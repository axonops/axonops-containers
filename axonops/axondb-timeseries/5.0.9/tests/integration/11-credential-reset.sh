#!/bin/bash
set -euo pipefail

# ============================================================================
# Credential Reset Test
# Purpose: Validate RESTORE_RESET_CREDENTIALS feature
# ============================================================================
# Tests:
# - Test 1: Reset to cassandra/cassandra
# - Test 2: Reset + auto-create new custom user
# - Test 3: WITHOUT reset flag, credentials preserved (regression)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

trap cleanup_test_resources EXIT

echo "========================================================================"
echo "Credential Reset Test"
echo "========================================================================"
echo ""

# Clean backup volume
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || true

run_test

# ============================================================================
# SETUP: Create backup with custom user and test data
# ============================================================================
echo "SETUP: Create backup with custom user and test data"
echo "------------------------------------------------------------------------"

podman run -d --name cred-reset-source \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=cred-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  -e AXONOPS_DB_USER=originaluser \
  -e AXONOPS_DB_PASSWORD=originalpass123 \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "cred-reset-source"

if ! wait_for_cassandra_ready "cred-reset-source" "originaluser" "originalpass123"; then
    fail_test "Credential reset" "Source container failed to start"
    exit 1
fi

echo "Waiting for init (30s)..."
sleep 30

# Create test data
echo "Creating test data..."
podman exec cred-reset-source cqlsh -u originaluser -p originalpass123 -e "CREATE KEYSPACE cred_test WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 1};" >/dev/null 2>&1
podman exec cred-reset-source cqlsh -u originaluser -p originalpass123 -e "CREATE TABLE cred_test.data (id INT PRIMARY KEY, value TEXT);" >/dev/null 2>&1
podman exec cred-reset-source cqlsh -u originaluser -p originalpass123 -e "INSERT INTO cred_test.data (id, value) VALUES (1, 'Test Row 1');" >/dev/null 2>&1
podman exec cred-reset-source cqlsh -u originaluser -p originalpass123 -e "INSERT INTO cred_test.data (id, value) VALUES (2, 'Test Row 2');" >/dev/null 2>&1

