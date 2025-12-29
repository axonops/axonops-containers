#!/bin/bash
set -euo pipefail

# ============================================================================
# Lock Semaphore Test
# Purpose: Validate backup lock prevents overlapping backups
# ============================================================================
# Tests:
# - Start backup in background
# - Try to start second backup immediately
# - Verify second backup is rejected (lock exists)
# - Wait for first backup to complete
# - Verify lock is removed

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

trap cleanup_test_resources EXIT


echo "========================================================================"
echo "Lock Semaphore Test"
echo "========================================================================"
echo ""

# Clean backup volume
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || true

run_test

# ============================================================================
# STEP 1: Create container
# ============================================================================
echo "STEP 1: Create test container"
echo "------------------------------------------------------------------------"

podman run -d --name lock-semaphore-test \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=lock-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "lock-semaphore-test"

if ! wait_for_cassandra_ready "lock-semaphore-test"; then
    fail_test "Lock semaphore" "Container failed to start"
    exit 1
fi

echo "✓ Container ready"

# ============================================================================
# STEP 2: Start first backup in background
# ============================================================================
echo ""
echo "STEP 2: Start first backup in background"
echo "------------------------------------------------------------------------"

# Start backup in background (doesn't block)
podman exec lock-semaphore-test /usr/local/bin/cassandra-backup.sh > /tmp/backup-1.log 2>&1 &
BACKUP_PID=$!

# Give it time to acquire lock
sleep 3

# Verify lock exists
if podman exec lock-semaphore-test test -f /tmp/axonops-backup.lock 2>/dev/null; then
    echo "✓ First backup acquired lock"
else
    fail_test "Lock semaphore" "Lock not created by first backup"
    wait $BACKUP_PID 2>/dev/null || true
    exit 1
fi

# ============================================================================
# STEP 3: Try to start second backup (should fail)
# ============================================================================
echo ""
echo "STEP 3: Try to start second backup (should be rejected)"
echo "------------------------------------------------------------------------"

# Try to start second backup (should fail with lock error)
if podman exec lock-semaphore-test /usr/local/bin/cassandra-backup.sh > /tmp/backup-2.log 2>&1; then
    fail_test "Lock semaphore" "Second backup should have been rejected (lock exists)"
    wait $BACKUP_PID 2>/dev/null || true
    exit 1
else
    # Check for lock-related error message
    if grep -qE "Backup already in progress|Backup lock exists|in_progress" /tmp/backup-2.log; then
        echo "✓ Second backup rejected (lock prevents overlap)"
    else
        fail_test "Lock semaphore" "Second backup failed but no lock error message"
        cat /tmp/backup-2.log
        wait $BACKUP_PID 2>/dev/null || true
        exit 1
    fi
fi

# ============================================================================
# STEP 4: Wait for first backup to complete
# ============================================================================
echo ""
echo "STEP 4: Wait for first backup to complete"
echo "------------------------------------------------------------------------"

# Wait for first backup to finish
if wait $BACKUP_PID 2>/dev/null; then
    echo "✓ First backup completed successfully"
else
    fail_test "Lock semaphore" "First backup failed"
    cat /tmp/backup-1.log
    exit 1
fi

# Give trap a moment to clean up lock
sleep 2

# ============================================================================
# STEP 5: Verify lock removed
# ============================================================================
echo ""
echo "STEP 5: Verify lock removed after completion"
echo "------------------------------------------------------------------------"

if podman exec lock-semaphore-test test -f /tmp/axonops-backup.lock 2>/dev/null; then
    fail_test "Lock semaphore" "Lock still exists after backup completed"
    exit 1
else
    echo "✓ Lock removed after backup completed"
fi

# ============================================================================
# STEP 6: Verify subsequent backup can run
# ============================================================================
echo ""
echo "STEP 6: Verify subsequent backup can now run"
echo "------------------------------------------------------------------------"

if podman exec lock-semaphore-test /usr/local/bin/cassandra-backup.sh > /tmp/backup-3.log 2>&1; then
    echo "✓ Subsequent backup succeeded (lock was properly cleaned)"
    pass_test "Lock semaphore prevents overlaps and cleans up properly"
else
    fail_test "Lock semaphore" "Subsequent backup failed (lock not cleaned?)"
    cat /tmp/backup-3.log
    exit 1
fi

# ============================================================================
# SUCCESS
# ============================================================================
echo ""
pass_test "Lock semaphore prevents overlapping backups"

print_test_summary
