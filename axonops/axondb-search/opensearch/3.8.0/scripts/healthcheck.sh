#!/bin/bash
# AxonDB Search Health Check
# Usage: healthcheck.sh {startup|liveness|readiness}

set -euo pipefail

MODE="${1:-readiness}"
HTTP_PORT="${OPENSEARCH_HTTP_PORT:-9200}"
TIMEOUT="${HEALTH_CHECK_TIMEOUT:-10}"
OPENSEARCH_DATA_DIR="${OPENSEARCH_DATA_DIR:-/var/lib/opensearch}"
AXONOPS_SEARCH_USER="${AXONOPS_SEARCH_USER:-}"
AXONOPS_SEARCH_PASSWORD="${AXONOPS_SEARCH_PASSWORD:-}"
DISABLE_SECURITY_PLUGIN="${DISABLE_SECURITY_PLUGIN:-false}"

# Determine protocol (HTTP or HTTPS) based on TLS setting
# When security plugin is disabled, always use HTTP
AXONOPS_SEARCH_TLS_ENABLED="${AXONOPS_SEARCH_TLS_ENABLED:-true}"
if [ "$DISABLE_SECURITY_PLUGIN" = "true" ] || [ "$AXONOPS_SEARCH_TLS_ENABLED" = "false" ]; then
  PROTOCOL="http"
else
  PROTOCOL="https"
fi

# Set authentication options if security plugin is enabled
CURL_OPTS=""
SECURITY_ENABLED="true"
if [ "$DISABLE_SECURITY_PLUGIN" = "true" ] || grep -q '^plugins.security.disabled: true' /etc/opensearch/opensearch.yml 2>/dev/null; then
  SECURITY_ENABLED="false"
else
  CURL_OPTS="-u ${AXONOPS_SEARCH_USER:-admin}:${AXONOPS_SEARCH_PASSWORD:-MyS3cur3P@ss2025}"
fi

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [$MODE] $*" >&2
}

