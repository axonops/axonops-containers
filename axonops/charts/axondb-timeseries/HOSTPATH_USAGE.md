# HostPath Volume Support for axondb-timeseries Helm Chart

## Overview

The axondb-timeseries Helm chart **supports hostPath volumes** through multiple configuration methods. While not a built-in option, hostPath can be configured using the chart's flexible volume configuration capabilities.

## Important Considerations

⚠️ **Security Warning**: hostPath volumes present security risks and should be used with caution:
- Pods can access sensitive host directories
- Limited to single-node deployments
- No automatic data migration if pod moves to another node
- Requires careful permission management

## Configuration Methods

### Method 1: Direct hostPath via extraVolumes (Recommended for Testing)

This is the simplest approach, suitable for development and testing environments.

```yaml
# Disable PVC-based persistence
persistence:
  enabled: false

# Define hostPath volumes
extraVolumes:
  - name: data
    hostPath:
      path: /data/cassandra
      type: DirectoryOrCreate
  - name: commitlog
    hostPath:
      path: /data/cassandra-commitlog
      type: DirectoryOrCreate

# Mount the volumes
extraVolumeMounts:
  - name: data
    mountPath: /var/lib/cassandra
  - name: commitlog
    mountPath: /var/lib/cassandra/commitlog
```

**Deployment:**
```bash
helm install axondb-timeseries ./axonops/charts/axondb-timeseries \
  -f values-hostpath-example.yaml
```

### Method 2: Using PersistentVolume with hostPath

This approach provides better abstraction and is more suitable for production-like environments.

1. **Create PV and PVC:**
```bash
kubectl apply -f hostpath-pv-pvc.yaml
```

2. **Configure values.yaml:**
```yaml
persistence:
  enabled: true
  data:
    existingClaim: "cassandra-data-pvc"
  commitlog:
    enabled: true
    existingClaim: "cassandra-commitlog-pvc"
```

3. **Deploy the chart:**
```bash
helm install axondb-timeseries ./axonops/charts/axondb-timeseries \
  --set persistence.data.existingClaim=cassandra-data-pvc \
  --set persistence.commitlog.enabled=true \
  --set persistence.commitlog.existingClaim=cassandra-commitlog-pvc
```

### Method 3: Using Local StorageClass

For dynamic provisioning with hostPath-like behavior:

1. **Create a local StorageClass:**
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

2. **Configure values.yaml:**
```yaml
persistence:
  enabled: true
  data:
    storageClass: "local-storage"
    size: 10Gi
  commitlog:
    enabled: true
    storageClass: "local-storage"
    size: 5Gi
```

## hostPath Type Options

When using hostPath, you can specify different type behaviors:

| Type | Behavior |
|------|----------|
| `""` (empty) | No checks performed |
| `DirectoryOrCreate` | Creates directory if it doesn't exist |
| `Directory` | Directory must exist |
| `FileOrCreate` | Creates file if it doesn't exist |
| `File` | File must exist |
| `Socket` | Unix socket must exist |
| `CharDevice` | Character device must exist |
| `BlockDevice` | Block device must exist |

## Best Practices

### 1. Node Affinity
Always configure node affinity to ensure the pod schedules on the correct node:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - your-specific-node
```

### 2. Permissions
Ensure correct permissions on host directories:

```bash
# On the host node
sudo mkdir -p /data/cassandra /data/cassandra-commitlog
sudo chown -R 999:999 /data/cassandra /data/cassandra-commitlog
sudo chmod -R 750 /data/cassandra /data/cassandra-commitlog
```

### 3. Security Context
Configure appropriate security context:

```yaml
podSecurityContext:
  fsGroup: 999
securityContext:
  runAsUser: 999
  runAsNonRoot: true
```

### 4. Single Replica
When using hostPath, limit to single replica:

```yaml
replicaCount: 1
```

## Verification

After deployment, verify the volume mounts:

```bash
# Check pod volumes
kubectl describe pod <pod-name> | grep -A 10 "Volumes:"

# Verify mount inside container
kubectl exec <pod-name> -- df -h /var/lib/cassandra

# Check data persistence
kubectl exec <pod-name> -- ls -la /var/lib/cassandra
```

## Migration from hostPath

To migrate away from hostPath to a proper storage solution:

1. Backup your data:
```bash
kubectl exec <pod-name> -- tar czf /tmp/backup.tar.gz /var/lib/cassandra
kubectl cp <pod-name>:/tmp/backup.tar.gz ./backup.tar.gz
```

2. Deploy with new storage configuration
3. Restore data to new volume

## Troubleshooting

### Permission Denied
If you encounter permission issues:
```bash
# On host
sudo chown -R 999:999 /data/cassandra
```

### Pod Stuck in Pending
Check node affinity and ensure the specified node exists:
```bash
kubectl get nodes
kubectl describe pod <pod-name>
```

### Data Not Persisting
Verify hostPath is correctly mounted:
```bash
kubectl exec <pod-name> -- mount | grep cassandra
```

## Conclusion

The axondb-timeseries chart fully supports hostPath volumes through its flexible configuration options. Choose the method that best fits your use case:

- **Method 1**: Quick testing and development
- **Method 2**: Production-like environments with better abstraction
- **Method 3**: When you need dynamic provisioning with local storage

Remember that hostPath is best suited for single-node deployments and testing scenarios. For production use, consider using proper persistent storage solutions like cloud provider volumes or distributed storage systems.