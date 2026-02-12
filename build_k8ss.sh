#!/bin/bash

#./build_k8ss.sh "2.0.3.asb14061-1" "1.0.13.asb4142nodetoolscheduler502-1" "5.0.6" "5.0"


#./build_k8ss.sh "2.0.3.asb14061-1" "1.0.14.asb3642nodetoolscheduler412-1" "4.1.7" "4.1"


AXON_AGENT_VERSION=$1 
AXON_AGENT_JAVA_VERSION=$2
CASSANDRA_VERSION=$3
MAJOR_VERSION=$4

TAG=$(uuidgen |cut -d- -f1)

crictl images | grep ttl.sh | awk '{print $3}' | xargs crictl rmi

docker build --build-arg=CQLAI_VERSION=0.1.1 --build-arg=AXON_AGENT_VERSION=${AXON_AGENT_VERSION} --build-arg=AXON_AGENT_JAVA_VERSION=${AXON_AGENT_JAVA_VERSION} --build-arg CASSANDRA_VERSION=${CASSANDRA_VERSION} --build-arg MAJOR_VERSION=${MAJOR_VERSION} --build-arg K8SSANDRA_BASE_DIGEST=sha256:bc5708b8ac40c2ad027961a2b1e1b70c826468b8b727c30859718ffc24d7ae04 --build-arg K8SSANDRA_API_VERSION=0.1.111 --tag ttl.sh/marc-axonops-cassandra:${TAG} ./k8ssandra/${MAJOR_VERSION} 

[ $? -gt 0 ] && {
  echo "failed"
  exit 1
}

docker push ttl.sh/marc-axonops-cassandra:${TAG}

yq -i ".spec.cassandra.serverImage = \"ttl.sh/marc-axonops-cassandra:${TAG}\"" ~/axonops-containers/k8ssandra/scripts/axon-cluster-${MAJOR_VERSION}.yml
kubectl apply -f ~/axonops-containers/k8ssandra/scripts/axon-cluster-${MAJOR_VERSION}.yml
