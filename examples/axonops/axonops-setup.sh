#!/usr/bin/env bash
# Deploy a self-hosted AxonOps stack on Kubernetes: cert-manager (optional),
# AxonDB Timeseries, AxonDB Search, axon-server and axon-dash.
#
# Usage:
#   source axonops-config.env
#   ./axonops-setup.sh
#
# Every setting below can be overridden with an environment variable.
# RENDER_ONLY=true writes the values files and the axon-server Secret to
# AXONOPS_OUTPUT_DIR and prints the commands a real run would execute,
# without changing the cluster.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

############################################
# Parameters
############################################

KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
HELM_BIN="${HELM_BIN:-helm}"
HELM_TIMEOUT="${HELM_TIMEOUT:-10m}"
# true: each AxonOps release is installed with helm --wait, so the script
# returns only when every pod is ready. false: install and return at once.
HELM_WAIT="${HELM_WAIT:-true}"
RENDER_ONLY="${RENDER_ONLY:-false}"


# NS_AXONOPS is the name used by earlier versions of this script.
AXONOPS_NAMESPACE="${AXONOPS_NAMESPACE:-${NS_AXONOPS:-axonops}}"
NS_CERT_MANAGER="${NS_CERT_MANAGER:-cert-manager}"

# Generated files hold passwords. They are written outside the tracked tree.
AXONOPS_OUTPUT_DIR="${AXONOPS_OUTPUT_DIR:-$SCRIPT_DIR/generated}"

# --- cert-manager ---
# Install cert-manager when its CRDs are missing. With false, an existing
# cert-manager is still used for the database certificates.
CERT_MANAGER_INSTALL="${CERT_MANAGER_INSTALL:-false}"
# Create CLUSTER_ISSUER_NAME as a self-signed ClusterIssuer. Set to false to
# use an issuer you already have.
CLUSTER_ISSUER_CREATE="${CLUSTER_ISSUER_CREATE:-true}"
CERT_MANAGER_RELEASE_NAME="${CERT_MANAGER_RELEASE_NAME:-cert-manager}"
CERT_MANAGER_CHART_REPO="${CERT_MANAGER_CHART_REPO:-oci://quay.io/jetstack/charts/cert-manager}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.19.1}"
CLUSTER_ISSUER_NAME="${CLUSTER_ISSUER_NAME:-selfsigned-cluster-issuer}"

# --- AxonDB Timeseries (Cassandra) ---
AXON_TIMESERIES_RELEASE_NAME="${AXON_TIMESERIES_RELEASE_NAME:-axondb-timeseries}"
AXON_TIMESERIES_CHART="${AXON_TIMESERIES_CHART:-oci://ghcr.io/axonops/charts/axondb-timeseries}"
AXON_TIMESERIES_HEAP_SIZE="${AXON_TIMESERIES_HEAP_SIZE:-2048M}"
AXON_TIMESERIES_TLS_ENABLED="${AXON_TIMESERIES_TLS_ENABLED:-false}"
AXON_TIMESERIES_CERTMANAGER_ENABLED="${AXON_TIMESERIES_CERTMANAGER_ENABLED:-true}"
# Secret with the TLS material when cert-manager is not used (tls.manual.existingSecret).
AXON_TIMESERIES_TLS_EXISTING_SECRET="${AXON_TIMESERIES_TLS_EXISTING_SECRET:-}"
AXON_TIMESERIES_CERT_ISSUER_NAME="${AXON_TIMESERIES_CERT_ISSUER_NAME:-$CLUSTER_ISSUER_NAME}"
AXON_TIMESERIES_PERSISTENCE_ENABLED="${AXON_TIMESERIES_PERSISTENCE_ENABLED:-true}"
AXON_TIMESERIES_STORAGE_CLASS="${AXON_TIMESERIES_STORAGE_CLASS:-}"
AXON_TIMESERIES_VOLUME_SIZE="${AXON_TIMESERIES_VOLUME_SIZE:-10Gi}"
AXON_TIMESERIES_USE_HOSTPATH="${AXON_TIMESERIES_USE_HOSTPATH:-false}"
AXON_TIMESERIES_HOSTPATH_DIR="${AXON_TIMESERIES_HOSTPATH_DIR:-/data/axon-timeseries}"
AXON_TIMESERIES_HOSTPATH_CREATE="${AXON_TIMESERIES_HOSTPATH_CREATE:-false}"
AXON_TIMESERIES_HOST_UID="${AXON_TIMESERIES_HOST_UID:-999}"
AXON_TIMESERIES_HOST_GID="${AXON_TIMESERIES_HOST_GID:-999}"
AXON_TIMESERIES_CONTAINER_MOUNT_PATH="${AXON_TIMESERIES_CONTAINER_MOUNT_PATH:-/var/lib/cassandra}"
AXON_TIMESERIES_RES_REQ_CPU="${AXON_TIMESERIES_RES_REQ_CPU:-1000m}"
AXON_TIMESERIES_RES_REQ_MEM="${AXON_TIMESERIES_RES_REQ_MEM:-2Gi}"
AXON_TIMESERIES_RES_LIMIT_CPU="${AXON_TIMESERIES_RES_LIMIT_CPU:-2000m}"
AXON_TIMESERIES_RES_LIMIT_MEM="${AXON_TIMESERIES_RES_LIMIT_MEM:-4Gi}"
AXON_TIMESERIES_HELM_EXTRA_ARGS="${AXON_TIMESERIES_HELM_EXTRA_ARGS:-}"

