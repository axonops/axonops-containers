#!/usr/bin/env bash
# Enhanced Strimzi Kafka cluster deployment with node selector support
# This script extends the original with per-broker and per-controller node placement
#
# Node Selector Configuration:
#   KAFKA_BROKER_NODE_SELECTORS="broker-0:node1,broker-1:node2,broker-2:node3"
#   KAFKA_CONTROLLER_NODE_SELECTORS="controller-0:node1,controller-1:node2,controller-2:node3"
#
# Examples:
#   # All on same node (default behavior):
#   ./strimzi-setup-with-node-selectors.sh
#
#   # Specific node placement:
#   KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1,broker-1:worker-2,broker-2:worker-3" \
#   KAFKA_CONTROLLER_NODE_SELECTORS="controller-0:worker-1,controller-1:worker-2,controller-2:worker-3" \
#   ./strimzi-setup-with-node-selectors.sh
#
#   # Mixed deployment:
#   KAFKA_BROKER_NODE_SELECTORS="broker-0:nvme-node-1,broker-1:nvme-node-2" \
#   KAFKA_CONTROLLER_NODE_SELECTORS="controller-0:control-node-1" \
#   ./strimzi-setup-with-node-selectors.sh

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
# Storage mode configuration
STORAGE_MODE="${STORAGE_MODE:-hostPath}"              # Options: 'hostPath' or 'pvc'
STORAGE_CLASS="${STORAGE_CLASS:-}"                    # For PVC mode: empty = default storage class
STORAGE_SIZE="${STORAGE_SIZE:-10Gi}"                  # For PVC mode: size of PVCs

STRIMZI_STORAGECLASS_FILE="${STRIMZI_STORAGECLASS_FILE:-strimzi-storageclass.yaml}"
STRIMZI_CONTROLLER_VOLUMES_FILE="${STRIMZI_CONTROLLER_VOLUMES_FILE:-strimzi-controller-volumes.yaml}"
STRIMZI_BROKER_VOLUMES_FILE="${STRIMZI_BROKER_VOLUMES_FILE:-strimzi-broker-volumes.yaml}"
STRIMZI_KAFKA_RBAC_FILE="${STRIMZI_KAFKA_RBAC_FILE:-strimzi-kafka-rbac.yaml}"
STRIMZI_NODE_POOLS_FILE="${STRIMZI_NODE_POOLS_FILE:-strimzi-node-pools.yaml}"
STRIMZI_KAFKA_CLUSTER_FILE="${STRIMZI_KAFKA_CLUSTER_FILE:-strimzi-kafka-cluster.yaml}"

# Node affinity / host configuration
STRIMZI_NODE_HOSTNAME="${STRIMZI_NODE_HOSTNAME:-$(hostname)}"  # Default node for backward compatibility

# NEW: Node selector configuration
KAFKA_BROKER_NODE_SELECTORS="${KAFKA_BROKER_NODE_SELECTORS:-}"
KAFKA_CONTROLLER_NODE_SELECTORS="${KAFKA_CONTROLLER_NODE_SELECTORS:-}"

# Number of replicas (can be overridden)
KAFKA_BROKER_REPLICAS="${KAFKA_BROKER_REPLICAS:-3}"
KAFKA_CONTROLLER_REPLICAS="${KAFKA_CONTROLLER_REPLICAS:-3}"

# Kafka / Axon agent configuration
STRIMZI_CLUSTER_NAME="${STRIMZI_CLUSTER_NAME:-my-cluster}"
AXON_AGENT_CLUSTER_NAME="${AXON_AGENT_CLUSTER_NAME:-$STRIMZI_CLUSTER_NAME}"
AXON_AGENT_ORG="${AXON_AGENT_ORG:-your-org}"
AXON_AGENT_TLS_MODE="${AXON_AGENT_TLS_MODE:-false}"

# AxonOps Server connection
AXON_AGENT_SERVER_PORT="${AXON_AGENT_SERVER_PORT:-${AXON_SERVER_AGENTS_PORT:-1888}}"
AXON_AGENT_SERVER_HOST="${AXON_AGENT_SERVER_HOST:-axon-server-agent.$NS_AXONOPS.svc.cluster.local}"

