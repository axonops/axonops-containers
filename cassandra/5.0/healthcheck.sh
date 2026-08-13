#!/bin/bash
# Container healthcheck: the node is healthy when Cassandra reports itself as
# up and normal and the CQL port is accepting connections.

set -o pipefail

CASSANDRA_HOME="${CASSANDRA_HOME:-/opt/cassandra}"
CASSANDRA_CONF="${CASSANDRA_CONF:-/etc/cassandra}"

CQL_PORT=$(sed -E '/^native_transport_port:[[:space:]]+[[:digit:]]+[[:space:]]*$/!d; s/^native_transport_port:[[:space:]]+([[:digit:]]+)[[:space:]]*$/\1/' "${CASSANDRA_CONF}/cassandra.yaml" 2>/dev/null)
CQL_PORT="${CQL_PORT:-9042}"

if ! "${CASSANDRA_HOME}/bin/nodetool" statusbinary 2>/dev/null | grep -q "^running$"; then
  echo "unhealthy: native transport is not running"
  exit 1
fi

if ! nc -z 127.0.0.1 "${CQL_PORT}" 2>/dev/null; then
  echo "unhealthy: CQL port ${CQL_PORT} is not accepting connections"
  exit 1
fi

echo "healthy: Cassandra is accepting CQL connections on port ${CQL_PORT}"
exit 0
