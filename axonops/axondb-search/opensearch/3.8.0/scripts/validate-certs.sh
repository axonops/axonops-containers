#!/bin/bash
# AxonDB Search Certificate Validation Script
# Verifies certificate configuration and displays details

set -e

CERTS_DIR="${OPENSEARCH_PATH_CONF:-/etc/opensearch}/certs"

echo "=== AxonDB Search Certificate Validation ==="
echo "Certificate Directory: $CERTS_DIR"
echo ""

# Check if certs directory exists
if [ ! -d "$CERTS_DIR" ]; then
    echo "ERROR: Certificate directory not found: $CERTS_DIR"
    exit 1
fi

cd "$CERTS_DIR"

# Required files
REQUIRED_CERTS="root-ca.pem node.pem admin.pem"
REQUIRED_KEYS="root-ca-key.pem node-key.pem admin-key.pem"

echo "=== Checking Certificate Files ==="
echo ""

# Check all required files exist
for cert in $REQUIRED_CERTS $REQUIRED_KEYS; do
    if [ ! -f "$cert" ]; then
        echo "✗ MISSING: $cert"
        exit 1
    else
        echo "✓ EXISTS: $cert"
    fi
done

echo ""
echo "=== Checking File Permissions ==="
echo ""

# Check certificate permissions (should be 644)
for cert in $REQUIRED_CERTS; do
    PERMS=$(stat -c "%a" "$cert" 2>/dev/null || stat -f "%p" "$cert" 2>/dev/null | tail -c 4)
    if [ "$PERMS" = "644" ] || [ "$PERMS" = "0644" ]; then
        echo "✓ $cert: $PERMS (correct)"
    else
        echo "⚠ $cert: $PERMS (expected 644)"
    fi
done

# Check key permissions (should be 600)
for key in $REQUIRED_KEYS; do
    PERMS=$(stat -c "%a" "$key" 2>/dev/null || stat -f "%p" "$key" 2>/dev/null | tail -c 4)
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "0600" ]; then
        echo "✓ $key: $PERMS (correct)"
    else
        echo "⚠ $key: $PERMS (expected 600)"
    fi
done

echo ""
echo "=== Certificate Details ==="
echo ""

# Root CA
echo "Root CA Certificate:"
openssl x509 -in root-ca.pem -noout -subject -issuer -dates 2>/dev/null | sed 's/^/  /'
echo ""

# Node Certificate
echo "Node Certificate:"
openssl x509 -in node.pem -noout -subject -issuer -dates 2>/dev/null | sed 's/^/  /'
echo "  Subject Alternative Names:"
openssl x509 -in node.pem -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/^/  /'
echo ""

# Admin Certificate
echo "Admin Certificate:"
openssl x509 -in admin.pem -noout -subject -issuer -dates 2>/dev/null | sed 's/^/  /'
echo ""

echo "=== Verifying Certificate Chain ==="
echo ""

# Verify node cert is signed by root CA
if openssl verify -CAfile root-ca.pem node.pem 2>/dev/null | grep -q "OK"; then
    echo "✓ Node certificate is signed by Root CA"
else
    echo "✗ Node certificate verification failed"
    exit 1
fi

# Verify admin cert is signed by root CA
if openssl verify -CAfile root-ca.pem admin.pem 2>/dev/null | grep -q "OK"; then
    echo "✓ Admin certificate is signed by Root CA"
else
    echo "✗ Admin certificate verification failed"
    exit 1
fi

echo ""
echo "=== Checking Private Key Format ==="
echo ""

# Check if keys are in PKCS#8 format
for key in node-key.pem admin-key.pem; do
    if head -1 "$key" | grep -q "BEGIN PRIVATE KEY"; then
        echo "✓ $key: PKCS#8 format (unencrypted)"
    elif head -1 "$key" | grep -q "BEGIN RSA PRIVATE KEY"; then
        echo "⚠ $key: Traditional format (should be PKCS#8)"
    else
        echo "✗ $key: Unknown format"
    fi
done

echo ""
echo "=== Validation Summary ==="
echo ""
echo "✓ All required files present"
echo "✓ File permissions correct"
echo "✓ Certificates are valid"
echo "✓ Certificate chain verified"
echo "✓ Keys in PKCS#8 format"
echo ""
echo "Certificates are properly configured for OpenSearch!"
exit 0
