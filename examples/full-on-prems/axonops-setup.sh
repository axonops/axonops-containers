#!/usr/bin/env bash
# Deploy AxonOps on-premises services with local storage
# This script deploys cert-manager, AxonOps Timeseries DB, Search DB, Server, and Dashboard

set -euo pipefail

############################################
# PARAMETER SECTION
############################################

# --- Global / Common ---
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
HELM_BIN="${HELM_BIN:-helm}"

# --- Namespaces ---
NS_CERT_MANAGER="${NS_CERT_MANAGER:-cert-manager}"
NS_AXONOPS="${NS_AXONOPS:-axonops}"

# --- cert-manager installation ---
CERT_MANAGER_RELEASE_NAME="${CERT_MANAGER_RELEASE_NAME:-cert-manager}"
CERT_MANAGER_CHART_REPO="${CERT_MANAGER_CHART_REPO:-oci://quay.io/jetstack/charts/cert-manager}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.19.1}"
CERT_MANAGER_CRDS_ENABLED="${CERT_MANAGER_CRDS_ENABLED:-true}"

# --- cert-manager ClusterIssuer ---
CLUSTER_ISSUER_NAME="${CLUSTER_ISSUER_NAME:-selfsigned-cluster-issuer}"
CLUSTER_ISSUER_KIND="${CLUSTER_ISSUER_KIND:-ClusterIssuer}"
CLUSTER_ISSUER_API_VERSION="${CLUSTER_ISSUER_API_VERSION:-cert-manager.io/v1}"

# --- AxonOps Timeseries DB (Cassandra) ---
AXON_TIMESERIES_RELEASE_NAME="${AXON_TIMESERIES_RELEASE_NAME:-axondb-timeseries}"
AXON_TIMESERIES_CHART="${AXON_TIMESERIES_CHART:-oci://ghcr.io/axonops/charts/axondb-timeseries}"
AXON_TIMESERIES_VALUES_FILE="${AXON_TIMESERIES_VALUES_FILE:-timeseries-values.yaml}"
AXON_TIMESERIES_HEAP_SIZE="${AXON_TIMESERIES_HEAP_SIZE:-2048M}"
AXON_TIMESERIES_TLS_ENABLED="${AXON_TIMESERIES_TLS_ENABLED:-true}"
AXON_TIMESERIES_CERTMANAGER_ENABLED="${AXON_TIMESERIES_CERTMANAGER_ENABLED:-true}"
AXON_TIMESERIES_CERT_ISSUER_NAME="${AXON_TIMESERIES_CERT_ISSUER_NAME:-$CLUSTER_ISSUER_NAME}"
AXON_TIMESERIES_PERSISTENCE_ENABLED="${AXON_TIMESERIES_PERSISTENCE_ENABLED:-false}"
AXON_TIMESERIES_USE_HOSTPATH="${AXON_TIMESERIES_USE_HOSTPATH:-false}"
AXON_TIMESERIES_STORAGE_CLASS="${AXON_TIMESERIES_STORAGE_CLASS:-}"
# unless using hostPath, set up the volume size
AXON_TIMESEARCH_VOLUME_SIZE="${AXON_TIMESEARCH_VOLUME_SIZE:-10Gi}"
AXON_TIMESERIES_HOSTPATH_DIR="${AXON_TIMESERIES_HOSTPATH_DIR:-/data/axon-timeseries}"
AXON_TIMESERIES_HOST_UID="${AXON_TIMESERIES_HOST_UID:-999}"
AXON_TIMESERIES_HOST_GID="${AXON_TIMESERIES_HOST_GID:-999}"
AXON_TIMESERIES_CONTAINER_MOUNT_PATH="${AXON_TIMESERIES_CONTAINER_MOUNT_PATH:-/var/lib/cassandra}"
AXON_TIMESERIES_RES_REQ_CPU="${AXON_TIMESERIES_RES_REQ_CPU:-1001m}"
AXON_TIMESERIES_RES_REQ_MEM="${AXON_TIMESERIES_RES_REQ_MEM:-2Gi}"
AXON_TIMESERIES_RES_LIMIT_CPU="${AXON_TIMESERIES_RES_LIMIT_CPU:-2000m}"
AXON_TIMESERIES_RES_LIMIT_MEM="${AXON_TIMESERIES_RES_LIMIT_MEM:-4Gi}"
AXON_TIMESERIES_HELM_EXTRA_ARGS="${AXON_TIMESERIES_HELM_EXTRA_ARGS:-}"

