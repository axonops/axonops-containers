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

# Paths and timings of the processes this script starts. Overridable so that
# k8ssandra/tests/entrypoint-stop.test.sh can run the script with stand-ins;
# nothing in the image sets them.
MGMT_API_ENTRYPOINT="${MGMT_API_ENTRYPOINT:-/docker-entrypoint.sh}"
AXON_AGENT_BIN="${AXON_AGENT_BIN:-/usr/share/axonops/axon-agent}"
AXON_AGENT_LOG="${AXON_AGENT_LOG:-/var/log/axonops/axon-agent.log}"
AXONOPS_SOCKET_FILE="${AXONOPS_SOCKET_FILE:-/var/lib/axonops/6868681090314641335.socket}"
AXONOPS_READY_POLL_SECONDS="${AXONOPS_READY_POLL_SECONDS:-5}"
case "$AXONOPS_READY_POLL_SECONDS" in
  ''|*[!0-9.]*|.|*.*.*) AXONOPS_READY_POLL_SECONDS=5 ;;
esac

touch "$AXON_AGENT_LOG"

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

# Default the NTP host used for clock-skew checks.
#
# The agent auto-detects the host's NTP configuration, but that does not work
# inside Kubernetes: the container has no ntp.conf/chrony.conf to read. Without
# this default the agent falls back to a public NTP pool of its own choosing,
# which is almost never the NTP source the Cassandra nodes actually use. Set an
# explicit default here and say so loudly, so an unconfigured deployment is
# visible in the container logs.
if [ -z "$AXON_AGENT_NTP_HOST" ]; then
  export AXON_AGENT_NTP_HOST="pool.ntp.org"
  echo "WARNING: AXON_AGENT_NTP_HOST is not set, defaulting to ${AXON_AGENT_NTP_HOST}."
  echo "WARNING: Clock-skew checks will use a public NTP pool, which is unlikely to be the NTP source your Cassandra hosts use."
  echo "WARNING: Set AXON_AGENT_NTP_HOST to your own NTP server, e.g. AXON_AGENT_NTP_HOST=10.0.0.1:123 (port defaults to 123)."
else
  case "$AXON_AGENT_NTP_HOST" in
    *:*)
      _ntp_port="${AXON_AGENT_NTP_HOST##*:}"
      case "$_ntp_port" in
        ''|*[!0-9]*)
          echo "WARNING: AXON_AGENT_NTP_HOST='${AXON_AGENT_NTP_HOST}' has a non-numeric port. Expected host or host:port, e.g. 10.0.0.1:123."
          ;;
        *)
          if [ "$_ntp_port" -lt 1 ] || [ "$_ntp_port" -gt 65535 ]; then
            echo "WARNING: AXON_AGENT_NTP_HOST='${AXON_AGENT_NTP_HOST}' has an out-of-range port. Expected 1-65535."
          fi
          ;;
      esac
      unset _ntp_port
      ;;
  esac
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

# Add AxonOps JVM options to cassandra-env.sh.
#
# Appended only once. Normally the file is part of the image layer and starts
# clean on every container, but cassandra-env.sh is often bind-mounted from the
# host or from a volume, in which case the append survives the container and a
# plain >> would add another identical line on every restart.
_add_axonops_jvm_options() {
  local env_file="$1"
  local source_line=". /usr/share/axonops/axonops-jvm.options"
  [ -f "$env_file" ] || return 0
  if grep -qF "$source_line" "$env_file"; then
    return 0
  fi
  echo "$source_line" >> "$env_file"
}

_add_axonops_jvm_options /opt/cassandra/conf/cassandra-env.sh
# Also add to /config if it exists (K8ssandra operator mounts config here)
_add_axonops_jvm_options /config/cassandra-env.sh

# CVE-2026-114938 mitigation: disable the Base64 intrinsics. Skipped on JVMs
# that do not know the flag, since an unknown -XX option aborts startup.
_add_base64_mitigation() {
  local env_file="$1"
  local line='JVM_OPTS="$JVM_OPTS -XX:-UseBASE64Intrinsics"'
  [ -f "$env_file" ] || return 0
  grep -qF "$line" "$env_file" && return 0
  echo "$line" >> "$env_file"
}

if java -XX:+PrintFlagsFinal -version 2>/dev/null | grep -q UseBASE64Intrinsics; then
  _add_base64_mitigation /opt/cassandra/conf/cassandra-env.sh
  _add_base64_mitigation /config/cassandra-env.sh
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

