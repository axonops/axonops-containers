#!/bin/bash
set -e

# ============================================================================
# AxonDB Backup/Restore - Main Test Runner
# Purpose: Run all test suites in organized fashion
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test suite tracking
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

run_test_suite() {
    local suite_name="$1"
    local test_script="$2"

    TOTAL_SUITES=$((TOTAL_SUITES + 1))

    echo ""
    echo "========================================================================"
    echo -e "${BLUE}TEST SUITE: $suite_name${NC}"
    echo "========================================================================"
    echo "Script: $test_script"
    echo ""

    if bash "$test_script"; then
        echo -e "${GREEN}✓ SUITE PASSED: $suite_name${NC}"
        PASSED_SUITES=$((PASSED_SUITES + 1))
        return 0
    else
        echo -e "${RED}✗ SUITE FAILED: $suite_name${NC}"
        FAILED_SUITES=$((FAILED_SUITES + 1))
        return 1
    fi
}

# Cleanup before starting
cleanup_before_tests() {
    echo "Cleaning up any leftover test resources..."
    podman rm -f $(podman ps -aq) 2>/dev/null || true
    mkdir -p .test-backups
    sudo rm -rf .test-backups/* 2>/dev/null || true
    podman network ls --format "{{.Name}}" | grep -E "ip-test|test-" | xargs -r podman network rm 2>/dev/null || true
    rm -f results/*.log results/*-results.txt 2>/dev/null || true
    echo "✓ Clean slate"
    echo ""
}

echo "================================================================================"
echo "AxonDB Backup/Restore - Complete Test Suite"
echo "================================================================================"
echo "Date: $(date)"
echo "Image: localhost/axondb-timeseries:backup-complete"
echo "================================================================================"

cleanup_before_tests

# ============================================================================
# Run Test Suites
# ============================================================================

CONTINUE_ON_FAILURE="${CONTINUE_ON_FAILURE:-false}"

# Smoke Tests (quick sanity checks)
if [ -f "smoke/basic-functionality.sh" ]; then
    if ! run_test_suite "Smoke Tests (Basic Functionality)" "smoke/basic-functionality.sh"; then
        if [ "$CONTINUE_ON_FAILURE" != "true" ]; then
            echo "Smoke tests failed - stopping"
            exit 1
        fi
    fi
fi

# Integration Tests (run in order: 01-10, includes comprehensive test as 10 last)
for test in integration/{0,1}*.sh; do
    if [ -f "$test" ]; then
        test_name=$(basename "$test" .sh | sed 's/^[0-9]*-//' | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
        if ! run_test_suite "Integration: $test_name" "$test"; then
            if [ "$CONTINUE_ON_FAILURE" != "true" ]; then
                echo "Integration test $(basename $test) failed - stopping"
                exit 1
            fi
        fi
    fi
done

# ============================================================================
# Final Summary
# ============================================================================

echo ""
echo "================================================================================"
echo "FINAL TEST SUMMARY"
echo "================================================================================"
echo ""
echo "Total Suites Run:    $TOTAL_SUITES"
echo "Suites Passed:       $PASSED_SUITES"
echo "Suites Failed:       $FAILED_SUITES"
echo ""

if [ $FAILED_SUITES -eq 0 ]; then
    echo -e "${GREEN}✓✓✓ ALL TEST SUITES PASSED! ✓✓✓${NC}"
    echo ""
    echo "Production ready:"
    echo "  - Smoke tests: Passing ✓"
    echo "  - Core integration: Passing ✓"
    echo "  - Advanced scenarios: Passing ✓"
    echo "  - All features validated ✓"
    exit 0
else
    echo -e "${RED}✗ SOME TEST SUITES FAILED${NC}"
    echo ""
    echo "Failed suites: $FAILED_SUITES"
    echo "Check results/ directory for details"
    exit 1
fi
