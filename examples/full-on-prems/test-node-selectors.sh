#!/usr/bin/env bash
# Test script for Strimzi node selector functionality
# This script helps test various node placement scenarios

set -euo pipefail

############################################
# Configuration
############################################
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
STRIMZI_CLUSTER_NAME="${STRIMZI_CLUSTER_NAME:-my-cluster}"
NS_KAFKA="${NS_KAFKA:-kafka}"

############################################
# Helper functions
############################################
info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*"; }
error() { echo "[ERROR] $*" >&2; }
success() { echo "[SUCCESS] $*"; }

############################################
# Test Functions
############################################

# Verify pod is on expected node
verify_pod_node() {
  local pod_name=$1
  local expected_node=$2
  local namespace=${3:-$NS_KAFKA}

  local actual_node=$($KUBECTL_BIN get pod "$pod_name" -n "$namespace" -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "not-found")

  if [[ "$actual_node" == "$expected_node" ]]; then
    success "Pod $pod_name is on node $actual_node (as expected)"
    return 0
  elif [[ "$actual_node" == "not-found" ]]; then
    error "Pod $pod_name not found"
    return 1
  else
    error "Pod $pod_name is on node $actual_node (expected: $expected_node)"
    return 1
  fi
}

# Wait for pod to be ready
wait_for_pod() {
  local pod_name=$1
  local namespace=${2:-$NS_KAFKA}
  local timeout=${3:-120}

  info "Waiting for pod $pod_name to be ready..."
  if $KUBECTL_BIN wait --for=condition=Ready pod "$pod_name" -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
    success "Pod $pod_name is ready"
    return 0
  else
    error "Pod $pod_name failed to become ready within ${timeout} seconds"
    return 1
  fi
}

# Test single node deployment (default behavior)
test_single_node_default() {
  info ""
  info "TEST 1: Single node deployment (default behavior)"
  info "================================================"

  # Get current node name
  local node=$($KUBECTL_BIN get nodes --no-headers | head -1 | awk '{print $1}')
  info "Using node: $node"

  export STRIMZI_NODE_HOSTNAME="$node"
  unset KAFKA_BROKER_NODE_SELECTORS
  unset KAFKA_CONTROLLER_NODE_SELECTORS

  info "Running deployment without node selectors (should use default node)..."
  ./strimzi-setup-with-node-selectors.sh

  # Wait for pods and verify placement
  info "Verifying all pods are on the same node..."
  local failed=0

  for i in 0 1 2; do
    wait_for_pod "${STRIMZI_CLUSTER_NAME}-controller-$i" || failed=1
    verify_pod_node "${STRIMZI_CLUSTER_NAME}-controller-$i" "$node" || failed=1
  done

  for i in 0 1 2; do
    wait_for_pod "broker-pool-$i" || failed=1
    verify_pod_node "broker-pool-$i" "$node" || failed=1
  done

  if [[ $failed -eq 0 ]]; then
    success "TEST 1 PASSED: All pods on single node"
  else
    error "TEST 1 FAILED: Pod placement issues"
  fi

  return $failed
}

