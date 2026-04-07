#!/bin/bash
set -euo pipefail

if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# ============================================================================
# AxonDB Cassandra Restore Script
# Purpose: Restore Cassandra data from backup
# ============================================================================


# Script name for dynamic logging (auto-detect from $0)
SCRIPT_NAME=$(basename "$0" .sh)


# Logging helper with timestamps (uses dynamic script name)
log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [${SCRIPT_NAME}] $*"
}


log_error() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [${SCRIPT_NAME}] ERROR: $*" >&2
}


# Timing helper
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


log "Starting Cassandra restore"


# Rotate restore log if needed before starting (preserve history across restores)
# Note: This script's output is redirected to this log by entrypoint.sh
RESTORE_LOG="/var/log/cassandra/restore.log"
ROTATE_SIZE_MB="${RESTORE_LOG_ROTATE_SIZE_MB:-10}"
ROTATE_KEEP="${RESTORE_LOG_ROTATE_KEEP:-5}"


/usr/local/bin/log-rotate.sh "$RESTORE_LOG" "$ROTATE_SIZE_MB" "$ROTATE_KEEP" 2>/dev/null || true


# ============================================================================
# Semaphore Management
# ============================================================================


# CRITICAL: Restore semaphore must be ephemeral (not in .axonops which gets backed up!)
# Restoring old "success" semaphore would confuse health checks
SEMAPHORE_FILE="/tmp/axonops-restore.done"


# Write semaphore file with result and reason
write_semaphore() {
    local result="$1"
    local reason="${2:-}"
    local backup_name="${3:-}"


    # /tmp always exists, no mkdir needed
    {
        echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "RESULT=$result"
        [ -n "$reason" ] && echo "REASON=$reason"
        [ -n "$backup_name" ] && echo "BACKUP_RESTORED=$backup_name"
    } > "$SEMAPHORE_FILE"


    log "Semaphore written: RESULT=$result${reason:+, REASON=$reason}"
}


# Trap handler for failures
cleanup_on_failure() {
    local exit_code=$?


    if [ $exit_code -ne 0 ]; then
        local total_duration=$(get_duration $START_TIME)
        log_error "Restore failed after ${total_duration}"


        # Write failure semaphore if not already written
        if [ ! -f "$SEMAPHORE_FILE" ]; then
            write_semaphore "failed" "unexpected_error"
        fi
    fi
}


trap cleanup_on_failure EXIT


# ============================================================================
# 1. Environment Variable Configuration
# ============================================================================


# Restore configuration
RESTORE_FROM_BACKUP="${RESTORE_FROM_BACKUP:-}"
RESTORE_ENABLED="${RESTORE_ENABLED:-false}"
RESTORE_RESET_CREDENTIALS="${RESTORE_RESET_CREDENTIALS:-false}"  # Delete system_auth to reset credentials
BACKUP_VOLUME="${BACKUP_VOLUME:-/backup}"
BACKUP_TAG_PREFIX="${BACKUP_TAG_PREFIX:-backup}"


# Support "latest" keyword in RESTORE_FROM_BACKUP
if [ "$RESTORE_FROM_BACKUP" = "latest" ]; then
    log "RESTORE_FROM_BACKUP='latest' detected, will restore most recent backup"
    RESTORE_ENABLED=true
    RESTORE_FROM_BACKUP=""
fi


# rsync configuration (NEW in v1.1)
RESTORE_RSYNC_RETRIES="${RESTORE_RSYNC_RETRIES:-3}"
RESTORE_RSYNC_TIMEOUT_MINUTES="${RESTORE_RSYNC_TIMEOUT_MINUTES:-120}"
RESTORE_RSYNC_EXTRA_OPTS="${RESTORE_RSYNC_EXTRA_OPTS:-}"


# Cassandra configuration
CASSANDRA_DATA_DIR="${CASSANDRA_DATA_DIR:-/var/lib/cassandra/data}"


