# K8ssandra Setup Script

## Overview
The `k8ssandra-setup.sh` script automates the deployment of a production-ready K8ssandra (Kubernetes + Cassandra) cluster with flexible configuration options.

## Features

- **Multi-rack topology** for high availability (default: 3 racks)
- **Configurable cluster size** (nodes per rack)
- **Dual storage modes**: hostPath (local development) and PVC (production)
- **Automatic K8ssandra operator installation** (latest version)
- **AxonOps integration** for monitoring (optional)
- **cert-manager integration** for TLS certificates
- **Idempotent deployment** - safe to re-run

## Prerequisites

- Kubernetes cluster (1.21+)
- kubectl configured with cluster access
- Helm 3.x installed
- Sufficient resources for Cassandra nodes (minimum 2GB RAM per node)

## Quick Start

### Default Installation (3-node cluster with hostPath storage)
```bash
./k8ssandra-setup.sh
```

### Production Installation (PVC with specific storage class)
```bash
STORAGE_MODE=pvc \
STORAGE_CLASS=fast-ssd \
STORAGE_SIZE=100Gi \
NODES_PER_RACK=2 \
./k8ssandra-setup.sh
```

## Configuration Options

### Storage Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `STORAGE_MODE` | `hostPath` | Storage mode: `hostPath` or `pvc` |
| `STORAGE_CLASS` | (empty) | StorageClass for PVC mode (empty = default) |
| `STORAGE_SIZE` | `10Gi` | Size of persistent volumes |

### Cluster Topology

| Variable | Default | Description |
|----------|---------|-------------|
| `K8SSANDRA_CLUSTER_NAME` | `my-k8ssandra-cluster` | Cluster name |
| `CASSANDRA_VERSION` | `4.1.3` | Cassandra version |
| `NODES_PER_RACK` | `1` | Number of Cassandra nodes per rack |
| `RACK_COUNT` | `3` | Number of racks (availability zones) |
| `REPLICATION_FACTOR` | `3` | Default keyspace replication factor |

### Resource Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `CASSANDRA_HEAP_SIZE` | `1Gi` | JVM heap size |
| `CASSANDRA_HEAP_MAX` | `1Gi` | Maximum JVM heap size |

### AxonOps Integration

| Variable | Default | Description |
|----------|---------|-------------|
| `AXONOPS_ENABLED` | `auto` | Enable AxonOps: `auto`, `true`, or `false` |
| `AXON_AGENT_ORG` | `your-org` | AxonOps organization name |
| `AXON_AGENT_SERVER_HOST` | Auto-detected | AxonOps server host |
| `AXON_AGENT_SERVER_PORT` | `1888` | AxonOps server port |

## Storage Modes

### hostPath Mode (Development)
- Uses Rancher's local-path-provisioner
- Automatically installs provisioner if not present
- Suitable for single-node or development clusters
- Data stored on local node filesystem

Example:
```bash
STORAGE_MODE=hostPath ./k8ssandra-setup.sh
```

### PVC Mode (Production)
- Uses existing StorageClass in your cluster
- Suitable for production deployments
- Supports any CSI driver (AWS EBS, GCP PD, Azure Disk, etc.)

Example:
```bash
STORAGE_MODE=pvc \
STORAGE_CLASS=gp3 \
STORAGE_SIZE=500Gi \
./k8ssandra-setup.sh
```

## Deployment Examples

### Small Development Cluster (3 nodes)
```bash
STORAGE_MODE=hostPath \
NODES_PER_RACK=1 \
CASSANDRA_HEAP_SIZE=512Mi \
./k8ssandra-setup.sh
```

### Medium Production Cluster (6 nodes)
```bash
STORAGE_MODE=pvc \
STORAGE_CLASS=fast-ssd \
STORAGE_SIZE=200Gi \
NODES_PER_RACK=2 \
CASSANDRA_HEAP_SIZE=4Gi \
./k8ssandra-setup.sh
```

### Large Production Cluster (9 nodes)
```bash
STORAGE_MODE=pvc \
STORAGE_CLASS=ultra-ssd \
STORAGE_SIZE=1Ti \
NODES_PER_RACK=3 \
CASSANDRA_HEAP_SIZE=8Gi \
REPLICATION_FACTOR=3 \
./k8ssandra-setup.sh
```

### With AxonOps Monitoring
```bash
# First deploy AxonOps
./axonops-setup.sh

# Then deploy K8ssandra with integration
AXONOPS_ENABLED=true \
AXON_AGENT_ORG=my-company \
./k8ssandra-setup.sh
```

## Post-Installation

### Access CQL Shell
```bash
# Direct exec into pod
kubectl exec -it -n k8ssandra \
  my-k8ssandra-cluster-dc1-rack1-sts-0 -- cqlsh

# Or port-forward and use local cqlsh
kubectl port-forward -n k8ssandra \
  svc/my-k8ssandra-cluster-dc1-service 9042:9042

# In another terminal
cqlsh localhost 9042 -u <username> -p <password>
```

### Get Database Credentials
```bash
# Username
kubectl get secret my-k8ssandra-cluster-superuser -n k8ssandra \
  -o jsonpath='{.data.username}' | base64 -d

# Password
kubectl get secret my-k8ssandra-cluster-superuser -n k8ssandra \
  -o jsonpath='{.data.password}' | base64 -d
```

