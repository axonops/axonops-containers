# Guide de déploiement on-premises

[English](DEPLOYMENT_GUIDE.md) | **Français**

Bienvenue dans le guide de déploiement on-premises d'AxonOps et des plateformes de données sur Kubernetes.

## Vue d'ensemble

Ce guide fournit les instructions de déploiement de différentes plateformes de données sur Kubernetes, avec la supervision et la gestion AxonOps en option.

## Navigation rapide

| Composant | Description | Guide |
| --- | --- | --- |
| AxonOps | Plateforme de supervision et de gestion | [AXONOPS_DEPLOYMENT.fr.md](AXONOPS_DEPLOYMENT.fr.md) |
| Strimzi Kafka | Apache Kafka sur Kubernetes | [STRIMZI_DEPLOYMENT.fr.md](STRIMZI_DEPLOYMENT.fr.md) |
| K8ssandra | Apache Cassandra sur Kubernetes | [K8SSANDRA_DEPLOYMENT.fr.md](K8SSANDRA_DEPLOYMENT.fr.md) |

## Manifestes d'exemple

Des manifestes Kubernetes prêts à l'emploi se trouvent dans les répertoires suivants :

| Répertoire | Description |
| --- | --- |
| [axonops/](axonops/) | Serveur AxonOps, dashboard et composants de base de données |
| [strimzi/cloud/](strimzi/cloud/) | Strimzi Kafka de production pour les environnements cloud |
| [strimzi/local-disk/](strimzi/local-disk/) | Strimzi Kafka avec volumes persistants locaux |
| [strimzi/single/](strimzi/single/) | Strimzi Kafka à nœud unique, pour le développement |
| [k8ssandra/](k8ssandra/) | Exemples de clusters Cassandra K8ssandra |

## Prérequis

Tous les déploiements exigent :

1. **Un cluster Kubernetes** (v1.21+)
   - mono-nœud ou multi-nœuds

2. **Des outils en ligne de commande**
   - `kubectl` — la CLI Kubernetes
   - `helm` — le gestionnaire de paquets Helm v3.x ou ultérieur
   - `envsubst` — substitution de variables (fourni par le paquet `gettext`)

3. **L'accès au cluster**
   - un contexte `kubectl` configuré
   - des permissions suffisantes (cluster-admin ou équivalent)

4. **Du stockage** (au choix)
   - un provisionneur de stockage dynamique (recommandé en production)
   - du stockage hostPath (pour les tests mono-nœud)

### Installer envsubst

La commande `envsubst` sert à substituer les variables d'environnement dans les templates YAML.

**macOS :**
```bash
brew install gettext
brew link --force gettext
```

**Ubuntu/Debian :**
```bash
sudo apt-get install gettext-base
```

**RHEL/CentOS :**
```bash
sudo yum install gettext
```

**Vérifier l'installation :**
```bash
envsubst --version
```

---

## Scénarios de déploiement

### Scénario 1 : AxonOps seul

Déployer uniquement la plateforme de supervision, pour superviser des clusters existants :

```bash
cd axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh
```

Voir [AXONOPS_DEPLOYMENT.fr.md](AXONOPS_DEPLOYMENT.fr.md) pour tous les détails.

---

### Scénario 2 : Kafka supervisé par AxonOps (recommandé)

Déployer Kafka avec une supervision complète :

```bash
# Step 1: Deploy AxonOps monitoring platform
cd axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh

# Step 2: Configure Strimzi (edit strimzi-setup.env as needed)
vi strimzi-setup.env

# Step 3: Deploy Kafka with automatic monitoring integration
source axonops-config.env
source strimzi-setup.env
./strimzi-setup.sh
```

Voir [AXONOPS_DEPLOYMENT.fr.md](AXONOPS_DEPLOYMENT.fr.md) et [STRIMZI_DEPLOYMENT.fr.md](STRIMZI_DEPLOYMENT.fr.md).

---

### Scénario 3 : Kafka autonome (exemples cloud)

Déployer Kafka à partir des manifestes d'exemple cloud :

