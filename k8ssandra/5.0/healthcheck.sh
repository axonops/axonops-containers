#!/bin/bash
# Container healthcheck.
#
# With the K8ssandra Management API present, health is its liveness endpoint,
# which is what the K8ssandra Operator itself relies on. Without it (images
# built with INCLUDE_MGMT_API=false) health is Cassandra's own view: the native
# transport must be running and the CQL port must accept connections.

set -o pipefail

MGMT_API_JAR="${MAAC_PATH:-/opt/management-api}/datastax-mgmtapi-server.jar"
CASSANDRA_HOME="${CASSANDRA_HOME:-/opt/cassandra}"
CASSANDRA_CONF="${CASSANDRA_CONF:-${CASSANDRA_HOME}/conf}"

if [ -f "${MGMT_API_JAR}" ]; then
  curl -f "http://localhost:${MGMT_API_LISTEN_TCP_PORT:-8080}/api/v0/probes/liveness" || exit 1
  exit 0
fi

CQL_PORT=$(sed -E '/^native_transport_port:[[:space:]]+[[:digit:]]+[[:space:]]*$/!d; s/^native_transport_port:[[:space:]]+([[:digit:]]+)[[:space:]]*$/\1/' "${CASSANDRA_CONF}/cassandra.yaml" 2>/dev/null)
CQL_PORT="${CQL_PORT:-9042}"

if ! "${CASSANDRA_HOME}/bin/nodetool" statusbinary 2>/dev/null | grep -q "^running$"; then
  echo "unhealthy: native transport is not running"
  exit 1
fi

if ! (ss -ln 2>/dev/null | grep -qE "^tcp .*:${CQL_PORT} .*$"); then
  echo "unhealthy: CQL port ${CQL_PORT} is not accepting connections"
  exit 1
fi

echo "healthy: Cassandra is accepting CQL connections on port ${CQL_PORT}"
exit 0
