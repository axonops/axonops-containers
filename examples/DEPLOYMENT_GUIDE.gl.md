# Guía de despregamento

[English](DEPLOYMENT_GUIDE.md) | [Français](DEPLOYMENT_GUIDE.fr.md) | [Español](DEPLOYMENT_GUIDE.es.md) | **Galego**

Estes exemplos despregan AxonOps, e clústeres de Kafka ou Cassandra monitorizados por AxonOps, sobre Kubernetes. Cada directorio de exemplo é autónomo: un ficheiro de configuración, os manifestos ou o script, e un README cos pasos exactos.

## Exemplos

| Directorio | Desprega | Destino de AxonOps |
| --- | --- | --- |
| [axonops/](axonops/) | AxonOps autoaloxado: servidor, panel e bases de datos Timeseries e Search | - |
| [strimzi/cloud/](strimzi/cloud/) | Strimzi Kafka sobre volumes aprovisionados dinamicamente | AxonOps Cloud |
| [strimzi/on-premises/](strimzi/on-premises/) | Strimzi Kafka sobre volumes aprovisionados dinamicamente | AxonOps autoaloxado |
| [strimzi/local-disk/](strimzi/local-disk/) | Strimzi Kafka sobre volumes hostPath fixados a nodos | AxonOps autoaloxado |
| [k8ssandra/](k8ssandra/) | Cassandra co operador K8ssandra | AxonOps Cloud ou autoaloxado |

Guías: [AxonOps](AXONOPS_DEPLOYMENT.gl.md), [Strimzi](STRIMZI_DEPLOYMENT.gl.md), [K8ssandra](K8SSANDRA_DEPLOYMENT.gl.md), [node selectors para discos locais](NODE_SELECTOR_GUIDE.gl.md).

## Requisitos previos

- Kubernetes 1.27 ou posterior e un contexto de `kubectl` con permisos de cluster-admin
- `helm` 3.8 ou posterior
- `envsubst`, do paquete `gettext`: `brew install gettext` en macOS, `apt-get install gettext-base` en Debian e Ubuntu, `dnf install gettext` en RHEL
- Unha StorageClass por defecto, agás para `strimzi/local-disk/`

## Como funcionan os exemplos

Todos os exemplos seguen o mesmo patrón:

1. Faga `cd` ao directorio do exemplo e `source` do seu ficheiro `.env`. Cada ficheiro é unha lista de liñas `export`; edíteo, ou exporte os valores que queira cambiar antes do `source`. Os valores xa definidos consérvanse e os que derivan deles seguen.
2. Exporte os segredos na shell en vez de escribilos no ficheiro: `AXON_SEARCH_PASSWORD` e `AXON_SERVER_CQL_PASSWORD` para AxonOps, `AXON_AGENT_KEY` para AxonOps Cloud.
3. Aplique os manifestos con `envsubst < file.yaml | kubectl apply -f -`, ou execute o script do exemplo.

Nada depende dun espazo de nomes fixo. Cada compoñente ten unha variable:

| Variable | Valor por defecto | Usada por |
| --- | --- | --- |
| `AXONOPS_NAMESPACE` | `axonops` | `axonops/`, e os exemplos de Kafka e Cassandra para atopar o servidor de AxonOps |
| `KAFKA_NAMESPACE` | `kafka` | `strimzi/*` |
| `STRIMZI_OPERATOR_NAMESPACE` | `strimzi` | Operador Strimzi |
| `K8SSANDRA_NAMESPACE` | `k8ssandra-operator` | `k8ssandra/` |

Os axentes atopan un servidor autoaloxado en `axon-server-agent.$AXONOPS_NAMESPACE.svc.cluster.local:1888`. Os exemplos que reportan a el constrúen este enderezo a partir de `axonops/axonops-config.env`, así que faga primeiro `source` dese ficheiro na mesma shell.

## Escenarios

### Só AxonOps

```bash
cd examples/axonops
source axonops-config.env
export AXON_SEARCH_PASSWORD="$(openssl rand -base64 24)"
export AXON_SERVER_CQL_PASSWORD="$(openssl rand -base64 24)"
./axonops-setup.sh
```

### Kafka monitorizado por AxonOps autoaloxado

Instale AxonOps como se indica arriba, instale o [operador Strimzi](STRIMZI_DEPLOYMENT.gl.md#instalar-o-operador-strimzi) e, dende a mesma shell:

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

Para volumes hostPath en nodos escollidos, use no seu lugar [strimzi/local-disk/](strimzi/local-disk/) e o seu `strimzi-setup.sh`.

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

Instale o [operador K8ssandra](K8SSANDRA_DEPLOYMENT.gl.md#instalar-o-operador-k8ssandra) e despois:

```bash
cd examples/k8ssandra
source k8ssandra-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key
envsubst < axonops-agent-secret.yaml | kubectl apply -f -
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

Para un servidor autoaloxado, consulte o [exemplo de K8ssandra](k8ssandra/README.md#examples).

## Renderizar para revisión ou GitOps

`envsubst` escribe na saída estándar, así que calquera comando de aplicación convértese nun comando de renderizado:

```bash
envsubst < kafka-cluster.yaml > kafka-cluster.rendered.yaml
```

Os scripts aceptan `RENDER_ONLY=true` e escriben nun directorio `generated/`, que git ignora. Os ficheiros renderizados poden conter contrasinais e chaves de axente; non os suba ao repositorio.

## Soporte

- [Documentación de AxonOps](https://docs.axonops.com)
- [Documentación de Strimzi](https://strimzi.io/docs/operators/latest/)
- [Documentación de K8ssandra](https://docs.k8ssandra.io/)
