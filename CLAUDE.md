# CLAUDE.md – AxonOps Containers

## Purpose

This repository defines, builds, tests, and publishes **production-grade container images** for the AxonOps platform and its integrations. Images are published to `ghcr.io/axonops/` and consumed by AxonOps customers and the open-source community. Treat every change as if it ships to regulated enterprise environments — because it does.

---

## FIRST: Read Before Acting

**Before making ANY changes**, read the relevant documentation. This repo has extensive docs — do not guess at conventions.

### Mandatory Reading (always)
- `DEVELOPMENT.md` — Repository-wide conventions, branch model, release process, code review checklist
- `README.md` — Component catalog, security policy (CVE, Cosign, digest-based deployment), UBI rationale
- `TAG_CHANGELOG.md` — Tag-to-image mapping and release history

### Component-Specific Reading (read when touching that component)

| Component | Read These Files |
|-----------|-----------------|
| **k8ssandra/** | `k8ssandra/README.md`, `k8ssandra/DEVELOPMENT.md`, `k8ssandra/RELEASE.md`, `k8ssandra/UPDATING_K8SSANDRA_VERSIONS.md`, `k8ssandra/README_K8SSANDRA_SETUP.md` |
| **axonops/axondb-timeseries/** | `axonops/axondb-timeseries/README.md`, `axonops/axondb-timeseries/DEVELOPMENT.md`, `axonops/axondb-timeseries/RELEASE.md`, `axonops/axondb-timeseries/5.0.6/tests/README.md` |
| **axonops/axondb-search/** | `axonops/axondb-search/README.md`, `axonops/axondb-search/DEVELOPMENT.md`, `axonops/axondb-search/RELEASE.md` |
| **axonops-schema-registry/** | `axonops-schema-registry/README.md`, `axonops-schema-registry/DEVELOPMENT.md`, `axonops-schema-registry/RELEASE.md` |
| **strimzi/** | `strimzi/README.md` |
| **axonops/charts/** | `axonops/charts/README.md`, plus each sub-chart's `README.md` (`axon-server/`, `axon-dash/`, `axondb-timeseries/`, `axondb-search/`) |
| **docker/** | `docker/README.md` |
| **examples/** | `examples/DEPLOYMENT_GUIDE.md`, `examples/AXONOPS_DEPLOYMENT.md`, `examples/K8SSANDRA_DEPLOYMENT.md`, `examples/STRIMZI_DEPLOYMENT.md`, `examples/NODE_SELECTOR_GUIDE.md` |

### CI/CD Reading (when touching workflows or actions)
- All workflow files: `.github/workflows/<component>-*.yml`
- All composite actions: `.github/actions/<component>-*/action.yml`
- The component's `DEVELOPMENT.md` for workflow documentation

---

## Planning and Progress Tracking

### Always Plan First

Before starting any non-trivial task:

1. **Analyse** — Read all relevant docs and existing code
2. **Plan** — Write a plan with numbered steps, expected outcomes, and risks
3. **Execute** — Work through the plan step by step
4. **Verify** — Check the result against the plan and existing tests

### PROGRESS.md

Maintain a `PROGRESS.md` file in the repo root, updated after each meaningful step:

```markdown
# Progress

## Current Task
<one-line description>

## Status
- [x] Step 1: <description> — DONE
- [x] Step 2: <description> — DONE
- [ ] Step 3: <description> — IN PROGRESS
- [ ] Step 4: <description> — TODO

## Decisions Made
- <decision and rationale>

## Issues Encountered
- <issue and resolution>

## Files Modified
- `path/to/file` — <what changed and why>
```

### SESSION_RESUME.md

Maintain a `SESSION_RESUME.md` file in the repo root with ALL context needed to resume work if the session crashes:

```markdown
# Session Resume

## Task
<full description of what we're doing and why>

## Current State
<what has been done, what is in progress, what remains>

## Key Context
- Branch: <branch name>
- Last commit: <hash and message>
- Component: <which component we're working on>
- Workflow: <if modifying CI, which workflow>

## Important Details
<any non-obvious context, gotchas, or decisions that would be lost>

