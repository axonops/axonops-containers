#!/usr/bin/env bash
# Deploy K8ssandra cluster with flexible storage options and AxonOps integration
# This script should be run after axonops-setup.sh (if AxonOps integration is desired)
#
# Storage Modes:
#   - hostPath (default): Uses local hostPath storage with local-path-provisioner
#     Example: ./k8ssandra-setup.sh
#
#   - pvc: Uses dynamic PVC provisioning with existing StorageClass
#     Example with default storage class:
#       STORAGE_MODE=pvc STORAGE_SIZE=20Gi ./k8ssandra-setup.sh
#
#     Example with specific storage class:
#       STORAGE_MODE=pvc STORAGE_CLASS=fast-ssd STORAGE_SIZE=50Gi ./k8ssandra-setup.sh
#
# Key Environment Variables:
#   STORAGE_MODE      - Storage mode: "hostPath" (default) or "pvc"
#   STORAGE_CLASS     - For PVC mode: StorageClass name (empty = default class)
#   STORAGE_SIZE      - Size of PVCs (e.g., "10Gi", "100Gi")
#   NODES_PER_RACK    - Number of Cassandra nodes per rack (default: 1)
#   RACK_COUNT        - Number of racks (default: 3)

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
NS_K8SSANDRA="${NS_K8SSANDRA:-k8ssandra}"

# --- cert-manager ClusterIssuer (may already exist from AxonOps setup) ---
CLUSTER_ISSUER_NAME="${CLUSTER_ISSUER_NAME:-selfsigned-cluster-issuer}"
CLUSTER_ISSUER_KIND="${CLUSTER_ISSUER_KIND:-ClusterIssuer}"
CLUSTER_ISSUER_API_VERSION="${CLUSTER_ISSUER_API_VERSION:-cert-manager.io/v1}"

# --- K8ssandra Operator ---
K8SSANDRA_HELM_REPO_NAME="${K8SSANDRA_HELM_REPO_NAME:-k8ssandra}"
K8SSANDRA_HELM_REPO_URL="${K8SSANDRA_HELM_REPO_URL:-https://helm.k8ssandra.io/}"
K8SSANDRA_OPERATOR_RELEASE_NAME="${K8SSANDRA_OPERATOR_RELEASE_NAME:-k8ssandra-operator}"
K8SSANDRA_OPERATOR_CHART="${K8SSANDRA_OPERATOR_CHART:-k8ssandra/k8ssandra-operator}"
K8SSANDRA_OPERATOR_VERSION="${K8SSANDRA_OPERATOR_VERSION:-}"  # Empty = latest version

# --- K8ssandra Cluster Configuration ---
K8SSANDRA_CLUSTER_NAME="${K8SSANDRA_CLUSTER_NAME:-my-k8ssandra-cluster}"
CASSANDRA_VERSION="${CASSANDRA_VERSION:-4.1.3}"
DATACENTER_NAME="${DATACENTER_NAME:-dc1}"
NODES_PER_RACK="${NODES_PER_RACK:-1}"
RACK_COUNT="${RACK_COUNT:-3}"
REPLICATION_FACTOR="${REPLICATION_FACTOR:-3}"
CASSANDRA_HEAP_SIZE="${CASSANDRA_HEAP_SIZE:-1Gi}"
CASSANDRA_HEAP_MAX="${CASSANDRA_HEAP_MAX:-1Gi}"

# --- Storage Mode Configuration ---
STORAGE_MODE="${STORAGE_MODE:-hostPath}"              # Options: 'hostPath' or 'pvc'
STORAGE_CLASS="${STORAGE_CLASS:-}"                    # For PVC mode: empty = default storage class
STORAGE_SIZE="${STORAGE_SIZE:-10Gi}"                  # Size of PVCs
LOCAL_PATH_PROVISIONER_VERSION="${LOCAL_PATH_PROVISIONER_VERSION:-v0.0.26}"

# --- K8ssandra manifest files ---
K8SSANDRA_CLUSTER_FILE="${K8SSANDRA_CLUSTER_FILE:-k8ssandra-cluster.yaml}"

# --- AxonOps Integration (optional) ---
AXONOPS_ENABLED="${AXONOPS_ENABLED:-auto}"  # auto, true, or false
AXON_AGENT_CLUSTER_NAME="${AXON_AGENT_CLUSTER_NAME:-$K8SSANDRA_CLUSTER_NAME}"
AXON_AGENT_ORG="${AXON_AGENT_ORG:-your-org}"
AXON_AGENT_TLS_MODE="${AXON_AGENT_TLS_MODE:-false}"

