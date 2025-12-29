# AxonDB Time-Series Database

[![GHCR Package](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axondb-timeseries)

Production-ready Apache Cassandra 5.0.6 container optimized for time-series workloads in AxonOps self-hosted deployments.

## Table of Contents

- [Overview](#overview)
- [Pre-built Docker Images](#pre-built-docker-images)
  - [Available Images](#available-images)
  - [Tagging Strategy](#tagging-strategy)
- [Production Best Practice](#-production-best-practice)
- [Deployment](#deployment)
- [Building Docker Images](#building-docker-images)
- [Environment Variables](#environment-variables)
  - [Cassandra Configuration](#cassandra-configuration)
  - [Initialization Control](#initialization-control)
- [Container Features](#container-features)
  - [Entrypoint Script](#entrypoint-script)
  - [Startup Version Banner](#startup-version-banner)
  - [Healthcheck Probes](#healthcheck-probes)
  - [Automated Initialization (System Keyspaces and Database User)](#automated-initialization-system-keyspaces-and-database-user)
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

AxonDB Time-Series is a production-ready Apache Cassandra container specifically designed for AxonOps self-hosted deployments. This container is optimized for time-series database workloads and is deployed as part of the complete AxonOps stack using AxonOps Helm charts.

**Container Features:**
- **Modern CQL Shell**: [cqlai](https://github.com/axonops/cqlai) v0.0.31 for enhanced database interaction
- **Memory Optimization**: jemalloc for improved memory management
- **Automated Setup**: System keyspace initialization and custom user creation
- **Enterprise Base**: Built on Red Hat UBI 9 minimal for production stability
- **Supply Chain Security**: Digest-pinned base images for immutable builds
- **Production Monitoring**: Integrated healthcheck probes (startup, liveness, readiness)

**Important:** This container is designed exclusively for AxonOps self-hosted deployments. It is deployed and configured via AxonOps Helm charts, which handle all orchestration, networking, and integration with the AxonOps monitoring and management platform. For more information about AxonOps, see [axonops.com](https://axonops.com).

## Pre-built Docker Images

Pre-built images are available from GitHub Container Registry (GHCR). This is the easiest way to get started.

### Available Images

All images are available at: `ghcr.io/axonops/axondb-timeseries`

Browse all available tags: [GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axondb-timeseries)

### Tagging Strategy

Images use a 2-dimensional tagging strategy:

| Tag Pattern | Example | Description | Use Case |
|-------------|---------|-------------|----------|
| `{CASS}-{AXON}` | `5.0.6-1.0.0` | Fully immutable (Cassandra + AxonOps version) | **Production**: Pin exact versions for complete auditability |
| `@sha256:<digest>` | `@sha256:abc123...` | Digest-based (cryptographically immutable) | **Highest Security**: Guaranteed image integrity |
| `{CASS}` | `5.0.6` | Latest AxonOps for this Cassandra version | Track AxonOps updates for specific Cassandra version |
| `latest` | `latest` | Latest across all versions | Quick trials only (NOT for production) |

**Versioning Dimensions:**
- **CASS** - Cassandra version (e.g., 5.0.6)
- **AXON** - AxonOps container version (e.g., 1.0.0, follows SemVer)

**Tagging Examples:**

When `5.0.6-1.0.0` is built (and it's the latest):
- `5.0.6-1.0.0` (immutable - never changes)
- `5.0.6` (floating - retags to newer AxonOps builds)
- `latest` (floating - moves to newer Cassandra versions)

## 💡 Production Best Practice

⚠️ **Using `latest` or floating tags in production is an anti-pattern**. This includes `latest` and `5.0.6` because:
- **No audit trail**: Cannot determine exact version deployed at a given time
- **Unexpected updates**: Container orchestrators may pull new images during restarts
- **Rollback difficulties**: Cannot reliably roll back to previous versions
- **Compliance issues**: Many frameworks require immutable version tracking

👍 **Recommended Deployment Strategies (in order of security):**

1. **🥇 Gold Standard - Digest-Based** (Highest Security)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries@sha256:abc123...
   ```
   - 100% immutable, cryptographically guaranteed
   - Required for regulated environments
   - Verify signature with Cosign (see [Security](#security))

2. **🥈 Immutable Tag** (Production Standard)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
   ```
   - Pinned to specific version (Cassandra 5.0.6 + AxonOps 1.0.0)
   - Easy to read and manage
   - Full audit trail maintained

3. **🥉 Floating Tags** (Development/Testing Only)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries:latest
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
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0

# Check signature exists
cosign tree ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

## Deployment

This container is deployed exclusively through **AxonOps Helm charts** as part of the AxonOps self-hosted stack. The Helm charts handle all configuration, orchestration, and integration with AxonOps monitoring and management components.

For deployment instructions, refer to the AxonOps self-hosted deployment documentation (available when Helm charts are released).

## Building Docker Images

If you prefer to build images yourself instead of using pre-built images:

```bash
cd axonops/axondb-timeseries/5.0.6

# Minimal build (required args only)
docker build \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg CQLAI_VERSION=0.0.31 \
  -t axondb-timeseries:5.0.6-1.0.0 \
  .

# Multi-arch build (amd64 + arm64) using buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg CQLAI_VERSION=0.0.31 \
  -t axondb-timeseries:5.0.6-1.0.0 \
  .
```

**Required build arguments:**
- `CASSANDRA_VERSION` - Cassandra version (e.g., 5.0.6)
- `CQLAI_VERSION` - Version of cqlai to install (see [latest release](https://github.com/axonops/cqlai/releases))

**Custom Configuration Files:**

The container includes customized Cassandra configuration files optimized for container deployments:

| File | Purpose | Key Customizations |
|------|---------|-------------------|
| `cassandra.yaml` | Core Cassandra settings | Production-ready defaults for time-series workloads |
| `jvm-server.options` | JVM options | Memory settings, GC configuration |
| `jvm17-server.options` | JDK 17 specific options | Shenandoah GC, heap settings (default 8G) |
| `cassandra-env.sh` | Cassandra environment | JVM parameters, memory optimization |
| `logback.xml` | Logging configuration | Reduced retention (1GB total, 7 days), debug logging disabled for production |

**logback.xml highlights:**
- **SYSTEMLOG** (system.log): INFO level, 50MB files, 7 day retention, **1GB total cap** (reduced from default 5GB)
- **DEBUGLOG** (debug.log): Disabled by default (can be enabled by uncommenting appender-ref)
- **Audit logging**: Infrastructure present but disabled (can be enabled in cassandra.yaml if needed)
- Optimized for container environments with controlled log growth

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

The container supports 14 environment variables for configuration:

| Variable | Description | Default | Category |
|----------|-------------|---------|----------|
| `CASSANDRA_CLUSTER_NAME` | Cluster name | `axonopsdb-timeseries` | Cassandra |
| `CASSANDRA_NUM_TOKENS` | Number of tokens per node (vnodes) | `8` | Cassandra |
| `CASSANDRA_DC` | Datacenter name | `axonopsdb_dc1` | Cassandra |
| `CASSANDRA_RACK` | Rack name | `rack1` | Cassandra |
| `CASSANDRA_LISTEN_ADDRESS` | IP address to listen on (`auto` = auto-detect) | `auto` | Cassandra |
| `CASSANDRA_BROADCAST_ADDRESS` | IP address to broadcast to other nodes | Same as `CASSANDRA_LISTEN_ADDRESS` | Cassandra |
| `CASSANDRA_RPC_ADDRESS` | CQL native transport address | `0.0.0.0` (all interfaces) | Cassandra |
| `CASSANDRA_BROADCAST_RPC_ADDRESS` | Broadcast RPC address to clients | Same as `CASSANDRA_LISTEN_ADDRESS` | Cassandra |
| `CASSANDRA_SEEDS` | Seed node addresses (comma-separated) | Own IP (for single-node) | Cassandra |
| `CASSANDRA_HEAP_SIZE` | JVM heap size (both -Xms and -Xmx) | `8G` | Cassandra |
| `INIT_SYSTEM_KEYSPACES_AND_ROLES` | Auto-convert system keyspaces and create custom roles | `true` | Initialization |
| `INIT_TIMEOUT` | Timeout in seconds for initialization script to wait for Cassandra | `600` (10 min) | Initialization |
| `AXONOPS_DB_USER` | Create custom superuser with this username (optional) | - | Initialization |
| `AXONOPS_DB_PASSWORD` | Password for custom superuser (required if `AXONOPS_DB_USER` set) | - | Initialization |

### Cassandra Configuration

The first 10 variables configure Cassandra's core behavior. These are processed by the entrypoint script and applied to Cassandra configuration files before Cassandra starts.

**Network Configuration:**
- `CASSANDRA_LISTEN_ADDRESS` - Set to `auto` for automatic IP detection, or specify an IP address
- `CASSANDRA_BROADCAST_ADDRESS` - Defaults to listen address, override for NAT/firewall scenarios
- `CASSANDRA_RPC_ADDRESS` - Set to `0.0.0.0` to listen on all interfaces
- `CASSANDRA_SEEDS` - Comma-separated list for multi-node clusters

**Topology Configuration:**
- `CASSANDRA_DC` and `CASSANDRA_RACK` - Define datacenter and rack for proper replication
- Written to `cassandra-rackdc.properties` and read by `GossipingPropertyFileSnitch`
- Defaults: `axonopsdb_dc1` / `rack1` (override for production deployments)

**Resource Configuration:**
- `CASSANDRA_HEAP_SIZE` - Controls JVM heap (both -Xms and -Xmx set to same value)

**Example:**
```bash
docker run -d --name axondb \
  -e CASSANDRA_CLUSTER_NAME=production-cluster \
  -e CASSANDRA_DC=us-east-1 \
  -e CASSANDRA_RACK=1a \
  -e CASSANDRA_SEEDS=10.0.1.10,10.0.1.11,10.0.1.12 \
  -e CASSANDRA_HEAP_SIZE=16G \
  -p 9042:9042 \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

### Initialization Control

The last 4 variables (`INIT_SYSTEM_KEYSPACES_AND_ROLES`, `INIT_TIMEOUT`, `AXONOPS_DB_USER`, `AXONOPS_DB_PASSWORD`) control automatic initialization behavior that occurs after Cassandra starts.

**System Keyspace Initialization:**

On first boot of a fresh single-node cluster, the container automatically converts system keyspaces from `SimpleStrategy` to `NetworkTopologyStrategy` for production readiness.

**Timeout Configuration:**
The initialization script waits up to `INIT_TIMEOUT` seconds (default: 600 = 10 minutes) for Cassandra to become ready. If your environment has slow startup (large heap, slow disks), increase this value:

```bash
docker run -d --name axondb \
  -e INIT_TIMEOUT=1200 \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

**The initialization process:**

- Only runs on single-node clusters with default `cassandra/cassandra` credentials
- Detects datacenter name from running Cassandra instance
- Converts: `system_auth`, `system_distributed`, `system_traces`
- Writes semaphore files for healthcheck coordination
- Skips if already converted or if multi-node cluster detected

To disable: `INIT_SYSTEM_KEYSPACES_AND_ROLES=false`

**Custom Database User:**

Automatically create a custom superuser and disable the default `cassandra` user:

```bash
docker run -d --name axondb \
  -e AXONOPS_DB_USER=admin \
  -e AXONOPS_DB_PASSWORD=SecurePassword123 \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  -p 9042:9042 \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0

# Connect with new credentials (after ~2 minutes for initialization)
docker exec -it axondb cqlai -u admin -p SecurePassword123
```

**Important:**
- Custom user creation only works on fresh clusters with default credentials
- Default `cassandra` user is disabled after custom user is created (sets `can_login=false`)
- User creation runs after system keyspace initialization completes
- Both operations are handled by the same script: `init-system-keyspaces.sh`
- Progress logs: `/var/log/cassandra/init-system-keyspaces.log`
- Completion markers (in persistent volume):
  - `/var/lib/cassandra/.axonops/init-system-keyspaces.done`
  - `/var/lib/cassandra/.axonops/init-db-user.done`

## Container Features

### Entrypoint Script

The entrypoint script (`/usr/local/bin/docker-entrypoint.sh`) is the main orchestrator that configures Cassandra and manages container startup. It runs as PID 1 via [tini](https://github.com/krallin/tini) and performs critical initialization before starting Cassandra.

#### tini - A Minimal Init System

The container uses **tini** as its init system (PID 1). Tini is a minimal init system specifically designed for containers that:

- **Handles signals properly** - Forwards signals (SIGTERM, SIGINT) to child processes for graceful shutdown
- **Reaps zombie processes** - Cleans up terminated child processes that would otherwise accumulate
- **Extremely lightweight** - Single static binary (~10KB), minimal overhead
- **Industry standard** - Used by Docker as the default init when `--init` flag is specified

The Dockerfile sets tini as the entrypoint wrapper:
```dockerfile
ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["cassandra", "-f"]
```

This means the actual process tree is:
```
tini (PID 1)
  └─► docker-entrypoint.sh
       └─► cassandra -f (after exec)
```

After `exec cassandra -f`, Cassandra replaces the shell script but tini remains as PID 1, ensuring proper signal handling for the entire container.

**Learn more:** [github.com/krallin/tini](https://github.com/krallin/tini)

#### What It Does

**1. Displays Startup Banner**
- Sources build metadata from `/etc/axonops/build-info.txt`
- Prints comprehensive version information (Cassandra, Java, cqlai, jemalloc, OS)
- Shows runtime environment (Kubernetes detection, hostname)
- Displays supply chain security info (base image digest)

**2. Configures Network and IP Addresses**
- Auto-detects container IP address if `CASSANDRA_LISTEN_ADDRESS=auto`
- Sets broadcast addresses based on listen address
- Configures RPC (CQL) addresses for client connections
- Ensures proper seed node configuration

**3. Applies Environment Variables to Cassandra Configuration**
- Processes all `CASSANDRA_*` environment variables
- Updates `cassandra.yaml` with user-provided settings
- Modifies `cassandra-rackdc.properties` for DC/Rack configuration
- Adjusts JVM heap size in `jvm17-server.options`
- Uses `GossipingPropertyFileSnitch` (pre-configured in cassandra.yaml) which reads DC/Rack from cassandra-rackdc.properties

**4. Enables jemalloc Memory Optimization**
- Sets `LD_PRELOAD=/usr/lib64/libjemalloc.so.2`
- Improves memory allocation performance
- Safe fallback if jemalloc not found

**5. Launches Background Initialization**
- Starts `init-system-keyspaces.sh` in background (non-blocking)
- Or writes skip semaphores if `INIT_SYSTEM_KEYSPACES_AND_ROLES=false`
- Allows Cassandra to start immediately while init waits for readiness

**6. Starts Cassandra**
- Executes `cassandra -f` (foreground mode)
- Replaces entrypoint process (becomes PID 1)
- Cassandra takes over as main container process

#### Execution Order

```
entrypoint.sh (PID 1 via tini)
  │
  ├─► 1. Print startup banner
  │
  ├─► 2. Set default environment variables
  │      (CASSANDRA_CLUSTER_NAME, CASSANDRA_DC, CASSANDRA_RACK, etc.)
  │
  ├─► 3. Resolve IP addresses
  │      (auto-detect if CASSANDRA_LISTEN_ADDRESS=auto)
  │
  ├─► 4. Apply environment variables to cassandra.yaml
  │      (cluster_name, num_tokens, listen_address, rpc_address, etc.)
  │
  ├─► 5. Apply DC/Rack to cassandra-rackdc.properties
  │
  ├─► 6. Apply heap size to jvm17-server.options
  │
  ├─► 7. Enable jemalloc (set LD_PRELOAD)
  │
  ├─► 8. Launch init-system-keyspaces.sh in background (&)
  │      - Non-blocking, runs in parallel with Cassandra
  │
  └─► 9. exec cassandra -f
         - Replaces entrypoint process
         - Cassandra becomes PID 1
         - Container runs Cassandra from this point
```

#### Configuration Files Modified

The entrypoint modifies these Cassandra configuration files based on environment variables:

| File | What's Modified | Environment Variables |
|------|----------------|----------------------|
| `/etc/cassandra/cassandra.yaml` | Core Cassandra settings | `CASSANDRA_CLUSTER_NAME`, `CASSANDRA_NUM_TOKENS`, `CASSANDRA_LISTEN_ADDRESS`, `CASSANDRA_RPC_ADDRESS`, `CASSANDRA_BROADCAST_ADDRESS`, `CASSANDRA_BROADCAST_RPC_ADDRESS`, `CASSANDRA_SEEDS` |
| `/etc/cassandra/cassandra-rackdc.properties` | Datacenter and rack topology | `CASSANDRA_DC` (default: `axonopsdb_dc1`), `CASSANDRA_RACK` (default: `rack1`) |
| `/etc/cassandra/jvm17-server.options` | JVM heap memory settings | `CASSANDRA_HEAP_SIZE` |

**Note:** The container uses `GossipingPropertyFileSnitch` (pre-configured in cassandra.yaml), which reads DC/Rack topology from `cassandra-rackdc.properties`. The DC and Rack values default to `axonopsdb_dc1` and `rack1` if not explicitly set.

#### Key Design Decisions

**Why exec cassandra -f?**
- Using `exec` replaces the shell process with Cassandra
- Cassandra becomes PID 1, receives signals directly
- Ensures clean shutdown when container stops
- No orphaned shell process consuming resources

**Why background initialization?**
- Init script needs Cassandra running (requires CQL access)
- Starting Cassandra first allows init to wait for readiness
- Non-blocking startup - container doesn't hang during init
- Healthcheck startup probe enforces completion before traffic routing

**Why tini as the init system?**
- **Signal forwarding** - Ensures SIGTERM/SIGINT reach Cassandra for graceful shutdown
- **Zombie reaping** - Cleans up terminated child processes (important for background init script)
- **Container best practice** - Prevents issues when container engine sends stop signals
- **Minimal overhead** - Tiny static binary (~10KB) with no dependencies
- **Industry standard** - Same init system Docker uses with `--init` flag
- Without tini, shell scripts (PID 1) don't forward signals properly, causing forced kills

**More info:** [Why you need an init system](https://github.com/krallin/tini#why-tini) in containers

### Startup Version Banner

All containers display comprehensive version information on startup:

```
================================================================================
AxonOps AxonDB Time-Series (Apache Cassandra 5.0.6)
Image: ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
Built: 2025-12-13T10:30:00Z
Release: https://github.com/axonops/axonops-containers/releases/tag/axondb-timeseries-1.0.0
Built by: GitHub Actions
================================================================================

Component Versions:
  Cassandra:          5.0.6
  Java:               OpenJDK Runtime Environment (Red_Hat-17.0.17.0.10-1)
  cqlai:              v0.0.31
  jemalloc:           jemalloc-5.2.1-2.el9.x86_64
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI - Universal Base Image, freely redistributable)
  Platform:           x86_64

Supply Chain Security:
  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest
  Base image digest:  sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2

Runtime Environment:
  Hostname:           axondb-node-1
  Kubernetes:         No

================================================================================
Starting Cassandra...
================================================================================
```

**View the banner:**
```bash
docker logs axondb | head -30
```

### Healthcheck Probes

The container includes an optimized healthcheck script supporting three probe types, designed for minimal overhead while ensuring reliability:

**1. Startup Probe** (`healthcheck.sh startup`)
- **Waits for initialization scripts to complete** (critical for async init pattern)
- Checks for semaphore files in persistent storage:
  - `/var/lib/cassandra/.axonops/init-system-keyspaces.done` (must exist)
  - `/var/lib/cassandra/.axonops/init-db-user.done` (must exist)
- **Validates RESULT field** - Fails if either semaphore has `RESULT=failed`
- Verifies Cassandra process is running (`pgrep -f cassandra`)
- Checks CQL port (9042) is listening (TCP check via `nc`)
- **Lightweight** - No nodetool calls, just process/port checks
- **Blocks pod "Started" status until init completes successfully**
- Use for: Kubernetes `startupProbe` (ensures init finishes before traffic routing)

**2. Liveness Probe** (`healthcheck.sh liveness`)
- **Ultra-lightweight** - Designed to run frequently (every 10 seconds)
- Checks if Cassandra process is running (`pgrep -f cassandra`)
- Checks CQL port (9042) is listening (TCP check via `nc`)
- **No nodetool calls** - Minimal overhead, very fast execution
- Use for: Kubernetes `livenessProbe` (detecting if Cassandra process has crashed)

**3. Readiness Probe** (`healthcheck.sh readiness`)
- Checks CQL port (9042) is listening (TCP check via `nc`)
- Runs `nodetool info` to verify Cassandra internal state
- Verifies "Native Transport active: true" in output
- Verifies "Gossip active: true" in output
- **More thorough** than liveness - ensures Cassandra is fully operational
- Use for: Kubernetes `readinessProbe` (load balancer health checks, traffic routing)

**Docker healthcheck:**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect axondb --format='{{json .State.Health}}' | jq
```

**Manual healthcheck testing:**
```bash
# Test startup probe
docker exec axondb /usr/local/bin/healthcheck.sh startup

# Test liveness probe
docker exec axondb /usr/local/bin/healthcheck.sh liveness

# Test readiness probe
docker exec axondb /usr/local/bin/healthcheck.sh readiness
```

**Note:** Healthcheck probe configuration is handled automatically by AxonOps Helm charts. The above modes are available for custom deployments if needed.

### Automated Initialization (System Keyspaces and Database User)

The container performs automated initialization on first boot, handling both system keyspace conversion and optional custom database user creation. Both operations are performed by a single background script (`init-system-keyspaces.sh`) that runs after Cassandra starts.

#### How It Works (Execution Flow)

The initialization uses an **asynchronous background process** coordinated by **semaphore files** to ensure proper ordering:

```
1. entrypoint.sh starts (PID 1 via tini)
   │
   ├─► 2. Launches init-system-keyspaces.sh in background (&)
   │      - Does NOT block Cassandra startup
   │      - Runs in parallel with Cassandra
   │
   └─► 3. Starts Cassandra (exec cassandra -f)
        │
        ├─► Cassandra starts and begins accepting connections
        │
        ├─► init-system-keyspaces.sh waits for Cassandra to be ready
        │   - Waits for CQL port (9042) to be listening
        │   - Waits for native transport + gossip active
        │   - Converts system keyspaces to NetworkTopologyStrategy
        │   - Creates custom database user (if AXONOPS_DB_USER set)
        │   - Writes semaphore files to persistent storage:
        │       /var/lib/cassandra/.axonops/init-system-keyspaces.done
        │       /var/lib/cassandra/.axonops/init-db-user.done
        │
        └─► healthcheck.sh (startup probe) checks for semaphores
            - Blocks until BOTH semaphore files exist
            - Only then marks container as "Started"
            - Kubernetes won't route traffic until this succeeds
```

**Why This Pattern is Safe:**

1. **Cassandra must run first** - Init script needs CQL access, so Cassandra must be running
2. **Background execution** - Init doesn't block Cassandra startup
3. **Semaphore coordination** - Healthcheck waits for init completion before marking ready
4. **Kubernetes enforcement** - Pod not marked "Started" until semaphores exist
5. **Persistent semaphores** - Stored in `/var/lib/cassandra` (volume), prevents re-init on restarts

#### Phase 1: System Keyspace Conversion

The first phase converts system keyspaces from `SimpleStrategy` to `NetworkTopologyStrategy` for production readiness.

**What it does:**
1. Waits for Cassandra to be ready (CQL port listening, native transport active)
2. Verifies this is a single-node cluster with default credentials
3. Detects datacenter name from running Cassandra instance
4. Converts `system_auth`, `system_distributed`, `system_traces` to `NetworkTopologyStrategy`
5. Writes completion semaphore to persistent storage: `/var/lib/cassandra/.axonops/init-system-keyspaces.done`

**Note:** Repair is NOT run because this is a single-node deployment (repair is only meaningful with multiple replicas).

**Safety checks:**
- Only runs on single-node clusters (skips multi-node and writes skip semaphore)
- Only runs if replication factor is 1 (skips if already customized and writes skip semaphore)
- Only runs if using `SimpleStrategy` (skips if already `NetworkTopologyStrategy` and writes skip semaphore)
- Requires default `cassandra/cassandra` credentials
- **Semaphore is ALWAYS written** (success or skipped with reason)

#### Phase 2: Custom Database User Creation (Optional)

The second phase creates a custom superuser and disables the default `cassandra` user (only if requested via environment variables).

**What it does:**
1. Waits for system keyspace initialization to complete
2. Creates new superuser with specified username and password
3. Grants full superuser permissions
4. Tests authentication with new user
5. Disables default `cassandra` user (sets `can_login=false`)
6. Writes completion semaphore: `/var/lib/cassandra/.axonops/init-db-user.done`

**Example:**
```bash
docker run -d --name axondb \
  -e AXONOPS_DB_USER=dbadmin \
  -e AXONOPS_DB_PASSWORD=MySecurePassword123! \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0

# Wait for initialization (~2 minutes)
docker logs -f axondb

# Connect with new credentials
docker exec -it axondb cqlai -u dbadmin -p MySecurePassword123!
```

**Safety checks:**
- Only runs if both `AXONOPS_DB_USER` and `AXONOPS_DB_PASSWORD` are set
- Only runs on fresh clusters with default credentials
- Tests new user authentication before disabling default user
- Rolls back user creation if authentication test fails
- **Semaphore is ALWAYS written** (success, skipped, or failed with reason)

#### Control and Disable

**Disable all initialization:**
```bash
docker run -d --name axondb \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

When disabled, semaphore files are written immediately with `RESULT=skipped` to allow the healthcheck to proceed.

#### Semaphore Files

The initialization process uses semaphore files to coordinate between the background init script and the healthcheck startup probe.

**Location:** `/var/lib/cassandra/.axonops/`

Semaphore files are stored in the Cassandra data directory (not `/etc`) because:
- `/var/lib/cassandra` is typically configured as a persistent volume in Kubernetes
- When persistent, semaphores survive container/pod restarts
- Prevents re-initialization on pod restarts (e.g., during rolling updates)
- Allows healthcheck to immediately pass after restart without re-running init

**Important:** Configure `/var/lib/cassandra` as a persistent volume (PersistentVolumeClaim) in your Kubernetes deployment. AxonOps Helm charts handle this automatically.

**Files Created:**
- `init-system-keyspaces.done` - System keyspace conversion status
- `init-db-user.done` - Custom user creation status

**File Format:**
```
COMPLETED=2025-12-14T09:32:17Z
RESULT=success
REASON=initialized_to_nts
```

**RESULT values for init-system-keyspaces.done:**
- `success` - System keyspaces converted successfully
  - `initialized_to_nts` - Converted to NetworkTopologyStrategy
- `skipped` - Conversion skipped safely (with REASON explaining why)
  - `multi_node_cluster` - Multi-node cluster detected (can't safely init)
  - `already_nts` - Already using NetworkTopologyStrategy (already done)
  - `custom_rf` - Replication factor != 1 (already customized by user)
  - `disabled_by_env_var` - INIT_SYSTEM_KEYSPACES_AND_ROLES=false (user disabled)
- `failed` - Initialization failed (with REASON) - **Init script exits with code 1**
  - `cql_port_timeout` - CQL port didn't open within timeout (default: 10 min, configurable via `INIT_TIMEOUT`)
  - `native_transport_timeout` - Native transport didn't activate within timeout
  - `cql_connectivity_failed` - Cannot connect with cassandra/cassandra credentials
  - `dc_detection_failed` - Could not detect datacenter name from nodetool or cassandra-rackdc.properties

**When failures occur:**
- `cql_port_timeout` / `native_transport_timeout` - Cassandra not starting properly (check logs)
- `cql_connectivity_failed` - Default credentials changed or authentication misconfigured
- `dc_detection_failed` - Cassandra not reporting datacenter name (configuration issue)

**Timeout Configuration:**
- Default timeout: 600 seconds (10 minutes)
- Configurable via `INIT_TIMEOUT` environment variable
- Example: `-e INIT_TIMEOUT=1200` for 20 minutes if Cassandra startup is slow

**RESULT values for init-db-user.done:**
- `success` - Custom user created successfully
  - `user_initialized` - User created and cassandra user disabled
  - `user_created_cassandra_disable_failed` - User created but failed to disable cassandra user (non-fatal, container continues)
- `skipped` - User creation skipped (with REASON)
  - `no_custom_user_requested` - AXONOPS_DB_USER not set
  - `user_already_exists` - Custom user already exists
  - `init_disabled` - INIT_SYSTEM_KEYSPACES_AND_ROLES=false
- `failed` - User creation failed (with REASON) - **Init script exits with code 1**
  - `create_user_failed` - Failed to create user (CQL CREATE ROLE failed)
  - `new_user_auth_failed` - User created but authentication test failed

**When failures occur:**
- `create_user_failed` - Can happen if:
  - CQL connection fails during user creation
  - Invalid username/password format
  - Cassandra internal error during role creation
- `new_user_auth_failed` - Can happen if:
  - User created but authentication system is misconfigured
  - Password not set correctly in system_auth
  - CQL authentication protocol issue

**Important:** When `RESULT=failed` is written, the init script exits with code 1 (failure), and the healthcheck startup probe will fail, preventing the container from being marked "Started" in Kubernetes.

**Guarantee:** Both semaphore files are **ALWAYS** written in all code paths. The healthcheck startup probe:
1. Requires both semaphore files to exist
2. Checks the RESULT field in each semaphore
3. **Fails the startup probe if either RESULT=failed**
4. Passes only if both are RESULT=success or RESULT=skipped

This ensures the container won't be marked "Started" if initialization failed.

#### Initialization Logs

Check initialization progress and results:

```bash
# View complete initialization log (both system keyspaces and user creation)
docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log

# Check system keyspace conversion status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-system-keyspaces.done

# Check custom user creation status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-db-user.done
```

## CI/CD Pipeline

### Workflows

The repository includes comprehensive GitHub Actions workflows:

**Build and Test** (`.github/workflows/axondb-timeseries-build-and-test.yml`)
- **Triggers:** Push/PR to main/development/feature/*/fix/* branches
  - When `axonops/axondb-timeseries/**` changes (excluding `*.md` files)
  - When workflows (`.github/workflows/axondb-timeseries-*.yml`) change
  - When actions (`.github/actions/axondb-timeseries-*/**`) change
- **Tests:** Docker build, version verification, healthcheck, cqlai, cqlsh, security scanning
- **Runtime:** ~10 minutes

**Production Publish** (`.github/workflows/axondb-timeseries-publish-signed.yml`)
- **Trigger:** Manual workflow dispatch with git tag
- **Process:** Validate → Test → Create Release → Build → Sign → Publish → Verify
- **Registry:** `ghcr.io/axonops/axondb-timeseries`
- **Platforms:** linux/amd64, linux/arm64
- **Signing:** Cosign keyless signing (OIDC)

**Development Publish** (`.github/workflows/axondb-timeseries-development-publish-signed.yml`)
- **Trigger:** Manual workflow dispatch from development branch
- **Registry:** `ghcr.io/axonops/development/axondb-timeseries`
- **Use:** Testing images before production release

### Automated Testing

The CI pipeline includes comprehensive testing:

**Functional Tests:**
- Container build verification (multi-arch)
- Startup banner verification (production vs development)
- Version verification (jemalloc, Cassandra, Java, cqlai)
- Healthcheck script tests (startup, liveness, readiness)
- System keyspace initialization verification
- CQL operations with cqlai
- CQL operations with cqlsh
- Environment variable handling

**Security Tests:**
- Trivy container vulnerability scanning (CRITICAL and HIGH severity)
- Results uploaded to GitHub Security tab
- Known upstream CVEs documented in `.trivyignore`

**Composite Actions (14 actions):**
Located in `.github/actions/axondb-timeseries-*/`:
- `start-and-wait` - Start container and wait for readiness
- `verify-startup-banner` - Verify banner content
- `verify-no-startup-errors` - Check for startup errors
- `verify-versions` - Verify component versions
- `test-healthcheck` - Test all healthcheck modes
- `verify-init-scripts` - Verify initialization completed
- `test-cqlai` - Test cqlai functionality
- `test-cqlsh` - Test cqlsh functionality
- `test-all-env-vars` - Test environment variable configuration (10 Cassandra + 4 initialization = 14 total)
- `test-dc-detection` - Test datacenter detection
- `sign-container` - Cosign signing
- `verify-published-image` - Post-publish verification
- `collect-logs` - Collect container logs
- `determine-latest` - Determine latest tags

### Publishing Process

**Development Release:**
```bash
# Tag on development branch
git checkout development
git tag vdev-axondb-timeseries-1.0.0
git push origin vdev-axondb-timeseries-1.0.0

# Publish to development registry
gh workflow run axondb-timeseries-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=vdev-axondb-timeseries-1.0.0 \
  -f container_version=1.0.0
```

**Production Release:**
```bash
# Tag on main branch
git checkout main
git tag axondb-timeseries-1.0.0
git push origin axondb-timeseries-1.0.0

# Publish to production registry
gh workflow run axondb-timeseries-publish-signed.yml \
  --ref main \
  -f main_git_tag=axondb-timeseries-1.0.0 \
  -f container_version=1.0.0
```

See [RELEASE.md](./RELEASE.md) for complete release process documentation.

## Troubleshooting

### Checking Container Version

View the startup banner to see all component versions:

```bash
docker logs axondb | head -30
```

The banner displays:
- Container version and git revision
- Cassandra, Java, cqlai, jemalloc versions
- Base image digest (for supply chain verification)
- Runtime environment details

### Initialization Script Logs

Check initialization progress and results:

```bash
# View init script output
docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log

# Check system keyspace init status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-system-keyspaces.done

# Check custom user creation status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-db-user.done
```

**Semaphore file format:**
```
COMPLETED=2025-12-13T10:45:00Z
RESULT=success
```

Possible `RESULT` values:
- `success` - Operation completed successfully
- `skipped` - Operation skipped (with REASON field explaining why)

### Healthcheck Debugging

Test healthcheck probes manually:

```bash
# Test all three probe types
docker exec axondb /usr/local/bin/healthcheck.sh startup
docker exec axondb /usr/local/bin/healthcheck.sh liveness
docker exec axondb /usr/local/bin/healthcheck.sh readiness

# Check Docker healthcheck status
docker inspect axondb --format='{{json .State.Health}}' | jq

# View healthcheck logs
docker exec axondb cat /var/log/cassandra/system.log | grep healthcheck
```

### Container Not Starting

**Check logs:**
```bash
docker logs axondb
```

**Common issues:**

1. **Insufficient memory:**
   - Default heap is 8G, ensure container has at least 12GB RAM
   - Adjust with: `-e CASSANDRA_HEAP_SIZE=4G`

2. **Port conflicts:**
   - CQL: 9042
   - JMX: 7199
   - Check with: `netstat -tuln | grep 9042`

3. **Permission issues:**
   - Container runs as `cassandra` user (UID 999)
   - Ensure volume permissions: `chown -R 999:999 /data/cassandra`

4. **Initialization timeout:**
   - Init scripts wait up to 10 minutes for Cassandra
   - Check: `docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log`

**Get Cassandra logs:**
```bash
docker exec axondb cat /var/log/cassandra/system.log
```

**Verify Cassandra is running:**
```bash
docker exec axondb nodetool status
```

## Production Considerations

1. **Persistent Storage**
   - Always use volumes for `/var/lib/cassandra` (data)
   - Use volumes for `/var/log/cassandra` (logs)
   - Example: `-v /data/cassandra:/var/lib/cassandra`

2. **Resource Allocation**
   - Memory: At least 1.5x heap size (e.g., 12GB for 8GB heap)
   - CPU: 4+ cores recommended
   - Disk: SSD storage for production workloads

3. **Networking**
   - Expose required ports: 9042 (CQL), 7199 (JMX), 7000 (inter-node)
   - Use proper firewall rules
   - Consider TLS for inter-node and client communication

4. **Security**
   - Use custom database user (set `AXONOPS_DB_USER` and `AXONOPS_DB_PASSWORD`)
   - Verify container signatures with Cosign
   - Use digest-based image references for immutability
   - Keep base images updated (automated in UBI)

5. **Monitoring**
   - Use healthcheck probes for availability monitoring
   - Monitor heap usage via JMX
   - Set up log aggregation for `/var/log/cassandra/`
   - Consider integrating with AxonOps for comprehensive monitoring

6. **Backup and Restore**

   This container includes integrated backup/restore functionality designed for single-node deployments.

   **Quick Start:**
   ```bash
   # Enable scheduled backups (every 6 hours, keep 168 hours / 7 days)
   docker run -d \
     -v /backup:/backup \
     -e BACKUP_SCHEDULE="0 */6 * * *" \
     -e BACKUP_RETENTION_HOURS=168 \
     axondb-timeseries:latest

   # Restore from backup
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     axondb-timeseries:latest
   ```

   **Key Features:**
   - Snapshot-based backups with hardlink deduplication (76% space savings)
   - Kubernetes-compatible (non-blocking restore, startup probe safe)
   - Automatic retention with async deletion
   - `.axonops` semaphore preservation (prevents re-initialization on restore)
   - IP address change handling
   - Log rotation with compression

   **Configuration:**

   | Variable | Required | Default | Description |
   |----------|----------|---------|-------------|
   | `BACKUP_SCHEDULE` | No | - | Cron expression (e.g., `0 */6 * * *` for every 6 hours) |
   | `BACKUP_RETENTION_HOURS` | If schedule set | - | Hours to keep backups (e.g., `168` for 7 days) |
   | `BACKUP_MINIMUM_RETENTION_COUNT` | No | `1` | Always keep at least N backups |
   | `BACKUP_USE_HARDLINKS` | No | `true` | Use hardlink deduplication |
   | `BACKUP_CALCULATE_STATS` | No | `false` | Calculate space savings (expensive) |
   | `BACKUP_RSYNC_RETRIES` | No | `3` | Number of rsync retries |
   | `BACKUP_RSYNC_TIMEOUT_MINUTES` | No | `120` | rsync timeout (large datasets) |
   | `RESTORE_FROM_BACKUP` | No | - | Backup name or `latest` |
   | `RESTORE_ENABLED` | No | `false` | Enable restore without backup name |
   | `RESTORE_RESET_CREDENTIALS` | No | `false` | Delete system_auth on restore (reset to cassandra/cassandra) |
   | `RSYNC_BWLIMIT_KB` | No | - | Bandwidth limit for backups in KB/s |
   | `ENABLE_SEMAPHORE_MONITOR` | No | `false` | Monitor backup/restore state |

   **Kubernetes Example:**
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: axondb
   spec:
     containers:
     - name: cassandra
       image: axondb-timeseries:latest
       env:
       - name: BACKUP_SCHEDULE
         value: "0 */6 * * *"
       - name: BACKUP_RETENTION_HOURS
         value: "168"
       volumeMounts:
       - name: data
         mountPath: /var/lib/cassandra
       - name: backup
         mountPath: /backup
     volumes:
     - name: data
       persistentVolumeClaim:
         claimName: cassandra-data
     - name: backup
       persistentVolumeClaim:
         claimName: cassandra-backup
   ```

   **Restore from Backup (Pod Recreation):**
   ```yaml
   # After pod deletion, restore from backup on new pod
   env:
   - name: RESTORE_FROM_BACKUP
     value: "latest"  # or specific: "backup-20251226-120000"
   ```

   **Important Notes:**
   - **Single-node only**: Backups are designed for single-node clusters
   - **Hardlinks are local**: When copying backups to remote storage (S3, NFS), hardlinks become independent files (full copy)
   - **`.axonops` preservation**: Init semaphores are backed up and restored to prevent re-initialization
   - **Non-blocking restore**: Restore runs in background, container starts normally (K8s compatible)
   - **Credentials preserved**: Custom credentials from backup are restored automatically (unless `RESTORE_RESET_CREDENTIALS=true`)
   - **Credential reset** (`RESTORE_RESET_CREDENTIALS=true`): Deletes all users/roles from backup
     - Resets to cassandra/cassandra (custom user auto-created if AXONOPS_DB_USER set)
     - All permissions and grants from backup are lost
     - Use for prod → dev restores where credential reset is desired

   **Backup Location:**
   - Mount `/backup` volume for persistence
   - Backups stored as: `/backup/data_backup-YYYYMMDD-HHMMSS/`
   - Includes schema dump (`schema.cql`) and data snapshots

   **Restore Examples:**
   ```bash
   # Restore latest backup
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="latest" \
     axondb-timeseries:latest

   # Restore specific backup
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     axondb-timeseries:latest

   # List available backups
   ls -1dt /backup/data_backup-* | head -10

   # Restore with credential reset (prod → dev)
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     -e RESTORE_RESET_CREDENTIALS=true \
     axondb-timeseries:latest
   # After restore: credentials are cassandra/cassandra

   # Restore with credential reset + new custom user
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     -e RESTORE_RESET_CREDENTIALS=true \
     -e AXONOPS_DB_USER=devuser \
     -e AXONOPS_DB_PASSWORD=devpass123 \
     axondb-timeseries:latest
   # After restore: credentials are devuser/devpass123 (auto-created)
   ```

   **Monitoring Backups:**
   ```bash
   # Enable semaphore monitor (logs backup/restore state every 60s)
   docker run -d \
     -e BACKUP_SCHEDULE="0 */6 * * *" \
     -e BACKUP_RETENTION_HOURS=168 \
     -e ENABLE_SEMAPHORE_MONITOR=true \
     axondb-timeseries:latest

   # Check backup logs
   docker exec axondb cat /var/log/cassandra/backup-cron.log
   docker exec axondb cat /var/log/cassandra/retention-cleanup.log

   # Check restore logs
   docker exec axondb cat /var/log/cassandra/restore.log
   ```

   **Troubleshooting:**

   | Issue | Check | Solution |
   |-------|-------|----------|
   | Backups not created | `cat /var/log/cassandra/backup-scheduler.log` | Verify BACKUP_SCHEDULE is valid cron |
   | Retention not working | `cat /var/log/cassandra/retention-cleanup.log` | Check BACKUP_RETENTION_HOURS is set |
   | Restore fails | `cat /var/log/cassandra/restore.log` | Verify backup exists: `ls /backup/data_backup-*` |
   | Init runs on restore | `cat /var/lib/cassandra/.axonops/init-*.done` | Verify .axonops in backup |
   | Lock errors | `cat /tmp/axonops-backup.lock` | Wait for previous backup to complete |

   For detailed testing, see [tests/README.md](./5.0.6/tests/README.md).

7. **Cluster Deployment**
   - Use consistent `CASSANDRA_DC` and `CASSANDRA_RACK` across nodes
   - Configure `CASSANDRA_SEEDS` with multiple seed nodes
   - Set `CASSANDRA_CLUSTER_NAME` consistently
   - Plan for multi-datacenter deployments if needed

For development workflow and testing, see [DEVELOPMENT.md](./DEVELOPMENT.md).

For release process, see [RELEASE.md](./RELEASE.md).
