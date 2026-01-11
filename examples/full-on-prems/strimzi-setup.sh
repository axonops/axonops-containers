#!/usr/bin/env bash
# Deploy Strimzi Kafka cluster with flexible storage options and AxonOps integration
# This script should be run after axonops-setup.sh
#
# Storage Modes:
#   - hostPath (default): Uses local hostPath storage with custom StorageClass and PVs
#     Example: ./strimzi-setup.sh
#
#   - pvc: Uses dynamic PVC provisioning with existing StorageClass
#     Example with default storage class:
#       STORAGE_MODE=pvc STORAGE_SIZE=20Gi ./strimzi-setup.sh
#
#     Example with specific storage class:
#       STORAGE_MODE=pvc STORAGE_CLASS=fast-ssd STORAGE_SIZE=50Gi ./strimzi-setup.sh
#
# Key Environment Variables:
#   STORAGE_MODE      - Storage mode: "hostPath" (default) or "pvc"
#   STORAGE_CLASS     - For PVC mode: StorageClass name (empty = default class)
#   STORAGE_SIZE      - For PVC mode: Size of PVCs (e.g., "10Gi", "100Gi")

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
NS_STRIMZI_OPERATOR="${NS_STRIMZI_OPERATOR:-strimzi}"
NS_KAFKA="${NS_KAFKA:-kafka}"

# --- cert-manager ClusterIssuer (may already exist from AxonOps setup) ---
CLUSTER_ISSUER_NAME="${CLUSTER_ISSUER_NAME:-selfsigned-cluster-issuer}"
CLUSTER_ISSUER_KIND="${CLUSTER_ISSUER_KIND:-ClusterIssuer}"
CLUSTER_ISSUER_API_VERSION="${CLUSTER_ISSUER_API_VERSION:-cert-manager.io/v1}"

# --- Strimzi Operator ---
STRIMZI_HELM_REPO_NAME="${STRIMZI_HELM_REPO_NAME:-strimzi}"
STRIMZI_HELM_REPO_URL="${STRIMZI_HELM_REPO_URL:-https://strimzi.io/charts}"
STRIMZI_OPERATOR_RELEASE_NAME="${STRIMZI_OPERATOR_RELEASE_NAME:-strimzi-kafka-operator}"
STRIMZI_OPERATOR_CHART="${STRIMZI_OPERATOR_CHART:-strimzi/strimzi-kafka-operator}"
STRIMZI_OPERATOR_VERSION="${STRIMZI_OPERATOR_VERSION:-0.49.1}"
STRIMZI_OPERATOR_WATCH_ANY_NS="${STRIMZI_OPERATOR_WATCH_ANY_NS:-true}"

# --- Strimzi Storage / Volumes / RBAC / NodePools / Cluster manifests ---
# Storage mode configuration (NEW)
STORAGE_MODE="${STORAGE_MODE:-hostPath}"              # Options: 'hostPath' or 'pvc'
STORAGE_CLASS="${STORAGE_CLASS:-}"                    # For PVC mode: empty = default storage class
STORAGE_SIZE="${STORAGE_SIZE:-10Gi}"                  # For PVC mode: size of PVCs

STRIMZI_STORAGECLASS_FILE="${STRIMZI_STORAGECLASS_FILE:-strimzi-storageclass.yaml}"
STRIMZI_CONTROLLER_VOLUMES_FILE="${STRIMZI_CONTROLLER_VOLUMES_FILE:-strimzi-controller-volumes.yaml}"
STRIMZI_BROKER_VOLUMES_FILE="${STRIMZI_BROKER_VOLUMES_FILE:-strimzi-broker-volumes.yaml}"
STRIMZI_KAFKA_RBAC_FILE="${STRIMZI_KAFKA_RBAC_FILE:-strimzi-kafka-rbac.yaml}"
STRIMZI_NODE_POOLS_FILE="${STRIMZI_NODE_POOLS_FILE:-strimzi-node-pools.yaml}"
STRIMZI_KAFKA_CLUSTER_FILE="${STRIMZI_KAFKA_CLUSTER_FILE:-strimzi-kafka-cluster.yaml}"

