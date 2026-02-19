# Tag and Container Changelog

This document tracks the relationship between Git tags and the container images they produce.

## Versioning Pattern

- **AxonDB Time-Series**: `ghcr.io/axonops/axondb-timeseries:5.0.6-{version}` (Cassandra 5.0.6)
- **AxonDB Search**: `ghcr.io/axonops/axondb-search:3.3.2-{version}` (OpenSearch 3.3.2)
- **AxonOps Schema Registry**: `ghcr.io/axonops/axonops-schema-registry:{SR_VERSION}-{CONTAINER_VERSION}` (e.g., 0.2.0-0.0.1)
- **K8ssandra**: `ghcr.io/axonops/k8ssandra/cassandra:{cass_version}-v{k8s_api}-{version}` (Cassandra 5.0.1-5.0.6)
- **Strimzi**: `ghcr.io/axonops/strimzi/kafka:{operator}-{kafka}-{agent}-{version}`
- **Helm Charts**: Published via `helm-release` workflow (OCI to `ghcr.io`)

## AxonDB Time-Series

| Git Tag | Container Image | Date | Status |
|---------|-----------------|------|--------|
| `axondb-timeseries-1.3.0` | `ghcr.io/axonops/axondb-timeseries:5.0.6-1.3.0` | 2026-01-14 | Published |
| `axondb-timeseries-1.2.0` | `ghcr.io/axonops/axondb-timeseries:5.0.6-1.2.0` | 2026-01-09 | Published |
| `axondb-timeseries-0.0.2` | `ghcr.io/axonops/axondb-timeseries:5.0.6-0.0.2` | 2025-12-13 | Published |
| `axondb-timeseries-0.0.1` | `ghcr.io/axonops/axondb-timeseries:5.0.6-0.0.1` | 2025-12-13 | Published |

### Legacy/Development Tags (Time-Series)

| Git Tag | Container Image | Notes |
|---------|-----------------|-------|
| `vdev-axondb-timeseries-1.0.3` | unknown | Development build |
| `vdev-axondb-timeseries-1.0.2` | unknown | Development build |
| `vdev-axondb-timeseries-1.0.1` | unknown | Development build |
| `vdev-axondb-timeseries-1.0.0` | unknown | Development build |
| `timeseries-1.1.0` | unknown | Legacy tag format |
| `timeseries-1.0.0` | unknown | Legacy tag format |
| `v2.4.17-timeseries` | unknown | Legacy tag format |
| `v2.4.7-timeseries-verify-fix` | unknown | Legacy tag format |
| `v2.4.6-timeseries-fix` | unknown | Legacy tag format |

## AxonDB Search

| Git Tag | Container Image | Date | Status |
|---------|-----------------|------|--------|
| `axondb-search-1.5.0` | `ghcr.io/axonops/axondb-search:3.3.2-1.5.0` | 2026-01-20 | Published |
| `axondb-search-1.4.0` | `ghcr.io/axonops/axondb-search:3.3.2-1.4.0` | 2026-01-20 | Published |
| `axondb-search-1.3.0` | `ghcr.io/axonops/axondb-search:3.3.2-1.3.0` | 2026-01-18 | Published |
| `axondb-search-1.2.0` | `ghcr.io/axonops/axondb-search:3.3.2-1.2.0` | 2026-01-09 | Published |
| `axondb-search-3.3.2-1.0.0` | `ghcr.io/axonops/axondb-search:3.3.2-1.0.0` | 2025-12-16 | Published |

### Legacy/Development Tags (Search)

| Git Tag | Container Image | Notes |
|---------|-----------------|-------|
| `vdev-axondb-search-3.3.2-0.1.0` | unknown | Development build |
| `dev-search-0.1.4` | unknown | Development build |
| `dev-search-0.1.2` | unknown | Development build |
| `dev-search-0.1.1` | unknown | Development build |
| `dev-search-0.1.0` | unknown | Development build |
| `search-1.3.0` | unknown | Legacy tag format |

## AxonDB Search Backups