# --- AxonOps Search DB (OpenSearch) ---
AXON_SEARCH_RELEASE_NAME="${AXON_SEARCH_RELEASE_NAME:-axondb-search}"
AXON_SEARCH_CHART="${AXON_SEARCH_CHART:-oci://ghcr.io/axonops/charts/axondb-search}"
AXON_SEARCH_VALUES_FILE="${AXON_SEARCH_VALUES_FILE:-search-values.yaml}"
AXON_SEARCH_HEAP_SIZE="${AXON_SEARCH_HEAP_SIZE:-2g}"
AXON_SEARCH_PERSISTENCE_ENABLED="${AXON_SEARCH_PERSISTENCE_ENABLED:-false}"
AXON_SEARCH_USE_HOSTPATH="${AXON_SEARCH_USE_HOSTPATH:-false}"
AXON_SEARCH_HOSTPATH_DIR="${AXON_SEARCH_HOSTPATH_DIR:-/data/axon-search}"
AXON_SEARCH_STORAGE_CLASS="${AXON_SEARCH_STORAGE_CLASS:-}"
AXON_SEARCH_VOLUME_SIZE="${AXON_SEARCH_VOLUME_SIZE:-10Gi}"
AXON_SEARCH_HOST_UID="${AXON_SEARCH_HOST_UID:-999}"
AXON_SEARCH_HOST_GID="${AXON_SEARCH_HOST_GID:-999}"
AXON_SEARCH_CONTAINER_MOUNT_PATH="${AXON_SEARCH_CONTAINER_MOUNT_PATH:-/var/lib/opensearch}"
AXON_SEARCH_TLS_ENABLED="${AXON_SEARCH_TLS_ENABLED:-true}"
AXON_SEARCH_CERTMANAGER_ENABLED="${AXON_SEARCH_CERTMANAGER_ENABLED:-true}"
AXON_SEARCH_CERT_ISSUER_NAME="${AXON_SEARCH_CERT_ISSUER_NAME:-$CLUSTER_ISSUER_NAME}"
AXON_SEARCH_HELM_EXTRA_ARGS="${AXON_SEARCH_HELM_EXTRA_ARGS:-}"
AXON_SEARCH_USER="${AXON_SEARCH_USER:-admin}"
# IMPORTANT: Set this environment variable before running the script for security
AXON_SEARCH_PASSWORD="${AXON_SEARCH_PASSWORD:-}"

# --- AxonOps Server Secret and Helm release ---
AXON_SERVER_SECRET_NAME="${AXON_SERVER_SECRET_NAME:-axon-server-config}"
AXON_SERVER_RELEASE_NAME="${AXON_SERVER_RELEASE_NAME:-axon-server}"
AXON_SERVER_CHART="${AXON_SERVER_CHART:-oci://ghcr.io/axonops/charts/axon-server}"
AXON_SERVER_CONFIG_FILE="${AXON_SERVER_CONFIG_FILE:-axonops-server-secret.yaml}"
AXON_SERVER_AGENTS_PORT="${AXON_SERVER_AGENTS_PORT:-1888}"
AXON_SERVER_API_PORT="${AXON_SERVER_API_PORT:-8080}"
AXON_SERVER_HOST="${AXON_SERVER_HOST:-0.0.0.0}"

# Search DB connection from Axon Server
AXON_SERVER_SEARCH_DB_HOST_URL="${AXON_SERVER_SEARCH_DB_HOST_URL:-https://axondb-search-cluster-master.$NS_AXONOPS.svc.cluster.local:9200}"
AXON_SERVER_SEARCH_DB_SKIP_VERIFY="${AXON_SERVER_SEARCH_DB_SKIP_VERIFY:-true}"

# AxonOps org and dashboard URL
AXON_SERVER_ORG_NAME="${AXON_SERVER_ORG_NAME:-example}"
AXON_SERVER_DASH_URL="${AXON_SERVER_DASH_URL:-https://axonops.example.com}"

