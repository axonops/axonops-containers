# Development Guidelines

This document outlines conventions and best practices for maintaining this repository.

## Repository Structure

```
axonops-cassandra-containers/
├── .github/workflows/       # GitHub Actions workflows (top-level only)
├── <component>/             # Component-specific directories (k8ssandra, kafka, etc.)
│   ├── <version>/          # Version-specific subdirectories (e.g., 5.0, 4.1)
│   │   ├── Dockerfile      # Container build definition
│   │   └── *.sh            # Component-specific scripts
│   ├── examples/           # Deployment examples for this component
│   ├── scripts/            # Component-specific utility scripts
│   └── README.md           # Component-specific documentation
├── DEVELOPMENT.md          # This file
├── README.md               # Repository overview
└── LICENSE                 # Apache 2.0 license
```

## Container Image Conventions

### Base Images

**Supply Chain Security - CRITICAL:**
- **ALWAYS** pin base images by digest (@sha256:...), NEVER by tag
- Tags are mutable and can be replaced maliciously (supply chain attack)
- Digests are immutable and cryptographically verified
- Document both the version tag AND digest in code/docs for clarity

**Example (CORRECT):**
```dockerfile
ARG BASE_DIGEST=sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af
FROM docker.io/k8ssandra/cass-management-api@${BASE_DIGEST}
# Comment: This is k8ssandra/cass-management-api:5.0.6-ubi-v0.1.110
```

**Example (WRONG - Supply Chain Vulnerability!):**
```dockerfile
FROM docker.io/k8ssandra/cass-management-api:5.0.6-ubi  # ❌ Mutable tag!
```

**Why this matters:**
- Attacker could replace upstream image with malicious version
- Same tag, different content = silent compromise
- Digest pinning prevents this attack vector

**Additional requirements:**
- Use official upstream images where possible (Docker Hub official images)
- Document base image source in component README
- Store digest mappings in repository variables for maintainability

### Multi-Architecture Support
- All images must support: `linux/amd64`, `linux/arm64`
- Test on both architectures before release
- Use `docker buildx` for multi-arch builds

### Security
- Run containers as non-root users with explicit UIDs/GIDs
- Scan all images with Trivy before publishing
- Address CRITICAL and HIGH severity vulnerabilities
- Keep component `.trivyignore` minimal and documented
  - Each component has its own `.trivyignore` file: `<component>/.trivyignore`
  - Each ignored CVE must have an inline comment explaining why
  - Example:
    ```
    # Java - K8ssandra Management API (upstream)
    CVE-2025-12183  # lz4-java 1.8.0 → 1.8.1 (HIGH - DoS risk, fixed in upstream)
    ```
  - Workflow must reference component-specific ignore file: `trivyignores: '<component>/.trivyignore'`

### Versioning
- Use explicit version directories (e.g., `5.0/`, `4.1/`)
- Version directory structure: `<component>/<major.minor>/`
- Never use `latest` tag in production examples

## GitHub Actions Workflows

### Location
- All workflows live at `.github/workflows/` (top-level only)
- Name workflows clearly:
  - Test workflow: `<component>-build-and-test.yml`
  - Publish workflow: `<component>-publish-signed.yml`

### Structure
- Use matrix builds to avoid duplication
- Filter `paths:` to avoid rebuilding unrelated images
- Implement comprehensive test suite before publishing
- Use GitHub Actions caching for Docker layers (`type=gha`)
- **Use composite actions to avoid duplication** - Place logic in `.github/actions/<component>-*/` directories
- **Name everything with component prefix** - Actions, workflows, jobs must use component name (e.g., `k8ssandra-*`)

### Composite Actions
- Store in `.github/actions/<component>-<action-name>/action.yml`
- Naming convention: `<component>-<action-name>` (e.g., `k8ssandra-setup-k3s`, `k8ssandra-test-cqlai`)
- Create separate actions for Docker vs Kubernetes contexts (e.g., `k8ssandra-test-cqlai` vs `k8ssandra-k3s-test-cqlai`)
- Always include error handling and safe defaults
- Document inputs clearly in action.yml

### Caching Strategy
- **Docker layers:** Use `cache-from: type=gha` and `cache-to: type=gha,mode=max` (auto-busting on code changes, 7-day retention)
- **External dependencies (Helm, etc.):** Use date-based cache keys (e.g., `helm-${{ runner.os }}-$(date +%Y-%m-%d)`) for daily refresh
- **Never cache indefinitely** - Always include version or date in cache key