case "$MODE" in
  startup)
    # Lightweight startup check with init script coordination
    log "Checking if OpenSearch is starting"

    # CRITICAL: Check if security init script semaphore exists
    # Located in /var/lib/opensearch (persistent volume) not /etc (ephemeral)
    INIT_SECURITY_SEMAPHORE="${OPENSEARCH_DATA_DIR}/.axonops/init-security.done"
    if [ ! -f "$INIT_SECURITY_SEMAPHORE" ]; then
      log "Waiting for security init script to complete (semaphore not found)"
      exit 1
    fi

    # CRITICAL: Check RESULT field in semaphore file - fail if initialization failed
    SECURITY_RESULT=$(grep "^RESULT=" "$INIT_SECURITY_SEMAPHORE" | cut -d'=' -f2)
    if [ "$SECURITY_RESULT" = "failed" ]; then
      SECURITY_REASON=$(grep "^REASON=" "$INIT_SECURITY_SEMAPHORE" | cut -d'=' -f2)
      log "ERROR: Security initialization failed: ${SECURITY_REASON}"
      exit 1
    fi

    # Check if OpenSearch Java process is running
    if ! pgrep -f "org.opensearch.bootstrap.OpenSearch" > /dev/null 2>&1; then
      log "OpenSearch process not running"
      exit 1
    fi

    # Check if port 9200 is listening (TCP check)
    if ! nc -z localhost "$HTTP_PORT" 2>/dev/null; then
      log "Port $HTTP_PORT not listening"
      exit 1
    fi

    # Check health endpoint (security plugin endpoint if enabled, otherwise cluster health)
    if [ "$SECURITY_ENABLED" = "true" ]; then
      HEALTH_CHECK=$(timeout "$TIMEOUT" curl -s --insecure $CURL_OPTS "${PROTOCOL}://localhost:${HTTP_PORT}/_plugins/_security/health" 2>/dev/null || echo "")
      if [ -z "$HEALTH_CHECK" ] || ! echo "$HEALTH_CHECK" | grep -q "message"; then
        log "Security health endpoint not responding"
        exit 1
      fi
      log "Startup check passed (init: ${SECURITY_RESULT}, process running, port listening, security health OK)"
    else
      HEALTH_CHECK=$(timeout "$TIMEOUT" curl -s "${PROTOCOL}://localhost:${HTTP_PORT}/_cluster/health" 2>/dev/null || echo "")
      if [ -z "$HEALTH_CHECK" ] || ! echo "$HEALTH_CHECK" | grep -q "status"; then
        log "Cluster health endpoint not responding"
        exit 1
      fi
      log "Startup check passed (init: ${SECURITY_RESULT}, process running, port listening, cluster health OK)"
    fi
    exit 0
    ;;

  liveness)
    # Ultra-lightweight liveness check (runs every 10 seconds)
    log "Checking liveness"

    # Check if OpenSearch process is running
    if ! pgrep -f "org.opensearch.bootstrap.OpenSearch" > /dev/null 2>&1; then
      log "ERROR: OpenSearch process not running"
      exit 1
    fi

    # Check if port 9200 is listening (TCP check)
    if ! nc -z localhost "$HTTP_PORT" 2>/dev/null; then
      log "ERROR: Port $HTTP_PORT not listening"
      exit 1
    fi

    # Check health endpoint (security plugin endpoint if enabled, otherwise cluster health)
    if [ "$SECURITY_ENABLED" = "true" ]; then
      HEALTH_CHECK=$(timeout "$TIMEOUT" curl -s --insecure $CURL_OPTS "${PROTOCOL}://localhost:${HTTP_PORT}/_plugins/_security/health" 2>/dev/null || echo "")
      if [ -z "$HEALTH_CHECK" ] || ! echo "$HEALTH_CHECK" | grep -q "message"; then
        log "ERROR: Security health endpoint not responding"
        exit 1
      fi
      log "Liveness check passed (process running + port listening + security health OK)"
    else
      HEALTH_CHECK=$(timeout "$TIMEOUT" curl -s "${PROTOCOL}://localhost:${HTTP_PORT}/_cluster/health" 2>/dev/null || echo "")
      if [ -z "$HEALTH_CHECK" ] || ! echo "$HEALTH_CHECK" | grep -q "status"; then
        log "ERROR: Cluster health endpoint not responding"
        exit 1
      fi
      log "Liveness check passed (process running + port listening + cluster health OK)"
    fi
    exit 0
    ;;

  readiness)
    # Readiness check with cluster health verification
    log "Checking readiness"

    # Check if port 9200 is listening (TCP check)
    if ! nc -z localhost "$HTTP_PORT" 2>/dev/null; then
      log "ERROR: Port $HTTP_PORT not listening"
      exit 1
    fi

    # Make HTTP GET request to /_cluster/health
    # When security is enabled: use --insecure (demo SSL certs) and auth credentials
    # When security is disabled: plain HTTP, no auth
    if [ "$SECURITY_ENABLED" = "true" ]; then
      HEALTH_RESPONSE=$(timeout "$TIMEOUT" curl -s --insecure $CURL_OPTS -XGET "${PROTOCOL}://localhost:${HTTP_PORT}/_cluster/health" 2>/dev/null || echo "")
    else
      HEALTH_RESPONSE=$(timeout "$TIMEOUT" curl -s -XGET "${PROTOCOL}://localhost:${HTTP_PORT}/_cluster/health" 2>/dev/null || echo "")
    fi

    if [ -z "$HEALTH_RESPONSE" ]; then
      log "ERROR: Failed to get cluster health response"
      exit 1
    fi

    # Check if response contains status field (indicates valid response)
    if ! echo "$HEALTH_RESPONSE" | grep -q '"status"'; then
      log "ERROR: Invalid cluster health response"
      echo "$HEALTH_RESPONSE" >&2
      exit 1
    fi

    # Extract cluster status and verify it's not "red"
    CLUSTER_STATUS=$(echo "$HEALTH_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d':' -f2 | tr -d '"')

    if [ "$CLUSTER_STATUS" = "red" ]; then
      log "ERROR: Cluster status is red (unhealthy)"
      exit 1
    fi

    log "Readiness check passed (port listening + cluster status: ${CLUSTER_STATUS})"
    exit 0
    ;;

  *)
    log "ERROR: Invalid mode. Usage: $0 {startup|liveness|readiness}"
    exit 1
    ;;
esac
