#!/bin/bash
set -euo pipefail

# ============================================================================
# Full Copy Mode Test
# Purpose: Validate BACKUP_USE_HARDLINKS=false creates independent copies
# ============================================================================
# Tests:
# - Create 2 backups with BACKUP_USE_HARDLINKS=false
# - Verify NO files have Links > 1 (all are independent copies)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

trap cleanup_test_resources EXIT


echo "========================================================================"
echo "Full Copy Mode Test (BACKUP_USE_HARDLINKS=false)"
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

podman run -d --name hardlink-disabled-test \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=hardlink-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "hardlink-disabled-test"

if ! wait_for_cassandra_ready "hardlink-disabled-test"; then
    fail_test "Full copy mode" "Container failed to start"
    exit 1
fi

echo "✓ Container ready"

# ============================================================================
# STEP 2: Create first backup with hardlinks disabled
# ============================================================================
echo ""
echo "STEP 2: Create first backup (full copy)"
echo "------------------------------------------------------------------------"

podman exec hardlink-disabled-test sh -c 'BACKUP_USE_HARDLINKS=false /usr/local/bin/cassandra-backup.sh' >/dev/null 2>&1

BACKUP_1=$(ls -1dt "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | head -1)
if [ -z "$BACKUP_1" ]; then
    fail_test "Full copy mode" "First backup not created"
    exit 1
fi

echo "✓ First backup: $(basename $BACKUP_1)"

sleep 5

# ============================================================================
# STEP 3: Create second backup with hardlinks disabled
# ============================================================================
echo ""
echo "STEP 3: Create second backup (full copy)"
echo "------------------------------------------------------------------------"

podman exec hardlink-disabled-test sh -c 'BACKUP_USE_HARDLINKS=false /usr/local/bin/cassandra-backup.sh' >/dev/null 2>&1

BACKUP_2=$(ls -1dt "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | head -1)
if [ -z "$BACKUP_2" ]; then
    fail_test "Full copy mode" "Second backup not created"
    exit 1
fi

echo "✓ Second backup: $(basename $BACKUP_2)"

# ============================================================================
# STEP 4: Verify NO hardlinks
# ============================================================================
echo ""
echo "STEP 4: Verify no hardlinks (all files independent)"
echo "------------------------------------------------------------------------"

# Check from HOST filesystem (all files should have Links: 1)
HARDLINKED_COUNT=$(find "$BACKUP_2" -type f -links +1 2>/dev/null | wc -l)

echo "Files with Links > 1: $HARDLINKED_COUNT"

if [ "$HARDLINKED_COUNT" -eq 0 ]; then
    echo "✓ No hardlinks found (all files are independent copies)"
    pass_test "Full copy mode verified (BACKUP_USE_HARDLINKS=false)"
else
    fail_test "Full copy mode" "Found $HARDLINKED_COUNT hardlinked files (should be 0)"
    exit 1
fi

# ============================================================================
# SUCCESS
# ============================================================================
echo ""
pass_test "rsync full copy mode with no hardlinks"

print_test_summary
