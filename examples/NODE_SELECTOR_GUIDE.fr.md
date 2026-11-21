# Guide des node selectors Strimzi

[English](NODE_SELECTOR_GUIDE.md) | **Français** | [Español](NODE_SELECTOR_GUIDE.es.md) | [Galego](NODE_SELECTOR_GUIDE.gl.md)

Ce guide traite du placement des volumes pour l'exemple [strimzi/local-disk/](strimzi/local-disk/), où les données Kafka résident dans des répertoires hostPath sur des nœuds choisis. Utilisez-le pour placer les brokers sur des nœuds aux disques rapides, tenir les controllers à l'écart des nœuds chargés, ou répartir les réplicas entre racks. Les exemples [strimzi/cloud/](strimzi/cloud/) et [strimzi/on-premises/](strimzi/on-premises/) utilisent des volumes provisionnés dynamiquement et n'en ont pas besoin.

## Fonctionnement du placement

`strimzi-setup.sh` crée un PersistentVolume par réplica, nommé `<cluster>-controller-<n>` ou `<cluster>-broker-<n>`, chacun avec une node affinity vers un nœud. Chaque node pool ne réclame que les volumes étiquetés pour ce pool. Comme la StorageClass lie le volume à la première utilisation, le scheduler place chaque pod sur un nœud qui a encore un volume libre de son pool, et le pod reste ensuite sur ce nœud.

L'index de volume `<n>` n'est pas l'id de nœud Kafka. Strimzi numérote les pods sur l'ensemble des deux pools, donc `my-cluster-broker-3` peut utiliser le volume `my-cluster-broker-0`. Planifiez les nœuds par pool, pas par nom de pod.

## Réglages

| Variable | Défaut | Description |
| --- | --- | --- |
| `KAFKA_CONTROLLER_NODE_SELECTORS` | vide | Volumes des controllers, `<index>:<node>,...` |
| `KAFKA_BROKER_NODE_SELECTORS` | vide | Volumes des brokers, `<index>:<node>,...` |
| `STRIMZI_NODE_HOSTNAME` | vide | Nœud de chaque volume sans correspondance. Détecté automatiquement sur un cluster à un seul nœud. |
| `STRIMZI_CONTROLLER_REPLICAS` / `STRIMZI_BROKER_REPLICAS` | `3` / `3` | Nombre de volumes par pool |
| `STRIMZI_HOST_BASE_DIR` | `/data/strimzi` | Répertoire parent sur les nœuds |

L'index peut s'écrire `0`, `broker-0`, `controller-0` ou `ctrl-0`. Le script s'arrête lorsqu'un index est hors limites, qu'une paire n'a pas de nœud, qu'un nœud n'existe pas ou qu'un volume n'a pas de nœud.

Les noms de nœuds doivent correspondre exactement à `kubectl get nodes`.

## Dispositions

Tout sur un seul nœud :

```bash
export STRIMZI_NODE_HOSTNAME=worker-1
./strimzi-setup.sh
```

Un controller et un broker par nœud :

```bash
export KAFKA_CONTROLLER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
./strimzi-setup.sh
```

Brokers sur des nœuds NVMe, controllers sur des nœuds généralistes :

```bash
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-1,1:nvme-2,2:nvme-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:general-1,1:general-2,2:general-3"
./strimzi-setup.sh
```

Un broker épinglé, les autres sur un nœud par défaut :

```bash
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-1"
export STRIMZI_NODE_HOSTNAME=worker-1
./strimzi-setup.sh
```

En production, gardez les trois controllers sur trois nœuds différents : le quorum KRaft ne survit à la perte d'un nœud que si deux controllers ne le partagent pas.

## Préparer les nœuds

Lancez d'abord le script avec `RENDER_ONLY=true`. Il affiche les répertoires nécessaires sur chaque nœud :

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

Exécutez ces commandes sur chaque nœud, puis relancez le script sans `RENDER_ONLY`. Les manifestes générés se trouvent dans `generated/strimzi-local-disk.yaml`.

## Vérifier

```bash
kubectl get pods -n "$KAFKA_NAMESPACE" -o wide
kubectl get pv -l strimzi.io/cluster="$STRIMZI_CLUSTER_NAME" \
  -o custom-columns=PV:.metadata.name,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0],CLAIM:.spec.claimRef.name
```

## Dépannage

| Symptôme | Cause et correction |
| --- | --- |
| Pod `Pending`, `didn't find available persistent volumes to bind` | Le pool a moins de volumes que de réplicas, ou les volumes sont sur des nœuds qui ne peuvent pas exécuter le pod (taints, ressources). Vérifiez `kubectl get pv`. |
| Pod `ContainerCreating`, `hostPath type check failed` | Le répertoire est absent sur ce nœud. Créez-le. |
| Kafka s'arrête avec `AccessDeniedException` | Le répertoire n'appartient pas à l'UID 1001. Exécutez la commande `chown`. |
| `Node 'x' not found` renvoyé par le script | Faute de frappe dans un selector. Comparez avec `kubectl get nodes`. |

## Voir aussi

- [strimzi/local-disk/README.md](strimzi/local-disk/README.md)
- [Guide de déploiement Strimzi](STRIMZI_DEPLOYMENT.fr.md)
- [Volumes local et hostPath de Kubernetes](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath)
