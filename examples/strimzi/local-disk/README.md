# AxonOps Strimzi Kafka Local Disk Examples

This directory contains example manifests to deploy a Strimzi-based Kafka cluster with AxonOps monitoring using local persistent volumes.

## Overview

- **Kafka Version**: 4.1.1
- **Mode**: KRaft (no ZooKeeper)
- **Brokers**: 3 replicas (configurable), 10Gi storage
- **Controllers**: 3 replicas (configurable), 5Gi storage
- **Replication Factor**: 1 (development/testing)
- **Storage**: Local persistent volumes with manual provisioning

## Prerequisites

- A Kubernetes cluster with the [Strimzi operator](https://strimzi.io/) installed
- `envsubst` command available (part of `gettext` package)
- Local storage paths available on nodes

## Configuration

A `strimzi-config.env` file is provided with default configuration values. Edit this file to customize your deployment.

```bash
# Review and edit the configuration
cat strimzi-config.env

# Source the environment variables
source strimzi-config.env
```

### Configuration Variables

| Variable | Default | Description |
| --- | --- | --- |
| `STRIMZI_NAMESPACE` | `kafka` | Kubernetes namespace for deployment |
| `STRIMZI_CLUSTER_NAME` | `my-cluster` | Name of the Kafka cluster |
| `STRIMZI_BROKER_REPLICAS` | `3` | Number of broker replicas |
| `STRIMZI_BROKER_STORAGE_SIZE` | `10Gi` | Storage size per broker |
| `STRIMZI_CONTROLLER_REPLICAS` | `3` | Number of controller replicas |
| `STRIMZI_CONTROLLER_STORAGE_SIZE` | `5Gi` | Storage size per controller |
| `AXON_AGENT_CLUSTER_NAME` | `my-cluster` | AxonOps cluster name |
| `AXON_AGENT_ORG` | `your-org` | AxonOps organization |
| `AXON_AGENT_TLS_MODE` | `disabled` | AxonOps TLS mode |
| `AXON_AGENT_SERVER_HOST` | `axon-server.axonops.svc.cluster.local` | AxonOps server host |
| `AXON_AGENT_SERVER_PORT` | `1888` | AxonOps server port |

### Per-Node Volume Variables

The following variables must be set when creating PersistentVolumes. Since each broker and controller needs its own PV, you must apply the volume manifests **multiple times** with different values:

| Variable | Description |
| --- | --- |
| `STRIMZI_BROKER_ID` | Broker index (0, 1, 2, etc.) - set for each broker volume |
| `STRIMZI_BROKER_NODE` | Kubernetes node hostname where the broker volume resides |
| `STRIMZI_CONTROLLER_ID` | Controller index (0, 1, 2, etc.) - set for each controller volume |
| `STRIMZI_CONTROLLER_NODE` | Kubernetes node hostname where the controller volume resides |

## Manifests

| File | Description |
| --- | --- |
| `strimzi-config.env` | Environment variables for configuration |
| `strimzi-storageclass.yaml` | StorageClass for local persistent volumes |
| `strimzi-broker-volumes.yaml` | PersistentVolumes for brokers |
| `strimzi-controller-volumes.yaml` | PersistentVolumes for controllers |
| `strimzi-kafka-rbac.yaml` | RBAC resources for Kafka |
| `strimzi-controller-pools.yaml` | KafkaNodePool for KRaft controllers |
| `strimzi-broker-pools.yaml` | KafkaNodePool for brokers |
| `strimzi-kafka-cluster.yaml` | Kafka cluster resource (KRaft mode) |

## Deployment

**Prerequisites:** Before proceeding, ensure you have created the local storage directories on each node and set the correct ownership. See [Local Storage Setup](#local-storage-setup) below.

### Using envsubst

The manifests use environment variable placeholders (`${VAR_NAME}`). Use `envsubst` to substitute the values before applying:

```bash
# 1. Source the configuration
source strimzi-config.env

# 2. Create the namespace
kubectl create namespace $STRIMZI_NAMESPACE

# 3. Apply the StorageClass
kubectl apply -f strimzi-storageclass.yaml

# 4. Create PersistentVolumes for each broker (repeat for each broker ID)
# You must apply the broker volume manifest once per broker with unique STRIMZI_BROKER_ID and STRIMZI_BROKER_NODE
export STRIMZI_BROKER_ID=0 STRIMZI_BROKER_NODE=node1 && envsubst < strimzi-broker-volumes.yaml | kubectl apply -f -
export STRIMZI_BROKER_ID=1 STRIMZI_BROKER_NODE=node2 && envsubst < strimzi-broker-volumes.yaml | kubectl apply -f -
export STRIMZI_BROKER_ID=2 STRIMZI_BROKER_NODE=node3 && envsubst < strimzi-broker-volumes.yaml | kubectl apply -f -

# 5. Create PersistentVolumes for each controller (repeat for each controller ID)
# You must apply the controller volume manifest once per controller with unique STRIMZI_CONTROLLER_ID and STRIMZI_CONTROLLER_NODE
export STRIMZI_CONTROLLER_ID=0 STRIMZI_CONTROLLER_NODE=node1 && envsubst < strimzi-controller-volumes.yaml | kubectl apply -f -
export STRIMZI_CONTROLLER_ID=1 STRIMZI_CONTROLLER_NODE=node2 && envsubst < strimzi-controller-volumes.yaml | kubectl apply -f -
export STRIMZI_CONTROLLER_ID=2 STRIMZI_CONTROLLER_NODE=node3 && envsubst < strimzi-controller-volumes.yaml | kubectl apply -f -

# 6. Apply RBAC resources
envsubst < strimzi-kafka-rbac.yaml | kubectl apply -f -

# 7. Create the controller node pool
envsubst < strimzi-controller-pools.yaml | kubectl apply -f -

# 8. Create the broker node pool
envsubst < strimzi-broker-pools.yaml | kubectl apply -f -

# 9. Create the Kafka cluster
envsubst < strimzi-kafka-cluster.yaml | kubectl apply -f -
```

### One-liner Deployment

Apply all manifests in order. Note that you must customize the node names (`node1`, `node2`, `node3`) to match your actual Kubernetes node hostnames:

```bash
source strimzi-config.env && \
kubectl create namespace $STRIMZI_NAMESPACE --dry-run=client -o yaml | kubectl apply -f - && \
kubectl apply -f strimzi-storageclass.yaml && \
# Create broker PVs (adjust node names to match your cluster)
for i in 0 1 2; do
  export STRIMZI_BROKER_ID=$i STRIMZI_BROKER_NODE=node$((i+1))
  envsubst < strimzi-broker-volumes.yaml | kubectl apply -f -
done && \
# Create controller PVs (adjust node names to match your cluster)
for i in 0 1 2; do
  export STRIMZI_CONTROLLER_ID=$i STRIMZI_CONTROLLER_NODE=node$((i+1))
  envsubst < strimzi-controller-volumes.yaml | kubectl apply -f -
done && \
# Apply remaining manifests
for f in strimzi-kafka-rbac.yaml strimzi-controller-pools.yaml strimzi-broker-pools.yaml strimzi-kafka-cluster.yaml; do
  envsubst < $f | kubectl apply -f -
done
```

### Generate Processed Manifests

To generate processed manifests for review or GitOps (adjust node names to match your cluster):

```bash
source strimzi-config.env

# Generate all processed manifests to a single file
{
  echo "---"
  cat strimzi-storageclass.yaml
  # Generate broker PVs
  for i in 0 1 2; do
    export STRIMZI_BROKER_ID=$i STRIMZI_BROKER_NODE=node$((i+1))
    echo "---"
    envsubst < strimzi-broker-volumes.yaml
  done
  # Generate controller PVs
  for i in 0 1 2; do
    export STRIMZI_CONTROLLER_ID=$i STRIMZI_CONTROLLER_NODE=node$((i+1))
    echo "---"
    envsubst < strimzi-controller-volumes.yaml
  done
  # Generate remaining manifests
  for f in strimzi-kafka-rbac.yaml strimzi-controller-pools.yaml strimzi-broker-pools.yaml \
           strimzi-kafka-cluster.yaml; do
    echo "---"
    envsubst < $f
  done
} > processed-manifests.yaml
```

## Local Storage Setup

**Important:** Before deploying, you must create the local storage directories on each Kubernetes node and set the correct ownership. Kafka runs as user ID 1001, so the directories must be owned by this user.

The paths follow the pattern:

- Brokers: `/data/strimzi/${STRIMZI_CLUSTER_NAME}/broker-pool-${STRIMZI_BROKER_ID}`
- Controllers: `/data/strimzi/${STRIMZI_CLUSTER_NAME}/controller-${STRIMZI_CONTROLLER_ID}`

```bash
# On each node, create the storage directories (using default cluster name 'my-cluster')
sudo mkdir -p /data/strimzi/my-cluster/broker-pool-{0,1,2}
sudo mkdir -p /data/strimzi/my-cluster/controller-{0,1,2}

# Set ownership to Kafka user (UID 1001)
sudo chown -R 1001:1001 /data/strimzi/my-cluster
```

Make sure to create the directories on the correct nodes as specified by `STRIMZI_BROKER_NODE` and `STRIMZI_CONTROLLER_NODE` variables. For example, if broker-0 is on node1, create `/data/strimzi/my-cluster/broker-pool-0` on node1.

## Verification

```bash
# Check the Kafka cluster status
kubectl get kafka -n $STRIMZI_NAMESPACE

# Check node pools
kubectl get kafkanodepool -n $STRIMZI_NAMESPACE

# Check pods
kubectl get pods -n $STRIMZI_NAMESPACE

# Check persistent volumes
kubectl get pv | grep kafka
```

## Related Documentation

- [Full Strimzi Deployment Guide](../../STRIMZI_DEPLOYMENT.md)
- [AxonOps Deployment Guide](../../AXONOPS_DEPLOYMENT.md)
