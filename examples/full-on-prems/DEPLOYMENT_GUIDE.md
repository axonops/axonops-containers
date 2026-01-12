# On-Premises Deployment Guide

Welcome to the on-premises deployment guide for AxonOps and data platform solutions on Kubernetes.

## Overview

This guide provides comprehensive deployment instructions for running various data platforms on Kubernetes with AxonOps monitoring and management capabilities. All deployments support flexible storage options and multi-node configurations.

## Available Deployment Guides

### 📊 [AxonOps Monitoring Platform](AXONOPS_DEPLOYMENT.md)

Deploy AxonOps for monitoring and managing your Kafka and Cassandra clusters.

**What you'll deploy:**
- AxonOps Server (core monitoring service)
- AxonDB Timeseries (metrics storage)
- AxonDB Search (log aggregation)
- AxonOps Dashboard (web UI)

**Quick Start:**
```bash
export AXON_SERVER_SEARCH_DB_PASSWORD='your-password'
./axonops-setup.sh
```

[📖 Full AxonOps Deployment Guide →](AXONOPS_DEPLOYMENT.md)

---

### 🔄 [Strimzi Apache Kafka](STRIMZI_DEPLOYMENT.md)

Deploy production-ready Apache Kafka using the Strimzi operator with KRaft mode (no ZooKeeper).

**What you'll deploy:**
- Strimzi Kafka Operator
- Kafka Controllers (KRaft consensus)
- Kafka Brokers (data handling)
- Optional: AxonOps monitoring integration

**Quick Start:**
```bash
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

[📖 Full Strimzi Deployment Guide →](STRIMZI_DEPLOYMENT.md)

---

### 🗄️ [K8ssandra Apache Cassandra](K8SSANDRA_DEPLOYMENT.md)

Deploy Apache Cassandra with K8ssandra for automated operations and management.

**Status:** 🚧 Coming Soon

**What you'll deploy:**
- K8ssandra Operator
- Apache Cassandra Cluster
- Medusa (backup/restore)
- Reaper (automated repairs)
- Optional: AxonOps monitoring integration

[📖 K8ssandra Deployment Guide (Preview) →](K8SSANDRA_DEPLOYMENT.md)

---

## Architecture Overview

### Modular Deployment Scripts

Each platform has its own deployment script:

```
examples/full-on-prems/
├── axonops-setup.sh       # Deploy AxonOps monitoring
├── strimzi-setup.sh       # Deploy Kafka with Strimzi
└── k8ssandra-setup.sh     # Deploy Cassandra (coming soon)
```

### Integration Flow

```
┌─────────────────────┐
│   AxonOps Platform  │
│  (Monitoring Core)  │
└──────────┬──────────┘
           │
           ├─── monitors ───┐
           │                │
           │                ▼
           │     ┌──────────────────┐
           │     │  Strimzi Kafka   │
           │     │  (Event Stream)  │
           │     └──────────────────┘
           │
           └─── monitors ───┐
                            │
                            ▼
                 ┌──────────────────────┐
                 │  K8ssandra Cassandra │
                 │   (Data Storage)     │
                 └──────────────────────┘
```

## Deployment Options

### Option 1: AxonOps Only

Deploy just the monitoring platform to monitor existing clusters:

```bash
export AXON_SERVER_SEARCH_DB_PASSWORD='your-password'
./axonops-setup.sh
```

### Option 2: Kafka with AxonOps (Recommended)

Full stack deployment with monitoring:

```bash
# Step 1: Deploy AxonOps
export AXON_SERVER_SEARCH_DB_PASSWORD='your-password'
./axonops-setup.sh

# Step 2: Deploy Kafka with monitoring integration
source axonops-config.env
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

### Option 3: Kafka Standalone

Deploy Kafka without monitoring:

```bash
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

### Option 4: Full Platform (Coming Soon)

Deploy AxonOps + Kafka + Cassandra:

```bash
# Step 1: AxonOps
./axonops-setup.sh

