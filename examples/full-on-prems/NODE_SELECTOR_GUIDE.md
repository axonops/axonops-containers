# Strimzi Node Selector Configuration Guide

## Overview

This guide explains how to use the Strimzi deployment script to pin Kafka brokers and controllers to specific Kubernetes nodes. This is essential when you need to:

- Ensure data locality for performance
- Pin components to nodes with specific hardware (NVMe, high memory, etc.)
- Distribute brokers across availability zones
- Control storage placement for persistent volumes

**Key Features:**
- Automatic node affinity configuration for hostPath storage
- Support for both single-node and multi-node deployments
- Flexible replica-to-node mapping
- Pre-deployment validation of node availability
- Post-deployment verification of pod placement

## Quick Start

### Single Node Deployment

```bash
# Default behavior - all components on one node
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

### Multi-Node Deployment

```bash
# Distribute brokers across nodes
export KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1,broker-1:worker-2,broker-2:worker-3"

# Keep controllers together on one node
export KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,ctrl-1:control-1,ctrl-2:control-1"

# Run the deployment
./strimzi-setup.sh
```

That's it! The script will:
- Validate all specified nodes exist and are ready
- Create PersistentVolumes with node affinity (for hostPath mode)
- Inject node affinity into KafkaNodePools automatically
- Verify pod placement after deployment

## Configuration Options

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `KAFKA_BROKER_NODE_SELECTORS` | Comma-separated broker:node pairs | `"broker-0:node1,broker-1:node2"` |
| `KAFKA_CONTROLLER_NODE_SELECTORS` | Comma-separated controller:node pairs | `"controller-0:node1,controller-1:node2"` |
| `KAFKA_BROKER_REPLICAS` | Number of broker replicas | `3` |
| `KAFKA_CONTROLLER_REPLICAS` | Number of controller replicas | `3` |
| `STRIMZI_NODE_HOSTNAME` | Default node when selectors not specified | `"worker-1"` |
| `STORAGE_MODE` | Storage mode: `hostPath` or `pvc` | `"hostPath"` |

### Selector Format

Node selectors use the format: `replica-id:node-name`

- **Replica ID**: Can be in multiple formats:
  - Full broker name: `broker-0`, `broker-1`, etc.
  - Full controller name: `controller-0`, `controller-1`, etc.
  - Short controller name: `ctrl-0`, `ctrl-1`, etc.
  - Number only: `0`, `1`, `2`, etc.
- **Node Name**: Must be exact Kubernetes node name

Examples:
```bash
# Broker formats (all equivalent for broker 0)
KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1"
KAFKA_BROKER_NODE_SELECTORS="0:worker-1"

# Controller formats (all equivalent for controller 0)
KAFKA_CONTROLLER_NODE_SELECTORS="controller-0:control-1"
KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1"
KAFKA_CONTROLLER_NODE_SELECTORS="0:control-1"

# Mixed formats work too
KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1,1:worker-2,broker-2:worker-3"
KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,controller-1:control-1,2:control-1"
```

## Deployment Scenarios

### Scenario 1: All Components on Single Node

```bash
# Explicitly set all to same node
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-1,2:worker-1"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:worker-1,1:worker-1,2:worker-1"

# Or use default behavior (simpler and recommended)
export STRIMZI_NODE_HOSTNAME="worker-1"
unset KAFKA_BROKER_NODE_SELECTORS
unset KAFKA_CONTROLLER_NODE_SELECTORS

./strimzi-setup.sh
```

### Scenario 2: Distributed Brokers, Co-located Controllers

```bash
# Brokers across different nodes for better throughput
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"

# Controllers on a single control node for better coordination
export KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,ctrl-1:control-1,ctrl-2:control-1"

./strimzi-setup.sh
```

### Scenario 3: High Availability Across Zones

```bash
# Distribute across availability zones
export KAFKA_BROKER_NODE_SELECTORS="0:az1-node1,1:az2-node1,2:az3-node1"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:az1-node2,1:az2-node2,2:az3-node2"

./strimzi-setup.sh
```

### Scenario 4: Storage-Optimized Placement

```bash
# Pin to nodes with NVMe storage for better performance
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-node-1,1:nvme-node-2,2:nvme-node-3"

# Controllers on standard nodes (less I/O intensive)
export KAFKA_CONTROLLER_NODE_SELECTORS="0:standard-node-1,1:standard-node-1,2:standard-node-1"

./strimzi-setup.sh
```

### Scenario 5: Partial Node Selectors

```bash
# Only specify some replicas, others use default
export KAFKA_BROKER_NODE_SELECTORS="0:special-node-1"  # Only broker-0 pinned
export STRIMZI_NODE_HOSTNAME="default-node"  # broker-1 and broker-2 use this

