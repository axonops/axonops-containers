# Supply chain security: Use immutable digest instead of mutable tag
# UBI 9 minimal base image digest (latest as of 2025-12-10)
# Points to: registry.access.redhat.com/ubi9/ubi-minimal:latest
ARG UBI9_MINIMAL_DIGEST=sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2

# OpenSearch version and SHA512 checksum (from official OpenSearch artifacts)
ARG OPENSEARCH_VERSION=3.3.2
ARG OPENSEARCH_SHA512=68dc91ada02bda29a1efed6ef9916d893e58eef42e20482a6bdb1aab21c2fae490ef198a815b4ab8bcbcc87e44ce272b5943d8f67dcf37bb432e0205031a94e4

FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# Re-declare ARGs after FROM (Docker ARG scope rule)
ARG UBI9_MINIMAL_DIGEST
ARG TARGETARCH
ARG OPENSEARCH_VERSION
ARG OPENSEARCH_SHA512

# Build metadata arguments (provided by CI/CD or set to defaults for local builds)
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown
ARG VERSION=unknown
ARG GIT_TAG=unknown
ARG GITHUB_ACTOR=unknown
ARG IS_PRODUCTION_RELEASE=false
ARG IMAGE_FULL_NAME=unknown

ENV OPENSEARCH_VERSION=${OPENSEARCH_VERSION}
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN echo "AXONOPS_BUILD: Using UBI 9 minimal base image (registry.access.redhat.com/ubi9/ubi-minimal)"
RUN echo "AXONOPS_BUILD: Base image digest: ${UBI9_MINIMAL_DIGEST}"
RUN echo "AXONOPS_BUILD: Will download OpenSearch ${OPENSEARCH_VERSION} from official artifacts"

# Legacy labels (for backward compatibility)
LABEL maintainer="AxonOps"
LABEL name="AxonOps AxonDB Search (OpenSearch ${OPENSEARCH_VERSION})"
LABEL vendor="AxonOps"
LABEL url="https://axonops.com"
LABEL release="${OPENSEARCH_VERSION}"
LABEL summary="OpenSearch ${OPENSEARCH_VERSION} optimized for AxonOps self-hosted deployments with integrated monitoring and search workloads"
LABEL description="Production-ready OpenSearch ${OPENSEARCH_VERSION} container built on Red Hat UBI 9, featuring security plugin configuration, optimized JVM settings, and AxonOps-optimized configuration for search workloads."

# OCI standard labels
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.authors="AxonOps"
LABEL org.opencontainers.image.url="https://axonops.com"
LABEL org.opencontainers.image.documentation="https://github.com/axonops/axonops-containers/blob/main/axonops/axondb-search/README.md"
LABEL org.opencontainers.image.source="https://github.com/axonops/axonops-containers"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="AxonOps"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.title="AxonOps AxonDB Search (OpenSearch ${OPENSEARCH_VERSION})"
LABEL org.opencontainers.image.description="OpenSearch ${OPENSEARCH_VERSION} optimized for AxonOps self-hosted search workloads. Built from Red Hat UBI 9 minimal (${UBI9_MINIMAL_DIGEST})."
LABEL org.opencontainers.image.ref.name="${IMAGE_FULL_NAME}"
LABEL org.opencontainers.image.base.name="registry.access.redhat.com/ubi9/ubi-minimal:latest"
LABEL org.opencontainers.image.base.digest="${UBI9_MINIMAL_DIGEST}"

# AxonOps-specific labels (com.axonops.* namespace)
LABEL com.axonops.opensearch.version="${OPENSEARCH_VERSION}"
LABEL com.axonops.build.actor="${GITHUB_ACTOR}"

# Update all packages to latest versions (security patches)
RUN echo "Updating all packages to latest versions..." && \
    microdnf update -y && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# OpenSearch environment
ENV OPENSEARCH_HOME=/opt/opensearch
ENV OPENSEARCH_PATH_CONF=/etc/opensearch
ENV OPENSEARCH_DATA_DIR=/var/lib/opensearch
ENV OPENSEARCH_LOG_DIR=/var/log/opensearch
ENV PATH=${OPENSEARCH_HOME}/bin:${PATH}

# Create opensearch user and group (UID/GID 999 to match AxonDB Time-Series pattern)
RUN microdnf install -y --nodocs shadow-utils && \
    groupadd -r opensearch --gid=999 && \
    useradd -m -d "$OPENSEARCH_HOME" -r -g opensearch -G root --uid=999 opensearch && \
    microdnf clean all && \
    rm -rf /var/cache/yum

# Install runtime dependencies
# procps-ng: provides commands OpenSearch scripts may use
# iproute: network configuration tools
# nmap-ncat: provides nc for init script port checks
# Note: curl-minimal is pre-installed in UBI9-minimal, sufficient for healthcheck
RUN microdnf install -y --nodocs \
    tzdata \
    procps-ng \
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

