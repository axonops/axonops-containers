# AxonDB Search Development Guide

This document provides a comprehensive guide for developers working on the AxonDB Search container (OpenSearch 3.3.2). It covers the CI/CD pipeline architecture, local testing procedures, and implementation details of container features.

## Table of Contents

- [GitHub Actions Overview](#github-actions-overview)
  - [Composite Actions (15 Total)](#composite-actions-15-total)
  - [Workflows (3 Total)](#workflows-3-total)
  - [Testing Strategy](#testing-strategy)
- [Local Testing](#local-testing)
  - [Prerequisites](#prerequisites)
  - [Building the Image Locally](#building-the-image-locally)
  - [Testing with Security Enabled (Default)](#testing-with-security-enabled-default)
  - [Testing with Security Disabled](#testing-with-security-disabled)
  - [Testing with TLS Enabled (Default)](#testing-with-tls-enabled-default)
  - [Testing with TLS Disabled](#testing-with-tls-disabled)
  - [Testing Custom Admin User Creation](#testing-custom-admin-user-creation)
  - [Using Podman Instead of Docker](#using-podman-instead-of-docker)
- [Container Features Implementation](#container-features-implementation)
  - [Entrypoint Script Architecture](#entrypoint-script-architecture)
  - [Certificate Generation](#certificate-generation)
  - [Admin User Replacement Model](#admin-user-replacement-model)
  - [Healthcheck Implementation](#healthcheck-implementation)
  - [Semaphore Coordination](#semaphore-coordination)

---

## GitHub Actions Overview

The CI/CD pipeline is built using GitHub Actions with a modular architecture consisting of 15 composite actions and 3 workflows. This design promotes code reusability and maintainability.

### Composite Actions (15 Total)

All composite actions are located in `.github/actions/axondb-search-*/` and provide reusable testing and deployment capabilities.

#### Build and Version Actions

1. **extract-version** (`.github/actions/axondb-search-extract-version/`)
   - Extracts OpenSearch version from Dockerfile
   - Sets version as GitHub Actions output for downstream jobs
   - Used by all workflows to ensure version consistency

2. **build-and-push** (`.github/actions/axondb-search-build-and-push/`)
   - Builds multi-arch Docker images (linux/amd64, linux/arm64)
   - Pushes images to GitHub Container Registry (GHCR)
   - Handles build arguments and metadata injection

#### Container Startup and Verification

3. **start-and-wait** (`.github/actions/axondb-search-start-and-wait/`)
   - Starts container with configurable environment variables
   - Waits for OpenSearch to be ready (HTTP port listening)
   - Supports custom admin user configuration for testing
   - Polls healthcheck endpoint until container is fully initialized

4. **verify-startup-banner** (`.github/actions/axondb-search-verify-startup-banner/`)
   - Verifies startup banner contains correct version information
   - Checks for production vs. development build metadata
   - Validates OpenSearch version, image name, build date
   - Ensures supply chain security info is displayed (base image digest)

5. **verify-no-startup-errors** (`.github/actions/axondb-search-verify-no-startup-errors/`)
   - Scans container logs for error messages during startup
   - Fails if critical errors detected (e.g., port binding failures, initialization errors)
   - Helps catch issues that don't cause immediate container exit

6. **verify-versions** (`.github/actions/axondb-search-verify-versions/`)
   - Verifies OpenSearch version via REST API (`GET /`)
   - Validates Java version (OpenJDK 17)
   - Checks component versions match expected values

#### Health and Functionality Testing

7. **test-healthcheck** (`.github/actions/axondb-search-test-healthcheck/`)
   - Tests all three healthcheck modes: startup, liveness, readiness
   - Verifies healthcheck script exit codes (0 = healthy, non-zero = unhealthy)
   - Ensures healthcheck probes work correctly in Kubernetes environments

8. **test-authentication** (`.github/actions/axondb-search-test-authentication/`)
   - Tests authentication with admin credentials
   - Verifies default admin user (when no custom user specified)
   - Tests custom admin user creation and authentication
   - Confirms old admin user is removed (replacement model)

9. **test-rest-api** (`.github/actions/axondb-search-test-rest-api/`)
   - Tests core OpenSearch REST API operations
   - Creates indices, indexes documents, searches data
   - Verifies cluster health endpoint (`/_cluster/health`)
   - Tests with both HTTPS (default) and HTTP (when TLS disabled)

10. **test-custom-user** (`.github/actions/axondb-search-test-custom-user/`)
    - Tests custom admin user replacement functionality
    - Verifies default admin is removed when custom user created
    - Confirms only one admin user exists (security model)
    - Tests semaphore file creation with correct metadata

11. **test-all-env-vars** (`.github/actions/axondb-search-test-all-env-vars/`)
    - Tests all 20 environment variables supported by the container
    - Verifies configuration is applied correctly to opensearch.yml and jvm.options
    - Tests edge cases (empty values, special characters, max heap size, etc.)
    - Ensures environment variable changes are reflected in OpenSearch configuration

#### Security and Certificate Verification

12. **verify-certificates** (`.github/actions/axondb-search-verify-certificates/`)
    - Verifies AxonOps-branded certificates exist (not demo certificates)
    - Checks certificate files: root-ca.pem, node.pem, node-key.pem, admin.pem, admin-key.pem
    - Validates certificate chain (node cert signed by root CA)
    - Verifies certificate details (RSA 3072, 5-year validity, correct CN/OU/O)
    - Confirms `allow_unsafe_democertificates: false` in opensearch.yml

#### Publishing and Release

13. **sign-container** (`.github/actions/axondb-search-sign-container/`)
    - Signs container images using Cosign (keyless signing with OIDC)
    - Uses Sigstore for transparency and auditability
    - Generates signature attestations for supply chain security
    - Allows verification with `cosign verify` command

14. **verify-published-image** (`.github/actions/axondb-search-verify-published-image/`)
    - Pulls published image from GHCR to verify availability
    - Verifies image digest matches expected value
    - Tests that published image runs correctly
    - Confirms all tags were applied (immutable tag, floating tags, latest)

15. **create-release** (`.github/actions/axondb-search-create-release/`)
    - Creates GitHub Release for production builds
    - Generates release notes with image details and versions
    - Links to container registry and Cosign verification instructions
    - Tags releases with semantic versioning

### Workflows (3 Total)

#### 1. Build and Test (`.github/workflows/axondb-search-build-and-test.yml`)

**Purpose:** Automated testing on every push/PR to main, development, and feature branches.

**Triggers:**
- Push to `main`, `development`, `feature/*`, `fix/*` branches
- Pull requests to `main` or `development` branches
- Path filters: `axonops/axondb-search/**`, `.github/workflows/axondb-search-*.yml`, `.github/actions/axondb-search-*/**`
- Manual workflow dispatch (for testing specific OpenSearch versions)

**Jobs:**
- `axondb-search-test` - Builds image, runs comprehensive test suite
  - Build image for linux/amd64 (single arch for speed)
  - Start container with custom test user
  - Verify startup banner and versions
  - Test healthcheck probes
  - Verify AxonOps certificates
  - Test authentication and REST API
  - Test custom user replacement
  - Test all 20 environment variables

**Runtime:** ~10 minutes

**Usage:**
```bash
# Automatically runs on push/PR
git push origin feature/my-changes

# Manual trigger for specific version
gh workflow run axondb-search-build-and-test.yml \
  --ref development \
  -f opensearch_version=3.3.2
```

#### 2. Production Publish (`.github/workflows/axondb-search-publish-signed.yml`)

**Purpose:** Build, test, sign, and publish production images to GHCR.

**Trigger:** Manual workflow dispatch with git tag (main branch only)

**Required Inputs:**
- `main_git_tag` - Git tag on main branch (e.g., `axondb-search-1.0.0`)
- `container_version` - Container version for GHCR (e.g., `1.0.0`)

**Jobs:**
1. `axondb-search-validate` - Pre-flight checks
   - Verify tag is on main branch
   - Check container version doesn't already exist in GHCR

2. `axondb-search-test` - Comprehensive testing
   - Build test image with production metadata
   - Run full test suite (startup, healthcheck, REST API, etc.)
   - Run Trivy security scan (CRITICAL and HIGH severity)
   - Upload scan results to GitHub Security tab

3. `axondb-search-create-release` - Create GitHub Release
   - Generate release notes with version and image details
   - Link to GHCR package and Cosign verification

4. `axondb-search-build-push-sign` - Build and publish
   - Build multi-arch images (linux/amd64, linux/arm64)
   - Push to GHCR with multiple tags (immutable + floating)
   - Sign with Cosign (keyless OIDC signing)

5. `axondb-search-verify-published` - Post-publish verification
   - Pull published image and verify digest
   - Test published image runs correctly
   - Verify signature exists and is valid

**Usage:**
```bash
# Tag on main branch
git checkout main
git tag axondb-search-1.0.0
git push origin axondb-search-1.0.0

# Trigger workflow
gh workflow run axondb-search-publish-signed.yml \
  --ref main \
  -f main_git_tag=axondb-search-1.0.0 \
  -f container_version=1.0.0
```

#### 3. Development Publish (`.github/workflows/axondb-search-development-publish-signed.yml`)

**Purpose:** Publish signed development images for testing before production release.

**Trigger:** Manual workflow dispatch (development branch only)

**Registry:** `ghcr.io/axonops/development/axondb-search` (separate from production)

**Required Inputs:**
- `dev_git_tag` - Git tag on development branch (e.g., `vdev-axondb-search-1.0.0`)
- `container_version` - Container version (e.g., `1.0.0`)

**Jobs:** Similar to production workflow but publishes to development registry

**Usage:**
```bash
# Tag on development branch
git checkout development
git tag vdev-axondb-search-1.0.0
git push origin vdev-axondb-search-1.0.0

# Trigger workflow
gh workflow run axondb-search-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=vdev-axondb-search-1.0.0 \
  -f container_version=1.0.0
```

### Testing Strategy

The CI/CD pipeline implements a comprehensive testing strategy with multiple verification layers:

**Layer 1: Build Validation**
- Multi-arch build (amd64, arm64)
- Build argument validation
- Dockerfile syntax and best practices

**Layer 2: Functional Testing**
- Container startup and initialization
- Version verification (OpenSearch, Java, OS)
- Healthcheck probe testing (startup, liveness, readiness)
- REST API operations (index creation, search, cluster health)
- Authentication testing (default admin, custom user)
- Environment variable configuration (all 20 variables)

**Layer 3: Security Testing**
- Certificate verification (AxonOps-branded, not demo)
- Security plugin configuration validation
- Admin user replacement model verification
- TLS configuration testing (enabled/disabled)
- Trivy vulnerability scanning (CRITICAL and HIGH)

**Layer 4: Integration Testing**
- Custom user creation and authentication
- TLS termination scenarios (load balancer use cases)
- Multi-container scenarios (future: clustering tests)

---

## Local Testing

This section provides step-by-step instructions for building and testing the AxonDB Search container locally.

### Prerequisites

**Required:**
- Docker or Podman installed
- 16GB+ RAM available (OpenSearch default heap is 8GB, needs 1.5x = 12GB minimum)
- 50GB+ disk space

**System Requirements (Linux):**
```bash
# Set vm.max_map_count (required for OpenSearch)
sudo sysctl -w vm.max_map_count=262144

# Make permanent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

**Optional Tools:**
- `jq` - For pretty-printing JSON API responses
- `curl` - For testing REST API endpoints
- `openssl` - For verifying certificates

### Building the Image Locally

```bash
# Navigate to OpenSearch 3.3.2 directory
cd axonops/axondb-search/opensearch/3.3.2

# Build image (minimal - required args only)
docker build \
  --build-arg OPENSEARCH_VERSION=3.3.2 \
  -t axondb-search:local \
  .

# Build with full metadata (optional - mimics CI builds)
docker build \
  --build-arg OPENSEARCH_VERSION=3.3.2 \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse HEAD) \
  --build-arg VERSION=local-dev \
  --build-arg GIT_TAG=$(git describe --tags --always) \
  --build-arg GITHUB_ACTOR=$(whoami) \
  --build-arg IS_PRODUCTION_RELEASE=false \
  --build-arg IMAGE_FULL_NAME=axondb-search:local \
  -t axondb-search:local \
  .

# Multi-arch build (requires buildx)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg OPENSEARCH_VERSION=3.3.2 \
  -t axondb-search:local \
  .
```

### Testing with Security Enabled (Default)

Security plugin is enabled by default with AxonOps-branded certificates.

```bash
# Start container with default security
docker run -d \
  --name axondb-search-test \
  -p 9200:9200 \
  -p 9300:9300 \
  -e OPENSEARCH_CLUSTER_NAME=test-cluster \
  axondb-search:local

# Wait for startup (~60-90 seconds)
docker logs -f axondb-search-test

# Test HTTPS endpoint with default admin credentials
curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200

# View cluster health
curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health | jq

# Verify certificates
docker exec axondb-search-test ls -la /etc/opensearch/certs/

# View certificate details
docker exec axondb-search-test openssl x509 \
  -in /etc/opensearch/certs/node.pem \
  -noout -text

# Check security initialization
docker exec axondb-search-test cat /var/lib/opensearch/.axonops/init-security.done

# Cleanup
docker stop axondb-search-test
docker rm axondb-search-test
```

### Testing with Security Disabled

For testing scenarios where security plugin is not needed.

```bash
# Start container with security disabled (NOT recommended for production)
docker run -d \
  --name axondb-search-nosec \
  -p 9200:9200 \
  -e DISABLE_SECURITY_PLUGIN=true \
  axondb-search:local

# Wait for startup
docker logs -f axondb-search-nosec

# Test HTTP endpoint (no authentication required)
curl http://localhost:9200

# View cluster health (no auth)
curl http://localhost:9200/_cluster/health | jq

# Verify security is disabled in logs
docker logs axondb-search-nosec | grep -i security

# Cleanup
docker stop axondb-search-nosec
docker rm axondb-search-nosec
```

### Testing with TLS Enabled (Default)

HTTPS is enabled by default on the REST API (port 9200).

```bash
# Start with TLS enabled (default)
docker run -d \
  --name axondb-search-tls \
  -p 9200:9200 \
  -e AXONOPS_SEARCH_TLS_ENABLED=true \
  axondb-search:local

# Wait for startup
docker logs -f axondb-search-tls

# Test HTTPS endpoint
curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200

# Verify TLS configuration
docker exec axondb-search-tls grep -A 5 "plugins.security.ssl.http.enabled" /etc/opensearch/opensearch.yml

# Test certificate validation (without -k flag, will fail if cert invalid)
# Note: Will fail with self-signed certs unless you trust the CA
curl --cacert <(docker exec axondb-search-tls cat /etc/opensearch/certs/root-ca.pem) \
  -u admin:MyS3cur3P@ss2025 \
  https://localhost:9200

# Cleanup
docker stop axondb-search-tls
docker rm axondb-search-tls
```

### Testing with TLS Disabled

For testing load balancer TLS termination scenarios.

```bash
# Start with HTTP (TLS disabled on REST API)
docker run -d \
  --name axondb-search-notls \
  -p 9200:9200 \
  -e AXONOPS_SEARCH_TLS_ENABLED=false \
  axondb-search:local

# Wait for startup
docker logs -f axondb-search-notls

# Test HTTP endpoint (no TLS)
curl -u admin:MyS3cur3P@ss2025 http://localhost:9200

# View cluster health
curl -u admin:MyS3cur3P@ss2025 http://localhost:9200/_cluster/health | jq

# Verify HTTP SSL is disabled
docker exec axondb-search-notls grep "plugins.security.ssl.http.enabled" /etc/opensearch/opensearch.yml

# Note: Transport layer SSL (node-to-node) remains enabled
docker exec axondb-search-notls grep "plugins.security.ssl.transport" /etc/opensearch/opensearch.yml

# Cleanup
docker stop axondb-search-notls
docker rm axondb-search-notls
```

### Testing Custom Admin User Creation

Test the admin user replacement model (custom user REPLACES default admin).

```bash
# Start with custom admin user
docker run -d \
  --name axondb-search-custom \
  -p 9200:9200 \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=MyCustomPassword123 \
  axondb-search:local

# Wait for initialization (~60-90 seconds)
docker logs -f axondb-search-custom

# Test authentication with custom user
curl -k -u dbadmin:MyCustomPassword123 https://localhost:9200

# Verify default admin is removed (should fail with 401)
curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200
# Expected: {"error":{"root_cause":[{"type":"security_exception",...}]}}

# Check internal_users.yml (only custom user should exist)
docker exec axondb-search-custom cat /etc/opensearch/opensearch-security/internal_users.yml

# Verify semaphore file shows custom user creation
docker exec axondb-search-custom cat /var/lib/opensearch/.axonops/init-security.done
# Expected: RESULT=success, REASON=custom_user_created_prestartup, ADMIN_USER=dbadmin

# Test cluster operations with custom user
curl -k -u dbadmin:MyCustomPassword123 https://localhost:9200/_cluster/health | jq

# Cleanup
docker stop axondb-search-custom
docker rm axondb-search-custom
```

### Using Podman Instead of Docker

Podman is a daemonless container engine that's fully compatible with Docker commands.

```bash
# All docker commands work with podman
alias docker=podman

# Or use podman directly
podman build -t axondb-search:local .

# Start container (same as Docker)
podman run -d \
  --name axondb-search-test \
  -p 9200:9200 \
  -e AXONOPS_SEARCH_USER=testuser \
  -e AXONOPS_SEARCH_PASSWORD=TestPassword123 \
  axondb-search:local

# Test with curl
curl -k -u testuser:TestPassword123 https://localhost:9200

# Cleanup
podman stop axondb-search-test
podman rm axondb-search-test
```

**Note:** Podman runs rootless by default, which is more secure than Docker's daemon-based architecture.

---

## Container Features Implementation

This section provides technical details about how key container features are implemented.

### Entrypoint Script Architecture

The entrypoint script (`/usr/local/bin/docker-entrypoint.sh`) is the container's main orchestrator, running as PID 1 via **tini** (a minimal init system).

#### Why tini?

Tini is a tiny but valid init system that solves critical issues when running processes in containers:

1. **Signal Forwarding** - Forwards SIGTERM/SIGINT to child processes for graceful shutdown
2. **Zombie Reaping** - Cleans up terminated child processes (prevents zombie accumulation)
3. **Minimal Overhead** - Single static binary (~10KB), no dependencies
4. **Industry Standard** - Same init Docker uses with `--init` flag

**Process Tree:**
```
tini (PID 1)
  └─► docker-entrypoint.sh
       └─► opensearch (after exec)
```

#### Entrypoint Execution Flow

```
1. tini starts as PID 1
   └─► 2. docker-entrypoint.sh executes
        │
        ├─► 3. Print startup banner (version info, build metadata, runtime env)
        │
        ├─► 4. Set default environment variables
        │      (OPENSEARCH_CLUSTER_NAME, OPENSEARCH_HEAP_SIZE, etc.)
        │
        ├─► 5. Apply environment variables to opensearch.yml
        │      (cluster.name, node.name, network.host, discovery.type)
        │
        ├─► 6. Apply heap size to jvm.options
        │      (Sets -Xms and -Xmx to OPENSEARCH_HEAP_SIZE)
        │
        ├─► 7. Apply advanced settings
        │      (thread pool, SSL, security admin DN)
        │
        ├─► 8. Create custom admin user (PRE-STARTUP, if requested)
        │      - Generate bcrypt password hash
        │      - REPLACE internal_users.yml with ONLY custom user
        │      - Write semaphore: /var/lib/opensearch/.axonops/init-security.done
        │
        └─► 9. exec opensearch
            - Replaces shell process with OpenSearch
            - OpenSearch becomes main process (tini remains PID 1)
            - Background init script runs for certificate verification
```

#### Key Design Decisions

**Why `exec opensearch`?**
- Replaces shell process with OpenSearch (no orphaned shell)
- OpenSearch receives signals directly from tini
- Ensures clean shutdown when container stops
- Reduces memory footprint (no shell process)

**Why pre-startup user creation (not background)?**
- Admin user created BEFORE OpenSearch starts (atomic operation)
- No race conditions (OpenSearch reads final config on startup)
- REPLACEMENT model: Only ONE admin user exists (security best practice)
- Simpler than post-startup securityadmin tool (which requires TLS and cluster coordination)

### Certificate Generation

AxonOps-branded TLS certificates are generated during Docker build using `scripts/generate-certs.sh`.

#### Certificate Specifications

**Root CA:**
- Algorithm: RSA 3072-bit
- Validity: 5 years (1825 days)
- Subject: `O=AxonOps, OU=Database, CN=AxonOps Root CA`

**Node Certificate:**
- Algorithm: RSA 3072-bit
- Validity: 5 years (1825 days)
- Subject: `O=AxonOps, OU=Database, CN=axondbsearch.axonops.com`
- SAN: `axondbsearch.axonops.com`, `*.axondbsearch.axonops.com`, `localhost`, `127.0.0.1`, `::1`
- Usage: Transport and HTTP SSL

**Admin Certificate:**
- Algorithm: RSA 3072-bit
- Validity: 5 years (1825 days)
- Subject: `O=AxonOps, OU=Database, CN=admin.axondbsearch.axonops.com`
- Usage: securityadmin tool authentication

#### Certificate Files

Located in `/etc/opensearch/certs/`:

| File | Type | Permissions |
|------|------|------------|
| `root-ca.pem` | Root CA certificate | 644 |
| `root-ca-key.pem` | Root CA private key | 600 |
| `node.pem` | Node certificate | 644 |
| `node-key.pem` | Node private key (PKCS#8) | 600 |
| `admin.pem` | Admin certificate | 644 |
| `admin-key.pem` | Admin private key (PKCS#8) | 600 |

#### Why PKCS#8 Format?

OpenSearch security plugin requires private keys in PKCS#8 format (not traditional PEM):

```bash
# Convert to PKCS#8 (done automatically by generate-certs.sh)
openssl pkcs8 -topk8 -inform PEM -outform PEM -in node-key-traditional.pem -out node-key.pem -nocrypt
```

### Admin User Replacement Model

Unlike AxonDB Time-Series (which appends custom users), AxonDB Search uses a **REPLACEMENT** model for security.

#### Why Replacement Instead of Append?

1. **Principle of Least Privilege** - Only one admin account reduces attack surface
2. **No Default Credentials** - Eliminates risk of forgotten default admin user
3. **Clean Security Model** - No legacy accounts or disabled users
4. **Atomic Operation** - User creation happens before OpenSearch starts (no race conditions)

#### Implementation

**Default Configuration (no custom user):**
- `internal_users.yml` contains default admin user
- Username: `admin`
- Password: `MyS3cur3P@ss2025` (bcrypt hashed)

**Custom User Configuration:**
```bash
# Set environment variables
AXONOPS_SEARCH_USER=dbadmin
AXONOPS_SEARCH_PASSWORD=MySecurePassword123
```

**Entrypoint Script Actions:**
1. Check if both `AXONOPS_SEARCH_USER` and `AXONOPS_SEARCH_PASSWORD` are set
2. Generate bcrypt password hash using OpenSearch hash.sh tool
3. **REPLACE** entire `internal_users.yml` with ONLY the custom user definition
4. Default `admin` user is removed (does not exist in final config)
5. Write semaphore file immediately to persistent storage

**Semaphore File:**
```
COMPLETED=2025-12-16T10:30:00Z
RESULT=success
REASON=custom_user_created_prestartup
ADMIN_USER=dbadmin
```

#### Security Benefits

- **No dual admin accounts** - Only one admin exists at any time
- **Forced credential change** - Production deployments must set custom credentials
- **Audit trail** - Semaphore file records which admin user was created
- **Predictable state** - Admin user is deterministic (custom OR default, never both)

### Healthcheck Implementation

The healthcheck script (`/usr/local/bin/healthcheck.sh`) supports three probe types optimized for Kubernetes.

#### Probe Types

**1. Startup Probe** (`healthcheck.sh startup`)
- **Purpose:** Wait for initialization to complete before marking pod "Started"
- **Checks:**
  1. Semaphore file exists: `/var/lib/opensearch/.axonops/init-security.done`
  2. Semaphore RESULT is not "failed"
  3. OpenSearch process is running (`pgrep -f OpenSearch`)
  4. HTTP port (9200) is listening (TCP check via `nc`)
  5. Security plugin health endpoint responds (`/_plugins/_security/health`)
- **Use Case:** Kubernetes `startupProbe` (blocks traffic until init complete)
- **Kubernetes Config:**
  ```yaml
  startupProbe:
    exec:
      command: ["/usr/local/bin/healthcheck.sh", "startup"]
    initialDelaySeconds: 30
    periodSeconds: 10
    failureThreshold: 30  # 5 minutes max
  ```

**2. Liveness Probe** (`healthcheck.sh liveness`)
- **Purpose:** Detect if OpenSearch process has crashed (restart pod if unhealthy)
- **Checks:**
  1. OpenSearch process is running (`pgrep -f OpenSearch`)
  2. HTTP port (9200) is listening (TCP check)
  3. Security plugin health endpoint responds
- **Design:** Ultra-lightweight, no cluster health API calls (runs every 10 seconds)
- **Use Case:** Kubernetes `livenessProbe` (detect crashes)
- **Kubernetes Config:**
  ```yaml
  livenessProbe:
    exec:
      command: ["/usr/local/bin/healthcheck.sh", "liveness"]
    initialDelaySeconds: 60
    periodSeconds: 10
    failureThreshold: 3
  ```

**3. Readiness Probe** (`healthcheck.sh readiness`)
- **Purpose:** Determine if pod should receive traffic (load balancer health)
- **Checks:**
  1. HTTP port (9200) is listening
  2. Authenticated call to `/_cluster/health` succeeds
  3. Cluster status is not "red" (yellow or green acceptable)
- **Design:** More thorough than liveness, ensures OpenSearch is fully operational
- **Credentials:** Auto-detects admin user from semaphore file
- **Use Case:** Kubernetes `readinessProbe` (load balancer traffic routing)
- **Kubernetes Config:**
  ```yaml
  readinessProbe:
    exec:
      command: ["/usr/local/bin/healthcheck.sh", "readiness"]
    initialDelaySeconds: 60
    periodSeconds: 10
    failureThreshold: 3
  ```

#### Healthcheck Design Principles

1. **Minimal Overhead** - Liveness probe is ultra-fast (no API calls)
2. **Authentication Awareness** - Readiness probe detects custom admin user automatically
3. **Semaphore Coordination** - Startup probe waits for initialization completion
4. **TLS Agnostic** - Works with both HTTPS (default) and HTTP (TLS disabled)

### Semaphore Coordination

Semaphore files coordinate initialization between entrypoint script, background verification, and healthcheck probes.

#### Why Semaphores?

1. **Persistent State** - Stored in `/var/lib/opensearch` (volume), survives pod restarts
2. **No Re-initialization** - Prevents re-running init scripts on pod restarts
3. **Healthcheck Coordination** - Startup probe waits for semaphore before marking pod "Started"
4. **Audit Trail** - Records initialization timestamp, result, and admin user created

#### Semaphore Location

**File:** `/var/lib/opensearch/.axonops/init-security.done`

**Why `/var/lib/opensearch` (not `/etc`)?**
- `/var/lib/opensearch` is configured as a persistent volume in Kubernetes
- Semaphores survive container/pod restarts
- Prevents re-initialization on rolling updates
- Healthcheck immediately passes after restart without re-running init

#### Semaphore Format

```
COMPLETED=2025-12-16T10:30:00Z
RESULT=success
REASON=custom_user_created_prestartup
ADMIN_USER=dbadmin
```

#### RESULT Values

**Success:**
- `success` - Initialization completed successfully
  - `custom_user_created_prestartup` - Custom admin created (default removed)
  - `default_config` - Using default admin user
  - `custom_admin_user_created` - Custom user created via background script (legacy)

**Skipped:**
- `skipped` - Initialization skipped (with REASON)
  - `security_plugin_disabled` - `DISABLE_SECURITY_PLUGIN=true`
  - `tls_disabled_no_securityadmin` - TLS disabled, cannot use securityadmin tool

**Failed:**
- `failed` - Initialization failed (with REASON)
  - `http_port_timeout` - Port 9200 didn't open within timeout
  - `cluster_not_responsive` - Cluster didn't respond within timeout
  - `certificates_missing` - AxonOps certificates not found
  - `security_config_missing` - Security configuration files missing
  - `password_hash_failed` - Failed to generate bcrypt hash
  - `securityadmin_failed` - securityadmin tool failed

#### Healthcheck Coordination

**Startup Probe Logic:**
```bash
# 1. Check semaphore exists
if [ ! -f /var/lib/opensearch/.axonops/init-security.done ]; then
  exit 1  # Not ready yet
fi

# 2. Check RESULT is not "failed"
RESULT=$(grep "^RESULT=" /var/lib/opensearch/.axonops/init-security.done | cut -d'=' -f2)
if [ "$RESULT" = "failed" ]; then
  exit 1  # Initialization failed, pod should not start
fi

# 3. Continue with other healthchecks (process, port, API)
```

**Guarantee:** Semaphore file is ALWAYS written in all code paths (success, skipped, or failed). The startup probe will:
- Wait for semaphore to exist
- Fail if RESULT=failed (prevents pod from starting)
- Pass if RESULT=success or RESULT=skipped

This ensures the container won't be marked "Started" in Kubernetes until initialization completes successfully.

---

## Contributing

When contributing to AxonDB Search container:

1. **Test locally** - Use the local testing instructions above
2. **Run full test suite** - Ensure all composite actions pass (use build-and-test workflow)
3. **Update documentation** - Keep README.md and DEVELOPMENT.md in sync with changes
4. **Follow versioning** - Use semantic versioning for container releases
5. **Security scanning** - Run Trivy scan locally before pushing

## Additional Resources

- **Main Documentation:** [README.md](./README.md)
- **Release Process:** [RELEASE.md](./RELEASE.md)
- **OpenSearch Documentation:** [opensearch.org/docs](https://opensearch.org/docs/latest/)
- **Security Plugin:** [opensearch.org/docs/security](https://opensearch.org/docs/latest/security/index/)
- **Cosign Documentation:** [docs.sigstore.dev](https://docs.sigstore.dev/cosign/overview/)
