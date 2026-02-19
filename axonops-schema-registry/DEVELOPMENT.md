# AxonOps Schema Registry Development Guide

This document covers development practices, workflows, testing, and contribution guidelines for AxonOps Schema Registry containers.

## Table of Contents

- [Workflows](#workflows)
  - [Build and Test](#build-and-test-axonops-schema-registry-build-and-testyml)
  - [Production Publish](#production-publish-axonops-schema-registry-publish-signedyml)
  - [Development Publish](#development-publish-axonops-schema-registry-development-publish-signedyml)
  - [Automated Release](#automated-release-axonops-schema-registry-releaseyml)
- [Composite Actions](#composite-actions)
  - [Build and Test Actions](#build-and-test-actions)
  - [Action Naming Convention](#action-naming-convention)
- [Container Features](#container-features)
  - [Startup Version Banner](#startup-version-banner)
  - [Healthcheck Script](#healthcheck-script)
- [Testing Locally](#testing-locally)
  - [Docker Build Test](#docker-build-test)
  - [Podman Build Test](#podman-build-test)
  - [View Startup Banner](#view-startup-banner)
  - [Run Local Container](#run-local-container)
- [Troubleshooting Development](#troubleshooting-development)
  - [Build Failures](#build-failures)
  - [Test Failures](#test-failures)
- [Adding Features](#adding-features)
  - [Adding New SR Versions](#adding-new-sr-versions)
- [Resources](#resources)
  - [Repository Structure](#repository-structure)
  - [Key Files](#key-files)
  - [External Dependencies](#external-dependencies)
- [Contributing](#contributing)

## Workflows

### Build and Test (`axonops-schema-registry-build-and-test.yml`)
**Purpose:** Docker build verification and functional testing

**Triggers:**
- Push to `main`, `development`, `feature/**`, or `fix/**` branches
  - When `axonops-schema-registry/**` changes (excluding `*.md` files)
  - When `.github/workflows/axonops-schema-registry-*.yml` changes
  - When `.github/actions/axonops-schema-registry-*/**` changes
- Pull requests to `main` or `development` (same path filters)
- Manual workflow dispatch

**What it tests:**
- Container build verification (amd64 platform)
- Startup banner content (production vs development metadata)
- Version verification (SR version, container version)
- Healthcheck script functionality (startup, liveness, readiness)
- Schema Registry API tests (GET /)
- Security scanning (Trivy)

**Runtime:** ~5 minutes

---

### Production Publish (`axonops-schema-registry-publish-signed.yml`)
**Purpose:** Build and publish production container images to GHCR with cryptographic signing

**Triggers:**
- Manual only (workflow dispatch)

**Required Inputs:**
- `main_git_tag` - Git tag on main branch (e.g., `axonops-schema-registry-0.2.0-0.0.1`)
- `sr_version` - Schema Registry version (e.g., `0.2.0`)
- `container_version` - Container version (e.g., `0.0.1`)

**Process:**
1. **Validate** - Verify tag is on main branch and version doesn't exist
2. **Test** - Run full test suite on tagged code
3. **Create Release** - Create GitHub Release with metadata
4. **Build** - Multi-arch build (amd64 + arm64)
5. **Sign** - Cryptographic signing with Cosign (keyless OIDC)
6. **Publish** - Push to `ghcr.io/axonops/axonops-schema-registry`
7. **Verify** - Pull from GHCR and run smoke tests

**Published Tags:**
- `0.2.0-0.0.1` (immutable)
- `0.2.0` (floating - latest container version for this SR version)
- `latest` (floating - latest across all versions)

See [RELEASE.md](./RELEASE.md) for complete instructions.

---

### Development Publish (`axonops-schema-registry-development-publish-signed.yml`)
**Purpose:** Publish development builds for testing before production

**Triggers:**
- Manual only (development branch)

**Published to:**
- `ghcr.io/axonops/development/axonops-schema-registry:<version>`

**Use for:**
- Testing containers before promoting to production
- Validating changes in real environments
- No version validation (can overwrite)
- No GitHub Releases created

---

### Automated Release (`axonops-schema-registry-release.yml`)
**Purpose:** Full automated release pipeline triggered from upstream `axonops/axonops-schema-registry`

**Triggers:**
- `repository_dispatch` (type: `schema-registry-release`) — cross-repo from upstream
- `workflow_dispatch` — manual trigger with `sr_version` input

**Auto-Version:** Container version is calculated automatically by querying GHCR for existing tags. No manual version input needed.

**Pipeline:**
1. **Setup** — Determine SR version, calculate next container version
2. **Test** — Build and run full test suite
3. **Publish Dev** — Multi-arch build, push to dev registry, sign
4. **Verify Dev** — Pull, verify signature, smoke test
5. **Publish Prod** — Multi-arch build, push to prod registry, sign, create GitHub Release
6. **Verify Prod** — Pull, verify signature, smoke test

See [RELEASE.md](./RELEASE.md#automated-releases-cross-repo) for upstream integration details.

---

## Composite Actions

AxonOps Schema Registry uses composite actions to avoid duplication and enable reusability.

### Build and Test Actions
Located in `.github/actions/axonops-schema-registry-*/`

**Container Lifecycle:**
- `start-and-wait` - Start container and wait for readiness (polls healthcheck)
- `collect-logs` - Collect container logs for debugging

**Verification:**
- `verify-startup-banner` - Verify banner shows correct metadata (production vs dev)
- `verify-no-startup-errors` - Check logs for ERROR/WARN/FATAL patterns
- `verify-versions` - Verify SR version and container version

**Testing:**
- `test-healthcheck` - Test startup, liveness, readiness probes
- `test-api` - Test Schema Registry API endpoints (GET /)

**Publishing:**
- `sign-container` - Cosign keyless signing with OIDC
- `verify-published-image` - Pull from GHCR, verify signature, smoke tests
- `calculate-version` - Auto-calculate next container version from GHCR tags

### Action Naming Convention
- Prefix with `axonops-schema-registry-` for component identification
- Use descriptive names (e.g., `test-api`, `verify-versions`)
- All actions are Docker-based (no Kubernetes actions for this component)

---

## Container Features

### Startup Version Banner

**Implementation:**
- **Build-time:** Dockerfile writes `/etc/axonops/build-info.txt` with all static metadata
- **Runtime:** Entrypoint sources file and prints banner before starting Schema Registry
- **Safe:** Never fails startup - errors caught with fallback to "unknown"

**Build-time metadata (in build-info.txt):**
```bash
CONTAINER_VERSION="0.2.0-0.0.1"
CONTAINER_IMAGE="ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1"
CONTAINER_REVISION="abc123def"
CONTAINER_GIT_TAG="axonops-schema-registry-0.2.0-0.0.1"
CONTAINER_BUILD_DATE="2025-12-13T10:30:00Z"
CONTAINER_BUILT_BY="GitHub Actions"
IS_PRODUCTION_RELEASE="true"
SR_VERSION="0.2.0"
CONTAINER_VERSION_TAG="0.0.1"
UBI9_BASE_DIGEST="sha256:6fc28bcb6776e387..."
SR_BINARY_VERSION="v0.2.0"
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

---

### Healthcheck Script

**Script:** `scripts/healthcheck.sh`

**Design Philosophy:** Optimized for minimal overhead with appropriate checks for each probe type.

**Three Modes:**

1. **startup** - For Kubernetes startupProbe
   - Checks Schema Registry process is running (`pgrep -f axonops-schema-registry`)
   - Checks API port responds to HTTP request
   - Use during container startup phase

2. **liveness** - For Kubernetes livenessProbe
   - **Ultra-lightweight** - Runs frequently
   - Checks Schema Registry process is running (`pgrep -f axonops-schema-registry`)
   - Detects if process has crashed

3. **readiness** - For Kubernetes readinessProbe (default)
   - Full HTTP health check against `GET /` endpoint
   - Verifies HTTP 200 response
   - **More thorough** than startup/liveness
   - Use for load balancer health checks

**Configuration:**
- API port: Configurable via `SR_PORT` env var (default: 8081)
- Timeout: Configurable via `HEALTH_CHECK_TIMEOUT` env var (default: 10s)

---

## Testing Locally

### Docker Build Test

```bash
cd axonops-schema-registry

# Basic build (local testing)
docker build \
  --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  --build-arg VERSION=local-test \
  --build-arg GIT_TAG=local \
  --build-arg IS_PRODUCTION_RELEASE=false \
  -t axonops-schema-registry:local \
  .
```

### Podman Build Test

```bash
cd axonops-schema-registry

# Podman build
podman build \
  -t axonops-schema-registry:local \
  .
```

### View Startup Banner

```bash
# Docker
docker run --rm axonops-schema-registry:local 2>&1 | head -30

# Podman
podman run --rm axonops-schema-registry:local 2>&1 | head -30
```

### Run Local Container

```bash
# Start container
docker run -d --name sr-local \
  -p 8081:8081 \
  axonops-schema-registry:local

# Watch logs
docker logs -f sr-local

# Test healthcheck probes
docker exec sr-local /usr/local/bin/healthcheck.sh startup
docker exec sr-local /usr/local/bin/healthcheck.sh liveness
docker exec sr-local /usr/local/bin/healthcheck.sh readiness

# Test API
curl -s http://localhost:8081/

# Cleanup
docker stop sr-local
docker rm sr-local
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

**Issue: Schema Registry tarball download fails**
```bash
# Test tarball availability
curl -sIL https://github.com/axonops/axonops-schema-registry/releases/download/v0.2.0/axonops-schema-registry-0.2.0-linux-amd64.tar.gz
```

**Issue: Build args not passed correctly**
```bash
# Verify build args in image
docker build -t test .
docker run --rm test cat /etc/axonops/build-info.txt
```

### Test Failures

**Container won't start:**
```bash
# Check logs for errors
docker logs sr-local 2>&1 | grep -i error

# Check if process is running
docker exec sr-local ps aux | grep axonops-schema-registry
```

**Healthcheck fails:**
```bash
# Test each probe manually
docker exec sr-local /usr/local/bin/healthcheck.sh startup 2>&1
docker exec sr-local /usr/local/bin/healthcheck.sh liveness 2>&1
docker exec sr-local /usr/local/bin/healthcheck.sh readiness 2>&1

# Test API directly
docker exec sr-local curl -sf http://localhost:8081/
```

---

## Adding Features

### Adding New SR Versions

When a new Schema Registry version is released (e.g., 0.3.0):

1. **Create new directory:**
   ```bash
   mkdir -p axonops-schema-registry/0.3/{scripts,config}
   ```

2. **Copy and update Dockerfile:**
   - Update `SR_VERSION` ARG default
   - Verify SHA256SUMS are available for new version

3. **Copy scripts and config:**
   - Copy entrypoint.sh, healthcheck.sh from previous version
   - Copy config.yaml (update if upstream config format changed)

4. **Update workflows:**
   - Update default `sr_version` values in workflow inputs
   - Update path filters if needed

5. **Update documentation:**
   - Update README.md with new version
   - Update examples

6. **Test:**
   ```bash
   cd axonops-schema-registry/0.3
   docker build -t test .
   docker run -d --name test -p 8081:8081 test
   curl -s http://localhost:8081/
   ```

---

## Resources

### Repository Structure
```
axonops-schema-registry/
├── Dockerfile                      # Main container build (version-agnostic)
├── .dockerignore                   # Build context exclusions
├── config/                         # Configuration files
│   └── config.yaml                 # Default SR configuration
├── scripts/                        # Container scripts
│   ├── entrypoint.sh               # Main entrypoint
│   └── healthcheck.sh              # Healthcheck probe script (3 modes)
├── .trivyignore                    # Known CVE suppressions
├── README.md                       # User-facing documentation
├── DEVELOPMENT.md                  # This file
└── RELEASE.md                      # Release process

.github/
├── workflows/
│   ├── axonops-schema-registry-build-and-test.yml
│   ├── axonops-schema-registry-publish-signed.yml
│   ├── axonops-schema-registry-development-publish-signed.yml
│   └── axonops-schema-registry-release.yml
└── actions/
    └── axonops-schema-registry-*/  # Composite actions
```

### Key Files

- **Dockerfile** - Container build definition with supply chain security
- **entrypoint.sh** - Startup banner display and process execution
- **healthcheck.sh** - Three-mode healthcheck (startup/liveness/readiness)

### External Dependencies

- **Base image:** `registry.access.redhat.com/ubi9/ubi-minimal` (digest-pinned)
- **Schema Registry:** GitHub Releases from https://github.com/axonops/axonops-schema-registry
- **Tini:** GitHub Releases from https://github.com/krallin/tini

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
