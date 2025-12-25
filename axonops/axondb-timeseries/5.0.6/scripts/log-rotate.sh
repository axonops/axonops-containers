#!/bin/bash
set -euo pipefail

# ============================================================================
# Log Rotation Script
# Purpose: Rotate, compress, and retain log files (similar to logrotate)
# ============================================================================
# Usage: log-rotate.sh <log_file> [size_mb] [keep_count]
#   size_mb: Rotate when log exceeds this size in MB (default: 10)
#   keep_count: Number of rotated logs to keep (default: 5)

LOG_FILE="${1:-}"
MAX_SIZE_MB="${2:-10}"
KEEP_COUNT="${3:-5}"

if [ -z "$LOG_FILE" ]; then
    echo "ERROR: Usage: $0 <log_file> [size_mb] [keep_count]"
    exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
    # Log doesn't exist yet, nothing to rotate
    exit 0
fi

# Check file size (in MB)
FILE_SIZE_BYTES=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
FILE_SIZE_MB=$((FILE_SIZE_BYTES / 1024 / 1024))

if [ "$FILE_SIZE_MB" -lt "$MAX_SIZE_MB" ]; then
    # Not large enough to rotate yet
    exit 0
fi

# Rotate logs
# Pattern: log.1.gz (newest) → log.2.gz → ... → log.N.gz (oldest, deleted)

# Remove oldest log if at limit
OLDEST_LOG="${LOG_FILE}.${KEEP_COUNT}.gz"
if [ -f "$OLDEST_LOG" ]; then
    rm -f "$OLDEST_LOG"
fi

# Shift existing rotated logs (N-1 → N, N-2 → N-1, ...)
for i in $(seq $((KEEP_COUNT - 1)) -1 1); do
    OLD_LOG="${LOG_FILE}.${i}.gz"
    NEW_LOG="${LOG_FILE}.$((i + 1)).gz"

    if [ -f "$OLD_LOG" ]; then
        mv "$OLD_LOG" "$NEW_LOG"
    fi
done

# Compress current log to .1.gz
if command -v gzip >/dev/null 2>&1; then
    gzip -c "$LOG_FILE" > "${LOG_FILE}.1.gz"
else
    # Fallback: just copy if gzip not available
    cp "$LOG_FILE" "${LOG_FILE}.1"
fi

# Truncate current log
> "$LOG_FILE"

# Log the rotation (to new empty log)
echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [LOG-ROTATE] Rotated log (size: ${FILE_SIZE_MB}MB, keeping last ${KEEP_COUNT} rotations)" >> "$LOG_FILE"

exit 0
