# AxonOps K8ssandra Cassandra Examples

This directory contains example manifests to deploy Apache Cassandra using K8ssandra with AxonOps monitoring.

## Overview

- **Cassandra Version**: 5.0.6
- **Operator**: K8ssandra
- **Nodes**: 3 replicas (configurable)
- **Storage**: 2Gi per node (configurable)
- **Monitoring**: AxonOps Cloud integration

## Prerequisites

- A Kubernetes cluster with the [K8ssandra operator](https://k8ssandra.io/) installed
- `envsubst` command available (part of `gettext` package)
- AxonOps account (optional, for monitoring)

## Installing K8ssandra Operator

```bash
# Add Helm repository
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update

# Install the operator. Set the global scope to true if you would like to use
# multiple namespaces
helm install k8ssandra-operator k8ssandra/k8ssandra-operator \
  -n k8ssandra-operator \
  --create-namespace \
  --set global.clusterScoped=true

# Verify installation
kubectl get pods -n k8ssandra-operator
```

## Configuration

A `k8ssandra-config.env` file is provided with default configuration values.

```bash
# Review and edit the configuration
cat k8ssandra-config.env

# Source the environment variables
export $(grep -v '^#' k8ssandra-config.env | xargs)
```

### Configuration Variables

| Variable | Default | Description |
| --- | --- | --- |
| `IMAGE_NAME` | `ghcr.io/axonops/cassandra:5.0.6` | AxonOps Cassandra image |
| `K8SSANDRA_CLUSTER_NAME` | `axonops-k8ssandra-5` | Cluster name |
| `K8SSANDRA_NAMESPACE` | `k8ssandra-operator` | Kubernetes namespace |
| `CASSANDRA_DC_NAME` | `dc1` | Datacenter name |
| `CASSANDRA_DC_SIZE` | `3` | Number of nodes |
| `STORAGE_CLASS` | `` | StorageClass name |
| `STORAGE_SIZE` | `2Gi` | Storage per node |
| `AXON_AGENT_KEY` | - | AxonOps API key |
| `AXON_AGENT_ORG` | - | AxonOps organization |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | AxonOps server |
| `AXON_AGENT_SERVER_PORT` | `443` | AxonOps port |

## Manifests

| File | Description |
| --- | --- |
| `k8ssandra-config.env` | Environment variables for configuration |
| `cluster-axonops-ubi.yaml` | K8ssandraCluster resource with AxonOps agent |

## Deployment

### Using envsubst

The manifests use environment variable placeholders (`${VAR_NAME}`). Use `envsubst` to substitute the values before applying:

```bash
# 1. Source the configuration
export $(grep -v '^#' k8ssandra-config.env | xargs)

# 2. Apply the cluster manifest with variable substitution
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

### One-liner Deployment

```bash
export $(grep -v '^#' k8ssandra-config.env | xargs) && \
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

### Generate Processed Manifest

To generate a processed manifest for review or GitOps:

```bash
export $(grep -v '^#' k8ssandra-config.env | xargs)
envsubst < cluster-axonops-ubi.yaml > processed-cluster.yaml
```

## Verification

```bash
# Check the K8ssandraCluster status
kubectl get k8ssandraclusters -n k8ssandra-operator

# Check CassandraDatacenter
kubectl get cassandradatacenters -n k8ssandra-operator

# Check pods
kubectl get pods -n k8ssandra-operator

# Connect to Cassandra
kubectl exec -it axonops-k8ssandra-5-dc1-default-sts-0 \
  -n k8ssandra-operator -- cqlsh
```

## AxonOps Integration

### AxonOps Cloud

1. Sign up at [https://axonops.cloud](https://axonops.cloud)
2. Get your API key and organization name
3. Update `k8ssandra-config.env` with your credentials:

```bash
AXON_AGENT_KEY=your-api-key
AXON_AGENT_ORG=your-organization
AXON_AGENT_SERVER_HOST=agents.axonops.cloud
AXON_AGENT_SERVER_PORT=443
```

### Self-Hosted AxonOps

For on-premises AxonOps, update the connection details:

```bash
AXON_AGENT_SERVER_HOST=axon-server-agent.axonops.svc.cluster.local
AXON_AGENT_SERVER_PORT=1888
```

## Cleanup

```bash
# Delete the cluster
kubectl delete k8ssandracluster axonops-k8ssandra-5 -n k8ssandra-operator

# Delete PVCs (WARNING: deletes data)
kubectl delete pvc -l cassandra.datastax.com/cluster=axonops-k8ssandra-5 \
  -n k8ssandra-operator
```

## Related Documentation

- [Full K8ssandra Deployment Guide](../K8SSANDRA_DEPLOYMENT.md)
- [AxonOps Deployment Guide](../AXONOPS_DEPLOYMENT.md)
- [K8ssandra Documentation](https://docs.k8ssandra.io/)
