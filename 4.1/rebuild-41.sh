#!/bin/bash
kubectl delete -f cluster-axonops.yaml

export IMAGE_NAME=ttl.sh/$(uuidgen):1h

crictl images | grep ttl.sh | awk '{print $3}' | xargs crictl rmi
docker build -t $IMAGE_NAME -f Dockerfile.4-1 . && docker push $IMAGE_NAME
crictl pull $IMAGE_NAME

cat cluster-axonops41.yaml | envsubst > /tmp/cluster-axonops.yaml
kubectl apply -f /tmp/cluster-axonops.yaml
