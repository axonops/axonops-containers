#!/bin/bash
set -e

# Comprehensive Backup/Restore Tests - Priority 1
# Tests critical functionality that wasn't validated in smoke tests

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_FILE="${TEST_DIR}/comprehensive-test-results.txt"
BACKUP_VOLUME=~/axondb-backup-testing/backup-volume

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
    local max_wait=180
    local elapsed=0

    echo "Waiting for Cassandra to be ready..."

    while [ $elapsed -lt $max_wait ]; do
        # Check if port is listening
        if podman exec "$container_name" nc -z localhost 9042 2>/dev/null; then
            # Port is open, try a simple query
            if podman exec "$container_name" cqlsh -u cassandra -p cassandra -e "SELECT cluster_name FROM system.local;" >/dev/null 2>&1; then
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

# Start container (disable init scripts for test predictability)
podman run -d --name k8s-backup-source \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=k8s-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=2G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null

# Wait for Cassandra to be ready
if ! wait_for_cassandra "k8s-backup-source"; then
    fail_test "K8s restore test" "Cassandra failed to start"
    exit 1
fi

# Create test data
echo "Creating test data..."
podman exec k8s-backup-source cqlsh -u cassandra -p cassandra -e "CREATE KEYSPACE k8s_demo WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 1};" 2>&1 | grep -v "Warning"
podman exec k8s-backup-source cqlsh -u cassandra -p cassandra -e "CREATE TABLE k8s_demo.data (id INT PRIMARY KEY, value TEXT);" 2>&1 | grep -v "Warning"
podman exec k8s-backup-source cqlsh -u cassandra -p cassandra -e "INSERT INTO k8s_demo.data (id, value) VALUES (1, 'K8S Test Row 1');" 2>&1 | grep -v "Warning"
podman exec k8s-backup-source cqlsh -u cassandra -p cassandra -e "INSERT INTO k8s_demo.data (id, value) VALUES (2, 'K8S Test Row 2');" 2>&1 | grep -v "Warning"

