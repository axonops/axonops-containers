#!/bin/bash
set -e

# AxonDB Search Entrypoint Script
# Configures OpenSearch and starts the search engine

# Display comprehensive startup banner
print_startup_banner() {
    if [ -f /etc/axonops/build-info.txt ]; then
      source /etc/axonops/build-info.txt 2>/dev/null || true
    fi

    echo "================================================================================"
    # Title
    echo "AxonOps AxonDB Search (OpenSearch ${OPENSEARCH_VERSION:-unknown})"

    # Image and build info (CI builds only - not shown for local/unknown builds)
    if [ -n "${CONTAINER_IMAGE}" ] && [ "${CONTAINER_IMAGE}" != "unknown" ] && [ "${CONTAINER_IMAGE}" != "" ]; then
      echo "Image: ${CONTAINER_IMAGE}"
    fi
    if [ -n "${CONTAINER_BUILD_DATE}" ] && [ "${CONTAINER_BUILD_DATE}" != "unknown" ] && [ "${CONTAINER_BUILD_DATE}" != "" ]; then
      echo "Built: ${CONTAINER_BUILD_DATE}"
    fi

    # Show release/tag link if available (CI builds)
    if [ -n "${CONTAINER_GIT_TAG}" ] && [ "${CONTAINER_GIT_TAG}" != "unknown" ] && [ "${CONTAINER_GIT_TAG}" != "" ]; then
      if [ "${IS_PRODUCTION_RELEASE:-false}" = "true" ]; then
        # Production build - link to release page (has release notes)
        echo "Release: https://github.com/axonops/axonops-containers/releases/tag/${CONTAINER_GIT_TAG}"
      else
        # Development build - link to tag/tree
        echo "Tag:     https://github.com/axonops/axonops-containers/tree/${CONTAINER_GIT_TAG}"
      fi
    fi

    # Show who built it if available (CI builds)
    if [ -n "${CONTAINER_BUILT_BY}" ] && [ "${CONTAINER_BUILT_BY}" != "unknown" ] && [ "${CONTAINER_BUILT_BY}" != "" ]; then
      if [ "${CONTAINER_BUILT_BY}" = "GitHub Actions" ] || [ "${IS_PRODUCTION_RELEASE:-false}" = "true" ]; then
        echo "Built by: ${CONTAINER_BUILT_BY}"
      fi
    fi

    echo "================================================================================"
    echo ""

    # Component versions (from build-info.txt)
    echo "Component Versions:"
    echo "  OpenSearch:         ${OPENSEARCH_VERSION:-unknown}"
    echo "  Java:               ${JAVA_VERSION:-unknown}"
    echo "  OS:                 ${OS_VERSION:-unknown}"
    echo "  Platform:           ${PLATFORM:-unknown}"
    echo ""

    # Supply chain verification (base image digest for security audit)
    echo "Supply Chain Security:"
    echo "  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest"
    echo "  Base image digest:  ${UBI9_BASE_DIGEST:-unknown}"
    echo ""

    # Runtime environment (dynamic - only knowable at runtime)
    echo "Runtime Environment:"
    echo "  Hostname:           $(hostname 2>/dev/null || echo 'unknown')"

    # Kubernetes detection (safe - only if vars exist)
    if [ -n "${KUBERNETES_SERVICE_HOST}" ]; then
      echo "  Kubernetes:         Yes"
      echo "    API Server:       ${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
      if [ -n "${HOSTNAME}" ]; then
        echo "    Pod:              ${HOSTNAME}"
      fi
    fi
    echo ""

    echo "================================================================================"
    echo "Starting OpenSearch..."
    echo "================================================================================"
    echo ""
}

print_startup_banner

# Export OpenSearch paths
export OPENSEARCH_HOME=${OPENSEARCH_HOME:-/opt/opensearch}
export OPENSEARCH_PATH_CONF=${OPENSEARCH_PATH_CONF:-/etc/opensearch}
export OPENSEARCH_DATA_DIR=${OPENSEARCH_DATA_DIR:-/var/lib/opensearch}
export OPENSEARCH_LOG_DIR=${OPENSEARCH_LOG_DIR:-/var/log/opensearch}

