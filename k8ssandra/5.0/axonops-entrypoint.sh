#!/bin/bash -x

touch /var/log/axonops/axon-agent.log

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