# Stop handling.
#
# The image inherits ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
# from cass-management-api, so on `docker stop` or pod deletion tini sends
# SIGTERM to this script's whole process group: this shell, the Management API,
# Cassandra (which the Management API starts as a daemon in the same group) and
# the axon-agent supervisor. Without a trap this shell died at once, tini exited
# with it, and the kernel SIGKILLed Cassandra in the middle of its shutdown.
# When this script is PID 1 instead (an entrypoint or `command:` override, no
# tini), bash ignores SIGTERM without a trap and nothing was stopped until the
# runtime's SIGKILL.
#
# So: on SIGTERM or SIGINT, send SIGTERM to the whole process group ourselves
# (idempotent when tini already did), then wait for the main process and for
# every other process in the group, Cassandra included, before exiting with the
# main process's status. SIGINT is sent on as SIGTERM: processes started in the
# background by a non-interactive shell ignore SIGINT, so the JVMs would never
# see it. cass-operator's preStop drain runs before any of this and is not
# affected. SIGQUIT is left alone: bash ignores it, and for a JVM it means a
# thread dump, not a stop. A second stop signal does not escalate: the
# runtime's SIGKILL at the end of its grace period bounds the wait. The script
# relies on being its process group's leader, as it is under tini, as PID 1,
# and under `docker run --init`.
STOP_SIGNAL=""
STOP_SIGNALS_SEEN=0
_on_stop_signal() {
  STOP_SIGNALS_SEEN=$((STOP_SIGNALS_SEEN + 1))
  if [ -n "$STOP_SIGNAL" ]; then
    return
  fi
  STOP_SIGNAL="$1"
  echo "Received SIG${STOP_SIGNAL}, stopping Cassandra and axon-agent"
  # Our own copy of the signal, and any repeat, returns above. The trap is
  # kept rather than set to ignore, because an ignored signal would be
  # inherited by anything started after this point and could not stop it.
  kill -TERM 0 2>/dev/null
}
trap '_on_stop_signal TERM' TERM
trap '_on_stop_signal INT' INT

# Waits for the main process and sets MAIN_RC to its own exit status. A trapped
# signal interrupts `wait` with a status above 128; when that happens while the
# process is still running, wait again. If it exited at that same instant, a
# second `wait` returns the status bash saved for it (127 only if there is none).
MAIN_REAPED=""
_wait_main() {
  local rc again seen
  [ -n "$MAIN_REAPED" ] && return 0
  while :; do
    seen=$STOP_SIGNALS_SEEN
    wait "$MAIN_PID"
    rc=$?
    if [ "$seen" -ne "$STOP_SIGNALS_SEEN" ]; then
      if kill -0 "$MAIN_PID" 2>/dev/null; then
        continue
      fi
      wait "$MAIN_PID" 2>/dev/null
      again=$?
      [ "$again" -ne 127 ] && rc=$again
    fi
    MAIN_RC=$rc
    MAIN_REAPED=1
    return 0
  done
}

# Prints the live (non-zombie) processes in this shell's process group other
# than this shell and the subshell running this function ($BASHPID, when it
# is called in a command substitution).
_group_members() {
  local stat p my_pgrp
  read -r stat < "/proc/$$/stat" || return 0
  # Fields after "pid (comm) ": state ppid pgrp ...; comm may contain spaces.
  # shellcheck disable=SC2086 # split into fields on purpose; no glob characters
  set -- ${stat##*) }
  my_pgrp="$3"
  for p in /proc/[0-9]*; do
    { [ "${p#/proc/}" = "$$" ] || [ "${p#/proc/}" = "$BASHPID" ]; } && continue
    read -r stat 2>/dev/null < "$p/stat" || continue
    # shellcheck disable=SC2086
    set -- ${stat##*) }
    if [ "$3" = "$my_pgrp" ] && [ "$1" != "Z" ]; then
      echo "${p#/proc/}"
    fi
  done
}

# After a stop signal: wait until everything that got it has exited. With the
# Management API, Cassandra is not this shell's child and can only be waited
# for this way. The runtime's grace period (Kubernetes
# terminationGracePeriodSeconds, `docker stop -t`) still bounds the wait.
#
# A process that joins the group after the signal (Cassandra still being
# spawned by the Management API, or restarted by its keep-alive) never got it,
# so every member is sent SIGTERM once more the first time it is seen here.
_wait_for_group() {
  local members pid signalled=" " reported=""
  while :; do
    members="$(_group_members)"
    [ -z "$members" ] && return 0
    for pid in $members; do
      case "$signalled" in
        *" $pid "*) ;;
        *)
          kill -TERM "$pid" 2>/dev/null
          signalled="$signalled$pid "
          ;;
      esac
    done
    if [ -z "$reported" ]; then
      echo "Waiting for $(echo "$members" | wc -l | tr -d ' ') process(es) to finish shutting down"
      reported=1
    fi
    sleep 0.5
  done
}

# Stops the agent supervisor (and through it axon-agent) when the main process
# exits on its own.
_stop_agent_supervisor() {
  [ -n "${SUPERVISOR_PID:-}" ] || return 0
  kill -TERM "$SUPERVISOR_PID" 2>/dev/null
  wait "$SUPERVISOR_PID" 2>/dev/null
}

# Ends the script after a stop signal.
_finish_stop() {
  # The main process may have been started after the group signal was sent
  [ -n "$MAIN_REAPED" ] || kill -TERM "$MAIN_PID" 2>/dev/null
  _wait_main
  _wait_for_group
  echo "${MAIN_PROCESS} stopped with status ${MAIN_RC}"
  exit "$MAIN_RC"
}

# Print startup banner (after config ready, before starting Cassandra)
print_startup_banner

