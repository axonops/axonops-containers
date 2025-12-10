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
# 1. Wait for CQL to be ready (local node listening on 9042)
# ============================================================================
echo "Waiting for CQL to be ready..."
MAX_WAIT=300  # 5 minutes
ELAPSED=0

until cqlsh -u cassandra -p cassandra -e "SELECT now() FROM system.local" > /dev/null 2>&1; do
  if [ $ELAPSED -gt $MAX_WAIT ]; then
    echo "⚠ CQL did not become ready within ${MAX_WAIT}s, skipping system keyspace init"
    exit 0
  fi
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

echo "✓ CQL is ready with default credentials"

# ============================================================================
# 1a. Safety Check: Verify we can authenticate with default cassandra/cassandra
# ============================================================================
# If authentication fails, it means credentials have been changed
# This implies the cluster has been customized - abort safely
if ! cqlsh -u cassandra -p cassandra -e "SELECT now() FROM system.local" > /dev/null 2>&1; then
  echo "✓ Default credentials not working - cluster has been customized, skipping initialization"
  exit 0
fi

# ============================================================================
# 2. Check if this is the first node (system.peers is empty)
# ============================================================================
echo ""
echo "Checking cluster state..."
PEER_COUNT=$(cqlsh -u cassandra -p cassandra -e "SELECT count(*) FROM system.peers;" 2>/dev/null | grep -oP '^\s*\d+' | tr -d ' ' || echo "unknown")

if [ "$PEER_COUNT" != "0" ] && [ "$PEER_COUNT" != "unknown" ]; then
  echo "✓ Cluster already has peers ($PEER_COUNT), skipping system keyspace initialization"
  exit 0
fi

# ============================================================================
# 3. Check current replication for system_auth (primary safety check)
# ============================================================================
echo ""
echo "Checking system_auth replication strategy..."
SYSTEM_AUTH_REPL=$(cqlsh -u cassandra -p cassandra -e "SELECT replication FROM system_schema.keyspaces WHERE keyspace_name = 'system_auth';" 2>/dev/null | grep '{' || echo "unknown")

if [[ "$SYSTEM_AUTH_REPL" == *"NetworkTopologyStrategy"* ]]; then
  echo "✓ system_auth already uses NetworkTopologyStrategy, skipping initialization"
  exit 0
fi

if [[ "$SYSTEM_AUTH_REPL" == *"SimpleStrategy"* ]]; then
  # Extract RF from SimpleStrategy
  RF=$(echo "$SYSTEM_AUTH_REPL" | grep -oP "'replication_factor':\s*\d+" | grep -oP '\d+' || echo "unknown")
  
  if [ "$RF" != "1" ] && [ "$RF" != "unknown" ]; then
    echo "⚠ system_auth uses SimpleStrategy with RF=$RF (not 1), skipping initialization"
    echo "   User may have already customized this. Aborting to prevent misconfiguration."
    exit 0
  fi
fi

# ============================================================================
# 4. Check system_distributed replication (only check if already NTS)
# ============================================================================
# Note: Cassandra 5.0 defaults system_distributed to RF=3, system_traces to RF=2
# We only use system_auth RF=1 check as the indicator of "fresh/uncustomized" cluster
# If system_auth is RF=1 and SimpleStrategy, we convert all 3 keyspaces to NTS
echo "Checking system_distributed replication strategy..."
SYSTEM_DIST_REPL=$(cqlsh -u cassandra -p cassandra -e "SELECT replication FROM system_schema.keyspaces WHERE keyspace_name = 'system_distributed';" 2>/dev/null | grep '{' || echo "unknown")

if [[ "$SYSTEM_DIST_REPL" == *"NetworkTopologyStrategy"* ]]; then
  echo "✓ system_distributed already uses NetworkTopologyStrategy, skipping initialization"
  exit 0
fi

# ============================================================================
# 5. Check system_traces replication (only check if already NTS)
# ============================================================================
echo "Checking system_traces replication strategy..."
SYSTEM_TRACES_REPL=$(cqlsh -u cassandra -p cassandra -e "SELECT replication FROM system_schema.keyspaces WHERE keyspace_name = 'system_traces';" 2>/dev/null | grep '{' || echo "unknown")

if [[ "$SYSTEM_TRACES_REPL" == *"NetworkTopologyStrategy"* ]]; then
  echo "✓ system_traces already uses NetworkTopologyStrategy, skipping initialization"
  exit 0
fi

# ============================================================================
# 6. All checks passed - proceed with initialization
# ============================================================================
echo ""
echo "✓ All checks passed. Initializing system keyspaces to NetworkTopologyStrategy..."

# Get datacenter and replication factor from environment and only ever RF of 1 on initialisation
DC_NAME="${CASSANDRA_DC:-axonopsdb_dc1}"
RF="1"

echo "  Using DC='$DC_NAME', RF=$RF"

# ============================================================================
# 7. Apply the ALTER KEYSPACE commands
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
