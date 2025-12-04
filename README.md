# AxonOps Container Images

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![GitHub Issues](https://img.shields.io/github/issues/axonops/axonops-cassandra-containers)](https://github.com/axonops/axonops-cassandra-containers/issues)
[![Multi-Architecture](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-brightgreen)](https://github.com/axonops/axonops-cassandra-containers)

Container build definitions and CI/CD pipelines for AxonOps container images.

## Table of Contents

- [Components](#components)
- [Repository Conventions](#repository-conventions)
- [Getting Started](#getting-started)
- [Development](#development)
- [Releasing](#releasing)
  - [Development Releases (Testing)](#development-releases-testing)
  - [Production Releases (Main)](#production-releases-main)
  - [Development Release Process](#development-release-process-quick-reference)
  - [Production Release Process](#production-release-process-quick-reference)
- [Acknowledgements](#acknowledgements)
- [License](#license)
- [Legal Notices](#legal-notices)

## Components

- **[k8ssandra/](./k8ssandra/)** - Apache Cassandra with AxonOps integration for K8ssandra Operator

## Repository Conventions

- **Multi-architecture support**: linux/amd64, linux/arm64
- **Published to**: GitHub Container Registry `ghcr.io/axonops/<image-name>:<tag>`
- **Automated CI/CD**: GitHub Actions with comprehensive testing
- **Security scanning**: Trivy vulnerability scanning on all images
- **Base images**: Official upstream sources where possible

## Getting Started

Each component has its own documentation with detailed instructions:

- [K8ssandra Documentation](./k8ssandra/README.md)

## Development

**Branch Structure:**
- `development` - Default branch, all feature work starts here
- `main` - Production releases only
- `feature/*` - Feature branches (merge to development)

See [DEVELOPMENT.md](./DEVELOPMENT.md) for complete guidelines.

**Developer Workflow:**
```bash
# Work on development branch
git checkout development
git pull origin development
git checkout -b feature/my-feature

# Make changes, create PR to development
# After merge and testing, promote to main via PR
```

## Releasing

### Development Publishing

**Purpose:** Publish images to development registry for testing before production release.

**Registry:** `ghcr.io/axonops/development-<image-name>`

**Characteristics:**
- Images can be overwritten (no version validation)
- Allows iterative testing with same tag
- No GitHub Releases created
- Tagged from `development` branch

**Process:**

```bash
# 1. Tag development branch (any name, e.g., dev-feature-x, dev-1.0.0)
git checkout development && git pull origin development
git tag dev-1.0.0 && git push origin dev-1.0.0

# 2. Trigger development publish workflow
gh workflow run development-<component>-publish.yml \
  -f dev_git_tag=dev-1.0.0 \
  -f container_version=dev-1.0.0

# 3. Test development image
docker pull ghcr.io/axonops/development-<image>:5.0.6-dev-1.0.0
# Run tests, validate functionality

# 4. When ready, promote to production via PR: development → main
```

**Use for:** Feature testing, integration testing, QA validation before production.

---

### Production Publishing

**Purpose:** Publish stable, tested images to production registry.

**Registry:** `ghcr.io/axonops/<image-name>`

**Characteristics:**
- Immutable (version validation prevents overwrites)
- Creates GitHub Releases
- Tagged from `main` branch only
- Only after testing in development

**Prerequisites:**
- Changes merged to `development` and tested
- Development images validated (if published)
- PR from `development` → `main` approved and merged

**Process:**

**Step 1: Create Git Tag on Main Branch**

**IMPORTANT:** Tags must be created on the `main` branch. The publish workflow will validate this.

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main

# Tag the commit
git tag 1.0.0

# Push tag to remote
git push origin 1.0.0
```

The tag can be any name (e.g., `1.0.0`, `v1.0.0`, `release-2024-12`). It marks the exact code snapshot to build from.

**Note:** If you tag a commit not on `main`, the publish workflow will fail with an error.

**Step 2: Trigger Publish Workflow**

You can trigger the publish workflow via **GitHub CLI** or **GitHub UI**.

#### Option A: GitHub CLI

Install and authenticate (first time only):
```bash
# macOS
brew install gh

# Linux
# See: https://github.com/cli/cli#installation

# Authenticate
gh auth login
```

Trigger the workflow:
```bash
gh workflow run <component>-publish.yml \
  -f main_git_tag=1.0.0 \
  -f container_version=1.0.0
```

**Arguments explained:**
- `-f main_git_tag=1.0.0` - The git tag on main branch to checkout and build (the tag you created in Step 1)
- `-f container_version=1.0.0` - The container version for GHCR images (e.g., creates `5.0.6-1.0.0`)

Monitor progress:
```bash
gh run watch
```

#### Option B: GitHub UI

1. Navigate to **Actions** tab in GitHub repository
2. Select the publish workflow (e.g., **K8ssandra Publish to GHCR**)
3. Click **Run workflow** button (top right)
4. A form appears with inputs:
   - **main_git_tag**: Enter the git tag on main branch created in Step 1 (e.g., `1.0.0`)
     - This determines which code to build
   - **container_version**: Enter the container version (e.g., `1.0.0`)
     - This becomes the container version on published images
     - Example: `5.0.6-1.0.0` where `1.0.0` is the container version
5. Click **Run workflow** to start

**Step 3: Workflow Execution**

The workflow will:
- Validate tag is on main branch (fails if not)
- Validate `container_version` doesn't exist in GHCR (fails if duplicate)
- Checkout the `main_git_tag` commit (exact code snapshot)
- Run full test suite
- Build multi-arch images (amd64, arm64)
- Publish to GHCR with tags like `5.0.6-<container_version>`
- Create GitHub Release named `<component>-<container_version>`

**Step 4: Verify Release**

```bash
# View GitHub Release
gh release view k8ssandra-1.0.0

# Pull and test image
docker pull ghcr.io/axonops/axonops-cassandra-containers:5.0.6-1.0.0
```

### Component Release Documentation

Each component has detailed release documentation:
- [K8ssandra Release Process](./k8ssandra/RELEASE.md)

## Acknowledgements

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

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Legal Notices

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
