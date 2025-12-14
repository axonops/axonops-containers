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
  - [Automated System Keyspace Initialization](#automated-system-keyspace-initialization)
  - [Custom Database User Creation](#custom-database-user-creation)
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

### Cassandra Configuration

Configure Cassandra behavior through environment variables (10 configurable variables):

| Variable | Description | Default |
|----------|-------------|---------|
| `CASSANDRA_CLUSTER_NAME` | Cluster name | `axonopsdb-timeseries` |
| `CASSANDRA_NUM_TOKENS` | Number of tokens per node (vnodes) | `8` |
| `CASSANDRA_DC` | Datacenter name | `axonopsdb_dc1` |
| `CASSANDRA_RACK` | Rack name | `rack1` |
| `CASSANDRA_LISTEN_ADDRESS` | IP address to listen on (`auto` = auto-detect) | `auto` |
| `CASSANDRA_BROADCAST_ADDRESS` | IP address to broadcast to other nodes | Same as `CASSANDRA_LISTEN_ADDRESS` |
| `CASSANDRA_RPC_ADDRESS` | CQL native transport address | `0.0.0.0` (all interfaces) |
| `CASSANDRA_BROADCAST_RPC_ADDRESS` | Broadcast RPC address to clients | Same as `CASSANDRA_LISTEN_ADDRESS` |
| `CASSANDRA_SEEDS` | Seed node addresses (comma-separated) | Own IP (for single-node) |
| `CASSANDRA_HEAP_SIZE` | JVM heap size (both -Xms and -Xmx) | `8G` |

**Note:** The endpoint snitch is automatically set to `GossipingPropertyFileSnitch` when `CASSANDRA_DC` or `CASSANDRA_RACK` are configured (recommended for all deployments). For custom snitch configuration, modify `cassandra.yaml` directly in a derived container.

**Example with custom configuration:**

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

Control automatic initialization behavior:

| Variable | Description | Default |
|----------|-------------|---------|
| `INIT_SYSTEM_KEYSPACES` | Auto-convert system keyspaces to NetworkTopologyStrategy | `true` |
| `AXONOPS_DB_USER` | Create custom superuser with this username (optional) | - |
| `AXONOPS_DB_PASSWORD` | Password for custom superuser (required if `AXONOPS_DB_USER` set) | - |

**System Keyspace Initialization:**

On first boot of a fresh single-node cluster, the container automatically converts system keyspaces from `SimpleStrategy` to `NetworkTopologyStrategy` for production readiness. This process:

- Only runs on single-node clusters with default `cassandra/cassandra` credentials
- Detects datacenter name from running Cassandra instance
- Converts: `system_auth`, `system_distributed`, `system_traces`
- Writes semaphore files for healthcheck coordination
- Skips if already converted or if multi-node cluster detected

To disable: `INIT_SYSTEM_KEYSPACES=false`

**Custom Database User:**

Automatically create a custom superuser and disable the default `cassandra` user:

```bash
docker run -d --name axondb \
  -e AXONOPS_DB_USER=admin \
  -e AXONOPS_DB_PASSWORD=SecurePassword123 \
  -e INIT_SYSTEM_KEYSPACES=true \
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
- Completion markers: `/etc/axonops/init-system-keyspaces.done` and `/etc/axonops/init-db-user.done`

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
- Automatically sets endpoint snitch to `GossipingPropertyFileSnitch` when DC/Rack are configured

**4. Enables jemalloc Memory Optimization**
- Sets `LD_PRELOAD=/usr/lib64/libjemalloc.so.2`
- Improves memory allocation performance
- Safe fallback if jemalloc not found

**5. Launches Background Initialization**
- Starts `init-system-keyspaces.sh` in background (non-blocking)
- Or writes skip semaphores if `INIT_SYSTEM_KEYSPACES=false`
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
| `/etc/cassandra/cassandra-rackdc.properties` | Datacenter and rack topology | `CASSANDRA_DC`, `CASSANDRA_RACK` |
| `/etc/cassandra/jvm17-server.options` | JVM heap memory settings | `CASSANDRA_HEAP_SIZE` |

**Note:** The endpoint snitch is automatically set to `GossipingPropertyFileSnitch` when `CASSANDRA_DC` or `CASSANDRA_RACK` are provided. This snitch reads topology from `cassandra-rackdc.properties`.

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

The container includes a sophisticated healthcheck script supporting three probe types:

**1. Startup Probe** (`healthcheck.sh startup`)
- **Waits for initialization scripts to complete** (critical for async init pattern)
- Checks for semaphore files:
  - `/etc/axonops/init-system-keyspaces.done` (system keyspace conversion)
  - `/etc/axonops/init-db-user.done` (custom user creation)
- Verifies nodetool responds
- **Blocks pod "Started" status until init completes**
- Use for: Kubernetes `startupProbe` (ensures init finishes before traffic routing)

**2. Liveness Probe** (`healthcheck.sh liveness`)
- Checks if nodetool/JMX is responsive
- Fast and lightweight check
- Use for: Detecting if Cassandra process has crashed

**3. Readiness Probe** (`healthcheck.sh readiness`)
- Verifies node is `UN` (Up/Normal) state
- Checks native transport (CQL) is active
- Verifies gossip is active
- Use for: Load balancer health checks

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

### Automated System Keyspace Initialization

On first boot, the container automatically converts system keyspaces to `NetworkTopologyStrategy` using a background initialization pattern.

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
        │   - Writes semaphore files: /etc/axonops/init-system-keyspaces.done
        │                             /etc/axonops/init-db-user.done
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

**What it does:**
1. Waits for Cassandra to be ready (CQL port listening, native transport active)
2. Verifies this is a single-node cluster with default credentials
3. Detects datacenter name from running Cassandra instance
4. Converts `system_auth`, `system_distributed`, `system_traces` to `NetworkTopologyStrategy`
5. Runs repair on updated keyspaces
6. Writes completion semaphore: `/etc/axonops/init-system-keyspaces.done`

**Safety checks:**
- Only runs on single-node clusters (skips multi-node)
- Only runs if replication factor is 1 (skips if already customized)
- Only runs if using `SimpleStrategy` (skips if already `NetworkTopologyStrategy`)
- Requires default `cassandra/cassandra` credentials

**Logs:**
```bash
# View initialization logs
docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log

# Check semaphore status
docker exec axondb cat /etc/axonops/init-system-keyspaces.done
```

**Disable if needed:**
```bash
docker run -d --name axondb \
  -e INIT_SYSTEM_KEYSPACES=false \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

### Custom Database User Creation

The container can automatically create a custom superuser and disable the default `cassandra` user:

**What it does:**
1. Waits for system keyspace initialization to complete
2. Creates new superuser with specified username and password
3. Grants full superuser permissions
4. Disables default `cassandra` user (sets `can_login=false`)
5. Writes completion semaphore

**Example:**
```bash
docker run -d --name axondb \
  -e AXONOPS_DB_USER=dbadmin \
  -e AXONOPS_DB_PASSWORD=MySecurePassword123! \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0

# Wait for initialization (~2 minutes)
docker logs -f axondb

# Connect with new credentials
docker exec -it axondb cqlai -u dbadmin -p MySecurePassword123!
```

**Important notes:**
- Only works on fresh clusters with default credentials
- Both `AXONOPS_DB_USER` and `AXONOPS_DB_PASSWORD` must be set
- Password should be strong (mixed case, numbers, symbols)
- Default `cassandra` user remains in `system_auth` but cannot log in
- Runs automatically after system keyspace initialization

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
- `test-all-env-vars` - Test environment variable configuration (10 Cassandra + 3 initialization variables)
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

# Check system keyspace init status
docker exec axondb cat /etc/axonops/init-system-keyspaces.done

# Check custom user creation status
docker exec axondb cat /etc/axonops/init-db-user.done
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

6. **Backup Strategy**
   - Regular snapshots of `/var/lib/cassandra/data`
   - Test restore procedures
   - Document recovery time objectives (RTO)

7. **Cluster Deployment**
   - Use consistent `CASSANDRA_DC` and `CASSANDRA_RACK` across nodes
   - Configure `CASSANDRA_SEEDS` with multiple seed nodes
   - Set `CASSANDRA_CLUSTER_NAME` consistently
   - Plan for multi-datacenter deployments if needed

For development workflow and testing, see [DEVELOPMENT.md](./DEVELOPMENT.md).

For release process, see [RELEASE.md](./RELEASE.md).
