# AxonOps Strimzi Kafka Cloud Examples

This directory contains example manifests to deploy a Strimzi-based Kafka cluster with AxonOps monitoring on cloud Kubernetes environments.

## Overview

- **Kafka Version**: 4.1.1
- **Mode**: KRaft (no ZooKeeper)
- **Brokers**: 6 replicas, 20Gi storage
- **Controllers**: 3 replicas, 5Gi storage
- **Replication Factor**: 3 (production-ready)

## Prerequisites

- A Kubernetes cluster with the [Strimzi operator](https://strimzi.io/) installed

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
| `STRIMZI_CLUSTER_NAME` | Name of the Kafka cluster | `axonops-kafka` |
| `KAFKA_VERSION` | Kafka version | `4.1.1` |
| `KAFKA_CONTAINER_IMAGE` | Kafka container image with AxonOps agent | See .env file |
| `STRIMZI_BROKER_REPLICAS` | Number of broker replicas | `6` |
| `STRIMZI_BROKER_STORAGE_SIZE` | Storage size per broker | `20Gi` |
| `STRIMZI_BROKER_STORAGE_CLASS` | Storage class for brokers | `""` (default) |
| `STRIMZI_CONTROLLER_REPLICAS` | Number of controller replicas | `3` |
| `STRIMZI_CONTROLLER_STORAGE_SIZE` | Storage size per controller | `5Gi` |
| `STRIMZI_CONTROLLER_STORAGE_CLASS` | Storage class for controllers | `""` (default) |
| `KAFKA_CONNECT_REPLICAS` | Number of Kafka Connect replicas | `2` |
| `KAFKA_CONNECT_IMAGE` | Kafka Connect container image | See .env file |
| `AXON_AGENT_CLUSTER_NAME` | AxonOps cluster name | `kafka` |
| `AXON_AGENT_ORG` | AxonOps organisation | `example` |
| `AXON_AGENT_KEY` | AxonOps agent key | `CHANGEME` |
| `AXON_AGENT_SERVER_HOST` | AxonOps server hostname | `agents.axonops.cloud` |
| `AXON_AGENT_TLS_MODE` | TLS mode for AxonOps connection | `TLS` |

## Manifests

| File | Description |
| --- | --- |
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

```bash
envsubst < kafka-connect.yaml | kubectl apply -f -
```

> **Note:** The `kafka-cluster.yaml` must be applied after the node pools, as the Kafka resource references them. KafkaConnect depends on the cluster being ready.

## Configuration Notes

- The storage class variables (`STRIMZI_BROKER_STORAGE_CLASS`, `STRIMZI_CONTROLLER_STORAGE_CLASS`) should be set to match your environment's available StorageClass.
- The container images reference AxonOps custom Strimzi images with the agent embedded.
- Topology spread constraints are configured using `topology.kubernetes.io/zone`. Adjust the `topologyKey` for your infrastructure (see below).

## Topology Key Configuration

The `topologyKey` in `kafka-node-pool-controller.yaml` and `kafka-cluster.yaml` controls how pods are distributed across failure domains. The correct value depends on your Kubernetes environment.

To check which topology labels are available on your nodes:

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{.metadata.labels}{"\n\n"}{end}' | grep -E "topology|zone|region"
```

Or view all labels for a specific node:

```bash
kubectl describe node <node-name> | grep -A 20 "Labels:"
```

### Common topology keys by provider

| Provider | Zone key | Region key |
| --- | --- | --- |
| Standard Kubernetes | `topology.kubernetes.io/zone` | `topology.kubernetes.io/region` |
| AWS EKS | `topology.kubernetes.io/zone` | `topology.kubernetes.io/region` |
| Google GKE | `topology.kubernetes.io/zone` | `topology.kubernetes.io/region` |
| Azure AKS | `topology.kubernetes.io/zone` | `topology.kubernetes.io/region` |

### Cloud provider documentation

- [AWS EKS - Spread workloads across zones](https://docs.aws.amazon.com/prescriptive-guidance/latest/ha-resiliency-amazon-eks-apps/spread-workloads.html)
- [Google GKE - Node labels](https://cloud.google.com/kubernetes-engine/docs/concepts/node-labels)
- [Azure AKS - Availability zones](https://learn.microsoft.com/en-us/azure/aks/availability-zones-overview)
- [Kubernetes - Well-known labels](https://kubernetes.io/docs/reference/labels-annotations-taints/#topologykubernetesiozone)

## Related Documentation

- [Full Strimzi Deployment Guide](../../STRIMZI_DEPLOYMENT.md)
- [AxonOps Deployment Guide](../../AXONOPS_DEPLOYMENT.md)
- [Node Selector Guide](../../NODE_SELECTOR_GUIDE.md)
