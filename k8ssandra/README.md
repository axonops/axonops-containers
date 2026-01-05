# AxonOps K8ssandra Containers

[![GHCR Package](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra)

Docker containers for Apache Cassandra with integrated AxonOps monitoring and management agent, designed for deployment on Kubernetes using K8ssandra Operator.

## Table of Contents

- [Overview](#overview)
- [Pre-built Docker Images](#pre-built-docker-images)
  - [Available Images](#available-images)
  - [Supported Cassandra Versions](#supported-cassandra-versions)
- [Production Best Practice](#-production-best-practice)
- [Quick Start with Docker/Podman](#quick-start-with-dockerpodman)
  - [Using with Kubernetes](#using-with-kubernetes-k8ssandra)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Building Docker Images](#building-docker-images)
  - [Adding Support for New Cassandra Versions](#adding-support-for-new-cassandra-versions)
  - [Updating for New k8ssandra Management API Versions](#updating-for-new-k8ssandra-management-api-versions)
- [Deploying to Kubernetes](#deploying-to-kubernetes)
  - [Using the Example Configuration](#using-the-example-configuration)
  - [Verifying the Deployment](#verifying-the-deployment)
  - [Connecting to the Cluster](#connecting-to-the-cluster)
  - [Key Configuration Options](#key-configuration-options)
- [Configuration](#configuration)
  - [AxonOps Agent Configuration](#axonops-agent-configuration)
  - [Container Environment Variables](#container-environment-variables)
- [Scripts Reference](#scripts-reference)
  - [scripts/install_k8ssandra.sh](#scriptsinstall_k8ssandrash)
  - [scripts/rebuild.sh](#scriptsrebuildsh)
- [Examples](#examples)
  - [examples/axon-cluster.yml](#examplesaxon-clusteryml)
  - [Customizing the Example](#customizing-the-example)
- [CI/CD Pipeline](#cicd-pipeline)
  - [Automated Builds and Testing](#automated-builds-and-testing)
- [Container Features](#container-features)
  - [Startup Version Banner](#startup-version-banner)
- [Monitoring with AxonOps](#monitoring-with-axonops)
- [Troubleshooting](#troubleshooting)
  - [Checking Container Version](#checking-container-version)
  - [Agent Connection Issues](#agent-connection-issues)
  - [Image Pull Errors](#image-pull-errors)
  - [Cluster Not Starting](#cluster-not-starting)
- [Production Considerations](#production-considerations)

## Overview

This repository provides pre-configured Docker images that combine:
- Apache Cassandra 5.0.x
- K8ssandra Management API
- AxonOps Agent for monitoring and management
- [cqlai](https://github.com/axonops/cqlai) - Modern CQL shell

These containers are optimized for Kubernetes deployments using the K8ssandra Operator and include automated CI/CD pipelines for building and publishing to GitHub Container Registry.

**Note:** Currently only Cassandra 5.0 versions are published. Cassandra 4.0 and 4.1 support is available in the repository but not yet published due to AxonOps agent compatibility issues. Please reach out if you need 4.0 or 4.1 support.

## Pre-built Docker Images

Pre-built images are available from GitHub Container Registry (GHCR). This is the easiest way to get started.

### Available Images

Images use a 3-dimensional tagging strategy with k8ssandra API version tracking:

| Tag Pattern | Example | Description | Use Case |
|-------------|---------|-------------|----------|
| `{CASS}-v{K8S_API}-{AXON}` | `5.0.6-v0.1.110-1.0.0` | Fully immutable (all 3 versions) | **Production**: Pin exact versions for complete auditability |
| `@sha256:<digest>` | `@sha256:412c852...` | Digest-based (immutable) | **Highest Security**: Cryptographically guaranteed image (see [Gold Standard Security](../README.md#gold-standard-security-deployment)) |
| `{CASS}-v{K8S_API}` | `5.0.6-v0.1.110` | Latest AxonOps for this Cassandra + k8ssandra combo | Track AxonOps updates for specific Cassandra + k8ssandra versions |
| `{CASS}` | `5.0.6` | Latest k8ssandra API + AxonOps for this Cassandra minor | Track k8ssandra + AxonOps updates for a Cassandra minor |
| `{MAJOR}-latest` | `5.0-latest` | Latest minor in Cassandra major 5.0 | Track latest Cassandra 5.0.x minor + components |
| `latest` | `latest` | Latest across all Cassandra majors | Quick trials (migrates to 5.1, 5.2, 6.0 when released) |

**Versioning Dimensions:**
- **CASS** - Cassandra version (e.g., 5.0.6)
- **K8S_API** - k8ssandra Management API version (e.g., v0.1.110)
- **AXON** - AxonOps container version (e.g., 1.0.0, SemVer)

**Tagging Examples:**

When `5.0.6-v0.1.110-1.0.0` is built (and it's the latest of everything):
- `5.0.6-v0.1.110-1.0.0` (immutable - never changes)
- `5.0.6-v0.1.110` (floating - retags to newer AxonOps builds)
- `5.0.6` (floating - retags when k8ssandra API or AxonOps updates)
- `5.0-latest` (floating - retags when newer 5.0.x minor released, e.g., 5.0.7)
- `latest` (floating - **moves to 5.1, 5.2, 6.0 when new Cassandra major released**)

### Supported Cassandra Versions

**Currently Supported:**
- **5.0.x:** 5.0.1, 5.0.2, 5.0.3, 5.0.4, 5.0.5, 5.0.6 (6 versions)

**Future Support:**
- **4.0.x and 4.1.x:** Available in repository but not yet published due to AxonOps agent compatibility issues. Reach out if you need these versions.

Browse all available tags: [GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra)

## 💡 Production Best Practice

⚠️ **Using ANY `-latest` tags in production is an anti-pattern**. This includes `latest`, `5.0-latest`, and `5.0.6-latest` because:
- **No audit trail**: You cannot determine which exact version was deployed at a given time
- **Unexpected updates**: Kubernetes may pull a new image during pod restarts, causing unintended version changes
- **Rollback difficulties**: You cannot reliably roll back to a previous version
- **Compliance issues**: Many compliance frameworks require immutable version tracking

👍 **Recommended Deployment Strategies (in order of security):**

1. **🥇 Gold Standard - Digest-Based** (Highest Security)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra@sha256:412c852252ec4ebcb8d377a505881828a7f6a5f9dc725cc4f20fda2a1bcb3494"
   ```
   - 100% immutable, cryptographically guaranteed
   - Required for regulated environments
   - See [Gold Standard Security Deployment](../README.md#gold-standard-security-deployment)

2. **🥈 Immutable Tag** (Production Standard)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5"
   ```
   - Pinned to specific version (Cassandra 5.0.6 + k8ssandra API v0.1.110 + AxonOps 1.0.5)
   - Easy to read and manage
   - Full audit trail maintained

3. **🥉 Latest Tags** (Development/Testing Only)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra:latest"
   ```
   - Fast iteration
   - NOT for production
   - Use for POCs and testing only

**CVE Management:** See [CVE Policy](../README.md#cve-policy) for how we handle security vulnerabilities and version releases.

**Image Updates with K8ssandra:** When you update the container image in your K8ssandraCluster manifest, the K8ssandra Operator handles the rolling update process. See the [K8ssandra Operator documentation](https://docs.k8ssandra.io/) for details on upgrade procedures and best practices.

## Quick Start with Docker/Podman

Run a single-node Cassandra instance locally for testing:

```bash
# Pull the latest 5.0 image (TESTING ONLY - not for production!)
# Note: 5.0-latest is a floating tag that points to the latest 5.0.x minor + components
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0-latest

# Run with AxonOps agent (replace with your credentials)
docker run -d --name cassandra \
  -e AXON_AGENT_KEY="your-axonops-agent-key" \
  -e AXON_AGENT_ORG="your-organization" \
  -e AXON_AGENT_SERVER_HOST="agents.axonops.cloud" \
  -p 9042:9042 \
  -p 8080:8080 \
  ghcr.io/axonops/k8ssandra/cassandra:5.0-latest

# Wait for Cassandra to be ready (check Management API)
curl http://localhost:8080/api/v0/probes/readiness

# Connect using cqlai (included in the image)
docker exec -it cassandra cqlai
```

**⚠️ For production use, pin to a specific immutable version:**
```bash
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

### Using with Kubernetes (K8ssandra)

For Kubernetes deployments, use the image with K8ssandra Operator:

```bash
export IMAGE_NAME="ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5"
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"

cat examples/axon-cluster.yml | envsubst | kubectl apply -f -
```

See [Deploying to Kubernetes](#deploying-to-kubernetes) for detailed instructions.

## Prerequisites

- Kubernetes cluster (local or cloud)
- kubectl configured to access your cluster
- Helm 3.x
- Docker (for local builds)
- envsubst (for environment variable substitution in YAML files)
  - macOS: `brew install gettext`
  - Linux: Usually pre-installed, or `apt install gettext` / `yum install gettext`
- AxonOps account with valid API key and organization ID (see [AxonOps Cloud Setup Guide](https://docs.axonops.com/get_started/cloud/))

## Supported Cassandra Versions

### Cassandra 5.0 (Currently Supported)
- Base Image: `k8ssandra/cass-management-api:5.0-ubi`
- Supported versions: 5.0.1, 5.0.2, 5.0.3, 5.0.4, 5.0.5, 5.0.6 (6 versions)
- JDK: JDK17
- Includes: AxonOps Agent, cqlai, jemalloc
- Location: `k8ssandra/5.0/` directory

### Cassandra 4.1 (Available but not published)
- Base Image: `k8ssandra/cass-management-api:4.1-ubi`
- Status: Code ready in `k8ssandra/4.1/` but not published due to AxonOps agent compatibility issues
- JDK: JDK11
- Contact us if you need 4.1 support

### Cassandra 4.0 (Available but not published)
- Base Image: `k8ssandra/cass-management-api:4.0-ubi`
- Status: Code ready in `k8ssandra/4.0/` but not published due to AxonOps agent compatibility issues
- JDK: JDK11
- Contact us if you need 4.0 support

## Getting Started

**Note:** The following commands assume you are in the `k8ssandra/` directory unless otherwise specified.

### 1. Install K8ssandra Operator

Run the installation script to set up the K8ssandra Operator and required dependencies:

```bash
./scripts/install_k8ssandra.sh
```

This script will:
- Install cert-manager (v1.19.1) in the `cert-manager` namespace
- Add the K8ssandra Helm repository
- Install K8ssandra Operator (v1.29.0) in the `k8ssandra-operator` namespace

### 2. Configure Environment Variables

Set up your AxonOps credentials:

```bash
export AXON_AGENT_KEY="your-axonops-api-key" # Obtained from AxonOps Cloud Console
export AXON_AGENT_ORG="your-organization-id" # AxonOps Cloud organization name
export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"
```

Optional: Specify a custom image name (defaults to ttl.sh with 1-hour TTL):

```bash
export IMAGE_NAME="your-registry/your-image:tag"
```

### 3. Build and Deploy

Use the rebuild script to build, push, and deploy your cluster:

```bash
# Change to the version directory (contains Dockerfile)
cd 5.0

# Run the rebuild script (builds from current directory)
../scripts/rebuild.sh
```

The script will:
1. Delete any existing cluster deployment
2. Clean up old container images
3. Build a new Docker image
4. Push the image to the registry
5. Apply the cluster configuration with environment variable substitution
6. Deploy the cluster to Kubernetes

## Building Docker Images

**Note:** Commands in this section assume you are in the `k8ssandra/` directory.

If you prefer to build images yourself instead of using the [pre-built images](#pre-built-docker-images):

```bash
cd 5.0

# Minimal build (required args only)
docker build \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg MAJOR_VERSION=5.0 \
  --build-arg K8SSANDRA_BASE_DIGEST=sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af \
  --build-arg K8SSANDRA_API_VERSION=0.1.110 \
  --build-arg CQLAI_VERSION=0.0.31 \
  -t your-registry/axonops-cassandra:5.0.6-v0.1.110-1.0.0 \
  .

docker push your-registry/axonops-cassandra:5.0.6-v0.1.110-1.0.0
```

**Required build arguments (must provide):**
- `CASSANDRA_VERSION` - Full Cassandra version (e.g., 5.0.6)
- `MAJOR_VERSION` - Major.minor version matching the directory (e.g., 5.0)
- `K8SSANDRA_BASE_DIGEST` - SHA256 digest of k8ssandra base image (supply chain security)
- `K8SSANDRA_API_VERSION` - k8ssandra Management API version (e.g., 0.1.110)
- `CQLAI_VERSION` - Version of cqlai to install (see [latest release](https://github.com/axonops/cqlai/releases))

**Optional build arguments (will default to "unknown" if not provided):**
- `BUILD_DATE` - Build timestamp (ISO 8601 format, e.g., `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF` - Git commit SHA (e.g., `$(git rev-parse HEAD)`)
- `VERSION` - Container version (e.g., 1.0.0)
- `GIT_TAG` - Git tag name (for release/tag links in banner)
- `GITHUB_ACTOR` - Username who triggered build (for audit trail)
- `IS_PRODUCTION_RELEASE` - Set to `true` for production (default: `false`)
- `IMAGE_FULL_NAME` - Full image name with tag (displayed in startup banner)

**Note:** Optional args enhance the startup banner and labels but aren't required for functionality.

### Adding Support for New Cassandra Versions

When a new Cassandra version is released (e.g., 5.0.7), follow these steps:

**1. Get the k8ssandra base image digest:**

```bash
# Find the latest k8ssandra API version for the new Cassandra version
VERSION="5.0.7"
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${VERSION}-ubi" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'].startswith('${VERSION}-ubi-v')]; \
  results.sort(key=lambda x: x['name'], reverse=True); \
  print(f\"Tag: {results[0]['name']}\nDigest: {results[0]['digest']}\") if results else print('Not found')"
```

This will show something like:
```
Tag: 5.0.7-ubi-v0.1.112
Digest: sha256:newdigest123...
```

**2. Update the `K8SSANDRA_VERSIONS` repository variable:**

```bash
# Add the new version+digest to the JSON variable
gh variable set K8SSANDRA_VERSIONS --body '{
  "5.0.1+0.1.110": "sha256:...",
  "5.0.2+0.1.110": "sha256:...",
  ...
  "5.0.6+0.1.110": "sha256:...",
  "5.0.7+0.1.112": "sha256:newdigest123..."
}'
```

**3. Update workflow matrix:**

In `.github/workflows/k8ssandra-*-signed.yml`, add `5.0.7` to the matrix:

```yaml
matrix:
  cassandra_version: [5.0.1, 5.0.2, 5.0.3, 5.0.4, 5.0.5, 5.0.6, 5.0.7]
```

**4. Update `ALL_VERSIONS` env var:**

```yaml
env:
  ALL_VERSIONS: "5.0.1 5.0.2 5.0.3 5.0.4 5.0.5 5.0.6 5.0.7"
```

**5. Test and publish:**

```bash
# Development test
git tag vdev-5.0.7-test
git push origin vdev-5.0.7-test
gh workflow run k8ssandra-development-publish-signed.yml \
  -f dev_git_tag=vdev-5.0.7-test \
  -f container_version=1.0.0

# If tests pass, publish to production via main branch
```

### Updating for New k8ssandra Management API Versions

When k8ssandra releases a new Management API version (e.g., v0.1.111) for existing Cassandra versions:

**1. Get new digests for all affected Cassandra versions:**

```bash
# Check what changed - k8ssandra typically updates all versions together
for version in 5.0.1 5.0.2 5.0.3 5.0.4 5.0.5 5.0.6; do
  echo "=== Cassandra $version ==="
  curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${version}-ubi-v0.1.111" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'] == '${version}-ubi-v0.1.111']; \
  print(f\"  Digest: {results[0]['digest']}\") if results else print('  Not found')"
done
```

**2. Update `K8SSANDRA_VERSIONS` variable with new API version:**

```bash
# Replace or add new composite keys with updated API version
gh variable set K8SSANDRA_VERSIONS --body '{
  "5.0.1+0.1.111": "sha256:new_digest_1...",
  "5.0.2+0.1.111": "sha256:new_digest_2...",
  "5.0.3+0.1.111": "sha256:new_digest_3...",
  "5.0.4+0.1.111": "sha256:new_digest_4...",
  "5.0.5+0.1.111": "sha256:new_digest_5...",
  "5.0.6+0.1.111": "sha256:new_digest_6..."
}'
```

**3. Increment AxonOps container version:**

Since k8ssandra API version is a component update, increment the MINOR version:
- Current: `1.0.0`
- New: `1.1.0` (MINOR bump for component update)

**4. Test and publish:**

```bash
# Test in development
git tag vdev-k8s-api-update
git push origin vdev-k8s-api-update
gh workflow run k8ssandra-development-publish-signed.yml \
  -f dev_git_tag=vdev-k8s-api-update \
  -f container_version=1.1.0

# After tests pass, create production release
git checkout main
git merge development
git tag k8ssandra-1.1.0
git push origin main k8ssandra-1.1.0

gh workflow run k8ssandra-publish-signed.yml \
  -f main_git_tag=k8ssandra-1.1.0 \
  -f container_version=1.1.0
```

**Note:** k8ssandra typically releases new Management API versions monthly. The nightly version checker workflow (future implementation) will detect these automatically.

**⚠️ Supply Chain Security Warning:**

Our Dockerfiles extend from k8ssandra base images using digest pinning (not tags) to prevent supply chain attacks:

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
FROM docker.io/k8ssandra/cass-management-api@sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM docker.io/k8ssandra/cass-management-api:5.0.6-ubi
```

**Why digest pinning matters:**
- Tags can be replaced maliciously (same tag, different malicious image)
- Digests are cryptographically immutable - cannot be changed
- Prevents silent compromise of your container supply chain
- Industry best practice for production container builds

**When extending ANY container image:**
1. Get the digest using: `docker inspect <image:tag> --format='{{.RepoDigests}}'`
2. Use `FROM image@digest` in your Dockerfile
3. Document the version tag in a comment for human readability

**Supply Chain Security:**

Our containers extend from `k8ssandra/cass-management-api` base images. For supply chain security, we pin base images by digest (immutable) rather than tags. The `K8SSANDRA_BASE_DIGEST` maps Cassandra versions to verified image digests, preventing supply chain attacks where upstream images could be replaced maliciously.

Digest mapping for 5.0.x versions (k8ssandra API v0.1.111):
- 5.0.1: `sha256:5cc48bddcb3be29f5c1492408e106417d1455f1182a45f191e99529226135240`
- 5.0.2: `sha256:17a66c0514e290b3428589ec09cff08d449ca888dd21801baf4896168de78432`
- 5.0.3: `sha256:359d2a448aab4d64e9e67978f1496b1aa502f03208866bb6f3a0a28d5426e79c`
- 5.0.4: `sha256:e7cbac800ec3b8f37d7e7952f438544fc2c549a40c072e9074cfdea115925149`
- 5.0.5: `sha256:b0ced4894cc5e9972d00b45d36def9bd7ac87c6a88934344b676849d8672f7ed`
- 5.0.6: `sha256:bc5708b8ac40c2ad027961a2b1e1b70c826468b8b727c30859718ffc24d7ae04`

**How to get digests for new k8ssandra versions:**

When k8ssandra releases a new Cassandra version, retrieve the digest using Docker Hub API:

```bash
# For a specific version (e.g., 5.0.7)
VERSION="5.0.7"
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${VERSION}-ubi" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'].startswith('${VERSION}-ubi')]; \
  [print(f\"Version: {r['name']}\nDigest: {r['digest']}\") for r in results[:1]]"
```

Or get all 5.0.x versions at once:

```bash
for version in 5.0.1 5.0.2 5.0.3 5.0.4 5.0.5 5.0.6; do
  echo "=== Cassandra $version ==="
  curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${version}-ubi" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'].startswith('${version}-ubi')]; \
  [print(f\"  {r['digest']}\") for r in results[:1]]"
  echo ""
done
```

Once you have the digest, update the `K8SSANDRA_VERSIONS` repository variable with the new version+digest composite key.

## Deploying to Kubernetes

**Note:** Commands in this section assume you are in the `k8ssandra/` directory.

### Using the Example Configuration

The `examples/axon-cluster.yml` provides a template for deploying a 3-node Cassandra 5.0 cluster:

```bash
# Set your environment variables
export IMAGE_NAME="your-image"
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"

# Apply the configuration
cat examples/axon-cluster.yml | envsubst | kubectl apply -f -
```

### Verifying the Deployment

After deploying, verify that your cluster is running:

```bash
# Check cluster status
kubectl get k8ssandraclusters -n k8ssandra-operator

# Watch pods come up (wait for all to show Running and Ready)
kubectl get pods -n k8ssandra-operator -w

# Check detailed cluster status
kubectl describe k8ssandracluster <cluster-name> -n k8ssandra-operator
```

All Cassandra pods should show `2/2` in the READY column when fully started.

### Connecting to the Cluster

#### Using cqlsh

Connect directly to a Cassandra pod:

```bash
kubectl exec -it <pod-name> -n k8ssandra-operator -c cassandra -- cqlsh
```

#### External Access (port-forward)

> **Note:** Port-forwarding is suitable for local development and testing. For production environments (AWS, GCP, Azure, etc.), consider using a LoadBalancer service, Ingress controller, or VPN-based access depending on your security requirements.

To connect from outside the Kubernetes cluster (e.g., from your local machine):

1. Get the superuser credentials:
   ```bash
   # Username
   kubectl get secret <cluster-name>-superuser -n k8ssandra-operator -o jsonpath='{.data.username}' | base64 -d

   # Password
   kubectl get secret <cluster-name>-superuser -n k8ssandra-operator -o jsonpath='{.data.password}' | base64 -d
   ```

2. Start port-forwarding:
   ```bash
   kubectl port-forward svc/<cluster-name>-dc1-service 9042:9042 -n k8ssandra-operator
   ```

3. Connect using cqlsh or any CQL client at `localhost:9042` with the credentials from step 1.

#### AxonOps Workbench

[AxonOps Workbench](https://axonops.com/workbench) is a free desktop IDE for developers and DBAs to connect to and manage Cassandra clusters. It provides a modern interface for running queries, browsing schema, and managing your data. Use the port-forward method above to connect Workbench to your Kubernetes-based cluster.

### Key Configuration Options

The example cluster includes:
- **Cluster Size**: 3 nodes in datacenter `dc1`
- **Resources**:
  - CPU: 1 core (request and limit)
  - Memory: 1Gi request, 2Gi limit
- **JVM Settings**:
  - Initial heap: 1G
  - Maximum heap: 1G
- **Storage**:
  - Storage class: `local-path`
  - Size: 2Gi per node
  - Access mode: ReadWriteOnce
- **Anti-affinity**: Soft pod anti-affinity enabled

## Configuration

### AxonOps Agent Configuration

The AxonOps agent is configured via environment variables passed to the Cassandra container:

| Variable | Description | Default |
|----------|-------------|---------|
| `AXON_AGENT_KEY` | Your AxonOps agent key | Required |
| `AXON_AGENT_ORG` | Your AxonOps organization ID | Required |
| `AXON_AGENT_SERVER_HOST` | AxonOps server hostname | `agents.axonops.cloud` |
| `AXON_AGENT_LOG_OUTPUT` | Agent log output destination | `std` |
| `AXON_AGENT_ARGS` | Additional agent arguments | - |

### Container Environment Variables

Environment variables are injected into the K8ssandra cluster configuration:

```yaml
containers:
  - name: cassandra
    env:
      - name: AXON_AGENT_KEY
        value: "${AXON_AGENT_KEY}"
      - name: AXON_AGENT_ORG
        value: "${AXON_AGENT_ORG}"
      - name: AXON_AGENT_SERVER_HOST
        value: "${AXON_AGENT_SERVER_HOST}"
```

## Scripts Reference

### scripts/install_k8ssandra.sh

Installs the K8ssandra Operator and its prerequisites.

**Usage:**
```bash
./scripts/install_k8ssandra.sh
```

**What it does:**
- Installs cert-manager using Helm
- Adds K8ssandra Helm repository
- Installs K8ssandra Operator v1.29.0

**No parameters required.**

### scripts/rebuild.sh

Builds, pushes, and deploys a Cassandra cluster with AxonOps integration.

> **Note:** This script is designed for Kubernetes environments with direct node access using `crictl`. It may not work on local development setups like minikube, kind, or Docker Desktop. For local development, see the manual build and deploy steps in the [Building Docker Images](#building-docker-images) and [Deploying to Kubernetes](#deploying-to-kubernetes) sections.

**Usage:**
```bash
export IMAGE_NAME="your-registry/image:tag"  # Optional, defaults to ttl.sh
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_SERVER_HOST="your-host"  # Optional

# Change to version directory (script runs docker build from here)
cd 5.0
../scripts/rebuild.sh
```

**What it does:**
1. Generates a unique image name if not provided (using ttl.sh with 1-hour TTL)
2. Deletes existing cluster deployment
3. Cleans up old container images using crictl
4. Builds new Docker image
5. Pushes image to registry
6. Pulls image using crictl
7. Substitutes environment variables in `cluster-axonops.yaml` (copy from [examples/axon-cluster.yml](examples/axon-cluster.yml))
8. Deploys the updated cluster configuration

**Environment Variables:**
- `IMAGE_NAME`: Docker image name (optional)
- `AXON_AGENT_KEY`: AxonOps API key (required in cluster config)
- `AXON_AGENT_ORG`: AxonOps organization (required in cluster config)
- `AXON_AGENT_SERVER_HOST`: AxonOps host (required in cluster config)

## Examples

### examples/axon-cluster.yml

A complete K8ssandraCluster resource definition showcasing:

**Cluster Specifications:**
- Name: `axonops-k8ssandra-50`
- Namespace: `k8ssandra-operator`
- Cassandra Version: 5.0.6
- Image: `ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0` (default)
- Datacenter: `dc1` with 3 nodes

**Resource Allocation:**
```yaml
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 1
    memory: 1Gi
```

**Storage Configuration:**
```yaml
storageConfig:
  cassandraDataVolumeClaimSpec:
    storageClassName: local-path
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 2Gi
```

**AxonOps Volume (Required):**

AxonOps requires a persistent volume to store its configuration. Add this to your cluster configuration:

```yaml
        extraVolumes:
          pvcs:
            - name: axonops-data
              mountPath: /var/lib/axonops
              pvcSpec:
                accessModes:
                  - ReadWriteOnce
                resources:
                  requests:
                    storage: 512Mi
```

**AxonOps Integration:**
The example shows proper environment variable injection for the AxonOps agent using the container-level environment variables approach required by K8ssandra.

### Customizing the Example

**Note:** Commands in this section assume you are in the `k8ssandra/` directory.

To use this example:

1. Copy the example file:
   ```bash
   cp examples/axon-cluster.yml my-cluster.yml
   ```

2. Update the values in `my-cluster.yml`:
   - **Cluster name**: Edit the `metadata.name` field (e.g., change `axonops-k8ssandra-50` to `my-cassandra-cluster`). Note: The cluster name is used to generate service names, secret names, and pod names.
   - **Namespace**: Edit `metadata.namespace` if deploying to a different namespace
   - **Node count**: Adjust `size` under `datacenters` (default is 3)
   - **Resources**: Modify CPU/memory allocations under `resources`
   - **Storage**: Update `storage` size under `storageConfig`

3. Deploy:
   ```bash
   export AXON_AGENT_KEY="your-key"
   export AXON_AGENT_ORG="your-org"
   export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"
   # Optional: Override default image
   export IMAGE_NAME="ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0"

   cat my-cluster.yml | envsubst | kubectl apply -f -
   ```

**Note:** The example uses the new image format `5.0.6-v0.1.110-1.0.0` which includes:
- Cassandra version: 5.0.6
- k8ssandra API version: v0.1.110
- AxonOps container version: 1.0.0

## CI/CD Pipeline

### Automated Builds and Testing

The repository includes comprehensive GitHub Actions workflows for building, testing, and publishing Docker images.

**Workflows:**
- **Build and Test:** `.github/workflows/k8ssandra-build-and-test.yml` - Docker build tests with full validation
- **E2E Testing:** `.github/workflows/k8ssandra-e2e-test.yml` - End-to-end Kubernetes deployment testing
- **Security Scanning:** `.github/workflows/k8ssandra-nightly-security-scan.yml` - Daily CVE scanning with email alerts
- **Production Publish (Signed):** `.github/workflows/k8ssandra-publish-signed.yml` - Manual production releases with Cosign signing
- **Development Publish (Signed):** `.github/workflows/k8ssandra-development-publish-signed.yml` - Development builds with Cosign signing

**Build and Test Workflow Triggers:**
- Push to `development` or `main` branch (with `k8ssandra/**` changes)
- Pull requests to `development` or `main` (with `k8ssandra/**` changes)

**E2E Test Workflow:**
- Manual trigger via GitHub Actions UI or `gh workflow run k8ssandra-e2e-test.yml`
- Deploys containers into k3s cluster on GitHub Actions runner
- Tests Management API, AxonOps agent, cqlai, and CQL operations
- Validates AxonOps SaaS connectivity
- Runtime: ~3-4 minutes

**Security Scan Workflow:**
- Scheduled: Daily at 2 AM UTC
- Manual trigger via GitHub Actions UI
- Scans all published versions for CVEs
- Email notifications on detection of CRITICAL or HIGH severity issues

**Publish Workflows:**
- Manual trigger via GitHub Actions UI or `gh` CLI
- Requires git tag and container version
- See [RELEASE.md](./RELEASE.md) for detailed instructions

**Test Suite:**
The CI pipeline includes comprehensive testing:
- Tests run for 5.0.6 first, then other 5.0 versions in parallel (5.0.1-5.0.5)
- Management API health checks (liveness, readiness)
- Management API Java agent operations (create keyspace, table, flush, compact)
- CQL operations using cqlai (CREATE, INSERT, SELECT, DROP)
- AxonOps agent process verification
- jemalloc verification (no warnings, successful loading)
- Java version verification (JDK17 for 5.0)
- Trivy container security scanning
  - Known upstream CVEs are documented in `.trivyignore`
  - See [.trivyignore](./.trivyignore) for list of suppressed vulnerabilities

**Publishing Process:**
1. Developer creates git tag (e.g., `git tag 1.0.0 && git push origin 1.0.0`)
2. Developer triggers publish workflow via GitHub UI or `gh workflow run`
3. Workflow validates version doesn't exist in GHCR
4. Full test suite runs on 5.0.6 first to validate
5. Multi-arch images (amd64, arm64) built for all 6 versions (max 3 concurrent)
6. Images pushed to GHCR with version-specific and latest tags
7. GitHub Release created automatically

For complete release instructions, see [RELEASE.md](./RELEASE.md)

**Image Tags:**
Each release uses 3-dimensional tagging with k8ssandra API version tracking:

```
ghcr.io/axonops/k8ssandra/cassandra:{CASS}-v{K8S_API}-{AXON}  # Fully immutable (all 3 versions)
ghcr.io/axonops/k8ssandra/cassandra:{CASS}-v{K8S_API}         # Latest AxonOps for this Cassandra + k8ssandra combo
ghcr.io/axonops/k8ssandra/cassandra:{CASS}                    # Latest k8ssandra API + AxonOps for this Cassandra minor
ghcr.io/axonops/k8ssandra/cassandra:{MAJOR}-latest            # Latest minor in Cassandra major
ghcr.io/axonops/k8ssandra/cassandra:latest                    # Latest across all Cassandra majors
```

**Example:** For Cassandra `5.0.6`, k8ssandra API `v0.1.110`, and AxonOps `1.0.0` release:

**Fully immutable tags** (1 per Cassandra version, 6 total):
- `5.0.1-v0.1.110-1.0.0`, `5.0.2-v0.1.110-1.0.0`, `5.0.3-v0.1.110-1.0.0`, `5.0.4-v0.1.110-1.0.0`, `5.0.5-v0.1.110-1.0.0`, `5.0.6-v0.1.110-1.0.0`

**Floating tags** (track latest AxonOps for Cassandra + k8ssandra combo, 6 total):
- `5.0.1-v0.1.110` → `5.0.1-v0.1.110-1.0.0`
- `5.0.2-v0.1.110` → `5.0.2-v0.1.110-1.0.0`
- `5.0.3-v0.1.110` → `5.0.3-v0.1.110-1.0.0`
- `5.0.4-v0.1.110` → `5.0.4-v0.1.110-1.0.0`
- `5.0.5-v0.1.110` → `5.0.5-v0.1.110-1.0.0`
- `5.0.6-v0.1.110` → `5.0.6-v0.1.110-1.0.0`

**Floating tags** (track latest k8ssandra + AxonOps for each Cassandra minor, 6 total):
- `5.0.1` → `5.0.1-v0.1.110-1.0.0`
- `5.0.2` → `5.0.2-v0.1.110-1.0.0`
- `5.0.3` → `5.0.3-v0.1.110-1.0.0`
- `5.0.4` → `5.0.4-v0.1.110-1.0.0`
- `5.0.5` → `5.0.5-v0.1.110-1.0.0`
- `5.0.6` → `5.0.6-v0.1.110-1.0.0`

**Minor-level latest tag** (1):
- `5.0-latest` → `5.0.6-v0.1.110-1.0.0`

**Global latest tag** (1):
- `latest` → `5.0.6-v0.1.110-1.0.0`

**Total:** 20 tags (6 immutable + 6 k8ssandra-floating + 6 cassandra-floating + 1 minor-latest + 1 global-latest)

## Container Features

### Startup Version Banner

All containers display a comprehensive version banner on startup showing:
- Container build version and git revision
- Cassandra version
- Java version
- AxonOps agent versions (both standalone and Java agent)
- cqlai version
- jemalloc version
- Operating system and platform
- Runtime environment (Kubernetes detection, hostname)
- AxonOps configuration status

**View the banner:**
```bash
# Docker/Podman
docker logs <container-name> | head -30

# Kubernetes
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | head -30
```

**Example output (production release):**
```
================================================================================
AxonOps K8ssandra Apache Cassandra 5.0.6
Image: ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0
Built: 2025-12-09T14:40:13Z
Release: https://github.com/axonops/axonops-containers/releases/tag/1.0.0
Built by: GitHub Actions
================================================================================

Component Versions:
  Cassandra:          5.0.6
  k8ssandra API:      0.1.110
  Java:               OpenJDK Runtime Environment (Red_Hat-17.0.17.0.10-1) (build 17.0.17+10-LTS)
  AxonOps Agent:      2.0.11
  AxonOps Java Agent: axon-cassandra5.0-agent-jdk17-1.0.12-1.noarch
  cqlai:              v0.0.31
  jemalloc:           jemalloc-5.2.1-2.el9.x86_64
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI - Universal Base Image, freely redistributable)
  Platform:           x86_64

Supply Chain Security:
  Base image:         k8ssandra/cass-management-api:5.0.6-ubi-v0.1.110
  Base image digest:  sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af

Runtime Environment:
  Hostname:           demo-dc1-default-sts-0
  Kubernetes:         Yes
    API Server:       10.43.0.1:443
    Pod:              demo-dc1-default-sts-0

AxonOps Configuration:
  Server:             agents.axonops.cloud
  Organization:       my-org
  Agent Key:          ***configured***

================================================================================
Starting Cassandra with Management API and AxonOps Agent...
================================================================================
```

**Production builds** include additional metadata: `Image`, `Release` link, and `Built by` fields. **Development builds** show only the essential fields (`Built` timestamp).

This banner makes debugging customer environments much easier by showing all relevant version information in one place.

## Monitoring with AxonOps

Once deployed, your Cassandra cluster will automatically:
- Register with AxonOps using the provided API key and organization
- Send metrics and logs to the AxonOps platform
- Enable cluster monitoring, alerting, and management features

Access your cluster monitoring at:
- AxonOps Cloud: https://axonops.cloud
- Custom installation: Your configured AxonOps URL

## Troubleshooting

### Checking Container Version

View the startup banner to see all component versions:
```bash
# Kubernetes
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | head -30

# Docker/Podman
docker logs <container-name> | head -30
```

The banner displays container version, git revision, and all component versions which helps identify exactly what's running.

### Agent Connection Issues

Check agent logs:
```bash
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | grep axon
```

Verify environment variables:
```bash
kubectl describe pod <pod-name> -n k8ssandra-operator
```

Check the startup banner shows AxonOps configuration is correct.

### Image Pull Errors

Ensure your image is accessible:
```bash
docker pull $IMAGE_NAME
```

For ttl.sh images, note they expire after 1 hour. Use a persistent registry for production.

### Cluster Not Starting

Check K8ssandra operator logs:
```bash
kubectl logs -n k8ssandra-operator deployment/k8ssandra-operator
```

Verify cluster status:
```bash
kubectl get k8ssandraclusters -n k8ssandra-operator
kubectl describe k8ssandracluster <cluster-name> -n k8ssandra-operator
```

## Production Considerations

1. **Image Registry**: Use a persistent container registry instead of ttl.sh
2. **Resource Sizing**: Adjust CPU, memory, and storage based on workload
3. **High Availability**: Deploy across multiple availability zones
4. **Backup Strategy**: Configure K8ssandra Medusa for backups
5. **Security**:
   - Use secrets for AxonOps credentials instead of environment variables
   - Enable encryption at rest and in transit
   - Configure RBAC and network policies
6. **Monitoring**: Set up alerts in AxonOps for critical metrics
