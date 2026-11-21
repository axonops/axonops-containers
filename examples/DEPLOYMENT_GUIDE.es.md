# Guía de despliegue

[English](DEPLOYMENT_GUIDE.md) | [Français](DEPLOYMENT_GUIDE.fr.md) | **Español** | [Galego](DEPLOYMENT_GUIDE.gl.md)

Estos ejemplos despliegan en Kubernetes AxonOps y clústeres de Kafka o Cassandra monitorizados por AxonOps. Cada directorio de ejemplo es autónomo: un fichero de configuración, los manifiestos o el script, y un README con los pasos exactos.

## Ejemplos

| Directorio | Despliega | Destino de AxonOps |
| --- | --- | --- |
| [axonops/](axonops/) | AxonOps autoalojado: servidor, dashboard y bases de datos Timeseries y Search | - |
| [strimzi/cloud/](strimzi/cloud/) | Strimzi Kafka sobre volúmenes aprovisionados dinámicamente | AxonOps Cloud |
| [strimzi/on-premises/](strimzi/on-premises/) | Strimzi Kafka sobre volúmenes aprovisionados dinámicamente | AxonOps autoalojado |
| [strimzi/local-disk/](strimzi/local-disk/) | Strimzi Kafka sobre volúmenes hostPath fijados a nodos | AxonOps autoalojado |
| [k8ssandra/](k8ssandra/) | Cassandra con el operador K8ssandra | AxonOps Cloud o autoalojado |

Guías: [AxonOps](AXONOPS_DEPLOYMENT.es.md), [Strimzi](STRIMZI_DEPLOYMENT.es.md), [K8ssandra](K8SSANDRA_DEPLOYMENT.es.md), [node selectors para discos locales](NODE_SELECTOR_GUIDE.es.md).

## Requisitos previos

- Kubernetes 1.27 o posterior y un contexto de `kubectl` con permisos de cluster-admin
- `helm` 3.8 o posterior
- `envsubst`, del paquete `gettext`: `brew install gettext` en macOS, `apt-get install gettext-base` en Debian y Ubuntu, `dnf install gettext` en RHEL
- Una StorageClass por defecto, salvo para `strimzi/local-disk/`

## Cómo funcionan los ejemplos

Todos los ejemplos siguen el mismo patrón:

1. Haga `cd` al directorio del ejemplo y cargue su fichero `.env` con `source`. Cada fichero es una lista de líneas `export`; edítelo o exporte valores propios antes de cargarlo. Los valores ya definidos se conservan y los que se derivan de ellos los siguen.
2. Exporte los secretos en la shell en lugar de escribirlos en el fichero: `AXON_SEARCH_PASSWORD` y `AXON_SERVER_CQL_PASSWORD` para AxonOps, `AXON_AGENT_KEY` para AxonOps Cloud.
3. Aplique los manifiestos con `envsubst < file.yaml | kubectl apply -f -`, o ejecute el script del ejemplo.

Nada está ligado a un namespace fijo. Cada componente tiene una variable:

| Variable | Valor por defecto | Usada por |
| --- | --- | --- |
| `AXONOPS_NAMESPACE` | `axonops` | `axonops/`, y los ejemplos de Kafka y Cassandra para localizar el servidor de AxonOps |
| `KAFKA_NAMESPACE` | `kafka` | `strimzi/*` |
| `STRIMZI_OPERATOR_NAMESPACE` | `strimzi` | Operador Strimzi |
| `K8SSANDRA_NAMESPACE` | `k8ssandra-operator` | `k8ssandra/` |

Los agentes encuentran un servidor autoalojado en `axon-server-agent.$AXONOPS_NAMESPACE.svc.cluster.local:1888`. Los ejemplos que envían datos a él construyen esta dirección a partir de `axonops/axonops-config.env`, así que cargue antes ese fichero en la misma shell.

## Escenarios

### Solo AxonOps

```bash
cd examples/axonops
source axonops-config.env
export AXON_SEARCH_PASSWORD="$(openssl rand -base64 24)"
export AXON_SERVER_CQL_PASSWORD="$(openssl rand -base64 24)"
./axonops-setup.sh
```

### Kafka monitorizado por AxonOps autoalojado

Instale AxonOps como se indica arriba, instale el [operador Strimzi](STRIMZI_DEPLOYMENT.es.md#instalar-el-operador-strimzi) y, desde la misma shell:

```bash
cd ../strimzi/on-premises
source ../../axonops/axonops-config.env
source strimzi-config.env
kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
```

Para volúmenes hostPath en nodos concretos, use en su lugar [strimzi/local-disk/](strimzi/local-disk/) y su `strimzi-setup.sh`.

### Kafka monitorizado por AxonOps Cloud

```bash
cd examples/strimzi/cloud
source strimzi-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key
kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
```

### Cassandra monitorizado por AxonOps Cloud

Instale el [operador K8ssandra](K8SSANDRA_DEPLOYMENT.es.md#instalar-el-operador-k8ssandra) y después:

```bash
cd examples/k8ssandra
source k8ssandra-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key
envsubst < axonops-agent-secret.yaml | kubectl apply -f -
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

Para un servidor autoalojado, consulte el [ejemplo de K8ssandra](k8ssandra/README.md#examples).

## Renderizado para revisión o GitOps

`envsubst` escribe en la salida estándar, así que cualquier comando de aplicación se convierte en un comando de renderizado:

```bash
envsubst < kafka-cluster.yaml > kafka-cluster.rendered.yaml
```

Los scripts aceptan `RENDER_ONLY=true` y escriben en un directorio `generated/`, que git ignora. Los ficheros renderizados pueden contener contraseñas y claves de agente; no los suba al repositorio.

## Soporte

- [Documentación de AxonOps](https://docs.axonops.com)
- [Documentación de Strimzi](https://strimzi.io/docs/operators/latest/)
- [Documentación de K8ssandra](https://docs.k8ssandra.io/)
