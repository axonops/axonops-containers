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

Do **not** copy the digest mapping into `k8ssandra/README.md`. It used to carry one, it
was pinned to an API version two releases behind, every digest in it was wrong, and
nothing in CI could tell. The README points at the variable instead.

What does need updating when a version is added or removed:

- The `build_matrix` section of [`versions.yaml`](../versions.yaml) - see
  [Where versions are declared](#where-versions-are-declared).
- The published version list and, if the policy changed, the support policy in
  `k8ssandra/README.md` and its French translation `k8ssandra/README.fr.md`. The
  `Docs Translations` workflow fails the PR if the English file changes without the
  translation.
- The `## [Unreleased]` section of `CHANGELOG.md`.
- The History table at the bottom of this file, when the API version changed.

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

## Where versions are declared

Two places, with one job each:

| Declaration | Lives in | Answers |
|-------------|----------|---------|
| Which Cassandra versions are built | `build_matrix` in [`versions.yaml`](../versions.yaml) | "Do we ship 5.0.8?" |
| Which base image digest each version uses | `K8SSANDRA_VERSIONS` repository variable | "What do we build 5.0.8 `FROM`?" |

Nothing else declares a version. Workflow matrices, the newest-version defaults, the
floating `latest` and `{line}-latest` tag conditions, the release notes and the nightly
scan list are all derived from `versions.yaml` by `scripts/build-matrix.sh`:

```bash
./scripts/build-matrix.sh versions          # JSON array, for fromJSON() in a matrix
./scripts/build-matrix.sh newest            # what `latest` resolves to
./scripts/build-matrix.sh newest-line       # what `{line}-latest` is named after
./scripts/build-matrix.sh space-separated   # for shell loops
./scripts/build-matrix.sh check --k8ssandra-versions "$(gh variable get K8SSANDRA_VERSIONS --repo axonops/axonops-containers)"
```

`check` is the gate. It fails if a published line lists no versions, if an unpublished
line gives no reason, if a version is listed under the wrong line or has no build
directory, or if a version has no `cass-management-api` base image. The publish,
build-and-test and cloud-install workflows run it before building anything, so a
mismatch costs seconds instead of a 15-minute build.

Repeating a version list in a workflow file is what this replaced, and it had already
gone wrong three ways: the production matrix built 5.0.1 and 5.0.2 while its
`ALL_VERSIONS` started at 5.0.3, the secondary test matrix stopped at 5.0.7 after
everything else moved to 5.0.8, and the cloud install test pinned 5.0.7 against a
development image that was never published for it.

## Workflow Behavior

The GitHub workflows automatically:
1. Read the build matrix from `versions.yaml`
2. Read the `K8SSANDRA_VERSIONS` variable
3. Parse the composite key to extract the k8ssandra API version
4. Use the SHA256 digest for supply chain security (digest-pinned base images)
5. Build containers with the correct base image

No workflow file changes are needed when adding a Cassandra version or updating a
k8ssandra API version - only `versions.yaml` and the `K8SSANDRA_VERSIONS` variable.

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

### A Cassandra version exists upstream but not in k8ssandra

Apache releases a Cassandra patch before k8ssandra builds a `cass-management-api` image
for it. These images are built `FROM` that base, so a Cassandra version cannot be added
to the matrix — nor to `K8SSANDRA_VERSIONS` — until the base image exists. Adding it
early makes every build job for that version fail with "No k8ssandra version found".

No version is in that state today: k8ssandra published a 5.0.9 base image at API
v0.1.125 and 5.0.9 is in the matrix. The newest supported line is 5.0.9.

`./scripts/build-matrix.sh check --k8ssandra-versions "$(gh variable get K8SSANDRA_VERSIONS --repo axonops/axonops-containers)"`
catches this before anything is built, and every publish workflow runs it first.

### k8ssandra hasn't released new images yet

Check Docker Hub for available tags:
```bash
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100" | \
  jq -r '.results[].name' | grep "5.0" | sort -V
```

## History

| Date | API Version | Container Version | Notes |
|------|-------------|-------------------|-------|
| 2026-08 | 0.1.125 | — | Bump from 0.1.124. Adds Cassandra 5.0.9, which k8ssandra published a base image for at this API version; 5.0.9 becomes the newest supported version and the floating tags resolve to it. Also carries 4.0.21 and 4.1.12 digests for the unpublished 4.x lines |
| 2026-06 | 0.1.120 | — | Security fix: bump all versions to newer UBI 9 base; resolves unignored CVEs in nightly scan. Added Cassandra 4.0.20, 4.1.11, 5.0.8 |
| 2025-01 | 0.1.113 | — | Bump to 0.1.113 |
| 2025-01 | 0.1.111 | 1.1.0 | Initial documented update |
| 2024-12 | 0.1.110 | 1.0.0 | Initial release |
