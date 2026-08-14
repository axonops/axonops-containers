#!/bin/bash
# Container healthcheck.
#
# Two things have to be right for this container to be doing its job: Cassandra
# has to be serving, and the AxonOps agent has to be running so the node is
# actually monitored.
#
# Cassandra health:
#   With the K8ssandra Management API present, health is its liveness endpoint,
#   which is what the K8ssandra Operator itself relies on. Without it (images
#   built with INCLUDE_MGMT_API=false) health is Cassandra's own view: the native
#   transport must be running and the CQL port must accept connections.
#
# Agent health:
#   The axon-agent process must be running. It is started by the entrypoint only
#   once Cassandra is up, and supervised with restart-on-exit, so a missing
#   process means the supervisor is gone or the agent is between restarts.
#
#   Whether a dead agent makes the container unhealthy is a deployment decision,
#   not ours: Cassandra is still serving CQL, and failing the healthcheck can
#   make an orchestrator restart or drain a node that is doing useful work.
#   HEALTHCHECK_REQUIRE_AGENT=true opts in to treating it as a failure. The
#   default reports the agent as down but exits on Cassandra's status alone.

set -o pipefail

MGMT_API_JAR="${MAAC_PATH:-/opt/management-api}/datastax-mgmtapi-server.jar"
CASSANDRA_HOME="${CASSANDRA_HOME:-/opt/cassandra}"
CASSANDRA_CONF="${CASSANDRA_CONF:-${CASSANDRA_HOME}/conf}"
AXON_AGENT_BIN="${AXON_AGENT_BIN:-/usr/share/axonops/axon-agent}"
REQUIRE_AGENT="${HEALTHCHECK_REQUIRE_AGENT:-false}"

# Is axon-agent running?
#
# /proc is walked directly rather than using pgrep, which is not guaranteed to be
# installed in the UBI base image. Only the command line is matched, so a process
# started under a different path (AXON_AGENT_BIN) is still found.
agent_running() {
  local proc cmdline
  for proc in /proc/[0-9]*; do
    [ -r "${proc}/cmdline" ] || continue
    cmdline=$(tr '\0' ' ' < "${proc}/cmdline" 2>/dev/null) || continue
    case "${cmdline}" in
      *"${AXON_AGENT_BIN}"*) return 0 ;;
    esac
  done
  return 1
}

cassandra_healthy() {
  local port="${MGMT_API_LISTEN_TCP_PORT:-8080}"
  if [ -f "${MGMT_API_JAR}" ]; then
    if ! curl -f "http://localhost:${port}/api/v0/probes/liveness"; then
      echo "unhealthy: Management API liveness probe failed on port ${port}"
      return 1
    fi
    echo "healthy: Management API liveness probe passed"
    return 0
  fi

  local cql_port
  cql_port=$(sed -E '/^native_transport_port:[[:space:]]+[[:digit:]]+[[:space:]]*$/!d; s/^native_transport_port:[[:space:]]+([[:digit:]]+)[[:space:]]*$/\1/' "${CASSANDRA_CONF}/cassandra.yaml" 2>/dev/null)
  cql_port="${cql_port:-9042}"

  if ! "${CASSANDRA_HOME}/bin/nodetool" statusbinary 2>/dev/null | grep -q "^running$"; then
    echo "unhealthy: native transport is not running"
    return 1
  fi

  if ! (ss -ln 2>/dev/null | grep -qE "^tcp .*:${cql_port} .*$"); then
    echo "unhealthy: CQL port ${cql_port} is not accepting connections"
    return 1
  fi

  echo "healthy: Cassandra is accepting CQL connections on port ${cql_port}"
  return 0
}

rc=0

if ! cassandra_healthy; then
  rc=1
fi

if agent_running; then
  echo "healthy: axon-agent is running"
else
  if [ "${REQUIRE_AGENT}" = "true" ]; then
    echo "unhealthy: axon-agent is not running"
    rc=1
  else
    echo "warning: axon-agent is not running, this node is not being monitored (set HEALTHCHECK_REQUIRE_AGENT=true to fail on this)"
  fi
fi

exit $rc