# Step 2: Kafka
source axonops-config.env
./strimzi-setup.sh

# Step 3: Cassandra (coming soon)
./k8ssandra-setup.sh
```

## Quick Start Decision Tree

```
Do you need monitoring?
├─ Yes → Deploy AxonOps first (AXONOPS_DEPLOYMENT.md)
│        Then choose your data platform below
│
└─ No  → Skip to data platform deployment

Which data platform?
├─ Kafka     → STRIMZI_DEPLOYMENT.md
├─ Cassandra → K8SSANDRA_DEPLOYMENT.md (coming soon)
└─ Both      → Deploy Strimzi first, then K8ssandra
```

## Common Prerequisites

All deployments require:

1. **Kubernetes Cluster**
   - Version: 1.21+ recommended
   - Single-node: Supported (ideal for testing)
   - Multi-node: Supported (recommended for production)

2. **Command-line Tools**
   - `kubectl` - Kubernetes CLI
   - `helm` - Helm package manager v3.x
   - `envsubst` - Variable substitution (part of `gettext`)

3. **Cluster Access**
   - Configured `kubectl` context
   - Sufficient permissions (cluster-admin or equivalent)

4. **Node Access** (for hostPath storage)
   - `sudo` access on Kubernetes nodes
   - SSH access for directory creation

## Storage Options

All deployments support two storage modes:

### hostPath Storage

**Best for:** Single-node testing and development

```bash
export STORAGE_MODE="hostPath"
```

**Characteristics:**
- Uses local directories on node filesystem
- Requires manual directory creation
- Fastest performance (no network overhead)
- Limited to single-node deployments or with node selectors

### PVC Storage (Dynamic Provisioning)

**Best for:** Production and multi-node clusters

```bash
export STORAGE_MODE="pvc"
export STORAGE_CLASS="your-storage-class"  # or empty for default
export STORAGE_SIZE="50Gi"
```

**Characteristics:**
- Works with any storage provider
- Automatic volume provisioning
- Better for multi-node deployments
- Supports snapshots and backups

## Node Selector Support

All deployments support pinning pods to specific nodes for:
- Resource optimization
- Hardware utilization (NVMe, high memory)
- Availability zone distribution
- Data locality

**Example:**

```bash
export KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1,broker-1:worker-2,broker-2:worker-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,ctrl-1:control-1"
```

For detailed configuration, see [NODE_SELECTOR_GUIDE.md](NODE_SELECTOR_GUIDE.md).

## Networking

### Internal Services

All components communicate within the cluster using Kubernetes services:

- **AxonOps Server Agent**: `axon-server-agent.axonops.svc.cluster.local:1888`
- **Kafka Bootstrap**: `{cluster-name}-kafka-bootstrap.kafka.svc.cluster.local:9092`
- **Cassandra CQL**: (coming soon)

### External Access

Configure external access per deployment:

- **AxonOps Dashboard**: Port-forward, NodePort, or Ingress
- **Kafka**: LoadBalancer or NodePort listeners
- **Cassandra**: CQL service exposure (coming soon)

## Monitoring and Observability

### With AxonOps Integration

When AxonOps is deployed, you get:

- **Real-time Metrics**: CPU, memory, disk, network
- **Cluster Health**: Broker/node status, partition states
- **Performance Monitoring**: Throughput, latency, lag
- **Log Aggregation**: Centralized log viewing and search
- **Alerting**: Configurable alerts for critical conditions
- **Historical Analysis**: Trend analysis and capacity planning

### Accessing AxonOps Dashboard

```bash
# Port-forward (quick access)
kubectl port-forward -n axonops svc/axon-dash 3000:3000
# Open http://localhost:3000

