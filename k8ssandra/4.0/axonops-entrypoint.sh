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
