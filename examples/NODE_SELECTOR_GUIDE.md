# Strimzi Node Selector Guide

**English** | [Français](NODE_SELECTOR_GUIDE.fr.md) | [Español](NODE_SELECTOR_GUIDE.es.md) | [Galego](NODE_SELECTOR_GUIDE.gl.md)

This guide covers volume placement for the [strimzi/local-disk/](strimzi/local-disk/) example, where Kafka data lives in hostPath directories on chosen nodes. Use it to put brokers on nodes with fast disks, keep controllers off busy nodes, or spread replicas across racks. The [strimzi/cloud/](strimzi/cloud/) and [strimzi/on-premises/](strimzi/on-premises/) examples use dynamically provisioned volumes and do not need it.

## How placement works

`strimzi-setup.sh` creates one PersistentVolume per replica, named `<cluster>-controller-<n>` or `<cluster>-broker-<n>`, each with a node affinity for one node. Each node pool claims only the volumes labelled for that pool. Because the StorageClass binds on first use, the scheduler places each pod on a node that still has a free volume of its pool, and the pod stays on that node afterwards.

The volume index `<n>` is not the Kafka node id. Strimzi numbers pods across both pools, so `my-cluster-broker-3` can use volume `my-cluster-broker-0`. Plan nodes per pool, not per pod name.

## Settings

| Variable | Default | Description |
| --- | --- | --- |
| `KAFKA_CONTROLLER_NODE_SELECTORS` | empty | Controller volumes, `<index>:<node>,...` |
| `KAFKA_BROKER_NODE_SELECTORS` | empty | Broker volumes, `<index>:<node>,...` |
| `STRIMZI_NODE_HOSTNAME` | empty | Node for every volume without a mapping. Found automatically on a single-node cluster. |
| `STRIMZI_CONTROLLER_REPLICAS` / `STRIMZI_BROKER_REPLICAS` | `3` / `3` | Number of volumes per pool |
| `STRIMZI_HOST_BASE_DIR` | `/data/strimzi` | Parent directory on the nodes |

The index can be written as `0`, `broker-0`, `controller-0` or `ctrl-0`. The script stops when an index is out of range, a pair has no node, a node does not exist, or a volume has no node.

Node names must match `kubectl get nodes` exactly.

## Layouts

All on one node:

```bash
export STRIMZI_NODE_HOSTNAME=worker-1
./strimzi-setup.sh
```

One controller and one broker per node:

```bash
export KAFKA_CONTROLLER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
./strimzi-setup.sh
```

Brokers on NVMe nodes, controllers on general nodes:

```bash
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-1,1:nvme-2,2:nvme-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:general-1,1:general-2,2:general-3"
./strimzi-setup.sh
```

One broker pinned, the rest on a default node:

```bash
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-1"
export STRIMZI_NODE_HOSTNAME=worker-1
./strimzi-setup.sh
```

Keep the three controllers on three different nodes in production: the KRaft quorum survives the loss of one node only if no two controllers share it.

## Preparing the nodes

Run the script with `RENDER_ONLY=true` first. It prints the directories each node needs:

```bash
source strimzi-config.env
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
RENDER_ONLY=true ./strimzi-setup.sh
```

```text
  # on worker-1
  sudo mkdir -p /data/strimzi/my-cluster/controller-0 /data/strimzi/my-cluster/broker-0
  sudo chown -R 1001:1001 /data/strimzi/my-cluster
```

Run those commands on each node, then run the script without `RENDER_ONLY`. The rendered manifests are in `generated/strimzi-local-disk.yaml`.

## Verify

```bash
kubectl get pods -n "$KAFKA_NAMESPACE" -o wide
kubectl get pv -l strimzi.io/cluster="$STRIMZI_CLUSTER_NAME" \
  -o custom-columns=PV:.metadata.name,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0],CLAIM:.spec.claimRef.name
```

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| Pod `Pending`, `didn't find available persistent volumes to bind` | The pool has fewer volumes than replicas, or the volumes sit on nodes that cannot run the pod (taints, resources). Check `kubectl get pv`. |
| Pod `ContainerCreating`, `hostPath type check failed` | The directory is missing on that node. Create it. |
| Kafka exits with `AccessDeniedException` | The directory is not owned by UID 1001. Run the `chown` command. |
| `Node 'x' not found` from the script | Typo in a selector. Compare with `kubectl get nodes`. |

## Related

- [strimzi/local-disk/README.md](strimzi/local-disk/README.md)
- [Strimzi deployment guide](STRIMZI_DEPLOYMENT.md)
- [Kubernetes local and hostPath volumes](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath)
