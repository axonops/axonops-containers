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

if [ $logDir != "" ]; then
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

# Start the agent
/usr/share/axonops/axon-agent -o file $AGENT_ARGS &
