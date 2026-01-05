# AxonOps Strimzi Kafka

This repository provides custom Strimzi Kafka container images with integrated AxonOps monitoring and observability components.

## Overview

The AxonOps Strimzi integration allows you to build Kafka clusters running on Kubernetes using the [Strimzi Operator](https://strimzi.io/) that automatically report metrics and logs to AxonOps. This is achieved by extending the standard Strimzi Kafka images with AxonOps agent components.

## Features

- **KRaft Support**: Built on Strimzi's KRaft mode (Kafka without ZooKeeper)
- **AxonOps Monitoring**: Automatic metrics collection and log shipping
- **Flexible Configuration**: Support for both ConfigMap and environment variable-based configuration
- **Rack Awareness**: Support for Kubernetes topology-based rack awareness
- **Security Scanning**: Integrated Trivy security scanning in CI/CD

## Prerequisites

- Kubernetes cluster (tested with k3s, but should work with any Kubernetes distribution)
- Helm 3.x
- kubectl configured to access your cluster
- AxonOps account with API key

## Quick Start

### 1. Install Strimzi Operator

```bash
helm repo add strimzi https://strimzi.io/charts/
helm install my-strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --version 0.46.0 \
  --set watchAnyNamespace=true
```

### 2. Create Kafka Namespace

```bash
kubectl create namespace kafka
```

### 3. Deploy Kafka Cluster

Choose one of the configuration methods below based on your requirements.

#### Option A: Environment Variable Configuration (Recommended)

This is the simplest approach where all AxonOps configuration is passed via environment variables.

**Update the following values** in [`examples/kafka-cluster-env.yaml`](examples/kafka-cluster-env.yaml):
- `YOUR_AXONOPS_HOST`: Your AxonOps server hostname (e.g., `agents.axonops.com`)
- `YOUR_AXONOPS_API_KEY`: Your AxonOps organization API key
- `YOUR_CLUSTER_NAME`: A unique name for this Kafka cluster
- `YOUR_ORG_NAME`: Your AxonOps organization name

Then apply:

```bash
kubectl apply -f examples/kafka-cluster-env.yaml -n kafka
kubectl get pod -n kafka --watch
```

#### Option B: ConfigMap Configuration

For more complex configurations, you can use ConfigMaps to provide full AxonOps agent configuration files.

**Update the following values** in [`examples/kafka-cluster-config.yaml`](examples/kafka-cluster-config.yaml):
- `YOUR_AXONOPS_HOST`: Your AxonOps server hostname
- `YOUR_AXONOPS_API_KEY`: Your AxonOps organization API key
- `YOUR_CLUSTER_NAME`: A unique name for this Kafka cluster
- `YOUR_ORG_NAME`: Your AxonOps organization name

ConfigMaps created:
- `controller-axon-config`: Configuration for Kafka controllers
- `broker-axon-config`: Configuration for Kafka brokers
- `kafka-logging-cm`: Logging configuration for log shipping

Then apply:

```bash
kubectl apply -f examples/kafka-cluster-config.yaml -n kafka
kubectl get pod -n kafka --watch
```

#### Option C: Single Node (Development/Testing)

For development or testing, you can deploy a single-node Kafka cluster with combined controller and broker roles.

**Update the values** in [`examples/kafka-single-node.yaml`](examples/kafka-single-node.yaml) and apply:

```bash
kubectl apply -f examples/kafka-single-node.yaml -n kafka
kubectl get pod -n kafka --watch
```

#### Option D: Kafka Connect Cluster

Deploy a Kafka Connect cluster for streaming data between Kafka and other systems.

**Prerequisites**: Ensure you have a running Kafka cluster (deployed using one of the options above).

**Update the following values** in [`examples/kafka-connect.yaml`](examples/kafka-connect.yaml):
- `YOUR_AXONOPS_HOST`: Your AxonOps server hostname (e.g., `agents.axonops.com`)
- `YOUR_AXONOPS_API_KEY`: Your AxonOps organization API key
- `YOUR_CLUSTER_NAME`: A unique name for this Kafka Connect cluster
- `YOUR_ORG_NAME`: Your AxonOps organization name
- `ghcr.io/axonops/strimzi/kafka:latest`: Replace with your specific AxonOps-enabled Kafka image
- `my-cluster-kafka-bootstrap:9092`: Replace with your actual Kafka bootstrap server address

Then apply:

```bash
kubectl apply -f examples/kafka-connect.yaml -n kafka
kubectl get pod -n kafka --watch
```

**Note**: Kafka Connect support is currently in beta. The Connect workers will report metrics to AxonOps using the `connect` node type.

## Configuration Details

### Required Environment Variables

When using environment variable-based configuration, the following variables must be set:

| Variable | Description | Example |
|----------|-------------|---------|
| `KAFKA_NODE_TYPE` | Role of the Kafka node | `kraft-controller` or `kraft-broker` |
| `AXON_AGENT_SERVER_HOST` | AxonOps server hostname | `agents.axonops.com` |
| `AXON_AGENT_KEY` | AxonOps API key | Your API key from AxonOps dashboard |
| `AGENT_CLUSTER_NAME` | Unique cluster identifier | `my-kafka-prod` |
| `AXON_AGENT_ORG` | AxonOps organization name | Your organization name |

### Optional Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `KAFKA_CLIENT_BROKERS` | Broker addresses (for brokers) | `0.0.0.0:9092` |

### ConfigMap Configuration

The ConfigMap approach allows you to provide a complete `axon-agent.yml` configuration file. This is useful for:

- Advanced metric collection configuration
- Custom logging settings
- Multiple datacenter deployments
- Fine-grained control over agent behavior

See [`examples/kafka-cluster-config.yaml`](examples/kafka-cluster-config.yaml) for the full structure.

## Rack Awareness

Kafka rack awareness is supported using Kubernetes node labels. This helps ensure replicas are distributed across availability zones.

### Label Your Nodes

```bash
kubectl label node <node-name> topology.kubernetes.io/zone=<zone-name>
```

Example:

```bash
kubectl label node worker-1 topology.kubernetes.io/zone=us-east-1a
kubectl label node worker-2 topology.kubernetes.io/zone=us-east-1b
kubectl label node worker-3 topology.kubernetes.io/zone=us-east-1c
```

### Configure in Kafka CRD

The rack awareness configuration is already included in the example manifests:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    rack:
      topologyKey: topology.kubernetes.io/zone
```

The node label defaults to `topology.kubernetes.io/zone` but can be overridden using the `topologyKey` parameter.

## Building Custom Images

### Local Development Build

To build a custom image locally for testing:

```bash
# For Kafka 3.x versions
docker build \
  --build-arg STRIMZI_VERSION=0.46.0 \
  --build-arg KAFKA_VERSION=3.9.0 \
  --build-arg KAFKA_AGENT_PACKAGE=axon-kafka3-agent \
  --build-arg AXONOPS_REPO_FILE=axonops.repo.dev \
  -t axonkafka:local \
  .

# For Kafka 4.x versions
docker build \
  --build-arg STRIMZI_VERSION=0.49.1 \
  --build-arg KAFKA_VERSION=4.1.0 \
  --build-arg KAFKA_AGENT_PACKAGE=axon-kafka4-agent \
  --build-arg AXONOPS_REPO_FILE=axonops.repo.dev \
  -t axonkafka:local \
  .
```

**Important**: Use `axon-kafka3-agent` for Kafka 3.x versions and `axon-kafka4-agent` for Kafka 4.x versions.

### CI/CD Pipeline

The repository includes a GitHub Actions workflow at [`.github/workflows/strimzi-build-and-test.yml`](../.github/workflows/strimzi-build-and-test.yml) that:

1. Builds the Strimzi operator image with AxonOps components
2. Runs security scanning with Trivy
3. Validates the image build process

The workflow is triggered on:
- Pushes to `main`, `development`, `feature/**`, `feat/**`, `fix/**`, `bug/**` branches
- Pull requests to `main` or `development`
- Changes to files in the `strimzi/` directory

### Tagging for Production Builds

To trigger a production build pipeline, create a tag in the following format:

```
<environment>/<strimzi-version>-kafka-<kafka-version>-<build-number>
```

**Examples:**

```bash
# Development build
git tag dev/0.49.1-kafka-4.1.0-1
git push origin dev/0.49.1-kafka-4.1.0-1

# Beta build
git tag beta/0.49.1-kafka-4.1.0-1
git push origin beta/0.49.1-kafka-4.1.0-1

# Production release
git tag release/0.49.1-kafka-4.1.0-1
git push origin release/0.49.1-kafka-4.1.0-1
```

**Where:**
- `<environment>`: `dev`, `beta`, or `release`
- `<strimzi-version>`: Strimzi operator version (e.g., `0.49.1`)
- `<kafka-version>`: Kafka version (e.g., `4.1.0`)
- `<build-number>`: Incremental build number (e.g., `1`, `2`, `3`)

## Cleanup

### Remove Kafka Cluster

To remove all Kafka resources from the example cluster:

```bash
# Delete all Strimzi resources
kubectl delete $(kubectl get strimzi -o name -n kafka) -n kafka

# Delete persistent volume claims
kubectl delete pvc --all -n kafka

# Uninstall Strimzi operator
helm uninstall my-strimzi-kafka-operator

# Clean up local images (if needed)
docker rmi axonkafka:local
```

### Clean up Kubernetes Images (k3s example)

```bash
k3s crictl rmi ghcr.io/axonops/strimzi/kafka:0.47.0-3.9.0
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n kafka
kubectl describe pod <pod-name> -n kafka
```

### View Logs

```bash
# Kafka broker logs
kubectl logs <broker-pod-name> -n kafka

# AxonOps agent logs
kubectl exec <pod-name> -n kafka -- tail -f /var/log/axonops/axon-agent.log

# Follow all logs from a pod
kubectl logs -f <pod-name> -n kafka
```

### Verify AxonOps Connection

```bash
# Check if agent is running
kubectl exec <pod-name> -n kafka -- ps aux | grep axon

# Check agent configuration
kubectl exec <pod-name> -n kafka -- cat /etc/axonops/axon-agent.yml
```

### Common Issues

**Problem**: Pods are stuck in `Pending` or `CrashLoopBackOff`
- Check resource availability: `kubectl describe pod <pod-name> -n kafka`
- Verify PVC status: `kubectl get pvc -n kafka`

**Problem**: AxonOps agent not reporting metrics
- Verify API key is correct in configuration
- Check network connectivity to AxonOps server
- Review agent logs for errors

## Architecture

The custom images are built by:

1. Starting from the official Strimzi Kafka base image (`quay.io/strimzi/kafka`)
2. Adding AxonOps YUM repository
3. Installing AxonOps agent and Kafka agent packages
4. Injecting the AxonOps wrapper script into Kafka startup scripts
5. Configuring permissions and group membership

Key files:

- [`Dockerfile`](Dockerfile): Image build definition
- [`files/axonops-wrapper.sh`](files/axonops-wrapper.sh): Startup wrapper for AxonOps integration
- [`files/axonops.repo.dev`](files/axonops.repo.dev): AxonOps YUM repository configuration (dev)
- [`files/axonops.repo.release`](files/axonops.repo.release): AxonOps YUM repository configuration (release)

## Example Configurations

### Single Node Cluster

**File**: [`examples/kafka-single-node.yaml`](examples/kafka-single-node.yaml)

- **Topology**: Single node with combined controller + broker role
- **Replicas**: 1
- **Storage**: Persistent volume (100Gi)
- **Configuration Method**: ConfigMap-based
- **Use Case**: Development, testing, demos

### Multi-Node Cluster with Separate Controllers and Brokers

**File**: [`examples/kafka-cluster-config.yaml`](examples/kafka-cluster-config.yaml)

- **Topology**: Separate controller and broker pools
- **Controllers**: 3 replicas with ephemeral storage
- **Brokers**: 2 replicas with ephemeral storage
- **Configuration Method**: ConfigMap-based with full agent configuration
- **Features**:
  - Rack awareness enabled
  - Custom logging configuration
  - Separate AxonOps config for controllers and brokers
- **Use Case**: Production deployments requiring full control

### Multi-Node Cluster with Environment Variables

**File**: [`examples/kafka-cluster-env.yaml`](examples/kafka-cluster-env.yaml)

- **Topology**: Separate controller and broker pools
- **Controllers**: 3 replicas with persistent storage (5Gi)
- **Brokers**: 2 replicas with persistent storage (5Gi)
- **Configuration Method**: Environment variable-based (recommended)
- **Features**:
  - Rack awareness enabled
  - Inline logging configuration
  - Simpler configuration management
- **Use Case**: Production deployments with standard configuration

### Kafka Connect Cluster

**File**: [`examples/kafka-connect.yaml`](examples/kafka-connect.yaml)

- **Component**: Kafka Connect workers
- **Replicas**: 1 (can be scaled as needed)
- **Configuration Method**: ConfigMap-based
- **Features**:
  - Connector resource support enabled
  - AxonOps monitoring for Connect workers
  - Configurable storage topics for Connect metadata
- **Configuration Topics**:
  - Config storage: `connect-configs`
  - Status storage: `connect-status`
  - Offset storage: `connect-offsets`
- **Use Case**: Data integration, ETL pipelines, streaming data between Kafka and external systems

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| Strimzi | 0.49.1 (latest) | ConfigMap support requires 0.44+, KRaft mode required |
| Kafka | 4.1.0 (latest) | Version 0.49.1 supports Kafka 4.0.0, 4.0.1, 4.1.0 |
| Kubernetes | 1.24+ | Any CNCF-compliant distribution |
| AxonOps Agent | Latest | Auto-installed from repository |

### Strimzi Version History

| Strimzi Version | Supported Kafka Versions | Release Date |
|-----------------|-------------------------|--------------|
| 0.49.1 | 4.0.0, 4.0.1, 4.1.0 | Dec 2024 |
| 0.46.0 | 3.9.0, 4.0.0 | Sep 2024 |
| 0.45.0 | 3.8.0, 3.8.1, 3.9.0 | Jul 2024 |

## Known Limitations and TODOs

- **Kafka Connect**: Example configuration provided, but full integration testing is ongoing
- **Mirror Maker**: Not built or tested yet
- **ZooKeeper Mode**: Not supported (KRaft only)
- **Persistent hostId**: Consider using persistent volumes for AxonOps agent hostId file

## Support

For issues related to:

- **AxonOps Integration**: Contact AxonOps support
- **Strimzi Operator**: See [Strimzi documentation](https://strimzi.io/docs/)
- **This Repository**: Open an issue in the repository

## Additional Resources

- [Strimzi Documentation](https://strimzi.io/docs/)
- [AxonOps Documentation](https://docs.axonops.com/)
- [Kafka KRaft Mode](https://kafka.apache.org/documentation/#kraft)
- [Kubernetes Node Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
