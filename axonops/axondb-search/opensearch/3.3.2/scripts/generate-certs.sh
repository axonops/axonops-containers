#!/bin/bash
set -e

# AxonDB Search Certificate Generation Script
# Generates self-signed PEM certificates with AxonOps branding during Docker build

echo "=== AxonDB Search Certificate Generation ==="
echo "Generating self-signed certificates with AxonOps branding..."
echo ""

# Configuration
CERTS_DIR="${OPENSEARCH_PATH_CONF:-/etc/opensearch}/certs"
VALIDITY_DAYS=1825  # 5 years
ORG="AxonOps"
ORG_UNIT="Database"
CN_ROOT="AxonOps Root CA"
CN_NODE="axondbsearch.axonops.com"
CN_ADMIN="admin.axondbsearch.axonops.com"

# Prefix for generated certificate files (makes them clearly identifiable as defaults)
FILE_PREFIX="axondbsearch-default-"

# Create certs directory
mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

echo "Certificate Directory: $CERTS_DIR"
echo "Organization: $ORG"
echo "Organizational Unit: $ORG_UNIT"
echo "Node CN: $CN_NODE"
echo "Validity: $VALIDITY_DAYS days (5 years)"
echo ""

# 1. Generate Root CA
echo "1. Generating Root CA..."
openssl req -x509 -newkey rsa:3072 -sha256 -days "$VALIDITY_DAYS" \
  -nodes -keyout ${FILE_PREFIX}root-ca-key.pem -out ${FILE_PREFIX}root-ca.pem \
  -subj "/CN=${CN_ROOT}/O=${ORG}/OU=${ORG_UNIT}" \
  2>/dev/null

if [ ! -f ${FILE_PREFIX}root-ca.pem ] || [ ! -f ${FILE_PREFIX}root-ca-key.pem ]; then
    echo "ERROR: Failed to generate root CA"
    exit 1
fi
echo "   ✓ Root CA generated: $CN_ROOT"
echo "   Files: ${FILE_PREFIX}root-ca.pem, ${FILE_PREFIX}root-ca-key.pem"

# 2. Generate Node Certificate
echo "2. Generating Node Certificate..."

# Create node CSR
openssl req -new -newkey rsa:3072 -sha256 -nodes \
  -keyout ${FILE_PREFIX}node-key-temp.pem -out ${FILE_PREFIX}node.csr \
  -subj "/CN=${CN_NODE}/O=${ORG}/OU=${ORG_UNIT}" \
  2>/dev/null

# Create SAN configuration for node certificate
cat > node-san.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${CN_NODE}
DNS.2 = localhost
DNS.3 = *.axondbsearch.axonops.com
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# Sign node certificate with Root CA
openssl x509 -req -in node.csr -CA ${FILE_PREFIX}root-ca.pem -CAkey ${FILE_PREFIX}root-ca-key.pem \
  -CAcreateserial -out ${FILE_PREFIX}node.pem -days "$VALIDITY_DAYS" \
  -extensions v3_req -extfile node-san.cnf \
  2>/dev/null

# Convert key to PKCS#8 format (required by OpenSearch)
openssl pkcs8 -topk8 -inform PEM -outform PEM -in node-key-temp.pem \
  -out ${FILE_PREFIX}node-key.pem -nocrypt

# Cleanup
rm -f node.csr node-key-temp.pem node-san.cnf

if [ ! -f ${FILE_PREFIX}node.pem ] || [ ! -f ${FILE_PREFIX}node-key.pem ]; then
    echo "ERROR: Failed to generate node certificate"
    exit 1
fi
echo "   ✓ Node certificate generated: $CN_NODE"

# 3. Generate Admin Client Certificate (for securityadmin tool)
echo "3. Generating Admin Client Certificate..."

# Create admin CSR
openssl req -new -newkey rsa:3072 -sha256 -nodes \
  -keyout admin-key-temp.pem -out admin.csr \
  -subj "/CN=${CN_ADMIN}/O=${ORG}/OU=${ORG_UNIT}" \
  2>/dev/null

# Sign admin certificate with Root CA
openssl x509 -req -in admin.csr -CA ${FILE_PREFIX}root-ca.pem -CAkey ${FILE_PREFIX}root-ca-key.pem \
  -CAcreateserial -out ${FILE_PREFIX}admin.pem -days "$VALIDITY_DAYS" \
  2>/dev/null

# Convert key to PKCS#8 format
openssl pkcs8 -topk8 -inform PEM -outform PEM -in admin-key-temp.pem \
  -out ${FILE_PREFIX}admin-key.pem -nocrypt

# Cleanup
rm -f admin.csr admin-key-temp.pem root-ca.srl

if [ ! -f ${FILE_PREFIX}admin.pem ] || [ ! -f ${FILE_PREFIX}admin-key.pem ]; then
    echo "ERROR: Failed to generate admin certificate"
    exit 1
fi
echo "   ✓ Admin certificate generated: $CN_ADMIN"

echo ""
echo "=== Setting Permissions ==="

# Set permissions
chmod 644 ${FILE_PREFIX}root-ca.pem ${FILE_PREFIX}node.pem ${FILE_PREFIX}admin.pem
chmod 600 ${FILE_PREFIX}root-ca-key.pem ${FILE_PREFIX}node-key.pem ${FILE_PREFIX}admin-key.pem

# Set ownership (if running as root during build)
if [ "$(id -u)" = "0" ] && command -v chown >/dev/null 2>&1; then
    chown opensearch:opensearch *.pem 2>/dev/null || true
fi

echo "   ✓ Permissions set (644 for certs, 600 for keys)"
echo ""

# Validate all files exist
echo "=== Validating Certificate Generation ==="
REQUIRED_FILES="${FILE_PREFIX}root-ca.pem ${FILE_PREFIX}root-ca-key.pem ${FILE_PREFIX}node.pem ${FILE_PREFIX}node-key.pem ${FILE_PREFIX}admin.pem ${FILE_PREFIX}admin-key.pem"
for file in $REQUIRED_FILES; do
    if [ ! -f "$file" ]; then
        echo "ERROR: Required file missing: $file"
        exit 1
    fi
    echo "   ✓ $file"
done

echo ""
echo "=== Certificate Generation Complete ==="
echo "Location: $CERTS_DIR"
echo "Files generated: 6 PEM files (3 certificates + 3 keys)"
echo ""

# Display certificate details
echo "=== Certificate Details ==="
echo ""
echo "Root CA:"
openssl x509 -in ${FILE_PREFIX}root-ca.pem -noout -subject -dates 2>/dev/null | sed 's/^/   /'

echo ""
echo "Node Certificate:"
openssl x509 -in ${FILE_PREFIX}node.pem -noout -subject -dates 2>/dev/null | sed 's/^/   /'
echo "   Subject Alternative Names:"
openssl x509 -in ${FILE_PREFIX}node.pem -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/^/   /'

echo ""
echo "Admin Certificate:"
openssl x509 -in ${FILE_PREFIX}admin.pem -noout -subject -dates 2>/dev/null | sed 's/^/   /'

echo ""
echo "✓ All certificates generated successfully"
exit 0
