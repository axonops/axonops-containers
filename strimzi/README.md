# AxonOps Strimzi Kafka

**English** | [Français](README.fr.md) | [Español](README.es.md) | [Galego](README.gl.md)

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

### 1. Install the Strimzi operator

```bash
helm upgrade --install strimzi-kafka-operator \
  oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  --version 1.1.0 \
  --namespace strimzi --create-namespace \
  --set watchAnyNamespace=true \
  --wait
```

### 2. Deploy a Kafka cluster

Ready-to-use manifests are in [`examples/strimzi/`](../examples/strimzi/). Each directory has a `strimzi-config.env` file and a README with the full steps:

| Example | Storage | AxonOps target |
| --- | --- | --- |
| [`cloud/`](../examples/strimzi/cloud/) | PVCs from a StorageClass | AxonOps Cloud |
| [`on-premises/`](../examples/strimzi/on-premises/) | PVCs from a StorageClass | Self-hosted AxonOps |
| [`local-disk/`](../examples/strimzi/local-disk/) | hostPath volumes pinned to nodes | Self-hosted AxonOps |

```bash
cd examples/strimzi/cloud
source strimzi-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key
kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
kubectl get pods -n "$KAFKA_NAMESPACE" --watch
```

`kafka-connect.yaml` in the same directories adds a Kafka Connect cluster whose workers report to AxonOps with the `connect` node type. Kafka Connect support is in beta.

See the [Strimzi deployment guide](../examples/STRIMZI_DEPLOYMENT.md) for operator and image version compatibility.

## Configuration Details

### Agent Environment Variables

The image reads its agent settings from environment variables on the Kafka container. The examples set them from a Secret with `valueFrom.secretKeyRef`.

| Variable | Description | Example |
|----------|-------------|---------|
| `KAFKA_NODE_TYPE` | Role of the Kafka node | `kraft-controller`, `kraft-broker` or `connect` |
| `AXON_AGENT_CLUSTER_NAME` | Cluster name shown in AxonOps | `my-kafka-prod` |
| `AXON_AGENT_ORG` | AxonOps organisation name | Your organisation name |
| `AXON_AGENT_KEY` | AxonOps agent key | Your key from the AxonOps console |
| `AXON_AGENT_SERVER_HOST` | AxonOps server hostname | `agents.axonops.cloud` |
| `AXON_AGENT_SERVER_PORT` | AxonOps server port | `443`, or `1888` for a self-hosted server |
| `AXON_AGENT_TLS_MODE` | Agent TLS mode | `TLS` or `disabled` |

### Configuration File

To configure the agent with a complete `axon-agent.yml` instead, mount it at `/mnt/axon-agent.yml`, for example from a ConfigMap through `template.pod.volumes` and `template.kafkaContainer.volumeMounts` in the KafkaNodePool. The image links it to `/etc/axonops/axon-agent.yml` at startup.

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
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    rack:
      topologyKey: topology.kubernetes.io/zone
```

The examples set `topologyKey` from `KAFKA_RACK_TOPOLOGY_KEY`: `topology.kubernetes.io/zone` in `cloud/`, `kubernetes.io/hostname` in `on-premises/` and `local-disk/`.

## Building Custom Images

### Local Development Build

To build a custom image locally for testing:

```bash
# For Kafka 3.x versions
docker build \
  --build-arg STRIMZI_VERSION=0.46.1 \
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
kubectl delete $(kubectl get strimzi -o name -n "$KAFKA_NAMESPACE") -n "$KAFKA_NAMESPACE"

# Delete persistent volume claims
kubectl delete pvc --all -n "$KAFKA_NAMESPACE"

# Uninstall Strimzi operator
helm uninstall strimzi-kafka-operator -n strimzi

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
kubectl get pods -n "$KAFKA_NAMESPACE"
kubectl describe pod <pod-name> -n "$KAFKA_NAMESPACE"
```

### View Logs

```bash
# Kafka broker logs
kubectl logs <broker-pod-name> -n "$KAFKA_NAMESPACE"

# AxonOps agent logs
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- tail -f /var/log/axonops/axon-agent.log

# Follow all logs from a pod
kubectl logs -f <pod-name> -n "$KAFKA_NAMESPACE"
```

### Verify AxonOps Connection

```bash
# Check if agent is running
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- ps aux | grep axon

# Check agent configuration
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- cat /etc/axonops/axon-agent.yml
```

### Common Issues

**Problem**: Pods are stuck in `Pending` or `CrashLoopBackOff`
- Check resource availability: `kubectl describe pod <pod-name> -n "$KAFKA_NAMESPACE"`
- Verify PVC status: `kubectl get pvc -n "$KAFKA_NAMESPACE"`

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
  The wrapper also adds `-XX:-UseBASE64Intrinsics` to `KAFKA_OPTS` to mitigate CVE-2026-114938. It is placed first, so a later `-XX:+UseBASE64Intrinsics` in your own `KAFKA_OPTS` overrides it.
- [`files/axonops.repo.dev`](files/axonops.repo.dev): AxonOps YUM repository configuration (dev)
- [`files/axonops.repo.release`](files/axonops.repo.release): AxonOps YUM repository configuration (release)

## Example Configurations

The examples are described in [`examples/STRIMZI_DEPLOYMENT.md`](../examples/STRIMZI_DEPLOYMENT.md). All three create a Kafka cluster with separate KRaft controller and broker pools, rack awareness, and the AxonOps agent in every container.

## Version Compatibility

| Component | Version | Notes |
| --------- | ------- | ----- |
| Strimzi | 1.2.0 (latest) | ConfigMap support requires 0.44+, KRaft mode required |
| Kafka | 4.3.1 (latest) | Version 1.2.0 supports Kafka 4.2.0, 4.2.1, 4.3.0, 4.3.1 |
| Kubernetes | 1.24+ | Any CNCF-compliant distribution |
| AxonOps Agent | Latest | Auto-installed from repository |

### Image Tags

Tags read `<strimzi>-<kafka>` (floating) or `<strimzi>-<kafka>-<agent>-<image>` (pinned). The Strimzi part must match the installed operator: `0.50.0-4.1.1` is for Strimzi 0.50.0. A combination that is not built, such as `1.1.0-4.1.0`, fails with `ImagePullBackOff`. See [Version compatibility](../examples/STRIMZI_DEPLOYMENT.md#version-compatibility) for how to read the installed operator version and for every operator and tag that is built.

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
