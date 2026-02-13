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
source strimzi-config.env
```

### Configuration Variables

| Variable | Default | Description |
| --- | --- | --- |
| `KAFKA_NAMESPACE` | `kafka` | Kubernetes namespace for deployment |
| `KAFKA_VERSION` | `4.1.1` | Kafka version |
| `KAFKA_CONTAINER_IMAGE` | `ghcr.io/axonops/strimzi/kafka:...` | Kafka container image with AxonOps agent |
| `STRIMZI_CLUSTER_NAME` | `axonops-kafka` | Name of the Kafka cluster |
| `AXON_AGENT_CLUSTER_NAME` | - | Cluster name in AxonOps |
| `AXON_AGENT_ORG` | - | Your AxonOps organization name |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | AxonOps server hostname |
| `AXON_AGENT_KEY` | - | Your AxonOps API key |
| `AXON_AGENT_TLS_MODE` | `TLS` | TLS mode (`TLS` for SaaS, `disabled` for on-prem) |
| `AXON_AGENT_DATACENTER` | `testdc` | Datacenter name for AxonOps |

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
source strimzi-config.env

# 2. Create the namespace
kubectl create namespace $KAFKA_NAMESPACE

# 3. Apply the ConfigMaps (process with envsubst)
envsubst < axonops-agent-config.yaml | kubectl apply -f -
envsubst < axonops-kafka-logging.yaml | kubectl apply -f -

# 4. Create the node pool (process with envsubst)
envsubst < axonops-kafka-nodepool.yaml | kubectl apply -f -

# 5. Create the Kafka cluster (process with envsubst)
envsubst < kafka-single-node.yaml | kubectl apply -f -
```

### One-liner Deployment

```bash
source strimzi-config.env && \
kubectl create namespace $KAFKA_NAMESPACE --dry-run=client -o yaml | kubectl apply -f - && \
envsubst < axonops-agent-config.yaml | kubectl apply -f - && \
envsubst < axonops-kafka-logging.yaml | kubectl apply -f - && \
envsubst < axonops-kafka-nodepool.yaml | kubectl apply -f - && \
envsubst < kafka-single-node.yaml | kubectl apply -f -
```

### Generate Processed Manifests

To generate processed manifests for review or GitOps:

```bash
source strimzi-config.env

# Generate all processed manifests to a single file
{
  envsubst < axonops-agent-config.yaml
  echo "---"
  envsubst < axonops-kafka-logging.yaml
  echo "---"
  envsubst < axonops-kafka-nodepool.yaml
  echo "---"
  envsubst < kafka-single-node.yaml
} > processed-manifests.yaml
```

## Verification

```bash
# Check the Kafka cluster status
kubectl get kafka -n $KAFKA_NAMESPACE

# Check node pools
kubectl get kafkanodepool -n $KAFKA_NAMESPACE

# Check pods
kubectl get pods -n $KAFKA_NAMESPACE

# View Kafka logs
kubectl logs -n $KAFKA_NAMESPACE -l strimzi.io/cluster=$STRIMZI_CLUSTER_NAME -c kafka
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
