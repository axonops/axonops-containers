#!/bin/bash
set -euo pipefail

# ============================================================================
# Hardlink Portability Test
# Purpose: Verify hardlinks behavior when copying backups to different location
# ============================================================================
# Key Question: Do hardlinks survive rsync to remote/different directory?
# Answer: NO - rsync copies actual file data (this is GOOD for portability!)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

trap cleanup_test_resources EXIT

REMOTE_DIR="${TEST_ROOT}/.test-remote-copy"

echo "========================================================================"
echo "Hardlink Portability Test"
echo "========================================================================"
echo ""

# Clean volumes
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || true
sudo rm -rf "$REMOTE_DIR" 2>/dev/null || true
mkdir -p "$REMOTE_DIR"

run_test

# ============================================================================
# STEP 1: Create container
# ============================================================================
echo "STEP 1: Create test container"
echo "------------------------------------------------------------------------"

podman run -d --name hardlink-portability-test \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=portability-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "hardlink-portability-test"

if ! wait_for_cassandra_ready "hardlink-portability-test"; then
    fail_test "Hardlink portability" "Container failed to start"
    exit 1
fi

echo "✓ Container ready"

# ============================================================================
# STEP 2: Create 2 backups with hardlinks
# ============================================================================
echo ""
echo "STEP 2: Create 2 backups with hardlinks"
echo "------------------------------------------------------------------------"

for i in {1..2}; do
    podman exec hardlink-portability-test /usr/local/bin/cassandra-backup.sh >/dev/null 2>&1
    echo "  Backup $i created"
    sleep 5
done

BACKUP_1=$(find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_backup-*" -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | cut -d' ' -f2)
BACKUP_2=$(find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_backup-*" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2)

echo "✓ 2 backups created"
echo "  Backup 1: $(basename $BACKUP_1)"
echo "  Backup 2: $(basename $BACKUP_2)"

# ============================================================================
# STEP 3: Find hardlinked file in backup-2
# ============================================================================
echo ""
echo "STEP 3: Find hardlinked file in backup-2"
echo "------------------------------------------------------------------------"

# Find a .db file with Links > 1
HARDLINKED_FILE=""
for file in $(find "$BACKUP_2" -type f -name "*.db" 2>/dev/null | head -20); do
    LINK_COUNT=$(stat -c%h "$file" 2>/dev/null || echo "1")
    if [ "$LINK_COUNT" -gt 1 ]; then
        HARDLINKED_FILE="$file"
        break
    fi
done

if [ -z "$HARDLINKED_FILE" ]; then
    fail_test "Hardlink portability" "No hardlinked files found in backup-2"
    exit 1
fi

SOURCE_INODE=$(stat -c%i "$HARDLINKED_FILE")
SOURCE_LINKS=$(stat -c%h "$HARDLINKED_FILE")
SOURCE_SIZE=$(stat -c%s "$HARDLINKED_FILE")

echo "Test file: $(basename $HARDLINKED_FILE)"
echo "  Inode: $SOURCE_INODE"
echo "  Links: $SOURCE_LINKS"
echo "  Size:  $SOURCE_SIZE bytes"
echo "✓ File is hardlinked (Links > 1)"

# ============================================================================
# STEP 4: Copy to remote location with rsync
# ============================================================================
echo ""
echo "STEP 4: Copy backups to 'remote' location with rsync"
echo "------------------------------------------------------------------------"
echo "Command: rsync -a (default, no -H to preserve hardlinks)"

rsync -a "$BACKUP_VOLUME/" "$REMOTE_DIR/" >/dev/null 2>&1

echo "✓ Copy completed"

# ============================================================================
# STEP 5: Verify hardlinks became independent files
# ============================================================================
echo ""
echo "STEP 5: Verify hardlinks became independent files"
echo "------------------------------------------------------------------------"

RELATIVE_PATH=${HARDLINKED_FILE#$BACKUP_VOLUME/}
REMOTE_FILE="$REMOTE_DIR/$RELATIVE_PATH"

if [ ! -f "$REMOTE_FILE" ]; then
    fail_test "Hardlink portability" "File not found in remote location"
    exit 1
fi

REMOTE_INODE=$(stat -c%i "$REMOTE_FILE")
REMOTE_LINKS=$(stat -c%h "$REMOTE_FILE")
REMOTE_SIZE=$(stat -c%s "$REMOTE_FILE")

echo "Remote file: $(basename $REMOTE_FILE)"
echo "  Inode: $REMOTE_INODE (was $SOURCE_INODE)"
echo "  Links: $REMOTE_LINKS (was $SOURCE_LINKS)"
echo "  Size:  $REMOTE_SIZE bytes (was $SOURCE_SIZE)"

# ============================================================================
# STEP 6: Verify portability
# ============================================================================
echo ""
echo "STEP 6: Verify portability"
echo "------------------------------------------------------------------------"

if [ "$REMOTE_LINKS" -eq 1 ]; then
    echo "✓ Hardlinks became independent files (Links: $SOURCE_LINKS → 1)"
else
    fail_test "Hardlink portability" "Hardlinks still exist (Links: $REMOTE_LINKS)"
    exit 1
fi

if [ "$SOURCE_SIZE" -eq "$REMOTE_SIZE" ]; then
    echo "✓ Data size unchanged (actual data copied)"
else
    fail_test "Hardlink portability" "Data size changed (corruption?)"
    exit 1
fi

echo ""
echo "Conclusion:"
echo "  - Hardlinks are local optimization only"
echo "  - After rsync to remote: Full data copied, hardlinks gone"
echo "  - Backups are self-contained and portable ✓"

# ============================================================================
# SUCCESS
# ============================================================================
echo ""
pass_test "Hardlink portability verified (hardlinks→independent files, data intact)"

print_test_summary

# Cleanup remote directory
sudo rm -rf "$REMOTE_DIR" 2>/dev/null || true
