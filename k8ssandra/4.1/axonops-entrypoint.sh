#!/bin/bash -x
set -e

touch /var/log/axonops/axon-agent.log

# Enable jemalloc for memory optimization (UBI path)
if [ -f /usr/lib64/libjemalloc.so.2 ]; then
    export LD_PRELOAD=/usr/lib64/libjemalloc.so.2
    echo "✓ jemalloc enabled"
else
    echo "⚠ jemalloc not found, continuing without it"
fi

# Config generation
if [ ! -f /etc/axonops/axon-agent.yml ]; then
cat > /etc/axonops/axon-agent.yml <<END
axon-server:
    hosts: "${AXON_AGENT_HOST:-agents.axonops.cloud}"
    port: ${AXON_AGENT_PORT:-443}
axon-agent:
    org: ${AXON_AGENT_ORG}
END
    if [ -n "${AXON_AGENT_KEY}" ]; then
cat >> /etc/axonops/axon-agent.yml <<END
    key: ${AXON_AGENT_KEY}
END
    fi

    if [ "$AXON_AGENT_TLS_MODE" != "" ]; then
cat >> /etc/axonops/axon-agent.yml <<END
    tls:
      mode: "${AXON_AGENT_TLS_MODE}"
END
    fi

    if [ "$AXON_NTP_HOST" != "" ]; then
cat >> /etc/axonops/axon-agent.yml <<END
NTP:
    hosts:
      - ${AXON_NTP_HOST}
END
    fi
fi

/usr/share/axonops/axon-agent $AXON_AGENT_ARGS | tee /var/log/axonops/axon-agent.log 2>&1 &
/docker-entrypoint.sh mgmtapi &

wait -n
# Exit with status of process that exited first
exit $?
