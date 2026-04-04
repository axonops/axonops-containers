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

# Script name for dynamic logging (auto-detect from $0)
SCRIPT_NAME=$(basename "$0" .sh)

log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [${SCRIPT_NAME}] $*"
}

log "Cassandra wrapper starting"

# Check if restore was requested
# Semaphore is in /tmp (ephemeral, not backed up with .axonops)
RESTORE_SEMAPHORE="/tmp/axonops-restore.done"

if [ -n "${RESTORE_FROM_BACKUP:-}" ] || [ "${RESTORE_ENABLED:-false}" = "true" ]; then
    log "Restore requested - waiting for restore to complete before starting Cassandra"
    log "This prevents data corruption from starting Cassandra during data copy"

    # Wait for restore to complete (check every 2 seconds)
    WAIT_COUNT=0
    while true; do
        if [ -f "$RESTORE_SEMAPHORE" ]; then
            RESTORE_RESULT=$(grep "^RESULT=" "$RESTORE_SEMAPHORE" | cut -d'=' -f2)

            if [ "$RESTORE_RESULT" = "success" ]; then
                log "✓ Restore completed successfully"

                # Check if credential reset was performed
                if grep -q "CREDENTIALS_RESET=true" "$RESTORE_SEMAPHORE" 2>/dev/null; then
                    log "Credential reset detected - custom user creation may be needed"
                    # Start Cassandra first, then run post-restore user creation
                    # User creation script will run AFTER we start Cassandra (it waits for CQL ready)
                    CREDENTIAL_RESET_PERFORMED=true
                fi

                log "Starting Cassandra with restored data"
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
                    log "Still waiting for restore to complete (waited $((WAIT_COUNT * 10))s)..."
                fi

                sleep 10
            else
                log "WARNING: Unknown restore result: $RESTORE_RESULT (waiting...)"
                sleep 10
            fi
        else
            # Semaphore doesn't exist yet - restore script hasn't started
            log "Waiting for restore script to start (semaphore not found)..."
            sleep 10
        fi
    done
else
    log "No restore requested - starting Cassandra normally"
fi

# Start Cassandra (replace this process with Cassandra)
# If credential reset was performed, start post-restore user creation in background
if [ "${CREDENTIAL_RESET_PERFORMED:-false}" = "true" ]; then
    log "Starting post-restore user creation in background..."
    (/usr/local/bin/post-restore-create-user.sh > /var/log/cassandra/post-restore-user.log 2>&1 &)
fi

log "Executing Cassandra: $@"
exec "$@"
