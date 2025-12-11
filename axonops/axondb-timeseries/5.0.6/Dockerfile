# syntax=docker/dockerfile:1.4

# Supply chain security: Use immutable digest instead of mutable tag
# UBI 9 minimal base image digest (latest as of 2025-12-10)
# Points to: registry.access.redhat.com/ubi9/ubi-minimal:latest
ARG UBI9_MINIMAL_DIGEST=sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2

# Cassandra version and SHA512 checksum (from official Apache Cassandra)
ARG CASSANDRA_VERSION=5.0.6
ARG CASSANDRA_SHA512=cab82049269e91ecd13e525254427d9b6139d8982fd1ddb8256ac7ebebc2fae412721750d7b30b1ee4e86f81d1960a87a2220d4a4a34d11f05c5aca0be6cd649

FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# Re-declare ARGs after FROM (Docker ARG scope rule)
ARG UBI9_MINIMAL_DIGEST
ARG TARGETARCH
ARG CASSANDRA_VERSION
ARG CASSANDRA_SHA512
ARG CQLAI_VERSION

ENV CASSANDRA_VERSION=${CASSANDRA_VERSION}
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN echo "AXONOPS_BUILD: Using UBI 9 minimal base image (digest: ${UBI9_MINIMAL_DIGEST})"
RUN echo "AXONOPS_BUILD: Will download Cassandra ${CASSANDRA_VERSION} from Apache mirrors"

LABEL maintainer="AxonOps"
LABEL name="AxonOps AxonDB Time-Series Database (Apache Cassandra ${CASSANDRA_VERSION})"
LABEL vendor="AxonOps"
LABEL release="${CASSANDRA_VERSION}"
LABEL summary="Apache Cassandra ${CASSANDRA_VERSION} optimized for AxonOps self-hosted deployments with integrated monitoring and time-series workloads"
LABEL description="Production-ready Apache Cassandra ${CASSANDRA_VERSION} container built on Red Hat UBI 9, featuring system keyspace auto-initialization, jemalloc memory optimization, cqlai modern CQL shell, and AxonOps-optimized configuration for time-series database workloads."

# Update all packages to latest versions (security patches)
RUN echo "Updating all packages to latest versions..." && \
    microdnf update -y && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# Cassandra environment
ENV CASSANDRA_PATH=/opt/cassandra
ENV PATH=${CASSANDRA_PATH}/bin:${PATH}
ENV CASSANDRA_HOME=${CASSANDRA_PATH}
ENV CASSANDRA_CONF=/etc/cassandra
ENV CASSANDRA_LOG_DIR=/var/log/cassandra
ENV CASSANDRA_DATA_DIR=/var/lib/cassandra

# Create cassandra user and group
RUN microdnf install -y --nodocs shadow-utils && \
    groupadd -r cassandra --gid=999 && \
    useradd -m -d "$CASSANDRA_HOME" -r -g cassandra -G root --uid=999 cassandra && \
    microdnf clean all && \
    rm -rf /var/cache/yum

# Install runtime dependencies
# procps-ng: provides commands Cassandra scripts use
# python3.11: required by cqlsh
# iproute: network configuration tools
# numactl: NUMA support (auto-detected by Cassandra)
# nmap-ncat: provides nc for init script port checks
# Note: curl-minimal is pre-installed in UBI9-minimal, sufficient for our needs
RUN microdnf install -y --nodocs \
    java-17-openjdk-headless \
    tzdata-java \
    python3.11 \
    procps-ng \
    numactl \
    iproute \
    nmap-ncat \
    findutils \
    which \
    hostname \
    util-linux \
    glibc-langpack-en \
    tar \
    gzip \
    wget \
    && microdnf clean all \
    && rm -rf /var/cache/yum /var/cache/dnf

# Install jemalloc from EPEL
RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    microdnf install -y jemalloc && \
    test -f /usr/lib64/libjemalloc.so.2 || (echo "ERROR: jemalloc not installed correctly" && exit 1) && \
    ln -sf /usr/lib64/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf && \
    ldconfig && \
    microdnf remove -y epel-release && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# Download and install Apache Cassandra with SHA512 verification
