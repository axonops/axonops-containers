# Strimzi Kafka Deployment Guide

This guide covers deploying Apache Kafka using the Strimzi operator on Kubernetes, with optional AxonOps monitoring integration.

## Quick Start

### Basic Deployment

```bash
# Set the Kubernetes node hostname
export STRIMZI_NODE_HOSTNAME='your-node-name'

# Deploy Strimzi Kafka
./strimzi-setup.sh
```

### With AxonOps Monitoring

```bash
# First deploy AxonOps (see AXONOPS_DEPLOYMENT.md)
export AXON_SERVER_SEARCH_DB_PASSWORD='your-password'
./axonops-setup.sh

# Then deploy Strimzi with AxonOps integration
source axonops-config.env
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

That's it! Your Kafka cluster will be deployed and ready to use.

---

## Overview

This deployment uses:
- **Strimzi Operator** - Kubernetes operator for running Apache Kafka
- **KRaft Mode** - Kafka's built-in consensus (no ZooKeeper required)
- **Node Pools** - Separate controller and broker node pools
- **Flexible Storage** - Support for hostPath or dynamic PVC provisioning
- **Node Selectors** - Pin brokers and controllers to specific nodes
- **AxonOps Integration** - Optional monitoring and management

### Architecture

The deployment creates:
- **Controller Nodes** (default: 2 replicas) - Manage cluster metadata using KRaft
- **Broker Nodes** (default: 3 replicas) - Handle data and client connections
- **PersistentVolumes** - Storage for Kafka data
- **Services** - Internal and external connectivity

## Prerequisites

1. **Kubernetes Cluster** (single or multi-node)
   - Single-node: Ideal for testing with hostPath storage
   - Multi-node: Supported with node selectors for distributed deployments
2. **Required Tools**:
   - `kubectl` - Kubernetes CLI
   - `helm` - Helm package manager
   - `envsubst` - Variable substitution tool (part of `gettext` package)
   - `sudo` - Root access on nodes for creating hostPath directories
3. **cert-manager** - Automatically installed if not present
4. **Optional**: AxonOps deployed for monitoring integration

## Configuration

### Basic Configuration

```bash
# Cluster configuration
export STRIMZI_CLUSTER_NAME="my-cluster"        # Kafka cluster name
export STRIMZI_NODE_HOSTNAME="worker-1"         # Default node for single-node deployment
export NS_KAFKA="kafka"                         # Kubernetes namespace

# Replica counts
export KAFKA_BROKER_REPLICAS=3                  # Number of broker replicas
export KAFKA_CONTROLLER_REPLICAS=2              # Number of controller replicas
```

### Storage Configuration

#### Option 1: hostPath Storage (Default)

Uses local directories on Kubernetes nodes. Best for single-node testing:

```bash
export STORAGE_MODE="hostPath"                           # Storage mode
export STRIMZI_HOST_BASE_DIR="/data/strimzi"           # Base directory on node
```

**Requirements:**
- Create directories on target nodes before deployment
- Run with `sudo` access or manually create directories
- Set proper permissions (UID:GID 1001:1001)

#### Option 2: PVC Storage (Dynamic Provisioning)

Uses PersistentVolumeClaims with your storage provider:

```bash
export STORAGE_MODE="pvc"                    # Use PVC mode
export STORAGE_CLASS="fast-ssd"              # StorageClass name (empty = default)
export STORAGE_SIZE="50Gi"                   # Size for each PVC
```

**Benefits:**
- Works with any storage provider
- Suitable for production environments
- No manual directory creation
- Better for multi-node clusters

### Node Selector Configuration

For multi-node deployments, pin specific brokers and controllers to designated nodes:

```bash
# Distribute brokers across nodes
export KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1,broker-1:worker-2,broker-2:worker-3"

# Keep controllers together
export KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,ctrl-1:control-1"
```

**Format:** `replica-id:node-name,replica-id:node-name`

**Supported formats:**
- `broker-0:node1` - Full broker name
- `controller-0:node1` - Full controller name
- `ctrl-0:node1` - Short controller name
- `0:node1` - Number only

For detailed node selector configuration, see [NODE_SELECTOR_GUIDE.md](NODE_SELECTOR_GUIDE.md).

### AxonOps Integration

If AxonOps is deployed, Kafka will automatically integrate with it:

```bash
# Source AxonOps configuration (created by axonops-setup.sh)
source axonops-config.env

