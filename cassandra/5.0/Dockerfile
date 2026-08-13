# Apache Cassandra 5.0 with the AxonOps agent, built on Red Hat UBI 9 minimal.
#
# Published as ghcr.io/axonops/cassandra/cassandra:{CASSANDRA}-{AXON_AGENT}-{BUILD}
#
# The K8ssandra Management API is NOT part of this image by default. Set
# INSTALL_K8SSANDRA_API=true to produce a variant that also carries the
# Management API, copied from the pinned k8ssandra base image.

# Supply chain security: base image is pinned by digest, not by tag.
# Points to registry.access.redhat.com/ubi9/ubi-minimal:latest
ARG UBI9_MINIMAL_DIGEST=sha256:1bc3c5c15720506a0cf48adfdf8b623dfe704377e007d7bbae8d14876392ca6a

# Cassandra version and the SHA512 of its official tarball. Both are required:
# the checksum comes from cassandra/versions.json, which mirrors the published
# checksums at https://archive.apache.org/dist/cassandra/
ARG CASSANDRA_VERSION=5.0.9
ARG CASSANDRA_SHA512=required

# K8ssandra Management API variant (opt-in). Only consulted when
# INSTALL_K8SSANDRA_API=true.
ARG INSTALL_K8SSANDRA_API=false
ARG K8SSANDRA_BASE_DIGEST=sha256:0000000000000000000000000000000000000000000000000000000000000000
ARG K8SSANDRA_API_VERSION=none

# ---------------------------------------------------------------------------
# Stage 1: download and verify the Apache Cassandra tarball
# ---------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM alpine:latest AS extractor
ARG CASSANDRA_VERSION
ARG CASSANDRA_SHA512

RUN apk add --no-cache wget tar

RUN if [ "$CASSANDRA_SHA512" = "required" ]; then \
      echo "ERROR: CASSANDRA_SHA512 build arg is required" >&2; \
      exit 1; \
    fi && \
    CASSANDRA_TARBALL="apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz" && \
    echo "Downloading Cassandra ${CASSANDRA_VERSION} from Apache mirrors..." && \
    wget -q "https://dlcdn.apache.org/cassandra/${CASSANDRA_VERSION}/${CASSANDRA_TARBALL}" -O "/tmp/${CASSANDRA_TARBALL}" || \
    wget -q "https://archive.apache.org/dist/cassandra/${CASSANDRA_VERSION}/${CASSANDRA_TARBALL}" -O "/tmp/${CASSANDRA_TARBALL}" && \
    echo "${CASSANDRA_SHA512}  /tmp/${CASSANDRA_TARBALL}" | sha512sum -c - && \
    mkdir -p /opt/tmp && \
    tar -xzf "/tmp/${CASSANDRA_TARBALL}" --no-same-owner -C /opt/tmp && \
    mv "/opt/tmp/apache-cassandra-${CASSANDRA_VERSION}" /opt/tmp/cassandra && \
    rm -f "/tmp/${CASSANDRA_TARBALL}"

# ---------------------------------------------------------------------------
# Stage 2: common Cassandra + AxonOps agent image
# ---------------------------------------------------------------------------
FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST} AS cassandra-base

# Re-declare ARGs after FROM (Docker ARG scope rule)
ARG UBI9_MINIMAL_DIGEST
ARG CASSANDRA_VERSION
ARG TARGETARCH
ARG CQLAI_VERSION
ARG AXON_AGENT_VERSION=latest
ARG AXON_AGENT_JAVA_VERSION=latest
ARG INSTALL_K8SSANDRA_API
ARG K8SSANDRA_API_VERSION

# Build metadata (provided by CI, defaulted for local builds)
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown
ARG VERSION=unknown
ARG GIT_TAG=unknown
ARG GITHUB_ACTOR=unknown
ARG IS_PRODUCTION_RELEASE=false
ARG IMAGE_FULL_NAME=unknown