./strimzi-setup.sh
```

## Storage Considerations

### hostPath Mode

When using `hostPath` storage mode with node selectors:

1. **Create directories on target nodes** before deployment:
   ```bash
   # On each target node
   sudo mkdir -p /data/strimzi/my-cluster/broker-pool-0
   sudo mkdir -p /data/strimzi/my-cluster/controller-0
   sudo chown -R 1001:1001 /data/strimzi
   sudo chmod -R 755 /data/strimzi
   ```

2. **PersistentVolumes are automatically created** with node affinity matching pod placement:
   ```yaml
   # Example: Broker 0 on worker-1
   nodeAffinity:
     required:
       nodeSelectorTerms:
       - matchExpressions:
         - key: kubernetes.io/hostname
           operator: In
           values:
           - worker-1  # Matches KAFKA_BROKER_NODE_SELECTORS for broker-0
   ```

3. **KafkaNodePools automatically get node affinity** to ensure pods start on nodes with their storage:
   ```yaml
   # Automatically injected by the script
   template:
     pod:
       affinity:
         nodeAffinity:
           requiredDuringSchedulingIgnoredDuringExecution:
             nodeSelectorTerms:
             - matchExpressions:
               - key: kubernetes.io/hostname
                 operator: In
                 values:
                 - worker-1  # All nodes used by this pool
                 - worker-2
                 - worker-3
   ```

   This ensures that:
   - Pods can only be scheduled on nodes where storage exists
   - Storage and compute are co-located for optimal performance
   - Failed pods won't be scheduled on nodes without their data

### PVC Mode

When using PVC mode with dynamic provisioning:

```bash
export STORAGE_MODE="pvc"
export STORAGE_CLASS="fast-ssd"  # Or leave empty for default
export STORAGE_SIZE="100Gi"

# Node selectors still control pod placement (no node affinity injection needed)
export KAFKA_BROKER_NODE_SELECTORS="0:node1,1:node2,2:node3"

./strimzi-setup.sh
```

**Note:** In PVC mode, node affinity is NOT automatically injected into KafkaNodePools since the storage provisioner handles volume placement. Pods can be scheduled more flexibly based on resource availability.

## Pre-Deployment Validation

The script performs several validation checks:

### 1. Node Existence Check
```bash
# Script validates all specified nodes exist
# If a node doesn't exist, deployment is aborted
```

### 2. Node Readiness Check
```bash
# Warns if nodes are not in Ready state
# Deployment continues with warning
```

### 3. Storage Label Check (Optional)
```bash
# Checks for kafka-storage=true label
# Informational only, not required

# To add label:
kubectl label node worker-1 kafka-storage=true
```

## Testing

### Run Test Suite

```bash
# Interactive test menu
./test-node-selectors.sh

# Run all tests automatically
./test-node-selectors.sh all

# Check current placement
./test-node-selectors.sh status

# Clean up test deployment
./test-node-selectors.sh cleanup
```

### Manual Verification

```bash
# Check pod placement
kubectl get pods -n kafka -o wide

# Verify specific pod placement
kubectl get pod broker-pool-0 -n kafka -o jsonpath='{.spec.nodeName}'

# Check PV node affinity
kubectl get pv -l strimzi.io/cluster=my-cluster -o yaml | grep -A5 nodeAffinity

# Monitor pod scheduling events
kubectl describe pod broker-pool-0 -n kafka | grep -A10 Events
```

## Troubleshooting

### Issue: Pods Stuck in Pending

**Symptom**: Pods remain in Pending state

**Possible Causes**:
1. Node doesn't have enough resources
2. PV node affinity doesn't match pod placement
3. Storage not available on target node

**Solution**:
```bash
# Check pod events
kubectl describe pod broker-pool-0 -n kafka

# Check node resources
kubectl describe node worker-1

# Verify PV node affinity matches pod node
kubectl get pv pv-my-cluster-broker-pool-0 -o yaml
```

### Issue: Node Not Found Error

**Symptom**: Script fails with "Node not found in cluster"

**Solution**:
```bash
# List available nodes
kubectl get nodes

# Use exact node names from the output
export KAFKA_BROKER_NODE_SELECTORS="0:actual-node-name"
```

### Issue: Storage Not Binding

**Symptom**: PVCs remain in Pending state

**Possible Causes**:
1. PV node affinity doesn't match pod's node
2. Storage directories don't exist on node
3. Permissions issues

**Solution**:
```bash
# Check PVC status
kubectl get pvc -n kafka

# Verify PV node affinity
kubectl get pv -o yaml | grep -B5 -A5 nodeAffinity

# SSH to node and check directories
ssh node-1 "ls -la /data/strimzi/my-cluster"
```

### Issue: Uneven Distribution

**Symptom**: Multiple brokers on same node despite different selectors

**Check**:
```bash
# Verify environment variables
echo $KAFKA_BROKER_NODE_SELECTORS

# Check actual pod placement
kubectl get pods -n kafka -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName

