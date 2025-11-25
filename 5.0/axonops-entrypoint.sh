#!/bin/bash -x
set -e

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

/usr/share/axonops/axon-agent $AXON_AGENT_ARGS | tee /var/log/axonops/axon-agent.log 2>&1 &
/docker-entrypoint.sh mgmtapi &

wait -n
# Exit with status of process that exited first
exit $?
