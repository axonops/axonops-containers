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

## Decisions Made
- Use tarball download (not RPM) for multi-arch support in Dockerfile
- Use `schemaregistry` as non-root user (UID/GID 999)
- Port 8081 exposed (Schema Registry default)
- Health endpoint: `GET /` (native app health check)
- Multi-dimensional versioning: `{SR_VERSION}-{BUILD}` (e.g., 0.2.0-1)
- Git tag format: `axonops-schema-registry-{SR_VERSION}-{BUILD}`
- Memory storage backend as default config

## Issues Encountered
- None significant

## Files Modified
- `axonops-schema-registry/0.2.0/Dockerfile` — Container build definition
- `axonops-schema-registry/0.2.0/.dockerignore` — Build context exclusions
- `axonops-schema-registry/0.2.0/config/config.yaml` — Default configuration
- `axonops-schema-registry/0.2.0/scripts/entrypoint.sh` — Container entrypoint with startup banner
- `axonops-schema-registry/0.2.0/scripts/healthcheck.sh` — Three-mode healthcheck
- `axonops-schema-registry/.trivyignore` — Security scan exceptions
- `axonops-schema-registry/README.md` — User-facing documentation
- `axonops-schema-registry/DEVELOPMENT.md` — Developer documentation
- `axonops-schema-registry/RELEASE.md` — Release process (two scenarios)
- `.github/workflows/axonops-schema-registry-build-and-test.yml` — CI test workflow
- `.github/workflows/axonops-schema-registry-publish-signed.yml` — Production publish workflow
- `.github/workflows/axonops-schema-registry-development-publish-signed.yml` — Dev publish workflow
- `.github/actions/axonops-schema-registry-sign-container/action.yml` — Cosign signing
- `.github/actions/axonops-schema-registry-start-and-wait/action.yml` — Container startup
- `.github/actions/axonops-schema-registry-test-healthcheck/action.yml` — Health probe tests
- `.github/actions/axonops-schema-registry-verify-startup-banner/action.yml` — Banner validation
- `.github/actions/axonops-schema-registry-verify-no-startup-errors/action.yml` — Error scan
- `.github/actions/axonops-schema-registry-verify-versions/action.yml` — Version checks
- `.github/actions/axonops-schema-registry-verify-published-image/action.yml` — Post-publish verify
- `.github/actions/axonops-schema-registry-collect-logs/action.yml` — Log collection
- `.github/actions/axonops-schema-registry-test-api/action.yml` — API functional tests
- `CLAUDE.md` — Added schema-registry to all relevant sections
- `README.md` — Added to Components, Acknowledgements, release docs
- `DEVELOPMENT.md` — Added to component catalog
- `TAG_CHANGELOG.md` — Added schema-registry section with versioning pattern
