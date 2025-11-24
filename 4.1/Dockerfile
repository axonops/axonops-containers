FROM k8ssandra/cass-management-api:4.1-ubi
ENV AXON_AGENT_LOG_OUTPUT=std
ENV MAJOR_VERSION=4.1
ENV AGENT_VER=1.0.11.asb4126cass5k8ssandra1-1

USER root
COPY axonops-yum-repo.repo /etc/yum.repos.d/axonops-yum.repo
RUN groupadd --gid 9988 axonops && \
    useradd --gid 9988 --uid 9988 --shell /bin/bash -c "AxonOps" -G cassandra axonops && \
    usermod -aG axonops cassandra && \
    microdnf -y install axon-cassandra4.1-agent-${AGENT_VER} axon-agent && \
    chown -R cassandra:cassandra /etc/axonops /var/lib/axonops /var/log/axonops && \
    touch /var/run/utmp

ENV JVM_EXTRA_OPTS="-javaagent:/usr/share/axonops/axon-cassandra${MAJOR_VERSION}-agent.jar=/etc/axonops/axon-agent.yml"
COPY axonops-entrypoint.sh /axonops-entrypoint.sh
RUN chmod 755 /axonops-entrypoint.sh

CMD ["/axonops-entrypoint.sh"]