# These variables are automatically set:
# - AXON_AGENT_SERVER_HOST
# - AXON_AGENT_SERVER_PORT
# - AXON_AGENT_ORG
# - AXON_AGENT_CLUSTER_NAME
```

Or manually configure:

```bash
export AXON_AGENT_SERVER_HOST="axon-server-agent.axonops.svc.cluster.local"
export AXON_AGENT_SERVER_PORT="1888"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_CLUSTER_NAME="$STRIMZI_CLUSTER_NAME"
export AXON_AGENT_TLS_MODE="false"
```

## Deployment Steps

### Step 1: Prepare Storage (hostPath mode only)

For single-node deployment with default settings:

```bash
# On the Kubernetes node
sudo mkdir -p /data/strimzi/my-cluster/controller-{0,1}
sudo mkdir -p /data/strimzi/my-cluster/broker-pool-{0,1,2}
sudo chown -R 1001:1001 /data/strimzi
sudo chmod -R 755 /data/strimzi
```

For multi-node deployment with node selectors:

```bash
# On each target node, create only the directories needed
# The script will show you which directories to create on which nodes

# Example: On worker-1 (hosts broker-0 and controller-0)
sudo mkdir -p /data/strimzi/my-cluster/broker-pool-0
sudo mkdir -p /data/strimzi/my-cluster/controller-0
sudo chown -R 1001:1001 /data/strimzi
sudo chmod -R 755 /data/strimzi

# Example: On worker-2 (hosts broker-1)
sudo mkdir -p /data/strimzi/my-cluster/broker-pool-1
sudo chown -R 1001:1001 /data/strimzi
sudo chmod -R 755 /data/strimzi
```

### Step 2: Configure Deployment

```bash
# Basic configuration
export STRIMZI_CLUSTER_NAME="production-kafka"
export STRIMZI_NODE_HOSTNAME="worker-1"  # For single-node or default node

# Optional: Configure node selectors for multi-node
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:control-1,1:control-1"

# Optional: Enable AxonOps integration
source axonops-config.env  # If AxonOps is deployed
```

### Step 3: Run Deployment Script

```bash
chmod +x strimzi-setup.sh
./strimzi-setup.sh
```

The script will:
1. Install cert-manager (if needed)
2. Install Strimzi operator
3. Validate node configurations (if using node selectors)
4. Create PersistentVolumes with node affinity (hostPath mode)
5. Apply Kafka NodePool configurations
6. Deploy Kafka cluster
7. Verify pod placement
8. Display connection information

### Step 4: Wait for Kafka to be Ready

The script automatically waits for the Kafka cluster to be ready. You can also monitor manually:

```bash
# Watch Kafka cluster status
kubectl get kafka -n kafka -w

# Check pod status
kubectl get pods -n kafka -o wide

# View Kafka cluster details
kubectl describe kafka my-cluster -n kafka
```

## Verifying the Deployment

### Check Component Status

```bash
# View Kafka cluster
kubectl get kafka -n kafka

# View node pools
kubectl get kafkanodepool -n kafka

# View all pods with their nodes
kubectl get pods -n kafka -o wide

# Check PersistentVolumes
kubectl get pv -l strimzi.io/cluster=my-cluster
kubectl get pvc -n kafka
```

### Verify Pod Placement

For multi-node deployments with node selectors:

```bash
# View pod-to-node mapping
kubectl get pods -n kafka -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName

# Expected output shows pods on correct nodes
# broker-pool-0    worker-1
# broker-pool-1    worker-2
# my-cluster-controller-0    control-1
```

### Test Kafka Connectivity

```bash
# Internal bootstrap servers
BOOTSTRAP_SERVERS="my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092"

# Create a test topic
kubectl run kafka-producer -ti --image=quay.io/strimzi/kafka:latest-kafka-3.9.0 \
  --rm=true --restart=Never -- \
  bin/kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVERS \
  --create --topic test-topic --partitions 3 --replication-factor 2

# List topics
kubectl run kafka-consumer -ti --image=quay.io/strimzi/kafka:latest-kafka-3.9.0 \
  --rm=true --restart=Never -- \
  bin/kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVERS --list
```

### Check AxonOps Integration

If AxonOps is integrated:

```bash
# Check agent annotations on pods
kubectl describe pod broker-pool-0 -n kafka | grep axon

# Check AxonOps Server for connected agents
kubectl logs -n axonops deployment/axon-server | grep agent