# CQL / Cassandra configuration
AXON_SERVER_CQL_HOSTS="${AXON_SERVER_CQL_HOSTS:-axondb-timeseries-headless.$NS_AXONOPS.svc.cluster.local}"
AXON_SERVER_CQL_PASSWORD="${AXON_SERVER_CQL_PASSWORD:-cassandra}"
AXON_SERVER_CQL_USERNAME="${AXON_SERVER_CQL_USERNAME}"

AXON_SERVER_CQL_LOCAL_DC="${AXON_SERVER_CQL_LOCAL_DC:-axonopsdb_dc1}"
AXON_SERVER_CQL_REPLICATION="${AXON_SERVER_CQL_REPLICATION:-{ \"class\": \"NetworkTopologyStrategy\", \"axonopsdb_dc1\": 1 }}"
AXON_SERVER_CQL_SSL_ENABLED="${AXON_SERVER_CQL_SSL_ENABLED:-true}"
AXON_SERVER_CQL_SKIP_VERIFY="${AXON_SERVER_CQL_SKIP_VERIFY:-true}"
AXON_SERVER_TLS_MODE="${AXON_SERVER_TLS_MODE:-disabled}"
AXON_SERVER_AUTH_ENABLED="${AXON_SERVER_AUTH_ENABLED:-false}"

AXON_SERVER_HELM_EXTRA_ARGS="${AXON_SERVER_HELM_EXTRA_ARGS:-}"

# --- AxonOps Dashboard (axon-dash) ---
AXON_DASH_RELEASE_NAME="${AXON_DASH_RELEASE_NAME:-axon-dash}"
AXON_DASH_CHART="${AXON_DASH_CHART:-oci://ghcr.io/axonops/charts/axon-dash}"
AXON_DASH_VALUES_FILE="${AXON_DASH_VALUES_FILE:-axonops-dash-values.yaml}"
AXON_DASH_AXON_SERVER_URL="${AXON_DASH_AXON_SERVER_URL:-http://axon-server-api.$NS_AXONOPS.svc.cluster.local:$AXON_SERVER_API_PORT}"

# Service configuration
AXON_DASH_SERVICE_TYPE="${AXON_DASH_SERVICE_TYPE:-ClusterIP}"
AXON_DASH_SERVICE_PORT="${AXON_DASH_SERVICE_PORT:-3000}"
# For NodePort (optional)
AXON_DASH_NODEPORT_ENABLED="${AXON_DASH_NODEPORT_ENABLED:-false}"
AXON_DASH_NODEPORT_PORT="${AXON_DASH_NODEPORT_PORT:-32000}"

# Ingress configuration
AXON_DASH_INGRESS_ENABLED="${AXON_DASH_INGRESS_ENABLED:-false}"
AXON_DASH_INGRESS_CLASS_NAME="${AXON_DASH_INGRESS_CLASS_NAME:-}"
AXON_DASH_INGRESS_HOST="${AXON_DASH_INGRESS_HOST:-axonops.mycompany.com}"
AXON_DASH_INGRESS_TLS_SECRET_NAME="${AXON_DASH_INGRESS_TLS_SECRET_NAME:-axon-dash-tls}"
AXON_DASH_INGRESS_CERT_ISSUER_ANNOTATION="${AXON_DASH_INGRESS_CERT_ISSUER_ANNOTATION:-$CLUSTER_ISSUER_NAME}"

AXON_DASH_HELM_EXTRA_ARGS="${AXON_DASH_HELM_EXTRA_ARGS:-}"

############################################
# Helper functions
############################################

info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*"; }
error() { echo "[ERROR] $*" >&2; }

