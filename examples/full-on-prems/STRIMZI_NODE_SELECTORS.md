# Strimzi Node Selectors Configuration

## Overview

The enhanced `strimzi-setup.sh` script now supports pinning Kafka brokers and controllers to specific Kubernetes nodes using node selectors. This is essential for:
- Ensuring data locality for performance
- Pinning components to nodes with specific hardware
- Distributing brokers across availability zones
- Controlling storage placement

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `KAFKA_BROKER_NODE_SELECTORS` | Comma-separated broker:node pairs | `"broker-0:node1,broker-1:node2,broker-2:node3"` |
| `KAFKA_CONTROLLER_NODE_SELECTORS` | Comma-separated controller:node pairs | `"controller-0:node1,controller-1:node2,controller-2:node3"` |
| `KAFKA_BROKER_REPLICAS` | Number of broker replicas | `3` |
| `KAFKA_CONTROLLER_REPLICAS` | Number of controller replicas | `3` |

## Usage Examples

### Example 1: Default Behavior (No Node Selectors)

If you don't specify node selectors, all components use the default node:

```bash
# All pods will be scheduled on STRIMZI_NODE_HOSTNAME
./strimzi-setup.sh
```

### Example 2: Specific Node Placement

```bash
# Pin each broker and controller to specific nodes
export KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1,broker-1:worker-2,broker-2:worker-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="controller-0:control-1,controller-1:control-1,controller-2:control-1"

./strimzi-setup.sh
```

### Example 3: Mixed Deployment

```bash
# Brokers on different nodes, controllers on same node
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-node-1,1:nvme-node-2,2:nvme-node-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:control-node-1,1:control-node-1,2:control-node-1"

./strimzi-setup.sh
```

### Example 4: High Availability Across Zones

```bash
# Distribute across availability zones
export KAFKA_BROKER_NODE_SELECTORS="0:az1-node1,1:az2-node1,2:az3-node1"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:az1-node2,1:az2-node2,2:az3-node2"

./strimzi-setup.sh
```

## How It Works

1. **Node Validation**: The script validates that all specified nodes exist and are ready
2. **PersistentVolume Generation**: Creates individual PVs for each replica with node affinity
3. **Directory Instructions**: Shows which directories need to be created on which nodes
4. **Pod Placement Verification**: After deployment, verifies pods are placed on correct nodes

## Pre-Deployment Setup

### 1. Label Your Nodes (Optional)

```bash
# Label nodes for easier identification
kubectl label node worker-1 kafka-storage=true
kubectl label node worker-2 kafka-storage=true
kubectl label node worker-3 kafka-storage=true
```

### 2. Create Storage Directories

The script will show you which directories to create on each node:

```bash
# On node 'worker-1':
sudo mkdir -p /data/strimzi/my-cluster/broker-pool-0
sudo mkdir -p /data/strimzi/my-cluster/controller-0
sudo chown -R 1001:1001 /data/strimzi
sudo chmod -R 755 /data/strimzi

# On node 'worker-2':
sudo mkdir -p /data/strimzi/my-cluster/broker-pool-1
sudo chown -R 1001:1001 /data/strimzi
sudo chmod -R 755 /data/strimzi

# On node 'worker-3':
sudo mkdir -p /data/strimzi/my-cluster/broker-pool-2
sudo chown -R 1001:1001 /data/strimzi
sudo chmod -R 755 /data/strimzi
```

## Verification

After deployment, verify pod placement:

```bash
# Check pod placement
kubectl get pods -n kafka -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName

# Example output:
# NAME                         NODE
# my-cluster-controller-0      control-1
# my-cluster-controller-1      control-1
# my-cluster-controller-2      control-1
# broker-pool-0                worker-1
# broker-pool-1                worker-2
# broker-pool-2                worker-3

# Check PV node affinity
kubectl get pv -l strimzi.io/cluster=my-cluster -o yaml | grep -A5 nodeAffinity
```

## Generated Resources

The script generates:

### PersistentVolumes

Each PV is created with node affinity matching the pod placement:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-my-cluster-broker-pool-0
spec:
  capacity:
    storage: 5Gi
  hostPath:
    path: /data/strimzi/my-cluster/broker-pool-0
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker-1  # Matches broker-0 placement
```

### KafkaNodePools

Node pools are configured with anti-affinity to ensure distribution.

## Troubleshooting

### Pods Stuck in Pending

Check:
1. Node resources: `kubectl describe node <node-name>`
2. PV node affinity matches pod placement
3. Storage directories exist on target nodes

### Node Not Found

```bash
# List available nodes
kubectl get nodes

# Use exact node names in selectors
export KAFKA_BROKER_NODE_SELECTORS="0:exact-node-name-from-above"
```

### Storage Not Binding

Verify:
1. PV and pod are on same node
2. Directories exist with correct permissions
3. StorageClass exists: `kubectl get storageclass`

## Advanced Configuration

### Custom Replica Counts

```bash
# Use 5 brokers and 3 controllers
export KAFKA_BROKER_REPLICAS=5
export KAFKA_CONTROLLER_REPLICAS=3
export KAFKA_BROKER_NODE_SELECTORS="0:node1,1:node2,2:node3,3:node4,4:node5"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:control1,1:control2,2:control3"

./strimzi-setup.sh
```

### PVC Mode with Node Selectors

Node selectors work with PVC mode too (though less common):

```bash
export STORAGE_MODE=pvc
export STORAGE_CLASS=local-ssd
export KAFKA_BROKER_NODE_SELECTORS="0:ssd-node-1,1:ssd-node-2,2:ssd-node-3"

./strimzi-setup.sh
```

## Best Practices

1. **Test in Development**: Verify node selector configuration in a test environment first
2. **Document Your Configuration**: Keep a record of which components are on which nodes
3. **Monitor After Deployment**: Check pod placement and storage binding
4. **Plan for Failures**: Consider what happens if a node fails
5. **Use Consistent Naming**: Use clear, descriptive node names

## Complete Example Script

```bash
#!/bin/bash
# deploy-kafka-with-node-selectors.sh

# Set cluster configuration
export STRIMZI_CLUSTER_NAME="production-kafka"
export NS_KAFKA="kafka-prod"
export STORAGE_MODE="hostPath"
export STRIMZI_HOST_BASE_DIR="/data/kafka"

# Configure node placement
export KAFKA_BROKER_REPLICAS=3
export KAFKA_CONTROLLER_REPLICAS=3
export KAFKA_BROKER_NODE_SELECTORS="0:prod-kafka-1,1:prod-kafka-2,2:prod-kafka-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:prod-control-1,1:prod-control-1,2:prod-control-1"

# Deploy
./strimzi-setup.sh

# Verify deployment
kubectl get pods -n kafka-prod -o wide
```