log "Configuration:"
log "  Restore From Backup: ${RESTORE_FROM_BACKUP:-<not set>}"
log "  Restore Enabled: ${RESTORE_ENABLED}"
log "  Reset Credentials: ${RESTORE_RESET_CREDENTIALS}"
log "  Backup Volume: ${BACKUP_VOLUME}"
log "  Data Directory: ${CASSANDRA_DATA_DIR}"
log "  rsync Retries: ${RESTORE_RSYNC_RETRIES}"
log "  rsync Timeout: ${RESTORE_RSYNC_TIMEOUT_MINUTES} minutes"
[ -n "$RESTORE_RSYNC_EXTRA_OPTS" ] && log "  rsync Extra Opts: ${RESTORE_RSYNC_EXTRA_OPTS}"


if [ "$RESTORE_RESET_CREDENTIALS" = "true" ]; then
    log ""
    log "⚠️  CREDENTIAL RESET ENABLED"
    log "  - system_auth keyspace will be deleted"
    log "  - All users, roles, and permissions from backup will be lost"
    log "  - Cassandra will recreate with cassandra/cassandra credentials"
    [ -n "${AXONOPS_DB_USER:-}" ] && log "  - Custom user will be created: ${AXONOPS_DB_USER}"
fi


# ============================================================================
# 2. Determine Restore Target
# ============================================================================


# Check if restore is requested
if [ -z "$RESTORE_FROM_BACKUP" ] && [ "$RESTORE_ENABLED" != "true" ]; then
    log "No restore requested (RESTORE_FROM_BACKUP not set and RESTORE_ENABLED=false)"
    write_semaphore "skipped" "not_requested"
    exit 0
fi


# Determine backup directory to restore
if [ -n "$RESTORE_FROM_BACKUP" ]; then
    # Specific backup requested
    BACKUP_DIR="${BACKUP_VOLUME}/data_${RESTORE_FROM_BACKUP}"
    RESTORE_TARGET="$RESTORE_FROM_BACKUP"
    log "Specific backup requested: ${RESTORE_TARGET}"
