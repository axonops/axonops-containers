#!/bin/bash
set -e

# AxonDB Time-Series Entrypoint Script
# Processes cassandra.yaml template with environment variables and starts Cassandra

# Display comprehensive startup banner
print_startup_banner() {
    if [ -f /etc/axonops/build-info.txt ]; then
      source /etc/axonops/build-info.txt 2>/dev/null || true
    fi

    echo "================================================================================"
    # Title
    echo "AxonOps AxonDB Time-Series (Apache Cassandra ${CASSANDRA_VERSION:-unknown})"

    # Image and build info (CI builds only - not shown for local/unknown builds)
    if [ -n "${CONTAINER_IMAGE}" ] && [ "${CONTAINER_IMAGE}" != "unknown" ] && [ "${CONTAINER_IMAGE}" != "" ]; then
      echo "Image: ${CONTAINER_IMAGE}"
    fi
    if [ -n "${CONTAINER_BUILD_DATE}" ] && [ "${CONTAINER_BUILD_DATE}" != "unknown" ] && [ "${CONTAINER_BUILD_DATE}" != "" ]; then
      echo "Built: ${CONTAINER_BUILD_DATE}"
    fi

    # Show release/tag link if available (CI builds)
    if [ -n "${CONTAINER_GIT_TAG}" ] && [ "${CONTAINER_GIT_TAG}" != "unknown" ] && [ "${CONTAINER_GIT_TAG}" != "" ]; then
      if [ "${IS_PRODUCTION_RELEASE:-false}" = "true" ]; then
        # Production build - link to release page (has release notes)
        echo "Release: https://github.com/axonops/axonops-containers/releases/tag/${CONTAINER_GIT_TAG}"
      else
        # Development build - link to tag/tree
        echo "Tag:     https://github.com/axonops/axonops-containers/tree/${CONTAINER_GIT_TAG}"
      fi
    fi

    # Show who built it if available (CI builds)
    if [ -n "${CONTAINER_BUILT_BY}" ] && [ "${CONTAINER_BUILT_BY}" != "unknown" ] && [ "${CONTAINER_BUILT_BY}" != "" ]; then
      if [ "${CONTAINER_BUILT_BY}" = "GitHub Actions" ] || [ "${IS_PRODUCTION_RELEASE:-false}" = "true" ]; then
        echo "Built by: ${CONTAINER_BUILT_BY}"
      fi
    fi

    echo "================================================================================"
    echo ""

    # Component versions (from build-info.txt)
    echo "Component Versions:"
    echo "  Cassandra:          ${CASSANDRA_VERSION:-unknown}"
    echo "  Java:               ${JAVA_VERSION:-unknown}"
    echo "  cqlai:              ${CQLAI_VERSION:-unknown}"
    echo "  jemalloc:           ${JEMALLOC_VERSION:-unknown}"
    echo "  OS:                 ${OS_VERSION:-unknown}"
    echo "  Platform:           ${PLATFORM:-unknown}"
    echo ""

    # Supply chain verification (base image digest for security audit)
    echo "Supply Chain Security:"
    echo "  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest"
    echo "  Base image digest:  ${UBI9_BASE_DIGEST:-unknown}"
    echo ""

    # Runtime environment (dynamic - only knowable at runtime)
    echo "Runtime Environment:"
    echo "  Hostname:           $(hostname 2>/dev/null || echo 'unknown')"

    # Kubernetes detection (safe - only if vars exist)
    if [ -n "${KUBERNETES_SERVICE_HOST}" ]; then
      echo "  Kubernetes:         Yes"
      echo "    API Server:       ${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
      if [ -n "${HOSTNAME}" ]; then
        echo "    Pod:              ${HOSTNAME}"
      fi
    fi
    echo ""

    # Backup/Restore Configuration (show if configured)
    if [ -n "${BACKUP_SCHEDULE:-}" ] || [ -n "${RESTORE_FROM_BACKUP:-}" ] || [ "${RESTORE_ENABLED:-false}" = "true" ]; then
      echo "Backup/Restore Configuration:"

      # Scheduled backups
      if [ -n "${BACKUP_SCHEDULE:-}" ]; then
        echo "  Scheduled Backups:  Enabled"
        echo "    Schedule:         ${BACKUP_SCHEDULE}"
        echo "    Retention:        ${BACKUP_RETENTION_HOURS:-not set} hours"
        echo "    Min Keep Count:   ${BACKUP_MINIMUM_RETENTION_COUNT:-1}"
        echo "    Hardlinks:        ${BACKUP_USE_HARDLINKS:-true}"
        echo "    Calculate Stats:  ${BACKUP_CALCULATE_STATS:-false}"
      else
        echo "  Scheduled Backups:  Disabled (trigger manually via /usr/local/bin/cassandra-backup.sh)"
      fi

      # Restore configuration
      if [ -n "${RESTORE_FROM_BACKUP:-}" ]; then
        echo "  Restore:            Enabled (specific backup)"
        echo "    Target:           ${RESTORE_FROM_BACKUP}"
      elif [ "${RESTORE_ENABLED:-false}" = "true" ]; then
        echo "  Restore:            Enabled (latest backup)"
      else
        echo "  Restore:            Disabled"
      fi

      echo ""
    fi

    echo "================================================================================"
    echo "Starting Cassandra..."
    echo "================================================================================"
    echo ""
}