# Or configure Ingress/NodePort during deployment
```

## Production Considerations

For production deployments:

### 1. High Availability

- Deploy multiple replicas
- Distribute across availability zones
- Configure appropriate replication factors
- Use rack awareness for Cassandra

### 2. Security

- Enable TLS for all components
- Configure authentication (SASL, mTLS)
- Implement network policies
- Use secrets management (Vault, sealed-secrets)
- Enable authorization and ACLs

### 3. Storage

- Use distributed storage (Ceph, NFS, cloud storage)
- Configure appropriate IOPS and throughput
- Plan capacity based on retention requirements
- Implement backup and disaster recovery

### 4. Resource Planning

- Set resource requests and limits
- Plan for peak load scenarios
- Monitor resource utilization
- Scale proactively

### 5. Monitoring

- Deploy AxonOps for comprehensive monitoring
- Configure alerting for critical metrics
- Set up log aggregation
- Implement distributed tracing

### 6. Backup and Recovery

- Implement backup strategies
- Test recovery procedures regularly
- Document runbooks
- Automate where possible

## Troubleshooting

Each deployment guide includes detailed troubleshooting sections:

- **[AxonOps Troubleshooting](AXONOPS_DEPLOYMENT.md#troubleshooting)**
- **[Strimzi Troubleshooting](STRIMZI_DEPLOYMENT.md#troubleshooting)**
- **[K8ssandra Troubleshooting](K8SSANDRA_DEPLOYMENT.md)** (coming soon)

### Common Issues

**Pods stuck in Pending:**
- Check PVC status: `kubectl get pvc -n <namespace>`
- Verify storage availability
- Check node resources: `kubectl describe node <node-name>`

**Service connectivity issues:**
- Verify DNS resolution within cluster
- Check NetworkPolicies if enabled
- Confirm service endpoints: `kubectl get endpoints -n <namespace>`

**Certificate issues:**
- Check cert-manager status: `kubectl get pods -n cert-manager`
- Verify ClusterIssuer: `kubectl get clusterissuer`
- Check certificate status: `kubectl get certificate -n <namespace>`

## Cleanup

Remove deployments in reverse order:

```bash
# Remove data platforms
kubectl delete kafka my-cluster -n kafka  # Strimzi
# kubectl delete cassandradatacenter ... # K8ssandra (coming soon)

# Remove operators
helm uninstall strimzi-kafka-operator -n strimzi
# helm uninstall k8ssandra-operator ... # (coming soon)

# Remove AxonOps
helm uninstall axon-dash axon-server axondb-search axondb-timeseries -n axonops

# Remove namespaces
kubectl delete namespace kafka strimzi axonops

# Optional: Remove cert-manager if not used by other services
helm uninstall cert-manager -n cert-manager
kubectl delete namespace cert-manager
```

## Getting Help

### Documentation

- **AxonOps**: [https://docs.axonops.com](https://docs.axonops.com)
- **Strimzi**: [https://strimzi.io/docs/](https://strimzi.io/docs/)
- **K8ssandra**: [https://docs.k8ssandra.io/](https://docs.k8ssandra.io/)
- **Apache Kafka**: [https://kafka.apache.org/documentation/](https://kafka.apache.org/documentation/)
- **Apache Cassandra**: [https://cassandra.apache.org/doc/latest/](https://cassandra.apache.org/doc/latest/)

### Support

- **Community**: GitHub issues and discussions
- **AxonOps Support**: Contact AxonOps for enterprise support
- **Strimzi Community**: Strimzi Slack and mailing lists
- **K8ssandra Community**: K8ssandra Discord and GitHub

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

See the LICENSE file in the repository root.

---

**Quick Navigation:**
- [AxonOps Deployment →](AXONOPS_DEPLOYMENT.md)
- [Strimzi Kafka Deployment →](STRIMZI_DEPLOYMENT.md)
- [K8ssandra Cassandra Deployment →](K8SSANDRA_DEPLOYMENT.md)
- [Node Selector Guide →](NODE_SELECTOR_GUIDE.md)

**Last Updated:** 2026-01-12