### Publishing
- Publish to GHCR: `ghcr.io/axonops/<image-name>:<tag>`
- Tag format: `{CASS}-v{K8S_API}-{AXON}` (e.g., `5.0.6-v0.1.110-1.0.5`)
- Multi-arch manifests required for all published images
- Only publish on version tags (semantic versioning)

### Testing
Every workflow must include:
- Container build verification
- Service health checks (liveness/readiness)
- Functional tests appropriate for the component
- Process ownership verification (non-root)
- Security scanning (Trivy)

## Adding a New Component

1. **Create component directory**: `mkdir <component-name>`
2. **Add version subdirectories**: `mkdir <component-name>/<version>`
3. **Create Dockerfile**: Follow security and multi-arch conventions
4. **Add component README**: Document build/deploy process
5. **Create GitHub Actions workflow**: Copy existing workflow, update paths
6. **Add examples**: Include deployment examples in `<component-name>/examples/`
7. **Add scripts**: Component-specific utilities in `<component-name>/scripts/`
8. **Update root README**: Add component to Components section
9. **Update acknowledgements**: Add upstream project acknowledgements
10. **Update legal notices**: Add relevant trademarks to Legal Notices section

## Documentation Standards

### Component README Requirements
- Clear installation/deployment instructions
- Environment variable documentation
- Prerequisites section
- Troubleshooting guide
- Examples with working configurations

### Root README
- Keep generic (repository-level information only)
- List components with one-line descriptions
- Link to component-specific READMEs for details
- Maintain acknowledgements for upstream projects
- Keep legal notices current

## Git Workflow

### Branch Structure

**`main` - Production Branch**
- Production-ready code only
- Protected: requires PR approval, no direct pushes
- Only accepts merges from `development` branch
- Releases published to: `ghcr.io/axonops/<component>/<image-name>` (e.g., `ghcr.io/axonops/k8ssandra/cassandra`)

**`development` - Integration Branch**
- Default branch for all development work
- Developers commit directly (no PR required)
- Releases published to: `ghcr.io/axonops/development/<component>/<image-name>` (e.g., `ghcr.io/axonops/development/k8ssandra/cassandra`)
- Testing ground before promoting to production

**`feature/<name>` - Feature Branches (Optional)**
- Use for complex features that need isolation
- Use for collaborative work
- Not required - direct commits to development are fine

### Development Workflow

**Standard Workflow (Direct Commits):**
```bash
# Work directly on development
git checkout development
git pull origin development

# Make changes and commit
git add .
git commit -S -m "Add my feature"  # -S for signed commit

# Push to development
git push origin development

# CI tests run automatically on push
```

**Alternative: Feature Branches (Optional)**
```bash
# For complex features, use a feature branch
git checkout development
git pull origin development
git checkout -b feature/my-feature

# Make changes
git add .
git commit -S -m "Add my feature"

# Push feature branch
git push origin feature/my-feature

# Merge to development (direct merge, no PR needed)
git checkout development
git merge feature/my-feature
git push origin development
git branch -d feature/my-feature
```

**Promoting to Production:**
```bash
# When development is stable, create PR: development → main
# This REQUIRES approval before merging
```

### Commits
- Use conventional commit messages
- Keep commits focused and atomic
- No attribution to tools or AI in commit messages

### Pull Requests

**To Development:**
- **Not required** - Direct commits allowed
- Feature branches optional (for complex features)
- CI tests run automatically on all pushes

**To Main:**
- **Required** - Must create PR from `development` branch
- Requires approval (enforced by branch protection)
- CI tests run on PR
- Only merge when development is stable and tested

## Code Review Checklist

- [ ] Multi-arch support verified (amd64, arm64)
- [ ] Security scan passes (Trivy)
- [ ] Processes run as non-root
- [ ] Documentation updated
- [ ] Tests pass on all platforms
- [ ] Examples are working
- [ ] Legal notices updated if new dependencies added
- [ ] Acknowledgements added for upstream projects

## Maintenance

### Updating Base Images
1. Update base image version in Dockerfile
2. Test thoroughly on all platforms
3. Update component README with new version
4. Rebuild and republish images

### Security Updates
- Monitor security advisories for base images
- Address vulnerabilities promptly
- Document exceptions in `.trivyignore` with justification

### Deprecation Policy
- Keep deprecated versions in repository for reference
- Remove from CI/CD workflows when deprecating
- Document deprecation in component README
- Maintain for at least 6 months after deprecation

## Release Process

### Overview

Each component uses a two-stage release process:

1. **Continuous Testing** - Automatic testing on push/PR (no publishing)
2. **Manual Publishing** - Controlled release to GHCR via manual workflow

### Component Workflows

Each component should have three workflows:

