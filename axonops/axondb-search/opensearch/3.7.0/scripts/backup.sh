#!/usr/bin/env bash
set -euo pipefail


# Backup script for OpenSearch snapshots
# - Checks whether a snapshot repository is configured according to env vars
# - Configures repository if missing (creates or updates using PUT)
# - Triggers a snapshot and waits for completion
# - Optionally cleans up old snapshots based on retention policy

# ============================================================================
# Configuration (environment variables with defaults)
# ============================================================================

# OpenSearch connection - HTTPS by default for secure communication
: "${AXONOPS_SEARCH_DEBUG:=false}"
: "${AXONOPS_SEARCH_URL:=https://localhost:9200}"
: "${AXONOPS_SEARCH_SNAPSHOT_REPO:=axon-backup-repo}"
: "${AXONOPS_SEARCH_BACKUP_TARGET:=local}"

# Authentication credentials (required for secured clusters)
: "${AXONOPS_SEARCH_USER:=admin}"
: "${AXONOPS_SEARCH_PASSWORD:=MyS3cur3P@ss2025}"

# TLS/SSL options
: "${AXONOPS_SEARCH_CA_CERT:=}"           # Path to CA certificate file
: "${AXONOPS_SEARCH_CLIENT_CERT:=}"       # Path to client certificate (for mTLS)
: "${AXONOPS_SEARCH_CLIENT_KEY:=}"        # Path to client key (for mTLS)
: "${AXONOPS_SEARCH_SKIP_TLS_VERIFY:=true}"  # Set to 'true' to skip TLS verification (NOT recommended for production)

# Snapshot options
: "${AXONOPS_SEARCH_SNAPSHOT_INDICES:=_all}"  # Indices to include in snapshot
: "${AXONOPS_SEARCH_SNAPSHOT_IGNORE_UNAVAILABLE:=true}"
: "${AXONOPS_SEARCH_SNAPSHOT_INCLUDE_GLOBAL_STATE:=true}"
: "${AXONOPS_SEARCH_SNAPSHOT_PREFIX:=snapshot}"

# Retention policy (optional)
: "${AXONOPS_SEARCH_SNAPSHOT_RETENTION_COUNT:=}"  # Number of snapshots to keep (empty = keep all)

# Timeout for waiting on snapshot completion (in seconds)
: "${AXONOPS_SEARCH_SNAPSHOT_TIMEOUT:=3600}"

[ "$AXONOPS_SEARCH_DEBUG" == "true" ] && set -x

# ============================================================================
# Build curl arguments
# ============================================================================

# Base curl options
CURL_OPTS=(-k -sS --fail-with-body --show-error)

# Authentication
AXONOPS_SEARCH_CURL_AUTH_ARGS=()
if [[ -n "${AXONOPS_SEARCH_USER}" ]] && [[ -n "${AXONOPS_SEARCH_PASSWORD}" ]]; then
  AXONOPS_SEARCH_CURL_AUTH_ARGS=(-u "${AXONOPS_SEARCH_USER}:${AXONOPS_SEARCH_PASSWORD}")
fi

# TLS/SSL configuration
AXONOPS_SEARCH_CURL_TLS_ARGS=()
if [[ "${AXONOPS_SEARCH_SKIP_TLS_VERIFY}" == "true" ]]; then
  echo "WARNING: TLS verification is disabled. This is insecure and not recommended for production." >&2
  AXONOPS_SEARCH_CURL_TLS_ARGS+=(-k)
else
  if [[ -n "${AXONOPS_SEARCH_CA_CERT}" ]]; then
    if [[ -f "${AXONOPS_SEARCH_CA_CERT}" ]]; then
      AXONOPS_SEARCH_CURL_TLS_ARGS+=(--cacert "${AXONOPS_SEARCH_CA_CERT}")
    else
      echo "ERROR: CA certificate file not found: ${AXONOPS_SEARCH_CA_CERT}" >&2
      exit 1
    fi
  fi
fi

# Client certificate authentication (mTLS)
if [[ -n "${AXONOPS_SEARCH_CLIENT_CERT}" ]] && [[ -n "${AXONOPS_SEARCH_CLIENT_KEY}" ]]; then
  if [[ -f "${AXONOPS_SEARCH_CLIENT_CERT}" ]] && [[ -f "${AXONOPS_SEARCH_CLIENT_KEY}" ]]; then
    AXONOPS_SEARCH_CURL_TLS_ARGS+=(--cert "${AXONOPS_SEARCH_CLIENT_CERT}" --key "${AXONOPS_SEARCH_CLIENT_KEY}")
  else
    echo "ERROR: Client certificate or key file not found" >&2
    exit 1
  fi
