ARG STRIMZI_VERSION=0.46.0
ARG KAFKA_VERSION=3.9.0
ARG STRIMZI_BASE_DIGEST=required

FROM quay.io/strimzi/kafka@${STRIMZI_BASE_DIGEST}

# Re-declare ARGs after FROM (Docker ARG scope rule - ARGs before FROM only available in FROM line)
ARG STRIMZI_VERSION
ARG KAFKA_VERSION
ARG STRIMZI_BASE_DIGEST
ARG AXON_AGENT_VERSION=2.0.12

RUN echo "AXONOPS_BUILD: Inheriting from strimzi/kafka:${STRIMZI_VERSION}-kafka-${KAFKA_VERSION} (digest: ${STRIMZI_BASE_DIGEST})"

ARG AGENT_PACKAGE=axon-agent
# Default to kafka3 agent, but can be overridden for Kafka 4.x builds with axon-kafka4-agent
ARG KAFKA_AGENT_PACKAGE=axon-kafka3-agent
ARG AXONOPS_REPO_FILE=axonops.repo.release

USER root

# Add AxonOps repo
COPY files/${AXONOPS_REPO_FILE} /etc/yum.repos.d/axonops-yum.repo
RUN microdnf --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install -y \
        ${KAFKA_AGENT_PACKAGE} \
        ${AGENT_PACKAGE}-${AXON_AGENT_VERSION}-1 \
    && microdnf clean all \
    && rm -f /etc/axonops/axon-agent.yml

# load axonops components
COPY files/axonops-wrapper.sh /opt/kafka/axonops-wrapper.sh
RUN chmod 755 /opt/kafka/axonops-wrapper.sh \
 && ([ -f /opt/kafka/kafka_run.sh ] && sed -i '$i source /opt/kafka/axonops-wrapper.sh' /opt/kafka/kafka_run.sh || true) \
 && ([ -f /opt/kafka/kafka_connect_run.sh ] && sed -i '$i source /opt/kafka/axonops-wrapper.sh' /opt/kafka/kafka_connect_run.sh || true) \
 && ([ -f /opt/kafka/zookeeper_run.sh ] && sed -i '2i source /opt/kafka/axonops-wrapper.sh' /opt/kafka/zookeeper_run.sh || true)

# Add custom Kafka run script
# COPY files/kafka_run.sh.361 /opt/kafka/kafka_run.sh
# RUN chmod 755 /opt/kafka/kafka_run.sh

# # Setup permissions and group membership
RUN usermod -a -G axonops kafka \
    && touch /opt/kafka/server.log /opt/kafka/controller.log /var/run/utmp \
    && mkdir -p /var/log/kafka \
    && chown kafka:axonops /var/log/kafka \
    && chown kafka:axonops /opt/kafka/server.log /opt/kafka/controller.log \
    && chmod g+w /etc/axonops 

USER kafka

