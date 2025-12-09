# K8ssandra Release Process

This document describes how to create and publish K8ssandra container releases for both development and production.

**Important:** All images are cryptographically signed with Sigstore Cosign using keyless signing. Use the `-signed` workflows for all new releases.

## Overview

The release process uses separate workflows for development and production:

**Development Workflow:**
1. **k8ssandra-build-and-test.yml** - Automatic testing on pushes/PRs to `development`
2. **k8ssandra-development-publish-signed.yml** - Manual publishing to development registry (Cosign signed)

**Production Workflow:**
1. **k8ssandra-build-and-test.yml** - Automatic testing on pushes/PRs to `main`
2. **k8ssandra-publish-signed.yml** - Manual publishing to production registry (Cosign signed)

This approach ensures:
- Testing happens on both development and main branches
- Development images available for testing before production
- Manual control over all publishing
- Production releases are immutable

## Development Release Workflow

Use this workflow to publish images to the development registry for testing.

### 1. Development and Testing

Code changes are tested automatically:

```bash
# Create feature branch from development
git checkout development
git pull origin development
git checkout -b feature/my-feature

# Make changes and push
git add .
git commit -m "Add my feature"
git push origin feature/my-feature

# Create PR to development - tests run automatically
# Merge when tests pass
```

The `k8ssandra-build-and-test.yml` workflow runs on:
- Push to `development` branch (when `k8ssandra/**` changes)
- Pull requests to `development` (when `k8ssandra/**` changes)

### 2. Publish Development Images (Optional)

To test images before promoting to production, publish to development registry:

```bash
# Tag on development branch
git checkout development
git pull origin development
git tag dev-1.0.0
git push origin dev-1.0.0

# Trigger development publish workflow (--ref development ensures correct branch)
gh workflow run k8ssandra-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=dev-1.0.0 \
  -f container_version=dev-1.0.0
```

**Images published to (with 3D versioning):**
- `ghcr.io/axonops/development/k8ssandra/cassandra:5.0.6-v0.1.110-dev-1.0.0`
- `ghcr.io/axonops/development/k8ssandra/cassandra:5.0.5-v0.1.110-dev-1.0.0`
- `ghcr.io/axonops/development/k8ssandra/cassandra:5.0.4-v0.1.110-dev-1.0.0`

**Testing development images:**
```bash
docker pull ghcr.io/axonops/development/k8ssandra/cassandra:5.0.6-v0.1.110-dev-1.0.0
# Run tests, validate functionality
```

**Note:** Development images can be overwritten (no version validation). No GitHub Releases are created.

### 3. Promote to Production

When development images are tested and validated, promote to main:

```bash
# Create PR from development to main
gh pr create --base main --head development --title "Release 1.0.0" --body "Promote tested changes to production"

# After PR approved and merged, continue to step 4
```

---

## Production Release Workflow

### 4. Create Git Tag on Main Branch

**IMPORTANT:** Tags must be created on the `main` branch only. The publish workflow validates this.

When ready to release, create a git tag:

```bash
# Ensure you're on main branch and up to date
git checkout main
git pull origin main

# Tag the release commit
git tag 1.0.0

# Push tag to remote
git push origin 1.0.0
```

**Tag naming:** Tags can be anything (e.g., `1.0.0`, `v1.0.0`, `k8ssandra-1.0.0`, `release-2024-12`). The tag is just a reference point for the workflow.

**Validation:** The publish workflow will verify the tag points to a commit on `main` branch. If you tag a commit from a feature branch, the workflow will fail.

### 5. Trigger Production Publish Workflow

#### Option A: Using GitHub UI

1. Go to **Actions** tab in GitHub
2. Select **K8ssandra Publish to GHCR** workflow
3. Click **Run workflow** button
4. Fill in inputs:
   - **main_git_tag**: The tag you created (e.g., `1.0.0`)
   - **container_version**: Container version (e.g., `1.0.0`)
5. Click **Run workflow**

#### Option B: Using GitHub CLI

```bash
# Install gh CLI if not already installed
# macOS: brew install gh
# Linux: https://github.com/cli/cli#installation

# Authenticate
gh auth login

# IMPORTANT: Ensure you're on main branch first
git checkout main
git pull origin main

# Trigger the signed workflow (--ref main ensures correct branch)
gh workflow run k8ssandra-publish-signed.yml \
  --ref main \
  -f main_git_tag=1.0.0 \
  -f container_version=1.0.0

# Monitor workflow progress
gh run watch
```

### 4. Workflow Execution

The signed publish workflow performs these steps:

1. **Validate** - Checks if `container_version` already exists in GHCR
   - Fails if any image tag `*-container_version` exists
   - Prevents accidental overwrites

2. **Checkout** - Checks out the specific `main_git_tag` commit
   - Not the current state of `main`
   - Ensures you're publishing exactly what was tagged

3. **Test** - Runs full test suite on the tagged code
   - Management API tests
   - CQL operations with cqlai
   - AxonOps agent verification
   - Security scanning (Trivy)

4. **Build** - Builds multi-arch images for all Cassandra versions
   - Matrix: `[5.0.4, 5.0.5, 5.0.6]`
   - Platforms: `linux/amd64`, `linux/arm64`

5. **Publish** - Pushes images to GHCR
   - Multi-dimensional tags: immutable, patch-latest, minor-latest, global-latest
   - Registry: `ghcr.io/axonops/k8ssandra/cassandra`

6. **Sign** - Cryptographically sign images with Cosign
   - Keyless signing using GitHub OIDC token
   - Signatures pushed to GHCR
   - Transparency log entries created