# Access AxonOps Dashboard
kubectl port-forward -n axonops svc/axon-dash 3000:3000
# Open http://localhost:3000 and verify Kafka cluster is visible
```

## Common Deployment Scenarios

### Scenario 1: Single-Node Testing

```bash
export STRIMZI_NODE_HOSTNAME="minikube"
export STORAGE_MODE="hostPath"
./strimzi-setup.sh
```

### Scenario 2: Multi-Node Production

```bash
export STORAGE_MODE="pvc"
export STORAGE_CLASS="fast-ssd"
export STORAGE_SIZE="100Gi"
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:control-1,1:control-1"
./strimzi-setup.sh
```

### Scenario 3: High Availability Across Zones

```bash
export STORAGE_MODE="pvc"
export STORAGE_CLASS="regional-ssd"
export STORAGE_SIZE="200Gi"
export KAFKA_BROKER_NODE_SELECTORS="0:zone-a-node1,1:zone-b-node1,2:zone-c-node1"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:zone-a-node2,1:zone-b-node2"
./strimzi-setup.sh
```

### Scenario 4: With AxonOps Monitoring

```bash
# Deploy AxonOps first
export AXON_SERVER_SEARCH_DB_PASSWORD='secure-password'
./axonops-setup.sh

# Deploy Kafka with monitoring
source axonops-config.env
export STRIMZI_NODE_HOSTNAME="worker-1"
./strimzi-setup.sh
```

For more scenarios, see [NODE_SELECTOR_GUIDE.md](NODE_SELECTOR_GUIDE.md).

## Troubleshooting

### Pods Stuck in Pending State

**Check PersistentVolume status:**

```bash
kubectl get pv
kubectl get pvc -n kafka
kubectl describe pvc <pvc-name> -n kafka
```

**Common causes:**
- **hostPath mode**: Directories don't exist or have wrong permissions
- **PVC mode**: No storage class available or insufficient capacity
- **Node affinity mismatch**: Pod node selector doesn't match PV node affinity

**Solutions:**

```bash
# For hostPath: Verify directories on node
ssh <node> "ls -la /data/strimzi/my-cluster"

# For PVC: Check storage classes
kubectl get storageclass

# Check pod events
kubectl describe pod <pod-name> -n kafka
```

### Node Affinity Issues

**Symptom:** Pods scheduled on wrong nodes or not scheduled at all

**Check node affinity:**

```bash
# For hostPath mode, verify PV node affinity matches pod placement
kubectl get pv pv-my-cluster-broker-pool-0 -o yaml | grep -A 10 nodeAffinity

# Check pod node affinity
kubectl get kafkanodepool broker-pool -n kafka -o yaml | grep -A 15 affinity
```

**Solution:**
- Ensure `KAFKA_BROKER_NODE_SELECTORS` and `KAFKA_CONTROLLER_NODE_SELECTORS` are correctly set
- Verify all specified nodes exist: `kubectl get nodes`
- For hostPath mode, ensure storage directories exist on the correct nodes

### Storage Not Binding

**Symptom:** PVCs remain in Pending state

**Check:**

```bash
# View PVC status
kubectl get pvc -n kafka

# Check PV availability
kubectl get pv | grep Available

# Check events
kubectl get events -n kafka --sort-by='.lastTimestamp'
```

**Solutions:**

```bash
# For hostPath: Create missing directories
# For PVC: Verify storage class and capacity

# Check if PV node affinity matches available nodes
kubectl get pv -o yaml | grep -B 5 -A 10 nodeAffinity
```

### Kafka Cluster Not Ready

**Check Strimzi operator:**

```bash
kubectl get pods -n strimzi
kubectl logs -n strimzi -l name=strimzi-cluster-operator
```

**Check Kafka custom resource:**

```bash
kubectl get kafka my-cluster -n kafka
kubectl describe kafka my-cluster -n kafka
```

**View pod logs:**

```bash
# Controller logs
kubectl logs my-cluster-controller-0 -n kafka -c kafka

# Broker logs
kubectl logs broker-pool-0 -n kafka -c kafka
```

### AxonOps Integration Issues

**Check agent configuration:**

```bash
# Verify agent environment variables in pods
kubectl exec broker-pool-0 -n kafka -- env | grep AXON

