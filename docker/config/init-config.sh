#!/bin/bash
# Initialize axon-server configuration from template
# This script substitutes environment variables into the config template

set -e

TEMPLATE_FILE="/config/axon-server.yml.template"
OUTPUT_FILE="/etc/axonops/axon-server.yml"

# Ensure output directory exists
mkdir -p /etc/axonops

# Set defaults for optional variables
export AXONOPS_ORG_NAME="${AXONOPS_ORG_NAME:-example}"
export AXONOPS_LICENSE_KEY="${AXONOPS_LICENSE_KEY:-}"
export AXONOPS_DB_PASSWORD="${AXONOPS_DB_PASSWORD:-axonops}"
export AXONOPS_SEARCH_PASSWORD="${AXONOPS_SEARCH_PASSWORD:-MyS3cur3P@ss2025}"
export AXONOPS_CQL_SSL="${AXONOPS_CQL_SSL:-true}"

# Substitute environment variables in template
envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo "Configuration generated at $OUTPUT_FILE"

# Execute the main process (axon-server)
exec "$@"