# The virtual file /proc/self/cgroup should list the current cgroup
# membership. For each hierarchy, you can follow the cgroup path from
# this file to the cgroup filesystem (usually /sys/fs/cgroup/) and
# introspect the statistics for the cgroup for the given
# hierarchy. Alas, Docker breaks this by mounting the container
# statistics at the root while leaving the cgroup paths as the actual
# paths. Therefore, OpenSearch provides a mechanism to override
# reading the cgroup path from /proc/self/cgroup and instead uses the
# cgroup path defined the JVM system property
# opensearch.cgroups.hierarchy.override. Therefore, we set this value here so
# that cgroup statistics are available for the container this process
# will run in.
export OPENSEARCH_JAVA_OPTS="-Dopensearch.cgroups.hierarchy.override=/ $OPENSEARCH_JAVA_OPTS"

# Set default environment variables if not provided
export OPENSEARCH_CLUSTER_NAME="${OPENSEARCH_CLUSTER_NAME:-axonopsdb-search}"
export OPENSEARCH_NODE_NAME="${OPENSEARCH_NODE_NAME:-${HOSTNAME}}"
export OPENSEARCH_NETWORK_HOST="${OPENSEARCH_NETWORK_HOST:-0.0.0.0}"

# TLS/SSL settings (default: enabled)
# When false, disables HTTPS on REST API (useful when TLS terminated at load balancer)
export AXONOPS_SEARCH_TLS_ENABLED="${AXONOPS_SEARCH_TLS_ENABLED:-true}"

# JVM heap settings (default: 8G, matches AxonDB Time-Series)
export OPENSEARCH_HEAP_SIZE="${OPENSEARCH_HEAP_SIZE:-8g}"

# Define certificate paths from environment variables or use defaults
TLS_CERT_PATH=${OPENSEARCH_TLS_CERT_PATH:-"${OPENSEARCH_PATH_CONF}/certs/axondbsearch-default-node.pem"}
TLS_KEY_PATH=${OPENSEARCH_TLS_KEY_PATH:-"${OPENSEARCH_PATH_CONF}/certs/axondbsearch-default-node-key.pem"}
CA_CERT_PATH=${OPENSEARCH_CA_CERT_PATH:-"${OPENSEARCH_PATH_CONF}/certs/axondbsearch-default-root-ca.pem"}

echo "Configuration:"
echo "  Cluster Name:       ${OPENSEARCH_CLUSTER_NAME}"
echo "  Node Name:          ${OPENSEARCH_NODE_NAME}"
echo "  Network Host:       ${OPENSEARCH_NETWORK_HOST}"
echo "  Discovery Type:     ${OPENSEARCH_DISCOVERY_TYPE}"
echo "  Heap Size:          ${OPENSEARCH_HEAP_SIZE}"
echo "  TLS Enabled:        ${AXONOPS_SEARCH_TLS_ENABLED}"

if [ "$AXONOPS_SEARCH_TLS_ENABLED" = "true" ]; then
    echo "  TLS Cert Path:      ${TLS_CERT_PATH}"
    echo "  TLS Key Path:       ${TLS_KEY_PATH}"
    echo "  CA Cert Path:       ${CA_CERT_PATH}"
fi
echo ""

# Apply environment variable substitutions to opensearch.yml
_sed-in-place() {
    local filename="$1"; shift
    local tempFile
    tempFile="$(mktemp)"
    sed "$@" "$filename" > "$tempFile"
    cat "$tempFile" > "$filename"
    rm "$tempFile"
}

# Apply cluster name
if [ -n "$OPENSEARCH_CLUSTER_NAME" ]; then
    _sed-in-place "/etc/opensearch/opensearch.yml" -r 's/^(# )?(cluster\.name:).*/\2 '"$OPENSEARCH_CLUSTER_NAME"'/'
fi