fi

# ============================================================================
# Helper functions
# ============================================================================

log() {
  echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"
}

log_error() {
  echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] ERROR: $*" >&2
}

http() {
  # Usage: http METHOD PATH [DATA]
  local method="$1" path="$2" data="${3:-}"
  local url="${AXONOPS_SEARCH_URL%/}${path}"

  if [[ -n "${data}" ]]; then
    curl "${CURL_OPTS[@]}" "${AXONOPS_SEARCH_CURL_AUTH_ARGS[@]}" "${AXONOPS_SEARCH_CURL_TLS_ARGS[@]}" \
      -X "$method" -H "Content-Type: application/json" -d "$data" "$url"
  else
    curl "${CURL_OPTS[@]}" "${AXONOPS_SEARCH_CURL_AUTH_ARGS[@]}" "${AXONOPS_SEARCH_CURL_TLS_ARGS[@]}" \
      -X "$method" "$url"
  fi
}

http_code() {
  # Outputs: HTTP_CODE on first line, then body on subsequent lines
  # Caller must parse: HTTP_CODE="${result%%$'\n'*}" and body="${result#*$'\n'}"
  local method="$1" path="$2" data="${3:-}"
  local url="${AXONOPS_SEARCH_URL%/}${path}"
  local resp

  # Remove --fail-with-body for this call to capture error responses
  local opts=(-sS --show-error)

  if [[ -n "${data}" ]]; then
    resp=$(curl "${opts[@]}" "${AXONOPS_SEARCH_CURL_AUTH_ARGS[@]}" "${AXONOPS_SEARCH_CURL_TLS_ARGS[@]}" \
      -X "$method" -H "Content-Type: application/json" -d "$data" -w "\n%{http_code}" "$url" 2>&1) || true
  else
    resp=$(curl "${opts[@]}" "${AXONOPS_SEARCH_CURL_AUTH_ARGS[@]}" "${AXONOPS_SEARCH_CURL_TLS_ARGS[@]}" \
      -X "$method" -w "\n%{http_code}" "$url" 2>&1) || true
  fi

  local code="${resp##*$'\n'}"
  local body="${resp%$'\n'*}"
  # Output code first, then body (separated by newline)
  printf "%s\n%s" "$code" "$body"
}

has_jq() {
  command -v jq >/dev/null 2>&1
}

# Helper to parse http_code output
# Sets HTTP_CODE and HTTP_BODY variables
parse_http_response() {
  local result="$1"
  HTTP_CODE="${result%%$'\n'*}"
  HTTP_BODY="${result#*$'\n'}"
}

wait_for_opensearch() {
  log "Waiting for OpenSearch to be available..."
  local max_attempts=60
  local attempt=0

  while [[ $attempt -lt $max_attempts ]]; do
    local result
    result=$(http_code GET "/_cluster/health" 2>/dev/null) || true
    parse_http_response "$result"
    if [[ "${HTTP_CODE}" == "200" ]]; then
      log "OpenSearch is available"
      return 0
    fi
    attempt=$((attempt + 1))
    log "Waiting for OpenSearch... (attempt ${attempt}/${max_attempts})"
    sleep 5
  done

  log_error "OpenSearch did not become available within expected time"
  return 1
}

# ============================================================================
# Repository management
# ============================================================================

