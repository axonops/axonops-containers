#!/bin/bash
set -euo pipefail

# ============================================================================
# Simple Startup Smoke Test
# Purpose: Validate basic container startup with init and healthchecks
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

trap cleanup_test_resources EXIT

echo "========================================================================"
echo "Simple Startup Smoke Test"
echo "========================================================================"
echo ""

# Clean backup volume
sudo rm -rf "$BACKUP_VOLUME"/* 2>/dev/null || true

run_test

# ============================================================================
# STEP 1: Start container with init enabled + custom user
# ============================================================================
echo "STEP 1: Start container with init enabled and custom user"
echo "------------------------------------------------------------------------"

podman run -d --name simple-smoke-test \
  -v "$BACKUP_VOLUME":/backup \
  -e CASSANDRA_CLUSTER_NAME=smoke-test \
  -e CASSANDRA_DC=dc1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  -e AXONOPS_DB_USER=testuser \
  -e AXONOPS_DB_PASSWORD=testpass123 \
  localhost/axondb-timeseries:backup-complete >/dev/null 2>&1

register_container "simple-smoke-test"

echo "✓ Container started"

# ============================================================================
# STEP 2: Wait for Cassandra to be ready
# ============================================================================
echo ""
echo "STEP 2: Wait for Cassandra startup"
echo "------------------------------------------------------------------------"

if ! wait_for_cassandra_ready "simple-smoke-test" "testuser" "testpass123" 300; then
    fail_test "Simple startup" "Cassandra failed to start within 5 minutes"
    podman logs simple-smoke-test | tail -50
    exit 1
fi

echo "✓ Cassandra ready"

# ============================================================================
# STEP 3: Wait for init scripts to complete
# ============================================================================
echo ""
echo "STEP 3: Wait for init scripts to complete"
echo "------------------------------------------------------------------------"

echo "Waiting for init (30s)..."
sleep 30

# Check init semaphores
if podman exec simple-smoke-test test -f /var/lib/cassandra/.axonops/init-system-keyspaces.done; then
    KEYSPACE_RESULT=$(podman exec simple-smoke-test grep "^RESULT=" /var/lib/cassandra/.axonops/init-system-keyspaces.done | cut -d'=' -f2)
    echo "  System keyspaces init: $KEYSPACE_RESULT"

    if [ "$KEYSPACE_RESULT" != "success" ]; then
        fail_test "Simple startup" "System keyspace init failed: $KEYSPACE_RESULT"
        exit 1
    fi
else
    fail_test "Simple startup" "Init semaphore not found"
    exit 1
fi

if podman exec simple-smoke-test test -f /var/lib/cassandra/.axonops/init-db-user.done; then
    USER_RESULT=$(podman exec simple-smoke-test grep "^RESULT=" /var/lib/cassandra/.axonops/init-db-user.done | cut -d'=' -f2)
    echo "  Database user init: $USER_RESULT"

    if [ "$USER_RESULT" != "success" ]; then
        fail_test "Simple startup" "Database user init failed: $USER_RESULT"
        exit 1
    fi
else
    fail_test "Simple startup" "User init semaphore not found"
    exit 1
fi

echo "✓ Init scripts completed successfully"

# ============================================================================
# STEP 4: Run healthcheck scripts
# ============================================================================
echo ""
echo "STEP 4: Validate healthcheck scripts"
echo "------------------------------------------------------------------------"

# Test startup healthcheck
if podman exec simple-smoke-test /usr/local/bin/healthcheck.sh startup >/dev/null 2>&1; then
    echo "✓ Startup healthcheck passed"
else
    fail_test "Simple startup" "Startup healthcheck failed"
    podman exec simple-smoke-test /usr/local/bin/healthcheck.sh startup 2>&1 || true
    exit 1
fi

# Test liveness healthcheck
if podman exec simple-smoke-test /usr/local/bin/healthcheck.sh liveness >/dev/null 2>&1; then
    echo "✓ Liveness healthcheck passed"
else
    fail_test "Simple startup" "Liveness healthcheck failed"
    exit 1
fi

# Test readiness healthcheck
if podman exec simple-smoke-test /usr/local/bin/healthcheck.sh readiness >/dev/null 2>&1; then
    echo "✓ Readiness healthcheck passed"
else
    fail_test "Simple startup" "Readiness healthcheck failed"
    exit 1
fi

# ============================================================================
# STEP 5: Verify custom credentials work
# ============================================================================
echo ""
echo "STEP 5: Verify custom credentials work"
echo "------------------------------------------------------------------------"

if podman exec simple-smoke-test cqlsh -u testuser -p testpass123 -e "SELECT cluster_name FROM system.local;" >/dev/null 2>&1; then
    echo "✓ Custom credentials work (testuser/testpass123)"
else
    fail_test "Simple startup" "Custom credentials failed"
    exit 1
fi

# Verify default cassandra user is disabled
if podman exec simple-smoke-test cqlsh -u cassandra -p cassandra -e "SELECT cluster_name FROM system.local;" >/dev/null 2>&1; then
    fail_test "Simple startup" "Default cassandra user still enabled (should be disabled)"
    exit 1
else
    echo "✓ Default cassandra user disabled (as expected)"
fi

# ============================================================================
# SUCCESS
# ============================================================================
echo ""
pass_test "Simple startup smoke test (init + healthchecks + custom credentials)"

print_test_summary
