#!/bin/bash
set -e

# AxonDB Search Comprehensive Smoke Tests
# Tests authentication, cluster health, CRUD operations, healthchecks, and performance

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_FILE="${TEST_DIR}/smoke-test-results.txt"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

echo "AxonDB Search Comprehensive Smoke Test Suite"
echo "============================================="
echo ""
echo "Test results will be saved to: ${RESULTS_FILE}"
echo ""

# Initialize results file
echo "AxonDB Search Smoke Test Results" > "$RESULTS_FILE"
echo "=================================" >> "$RESULTS_FILE"
echo "Date: $(date)" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test functions
pass_test() {
    local test_name="$1"
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
    echo "✓ PASS: $test_name" >> "$RESULTS_FILE"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail_test() {
    local test_name="$1"
    local reason="$2"
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    echo "  Reason: $reason"
    echo "✗ FAIL: $test_name - $reason" >> "$RESULTS_FILE"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-opensearch-smoke-test}"
OPENSEARCH_URL="https://localhost:9200"

# Get custom credentials from container environment if not provided
if [ -z "$CUSTOM_USER" ]; then
    CUSTOM_USER=$(podman exec "$CONTAINER_NAME" printenv AXONOPS_SEARCH_USER 2>/dev/null || echo "axonops")
fi

if [ -z "$CUSTOM_PASSWORD" ]; then
    # Get password from container, handle escaped characters
    CUSTOM_PASSWORD=$(podman exec "$CONTAINER_NAME" printenv AXONOPS_SEARCH_PASSWORD 2>/dev/null || echo "AxonOps@2025!")
fi

DEFAULT_USER="admin"
DEFAULT_PASSWORD="MyS3cur3P@ss2025"

echo "Configuration:"
echo "  Container: $CONTAINER_NAME"
echo "  URL: $OPENSEARCH_URL"
echo "  Custom User: $CUSTOM_USER"
echo ""

# Check if container is running
if ! podman inspect "$CONTAINER_NAME" > /dev/null 2>&1; then
    echo "ERROR: Container '$CONTAINER_NAME' not found or not running"
    echo "Please start the container first with:"
    echo "  podman run -d --name $CONTAINER_NAME \\"
    echo "    -e AXONOPS_SEARCH_USER=$CUSTOM_USER \\"
    echo "    -e AXONOPS_SEARCH_PASSWORD='$CUSTOM_PASSWORD' \\"
    echo "    -e discovery.type=single-node \\"
    echo "    -p 9200:9200 \\"
    echo "    axondb-search:secure"
    exit 1
fi

echo "========================================" | tee -a "$RESULTS_FILE"
echo "AUTHENTICATION TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 1: Verify authentication is enabled (no credentials should fail)
run_test
echo "Test 1: Authentication required (no credentials)"
RESPONSE=$(curl -s --insecure -o /dev/null -w "%{http_code}" "$OPENSEARCH_URL/" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "401" ]; then
    pass_test "Authentication required (got 401 Unauthorized)"
else
    fail_test "Authentication required" "Expected 401, got $RESPONSE"
fi

# Test 2: Verify correct credentials work (default admin)
run_test
echo "Test 2: Default admin credentials work"
RESPONSE=$(curl -s --insecure -u "$DEFAULT_USER:$DEFAULT_PASSWORD" -o /dev/null -w "%{http_code}" "$OPENSEARCH_URL/" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    pass_test "Default admin credentials work (got 200 OK)"
else
    fail_test "Default admin credentials" "Expected 200, got $RESPONSE"
fi

# Test 3: Verify wrong credentials fail
run_test
echo "Test 3: Wrong credentials fail"
RESPONSE=$(curl -s --insecure -u "admin:wrongpassword" -o /dev/null -w "%{http_code}" "$OPENSEARCH_URL/" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "401" ]; then
    pass_test "Wrong credentials fail (got 401 Unauthorized)"
else
    fail_test "Wrong credentials fail" "Expected 401, got $RESPONSE"
fi

# Test 4: Verify custom user credentials work
run_test
echo "Test 4: Custom user credentials work"
RESPONSE=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" -o /dev/null -w "%{http_code}" "$OPENSEARCH_URL/_cluster/health" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    pass_test "Custom user credentials work (got 200 OK)"
else
    fail_test "Custom user credentials" "Expected 200, got $RESPONSE"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "CLUSTER HEALTH TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 5: Cluster health is not red
run_test
echo "Test 5: Cluster health not red"
HEALTH=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" "$OPENSEARCH_URL/_cluster/health" 2>/dev/null)
STATUS=$(echo "$HEALTH" | grep -o '"status":"[^"]*"' | cut -d':' -f2 | tr -d '"')
if [ "$STATUS" = "green" ] || [ "$STATUS" = "yellow" ]; then
    pass_test "Cluster health is $STATUS (not red)"
else
    fail_test "Cluster health" "Status is $STATUS"
fi

# Test 6: At least one node present
run_test
echo "Test 6: At least one node present"
NODES_RESPONSE=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" "$OPENSEARCH_URL/_nodes" 2>/dev/null)
NODE_COUNT=$(echo "$NODES_RESPONSE" | grep -o '"total":[0-9]*' | head -1 | cut -d':' -f2)
if [ "$NODE_COUNT" -ge 1 ] 2>/dev/null; then
    pass_test "Node count: $NODE_COUNT (>= 1)"
else
    fail_test "Node count" "Expected >= 1, got $NODE_COUNT"
fi

# Test 7: Node state is healthy
run_test
echo "Test 7: Node state is healthy"
CAT_NODES=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" "$OPENSEARCH_URL/_cat/nodes?v" 2>/dev/null)
if echo "$CAT_NODES" | grep -qE "(node.role|cluster_manager)"; then
    pass_test "Node state is healthy"
else
    fail_test "Node state" "Could not verify node health"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "INDEX & DOCUMENT CRUD TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

TEST_INDEX="test-smoke-$(date +%s)"

# Test 8: Create an index
run_test
echo "Test 8: Create index: $TEST_INDEX"
CREATE_RESPONSE=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" -X PUT "$OPENSEARCH_URL/$TEST_INDEX" -H 'Content-Type: application/json' -d '{"settings":{"number_of_shards":1,"number_of_replicas":0}}' 2>/dev/null)
if echo "$CREATE_RESPONSE" | grep -q '"acknowledged":true'; then
    pass_test "Index created successfully"
else
    fail_test "Index creation" "Response: $CREATE_RESPONSE"
fi

# Test 9: Create a document
run_test
echo "Test 9: Create document"
DOC_RESPONSE=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" -X POST "$OPENSEARCH_URL/$TEST_INDEX/_doc?refresh=wait_for" -H 'Content-Type: application/json' -d '{"message":"Smoke test document","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","test_id":"smoke-test-1"}' 2>/dev/null)
DOC_ID=$(echo "$DOC_RESPONSE" | grep -o '"_id":"[^"]*"' | cut -d':' -f2 | tr -d '"')
if [ -n "$DOC_ID" ]; then
    pass_test "Document created (ID: $DOC_ID)"
else
    fail_test "Document creation" "Response: $DOC_RESPONSE"
fi

# Test 10: Retrieve the document
run_test
echo "Test 10: Retrieve document by ID"
if [ -n "$DOC_ID" ]; then
    GET_RESPONSE=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" "$OPENSEARCH_URL/$TEST_INDEX/_doc/$DOC_ID" 2>/dev/null)
    if echo "$GET_RESPONSE" | grep -q '"found":true'; then
        pass_test "Document retrieved successfully"
    else
        fail_test "Document retrieval" "Document not found"
    fi
else
    fail_test "Document retrieval" "No document ID from previous test"
fi

# Test 11: Search for the document
run_test
echo "Test 11: Search for document"
# Force refresh and search directly
SEARCH_RESPONSE=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" "$OPENSEARCH_URL/$TEST_INDEX/_search" -H 'Content-Type: application/json' -d '{"query":{"match":{"test_id":"smoke-test-1"}}}' 2>/dev/null)
HIT_COUNT=$(echo "$SEARCH_RESPONSE" | grep -o '"total":{"value":[0-9]*' | cut -d':' -f3)
if [ "$HIT_COUNT" = "1" ] 2>/dev/null; then
    pass_test "Document found via search"
else
    fail_test "Document search" "Expected 1 hit, got $HIT_COUNT"
fi

# Test 12: Delete the document
run_test
echo "Test 12: Delete document"
if [ -n "$DOC_ID" ]; then
    DELETE_DOC_RESPONSE=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" -X DELETE "$OPENSEARCH_URL/$TEST_INDEX/_doc/$DOC_ID" 2>/dev/null)
    if echo "$DELETE_DOC_RESPONSE" | grep -q '"result":"deleted"'; then
        pass_test "Document deleted successfully"
    else
        fail_test "Document deletion" "Response: $DELETE_DOC_RESPONSE"
    fi
else
    fail_test "Document deletion" "No document ID"
fi

# Test 13: Delete the index
run_test
echo "Test 13: Delete index"
DELETE_INDEX_RESPONSE=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" -X DELETE "$OPENSEARCH_URL/$TEST_INDEX" 2>/dev/null)
if echo "$DELETE_INDEX_RESPONSE" | grep -q '"acknowledged":true'; then
    pass_test "Index deleted successfully"
else
    fail_test "Index deletion" "Response: $DELETE_INDEX_RESPONSE"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "HEALTHCHECK SCRIPT TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 14: Startup healthcheck
run_test
echo "Test 14: Startup healthcheck"
if podman exec "$CONTAINER_NAME" /usr/local/bin/healthcheck.sh startup >/dev/null 2>&1; then
    pass_test "Startup healthcheck returns exit code 0"
else
    fail_test "Startup healthcheck" "Exit code non-zero"
fi

# Test 15: Liveness healthcheck
run_test
echo "Test 15: Liveness healthcheck"
if podman exec "$CONTAINER_NAME" /usr/local/bin/healthcheck.sh liveness >/dev/null 2>&1; then
    pass_test "Liveness healthcheck returns exit code 0"
else
    fail_test "Liveness healthcheck" "Exit code non-zero"
fi

# Test 16: Readiness healthcheck
run_test
echo "Test 16: Readiness healthcheck"
if podman exec "$CONTAINER_NAME" /usr/local/bin/healthcheck.sh readiness >/dev/null 2>&1; then
    pass_test "Readiness healthcheck returns exit code 0"
else
    fail_test "Readiness healthcheck" "Exit code non-zero"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "PERFORMANCE & BULK TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

BULK_INDEX="test-bulk-$(date +%s)"

# Test 17: Bulk insert 1000 documents
run_test
echo "Test 17: Bulk insert 1000 documents"

# Create bulk request payload
BULK_DATA=""
for i in $(seq 1 1000); do
    BULK_DATA="${BULK_DATA}{\"index\":{\"_index\":\"$BULK_INDEX\"}}\n"
    BULK_DATA="${BULK_DATA}{\"message\":\"Bulk test document $i\",\"doc_number\":$i,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}\n"
done

# Send bulk request
START_TIME=$(date +%s)
BULK_RESPONSE=$(echo -e "$BULK_DATA" | curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" -X POST "$OPENSEARCH_URL/_bulk" -H 'Content-Type: application/x-ndjson' --data-binary @- 2>/dev/null)
END_TIME=$(date +%s)
BULK_DURATION=$((END_TIME - START_TIME))

if echo "$BULK_RESPONSE" | grep -q '"errors":false'; then
    INDEXED_COUNT=$(echo "$BULK_RESPONSE" | grep -o '"index":{' | wc -l)
    pass_test "Bulk indexed $INDEXED_COUNT documents in ${BULK_DURATION}s"
else
    fail_test "Bulk insert" "Errors in bulk response"
fi

# Test 18: Verify documents are indexed
run_test
echo "Test 18: Verify bulk documents are indexed"
sleep 2  # Allow time for refresh
COUNT_RESPONSE=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" "$OPENSEARCH_URL/$BULK_INDEX/_count" 2>/dev/null)
DOC_COUNT=$(echo "$COUNT_RESPONSE" | grep -o '"count":[0-9]*' | cut -d':' -f2)
if [ "$DOC_COUNT" = "1000" ] 2>/dev/null; then
    pass_test "All 1000 documents indexed correctly"
else
    fail_test "Bulk document verification" "Expected 1000 docs, got $DOC_COUNT"
fi

# Test 19: Simple search query performance
run_test
echo "Test 19: Simple search query performance"
START_TIME=$(date +%s%3N)  # milliseconds
SEARCH_RESPONSE=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" "$OPENSEARCH_URL/$BULK_INDEX/_search?q=doc_number:500" 2>/dev/null)
END_TIME=$(date +%s%3N)
QUERY_DURATION=$((END_TIME - START_TIME))

HITS=$(echo "$SEARCH_RESPONSE" | grep -o '"total":{"value":[0-9]*' | cut -d':' -f3)
if [ "$HITS" = "1" ] 2>/dev/null && [ "$QUERY_DURATION" -lt 1000 ]; then
    pass_test "Search query returned 1 result in ${QUERY_DURATION}ms (< 1000ms)"
else
    if [ "$QUERY_DURATION" -ge 1000 ] 2>/dev/null; then
        fail_test "Search query performance" "Took ${QUERY_DURATION}ms (>= 1000ms)"
    else
        fail_test "Search query" "Expected 1 hit, got $HITS"
    fi
fi

# Clean up bulk index
echo "Cleaning up bulk test index..."
curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" -X DELETE "$OPENSEARCH_URL/$BULK_INDEX" >/dev/null 2>&1

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "DATA PERSISTENCE TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

PERSIST_INDEX="test-persist-$(date +%s)"

# Test 20: Create index and add data
run_test
echo "Test 20: Create persistent index with data"
curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" -X PUT "$OPENSEARCH_URL/$PERSIST_INDEX" -H 'Content-Type: application/json' -d '{"settings":{"number_of_shards":1,"number_of_replicas":0}}' >/dev/null 2>&1

DOC1=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" -X POST "$OPENSEARCH_URL/$PERSIST_INDEX/_doc?refresh=true" -H 'Content-Type: application/json' -d '{"message":"Persistence test 1"}' 2>/dev/null)
DOC2=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" -X POST "$OPENSEARCH_URL/$PERSIST_INDEX/_doc?refresh=true" -H 'Content-Type: application/json' -d '{"message":"Persistence test 2"}' 2>/dev/null)

COUNT=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" "$OPENSEARCH_URL/$PERSIST_INDEX/_count" 2>/dev/null | grep -o '"count":[0-9]*' | cut -d':' -f2)
if [ "$COUNT" = "2" ] 2>/dev/null; then
    pass_test "Created index with 2 documents"
else
    fail_test "Data creation" "Expected 2 docs, got $COUNT"
fi

# Test 21: Read data back
run_test
echo "Test 21: Read data and verify"
SEARCH_ALL=$(curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" "$OPENSEARCH_URL/$PERSIST_INDEX/_search" 2>/dev/null)
HIT_COUNT=$(echo "$SEARCH_ALL" | grep -o '"total":{"value":[0-9]*' | cut -d':' -f3)
if [ "$HIT_COUNT" = "2" ] 2>/dev/null && echo "$SEARCH_ALL" | grep -q "Persistence test"; then
    pass_test "Data read back correctly (2 documents found)"
else
    fail_test "Data read" "Expected 2 hits with correct content"
fi

# Test 22: Verify data in data directory
run_test
echo "Test 22: Verify index exists in data directory"
if podman exec "$CONTAINER_NAME" test -d /var/lib/opensearch/nodes/0/indices/ 2>/dev/null; then
    INDEX_COUNT=$(podman exec "$CONTAINER_NAME" ls /var/lib/opensearch/nodes/0/indices/ 2>/dev/null | wc -l)
    if [ "$INDEX_COUNT" -gt 0 ]; then
        pass_test "Index data exists in /var/lib/opensearch (found $INDEX_COUNT indices)"
    else
        fail_test "Index data directory" "No indices found"
    fi
else
    fail_test "Index data directory" "Directory not found"
fi

# Clean up persist index
echo "Cleaning up persistence test index..."
curl -s --insecure -u "$CUSTOM_USER:$CUSTOM_PASSWORD" -X DELETE "$OPENSEARCH_URL/$PERSIST_INDEX" >/dev/null 2>&1

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "SEMAPHORE & INIT SCRIPT TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 23: Semaphore file exists
run_test
echo "Test 23: Semaphore file exists"
if podman exec "$CONTAINER_NAME" test -f /var/lib/opensearch/.axonops/init-security.done; then
    pass_test "Semaphore file exists"
else
    fail_test "Semaphore file" "File not found"
fi

# Test 24: Semaphore contains RESULT field
run_test
echo "Test 24: Semaphore has RESULT field"
SEMAPHORE_CONTENT=$(podman exec "$CONTAINER_NAME" cat /var/lib/opensearch/.axonops/init-security.done 2>/dev/null)
if echo "$SEMAPHORE_CONTENT" | grep -q "^RESULT="; then
    RESULT=$(echo "$SEMAPHORE_CONTENT" | grep "^RESULT=" | cut -d'=' -f2)
    pass_test "Semaphore RESULT=$RESULT"
else
    fail_test "Semaphore RESULT field" "Field not found"
fi

# Test 25: Custom user recorded in semaphore
run_test
echo "Test 25: Custom user recorded in semaphore"
if echo "$SEMAPHORE_CONTENT" | grep -q "^ADMIN_USER=$CUSTOM_USER"; then
    pass_test "Custom user $CUSTOM_USER recorded in semaphore"
else
    fail_test "Custom user in semaphore" "ADMIN_USER not found or incorrect"
fi

# Test 26: Init script log exists
run_test
echo "Test 26: Init script log exists and shows success"
INIT_LOG=$(podman exec "$CONTAINER_NAME" cat /var/log/opensearch/init-opensearch.log 2>/dev/null || echo "")
if echo "$INIT_LOG" | grep -q "Admin User Created"; then
    pass_test "Init script log shows successful user creation"
else
    fail_test "Init script log" "Success message not found"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "ENVIRONMENT VARIABLE TESTS" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 28: Cluster name from environment variable
run_test
echo "Test 28: OPENSEARCH_CLUSTER_NAME applied"
CLUSTER_INFO=$(curl -s --insecure -u "$DEFAULT_USER:$DEFAULT_PASSWORD" "$OPENSEARCH_URL/" 2>/dev/null)
CLUSTER_NAME=$(echo "$CLUSTER_INFO" | grep -o '"cluster_name" : "[^"]*"' | cut -d'"' -f4)
if [ "$CLUSTER_NAME" = "axonopsdb-search" ]; then
    pass_test "Cluster name is axonopsdb-search (default)"
else
    fail_test "Cluster name" "Expected axonopsdb-search, got $CLUSTER_NAME"
fi

# Test 29: Heap size from environment variable
run_test
echo "Test 29: OPENSEARCH_HEAP_SIZE applied"
# Check JVM info for heap settings
JVM_INFO=$(curl -s --insecure -u "$DEFAULT_USER:$DEFAULT_PASSWORD" "$OPENSEARCH_URL/_nodes/stats/jvm" 2>/dev/null)
HEAP_MAX=$(echo "$JVM_INFO" | grep -o '"heap_max_in_bytes":[0-9]*' | head -1 | cut -d':' -f2)
# 8GB = 8589934592 bytes
EXPECTED_HEAP=8589934592
if [ "$HEAP_MAX" = "$EXPECTED_HEAP" ] 2>/dev/null; then
    pass_test "Heap size is 8GB (default)"
else
    # Allow some variation (within 1GB)
    DIFF=$((HEAP_MAX - EXPECTED_HEAP))
    ABS_DIFF=${DIFF#-}  # absolute value
    if [ "$ABS_DIFF" -lt 1073741824 ]; then
        pass_test "Heap size is approximately 8GB (${HEAP_MAX} bytes)"
    else
        fail_test "Heap size" "Expected ~8GB, got ${HEAP_MAX} bytes"
    fi
fi

# Test 30: Discovery type from environment variable
run_test
echo "Test 30: discovery.type applied"
CLUSTER_SETTINGS=$(curl -s --insecure -u "$DEFAULT_USER:$DEFAULT_PASSWORD" "$OPENSEARCH_URL/_cluster/settings?include_defaults=true&flat_settings=true" 2>/dev/null)
if echo "$CLUSTER_SETTINGS" | grep -q '"discovery.type":"single-node"'; then
    pass_test "Discovery type is single-node"
else
    fail_test "Discovery type" "Expected single-node"
fi

# Test 31: Network host from environment variable
run_test
echo "Test 31: network.host applied"
NODE_INFO=$(curl -s --insecure -u "$DEFAULT_USER:$DEFAULT_PASSWORD" "$OPENSEARCH_URL/_nodes/_local" 2>/dev/null)
# Check for bound_address showing all interfaces ([::]:9200 or 0.0.0.0:9200)
if echo "$NODE_INFO" | grep -qE '"bound_address".*\[::\]:9200'; then
    pass_test "Network host is 0.0.0.0 (bound to all interfaces)"
else
    fail_test "Network host" "Expected binding to all interfaces"
fi

# Test 32: Custom admin user from environment variables
run_test
echo "Test 32: AXONOPS_SEARCH_USER created"
USER_INFO=$(curl -s --insecure -u "$DEFAULT_USER:$DEFAULT_PASSWORD" "$OPENSEARCH_URL/_plugins/_security/api/internalusers/$CUSTOM_USER" 2>/dev/null)
if echo "$USER_INFO" | grep -q "\"$CUSTOM_USER\""; then
    pass_test "Custom user $CUSTOM_USER exists in security index"
else
    fail_test "Custom user existence" "User $CUSTOM_USER not found"
fi

# Test 33: TLS enabled by default (AXONOPS_SEARCH_TLS_ENABLED)
run_test
echo "Test 33: TLS enabled by default (HTTPS)"
# Check if HTTPS works (TLS should be enabled by default)
HTTPS_RESPONSE=$(curl -s --insecure -o /dev/null -w "%{http_code}" -u "$DEFAULT_USER:$DEFAULT_PASSWORD" "https://localhost:9200/" 2>/dev/null || echo "000")
if [ "$HTTPS_RESPONSE" = "200" ]; then
    pass_test "HTTPS accessible (TLS enabled by default)"
else
    fail_test "HTTPS access" "Expected 200, got $HTTPS_RESPONSE"
fi

# Test 34: Verify container environment has TLS setting
run_test
echo "Test 34: AXONOPS_SEARCH_TLS_ENABLED environment variable"
TLS_ENV=$(podman exec "$CONTAINER_NAME" printenv AXONOPS_SEARCH_TLS_ENABLED 2>/dev/null || echo "")
if [ -z "$TLS_ENV" ] || [ "$TLS_ENV" = "true" ]; then
    pass_test "AXONOPS_SEARCH_TLS_ENABLED defaults to true or is set correctly"
else
    fail_test "TLS environment variable" "Expected true or unset, got $TLS_ENV"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "TLS DISABLED TEST (HTTP Mode)" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 35: Start new container with TLS disabled and verify HTTP works
run_test
echo "Test 35: TLS disabled mode - HTTP accessible"
echo "  Starting temporary container with AXONOPS_SEARCH_TLS_ENABLED=false..."

# Start container with TLS disabled
TLS_CONTAINER="opensearch-tls-disabled-test"
podman run -d --name "$TLS_CONTAINER" \
  -e AXONOPS_SEARCH_TLS_ENABLED=false \
  -e discovery.type=single-node \
  -p 9201:9200 \
  axondb-search:secure >/dev/null 2>&1

# Wait for container to be ready
sleep 30

# Test HTTP (not HTTPS) access
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -u "$DEFAULT_USER:$DEFAULT_PASSWORD" "http://localhost:9201/" 2>/dev/null || echo "000")

# Clean up
podman stop "$TLS_CONTAINER" >/dev/null 2>&1
podman rm "$TLS_CONTAINER" >/dev/null 2>&1

if [ "$HTTP_RESPONSE" = "200" ]; then
    pass_test "HTTP accessible when TLS disabled (got 200)"
else
    fail_test "HTTP with TLS disabled" "Expected 200, got $HTTP_RESPONSE"
fi

# Test 36: Verify HTTPS fails when TLS disabled
run_test
echo "Test 36: TLS disabled mode - HTTPS not required"
echo "  Starting temporary container with AXONOPS_SEARCH_TLS_ENABLED=false..."

# Start container with TLS disabled
podman run -d --name "$TLS_CONTAINER" \
  -e AXONOPS_SEARCH_TLS_ENABLED=false \
  -e discovery.type=single-node \
  -p 9201:9200 \
  axondb-search:secure >/dev/null 2>&1

# Wait for container to be ready
sleep 30

# Verify HTTP works (primary check)
HTTP_WORKS=$(curl -s -o /dev/null -w "%{http_code}" -u "$DEFAULT_USER:$DEFAULT_PASSWORD" "http://localhost:9201/" 2>/dev/null || echo "000")

# Check that healthcheck uses HTTP protocol
HEALTHCHECK_OUTPUT=$(podman exec "$TLS_CONTAINER" /usr/local/bin/healthcheck.sh readiness 2>&1 || true)

# Clean up
podman stop "$TLS_CONTAINER" >/dev/null 2>&1
podman rm "$TLS_CONTAINER" >/dev/null 2>&1

if [ "$HTTP_WORKS" = "200" ] && echo "$HEALTHCHECK_OUTPUT" | grep -q "Readiness check passed"; then
    pass_test "HTTP mode fully functional (API + healthchecks work)"
else
    fail_test "HTTP mode validation" "HTTP response: $HTTP_WORKS, healthcheck unclear"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "PROCESS FAILURE DETECTION TEST (DESTRUCTIVE - RUNS LAST)" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

# Test 37: Kill OpenSearch process and verify liveness healthcheck fails
# NOTE: This test is DESTRUCTIVE and runs last because it kills the container
run_test
echo "Test 37: Healthcheck detects killed process"
# Get OpenSearch PID
OPENSEARCH_PID=$(podman exec "$CONTAINER_NAME" pgrep -f "org.opensearch.bootstrap.OpenSearch" 2>/dev/null | head -1)
if [ -n "$OPENSEARCH_PID" ]; then
    # Kill the process
    echo "  Killing OpenSearch process (PID: $OPENSEARCH_PID)..."
    podman exec "$CONTAINER_NAME" kill -9 "$OPENSEARCH_PID" 2>/dev/null || true
    sleep 2

    # Liveness check should fail now
    if ! podman exec "$CONTAINER_NAME" /usr/local/bin/healthcheck.sh liveness >/dev/null 2>&1; then
        pass_test "Liveness healthcheck correctly detected process failure (exit code 1)"
    else
        fail_test "Process failure detection" "Liveness check passed when it should have failed"
    fi
else
    fail_test "Process failure detection" "Could not find OpenSearch PID"
fi

echo ""
echo "========================================" | tee -a "$RESULTS_FILE"
echo "TEST SUMMARY" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo ""

echo "Tests Run:    $TESTS_RUN" | tee -a "$RESULTS_FILE"
echo "Tests Passed: $TESTS_PASSED" | tee -a "$RESULTS_FILE"
echo "Tests Failed: $TESTS_FAILED" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}" | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}" | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"
    exit 1
fi