build_repo_payload() {
  local tgt="$1"
  local settings_json="{}"

  case "$tgt" in
    s3)
      : "${AXONOPS_SEARCH_S3_BUCKET:?AXONOPS_SEARCH_S3_BUCKET is required for s3}"
      local -a parts=("\"bucket\": \"${AXONOPS_SEARCH_S3_BUCKET}\"")
      [[ -n "${AXONOPS_SEARCH_S3_BASE_PATH:-}" ]] && parts+=("\"base_path\": \"${AXONOPS_SEARCH_S3_BASE_PATH}\"")
      [[ -n "${AXONOPS_SEARCH_S3_REGION:-}" ]] && parts+=("\"region\": \"${AXONOPS_SEARCH_S3_REGION}\"")
      [[ -n "${AXONOPS_SEARCH_S3_ENDPOINT:-}" ]] && parts+=("\"endpoint\": \"${AXONOPS_SEARCH_S3_ENDPOINT}\"")
      [[ -n "${AXONOPS_SEARCH_S3_PROTOCOL:-}" ]] && parts+=("\"protocol\": \"${AXONOPS_SEARCH_S3_PROTOCOL}\"")
      [[ -n "${AXONOPS_SEARCH_S3_PATH_STYLE_ACCESS:-}" ]] && parts+=("\"path_style_access\": ${AXONOPS_SEARCH_S3_PATH_STYLE_ACCESS}")
      # Note: access_key and secret_key should be configured via keystore, not env vars
      local IFS=','
      settings_json="{${parts[*]}}"
      ;;
    gcs)
      : "${AXONOPS_SEARCH_GCS_BUCKET:?AXONOPS_SEARCH_GCS_BUCKET is required for gcs}"
      local -a parts=("\"bucket\": \"${AXONOPS_SEARCH_GCS_BUCKET}\"")
      [[ -n "${AXONOPS_SEARCH_GCS_BASE_PATH:-}" ]] && parts+=("\"base_path\": \"${AXONOPS_SEARCH_GCS_BASE_PATH}\"")
      [[ -n "${AXONOPS_SEARCH_GCS_CLIENT:-}" ]] && parts+=("\"client\": \"${AXONOPS_SEARCH_GCS_CLIENT}\"")
      local IFS=','
      settings_json="{${parts[*]}}"
      ;;
    azure)
      : "${AXONOPS_SEARCH_AZURE_CONTAINER:?AXONOPS_SEARCH_AZURE_CONTAINER is required for azure}"
      local -a parts=("\"container\": \"${AXONOPS_SEARCH_AZURE_CONTAINER}\"")
      [[ -n "${AXONOPS_SEARCH_AZURE_BASE_PATH:-}" ]] && parts+=("\"base_path\": \"${AXONOPS_SEARCH_AZURE_BASE_PATH}\"")
      [[ -n "${AXONOPS_SEARCH_AZURE_CLIENT:-}" ]] && parts+=("\"client\": \"${AXONOPS_SEARCH_AZURE_CLIENT}\"")
      local IFS=','
      settings_json="{${parts[*]}}"
      ;;
    local|fs)
      : "${AXONOPS_SEARCH_FS_PATH:?AXONOPS_SEARCH_FS_PATH is required for local/fs}"
      settings_json="{\"location\": \"${AXONOPS_SEARCH_FS_PATH}\"}"
      tgt="fs"
      ;;
    *)
      log_error "Unsupported AXONOPS_SEARCH_BACKUP_TARGET: $tgt"
      exit 2
      ;;
  esac

  # Allow the user to override the full settings object if AXONOPS_SEARCH_REPO_SETTINGS is provided
  if [[ -n "${AXONOPS_SEARCH_REPO_SETTINGS:-}" ]]; then
    printf '{"type":"%s","settings":%s}' "$tgt" "${AXONOPS_SEARCH_REPO_SETTINGS}"
  else
    printf '{"type":"%s","settings":%s}' "$tgt" "${settings_json}"
  fi
}

get_existing_repo() {
  local result body
  result=$(http_code GET "/_snapshot/${AXONOPS_SEARCH_SNAPSHOT_REPO}")
  parse_http_response "$result"
  if [[ "${HTTP_CODE}" == "200" ]]; then
    printf '%s' "$HTTP_BODY"
    return 0
  fi
  return 1
}

