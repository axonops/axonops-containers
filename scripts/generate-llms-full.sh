#!/usr/bin/env bash
#
# generate-llms-full.sh - build llms-full.txt from the documentation manifest.
#
# llms-full.txt is a single Markdown bundle of this repository's canonical
# documentation, for tools that want the whole thing as one context source. It
# is generated, never edited by hand.
#
# Modes:
#   (default)   Regenerate llms-full.txt from scripts/llms-manifest.txt.
#   --check     Verify the repository is consistent, changing nothing. Fails if
#               llms-full.txt is out of date, if a tracked Markdown file is in
#               neither list of the manifest, if a manifest path does not exist,
#               or if a relative link in llms.txt does not resolve. Intended as
#               a CI gate.
#
# Dependencies: bash 4+, git.
#
# Neither llms.txt nor llms-full.txt controls crawlers, indexing, training or
# licensing. They are discovery and context aids; the linked files remain the
# canonical source.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${REPO_ROOT}/scripts/llms-manifest.txt"
INDEX="${REPO_ROOT}/llms.txt"
BUNDLE="${REPO_ROOT}/llms-full.txt"
TMP_BUNDLE=""

log()  { printf '%s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

cleanup() { [[ -n "$TMP_BUNDLE" && -f "$TMP_BUNDLE" ]] && rm -f "$TMP_BUNDLE"; return 0; }
trap cleanup EXIT

# Print the paths carrying a given directive, in manifest order. A trailing
# `# reason` comment is stripped.
manifest_paths() {
  local directive="$1"
  sed 's/[[:space:]]*#.*$//' "$MANIFEST" \
    | awk -v d="$directive" '$1 == d && NF >= 2 { $1 = ""; sub(/^[[:space:]]+/, ""); print }'
}

# Every Markdown file must be accounted for, so a new document cannot slip into
# the repository without a decision about whether it belongs in the bundle.
check_manifest_coverage() {
  local tracked included excluded listed missing=() unknown=()

  tracked="$(cd "$REPO_ROOT" && git ls-files '*.md' | sort)"
  included="$(manifest_paths include | sort)"
  excluded="$(manifest_paths exclude | sort)"
  listed="$(printf '%s\n%s\n' "$included" "$excluded" | sed '/^$/d' | sort)"

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    grep -qxF "$path" <<< "$listed" || missing+=("$path")
  done <<< "$tracked"

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    grep -qxF "$path" <<< "$tracked" || unknown+=("$path")
  done <<< "$listed"

  if [[ ${#missing[@]} -gt 0 ]]; then
    log "these Markdown files are in neither list of scripts/llms-manifest.txt:"
    printf '  %s\n' "${missing[@]}" >&2
    log "add each as an 'include' or an 'exclude' with a reason."
    return 1
  fi

  if [[ ${#unknown[@]} -gt 0 ]]; then
    log "these manifest paths do not exist:"
    printf '  %s\n' "${unknown[@]}" >&2
    return 1
  fi

  # A path listed twice would be bundled twice.
  local dupes
  dupes="$(printf '%s\n' "$listed" | uniq -d)"
  if [[ -n "$dupes" ]]; then
    log "these paths are listed more than once in the manifest:"
    printf '  %s\n' "$dupes" >&2
    return 1
  fi

  return 0
}

# Relative links in llms.txt must resolve from the repository root, or the index
# is worse than no index. Anchors, absolute URLs and mailto: are skipped.
check_index_links() {
  local broken=() target
  [[ -f "$INDEX" ]] || die "not found: ${INDEX}"

  while IFS= read -r target; do
    [[ -n "$target" ]] || continue
    case "$target" in
      http://*|https://*|mailto:*|'#'*) continue ;;
    esac
    target="${target%%#*}"
    [[ -n "$target" ]] || continue
    [[ -e "${REPO_ROOT}/${target}" ]] || broken+=("$target")
  done < <(grep -o '](\([^)]*\))' "$INDEX" | sed 's/^](//; s/)$//')

  if [[ ${#broken[@]} -gt 0 ]]; then
    log "these llms.txt links do not resolve from the repository root:"
    printf '  %s\n' "${broken[@]}" >&2
    return 1
  fi

  return 0
}

# Deterministic: manifest order in, no timestamps, no host-dependent values.
render_bundle() {
  local out="$1" path first=1

  cat > "$out" <<'HEADER'
# AxonOps Containers - full documentation bundle

> Generated file. Do not edit.
>
> Regenerate with ./scripts/generate-llms-full.sh; the source list is
> scripts/llms-manifest.txt. CI fails if this file is out of date.

Every document below is reproduced verbatim from this repository, each under a
`# Source: <path>` heading giving its path from the repository root. Those files
remain canonical: read the original before applying any command or configuration
change, and prefer it over this bundle if the two ever disagree.

This bundle carries prose documentation only. Docker Compose files, Kubernetes
manifests, Helm values, Dockerfiles and scripts are not included - follow the
paths in the documents to the real files. Translations are not included either;
llms.txt links those.

This file is a discovery and context aid. It does not control crawlers,
indexing, model training, licensing or attribution.
HEADER

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ -f "${REPO_ROOT}/${path}" ]] || die "manifest lists a missing file: ${path}"

    printf '\n---\n\n# Source: %s\n\n' "$path" >> "$out"
    cat "${REPO_ROOT}/${path}" >> "$out"

    # Guarantee a newline between documents whatever the source ends with.
    [[ -n "$(tail -c 1 "${REPO_ROOT}/${path}")" ]] && printf '\n' >> "$out"

    first=0
  done < <(manifest_paths include)

  [[ "$first" -eq 0 ]] || die "manifest lists no files to include"
}

main() {
  local mode="write"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check)     mode="check"; shift ;;
      -h|--help)   usage 0 ;;
      *)           log "unknown argument: $1"; usage 1 ;;
    esac
  done

  [[ -f "$MANIFEST" ]] || die "not found: ${MANIFEST}"
  command -v git >/dev/null 2>&1 || die "missing dependency: git"

  check_manifest_coverage || die "manifest checks failed"

  TMP_BUNDLE="$(mktemp)"
  render_bundle "$TMP_BUNDLE"

  case "$mode" in
    check)
      [[ -f "$BUNDLE" ]] || die "llms-full.txt does not exist - run ./scripts/generate-llms-full.sh"
      if ! diff -u "$BUNDLE" "$TMP_BUNDLE" >&2; then
        die "llms-full.txt is out of date - run ./scripts/generate-llms-full.sh"
      fi
      ;;
    write)
      mv "$TMP_BUNDLE" "$BUNDLE"
      TMP_BUNDLE=""
      log "wrote ${BUNDLE}"
      ;;
  esac

  # After the bundle exists, so a first run on a fresh checkout does not fail on
  # llms.txt's own link to it.
  check_index_links || die "index checks failed"

  [[ "$mode" == "check" ]] && log "llms.txt and llms-full.txt are up to date"

  return 0
}

main "$@"
