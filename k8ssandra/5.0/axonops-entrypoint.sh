#!/bin/bash
#
# This entrypoint serves two images built from the same Dockerfile:
#
#   INCLUDE_MGMT_API=true  - the K8ssandra image. Cassandra is started by the
#     upstream Management API entrypoint, which also applies the CASSANDRA_*
#     environment variables to the configuration.
#   INCLUDE_MGMT_API=false - the standalone ghcr.io/axonops/cassandra/cassandra
#     image. The Management API is not in the image, so this script applies the
#     same CASSANDRA_* environment variables itself and starts Cassandra
#     directly.
#
# The branch is taken on whether the Management API server jar exists, not on a
# build argument, so a stripped image can never try to start an API it does not
# have.

MGMT_API_JAR="${MAAC_PATH:-/opt/management-api}/datastax-mgmtapi-server.jar"
CASSANDRA_HOME="${CASSANDRA_HOME:-/opt/cassandra}"
CASSANDRA_CONF="${CASSANDRA_CONF:-${CASSANDRA_HOME}/conf}"

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
    if [ -f "${MGMT_API_JAR}" ]; then
      echo "  k8ssandra API:      ${K8SSANDRA_API_VERSION:-unknown}"
    else
      echo "  k8ssandra API:      not installed"
    fi
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
    echo "  Server:             ${AXON_AGENT_SERVER_HOST:-agents.axonops.cloud}"
    echo "  Organization:       ${AXON_AGENT_ORG:-not configured}"
    echo "  Agent Key:          $([ -n "${AXON_AGENT_KEY}" ] && echo '***configured***' || echo 'NOT SET')"
    echo ""

    echo "================================================================================"
    if [ -f "${MGMT_API_JAR}" ]; then
      echo "Starting Cassandra with Management API and AxonOps Agent..."
    else
      echo "Starting Cassandra with AxonOps Agent..."
    fi
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
  export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"
fi
if [ -z "$AXON_AGENT_SERVER_PORT" ]; then
  export AXON_AGENT_SERVER_PORT="443"
fi
if [ -z "$AXON_AGENT_ORG" ]; then
  echo "ERROR: AXON_AGENT_ORG environment variable is not set. Exiting."
  exit 1
fi

# Ensure the config file exists to avoid axon-agent startup errors
# But do not overwrite if it already exists (e.g., mounted config)
if [ ! -f /etc/axonops/axon-agent.yml ]; then
  echo "# all agent configurations occur through environment variables" > /etc/axonops/axon-agent.yml
  echo "cassandra:" >> /etc/axonops/axon-agent.yml
  echo "# intentionally left empty" >> /etc/axonops/axon-agent.yml
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

# Apply the CASSANDRA_* environment variables to the configuration.
#
# Only used when the Management API is absent. With the API present the upstream
# entrypoint does this itself, and doing it twice would fight with it. The
# behaviour deliberately mirrors the upstream entrypoint and the official
# Cassandra image, so the environment variable interface is the same in both.
_ip_address() {
  ip address | awk '
    $1 == "inet" && $NF != "lo" {
      gsub(/\/.+$/, "", $2)
      print $2
      exit
    }
  '
}

# sed -i without mv, so it works on bind-mounted files
_sed_in_place() {
  local filename="$1"; shift
  local temp_file
  temp_file="$(mktemp)"
  sed "$@" "$filename" > "$temp_file"
  cat "$temp_file" > "$filename"
  rm -f "$temp_file"
}

configure_cassandra_from_env() {
  # Mounted configuration wins over anything set here
  if [ -d /config ] && ! [ /config -ef "${CASSANDRA_CONF}" ]; then
    cp -R /config/* "${CASSANDRA_CONF}"
  fi

  : "${CASSANDRA_RPC_ADDRESS:=0.0.0.0}"
  : "${CASSANDRA_LISTEN_ADDRESS:=auto}"
  if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
    CASSANDRA_LISTEN_ADDRESS="$(_ip_address)"
  fi

  : "${CASSANDRA_BROADCAST_ADDRESS:=$CASSANDRA_LISTEN_ADDRESS}"
  if [ "$CASSANDRA_BROADCAST_ADDRESS" = 'auto' ]; then
    CASSANDRA_BROADCAST_ADDRESS="$(_ip_address)"
  fi
  : "${CASSANDRA_BROADCAST_RPC_ADDRESS:=$CASSANDRA_BROADCAST_ADDRESS}"
  : "${CASSANDRA_SEEDS:=$CASSANDRA_BROADCAST_ADDRESS}"

  _sed_in_place "${CASSANDRA_CONF}/cassandra.yaml" \
    -r 's/(- seeds:).*/\1 "'"$CASSANDRA_SEEDS"'"/'

  for yaml in \
    authenticator \
    authorizer \
    broadcast_address \
    broadcast_rpc_address \
    cluster_name \
    endpoint_snitch \
    listen_address \
    native_transport_port \
    num_tokens \
    role_manager \
    rpc_address \
  ; do
    var="CASSANDRA_${yaml^^}"
    val="${!var}"
    if [ "$val" ]; then
      _sed_in_place "${CASSANDRA_CONF}/cassandra.yaml" \
        -r 's/^(# )?('"$yaml"':).*/\2 '"$val"'/'
    fi
  done

  for rackdc in dc rack; do
    var="CASSANDRA_${rackdc^^}"
    val="${!var}"
    if [ "$val" ]; then
      _sed_in_place "${CASSANDRA_CONF}/cassandra-rackdc.properties" \
        -r 's/^('"$rackdc"'=).*/\1 '"$val"'/'
    fi
  done

  echo "Cassandra configured: seeds=${CASSANDRA_SEEDS} listen=${CASSANDRA_LISTEN_ADDRESS} rpc=${CASSANDRA_RPC_ADDRESS} dc=${CASSANDRA_DC:-default} rack=${CASSANDRA_RACK:-default} authenticator=${CASSANDRA_AUTHENTICATOR:-AllowAllAuthenticator} authorizer=${CASSANDRA_AUTHORIZER:-AllowAllAuthorizer}"
}

