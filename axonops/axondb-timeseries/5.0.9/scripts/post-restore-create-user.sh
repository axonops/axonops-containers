#!/bin/bash
set -euo pipefail

# ============================================================================
# Post-Restore User Creation Script
# Purpose: Create custom user after credential reset (simple, no keyspace ALTERs)
# ============================================================================
# Called by cassandra-wrapper.sh after restore with credential reset
# Only creates custom user if AXONOPS_DB_USER is set
# Does NOT alter keyspaces (already NTS from restore)
# Does NOT check single-node (we're restoring, not fresh cluster)

SCRIPT_NAME=$(basename "$0" .sh)

log() {
    echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] [${SCRIPT_NAME}] $*"
}

log "Post-restore user creation starting"

# Check if custom user requested
if [ -z "${AXONOPS_DB_USER:-}" ] || [ -z "${AXONOPS_DB_PASSWORD:-}" ]; then
    log "No custom user requested (AXONOPS_DB_USER not set)"
    log "Using default cassandra/cassandra credentials"
    exit 0
fi

log "Custom user requested: ${AXONOPS_DB_USER}"

# Wait for Cassandra to be ready (CQL port listening and responsive)
log "Waiting for Cassandra to be ready..."

MAX_WAIT=180
ELAPSED=0
until echo "SELECT cluster_name FROM system.local;" | cqlsh -u cassandra -p cassandra >/dev/null 2>&1; do
    if [ $ELAPSED -ge $MAX_WAIT ]; then
        log "ERROR: Cassandra not ready after ${MAX_WAIT}s"
        exit 1
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

log "✓ Cassandra ready (${ELAPSED}s)"

# Create custom user
log "Creating custom user: ${AXONOPS_DB_USER}"

if cqlsh -u cassandra -p cassandra -e "CREATE ROLE IF NOT EXISTS '${AXONOPS_DB_USER}' WITH PASSWORD = '${AXONOPS_DB_PASSWORD}' AND SUPERUSER = true AND LOGIN = true;" 2>&1; then
    log "✓ Custom user created"
else
    log "ERROR: Failed to create custom user"
    exit 1
fi

# Test custom user credentials
log "Testing custom user credentials..."

if cqlsh -u "${AXONOPS_DB_USER}" -p "${AXONOPS_DB_PASSWORD}" -e "SELECT cluster_name FROM system.local;" >/dev/null 2>&1; then
    log "✓ Custom user authentication works"
else
    log "ERROR: Custom user authentication failed"
    # Rollback
    cqlsh -u cassandra -p cassandra -e "DROP ROLE IF EXISTS '${AXONOPS_DB_USER}';" 2>&1 || true
    exit 1
fi

# Disable default cassandra user
log "Disabling default cassandra user..."

if cqlsh -u cassandra -p cassandra -e "ALTER ROLE cassandra WITH LOGIN = false;" 2>&1; then
    log "✓ Default cassandra user disabled"
else
    log "WARNING: Failed to disable cassandra user"
fi

log "✓ Post-restore user creation completed"
log "  User: ${AXONOPS_DB_USER}"
log "  Default cassandra user: disabled"
