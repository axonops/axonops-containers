#!/bin/bash
# Entrypoint for the AxonOps Apache Cassandra image.
#
# Starts Cassandra in the background, waits until it is accepting CQL
# connections, then starts the AxonOps agent under supervision. The container
# lifecycle is tied to the Cassandra process: if Cassandra exits, the container
# exits with the same status.

set -o pipefail

CASSANDRA_HOME="${CASSANDRA_HOME:-/opt/cassandra}"
CASSANDRA_CONF="${CASSANDRA_CONF:-/etc/cassandra}"
AXON_AGENT_LOG="/var/log/axonops/axon-agent.log"

mkdir -p /var/log/axonops
touch "${AXON_AGENT_LOG}" 2>/dev/null || true

# Startup banner - prints version information.
# Designed never to fail: any error inside falls back to a single line.
print_startup_banner() {
  {
    echo "================================================================================"

    if [ -f /etc/axonops/build-info.txt ]; then
      source /etc/axonops/build-info.txt 2>/dev/null || true
    fi

    echo "AxonOps Apache Cassandra ${CASSANDRA_VERSION:-unknown}"
    if [ -n "${CONTAINER_IMAGE}" ] && [ "${CONTAINER_IMAGE}" != "unknown" ]; then
      echo "Image: ${CONTAINER_IMAGE}"
    fi
    if [ -n "${CONTAINER_BUILD_DATE}" ] && [ "${CONTAINER_BUILD_DATE}" != "unknown" ]; then
      echo "Built: ${CONTAINER_BUILD_DATE}"
    fi

    if [ -n "${CONTAINER_GIT_TAG}" ] && [ "${CONTAINER_GIT_TAG}" != "unknown" ]; then
      if [ "${IS_PRODUCTION_RELEASE:-false}" = "true" ]; then
        echo "Release: https://github.com/axonops/axonops-containers/releases/tag/${CONTAINER_GIT_TAG}"
      else
        echo "Tag:     https://github.com/axonops/axonops-containers/tree/${CONTAINER_GIT_TAG}"
      fi
    fi

    if [ -n "${CONTAINER_BUILT_BY}" ] && [ "${CONTAINER_BUILT_BY}" != "unknown" ]; then
      echo "Built by: ${CONTAINER_BUILT_BY}"
    fi

    echo "================================================================================"
    echo ""
    echo "Component Versions:"
    echo "  Cassandra:          ${CASSANDRA_VERSION:-unknown}"
    echo "  Java:               ${JAVA_VERSION:-unknown}"
    echo "  AxonOps Agent:      ${AXON_AGENT_VERSION:-unknown}"
    echo "  AxonOps Java Agent: ${AXON_JAVA_AGENT_VERSION:-unknown}"
    echo "  cqlai:              ${CQLAI_VERSION:-unknown}"
    echo "  jemalloc:           ${JEMALLOC_VERSION:-unknown}"
    echo "  OS:                 ${OS_VERSION:-unknown}"
    echo "  Platform:           ${PLATFORM:-unknown}"
    if [ "${INSTALL_K8SSANDRA_API:-false}" = "true" ]; then
      echo "  K8ssandra API:      ${K8SSANDRA_API_VERSION:-unknown}"
    fi
    echo ""

    echo "Supply Chain Security:"
    echo "  Base image:         registry.access.redhat.com/ubi9/ubi-minimal"
    echo "  Base image digest:  ${UBI9_BASE_DIGEST:-unknown}"
    echo ""

    echo "Runtime Environment:"
    echo "  Hostname:           $(hostname 2>/dev/null || echo 'unknown')"
    if [ -n "${KUBERNETES_SERVICE_HOST}" ]; then
      echo "  Kubernetes:         Yes"
      echo "    API Server:       ${KUBERNETES_SERVICE_HOST:-unknown}:${KUBERNETES_SERVICE_PORT:-unknown}"
      echo "    Pod:              ${HOSTNAME:-unknown}"
    else
      echo "  Kubernetes:         No"
    fi
    echo ""

    echo "AxonOps Configuration:"
    echo "  Server:             ${AXON_AGENT_SERVER_HOST:-agents.axonops.cloud}"
    echo "  Organization:       ${AXON_AGENT_ORG:-not configured}"
    echo "  Agent Key:          $([ -n "${AXON_AGENT_KEY}" ] && echo '***configured***' || echo 'NOT SET')"
    echo ""

    echo "================================================================================"
    echo "Starting Apache Cassandra with the AxonOps agent..."
    echo "================================================================================"
    echo ""
  } || {
    echo "AxonOps Apache Cassandra container starting..." >&2
  }
}

# AxonOps agent configuration is supplied entirely through environment
# variables:
#   AXON_AGENT_SERVER_HOST, AXON_AGENT_SERVER_PORT, AXON_AGENT_NTP_HOST,
#   AXON_AGENT_KEY, AXON_AGENT_ORG, AXON_AGENT_CLUSTER_NAME,
#   AXON_AGENT_TMP_PATH, AXON_AGENT_TLS_MODE
if [ -z "${AXON_AGENT_SERVER_HOST}" ]; then
  export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"
