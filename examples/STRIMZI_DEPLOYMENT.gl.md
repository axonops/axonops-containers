# Guía de despregamento de Strimzi Kafka

[English](STRIMZI_DEPLOYMENT.md) | [Français](STRIMZI_DEPLOYMENT.fr.md) | [Español](STRIMZI_DEPLOYMENT.es.md) | **Galego**

Esta guía desprega Apache Kafka co operador Strimzi e a imaxe de Kafka de AxonOps, que executa o axente de AxonOps en cada contedor de Kafka.

## Escoller un exemplo

| Exemplo | Almacenamento | Destino de AxonOps | Despregamento |
| --- | --- | --- | --- |
| [strimzi/cloud/](strimzi/cloud/) | PVC dunha StorageClass | AxonOps Cloud | `envsubst` e `kubectl apply` |
| [strimzi/on-premises/](strimzi/on-premises/) | PVC dunha StorageClass | AxonOps autoaloxado | `envsubst` e `kubectl apply` |
| [strimzi/local-disk/](strimzi/local-disk/) | PV hostPath fixados a nodos | AxonOps autoaloxado | `strimzi-setup.sh` |

Os tres comparten os mesmos recursos e nomes de variables:

| Recurso | Nome |
| --- | --- |
| Kafka | `$STRIMZI_CLUSTER_NAME` (por defecto `my-cluster`) en `$KAFKA_NAMESPACE` (por defecto `kafka`) |
| KafkaNodePools | `controller` e `broker` |
| Secret do axente | `$STRIMZI_CLUSTER_NAME-axonops-agent`, lido por cada contedor de Kafka |
| Service de bootstrap | `$STRIMZI_CLUSTER_NAME-kafka-bootstrap:9092` (plain), `:9093` (TLS) |

## Instalar o operador Strimzi

Instáleo unha vez por clúster de Kubernetes. Os exemplos precisan un operador que vixíe o espazo de nomes de Kafka; `watchAnyNamespace=true` cobre calquera espazo de nomes.

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

Para limitar o operador a un só espazo de nomes, substitúa `watchAnyNamespace=true` por `--set "watchNamespaces={$KAFKA_NAMESPACE}"` e cree antes ese espazo de nomes.

`strimzi/local-disk/strimzi-setup.sh` executa este paso por si mesmo cando faltan os CRD de Strimzi.

## Despregar

Siga o README do exemplo escollido. Para [strimzi/cloud/](strimzi/cloud/):

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

## Compatibilidade de versións

`KAFKA_VERSION` debe estar admitida polo operador, e `KAFKA_CONTAINER_IMAGE` debe estar construída para os dous. As etiquetas das imaxes de AxonOps teñen a forma `<strimzi>-<kafka>-<agent>-<image>`, así que `1.1.0-4.3.0-2.0.32-0.1.28` é Strimzi 1.1.0 con Kafka 4.3.0. O valor por defecto é a etiqueta flotante `<strimzi>-<kafka>`, por exemplo `1.1.0-4.3.0`, que sempre apunta á última build de AxonOps para esa combinación. Vale para unha demo; en produción, fixe a imaxe por digest SHA256 (`ghcr.io/axonops/strimzi/kafka@sha256:<digest>`) para que todos os brokers executen a mesma build. As etiquetas publicadas están listadas en [VERSIONS.md](../VERSIONS.md).

| Strimzi | Kafka | Kubernetes |
| --- | --- | --- |
| 1.1.0 | 4.2.0, 4.2.1, 4.3.0 | 1.27+ |
| 1.0.1 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | 1.27+ |
| 0.51.0 | 4.1.0, 4.1.1, 4.2.0 | 1.26+ |
| 0.50.0 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | 1.25+ |

Os exemplos usan a API `kafka.strimzi.io/v1`, dispoñible dende Strimzi 0.49. Consulte a [páxina de descargas de Strimzi](https://strimzi.io/downloads/) para a matriz actual.

## Relacionado

- [Guía de node selectors](NODE_SELECTOR_GUIDE.gl.md) para `strimzi/local-disk/`
- [Imaxe de Kafka de AxonOps](../strimzi/README.gl.md)
- [Guía de despregamento de AxonOps](AXONOPS_DEPLOYMENT.gl.md)
- [Documentación de Strimzi](https://strimzi.io/docs/operators/latest/)
