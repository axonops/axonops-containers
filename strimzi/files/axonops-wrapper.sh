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
if [ ! -d /var/lib/kafka/data-0/axonops ]; then
  cp -a /var/lib/axonops /var/lib/kafka/data-0/axonops
fi

for x in agent_service hostId local.db mq; do
  rm -rf /var/lib/axonops/$x
  ln -s /var/lib/kafka/data-0/axonops/$x /var/lib/axonops/$x
done

# Start the agent
/usr/share/axonops/axon-agent -o file $AGENT_ARGS &
