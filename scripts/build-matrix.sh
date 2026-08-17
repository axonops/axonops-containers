#!/usr/bin/env bash
#
# build-matrix.sh - read the Cassandra build matrix out of versions.yaml.
#
# versions.yaml is the only place the Cassandra version list is declared.
# Workflows call this script instead of repeating a list in a `matrix:` block,
# so a version can never be built by one workflow and skipped by another. One
# list covers both published images: they share the k8ssandra Dockerfiles and
# base digests, so a version available to one is available to the other.
#
# Usage:
#   build-matrix.sh versions [--line LINE]
#       JSON array of every published version, oldest first, for use with
#       fromJSON() in a matrix. With --line, only that line's versions.
#   build-matrix.sh newest [--line LINE]
#       Newest published version. Without --line this is the newest version of
#       the newest published line - what the floating `latest` tag resolves to.
#   build-matrix.sh newest-line
#       The line the newest published version belongs to, e.g. "5.0". This is
#       what the floating `{line}-latest` tag is named after.
#   build-matrix.sh lines
#       JSON array of published lines, oldest first.
#   build-matrix.sh space-separated [--line LINE]
#       Published versions as a space-separated string, for shell loops.
#   build-matrix.sh check [--k8ssandra-versions JSON]
#       Validate the matrix: every published line has at least one version,
#       every unpublished line states a reason, versions are unique and belong
#       to the line they are listed under, and - when --k8ssandra-versions is
#       given - every version has a matching key in that JSON map. Run this
#       before building: a version with no `cass-management-api` base fails
#       every build job for that version, 15 minutes in.
#
# When run under GitHub Actions the result is also appended to $GITHUB_OUTPUT
# as `result=<value>`, so a job can expose it as `steps.<id>.outputs.result`.
#
# Dependencies: bash 4+, yq (mikefarah), jq.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS_YAML="${REPO_ROOT}/versions.yaml"

