#!/bin/bash
set -euo pipefail

# ============================================================================
# Environment Variable Integration Tests
# Purpose: Verify env vars trigger expected behavior (not just direct script calls)
# ============================================================================

# Source common test utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

# Trap for cleanup
trap cleanup_test_resources EXIT

TEST_RESULTS="results/integration-env-vars-results.txt"

echo "========================================================================"
echo "Environment Variable Integration Tests"
echo "========================================================================"
echo ""
echo "Results: $TEST_RESULTS"
echo ""

# Initialize results file
mkdir -p "$(dirname "$TEST_RESULTS")"
echo "Environment Variable Integration Test Results" > "$TEST_RESULTS"
echo "==============================================" >> "$TEST_RESULTS"
echo "Date: $(date)" >> "$TEST_RESULTS"
echo "" >> "$TEST_RESULTS"

# Clean environment
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || true

# ============================================================================
# Test 1: BACKUP_SCHEDULE Triggers Scheduler
# ============================================================================
echo "========================================================================"
echo "Test 1: BACKUP_SCHEDULE Triggers Scheduler Daemon"
echo "========================================================================"
echo ""

run_test

podman run -d --name test-schedule \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=test-schedule \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  -e BACKUP_SCHEDULE="*/5 * * * *" \
  -e BACKUP_RETENTION_HOURS=24 \
  localhost/axondb-timeseries:backup-complete >/dev/null

echo "Waiting for container to start and scheduler to initialize..."
sleep 15

# Check if scheduler process is running
if podman exec test-schedule ps aux | grep "backup-scheduler.sh" | grep -v grep >/dev/null; then
    echo "✓ backup-scheduler.sh process running"

    # Check scheduler log
    if podman exec test-schedule test -f /var/log/cassandra/backup-scheduler.log; then
        SCHEDULE_LOG=$(podman exec test-schedule cat /var/log/cassandra/backup-scheduler.log)

        if echo "$SCHEDULE_LOG" | grep "Backup scheduler starting" >/dev/null; then
            echo "✓ Scheduler started successfully"

            if echo "$SCHEDULE_LOG" | grep "Every 5 minutes\|00:05:00" >/dev/null; then
                pass_test "BACKUP_SCHEDULE triggers scheduler with correct interval"
            else
                fail_test "Scheduler interval" "Didn't parse '*/5 * * * *' correctly"
            fi
        else
            fail_test "Scheduler start" "Scheduler log doesn't show startup"
        fi
    else
        fail_test "Scheduler log" "Log file not created"
    fi
else
    fail_test "Scheduler process" "backup-scheduler.sh not running"
fi

podman rm -f test-schedule >/dev/null 2>&1

# ============================================================================
# Test 2: RESTORE_FROM_BACKUP=latest Triggers Restore
# ============================================================================
echo ""
echo "========================================================================"
echo "Test 2: RESTORE_FROM_BACKUP=latest Triggers Restore"
echo "========================================================================"
echo ""

run_test

# Create a backup first
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || true

podman run -d --name test-backup-source \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=test-restore \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  localhost/axondb-timeseries:backup-complete >/dev/null

echo "Creating backup..."
sleep 75

podman exec test-backup-source /usr/local/bin/cassandra-backup.sh >/dev/null 2>&1

BACKUP_NAME=$(ls -1dt "$BACKUP_VOLUME"/data_backup-* 2>/dev/null | head -1 | xargs basename)
echo "Backup created: $BACKUP_NAME"

podman rm -f test-backup-source >/dev/null 2>&1

# Test restore with "latest" keyword
echo "Testing RESTORE_FROM_BACKUP=latest..."

podman run -d --name test-restore-latest \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=test-restore \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e RESTORE_FROM_BACKUP="latest" \
  localhost/axondb-timeseries:backup-complete >/dev/null

sleep 40

# Check if restore ran
if podman exec test-restore-latest test -f /tmp/axonops-restore.done 2>/dev/null; then
    RESTORE_RESULT=$(podman exec test-restore-latest grep "^RESULT=" /tmp/axonops-restore.done | cut -d'=' -f2)

    if [ "$RESTORE_RESULT" = "success" ]; then
        echo "✓ Restore completed with 'latest' keyword"
        pass_test "RESTORE_FROM_BACKUP=latest triggers restore correctly"
    else
        fail_test "Restore with latest" "Restore failed: RESULT=$RESTORE_RESULT"
    fi
else
    fail_test "Restore with latest" "Restore semaphore not found"
fi

podman rm -f test-restore-latest >/dev/null 2>&1

# ============================================================================
# Test 3: Missing BACKUP_RETENTION_HOURS Causes Exit
# ============================================================================
echo ""
echo "========================================================================"
echo "Test 3: Missing BACKUP_RETENTION_HOURS Causes Container Exit"
echo "========================================================================"
echo ""

run_test

# Start container with schedule but no retention (should exit)
podman run -d --name test-no-retention \
  -e CASSANDRA_CLUSTER_NAME=test-exit \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e BACKUP_SCHEDULE="*/30 * * * *" \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1 || true

sleep 10

# Check if container exited
STATUS=$(podman inspect test-no-retention --format '{{.State.Status}}' 2>/dev/null || echo "not_found")

if [ "$STATUS" = "exited" ]; then
    # Check exit logs
    EXIT_LOGS=$(podman logs test-no-retention 2>&1)

    if echo "$EXIT_LOGS" | grep "BACKUP_SCHEDULE provided but BACKUP_RETENTION_HOURS not set" >/dev/null; then
        echo "✓ Container exited with correct error message"
        pass_test "Missing BACKUP_RETENTION_HOURS causes container exit (prevents misconfiguration)"
    else
        fail_test "Exit error message" "Didn't show expected error"
    fi
else
    fail_test "Container exit" "Container didn't exit (status: $STATUS)"
fi

podman rm -f test-no-retention >/dev/null 2>&1

# ============================================================================
# Summary
# ============================================================================
print_test_summary