# --- AxonDB Search (OpenSearch) ---
AXON_SEARCH_RELEASE_NAME="${AXON_SEARCH_RELEASE_NAME:-axondb-search}"
AXON_SEARCH_CHART="${AXON_SEARCH_CHART:-oci://ghcr.io/axonops/charts/axondb-search}"
AXON_SEARCH_HEAP_SIZE="${AXON_SEARCH_HEAP_SIZE:-2g}"
AXON_SEARCH_TLS_ENABLED="${AXON_SEARCH_TLS_ENABLED:-false}"
AXON_SEARCH_CERTMANAGER_ENABLED="${AXON_SEARCH_CERTMANAGER_ENABLED:-true}"
# Secret with the TLS material when cert-manager is not used (tls.manual.existingSecret).
AXON_SEARCH_TLS_EXISTING_SECRET="${AXON_SEARCH_TLS_EXISTING_SECRET:-}"
AXON_SEARCH_CERT_ISSUER_NAME="${AXON_SEARCH_CERT_ISSUER_NAME:-$CLUSTER_ISSUER_NAME}"
AXON_SEARCH_PERSISTENCE_ENABLED="${AXON_SEARCH_PERSISTENCE_ENABLED:-true}"
AXON_SEARCH_STORAGE_CLASS="${AXON_SEARCH_STORAGE_CLASS:-}"
AXON_SEARCH_VOLUME_SIZE="${AXON_SEARCH_VOLUME_SIZE:-10Gi}"
AXON_SEARCH_USE_HOSTPATH="${AXON_SEARCH_USE_HOSTPATH:-false}"
AXON_SEARCH_HOSTPATH_DIR="${AXON_SEARCH_HOSTPATH_DIR:-/data/axon-search}"
AXON_SEARCH_HOSTPATH_CREATE="${AXON_SEARCH_HOSTPATH_CREATE:-false}"
AXON_SEARCH_HOST_UID="${AXON_SEARCH_HOST_UID:-999}"
AXON_SEARCH_HOST_GID="${AXON_SEARCH_HOST_GID:-999}"
AXON_SEARCH_CONTAINER_MOUNT_PATH="${AXON_SEARCH_CONTAINER_MOUNT_PATH:-/var/lib/opensearch}"
AXON_SEARCH_HELM_EXTRA_ARGS="${AXON_SEARCH_HELM_EXTRA_ARGS:-}"
AXON_SEARCH_USER="${AXON_SEARCH_USER:-admin}"
AXON_SEARCH_PASSWORD="${AXON_SEARCH_PASSWORD:-}"

# --- axon-server ---
AXON_SERVER_RELEASE_NAME="${AXON_SERVER_RELEASE_NAME:-axon-server}"
AXON_SERVER_CHART="${AXON_SERVER_CHART:-oci://ghcr.io/axonops/charts/axon-server}"
AXON_SERVER_SECRET_NAME="${AXON_SERVER_SECRET_NAME:-axon-server-config}"
AXON_SERVER_AGENTS_PORT="${AXON_SERVER_AGENTS_PORT:-1888}"
AXON_SERVER_API_PORT="${AXON_SERVER_API_PORT:-8080}"
AXON_SERVER_ORG_NAME="${AXON_SERVER_ORG_NAME:-example}"
AXON_SERVER_LICENSE_KEY="${AXON_SERVER_LICENSE_KEY:-}"
AXON_SERVER_TLS_MODE="${AXON_SERVER_TLS_MODE:-disabled}"
AXON_SERVER_AUTH_ENABLED="${AXON_SERVER_AUTH_ENABLED:-false}"
AXON_SERVER_HELM_EXTRA_ARGS="${AXON_SERVER_HELM_EXTRA_ARGS:-}"

