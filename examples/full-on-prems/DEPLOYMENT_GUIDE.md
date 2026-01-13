# On-Premises Deployment Guide

Welcome to the on-premises deployment guide for AxonOps and data platform solutions on Kubernetes.

## Overview

This guide provides deployment instructions for running various data platforms on Kubernetes with optional AxonOps monitoring and management capabilities.

## Available Deployment Guides

### 📊 [AxonOps Monitoring Platform](AXONOPS_DEPLOYMENT.md)

Deploy AxonOps for monitoring and managing your Kafka and Cassandra clusters.

**Components:**
- AxonOps Server (core monitoring service)
- AxonDB Timeseries (metrics storage with Cassandra)
- AxonDB Search (log aggregation with OpenSearch)
- AxonOps Dashboard (web UI)

**Quick Start:**
```bash
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh
```

[📖 Full AxonOps Deployment Guide →](AXONOPS_DEPLOYMENT.md)

---

### 🔄 [Strimzi Apache Kafka](STRIMZI_DEPLOYMENT.md)

Deploy production-ready Apache Kafka using the Strimzi operator with KRaft mode (no ZooKeeper required).

**Components:**
- Strimzi Kafka Operator
- Kafka Controllers (KRaft consensus)
- Kafka Brokers (data handling)
- Optional: AxonOps monitoring integration

**Quick Start:**
```bash
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

[📖 Full Strimzi Kafka Deployment Guide →](STRIMZI_DEPLOYMENT.md)

---

### 🗄️ Apache Cassandra with K8ssandra

Deploy Apache Cassandra with K8ssandra for automated operations and management.

**Status:** 🚧 Coming Soon

**Planned Components:**
- K8ssandra Operator
- Apache Cassandra Cluster
- Medusa (backup/restore)
- Reaper (automated repairs)
- Optional: AxonOps monitoring integration

---

## Deployment Scenarios

### Scenario 1: AxonOps Only

Deploy just the monitoring platform to monitor existing clusters:

```bash
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
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh

# Step 2: Deploy Kafka with automatic monitoring integration
source axonops-config.env
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

See [AXONOPS_DEPLOYMENT.md](AXONOPS_DEPLOYMENT.md) and [STRIMZI_DEPLOYMENT.md](STRIMZI_DEPLOYMENT.md).

---

### Scenario 3: Kafka Standalone

Deploy Kafka without monitoring:

```bash
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

See [STRIMZI_DEPLOYMENT.md](STRIMZI_DEPLOYMENT.md) for full details.

---

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

---

## Quick Navigation

- **[AxonOps Deployment →](AXONOPS_DEPLOYMENT.md)** - Monitor and manage your data platforms
- **[Strimzi Kafka Deployment →](STRIMZI_DEPLOYMENT.md)** - Production-ready Apache Kafka
- **Apache Cassandra Deployment** - Coming soon

---

## Support

- **AxonOps Documentation**: [https://docs.axonops.com](https://docs.axonops.com)
- **Strimzi Documentation**: [https://strimzi.io/docs/](https://strimzi.io/docs/)
- **Apache Kafka Documentation**: [https://kafka.apache.org/documentation/](https://kafka.apache.org/documentation/)

---

**Last Updated:** 2026-01-13
