FROM docker.io/k8ssandra/cass-management-api:5.0.5-ubi
ENV AXON_AGENT_LOG_OUTPUT=std
ENV MAJOR_VERSION=5.0
ENV AGENT_VER=1.0.11.asb4126cass5k8ssandra1-1

USER root
COPY axonops-yum-repo.repo /etc/yum.repos.d/axonops-yum.repo
RUN groupadd --gid 9988 axonops && \
    useradd --gid 9988 --uid 9988 --shell /bin/bash -c "AxonOps" -G cassandra axonops && \
    usermod -aG axonops cassandra && \
    microdnf -y install axon-cassandra5.0-agent-jdk17-${AGENT_VER} axon-agent gettext && \
    chown -R cassandra:cassandra /etc/axonops /var/lib/axonops /var/log/axonops && \
    touch /var/run/utmp && \
    echo ". /usr/share/axonops/axonops-jvm.options" >> /opt/cassandra/conf/cassandra-env.sh

COPY axonops-entrypoint.sh /axonops-entrypoint.sh
RUN chmod 755 /axonops-entrypoint.sh

CMD ["/axonops-entrypoint.sh"]
