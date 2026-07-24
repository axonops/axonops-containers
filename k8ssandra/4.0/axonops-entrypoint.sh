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

supervise_axon_agent &

/docker-entrypoint.sh mgmtapi &
MGMTAPI_PID=$!

# Keep the container tied to the Management API; exit with its status when it dies.
wait "$MGMTAPI_PID"
exit $?
