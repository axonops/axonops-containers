# AxonOps Strimzi Kafka

[English](README.md) | **Français** | [Español](README.es.md) | [Galego](README.gl.md)

Ce dépôt fournit des images de conteneurs Strimzi Kafka personnalisées, intégrant les composants de supervision et d'observabilité AxonOps.

## Vue d'ensemble

L'intégration AxonOps pour Strimzi permet de construire des clusters Kafka fonctionnant sur Kubernetes via l'[opérateur Strimzi](https://strimzi.io/), qui remontent automatiquement métriques et logs à AxonOps. Cela s'obtient en étendant les images Strimzi Kafka standard avec les composants de l'agent AxonOps.

## Fonctionnalités

- **Prise en charge de KRaft** : construit sur le mode KRaft de Strimzi (Kafka sans ZooKeeper)
- **Supervision AxonOps** : collecte automatique des métriques et envoi des logs
- **Configuration souple** : configuration par ConfigMap ou par variables d'environnement
- **Rack awareness** : prise en charge du rack awareness fondé sur la topologie Kubernetes
- **Analyse de sécurité** : analyse Trivy intégrée au CI/CD

## Prérequis

- Un cluster Kubernetes (testé avec k3s, mais toute distribution Kubernetes devrait convenir)
- Helm 3.x
- kubectl configuré pour accéder à votre cluster
- Un compte AxonOps avec une clé d'API

## Démarrage rapide

### 1. Installer l'opérateur Strimzi

```bash
helm repo add strimzi https://strimzi.io/charts/
helm install my-strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --version 0.46.0 \
  --set watchAnyNamespace=true
```

### 2. Créer le namespace Kafka

```bash
kubectl create namespace kafka
```

### 3. Déployer le cluster Kafka

Choisissez l'une des méthodes de configuration ci-dessous selon vos besoins.

#### Option A : déploiement cloud (multi-nœuds)

Pour les déploiements cloud de production, avec des pools de controllers et de brokers distincts.

Tous les manifestes nécessaires se trouvent dans le répertoire [`examples/strimzi/cloud/`](../examples/strimzi/cloud/) :

- `kafka-cluster.yaml` : configuration principale du cluster Kafka
- `kafka-node-pool-controller.yaml` : pool de nœuds controller
- `kafka-node-pool-brokers.yaml` : pool de nœuds broker
- `kafka-logging-cm.yaml` : configuration des logs
- `axonops-config-secret.yaml` : identifiants AxonOps

**Renseignez les valeurs suivantes** :

- `YOUR_AXONOPS_HOST` : le nom d'hôte de votre serveur AxonOps (par exemple `agents.axonops.com`)
- `YOUR_AXONOPS_API_KEY` : la clé d'API de votre organisation AxonOps
- `YOUR_CLUSTER_NAME` : un nom unique pour ce cluster Kafka
- `YOUR_ORG_NAME` : le nom de votre organisation AxonOps

Puis appliquez :

```bash
kubectl apply -f ../examples/strimzi/cloud/ -n kafka
kubectl get pod -n kafka --watch
```

#### Option B : nœud unique (développement / test)

Pour le développement ou les tests, vous pouvez déployer un cluster Kafka à un seul nœud combinant les rôles controller et broker.

Voir le répertoire [`examples/strimzi/cloud/`](../examples/strimzi/cloud/) :

- `kafka-single-node.yaml` : cluster Kafka à nœud unique
- `axonops-agent-config.yaml` : configuration de l'agent AxonOps
- `axonops-kafka-logging.yaml` : configuration des logs
- `axonops-kafka-nodepool.yaml` : configuration du pool de nœuds

**Renseignez les valeurs** puis appliquez :

```bash
kubectl apply -f ../examples/strimzi/cloud/ -n kafka
kubectl get pod -n kafka --watch
```

#### Option C : stockage sur disque local

Pour les déploiements utilisant des volumes persistants locaux.

Tous les manifestes nécessaires se trouvent dans le répertoire [`examples/strimzi/local-disk/`](../examples/strimzi/local-disk/).

```bash
kubectl apply -f ../examples/strimzi/local-disk/ -n kafka
kubectl get pod -n kafka --watch
```

#### Option D : cluster Kafka Connect

Déployez un cluster Kafka Connect pour faire circuler des données entre Kafka et d'autres systèmes.

**Prérequis** : disposer d'un cluster Kafka en fonctionnement (déployé avec l'une des options ci-dessus).