_search_scheme=https
[[ "$AXON_SEARCH_TLS_ENABLED" == "true" ]] || _search_scheme=http
AXON_SERVER_SEARCH_DB_HOST_URL="${AXON_SERVER_SEARCH_DB_HOST_URL:-${_search_scheme}://axondb-search-cluster-master.${AXONOPS_NAMESPACE}.svc.cluster.local:9200}"
AXON_SERVER_SEARCH_DB_SKIP_VERIFY="${AXON_SERVER_SEARCH_DB_SKIP_VERIFY:-true}"

# The charts name their Services after the release, adding the chart name
# unless the release name already contains it.
helm_fullname() {
  if [[ "$1" == *"$2"* ]]; then echo "$1"; else echo "$1-$2"; fi
}
_timeseries_fullname="$(helm_fullname "$AXON_TIMESERIES_RELEASE_NAME" axondb-timeseries)"
_server_fullname="$(helm_fullname "$AXON_SERVER_RELEASE_NAME" axon-server)"

AXON_SERVER_CQL_HOSTS="${AXON_SERVER_CQL_HOSTS:-${_timeseries_fullname}-headless.${AXONOPS_NAMESPACE}.svc.cluster.local}"
AXON_SERVER_CQL_USERNAME="${AXON_SERVER_CQL_USERNAME:-axonops}"
AXON_SERVER_CQL_PASSWORD="${AXON_SERVER_CQL_PASSWORD:-}"
AXON_SERVER_CQL_LOCAL_DC="${AXON_SERVER_CQL_LOCAL_DC:-axonopsdb_dc1}"
AXON_SERVER_CQL_SSL_ENABLED="${AXON_SERVER_CQL_SSL_ENABLED:-$AXON_TIMESERIES_TLS_ENABLED}"
AXON_SERVER_CQL_SKIP_VERIFY="${AXON_SERVER_CQL_SKIP_VERIFY:-true}"

# API Ingress
AXON_SERVER_API_INGRESS_ENABLED="${AXON_SERVER_API_INGRESS_ENABLED:-false}"
AXON_SERVER_API_INGRESS_CLASS_NAME="${AXON_SERVER_API_INGRESS_CLASS_NAME:-}"
AXON_SERVER_API_INGRESS_HOST="${AXON_SERVER_API_INGRESS_HOST:-api.example.com}"
AXON_SERVER_API_INGRESS_TLS_SECRET_NAME="${AXON_SERVER_API_INGRESS_TLS_SECRET_NAME:-axon-server-api-tls}"
AXON_SERVER_API_INGRESS_CERT_ISSUER_ANNOTATION="${AXON_SERVER_API_INGRESS_CERT_ISSUER_ANNOTATION:-}"

# Agent Ingress (gRPC)
AXON_SERVER_AGENT_INGRESS_ENABLED="${AXON_SERVER_AGENT_INGRESS_ENABLED:-false}"
AXON_SERVER_AGENT_INGRESS_CLASS_NAME="${AXON_SERVER_AGENT_INGRESS_CLASS_NAME:-nginx}"
AXON_SERVER_AGENT_INGRESS_HOST="${AXON_SERVER_AGENT_INGRESS_HOST:-agents.example.com}"
AXON_SERVER_AGENT_INGRESS_TLS_SECRET_NAME="${AXON_SERVER_AGENT_INGRESS_TLS_SECRET_NAME:-axon-server-agents-tls}"
AXON_SERVER_AGENT_INGRESS_CERT_ISSUER_ANNOTATION="${AXON_SERVER_AGENT_INGRESS_CERT_ISSUER_ANNOTATION:-}"
AXON_SERVER_AGENT_INGRESS_GRPC_ANNOTATION="${AXON_SERVER_AGENT_INGRESS_GRPC_ANNOTATION:-true}"

# --- axon-dash ---
AXON_DASH_RELEASE_NAME="${AXON_DASH_RELEASE_NAME:-axon-dash}"
AXON_DASH_CHART="${AXON_DASH_CHART:-oci://ghcr.io/axonops/charts/axon-dash}"
AXON_DASH_AXON_SERVER_URL="${AXON_DASH_AXON_SERVER_URL:-http://${_server_fullname}-api.${AXONOPS_NAMESPACE}.svc.cluster.local:${AXON_SERVER_API_PORT}}"
AXON_DASH_SERVICE_TYPE="${AXON_DASH_SERVICE_TYPE:-ClusterIP}"
AXON_DASH_SERVICE_PORT="${AXON_DASH_SERVICE_PORT:-3000}"
AXON_DASH_NODEPORT_ENABLED="${AXON_DASH_NODEPORT_ENABLED:-false}"
AXON_DASH_INGRESS_ENABLED="${AXON_DASH_INGRESS_ENABLED:-false}"
AXON_DASH_INGRESS_CLASS_NAME="${AXON_DASH_INGRESS_CLASS_NAME:-}"
AXON_DASH_INGRESS_HOST="${AXON_DASH_INGRESS_HOST:-axonops.example.com}"
AXON_DASH_INGRESS_TLS_SECRET_NAME="${AXON_DASH_INGRESS_TLS_SECRET_NAME:-axon-dash-tls}"
AXON_DASH_INGRESS_CERT_ISSUER_ANNOTATION="${AXON_DASH_INGRESS_CERT_ISSUER_ANNOTATION:-}"
AXON_DASH_HELM_EXTRA_ARGS="${AXON_DASH_HELM_EXTRA_ARGS:-}"