create_or_update_repo() {
  local payload
  payload=$(build_repo_payload "$AXONOPS_SEARCH_BACKUP_TARGET")
  log "Repository payload: $payload"

  local existing
  if existing=$(get_existing_repo 2>/dev/null); then
    if has_jq; then
      local existing_type existing_settings desired_type desired_settings
      existing_type=$(printf '%s' "$existing" | jq -r ".\"${AXONOPS_SEARCH_SNAPSHOT_REPO}\".type // empty")
      existing_settings=$(printf '%s' "$existing" | jq -S -c ".\"${AXONOPS_SEARCH_SNAPSHOT_REPO}\".settings // {}")
      desired_type=$(printf '%s' "$payload" | jq -r '.type')
      desired_settings=$(printf '%s' "$payload" | jq -S -c '.settings')

      if [[ "$existing_type" != "$desired_type" ]] || [[ "$existing_settings" != "$desired_settings" ]]; then
        log "Repository exists but differs from desired configuration. Updating repository..."
        local result
        result=$(http_code PUT "/_snapshot/${AXONOPS_SEARCH_SNAPSHOT_REPO}" "$payload")
        parse_http_response "$result"
        if [[ "${HTTP_CODE}" != "200" && "${HTTP_CODE}" != "201" ]]; then
          log_error "Failed to update repository: HTTP ${HTTP_CODE}"
          log_error "Response: ${HTTP_BODY}"

          # Check for common S3 errors and provide helpful guidance
          if [[ "$AXONOPS_SEARCH_BACKUP_TARGET" = "s3" ]]; then
            if echo "$HTTP_BODY" | grep -qi "credentials\|access\|authorization"; then
              log_error ""
              log_error "Credential Error Troubleshooting:"
              log_error "  1. If using env vars: Verify AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set"
              log_error "  2. If using Pod Identity: Verify serviceAccount has correct IAM role annotation"
              log_error "  3. Check keystore contains credentials:"
              log_error "     /usr/share/opensearch/bin/opensearch-keystore list"
            elif echo "$HTTP_BODY" | grep -qi "bucket\|s3:"; then
              log_error ""
              log_error "S3 Bucket Error: Verify AXONOPS_SEARCH_S3_BUCKET exists and is accessible"
              log_error "  Bucket name: ${AXONOPS_SEARCH_S3_BUCKET:-not set}"
              log_error "  Check IAM permissions for s3:ListBucket, s3:PutObject, s3:GetObject"
            elif echo "$HTTP_BODY" | grep -qi "plugin"; then
              log_error ""
              log_error "Plugin Error: Verify repository-s3 plugin is installed"
              log_error "  Check: /usr/share/opensearch/bin/opensearch-plugin list | grep repository-s3"
            fi
          fi
          exit 3
        fi
        log "Repository updated."
      else
        log "Repository already configured as desired."
      fi
    else
      log "Repository exists; 'jq' not available to validate settings. Skipping strict validation."
    fi
  else
    log "Repository not found; creating..."
    local result
    result=$(http_code PUT "/_snapshot/${AXONOPS_SEARCH_SNAPSHOT_REPO}" "$payload")
    parse_http_response "$result"
    if [[ "${HTTP_CODE}" != "200" && "${HTTP_CODE}" != "201" ]]; then
      log_error "Failed to create repository: HTTP ${HTTP_CODE}"
      log_error "Response: ${HTTP_BODY}"

      # Check for common S3 errors and provide helpful guidance
      if [[ "$AXONOPS_SEARCH_BACKUP_TARGET" = "s3" ]]; then
        if echo "$HTTP_BODY" | grep -qi "credentials\|access\|authorization"; then
          log_error ""
          log_error "Credential Error Troubleshooting:"
          log_error "  1. If using env vars: Verify AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set"
          log_error "  2. If using Pod Identity: Verify serviceAccount has correct IAM role annotation"
          log_error "  3. Check keystore contains credentials:"
          log_error "     /usr/share/opensearch/bin/opensearch-keystore list"
        elif echo "$HTTP_BODY" | grep -qi "bucket\|s3:"; then
          log_error ""
          log_error "S3 Bucket Error: Verify AXONOPS_SEARCH_S3_BUCKET exists and is accessible"
          log_error "  Bucket name: ${AXONOPS_SEARCH_S3_BUCKET:-not set}"
          log_error "  Check IAM permissions for s3:ListBucket, s3:PutObject, s3:GetObject"
        elif echo "$HTTP_BODY" | grep -qi "plugin"; then
          log_error ""
          log_error "Plugin Error: Verify repository-s3 plugin is installed"
          log_error "  Check: /usr/share/opensearch/bin/opensearch-plugin list | grep repository-s3"
        fi
      fi
      exit 3
    fi
    log "Repository created."
  fi

  # Verify repository is accessible
  log "Verifying repository..."
  local verify_result
  verify_result=$(http_code POST "/_snapshot/${AXONOPS_SEARCH_SNAPSHOT_REPO}/_verify")
  parse_http_response "$verify_result"
  if [[ "${HTTP_CODE}" != "200" ]]; then
    log_error "Repository verification failed: HTTP ${HTTP_CODE}"
    log_error "Response: ${HTTP_BODY}"

    # Check for common S3 errors and provide helpful guidance
    if [[ "$AXONOPS_SEARCH_BACKUP_TARGET" = "s3" ]]; then
      if echo "$HTTP_BODY" | grep -qi "credentials\|access\|authorization"; then
        log_error ""
        log_error "Credential Error During Verification:"
        log_error "  Repository created but verification failed - check IAM permissions"
        log_error "  Required: s3:ListBucket, s3:PutObject, s3:GetObject, s3:DeleteObject"
      elif echo "$HTTP_BODY" | grep -qi "region\|location"; then
        log_error ""
        log_error "Region Error: Bucket may be in a different region"
        log_error "  Try setting: AXONOPS_SEARCH_S3_REGION to match bucket region"
      fi
    fi
    exit 3
  fi
  log "Repository verified successfully."
}

