#!/bin/bash
set -e

# AxonDB Cassandra Backup/Restore Comprehensive Smoke Tests
# Tests backup script, restore script, retry logic, timeout handling, and error scenarios

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_FILE="${TEST_DIR}/backup-smoke-test-results.txt"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

echo "AxonDB Cassandra Backup/Restore Comprehensive Smoke Test Suite"
echo "=============================================================="
echo ""
echo "Test results will be saved to: ${RESULTS_FILE}"
echo ""

# Initialize results file
echo "AxonDB Cassandra Backup/Restore Smoke Test Results" > "$RESULTS_FILE"
echo "===================================================" >> "$RESULTS_FILE"
echo "Date: $(date)" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test functions
pass_test() {
    local test_name="$1"
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
    echo "✓ PASS: $test_name" >> "$RESULTS_FILE"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail_test() {
    local test_name="$1"
    local reason="$2"
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    echo "  Reason: $reason"
    echo "✗ FAIL: $test_name - $reason" >> "$RESULTS_FILE"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-cassandra-backup-test}"
CQL_PORT=9042

echo "Configuration:"
echo "  Container: $CONTAINER_NAME"
echo "  CQL Port: $CQL_PORT"
echo ""

# Check if container is running
if ! podman inspect "$CONTAINER_NAME" > /dev/null 2>&1; then
    echo "ERROR: Container '$CONTAINER_NAME' not found or not running"
    echo "Please start the container first"
    exit 1
fi

echo "========================================" | tee -a "$RESULTS_FILE"
echo "BACKUP SCRIPT TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 1: Backup script exists and is executable
run_test
echo "Test 1: Backup script exists and is executable"
if podman exec "$CONTAINER_NAME" test -x /usr/local/bin/cassandra-backup.sh; then
    pass_test "Backup script exists and is executable"
else
    fail_test "Backup script existence" "Script not found or not executable"
fi

# Test 2: Create first backup (full copy, no hardlinks)
run_test
echo "Test 2: Create first backup"
START_TIME=$(date +%s)
if podman exec "$CONTAINER_NAME" /usr/local/bin/cassandra-backup.sh > /tmp/backup-test-1.log 2>&1; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    # Check if backup directory was created
    BACKUP_COUNT=$(podman exec "$CONTAINER_NAME" sh -c 'ls -1d /backup/data_backup-* 2>/dev/null | wc -l')
    if [ "$BACKUP_COUNT" -ge 1 ]; then
        pass_test "First backup created successfully (took ${DURATION}s)"
    else
        fail_test "First backup" "No backup directory found"
        cat /tmp/backup-test-1.log
    fi
else
    fail_test "First backup" "Backup script failed"
    cat /tmp/backup-test-1.log
fi

# Test 3: Verify backup contains schema.cql
run_test
echo "Test 3: Backup contains schema.cql"
LATEST_BACKUP=$(podman exec "$CONTAINER_NAME" sh -c 'ls -1dt /backup/data_backup-* 2>/dev/null | head -1')
if podman exec "$CONTAINER_NAME" test -f "${LATEST_BACKUP}/schema.cql"; then
    SCHEMA_LINES=$(podman exec "$CONTAINER_NAME" sh -c "wc -l < ${LATEST_BACKUP}/schema.cql")
    pass_test "Schema dump exists (${SCHEMA_LINES} lines)"
else
    fail_test "Schema dump" "schema.cql not found in backup"
fi

# Test 4: Verify snapshot was cleaned up
run_test
echo "Test 4: Snapshot cleaned up after backup"
SNAPSHOT_OUTPUT=$(podman exec "$CONTAINER_NAME" nodetool listsnapshots 2>/dev/null)
if echo "$SNAPSHOT_OUTPUT" | grep -q "There are no snapshots"; then
    pass_test "Snapshot cleaned up (no snapshots remain)"
else
    SNAPSHOT_COUNT=$(echo "$SNAPSHOT_OUTPUT" | grep -c "backup-" || echo "0")
    fail_test "Snapshot cleanup" "Found $SNAPSHOT_COUNT snapshot(s) still present"
fi

# Test 5: Create second backup (should use hardlinks)
run_test
echo "Test 5: Create second backup with hardlink deduplication"
sleep 5  # Ensure different timestamp

# Clean any stale lock from previous test (trap may not have run yet)
podman exec "$CONTAINER_NAME" rm -f /var/lib/cassandra/.axonops/backup.lock 2>/dev/null || true

if podman exec "$CONTAINER_NAME" /usr/local/bin/cassandra-backup.sh > /tmp/backup-test-2.log 2>&1; then
    # Check for hardlink deduplication message
    if grep -q "Using hardlink deduplication" /tmp/backup-test-2.log; then
        # Verify hardlinks exist
        BACKUP_COUNT=$(podman exec "$CONTAINER_NAME" sh -c 'ls -1d /backup/data_backup-* 2>/dev/null | wc -l')
        if [ "$BACKUP_COUNT" -ge 2 ]; then
            # Check for hardlinked files
            LATEST=$(podman exec "$CONTAINER_NAME" sh -c 'ls -1dt /backup/data_backup-* | head -1')
            HARDLINKED=$(podman exec "$CONTAINER_NAME" find "$LATEST" -type f -links +1 2>/dev/null | wc -l)
            if [ "$HARDLINKED" -gt 0 ]; then
                pass_test "Second backup uses hardlinks ($HARDLINKED files deduplicated)"
            else
                fail_test "Hardlink deduplication" "No hardlinked files found"
            fi
        else
            fail_test "Second backup" "Expected 2 backups, found $BACKUP_COUNT"
        fi
    else
        fail_test "Hardlink deduplication" "Deduplication not used"
        cat /tmp/backup-test-2.log
    fi
else
    fail_test "Second backup" "Backup script failed"
    cat /tmp/backup-test-2.log
fi

# Test 6: Verify backup logging includes timings
run_test
echo "Test 6: Backup logs include operation timings"
if grep -qE "took [0-9]+(s|m)" /tmp/backup-test-2.log; then
    TIMING_COUNT=$(grep -cE "took [0-9]+(s|m)" /tmp/backup-test-2.log)
    pass_test "Backup logs include timings ($TIMING_COUNT timing logs found)"
else
    fail_test "Backup timings" "No timing information found in logs"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "RESTORE SCRIPT TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 7: Restore script exists and is executable
run_test
echo "Test 7: Restore script exists and is executable"
if podman exec "$CONTAINER_NAME" test -x /usr/local/bin/cassandra-restore.sh; then
    pass_test "Restore script exists and is executable"
else
    fail_test "Restore script existence" "Script not found or not executable"
fi

# Test 8: Full restore cycle via entrypoint
run_test
echo "Test 8: Full restore cycle (entrypoint integration)"
echo "  Creating new container with restore from backup..."

# Get a backup created by THIS test run (most recent)
RESTORE_BACKUP=$(podman exec "$CONTAINER_NAME" sh -c 'ls -1dt /backup/data_backup-* | head -1 | xargs basename | sed "s/^data_//"')
echo "  Restoring from: $RESTORE_BACKUP"

# Stop current container
podman stop "$CONTAINER_NAME" >/dev/null 2>&1

# Start new container with RESTORE_FROM_BACKUP env var
# CRITICAL: Use SAME cluster name as backup was created with
# Get original cluster name from running container
ORIG_CLUSTER=$(podman exec "$CONTAINER_NAME" printenv CASSANDRA_CLUSTER_NAME)
RESTORE_CONTAINER="${CONTAINER_NAME}-restore"
podman run -d --name "$RESTORE_CONTAINER" \
  -v ~/axondb-backup-testing/backup-volume:/backup \
  -e CASSANDRA_CLUSTER_NAME="$ORIG_CLUSTER" \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=2G \
  -e RESTORE_FROM_BACKUP="$RESTORE_BACKUP" \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

# Wait for restore to complete and Cassandra to start (restore + startup takes ~45s)
sleep 45
MAX_WAIT=120
ELAPSED=0
until podman exec "$RESTORE_CONTAINER" nc -z localhost "$CQL_PORT" 2>/dev/null; do
    if [ $ELAPSED -gt $MAX_WAIT ]; then
        fail_test "Restore via entrypoint" "Cassandra did not start within ${MAX_WAIT}s"
        podman logs "$RESTORE_CONTAINER" 2>&1 | tail -50
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if podman exec "$RESTORE_CONTAINER" nc -z localhost "$CQL_PORT" 2>/dev/null; then
    # Check restore semaphore
    if podman exec "$RESTORE_CONTAINER" test -f /var/lib/cassandra/.axonops/restore.done; then
        RESTORE_RESULT=$(podman exec "$RESTORE_CONTAINER" cat /var/lib/cassandra/.axonops/restore.done 2>/dev/null | grep "^RESULT=" | cut -d'=' -f2)
        if [ "$RESTORE_RESULT" = "success" ]; then
            pass_test "Restore via entrypoint successful (Cassandra started with restored data)"
        else
            fail_test "Restore via entrypoint" "RESULT=$RESTORE_RESULT (expected success)"
        fi
    else
        fail_test "Restore via entrypoint" "Restore semaphore not found"
    fi
else
    fail_test "Restore via entrypoint" "Cassandra did not start"
fi

# Clean up restore container and restart original
podman stop "$RESTORE_CONTAINER" >/dev/null 2>&1
podman rm "$RESTORE_CONTAINER" >/dev/null 2>&1
podman start "$CONTAINER_NAME" >/dev/null 2>&1

# Wait for original container to be ready again
sleep 30
until podman exec "$CONTAINER_NAME" nc -z localhost "$CQL_PORT" 2>/dev/null; do
    sleep 5
done

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "RETENTION POLICY TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 9: Backup retention in hours (not days)
run_test
echo "Test 9: Backup retention uses BACKUP_RETENTION_HOURS"
if podman exec "$CONTAINER_NAME" grep -q "BACKUP_RETENTION_HOURS" /usr/local/bin/cassandra-backup.sh; then
    pass_test "Backup script uses BACKUP_RETENTION_HOURS"
else
    fail_test "Retention hours" "BACKUP_RETENTION_HOURS not found in script"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "ERROR HANDLING TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 13: Hardlink filesystem check
run_test
echo "Test 10: Hardlink filesystem support check exists"
if podman exec "$CONTAINER_NAME" grep -q "Testing filesystem hardlink support" /usr/local/bin/cassandra-backup.sh; then
    pass_test "Hardlink support test exists in backup script"
else
    fail_test "Hardlink check" "Hardlink support test not found"
fi

# Test 14: rsync retry mechanism
run_test
echo "Test 11: rsync retry mechanism exists"
if podman exec "$CONTAINER_NAME" grep -q "BACKUP_RSYNC_RETRIES" /usr/local/bin/cassandra-backup.sh; then
    pass_test "rsync retry mechanism implemented"
else
    fail_test "rsync retry" "BACKUP_RSYNC_RETRIES not found"
fi

# Test 15: rsync timeout mechanism
run_test
echo "Test 12: rsync timeout mechanism exists"
if podman exec "$CONTAINER_NAME" grep -q "BACKUP_RSYNC_TIMEOUT_MINUTES" /usr/local/bin/cassandra-backup.sh; then
    pass_test "rsync timeout mechanism implemented"
else
    fail_test "rsync timeout" "BACKUP_RSYNC_TIMEOUT_MINUTES not found"
fi

# Test 16: rsync extra options support
run_test
echo "Test 13: rsync extra options support"
if podman exec "$CONTAINER_NAME" grep -q "BACKUP_RSYNC_EXTRA_OPTS" /usr/local/bin/cassandra-backup.sh; then
    pass_test "rsync extra options supported"
else
    fail_test "rsync extra opts" "BACKUP_RSYNC_EXTRA_OPTS not found"
fi

# Test 17: Restore script checks if Cassandra is running (FATAL)
run_test
echo "Test 14: Restore script checks if Cassandra is running"
if podman exec "$CONTAINER_NAME" grep -q "Cassandra is running - this should NEVER happen" /usr/local/bin/cassandra-restore.sh; then
    pass_test "Restore script has Cassandra running check (FATAL)"
else
    fail_test "Cassandra running check" "Check not found or not FATAL"
fi

# Test 18: Restore script has retry mechanism
run_test
echo "Test 15: Restore script has rsync retry mechanism"
if podman exec "$CONTAINER_NAME" grep -q "RESTORE_RSYNC_RETRIES" /usr/local/bin/cassandra-restore.sh; then
    pass_test "Restore rsync retry mechanism implemented"
else
    fail_test "Restore rsync retry" "RESTORE_RSYNC_RETRIES not found"
fi

# Test 19: Backup script gracefully skips when Cassandra not running
run_test
echo "Test 16: Backup script skips gracefully when Cassandra not running"
if podman exec "$CONTAINER_NAME" grep -q "WARNING: Cassandra process is not running" /usr/local/bin/cassandra-backup.sh; then
    # Check that script exits 0 (not 1) when Cassandra not running
    if podman exec "$CONTAINER_NAME" sh -c 'grep -A5 "WARNING: Cassandra process is not running" /usr/local/bin/cassandra-backup.sh' | grep -q "exit 0"; then
        pass_test "Backup script gracefully skips when Cassandra not running (exit 0)"
    else
        fail_test "Backup Cassandra check" "Script doesn't exit 0 after warning"
    fi
else
    fail_test "Backup Cassandra check" "Warning message not found"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "SINGLE-NODE ENFORCEMENT TEST" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 20: Backup script enforces single-node only
run_test
echo "Test 17: Backup script enforces single-node clusters"
if podman exec "$CONTAINER_NAME" grep -q "Backup is only supported for single-node clusters" /usr/local/bin/cassandra-backup.sh; then
    pass_test "Single-node enforcement exists"
else
    fail_test "Single-node enforcement" "Check not found"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "CONFIGURATION VARIABLES TEST" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 21: All required environment variables documented
run_test
echo "Test 18: Environment variables properly configured"
REQUIRED_VARS="BACKUP_RETENTION_HOURS BACKUP_USE_HARDLINKS BACKUP_RSYNC_RETRIES BACKUP_RSYNC_TIMEOUT_MINUTES BACKUP_RSYNC_EXTRA_OPTS"
MISSING=""
for var in $REQUIRED_VARS; do
    if ! podman exec "$CONTAINER_NAME" grep -q "$var" /usr/local/bin/cassandra-backup.sh; then
        MISSING="$MISSING $var"
    fi
done

if [ -z "$MISSING" ]; then
    pass_test "All required environment variables present"
else
    fail_test "Environment variables" "Missing:$MISSING"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "LOCK SEMAPHORE TESTS (PHASE 3)" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 19: Backup lock semaphore exists in script
run_test
echo "Test 19: Backup lock semaphore implemented"
if podman exec "$CONTAINER_NAME" grep -q "backup.lock" /usr/local/bin/cassandra-backup.sh; then
    pass_test "Backup lock semaphore implemented"
else
    fail_test "Backup lock semaphore" "Lock mechanism not found"
fi

# Test 20: Test backup lock prevents overlapping backups
run_test
echo "Test 20: Lock prevents overlapping backups"
# Create a slow backup by triggering one, then immediately triggering another
podman exec "$CONTAINER_NAME" /usr/local/bin/cassandra-backup.sh >/dev/null 2>&1 &
BACKUP_PID=$!
sleep 2  # Let first backup acquire lock

# Try to start second backup (should fail with lock error)
if podman exec "$CONTAINER_NAME" /usr/local/bin/cassandra-backup.sh > /tmp/lock-test.log 2>&1; then
    fail_test "Lock overlap prevention" "Second backup should have been rejected"
else
    # Check for ANY lock-related error message (various scenarios possible)
    if grep -qE "Backup already in progress|Backup lock exists" /tmp/lock-test.log; then
        pass_test "Lock prevents overlapping backups"
    else
        fail_test "Lock overlap prevention" "No lock error message found"
        cat /tmp/lock-test.log
    fi
fi

# Wait for first backup to finish
wait $BACKUP_PID 2>/dev/null || true

# Clean lock to avoid affecting next tests
sleep 2
podman exec "$CONTAINER_NAME" rm -f /var/lib/cassandra/.axonops/backup.lock 2>/dev/null || true

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "ORPHANED SNAPSHOT CLEANUP TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 21: Orphaned snapshot housekeeping exists
run_test
echo "Test 21: Orphaned snapshot housekeeping implemented"
if podman exec "$CONTAINER_NAME" grep -q "housekeeping_cleanup_old_snapshots" /usr/local/bin/cassandra-backup.sh; then
    pass_test "Orphaned snapshot housekeeping implemented"
else
    fail_test "Snapshot housekeeping" "Housekeeping function not found"
fi

# Test 22: SNAPSHOT_RETENTION_DAYS variable exists
run_test
echo "Test 22: SNAPSHOT_RETENTION_DAYS variable supported"
if podman exec "$CONTAINER_NAME" grep -q "SNAPSHOT_RETENTION_DAYS" /usr/local/bin/cassandra-backup.sh; then
    pass_test "SNAPSHOT_RETENTION_DAYS variable supported"
else
    fail_test "Snapshot retention days" "Variable not found"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "SCHEDULED BACKUP TESTS (PHASE 3)" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 23: Backup scheduler script exists
run_test
echo "Test 23: Backup scheduler script exists"
if podman exec "$CONTAINER_NAME" test -x /usr/local/bin/backup-scheduler.sh; then
    pass_test "Backup scheduler script exists and is executable"
else
    fail_test "Backup scheduler" "Script not found or not executable"
fi

# Test 24: Backup cron wrapper exists
run_test
echo "Test 24: Backup cron wrapper exists"
if podman exec "$CONTAINER_NAME" test -x /usr/local/bin/backup-cron-wrapper.sh; then
    pass_test "Backup cron wrapper exists and is executable"
else
    fail_test "Backup cron wrapper" "Script not found or not executable"
fi

# Test 25: No default BACKUP_SCHEDULE (must be explicitly set)
run_test
echo "Test 25: BACKUP_SCHEDULE has no default in entrypoint"
# Check that entrypoint requires explicit schedule
if podman exec "$CONTAINER_NAME" grep -q "BACKUP_ENABLED=true but BACKUP_SCHEDULE not set" /usr/local/bin/docker-entrypoint.sh; then
    pass_test "BACKUP_SCHEDULE required (no default)"
else
    fail_test "No default schedule" "Entrypoint doesn't validate BACKUP_SCHEDULE"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "TEST SUMMARY" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

echo "Tests Run:    $TESTS_RUN" | tee -a "$RESULTS_FILE"
echo "Tests Passed: $TESTS_PASSED" | tee -a "$RESULTS_FILE"
echo "Tests Failed: $TESTS_FAILED" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}" | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}" | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"
    exit 1
fi