## Next Steps (in order)
1. <specific next action>
2. <specific next action>

## Files to Review
- `path/to/file` — <why it matters>

## Open Questions
- <anything unresolved>
```

**Update both files as you work. They are your lifeline.**

---

## Repository Structure

```
axonops-containers/
├── .github/
│   ├── workflows/          # All CI/CD workflows (top-level ONLY)
│   │   ├── <component>-build-and-test.yml
│   │   ├── <component>-development-publish-signed.yml
│   │   ├── <component>-publish-signed.yml
│   │   ├── create-promotion-pr.yml
│   │   ├── helm-lint.yml / helm-release.yml / helm-charts-test.yml
│   │   └── ...
│   └── actions/            # Composite actions (reusable steps)
│       ├── <component>-<action-name>/action.yml
│       └── ...
├── k8ssandra/              # Apache Cassandra + K8ssandra Operator + AxonOps
│   ├── 4.0/ 4.1/ 5.0/     # Version-specific Dockerfiles
│   ├── scripts/            # Build/install utilities
│   ├── examples/           # K8ssandraCluster manifests
│   └── *.md                # Component docs
├── axonops/                # AxonOps self-hosted platform
│   ├── axondb-timeseries/  # Cassandra 5.0.6 for metrics (UBI 9 from scratch)
│   ├── axondb-search/      # OpenSearch 3.3.2 for logs (UBI 9 from scratch)
│   └── charts/             # Helm charts (axon-server, axon-dash, axondb-*)
├── axonops-schema-registry/ # Confluent-compatible Schema Registry (Go binary)
│   ├── 0.2.0/              # Version-specific Dockerfile
│   └── *.md                # Component docs
├── strimzi/                # Apache Kafka + Strimzi Operator + AxonOps
├── docker/                 # Docker Compose for local/standalone deployment
├── examples/               # Cross-component deployment guides and manifests
├── DEVELOPMENT.md          # Repository-wide conventions (READ THIS)
├── README.md               # Public-facing overview and security docs
└── TAG_CHANGELOG.md        # Git tag → container image mapping
```

---

## Components At a Glance

| Component | Base Image | Registry Path | Status |
|-----------|-----------|---------------|--------|
| **k8ssandra** | `k8ssandra/cass-management-api` (digest-pinned) | `ghcr.io/axonops/k8ssandra/cassandra` | Production |
| **axondb-timeseries** | `ubi9/ubi-minimal` (digest-pinned) | `ghcr.io/axonops/axondb-timeseries` | Production |
| **axondb-search** | `ubi9/ubi-minimal` (digest-pinned) | `ghcr.io/axonops/axondb-search` | Production |
| **axonops-schema-registry** | `ubi9/ubi-minimal` (digest-pinned) | `ghcr.io/axonops/axonops-schema-registry` | New |
| **strimzi** | `strimzi/kafka` (digest-pinned) | `ghcr.io/axonops/strimzi/kafka` | Production |
| **Helm charts** | N/A | `ghcr.io/axonops/charts/<chart>` | Production |

Development images publish to `ghcr.io/axonops/development/<component>/...`

---

## Hard Rules — Non-Negotiable

### 1. Supply Chain Security: Digest Pinning

**ALWAYS pin base images by SHA256 digest. NEVER by tag.**

```dockerfile
# ✅ CORRECT — immutable, cryptographically verified
ARG BASE_DIGEST=sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7...
FROM docker.io/k8ssandra/cass-management-api@${BASE_DIGEST}