**Renseignez les valeurs suivantes** dans [`examples/strimzi/cloud/kafka-connect.yaml`](../examples/strimzi/cloud/kafka-connect.yaml) :

- `YOUR_AXONOPS_HOST` : le nom d'hôte de votre serveur AxonOps (par exemple `agents.axonops.com`)
- `YOUR_AXONOPS_API_KEY` : la clé d'API de votre organisation AxonOps
- `YOUR_CLUSTER_NAME` : un nom unique pour ce cluster Kafka Connect
- `YOUR_ORG_NAME` : le nom de votre organisation AxonOps
- `ghcr.io/axonops/strimzi/kafka:latest` : à remplacer par votre image Kafka AxonOps précise
- `my-cluster-kafka-bootstrap:9092` : à remplacer par l'adresse réelle de votre serveur bootstrap Kafka

Puis appliquez :

```bash
kubectl apply -f ../examples/strimzi/cloud/kafka-connect.yaml -n kafka
kubectl get pod -n kafka --watch
```

**Note** : la prise en charge de Kafka Connect est actuellement en bêta. Les workers Connect remontent leurs métriques à AxonOps sous le type de nœud `connect`.

## Détails de configuration

### Variables d'environnement obligatoires

Lorsque la configuration se fait par variables d'environnement, les variables suivantes doivent être définies :

| Variable | Description | Exemple |
|----------|-------------|---------|
| `KAFKA_NODE_TYPE` | Rôle du nœud Kafka | `kraft-controller` ou `kraft-broker` |
| `AXON_AGENT_SERVER_HOST` | Nom d'hôte du serveur AxonOps | `agents.axonops.com` |
| `AXON_AGENT_KEY` | Clé d'API AxonOps | Votre clé d'API depuis le dashboard AxonOps |
| `AGENT_CLUSTER_NAME` | Identifiant unique du cluster | `my-kafka-prod` |
| `AXON_AGENT_ORG` | Nom de l'organisation AxonOps | Le nom de votre organisation |

### Variables d'environnement optionnelles

| Variable | Description | Défaut |
|----------|-------------|---------|
| `KAFKA_CLIENT_BROKERS` | Adresses des brokers (pour les brokers) | `0.0.0.0:9092` |

### Configuration par ConfigMap

L'approche ConfigMap permet de fournir un fichier de configuration `axon-agent.yml` complet. C'est utile pour :

- une configuration avancée de la collecte de métriques
- des réglages de logs personnalisés
- des déploiements multi-datacenters
- un contrôle fin du comportement de l'agent

Voir [`examples/strimzi/cloud/`](../examples/strimzi/cloud/) pour la structure complète.

## Rack awareness

Le rack awareness de Kafka s'appuie sur les labels des nœuds Kubernetes. Il aide à répartir les réplicas entre les zones de disponibilité.

### Labelliser vos nœuds

```bash
kubectl label node <node-name> topology.kubernetes.io/zone=<zone-name>
```

Exemple :

```bash
kubectl label node worker-1 topology.kubernetes.io/zone=us-east-1a
kubectl label node worker-2 topology.kubernetes.io/zone=us-east-1b
kubectl label node worker-3 topology.kubernetes.io/zone=us-east-1c
```

### Configurer dans la CRD Kafka

La configuration du rack awareness est déjà présente dans les manifestes d'exemple :

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    rack:
      topologyKey: topology.kubernetes.io/zone
```

Le label de nœud vaut `topology.kubernetes.io/zone` par défaut, mais peut être remplacé via le paramètre `topologyKey`.

## Construire des images personnalisées

### Build local de développement

Pour construire une image personnalisée en local à des fins de test :

```bash
# For Kafka 3.x versions
docker build \
  --build-arg STRIMZI_VERSION=0.46.0 \
  --build-arg KAFKA_VERSION=3.9.0 \
  --build-arg KAFKA_AGENT_PACKAGE=axon-kafka3-agent \
  --build-arg AXONOPS_REPO_FILE=axonops.repo.dev \
  -t axonkafka:local \
  .

# For Kafka 4.x versions
docker build \
  --build-arg STRIMZI_VERSION=0.49.1 \
  --build-arg KAFKA_VERSION=4.1.0 \
  --build-arg KAFKA_AGENT_PACKAGE=axon-kafka4-agent \
  --build-arg AXONOPS_REPO_FILE=axonops.repo.dev \
  -t axonkafka:local \
  .