print_startup_banner

# Helper function to get container IP address
_ip_address() {
    # scrape the first non-localhost IP address of the container
    ip address | awk '
        $1 == "inet" && $NF != "lo" {
            gsub(/\/.+$/, "", $2)
            print $2
            exit
        }
    '
}

# Set default environment variables if not provided
export CASSANDRA_CLUSTER_NAME="${CASSANDRA_CLUSTER_NAME:-axonopsdb-timeseries}"
export CASSANDRA_NUM_TOKENS="${CASSANDRA_NUM_TOKENS:-8}"
export CASSANDRA_LISTEN_ADDRESS="${CASSANDRA_LISTEN_ADDRESS:-auto}"
export CASSANDRA_RPC_ADDRESS="${CASSANDRA_RPC_ADDRESS:-0.0.0.0}"
export CASSANDRA_DC="${CASSANDRA_DC:-axonopsdb_dc1}"
export CASSANDRA_RACK="${CASSANDRA_RACK:-rack1}"

# Resolve 'auto' to actual IP address
if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
    CASSANDRA_LISTEN_ADDRESS="$(_ip_address)"
fi

# Set broadcast addresses if not specified
if [ -z "$CASSANDRA_BROADCAST_ADDRESS" ]; then
    CASSANDRA_BROADCAST_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"
fi

# If RPC address is 0.0.0.0 (wildcard), broadcast_rpc_address must be set to actual IP
if [ "$CASSANDRA_RPC_ADDRESS" = "0.0.0.0" ] && [ -z "$CASSANDRA_BROADCAST_RPC_ADDRESS" ]; then
    CASSANDRA_BROADCAST_RPC_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"
fi

# Set seeds - default to the node's own IP for single-node deployments
if [ -z "$CASSANDRA_SEEDS" ]; then
    CASSANDRA_SEEDS="$CASSANDRA_BROADCAST_ADDRESS"
fi

# JVM heap settings
export CASSANDRA_HEAP_SIZE="${CASSANDRA_HEAP_SIZE:-8G}"

# Enable SSL if specified (assumes certs are mounted in /etc/cassandra/ssl)
if [ "$CASSANDRA_KEYSTORE_PATH" != "" ] && [ -f "${CASSANDRA_KEYSTORE_PATH}" ]; then
  yq -i '.server_encryption_options.internode_encryption = strenv(CASSANDRA_INTERNODE_ENCRYPTION)' /etc/cassandra/cassandra.yaml
  yq -i '.server_encryption_options.enabled = true' /etc/cassandra/cassandra.yaml
  yq -i '.server_encryption_options.keystore = strenv(CASSANDRA_KEYSTORE_PATH)' /etc/cassandra/cassandra.yaml
  yq -i '.server_encryption_options.keystore_password = strenv(CASSANDRA_KEYSTORE_PASSWORD)' /etc/cassandra/cassandra.yaml
  yq -i '.server_encryption_options.truststore = strenv(CASSANDRA_TRUSTSTORE_PATH)' /etc/cassandra/cassandra.yaml
  yq -i '.server_encryption_options.truststore_password = strenv(CASSANDRA_TRUSTSTORE_PASSWORD)' /etc/cassandra/cassandra.yaml

  yq -i '.client_encryption_options.enabled = strenv(CASSANDRA_INTERNODE_CLIENT_AUTH)' /etc/cassandra/cassandra.yaml
  yq -i '.client_encryption_options.keystore = strenv(CASSANDRA_KEYSTORE_PATH)' /etc/cassandra/cassandra.yaml
  yq -i '.client_encryption_options.keystore_password = strenv(CASSANDRA_KEYSTORE_PASSWORD)' /etc/cassandra/cassandra.yaml
  yq -i '.client_encryption_options.truststore = strenv(CASSANDRA_TRUSTSTORE_PATH)' /etc/cassandra/cassandra.yaml
  yq -i '.client_encryption_options.truststore_password = strenv(CASSANDRA_TRUSTSTORE_PASSWORD)' /etc/cassandra/cassandra.yaml
  echo "✓ SSL encryption enabled for client and inter-node communication"
  SSL_ENABLED=true
