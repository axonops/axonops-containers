# Session Resume

## Task
Add axonops-schema-registry as a new component to the axonops-containers repository, including cross-repo automated release pipeline.

## Current State
All implementation steps are COMPLETE. Dockerfile moved to version-agnostic location, auto-version calculation action created, cross-repo release workflow created, documentation updated.

## Key Context
- Branch: feature/add-axonops-schema-registry
- PR: #123
- Component: axonops-schema-registry
- SR Version: 0.2.0, Container Version: auto-calculated
- Base image: UBI 9 minimal (digest-pinned)

## Important Details
- No AI attribution in commit messages
- Work on feature branch, PR to development (not direct commits)
- Multi-dimensional versioning: {SR_VERSION}-{CONTAINER_VERSION} (e.g., 0.2.0-0.0.1)
- Dockerfile is version-agnostic (at component root, not in version subdirectory)
- Cross-repo release via repository_dispatch from axonops/axonops-schema-registry
- Container version auto-calculated by querying GHCR for existing tags

## Next Steps (in order)
1. Push changes to remote
2. Verify CI passes

## Open Questions
- None