| Git Tag | Container Image | Status |
|---------|-----------------|--------|
| `axondb-search-backups-0.0.26` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.26` | Published |
| `axondb-search-backups-0.0.25` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.25` | Published |
| `axondb-search-backups-0.0.24` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.24` | Published |
| `axondb-search-backups-0.0.23` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.23` | Published |
| `axondb-search-backups-0.0.22` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.22` | Published |
| `axondb-search-backups-0.0.21` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.21` | Published |
| `axondb-search-backups-0.0.20` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.20` | Published |
| `axondb-search-backups-0.0.19` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.19` | Published |
| `axondb-search-backups-0.0.18` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.18` | Published |
| `axondb-search-backups-0.0.17` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.17` | Published |
| `axondb-search-backups-0.0.16` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.16` | Published |
| `axondb-search-backups-0.0.15` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.15` | Published |
| `axondb-search-backups-0.0.14` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.14` | Published |
| `axondb-search-backups-0.0.13` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.13` | Published |
| `axondb-search-backups-0.0.12` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.12` | Published |
| `axondb-search-backups-0.0.11` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.11` | Published |
| `axondb-search-backups-0.0.10` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.10` | Published |
| `axondb-search-backups-0.0.9` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.9` | Published |
| `axondb-search-backups-0.0.8` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.8` | Published |
| `axondb-search-backups-0.0.7` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.7` | Published |
| `axondb-search-backups-0.0.6` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.6` | Published |
| `axondb-search-backups-0.0.5` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.5` | Published |
| `axondb-search-backups-0.0.4` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.4` | Published |
| `axondb-search-backups-0.0.3` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.3` | Published |
| `axondb-search-backups-0.0.2` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.2` | Published |
| `axondb-search-backups-0.0.1` | `ghcr.io/axonops/axondb-search-backups:3.3.2-0.0.1` | Published |

## AxonOps Schema Registry

| Git Tag | Container Image | Date | Status |
|---------|-----------------|------|--------|
| — | — | — | No releases yet |

### Schema Registry Versioning

Schema Registry uses **multi-dimensional versioning** with two axes:
- **SR_VERSION**: Application version (e.g., `0.2.0`)
- **CONTAINER_VERSION**: Container version (semver, e.g., `0.0.1`)

Git tag format: `axonops-schema-registry-{SR_VERSION}-{CONTAINER_VERSION}` (e.g., `axonops-schema-registry-0.2.0-0.0.1`)

## K8ssandra

| Git Tag | Container Image | Date | Status |
|---------|-----------------|------|--------|
| `k8ssandra-1.4.2` | `ghcr.io/axonops/k8ssandra/cassandra:{cass}-v0.1.110-1.4.2` | 2026-02-13 | Published |
| `k8ssandra-1.4.1` | `ghcr.io/axonops/k8ssandra/cassandra:{cass}-v0.1.110-1.4.1` | 2026-02-03 | Published |
| `k8ssandra-1.4.0` | `ghcr.io/axonops/k8ssandra/cassandra:{cass}-v0.1.110-1.4.0` | 2026-01-30 | Published |
| `k8ssandra-1.3.1` | `ghcr.io/axonops/k8ssandra/cassandra:{cass}-v0.1.110-1.3.1` | 2026-01-27 | Published |
| `k8ssandra-1.3.0` | `ghcr.io/axonops/k8ssandra/cassandra:{cass}-v0.1.110-1.3.0` | 2026-01-22 | Published |
| `k8ssandra-1.2.0` | `ghcr.io/axonops/k8ssandra/cassandra:{cass}-v0.1.110-1.2.0` | 2026-01-09 | Published |
| `k8ssandra-1.1.0` | `ghcr.io/axonops/k8ssandra/cassandra:{cass}-v0.1.110-1.1.0` | 2026-01-05 | Published |

> **Note:** `{cass}` = Cassandra versions 5.0.1 through 5.0.6. Each release produces tags for all supported versions.

### Development Tags (K8ssandra)

| Git Tag | Notes |
|---------|-------|
| `dev-k8ssandra-1.4.1` | Development build |
| `dev-k8ssandra-1.4.0` | Development build |

## Strimzi

| Git Tag | Container Image | Date | Status |
|---------|-----------------|------|--------|
| `strimzi-0.1.7` | `ghcr.io/axonops/strimzi/kafka:{operator}-{kafka}-{agent}-0.1.7` | 2026-02-13 | Published |
| `strimzi-0.1.6` | `ghcr.io/axonops/strimzi/kafka:{operator}-{kafka}-{agent}-0.1.6` | 2026-02-13 | Published |
| `strimzi-0.1.5` | `ghcr.io/axonops/strimzi/kafka:{operator}-{kafka}-{agent}-0.1.5` | 2026-02-13 | Published |
| `strimzi-0.1.4` | `ghcr.io/axonops/strimzi/kafka:{operator}-{kafka}-{agent}-0.1.4` | 2026-02-12 | Published |
| `strimzi-0.1.3` | `ghcr.io/axonops/strimzi/kafka:{operator}-{kafka}-{agent}-0.1.3` | 2026-02-02 | Published |
| `strimzi-0.1.2` | `ghcr.io/axonops/strimzi/kafka:{operator}-{kafka}-{agent}-0.1.2` | 2026-02-02 | Published |
| `strimzi-0.1.0` | `ghcr.io/axonops/strimzi/kafka:{operator}-{kafka}-{agent}-0.1.0` | 2026-01-30 | Published |

> **Note:** Strimzi operator 0.50.0 supports Kafka versions 4.0.0, 4.0.1, 4.1.0, 4.1.1. Each release produces tags for all supported combinations.

### Development Tags (Strimzi)

| Git Tag | Notes |
|---------|-------|
| `dev-strimzi-0.1.3` | Development build |
| `dev-strimzi-0.1.2` | Development build |
| `dev-strimzi-0.1.1` | Development build |
| `dev-strimzi-0.1.0` | Development build |

## Helm Charts

| Git Tag | Charts | Date | Status |
|---------|--------|------|--------|
| `helm-0.0.18` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-02-10 | Published |
| `helm-0.0.17` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-22 | Published |
| `helm-0.0.16` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-21 | Published |
| `helm-0.0.15` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-21 | Published |
| `helm-0.0.14` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-21 | Published |
| `helm-0.0.13` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-20 | Published |
| `helm-0.0.12` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-20 | Published |
| `helm-0.0.11` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-18 | Published |
| `helm-0.0.10` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-16 | Published |
| `helm-0.0.9` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-16 | Published |
| `helm-0.0.8` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-14 | Published |
| `helm-0.0.7` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-14 | Published |
| `helm-0.0.6` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-12 | Published |
| `helm-0.0.5` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2026-01-09 | Published |
| `helm-0.0.4` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2025-12-29 | Published |
| `helm-0.0.3` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2025-12-29 | Published |
| `helm-0.0.2` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2025-12-17 | Published |
| `helm-0.0.1` | axonops, axondb-timeseries, axondb-search, axon-server, axon-dash | 2025-12-17 | Published |

## How to Create a New Release

### Time-Series
```bash
# 1. Create and push tag on main branch
git tag axondb-timeseries-X.Y.Z origin/main
git push origin axondb-timeseries-X.Y.Z