############################################
# 1. Install cert-manager and ClusterIssuer
############################################
install_cert_manager() {
  info "Checking if cert-manager is already installed..."

  if $KUBECTL_BIN get namespace "$NS_CERT_MANAGER" &>/dev/null; then
    info "cert-manager namespace exists, checking deployment..."
    if $KUBECTL_BIN get deployment -n "$NS_CERT_MANAGER" cert-manager &>/dev/null; then
      info "cert-manager is already installed, skipping installation"
      return 0
    fi
  fi

  info "Installing cert-manager in namespace '$NS_CERT_MANAGER'..."

  $HELM_BIN upgrade --install \
    "$CERT_MANAGER_RELEASE_NAME" "$CERT_MANAGER_CHART_REPO" \
    --version "$CERT_MANAGER_VERSION" \
    --namespace "$NS_CERT_MANAGER" \
    --create-namespace \
    --wait \
    --set "crds.enabled=${CERT_MANAGER_CRDS_ENABLED}"

  info "Waiting for cert-manager to be ready..."
  $KUBECTL_BIN wait --for=condition=ready pod \
    --all -n "$NS_CERT_MANAGER" \
    --timeout=120s

  info "Creating self-signed ClusterIssuer '$CLUSTER_ISSUER_NAME'..."

  cat <<EOF | $KUBECTL_BIN apply -f -
apiVersion: ${CLUSTER_ISSUER_API_VERSION}
kind: ${CLUSTER_ISSUER_KIND}
metadata:
  name: ${CLUSTER_ISSUER_NAME}
spec:
  selfSigned: {}
EOF
}

############################################
# 2. AxonOps Timeseries DB
############################################
prepare_timeseries_hostpath() {
  if [[ "$AXON_TIMESERIES_USE_HOSTPATH" != "true" ]]; then
    info "Skipping hostPath directory preparation for AxonOps Timeseries DB as AXON_TIMESERIES_USE_HOSTPATH is not set to 'true'"
    return 0
  fi
  info "Preparing hostPath directory for AxonOps Timeseries DB: $AXON_TIMESERIES_HOSTPATH_DIR"
  sudo mkdir -p "$AXON_TIMESERIES_HOSTPATH_DIR"
  sudo chown -R "${AXON_TIMESERIES_HOST_UID}:${AXON_TIMESERIES_HOST_GID}" "$AXON_TIMESERIES_HOSTPATH_DIR"
}

generate_timeseries_values() {
  info "Generating $AXON_TIMESERIES_VALUES_FILE..."
  cat > "$AXON_TIMESERIES_VALUES_FILE" <<EOF
heapSize: ${AXON_TIMESERIES_HEAP_SIZE}

authentication:
  db_user: "${AXON_SERVER_CQL_USERNAME}"
  db_password: "${AXON_SERVER_CQL_PASSWORD}"

tls:
  enabled: ${AXON_TIMESERIES_TLS_ENABLED}
  certManager:
    enabled: ${AXON_TIMESERIES_CERTMANAGER_ENABLED}
    issuer:
      name: ${AXON_TIMESERIES_CERT_ISSUER_NAME}
resources:
  requests:
    cpu: ${AXON_TIMESERIES_RES_REQ_CPU}
    memory: ${AXON_TIMESERIES_RES_REQ_MEM}
  limits:
    cpu: ${AXON_TIMESERIES_RES_LIMIT_CPU}
    memory: ${AXON_TIMESERIES_RES_LIMIT_MEM}
EOF
if [[ "$AXON_TIMESERIES_USE_HOSTPATH" == "true" ]]; then
  cat >> "$AXON_TIMESERIES_VALUES_FILE" <<EOF
persistence:
  enabled: false

extraVolumes:
  - name: timeseries-data
    hostPath:
      path: ${AXON_TIMESERIES_HOSTPATH_DIR}
      type: DirectoryOrCreate
extraVolumeMounts:
  - name: timeseries-data
    mountPath: ${AXON_TIMESERIES_CONTAINER_MOUNT_PATH}
EOF
else
  cat >> "$AXON_TIMESERIES_VALUES_FILE" <<EOF
persistence:
  enabled: ${AXON_TIMESERIES_PERSISTENCE_ENABLED}
  enableInitChown: true
  storageClass: "${AXON_TIMESERIES_STORAGE_CLASS}"
  accessMode: ReadWriteOnce
  size: ${AXON_TIMESEARCH_VOLUME_SIZE}
  # existingClaim: ""
  annotations: {}
EOF
fi
}

install_timeseries_db() {
  info "Installing AxonOps Timeseries DB (Helm release: $AXON_TIMESERIES_RELEASE_NAME)..."

  $HELM_BIN upgrade --install "$AXON_TIMESERIES_RELEASE_NAME" "$AXON_TIMESERIES_CHART" \
    --namespace "$NS_AXONOPS" \
    --create-namespace \
    --wait \
    -f "$AXON_TIMESERIES_VALUES_FILE" \
    $AXON_TIMESERIES_HELM_EXTRA_ARGS
}