# Reports v2: axon-reporting sidecar in the axon-dash pod (needs axon-server >= 2.0.39).
AXON_DASH_REPORTING_IMAGE_REPOSITORY="${AXON_DASH_REPORTING_IMAGE_REPOSITORY:-registry.axonops.com/axonops-public/axonops-docker/axon-reporting}"
AXON_DASH_REPORTING_IMAGE_TAG="${AXON_DASH_REPORTING_IMAGE_TAG:-1.0.3}"
AXON_DASH_REPORTING_PORT="${AXON_DASH_REPORTING_PORT:-8081}"
_dash_fullname="$(helm_fullname "$AXON_DASH_RELEASE_NAME" axon-dash)"
AXON_SERVER_REPORTING_URL="${AXON_SERVER_REPORTING_URL:-http://${_dash_fullname}-svc.${AXONOPS_NAMESPACE}.svc.cluster.local:${AXON_DASH_REPORTING_PORT}}"

TIMESERIES_VALUES_FILE="$AXONOPS_OUTPUT_DIR/timeseries-values.yaml"
SEARCH_VALUES_FILE="$AXONOPS_OUTPUT_DIR/search-values.yaml"
SERVER_SECRET_FILE="$AXONOPS_OUTPUT_DIR/axon-server-secret.yaml"
SERVER_VALUES_FILE="$AXONOPS_OUTPUT_DIR/axon-server-values.yaml"
DASH_VALUES_FILE="$AXONOPS_OUTPUT_DIR/axon-dash-values.yaml"

############################################
# Helpers
############################################

info()  { echo "[INFO]  $*"; }

# Escape a value for a double-quoted YAML scalar.
yaml_quote() { local v="${1//\\/\\\\}"; printf '"%s"' "${v//\"/\\\"}"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; }

# Persistence block shared by both databases: hostPath, PVC, or none.
# Args: use_hostpath hostpath_dir mount_path volume_name persistence storage_class size
persistence_block() {
  if [[ "$1" == "true" ]]; then
    cat <<EOF
persistence:
  enabled: false
extraVolumes:
  - name: $4
    hostPath:
      path: $2
      type: DirectoryOrCreate
extraVolumeMounts:
  - name: $4
    mountPath: $3
EOF
  else
    cat <<EOF
persistence:
  enabled: $5
  enableInitChown: true
  storageClass: "$6"
  accessMode: ReadWriteOnce
  size: $7
EOF
  fi
}

# Create a hostPath directory with sudo. Only meaningful when this script runs
# on the single Kubernetes node that will mount it.
prepare_hostpath() {
  local dir="$1" owner="$2"
  info "Creating hostPath directory $dir (owner $owner) on this machine"
  sudo mkdir -p "$dir"
  sudo chown -R "$owner" "$dir"
}

############################################
# cert-manager
############################################

# True when either database gets its certificate from cert-manager.
uses_cert_manager() {
  [[ "$AXON_TIMESERIES_TLS_ENABLED" == "true" && "$AXON_TIMESERIES_CERTMANAGER_ENABLED" == "true" ]] ||
    [[ "$AXON_SEARCH_TLS_ENABLED" == "true" && "$AXON_SEARCH_CERTMANAGER_ENABLED" == "true" ]]
}

# AxonDB Timeseries with TLS enabled but no certificate source starts without
# TLS, while axon-server still connects with TLS and fails. Stop before that.
# AxonDB Search falls back to the certificates built into its image.
check_tls_settings() {
  if [[ "$AXON_TIMESERIES_TLS_ENABLED" == "true" && "$AXON_TIMESERIES_CERTMANAGER_ENABLED" != "true" \
        && -z "$AXON_TIMESERIES_TLS_EXISTING_SECRET" ]]; then
    error "AXON_TIMESERIES_TLS_ENABLED=true but AXON_TIMESERIES_CERTMANAGER_ENABLED=false and"
    error "AXON_TIMESERIES_TLS_EXISTING_SECRET is empty: the database would start without TLS."
    error "Set AXON_TIMESERIES_CERTMANAGER_ENABLED=true, set AXON_TIMESERIES_TLS_EXISTING_SECRET,"
    error "or set AXON_TIMESERIES_TLS_ENABLED=false."
    exit 1
  fi
}

