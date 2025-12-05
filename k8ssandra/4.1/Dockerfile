ARG CASSANDRA_VERSION=4.1
FROM docker.io/k8ssandra/cass-management-api:${CASSANDRA_VERSION}-ubi

RUN echo "AXONOPS_BUILD: Inheriting from k8ssandra/cass-management-api:${CASSANDRA_VERSION}-ubi"

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
RUN rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    microdnf install -y jemalloc && \
    ln -sf /usr/lib64/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf && \
    ldconfig && \
    microdnf remove -y epel-release && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# Install AxonOps agents and configure
RUN groupadd --gid 9988 axonops && \
    useradd --gid 9988 --uid 9988 --shell /bin/bash -c "AxonOps" -G cassandra axonops && \
    usermod -aG axonops cassandra && \
    microdnf -y install axon-cassandra4.1-agent axon-agent gettext && \
    chown -R cassandra:cassandra /etc/axonops /var/lib/axonops /var/log/axonops && \
    chmod 755 /usr/share/axonops/axon-agent && \
    rm -f /etc/axonops/axon-agent.yml && \
    touch /var/run/utmp && \
    microdnf clean all && \
    rm -rf /var/cache/yum /var/cache/dnf

# Install cqlai (latest release)
RUN RPM_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "aarch64") && \
    CQLAI_VERSION=$(curl -s https://api.github.com/repos/axonops/cqlai/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/') && \
    rpm -i https://github.com/axonops/cqlai/releases/download/v${CQLAI_VERSION}/cqlai-${CQLAI_VERSION}-1.${RPM_ARCH}.rpm && \
    rm -rf /var/tmp/rpm-* /var/cache/yum /var/cache/dnf

ENV JVM_EXTRA_OPTS="-javaagent:/usr/share/axonops/axon-cassandra${MAJOR_VERSION}-agent.jar=/etc/axonops/axon-agent.yml"
COPY axonops-entrypoint.sh /axonops-entrypoint.sh
RUN chmod 755 /axonops-entrypoint.sh

CMD ["/axonops-entrypoint.sh"]
