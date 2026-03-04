#!/usr/bin/env bash
#
# Add a new Strimzi operator version to all workflow files.
#
# Usage:
#   ./strimzi/add-strimzi-version.sh <operator_version> <kafka_version> [kafka_version ...]
#
# Example:
#   ./strimzi/add-strimzi-version.sh 0.50.1 4.0.0 4.0.1 4.1.0 4.1.1
#
# What it does:
#   1. Pulls each quay.io/strimzi/kafka image to get the sha256 digest
#   2. Appends digest entries to STRIMZI_DIGESTS in all three workflow files
#   3. Adds the operator version to VERSION_MATRIX in strimzi-publish-signed.yml
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

WORKFLOW_FILES=(
  "$REPO_ROOT/.github/workflows/strimzi-development-build-and-test.yml"
  "$REPO_ROOT/.github/workflows/strimzi-build-and-test.yml"
  "$REPO_ROOT/.github/workflows/strimzi-publish-signed.yml"
)

PUBLISH_WORKFLOW="$REPO_ROOT/.github/workflows/strimzi-publish-signed.yml"

# --- Argument validation ---
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <operator_version> <kafka_version> [kafka_version ...]"
  echo "Example: $0 0.50.1 4.0.0 4.0.1 4.1.0 4.1.1"
  exit 1
fi

OPERATOR_VERSION="$1"
shift
KAFKA_VERSIONS=("$@")

echo "==> Adding Strimzi operator $OPERATOR_VERSION with Kafka versions: ${KAFKA_VERSIONS[*]}"
echo ""

# --- Check workflow files exist ---
for f in "${WORKFLOW_FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: Workflow file not found: $f"
    exit 1
  fi
done

# --- Check for duplicates ---
FIRST_KEY="${OPERATOR_VERSION}+${KAFKA_VERSIONS[0]}"
if grep -q "\"${FIRST_KEY}\"" "${WORKFLOW_FILES[0]}"; then
  echo "ERROR: Version $FIRST_KEY already exists in workflows. Aborting."
  exit 1
fi

# --- Pull images and collect digests ---
declare -A DIGESTS

for KAFKA_VERSION in "${KAFKA_VERSIONS[@]}"; do
  IMAGE="quay.io/strimzi/kafka:${OPERATOR_VERSION}-kafka-${KAFKA_VERSION}"
  echo "--- Pulling $IMAGE ..."

  if ! docker pull "$IMAGE" > /dev/null 2>&1; then
    echo "ERROR: Failed to pull $IMAGE"
    echo "Check that operator version $OPERATOR_VERSION with Kafka $KAFKA_VERSION exists at quay.io/strimzi/kafka"
    exit 1
  fi

  DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" | sed 's/.*@//')

  if [[ -z "$DIGEST" || "$DIGEST" == *"nil"* ]]; then
    echo "ERROR: Could not extract digest for $IMAGE"
    exit 1
  fi

  KEY="${OPERATOR_VERSION}+${KAFKA_VERSION}"
  DIGESTS["$KEY"]="$DIGEST"
  echo "    $KEY -> $DIGEST"
done

echo ""

