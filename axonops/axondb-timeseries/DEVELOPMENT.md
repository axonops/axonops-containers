# AxonDB Time-Series Development Guide

This document covers development practices, workflows, testing, and contribution guidelines for AxonDB Time-Series containers.

## Table of Contents

- [Workflows](#workflows)
  - [Build and Test](#build-and-test-axondb-timeseries-build-and-testyml)
  - [Production Publish](#production-publish-axondb-timeseries-publish-signedyml)
  - [Development Publish](#development-publish-axondb-timeseries-development-publish-signedyml)
- [Composite Actions](#composite-actions)
  - [Build and Test Actions](#build-and-test-actions)
  - [Action Naming Convention](#action-naming-convention)
- [Container Features](#container-features)
  - [Startup Version Banner](#startup-version-banner)
  - [System Keyspace Initialization](#system-keyspace-initialization)
  - [Healthcheck Script](#healthcheck-script)
- [Testing Locally](#testing-locally)
  - [Docker Build Test](#docker-build-test)
  - [Podman Build Test](#podman-build-test)
  - [View Startup Banner](#view-startup-banner)
  - [Run Local Container](#run-local-container)
  - [Test Environment Variables](#test-environment-variables)
- [Troubleshooting Development](#troubleshooting-development)
  - [Build Failures](#build-failures)
  - [Test Failures](#test-failures)
- [Adding Features](#adding-features)
  - [Adding New Environment Variables](#adding-new-environment-variables)
  - [Adding New Cassandra Versions](#adding-new-cassandra-versions)
- [Resources](#resources)
  - [Repository Structure](#repository-structure)
  - [GitHub Actions Variables](#github-actions-variables)
  - [Key Files](#key-files)
  - [External Dependencies](#external-dependencies)
- [Contributing](#contributing)

## Workflows

### Build and Test (`axondb-timeseries-build-and-test.yml`)
**Purpose:** Docker build verification and comprehensive functional testing

**Triggers:**
- Push to `main`, `development`, `feature/**`, or `fix/**` branches
  - When `axonops/axondb-timeseries/**` changes (excluding `*.md` files)
  - When `.github/workflows/axondb-timeseries-*.yml` changes
  - When `.github/actions/axondb-timeseries-*/**` changes
- Pull requests to `main` or `development` (same path filters)
- Manual workflow dispatch

**What it tests:**
- Container build verification (amd64 platform)
- Startup banner content (production vs development metadata)
- Version verification (Cassandra, Java, cqlai, jemalloc)
- Healthcheck script functionality (startup, liveness, readiness)
- System keyspace initialization
- Custom database user creation
- cqlai CQL operations
- cqlsh CQL operations
- Security scanning (Trivy)
- Environment variable handling (comprehensive test suite)
- Datacenter detection logic

**Runtime:** ~10-15 minutes

**Matrix:** Currently tests Cassandra 5.0.6 only (may expand to 5.0.7, 5.1.x in future)

---

### Production Publish (`axondb-timeseries-publish-signed.yml`)
**Purpose:** Build and publish production container images to GHCR with cryptographic signing

**Triggers:**
- Manual only (workflow dispatch)

**Required Inputs:**
- `main_git_tag` - Git tag on main branch (e.g., `axondb-timeseries-1.0.0`)
- `container_version` - Container version for GHCR (e.g., `1.0.0`)

**Process:**
1. **Validate** - Verify tag is on main branch and version doesn't exist
2. **Test** - Run full test suite on tagged code
3. **Create Release** - Create GitHub Release with metadata
4. **Build** - Multi-arch build (amd64 + arm64)
5. **Sign** - Cryptographic signing with Cosign (keyless OIDC)
6. **Publish** - Push to `ghcr.io/axonops/axondb-timeseries`
7. **Verify** - Pull from GHCR and run smoke tests

**Published Tags:**
- `5.0.6-1.0.0` (immutable)
- `5.0.6` (floating - latest AxonOps for this Cassandra)
- `latest` (floating - latest across all versions)

See [RELEASE.md](./RELEASE.md) for complete instructions.

---

### Development Publish (`axondb-timeseries-development-publish-signed.yml`)
**Purpose:** Publish development builds for testing before production

**Triggers:**
- Manual only (development branch)

**Published to:**
- `ghcr.io/axonops/development/axondb-timeseries:<version>`

**Use for:**
- Testing containers before promoting to production
- Validating changes in real environments
- No version validation (can overwrite)
- No GitHub Releases created

---

## Composite Actions

AxonDB Time-Series uses 14 composite actions to avoid duplication and enable reusability.

### Build and Test Actions
Located in `.github/actions/axondb-timeseries-*/`

**Container Lifecycle:**
- `start-and-wait` - Start container and wait for readiness (polls healthcheck)
- `collect-logs` - Collect container logs for debugging

**Verification:**
- `verify-startup-banner` - Verify banner shows correct metadata (production vs dev)
- `verify-no-startup-errors` - Check logs for ERROR/WARN/FATAL patterns
- `verify-versions` - Verify jemalloc, Cassandra, Java, cqlai versions

**Testing:**
- `test-healthcheck` - Test startup, liveness, readiness probes
- `verify-init-scripts` - Verify system keyspace init and user creation (both handled by `init-system-keyspaces.sh`)
- `test-cqlai` - Test cqlai (CREATE/INSERT/SELECT/DROP operations)
- `test-cqlsh` - Test cqlsh (same operations)
- `test-all-env-vars` - Test environment variables (10 CASSANDRA_* + 4 initialization = 14 total)
- `test-dc-detection` - Test datacenter detection from nodetool

**Publishing:**
- `sign-container` - Cosign keyless signing with OIDC
- `verify-published-image` - Pull from GHCR, verify signature, smoke tests
- `determine-latest` - Determine which tags should be marked as "latest"

### Action Naming Convention
- Prefix with `axondb-timeseries-` for component identification
- Use descriptive names (e.g., `test-cqlai`, `verify-versions`)
- All actions are Docker-based (no Kubernetes actions for this component)

---

## Container Features

### Startup Version Banner

**Implementation:**
- **Build-time:** Dockerfile writes `/etc/axonops/build-info.txt` with all static metadata
- **Runtime:** Entrypoint sources file and prints banner before starting Cassandra
- **Safe:** Never fails startup - errors caught with fallback to "unknown"

**Build-time metadata (in build-info.txt):**
```bash
CONTAINER_VERSION="1.0.0"
CONTAINER_IMAGE="ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0"
CONTAINER_REVISION="abc123def"
CONTAINER_GIT_TAG="axondb-timeseries-1.0.0"
CONTAINER_BUILD_DATE="2025-12-13T10:30:00Z"
CONTAINER_BUILT_BY="GitHub Actions"
IS_PRODUCTION_RELEASE="true"
CASSANDRA_VERSION="5.0.6"
UBI9_BASE_DIGEST="sha256:80f3902b..."
JAVA_VERSION="OpenJDK Runtime Environment..."
CQLAI_VERSION="v0.0.31"
JEMALLOC_VERSION="jemalloc-5.2.1-2.el9.x86_64"
OS_VERSION="Red Hat Enterprise Linux 9.7 (Plow) (UBI)"
PLATFORM="x86_64"
```

**Runtime detection:**
- Hostname (from `hostname` command)
- Kubernetes environment (from `KUBERNETES_SERVICE_HOST` env var)

**Production vs Development:**
- Production: Shows "Release:" link to GitHub release page
- Development: Shows "Tag:" link to GitHub tree/tag
- Production: Shows "Built by: GitHub Actions"
- Development: Omits "Built by" unless from CI

See README.md "Container Features" section for example output.

---

### System Keyspace Initialization

**Script:** `scripts/init-system-keyspaces.sh`

**Process:**
1. Wait for CQL port (9042) to be listening (max 10 min)
2. Wait for native transport + gossip to be active
3. Verify CQL connectivity with default credentials
4. Check if single-node cluster (via `nodetool status`)
5. Check if system keyspaces already use NetworkTopologyStrategy
6. Detect datacenter name from `nodetool status`
7. Convert system keyspaces to NetworkTopologyStrategy
8. Write `/etc/axonops/init-system-keyspaces.done` semaphore
9. If `AXONOPS_DB_USER` and `AXONOPS_DB_PASSWORD` are set:
   - Create custom superuser with specified credentials
   - Disable default `cassandra` user (sets `can_login=false`)
   - Write `/etc/axonops/init-db-user.done` semaphore

**Note:** Repair is NOT run because this is a single-node deployment (repair requires multiple replicas to be meaningful).

**Safety Checks:**
- Only runs on single-node clusters
- Only runs if RF=1 (skips if already customized)
- Only runs if using SimpleStrategy
- Requires default cassandra/cassandra credentials

**Semaphore Files:**
Located in `/var/lib/cassandra/.axonops/` (persistent volume, not ephemeral /etc):
- `init-system-keyspaces.done` - System keyspace conversion status
- `init-db-user.done` - Custom user creation status

**Always written** (even when skipped) with RESULT field: `success`, `skipped`, or `failed`

Used by healthcheck `startup` probe to ensure initialization completes before marking container ready.

---

### Healthcheck Script

**Script:** `scripts/healthcheck.sh`

**Design Philosophy:** Optimized for minimal overhead with appropriate checks for each probe type.

**Three Modes:**

1. **startup** - For Kubernetes startupProbe
   - Checks semaphore files exist in persistent storage (CRITICAL for async init coordination)
     - `/var/lib/cassandra/.axonops/init-system-keyspaces.done`
     - `/var/lib/cassandra/.axonops/init-db-user.done`
   - **Validates RESULT field** - Fails if either has `RESULT=failed`
   - Verifies Cassandra process running (`pgrep -f cassandra`)
   - Checks CQL port (9042) listening via TCP (`nc`)
   - **Lightweight** - No nodetool calls
   - Use during container startup phase

2. **liveness** - For Kubernetes livenessProbe
   - **Ultra-lightweight** - Runs every 10 seconds, must be very fast
   - Checks Cassandra process running (`pgrep -f cassandra`)
   - Checks CQL port (9042) listening via TCP (`nc`)
   - **No nodetool calls** - Minimal overhead
   - Detects if Cassandra process crashed

3. **readiness** - For Kubernetes readinessProbe (default)
   - Checks CQL port (9042) listening via TCP (`nc`)
   - Runs `nodetool info` to verify internal state
   - Verifies "Native Transport active: true"
   - Verifies "Gossip active: true"
   - **More thorough** than startup/liveness
   - Use for load balancer health checks

**Configuration:**
- CQL port: Configurable via `CASSANDRA_NATIVE_TRANSPORT_PORT` env var (default: 9042)
- Timeout: Configurable via `HEALTH_CHECK_TIMEOUT` env var (default: 10s)

---

## Testing Locally

### Docker Build Test

```bash
cd axonops/axondb-timeseries/5.0.6

# Basic build (local testing)
docker build \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg CQLAI_VERSION=0.0.31 \
  --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  --build-arg VERSION=local-test \
  --build-arg GIT_TAG=local \
  --build-arg IS_PRODUCTION_RELEASE=false \
  -t axondb-timeseries:local \
  .
```

### Podman Build Test

```bash
cd axonops/axondb-timeseries/5.0.6

# Podman build (same args as Docker)
podman build \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg CQLAI_VERSION=0.0.31 \
  -t axondb-timeseries:local \
  .
```

### View Startup Banner

```bash
# Docker
docker run --rm axondb-timeseries:local 2>&1 | head -40

# Podman
podman run --rm axondb-timeseries:local 2>&1 | head -40
```

### Run Local Container

```bash
# Start container
docker run -d --name axondb-local \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  -p 9042:9042 \
  axondb-timeseries:local

# Watch logs
docker logs -f axondb-local

# Test healthcheck probes
docker exec axondb-local /usr/local/bin/healthcheck.sh startup
docker exec axondb-local /usr/local/bin/healthcheck.sh liveness
docker exec axondb-local /usr/local/bin/healthcheck.sh readiness

# Test cqlai
docker exec -it axondb-local cqlai

# Check init logs
docker exec axondb-local cat /var/log/cassandra/init-system-keyspaces.log

# Cleanup
docker stop axondb-local
docker rm axondb-local
```

### Test Environment Variables

```bash
# Test with custom configuration
docker run -d --name axondb-test \
  -e CASSANDRA_CLUSTER_NAME=test-cluster \
  -e CASSANDRA_DC=testdc \
  -e CASSANDRA_RACK=rack1 \
  -e CASSANDRA_HEAP_SIZE=4G \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  -e AXONOPS_DB_USER=testadmin \
  -e AXONOPS_DB_PASSWORD=TestPass123! \
  -p 9042:9042 \
  axondb-timeseries:local

# Verify configuration
docker exec axondb-test cat /etc/cassandra/cassandra.yaml | grep -E "cluster_name|dc|rack"
docker exec axondb-test nodetool status

# Test custom user login (after init completes)
docker exec -it axondb-test cqlai -u testadmin -p TestPass123!

# Cleanup
docker stop axondb-test
docker rm axondb-test
```

---

## Troubleshooting Development

### Build Failures

**Issue: Base image not accessible**
```bash
# Test base image pull
docker pull registry.access.redhat.com/ubi9/ubi-minimal:latest

# Check digest matches Dockerfile
docker inspect registry.access.redhat.com/ubi9/ubi-minimal:latest \
  --format='{{index .RepoDigests 0}}'
```

**Issue: Cassandra download fails**
```bash
# Test Cassandra tarball availability
wget -q --spider https://dlcdn.apache.org/cassandra/5.0.6/apache-cassandra-5.0.6-bin.tar.gz
echo $?  # Should be 0 if accessible
```

**Issue: cqlai download fails**
```bash
# Check cqlai release exists
curl -I https://github.com/axonops/cqlai/releases/download/v0.0.31/cqlai-0.0.31-1.x86_64.rpm
```

**Issue: Build args not passed correctly**
```bash
# Verify build args in image
docker build --build-arg CASSANDRA_VERSION=5.0.6 --build-arg CQLAI_VERSION=0.0.31 -t test .
docker run --rm test cat /etc/axonops/build-info.txt
```

### Test Failures

**Container won't start:**
```bash
# Check logs for errors
docker logs axondb-local 2>&1 | grep -i error

# Check if Cassandra process is running
docker exec axondb-local ps aux | grep cassandra

# Check if ports are bound
docker exec axondb-local netstat -tuln | grep 9042
```

**Healthcheck fails:**
```bash
# Test each probe manually
docker exec axondb-local /usr/local/bin/healthcheck.sh startup 2>&1
docker exec axondb-local /usr/local/bin/healthcheck.sh liveness 2>&1
docker exec axondb-local /usr/local/bin/healthcheck.sh readiness 2>&1

# Check semaphore files
docker exec axondb-local ls -la /etc/axonops/
docker exec axondb-local cat /etc/axonops/init-system-keyspaces.done
```

**Init script doesn't run:**
```bash
# Check init script log
docker exec axondb-local cat /var/log/cassandra/init-system-keyspaces.log

# Verify INIT_SYSTEM_KEYSPACES_AND_ROLES setting
docker exec axondb-local env | grep INIT_SYSTEM_KEYSPACES_AND_ROLES

# Check if semaphore was written
docker exec axondb-local cat /etc/axonops/init-system-keyspaces.done
```

**cqlai/cqlsh tests fail:**
```bash
# Test cqlai manually
docker exec axondb-local cqlai -u cassandra -p cassandra -e "SELECT now() FROM system.local;"

# Test cqlsh manually
docker exec axondb-local cqlsh -u cassandra -p cassandra -e "SELECT now() FROM system.local;"

# Check authentication is enabled
docker exec axondb-local grep authenticator /etc/cassandra/cassandra.yaml
```

---

## Adding Features

### Adding New Environment Variables

1. **Update entrypoint.sh:**
   ```bash
   # Add default value
   export NEW_VARIABLE="${NEW_VARIABLE:-default_value}"

   # Apply to cassandra.yaml if needed
   if [ -n "$NEW_VARIABLE" ]; then
       _sed-in-place "/etc/cassandra/cassandra.yaml" \
         -r 's/^(# )?(new_setting:).*/\2 '"$NEW_VARIABLE"'/'
   fi
   ```

2. **Update README.md:**
   - Add to Environment Variables table
   - Add usage example

3. **Add test in test-all-env-vars action:**
   - Test variable is applied correctly
   - Verify in cassandra.yaml

4. **Test locally:**
   ```bash
   docker run -e NEW_VARIABLE=test_value axondb-timeseries:local
   docker exec container cat /etc/cassandra/cassandra.yaml | grep new_setting
   ```

### Adding New Cassandra Versions

When Cassandra releases new versions (e.g., 5.0.7 or 5.1.0):

1. **Check if new major.minor:**
   - If yes: Create new directory `axonops/axondb-timeseries/<version>/`
   - If patch: Can use existing 5.0.6 directory

2. **Update Dockerfile:**
   - Update `CASSANDRA_VERSION` ARG default
   - Update `CASSANDRA_SHA512` checksum
   - Test build

3. **Update workflows:**
   - Add to matrix in `axondb-timeseries-build-and-test.yml`
   - Add to matrix in publish workflows

4. **Update documentation:**
   - Update README.md with new version
   - Update examples

5. **Test:**
   ```bash
   cd axonops/axondb-timeseries/5.0.7  # or appropriate dir
   docker build --build-arg CASSANDRA_VERSION=5.0.7 --build-arg CQLAI_VERSION=0.0.31 -t test .
   docker run -d --name test -p 9042:9042 test
   docker logs -f test
   docker exec test nodetool version
   ```

6. **Publish:**
   - Follow RELEASE.md process

---

## Resources

### Repository Structure
```
axonops/axondb-timeseries/
├── 5.0.6/                          # Cassandra 5.0.6 container
│   ├── Dockerfile                  # Main container build
│   ├── config/                     # Cassandra configuration templates
│   │   ├── cassandra.yaml
│   │   ├── cassandra-env.sh
│   │   ├── logback.xml
│   │   ├── jvm-server.options
│   │   └── jvm17-server.options
│   └── scripts/                    # Container scripts
│       ├── entrypoint.sh           # Main entrypoint
│       ├── healthcheck.sh          # Healthcheck probe script (3 modes)
│       └── init-system-keyspaces.sh # Init script (keyspace conversion + user creation)
├── .trivyignore                    # Known CVE suppressions
├── README.md                       # This file
├── DEVELOPMENT.md                  # Development guide
└── RELEASE.md                      # Release process

.github/
├── workflows/
│   ├── axondb-timeseries-build-and-test.yml
│   ├── axondb-timeseries-publish-signed.yml
│   └── axondb-timeseries-development-publish-signed.yml
└── actions/
    └── axondb-timeseries-*/        # 14 composite actions
```

### GitHub Actions Variables

Repository variables (`.github` → Settings → Secrets and variables → Actions):

- `AXONDB_TIMESERIES_CQLAI_VERSION` - cqlai version to install (e.g., `0.0.31`)

### Key Files

- **Dockerfile** - Container build definition with supply chain security
- **entrypoint.sh** - Environment variable processing and Cassandra startup
- **healthcheck.sh** - Three-mode healthcheck (startup/liveness/readiness)
- **init-system-keyspaces.sh** - Combined script handling both:
  - System keyspace conversion to NetworkTopologyStrategy
  - Custom database user creation (if AXONOPS_DB_USER/PASSWORD set)

### External Dependencies

- **Base image:** `registry.access.redhat.com/ubi9/ubi-minimal` (digest-pinned)
- **Cassandra:** Apache Cassandra tarball from Apache mirrors
- **cqlai:** GitHub Releases from https://github.com/axonops/cqlai
- **jemalloc:** EPEL repository for RHEL 9

---

## Contributing

When making changes:

1. Create feature branch from `development`
2. Make changes and test locally
3. Push and create PR to `development`
4. CI tests run automatically
5. After merge, optionally publish development image for testing
6. Promote to `main` when ready for production
7. Follow RELEASE.md for production publish

See [RELEASE.md](./RELEASE.md) for complete release workflow.
