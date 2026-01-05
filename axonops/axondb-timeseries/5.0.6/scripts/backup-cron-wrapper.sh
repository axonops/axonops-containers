#!/bin/bash
# Wrapper for cron backup - outputs to both console and log file
# Log file is rotated (compressed, retained) to prevent unbounded growth

set -o pipefail  # Ensure tee doesn't hide exit code

LOG_FILE="/var/log/cassandra/backup-cron.log"

# Run backup - output goes to both console (for kubectl logs) and file
# Using tee to send to both destinations
# set -o pipefail ensures we get backup script's exit code, not tee's
/usr/local/bin/cassandra-backup.sh 2>&1 | tee -a "$LOG_FILE"
BACKUP_EXIT=${PIPESTATUS[0]}

# Rotate log file if needed (size-based, compressed, retained)
# Configurable via env vars (defaults: 10MB, keep 5 rotations)
ROTATE_SIZE_MB="${BACKUP_LOG_ROTATE_SIZE_MB:-10}"
ROTATE_KEEP="${BACKUP_LOG_ROTATE_KEEP:-5}"

/usr/local/bin/log-rotate.sh "$LOG_FILE" "$ROTATE_SIZE_MB" "$ROTATE_KEEP" 2>/dev/null || true

# Exit with backup script's exit code
exit $BACKUP_EXIT

