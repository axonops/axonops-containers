#!/bin/bash
set -euo pipefail

# ============================================================================
# Cassandra Backup Scheduler
# Purpose: Run scheduled backups in background (container-native, no cron needed)
# ============================================================================

# Script name for dynamic logging (auto-detect from $0)
SCRIPT_NAME=$(basename "$0" .sh)

log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [${SCRIPT_NAME}] $*"
}

# Log rotation configuration for scheduler log
# This script's output is redirected to backup-scheduler.log by entrypoint
SCHEDULER_LOG="/var/log/cassandra/backup-scheduler.log"
SCHEDULER_LOG_SIZE_MB="${SCHEDULER_LOG_ROTATE_SIZE_MB:-10}"
SCHEDULER_LOG_KEEP="${SCHEDULER_LOG_ROTATE_KEEP:-5}"

log "Backup scheduler starting"

# CRITICAL: BACKUP_SCHEDULE is mandatory (no defaults!)
if [ -z "${BACKUP_SCHEDULE:-}" ]; then
    log "ERROR: BACKUP_SCHEDULE not set"
    log "This script should only be started if BACKUP_SCHEDULE is provided"
    log "Check entrypoint.sh configuration"
    exit 1
fi

log "Schedule: ${BACKUP_SCHEDULE}"

# Parse cron schedule to determine interval in minutes
# For simplicity, we'll support */N format (every N minutes/hours)
# Example: "*/6 * * * *" = every 6 minutes
# Example: "0 */6 * * *" = every 6 hours

SCHEDULE="${BACKUP_SCHEDULE}"

# Simple parser for common patterns
if echo "$SCHEDULE" | grep -qE '^\*/[0-9]+ \* \* \* \*$'; then
    # Pattern: */N * * * * (every N minutes)
    INTERVAL_MINUTES=$(echo "$SCHEDULE" | grep -oE '^\*/[0-9]+' | cut -d'/' -f2)
    log "Detected schedule: Every ${INTERVAL_MINUTES} minutes"
elif echo "$SCHEDULE" | grep -qE '^0 \*/[0-9]+ \* \* \*$'; then
    # Pattern: 0 */N * * * (every N hours)
    INTERVAL_HOURS=$(echo "$SCHEDULE" | grep -oE '\*/[0-9]+' | cut -d'/' -f2)
    INTERVAL_MINUTES=$((INTERVAL_HOURS * 60))
    log "Detected schedule: Every ${INTERVAL_HOURS} hours (${INTERVAL_MINUTES} minutes)"
else
    # Cannot parse - ERROR
    log "ERROR: Could not parse schedule pattern: $SCHEDULE"
    log "Supported patterns:"
    log "  */N * * * *  (every N minutes)"
    log "  0 */N * * *  (every N hours)"
    exit 1
fi

INTERVAL_SECONDS=$((INTERVAL_MINUTES * 60))
# Format as HH:MM:SS for readability (#6)
HOURS=$((INTERVAL_SECONDS / 3600))
MINUTES=$(((INTERVAL_SECONDS % 3600) / 60))
SECONDS=$((INTERVAL_SECONDS % 60))
log "Running backups every $(printf '%02d:%02d:%02d' $HOURS $MINUTES $SECONDS)"

# Wait for Cassandra to be ready before first backup
log "Waiting for Cassandra to be ready..."

MAX_WAIT=300
ELAPSED=0
until nc -z localhost 9042 2>/dev/null; do
    if [ $ELAPSED -gt $MAX_WAIT ]; then
        log "WARNING: Cassandra not ready after ${MAX_WAIT}s"
        log "Will retry on next backup cycle"
        break
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if nc -z localhost 9042 2>/dev/null; then
    log "Cassandra is ready, starting backup schedule"
else
    log "WARNING: Cassandra not ready after ${MAX_WAIT}s"
    log "Starting scheduler anyway - backup script will handle errors"
fi

# Main backup loop
while true; do
    log "Triggering scheduled backup..."

    # Run backup via wrapper script
    # Wrapper uses tee to output to BOTH console (for kubectl logs) and file
    /usr/local/bin/backup-cron-wrapper.sh

    # Check exit code
    BACKUP_EXIT=$?
    if [ $BACKUP_EXIT -eq 0 ]; then
        log "Backup completed successfully"
    else
        log "WARNING: Backup failed or was skipped (exit code $BACKUP_EXIT)"
    fi

    # Rotate scheduler log if needed (this script's output is redirected to backup-scheduler.log)
    /usr/local/bin/log-rotate.sh "$SCHEDULER_LOG" "$SCHEDULER_LOG_SIZE_MB" "$SCHEDULER_LOG_KEEP" 2>/dev/null || true

    log "Sleeping for ${INTERVAL_MINUTES} minutes until next backup..."
    sleep "$INTERVAL_SECONDS"
done