else
    # Restore latest backup
    log "Latest backup requested, finding most recent..."


    LATEST_BACKUP=$(find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_${BACKUP_TAG_PREFIX}-*" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2 || echo "")


    if [ -z "$LATEST_BACKUP" ]; then
        log_error "No backups found in ${BACKUP_VOLUME}"
        log_error "Cannot restore - backup directory is empty"
        write_semaphore "failed" "no_backups_found"
        exit 1
    fi


    BACKUP_DIR="$LATEST_BACKUP"
    RESTORE_TARGET=$(basename "$BACKUP_DIR" | sed 's/^data_//')
    log "Latest backup found: ${RESTORE_TARGET}"
fi


log "Restore target: ${BACKUP_DIR}"


# ============================================================================
# 3. Validate Backup Exists
# ============================================================================


log "Validating backup exists and is accessible..."
VALIDATE_START=$(date +%s)


if [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup directory does not exist: ${BACKUP_DIR}"
    log_error "Available backups in ${BACKUP_VOLUME}:"
    find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_${BACKUP_TAG_PREFIX}-*" -exec basename {} \; 2>/dev/null | sed 's/^data_/  - /' || echo "  (none)"
    write_semaphore "failed" "backup_not_found"
    exit 1
fi


if [ ! -r "$BACKUP_DIR" ]; then
    log_error "Backup directory is not readable: ${BACKUP_DIR}"
    log_error "Check permissions (should be readable by cassandra user)"
    write_semaphore "failed" "backup_not_readable"
    exit 1
fi


# Check backup contains data
BACKUP_FILE_COUNT=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l || echo "0")
if [ "$BACKUP_FILE_COUNT" -eq 0 ]; then
    log_error "Backup directory is empty: ${BACKUP_DIR}"
    log_error "Cannot restore from empty backup"
    write_semaphore "failed" "backup_empty"
    exit 1
fi


VALIDATE_DURATION=$(get_duration $VALIDATE_START)
log "✓ Backup validation passed (took ${VALIDATE_DURATION})"
log "  Files in backup: ${BACKUP_FILE_COUNT}"
log "  Backup size: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo 'unknown')"


# ============================================================================
# 4. Write "in_progress" Semaphore (allows startup probe to pass)
# ============================================================================


log "Writing in_progress semaphore (allows container startup)..."
write_semaphore "in_progress" "restore_started" "$RESTORE_TARGET"


# ============================================================================
# 5. Check Cassandra Status - MUST NOT BE RUNNING (CRITICAL ERROR)
# ============================================================================


log "Checking if Cassandra is running..."


# Check for actual Cassandra Java process (not scripts that have "cassandra" in path)
# Use more specific pattern to avoid matching init scripts with cassandra in log path
if pgrep -f "org.apache.cassandra.service.CassandraDaemon" > /dev/null 2>&1; then
    # CRITICAL ERROR - Cassandra should NEVER be running during restore
    log_error "Cassandra is running - this should NEVER happen during restore"
    log_error "Restore must be triggered BEFORE Cassandra starts"
    log_error "This indicates a critical misconfiguration in your setup"
    log_error ""
    log_error "Check:"
    log_error "  - Entrypoint configuration (restore should run before 'exec cassandra')"
    log_error "  - Container orchestration (restore env vars set correctly)"
    log_error "  - Health check timing (startup/readiness probes)"
    log_error ""
    log_error "Cannot proceed with restore while Cassandra is running"
    log_error "Data corruption may occur if we continue"
    write_semaphore "failed" "cassandra_running"
    exit 1
fi


log "✓ Cassandra is not running (expected)"


# ============================================================================
# 6. Backup Existing Data Directory (safety - allows rollback)
# ============================================================================


log "Backing up existing data directory..."
BACKUP_EXISTING_START=$(date +%s)


# Ensure variable exists for later rollback checks under 'set -u'
DATA_BACKUP_DIR=""


if [ -d "$CASSANDRA_DATA_DIR" ] && [ "$(ls -A "$CASSANDRA_DATA_DIR" 2>/dev/null)" ]; then
    DATA_BACKUP_DIR="${CASSANDRA_DATA_DIR}.old.$(date -u +%Y%m%d-%H%M%S)"


    log "Moving existing data to: ${DATA_BACKUP_DIR}"


    if mv "$CASSANDRA_DATA_DIR" "$DATA_BACKUP_DIR" 2>&1; then
        BACKUP_EXISTING_DURATION=$(get_duration $BACKUP_EXISTING_START)
        log "✓ Existing data backed up (took ${BACKUP_EXISTING_DURATION})"
        log "  Can be restored manually if needed: mv ${DATA_BACKUP_DIR} ${CASSANDRA_DATA_DIR}"
    else
        log_error "Failed to backup existing data directory"
        write_semaphore "failed" "data_backup_failed"
        exit 1
    fi
else
    log "No existing data to backup (data directory empty or doesn't exist)"
fi


# ============================================================================
# 7. Create Fresh Data Directory
# ============================================================================


log "Creating fresh data directory..."


mkdir -p "$CASSANDRA_DATA_DIR" || {
    log_error "Failed to create data directory: ${CASSANDRA_DATA_DIR}"
    write_semaphore "failed" "mkdir_failed"
    exit 1
}


log "✓ Data directory created"


# ============================================================================
# 7a. Restore .axonops Directory FIRST (Semaphores and State)
# ============================================================================


log "Restoring .axonops directory (semaphores and state)..."


AXONOPS_SOURCE="${BACKUP_DIR}/.axonops"
AXONOPS_DEST="/var/lib/cassandra/.axonops"


if [ -d "$AXONOPS_SOURCE" ]; then
    # Create .axonops directory
    mkdir -p "$AXONOPS_DEST" || {
        log_error "Failed to create .axonops directory: ${AXONOPS_DEST}"
        write_semaphore "failed" "axonops_mkdir_failed"
        exit 1
    }


    # Restore .axonops directory
    if rsync -a --no-H "$AXONOPS_SOURCE/" "$AXONOPS_DEST/" 2>&1; then
        log "✓ .axonops directory restored"
        log "  Semaphores from original cluster preserved"


        # Fix permissions (cassandra user needs access)
        chown -R cassandra:cassandra "$AXONOPS_DEST" 2>&1 || {
            log "WARNING: Failed to fix .axonops ownership"
        }


        # Show restored semaphores for debugging
        if [ -f "${AXONOPS_DEST}/init-system-keyspaces.done" ]; then
            KEYSPACE_RESULT=$(grep "^RESULT=" "${AXONOPS_DEST}/init-system-keyspaces.done" | cut -d'=' -f2 || echo "unknown")
            log "  init-system-keyspaces.done: RESULT=$KEYSPACE_RESULT (from backup)"
        fi


        if [ -f "${AXONOPS_DEST}/init-db-user.done" ]; then
            USER_RESULT=$(grep "^RESULT=" "${AXONOPS_DEST}/init-db-user.done" | cut -d'=' -f2 || echo "unknown")
            log "  init-db-user.done: RESULT=$USER_RESULT (from backup)"
        fi
    else
        log_error "Failed to restore .axonops directory"
        write_semaphore "failed" "axonops_restore_failed"
        exit 1
    fi
else
    log "WARNING: .axonops directory not found in backup (${AXONOPS_SOURCE})"
    log "  This may be an old backup from before semaphore feature"
    log "  Health checks may fail - manual semaphore creation may be needed"
fi


# ============================================================================
# 8. rsync Restore from Backup (with retry and timeout)
# ============================================================================


log "Starting restore from backup..."
log "  Source: ${BACKUP_DIR}"
log "  Destination: ${CASSANDRA_DATA_DIR}"


# Prepare rsync command
# NOTE: --no-H is redundant unless -H is also used, but keeping it is harmless and explicit.
rsync_opts=( -a --no-H --stats )


# Add extra user-provided options (split on whitespace)
if [ -n "$RESTORE_RSYNC_EXTRA_OPTS" ]; then
    # shellcheck disable=SC2206
    extra_opts=( $RESTORE_RSYNC_EXTRA_OPTS )
    rsync_opts+=( "${extra_opts[@]}" )
fi


# Convert timeout to seconds
RSYNC_TIMEOUT_SECONDS=$((RESTORE_RSYNC_TIMEOUT_MINUTES * 60))


# rsync with retry logic
RSYNC_SUCCESS=false
RSYNC_START=$(date +%s)


for attempt in $(seq 1 $((RESTORE_RSYNC_RETRIES + 1))); do
    if [ $attempt -gt 1 ]; then
        # Exponential backoff: 5s, 10s, 20s, 40s...
        BACKOFF_SECONDS=$((5 * (2 ** (attempt - 2))))
        log "Retrying in ${BACKOFF_SECONDS}s..."
        sleep $BACKOFF_SECONDS
    fi


    log "Starting rsync (attempt $attempt/$((RESTORE_RSYNC_RETRIES + 1)))..."
    ATTEMPT_START=$(date +%s)


    # rsync with timeout, exclude schema.cql (not part of data structure)
    if timeout ${RSYNC_TIMEOUT_SECONDS} rsync "${rsync_opts[@]}" --exclude='schema.cql' "${BACKUP_DIR}/" "${CASSANDRA_DATA_DIR}/" 2>&1; then
        ATTEMPT_DURATION=$(get_duration $ATTEMPT_START)
        log "✓ rsync completed (took ${ATTEMPT_DURATION})"
        RSYNC_SUCCESS=true
        break
    else
        RSYNC_EXIT=$?
        ATTEMPT_DURATION=$(get_duration $ATTEMPT_START)


        if [ $RSYNC_EXIT -eq 124 ]; then
            log_error "rsync attempt $attempt/$((RESTORE_RSYNC_RETRIES + 1)) timed out after ${RESTORE_RSYNC_TIMEOUT_MINUTES} minutes (took ${ATTEMPT_DURATION})"
        else
            log_error "rsync attempt $attempt/$((RESTORE_RSYNC_RETRIES + 1)) failed with exit code $RSYNC_EXIT (took ${ATTEMPT_DURATION})"
        fi


        if [ $attempt -eq $((RESTORE_RSYNC_RETRIES + 1)) ]; then
            log_error "rsync failed after $((RESTORE_RSYNC_RETRIES + 1)) attempts"
            log_error "Consider:"
            log_error "  - Increasing RESTORE_RSYNC_TIMEOUT_MINUTES (current: ${RESTORE_RSYNC_TIMEOUT_MINUTES})"
            log_error "  - Increasing RESTORE_RSYNC_RETRIES (current: ${RESTORE_RSYNC_RETRIES})"
            log_error "  - Checking backup integrity and filesystem health"
            log_error ""
            log_error "Attempting rollback..."


            # Attempt rollback
            rm -rf "$CASSANDRA_DATA_DIR" 2>/dev/null || true
            if [ -n "$DATA_BACKUP_DIR" ] && [ -d "$DATA_BACKUP_DIR" ]; then
                mv "$DATA_BACKUP_DIR" "$CASSANDRA_DATA_DIR" 2>/dev/null && log "✓ Rollback successful" || log_error "Rollback failed!"
            fi


            write_semaphore "failed" "rsync_failed"
            exit 1
        fi
    fi
done


if [ "$RSYNC_SUCCESS" != "true" ]; then
    log_error "rsync failed - restore incomplete"
    write_semaphore "failed" "rsync_failed"
    exit 1
fi


RSYNC_TOTAL_DURATION=$(get_duration $RSYNC_START)
log "Total rsync time: ${RSYNC_TOTAL_DURATION}"


# ============================================================================
# 9. Fix Ownership and Permissions
# ============================================================================


log "Fixing ownership and permissions..."
PERMISSIONS_START=$(date +%s)


# Get cassandra user/group (should be UID 999, GID 999)
CASSANDRA_USER="cassandra"
CASSANDRA_GROUP="cassandra"


# Fix ownership recursively
log "Setting ownership to ${CASSANDRA_USER}:${CASSANDRA_GROUP}..."
CHOWN_START=$(date +%s)
if chown -R "${CASSANDRA_USER}:${CASSANDRA_GROUP}" "$CASSANDRA_DATA_DIR" 2>&1; then
    CHOWN_DURATION=$(get_duration $CHOWN_START)
    log "✓ Ownership fixed (took ${CHOWN_DURATION})"
else
    log_error "Failed to fix ownership"
    log_error "Cassandra may fail to start due to permission issues"
    write_semaphore "failed" "chown_failed"
    exit 1
fi


# Fix permissions (directories: 755, files: 644)
log "Setting permissions (directories: 755, files: 644)..."
CHMOD_START=$(date +%s)


find "$CASSANDRA_DATA_DIR" -type d -exec chmod 755 {} \; 2>&1 || {
    log_error "Failed to set directory permissions"
    write_semaphore "failed" "chmod_dir_failed"
    exit 1
}


find "$CASSANDRA_DATA_DIR" -type f -exec chmod 644 {} \; 2>&1 || {
    log_error "Failed to set file permissions"
    write_semaphore "failed" "chmod_file_failed"
    exit 1
}


CHMOD_DURATION=$(get_duration $CHMOD_START)
log "✓ Permissions fixed (took ${CHMOD_DURATION})"


PERMISSIONS_DURATION=$(get_duration $PERMISSIONS_START)
log "Total permissions time: ${PERMISSIONS_DURATION}"


# ============================================================================
# 9a. Credential Reset (Optional)
# ============================================================================


if [ "$RESTORE_RESET_CREDENTIALS" = "true" ]; then
    log ""
    log "========================================================================"
    log "CREDENTIAL RESET"
    log "========================================================================"
    log ""
    log "Credential reset requested - deleting system_auth keyspace data"
    log "WARNING: All user accounts, roles, and permissions from backup will be lost"
    log "Cassandra will recreate system_auth with default cassandra/cassandra credentials"


    CREDENTIAL_RESET_START=$(date +%s)
    SYSTEM_AUTH_DIR="${CASSANDRA_DATA_DIR}/system_auth"


    if [ -d "$SYSTEM_AUTH_DIR" ]; then
        # Get size for logging
        SYSTEM_AUTH_SIZE=$(du -sh "$SYSTEM_AUTH_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        log "Removing system_auth directory (size: $SYSTEM_AUTH_SIZE)"


        # Delete system_auth directory (CRITICAL - must succeed)
        if ! rm -rf "$SYSTEM_AUTH_DIR" 2>&1; then
            log_error "Failed to delete system_auth directory"
            log_error "Credential reset failed - cannot continue"


            # Write failure to semaphore
            {
                echo "COMPLETED=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
                echo "RESULT=failed"
                echo "REASON=credential_reset_failed"
                echo "BACKUP_ATTEMPTED=${RESTORE_TARGET}"
            } > /tmp/axonops-restore.done


            exit 1
        fi


        log "✓ system_auth directory deleted"
        log "  Cassandra will auto-create fresh system_auth on startup"
        log "  Default credentials: cassandra/cassandra"
    else
        log "WARNING: system_auth directory not found (expected at: $SYSTEM_AUTH_DIR)"
        log "Credential reset not needed (no system_auth in restored data)"
    fi


    # Note: Other system keyspaces (system, system_schema, etc.) are NOT altered
    # They retain their configuration from the backup (already NetworkTopologyStrategy)
    # Only system_auth is reset because it contains user credentials


    CREDENTIAL_RESET_DURATION=$(get_duration $CREDENTIAL_RESET_START)
    log "✓ Credential reset completed (took ${CREDENTIAL_RESET_DURATION})"
    log ""
fi


# ============================================================================
# 10. Validate Restored Data
# ============================================================================


log "Validating restored data..."
VALIDATION_START=$(date +%s)


# Count files restored
RESTORED_FILES=$(find "$CASSANDRA_DATA_DIR" -type f 2>/dev/null | wc -l || echo "0")


if [ "$RESTORED_FILES" -eq 0 ]; then
    log_error "No files found in restored data directory"
    log_error "Restore appears to have failed"
    write_semaphore "failed" "validation_failed"
    exit 1
fi


VALIDATION_DURATION=$(get_duration $VALIDATION_START)
log "✓ Validation passed (took ${VALIDATION_DURATION})"
log "  Files restored: ${RESTORED_FILES}"
log "  Data size: $(du -sh "$CASSANDRA_DATA_DIR" 2>/dev/null | cut -f1 || echo 'unknown')"


# ============================================================================
# 11. Write Success Semaphore
# ============================================================================


log "Writing success semaphore..."


# Write success semaphore with credential reset status
{
    echo "COMPLETED=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    echo "RESULT=success"
    echo "REASON=restore_completed"
    echo "BACKUP_RESTORED=${RESTORE_TARGET}"
    [ "$RESTORE_RESET_CREDENTIALS" = "true" ] && echo "CREDENTIALS_RESET=true"
} > "$SEMAPHORE_FILE"


# Only log CREDENTIALS_RESET when it actually happened
if [ "$RESTORE_RESET_CREDENTIALS" = "true" ]; then
    log "Semaphore written: RESULT=success, REASON=restore_completed, CREDENTIALS_RESET=true"
else
    log "Semaphore written: RESULT=success, REASON=restore_completed"
fi


# ============================================================================
# 12. Success
# ============================================================================


TOTAL_DURATION=$(get_duration $START_TIME)


log "=========================================="
log "✓ Restore completed successfully"
log "=========================================="
log "Backup restored: ${RESTORE_TARGET}"
log "Files restored: ${RESTORED_FILES}"
log "Data directory: ${CASSANDRA_DATA_DIR}"
log "Total duration: ${TOTAL_DURATION}"
log "=========================================="
log ""
log "Cassandra will now start with restored data"
log "Monitor logs to ensure successful startup"
log "=========================================="


exit 0
