#!/bin/bash
set -euo pipefail

# ============================================================================
# Retention Policy Test
# Purpose: Validate old backups deleted based on name timestamps
# ============================================================================
# Tests:
# - Create 3 old backups with timestamps 4h ago (in directory names)
# - Create 2 recent backups
# - Run backup with BACKUP_RETENTION_HOURS=2
# - Wait for async retention cleanup
# - Verify: 5 backups → 3 backups (3 old deleted)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

trap cleanup_test_resources EXIT

echo "========================================================================"
echo "Retention Policy Test"
echo "========================================================================"
echo ""

# Clean backup volume
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || true

run_test

# ============================================================================
# STEP 1: Create container (init disabled for test predictability)
# ============================================================================
echo "STEP 1: Create test container"
echo "------------------------------------------------------------------------"

podman run -d --name retention-test \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=retention-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "retention-test"

if ! wait_for_cassandra_ready "retention-test"; then
    fail_test "Retention policy" "Container failed to start"
    exit 1
fi

echo "✓ Container ready"

# ============================================================================
# STEP 2: Create 3 old backups with historical timestamps in names
# ============================================================================
echo ""
echo "STEP 2: Create 3 old backups (4 hours ago)"
echo "------------------------------------------------------------------------"

for i in 1 2 3; do
    # Create timestamps 4 hours ago, with 10-second offsets
    offset=$((i * 10))
    old_time=$(date -u -d "4 hours ago + $offset seconds" +%Y%m%d-%H%M%S)
    old_backup="${BACKUP_VOLUME}/data_backup-${old_time}"

    mkdir -p "$old_backup"
    echo "Simulated old backup from test" > "$old_backup/README.txt"

    echo "  Created: backup-${old_time}"
done

echo "✓ 3 old backups created with historical timestamps"

# ============================================================================
# STEP 3: Create 2 recent backups (real backups)
# ============================================================================
echo ""
echo "STEP 3: Create 2 recent backups"
echo "------------------------------------------------------------------------"

for i in 1 2; do
    podman exec retention-test /usr/local/bin/cassandra-backup.sh >/dev/null 2>&1
    echo "  Recent backup $i created"
    sleep 5
done

INITIAL_COUNT=$(ls -1d "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | wc -l)
echo "✓ Total backups: $INITIAL_COUNT (3 old + 2 recent)"

if [ "$INITIAL_COUNT" -ne 5 ]; then
    fail_test "Retention policy" "Expected 5 backups, got $INITIAL_COUNT"
    exit 1
fi

# ============================================================================
# STEP 4: Run backup with retention policy
# ============================================================================
echo ""
echo "STEP 4: Run backup with BACKUP_RETENTION_HOURS=2"
echo "------------------------------------------------------------------------"

podman exec retention-test sh -c 'BACKUP_RETENTION_HOURS=2 /usr/local/bin/cassandra-backup.sh' >/dev/null 2>&1

echo "✓ Backup with retention triggered (async cleanup started)"

# ============================================================================
# STEP 5: Wait for async retention cleanup
# ============================================================================
echo ""
echo "STEP 5: Wait for async retention cleanup"
echo "------------------------------------------------------------------------"

MAX_WAIT=60
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if podman exec retention-test test -f /tmp/axonops-retention-cleanup.lock 2>/dev/null; then
        if [ $((ELAPSED % 10)) -eq 0 ] && [ $ELAPSED -gt 0 ]; then
            echo "  Cleanup still running (${ELAPSED}s)..."
        fi
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    else
        echo "✓ Async cleanup completed (${ELAPSED}s)"
        break
    fi
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    fail_test "Retention policy" "Cleanup still running after ${MAX_WAIT}s"
    exit 1
fi

# ============================================================================
# STEP 6: Verify retention worked
# ============================================================================
echo ""
echo "STEP 6: Verify retention results"
echo "------------------------------------------------------------------------"

REMAINING_COUNT=$(ls -1d "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | wc -l)
echo "Remaining backups: $REMAINING_COUNT"

# Should have: 2 recent + 1 just created = 3 total (3 old deleted based on name timestamps)
if [ "$REMAINING_COUNT" -eq 3 ]; then
    echo "✓ Retention deleted 3 old backups (5 → 3)"
    pass_test "Retention policy deletes old backups based on name timestamps"
else
    fail_test "Retention policy" "Expected 3 backups, got $REMAINING_COUNT"
    exit 1
fi

# ============================================================================
# SUCCESS
# ============================================================================
echo ""
pass_test "Retention policy with async deletion and name-based timestamps"

print_test_summary
