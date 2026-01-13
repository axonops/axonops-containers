# AxonOps Meta-Chart

## Overview

This Helm chart deploys the complete AxonOps observability stack for Apache Cassandra and Kafka monitoring. It acts as an umbrella chart that orchestrates the deployment of all AxonOps components with sensible defaults.

### Components

The meta-chart deploys the following components in order:

1. **axondb-timeseries** - Time-series database (Cassandra 5.0.6) for metrics storage
2. **axondb-search** - Search backend (OpenSearch 3.3.2) for logs and search functionality
3. **axon-server** - Core AxonOps observability platform
4. **axon-dash** - Web-based dashboard UI

All sub-charts are hosted on the AxonOps OCI registry at `ghcr.io/axonops/charts`.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8+
- PV provisioner support in the cluster (for persistent storage)
- Minimum cluster resources (with default 8G heap settings):
  - 8 CPU cores
  - 40GB RAM (for 8G heap on both databases + overhead)
  - 200GB storage (100GB per database)

## Installation

### Quick Start

Deploy the complete AxonOps stack with default settings:

```bash
# Navigate to the chart directory
cd axonops/charts/axonops

# Update dependencies from OCI registry
helm dependency update

# Install the chart
helm install axonops . --namespace axonops --create-namespace
```

**Note:** The default configuration uses 8GB heap for both databases. For development environments with limited resources, see the [Resource Configuration](#resource-configuration) section below.

### Custom Installation

Install with custom values file:

```bash
# Create a custom values file
cat > custom-values.yaml <<EOF
axon-server:
  config:
    org_name: "my-organization"
    license_key: "your-license-key"
  dashboardUrl: https://axonops.mydomain.com

axondb-timeseries:
  persistence:
    size: 50Gi

axondb-search:
  persistence:
    size: 50Gi
EOF

# Install with custom values
helm install axonops . -f custom-values.yaml --namespace axonops --create-namespace
```

### Production Installation

For production deployments, you MUST:

1. **Change all default passwords**
2. **Set your organization name and license key**
3. **Configure appropriate resource limits**
4. **Enable persistent storage with appropriate sizes**

```bash
# Generate secure passwords
SEARCH_PASSWORD=$(openssl rand -base64 32)
CASSANDRA_PASSWORD=$(openssl rand -base64 32)

# Install with secure configuration
helm install axonops . \
  --namespace axonops \
  --create-namespace \
  --set axon-server.config.org_name="production-org" \
  --set axon-server.config.license_key="YOUR_LICENSE_KEY" \
  --set axon-server.dashboardUrl="https://axonops.yourdomain.com" \
  --set axondb-search.security.adminPassword="$SEARCH_PASSWORD" \
  --set axondb-timeseries.cassandra.auth.password="$CASSANDRA_PASSWORD" \
  --set axon-server.searchDb.password="$SEARCH_PASSWORD" \
  --set axon-server.config.extraConfig.cql_password="$CASSANDRA_PASSWORD" \
  --set axon-server.config.extraConfig.cql_username="cassandra" \
  --set axondb-timeseries.cassandra.auth.username="cassandra" \
  --set axondb-timeseries.persistence.size=200Gi \
  --set axondb-search.persistence.size=200Gi
```

## Configuration

### Key Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `axondb-timeseries.enabled` | Enable Cassandra timeseries database | `true` |
| `axondb-search.enabled` | Enable OpenSearch backend | `true` |
| `axon-server.enabled` | Enable AxonOps server | `true` |
| `axon-dash.enabled` | Enable dashboard UI | `true` |
| `axondb-timeseries.heapSize` | JVM heap size for Cassandra | `8192M` |
| `axondb-search.opensearchHeapSize` | JVM heap size for OpenSearch | `8g` |
| `axon-server.config.org_name` | Your organization name | `example` |
| `axon-server.config.license_key` | AxonOps license key | `""` |
| `axon-server.dashboardUrl` | Public URL for dashboard | `https://axonops.example.com` |

### Resource Configuration

Default resource allocations with 8G heap for production:

```yaml
axondb-timeseries:
  heapSize: 8192M  # 8G heap for production
  resources:
    requests:
      memory: 9Gi    # Heap + overhead
      cpu: 1000m
    limits:
      memory: 10Gi
      cpu: 2000m

axondb-search:
  opensearchHeapSize: "8g"  # 8G heap for production
  resources:
    requests:
      memory: 9Gi    # Heap + overhead
      cpu: 1000m
    limits:
      memory: 10Gi
      cpu: 2000m

axon-server:
  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 1Gi
      cpu: 500m
```

For development/testing environments, you can reduce the heap sizes:

```yaml
axondb-timeseries:
  heapSize: 2048M  # 2G heap for dev/test

axondb-search:
  opensearchHeapSize: "2g"  # 2G heap for dev/test
```

### Storage Configuration

Default storage configuration (100Gi per database):

```yaml
axondb-timeseries:
  persistence:
    enabled: true
    size: 100Gi  # Default for production
    # storageClass: "fast-ssd"  # Optional: specify storage class

axondb-search:
  persistence:
    enabled: true
    size: 100Gi  # Default for production
    # storageClass: "fast-ssd"  # Optional: specify storage class
```

## Security

### WARNING: Default Credentials

This chart includes default passwords for development/testing purposes. **NEVER use these defaults in production!**

Default credentials:
- OpenSearch admin: `admin` / `MyS3cur3P@ss2025`
- Cassandra: `cassandra` / `cassandra`

### Changing Passwords

Always set custom passwords for production:

```bash
helm install axonops . \
  --set axondb-search.security.adminPassword="YOUR_SECURE_PASSWORD" \
  --set axondb-timeseries.cassandra.auth.password="YOUR_SECURE_PASSWORD" \
  --set axon-server.searchDb.password="YOUR_SECURE_PASSWORD" \
  --set axon-server.config.extraConfig.cql_password="YOUR_SECURE_PASSWORD"
```

### TLS Configuration

Enable TLS for axon-server:

```yaml
axon-server:
  config:
    tls:
      mode: "TLS"  # or "mTLS" for mutual TLS
      cert: |
        -----BEGIN CERTIFICATE-----
        YOUR_CERTIFICATE_HERE
        -----END CERTIFICATE-----
      key: |
        -----BEGIN PRIVATE KEY-----
        YOUR_PRIVATE_KEY_HERE
        -----END PRIVATE KEY-----
```

## Selective Deployment

You can deploy only specific components by disabling others:

### Deploy only databases

```bash
helm install axonops-db . \
  --set axon-server.enabled=false \
  --set axon-dash.enabled=false
```

### Deploy without dashboard

```bash
helm install axonops . \
  --set axon-dash.enabled=false
```

### Deploy without search backend

```bash
helm install axonops . \
  --set axondb-search.enabled=false
```

### Development deployment with reduced resources

```bash
# Deploy with 2G heap for development/testing
helm install axonops-dev . \
  --namespace axonops-dev \
  --create-namespace \
  --set axondb-timeseries.heapSize=2048M \
  --set axondb-timeseries.resources.requests.memory=3Gi \
  --set axondb-timeseries.resources.limits.memory=4Gi \
  --set axondb-search.opensearchHeapSize="2g" \
  --set axondb-search.resources.requests.memory=3Gi \
  --set axondb-search.resources.limits.memory=4Gi \
  --set axondb-timeseries.persistence.size=20Gi \
  --set axondb-search.persistence.size=20Gi
```

## Accessing Services

### Dashboard Access

After installation, access the dashboard:

1. **Port-forward** (for testing):
```bash
kubectl port-forward -n axonops svc/axonops-axon-dash 3000:3000
# Access at http://localhost:3000
```

2. **Ingress** (for production):
Configure ingress in values:
```yaml
axon-dash:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: axonops.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: axonops-tls
        hosts:
          - axonops.yourdomain.com
```

### API Access

The AxonOps API is available at:
```bash
kubectl port-forward -n axonops svc/axonops-axon-server-api 8080:8080
# API at http://localhost:8080
```

### Agent Connection

Cassandra agents connect to:

- Service: `axonops-axon-server-agent`
- Port: `1888`
- Endpoint from outside cluster: Configure ingress or LoadBalancer

## Monitoring

### Check Pod Status

```bash
# Watch pod startup
kubectl get pods -n axonops --watch

# Check pod logs
kubectl logs -n axonops deployment/axonops-axon-server
kubectl logs -n axonops statefulset/axondb-timeseries
kubectl logs -n axonops statefulset/axondb-search-cluster-master
```

### Expected Startup Order

1. `axondb-timeseries-0` - Should be Running first
2. `axondb-search-cluster-master-0` - Should be Running second
3. `axonops-axon-server-*` - Starts after databases are ready
4. `axonops-axon-dash-*` - Starts last

### Verify Services

```bash
# List all services
kubectl get svc -n axonops

# Expected services (assuming release name "axonops"):
# - axondb-timeseries
# - axondb-timeseries-headless
# - axondb-search-cluster-master
# - axondb-search-cluster-master-headless
# - axonops-axon-server-api
# - axonops-axon-server-agent
# - axonops-axon-dash
```

### Test Connectivity

```bash
# Test OpenSearch
kubectl exec -n axonops deploy/axonops-axon-server -- \
  curl -k -u admin:MyS3cur3P@ss2025 https://axondb-search-cluster-master:9200

# Test Cassandra
kubectl exec -n axonops deploy/axonops-axon-server -- \
  nc -zv axondb-timeseries-headless 9042
```

## Troubleshooting

### Pods Not Starting

1. **Check events**:
```bash
kubectl describe pod -n axonops <pod-name>
```

2. **Check logs**:
```bash
kubectl logs -n axonops <pod-name> --previous
```

3. **Common issues**:
- Insufficient resources: Increase memory/CPU limits
- Storage issues: Check PVC status
- Image pull errors: Check registry access

### Service Connection Issues

1. **Verify DNS resolution**:
```bash
kubectl exec -n axonops deploy/axonops-axon-server -- nslookup axondb-timeseries-headless
```

2. **Check service endpoints**:
```bash
kubectl get endpoints -n axonops
```

3. **Test port connectivity**:
```bash
kubectl exec -n axonops deploy/axonops-axon-server -- nc -zv axondb-search-cluster-master 9200
```

### Database Issues

**Cassandra not ready**:
```bash
# Check Cassandra status
kubectl exec -n axonops axondb-timeseries-0 -- nodetool status
```

**OpenSearch not ready**:
```bash
# Check cluster health
kubectl exec -n axonops axondb-search-cluster-master-0 -- \
  curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health?pretty
```

### Reinstalling

If you need to reinstall:

```bash
# Uninstall
helm uninstall axonops -n axonops

# Clean up PVCs (WARNING: This deletes data!)
kubectl delete pvc -n axonops --all

# Reinstall
helm install axonops . --namespace axonops --create-namespace
```

## Testing

### Dependency Version Validation

The meta-chart includes automated validation that ensures the dependency versions in `Chart.yaml` match the actual versions of the individual sub-charts. This validation runs automatically in GitHub Actions on every push and pull request.

**What it validates:**

- All dependency versions in the meta-chart match the actual sub-chart versions
- No version mismatches exist before building dependencies
- The chart is ready for release

**CI/CD Integration:**

The validation runs as part of the `helm-charts-test.yml` workflow in the `validate-dependency-versions` job:

- ✅ Automatically runs on pushes to development and feature branches
- ✅ Runs on pull requests to main and development branches
- ✅ Can be triggered manually via workflow_dispatch
- ✅ Fast execution (~30 seconds)
- ✅ Fails the build if versions don't match

**What happens on failure:**

If a version mismatch is detected, the workflow will fail with a clear message showing:

- Which chart has a mismatch
- The expected version (from the sub-chart)
- The version specified in the meta-chart dependencies
- Instructions on how to fix it

## Upgrade

To upgrade the deployment:

```bash
# Update dependencies
helm dependency update

# Upgrade release
helm upgrade axonops . -n axonops
```

## Uninstall

To remove the deployment:

```bash
# Uninstall the chart
helm uninstall axonops -n axonops

# Optional: Remove namespace
kubectl delete namespace axonops

# Optional: Remove persistent volumes (WARNING: Data loss!)
kubectl delete pvc -n axonops --all
```

## Values Reference

See [values.yaml](values.yaml) for the complete list of configuration options with detailed comments.

## Support

For issues, questions, or contributions:
- GitHub: https://github.com/axonops/axonops-containers
- Email: info@axonops.com
- Documentation: https://axonops.com/docs

## License

Copyright AxonOps. All rights reserved.