# Test multi-node broker distribution
test_multi_node_brokers() {
  info ""
  info "TEST 2: Multi-node broker distribution"
  info "======================================="

  # Get available nodes
  local nodes=($($KUBECTL_BIN get nodes --no-headers | awk '{print $1}'))

  if [[ ${#nodes[@]} -lt 2 ]]; then
    warn "Not enough nodes for multi-node test (need at least 2, have ${#nodes[@]})"
    return 0
  fi

  info "Available nodes: ${nodes[*]}"

  # Configure brokers across first 2 nodes, controllers on first node
  export KAFKA_BROKER_NODE_SELECTORS="broker-0:${nodes[0]},broker-1:${nodes[1]},broker-2:${nodes[0]}"
  export KAFKA_CONTROLLER_NODE_SELECTORS="controller-0:${nodes[0]},controller-1:${nodes[0]},controller-2:${nodes[0]}"

  info "Broker configuration:"
  info "  - broker-0 -> ${nodes[0]}"
  info "  - broker-1 -> ${nodes[1]}"
  info "  - broker-2 -> ${nodes[0]}"
  info "Controller configuration:"
  info "  - All controllers -> ${nodes[0]}"

  info "Running deployment with multi-node configuration..."
  ./strimzi-setup-with-node-selectors.sh

  # Wait for pods and verify placement
  info "Verifying pod placement..."
  local failed=0

  # Check controllers (all on first node)
  for i in 0 1 2; do
    wait_for_pod "${STRIMZI_CLUSTER_NAME}-controller-$i" || failed=1
    verify_pod_node "${STRIMZI_CLUSTER_NAME}-controller-$i" "${nodes[0]}" || failed=1
  done

  # Check brokers
  wait_for_pod "broker-pool-0" || failed=1
  verify_pod_node "broker-pool-0" "${nodes[0]}" || failed=1

  wait_for_pod "broker-pool-1" || failed=1
  verify_pod_node "broker-pool-1" "${nodes[1]}" || failed=1

  wait_for_pod "broker-pool-2" || failed=1
  verify_pod_node "broker-pool-2" "${nodes[0]}" || failed=1

  if [[ $failed -eq 0 ]]; then
    success "TEST 2 PASSED: Brokers distributed across nodes"
  else
    error "TEST 2 FAILED: Pod placement issues"
  fi

  return $failed
}

# Test invalid node handling
test_invalid_node() {
  info ""
  info "TEST 3: Invalid node handling"
  info "=============================="

  export KAFKA_BROKER_NODE_SELECTORS="broker-0:non-existent-node"
  export KAFKA_CONTROLLER_NODE_SELECTORS=""

  info "Testing with invalid node 'non-existent-node'..."

  # This should fail during validation
  if ./strimzi-setup-with-node-selectors.sh 2>&1 | grep -q "Node non-existent-node not found"; then
    success "TEST 3 PASSED: Script correctly rejected invalid node"
    return 0
  else
    error "TEST 3 FAILED: Script should have rejected invalid node"
    return 1
  fi
}

# Test partial node selectors
test_partial_selectors() {
  info ""
  info "TEST 4: Partial node selectors"
  info "==============================="

  local nodes=($($KUBECTL_BIN get nodes --no-headers | awk '{print $1}'))
  local default_node="${nodes[0]}"

  info "Using default node: $default_node"

  # Only specify node for broker-0, others should use default
  export KAFKA_BROKER_NODE_SELECTORS="broker-0:$default_node"
  export KAFKA_CONTROLLER_NODE_SELECTORS=""  # Use defaults
  export KAFKA_BROKER_REPLICAS=2  # Only 2 brokers
  export STRIMZI_NODE_HOSTNAME="$default_node"

  info "Configuration:"
  info "  - broker-0 -> $default_node (explicit)"
  info "  - broker-1 -> $default_node (default)"
  info "  - All controllers -> $default_node (default)"

  info "Running deployment with partial selectors..."
  ./strimzi-setup-with-node-selectors.sh

  # Verify placement
  info "Verifying pod placement..."
  local failed=0

  # All should be on the default node
  for i in 0 1; do
    wait_for_pod "broker-pool-$i" || failed=1
    verify_pod_node "broker-pool-$i" "$default_node" || failed=1
  done

  for i in 0 1 2; do
    wait_for_pod "${STRIMZI_CLUSTER_NAME}-controller-$i" || failed=1
    verify_pod_node "${STRIMZI_CLUSTER_NAME}-controller-$i" "$default_node" || failed=1
  done

  if [[ $failed -eq 0 ]]; then
    success "TEST 4 PASSED: Partial selectors with defaults"
  else
    error "TEST 4 FAILED: Pod placement issues"
  fi

  return $failed
}

# Check storage PV node affinity
test_storage_affinity() {
  info ""
  info "TEST 5: Storage PV node affinity"
  info "================================="

  info "Checking PersistentVolume node affinities..."

  local failed=0

  # Check controller PVs
  for i in 0 1 2; do
    local pv_name="pv-${STRIMZI_CLUSTER_NAME}-controller-$i"
    local pv_node=$($KUBECTL_BIN get pv "$pv_name" -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}' 2>/dev/null || echo "not-found")

    if [[ "$pv_node" == "not-found" ]]; then
      warn "PV $pv_name not found or has no node affinity"
    else
      info "PV $pv_name has node affinity to: $pv_node"
    fi
  done

  # Check broker PVs
  for i in 0 1 2; do
    local pv_name="pv-${STRIMZI_CLUSTER_NAME}-broker-pool-$i"
    local pv_node=$($KUBECTL_BIN get pv "$pv_name" -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}' 2>/dev/null || echo "not-found")

    if [[ "$pv_node" == "not-found" ]]; then
      warn "PV $pv_name not found or has no node affinity"
    else
      info "PV $pv_name has node affinity to: $pv_node"
    fi
  done

  success "TEST 5 COMPLETED: Storage affinity check"
  return 0
}

# Clean up test deployment
cleanup_test() {
  info ""
  info "Cleaning up test deployment..."

  # Delete Kafka cluster
  $KUBECTL_BIN delete kafka "$STRIMZI_CLUSTER_NAME" -n "$NS_KAFKA" --ignore-not-found=true

  # Delete NodePools
  $KUBECTL_BIN delete kafkanodepool --all -n "$NS_KAFKA" --ignore-not-found=true

  # Delete PVs
  $KUBECTL_BIN delete pv -l "strimzi.io/cluster=$STRIMZI_CLUSTER_NAME" --ignore-not-found=true

  # Wait for pods to terminate
  info "Waiting for pods to terminate..."
  $KUBECTL_BIN wait --for=delete pod -l "strimzi.io/cluster=$STRIMZI_CLUSTER_NAME" -n "$NS_KAFKA" --timeout=60s 2>/dev/null || true

  success "Cleanup completed"
}

############################################
# Test Suite Menu
############################################
show_menu() {
  echo ""
  echo "=========================================="
  echo "Strimzi Node Selector Test Suite"
  echo "=========================================="
  echo ""
  echo "Available tests:"
  echo "  1) Single node deployment (default)"
  echo "  2) Multi-node broker distribution"
  echo "  3) Invalid node handling"
  echo "  4) Partial node selectors"
  echo "  5) Storage PV affinity check"
  echo "  6) Run all tests"
  echo "  7) Cleanup test deployment"
  echo "  8) Show current pod placement"
  echo "  9) Exit"
  echo ""
}

show_current_placement() {
  info "Current pod placement:"
  echo ""
  $KUBECTL_BIN get pods -n "$NS_KAFKA" -l "strimzi.io/cluster=$STRIMZI_CLUSTER_NAME" \
    -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase,READY:.status.conditions[?'(@.type=="Ready")'].status
}

run_all_tests() {
  info "Running all tests..."

  local total_failed=0

  # Run each test with cleanup between
  test_single_node_default || total_failed=$((total_failed + 1))
  cleanup_test

  test_multi_node_brokers || total_failed=$((total_failed + 1))
  cleanup_test

  test_invalid_node || total_failed=$((total_failed + 1))

  test_partial_selectors || total_failed=$((total_failed + 1))
  test_storage_affinity

  echo ""
  echo "=========================================="
  if [[ $total_failed -eq 0 ]]; then
    success "ALL TESTS PASSED"
  else
    error "$total_failed TESTS FAILED"
  fi
  echo "=========================================="
}

############################################
# Main
############################################
main() {
  # Check if running in non-interactive mode
  if [[ $# -gt 0 ]]; then
    case "$1" in
      all)
        run_all_tests
        ;;
      cleanup)
        cleanup_test
        ;;
      status)
        show_current_placement
        ;;
      *)
        error "Unknown argument: $1"
        echo "Usage: $0 [all|cleanup|status]"
        exit 1
        ;;
    esac
    exit 0
  fi

  # Interactive mode
  while true; do
    show_menu
    read -p "Select test to run: " choice

    case "$choice" in
      1)
        test_single_node_default
        ;;
      2)
        test_multi_node_brokers
        ;;
      3)
        test_invalid_node
        ;;
      4)
        test_partial_selectors
        ;;
      5)
        test_storage_affinity
        ;;
      6)
        run_all_tests
        ;;
      7)
        cleanup_test
        ;;
      8)
        show_current_placement
        ;;
      9)
        info "Exiting..."
        exit 0
        ;;
      *)
        error "Invalid choice"
        ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
  done
}

main "$@"