# Apply node name
if [ -n "$OPENSEARCH_NODE_NAME" ]; then
    _sed-in-place "/etc/opensearch/opensearch.yml" -r 's/^(# )?(node\.name:).*/\2 '"$OPENSEARCH_NODE_NAME"'/'
fi

# Apply network host
if [ -n "$OPENSEARCH_NETWORK_HOST" ]; then
    _sed-in-place "/etc/opensearch/opensearch.yml" -r 's/^(# )?(network\.host:).*/\2 '"$OPENSEARCH_NETWORK_HOST"'/'
fi

# Apply heap size override to jvm.options if env var set
if [ -n "$OPENSEARCH_HEAP_SIZE" ]; then
    _sed-in-place "/etc/opensearch/jvm.options" -r 's/^-Xms[0-9]+[GgMm]$/-Xms'"$OPENSEARCH_HEAP_SIZE"'/'
    _sed-in-place "/etc/opensearch/jvm.options" -r 's/^-Xmx[0-9]+[GgMm]$/-Xmx'"$OPENSEARCH_HEAP_SIZE"'/'
fi

# Apply thread pool write queue size if env var set
if [ -n "$OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE" ]; then
    _sed-in-place "/etc/opensearch/opensearch.yml" -r 's/^(# )?(thread_pool\.write\.queue_size:).*/\2 '"$OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE"'/'
fi

# Apply transport SSL hostname verification if env var set
if [ -n "$OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION" ]; then
    _sed-in-place "/etc/opensearch/opensearch.yml" -r 's/^(# )?(plugins\.security\.ssl\.transport\.enforce_hostname_verification:).*/\2 '"$OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION"'/'
fi

# Apply HTTP SSL client auth mode if env var set
if [ -n "$OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE" ]; then
    _sed-in-place "/etc/opensearch/opensearch.yml" -r 's/^(# )?(plugins\.security\.ssl\.http\.clientauth_mode:).*/\2 '"$OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE"'/'
fi

# Apply security admin DN if env var set (for custom certificate scenarios)
if [ -n "$OPENSEARCH_SECURITY_ADMIN_DN" ]; then
    # Replace the admin_dn line (format: "  - \"DN_STRING\"")
    _sed-in-place "/etc/opensearch/opensearch.yml" -r 's|^  - ".*axondbsearch.*"|  - "'"$OPENSEARCH_SECURITY_ADMIN_DN"'"|'
fi

# Apply security nodes DN if env var set (for custom certificate scenarios)
# Supports multiple DNs separated by semicolon (;)
# Example: "CN=*.example.svc.cluster.local;CN=node-1;CN=node-2"
if [ -n "$OPENSEARCH_SECURITY_NODES_DN" ]; then
    echo "Configuring nodes_dn from OPENSEARCH_SECURITY_NODES_DN..."

    # Remove existing nodes_dn section (from the key line to the last list item)
    _sed-in-place "/etc/opensearch/opensearch.yml" '/^plugins\.security\.nodes_dn:/,/^  - ".*"$/d'

    # Build the nodes_dn section from the environment variable
    NODES_DN_SECTION="plugins.security.nodes_dn:"

    # Split by semicolon and build YAML list
    IFS=';' read -ra DN_ARRAY <<< "$OPENSEARCH_SECURITY_NODES_DN"
    for dn in "${DN_ARRAY[@]}"; do
        # Trim whitespace
        dn=$(echo "$dn" | xargs)
        if [ -n "$dn" ]; then
            NODES_DN_SECTION="${NODES_DN_SECTION}\n  - \"${dn}\""
        fi
    done

    # Insert the new nodes_dn section after admin_dn
    _sed-in-place "/etc/opensearch/opensearch.yml" "/^plugins\.security\.authcz\.admin_dn:/,/^  - \".*\"$/ {
        /^  - \".*\"$/ a\\
\\
# Node certificates (configured via OPENSEARCH_SECURITY_NODES_DN)\\
${NODES_DN_SECTION}
    }"

    echo "  ✓ Configured $(echo "${DN_ARRAY[@]}" | wc -w) node DN(s)"
