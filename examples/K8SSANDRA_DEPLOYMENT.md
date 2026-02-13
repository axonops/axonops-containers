# K8ssandra Deployment Guide

This guide covers deploying Apache Cassandra using the K8ssandra operator on Kubernetes, with optional AxonOps monitoring integration.

## Quick Start

```bash
# 1. Install K8ssandra operator
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update
helm install k8ssandra-operator k8ssandra/k8ssandra-operator -n k8ssandra-operator --create-namespace

# 2. Configure and deploy cluster
cd k8ssandra/
export $(grep -v '^#' k8ssandra-config.env | xargs)
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

---

## Overview

K8ssandra is a production-ready platform for running Apache Cassandra on Kubernetes. This deployment uses:

- **K8ssandra Operator** - Kubernetes operator for managing Cassandra clusters
- **AxonOps Images** - Cassandra images with embedded AxonOps agent
- **AxonOps Cloud** - Optional monitoring and management integration

### Features

- Automated deployment and scaling
- Rolling upgrades and repairs
- Backup and restore capabilities
- AxonOps monitoring integration

## Prerequisites

1. **Kubernetes Cluster** (v1.21+)
   - Single-node or multi-node supported
2. **Required Tools**:
   - `kubectl` - Kubernetes CLI
   - `helm` - Helm package manager v3.x
   - `envsubst` - Variable substitution (part of `gettext` package)
3. **Storage**: PersistentVolume support or local-path provisioner
4. **Optional**: AxonOps account for monitoring integration

## Installing K8ssandra Operator

### Step 1: Add Helm Repository

```bash
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update
```

### Step 2: Install the Operator

```bash
# Create namespace and install operator
helm install k8ssandra-operator k8ssandra/k8ssandra-operator \
  -n k8ssandra-operator \
  --create-namespace
```

### Step 3: Verify Installation

```bash
# Check operator pods
kubectl get pods -n k8ssandra-operator

# Wait for operator to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=k8ssandra-operator \
  -n k8ssandra-operator \
  --timeout=300s
```

Expected output:

```text
NAME                                                READY   STATUS    RESTARTS   AGE
k8ssandra-operator-xxxxxxx-xxxxx                    1/1     Running   0          1m
k8ssandra-operator-cass-operator-xxxxxxx-xxxxx      1/1     Running   0          1m
```

## Configuration

### Environment Variables

Create or edit `k8ssandra/k8ssandra-config.env`:

```bash
# K8ssandra Cluster Configuration
K8SSANDRA_CLUSTER_NAME=axonops-k8ssandra
K8SSANDRA_NAMESPACE=k8ssandra-operator
CASSANDRA_VERSION=5.0.6
CASSANDRA_DC_NAME=dc1
CASSANDRA_DC_SIZE=3

# AxonOps Container Image
IMAGE_NAME=ghcr.io/axonops/cassandra:5.0.6

# Storage Configuration
STORAGE_CLASS=local-path
STORAGE_SIZE=10Gi

# Resource Limits
CPU_LIMIT=2
CPU_REQUEST=1
MEMORY_LIMIT=4Gi
MEMORY_REQUEST=2Gi
HEAP_SIZE=1G

# AxonOps Agent Configuration (for AxonOps Cloud)
AXON_AGENT_KEY=your-agent-key
AXON_AGENT_ORG=your-organization
AXON_AGENT_SERVER_HOST=agents.axonops.cloud
AXON_AGENT_SERVER_PORT=443
```

### Configuration Variables Reference

| Variable | Default | Description |
| --- | --- | --- |
| `K8SSANDRA_CLUSTER_NAME` | `axonops-k8ssandra` | Name of the Cassandra cluster |
| `K8SSANDRA_NAMESPACE` | `k8ssandra-operator` | Kubernetes namespace |
| `CASSANDRA_VERSION` | `5.0.6` | Cassandra version |
| `IMAGE_NAME` | `ghcr.io/axonops/cassandra:5.0.6` | AxonOps Cassandra image |
| `CASSANDRA_DC_NAME` | `dc1` | Datacenter name |
| `CASSANDRA_DC_SIZE` | `3` | Number of Cassandra nodes |
| `STORAGE_CLASS` | `local-path` | Kubernetes StorageClass |
| `STORAGE_SIZE` | `10Gi` | Storage per node |
| `AXON_AGENT_KEY` | - | AxonOps API key |
| `AXON_AGENT_ORG` | - | AxonOps organization name |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | AxonOps server hostname |
| `AXON_AGENT_SERVER_PORT` | `443` | AxonOps server port |

## Deployment

### Using envsubst

The example manifests use environment variable placeholders. Use `envsubst` to substitute values before applying:

```bash
cd k8ssandra/

# 1. Source configuration
export $(grep -v '^#' k8ssandra-config.env | xargs)

# 2. Apply cluster manifest with variable substitution
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

### Manual Deployment

Alternatively, edit the YAML file directly and apply:

```bash
# Edit the manifest
vi k8ssandra/cluster-axonops-ubi.yaml

# Apply directly
kubectl apply -f k8ssandra/cluster-axonops-ubi.yaml
```

### Wait for Cluster to be Ready

```bash
# Watch cluster status
kubectl get k8ssandraclusters -n k8ssandra-operator -w

# Check pods
kubectl get pods -n k8ssandra-operator -l cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME

# View cluster details
kubectl describe k8ssandracluster $K8SSANDRA_CLUSTER_NAME -n k8ssandra-operator
```

