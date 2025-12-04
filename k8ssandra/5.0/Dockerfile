ARG CASSANDRA_VERSION=5.0
FROM docker.io/k8ssandra/cass-management-api:${CASSANDRA_VERSION}-ubi

ENV AXON_AGENT_LOG_OUTPUT=std
ARG MAJOR_VERSION=5.0
ARG TARGETARCH

USER root
COPY axonops-yum-repo.repo /etc/yum.repos.d/axonops-yum.repo
RUN groupadd --gid 9988 axonops && \
    useradd --gid 9988 --uid 9988 --shell /bin/bash -c "AxonOps" -G cassandra axonops && \
    usermod -aG axonops cassandra && \
    microdnf -y install axon-cassandra5.0-agent-jdk17 axon-agent gettext && \
    chown -R cassandra:cassandra /etc/axonops /var/lib/axonops /var/log/axonops && \
    chmod 755 /usr/share/axonops/axon-agent && \
    rm -f /etc/axonops/axon-agent.yml && \
    touch /var/run/utmp && \
    echo ". /usr/share/axonops/axonops-jvm.options" >> /opt/cassandra/conf/cassandra-env.sh

# Install cqlai (latest release)
RUN RPM_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "aarch64") && \
    CQLAI_VERSION=$(curl -s https://api.github.com/repos/axonops/cqlai/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/') && \
    rpm -i https://github.com/axonops/cqlai/releases/download/v${CQLAI_VERSION}/cqlai-${CQLAI_VERSION}-1.${RPM_ARCH}.rpm

COPY axonops-entrypoint.sh /axonops-entrypoint.sh
RUN chmod 755 /axonops-entrypoint.sh

# Health check using Management API liveness endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/api/v0/probes/liveness || exit 1

# Switch back to cassandra user (base image default)
USER cassandra

CMD ["/axonops-entrypoint.sh"]
