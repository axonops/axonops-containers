#!/usr/bin/env bash
# Deploy a Strimzi Kafka cluster on local disks (hostPath PersistentVolumes)
# with the AxonOps agent.
#
# Usage:
#   source strimzi-config.env
#   ./strimzi-setup.sh
#
# The script installs the Strimzi operator if its CRDs are missing, creates a
# PersistentVolume per controller and broker on the node chosen for it, then
# applies the node pools and the Kafka cluster. The volume directories must
# exist on each node first; the script prints the commands to create them.
#
# RENDER_ONLY=true writes the rendered manifests to STRIMZI_OUTPUT_DIR and
# prints the directories each node needs and the commands a real run would
# execute, without changing the cluster.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

############################################
# Parameters
############################################

KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
HELM_BIN="${HELM_BIN:-helm}"
RENDER_ONLY="${RENDER_ONLY:-false}"

STRIMZI_OUTPUT_DIR="${STRIMZI_OUTPUT_DIR:-$SCRIPT_DIR/generated}"
KAFKA_READY_TIMEOUT="${KAFKA_READY_TIMEOUT:-600s}"

# Strimzi operator, installed only when its CRDs are not present.
STRIMZI_OPERATOR_INSTALL="${STRIMZI_OPERATOR_INSTALL:-true}"
STRIMZI_OPERATOR_NAMESPACE="${STRIMZI_OPERATOR_NAMESPACE:-strimzi}"
STRIMZI_OPERATOR_VERSION="${STRIMZI_OPERATOR_VERSION:-1.1.0}"
# true: install the operator with helm --wait. false: do not wait for its pod.
HELM_WAIT="${HELM_WAIT:-true}"

export KAFKA_NAMESPACE="${KAFKA_NAMESPACE:-kafka}"
export STRIMZI_CLUSTER_NAME="${STRIMZI_CLUSTER_NAME:-my-cluster}"
export KAFKA_RACK_TOPOLOGY_KEY="${KAFKA_RACK_TOPOLOGY_KEY:-kubernetes.io/hostname}"
export STRIMZI_VERSION="${STRIMZI_VERSION:-$STRIMZI_OPERATOR_VERSION}"
export KAFKA_VERSION="${KAFKA_VERSION:-4.3.0}"
export KAFKA_CONTAINER_IMAGE="${KAFKA_CONTAINER_IMAGE:-ghcr.io/axonops/strimzi/kafka:${STRIMZI_VERSION}-${KAFKA_VERSION}}"
export KAFKA_REPLICATION_FACTOR="${KAFKA_REPLICATION_FACTOR:-3}"
export KAFKA_MIN_INSYNC_REPLICAS="${KAFKA_MIN_INSYNC_REPLICAS:-2}"

export STRIMZI_CONTROLLER_REPLICAS="${STRIMZI_CONTROLLER_REPLICAS:-3}"
export STRIMZI_CONTROLLER_STORAGE_SIZE="${STRIMZI_CONTROLLER_STORAGE_SIZE:-10Gi}"
export STRIMZI_BROKER_REPLICAS="${STRIMZI_BROKER_REPLICAS:-3}"
export STRIMZI_BROKER_STORAGE_SIZE="${STRIMZI_BROKER_STORAGE_SIZE:-20Gi}"

export STRIMZI_LOCAL_STORAGE_CLASS="${STRIMZI_LOCAL_STORAGE_CLASS:-strimzi-local}"
export STRIMZI_HOST_BASE_DIR="${STRIMZI_HOST_BASE_DIR:-/data/strimzi}"
STRIMZI_HOST_UID="${STRIMZI_HOST_UID:-1001}"
STRIMZI_HOST_GID="${STRIMZI_HOST_GID:-1001}"
STRIMZI_NODE_HOSTNAME="${STRIMZI_NODE_HOSTNAME:-}"
KAFKA_CONTROLLER_NODE_SELECTORS="${KAFKA_CONTROLLER_NODE_SELECTORS:-}"
KAFKA_BROKER_NODE_SELECTORS="${KAFKA_BROKER_NODE_SELECTORS:-}"
# Create the directories with sudo on this machine. Only useful when this
# machine is the Kubernetes node that holds every volume.
STRIMZI_CREATE_HOST_DIRS="${STRIMZI_CREATE_HOST_DIRS:-false}"

