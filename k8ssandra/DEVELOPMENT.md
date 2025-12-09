# K8ssandra Container Development Guide

This document covers k8ssandra-specific development practices, workflows, and testing.

## Workflows

### Build and Test (`k8ssandra-build-and-test.yml`)
**Purpose:** Docker build verification and functional testing

**Triggers:**
- Push to `main` or `development` branch (with `k8ssandra/**` changes)
- Pull requests to `main` or `development`

**What it tests:**
- Container build verification (5.0.6 first, then 5.0.1-5.0.5 in parallel)
- Base image verification
- Service health checks (liveness/readiness via Management API)
- Version verification (jemalloc, Cassandra, Java)
- Management API endpoints and Java agent operations
- AxonOps agent process verification
- cqlai installation and CQL operations
- Security scanning (Trivy)
- Process ownership (non-root)

**Runtime:** ~7-10 minutes

---

### E2E Test (`k8ssandra-e2e-test.yml`)
**Purpose:** End-to-end Kubernetes deployment testing with AxonOps SaaS integration

**Triggers:**
- Manual via GitHub Actions UI or `gh workflow run k8ssandra-e2e-test.yml`

**What it tests:**
1. k3s cluster setup on GitHub Actions runner
2. K8ssandra operator installation (cert-manager + operator)
3. K8ssandraCluster deployment with AxonOps agent configuration
4. Credential retrieval from k8ssandra secrets
5. Management API verification via port-forward
6. AxonOps agent verification (process, logs, env vars)
7. cqlai tests with authentication
8. CQL smoke tests with cqlsh

**Workflow inputs:**
- `container_image` - Image to test (default: latest release)
- `cassandra_version` - Cassandra version (default: 5.0.6)

**Runtime:** ~3-4 minutes

**Cluster configuration:**
- Name: `github-ci-<version>-<run_id>`
- Single-node cluster (minimized resources for GitHub runner)
- Heap: 1GB
- Storage: 2Gi Cassandra data, 512Mi AxonOps data
- Authentication: Enabled (k8ssandra default)

**Uses secrets/variables:**
- `AXONOPS_AGENT_KEY` (secret)
- `AXONOPS_AGENT_ORG` (variable)
- `AXONOPS_SERVER` (variable)

---

### Security Scan (`k8ssandra-nightly-security-scan.yml`)
**Purpose:** Daily CVE scanning of published container images

**Triggers:**
- Scheduled: Daily at 2 AM UTC
- Manual via GitHub Actions UI

**What it scans:**
- All published 5.0.x versions (5.0.1 through 5.0.6)
- CRITICAL and HIGH severity vulnerabilities
- OS and library packages

**Email notifications:**
- Sent if any CVEs detected
- Recipients configured via `SECURITY_EMAIL` variable
- Gmail SMTP integration

**Runtime:** ~2-3 minutes per version (6 versions in parallel)

---

### Production Publish (`k8ssandra-publish-signed.yml`)
**Purpose:** Build and publish production container images to GHCR

**Triggers:**
- Manual only

**Inputs:**
- `main_git_tag` - Git tag on main branch (e.g., 1.0.4)
- `container_version` - Container version for GHCR (e.g., 1.0.4)

**Process:**
1. Validate tag is on main branch
2. Check container version doesn't exist in GHCR
3. Run full test suite on 5.0.6
4. Build and push multi-arch images for all 5.0.x versions
5. Create GitHub Release

See [RELEASE.md](./RELEASE.md) for complete instructions.

---

### Development Publish (`k8ssandra-development-publish-signed.yml`)
**Purpose:** Publish development builds for testing before production

**Triggers:**
- Manual only (development branch)

**Published to:**
- `ghcr.io/axonops/development/k8ssandra/cassandra:<version>-<tag>`

**Use for:**
- Testing containers before promoting to production
- Validating changes in real environments

---

## Composite Actions

K8ssandra uses composite actions to avoid duplication and enable reusability.

### Docker-based Actions
Located in `.github/actions/k8ssandra-*/`

- `k8ssandra-verify-base-image` - Verify correct base image used
- `k8ssandra-start-and-wait` - Start container and wait for readiness
- `k8ssandra-verify-versions` - Verify jemalloc, Cassandra, Java versions
- `k8ssandra-test-management-api` - Test Management API endpoints
- `k8ssandra-verify-axonops` - Verify AxonOps agent in Docker container
- `k8ssandra-test-cqlai` - Test cqlai in Docker container
- `k8ssandra-collect-logs` - Collect container logs

