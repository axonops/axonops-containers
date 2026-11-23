# Strimzi Kafka reporting to a self-hosted AxonOps server

A KRaft Kafka cluster run by the Strimzi operator, using the AxonOps Kafka image so every controller and broker runs the AxonOps agent. The agents report to a self-hosted AxonOps server, such as the one installed by [../../axonops/](../../axonops/). For AxonOps Cloud use [../cloud/](../cloud/); the manifests are identical and only `strimzi-config.env` differs.

| Setting | Default |
| --- | --- |
| Kafka | 4.3.0, KRaft |
| Controllers | 3, 10Gi each |
| Brokers | 3, 20Gi each |
| Replication factor / min ISR | 3 / 2 |
| Rack awareness | `kubernetes.io/hostname` |
| Storage | PVCs from the default StorageClass |

## Prerequisites

- Kubernetes 1.27 or newer, with a default StorageClass
- The Strimzi operator 1.1.0, watching the Kafka namespace (see [STRIMZI_DEPLOYMENT.md](../../STRIMZI_DEPLOYMENT.md#install-the-strimzi-operator))
- `envsubst` (package `gettext`)
- A self-hosted AxonOps server reachable from the pods. With [../../axonops/](../../axonops/) in the same cluster nothing else is needed.

## Quick start

```bash
cd examples/strimzi/on-premises
# Sets AXONOPS_NAMESPACE, AXON_SERVER_ORG_NAME and AXON_SERVER_AGENTS_PORT
source ../../axonops/axonops-config.env
source strimzi-config.env

kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
kubectl wait kafka/"$STRIMZI_CLUSTER_NAME" -n "$KAFKA_NAMESPACE" \
  --for=condition=Ready --timeout=600s
```

The cluster appears in AxonOps under the name in `AXON_AGENT_CLUSTER_NAME` a minute or two after the pods are ready.

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

Review `rendered.yaml` for credentials before committing it.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `KAFKA_NAMESPACE` | `kafka` | Namespace for every resource |
| `STRIMZI_CLUSTER_NAME` | `my-cluster` | Kafka resource name, used as a prefix for pods, Services and the Secret |
| `KAFKA_RACK_TOPOLOGY_KEY` | `kubernetes.io/hostname` | Node label for rack awareness and pod spreading. Use `topology.kubernetes.io/zone` if your nodes carry it. |
| `STRIMZI_VERSION` | `1.1.0` | Installed Strimzi operator version. Selects the image tag; see [version compatibility](../../STRIMZI_DEPLOYMENT.md#version-compatibility). |
| `KAFKA_VERSION` | `4.3.0` | Kafka version. Must be supported by the operator version. |
| `KAFKA_CONTAINER_IMAGE` | `ghcr.io/axonops/strimzi/kafka:${STRIMZI_VERSION}-${KAFKA_VERSION}` | AxonOps Kafka image. The default floating tag follows the latest build for `STRIMZI_VERSION` and `KAFKA_VERSION`; in production pin it by SHA256 digest. |
| `KAFKA_REPLICATION_FACTOR` | `3` | Default and internal topic replication factor. At most the broker count. |
| `KAFKA_MIN_INSYNC_REPLICAS` | `2` | Default and transaction log min ISR |
| `STRIMZI_CONTROLLER_REPLICAS` | `3` | Controllers. Use an odd number. |
| `STRIMZI_CONTROLLER_STORAGE_SIZE` / `_CLASS` | `10Gi` / empty | Controller volume |
| `STRIMZI_BROKER_REPLICAS` | `3` | Brokers |
| `STRIMZI_BROKER_STORAGE_SIZE` / `_CLASS` | `20Gi` / empty | Broker volume. Empty class means the cluster default. |
| `KAFKA_CONNECT_REPLICAS` | `1` | Kafka Connect workers |
| `AXONOPS_NAMESPACE` | `axonops`, or the value from `axonops-config.env` | Namespace of the AxonOps server |
| `AXON_AGENT_ORG` | `$AXON_SERVER_ORG_NAME`, else `example` | Must match the server `org_name` |
| `AXON_AGENT_KEY` | `not-used` | Not used by a self-hosted server |
| `AXON_AGENT_CLUSTER_NAME` | `$STRIMZI_CLUSTER_NAME` | Cluster name shown in AxonOps |
| `AXON_AGENT_SERVER_HOST` | `axon-server-agent.$AXONOPS_NAMESPACE.svc.cluster.local` | axon-server agent Service. Use the agent Ingress host for a server outside the cluster. |
| `AXON_AGENT_SERVER_PORT` | `$AXON_SERVER_AGENTS_PORT`, else `1888` | axon-server agent port |
| `AXON_AGENT_TLS_MODE` | `disabled` | `TLS` when the server agent port or Ingress uses TLS |

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