export AXONOPS_NAMESPACE="${AXONOPS_NAMESPACE:-axonops}"
export AXON_AGENT_ORG="${AXON_AGENT_ORG:-${AXON_SERVER_ORG_NAME:-example}}"
export AXON_AGENT_KEY="${AXON_AGENT_KEY:-not-used}"
export AXON_AGENT_CLUSTER_NAME="${AXON_AGENT_CLUSTER_NAME:-$STRIMZI_CLUSTER_NAME}"
export AXON_AGENT_SERVER_HOST="${AXON_AGENT_SERVER_HOST:-axon-server-agent.${AXONOPS_NAMESPACE}.svc.cluster.local}"
export AXON_AGENT_SERVER_PORT="${AXON_AGENT_SERVER_PORT:-${AXON_SERVER_AGENTS_PORT:-1888}}"
export AXON_AGENT_TLS_MODE="${AXON_AGENT_TLS_MODE:-disabled}"

############################################
# Helpers
############################################

info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; }

# Render a manifest from this directory. Only the listed variables are
# substituted, so log4j2 lookups such as ${sys:kafka.logs.dir} stay intact.
# shellcheck disable=SC2016 # the ${VAR} names are for envsubst, not the shell
render() {
  envsubst "$(printf '${%s} ' \
    KAFKA_NAMESPACE STRIMZI_CLUSTER_NAME KAFKA_RACK_TOPOLOGY_KEY KAFKA_VERSION \
    KAFKA_CONTAINER_IMAGE KAFKA_REPLICATION_FACTOR KAFKA_MIN_INSYNC_REPLICAS \
    STRIMZI_CONTROLLER_REPLICAS STRIMZI_CONTROLLER_STORAGE_SIZE \
    STRIMZI_BROKER_REPLICAS STRIMZI_BROKER_STORAGE_SIZE \
    STRIMZI_LOCAL_STORAGE_CLASS STRIMZI_HOST_BASE_DIR \
    STRIMZI_VOLUME_INDEX STRIMZI_VOLUME_NODE \
    AXON_AGENT_CLUSTER_NAME AXON_AGENT_ORG AXON_AGENT_KEY \
    AXON_AGENT_SERVER_HOST AXON_AGENT_SERVER_PORT AXON_AGENT_TLS_MODE)" \
    < "$SCRIPT_DIR/$1"
}

# Print one node per replica index, in index order.
# Args: replicas selectors prefix
resolve_nodes() {
  local replicas="$1" selectors="$2" prefix="$3" pair idx node i
  local nodes=()
  if [[ -n "$selectors" ]]; then
    IFS=',' read -ra pairs <<< "$selectors"
    for pair in "${pairs[@]}"; do
      idx="${pair%%:*}"
      node="${pair#*:}"
      idx="${idx##*-}"   # accepts 0, broker-0, controller-0 and ctrl-0
      if [[ "$pair" != *:* || -z "$node" ]] || ! [[ "$idx" =~ ^[0-9]+$ ]]; then
        error "Invalid $prefix selector '$pair'; expected <index>:<node>"
        return 1
      fi
      if (( idx >= replicas )); then
        error "$prefix index $idx is out of range: there are $replicas replicas"
        return 1
      fi
      nodes[idx]="$node"
    done
  fi
  for ((i = 0; i < replicas; i++)); do
    if [[ -z "${nodes[i]:-}" ]]; then
      if [[ -z "$STRIMZI_NODE_HOSTNAME" ]]; then
        error "No node for $prefix-$i. Set STRIMZI_NODE_HOSTNAME or list it in the node selectors."
        return 1
      fi
      nodes[i]="$STRIMZI_NODE_HOSTNAME"
    fi
    echo "${nodes[i]}"
  done
}

############################################
# Steps
############################################