RUN mkdir -p "$CASSANDRA_HOME" /licenses && \
    cd /tmp && \
    CASSANDRA_TARBALL="apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz" && \
    echo "Downloading Cassandra ${CASSANDRA_VERSION} from Apache mirrors..." && \
    wget -q "https://dlcdn.apache.org/cassandra/${CASSANDRA_VERSION}/${CASSANDRA_TARBALL}" || \
    wget -q "https://archive.apache.org/dist/cassandra/${CASSANDRA_VERSION}/${CASSANDRA_TARBALL}" && \
    echo "${CASSANDRA_SHA512}  ${CASSANDRA_TARBALL}" | sha512sum -c - && \
    echo "Extracting Cassandra to ${CASSANDRA_HOME}..." && \
    tar -xzf "${CASSANDRA_TARBALL}" --strip-components=1 -C "$CASSANDRA_HOME" && \
    rm "${CASSANDRA_TARBALL}" && \
    cp "$CASSANDRA_HOME/LICENSE.txt" /licenses/LICENSE.txt && \
    mv "$CASSANDRA_HOME/conf" /etc/cassandra && \
    ln -s /etc/cassandra "$CASSANDRA_HOME/conf" && \
    chown -R cassandra:root "$CASSANDRA_HOME" /etc/cassandra /licenses && \
    rm -rf /tmp/*

# Install cqlai with BuildKit cache mount, checksum verification, and retry logic
# Cache is version-specific and always verified against upstream checksums
# Note: Uses uname -m for architecture detection. For multi-arch builds with buildx,
# this will be set correctly by the platform-specific base image.
RUN --mount=type=cache,target=/var/cache/cqlai,id=cqlai-rpms,sharing=locked \
    if [ -z "$CQLAI_VERSION" ]; then \
      echo "ERROR: CQLAI_VERSION build arg is required"; \
      exit 1; \
    fi && \
    echo "Installing cqlai version: $CQLAI_VERSION" && \
    RPM_ARCH=$(uname -m) && \
    echo "Detected architecture: $RPM_ARCH" && \
    CQLAI_RPM="cqlai-${CQLAI_VERSION}-1.${RPM_ARCH}.rpm" && \
    CQLAI_URL="https://github.com/axonops/cqlai/releases/download/v${CQLAI_VERSION}" && \
    CACHE_RPM="/var/cache/cqlai/${CQLAI_RPM}" && \
    \
    echo "[INFO] Downloading checksum file..." && \
    curl -fsSL --retry 3 -o /tmp/SHA256SUMS.txt "${CQLAI_URL}/SHA256SUMS.txt" || { \
      echo "[WARNING] Checksum file not available, proceeding without verification"; \
      SKIP_CHECKSUM=true; \
    } && \
    \
    USE_CACHE=false && \
    if [ -f "${CACHE_RPM}" ]; then \
      echo "[CACHE] Cached RPM found, verifying checksum..." && \
      if [ "$SKIP_CHECKSUM" != "true" ] && (cd /var/cache/cqlai && grep "${CQLAI_RPM}" /tmp/SHA256SUMS.txt | sha256sum -c - 2>&1); then \
        echo "[CACHE] HIT - Checksum valid, using cached RPM" && \
        USE_CACHE=true; \
      else \
        echo "[CACHE] INVALID - Checksum failed or unavailable, will re-download" && \
        rm -f "${CACHE_RPM}"; \
      fi; \
    else \
      echo "[CACHE] MISS - RPM not in cache"; \
    fi && \
    \
    if [ "$USE_CACHE" = "false" ]; then \
      echo "[INFO] Downloading cqlai RPM..." && \
      for attempt in 1 2 3 4 5; do \
        echo "[INFO] Download attempt ${attempt}/5" && \
        if curl -fsSL --retry 3 --retry-delay 5 --retry-max-time 120 \
          -o "${CACHE_RPM}.tmp" "${CQLAI_URL}/${CQLAI_RPM}"; then \
          mv "${CACHE_RPM}.tmp" "${CACHE_RPM}" && \
          echo "[INFO] Download successful" && \
          break; \
        else \
          echo "[WARNING] Download failed" && \
          rm -f "${CACHE_RPM}.tmp" && \
          if [ ${attempt} -lt 5 ]; then \
            sleep_time=$((attempt * 10)); \
            echo "[INFO] Retrying in ${sleep_time}s..." && \
            sleep ${sleep_time}; \
          else \
            echo "[ERROR] Failed to download after 5 attempts"; \
            exit 1; \
          fi; \
        fi; \
      done && \
      \
      if [ "$SKIP_CHECKSUM" != "true" ]; then \
        echo "[INFO] Verifying downloaded RPM checksum..." && \
        (cd /var/cache/cqlai && grep "${CQLAI_RPM}" /tmp/SHA256SUMS.txt | sha256sum -c -) || { \
          echo "[ERROR] Checksum verification failed for downloaded RPM"; \
          exit 1; \
        } && \
        echo "[INFO] Checksum verified"; \
      fi; \
    fi && \
    \
    echo "[INFO] Installing cqlai RPM" && \
    rpm -i "${CACHE_RPM}" && \
    echo "[INFO] cqlai installation complete" && \
    rm -f /tmp/SHA256SUMS.txt && \
    rm -rf /var/tmp/rpm-* /var/cache/yum /var/cache/dnf

# Overlay our custom config files to /etc/cassandra
COPY --chown=cassandra:root config/cassandra.yaml /etc/cassandra/cassandra.yaml
COPY --chown=cassandra:root config/jvm-server.options /etc/cassandra/jvm-server.options
COPY --chown=cassandra:root config/jvm17-server.options /etc/cassandra/jvm17-server.options

# Create data and log directories
RUN mkdir -p ${CASSANDRA_DATA_DIR} ${CASSANDRA_LOG_DIR} && \
    chown -R cassandra:root ${CASSANDRA_DATA_DIR} ${CASSANDRA_LOG_DIR} && \
    chmod 775 ${CASSANDRA_DATA_DIR} ${CASSANDRA_LOG_DIR} && \
    chmod a+rwX ${CASSANDRA_PATH} /etc/cassandra

# Copy our healthcheck script
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/healthcheck.sh

# Copy initialization script (handles both keyspace init and user creation)
COPY scripts/init-system-keyspaces.sh /usr/local/bin/init-system-keyspaces.sh
RUN chmod 755 /usr/local/bin/init-system-keyspaces.sh

# Generate build info
RUN mkdir -p /etc/axonops && \
    echo "CASSANDRA_VERSION=\"${CASSANDRA_VERSION}\"" > /etc/axonops/build-info.txt && \
    echo "JAVA_VERSION=\"$(java -version 2>&1 | head -2 | tail -1)\"" >> /etc/axonops/build-info.txt && \
    echo "CQLAI_VERSION=\"$(cqlai --version 2>&1 | awk '{print $NF}')\"" >> /etc/axonops/build-info.txt && \
    echo "JEMALLOC_VERSION=\"$(rpm -q jemalloc)\"" >> /etc/axonops/build-info.txt && \
    chown -R cassandra:root /etc/axonops

# AxonDB entrypoint
COPY scripts/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh && \
    ln -sf /usr/local/bin/docker-entrypoint.sh /docker-entrypoint.sh && \
    ln -sf /proc/mounts /etc/mtab

# Tini init system (minimal init for containers - handles signals and prevents zombies)
# Uses cache mount + retry logic for reliability (same as cqlai)
# Note: Uses uname -m for architecture detection. For multi-arch builds with buildx,
# this will be set correctly by the platform-specific base image.
RUN --mount=type=cache,target=/var/cache/tini,id=tini-binaries,sharing=locked \
    TINI_VERSION=v0.19.0 && \
    ARCH=$(uname -m) && \
    echo "Detected architecture for Tini: $ARCH" && \
    if [ "$ARCH" = "x86_64" ]; then \
        TINI_ARCH="amd64"; \
        TINI_SHA256="93dcc18adc78c65a028a84799ecf8ad40c936fdfc5f2a57b1acda5a8117fa82c"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        TINI_ARCH="arm64"; \
        TINI_SHA256="07952557df20bfd2a95f9bef198b445e006171969499a1d361bd9e6f8e5e0e81"; \
    else \
        echo "ERROR: Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    TINI_URL="https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TINI_ARCH}" && \
    CACHE_TINI="/var/cache/tini/tini-${TINI_VERSION}-${TINI_ARCH}" && \
    \
    USE_CACHE=false && \
    if [ -f "${CACHE_TINI}" ]; then \
      echo "[CACHE] Cached tini found, verifying checksum..." && \
      if echo "${TINI_SHA256}  ${CACHE_TINI}" | sha256sum -c - 2>&1; then \
        echo "[CACHE] HIT - Checksum valid, using cached tini" && \
        USE_CACHE=true; \
      else \
        echo "[CACHE] INVALID - Checksum failed, will re-download" && \
        rm -f "${CACHE_TINI}"; \
      fi; \
    else \
      echo "[CACHE] MISS - Tini not in cache"; \
    fi && \
    \
    if [ "$USE_CACHE" = "false" ]; then \
      echo "[INFO] Downloading tini..." && \
      for attempt in 1 2 3 4 5; do \
        echo "[INFO] Download attempt ${attempt}/5" && \
        if wget -q -O "${CACHE_TINI}.tmp" "${TINI_URL}"; then \
          mv "${CACHE_TINI}.tmp" "${CACHE_TINI}" && \
          echo "[INFO] Download successful" && \
          break; \
        else \
          echo "[WARNING] Download failed" && \
          rm -f "${CACHE_TINI}.tmp" && \
          if [ ${attempt} -lt 5 ]; then \
            sleep_time=$((attempt * 5)); \
            echo "[INFO] Retrying in ${sleep_time}s..." && \
            sleep ${sleep_time}; \
          else \
            echo "[ERROR] Failed to download tini after 5 attempts"; \
            exit 1; \
          fi; \
        fi; \
      done && \
      echo "[INFO] Verifying downloaded tini checksum..." && \
      echo "${TINI_SHA256}  ${CACHE_TINI}" | sha256sum -c -; \
    fi && \
    \
    cp "${CACHE_TINI}" /tini && \
    chmod +x /tini && \
    echo "[INFO] Tini installation complete"

# Set user to run as
USER cassandra

# Expose volumes
VOLUME ["/var/lib/cassandra", "/var/log/cassandra"]

# CASSANDRA PORTS (INTRA-NODE, TLS INTRA-NODE, JMX, CQL, THRIFT)
EXPOSE 7000 7001 7199 9042 9160

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh readiness

ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["cassandra", "-f"]