# --- Build the new digest lines ---
# We insert them right before the closing "}" of STRIMZI_DIGESTS
NEW_LINES=""
LAST_IDX=$(( ${#KAFKA_VERSIONS[@]} - 1 ))
for i in "${!KAFKA_VERSIONS[@]}"; do
  KEY="${OPERATOR_VERSION}+${KAFKA_VERSIONS[$i]}"
  COMMA=","
  if [[ $i -eq $LAST_IDX ]]; then
    COMMA=""
  fi
  NEW_LINES+="      \"${KEY}\": \"${DIGESTS[$KEY]}\"${COMMA}\n"
done

# --- Update STRIMZI_DIGESTS in each workflow file ---
for f in "${WORKFLOW_FILES[@]}"; do
  echo "==> Updating digests in $(basename "$f")"

  # Find the last digest line before the closing brace.
  # The pattern: last line that has "sha256:" before the closing "}"
  # We add a comma to the last existing entry and append new lines.

  # Use python for reliable multi-line editing
  python3 - "$f" "$NEW_LINES" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
new_lines = sys.argv[2].replace("\\n", "\n")

with open(filepath, "r") as fh:
    content = fh.read()

# Find the STRIMZI_DIGESTS block - match the last sha256 line before closing brace
# Pattern: last "sha256:..." line followed by newline(s) and "    }"
pattern = r'("sha256:[a-f0-9]+")([\s]*\n)(    \})'
matches = list(re.finditer(pattern, content))

if not matches:
    print(f"  ERROR: Could not find STRIMZI_DIGESTS closing pattern in {filepath}")
    sys.exit(1)

# Use the last match (in case there are multiple JSON blocks)
match = matches[-1]

# Check if the last entry already has a trailing comma
before_match = content[:match.start(1)]
last_quote_and_value = match.group(1)

# Replace: add comma after last entry, insert new lines, keep closing brace
replacement = last_quote_and_value + ",\n" + new_lines.rstrip("\n") + "\n" + "    }"
new_content = content[:match.start(1)] + replacement + content[match.end(3):]

with open(filepath, "w") as fh:
    fh.write(new_content)

print("  Done.")
PYEOF
done

# --- Update VERSION_MATRIX in publish workflow ---
echo ""
echo "==> Updating VERSION_MATRIX in $(basename "$PUBLISH_WORKFLOW")"

# Build the kafka versions JSON array string
KAFKA_JSON_ARRAY="["
for i in "${!KAFKA_VERSIONS[@]}"; do
  if [[ $i -gt 0 ]]; then
    KAFKA_JSON_ARRAY+=", "
  fi
  KAFKA_JSON_ARRAY+="\"${KAFKA_VERSIONS[$i]}\""
done
KAFKA_JSON_ARRAY+="]"

python3 - "$PUBLISH_WORKFLOW" "$OPERATOR_VERSION" "$KAFKA_JSON_ARRAY" <<'PYEOF'
import sys, re

filepath = sys.argv[1]
operator_version = sys.argv[2]
kafka_json_array = sys.argv[3]

with open(filepath, "r") as fh:
    content = fh.read()

# Check if version already in VERSION_MATRIX
if f'"{operator_version}"' in content.split("STRIMZI_DIGESTS")[0]:
    print(f"  Version {operator_version} already in VERSION_MATRIX, skipping.")
    sys.exit(0)

# Insert new version entry at the top of VERSION_MATRIX (after the opening brace)
new_entry = (
    f'      "{operator_version}": {{\n'
    f'        "kafka_versions": {kafka_json_array},\n'
    f'        "axon_agent_version": "2.0.18"\n'
    f'      }},\n'
)

# Find VERSION_MATRIX opening brace
pattern = r'(VERSION_MATRIX: \|\s*\n\s*\{)\n'
match = re.search(pattern, content)
if not match:
    print("  ERROR: Could not find VERSION_MATRIX in publish workflow")
    sys.exit(1)

insert_pos = match.end()
new_content = content[:insert_pos] + new_entry + content[insert_pos:]

with open(filepath, "w") as fh:
    fh.write(new_content)

print("  Done.")
PYEOF

echo ""
echo "=== All done! ==="
echo ""
echo "New digests added for Strimzi $OPERATOR_VERSION:"
for KAFKA_VERSION in "${KAFKA_VERSIONS[@]}"; do
  KEY="${OPERATOR_VERSION}+${KAFKA_VERSION}"
  echo "  $KEY -> ${DIGESTS[$KEY]}"
done
echo ""
echo "Files modified:"
for f in "${WORKFLOW_FILES[@]}"; do
  echo "  $(basename "$f")"
done
echo ""
echo "Please review the changes with: git diff"
