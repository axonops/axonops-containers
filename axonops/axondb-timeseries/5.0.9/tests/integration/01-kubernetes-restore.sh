#!/bin/bash
set -euo pipefail

# ============================================================================
# Kubernetes-Style Restore Test
# Purpose: Validate pod recreation pattern with .axonops preservation
# ============================================================================
# Tests:
# - Container 1: Create data with init enabled + custom user
# - Backup (verify .axonops directory included)
# - Destroy container 1 (simulate pod deletion)
# - Container 2: Restore from same volume
# - Verify: Init semaphores from backup (not re-run)
# - Verify: Custom credentials work
# - Verify: Data restored correctly

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

trap cleanup_test_resources EXIT

echo "========================================================================"
echo "Kubernetes-Style Restore Test"
echo "========================================================================"
echo ""

# Clean backup volume
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || true

run_test

# ============================================================================
# STEP 1: Create source container with init + custom user
# ============================================================================
echo "STEP 1: Create source container with init enabled"
echo "------------------------------------------------------------------------"

create_test_container "k8s-backup-source" "\
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  -e AXONOPS_DB_USER=testuser \
  -e AXONOPS_DB_PASSWORD=testpass123"

if ! wait_for_cassandra_ready "k8s-backup-source"; then
    fail_test "K8s restore" "Source container failed to start"
    exit 1
fi

# Wait for init to complete
echo "Waiting for init scripts (30s)..."
sleep 30

# Verify init completed
if ! podman exec k8s-backup-source test -f /var/lib/cassandra/.axonops/init-system-keyspaces.done; then
    fail_test "K8s restore" "Init semaphore not created"
    exit 1
fi

INIT_RESULT=$(podman exec k8s-backup-source grep "^RESULT=" /var/lib/cassandra/.axonops/init-system-keyspaces.done | cut -d'=' -f2)
if [ "$INIT_RESULT" != "success" ]; then
    fail_test "K8s restore" "Init failed: $INIT_RESULT"
    exit 1
fi

echo "✓ Init completed successfully"

# ============================================================================
# STEP 2: Create test data with custom credentials
# ============================================================================
echo ""
echo "STEP 2: Create test data"
echo "------------------------------------------------------------------------"

podman exec k8s-backup-source cqlsh -u testuser -p testpass123 -e "CREATE KEYSPACE k8s_demo WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 1};" >/dev/null 2>&1
podman exec k8s-backup-source cqlsh -u testuser -p testpass123 -e "CREATE TABLE k8s_demo.data (id INT PRIMARY KEY, value TEXT);" >/dev/null 2>&1
podman exec k8s-backup-source cqlsh -u testuser -p testpass123 -e "INSERT INTO k8s_demo.data (id, value) VALUES (1, 'K8S Test Row 1');" >/dev/null 2>&1
podman exec k8s-backup-source cqlsh -u testuser -p testpass123 -e "INSERT INTO k8s_demo.data (id, value) VALUES (2, 'K8S Test Row 2');" >/dev/null 2>&1

