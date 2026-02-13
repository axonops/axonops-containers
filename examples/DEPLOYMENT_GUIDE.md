# On-Premises Deployment Guide

Welcome to the on-premises deployment guide for AxonOps and data platform solutions on Kubernetes.

## Overview

This guide provides deployment instructions for running various data platforms on Kubernetes with optional AxonOps monitoring and management capabilities.

## Quick Navigation

| Component | Description | Guide |
| --- | --- | --- |
| AxonOps | Monitoring and management platform | [AXONOPS_DEPLOYMENT.md](AXONOPS_DEPLOYMENT.md) |
| Strimzi Kafka | Apache Kafka on Kubernetes | [STRIMZI_DEPLOYMENT.md](STRIMZI_DEPLOYMENT.md) |
| K8ssandra | Apache Cassandra on Kubernetes | [K8SSANDRA_DEPLOYMENT.md](K8SSANDRA_DEPLOYMENT.md) |

## Example Manifests

Ready-to-use Kubernetes manifests are available in the following directories:

| Directory | Description |
| --- | --- |
| [axonops/](axonops/) | AxonOps server, dashboard, and database components |
| [strimzi/cloud/](strimzi/cloud/) | Production Strimzi Kafka for cloud environments |
| [strimzi/local-disk/](strimzi/local-disk/) | Strimzi Kafka with local persistent volumes |
| [strimzi/single/](strimzi/single/) | Single-node Strimzi Kafka for development |
| [k8ssandra/](k8ssandra/) | K8ssandra Cassandra cluster examples |

## Prerequisites

All deployments require:

1. **Kubernetes Cluster** (v1.21+)
   - Single-node or multi-node supported

2. **Command-line Tools**
   - `kubectl` - Kubernetes CLI
   - `helm` - Helm package manager v3.x or later
   - `envsubst` - Variable substitution (part of `gettext` package)

3. **Cluster Access**
   - Configured `kubectl` context
   - Sufficient permissions (cluster-admin or equivalent)

4. **Storage** (choose one)
   - Dynamic storage provisioner (recommended for production)
   - hostPath storage (for single-node testing)

### Installing envsubst

The `envsubst` command is used to substitute environment variables in YAML templates.

**macOS:**
```bash
brew install gettext
brew link --force gettext
```

**Ubuntu/Debian:**
```bash
sudo apt-get install gettext-base
```

**RHEL/CentOS:**
```bash
sudo yum install gettext
```

**Verify installation:**
```bash
envsubst --version
```

---

## Deployment Scenarios

### Scenario 1: AxonOps Only

Deploy just the monitoring platform to monitor existing clusters:

```bash
cd axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh
```

See [AXONOPS_DEPLOYMENT.md](AXONOPS_DEPLOYMENT.md) for full details.

---

### Scenario 2: Kafka with AxonOps Monitoring (Recommended)

Deploy Kafka with comprehensive monitoring:

```bash
# Step 1: Deploy AxonOps monitoring platform
cd axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh

# Step 2: Configure Strimzi (edit strimzi-setup.env as needed)
vi strimzi-setup.env

# Step 3: Deploy Kafka with automatic monitoring integration
source axonops-config.env
source strimzi-setup.env
./strimzi-setup.sh
```

See [AXONOPS_DEPLOYMENT.md](AXONOPS_DEPLOYMENT.md) and [STRIMZI_DEPLOYMENT.md](STRIMZI_DEPLOYMENT.md).

---

### Scenario 3: Kafka Standalone (Cloud Examples)

Deploy Kafka using the cloud example manifests:

```bash
cd strimzi/cloud/

# Configure and source environment variables
vi strimzi-config.env
export $(grep -v '^#' strimzi-config.env | xargs)

# Create the AxonOps secret
kubectl create secret generic axonops-agent -n kafka \
  --from-literal=AXON_AGENT_CLUSTER_NAME=$AXON_AGENT_CLUSTER_NAME \
  --from-literal=AXON_AGENT_ORG=$AXON_AGENT_ORG \
  --from-literal=AXON_AGENT_SERVER_HOST=$AXON_AGENT_SERVER_HOST \
  --from-literal=AXON_AGENT_KEY=$AXON_AGENT_KEY

# Apply manifests
kubectl apply -f kafka-logging-cm.yaml
kubectl apply -f kafka-node-pool-controller.yaml
kubectl apply -f kafka-node-pool-brokers.yaml
kubectl apply -f kafka-cluster.yaml
```

See [strimzi/cloud/README.md](strimzi/cloud/README.md) for full details.

---

### Scenario 4: Cassandra with K8ssandra

Deploy Apache Cassandra using K8ssandra:

```bash
cd k8ssandra/

# Configure environment variables
export $(grep -v '^#' k8ssandra-config.env | xargs)

# Apply the cluster manifest
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

See [K8SSANDRA_DEPLOYMENT.md](K8SSANDRA_DEPLOYMENT.md) for full details.

---

### Scenario 5: Full Stack (AxonOps + Kafka + Cassandra)

Deploy the complete monitoring and data platform stack:

```bash
# Step 1: Deploy AxonOps
cd axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh
source axonops-config.env

# Step 2: Deploy Kafka
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh

# Step 3: Deploy Cassandra
cd ../k8ssandra/
export $(grep -v '^#' k8ssandra-config.env | xargs)
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

---

## Using envsubst with Manifests

Many example manifests use environment variable placeholders (`${VAR_NAME}`). Use `envsubst` to substitute values before applying:

### Basic Usage

```bash
# Source configuration file
export $(grep -v '^#' config.env | xargs)

# Apply manifest with variable substitution
envsubst < manifest.yaml | kubectl apply -f -
```

### Processing Multiple Files

```bash
# Source configuration
export $(grep -v '^#' strimzi-config.env | xargs)

# Apply all manifests in order
for f in manifest1.yaml manifest2.yaml manifest3.yaml; do
  envsubst < $f | kubectl apply -f -
done
```

### Generating Processed Manifests

For GitOps or review purposes, generate fully processed manifests:

```bash
export $(grep -v '^#' config.env | xargs)

# Generate single output file
envsubst < input.yaml > processed-output.yaml

# Or generate multiple files
for f in *.yaml; do
  envsubst < $f > processed/$f
done
```

### Selective Variable Substitution

To substitute only specific variables:

```bash
# Only substitute NAMESPACE and CLUSTER_NAME
envsubst '$NAMESPACE $CLUSTER_NAME' < manifest.yaml | kubectl apply -f -
```

---

## Verification

After deployment, verify all components are running:

```bash
# Check all namespaces
kubectl get pods -A | grep -E "axonops|kafka|k8ssandra|strimzi"

# Check specific namespace
kubectl get pods -n kafka
kubectl get pods -n axonops
kubectl get pods -n k8ssandra-operator
```

---

## Support

- **AxonOps Documentation**: [https://docs.axonops.com](https://docs.axonops.com)
- **AxonOps Agent Setup**: [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Strimzi Documentation**: [https://strimzi.io/docs/](https://strimzi.io/docs/)
- **K8ssandra Documentation**: [https://docs.k8ssandra.io/](https://docs.k8ssandra.io/)
- **Apache Kafka Documentation**: [https://kafka.apache.org/documentation/](https://kafka.apache.org/documentation/)
- **Apache Cassandra Documentation**: [https://cassandra.apache.org/doc/](https://cassandra.apache.org/doc/)

---

**Last Updated:** 2026-02-13