cert_manager_installed() {
  $KUBECTL_BIN get crd certificates.cert-manager.io &>/dev/null
}

cluster_issuer_exists() {
  $KUBECTL_BIN get clusterissuer "$CLUSTER_ISSUER_NAME" &>/dev/null
}

# cert-manager is only installed when it is missing and CERT_MANAGER_INSTALL=true.
# An existing ClusterIssuer is never modified.
setup_cert_manager() {
  if cert_manager_installed; then
    info "cert-manager is already installed; not installing it"
  elif [[ "$CERT_MANAGER_INSTALL" == "true" ]]; then
    info "Installing cert-manager $CERT_MANAGER_VERSION in '$NS_CERT_MANAGER'..."
    $HELM_BIN upgrade --install "$CERT_MANAGER_RELEASE_NAME" "$CERT_MANAGER_CHART_REPO" \
      --version "$CERT_MANAGER_VERSION" \
      --namespace "$NS_CERT_MANAGER" --create-namespace \
      --set crds.enabled=true \
      --wait --timeout "$HELM_TIMEOUT"  # always: the ClusterIssuer needs the webhook running
  else
    error "Database TLS uses cert-manager, which is not installed. Install it, or set"
    error "CERT_MANAGER_INSTALL=true, or set AXON_TIMESERIES_CERTMANAGER_ENABLED=false with"
    error "AXON_TIMESERIES_TLS_EXISTING_SECRET."
    exit 1
  fi

  if cluster_issuer_exists; then
    info "ClusterIssuer '$CLUSTER_ISSUER_NAME' exists; using it"
  elif [[ "$CLUSTER_ISSUER_CREATE" == "true" ]]; then
    info "Creating self-signed ClusterIssuer '$CLUSTER_ISSUER_NAME'..."
    $KUBECTL_BIN apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${CLUSTER_ISSUER_NAME}
spec:
  selfSigned: {}
EOF
  else
    error "ClusterIssuer '$CLUSTER_ISSUER_NAME' not found and CLUSTER_ISSUER_CREATE=false."
    exit 1
  fi
}

############################################
# Values and Secret generation
############################################

generate_timeseries_values() {
  info "Writing $TIMESERIES_VALUES_FILE"
  {
    cat <<EOF
heapSize: ${AXON_TIMESERIES_HEAP_SIZE}

authentication:
  db_user: $(yaml_quote "$AXON_SERVER_CQL_USERNAME")
  db_password: $(yaml_quote "$AXON_SERVER_CQL_PASSWORD")

tls:
  enabled: ${AXON_TIMESERIES_TLS_ENABLED}
  certManager:
    enabled: ${AXON_TIMESERIES_CERTMANAGER_ENABLED}
    issuer:
      name: ${AXON_TIMESERIES_CERT_ISSUER_NAME}
  manual:
    existingSecret: "${AXON_TIMESERIES_TLS_EXISTING_SECRET}"

resources:
  requests:
    cpu: ${AXON_TIMESERIES_RES_REQ_CPU}
    memory: ${AXON_TIMESERIES_RES_REQ_MEM}
  limits:
    cpu: ${AXON_TIMESERIES_RES_LIMIT_CPU}
    memory: ${AXON_TIMESERIES_RES_LIMIT_MEM}

EOF
    persistence_block "$AXON_TIMESERIES_USE_HOSTPATH" "$AXON_TIMESERIES_HOSTPATH_DIR" \
      "$AXON_TIMESERIES_CONTAINER_MOUNT_PATH" timeseries-data \
      "$AXON_TIMESERIES_PERSISTENCE_ENABLED" "$AXON_TIMESERIES_STORAGE_CLASS" "$AXON_TIMESERIES_VOLUME_SIZE"
  } > "$TIMESERIES_VALUES_FILE"
}

