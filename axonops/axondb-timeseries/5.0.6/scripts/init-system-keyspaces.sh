#!/bin/bash
set -euo pipefail

# ============================================================================
# AxonOps System Keyspace Initialization Script
# Purpose: Automatically convert system_auth, system_distributed, and
#          system_traces from SimpleStrategy to NetworkTopologyStrategy
#          on first-time cluster bootstrap (ONLY if safe to do so)
# ============================================================================

# Semaphore files for healthcheck coordination
# Located in /var/lib/cassandra (persistent volume) to survive container restarts
SEMAPHORE_DIR="/var/lib/cassandra/.axonops"
SEMAPHORE_FILE="${SEMAPHORE_DIR}/init-system-keyspaces.done"

# Helper function to write semaphore on exit
write_semaphore() {
  local result="$1"
  local reason="${2:-}"
  mkdir -p "$SEMAPHORE_DIR"
  echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$SEMAPHORE_FILE"
  echo "RESULT=$result" >> "$SEMAPHORE_FILE"
  [ -n "$reason" ] && echo "REASON=$reason" >> "$SEMAPHORE_FILE"
}

echo "AxonOps System Keyspace Initialization (Cassandra 5.0.6)"
echo "=========================================================="

# ============================================================================
# 1. Wait for CQL port to be listening
# ============================================================================
# Get native transport port from cassandra.yaml (default 9042)
CQL_PORT=$(grep '^native_transport_port:' /etc/cassandra/cassandra.yaml | awk '{print $2}' || echo "9042")

# Timeout configurable via environment variable (default: 10 minutes)
MAX_WAIT="${INIT_TIMEOUT:-600}"

echo "Waiting for CQL port $CQL_PORT to be listening (timeout: ${MAX_WAIT}s)..."
ELAPSED=0

until nc -z localhost "$CQL_PORT" 2>/dev/null; do
  if [ $ELAPSED -gt $MAX_WAIT ]; then
    echo "⚠ ERROR: CQL port did not open within ${MAX_WAIT}s"
    echo "  This is a fatal error - Cassandra should have started by now"
    echo "  Increase INIT_TIMEOUT env var if Cassandra needs more time to start"
    write_semaphore "failed" "cql_port_timeout"
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

echo "✓ CQL port $CQL_PORT is listening"

# ============================================================================
# 2. Wait for native transport and gossip to be enabled
# ============================================================================
echo "Waiting for native transport and gossip to be enabled (timeout: ${MAX_WAIT}s)..."
ELAPSED=0

until nodetool info 2>/dev/null | grep -q "Native Transport active.*: true" && \
      nodetool info 2>/dev/null | grep -q "Gossip active.*: true"; do
  if [ $ELAPSED -gt $MAX_WAIT ]; then
    echo "⚠ ERROR: Native transport/gossip did not become ready within ${MAX_WAIT}s"
    echo "  This is a fatal error - Cassandra internals should be active by now"
    write_semaphore "failed" "native_transport_timeout"
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

echo "✓ Native transport and gossip are active"

# ============================================================================
# 3. Verify CQL connectivity with default credentials
# ============================================================================
echo "Verifying CQL connectivity..."
CQL_ELAPSED=0
CQL_MAX_WAIT=60  # Wait up to 60 seconds for CQL authentication to be ready

until cqlsh -u cassandra -p cassandra -e "SELECT now() FROM system.local LIMIT 1" > /dev/null 2>&1; do
  if [ $CQL_ELAPSED -gt $CQL_MAX_WAIT ]; then
    echo "⚠ ERROR: CQL connectivity check failed after ${CQL_MAX_WAIT}s"
    echo "  Cannot connect with default cassandra/cassandra credentials"
    echo "  Either authentication is not ready or credentials have been changed"
    write_semaphore "failed" "cql_connectivity_failed"
    exit 1
  fi
  sleep 2
  CQL_ELAPSED=$((CQL_ELAPSED + 2))
done

echo "✓ CQL is ready with default credentials"

# ============================================================================
# 4. Check if this is the first node using nodetool status
# ============================================================================
echo ""
echo "Checking cluster state..."
NODE_COUNT=$(nodetool status 2>/dev/null | grep -c '^[UD][NLJM]' || echo "0")

if [ "$NODE_COUNT" -gt 1 ]; then
  echo "✓ Cluster has $NODE_COUNT nodes, skipping system keyspace initialization"
  write_semaphore "skipped" "multi_node_cluster"
  exit 0
fi

echo "✓ Single node detected ($NODE_COUNT node)"