# 2. Trigger the workflow
gh workflow run "AxonDB Time-Series Publish Signed to GHCR" \
  --repo axonops/axonops-containers \
  -f main_git_tag=axondb-timeseries-X.Y.Z \
  -f container_version=X.Y.Z
```

### Search
```bash
# 1. Create and push tag on main branch
git tag axondb-search-X.Y.Z origin/main
git push origin axondb-search-X.Y.Z

# 2. Trigger the workflow
gh workflow run "AxonDB Search Publish Signed to GHCR" \
  --repo axonops/axonops-containers \
  -f main_git_tag=axondb-search-X.Y.Z \
  -f container_version=X.Y.Z
```

### Schema Registry
```bash
# 1. Create and push tag on main branch
git tag axonops-schema-registry-0.2.0-0.0.1 origin/main
git push origin axonops-schema-registry-0.2.0-0.0.1

# 2. Trigger the workflow
gh workflow run "AxonOps Schema Registry Publish Signed to GHCR" \
  --repo axonops/axonops-containers \
  -f main_git_tag=axonops-schema-registry-0.2.0-0.0.1 \
  -f sr_version=0.2.0 \
  -f container_version=0.0.1
```

### K8ssandra
```bash
# 1. Create and push tag on main branch
git tag k8ssandra-X.Y.Z origin/main
git push origin k8ssandra-X.Y.Z

# 2. Trigger the workflow
gh workflow run "K8ssandra Publish Signed to GHCR" \
  --repo axonops/axonops-containers \
  -f main_git_tag=k8ssandra-X.Y.Z \
  -f container_version=X.Y.Z
```

### Strimzi
```bash
# 1. Create and push tag on main branch
git tag strimzi-X.Y.Z origin/main
git push origin strimzi-X.Y.Z

# 2. Trigger the workflow
gh workflow run "Strimzi Publish Signed to GHCR" \
  --repo axonops/axonops-containers \
  -f main_git_tag=strimzi-X.Y.Z \
  -f container_version=X.Y.Z
```

## Notes

- Tags must exist on the `main` branch for production publish workflows
- Container versions must be unique (workflow validates this)
- Development builds use the `dev-` prefix and publish to development tags
- Legacy tags without the `axondb-` prefix are deprecated
