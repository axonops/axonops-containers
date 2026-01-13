#!/bin/bash

# Cassandra Backup Script using rclone
# This script copies the contents of /backups directory to a configured remote target
# Required environment variables:
#   RCLONE_REMOTE_NAME: The name of the configured rclone remote (e.g., "s3", "gcs", "azure")
#   RCLONE_REMOTE_PATH: The path in the remote storage (e.g., "my-bucket/cassandra-backups")
# Optional environment variables:
#   BACKUP_SOURCE_DIR: Source directory (default: /backups)
#   RCLONE_FLAGS: Additional rclone flags (default: "--verbose --stats 60s")
#   BACKUP_RETENTION_DAYS: Number of days to retain old backups (optional)

set -euo pipefail

# Default values
BACKUP_SOURCE_DIR="${BACKUP_VOLUME:-/backups}"
RCLONE_FLAGS="${RCLONE_FLAGS:---verbose --stats 60s}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
HOSTNAME="${HOSTNAME:-$(hostname)}"
RCLONE_REMOTE_NAME="${RCLONE_REMOTE_NAME:-CASS}"
BACKUP_RETENTION_DAYS="${SNAPSHOT_RETENTION_DAYS:-7}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
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

    if ! command -v rclone &> /dev/null; then
        log_error "rclone is not installed or not in PATH"
        error=1
    fi

    if [ ! -d "$BACKUP_SOURCE_DIR" ]; then
        log_error "Source directory $BACKUP_SOURCE_DIR does not exist"
        error=1
    fi

    if [ $error -eq 1 ]; then
        log_error "Prerequisites check failed. Exiting."
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Perform the backup
perform_backup() {
    local source="$BACKUP_SOURCE_DIR"
    local destination="${RCLONE_REMOTE_NAME}:${RCLONE_REMOTE_PATH}/${HOSTNAME}/${TIMESTAMP}"

    log_info "Starting backup from $source to $destination"
    log_info "Using rclone flags: $RCLONE_FLAGS"

    # Check if source directory has content
    if [ -z "$(ls -A "$source" 2>/dev/null)" ]; then
        log_warning "Source directory $source is empty. Nothing to backup."
        exit 0
    fi

    # Count files to backup
    file_count=$(find "$source" -type f | wc -l)
    log_info "Found $file_count files to backup"

    # Perform the backup
    if rclone copy "$source" "$destination" $RCLONE_FLAGS; then
        log_info "Backup completed successfully to $destination"

        # Optionally create a latest symlink/marker
        if [ "${CREATE_LATEST_MARKER:-true}" == "true" ]; then
            echo "$TIMESTAMP" | rclone rcat "${RCLONE_REMOTE_NAME}:${RCLONE_REMOTE_PATH}/${HOSTNAME}/LATEST.txt" 2>/dev/null || \
                log_warning "Could not update LATEST.txt marker"
        fi

        return 0
    else
        log_error "Backup failed with exit code $?"
        return 1
    fi
}

# Clean up old backups based on retention policy
cleanup_old_backups() {
    if [ -z "${BACKUP_RETENTION_DAYS:-}" ]; then
        log_info "No retention policy set (BACKUP_RETENTION_DAYS not defined)"
        return 0
    fi

    log_info "Cleaning up backups older than $BACKUP_RETENTION_DAYS days"

    local cutoff_date=$(date -d "${BACKUP_RETENTION_DAYS} days ago" +%Y%m%d 2>/dev/null || \
                       date -v-${BACKUP_RETENTION_DAYS}d +%Y%m%d 2>/dev/null || \
                       echo "")

    if [ -z "$cutoff_date" ]; then
        log_warning "Could not calculate cutoff date for retention. Skipping cleanup."
        return 0
    fi

    # List and remove old backup directories
    rclone lsd "${RCLONE_REMOTE_NAME}:${RCLONE_REMOTE_PATH}/${HOSTNAME}" 2>/dev/null | \
    while read -r size date time name; do
        if [[ "$name" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
            backup_date="${name:0:8}"
            if [[ "$backup_date" < "$cutoff_date" ]]; then
                log_info "Removing old backup: $name"
                rclone purge "${RCLONE_REMOTE_NAME}:${RCLONE_REMOTE_PATH}/${HOSTNAME}/$name" || \
                    log_warning "Failed to remove old backup: $name"
            fi
        fi
    done
}

# Verify backup (optional)
verify_backup() {
    if [ "${VERIFY_BACKUP:-false}" != "true" ]; then
        return 0
    fi

    local destination="${RCLONE_REMOTE_NAME}:${RCLONE_REMOTE_PATH}/${HOSTNAME}/${TIMESTAMP}"
    log_info "Verifying backup at $destination"

    local remote_count=$(rclone ls "$destination" 2>/dev/null | wc -l)
    local local_count=$(find "$BACKUP_SOURCE_DIR" -type f | wc -l)

    if [ "$remote_count" -eq "$local_count" ]; then
        log_info "Verification passed: $remote_count files in backup"
        return 0
    else
        log_error "Verification failed: Local files: $local_count, Remote files: $remote_count"
        return 1
    fi
}

# Main execution
main() {
    log_info "=== Cassandra Backup Script Started ==="
    log_info "Hostname: $HOSTNAME"
    log_info "Timestamp: $TIMESTAMP"
    log_info "Source Directory: $BACKUP_SOURCE_DIR"
    log_info "Remote: ${RCLONE_REMOTE_NAME}:${RCLONE_REMOTE_PATH}"

    # Check requirements
    check_requirements

    # Test rclone configuration
    log_info "Testing rclone configuration..."
    if ! rclone lsd "${RCLONE_REMOTE_NAME}:" &>/dev/null; then
        log_error "Failed to connect to remote storage. Please check rclone configuration."
        exit 1
    fi

    # Perform backup
    if perform_backup; then
        # Verify backup if enabled
        verify_backup

        # Clean up old backups
        cleanup_old_backups

        log_info "=== Backup Script Completed Successfully ==="
        exit 0
    else
        log_error "=== Backup Script Failed ==="
        exit 1
    fi
}

# Handle script termination
trap 'log_error "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"
