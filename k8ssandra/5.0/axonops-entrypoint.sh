#!/bin/bash -x

touch /var/log/axonops/axon-agent.log

# Startup banner function - prints version information
# This function is designed to never fail - all errors are caught
print_startup_banner() {
  {
    echo "================================================================================"

    # Load build info from file (all static versions captured at build time)
    if [ -f /etc/axonops/build-info.txt ]; then
      source /etc/axonops/build-info.txt 2>/dev/null || true
    fi

    # Title
    echo "AxonOps K8ssandra Apache Cassandra ${CASSANDRA_VERSION:-unknown}"
    if [ -n "${CONTAINER_IMAGE}" ] && [ "${CONTAINER_IMAGE}" != "unknown" ] && [ "${CONTAINER_IMAGE}" != "" ]; then
      echo "Image: ${CONTAINER_IMAGE}"
    fi
    if [ -n "${CONTAINER_BUILD_DATE}" ] && [ "${CONTAINER_BUILD_DATE}" != "unknown" ] && [ "${CONTAINER_BUILD_DATE}" != "" ]; then
      echo "Built: ${CONTAINER_BUILD_DATE}"
    fi

    # Show release/tag link if available (CI builds)
    if [ -n "${CONTAINER_GIT_TAG}" ] && [ "${CONTAINER_GIT_TAG}" != "unknown" ] && [ "${CONTAINER_GIT_TAG}" != "" ]; then
      if [ "${IS_PRODUCTION_RELEASE:-false}" = "true" ]; then
        # Production build - link to release page (has release notes)
        echo "Release: https://github.com/axonops/axonops-containers/releases/tag/${CONTAINER_GIT_TAG}"
      else
        # Development build - link to tag/tree
        echo "Tag:     https://github.com/axonops/axonops-containers/tree/${CONTAINER_GIT_TAG}"
      fi
    fi

    # Show who built it if available (CI builds)
    if [ -n "${CONTAINER_BUILT_BY}" ] && [ "${CONTAINER_BUILT_BY}" != "unknown" ] && [ "${CONTAINER_BUILT_BY}" != "" ]; then
      echo "Built by: ${CONTAINER_BUILT_BY}"
    fi

    echo "================================================================================"
    echo ""

    # Component versions (from build-info.txt)
    echo "Component Versions:"
    echo "  Cassandra:          ${CASSANDRA_VERSION:-unknown}"
    echo "  k8ssandra API:      ${K8SSANDRA_API_VERSION:-unknown}"
    echo "  Java:               ${JAVA_VERSION:-unknown}"
    echo "  AxonOps Agent:      ${AXON_AGENT_VERSION:-unknown}"
    echo "  AxonOps Java Agent: ${AXON_JAVA_AGENT_VERSION:-unknown}"
    echo "  cqlai:              ${CQLAI_VERSION:-unknown}"
    echo "  jemalloc:           ${JEMALLOC_VERSION:-unknown}"
    echo "  OS:                 ${OS_VERSION:-unknown}"
    echo "  Platform:           ${PLATFORM:-unknown}"
    echo ""

    # Supply chain verification (digests for security audit)
    echo "Supply Chain Security:"
    echo "  Base image:         k8ssandra/cass-management-api:${CASSANDRA_VERSION:-unknown}-ubi-v${K8SSANDRA_API_VERSION:-unknown}"
    echo "  Base image digest:  ${K8SSANDRA_BASE_DIGEST:-unknown}"
    echo ""

    # Runtime environment (dynamic - only knowable at runtime)
    echo "Runtime Environment:"
    echo "  Hostname:           $(hostname 2>/dev/null || echo 'unknown')"

    # Kubernetes detection (safe - only if vars exist)
    if [ -n "${KUBERNETES_SERVICE_HOST}" ]; then
      echo "  Kubernetes:         Yes"
      echo "    API Server:       ${KUBERNETES_SERVICE_HOST:-unknown}:${KUBERNETES_SERVICE_PORT:-unknown}"
      echo "    Pod:              ${HOSTNAME:-unknown}"
    else
      echo "  Kubernetes:         No"
    fi
    echo ""

    # AxonOps config
    echo "AxonOps Configuration:"
    echo "  Server:             ${AXON_AGENT_HOST:-agents.axonops.cloud}"
    echo "  Organization:       ${AXON_AGENT_ORG:-not configured}"
    echo "  Agent Key:          $([ -n "${AXON_AGENT_KEY}" ] && echo '***configured***' || echo 'NOT SET')"
    echo ""

    echo "================================================================================"
    echo "Starting Cassandra with Management API and AxonOps Agent..."
    echo "================================================================================"
    echo ""
  } || {
    # If banner fails for any reason, print minimal fallback and continue
    echo "AxonOps K8ssandra Container starting..." >&2
  }
}