# Node affinity / host configuration (must match PV manifests)
# This MUST be set to your actual Kubernetes node hostname
STRIMZI_NODE_HOSTNAME="${STRIMZI_NODE_HOSTNAME:-$(hostname)}"  # Default to current hostname, override with actual K8s node name

# Kafka / Axon agent configuration
STRIMZI_CLUSTER_NAME="${STRIMZI_CLUSTER_NAME:-my-cluster}"
AXON_AGENT_CLUSTER_NAME="${AXON_AGENT_CLUSTER_NAME:-$STRIMZI_CLUSTER_NAME}"
AXON_AGENT_ORG="${AXON_AGENT_ORG:-your-org}"
AXON_AGENT_TLS_MODE="${AXON_AGENT_TLS_MODE:-false}"

# AxonOps Server connection (from AxonOps setup or environment)
AXON_AGENT_SERVER_PORT="${AXON_AGENT_SERVER_PORT:-${AXON_SERVER_AGENTS_PORT:-1888}}"
AXON_AGENT_SERVER_HOST="${AXON_AGENT_SERVER_HOST:-axon-server-agent.$NS_AXONOPS.svc.cluster.local}"

# --- Strimzi hostPath directories on node & permissions ---
STRIMZI_HOST_BASE_DIR="${STRIMZI_HOST_BASE_DIR:-/data/strimzi}"
STRIMZI_HOST_CLUSTER_DIR="${STRIMZI_HOST_CLUSTER_DIR:-$STRIMZI_HOST_BASE_DIR/$STRIMZI_CLUSTER_NAME}"
STRIMZI_CONTROLLER_DIR_PATTERN="${STRIMZI_CONTROLLER_DIR_PATTERN:-controller-{0,1,2}}"
STRIMZI_BROKER_POOL_DIR_PATTERN="${STRIMZI_BROKER_POOL_DIR_PATTERN:-broker-pool-{0,1,2}}"
STRIMZI_HOST_UID="${STRIMZI_HOST_UID:-1001}"
STRIMZI_HOST_GID="${STRIMZI_HOST_GID:-1001}"  # Non-root for security
STRIMZI_HOST_PERMS="${STRIMZI_HOST_PERMS:-755}"

############################################
# Helper functions
############################################

info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*"; }
error() { echo "[ERROR] $*" >&2; }

############################################
# Validate storage configuration
############################################
validate_storage_configuration() {
  info "Validating storage configuration..."

  if [[ "$STORAGE_MODE" == "pvc" ]]; then
    info "Storage mode: PVC (Dynamic Provisioning)"
    info "  - PVC Size: $STORAGE_SIZE"

    if [[ -n "$STORAGE_CLASS" ]]; then
      # Check if specified storage class exists
      if ! $KUBECTL_BIN get storageclass "$STORAGE_CLASS" &>/dev/null; then
        error "Storage class '$STORAGE_CLASS' not found in cluster"
        error "Available storage classes:"
        $KUBECTL_BIN get storageclass
        exit 1
      fi
      info "  - Storage Class: $STORAGE_CLASS"
    else
      info "  - Storage Class: (default)"
    fi
  elif [[ "$STORAGE_MODE" == "hostPath" ]]; then
    info "Storage mode: hostPath (Local Storage)"
    info "  - Target Node: $STRIMZI_NODE_HOSTNAME"
    info "  - Base Path: $STRIMZI_HOST_CLUSTER_DIR"

    if [[ "$STRIMZI_NODE_HOSTNAME" == "$(hostname)" ]]; then
      warn "STRIMZI_NODE_HOSTNAME is set to current hostname '$(hostname)'"
      warn "Ensure this matches your actual Kubernetes node name"
    fi
  else
    error "Invalid STORAGE_MODE: '$STORAGE_MODE'"
    error "Supported modes: 'hostPath' or 'pvc'"
    exit 1
  fi
}