check_prerequisites() {
  command -v envsubst >/dev/null || { error "envsubst not found (install gettext)"; exit 1; }
  if [[ "$RENDER_ONLY" != "true" ]]; then
    command -v "$KUBECTL_BIN" >/dev/null || { error "$KUBECTL_BIN not found"; exit 1; }
  fi
  if [[ -z "$STRIMZI_NODE_HOSTNAME" ]]; then
    local nodes
    nodes="$($KUBECTL_BIN get nodes -o name 2>/dev/null || true)"
    if [[ -n "$nodes" && "$(wc -l <<< "$nodes")" -eq 1 ]]; then
      STRIMZI_NODE_HOSTNAME="${nodes#node/}"
      info "Single-node cluster: all volumes go on '$STRIMZI_NODE_HOSTNAME'"
    elif [[ "$RENDER_ONLY" == "true" ]]; then
      STRIMZI_NODE_HOSTNAME="NODE-NAME"
      warn "STRIMZI_NODE_HOSTNAME is not set; rendering with the placeholder 'NODE-NAME'"
    fi
  fi
}

validate_nodes() {
  local node failed=0
  for node in $(printf '%s\n' "${controller_nodes[@]}" "${broker_nodes[@]}" | sort -u); do
    if ! $KUBECTL_BIN get node "$node" >/dev/null 2>&1; then
      error "Node '$node' not found"
      failed=1
    fi
  done
  if (( failed )); then
    error "Available nodes:"
    $KUBECTL_BIN get nodes >&2
    exit 1
  fi
}

print_directories() {
  local node i dirs
  info "Each node needs these directories before the pods can start:"
  for node in $(printf '%s\n' "${controller_nodes[@]}" "${broker_nodes[@]}" | sort -u); do
    dirs=""
    for i in "${!controller_nodes[@]}"; do
      [[ "${controller_nodes[i]}" == "$node" ]] && dirs+=" $STRIMZI_HOST_BASE_DIR/$STRIMZI_CLUSTER_NAME/controller-$i"
    done
    for i in "${!broker_nodes[@]}"; do
      [[ "${broker_nodes[i]}" == "$node" ]] && dirs+=" $STRIMZI_HOST_BASE_DIR/$STRIMZI_CLUSTER_NAME/broker-$i"
    done
    echo "  # on $node"
    echo "  sudo mkdir -p$dirs"
    echo "  sudo chown -R $STRIMZI_HOST_UID:$STRIMZI_HOST_GID $STRIMZI_HOST_BASE_DIR/$STRIMZI_CLUSTER_NAME"
  done
}

create_local_directories() {
  local i dirs=()
  for i in "${!controller_nodes[@]}"; do dirs+=("$STRIMZI_HOST_BASE_DIR/$STRIMZI_CLUSTER_NAME/controller-$i"); done
  for i in "${!broker_nodes[@]}"; do dirs+=("$STRIMZI_HOST_BASE_DIR/$STRIMZI_CLUSTER_NAME/broker-$i"); done
  info "Creating ${#dirs[@]} directories on this machine with sudo"
  sudo mkdir -p "${dirs[@]}"
  sudo chown -R "$STRIMZI_HOST_UID:$STRIMZI_HOST_GID" "$STRIMZI_HOST_BASE_DIR/$STRIMZI_CLUSTER_NAME"
}

install_strimzi_operator() {
  if $KUBECTL_BIN get crd kafkas.kafka.strimzi.io >/dev/null 2>&1; then
    info "Strimzi CRDs found; using the installed operator"
    return
  fi
  if [[ "$STRIMZI_OPERATOR_INSTALL" != "true" ]]; then
    error "Strimzi CRDs not found and STRIMZI_OPERATOR_INSTALL is not 'true'"
    exit 1
  fi
  local wait=()
  [[ "$HELM_WAIT" == "true" ]] && wait=(--wait)
  info "Installing Strimzi operator $STRIMZI_OPERATOR_VERSION in '$STRIMZI_OPERATOR_NAMESPACE'..."
  $HELM_BIN upgrade --install strimzi-kafka-operator \
    oci://quay.io/strimzi-helm/strimzi-kafka-operator \
    --version "$STRIMZI_OPERATOR_VERSION" \
    --namespace "$STRIMZI_OPERATOR_NAMESPACE" --create-namespace \
    --set watchAnyNamespace=true \
    ${wait[@]+"${wait[@]}"}
}

