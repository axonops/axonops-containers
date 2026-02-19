# AxonOps Strimzi Kafka On-Premises Example

This directory contains example manifests to deploy a Strimzi-based Kafka cluster with AxonOps monitoring, connecting to an **on-premises AxonOps Server** (self-hosted).

## Overview

- **Kafka Version**: 4.1.1
- **Mode**: KRaft (no ZooKeeper)
- **Brokers**: 6 replicas, 20Gi storage
- **Controllers**: 3 replicas, 10Gi storage
- **Replication Factor**: 3 (production-ready)
- **AxonOps Connection**: On-premises AxonOps Server (no TLS, no API key required)

## Prerequisites

- A Kubernetes cluster with the [Strimzi operator](https://strimzi.io/) installed
- An on-premises AxonOps Server accessible from the Kubernetes cluster (e.g. `axon-server-agent.axonops.svc.cluster.local`)
- `envsubst` available (part of `gettext` package)

## Configuration

Edit the `strimzi-config.env` file with your settings:

```bash
# Review and edit the configuration
cat strimzi-config.env

# Source the environment variables
source strimzi-config.env
```

### Configuration Variables

| Variable | Description | Default |
| --- | --- | --- |
| `KAFKA_NAMESPACE` | Kubernetes namespace for Kafka | `kafka` |
| `STRIMZI_CLUSTER_NAME` | Name of the Kafka cluster | `example` |
| `KAFKA_VERSION` | Kafka version | `4.1.1` |
| `KAFKA_CONTAINER_IMAGE` | Kafka container image with AxonOps agent | See .env file |
| `STRIMZI_BROKER_REPLICAS` | Number of broker replicas | `6` |
| `STRIMZI_BROKER_STORAGE_SIZE` | Storage size per broker | `20Gi` |
| `STRIMZI_BROKER_STORAGE_CLASS` | Storage class for brokers | `""` (default) |
| `STRIMZI_CONTROLLER_REPLICAS` | Number of controller replicas | `3` |
| `STRIMZI_CONTROLLER_STORAGE_SIZE` | Storage size per controller | `10Gi` |
| `STRIMZI_CONTROLLER_STORAGE_CLASS` | Storage class for controllers | `""` (default) |
| `AXON_AGENT_CLUSTER_NAME` | AxonOps cluster name | `example` |
| `AXON_AGENT_ORG` | AxonOps organisation | `example` |
| `AXON_AGENT_KEY` | AxonOps agent key | `not-used` |
| `AXON_AGENT_SERVER_HOST` | AxonOps Server hostname | `axon-server-agent.axonops.svc.cluster.local` |
| `AXON_AGENT_SERVER_PORT` | AxonOps Server agent port | `1888` |
| `AXON_AGENT_TLS_MODE` | TLS mode for AxonOps connection | `disabled` |

### On-Premises vs Cloud differences

| Setting | On-Premises | Cloud (SaaS) |
| --- | --- | --- |
| `AXON_AGENT_SERVER_HOST` | Your AxonOps Server address (e.g. K8s service DNS) | `agents.axonops.cloud` |
| `AXON_AGENT_SERVER_PORT` | `1888` | `443` |
| `AXON_AGENT_TLS_MODE` | `disabled` (or `TLS` if configured) | `TLS` |
| `AXON_AGENT_KEY` | `not-used` | Your AxonOps API key |

## Manifests

| File | Description |
| --- | --- |
| `strimzi-config.env` | Environment variables for all manifests |
| `axonops-config-secret.yaml` | Secret with AxonOps agent connection details |
| `kafka-logging-cm.yaml` | ConfigMap with log4j configuration for Kafka |
| `kafka-node-pool-controller.yaml` | KafkaNodePool for KRaft controllers |
| `kafka-node-pool-brokers.yaml` | KafkaNodePool for brokers |
| `kafka-cluster.yaml` | Kafka cluster resource (KRaft mode) |
| `kafka-connect.yaml` | KafkaConnect deployment (optional) |

## Deployment

### 1. Source Configuration and Create Namespace

```bash
# Source the environment variables
source strimzi-config.env

# Create the namespace
kubectl create namespace ${KAFKA_NAMESPACE}
```

### 2. Deploy the AxonOps Agent Secret

```bash
envsubst < axonops-config-secret.yaml | kubectl apply -f -
```

### 3. Deploy the Logging ConfigMap

```bash
envsubst < kafka-logging-cm.yaml | kubectl apply -f -
```

### 4. Deploy the KRaft Controller Node Pool

```bash
envsubst < kafka-node-pool-controller.yaml | kubectl apply -f -
```

### 5. Deploy the Broker Node Pool

```bash
envsubst < kafka-node-pool-brokers.yaml | kubectl apply -f -
```

### 6. Deploy the Kafka Cluster

```bash
envsubst < kafka-cluster.yaml | kubectl apply -f -
```

### 7. (Optional) Deploy Kafka Connect

> **Note:** Kafka Connect is supported by AxonOps but is out of scope for this example. If you need help setting up Kafka Connect with AxonOps monitoring, please contact [AxonOps](https://axonops.com) or [Digitalis](https://digitalis.io) for support.

**Note:** The `kafka-cluster.yaml` must be applied after the node pools, as the Kafka resource references them.

## Configuration Notes

- The storage class variables (`STRIMZI_BROKER_STORAGE_CLASS`, `STRIMZI_CONTROLLER_STORAGE_CLASS`) should be set to match your environment's available StorageClass.
- The container images reference AxonOps custom Strimzi images with the agent embedded.
- Topology spread constraints are configured using `topology.kubernetes.io/zone`. For on-premises clusters without zone labels, you may want to change the `topologyKey` to `kubernetes.io/hostname` to spread pods across nodes instead.
- For Kafka Connect, you need to define `KAFKA_CONNECT_IMAGE` and `KAFKA_CONNECT_REPLICAS` in your environment before deploying.

## Topology Key Configuration

The `topologyKey` in `kafka-cluster.yaml` controls how pods are distributed across failure domains. For on-premises environments, the correct value depends on your cluster's node labels.

To check which topology labels are available on your nodes:

```bash
kubectl get nodes --show-labels | grep -E "topology|zone|hostname"
```

### Common topology keys for on-premises

| Scenario | Topology Key | Use Case |
| --- | --- | --- |
| Multi-zone on-prem | `topology.kubernetes.io/zone` | Nodes labelled by rack/zone |
| Single-zone on-prem | `kubernetes.io/hostname` | Spread across individual nodes |
| Custom labels | Your custom label key | Custom rack/failure-domain labels |

If your on-premises nodes don't have zone labels, update the `topologyKey` in `kafka-cluster.yaml`:

```yaml
rack:
  topologyKey: kubernetes.io/hostname
```

## Related Documentation

- [Full Strimzi Deployment Guide](../../STRIMZI_DEPLOYMENT.md)
- [AxonOps Deployment Guide](../../AXONOPS_DEPLOYMENT.md)
- [Node Selector Guide](../../NODE_SELECTOR_GUIDE.md)