# Legacy labels (for backward compatibility)
LABEL maintainer="AxonOps"
LABEL name="AxonOps Apache Cassandra"
LABEL vendor="AxonOps"
LABEL url="https://axonops.com"
LABEL release="${CASSANDRA_VERSION}"
LABEL summary="Apache Cassandra with the AxonOps monitoring and management agent."
LABEL description="Apache Cassandra ${CASSANDRA_VERSION} built on Red Hat UBI 9 minimal, with the AxonOps agent, the cqlai CQL shell and jemalloc memory optimisation. The K8ssandra Management API is not included unless the image was built with INSTALL_K8SSANDRA_API=true."

# OCI standard labels
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.authors="AxonOps"
LABEL org.opencontainers.image.url="https://axonops.com"
LABEL org.opencontainers.image.documentation="https://github.com/axonops/axonops-containers/blob/main/cassandra/README.md"
LABEL org.opencontainers.image.source="https://github.com/axonops/axonops-containers"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="AxonOps"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.title="AxonOps Apache Cassandra ${CASSANDRA_VERSION}"
LABEL org.opencontainers.image.description="Apache Cassandra ${CASSANDRA_VERSION} with the AxonOps agent, cqlai v${CQLAI_VERSION} and jemalloc. Built from Red Hat UBI 9 minimal (${UBI9_MINIMAL_DIGEST})."
LABEL org.opencontainers.image.ref.name="${IMAGE_FULL_NAME}"
LABEL org.opencontainers.image.base.name="registry.access.redhat.com/ubi9/ubi-minimal:latest"
LABEL org.opencontainers.image.base.digest="${UBI9_MINIMAL_DIGEST}"

# AxonOps-specific labels (com.axonops.* namespace)
LABEL com.axonops.cassandra.version="${CASSANDRA_VERSION}"
LABEL com.axonops.cqlai.version="${CQLAI_VERSION}"
LABEL com.axonops.build.actor="${GITHUB_ACTOR}"

ENV CASSANDRA_PATH=/opt/cassandra
ENV CASSANDRA_HOME=/opt/cassandra
ENV CASSANDRA_CONF=/etc/cassandra
ENV CASSANDRA_LOG_DIR=/var/log/cassandra
ENV CASSANDRA_DATA_DIR=/var/lib/cassandra/data
ENV PATH=/opt/cassandra/bin:${PATH}
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
ENV AXON_AGENT_LOG_OUTPUT=std

# Update all packages to latest versions (security patches)
RUN microdnf update -y && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# Create the cassandra user and group. UID/GID 999 matches the official
# Cassandra images and the axondb-timeseries image in this repository.
RUN microdnf install -y --nodocs shadow-utils && \
    groupadd -r cassandra --gid=999 && \
    useradd -m -d "$CASSANDRA_HOME" -r -g cassandra -G root --uid=999 cassandra && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# Runtime dependencies.
# procps-ng: process tools used by Cassandra's own scripts and by the agent
# python3.11: required by cqlsh
# nmap-ncat / iproute: port checks in the entrypoint
# numactl: NUMA support, auto-detected by Cassandra
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
      gettext \
    && microdnf clean all \
    && rm -rf /var/cache/yum /var/cache/dnf

# Install jemalloc for memory allocation optimisation.
# The EPEL release RPM is GPG-signed and verified automatically by rpm.
RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    microdnf install -y jemalloc && \
    test -f /usr/lib64/libjemalloc.so.2 || (echo "ERROR: jemalloc not installed correctly" >&2 && exit 1) && \
    ln -sf /usr/lib64/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf && \
    ldconfig && \
    microdnf remove -y epel-release && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf /opt/cassandra

COPY --from=extractor /opt/tmp/cassandra /opt/cassandra