render_all() {
  local i
  render strimzi-storageclass.yaml
  for i in "${!controller_nodes[@]}"; do
    STRIMZI_VOLUME_INDEX="$i" STRIMZI_VOLUME_NODE="${controller_nodes[i]}" \
      render strimzi-controller-volumes.yaml
  done
  for i in "${!broker_nodes[@]}"; do
    STRIMZI_VOLUME_INDEX="$i" STRIMZI_VOLUME_NODE="${broker_nodes[i]}" \
      render strimzi-broker-volumes.yaml
  done
  render axonops-agent-secret.yaml
  render kafka-node-pool-controller.yaml
  render kafka-node-pool-brokers.yaml
  render kafka-cluster.yaml
}

wait_for_kafka() {
  info "Waiting up to $KAFKA_READY_TIMEOUT for Kafka '$STRIMZI_CLUSTER_NAME' to be Ready..."
  if ! $KUBECTL_BIN wait kafka/"$STRIMZI_CLUSTER_NAME" -n "$KAFKA_NAMESPACE" \
      --for=condition=Ready --timeout="$KAFKA_READY_TIMEOUT"; then
    error "Kafka is not Ready. Check:"
    error "  $KUBECTL_BIN get kafka,kafkanodepool,pvc,pods -n $KAFKA_NAMESPACE"
    exit 1
  fi
  $KUBECTL_BIN get pods -n "$KAFKA_NAMESPACE" -l "strimzi.io/cluster=$STRIMZI_CLUSTER_NAME" \
    -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase
  echo
  info "Bootstrap: ${STRIMZI_CLUSTER_NAME}-kafka-bootstrap.${KAFKA_NAMESPACE}.svc.cluster.local:9092"
  info "AxonOps agent: ${AXON_AGENT_SERVER_HOST}:${AXON_AGENT_SERVER_PORT} (org '${AXON_AGENT_ORG}', cluster '${AXON_AGENT_CLUSTER_NAME}')"
}

main() {
  check_prerequisites

  local resolved
  resolved="$(resolve_nodes "$STRIMZI_CONTROLLER_REPLICAS" "$KAFKA_CONTROLLER_NODE_SELECTORS" controller)" || exit 1
  # Node names never contain whitespace, so word splitting is safe here.
  # shellcheck disable=SC2206
  controller_nodes=($resolved)
  resolved="$(resolve_nodes "$STRIMZI_BROKER_REPLICAS" "$KAFKA_BROKER_NODE_SELECTORS" broker)" || exit 1
  # shellcheck disable=SC2206
  broker_nodes=($resolved)

  if [[ "$RENDER_ONLY" == "true" ]]; then
    local out="$STRIMZI_OUTPUT_DIR/strimzi-local-disk.yaml"
    (umask 077 && mkdir -p "$STRIMZI_OUTPUT_DIR")
    render_all > "$out"
    info "RENDER_ONLY=true: wrote $out, nothing applied."
    print_directories
    echo
    info "A real run would execute:"
    echo "  $HELM_BIN upgrade --install strimzi-kafka-operator oci://quay.io/strimzi-helm/strimzi-kafka-operator --version $STRIMZI_OPERATOR_VERSION -n $STRIMZI_OPERATOR_NAMESPACE --create-namespace --set watchAnyNamespace=true $([[ "$HELM_WAIT" == "true" ]] && echo --wait)  # only if the Strimzi CRDs are missing"
    echo "  $KUBECTL_BIN create namespace $KAFKA_NAMESPACE"
    echo "  $KUBECTL_BIN apply -f $out"
    echo "  $KUBECTL_BIN wait kafka/$STRIMZI_CLUSTER_NAME -n $KAFKA_NAMESPACE --for=condition=Ready --timeout=$KAFKA_READY_TIMEOUT"
    exit 0
  fi

  validate_nodes
  if [[ "$STRIMZI_CREATE_HOST_DIRS" == "true" ]]; then
    create_local_directories
  else
    print_directories
  fi

  install_strimzi_operator

  info "Applying manifests to namespace '$KAFKA_NAMESPACE'..."
  $KUBECTL_BIN create namespace "$KAFKA_NAMESPACE" --dry-run=client -o yaml | $KUBECTL_BIN apply -f -
  render_all | $KUBECTL_BIN apply -f -

  wait_for_kafka
}

main "$@"
