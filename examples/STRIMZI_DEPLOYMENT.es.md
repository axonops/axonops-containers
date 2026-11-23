# Guía de despliegue de Strimzi Kafka

[English](STRIMZI_DEPLOYMENT.md) | [Français](STRIMZI_DEPLOYMENT.fr.md) | **Español** | [Galego](STRIMZI_DEPLOYMENT.gl.md)

Esta guía despliega Apache Kafka con el operador Strimzi y la imagen de Kafka de AxonOps, que ejecuta el agente de AxonOps en cada contenedor de Kafka.

## Elegir un ejemplo

| Ejemplo | Almacenamiento | Destino de AxonOps | Despliegue |
| --- | --- | --- | --- |
| [strimzi/cloud/](strimzi/cloud/) | PVCs de una StorageClass | AxonOps Cloud | `envsubst` y `kubectl apply` |
| [strimzi/on-premises/](strimzi/on-premises/) | PVCs de una StorageClass | AxonOps autoalojado | `envsubst` y `kubectl apply` |
| [strimzi/local-disk/](strimzi/local-disk/) | PVs hostPath fijados a nodos | AxonOps autoalojado | `strimzi-setup.sh` |

Los tres comparten los mismos recursos y nombres de variables:

| Recurso | Nombre |
| --- | --- |
| Kafka | `$STRIMZI_CLUSTER_NAME` (por defecto `my-cluster`) en `$KAFKA_NAMESPACE` (por defecto `kafka`) |
| KafkaNodePools | `controller` y `broker` |
| Secret del agente | `$STRIMZI_CLUSTER_NAME-axonops-agent`, leído por cada contenedor de Kafka |
| Service de bootstrap | `$STRIMZI_CLUSTER_NAME-kafka-bootstrap:9092` (plano), `:9093` (TLS) |

## Instalar el operador Strimzi

Instálelo una vez por clúster de Kubernetes. Los ejemplos necesitan un operador que vigile el namespace de Kafka; `watchAnyNamespace=true` cubre cualquier namespace.

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

Para limitar el operador a un namespace, sustituya `watchAnyNamespace=true` por `--set "watchNamespaces={$KAFKA_NAMESPACE}"` y cree antes ese namespace.

`strimzi/local-disk/strimzi-setup.sh` ejecuta este paso por sí mismo cuando faltan las CRDs de Strimzi.

## Desplegar

Siga el README del ejemplo elegido. Para [strimzi/cloud/](strimzi/cloud/):

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

## Compatibilidad de versiones

La imagen de AxonOps debe estar construida para el operador instalado y para `KAFKA_VERSION`. Una etiqueta que nunca se construyó falla con `ImagePullBackOff`.

1. Averigüe la versión del operador instalado. Es la etiqueta de la imagen del Deployment del operador, tanto si se instaló con Helm como con el YAML de Strimzi:

   ```bash
   kubectl get deployments -A --field-selector metadata.name=strimzi-cluster-operator \
     -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
   ```

   `quay.io/strimzi/operator:0.50.0` significa Strimzi 0.50.0.

2. Elija una versión de Kafka de la fila de ese operador en la tabla de abajo. Exporte ambas antes de cargar `strimzi-config.env`, que construye `KAFKA_CONTAINER_IMAGE` a partir de ellas. Si ya cargó el archivo en esta shell, elimine antes `KAFKA_CONTAINER_IMAGE` con `unset`, o conservará la etiqueta anterior:

   ```bash
   export STRIMZI_VERSION=0.50.0 KAFKA_VERSION=4.1.1
   unset KAFKA_CONTAINER_IMAGE
   source strimzi-config.env
   ```

Las etiquetas de imagen de AxonOps siguen el formato `<strimzi>-<kafka>` (flotante) o `<strimzi>-<kafka>-<agent>-<image>` (fija), así que `1.1.0-4.3.0-2.0.32-0.1.28` es Strimzi 1.1.0 con Kafka 4.3.0, el agente de AxonOps 2.0.32 y la build de imagen 0.1.28. Una etiqueta flotante siempre apunta a la última build de AxonOps para esa combinación, y `<strimzi>-latest` a la versión de Kafka más reciente para ese operador. Sirve para una demo; en producción, fije la imagen por digest SHA256 (`ghcr.io/axonops/strimzi/kafka@sha256:<digest>`) para que todos los brokers ejecuten la misma build. La versión actual se indica en [VERSIONS.md](../VERSIONS.md).

<!-- strimzi-compat-table:start -->
| Operador Strimzi | Versiones de Kafka | Etiquetas flotantes |
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

La tabla se genera a partir de la matriz de build con `scripts/strimzi-compat-table.sh`. Los ejemplos usan la API `kafka.strimzi.io/v1`, disponible desde Strimzi 0.49. Consulte la [página de descargas de Strimzi](https://strimzi.io/downloads/) para las versiones de Kubernetes que admite cada operador.

## Relacionado

- [Guía de node selectors](NODE_SELECTOR_GUIDE.es.md) para `strimzi/local-disk/`
- [Imagen de Kafka de AxonOps](../strimzi/README.es.md)
- [Guía de despliegue de AxonOps](AXONOPS_DEPLOYMENT.es.md)
- [Documentación de Strimzi](https://strimzi.io/docs/operators/latest/)
