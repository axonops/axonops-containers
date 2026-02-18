# Supply chain security: Use immutable digest instead of mutable tag
# UBI 9 minimal base image digest (latest as of 2025-12-10)
# Points to: registry.access.redhat.com/ubi9/ubi-minimal:latest
ARG UBI9_MINIMAL_DIGEST=sha256:6fc28bcb6776e387d7a35a2056d9d2b985dc4e26031e98a2bd35a7137cd6fd71

# axonops-schema-registry version (application version from upstream releases)
ARG SR_VERSION=0.2.0

FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# Re-declare ARGs after FROM (Docker ARG scope rule)
ARG UBI9_MINIMAL_DIGEST
ARG TARGETARCH
ARG SR_VERSION

# Build metadata arguments (provided by CI/CD or set to defaults for local builds)
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown
ARG VERSION=unknown
ARG BUILD_NUMBER=1
ARG GIT_TAG=unknown
ARG GITHUB_ACTOR=unknown
ARG IS_PRODUCTION_RELEASE=false
ARG IMAGE_FULL_NAME=unknown

ENV SR_VERSION=${SR_VERSION}

RUN echo "AXONOPS_BUILD: Using UBI 9 minimal base image (registry.access.redhat.com/ubi9/ubi-minimal)"
RUN echo "AXONOPS_BUILD: Base image digest: ${UBI9_MINIMAL_DIGEST}"
RUN echo "AXONOPS_BUILD: Will download axonops-schema-registry ${SR_VERSION} from GitHub Releases"

# Legacy labels (for backward compatibility)
LABEL maintainer="AxonOps"
LABEL name="AxonOps Schema Registry ${SR_VERSION}"
LABEL vendor="AxonOps"
LABEL url="https://axonops.com"
LABEL release="${SR_VERSION}"
LABEL summary="AxonOps Schema Registry ${SR_VERSION} — Confluent-compatible Kafka Schema Registry with multi-backend storage"
LABEL description="Production-ready AxonOps Schema Registry ${SR_VERSION} container built on Red Hat UBI 9. Provides Confluent-compatible Schema Registry API with PostgreSQL, MySQL, Cassandra 5+, and in-memory storage backends."

# OCI standard labels
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.authors="AxonOps"
LABEL org.opencontainers.image.url="https://axonops.com"
LABEL org.opencontainers.image.documentation="https://github.com/axonops/axonops-containers/blob/main/axonops-schema-registry/README.md"
LABEL org.opencontainers.image.source="https://github.com/axonops/axonops-containers"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="AxonOps"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.title="AxonOps Schema Registry ${SR_VERSION}"
LABEL org.opencontainers.image.description="AxonOps Schema Registry ${SR_VERSION} with Confluent-compatible API. Built from Red Hat UBI 9 minimal (${UBI9_MINIMAL_DIGEST})."
LABEL org.opencontainers.image.ref.name="${IMAGE_FULL_NAME}"
LABEL org.opencontainers.image.base.name="registry.access.redhat.com/ubi9/ubi-minimal:latest"
LABEL org.opencontainers.image.base.digest="${UBI9_MINIMAL_DIGEST}"

# AxonOps-specific labels (com.axonops.* namespace)
LABEL com.axonops.schema-registry.version="${SR_VERSION}"
LABEL com.axonops.build.number="${BUILD_NUMBER}"
LABEL com.axonops.build.actor="${GITHUB_ACTOR}"

# Update all packages to latest versions (security patches)
RUN set -euo pipefail && \
    echo "Updating all packages to latest versions..." && \
    microdnf update -y && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# Create schemaregistry user and group (non-root execution)
RUN set -euo pipefail && \
    microdnf install -y --nodocs shadow-utils && \
    groupadd -r schemaregistry --gid=999 && \
    useradd -m -d /opt/axonops-schema-registry -r -g schemaregistry -G root --uid=999 schemaregistry && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# Install minimal runtime dependencies
# tar + gzip: required to extract the tarball
# curl-minimal: pre-installed in UBI9-minimal, used by healthcheck
RUN set -euo pipefail && \
    microdnf install -y --nodocs \
        tar \
        gzip \
        hostname \
        procps-ng \
    && microdnf clean all \
    && rm -rf /var/cache/yum /var/cache/dnf