# Verify data exists
ROW_COUNT=$(podman exec k8s-backup-source cqlsh -u cassandra -p cassandra -e "SELECT COUNT(*) FROM k8s_demo.data;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
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
  -e CASSANDRA_HEAP_SIZE=2G \
  -e RESTORE_FROM_BACKUP="$BACKUP_NAME" \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

# Wait for restore to complete and Cassandra to be ready
if ! wait_for_cassandra "k8s-restore-target"; then
    fail_test "K8s restore test" "Cassandra failed to start after restore"
    podman logs k8s-restore-target | tail -50
    exit 1
fi

# Check if Cassandra is running
if podman exec k8s-restore-target nc -z localhost 9042 2>/dev/null; then
    echo "✓ Cassandra started after restore"

    # Verify restore semaphore
    RESTORE_RESULT=$(podman exec k8s-restore-target cat /var/lib/cassandra/.axonops/restore.done | grep "^RESULT=" | cut -d'=' -f2)
    if [ "$RESTORE_RESULT" = "success" ]; then
        echo "✓ Restore semaphore shows success"

        # Verify data restored
        RESTORED_COUNT=$(podman exec k8s-restore-target cqlsh -u cassandra -p cassandra -e "SELECT COUNT(*) FROM k8s_demo.data;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
        if [ "$RESTORED_COUNT" = "2" ]; then
            pass_test "Kubernetes-style restore (pod recreation with volume persistence)"
        else
            fail_test "K8s restore test" "Data not restored correctly (expected 2 rows, got $RESTORED_COUNT)"
        fi
    else
        fail_test "K8s restore test" "Restore failed with RESULT=$RESTORE_RESULT"
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

# Start container for retention test (disable init scripts for test predictability)
podman run -d --name retention-test \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=retention-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=2G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null

if ! wait_for_cassandra "retention-test"; then
    fail_test "Retention test" "Cassandra failed to start"
    exit 1
fi

# Create 5 backups
echo "Creating 5 backups..."
for i in {1..5}; do
    podman exec retention-test /usr/local/bin/cassandra-backup.sh >/dev/null 2>&1
    echo "  Backup $i created"
    sleep 5
done

INITIAL_COUNT=$(ls -1d "$BACKUP_VOLUME"/data_backup-* | wc -l)
echo "Initial backup count: $INITIAL_COUNT"

# Manually age first 3 backups (make them 3 hours old)
echo "Manually aging first 3 backups (3 hours old)..."
for backup in $(ls -1dt "$BACKUP_VOLUME"/data_backup-* | tail -3); do
    echo "  Aging: $(basename $backup)"
    sudo touch -d "3 hours ago" "$backup"
done

# Trigger backup with BACKUP_RETENTION_HOURS=2 (should delete aged backups)
echo "Running backup with BACKUP_RETENTION_HOURS=2..."
podman exec retention-test sh -c 'BACKUP_RETENTION_HOURS=2 /usr/local/bin/cassandra-backup.sh' >/dev/null 2>&1

# Count remaining backups
REMAINING_COUNT=$(ls -1d "$BACKUP_VOLUME"/data_backup-* | wc -l)
echo "Remaining backups: $REMAINING_COUNT"

# Should have: 2 new backups + 1 just created = 3 total (3 aged ones deleted)
if [ "$REMAINING_COUNT" -eq 3 ]; then
    pass_test "Retention policy deletes old backups (5 → 3 after deleting aged backups)"
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
  -e CASSANDRA_HEAP_SIZE=2G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null

if ! wait_for_cassandra "hardlink-disabled-test"; then
    fail_test "Hardlink disabled test" "Cassandra failed to start"
    exit 1
fi

# Create first backup (full copy)
echo "Creating first backup..."
podman exec hardlink-disabled-test sh -c 'BACKUP_USE_HARDLINKS=false /usr/local/bin/cassandra-backup.sh' >/dev/null 2>&1

BACKUP_1=$(podman exec hardlink-disabled-test ls -1dt /backup/data_backup-* | head -1)
echo "First backup: $(basename $BACKUP_1)"

sleep 5

# Create second backup (should also be full copy, no hardlinks)
echo "Creating second backup with hardlinks disabled..."
podman exec hardlink-disabled-test sh -c 'BACKUP_USE_HARDLINKS=false /usr/local/bin/cassandra-backup.sh' >/dev/null 2>&1

BACKUP_2=$(podman exec hardlink-disabled-test ls -1dt /backup/data_backup-* | head -1)
echo "Second backup: $(basename $BACKUP_2)"

# Verify NO hardlinks (all files should have Links: 1)
HARDLINKED_COUNT=$(podman exec hardlink-disabled-test find "$BACKUP_2" -type f -links +1 2>/dev/null | wc -l)

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
  -e CASSANDRA_HEAP_SIZE=2G \
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

# Get backup names (oldest to newest)
BACKUP_1=$(podman exec hardlink-chain-test ls -1t /backup/data_backup-* | tail -1)
BACKUP_2=$(podman exec hardlink-chain-test ls -1t /backup/data_backup-* | head -2 | tail -1)
BACKUP_3=$(podman exec hardlink-chain-test ls -1t /backup/data_backup-* | head -1)

echo "Backup 1 (oldest): $(basename $BACKUP_1)"
echo "Backup 2 (middle): $(basename $BACKUP_2)"
echo "Backup 3 (newest): $(basename $BACKUP_3)"

# Pick a file from backup-2 that should be hardlinked
TEST_FILE=$(podman exec hardlink-chain-test find "$BACKUP_2" -type f -name "*.db" -links +1 2>/dev/null | head -1)

if [ -z "$TEST_FILE" ]; then
    fail_test "Hardlink chain test" "No hardlinked files found in backup-2"
else
    echo "Test file: $TEST_FILE"

    # Get inode and link count before deletion
    INODE_BEFORE=$(podman exec hardlink-chain-test stat "$TEST_FILE" | grep Inode | awk '{print $3}')
    LINKS_BEFORE=$(podman exec hardlink-chain-test stat "$TEST_FILE" | grep "Links:" | awk '{print $2}')

    echo "Before deletion:"
    echo "  Inode: $INODE_BEFORE"
    echo "  Links: $LINKS_BEFORE"

    # Delete backup-1 (oldest)
    echo "Deleting oldest backup: $(basename $BACKUP_1)"
    podman exec hardlink-chain-test rm -rf "$BACKUP_1" 2>&1 | head -5

    # Verify file in backup-2 still exists with same inode
    if podman exec hardlink-chain-test test -f "$TEST_FILE"; then
        INODE_AFTER=$(podman exec hardlink-chain-test stat "$TEST_FILE" | grep Inode | awk '{print $3}')
        LINKS_AFTER=$(podman exec hardlink-chain-test stat "$TEST_FILE" | grep "Links:" | awk '{print $2}')

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
