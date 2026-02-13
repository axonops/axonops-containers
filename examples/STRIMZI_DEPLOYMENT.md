# Strimzi Kafka Deployment Guide

This guide covers deploying Apache Kafka using the Strimzi operator on Kubernetes, with optional AxonOps monitoring integration.

## Quick Start

### Step 1: Install Strimzi Operator

Before deploying Kafka clusters, install the Strimzi operator using Helm.

**Important:** Check the [Strimzi downloads page](https://strimzi.io/downloads/) to verify which Strimzi version supports your desired Kafka version. The support matrix shows compatible Kafka versions for each Strimzi release.

```bash
# Add Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Create namespaces
kubectl create namespace strimzi
kubectl create namespace kafka

# Check available versions
helm search repo strimzi --versions

# Install the operator (specify version based on support matrix)
# Example: Strimzi 0.50.0 supports Kafka 4.1.1
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  -n strimzi \
  --version 0.50.0 \
  --set watchNamespaces="{kafka}" \
  --wait

# Verify installation
kubectl get pods -n strimzi
kubectl get crd | grep strimzi
```

### Step 2: Deploy Kafka Cluster

Choose one of the deployment examples based on your use case. Each example includes its own README with detailed deployment instructions:

| Directory | Use Case | Description |
| --- | --- | --- |
| [strimzi/cloud/](strimzi/cloud/) | Production | 6 brokers, 3 controllers, cloud storage |
| [strimzi/local-disk/](strimzi/local-disk/) | On-premises | Local persistent volumes, configurable |
| [strimzi/single/](strimzi/single/) | Development | Single dual-role node |

Each example directory contains:

- `README.md` - Complete deployment instructions
- `strimzi-config.env` - Configuration variables
- YAML manifests for all Kafka cluster components

### Step 3: Add AxonOps Monitoring (Optional)

See [AXONOPS_DEPLOYMENT.md](AXONOPS_DEPLOYMENT.md) for deploying AxonOps monitoring. The Strimzi example manifests include AxonOps agent configuration variables.

---

## Strimzi Version Compatibility

Always check the [Strimzi support matrix](https://strimzi.io/downloads/) before installation to ensure compatibility:

| Strimzi Version | Supported Kafka Versions | Kubernetes Versions |
| --- | --- | --- |
| 0.45.0 | 3.8.x, 3.9.x | 1.25+ |
| 0.44.0 | 3.7.x, 3.8.x | 1.25+ |
| 0.43.0 | 3.7.x, 3.8.x | 1.23+ |

*Note: This table is for reference only. Always verify current compatibility at [strimzi.io/downloads](https://strimzi.io/downloads/).*

### Upgrading Strimzi

```bash
# Check current version
helm list -n strimzi

# Upgrade to new version
helm upgrade strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  -n strimzi \
  --version <new-version>
```

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
- **Strimzi GitHub**: [https://github.com/strimzi/strimzi-kafka-operator](https://github.com/strimzi/strimzi-kafka-operator)
- **Node Selector Guide**: [NODE_SELECTOR_GUIDE.md](NODE_SELECTOR_GUIDE.md)
- **AxonOps Integration**: [AXONOPS_DEPLOYMENT.md](AXONOPS_DEPLOYMENT.md)
- **AxonOps Agent Setup**: [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Apache Kafka Documentation**: [https://kafka.apache.org/documentation/](https://kafka.apache.org/documentation/)
- **KRaft Documentation**: [https://kafka.apache.org/documentation/#kraft](https://kafka.apache.org/documentation/#kraft)

---

**Last Updated:** 2026-02-13
