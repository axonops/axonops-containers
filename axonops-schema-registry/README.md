# AxonOps Schema Registry

[![GHCR Package](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axonops-schema-registry)

Production-ready Confluent-compatible Kafka Schema Registry with multi-backend storage support, built on Red Hat UBI 9.

## Table of Contents

- [Overview](#overview)
- [Pre-built Docker Images](#pre-built-docker-images)
  - [Available Images](#available-images)
  - [Tagging Strategy](#tagging-strategy)
- [Production Best Practice](#-production-best-practice)
- [Building Docker Images](#building-docker-images)
- [Environment Variables](#environment-variables)
- [Container Features](#container-features)
  - [Entrypoint Script](#entrypoint-script)
  - [Startup Version Banner](#startup-version-banner)
  - [Healthcheck Probes](#healthcheck-probes)
- [CI/CD Pipeline](#cicd-pipeline)
  - [Workflows](#workflows)
  - [Automated Testing](#automated-testing)
  - [Publishing Process](#publishing-process)
- [Troubleshooting](#troubleshooting)
  - [Checking Container Version](#checking-container-version)
  - [Healthcheck Debugging](#healthcheck-debugging)
  - [Container Not Starting](#container-not-starting)
- [Production Considerations](#production-considerations)

## Overview

AxonOps Schema Registry is a Confluent-compatible Kafka Schema Registry that provides schema management with multiple storage backend support. It is a single stateless Go binary that exposes a REST API on port 8081.

**Container Features:**
- **Multi-Backend Storage**: PostgreSQL, MySQL, Cassandra 5+, and in-memory storage backends
- **Confluent API Compatible**: Drop-in replacement for Confluent Schema Registry
- **Enterprise Base**: Built on Red Hat UBI 9 minimal for production stability
- **Supply Chain Security**: Digest-pinned base images for immutable builds
- **Production Monitoring**: Integrated healthcheck probes (startup, liveness, readiness)
- **Lightweight**: Single Go binary, ~50MB memory footprint

**API Endpoints:**
- Health check: `GET /`
- Swagger documentation: `GET /docs`
- Schema Registry API: Port 8081

## Pre-built Docker Images

Pre-built images are available from GitHub Container Registry (GHCR). This is the easiest way to get started.

### Available Images

All images are available at: `ghcr.io/axonops/axonops-schema-registry`

Browse all available tags: [GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axonops-schema-registry)

### Tagging Strategy

Images use a multi-dimensional tagging strategy with two independent axes:

- **SR_VERSION** - Schema Registry application version (e.g., `0.2.0`)
- **CONTAINER_VERSION** - Container version (semver, e.g., `0.0.1`, `0.0.2`, `0.1.0`)

| Tag Pattern | Example | Description | Use Case |
|-------------|---------|-------------|----------|
| `{SR_VERSION}-{CONTAINER_VERSION}` | `0.2.0-0.0.1` | Fully immutable (SR version + container version) | **Production**: Pin exact versions for complete auditability |
| `@sha256:<digest>` | `@sha256:abc123...` | Digest-based (cryptographically immutable) | **Highest Security**: Guaranteed image integrity |
| `{SR_VERSION}` | `0.2.0` | Latest container version for this SR version | Track container updates for specific SR version |
| `latest` | `latest` | Latest across all versions | Quick trials only (NOT for production) |

**Tagging Examples:**

When `0.2.0-0.0.1` is built (and it's the latest):
- `0.2.0-0.0.1` (immutable - never changes)
- `0.2.0` (floating - retags to newer container versions of same SR version)
- `latest` (floating - moves to newer SR versions)

When `0.2.0-0.0.2` is built (container-only bump, same SR version):
- `0.2.0-0.0.2` (immutable - never changes)
- `0.2.0` (floating - now points to container version 0.0.2)
- `latest` (floating - now points to container version 0.0.2)

When `0.3.0-0.0.1` is built (new SR version, container version resets to 0.0.1):
- `0.3.0-0.0.1` (immutable - never changes)
- `0.3.0` (floating - latest container version of 0.3.0)
- `latest` (floating - now points to 0.3.0-0.0.1)

## Production Best Practice

**Using `latest` or floating tags in production is an anti-pattern**. This includes `latest` and `0.2.0` because:
- **No audit trail**: Cannot determine exact version deployed at a given time
- **Unexpected updates**: Container orchestrators may pull new images during restarts
- **Rollback difficulties**: Cannot reliably roll back to previous versions
- **Compliance issues**: Many frameworks require immutable version tracking

**Recommended Deployment Strategies (in order of security):**

1. **Gold Standard - Digest-Based** (Highest Security)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry@sha256:abc123...
   ```
   - 100% immutable, cryptographically guaranteed
   - Required for regulated environments
   - Verify signature with Cosign (see below)

2. **Immutable Tag** (Production Standard)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
   ```
   - Pinned to specific version (SR 0.2.0, container 0.0.1)
   - Easy to read and manage
   - Full audit trail maintained

3. **Floating Tags** (Development/Testing Only)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry:latest
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
  ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1

# Check signature exists
cosign tree ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
```

## Building Docker Images

If you prefer to build images yourself instead of using pre-built images:

```bash
cd axonops-schema-registry/0.2

# Minimal build (required args only)
docker build \
  -t axonops-schema-registry:0.2.0-0.0.1 \
  .

# Multi-arch build (amd64 + arm64) using buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t axonops-schema-registry:0.2.0-0.0.1 \
  .
```

**Optional build arguments (enhance metadata but aren't required):**
- `SR_VERSION` - Schema Registry version (default: `0.2.0`)
- `BUILD_DATE` - Build timestamp (ISO 8601 format, e.g., `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF` - Git commit SHA (e.g., `$(git rev-parse HEAD)`)
- `VERSION` - Full version string (e.g., `0.2.0-0.0.1`)
- `CONTAINER_VERSION` - Container version (e.g., `0.0.1`)
- `GIT_TAG` - Git tag name (for release/tag links in banner)
- `GITHUB_ACTOR` - Username who triggered build (for audit trail)
- `IS_PRODUCTION_RELEASE` - Set to `true` for production (default: `false`)
- `IMAGE_FULL_NAME` - Full image name with tag (displayed in startup banner)

**Supply Chain Security:**

Our Dockerfile uses digest-pinned base images for supply chain security:

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
ARG UBI9_MINIMAL_DIGEST=sha256:6fc28bcb6776e387d7a35a2056d9d2b985dc4e26031e98a2bd35a7137cd6fd71
FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
```

## Environment Variables

The Schema Registry is configured primarily via its YAML configuration file (`/etc/axonops-schema-registry/config.yaml`). You can override this by mounting a custom config file.

| Variable | Description | Default |
|----------|-------------|---------|
| `SR_PORT` | API port for healthcheck script | `8081` |
| `HEALTH_CHECK_TIMEOUT` | Healthcheck timeout in seconds | `10` |

**Custom Configuration:**

Mount a custom config file to override the default:

```bash
docker run -d --name schema-registry \
  -v /path/to/config.yaml:/etc/axonops-schema-registry/config.yaml:ro \
  -p 8081:8081 \
  ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
```

## Container Features

### Entrypoint Script

The entrypoint script (`/usr/local/bin/docker-entrypoint.sh`) displays the startup banner and then executes the main process. It runs via [tini](https://github.com/krallin/tini) for proper signal handling and zombie process reaping.

```dockerfile
ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["axonops-schema-registry", "--config", "/etc/axonops-schema-registry/config.yaml"]
```

Process tree:
```
tini (PID 1)
  └── docker-entrypoint.sh
       └── axonops-schema-registry (after exec)
```

### Startup Version Banner

All containers display comprehensive version information on startup:

```
================================================================================
AxonOps Schema Registry 0.2.0
Image: ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
Built: 2025-12-13T10:30:00Z
Release: https://github.com/axonops/axonops-containers/releases/tag/axonops-schema-registry-0.2.0-0.0.1
Built by: GitHub Actions
================================================================================

Component Versions:
  Schema Registry:    0.2.0
  Binary Version:     v0.2.0
  Container Version:  0.0.1
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI)
  Platform:           x86_64

Supply Chain Security:
  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest
  Base image digest:  sha256:6fc28bcb6776e387...

Runtime Environment:
  Hostname:           schema-registry-1

================================================================================
Starting Schema Registry...
================================================================================
```

**View the banner:**
```bash
docker logs schema-registry | head -25
```

### Healthcheck Probes

The container includes a healthcheck script supporting three probe types:

**1. Startup Probe** (`healthcheck.sh startup`)
- Checks if Schema Registry process is running (`pgrep`)
- Checks if API port responds to HTTP requests
- Use for: Kubernetes `startupProbe`

**2. Liveness Probe** (`healthcheck.sh liveness`)
- Checks if Schema Registry process is running (`pgrep`)
- Ultra-lightweight, runs frequently
- Use for: Kubernetes `livenessProbe`

**3. Readiness Probe** (`healthcheck.sh readiness`)
- Full HTTP health check against `GET /` endpoint
- Verifies HTTP 200 response
- Use for: Kubernetes `readinessProbe` and Docker HEALTHCHECK

**Docker healthcheck:**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect schema-registry --format='{{json .State.Health}}' | jq
```

**Manual healthcheck testing:**
```bash
# Test startup probe
docker exec schema-registry /usr/local/bin/healthcheck.sh startup

# Test liveness probe
docker exec schema-registry /usr/local/bin/healthcheck.sh liveness

# Test readiness probe
docker exec schema-registry /usr/local/bin/healthcheck.sh readiness
```

## CI/CD Pipeline

### Workflows

**Build and Test** (`.github/workflows/axonops-schema-registry-build-and-test.yml`)
- **Triggers:** Push/PR to main/development/feature/*/fix/* branches
  - When `axonops-schema-registry/**` changes (excluding `*.md` files)
  - When workflows (`.github/workflows/axonops-schema-registry-*.yml`) change
  - When actions (`.github/actions/axonops-schema-registry-*/**`) change
- **Tests:** Docker build, version verification, healthcheck, API tests, security scanning
- **Runtime:** ~5 minutes

**Production Publish** (`.github/workflows/axonops-schema-registry-publish-signed.yml`)
- **Trigger:** Manual workflow dispatch with git tag
- **Process:** Validate -> Test -> Create Release -> Build -> Sign -> Publish -> Verify
- **Registry:** `ghcr.io/axonops/axonops-schema-registry`
- **Platforms:** linux/amd64, linux/arm64
- **Signing:** Cosign keyless signing (OIDC)

**Development Publish** (`.github/workflows/axonops-schema-registry-development-publish-signed.yml`)
- **Trigger:** Manual workflow dispatch from development branch
- **Registry:** `ghcr.io/axonops/development/axonops-schema-registry`
- **Use:** Testing images before production release

### Automated Testing

The CI pipeline includes:

**Functional Tests:**
- Container build verification (multi-arch)
- Startup banner verification (production vs development)
- Version verification (SR version, container version)
- Healthcheck script tests (startup, liveness, readiness)
- Schema Registry API tests (GET /)

**Security Tests:**
- Trivy container vulnerability scanning (CRITICAL and HIGH severity)
- Results uploaded to GitHub Security tab
- Known upstream CVEs documented in `.trivyignore`

### Publishing Process

**Development Release:**
```bash
# Tag on development branch
git checkout development
git pull origin development
git tag vdev-axonops-schema-registry-0.2.0-0.0.1
git push origin vdev-axonops-schema-registry-0.2.0-0.0.1

# Publish to development registry
gh workflow run axonops-schema-registry-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=vdev-axonops-schema-registry-0.2.0-0.0.1 \
  -f sr_version=0.2.0 \
  -f container_version=0.0.1
```

**Production Release:**
```bash
# Tag on main branch
git checkout main
git pull origin main
git tag axonops-schema-registry-0.2.0-0.0.1
git push origin axonops-schema-registry-0.2.0-0.0.1

# Publish to production registry
gh workflow run axonops-schema-registry-publish-signed.yml \
  --ref main \
  -f main_git_tag=axonops-schema-registry-0.2.0-0.0.1 \
  -f sr_version=0.2.0 \
  -f container_version=0.0.1
```

See [RELEASE.md](./RELEASE.md) for complete release process documentation.

## Troubleshooting

### Checking Container Version

View the startup banner to see all component versions:

```bash
docker logs schema-registry | head -25
```

### Healthcheck Debugging

Test healthcheck probes manually:

```bash
# Test all three probe types
docker exec schema-registry /usr/local/bin/healthcheck.sh startup
docker exec schema-registry /usr/local/bin/healthcheck.sh liveness
docker exec schema-registry /usr/local/bin/healthcheck.sh readiness

# Check Docker healthcheck status
docker inspect schema-registry --format='{{json .State.Health}}' | jq

# Test API directly
curl -s http://localhost:8081/
```

### Container Not Starting

**Check logs:**
```bash
docker logs schema-registry
```

**Common issues:**

1. **Port conflicts:**
   - Schema Registry API: 8081
   - Check with: `netstat -tuln | grep 8081`

2. **Permission issues:**
   - Container runs as `schemaregistry` user (UID 999)
   - Ensure volume permissions: `chown -R 999:999 /data/schema-registry`

3. **Configuration issues:**
   - Verify config file: `docker exec schema-registry cat /etc/axonops-schema-registry/config.yaml`

## Production Considerations

1. **Persistent Storage**
   - Use volumes for `/var/lib/axonops-schema-registry` (data)
   - Use volumes for `/var/log/axonops-schema-registry` (logs)

2. **Resource Allocation**
   - Memory: ~50MB typical, allocate 256MB minimum
   - CPU: 1 core is sufficient for most workloads

3. **Networking**
   - Expose port 8081 for Schema Registry API
   - Use proper firewall rules

4. **Security**
   - Verify container signatures with Cosign
   - Use digest-based image references for immutability
   - Keep base images updated

5. **Monitoring**
   - Use healthcheck probes for availability monitoring
   - Monitor API response times via `GET /`
   - Set up log aggregation for `/var/log/axonops-schema-registry/`

6. **High Availability**
   - Schema Registry is stateless when using external storage backends
   - Run multiple instances behind a load balancer for HA

For development workflow and testing, see [DEVELOPMENT.md](./DEVELOPMENT.md).

For release process, see [RELEASE.md](./RELEASE.md).
