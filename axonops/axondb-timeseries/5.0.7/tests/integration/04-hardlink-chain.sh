#!/bin/bash
set -euo pipefail

# ============================================================================
# Hardlink Chain Integrity Test
# Purpose: Validate hardlink chain remains intact after deleting oldest backup
# ============================================================================
# Tests:
# - Create 3 backups (chain with hardlinks)
# - Pick file from backup-2 (record inode)
# - Delete backup-1 (oldest)
# - Verify file in backup-2 still exists with same inode

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

trap cleanup_test_resources EXIT


echo "========================================================================"
echo "Hardlink Chain Integrity Test"
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

podman run -d --name hardlink-chain-test \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=chain-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "hardlink-chain-test"

if ! wait_for_cassandra_ready "hardlink-chain-test"; then
    fail_test "Hardlink chain" "Container failed to start"
    exit 1
fi

echo "✓ Container ready"

# ============================================================================
# STEP 2: Create backup chain (3 backups)
# ============================================================================
echo ""
echo "STEP 2: Create backup chain"
echo "------------------------------------------------------------------------"

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
    fail_test "Hardlink chain" "Failed to create backup chain"
    exit 1
fi

echo "  Backup 1 (oldest): $(basename $BACKUP_1)"
echo "  Backup 2 (middle): $(basename $BACKUP_2)"
echo "  Backup 3 (newest): $(basename $BACKUP_3)"

echo "✓ 3 backups created"

# ============================================================================
# STEP 3: Pick hardlinked file from backup-2
# ============================================================================
echo ""
echo "STEP 3: Select test file from backup-2"
echo "------------------------------------------------------------------------"

# Find a .db file in backup-2 that has Links > 1
echo "  Searching for hardlinked .db files in: $BACKUP_2"

# Use a different approach - find any .db file and check its link count
TEST_FILE=""
for file in $(find "$BACKUP_2" -type f -name "*.db" 2>/dev/null | head -20); do
    LINK_COUNT=$(stat -c%h "$file" 2>/dev/null || echo "1")
    if [ "$LINK_COUNT" -gt 1 ]; then
        TEST_FILE="$file"
        break
    fi
done

if [ -z "$TEST_FILE" ]; then
    echo "  ERROR: No hardlinked .db files found"
    echo "  All .db files in backup-2:"
    find "$BACKUP_2" -type f -name "*.db" 2>/dev/null | head -10
    echo "  Checking link counts:"
    for f in $(find "$BACKUP_2" -type f -name "*.db" 2>/dev/null | head -3); do
        echo "  $f: $(stat -c%h "$f" 2>/dev/null || echo "?") links"
    done
    fail_test "Hardlink chain" "No hardlinked files found in backup-2"
    exit 1
fi

# Get inode and link count before deletion
INODE_BEFORE=$(stat "$TEST_FILE" | grep Inode | awk '{print $4}' | tr -d ',')
LINKS_BEFORE=$(stat "$TEST_FILE" | grep Links | awk '{print $2}')

echo "Test file: $(basename $TEST_FILE)"
echo "  Inode: $INODE_BEFORE"
echo "  Links: $LINKS_BEFORE"

echo "✓ Test file selected (hardlinked)"

# ============================================================================
# STEP 4: Delete oldest backup
# ============================================================================
echo ""
echo "STEP 4: Delete oldest backup"
echo "------------------------------------------------------------------------"

echo "Deleting: $(basename $BACKUP_1)"
sudo rm -rf "$BACKUP_1" 2>/dev/null

if [ -d "$BACKUP_1" ]; then
    fail_test "Hardlink chain" "Failed to delete backup-1"
    exit 1
fi

echo "✓ Oldest backup deleted"

# ============================================================================
# STEP 5: Verify file integrity
# ============================================================================
echo ""
echo "STEP 5: Verify file integrity in backup-2"
echo "------------------------------------------------------------------------"

if [ ! -f "$TEST_FILE" ]; then
    fail_test "Hardlink chain" "File no longer exists after deleting backup-1"
    exit 1
fi

INODE_AFTER=$(stat "$TEST_FILE" | grep Inode | awk '{print $4}' | tr -d ',')
LINKS_AFTER=$(stat "$TEST_FILE" | grep Links | awk '{print $2}')

echo "After deletion:"
echo "  Inode: $INODE_AFTER"
echo "  Links: $LINKS_AFTER"

if [ "$INODE_BEFORE" = "$INODE_AFTER" ]; then
    echo "✓ Inode unchanged (data preserved)"
    pass_test "Hardlink chain integrity maintained after deletion"
else
    fail_test "Hardlink chain" "Inode changed (expected $INODE_BEFORE, got $INODE_AFTER)"
    exit 1
fi

# ============================================================================
# SUCCESS
# ============================================================================
echo ""
pass_test "Hardlink chain integrity verified"

print_test_summary
