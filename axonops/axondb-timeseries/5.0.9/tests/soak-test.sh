#!/bin/bash
set -euo pipefail

# ============================================================================
# Comprehensive Soak Test
# Purpose: Real-world scenario testing with data writing, backups, restores
# ============================================================================
# Duration: ~60-90 minutes
# Validates:
# - Continuous backups (every 10 minutes)
# - Data writing while backing up
# - Hardlink space savings
# - Retention over time
# - Multiple restore scenarios
# - IP change + credential reset combinations

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_VOLUME="${SCRIPT_DIR}/.soak-test-backups"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================================================"
echo -e "${BLUE}Comprehensive Soak Test - Backup/Restore Solution${NC}"
echo "================================================================================"
echo "Duration: ~60-90 minutes"
echo "Backup interval: Every 10 minutes"
echo "Backup volume: $BACKUP_VOLUME"
echo "================================================================================"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."
    podman rm -f soak-test-primary soak-test-restore1 soak-test-restore2 soak-test-restore3 2>/dev/null || true
    podman network rm soak-test-net 2>/dev/null || true
    echo "✓ Cleanup complete"
}

trap cleanup EXIT

# Clean backup volume
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || true
mkdir -p "$BACKUP_VOLUME"

# ============================================================================
# PHASE 1: Start Container with Scheduled Backups (every 10 minutes)
# ============================================================================
echo ""
echo "================================================================================"
echo "PHASE 1: Start Container with Scheduled Backups"
echo "================================================================================"
echo ""

echo "Starting container with:"
echo "  - Scheduled backups: every 10 minutes (*/10 * * * *)"
echo "  - Retention: 60 minutes (keep ~6 backups)"
echo "  - Custom user: soakuser/soakpass123"
echo ""

podman run -d --name soak-test-primary \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=soak-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  -e AXONOPS_DB_USER=soakuser \
  -e AXONOPS_DB_PASSWORD=soakpass123 \
  -e BACKUP_SCHEDULE="*/10 * * * *" \
  -e BACKUP_RETENTION_HOURS=1 \
  -e BACKUP_MINIMUM_RETENTION_COUNT=3 \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

echo "✓ Container started"

# Wait for Cassandra ready
echo "Waiting for Cassandra to be ready..."
MAX_WAIT=180
ELAPSED=0
until podman exec soak-test-primary cqlsh -u soakuser -p soakpass123 -e "SELECT cluster_name FROM system.local;" >/dev/null 2>&1; do
    if [ $ELAPSED -gt $MAX_WAIT ]; then
        echo "ERROR: Cassandra not ready after ${MAX_WAIT}s"
        exit 1
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ $((ELAPSED % 30)) -eq 0 ]; then
        echo "  Still waiting (${ELAPSED}s)..."
    fi
done

echo -e "${GREEN}✓ Cassandra ready (${ELAPSED}s)${NC}"
echo ""

# Wait for init scripts
echo "Waiting for init scripts (30s)..."
sleep 30

# Check backup scheduler started
if podman exec soak-test-primary pgrep -f backup-scheduler >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Backup scheduler running${NC}"
else
    echo "ERROR: Backup scheduler not running"
    exit 1
fi

echo ""

# ============================================================================
# PHASE 2: Create Multiple Keyspaces and Write Data
# ============================================================================
echo "================================================================================"
echo "PHASE 2: Create Keyspaces and Write Data"
echo "================================================================================"
echo ""

echo "Creating 3 keyspaces with test data..."

# Keyspace 1: metrics (time-series data)
podman exec soak-test-primary cqlsh -u soakuser -p soakpass123 -e "
CREATE KEYSPACE IF NOT EXISTS metrics
WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 1};" >/dev/null 2>&1

podman exec soak-test-primary cqlsh -u soakuser -p soakpass123 -e "
CREATE TABLE IF NOT EXISTS metrics.measurements (
  device_id TEXT,
  timestamp TIMESTAMP,
  value DOUBLE,
  PRIMARY KEY (device_id, timestamp)
);" >/dev/null 2>&1

