# Strimzi Kafka reporting to AxonOps Cloud

A KRaft Kafka cluster run by the Strimzi operator, using the AxonOps Kafka image so every controller and broker runs the AxonOps agent. The agents report to AxonOps Cloud (SaaS). For a self-hosted AxonOps server use [../on-premises/](../on-premises/); the manifests are identical and only `strimzi-config.env` differs.

| Setting | Default |
| --- | --- |
| Kafka | 4.3.0, KRaft |
| Controllers | 3, 10Gi each |
| Brokers | 3, 20Gi each |
| Replication factor / min ISR | 3 / 2 |
| Rack awareness | `topology.kubernetes.io/zone` |
| Storage | PVCs from the default StorageClass |

## Prerequisites

- Kubernetes 1.27 or newer, with a default StorageClass
- The Strimzi operator 1.1.0, watching the Kafka namespace (see [STRIMZI_DEPLOYMENT.md](../../STRIMZI_DEPLOYMENT.md#install-the-strimzi-operator))
- `envsubst` (package `gettext`)
- An AxonOps Cloud organisation and agent key
- Nodes labelled with `topology.kubernetes.io/zone`. Managed clusters (EKS, GKE, AKS) set it. Otherwise set `KAFKA_RACK_TOPOLOGY_KEY=kubernetes.io/hostname`.

## Quick start

```bash
cd examples/strimzi/cloud
source strimzi-config.env
export AXON_AGENT_ORG=your-org
export AXON_AGENT_KEY=your-agent-key

kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
kubectl wait kafka/"$STRIMZI_CLUSTER_NAME" -n "$KAFKA_NAMESPACE" \
  --for=condition=Ready --timeout=600s
```

The cluster appears in AxonOps Cloud under the name in `AXON_AGENT_CLUSTER_NAME` a minute or two after the pods are ready.

## Files

| File | Resource |
| --- | --- |
| `strimzi-config.env` | Settings for every manifest |
| `axonops-agent-secret.yaml` | Secret `<cluster>-axonops-agent` with the agent settings. Every Kafka container reads it through `valueFrom.secretKeyRef`. |
| `kafka-node-pool-controller.yaml` | KafkaNodePool `controller` (KRaft controllers) |
| `kafka-node-pool-brokers.yaml` | KafkaNodePool `broker` |
| `kafka-cluster.yaml` | Kafka `<cluster>`: listeners, replication, rack awareness, logging to `/var/log/kafka/server.log` for the agent |
| `kafka-connect.yaml` | Optional KafkaConnect `<cluster>-connect`, also monitored by AxonOps |

Pods are named `<cluster>-controller-<id>` and `<cluster>-broker-<id>`. Node ids are shared by both pools, so the first broker is not always `-0`.

## Examples

Use a different namespace, cluster name and StorageClass:

```bash
export KAFKA_NAMESPACE=streaming STRIMZI_CLUSTER_NAME=orders
export STRIMZI_BROKER_STORAGE_CLASS=gp3 STRIMZI_CONTROLLER_STORAGE_CLASS=gp3
source strimzi-config.env
```

Export overrides before sourcing the file: it keeps values that are already set, and derived values such as `AXON_AGENT_CLUSTER_NAME` follow `STRIMZI_CLUSTER_NAME`. Start a new shell to drop them.

Add Kafka Connect after the cluster is ready:

```bash
envsubst < kafka-connect.yaml | kubectl apply -f -
kubectl wait kafkaconnect/"$STRIMZI_CLUSTER_NAME-connect" -n "$KAFKA_NAMESPACE" \
  --for=condition=Ready --timeout=600s
```

Render everything to one file for review or GitOps:

```bash
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  echo "---"; envsubst < "$f"
done > rendered.yaml
```

`rendered.yaml` contains the agent key. Do not commit it.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `KAFKA_NAMESPACE` | `kafka` | Namespace for every resource |
| `STRIMZI_CLUSTER_NAME` | `my-cluster` | Kafka resource name, used as a prefix for pods, Services and the Secret |
| `KAFKA_RACK_TOPOLOGY_KEY` | `topology.kubernetes.io/zone` | Node label for rack awareness and pod spreading |
| `KAFKA_VERSION` | `4.3.0` | Kafka version. Must be supported by the operator version. |
| `KAFKA_CONTAINER_IMAGE` | `ghcr.io/axonops/strimzi/kafka:1.1.0-4.3.0` | AxonOps Kafka image. The default floating tag follows the latest build for Strimzi 1.1.0 and `KAFKA_VERSION`; in production pin it by SHA256 digest. |
| `KAFKA_REPLICATION_FACTOR` | `3` | Default and internal topic replication factor. At most the broker count. |
| `KAFKA_MIN_INSYNC_REPLICAS` | `2` | Default and transaction log min ISR |
| `STRIMZI_CONTROLLER_REPLICAS` | `3` | Controllers. Use an odd number. |
| `STRIMZI_CONTROLLER_STORAGE_SIZE` / `_CLASS` | `10Gi` / empty | Controller volume |
| `STRIMZI_BROKER_REPLICAS` | `3` | Brokers |
| `STRIMZI_BROKER_STORAGE_SIZE` / `_CLASS` | `20Gi` / empty | Broker volume. Empty class means the cluster default. |
| `KAFKA_CONNECT_REPLICAS` | `1` | Kafka Connect workers |
| `AXON_AGENT_ORG` | `your-org` | AxonOps organisation |
| `AXON_AGENT_KEY` | none, required | AxonOps agent key. Export it; do not write it in the file. |
| `AXON_AGENT_CLUSTER_NAME` | `$STRIMZI_CLUSTER_NAME` | Cluster name shown in AxonOps |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | AxonOps endpoint |
| `AXON_AGENT_SERVER_PORT` | `443` | AxonOps endpoint port |
| `AXON_AGENT_TLS_MODE` | `TLS` | Agent TLS mode |

To change the agent settings later, update the Secret and restart the pods; Strimzi does not roll them for a Secret change:

```bash
envsubst < axonops-agent-secret.yaml | kubectl apply -f -
kubectl annotate strimzipodset -n "$KAFKA_NAMESPACE" \
  "$STRIMZI_CLUSTER_NAME-controller" "$STRIMZI_CLUSTER_NAME-broker" \
  strimzi.io/manual-rolling-update=true
```

## Verify

```bash
kubectl get kafka,kafkanodepool,pods,pvc -n "$KAFKA_NAMESPACE"
# Agent output is in the Kafka container log
BROKER=$(kubectl get pod -n "$KAFKA_NAMESPACE" -l strimzi.io/pool-name=broker -o name | head -1)
kubectl logs -n "$KAFKA_NAMESPACE" "$BROKER" -c kafka | grep -i axon
```

## Remove

```bash
kubectl delete kafkaconnect "$STRIMZI_CLUSTER_NAME-connect" -n "$KAFKA_NAMESPACE" --ignore-not-found
kubectl delete kafka "$STRIMZI_CLUSTER_NAME" -n "$KAFKA_NAMESPACE"
kubectl delete kafkanodepool controller broker -n "$KAFKA_NAMESPACE"
kubectl delete secret "$STRIMZI_CLUSTER_NAME-axonops-agent" -n "$KAFKA_NAMESPACE"
# deleteClaim is false, so the data volumes stay. To delete them:
kubectl delete pvc -n "$KAFKA_NAMESPACE" -l strimzi.io/cluster="$STRIMZI_CLUSTER_NAME"
```

## Related

- [Strimzi deployment guide](../../STRIMZI_DEPLOYMENT.md)
- [AxonOps Kafka image](../../../strimzi/README.md)
- [Strimzi documentation](https://strimzi.io/docs/operators/latest/)
