ARG CASSANDRA_VERSION=4.1
ARG K8SSANDRA_BASE_DIGEST=required
ARG K8SSANDRA_API_VERSION=required

FROM ghcr.io/k8ssandra/cass-management-api@${K8SSANDRA_BASE_DIGEST}

# Re-declare ARGs after FROM (Docker ARG scope rule - ARGs before FROM only available in FROM line)
ARG CASSANDRA_VERSION
ARG K8SSANDRA_BASE_DIGEST
ARG K8SSANDRA_API_VERSION
ARG CQLAI_VERSION

RUN echo "AXONOPS_BUILD: Inheriting from k8ssandra/cass-management-api:${CASSANDRA_VERSION}-ubi-v${K8SSANDRA_API_VERSION} (digest: ${K8SSANDRA_BASE_DIGEST})"

# Build arguments for OCI labels
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
ARG GIT_TAG
ARG GITHUB_ACTOR
ARG IS_PRODUCTION_RELEASE=false
ARG IMAGE_FULL_NAME
ARG AXON_AGENT_VERSION=latest
ARG AXON_AGENT_JAVA_VERSION=latest

# Set to false to strip the K8ssandra Management API from the image. Used to
# build the standalone ghcr.io/axonops/cassandra/cassandra image, which is
# Cassandra plus the AxonOps agent and nothing else. Leave true for the
# K8ssandra Operator image.
ARG INCLUDE_MGMT_API=true

# Legacy labels (for backward compatibility)
LABEL maintainer="AxonOps"
LABEL name="AxonOps K8ssandra Apache Cassandra"
LABEL vendor="AxonOps"
LABEL url="https://axonops.com"
LABEL release="${CASSANDRA_VERSION}"
LABEL summary="Apache Cassandra with integrated AxonOps monitoring and management agent, designed for deployment on Kubernetes using K8ssandra Operator."
LABEL description="Docker container combining Apache Cassandra ${CASSANDRA_VERSION}, K8ssandra Management API, AxonOps Agent for monitoring and management, and cqlai modern CQL shell. Optimized for Kubernetes deployments with jemalloc memory optimization."

# OCI standard labels
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.authors="AxonOps"
LABEL org.opencontainers.image.url="https://axonops.com"
LABEL org.opencontainers.image.documentation="https://github.com/axonops/axonops-containers/blob/main/k8ssandra/README.md"
LABEL org.opencontainers.image.source="https://github.com/axonops/axonops-containers"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="AxonOps"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.title="AxonOps K8ssandra Apache Cassandra ${CASSANDRA_VERSION}"
LABEL org.opencontainers.image.description="Apache Cassandra ${CASSANDRA_VERSION} with k8ssandra Management API v${K8SSANDRA_API_VERSION}, AxonOps monitoring agents, cqlai v${CQLAI_VERSION}, and jemalloc memory optimization. Base: k8ssandra/cass-management-api:${CASSANDRA_VERSION}-ubi-v${K8SSANDRA_API_VERSION}@${K8SSANDRA_BASE_DIGEST}. Optimized for Kubernetes with K8ssandra Operator."
LABEL org.opencontainers.image.ref.name="${IMAGE_FULL_NAME}"
LABEL org.opencontainers.image.base.name="docker.io/k8ssandra/cass-management-api:${CASSANDRA_VERSION}-ubi-v${K8SSANDRA_API_VERSION}"
LABEL org.opencontainers.image.base.digest="${K8SSANDRA_BASE_DIGEST}"

# AxonOps-specific labels (com.axonops.* namespace)
LABEL com.axonops.cassandra.version="${CASSANDRA_VERSION}"
LABEL com.axonops.k8ssandra-api.version="${K8SSANDRA_API_VERSION}"
LABEL com.axonops.k8ssandra-api.included="${INCLUDE_MGMT_API}"
LABEL com.axonops.cqlai.version="${CQLAI_VERSION}"
LABEL com.axonops.build.actor="${GITHUB_ACTOR}"

ENV AXON_AGENT_LOG_OUTPUT=std
ARG MAJOR_VERSION=4.1
ARG TARGETARCH

USER root

# Update all packages to latest versions (security patches)
RUN echo "Updating all packages to latest versions..." && \
    microdnf update -y && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

COPY axonops-yum-repo.repo /etc/yum.repos.d/axonops-yum.repo