**1. `<component>-build-and-test.yml`**
- Triggers: Push to `main`/`development`, PRs to `main`/`development` (with path filters for `<component>/**`)
- Runs: Full test suite
- Does NOT publish to GHCR

**2. `<component>-development-publish-signed.yml`** (Development Publishing - Signed)
- Trigger: Manual (`workflow_dispatch`)
- Inputs: `dev_git_tag`, `container_version`
- Validates: Tag is on development branch
- Runs: Full test suite on tagged code
- Publishes: Multi-arch images to `ghcr.io/axonops/development/<component>/<image-name>`
- Signs: All images with Cosign (keyless)
- Does NOT create GitHub Releases

**3. `<component>-publish-signed.yml`** (Production Publishing - Signed)
- Trigger: Manual (`workflow_dispatch`)
- Inputs: `main_git_tag`, `container_version`
- Validates: Tag is on main branch
- Runs: Full test suite on tagged code
- Publishes: Multi-arch images to `ghcr.io/axonops/<component>/<image-name>`
- Signs: All images with Cosign (keyless)
- Creates: DRAFT GitHub Release named `<component>-<container_version>` with component versions

### Development Release (Testing)

Publish development images for testing before production release:

1. **Tag development branch**
   ```bash
   git checkout development
   git pull origin development
   git tag dev-1.0.0
   git push origin dev-1.0.0
   ```

2. **Trigger development publish workflow**
   ```bash
   gh workflow run <component>-development-publish-signed.yml \
     -f dev_git_tag=dev-1.0.0 \
     -f container_version=dev-1.0.0
   ```

3. **Images published to development registry**
   - Registry: `ghcr.io/axonops/development/<component>/<image-name>`
   - Example: `ghcr.io/axonops/development/k8ssandra/cassandra:5.0.6-v0.1.110-dev-1.0.0`
   - Can be overwritten (no version validation)
   - No GitHub Release created

4. **Test development images**
   ```bash
   docker pull ghcr.io/axonops/development/<component>/<image>:<version>-v<k8s-api>-dev-1.0.0
   # Run tests, validate functionality
   ```

### Production Release (Main Branch)

When development images are tested and ready for production:

1. **Create promotion tag to auto-generate PR**
   ```bash
   git checkout development
   git pull origin development
   git tag merge-1.0.0
   git push origin merge-1.0.0
   ```

   The `create-promotion-pr.yml` workflow automatically creates a PR from `development` → `main` with:
   - Changelog of all commits
   - Next steps for production publishing
   - 'production-release' label

2. **Review and merge the auto-generated PR**
   - Review changes in PR
   - Approval required (enforced by branch protection)
   - Tests run on PR
   - Merge when approved

3. **Create Git Tag on Main Branch**
   ```bash
   # IMPORTANT: Must be on main branch
   git checkout main
   git pull origin main
   git tag 1.0.0
   git push origin 1.0.0
   ```

4. **Trigger Production Publish Workflow**

   **GitHub CLI:**
   ```bash
   gh workflow run <component>-publish-signed.yml \
     -f main_git_tag=1.0.0 \
     -f container_version=1.0.0
   ```

   **GitHub UI:**
   - Actions → Select publish workflow → Run workflow
   - Enter `main_git_tag` and `container_version`

5. **Workflow Execution**
   - Validates tag is on main branch (fails if not)
   - Validates container version doesn't exist in GHCR (prevents overwrites)
   - Checks out specific git tag
   - Runs all tests
   - Builds multi-arch images
   - Publishes to: `ghcr.io/axonops/<image-name>`
   - Creates GitHub Release

6. **Verify Production Release**
   ```bash
   gh release view <component>-1.0.0
   docker pull ghcr.io/axonops/<image>:<version>-1.0.0
   ```

### Component Release Documentation

Each component must have a `RELEASE.md` file documenting:
- Detailed release workflow
- Input parameters
- Troubleshooting steps
- Version validation
- Examples with gh CLI and GitHub UI

See `k8ssandra/RELEASE.md` for reference implementation.

## Legal Compliance

### Adding New Dependencies
When adding new container base images, libraries, or components:
1. Verify license compatibility (Apache 2.0 compatible)
2. Add to Legal Notices section in root README
3. Add to Acknowledgements section if applicable
4. Update trademark disclaimers

### Trademark Usage
- Use proper trademark symbols (®, ™) where applicable
- Include trademark disclaimers in README
- Respect upstream project naming and branding

## Questions or Issues?

- Open a GitHub Issue for bugs or feature requests
- Use GitHub Discussions for questions
- Review existing issues before creating new ones
