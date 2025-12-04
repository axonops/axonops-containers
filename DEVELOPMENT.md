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
- Use official upstream images where possible (Docker Hub official images)
- Document base image source in component README
- Pin base image versions explicitly

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
  - Publish workflow: `<component>-publish.yml`

### Structure
- Use matrix builds to avoid duplication
- Filter `paths:` to avoid rebuilding unrelated images
- Implement comprehensive test suite before publishing
- Use GitHub Actions caching for Docker layers (`type=gha`)

### Publishing
- Publish to GHCR: `ghcr.io/axonops/<image-name>:<tag>`
- Tag format: `<version>-<release>` (e.g., `5.0.6-1.0.0`)
- Multi-arch manifests required for all published images
- Only publish on version tags (semantic versioning)

### Testing
Every workflow must include:
- Container build verification
- Service health checks (liveness/readiness)
- Functional tests (API endpoints, CQL operations, etc.)
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

### Branching
- `main` - production-ready code
- `feature/<name>` - new features or components
- `fix/<name>` - bug fixes

### Commits
- Use conventional commit messages
- Keep commits focused and atomic
- No attribution to tools or AI in commit messages

### Pull Requests
- Test locally before creating PR
- Ensure CI passes on all platforms
- Update documentation as needed
- Link to related issues

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

Each component should have two workflows:

**1. `<component>-build-and-test.yml`**
- Triggers: Push to `main`, PRs (with path filters for `<component>/**`)
- Runs: Full test suite
- Does NOT publish to GHCR

**2. `<component>-publish.yml`**
- Trigger: Manual (`workflow_dispatch`)
- Inputs: `main_git_tag`, `container_version`
- Validates: Tag is on main branch, container version doesn't exist in GHCR
- Runs: Full test suite on tagged code
- Publishes: Multi-arch images to GHCR
- Creates: GitHub Release named `<component>-<container_version>`

### Release Steps

1. **Develop & Test**
   ```bash
   git push origin feature/my-feature
   # PR created → tests run automatically
   # Merge when tests pass
   ```

2. **Create Git Tag on Main Branch**
   ```bash
   # IMPORTANT: Must be on main branch
   git checkout main
   git pull origin main
   git tag 1.0.0
   git push origin 1.0.0
   ```

3. **Trigger Publish Workflow**

   **GitHub UI:**
   - Actions → Select publish workflow → Run workflow
   - Enter `main_git_tag` and `container_version`

   **GitHub CLI:**
   ```bash
   gh workflow run <component>-publish.yml \
     -f main_git_tag=1.0.0 \
     -f container_version=1.0.0
   ```

4. **Workflow Execution**
   - Validates tag is on main branch (fails if not)
   - Validates version doesn't exist in GHCR
   - Checks out specific git tag
   - Runs all tests
   - Builds multi-arch images
   - Publishes to GHCR
   - Creates GitHub Release

5. **Verify Release**
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
