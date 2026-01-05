# AxonOps Container Images

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![GitHub Issues](https://img.shields.io/github/issues/axonops/axonops-containers)](https://github.com/axonops/axonops-containers/issues)
[![Multi-Architecture](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-brightgreen)](https://github.com/axonops/axonops-containers)

Container build definitions and CI/CD pipelines for AxonOps container images.

## Table of Contents

- [Components](#components)
- [Red Hat Universal Base Image (UBI)](#red-hat-universal-base-image-ubi)
- [Repository Conventions](#repository-conventions)
- [Security](#security)
  - [CVE Policy](#cve-policy)
  - [Gold Standard Security Deployment](#gold-standard-security-deployment)
- [Development](#development)
  - [Container Security Standards](#container-security-standards-all-components)
- [Releasing](#releasing)
  - [Development Publishing](#development-publishing)
  - [Production Publishing](#production-publishing)
  - [Component Release Documentation](#component-release-documentation)
- [Acknowledgements](#acknowledgements)
  - [Apache Cassandra](#apache-cassandra)
  - [K8ssandra](#k8ssandra)
- [License](#license)
- [Legal Notices](#legal-notices)
  - [Trademarks](#trademarks)

## Components

### Kubernetes Distributions
- **[k8ssandra/](./k8ssandra/)** - Apache Cassandra with AxonOps integration for K8ssandra Operator

### AxonOps Self-Hosted
- **[axonops/](./axonops/)** - AxonOps self-hosted stack (complete platform components)

## Red Hat Universal Base Image (UBI)

All containers in this repository are built on **Red Hat Universal Base Image (UBI) 9**, providing enterprise-grade security, stability, and compliance.

**Why Red Hat UBI?**

- **Freely Redistributable** - No subscription required to use or redistribute
- **Enterprise Security** - Regular security updates and CVE patches from Red Hat
- **Production Hardened** - Minimal attack surface with only essential packages
- **Compliance Ready** - Meets requirements for regulated industries (finance, healthcare, government)
- **Long-Term Support** - Stable base with predictable lifecycle (RHEL 9 supported until 2032)
- **Container Optimized** - Purpose-built for containerized workloads with minimal footprint

**Learn More:**
- [Red Hat UBI Project](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image)
- [UBI 9 Container Catalog](https://catalog.redhat.com/software/containers/search?q=ubi9)
- [UBI Documentation](https://developers.redhat.com/products/rhel/ubi)

## Repository Conventions

- **Multi-architecture support**: linux/amd64, linux/arm64
- **Published to**: GitHub Container Registry `ghcr.io/axonops/<image-name>:<tag>`
- **Automated CI/CD**: GitHub Actions with comprehensive testing
- **Security scanning**: Trivy vulnerability scanning on all images
- **Base images**: Red Hat UBI 9 (digest-pinned for supply chain security)

## Security

### CVE Policy

**Immutable Tagging:** All container images use immutable versioning. When CVEs are discovered and patched, we release NEW versions rather than overwriting existing tags.

**Version Increments:**
- Critical CVEs (CRITICAL, HIGH severity): Immediate patch release (e.g., `1.0.3` → `1.0.4`)
- Non-critical CVEs (MEDIUM, LOW): Batched into monthly releases
- Patch version increments may include: CVE fixes, component updates (e.g., AxonOps agent), bug fixes, or feature additions

**Latest Tag Behavior:**
- `latest` tag always points to the most recent secure version
- Provides automatic security updates when using latest tag
- **NOT recommended for production** - use specific versions instead

**Production Deployment:**
- Always pin to specific immutable versions (e.g., `5.0.6-v0.1.110-1.0.5`)
- Never use `latest`, `5.0-latest`, or `{version}-latest` tags in production
- Review release notes before upgrading
- Test upgrades in non-production environments first

**CVE Notifications:**
- Automated nightly security scans with Trivy
- Email notifications for new CRITICAL/HIGH CVEs
- Transparent disclosure in release notes

**For highest security environments**, see [Gold Standard Security Deployment](#gold-standard-security-deployment).

---

### Gold Standard Security Deployment

**Digest-Based Deployment** provides the highest level of security and immutability for container deployments.

#### What is Digest-Based Deployment?

Instead of using tags (which can be mutable), deploy using the image's SHA256 digest:

```yaml
# Tag-based (good)
image: ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Digest-based (best)
image: ghcr.io/axonops/k8ssandra/cassandra@sha256:412c85225...
```

#### Benefits

✅ **100% Immutable** - Guaranteed exact same image every time, forever

✅ **Survives Tag Manipulation** - Unaffected if tags are accidentally or maliciously changed

✅ **Compliance Ready** - Meets requirements for regulated environments (finance, healthcare, government)

✅ **Audit Trail** - Digest in deployment manifest provides cryptographic proof of exact image

✅ **Supply Chain Security** - Combined with signature verification, provides complete provenance

#### Finding Image Digests

**Method 1: From GHCR UI**
1. Navigate to package: https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra
2. Click on specific version
3. Copy SHA256 digest shown

**Method 2: Using Docker/Podman**
```bash
# Pull the image first
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Get digest
docker inspect ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5 \
  --format='{{index .RepoDigests 0}}'

# Output: ghcr.io/axonops/k8ssandra/cassandra@sha256:412c85225...
```

**Method 3: During Workflow**
- Check GitHub Actions workflow logs after publishing
- Digest printed in build output

#### Kubernetes Deployment Example

**K8ssandraCluster manifest:**
```yaml
apiVersion: k8ssandra.io/v1alpha1
kind: K8ssandraCluster
metadata:
  name: production-cluster
spec:
  cassandra:
    serverVersion: "5.0.6"
    # Use digest instead of tag
    serverImage: "ghcr.io/axonops/k8ssandra/cassandra@sha256:412c852252ec4ebcb8d377a505881828a7f6a5f9dc725cc4f20fda2a1bcb3494"
    datacenters:
      - metadata:
          name: dc1
        size: 3
        # ... rest of configuration
```

#### Verifying Signatures

All images published to GHCR are signed with [Sigstore Cosign](https://github.com/sigstore/cosign) using keyless signing.

**Standard Verification:**
```bash
# Install cosign
brew install sigstore/tap/cosign  # macOS
# or: https://docs.sigstore.dev/cosign/installation/

# Verify signature
cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Check signature exists
cosign tree ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

**Troubleshooting (macOS Issues):**

If you encounter issues with local cosign on macOS, use the official Cosign container image:

```bash
# Using Docker
docker run --rm gcr.io/projectsigstore/cosign:v2.4.1 verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Using Podman
podman run --rm gcr.io/projectsigstore/cosign:v2.4.1 verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

This uses the [official Cosign container](https://github.com/sigstore/cosign) and works reliably across all platforms.

**Successful verification proves:**
- ✅ Image was built by official GitHub Actions workflow
- ✅ Image has not been tampered with
- ✅ Build provenance is traceable to specific commit and workflow run

#### Enforcing Signed Images in Kubernetes

For production environments requiring signature verification before deployment:

**Policy Enforcement Tools:**
- **Kyverno** - Kubernetes native policy engine
- **OPA Gatekeeper** - Open Policy Agent for Kubernetes
- **Sigstore Policy Controller** - Official Sigstore admission controller

**Example: Kyverno Policy**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-axonops-images
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-signature
      match:
        resources:
          kinds:
            - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/axonops/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/axonops/axonops-containers/*"
                    issuer: "https://token.actions.githubusercontent.com"
```

**Cloud Provider Support:**
- **AWS EKS** - Use Kyverno or OPA Gatekeeper via Helm
- **Google GKE** - Binary Authorization with Cosign attestations
- **Azure AKS** - Azure Policy with Ratify + Cosign
- **Rancher/RKE** - Kyverno or OPA Gatekeeper via Rancher Apps

For detailed setup, see your Kubernetes distribution's documentation on admission controllers and image policy enforcement.

#### Best Practices

**For Production Clusters:**
1. ✅ Use digest-based deployment
2. ✅ Verify signatures before deployment (signed images)
3. ✅ Pin digest in version control (GitOps)
4. ✅ Document digest → version mapping in release notes
5. ✅ Update digests only after testing in non-production

**For Development/Testing:**
- Tag-based deployment is acceptable for faster iteration
- Use development image registry for testing

**Updating Digests:**
```bash
# 1. Pull new version
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# 2. Get new digest
NEW_DIGEST=$(docker inspect ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5 \
  --format='{{index .RepoDigests 0}}' | cut -d@ -f2)

# 3. Update manifest
sed -i "s|@sha256:.*|@${NEW_DIGEST}\"|" k8ssandra-cluster.yaml

# 4. Review, test, and commit
git diff k8ssandra-cluster.yaml
```

---

## Development

**Branch Structure:**
- `development` - Default branch, commit directly here
- `main` - Production releases only (PR required)
- `feature/*` - Optional, for complex features

See [DEVELOPMENT.md](./DEVELOPMENT.md) for complete guidelines.

**Developer Workflow:**
```bash
# Work directly on development
git checkout development && git pull origin development
git add . && git commit -S -m "Add feature" && git push origin development

# For production: create PR development → main (approval required)
```

### Container Security Standards (ALL Components)

**Every container we build MUST follow these security practices:**

1. **Digest Pinning (Supply Chain Security)**
   - **ALWAYS** pin base images by SHA256 digest, NEVER by tag
   - Tags are mutable - can be replaced maliciously
   - Digests are immutable - cryptographically guaranteed
   - Example:
     ```dockerfile
     # CORRECT
     FROM upstream/image@sha256:abc123...

     # WRONG - Supply chain vulnerability!
     FROM upstream/image:latest
     FROM upstream/image:v1.0.0
     ```

2. **Container Signing (Authenticity)**
   - **ALL** published images MUST be signed with Cosign
   - Use keyless signing with GitHub OIDC (no secret management)
   - Sign by digest immediately after build
   - Publish to `ghcr.io/axonops/<component>/<image-name>:tag`

3. **Verification & Testing**
   - Verify checksums for downloaded artifacts (RPMs, tarballs, etc.)
   - Verify base image digest matches expected version
   - Automated startup error detection
   - Security scanning with Trivy before publishing

**Why these standards matter:**
- Prevents supply chain attacks (malicious base images)
- Ensures image authenticity (Cosign signatures)
- Provides full audit trail (digests + signatures)
- Meets compliance requirements for regulated environments

## Releasing

### Development Publishing

**Purpose:** Publish signed images to development registry for testing before production release.

**Registry:** `ghcr.io/axonops/development/<component>/<image-name>`

**Example:** `ghcr.io/axonops/development/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0`

**Characteristics:**
- All images are Cosign signed (same as production)
- Uses same security standards as production (digest pinning, checksums, verification)
- Allows testing with specific versions
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

# 4. Promote to main (auto-creates PR)
git tag merge-1.0.0 && git push origin merge-1.0.0
# PR auto-created, review and merge to main
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

Trigger the signed publish workflow:
```bash
gh workflow run <component>-publish-signed.yml \
  -f main_git_tag=1.0.0 \
  -f container_version=1.0.0
```

**Arguments explained:**
- `-f main_git_tag=1.0.0` - The git tag on main branch to checkout and build (the tag you created in Step 1)
- `-f container_version=1.0.0` - The container version for GHCR images (e.g., creates `5.0.6-v0.1.110-1.0.5`)

**Note:** Use the `-signed` workflows (`k8ssandra-publish-signed.yml`) for new releases. These publish to the new image paths with cryptographic signatures. Old workflows remain for backward compatibility but are deprecated.

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
     - Example: `5.0.6-v0.1.110-1.0.5` where `1.0.0` is the container version
5. Click **Run workflow** to start

**Step 3: Workflow Execution**

The signed publish workflow will:
- Validate tag is on main branch (fails if not)
- Validate `container_version` doesn't exist in GHCR (fails if duplicate)
- Checkout the `main_git_tag` commit (exact code snapshot)
- Run full test suite
- Build multi-arch images (amd64, arm64)
- Push to GHCR with multi-dimensional tags
- **Sign images** with Sigstore Cosign (keyless, GitHub OIDC)
- Re-push tags to ensure proper GHCR UI display
- Create GitHub Release named `<component>-signed-<container_version>`

**Images are signed** using keyless signing with transparency log entries. Signatures can be verified with `cosign verify` (see [Verifying Signatures](#verifying-signatures)).

**Step 4: Verify Release**

```bash
# View GitHub Release
gh release view k8ssandra-signed-1.0.0

# Pull and test image
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Verify signature
cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Or check signature exists
cosign tree ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

All production images are cryptographically signed. Signature verification proves the image was built by official workflows and has not been tampered with. See [Gold Standard Security Deployment](#gold-standard-security-deployment) for more details.

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
