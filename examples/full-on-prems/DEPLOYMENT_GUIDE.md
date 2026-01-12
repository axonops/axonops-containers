# AxonOps and Strimzi Kafka On-Premises Deployment Guide

This guide helps you deploy AxonOps monitoring services and Strimzi Kafka cluster with flexible storage and node placement options.

## Quick Start

For a basic single-node deployment with default settings:

```bash
# Set the Kubernetes node hostname
export STRIMZI_NODE_HOSTNAME='your-node-name'

# Deploy Strimzi Kafka
./strimzi-setup.sh
```

For a full deployment with AxonOps monitoring:

```bash
# Deploy AxonOps first
export AXON_SERVER_SEARCH_DB_PASSWORD='your-password'
./axonops-setup.sh

# Then deploy Strimzi with AxonOps integration
source axonops-config.env
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

That's it! Continue reading for detailed configuration options and advanced scenarios.

---

## Overview

The deployment has been split into two modular scripts for better flexibility:
- **`axonops-setup.sh`** - Deploys AxonOps monitoring and management services
- **`strimzi-setup.sh`** - Deploys Strimzi Kafka cluster with optional AxonOps integration and node selector support

## Prerequisites

1. **Kubernetes Cluster** (single or multi-node)
   - Single-node: Ideal for testing with hostPath storage
   - Multi-node: Supported with node selectors for distributed deployments
2. **Required Tools**:
   - `kubectl` - Kubernetes CLI
   - `helm` - Helm package manager
   - `envsubst` - Environment variable substitution tool (usually in `gettext` package)
   - `sudo` - Root access on the Kubernetes node for creating directories

## Deployment Options

### Option 1: Full Stack (AxonOps + Strimzi with Monitoring)
Deploy both AxonOps services and Strimzi Kafka with monitoring integration.

### Option 2: AxonOps Only
Deploy only AxonOps monitoring services for existing Kafka clusters.

### Option 3: Strimzi Only
Deploy only Strimzi Kafka cluster without monitoring.

## Important Configuration Steps

### 1. Set Required Environment Variables

**CRITICAL**: Set the search database password before deploying AxonOps:
```bash
export AXON_SERVER_SEARCH_DB_PASSWORD='YourSecurePasswordHere'
```

### 2. Configure Node Hostname

Set the actual Kubernetes node hostname where Kafka will be deployed:
```bash
# Get your node name
kubectl get nodes

# Set the hostname for Strimzi deployment
export STRIMZI_NODE_HOSTNAME='your-actual-node-name'
```

### 3. Optional Configuration

You can customize various parameters by setting environment variables before running the scripts:

```bash
# Namespaces
export NS_AXONOPS="axonops"           # Default namespace for AxonOps
export NS_KAFKA="kafka"                # Default namespace for Kafka

# Kafka cluster name
export STRIMZI_CLUSTER_NAME="my-cluster"

# AxonOps agent configuration
export AXON_AGENT_ORG="your-org"      # Your organization name

# Storage directories (on the node)
export STRIMZI_HOST_BASE_DIR="/data/strimzi"  # Base directory for Kafka data

# AxonOps storage configuration
export AXON_SEARCH_USE_HOSTPATH="false"     # Set to "true" to use hostPath storage for Search DB (default: false)
export AXON_TIMESERIES_USE_HOSTPATH="false" # Set to "true" to use hostPath storage for Timeseries DB (default: false)

# Node selector configuration (for multi-node deployments)
export KAFKA_BROKER_NODE_SELECTORS="broker-0:node1,broker-1:node2,broker-2:node3"
export KAFKA_CONTROLLER_NODE_SELECTORS="controller-0:node1,controller-1:node1,controller-2:node1"

