#!/bin/bash

touch /var/log/axonops/axon-agent.log

cat > /etc/axonops/axon-agent.yml <<END
axon-server:
    hosts: "${AXON_AGENT_HOST:-agents.axonops.cloud}"
axon-agent:
    key: ${AXON_AGENT_KEY}
    org: ${AXON_AGENT_ORG}
END

/usr/share/axonops/axon-agent -v 1 $AXON_AGENT_ARGS > /var/log/axonops/axon-agent.log 2>&1 &

exec /tini -g -- /docker-entrypoint.sh mgmtapi
