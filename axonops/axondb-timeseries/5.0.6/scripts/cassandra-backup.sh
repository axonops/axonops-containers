#!/bin/bash
set -euo pipefail

# ============================================================================
# AxonDB Cassandra Backup Script
# Purpose: Create snapshot-based backups with rsync deduplication
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

# Helper to write error state to semaphore (call before exit 1)
write_error_semaphore() {
    local reason="$1"
    {
        echo "STATE=error"
        echo "REASON=$reason"
        echo "TIMESTAMP=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
        echo "PID=$$"
    } > "$LOCK_SEMAPHORE"
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

log "Starting Cassandra backup"

# ============================================================================
# Backup Lock Semaphore (Prevents Overlapping Backups)
# ============================================================================

# CRITICAL: Lock must be in /tmp (ephemeral) not .axonops (gets backed up!)
# Restoring an old lock would block all future backups
LOCK_SEMAPHORE="/tmp/axonops-backup.lock"

# Check if backup already in progress
if [ -f "$LOCK_SEMAPHORE" ]; then
    # Parse semaphore to get start time and PID
    BACKUP_START=$(grep "^STARTED=" "$LOCK_SEMAPHORE" | cut -d'=' -f2)
    BACKUP_PID=$(grep "^PID=" "$LOCK_SEMAPHORE" | cut -d'=' -f2)

    if [ -z "$BACKUP_START" ] || [ -z "$BACKUP_PID" ]; then
        log "WARNING: Backup lock file exists but malformed, removing stale lock"
        rm -f "$LOCK_SEMAPHORE"
    else
        # Calculate how long backup has been running
        START_EPOCH=$(date -d "$BACKUP_START" +%s 2>/dev/null || echo "0")
        CURRENT_EPOCH=$(date +%s)
        RUNNING_SECONDS=$((CURRENT_EPOCH - START_EPOCH))
        RUNNING_MINUTES=$((RUNNING_SECONDS / 60))

        # PRIMARY CHECK: Is the backup process still running?
        if kill -0 "$BACKUP_PID" 2>/dev/null; then
            # Process exists - backup is actively running
            log_error "Backup already in progress (PID $BACKUP_PID, running for ${RUNNING_MINUTES}m ${RUNNING_SECONDS}s)"
            log_error "  Started: ${BACKUP_START}"
            log_error ""
            log_error "Cannot start overlapping backup jobs"
            log_error "Wait for current backup to complete"
            exit 1
        fi

        # SECONDARY CHECK: Process died, but is rsync still running?
        if pgrep -f "rsync.*backup" >/dev/null 2>&1; then
            # rsync still running - backup script may have died but rsync continues
            log_error "Backup rsync process still running (script PID $BACKUP_PID died, running for ${RUNNING_MINUTES}m)"
            log_error "  Started: ${BACKUP_START}"
            log_error ""
            log_error "Cannot start overlapping backup jobs"
            log_error "Wait for rsync to complete or kill it manually"
            exit 1
        fi

        # TERTIARY CHECK: Both PID and rsync gone - check timeout to be safe
        # Timeout for considering lock truly stale (default: 60 minutes)
        BACKUP_STUCK_TIMEOUT_MINUTES="${BACKUP_STUCK_TIMEOUT_MINUTES:-60}"
        BACKUP_STUCK_TIMEOUT_SECONDS=$((BACKUP_STUCK_TIMEOUT_MINUTES * 60))

        if [ "$RUNNING_SECONDS" -lt "$BACKUP_STUCK_TIMEOUT_SECONDS" ]; then
            # Lock is recent - backup may have just died, be cautious
            log_error "Backup lock exists from ${RUNNING_MINUTES}m ago (PID and rsync gone)"
            log_error "  Started: ${BACKUP_START}"
            log_error "  Backup may have just completed or died"
            log_error ""
            log_error "Being cautious - won't start new backup until lock is older than ${BACKUP_STUCK_TIMEOUT_MINUTES}m"
            log_error "Or manually remove lock: rm ${LOCK_SEMAPHORE}"
            exit 1
        else
            # Lock is old - definitely stale
            log "WARNING: Stale backup lock detected (${RUNNING_MINUTES}m old, no PID/rsync found)"
            log "  Started: ${BACKUP_START}"
            log "  Removing stale lock and continuing"
            rm -f "$LOCK_SEMAPHORE"
        fi
    fi
fi

# Create backup lock semaphore
mkdir -p "$(dirname "$LOCK_SEMAPHORE")"
{
    echo "STARTED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "PID=$$"
    echo "HOSTNAME=$(hostname)"
} > "$LOCK_SEMAPHORE"

log "Backup lock acquired"

# Trap to ALWAYS remove lock semaphore (even on failure)
remove_backup_lock() {
    local exit_code=$?
    rm -f "$LOCK_SEMAPHORE" 2>/dev/null || true
    log "Backup lock released"
}

# Housekeeping: Clean up orphaned snapshots from failed backups
# This runs on EXIT to ensure we don't leave orphaned snapshots behind
housekeeping_cleanup_old_snapshots() {
    # Days to keep snapshots (default: 7 days)
    SNAPSHOT_RETENTION_DAYS="${SNAPSHOT_RETENTION_DAYS:-7}"

    log "Housekeeping: Checking for orphaned snapshots older than ${SNAPSHOT_RETENTION_DAYS} days..."

    # Get list of all snapshots with our backup tag prefix
    SNAPSHOTS=$(nodetool listsnapshots 2>/dev/null | grep "${BACKUP_TAG_PREFIX}-" | awk '{print $1}' || echo "")

    if [ -z "$SNAPSHOTS" ]; then
        log "No orphaned snapshots found"
        return 0
    fi

    # Current timestamp
    CURRENT_EPOCH=$(date +%s)
    RETENTION_SECONDS=$((SNAPSHOT_RETENTION_DAYS * 24 * 60 * 60))

    # Check each snapshot
    while IFS= read -r snapshot_tag; do
        # Extract date from tag (format: backup-YYYYMMDD-HHMMSS)
        if echo "$snapshot_tag" | grep -qE "${BACKUP_TAG_PREFIX}-[0-9]{8}-[0-9]{6}"; then
            # Parse date from tag
            SNAPSHOT_DATE=$(echo "$snapshot_tag" | sed "s/${BACKUP_TAG_PREFIX}-//")
            SNAPSHOT_EPOCH=$(date -d "${SNAPSHOT_DATE:0:8} ${SNAPSHOT_DATE:9:2}:${SNAPSHOT_DATE:11:2}:${SNAPSHOT_DATE:13:2}" +%s 2>/dev/null || echo "0")

            if [ "$SNAPSHOT_EPOCH" -gt 0 ]; then
                AGE_SECONDS=$((CURRENT_EPOCH - SNAPSHOT_EPOCH))
                AGE_DAYS=$((AGE_SECONDS / 86400))

                if [ "$AGE_SECONDS" -gt "$RETENTION_SECONDS" ]; then
                    log "Housekeeping: Removing orphaned snapshot $snapshot_tag (${AGE_DAYS} days old)"
                    nodetool clearsnapshot -t "$snapshot_tag" 2>&1 || log "WARNING: Failed to remove snapshot $snapshot_tag"
                fi
            fi
        fi
    done <<< "$SNAPSHOTS"
}

trap 'cleanup_snapshot; housekeeping_cleanup_old_snapshots; remove_backup_lock' EXIT

# ============================================================================
# 1. Environment Variable Configuration
# ============================================================================

# Backup configuration with defaults
BACKUP_VOLUME="${BACKUP_VOLUME:-/backup}"
BACKUP_TAG_PREFIX="${BACKUP_TAG_PREFIX:-backup}"
BACKUP_RETENTION_HOURS="${BACKUP_RETENTION_HOURS:-168}"  # Default: 7 days
BACKUP_MINIMUM_RETENTION_COUNT="${BACKUP_MINIMUM_RETENTION_COUNT:-1}"  # Always keep at least N previous backups (safety)
BACKUP_USE_HARDLINKS="${BACKUP_USE_HARDLINKS:-true}"
BACKUP_CALCULATE_STATS="${BACKUP_CALCULATE_STATS:-false}"  # Default: false (expensive on large datasets)
CLEANUP_TIMEOUT_MINUTES="${RETENTION_CLEANUP_TIMEOUT_MINUTES:-60}"  # Timeout for async retention deletion

# rsync configuration
BACKUP_RSYNC_RETRIES="${BACKUP_RSYNC_RETRIES:-3}"
BACKUP_RSYNC_TIMEOUT_MINUTES="${BACKUP_RSYNC_TIMEOUT_MINUTES:-120}"
BACKUP_RSYNC_EXTRA_OPTS="${BACKUP_RSYNC_EXTRA_OPTS:-}"
RSYNC_BWLIMIT_KB="${RSYNC_BWLIMIT_KB:-}"  # Bandwidth limit in KB/s (optional)

# Resource-friendly settings
# - nice -n 19: Lower CPU priority (0-19, higher = lower priority)
# - ionice -c 3: Idle disk I/O class (only use disk when nothing else needs it)
# These ensure backups don't impact Cassandra performance

# Cassandra configuration
CASSANDRA_DATA_DIR="${CASSANDRA_DATA_DIR:-/var/lib/cassandra/data}"
CQL_PORT="${CASSANDRA_NATIVE_TRANSPORT_PORT:-9042}"

log "Configuration:"
log "  Backup Volume: ${BACKUP_VOLUME}"
log "  Tag Prefix: ${BACKUP_TAG_PREFIX}"
log "  Retention Hours: ${BACKUP_RETENTION_HOURS}"
log "  Minimum Retention Count: ${BACKUP_MINIMUM_RETENTION_COUNT} (always keep at least this many previous backups)"
log "  Use Hardlinks: ${BACKUP_USE_HARDLINKS}"
log "  Calculate Stats: ${BACKUP_CALCULATE_STATS} (expensive on large datasets, default: false)"
log "  Data Directory: ${CASSANDRA_DATA_DIR}"
log "  rsync Retries: ${BACKUP_RSYNC_RETRIES}"
log "  rsync Timeout: ${BACKUP_RSYNC_TIMEOUT_MINUTES} minutes"
[ -n "$BACKUP_RSYNC_EXTRA_OPTS" ] && log "  rsync Extra Opts: ${BACKUP_RSYNC_EXTRA_OPTS}"

# ============================================================================
# 2. Validate Environment
# ============================================================================

log "Validating environment..."

# Check backup volume exists and is writable
if [ ! -d "$BACKUP_VOLUME" ]; then
    log_error "Backup volume does not exist: ${BACKUP_VOLUME}"
    log_error "Please ensure /backup volume is mounted"
    write_error_semaphore "Backup volume does not exist"
    exit 1
fi

if [ ! -w "$BACKUP_VOLUME" ]; then
    log_error "Backup volume is not writable: ${BACKUP_VOLUME}"
    log_error "Check volume permissions (should be writable by cassandra user)"
    write_error_semaphore "Backup volume not writable"
    exit 1
fi

# Check Cassandra data directory exists
if [ ! -d "$CASSANDRA_DATA_DIR" ]; then
    log_error "Cassandra data directory does not exist: ${CASSANDRA_DATA_DIR}"
    write_error_semaphore "Cassandra data directory does not exist"
    exit 1
fi

# Check Cassandra is running and responsive
if ! pgrep -f cassandra > /dev/null 2>&1; then
    log_error "Cassandra process is not running"
    log_error "Backup cannot proceed without Cassandra running"
    write_error_semaphore "Cassandra process not running"
    exit 1
fi

# Check CQL port is listening
if ! nc -z localhost "$CQL_PORT" 2>/dev/null; then
    log_error "CQL port $CQL_PORT is not listening"
    log_error "Cassandra may not be fully started yet"
    write_error_semaphore "CQL port not listening"
    exit 1
fi

# Check nodetool is available
if ! command -v nodetool >/dev/null 2>&1; then
    log_error "nodetool command not found"
    log_error "PATH: $PATH"
    write_error_semaphore "nodetool command not found"
    exit 1
fi

log "✓ Environment validation passed"

# ============================================================================
# 3. Single-Node Cluster Check (CRITICAL - Only single-node supported)
# ============================================================================

log "Checking cluster state..."

# Get node count from nodetool status
NODE_COUNT=$(nodetool status 2>/dev/null | grep -c '^[UD][NLJM]' || echo "0")

if [ "$NODE_COUNT" -eq 0 ]; then
    log_error "Unable to determine cluster state (nodetool status failed)"
    log_error "Cassandra may not be ready or nodetool is not working"
    nodetool status 2>&1 || true
    write_error_semaphore "Unable to determine cluster state"
    exit 1
fi

if [ "$NODE_COUNT" -gt 1 ]; then
    log_error "Backup is only supported for single-node clusters"
    log_error "Detected $NODE_COUNT nodes in cluster:"
    nodetool status 2>&1 | grep '^[UD][NLJM]' || true
    log_error ""
    log_error "For multi-node clusters, please use external backup solutions"
    log_error "or deploy and manage Cassandra separately from AxonOps containers"
    write_error_semaphore "Multi-node cluster detected ($NODE_COUNT nodes)"
    exit 1
fi

log "✓ Single node cluster detected ($NODE_COUNT node)"

# ============================================================================
# 4. Generate Snapshot Tag with Timestamp
# ============================================================================

# Format: backup-YYYYMMDD-HHMMSS
SNAPSHOT_TAG="${BACKUP_TAG_PREFIX}-$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_VOLUME}/data_${SNAPSHOT_TAG}"

log "Snapshot tag: ${SNAPSHOT_TAG}"
log "Backup directory: ${BACKUP_DIR}"

# ============================================================================
# 5. Trap Handler for Cleanup (ensures snapshot cleanup even on failure)
# ============================================================================

SNAPSHOT_CREATED=false

cleanup_snapshot() {
    local exit_code=$?

    if [ "$SNAPSHOT_CREATED" = "true" ]; then
        log "Cleaning up snapshot: ${SNAPSHOT_TAG}"
        if nodetool clearsnapshot -t "$SNAPSHOT_TAG" 2>/dev/null; then
            log "✓ Snapshot cleaned up successfully"
        else
            log "WARNING: Failed to cleanup snapshot ${SNAPSHOT_TAG}"
            log "You may need to manually cleanup with: nodetool clearsnapshot -t ${SNAPSHOT_TAG}"
        fi
    fi

    if [ $exit_code -ne 0 ]; then
        local total_duration=$(get_duration $START_TIME)
        log_error "Backup failed after ${total_duration}"
        log_error "Check logs above for details"
    fi
}

# NOTE: Trap is already set at top of script (cleanup_snapshot + housekeeping + remove_backup_lock)
# Do NOT set another trap here as it would overwrite the first one!

# ============================================================================
# 6. Flush Memtables (CRITICAL - Ensures all data written to SSTables)
# ============================================================================

log "Flushing memtables to ensure all data written to SSTables..."
FLUSH_START=$(date +%s)

if ! nodetool flush 2>&1; then
    log_error "nodetool flush failed"
    log_error "Cannot proceed with backup - data may be incomplete"
    exit 1
fi

FLUSH_DURATION=$(get_duration $FLUSH_START)
log "✓ Memtables flushed (took ${FLUSH_DURATION})"

# ============================================================================
# 7. Create Snapshot
# ============================================================================

log "Creating snapshot: ${SNAPSHOT_TAG}"
SNAPSHOT_START=$(date +%s)

if ! nodetool snapshot -t "$SNAPSHOT_TAG" 2>&1; then
    log_error "nodetool snapshot failed"
    log_error "Cannot proceed with backup"
    write_error_semaphore "nodetool snapshot failed"
    exit 1
fi

SNAPSHOT_CREATED=true
SNAPSHOT_DURATION=$(get_duration $SNAPSHOT_START)
log "✓ Snapshot created (took ${SNAPSHOT_DURATION})"

# ============================================================================
# 8. Dump Schema (for documentation purposes)
# ============================================================================

log "Dumping schema for documentation..."
SCHEMA_START=$(date +%s)

# Create temporary file for schema dump
SCHEMA_TEMP="/tmp/schema-${SNAPSHOT_TAG}.cql"

# Try to dump schema (non-critical - continue on failure)
# Credential hierarchy: 1) AXONOPS_DB_USER/PASSWORD, 2) no auth, 3) cassandra/cassandra
SCHEMA_DUMPED=false

# Try 1: AXONOPS_DB_USER/PASSWORD (if set)
if [ -n "${AXONOPS_DB_USER:-}" ] && [ -n "${AXONOPS_DB_PASSWORD:-}" ]; then
    log "Attempting schema dump with AXONOPS_DB_USER credentials..."
    if cqlsh -u "$AXONOPS_DB_USER" -p "$AXONOPS_DB_PASSWORD" -e "DESCRIBE SCHEMA" > "$SCHEMA_TEMP" 2>&1; then
        SCHEMA_DUMPED=true
    fi
fi

# Try 2: No authentication (if first attempt failed or not configured)
if [ "$SCHEMA_DUMPED" = "false" ]; then
    log "Attempting schema dump without authentication..."
    if cqlsh -e "DESCRIBE SCHEMA" > "$SCHEMA_TEMP" 2>&1; then
        SCHEMA_DUMPED=true
    fi
fi

# Try 3: Default cassandra/cassandra credentials (fallback)
if [ "$SCHEMA_DUMPED" = "false" ]; then
    log "Attempting schema dump with default cassandra/cassandra credentials..."
    if cqlsh -u cassandra -p cassandra -e "DESCRIBE SCHEMA" > "$SCHEMA_TEMP" 2>&1; then
        SCHEMA_DUMPED=true
    fi
fi

# Check if any attempt succeeded
if [ "$SCHEMA_DUMPED" = "true" ]; then
    SCHEMA_LINES=$(wc -l < "$SCHEMA_TEMP")
    SCHEMA_DURATION=$(get_duration $SCHEMA_START)
    log "✓ Schema dumped (took ${SCHEMA_DURATION}, ${SCHEMA_LINES} lines)"
else
    log "WARNING: Failed to dump schema after trying all credential options"
    log "  Tried: AXONOPS_DB_USER (${AXONOPS_DB_USER:-not set}), no auth, cassandra/cassandra"
    log "  This is not critical - backup will proceed without schema.cql"
    # Create empty file so copy doesn't fail later
    echo "-- Schema dump failed at $(date -u +'%Y-%m-%dT%H:%M:%SZ')" > "$SCHEMA_TEMP"
    echo "-- Tried all credential options" >> "$SCHEMA_TEMP"
fi

# ============================================================================
# 9. Find Latest Previous Backup (for --link-dest deduplication)
# ============================================================================

log "Checking for previous backups (for deduplication)..."

# Find latest backup directory (sorted by modification time, descending)
LATEST_BACKUP=$(find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_${BACKUP_TAG_PREFIX}-*" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2 || echo "")

if [ -n "$LATEST_BACKUP" ]; then
    log "✓ Found previous backup: $(basename "$LATEST_BACKUP")"
    log "  Will use for deduplication (hardlinks)"
else
    log "No previous backups found - this will be a full backup"
fi

# ============================================================================
# 10. Test Hardlink Support (CRITICAL - ERROR if not supported and enabled)
# ============================================================================

if [ "$BACKUP_USE_HARDLINKS" = "true" ]; then
    log "Testing filesystem hardlink support..."

    # Create test directory
    mkdir -p "$BACKUP_DIR" || {
        log_error "Failed to create backup directory: ${BACKUP_DIR}"
        exit 1
    }

    # Test hardlink creation
    TEST_FILE="${BACKUP_DIR}/.hardlink-test-$$"
    TEST_LINK="${BACKUP_DIR}/.hardlink-test-link-$$"

    if touch "$TEST_FILE" 2>/dev/null && ln "$TEST_FILE" "$TEST_LINK" 2>/dev/null; then
        log "✓ Filesystem supports hardlinks"
        rm -f "$TEST_FILE" "$TEST_LINK"
    else
        # Cleanup test files
        rm -f "$TEST_FILE" "$TEST_LINK" 2>/dev/null || true

        # CRITICAL ERROR - filesystem doesn't support hardlinks but user requested them
        log_error "Filesystem does not support hardlinks"
        log_error "Hardlink deduplication is enabled but filesystem doesn't support it"
        log_error ""
        log_error "You have two options:"
        log_error "  1. Use a filesystem that supports hardlinks (ext4, xfs, btrfs, etc.)"
        log_error "  2. Disable hardlink deduplication: BACKUP_USE_HARDLINKS=false"
        log_error ""
        log_error "WARNING: Disabling hardlinks means full copies of all backups"
        log_error "         This will consume significantly more disk space"
        log_error ""
        log_error "Current filesystem info:"
        df -T "$BACKUP_VOLUME" 2>&1 || true
        write_error_semaphore "Filesystem does not support hardlinks"
        exit 1
    fi
fi

# ============================================================================
# 11. rsync Snapshot to Backup Volume (with retry and timeout)
# ============================================================================

log "Starting rsync to backup volume..."

# Create backup directory if not exists (may exist from hardlink test)
mkdir -p "$BACKUP_DIR" || {
    log_error "Failed to create backup directory: ${BACKUP_DIR}"
    exit 1
}

# Prepare rsync command
RSYNC_OPTS="-a --stats"

# Add --link-dest if enabled and previous backup exists
if [ "$BACKUP_USE_HARDLINKS" = "true" ] && [ -n "$LATEST_BACKUP" ]; then
    log "Using hardlink deduplication (--link-dest)"
    RSYNC_OPTS="$RSYNC_OPTS --link-dest=$LATEST_BACKUP"
fi

# Add bandwidth limit if specified
if [ -n "$RSYNC_BWLIMIT_KB" ]; then
    RSYNC_OPTS="$RSYNC_OPTS --bwlimit=$RSYNC_BWLIMIT_KB"
    log "Bandwidth limit: ${RSYNC_BWLIMIT_KB} KB/s"
fi

# Add extra user-provided options
if [ -n "$BACKUP_RSYNC_EXTRA_OPTS" ]; then
    RSYNC_OPTS="$RSYNC_OPTS $BACKUP_RSYNC_EXTRA_OPTS"
fi

# Convert timeout to seconds
RSYNC_TIMEOUT_SECONDS=$((BACKUP_RSYNC_TIMEOUT_MINUTES * 60))

# Resource-friendly wrapper for rsync
# - nice -n 19: Lower CPU priority (backups don't starve Cassandra)
# - ionice -c 3: Idle disk I/O (only use disk when nothing else needs it)
RSYNC_WRAPPER="nice -n 19 ionice -c 3"
log "Resource limits: nice -n 19 (low CPU priority), ionice -c 3 (idle I/O)"

# rsync with retry logic
RSYNC_SUCCESS=false
RSYNC_START=$(date +%s)

for attempt in $(seq 1 $((BACKUP_RSYNC_RETRIES + 1))); do
    if [ $attempt -gt 1 ]; then
        # Exponential backoff: 5s, 10s, 20s, 40s...
        BACKOFF_SECONDS=$((5 * (2 ** (attempt - 2))))
        log "Retrying in ${BACKOFF_SECONDS}s..."
        sleep $BACKOFF_SECONDS
    fi

    log "Starting rsync (attempt $attempt/$((BACKUP_RSYNC_RETRIES + 1)))..."
    ATTEMPT_START=$(date +%s)

    # Find all snapshot directories for this tag and rsync them
    SNAPSHOT_DIRS=$(find "$CASSANDRA_DATA_DIR" -type d -path "*/snapshots/${SNAPSHOT_TAG}" 2>/dev/null || true)

    if [ -z "$SNAPSHOT_DIRS" ]; then
        log_error "No snapshot directories found for tag: ${SNAPSHOT_TAG}"
        log_error "Expected to find directories at: ${CASSANDRA_DATA_DIR}/*/snapshots/${SNAPSHOT_TAG}"
        write_error_semaphore "No snapshot directories found"
        exit 1
    fi

    SNAPSHOT_COUNT=$(echo "$SNAPSHOT_DIRS" | wc -l)
    log "Found $SNAPSHOT_COUNT snapshot directories to backup"

    # Track success for this attempt
    ATTEMPT_SUCCESS=true
    TOTAL_FILES=0

    # Iterate through each snapshot directory
    while IFS= read -r snapshot_dir; do
        # Get parent directory (table dir)
        table_dir=$(dirname "$(dirname "$snapshot_dir")")

        # Get relative path from data dir
        rel_path=${table_dir#${CASSANDRA_DATA_DIR}/}

        # Destination directory
        dest_dir="${BACKUP_DIR}/${rel_path}"

        # Create destination directory
        mkdir -p "$dest_dir" || {
            log_error "Failed to create directory: ${dest_dir}"
            ATTEMPT_SUCCESS=false
            break
        }

        # Count files in snapshot
        file_count=$(find "$snapshot_dir" -type f | wc -l)
        TOTAL_FILES=$((TOTAL_FILES + file_count))

        # rsync this snapshot directory to destination with timeout
        if [ "$BACKUP_USE_HARDLINKS" = "true" ] && [ -n "$LATEST_BACKUP" ]; then
            # With hardlinks - check if destination exists in previous backup
            prev_dest="${LATEST_BACKUP}/${rel_path}"
            if [ -d "$prev_dest" ]; then
                if ! timeout ${RSYNC_TIMEOUT_SECONDS} $RSYNC_WRAPPER rsync $RSYNC_OPTS --link-dest="$prev_dest" "$snapshot_dir/" "$dest_dir/" 2>&1; then
                    if [ $? -eq 124 ]; then
                        log_error "rsync timed out after ${BACKUP_RSYNC_TIMEOUT_MINUTES} minutes for: $rel_path"
                    else
                        log_error "rsync failed for: $rel_path"
                    fi
                    ATTEMPT_SUCCESS=false
                    break
                fi
            else
                # No previous backup for this table - full copy
                if ! timeout ${RSYNC_TIMEOUT_SECONDS} $RSYNC_WRAPPER rsync $RSYNC_OPTS "$snapshot_dir/" "$dest_dir/" 2>&1; then
                    if [ $? -eq 124 ]; then
                        log_error "rsync timed out after ${BACKUP_RSYNC_TIMEOUT_MINUTES} minutes for: $rel_path"
                    else
                        log_error "rsync failed for: $rel_path"
                    fi
                    ATTEMPT_SUCCESS=false
                    break
                fi
            fi
        else
            # Without hardlinks - full copy
            if ! timeout ${RSYNC_TIMEOUT_SECONDS} $RSYNC_WRAPPER rsync $RSYNC_OPTS "$snapshot_dir/" "$dest_dir/" 2>&1; then
                if [ $? -eq 124 ]; then
                    log_error "rsync timed out after ${BACKUP_RSYNC_TIMEOUT_MINUTES} minutes for: $rel_path"
                else
                    log_error "rsync failed for: $rel_path"
                fi
                ATTEMPT_SUCCESS=false
                break
            fi
        fi

    done <<< "$SNAPSHOT_DIRS"

    ATTEMPT_DURATION=$(get_duration $ATTEMPT_START)

    if [ "$ATTEMPT_SUCCESS" = "true" ]; then
        log "✓ rsync completed (took ${ATTEMPT_DURATION})"
        log "  Copied $TOTAL_FILES files from snapshot to backup"
        RSYNC_SUCCESS=true
        break
    else
        log_error "rsync attempt $attempt/$((BACKUP_RSYNC_RETRIES + 1)) failed (took ${ATTEMPT_DURATION})"

        if [ $attempt -eq $((BACKUP_RSYNC_RETRIES + 1)) ]; then
            log_error "rsync failed after $((BACKUP_RSYNC_RETRIES + 1)) attempts"
            log_error "Consider:"
            log_error "  - Increasing BACKUP_RSYNC_TIMEOUT_MINUTES (current: ${BACKUP_RSYNC_TIMEOUT_MINUTES})"
            log_error "  - Increasing BACKUP_RSYNC_RETRIES (current: ${BACKUP_RSYNC_RETRIES})"
            log_error "  - Checking disk space and filesystem health"
            write_error_semaphore "rsync failed after $((BACKUP_RSYNC_RETRIES + 1)) attempts"
            exit 1
        fi
    fi
done

if [ "$RSYNC_SUCCESS" != "true" ]; then
    log_error "rsync failed - backup incomplete"
    write_error_semaphore "rsync failed - backup incomplete"
    exit 1
fi

RSYNC_TOTAL_DURATION=$(get_duration $RSYNC_START)
log "Total rsync time: ${RSYNC_TOTAL_DURATION}"

# ============================================================================
# 12. Copy Schema Dump to Backup Directory
# ============================================================================

if [ -f "$SCHEMA_TEMP" ]; then
    log "Copying schema dump to backup directory..."
    cp "$SCHEMA_TEMP" "${BACKUP_DIR}/schema.cql" || {
        log "WARNING: Failed to copy schema.cql to backup directory"
    }
    rm -f "$SCHEMA_TEMP"
    log "✓ Schema dump saved to backup"
fi

# ============================================================================
# 12a. Backup .axonops Directory (Semaphores and State)
# ============================================================================

AXONOPS_DIR="/var/lib/cassandra/.axonops"
if [ -d "$AXONOPS_DIR" ]; then
    log "Backing up .axonops directory (semaphores and state)..."

    # Copy .axonops to backup (preserves init/restore state from original cluster)
    if rsync -a "$AXONOPS_DIR/" "${BACKUP_DIR}/.axonops/" 2>&1; then
        log "✓ .axonops directory backed up"
        log "  This preserves semaphore state for restore"
    else
        log "WARNING: Failed to backup .axonops directory"
        log "  Restore may need manual semaphore configuration"
    fi
else
    log "WARNING: .axonops directory not found (${AXONOPS_DIR})"
    log "  This may be a fresh cluster or semaphores not yet created"
fi

# ============================================================================
# 13. Calculate Backup Statistics
# ============================================================================

log "Calculating backup statistics..."

# Total size of backup (in human-readable format)
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "unknown")

# Calculate detailed stats only if enabled (expensive on large datasets)
if [ "$BACKUP_CALCULATE_STATS" = "true" ]; then
    log "Detailed stats calculation enabled (may be slow on large datasets)..."
    STATS_START=$(date +%s)

    if [ "$BACKUP_USE_HARDLINKS" = "true" ] && [ -n "$LATEST_BACKUP" ]; then
        # Count hardlinks (files with link count > 1) - EXPENSIVE!
        HARDLINKED_FILES=$(find "$BACKUP_DIR" -type f -links +1 2>/dev/null | wc -l || echo "0")
        STATS_DURATION=$(get_duration $STATS_START)

        log "Backup statistics (calculated in ${STATS_DURATION}):"
        log "  Total size: ${BACKUP_SIZE}"
        log "  Files hardlinked: ${HARDLINKED_FILES} (deduplicated from previous backup)"
    else
        log "Backup statistics:"
        log "  Total size: ${BACKUP_SIZE}"
        log "  Full backup (no deduplication)"
    fi
else
    # Fast stats only (no expensive find operation)
    log "Backup statistics (fast mode, detailed stats disabled):"
    log "  Total size: ${BACKUP_SIZE}"
    if [ "$BACKUP_USE_HARDLINKS" = "true" ] && [ -n "$LATEST_BACKUP" ]; then
        log "  Hardlink deduplication: enabled (set BACKUP_CALCULATE_STATS=true for file count)"
    else
        log "  Hardlink deduplication: disabled"
    fi
fi

# ============================================================================
# 14. Apply Retention Policy (Delete Old Backups)
# ============================================================================

log "Applying retention policy (keeping last ${BACKUP_RETENTION_HOURS} hours)..."
log "Minimum retention count: ${BACKUP_MINIMUM_RETENTION_COUNT} (safety net - always keep this many previous backups)"

# Check if retention cleanup already running
CLEANUP_SEMAPHORE="/tmp/axonops-retention-cleanup.lock"
if [ -f "$CLEANUP_SEMAPHORE" ]; then
    CLEANUP_STATE=$(grep "^STATE=" "$CLEANUP_SEMAPHORE" 2>/dev/null | cut -d'=' -f2 || echo "unknown")
    CLEANUP_PID=$(grep "^PID=" "$CLEANUP_SEMAPHORE" 2>/dev/null | cut -d'=' -f2 || echo "")

    if [ -n "$CLEANUP_PID" ] && kill -0 "$CLEANUP_PID" 2>/dev/null; then
        log "Retention cleanup already in progress (PID $CLEANUP_PID, state: $CLEANUP_STATE)"
        log "Skipping retention check (will retry on next backup)"
    else
        log "Stale cleanup semaphore found (removing)"
        rm -f "$CLEANUP_SEMAPHORE"
    fi
fi

if [ ! -f "$CLEANUP_SEMAPHORE" ]; then
    # Calculate cutoff time in epoch seconds
    RETENTION_SECONDS=$((BACKUP_RETENTION_HOURS * 3600))
    CURRENT_TIME=$(date +%s)
    CUTOFF_TIME=$((CURRENT_TIME - RETENTION_SECONDS))

    log "Current time: $(date -u -d @${CURRENT_TIME} +"%Y-%m-%d %H:%M:%S UTC")"
    log "Cutoff time: $(date -u -d @${CUTOFF_TIME} +"%Y-%m-%d %H:%M:%S UTC")"

    # Find all EXISTING backup directories (excludes current backup being created)
    ALL_BACKUPS=$(find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_${BACKUP_TAG_PREFIX}-*" 2>/dev/null | sort || true)

    if [ -z "$ALL_BACKUPS" ]; then
        log "No existing backups found (this appears to be the first backup)"
    else
        TOTAL_BACKUPS=$(echo "$ALL_BACKUPS" | wc -l)
        log "Found ${TOTAL_BACKUPS} existing backup(s) (excludes current backup being created)"

        # Safety check: Always keep at least MINIMUM_RETENTION_COUNT previous backups
        MINIMUM_KEEP=$((BACKUP_MINIMUM_RETENTION_COUNT + 1))

        if [ "$TOTAL_BACKUPS" -le "$BACKUP_MINIMUM_RETENTION_COUNT" ]; then
            log "Keeping all ${TOTAL_BACKUPS} backup(s) (minimum retention: ${BACKUP_MINIMUM_RETENTION_COUNT})"
            log "No backups will be deleted (safety net active)"
        else
            log "Total backups (${TOTAL_BACKUPS}) > minimum retention (${BACKUP_MINIMUM_RETENTION_COUNT}) - checking for old backups"

            # Build list of old backups to delete
            OLD_BACKUPS_LIST=""
            TO_DELETE_COUNT=0

            while IFS= read -r backup_dir; do
                backup_name=$(basename "$backup_dir")

                # Extract timestamp from backup name
                timestamp=$(echo "$backup_name" | sed "s/^data_${BACKUP_TAG_PREFIX}-//")

                # Convert to epoch
                year=${timestamp:0:4}
                month=${timestamp:4:2}
                day=${timestamp:6:2}
                hour=${timestamp:9:2}
                minute=${timestamp:11:2}
                second=${timestamp:13:2}

                backup_datetime="${year}-${month}-${day} ${hour}:${minute}:${second}"
                backup_epoch=$(date -u -d "$backup_datetime" +%s 2>/dev/null || echo "0")

                if [ "$backup_epoch" -eq 0 ]; then
                    log "WARNING: Failed to parse timestamp for: $backup_name (skipping)"
                    continue
                fi

                # Check if backup is older than cutoff
                if [ "$backup_epoch" -lt "$CUTOFF_TIME" ]; then
                    # Calculate how many backups will remain after this deletion
                    REMAINING_AFTER_DELETE=$((TOTAL_BACKUPS - TO_DELETE_COUNT - 1))

                    # Safety check: Don't delete if it would violate minimum retention
                    if [ "$REMAINING_AFTER_DELETE" -lt "$MINIMUM_KEEP" ]; then
                        log "  Skipping: $backup_name (age: $(((CURRENT_TIME - backup_epoch) / 3600))h) - would violate minimum retention"
                        log "    Remaining after delete would be: $REMAINING_AFTER_DELETE (minimum required: $MINIMUM_KEEP)"
                        continue
                    fi

                    # Add to deletion list
                    log "  Marked for deletion: $backup_name (age: $(((CURRENT_TIME - backup_epoch) / 3600))h)"
                    if [ -z "$OLD_BACKUPS_LIST" ]; then
                        OLD_BACKUPS_LIST="$backup_dir"
                    else
                        OLD_BACKUPS_LIST="$OLD_BACKUPS_LIST"$'\n'"$backup_dir"
                    fi
                    TO_DELETE_COUNT=$((TO_DELETE_COUNT + 1))
                fi
            done <<< "$ALL_BACKUPS"

            if [ -n "$OLD_BACKUPS_LIST" ]; then
                log "Starting async deletion of ${TO_DELETE_COUNT} old backup(s)..."
                log "Deletion will run in background (timeout: ${CLEANUP_TIMEOUT_MINUTES} minutes)"
                log "Backup script will complete immediately (check logs for deletion progress)"

                # Export vars needed by deletion script
                export RETENTION_CLEANUP_TIMEOUT_MINUTES="$CLEANUP_TIMEOUT_MINUTES"

                # Start async cleanup (redirect output to log file)
                echo "$OLD_BACKUPS_LIST" | /usr/local/bin/retention-cleanup.sh >> /var/log/cassandra/retention-cleanup.log 2>&1 &

                log "✓ Async deletion started (PID $!)"
                log "  Remaining: $((TOTAL_BACKUPS - TO_DELETE_COUNT)) existing + 1 current = $((TOTAL_BACKUPS - TO_DELETE_COUNT + 1)) total (after cleanup)"
            else
                log "No old backups to delete (all within retention period or protected by minimum count)"
            fi
        fi
    fi
fi

# ============================================================================
# 15. Cleanup Snapshot (via trap handler)
# ============================================================================

log "Cleanup will be performed via trap handler..."

# ============================================================================
# 16. Success
# ============================================================================

TOTAL_DURATION=$(get_duration $START_TIME)

log "=========================================="
log "✓ Backup completed successfully"
log "=========================================="
log "Snapshot tag: ${SNAPSHOT_TAG}"
log "Backup location: ${BACKUP_DIR}"
log "Backup size: ${BACKUP_SIZE}"
log "Retention: ${BACKUP_RETENTION_HOURS} hours"
log "Total duration: ${TOTAL_DURATION}"
log "=========================================="

exit 0
