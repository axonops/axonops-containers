# AxonOps Strimzi Kafka Single Node Examples

This directory contains example manifests to deploy a single-node Strimzi Kafka cluster with AxonOps monitoring. Ideal for development, testing, and local environments.

## Overview

- **Kafka Version**: 4.1.1
- **Mode**: KRaft (no ZooKeeper)
- **Topology**: Single node with dual-role (controller + broker)
- **Replicas**: 1
- **Storage**: 100Gi persistent volume
- **Replication Factor**: 1 (single node)

## Prerequisites

- A Kubernetes cluster with the [Strimzi operator](https://strimzi.io/) installed
- `envsubst` command available (part of `gettext` package)

## Configuration

A `strimzi-config.env` file is provided with default configuration values.

```bash
# Review and edit the configuration
cat strimzi-config.env

# Source the environment variables
export $(grep -v '^#' strimzi-config.env | xargs)
```

### Configuration Variables

| Variable | Default | Description |
| --- | --- | --- |
| `STRIMZI_CLUSTER_NAME` | `axonops-kafka` | Name of the Kafka cluster |

### AxonOps Agent Configuration

The AxonOps agent is configured via a ConfigMap (`axonops-agent-config.yaml`). Update the following values in the ConfigMap:

| Field | Description |
| --- | --- |
| `axon-server.hosts` | AxonOps server hostname |
| `axon-agent.org` | Your AxonOps organization name |
| `axon-agent.cluster_name` | Cluster name in AxonOps |
| `axon-agent.key` | Your AxonOps API key |

## Manifests

| File | Description |
| --- | --- |
| `strimzi-config.env` | Environment variables for configuration |
| `axonops-agent-config.yaml` | ConfigMap with AxonOps agent configuration |
| `axonops-kafka-logging.yaml` | ConfigMap with log4j configuration |
| `axonops-kafka-nodepool.yaml` | KafkaNodePool for dual-role node |
| `kafka-single-node.yaml` | Kafka cluster resource (KRaft mode) |

## Deployment

### Using envsubst

The manifests use environment variable placeholders (`${VAR_NAME}`). Use `envsubst` to substitute the values before applying:

```bash
# 1. Source the configuration
export $(grep -v '^#' strimzi-config.env | xargs)

# 2. Edit the AxonOps agent configuration
# Update axonops-agent-config.yaml with your AxonOps credentials

# 3. Apply the ConfigMaps
kubectl apply -f axonops-agent-config.yaml
kubectl apply -f axonops-kafka-logging.yaml

# 4. Create the node pool (process with envsubst)
envsubst < axonops-kafka-nodepool.yaml | kubectl apply -f -

# 5. Create the Kafka cluster (process with envsubst)
envsubst < kafka-single-node.yaml | kubectl apply -f -
```

### One-liner Deployment

```bash
export $(grep -v '^#' strimzi-config.env | xargs) && \
kubectl apply -f axonops-agent-config.yaml && \
kubectl apply -f axonops-kafka-logging.yaml && \
envsubst < axonops-kafka-nodepool.yaml | kubectl apply -f - && \
envsubst < kafka-single-node.yaml | kubectl apply -f -
```

### Generate Processed Manifests

To generate processed manifests for review or GitOps:

```bash
export $(grep -v '^#' strimzi-config.env | xargs)

# Generate all processed manifests to a single file
cat axonops-agent-config.yaml > processed-manifests.yaml
echo "---" >> processed-manifests.yaml
cat axonops-kafka-logging.yaml >> processed-manifests.yaml
echo "---" >> processed-manifests.yaml
envsubst < axonops-kafka-nodepool.yaml >> processed-manifests.yaml
echo "---" >> processed-manifests.yaml
envsubst < kafka-single-node.yaml >> processed-manifests.yaml
```

## Verification

```bash
# Check the Kafka cluster status
kubectl get kafka $STRIMZI_CLUSTER_NAME

# Check node pools
kubectl get kafkanodepool

# Check pods
kubectl get pods -l strimzi.io/cluster=$STRIMZI_CLUSTER_NAME

# View Kafka logs
kubectl logs -l strimzi.io/cluster=$STRIMZI_CLUSTER_NAME -c kafka
```

## Use Cases

This single-node setup is suitable for:

- Local development and testing
- CI/CD pipelines
- Learning and experimentation
- Resource-constrained environments

**Not recommended for production use** due to:
- No high availability (single point of failure)
- Replication factor of 1 (no data redundancy)

## Related Documentation

- [Full Strimzi Deployment Guide](../../STRIMZI_DEPLOYMENT.md)
- [AxonOps Deployment Guide](../../AXONOPS_DEPLOYMENT.md)