generate_search_values() {
  info "Writing $SEARCH_VALUES_FILE"
  {
    cat <<EOF
opensearchHeapSize: "${AXON_SEARCH_HEAP_SIZE}"

authentication:
  opensearch_user: $(yaml_quote "$AXON_SEARCH_USER")
  opensearch_password: $(yaml_quote "$AXON_SEARCH_PASSWORD")

tls:
  enabled: ${AXON_SEARCH_TLS_ENABLED}
  certManager:
    enabled: ${AXON_SEARCH_CERTMANAGER_ENABLED}
    issuer:
      name: ${AXON_SEARCH_CERT_ISSUER_NAME}
  manual:
    existingSecret: "${AXON_SEARCH_TLS_EXISTING_SECRET}"

EOF
    persistence_block "$AXON_SEARCH_USE_HOSTPATH" "$AXON_SEARCH_HOSTPATH_DIR" \
      "$AXON_SEARCH_CONTAINER_MOUNT_PATH" data \
      "$AXON_SEARCH_PERSISTENCE_ENABLED" "$AXON_SEARCH_STORAGE_CLASS" "$AXON_SEARCH_VOLUME_SIZE"
  } > "$SEARCH_VALUES_FILE"
}

generate_server_secret() {
  info "Writing $SERVER_SECRET_FILE"
  cat > "$SERVER_SECRET_FILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${AXON_SERVER_SECRET_NAME}
  namespace: ${AXONOPS_NAMESPACE}
type: Opaque
stringData:
  axon-server.yml: |
    agents_port: ${AXON_SERVER_AGENTS_PORT}
    api_port: ${AXON_SERVER_API_PORT}
    host: 0.0.0.0

    search_db:
      hosts:
        - ${AXON_SERVER_SEARCH_DB_HOST_URL}
      username: $(yaml_quote "$AXON_SEARCH_USER")
      password: $(yaml_quote "$AXON_SEARCH_PASSWORD")
      skip_verify: ${AXON_SERVER_SEARCH_DB_SKIP_VERIFY}

    org_name: $(yaml_quote "$AXON_SERVER_ORG_NAME")
    license_key: $(yaml_quote "$AXON_SERVER_LICENSE_KEY")

    axon_reporting_url: ${AXON_SERVER_REPORTING_URL}

    log_file: /dev/stdout
    tls:
      mode: ${AXON_SERVER_TLS_MODE}
    auth:
      enabled: ${AXON_SERVER_AUTH_ENABLED}

    cql_hosts:
      - ${AXON_SERVER_CQL_HOSTS}
    cql_local_dc: ${AXON_SERVER_CQL_LOCAL_DC}
    cql_username: $(yaml_quote "$AXON_SERVER_CQL_USERNAME")
    cql_password: $(yaml_quote "$AXON_SERVER_CQL_PASSWORD")
    cql_ssl: ${AXON_SERVER_CQL_SSL_ENABLED}
    cql_skip_verify: ${AXON_SERVER_CQL_SKIP_VERIFY}
    cql_autocreate_tables: true
    cql_batch_size: 100
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
EOF
}

# Ingress block for the axon-server and axon-dash charts.
# Args: key enabled class host tls_secret issuer [extra_annotation]
ingress_block() {
  local key="$1" enabled="$2" class="$3" host="$4" tls_secret="$5" issuer="$6" extra="${7:-}"
  if [[ "$enabled" != "true" ]]; then
    printf '%s:\n  enabled: false\n' "$key"
    return
  fi
  echo "$key:"
  echo "  enabled: true"
  echo "  className: \"$class\""
  if [[ -n "$issuer" || -n "$extra" ]]; then
    echo "  annotations:"
    [[ -n "$extra" ]] && echo "    $extra"
    [[ -n "$issuer" ]] && echo "    cert-manager.io/cluster-issuer: $issuer"
  else
    echo "  annotations: {}"
  fi
  cat <<EOF
  hosts:
    - host: $host
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: $tls_secret
      hosts:
        - $host
EOF
}

generate_server_values() {
  info "Writing $SERVER_VALUES_FILE"
  local grpc=""
  [[ "$AXON_SERVER_AGENT_INGRESS_GRPC_ANNOTATION" == "true" ]] \
    && grpc='nginx.ingress.kubernetes.io/backend-protocol: "GRPC"'
  # The axon-server-api Service makes Kubernetes inject
  # AXON_SERVER_API_PORT=tcp://<ip>:<port>, which axon-server reads as its
  # listen port. enableServiceLinks needs axon-server chart >= 2.1.21; the
  # explicit env var wins over the injected one on older charts.
  {
    cat <<EOF
configurationSecret: ${AXON_SERVER_SECRET_NAME}

enableServiceLinks: false

deployment:
  env:
    AXON_SERVER_API_PORT: "${AXON_SERVER_API_PORT}"

EOF
    ingress_block apiIngress "$AXON_SERVER_API_INGRESS_ENABLED" "$AXON_SERVER_API_INGRESS_CLASS_NAME" \
      "$AXON_SERVER_API_INGRESS_HOST" "$AXON_SERVER_API_INGRESS_TLS_SECRET_NAME" \
      "$AXON_SERVER_API_INGRESS_CERT_ISSUER_ANNOTATION"
    echo
    ingress_block agentIngress "$AXON_SERVER_AGENT_INGRESS_ENABLED" "$AXON_SERVER_AGENT_INGRESS_CLASS_NAME" \
      "$AXON_SERVER_AGENT_INGRESS_HOST" "$AXON_SERVER_AGENT_INGRESS_TLS_SECRET_NAME" \
      "$AXON_SERVER_AGENT_INGRESS_CERT_ISSUER_ANNOTATION" "$grpc"
  } > "$SERVER_VALUES_FILE"
}

