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
docker build -t $IMAGE_NAME . && docker push $IMAGE_NAME
crictl pull $IMAGE_NAME

cat cluster-axonops.yaml | envsubst > /tmp/cluster-axonops.yaml
kubectl apply -f /tmp/cluster-axonops.yaml

echo "Built and push image $IMAGE_NAME and deployed to cluster."
