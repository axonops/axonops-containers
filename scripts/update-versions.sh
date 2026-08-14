#!/usr/bin/env bash
#
# update-versions.sh - keep versions.yaml and VERSIONS.md in step.
#
# Modes:
#   (default)   Regenerate VERSIONS.md from versions.yaml.
#   --refresh   Query each registry for the digest of every component's current
#               tag and write it back into versions.yaml, then regenerate
#               VERSIONS.md. Requires network access to ghcr.io and
#               registry.axonops.com.
#   --check     Regenerate VERSIONS.md into a temporary file and fail if it
#               differs from the committed one. Intended as a CI gate.
#
# Dependencies: bash 4+, yq (mikefarah), jq, curl.
#
# Only public, anonymously pullable repositories are resolved. A private or
# unpublished repository yields an empty digest and a warning, not a failure, so
# a component can be listed here before its first release.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS_YAML="${REPO_ROOT}/versions.yaml"
VERSIONS_MD="${REPO_ROOT}/VERSIONS.md"
TMP_MD=""

MANIFEST_ACCEPT=(
  -H 'Accept: application/vnd.oci.image.index.v1+json'
  -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json'
  -H 'Accept: application/vnd.oci.image.manifest.v1+json'
  -H 'Accept: application/vnd.docker.distribution.manifest.v2+json'
)

