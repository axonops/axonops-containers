#!/bin/bash
set -e

# AxonDB Time-Series Entrypoint Script
# Processes cassandra.yaml template with environment variables and starts Cassandra

echo "=== AxonDB Time-Series Starting ==="
echo ""

# JAVA_HOME and PATH are already set correctly by the base image

# Source build info if available
if [ -f /etc/axonops/build-info.txt ]; then
    source /etc/axonops/build-info.txt
    echo "Container Information:"
    echo "  Version:            ${CONTAINER_VERSION:-unknown}"
    echo "  Image:              ${CONTAINER_IMAGE:-unknown}"
    echo "  Build Date:         ${CONTAINER_BUILD_DATE:-unknown}"
    echo "  Production Release: ${IS_PRODUCTION_RELEASE:-false}"
    echo ""
    echo "Component Versions:"
    echo "  Cassandra:          ${CASSANDRA_VERSION:-unknown}"
    echo "  Java:               ${JAVA_VERSION:-unknown}"
    echo "  cqlai:              ${CQLAI_VERSION:-unknown}"
    echo "  Jemalloc:           ${JEMALLOC_VERSION:-unknown}"
    echo "  OS:                 ${OS_VERSION:-unknown}"
    echo "  Platform:           ${PLATFORM:-unknown}"
    echo ""
fi

# Helper function to get container IP address
_ip_address() {
    # scrape the first non-localhost IP address of the container
    ip address | awk '
        $1 == "inet" && $NF != "lo" {
            gsub(/\/.+$/, "", $2)
            print $2
            exit
        }
    '
}

# Set default environment variables if not provided
export CASSANDRA_CLUSTER_NAME="${CASSANDRA_CLUSTER_NAME:-axonopsdb-timeseries}"
export CASSANDRA_NUM_TOKENS="${CASSANDRA_NUM_TOKENS:-8}"
export CASSANDRA_LISTEN_ADDRESS="${CASSANDRA_LISTEN_ADDRESS:-auto}"
export CASSANDRA_RPC_ADDRESS="${CASSANDRA_RPC_ADDRESS:-0.0.0.0}"
export CASSANDRA_DC="${CASSANDRA_DC:-axonopsdb_dc1}"
export CASSANDRA_RACK="${CASSANDRA_RACK:-rack1}"

# Resolve 'auto' to actual IP address
if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
    CASSANDRA_LISTEN_ADDRESS="$(_ip_address)"
fi

# Set broadcast addresses if not specified
if [ -z "$CASSANDRA_BROADCAST_ADDRESS" ]; then
    CASSANDRA_BROADCAST_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"
fi

# If RPC address is 0.0.0.0 (wildcard), broadcast_rpc_address must be set to actual IP
if [ "$CASSANDRA_RPC_ADDRESS" = "0.0.0.0" ] && [ -z "$CASSANDRA_BROADCAST_RPC_ADDRESS" ]; then
    CASSANDRA_BROADCAST_RPC_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"
fi

# Set seeds - default to the node's own IP for single-node deployments
if [ -z "$CASSANDRA_SEEDS" ]; then
    CASSANDRA_SEEDS="$CASSANDRA_BROADCAST_ADDRESS"
fi

# JVM heap settings
export CASSANDRA_HEAP_SIZE="${CASSANDRA_HEAP_SIZE:-8G}"

echo "Configuration:"
echo "  Cluster Name:       ${CASSANDRA_CLUSTER_NAME}"
echo "  DC/Rack:            ${CASSANDRA_DC}/${CASSANDRA_RACK}"
echo "  Num Tokens:         ${CASSANDRA_NUM_TOKENS}"
echo "  Listen Address:     ${CASSANDRA_LISTEN_ADDRESS}"
echo "  RPC Address:        ${CASSANDRA_RPC_ADDRESS}"
echo "  Heap Size:          ${CASSANDRA_HEAP_SIZE}"
echo ""

# Apply environment variable substitutions to cassandra.yaml
# Copied from base image's docker-entrypoint.sh sed logic
_sed-in-place() {
    local filename="$1"; shift
    local tempFile
    tempFile="$(mktemp)"
    sed "$@" "$filename" > "$tempFile"
    cat "$tempFile" > "$filename"
    rm "$tempFile"
}

