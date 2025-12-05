# AxonOps K8ssandra Containers

Docker containers for Apache Cassandra with integrated AxonOps monitoring and management agent, designed for deployment on Kubernetes using K8ssandra Operator.

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

Images use a multi-dimensional tagging strategy for flexibility:

| Tag Pattern | Example | Description | Use Case |
|-------------|---------|-------------|----------|
| `{CASSANDRA_VERSION}-{AXONOPS_VERSION}` | `5.0.6-1.0.0` | Immutable, specific version | **Production**: Pin exact versions for auditability |
| `{CASSANDRA_VERSION}-latest` | `5.0.6-latest` | Latest AxonOps version for this Cassandra patch | Track AxonOps updates for a specific Cassandra patch |
| `{CASSANDRA_MINOR}-latest` | `5.0-latest` | Latest patch in this Cassandra minor line | Track latest Cassandra patch in a major version (currently 5.0.6) |
| `latest` | `latest` | Latest across all versions | Quick trials and documentation (currently 5.0.6) |

**Tagging Examples:**

When version `5.0.6-1.0.1` is built, it gets tagged as:
- `5.0.6-1.0.1` (immutable)
- `5.0.6-latest` (retag)
- `5.0-latest` (retag, because 5.0.6 is the highest 5.0.x patch)
- `latest` (retag, because 5.0.6 is the highest overall version)

### Supported Cassandra Versions

**Currently Supported:**
- **5.0.x:** 5.0.1, 5.0.2, 5.0.3, 5.0.4, 5.0.5, 5.0.6 (6 versions)

**Future Support:**
- **4.0.x and 4.1.x:** Available in repository but not yet published due to AxonOps agent compatibility issues. Reach out if you need these versions.

