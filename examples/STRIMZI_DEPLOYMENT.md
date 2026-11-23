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

The AxonOps image must be built for the installed operator and for `KAFKA_VERSION`. A tag that was never built fails with `ImagePullBackOff`.

1. Find the installed operator version. It is the tag of the operator Deployment image, whether the operator was installed with Helm or with the Strimzi YAML:

   ```bash
   kubectl get deployments -A --field-selector metadata.name=strimzi-cluster-operator \
     -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
   ```

   `quay.io/strimzi/operator:0.50.0` means Strimzi 0.50.0.

2. Pick a Kafka version from that operator's row in the table below. Export both before sourcing `strimzi-config.env`, which builds `KAFKA_CONTAINER_IMAGE` from them. Unset `KAFKA_CONTAINER_IMAGE` first if the file was already sourced in this shell, or it keeps the old tag:

   ```bash
   export STRIMZI_VERSION=0.50.0 KAFKA_VERSION=4.1.1
   unset KAFKA_CONTAINER_IMAGE
   source strimzi-config.env
   ```

AxonOps image tags read `<strimzi>-<kafka>` (floating) or `<strimzi>-<kafka>-<agent>-<image>` (pinned), so `1.1.0-4.3.0-2.0.32-0.1.28` is Strimzi 1.1.0 with Kafka 4.3.0, AxonOps agent 2.0.32 and image build 0.1.28. A floating tag always points to the latest AxonOps build for that pair, and `<strimzi>-latest` to the newest Kafka version for that operator. That suits a demo; in production, pin the image by SHA256 digest (`ghcr.io/axonops/strimzi/kafka@sha256:<digest>`) so every broker runs the same build. The current release is listed in [VERSIONS.md](../VERSIONS.md).

<!-- strimzi-compat-table:start -->
| Strimzi operator | Kafka versions | Floating tags |
| --- | --- | --- |
| 1.2.0 | 4.2.0, 4.2.1, 4.3.0, 4.3.1 | `1.2.0-4.2.0`, `1.2.0-4.2.1`, `1.2.0-4.3.0`, `1.2.0-4.3.1`, `1.2.0-latest` |
| 1.1.0 | 4.2.0, 4.2.1, 4.3.0 | `1.1.0-4.2.0`, `1.1.0-4.2.1`, `1.1.0-4.3.0`, `1.1.0-latest` |
| 1.0.1 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | `1.0.1-4.1.0`, `1.0.1-4.1.1`, `1.0.1-4.1.2`, `1.0.1-4.2.0`, `1.0.1-latest` |
| 1.0.0 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | `1.0.0-4.1.0`, `1.0.0-4.1.1`, `1.0.0-4.1.2`, `1.0.0-4.2.0`, `1.0.0-latest` |
| 0.51.0 | 4.1.0, 4.1.1, 4.2.0 | `0.51.0-4.1.0`, `0.51.0-4.1.1`, `0.51.0-4.2.0`, `0.51.0-latest` |
| 0.50.1 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | `0.50.1-4.0.0`, `0.50.1-4.0.1`, `0.50.1-4.1.0`, `0.50.1-4.1.1`, `0.50.1-latest` |
| 0.50.0 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | `0.50.0-4.0.0`, `0.50.0-4.0.1`, `0.50.0-4.1.0`, `0.50.0-4.1.1`, `0.50.0-latest` |
| 0.49.1 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | `0.49.1-4.0.0`, `0.49.1-4.0.1`, `0.49.1-4.1.0`, `0.49.1-4.1.1`, `0.49.1-latest` |
| 0.49.0 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | `0.49.0-4.0.0`, `0.49.0-4.0.1`, `0.49.0-4.1.0`, `0.49.0-4.1.1`, `0.49.0-latest` |
| 0.48.0 | 4.0.0, 4.1.0 | `0.48.0-4.0.0`, `0.48.0-4.1.0`, `0.48.0-latest` |
| 0.47.0 | 3.9.0, 3.9.1 | `0.47.0-3.9.0`, `0.47.0-3.9.1`, `0.47.0-latest` |
| 0.46.1 | 3.9.0 | `0.46.1-3.9.0`, `0.46.1-latest` |
<!-- strimzi-compat-table:end -->

The table is generated from the build matrix by `scripts/strimzi-compat-table.sh`. The examples use the `kafka.strimzi.io/v1` API, available from Strimzi 0.49. Check the [Strimzi downloads page](https://strimzi.io/downloads/) for the Kubernetes versions each operator supports.

## Related

- [Node selector guide](NODE_SELECTOR_GUIDE.md) for `strimzi/local-disk/`
- [AxonOps Kafka image](../strimzi/README.md)
- [AxonOps deployment guide](AXONOPS_DEPLOYMENT.md)
- [Strimzi documentation](https://strimzi.io/docs/operators/latest/)