generate_dash_values() {
  info "Writing $DASH_VALUES_FILE"
  local service_type="$AXON_DASH_SERVICE_TYPE"
  [[ "$AXON_DASH_NODEPORT_ENABLED" == "true" ]] && service_type=NodePort
  {
    cat <<EOF
enableServiceLinks: false

config:
  axonServerUrl: "${AXON_DASH_AXON_SERVER_URL}"

service:
  type: ${service_type}
  port: ${AXON_DASH_SERVICE_PORT}

reporting:
  image:
    repository: ${AXON_DASH_REPORTING_IMAGE_REPOSITORY}
    tag: "${AXON_DASH_REPORTING_IMAGE_TAG}"
  port: ${AXON_DASH_REPORTING_PORT}

EOF
    ingress_block ingress "$AXON_DASH_INGRESS_ENABLED" "$AXON_DASH_INGRESS_CLASS_NAME" \
      "$AXON_DASH_INGRESS_HOST" "$AXON_DASH_INGRESS_TLS_SECRET_NAME" \
      "$AXON_DASH_INGRESS_CERT_ISSUER_ANNOTATION"
  } > "$DASH_VALUES_FILE"
}

############################################
# Install
############################################

# helm flags for HELM_WAIT.
helm_wait_args() {
  if [[ "$HELM_WAIT" == "true" ]]; then echo "--wait --timeout $HELM_TIMEOUT"; fi
}

# Args: release chart values_file extra_args
helm_install() {
  info "Installing Helm release '$1' in '$AXONOPS_NAMESPACE'..."
  # shellcheck disable=SC2046,SC2086 # wait flags and extra args are intentionally word-split
  $HELM_BIN upgrade --install "$1" "$2" \
    --namespace "$AXONOPS_NAMESPACE" --create-namespace \
    -f "$3" \
    $(helm_wait_args) \
    $4
}

print_access() {
  local dash_svc="${_dash_fullname}-svc"
  echo
  info "AxonOps is running in namespace '$AXONOPS_NAMESPACE'."
  echo "  $KUBECTL_BIN get pods -n $AXONOPS_NAMESPACE"
  echo
  info "Dashboard:"
  if [[ "$AXON_DASH_INGRESS_ENABLED" == "true" ]]; then
    echo "  https://$AXON_DASH_INGRESS_HOST"
  elif [[ "$AXON_DASH_NODEPORT_ENABLED" == "true" ]]; then
    local port
    port="$($KUBECTL_BIN get svc "$dash_svc" -n "$AXONOPS_NAMESPACE" \
      -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')"
    echo "  http://<node-ip>:$port"
  else
    echo "  $KUBECTL_BIN port-forward -n $AXONOPS_NAMESPACE svc/$dash_svc 3000:$AXON_DASH_SERVICE_PORT"
    echo "  then open http://localhost:3000"
  fi
  echo
  info "Agents inside the cluster connect to:"
  echo "  ${_server_fullname}-agent.${AXONOPS_NAMESPACE}.svc.cluster.local:${AXON_SERVER_AGENTS_PORT}"
  if [[ "$AXON_SERVER_AGENT_INGRESS_ENABLED" == "true" ]]; then
    info "Agents outside the cluster connect to:"
    echo "  $AXON_SERVER_AGENT_INGRESS_HOST:443"
  fi
}

