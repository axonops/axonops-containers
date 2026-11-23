# Strimzi Kafka on local disks

A KRaft Kafka cluster with the AxonOps agent whose data lives in directories on chosen Kubernetes nodes, through hostPath PersistentVolumes. Use it on bare metal or lab clusters without a storage provisioner. With a StorageClass that provisions volumes, use [../on-premises/](../on-premises/) instead.

`strimzi-setup.sh` does the deployment: it installs the Strimzi operator if its CRDs are missing, creates one PersistentVolume per controller and broker on the node you choose for it, and applies the node pools and the Kafka cluster. The agents report to a self-hosted AxonOps server, by default the one from [../../axonops/](../../axonops/).

| Setting | Default |
| --- | --- |
| Kafka | 4.3.0, KRaft |
| Controllers | 3, 10Gi each |
| Brokers | 3, 20Gi each |
| Replication factor / min ISR | 3 / 2 |
| Volume directories | `/data/strimzi/<cluster>/controller-<n>` and `/data/strimzi/<cluster>/broker-<n>` |

## Prerequisites

- Kubernetes 1.27 or newer, `kubectl`, `helm` and `envsubst` (package `gettext`)
- bash 3.2 or newer
- Shell access to the nodes that hold the volumes, to create the directories
- A self-hosted AxonOps server reachable from the pods

## Quick start

On a single-node cluster the script places every volume on that node:

```bash
cd examples/strimzi/local-disk
source ../../axonops/axonops-config.env   # AxonOps namespace, organisation and port
source strimzi-config.env
RENDER_ONLY=true ./strimzi-setup.sh       # prints the directories to create
```

Run the printed commands on the node, for example:

```bash
sudo mkdir -p /data/strimzi/my-cluster/controller-{0,1,2} /data/strimzi/my-cluster/broker-{0,1,2}
sudo chown -R 1001:1001 /data/strimzi/my-cluster
```

Then deploy:

```bash
./strimzi-setup.sh
```

The script waits until the Kafka resource is Ready and prints each pod with its node.

## Placing volumes on several nodes

Each volume is pinned to one node. Map volume indices to nodes with `<index>:<node>` pairs; indices without a mapping use `STRIMZI_NODE_HOSTNAME`:

```bash
source strimzi-config.env
export KAFKA_CONTROLLER_NODE_SELECTORS="0:node-a,1:node-b,2:node-c"
export KAFKA_BROKER_NODE_SELECTORS="0:node-a,1:node-b,2:node-c"
./strimzi-setup.sh
```

A pod runs on the node of the volume it binds to. The volume index is not the Kafka node id; Strimzi numbers pods across both pools. See the [node selector guide](../../NODE_SELECTOR_GUIDE.md) for more layouts.

## Files

