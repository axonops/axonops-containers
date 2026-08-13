#!/bin/bash
# AxonDB Time-Series Health Check
# Usage: healthcheck.sh {startup|liveness|readiness}

set -euo pipefail

MODE="${1:-readiness}"
CQL_PORT="${CASSANDRA_NATIVE_TRANSPORT_PORT:-9042}"
TIMEOUT="${HEALTH_CHECK_TIMEOUT:-10}"

# Script name for logging (combined with mode for context)
SCRIPT_NAME=$(basename "$0" .sh)

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [${SCRIPT_NAME}:$MODE] $*" >&2
}

case "$MODE" in
  startup)
    # Lightweight startup check with init script coordination
    log "Checking if Cassandra is starting"

    # CRITICAL: Check if restore was requested
    # Semaphore is in /tmp (ephemeral, not backed up with .axonops)
    RESTORE_SEMAPHORE="/tmp/axonops-restore.done"
    if [ -n "${RESTORE_FROM_BACKUP:-}" ] || [ "${RESTORE_ENABLED:-false}" = "true" ]; then
      # Restore was requested - check semaphore
      if [ ! -f "$RESTORE_SEMAPHORE" ]; then
        log "Waiting for restore to start (semaphore not found)"
        exit 1
      fi

      RESTORE_RESULT=$(grep "^RESULT=" "$RESTORE_SEMAPHORE" | cut -d'=' -f2)
      if [ "$RESTORE_RESULT" = "failed" ]; then
        RESTORE_REASON=$(grep "^REASON=" "$RESTORE_SEMAPHORE" | cut -d'=' -f2)
        log "ERROR: Restore failed: ${RESTORE_REASON}"
        exit 1
      fi

      # Allow in_progress or success for startup probe
      log "Restore status: ${RESTORE_RESULT}"
    fi

    # CRITICAL: Check if system keyspace init script semaphore exists
    # Located in /var/lib/cassandra (persistent volume) not /etc (ephemeral)
    INIT_KEYSPACE_SEMAPHORE="/var/lib/cassandra/.axonops/init-system-keyspaces.done"
    if [ ! -f "$INIT_KEYSPACE_SEMAPHORE" ]; then
      log "Waiting for system keyspace init script to complete (semaphore not found)"
      exit 1
    fi

    # CRITICAL: Check if database user init script semaphore exists
    INIT_USER_SEMAPHORE="/var/lib/cassandra/.axonops/init-db-user.done"
    if [ ! -f "$INIT_USER_SEMAPHORE" ]; then
      log "Waiting for database user init script to complete (semaphore not found)"
      exit 1
    fi

    # CRITICAL: Check RESULT field in semaphore files - fail if initialization failed
    KEYSPACE_RESULT=$(grep "^RESULT=" "$INIT_KEYSPACE_SEMAPHORE" | cut -d'=' -f2)
    if [ "$KEYSPACE_RESULT" = "failed" ]; then
      KEYSPACE_REASON=$(grep "^REASON=" "$INIT_KEYSPACE_SEMAPHORE" | cut -d'=' -f2)
      log "ERROR: System keyspace initialization failed: ${KEYSPACE_REASON}"
      exit 1
    fi

    USER_RESULT=$(grep "^RESULT=" "$INIT_USER_SEMAPHORE" | cut -d'=' -f2)
    if [ "$USER_RESULT" = "failed" ]; then
      USER_REASON=$(grep "^REASON=" "$INIT_USER_SEMAPHORE" | cut -d'=' -f2)
      log "ERROR: Database user initialization failed: ${USER_REASON}"
      exit 1
    fi

    # Check if Cassandra process is running
    if ! pgrep -f cassandra > /dev/null 2>&1; then
      log "Cassandra process not running"
      exit 1
    fi

    # Check if native transport port is listening
    if ! nc -z localhost "$CQL_PORT" 2>/dev/null; then
      log "CQL port $CQL_PORT not listening"
      exit 1
    fi

    log "Startup check passed (init: ${KEYSPACE_RESULT}/${USER_RESULT}, process running, port listening)"
    exit 0
    ;;

  liveness)
    # Ultra-lightweight liveness check (runs every 10 seconds)
    log "Checking liveness"

    # Check if Cassandra process is running
    if ! pgrep -f cassandra > /dev/null 2>&1; then
      log "ERROR: Cassandra process not running"
      exit 1
    fi

    # Check if native transport port is listening
    if ! nc -z localhost "$CQL_PORT" 2>/dev/null; then
      log "ERROR: CQL port $CQL_PORT not listening"
      exit 1
    fi

    log "Liveness check passed (process running + port listening)"
    exit 0
    ;;

  readiness)
    log "Checking readiness"

    # CRITICAL: Check if restore was requested - BLOCK until complete
    # Semaphore is in /tmp (ephemeral, not backed up with .axonops)
    RESTORE_SEMAPHORE="/tmp/axonops-restore.done"
    if [ -n "${RESTORE_FROM_BACKUP:-}" ] || [ "${RESTORE_ENABLED:-false}" = "true" ]; then
      # Restore was requested - check semaphore
      if [ ! -f "$RESTORE_SEMAPHORE" ]; then
        log "Waiting for restore to complete (semaphore not found)"
        exit 1
      fi

      RESTORE_RESULT=$(grep "^RESULT=" "$RESTORE_SEMAPHORE" | cut -d'=' -f2)

      if [ "$RESTORE_RESULT" = "in_progress" ]; then
        log "Waiting for restore to complete (currently in progress)"
        exit 1
      fi

      if [ "$RESTORE_RESULT" = "failed" ]; then
        RESTORE_REASON=$(grep "^REASON=" "$RESTORE_SEMAPHORE" | cut -d'=' -f2)
        log "ERROR: Restore failed: ${RESTORE_REASON}"
        exit 1
      fi

      # Only continue if success
      log "Restore completed: ${RESTORE_RESULT}"
    fi

    # Check if native transport port is listening
    if ! nc -z localhost "$CQL_PORT" 2>/dev/null; then
      log "ERROR: CQL port $CQL_PORT not listening"
      exit 1
    fi

    # Check native transport and gossip via nodetool info
    INFO=$(timeout "$TIMEOUT" nodetool info 2>/dev/null)

    # Handle variable whitespace in nodetool info output (e.g., "Native Transport active          : true")
    if ! echo "$INFO" | grep -E "Native Transport active[[:space:]]*:[[:space:]]*true" > /dev/null; then
      log "ERROR: Native transport not active"
      echo "$INFO" | grep "Native Transport" >&2 || true
      exit 1
    fi

    if ! echo "$INFO" | grep -E "Gossip active[[:space:]]*:[[:space:]]*true" > /dev/null; then
      log "ERROR: Gossip not active"
      echo "$INFO" | grep "Gossip" >&2 || true
      exit 1
    fi

    log "Readiness check passed (port listening + native transport active + gossip active)"
    exit 0
    ;;

  *)
    log "ERROR: Invalid mode. Usage: $0 {startup|liveness|readiness}"
    exit 1
    ;;
esac
