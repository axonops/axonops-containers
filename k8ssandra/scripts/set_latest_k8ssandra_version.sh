#!/usr/bin/env bash
# Sets the K8SSANDRA_VERSION GitHub Actions variable to the latest Cassandra
# version found in the K8SSANDRA_VERSIONS repository variable.
#
# Usage:
#   ./set_latest_k8ssandra_version.sh [--repo OWNER/REPO] [--dry-run]
#
# Requirements: gh CLI authenticated, jq

set -euo pipefail

REPO="${GITHUB_REPOSITORY:-axonops/axonops-containers}"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)   REPO="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

echo "Fetching K8SSANDRA_VERSIONS from ${REPO}..."
VERSIONS_JSON=$(gh variable get K8SSANDRA_VERSIONS --repo "$REPO" --json value -q .value)

if [ -z "$VERSIONS_JSON" ]; then
  echo "ERROR: K8SSANDRA_VERSIONS variable is empty or not set" >&2
  exit 1
fi

# Keys are "CASSANDRA_VER+API_VER" (e.g. "5.0.7+0.1.113").
# Extract the Cassandra part and find the highest semver.
LATEST=$(echo "$VERSIONS_JSON" | jq -r '
  keys[]
  | split("+")[0]
' | sort -V | tail -1)

if [ -z "$LATEST" ]; then
  echo "ERROR: Could not determine latest version" >&2
  exit 1
fi

echo "Latest Cassandra version: ${LATEST}"

if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] Would set K8SSANDRA_VERSION=${LATEST} on ${REPO}"
  exit 0
fi

gh variable set K8SSANDRA_VERSION --body "$LATEST" --repo "$REPO"
echo "✓ K8SSANDRA_VERSION=${LATEST} set on ${REPO}"