############################################
# 3. AxonOps Search DB
############################################
prepare_search_hostpath() {
  if [[ "$AXON_SEARCH_USE_HOSTPATH" != "true" ]]; then
    info "Skipping hostPath directory preparation for AxonOps Search DB as AXON_SEARCH_USE_HOSTPATH is not set to 'true'"
    return 0
  fi
  info "Preparing hostPath directory for AxonOps Search DB: $AXON_SEARCH_HOSTPATH_DIR"
  sudo mkdir -p "$AXON_SEARCH_HOSTPATH_DIR"
  sudo chown -R "${AXON_SEARCH_HOST_UID}:${AXON_SEARCH_HOST_GID}" "$AXON_SEARCH_HOSTPATH_DIR"
}

generate_search_values() {
  info "Generating $AXON_SEARCH_VALUES_FILE..."
  cat > "$AXON_SEARCH_VALUES_FILE" <<EOF
opensearchHeapSize: "${AXON_SEARCH_HEAP_SIZE}"

authentication:
  opensearch_user: "${AXON_SEARCH_USER}"
  opensearch_password: "${AXON_SEARCH_PASSWORD}"

tls:
  enabled: ${AXON_SEARCH_TLS_ENABLED}
  certManager:
    enabled: ${AXON_SEARCH_CERTMANAGER_ENABLED}
    issuer:
      name: ${AXON_SEARCH_CERT_ISSUER_NAME}
EOF
  if [[ "$AXON_SEARCH_USE_HOSTPATH" == "true" ]]; then
    cat >> "$AXON_SEARCH_VALUES_FILE" <<EOF
persistence:
  enabled: false

extraVolumes:
  - name: data
    hostPath:
      path: ${AXON_SEARCH_HOSTPATH_DIR}
      type: DirectoryOrCreate

extraVolumeMounts:
  - name: data
    mountPath: ${AXON_SEARCH_CONTAINER_MOUNT_PATH}
EOF
  else
    cat >> "$AXON_SEARCH_VALUES_FILE" <<EOF
persistence:
  enabled: ${AXON_SEARCH_PERSISTENCE_ENABLED}
  enableInitChown: true
  storageClass: "${AXON_SEARCH_STORAGE_CLASS}"
  accessMode: ReadWriteOnce
  size: ${AXON_SEARCH_VOLUME_SIZE}
  # existingClaim: ""
  annotations: {}
EOF
  fi
}

install_search_db() {
  info "Installing AxonOps Search DB (Helm release: $AXON_SEARCH_RELEASE_NAME)..."

  $HELM_BIN upgrade --install "$AXON_SEARCH_RELEASE_NAME" "$AXON_SEARCH_CHART" \
    --namespace "$NS_AXONOPS" \
    --create-namespace \
    --wait \
    -f "$AXON_SEARCH_VALUES_FILE" \
    $AXON_SEARCH_HELM_EXTRA_ARGS
}

############################################
# 4. AxonOps Server
############################################
generate_axon_server_secret_manifest() {
  info "Generating AxonOps server Secret manifest: $AXON_SERVER_CONFIG_FILE..."
  cat > "$AXON_SERVER_CONFIG_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${AXON_SERVER_SECRET_NAME}
  namespace: ${NS_AXONOPS}
type: Opaque
stringData:
  axon-server.yml: |
    agents_port: ${AXON_SERVER_AGENTS_PORT}
    api_port: ${AXON_SERVER_API_PORT}
    host: ${AXON_SERVER_HOST}

    search_db:
      hosts:
        - ${AXON_SERVER_SEARCH_DB_HOST_URL}
      username: ${AXON_SEARCH_USER}
      password: ${AXON_SEARCH_PASSWORD}
      skip_verify: ${AXON_SERVER_SEARCH_DB_SKIP_VERIFY}

    org_name: ${AXON_SERVER_ORG_NAME}

    axon_dash_url: ${AXON_SERVER_DASH_URL}

    log_file: /dev/stdout
    tls:
      mode: ${AXON_SERVER_TLS_MODE}
    auth:
      enabled: ${AXON_SERVER_AUTH_ENABLED}
    cql_autocreate_tables: true
    cql_batch_size: 100
    cql_hosts:
    - ${AXON_SERVER_CQL_HOSTS}
    # cql_keyspace_replication: '${AXON_SERVER_CQL_REPLICATION}'
    cql_local_dc: ${AXON_SERVER_CQL_LOCAL_DC}
    cql_max_searchqueriesparallelism: 100
    cql_metrics_cache_max_items: 500000
    cql_metrics_cache_max_size: 128
    cql_page_size: 100
    cql_proto_version: 4
    cql_reconnectionpolicy_initialinterval: 1s
    cql_reconnectionpolicy_maxinterval: 10s
    cql_reconnectionpolicy_maxretries: 10
    cql_retrypolicy_max: 10s
    cql_retrypolicy_min: 2s
    cql_retrypolicy_numretries: 3
    cql_skip_verify: ${AXON_SERVER_CQL_SKIP_VERIFY}
    cql_ssl: ${AXON_SERVER_CQL_SSL_ENABLED}
    cql_username: ${AXON_SERVER_CQL_USERNAME}
    cql_password: ${AXON_SERVER_CQL_PASSWORD}
EOF
}