log()  { printf '%s\n' "$*" >&2; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

require_deps() {
  local missing=()
  for dep in yq jq curl; do
    command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
  done
  [[ ${#missing[@]} -eq 0 ]] || die "missing dependencies: ${missing[*]}"
  yq --version 2>&1 | grep -q 'mikefarah' \
    || die "yq must be the mikefarah build (https://github.com/mikefarah/yq)"
}

# Resolve a manifest digest for registry/repository:tag. Prints the digest, or
# nothing if the tag cannot be resolved anonymously.
digest_for() {
  local registry="$1" repository="$2" tag="$3" token='' digest=''

  if [[ "$registry" == "ghcr.io" ]]; then
    token="$(curl -fsS "https://ghcr.io/token?scope=repository:${repository}:pull&service=ghcr.io" \
      | jq -r '.token // empty')" || true
  fi

  local auth=()
  [[ -n "$token" ]] && auth=(-H "Authorization: Bearer ${token}")

  digest="$(curl -fsSI "${auth[@]}" "${MANIFEST_ACCEPT[@]}" \
    "https://${registry}/v2/${repository}/manifests/${tag}" 2>/dev/null \
    | awk 'tolower($1) == "docker-content-digest:" { print $2 }' | tr -d '\r')" || true

  printf '%s' "$digest"
}

refresh_digests() {
  local count idx name kind registry repository tag digest
  count="$(yq '.components | length' "$VERSIONS_YAML")"

  for (( idx = 0; idx < count; idx++ )); do
    name="$(yq -r ".components[${idx}].name" "$VERSIONS_YAML")"
    kind="$(yq -r ".components[${idx}].kind" "$VERSIONS_YAML")"
    tag="$(yq -r ".components[${idx}].current.tag // \"\"" "$VERSIONS_YAML")"

    if [[ "$kind" != "image" ]]; then
      continue  # Helm charts are OCI artifacts but are pinned by chart version.
    fi
    if [[ -z "$tag" || "$tag" == "null" ]]; then
      warn "${name}: no current tag, skipping"
      continue
    fi

    registry="$(yq -r ".components[${idx}].registry" "$VERSIONS_YAML")"
    repository="$(yq -r ".components[${idx}].repository" "$VERSIONS_YAML")"

    digest="$(digest_for "$registry" "$repository" "$tag")"
    if [[ -z "$digest" ]]; then
      warn "${name}: could not resolve ${registry}/${repository}:${tag}"
      continue
    fi

    yq -i ".components[${idx}].current.digest = \"${digest}\"" "$VERSIONS_YAML"
    log "${name}: ${tag} -> ${digest}"
  done

  yq -i ".last_verified = \"$(date -u +%Y-%m-%d)\"" "$VERSIONS_YAML"
}

generate_md() {
  local out="$1"
  local count idx name kind git_tag registry repository tag digest notes previous verified

  verified="$(yq -r '.last_verified' "$VERSIONS_YAML")"
  count="$(yq '.components | length' "$VERSIONS_YAML")"

  {
    cat <<EOF
<!--
  GENERATED FILE - DO NOT EDIT.
  Source: versions.yaml
  Regenerate: ./scripts/update-versions.sh
-->

# Current Versions

The current release of every container image and Helm chart published from this
repository. Registry data last verified **${verified}**.

Components are listed in deployment order: data stores, then the AxonOps
services that depend on them, then the operator images, then the Helm charts.

**Pin by digest, not by tag.** A digest is a cryptographic checksum of the exact
image; a tag is a mutable pointer that can be moved. See
[Gold Standard Security Deployment](README.md#gold-standard-security-deployment)
for the full rationale and the verification steps.

## Images

| Component | Current tag | Digest | Git tag |
|-----------|-------------|--------|---------|
EOF

    for (( idx = 0; idx < count; idx++ )); do
      kind="$(yq -r ".components[${idx}].kind" "$VERSIONS_YAML")"
      [[ "$kind" == "image" ]] || continue
      name="$(yq -r ".components[${idx}].name" "$VERSIONS_YAML")"
      registry="$(yq -r ".components[${idx}].registry" "$VERSIONS_YAML")"
      repository="$(yq -r ".components[${idx}].repository" "$VERSIONS_YAML")"
      tag="$(yq -r ".components[${idx}].current.tag // \"—\"" "$VERSIONS_YAML")"
      digest="$(yq -r ".components[${idx}].current.digest // \"—\"" "$VERSIONS_YAML")"
      git_tag="$(yq -r ".components[${idx}].git_tag // \"—\"" "$VERSIONS_YAML")"
      [[ "$tag" == "null" ]] && tag="—"
      [[ "$digest" == "null" ]] && digest="—"
      [[ "$git_tag" == "null" ]] && git_tag="—"
      printf '| `%s/%s` | `%s` | `%s` | `%s` |\n' \
        "$registry" "$repository" "$tag" "$digest" "$git_tag"
    done

    cat <<'EOF'

## Helm charts

| Chart | Version | Git tag |
|-------|---------|---------|
EOF

    for (( idx = 0; idx < count; idx++ )); do
      kind="$(yq -r ".components[${idx}].kind" "$VERSIONS_YAML")"
      [[ "$kind" == "chart" ]] || continue
      registry="$(yq -r ".components[${idx}].registry" "$VERSIONS_YAML")"
      repository="$(yq -r ".components[${idx}].repository" "$VERSIONS_YAML")"
      tag="$(yq -r ".components[${idx}].current.tag // \"—\"" "$VERSIONS_YAML")"
      git_tag="$(yq -r ".components[${idx}].git_tag // \"—\"" "$VERSIONS_YAML")"
      printf '| `oci://%s/%s` | `%s` | `%s` |\n' \
        "$registry" "$repository" "$tag" "$git_tag"
    done

    printf '\n## Pinned references\n\nCopy these straight into a compose file, manifest or Helm values file.\n\n```\n'

    for (( idx = 0; idx < count; idx++ )); do
      kind="$(yq -r ".components[${idx}].kind" "$VERSIONS_YAML")"
      [[ "$kind" == "image" ]] || continue
      digest="$(yq -r ".components[${idx}].current.digest // \"\"" "$VERSIONS_YAML")"
      [[ -n "$digest" && "$digest" != "null" ]] || continue
      registry="$(yq -r ".components[${idx}].registry" "$VERSIONS_YAML")"
      repository="$(yq -r ".components[${idx}].repository" "$VERSIONS_YAML")"
      printf '%s/%s@%s\n' "$registry" "$repository" "$digest"
    done

    printf '```\n\n## Notes\n\n'

    for (( idx = 0; idx < count; idx++ )); do
      notes="$(yq -r ".components[${idx}].notes // \"\"" "$VERSIONS_YAML")"
      [[ -n "$notes" && "$notes" != "null" ]] || continue
      name="$(yq -r ".components[${idx}].name" "$VERSIONS_YAML")"
      printf -- '- **%s** — %s\n' "$name" "$notes"
    done

    cat <<'EOF'

## Previous releases

Newest-first, per component. Full git-tag-to-image history lives in
[TAG_CHANGELOG.md](TAG_CHANGELOG.md).

EOF

    for (( idx = 0; idx < count; idx++ )); do
      previous="$(yq -r ".components[${idx}].previous[]" "$VERSIONS_YAML" 2>/dev/null || true)"
      [[ -n "$previous" ]] || continue
      name="$(yq -r ".components[${idx}].name" "$VERSIONS_YAML")"

      local line='' entry
      while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        line+="${line:+, }\`${entry}\`"
      done <<< "$previous"

      printf -- '- **%s**: %s\n' "$name" "$line"
    done
  } > "$out"
}

main() {
  local mode="generate"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --refresh) mode="refresh" ;;
      --check)   mode="check" ;;
      -h|--help) usage 0 ;;
      *)         log "unknown argument: $1"; usage 1 ;;
    esac
    shift
  done

  require_deps
  [[ -f "$VERSIONS_YAML" ]] || die "not found: ${VERSIONS_YAML}"

  case "$mode" in
    refresh)
      refresh_digests
      generate_md "$VERSIONS_MD"
      log "updated ${VERSIONS_YAML} and ${VERSIONS_MD}"
      ;;
    check)
      TMP_MD="$(mktemp)"
      trap 'rm -f "${TMP_MD:-}"' EXIT
      generate_md "$TMP_MD"
      if ! diff -u "$VERSIONS_MD" "$TMP_MD"; then
        die "VERSIONS.md is out of date - run ./scripts/update-versions.sh"
      fi
      log "VERSIONS.md is up to date"
      ;;
    generate)
      generate_md "$VERSIONS_MD"
      log "wrote ${VERSIONS_MD}"
      ;;
  esac
}

main "$@"