ROW_COUNT=$(podman exec cred-reset-source cqlsh -u originaluser -p originalpass123 -e "SELECT COUNT(*) FROM cred_test.data;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
if [ "$ROW_COUNT" != "2" ]; then
    fail_test "Credential reset" "Failed to create test data"
    exit 1
fi

echo "✓ Test data created (2 rows)"

# Create backup
echo "Creating backup..."
podman exec cred-reset-source /usr/local/bin/cassandra-backup.sh >/dev/null 2>&1

BACKUP_NAME=$(ls -1dt "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | head -1 | xargs basename | sed 's/^data_//')
if [ -z "$BACKUP_NAME" ]; then
    fail_test "Credential reset" "Backup not created"
    exit 1
fi

echo "✓ Backup created: $BACKUP_NAME"

# Verify original user works
if ! podman exec cred-reset-source cqlsh -u originaluser -p originalpass123 -e "SELECT COUNT(*) FROM cred_test.data;" >/dev/null 2>&1; then
    fail_test "Credential reset" "Original credentials don't work"
    exit 1
fi

echo "✓ Original user verified: originaluser/originalpass123"

# Cleanup source container
podman rm -f cred-reset-source >/dev/null 2>&1

echo "✓ Setup complete"
echo ""

# ============================================================================
# TEST 1: Credential reset to cassandra/cassandra (no custom user)
# ============================================================================
echo "TEST 1: Credential reset to cassandra/cassandra"
echo "------------------------------------------------------------------------"

podman run -d --name cred-reset-test1 \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=cred-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e RESTORE_FROM_BACKUP="$BACKUP_NAME" \
  -e RESTORE_RESET_CREDENTIALS=true \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "cred-reset-test1"

if ! wait_for_cassandra_ready "cred-reset-test1" "cassandra" "cassandra" 300; then
    fail_test "Credential reset test 1" "Container failed to start"
    podman logs cred-reset-test1 | tail -50
    exit 1
fi

echo "✓ Container started with cassandra/cassandra"

# Verify cassandra/cassandra works
if ! podman exec cred-reset-test1 cqlsh -u cassandra -p cassandra -e "SELECT COUNT(*) FROM cred_test.data;" >/dev/null 2>&1; then
    fail_test "Credential reset test 1" "cassandra/cassandra credentials don't work"
    exit 1
fi

echo "✓ cassandra/cassandra credentials work"

# Verify original user does NOT exist
if podman exec cred-reset-test1 cqlsh -u originaluser -p originalpass123 -e "SELECT COUNT(*) FROM cred_test.data;" >/dev/null 2>&1; then
    fail_test "Credential reset test 1" "Original user still exists (should be deleted)"
    exit 1
fi

echo "✓ Original user (originaluser) does NOT exist"

# Verify data preserved
RESTORED_COUNT=$(podman exec cred-reset-test1 cqlsh -u cassandra -p cassandra -e "SELECT COUNT(*) FROM cred_test.data;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
if [ "$RESTORED_COUNT" != "2" ]; then
    fail_test "Credential reset test 1" "Data not preserved (expected 2 rows, got $RESTORED_COUNT)"
    exit 1
fi

echo "✓ Data preserved (2 rows accessible)"

# Verify semaphore shows credential reset
if podman exec cred-reset-test1 grep -q "CREDENTIALS_RESET=true" /tmp/axonops-restore.done 2>/dev/null; then
    echo "✓ Restore semaphore shows CREDENTIALS_RESET=true"
else
    fail_test "Credential reset test 1" "Semaphore missing CREDENTIALS_RESET flag"
    exit 1
fi

podman rm -f cred-reset-test1 >/dev/null 2>&1

pass_test "Test 1: Credential reset to cassandra/cassandra"
echo ""

# ============================================================================
# TEST 2: Credential reset + new custom user
# ============================================================================
echo "TEST 2: Credential reset + new custom user"
echo "------------------------------------------------------------------------"

podman run -d --name cred-reset-test2 \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=cred-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e RESTORE_FROM_BACKUP="$BACKUP_NAME" \
  -e RESTORE_RESET_CREDENTIALS=true \
  -e AXONOPS_DB_USER=newuser \
  -e AXONOPS_DB_PASSWORD=newpass456 \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "cred-reset-test2"

# Wait for Cassandra to start (it will have cassandra/cassandra first)
if ! wait_for_cassandra_ready "cred-reset-test2" "cassandra" "cassandra" 180; then
    fail_test "Credential reset test 2" "Cassandra failed to start"
    podman logs cred-reset-test2 | tail -50
    exit 1
fi

echo "✓ Cassandra started with cassandra/cassandra"

# Wait for post-restore user creation script to complete
echo "Waiting for post-restore user creation (60s)..."
sleep 60

# Verify new user works
if ! podman exec cred-reset-test2 cqlsh -u newuser -p newpass456 -e "SELECT COUNT(*) FROM cred_test.data;" >/dev/null 2>&1; then
    fail_test "Credential reset test 2" "New user (newuser/newpass456) doesn't work"
    exit 1
fi

echo "✓ New user credentials work (newuser/newpass456)"

# Verify cassandra/cassandra is disabled
if podman exec cred-reset-test2 cqlsh -u cassandra -p cassandra -e "SELECT COUNT(*) FROM cred_test.data;" >/dev/null 2>&1; then
    fail_test "Credential reset test 2" "cassandra/cassandra still enabled (should be disabled)"
    exit 1
fi

echo "✓ Default cassandra user disabled (as expected)"

# Verify original user does NOT exist
if podman exec cred-reset-test2 cqlsh -u originaluser -p originalpass123 -e "SELECT COUNT(*) FROM cred_test.data;" >/dev/null 2>&1; then
    fail_test "Credential reset test 2" "Original user still exists"
    exit 1
fi

echo "✓ Original user (originaluser) does NOT exist"

# Verify data preserved
RESTORED_COUNT=$(podman exec cred-reset-test2 cqlsh -u newuser -p newpass456 -e "SELECT COUNT(*) FROM cred_test.data;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
if [ "$RESTORED_COUNT" != "2" ]; then
    fail_test "Credential reset test 2" "Data not preserved"
    exit 1
fi

echo "✓ Data preserved (2 rows)"

# Check post-restore user creation logs
if podman exec cred-reset-test2 test -f /var/log/cassandra/post-restore-user.log; then
    if podman exec cred-reset-test2 grep -q "Post-restore user creation completed" /var/log/cassandra/post-restore-user.log; then
        echo "✓ Post-restore user creation completed successfully"
    else
        echo "⚠ Post-restore user creation log exists but completion not confirmed"
    fi
fi

podman rm -f cred-reset-test2 >/dev/null 2>&1

pass_test "Test 2: Credential reset + auto-create new custom user"
echo ""

# ============================================================================
# TEST 3: Credential reset without flag (baseline - credentials preserved)
# ============================================================================
echo "TEST 3: Baseline - WITHOUT credential reset flag"
echo "------------------------------------------------------------------------"

podman run -d --name cred-reset-test3 \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=cred-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e RESTORE_FROM_BACKUP="$BACKUP_NAME" \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "cred-reset-test3"

if ! wait_for_cassandra_ready "cred-reset-test3" "originaluser" "originalpass123" 300; then
    fail_test "Credential reset test 3" "Container failed to start"
    exit 1
fi

echo "✓ Container started"

# Verify original user still works (preserved from backup)
if ! podman exec cred-reset-test3 cqlsh -u originaluser -p originalpass123 -e "SELECT COUNT(*) FROM cred_test.data;" >/dev/null 2>&1; then
    fail_test "Credential reset test 3" "Original credentials don't work (should be preserved)"
    exit 1
fi

echo "✓ Original user preserved (originaluser/originalpass123)"

# Verify data preserved
RESTORED_COUNT=$(podman exec cred-reset-test3 cqlsh -u originaluser -p originalpass123 -e "SELECT COUNT(*) FROM cred_test.data;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
if [ "$RESTORED_COUNT" != "2" ]; then
    fail_test "Credential reset test 3" "Data not preserved"
    exit 1
fi

echo "✓ Data preserved (2 rows)"

# Verify semaphore does NOT show credential reset
if podman exec cred-reset-test3 grep -q "CREDENTIALS_RESET=true" /tmp/axonops-restore.done 2>/dev/null; then
    fail_test "Credential reset test 3" "Semaphore shows CREDENTIALS_RESET but flag wasn't set"
    exit 1
fi

echo "✓ Semaphore correct (no CREDENTIALS_RESET flag)"

podman rm -f cred-reset-test3 >/dev/null 2>&1

pass_test "Test 3: Baseline - credentials preserved without reset flag"
echo ""

# ============================================================================
# SUCCESS
# ============================================================================
echo ""
pass_test "Credential reset feature validated (3 scenarios)"

print_test_summary
