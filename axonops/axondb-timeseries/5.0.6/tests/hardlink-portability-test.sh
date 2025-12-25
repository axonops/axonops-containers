#!/bin/bash
set -e

# ============================================================================
# Hardlink Portability Test
# Purpose: Verify hardlinks behavior when copying backups to different location
# ============================================================================
# Key Question: Do hardlinks survive rsync to remote/different directory?
# Answer: NO - rsync copies actual file data (this is GOOD for portability!)

BACKUP_VOLUME=~/axondb-backup-testing/backup-volume
REMOTE_DIR=~/axondb-backup-testing/remote-backup-copy
TEST_RESULTS="hardlink-portability-results.txt"

echo "========================================================================"
echo "Hardlink Portability Test"
echo "========================================================================"
echo ""
echo "Results: $TEST_RESULTS"
echo ""

# Initialize results
echo "Hardlink Portability Test Results" > "$TEST_RESULTS"
echo "==================================" >> "$TEST_RESULTS"
echo "Date: $(date)" >> "$TEST_RESULTS"
echo "" >> "$TEST_RESULTS"

# Clean previous test data
sudo rm -rf "$REMOTE_DIR" 2>/dev/null || true
mkdir -p "$REMOTE_DIR"

echo "Test Scenario:"
echo "1. Create backups with hardlinks (using real Cassandra container)"
echo "2. Verify hardlinks exist in source"
echo "3. Copy to 'remote' location with rsync"
echo "4. Verify hardlinks become independent files (data portability)"
echo ""