# Download and install axonops-schema-registry with SHA256 verification
# Uses TARGETARCH (set by docker buildx) to select the correct architecture binary
RUN set -euo pipefail && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        SR_ARCH="amd64"; \
    elif [ "${TARGETARCH}" = "arm64" ]; then \
        SR_ARCH="arm64"; \
    else \
        echo "ERROR: Unsupported architecture: ${TARGETARCH}" && exit 1; \
    fi && \
    SR_TARBALL="axonops-schema-registry-${SR_VERSION}-linux-${SR_ARCH}.tar.gz" && \
    SR_URL="https://github.com/axonops/axonops-schema-registry/releases/download/v${SR_VERSION}" && \
    echo "Downloading axonops-schema-registry ${SR_VERSION} for ${SR_ARCH}..." && \
    curl -sL -o "/tmp/${SR_TARBALL}" "${SR_URL}/${SR_TARBALL}" && \
    echo "Downloading SHA256SUMS for verification..." && \
    curl -sL -o /tmp/SHA256SUMS "${SR_URL}/SHA256SUMS" && \
    echo "Verifying checksum..." && \
    cd /tmp && grep "${SR_TARBALL}" SHA256SUMS | sha256sum -c - && \
    echo "Extracting to /opt/axonops-schema-registry..." && \
    mkdir -p /opt/axonops-schema-registry/bin && \
    tar -xzf "/tmp/${SR_TARBALL}" -C /opt/axonops-schema-registry/bin --strip-components=1 && \
    chmod +x /opt/axonops-schema-registry/bin/schema-registry && \
    ln -sf /opt/axonops-schema-registry/bin/schema-registry /usr/local/bin/axonops-schema-registry && \
    rm -f "/tmp/${SR_TARBALL}" /tmp/SHA256SUMS && \
    echo "axonops-schema-registry ${SR_VERSION} installed successfully"

# Create configuration and data directories
RUN set -euo pipefail && \
    mkdir -p /etc/axonops-schema-registry \
             /var/lib/axonops-schema-registry \
             /var/log/axonops-schema-registry \
             /etc/axonops \
             /licenses && \
    chown -R schemaregistry:root \
        /opt/axonops-schema-registry \
        /etc/axonops-schema-registry \
        /var/lib/axonops-schema-registry \
        /var/log/axonops-schema-registry \
        /etc/axonops && \
    chmod 775 /var/lib/axonops-schema-registry /var/log/axonops-schema-registry

# Copy default configuration
COPY --chown=schemaregistry:root config/config.yaml /etc/axonops-schema-registry/config.yaml

# Generate comprehensive build information for runtime startup banner
# Values are quoted for safe sourcing in bash
RUN set -euo pipefail && \
    echo "CONTAINER_VERSION=\"${VERSION}\"" > /etc/axonops/build-info.txt && \
    echo "CONTAINER_IMAGE=\"${IMAGE_FULL_NAME}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_REVISION=\"${VCS_REF}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_GIT_TAG=\"${GIT_TAG}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_BUILD_DATE=\"${BUILD_DATE}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_BUILT_BY=\"${GITHUB_ACTOR}\"" >> /etc/axonops/build-info.txt && \
    echo "IS_PRODUCTION_RELEASE=\"${IS_PRODUCTION_RELEASE}\"" >> /etc/axonops/build-info.txt && \
    echo "SR_VERSION=\"${SR_VERSION}\"" >> /etc/axonops/build-info.txt && \
    echo "BUILD_NUMBER=\"${BUILD_NUMBER}\"" >> /etc/axonops/build-info.txt && \
    echo "UBI9_BASE_DIGEST=\"${UBI9_MINIMAL_DIGEST}\"" >> /etc/axonops/build-info.txt && \
    echo "SR_BINARY_VERSION=\"$(axonops-schema-registry --version 2>&1 || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "OS_VERSION=\"$(grep PRETTY_NAME /etc/os-release 2>/dev/null | sed 's/.*="\(.*\)"/\1/' || echo 'unknown') (UBI - Universal Base Image, freely redistributable)\"" >> /etc/axonops/build-info.txt && \
    echo "PLATFORM=\"$(uname -m || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    chown -R schemaregistry:root /etc/axonops

# Copy entrypoint and healthcheck scripts
COPY scripts/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh && \
    ln -sf /usr/local/bin/docker-entrypoint.sh /docker-entrypoint.sh

# Tini init system (minimal init for containers - handles signals and prevents zombies)
# Uses TARGETARCH for architecture detection (set by docker buildx)
RUN set -euo pipefail && \
    TINI_VERSION=v0.19.0 && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        TINI_ARCH="amd64"; \
        TINI_SHA256="93dcc18adc78c65a028a84799ecf8ad40c936fdfc5f2a57b1acda5a8117fa82c"; \
    elif [ "${TARGETARCH}" = "arm64" ]; then \
        TINI_ARCH="arm64"; \
        TINI_SHA256="07952557df20bfd2a95f9bef198b445e006171969499a1d361bd9e6f8e5e0e81"; \
    else \
        echo "ERROR: Unsupported architecture: ${TARGETARCH}" && exit 1; \
    fi && \
    curl -sL -o /tini "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TINI_ARCH}" && \
    echo "${TINI_SHA256}  /tini" | sha256sum -c - && \
    chmod +x /tini

# Set user to run as (non-root)
USER schemaregistry

# Expose data volume
VOLUME ["/var/lib/axonops-schema-registry", "/var/log/axonops-schema-registry"]

# Schema Registry API port
EXPOSE 8081

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh readiness

ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["axonops-schema-registry", "--config", "/etc/axonops-schema-registry/config.yaml"]
