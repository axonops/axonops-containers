# K8ssandra Deployment Guide

**English** | [Français](K8SSANDRA_DEPLOYMENT.fr.md) | [Español](K8SSANDRA_DEPLOYMENT.es.md) | [Galego](K8SSANDRA_DEPLOYMENT.gl.md)

This guide deploys Apache Cassandra with the K8ssandra operator and the AxonOps Cassandra image, which runs the AxonOps agent next to Cassandra. The manifests and every setting are in [k8ssandra/](k8ssandra/README.md).

## Install the K8ssandra operator

The operator needs cert-manager. Install both once per Kubernetes cluster:

```bash
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true --wait

export K8SSANDRA_OPERATOR_NAMESPACE=k8ssandra-operator
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update
helm upgrade --install k8ssandra-operator k8ssandra/k8ssandra-operator \
  --version 1.29.0 \
  --namespace "$K8SSANDRA_OPERATOR_NAMESPACE" --create-namespace \
  --wait
```

Installed like this, the operator only manages clusters in its own namespace, which is the example default. To deploy clusters in other namespaces, add `--set global.clusterScoped=true`.

## Deploy a cluster

```bash
cd examples/k8ssandra
source k8ssandra-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key

envsubst < axonops-agent-secret.yaml | kubectl apply -f -
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
kubectl wait k8ssandracluster/"$K8SSANDRA_CLUSTER_NAME" -n "$K8SSANDRA_NAMESPACE" \
  --for=condition=CassandraInitialized --timeout=20m
```

Apply the Secret first: the Cassandra container reads the agent settings from it.

## AxonOps target

| Target | Settings |
| --- | --- |
| AxonOps Cloud (default) | `AXON_AGENT_ORG`, `AXON_AGENT_KEY`; server `agents.axonops.cloud:443`, TLS |
| Self-hosted AxonOps | `AXON_AGENT_SERVER_HOST=axon-server-agent.$AXONOPS_NAMESPACE.svc.cluster.local`, `AXON_AGENT_SERVER_PORT=1888`, `AXON_AGENT_TLS_MODE=disabled` |

For a self-hosted server installed from [axonops/](axonops/), source `axonops/axonops-config.env` first and follow the [self-hosted example](k8ssandra/README.md#examples).

## Image versions

`IMAGE_NAME` must match `CASSANDRA_VERSION`. Tags read `<cassandra>-v<k8ssandra api>-<image>`, for example `5.0.9-v0.1.125-1.6.3`. Published tags are listed in [VERSIONS.md](../VERSIONS.md) and the [K8ssandra image README](../k8ssandra/README.md).

## Scaling

Change `CASSANDRA_DC_SIZE` and apply the manifest again:

```bash
export CASSANDRA_DC_SIZE=5
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

When scaling down, the operator decommissions the removed nodes one at a time. Make sure the remaining nodes have room for their data first.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Pod `CreateContainerConfigError` | The agent Secret is missing: `kubectl get secret "$K8SSANDRA_CLUSTER_NAME-axonops-agent" -n "$K8SSANDRA_NAMESPACE"` |
| Pods `Pending` | `kubectl get pvc -n "$K8SSANDRA_NAMESPACE"`; set `STORAGE_CLASS` if there is no default StorageClass |
| Nothing created after apply | The cluster namespace differs from the operator namespace and the operator is not cluster-scoped |
| Cluster missing in AxonOps | `kubectl logs <pod> -c cassandra \| grep -i axon` for connection errors; check host, port, TLS mode and key |

## Production notes

- Give each node at least 4 CPU and 8 GiB of memory, and raise `HEAP_SIZE` with it.
- Use fast SSD-backed StorageClasses.
- Use replication factor 3 for application keyspaces.
- Configure backups, for example with K8ssandra Medusa.

## Related

- [k8ssandra/README.md](k8ssandra/README.md): files and every setting
- [AxonOps K8ssandra image](../k8ssandra/README.md)
- [K8ssandra documentation](https://docs.k8ssandra.io/)
