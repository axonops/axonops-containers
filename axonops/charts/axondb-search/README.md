# AxonOps Search DB

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3.3.2-1.1.0](https://img.shields.io/badge/AppVersion-3.3.2--1.1.0-informational?style=flat-square)

A Helm chart for deploying the AxonOps Search DB on Kubernetes. This search database powers the AxonOps platform's indexing and search capabilities for logs, events, and operational data.

**Homepage:** <https://axonops.com>

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation Examples](#installation-examples)
  - [Basic Installation](#basic-installation)
  - [Installation with Custom Storage](#installation-with-custom-storage)
  - [Installation with Authentication](#installation-with-authentication)
  - [Installation with TLS (Manual Certificates)](#installation-with-tls-manual-certificates)
  - [Installation with TLS (cert-manager)](#installation-with-tls-cert-manager)
  - [Multi-Node Cluster Installation](#multi-node-cluster-installation)
  - [Production-Ready Installation](#production-ready-installation)
- [Backup Configuration](#backup-configuration)
  - [Local Backups](#local-backups)
  - [S3 Backups](#s3-backups)
- [External Secret Management (vals-operator)](#external-secret-management-vals-operator)
- [Configuration](#configuration)
- [Upgrading](#upgrading)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before you begin, ensure you have the following:

- **Kubernetes cluster**: Version 1.19 or higher
- **kubectl**: Configured to communicate with your cluster
- **Helm**: Version 3.0 or higher installed ([Installation guide](https://helm.sh/docs/intro/install/))
- **Storage**: A default StorageClass configured in your cluster, or a specific StorageClass for persistent volumes
- **Resources**: At least 4GB of available memory and 2 CPU cores recommended

### Optional Prerequisites

- **cert-manager**: Required only if you want automatic TLS certificate management ([Installation guide](https://cert-manager.io/docs/installation/))
- **Prometheus Operator**: Required only if you want to enable metrics monitoring with ServiceMonitor

### Verifying Your Setup

Check if Helm is installed:
```bash
helm version
```

Check if kubectl is configured:
```bash
kubectl cluster-info
```

Check available StorageClasses:
```bash
kubectl get storageclass
```

## Quick Start

The fastest way to get started with the AxonOps Search DB:

```bash
# Add the AxonOps Helm repository (if available)
# helm repo add axonops https://axonops.github.io/helm-charts
# helm repo update

# Install with default settings (single-node mode)
helm install axondb-search ./axondb-search

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axondb-search
```

This will deploy a single-node search database with:
- 8Gi persistent storage
- Default resource limits (4GB memory, 1 CPU)
- Single-node discovery mode
- HTTPS enabled by default
- Basic security configuration

## Installation Examples

### Basic Installation

Install with minimal configuration suitable for development/testing:

```bash
helm install axondb-search ./axondb-search \
  --set replicas=1 \
  --set singleNode=true
```

Or create a `values-basic.yaml` file:

```yaml
# values-basic.yaml
# Single-node configuration for development

replicas: 1
singleNode: true

# Increase heap size for better performance
opensearchHeapSize: "2g"

# Resource limits
resources:
  requests:
    cpu: 1000m
    memory: 4Gi
  limits:
    cpu: 2000m
    memory: 4Gi

# Persistent storage
persistence:
  enabled: true
  size: 10Gi
```

Install using the values file:

```bash
helm install axondb-search ./axondb-search -f values-basic.yaml
```

### Installation with Custom Storage

Configure persistent storage with a specific StorageClass and size:

```yaml
# values-storage.yaml
replicas: 1
singleNode: true

# Heap size (should be ~50% of container memory)
opensearchHeapSize: "4g"

persistence:
  enabled: true
  # Use your cluster's StorageClass (e.g., gp3, standard, fast-ssd)
  # storageClass: "gp3"
  size: 50Gi
  accessModes:
    - ReadWriteOnce
  # Optional: Add annotations for the PVC
  annotations: {}
  # Optional: Enable volume labels
  labels:
    enabled: true
    additionalLabels:
      app: axondb-search
      environment: production

resources:
  requests:
    cpu: 2000m
    memory: 8Gi
  limits:
    cpu: 4000m
    memory: 8Gi
```

Install:

```bash
helm install axondb-search ./axondb-search -f values-storage.yaml
```

### Installation with Authentication

Secure your search database with authentication credentials:

**Option 1: Using Direct Values (Development Only)**

```yaml
# values-auth.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

authentication:
  opensearch_user: "axonops"
  opensearch_password: "your-secure-password"
```

**Option 2: Using Kubernetes Secrets (Recommended for Production)**

First, create a Kubernetes secret:

```bash
kubectl create secret generic -n axonops axondb-search-credentials \
  --from-literal=AXONOPS_SEARCH_USER=axonops \
  --from-literal=AXONOPS_SEARCH_PASSWORD=secure-password
```

Then create your values file:

```yaml
# values-auth-secret.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

authentication:
  opensearch_secret: "axondb-search-credentials"
```

Install:

```bash
helm install axondb-search ./axondb-search -f values-auth-secret.yaml
```

### Installation with TLS (Manual Certificates)

Use existing TLS certificates for encrypted communication:

**Step 1: Create a secret with your certificates**

```bash
kubectl create secret generic axondb-search-tls-manual \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key \
  --from-file=ca.crt=path/to/ca.crt
```

**Step 2: Create your values file**

```yaml
# values-tls-manual.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

# Enable HTTPS protocol
protocol: https

tls:
  enabled: true
  manual:
    existingSecret: "axondb-search-tls-manual"

# Security configuration
securityConfig:
  enabled: true
```

Install:

```bash
helm install axondb-search ./axondb-search -f values-tls-manual.yaml
```

### Installation with TLS (cert-manager)

Automatically generate and manage TLS certificates using cert-manager:

**Prerequisites:**
- cert-manager must be installed in your cluster

**Step 1: Install cert-manager (if not already installed)**

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

Wait for cert-manager to be ready:

```bash
kubectl wait --for=condition=Available --timeout=300s \
  deployment/cert-manager -n cert-manager
```

**Step 2: Create your values file**

**Using Self-Signed Certificates (Development/Testing):**

```yaml
# values-tls-certmanager-selfsigned.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

# Enable HTTPS protocol
protocol: https

tls:
  enabled: true
  certManager:
    enabled: true
    # Keystore password (change this!)
    keystorePassword: "my-secure-keystore-password"

    issuer:
      # Automatically create a self-signed issuer
      createSelfSigned: true
      kind: "ClusterIssuer"

    certificate:
      # Certificate will be valid for 5 years
      duration: 43800h
      # Renew 30 days before expiry
      renewBefore: 720h
      secretName: "axondb-search-tls-cert"

# Security configuration
securityConfig:
  enabled: true
```

**Using an Existing Issuer (Production):**

```yaml
# values-tls-certmanager-production.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

# Enable HTTPS protocol
protocol: https

tls:
  enabled: true
  certManager:
    enabled: true
    keystorePassword: "my-secure-keystore-password"

    issuer:
      # Use your existing ClusterIssuer
      name: "letsencrypt-prod"
      kind: "ClusterIssuer"
      createSelfSigned: false

    certificate:
      # Custom DNS names for the certificate
      commonName: "axondb-search.example.com"
      dnsNames:
        - "axondb-search.example.com"
        - "*.axondb-search.example.com"
      duration: 2160h  # 90 days
      renewBefore: 360h  # 15 days
      secretName: "axondb-search-tls-cert"

securityConfig:
  enabled: true
```

Install:

```bash
# For self-signed certificates
helm install axondb-search ./axondb-search -f values-tls-certmanager-selfsigned.yaml

# OR for production with existing issuer
helm install axondb-search ./axondb-search -f values-tls-certmanager-production.yaml
```

**Verify certificate creation:**

```bash
kubectl get certificate
kubectl describe certificate axondb-search-tls
```

### Multi-Node Cluster Installation

Deploy a multi-node cluster for high availability and better performance:

```yaml
# values-cluster.yaml
# Multi-node cluster configuration

# Disable single-node mode for clustering
singleNode: false

# Deploy 3 nodes for high availability
replicas: 3

clusterName: "axondb-search-cluster"

# Node roles (master, data, ingest)
roles:
  - master
  - ingest
  - data
  - remote_cluster_client

# Heap size per node
opensearchHeapSize: "4g"

# Resource allocation per node
resources:
  requests:
    cpu: 2000m
    memory: 8Gi
  limits:
    cpu: 4000m
    memory: 8Gi

# Persistent storage per node
persistence:
  enabled: true
  size: 50Gi
  accessModes:
    - ReadWriteOnce

# Anti-affinity to spread pods across nodes
antiAffinity: "hard"
antiAffinityTopologyKey: "kubernetes.io/hostname"

# Pod management policy
podManagementPolicy: "Parallel"

# Security configuration
securityConfig:
  enabled: true

# Node certificate DNs for inter-node security (multi-node clusters)
# Configures which certificate Distinguished Names can join the cluster
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.default.svc.cluster.local;CN=axondb-search-cluster-master-0;CN=axondb-search-cluster-master-1;CN=axondb-search-cluster-master-2"

# Service configuration
service:
  type: ClusterIP
  httpPortName: http
  transportPortName: transport
```

Install:

```bash
helm install axondb-search ./axondb-search -f values-cluster.yaml
```

### Production-Ready Installation

A complete production configuration with all recommended settings:

```yaml
# values-production.yaml
# Production configuration for AxonOps Search DB

# Multi-node cluster for high availability
singleNode: false
replicas: 3

clusterName: "axondb-search-production"

# Node roles
roles:
  - master
  - ingest
  - data
  - remote_cluster_client

# Heap size (50% of container memory)
opensearchHeapSize: "8g"

# Authentication using Kubernetes secrets
authentication:
  opensearch_secret: "axondb-search-credentials"

# Resource limits for production workloads
resources:
  requests:
    cpu: 2000m
    memory: 16Gi
  limits:
    cpu: 4000m
    memory: 16Gi

# Persistent storage configuration
persistence:
  enabled: true
  size: 100Gi
  accessModes:
    - ReadWriteOnce
  # storageClass: "gp3"  # Uncomment and set your StorageClass
  labels:
    enabled: true
    additionalLabels:
      environment: production

# TLS encryption with cert-manager
protocol: https
tls:
  enabled: true
  certManager:
    enabled: true
    keystorePassword: "change-this-secure-password"
    issuer:
      name: "letsencrypt-prod"
      kind: "ClusterIssuer"
      createSelfSigned: false
    certificate:
      commonName: "axondb-search.prod.example.com"
      dnsNames:
        - "axondb-search.prod.example.com"
        - "*.axondb-search.prod.example.com"
      duration: 2160h
      renewBefore: 360h

# Security configuration
securityConfig:
  enabled: true

# Node certificate DNs for inter-node security
# IMPORTANT: Configure this for multi-node clusters to control which nodes can join
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.prod.example.com;CN=axondb-search-production-0;CN=axondb-search-production-1;CN=axondb-search-production-2"

# Health check probes
startupProbe:
  tcpSocket:
    port: 9200
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 30

readinessProbe:
  tcpSocket:
    port: 9200
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# Pod security context
podSecurityContext:
  fsGroup: 999
  runAsUser: 999

securityContext:
  capabilities:
    drop:
      - ALL
  runAsNonRoot: true
  runAsUser: 999

# Service configuration
service:
  type: ClusterIP
  annotations: {}
  labels:
    environment: production

# Anti-affinity rules to spread pods across nodes
antiAffinity: "hard"
antiAffinityTopologyKey: "kubernetes.io/hostname"

# Pod management policy (Parallel for faster startup)
podManagementPolicy: "Parallel"

# System settings
sysctlVmMaxMapCount: 262144
sysctlInit:
  enabled: false  # Set to true if not configured at OS level

# Graceful shutdown period
terminationGracePeriod: 120

# Enable Prometheus monitoring (requires prometheus-exporter plugin)
serviceMonitor:
  enabled: false  # Enable after installing prometheus-exporter plugin
  interval: 30s
  path: /_prometheus/metrics
  scheme: https
  labels:
    prometheus: kube-prometheus

# Network policy (optional)
networkPolicy:
  create: false

# Tolerations for dedicated nodes (optional)
# tolerations:
#   - key: "workload"
#     operator: "Equal"
#     value: "search"
#     effect: "NoSchedule"

# Node selector for dedicated nodes (optional)
# nodeSelector:
#   workload: search
```

**Before installing, create the authentication secret:**

```bash
kubectl create secret generic axondb-search-credentials \
  --from-literal=OPENSEARCH_USER=axonops \
  --from-literal=OPENSEARCH_PASSWORD=$(openssl rand -base64 32)
```

**Install the production deployment:**

```bash
helm install axondb-search ./axondb-search \
  -f values-production.yaml \
  --namespace axonops \
  --create-namespace
```

**Verify the cluster is healthy:**

```bash
# Check all pods are running
kubectl get pods -l app.kubernetes.io/name=axondb-search -n axonops

# Check cluster health (port-forward to access)
kubectl port-forward svc/axondb-search-cluster-master 9200:9200 -n axonops

# In another terminal (if using default credentials)
curl -k -u admin:ChangeThisSecurePassword123! https://localhost:9200/_cluster/health
```

## Backup Configuration

The axondb-search chart includes built-in backup functionality using OpenSearch snapshots. Backups can be stored locally or in S3-compatible storage.

### Local Backups

Configure local filesystem backups with a dedicated PVC:

```yaml
# values-backup-local.yaml
backups:
  enabled: true
  schedule: "0 8 * * *"  # Daily at 8am UTC

  # Snapshot retention
  retention:
    days: 30
    count: ""  # Optional: max number of snapshots

  # Local backup target
  target:
    type: local
    local:
      path: "/mnt/backups"
      size: "50Gi"
      storageClass: ""  # Uses default storage class
```

Install:

```bash
helm install axondb-search ./axondb-search -f values-backup-local.yaml
```

### S3 Backups

Configure backups to AWS S3 or S3-compatible storage (MinIO, Ceph, etc.):

#### Using AWS S3

```yaml
# values-backup-s3.yaml
backups:
  enabled: true
  schedule: "0 */6 * * *"  # Every 6 hours

  retention:
    days: 30

  target:
    type: s3
    s3:
      bucket: "my-opensearch-backups"
      region: "us-east-1"
      basePath: "axondb-search"

      # Method 1: Use existing Kubernetes secret (recommended)
      credentials:
        existingSecret: "aws-backup-credentials"
        # Secret must contain keys: aws-access-key-id, aws-secret-access-key

      # Method 2: Inline credentials (NOT recommended for production)
      # credentials:
      #   accessKeyId: "AKIAIOSFODNN7EXAMPLE"
      #   secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

Create the credentials secret:

```bash
kubectl create secret generic aws-backup-credentials \
  --from-literal=aws-access-key-id=AKIAIOSFODNN7EXAMPLE \
  --from-literal=aws-secret-access-key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

#### Using S3-Compatible Storage (MinIO)

```yaml
# values-backup-minio.yaml
backups:
  enabled: true
  schedule: "0 */4 * * *"

  target:
    type: s3
    s3:
      bucket: "opensearch-backups"
      endpoint: "http://minio.minio.svc.cluster.local:9000"
      pathStyleAccess: true  # Required for MinIO

      credentials:
        existingSecret: "minio-credentials"
```

#### Using AWS IAM Roles (EKS with IRSA)

For EKS clusters with IAM Roles for Service Accounts:

```yaml
# values-backup-irsa.yaml
backups:
  enabled: true
  target:
    type: s3
    s3:
      bucket: "my-opensearch-backups"
      region: "us-east-1"
      # Leave credentials empty for IRSA

rbac:
  create: true
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/opensearch-backup-role
```

## External Secret Management (vals-operator)

The chart supports [vals-operator](https://github.com/digitalis-io/vals-operator) for fetching secrets from external stores like AWS Secrets Manager, HashiCorp Vault, Google Secret Manager, and Azure Key Vault.

### vals-operator Setup

Install vals-operator in your cluster:

```bash
helm repo add digitalis https://digitalis-io.github.io/helm-charts
helm install vals-operator digitalis/vals-operator
```

### vals-operator Configuration

```yaml
# values-vals.yaml
vals:
  enabled: true
  ttl: 3600  # Refresh interval in seconds

  # OpenSearch authentication from external secret store
  authentication:
    # AWS Secrets Manager example
    opensearch_user: "ref+awssecrets://axonops/search#username"
    opensearch_password: "ref+awssecrets://axonops/search#password"

    # HashiCorp Vault example
    # opensearch_user: "ref+vault://secret/data/axonops/search#username"
    # opensearch_password: "ref+vault://secret/data/axonops/search#password"

  # TLS keystore password (if using TLS)
  tls:
    keystorePassword: "ref+awssecrets://axonops/tls#keystore-password"

  # S3 backup credentials
  s3Credentials:
    accessKeyId: "ref+awssecrets://axonops/s3#access-key-id"
    secretAccessKey: "ref+awssecrets://axonops/s3#secret-access-key"

  # ServiceMonitor basic auth (if using Prometheus)
  serviceMonitor:
    username: "ref+awssecrets://axonops/monitoring#username"
    password: "ref+awssecrets://axonops/monitoring#password"
```

Install:

```bash
helm install axondb-search ./axondb-search -f values-vals.yaml
```

When vals-operator is enabled, a `ValsSecret` resource is created which vals-operator reconciles into a standard Kubernetes Secret. This allows seamless integration with external secret stores.

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicas` | Number of search database replicas | `1` |
| `singleNode` | Enable single-node mode (disables clustering) | `true` |
| `opensearchHeapSize` | JVM heap size | `2g` |
| `image.repository` | Container image repository | `ghcr.io/axonops/axondb-search` |
| `image.tag` | Container image tag | `""` (uses appVersion) |
| `authentication.opensearch_user` | Username (dev only) | `""` |
| `authentication.opensearch_password` | Password (dev only) | `""` |
| `authentication.opensearch_secret` | Kubernetes secret name for credentials | `""` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | Size of data volume | `8Gi` |
| `protocol` | HTTP protocol (http or https) | `https` |
| `tls.enabled` | Enable TLS/SSL encryption | `false` |
| `tls.certManager.enabled` | Use cert-manager for certificates | `false` |
| `resources.requests.memory` | Memory request | `4096Mi` |
| `resources.requests.cpu` | CPU request | `1000m` |

### Important Notes

**Heap Size Configuration:**
- The heap size should be approximately 50% of the container's memory
- Example: If `resources.limits.memory: 8Gi`, set `opensearchHeapSize: "4g"`
- Never set heap size larger than 32GB (compressed OOP limit)

**Single-Node vs Cluster Mode:**
- `singleNode: true` - Use for development/testing, automatically sets `replicas: 1`
- `singleNode: false` - Use for production, allows multiple replicas for high availability

**Security:**
- Always use Kubernetes secrets for credentials in production
- Enable TLS for production deployments

**Multi-Node Security (Node Certificate DNs):**

For multi-node clusters, configure which certificate Distinguished Names (DNs) are allowed to join the cluster using the `OPENSEARCH_SECURITY_NODES_DN` environment variable. This is critical for securing transport layer communication between nodes.

Configure via `extraEnvs`:
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.example.svc.cluster.local;CN=node-1;CN=node-2"
```

**Key points:**
- Use semicolons (`;`) to separate multiple DNs
- Supports wildcards (e.g., `CN=*.svc.cluster.local`) for dynamic pod names in Kubernetes
- Only nodes with certificates matching these DNs can join the cluster
- Essential for preventing unauthorized nodes from joining your cluster
- Default value: `CN=*.axonops.svc.cluster.local`

**Example for Kubernetes with wildcard DNS:**
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.default.svc.cluster.local"
```

**Example with explicit node names:**
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=axondb-search-0;CN=axondb-search-1;CN=axondb-search-2"
```

### Complete Values Reference

<details>
<summary>Click to expand full values table</summary>

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| antiAffinity | string | `"soft"` | Anti-affinity setting (soft, hard, or custom) |
| antiAffinityTopologyKey | string | `"kubernetes.io/hostname"` | Topology key for anti-affinity |
| authentication.opensearch_password | string | `""` | Database password (plain text - dev only) |
| authentication.opensearch_secret | string | `""` | Kubernetes secret name containing credentials |
| authentication.opensearch_user | string | `""` | Database username (plain text - dev only) |
| clusterName | string | `"axondb-search-cluster"` | Name of the search cluster |
| config.opensearch.yml | string | `"cluster.name: opensearch-cluster\n\nnetwork.host: 0.0.0.0\n"` | Configuration file content |
| enableServiceLinks | bool | `true` | Enable service links injection |
| envFrom | list | `[]` | Load environment variables from secrets/configmaps |
| extraContainers | list | `[]` | Additional sidecar containers |
| extraEnvs | list | `[]` | Additional environment variables (use for OPENSEARCH_SECURITY_NODES_DN in multi-node clusters) |
| extraInitContainers | list | `[]` | Additional init containers |
| extraVolumeMounts | list | `[]` | Additional volume mounts |
| extraVolumes | list | `[]` | Additional volumes |
| fullnameOverride | string | `""` | Override the full resource name |
| httpPort | int | `9200` | HTTP port for the service |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"ghcr.io/axonops/axondb-search"` | Container image repository |
| image.tag | string | `""` | Image tag (defaults to chart appVersion) |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| ingress.enabled | bool | `false` | Enable ingress |
| ingress.annotations | object | `{}` | Ingress annotations |
| ingress.hosts | list | `["chart-example.local"]` | Ingress hostnames |
| labels | object | `{}` | Additional labels for resources |
| lifecycle | object | `{}` | Lifecycle hooks for containers |
| livenessProbe | object | `{}` | Liveness probe configuration |
| majorVersion | string | `"3"` | Major version of the search engine |
| masterService | string | `"axondb-search-cluster-master"` | Master service name for clustering |
| maxUnavailable | int | `1` | Max unavailable pods during updates |
| metricsPort | int | `9600` | Metrics port |
| nameOverride | string | `""` | Override the chart name |
| networkHost | string | `"0.0.0.0"` | Network host binding |
| networkPolicy.create | bool | `false` | Create network policy |
| nodeSelector | object | `{}` | Node labels for pod assignment |
| opensearchHeapSize | string | `"2g"` | JVM heap size |
| opensearchJavaOps | string | `""` | Additional Java options |
| persistence.enabled | bool | `true` | Enable persistent storage |
| persistence.size | string | `"8Gi"` | Size of data volume |
| persistence.accessModes | list | `["ReadWriteOnce"]` | Access modes for PVC |
| persistence.annotations | object | `{}` | Annotations for PVC |
| persistence.existingClaim | string | `""` | Use existing PVC |
| plugins.enabled | bool | `false` | Enable plugin management |
| plugins.installList | list | `[]` | List of plugins to install |
| podAnnotations | object | `{}` | Annotations for pods |
| podManagementPolicy | string | `"Parallel"` | Pod management policy |
| podSecurityContext.fsGroup | int | `999` | FSGroup for pod security context |
| podSecurityContext.runAsUser | int | `999` | User ID to run pods |
| protocol | string | `"https"` | HTTP protocol (http or https) |
| rbac.create | bool | `false` | Create RBAC resources |
| readinessProbe.failureThreshold | int | `3` | Failure threshold for readiness probe |
| readinessProbe.periodSeconds | int | `5` | How often to perform the probe |
| readinessProbe.timeoutSeconds | int | `3` | Timeout for readiness probe |
| replicas | int | `1` | Number of replicas |
| resources.requests.cpu | string | `"1000m"` | CPU request |
| resources.requests.memory | string | `"4096Mi"` | Memory request |
| roles | list | `["master","ingest","data","remote_cluster_client"]` | Node roles |
| securityConfig.enabled | bool | `true` | Enable security configuration |
| securityContext.capabilities.drop | list | `["ALL"]` | Drop all capabilities |
| securityContext.runAsNonRoot | bool | `true` | Run as non-root user |
| securityContext.runAsUser | int | `999` | User ID to run container |
| service.type | string | `"ClusterIP"` | Kubernetes service type |
| service.httpPortName | string | `"http"` | HTTP port name |
| service.transportPortName | string | `"transport"` | Transport port name |
| serviceMonitor.enabled | bool | `false` | Enable Prometheus ServiceMonitor |
| serviceMonitor.interval | string | `"10s"` | Scrape interval |
| serviceMonitor.path | string | `"/_prometheus/metrics"` | Metrics path |
| singleNode | bool | `true` | Enable single-node mode |
| startupProbe.failureThreshold | int | `30` | Failure threshold for startup probe |
| startupProbe.initialDelaySeconds | int | `5` | Initial delay before startup probe |
| startupProbe.periodSeconds | int | `10` | How often to perform the probe |
| sysctlVmMaxMapCount | int | `262144` | VM max map count setting |
| terminationGracePeriod | int | `120` | Graceful shutdown timeout |
| tls.enabled | bool | `false` | Enable TLS/SSL |
| tls.certManager.enabled | bool | `false` | Enable cert-manager for TLS |
| tls.certManager.keystorePassword | string | `"changeme"` | Keystore password |
| tls.certManager.issuer.createSelfSigned | bool | `true` | Create self-signed issuer |
| tls.certManager.issuer.kind | string | `"ClusterIssuer"` | Issuer kind |
| tls.certManager.certificate.duration | string | `"43800h"` | Certificate duration |
| tls.manual.existingSecret | string | `""` | Existing secret with manual certificates |
| tolerations | list | `[]` | Tolerations for pod assignment |
| transportPort | int | `9300` | Transport port for node communication |
| updateStrategy | string | `"RollingUpdate"` | Update strategy |

</details>

## Upgrading

To upgrade an existing installation:

```bash
# Update the chart
helm upgrade axondb-search ./axondb-search -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axondb-search-cluster-master
```

**Important:** For multi-node clusters, upgrades are performed using a rolling update strategy. Ensure you have sufficient capacity to handle traffic during the upgrade.

## Uninstalling

To remove the AxonOps Search DB:

```bash
# Uninstall the release
helm uninstall axondb-search

# Optional: Delete PVCs (this will delete all data!)
kubectl delete pvc -l app.kubernetes.io/name=axondb-search
```

**Warning:** Deleting PVCs will permanently delete all indexed data. Make sure you have backups or snapshots before proceeding.

## Troubleshooting

### Common Issues

**1. Pods not starting (CrashLoopBackOff)**

Check pod logs:
```bash
kubectl logs axondb-search-cluster-master-0
```

Common causes:
- Insufficient memory (increase `opensearchHeapSize` and `resources.limits.memory`)
- Storage provisioning issues (check PVC status with `kubectl get pvc`)
- VM max map count not set (enable `sysctlInit.enabled: true`)

**2. "vm.max_map_count is too low" error**

The search engine requires `vm.max_map_count` to be at least 262144. You have two options:

**Option A: Enable sysctlInit in Helm chart (requires privileged containers):**
```yaml
sysctlInit:
  enabled: true
```

**Option B: Set at the node level (recommended):**
```bash
# On each Kubernetes node
sudo sysctl -w vm.max_map_count=262144

# Make it persistent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

**3. Storage issues**

Check PVC status:
```bash
kubectl get pvc
kubectl describe pvc axondb-search-cluster-master-axondb-search-cluster-master-0
```

If PVC is pending:
- Verify StorageClass exists: `kubectl get storageclass`
- Check if dynamic provisioning is enabled in your cluster
- Ensure you have sufficient storage quota

**4. Certificate issues (cert-manager)**

Check certificate status:
```bash
kubectl get certificate
kubectl describe certificate axondb-search-tls
kubectl get certificaterequest
```

Check cert-manager logs:
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

**5. Cluster not forming (multi-node)**

If nodes can't discover each other:

```bash
# Check all pods are running
kubectl get pods -l app.kubernetes.io/name=axondb-search

# Check service endpoints
kubectl get endpoints axondb-search-cluster-master-headless

# Check logs for discovery issues
kubectl logs axondb-search-cluster-master-0 | grep -i discovery
```

Verify:
- `singleNode: false` is set
- `masterService` points to the correct service name
- Pods can communicate on port 9300 (transport)

**6. Connection refused errors**

Verify the service:
```bash
kubectl get svc
kubectl describe svc axondb-search-cluster-master
```

Test connectivity:
```bash
# Port-forward to access locally
kubectl port-forward svc/axondb-search-cluster-master 9200:9200

# Test the connection
curl -k https://localhost:9200
```

**7. High memory usage or OOM kills**

Check actual memory usage:
```bash
kubectl top pod -l app.kubernetes.io/name=axondb-search
```

Adjust heap size and memory limits:
```yaml
opensearchHeapSize: "4g"
resources:
  limits:
    memory: 8Gi  # Should be at least 2x heap size
```

**Important heap size rules:**
- Set heap to ~50% of container memory
- Never exceed 31-32GB (compressed OOP limit)
- Ensure `requests.memory` and `limits.memory` are the same to avoid OOM

**8. Performance issues**

For better performance:

1. Enable separate commitlog volume (if supported by your configuration)
2. Use SSD-backed storage classes
3. Increase replica count for better query distribution
4. Monitor JVM metrics and adjust heap size accordingly

### Getting Help

For additional support:
- Check the logs: `kubectl logs -f axondb-search-cluster-master-0`
- View events: `kubectl get events --sort-by='.lastTimestamp'`
- Describe the StatefulSet: `kubectl describe statefulset axondb-search-cluster-master`
- Check cluster health via API (after port-forwarding):
  ```bash
  curl -k -u admin:password https://localhost:9200/_cluster/health?pretty
  ```
- Visit AxonOps documentation: <https://docs.axonops.com>
- Contact AxonOps support: <info@axonops.com>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| AxonOps Team | <info@aoxnops.com> |  |

---

*Generated with AxonOps Helm Charts*
