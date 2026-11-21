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
helm upgrade --install strimzi-kafka-operator \
  oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  --version 1.1.0 \
  --namespace strimzi --create-namespace \
  --set watchAnyNamespace=true \
  --wait
```

### 2. Déployer un cluster Kafka

Des manifestes prêts à l'emploi se trouvent dans [`examples/strimzi/`](../examples/strimzi/). Chaque répertoire contient un fichier `strimzi-config.env` et un README avec toutes les étapes :

| Exemple | Stockage | Cible AxonOps |
| --- | --- | --- |
| [`cloud/`](../examples/strimzi/cloud/) | PVC issus d'une StorageClass | AxonOps Cloud |
| [`on-premises/`](../examples/strimzi/on-premises/) | PVC issus d'une StorageClass | AxonOps auto-hébergé |
| [`local-disk/`](../examples/strimzi/local-disk/) | Volumes hostPath attachés à des nœuds | AxonOps auto-hébergé |

```bash
cd examples/strimzi/cloud
source strimzi-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key
kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
kubectl get pods -n "$KAFKA_NAMESPACE" --watch
```

`kafka-connect.yaml`, dans les mêmes répertoires, ajoute un cluster Kafka Connect dont les workers remontent à AxonOps sous le type de nœud `connect`. La prise en charge de Kafka Connect est en bêta.

Voir le [guide de déploiement Strimzi](../examples/STRIMZI_DEPLOYMENT.fr.md) pour la compatibilité des versions de l'opérateur et de l'image.

## Détails de configuration

### Variables d'environnement de l'agent

L'image lit les réglages de l'agent dans les variables d'environnement du conteneur Kafka. Les exemples les définissent depuis un Secret avec `valueFrom.secretKeyRef`.

| Variable | Description | Exemple |
|----------|-------------|---------|
| `KAFKA_NODE_TYPE` | Rôle du nœud Kafka | `kraft-controller`, `kraft-broker` ou `connect` |
| `AXON_AGENT_CLUSTER_NAME` | Nom du cluster affiché dans AxonOps | `my-kafka-prod` |
| `AXON_AGENT_ORG` | Nom de l'organisation AxonOps | Le nom de votre organisation |
| `AXON_AGENT_KEY` | Clé d'agent AxonOps | Votre clé depuis la console AxonOps |
| `AXON_AGENT_SERVER_HOST` | Nom d'hôte du serveur AxonOps | `agents.axonops.cloud` |
| `AXON_AGENT_SERVER_PORT` | Port du serveur AxonOps | `443`, ou `1888` pour un serveur auto-hébergé |
| `AXON_AGENT_TLS_MODE` | Mode TLS de l'agent | `TLS` ou `disabled` |

### Fichier de configuration

Pour configurer l'agent avec un fichier `axon-agent.yml` complet, montez-le sur `/mnt/axon-agent.yml`, par exemple depuis un ConfigMap via `template.pod.volumes` et `template.kafkaContainer.volumeMounts` dans le KafkaNodePool. Au démarrage, l'image le lie à `/etc/axonops/axon-agent.yml`.

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
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    rack:
      topologyKey: topology.kubernetes.io/zone
```

Les exemples définissent `topologyKey` à partir de `KAFKA_RACK_TOPOLOGY_KEY` : `topology.kubernetes.io/zone` dans `cloud/`, `kubernetes.io/hostname` dans `on-premises/` et `local-disk/`.

## Construire des images personnalisées

### Build local de développement

Pour construire une image personnalisée en local à des fins de test :

```bash
# For Kafka 3.x versions
docker build \
  --build-arg STRIMZI_VERSION=0.46.1 \
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
kubectl delete $(kubectl get strimzi -o name -n "$KAFKA_NAMESPACE") -n "$KAFKA_NAMESPACE"

# Delete persistent volume claims
kubectl delete pvc --all -n "$KAFKA_NAMESPACE"

# Uninstall Strimzi operator
helm uninstall strimzi-kafka-operator -n strimzi

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
kubectl get pods -n "$KAFKA_NAMESPACE"
kubectl describe pod <pod-name> -n "$KAFKA_NAMESPACE"
```

### Consulter les logs

```bash
# Kafka broker logs
kubectl logs <broker-pod-name> -n "$KAFKA_NAMESPACE"

# AxonOps agent logs
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- tail -f /var/log/axonops/axon-agent.log

# Follow all logs from a pod
kubectl logs -f <pod-name> -n "$KAFKA_NAMESPACE"
```

### Vérifier la connexion à AxonOps

```bash
# Check if agent is running
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- ps aux | grep axon

# Check agent configuration
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- cat /etc/axonops/axon-agent.yml
```

### Problèmes courants

**Problème** : les pods restent bloqués en `Pending` ou en `CrashLoopBackOff`
- Vérifiez les ressources disponibles : `kubectl describe pod <pod-name> -n "$KAFKA_NAMESPACE"`
- Vérifiez l'état des PVC : `kubectl get pvc -n "$KAFKA_NAMESPACE"`

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
  Le wrapper ajoute aussi `-XX:-UseBASE64Intrinsics` à `KAFKA_OPTS` pour atténuer CVE-2026-114938. Il est placé en premier : un `-XX:+UseBASE64Intrinsics` ultérieur dans votre propre `KAFKA_OPTS` le remplace.
- [`files/axonops.repo.dev`](files/axonops.repo.dev) : configuration du dépôt YUM AxonOps (dev)
- [`files/axonops.repo.release`](files/axonops.repo.release) : configuration du dépôt YUM AxonOps (release)

## Exemples de configuration

Les exemples sont décrits dans [`examples/STRIMZI_DEPLOYMENT.fr.md`](../examples/STRIMZI_DEPLOYMENT.fr.md). Tous trois créent un cluster Kafka avec des pools KRaft controller et broker distincts, le rack awareness et l'agent AxonOps dans chaque conteneur.

## Compatibilité des versions

| Composant | Version | Notes |
| --------- | ------- | ----- |
| Strimzi | 1.2.0 (dernière) | La prise en charge des ConfigMaps exige 0.44+, le mode KRaft est obligatoire |
| Kafka | 4.3.1 (dernière) | La version 1.2.0 prend en charge Kafka 4.2.0, 4.2.1, 4.3.0, 4.3.1 |
| Kubernetes | 1.24+ | Toute distribution conforme CNCF |
| Agent AxonOps | Dernière | Installé automatiquement depuis le dépôt |

### Historique des versions de Strimzi

| Version Strimzi | Versions de Kafka prises en charge | Date de publication |
| --------------- | ------------------------ | ------------ |
| 1.2.0 | 4.2.0, 4.2.1, 4.3.0, 4.3.1 | Août 2026 |
| 1.1.0 | 4.2.0, 4.2.1, 4.3.0 | Juin 2026 |
| 1.0.1 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | Juin 2026 |
| 1.0.0 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | Avril 2026 |
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
