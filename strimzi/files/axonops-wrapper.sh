#!/usr/bin/env bash

echo "Starting axonops services"

AGENT_ARGS="${AXONOPS_AGENT_ARGS:-''}"

# Find the agent jar
KAFKA_AGENT_JAR=$(ls -1 /usr/share/axonops/axon-kafka*-agent.jar 2>/dev/null)

# Handle the config link and initial javaagent flag
if [ -f /mnt/axon-agent.yml ]; then
  ln -sf /mnt/axon-agent.yml /etc/axonops/axon-agent.yml
  KAFKA_OPTS="${KAFKA_OPTS} -javaagent:${KAFKA_AGENT_JAR}=/etc/axonops/axon-agent.yml"
else
  KAFKA_OPTS="${KAFKA_OPTS} -javaagent:${KAFKA_AGENT_JAR}"
fi

# Append the required Java 11+ modularity flags to KAFKA_OPTS
export KAFKA_OPTS="${KAFKA_OPTS} \
  --add-exports=java.base/sun.nio.ch=ALL-UNNAMED \
  --add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
  --add-exports=jdk.unsupported/sun.misc=ALL-UNNAMED \
  --add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED \
  --add-exports=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED \
  --add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED \
  --add-opens=java.management/com.sun.jmx.mbeanserver=ALL-UNNAMED \
  --add-exports=java.management/com.sun.jmx.mbeanserver=ALL-UNNAMED \
  --add-opens=java.management/com.sun.jmx.interceptor=ALL-UNNAMED \
  --add-exports=java.management/com.sun.jmx.interceptor=ALL-UNNAMED"

# Move /var/lib/axonops to a persistent directory
logDir=$(grep log.dirs /tmp/strimzi.properties | awk -F = '{print $2}')

if [ -n "$logDir" ]; then
  if [ -d "${logDir}" ] && [ ! -f /var/lib/axonops/local.db ]; then
    cp -a /var/lib/axonops-template /var/lib/kafka/data-0/axonops
  fi
fi

# connect nodes won't use /var/lib/kafka/data-0/axonops so need to explicitly set agent_service
if [ "$KAFKA_NODE_TYPE" = "connect" ]; then
    echo "kafka" > /var/lib/axonops/agent_service
fi

# strimzi logs controller logs as server.log while axonops expects it to be controller.log
if [ "$KAFKA_NODE_TYPE" = "kraft-controller" ]; then
    ln -s /var/log/kafka/server.log /var/log/kafka/controller.log
fi

# Supervise axon-agent: restart forever on exit, with crash-loop backoff (issue #154).
# This wrapper is sourced into the Strimzi run script, which then execs the Kafka
# JVM (replacing this shell). Backgrounding the supervisor lets it survive that
# exec: it is reparented to PID 1 (tini), which reaps the agent's exits. Log lines
# go to stdout (Kafka logs); the file tee degrades gracefully if not writable.
supervise_axon_agent() {
  local log="/var/log/axonops/axon-agent.log"
  local fails=0
  local window
  window=$(date +%s)
  while true; do
    echo "[axonops-supervise] starting axon-agent" | tee -a "$log" 2>/dev/null
    /usr/share/axonops/axon-agent -o file $AGENT_ARGS 2>&1 | tee -a "$log" 2>/dev/null
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

# Start the agent under supervision, backgrounded so it survives the Kafka exec
supervise_axon_agent &
