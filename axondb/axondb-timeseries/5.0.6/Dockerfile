ARG CASSANDRA_VERSION=5.0.6
ARG CASSANDRA_BASE_DIGEST=sha256:83cf8b427d281c6f50d21f7549e74301a69a692b3d422f8aebcc04faeb6ccd78
FROM cassandra@${CASSANDRA_BASE_DIGEST}

# Re-declare ARGs after FROM (Docker ARG scope rule)
ARG CASSANDRA_VERSION
ARG CASSANDRA_BASE_DIGEST

RUN echo "AXONDB_BUILD: Inheriting from cassandra:${CASSANDRA_VERSION} (digest: ${CASSANDRA_BASE_DIGEST})"

# Build arguments for OCI labels and version tracking
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
ARG GIT_TAG
ARG GITHUB_ACTOR
ARG IS_PRODUCTION_RELEASE=false
ARG IMAGE_FULL_NAME
ARG TARGETARCH

# Legacy labels (for backward compatibility)
LABEL maintainer="AxonOps"
LABEL name="AxonDB Time-Series Database"
LABEL vendor="AxonOps"
LABEL url="https://axonops.com"
LABEL release="${CASSANDRA_VERSION}"
LABEL summary="Apache Cassandra ${CASSANDRA_VERSION} optimized for AxonOps self-hosted time-series workloads with Azul OpenJDK 17 and Shenandoah GC."
LABEL description="Optimized Apache Cassandra ${CASSANDRA_VERSION} container for AxonOps self-hosted deployments. Includes Azul OpenJDK 17 with Shenandoah GC, jemalloc memory optimization, and tuned configuration for time-series data. Designed for Kubernetes StatefulSet deployments."

# OCI standard labels
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.authors="AxonOps"
LABEL org.opencontainers.image.url="https://axonops.com"
LABEL org.opencontainers.image.documentation="https://github.com/axonops/axonops-containers/blob/main/axondb/axondb-timeseries/README.md"
LABEL org.opencontainers.image.source="https://github.com/axonops/axonops-containers"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="AxonOps"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.title="AxonDB Time-Series - Apache Cassandra ${CASSANDRA_VERSION}"
LABEL org.opencontainers.image.description="Apache Cassandra ${CASSANDRA_VERSION} optimized for AxonOps self-hosting and time-series workloads with Azul OpenJDK 17 Shenandoah GC, jemalloc, and production-grade configuration. Multi-arch (amd64/arm64) for Kubernetes deployments."
LABEL org.opencontainers.image.ref.name="${IMAGE_FULL_NAME}"
LABEL org.opencontainers.image.base.name="docker.io/cassandra:${CASSANDRA_VERSION}"
LABEL org.opencontainers.image.base.digest="${CASSANDRA_BASE_DIGEST}"

# AxonOps-specific labels (com.axonops.* namespace)
LABEL com.axonops.component="axondb-timeseries"
LABEL com.axonops.cassandra.version="${CASSANDRA_VERSION}"
LABEL com.axonops.build.actor="${GITHUB_ACTOR}"

USER root

# Update all packages to latest versions (security patches)
RUN echo "Updating all packages to latest versions..." && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Remove existing OpenJDK and install Azul OpenJDK 17 with Shenandoah GC support
RUN echo "Removing Eclipse Temurin and installing Azul OpenJDK 17..." && \
    # Install dependencies
    apt-get update && \
    apt-get install -y curl gnupg ca-certificates && \
    # Add Azul repository key and repo
    curl -s https://repos.azul.com/azul-repo.key | gpg --dearmor -o /usr/share/keyrings/azul.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" > /etc/apt/sources.list.d/zulu.list && \
    apt-get update && \
    # Remove old Java (Eclipse Temurin)
    apt-get remove -y '*openjdk*' || true && \
    # Install Azul Zulu OpenJDK 17 (includes Shenandoah GC)
    apt-get install -y zulu17-jdk && \
    # Find actual Java installation path and set alternatives
    JAVA_PATH=$(find /usr/lib/jvm -name "zulu17*" -type d | head -1) && \
    update-alternatives --install /usr/bin/java java ${JAVA_PATH}/bin/java 1 && \
    update-alternatives --set java ${JAVA_PATH}/bin/java && \
    # Verify installation
    java -version && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME for Azul OpenJDK 17 (will be set dynamically by entrypoint if needed)
ENV JAVA_HOME=/usr/lib/jvm/zulu17

# Install jemalloc for memory allocation optimization
RUN echo "Installing jemalloc..." && \
    apt-get update && \
    apt-get install -y libjemalloc2 && \
    # Verify jemalloc binary exists
    test -f /usr/lib/x86_64-linux-gnu/libjemalloc.so.2 || test -f /usr/lib/aarch64-linux-gnu/libjemalloc.so.2 || (echo "ERROR: jemalloc not installed correctly" && exit 1) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# No need for gettext-base - base image's docker-entrypoint.sh handles env var substitution

# Copy customized Cassandra configuration files
# Our custom cassandra.yaml becomes the default config
# Base image's docker-entrypoint.sh will handle environment variable substitution
COPY config/cassandra.yaml /etc/cassandra/cassandra.yaml
COPY config/jvm-server.options /etc/cassandra/jvm-server.options
COPY config/jvm17-server.options /etc/cassandra/jvm17-server.options

# Copy entrypoint and healthcheck scripts
COPY scripts/entrypoint.sh /usr/local/bin/axondb-entrypoint.sh
COPY scripts/healthcheck.sh /usr/local/bin/axondb-healthcheck.sh

RUN chmod 755 /usr/local/bin/axondb-entrypoint.sh /usr/local/bin/axondb-healthcheck.sh

# Write build information to file for runtime access
RUN echo "CONTAINER_VERSION=\"${VERSION}\"" > /etc/axonops/build-info.txt && \
    echo "CONTAINER_IMAGE=\"${IMAGE_FULL_NAME}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_REVISION=\"${VCS_REF}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_GIT_TAG=\"${GIT_TAG}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_BUILD_DATE=\"${BUILD_DATE}\"" >> /etc/axonops/build-info.txt && \
    echo "CONTAINER_BUILT_BY=\"${GITHUB_ACTOR}\"" >> /etc/axonops/build-info.txt && \
    echo "IS_PRODUCTION_RELEASE=\"${IS_PRODUCTION_RELEASE}\"" >> /etc/axonops/build-info.txt && \
    echo "CASSANDRA_VERSION=\"${CASSANDRA_VERSION}\"" >> /etc/axonops/build-info.txt && \
    echo "JAVA_VERSION=\"$(java -version 2>&1 | head -2 | tail -1 || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "JEMALLOC_VERSION=\"$(dpkg -l | grep libjemalloc2 | awk '{print $3}' || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "OS_VERSION=\"$(grep PRETTY_NAME /etc/os-release 2>/dev/null | sed 's/.*="\(.*\)"/\1/' || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    echo "PLATFORM=\"$(uname -m || echo 'unknown')\"" >> /etc/axonops/build-info.txt && \
    mkdir -p /etc/axonops && \
    chown cassandra:cassandra /etc/axonops/build-info.txt || true

# Health check using nodetool status
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD /usr/local/bin/axondb-healthcheck.sh

# Switch back to cassandra user (base image default)
USER cassandra

# Use custom entrypoint
ENTRYPOINT ["/usr/local/bin/axondb-entrypoint.sh"]
CMD ["cassandra", "-f"]