# AXON_AGENT_SERVER_HOST
# AXON_AGENT_SERVER_PORT
# AXON_AGENT_NTP_HOST
# AXON_AGENT_KEY
# AXON_AGENT_ORG
# AXON_AGENT_CLUSTER_NAME
# AXON_AGENT_TMP_PATH
# AXON_AGENT_TLS_MODE

if [ -z "$AXON_AGENT_SERVER_HOST" ]; then
  AXON_AGENT_SERVER_HOST="agents.axonops.cloud"
fi
if [ -z "$AXON_AGENT_SERVER_PORT" ]; then
  AXON_AGENT_SERVER_PORT="443"
fi
if [ -z "$AXON_AGENT_ORG" ]; then
  echo "ERROR: AXON_AGENT_ORG environment variable is not set. Exiting."
  exit 1
fi

# Ensure the config file exists to avoid axon-agent startup errors
if [ ! -f /etc/axonops/axon-agent.yml ]; then
  touch /etc/axonops/axon-agent.yml
fi

# Add AxonOps JVM options to cassandra-env.sh
echo ". /usr/share/axonops/axonops-jvm.options" >> /opt/cassandra/conf/cassandra-env.sh
# Also add to /config if it exists (K8ssandra operator mounts config here)
if [ -f /config/cassandra-env.sh ]; then
    echo ". /usr/share/axonops/axonops-jvm.options" >> /config/cassandra-env.sh
fi

# Enable jemalloc for memory optimization (UBI path)
if [ -f /usr/lib64/libjemalloc.so.2 ]; then
    export LD_PRELOAD=/usr/lib64/libjemalloc.so.2
    echo "✓ jemalloc enabled"
else
    echo "⚠ jemalloc not found, continuing without it"
fi

# Print startup banner (after config ready, before starting Cassandra)
print_startup_banner

# Start Management API + Cassandra in background
echo "Starting Cassandra management API"
/docker-entrypoint.sh mgmtapi &
MGMTAPI_PID=$!

# Wait for the axonops socket file to appear (created by Java agent)
SOCKET_FILE="/var/lib/axonops/6868681090314641335.socket"
CQL_PORT=$(sed -E '/^native_transport_port:[[:space:]]+[[:digit:]]+[[:space:]]*$/!d; s/^native_transport_port:[[:space:]]+([[:digit:]]+)[[:space:]]*$/\1/' /opt/cassandra/conf/cassandra.yaml)
echo "Waiting for Cassandra to start up. Detected CQL port $CQL_PORT"
while true; do
    echo "Waiting for Cassandra to be ready before starting axon-agent..."
    sleep 5
    # Check if Management API is still running
    if ! kill -0 $MGMTAPI_PID 2>/dev/null; then
        echo "Management API died while waiting for Cassandra to be ready"
        exit 1
    fi
    if [ -S "$SOCKET_FILE" ] && (ss -ln | grep -qE "^tcp .*:$CQL_PORT .*$"); then
      break
    fi
done
echo "Cassandra is ready, starting axon-agent"

# Start axon-agent in background
/usr/share/axonops/axon-agent $AXON_AGENT_ARGS 2>&1 | tee /var/log/axonops/axon-agent.log &

# Wait on Management API process to keep container running
wait $MGMTAPI_PID
