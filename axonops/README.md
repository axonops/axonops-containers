# AxonOps Self-Hosted Stack

Container images for deploying the AxonOps platform in self-hosted environments.

## What is AxonOps?

**AxonOps** is a comprehensive monitoring, management, and operations platform for Apache Cassandra and Apache Kafka. It provides enterprises with complete observability, automated operations, and expert guidance for managing distributed data infrastructure at scale.

### For Apache Cassandra

AxonOps provides:
- **Real-time Monitoring** - Comprehensive metrics, health scoring, and performance insights
- **Automated Operations** - Backup/restore, repairs, compactions, and maintenance automation
- **Query Analysis** - Slow query detection, CQL workload analysis, and optimization recommendations
- **Capacity Planning** - Resource utilization tracking, growth forecasting, and scaling guidance
- **Alerting & Incident Management** - Intelligent alerting with context-aware notifications
- **Expert Guidance** - Built-in best practices and operational recommendations from Cassandra experts

### For Apache Kafka

AxonOps delivers:
- **Complete Visibility** - Broker, topic, partition, and consumer group monitoring
- **Performance Optimization** - Throughput analysis, latency tracking, and bottleneck identification
- **Operational Automation** - Topic management, rebalancing, and maintenance workflows
- **Data Quality Monitoring** - Message delivery tracking and data integrity verification
- **Cluster Health Management** - Proactive health checks and automated remediation

**Learn more:** [axonops.com](https://axonops.com)

## Self-Hosted Deployment

The AxonOps self-hosted stack provides the complete AxonOps platform running in your own infrastructure. This directory contains all necessary container images for deploying AxonOps using Helm charts on Kubernetes.

## Components

### ✅ AxonDB Time-Series

**[axondb-timeseries/](./axondb-timeseries/)** - Time-series optimized Apache Cassandra database

Apache Cassandra 5.0.6 configured and optimized for storing AxonOps metrics and time-series data:
- Automated system keyspace initialization for production readiness
- Custom user management with secure defaults
- Multi-architecture support (amd64, arm64)
- Comprehensive healthcheck probes (startup, liveness, readiness)
- Built on Red Hat UBI 9 with supply chain security

**Status**: Production Ready (v1.0.0)
**Images**: `ghcr.io/axonops/axondb-timeseries`
**Documentation**: [README](./axondb-timeseries/README.md) | [Development](./axondb-timeseries/DEVELOPMENT.md) | [Release](./axondb-timeseries/RELEASE.md)

### ✅ AxonDB Search

**[axondb-search/](./axondb-search/)** - Search and analytics optimized OpenSearch database

OpenSearch 3.3.2 configured and optimized for AxonOps search, logs, and analytics workloads:
- AxonOps-branded TLS certificates (RSA 3072, not demo certificates)
- Secure admin user replacement model (AXONOPS_SEARCH_USER/PASSWORD)
- 20 environment variables for complete customization
- Production settings (bootstrap.memory_lock, thread_pool)
- Multi-architecture support (amd64, arm64)
- Comprehensive healthcheck probes with security plugin health endpoint
- Built on Red Hat UBI 9 with supply chain security

**Status**: Production Ready (v1.0.0)
**Images**: `ghcr.io/axonops/axondb-search`
**Documentation**: [README](./axondb-search/README.md) | [Development](./axondb-search/DEVELOPMENT.md) | [Release](./axondb-search/RELEASE.md)

### 🚧 AxonOps Server (Coming Soon)

AxonOps control plane, API server, and orchestration engine.

**Status**: Planned

### 🚧 AxonOps Dashboard (Coming Soon)

AxonOps web dashboard and user interface.

**Status**: Planned

## Architecture

The AxonOps self-hosted stack consists of multiple components working together:

```
┌─────────────────────────────────────────────────┐
│  AxonOps Dashboard                              │
│  (Web UI for monitoring and management)         │
└────────────────┬────────────────────────────────┘
                 │
┌────────────────┴────────────────────────────────┐
│  AxonOps Server                                 │
│  (Control Plane, API, Orchestration)            │
└────────────┬───────────────┬────────────────────┘
             │               │
    ┌────────┴────────┐ ┌───┴──────────────┐
    │  AxonDB         │ │  AxonDB          │
    │  Time-Series    │ │  Search          │
    │  (Metrics)      │ │  (Logs/Events)   │
    └─────────────────┘ └──────────────────┘
             │               │
    ┌────────┴───────────────┴────────────────┐
    │  Your Cassandra & Kafka Clusters        │
    │  (Monitored infrastructure)             │
    └─────────────────────────────────────────┘
```

## Deployment

The AxonOps self-hosted stack is deployed using **Helm charts** on Kubernetes. The Helm charts handle:
- Component orchestration and configuration
- Networking and service discovery
- Persistent storage provisioning
- Security and access control
- High availability and scaling

**Deployment documentation will be available when Helm charts are released.**

## Development

Each component has its own development documentation:

- [AxonDB Time-Series Development Guide](./axondb-timeseries/DEVELOPMENT.md)

For development workflow:
1. Building containers locally
2. Running tests
3. Contributing guidelines
4. CI/CD pipeline details

## Publishing

All components follow a consistent release pattern:

### Development Releases
- Published to `ghcr.io/axonops/development/<component>`
- Used for testing before production
- Can be overwritten

### Production Releases
- Published to `ghcr.io/axonops/<component>`
- Immutable and cryptographically signed
- Full validation and testing

See component-specific RELEASE.md files for detailed instructions.

## Support

- **Documentation**: [docs.axonops.com](https://docs.axonops.com)
- **Website**: [axonops.com](https://axonops.com)
- **GitHub Issues**: [github.com/axonops/axonops-containers/issues](https://github.com/axonops/axonops-containers/issues)
