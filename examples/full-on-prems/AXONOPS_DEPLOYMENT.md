# AxonOps Deployment Guide

This guide covers deploying AxonOps monitoring and management services on Kubernetes.

## Quick Start

```bash
# Set the required passwords
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-password'

# Deploy AxonOps services
./axonops-setup.sh
```

That's it! AxonOps services will be deployed and ready to monitor your Kafka clusters.

---

## Overview

AxonOps provides comprehensive monitoring and management for Apache Kafka clusters. The deployment consists of four main components:

- **axon-server** - Core monitoring and management server
- **axondb-timeseries** - Time-series database for metrics storage
- **axondb-search** - Search database for log aggregation and querying
- **axon-dash** - Web-based dashboard for visualization

## Prerequisites

1. **Kubernetes Cluster** (single or multi-node)
2. **Required Tools**:
   - `kubectl` - Kubernetes CLI
   - `helm` - Helm package manager v3.x or later
3. **Namespace**: By default uses `axonops` namespace (auto-created)

## Configuration

### Required Configuration

**CRITICAL**: Set the required passwords before deploying:

```bash
export AXON_SEARCH_PASSWORD='YourSecurePasswordHere'
export AXON_SERVER_CQL_PASSWORD='YourSecureCQLPasswordHere'
```

### Optional Configuration

Customize the deployment by setting these environment variables:

```bash
# Namespace
export NS_AXONOPS="axonops"           # Default namespace for AxonOps

# AxonOps Server configuration
export AXON_SERVER_AGENTS_PORT="1888"       # Port for Kafka agents (default: 1888)
export AXON_SERVER_API_PORT="8080"          # API port (default: 8080)

# Storage configuration
export AXON_SEARCH_USE_HOSTPATH="false"     # Use hostPath for Search DB (default: false)
export AXON_TIMESERIES_USE_HOSTPATH="false" # Use hostPath for Timeseries DB (default: false)

# Storage sizes (for PVC mode)
export AXON_TIMESERIES_VOLUME_SIZE="10Gi"   # Timeseries DB storage
export AXON_SEARCH_VOLUME_SIZE="10Gi"       # Search DB storage

# Dashboard access
export AXON_DASH_INGRESS_ENABLED="false"    # Enable Ingress (default: false)
export AXON_DASH_INGRESS_HOST=""            # Ingress hostname
export AXON_DASH_NODEPORT_ENABLED="false"   # Enable NodePort (default: false)
export AXON_DASH_NODEPORT_PORT=""           # NodePort port number

export AXON_SEARCH_USER=admin
export AXON_SEARCH_PASSWORD=secure-password-here-5o02GzIn+58JbgU437WI8QksSHE
export AXON_SERVER_CQL_USERNAME=axonops
export AXON_SERVER_CQL_PASSWORD=secure-password-here-4kaZo3tLV3zuBRsLN2Xtudn1qwc
```

### Storage Options

AxonOps supports two storage modes for its databases:

#### PVC Mode (Default - Recommended)

Uses dynamic PersistentVolumeClaims with your cluster's default or specified storage class:

```bash
# Use default storage class
./axonops-setup.sh

# Or specify storage sizes
export AXON_TIMESERIES_VOLUME_SIZE="50Gi"
export AXON_SEARCH_VOLUME_SIZE="20Gi"
./axonops-setup.sh
```

**Benefits:**
- Works with any storage provider
- Suitable for production environments
- Supports multi-node clusters
- Automatic volume management

#### hostPath Mode (Single-Node Testing Only)

Uses local directories on the Kubernetes node:

```bash
export AXON_SEARCH_USE_HOSTPATH="true"
export AXON_TIMESERIES_USE_HOSTPATH="true"
./axonops-setup.sh
```

**Limitations:**
- Requires single-node cluster
- Not suitable for production
- Manual directory creation required

If using hostPath mode, create directories on the node:

