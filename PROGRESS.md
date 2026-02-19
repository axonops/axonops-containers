# Progress

## Current Task
Add axonops-schema-registry as a new component to axonops-containers

## Status
- [x] Step 1: Research — Read all mandatory docs, study existing components — DONE
- [x] Step 2: Plan — Write detailed implementation plan — DONE
- [x] Step 3: Create directory structure and Dockerfile — DONE
- [x] Step 4: Create entrypoint and healthcheck scripts — DONE
- [x] Step 5: Create component documentation (README, DEVELOPMENT, RELEASE) — DONE
- [x] Step 6: Create CI/CD workflows (three-workflow pattern) — DONE
- [x] Step 7: Create composite actions (9 actions) — DONE
- [x] Step 8: Update repository-wide files (CLAUDE.md, README.md, DEVELOPMENT.md, TAG_CHANGELOG.md) — DONE
- [x] Step 9: Add arm64 smoke test job to CI — DONE
- [x] Step 10: Fix CI issues (tarball extraction, Trivy CVEs, SIGPIPE) — DONE
- [x] Step 11: Refactor versioning format to {SR_VERSION}-{CONTAINER_VERSION} (e.g., 0.2.0-0.0.1) — DONE
- [x] Step 12: Rename directory from 0.2.0/ to 0.2/ — DONE

## Decisions Made
- Use tarball download (not RPM) for multi-arch support in Dockerfile
- Use `schemaregistry` as non-root user (UID/GID 999)
- Port 8081 exposed (Schema Registry default)
- Health endpoint: `GET /` (native app health check)
- Multi-dimensional versioning: `{SR_VERSION}-{CONTAINER_VERSION}` (e.g., 0.2.0-0.0.1)
- Git tag format: `axonops-schema-registry-{SR_VERSION}-{CONTAINER_VERSION}`
- Memory storage backend as default config
- Directory structure: `axonops-schema-registry/0.2/` (major.minor only, no patch directories)

## Issues Encountered
- Tarball binary named `schema-registry` not `axonops-schema-registry` — fixed with symlink
- Tarball has top-level directory — fixed with `--strip-components=1`
- 4 Go stdlib CVEs in upstream binary — added to `.trivyignore`
- SIGPIPE exit 141 on arm64 QEMU — fixed with `|| true` in pipe

## Files Modified
- `axonops-schema-registry/0.2/Dockerfile` — Container build definition
- `axonops-schema-registry/0.2/.dockerignore` — Build context exclusions
- `axonops-schema-registry/0.2/config/config.yaml` — Default configuration
- `axonops-schema-registry/0.2/scripts/entrypoint.sh` — Container entrypoint with startup banner
- `axonops-schema-registry/0.2/scripts/healthcheck.sh` — Three-mode healthcheck
- `axonops-schema-registry/.trivyignore` — Security scan exceptions
- `axonops-schema-registry/README.md` — User-facing documentation
- `axonops-schema-registry/DEVELOPMENT.md` — Developer documentation
- `axonops-schema-registry/RELEASE.md` — Release process (two scenarios)
- `.github/workflows/axonops-schema-registry-build-and-test.yml` — CI test workflow (amd64 + arm64)
- `.github/workflows/axonops-schema-registry-publish-signed.yml` — Production publish workflow
- `.github/workflows/axonops-schema-registry-development-publish-signed.yml` — Dev publish workflow
- `.github/actions/axonops-schema-registry-*/action.yml` — 9 composite actions
- `CLAUDE.md` — Added schema-registry to all relevant sections
- `README.md` — Added to Components, Acknowledgements, release docs
- `DEVELOPMENT.md` — Added to component catalog
- `TAG_CHANGELOG.md` — Added schema-registry section with versioning pattern
