# AxonOps Cassandra Containers

Docker containers for Apache Cassandra with integrated AxonOps monitoring and management agent, designed for deployment on Kubernetes using K8ssandra Operator.

## Overview

This repository provides pre-configured Docker images that combine:
- Apache Cassandra (versions 4.1 and 5.0)
- K8ssandra Management API
- AxonOps Agent for monitoring and management

These containers are optimized for Kubernetes deployments using the K8ssandra Operator and include automated CI/CD pipelines for building and publishing to GitHub Container Registry.

## Prerequisites

- Kubernetes cluster (local or cloud)
- kubectl configured to access your cluster
- Helm 3.x
- Docker (for local builds)
- AxonOps account with valid API key and organization ID

## Project Structure

```
.
├── 4.1/                          # Cassandra 4.1 specific files
│   ├── Dockerfile.4-1            # Dockerfile for Cassandra 4.1
│   └── rebuild-41.sh             # Build script for 4.1
├── 5.0/                          # Cassandra 5.0 specific files
│   ├── Dockerfile                # Dockerfile for Cassandra 5.0
│   ├── axonops-entrypoint.sh     # Entrypoint script
│   ├── axonops-entrypoint-supervisor.sh  # Alternative supervisor-based entrypoint
│   ├── axonops-yum-repo.repo     # AxonOps YUM repository configuration
│   └── supervisor.conf           # Supervisor configuration
├── scripts/                      # Helper scripts
│   ├── install_k8ssandra.sh      # K8ssandra operator installation
│   └── rebuild.sh                # Build and deploy script
├── examples/                     # Example configurations
│   └── axon-cluster.yml          # Sample K8ssandra cluster definition
├── .github/workflows/            # CI/CD pipelines
│   └── build-and-publish-5.0.yml # Automated build and publish workflow
├── cluster-axonops.yaml          # Production cluster configuration (5.0)
└── cluster-axonops41.yaml        # Production cluster configuration (4.1)
```

## Supported Cassandra Versions

### Cassandra 5.0
- Base Image: `k8ssandra/cass-management-api:5.0.5-ubi`
- AxonOps Agent: `1.0.11.asb4126cass5k8ssandra1-1`
- JDK: JDK17
- Location: `5.0/` directory

### Cassandra 4.1
- Base Image: `k8ssandra/cass-management-api:4.1-ubi`
- AxonOps Agent: `1.0.14.asb4118k8ssandra411-1`
- Location: `4.1/` directory

## Getting Started

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
export AXON_AGENT_KEY="your-axonops-api-key"
export AXON_AGENT_ORG="your-organization-id"
export AXON_AGENT_HOST="agents.axonops.cloud"  # or your custom host
```

Optional: Specify a custom image name (defaults to ttl.sh with 1-hour TTL):

```bash
export IMAGE_NAME="your-registry/your-image:tag"
```

### 3. Build and Deploy

Use the rebuild script to build, push, and deploy your cluster:

```bash
cd 5.0  # or 4.1 for Cassandra 4.1
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

### Cassandra 5.0

```bash
cd 5.0
docker build -t your-registry/axonops-cassandra:5.0.5 .
docker push your-registry/axonops-cassandra:5.0.5
```

### Cassandra 4.1

```bash
cd 4.1
docker build -f Dockerfile.4-1 -t your-registry/axonops-cassandra:4.1 .
docker push your-registry/axonops-cassandra:4.1
```

## Deploying to Kubernetes

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
| `AXON_AGENT_KEY` | Your AxonOps API key | Required |
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

**Usage:**
```bash
export IMAGE_NAME="your-registry/image:tag"  # Optional, defaults to ttl.sh
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_HOST="your-host"  # Optional

./scripts/rebuild.sh
```

**What it does:**
1. Generates a unique image name if not provided (using ttl.sh with 1-hour TTL)
2. Deletes existing cluster deployment
3. Cleans up old container images from crictl
4. Builds new Docker image
5. Pushes image to registry
6. Pulls image using crictl
7. Substitutes environment variables in `cluster-axonops.yaml`
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
- Name: `axonops-k8ssandra-5`
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

**AxonOps Integration:**
The example shows proper environment variable injection for the AxonOps agent using the container-level environment variables approach required by K8ssandra.

### Customizing the Example

To use this example:

1. Copy the example file:
   ```bash
   cp examples/axon-cluster.yml my-cluster.yml
   ```

2. Update the values:
   - Change cluster name and namespace
   - Adjust node count (`size`)
   - Modify resource allocations
   - Update storage settings
   - Set your image name

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

The repository includes a GitHub Actions workflow that automatically builds and publishes Docker images when version tags are pushed.

**Workflow:** `.github/workflows/build-and-publish-5.0.yml`

**Trigger:** Push tags matching pattern `*.*.*-*.*.*`

Example tag: `1.0.0-5.0.5` (agent-version-cassandra-version)

**Process:**
1. **Create Release**: Automatically creates a GitHub release for the tag
2. **Build and Push**:
   - Builds Docker image from `5.0/Dockerfile`
   - Tags with version (`5.0-<version>`) and `5.0-latest`
   - Pushes to GitHub Container Registry (`ghcr.io`)
   - Uses Docker layer caching for faster builds

**Image Location:**
```
ghcr.io/<owner>/<repository>:5.0-<version>
ghcr.io/<owner>/<repository>:5.0-latest
```

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

## License

See [LICENSE](LICENSE) file for details.

## Support

- AxonOps Documentation: https://axonops.com/docs
- K8ssandra Documentation: https://docs.k8ssandra.io
- Issues: Please report issues in this repository

---
*This project may contain trademarks or logos for projects, products, or services. Any use of third-party trademarks or logos are subject to those third-party's policies. AxonOps is a registered trademark of AxonOps Limited. Apache, Apache Cassandra, Cassandra, Apache Spark, Spark, Apache TinkerPop, TinkerPop, Apache Kafka and Kafka are either registered trademarks or trademarks of the Apache Software Foundation or its subsidiaries in Canada, the United States and/or other countries. Elasticsearch is a trademark of Elasticsearch B.V., registered in the U.S. and in other countries. Docker is a trademark or registered trademark of Docker, Inc. in the United States and/or other countries.*
