#!/bin/bash
set -e

# AxonDB Search Initialization Script
# Handles security configuration and custom admin user creation
# Runs in background, coordinated via semaphore files

echo "=== AxonDB Search Initialization Script ==="
echo "Starting at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Semaphore files for healthcheck coordination
# Located in /var/lib/opensearch (persistent volume) to survive container restarts
OPENSEARCH_HOME="${OPENSEARCH_HOME:-/opt/opensearch}"
OPENSEARCH_DATA_DIR="${OPENSEARCH_DATA_DIR:-/var/lib/opensearch}"
OPENSEARCH_PATH_CONF="${OPENSEARCH_PATH_CONF:-/etc/opensearch}"
SEMAPHORE_DIR="${OPENSEARCH_DATA_DIR}/.axonops"
SEMAPHORE_FILE="${SEMAPHORE_DIR}/init-security.done"

# Configuration
HTTP_PORT="${OPENSEARCH_HTTP_PORT:-9200}"
INIT_TIMEOUT="${INIT_TIMEOUT:-600}"  # Configurable timeout (default: 10 minutes)
DISABLE_SECURITY_PLUGIN="${DISABLE_SECURITY_PLUGIN:-false}"

# TLS/SSL settings
AXONOPS_SEARCH_TLS_ENABLED="${AXONOPS_SEARCH_TLS_ENABLED:-true}"
if [ "$AXONOPS_SEARCH_TLS_ENABLED" = "false" ]; then
    PROTOCOL="http"
else
    PROTOCOL="https"
fi

# Admin user credentials
AXONOPS_SEARCH_USER="${AXONOPS_SEARCH_USER}"
AXONOPS_SEARCH_PASSWORD="${AXONOPS_SEARCH_PASSWORD}"

# Function to write semaphore file
write_semaphore() {
    local result="$1"
    local reason="$2"

    mkdir -p "$SEMAPHORE_DIR"
    {
        echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "RESULT=${result}"
        echo "REASON=${reason}"
        if [ -n "$AXONOPS_SEARCH_USER" ]; then
            echo "ADMIN_USER=${AXONOPS_SEARCH_USER}"
        fi
    } > "$SEMAPHORE_FILE"

    echo "✓ Semaphore written: ${SEMAPHORE_FILE}"
    echo "  RESULT=${result}"
    echo "  REASON=${reason}"
}

# Check if security plugin is disabled
if [ "$DISABLE_SECURITY_PLUGIN" = "true" ]; then
    echo "ℹ Security plugin is disabled (DISABLE_SECURITY_PLUGIN=true)"
    echo "  Skipping all security initialization"
    write_semaphore "skipped" "security_plugin_disabled"
    exit 0
fi

# Check if already initialized (semaphore exists and successful)
if [ -f "$SEMAPHORE_FILE" ]; then
    PREV_RESULT=$(grep "^RESULT=" "$SEMAPHORE_FILE" | cut -d'=' -f2)
    if [ "$PREV_RESULT" = "success" ] || [ "$PREV_RESULT" = "skipped" ]; then
        echo "ℹ Initialization already completed on previous run"
        echo "  Previous result: $PREV_RESULT"
        echo "  Skipping re-initialization (persistent volume detected)"
        exit 0
    fi
fi

echo "Waiting for OpenSearch HTTP API to be ready..."
echo "  Port: $HTTP_PORT"
echo "  Timeout: ${INIT_TIMEOUT}s"
echo ""

# Wait for HTTP port to be listening
ELAPSED=0
while ! nc -z localhost "$HTTP_PORT" 2>/dev/null; do
    if [ $ELAPSED -gt $INIT_TIMEOUT ]; then
        echo "⚠ ERROR: HTTP port did not open within ${INIT_TIMEOUT}s"
        echo "  This is a fatal error - OpenSearch should have started by now"
        echo "  Increase INIT_TIMEOUT env var if OpenSearch needs more time to start"
        write_semaphore "failed" "http_port_timeout"
        exit 1
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ $((ELAPSED % 30)) -eq 0 ]; then
        echo "  Waiting... ${ELAPSED}s / ${INIT_TIMEOUT}s"
    fi
done

echo "✓ HTTP port $HTTP_PORT is listening"
echo ""

# Wait for cluster to be responsive
echo "Waiting for OpenSearch cluster to be responsive..."
ELAPSED=0
while true; do
    # Try to get cluster health (may fail initially)
    # Use HTTP or HTTPS based on TLS setting
    if timeout 5 curl -s --insecure -u admin:MyS3cur3P@ss2025 -XGET "${PROTOCOL}://localhost:${HTTP_PORT}/_cluster/health" >/dev/null 2>&1; then
        echo "✓ OpenSearch cluster is responsive"
        break
    fi

    if [ $ELAPSED -gt $INIT_TIMEOUT ]; then
        echo "⚠ ERROR: Cluster did not become responsive within ${INIT_TIMEOUT}s"
        write_semaphore "failed" "cluster_not_responsive"
        exit 1
    fi

    sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ $((ELAPSED % 30)) -eq 0 ]; then
        echo "  Waiting... ${ELAPSED}s / ${INIT_TIMEOUT}s"
    fi
done

echo ""

