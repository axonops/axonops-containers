#!/usr/bin/env bash
#
# strimzi-compat-table.sh - render the Strimzi image compatibility table.
#
# The VERSION_MATRIX in .github/workflows/strimzi-publish-signed.yml decides
# which operator and Kafka versions the AxonOps Strimzi Kafka image is built
# for. This script renders that matrix as a Markdown table and writes it
# between the markers below in examples/STRIMZI_DEPLOYMENT.md and its
# translations, so the documented tags cannot drift from the built ones.
#
#   <!-- strimzi-compat-table:start -->
#   <!-- strimzi-compat-table:end -->
#
# Modes:
#   (default)   Rewrite the table in every target file.
#   --check     Fail if any target file differs from the matrix. Intended as a
#               CI gate.
#   --print     Print the English table to stdout.
#
# Dependencies: bash 4+, yq (mikefarah), jq.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="${REPO_ROOT}/.github/workflows/strimzi-publish-signed.yml"
TARGETS=(
  examples/STRIMZI_DEPLOYMENT.md
  examples/STRIMZI_DEPLOYMENT.es.md
  examples/STRIMZI_DEPLOYMENT.fr.md
  examples/STRIMZI_DEPLOYMENT.gl.md
)
START_MARKER='<!-- strimzi-compat-table:start -->'
END_MARKER='<!-- strimzi-compat-table:end -->'
TMP_FILE=""

log() { printf '%s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
}

header_for() {
  case "$1" in
    *.es.md) printf '| Operador Strimzi | Versiones de Kafka | Etiquetas flotantes |\n' ;;
    *.fr.md) printf '| Opérateur Strimzi | Versions de Kafka | Tags flottants |\n' ;;
    *.gl.md) printf '| Operador Strimzi | Versións de Kafka | Etiquetas flotantes |\n' ;;
    *)       printf '| Strimzi operator | Kafka versions | Floating tags |\n' ;;
  esac
  printf '| --- | --- | --- |\n'
}

# One row per operator, newest first. The floating tags are the
# <strimzi>-<kafka> tag for every Kafka version plus <strimzi>-latest, which
# the publish workflow points at the newest Kafka version for that operator.
table_rows() {
  local matrix
  matrix="$(yq -e '.env.VERSION_MATRIX' "$WORKFLOW")" \
    || die "VERSION_MATRIX not found in ${WORKFLOW}"
  jq -r '
    def semver: split(".") | map(tonumber);
    to_entries
    | sort_by(.key | semver) | reverse
    | .[]
    | .key as $op
    | (.value.kafka_versions | sort_by(semver)) as $kafka
    | "| \($op) | \($kafka | join(", ")) | "
      + ([$kafka[] | "`\($op)-\(.)`"] + ["`\($op)-latest`"] | join(", "))
      + " |"
  ' <<<"$matrix"
}

render_table() {
  header_for "$1"
  table_rows
}

# Replace the lines between the markers in $1 with the table, writing to $2.
render_file() {
  local src="$1" dest="$2" table
  grep -qF "$START_MARKER" "$src" || die "${src}: missing ${START_MARKER}"
  grep -qF "$END_MARKER" "$src" || die "${src}: missing ${END_MARKER}"
  table="$(render_table "$src")"
  TABLE="$table" awk -v start="$START_MARKER" -v end="$END_MARKER" '
    $0 == start { print; print ENVIRON["TABLE"]; skip = 1; next }
    $0 == end   { skip = 0 }
    !skip       { print }
  ' "$src" >"$dest"
}

main() {
  local mode="generate"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check)   mode="check" ;;
      --print)   mode="print" ;;
      -h|--help) usage 0 ;;
      *)         log "unknown argument: $1"; usage 1 ;;
    esac
    shift
  done

  require_deps
  [[ -f "$WORKFLOW" ]] || die "not found: ${WORKFLOW}"

  if [[ "$mode" == "print" ]]; then
    render_table "${TARGETS[0]}"
    return
  fi

  local target stale=0
  TMP_FILE="$(mktemp)"
  trap 'rm -f "${TMP_FILE:-}"' EXIT

  for target in "${TARGETS[@]}"; do
    render_file "${REPO_ROOT}/${target}" "$TMP_FILE"
    if [[ "$mode" == "check" ]]; then
      if ! diff -u "${REPO_ROOT}/${target}" "$TMP_FILE"; then
        log "${target} is out of date"
        stale=1
      fi
    else
      cat "$TMP_FILE" >"${REPO_ROOT}/${target}"
      log "wrote ${target}"
    fi
  done

  if [[ "$stale" -ne 0 ]]; then
    die "Strimzi compatibility table is out of date - run ./scripts/strimzi-compat-table.sh"
  fi
  [[ "$mode" == "check" ]] && log "Strimzi compatibility table is up to date"
  return 0
}

main "$@"
