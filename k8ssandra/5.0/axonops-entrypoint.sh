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

    # Title with all key versions
    echo "AxonOps K8ssandra Apache Cassandra ${CASSANDRA_VERSION:-unknown} + ${AXON_AGENT_VERSION:-unknown}"
    echo "Container v${CONTAINER_VERSION:-unknown} (git: ${CONTAINER_REVISION:-unknown})"
    echo "================================================================================"
    echo ""

    # Component versions (from build-info.txt)
    echo "Component Versions:"
    echo "  Cassandra:          ${CASSANDRA_VERSION:-unknown}"
    echo "  Java:               ${JAVA_VERSION:-unknown}"
    echo "  AxonOps Agent:      ${AXON_AGENT_VERSION:-unknown}"
    echo "  AxonOps Java Agent: ${AXON_JAVA_AGENT_VERSION:-unknown}"
    echo "  cqlai:              ${CQLAI_VERSION:-unknown}"
    echo "  jemalloc:           ${JEMALLOC_VERSION:-unknown}"
    echo "  OS:                 ${OS_VERSION:-unknown}"
    echo "  Platform:           ${PLATFORM:-unknown}"
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

# Config generation
if [ ! -f /etc/axonops/axon-agent.yml ]; then
cat > /etc/axonops/axon-agent.yml <<END
axon-server:
    hosts: "${AXON_AGENT_HOST:-agents.axonops.cloud}"
axon-agent:
    key: ${AXON_AGENT_KEY}
    org: ${AXON_AGENT_ORG}
END
    if [ "$AXON_NTP_HOST" != "" ]; then
cat >> /etc/axonops/axon-agent.yml <<END
NTP:
    hosts:
      - ${AXON_NTP_HOST}
END
    fi
fi

# Add AxonOps JVM options to cassandra-env.sh
echo ". /usr/share/axonops/axonops-jvm.options" >> /opt/cassandra/conf/cassandra-env.sh
echo ". /usr/share/axonops/axonops-jvm.options" >> /config/cassandra-env.sh

# Print startup banner (after config ready, before starting Cassandra)
print_startup_banner

# Start Management API + Cassandra in background
/docker-entrypoint.sh mgmtapi &
MGMTAPI_PID=$!

# Wait for the axonops socket file to appear (created by Java agent)
SOCKET_FILE="/var/lib/axonops/6868681090314641335.socket"
echo "Waiting for socket file: $SOCKET_FILE"
while [ ! -S "$SOCKET_FILE" ]; do
    sleep 1
    # Check if Management API is still running
    if ! kill -0 $MGMTAPI_PID 2>/dev/null; then
        echo "Management API died while waiting for socket file"
        exit 1
    fi
done
echo "Socket file found, starting axon-agent"

# Start axon-agent in background
/usr/share/axonops/axon-agent $AXON_AGENT_ARGS 2>&1 | tee /var/log/axonops/axon-agent.log &

# Wait on Management API process to keep container running
wait $MGMTAPI_PID
