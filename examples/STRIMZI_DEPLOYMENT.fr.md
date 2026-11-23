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

L'image AxonOps doit être construite pour l'opérateur installé et pour `KAFKA_VERSION`. Un tag qui n'a jamais été construit échoue avec `ImagePullBackOff`.

1. Trouvez la version de l'opérateur installé. C'est le tag de l'image du Deployment de l'opérateur, qu'il ait été installé avec Helm ou avec le YAML de Strimzi :

   ```bash
   kubectl get deployments -A --field-selector metadata.name=strimzi-cluster-operator \
     -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.spec.template.spec.containers[0].image}{"\n"}{end}'
   ```

   `quay.io/strimzi/operator:0.50.0` signifie Strimzi 0.50.0.

2. Choisissez une version de Kafka dans la ligne de cet opérateur du tableau ci-dessous. Exportez les deux avant de charger `strimzi-config.env`, qui construit `KAFKA_CONTAINER_IMAGE` à partir d'elles. Si le fichier a déjà été chargé dans ce shell, supprimez d'abord `KAFKA_CONTAINER_IMAGE` avec `unset`, sinon l'ancien tag est conservé :

   ```bash
   export STRIMZI_VERSION=0.50.0 KAFKA_VERSION=4.1.1
   unset KAFKA_CONTAINER_IMAGE
   source strimzi-config.env
   ```

Les tags d'image AxonOps se lisent `<strimzi>-<kafka>` (flottant) ou `<strimzi>-<kafka>-<agent>-<image>` (épinglé) : `1.1.0-4.3.0-2.0.32-0.1.28` correspond donc à Strimzi 1.1.0 avec Kafka 4.3.0, l'agent AxonOps 2.0.32 et le build d'image 0.1.28. Un tag flottant pointe toujours vers le dernier build AxonOps pour cette combinaison, et `<strimzi>-latest` vers la version de Kafka la plus récente pour cet opérateur. Cela convient à une démo ; en production, épinglez l'image par digest SHA256 (`ghcr.io/axonops/strimzi/kafka@sha256:<digest>`) afin que tous les brokers exécutent le même build. La version actuelle est indiquée dans [VERSIONS.md](../VERSIONS.md).

<!-- strimzi-compat-table:start -->
| Opérateur Strimzi | Versions de Kafka | Tags flottants |
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

Le tableau est généré à partir de la matrice de build par `scripts/strimzi-compat-table.sh`. Les exemples utilisent l'API `kafka.strimzi.io/v1`, disponible à partir de Strimzi 0.49. Consultez la [page de téléchargement de Strimzi](https://strimzi.io/downloads/) pour les versions de Kubernetes prises en charge par chaque opérateur.

## Voir aussi

- [Guide des node selectors](NODE_SELECTOR_GUIDE.fr.md) pour `strimzi/local-disk/`
- [Image Kafka AxonOps](../strimzi/README.fr.md)
- [Guide de déploiement AxonOps](AXONOPS_DEPLOYMENT.fr.md)
- [Documentation Strimzi](https://strimzi.io/docs/operators/latest/)
