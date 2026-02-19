#!/bin/bash
# AxonOps Schema Registry Health Check
# Usage: healthcheck.sh {startup|liveness|readiness}

set -euo pipefail

MODE="${1:-readiness}"
SR_PORT="${SR_PORT:-8081}"
TIMEOUT="${HEALTH_CHECK_TIMEOUT:-10}"

# Script name for logging (combined with mode for context)
SCRIPT_NAME=$(basename "$0" .sh)

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [${SCRIPT_NAME}:$MODE] $*" >&2
}

case "$MODE" in
  startup)
    # Lightweight startup check — process running and port listening
    log "Checking if Schema Registry is starting"

    # Check if axonops-schema-registry process is running
    if ! pgrep -f axonops-schema-registry > /dev/null 2>&1; then
      log "Schema Registry process not running"
      exit 1
    fi

    # Check if API port is listening
    if ! curl -sf --max-time 2 -o /dev/null "http://localhost:${SR_PORT}/" 2>/dev/null; then
      log "API port $SR_PORT not responding"
      exit 1
    fi

    log "Startup check passed (process running, port responding)"
    exit 0
    ;;

  liveness)
    # Ultra-lightweight liveness check (runs frequently)
    log "Checking liveness"

    # Check if axonops-schema-registry process is running
    if ! pgrep -f axonops-schema-registry > /dev/null 2>&1; then
      log "ERROR: Schema Registry process not running"
      exit 1
    fi

    log "Liveness check passed (process running)"
    exit 0
    ;;

  readiness)
    log "Checking readiness"

    # Full HTTP health check — app responds to API requests
    HTTP_CODE=$(curl -sf --max-time "$TIMEOUT" -o /dev/null -w "%{http_code}" "http://localhost:${SR_PORT}/" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
      log "Readiness check passed (HTTP 200)"
      exit 0
    fi

    log "ERROR: Health endpoint returned HTTP $HTTP_CODE"
    exit 1
    ;;

  *)
    log "ERROR: Invalid mode. Usage: $0 {startup|liveness|readiness}"
    exit 1
    ;;
esac
