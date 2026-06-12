#!/bin/bash
set -euo pipefail

# ============================================================================
# Semaphore Monitoring Script
# Purpose: Monitor semaphore states and echo to console for kubectl logs visibility
# ============================================================================
# Checks all semaphore files every N seconds (default: 60)
# Echoes to console if state is in_progress, error, or failed
# Provides visibility into long-running operations in kubectl logs

MONITOR_INTERVAL="${SEMAPHORE_MONITOR_INTERVAL:-60}"

# Script name for dynamic logging (auto-detect from $0)
SCRIPT_NAME=$(basename "$0" .sh)

log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [${SCRIPT_NAME}] $*"
}

log "Semaphore monitor starting (interval: ${MONITOR_INTERVAL}s)"

# Wait a bit before first check (let container initialize)
sleep 30

while true; do
    FOUND_ISSUES=false

    # Check ephemeral semaphores in /tmp
    for sem in /tmp/axonops-*.lock /tmp/axonops-*.done; do
        if [ -f "$sem" ]; then
            # Read state/result
            STATE=$(grep -E "^STATE=|^RESULT=" "$sem" 2>/dev/null | cut -d'=' -f2 || echo "")

            if [ -z "$STATE" ]; then
                continue
            fi

            # Alert on in_progress, error, or failed states
            if [ "$STATE" = "in_progress" ] || [ "$STATE" = "error" ] || [ "$STATE" = "failed" ]; then
                FOUND_ISSUES=true
                SEM_NAME=$(basename "$sem")

                log "======================================"
                log "ALERT: $(basename $sem .lock | basename .done) - STATE: $STATE"
                log "======================================"

                # Show full semaphore details
                while IFS= read -r line; do
                    log "  $line"
                done < "$sem"

                log "======================================"
            fi
        fi
    done

    # Check persistent semaphores in .axonops (init/user creation)
    if [ -d "/var/lib/cassandra/.axonops" ]; then
        for sem in /var/lib/cassandra/.axonops/*.done; do
            if [ -f "$sem" ]; then
                # Read result
                RESULT=$(grep "^RESULT=" "$sem" 2>/dev/null | cut -d'=' -f2 || echo "")

                if [ -z "$RESULT" ]; then
                    continue
                fi

                # Alert on failed or in_progress states
                if [ "$RESULT" = "in_progress" ] || [ "$RESULT" = "failed" ]; then
                    FOUND_ISSUES=true
                    SEM_NAME=$(basename "$sem")

                    log "======================================"
                    log "ALERT: $SEM_NAME - RESULT: $RESULT"
                    log "======================================"

                    # Show full semaphore details
                    while IFS= read -r line; do
                        log "  $line"
                    done < "$sem"

                    log "======================================"
                fi
            fi
        done
    fi

    if [ "$FOUND_ISSUES" = "false" ]; then
        # Periodic heartbeat (every 10 intervals = 10 minutes by default)
        ITERATION=$((${ITERATION:-0} + 1))
        if [ $((ITERATION % 10)) -eq 0 ]; then
            log "Heartbeat: All semaphores OK (checked ${ITERATION} times)"
        fi
    fi

    # Rotate log file if needed (every check cycle)
    # Prevents unbounded growth from continuous monitoring
    MONITOR_LOG="/var/log/cassandra/semaphore-monitor.log"
    ROTATE_SIZE_MB="${SEMAPHORE_MONITOR_LOG_ROTATE_SIZE_MB:-5}"  # Smaller default (5MB)
    ROTATE_KEEP="${SEMAPHORE_MONITOR_LOG_ROTATE_KEEP:-3}"  # Less history needed

    /usr/local/bin/log-rotate.sh "$MONITOR_LOG" "$ROTATE_SIZE_MB" "$ROTATE_KEEP" 2>/dev/null || true

    sleep "$MONITOR_INTERVAL"
done
