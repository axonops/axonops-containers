#!/bin/bash
set -e

# AxonDB Time-Series Entrypoint Script
# Processes cassandra.yaml template with environment variables and starts Cassandra

echo "=== AxonDB Time-Series Starting ==="
echo ""

# Fix JAVA_HOME and PATH to use Azul Zulu instead of base image's Temurin
if [ -d "/usr/lib/jvm/zulu17-ca-arm64" ]; then
    export JAVA_HOME="/usr/lib/jvm/zulu17-ca-arm64"
elif [ -d "/usr/lib/jvm/zulu17-ca-amd64" ]; then
    export JAVA_HOME="/usr/lib/jvm/zulu17-ca-amd64"
elif [ -d "/usr/lib/jvm/zulu17" ]; then
    export JAVA_HOME="/usr/lib/jvm/zulu17"
fi

# Prepend Azul Java to PATH (before base image's /opt/java/openjdk)
export PATH="${JAVA_HOME}/bin:${PATH}"

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
    echo "  Jemalloc:           ${JEMALLOC_VERSION:-unknown}"
    echo "  OS:                 ${OS_VERSION:-unknown}"
    echo "  Platform:           ${PLATFORM:-unknown}"
    echo ""
fi

# Set default environment variables if not provided
# These will be picked up by the base image's docker-entrypoint.sh
: ${CASSANDRA_CLUSTER_NAME:=axonopsdb-timeseries}
: ${CASSANDRA_NUM_TOKENS:=8}
: ${CASSANDRA_LISTEN_ADDRESS:=auto}
: ${CASSANDRA_RPC_ADDRESS:=0.0.0.0}
: ${CASSANDRA_DC:=dc1}
: ${CASSANDRA_RACK:=rack1}

# JVM heap settings
: ${CASSANDRA_HEAP_SIZE:=2G}
: ${CASSANDRA_HEAP_NEWSIZE:=512M}

echo "Configuration:"
echo "  Cluster Name:       ${CASSANDRA_CLUSTER_NAME}"
echo "  DC/Rack:            ${CASSANDRA_DC}/${CASSANDRA_RACK}"
echo "  Num Tokens:         ${CASSANDRA_NUM_TOKENS}"
echo "  Listen Address:     ${CASSANDRA_LISTEN_ADDRESS}"
echo "  RPC Address:        ${CASSANDRA_RPC_ADDRESS}"
echo "  Heap Size:          ${CASSANDRA_HEAP_SIZE}"
echo "  Heap New Size:      ${CASSANDRA_HEAP_NEWSIZE}"
echo ""

# Enable jemalloc for memory optimization
if [ -f /usr/lib/x86_64-linux-gnu/libjemalloc.so.2 ]; then
    export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
    echo "✓ jemalloc enabled (x86_64)"
elif [ -f /usr/lib/aarch64-linux-gnu/libjemalloc.so.2 ]; then
    export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so.2
    echo "✓ jemalloc enabled (aarch64)"
else
    echo "⚠ jemalloc not found, continuing without it"
fi

# Set JVM options for Shenandoah GC
export JVM_OPTS="$JVM_OPTS -Xms${CASSANDRA_HEAP_SIZE}"
export JVM_OPTS="$JVM_OPTS -Xmx${CASSANDRA_HEAP_SIZE}"
export JVM_OPTS="$JVM_OPTS -Xmn${CASSANDRA_HEAP_NEWSIZE}"
export JVM_OPTS="$JVM_OPTS -XX:+UseShenandoahGC"
export JVM_OPTS="$JVM_OPTS -XX:+AlwaysPreTouch"

echo ""
echo "=== Starting Cassandra ==="
echo ""

# Execute the original Cassandra entrypoint or command
exec /usr/local/bin/docker-entrypoint.sh "$@"
