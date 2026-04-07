#!/bin/bash
# Common test utilities and cleanup functions
# Source this in all test scripts

# Project-local backup volume (relative to tests/ directory)
TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_VOLUME="${TEST_ROOT}/.test-backups"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Resources to clean up (populated by tests)
CONTAINERS_TO_CLEANUP=()
NETWORKS_TO_CLEANUP=()

pass_test() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail_test() {
    echo -e "${RED}✗ FAIL${NC}: $1 - $2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Register container for cleanup
register_container() {
    CONTAINERS_TO_CLEANUP+=("$1")
}

# Register network for cleanup
register_network() {
    NETWORKS_TO_CLEANUP+=("$1")
}

# Cleanup function (call in trap)
cleanup_test_resources() {
    local exit_code=$?

    echo ""
    echo "Cleaning up test resources..."

    # Remove containers
    for container in "${CONTAINERS_TO_CLEANUP[@]}"; do
        podman rm -f "$container" >/dev/null 2>&1 && echo "  Removed container: $container" || true
    done

    # Remove networks
    for network in "${NETWORKS_TO_CLEANUP[@]}"; do
        podman network rm "$network" >/dev/null 2>&1 && echo "  Removed network: $network" || true
    done

    echo "✓ Cleanup complete"

    exit $exit_code
}

# Wait for Cassandra to be ready (reusable)
wait_for_cassandra_ready() {
    local container_name="$1"
    local username="${2:-cassandra}"
    local password="${3:-cassandra}"
    local max_wait="${4:-180}"
    local elapsed=0

    while [ $elapsed -lt $max_wait ]; do
        if podman exec "$container_name" nc -z localhost 9042 2>/dev/null; then
            if podman exec "$container_name" cqlsh -u "$username" -p "$password" -e "SELECT cluster_name FROM system.local;" >/dev/null 2>&1; then
                return 0
            fi
        fi

        sleep 5
        elapsed=$((elapsed + 5))

        if [ $((elapsed % 30)) -eq 0 ]; then
            echo "  Waiting for Cassandra (${elapsed}s)..."
        fi
    done

    echo "ERROR: Cassandra not ready after ${max_wait}s"
    return 1
}

# Create test container (standardized)
create_test_container() {
    local name="$1"
    local extra_args="${2:-}"

    register_container "$name"

    podman run -d --name "$name" \
        -v "$BACKUP_VOLUME":/backup \
        -e CASSANDRA_CLUSTER_NAME=test-cluster \
        -e CASSANDRA_DC=dc1 \
        -e CASSANDRA_HEAP_SIZE=4G \
        -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
        $extra_args \
        localhost/axondb-timeseries:backup-complete >/dev/null

    echo "Created container: $name"
}

# Print test summary
print_test_summary() {
    echo ""
    echo "========================================================================"
    echo "TEST SUMMARY"
    echo "========================================================================"
    echo ""
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
        return 0
    else
        echo -e "${RED}✗ SOME TESTS FAILED${NC}"
        return 1
    fi
}