fi
if [ -z "${AXON_AGENT_SERVER_PORT}" ]; then
  export AXON_AGENT_SERVER_PORT="443"
fi
if [ -z "${AXON_AGENT_ORG}" ]; then
  echo "ERROR: AXON_AGENT_ORG environment variable is not set. Exiting." >&2
  exit 1
fi

# The agent refuses to start without a config file, but a mounted one always
# wins.
if [ ! -f /etc/axonops/axon-agent.yml ]; then
  {
    echo "# all agent configurations occur through environment variables"
    echo "cassandra:"
    echo "# intentionally left empty"
  } > /etc/axonops/axon-agent.yml
fi

# Wire the AxonOps Java agent into Cassandra's JVM options. Guarded so a
# restart of the entrypoint cannot append it twice.
if ! grep -q 'axonops-jvm.options' "${CASSANDRA_CONF}/cassandra-env.sh" 2>/dev/null; then
  echo ". /usr/share/axonops/axonops-jvm.options" >> "${CASSANDRA_CONF}/cassandra-env.sh"
fi

# Enable jemalloc for memory optimisation (UBI path).
if [ -f /usr/lib64/libjemalloc.so.2 ]; then
  export LD_PRELOAD=/usr/lib64/libjemalloc.so.2
  echo "jemalloc enabled"
else
  echo "jemalloc not found, continuing without it"
fi

print_startup_banner

# Optional K8ssandra Management API (only present when the image was built with
# INSTALL_K8SSANDRA_API=true).
MGMTAPI_PID=""
MGMTAPI_JAR=$(ls /opt/management-api/datastax-mgmtapi-server*.jar 2>/dev/null | head -1)
if [ -n "${MGMTAPI_JAR}" ]; then
  echo "Starting K8ssandra Management API from ${MGMTAPI_JAR}"
  java -jar "${MGMTAPI_JAR}" \
    --cassandra-home "${CASSANDRA_HOME}" \
    --host "tcp://0.0.0.0:8080" \
    --no-keep-alive &
  MGMTAPI_PID=$!
fi

echo "Starting Apache Cassandra"
"${CASSANDRA_HOME}/bin/cassandra" -f -R &
CASSANDRA_PID=$!

# Wait for Cassandra to accept CQL connections before starting the agent. The
# agent expects a live node and a socket created by the Java agent.
CQL_PORT=$(sed -E '/^native_transport_port:[[:space:]]+[[:digit:]]+[[:space:]]*$/!d; s/^native_transport_port:[[:space:]]+([[:digit:]]+)[[:space:]]*$/\1/' "${CASSANDRA_CONF}/cassandra.yaml")
CQL_PORT="${CQL_PORT:-9042}"
echo "Waiting for Cassandra to start up. Detected CQL port ${CQL_PORT}"

while true; do
  sleep 5
  if ! kill -0 "${CASSANDRA_PID}" 2>/dev/null; then
    echo "Cassandra exited while starting up" >&2
    wait "${CASSANDRA_PID}"
    exit $?
  fi
  if ss -ln | grep -qE "^tcp .*:${CQL_PORT} .*$"; then
    break
  fi
  echo "Waiting for Cassandra to be ready before starting axon-agent..."
done
echo "Cassandra is ready, starting axon-agent"

# Supervise axon-agent: restart on exit, with crash-loop backoff (issue #154).
# Runs backgrounded so the container lifecycle stays tied to Cassandra, not the
# agent. The agent is piped through tee, so its real exit code comes from
# PIPESTATUS.
supervise_axon_agent() {
  local fails=0
  local window
  window=$(date +%s)
  while true; do
    echo "[axonops-supervise] starting axon-agent" | tee -a "${AXON_AGENT_LOG}" 2>/dev/null
    /usr/share/axonops/axon-agent $AXON_AGENT_ARGS 2>&1 | tee -a "${AXON_AGENT_LOG}" 2>/dev/null
    local rc=${PIPESTATUS[0]}
    echo "[axonops-supervise] axon-agent exited rc=${rc}, restarting" | tee -a "${AXON_AGENT_LOG}" 2>/dev/null
    local now
    now=$(date +%s)
    if [ $((now - window)) -gt 60 ]; then
      fails=0
      window=$now
    fi
    fails=$((fails + 1))
    if [ "$fails" -gt 5 ]; then
      echo "[axonops-supervise] >5 restarts in 60s, backing off 30s" | tee -a "${AXON_AGENT_LOG}" 2>/dev/null
      sleep 30
      fails=0
      window=$(date +%s)
    else
      sleep 2
    fi
  done
}

supervise_axon_agent &

# Container lives and dies with Cassandra.
wait "${CASSANDRA_PID}"
CASSANDRA_RC=$?
echo "Cassandra exited with status ${CASSANDRA_RC}"
if [ -n "${MGMTAPI_PID}" ]; then
  kill "${MGMTAPI_PID}" 2>/dev/null || true
fi
exit "${CASSANDRA_RC}"
