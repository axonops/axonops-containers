# Updating K8ssandra Management API Versions

This document describes the process for updating the k8ssandra Management API version used in our container builds.

## Overview

When k8ssandra releases a new Management API version (e.g., v0.1.111), we need to:
1. Get the new SHA256 digests from Docker Hub
2. Update the `K8SSANDRA_VERSIONS` GitHub repository variable
3. Update documentation
4. Test and release new container images

## Step-by-Step Process

### 1. Get SHA256 Digests from Docker Hub

Use the Docker Hub API to retrieve the SHA256 digests for all supported Cassandra versions:

```bash
# Get all digests for a specific k8ssandra API version
curl -s "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=5.0" | \
  jq -r '.results[] | select(.name | test("^5\\.0\\.[0-9]+-ubi-v0\\.1\\.111$")) | "\(.name): \(.digest)"'
```

Or for individual versions:

```bash
# Check a specific Cassandra version
VERSION="5.0.6"
API_VERSION="0.1.111"
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${VERSION}-ubi-v${API_VERSION}" | \
  jq -r '.results[] | select(.name == "'"${VERSION}-ubi-v${API_VERSION}"'") | "Digest: \(.digest)"'
```

### 2. Update K8SSANDRA_VERSIONS GitHub Variable

The `K8SSANDRA_VERSIONS` repository variable is a JSON object mapping composite keys to SHA256 digests:

**Composite Key Format:** `{CASSANDRA_VERSION}+{K8SSANDRA_API_VERSION}`

**Example:** `5.0.6+0.1.111`

Update the variable via GitHub CLI:

```bash
gh variable set K8SSANDRA_VERSIONS --body '{
  "5.0.1+0.1.111": "sha256:5cc48bddcb3be29f5c1492408e106417d1455f1182a45f191e99529226135240",
  "5.0.2+0.1.111": "sha256:17a66c0514e290b3428589ec09cff08d449ca888dd21801baf4896168de78432",
  "5.0.3+0.1.111": "sha256:359d2a448aab4d64e9e67978f1496b1aa502f03208866bb6f3a0a28d5426e79c",
  "5.0.4+0.1.111": "sha256:e7cbac800ec3b8f37d7e7952f438544fc2c549a40c072e9074cfdea115925149",
  "5.0.5+0.1.111": "sha256:b0ced4894cc5e9972d00b45d36def9bd7ac87c6a88934344b676849d8672f7ed",
  "5.0.6+0.1.111": "sha256:bc5708b8ac40c2ad027961a2b1e1b70c826468b8b727c30859718ffc24d7ae04"
}'
```

Or update via GitHub UI:
1. Go to Repository Settings > Secrets and variables > Actions > Variables
2. Edit `K8SSANDRA_VERSIONS`
3. Replace the JSON content with new digests

### 3. Update Documentation

Update the digest mapping in `k8ssandra/README.md`:

```markdown
Digest mapping for 5.0.x versions (k8ssandra API v0.1.111):
- 5.0.1: `sha256:5cc48bddcb3be29f5c1492408e106417d1455f1182a45f191e99529226135240`
- 5.0.2: `sha256:17a66c0514e290b3428589ec09cff08d449ca888dd21801baf4896168de78432`
- 5.0.3: `sha256:359d2a448aab4d64e9e67978f1496b1aa502f03208866bb6f3a0a28d5426e79c`
- 5.0.4: `sha256:e7cbac800ec3b8f37d7e7952f438544fc2c549a40c072e9074cfdea115925149`
- 5.0.5: `sha256:b0ced4894cc5e9972d00b45d36def9bd7ac87c6a88934344b676849d8672f7ed`
- 5.0.6: `sha256:bc5708b8ac40c2ad027961a2b1e1b70c826468b8b727c30859718ffc24d7ae04`
```

### 4. Create Feature Branch and PR

```bash
# Create feature branch from development
git checkout development
git pull origin development
git checkout -b feature/bump-k8ssandra-0.1.111

# Make changes to README.md
# ... edit files ...

# Commit and push
git add k8ssandra/README.md k8ssandra/UPDATING_K8SSANDRA_VERSIONS.md
git commit -m "Update k8ssandra Management API to v0.1.111"
git push origin feature/bump-k8ssandra-0.1.111

# Create PR to development
gh pr create --base development --title "Update k8ssandra Management API to v0.1.111" \
  --body "Updates k8ssandra base images to Management API v0.1.111

## Changes
- Updated digest mapping in README.md
- Added UPDATING_K8SSANDRA_VERSIONS.md documentation

## Testing
The build-and-test workflow will automatically run on this PR to validate the new digests."
```

### 5. Test with Development Publish

After merging to development:

```bash
# Create a development tag
git checkout development
git pull origin development
git tag dev-1.1.0
git push origin dev-1.1.0

# Trigger development publish workflow
gh workflow run k8ssandra-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=dev-1.1.0 \
  -f container_version=dev-1.1.0

# Monitor the workflow
gh run watch
```

### 6. Production Release

After development testing passes:

```bash
# Create PR from development to main
gh pr create --base main --head development \
  --title "Release k8ssandra v0.1.111 containers" \
  --body "Promote k8ssandra v0.1.111 containers to production"

# After PR merged, create production tag on main
git checkout main
git pull origin main
git tag k8ssandra-1.1.0
git push origin k8ssandra-1.1.0

# Trigger production publish workflow
gh workflow run k8ssandra-publish-signed.yml \
  --ref main \
  -f main_git_tag=k8ssandra-1.1.0 \
  -f container_version=1.1.0

# Monitor the workflow
gh run watch
```

## Versioning Strategy

When updating the k8ssandra Management API version:

- **MINOR version bump** (e.g., 1.0.0 → 1.1.0) - Component update (k8ssandra API, cqlai, AxonOps agent)
- **PATCH version bump** (e.g., 1.1.0 → 1.1.1) - Bug fixes, security patches

## Workflow Behavior

The GitHub workflows automatically:
1. Read the `K8SSANDRA_VERSIONS` variable
2. Parse the composite key to extract the k8ssandra API version
3. Use the SHA256 digest for supply chain security (digest-pinned base images)
4. Build containers with the correct base image

No workflow file changes are needed when updating k8ssandra versions - only the `K8SSANDRA_VERSIONS` variable needs updating.

## Troubleshooting

### Workflow fails with "No k8ssandra version found"

The composite key in `K8SSANDRA_VERSIONS` doesn't match the Cassandra version being built.

**Check:**
```bash
gh variable get K8SSANDRA_VERSIONS | jq 'keys'
```

Ensure keys follow the format: `{CASSANDRA_VERSION}+{K8SSANDRA_API_VERSION}`

### Digest mismatch errors

The digest in `K8SSANDRA_VERSIONS` doesn't match what Docker Hub has.

**Verify:**
```bash
VERSION="5.0.6"
API_VERSION="0.1.111"
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?name=${VERSION}-ubi-v${API_VERSION}" | \
  jq -r '.results[] | "\(.name): \(.digest)"'
```

### k8ssandra hasn't released new images yet

Check Docker Hub for available tags:
```bash
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100" | \
  jq -r '.results[].name' | grep "5.0" | sort -V
```

## History

| Date | API Version | Container Version | Notes |
|------|-------------|-------------------|-------|
| 2025-01 | 0.1.111 | 1.1.0 | Initial documented update |
| 2024-12 | 0.1.110 | 1.0.0 | Initial release |