# Storage mode (default: hostPath)
export STORAGE_MODE="hostPath"    # Options: "hostPath" or "pvc"
export STORAGE_CLASS="fast-ssd"   # For PVC mode only
export STORAGE_SIZE="50Gi"        # For PVC mode only
```

**Note about AxonOps Storage Options:**
- By default (`false`), AxonOps databases use standard PersistentVolumeClaims which can work with various storage providers
- When set to `true`, the databases will use hostPath storage bound to specific directories on the node
- Use hostPath storage (`true`) only for single-node testing environments
- For production, keep these as `false` and configure proper persistent storage

**Note about Node Selectors:**
- Use node selectors to pin specific brokers and controllers to designated nodes
- Format: `"replica-id:node-name,replica-id:node-name"`
- Examples: `"broker-0:worker-1"`, `"ctrl-0:control-1"`, or just `"0:node1"`
- When using hostPath storage, node affinity is automatically configured to match storage placement
- See [NODE_SELECTOR_GUIDE.md](NODE_SELECTOR_GUIDE.md) for detailed configuration examples

## Running the Deployment

### Full Stack Deployment (Recommended)

#### Step 1: Prepare the Node (Run on the Kubernetes Node)

SSH to your Kubernetes node and run these commands to create the required directories:

```bash
# Set variables on the node
STRIMZI_CLUSTER_NAME="my-cluster"
STRIMZI_HOST_BASE_DIR="/data/strimzi"

# Create Strimzi directories
sudo mkdir -p ${STRIMZI_HOST_BASE_DIR}/${STRIMZI_CLUSTER_NAME}/controller-{0,1,2}
sudo mkdir -p ${STRIMZI_HOST_BASE_DIR}/${STRIMZI_CLUSTER_NAME}/broker-pool-{0,1,2}

# Set permissions for Strimzi (UID:GID 1001:1001)
sudo chown -R 1001:1001 ${STRIMZI_HOST_BASE_DIR}
sudo chmod -R 755 ${STRIMZI_HOST_BASE_DIR}

# Create AxonOps directories (only if using hostPath storage)
# Skip these if AXON_SEARCH_USE_HOSTPATH and AXON_TIMESERIES_USE_HOSTPATH are both "false"
sudo mkdir -p /data/axon-timeseries
sudo mkdir -p /data/axon-search

# Set permissions for AxonOps (UID:GID 999:999)
sudo chown -R 999:999 /data/axon-timeseries /data/axon-search
```

#### Step 2: Deploy AxonOps Services

From your workstation (with kubectl access):

```bash
# Make the scripts executable
chmod +x axonops-setup.sh strimzi-setup.sh

# Set required password
export AXON_SERVER_SEARCH_DB_PASSWORD='YourSecurePasswordHere'

# Option A: Deploy with standard storage (recommended for multi-node clusters)
./axonops-setup.sh

# Option B: Deploy with hostPath storage (single-node testing only)
export AXON_SEARCH_USE_HOSTPATH="true"
export AXON_TIMESERIES_USE_HOSTPATH="true"
./axonops-setup.sh
```

Wait for AxonOps services to be ready before proceeding.

#### Step 3: Deploy Strimzi Kafka Cluster

```bash
# Source the AxonOps configuration (created by axonops-setup.sh)
source axonops-config.env

# Set the target node hostname
export STRIMZI_NODE_HOSTNAME='your-actual-node-name'

# Deploy Strimzi with AxonOps integration
./strimzi-setup.sh
```

### AxonOps Only Deployment

For monitoring existing Kafka clusters:

```bash
# Set required password
export AXON_SERVER_SEARCH_DB_PASSWORD='YourSecurePasswordHere'

# Deploy only AxonOps services
./axonops-setup.sh
```

### Strimzi Only Deployment

For Kafka cluster without monitoring:

```bash
# Set the target node hostname
export STRIMZI_NODE_HOSTNAME='your-actual-node-name'

# Deploy only Strimzi
./strimzi-setup.sh
```

## Verifying the Deployment

### Check AxonOps Components
```bash
kubectl get pods -n axonops
kubectl get svc -n axonops
```

### Check Kafka Cluster
```bash
kubectl get kafka -n kafka
kubectl get kafkanodepool -n kafka
kubectl get pods -n kafka
```

### Monitor Kafka Cluster Status
```bash
kubectl get kafka -n kafka -w
```

## Accessing Services

### AxonOps Dashboard

By default, the dashboard is accessible via ClusterIP. To access it:

```bash
# Port-forward to access the dashboard
kubectl port-forward -n axonops svc/axon-dash 3000:3000