else
  echo "⚠ SSL encryption not enabled (keystore/truststore not found), continuing without it"
  SSL_ENABLED=false
fi

if [ "$CASSANDRSA_FQDN" == "" ]; then
  CASSANDRSA_FQDN="$(hostname)"
  echo "✓ CQLSH FQDN set to $CASSANDRSA_FQDN"
fi

if [ "$SSL_ENABLED" = true ] && [ -f "$CASSANDRA_CA_CERT_PATH" ]; then
  mkdir -p /opt/cassandra/.cassandra
  cat >> /opt/cassandra/.cassandra/cqlshrc <<EOL
[connection]
ssl = true
hostname = $CASSANDRSA_FQDN

[ssl]
certfile = $CASSANDRA_CA_CERT_PATH
userkey = $CASSANDRA_TLS_KEY_PATH
usercert = $CASSANDRA_TLS_CERT_PATH
validate = true
EOL

elif [ "$SSL_ENABLED" = true ]; then
  cat >> /opt/cassandra/.cassandra/cqlshrc <<EOL
[connection]
ssl = true
hostname = $CASSANDRSA_FQDN

[ssl]
validate = false
EOL
fi

echo "Configuration:"
echo "  Cluster Name:       ${CASSANDRA_CLUSTER_NAME}"
echo "  DC/Rack:            ${CASSANDRA_DC}/${CASSANDRA_RACK}"
echo "  Num Tokens:         ${CASSANDRA_NUM_TOKENS}"
echo "  Listen Address:     ${CASSANDRA_LISTEN_ADDRESS}"
echo "  RPC Address:        ${CASSANDRA_RPC_ADDRESS}"
echo "  Heap Size:          ${CASSANDRA_HEAP_SIZE}"
if [ "$SSL_ENABLED" = true ]; then
  echo "  SSL:                Enabled"
else
  echo "  SSL:                Disabled"
fi
echo ""

# Apply environment variable substitutions to cassandra.yaml
# Copied from base image's docker-entrypoint.sh sed logic
_sed-in-place() {
    local filename="$1"; shift
    local tempFile
    tempFile="$(mktemp)"
    sed "$@" "$filename" > "$tempFile"
    cat "$tempFile" > "$filename"
    rm "$tempFile"
}

# Update seeds in cassandra.yaml
_sed-in-place "/etc/cassandra/cassandra.yaml" -r 's/(- seeds:).*/\1 "'"$CASSANDRA_SEEDS"'"/'

# Note: endpoint_snitch is already set to GossipingPropertyFileSnitch in cassandra.yaml
# This snitch reads DC/Rack from cassandra-rackdc.properties (updated below)

# Apply CASSANDRA_* environment variables to cassandra.yaml
for yaml in cluster_name num_tokens listen_address rpc_address broadcast_address broadcast_rpc_address; do
    var="CASSANDRA_${yaml^^}"
    val="${!var}"
    if [ "$val" ]; then
        _sed-in-place "/etc/cassandra/cassandra.yaml" -r 's/^(# )?('"$yaml"':).*/\2 '"$val"'/'
    fi
done

# Apply DC/Rack to cassandra-rackdc.properties (handle space after =)
for rackdc in dc rack; do
    var="CASSANDRA_${rackdc^^}"
    val="${!var}"
    if [ "$val" ]; then
        _sed-in-place "/etc/cassandra/cassandra-rackdc.properties" -r 's/^('"$rackdc"')\s*=.*/\1='"$val"'/'
    fi
done