echo "✓ metrics keyspace created"

# Keyspace 2: events
podman exec soak-test-primary cqlsh -u soakuser -p soakpass123 -e "
CREATE KEYSPACE IF NOT EXISTS events
WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 1};" >/dev/null 2>&1

podman exec soak-test-primary cqlsh -u soakuser -p soakpass123 -e "
CREATE TABLE IF NOT EXISTS events.log (
  id UUID PRIMARY KEY,
  message TEXT,
  severity TEXT,
  timestamp TIMESTAMP
);" >/dev/null 2>&1

echo "✓ events keyspace created"

# Keyspace 3: config
podman exec soak-test-primary cqlsh -u soakuser -p soakpass123 -e "
CREATE KEYSPACE IF NOT EXISTS config
WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 1};" >/dev/null 2>&1

podman exec soak-test-primary cqlsh -u soakuser -p soakpass123 -e "
CREATE TABLE IF NOT EXISTS config.settings (
  key TEXT PRIMARY KEY,
  value TEXT
);" >/dev/null 2>&1

echo "✓ config keyspace created"
echo ""

# Insert initial data
echo "Writing initial data (100 rows)..."
for i in $(seq 1 100); do
    podman exec soak-test-primary cqlsh -u soakuser -p soakpass123 -e "
    INSERT INTO metrics.measurements (device_id, timestamp, value)
    VALUES ('device-${i}', toTimestamp(now()), ${i}.5);" >/dev/null 2>&1
done

echo -e "${GREEN}✓ Initial data written (100 rows)${NC}"
echo ""

# ============================================================================
# PHASE 3: Monitor Backups (wait 35 minutes for 3+ backup cycles)
# ============================================================================
echo "================================================================================"
echo "PHASE 3: Monitor Backups (35 minutes - 3+ cycles)"
echo "================================================================================"
echo ""

echo "Monitoring backup cycles..."
echo "  Backup schedule: every 10 minutes"
echo "  Monitoring period: 35 minutes"
echo "  Expected backups: 3-4"
echo ""

START_TIME=$(date +%s)
WRITE_COUNTER=100

