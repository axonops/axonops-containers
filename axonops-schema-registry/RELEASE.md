# AxonOps Schema Registry Release Process

This document describes how to create and publish AxonOps Schema Registry container releases for both development and production.

**Important:** All images are cryptographically signed with Sigstore Cosign using keyless signing (OIDC). Use the `-signed` workflows for all releases.

## Table of Contents

- [Overview](#overview)
- [Versioning Strategy](#versioning-strategy)
  - [Multi-Dimensional Versioning](#multi-dimensional-versioning)
  - [Two Release Scenarios](#two-release-scenarios)
  - [When to Increment](#when-to-increment)
  - [Pre-release Versions](#pre-release-versions)
- [Development Release Workflow](#development-release-workflow)
  - [1. Development and Testing](#1-development-and-testing)
  - [2. Publish Development Images (Optional)](#2-publish-development-images-optional)
  - [3. Promote to Production](#3-promote-to-production)
- [Production Release Workflow](#production-release-workflow)
  - [4. Create Git Tag on Main Branch](#4-create-git-tag-on-main-branch)
  - [5. Trigger Production Publish Workflow](#5-trigger-production-publish-workflow)
  - [6. Workflow Execution](#6-workflow-execution)
  - [7. Verify Release](#7-verify-release)
- [Inputs Reference](#inputs-reference)
  - [main_git_tag](#main_git_tag)
  - [sr_version](#sr_version)
  - [container_version](#container_version)
- [Published Artifacts](#published-artifacts)
  - [Container Images (GHCR)](#container-images-ghcr)
  - [GitHub Release](#github-release)
  - [Cosign Signatures](#cosign-signatures)
- [Release Scenarios](#release-scenarios)
  - [Scenario 1: New SR Application Version](#scenario-1-new-sr-application-version)
  - [Scenario 2: Container-Only Bump](#scenario-2-container-only-bump)
- [Troubleshooting](#troubleshooting)
  - [Version Already Exists](#version-already-exists)
  - [Tests Fail During Publish](#tests-fail-during-publish)
  - [Workflow Cannot Find Tag](#workflow-cannot-find-tag)
  - [Tag Not on Main Branch](#tag-not-on-main-branch)
  - [Image Push Fails](#image-push-fails)
  - [Signature Verification Fails](#signature-verification-fails)
- [Re-releasing](#re-releasing)
- [Checklist](#checklist)
- [Release Cadence](#release-cadence)

## Overview

The release process uses separate workflows for development and production:

**Development Workflow:**
1. **axonops-schema-registry-build-and-test.yml** - Automatic testing on pushes/PRs to `development`
2. **axonops-schema-registry-development-publish-signed.yml** - Manual publishing to development registry (Cosign signed)

**Production Workflow:**
1. **axonops-schema-registry-build-and-test.yml** - Automatic testing on pushes/PRs to `main`
2. **axonops-schema-registry-publish-signed.yml** - Manual publishing to production registry (Cosign signed)

This approach ensures:
- Testing happens on both development and main branches
- Development images available for testing before production
- Manual control over all publishing
- Production releases are immutable and cryptographically signed

## Versioning Strategy

### Multi-Dimensional Versioning

AxonOps Schema Registry uses **two-dimensional versioning** with independent axes:

| Dimension | Description | Example | Controlled By |
|-----------|-------------|---------|---------------|
| **SR_VERSION** | Upstream Schema Registry application version | `0.2.0` | Upstream releases |
| **CONTAINER_VERSION** | Container version (semver) | `0.0.1`, `0.0.2`, `0.1.0` | This repository |

**Combined format:** `{SR_VERSION}-{CONTAINER_VERSION}` (e.g., `0.2.0-0.0.1`)

**Git tag format:** `axonops-schema-registry-{SR_VERSION}-{CONTAINER_VERSION}` (e.g., `axonops-schema-registry-0.2.0-0.0.1`)

### Two Release Scenarios

There are exactly **two** scenarios for releasing:

1. **New SR application version** (e.g., 0.2.0 -> 0.3.0): Container version **resets to 0.0.1**
2. **Container-only bump** (e.g., 0.2.0-0.0.1 -> 0.2.0-0.0.2): Same SR version, **increment container version**

See [Release Scenarios](#release-scenarios) for detailed step-by-step instructions for each.

### When to Increment

**New SR Version (container version resets to 0.0.1):**
- Upstream releases a new Schema Registry version
- Example: `0.2.0-0.0.1` -> `0.3.0-0.0.1`

**Container-Only Bump (increment container version):**
- Base image security patches (UBI 9 updates)
- Dockerfile improvements (optimizations, best practices)
- Entrypoint or healthcheck script fixes
- CI/CD pipeline improvements that affect the built image
- Example: `0.2.0-0.0.1` -> `0.2.0-0.0.2`

### Pre-release Versions

Use suffixes for pre-releases:
- `0.2.0-0.0.1-alpha` - Alpha release
- `0.2.0-0.0.1-beta` - Beta release
- `0.2.0-0.0.1-rc.1` - Release candidate

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

The `axonops-schema-registry-build-and-test.yml` workflow runs on:
- Push to `development` branch (when `axonops-schema-registry/**` changes)
- Pull requests to `development` (when `axonops-schema-registry/**` changes)

### 2. Publish Development Images (Optional)

To test images before promoting to production, publish to development registry:

```bash
# Tag on development branch
git checkout development
git pull origin development
git tag vdev-axonops-schema-registry-0.2.0-0.0.1
git push origin vdev-axonops-schema-registry-0.2.0-0.0.1

# Trigger development publish workflow
gh workflow run axonops-schema-registry-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=vdev-axonops-schema-registry-0.2.0-0.0.1 \
  -f sr_version=0.2.0 \
  -f container_version=0.0.1
```

**Images published to:**
- `ghcr.io/axonops/development/axonops-schema-registry:0.2.0-0.0.1`
- `ghcr.io/axonops/development/axonops-schema-registry:0.2.0`
- `ghcr.io/axonops/development/axonops-schema-registry:latest`

**Testing development images:**
```bash
docker pull ghcr.io/axonops/development/axonops-schema-registry:0.2.0-0.0.1
docker run -d --name test -p 8081:8081 ghcr.io/axonops/development/axonops-schema-registry:0.2.0-0.0.1
curl -s http://localhost:8081/
```

### 3. Promote to Production

When development images are tested and validated, promote to main:

```bash
# Create PR from development to main
gh pr create --base main --head development \
  --title "Release axonops-schema-registry 0.2.0-0.0.1" \
  --body "Promote tested changes to production"

# After PR approved and merged, continue to production release (step 4)
```

---

## Production Release Workflow

### 4. Create Git Tag on Main Branch

**IMPORTANT:** Tags must be created on the `main` branch only. The publish workflow validates this.

```bash
# Ensure you're on main branch and up to date
git checkout main
git pull origin main

# Tag the release commit
git tag axonops-schema-registry-0.2.0-0.0.1

# Push tag to remote
git push origin axonops-schema-registry-0.2.0-0.0.1
```

**Tag naming:** Required format: `axonops-schema-registry-{SR_VERSION}-{CONTAINER_VERSION}` (e.g., `axonops-schema-registry-0.2.0-0.0.1`)

### 5. Trigger Production Publish Workflow

#### Option A: Using GitHub UI

1. Go to **Actions** tab in GitHub
2. Select **AxonOps Schema Registry Publish Signed to GHCR** workflow
3. Click **Run workflow** button
4. Fill in inputs:
   - **main_git_tag**: The tag you created (e.g., `axonops-schema-registry-0.2.0-0.0.1`)
   - **sr_version**: Schema Registry version (e.g., `0.2.0`)
   - **container_version**: Container version (e.g., `0.0.1`)
5. Click **Run workflow**

#### Option B: Using GitHub CLI

```bash
# Ensure you're on main branch
git checkout main
git pull origin main

# Trigger the signed workflow
gh workflow run axonops-schema-registry-publish-signed.yml \
  --ref main \
  -f main_git_tag=axonops-schema-registry-0.2.0-0.0.1 \
  -f sr_version=0.2.0 \
  -f container_version=0.0.1

# Monitor workflow progress
gh run watch
```

### 6. Workflow Execution

The production workflow performs these steps:

1. **Validate** - Checks if version already exists in GHCR
   - Prevents accidental overwrites
   - Validates tag is on main branch

2. **Test** - Runs full test suite on the tagged code
   - Container build verification
   - Startup banner verification (production mode)
   - Version verification
   - Healthcheck tests
   - API tests
   - Security scanning (Trivy)

3. **Create Release** - Creates GitHub Release
   - Name: `axonops-schema-registry-{SR_VERSION}-{CONTAINER_VERSION}`
   - Tag: `<main_git_tag>`
   - Body: Image details and Cosign verification instructions

4. **Build** - Builds multi-arch images
   - Platforms: `linux/amd64`, `linux/arm64`
   - Full metadata in build-info.txt
   - Production release flag set to true

5. **Sign** - Cryptographically sign images with Cosign
   - Keyless signing using GitHub OIDC token
   - Signatures pushed to GHCR

6. **Publish** - Pushes images to GHCR
   - Immutable tag: `0.2.0-0.0.1`
   - Floating tag: `0.2.0`
   - Global latest: `latest`
   - Registry: `ghcr.io/axonops/axonops-schema-registry`

7. **Verify** - Post-publish verification
   - Pulls image from GHCR
   - Verifies Cosign signature
   - Starts container and runs smoke tests

### 7. Verify Release

```bash
# Check GHCR for published images
gh api /orgs/axonops/packages/container/axonops-schema-registry/versions | \
  jq '.[] | select(.metadata.container.tags[] | contains("0.2.0-0.0.1"))'

# Pull and test
docker pull ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
docker run -d --name sr-test -p 8081:8081 ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
curl -s http://localhost:8081/
docker stop sr-test && docker rm sr-test
```

**Verify Signatures:**

```bash
cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
```

## Inputs Reference

### main_git_tag
**Required:** Yes
**Type:** String
**Description:** Git tag on main branch to checkout and build from

The workflow validates this tag is on main branch, then checks out this exact tag.

**Examples:**
- `axonops-schema-registry-0.2.0-0.0.1` (recommended)

### sr_version
**Required:** Yes
**Type:** String
**Default:** `0.2.0`
**Description:** Schema Registry application version

This becomes the SR version component in the image tag:
- `{sr_version}-{container_version}` (e.g., `0.2.0-0.0.1`)

### container_version
**Required:** Yes
**Type:** String
**Default:** `0.0.1`
**Description:** Container version (semver)

Resets to `0.0.1` when `sr_version` changes. Increment for container-only bumps.

## Published Artifacts

Each release publishes:

### Container Images (GHCR)

**Production registry:**
- `ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1` (immutable)
- `ghcr.io/axonops/axonops-schema-registry:0.2.0` (floating)
- `ghcr.io/axonops/axonops-schema-registry:latest` (floating)

**Development registry:**
- `ghcr.io/axonops/development/axonops-schema-registry:0.2.0-0.0.1`
- `ghcr.io/axonops/development/axonops-schema-registry:0.2.0`
- `ghcr.io/axonops/development/axonops-schema-registry:latest`

All images are multi-arch: `linux/amd64`, `linux/arm64`

### GitHub Release
- Name: `axonops-schema-registry-{SR_VERSION}-{CONTAINER_VERSION}`
- Tag: `<main_git_tag>`
- Body: Lists image tags, Cosign verification instructions

### Cosign Signatures
- Keyless signatures using GitHub OIDC
- Transparency log entries in Rekor
- Attestations pushed to GHCR

## Release Scenarios

### Scenario 1: New SR Application Version

**When:** Upstream releases a new Schema Registry version (e.g., 0.2.0 -> 0.3.0)

**Key rule:** Container version **resets to 0.0.1**.

The Dockerfile is version-agnostic — it downloads the correct SR version at build time via the `SR_VERSION` build argument. No directory changes are needed for new SR versions.

**Steps:**

1. **Update default `sr_version` in workflows** (optional — only if you want to change the default):
   - Update `ARG SR_VERSION=` in `axonops-schema-registry/Dockerfile`
   - Update default `sr_version` input values in workflow files

2. **Verify the new version builds correctly:**
   ```bash
   cd axonops-schema-registry
   docker build --build-arg SR_VERSION=0.3.0 -t axonops-schema-registry:test .
   ```

3. **Merge to main and tag:**
   ```bash
   git tag axonops-schema-registry-0.3.0-0.0.1
   git push origin axonops-schema-registry-0.3.0-0.0.1
   ```

6. **Publish:**
   ```bash
   gh workflow run axonops-schema-registry-publish-signed.yml \
     --ref main \
     -f main_git_tag=axonops-schema-registry-0.3.0-0.0.1 \
     -f sr_version=0.3.0 \
     -f container_version=0.0.1
   ```

**Result:** Tags `0.3.0-0.0.1`, `0.3.0`, `latest` published.

### Scenario 2: Container-Only Bump

**When:** Container improvements without SR version change (base image updates, script fixes, Dockerfile optimization).

**Key rule:** Same SR version, **increment container version**.

**Steps:**

1. **Make changes** (e.g., update base image digest, fix entrypoint script)

2. **Merge to main and tag with incremented build:**
   ```bash
   git tag axonops-schema-registry-0.2.0-0.0.2
   git push origin axonops-schema-registry-0.2.0-0.0.2
   ```

3. **Publish:**
   ```bash
   gh workflow run axonops-schema-registry-publish-signed.yml \
     --ref main \
     -f main_git_tag=axonops-schema-registry-0.2.0-0.0.2 \
     -f sr_version=0.2.0 \
     -f container_version=0.0.2
   ```

**Result:** Tags `0.2.0-0.0.2`, `0.2.0` (now points to container version 0.0.2), `latest` published. Tag `0.2.0-0.0.1` remains unchanged.

## Troubleshooting

### Version Already Exists

**Error:** `Container version already exists in GHCR`

**Solution:**
- Use a different version (increment container version)
- Or delete the existing release and images from GHCR if this was a mistake

### Tests Fail During Publish

**Error:** Tests fail in the publish workflow

**Solution:**
- Fix the issues on `main` branch
- Create a new git tag pointing to the fixed commit
- Trigger publish workflow with the new tag

### Workflow Cannot Find Tag

**Error:** `fatal: reference is not a tree: <tag>`

**Solution:**
- Ensure you pushed the tag: `git push origin <tag>`
- Check tag exists: `git tag -l`

### Tag Not on Main Branch

**Error:** `Tag is not on main branch`

**Solution:**
- Merge your feature branch to main first
- Then create the tag on main

### Image Push Fails

**Error:** Failed to push to GHCR

**Solution:**
- Check GitHub token permissions
- Verify GHCR registry is accessible
- Re-run the workflow

### Signature Verification Fails

**Error:** Cosign verification fails after publish

**Solution:**
```bash
cosign tree ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1

cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1 \
  --verbose
```

## Re-releasing

If you need to re-publish the same version (e.g., image push failed):

1. Delete the existing GitHub Release: `gh release delete axonops-schema-registry-0.2.0-0.0.1`
2. Delete images from GHCR (via GitHub Packages UI)
3. Re-run the publish workflow with the same inputs

**Note:** Only do this for failed releases. Never overwrite successfully published releases.

## Checklist

Before publishing:

- [ ] All tests passing on `main` branch
- [ ] Documentation updated (README.md, DEVELOPMENT.md)
- [ ] Git tag created and pushed (format: `axonops-schema-registry-{SR_VERSION}-{CONTAINER_VERSION}`)
- [ ] Version doesn't exist in GHCR
- [ ] Correct scenario identified (new SR version vs container-only bump)
- [ ] Container version is correct (reset to 0.0.1 for new SR version, incremented for container bump)

During publishing:

- [ ] Workflow validation passed
- [ ] All tests passed on tagged code
- [ ] Images built successfully (multi-arch)
- [ ] Images pushed to GHCR
- [ ] Images signed with Cosign
- [ ] GitHub Release created
- [ ] Post-publish verification passed

After publishing:

- [ ] Verify images in GHCR
- [ ] Test pulling and running images
- [ ] Verify Cosign signatures
- [ ] Test healthcheck probes
- [ ] Update TAG_CHANGELOG.md
- [ ] Announce release (if applicable)

## Release Cadence

**Recommended Release Schedule:**

- **Container bumps:** As needed for security patches and container improvements
- **New SR versions:** When upstream releases new Schema Registry versions

**Security Updates:**
- Base image (UBI9) updates: Publish as container bump (e.g., `0.2.0-0.0.1` -> `0.2.0-0.0.2`)
- Schema Registry security releases: Publish as new SR version

---

For development workflow and testing, see [DEVELOPMENT.md](./DEVELOPMENT.md).

For general usage and features, see [README.md](./README.md).
