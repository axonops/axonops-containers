# AxonOps Helm Charts

Official Helm charts for deploying AxonOps on Kubernetes clusters.

## Overview

AxonOps is a comprehensive monitoring, management, and operations platform for [Apache Cassandra](https://axonops.com/cassandra-overview-axonops) and [Apache Kafka](https://axonops.com/kafka-overview). These Helm charts enable you to deploy and manage the complete AxonOps stack on-premises in your Kubernetes environment.

The AxonOps platform consists of several components that work together to provide monitoring, alerting, backup/restore capabilities, and cluster management for your Apache Cassandra and Apache Kafka infrastructure.

## Architecture

The AxonOps platform is composed of the following components:

- **axon-server**: The core backend service that processes metrics, handles alerts, and manages cluster operations
- **axon-dash**: The web-based dashboard UI for visualization and management
- **axondb-timeseries**: Cassandra-based storage for time-series metrics data
- **axondb-search**: OpenSearch-based storage for logs and advanced search capabilities

## Available Charts

| Chart | Description | Version |
|-------|-------------|---------|
| [axon-server](./axon-server) | AxonOps Server - Core backend service | ![Version](https://img.shields.io/badge/dynamic/yaml?url=https://raw.githubusercontent.com/axonops/axonops-containers/main/charts/axon-server/Chart.yaml&label=version&query=$.version&color=blue) |
| [axon-dash](./axon-dash) | AxonOps Dashboard - Web UI | ![Version](https://img.shields.io/badge/dynamic/yaml?url=https://raw.githubusercontent.com/axonops/axonops-containers/main/charts/axon-dash/Chart.yaml&label=version&query=$.version&color=blue) |
| [axondb-timeseries](./axondb-timeseries) | Time-series database for metrics | ![Version](https://img.shields.io/badge/dynamic/yaml?url=https://raw.githubusercontent.com/axonops/axonops-containers/main/charts/axondb-timeseries/Chart.yaml&label=version&query=$.version&color=blue) |
| [axondb-search](./axondb-search) | Search database for logs | ![Version](https://img.shields.io/badge/dynamic/yaml?url=https://raw.githubusercontent.com/axonops/axonops-containers/main/charts/axondb-search/Chart.yaml&label=version&query=$.version&color=blue) |

> **Note:** AxonOps Timeseries is designed to run as a single-node instance and we do not recommend running in a clustered mode.

## Prerequisites

Before installing AxonOps using these Helm charts, ensure you have:

- **Kubernetes cluster**: Version 1.19+ (tested with 1.24+)
- **Helm**: Version 3.8+ installed on your machine
- **kubectl**: Configured to access your cluster
- **Storage**: Persistent volume provisioner for dynamic storage allocation
- **Resources**: Adequate CPU and memory resources (see individual chart documentation)
- **AxonOps License**: Contact [AxonOps](https://axonops.com) for licensing information

## Quick Start

### Installation from GitHub Container Registry (OCI)

The charts are available as OCI packages and can be installed directly:

```bash
# Login to GitHub Container Registry
helm registry login ghcr.io

# Install AxonDB TimeSeries (metrics storage)
helm install axondb-timeseries oci://ghcr.io/axonops/charts/axondb-timeseries \
  --namespace axonops \
  --create-namespace

# Install AxonDB Search (log storage)
helm install axondb-search oci://ghcr.io/axonops/charts/axondb-search \
  --namespace axonops

# Install AxonOps Server
helm install axon-server oci://ghcr.io/axonops/charts/axon-server \
  --namespace axonops \
  --set config.license_key="YOUR_LICENSE_KEY"

# Install AxonOps Dashboard
helm install axon-dash oci://ghcr.io/axonops/charts/axon-dash \
  --namespace axonops
```

### Installation from Source

Alternatively, you can install from the chart source:

```bash
# Clone the repository
git clone https://github.com/axonops/axonops-containers.git
cd axonops-containers/charts

# Install the charts
helm install axondb-timeseries ./axondb-timeseries --namespace axonops --create-namespace
helm install axondb-search ./axondb-search --namespace axonops
helm install axon-server ./axon-server --namespace axonops --set config.license_key="YOUR_LICENSE_KEY"
helm install axon-dash ./axon-dash --namespace axonops
```

## Installation Order

For a complete AxonOps deployment, install the components in this order:

1. **axondb-timeseries** - Metrics database must be available first
2. **axondb-search** - Search/log database
3. **axon-server** - Core backend (depends on the databases)
4. **axon-dash** - Dashboard UI (depends on axon-server)

## Configuration

Each chart can be customized using values files. See the individual chart READMEs for detailed configuration options:

```bash
# Create a custom values file
cat > my-values.yaml <<EOF
config:
  license_key: "YOUR_LICENSE_KEY"
  org_name: "my-organization"

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 4Gi
EOF

# Install with custom values
helm install axon-server ./axon-server -f my-values.yaml --namespace axonops
```

## Production Deployment

For production deployments, consider the following:

### High Availability
- Run multiple replicas of **axon-dash** (supports HPA)
- Configure proper resource requests and limits
- Use pod anti-affinity to spread pods across nodes
- Enable pod disruption budgets

### Persistence
- Configure appropriate storage classes for persistent volumes
- Size volumes based on your metrics retention requirements
- Use separate storage for commitlogs in **axondb-timeseries** for better performance

### Security
- Enable TLS/SSL for all components
- Configure authentication and RBAC
- Use secrets management (Kubernetes Secrets or external secret stores)
- Enable network policies to restrict traffic

### Monitoring
- Configure ServiceMonitor resources for Prometheus integration
- Set up proper alerting rules
- Monitor resource usage and adjust limits accordingly

## Getting Started with AxonOps

Once deployed, AxonOps provides comprehensive monitoring and management for your Apache Cassandra and Apache Kafka clusters:

1. **Install AxonOps agents** on your Cassandra or Kafka nodes
2. **Configure agents** to connect to your AxonOps Server
3. **Access the dashboard** to view metrics, alerts, and cluster health
4. **Set up alerts** for proactive monitoring
5. **Configure backups** for data protection (Cassandra)

For detailed instructions on getting started with AxonOps, including agent installation and configuration, please refer to the official documentation:

📚 **[AxonOps Getting Started Guide](https://axonops.com/docs/get_started/getting_started/)**

### Platform-Specific Guides

- **Apache Cassandra**: [Getting Started with Cassandra Monitoring](https://axonops.com/docs/get_started/getting_started/)
- **Apache Kafka**: [Kafka Monitoring Overview](https://axonops.com/kafka-overview)

## Documentation

- **Official Documentation**: https://axonops.com/docs/
- **Installation Guide**: https://axonops.com/docs/get_started/getting_started/
- **Configuration Reference**: https://axonops.com/docs/configuration/
- **Kubernetes Deployment**: https://axonops.com/docs/installation/kubernetes/
- **Kafka Monitoring**: https://axonops.com/kafka-overview

## Support

- **Documentation**: https://axonops.com/docs/
- **Community Support**: https://community.axonops.com/
- **Enterprise Support**: support@axonops.com
- **Issues**: https://github.com/axonops/axonops-containers/issues

## License

These Helm charts are open source. AxonOps software requires a commercial license for production use.

For licensing information, please visit: https://axonops.com/pricing/

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our GitHub repository.

## Chart Maintenance

- Charts are automatically linted on every push/PR
- Releases are published as OCI packages to GitHub Container Registry
- Each chart maintains its own version and changelog

## Version Compatibility

| Chart Version | Kubernetes | Helm | AxonOps |
|--------------|------------|------|---------|
| 0.1.x        | 1.19+      | 3.8+ | 1.x     |

For the latest compatibility information, check individual chart documentation.
