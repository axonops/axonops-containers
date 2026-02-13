# Strimzi Kafka Deployment Guide

This guide covers deploying Apache Kafka using the Strimzi operator on Kubernetes, with optional AxonOps monitoring integration.

## Quick Start

### Step 1: Install Strimzi Operator

Before deploying Kafka clusters, install the Strimzi operator using Helm.

**Important:** Check the [Strimzi downloads page](https://strimzi.io/downloads/) to verify which Strimzi version supports your desired Kafka version. The support matrix shows compatible Kafka versions for each Strimzi release.

```bash
# Add Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Create namespaces
kubectl create namespace strimzi
kubectl create namespace kafka

# Check available versions
helm search repo strimzi --versions

# Install the operator (specify version based on support matrix)
# Example: Strimzi 0.50.0 supports Kafka 4.1.1
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  -n strimzi \
  --version 0.50.0 \
  --set watchNamespaces="{kafka}" \
  --wait

# Verify installation
kubectl get pods -n strimzi
kubectl get crd | grep strimzi
```

### Step 2: Deploy Kafka Cluster

Choose one of the deployment examples based on your use case. Each example includes its own README with detailed deployment instructions:

| Directory | Use Case | Description |
| --- | --- | --- |
| [strimzi/cloud/](strimzi/cloud/) | Production | 6 brokers, 3 controllers, cloud storage |
| [strimzi/local-disk/](strimzi/local-disk/) | On-premises | Local persistent volumes, configurable |
| [strimzi/single/](strimzi/single/) | Development | Single dual-role node |

Each example directory contains:

- `README.md` - Complete deployment instructions
- `strimzi-config.env` - Configuration variables
- YAML manifests for all Kafka cluster components

### Step 3: Add AxonOps Monitoring (Optional)

See [AXONOPS_DEPLOYMENT.md](AXONOPS_DEPLOYMENT.md) for deploying AxonOps monitoring. The Strimzi example manifests include AxonOps agent configuration variables.

---

## Strimzi Version Compatibility

Always check the [Strimzi support matrix](https://strimzi.io/downloads/) before installation to ensure compatibility:

| Strimzi Version | Supported Kafka Versions | Kubernetes Versions |
| --- | --- | --- |
| 0.45.0 | 3.8.x, 3.9.x | 1.25+ |
| 0.44.0 | 3.7.x, 3.8.x | 1.25+ |
| 0.43.0 | 3.7.x, 3.8.x | 1.23+ |

*Note: This table is for reference only. Always verify current compatibility at [strimzi.io/downloads](https://strimzi.io/downloads/).*

## Additional Resources

- **Strimzi Documentation**: [https://strimzi.io/docs/](https://strimzi.io/docs/)
- **Strimzi GitHub**: [https://github.com/strimzi/strimzi-kafka-operator](https://github.com/strimzi/strimzi-kafka-operator)
- **Node Selector Guide**: [NODE_SELECTOR_GUIDE.md](NODE_SELECTOR_GUIDE.md)
- **AxonOps Integration**: [AXONOPS_DEPLOYMENT.md](AXONOPS_DEPLOYMENT.md)
- **AxonOps Agent Setup**: [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Apache Kafka Documentation**: [https://kafka.apache.org/documentation/](https://kafka.apache.org/documentation/)
- **KRaft Documentation**: [https://kafka.apache.org/documentation/#kraft](https://kafka.apache.org/documentation/#kraft)

---

**Last Updated:** 2026-02-13
