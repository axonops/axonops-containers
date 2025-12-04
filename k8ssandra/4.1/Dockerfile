ARG CASSANDRA_VERSION=4.1
FROM docker.io/k8ssandra/cass-management-api:${CASSANDRA_VERSION}-ubi

ENV AXON_AGENT_LOG_OUTPUT=std
ARG MAJOR_VERSION=4.1
ARG TARGETARCH

USER root
COPY axonops-yum-repo.repo /etc/yum.repos.d/axonops-yum.repo
RUN groupadd --gid 9988 axonops && \
    useradd --gid 9988 --uid 9988 --shell /bin/bash -c "AxonOps" -G cassandra axonops && \
    usermod -aG axonops cassandra && \
    microdnf -y install axon-cassandra4.1-agent axon-agent gettext && \
    chown -R cassandra:cassandra /etc/axonops /var/lib/axonops /var/log/axonops && \
    chmod 755 /usr/share/axonops/axon-agent && \
    rm -f /etc/axonops/axon-agent.yml && \
    touch /var/run/utmp

# Install cqlai (latest release)
RUN RPM_ARCH=$([ "$TARGETARCH" = "amd64" ] && echo "x86_64" || echo "aarch64") && \
    CQLAI_VERSION=$(curl -s https://api.github.com/repos/axonops/cqlai/releases/latest | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/') && \
    rpm -i https://github.com/axonops/cqlai/releases/download/v${CQLAI_VERSION}/cqlai-${CQLAI_VERSION}-1.${RPM_ARCH}.rpm

ENV JVM_EXTRA_OPTS="-javaagent:/usr/share/axonops/axon-cassandra${MAJOR_VERSION}-agent.jar=/etc/axonops/axon-agent.yml"
COPY axonops-entrypoint.sh /axonops-entrypoint.sh
RUN chmod 755 /axonops-entrypoint.sh

CMD ["/axonops-entrypoint.sh"]
