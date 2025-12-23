#!/bin/bash
# Wrapper for cron backup - outputs to both console and log file
# Log file is auto-rotated to prevent unbounded growth

set -o pipefail  # Ensure tee doesn't hide exit code

LOG_FILE="/var/log/cassandra/backup-cron.log"
MAX_LINES=1000

# Run backup - output goes to both console (for kubectl logs) and file
# Using tee to send to both destinations
# set -o pipefail ensures we get backup script's exit code, not tee's
/usr/local/bin/cassandra-backup.sh 2>&1 | tee -a "$LOG_FILE"
BACKUP_EXIT=${PIPESTATUS[0]}

# Trim log file to last MAX_LINES (prevents unbounded growth)
if [ -f "$LOG_FILE" ]; then
    LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
    if [ "$LINES" -gt "$MAX_LINES" ]; then
        tail -n "$MAX_LINES" "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
fi

# Exit with backup script's exit code
exit $BACKUP_EXIT