############################################
# 1. Check prerequisites
############################################
check_prerequisites() {
  info "Checking prerequisites..."

  # Check if cert-manager is installed
  if ! $KUBECTL_BIN get namespace "$NS_CERT_MANAGER" &>/dev/null; then
    warn "cert-manager namespace not found. Installing cert-manager..."
    install_cert_manager
  else
    info "cert-manager is already installed"
  fi

  # Check if ClusterIssuer exists
  if ! $KUBECTL_BIN get clusterissuer "$CLUSTER_ISSUER_NAME" &>/dev/null; then
    warn "ClusterIssuer '$CLUSTER_ISSUER_NAME' not found. Creating..."
    create_cluster_issuer
  else
    info "ClusterIssuer '$CLUSTER_ISSUER_NAME' already exists"
  fi

  # Check if AxonOps namespace exists (optional, for integration)
  if $KUBECTL_BIN get namespace "$NS_AXONOPS" &>/dev/null; then
    info "AxonOps namespace '$NS_AXONOPS' exists - AxonOps integration will be configured"
    AXONOPS_AVAILABLE="true"
  else
    warn "AxonOps namespace '$NS_AXONOPS' not found - Kafka cluster will be deployed without AxonOps agent"
    warn "Run axonops-setup.sh first if you want AxonOps integration"
    AXONOPS_AVAILABLE="false"
  fi
}

############################################
# 2. Install cert-manager (if needed)
############################################
install_cert_manager() {
  info "Installing cert-manager in namespace '$NS_CERT_MANAGER'..."

  # Add Jetstack Helm repository
  $HELM_BIN repo add jetstack https://charts.jetstack.io --force-update

  $HELM_BIN upgrade --install \
    cert-manager jetstack/cert-manager \
    --namespace "$NS_CERT_MANAGER" \
    --create-namespace \
    --version v1.19.1 \
    --set installCRDs=true

  info "Waiting for cert-manager to be ready..."
  $KUBECTL_BIN wait --for=condition=ready pod \
    --all -n "$NS_CERT_MANAGER" \
    --timeout=120s
}