# Verify AxonOps SSL certificates exist (generated during build)
echo "=== Verifying Security Configuration ==="
CERT_FILES="root-ca.pem node.pem node-key.pem admin.pem admin-key.pem"
for cert in $CERT_FILES; do
    if [ ! -f "${OPENSEARCH_PATH_CONF}/certs/${cert}" ]; then
        echo "⚠ ERROR: Certificate not found: ${OPENSEARCH_PATH_CONF}/certs/${cert}"
        write_semaphore "failed" "certificates_missing"
        exit 1
    fi
done

if [ ! -f "${OPENSEARCH_PATH_CONF}/opensearch-security/config.yml" ]; then
    echo "⚠ ERROR: Security configuration not found!"
    echo "  Expected: ${OPENSEARCH_PATH_CONF}/opensearch-security/config.yml"
    write_semaphore "failed" "security_config_missing"
    exit 1
fi
echo "✓ AxonOps SSL certificates verified (axondbsearch.axonops.com)"
echo "✓ Security configuration verified"
echo ""

# Check if custom admin user creation is requested
if [ -n "$AXONOPS_SEARCH_USER" ] && [ -n "$AXONOPS_SEARCH_PASSWORD" ]; then
    echo "=== Custom Admin User Creation ==="
    echo "  Username: $AXONOPS_SEARCH_USER"
    echo ""

    # Check if TLS is enabled (required for securityadmin tool)
    if [ "$AXONOPS_SEARCH_TLS_ENABLED" = "false" ]; then
        echo "⚠ WARNING: Cannot create custom user when TLS is disabled"
        echo "  The securityadmin tool requires TLS/HTTPS to apply security configuration"
        echo "  Please either:"
        echo "    1. Enable TLS (AXONOPS_SEARCH_TLS_ENABLED=true) to create custom users"
        echo "    2. Use the default admin user (admin / MyS3cur3P@ss2025)"
        echo "    3. Create users manually via OpenSearch REST API after startup"
        echo ""
        write_semaphore "skipped" "tls_disabled_no_securityadmin"
        exit 0
    fi

    # Generate password hash
    echo "Generating password hash for user..."
    HASH_OUTPUT=$(cd "${OPENSEARCH_HOME}" && bash "${OPENSEARCH_HOME}/plugins/opensearch-security/tools/hash.sh" -p "$AXONOPS_SEARCH_PASSWORD")
    PASSWORD_HASH=$(echo "$HASH_OUTPUT" | tail -1)

    if [ -z "$PASSWORD_HASH" ]; then
        echo "⚠ ERROR: Failed to generate password hash"
        write_semaphore "failed" "password_hash_failed"
        exit 1
    fi

    echo "✓ Password hash generated"

    # Update internal_users.yml to add custom admin user
    INTERNAL_USERS_FILE="${OPENSEARCH_PATH_CONF}/opensearch-security/internal_users.yml"

    echo "Creating custom admin user in internal_users.yml..."
    cat >> "$INTERNAL_USERS_FILE" <<EOF

# AxonOps custom admin user
${AXONOPS_SEARCH_USER}:
  hash: "${PASSWORD_HASH}"
  reserved: true
  backend_roles:
  - "admin"
  description: "AxonOps admin user created via AXONOPS_SEARCH_USER"
EOF

    echo "✓ Custom admin user added to internal_users.yml"

    # Apply security configuration using securityadmin
    echo "Applying security configuration..."
    cd "${OPENSEARCH_HOME}"

    # Wait a bit for OpenSearch to be fully ready for security admin
    sleep 5

    if bash "${OPENSEARCH_HOME}/plugins/opensearch-security/tools/securityadmin.sh" \
        -cd "${OPENSEARCH_PATH_CONF}/opensearch-security" \
        -icl -nhnv \
        -cacert "${OPENSEARCH_PATH_CONF}/certs/root-ca.pem" \
        -cert "${OPENSEARCH_PATH_CONF}/certs/admin.pem" \
        -key "${OPENSEARCH_PATH_CONF}/certs/admin-key.pem" \
        -h localhost; then
        echo "✓ Security configuration applied successfully"
        echo ""
        echo "=== Admin User Created ==="
        echo "  Username: ${AXONOPS_SEARCH_USER}"
        echo "  Password: [provided via AXONOPS_SEARCH_PASSWORD]"
        echo ""
        echo "⚠ IMPORTANT: The default 'admin' user is still active"
        echo "  For production, disable the default admin user after confirming"
        echo "  your custom admin user works correctly."
        echo ""

        write_semaphore "success" "custom_admin_user_created"
        exit 0
    else
        echo "⚠ ERROR: Failed to apply security configuration"
        write_semaphore "failed" "securityadmin_failed"
        exit 1
    fi
else
    echo "=== Security Initialization Complete ==="
    echo "  No custom admin user requested (AXONOPS_SEARCH_USER not set)"
    echo "  Security plugin is enabled with demo SSL configuration"
    echo ""
    echo "⚠ WARNING: Using default 'admin' user with default password"
    echo "  Default credentials: admin / admin"
    echo ""
    echo "ℹ RECOMMENDATION: Provide AXONOPS_SEARCH_USER and AXONOPS_SEARCH_PASSWORD"
    echo "  for production deployments to create a custom admin user."
    echo ""

    write_semaphore "success" "default_demo_config"
    exit 0
fi