# A stop signal during the setup above: nothing has been started yet.
if [ -n "$STOP_SIGNAL" ]; then
  echo "Stopped before Cassandra was started"
  exit 143
fi

# Start Cassandra in the background. With the Management API present it is
# started by the upstream entrypoint, which stays in the foreground as the
# process the container tracks; without it, Cassandra itself is that process.
if [ -f "${MGMT_API_JAR}" ]; then
  echo "Starting Cassandra management API"
  "$MGMT_API_ENTRYPOINT" mgmtapi &
  MAIN_PID=$!
  MAIN_PROCESS="Management API"
else
  configure_cassandra_from_env
  if [ -n "$STOP_SIGNAL" ]; then
    echo "Stopped before Cassandra was started"
    exit 143
  fi
  echo "Starting Cassandra"
  "${CASSANDRA_HOME}/bin/cassandra" -f -R &
  MAIN_PID=$!
  MAIN_PROCESS="Cassandra"
fi

# Wait for the axonops socket file to appear (created by Java agent)
SOCKET_FILE="$AXONOPS_SOCKET_FILE"
CQL_PORT=$(sed -E '/^native_transport_port:[[:space:]]+[[:digit:]]+[[:space:]]*$/!d; s/^native_transport_port:[[:space:]]+([[:digit:]]+)[[:space:]]*$/\1/' "${CASSANDRA_CONF}/cassandra.yaml")
CQL_PORT="${CQL_PORT:-9042}"
echo "Waiting for Cassandra to start up. Detected CQL port $CQL_PORT"
while true; do
    echo "Waiting for Cassandra to be ready before starting axon-agent..."
    # In the background so a stop signal is handled at once, not after the sleep
    sleep "$AXONOPS_READY_POLL_SECONDS" &
    wait $!
    if [ -n "$STOP_SIGNAL" ]; then
      _finish_stop
    fi
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
# Management API, not the agent. On SIGTERM it stops the agent and does not
# restart it. The agent runs in the background and is waited for, so the
# signal is handled at once; its output goes through tee by process
# substitution, so $! and the wait status are the agent's own.
supervise_axon_agent() {
  local log="$AXON_AGENT_LOG"
  local fails=0
  local window now rc
  local stopping=0 agent_pid="" pause_pid=""
  trap 'stopping=1; kill -TERM $agent_pid $pause_pid 2>/dev/null' TERM
  window=$(date +%s)
  while [ "$stopping" -eq 0 ]; do
    echo "[axonops-supervise] starting axon-agent" | tee -a "$log" 2>/dev/null
    # shellcheck disable=SC2086 # AXON_AGENT_ARGS is a list of arguments
    # tee ignores SIGTERM and ends when the agent closes its output, so the
    # agent's own shutdown messages are still logged after a group SIGTERM.
    "$AXON_AGENT_BIN" $AXON_AGENT_ARGS > >(trap '' TERM; exec tee -a "$log" 2>/dev/null) 2>&1 &
    agent_pid=$!
    # A SIGTERM that arrived just before the fork did not reach the agent
    [ "$stopping" -eq 0 ] || kill -TERM "$agent_pid" 2>/dev/null
    wait "$agent_pid"
    rc=$?
    while kill -0 "$agent_pid" 2>/dev/null; do
      wait "$agent_pid"
      rc=$?
    done
    agent_pid=""
    [ "$stopping" -eq 0 ] || break
    echo "[axonops-supervise] axon-agent exited rc=${rc}, restarting" | tee -a "$log" 2>/dev/null
    now=$(date +%s)
    if [ $((now - window)) -gt 60 ]; then
      fails=0
      window=$now
    fi
    fails=$((fails + 1))
    if [ "$fails" -gt 5 ]; then
      echo "[axonops-supervise] >5 restarts in 60s, backing off 30s" | tee -a "$log" 2>/dev/null
      sleep 30 &
      pause_pid=$!
      [ "$stopping" -eq 0 ] || kill -TERM "$pause_pid" 2>/dev/null
      wait "$pause_pid"
      pause_pid=""
      fails=0
      window=$(date +%s)
    else
      sleep 2 &
      pause_pid=$!
      [ "$stopping" -eq 0 ] || kill -TERM "$pause_pid" 2>/dev/null
      wait "$pause_pid"
      pause_pid=""
    fi
  done
  echo "[axonops-supervise] stopping, axon-agent will not be restarted" | tee -a "$log" 2>/dev/null
  # Let the last tee finish writing the agent's output
  wait
}

# Start axon-agent under supervision in the background, unless a stop signal
# arrived after the last check in the readiness loop
if [ -n "$STOP_SIGNAL" ]; then
  _finish_stop
fi
supervise_axon_agent &
SUPERVISOR_PID=$!

# Wait on the tracked process to keep the container running: the Management API
# when it is installed, Cassandra itself when it is not.
_wait_main
if [ -n "$STOP_SIGNAL" ]; then
  _finish_stop
fi
echo "${MAIN_PROCESS} exited with status ${MAIN_RC}"
_stop_agent_supervisor
exit "$MAIN_RC"
