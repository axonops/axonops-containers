#!/bin/bash

# if [ -z "$AXON_AGENT_KEY" ] || [ -z "$AXON_AGENT_ORG" ]; then
#   echo "AXON_AGENT_KEY and AXON_AGENT_ORG environment variables must be set."
#   exit 1
# fi

if [ -z "$IMAGE_NAME" ]; then
    export IMAGE_NAME=ttl.sh/$(uuidgen):1h
fi

kubectl delete -f cluster-axonops.yaml

crictl images | grep ttl.sh | awk '{print $3}' | xargs crictl rmi

# Get k8ssandra version from K8SSANDRA_VERSIONS variable or use latest known
# For quick dev builds, we use the first available version
CASSANDRA_VER=$(basename $(pwd) | cut -d. -f1,2)  # Get 5.0 from directory
CQLAI_VER=${CQLAI_VERSION:-0.0.31}

# Note: These should match your K8SSANDRA_VERSIONS variable
# For 5.0.6, use the digest from the variable
K8S_DIGEST=${K8SSANDRA_DIGEST:-sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af}
K8S_API_VER=${K8SSANDRA_API_VERSION:-0.1.110}

docker build \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg MAJOR_VERSION=$CASSANDRA_VER \
  --build-arg K8SSANDRA_BASE_DIGEST=$K8S_DIGEST \
  --build-arg K8SSANDRA_API_VERSION=$K8S_API_VER \
  --build-arg CQLAI_VERSION=$CQLAI_VER \
  -t $IMAGE_NAME . && docker push $IMAGE_NAME
crictl pull $IMAGE_NAME

cat cluster-axonops.yaml | envsubst > /tmp/cluster-axonops.yaml
kubectl apply -f /tmp/cluster-axonops.yaml

echo "Built and push image $IMAGE_NAME and deployed to cluster."
