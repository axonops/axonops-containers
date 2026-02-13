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
export $(grep -v '^#' strimzi-config.env | xargs)
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
| `AXON_AGENT_ORG` | `my-org` | AxonOps organization |
| `AXON_AGENT_TLS_MODE` | `none` | AxonOps TLS mode |
| `AXON_AGENT_SERVER_HOST` | `axon-server.axonops.svc.cluster.local` | AxonOps server host |
| `AXON_AGENT_SERVER_PORT` | `1888` | AxonOps server port |

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

### Using envsubst

The manifests use environment variable placeholders (`${VAR_NAME}`). Use `envsubst` to substitute the values before applying:

```bash
# 1. Source the configuration
export $(grep -v '^#' strimzi-config.env | xargs)

# 2. Create the namespace
kubectl create namespace $STRIMZI_NAMESPACE

# 3. Apply the StorageClass
kubectl apply -f strimzi-storageclass.yaml

# 4. Create PersistentVolumes (process with envsubst)
envsubst < strimzi-broker-volumes.yaml | kubectl apply -f -
envsubst < strimzi-controller-volumes.yaml | kubectl apply -f -

# 5. Apply RBAC resources
envsubst < strimzi-kafka-rbac.yaml | kubectl apply -f -

# 6. Create the controller node pool
envsubst < strimzi-controller-pools.yaml | kubectl apply -f -

# 7. Create the broker node pool
envsubst < strimzi-broker-pools.yaml | kubectl apply -f -

# 8. Create the Kafka cluster
envsubst < strimzi-kafka-cluster.yaml | kubectl apply -f -
```

### One-liner Deployment

Apply all manifests in order with a single command:

```bash
export $(grep -v '^#' strimzi-config.env | xargs) && \
kubectl create namespace $STRIMZI_NAMESPACE --dry-run=client -o yaml | kubectl apply -f - && \
kubectl apply -f strimzi-storageclass.yaml && \
for f in strimzi-broker-volumes.yaml strimzi-controller-volumes.yaml strimzi-kafka-rbac.yaml \
         strimzi-controller-pools.yaml strimzi-broker-pools.yaml strimzi-kafka-cluster.yaml; do
  envsubst < $f | kubectl apply -f -
done
```

### Generate Processed Manifests

To generate processed manifests for review or GitOps:

```bash
export $(grep -v '^#' strimzi-config.env | xargs)

# Generate all processed manifests to a single file
for f in strimzi-storageclass.yaml strimzi-broker-volumes.yaml strimzi-controller-volumes.yaml \
         strimzi-kafka-rbac.yaml strimzi-controller-pools.yaml strimzi-broker-pools.yaml \
         strimzi-kafka-cluster.yaml; do
  echo "---"
  envsubst < $f
done > processed-manifests.yaml
```

## Local Storage Setup

Before deploying, ensure the local storage paths exist on your nodes:

```bash
# On each node, create the storage directories
sudo mkdir -p /mnt/data/kafka/broker-{0,1,2}
sudo mkdir -p /mnt/data/kafka/controller-{0,1,2}
```

Update the `strimzi-broker-volumes.yaml` and `strimzi-controller-volumes.yaml` to match your node names and paths.

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