# ❌ WRONG — mutable tag, supply chain attack vector
FROM docker.io/k8ssandra/cass-management-api:5.0.6-ubi
FROM docker.io/k8ssandra/cass-management-api:latest
```

Comment both the human-readable version and the digest in the Dockerfile.

### 2. Container Signing

ALL published images MUST be signed with Cosign (keyless, GitHub OIDC). This is handled by the `<component>-sign-container` composite actions. Never bypass signing.

### 3. Multi-Architecture

ALL images MUST support `linux/amd64` and `linux/arm64`. Use `docker buildx` for multi-arch builds. Test on both architectures.

### 4. Non-Root Execution

Run processes as non-root with explicit UIDs/GIDs. If root is required, add a comment explaining why and revert to the runtime user.

### 5. Red Hat UBI 9 Base

All images built from scratch use Red Hat Universal Base Image 9 (`ubi9/ubi-minimal`). Do not introduce alternative base images without explicit justification.

### 6. Security Scanning

Trivy scans run on all images. Address CRITICAL and HIGH vulnerabilities. Document exceptions in component-specific `.trivyignore` files with inline comments explaining why.

### 7. No Secrets in Images

Never bake secrets, credentials, tokens, or environment-specific values into images or workflow definitions.

---

## Git Workflow

### Branch Model

| Branch | Purpose | Push Policy | Publishes To |
|--------|---------|-------------|-------------|
| `development` | Default branch, all development | Direct commits OK | `ghcr.io/axonops/development/...` |
| `main` | Production releases only | PR required (from development) | `ghcr.io/axonops/...` |
| `feature/<n>` | Complex features (optional) | Merge to development | N/A |

### Commit Conventions
- Use conventional commit messages (e.g., `feat:`, `fix:`, `docs:`, `ci:`)
- Keep commits focused and atomic
- **No attribution to tools or AI in commit messages**
- Sign commits with `-S` flag

### Release Flow

```
development ──[merge-* tag]──> auto PR to main ──[approve+merge]──> main ──[tag]──> publish workflow
```

1. Tag `development` with `merge-X.Y.Z` → auto-creates PR to `main`
2. Review and merge PR to `main`
3. Tag `main` with version (e.g., `1.0.5`, `axondb-timeseries-1.3.0`)
4. Manually trigger `<component>-publish-signed.yml` with the tag

### Tagging Conventions

| Component | Tag Format | Example |
|-----------|-----------|---------|
| k8ssandra | `<version>` | `1.0.5` |
| axondb-timeseries | `axondb-timeseries-<version>` | `axondb-timeseries-1.3.0` |
| axondb-search | `axondb-search-<version>` | `axondb-search-1.3.0` |
| axonops-schema-registry | `axonops-schema-registry-<SR_VERSION>-<BUILD>` | `axonops-schema-registry-0.2.0-1` |
| strimzi | `<env>/<strimzi>-kafka-<kafka>-<build>` | `release/0.49.1-kafka-4.1.0-1` |
| Development | `dev-<version>` or `vdev-<component>-<version>` | `dev-1.0.0` |
| Promotion | `merge-<version>` | `merge-1.0.5` |

---

## CI/CD Patterns

### Three-Workflow Pattern (per component)

Every component follows this pattern:

1. **`<component>-build-and-test.yml`** — Automatic on push/PR, runs full test suite, does NOT publish
2. **`<component>-development-publish-signed.yml`** — Manual, publishes signed images to development registry
3. **`<component>-publish-signed.yml`** — Manual, publishes signed images to production registry, creates GitHub Release

### Composite Actions

- Stored in `.github/actions/<component>-<action-name>/action.yml`
- Naming: `<component>-<action-name>` (e.g., `k8ssandra-test-cqlai`, `axondb-search-verify-certificates`)
- Use `-k3s-` infix for Kubernetes-specific actions (e.g., `k8ssandra-k3s-test-cqlai`)
- Always include error handling and safe defaults
- Document inputs clearly

### Workflow Conventions

- All workflows live in `.github/workflows/` (top-level only)
- Name workflows clearly: `<component>-<purpose>.yml`
- Use matrix builds for multiple versions
- Filter with `paths:` to avoid rebuilding unrelated components
- Use GitHub Actions caching: `cache-from: type=gha`, `cache-to: type=gha,mode=max`
- External dependency caches: date-based keys (e.g., `helm-${{ runner.os }}-$(date +%Y-%m-%d)`)
- Use `set -euo pipefail` in all RUN/shell steps

### Testing Requirements

Every workflow must include:
- Container build verification
- Service health checks (liveness/readiness)
- Functional tests appropriate to the component
- Process ownership verification (non-root)
- Security scanning (Trivy)
- Startup error detection (scan logs for ERROR/WARN/FATAL)

### Registry and Tags

**Production:** `ghcr.io/axonops/<component>/<image-name>:<tag>`
**Development:** `ghcr.io/axonops/development/<component>/<image-name>:<tag>`

K8ssandra uses multi-dimensional tagging:
```
{CASS}-v{K8S_API}-{AXON}   # Immutable (e.g., 5.0.6-v0.1.110-1.0.5)
{CASS}-v{K8S_API}           # Floating: latest AxonOps for this combo
{CASS}                       # Floating: latest k8ssandra + AxonOps
{MAJOR}-latest               # Floating: latest minor in major
latest                       # Floating: latest everything
```

AxonDB uses simpler tagging:
```
{UPSTREAM}-{AXON}           # Immutable (e.g., 5.0.6-1.3.0 or 3.3.2-1.3.0)
{UPSTREAM}                   # Floating
latest                       # Floating
```

Schema Registry uses multi-dimensional versioning (SR version + build number):
```
{SR_VERSION}-{BUILD}        # Immutable (e.g., 0.2.0-1)
{SR_VERSION}                 # Floating: latest build for this SR version
latest                       # Floating: latest everything
```

---

## Dockerfile Conventions

### Shell Practices
```dockerfile
RUN set -euo pipefail && \
    microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y \
        package-name && \
    microdnf clean all
