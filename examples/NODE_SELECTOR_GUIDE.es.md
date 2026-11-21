# Guía de node selectors de Strimzi

[English](NODE_SELECTOR_GUIDE.md) | [Français](NODE_SELECTOR_GUIDE.fr.md) | **Español** | [Galego](NODE_SELECTOR_GUIDE.gl.md)

Esta guía cubre la ubicación de volúmenes del ejemplo [strimzi/local-disk/](strimzi/local-disk/), donde los datos de Kafka residen en directorios hostPath de nodos concretos. Úsela para situar los brokers en nodos con discos rápidos, mantener los controllers fuera de nodos cargados o repartir réplicas entre racks. Los ejemplos [strimzi/cloud/](strimzi/cloud/) y [strimzi/on-premises/](strimzi/on-premises/) usan volúmenes aprovisionados dinámicamente y no la necesitan.

## Cómo funciona la ubicación

`strimzi-setup.sh` crea un PersistentVolume por réplica, llamado `<cluster>-controller-<n>` o `<cluster>-broker-<n>`, cada uno con una node affinity hacia un nodo. Cada node pool reclama solo los volúmenes etiquetados para ese pool. Como la StorageClass enlaza en el primer uso, el scheduler coloca cada pod en un nodo que aún tenga un volumen libre de su pool, y el pod permanece en ese nodo a partir de entonces.

El índice de volumen `<n>` no es el id de nodo de Kafka. Strimzi numera los pods a lo largo de ambos pools, así que `my-cluster-broker-3` puede usar el volumen `my-cluster-broker-0`. Planifique los nodos por pool, no por nombre de pod.

## Ajustes

| Variable | Valor por defecto | Descripción |
| --- | --- | --- |
| `KAFKA_CONTROLLER_NODE_SELECTORS` | vacío | Volúmenes de controller, `<index>:<node>,...` |
| `KAFKA_BROKER_NODE_SELECTORS` | vacío | Volúmenes de broker, `<index>:<node>,...` |
| `STRIMZI_NODE_HOSTNAME` | vacío | Nodo para cada volumen sin asignación. Se detecta automáticamente en un clúster de un solo nodo. |
| `STRIMZI_CONTROLLER_REPLICAS` / `STRIMZI_BROKER_REPLICAS` | `3` / `3` | Número de volúmenes por pool |
| `STRIMZI_HOST_BASE_DIR` | `/data/strimzi` | Directorio padre en los nodos |

El índice puede escribirse como `0`, `broker-0`, `controller-0` o `ctrl-0`. El script se detiene cuando un índice está fuera de rango, un par no tiene nodo, un nodo no existe o un volumen no tiene nodo.

Los nombres de nodo deben coincidir exactamente con `kubectl get nodes`.

## Distribuciones

Todo en un nodo:

```bash
export STRIMZI_NODE_HOSTNAME=worker-1
./strimzi-setup.sh
```

Un controller y un broker por nodo:

```bash
export KAFKA_CONTROLLER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
./strimzi-setup.sh
```

Brokers en nodos NVMe, controllers en nodos de uso general:

```bash
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-1,1:nvme-2,2:nvme-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:general-1,1:general-2,2:general-3"
./strimzi-setup.sh
```

Un broker fijado y el resto en un nodo por defecto:

```bash
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-1"
export STRIMZI_NODE_HOSTNAME=worker-1
./strimzi-setup.sh
```

En producción, mantenga los tres controllers en tres nodos distintos: el quórum KRaft sobrevive a la pérdida de un nodo solo si no hay dos controllers en el mismo.

## Preparación de los nodos

Ejecute primero el script con `RENDER_ONLY=true`. Muestra los directorios que necesita cada nodo:

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

Ejecute esos comandos en cada nodo y después ejecute el script sin `RENDER_ONLY`. Los manifiestos renderizados están en `generated/strimzi-local-disk.yaml`.

## Verificación

```bash
kubectl get pods -n "$KAFKA_NAMESPACE" -o wide
kubectl get pv -l strimzi.io/cluster="$STRIMZI_CLUSTER_NAME" \
  -o custom-columns=PV:.metadata.name,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0],CLAIM:.spec.claimRef.name
```

## Resolución de problemas

| Síntoma | Causa y solución |
| --- | --- |
| Pod `Pending`, `didn't find available persistent volumes to bind` | El pool tiene menos volúmenes que réplicas, o los volúmenes están en nodos que no pueden ejecutar el pod (taints, recursos). Compruebe `kubectl get pv`. |
| Pod `ContainerCreating`, `hostPath type check failed` | Falta el directorio en ese nodo. Créelo. |
| Kafka termina con `AccessDeniedException` | El directorio no pertenece al UID 1001. Ejecute el comando `chown`. |
| `Node 'x' not found` desde el script | Error tipográfico en un selector. Compárelo con `kubectl get nodes`. |

## Relacionado

- [strimzi/local-disk/README.md](strimzi/local-disk/README.md)
- [Guía de despliegue de Strimzi](STRIMZI_DEPLOYMENT.es.md)
- [Volúmenes local y hostPath de Kubernetes](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath)
