#!/bin/bash

# Cassandra Restore Script using rclone
# This script downloads backup from remote storage to /backups directory
# Required environment variables:
#   RCLONE_REMOTE_NAME: The name of the configured rclone remote (e.g., "s3", "gcs", "azure")
#   RCLONE_REMOTE_PATH: The path in the remote storage (e.g., "my-bucket/cassandra-backups")
#   RESTORE_FROM_BACKUP: Backup identifier to restore (default: "latest")
# Optional environment variables:
#   BACKUP_DESTINATION_DIR: Destination directory for restore (default: /backup)
#   RCLONE_FLAGS: Additional rclone flags (default: "--verbose --stats 60s")

set -euo pipefail

if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# Default values
BACKUP_DESTINATION_DIR="${BACKUP_VOLUME:-/backup}"
RCLONE_FLAGS="${RCLONE_FLAGS:---verbose --stats 60s}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
HOSTNAME="${HOSTNAME:-$(hostname)}"
RCLONE_BWLIMIT_KB="${BWLIMIT_KB:-0}"
RCLONE_FLAGS+=" $( [ "$RCLONE_BWLIMIT_KB" -gt 0 ] && echo "--bwlimit ${RCLONE_BWLIMIT_KB}k" || echo "" )"
RCLONE_REMOTE_NAME="CASS"
BACKUP_INITIAL_DELAY_SECONDS=${BACKUP_INITIAL_DELAY_SECONDS:-300}
RESTORE_FROM_BACKUP="${RESTORE_FROM_BACKUP:-latest}"

# If it's not "latest" AND it doesn't already start with "data_"
if [[ "$RESTORE_FROM_BACKUP" != "latest" && "$RESTORE_FROM_BACKUP" != data_* ]]; then
    RESTORE_FROM_BACKUP="data_${RESTORE_FROM_BACKUP}"
fi