# Check if AxonOps server is reachable
kubectl exec broker-pool-0 -n kafka -- nc -zv axon-server-agent.axonops.svc.cluster.local 1888
```

**View agent logs:**

```bash
kubectl logs broker-pool-0 -n kafka -c kafka | grep -i axon
```

## Performance Tuning

### Resource Limits

Edit the NodePool YAML files to set resource limits:

```yaml
# strimzi/strimzi-broker-pools.yaml
spec:
  resources:
    requests:
      memory: "8Gi"
      cpu: "2000m"
    limits:
      memory: "16Gi"
      cpu: "4000m"
```

### Storage Optimization

For better performance:

```bash
# Use faster storage class
export STORAGE_CLASS="nvme-ssd"

# Increase storage size
export STORAGE_SIZE="500Gi"

# Pin brokers to nodes with high-performance storage
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-node-1,1:nvme-node-2,2:nvme-node-3"
```

### Kafka Configuration

Customize Kafka settings in `strimzi/strimzi-kafka-cluster.yaml`:

```yaml
spec:
  kafka:
    config:
      num.network.threads: 8
      num.io.threads: 16
      socket.send.buffer.bytes: 102400
      socket.receive.buffer.bytes: 102400
      socket.request.max.bytes: 104857600
```

## Cleanup

### Remove Kafka Cluster

```bash
# Delete Kafka cluster (keeps operator)
kubectl delete kafka my-cluster -n kafka
kubectl delete kafkanodepool --all -n kafka

# Remove PersistentVolumes
kubectl delete pv -l strimzi.io/cluster=my-cluster
```

### Remove Strimzi Operator

```bash
# Uninstall operator
helm uninstall -n strimzi strimzi-kafka-operator

# Delete namespace
kubectl delete namespace kafka strimzi
```

### Clean Up Node Storage (CAUTION)

For hostPath storage:

```bash
# On each Kubernetes node
sudo rm -rf /data/strimzi
```

## Production Considerations

For production deployments:

1. **Storage**:
   - Use distributed storage with proper IOPS
   - Configure appropriate retention and backup policies
   - Size storage based on expected data volume and retention

2. **High Availability**:
   - Distribute brokers across availability zones
   - Use appropriate replication factors (min 3)
   - Configure proper rack awareness

3. **Security**:
   - Enable TLS for client and inter-broker communication
   - Configure SASL authentication
   - Use network policies
   - Enable authorization with ACLs

4. **Monitoring**:
   - Integrate with AxonOps for comprehensive monitoring
   - Set up alerting for critical metrics
   - Monitor disk usage, lag, and throughput

5. **Resource Planning**:
   - Set appropriate CPU and memory limits
   - Plan for peak load scenarios
   - Leave headroom for growth

6. **Backup and Recovery**:
   - Implement backup strategy for data and configurations
   - Test recovery procedures
   - Document runbooks

7. **Network**:
   - Configure appropriate network bandwidth
   - Use dedicated networks for storage if possible
   - Configure proper DNS and service discovery

## Advanced Topics

### Custom Kafka Configuration

Modify `strimzi/strimzi-kafka-cluster.yaml` to customize Kafka:

```yaml
spec:
  kafka:
    version: 3.9.0
    replicas: 3
    config:
      # Add custom Kafka server properties here
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
```

### External Listeners

Configure external access in the Kafka cluster YAML:

```yaml
spec:
  kafka:
    listeners:
      - name: external
        port: 9094
        type: loadbalancer
        tls: true
```

### Scaling

Scale the number of brokers:

```bash
# Update replica count
export KAFKA_BROKER_REPLICAS=5

# Rerun deployment or edit NodePool directly
kubectl edit kafkanodepool broker-pool -n kafka
```

### Upgrading Kafka

Follow Strimzi upgrade procedures:

1. Upgrade Strimzi operator first
2. Update Kafka version in cluster spec
3. Strimzi handles rolling upgrade automatically

## Additional Resources

- **Strimzi Documentation**: [https://strimzi.io/docs/](https://strimzi.io/docs/)
- **Node Selector Guide**: [NODE_SELECTOR_GUIDE.md](NODE_SELECTOR_GUIDE.md)
- **AxonOps Integration**: [AXONOPS_DEPLOYMENT.md](AXONOPS_DEPLOYMENT.md)
- **Apache Kafka Documentation**: [https://kafka.apache.org/documentation/](https://kafka.apache.org/documentation/)
- **KRaft Documentation**: [https://kafka.apache.org/documentation/#kraft](https://kafka.apache.org/documentation/#kraft)