```bash
cd strimzi/cloud/

# Configure and source environment variables
vi strimzi-config.env
source strimzi-config.env

# Create the AxonOps secret
kubectl create secret generic axonops-agent -n kafka \
  --from-literal=AXON_AGENT_CLUSTER_NAME=$AXON_AGENT_CLUSTER_NAME \
  --from-literal=AXON_AGENT_ORG=$AXON_AGENT_ORG \
  --from-literal=AXON_AGENT_SERVER_HOST=$AXON_AGENT_SERVER_HOST \
  --from-literal=AXON_AGENT_KEY=$AXON_AGENT_KEY

# Apply manifests
kubectl apply -f kafka-logging-cm.yaml
kubectl apply -f kafka-node-pool-controller.yaml
kubectl apply -f kafka-node-pool-brokers.yaml
kubectl apply -f kafka-cluster.yaml
```

Voir [strimzi/cloud/README.md](strimzi/cloud/README.md) pour tous les détails.

---

### Scénario 4 : Cassandra avec K8ssandra

Déployer Apache Cassandra avec K8ssandra :

```bash
cd k8ssandra/

# Configure environment variables
export $(grep -v '^#' k8ssandra-config.env | xargs)

# Apply the cluster manifest
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

Voir [K8SSANDRA_DEPLOYMENT.fr.md](K8SSANDRA_DEPLOYMENT.fr.md) pour tous les détails.

---

### Scénario 5 : stack complète (AxonOps + Kafka + Cassandra)

Déployer l'ensemble de la plateforme de supervision et de données :

```bash
# Step 1: Deploy AxonOps
cd axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh
source axonops-config.env

# Step 2: Deploy Kafka
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh

# Step 3: Deploy Cassandra
cd ../k8ssandra/
export $(grep -v '^#' k8ssandra-config.env | xargs)
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

---

## Utiliser envsubst avec les manifestes

De nombreux manifestes d'exemple contiennent des placeholders de variables d'environnement (`${VAR_NAME}`). Utilisez `envsubst` pour y substituer les valeurs avant application :

### Usage de base

```bash
# Source configuration file
export $(grep -v '^#' config.env | xargs)

# Apply manifest with variable substitution
envsubst < manifest.yaml | kubectl apply -f -
```

### Traiter plusieurs fichiers

```bash
# Source configuration
source strimzi-config.env

# Apply all manifests in order
for f in manifest1.yaml manifest2.yaml manifest3.yaml; do
  envsubst < $f | kubectl apply -f -
done
```

### Produire des manifestes déjà substitués

Pour du GitOps ou pour relecture, produisez des manifestes entièrement substitués :

```bash
export $(grep -v '^#' config.env | xargs)

# Generate single output file
envsubst < input.yaml > processed-output.yaml

# Or generate multiple files
for f in *.yaml; do
  envsubst < $f > processed/$f
done
```

### Substitution sélective de variables

Pour ne substituer que certaines variables :

```bash
# Only substitute NAMESPACE and CLUSTER_NAME
envsubst '$NAMESPACE $CLUSTER_NAME' < manifest.yaml | kubectl apply -f -
```

---

## Vérification

Après déploiement, vérifiez que tous les composants tournent :

```bash
# Check all namespaces
kubectl get pods -A | grep -E "axonops|kafka|k8ssandra|strimzi"

# Check specific namespace
kubectl get pods -n kafka
kubectl get pods -n axonops
kubectl get pods -n k8ssandra-operator
```

---

## Support

- **Documentation AxonOps** : [https://docs.axonops.com](https://docs.axonops.com)
- **Installation de l'agent AxonOps** : [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Documentation Strimzi** : [https://strimzi.io/docs/](https://strimzi.io/docs/)
- **Documentation K8ssandra** : [https://docs.k8ssandra.io/](https://docs.k8ssandra.io/)
- **Documentation Apache Kafka** : [https://kafka.apache.org/documentation/](https://kafka.apache.org/documentation/)
- **Documentation Apache Cassandra** : [https://cassandra.apache.org/doc/](https://cassandra.apache.org/doc/)

---

**Dernière mise à jour :** 2026-02-13
