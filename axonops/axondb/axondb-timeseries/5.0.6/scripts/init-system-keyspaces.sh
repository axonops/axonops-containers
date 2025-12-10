#!/bin/bash
set -euo pipefail

# ============================================================================
# AxonOps System Keyspace Initialization Script
# Purpose: Automatically convert system_auth, system_distributed, and 
#          system_traces from SimpleStrategy to NetworkTopologyStrategy
#          on first-time cluster bootstrap (ONLY if safe to do so)
# ============================================================================

echo "AxonOps System Keyspace Initialization (Cassandra 5.0.6)"
echo "=========================================================="

# ============================================================================
# 1. Wait for CQL port to be listening
# ============================================================================
# Get native transport port from cassandra.yaml (default 9042)
CQL_PORT=$(grep '^native_transport_port:' /etc/cassandra/cassandra.yaml | awk '{print $2}' || echo "9042")

echo "Waiting for CQL port $CQL_PORT to be listening..."
MAX_WAIT=300  # 5 minutes
ELAPSED=0

until nc -z localhost "$CQL_PORT" 2>/dev/null; do
  if [ $ELAPSED -gt $MAX_WAIT ]; then
    echo "⚠ CQL port did not open within ${MAX_WAIT}s, skipping system keyspace init"
    exit 0
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

echo "✓ CQL port $CQL_PORT is listening"

# ============================================================================
# 2. Wait for native transport and gossip to be enabled
# ============================================================================
echo "Waiting for native transport and gossip to be enabled..."
ELAPSED=0

until nodetool info 2>/dev/null | grep -q "Native Transport active: true" && \
      nodetool info 2>/dev/null | grep -q "Gossip active: true"; do
  if [ $ELAPSED -gt $MAX_WAIT ]; then
    echo "⚠ Native transport/gossip did not become ready within ${MAX_WAIT}s, skipping"
    exit 0
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

echo "✓ Native transport and gossip are active"

# ============================================================================
# 3. Verify CQL connectivity with default credentials
# ============================================================================
echo "Verifying CQL connectivity..."
if ! cqlsh -u cassandra -p cassandra -e "SELECT now() FROM system.local LIMIT 1" > /dev/null 2>&1; then
  echo "⚠ CQL connectivity check failed, skipping system keyspace init"
  exit 0
fi

echo "✓ CQL is ready with default credentials"

# ============================================================================
# 4. Check if this is the first node using nodetool status
# ============================================================================
echo ""
echo "Checking cluster state..."
NODE_COUNT=$(nodetool status 2>/dev/null | grep -c '^[UD][NLJM]' || echo "0")

if [ "$NODE_COUNT" -gt 1 ]; then
  echo "✓ Cluster has $NODE_COUNT nodes, skipping system keyspace initialization"
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
  exit 0
fi

if echo "$CLUSTER_INFO" | grep -q "system_distributed -> Replication class: NetworkTopologyStrategy"; then
  echo "✓ system_distributed already uses NetworkTopologyStrategy, skipping initialization"
  exit 0
fi

if echo "$CLUSTER_INFO" | grep -q "system_traces -> Replication class: NetworkTopologyStrategy"; then
  echo "✓ system_traces already uses NetworkTopologyStrategy, skipping initialization"
  exit 0
fi

# Check if system_auth has been customized (RF != 1)
# This is our primary indicator that the cluster has been manually configured
SYSTEM_AUTH_RF=$(echo "$CLUSTER_INFO" | grep "system_auth" | grep -oP 'replication_factor=\K\d+' || echo "1")

if [ "$SYSTEM_AUTH_RF" != "1" ]; then
  echo "⚠ system_auth uses SimpleStrategy with RF=$SYSTEM_AUTH_RF (not 1), skipping initialization"
  echo "   User may have already customized this. Aborting to prevent misconfiguration."
  exit 0
fi

echo "✓ All checks passed - fresh single-node cluster detected"
echo "  system_auth: SimpleStrategy RF=$SYSTEM_AUTH_RF"

# ============================================================================
# 7. All checks passed - proceed with initialization
# ============================================================================
echo ""
echo "✓ All checks passed. Initializing system keyspaces to NetworkTopologyStrategy..."

# Get datacenter and replication factor from environment and only ever RF of 1 on initialisation
DC_NAME="${CASSANDRA_DC:-axonopsdb_dc1}"
RF="1"

echo "  Using DC='$DC_NAME', RF=$RF"

# ============================================================================
# 8. Apply the ALTER KEYSPACE commands
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
# 8. Run repair to propagate changes
# ============================================================================
# Not run as not necessary as only on initalisation
# echo ""
# echo "Running repair to propagate replication changes..."
# nodetool repair -full system_auth system_distributed system_traces 2>/dev/null || {
#   echo "⚠ Repair encountered issues but initialization completed"
# }

# echo ""
# echo "✓ System keyspace initialization complete"
