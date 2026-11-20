# CLAUDE.md — axonops-containers

Project-level instructions for Claude Code. Overrides global defaults; user instructions override this file.

## Documentation and translations

Every PR that changes user-facing content — README files, deployment guides, release docs, component docs, or any other `.md` file — must:

1. **Update the English source first.** `README.md` and all docs in the repo root and subdirectories are the source of truth.

2. **Keep translations in sync.** The following translations must reflect every change made to their English counterpart in the same PR:
   - `README.es.md`, `README.fr.md`, `README.gl.md` (repo root)
   - `strimzi/README.es.md`, `strimzi/README.fr.md`, `strimzi/README.gl.md`
   - `examples/STRIMZI_DEPLOYMENT.es.md`, `examples/STRIMZI_DEPLOYMENT.fr.md`, `examples/STRIMZI_DEPLOYMENT.gl.md`
   - Any other `*.es.md`, `*.fr.md`, `*.gl.md` file that mirrors a changed English doc

3. **Verify completeness.** Before creating a PR, grep for the changed section headings and key terms across all translation files to confirm nothing was missed.

Changes that touch only code, CI workflows, or non-documentation files do not require translation updates.