log() { printf '%s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,35p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

require_deps() {
  local missing=()
  for dep in yq jq; do
    command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
  done
  [[ ${#missing[@]} -eq 0 ]] || die "missing dependencies: ${missing[*]}"
  yq --version 2>&1 | grep -q 'mikefarah' \
    || die "yq must be the mikefarah build (https://github.com/mikefarah/yq)"
  yq -e '.build_matrix.lines' "$VERSIONS_YAML" >/dev/null 2>&1 \
    || die "versions.yaml has no build_matrix.lines section"
}

# JSON array of published versions. LINE, when set, restricts to one line.
published_versions() {
  local line="${1:-}"
  if [[ -n "$line" ]]; then
    yq -o=json -I=0 \
      "[.build_matrix.lines[]
          | select(.published == true and .line == \"${line}\")
          | .versions[]]" "$VERSIONS_YAML"
  else
    yq -o=json -I=0 \
      "[.build_matrix.lines[]
          | select(.published == true)
          | .versions[]]" "$VERSIONS_YAML"
  fi
}

published_lines() {
  yq -o=json -I=0 \
    "[.build_matrix.lines[] | select(.published == true) | .line]" "$VERSIONS_YAML"
}

# The last version of the last published line. Ordering in versions.yaml is the
# only ordering signal - the file documents that lists are oldest first - so
# nothing here sorts, which would put 5.0.10 before 5.0.9.
newest_version() {
  published_versions "${1:-}" | jq -r 'if length == 0 then "" else .[-1] end'
}

check_matrix() {
  local k8ssandra_versions="${1:-}"
  local count idx line published reason versions failed=0

  count="$(yq '.build_matrix.lines | length' "$VERSIONS_YAML")"
  [[ "$count" -gt 0 ]] || die "build_matrix declares no lines"

  for ((idx = 0; idx < count; idx++)); do
    line="$(yq -r ".build_matrix.lines[${idx}].line" "$VERSIONS_YAML")"
    published="$(yq -r ".build_matrix.lines[${idx}].published" "$VERSIONS_YAML")"
    reason="$(yq -r ".build_matrix.lines[${idx}].reason // \"\"" "$VERSIONS_YAML")"
    versions="$(yq -o=json -I=0 ".build_matrix.lines[${idx}].versions // []" "$VERSIONS_YAML")"

    if [[ "$published" == "true" ]]; then
      if [[ "$(jq -r 'length' <<<"$versions")" -eq 0 ]]; then
        log "ERROR: line ${line} is published but lists no versions"
        failed=1
      fi
      if [[ "$(jq -r 'length' <<<"$versions")" -ne "$(jq -r 'unique | length' <<<"$versions")" ]]; then
        log "ERROR: line ${line} lists a duplicate version"
        failed=1
      fi
      # A version under the wrong line builds from the wrong Dockerfile
      # directory, which fails late and confusingly.
      while read -r version; do
        [[ -z "$version" ]] && continue
        [[ "$version" == "${line}."* ]] \
          || { log "ERROR: version ${version} is listed under line ${line}"; failed=1; }
      done < <(jq -r '.[]' <<<"$versions")

      [[ -d "${REPO_ROOT}/k8ssandra/${line}" ]] \
        || { log "ERROR: line ${line} is published but k8ssandra/${line}/ does not exist"; failed=1; }
    else
      [[ -n "$reason" ]] \
        || { log "ERROR: line ${line} is unpublished but gives no reason"; failed=1; }
    fi
  done

  if [[ -z "$k8ssandra_versions" ]]; then
    log "NOTE: pass --k8ssandra-versions to verify each version has a cass-management-api base image"
  else
    jq -e 'type == "object"' <<<"$k8ssandra_versions" >/dev/null 2>&1 \
      || die "--k8ssandra-versions must be a JSON object mapping '<cassandra>+<api>' to a digest"
    while read -r version; do
      [[ -z "$version" ]] && continue
      if ! jq -e --arg v "$version" 'keys[] | select(startswith($v + "+"))' <<<"$k8ssandra_versions" >/dev/null 2>&1; then
        log "ERROR: Cassandra ${version} is in the build matrix but K8SSANDRA_VERSIONS has no '${version}+<api>' key"
        log "       k8ssandra publishes no cass-management-api base for it, so every build job for ${version} would fail."
        failed=1
      fi
    done < <(jq -r '.[]' <<<"$(published_versions)")
  fi

  [[ "$failed" -eq 0 ]] || die "build matrix is not valid"
  log "✓ build matrix is valid"
  printf 'ok'
}

main() {
  [[ $# -ge 1 ]] || usage 1
  case "${1:-}" in
    -h | --help) usage 0 ;;
  esac

  require_deps

  local mode="$1" line='' k8ssandra_versions='' result=''
  shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --line)
        [[ $# -ge 2 ]] || die "--line needs a value"
        line="$2"
        shift 2
        ;;
      --k8ssandra-versions)
        [[ $# -ge 2 ]] || die "--k8ssandra-versions needs a value"
        k8ssandra_versions="$2"
        shift 2
        ;;
      *) die "unknown argument: $1" ;;
    esac
  done

  case "$mode" in
    versions) result="$(published_versions "$line")" ;;
    newest) result="$(newest_version "$line")" ;;
    newest-line) result="$(newest_version | cut -d. -f1,2)" ;;
    lines) result="$(published_lines)" ;;
    space-separated) result="$(published_versions "$line" | jq -r 'join(" ")')" ;;
    check) result="$(check_matrix "$k8ssandra_versions")" ;;
    *) die "unknown mode '${mode}' (versions, newest, newest-line, lines, space-separated, check)" ;;
  esac

  # An empty result would render as an empty matrix, which builds nothing and
  # still reports success. Fail instead.
  [[ -n "$result" && "$result" != "[]" ]] \
    || die "no result for '${mode}'${line:+ on line ${line}} - is the line published in versions.yaml?"

  printf '%s\n' "$result"
  [[ -n "${GITHUB_OUTPUT:-}" ]] && printf 'result=%s\n' "$result" >>"$GITHUB_OUTPUT"
  return 0
}

main "$@"