# AxonOps Server connection (from AxonOps setup or environment)
AXON_AGENT_SERVER_PORT="${AXON_AGENT_SERVER_PORT:-${AXON_SERVER_AGENTS_PORT:-1888}}"
AXON_AGENT_SERVER_HOST="${AXON_AGENT_SERVER_HOST:-axon-server-agent.$NS_AXONOPS.svc.cluster.local}"

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
    info "Storage mode: hostPath (Local Storage with local-path-provisioner)"
    info "  - Storage Size: $STORAGE_SIZE"
  else
    error "Invalid STORAGE_MODE: '$STORAGE_MODE'"
    error "Supported modes: 'hostPath' or 'pvc'"
    exit 1
  fi
}

############################################
# Validate cluster configuration
############################################
validate_cluster_configuration() {
  info "Validating cluster configuration..."

  local total_nodes=$((NODES_PER_RACK * RACK_COUNT))
  info "  - Cluster Name: $K8SSANDRA_CLUSTER_NAME"
  info "  - Cassandra Version: $CASSANDRA_VERSION"
  info "  - Datacenter: $DATACENTER_NAME"
  info "  - Topology: $RACK_COUNT racks × $NODES_PER_RACK nodes = $total_nodes total nodes"
  info "  - Replication Factor: $REPLICATION_FACTOR"

  if [[ $REPLICATION_FACTOR -gt $total_nodes ]]; then
    warn "Replication factor ($REPLICATION_FACTOR) is greater than total nodes ($total_nodes)"
    warn "This may cause issues with keyspace creation"
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
  if [[ "$AXONOPS_ENABLED" == "auto" ]]; then
    if $KUBECTL_BIN get namespace "$NS_AXONOPS" &>/dev/null; then
      info "AxonOps namespace '$NS_AXONOPS' exists - AxonOps integration will be configured"
      AXONOPS_AVAILABLE="true"
    else
      warn "AxonOps namespace '$NS_AXONOPS' not found - K8ssandra cluster will be deployed without AxonOps agent"
      warn "Run axonops-setup.sh first if you want AxonOps integration"
      AXONOPS_AVAILABLE="false"
    fi
  elif [[ "$AXONOPS_ENABLED" == "true" ]]; then
    AXONOPS_AVAILABLE="true"
  else
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
# 3. Install K8ssandra Operator
############################################
install_k8ssandra_operator() {
  info "Adding K8ssandra Helm repo '$K8SSANDRA_HELM_REPO_NAME'..."
  $HELM_BIN repo add "$K8SSANDRA_HELM_REPO_NAME" "$K8SSANDRA_HELM_REPO_URL"
  $HELM_BIN repo update

  # Check if operator is already installed
  if $HELM_BIN list -n k8ssandra-operator | grep -q k8ssandra-operator; then
    info "K8ssandra operator is already installed"
  else
    info "Installing K8ssandra operator..."

    # Get latest version if not specified
    if [[ -z "$K8SSANDRA_OPERATOR_VERSION" ]]; then
      K8SSANDRA_OPERATOR_VERSION=$($HELM_BIN search repo k8ssandra/k8ssandra-operator --versions | grep -v NAME | head -1 | awk '{print $2}')
      info "Using latest K8ssandra operator version: $K8SSANDRA_OPERATOR_VERSION"
    fi

    $HELM_BIN upgrade --install "$K8SSANDRA_OPERATOR_RELEASE_NAME" "$K8SSANDRA_OPERATOR_CHART" \
      -n k8ssandra-operator \
      --create-namespace \
      --version "$K8SSANDRA_OPERATOR_VERSION"

    info "Waiting for K8ssandra operator to be ready..."
    $KUBECTL_BIN wait --for=condition=ready pod \
      -l "app.kubernetes.io/name=k8ssandra-operator" \
      -n k8ssandra-operator \
      --timeout=120s
  fi
}

############################################
# 4. Prepare storage
############################################
prepare_storage() {
  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    info "Setting up local-path-provisioner for hostPath storage..."

    # Check if local-path-provisioner is already installed
    if ! $KUBECTL_BIN get namespace local-path-storage &>/dev/null; then
      info "Installing local-path-provisioner..."

      # Download and apply the manifest
      local provisioner_url="https://raw.githubusercontent.com/rancher/local-path-provisioner/${LOCAL_PATH_PROVISIONER_VERSION}/deploy/local-path-storage.yaml"
      $KUBECTL_BIN apply -f "$provisioner_url"

      info "Waiting for local-path-provisioner to be ready..."
      $KUBECTL_BIN wait --for=condition=ready pod \
        -l app=local-path-provisioner \
        -n local-path-storage \
        --timeout=120s

      # Set local-path as the actual storage class to use
      export ACTUAL_STORAGE_CLASS="local-path"
    else
      info "local-path-provisioner is already installed"
      export ACTUAL_STORAGE_CLASS="local-path"
    fi
  else
    # PVC mode - use the specified or default storage class
    if [[ -n "$STORAGE_CLASS" ]]; then
      export ACTUAL_STORAGE_CLASS="$STORAGE_CLASS"
    else
      # Get default storage class
      DEFAULT_SC=$($KUBECTL_BIN get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' | head -n1)
      if [[ -n "$DEFAULT_SC" ]]; then
        info "Using default storage class: $DEFAULT_SC"
        export ACTUAL_STORAGE_CLASS="$DEFAULT_SC"
      else
        warn "No default storage class found. PVCs may not bind automatically."
        export ACTUAL_STORAGE_CLASS=""
      fi
    fi
  fi
}

############################################
# 5. Generate K8ssandra cluster manifest
############################################
generate_k8ssandra_cluster_yaml() {
  info "Generating K8ssandra cluster manifest..."

  local total_nodes=$((NODES_PER_RACK * RACK_COUNT))

  # Start building the YAML
  cat > "k8ssandra/$K8SSANDRA_CLUSTER_FILE" <<EOF
apiVersion: k8ssandra.io/v1alpha1
kind: K8ssandraCluster
metadata:
  name: ${K8SSANDRA_CLUSTER_NAME}
  namespace: ${NS_K8SSANDRA}
spec:
  cassandra:
    clusterName: ${K8SSANDRA_CLUSTER_NAME}
    serverVersion: ${CASSANDRA_VERSION}
    datacenters:
    - metadata:
        name: ${DATACENTER_NAME}
      size: ${total_nodes}
      cassandraConfig:
        jvmOptions:
          heap_size: ${CASSANDRA_HEAP_SIZE}
          heap_max_size: ${CASSANDRA_HEAP_MAX}
EOF

  # Add AxonOps agent configuration if enabled
  if [[ "$AXONOPS_AVAILABLE" == "true" ]]; then
    cat >> "k8ssandra/$K8SSANDRA_CLUSTER_FILE" <<EOF
          additionalJvmOptions:
          - -javaagent:/opt/axon-agent/axon-agent.jar
          - -Daxon.agent.server.host=${AXON_AGENT_SERVER_HOST}
          - -Daxon.agent.server.port=${AXON_AGENT_SERVER_PORT}
          - -Daxon.agent.org=${AXON_AGENT_ORG}
          - -Daxon.agent.cluster.name=${AXON_AGENT_CLUSTER_NAME}
          - -Daxon.agent.tls=${AXON_AGENT_TLS_MODE}
EOF
  fi

  # Continue with the rest of the configuration
  cat >> "k8ssandra/$K8SSANDRA_CLUSTER_FILE" <<EOF
      storageConfig:
        cassandraDataVolumeClaimSpec:
          storageClassName: ${ACTUAL_STORAGE_CLASS}
          accessModes:
          - ReadWriteOnce
          resources:
            requests:
              storage: ${STORAGE_SIZE}
      racks:
EOF

  # Generate rack configurations
  for ((i=1; i<=RACK_COUNT; i++)); do
    cat >> "k8ssandra/$K8SSANDRA_CLUSTER_FILE" <<EOF
      - name: rack${i}
        nodeAffinityLabels:
          topology.kubernetes.io/zone: zone${i}
        nodes: ${NODES_PER_RACK}
EOF
  done

  # Add AxonOps sidecar if enabled
  if [[ "$AXONOPS_AVAILABLE" == "true" ]]; then
    cat >> "k8ssandra/$K8SSANDRA_CLUSTER_FILE" <<EOF
      additionalContainers:
      - name: axon-agent
        image: axonops/axon-agent:latest
        env:
        - name: AXON_AGENT_SERVER_HOST
          value: "${AXON_AGENT_SERVER_HOST}"
        - name: AXON_AGENT_SERVER_PORT
          value: "${AXON_AGENT_SERVER_PORT}"
        - name: AXON_AGENT_ORG
          value: "${AXON_AGENT_ORG}"
        - name: AXON_AGENT_CLUSTER_NAME
          value: "${AXON_AGENT_CLUSTER_NAME}"
        - name: AXON_AGENT_TLS_MODE
          value: "${AXON_AGENT_TLS_MODE}"
        volumeMounts:
        - name: server-logs
          mountPath: /var/log/cassandra
        - name: axon-agent
          mountPath: /opt/axon-agent
      additionalVolumes:
      - name: axon-agent
        emptyDir: {}
      initContainers:
      - name: axon-agent-init
        image: busybox:1.33.1
        command:
        - /bin/sh
        - -c
        - |
          echo "Downloading AxonOps agent..."
          wget -O /opt/axon-agent/axon-agent.jar \
            https://github.com/axonops/axon-agent/releases/latest/download/axon-agent.jar
        volumeMounts:
        - name: axon-agent
          mountPath: /opt/axon-agent
EOF
  fi

  # Add telemetry and monitoring configuration
  cat >> "k8ssandra/$K8SSANDRA_CLUSTER_FILE" <<EOF
  telemetry:
    prometheus:
      enabled: true
  reaper:
    enabled: true
    autoScheduling:
      enabled: true
  stargate:
    enabled: false  # Enable if you need Stargate API
EOF

  info "K8ssandra cluster manifest generated at k8ssandra/$K8SSANDRA_CLUSTER_FILE"
}

############################################
# 6. Apply K8ssandra resources
############################################
apply_k8ssandra_resources() {
  info "Creating K8ssandra namespace '$NS_K8SSANDRA' (if it does not exist)..."
  $KUBECTL_BIN create namespace "$NS_K8SSANDRA" 2>/dev/null || true

  info "Checking for required YAML files..."
  if [[ ! -f "k8ssandra/$K8SSANDRA_CLUSTER_FILE" ]]; then
    error "Required file not found: k8ssandra/$K8SSANDRA_CLUSTER_FILE"
    error "Run generate_k8ssandra_cluster_yaml first"
    exit 1
  fi

  info "Applying K8ssandra cluster configuration..."
  $KUBECTL_BIN apply -n "$NS_K8SSANDRA" -f "k8ssandra/$K8SSANDRA_CLUSTER_FILE"
}

############################################
# 7. Wait for K8ssandra cluster to be ready
############################################
wait_for_k8ssandra() {
  info "Waiting for K8ssandra cluster '$K8SSANDRA_CLUSTER_NAME' to be ready..."

  local total_nodes=$((NODES_PER_RACK * RACK_COUNT))
  local timeout=900  # 15 minutes timeout
  local elapsed=0
  local interval=10

  # Wait for K8ssandraCluster resource to exist
  info "Waiting for K8ssandraCluster resource to be created..."
  while [[ $elapsed -lt $timeout ]]; do
    if $KUBECTL_BIN get k8ssandracluster "$K8SSANDRA_CLUSTER_NAME" -n "$NS_K8SSANDRA" &>/dev/null; then
      break
    fi
    echo -n "."
    sleep $interval
    elapsed=$((elapsed + interval))
  done

  # Wait for the cluster to be ready
  info "Monitoring K8ssandra cluster status (this may take several minutes)..."
  elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    if $KUBECTL_BIN get k8ssandracluster "$K8SSANDRA_CLUSTER_NAME" -n "$NS_K8SSANDRA" &>/dev/null; then
      local ready_condition=$($KUBECTL_BIN get k8ssandracluster "$K8SSANDRA_CLUSTER_NAME" -n "$NS_K8SSANDRA" -o jsonpath='{.status.datacenters..cassandra.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
      if [[ "$ready_condition" == "True" ]]; then
        info "K8ssandra cluster is ready!"
        break
      fi
    fi

    echo -n "."
    sleep $interval
    elapsed=$((elapsed + interval))
  done

  if [[ $elapsed -ge $timeout ]]; then
    error "Timeout waiting for K8ssandra cluster to be ready"
    error "Check the status with: $KUBECTL_BIN get k8ssandracluster -n $NS_K8SSANDRA"
    exit 1
  fi

  # Wait for Cassandra pods
  info "Waiting for Cassandra pods to be ready..."
  local ready_pods=0
  elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    ready_pods=$($KUBECTL_BIN get pods -n "$NS_K8SSANDRA" -l "cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME" --field-selector=status.phase=Running 2>/dev/null | grep -c Running || true)

    if [[ "$ready_pods" -eq "$total_nodes" ]]; then
      info "All $total_nodes Cassandra pods are running!"
      break
    fi

    info "Waiting... ($ready_pods/$total_nodes pods ready)"
    sleep $interval
    elapsed=$((elapsed + interval))
  done

  if [[ "$ready_pods" -ne "$total_nodes" ]]; then
    warn "Not all pods are ready. Current status:"
    $KUBECTL_BIN get pods -n "$NS_K8SSANDRA" -l "cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME"
  fi

  # Show pod status
  info "Cassandra pods status:"
  $KUBECTL_BIN get pods -n "$NS_K8SSANDRA" -l "cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME"
}

############################################
# 8. Display connection information
############################################
display_connection_info() {
  info ""
  info "============================================"
  info "K8ssandra Cluster Deployment Complete!"
  info "============================================"
  info ""
  info "Cluster Name: $K8SSANDRA_CLUSTER_NAME"
  info "Namespace: $NS_K8SSANDRA"
  info "Storage Mode: $STORAGE_MODE"

  if [[ "$STORAGE_MODE" == "hostPath" ]]; then
    info "Storage Class: local-path (local-path-provisioner)"
  else
    info "Storage Class: ${ACTUAL_STORAGE_CLASS:-default}"
    info "Storage Size: $STORAGE_SIZE"
  fi

  local total_nodes=$((NODES_PER_RACK * RACK_COUNT))
  info "Topology: $RACK_COUNT racks × $NODES_PER_RACK nodes = $total_nodes total nodes"

  if [[ "$AXONOPS_AVAILABLE" == "true" ]]; then
    info ""
    info "AxonOps Integration:"
    echo "  - Agent configured to connect to: $AXON_AGENT_SERVER_HOST:$AXON_AGENT_SERVER_PORT"
    echo "  - Organization: $AXON_AGENT_ORG"
    echo "  - Cluster name in AxonOps: $AXON_AGENT_CLUSTER_NAME"
  fi

  # Get superuser secret
  local superuser_secret="${K8SSANDRA_CLUSTER_NAME}-superuser"
  if $KUBECTL_BIN get secret "$superuser_secret" -n "$NS_K8SSANDRA" &>/dev/null; then
    local username=$($KUBECTL_BIN get secret "$superuser_secret" -n "$NS_K8SSANDRA" -o jsonpath='{.data.username}' | base64 -d)
    local password=$($KUBECTL_BIN get secret "$superuser_secret" -n "$NS_K8SSANDRA" -o jsonpath='{.data.password}' | base64 -d)

    info ""
    info "Database Credentials:"
    echo "  Username: $username"
    echo "  Password: $password"
  fi

  info ""
  info "Useful commands:"
  echo "  # View K8ssandra cluster status"
  echo "  $KUBECTL_BIN get k8ssandracluster -n $NS_K8SSANDRA"
  echo ""
  echo "  # View all Cassandra pods"
  echo "  $KUBECTL_BIN get pods -n $NS_K8SSANDRA"
  echo ""
  echo "  # Access CQL shell"
  echo "  $KUBECTL_BIN exec -it -n $NS_K8SSANDRA ${K8SSANDRA_CLUSTER_NAME}-${DATACENTER_NAME}-rack1-sts-0 -- cqlsh"
  echo ""
  echo "  # Port-forward CQL service"
  echo "  $KUBECTL_BIN port-forward -n $NS_K8SSANDRA svc/${K8SSANDRA_CLUSTER_NAME}-${DATACENTER_NAME}-service 9042:9042"
  echo ""
  echo "  # View Cassandra logs"
  echo "  $KUBECTL_BIN logs -n $NS_K8SSANDRA ${K8SSANDRA_CLUSTER_NAME}-${DATACENTER_NAME}-rack1-sts-0 -c cassandra"
}

############################################
# Main
############################################
main() {
  info "Starting deployment of K8ssandra cluster..."
  info ""

  # Validate configurations
  validate_storage_configuration
  validate_cluster_configuration
  info ""

  info "Configuration Summary:"
  info "  K8ssandra Cluster Name: $K8SSANDRA_CLUSTER_NAME"
  info "  Storage Mode: $STORAGE_MODE"
  info "  Storage Size: $STORAGE_SIZE"
  echo ""

  read -p "Continue with deployment? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Deployment cancelled"
    exit 0
  fi

  check_prerequisites
  install_k8ssandra_operator
  prepare_storage

  # Create k8ssandra directory for manifests
  mkdir -p k8ssandra

  generate_k8ssandra_cluster_yaml
  apply_k8ssandra_resources
  wait_for_k8ssandra
  display_connection_info
}

main "$@"