```bash
# On the Kubernetes node
sudo mkdir -p /data/axon-timeseries /data/axon-search
sudo chown -R 999:999 /data/axon-timeseries /data/axon-search
sudo chmod -R 755 /data/axon-timeseries /data/axon-search
```

## Deployment Steps

### Step 1: Set Required Passwords

```bash
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
```

### Step 2: (Optional) Customize Configuration

```bash
# Example: Change namespace
export NS_AXONOPS="monitoring"

# Example: Use larger storage
export AXON_TIMESERIES_VOLUME_SIZE="100Gi"
export AXON_SEARCH_VOLUME_SIZE="50Gi"
```

### Step 3: Run Deployment Script

```bash
chmod +x axonops-setup.sh
./axonops-setup.sh
```

The script will:
1. Install cert-manager (if not already installed)
2. Deploy AxonDB Timeseries database
3. Deploy AxonDB Search database
4. Deploy AxonOps Server
5. Deploy AxonOps Dashboard
6. Create `axonops-config.env` with connection details

### Step 4: Wait for Services to be Ready

```bash
# Check pod status
kubectl get pods -n axonops

# Wait for all pods to be Running
kubectl wait --for=condition=ready pod --all -n axonops --timeout=300s
```

## Accessing AxonOps Dashboard

### Option 1: Port Forward (Quick Access)

```bash
kubectl port-forward -n axonops svc/axon-dash 3000:3000

# Access at: http://localhost:3000
```

### Option 2: NodePort (External Access)

Enable NodePort during deployment:

```bash
export AXON_DASH_NODEPORT_ENABLED="true"
export AXON_DASH_NODEPORT_PORT="32000"
./axonops-setup.sh

# Access at: http://<node-ip>:32000
```

### Option 3: Ingress (Production)

Enable Ingress during deployment:

```bash
export AXON_DASH_INGRESS_ENABLED="true"
export AXON_DASH_INGRESS_HOST="axonops.yourdomain.com"
./axonops-setup.sh

# Access at: https://axonops.yourdomain.com
```

**Note:** Requires an Ingress controller installed in your cluster.

## Integration with Kafka

After deploying AxonOps, you can connect it to your Kafka clusters:

### For New Strimzi Deployments

```bash
# Source the AxonOps configuration
source axonops-config.env

# Deploy Strimzi with AxonOps integration
./strimzi-setup.sh
```

See [STRIMZI_DEPLOYMENT.md](STRIMZI_DEPLOYMENT.md) for details.

### For Existing Kafka Clusters

Configure the AxonOps agent on your Kafka brokers using the connection details from `axonops-config.env`:

```bash
# Agent connection details
AXON_AGENT_SERVER_HOST=axon-server-agent.axonops.svc.cluster.local
AXON_AGENT_SERVER_PORT=1888
```

## Verifying the Deployment

### Check Component Status

```bash
# View all AxonOps pods
kubectl get pods -n axonops

# View all services
kubectl get svc -n axonops

# Check Helm releases
helm list -n axonops
```

Expected output:
- 4 Helm releases: `axon-server`, `axondb-timeseries`, `axondb-search`, `axon-dash`
- All pods in Running state
- Services with ClusterIP endpoints

### Check Logs

```bash
# AxonOps Server logs
kubectl logs -n axonops deployment/axon-server -f

# Dashboard logs
kubectl logs -n axonops deployment/axon-dash -f

# Timeseries DB logs
kubectl logs -n axonops statefulset/axondb-timeseries -f

# Search DB logs
kubectl logs -n axonops statefulset/axondb-search -f
```

### Test Dashboard Access

```bash
# Port-forward and open browser
kubectl port-forward -n axonops svc/axon-dash 3000:3000

# In another terminal or browser, navigate to:
# http://localhost:3000
```

## Troubleshooting

### Pods Stuck in Pending State

**Check PersistentVolume Claims:**

```bash
kubectl get pvc -n axonops
```

**Possible causes:**
- No storage class available
- Insufficient storage capacity
- For hostPath mode: directories not created or wrong permissions