# Apply heap size override to jvm17-server.options if env var set
if [ -n "$CASSANDRA_HEAP_SIZE" ]; then
    # Check if -Xms and -Xmx lines already exist and update them, or add new ones
    if grep -q "^-Xms" "/etc/cassandra/jvm17-server.options"; then
        _sed-in-place "/etc/cassandra/jvm17-server.options" -r 's|^-Xms.*|-Xms'"${CASSANDRA_HEAP_SIZE}"'|'
    else
        echo "-Xms${CASSANDRA_HEAP_SIZE}" >> "/etc/cassandra/jvm17-server.options"
    fi

    if grep -q "^-Xmx" "/etc/cassandra/jvm17-server.options"; then
        _sed-in-place "/etc/cassandra/jvm17-server.options" -r 's|^-Xmx.*|-Xmx'"${CASSANDRA_HEAP_SIZE}"'|'
    else
        echo "-Xmx${CASSANDRA_HEAP_SIZE}" >> "/etc/cassandra/jvm17-server.options"
    fi

    # Confirm the heap size was set correctly
    echo "✓ Heap size set to ${CASSANDRA_HEAP_SIZE} (Xms and Xmx)"
    echo "  JVM options updated in /etc/cassandra/jvm17-server.options"
fi

echo "✓ Configuration applied to cassandra.yaml"
echo ""

# Enable jemalloc for memory optimization (UBI path)
if [ -f /usr/lib64/libjemalloc.so.2 ]; then
    export LD_PRELOAD=/usr/lib64/libjemalloc.so.2
    echo "✓ jemalloc enabled"
else
    echo "⚠ jemalloc not found, continuing without it"
fi

# JVM options are set in jvm17-server.options (including Shenandoah GC)

# ============================================================================
# Restore from Backup (if requested)
# ============================================================================
# CRITICAL: Check restore FIRST, before starting init scripts
# In a restore scenario, we're restoring EXISTING data (with keyspaces and users already configured)
# We should NOT run init scripts that would try to ALTER system keyspaces or CREATE users
# This runs BEFORE Cassandra starts to restore data files first

if [ -n "${RESTORE_FROM_BACKUP:-}" ] || [ "${RESTORE_ENABLED:-false}" = "true" ]; then
    echo "=== Restore Requested ==="
    if [ -n "${RESTORE_FROM_BACKUP:-}" ]; then
        echo "Restoring from backup: ${RESTORE_FROM_BACKUP}"
    else
        echo "Restoring from latest backup"
    fi
    echo ""
    echo "Skipping init scripts (restoring existing data with keyspaces and users already configured)"
    echo ""

    # NOTE: Semaphores (init-system-keyspaces.done, init-db-user.done) will come from backup!
    # The backup includes /var/lib/cassandra/.axonops with original cluster state
    # Restore script copies .axonops directory FIRST, preserving semaphore state
    # No need to write "skipped" semaphores - we use the real ones from backup

    # Write restore semaphore IMMEDIATELY so startup probe passes
    # Restore script will update this to "success" or "failed" when complete
    # CRITICAL: Use /tmp (ephemeral) not .axonops (gets backed up!)
    {
        echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        echo "RESULT=in_progress"
        echo "REASON=restore_starting"
    } > /tmp/axonops-restore.done

    # Start restore in BACKGROUND (non-blocking)
    # This prevents entrypoint from blocking on long restores (which causes K8s startup probe timeouts)
    # The cassandra-wrapper.sh will wait for restore to complete before starting Cassandra
    echo "Starting restore script in background..."
    echo "  Output: /var/log/cassandra/restore.log"
    echo "  Wrapper will wait for restore to complete before starting Cassandra"
    echo ""
    (/usr/local/bin/cassandra-restore.sh > /var/log/cassandra/restore.log 2>&1 &)

    # Entrypoint will now exec cassandra-wrapper.sh (which waits for restore, then starts Cassandra)
    # This allows entrypoint to return immediately (preventing K8s startup probe timeouts)

else
    # NO restore requested - run init scripts normally for fresh cluster
    # Initialize system keyspaces and custom database user in background (non-blocking)
    # This will wait for Cassandra to be ready, then:
    #   1. Convert system keyspaces to NetworkTopologyStrategy (if INIT_SYSTEM_KEYSPACES_AND_ROLES=true)
    #   2. Create custom superuser (if AXONOPS_DB_USER and AXONOPS_DB_PASSWORD are set)
    # Only runs on fresh single-node clusters with default credentials
    # Can be disabled by setting INIT_SYSTEM_KEYSPACES_AND_ROLES=false
    INIT_SYSTEM_KEYSPACES_AND_ROLES="${INIT_SYSTEM_KEYSPACES_AND_ROLES:-true}"

    if [ "$INIT_SYSTEM_KEYSPACES_AND_ROLES" = "true" ]; then
        echo "Starting initialization in background (keyspaces + roles)..."
        (/usr/local/bin/init-system-keyspaces.sh > /var/log/cassandra/init-system-keyspaces.log 2>&1 &)
    else
        echo "System keyspace and role initialization disabled (INIT_SYSTEM_KEYSPACES_AND_ROLES=false)"
        echo "Writing semaphore files to allow healthcheck to proceed..."
        # Write semaphores immediately so healthcheck doesn't block
        # Located in /var/lib/cassandra (persistent volume) not /etc (ephemeral)
        mkdir -p /var/lib/cassandra/.axonops
        {
            echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
            echo "RESULT=skipped"
            echo "REASON=disabled_by_env_var"
        } > /var/lib/cassandra/.axonops/init-system-keyspaces.done
        {
            echo "COMPLETED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
            echo "RESULT=skipped"
            echo "REASON=init_disabled"
        } > /var/lib/cassandra/.axonops/init-db-user.done
    fi