### Kubernetes-based Actions
Located in `.github/actions/k8ssandra-k3s-*/` and `.github/actions/k8ssandra-*-operator/`

- `k8ssandra-setup-k3s` - Setup k3s cluster with k3d
- `k8ssandra-install-operator` - Install cert-manager and K8ssandra operator
- `k8ssandra-deploy-cluster` - Deploy K8ssandraCluster with AxonOps config
- `k8ssandra-k3s-test-management-api` - Test Management API in Kubernetes (port-forward)
- `k8ssandra-k3s-verify-axonops` - Verify AxonOps agent in Kubernetes pod
- `k8ssandra-k3s-test-cqlai` - Test cqlai in Kubernetes pod

### Action Naming Convention
- Prefix with `k8ssandra-` for component identification
- Use `-k3s-` infix for Kubernetes-specific actions (e.g., `k8ssandra-k3s-test-cqlai`)
- Docker actions have no infix (e.g., `k8ssandra-test-cqlai`)

This allows reuse across different testing contexts (Docker vs Kubernetes) while maintaining clear naming.

---

## Container Features

### Startup Version Banner
All k8ssandra containers display comprehensive version information on startup.

**Implementation:**
- Build-time: Dockerfile writes `/etc/axonops/build-info.txt` with all static versions
- Runtime: Entrypoint sources file and prints banner before starting Cassandra
- Safe: Never fails startup - errors caught with fallback message

**Information displayed:**
- Container version and git revision
- Cassandra, Java versions
- AxonOps agent versions (standalone + Java agent)
- cqlai, jemalloc versions
- OS and platform
- Kubernetes detection
- AxonOps configuration status

See k8ssandra/README.md "Container Features" section for example output.

---

## Testing Locally

### Docker Build Test
```bash
cd k8ssandra/5.0
podman build \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg MAJOR_VERSION=5.0 \
  --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  --build-arg VERSION=local-test \
  -t test-image:local \
  .
```

### View Startup Banner
```bash
podman run --rm -e AXON_AGENT_KEY=test -e AXON_AGENT_ORG=test test-image:local 2>&1 | head -40
```

### Run E2E Tests Locally
E2E tests run on GitHub Actions with k3s - not designed for local execution.

To test E2E workflow:
```bash
gh workflow run k8ssandra-e2e-test.yml
gh run watch
```

---

## Troubleshooting Development

### Build Failures
- Check base image availability: `docker pull k8ssandra/cass-management-api:5.0-ubi`
- Verify build args passed correctly
- Check AxonOps yum repo accessibility
- Review cqlai GitHub release availability

### Test Failures
- Check container logs: `docker logs <container>`
- Verify all services started (Management API on port 8080)
- Check AxonOps agent process: `docker exec <container> ps aux | grep axon`
- Review startup banner for version mismatches

### E2E Test Failures
- Check GitHub Actions logs for specific failure step
- k3s setup issues: May need different k3s version
- Operator install issues: Check cert-manager ready
- Cluster deployment issues: Check pod logs and K8ssandraCluster status
- Agent issues: Verify secrets/variables configured correctly

---

## Adding New Cassandra Versions

When k8ssandra releases a new Cassandra version:

1. **Check if new major.minor version:**
   - If yes: Create new directory `k8ssandra/<major.minor>/`
   - If patch: Use existing directory

2. **Update Dockerfile:**
   - Update `CASSANDRA_VERSION` ARG default if needed
   - Test build with new version

3. **Update workflows:**
   - Add version to test matrix in `k8ssandra-build-and-test.yml`
   - Add version to publish matrix in `k8ssandra-publish-signed.yml`
   - Add version to security scan matrix

4. **Update documentation:**
   - Update "Supported Cassandra Versions" section in README
   - Update example commands with new version

5. **Test:**
   - Run build-and-test workflow
   - Run E2E test workflow
   - Verify all tests pass

6. **Publish:**
   - Follow RELEASE.md process

---

## Resources

- GitHub runner specs: 4 CPU, 7GB RAM (sufficient for k3s + single-node Cassandra)
- k3s startup: ~20-30 seconds
- Cassandra startup in k3s: ~2 minutes
- Total E2E test: ~3-4 minutes
