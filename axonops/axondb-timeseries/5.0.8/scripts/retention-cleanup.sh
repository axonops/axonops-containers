#!/bin/bash
set -euo pipefail

# ============================================================================
# Retention Cleanup Script (Async)
# Purpose: Delete old backups asynchronously with timeout and semaphore
# ============================================================================
# This script is spawned in background by cassandra-backup.sh
# It allows backup to complete immediately while deletion happens async

# Script name for dynamic logging (auto-detect from $0)
SCRIPT_NAME=$(basename "$0" .sh)

# Logging (uses dynamic script name)
log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [${SCRIPT_NAME}] $*"
}

log_error() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [${SCRIPT_NAME}] ERROR: $*" >&2
}

# Timing
START_TIME=$(date +%s)
get_duration() {
    local start=$1
    local end=$(date +%s)
    local duration=$((end - start))
    if [ $duration -ge 60 ]; then
        echo "$((duration / 60))m $((duration % 60))s"
    else
        echo "${duration}s"
    fi
}

log "Starting retention cleanup"

# Semaphore for this cleanup process
# CRITICAL: In /tmp (ephemeral) not .axonops (would be backed up!)
CLEANUP_SEMAPHORE="/tmp/axonops-retention-cleanup.lock"
CLEANUP_TIMEOUT_MINUTES="${RETENTION_CLEANUP_TIMEOUT_MINUTES:-60}"

# Write semaphore
write_semaphore() {
    local state="$1"
    local reason="${2:-}"

    {
        echo "STARTED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "PID=$$"
        echo "STATE=$state"
        [ -n "$reason" ] && echo "REASON=$reason"
    } > "$CLEANUP_SEMAPHORE"

    log "Semaphore: STATE=$state${reason:+, REASON=$reason}"
}

# Trap to always update semaphore on exit
cleanup_on_exit() {
    local exit_code=$?
    local duration=$(get_duration $START_TIME)

    if [ $exit_code -eq 0 ]; then
        write_semaphore "success" "cleanup_completed"
        log "✓ Retention cleanup completed (took ${duration})"
    elif [ $exit_code -eq 124 ]; then
        write_semaphore "timeout" "exceeded_${CLEANUP_TIMEOUT_MINUTES}min"
        log_error "Retention cleanup timed out after ${CLEANUP_TIMEOUT_MINUTES} minutes"
    else
        write_semaphore "error" "exit_code_${exit_code}"
        log_error "Retention cleanup failed after ${duration} (exit code: $exit_code)"
    fi

    # Remove lock after updating state
    rm -f "$CLEANUP_SEMAPHORE" 2>/dev/null || true
}

trap cleanup_on_exit EXIT

# Write in_progress state
write_semaphore "in_progress" "deleting_old_backups"

# Read backup list from arguments or stdin
if [ $# -gt 0 ]; then
    # Backups passed as arguments
    BACKUPS_TO_DELETE="$@"
else
    # Read from stdin
    BACKUPS_TO_DELETE=$(cat)
fi

if [ -z "$BACKUPS_TO_DELETE" ]; then
    log "No backups to delete"
    exit 0
fi

# Count backups to delete
DELETE_COUNT=$(echo "$BACKUPS_TO_DELETE" | wc -l)
log "Deleting ${DELETE_COUNT} old backup(s)..."

# Delete each backup with timeout wrapper
DELETED=0
FAILED=0

# Timeout for entire cleanup operation
# Pass backup list via stdin to timeout command
# Export SCRIPT_NAME for subshell
export SCRIPT_NAME
echo "$BACKUPS_TO_DELETE" | timeout ${CLEANUP_TIMEOUT_MINUTES}m bash -c '
while IFS= read -r backup_path; do
    if [ -z "$backup_path" ]; then
        continue
    fi

    backup_name=$(basename "$backup_path")

    echo "[$(date -u +'"'"'%Y-%m-%dT%H:%M:%SZ'"'"')] [${SCRIPT_NAME}]   Deleting: $backup_name"

    if rm -rf "$backup_path" 2>&1; then
        echo "[$(date -u +'"'"'%Y-%m-%dT%H:%M:%SZ'"'"')] [${SCRIPT_NAME}]     ✓ Deleted: $backup_name"
    else
        echo "[$(date -u +'"'"'%Y-%m-%dT%H:%M:%SZ'"'"')] [${SCRIPT_NAME}]     ✗ Failed to delete: $backup_name"
    fi
done
'

CLEANUP_EXIT=$?

if [ $CLEANUP_EXIT -eq 124 ]; then
    log_error "Cleanup timed out after ${CLEANUP_TIMEOUT_MINUTES} minutes"
    log_error "Some backups may not have been deleted"
    exit 124
elif [ $CLEANUP_EXIT -ne 0 ]; then
    log_error "Cleanup failed with exit code $CLEANUP_EXIT"
    exit $CLEANUP_EXIT
fi

log "✓ All old backups deleted successfully"

# Rotate log file if needed (size-based, compressed, retained)
# Configurable via env vars (defaults: 10MB, keep 5 rotations)
LOG_FILE="/var/log/cassandra/retention-cleanup.log"
ROTATE_SIZE_MB="${RETENTION_LOG_ROTATE_SIZE_MB:-10}"
ROTATE_KEEP="${RETENTION_LOG_ROTATE_KEEP:-5}"

/usr/local/bin/log-rotate.sh "$LOG_FILE" "$ROTATE_SIZE_MB" "$ROTATE_KEEP" 2>/dev/null || true

exit 0
