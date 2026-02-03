# AxonOps Strimzi Kafka Cloud Examples

This directory contains example manifests to deploy a Strimzi-based Kafka cluster with AxonOps monitoring on cloud Kubernetes environments.

## Prerequisites

- A Kubernetes cluster with the [Strimzi operator](https://strimzi.io/) installed
- A `kafka` namespace created
- An `axonops-agent` secret in the `kafka` namespace (see below)

## AxonOps Agent Configuration

The Kafka components require an `axonops-agent` secret with your AxonOps connection details. An example is provided in `axonops-config-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: axonops-agent
  namespace: kafka
stringData:
  AXON_AGENT_SERVER_HOST: agents.axonops.cloud
  AXON_AGENT_KEY: CHANGEME
  AXON_AGENT_ORG: example
  AXON_AGENT_CLUSTER_NAME: kafka
```

Update the values to match your AxonOps organisation and agent key. Refer to the [AxonOps Agent Setup documentation](https://axonops.com/docs/get_started/agent_setup/) for details on obtaining these values.

## Manifests

| File | Description |
| --- | --- |
| `axonops-config-secret.yaml` | Secret with AxonOps agent connection details |
| `kafka-logging-cm.yaml` | ConfigMap with log4j configuration for Kafka |
| `kafka-node-pool-controller.yaml` | KafkaNodePool for KRaft controllers (3 replicas) |
| `kafka-node-pool-brokers.yaml` | KafkaNodePool for brokers (6 replicas) |
| `kafka-cluster.yaml` | Kafka cluster resource (KRaft mode) |
| `kafka-connect.yaml` | KafkaConnect deployment (2 replicas) |

## Deployment Order

Apply the manifests in the following order:

```bash
# 1. Create the AxonOps agent secret
kubectl apply -f axonops-config-secret.yaml

# 2. Create the logging ConfigMap
kubectl apply -f kafka-logging-cm.yaml

# 3. Create the KRaft controller node pool
kubectl apply -f kafka-node-pool-controller.yaml

# 4. Create the broker node pool
kubectl apply -f kafka-node-pool-brokers.yaml

# 5. Create the Kafka cluster
kubectl apply -f kafka-cluster.yaml

# 6. (Optional) Deploy Kafka Connect
kubectl apply -f kafka-connect.yaml
```

> **Note:** The `kafka-cluster.yaml` must be applied after the node pools, as the Kafka resource references them. KafkaConnect depends on the cluster being ready.

## Configuration Notes

- The storage class fields (`class`) should be set to match your environment's available StorageClass.
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