fi

# Disable HTTP SSL if AXONOPS_SEARCH_TLS_ENABLED=false
# This is useful when TLS is terminated at load balancer/ingress
# Transport layer SSL remains enabled for node-to-node communication
if [ "$AXONOPS_SEARCH_TLS_ENABLED" = "false" ]; then
    echo "Disabling HTTP SSL (AXONOPS_SEARCH_TLS_ENABLED=false)"
    echo "  TLS will be terminated at load balancer/ingress"
    echo "  Transport layer SSL remains enabled for node-to-node communication"
    # Add or update the HTTP SSL setting in opensearch.yml
    if grep -q "plugins.security.ssl.http.enabled" /etc/opensearch/opensearch.yml; then
        _sed-in-place "/etc/opensearch/opensearch.yml" -r 's/^(# )?(plugins\.security\.ssl\.http\.enabled:).*/\2 false/'
    else
        echo "plugins.security.ssl.http.enabled: false" >> /etc/opensearch/opensearch.yml
    fi
fi

# Apply SSL/TLS certificate paths based on environment variables
# Convert absolute paths to relative paths for opensearch.yml (remove the config path prefix)
# The configuration expects relative paths from the config directory
if [ -n "$TLS_CERT_PATH" ]; then
    # Extract relative path by removing the OPENSEARCH_PATH_CONF prefix
    RELATIVE_CERT_PATH="${TLS_CERT_PATH#${OPENSEARCH_PATH_CONF}/}"
    # Update both transport and HTTP certificate paths
    _sed-in-place "/etc/opensearch/opensearch.yml" -r "s|^(plugins\.security\.ssl\.transport\.pemcert_filepath:).*|\1 ${RELATIVE_CERT_PATH}|"
    _sed-in-place "/etc/opensearch/opensearch.yml" -r "s|^(plugins\.security\.ssl\.http\.pemcert_filepath:).*|\1 ${RELATIVE_CERT_PATH}|"
fi

if [ -n "$TLS_KEY_PATH" ]; then
    # Extract relative path by removing the OPENSEARCH_PATH_CONF prefix
    RELATIVE_KEY_PATH="${TLS_KEY_PATH#${OPENSEARCH_PATH_CONF}/}"
    # Update both transport and HTTP key paths
    _sed-in-place "/etc/opensearch/opensearch.yml" -r "s|^(plugins\.security\.ssl\.transport\.pemkey_filepath:).*|\1 ${RELATIVE_KEY_PATH}|"
    _sed-in-place "/etc/opensearch/opensearch.yml" -r "s|^(plugins\.security\.ssl\.http\.pemkey_filepath:).*|\1 ${RELATIVE_KEY_PATH}|"
fi

if [ -n "$CA_CERT_PATH" ]; then
    # Extract relative path by removing the OPENSEARCH_PATH_CONF prefix
    RELATIVE_CA_PATH="${CA_CERT_PATH#${OPENSEARCH_PATH_CONF}/}"
    # Update both transport and HTTP CA certificate paths
    _sed-in-place "/etc/opensearch/opensearch.yml" -r "s|^(plugins\.security\.ssl\.transport\.pemtrustedcas_filepath:).*|\1 ${RELATIVE_CA_PATH}|"
    _sed-in-place "/etc/opensearch/opensearch.yml" -r "s|^(plugins\.security\.ssl\.http\.pemtrustedcas_filepath:).*|\1 ${RELATIVE_CA_PATH}|"
fi

echo "✓ Configuration applied to opensearch.yml"
echo ""

# Files created by OpenSearch should always be group writable too
umask 0002

# Prevent root execution
if [[ "$(id -u)" == "0" ]]; then
    echo "OpenSearch cannot run as root. Please start your container as another user."
    exit 1
fi

# Performance Analyzer - disabled by default (AxonOps provides monitoring)
export DISABLE_PERFORMANCE_ANALYZER_AGENT_CLI="${DISABLE_PERFORMANCE_ANALYZER_AGENT_CLI:-true}"

