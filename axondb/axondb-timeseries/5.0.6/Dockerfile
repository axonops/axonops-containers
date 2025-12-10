ARG UBI_MAJOR=9
ARG UBI_BASETAG=latest
ARG CASSANDRA_VERSION=5.0.6
FROM cassandra:${CASSANDRA_VERSION} AS cassandra-base

FROM registry.access.redhat.com/ubi${UBI_MAJOR}/ubi-minimal:${UBI_BASETAG} AS builder

ARG CASSANDRA_VERSION

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
ENV CASSANDRA_HOME=/opt/cassandra

# Update base layer
RUN microdnf install -y --nodocs shadow-utils \
    && groupadd -r cassandra --gid=999 \
    && useradd -m -d "$CASSANDRA_HOME" -r -g cassandra -G root --uid=999 cassandra \
# Install packages needed during install process
    && microdnf install -y tar gzip unzip

WORKDIR /

###
# Copy Cassandra from official image
###
COPY --from=cassandra-base /etc/cassandra /etc/cassandra
COPY --from=cassandra-base ${CASSANDRA_HOME} ${CASSANDRA_HOME}

FROM registry.access.redhat.com/ubi${UBI_MAJOR}/ubi-minimal:${UBI_BASETAG} AS cassandra
ARG TARGETARCH
ARG CASSANDRA_VERSION
ARG CQLAI_VERSION
ENV CASSANDRA_VERSION=${CASSANDRA_VERSION}

LABEL maintainer="AxonOps"
LABEL name="AxonOps version of Apache Cassandra for Time-Series Database for use with AxonOps self-hosting"
LABEL vendor="AxonOps"
LABEL release="${CASSANDRA_VERSION}"
LABEL summary="Apache Cassandra is an open source distributed database management system designed to handle large amounts of data across many commodity servers, providing high availability with no single point of failure. Cassandra offers robust support for clusters spanning multiple datacenters, with asynchronous masterless replication allowing low latency operations for all clients."
LABEL description="Apache Cassandra is an open source distributed database management system designed to handle large amounts of data across many commodity servers, providing high availability with no single point of failure. Cassandra offers robust support for clusters spanning multiple datacenters, with asynchronous masterless replication allowing low latency operations for all clients."

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

# Update all packages to latest versions (security patches)
RUN echo "Updating all packages to latest versions..." && \
    microdnf update -y && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

ENV CASSANDRA_PATH=/opt/cassandra
ENV PATH=${CASSANDRA_PATH}/bin:${PATH}
ENV CASSANDRA_HOME=${CASSANDRA_PATH}
ENV CASSANDRA_CONF=${CASSANDRA_PATH}/conf
ENV CASSANDRA_LOG_DIR=/var/log/cassandra
ENV CASSANDRA_DATA_DIR=/var/lib/cassandra
ENV CASSANDRA_FILES_PATH=/opt/cassandra_files

# Update base layer
RUN microdnf install -y --nodocs shadow-utils \
    && groupadd -r cassandra --gid=999 \
    && useradd -m -d "$CASSANDRA_HOME" -r -g cassandra -G root --uid=999 cassandra \
    && rm -rf /var/cache/yum \
# Install packages needed during install process
    && microdnf install -y --nodocs java-17-openjdk-headless tzdata-java python3.11 zlib findutils which hostname iproute procps util-linux glibc-langpack-en wget tar nmap-ncat \
    && microdnf clean all

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

# Install cqlai
RUN if [ -z "$CQLAI_VERSION" ]; then \
      echo "ERROR: CQLAI_VERSION build arg is required"; \
      exit 1; \
    fi && \
    echo "Installing cqlai version: $CQLAI_VERSION" && \
    RPM_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "aarch64") && \
    CQLAI_RPM="cqlai-${CQLAI_VERSION}-1.${RPM_ARCH}.rpm" && \
    CQLAI_URL="https://github.com/axonops/cqlai/releases/download/v${CQLAI_VERSION}" && \
    curl -sL -o SHA256SUMS.txt "${CQLAI_URL}/SHA256SUMS.txt" && \
    curl -sL -o "${CQLAI_RPM}" "${CQLAI_URL}/${CQLAI_RPM}" && \
    grep "${CQLAI_RPM}" SHA256SUMS.txt | sha256sum -c - && \
    rpm -i "${CQLAI_RPM}" && \
    rm -f "${CQLAI_RPM}" SHA256SUMS.txt && \
    rm -rf /var/tmp/rpm-* /var/cache/yum /var/cache/dnf

# Copy trimmed Cassandra installation from builder
COPY --from=builder --chown=cassandra:root /etc/cassandra /etc/cassandra
COPY --from=builder --chown=cassandra:root ${CASSANDRA_PATH} ${CASSANDRA_PATH}
COPY --from=builder --chown=cassandra:root ${CASSANDRA_PATH}/LICENSE.txt /licenses/

# Overlay our custom config files to /etc/cassandra (entrypoint.sh expects this path)
COPY --chown=cassandra:root config/cassandra.yaml /etc/cassandra/cassandra.yaml
COPY --chown=cassandra:root config/jvm-server.options /etc/cassandra/jvm-server.options
COPY --chown=cassandra:root config/jvm17-server.options /etc/cassandra/jvm17-server.options

# Create directories
RUN (for dir in ${CASSANDRA_DATA_DIR} \
                ${CASSANDRA_LOG_DIR} ; do \
        mkdir -p $dir && chown -R cassandra:root $dir && chmod 775 $dir ; \
    done ) && \
    # change mode of directories
    chmod a+rwX ${CASSANDRA_PATH} /etc/cassandra

# Copy our healthcheck script
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 755 /usr/local/bin/healthcheck.sh

# Copy system keyspace initialization script
COPY scripts/init-system-keyspaces.sh /usr/local/bin/init-system-keyspaces.sh
RUN chmod 755 /usr/local/bin/init-system-keyspaces.sh

# Generate build info
RUN mkdir -p /etc/axonops && \
    echo "CASSANDRA_VERSION=\"${CASSANDRA_VERSION}\"" > /etc/axonops/build-info.txt && \
    echo "JAVA_VERSION=\"$(java -version 2>&1 | head -2 | tail -1)\"" >> /etc/axonops/build-info.txt && \
    echo "CQLAI_VERSION=\"$(cqlai --version 2>&1 | awk '{print $NF}')\"" >> /etc/axonops/build-info.txt && \
    echo "JEMALLOC_VERSION=\"$(rpm -q jemalloc)\"" >> /etc/axonops/build-info.txt && \
    chown -R cassandra:root /etc/axonops

# AxonDB entrypoint (our working version from Ubuntu build)
COPY scripts/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh && \
  ln -sf /usr/local/bin/docker-entrypoint.sh /docker-entrypoint.sh && \
# fix for the missing mtab in the containerd
  ln -sf /proc/mounts /etc/mtab

ENV TINI_VERSION=v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TARGETARCH} /tini
RUN chmod +x /tini

# Set user to run as
USER cassandra

# Expose CASSANDRA folders
VOLUME ["/var/lib/cassandra", "/var/log/cassandra"]

# CASSANDRA PORTS (INTRA-NODE, TLS INTRA-NODE, JMX, CQL, THRIFT)
EXPOSE 7000 7001 7199 9042 9160

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh readiness

ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["cassandra", "-f"]