fi

echo ""

# ============================================================================
# Configure Scheduled Backups (if BACKUP_SCHEDULE provided)
# ============================================================================
# NOTE: No BACKUP_ENABLED flag needed - if user provides BACKUP_SCHEDULE, enable backups
# This simplifies configuration - one env var instead of two

if [ -n "${BACKUP_SCHEDULE:-}" ]; then
    echo "=== Configuring Scheduled Backups ==="
    echo "Schedule: ${BACKUP_SCHEDULE}"

    # CRITICAL: BACKUP_RETENTION_HOURS is mandatory when backups enabled
    if [ -z "${BACKUP_RETENTION_HOURS:-}" ]; then
        echo "ERROR: BACKUP_SCHEDULE provided but BACKUP_RETENTION_HOURS not set"
        echo "  Retention is MANDATORY to prevent disk fill"
        echo "  Examples:"
        echo "    BACKUP_RETENTION_HOURS=24      # Keep 24 hours"
        echo "    BACKUP_RETENTION_HOURS=168     # Keep 7 days"
        echo "    BACKUP_RETENTION_HOURS=720     # Keep 30 days"
        echo ""
        echo "CRITICAL: This is an invalid configuration"
        echo "Container cannot start with backup schedule but no retention policy"
        echo ""
        exit 1
    else
        echo "Retention: ${BACKUP_RETENTION_HOURS} hours"
        echo ""

        # Start backup scheduler in background (container-native, no cron needed)
        # This avoids PAM/crontab permission issues in containers
        # Backup output goes to console (for kubectl logs) AND file (via wrapper script)
        echo "Starting backup scheduler daemon..."
        (/usr/local/bin/backup-scheduler.sh >> /var/log/cassandra/backup-scheduler.log 2>&1 &)

        echo "✓ Backup scheduler started"
        echo "  Schedule: ${BACKUP_SCHEDULE}"
        echo "  Retention: ${BACKUP_RETENTION_HOURS} hours"
        echo "  Scheduler logs: /var/log/cassandra/backup-scheduler.log (rotated, compressed, retained)"
        echo "  Backup logs: /var/log/cassandra/backup-cron.log (rotated, compressed, retained)"
        echo "  Backup output visible in container logs (use: podman logs / kubectl logs)"
        echo ""
    fi
else
    echo "Scheduled backups disabled (BACKUP_SCHEDULE not set)"
    echo "You can manually trigger backups with: /usr/local/bin/cassandra-backup.sh"
    echo ""
fi

# ============================================================================
# Start Semaphore Monitor (background daemon for kubectl logs visibility)
# ============================================================================
# Monitors all semaphore files and echoes in-progress/error states to console
# Provides visibility into long-running operations (backups, restores, cleanup)
ENABLE_SEMAPHORE_MONITOR="${ENABLE_SEMAPHORE_MONITOR:-true}"

if [ "$ENABLE_SEMAPHORE_MONITOR" = "true" ]; then
    echo "Starting semaphore monitor daemon..."
    echo "  Interval: ${SEMAPHORE_MONITOR_INTERVAL:-60}s"
    echo "  Monitors: backup.lock, retention-cleanup.lock, restore.done, init semaphores"
    echo "  Alerts on: in_progress, error, failed states"
    (/usr/local/bin/semaphore-monitor.sh >> /var/log/cassandra/semaphore-monitor.log 2>&1 &)
    echo "✓ Semaphore monitor started"
    echo ""
fi

echo "=== Starting Cassandra ==="
echo ""

# Execute cassandra-wrapper.sh (which waits for restore if needed, then starts Cassandra)
# In restore scenario: wrapper waits for restore to complete, preventing data corruption
# In normal scenario: wrapper starts Cassandra immediately
# CMD is ["cassandra", "-f"] which gets passed as $@
exec /usr/local/bin/cassandra-wrapper.sh "$@"