### Check Cluster Status
```bash
# K8ssandra cluster status
kubectl get k8ssandracluster -n k8ssandra

# Pod status
kubectl get pods -n k8ssandra

# Detailed cluster information
kubectl describe k8ssandracluster my-k8ssandra-cluster -n k8ssandra
```

## Monitoring

### Prometheus Metrics
The cluster automatically exposes Prometheus metrics on port 9103:
```bash
kubectl port-forward -n k8ssandra \
  my-k8ssandra-cluster-dc1-rack1-sts-0 9103:9103

# Access metrics
curl http://localhost:9103/metrics
```

### Reaper UI (Repair Management)
Access the Reaper UI for repair management:
```bash
kubectl port-forward -n k8ssandra \
  svc/my-k8ssandra-cluster-reaper-service 8080:8080

# Open http://localhost:8080 in browser
```

## Troubleshooting

### Pods Not Starting
```bash
# Check pod events
kubectl describe pod -n k8ssandra <pod-name>

# Check logs
kubectl logs -n k8ssandra <pod-name> -c cassandra

# Check PVC status
kubectl get pvc -n k8ssandra
```

### Storage Issues
```bash
# Check StorageClass
kubectl get storageclass

# Check PV provisioning
kubectl get pv

# For hostPath mode, check local-path-provisioner
kubectl logs -n local-path-storage \
  -l app=local-path-provisioner
```

### Operator Issues
```bash
# Check operator logs
kubectl logs -n k8ssandra-operator \
  -l app.kubernetes.io/name=k8ssandra-operator

# Check CRDs
kubectl get crd | grep k8ssandra
```

## Scaling

### Add Nodes to Existing Rack
```bash
# Edit the K8ssandraCluster resource
kubectl edit k8ssandracluster my-k8ssandra-cluster -n k8ssandra

# Increase the size field under datacenters
```

### Add New Datacenter
Create a new datacenter by modifying the K8ssandraCluster spec:
```yaml
spec:
  cassandra:
    datacenters:
    - name: dc1  # existing
      size: 3
    - name: dc2  # new datacenter
      size: 3
      storageConfig:
        cassandraDataVolumeClaimSpec:
          storageClassName: fast-ssd
          resources:
            requests:
              storage: 100Gi
```

## Backup and Restore

### Enable Medusa Backup
Add to cluster configuration:
```yaml
spec:
  medusa:
    enabled: true
    storage:
      storageProvider: s3
      storageSecret: medusa-bucket-secret
      bucketName: cassandra-backups
```

### Create Backup
```bash
kubectl create -f - <<EOF
apiVersion: medusa.k8ssandra.io/v1alpha1
kind: MedusaBackup
metadata:
  name: backup-$(date +%Y%m%d-%H%M%S)
  namespace: k8ssandra
spec:
  cassandraDatacenter: dc1
EOF
```

## Uninstall

### Remove K8ssandra Cluster
```bash
# Delete cluster
kubectl delete k8ssandracluster my-k8ssandra-cluster -n k8ssandra

# Delete namespace
kubectl delete namespace k8ssandra

# Remove operator (optional)
helm uninstall k8ssandra-operator -n k8ssandra-operator
kubectl delete namespace k8ssandra-operator

# Remove local-path-provisioner (if using hostPath)
kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
```

## Advanced Configuration

### Custom Cassandra Configuration
Modify the generated `k8ssandra/k8ssandra-cluster.yaml` before applying:
```yaml
spec:
  cassandra:
    datacenters:
    - cassandraConfig:
        cassandraYaml:
          concurrent_reads: 64
          concurrent_writes: 64
          memtable_flush_writers: 4
```

### Node Affinity and Anti-Affinity
Ensure proper node labeling for rack-aware deployment:
```bash
# Label nodes for rack placement
kubectl label node node1 topology.kubernetes.io/zone=zone1
kubectl label node node2 topology.kubernetes.io/zone=zone2
kubectl label node node3 topology.kubernetes.io/zone=zone3
```

### TLS Configuration
Enable TLS for client and internode communication:
```yaml
spec:
  cassandra:
    serverEncryptionStores:
      keystoreSecret: cassandra-keystore
      truststoreSecret: cassandra-truststore
    clientEncryptionStores:
      keystoreSecret: client-keystore
      truststoreSecret: client-truststore
```

## Performance Tuning

### JVM Options
Adjust heap sizes based on available memory:
- Small (4GB RAM): `CASSANDRA_HEAP_SIZE=1Gi`
- Medium (8GB RAM): `CASSANDRA_HEAP_SIZE=2Gi`
- Large (16GB+ RAM): `CASSANDRA_HEAP_SIZE=4Gi` or more

### Storage Performance
- Use SSD-backed storage classes for production
- Set appropriate IOPS limits for cloud storage
- Consider local SSDs for highest performance

## Support

For issues or questions:
- K8ssandra Documentation: https://docs.k8ssandra.io/
- K8ssandra GitHub: https://github.com/k8ssandra/k8ssandra
- Cassandra Documentation: https://cassandra.apache.org/doc/