# Install jemalloc for memory allocation optimization
# Note: EPEL release RPM is GPG-signed and verified automatically by rpm
RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    # Verify jemalloc package will be installed from EPEL (not untrusted repos)
    microdnf install -y jemalloc && \
    # Verify jemalloc binary exists and is from expected location
    test -f /usr/lib64/libjemalloc.so.2 || (echo "ERROR: jemalloc not installed correctly" && exit 1) && \
    ln -sf /usr/lib64/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf && \
    ldconfig && \
    microdnf remove -y epel-release && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# Install AxonOps agents and configure
RUN if [ "$AXON_AGENT_JAVA_VERSION" == "latest" ]; then \
      axon_agent_java_pkg="axon-cassandra4.1-agent"; \
    else \
      axon_agent_java_pkg="axon-cassandra4.1-agent-${AXON_AGENT_JAVA_VERSION}"; \
    fi && \
if [ "$AXON_AGENT_VERSION" == "latest" ]; then \
      axon_agent_pkg="axon-agent"; \
    else \
      axon_agent_pkg="axon-agent-${AXON_AGENT_VERSION}"; \
    fi && \
    groupadd --gid 9988 axonops && \
    useradd --gid 9988 --uid 9988 --shell /bin/bash -c "AxonOps" -G cassandra axonops && \
    usermod -aG axonops cassandra && \
    microdnf -y install ${axon_agent_pkg} ${axon_agent_java_pkg} gettext && \
    chown -R cassandra:cassandra /etc/axonops /var/lib/axonops /var/log/axonops && \
    chmod 755 /usr/share/axonops/axon-agent && \
    rm -f /etc/axonops/axon-agent.yml && \
    touch /var/run/utmp && \
    mkdir -p /var/lib/axonops/cassandra && \
    echo '{"working_dir": "/opt/cassandra","commit_log_dir": "/opt/cassandra/data/commitlog"}' > /var/lib/axonops/cassandra/cassandra_info.json && \
    chown -R cassandra:cassandra /var/lib/axonops/cassandra && \
    microdnf clean all && \
    setcap cap_chown,cap_fowner+eip /usr/share/axonops/axon-agent && \
    rm -rf /var/cache/yum /var/cache/dnf

RUN if [ -z "$CQLAI_VERSION" ]; then \
      echo "ERROR: CQLAI_VERSION build arg is required"; \
      exit 1; \
    fi && \
    echo "Installing cqlai version: $CQLAI_VERSION" && \
    RPM_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "aarch64") && \
    CQLAI_RPM="cqlai-${CQLAI_VERSION}-1.${RPM_ARCH}.rpm" && \
    CQLAI_URL="https://github.com/axonops/cqlai/releases/download/v${CQLAI_VERSION}" && \
    # Download checksums file and RPM
    curl -sL -o SHA256SUMS.txt "${CQLAI_URL}/SHA256SUMS.txt" && \
    curl -sL -o "${CQLAI_RPM}" "${CQLAI_URL}/${CQLAI_RPM}" && \
    # Verify checksum
    grep "${CQLAI_RPM}" SHA256SUMS.txt | sha256sum -c - && \
    # Install RPM
    rpm -i "${CQLAI_RPM}" && \
    # Cleanup
    rm -f "${CQLAI_RPM}" SHA256SUMS.txt && \
    rm -rf /var/tmp/rpm-* /var/cache/yum /var/cache/dnf

# Strip the K8ssandra Management API when building the standalone image.
#
# MAAC_PATH and CDC_AGENT_PATH are inherited from the base image and cannot be
# unset conditionally in a Dockerfile, so they keep pointing at the removed
# directories. Nothing reads them once the API is gone: the entrypoint and the
# healthcheck both branch on whether the server jar actually exists.
#
# Note: this removes the files from the running container, but the base image
# layers still carry them, so the image download size is unchanged.
RUN if [ "$INCLUDE_MGMT_API" = "false" ]; then \
      echo "AXONOPS_BUILD: removing the K8ssandra Management API and CDC agent" && \
      rm -rf "${MAAC_PATH:-/opt/management-api}" "${CDC_AGENT_PATH:-/opt/cdc_agent}" && \
      test ! -d "${MAAC_PATH:-/opt/management-api}" || (echo "ERROR: Management API still present" >&2 && exit 1) && \
      # The base image bakes the Management API java agent into cassandra-env.sh.
      # Left in place the JVM refuses to start once the jar is gone.
      for env_file in /opt/cassandra/conf/cassandra-env.sh /etc/cassandra/cassandra-env.sh; do \
        if [ -f "$env_file" ]; then \
          sed -i '/javaagent:.*datastax-mgmtapi-agent\.jar/d' "$env_file"; \
        fi; \
      done && \
      if grep -rq 'datastax-mgmtapi-agent\.jar' /opt/cassandra/conf/cassandra-env.sh; then \
        echo "ERROR: Management API java agent still referenced in cassandra-env.sh" >&2; \
        exit 1; \
      fi; \
    else \
      test -f "${MAAC_PATH:-/opt/management-api}/datastax-mgmtapi-server.jar" || \
        (echo "ERROR: Management API missing from the base image" >&2 && exit 1); \
    fi