| File | Resource |
| --- | --- |
| `strimzi-config.env` | Settings for the script and every manifest |
| `strimzi-setup.sh` | Renders and applies everything below |
| `strimzi-storageclass.yaml` | StorageClass `strimzi-local` (no provisioner, `WaitForFirstConsumer`) |
| `strimzi-controller-volumes.yaml`, `strimzi-broker-volumes.yaml` | One PersistentVolume, rendered once per replica with `STRIMZI_VOLUME_INDEX` and `STRIMZI_VOLUME_NODE` |
| `axonops-agent-secret.yaml` | Secret `<cluster>-axonops-agent`, read by every Kafka container |
| `kafka-node-pool-controller.yaml`, `kafka-node-pool-brokers.yaml` | KafkaNodePools `controller` and `broker`. Their claims select only the volumes labelled for their pool. |
| `kafka-cluster.yaml` | Kafka `<cluster>` |

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `KAFKA_NAMESPACE` | `kafka` | Namespace for the Kafka resources |
| `STRIMZI_CLUSTER_NAME` | `my-cluster` | Kafka resource name, also part of the PV names and paths |
| `STRIMZI_CONTROLLER_REPLICAS` / `STRIMZI_BROKER_REPLICAS` | `3` / `3` | Pool sizes. One volume is created per replica. |
| `STRIMZI_CONTROLLER_STORAGE_SIZE` / `STRIMZI_BROKER_STORAGE_SIZE` | `10Gi` / `20Gi` | Size requested and declared on each PV. hostPath does not enforce it. |
| `KAFKA_REPLICATION_FACTOR` / `KAFKA_MIN_INSYNC_REPLICAS` | `3` / `2` | Use `1` / `1` with a single broker |
| `STRIMZI_HOST_BASE_DIR` | `/data/strimzi` | Parent directory of the volumes on each node |
| `STRIMZI_HOST_UID` / `STRIMZI_HOST_GID` | `1001` / `1001` | Owner of the directories. Kafka runs as UID 1001. |
| `STRIMZI_LOCAL_STORAGE_CLASS` | `strimzi-local` | StorageClass for the PVs |
| `STRIMZI_NODE_HOSTNAME` | empty | Node for unmapped volumes. Found automatically on a single-node cluster. |
| `KAFKA_CONTROLLER_NODE_SELECTORS` / `KAFKA_BROKER_NODE_SELECTORS` | empty | `<index>:<node>,...`. `broker-0`, `controller-0` and `ctrl-0` are accepted as indices. |
| `STRIMZI_CREATE_HOST_DIRS` | `false` | Create the directories with `sudo` on the machine running the script. Only useful when it is the node. |
| `KAFKA_RACK_TOPOLOGY_KEY` | `kubernetes.io/hostname` | Node label for rack awareness |
| `STRIMZI_VERSION` | `$STRIMZI_OPERATOR_VERSION` | Installed operator version, used for the image tag. Set it when the operator was already installed at another version. |
| `KAFKA_VERSION`, `KAFKA_CONTAINER_IMAGE` | `4.3.0`, AxonOps image | As in the [cloud example](../cloud/README.md#configuration) |
| `AXONOPS_NAMESPACE` | `axonops` | Namespace of the AxonOps server |
| `AXON_AGENT_*` | self-hosted server in `AXONOPS_NAMESPACE`, TLS disabled | As in the [on-premises example](../on-premises/README.md#configuration) |
| `STRIMZI_OPERATOR_INSTALL` / `STRIMZI_OPERATOR_NAMESPACE` / `STRIMZI_OPERATOR_VERSION` | `true` / `strimzi` / `1.1.0` | Operator install when its CRDs are missing. Script only. |
| `HELM_WAIT` | `true` | Install the operator with `helm --wait`. Script only. |
| `RENDER_ONLY` | `false` | Write `generated/strimzi-local-disk.yaml`, print the directories and the commands a real run would execute, apply nothing. Script only. |
| `KAFKA_READY_TIMEOUT` | `600s` | How long to wait for the Kafka resource. Script only. |

## Verify

```bash
kubectl get kafka,kafkanodepool,pvc -n "$KAFKA_NAMESPACE"
kubectl get pv -l strimzi.io/cluster="$STRIMZI_CLUSTER_NAME"
kubectl get pods -n "$KAFKA_NAMESPACE" -o wide
```

| Symptom | Cause |
| --- | --- |
| PVC `Pending`, event `didn't find available persistent volumes to bind` | Fewer PVs than replicas, or the size in the PV is smaller than the claim |
| Pod `ContainerCreating`, event `hostPath type check failed` | The directory does not exist on that node |
| Kafka container exits with `AccessDeniedException` | The directory is not owned by UID 1001 |

## Remove

```bash
kubectl delete kafka "$STRIMZI_CLUSTER_NAME" -n "$KAFKA_NAMESPACE"
kubectl delete kafkanodepool controller broker -n "$KAFKA_NAMESPACE"
kubectl delete secret "$STRIMZI_CLUSTER_NAME-axonops-agent" -n "$KAFKA_NAMESPACE"
kubectl delete pvc -n "$KAFKA_NAMESPACE" -l strimzi.io/cluster="$STRIMZI_CLUSTER_NAME"
kubectl delete pv -l strimzi.io/cluster="$STRIMZI_CLUSTER_NAME"
# The data stays on the nodes until you delete the directories:
# sudo rm -rf /data/strimzi/my-cluster
```

## Related

- [Node selector guide](../../NODE_SELECTOR_GUIDE.md)
- [Strimzi deployment guide](../../STRIMZI_DEPLOYMENT.md)
