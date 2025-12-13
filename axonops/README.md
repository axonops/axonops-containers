# AxonOps Self-Hosted Components

Container images for AxonOps self-hosted infrastructure components.

## Overview

This directory contains production-ready container images for deploying AxonOps infrastructure in self-hosted environments. All components are designed for high availability, security, and operational simplicity.

## Components

### AxonDB Time-Series

**[axondb-timeseries/](./axondb-timeseries/)** - Time-series optimized Apache Cassandra database

Apache Cassandra configured and optimized for time-series workloads with:
- Automated system keyspace initialization
- Custom user management
- Production-ready configuration
- Multi-architecture support (amd64, arm64)
- Comprehensive monitoring via startup banner

**Status**: ✅ Production Ready
**Images**: `ghcr.io/axonops/axondb-timeseries`
**Documentation**: [Full Documentation](./axondb-timeseries/README.md)

### AxonDB Search (Coming Soon)

Search-optimized Apache Cassandra database for AxonOps search workloads.

**Status**: 🚧 In Development

### AxonOps Server (Coming Soon)

AxonOps control plane and API server.

**Status**: 🚧 Planned

### AxonOps Dashboard (Coming Soon)

AxonOps web dashboard and UI.

**Status**: 🚧 Planned

## Quick Start

See individual component documentation for detailed setup instructions:

- [AxonDB Time-Series Quick Start](./axondb-timeseries/README.md#quick-start)

## Architecture

AxonOps self-hosted components are designed to work together:

```
┌─────────────────────────────────────────────────┐
│  AxonOps Dashboard                              │
│  (Web UI)                                       │
└────────────────┬────────────────────────────────┘
                 │
┌────────────────┴────────────────────────────────┐
│  AxonOps Server                                 │
│  (Control Plane & API)                          │
└────────────┬───────────────┬────────────────────┘
             │               │
    ┌────────┴────────┐ ┌───┴──────────────┐
    │  AxonDB         │ │  AxonDB          │
    │  Time-Series    │ │  Search          │
    │  (Metrics)      │ │  (Logs/Events)   │
    └─────────────────┘ └──────────────────┘
```

## Development

See individual component DEVELOPMENT.md files for:
- Building containers locally
- Running tests
- Development workflow
- Contributing guidelines

## Publishing

All components follow the same release pattern:

### Development Releases
Published to `ghcr.io/axonops/development/<component>` for testing

### Production Releases
Published to `ghcr.io/axonops/<component>` after validation

See component-specific RELEASE.md files for detailed release instructions.

## Support

For issues, questions, or contributions:
- [GitHub Issues](https://github.com/axonops/axonops-containers/issues)
- [AxonOps Documentation](https://docs.axonops.com)
- [AxonOps Website](https://axonops.com)

## License

Apache License 2.0 - See [LICENSE](../LICENSE) for details.