install_axon_server() {
  info "Applying AxonOps server Secret..."
  $KUBECTL_BIN apply -f "$AXON_SERVER_CONFIG_FILE"

  info "Installing AxonOps server (Helm release: $AXON_SERVER_RELEASE_NAME)..."
  $HELM_BIN upgrade --install "$AXON_SERVER_RELEASE_NAME" "$AXON_SERVER_CHART" \
    --namespace "$NS_AXONOPS" \
    --create-namespace \
    --set "configurationSecret=${AXON_SERVER_SECRET_NAME}" \
    $AXON_SERVER_HELM_EXTRA_ARGS
}

############################################
# 5. AxonOps Dashboard
############################################
generate_axon_dash_values() {
  info "Generating AxonOps dashboard values file: $AXON_DASH_VALUES_FILE..."

  # Choose between ClusterIP and NodePort based on AXON_DASH_NODEPORT_ENABLED
  if [[ "$AXON_DASH_NODEPORT_ENABLED" == "true" ]]; then
    SERVICE_BLOCK=$(cat <<EOS
service:
  type: NodePort
  ports:
    - port: ${AXON_DASH_SERVICE_PORT}
      targetPort: ${AXON_DASH_SERVICE_PORT}
      nodePort: ${AXON_DASH_NODEPORT_PORT}
EOS
)
  else
    SERVICE_BLOCK=$(cat <<EOS
service:
  type: ${AXON_DASH_SERVICE_TYPE}
  port: ${AXON_DASH_SERVICE_PORT}
EOS
)
  fi

  # Ingress configuration
  if [[ "$AXON_DASH_INGRESS_ENABLED" == "true" ]]; then
    INGRESS_BLOCK=$(cat <<EOS
ingress:
  enabled: true
  className: "${AXON_DASH_INGRESS_CLASS_NAME}"
  annotations:
    cert-manager.io/cluster-issuer: ${AXON_DASH_INGRESS_CERT_ISSUER_ANNOTATION}
  hosts:
    - host: ${AXON_DASH_INGRESS_HOST}
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: ${AXON_DASH_INGRESS_TLS_SECRET_NAME}
      hosts:
        - ${AXON_DASH_INGRESS_HOST}
EOS
)
  else
    INGRESS_BLOCK=$(cat <<'EOS'
ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: axonops.mycompany.com
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []
EOS
)
  fi

  cat > "$AXON_DASH_VALUES_FILE" <<EOF
config:
  axonServerUrl: "${AXON_DASH_AXON_SERVER_URL}"

${SERVICE_BLOCK}

${INGRESS_BLOCK}
EOF
}

install_axon_dash() {
  info "Installing AxonOps dashboard (Helm release: $AXON_DASH_RELEASE_NAME)..."
  $HELM_BIN upgrade --install "$AXON_DASH_RELEASE_NAME" "$AXON_DASH_CHART" \
    --namespace "$NS_AXONOPS" \
    --create-namespace \
    -f "$AXON_DASH_VALUES_FILE" \
    $AXON_DASH_HELM_EXTRA_ARGS
}

