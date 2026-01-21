# AxonOps Timeseries Database

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 5.0.5-1.0.0](https://img.shields.io/badge/AppVersion-5.0.5--1.0.0-informational?style=flat-square)

A Helm chart for deploying the AxonOps timeseries database (Cassandra-based) on Kubernetes. This database stores metrics and monitoring data for the AxonOps platform.

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
  - [Production-Ready Installation](#production-ready-installation)
- [Backup Configuration](#backup-configuration)
  - [Local Backups](#local-backups)
  - [Remote Backups (S3)](#remote-backups-s3)
  - [Restoring from Backup](#restoring-from-backup)
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
- **Resources**: At least 2GB of available memory and 2 CPU cores recommended

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

The fastest way to get started with the AxonOps timeseries database:

```bash
# Add the AxonOps Helm repository (if available)
# helm repo add axonops https://axonops.github.io/helm-charts
# helm repo update

# Install with default settings
helm install axondb-timeseries ./axondb-timeseries

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axondb-timeseries
```

This will deploy a single-node timeseries database with:
- 10Gi persistent storage
- Default resource limits
- No authentication (development only)
- No TLS encryption

## Installation Examples

### Basic Installation

Install with minimal configuration suitable for development/testing:

```bash
helm install axondb-timeseries ./axondb-timeseries \
  --set replicaCount=1
```

Or create a `values-basic.yaml` file:

```yaml
# values-basic.yaml
replicaCount: 1

# Optional: Increase heap size for better performance
heapSize: 2048M

# Optional: Set resource limits
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

Install using the values file:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-basic.yaml
```

### Installation with Custom Storage

Configure persistent storage with a specific StorageClass and size:

```yaml
# values-storage.yaml
replicaCount: 1

persistence:
  enabled: true
  data:
    # Use your cluster's StorageClass (e.g., gp3, standard, fast-ssd)
    storageClass: "gp3"
    size: 50Gi
    accessMode: ReadWriteOnce

  # Optional: Separate commitlog volume for better I/O performance
  commitlog:
    enabled: true
    storageClass: "fast-ssd"  # Use SSD for commitlog
    size: 10Gi
    accessMode: ReadWriteOnce
```

Install:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-storage.yaml
```

### Installation with Authentication

Secure your database with authentication credentials:

**Option 1: Using Direct Values (Development Only)**

```yaml
# values-auth.yaml
replicaCount: 1

authentication:
  db_user: "axonops"
  db_password: "your-secure-password"
```

**Option 2: Using Kubernetes Secrets (Recommended for Production)**

First, create a Kubernetes secret:

```bash
kubectl create secret generic axondb-credentials \
  --from-literal=AXONOPS_DB_USER=axonops \
  --from-literal=AXONOPS_DB_PASSWORD=your-secure-password
```

Then create your values file:

```yaml
# values-auth-secret.yaml
replicaCount: 1

authentication:
  db_secret: "axondb-credentials"
```

Install:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-auth-secret.yaml
```

### Installation with TLS (Manual Certificates)

Use existing TLS certificates for encrypted communication:

**Step 1: Create a secret with your certificates**

```bash
kubectl create secret generic axondb-tls-manual \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key \
  --from-file=ca.crt=path/to/ca.crt \
  --from-file=keystore.jks=path/to/keystore.jks \
  --from-file=truststore.jks=path/to/truststore.jks \
  --from-literal=keystore-password=your-keystore-password \
  --from-literal=truststore-password=your-truststore-password
```

**Step 2: Create your values file**

```yaml
# values-tls-manual.yaml
replicaCount: 1

tls:
  enabled: true
  manual:
    existingSecret: "axondb-tls-manual"

  cassandra:
    # Configure internode (node-to-node) encryption
    internode:
      encryption: "all"          # Options: none, dc, rack, all
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"
```

Install:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-tls-manual.yaml
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
replicaCount: 1

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
      secretName: "axondb-timeseries-tls-cert"

  cassandra:
    internode:
      encryption: "all"
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"
```

**Using an Existing Issuer (Production):**

```yaml
# values-tls-certmanager-production.yaml
replicaCount: 1

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
      commonName: "axondb.example.com"
      dnsNames:
        - "axondb.example.com"
        - "*.axondb.example.com"
      duration: 2160h  # 90 days
      renewBefore: 360h  # 15 days
      secretName: "axondb-timeseries-tls-cert"

  cassandra:
    internode:
      encryption: "all"
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"
```

Install:

```bash
# For self-signed certificates
helm install axondb-timeseries ./axondb-timeseries -f values-tls-certmanager-selfsigned.yaml

# OR for production with existing issuer
helm install axondb-timeseries ./axondb-timeseries -f values-tls-certmanager-production.yaml
```

**Verify certificate creation:**

```bash
kubectl get certificate
kubectl describe certificate axondb-timeseries-tls
```

### Production-Ready Installation

A complete production configuration with all recommended settings:

```yaml
# values-production.yaml
# Production configuration for AxonOps Timeseries Database

# Run at least 3 nodes for high availability
replicaCount: 3

image:
  repository: ghcr.io/axonops/axondb-timeseries
  pullPolicy: IfNotPresent
  tag: ""  # Uses chart appVersion

# Increase heap size for production workloads
heapSize: 8192M

# Authentication using Kubernetes secrets
authentication:
  db_secret: "axondb-credentials"

# Resource limits for production
resources:
  requests:
    cpu: 2000m
    memory: 10Gi
  limits:
    cpu: 4000m
    memory: 16Gi

# Persistent storage configuration
persistence:
  enabled: true
  data:
    storageClass: "gp3"
    size: 100Gi
    accessMode: ReadWriteOnce
  commitlog:
    enabled: true
    storageClass: "fast-ssd"
    size: 20Gi
    accessMode: ReadWriteOnce

# TLS encryption with cert-manager
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
      commonName: "axondb.prod.example.com"
      dnsNames:
        - "axondb.prod.example.com"
        - "*.axondb.prod.example.com"
      duration: 2160h
      renewBefore: 360h
  cassandra:
    internode:
      encryption: "all"
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"

# Health check probes
livenessProbe:
  enabled: true
  initialDelaySeconds: 90
  periodSeconds: 30
  timeoutSeconds: 30
  failureThreshold: 5

readinessProbe:
  enabled: true
  initialDelaySeconds: 90
  periodSeconds: 10
  timeoutSeconds: 30
  failureThreshold: 5

# Pod security context
podSecurityContext:
  fsGroup: 999

securityContext:
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 999

# Service configuration
service:
  type: ClusterIP
  port: 9042

# Enable Prometheus monitoring
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
  labels:
    prometheus: kube-prometheus

# Pod placement rules
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
                - axondb-timeseries
        topologyKey: kubernetes.io/hostname

# Tolerations for dedicated nodes (optional)
# tolerations:
#   - key: "workload"
#     operator: "Equal"
#     value: "database"
#     effect: "NoSchedule"

# Node selector for dedicated nodes (optional)
# nodeSelector:
#   workload: database
```

**Before installing, create the authentication secret:**

```bash
kubectl create secret generic axondb-credentials \
  --from-literal=AXONOPS_DB_USER=axonops \
  --from-literal=AXONOPS_DB_PASSWORD=$(openssl rand -base64 32)
```

**Install the production deployment:**

```bash
helm install axondb-timeseries ./axondb-timeseries \
  -f values-production.yaml \
  --namespace axonops \
  --create-namespace
```

## Backup Configuration

The axondb-timeseries chart includes comprehensive backup functionality using Cassandra snapshots with rsync-based deduplication. Backups can be stored locally or synced to remote S3-compatible storage.

**Note:** AxonDB Timeseries is designed for single-node deployments only. Multi-node clusters are not supported for backup operations.

### Local Backups

Configure local snapshot-based backups with hardlink deduplication:

```yaml
# values-backup-local.yaml
backups:
  enabled: true

  # Backup volume configuration
  volume:
    size: "50Gi"
    storageClass: ""  # Uses default storage class
    mountPath: /backup

  # Backup schedule (cron format)
  schedule:
    cronSchedule: "0 */4 * * *"  # Every 4 hours
    successfulJobsHistoryLimit: 3
    failedJobsHistoryLimit: 3

  # Backup settings
  settings:
    tagPrefix: "backup"
    retentionHours: 168  # 7 days
    minimumRetentionCount: 3  # Always keep at least 3 backups
    useHardlinks: true  # Enable deduplication
```

Install:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-backup-local.yaml
```

### Remote Backups (S3)

Configure backups to sync to AWS S3 or S3-compatible storage using rclone:

```yaml
# values-backup-remote.yaml
backups:
  enabled: true

  volume:
    size: "50Gi"

  schedule:
    cronSchedule: "0 */4 * * *"

  settings:
    retentionHours: 168
    useHardlinks: true

  # Remote sync configuration
  remote:
    enabled: true
    syncIntervalSeconds: 3600  # Sync to remote every hour
    initialDelaySeconds: 300   # Wait 5 minutes before first sync

    # Remote storage path (rclone format)
    name: "s3"  # rclone remote name
    path: "my-bucket/cassandra-backups"

    # Retention in remote storage
    retentionDays: "30"

    # Authentication via Kubernetes secret
    authMethod: "env"
    secretName: "backup-s3-credentials"

    # Resource limits for rclone sidecar
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

Create the S3 credentials secret:

```bash
kubectl create secret generic backup-s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE \
  --from-literal=AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  --from-literal=AWS_DEFAULT_REGION=us-east-1
```

For S3-compatible storage (MinIO, Ceph), add endpoint configuration:

```bash
kubectl create secret generic backup-s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=minioadmin \
  --from-literal=AWS_SECRET_ACCESS_KEY=minioadmin \
  --from-literal=AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000
```

### Restoring from Backup

To restore from a remote backup on pod initialization:

```yaml
# values-restore.yaml
# Restore from the latest backup
restoreFromBackup: "latest"

# Or restore from a specific backup
# restoreFromBackup: "backup-20260114-102241"

backups:
  enabled: true
  remote:
    enabled: true
    name: "s3"
    path: "my-bucket/cassandra-backups"
    secretName: "backup-s3-credentials"
```

Install with restore:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-restore.yaml
```

**Important:** The restore process will download the specified backup from remote storage and restore it before Cassandra starts.

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

  # Database authentication from external secret store
  authentication:
    # AWS Secrets Manager example
    db_user: "ref+awssecrets://axonops/timeseries#username"
    db_password: "ref+awssecrets://axonops/timeseries#password"

    # HashiCorp Vault example
    # db_user: "ref+vault://secret/data/axonops/timeseries#username"
    # db_password: "ref+vault://secret/data/axonops/timeseries#password"

  # TLS keystore password (if using TLS)
  tls:
    keystorePassword: "ref+awssecrets://axonops/tls#keystore-password"

  # Remote backup credentials
  backup:
    awsAccessKeyId: "ref+awssecrets://axonops/backup#access-key-id"
    awsSecretAccessKey: "ref+awssecrets://axonops/backup#secret-access-key"
```

Install:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-vals.yaml
```

When vals-operator is enabled, a `ValsSecret` resource is created which vals-operator reconciles into a standard Kubernetes Secret. This allows seamless integration with external secret stores.

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of database replicas | `1` |
| `heapSize` | JVM heap size for Cassandra | `1024M` |
| `image.repository` | Container image repository | `ghcr.io/axonops/axondb-timeseries` |
| `image.tag` | Container image tag | `""` (uses appVersion) |
| `authentication.db_user` | Database username (dev only) | `""` |
| `authentication.db_password` | Database password (dev only) | `""` |
| `authentication.db_secret` | Kubernetes secret name for credentials | `""` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.data.size` | Size of data volume | `10Gi` |
| `persistence.data.storageClass` | StorageClass for data volume | `""` (default) |
| `persistence.commitlog.enabled` | Enable separate commitlog volume | `false` |
| `tls.enabled` | Enable TLS/SSL encryption | `false` |
| `tls.certManager.enabled` | Use cert-manager for certificates | `false` |
| `resources.requests.memory` | Memory request | `nil` |
| `resources.limits.memory` | Memory limit | `nil` |

### Complete Values Reference

<details>
<summary>Click to expand full values table</summary>

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Pod affinity rules for scheduling |
| authentication.db_password | string | `""` | Database password (plain text - dev only) |
| authentication.db_secret | string | `""` | Kubernetes secret name containing AXONOPS_DB_USER and AXONOPS_DB_PASSWORD |
| authentication.db_user | string | `""` | Database username (plain text - dev only) |
| envVars | list | `[]` | Additional environment variables as a list |
| envVarsSecret | string | `""` | Name of a secret containing environment variables |
| extraVolumeMounts | list | `[]` | Additional volume mounts for the pod |
| extraVolumes | list | `[]` | Additional volumes for the pod |
| fullnameOverride | string | `""` | Override the full resource name |
| heapSize | string | `"1024M"` | JVM heap size (e.g., 1024M, 8G) |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"ghcr.io/axonops/axondb-timeseries"` | Container image repository |
| image.tag | string | `""` | Image tag (defaults to chart appVersion) |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| livenessProbe.enabled | bool | `true` | Enable liveness probe |
| livenessProbe.failureThreshold | int | `5` | Failure threshold for liveness probe |
| livenessProbe.initialDelaySeconds | int | `60` | Initial delay before liveness probe starts |
| livenessProbe.periodSeconds | int | `30` | How often to perform the probe |
| livenessProbe.successThreshold | int | `1` | Success threshold for liveness probe |
| livenessProbe.timeoutSeconds | int | `30` | Timeout for liveness probe |
| nameOverride | string | `""` | Override the chart name |
| nodeSelector | object | `{}` | Node labels for pod assignment |
| persistence.commitlog.accessMode | string | `"ReadWriteOnce"` | Access mode for commitlog volume |
| persistence.commitlog.annotations | object | `{}` | Annotations for commitlog PVC |
| persistence.commitlog.enabled | bool | `false` | Enable separate commitlog volume |
| persistence.commitlog.mountPath | string | `"/var/lib/cassandra/commitlog"` | Mount path for commitlog |
| persistence.commitlog.size | string | `"5Gi"` | Size of commitlog volume |
| persistence.commitlog.storageClass | string | `""` | StorageClass for commitlog |
| persistence.data.accessMode | string | `"ReadWriteOnce"` | Access mode for data volume |
| persistence.data.annotations | object | `{}` | Annotations for data PVC |
| persistence.data.mountPath | string | `"/var/lib/cassandra"` | Mount path for data |
| persistence.data.size | string | `"10Gi"` | Size of data volume |
| persistence.data.storageClass | string | `""` | StorageClass for data volume |
| persistence.enabled | bool | `true` | Enable persistent storage |
| podAnnotations | object | `{}` | Annotations for pods |
| podLabels | object | `{}` | Additional labels for pods |
| podSecurityContext.fsGroup | int | `999` | FSGroup for pod security context |
| readinessProbe.enabled | bool | `true` | Enable readiness probe |
| readinessProbe.failureThreshold | int | `5` | Failure threshold for readiness probe |
| readinessProbe.initialDelaySeconds | int | `60` | Initial delay before readiness probe starts |
| readinessProbe.periodSeconds | int | `10` | How often to perform the probe |
| readinessProbe.successThreshold | int | `1` | Success threshold for readiness probe |
| readinessProbe.timeoutSeconds | int | `30` | Timeout for readiness probe |
| replicaCount | int | `1` | Number of replicas |
| resources | object | `{}` | CPU/Memory resource requests and limits |
| securityContext.readOnlyRootFilesystem | bool | `false` | Mount root filesystem as read-only |
| securityContext.runAsNonRoot | bool | `true` | Run container as non-root user |
| securityContext.runAsUser | int | `999` | User ID to run the container |
| service.port | int | `9042` | CQL service port |
| service.type | string | `"ClusterIP"` | Kubernetes service type |
| serviceAccount.annotations | object | `{}` | Annotations for service account |
| serviceAccount.automount | bool | `true` | Automount service account token |
| serviceAccount.create | bool | `true` | Create service account |
| serviceAccount.name | string | `""` | Service account name |
| serviceMonitor.annotations | object | `{}` | Annotations for ServiceMonitor |
| serviceMonitor.enabled | bool | `false` | Enable Prometheus ServiceMonitor |
| serviceMonitor.interval | string | `"30s"` | Scrape interval |
| serviceMonitor.labels | object | `{}` | Additional labels for ServiceMonitor |
| serviceMonitor.metricRelabelings | list | `[]` | Metric relabeling configuration |
| serviceMonitor.port | string | `"jmx"` | Port to scrape metrics from |
| serviceMonitor.relabelings | list | `[]` | Relabeling configuration |
| serviceMonitor.scrapeTimeout | string | `"10s"` | Scrape timeout |
| serviceMonitor.selector | object | `{}` | Additional selector labels |
| tls.cassandra.internode.acceptedProtocols | string | `"TLSv1.2,TLSv1.3"` | Accepted TLS protocols for internode |
| tls.cassandra.internode.cipherSuites | list | `[]` | Cipher suites for internode encryption |
| tls.cassandra.internode.encryption | string | `"all"` | Internode encryption: none, dc, rack, all |
| tls.cassandra.internode.protocol | string | `"TLS"` | TLS protocol version |
| tls.certManager.certificate.commonName | string | `""` | Certificate common name |
| tls.certManager.certificate.dnsNames | list | `[]` | Certificate DNS SANs |
| tls.certManager.certificate.duration | string | `"43800h"` | Certificate validity duration |
| tls.certManager.certificate.ipAddresses | list | `[]` | Certificate IP SANs |
| tls.certManager.certificate.renewBefore | string | `"720h"` | Renew certificate before expiry |
| tls.certManager.certificate.secretName | string | `"axondb-timeseries-tls-cert"` | Secret name for certificate |
| tls.certManager.enabled | bool | `false` | Enable cert-manager for TLS |
| tls.certManager.issuer.createSelfSigned | bool | `true` | Create self-signed issuer |
| tls.certManager.issuer.kind | string | `"ClusterIssuer"` | Issuer kind: Issuer or ClusterIssuer |
| tls.certManager.issuer.name | string | `""` | Existing issuer name |
| tls.certManager.keystorePassword | string | `"changeme"` | Keystore password for JKS files |
| tls.enabled | bool | `false` | Enable TLS/SSL |
| tls.manual.existingSecret | string | `""` | Existing secret with manual certificates |
| tolerations | list | `[]` | Tolerations for pod assignment |

</details>

## Upgrading

To upgrade an existing installation:

```bash
# Update the chart
helm upgrade axondb-timeseries ./axondb-timeseries -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axondb-timeseries
```

## Uninstalling

To remove the AxonOps timeseries database:

```bash
# Uninstall the release
helm uninstall axondb-timeseries

# Optional: Delete PVCs (this will delete all data!)
kubectl delete pvc -l app.kubernetes.io/name=axondb-timeseries
```

**Warning:** Deleting PVCs will permanently delete all database data. Make sure you have backups before proceeding.

## Troubleshooting

### Common Issues

**1. Pods not starting (CrashLoopBackOff)**

Check pod logs:
```bash
kubectl logs axondb-timeseries-0
```

Common causes:
- Insufficient memory (increase `heapSize` and `resources.limits.memory`)
- Storage provisioning issues (check PVC status with `kubectl get pvc`)
- Configuration errors (verify your values file)

**2. Storage issues**

Check PVC status:
```bash
kubectl get pvc
kubectl describe pvc data-axondb-timeseries-0
```

If PVC is pending:
- Verify StorageClass exists: `kubectl get storageclass`
- Check if dynamic provisioning is enabled in your cluster

**3. Certificate issues (cert-manager)**

Check certificate status:
```bash
kubectl get certificate
kubectl describe certificate axondb-timeseries-tls
kubectl get certificaterequest
```

Check cert-manager logs:
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

**4. Connection refused errors**

Verify the service:
```bash
kubectl get svc axondb-timeseries
kubectl describe svc axondb-timeseries
```

Test connectivity from another pod:
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  telnet axondb-timeseries 9042
```

**5. High memory usage**

Check actual memory usage:
```bash
kubectl top pod axondb-timeseries-0
```

Adjust heap size (should be about 50% of container memory):
```yaml
heapSize: 4096M
resources:
  limits:
    memory: 8Gi
```

### Getting Help

For additional support:
- Check the logs: `kubectl logs -f axondb-timeseries-0`
- View events: `kubectl get events --sort-by='.lastTimestamp'`
- Describe the StatefulSet: `kubectl describe statefulset axondb-timeseries`
- Visit AxonOps documentation: <https://docs.axonops.com>
- Contact AxonOps support: <info@axonops.com>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| AxonOps Team | <info@aoxnops.com> |  |

---

*Generated with AxonOps Helm Charts*