# ============================================================================
# 5. Check replication strategies using nodetool describecluster
# ============================================================================
echo ""
echo "Checking replication strategies..."
CLUSTER_INFO=$(nodetool describecluster 2>/dev/null)

# Check if any of the 3 keyspaces already use NetworkTopologyStrategy
if echo "$CLUSTER_INFO" | grep -q "system_auth -> Replication class: NetworkTopologyStrategy"; then
  echo "✓ system_auth already uses NetworkTopologyStrategy, skipping initialization"
  write_semaphore "skipped" "already_nts"
  exit 0
fi

if echo "$CLUSTER_INFO" | grep -q "system_distributed -> Replication class: NetworkTopologyStrategy"; then
  echo "✓ system_distributed already uses NetworkTopologyStrategy, skipping initialization"
  write_semaphore "skipped" "already_nts"
  exit 0
fi

if echo "$CLUSTER_INFO" | grep -q "system_traces -> Replication class: NetworkTopologyStrategy"; then
  echo "✓ system_traces already uses NetworkTopologyStrategy, skipping initialization"
  write_semaphore "skipped" "already_nts"
  exit 0
fi

# Check if system_auth has been customized (RF != 1)
# This is our primary indicator that the cluster has been manually configured
SYSTEM_AUTH_RF=$(echo "$CLUSTER_INFO" | grep "system_auth" | grep -oP 'replication_factor=\K\d+' || echo "1")

if [ "$SYSTEM_AUTH_RF" != "1" ]; then
  echo "⚠ system_auth uses SimpleStrategy with RF=$SYSTEM_AUTH_RF (not 1), skipping initialization"
  echo "   User may have already customized this. Aborting to prevent misconfiguration."
  write_semaphore "skipped" "custom_rf"
  exit 0
fi

echo "✓ All checks passed - fresh single-node cluster detected"
echo "  system_auth: SimpleStrategy RF=$SYSTEM_AUTH_RF"

# ============================================================================
# 7. Detect the actual datacenter name from Cassandra
# ============================================================================
echo ""
echo "Detecting datacenter name from Cassandra..."

# Get the actual datacenter name from nodetool status
# This ensures we use the DC that Cassandra is actually running with,
# not what might be in environment variables
# nodetool status output has "Datacenter: <name>" on its own line
DC_NAME=$(nodetool status 2>/dev/null | grep '^Datacenter:' | head -1 | awk '{print $2}' || echo "")

if [ -z "$DC_NAME" ]; then
  echo "⚠ Could not detect datacenter name from nodetool status"
  echo "  Falling back to cassandra-rackdc.properties..."
  DC_NAME=$(grep '^dc=' /etc/cassandra/cassandra-rackdc.properties | cut -d'=' -f2 | tr -d '[:space:]' || echo "")
fi

if [ -z "$DC_NAME" ]; then
  echo "⚠ ERROR: Could not detect datacenter name"
  echo "  Tried nodetool status and cassandra-rackdc.properties"
  echo "  Cannot convert system keyspaces without knowing the datacenter name"
  write_semaphore "failed" "dc_detection_failed"
  exit 1
fi

echo "✓ Detected datacenter: $DC_NAME"

# ============================================================================
# 8. All checks passed - proceed with initialization
# ============================================================================
echo ""
echo "✓ All checks passed. Initializing system keyspaces to NetworkTopologyStrategy..."

# Replication factor is always 1 on initialization (single-node cluster)
RF="1"

echo "  Using DC='$DC_NAME', RF=$RF"

# ============================================================================
# 9. Apply the ALTER KEYSPACE commands
# ============================================================================
echo ""
echo "Altering system_auth..."
cqlsh -u cassandra -p cassandra -e "ALTER KEYSPACE system_auth WITH replication = {'class': 'NetworkTopologyStrategy', '$DC_NAME': $RF};" || {
  echo "⚠ Failed to alter system_auth, continuing anyway"
}

echo "Altering system_distributed..."
cqlsh -u cassandra -p cassandra -e "ALTER KEYSPACE system_distributed WITH replication = {'class': 'NetworkTopologyStrategy', '$DC_NAME': $RF};" || {
  echo "⚠ Failed to alter system_distributed, continuing anyway"
}

echo "Altering system_traces..."
cqlsh -u cassandra -p cassandra -e "ALTER KEYSPACE system_traces WITH replication = {'class': 'NetworkTopologyStrategy', '$DC_NAME': $RF};" || {
  echo "⚠ Failed to alter system_traces, continuing anyway"
}