# Check if backups exist from previous tests
BACKUP_COUNT=$(find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_backup-*" 2>/dev/null | wc -l)

if [ "$BACKUP_COUNT" -lt 2 ]; then
    echo "ERROR: Need at least 2 backups with hardlinks for this test"
    echo "Run comprehensive tests first to create backups"
    exit 1
fi

# Find 2 backups
BACKUP_1=$(find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_backup-*" -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | cut -d' ' -f2)
BACKUP_2=$(find "$BACKUP_VOLUME" -maxdepth 1 -type d -name "data_backup-*" -printf '%T@ %p\n' 2>/dev/null | sort -n | head -2 | tail -1 | cut -d' ' -f2)

echo "Using backups:"
echo "  Backup 1: $(basename $BACKUP_1)"
echo "  Backup 2: $(basename $BACKUP_2)"
echo ""

# Find a hardlinked file in backup-2
echo "Finding hardlinked files in backup-2..."
HARDLINKED_FILE=$(find "$BACKUP_2" -type f -name "*.db" -links +1 2>/dev/null | head -1)

if [ -z "$HARDLINKED_FILE" ]; then
    echo "ERROR: No hardlinked files found in backup-2"
    echo "This test requires backups created with BACKUP_USE_HARDLINKS=true"
    exit 1
fi

echo "Test file: $HARDLINKED_FILE"
echo ""

# Get source file stats
echo "========================================================================"
echo "SOURCE (Local Backup Volume):"
echo "========================================================================"
SOURCE_INODE=$(stat "$HARDLINKED_FILE" | grep Inode | awk '{print $4}' | tr -d ',')
SOURCE_LINKS=$(stat "$HARDLINKED_FILE" | grep Links | awk '{print $2}')
SOURCE_SIZE=$(stat "$HARDLINKED_FILE" | grep Size | awk '{print $2}')

echo "File: $(basename $HARDLINKED_FILE)"
echo "  Inode: $SOURCE_INODE"
echo "  Links: $SOURCE_LINKS"
echo "  Size:  $SOURCE_SIZE bytes"
echo ""

if [ "$SOURCE_LINKS" -le 1 ]; then
    echo "ERROR: Test file has only 1 link (not hardlinked!)"
    exit 1
fi

echo "✓ File is hardlinked (Links > 1)" | tee -a "$TEST_RESULTS"
echo ""

# Copy backups to 'remote' location with rsync (default behavior, no -H flag)
echo "========================================================================"
echo "COPYING TO 'REMOTE' LOCATION:"
echo "========================================================================"
echo "Using rsync (default, no -H flag to preserve hardlinks)"
echo "Command: rsync -a $BACKUP_VOLUME/ $REMOTE_DIR/"
echo ""

rsync -a "$BACKUP_VOLUME/" "$REMOTE_DIR/" 2>&1 | tail -5

echo ""
echo "✓ Copy completed"
echo ""

# Get remote file stats
RELATIVE_PATH=${HARDLINKED_FILE#$BACKUP_VOLUME/}
REMOTE_FILE="$REMOTE_DIR/$RELATIVE_PATH"

echo "========================================================================"
echo "REMOTE (Copied Location):"
echo "========================================================================"

if [ ! -f "$REMOTE_FILE" ]; then
    echo "ERROR: File not found in remote location"
    exit 1
fi

REMOTE_INODE=$(stat "$REMOTE_FILE" | grep Inode | awk '{print $4}' | tr -d ',')
REMOTE_LINKS=$(stat "$REMOTE_FILE" | grep Links | awk '{print $2}')
REMOTE_SIZE=$(stat "$REMOTE_FILE" | grep Size | awk '{print $2}')

echo "File: $(basename $REMOTE_FILE)"
echo "  Inode: $REMOTE_INODE"
echo "  Links: $REMOTE_LINKS"
echo "  Size:  $REMOTE_SIZE bytes"
echo ""

# Verify results
echo "========================================================================"
echo "ANALYSIS:"
echo "========================================================================"
echo ""

echo "Inode changed: $SOURCE_INODE → $REMOTE_INODE" | tee -a "$TEST_RESULTS"
echo "Links changed: $SOURCE_LINKS → $REMOTE_LINKS" | tee -a "$TEST_RESULTS"
echo "Size same:     $SOURCE_SIZE = $REMOTE_SIZE bytes" | tee -a "$TEST_RESULTS"
echo "" | tee -a "$TEST_RESULTS"

if [ "$SOURCE_INODE" != "$REMOTE_INODE" ]; then
    echo "✓ EXPECTED: Inode changed (different filesystem)" | tee -a "$TEST_RESULTS"
else
    echo "✗ UNEXPECTED: Inode same (still same filesystem?)" | tee -a "$TEST_RESULTS"
fi

if [ "$REMOTE_LINKS" = "1" ]; then
    echo "✓ EXPECTED: Links=1 (hardlinks became independent files)" | tee -a "$TEST_RESULTS"
else
    echo "✗ UNEXPECTED: Links=$REMOTE_LINKS (hardlinks preserved?)" | tee -a "$TEST_RESULTS"
fi

if [ "$SOURCE_SIZE" = "$REMOTE_SIZE" ]; then
    echo "✓ EXPECTED: Size unchanged (actual data copied)" | tee -a "$TEST_RESULTS"
else
    echo "✗ UNEXPECTED: Size changed (data corruption?)" | tee -a "$TEST_RESULTS"
fi

echo "" | tee -a "$TEST_RESULTS"

echo "========================================================================"
echo "CONCLUSION:"
echo "========================================================================"
echo ""
echo "Hardlinks are LOCAL optimization only:" | tee -a "$TEST_RESULTS"
echo "  - Within /backup volume: Space-efficient (hardlinks work)" | tee -a "$TEST_RESULTS"
echo "  - After rsync to remote: Full data copied (hardlinks gone)" | tee -a "$TEST_RESULTS"
echo ""  | tee -a "$TEST_RESULTS"
echo "This is CORRECT behavior:" | tee -a "$TEST_RESULTS"
echo "  ✓ Backups are self-contained after copy" | tee -a "$TEST_RESULTS"
echo "  ✓ Data is portable (not dependent on hardlink chain)" | tee -a "$TEST_RESULTS"
echo "  ✓ No risk of broken links on remote system" | tee -a "$TEST_RESULTS"
echo "" | tee -a "$TEST_RESULTS"

if [ "$REMOTE_LINKS" = "1" ] && [ "$SOURCE_SIZE" = "$REMOTE_SIZE" ]; then
    echo "[0;32m✓ PASS: Hardlink portability verified (hardlinks→independent files, data intact)[0m" | tee -a "$TEST_RESULTS"
    exit 0
else
    echo "[0;31m✗ FAIL: Unexpected behavior[0m" | tee -a "$TEST_RESULTS"
    exit 1
fi