# Look for topology constraints
kubectl get kafkanodepool broker-pool -n kafka -o yaml | grep -A10 affinity
```

## Best Practices

### 1. Label Your Nodes

```bash
# Label nodes by role
kubectl label node worker-1 node-role=kafka-broker
kubectl label node control-1 node-role=kafka-controller

# Label by storage type
kubectl label node nvme-node-1 storage-type=nvme
kubectl label node worker-1 storage-type=standard
```

### 2. Plan Storage Layout

- **Co-locate storage and compute**: Ensure PVs are on the same nodes as pods
- **Use local storage for performance**: hostPath or local PV for best performance
- **Consider failure domains**: Distribute across zones/racks

### 3. Monitor Resource Usage

```bash
# Check node resources before deployment
kubectl top nodes

# Monitor after deployment
kubectl top pods -n kafka
```

### 4. Use Dedicated Nodes

For production:
- Consider dedicating nodes to Kafka
- Use taints and tolerations for exclusive scheduling
- Separate controller and broker nodes for large clusters

### 5. Document Your Configuration

Create a configuration file:
```bash
# kafka-placement.env
export KAFKA_BROKER_NODE_SELECTORS="0:prod-kafka-1,1:prod-kafka-2,2:prod-kafka-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:prod-control-1,1:prod-control-2,2:prod-control-3"
export STORAGE_MODE="hostPath"
export STRIMZI_HOST_BASE_DIR="/data/kafka"

# Source before deployment
source kafka-placement.env
./strimzi-setup-with-node-selectors.sh
```

## Migration from Existing Deployment

### Step 1: Backup Current Configuration

```bash
# Export current Kafka configuration
kubectl get kafka my-cluster -n kafka -o yaml > kafka-backup.yaml
kubectl get kafkanodepool -n kafka -o yaml > nodepool-backup.yaml
```

### Step 2: Plan Node Mapping

```bash
# Check current pod placement
kubectl get pods -n kafka -o wide

# Plan new placement based on requirements
```

### Step 3: Prepare Target Nodes

```bash
# On each target node
sudo mkdir -p /data/strimzi/my-cluster
sudo chown -R 1001:1001 /data/strimzi
```

### Step 4: Deploy with Node Selectors

```bash
# Set your node mappings
export KAFKA_BROKER_NODE_SELECTORS="0:new-node-1,1:new-node-2,2:new-node-3"

# Run migration (consider doing this during maintenance window)
./strimzi-setup.sh
```

## Advanced Configuration

### Custom Affinity Rules

For more complex affinity requirements, modify the generated NodePool:

```yaml
template:
  pod:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: node-role
              operator: In
              values: ["kafka-broker"]
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          preference:
            matchExpressions:
            - key: storage-type
              operator: In
              values: ["nvme"]
```

### Using with Kubernetes Operators

The node selector configuration works with:
- **Cluster Autoscaler**: Pre-provision or label node groups
- **Karpenter**: Use provisioner requirements
- **Node Feature Discovery**: Leverage hardware labels

## Support and Feedback

For issues or questions:
1. Check the troubleshooting section
2. Review test output: `./test-node-selectors.sh all`
3. Examine pod events: `kubectl describe pod <pod-name> -n kafka`
4. Check operator logs: `kubectl logs -n strimzi -l name=strimzi-cluster-operator`

## Appendix: Complete Example

```bash
#!/bin/bash
# Complete deployment example

# 1. Check available nodes
echo "Available nodes:"
kubectl get nodes

# 2. Label nodes for clarity
kubectl label node worker-1 kafka-role=broker storage=nvme
kubectl label node worker-2 kafka-role=broker storage=nvme
kubectl label node worker-3 kafka-role=broker storage=nvme
kubectl label node control-1 kafka-role=controller storage=ssd

# 3. Set configuration
export STRIMZI_CLUSTER_NAME="production-kafka"
export NS_KAFKA="kafka-prod"
export STORAGE_MODE="hostPath"
export STRIMZI_HOST_BASE_DIR="/data/kafka"

# 4. Configure node placement
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:control-1,1:control-1,2:control-1"

# 5. Configure resources
export KAFKA_BROKER_REPLICAS=3
export KAFKA_CONTROLLER_REPLICAS=3
export STRIMZI_BROKER_STORAGE_SIZE="100Gi"
export STRIMZI_CONTROLLER_STORAGE_SIZE="10Gi"

# 6. Deploy
./strimzi-setup.sh

# 7. Verify
kubectl get pods -n kafka-prod -o wide
kubectl get pv -l strimzi.io/cluster=production-kafka

# 8. Test
kubectl run kafka-test -ti --image=quay.io/strimzi/kafka:latest-kafka-3.9.0 \
  --rm=true --restart=Never -- \
  bin/kafka-topics.sh --bootstrap-server production-kafka-kafka-bootstrap:9092 --list
```