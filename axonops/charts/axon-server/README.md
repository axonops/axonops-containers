# AxonOps Server

![Version: 2.0.0](https://img.shields.io/badge/Version-2.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

A Helm chart for deploying the AxonOps Server - the unified observability platform for Apache Cassandra. The AxonOps Server is the central component that collects metrics and logs from Cassandra clusters, stores them in the timeseries and search databases, and provides APIs for the AxonOps Dashboard.

**Homepage:** <https://axonops.com>

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation Examples](#installation-examples)
  - [Basic Installation](#basic-installation)
  - [Installation with External Databases](#installation-with-external-databases)
  - [Installation with Ingress](#installation-with-ingress)
  - [Installation with TLS/mTLS](#installation-with-tlsmtls)
  - [Installation with LDAP Authentication](#installation-with-ldap-authentication)
  - [Production-Ready Installation](#production-ready-installation)
- [Configuration](#configuration)
- [Upgrading](#upgrading)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)

## Architecture Overview

The AxonOps Server is the central component of the AxonOps platform:

```
┌─────────────────┐         ┌──────────────────┐
│  AxonOps Agents │────────>│  AxonOps Server  │
│  (on Cassandra) │  :1888  │                  │
└─────────────────┘         │  - Metrics API   │
                            │  - Agent Listener│
┌─────────────────┐  :8080  │  - Data Pipeline │
│ AxonOps Dashboard│<───────┤                  │
└─────────────────┘         └──────────────────┘
                                   │     │
                   ┌───────────────┘     └──────────────┐
                   v                                     v
         ┌──────────────────┐                  ┌─────────────────┐
         │ AxonDB Timeseries│                  │ AxonDB Search   │
         │ (Cassandra)      │                  │ (Search Engine) │
         └──────────────────┘                  └─────────────────┘
```

## Prerequisites

Before you begin, ensure you have the following:

### Required Components

- **Kubernetes cluster**: Version 1.19 or higher
- **kubectl**: Configured to communicate with your cluster
- **Helm**: Version 3.0 or higher installed ([Installation guide](https://helm.sh/docs/intro/install/))
- **AxonDB Timeseries**: Already deployed ([Installation guide](../axondb-timeseries/))
- **AxonDB Search**: Already deployed ([Installation guide](../axondb-search/))
- **AxonOps License Key**: Contact AxonOps for a license key

### Optional Components

- **Ingress Controller**: Required if you want external access to the API or agents
- **cert-manager**: For automatic TLS certificate management
- **LDAP Server**: If using LDAP authentication

### Verifying Your Setup

Check if the databases are running:
```bash
# Check timeseries database
kubectl get pods -l app.kubernetes.io/name=axondb-timeseries

# Check search database
kubectl get pods -l app.kubernetes.io/name=axondb-search
```

Check if Helm is installed:
```bash
helm version
```

## Quick Start

The fastest way to get started with the AxonOps Server:

```bash
# Install with default settings (connects to local databases)
helm install axon-server ./axon-server \
  --set config.license_key="YOUR_LICENSE_KEY" \
  --set config.org_name="your-organization"

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axon-server
```

This will deploy the AxonOps Server with:
- Connection to local AxonDB instances
- No external access (ClusterIP services)
- Default authentication (disabled)
- 1Gi persistent storage

## Installation Examples

### Basic Installation

Install with minimal configuration suitable for development/testing:

```yaml
# values-basic.yaml
# Basic AxonOps Server configuration

# Organization and licensing
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  # Listener configuration
  listener:
    host: 0.0.0.0
    api_port: 8080      # API for dashboard
    agents_port: 1888   # Port for agents

  # Database connections
  extraConfig:
    # Timeseries database (Cassandra) connection
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    cql_username: "axonops"
    cql_password: "your-db-password"
    cql_local_dc: "datacenter1"
    cql_ssl: true
    cql_skip_verify: true

# Search database connection
searchDb:
  hosts:
    - https://axondb-search-cluster-master:9200
  username: "admin"
  password: "your-search-password"
  skip_verify: true

# Dashboard URL (used in notifications and links)
dashboardUrl: "https://axonops.example.com"

# Resource limits
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

Install:

```bash
helm install axon-server ./axon-server -f values-basic.yaml
```

### Installation with External Databases

Configure connections to external database instances:

```yaml
# values-external-dbs.yaml
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  extraConfig:
    # External Cassandra timeseries database
    cql_hosts:
      - cassandra-1.example.com
      - cassandra-2.example.com
      - cassandra-3.example.com
    cql_username: "axonops"
    cql_password: "secure-password"
    cql_local_dc: "dc1"
    cql_proto_version: 4

    # Connection tuning
    cql_reconnectionpolicy_maxretries: 10
    cql_reconnectionpolicy_initialinterval: 1s
    cql_reconnectionpolicy_maxinterval: 10s
    cql_retrypolicy_numretries: 3
    cql_retrypolicy_min: 2s
    cql_retrypolicy_max: 10s

    # Performance tuning
    cql_max_searchqueriesparallelism: 100
    cql_batch_size: 100
    cql_page_size: 100

    # Metrics cache
    cql_metrics_cache_max_size: 128  # MB
    cql_metrics_cache_max_items: 500000

    # TLS configuration for Cassandra
    cql_ssl: true
    cql_skip_verify: false
    # cql_ca_file: /ssl/ca.crt
    # cql_cert_file: /ssl/tls.crt
    # cql_key_file: /ssl/tls.key

# External search database
searchDb:
  hosts:
    - https://search-1.example.com:9200
    - https://search-2.example.com:9200
  username: "axonops"
  password: "secure-search-password"
  skip_verify: false

dashboardUrl: "https://axonops.example.com"
```

**If using TLS certificates for Cassandra connection:**

```bash
# Create secret with certificates
kubectl create secret generic axon-server-cql-tls \
  --from-file=ca.crt=path/to/ca.crt \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key

# Update values to mount the secret
```

```yaml
# Add to values file
config:
  sslSecretName: "axon-server-cql-tls"
  extraConfig:
    cql_ssl: true
    cql_skip_verify: false
    cql_ca_file: /ssl/ca.crt
    cql_cert_file: /ssl/tls.crt
    cql_key_file: /ssl/tls.key
```

Install:

```bash
helm install axon-server ./axon-server -f values-external-dbs.yaml
```

### Installation with Ingress

Expose the AxonOps Server APIs externally using Ingress:

```yaml
# values-ingress.yaml
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  extraConfig:
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    cql_username: "axonops"
    cql_password: "password"

searchDb:
  hosts:
    - https://axondb-search-cluster-master:9200
  username: "admin"
  password: "password"

dashboardUrl: "https://axonops.example.com"

# API Ingress (for Dashboard access)
apiIngress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: api.axonops.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: axon-api-tls
      hosts:
        - api.axonops.example.com

# Agent Ingress (for external Cassandra agents)
agentIngress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: agents.axonops.example.com
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: axon-agents-tls
      hosts:
        - agents.axonops.example.com
```

Install:

```bash
helm install axon-server ./axon-server -f values-ingress.yaml
```

### Installation with TLS/mTLS

Configure TLS or mutual TLS for agent connections:

**Step 1: Create TLS secret**

```bash
kubectl create secret generic axon-server-tls \
  --from-file=tls.crt=path/to/server.crt \
  --from-file=tls.key=path/to/server.key \
  --from-file=ca.crt=path/to/ca.crt
```

**Step 2: Create values file**

**For TLS:**

```yaml
# values-tls.yaml
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  # Enable TLS mode
  tls:
    mode: "TLS"  # Options: disabled, TLS, mTLS

  # Mount the SSL secret
  sslSecretName: "axon-server-tls"

  extraConfig:
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    cql_username: "axonops"
    cql_password: "password"

searchDb:
  hosts:
    - https://axondb-search-cluster-master:9200
  username: "admin"
  password: "password"

dashboardUrl: "https://axonops.example.com"
```

**For mTLS (mutual TLS):**

```yaml
# values-mtls.yaml
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  # Enable mTLS mode (requires client certificates)
  tls:
    mode: "mTLS"

  sslSecretName: "axon-server-tls"

  extraConfig:
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    cql_username: "axonops"
    cql_password: "password"

searchDb:
  hosts:
    - https://axondb-search-cluster-master:9200
  username: "admin"
  password: "password"

dashboardUrl: "https://axonops.example.com"
```

Install:

```bash
# For TLS
helm install axon-server ./axon-server -f values-tls.yaml

# OR for mTLS
helm install axon-server ./axon-server -f values-mtls.yaml
```

### Installation with LDAP Authentication

Configure LDAP/Active Directory authentication:

```yaml
# values-ldap.yaml
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  # Enable authentication
  auth:
    enabled: true
    type: "LDAP"
    settings:
      host: "ldap.example.com"
      port: 636
      base: "dc=example,dc=com"
      useSSL: true
      startTLS: false
      insecureSkipVerify: false
      bindDN: "cn=axonops,ou=services,dc=example,dc=com"
      bindPassword: "ldap-bind-password"
      userFilter: "(cn=%s)"
      rolesAttribute: "memberOf"
      callAttempts: 3

      # Role mappings
      rolesMapping:
        # Global roles (apply across all organizations/clusters)
        _global_:
          superUserRole: "cn=axonops-superuser,ou=groups,dc=example,dc=com"
          readOnlyRole: "cn=axonops-readonly,ou=groups,dc=example,dc=com"
          adminRole: "cn=axonops-admin,ou=groups,dc=example,dc=com"
          backupAdminRole: "cn=axonops-backup-admin,ou=groups,dc=example,dc=com"

        # Organization-specific roles
        my-organization:
          superUserRole: "cn=org-superuser,ou=groups,dc=example,dc=com"
          readOnlyRole: "cn=org-readonly,ou=groups,dc=example,dc=com"
          adminRole: "cn=org-admin,ou=groups,dc=example,dc=com"
          backupAdminRole: "cn=org-backup-admin,ou=groups,dc=example,dc=com"

        # Cluster type-specific roles
        my-organization/cassandra:
          adminRole: "cn=cassandra-admin,ou=groups,dc=example,dc=com"

        # Specific cluster roles
        my-organization/cassandra/production:
          superUserRole: "cn=prod-admin,ou=groups,dc=example,dc=com"

  extraConfig:
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    cql_username: "axonops"
    cql_password: "password"

searchDb:
  hosts:
    - https://axondb-search-cluster-master:9200
  username: "admin"
  password: "password"

dashboardUrl: "https://axonops.example.com"
```

Install:

```bash
helm install axon-server ./axon-server -f values-ldap.yaml
```

### Production-Ready Installation

A complete production configuration with all recommended settings:

```yaml
# values-production.yaml
# Production configuration for AxonOps Server

# Organization and licensing
config:
  org_name: "production-org"
  license_key: "YOUR_PRODUCTION_LICENSE_KEY"

  # Listener configuration
  listener:
    host: 0.0.0.0
    api_port: 8080
    agents_port: 1888

  # Enable TLS for agent connections
  tls:
    mode: "TLS"

  # SSL certificates for TLS
  sslSecretName: "axon-server-tls"

  # Enable LDAP authentication
  auth:
    enabled: true
    type: "LDAP"
    settings:
      host: "ldap.production.example.com"
      port: 636
      base: "dc=production,dc=example,dc=com"
      useSSL: true
      startTLS: false
      insecureSkipVerify: false
      bindDN: "cn=axonops,ou=services,dc=production,dc=example,dc=com"
      bindPassword: "secure-ldap-password"
      userFilter: "(cn=%s)"
      rolesAttribute: "memberOf"
      callAttempts: 3
      rolesMapping:
        _global_:
          superUserRole: "cn=axonops-superuser,ou=groups,dc=production,dc=example,dc=com"
          readOnlyRole: "cn=axonops-readonly,ou=groups,dc=production,dc=example,dc=com"
          adminRole: "cn=axonops-admin,ou=groups,dc=production,dc=example,dc=com"
          backupAdminRole: "cn=axonops-backup-admin,ou=groups,dc=production,dc=example,dc=com"

  # Alerting configuration
  alerting:
    notification_interval: 3h

  # Database connection configuration
  extraConfig:
    # Cassandra timeseries database
    cql_hosts:
      - axondb-timeseries-0.axondb-timeseries-headless.production.svc.cluster.local
      - axondb-timeseries-1.axondb-timeseries-headless.production.svc.cluster.local
      - axondb-timeseries-2.axondb-timeseries-headless.production.svc.cluster.local
    cql_username: "axonops"
    cql_password: "secure-cassandra-password"
    cql_local_dc: "datacenter1"
    cql_proto_version: 4
    cql_keyspace_replication: "{ 'class': 'NetworkTopologyStrategy', 'datacenter1': 3 }"

    # Connection settings
    cql_reconnectionpolicy_maxretries: 10
    cql_reconnectionpolicy_initialinterval: 1s
    cql_reconnectionpolicy_maxinterval: 10s
    cql_retrypolicy_numretries: 3
    cql_retrypolicy_min: 2s
    cql_retrypolicy_max: 10s

    # Performance tuning
    cql_max_searchqueriesparallelism: 100
    cql_batch_size: 100
    cql_page_size: 100
    cql_autocreate_tables: true

    # Metrics cache configuration
    cql_metrics_cache_max_size: 256  # MB
    cql_metrics_cache_max_items: 1000000

    # TLS for Cassandra
    cql_ssl: true
    cql_skip_verify: false
    cql_ca_file: /ssl/ca.crt
    cql_cert_file: /ssl/tls.crt
    cql_key_file: /ssl/tls.key

# Search database configuration
searchDb:
  hosts:
    - https://axondb-search-cluster-master-0.axondb-search-cluster-master-headless.production.svc.cluster.local:9200
    - https://axondb-search-cluster-master-1.axondb-search-cluster-master-headless.production.svc.cluster.local:9200
    - https://axondb-search-cluster-master-2.axondb-search-cluster-master-headless.production.svc.cluster.local:9200
  username: "axonops"
  password: "secure-search-password"
  skip_verify: false

# Dashboard URL (used in notifications and email links)
dashboardUrl: "https://axonops.production.example.com"

# API Service (for dashboard connections)
apiService:
  type: ClusterIP
  listenPort: 8080
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"

# API Ingress
apiIngress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  hosts:
    - host: api.axonops.production.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: axon-api-tls
      hosts:
        - api.axonops.production.example.com

# Agent Service (for agent connections)
agentService:
  type: LoadBalancer
  listenPort: 1888
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"

# Agent Ingress (optional if using LoadBalancer)
agentIngress:
  enabled: false

# Resource limits
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 4000m
    memory: 4Gi

# Health check probes
livenessProbe:
  httpGet:
    path: /api/v1/healthz
    port: api
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /api/v1/healthz
    port: api
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

startupProbe:
  httpGet:
    path: /api/v1/healthz
    port: api
  initialDelaySeconds: 0
  periodSeconds: 2
  timeoutSeconds: 3
  failureThreshold: 60

# Persistence
persistence:
  enabled: true
  enableInitChown: true
  size: 10Gi
  # storageClass: "gp3"
  accessMode: ReadWriteOnce
  annotations:
    backup.velero.io/backup-volumes: "data"

# Security context
podSecurityContext:
  enabled: true
  runAsUser: 9988
  fsGroup: 9988
  runAsNonRoot: true

securityContext:
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 9988

# Node selection
nodeSelector:
  workload: monitoring

# Tolerations
tolerations:
  - key: "workload"
    operator: "Equal"
    value: "monitoring"
    effect: "NoSchedule"

# Pod annotations
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

**Before installing:**

```bash
# Create TLS secret for server
kubectl create secret generic axon-server-tls \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key \
  --from-file=ca.crt=path/to/ca.crt \
  -n production
```

**Install the production deployment:**

```bash
helm install axon-server ./axon-server \
  -f values-production.yaml \
  --namespace production \
  --create-namespace
```

**Verify the deployment:**

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=axon-server -n production

# Check services
kubectl get svc -l app.kubernetes.io/name=axon-server -n production

# Check ingress
kubectl get ingress -n production

# Test health endpoint
kubectl port-forward svc/axon-server-api 8080:8080 -n production
curl http://localhost:8080/api/v1/healthz
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.org_name` | Organization name | `"example"` |
| `config.license_key` | AxonOps license key (required) | `""` |
| `config.listener.api_port` | API port for dashboard connections | `8080` |
| `config.listener.agents_port` | Port for agent connections | `1888` |
| `config.tls.mode` | TLS mode: disabled, TLS, mTLS | `"disabled"` |
| `config.auth.enabled` | Enable authentication | `false` |
| `config.extraConfig.cql_hosts` | Cassandra hosts for timeseries DB | `[]` |
| `config.extraConfig.cql_username` | Cassandra username | `""` |
| `searchDb.hosts` | Search database hosts | `[]` |
| `searchDb.username` | Search database username | `""` |
| `dashboardUrl` | Public URL for AxonOps Dashboard | `""` |
| `apiIngress.enabled` | Enable API ingress | `false` |
| `agentIngress.enabled` | Enable agent ingress | `false` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | Size of persistent volume | `1Gi` |

### Important Notes

**License Key:**
- A valid AxonOps license key is required for production use
- Contact AxonOps at <info@axonops.com> to obtain a license

**Database Connections:**
- The server requires connections to both timeseries and search databases
- Ensure databases are running and accessible before deploying the server
- Use service names for in-cluster databases or FQDNs for external databases

**Replica Count:**
- Currently, only 1 replica is supported
- High availability is achieved through StatefulSet and persistent storage

**TLS Modes:**
- `disabled`: No TLS (development only)
- `TLS`: Server-side TLS encryption
- `mTLS`: Mutual TLS (requires client certificates on agents)

### Complete Values Reference

<details>
<summary>Click to expand full values table</summary>

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Pod affinity rules |
| agentIngress.annotations | object | `{}` | Annotations for agent ingress |
| agentIngress.className | string | `"nginx"` | Ingress class for agents |
| agentIngress.enabled | bool | `false` | Enable agent ingress |
| agentIngress.hosts | list | `[{"host":"agents.example.com","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Agent ingress hosts |
| agentIngress.tls | list | `[]` | TLS configuration for agent ingress |
| agentService.annotations | object | `{}` | Annotations for agent service |
| agentService.listenPort | int | `1888` | Agent service port |
| agentService.type | string | `"ClusterIP"` | Agent service type |
| apiIngress.annotations | object | `{}` | Annotations for API ingress |
| apiIngress.className | string | `"traefik"` | Ingress class for API |
| apiIngress.enabled | bool | `false` | Enable API ingress |
| apiIngress.hosts | list | `[{"host":"api.example.com","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | API ingress hosts |
| apiIngress.tls | list | `[]` | TLS configuration for API ingress |
| apiService.annotations | object | `{}` | Annotations for API service |
| apiService.listenPort | int | `8080` | API service port |
| apiService.type | string | `"ClusterIP"` | API service type |
| config.alerting.notification_interval | string | `"3h"` | Alert notification interval |
| config.auth.enabled | bool | `false` | Enable authentication |
| config.extraConfig | object | `{}` | Additional configuration options |
| config.license_key | string | `""` | AxonOps license key |
| config.listener.agents_port | int | `1888` | Agent listener port |
| config.listener.api_port | int | `8080` | API listener port |
| config.listener.host | string | `"0.0.0.0"` | Listener host |
| config.org_name | string | `"example"` | Organization name |
| config.sslSecretName | string | `""` | Secret name containing SSL certificates |
| config.tls.mode | string | `"disabled"` | TLS mode (disabled, TLS, mTLS) |
| dashboardUrl | string | `""` | Public dashboard URL |
| deployment.annotations | object | `{}` | Deployment annotations |
| deployment.env | object | `{}` | Additional environment variables |
| deployment.secretEnv | string | `""` | Secret containing environment variables |
| extraVolumeMounts | list | `[]` | Additional volume mounts |
| extraVolumes | list | `[]` | Additional volumes |
| fullnameOverride | string | `""` | Override full resource name |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"registry.axonops.com/axonops-public/axonops-docker/axon-server"` | Image repository |
| image.tag | string | `""` | Image tag (defaults to appVersion) |
| imagePullSecrets | list | `[]` | Image pull secrets |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":5}` | Liveness probe configuration |
| nameOverride | string | `""` | Override chart name |
| nodeSelector | object | `{}` | Node labels for pod assignment |
| persistence.accessMode | string | `"ReadWriteOnce"` | Access mode for PVC |
| persistence.annotations | object | `{}` | Annotations for PVC |
| persistence.enableInitChown | bool | `true` | Enable init container to set ownership |
| persistence.enabled | bool | `true` | Enable persistent storage |
| persistence.size | string | `"1Gi"` | Size of persistent volume |
| persistence.storageClass | string | `""` | Storage class name |
| podAnnotations | object | `{}` | Pod annotations |
| podLabels | object | `{}` | Pod labels |
| podManagementPolicy | string | `"OrderedReady"` | Pod management policy |
| podSecurityContext.enabled | bool | `false` | Enable pod security context |
| podSecurityContext.fsGroup | int | `9988` | FSGroup for pod |
| podSecurityContext.runAsNonRoot | bool | `true` | Run as non-root |
| podSecurityContext.runAsUser | int | `9988` | User ID to run pod |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":3}` | Readiness probe configuration |
| resources | object | `{}` | Resource limits and requests |
| searchDb.hosts | list | `[]` | Search database hosts |
| searchDb.password | string | `""` | Search database password |
| searchDb.skip_verify | bool | `true` | Skip TLS verification for search DB |
| searchDb.username | string | `""` | Search database username |
| securityContext | object | `{"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":false,"runAsNonRoot":true,"runAsUser":9988}` | Container security context |
| serviceAccount.annotations | object | `{}` | Service account annotations |
| serviceAccount.automount | bool | `true` | Automount service account token |
| serviceAccount.create | bool | `true` | Create service account |
| serviceAccount.createClusterRole | bool | `false` | Create cluster role |
| serviceAccount.name | string | `""` | Service account name |
| startupProbe | object | `{"failureThreshold":60,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":0,"periodSeconds":2,"timeoutSeconds":3}` | Startup probe configuration |
| tolerations | list | `[]` | Tolerations for pod assignment |
| updateStrategy.type | string | `"RollingUpdate"` | Update strategy type |

</details>

## Upgrading

To upgrade an existing installation:

```bash
# Update the chart
helm upgrade axon-server ./axon-server -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axon-server
```

**Important Notes:**
- Always review the changelog before upgrading
- Test upgrades in a non-production environment first
- Backup the persistent volume before upgrading
- The server may be briefly unavailable during the upgrade

## Uninstalling

To remove the AxonOps Server:

```bash
# Uninstall the release
helm uninstall axon-server

# Optional: Delete PVC (this will delete server data!)
kubectl delete pvc -l app.kubernetes.io/name=axon-server
```

**Warning:** Deleting the PVC will remove:
- Server configuration
- User data (if not using LDAP)
- Alert history and notification state

## Troubleshooting

### Common Issues

**1. Server not connecting to databases**

Check database connectivity:
```bash
# Get server pod logs
kubectl logs axon-server-0

# Look for connection errors
kubectl logs axon-server-0 | grep -i "error\|connection\|failed"
```

Common causes:
- Incorrect database hostnames or service names
- Wrong credentials (check username/password)
- Database not ready (ensure databases are running first)
- Network policies blocking connections

**2. License key errors**

If you see license errors:
```bash
# Check if license key is set
kubectl get statefulset axon-server -o yaml | grep -A 5 license_key
```

- Ensure `config.license_key` is set in values
- Contact AxonOps for a valid license key
- Check for typos or extra spaces in the license key

**3. Agents not connecting**

Check agent connectivity:
```bash
# Check agent service
kubectl get svc axon-server-agents

# Check if port is accessible
kubectl port-forward svc/axon-server-agents 1888:1888

# In another terminal
telnet localhost 1888
```

Common causes:
- Agents using wrong hostname or port
- TLS mode mismatch (server in TLS, agents not configured)
- Network policies or firewalls blocking port 1888
- Ingress not configured correctly for external agents

**4. Dashboard cannot connect to API**

Verify API service:
```bash
# Check API service
kubectl get svc axon-server-api

# Test API health
kubectl port-forward svc/axon-server-api 8080:8080
curl http://localhost:8080/api/v1/healthz
```

If using ingress:
```bash
# Check ingress configuration
kubectl get ingress

# Test external access
curl https://api.axonops.example.com/api/v1/healthz
```

**5. LDAP authentication failing**

Check LDAP configuration:
```bash
# View server logs for LDAP errors
kubectl logs axon-server-0 | grep -i ldap

# Common issues:
# - Incorrect bind DN or password
# - Wrong LDAP host or port
# - SSL/TLS certificate issues
# - Incorrect user filter or base DN
# - Role attribute not found
```

Test LDAP connectivity:
```bash
# From within the pod
kubectl exec -it axon-server-0 -- sh
# Try to connect to LDAP server
nc -zv ldap.example.com 636
```

**6. High memory usage**

Check resource usage:
```bash
kubectl top pod axon-server-0
```

Increase resources if needed:
```yaml
resources:
  limits:
    memory: 4Gi
  requests:
    memory: 2Gi
```

**7. Persistent volume issues**

Check PVC status:
```bash
kubectl get pvc
kubectl describe pvc data-axon-server-0
```

If PVC is pending:
- Verify StorageClass exists and is default
- Check if there's sufficient storage quota
- Ensure dynamic provisioning is enabled

**8. TLS certificate issues**

For TLS/mTLS problems:
```bash
# Check if secret exists
kubectl get secret axon-server-tls

# Verify secret contains required keys
kubectl describe secret axon-server-tls

# Check server logs for TLS errors
kubectl logs axon-server-0 | grep -i tls
```

Ensure certificates:
- Are in PEM format
- Have correct permissions
- Are not expired
- Match the server hostname

### Getting Help

For additional support:

- **Check logs:** `kubectl logs -f axon-server-0`
- **View events:** `kubectl get events --sort-by='.lastTimestamp'`
- **Describe pod:** `kubectl describe pod axon-server-0`
- **Test health endpoint:**
  ```bash
  kubectl port-forward svc/axon-server-api 8080:8080
  curl http://localhost:8080/api/v1/healthz
  ```
- **Documentation:** <https://docs.axonops.com>
- **Support:** <info@axonops.com>
- **Community:** <https://community.axonops.com>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| AxonOps Team | <info@axonops.com> | <https://axonops.com> |

## Source Code

* <https://github.com/axonops/axonops-containers>

---

*Generated with AxonOps Helm Charts*
