# Guide de déploiement K8ssandra

[English](K8SSANDRA_DEPLOYMENT.md) | **Français**

Ce guide traite du déploiement d'Apache Cassandra avec l'opérateur K8ssandra sur Kubernetes, avec l'intégration de la supervision AxonOps en option.

## Démarrage rapide

```bash
# 1. Install K8ssandra operator
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update
helm install k8ssandra-operator k8ssandra/k8ssandra-operator -n k8ssandra-operator --create-namespace

# 2. Configure and deploy cluster
cd k8ssandra/
export $(grep -v '^#' k8ssandra-config.env | xargs)
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

---

## Vue d'ensemble

K8ssandra est une plateforme prête pour la production permettant d'exécuter Apache Cassandra sur Kubernetes. Ce déploiement s'appuie sur :

- **l'opérateur K8ssandra** — l'opérateur Kubernetes qui gère les clusters Cassandra
- **les images AxonOps** — des images Cassandra avec l'agent AxonOps intégré
- **AxonOps Cloud** — l'intégration optionnelle de supervision et de gestion

### Fonctionnalités

- déploiement et mise à l'échelle automatisés
- montées de version et repairs en rolling
- capacités de sauvegarde et de restauration
- intégration de la supervision AxonOps

## Prérequis

1. **Un cluster Kubernetes** (v1.21+)
   - mono-nœud ou multi-nœuds
2. **Les outils nécessaires** :
   - `kubectl` — la CLI Kubernetes
   - `helm` — le gestionnaire de paquets Helm v3.x
   - `envsubst` — substitution de variables (fourni par le paquet `gettext`)
3. **Du stockage** : prise en charge des PersistentVolume, ou le provisionneur local-path
4. **Optionnel** : un compte AxonOps pour l'intégration de la supervision

## Installer l'opérateur K8ssandra

### Étape 1 : ajouter le dépôt Helm

```bash
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update
```

### Étape 2 : installer l'opérateur

```bash
# Create namespace and install operator
helm install k8ssandra-operator k8ssandra/k8ssandra-operator \
  -n k8ssandra-operator \
  --create-namespace
```

### Étape 3 : vérifier l'installation

```bash
# Check operator pods
kubectl get pods -n k8ssandra-operator

# Wait for operator to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=k8ssandra-operator \
  -n k8ssandra-operator \
  --timeout=300s
```

Sortie attendue :

```text
NAME                                                READY   STATUS    RESTARTS   AGE
k8ssandra-operator-xxxxxxx-xxxxx                    1/1     Running   0          1m
k8ssandra-operator-cass-operator-xxxxxxx-xxxxx      1/1     Running   0          1m
```

## Configuration

### Variables d'environnement

Créez ou modifiez `k8ssandra/k8ssandra-config.env` :

```bash
# K8ssandra Cluster Configuration
K8SSANDRA_CLUSTER_NAME=axonops-k8ssandra
K8SSANDRA_NAMESPACE=k8ssandra-operator
CASSANDRA_VERSION=5.0.6
CASSANDRA_DC_NAME=dc1
CASSANDRA_DC_SIZE=3

# AxonOps Container Image
IMAGE_NAME=ghcr.io/axonops/cassandra:5.0.6

# Storage Configuration
STORAGE_CLASS=local-path
STORAGE_SIZE=10Gi

# Resource Limits
CPU_LIMIT=2
CPU_REQUEST=1
MEMORY_LIMIT=4Gi
MEMORY_REQUEST=2Gi
HEAP_SIZE=1G