Browse all available tags: [GitHub Container Registry](https://github.com/axonops/axonops-cassandra-containers/pkgs/container/axonops-cassandra-containers)

## 💡 Production Best Practice

⚠️ **Using ANY `-latest` tags in production is an anti-pattern**. This includes `latest`, `5.0-latest`, and `5.0.6-latest` because:
- **No audit trail**: You cannot determine which exact version was deployed at a given time
- **Unexpected updates**: Kubernetes may pull a new image during pod restarts, causing unintended version changes
- **Rollback difficulties**: You cannot reliably roll back to a previous version
- **Compliance issues**: Many compliance frameworks require immutable version tracking

👍 **Always use immutable tags in production** (e.g., `5.0.6-1.0.1`). Use latest tags only for:
- Local development and testing
- Documentation examples
- Quick proof-of-concept deployments

**Image Updates with K8ssandra:** When you update the container image in your K8ssandraCluster manifest, the K8ssandra Operator handles the rolling update process. See the [K8ssandra Operator documentation](https://docs.k8ssandra.io/) for details on upgrade procedures and best practices.

## Quick Start with Docker/Podman

Run a single-node Cassandra instance locally:

```bash
# Pull the image
docker pull ghcr.io/axonops/axonops-cassandra-containers:5.0.6-1.0.0

# Run with AxonOps agent (replace with your credentials)
docker run -d --name cassandra \
  -e AXON_AGENT_KEY="your-axonops-agent-key" \
  -e AXON_AGENT_ORG="your-organization" \
  -e AXON_AGENT_HOST="agents.axonops.cloud" \
  -p 9042:9042 \
  -p 8080:8080 \
  ghcr.io/axonops/axonops-cassandra-containers:5.0.6-1.0.0

# Wait for Cassandra to be ready (check Management API)
curl http://localhost:8080/api/v0/probes/readiness

# Connect using cqlai (included in the image)
docker exec -it cassandra cqlai
```

### Using with Kubernetes (K8ssandra)

For Kubernetes deployments, use the image with K8ssandra Operator:

```bash
export IMAGE_NAME="ghcr.io/axonops/axonops-cassandra-containers:5.0.6-1.0.0"
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_HOST="agents.axonops.cloud"

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
export AXON_AGENT_HOST="agents.axonops.cloud"
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
docker build -t your-registry/axonops-cassandra:5.0.6 .
docker push your-registry/axonops-cassandra:5.0.6
```

## Deploying to Kubernetes

**Note:** Commands in this section assume you are in the `k8ssandra/` directory.

### Using the Example Configuration

The `examples/axon-cluster.yml` provides a template for deploying a 3-node Cassandra 5.0 cluster:

```bash
# Set your environment variables
export IMAGE_NAME="your-image"
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_HOST="agents.axonops.cloud"

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
| `AXON_AGENT_HOST` | AxonOps server hostname | `agents.axonops.cloud` |
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
      - name: AXON_AGENT_HOST
        value: "${AXON_AGENT_HOST}"
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
export AXON_AGENT_HOST="your-host"  # Optional

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
- `AXON_AGENT_HOST`: AxonOps host (required in cluster config)

## Examples

### examples/axon-cluster.yml

A complete K8ssandraCluster resource definition showcasing:

**Cluster Specifications:**
- Name: `axonops-k8ssandra-50`
- Namespace: `k8ssandra-operator`
- Cassandra Version: 5.0.5
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
   export AXON_AGENT_HOST="agents.axonops.cloud"
   export IMAGE_NAME="your-image"

   cat my-cluster.yml | envsubst | kubectl apply -f -
   ```

## CI/CD Pipeline

### Automated Builds

The repository includes a GitHub Actions workflow that automatically builds and publishes Docker images.

**Workflows:**
- Test: `.github/workflows/k8ssandra-build-and-test.yml`
- Publish: `.github/workflows/k8ssandra-publish.yml` (manual)

**Test Workflow Triggers:**
- Push to `main` branch (with `k8ssandra/**` changes)
- Pull requests to `main` (with `k8ssandra/**` changes)

**Publish Workflow:**
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
Each release uses multi-dimensional tagging:

```
ghcr.io/axonops/axonops-cassandra-containers:{CASSANDRA_VERSION}-{AXONOPS_VERSION}  # Immutable
ghcr.io/axonops/axonops-cassandra-containers:{CASSANDRA_VERSION}-latest             # Patch-level latest
ghcr.io/axonops/axonops-cassandra-containers:5.0-latest                             # Minor-level latest
ghcr.io/axonops/axonops-cassandra-containers:latest                                 # Global latest
```

**Example:** For AxonOps release `1.0.1`, a total of 14 tags published:

**Immutable tags** (6):
- `5.0.1-1.0.1`, `5.0.2-1.0.1`, `5.0.3-1.0.1`, `5.0.4-1.0.1`, `5.0.5-1.0.1`, `5.0.6-1.0.1`

**Patch-level latest tags** (6):
- `5.0.1-latest` → `5.0.1-1.0.1`
- `5.0.2-latest` → `5.0.2-1.0.1`
- `5.0.3-latest` → `5.0.3-1.0.1`
- `5.0.4-latest` → `5.0.4-1.0.1`
- `5.0.5-latest` → `5.0.5-1.0.1`
- `5.0.6-latest` → `5.0.6-1.0.1`

**Minor-level latest tag** (1):
- `5.0-latest` → `5.0.6-1.0.1`

**Global latest tag** (1):
- `latest` → `5.0.6-1.0.1`

**Total:** 14 tags (6 immutable + 6 patch-latest + 1 minor-latest + 1 global-latest)

## Monitoring with AxonOps

Once deployed, your Cassandra cluster will automatically:
- Register with AxonOps using the provided API key and organization
- Send metrics and logs to the AxonOps platform
- Enable cluster monitoring, alerting, and management features

Access your cluster monitoring at:
- AxonOps Cloud: https://axonops.cloud
- Custom installation: Your configured AxonOps URL

## Troubleshooting

### Agent Connection Issues

Check agent logs:
```bash
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | grep axon
```

Verify environment variables:
```bash
kubectl describe pod <pod-name> -n k8ssandra-operator
```

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
