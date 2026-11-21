# Guide de déploiement Strimzi Kafka

[English](STRIMZI_DEPLOYMENT.md) | **Français** | [Español](STRIMZI_DEPLOYMENT.es.md) | [Galego](STRIMZI_DEPLOYMENT.gl.md)

Ce guide déploie Apache Kafka avec l'opérateur Strimzi et l'image Kafka AxonOps, qui exécute l'agent AxonOps dans chaque conteneur Kafka.

## Choisir un exemple

| Exemple | Stockage | Cible AxonOps | Déploiement |
| --- | --- | --- | --- |
| [strimzi/cloud/](strimzi/cloud/) | PVC issus d'une StorageClass | AxonOps Cloud | `envsubst` et `kubectl apply` |
| [strimzi/on-premises/](strimzi/on-premises/) | PVC issus d'une StorageClass | AxonOps auto-hébergé | `envsubst` et `kubectl apply` |
| [strimzi/local-disk/](strimzi/local-disk/) | PV hostPath attachés à des nœuds | AxonOps auto-hébergé | `strimzi-setup.sh` |

Les trois partagent les mêmes ressources et les mêmes noms de variables :

| Ressource | Nom |
| --- | --- |
| Kafka | `$STRIMZI_CLUSTER_NAME` (`my-cluster` par défaut) dans `$KAFKA_NAMESPACE` (`kafka` par défaut) |
| KafkaNodePools | `controller` et `broker` |
| Secret de l'agent | `$STRIMZI_CLUSTER_NAME-axonops-agent`, lu par chaque conteneur Kafka |
| Service bootstrap | `$STRIMZI_CLUSTER_NAME-kafka-bootstrap:9092` (en clair), `:9093` (TLS) |

## Installer l'opérateur Strimzi

Installez-le une fois par cluster Kubernetes. Les exemples ont besoin d'un opérateur qui surveille le namespace Kafka ; `watchAnyNamespace=true` couvre n'importe quel namespace.

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

Pour limiter l'opérateur à un seul namespace, remplacez `watchAnyNamespace=true` par `--set "watchNamespaces={$KAFKA_NAMESPACE}"` et créez d'abord ce namespace.

`strimzi/local-disk/strimzi-setup.sh` exécute lui-même cette étape lorsque les CRD Strimzi sont absentes.

## Déployer

Suivez le README de l'exemple choisi. Pour [strimzi/cloud/](strimzi/cloud/) :

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

## Compatibilité des versions

`KAFKA_VERSION` doit être pris en charge par l'opérateur, et `KAFKA_CONTAINER_IMAGE` doit être construite pour les deux. Les tags d'image AxonOps se lisent `<strimzi>-<kafka>-<agent>-<image>` : `1.1.0-4.3.0-2.0.32-0.1.28` correspond donc à Strimzi 1.1.0 avec Kafka 4.3.0. Les tags publiés sont listés dans [VERSIONS.md](../VERSIONS.md).

| Strimzi | Kafka | Kubernetes |
| --- | --- | --- |
| 1.1.0 | 4.2.0, 4.2.1, 4.3.0 | 1.27+ |
| 1.0.1 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | 1.27+ |
| 0.51.0 | 4.1.0, 4.1.1, 4.2.0 | 1.26+ |
| 0.50.0 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | 1.25+ |

Les exemples utilisent l'API `kafka.strimzi.io/v1`, disponible à partir de Strimzi 0.49. Consultez la [page de téléchargement de Strimzi](https://strimzi.io/downloads/) pour la matrice à jour.

## Voir aussi

- [Guide des node selectors](NODE_SELECTOR_GUIDE.fr.md) pour `strimzi/local-disk/`
- [Image Kafka AxonOps](../strimzi/README.fr.md)
- [Guide de déploiement AxonOps](AXONOPS_DEPLOYMENT.fr.md)
- [Documentation Strimzi](https://strimzi.io/docs/operators/latest/)