# Move the shipped configuration to /etc/cassandra and symlink it back, so the
# conventional $CASSANDRA_HOME/conf path keeps working.
RUN mkdir -p /licenses && \
    cp "$CASSANDRA_HOME/LICENSE.txt" /licenses/LICENSE.txt && \
    mv "$CASSANDRA_HOME/conf" /etc/cassandra && \
    ln -s /etc/cassandra "$CASSANDRA_HOME/conf" && \
    mkdir -p "${CASSANDRA_DATA_DIR}" "${CASSANDRA_LOG_DIR}" && \
    chown -R cassandra:root "$CASSANDRA_HOME" /etc/cassandra /licenses /var/lib/cassandra "${CASSANDRA_LOG_DIR}" && \
    chmod 775 /var/lib/cassandra "${CASSANDRA_DATA_DIR}" "${CASSANDRA_LOG_DIR}" && \
    chmod a+rwX "${CASSANDRA_PATH}" /etc/cassandra && \
    rm -rf /tmp/*

# Install the AxonOps agent and the Cassandra 5.0 Java agent.
COPY axonops-yum-repo.repo /etc/yum.repos.d/axonops-yum.repo
RUN if [ "$AXON_AGENT_JAVA_VERSION" = "latest" ]; then \
      axon_agent_java_pkg="axon-cassandra5.0-agent-jdk17"; \
    else \
      axon_agent_java_pkg="axon-cassandra5.0-agent-jdk17-${AXON_AGENT_JAVA_VERSION}"; \
    fi && \
    if [ "$AXON_AGENT_VERSION" = "latest" ]; then \
      axon_agent_pkg="axon-agent"; \
    else \
      axon_agent_pkg="axon-agent-${AXON_AGENT_VERSION}"; \
    fi && \
    microdnf -y install ${axon_agent_pkg} ${axon_agent_java_pkg} && \
    chown -R cassandra:cassandra /etc/axonops /var/lib/axonops /var/log/axonops && \
    chmod 755 /usr/share/axonops/axon-agent && \
    rm -f /etc/axonops/axon-agent.yml && \
    touch /var/run/utmp && \
    mkdir -p /var/lib/axonops/cassandra && \
    echo '{"working_dir": "/opt/cassandra","commit_log_dir": "/var/lib/cassandra/commitlog"}' > /var/lib/axonops/cassandra/cassandra_info.json && \
    chown -R cassandra:cassandra /var/lib/axonops/cassandra && \
    setcap cap_chown,cap_fowner+eip /usr/share/axonops/axon-agent && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# Install cqlai, verified against the published SHA256SUMS.
RUN if [ -z "$CQLAI_VERSION" ]; then \
      echo "ERROR: CQLAI_VERSION build arg is required" >&2; \
      exit 1; \
    fi && \
    echo "Installing cqlai version: $CQLAI_VERSION" && \
    RPM_ARCH=$(uname -m) && \
    CQLAI_RPM="cqlai-${CQLAI_VERSION}-1.${RPM_ARCH}.rpm" && \
    CQLAI_URL="https://github.com/axonops/cqlai/releases/download/v${CQLAI_VERSION}" && \
    cd /tmp && \
    curl -sL -o SHA256SUMS.txt "${CQLAI_URL}/SHA256SUMS.txt" && \
    curl -sL -o "${CQLAI_RPM}" "${CQLAI_URL}/${CQLAI_RPM}" && \
    grep "${CQLAI_RPM}" SHA256SUMS.txt | sha256sum -c - && \
    rpm -i "${CQLAI_RPM}" && \
    rm -f "${CQLAI_RPM}" SHA256SUMS.txt && \
    rm -rf /var/tmp/rpm-* /var/cache/yum /var/cache/dnf

# Runtime build information, sourced by the entrypoint for the startup banner.
# Values are quoted for safe sourcing in bash.
RUN echo "CONTAINER_VERSION=\"${VERSION}\"" > /etc/axonops/build-info.txt && \
    echo "CONTAINER_IMAGE=\"${IMAGE_FULL_NAME}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_REVISION=\"${VCS_REF}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_GIT_TAG=\"${GIT_TAG}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_BUILD_DATE=\"${BUILD_DATE}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_BUILT_BY=\"${GITHUB_ACTOR}\"" >> /etc/axonops/build-info.txt && \
    echo "IS_PRODUCTION_RELEASE=\"${IS_PRODUCTION_RELEASE}\"" >> /etc/axonops/build-info.txt && \
    echo "CASSANDRA_VERSION=\"${CASSANDRA_VERSION}\"" >> /etc/axonops/build-info.txt && \
    echo "UBI9_BASE_DIGEST=\"${UBI9_MINIMAL_DIGEST}\"" >> /etc/axonops/build-info.txt && \
    echo "INSTALL_K8SSANDRA_API=\"${INSTALL_K8SSANDRA_API}\"" >> /etc/axonops/build-info.txt && \
    echo "K8SSANDRA_API_VERSION=\"${K8SSANDRA_API_VERSION}\"" >> /etc/axonops/build-info.txt && \
    echo "JAVA_VERSION=\"$(java -version 2>&1 | head -2 | tail -1 || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "AXON_AGENT_VERSION=\"$(rpm -q --qf '%{VERSION}' axon-agent 2>/dev/null || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "AXON_JAVA_AGENT_VERSION=\"$(rpm -q axon-cassandra5.0-agent-jdk17 2>/dev/null || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "CQLAI_VERSION=\"$(cqlai --version 2>&1 | head -1 | awk '{print $NF}' || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "JEMALLOC_VERSION=\"$(rpm -q jemalloc 2>/dev/null || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "OS_VERSION=\"$(grep PRETTY_NAME /etc/os-release 2>/dev/null | sed 's/.*=\"\(.*\)\"/\1/' || echo 'unknown') (UBI - Universal Base Image, freely redistributable)\"" >> /etc/axonops/build-info.txt && \
    echo "PLATFORM=\"$(uname -m || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    chown -R cassandra:cassandra /etc/axonops

COPY axonops-entrypoint.sh /axonops-entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /axonops-entrypoint.sh /usr/local/bin/healthcheck.sh

# Tini keeps signal handling and zombie reaping sane for the multi-process
# entrypoint (Cassandra plus the supervised agent).
RUN TINI_VERSION=v0.19.0 && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        TINI_ARCH="amd64"; \
        TINI_SHA256="93dcc18adc78c65a028a84799ecf8ad40c936fdfc5f2a57b1acda5a8117fa82c"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        TINI_ARCH="arm64"; \
        TINI_SHA256="07952557df20bfd2a95f9bef198b445e006171969499a1d361bd9e6f8e5e0e81"; \
    else \
        echo "ERROR: Unsupported architecture: $ARCH" >&2 && exit 1; \
    fi && \
    wget -q -O /tini "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TINI_ARCH}" && \
    echo "${TINI_SHA256}  /tini" | sha256sum -c - && \
    chmod +x /tini

VOLUME ["/var/lib/cassandra", "/var/log/cassandra"]

# Intra-node, TLS intra-node, JMX, CQL
EXPOSE 7000 7001 7199 9042

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh || exit 1

USER cassandra

ENTRYPOINT ["/tini", "-g", "--"]
CMD ["/axonops-entrypoint.sh"]

# ---------------------------------------------------------------------------
# Stage 3: variant selection
#
# BuildKit only builds the stages the final target depends on, so the k8ssandra
# base image is never pulled for a default (INSTALL_K8SSANDRA_API=false) build.
# ---------------------------------------------------------------------------
FROM ghcr.io/k8ssandra/cass-management-api@${K8SSANDRA_BASE_DIGEST} AS mgmtapi-source

FROM cassandra-base AS variant-false

FROM cassandra-base AS variant-true
ARG K8SSANDRA_API_VERSION
USER root
COPY --from=mgmtapi-source /opt/management-api /opt/management-api
RUN chown -R cassandra:cassandra /opt/management-api
LABEL com.axonops.k8ssandra-api.version="${K8SSANDRA_API_VERSION}"
EXPOSE 8080
USER cassandra

FROM variant-${INSTALL_K8SSANDRA_API} AS final
