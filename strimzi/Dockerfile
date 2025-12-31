ARG STRIMZI_VERSION=0.46.0
ARG KAFKA_VERSION=3.9.0

FROM quay.io/strimzi/kafka:${STRIMZI_VERSION}-kafka-${KAFKA_VERSION}

ARG AXON_AGENT_VERSION=2.0.12

ARG AGENT_PACKAGE=axon-agent
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
 && sed -i '$i source /opt/kafka/axonops-wrapper.sh' /opt/kafka/kafka_run.sh \
 && if [ -f /opt/kafka/zookeeper_run.sh ]; then sed -i '2i source /opt/kafka/axonops-wrapper.sh' /opt/kafka/zookeeper_run.sh; fi

# Add custom Kafka run script
# COPY files/kafka_run.sh.361 /opt/kafka/kafka_run.sh
# RUN chmod 755 /opt/kafka/kafka_run.sh

# # Setup permissions and group membership
RUN usermod -a -G axonops kafka \
    && mkdir -p /var/log/kafka \
    && chown kafka:axonops /var/log/kafka \
    && chmod g+w /etc/axonops 

USER kafka