# Update seeds in cassandra.yaml
_sed-in-place "/etc/cassandra/cassandra.yaml" -r 's/(- seeds:).*/\1 "'"$CASSANDRA_SEEDS"'"/'

# If DC/Rack env vars are set, switch to GossipingPropertyFileSnitch (which reads rackdc.properties)
if [ -n "$CASSANDRA_DC" ] || [ -n "$CASSANDRA_RACK" ]; then
    export CASSANDRA_ENDPOINT_SNITCH="GossipingPropertyFileSnitch"
fi

# Apply CASSANDRA_* environment variables to cassandra.yaml
for yaml in cluster_name num_tokens listen_address rpc_address broadcast_address broadcast_rpc_address endpoint_snitch; do
    var="CASSANDRA_${yaml^^}"
    val="${!var}"
    if [ "$val" ]; then
        _sed-in-place "/etc/cassandra/cassandra.yaml" -r 's/^(# )?('"$yaml"':).*/\2 '"$val"'/'
    fi
done

# Apply DC/Rack to cassandra-rackdc.properties (handle space after =)
for rackdc in dc rack; do
    var="CASSANDRA_${rackdc^^}"
    val="${!var}"
    if [ "$val" ]; then
        _sed-in-place "/etc/cassandra/cassandra-rackdc.properties" -r 's/^('"$rackdc"')\s*=.*/\1='"$val"'/'
    fi
done

# Apply heap size override to jvm17-server.options if env var set
if [ -n "$CASSANDRA_HEAP_SIZE" ]; then
    _sed-in-place "/etc/cassandra/jvm17-server.options" -r 's/^-Xms[0-9]+[GgMm]$/-Xms'"$CASSANDRA_HEAP_SIZE"'/'
    _sed-in-place "/etc/cassandra/jvm17-server.options" -r 's/^-Xmx[0-9]+[GgMm]$/-Xmx'"$CASSANDRA_HEAP_SIZE"'/'
fi

echo "✓ Configuration applied to cassandra.yaml"
echo ""

# Enable jemalloc for memory optimization (UBI path)
if [ -f /usr/lib64/libjemalloc.so.2 ]; then
    export LD_PRELOAD=/usr/lib64/libjemalloc.so.2
    echo "✓ jemalloc enabled"
else
    echo "⚠ jemalloc not found, continuing without it"
fi

# JVM options are set in jvm17-server.options (including Shenandoah GC)

# Initialize system keyspaces and custom database user in background (non-blocking)
# This will wait for Cassandra to be ready, then:
#   1. Convert system keyspaces to NetworkTopologyStrategy (if INIT_SYSTEM_KEYSPACES=true)
#   2. Create custom superuser (if AXONOPS_DB_USER and AXONOPS_DB_PASSWORD are set)
# Only runs on fresh single-node clusters with default credentials
# Can be disabled by setting INIT_SYSTEM_KEYSPACES=false
INIT_SYSTEM_KEYSPACES="${INIT_SYSTEM_KEYSPACES:-true}"

if [ "$INIT_SYSTEM_KEYSPACES" = "true" ]; then
    echo "Starting initialization in background (keyspaces + user)..."
    (/usr/local/bin/init-system-keyspaces.sh > /var/log/cassandra/init-system-keyspaces.log 2>&1 &)
else
    echo "System keyspace initialization disabled (INIT_SYSTEM_KEYSPACES=false)"
    echo "Writing semaphore files to allow healthcheck to proceed..."
    # Write semaphores immediately so healthcheck doesn't block
    mkdir -p /etc/axonops
    {
        echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "RESULT=skipped"
        echo "REASON=disabled_by_env_var"
    } > /etc/axonops/init-system-keyspaces.done
    {
        echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "RESULT=skipped"
        echo "REASON=init_disabled"
    } > /etc/axonops/init-db-user.done
fi

echo ""
echo "=== Starting Cassandra ==="
echo ""

# Execute command (CMD is ["cassandra", "-f"] which gets passed as $@)
exec "$@"