ROW_COUNT=$(podman exec k8s-backup-source cqlsh -u testuser -p testpass123 -e "SELECT COUNT(*) FROM k8s_demo.data;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
if [ "$ROW_COUNT" != "2" ]; then
    fail_test "K8s restore" "Failed to create test data (got $ROW_COUNT rows)"
    exit 1
fi

echo "✓ Created 2 rows with custom user (testuser)"

# ============================================================================
# STEP 3: Create backup
# ============================================================================
echo ""
echo "STEP 3: Create backup"
echo "------------------------------------------------------------------------"

podman exec k8s-backup-source /usr/local/bin/cassandra-backup.sh >/dev/null 2>&1

BACKUP_NAME=$(ls -1dt "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | head -1 | xargs basename | sed 's/^data_//')
if [ -z "$BACKUP_NAME" ]; then
    fail_test "K8s restore" "Backup not created"
    exit 1
fi

echo "✓ Backup created: $BACKUP_NAME"

# CRITICAL: Verify .axonops in backup
if [ ! -d "$BACKUP_VOLUME/data_$BACKUP_NAME/.axonops" ]; then
    fail_test "K8s restore" ".axonops directory NOT in backup!"
    exit 1
fi

if [ ! -f "$BACKUP_VOLUME/data_$BACKUP_NAME/.axonops/init-system-keyspaces.done" ]; then
    fail_test "K8s restore" "Init semaphore NOT in backup!"
    exit 1
fi

BACKED_UP_INIT=$(grep "^RESULT=" "$BACKUP_VOLUME/data_$BACKUP_NAME/.axonops/init-system-keyspaces.done" | cut -d'=' -f2)
echo "✓ .axonops directory in backup (init result: $BACKED_UP_INIT)"

# ============================================================================
# STEP 4: Destroy source container (simulate pod deletion)
# ============================================================================
echo ""
echo "STEP 4: Destroy source container (pod deletion simulation)"
echo "------------------------------------------------------------------------"

podman rm -f k8s-backup-source >/dev/null 2>&1

if [ ! -d "$BACKUP_VOLUME/data_$BACKUP_NAME" ]; then
    fail_test "K8s restore" "Backup disappeared after container deletion"
    exit 1
fi

echo "✓ Container destroyed, backup persisted on volume"

# ============================================================================
# STEP 5: Restore to new container (simulate pod recreation)
# ============================================================================
echo ""
echo "STEP 5: Restore to new container"
echo "------------------------------------------------------------------------"

podman run -d --name k8s-restore-target \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=test-cluster \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e RESTORE_FROM_BACKUP="$BACKUP_NAME" \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "k8s-restore-target"

if ! wait_for_cassandra_ready "k8s-restore-target" "testuser" "testpass123"; then
    fail_test "K8s restore" "Restore container failed to start"
    podman logs k8s-restore-target | tail -50
    exit 1
fi

echo "✓ Restore container started"

# ============================================================================
# STEP 6: Verify restore results
# ============================================================================
echo ""
echo "STEP 6: Verify restore"
echo "------------------------------------------------------------------------"

# Check restore semaphore
RESTORE_RESULT=$(podman exec k8s-restore-target cat /tmp/axonops-restore.done 2>/dev/null | grep "^RESULT=" | cut -d'=' -f2 || echo "not_found")
if [ "$RESTORE_RESULT" != "success" ]; then
    fail_test "K8s restore" "Restore semaphore not success: $RESTORE_RESULT"
    exit 1
fi

echo "✓ Restore completed successfully"

# Verify init semaphores from backup (NOT re-run)
RESTORED_INIT=$(podman exec k8s-restore-target grep "^RESULT=" /var/lib/cassandra/.axonops/init-system-keyspaces.done | cut -d'=' -f2)
echo "✓ Init semaphore restored from backup: $RESTORED_INIT"

# Verify init did NOT re-run
INIT_LOG_SIZE=$(podman exec k8s-restore-target stat -c%s /var/log/cassandra/init-system-keyspaces.log 2>/dev/null || echo "0")
if [ "$INIT_LOG_SIZE" -ne 0 ]; then
    fail_test "K8s restore" "Init re-ran during restore (should use backup's semaphores)"
    exit 1
fi

echo "✓ Init skipped (used semaphores from backup)"

# Verify data with custom credentials
RESTORED_COUNT=$(podman exec k8s-restore-target cqlsh -u testuser -p testpass123 -e "SELECT COUNT(*) FROM k8s_demo.data;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
if [ "$RESTORED_COUNT" != "2" ]; then
    fail_test "K8s restore" "Data not restored (expected 2, got $RESTORED_COUNT)"
    exit 1
fi

echo "✓ Data accessible with custom credentials (2 rows)"

# ============================================================================
# SUCCESS
# ============================================================================
echo ""
pass_test "Kubernetes pod recreation with .axonops preservation and custom credentials"

print_test_summary