# Show what a real run would do, for RENDER_ONLY.
print_plan() {
  local r
  info "RENDER_ONLY=true: files written to $AXONOPS_OUTPUT_DIR, nothing applied."
  echo
  info "A real run would execute:"
  if uses_cert_manager; then
    if cert_manager_installed; then
      echo "  # cert-manager already installed: not installing it"
    elif [[ "$CERT_MANAGER_INSTALL" == "true" ]]; then
      echo "  $HELM_BIN upgrade --install $CERT_MANAGER_RELEASE_NAME $CERT_MANAGER_CHART_REPO --version $CERT_MANAGER_VERSION -n $NS_CERT_MANAGER --create-namespace --set crds.enabled=true --wait"
    else
      echo "  # cert-manager not found and CERT_MANAGER_INSTALL=false: a real run stops here"
    fi
    if cluster_issuer_exists; then
      echo "  # ClusterIssuer $CLUSTER_ISSUER_NAME exists: using it"
    elif [[ "$CLUSTER_ISSUER_CREATE" == "true" ]]; then
      echo "  $KUBECTL_BIN apply -f -  # create self-signed ClusterIssuer $CLUSTER_ISSUER_NAME"
    fi
  else
    echo "  # database TLS is off: cert-manager not used"
  fi
  for r in "$AXON_TIMESERIES_RELEASE_NAME $AXON_TIMESERIES_CHART $TIMESERIES_VALUES_FILE" \
           "$AXON_SEARCH_RELEASE_NAME $AXON_SEARCH_CHART $SEARCH_VALUES_FILE"; do
    # shellcheck disable=SC2086
    set -- $r
    echo "  $HELM_BIN upgrade --install $1 $2 -n $AXONOPS_NAMESPACE --create-namespace -f $3 $(helm_wait_args)"
  done
  echo "  $KUBECTL_BIN apply -f $SERVER_SECRET_FILE"
  echo "  $HELM_BIN upgrade --install $AXON_SERVER_RELEASE_NAME $AXON_SERVER_CHART -n $AXONOPS_NAMESPACE --create-namespace -f $SERVER_VALUES_FILE $(helm_wait_args)"
  echo "  $HELM_BIN upgrade --install $AXON_DASH_RELEASE_NAME $AXON_DASH_CHART -n $AXONOPS_NAMESPACE --create-namespace -f $DASH_VALUES_FILE $(helm_wait_args)"
  echo
  info "To preview the Kubernetes manifests, for example:"
  echo "  $HELM_BIN template $AXON_SERVER_RELEASE_NAME $AXON_SERVER_CHART -n $AXONOPS_NAMESPACE -f $SERVER_VALUES_FILE"
}

main() {
  local missing=0
  for var in AXON_SEARCH_PASSWORD AXON_SERVER_CQL_PASSWORD; do
    if [[ -z "${!var}" ]]; then
      error "$var is not set. Example: export $var=\"\$(openssl rand -base64 24)\""
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]] || exit 1
  check_tls_settings

  (umask 077 && mkdir -p "$AXONOPS_OUTPUT_DIR")
  umask 077

  generate_timeseries_values
  generate_search_values
  generate_server_secret
  generate_server_values
  generate_dash_values

  if [[ "$RENDER_ONLY" == "true" ]]; then
    print_plan
    exit 0
  fi

  if uses_cert_manager; then
    setup_cert_manager
  fi

  if [[ "$AXON_TIMESERIES_USE_HOSTPATH" == "true" && "$AXON_TIMESERIES_HOSTPATH_CREATE" == "true" ]]; then
    prepare_hostpath "$AXON_TIMESERIES_HOSTPATH_DIR" "$AXON_TIMESERIES_HOST_UID:$AXON_TIMESERIES_HOST_GID"
  fi
  helm_install "$AXON_TIMESERIES_RELEASE_NAME" "$AXON_TIMESERIES_CHART" "$TIMESERIES_VALUES_FILE" "$AXON_TIMESERIES_HELM_EXTRA_ARGS"

  if [[ "$AXON_SEARCH_USE_HOSTPATH" == "true" && "$AXON_SEARCH_HOSTPATH_CREATE" == "true" ]]; then
    prepare_hostpath "$AXON_SEARCH_HOSTPATH_DIR" "$AXON_SEARCH_HOST_UID:$AXON_SEARCH_HOST_GID"
  fi
  helm_install "$AXON_SEARCH_RELEASE_NAME" "$AXON_SEARCH_CHART" "$SEARCH_VALUES_FILE" "$AXON_SEARCH_HELM_EXTRA_ARGS"

  info "Applying Secret '$AXON_SERVER_SECRET_NAME'..."
  $KUBECTL_BIN apply -f "$SERVER_SECRET_FILE"
  helm_install "$AXON_SERVER_RELEASE_NAME" "$AXON_SERVER_CHART" "$SERVER_VALUES_FILE" "$AXON_SERVER_HELM_EXTRA_ARGS"

  helm_install "$AXON_DASH_RELEASE_NAME" "$AXON_DASH_CHART" "$DASH_VALUES_FILE" "$AXON_DASH_HELM_EXTRA_ARGS"

  print_access
}

main "$@"