# Print startup banner (after config ready, before starting Cassandra)
print_startup_banner

# Start Cassandra in the background. With the Management API present it is
# started by the upstream entrypoint, which stays in the foreground as the
# process the container tracks; without it, Cassandra itself is that process.
if [ -f "${MGMT_API_JAR}" ]; then
  echo "Starting Cassandra management API"
  /docker-entrypoint.sh mgmtapi &
  MAIN_PID=$!
  MAIN_PROCESS="Management API"
else
  configure_cassandra_from_env
  echo "Starting Cassandra"
  "${CASSANDRA_HOME}/bin/cassandra" -f -R &
  MAIN_PID=$!
  MAIN_PROCESS="Cassandra"
fi

# Wait for the axonops socket file to appear (created by Java agent)
SOCKET_FILE="/var/lib/axonops/6868681090314641335.socket"
CQL_PORT=$(sed -E '/^native_transport_port:[[:space:]]+[[:digit:]]+[[:space:]]*$/!d; s/^native_transport_port:[[:space:]]+([[:digit:]]+)[[:space:]]*$/\1/' "${CASSANDRA_CONF}/cassandra.yaml")
CQL_PORT="${CQL_PORT:-9042}"
echo "Waiting for Cassandra to start up. Detected CQL port $CQL_PORT"
while true; do
    echo "Waiting for Cassandra to be ready before starting axon-agent..."
    sleep 5
    # Check the process the container tracks is still running
    if ! kill -0 $MAIN_PID 2>/dev/null; then
        echo "${MAIN_PROCESS} died while waiting for Cassandra to be ready"
        wait $MAIN_PID
        exit $?
    fi
    if [ -S "$SOCKET_FILE" ] && (ss -ln | grep -qE "^tcp .*:$CQL_PORT .*$"); then
      break
    fi
done
echo "Cassandra is ready, starting axon-agent"

# Supervise axon-agent: restart forever on exit, with crash-loop backoff (issue #154).
# Runs as a backgrounded subshell so the container lifecycle stays tied to the
# Management API, not the agent. The agent is piped through tee, so its real exit
# code is read from PIPESTATUS, not $?.
supervise_axon_agent() {
  local log="/var/log/axonops/axon-agent.log"
  local fails=0
  local window
  window=$(date +%s)
  while true; do
    echo "[axonops-supervise] starting axon-agent" | tee -a "$log" 2>/dev/null
    /usr/share/axonops/axon-agent $AXON_AGENT_ARGS 2>&1 | tee -a "$log" 2>/dev/null
    local rc=${PIPESTATUS[0]}
    echo "[axonops-supervise] axon-agent exited rc=${rc}, restarting" | tee -a "$log" 2>/dev/null
    local now
    now=$(date +%s)
    if [ $((now - window)) -gt 60 ]; then
      fails=0
      window=$now
    fi
    fails=$((fails + 1))
    if [ "$fails" -gt 5 ]; then
      echo "[axonops-supervise] >5 restarts in 60s, backing off 30s" | tee -a "$log" 2>/dev/null
      sleep 30
      fails=0
      window=$(date +%s)
    else
      sleep 2
    fi
  done
}

# Start axon-agent under supervision in the background
supervise_axon_agent &

# Wait on the tracked process to keep the container running: the Management API
# when it is installed, Cassandra itself when it is not.
wait $MAIN_PID
MAIN_RC=$?
echo "${MAIN_PROCESS} exited with status ${MAIN_RC}"
exit $MAIN_RC
