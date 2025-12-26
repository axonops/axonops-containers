#!/bin/bash
set -e

# Comprehensive Backup/Restore Tests - Priority 1
# Tests critical functionality that wasn't validated in smoke tests

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

TEST_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_FILE="${TEST_DIR}/results/comprehensive-test-results.txt"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

echo "======================================================================"
echo "Comprehensive Backup/Restore Tests - Priority 1"
echo "======================================================================"
echo ""
echo "Results: ${RESULTS_FILE}"
echo ""

# Initialize results
mkdir -p "$(dirname "$RESULTS_FILE")"
echo "Comprehensive Backup/Restore Test Results" > "$RESULTS_FILE"
echo "=========================================" >> "$RESULTS_FILE"
echo "Date: $(date)" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

pass_test() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    echo "✓ PASS: $1" >> "$RESULTS_FILE"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail_test() {
    echo -e "${RED}✗ FAIL${NC}: $1 - $2"
    echo "✗ FAIL: $1 - $2" >> "$RESULTS_FILE"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Wait for Cassandra to be ready (max 3 minutes)
wait_for_cassandra() {
    local container_name="$1"
    local username="${2:-cassandra}"
    local password="${3:-cassandra}"
    local max_wait=180
    local elapsed=0

    echo "Waiting for Cassandra to be ready..."

    while [ $elapsed -lt $max_wait ]; do
        # Check if port is listening
        if podman exec "$container_name" nc -z localhost 9042 2>/dev/null; then
            # Port is open, try a simple query
            if podman exec "$container_name" cqlsh -u "$username" -p "$password" -e "SELECT cluster_name FROM system.local;" >/dev/null 2>&1; then
                echo "✓ Cassandra ready (took ${elapsed}s)"
                return 0
            fi
        fi

        sleep 5
        elapsed=$((elapsed + 5))

        if [ $((elapsed % 30)) -eq 0 ]; then
            echo "  Still waiting (${elapsed}s)..."
        fi
    done

    echo "ERROR: Cassandra not ready after ${max_wait}s"
    return 1
}

# ======================================================================
# Test 1: Kubernetes-Style Restore (New Container, Same Volume)
# ======================================================================
echo "======================================================================" | tee -a "$RESULTS_FILE"
echo "Test 1: Kubernetes-Style Restore (Pod Recreation Simulation)" | tee -a "$RESULTS_FILE"
echo "======================================================================" | tee -a "$RESULTS_FILE"
echo ""

run_test
echo "Creating first container with data..."

# Clean old backups (sudo for permission issues with cassandra-owned files)
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || echo "  Note: Some old backups may remain (permission issues)"

# Start container WITH init enabled (validates .axonops backup/restore)
echo "Starting container with init enabled (to test .axonops semaphore preservation)..."
podman run -d --name k8s-backup-source \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=k8s-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  -e AXONOPS_DB_USER=testuser \
  -e AXONOPS_DB_PASSWORD=testpass123 \
  localhost/axondb-timeseries:backup-complete >/dev/null

# Wait for Cassandra to be ready
if ! wait_for_cassandra "k8s-backup-source"; then
    fail_test "K8s restore test" "Cassandra failed to start"
    exit 1
fi

# Wait for init scripts to complete (check semaphores)
echo "Waiting for init scripts to complete..."
sleep 30  # Give init time to run

# Check init completed successfully
if podman exec k8s-backup-source test -f /var/lib/cassandra/.axonops/init-system-keyspaces.done; then
    INIT_RESULT=$(podman exec k8s-backup-source grep "^RESULT=" /var/lib/cassandra/.axonops/init-system-keyspaces.done | cut -d'=' -f2)
    echo "  Init result: $INIT_RESULT"
    if [ "$INIT_RESULT" != "success" ]; then
        fail_test "K8s restore test" "Init failed: $INIT_RESULT"
        exit 1
    fi
else
    fail_test "K8s restore test" "Init semaphore not found"
    exit 1
fi

# Create test data using CUSTOM credentials (testuser/testpass123)
echo "Creating test data with custom user..."
podman exec k8s-backup-source cqlsh -u testuser -p testpass123 -e "CREATE KEYSPACE k8s_demo WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 1};" 2>&1 | grep -v "Warning"
podman exec k8s-backup-source cqlsh -u testuser -p testpass123 -e "CREATE TABLE k8s_demo.data (id INT PRIMARY KEY, value TEXT);" 2>&1 | grep -v "Warning"
podman exec k8s-backup-source cqlsh -u testuser -p testpass123 -e "INSERT INTO k8s_demo.data (id, value) VALUES (1, 'K8S Test Row 1');" 2>&1 | grep -v "Warning"
podman exec k8s-backup-source cqlsh -u testuser -p testpass123 -e "INSERT INTO k8s_demo.data (id, value) VALUES (2, 'K8S Test Row 2');" 2>&1 | grep -v "Warning"

# Verify data exists
ROW_COUNT=$(podman exec k8s-backup-source cqlsh -u testuser -p testpass123 -e "SELECT COUNT(*) FROM k8s_demo.data;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
if [ "$ROW_COUNT" = "2" ]; then
    echo "✓ Test data created (2 rows)"
else
    fail_test "K8s restore test" "Failed to create test data"
    exit 1
fi

# Create backup
echo "Creating backup..."
podman exec k8s-backup-source /usr/local/bin/cassandra-backup.sh >/dev/null 2>&1

# Check backup from HOST volume (more reliable than exec ls)
BACKUP_NAME=$(ls -1dt "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | head -1 | xargs basename | sed 's/^data_//')
if [ -z "$BACKUP_NAME" ]; then
    fail_test "K8s restore test" "Backup was not created"
    podman logs k8s-backup-source | grep -i "backup\|error" | tail -20
    exit 1
fi
echo "Backup created: $BACKUP_NAME"

# CRITICAL VALIDATION: Verify .axonops directory is in backup
if [ -d "$BACKUP_VOLUME/data_$BACKUP_NAME/.axonops" ]; then
    echo "✓ .axonops directory included in backup"
    # Verify semaphores exist
    if [ -f "$BACKUP_VOLUME/data_$BACKUP_NAME/.axonops/init-system-keyspaces.done" ]; then
        BACKED_UP_INIT=$(grep "^RESULT=" "$BACKUP_VOLUME/data_$BACKUP_NAME/.axonops/init-system-keyspaces.done" | cut -d'=' -f2)
        echo "  init-system-keyspaces.done: RESULT=$BACKED_UP_INIT (backed up)"
    fi
else
    fail_test "K8s restore test" ".axonops directory NOT in backup (critical feature broken!)"
    exit 1
fi

# CRITICAL: Destroy first container (simulates pod deletion in K8s)
echo "Destroying original container (simulating pod deletion)..."
podman stop k8s-backup-source >/dev/null 2>&1
podman rm k8s-backup-source >/dev/null 2>&1

# Verify volume still has backup (persistent)
if [ -d "$BACKUP_VOLUME/data_$BACKUP_NAME" ]; then
    echo "✓ Backup persisted on volume"
else
    fail_test "K8s restore test" "Backup not found on volume after container deletion"
    exit 1
fi

# Create NEW container with restore (simulates pod recreation)
echo "Creating new container with restore (simulating pod recreation)..."
podman run -d --name k8s-restore-target \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=k8s-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e RESTORE_FROM_BACKUP="$BACKUP_NAME" \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

# Wait for restore to complete and Cassandra to be ready
# Use custom credentials (testuser/testpass123) from backed up cluster
if ! wait_for_cassandra "k8s-restore-target" "testuser" "testpass123"; then
    fail_test "K8s restore test" "Cassandra failed to start after restore"
    podman logs k8s-restore-target | tail -50
    exit 1
fi

# Check if Cassandra is running
if podman exec k8s-restore-target nc -z localhost 9042 2>/dev/null; then
    echo "✓ Cassandra started after restore"

    # Verify restore semaphore (now in /tmp, not .axonops)
    RESTORE_RESULT=$(podman exec k8s-restore-target cat /tmp/axonops-restore.done 2>/dev/null | grep "^RESULT=" | cut -d'=' -f2 || echo "not_found")
    if [ "$RESTORE_RESULT" = "success" ]; then
        echo "✓ Restore semaphore shows success"
    else
        fail_test "K8s restore test" "Restore failed with RESULT=$RESTORE_RESULT"
        exit 1
    fi

    # CRITICAL: Verify init semaphores came from BACKUP (not re-run)
    if [ -f "$BACKUP_VOLUME/data_$BACKUP_NAME/.axonops/init-system-keyspaces.done" ]; then
        RESTORED_INIT=$(podman exec k8s-restore-target grep "^RESULT=" /var/lib/cassandra/.axonops/init-system-keyspaces.done | cut -d'=' -f2)
        echo "✓ Init semaphore restored from backup: RESULT=$RESTORED_INIT"

        # Check init log - should NOT show re-init (restore skipped init)
        INIT_LOG_SIZE=$(podman exec k8s-restore-target stat -c%s /var/log/cassandra/init-system-keyspaces.log 2>/dev/null || echo "0")
        if [ "$INIT_LOG_SIZE" -eq 0 ]; then
            echo "✓ Init was skipped (used semaphores from backup, not re-run)"
        else
            fail_test "K8s restore test" "Init re-ran during restore (should use backup's semaphores!)"
            exit 1
        fi
    else
        fail_test "K8s restore test" "Init semaphore not found in backup"
        exit 1
    fi

    # Verify data restored using CUSTOM credentials (testuser/testpass123)
    RESTORED_COUNT=$(podman exec k8s-restore-target cqlsh -u testuser -p testpass123 -e "SELECT COUNT(*) FROM k8s_demo.data;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
    if [ "$RESTORED_COUNT" = "2" ]; then
        echo "✓ Data restored and accessible with custom credentials"
        pass_test "Kubernetes-style restore (pod recreation + .axonops preservation + custom credentials)"
    else
        fail_test "K8s restore test" "Data not restored correctly (expected 2 rows, got $RESTORED_COUNT)"
    fi
else
    fail_test "K8s restore test" "Cassandra did not start"
fi

# Cleanup
podman stop k8s-restore-target >/dev/null 2>&1
podman rm k8s-restore-target >/dev/null 2>&1

# ======================================================================
# Test 2: Retention Policy with Manually Aged Backups
# ======================================================================
echo ""
echo "======================================================================" | tee -a "$RESULTS_FILE"
echo "Test 2: Retention Policy Deletes Old Backups" | tee -a "$RESULTS_FILE"
echo "======================================================================" | tee -a "$RESULTS_FILE"
echo ""

run_test

# Clean backup volume for test isolation (sudo for cassandra-owned files)
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || echo "  Note: Some old backups may remain"

# Start container for retention test (disable init scripts for test predictability)
podman run -d --name retention-test \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=retention-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null

if ! wait_for_cassandra "retention-test"; then
    fail_test "Retention test" "Cassandra failed to start"
    exit 1
fi

# Create 3 old backups with timestamps in names (simulating backups from 4 hours ago)
echo "Creating 3 old backups with historical timestamps..."
OLD_TIMESTAMP=$(date -u -d "4 hours ago" +%Y%m%d-%H%M%S)
for i in 1 2 3; do
    # Decrement timestamp by 10 seconds for each backup
    offset=$((i * 10))
    old_time=$(date -u -d "4 hours ago + $offset seconds" +%Y%m%d-%H%M%S)
    old_backup="${BACKUP_VOLUME}/data_backup-${old_time}"

    echo "  Creating old backup: backup-${old_time}"
    mkdir -p "$old_backup"
    echo "Simulated old backup from test" > "$old_backup/README.txt"
done

# Create 2 recent backups (real backups)
echo "Creating 2 recent backups (actual backups)..."
for i in 1 2; do
    podman exec retention-test /usr/local/bin/cassandra-backup.sh >/dev/null 2>&1
    echo "  Recent backup $i created"
    sleep 5
done

INITIAL_COUNT=$(ls -1d "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | wc -l)
echo "Initial backup count: $INITIAL_COUNT (3 old + 2 recent)"

# Trigger backup with BACKUP_RETENTION_HOURS=2 (should delete 3 old backups based on NAME timestamps)
echo "Running backup with BACKUP_RETENTION_HOURS=2..."
podman exec retention-test sh -c 'BACKUP_RETENTION_HOURS=2 /usr/local/bin/cassandra-backup.sh' >/dev/null 2>&1

# Wait for async retention cleanup to complete (it runs in background)
echo "Waiting for async retention cleanup to complete..."

# Poll for semaphore to disappear (cleanup complete)
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
        echo "✓ Async cleanup completed (took ${ELAPSED}s)"
        break
    fi
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "WARNING: Cleanup still running after ${MAX_WAIT}s (continuing anyway)"
fi

# Count remaining backups
REMAINING_COUNT=$(ls -1d "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | wc -l)
echo "Remaining backups: $REMAINING_COUNT"

# Should have: 2 recent + 1 just created = 3 total (3 old ones deleted based on NAME timestamps)
if [ "$REMAINING_COUNT" -eq 3 ]; then
    pass_test "Retention policy deletes old backups based on name timestamps (5 → 3)"
else
    fail_test "Retention policy" "Expected 3 backups, got $REMAINING_COUNT"
fi

# Cleanup
podman stop retention-test >/dev/null 2>&1
podman rm retention-test >/dev/null 2>&1

# ======================================================================
# Test 3: rsync Full Copy Mode (Hardlinks Disabled)
# ======================================================================
echo ""
echo "======================================================================" | tee -a "$RESULTS_FILE"
echo "Test 3: rsync Full Copy Mode (BACKUP_USE_HARDLINKS=false)" | tee -a "$RESULTS_FILE"
echo "======================================================================" | tee -a "$RESULTS_FILE"
echo ""

run_test

# Clean backups (sudo for cassandra-owned files)
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || echo "  Note: Some old backups may remain"

# Start container (disable init scripts for test predictability)
podman run -d --name hardlink-disabled-test \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=hardlink-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null

if ! wait_for_cassandra "hardlink-disabled-test"; then
    fail_test "Hardlink disabled test" "Cassandra failed to start"
    exit 1
fi

# Create first backup (full copy)
echo "Creating first backup..."
podman exec hardlink-disabled-test sh -c 'BACKUP_USE_HARDLINKS=false /usr/local/bin/cassandra-backup.sh' >/dev/null 2>&1

BACKUP_1=$(ls -1dt "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | head -1)
if [ -z "$BACKUP_1" ]; then
    fail_test "Hardlink disabled test" "First backup was not created"
    exit 1
fi
echo "First backup: $(basename $BACKUP_1)"

sleep 5

# Create second backup (should also be full copy, no hardlinks)
echo "Creating second backup with hardlinks disabled..."
podman exec hardlink-disabled-test sh -c 'BACKUP_USE_HARDLINKS=false /usr/local/bin/cassandra-backup.sh' >/dev/null 2>&1

BACKUP_2=$(ls -1dt "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | head -1)
if [ -z "$BACKUP_2" ]; then
    fail_test "Hardlink disabled test" "Second backup was not created"
    exit 1
fi
echo "Second backup: $(basename $BACKUP_2)"

# Verify NO hardlinks (all files should have Links: 1)
# Check from HOST filesystem (more reliable than podman exec)
HARDLINKED_COUNT=$(find "$BACKUP_2" -type f -links +1 2>/dev/null | wc -l)

if [ "$HARDLINKED_COUNT" -eq 0 ]; then
    pass_test "rsync full copy mode (no hardlinks, all files independent)"
else
    fail_test "rsync full copy mode" "Found $HARDLINKED_COUNT hardlinked files (should be 0)"
fi

# Cleanup
podman stop hardlink-disabled-test >/dev/null 2>&1
podman rm hardlink-disabled-test >/dev/null 2>&1

# ======================================================================
# Test 4: Hardlink Chain Integrity After Deletion
# ======================================================================
echo ""
echo "======================================================================" | tee -a "$RESULTS_FILE"
echo "Test 4: Hardlink Chain Integrity (Delete Oldest, Verify Data)" | tee -a "$RESULTS_FILE"
echo "======================================================================" | tee -a "$RESULTS_FILE"
echo ""

run_test

# Clean backups (sudo for cassandra-owned files)
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || echo "  Note: Some old backups may remain"

# Start container (disable init scripts for test predictability)
podman run -d --name hardlink-chain-test \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=chain-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null

if ! wait_for_cassandra "hardlink-chain-test"; then
    fail_test "Hardlink chain test" "Cassandra failed to start"
    exit 1
fi

# Create backup chain: backup-1, backup-2 (links to 1), backup-3 (links to 2)
echo "Creating backup chain (3 backups)..."
for i in {1..3}; do
    podman exec hardlink-chain-test /usr/local/bin/cassandra-backup.sh >/dev/null 2>&1
    echo "  Backup $i created"
    sleep 5
done

# Get backup names from HOST volume (oldest to newest) - directories only
BACKUP_1=$(find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_backup-*" -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | cut -d' ' -f2)
BACKUP_2=$(find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_backup-*" -printf '%T@ %p\n' 2>/dev/null | sort -n | head -2 | tail -1 | cut -d' ' -f2)
BACKUP_3=$(find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_backup-*" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2)

if [ -z "$BACKUP_1" ] || [ -z "$BACKUP_2" ] || [ -z "$BACKUP_3" ]; then
    fail_test "Hardlink chain test" "Failed to create backup chain"
    exit 1
fi

echo "Backup 1 (oldest): $(basename $BACKUP_1)"
echo "Backup 2 (middle): $(basename $BACKUP_2)"
echo "Backup 3 (newest): $(basename $BACKUP_3)"

# Pick a file from backup-2 that should be hardlinked
# Access from HOST filesystem
TEST_FILE=$(find "$BACKUP_2" -type f -name "*.db" -links +1 2>/dev/null | head -1)

if [ -z "$TEST_FILE" ]; then
    fail_test "Hardlink chain test" "No hardlinked files found in backup-2"
else
    echo "Test file: $TEST_FILE"

    # Get inode and link count before deletion (from HOST)
    INODE_BEFORE=$(stat "$TEST_FILE" | grep Inode | awk '{print $4}' | tr -d ',')
    LINKS_BEFORE=$(stat "$TEST_FILE" | grep Links | awk '{print $2}')

    echo "Before deletion:"
    echo "  Inode: $INODE_BEFORE"
    echo "  Links: $LINKS_BEFORE"

    # Delete backup-1 (oldest) from HOST
    echo "Deleting oldest backup: $(basename $BACKUP_1)"
    sudo rm -rf "$BACKUP_1" 2>&1 | head -5

    # Verify file in backup-2 still exists with same inode
    if [ -f "$TEST_FILE" ]; then
        INODE_AFTER=$(stat "$TEST_FILE" | grep Inode | awk '{print $4}' | tr -d ',')
        LINKS_AFTER=$(stat "$TEST_FILE" | grep Links | awk '{print $2}')

        echo "After deletion:"
        echo "  Inode: $INODE_AFTER"
        echo "  Links: $LINKS_AFTER"

        if [ "$INODE_BEFORE" = "$INODE_AFTER" ]; then
            pass_test "Hardlink chain integrity (data preserved after deleting oldest backup)"
        else
            fail_test "Hardlink chain integrity" "Inode changed (data corrupted?)"
        fi
    else
        fail_test "Hardlink chain integrity" "File no longer exists after deleting backup-1"
    fi
fi

# Cleanup
podman stop hardlink-chain-test >/dev/null 2>&1
podman rm hardlink-chain-test >/dev/null 2>&1

# ======================================================================
# Summary
# ======================================================================
echo ""
echo "======================================================================" | tee -a "$RESULTS_FILE"
echo "TEST SUMMARY" | tee -a "$RESULTS_FILE"
echo "======================================================================" | tee -a "$RESULTS_FILE"
echo ""

echo "Tests Run:    $TESTS_RUN" | tee -a "$RESULTS_FILE"
echo "Tests Passed: $TESTS_PASSED" | tee -a "$RESULTS_FILE"
echo "Tests Failed: $TESTS_FAILED" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL COMPREHENSIVE TESTS PASSED!${NC}" | tee -a "$RESULTS_FILE"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}" | tee -a "$RESULTS_FILE"
    exit 1
fi
