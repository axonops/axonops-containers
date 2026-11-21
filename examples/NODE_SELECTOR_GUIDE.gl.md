# Guía de node selectors de Strimzi

[English](NODE_SELECTOR_GUIDE.md) | [Français](NODE_SELECTOR_GUIDE.fr.md) | [Español](NODE_SELECTOR_GUIDE.es.md) | **Galego**

Esta guía trata a colocación dos volumes no exemplo [strimzi/local-disk/](strimzi/local-disk/), onde os datos de Kafka están en directorios hostPath de nodos escollidos. Úsea para poñer os brokers en nodos con discos rápidos, manter os controllers fóra de nodos cargados ou repartir as réplicas entre racks. Os exemplos [strimzi/cloud/](strimzi/cloud/) e [strimzi/on-premises/](strimzi/on-premises/) usan volumes aprovisionados dinamicamente e non a precisan.

## Como funciona a colocación

`strimzi-setup.sh` crea un PersistentVolume por réplica, chamado `<cluster>-controller-<n>` ou `<cluster>-broker-<n>`, cada un cunha afinidade de nodo a un só nodo. Cada pool de nodos reclama só os volumes etiquetados para ese pool. Como a StorageClass enlaza no primeiro uso, o planificador coloca cada pod nun nodo que aínda teña un volume libre do seu pool, e o pod queda nese nodo a partir de entón.

O índice do volume `<n>` non é o id de nodo de Kafka. Strimzi numera os pods entre os dous pools, así que `my-cluster-broker-3` pode usar o volume `my-cluster-broker-0`. Planifique os nodos por pool, non por nome de pod.

## Opcións

| Variable | Valor por defecto | Descrición |
| --- | --- | --- |
| `KAFKA_CONTROLLER_NODE_SELECTORS` | baleiro | Volumes dos controllers, `<index>:<node>,...` |
| `KAFKA_BROKER_NODE_SELECTORS` | baleiro | Volumes dos brokers, `<index>:<node>,...` |
| `STRIMZI_NODE_HOSTNAME` | baleiro | Nodo para cada volume sen asignación. Detéctase automaticamente nun clúster dun só nodo. |
| `STRIMZI_CONTROLLER_REPLICAS` / `STRIMZI_BROKER_REPLICAS` | `3` / `3` | Número de volumes por pool |
| `STRIMZI_HOST_BASE_DIR` | `/data/strimzi` | Directorio pai nos nodos |

O índice pódese escribir como `0`, `broker-0`, `controller-0` ou `ctrl-0`. O script detense cando un índice está fóra de rango, un par non ten nodo, un nodo non existe ou un volume non ten nodo.

Os nomes dos nodos deben coincidir exactamente cos de `kubectl get nodes`.

## Distribucións

Todo nun só nodo:

```bash
export STRIMZI_NODE_HOSTNAME=worker-1
./strimzi-setup.sh
```

Un controller e un broker por nodo:

```bash
export KAFKA_CONTROLLER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
./strimzi-setup.sh
```

Brokers en nodos NVMe, controllers en nodos xerais:

```bash
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-1,1:nvme-2,2:nvme-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:general-1,1:general-2,2:general-3"
./strimzi-setup.sh
```

Un broker fixado, o resto nun nodo por defecto:

```bash
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-1"
export STRIMZI_NODE_HOSTNAME=worker-1
./strimzi-setup.sh
```

En produción, manteña os tres controllers en tres nodos distintos: o quórum de KRaft só sobrevive á perda dun nodo se ningún par de controllers o comparte.

## Preparar os nodos

Execute primeiro o script con `RENDER_ONLY=true`. Mostra os directorios que precisa cada nodo:

```bash
source strimzi-config.env
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
RENDER_ONLY=true ./strimzi-setup.sh
```

```text
  # on worker-1
  sudo mkdir -p /data/strimzi/my-cluster/controller-0 /data/strimzi/my-cluster/broker-0
  sudo chown -R 1001:1001 /data/strimzi/my-cluster
```

Execute eses comandos en cada nodo e despois execute o script sen `RENDER_ONLY`. Os manifestos renderizados están en `generated/strimzi-local-disk.yaml`.

## Verificar

```bash
kubectl get pods -n "$KAFKA_NAMESPACE" -o wide
kubectl get pv -l strimzi.io/cluster="$STRIMZI_CLUSTER_NAME" \
  -o custom-columns=PV:.metadata.name,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0],CLAIM:.spec.claimRef.name
```

## Resolución de problemas

| Síntoma | Causa e solución |
| --- | --- |
| Pod `Pending`, `didn't find available persistent volumes to bind` | O pool ten menos volumes ca réplicas, ou os volumes están en nodos que non poden executar o pod (taints, recursos). Comprobe `kubectl get pv`. |
| Pod `ContainerCreating`, `hostPath type check failed` | Falta o directorio nese nodo. Créeo. |
| Kafka sae con `AccessDeniedException` | O directorio non pertence ao UID 1001. Execute o comando `chown`. |
| `Node 'x' not found` dende o script | Erro tipográfico nun selector. Compare con `kubectl get nodes`. |

## Relacionado

- [strimzi/local-disk/README.md](strimzi/local-disk/README.md)
- [Guía de despregamento de Strimzi](STRIMZI_DEPLOYMENT.gl.md)
- [Volumes local e hostPath de Kubernetes](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath)