7. **Re-push Tags** - Update tag references for proper GHCR UI display

8. **Create Release** - Creates GitHub Release
   - Name: `k8ssandra-signed-<container_version>` (e.g., `k8ssandra-signed-1.0.4`)
   - Includes signature verification instructions
   - Lists all published image tags

### 5. Verify Release

Check that images were published:

```bash
# Check GHCR for published images
gh api /orgs/axonops/packages/container/k8ssandra%2Fcassandra/versions | \
  jq '.[] | select(.metadata.container.tags[] | contains("1.0.0"))'

# Pull and test an image
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
docker run -d \
  -e AXON_AGENT_KEY=your-key \
  -e AXON_AGENT_ORG=your-org \
  -e AXON_AGENT_HOST=agents.axonops.cloud \
  -p 9042:9042 \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

Check GitHub Release:

```bash
# List releases
gh release list

# View specific release
gh release view k8ssandra-signed-1.0.0
```

**Verify Signatures:**

All production images are signed. Verify before deployment:

```bash
# Verify signature
cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Check signature exists
cosign tree ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

See [Security Documentation](../README.md#security) for more on signature verification and digest-based deployment.

## Inputs Reference

### main_git_tag
**Required:** Yes
**Type:** String
**Description:** Git tag on main branch to checkout and build from

The workflow validates this tag is on main branch, then checks out this exact tag. This ensures you're publishing a frozen snapshot of code from main, not from a feature branch.

**Examples:**
- `1.0.0`
- `v1.0.0`
- `k8ssandra-1.0.0`
- `release-2024-12-04`

### container_version
**Required:** Yes
**Type:** String
**Description:** Container version for published images in GHCR

This becomes the container version for all published images:
- `5.0.6-<container_version>`
- `5.0.5-<container_version>`
- `5.0.4-<container_version>`

**Format:** Semantic versioning recommended (e.g., `1.0.0`, `1.2.3`, `2.0.0-beta`)

**Validation:** Workflow fails if any image with this version already exists in GHCR.

## Published Artifacts

Each release publishes:

### Container Images (GHCR)
- `ghcr.io/axonops/k8ssandra/cassandra:5.0.6-<container_version>`
- `ghcr.io/axonops/k8ssandra/cassandra:5.0.5-<container_version>`
- `ghcr.io/axonops/k8ssandra/cassandra:5.0.4-<container_version>`

All images are multi-arch: `linux/amd64`, `linux/arm64`

### GitHub Release
- Name: `k8ssandra-<container_version>`
- Tag: `<main_git_tag>`
- Body: Lists all published image tags

## Troubleshooting

### Version Already Exists

**Error:** `Container version X.Y.Z already exists in GHCR`

**Solution:**
- Use a different `container_version` (e.g., increment to next version)
- Or delete the existing release and images from GHCR if this was a mistake

### Tests Fail During Publish

**Error:** Tests fail in the publish workflow

**Solution:**
- The git tag has code that doesn't pass tests
- Fix the issues on `main` branch
- Create a new git tag pointing to the fixed commit
- Trigger publish workflow with the new tag

### Workflow Cannot Find Tag

**Error:** `fatal: reference is not a tree: <tag>`

**Solution:**
- Ensure you pushed the tag: `git push origin <tag>`
- Check tag exists: `git tag -l`
- Tag must exist in remote repository

### Tag Not on Main Branch

**Error:** `Tag X.Y.Z is not on main branch`

**Solution:**
- Tags must point to commits on `main` branch
- Merge your feature branch to main first
- Then create the tag on main:
  ```bash
  git checkout main
  git pull origin main
  git tag 1.0.0
  git push origin 1.0.0
  ```

### Image Push Fails

**Error:** Failed to push to GHCR

**Solution:**
- Check GitHub token permissions (should be automatic in Actions)
- Verify GHCR registry is accessible
- Re-run the workflow (images may have partially published)

## Re-releasing

If you need to re-publish the same version (e.g., image push failed):

1. Delete the existing GitHub Release: `gh release delete k8ssandra-1.0.0`
2. Delete images from GHCR (via GitHub Packages UI)
3. Re-run the publish workflow with the same inputs

## Versioning Strategy

### Semantic Versioning

Recommended format: `MAJOR.MINOR.PATCH`

- **MAJOR** - Breaking changes, incompatible API changes
- **MINOR** - New features, backwards-compatible
- **PATCH** - Bug fixes, backwards-compatible

### Examples

- `1.0.0` - Initial stable release
- `1.1.0` - New feature added (cqlai version bump)
- `1.1.1` - Bug fix (AxonOps agent configuration fix)
- `2.0.0` - Breaking change (Cassandra 6.0 support)

### Pre-release Versions

Use suffixes for pre-releases:
- `1.0.0-alpha` - Alpha release
- `1.0.0-beta` - Beta release
- `1.0.0-rc1` - Release candidate

## Checklist

Before publishing:

- [ ] All tests passing on `main` branch
- [ ] CHANGELOG updated (if applicable)
- [ ] Documentation updated
- [ ] Git tag created and pushed
- [ ] `container_version` doesn't exist in GHCR
- [ ] Ready to make release public

During publishing:

- [ ] Workflow validation passed
- [ ] All tests passed on tagged code
- [ ] All images built successfully
- [ ] All images pushed to GHCR
- [ ] GitHub Release created

After publishing:

- [ ] Verify images in GHCR
- [ ] Test pulling and running images
- [ ] Announce release (if applicable)
- [ ] Update documentation with new version numbers