# ============================================================================
# 10. Write success semaphore for keyspace init
# ============================================================================
echo ""
echo "✓ System keyspace initialization complete"
write_semaphore "success" "initialized_to_nts"

# ============================================================================
# 11. Custom database user creation (if requested)
# ============================================================================
USER_SEMAPHORE_FILE="${SEMAPHORE_DIR}/init-db-user.done"

write_user_semaphore() {
  local result="$1"
  local reason="${2:-}"
  mkdir -p "$SEMAPHORE_DIR"
  echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")" > "$USER_SEMAPHORE_FILE"
  echo "RESULT=$result" >> "$USER_SEMAPHORE_FILE"
  [ -n "$reason" ] && echo "REASON=$reason" >> "$USER_SEMAPHORE_FILE"
}

echo ""
echo "============================================================"
echo "Custom Database User Initialization"
echo "============================================================"

# Check if custom user credentials are provided
if [ -z "${AXONOPS_DB_USER:-}" ] || [ -z "${AXONOPS_DB_PASSWORD:-}" ]; then
  echo "✓ No custom database user requested (AXONOPS_DB_USER/AXONOPS_DB_PASSWORD not set)"
  write_user_semaphore "skipped" "no_custom_user_requested"
  exit 0
fi

echo "Custom database user requested: ${AXONOPS_DB_USER}"

# Check if custom user already exists
echo "Checking if user '${AXONOPS_DB_USER}' already exists..."
USER_EXISTS=$(cqlsh -u cassandra -p cassandra -e "SELECT role FROM system_auth.roles WHERE role='${AXONOPS_DB_USER}';" 2>/dev/null | grep -c "${AXONOPS_DB_USER}" 2>/dev/null || echo "0")
USER_EXISTS=$(echo "$USER_EXISTS" | tr -d '\n' | head -c 10)

if [ "$USER_EXISTS" -gt 0 ]; then
  echo "✓ User '${AXONOPS_DB_USER}' already exists, skipping user initialization"
  write_user_semaphore "skipped" "user_already_exists"
  exit 0
fi

echo "✓ User '${AXONOPS_DB_USER}' does not exist, proceeding with creation"

# Create custom superuser
echo "Creating superuser '${AXONOPS_DB_USER}'..."
cqlsh -u cassandra -p cassandra -e "CREATE ROLE IF NOT EXISTS '${AXONOPS_DB_USER}' WITH PASSWORD = '${AXONOPS_DB_PASSWORD}' AND SUPERUSER = true AND LOGIN = true;" || {
  echo "⚠ ERROR: Failed to create user '${AXONOPS_DB_USER}'"
  echo "  This is a fatal error - user credentials were provided but creation failed"
  write_user_semaphore "failed" "create_user_failed"
  exit 1
}

echo "✓ User '${AXONOPS_DB_USER}' created successfully"

# Test new user authentication
echo "Testing authentication with new user '${AXONOPS_DB_USER}'..."
if ! cqlsh -u "${AXONOPS_DB_USER}" -p "${AXONOPS_DB_PASSWORD}" -e "SELECT now() FROM system.local LIMIT 1" > /dev/null 2>&1; then
  echo "⚠ ERROR: Failed to authenticate with new user '${AXONOPS_DB_USER}'"
  echo "  User was created but authentication test failed - possible CQL issue"
  echo "  Rolling back: deleting user '${AXONOPS_DB_USER}'"
  cqlsh -u cassandra -p cassandra -e "DROP ROLE IF EXISTS '${AXONOPS_DB_USER}';" 2>/dev/null || true
  write_user_semaphore "failed" "new_user_auth_failed"
  exit 1
fi

echo "✓ Successfully authenticated with new user '${AXONOPS_DB_USER}'"

# Disable default cassandra user
echo "Disabling default cassandra user..."
if ! cqlsh -u cassandra -p cassandra -e "ALTER ROLE cassandra WITH LOGIN = false;" 2>/dev/null; then
  echo "⚠ Failed to disable cassandra user (may already be disabled)"
  echo "  This is not critical - continuing anyway."
  echo "  New user '${AXONOPS_DB_USER}' is available and working."
  write_user_semaphore "success" "user_created_cassandra_disable_failed"
  exit 0
fi

echo "✓ Default cassandra user disabled"
echo ""
echo "✓ Database user initialization complete"
echo "  User '${AXONOPS_DB_USER}' is now the active superuser"
echo "  Default 'cassandra' user has been disabled"
write_user_semaphore "success" "user_initialized"