```

**Important** : utilisez `axon-kafka3-agent` pour les versions Kafka 3.x et `axon-kafka4-agent` pour les versions Kafka 4.x.

### Pipeline CI/CD

Le dépôt contient un workflow GitHub Actions dans [`.github/workflows/strimzi-build-and-test.yml`](../.github/workflows/strimzi-build-and-test.yml) qui :

1. construit l'image de l'opérateur Strimzi avec les composants AxonOps
2. exécute une analyse de sécurité avec Trivy
3. valide le processus de construction de l'image

Le workflow se déclenche sur :
- les push sur les branches `main`, `development`, `feature/**`, `feat/**`, `fix/**`, `bug/**`
- les pull requests vers `main` ou `development`
- les modifications de fichiers du répertoire `strimzi/`

### Tags pour les builds de production

Pour déclencher un pipeline de build de production, créez un tag au format suivant :

```
<environment>/<strimzi-version>-kafka-<kafka-version>-<build-number>
```

**Exemples :**

```bash
# Development build
git tag dev/0.49.1-kafka-4.1.0-1
git push origin dev/0.49.1-kafka-4.1.0-1

# Beta build
git tag beta/0.49.1-kafka-4.1.0-1
git push origin beta/0.49.1-kafka-4.1.0-1

# Production release
git tag release/0.49.1-kafka-4.1.0-1
git push origin release/0.49.1-kafka-4.1.0-1
```

**Où :**
- `<environment>` : `dev`, `beta` ou `release`
- `<strimzi-version>` : version de l'opérateur Strimzi (par exemple `0.49.1`)
- `<kafka-version>` : version de Kafka (par exemple `4.1.0`)
- `<build-number>` : numéro de build incrémental (par exemple `1`, `2`, `3`)

## Nettoyage

### Supprimer le cluster Kafka

Pour supprimer toutes les ressources Kafka du cluster d'exemple :

```bash
# Delete all Strimzi resources
kubectl delete $(kubectl get strimzi -o name -n kafka) -n kafka

# Delete persistent volume claims
kubectl delete pvc --all -n kafka

# Uninstall Strimzi operator
helm uninstall my-strimzi-kafka-operator

# Clean up local images (if needed)
docker rmi axonkafka:local
```

### Nettoyer les images Kubernetes (exemple k3s)

```bash
k3s crictl rmi ghcr.io/axonops/strimzi/kafka:0.47.0-3.9.0
```

## Dépannage

### Vérifier l'état des pods

```bash
kubectl get pods -n kafka
kubectl describe pod <pod-name> -n kafka
```

### Consulter les logs

```bash
# Kafka broker logs
kubectl logs <broker-pod-name> -n kafka

# AxonOps agent logs
kubectl exec <pod-name> -n kafka -- tail -f /var/log/axonops/axon-agent.log

# Follow all logs from a pod
kubectl logs -f <pod-name> -n kafka
```

### Vérifier la connexion à AxonOps

```bash
# Check if agent is running
kubectl exec <pod-name> -n kafka -- ps aux | grep axon

# Check agent configuration
kubectl exec <pod-name> -n kafka -- cat /etc/axonops/axon-agent.yml
```

### Problèmes courants

**Problème** : les pods restent bloqués en `Pending` ou en `CrashLoopBackOff`
- Vérifiez les ressources disponibles : `kubectl describe pod <pod-name> -n kafka`
- Vérifiez l'état des PVC : `kubectl get pvc -n kafka`

**Problème** : l'agent AxonOps ne remonte pas de métriques
- Vérifiez que la clé d'API est correcte dans la configuration
- Vérifiez la connectivité réseau vers le serveur AxonOps
- Examinez les logs de l'agent à la recherche d'erreurs

## Architecture

Les images personnalisées sont construites ainsi :

1. départ depuis l'image de base officielle Strimzi Kafka (`quay.io/strimzi/kafka`)
2. ajout du dépôt YUM AxonOps
3. installation des paquets de l'agent AxonOps et de l'agent Kafka
4. injection du script wrapper AxonOps dans les scripts de démarrage de Kafka
5. configuration des permissions et des appartenances de groupe

Fichiers clés :

- [`Dockerfile`](Dockerfile) : définition de construction de l'image
- [`files/axonops-wrapper.sh`](files/axonops-wrapper.sh) : wrapper de démarrage pour l'intégration AxonOps
- [`files/axonops.repo.dev`](files/axonops.repo.dev) : configuration du dépôt YUM AxonOps (dev)
- [`files/axonops.repo.release`](files/axonops.repo.release) : configuration du dépôt YUM AxonOps (release)

## Exemples de configuration

### Cluster à nœud unique

**Répertoire** : [`examples/strimzi/cloud/`](../examples/strimzi/cloud/)

- **Topologie** : un nœud unique combinant les rôles controller et broker
- **Réplicas** : 1
- **Stockage** : volume persistant
- **Méthode de configuration** : par ConfigMap
- **Cas d'usage** : développement, tests, démonstrations

### Déploiement cloud (multi-nœuds)

**Répertoire** : [`examples/strimzi/cloud/`](../examples/strimzi/cloud/)

- **Topologie** : pools de controllers et de brokers séparés
- **Controllers** : 3 réplicas
- **Brokers** : 3 réplicas
- **Méthode de configuration** : par ConfigMap, avec configuration complète de l'agent
- **Caractéristiques** :
  - rack awareness activé
  - configuration des logs personnalisée
  - configuration AxonOps distincte pour les controllers et les brokers
- **Cas d'usage** : déploiements cloud de production

### Stockage sur disque local

**Répertoire** : [`examples/strimzi/local-disk/`](../examples/strimzi/local-disk/)

- **Topologie** : pools de controllers et de brokers séparés
- **Stockage** : volumes persistants locaux
- **Caractéristiques** :
  - configuration de la StorageClass
  - mise en place du RBAC
  - provisionnement des volumes
- **Cas d'usage** : déploiements on-premises avec stockage local

### Cluster Kafka Connect

**Fichier** : [`examples/strimzi/cloud/kafka-connect.yaml`](../examples/strimzi/cloud/kafka-connect.yaml)

- **Composant** : workers Kafka Connect
- **Réplicas** : 1 (peut être augmenté selon les besoins)
- **Méthode de configuration** : par ConfigMap
- **Caractéristiques** :
  - prise en charge des ressources Connector activée
  - supervision AxonOps des workers Connect
  - topics de stockage configurables pour les métadonnées Connect
- **Topics de configuration** :
  - stockage de la configuration : `connect-configs`
  - stockage des statuts : `connect-status`
  - stockage des offsets : `connect-offsets`
- **Cas d'usage** : intégration de données, pipelines ETL, circulation de données entre Kafka et des systèmes externes

## Compatibilité des versions

| Composant | Version | Notes |
| --------- | ------- | ----- |
| Strimzi | 1.1.0 (dernière) | La prise en charge des ConfigMaps exige 0.44+, le mode KRaft est obligatoire |
| Kafka | 4.3.0 (dernière) | La version 1.1.0 prend en charge Kafka 4.2.0, 4.2.1, 4.3.0 |
| Kubernetes | 1.24+ | Toute distribution conforme CNCF |
| Agent AxonOps | Dernière | Installé automatiquement depuis le dépôt |

### Historique des versions de Strimzi

| Version Strimzi | Versions de Kafka prises en charge | Date de publication |
| --------------- | ------------------------ | ------------ |
| 1.1.0 | 4.2.0, 4.2.1, 4.3.0 | Juin 2026 |
| 1.0.1 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | Juin 2026 |
| 0.51.0 | 4.1.0, 4.1.1, 4.2.0 | Mars 2026 |
| 0.50.0 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | Février 2025 |
| 0.49.1 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | Décembre 2024 |
| 0.48.0 | 4.0.0, 4.1.0 | Novembre 2024 |
| 0.47.0 | 3.9.0, 3.9.1 | Octobre 2024 |

## Limitations connues et TODO

- **Kafka Connect** : une configuration d'exemple est fournie, mais les tests d'intégration complets sont en cours
- **Mirror Maker** : ni construit ni testé pour l'instant
- **Mode ZooKeeper** : non pris en charge (KRaft uniquement)
- **hostId persistant** : envisager des volumes persistants pour le fichier hostId de l'agent AxonOps

## Support

Pour les problèmes concernant :

- **l'intégration AxonOps** : contactez le support AxonOps
- **l'opérateur Strimzi** : voir la [documentation Strimzi](https://strimzi.io/docs/)
- **ce dépôt** : ouvrez un ticket dans le dépôt

## Ressources complémentaires

- [Documentation Strimzi](https://strimzi.io/docs/)
- [Documentation AxonOps](https://docs.axonops.com/)
- [Mode KRaft de Kafka](https://kafka.apache.org/documentation/#kraft)
- [Labels de nœuds Kubernetes](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