# --- Strimzi hostPath directories on node & permissions ---
STRIMZI_HOST_BASE_DIR="${STRIMZI_HOST_BASE_DIR:-/data/strimzi}"
STRIMZI_HOST_CLUSTER_DIR="${STRIMZI_HOST_CLUSTER_DIR:-$STRIMZI_HOST_BASE_DIR/$STRIMZI_CLUSTER_NAME}"
STRIMZI_HOST_UID="${STRIMZI_HOST_UID:-1001}"
STRIMZI_HOST_GID="${STRIMZI_HOST_GID:-1001}"
STRIMZI_HOST_PERMS="${STRIMZI_HOST_PERMS:-755}"

############################################
# Helper functions
############################################

info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*"; }
error() { echo "[ERROR] $*" >&2; }

############################################
# Parse node selector configurations
############################################
declare -A broker_nodes
declare -A controller_nodes

parse_node_selectors() {
  info "Parsing node selector configurations..."

  # Parse broker node selectors
  if [[ -n "$KAFKA_BROKER_NODE_SELECTORS" ]]; then
    info "Parsing broker node selectors: $KAFKA_BROKER_NODE_SELECTORS"
    IFS=',' read -ra PAIRS <<< "$KAFKA_BROKER_NODE_SELECTORS"
    for pair in "${PAIRS[@]}"; do
      IFS=':' read -r replica node <<< "$pair"
      # Extract replica number from format like "broker-0" or just "0"
      replica_num="${replica#broker-}"
      broker_nodes[$replica_num]=$node
      info "  Broker $replica_num -> Node $node"
    done
  fi

  # Parse controller node selectors
  if [[ -n "$KAFKA_CONTROLLER_NODE_SELECTORS" ]]; then
    info "Parsing controller node selectors: $KAFKA_CONTROLLER_NODE_SELECTORS"
    IFS=',' read -ra PAIRS <<< "$KAFKA_CONTROLLER_NODE_SELECTORS"
    for pair in "${PAIRS[@]}"; do
      IFS=':' read -r replica node <<< "$pair"
      # Extract replica number from format like "controller-0" or just "0"
      replica_num="${replica#controller-}"
      controller_nodes[$replica_num]=$node
      info "  Controller $replica_num -> Node $node"
    done
  fi

  # If no selectors specified, use default node for all replicas
  if [[ ${#broker_nodes[@]} -eq 0 ]]; then
    info "No broker node selectors specified, using default node: $STRIMZI_NODE_HOSTNAME"
    for i in $(seq 0 $((KAFKA_BROKER_REPLICAS - 1))); do
      broker_nodes[$i]=$STRIMZI_NODE_HOSTNAME
    done
  fi

  if [[ ${#controller_nodes[@]} -eq 0 ]]; then
    info "No controller node selectors specified, using default node: $STRIMZI_NODE_HOSTNAME"
    for i in $(seq 0 $((KAFKA_CONTROLLER_REPLICAS - 1))); do
      controller_nodes[$i]=$STRIMZI_NODE_HOSTNAME
    done
  fi
}

############################################
# Validate node configurations
############################################
validate_nodes() {
  info "Validating node configurations..."

  local all_nodes=()
  local failed=false

  # Collect all unique nodes
  for node in "${broker_nodes[@]}"; do
    if [[ ! " ${all_nodes[@]} " =~ " ${node} " ]]; then
      all_nodes+=("$node")
    fi
  done

  for node in "${controller_nodes[@]}"; do
    if [[ ! " ${all_nodes[@]} " =~ " ${node} " ]]; then
      all_nodes+=("$node")
    fi
  done

  # Validate each node exists and is ready
  for node in "${all_nodes[@]}"; do
    info "Checking node: $node"

    # Check if node exists
    if ! $KUBECTL_BIN get node "$node" &>/dev/null; then
      error "Node $node not found in cluster"
      failed=true
      continue
    fi

    # Check if node is ready
    local node_ready=$($KUBECTL_BIN get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    if [[ "$node_ready" != "True" ]]; then
      warn "Node $node is not in Ready state (status: $node_ready)"
    else
      info "  Node $node is Ready"
    fi

    # Check for storage-related labels (optional)
    if $KUBECTL_BIN get node "$node" --show-labels | grep -q "kafka-storage=true"; then
      info "  Node $node has kafka-storage=true label"
    else
      warn "  Node $node lacks kafka-storage=true label (optional)"
    fi
  done

  if [[ "$failed" == "true" ]]; then
    error "Node validation failed. Please check your node configurations."
    error "Available nodes:"
    $KUBECTL_BIN get nodes
    exit 1
  fi

  info "Node validation completed successfully"
}

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
    info "  - Base Path: $STRIMZI_HOST_CLUSTER_DIR"

    # Show which nodes need storage directories
    info "Storage directories needed on nodes:"
    local shown_nodes=()
    for node in "${broker_nodes[@]}" "${controller_nodes[@]}"; do
      if [[ ! " ${shown_nodes[@]} " =~ " ${node} " ]]; then
        info "  - $node: $STRIMZI_HOST_CLUSTER_DIR"
        shown_nodes+=("$node")
      fi
    done
  else
    error "Invalid STORAGE_MODE: '$STORAGE_MODE'"
    error "Supported modes: 'hostPath' or 'pvc'"
    exit 1
  fi
}

############################################
# Check prerequisites
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
# Install cert-manager
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
# Install Strimzi Operator
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
# Prepare Strimzi hostPath directories
############################################
prepare_strimzi_hostpath() {
  # Only prepare directories for hostPath mode
  if [[ "$STORAGE_MODE" != "hostPath" ]]; then
    info "PVC storage mode selected - skipping local directory preparation"
    return 0
  fi

  info "Preparing Strimzi hostPath directories..."

  # Get unique nodes that need directories
  local unique_nodes=()
  for node in "${broker_nodes[@]}" "${controller_nodes[@]}"; do
    if [[ ! " ${unique_nodes[@]} " =~ " ${node} " ]]; then
      unique_nodes+=("$node")
    fi
  done

  warn "IMPORTANT: You need to create the following directories on the specified nodes:"
  echo ""

  for node in "${unique_nodes[@]}"; do
    echo "On node '$node':"
    echo "  sudo mkdir -p $STRIMZI_HOST_CLUSTER_DIR"

    # Show which specific directories are needed on this node
    for i in "${!controller_nodes[@]}"; do
      if [[ "${controller_nodes[$i]}" == "$node" ]]; then
        echo "  sudo mkdir -p $STRIMZI_HOST_CLUSTER_DIR/controller-$i"
      fi
    done

    for i in "${!broker_nodes[@]}"; do
      if [[ "${broker_nodes[$i]}" == "$node" ]]; then
        echo "  sudo mkdir -p $STRIMZI_HOST_CLUSTER_DIR/broker-pool-$i"
      fi
    done

    echo "  sudo chown -R ${STRIMZI_HOST_UID}:${STRIMZI_HOST_GID} $STRIMZI_HOST_BASE_DIR"
    echo "  sudo chmod -R ${STRIMZI_HOST_PERMS} $STRIMZI_HOST_BASE_DIR"
    echo ""
  done

  # If we're on one of the nodes, offer to create directories locally
  local current_hostname=$(hostname)
  if [[ " ${unique_nodes[@]} " =~ " ${current_hostname} " ]]; then
    read -p "Current hostname matches node '$current_hostname'. Create directories locally? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      # Create directories for this node
      for i in "${!controller_nodes[@]}"; do
        if [[ "${controller_nodes[$i]}" == "$current_hostname" ]]; then
          sudo mkdir -p "$STRIMZI_HOST_CLUSTER_DIR/controller-$i"
        fi
      done

      for i in "${!broker_nodes[@]}"; do
        if [[ "${broker_nodes[$i]}" == "$current_hostname" ]]; then
          sudo mkdir -p "$STRIMZI_HOST_CLUSTER_DIR/broker-pool-$i"
        fi
      done

      sudo chown -R "${STRIMZI_HOST_UID}:${STRIMZI_HOST_GID}" "$STRIMZI_HOST_BASE_DIR"
      sudo chmod -R "${STRIMZI_HOST_PERMS}" "$STRIMZI_HOST_BASE_DIR"

      info "Local directories created successfully"
    fi
  fi
}

############################################
# Generate PersistentVolumes with node affinity
############################################
generate_persistent_volumes() {
  if [[ "$STORAGE_MODE" != "hostPath" ]]; then
    return 0
  fi

  info "Generating PersistentVolumes with node affinity..."

  # Create temporary directory for generated PVs
  local temp_dir=$(mktemp -d)

  # Generate controller PVs
  cat > "$temp_dir/controller-volumes.yaml" <<EOF
# Generated Controller PersistentVolumes with node affinity
EOF

  for i in "${!controller_nodes[@]}"; do
    local node="${controller_nodes[$i]}"
    cat >> "$temp_dir/controller-volumes.yaml" <<EOF
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-${STRIMZI_CLUSTER_NAME}-controller-$i
  labels:
    strimzi.io/cluster: ${STRIMZI_CLUSTER_NAME}
    strimzi.io/pool: ${STRIMZI_CLUSTER_NAME}-controller
spec:
  capacity:
    storage: ${STRIMZI_CONTROLLER_STORAGE_SIZE:-5Gi}
  accessModes:
  - ReadWriteOnce
  volumeMode: Filesystem
  persistentVolumeReclaimPolicy: Retain
  storageClassName: strimzi-local-controller
  hostPath:
    path: ${STRIMZI_HOST_CLUSTER_DIR}/controller-$i
    type: Directory
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $node
EOF
  done

  # Generate broker PVs
  cat > "$temp_dir/broker-volumes.yaml" <<EOF
# Generated Broker PersistentVolumes with node affinity
EOF

  for i in "${!broker_nodes[@]}"; do
    local node="${broker_nodes[$i]}"
    cat >> "$temp_dir/broker-volumes.yaml" <<EOF
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-${STRIMZI_CLUSTER_NAME}-broker-pool-$i
  labels:
    strimzi.io/cluster: ${STRIMZI_CLUSTER_NAME}
    strimzi.io/pool: broker-pool
spec:
  capacity:
    storage: ${STRIMZI_BROKER_STORAGE_SIZE:-5Gi}
  accessModes:
  - ReadWriteOnce
  volumeMode: Filesystem
  persistentVolumeReclaimPolicy: Retain
  storageClassName: strimzi-local-broker
  hostPath:
    path: ${STRIMZI_HOST_CLUSTER_DIR}/broker-pool-$i
    type: Directory
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $node
EOF
  done

  # Apply the generated PVs
  info "Applying Controller PersistentVolumes..."
  $KUBECTL_BIN apply -n $NS_KAFKA -f "$temp_dir/controller-volumes.yaml"

  info "Applying Broker PersistentVolumes..."
  $KUBECTL_BIN apply -n $NS_KAFKA -f "$temp_dir/broker-volumes.yaml"

  # Clean up temp directory
  rm -rf "$temp_dir"
}

############################################
# Generate NodePools with pod affinity
############################################
generate_node_pools() {
  info "Generating KafkaNodePools with pod affinity..."

  local temp_dir=$(mktemp -d)

  # Generate controller node pool
  cat > "$temp_dir/node-pools.yaml" <<EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaNodePool
metadata:
  name: ${STRIMZI_CLUSTER_NAME}-controller
  namespace: ${NS_KAFKA}
  labels:
    strimzi.io/cluster: ${STRIMZI_CLUSTER_NAME}
spec:
  replicas: ${KAFKA_CONTROLLER_REPLICAS}
  roles: [controller]
  storage:
    type: jbod
    volumes:
    - id: 0
      type: persistent-claim
      size: ${STRIMZI_CONTROLLER_STORAGE_SIZE:-5Gi}
EOF

  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    echo "      class: strimzi-local-controller" >> "$temp_dir/node-pools.yaml"
  elif [[ -n "$STORAGE_CLASS" ]]; then
    echo "      class: $STORAGE_CLASS" >> "$temp_dir/node-pools.yaml"
  fi

  cat >> "$temp_dir/node-pools.yaml" <<EOF
      deleteClaim: false
      kraftMetadata: shared
  template:
    pod:
EOF

  # Add pod affinity for controllers if using specific nodes
  if [[ -n "$KAFKA_CONTROLLER_NODE_SELECTORS" ]]; then
    cat >> "$temp_dir/node-pools.yaml" <<EOF
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                strimzi.io/pool-name: ${STRIMZI_CLUSTER_NAME}-controller
            topologyKey: kubernetes.io/hostname
EOF
  fi

  cat >> "$temp_dir/node-pools.yaml" <<EOF
    kafkaContainer:
        env:
        - name: KAFKA_NODE_TYPE
          value: kraft-controller
EOF

  if [[ "$AXONOPS_AVAILABLE" == "true" ]]; then
    cat >> "$temp_dir/node-pools.yaml" <<EOF
        - name: AXON_AGENT_CLUSTER_NAME
          value: "${AXON_AGENT_CLUSTER_NAME}"
        - name: AXON_AGENT_ORG
          value: "${AXON_AGENT_ORG}"
        - name: AXON_AGENT_TLS_MODE
          value: "${AXON_AGENT_TLS_MODE}"
        - name: AXON_AGENT_SERVER_PORT
          value: "${AXON_AGENT_SERVER_PORT}"
        - name: AXON_AGENT_SERVER_HOST
          value: "${AXON_AGENT_SERVER_HOST}"
EOF
  fi

  # Generate broker node pool
  cat >> "$temp_dir/node-pools.yaml" <<EOF
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaNodePool
metadata:
  name: broker-pool
  namespace: ${NS_KAFKA}
  labels:
    strimzi.io/cluster: ${STRIMZI_CLUSTER_NAME}
spec:
  replicas: ${KAFKA_BROKER_REPLICAS}
  roles: [broker]
  storage:
    type: jbod
    volumes:
    - id: 0
      type: persistent-claim
      size: ${STRIMZI_BROKER_STORAGE_SIZE:-5Gi}
EOF

  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    echo "      class: strimzi-local-broker" >> "$temp_dir/node-pools.yaml"
  elif [[ -n "$STORAGE_CLASS" ]]; then
    echo "      class: $STORAGE_CLASS" >> "$temp_dir/node-pools.yaml"
  fi

  cat >> "$temp_dir/node-pools.yaml" <<EOF
      deleteClaim: false
  template:
    pod:
EOF

  # Add pod affinity for brokers if using specific nodes
  if [[ -n "$KAFKA_BROKER_NODE_SELECTORS" ]]; then
    cat >> "$temp_dir/node-pools.yaml" <<EOF
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                strimzi.io/pool-name: broker-pool
            topologyKey: kubernetes.io/hostname
EOF
  fi

  cat >> "$temp_dir/node-pools.yaml" <<EOF
    kafkaContainer:
        env:
        - name: KAFKA_NODE_TYPE
          value: kraft-broker
EOF

  if [[ "$AXONOPS_AVAILABLE" == "true" ]]; then
    cat >> "$temp_dir/node-pools.yaml" <<EOF
        - name: AXON_AGENT_CLUSTER_NAME
          value: "${AXON_AGENT_CLUSTER_NAME}"
        - name: AXON_AGENT_ORG
          value: "${AXON_AGENT_ORG}"
        - name: AXON_AGENT_TLS_MODE
          value: "${AXON_AGENT_TLS_MODE}"
        - name: AXON_AGENT_SERVER_PORT
          value: "${AXON_AGENT_SERVER_PORT}"
        - name: AXON_AGENT_SERVER_HOST
          value: "${AXON_AGENT_SERVER_HOST}"
EOF
  fi

  # Apply the generated NodePools
  info "Applying KafkaNodePools..."
  $KUBECTL_BIN apply -f "$temp_dir/node-pools.yaml"

  # Clean up temp directory
  rm -rf "$temp_dir"
}

############################################
# Apply Strimzi resources
############################################
apply_strimzi_resources() {
  info "Creating Kafka namespace '$NS_KAFKA' (if it does not exist)..."
  $KUBECTL_BIN create namespace "$NS_KAFKA" 2>/dev/null || true

  # Apply storage class if in hostPath mode
  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    info "Applying StorageClass..."
    if [[ -f "strimzi/$STRIMZI_STORAGECLASS_FILE" ]]; then
      $KUBECTL_BIN apply -n $NS_KAFKA -f "strimzi/$STRIMZI_STORAGECLASS_FILE"
    else
      # Create StorageClass inline if file doesn't exist
      cat <<EOF | $KUBECTL_BIN apply -n $NS_KAFKA -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: strimzi-local-controller
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: strimzi-local-broker
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
EOF
    fi

    # Generate and apply PersistentVolumes with node affinity
    generate_persistent_volumes
  fi

  # Apply RBAC
  info "Applying RBAC resources..."
  if [[ -f "strimzi/$STRIMZI_KAFKA_RBAC_FILE" ]]; then
    export STRIMZI_NAMESPACE="$NS_KAFKA"
    envsubst < "strimzi/$STRIMZI_KAFKA_RBAC_FILE" | $KUBECTL_BIN apply -n $NS_KAFKA -f -
  fi

  # Generate and apply NodePools with pod affinity
  generate_node_pools

  # Apply Kafka cluster configuration
  info "Applying Kafka cluster configuration..."
  if [[ -f "strimzi/$STRIMZI_KAFKA_CLUSTER_FILE" ]]; then
    export STRIMZI_NAMESPACE="$NS_KAFKA"
    envsubst < "strimzi/$STRIMZI_KAFKA_CLUSTER_FILE" | $KUBECTL_BIN apply -n $NS_KAFKA -f -
  fi
}

############################################
# Verify pod placement
############################################
verify_pod_placement() {
  info "Verifying pod placement..."

  local timeout=300  # 5 minutes timeout
  local elapsed=0
  local interval=10

  # Wait for pods to be scheduled
  info "Waiting for pods to be scheduled..."
  while [[ $elapsed -lt $timeout ]]; do
    local controller_pods=$($KUBECTL_BIN get pods -n "$NS_KAFKA" -l "strimzi.io/pool-name=${STRIMZI_CLUSTER_NAME}-controller" --no-headers 2>/dev/null | wc -l)
    local broker_pods=$($KUBECTL_BIN get pods -n "$NS_KAFKA" -l "strimzi.io/pool-name=broker-pool" --no-headers 2>/dev/null | wc -l)

    if [[ $controller_pods -ge ${KAFKA_CONTROLLER_REPLICAS} ]] && [[ $broker_pods -ge ${KAFKA_BROKER_REPLICAS} ]]; then
      break
    fi

    echo -n "."
    sleep $interval
    elapsed=$((elapsed + interval))
  done
  echo ""

  # Verify controller placement
  info "Controller pod placement:"
  for i in "${!controller_nodes[@]}"; do
    local expected_node="${controller_nodes[$i]}"
    local pod_name="${STRIMZI_CLUSTER_NAME}-controller-$i"
    local actual_node=$($KUBECTL_BIN get pod "$pod_name" -n "$NS_KAFKA" -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "not-found")

    if [[ "$actual_node" == "$expected_node" ]]; then
      info "  ✓ $pod_name on $actual_node (as expected)"
    elif [[ "$actual_node" == "not-found" ]]; then
      warn "  ? $pod_name not found yet (expected on $expected_node)"
    else
      warn "  ✗ $pod_name on $actual_node (expected on $expected_node)"
    fi
  done

  # Verify broker placement
  info "Broker pod placement:"
  for i in "${!broker_nodes[@]}"; do
    local expected_node="${broker_nodes[$i]}"
    local pod_name="broker-pool-$i"
    local actual_node=$($KUBECTL_BIN get pod "$pod_name" -n "$NS_KAFKA" -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "not-found")

    if [[ "$actual_node" == "$expected_node" ]]; then
      info "  ✓ $pod_name on $actual_node (as expected)"
    elif [[ "$actual_node" == "not-found" ]]; then
      warn "  ? $pod_name not found yet (expected on $expected_node)"
    else
      warn "  ✗ $pod_name on $actual_node (expected on $expected_node)"
    fi
  done
}

############################################
# Wait for Kafka cluster to be ready
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

  # Verify pod placement if node selectors were used
  if [[ -n "$KAFKA_BROKER_NODE_SELECTORS" ]] || [[ -n "$KAFKA_CONTROLLER_NODE_SELECTORS" ]]; then
    verify_pod_placement
  fi
}

############################################
# Display connection information
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

  # Display node placement configuration
  if [[ -n "$KAFKA_BROKER_NODE_SELECTORS" ]] || [[ -n "$KAFKA_CONTROLLER_NODE_SELECTORS" ]]; then
    info ""
    info "Node Placement Configuration:"
    info "  Controllers:"
    for i in "${!controller_nodes[@]}"; do
      info "    - Controller $i: ${controller_nodes[$i]}"
    done
    info "  Brokers:"
    for i in "${!broker_nodes[@]}"; do
      info "    - Broker $i: ${broker_nodes[$i]}"
    done
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
  echo "  # View all Kafka pods with their nodes"
  echo "  $KUBECTL_BIN get pods -n $NS_KAFKA -o wide"
  echo ""
  echo "  # View Kafka logs"
  echo "  $KUBECTL_BIN logs -n $NS_KAFKA -l strimzi.io/name=${STRIMZI_CLUSTER_NAME}-kafka -c kafka"
  echo ""
  echo "  # Verify pod placement"
  echo "  $KUBECTL_BIN get pods -n $NS_KAFKA -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName"
  echo ""
  echo "  # Create a test topic"
  echo "  $KUBECTL_BIN run kafka-producer -ti --image=quay.io/strimzi/kafka:latest-kafka-3.9.0 --rm=true --restart=Never -- bin/kafka-topics.sh --bootstrap-server ${STRIMZI_CLUSTER_NAME}-kafka-bootstrap:9092 --create --topic test-topic --partitions 3 --replication-factor 1"
}

############################################
# Main
############################################
main() {
  info "Starting deployment of Strimzi Kafka cluster with node selector support..."
  info ""

  # Parse node selector configurations
  parse_node_selectors

  # Validate storage configuration
  validate_storage_configuration
  info ""

  info "Configuration:"
  info "  Kafka Cluster Name: $STRIMZI_CLUSTER_NAME"
  info "  Storage Mode: $STORAGE_MODE"
  info "  Controller Replicas: $KAFKA_CONTROLLER_REPLICAS"
  info "  Broker Replicas: $KAFKA_BROKER_REPLICAS"

  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    info "  Storage Path: $STRIMZI_HOST_CLUSTER_DIR"
  else
    info "  PVC Size: $STORAGE_SIZE"
    if [[ -n "$STORAGE_CLASS" ]]; then
      info "  Storage Class: $STORAGE_CLASS"
    else
      info "  Storage Class: (default)"
    fi
  fi
  echo ""

  # Validate nodes before proceeding
  validate_nodes
  echo ""

  read -p "Continue with deployment? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Deployment cancelled"
    exit 0
  fi

  check_prerequisites
  install_strimzi_operator

  # Prepare directories if using hostPath
  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    prepare_strimzi_hostpath
  fi

  apply_strimzi_resources
  wait_for_kafka
  display_connection_info
}

main "$@"