# Download and install OpenSearch with SHA512 verification
RUN mkdir -p "$OPENSEARCH_HOME" /licenses && \
    cd /tmp && \
    OPENSEARCH_TARBALL="opensearch-${OPENSEARCH_VERSION}-linux-x64.tar.gz" && \
    echo "Downloading OpenSearch ${OPENSEARCH_VERSION} from official artifacts..." && \
    wget -q "https://artifacts.opensearch.org/releases/bundle/opensearch/${OPENSEARCH_VERSION}/${OPENSEARCH_TARBALL}" && \
    echo "${OPENSEARCH_SHA512}  ${OPENSEARCH_TARBALL}" | sha512sum -c - && \
    echo "Extracting OpenSearch to ${OPENSEARCH_HOME}..." && \
    tar -xzf "${OPENSEARCH_TARBALL}" --strip-components=1 -C "$OPENSEARCH_HOME" && \
    rm "${OPENSEARCH_TARBALL}" && \
    cp "$OPENSEARCH_HOME/LICENSE.txt" /licenses/LICENSE.txt && \
    # Move config directory to /etc/opensearch
    mv "$OPENSEARCH_HOME/config" /etc/opensearch && \
    ln -s /etc/opensearch "$OPENSEARCH_HOME/config" && \
    # Remove data and logs directories (will be volumes)
    rm -rf "$OPENSEARCH_HOME/data" "$OPENSEARCH_HOME/logs" && \
    # Set ownership
    chown -R opensearch:root "$OPENSEARCH_HOME" /etc/opensearch /licenses && \
    rm -rf /tmp/*

# Overlay our custom config files to /etc/opensearch (before SSL setup)
COPY --chown=opensearch:root config/jvm.options /etc/opensearch/jvm.options
COPY --chown=opensearch:root config/log4j2.properties /etc/opensearch/log4j2.properties

# Install demo SSL configuration and delete demo certs in ONE layer
# Certificates will be generated at RUNTIME (not build time) to avoid Trivy secret detection
# Demo script sets up security infrastructure, then we delete demo certs
RUN cd ${OPENSEARCH_HOME} && \
    DISABLE_INSTALL_DEMO_CONFIG=false \
    OPENSEARCH_INITIAL_ADMIN_PASSWORD='MyS3cur3P@ss2025' \
    bash ${OPENSEARCH_HOME}/plugins/opensearch-security/tools/install_demo_configuration.sh -y -i -s && \
    chown -R opensearch:root /etc/opensearch && \
    echo "Demo SSL infrastructure created" && \
    rm -f /etc/opensearch/esnode.pem \
          /etc/opensearch/esnode-key.pem \
          /etc/opensearch/kirk.pem \
          /etc/opensearch/kirk-key.pem \
          /etc/opensearch/root-ca.pem \
          /etc/opensearch/root-ca-key.pem \
          /etc/opensearch/*.srl \
          /etc/opensearch/securityadmin_demo.sh && \
    echo "✓ Demo certificates removed in same layer"

# Copy certificate generation script (will be run at container startup)
COPY scripts/generate-certs.sh /usr/local/bin/generate-certs.sh
RUN chmod 755 /usr/local/bin/generate-certs.sh

# Now overlay our customized opensearch.yml and security configs
# This updates the security plugin to use our AxonOps certificates instead of demo certs
COPY --chown=opensearch:root config/opensearch.yml /etc/opensearch/opensearch.yml
COPY --chown=opensearch:root config/security/action_groups.yml /etc/opensearch/opensearch-security/action_groups.yml
COPY --chown=opensearch:root config/security/allowlist.yml /etc/opensearch/opensearch-security/allowlist.yml
COPY --chown=opensearch:root config/security/audit.yml /etc/opensearch/opensearch-security/audit.yml
COPY --chown=opensearch:root config/security/config.yml /etc/opensearch/opensearch-security/config.yml
COPY --chown=opensearch:root config/security/internal_users.yml /etc/opensearch/opensearch-security/internal_users.yml
COPY --chown=opensearch:root config/security/nodes_dn.yml /etc/opensearch/opensearch-security/nodes_dn.yml
COPY --chown=opensearch:root config/security/roles.yml /etc/opensearch/opensearch-security/roles.yml
COPY --chown=opensearch:root config/security/roles_mapping.yml /etc/opensearch/opensearch-security/roles_mapping.yml
COPY --chown=opensearch:root config/security/tenants.yml /etc/opensearch/opensearch-security/tenants.yml

# Create data and log directories
RUN mkdir -p ${OPENSEARCH_DATA_DIR} ${OPENSEARCH_LOG_DIR} && \
    chown -R opensearch:root ${OPENSEARCH_DATA_DIR} ${OPENSEARCH_LOG_DIR} && \
    chmod 775 ${OPENSEARCH_DATA_DIR} ${OPENSEARCH_LOG_DIR} && \
    chmod a+rwX ${OPENSEARCH_HOME} /etc/opensearch

# Set JAVA_HOME to bundled JDK
ENV JAVA_HOME=${OPENSEARCH_HOME}/jdk
ENV PATH=${JAVA_HOME}/bin:${PATH}

# Add KNN plugin library path (required for opensearch-knn plugin)
ENV LD_LIBRARY_PATH=${OPENSEARCH_HOME}/plugins/opensearch-knn/lib

# Copy our healthcheck script
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/healthcheck.sh

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
    echo "OPENSEARCH_VERSION=\"${OPENSEARCH_VERSION}\"" >> /etc/axonops/build-info.txt && \
    echo "UBI9_BASE_DIGEST=\"${UBI9_MINIMAL_DIGEST}\"" >> /etc/axonops/build-info.txt && \
    echo "JAVA_VERSION=\"$(${JAVA_HOME}/bin/java -version 2>&1 | head -1 || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "OS_VERSION=\"$(grep PRETTY_NAME /etc/os-release 2>/dev/null | sed 's/.*="\(.*\)"/\1/' || echo 'unknown') (UBI - Universal Base Image, freely redistributable)\"" >> /etc/axonops/build-info.txt && \
    echo "PLATFORM=\"$(uname -m || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    chown -R opensearch:root /etc/axonops

# AxonDB entrypoint
COPY scripts/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh && \
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
USER opensearch

# Expose volumes
VOLUME ["${OPENSEARCH_DATA_DIR}", "${OPENSEARCH_LOG_DIR}"]

# OPENSEARCH PORTS (HTTP API, TRANSPORT, PERFORMANCE ANALYZER)
EXPOSE 9200 9300

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh readiness

ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["opensearch"]