# ============================================================================
# Snapshot management
# ============================================================================

create_snapshot() {
  local name
  name="${AXONOPS_SEARCH_SNAPSHOT_PREFIX}-$(date -u +%Y%m%d%H%M%S)"
  log "Starting snapshot '${name}' in repository '${AXONOPS_SEARCH_SNAPSHOT_REPO}'..."

  local body
  body=$(cat <<EOF
{
  "indices": "${AXONOPS_SEARCH_SNAPSHOT_INDICES}",
  "ignore_unavailable": ${AXONOPS_SEARCH_SNAPSHOT_IGNORE_UNAVAILABLE},
  "include_global_state": ${AXONOPS_SEARCH_SNAPSHOT_INCLUDE_GLOBAL_STATE}
}
EOF
)

  local result
  result=$(http_code PUT "/_snapshot/${AXONOPS_SEARCH_SNAPSHOT_REPO}/${name}?wait_for_completion=true" "$body")
  parse_http_response "$result"

  if [[ "${HTTP_CODE}" != "200" && "${HTTP_CODE}" != "201" ]]; then
    log_error "Snapshot failed: HTTP ${HTTP_CODE}"
    log_error "Response: ${HTTP_BODY}"
    exit 4
  fi

  # Check snapshot state if jq is available
  if has_jq; then
    local state
    state=$(printf '%s' "$HTTP_BODY" | jq -r '.snapshot.state // "UNKNOWN"')
    if [[ "$state" != "SUCCESS" ]]; then
      log_error "Snapshot completed with state: ${state}"
      log_error "Response: ${HTTP_BODY}"
      exit 4
    fi
    local shards_total shards_failed
    shards_total=$(printf '%s' "$HTTP_BODY" | jq -r '.snapshot.shards.total // 0')
    shards_failed=$(printf '%s' "$HTTP_BODY" | jq -r '.snapshot.shards.failed // 0')
    log "Snapshot '${name}' completed successfully. State: ${state}, Shards: ${shards_total} total, ${shards_failed} failed."
  else
    log "Snapshot '${name}' completed successfully."
  fi
}