set -a
RCLONE_CONFIG_CASS_TYPE=s3
RCLONE_CONFIG_CASS_PROVIDER=AWS
RCLONE_CONFIG_CASS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
RCLONE_CONFIG_CASS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
RCLONE_CONFIG_CASS_REGION=${AWS_REGION:-us-east-1}
set +a

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Check required environment variables
check_requirements() {
    local error=0

    if [ -z "${RCLONE_REMOTE_NAME:-}" ]; then
        log_error "RCLONE_REMOTE_NAME environment variable is not set"
        error=1
    fi

    if [ -z "${RCLONE_REMOTE_PATH:-}" ]; then
        log_error "RCLONE_REMOTE_PATH environment variable is not set"
        error=1
    fi

    if [ -z "${RESTORE_FROM_BACKUP:-}" ]; then
        log_error "RESTORE_FROM_BACKUP environment variable is not set"
        error=1
    fi

    if ! command -v rclone &> /dev/null; then
        log_error "rclone is not installed or not in PATH"
        error=1
    fi

    if [ ! -d "$BACKUP_DESTINATION_DIR" ]; then
        log_warning "Destination directory $BACKUP_DESTINATION_DIR does not exist, creating it..."
        mkdir -p "$BACKUP_DESTINATION_DIR" || {
            log_error "Failed to create destination directory $BACKUP_DESTINATION_DIR"
            error=1
        }
    fi

    if [ $error -eq 1 ]; then
        log_error "Prerequisites check failed. Exiting."
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Determine the backup source path
determine_backup_source() {
    local remote_base="${RCLONE_REMOTE_NAME}:${RCLONE_REMOTE_PATH}/${HOSTNAME}"

    if [ "$RESTORE_FROM_BACKUP" == "latest" ]; then
        log_info "Looking for latest backup..."

        # Try to read LATEST.txt marker if it exists
        local latest_marker=$(rclone cat "${remote_base}/LATEST.txt" 2>/dev/null || echo "")

        if [ -n "$latest_marker" ]; then
            log_info "Found LATEST.txt marker pointing to timestamp: $latest_marker"
            # The marker contains just the timestamp, use the base path
            echo "$remote_base"
            return 0
        fi

        # If no marker, find the most recent backup directory
        log_info "No LATEST.txt marker found, searching for most recent backup directory..."
        local latest_backup=$(rclone lsd "$remote_base" 2>/dev/null | \
            grep -E 'backup.*-[0-9]{8}-[0-9]{6}$' | \
            awk '{print $NF}' | \
            sort -r | \
            head -n 1)

        if [ -z "$latest_backup" ]; then
            # No dated backup directories, use the base path directly
            log_info "No dated backup directories found, using base path: $remote_base"
            echo "$remote_base"
        else
            log_info "Found latest backup directory: $latest_backup"
            echo "${remote_base}/${latest_backup}"
        fi
    else
        # Specific backup requested
        log_info "Restoring specific backup: $RESTORE_FROM_BACKUP"
        echo "${remote_base}/${RESTORE_FROM_BACKUP}"
    fi
}

# Perform the restore
perform_restore() {
    local source=$(determine_backup_source)
    local destination="$BACKUP_DESTINATION_DIR/${RESTORE_FROM_BACKUP}"

    log_info "Starting restore from $source to $destination"
    log_info "Using rclone flags: $RCLONE_FLAGS"

    # Check if remote backup exists and has content
    if ! rclone lsd "$source" &>/dev/null && ! rclone ls "$source" &>/dev/null; then
        log_error "Remote backup source $source does not exist or is not accessible"
        return 1
    fi

    # Count files to restore
    file_count=$(rclone ls "$source" 2>/dev/null | wc -l)
    if [ "$file_count" -eq 0 ]; then
        log_warning "Remote backup $source is empty. Nothing to restore."
        return 1
    fi

    log_info "Found $file_count files to restore"

    # Clear destination directory if requested
    if [ "${CLEAR_DESTINATION:-false}" == "true" ]; then
        log_warning "Clearing destination directory $destination"
        rm -rf "${destination:?}"/*
    fi

    # Perform the restore
    if rclone copy "$source" "$destination" $RCLONE_FLAGS; then
        log_info "Restore completed successfully to $destination"

        # Verify restored file count
        local restored_count=$(find "$destination" -type f 2>/dev/null | wc -l)
        log_info "Restored $restored_count files"

        return 0
    else
        log_error "Restore failed with exit code $?"
        return 1
    fi
}

# List available backups
list_available_backups() {
    local remote_base="${RCLONE_REMOTE_NAME}:${RCLONE_REMOTE_PATH}/${HOSTNAME}"

    log_info "Available backups at $remote_base:"
    rclone lsd "$remote_base" 2>/dev/null | awk '{print "  - " $NF}' || \
        log_warning "Could not list available backups"
}

# Verify restore (optional)
verify_restore() {
    if [ "${VERIFY_RESTORE:-false}" != "true" ]; then
        return 0
    fi

    local source=$(determine_backup_source)
    log_info "Verifying restore from $source"

    local remote_count=$(rclone ls "$source" 2>/dev/null | wc -l)
    local local_count=$(find "$BACKUP_DESTINATION_DIR" -type f 2>/dev/null | wc -l)

    if [ "$remote_count" -eq "$local_count" ]; then
        log_info "Verification passed: $local_count files restored"
        return 0
    else
        log_error "Verification failed: Remote files: $remote_count, Local files: $local_count"
        return 1
    fi
}

# Main execution
main() {
    log_info "=== Cassandra Restore Script Started ==="
    log_info "Hostname: $HOSTNAME"
    log_info "Timestamp: $TIMESTAMP"
    log_info "Restore Target: $RESTORE_FROM_BACKUP"
    log_info "Destination Directory: $BACKUP_DESTINATION_DIR"
    log_info "Remote: ${RCLONE_REMOTE_NAME}:${RCLONE_REMOTE_PATH}"

    # Check requirements
    check_requirements

    # Test rclone configuration
    log_info "Testing rclone configuration..."
    if ! rclone lsd "${RCLONE_REMOTE_NAME}:" &>/dev/null; then
        log_error "Failed to connect to remote storage. Please check rclone configuration."
        return 1
    fi

    # List available backups if requested
    if [ "${LIST_BACKUPS:-false}" == "true" ]; then
        list_available_backups
        return 0
    fi

    # Perform restore
    if perform_restore; then
        # Verify restore if enabled
        verify_restore

        log_info "=== Restore Script Completed Successfully ==="
        return 0
    else
        log_error "=== Restore Script Failed ==="
        return 1
    fi
}

# Handle script termination
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Wait before starting the restore if initial delay is set
if [ "${BACKUP_INITIAL_DELAY_SECONDS:-0}" -gt 0 ]; then
    log_info "Waiting ${BACKUP_INITIAL_DELAY_SECONDS} seconds before starting restore..."
    sleep ${BACKUP_INITIAL_DELAY_SECONDS}
fi

# Run the restore
main "$@"
