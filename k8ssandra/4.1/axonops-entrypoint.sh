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

/usr/share/axonops/axon-agent $AXON_AGENT_ARGS | tee /var/log/axonops/axon-agent.log 2>&1 &
/docker-entrypoint.sh mgmtapi &

wait -n
# Exit with status of process that exited first
exit $?