**Solutions:**

```bash
# Check available storage classes
kubectl get storageclass

# For hostPath mode, verify directories exist
ssh <node> "ls -la /data/axon-timeseries /data/axon-search"

# Check pod events
kubectl describe pod <pod-name> -n axonops
```

### Search Database Connection Issues

**Symptom:** AxonOps Server can't connect to Search database

**Check password configuration:**

```bash
# Verify secret exists
kubectl get secret axon-server-config -n axonops

# Check server configuration
kubectl get secret axon-server-config -n axonops -o jsonpath='{.data.axon-server\.yml}' | base64 -d
```

**Solution:**

```bash
# Recreate the secret with correct password
kubectl delete secret axon-server-config -n axonops
export AXON_SEARCH_PASSWORD='your-password'
export AXON_SERVER_CQL_PASSWORD='your-cql-password'
./axonops-setup.sh
```

### Dashboard Not Accessible

**Check service type:**

```bash
kubectl get svc axon-dash -n axonops
```

**If using NodePort, verify port is accessible:**

```bash
# Check firewall rules
# Ensure node port is open in security groups/firewall

# Test connectivity
curl http://<node-ip>:<nodeport>
```

**If using Ingress, verify Ingress configuration:**

```bash
kubectl get ingress -n axonops
kubectl describe ingress axon-dash -n axonops
```

### Certificate Issues

**Check cert-manager status:**

```bash
kubectl get pods -n cert-manager
kubectl get clusterissuer
```

**View certificate status:**

```bash
kubectl get certificate -n axonops
kubectl describe certificate -n axonops
```

## Configuration Reference

### Generated Configuration File

After deployment, `axonops-config.env` is created with these variables:

```bash
NS_AXONOPS=axonops
AXON_SERVER_AGENTS_PORT=1888
AXON_SERVER_API_PORT=8080
AXON_SERVER_ORG_NAME=example
```

Source this file before deploying Kafka to enable automatic integration.

### Helm Chart Versions

The script uses specific chart versions:

- **axondb-timeseries**: Latest from AxonOps repository
- **axondb-search**: Latest from AxonOps repository
- **axon-server**: Latest from AxonOps repository
- **axon-dash**: Latest from AxonOps repository

## Cleanup

### Remove AxonOps Services

```bash
# Uninstall Helm releases
helm uninstall -n axonops axon-dash
helm uninstall -n axonops axon-server
helm uninstall -n axonops axondb-search
helm uninstall -n axonops axondb-timeseries

# Delete namespace
kubectl delete namespace axonops
```

### Remove Data (CAUTION: Deletes all data)

For hostPath storage:

```bash
# On the Kubernetes node
sudo rm -rf /data/axon-timeseries
sudo rm -rf /data/axon-search
```

For PVC storage, delete PVCs:

```bash
kubectl delete pvc -n axonops --all
```

### Remove cert-manager (Optional)

Only if not used by other services:

```bash
helm uninstall -n cert-manager cert-manager
kubectl delete namespace cert-manager
```

## Production Considerations

For production deployments:

1. **Storage**: Use distributed storage with proper backup and disaster recovery
2. **High Availability**: Consider deploying multiple replicas (requires Helm chart customization)
3. **Security**:
   - Use strong passwords
   - Enable TLS for all components
   - Configure proper RBAC
   - Use network policies
4. **Monitoring**: Monitor AxonOps components themselves
5. **Resource Limits**: Set appropriate CPU and memory limits
6. **Backup**: Regular backups of Search and Timeseries databases
7. **Access Control**: Use Ingress with authentication/authorization

## Additional Resources

- **AxonOps Documentation**: [https://docs.axonops.com](https://docs.axonops.com)
- **Strimzi Integration**: See [STRIMZI_DEPLOYMENT.md](STRIMZI_DEPLOYMENT.md)
- **Helm Charts**: AxonOps Helm repository
- **Support**: Contact AxonOps support for production deployments
