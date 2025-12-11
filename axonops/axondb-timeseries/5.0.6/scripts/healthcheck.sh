#!/bin/bash
# AxonDB Time-Series Health Check
# Usage: healthcheck.sh {startup|liveness|readiness}
# Parses cassandra.yaml for actual configuration values

set -euo pipefail

MODE="${1:-readiness}"
CASSANDRA_CONF="${CASSANDRA_CONF:-/etc/cassandra/cassandra.yaml}"
TIMEOUT="${HEALTH_CHECK_TIMEOUT:-10}"

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [$MODE] $*" >&2
}

# Parse cassandra.yaml for configuration
get_config_value() {
  local key="$1"
  local default="$2"
  
  if [ ! -f "$CASSANDRA_CONF" ]; then
    log "WARNING: cassandra.yaml not found at $CASSANDRA_CONF, using default"
    echo "$default"
    return 0
  fi
  
  # Extract value from cassandra.yaml (handles: key: value)
  grep -E "^[[:space:]]*${key}:" "$CASSANDRA_CONF" | \
    head -1 | \
    sed -E "s/^[[:space:]]*${key}:[[:space:]]*//;s/#.*//" | \
    xargs echo -n || echo "$default"
}

# Get CQL port (native_transport_port)
get_cql_port() {
  get_config_value "native_transport_port" "9042"
}

# Get listen address (listen_address)
get_listen_address() {
  get_config_value "listen_address" "127.0.0.1"
}

case "$MODE" in
  startup)
    # Wait for init scripts to complete before marking startup as successful
    log "Checking if Cassandra is starting"

    # Check if system keyspace init script semaphore exists
    INIT_KEYSPACE_SEMAPHORE="/etc/axonops/init-system-keyspaces.done"
    if [ ! -f "$INIT_KEYSPACE_SEMAPHORE" ]; then
      log "Waiting for system keyspace init script to complete (semaphore not found)"
      exit 1
    fi

    # Check if database user init script semaphore exists
    INIT_USER_SEMAPHORE="/etc/axonops/init-db-user.done"
    if [ ! -f "$INIT_USER_SEMAPHORE" ]; then
      log "Waiting for database user init script to complete (semaphore not found)"
      exit 1
    fi

    # Check if nodetool responds
    if timeout "$TIMEOUT" nodetool version > /dev/null 2>&1; then
      log "Startup check passed (init scripts complete + nodetool responsive)"
      exit 0
    else
      log "Cassandra not yet responsive"
      exit 1
    fi
    ;;
    
  liveness)
    # Check if JMX/nodetool is responsive
    log "Checking liveness"
    if timeout "$TIMEOUT" nodetool status > /dev/null 2>&1; then
      log "Liveness check passed"
      exit 0
    else
      log "ERROR: nodetool unresponsive"
      exit 1
    fi
    ;;
    
  readiness)
    log "Checking readiness"
    
    # Parse configuration from cassandra.yaml
    CQL_PORT=$(get_cql_port)
    LISTEN_ADDRESS=$(get_listen_address)
    log "Using CQL_PORT=$CQL_PORT, LISTEN_ADDRESS=$LISTEN_ADDRESS"
    
    # Get node state from nodetool status
    IP=$(hostname -i)
    STATE=$(timeout "$TIMEOUT" nodetool status 2>/dev/null | awk -v ip="$IP" '$2 == ip {print $1; exit}')
    log "Node state: ${STATE:-UNKNOWN}"
    
    if [ "$STATE" != "UN" ]; then
      log "ERROR: Node not UN (current: ${STATE:-UNKNOWN})"
      exit 1
    fi
    
    # Check native transport is active via nodetool info
    INFO=$(timeout "$TIMEOUT" nodetool info 2>/dev/null)
    
    if ! echo "$INFO" | grep -q "Native Transport active: true"; then
      log "ERROR: Native transport not active"
      echo "$INFO" | grep "Native Transport" >&2 || true
      exit 1
    fi
    
    if ! echo "$INFO" | grep -q "Gossip active: true"; then
      log "WARNING: Gossip not active"
      # Don't fail - might be temporary
    fi
    
    log "Readiness check passed (UN + native transport active)"
    exit 0
    ;;
    
  *)
    log "ERROR: Invalid mode. Usage: $0 {startup|liveness|readiness}"
    exit 1
    ;;
esac
