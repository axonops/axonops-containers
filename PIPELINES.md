# How to Trigger Publish Pipelines

All pipelines are triggered via `gh workflow run`. You must create and push a git tag first, then trigger the workflow.

**Important:** Since the default branch is `development`, you must pass `--ref main` for production pipelines and `--ref development` for development pipelines. Otherwise the workflow file will be read from the wrong branch.

## Production Pipelines

### AxonDB Time-Series

```bash
git tag axondb-timeseries-1.4.0 origin/main
git push origin axondb-timeseries-1.4.0

gh workflow run "AxonDB Time-Series Publish Signed to GHCR" \
  --ref main \
  -f main_git_tag=axondb-timeseries-1.4.0 \
  -f container_version=1.4.0
```

### AxonDB Search

```bash
git tag axondb-search-1.6.0 origin/main
git push origin axondb-search-1.6.0

gh workflow run "AxonDB Search Publish Signed to GHCR" \
  --ref main \
  -f main_git_tag=axondb-search-1.6.0 \
  -f container_version=1.6.0
```

### AxonDB Search Backups

```bash
git tag axondb-search-backups-0.0.27 origin/main
git push origin axondb-search-backups-0.0.27

gh workflow run "AxonDB Search Backups Publish Signed to GHCR" \
  --ref main \
  -f main_git_tag=axondb-search-backups-0.0.27 \
  -f container_version=0.0.27
```

### AxonDB Time-Series Backups

```bash
git tag axondb-timeseries-backups-1.0.0 origin/main
git push origin axondb-timeseries-backups-1.0.0

gh workflow run "AxonDB Time-Series Backups Publish Signed to GHCR" \
  --ref main \
  -f main_git_tag=axondb-timeseries-backups-1.0.0 \
  -f container_version=1.0.0
```

### K8ssandra

```bash
git tag k8ssandra-1.5.0 origin/main
git push origin k8ssandra-1.5.0

gh workflow run "K8ssandra Publish Signed to GHCR" \
  --ref main \
  -f main_git_tag=k8ssandra-1.5.0 \
  -f container_version=1.5.0
```

### Strimzi

```bash
git tag strimzi-0.2.0 origin/main
git push origin strimzi-0.2.0

# Build all operator versions (default)
gh workflow run "Strimzi Publish Signed to GHCR" \
  --ref main \
  -f main_git_tag=strimzi-0.2.0

# Or build a specific operator version only
gh workflow run "Strimzi Publish Signed to GHCR" \
  --ref main \
  -f main_git_tag=strimzi-0.2.0 \
  -f operator_version=0.50.0
```

### Helm Charts

Helm releases are triggered automatically by pushing a tag. No `workflow_dispatch` needed.

```bash
git tag helm-0.0.19 origin/main
git push origin helm-0.0.19
```

To release specific charts only:

```bash
gh workflow run "Helm Charts Release" \
  --ref main \
  -f charts_to_release=axondb-timeseries,axondb-search
```

## Development Pipelines

### AxonDB Time-Series (Dev)

```bash
gh workflow run "AxonDB Time-Series Development Publish Signed to GHCR" \
  --ref development \
  -f dev_git_tag=development \
  -f container_version=dev-1.4.0
```

### AxonDB Search (Dev)

```bash
gh workflow run "AxonDB Search Development Publish Signed to GHCR" \
  --ref development \
  -f dev_git_tag=development \
  -f container_version=dev-1.6.0
```

### AxonDB Search Backups (Dev)

```bash
gh workflow run "AxonDB Search Backups Development Publish Signed to GHCR" \
  --ref development \
  -f dev_git_tag=development \
  -f container_version=dev-0.0.27
```

### AxonDB Time-Series Backups (Dev)

```bash
gh workflow run "AxonDB Time-Series Backups Development Publish Signed to GHCR" \
  --ref development \
  -f dev_git_tag=development \
  -f container_version=dev-1.0.0
```

### K8ssandra (Dev)

```bash
git tag dev-k8ssandra-1.5.0 origin/development
git push origin dev-k8ssandra-1.5.0

gh workflow run "K8ssandra Development Publish Signed to GHCR" \
  --ref development \
  -f dev_git_tag=dev-k8ssandra-1.5.0 \
  -f container_version=dev-1.5.0
```

### Strimzi (Dev)

```bash
git tag dev-strimzi-0.2.0 origin/development
git push origin dev-strimzi-0.2.0

gh workflow run "Strimzi Development Publish Signed to GHCR" \
  --ref development \
  -f dev_git_tag=dev-strimzi-0.2.0 \
  -f operator_version=0.50.0
```