# Generate AxonOps-branded certificates at runtime (if needed)
# This generates unique certificates per deployment instead of embedding them in the image
GENERATE_CERTS_ON_STARTUP="${GENERATE_CERTS_ON_STARTUP:-true}"
CERT_SEMAPHORE="${OPENSEARCH_DATA_DIR}/.axonops/generate-certs.done"
CERT_FILE=${OPENSEARCH_TLS_CERT_PATH:-${OPENSEARCH_PATH_CONF}/certs/axondbsearch-default-node.pem}

if [ "$GENERATE_CERTS_ON_STARTUP" = "true" ]; then
    echo "=== Certificate Generation (Runtime) ==="

    if [ ! -f "$CERT_FILE" ]; then
        # Certs don't exist - check if we generated them before but they're gone (ephemeral storage)
        if [ -f "$CERT_SEMAPHORE" ] && grep -q "certs_generated\|certs_regenerated" "$CERT_SEMAPHORE" 2>/dev/null; then
            echo "⚠ Certificates were generated before but are missing (container restart with ephemeral storage)"
            echo "  Regenerating certificates..."
            /usr/local/bin/generate-certs.sh
            mkdir -p "$(dirname "$CERT_SEMAPHORE")"
            {
                echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
                echo "RESULT=success"
                echo "REASON=certs_regenerated_after_restart"
            } > "$CERT_SEMAPHORE"
            echo "  ✓ Certificates regenerated"
        else
            # First time generation
            echo "  Generating AxonOps-branded certificates..."
            /usr/local/bin/generate-certs.sh
            mkdir -p "$(dirname "$CERT_SEMAPHORE")"
            {
                echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
                echo "RESULT=success"
                echo "REASON=certs_generated"
            } > "$CERT_SEMAPHORE"
            echo "  ✓ Certificates generated for first time"
        fi
    else
        echo "  ✓ Certificates already exist (user-provided or previously generated)"
        mkdir -p "$(dirname "$CERT_SEMAPHORE")"
        {
            echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
            echo "RESULT=skipped"
            echo "REASON=certs_already_exist"
        } > "$CERT_SEMAPHORE"
    fi
    echo ""
else
    echo "=== Certificate Generation Disabled ==="
    echo "  GENERATE_CERTS_ON_STARTUP=false"
    echo "  Ensure certificates are provided via volume mount!"
    mkdir -p "$(dirname "$CERT_SEMAPHORE")"
    {
        echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "RESULT=skipped"
        echo "REASON=disabled_by_env_var"
    } > "$CERT_SEMAPHORE"
    echo ""
fi

# Create custom admin user BEFORE starting OpenSearch (if requested)
# This REPLACES the default admin user in internal_users.yml
# Security: Only ONE admin user should exist (either default OR custom, never both)
if [ -n "$AXONOPS_SEARCH_USER" ] && [ -n "$AXONOPS_SEARCH_PASSWORD" ]; then
    echo "=== Replacing Default Admin with Custom Admin User (Pre-Startup) ==="
    echo "  Username: $AXONOPS_SEARCH_USER"
    echo "  Replacing default 'admin' user for security"
    echo ""

    # Generate password hash using OpenSearch security tools
    echo "  Generating password hash..."
    HASH_OUTPUT=$(cd "${OPENSEARCH_HOME}" && bash "${OPENSEARCH_HOME}/plugins/opensearch-security/tools/hash.sh" -p "$AXONOPS_SEARCH_PASSWORD" 2>/dev/null)
    PASSWORD_HASH=$(echo "$HASH_OUTPUT" | tail -1)

    if [ -z "$PASSWORD_HASH" ] || ! echo "$PASSWORD_HASH" | grep -q '^\$2[ayb]\$'; then
        echo "  ⚠ ERROR: Failed to generate valid bcrypt password hash"
        exit 1
    fi

    # REPLACE internal_users.yml with ONLY the custom user (delete default admin)
    INTERNAL_USERS_FILE="${OPENSEARCH_PATH_CONF}/opensearch-security/internal_users.yml"
    echo "  Writing ${INTERNAL_USERS_FILE} with ONLY custom user..."
    cat > "$INTERNAL_USERS_FILE" <<EOF
