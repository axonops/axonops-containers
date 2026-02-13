# AxonOps Server Examples

This directory contains example configurations and setup scripts for deploying AxonOps monitoring platform on Kubernetes.

## Overview

AxonOps provides comprehensive monitoring and management for Apache Kafka and Cassandra clusters. The deployment consists of:

- **axon-server** - Core monitoring and management server
- **axondb-timeseries** - Time-series database for metrics storage (Cassandra-based)
- **axondb-search** - Search database for log aggregation (OpenSearch-based)
- **axon-dash** - Web-based dashboard for visualization

## Prerequisites

- A Kubernetes cluster (v1.21+)
- `kubectl` configured with cluster access
- `helm` v3.x or later
- `envsubst` command (part of `gettext` package)

## Files

| File | Description |
| --- | --- |
| `axonops-config.env` | Environment variables for AxonOps configuration |
| `axonops-setup.sh` | Automated deployment script for AxonOps |
| `strimzi-setup.env` | Environment variables for Strimzi Kafka configuration |
| `strimzi-setup.sh` | Strimzi Kafka deployment script (with AxonOps integration) |
| `axonops-server-secret.yaml` | Example Secret for axon-server configuration |
| `axonops-dash-values.yaml` | Helm values for AxonOps Dashboard |
| `search-values.yaml` | Helm values for AxonDB Search |
| `timeseries-values.yaml` | Helm values for AxonDB Timeseries |
| `strimzi/` | Symlink to Strimzi local-disk examples |

## Quick Start

### Using the Setup Script

```bash
# Set required passwords
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'

# Run the setup script
./axonops-setup.sh
```

The script will:
1. Install cert-manager (if needed)
2. Deploy AxonDB Timeseries
3. Deploy AxonDB Search
4. Deploy AxonOps Server
5. Deploy AxonOps Dashboard
6. Generate `axonops-config.env` with connection details

### Manual Deployment with Helm

```bash
# Source configuration
export $(grep -v '^#' axonops-config.env | xargs)

# Add AxonOps Helm repository
helm repo add axonops https://helm.axonops.com
helm repo update

# Create namespace
kubectl create namespace axonops

# Deploy components
helm install axondb-timeseries axonops/axondb-timeseries \
  -n axonops -f timeseries-values.yaml

helm install axondb-search axonops/axondb-search \
  -n axonops -f search-values.yaml

helm install axon-server axonops/axon-server \
  -n axonops --set searchDb.password=$AXON_SEARCH_PASSWORD

helm install axon-dash axonops/axon-dash \
  -n axonops -f axonops-dash-values.yaml
```

## Configuration

### Environment Variables

Edit `axonops-config.env` to customize your deployment:

```bash
# Namespace
NS_AXONOPS=axonops

# Server ports
AXON_SERVER_AGENTS_PORT=1888    # Port for Kafka/Cassandra agents
AXON_SERVER_API_PORT=8080       # API port

# Organization
AXON_SERVER_ORG_NAME=example

# Search database credentials
AXON_SEARCH_USER=admin
AXON_SEARCH_PASSWORD=your-secure-password

# Timeseries database credentials
AXON_SERVER_CQL_USERNAME=axonops
AXON_SERVER_CQL_PASSWORD=your-secure-cql-password
```

### Server Configuration Secret

The `axonops-server-secret.yaml` contains the full server configuration. Key settings:

| Setting | Description |
| --- | --- |
| `agents_port` | Port for agent connections (1888) |
| `api_port` | REST API port (8080) |
| `search_db.hosts` | OpenSearch endpoint |
| `cql_hosts` | Cassandra hosts for metrics storage |
| `org_name` | Organization name |
| `tls.mode` | TLS mode (disabled/enabled) |
| `auth.enabled` | Authentication toggle |

## Accessing the Dashboard

### Port Forward (Quick Access)

```bash
kubectl port-forward -n axonops svc/axon-dash 3000:3000

# Access at: http://localhost:3000
```

### NodePort

```bash
export AXON_DASH_NODEPORT_ENABLED=true
export AXON_DASH_NODEPORT_PORT=32000
./axonops-setup.sh

# Access at: http://<node-ip>:32000
```

### Ingress

```bash
export AXON_DASH_INGRESS_ENABLED=true
export AXON_DASH_INGRESS_HOST=axonops.yourdomain.com
./axonops-setup.sh

# Access at: https://axonops.yourdomain.com
```

## Integrating with Data Platforms

### Strimzi Kafka

After deploying AxonOps, integrate with Kafka:

```bash
# Source AxonOps configuration
source axonops-config.env

# Configure Strimzi (edit strimzi-setup.env as needed)
vi strimzi-setup.env

# Source Strimzi configuration and deploy
source strimzi-setup.env
./strimzi-setup.sh
```

Or use environment variables directly:

```bash
source axonops-config.env
export STRIMZI_NODE_HOSTNAME='your-node-name'
export STRIMZI_CLUSTER_NAME='my-cluster'
./strimzi-setup.sh
```

Or use the Strimzi cloud examples:

```bash
cd ../strimzi/cloud/
export AXON_AGENT_SERVER_HOST=axon-server-agent.axonops.svc.cluster.local
export AXON_AGENT_SERVER_PORT=1888
# ... apply manifests
```

### K8ssandra Cassandra

Configure K8ssandra to connect to self-hosted AxonOps:

```bash
export AXON_AGENT_SERVER_HOST=axon-server-agent.axonops.svc.cluster.local
export AXON_AGENT_SERVER_PORT=1888
export AXON_AGENT_ORG=$AXON_SERVER_ORG_NAME

cd ../k8ssandra/
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

## Verification

```bash
# Check all pods
kubectl get pods -n axonops

# Check services
kubectl get svc -n axonops

# Check Helm releases
helm list -n axonops

# View server logs
kubectl logs -n axonops deployment/axon-server
```

## Cleanup

```bash
# Uninstall Helm releases
helm uninstall axon-dash -n axonops
helm uninstall axon-server -n axonops
helm uninstall axondb-search -n axonops
helm uninstall axondb-timeseries -n axonops

# Delete namespace
kubectl delete namespace axonops
```

## Related Documentation

- [Full AxonOps Deployment Guide](../AXONOPS_DEPLOYMENT.md)
- [Strimzi Kafka Integration](../STRIMZI_DEPLOYMENT.md)
- [K8ssandra Integration](../K8SSANDRA_DEPLOYMENT.md)
- [AxonOps Documentation](https://docs.axonops.com)
- [AxonOps Agent Setup](https://axonops.com/docs/get_started/agent_setup/)