create_cluster_issuer() {
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
# 3. Install Strimzi Operator
############################################
install_strimzi_operator() {
  info "Adding Strimzi Helm repo '$STRIMZI_HELM_REPO_NAME'..."
  $HELM_BIN repo add "$STRIMZI_HELM_REPO_NAME" "$STRIMZI_HELM_REPO_URL"
  $HELM_BIN repo update

  info "Installing Strimzi Kafka Operator..."
  $HELM_BIN upgrade --install "$STRIMZI_OPERATOR_RELEASE_NAME" "$STRIMZI_OPERATOR_CHART" \
    -n "$NS_STRIMZI_OPERATOR" \
    --create-namespace \
    --version "$STRIMZI_OPERATOR_VERSION" \
    --set "watchAnyNamespace=${STRIMZI_OPERATOR_WATCH_ANY_NS}"

  info "Waiting for Strimzi Operator to be ready..."
  $KUBECTL_BIN wait --for=condition=ready pod \
    -l "name=strimzi-cluster-operator" \
    -n "$NS_STRIMZI_OPERATOR" \
    --timeout=120s
}

############################################
# 4. Prepare Strimzi hostPath directories
############################################
prepare_strimzi_hostpath() {
  # Only prepare directories for hostPath mode
  if [[ "$STORAGE_MODE" != "hostPath" ]]; then
    info "PVC storage mode selected - skipping local directory preparation"
    return 0
  fi

  info "Preparing Strimzi hostPath directories on node under $STRIMZI_HOST_CLUSTER_DIR"

  # Check if running with sudo permissions
  if [[ $EUID -ne 0 ]]; then
    warn "Not running as root. Will attempt to use sudo for directory creation..."
  fi

  # Controller directories
  info "Creating controller directories..."
  sudo mkdir -p "${STRIMZI_HOST_CLUSTER_DIR}/controller-0" \
               "${STRIMZI_HOST_CLUSTER_DIR}/controller-1" \
               "${STRIMZI_HOST_CLUSTER_DIR}/controller-2"

  # Broker pool directories
  info "Creating broker pool directories..."
  sudo mkdir -p "${STRIMZI_HOST_CLUSTER_DIR}/broker-pool-0" \
               "${STRIMZI_HOST_CLUSTER_DIR}/broker-pool-1" \
               "${STRIMZI_HOST_CLUSTER_DIR}/broker-pool-2"

  # Set permissions
  info "Setting ownership and permissions..."
  sudo chown -R "${STRIMZI_HOST_UID}:${STRIMZI_HOST_GID}" "$STRIMZI_HOST_BASE_DIR"
  sudo chmod -R "${STRIMZI_HOST_PERMS}" "$STRIMZI_HOST_BASE_DIR"

  info "Directory structure created:"
  ls -la "$STRIMZI_HOST_CLUSTER_DIR"
}


############################################
# 5. Apply Strimzi resources
############################################
apply_strimzi_resources() {
  info "Creating Kafka namespace '$NS_KAFKA' (if it does not exist)..."
  $KUBECTL_BIN create namespace "$NS_KAFKA" 2>/dev/null || true

  info "Checking for required YAML files..."
  local required_files=(
    "$STRIMZI_KAFKA_RBAC_FILE"
    "$STRIMZI_NODE_POOLS_FILE"
    "$STRIMZI_KAFKA_CLUSTER_FILE"
  )

  # Only check for hostPath-specific files in hostPath mode
  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    required_files+=(
      "$STRIMZI_STORAGECLASS_FILE"
      "$STRIMZI_CONTROLLER_VOLUMES_FILE"
      "$STRIMZI_BROKER_VOLUMES_FILE"
    )
  fi

  for file in "${required_files[@]}"; do
    if [[ ! -f "strimzi/$file" ]]; then
      error "Required file not found: $file"
      error "Please ensure all Strimzi YAML files are in the current directory"
      exit 1
    fi
  done

  info "Checking for envsubst command..."
  if ! command -v envsubst &> /dev/null; then
    error "envsubst command not found. Please install it (usually part of gettext package)"
    error "On Ubuntu/Debian: sudo apt-get install gettext-base"
    error "On macOS: brew install gettext"
    exit 1
  fi

  # Set storage size variables based on mode
  if [[ "$STORAGE_MODE" == "pvc" ]]; then
    export STRIMZI_CONTROLLER_STORAGE_SIZE="${STORAGE_SIZE}"
    export STRIMZI_BROKER_STORAGE_SIZE="${STORAGE_SIZE}"
  else
    export STRIMZI_CONTROLLER_STORAGE_SIZE="5Gi"
    export STRIMZI_BROKER_STORAGE_SIZE="5Gi"
  fi

  # Export variables for envsubst to use
  export STRIMZI_NODE_HOSTNAME
  export STRIMZI_CLUSTER_NAME
  export AXON_AGENT_CLUSTER_NAME
  export AXON_AGENT_ORG
  export AXON_AGENT_TLS_MODE
  export AXON_AGENT_SERVER_PORT
  export AXON_AGENT_SERVER_HOST
  export NS_KAFKA
  export STRIMZI_HOST_CLUSTER_DIR
  export STRIMZI_NAMESPACE="$NS_KAFKA"

  info "Applying Strimzi resources with variable substitution..."

  # Apply storage resources only in hostPath mode
  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    info "Applying hostPath storage resources..."

    # Apply StorageClass (no substitution needed)
    info "Applying StorageClass..."
    $KUBECTL_BIN apply -n $NS_KAFKA -f "strimzi/$STRIMZI_STORAGECLASS_FILE"

    # Apply PersistentVolumes with substitution
    info "Applying Controller PersistentVolumes..."
    envsubst < "strimzi/$STRIMZI_CONTROLLER_VOLUMES_FILE" | $KUBECTL_BIN apply -n $NS_KAFKA -f -

    info "Applying Broker PersistentVolumes..."
    envsubst < "strimzi/$STRIMZI_BROKER_VOLUMES_FILE" | $KUBECTL_BIN apply -n $NS_KAFKA -f -
  else
    info "PVC mode selected - using dynamic provisioning, skipping StorageClass and PV creation"
  fi

  # Apply RBAC (may need substitution for namespace)
  info "Applying RBAC resources..."
  envsubst < "strimzi/$STRIMZI_KAFKA_RBAC_FILE" | $KUBECTL_BIN apply -n $NS_KAFKA -f -

  # Apply NodePools (needs substitution for AxonOps agent config and storage)
  info "Applying Kafka NodePools..."

  # Process NodePools YAML with dynamic storage class insertion
  local nodepool_yaml=$(envsubst < "strimzi/$STRIMZI_NODE_POOLS_FILE")

  # Add storage class fields based on storage mode
  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    # Insert storage class after size for controller nodepool
    nodepool_yaml=$(echo "$nodepool_yaml" | awk '
      /name: .*-controller$/ {controller=1}
      /name: broker-pool$/ {controller=0}
      /size: .*Gi$/ && controller {print $0 "\n      class: strimzi-local-controller"; next}
      /size: .*Gi$/ && !controller {print $0 "\n      class: strimzi-local-broker"; next}
      {print}
    ')
  elif [[ -n "$STORAGE_CLASS" ]]; then
    # Insert specified storage class for both nodepools
    nodepool_yaml=$(echo "$nodepool_yaml" | awk -v sc="$STORAGE_CLASS" '
      /size: .*Gi$/ {print $0 "\n      class: " sc; next}
      {print}
    ')
  fi
  # If PVC with default storage class (empty STORAGE_CLASS), don't add class field

  if [[ "$AXONOPS_AVAILABLE" == "true" ]]; then
    info "Configuring NodePools with AxonOps agent..."
    echo "$nodepool_yaml" | $KUBECTL_BIN apply -n $NS_KAFKA -f -
  else
    warn "Applying NodePools without AxonOps agent configuration..."
    # Remove AxonOps agent annotations if AxonOps is not available
    echo "$nodepool_yaml" | sed '/axon.ops.io/d' | $KUBECTL_BIN -n $NS_KAFKA apply -f -
  fi

  # Apply Kafka cluster (may need substitution)
  info "Applying Kafka cluster configuration..."
  envsubst < "strimzi/$STRIMZI_KAFKA_CLUSTER_FILE" | $KUBECTL_BIN -n $NS_KAFKA apply -f -
}

############################################
# 6. Wait for Kafka cluster to be ready
############################################
wait_for_kafka() {
  info "Waiting for Kafka cluster '$STRIMZI_CLUSTER_NAME' to be ready..."

  # Wait for Kafka custom resource to be ready
  info "Monitoring Kafka cluster status (this may take several minutes)..."

  local timeout=600  # 10 minutes timeout
  local elapsed=0
  local interval=10

  while [[ $elapsed -lt $timeout ]]; do
    if $KUBECTL_BIN get kafka "$STRIMZI_CLUSTER_NAME" -n "$NS_KAFKA" &>/dev/null; then
      local status=$($KUBECTL_BIN get kafka "$STRIMZI_CLUSTER_NAME" -n "$NS_KAFKA" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
      if [[ "$status" == "True" ]]; then
        info "Kafka cluster is ready!"
        break
      fi
    fi

    echo -n "."
    sleep $interval
    elapsed=$((elapsed + interval))
  done

  if [[ $elapsed -ge $timeout ]]; then
    error "Timeout waiting for Kafka cluster to be ready"
    error "Check the status with: $KUBECTL_BIN get kafka -n $NS_KAFKA"
    exit 1
  fi

  # Show pod status
  info "Kafka pods status:"
  $KUBECTL_BIN get pods -n "$NS_KAFKA" -l "strimzi.io/cluster=$STRIMZI_CLUSTER_NAME"
}

############################################
# 7. Display connection information
############################################
display_connection_info() {
  info ""
  info "============================================"
  info "Strimzi Kafka Cluster Deployment Complete!"
  info "============================================"
  info ""
  info "Cluster Name: $STRIMZI_CLUSTER_NAME"
  info "Namespace: $NS_KAFKA"
  info "Storage Mode: $STORAGE_MODE"

  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    info "Storage Path: $STRIMZI_HOST_CLUSTER_DIR"
  else
    info "PVC Size: $STORAGE_SIZE"
    if [[ -n "$STORAGE_CLASS" ]]; then
      info "Storage Class: $STORAGE_CLASS"
    else
      info "Storage Class: (default)"
    fi
  fi

  info ""
  info "Bootstrap servers:"
  echo "  - Internal: ${STRIMZI_CLUSTER_NAME}-kafka-bootstrap.${NS_KAFKA}.svc.cluster.local:9092"

  if [[ "$AXONOPS_AVAILABLE" == "true" ]]; then
    info ""
    info "AxonOps Integration:"
    echo "  - Agent configured to connect to: $AXON_AGENT_SERVER_HOST:$AXON_AGENT_SERVER_PORT"
    echo "  - Organization: $AXON_AGENT_ORG"
    echo "  - Cluster name in AxonOps: $AXON_AGENT_CLUSTER_NAME"
  fi

  info ""
  info "Useful commands:"
  echo "  # View Kafka cluster status"
  echo "  $KUBECTL_BIN get kafka -n $NS_KAFKA"
  echo ""
  echo "  # View all Kafka pods"
  echo "  $KUBECTL_BIN get pods -n $NS_KAFKA"
  echo ""
  echo "  # View Kafka logs"
  echo "  $KUBECTL_BIN logs -n $NS_KAFKA -l strimzi.io/name=${STRIMZI_CLUSTER_NAME}-kafka -c kafka"
  echo ""
  echo "  # Create a test topic"
  echo "  $KUBECTL_BIN run kafka-producer -ti --image=quay.io/strimzi/kafka:latest-kafka-3.9.0 --rm=true --restart=Never -- bin/kafka-topics.sh --bootstrap-server ${STRIMZI_CLUSTER_NAME}-kafka-bootstrap:9092 --create --topic test-topic --partitions 3 --replication-factor 1"
}

############################################
# Main
############################################
main() {
  info "Starting deployment of Strimzi Kafka cluster..."
  info ""

  # Validate storage configuration first
  validate_storage_configuration
  info ""

  info "Configuration:"
  info "  Kafka Cluster Name: $STRIMZI_CLUSTER_NAME"
  info "  Storage Mode: $STORAGE_MODE"

  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    info "  Target Node: $STRIMZI_NODE_HOSTNAME"
    info "  Storage Path: $STRIMZI_HOST_CLUSTER_DIR"
    warn ""
    warn "IMPORTANT: Ensure '$STRIMZI_NODE_HOSTNAME' matches your actual Kubernetes node name"
    warn "You can check node names with: $KUBECTL_BIN get nodes"
  else
    info "  PVC Size: $STORAGE_SIZE"
    if [[ -n "$STORAGE_CLASS" ]]; then
      info "  Storage Class: $STORAGE_CLASS"
    else
      info "  Storage Class: (default)"
    fi
  fi
  echo ""

  read -p "Continue with deployment? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Deployment cancelled"
    exit 0
  fi

  check_prerequisites
  install_strimzi_operator

  # Only prepare hostPath directories in hostPath mode
  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    warn "Directory creation requires sudo access on the Kubernetes node"
    warn "If running remotely, ensure you have created the directories on the target node"
    prepare_strimzi_hostpath
  fi

  apply_strimzi_resources
  wait_for_kafka
  display_connection_info
}

main "$@"