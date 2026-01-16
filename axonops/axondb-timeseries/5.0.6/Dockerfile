# Supply chain security: Use immutable digest instead of mutable tag
# UBI 9 minimal base image digest (latest as of 2025-12-10)
# Points to: registry.access.redhat.com/ubi9/ubi-minimal:latest
ARG UBI9_MINIMAL_DIGEST=sha256:6fc28bcb6776e387d7a35a2056d9d2b985dc4e26031e98a2bd35a7137cd6fd71

# Cassandra version and SHA512 checksum (from official Apache Cassandra)
ARG CASSANDRA_VERSION=5.0.6
ARG CASSANDRA_SHA512=cab82049269e91ecd13e525254427d9b6139d8982fd1ddb8256ac7ebebc2fae412721750d7b30b1ee4e86f81d1960a87a2220d4a4a34d11f05c5aca0be6cd649

FROM --platform=$BUILDPLATFORM alpine:latest AS extractor
ARG CASSANDRA_VERSION
ARG CASSANDRA_SHA512

RUN apk add --no-cache wget tar gnupg

# Download and install Apache Cassandra with SHA512 verification
RUN CASSANDRA_TARBALL="apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz" && \
    echo "Downloading Cassandra ${CASSANDRA_VERSION} from Apache mirrors..." && \
    wget -q "https://dlcdn.apache.org/cassandra/${CASSANDRA_VERSION}/${CASSANDRA_TARBALL}" -O /tmp/$CASSANDRA_TARBALL || \
    wget -q "https://archive.apache.org/dist/cassandra/${CASSANDRA_VERSION}/${CASSANDRA_TARBALL}" -O /tmp/$CASSANDRA_TARBALL && \
    echo "${CASSANDRA_SHA512} /tmp/${CASSANDRA_TARBALL}" | sha512sum -c - && \
    mkdir -p /opt/tmp && \
    tar -xzf "/tmp/${CASSANDRA_TARBALL}" --no-same-owner -C /opt/tmp && \
    mv "/opt/tmp/apache-cassandra-${CASSANDRA_VERSION}" /opt/tmp/cassandra

FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# Re-declare ARGs after FROM (Docker ARG scope rule)
ARG UBI9_MINIMAL_DIGEST
ARG TARGETARCH
ARG CASSANDRA_VERSION
ARG CASSANDRA_SHA512
ARG CQLAI_VERSION

# Build metadata arguments (provided by CI/CD or set to defaults for local builds)
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown
ARG VERSION=unknown
ARG GIT_TAG=unknown
ARG GITHUB_ACTOR=unknown
ARG IS_PRODUCTION_RELEASE=false
ARG IMAGE_FULL_NAME=unknown
ARG YQ_VERSION=v4.50.1

ENV CASSANDRA_VERSION=${CASSANDRA_VERSION}
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN echo "AXONOPS_BUILD: Using UBI 9 minimal base image (registry.access.redhat.com/ubi9/ubi-minimal)"
RUN echo "AXONOPS_BUILD: Base image digest: ${UBI9_MINIMAL_DIGEST}"
RUN echo "AXONOPS_BUILD: Will download Cassandra ${CASSANDRA_VERSION} from Apache mirrors"

# Legacy labels (for backward compatibility)
LABEL maintainer="AxonOps"
LABEL name="AxonOps AxonDB Time-Series Database (Apache Cassandra ${CASSANDRA_VERSION})"
LABEL vendor="AxonOps"
LABEL url="https://axonops.com"
LABEL release="${CASSANDRA_VERSION}"
LABEL summary="Apache Cassandra ${CASSANDRA_VERSION} optimized for AxonOps self-hosted deployments with integrated monitoring and time-series workloads"
LABEL description="Production-ready Apache Cassandra ${CASSANDRA_VERSION} container built on Red Hat UBI 9, featuring system keyspace auto-initialization, jemalloc memory optimization, cqlai v${CQLAI_VERSION}, and AxonOps-optimized configuration for time-series database workloads."

# OCI standard labels
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.authors="AxonOps"
LABEL org.opencontainers.image.url="https://axonops.com"
LABEL org.opencontainers.image.documentation="https://github.com/axonops/axonops-containers/blob/main/axonops/axondb-timeseries/README.md"
LABEL org.opencontainers.image.source="https://github.com/axonops/axonops-containers"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="AxonOps"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.title="AxonOps AxonDB Time-Series (Apache Cassandra ${CASSANDRA_VERSION})"
LABEL org.opencontainers.image.description="Apache Cassandra ${CASSANDRA_VERSION} with cqlai v${CQLAI_VERSION} and jemalloc memory optimization. Built from Red Hat UBI 9 minimal (${UBI9_MINIMAL_DIGEST}). Optimized for AxonOps self-hosted time-series workloads."
LABEL org.opencontainers.image.ref.name="${IMAGE_FULL_NAME}"
LABEL org.opencontainers.image.base.name="registry.access.redhat.com/ubi9/ubi-minimal:latest"
LABEL org.opencontainers.image.base.digest="${UBI9_MINIMAL_DIGEST}"