```

### Package Installation
- Use `microdnf`/`dnf` with `--nodocs` and `clean all`
- Lock critical tool versions explicitly
- Remove build-time tooling in the final stage (multi-stage builds)
- Verify checksums for downloaded artifacts (RPMs, tarballs)

### Labels
```dockerfile
LABEL org.opencontainers.image.source="https://github.com/axonops/axonops-containers" \
      org.opencontainers.image.vendor="AxonOps" \
      org.opencontainers.image.licenses="Apache-2.0"
```

### Container Features (required for new components)
- **Startup version banner** — Display component versions, build info, supply chain metadata on startup
- **Build-info file** — Write `/etc/axonops/build-info.txt` at build time with static metadata
- **Healthcheck script** — Three-mode probe support: `startup`, `liveness`, `readiness`
- **Semaphore files** — Coordinate async initialization with healthcheck probes; store in persistent volume path

### Security Practices
- Expose only necessary ports; document exposed ports in comments
- Avoid `curl | bash`; prefer package managers or pinned/verified artifacts
- Least-privilege file permissions for the runtime user
- Add meaningful healthcheck commands

---

## Helm Chart Conventions

- Charts live in `axonops/charts/<chart-name>/`
- Each chart has its own `README.md`, `values.yaml`, CI values in `ci/`
- Linting runs automatically via `helm-lint.yml` (matrix across all detected charts)
- Published as OCI packages to `ghcr.io/axonops/charts/<chart-name>`
- Install order matters: axondb-timeseries → axondb-search → axon-server → axon-dash

---

## Pre-commit and Linting

The repo uses pre-commit hooks (`.pre-commit-config.yaml`):
- `trailing-whitespace` (excludes `.md`)
- `end-of-file-fixer` (excludes `.md`)
- `check-yaml` (excludes Helm charts and Strimzi examples)
- `yamllint` with config from `.yamllint` (excludes Helm charts and GitHub workflows)

YAML lint rules: braces, brackets, colons, empty-lines, hyphens, key-duplicates, trailing-spaces enabled. Line-length, indentation, comments disabled.

---

## Adding a New Component

Follow the checklist from `DEVELOPMENT.md`:

1. Create component directory: `<component-name>/`
2. Add version subdirectories: `<component-name>/<version>/`
3. Create Dockerfile following all security and multi-arch conventions
4. Add component `README.md` with: installation, env vars, prerequisites, troubleshooting, examples
5. Add `DEVELOPMENT.md` with: workflow docs, composite action catalog, local testing instructions
6. Add `RELEASE.md` with: step-by-step release process, inputs, troubleshooting
7. Create `.trivyignore` with documented exceptions
8. Create GitHub Actions workflows (build-and-test, dev-publish, prod-publish)
9. Create composite actions in `.github/actions/<component>-*/`
10. Add deployment examples in `<component-name>/examples/` or `examples/`
11. Update root `README.md` — add to Components section
12. Update root `DEVELOPMENT.md` — add to component catalog
13. Update `TAG_CHANGELOG.md` — add new component section
14. Update acknowledgements and legal notices if new upstream dependencies

---

## Key Technical Details Per Component

### k8ssandra
- Extends k8ssandra Management API base image (Docker Hub, digest-pinned)
- Digests stored in `K8SSANDRA_VERSIONS` GitHub repository variable (JSON, composite keys: `{CASS}+{K8S_API}`)
- Installs: AxonOps agent (standalone + Java agent), cqlai, jemalloc
- Supported Cassandra versions: 5.0.1 through 5.0.6 (only 5.0 currently published)
- E2E tests use k3s on GitHub Actions runners
- `scripts/install_k8ssandra.sh` and `scripts/rebuild.sh` for local dev

### axondb-timeseries
- Cassandra 5.0.6 built from scratch on UBI 9 minimal
- Cassandra tarball downloaded and verified (SHA512)
- cqlai installed from GitHub Releases
- 14+ environment variables for configuration (CASSANDRA_*, AXONOPS_DB_*)
- System keyspace initialization script converts to NetworkTopologyStrategy
- Custom user creation with semaphore coordination
- Three-mode healthcheck (startup waits for init semaphores)

### axondb-search
- OpenSearch 3.3.2 built from scratch on UBI 9 minimal
- AxonOps-branded TLS certificates (RSA 3072, not demo certificates)
- Admin user replacement model (custom user replaces default, never both)
- 20 environment variables for configuration
- Background security initialization with semaphore coordination
- 15 composite actions for comprehensive testing

### axonops-schema-registry
- Go binary (axonops-schema-registry) built from scratch on UBI 9 minimal
- Tarball downloaded from GitHub Releases with SHA256 verification
- Multi-dimensional versioning: SR_VERSION (e.g., 0.2.0) + BUILD (integer, e.g., 1)
- Port 8081, health at `GET /`, Swagger at `GET /docs`
- Supports multiple storage backends: PostgreSQL, MySQL, Cassandra 5+, memory
- Lightweight: single stateless binary, ~50MB memory
- Three-mode healthcheck (startup: process + port, liveness: process, readiness: HTTP 200)
- 9 composite actions for comprehensive testing

### strimzi
- Extends Strimzi Kafka base image (Quay.io, digest-pinned)
- Supports Kafka 3.x (axon-kafka3-agent) and 4.x (axon-kafka4-agent)
- KRaft mode only (no ZooKeeper)
- AxonOps wrapper script injected into Kafka startup scripts
- Tag format: `<env>/<strimzi-version>-kafka-<kafka-version>-<build>`

### Helm Charts
- Four charts: axon-server, axon-dash, axondb-timeseries, axondb-search
- Published as OCI to GHCR
- Linted on every push/PR
- Integration tests via `axonops-helm-integration-tests.yml`

---

## Things to Avoid

- Adding base images other than UBI 9 without explicit justification
- Using mutable tags (`latest`, version tags) in FROM statements
- Running as root without documented reason
- Embedding secrets, tokens, or env-specific config in images or workflows
- Creating unused or ad-hoc tags in the registry
- Complex logic in CI workflows when simple step sequences suffice
- Skipping tests in publish workflows
- Modifying workflows without testing the change (use `workflow_dispatch` for manual testing)
- Duplicating logic that should be a composite action
- Forgetting to update `TAG_CHANGELOG.md` after a release
- Using `-latest` tags in any production example or documentation
- Confusing SR_VERSION (application version) with BUILD (container build number) for schema-registry

---

## Scope of Assistance

Use these rules whenever you:
- Generate or modify Dockerfiles / Containerfiles
- Propose changes to GitHub Actions workflows or composite actions
- Suggest improvements to container security, size, or runtime configuration
- Work on Helm charts or Kubernetes manifests
- Update documentation or examples
- Add new components or features

If explicitly asked to break these rules, confirm the implications and clearly mark the resulting code as an exception to standard policy.

