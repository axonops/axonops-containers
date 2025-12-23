#!/bin/bash
set -e

# ============================================================================
# Cassandra Wrapper Script
# Purpose: Wait for restore to complete (if requested), then start Cassandra
# ============================================================================
# This wrapper decouples restore from entrypoint blocking:
# - Entrypoint spawns restore in background and execs this wrapper (non-blocking)
# - This wrapper waits for restore to complete (blocking, but entrypoint already returned)
# - Then starts Cassandra with restored data
# This prevents Kubernetes startup probe timeouts on long restores

log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [WRAPPER] $*"
}

log "Cassandra wrapper starting"

# Check if restore was requested
RESTORE_SEMAPHORE="/var/lib/cassandra/.axonops/restore.done"

if [ -n "${RESTORE_FROM_BACKUP:-}" ] || [ "${RESTORE_ENABLED:-false}" = "true" ]; then
    log "Restore requested - waiting for restore to complete before starting Cassandra"
    log "This prevents data corruption from starting Cassandra during data copy"

    # Wait for restore to complete (check every 2 seconds)
    WAIT_COUNT=0
    while true; do
        if [ -f "$RESTORE_SEMAPHORE" ]; then
            RESTORE_RESULT=$(grep "^RESULT=" "$RESTORE_SEMAPHORE" | cut -d'=' -f2)

            if [ "$RESTORE_RESULT" = "success" ]; then
                log "✓ Restore completed successfully - starting Cassandra with restored data"
                break
            elif [ "$RESTORE_RESULT" = "failed" ]; then
                RESTORE_REASON=$(grep "^REASON=" "$RESTORE_SEMAPHORE" | cut -d'=' -f2 || echo "unknown")
                log "ERROR: Restore failed (RESULT=$RESTORE_RESULT, REASON=$RESTORE_REASON)"
                log "Cannot start Cassandra with failed restore"
                exit 1
            elif [ "$RESTORE_RESULT" = "in_progress" ]; then
                # Still in progress - keep waiting
                WAIT_COUNT=$((WAIT_COUNT + 1))

                # Log progress every 30 checks (60 seconds)
                if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
                    log "Still waiting for restore to complete (waited $((WAIT_COUNT * 2))s)..."
                fi

                sleep 2
            else
                log "WARNING: Unknown restore result: $RESTORE_RESULT (waiting...)"
                sleep 2
            fi
        else
            # Semaphore doesn't exist yet - restore script hasn't started
            log "Waiting for restore script to start (semaphore not found)..."
            sleep 2
        fi
    done
else
    log "No restore requested - starting Cassandra normally"
fi

# Start Cassandra (replace this process with Cassandra)
log "Executing Cassandra: $@"
exec "$@"
