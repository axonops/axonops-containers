#!/bin/bash
set -e

# AxonDB Time-Series Container Testing Script
# Tests all environment variable combinations

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_FILE="${TEST_DIR}/test-results.txt"

echo "AxonDB Time-Series Container Test Suite"
echo "========================================"
echo ""
echo "Test results will be saved to: ${RESULTS_FILE}"
echo ""

# Clean up function
cleanup() {
    local compose_file="$1"
    echo "  Cleaning up..."
    podman-compose -f "$compose_file" down -v 2>/dev/null || true
    sleep 2
}

# Function to wait for container to be ready (using startup healthcheck)
wait_for_healthy() {
    local container_name="$1"
    local max_wait=300  # 5 minutes
    local elapsed=0

    echo "  Waiting for container to be ready (using startup healthcheck)..."

    while [ $elapsed -lt $max_wait ]; do
        # Check if container is still running
        if ! podman inspect "$container_name" --format='{{.State.Status}}' 2>/dev/null | grep -q "running"; then
            echo "  ✗ Container is not running!"
            return 1
        fi

        # Use our startup healthcheck script
        if podman exec "$container_name" /usr/local/bin/healthcheck.sh startup 2>/dev/null; then
            echo "  ✓ Container startup healthcheck passed"

            # Also wait for readiness (ensures CQL is fully operational)
            echo "  Waiting for readiness healthcheck..."
            local ready_wait=0
            while [ $ready_wait -lt 30 ]; do
                if podman exec "$container_name" /usr/local/bin/healthcheck.sh readiness 2>/dev/null; then
                    echo "  ✓ Container readiness healthcheck passed"
                    return 0
                fi
                sleep 2
                ready_wait=$((ready_wait + 2))
            done

            echo "  ⚠ Readiness check taking longer than expected, but continuing..."
            return 0
        fi

        sleep 5
        elapsed=$((elapsed + 5))
        if [ $((elapsed % 30)) -eq 0 ]; then
            echo "    Waiting... ${elapsed}s / ${max_wait}s"
        fi
    done

    echo "  ✗ Timeout waiting for container startup healthcheck"
    echo "  Last healthcheck output:"
    podman exec "$container_name" /usr/local/bin/healthcheck.sh startup 2>&1 || true
    return 1
}

# Function to check semaphore files
check_semaphores() {
    local container_name="$1"
    echo "  Checking semaphore files..."

    echo "    - System keyspace init semaphore:"
    podman exec "$container_name" cat /var/lib/cassandra/.axonops/init-system-keyspaces.done 2>/dev/null || echo "      NOT FOUND"

    echo "    - Database user init semaphore:"
    podman exec "$container_name" cat /var/lib/cassandra/.axonops/init-db-user.done 2>/dev/null || echo "      NOT FOUND"
}

# Function to check keyspace replication
check_keyspaces() {
    local container_name="$1"
    echo "  Checking system keyspace replication strategies..."

    podman exec "$container_name" nodetool describecluster 2>/dev/null | grep -E "(system_auth|system_distributed|system_traces)" || true
}

# Function to check user exists
check_user() {
    local container_name="$1"
    local username="$2"
    echo "  Checking if user '${username}' exists..."

    podman exec "$container_name" cqlsh -u cassandra -p cassandra -e "SELECT role FROM system_auth.roles WHERE role='${username}';" 2>/dev/null || \
    podman exec "$container_name" cqlsh -u "${username}" -p "securepass123" -e "SELECT now() FROM system.local LIMIT 1;" 2>/dev/null
}

# Run a test scenario
run_test() {
    local test_name="$1"
    local compose_file="$2"
    local container_name="$3"
    local validation_func="$4"

    echo ""
    echo "========================================" | tee -a "$RESULTS_FILE"
    echo "Test: ${test_name}" | tee -a "$RESULTS_FILE"
    echo "========================================" | tee -a "$RESULTS_FILE"
    echo "Compose file: ${compose_file}"
    echo "Container: ${container_name}"
    echo ""

    # Clean up any previous test
    cleanup "$compose_file"

    # Start the container
    echo "Starting container..."
    if ! podman-compose -f "$compose_file" up -d; then
        echo "✗ FAILED: Could not start container" | tee -a "$RESULTS_FILE"
        return 1
    fi

    # Wait for container to be healthy
    if ! wait_for_healthy "$container_name"; then
        echo "  Checking logs..."
        podman logs "$container_name" | tail -50
        echo "✗ FAILED: Container did not become healthy" | tee -a "$RESULTS_FILE"
        cleanup "$compose_file"
        return 1
    fi

    # Run validation
    echo ""
    echo "  Running validation..."
    if $validation_func "$container_name"; then
        echo "" | tee -a "$RESULTS_FILE"
        echo "✓ PASSED: ${test_name}" | tee -a "$RESULTS_FILE"
        echo "" | tee -a "$RESULTS_FILE"
    else
        echo "" | tee -a "$RESULTS_FILE"
        echo "✗ FAILED: ${test_name}" | tee -a "$RESULTS_FILE"
        echo "" | tee -a "$RESULTS_FILE"
    fi

    # Show logs
    echo ""
    echo "  Checking initialization logs..."
    echo "    --- init-system-keyspaces.log ---"
    podman exec "$container_name" cat /var/log/cassandra/init-system-keyspaces.log 2>/dev/null || echo "    Log file not found"
    echo ""
    echo "    Note: Both keyspace and user init logged to same file (init-system-keyspaces.log)"

    # Cleanup
    cleanup "$compose_file"

    echo ""
    echo "Test complete."
    echo ""
}