---
_meta:
  type: "internalusers"
  config_version: 2

# AxonOps custom admin user (REPLACES default admin for security)
# Created from AXONOPS_SEARCH_USER and AXONOPS_SEARCH_PASSWORD environment variables
${AXONOPS_SEARCH_USER}:
  hash: "${PASSWORD_HASH}"
  reserved: true
  backend_roles:
  - "admin"
  description: "AxonOps admin user created via AXONOPS_SEARCH_USER (default admin replaced)"
EOF

    echo "  ✓ Default 'admin' user REMOVED"
    echo "  ✓ Custom admin user created: $AXONOPS_SEARCH_USER"
    echo "  ✓ ONLY custom user will exist (no default admin)"
    echo ""
fi

# Display security configuration
if [ "$DISABLE_SECURITY_PLUGIN" = "true" ]; then
    echo "⚠ WARNING: Security plugin disabled (DISABLE_SECURITY_PLUGIN=true)"
    echo "  This is NOT recommended for production!"
elif [ -n "$AXONOPS_SEARCH_USER" ]; then
    echo "✓ Security enabled with custom admin user: $AXONOPS_SEARCH_USER"
else
    echo "✓ Security enabled with default admin user"
    echo "  Default credentials: admin / MyS3cur3P@ss2025"
fi
echo ""

# Write semaphore file immediately (no background init script needed)
mkdir -p ${OPENSEARCH_DATA_DIR}/.axonops
{
    echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "RESULT=success"
    if [ -n "$AXONOPS_SEARCH_USER" ]; then
        echo "REASON=custom_user_created_prestartup"
        echo "ADMIN_USER=${AXONOPS_SEARCH_USER}"
    else
        echo "REASON=default_config"
    fi
} > ${OPENSEARCH_DATA_DIR}/.axonops/init-security.done
echo "✓ Semaphore written (pre-startup configuration complete)"
echo ""

# Parse Docker env vars to customize OpenSearch
# e.g. Setting the env var cluster.name=testcluster
# will cause OpenSearch to be invoked with -Ecluster.name=testcluster
opensearch_opts=()

# Handle special OpenSearch control variables (not dotted notation)
# These need to be handled before the general environment variable parsing
if [ "$DISABLE_SECURITY_PLUGIN" = "true" ]; then
    echo "Security plugin disabled (DISABLE_SECURITY_PLUGIN=true)"
    opensearch_opt="-Eplugins.security.disabled=true"
    opensearch_opts+=("${opensearch_opt}")
fi

# Parse environment variables with dotted notation
while IFS='=' read -r envvar_key envvar_value
do
    # OpenSearch settings need to have at least two dot separated lowercase
    # words, e.g. `cluster.name`, except for `processors` which we handle
    # specially
    if [[ "$envvar_key" =~ ^[a-z0-9_]+\.[a-z0-9_]+ || "$envvar_key" == "processors" ]]; then
        if [[ ! -z $envvar_value ]]; then
        opensearch_opt="-E${envvar_key}=${envvar_value}"
        opensearch_opts+=("${opensearch_opt}")
        fi
    fi
done < <(env)

if [ ${#opensearch_opts[@]} -gt 0 ]; then
    echo "Additional OpenSearch options from environment variables:"
    for opt in "${opensearch_opts[@]}"; do
        echo "  $opt"
    done
    echo ""
fi

echo ""
echo "=== Starting OpenSearch ==="
echo ""

# Prepend "opensearch" command if no argument was provided or if the first
# argument looks like a flag (i.e. starts with a dash).
if [ $# -eq 0 ] || [ "${1:0:1}" = '-' ]; then
    set -- opensearch "$@"
fi

# Execute command (CMD is ["opensearch"] which gets passed as $@)
exec "$@" "${opensearch_opts[@]}"
