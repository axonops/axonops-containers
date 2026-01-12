#!/usr/bin/env bash
# Test script for K8ssandra cluster deployment validation

set -euo pipefail

info()  { echo "[TEST] $*"; }
error() { echo "[ERROR] $*" >&2; }
pass()  { echo "[PASS] ✓ $*"; }
fail()  { echo "[FAIL] ✗ $*"; }

# Configuration
NS_K8SSANDRA="${NS_K8SSANDRA:-k8ssandra}"
K8SSANDRA_CLUSTER_NAME="${K8SSANDRA_CLUSTER_NAME:-my-k8ssandra-cluster}"
DATACENTER_NAME="${DATACENTER_NAME:-dc1}"
EXPECTED_NODES="${EXPECTED_NODES:-3}"  # Default 3 nodes (1 per rack × 3 racks)

# Test 1: Check K8ssandra operator installation
test_operator() {
  info "Testing K8ssandra operator installation..."

  if kubectl get deployment -n k8ssandra-operator k8ssandra-operator &>/dev/null; then
    pass "K8ssandra operator is deployed"
  else
    fail "K8ssandra operator not found"
    return 1
  fi

  # Check operator pod is running
  local operator_ready=$(kubectl get pods -n k8ssandra-operator -l app.kubernetes.io/name=k8ssandra-operator -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Not Found")
  if [[ "$operator_ready" == "Running" ]]; then
    pass "K8ssandra operator pod is running"
  else
    fail "K8ssandra operator pod status: $operator_ready"
    return 1
  fi

  # Check CRDs
  if kubectl get crd k8ssandraclusters.k8ssandra.io &>/dev/null; then
    pass "K8ssandraCluster CRD exists"
  else
    fail "K8ssandraCluster CRD not found"
    return 1
  fi
}

# Test 2: Check K8ssandra cluster resource
test_cluster_resource() {
  info "Testing K8ssandra cluster resource..."

  if kubectl get k8ssandracluster "$K8SSANDRA_CLUSTER_NAME" -n "$NS_K8SSANDRA" &>/dev/null; then
    pass "K8ssandraCluster resource exists"
  else
    fail "K8ssandraCluster resource not found"
    return 1
  fi

  # Check cluster condition
  local ready_condition=$(kubectl get k8ssandracluster "$K8SSANDRA_CLUSTER_NAME" -n "$NS_K8SSANDRA" \
    -o jsonpath='{.status.datacenters..cassandra.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "false")

  if [[ "$ready_condition" == "True" ]]; then
    pass "K8ssandraCluster reports ready condition"
  else
    fail "K8ssandraCluster not ready (condition: $ready_condition)"
  fi
}

# Test 3: Check Cassandra pods
test_cassandra_pods() {
  info "Testing Cassandra pods..."

  # Count running pods
  local running_pods=$(kubectl get pods -n "$NS_K8SSANDRA" \
    -l "cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME" \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | wc -l)

  if [[ "$running_pods" -eq "$EXPECTED_NODES" ]]; then
    pass "All $EXPECTED_NODES Cassandra pods are running"
  else
    fail "Expected $EXPECTED_NODES pods, found $running_pods running"
    kubectl get pods -n "$NS_K8SSANDRA" -l "cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME"
    return 1
  fi

  # Check each pod's cassandra container
  local all_ready=true
  for pod in $(kubectl get pods -n "$NS_K8SSANDRA" -l "cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME" -o jsonpath='{.items[*].metadata.name}'); do
    local container_ready=$(kubectl get pod "$pod" -n "$NS_K8SSANDRA" \
      -o jsonpath='{.status.containerStatuses[?(@.name=="cassandra")].ready}' 2>/dev/null || echo "false")

    if [[ "$container_ready" != "true" ]]; then
      fail "Cassandra container not ready in pod: $pod"
      all_ready=false
    fi
  done

  if [[ "$all_ready" == "true" ]]; then
    pass "All Cassandra containers are ready"
  else
    return 1
  fi
}

# Test 4: Check storage
test_storage() {
  info "Testing storage configuration..."

  # Check PVCs
  local pvcs=$(kubectl get pvc -n "$NS_K8SSANDRA" \
    -l "cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME" \
    --no-headers 2>/dev/null | wc -l)

  if [[ "$pvcs" -eq "$EXPECTED_NODES" ]]; then
    pass "Found $EXPECTED_NODES PVCs for Cassandra data"
  else
    fail "Expected $EXPECTED_NODES PVCs, found $pvcs"
    kubectl get pvc -n "$NS_K8SSANDRA"
    return 1
  fi

  # Check PVC status
  local bound_pvcs=$(kubectl get pvc -n "$NS_K8SSANDRA" \
    -l "cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME" \
    -o jsonpath='{.items[*].status.phase}' | grep -o "Bound" | wc -l)

  if [[ "$bound_pvcs" -eq "$EXPECTED_NODES" ]]; then
    pass "All PVCs are bound"
  else
    fail "Only $bound_pvcs out of $EXPECTED_NODES PVCs are bound"
    return 1
  fi
}

# Test 5: Check services
test_services() {
  info "Testing services..."

  # Check CQL service
  local cql_service="${K8SSANDRA_CLUSTER_NAME}-${DATACENTER_NAME}-service"
  if kubectl get service "$cql_service" -n "$NS_K8SSANDRA" &>/dev/null; then
    pass "CQL service exists: $cql_service"
  else
    fail "CQL service not found: $cql_service"
    return 1
  fi

  # Check if service has endpoints
  local endpoints=$(kubectl get endpoints "$cql_service" -n "$NS_K8SSANDRA" \
    -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)

  if [[ "$endpoints" -gt 0 ]]; then
    pass "CQL service has $endpoints endpoints"
  else
    fail "CQL service has no endpoints"
    return 1
  fi
}

# Test 6: Check secrets
test_secrets() {
  info "Testing secrets..."

  # Check superuser secret
  local superuser_secret="${K8SSANDRA_CLUSTER_NAME}-superuser"
  if kubectl get secret "$superuser_secret" -n "$NS_K8SSANDRA" &>/dev/null; then
    pass "Superuser secret exists"

    # Check if credentials are present
    local username=$(kubectl get secret "$superuser_secret" -n "$NS_K8SSANDRA" \
      -o jsonpath='{.data.username}' | base64 -d 2>/dev/null)
    local password=$(kubectl get secret "$superuser_secret" -n "$NS_K8SSANDRA" \
      -o jsonpath='{.data.password}' 2>/dev/null)

    if [[ -n "$username" && -n "$password" ]]; then
      pass "Superuser credentials found (username: $username)"
    else
      fail "Superuser credentials incomplete"
      return 1
    fi
  else
    fail "Superuser secret not found"
    return 1
  fi
}

# Test 7: Check Reaper (repair service)
test_reaper() {
  info "Testing Reaper deployment..."

  local reaper_deployment="${K8SSANDRA_CLUSTER_NAME}-${DATACENTER_NAME}-reaper"
  if kubectl get deployment "$reaper_deployment" -n "$NS_K8SSANDRA" &>/dev/null; then
    pass "Reaper deployment exists"

    # Check if Reaper is ready
    local reaper_ready=$(kubectl get deployment "$reaper_deployment" -n "$NS_K8SSANDRA" \
      -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

    if [[ "$reaper_ready" -gt 0 ]]; then
      pass "Reaper is ready ($reaper_ready replicas)"
    else
      fail "Reaper not ready"
    fi
  else
    warn "Reaper not deployed (might be disabled)"
  fi
}

# Test 8: Test CQL connectivity
test_cql_connectivity() {
  info "Testing CQL connectivity..."

  # Get credentials
  local superuser_secret="${K8SSANDRA_CLUSTER_NAME}-superuser"
  local username=$(kubectl get secret "$superuser_secret" -n "$NS_K8SSANDRA" \
    -o jsonpath='{.data.username}' | base64 -d 2>/dev/null)
  local password=$(kubectl get secret "$superuser_secret" -n "$NS_K8SSANDRA" \
    -o jsonpath='{.data.password}' | base64 -d 2>/dev/null)

  if [[ -z "$username" || -z "$password" ]]; then
    fail "Cannot test CQL - credentials not found"
    return 1
  fi

  # Test CQL connection from within pod
  local test_pod="${K8SSANDRA_CLUSTER_NAME}-${DATACENTER_NAME}-rack1-sts-0"
  local cql_test=$(kubectl exec -n "$NS_K8SSANDRA" "$test_pod" -- \
    cqlsh -u "$username" -p "$password" -e "SELECT cluster_name FROM system.local;" 2>/dev/null || echo "FAILED")

  if [[ "$cql_test" != "FAILED" ]] && [[ "$cql_test" == *"$K8SSANDRA_CLUSTER_NAME"* ]]; then
    pass "CQL connectivity verified"
  else
    fail "CQL connectivity test failed"
    info "You can manually test with:"
    echo "  kubectl exec -it -n $NS_K8SSANDRA $test_pod -- cqlsh -u $username -p <password>"
  fi
}

# Main test runner
main() {
  info "Starting K8ssandra deployment validation tests..."
  info "==========================================="
  echo ""

  local failed_tests=0

  # Run tests
  test_operator || ((failed_tests++))
  echo ""

  test_cluster_resource || ((failed_tests++))
  echo ""

  test_cassandra_pods || ((failed_tests++))
  echo ""

  test_storage || ((failed_tests++))
  echo ""

  test_services || ((failed_tests++))
  echo ""

  test_secrets || ((failed_tests++))
  echo ""

  test_reaper || ((failed_tests++))
  echo ""

  test_cql_connectivity || ((failed_tests++))
  echo ""

  # Summary
  info "==========================================="
  if [[ "$failed_tests" -eq 0 ]]; then
    pass "All tests passed! K8ssandra cluster is healthy."
    echo ""
    info "Next steps:"
    echo "  1. Port-forward CQL service:"
    echo "     kubectl port-forward -n $NS_K8SSANDRA svc/${K8SSANDRA_CLUSTER_NAME}-${DATACENTER_NAME}-service 9042:9042"
    echo ""
    echo "  2. Connect with cqlsh:"
    echo "     cqlsh localhost 9042 -u <username> -p <password>"
    echo ""
    echo "  3. Check cluster status:"
    echo "     kubectl get k8ssandracluster -n $NS_K8SSANDRA"
  else
    fail "$failed_tests tests failed. Please check the deployment."
    echo ""
    info "Debugging commands:"
    echo "  # Check operator logs"
    echo "  kubectl logs -n k8ssandra-operator -l app.kubernetes.io/name=k8ssandra-operator"
    echo ""
    echo "  # Check Cassandra pod logs"
    echo "  kubectl logs -n $NS_K8SSANDRA ${K8SSANDRA_CLUSTER_NAME}-${DATACENTER_NAME}-rack1-sts-0 -c cassandra"
    echo ""
    echo "  # Describe cluster"
    echo "  kubectl describe k8ssandracluster $K8SSANDRA_CLUSTER_NAME -n $NS_K8SSANDRA"
    exit 1
  fi
}

# Handle missing utilities gracefully
warn() { echo "[WARN] $*"; }

if ! command -v kubectl &>/dev/null; then
  error "kubectl not found. Please install kubectl first."
  exit 1
fi

main "$@"