# AxonOps Agent Configuration (for AxonOps Cloud)
AXON_AGENT_KEY=your-agent-key
AXON_AGENT_ORG=your-organization
AXON_AGENT_SERVER_HOST=agents.axonops.cloud
AXON_AGENT_SERVER_PORT=443
```

### Référence des variables de configuration

| Variable | Défaut | Description |
| --- | --- | --- |
| `K8SSANDRA_CLUSTER_NAME` | `axonops-k8ssandra` | Nom du cluster Cassandra |
| `K8SSANDRA_NAMESPACE` | `k8ssandra-operator` | Namespace Kubernetes |
| `CASSANDRA_VERSION` | `5.0.6` | Version de Cassandra |
| `IMAGE_NAME` | `ghcr.io/axonops/cassandra:5.0.6` | Image Cassandra AxonOps |
| `CASSANDRA_DC_NAME` | `dc1` | Nom du datacenter |
| `CASSANDRA_DC_SIZE` | `3` | Nombre de nœuds Cassandra |
| `STORAGE_CLASS` | `local-path` | StorageClass Kubernetes |
| `STORAGE_SIZE` | `10Gi` | Stockage par nœud |
| `AXON_AGENT_KEY` | - | Clé d'API AxonOps |
| `AXON_AGENT_ORG` | - | Nom de l'organisation AxonOps |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | Nom d'hôte du serveur AxonOps |
| `AXON_AGENT_SERVER_PORT` | `443` | Port du serveur AxonOps |

## Déploiement

### Avec envsubst

Les manifestes d'exemple contiennent des placeholders de variables d'environnement. Utilisez `envsubst` pour y substituer les valeurs avant application :

```bash
cd k8ssandra/

# 1. Source configuration
export $(grep -v '^#' k8ssandra-config.env | xargs)

# 2. Apply cluster manifest with variable substitution
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

### Déploiement manuel

Vous pouvez aussi modifier directement le fichier YAML puis l'appliquer :

```bash
# Edit the manifest
vi k8ssandra/cluster-axonops-ubi.yaml

# Apply directly
kubectl apply -f k8ssandra/cluster-axonops-ubi.yaml
```

### Attendre que le cluster soit prêt

```bash
# Watch cluster status
kubectl get k8ssandraclusters -n k8ssandra-operator -w

# Check pods
kubectl get pods -n k8ssandra-operator -l cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME

# View cluster details
kubectl describe k8ssandracluster $K8SSANDRA_CLUSTER_NAME -n k8ssandra-operator
```

## Vérifier le déploiement

### Contrôler l'état du cluster

```bash
# View K8ssandraCluster resource
kubectl get k8ssandraclusters -n k8ssandra-operator

# View CassandraDatacenter
kubectl get cassandradatacenters -n k8ssandra-operator

# View all pods
kubectl get pods -n k8ssandra-operator -o wide
```

### Tester la connectivité Cassandra

```bash
# Get a shell in a Cassandra pod
kubectl exec -it ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- cqlsh

# Run a simple query
cqlsh> SELECT cluster_name, listen_address FROM system.local;
cqlsh> DESCRIBE KEYSPACES;
```

### Contrôler l'intégration AxonOps

Si vous utilisez AxonOps Cloud :

```bash
# Check agent logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator | grep -i axon

# Verify agent environment variables
kubectl exec ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- env | grep AXON
```

