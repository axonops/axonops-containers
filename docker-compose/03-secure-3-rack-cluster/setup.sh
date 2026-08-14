#!/usr/bin/env bash
#
# Create and seed the host directories this example bind-mounts into the three
# Cassandra nodes:
#
#   docker/cassandra0N        -> /var/lib/cassandra   (data)
#   docker/cassandra0N-conf   -> /opt/cassandra/conf  (configuration)
#
# The configuration directories are seeded from the image itself, so they match
# the Cassandra version actually being run. Existing directories are left alone
# unless --force is given, so local edits are never overwritten by accident.
#
# Usage:
#   ./setup.sh              create and seed anything missing
#   ./setup.sh --force      re-seed the configuration directories from the image
#   ./setup.sh --help
#
# Run it once before the first "docker compose up -d".

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly DATA_ROOT="${SCRIPT_DIR}/docker"
readonly NODES=(cassandra01 cassandra02 cassandra03)

# Must match docker-compose.yaml. .env wins if it sets CASSANDRA_IMAGE.
readonly DEFAULT_IMAGE="ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0"

# The image runs Cassandra as uid/gid 999. A bind-mounted directory created by
# Docker or by root is not writable by that user on Linux.
readonly CASSANDRA_UID=999
readonly CASSANDRA_GID=999

FORCE=false

log()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# Print the header comment block, minus the shebang.
usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -f|--force) FORCE=true ;;
      -h|--help)  usage; exit 0 ;;
      *)          die "unknown option: $1 (try --help)" ;;
    esac
    shift
  done
}

# CASSANDRA_IMAGE from .env if set there, otherwise the default above.
resolve_image() {
  local env_file="${SCRIPT_DIR}/.env"
  local from_env=""

  if [ -f "$env_file" ]; then
    from_env="$(sed -n 's/^[[:space:]]*CASSANDRA_IMAGE[[:space:]]*=[[:space:]]*//p' "$env_file" | tail -n 1)"
    from_env="${from_env%\"}"
    from_env="${from_env#\"}"
  fi

  printf '%s\n' "${from_env:-$DEFAULT_IMAGE}"
}

require_docker() {
  command -v docker >/dev/null 2>&1 || die "docker is not on PATH"
  docker info >/dev/null 2>&1 || die "cannot talk to the Docker daemon"
}

# Copy /opt/cassandra/conf out of the image into a host directory.
seed_conf() {
  local image="$1" target="$2"
  local container

  container="$(docker create "$image")" || die "could not create a container from $image"
  # shellcheck disable=SC2064  # expand $container now, not at trap time
  trap "docker rm -f '$container' >/dev/null 2>&1 || true" RETURN

  rm -rf -- "${target:?}"
  mkdir -p -- "$target"
  # docker cp of "path/." copies the contents, not the directory itself
  docker cp "${container}:/opt/cassandra/conf/." "$target" \
    || die "could not copy /opt/cassandra/conf out of $image"
}

# Best-effort chown. Needed on Linux; on Docker Desktop the file sharing layer
# maps ownership already and chown without privileges is expected to fail.
set_ownership() {
  local path="$1"

  if chown -R "${CASSANDRA_UID}:${CASSANDRA_GID}" "$path" 2>/dev/null; then
    return 0
  fi
  if [ "$(uname -s)" = "Linux" ]; then
    warn "could not chown $path to ${CASSANDRA_UID}:${CASSANDRA_GID}."
    warn "  If Cassandra fails to start with a permissions error, run:"
    warn "    sudo chown -R ${CASSANDRA_UID}:${CASSANDRA_GID} ${DATA_ROOT}"
  fi
}

main() {
  parse_args "$@"
  require_docker

  local image
  image="$(resolve_image)"
  log "Image:     $image"
  log "Directory: $DATA_ROOT"
  log ""

  if ! docker image inspect "$image" >/dev/null 2>&1; then
    log "Pulling $image ..."
    docker pull "$image" >/dev/null || die "could not pull $image"
  fi

  mkdir -p -- "$DATA_ROOT"

  local node data_dir conf_dir
  for node in "${NODES[@]}"; do
    data_dir="${DATA_ROOT}/${node}"
    conf_dir="${DATA_ROOT}/${node}-conf"

    if [ -d "$data_dir" ]; then
      log "${node}: data directory exists, left alone"
    else
      mkdir -p -- "$data_dir"
      log "${node}: data directory created"
    fi

    if [ -d "$conf_dir" ] && [ -f "${conf_dir}/cassandra.yaml" ] && [ "$FORCE" = false ]; then
      log "${node}: configuration exists, left alone (--force to re-seed)"
    else
      seed_conf "$image" "$conf_dir"
      log "${node}: configuration seeded from the image"
    fi

    set_ownership "$data_dir"
    set_ownership "$conf_dir"
  done

  log ""
  log "Done. Next:"
  log "  cp env.example .env    # if you have not already"
  log "  docker compose up -d"
}

main "$@"