# AxonOps-specific labels (com.axonops.* namespace)
LABEL com.axonops.cassandra.version="${CASSANDRA_VERSION}"
LABEL com.axonops.cqlai.version="${CQLAI_VERSION}"
LABEL com.axonops.build.actor="${GITHUB_ACTOR}"

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
ENV CASSANDRA_DATA_DIR=/var/lib/cassandra/data

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
# rsync: required for backup/restore functionality
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
    rsync \
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
    rm -rf /var/cache/yum /var/cache/dnf /opt/cassandra

COPY --from=extractor /opt/tmp/cassandra /opt/cassandra

# Download and install Apache Cassandra with SHA512 verification
RUN mkdir -p /licenses && \
    cd /opt && \
    cp "$CASSANDRA_HOME/LICENSE.txt" /licenses/LICENSE.txt && \
    mv "$CASSANDRA_HOME/conf" /etc/cassandra && \
    ln -s /etc/cassandra "$CASSANDRA_HOME/conf" && \
    chown -R cassandra:root "$CASSANDRA_HOME" /etc/cassandra /licenses && \
    rm -rf /tmp/*

# Get yq, this will be used to modify the cassandra.yaml if needed
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        YQ_ARCH="amd64"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        YQ_ARCH="arm64"; \
    else \
        echo "ERROR: Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    wget -q -O /tmp/checksums.txt https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/checksums-bsd && \
    wget -q -O /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH} && \
    # Extract expected hash from checksums.txt and compare only the hash portion
    EXPECTED_SHA256=$(grep "SHA256 (yq_linux_${YQ_ARCH})" /tmp/checksums.txt | awk '{print $4}') && \
    LOCAL_SHA256=$(sha256sum /usr/local/bin/yq | awk '{print $1}') && \
    if [ "${EXPECTED_SHA256}" != "${LOCAL_SHA256}" ]; then \
      echo "ERROR: Checksum failed for yq_linux_${YQ_ARCH}" >&2; \
      echo "Expected: ${EXPECTED_SHA256}" >&2; \
      echo "Got     : ${LOCAL_SHA256}" >&2; \
      exit 1; \
    fi && \
    chmod +x /usr/local/bin/yq && \
    rpm -Uvh https://downloads.rclone.org/v1.72.1/rclone-v1.72.1-linux-${YQ_ARCH}.rpm && \
    rm -f /tmp/checksums.txt

# Install cqlai
# Note: Uses uname -m for architecture detection. For multi-arch builds with buildx,
# this will be set correctly by the platform-specific base image.
RUN if [ -z "$CQLAI_VERSION" ]; then \
      echo "ERROR: CQLAI_VERSION build arg is required"; \
      exit 1; \
    fi && \
    echo "Installing cqlai version: $CQLAI_VERSION" && \
    RPM_ARCH=$(uname -m) && \
    echo "Detected architecture: $RPM_ARCH" && \
    CQLAI_RPM="cqlai-${CQLAI_VERSION}-1.${RPM_ARCH}.rpm" && \
    CQLAI_URL="https://github.com/axonops/cqlai/releases/download/v${CQLAI_VERSION}" && \
    curl -sL -o "/tmp/${CQLAI_RPM}" "${CQLAI_URL}/${CQLAI_RPM}" && \
    if curl -sL -o /tmp/SHA256SUMS.txt "${CQLAI_URL}/SHA256SUMS.txt" 2>/dev/null && [ -s /tmp/SHA256SUMS.txt ]; then \
      echo "Verifying checksum..." && \
      (cd /tmp && grep "${CQLAI_RPM}" SHA256SUMS.txt | sha256sum -c - || echo "WARNING: Checksum verification failed, continuing anyway"); \
    else \
      echo "WARNING: SHA256SUMS.txt not found, skipping checksum verification"; \
    fi && \
    rpm -i "/tmp/${CQLAI_RPM}" && \
    rm -f "${CQLAI_RPM}" SHA256SUMS.txt && \
    rm -rf /var/tmp/rpm-* /var/cache/yum /var/cache/dnf

# Overlay our custom config files to /etc/cassandra
COPY --chown=cassandra:root config/cassandra.yaml /etc/cassandra/cassandra.yaml
COPY --chown=cassandra:root config/jvm-server.options /etc/cassandra/jvm-server.options
COPY --chown=cassandra:root config/jvm17-server.options /etc/cassandra/jvm17-server.options
COPY --chown=cassandra:root config/cassandra-env.sh /etc/cassandra/cassandra-env.sh
COPY --chown=cassandra:root config/logback.xml /etc/cassandra/logback.xml

# Create data and log directories
# Also ensure parent directory /var/lib/cassandra is owned by cassandra user
# This is needed for semaphore files in /var/lib/cassandra/.axonops
RUN mkdir -p ${CASSANDRA_DATA_DIR} ${CASSANDRA_LOG_DIR} && \
    chown -R cassandra:root /var/lib/cassandra ${CASSANDRA_LOG_DIR} && \
    chmod 775 /var/lib/cassandra ${CASSANDRA_DATA_DIR} ${CASSANDRA_LOG_DIR} && \
    chmod a+rwX ${CASSANDRA_PATH} /etc/cassandra

# Copy initialization script (handles both keyspace init and user creation)
COPY scripts/init-system-keyspaces.sh /usr/local/bin/init-system-keyspaces.sh
RUN chmod 755 /usr/local/bin/init-system-keyspaces.sh

# Copy backup and restore scripts
COPY scripts/cassandra-remote-backup.sh /usr/local/bin/cassandra-remote=backup.sh
COPY scripts/cassandra-backup.sh /usr/local/bin/cassandra-backup.sh
COPY scripts/cassandra-restore.sh /usr/local/bin/cassandra-restore.sh
COPY scripts/backup-cron-wrapper.sh /usr/local/bin/backup-cron-wrapper.sh
COPY scripts/backup-scheduler.sh /usr/local/bin/backup-scheduler.sh
COPY scripts/cassandra-wrapper.sh /usr/local/bin/cassandra-wrapper.sh
COPY scripts/retention-cleanup.sh /usr/local/bin/retention-cleanup.sh
COPY scripts/log-rotate.sh /usr/local/bin/log-rotate.sh
COPY scripts/semaphore-monitor.sh /usr/local/bin/semaphore-monitor.sh
COPY scripts/post-restore-create-user.sh /usr/local/bin/post-restore-create-user.sh
RUN chmod 755 /usr/local/bin/*.sh

# Generate comprehensive build information for runtime startup banner
# Values are quoted for safe sourcing in bash
RUN mkdir -p /etc/axonops && \
    echo "CONTAINER_VERSION=\"${VERSION}\"" > /etc/axonops/build-info.txt && \
    echo "CONTAINER_IMAGE=\"${IMAGE_FULL_NAME}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_REVISION=\"${VCS_REF}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_GIT_TAG=\"${GIT_TAG}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_BUILD_DATE=\"${BUILD_DATE}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_BUILT_BY=\"${GITHUB_ACTOR}\"" >> /etc/axonops/build-info.txt && \
    echo "IS_PRODUCTION_RELEASE=\"${IS_PRODUCTION_RELEASE}\"" >> /etc/axonops/build-info.txt && \
    echo "CASSANDRA_VERSION=\"${CASSANDRA_VERSION}\"" >> /etc/axonops/build-info.txt && \
    echo "UBI9_BASE_DIGEST=\"${UBI9_MINIMAL_DIGEST}\"" >> /etc/axonops/build-info.txt && \
    echo "JAVA_VERSION=\"$(java -version 2>&1 | head -2 | tail -1 || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "CQLAI_VERSION=\"$(cqlai --version 2>&1 | awk '{print $NF}' || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "JEMALLOC_VERSION=\"$(rpm -q jemalloc 2>/dev/null || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "OS_VERSION=\"$(grep PRETTY_NAME /etc/os-release 2>/dev/null | sed 's/.*="\(.*\)"/\1/' || echo 'unknown') (UBI - Universal Base Image, freely redistributable)\"" >> /etc/axonops/build-info.txt && \
    echo "PLATFORM=\"$(uname -m || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    chown -R cassandra:root /etc/axonops

# AxonDB entrypoint
COPY scripts/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    ln -sf /usr/local/bin/docker-entrypoint.sh /docker-entrypoint.sh && \
    ln -sf /proc/mounts /etc/mtab

# Tini init system (minimal init for containers - handles signals and prevents zombies)
# Note: Uses uname -m for architecture detection. For multi-arch builds with buildx,
# this will be set correctly by the platform-specific base image.
RUN TINI_VERSION=v0.19.0 && \
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
    wget -q -O /tini "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TINI_ARCH}" && \
    echo "${TINI_SHA256}  /tini" | sha256sum -c - && \
    chmod +x /tini

# Set user to run as
USER cassandra

# Expose volumes
VOLUME ["/var/lib/cassandra", "/var/log/cassandra", "/backup"]

# CASSANDRA PORTS (INTRA-NODE, TLS INTRA-NODE, JMX, CQL, THRIFT)
EXPOSE 7000 7001 7199 9042 9160

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh readiness

ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["cassandra", "-f"]