cleanup_old_snapshots() {
  # Support both retention days and count - days takes precedence
  local retention_days="${AXONOPS_SEARCH_SNAPSHOT_RETENTION_DAYS:-30}"  # Default to 30 days
  local retention_count="${AXONOPS_SEARCH_SNAPSHOT_RETENTION_COUNT:-}"

  # If retention_days is 0 or negative, skip cleanup
  if [[ "$retention_days" -le 0 ]]; then
    log "Snapshot retention disabled (retention_days=0), skipping cleanup."
    return 0
  fi

  if ! has_jq; then
    log "WARNING: jq not available, cannot perform snapshot cleanup."
    return 0
  fi

  # Calculate cutoff timestamp (milliseconds since epoch)
  local cutoff_timestamp_ms
  cutoff_timestamp_ms=$(( ($(date +%s) - (retention_days * 86400)) * 1000 ))

  log "Cleaning up snapshots older than ${retention_days} days..."

  local result
  result=$(http_code GET "/_snapshot/${AXONOPS_SEARCH_SNAPSHOT_REPO}/_all")
  parse_http_response "$result"

  if [[ "${HTTP_CODE}" != "200" ]]; then
    log_error "Failed to list snapshots: HTTP ${HTTP_CODE}"
    return 1
  fi

  # Get snapshots to delete based on age (and optionally count)
  local snapshots_to_delete
  if [[ -n "$retention_count" ]] && [[ "$retention_count" -gt 0 ]]; then
    # Both age and count retention - delete snapshots that are either too old OR exceed count
    log "Also enforcing maximum of ${retention_count} snapshots"
    snapshots_to_delete=$(printf '%s' "$HTTP_BODY" | jq -r \
      --arg prefix "${AXONOPS_SEARCH_SNAPSHOT_PREFIX}" \
      --argjson cutoff "$cutoff_timestamp_ms" \
      --argjson keep "$retention_count" '
      .snapshots
      | map(select(.snapshot | startswith($prefix)))
      | sort_by(.start_time_in_millis)
      | reverse
      | (
          (.[($keep):] // []) +
          (map(select(.start_time_in_millis < $cutoff)) // [])
        )
      | unique
      | .[].snapshot
    ')
  else
    # Only age-based retention
    snapshots_to_delete=$(printf '%s' "$HTTP_BODY" | jq -r \
      --arg prefix "${AXONOPS_SEARCH_SNAPSHOT_PREFIX}" \
      --argjson cutoff "$cutoff_timestamp_ms" '
      .snapshots
      | map(select(.snapshot | startswith($prefix)))
      | map(select(.start_time_in_millis < $cutoff))
      | .[].snapshot
    ')
  fi

  if [[ -z "$snapshots_to_delete" ]]; then
    log "No old snapshots to delete."
    return 0
  fi

  local count=0
  local total_count
  total_count=$(echo "$snapshots_to_delete" | grep -c '^' || true)

  log "Found ${total_count} snapshot(s) to delete based on retention policy"

  while IFS= read -r snapshot_name; do
    [[ -z "$snapshot_name" ]] && continue
    log "Deleting old snapshot: ${snapshot_name}"
    local delete_result
    delete_result=$(http_code DELETE "/_snapshot/${AXONOPS_SEARCH_SNAPSHOT_REPO}/${snapshot_name}")
    parse_http_response "$delete_result"
    if [[ "${HTTP_CODE}" == "200" ]]; then
      log "Deleted snapshot: ${snapshot_name}"
      count=$((count + 1))
    else
      log_error "Failed to delete snapshot ${snapshot_name}: HTTP ${HTTP_CODE}"
    fi
  done <<< "$snapshots_to_delete"

  log "Deleted ${count} of ${total_count} old snapshot(s)."
}

list_snapshots() {
  log "Listing snapshots in repository '${AXONOPS_SEARCH_SNAPSHOT_REPO}'..."
  local result
  result=$(http_code GET "/_snapshot/${AXONOPS_SEARCH_SNAPSHOT_REPO}/_all")
  parse_http_response "$result"

  if [[ "${HTTP_CODE}" != "200" ]]; then
    log_error "Failed to list snapshots: HTTP ${HTTP_CODE}"
    return 1
  fi

  if has_jq; then
    printf '%s' "$HTTP_BODY" | jq -r '.snapshots[] | "\(.snapshot)\t\(.state)\t\(.start_time)"'
  else
    printf '%s\n' "$HTTP_BODY"
  fi
}

# ============================================================================
# Main
# ============================================================================

usage() {
  cat <<EOF
Usage: $(basename "$0") [COMMAND]

Commands:
  backup    Create a new snapshot (default)
  list      List existing snapshots
  cleanup   Clean up old snapshots based on retention policy
  verify    Verify repository configuration
  help      Show this help message

Environment Variables:
  AXONOPS_SEARCH_URL                    OpenSearch URL (default: https://localhost:9200)
  AXONOPS_SEARCH_USER                   Username for authentication
  AXONOPS_SEARCH_PASSWORD               Password for authentication
  AXONOPS_SEARCH_CA_CERT                Path to CA certificate for TLS
  AXONOPS_SEARCH_CLIENT_CERT            Path to client certificate for mTLS
  AXONOPS_SEARCH_CLIENT_KEY             Path to client key for mTLS
  AXONOPS_SEARCH_SKIP_TLS_VERIFY        Skip TLS verification (default: false)
  AXONOPS_SEARCH_SNAPSHOT_REPO          Snapshot repository name (default: my-backup-repo)
  AXONOPS_SEARCH_BACKUP_TARGET          Backup target: s3, gcs, azure, local (required)
  AXONOPS_SEARCH_SNAPSHOT_PREFIX        Snapshot name prefix (default: snapshot)
  AXONOPS_SEARCH_SNAPSHOT_RETENTION_COUNT  Number of snapshots to keep (optional)

  For S3:
    AXONOPS_SEARCH_S3_BUCKET            S3 bucket name (required)
    AXONOPS_SEARCH_S3_BASE_PATH         Base path within bucket
    AXONOPS_SEARCH_S3_REGION            AWS region
    AXONOPS_SEARCH_S3_ENDPOINT          Custom S3 endpoint
    AXONOPS_SEARCH_S3_PROTOCOL          Protocol (http/https)
    AXONOPS_SEARCH_S3_PATH_STYLE_ACCESS Use path-style access (true/false)

  For GCS:
    AXONOPS_SEARCH_GCS_BUCKET           GCS bucket name (required)
    AXONOPS_SEARCH_GCS_BASE_PATH        Base path within bucket
    AXONOPS_SEARCH_GCS_CLIENT           GCS client name

  For Azure:
    AXONOPS_SEARCH_AZURE_CONTAINER      Azure container name (required)
    AXONOPS_SEARCH_AZURE_BASE_PATH      Base path within container
    AXONOPS_SEARCH_AZURE_CLIENT         Azure client name

  For Local/FS:
    AXONOPS_SEARCH_FS_PATH              Filesystem path (required)
EOF
}

main() {
  local command="${1:-backup}"

  log "OpenSearch Backup Script"
  log "========================"
  log "OpenSearch URL: ${AXONOPS_SEARCH_URL}"
  log "Target: ${AXONOPS_SEARCH_BACKUP_TARGET}"
  log "Repository: ${AXONOPS_SEARCH_SNAPSHOT_REPO}"

  # Log retention policy
  local retention_days="${AXONOPS_SEARCH_SNAPSHOT_RETENTION_DAYS:-30}"
  if [[ "$retention_days" -gt 0 ]]; then
    log "Retention: ${retention_days} days"
    if [[ -n "${AXONOPS_SEARCH_SNAPSHOT_RETENTION_COUNT:-}" ]]; then
      log "Max snapshots: ${AXONOPS_SEARCH_SNAPSHOT_RETENTION_COUNT}"
    fi
  else
    log "Retention: Disabled"
  fi

  # Log S3-specific configuration if using S3 target
  if [[ "$AXONOPS_SEARCH_BACKUP_TARGET" = "s3" ]]; then
    log "S3 Configuration:"
    log "  Bucket: ${AXONOPS_SEARCH_S3_BUCKET:-not set}"
    log "  Region: ${AXONOPS_SEARCH_S3_REGION:-default}"
    log "  Base Path: ${AXONOPS_SEARCH_S3_BASE_PATH:-/}"

    # Check if using S3-compatible storage
    if [[ -n "${AXONOPS_SEARCH_S3_ENDPOINT:-}" ]]; then
        log "  Endpoint: ${AXONOPS_SEARCH_S3_ENDPOINT} (S3-compatible storage)"
        log "  Protocol: ${AXONOPS_SEARCH_S3_PROTOCOL:-auto-detect}"
        log "  Path Style: ${AXONOPS_SEARCH_S3_PATH_STYLE_ACCESS:-false}"
    else
        log "  Endpoint: AWS default"
    fi

    # Log credential source (without exposing actual credentials)
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
        log "  Credentials: Explicit (env vars)"
    else
        log "  Credentials: IAM Role (Pod Identity/IRSA/Instance Profile)"
    fi
  fi

  case "$command" in
    backup)
      if [[ "${AXONOPS_SEARCH_BACKUP_TARGET}" != "local" && "${AXONOPS_SEARCH_BACKUP_TARGET}" != "fs" ]]; then
        log "Note: Ensure the corresponding repository plugin is installed on OpenSearch nodes for target '${AXONOPS_SEARCH_BACKUP_TARGET}'."
      fi

      wait_for_opensearch
      create_or_update_repo
      create_snapshot
      cleanup_old_snapshots

      log "Backup completed successfully."
      ;;
    list)
      wait_for_opensearch
      list_snapshots
      ;;
    cleanup)
      wait_for_opensearch
      cleanup_old_snapshots
      ;;
    verify)
      wait_for_opensearch
      create_or_update_repo
      log "Repository verification completed."
      ;;
    help|--help|-h)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown command: $command"
      usage
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