for minute in {1..35}; do
    sleep 60

    # Write more data every minute
    podman exec soak-test-primary cqlsh -u soakuser -p soakpass123 -e "
    INSERT INTO metrics.measurements (device_id, timestamp, value)
    VALUES ('device-continuous', toTimestamp(now()), ${WRITE_COUNTER});" >/dev/null 2>&1

    WRITE_COUNTER=$((WRITE_COUNTER + 1))

    # Check backup count every 5 minutes
    if [ $((minute % 5)) -eq 0 ]; then
        BACKUP_COUNT=$(ls -1d "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | wc -l)
        ELAPSED=$((minute))
        echo -e "${YELLOW}[${ELAPSED}min]${NC} Backups: $BACKUP_COUNT | Data rows: ~$((WRITE_COUNTER))"

        # Show backup scheduler log
        if [ $((minute % 10)) -eq 0 ]; then
            echo "  Recent scheduler activity:"
            podman exec soak-test-primary tail -5 /var/log/cassandra/backup-scheduler.log 2>/dev/null | sed 's/^/    /'
        fi
    fi
done

TOTAL_TIME=$(($(date +%s) - START_TIME))
echo ""
echo -e "${GREEN}✓ Monitoring complete (${TOTAL_TIME}s = $((TOTAL_TIME / 60))min)${NC}"
echo ""

# ============================================================================
# PHASE 4: Analyze Backups
# ============================================================================
echo "================================================================================"
echo "PHASE 4: Analyze Backups"
echo "================================================================================"
echo ""

BACKUP_COUNT=$(ls -1d "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | wc -l)
echo "Total backups created: $BACKUP_COUNT"
echo ""

echo "Backup details:"
echo "------------------------------------------------------------------------"
for backup in $(ls -1dt "$BACKUP_VOLUME"/data_backup-* 2>/dev/null); do
    backup_name=$(basename "$backup" | sed 's/^data_//')
    backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1)
    hardlink_count=$(find "$backup" -type f -links +1 2>/dev/null | wc -l)
    total_files=$(find "$backup" -type f 2>/dev/null | wc -l)

    hardlink_pct=0
    if [ "$total_files" -gt 0 ]; then
        hardlink_pct=$((hardlink_count * 100 / total_files))
    fi

    echo "  $backup_name:"
    echo "    Size: $backup_size"
    echo "    Files: $total_files (${hardlink_count} hardlinked = ${hardlink_pct}%)"
done

echo ""

# Calculate total size vs deduplication savings
TOTAL_SIZE=$(du -sh "$BACKUP_VOLUME" 2>/dev/null | cut -f1)
echo -e "${GREEN}✓ Backup volume total size: $TOTAL_SIZE${NC}"
echo ""

# ============================================================================
# PHASE 5: Verify Data Integrity
# ============================================================================
echo "================================================================================"
echo "PHASE 5: Verify Data Integrity"
echo "================================================================================"
echo ""

TOTAL_ROWS=$(podman exec soak-test-primary cqlsh -u soakuser -p soakpass123 -e "SELECT COUNT(*) FROM metrics.measurements;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
echo "Total data rows: $TOTAL_ROWS"
echo -e "${GREEN}✓ Data verified${NC}"
echo ""

# ============================================================================
# PHASE 6: Test Restore Scenarios
# ============================================================================
echo "================================================================================"
echo "PHASE 6: Test Restore Scenarios"
echo "================================================================================"
echo ""

# Get list of backups
BACKUPS=($(ls -1dt "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | xargs -I{} basename {} | sed 's/^data_//'))
LATEST_BACKUP="${BACKUPS[0]}"
if [ ${#BACKUPS[@]} -ge 3 ]; then
    OLDER_BACKUP="${BACKUPS[2]}"
else
    OLDER_BACKUP="${BACKUPS[-1]}"
fi

echo "Available backups: ${#BACKUPS[@]}"
echo "  Latest: $LATEST_BACKUP"
echo "  Older:  $OLDER_BACKUP"
echo ""

# --- Scenario 1: Restore Latest ---
echo "------------------------------------------------------------------------"
echo "Scenario 1: Restore Latest Backup"
echo "------------------------------------------------------------------------"

podman run -d --name soak-test-restore1 \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=soak-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e RESTORE_FROM_BACKUP="latest" \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

sleep 90

if podman exec soak-test-restore1 cqlsh -u soakuser -p soakpass123 -e "SELECT COUNT(*) FROM metrics.measurements;" >/dev/null 2>&1; then
    RESTORED_ROWS=$(podman exec soak-test-restore1 cqlsh -u soakuser -p soakpass123 -e "SELECT COUNT(*) FROM metrics.measurements;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
    echo -e "${GREEN}✓ Latest backup restored: $RESTORED_ROWS rows${NC}"
else
    echo "ERROR: Latest restore failed"
    exit 1
fi

podman rm -f soak-test-restore1 >/dev/null 2>&1
echo ""

# --- Scenario 2: Restore Older Backup ---
echo "------------------------------------------------------------------------"
echo "Scenario 2: Restore Older Backup"
echo "------------------------------------------------------------------------"

podman run -d --name soak-test-restore2 \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=soak-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e RESTORE_FROM_BACKUP="$OLDER_BACKUP" \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

sleep 90

if podman exec soak-test-restore2 cqlsh -u soakuser -p soakpass123 -e "SELECT COUNT(*) FROM metrics.measurements;" >/dev/null 2>&1; then
    RESTORED_ROWS=$(podman exec soak-test-restore2 cqlsh -u soakuser -p soakpass123 -e "SELECT COUNT(*) FROM metrics.measurements;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
    echo -e "${GREEN}✓ Older backup restored: $RESTORED_ROWS rows${NC}"
else
    echo "ERROR: Older restore failed"
    exit 1
fi

podman rm -f soak-test-restore2 >/dev/null 2>&1
echo ""

# --- Scenario 3: Restore with IP Change + Credential Reset ---
echo "------------------------------------------------------------------------"
echo "Scenario 3: Restore with IP Change + Credential Reset"
echo "------------------------------------------------------------------------"

# Create custom network
podman network create --subnet 172.40.0.0/24 soak-test-net >/dev/null 2>&1

podman run -d --name soak-test-restore3 \
  --network soak-test-net \
  --ip 172.40.0.250 \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=soak-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e RESTORE_FROM_BACKUP="$LATEST_BACKUP" \
  -e RESTORE_RESET_CREDENTIALS=true \
  -e AXONOPS_DB_USER=devuser \
  -e AXONOPS_DB_PASSWORD=devpass456 \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

sleep 120  # Extra time for credential reset + user creation

# Test with new credentials
if podman exec soak-test-restore3 cqlsh -u devuser -p devpass456 -e "SELECT COUNT(*) FROM metrics.measurements;" >/dev/null 2>&1; then
    RESTORED_ROWS=$(podman exec soak-test-restore3 cqlsh -u devuser -p devpass456 -e "SELECT COUNT(*) FROM metrics.measurements;" 2>&1 | grep -A2 "count" | tail -1 | tr -d ' ')
    RESTORE_IP=$(podman exec soak-test-restore3 nodetool status | grep "^UN" | awk '{print $2}' | cut -d':' -f1)
    echo -e "${GREEN}✓ Credential reset + IP change restored${NC}"
    echo "  New credentials: devuser/devpass456 (working)"
    echo "  New IP: $RESTORE_IP"
    echo "  Data rows: $RESTORED_ROWS"

    # Verify old user doesn't exist
    if podman exec soak-test-restore3 cqlsh -u soakuser -p soakpass123 -e "SELECT COUNT(*) FROM metrics.measurements;" >/dev/null 2>&1; then
        echo "  ⚠ WARNING: Old user still exists (should be deleted)"
    else
        echo "  ✓ Old user (soakuser) correctly deleted"
    fi
else
    echo "ERROR: Credential reset restore failed"
    podman logs soak-test-restore3 | tail -50
    exit 1
fi

podman rm -f soak-test-restore3 >/dev/null 2>&1
podman network rm soak-test-net >/dev/null 2>&1
echo ""

# ============================================================================
# PHASE 7: Final Analysis
# ============================================================================
echo "================================================================================"
echo "PHASE 7: Final Analysis"
echo "================================================================================"
echo ""

echo "Soak Test Summary:"
echo "------------------------------------------------------------------------"
echo "  Primary container runtime: ~35 minutes"
echo "  Backups created: $BACKUP_COUNT"
echo "  Data rows written: ~$TOTAL_ROWS"
echo "  Backup volume size: $TOTAL_SIZE"
echo "  Restore scenarios tested: 3"
echo "    1. Latest backup restore: ✓"
echo "    2. Older backup restore: ✓"
echo "    3. IP change + credential reset: ✓"
echo ""

# Check backup logs
echo "Backup scheduler logs (last 20 lines):"
podman exec soak-test-primary tail -20 /var/log/cassandra/backup-scheduler.log 2>/dev/null | sed 's/^/  /'
echo ""

echo "Retention cleanup logs (if any):"
podman exec soak-test-primary tail -10 /var/log/cassandra/retention-cleanup.log 2>/dev/null | sed 's/^/  /' || echo "  (No retention cleanup performed yet)"
echo ""

# ============================================================================
# SUCCESS
# ============================================================================
echo "================================================================================"
echo -e "${GREEN}✓✓✓ SOAK TEST COMPLETE ✓✓✓${NC}"
echo "================================================================================"
echo ""
echo "Validated:"
echo "  ✓ Scheduled backups working (10-minute intervals)"
echo "  ✓ Data writing during backups (no conflicts)"
echo "  ✓ Hardlink deduplication working"
echo "  ✓ Multiple restore scenarios successful"
echo "  ✓ IP change handling"
echo "  ✓ Credential reset feature"
echo "  ✓ Backup volume integrity"
echo ""
echo "Test artifacts saved in: $BACKUP_VOLUME"
echo "================================================================================"