############################################
# Wait for services to be ready
############################################
wait_for_services() {
  info "Waiting for AxonOps services to be ready..."

  # Wait for Timeseries DB
  info "Waiting for Timeseries DB to be ready..."
  $KUBECTL_BIN wait --for=condition=ready pod \
    -l "app.kubernetes.io/instance=$AXON_TIMESERIES_RELEASE_NAME" \
    -n "$NS_AXONOPS" \
    --timeout=300s

  # Wait for Search DB
  info "Waiting for Search DB to be ready..."
  $KUBECTL_BIN wait --for=condition=ready pod \
    -l "app.kubernetes.io/instance=$AXON_SEARCH_RELEASE_NAME" \
    -n "$NS_AXONOPS" \
    --timeout=300s

  # Wait for AxonOps Server
  info "Waiting for AxonOps Server to be ready..."
  $KUBECTL_BIN wait --for=condition=ready pod \
    -l "app.kubernetes.io/instance=$AXON_SERVER_RELEASE_NAME" \
    -n "$NS_AXONOPS" \
    --timeout=180s

  # Wait for Dashboard
  info "Waiting for AxonOps Dashboard to be ready..."
  $KUBECTL_BIN wait --for=condition=ready pod \
    -l "app.kubernetes.io/instance=$AXON_DASH_RELEASE_NAME" \
    -n "$NS_AXONOPS" \
    --timeout=120s
}

############################################
# Export configuration for Strimzi script
############################################
export_config_for_strimzi() {
  info "Exporting configuration for Strimzi setup..."

  cat > axonops-config.env <<EOF
# AxonOps configuration for Strimzi integration
export NS_AXONOPS="${NS_AXONOPS}"
export AXON_SERVER_AGENTS_PORT="${AXON_SERVER_AGENTS_PORT}"
export AXON_SERVER_API_PORT="${AXON_SERVER_API_PORT}"
export AXON_SERVER_ORG_NAME="${AXON_SERVER_ORG_NAME}"
EOF

  info "Configuration exported to axonops-config.env"
  info "Source this file before running strimzi-setup.sh:"
  echo "  source axonops-config.env"
}

############################################
# Main
############################################
main() {
  info "Starting deployment of AxonOps on-premises services..."

  # Check required environment variables
  if [[ -z "${AXON_SEARCH_PASSWORD:-}" ]]; then
    error "AXON_SEARCH_PASSWORD environment variable is required for security"
    error "Please set it before running: export AXON_SEARCH_PASSWORD='your-secure-password'"
    exit 1
  fi
  
  if [[ -z "${AXON_SERVER_CQL_PASSWORD:-}" ]]; then
    error "AXON_SERVER_CQL_PASSWORD environment variable is required for security"
    error "Please set it before running: export AXON_SERVER_CQL_PASSWORD='your-secure-password'"
    exit 1
  fi
  
  install_cert_manager

  prepare_timeseries_hostpath
  generate_timeseries_values
  install_timeseries_db

  prepare_search_hostpath
  generate_search_values
  install_search_db

  generate_axon_server_secret_manifest
  install_axon_server

  generate_axon_dash_values
  install_axon_dash

  wait_for_services
  export_config_for_strimzi

  info "AxonOps services deployment completed successfully!"
  info ""
  info "Verify status with:"
  echo "  $KUBECTL_BIN get pods -n $NS_AXONOPS"
  echo ""
  info "Access the AxonOps Dashboard:"

  if [[ "$AXON_DASH_NODEPORT_ENABLED" == "true" ]]; then
    echo "  NodePort: http://<node-ip>:$AXON_DASH_NODEPORT_PORT"
  elif [[ "$AXON_DASH_INGRESS_ENABLED" == "true" ]]; then
    echo "  Ingress: https://$AXON_DASH_INGRESS_HOST"
  else
    echo "  Port-forward: $KUBECTL_BIN port-forward -n $NS_AXONOPS svc/axon-dash 3000:$AXON_DASH_SERVICE_PORT"
    echo "  Then access: http://localhost:3000"
  fi

  info ""
  info "Next steps:"
  echo "  1. Source the configuration file: source axonops-config.env"
  echo "  2. Run the Strimzi setup script: ./strimzi-setup.sh"
}

main "$@"
