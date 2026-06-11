#!/bin/bash
set -euo pipefail

# Source common test utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

# Trap for cleanup
trap cleanup_test_resources EXIT

# ============================================================================
# IP Address Change on Restore Test
# ============================================================================

TEST_NETWORK="ip-test-net"
SOURCE_IP="172.30.0.100"
RESTORE_IP="172.30.0.200"

echo "========================================================================"
echo "IP Address Change on Restore Test"
echo "========================================================================"
echo ""

# Clean and setup
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || true

# Create network (clean first)
podman network rm "$TEST_NETWORK" 2>/dev/null || true
podman network create "$TEST_NETWORK" --subnet 172.30.0.0/24 >/dev/null
register_network "$TEST_NETWORK"

echo "✓ Test network created (172.30.0.0/24)"
echo ""

# ============================================================================
# Test: Backup from IP .100, Restore to IP .200
# ============================================================================
run_test

echo "STEP 1: Create backup from IP $SOURCE_IP"
echo "------------------------------------------------------------------------"

podman run -d --name ip-test-source \
    --network "$TEST_NETWORK" --ip "$SOURCE_IP" \
    -v "$BACKUP_VOLUME":/backup \
    -e CASSANDRA_CLUSTER_NAME=test-ip-change \
    -e CASSANDRA_DC=dc1 \
    -e CASSANDRA_HEAP_SIZE=4G \
    -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
    localhost/axondb-timeseries:backup-complete >/dev/null

register_container "ip-test-source"

if ! wait_for_cassandra_ready "ip-test-source"; then
    fail_test "IP change test" "Source container failed to start"
    exit 1
fi

# Verify source IP
ACTUAL_SOURCE_IP=$(podman exec ip-test-source nodetool status | grep "^UN" | awk '{print $2}')
echo "✓ Source container IP: $ACTUAL_SOURCE_IP"

if [ "$ACTUAL_SOURCE_IP" != "$SOURCE_IP" ]; then
    fail_test "IP change test" "Source IP mismatch (expected $SOURCE_IP, got $ACTUAL_SOURCE_IP)"
    exit 1
fi

# Create test data
echo "Creating test data..."
podman exec ip-test-source cqlsh -u cassandra -p cassandra -e "CREATE KEYSPACE ip_test WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 1};" >/dev/null 2>&1
podman exec ip-test-source cqlsh -u cassandra -p cassandra -e "CREATE TABLE ip_test.data (id INT PRIMARY KEY, source_ip TEXT);" >/dev/null 2>&1
podman exec ip-test-source cqlsh -u cassandra -p cassandra -e "INSERT INTO ip_test.data (id, source_ip) VALUES (1, '$ACTUAL_SOURCE_IP');" >/dev/null 2>&1
echo "✓ Test data created"

# Create backup
echo "Creating backup..."
podman exec ip-test-source /usr/local/bin/cassandra-backup.sh >/dev/null 2>&1

BACKUP_NAME=$(ls -1dt "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | head -1 | xargs basename | sed 's/^data_//')
if [ -z "$BACKUP_NAME" ]; then
    fail_test "IP change test" "Backup not created"
    exit 1
fi
echo "✓ Backup created: $BACKUP_NAME"

# Destroy source
podman rm -f ip-test-source >/dev/null 2>&1
echo "✓ Source container destroyed"
echo ""

echo "STEP 2: Restore to DIFFERENT IP $RESTORE_IP"
echo "------------------------------------------------------------------------"

podman run -d --name ip-test-restore \
    --network "$TEST_NETWORK" --ip "$RESTORE_IP" \
    -v "$BACKUP_VOLUME":/backup \
    -e CASSANDRA_CLUSTER_NAME=test-ip-change \
    -e CASSANDRA_DC=dc1 \
    -e CASSANDRA_HEAP_SIZE=4G \
    -e RESTORE_FROM_BACKUP="$BACKUP_NAME" \
    localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "ip-test-restore"

if ! wait_for_cassandra_ready "ip-test-restore"; then
    fail_test "IP change test" "Restore container failed to start"
    podman logs ip-test-restore 2>&1 | tail -30
    exit 1
fi

# Verify restore IP
ACTUAL_RESTORE_IP=$(podman exec ip-test-restore nodetool status | grep "^UN" | awk '{print $2}')
echo "✓ Restore container IP: $ACTUAL_RESTORE_IP"

if [ "$ACTUAL_RESTORE_IP" != "$RESTORE_IP" ]; then
    fail_test "IP change test" "Restore IP mismatch (expected $RESTORE_IP, got $ACTUAL_RESTORE_IP)"
    exit 1
fi

echo ""
echo "STEP 3: Verify IP Change Handled"
echo "------------------------------------------------------------------------"

# CRITICAL: IPs must be different
if [ "$ACTUAL_SOURCE_IP" = "$ACTUAL_RESTORE_IP" ]; then
    fail_test "IP change test" "IPs are same ($ACTUAL_SOURCE_IP) - test setup error!"
    exit 1
fi

echo "✓ IP CHANGED: $ACTUAL_SOURCE_IP → $ACTUAL_RESTORE_IP"

# Verify Cassandra functional
if ! podman exec ip-test-restore cqlsh -u cassandra -p cassandra -e "SELECT cluster_name FROM system.local;" >/dev/null 2>&1; then
    fail_test "IP change test" "CQL queries failed after IP change"
    exit 1
fi
echo "✓ CQL queries work"

# Verify data accessible
RESTORED_DATA=$(podman exec ip-test-restore cqlsh -u cassandra -p cassandra -e "SELECT source_ip FROM ip_test.data WHERE id=1;" 2>&1 | grep -v Warning | grep -A2 "source_ip" | tail -1 | tr -d ' ')
if [ "$RESTORED_DATA" = "$ACTUAL_SOURCE_IP" ]; then
    echo "✓ Data accessible (original source IP in data: $RESTORED_DATA)"
else
    fail_test "IP change test" "Data corrupted or inaccessible"
    exit 1
fi

# Verify nodetool shows new IP
if podman exec ip-test-restore nodetool status | grep "^UN.*$ACTUAL_RESTORE_IP" >/dev/null; then
    echo "✓ Nodetool status shows new IP ($ACTUAL_RESTORE_IP)"
else
    fail_test "IP change test" "Nodetool doesn't show correct IP"
    exit 1
fi

echo ""
pass_test "IP address change (${ACTUAL_SOURCE_IP} → ${ACTUAL_RESTORE_IP}): Cassandra handles correctly"

print_test_summary