# Access at: http://localhost:3000
```

For production access, configure Ingress before deployment:
```bash
export AXON_DASH_INGRESS_ENABLED=true
export AXON_DASH_INGRESS_HOST="axonops.yourdomain.com"
```

Or enable NodePort access:
```bash
export AXON_DASH_NODEPORT_ENABLED=true
export AXON_DASH_NODEPORT_PORT=32000
# Access at: http://<node-ip>:32000
```

### Kafka Bootstrap Servers

Internal cluster access:
```
my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092
```

## Troubleshooting

### Pods Stuck in Pending State

Check PersistentVolume status:
```bash
kubectl get pv
kubectl get pvc -n kafka
```

Ensure the node hostname matches:
```bash
kubectl describe pv pv-my-cluster-controller-0
```

### Directory Permission Issues

On the Kubernetes node:
```bash
# Check Strimzi directories
ls -la /data/strimzi/my-cluster/
# Should be owned by UID 1001 and GID 1001

# Check AxonOps directories
ls -la /data/axon-timeseries /data/axon-search
# Should be owned by UID 999 and GID 999
```

### Check Logs

AxonOps Server:
```bash
kubectl logs -n axonops deployment/axon-server -f
```

Strimzi Operator:
```bash
kubectl logs -n strimzi deployment/strimzi-cluster-operator -f
```

Kafka Pods:
```bash
kubectl logs -n kafka my-cluster-controller-0 -f
```

### AxonOps Integration Issues

If the AxonOps agent is not connecting:
```bash
# Check agent annotations on Kafka pods
kubectl describe pod -n kafka my-cluster-broker-pool-0

# Check AxonOps server agent endpoint
kubectl get svc -n axonops axon-server-agent
```

## Limitations

⚠️ **When using hostPath storage mode:**
- Data is stored directly on the node's filesystem
- Each pod must be pinned to the node where its storage resides
- Moving pods requires data migration
- Limited high availability compared to distributed storage
- Recommended for testing and development environments only

**For production deployments:**
- Use PVC mode (`STORAGE_MODE=pvc`) with a distributed storage provider
- Configure proper backup and disaster recovery procedures
- Implement monitoring and alerting

## Cleanup

### Remove Strimzi Kafka
```bash
# Remove Kafka cluster
kubectl delete kafka -n kafka my-cluster
kubectl delete kafkanodepool -n kafka --all

# Remove PersistentVolumes
kubectl delete pv -l strimzi.io/cluster=my-cluster

# Uninstall Strimzi operator
helm uninstall -n strimzi strimzi-kafka-operator

# Delete Kafka namespace
kubectl delete namespace kafka
```

### Remove AxonOps
```bash
# Uninstall Helm releases
helm uninstall -n axonops axon-dash
helm uninstall -n axonops axon-server
helm uninstall -n axonops axondb-search
helm uninstall -n axonops axondb-timeseries

# Delete AxonOps namespace
kubectl delete namespace axonops
```

### Remove cert-manager
```bash
helm uninstall -n cert-manager cert-manager
kubectl delete namespace cert-manager
```

### Clean Up Node Storage
On the Kubernetes node (CAUTION: This deletes all data):
```bash
# Remove Strimzi data
sudo rm -rf /data/strimzi

# Remove AxonOps data
sudo rm -rf /data/axon-timeseries
sudo rm -rf /data/axon-search
```

## Production Considerations

For production deployments:
1. **Storage**: Use proper persistent storage (NFS, Ceph, cloud storage)
2. **High Availability**: Enable multi-node deployment with proper replication
3. **Security**: Configure TLS/SSL for all components
4. **Authentication**: Set up proper authentication and authorization
5. **Network**: Use external load balancers or ingress controllers
6. **Monitoring**: Implement comprehensive monitoring and alerting
7. **Backup**: Configure backup and disaster recovery procedures

## Additional Documentation

For more detailed information about the split deployment:
- See [README-split-deployment.md](README-split-deployment.md) for comprehensive configuration options
- Review individual script comments for parameter details
- Check the generated YAML files for customization options