Consultez ensuite le dashboard AxonOps sur [https://console.axonops.cloud](https://console.axonops.cloud) pour vérifier que votre cluster y apparaît.

## Options d'intégration AxonOps

### Option 1 : AxonOps Cloud (SaaS)

Utilisez AxonOps Cloud pour une supervision managée :

1. Créez un compte sur [https://axonops.cloud](https://axonops.cloud)
2. Créez une organisation et récupérez votre clé d'API
3. Renseignez les variables d'environnement de l'agent dans `k8ssandra-config.env` :

```bash
AXON_AGENT_KEY=your-api-key
AXON_AGENT_ORG=your-organization
AXON_AGENT_SERVER_HOST=agents.axonops.cloud
AXON_AGENT_SERVER_PORT=443
```

### Option 2 : AxonOps auto-hébergé

Déployez d'abord AxonOps on-premises, puis configurez Cassandra pour s'y connecter :

```bash
# Deploy AxonOps (see AXONOPS_DEPLOYMENT.md)
cd ../axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh
source axonops-config.env

# Configure K8ssandra to use self-hosted AxonOps
export AXON_AGENT_SERVER_HOST=axon-server-agent.axonops.svc.cluster.local
export AXON_AGENT_SERVER_PORT=1888
export AXON_AGENT_ORG=$AXON_SERVER_ORG_NAME

# Deploy K8ssandra
cd ../k8ssandra/
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

## Mettre le cluster à l'échelle

### Ajouter des nœuds

```bash
# Edit the datacenter size
kubectl patch k8ssandracluster $K8SSANDRA_CLUSTER_NAME \
  -n k8ssandra-operator \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/cassandra/datacenters/0/size", "value": 5}]'

# Or edit the manifest and reapply
export CASSANDRA_DC_SIZE=5
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

### Retirer des nœuds

Réduisez la taille avec précaution, pour éviter toute perte de données :

```bash
# Decommission nodes first, then reduce size
kubectl patch k8ssandracluster $K8SSANDRA_CLUSTER_NAME \
  -n k8ssandra-operator \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/cassandra/datacenters/0/size", "value": 3}]'
```

## Dépannage

### Pods bloqués en Pending

```bash
# Check PVC status
kubectl get pvc -n k8ssandra-operator

# Check events
kubectl get events -n k8ssandra-operator --sort-by='.lastTimestamp'

# Verify storage class exists
kubectl get storageclass
```

### Cassandra ne démarre pas

```bash
# Check pod logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator

# Check init container logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -c server-config-init

# Describe pod for events
kubectl describe pod ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator
```

### L'agent AxonOps ne se connecte pas

```bash
# Verify environment variables
kubectl exec ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- env | grep AXON

# Test network connectivity to AxonOps
kubectl exec ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- nc -zv $AXON_AGENT_SERVER_HOST $AXON_AGENT_SERVER_PORT

# Check agent logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator | grep -i "axon\|agent"
```

## Nettoyage

### Supprimer le cluster Cassandra

```bash
# Delete the K8ssandraCluster
kubectl delete k8ssandracluster $K8SSANDRA_CLUSTER_NAME -n k8ssandra-operator

# Delete PVCs (WARNING: deletes all data)
kubectl delete pvc -l cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME \
  -n k8ssandra-operator
```

### Supprimer l'opérateur K8ssandra

```bash
# Uninstall operator
helm uninstall k8ssandra-operator -n k8ssandra-operator

# Delete namespace
kubectl delete namespace k8ssandra-operator
```

## Considérations de production

1. **Stockage** : utilisez des SSD performants, avec des IOPS adaptées
2. **Ressources** : allouez suffisamment de CPU et de mémoire (4 cœurs et 8 Go de RAM par nœud au minimum recommandés)
3. **Réplication** : utilisez un facteur de réplication de 3 en production
4. **Sauvegarde** : configurez Medusa pour des sauvegardes automatisées
5. **Supervision** : utilisez AxonOps pour une supervision et une alerte complètes
6. **Sécurité** : activez le chiffrement TLS et l'authentification
7. **Réseau** : dédiez un réseau aux communications entre nœuds

## Ressources complémentaires

- **Documentation K8ssandra** : [https://docs.k8ssandra.io/](https://docs.k8ssandra.io/)
- **K8ssandra sur GitHub** : [https://github.com/k8ssandra/k8ssandra](https://github.com/k8ssandra/k8ssandra)
- **Documentation AxonOps** : [https://docs.axonops.com](https://docs.axonops.com)
- **Installation de l'agent AxonOps** : [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Documentation Apache Cassandra** : [https://cassandra.apache.org/doc/](https://cassandra.apache.org/doc/)
- **Manifestes d'exemple** : [k8ssandra/](k8ssandra/)

---

**Dernière mise à jour :** 2026-02-13