## Verifying the Deployment

### Check Cluster Status

```bash
# View K8ssandraCluster resource
kubectl get k8ssandraclusters -n k8ssandra-operator

# View CassandraDatacenter
kubectl get cassandradatacenters -n k8ssandra-operator

# View all pods
kubectl get pods -n k8ssandra-operator -o wide
```

### Test Cassandra Connectivity

```bash
# Get a shell in a Cassandra pod
kubectl exec -it ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- cqlsh

# Run a simple query
cqlsh> SELECT cluster_name, listen_address FROM system.local;
cqlsh> DESCRIBE KEYSPACES;
```

### Check AxonOps Integration

If using AxonOps Cloud:

```bash
# Check agent logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator | grep -i axon

# Verify agent environment variables
kubectl exec ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- env | grep AXON
```

Then check the AxonOps dashboard at [https://console.axonops.cloud](https://console.axonops.cloud) to verify your cluster appears.

## AxonOps Integration Options

### Option 1: AxonOps Cloud (SaaS)

Use AxonOps Cloud for managed monitoring:

1. Sign up at [https://axonops.cloud](https://axonops.cloud)
2. Create an organization and get your API key
3. Configure the agent environment variables in `k8ssandra-config.env`:

```bash
AXON_AGENT_KEY=your-api-key
AXON_AGENT_ORG=your-organization
AXON_AGENT_SERVER_HOST=agents.axonops.cloud
AXON_AGENT_SERVER_PORT=443
```

### Option 2: Self-Hosted AxonOps

Deploy AxonOps on-premises first, then configure Cassandra to connect:

```bash
# Deploy AxonOps (see AXONOPS_DEPLOYMENT.md)
cd ../axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh
source axonops-config.env

# Configure K8ssandra to use self-hosted AxonOps
export AXON_AGENT_SERVER_HOST=axon-server-agent.axonops.svc.cluster.local
export AXON_AGENT_SERVER_PORT=1888
export AXON_AGENT_ORG=$AXON_SERVER_ORG_NAME

# Deploy K8ssandra
cd ../k8ssandra/
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

## Scaling the Cluster

### Add Nodes

```bash
# Edit the datacenter size
kubectl patch k8ssandracluster $K8SSANDRA_CLUSTER_NAME \
  -n k8ssandra-operator \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/cassandra/datacenters/0/size", "value": 5}]'

# Or edit the manifest and reapply
export CASSANDRA_DC_SIZE=5
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

### Remove Nodes

Scale down carefully to avoid data loss:

```bash
# Decommission nodes first, then reduce size
kubectl patch k8ssandracluster $K8SSANDRA_CLUSTER_NAME \
  -n k8ssandra-operator \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/cassandra/datacenters/0/size", "value": 3}]'
```

## Troubleshooting

### Pods Stuck in Pending

```bash
# Check PVC status
kubectl get pvc -n k8ssandra-operator

# Check events
kubectl get events -n k8ssandra-operator --sort-by='.lastTimestamp'

# Verify storage class exists
kubectl get storageclass
```

### Cassandra Not Starting

```bash
# Check pod logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator

# Check init container logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -c server-config-init

# Describe pod for events
kubectl describe pod ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator
```

### AxonOps Agent Not Connecting

```bash
# Verify environment variables
kubectl exec ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- env | grep AXON

# Test network connectivity to AxonOps
kubectl exec ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- nc -zv $AXON_AGENT_SERVER_HOST $AXON_AGENT_SERVER_PORT

# Check agent logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator | grep -i "axon\|agent"
```

## Cleanup

### Remove Cassandra Cluster

```bash
# Delete the K8ssandraCluster
kubectl delete k8ssandracluster $K8SSANDRA_CLUSTER_NAME -n k8ssandra-operator

# Delete PVCs (WARNING: deletes all data)
kubectl delete pvc -l cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME \
  -n k8ssandra-operator
```

### Remove K8ssandra Operator

```bash
# Uninstall operator
helm uninstall k8ssandra-operator -n k8ssandra-operator

# Delete namespace
kubectl delete namespace k8ssandra-operator
```

## Production Considerations

1. **Storage**: Use high-performance SSDs with appropriate IOPS
2. **Resources**: Allocate sufficient CPU and memory (recommend 4+ cores, 8GB+ RAM per node)
3. **Replication**: Use replication factor of 3 for production
4. **Backup**: Configure Medusa for automated backups
5. **Monitoring**: Use AxonOps for comprehensive monitoring and alerting
6. **Security**: Enable TLS encryption and authentication
7. **Network**: Use dedicated network for inter-node communication

## Additional Resources

- **K8ssandra Documentation**: [https://docs.k8ssandra.io/](https://docs.k8ssandra.io/)
- **K8ssandra GitHub**: [https://github.com/k8ssandra/k8ssandra](https://github.com/k8ssandra/k8ssandra)
- **AxonOps Documentation**: [https://docs.axonops.com](https://docs.axonops.com)
- **AxonOps Agent Setup**: [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Apache Cassandra Documentation**: [https://cassandra.apache.org/doc/](https://cassandra.apache.org/doc/)
- **Example Manifests**: [k8ssandra/](k8ssandra/)

---

**Last Updated:** 2026-02-13
