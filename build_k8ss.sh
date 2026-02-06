#!/bin/bash

AXON_AGENT_JAVA_VERSION=$1

crictl images | grep ttl.sh | awk '{print $3}' | xargs crictl rmi

docker build --build-arg=CQLAI_VERSION=0.1.1 --build-arg=AXON_AGENT_JAVA_VERSION=${AXON_AGENT_JAVA_VERSION} --build-arg CASSANDRA_VERSION=5.0.6 --build-arg MAJOR_VERSION=5.0 --build-arg K8SSANDRA_BASE_DIGEST=sha256:bc5708b8ac40c2ad027961a2b1e1b70c826468b8b727c30859718ffc24d7ae04 --build-arg K8SSANDRA_API_VERSION=0.1.111 --tag ttl.sh/marc-axonops-cassandra:1h ./k8ssandra/5.0

[ $? -gt 0 ] && {
  echo "failed"
  exit 1
}

docker push ttl.sh/marc-axonops-cassandra:1h