# Write build information to file for runtime access (after all packages installed)
# Values are quoted for safe sourcing in bash
RUN echo "CONTAINER_VERSION=\"${VERSION}\"" > /etc/axonops/build-info.txt && \
    echo "CONTAINER_IMAGE=\"${IMAGE_FULL_NAME}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_REVISION=\"${VCS_REF}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_GIT_TAG=\"${GIT_TAG}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_BUILD_DATE=\"${BUILD_DATE}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_BUILT_BY=\"${GITHUB_ACTOR}\"" >> /etc/axonops/build-info.txt && \
    echo "IS_PRODUCTION_RELEASE=\"${IS_PRODUCTION_RELEASE}\"" >> /etc/axonops/build-info.txt && \
    echo "CASSANDRA_VERSION=\"${CASSANDRA_VERSION}\"" >> /etc/axonops/build-info.txt && \
    echo "K8SSANDRA_API_VERSION=\"${K8SSANDRA_API_VERSION}\"" >> /etc/axonops/build-info.txt && \
    echo "INCLUDE_MGMT_API=\"${INCLUDE_MGMT_API}\"" >> /etc/axonops/build-info.txt && \
    echo "K8SSANDRA_BASE_DIGEST=\"${K8SSANDRA_BASE_DIGEST}\"" >> /etc/axonops/build-info.txt && \
    echo "JAVA_VERSION=\"$(java -version 2>&1 | head -2 | tail -1 || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "AXON_AGENT_VERSION=\"$(/usr/share/axonops/axon-agent --version 2>&1 | head -1 | awk '{print $NF}' || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "AXON_JAVA_AGENT_VERSION=\"$(rpm -q axon-cassandra4.1-agent 2>/dev/null || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "CQLAI_VERSION=\"$(cqlai --version 2>&1 | head -1 | awk '{print $NF}' || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "JEMALLOC_VERSION=\"$(rpm -q jemalloc 2>/dev/null || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "OS_VERSION=\"$(grep PRETTY_NAME /etc/os-release 2>/dev/null | sed 's/.*="\(.*\)"/\1/' || echo 'unknown') (UBI - Universal Base Image, freely redistributable)\"" >> /etc/axonops/build-info.txt && \
    echo "PLATFORM=\"$(uname -m || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    chown cassandra:cassandra /etc/axonops/build-info.txt || true

# The entrypoint sources /usr/share/axonops/axonops-jvm.options from
# cassandra-env.sh to attach the java agent. The Cassandra 5.0 agent RPM ships
# that file; the 4.1 RPM does not, so write it here. Cassandra 4.1 runs on
# JDK11 and needs none of the JDK17 --add-opens/--add-exports flags the 5.0
# file carries.
RUN printf 'JVM_OPTS="$JVM_OPTS -javaagent:/usr/share/axonops/axon-cassandra%s-agent.jar=/etc/axonops/axon-agent.yml"\n' "${MAJOR_VERSION}" \
      > /usr/share/axonops/axonops-jvm.options && \
    chmod 644 /usr/share/axonops/axonops-jvm.options

COPY axonops-entrypoint.sh /axonops-entrypoint.sh
COPY healthcheck.sh /usr/local/bin/axonops-healthcheck.sh
RUN chmod 755 /axonops-entrypoint.sh /usr/local/bin/axonops-healthcheck.sh

# Health check: Management API liveness endpoint when the API is present,
# native transport status when it is not, plus the AxonOps agent. A dead agent
# is reported but does not fail the check unless HEALTHCHECK_REQUIRE_AGENT is
# set to true.
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD /usr/local/bin/axonops-healthcheck.sh || exit 1

# Switch back to cassandra user (base image default)
USER cassandra

CMD ["/axonops-entrypoint.sh"]
