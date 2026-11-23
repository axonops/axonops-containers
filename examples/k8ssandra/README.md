# K8ssandra Cassandra with the AxonOps agent

A Cassandra cluster run by the K8ssandra operator, using the AxonOps Cassandra image so every node runs the AxonOps agent. The agents report to AxonOps Cloud by default, or to a self-hosted AxonOps server.

| Setting | Default |
| --- | --- |
| Cassandra | 5.0.9 |
| Datacenter | `dc1`, 3 nodes |
| Storage | 10Gi data + 2Gi agent state per node, default StorageClass |
| Resources | 1-2 CPU, 2-4 GiB memory, 1G heap per node |

## Prerequisites

- Kubernetes 1.27 or newer, with a default StorageClass
- The K8ssandra operator and cert-manager (see [K8SSANDRA_DEPLOYMENT.md](../K8SSANDRA_DEPLOYMENT.md#install-the-k8ssandra-operator))
- `envsubst` (package `gettext`)
- An AxonOps Cloud organisation and agent key, or a self-hosted AxonOps server

## Quick start

```bash
cd examples/k8ssandra
source k8ssandra-config.env
export AXON_AGENT_ORG=your-org
export AXON_AGENT_KEY=your-agent-key

envsubst < axonops-agent-secret.yaml | kubectl apply -f -
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
kubectl wait k8ssandracluster/"$K8SSANDRA_CLUSTER_NAME" -n "$K8SSANDRA_NAMESPACE" \
  --for=condition=CassandraInitialized --timeout=20m
```

The Secret must exist before the cluster: the Cassandra container reads the agent settings from it and does not start without it.

## Files

| File | Resource |
| --- | --- |
| `k8ssandra-config.env` | Settings for both manifests |
| `axonops-agent-secret.yaml` | Secret `<cluster>-axonops-agent` with the agent settings |
| `cluster-axonops-ubi.yaml` | K8ssandraCluster `<cluster>` with the AxonOps image and a PVC for `/var/lib/axonops` |

Pods are named `<cluster>-<dc>-default-sts-<n>`.

## Examples

Report to the self-hosted AxonOps server from [../axonops/](../axonops/):

```bash
source ../axonops/axonops-config.env
source k8ssandra-config.env
export AXON_AGENT_ORG="$AXON_SERVER_ORG_NAME" AXON_AGENT_KEY=not-used
export AXON_AGENT_SERVER_HOST="axon-server-agent.$AXONOPS_NAMESPACE.svc.cluster.local"
export AXON_AGENT_SERVER_PORT="$AXON_SERVER_AGENTS_PORT" AXON_AGENT_TLS_MODE=disabled
envsubst < axonops-agent-secret.yaml | kubectl apply -f -
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

Deploy into a namespace other than the operator's. The operator must have been installed with `--set global.clusterScoped=true`:

```bash
source k8ssandra-config.env
export K8SSANDRA_NAMESPACE=cassandra
kubectl create namespace "$K8SSANDRA_NAMESPACE"
envsubst < axonops-agent-secret.yaml | kubectl apply -f -
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

Scale the datacenter to 5 nodes:

```bash
export CASSANDRA_DC_SIZE=5
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `K8SSANDRA_OPERATOR_NAMESPACE` | `k8ssandra-operator` | Namespace of the operator |
| `K8SSANDRA_NAMESPACE` | `k8ssandra-operator` | Namespace of the cluster. Must equal the operator namespace unless the operator is cluster-scoped. |
| `K8SSANDRA_CLUSTER_NAME` | `my-cassandra` | K8ssandraCluster name and Cassandra cluster name |
| `CASSANDRA_VERSION` | `5.0.9` | Cassandra version |
| `IMAGE_NAME` | `ghcr.io/axonops/k8ssandra/cassandra:5.0.9` | AxonOps image. The default floating tag follows the latest build for `CASSANDRA_VERSION`; in production pin it by SHA256 digest. Must match `CASSANDRA_VERSION`. |
| `CASSANDRA_DC_NAME` / `CASSANDRA_DC_SIZE` | `dc1` / `3` | Datacenter name and node count |
| `STORAGE_CLASS` | empty (cluster default) | StorageClass for both PVCs |
| `STORAGE_SIZE` | `10Gi` | Cassandra data volume |
| `AXONOPS_STORAGE_SIZE` | `2Gi` | Agent state volume at `/var/lib/axonops`. Most StorageClasses cannot shrink it later. |
| `CPU_REQUEST` / `CPU_LIMIT` | `1` / `2` | CPU per node |
| `MEMORY_REQUEST` / `MEMORY_LIMIT` | `2Gi` / `4Gi` | Memory per node |
| `HEAP_SIZE` | `1G` | Cassandra heap |
| `AXON_AGENT_ORG` | `your-org` | AxonOps organisation |
| `AXON_AGENT_KEY` | none, required for AxonOps Cloud | Agent key. Export it; do not write it in the file. |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | AxonOps endpoint |
| `AXON_AGENT_SERVER_PORT` | `443` | `1888` for a self-hosted server |
| `AXON_AGENT_TLS_MODE` | `TLS` | `disabled` for a self-hosted server without TLS on the agent port |

## Verify

```bash
kubectl get k8ssandracluster,cassandradatacenter,pods -n "$K8SSANDRA_NAMESPACE"
POD="$K8SSANDRA_CLUSTER_NAME-$CASSANDRA_DC_NAME-default-sts-0"
kubectl logs -n "$K8SSANDRA_NAMESPACE" "$POD" -c cassandra | grep -i axon
```

## Remove

```bash
kubectl delete k8ssandracluster "$K8SSANDRA_CLUSTER_NAME" -n "$K8SSANDRA_NAMESPACE"
kubectl delete secret "$K8SSANDRA_CLUSTER_NAME-axonops-agent" -n "$K8SSANDRA_NAMESPACE"
# Deletes the Cassandra data:
kubectl delete pvc -n "$K8SSANDRA_NAMESPACE" -l cassandra.datastax.com/cluster="$K8SSANDRA_CLUSTER_NAME"
```

## Related

- [K8ssandra deployment guide](../K8SSANDRA_DEPLOYMENT.md)
- [AxonOps K8ssandra image](../../k8ssandra/README.md)
- [K8ssandra documentation](https://docs.k8ssandra.io/)
