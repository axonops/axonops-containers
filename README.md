# AxonOps Container Images

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![GitHub Issues](https://img.shields.io/github/issues/axonops/axonops-cassandra-containers)](https://github.com/axonops/axonops-cassandra-containers/issues)
[![Multi-Architecture](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-brightgreen)](https://github.com/axonops/axonops-cassandra-containers)

Container build definitions and CI/CD pipelines for AxonOps container images.

## 📦 Components

- **[k8ssandra/](./k8ssandra/)** - Apache Cassandra with AxonOps integration for K8ssandra Operator

## 🏗️ Repository Conventions

- **Multi-architecture support**: linux/amd64, linux/arm64
- **Published to**: GitHub Container Registry `ghcr.io/axonops/<image-name>:<tag>`
- **Automated CI/CD**: GitHub Actions with comprehensive testing
- **Security scanning**: Trivy vulnerability scanning on all images
- **Base images**: Official upstream sources where possible

## 🚀 Getting Started

Each component has its own documentation with detailed instructions:

- [K8ssandra Documentation](./k8ssandra/README.md)

## 🛠️ Development

See [DEVELOPMENT.md](./DEVELOPMENT.md) for guidelines on contributing, adding new components, and maintenance procedures.

## 🙏 Acknowledgements

### Apache Cassandra
We extend our appreciation to the [Apache Cassandra](https://cassandra.apache.org/) community for their outstanding work and contributions to the distributed database field. Apache Cassandra is a free and open-source, distributed, wide-column store, NoSQL database management system designed to handle large amounts of data across many commodity servers, providing high availability with no single point of failure.

For more information:
- [Apache Cassandra Website](https://cassandra.apache.org/)
- [Apache Cassandra GitHub](https://github.com/apache/cassandra)
- [Apache Cassandra Documentation](https://cassandra.apache.org/doc/latest/)

### K8ssandra
We acknowledge [K8ssandra](https://k8ssandra.io/) for providing excellent Kubernetes operator and management tools for Apache Cassandra. K8ssandra is a production-ready platform for running Apache Cassandra on Kubernetes, including backup/restore, repairs, and monitoring capabilities.

For more information:
- [K8ssandra Website](https://k8ssandra.io/)
- [K8ssandra GitHub](https://github.com/k8ssandra/k8ssandra-operator)
- [K8ssandra Documentation](https://docs.k8ssandra.io/)

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## ⚖️ Legal Notices

This project may contain trademarks or logos for projects, products, or services. Any use of third-party trademarks or logos are subject to those third-party's policies.

### Trademarks

- **AxonOps** is a registered trademark of AxonOps Limited
- **Apache**, **Apache Cassandra**, and **Cassandra** are trademarks of the Apache Software Foundation or its subsidiaries in Canada, the United States and/or other countries
- **Apache Kafka** and **Kafka** are trademarks of the Apache Software Foundation
- **K8ssandra** is a trademark of the Apache Software Foundation
- **Docker** is a trademark or registered trademark of Docker, Inc. in the United States and/or other countries
- **Podman** is a trademark of Red Hat, Inc.
- **OpenSearch** is a trademark of Amazon.com, Inc. or its affiliates
- **Kubernetes** is a registered trademark of The Linux Foundation

---

<div align="center">

**Made with ❤️ by [AxonOps](https://axonops.com)**

</div>