# Validation functions
validate_test1() {
    local container="$1"
    check_semaphores "$container"
    check_keyspaces "$container"

    # Verify system keyspaces were converted to NTS
    if podman exec "$container" nodetool describecluster 2>/dev/null | grep "system_auth.*NetworkTopologyStrategy"; then
        echo "  ✓ System keyspaces converted to NTS"
        return 0
    else
        echo "  ✗ System keyspaces NOT converted to NTS"
        return 1
    fi
}

validate_test2() {
    local container="$1"
    check_semaphores "$container"

    # Verify init was skipped
    if podman exec "$container" cat /var/lib/cassandra/.axonops/init-system-keyspaces.done 2>/dev/null | grep "disabled_by_env_var"; then
        echo "  ✓ System keyspace init was skipped as expected"
        return 0
    else
        echo "  ✗ System keyspace init was NOT skipped"
        return 1
    fi
}

validate_test3() {
    local container="$1"
    check_semaphores "$container"
    check_keyspaces "$container"
    check_user "$container" "axonops"

    # Try to authenticate with new user
    if podman exec "$container" cqlsh -u axonops -p securepass123 -e "SELECT now() FROM system.local LIMIT 1;" 2>/dev/null; then
        echo "  ✓ Custom user 'axonops' created and working"
    else
        echo "  ✗ Custom user 'axonops' authentication failed"
        return 1
    fi

    # Try to authenticate with default cassandra user (should fail)
    if podman exec "$container" cqlsh -u cassandra -p cassandra -e "SELECT now() FROM system.local LIMIT 1;" 2>/dev/null; then
        echo "  ✗ Default cassandra user still active (should be disabled)"
        return 1
    else
        echo "  ✓ Default cassandra user disabled as expected"
    fi

    return 0
}

validate_test4() {
    local container="$1"
    check_semaphores "$container"

    # Verify init was skipped
    if ! podman exec "$container" cat /var/lib/cassandra/.axonops/init-system-keyspaces.done 2>/dev/null | grep "disabled_by_env_var"; then
        echo "  ✗ System keyspace init was NOT skipped"
        return 1
    fi
    echo "  ✓ System keyspace init skipped (disabled_by_env_var)"

    # Verify user init was also skipped (when INIT_SYSTEM_KEYSPACES_AND_ROLES=false, both skip)
    if ! podman exec "$container" cat /var/lib/cassandra/.axonops/init-db-user.done 2>/dev/null | grep "init_disabled"; then
        echo "  ✗ User init was NOT skipped"
        return 1
    fi
    echo "  ✓ User init skipped (init_disabled)"

    # Wait a bit for CQL authentication to be fully ready (sometimes needs extra time)
    echo "  Waiting for authentication to be ready..."
    sleep 5

    # Should still be able to login with default credentials (retry a few times)
    local max_attempts=3
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if podman exec "$container" cqlsh -u cassandra -p cassandra -e "SELECT now() FROM system.local LIMIT 1;" 2>/dev/null; then
            echo "  ✓ Both init operations skipped as expected"
            echo "  ✓ Default cassandra credentials still work"
            return 0
        fi
        echo "    Attempt $attempt/$max_attempts failed, retrying..."
        sleep 3
        attempt=$((attempt + 1))
    done

    echo "  ✗ Cannot connect with default credentials after $max_attempts attempts"
    echo "  Debug: Checking if Cassandra is ready..."
    podman exec "$container" nodetool status 2>&1 | head -10
    return 1
}

# Initialize results file
echo "AxonDB Time-Series Container Test Results" > "$RESULTS_FILE"
echo "=========================================" >> "$RESULTS_FILE"
echo "Date: $(date)" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Run all tests
run_test "Scenario 1: Default Behavior" \
    "${TEST_DIR}/test-scenario-1-default.yml" \
    "cassandra-test1" \
    "validate_test1"

run_test "Scenario 2: Skip Keyspace Init" \
    "${TEST_DIR}/test-scenario-2-skip-init.yml" \
    "cassandra-test2" \
    "validate_test2"

run_test "Scenario 3: Custom User Creation" \
    "${TEST_DIR}/test-scenario-3-custom-user.yml" \
    "cassandra-test3" \
    "validate_test3"

run_test "Scenario 4: Skip Init + Custom User" \
    "${TEST_DIR}/test-scenario-4-combined.yml" \
    "cassandra-test4" \
    "validate_test4"

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "All tests complete!" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""
echo "Full results saved to: ${RESULTS_FILE}"
