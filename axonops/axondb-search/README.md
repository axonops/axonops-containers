# AxonDB Search Database

[![GHCR Package](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axondb-search)

Production-ready OpenSearch 3.3.2 container optimized for search workloads in AxonOps self-hosted deployments.

## Table of Contents

- [Overview](#overview)
- [Pre-built Docker Images](#pre-built-docker-images)
  - [Available Images](#available-images)
  - [Tagging Strategy](#tagging-strategy)
- [Production Best Practice](#-production-best-practice)
- [Deployment](#deployment)
  - [Kubernetes Deployment Requirements](#kubernetes-deployment-requirements)
- [Building Docker Images](#building-docker-images)
- [Environment Variables](#environment-variables)
- [Container Features](#container-features)
  - [Entrypoint Script](#entrypoint-script)
  - [Startup Version Banner](#startup-version-banner)
  - [Healthcheck Probes](#healthcheck-probes)
  - [Security and Certificate Management](#security-and-certificate-management)
  - [Automated Initialization (Security Configuration and Admin User)](#automated-initialization-security-configuration-and-admin-user)
- [Configuration Files](#configuration-files)
- [CI/CD Pipeline](#cicd-pipeline)
  - [Workflows](#workflows)
  - [Automated Testing](#automated-testing)
  - [Publishing Process](#publishing-process)
- [Troubleshooting](#troubleshooting)
  - [Checking Container Version](#checking-container-version)
  - [Initialization Script Logs](#initialization-script-logs)
  - [Healthcheck Debugging](#healthcheck-debugging)
  - [Container Not Starting](#container-not-starting)
- [Production Considerations](#production-considerations)

## Overview

AxonDB Search is a production-ready OpenSearch container specifically designed for AxonOps self-hosted deployments. This container is optimized for search database workloads and is deployed as part of the complete AxonOps stack using AxonOps Helm charts.

**Container Features:**
- **Modern Search Engine**: OpenSearch 3.3.2 with full-text search, analytics, and visualization capabilities
- **Production Security**: AxonOps-branded TLS certificates (RSA 3072, not demo certificates)
- **Automated Setup**: Pre-configured security plugin with optional custom admin user creation
- **Enterprise Base**: Built on Red Hat UBI 9 minimal for production stability
- **Supply Chain Security**: Digest-pinned base images for immutable builds
- **Production Monitoring**: Integrated healthcheck probes (startup, liveness, readiness)

**Important:** This container is designed exclusively for AxonOps self-hosted deployments. It is deployed and configured via AxonOps Helm charts, which handle all orchestration, networking, and integration with the AxonOps monitoring and management platform. For more information about AxonOps, see [axonops.com](https://axonops.com).

## Pre-built Docker Images

Pre-built images are available from GitHub Container Registry (GHCR). This is the easiest way to get started.

### Available Images

All images are available at: `ghcr.io/axonops/axondb-search`

Browse all available tags: [GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axondb-search)

### Tagging Strategy

Images use a 2-dimensional tagging strategy:

| Tag Pattern | Example | Description | Use Case |
|-------------|---------|-------------|----------|
| `{OPENSEARCH}-{AXON}` | `3.3.2-1.0.0` | Fully immutable (OpenSearch + AxonOps version) | **Production**: Pin exact versions for complete auditability |
| `@sha256:<digest>` | `@sha256:abc123...` | Digest-based (cryptographically immutable) | **Highest Security**: Guaranteed image integrity |
| `{OPENSEARCH}` | `3.3.2` | Latest AxonOps for this OpenSearch version | Track AxonOps updates for specific OpenSearch version |
| `latest` | `latest` | Latest across all versions | Quick trials only (NOT for production) |

**Versioning Dimensions:**
- **OPENSEARCH** - OpenSearch version (e.g., 3.3.2)
- **AXON** - AxonOps container version (e.g., 1.0.0, follows SemVer)

**Tagging Examples:**

When `3.3.2-1.0.0` is built (and it's the latest):
- `3.3.2-1.0.0` (immutable - never changes)
- `3.3.2` (floating - retags to newer AxonOps builds)
- `latest` (floating - moves to newer OpenSearch versions)

## 💡 Production Best Practice

⚠️ **Using `latest` or floating tags in production is an anti-pattern**. This includes `latest` and `3.3.2` because:
- **No audit trail**: Cannot determine exact version deployed at a given time
- **Unexpected updates**: Container orchestrators may pull new images during restarts
- **Rollback difficulties**: Cannot reliably roll back to previous versions
- **Compliance issues**: Many frameworks require immutable version tracking

👍 **Recommended Deployment Strategies (in order of security):**

1. **🥇 Gold Standard - Digest-Based** (Highest Security)
   ```bash
   docker pull ghcr.io/axonops/axondb-search@sha256:abc123...
   ```
   - 100% immutable, cryptographically guaranteed
   - Required for regulated environments
   - Verify signature with Cosign (see [Security](#security))

2. **🥈 Immutable Tag** (Production Standard)
   ```bash
   docker pull ghcr.io/axonops/axondb-search:3.3.2-1.0.0
   ```
   - Pinned to specific version (OpenSearch 3.3.2 + AxonOps 1.0.0)
   - Easy to read and manage
   - Full audit trail maintained

3. **🥉 Floating Tags** (Development/Testing Only)
   ```bash
   docker pull ghcr.io/axonops/axondb-search:latest
   ```
   - Fast iteration
   - NOT for production
   - Use for POCs and testing only

**Security Note:** All production images are cryptographically signed with Sigstore Cosign using keyless signing. Verify signatures before deployment:

```bash
# Install cosign
# macOS: brew install cosign
# Linux: https://docs.sigstore.dev/cosign/installation

# Verify signature
cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Check signature exists
cosign tree ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

## Deployment

This container is deployed exclusively through **AxonOps Helm charts** as part of the AxonOps self-hosted stack. The Helm charts handle all configuration, orchestration, and integration with AxonOps monitoring and management components.

For deployment instructions, refer to the AxonOps self-hosted deployment documentation (available when Helm charts are released).

### Kubernetes Deployment Requirements

**CRITICAL Prerequisites for Kubernetes Deployments:**

OpenSearch requires specific system-level configurations on Kubernetes nodes and pod security contexts. These settings are mandatory for production deployments.

#### 1. Node-Level Configuration (vm.max_map_count)

OpenSearch uses a mmapfs directory to store indices. The default operating system limits on mmap counts is likely to be too low, which may result in out-of-memory exceptions.

**Requirement: `vm.max_map_count` >= 262144 on ALL Kubernetes nodes**

```bash
# Check current value on node
sysctl vm.max_map_count

# Set permanently on each Kubernetes node
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# OR use a DaemonSet to set on all nodes automatically
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: opensearch-sysctl
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: opensearch-sysctl
  template:
    metadata:
      labels:
        name: opensearch-sysctl
    spec:
      hostNetwork: true
      hostPID: true
      initContainers:
      - name: sysctl
        image: busybox
        command: ['sh', '-c', 'sysctl -w vm.max_map_count=262144']
        securityContext:
          privileged: true
      containers:
      - name: pause
        image: gcr.io/google_containers/pause
EOF
```

#### 2. Pod Security Context (ulimits and capabilities)

**Requirement: `ulimits.nofile` (max file descriptors) >= 65536**

OpenSearch requires a high number of file descriptors. Additionally, `bootstrap.memory_lock: true` (configured in `opensearch.yml`) requires the `IPC_LOCK` capability to prevent memory swapping.

**Complete Pod Security Configuration:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: axondb-search
spec:
  # Enable IPC_LOCK capability for bootstrap.memory_lock
  securityContext:
    capabilities:
      add:
        - IPC_LOCK
    # Memory lock requires memlock=-1 (unlimited)
    # This is handled by the IPC_LOCK capability in Kubernetes

  containers:
  - name: opensearch
    image: ghcr.io/axonops/axondb-search:3.3.2-1.0.0

    # CRITICAL: Set resource limits
    resources:
      requests:
        memory: "12Gi"  # 1.5x heap size (8G default)
        cpu: "4"
      limits:
        memory: "16Gi"
        cpu: "8"

    # CRITICAL: Set ulimits via securityContext
    securityContext:
      # OpenSearch runs as UID 999 (opensearch user)
      runAsUser: 999
      runAsGroup: 999
      # Allow memory locking (for bootstrap.memory_lock)
      capabilities:
        add:
          - IPC_LOCK
      # Set nofile (max open files) to 65536
      # Note: In Kubernetes, this is set via container securityContext
      # The actual ulimit is controlled by the container runtime
      # For containerd/CRI-O, set limits in container runtime config
      allowPrivilegeEscalation: false

    env:
    # Heap size (default: 8g)
    - name: OPENSEARCH_HEAP_SIZE
      value: "8g"

    # Custom admin user (optional but recommended)
    - name: AXONOPS_SEARCH_USER
      value: "dbadmin"
    - name: AXONOPS_SEARCH_PASSWORD
      valueFrom:
        secretKeyRef:
          name: opensearch-credentials
          key: admin-password

    # TLS enabled (default: true)
    - name: AXONOPS_SEARCH_TLS_ENABLED
      value: "true"

    # Cluster configuration
    - name: OPENSEARCH_CLUSTER_NAME
      value: "axonops-production"
    - name: OPENSEARCH_NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name

    # Volume mounts
    volumeMounts:
    - name: data
      mountPath: /var/lib/opensearch
    - name: logs
      mountPath: /var/log/opensearch

    # Healthcheck probes
    startupProbe:
      exec:
        command:
          - /usr/local/bin/healthcheck.sh
          - startup
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 10
      failureThreshold: 30  # 5 minutes max startup time

    livenessProbe:
      exec:
        command:
          - /usr/local/bin/healthcheck.sh
          - liveness
      initialDelaySeconds: 60
      periodSeconds: 10
      timeoutSeconds: 10
      failureThreshold: 3

    readinessProbe:
      exec:
        command:
          - /usr/local/bin/healthcheck.sh
          - readiness
      initialDelaySeconds: 60
      periodSeconds: 10
      timeoutSeconds: 10
      failureThreshold: 3

  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: opensearch-data
  - name: logs
    emptyDir: {}
```

**StatefulSet Example (for production clusters):**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: axondb-search
spec:
  serviceName: axondb-search
  replicas: 3
  selector:
    matchLabels:
      app: axondb-search
  template:
    metadata:
      labels:
        app: axondb-search
    spec:
      # Anti-affinity to spread pods across nodes
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: axondb-search
            topologyKey: kubernetes.io/hostname

      # Init container to set ulimits (if container runtime doesn't support it)
      initContainers:
      - name: increase-ulimit
        image: busybox
        command:
          - sh
          - -c
          - ulimit -n 65536
        securityContext:
          privileged: true

      # OpenSearch container (see Pod example above for full configuration)
      containers:
      - name: opensearch
        image: ghcr.io/axonops/axondb-search:3.3.2-1.0.0
        # ... (rest of container config from Pod example)

  # Persistent volume claim template
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 500Gi
```

**Important Notes:**
- **vm.max_map_count**: Must be set on ALL Kubernetes nodes (not just the pod)
- **ulimits.nofile**: Set via `securityContext` or init container
- **IPC_LOCK**: Required for `bootstrap.memory_lock: true` (prevents swapping)
- **Persistent volumes**: Use SSD storage with adequate IOPS for production
- **Memory**: Allocate at least 1.5x heap size (e.g., 12Gi for 8G heap)

## Building Docker Images

If you prefer to build images yourself instead of using pre-built images:

```bash
cd axonops/axondb-search/opensearch/3.3.2

# Minimal build (required args only)
docker build \
  --build-arg OPENSEARCH_VERSION=3.3.2 \
  -t axondb-search:3.3.2-1.0.0 \
  .

# Multi-arch build (amd64 + arm64) using buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg OPENSEARCH_VERSION=3.3.2 \
  -t axondb-search:3.3.2-1.0.0 \
  .
```

**Required build arguments:**
- `OPENSEARCH_VERSION` - OpenSearch version (e.g., 3.3.2)

**Optional build arguments (enhance metadata but aren't required):**
- `BUILD_DATE` - Build timestamp (ISO 8601 format, e.g., `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF` - Git commit SHA (e.g., `$(git rev-parse HEAD)`)
- `VERSION` - Container version (e.g., 1.0.0)
- `GIT_TAG` - Git tag name (for release/tag links in banner)
- `GITHUB_ACTOR` - Username who triggered build (for audit trail)
- `IS_PRODUCTION_RELEASE` - Set to `true` for production (default: `false`)
- `IMAGE_FULL_NAME` - Full image name with tag (displayed in startup banner)

**Supply Chain Security:**

Our Dockerfile uses digest-pinned base images for supply chain security:

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
ARG UBI9_MINIMAL_DIGEST=sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2
FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
```

**Why digest pinning matters:**
- Tags can be replaced maliciously (same tag, different image)
- Digests are cryptographically immutable - cannot be changed
- Prevents silent compromise of your container supply chain
- Industry best practice for production builds

## Environment Variables

The container supports 21 environment variables for configuration:

| Variable | Description | Default | Category |
|----------|-------------|---------|----------|
| `OPENSEARCH_CLUSTER_NAME` | Cluster name | `axonopsdb-search` | OpenSearch Config |
| `OPENSEARCH_NODE_NAME` | Node name | `${HOSTNAME}` | OpenSearch Config |
| `OPENSEARCH_NETWORK_HOST` | Network bind address | `0.0.0.0` | OpenSearch Config |
| `OPENSEARCH_DISCOVERY_TYPE` | Cluster discovery type (`single-node` or multi-node) | `single-node` | OpenSearch Config |
| `OPENSEARCH_HEAP_SIZE` | JVM heap size (both -Xms and -Xmx) | `8g` | OpenSearch Config |
| `OPENSEARCH_HTTP_PORT` | HTTP API port | `9200` | OpenSearch Config |
| `OPENSEARCH_DATA_DIR` | Data directory path | `/var/lib/opensearch` | OpenSearch Config |
| `OPENSEARCH_LOG_DIR` | Log directory path | `/var/log/opensearch` | OpenSearch Config |
| `OPENSEARCH_PATH_CONF` | Configuration directory path | `/etc/opensearch` | OpenSearch Config |
| `AXONOPS_SEARCH_USER` | Create custom admin user with this username (replaces default admin) | - | Security & Init |
| `AXONOPS_SEARCH_PASSWORD` | Password for custom admin user (required if `AXONOPS_SEARCH_USER` set) | - | Security & Init |
| `AXONOPS_SEARCH_TLS_ENABLED` | Enable HTTPS on REST API (set `false` for LB termination) | `true` | Security & Init |
| `GENERATE_CERTS_ON_STARTUP` | Generate AxonOps default certificates at runtime if missing | `true` | Security & Init |
| `INIT_OPENSEARCH_SECURITY` | Run security initialization (deprecated, always runs) | `true` | Security & Init |
| `INIT_TIMEOUT` | Timeout in seconds for initialization script | `600` (10 min) | Security & Init |
| `OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE` | Write thread pool queue size (increase for high-write workloads) | `10000` | Advanced/Transport |
| `OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION` | Enforce hostname verification for transport SSL | `false` | Advanced/Transport |
| `OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE` | HTTP client authentication mode (`NONE`, `OPTIONAL`, `REQUIRED`) | `NONE` | Advanced/Transport |
| `OPENSEARCH_SECURITY_ADMIN_DN` | Custom admin certificate DN (for custom certificate scenarios) | `OU=Database,O=AxonOps,CN=admin.axondbsearch.axonops.com` | Advanced/Transport |
| `DISABLE_SECURITY_PLUGIN` | Disable security plugin entirely (NOT recommended for production) | `false` | Plugin Control |
| `DISABLE_PERFORMANCE_ANALYZER_AGENT_CLI` | Disable performance analyzer (AxonOps provides monitoring) | `true` | Plugin Control |

### OpenSearch Configuration

The first 9 variables configure OpenSearch's core behavior. These are processed by the entrypoint script and applied to configuration files before OpenSearch starts.

**Network Configuration:**
- `OPENSEARCH_NETWORK_HOST` - Set to `0.0.0.0` to bind on all interfaces
- `OPENSEARCH_HTTP_PORT` - REST API port (default: 9200)

**Cluster Configuration:**
- `OPENSEARCH_CLUSTER_NAME` - Descriptive cluster name
- `OPENSEARCH_NODE_NAME` - Defaults to pod hostname in Kubernetes
- `OPENSEARCH_DISCOVERY_TYPE` - Set to `single-node` for single-node clusters, or configure seed hosts for multi-node

**Resource Configuration:**
- `OPENSEARCH_HEAP_SIZE` - Controls JVM heap (both -Xms and -Xmx set to same value)
- Recommendation: Set to 50% of container memory, max 32GB

**Example:**
```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_CLUSTER_NAME=production-search \
  -e OPENSEARCH_NODE_NAME=search-node-01 \
  -e OPENSEARCH_HEAP_SIZE=16g \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=SecurePassword123 \
  -p 9200:9200 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

### Security and Initialization Control

**TLS/SSL Configuration:**

By default, the container enables HTTPS on the REST API using AxonOps-branded certificates. If you're using a load balancer or ingress that terminates TLS, you can disable HTTP SSL:

```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_TLS_ENABLED=false \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Important:** Transport layer SSL (node-to-node communication) remains enabled even when HTTP SSL is disabled.

**Custom Admin User (REPLACEMENT Model):**

The container supports creating a custom admin user that **REPLACES** the default admin user. This is different from AxonDB Time-Series which appends a custom user - in OpenSearch, for security reasons, only one admin user should exist.

```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=MySecurePassword123 \
  -p 9200:9200 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Connect with new credentials
curl -k -u dbadmin:MySecurePassword123 https://localhost:9200/_cluster/health
```

**Important:**
- Custom user creation happens **before** OpenSearch starts (pre-startup, not background)
- The default `admin` user is **REMOVED** from `internal_users.yml`
- Only the custom user will exist (no default admin)
- User creation is atomic - either succeeds completely or rolls back

**Timeout Configuration:**

The initialization script waits up to `INIT_TIMEOUT` seconds (default: 600 = 10 minutes) for OpenSearch to become ready. If your environment has slow startup (large heap, slow disks), increase this value:

```bash
docker run -d --name axondb-search \
  -e INIT_TIMEOUT=1200 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

### Advanced Configuration

**Thread Pool Configuration:**

For high-write workloads, you may need to increase the write thread pool queue size:

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE=20000 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Transport SSL Configuration:**

For multi-node clusters with strict security requirements:

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION=true \
  -e OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE=OPTIONAL \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

## Container Features

### Entrypoint Script

The entrypoint script (`/usr/local/bin/docker-entrypoint.sh`) is the main orchestrator that configures OpenSearch and manages container startup. It runs as PID 1 via [tini](https://github.com/krallin/tini) and performs critical initialization before starting OpenSearch.

#### tini - A Minimal Init System

The container uses **tini** as its init system (PID 1). Tini is a minimal init system specifically designed for containers that:

- **Handles signals properly** - Forwards signals (SIGTERM, SIGINT) to child processes for graceful shutdown
- **Reaps zombie processes** - Cleans up terminated child processes that would otherwise accumulate
- **Extremely lightweight** - Single static binary (~10KB), minimal overhead
- **Industry standard** - Used by Docker as the default init when `--init` flag is specified

The Dockerfile sets tini as the entrypoint wrapper:
```dockerfile
ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["opensearch"]
```

This means the actual process tree is:
```
tini (PID 1)
  └─► docker-entrypoint.sh
       └─► opensearch (after exec)
```

After `exec opensearch`, OpenSearch replaces the shell script but tini remains as PID 1, ensuring proper signal handling for the entire container.

**Learn more:** [github.com/krallin/tini](https://github.com/krallin/tini)

#### What It Does

**1. Displays Startup Banner**
- Sources build metadata from `/etc/axonops/build-info.txt`
- Prints comprehensive version information (OpenSearch, Java, OS)
- Shows runtime environment (Kubernetes detection, hostname)
- Displays supply chain security info (base image digest)

**2. Sets Default Environment Variables**
- `OPENSEARCH_CLUSTER_NAME` (default: `axonopsdb-search`)
- `OPENSEARCH_NODE_NAME` (default: hostname)
- `OPENSEARCH_NETWORK_HOST` (default: `0.0.0.0`)
- `OPENSEARCH_DISCOVERY_TYPE` (default: `single-node`)
- `OPENSEARCH_HEAP_SIZE` (default: `8g`)
- `AXONOPS_SEARCH_TLS_ENABLED` (default: `true`)

**3. Applies Environment Variables to OpenSearch Configuration**
- Updates `opensearch.yml` with cluster name, node name, network settings
- Adjusts JVM heap size in `jvm.options`
- Configures thread pool settings, SSL settings, security admin DN
- Handles TLS enable/disable for HTTP layer

**4. Creates Custom Admin User (Pre-Startup)**
- If `AXONOPS_SEARCH_USER` and `AXONOPS_SEARCH_PASSWORD` are set
- Generates bcrypt password hash using OpenSearch security tools
- **REPLACES** `internal_users.yml` with ONLY the custom user (deletes default admin)
- This happens before OpenSearch starts (atomic operation)
- Writes semaphore file immediately to `/var/lib/opensearch/.axonops/init-security.done`

**5. Starts OpenSearch**
- Executes `opensearch` (foreground mode)
- Replaces entrypoint process (becomes main container process)
- OpenSearch takes over with tini as PID 1

#### Execution Order

```
entrypoint.sh (PID 1 via tini)
  │
  ├─► 1. Print startup banner
  │
  ├─► 2. Set default environment variables
  │      (OPENSEARCH_CLUSTER_NAME, OPENSEARCH_NODE_NAME, etc.)
  │
  ├─► 3. Apply environment variables to opensearch.yml
  │      (cluster.name, node.name, network.host, discovery.type, etc.)
  │
  ├─► 4. Apply heap size to jvm.options
  │
  ├─► 5. Apply advanced settings (thread pool, SSL, security admin DN)
  │
  ├─► 6. Create custom admin user (PRE-STARTUP, if requested)
  │      - Generate password hash
  │      - REPLACE internal_users.yml with ONLY custom user
  │      - Write semaphore file
  │
  └─► 7. exec opensearch
         - Replaces entrypoint process
         - OpenSearch becomes main process
         - Container runs OpenSearch from this point
```

#### Configuration Files Modified

The entrypoint modifies these OpenSearch configuration files based on environment variables:

| File | What's Modified | Environment Variables |
|------|----------------|----------------------|
| `/etc/opensearch/opensearch.yml` | Core OpenSearch settings | `OPENSEARCH_CLUSTER_NAME`, `OPENSEARCH_NODE_NAME`, `OPENSEARCH_NETWORK_HOST`, `OPENSEARCH_DISCOVERY_TYPE`, `OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE`, `OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION`, `OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE`, `OPENSEARCH_SECURITY_ADMIN_DN`, `AXONOPS_SEARCH_TLS_ENABLED` |
| `/etc/opensearch/jvm.options` | JVM heap memory settings | `OPENSEARCH_HEAP_SIZE` |
| `/etc/opensearch/opensearch-security/internal_users.yml` | Admin user configuration | `AXONOPS_SEARCH_USER`, `AXONOPS_SEARCH_PASSWORD` (REPLACES entire file) |

#### Key Design Decisions

**Why exec opensearch?**
- Using `exec` replaces the shell process with OpenSearch
- OpenSearch becomes the main process under tini (PID 1 wrapper)
- Ensures clean shutdown when container stops
- No orphaned shell process consuming resources

**Why pre-startup user creation (not background)?**
- Admin user creation modifies `internal_users.yml` before OpenSearch reads it
- Ensures clean, atomic operation (no race conditions)
- OpenSearch reads the final configuration on first startup
- Simpler than post-startup securityadmin tool (which requires TLS)
- **REPLACEMENT model**: Only ONE admin user exists (custom OR default, never both)

**Why tini as the init system?**
- **Signal forwarding** - Ensures SIGTERM/SIGINT reach OpenSearch for graceful shutdown
- **Zombie reaping** - Cleans up terminated child processes
- **Container best practice** - Prevents issues when container engine sends stop signals
- **Minimal overhead** - Tiny static binary (~10KB) with no dependencies
- **Industry standard** - Same init system Docker uses with `--init` flag
- Without tini, shell scripts (PID 1) don't forward signals properly, causing forced kills

**More info:** [Why you need an init system](https://github.com/krallin/tini#why-tini) in containers

### Startup Version Banner

All containers display comprehensive version information on startup:

```
================================================================================
AxonOps AxonDB Search (OpenSearch 3.3.2)
Image: ghcr.io/axonops/axondb-search:3.3.2-1.0.0
Built: 2025-12-13T10:30:00Z
Release: https://github.com/axonops/axonops-containers/releases/tag/axondb-search-1.0.0
Built by: GitHub Actions
================================================================================

Component Versions:
  OpenSearch:         3.3.2
  Java:               OpenJDK Runtime Environment (Red_Hat-17.0.17.0.10-1)
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI - Universal Base Image, freely redistributable)
  Platform:           x86_64

Supply Chain Security:
  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest
  Base image digest:  sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2

Runtime Environment:
  Hostname:           axondb-search-node-1
  Kubernetes:         Yes
    API Server:       10.0.0.1:443
    Pod:              axondb-search-node-1

================================================================================
Starting OpenSearch...
================================================================================
```

**View the banner:**
```bash
docker logs axondb-search | head -30
```

### Healthcheck Probes

The container includes an optimized healthcheck script supporting three probe types, designed for minimal overhead while ensuring reliability:

**1. Startup Probe** (`healthcheck.sh startup`)
- **Waits for initialization to complete** (critical for pre-startup admin user creation)
- Checks for semaphore file in persistent storage: `/var/lib/opensearch/.axonops/init-security.done`
- **Validates RESULT field** - Fails if semaphore has `RESULT=failed`
- Verifies OpenSearch process is running (`pgrep -f OpenSearch`)
- Checks HTTP port (9200) is listening (TCP check via `nc`)
- Checks security plugin health endpoint (lightweight, no auth required)
- **Blocks pod "Started" status until init completes successfully**
- Use for: Kubernetes `startupProbe` (ensures admin user created before traffic routing)

**2. Liveness Probe** (`healthcheck.sh liveness`)
- **Ultra-lightweight** - Designed to run frequently (every 10 seconds)
- Checks if OpenSearch process is running (`pgrep -f OpenSearch`)
- Checks HTTP port (9200) is listening (TCP check via `nc`)
- Checks security plugin health endpoint (lightweight, no auth required)
- **No cluster health API calls** - Minimal overhead, very fast execution
- Use for: Kubernetes `livenessProbe` (detecting if OpenSearch process has crashed)

**3. Readiness Probe** (`healthcheck.sh readiness`)
- Checks HTTP port (9200) is listening (TCP check via `nc`)
- Makes authenticated call to `/_cluster/health` API
- Verifies cluster status is not "red" (yellow or green is acceptable)
- **More thorough** than liveness - ensures OpenSearch is fully operational
- Automatically detects admin credentials from semaphore file (custom user if created)
- Use for: Kubernetes `readinessProbe` (load balancer health checks, traffic routing)

**Docker healthcheck:**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect axondb-search --format='{{json .State.Health}}' | jq
```

**Manual healthcheck testing:**
```bash
# Test startup probe
docker exec axondb-search /usr/local/bin/healthcheck.sh startup

# Test liveness probe
docker exec axondb-search /usr/local/bin/healthcheck.sh liveness

# Test readiness probe
docker exec axondb-search /usr/local/bin/healthcheck.sh readiness
```

**Note:** Healthcheck probe configuration is handled automatically by AxonOps Helm charts. The above modes are available for custom deployments if needed.

### Security and Certificate Management

The container includes a comprehensive security configuration with AxonOps-branded TLS certificates generated **at runtime** (container startup), providing better security and flexibility for persistent storage scenarios.

#### Runtime Certificate Generation

**How It Works:**

The container generates certificates automatically when it starts:

1. **Startup Check**: On container startup, the entrypoint script checks if certificate files exist
2. **Automatic Generation**: If certificates are missing, they are generated automatically with AxonOps branding
3. **Semaphore Tracking**: A semaphore file records the generation status
4. **Skip on Restart**: If certificates already exist (persistent volume), generation is skipped

**Benefits of Runtime Generation:**

- **Persistent Storage Compatible**: Certificates persist across container recreations when using volumes
- **Fresh Certificates**: New deployments get newly-generated certificates
- **User-Provided Certificates**: Easy to provide your own certificates by disabling auto-generation
- **Transparent Operation**: Fully automatic with sensible defaults

**Controlling Certificate Generation:**

Use the `GENERATE_CERTS_ON_STARTUP` environment variable to control this behavior:

```bash
# Default: Auto-generate certificates if missing
docker run -d --name axondb-search \
  -e GENERATE_CERTS_ON_STARTUP=true \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Disable: Require user-provided certificates
docker run -d --name axondb-search \
  -e GENERATE_CERTS_ON_STARTUP=false \
  -v /path/to/your/certs:/etc/opensearch/certs \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Generation Scenarios:**

| Scenario | `GENERATE_CERTS_ON_STARTUP` | Certificates Exist? | Result |
|----------|----------------------------|---------------------|--------|
| **First startup (empty volume)** | `true` (default) | No | ✓ Certificates generated |
| **First startup (no volume)** | `true` (default) | No | ✓ Certificates generated (ephemeral) |
| **Restart with persistent volume** | `true` (default) | Yes | ✓ Skipped (existing certs used) |
| **User-provided certificates** | `false` | Yes | ✓ User certs used |
| **User-provided certificates** | `false` | No | ✗ Container fails (no certs) |

**Semaphore File:**

The certificate generation status is recorded in `/var/lib/opensearch/.axonops/generate-certs.done`:

```bash
# Check certificate generation status
docker exec axondb-search cat /var/lib/opensearch/.axonops/generate-certs.done

# Example output:
COMPLETED=2025-12-16T05:47:02Z
RESULT=success
REASON=certs_generated
```

**Possible `RESULT` values:**
- `success` - Certificates generated successfully
- `skipped` - Certificates already exist, generation skipped
- `disabled` - Certificate generation disabled via `GENERATE_CERTS_ON_STARTUP=false`

#### AxonOps-Branded Certificates (NOT Demo Certificates)

**CRITICAL DIFFERENCE from Demo Setup:**

- **Demo certificates are DELETED** during Docker build (never present in final image)
- **AxonOps-branded certificates** are generated with production-grade settings
- **Certificate details:**
  - **Algorithm:** RSA 3072-bit (strong security)
  - **Validity:** 5 years (1825 days)
  - **Organization:** AxonOps
  - **Organizational Unit:** Database
  - **Common Names:**
    - Root CA: `AxonOps Root CA`
    - Node Certificate: `axondbsearch.axonops.com`
    - Admin Certificate: `admin.axondbsearch.axonops.com`
  - **Subject Alternative Names (SAN):** `axondbsearch.axonops.com`, `*.axondbsearch.axonops.com`, `localhost`, `127.0.0.1`, `::1`

**Security Configuration (opensearch.yml):**

```yaml
# Transport layer SSL/TLS (node-to-node communication)
plugins.security.ssl.transport.pemcert_filepath: certs/axondbsearch-default-node.pem
plugins.security.ssl.transport.pemkey_filepath: certs/axondbsearch-default-node-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: certs/axondbsearch-default-root-ca.pem
plugins.security.ssl.transport.enforce_hostname_verification: false

# HTTP layer SSL/TLS (REST API)
plugins.security.ssl.http.enabled: true
plugins.security.ssl.http.pemcert_filepath: certs/axondbsearch-default-node.pem
plugins.security.ssl.http.pemkey_filepath: certs/axondbsearch-default-node-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: certs/axondbsearch-default-root-ca.pem
plugins.security.ssl.http.clientauth_mode: NONE

# Admin certificate DN (for securityadmin tool)
plugins.security.authcz.admin_dn:
  - "OU=Database,O=AxonOps,CN=admin.axondbsearch.axonops.com"

# Demo certificates NOT allowed (we use AxonOps-branded certificates)
plugins.security.allow_unsafe_democertificates: false
```

#### Certificate Files Generated

The following certificate files are created in `/etc/opensearch/certs/` (using `axondbsearch-default-` prefix to clearly identify auto-generated certificates):

| File | Type | Description |
|------|------|-------------|
| `axondbsearch-default-root-ca.pem` | Root CA Certificate | AxonOps Root CA (public certificate) |
| `axondbsearch-default-root-ca-key.pem` | Root CA Private Key | Root CA private key (600 permissions) |
| `axondbsearch-default-node.pem` | Node Certificate | Node certificate for transport and HTTP SSL |
| `axondbsearch-default-node-key.pem` | Node Private Key | Node private key in PKCS#8 format (600 permissions) |
| `axondbsearch-default-admin.pem` | Admin Certificate | Admin client certificate for securityadmin tool |
| `axondbsearch-default-admin-key.pem` | Admin Private Key | Admin private key in PKCS#8 format (600 permissions) |

**File Naming Convention:**

Certificate files use the `axondbsearch-default-` prefix to:
- Clearly identify AxonOps auto-generated certificates
- Distinguish them from user-provided certificates
- Make it obvious which certificates can be safely replaced

**Certificate Verification:**

```bash
# View node certificate details
docker exec axondb-search openssl x509 -in /etc/opensearch/certs/axondbsearch-default-node.pem -noout -text

# Verify certificate chain
docker exec axondb-search openssl verify \
  -CAfile /etc/opensearch/certs/axondbsearch-default-root-ca.pem \
  /etc/opensearch/certs/axondbsearch-default-node.pem

# Check certificate generation semaphore
docker exec axondb-search cat /var/lib/opensearch/.axonops/generate-certs.done
```

#### Using Custom Certificates

To provide your own certificates instead of using AxonOps auto-generated ones:

**Option 1: Disable auto-generation and mount your certificates**
```bash
docker run -d --name axondb-search \
  -e GENERATE_CERTS_ON_STARTUP=false \
  -v /path/to/your/certs:/etc/opensearch/certs:ro \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Option 2: Replace certificates in persistent volume**
```bash
# Create volume
docker volume create opensearch-certs

# Start container with auto-generation first time
docker run -d --name axondb-search \
  -v opensearch-certs:/etc/opensearch/certs \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Stop container and replace certificates
docker stop axondb-search
docker run --rm -v opensearch-certs:/certs busybox sh -c "rm /certs/axondbsearch-default-*.pem"
docker cp /path/to/your/certs/. axondb-search:/etc/opensearch/certs/

# Restart with your certificates
docker start axondb-search
```

**Required certificate files (if providing your own):**
- `root-ca.pem` (or your CA cert name)
- `node.pem` (or your node cert name)
- `node-key.pem` (or your node key name, PKCS#8 format)
- `admin.pem` (or your admin cert name)
- `admin-key.pem` (or your admin key name, PKCS#8 format)

Update `opensearch.yml` to reference your certificate filenames if they differ from AxonOps defaults.

#### Admin User Replacement Model

Unlike AxonDB Time-Series (which appends a custom user), AxonDB Search uses a **REPLACEMENT** model for security:

**Default Configuration (no custom user):**
- Default admin user: `admin`
- Default password: `MyS3cur3P@ss2025`
- Located in: `/etc/opensearch/opensearch-security/internal_users.yml`

**Custom User Configuration (recommended for production):**
```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=MySecurePassword123 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**What happens:**
1. Entrypoint script generates bcrypt password hash for custom user
2. **REPLACES** entire `internal_users.yml` file with ONLY the custom user
3. Default `admin` user is **REMOVED** (does not exist in final config)
4. Only ONE admin user exists in the system (custom user)
5. Semaphore file written to `/var/lib/opensearch/.axonops/init-security.done`

**Security Rationale:**
- **Principle of least privilege** - Only one admin account reduces attack surface
- **No default credentials** - Eliminates risk of forgotten default admin user
- **Atomic operation** - User creation is atomic (happens before OpenSearch starts)
- **Clean security model** - No legacy accounts or disabled users

#### TLS Configuration Options

**Enable/Disable HTTP SSL:**

By default, HTTPS is enabled on the REST API. You can disable it for load balancer TLS termination:

```bash
# Disable HTTP SSL (TLS terminated at load balancer)
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_TLS_ENABLED=false \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Important:**
- Transport layer SSL (node-to-node) remains enabled even when HTTP SSL is disabled
- This is recommended when using a load balancer or ingress controller that terminates TLS
- Internal cluster communication is always encrypted

**Custom Certificate DN (Advanced):**

For custom certificate scenarios, you can override the admin certificate DN:

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_SECURITY_ADMIN_DN="CN=mycustomadmin,O=MyOrg,OU=MyUnit" \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

### Automated Initialization (Security Configuration and Admin User)

The container performs automated security initialization, handling both certificate verification and optional custom admin user creation. The initialization is coordinated via semaphore files to ensure proper ordering with healthcheck probes.

#### How It Works (Execution Flow)

The initialization uses **pre-startup configuration** (not background process) for admin user creation, with a background verification script:

```
1. entrypoint.sh starts (PID 1 via tini)
   │
   ├─► 2. Apply configuration (opensearch.yml, jvm.options)
   │
   ├─► 3. Create custom admin user (PRE-STARTUP, if requested)
   │      - Generate password hash
   │      - REPLACE internal_users.yml with ONLY custom user
   │      - Write initial semaphore file
   │      (This happens BEFORE OpenSearch starts)
   │
   └─► 4. Start OpenSearch (exec opensearch)
        │
        ├─► OpenSearch starts and begins accepting connections
        │
        ├─► Background init-opensearch.sh script (optional verification)
        │   - Waits for HTTP API to be ready
        │   - Verifies AxonOps SSL certificates exist
        │   - Updates semaphore file status
        │
        └─► healthcheck.sh (startup probe) checks semaphore
            - Blocks until semaphore file exists
            - Verifies RESULT is not "failed"
            - Only then marks container as "Started"
```

**Why This Pattern is Safe:**

1. **Admin user created before OpenSearch starts** - No race conditions, atomic operation
2. **Only ONE admin user exists** - REPLACEMENT model (custom OR default, never both)
3. **Semaphore coordination** - Healthcheck waits for initialization completion
4. **Persistent semaphores** - Stored in `/var/lib/opensearch` (volume), prevents re-init on restarts
5. **Kubernetes enforcement** - Pod not marked "Started" until semaphore confirms success

#### Phase 1: Admin User Creation (Pre-Startup)

The first phase creates a custom admin user and removes the default admin user **before** OpenSearch starts.

**What it does:**
1. Generates bcrypt password hash for custom user (using OpenSearch hash.sh tool)
2. **REPLACES** `internal_users.yml` with ONLY the custom user definition
3. Default `admin` user is removed (does not exist in final configuration)
4. Writes initial semaphore to persistent storage: `/var/lib/opensearch/.axonops/init-security.done`

**Example:**
```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=MySecurePassword123 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Wait for startup (~1-2 minutes)
docker logs -f axondb-search

# Connect with custom credentials
curl -k -u dbadmin:MySecurePassword123 https://localhost:9200/_cluster/health
```

**Safety checks:**
- Only runs if both `AXONOPS_SEARCH_USER` and `AXONOPS_SEARCH_PASSWORD` are set
- Password hash generation is validated (must be valid bcrypt format)
- File replacement is atomic (writes new file completely before OpenSearch starts)
- **Semaphore is ALWAYS written** (success or error)

#### Phase 2: Certificate and Cluster Verification (Background)

The second phase verifies certificates and cluster health in the background after OpenSearch starts.

**What it does:**
1. Waits for HTTP port (9200) to be listening
2. Waits for OpenSearch cluster to be responsive (`/_cluster/health`)
3. Verifies all AxonOps SSL certificates exist in `/etc/opensearch/certs/`
4. Verifies security configuration file exists
5. Updates semaphore file with final status

**Note:** If `AXONOPS_SEARCH_TLS_ENABLED=false`, the background script cannot use securityadmin tool (requires TLS) and will skip advanced user creation steps.

#### Control and Disable

**Disable security plugin entirely (NOT recommended for production):**
```bash
docker run -d --name axondb-search \
  -e DISABLE_SECURITY_PLUGIN=true \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

When disabled, semaphore files are written immediately with `RESULT=skipped` to allow the healthcheck to proceed.

#### Semaphore Files

The initialization process uses semaphore files to coordinate between the entrypoint script, background verification, and healthcheck probes.

**Location:** `/var/lib/opensearch/.axonops/`

Semaphore files are stored in the OpenSearch data directory (not `/etc`) because:
- `/var/lib/opensearch` is typically configured as a persistent volume in Kubernetes
- When persistent, semaphores survive container/pod restarts
- Prevents re-initialization on pod restarts (e.g., during rolling updates)
- Allows healthcheck to immediately pass after restart without re-running init

**Important:** Configure `/var/lib/opensearch` as a persistent volume (PersistentVolumeClaim) in your Kubernetes deployment. AxonOps Helm charts handle this automatically.

**File Created:**
- `init-security.done` - Security configuration and admin user status

**File Format:**
```
COMPLETED=2025-12-16T09:32:17Z
RESULT=success
REASON=custom_user_created_prestartup
ADMIN_USER=dbadmin
```

**RESULT values for init-security.done:**
- `success` - Security initialization completed successfully
  - `custom_user_created_prestartup` - Custom admin user created (default admin removed)
  - `default_config` - Using default admin user and password
  - `custom_admin_user_created` - Custom user created via background script (legacy)
- `skipped` - Initialization skipped (with REASON explaining why)
  - `security_plugin_disabled` - DISABLE_SECURITY_PLUGIN=true
  - `tls_disabled_no_securityadmin` - TLS disabled, cannot use securityadmin tool
- `failed` - Initialization failed (with REASON) - **Script exits with code 1**
  - `http_port_timeout` - HTTP port didn't open within timeout
  - `cluster_not_responsive` - Cluster didn't respond within timeout
  - `certificates_missing` - AxonOps certificates not found
  - `security_config_missing` - Security configuration files not found
  - `password_hash_failed` - Failed to generate bcrypt password hash
  - `securityadmin_failed` - securityadmin tool failed to apply configuration

**Timeout Configuration:**
- Default timeout: 600 seconds (10 minutes)
- Configurable via `INIT_TIMEOUT` environment variable
- Example: `-e INIT_TIMEOUT=1200` for 20 minutes if OpenSearch startup is slow

**Important:** When `RESULT=failed` is written, the healthcheck startup probe will fail, preventing the container from being marked "Started" in Kubernetes.

**Guarantee:** The semaphore file is **ALWAYS** written in all code paths. The healthcheck startup probe:
1. Requires semaphore file to exist
2. Checks the RESULT field in the semaphore
3. **Fails the startup probe if RESULT=failed**
4. Passes if RESULT=success or RESULT=skipped

This ensures the container won't be marked "Started" if initialization failed.

#### Initialization Logs

Check initialization progress and results:

```bash
# View OpenSearch startup logs
docker logs axondb-search

# Check security initialization status (in persistent volume)
docker exec axondb-search cat /var/lib/opensearch/.axonops/init-security.done

# View internal_users.yml to verify custom user
docker exec axondb-search cat /etc/opensearch/opensearch-security/internal_users.yml

# Verify AxonOps certificates
docker exec axondb-search ls -la /etc/opensearch/certs/
```

## Configuration Files

The container includes 13 configuration files that control OpenSearch behavior:

### Core Configuration Files

| File | Purpose | Key Customizations |
|------|---------|-------------------|
| `opensearch.yml` | Core OpenSearch settings | Production-ready defaults for search workloads, security plugin configuration, AxonOps certificate paths |
| `jvm.options` | JVM options | Heap settings (default 8G), GC configuration optimized for search |
| `log4j2.properties` | Logging configuration | Reduced retention, optimized for container environments |

### Security Plugin Configuration Files (9 files)

Located in `/etc/opensearch/opensearch-security/`:

| File | Purpose | Description |
|------|---------|-------------|
| `config.yml` | Security plugin main config | Authentication/authorization backends (basic auth, LDAP, JWT, etc.) |
| `internal_users.yml` | Internal user database | Admin user definition (REPLACED by entrypoint if custom user specified) |
| `roles.yml` | Role definitions | Pre-defined roles (admin, readall, etc.) |
| `roles_mapping.yml` | User-to-role mappings | Maps users and backend roles to OpenSearch roles |
| `action_groups.yml` | Action group definitions | Groups of permissions for simplified role creation |
| `tenants.yml` | Multi-tenancy configuration | Tenant definitions for dashboard isolation |
| `nodes_dn.yml` | Node distinguished names | Certificate DNs allowed for node-to-node communication |
| `allowlist.yml` | API allowlist | REST API endpoints allowed when security is restricted |
| `audit.yml` | Audit logging configuration | Audit log settings (disabled by default, can be enabled) |

**Configuration Highlights:**

**opensearch.yml:**
- **Cluster:** `axonopsdb-search` (configurable via `OPENSEARCH_CLUSTER_NAME`)
- **Discovery:** `single-node` by default (configurable via `OPENSEARCH_DISCOVERY_TYPE`)
- **Memory Lock:** `bootstrap.memory_lock: true` (requires IPC_LOCK capability)
- **Network:** Binds to `0.0.0.0` (all interfaces)
- **Thread Pool:** `thread_pool.write.queue_size: 10000` (increase for high-write workloads)
- **Security:** AxonOps-branded certificates, demo certificates disabled (`allow_unsafe_democertificates: false`)

**jvm.options:**
- **Heap:** Default 8G (`-Xms8g -Xmx8g`), configurable via `OPENSEARCH_HEAP_SIZE`
- **GC:** Optimized for modern JVMs (JDK 17+)

**log4j2.properties:**
- **Log Levels:** INFO by default, DEBUG can be enabled if needed
- **Retention:** Optimized for container environments with controlled log growth
- **Location:** `/var/log/opensearch/`

**internal_users.yml:**
- **Default:** Contains `admin` user with bcrypt hashed password
- **Custom User:** **REPLACED entirely** if `AXONOPS_SEARCH_USER` is set (only custom user exists)
- **Format:** YAML with bcrypt password hashes

**config.yml:**
- **Authentication:** HTTP Basic auth enabled by default against internal users database
- **Authorization:** Internal role mapping
- **Additional Auth:** LDAP, JWT, Kerberos, client certificates available (disabled by default)

## CI/CD Pipeline

### Workflows

The repository includes comprehensive GitHub Actions workflows:

**Build and Test** (`.github/workflows/axondb-search-build-and-test.yml`)
- **Triggers:** Push/PR to main/development/feature/*/fix/* branches
  - When `axonops/axondb-search/**` changes (excluding `*.md` files)
  - When workflows (`.github/workflows/axondb-search-*.yml`) change
  - When actions (`.github/actions/axondb-search-*/**`) change
- **Tests:** Docker build, version verification, healthcheck, security scanning
- **Runtime:** ~10 minutes

**Production Publish** (`.github/workflows/axondb-search-publish-signed.yml`)
- **Trigger:** Manual workflow dispatch with git tag
- **Process:** Validate → Test → Create Release → Build → Sign → Publish → Verify
- **Registry:** `ghcr.io/axonops/axondb-search`
- **Platforms:** linux/amd64, linux/arm64
- **Signing:** Cosign keyless signing (OIDC)

**Development Publish** (`.github/workflows/axondb-search-development-publish-signed.yml`)
- **Trigger:** Manual workflow dispatch from development branch
- **Registry:** `ghcr.io/axonops/development/axondb-search`
- **Use:** Testing images before production release

### Automated Testing

The CI pipeline includes comprehensive testing:

**Functional Tests:**
- Container build verification (multi-arch)
- Startup banner verification (production vs development)
- Version verification (OpenSearch, Java)
- Healthcheck script tests (startup, liveness, readiness)
- Security initialization verification
- REST API operations with curl
- Environment variable handling (20 variables)
- Certificate verification

**Security Tests:**
- Trivy container vulnerability scanning (CRITICAL and HIGH severity)
- Results uploaded to GitHub Security tab
- Known upstream CVEs documented in `.trivyignore`
- Certificate verification (AxonOps-branded, not demo)

**Composite Actions:**
Located in `.github/actions/axondb-search-*/`:
- `start-and-wait` - Start container and wait for readiness
- `verify-startup-banner` - Verify banner content
- `verify-no-startup-errors` - Check for startup errors
- `verify-versions` - Verify component versions
- `test-healthcheck` - Test all healthcheck modes
- `verify-init-scripts` - Verify security initialization completed
- `test-rest-api` - Test REST API functionality
- `test-all-env-vars` - Test environment variable configuration (20 variables)
- `verify-certificates` - Verify AxonOps certificates (not demo)
- `sign-container` - Cosign signing
- `verify-published-image` - Post-publish verification
- `collect-logs` - Collect container logs
- `determine-latest` - Determine latest tags

### Publishing Process

**Development Release:**
```bash
# Tag on development branch
git checkout development
git tag vdev-axondb-search-1.0.0
git push origin vdev-axondb-search-1.0.0

# Publish to development registry
gh workflow run axondb-search-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=vdev-axondb-search-1.0.0 \
  -f container_version=1.0.0
```

**Production Release:**
```bash
# Tag on main branch
git checkout main
git tag axondb-search-1.0.0
git push origin axondb-search-1.0.0

# Publish to production registry
gh workflow run axondb-search-publish-signed.yml \
  --ref main \
  -f main_git_tag=axondb-search-1.0.0 \
  -f container_version=1.0.0
```

See [RELEASE.md](./RELEASE.md) for complete release process documentation.

## Troubleshooting

### Checking Container Version

View the startup banner to see all component versions:

```bash
docker logs axondb-search | head -30
```

The banner displays:
- Container version and git revision
- OpenSearch, Java, OS versions
- Base image digest (for supply chain verification)
- Runtime environment details

### Initialization Script Logs

Check initialization progress and results:

```bash
# View OpenSearch startup logs
docker logs axondb-search

# Check security initialization status (in persistent volume)
docker exec axondb-search cat /var/lib/opensearch/.axonops/init-security.done

# View internal_users.yml to verify admin user configuration
docker exec axondb-search cat /etc/opensearch/opensearch-security/internal_users.yml

# List AxonOps certificates
docker exec axondb-search ls -la /etc/opensearch/certs/
```

**Semaphore file format:**
```
COMPLETED=2025-12-16T10:45:00Z
RESULT=success
REASON=custom_user_created_prestartup
ADMIN_USER=dbadmin
```

Possible `RESULT` values:
- `success` - Operation completed successfully
- `skipped` - Operation skipped (with REASON field explaining why)
- `failed` - Operation failed (with REASON field explaining why)

### Healthcheck Debugging

Test healthcheck probes manually:

```bash
# Test all three probe types
docker exec axondb-search /usr/local/bin/healthcheck.sh startup
docker exec axondb-search /usr/local/bin/healthcheck.sh liveness
docker exec axondb-search /usr/local/bin/healthcheck.sh readiness

# Check Docker healthcheck status
docker inspect axondb-search --format='{{json .State.Health}}' | jq

# Test REST API manually
docker exec axondb-search curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health
```

### Container Not Starting

**Check logs:**
```bash
docker logs axondb-search
```

**Common issues:**

1. **Insufficient memory:**
   - Default heap is 8G, ensure container has at least 12GB RAM (1.5x heap)
   - Adjust with: `-e OPENSEARCH_HEAP_SIZE=4g`

2. **Port conflicts:**
   - HTTP: 9200
   - Transport: 9300
   - Check with: `netstat -tuln | grep 9200`

3. **Permission issues:**
   - Container runs as `opensearch` user (UID 999)
   - Ensure volume permissions: `chown -R 999:999 /data/opensearch`

4. **vm.max_map_count too low:**
   - Check: `sysctl vm.max_map_count`
   - Set: `sudo sysctl -w vm.max_map_count=262144`
   - Permanent: Add to `/etc/sysctl.conf`

5. **Initialization timeout:**
   - Init script waits up to 10 minutes for OpenSearch
   - Check: `docker exec axondb-search cat /var/lib/opensearch/.axonops/init-security.done`
   - Increase: `-e INIT_TIMEOUT=1200`

**Get OpenSearch logs:**
```bash
docker exec axondb-search cat /var/log/opensearch/axonopsdb-search.log
```

**Verify OpenSearch is running:**
```bash
docker exec axondb-search ps aux | grep opensearch
```

**Test REST API connectivity:**
```bash
# With default credentials
curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health

# With custom credentials
curl -k -u dbadmin:MySecurePassword123 https://localhost:9200/_cluster/health

# Without TLS (if AXONOPS_SEARCH_TLS_ENABLED=false)
curl -u admin:MyS3cur3P@ss2025 http://localhost:9200/_cluster/health
```

## Production Considerations

1. **Persistent Storage**
   - Always use volumes for `/var/lib/opensearch` (data and semaphores)
   - Use volumes for `/var/log/opensearch` (logs)
   - Example: `-v /data/opensearch:/var/lib/opensearch`
   - Use SSD storage for production workloads (high IOPS required)

2. **Resource Allocation**
   - Memory: At least 1.5x heap size (e.g., 12GB for 8GB heap)
   - CPU: 4+ cores recommended
   - Disk: Fast SSD storage with adequate IOPS
   - Heap: Max 32GB (due to JVM compressed pointers optimization)

3. **System Configuration**
   - **vm.max_map_count:** Must be >= 262144 on all nodes
   - **ulimits.nofile:** Set to 65536 (max open file descriptors)
   - **IPC_LOCK capability:** Required for `bootstrap.memory_lock: true`
   - Disable swap for best performance

4. **Networking**
   - Expose required ports: 9200 (HTTP), 9300 (transport)
   - Use proper firewall rules
   - Consider TLS termination at load balancer (set `AXONOPS_SEARCH_TLS_ENABLED=false`)
   - Transport layer SSL remains enabled for node-to-node communication

5. **Security**
   - Use custom admin user (set `AXONOPS_SEARCH_USER` and `AXONOPS_SEARCH_PASSWORD`)
   - **NEVER** use default credentials in production
   - Verify container signatures with Cosign
   - Use digest-based image references for immutability
   - Keep base images updated (automated in UBI)
   - AxonOps-branded certificates are production-grade (RSA 3072, 5-year validity)

6. **Monitoring**
   - Use healthcheck probes for availability monitoring
   - Monitor heap usage via JVM metrics
   - Set up log aggregation for `/var/log/opensearch/`
   - Consider integrating with AxonOps for comprehensive monitoring
   - Monitor cluster health via `/_cluster/health` API

7. **Backup Strategy**
   - Regular snapshots of `/var/lib/opensearch/data`
   - Use OpenSearch snapshot repository API
   - Test restore procedures
   - Document recovery time objectives (RTO)

8. **Cluster Deployment**
   - Use consistent `OPENSEARCH_CLUSTER_NAME` across nodes
   - Configure seed hosts for multi-node discovery
   - Plan for cluster-manager-eligible nodes (minimum 3 for quorum)
   - Use dedicated cluster-manager nodes for large clusters
   - Configure proper shard allocation awareness

For development workflow and testing, see [DEVELOPMENT.md](./DEVELOPMENT.md).

For release process, see [RELEASE.md](./RELEASE.md).
