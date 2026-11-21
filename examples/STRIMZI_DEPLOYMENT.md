# Strimzi Kafka Deployment Guide

**English** | [Français](STRIMZI_DEPLOYMENT.fr.md) | [Español](STRIMZI_DEPLOYMENT.es.md) | [Galego](STRIMZI_DEPLOYMENT.gl.md)

This guide deploys Apache Kafka with the Strimzi operator and the AxonOps Kafka image, which runs the AxonOps agent in every Kafka container.

## Choose an example

| Example | Storage | AxonOps target | Deployment |
| --- | --- | --- | --- |
| [strimzi/cloud/](strimzi/cloud/) | PVCs from a StorageClass | AxonOps Cloud | `envsubst` and `kubectl apply` |
| [strimzi/on-premises/](strimzi/on-premises/) | PVCs from a StorageClass | Self-hosted AxonOps | `envsubst` and `kubectl apply` |
| [strimzi/local-disk/](strimzi/local-disk/) | hostPath PVs pinned to nodes | Self-hosted AxonOps | `strimzi-setup.sh` |

The three share the same resources and variable names:

| Resource | Name |
| --- | --- |
| Kafka | `$STRIMZI_CLUSTER_NAME` (default `my-cluster`) in `$KAFKA_NAMESPACE` (default `kafka`) |
| KafkaNodePools | `controller` and `broker` |
| Agent Secret | `$STRIMZI_CLUSTER_NAME-axonops-agent`, read by every Kafka container |
| Bootstrap Service | `$STRIMZI_CLUSTER_NAME-kafka-bootstrap:9092` (plain), `:9093` (TLS) |

## Install the Strimzi operator

Install it once per Kubernetes cluster. The examples need an operator that watches the Kafka namespace; `watchAnyNamespace=true` covers any namespace.

```bash
export STRIMZI_OPERATOR_NAMESPACE=strimzi
helm upgrade --install strimzi-kafka-operator \
  oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  --version 1.1.0 \
  --namespace "$STRIMZI_OPERATOR_NAMESPACE" --create-namespace \
  --set watchAnyNamespace=true \
  --wait
kubectl get pods -n "$STRIMZI_OPERATOR_NAMESPACE"
```

To limit the operator to one namespace, replace `watchAnyNamespace=true` with `--set "watchNamespaces={$KAFKA_NAMESPACE}"` and create that namespace first.

`strimzi/local-disk/strimzi-setup.sh` runs this step itself when the Strimzi CRDs are missing.

## Deploy

Follow the README of the chosen example. For [strimzi/cloud/](strimzi/cloud/):

```bash
cd examples/strimzi/cloud
source strimzi-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key
kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
kubectl wait kafka/"$STRIMZI_CLUSTER_NAME" -n "$KAFKA_NAMESPACE" \
  --for=condition=Ready --timeout=600s
```

## Version compatibility

`KAFKA_VERSION` must be supported by the operator, and `KAFKA_CONTAINER_IMAGE` must be built for both. AxonOps image tags read `<strimzi>-<kafka>-<agent>-<image>`, so `1.1.0-4.3.0-2.0.32-0.1.28` is Strimzi 1.1.0 with Kafka 4.3.0. Published tags are listed in [VERSIONS.md](../VERSIONS.md).

| Strimzi | Kafka | Kubernetes |
| --- | --- | --- |
| 1.1.0 | 4.2.0, 4.2.1, 4.3.0 | 1.27+ |
| 1.0.1 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | 1.27+ |
| 0.51.0 | 4.1.0, 4.1.1, 4.2.0 | 1.26+ |
| 0.50.0 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | 1.25+ |

The examples use the `kafka.strimzi.io/v1` API, available from Strimzi 0.49. Check the [Strimzi downloads page](https://strimzi.io/downloads/) for the current matrix.

## Related

- [Node selector guide](NODE_SELECTOR_GUIDE.md) for `strimzi/local-disk/`
- [AxonOps Kafka image](../strimzi/README.md)
- [AxonOps deployment guide](AXONOPS_DEPLOYMENT.md)
- [Strimzi documentation](https://strimzi.io/docs/operators/latest/)
