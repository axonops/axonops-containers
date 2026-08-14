# Guide de déploiement AxonOps

[English](AXONOPS_DEPLOYMENT.md) | **Français**

Ce guide traite du déploiement des services de supervision et de gestion AxonOps sur Kubernetes.

## Démarrage rapide

```bash
# Set the required passwords
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-password'

# Deploy AxonOps services
./axonops-setup.sh
```

C'est tout : les services AxonOps sont déployés et prêts à superviser vos clusters Kafka.

---

## Vue d'ensemble

AxonOps assure une supervision et une gestion complètes des clusters Apache Kafka. Le déploiement comporte quatre composants principaux :

- **axon-server** — le serveur de supervision et de gestion, cœur de la plateforme
- **axondb-timeseries** — la base de données time-series de stockage des métriques
- **axondb-search** — la base de recherche pour l'agrégation et l'interrogation des logs
- **axon-dash** — le dashboard web de visualisation

## Prérequis

1. **Un cluster Kubernetes** (mono-nœud ou multi-nœuds)
2. **Les outils nécessaires** :
   - `kubectl` — la CLI Kubernetes
   - `helm` — le gestionnaire de paquets Helm v3.x ou ultérieur
3. **Un namespace** : le namespace `axonops` par défaut (créé automatiquement)

## Configuration

### Configuration obligatoire

**CRITIQUE** : définissez les mots de passe obligatoires avant tout déploiement :

```bash
export AXON_SEARCH_PASSWORD='YourSecurePasswordHere'
export AXON_SERVER_CQL_PASSWORD='YourSecureCQLPasswordHere'
```

### Configuration optionnelle

Personnalisez le déploiement avec ces variables d'environnement :

```bash
# Namespace
export NS_AXONOPS="axonops"           # Default namespace for AxonOps

# AxonOps Server configuration
export AXON_SERVER_AGENTS_PORT="1888"       # Port for Kafka agents (default: 1888)
export AXON_SERVER_API_PORT="8080"          # API port (default: 8080)

# Storage configuration
export AXON_SEARCH_USE_HOSTPATH="false"     # Use hostPath for Search DB (default: false)
export AXON_TIMESERIES_USE_HOSTPATH="false" # Use hostPath for Timeseries DB (default: false)

# Storage sizes (for PVC mode)
export AXON_TIMESERIES_VOLUME_SIZE="10Gi"   # Timeseries DB storage
export AXON_SEARCH_VOLUME_SIZE="10Gi"       # Search DB storage

# Dashboard access
export AXON_DASH_INGRESS_ENABLED="false"    # Enable Ingress (default: false)
export AXON_DASH_INGRESS_HOST=""            # Ingress hostname
export AXON_DASH_NODEPORT_ENABLED="false"   # Enable NodePort (default: false)
export AXON_DASH_NODEPORT_PORT=""           # NodePort port number

export AXON_SEARCH_USER=admin
export AXON_SEARCH_PASSWORD=secure-password-here-5o02GzIn+58JbgU437WI8QksSHE
export AXON_SERVER_CQL_USERNAME=axonops
export AXON_SERVER_CQL_PASSWORD=secure-password-here-4kaZo3tLV3zuBRsLN2Xtudn1qwc
```

### Options de stockage

AxonOps propose deux modes de stockage pour ses bases de données :

#### Mode PVC (par défaut — recommandé)

Utilise des PersistentVolumeClaims dynamiques, avec la storage class par défaut de votre cluster ou celle que vous indiquez :

```bash
# Use default storage class
./axonops-setup.sh

# Or specify storage sizes
export AXON_TIMESERIES_VOLUME_SIZE="50Gi"
export AXON_SEARCH_VOLUME_SIZE="20Gi"
./axonops-setup.sh
```

**Avantages :**
- fonctionne avec n'importe quel fournisseur de stockage
- adapté aux environnements de production
- prend en charge les clusters multi-nœuds
- gestion automatique des volumes

#### Mode hostPath (tests mono-nœud uniquement)

Utilise des répertoires locaux sur le nœud Kubernetes :

```bash
export AXON_SEARCH_USE_HOSTPATH="true"
export AXON_TIMESERIES_USE_HOSTPATH="true"
./axonops-setup.sh
```

**Limites :**
- exige un cluster mono-nœud
- inadapté à la production
- création manuelle des répertoires nécessaire

En mode hostPath, créez les répertoires sur le nœud :

```bash
# On the Kubernetes node
sudo mkdir -p /data/axon-timeseries /data/axon-search
sudo chown -R 999:999 /data/axon-timeseries /data/axon-search
sudo chmod -R 755 /data/axon-timeseries /data/axon-search
```

## Étapes de déploiement

### Étape 1 : définir les mots de passe obligatoires

```bash
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
```

### Étape 2 : (optionnel) personnaliser la configuration

```bash
# Example: Change namespace
export NS_AXONOPS="monitoring"

# Example: Use larger storage
export AXON_TIMESERIES_VOLUME_SIZE="100Gi"
export AXON_SEARCH_VOLUME_SIZE="50Gi"
```

### Étape 3 : lancer le script de déploiement

```bash
chmod +x axonops-setup.sh
./axonops-setup.sh
```

Le script va :
1. installer cert-manager (s'il ne l'est pas déjà)
2. déployer la base AxonDB Timeseries
3. déployer la base AxonDB Search
4. déployer AxonOps Server
5. déployer le dashboard AxonOps
6. créer `axonops-config.env` avec les paramètres de connexion

### Étape 4 : attendre que les services soient prêts

```bash
# Check pod status
kubectl get pods -n axonops

# Wait for all pods to be Running
kubectl wait --for=condition=ready pod --all -n axonops --timeout=300s
```

## Accéder au dashboard AxonOps

### Option 1 : port-forward (accès rapide)

```bash
kubectl port-forward -n axonops svc/axon-dash 3000:3000

# Access at: http://localhost:3000
```

### Option 2 : NodePort (accès externe)

Activez le NodePort au moment du déploiement :

```bash
export AXON_DASH_NODEPORT_ENABLED="true"
export AXON_DASH_NODEPORT_PORT="32000"
./axonops-setup.sh

# Access at: http://<node-ip>:32000
```

### Option 3 : Ingress (production)

Activez l'Ingress au moment du déploiement :

```bash
export AXON_DASH_INGRESS_ENABLED="true"
export AXON_DASH_INGRESS_HOST="axonops.yourdomain.com"
./axonops-setup.sh

# Access at: https://axonops.yourdomain.com
```

**Note :** exige qu'un contrôleur Ingress soit installé dans votre cluster.

## Intégration avec Kafka

Une fois AxonOps déployé, vous pouvez le raccorder à vos clusters Kafka :

### Pour un nouveau déploiement Strimzi

```bash
# Source the AxonOps configuration
source axonops-config.env

# Deploy Strimzi with AxonOps integration
./strimzi-setup.sh
```

Voir [STRIMZI_DEPLOYMENT.fr.md](STRIMZI_DEPLOYMENT.fr.md) pour les détails.

### Pour un cluster Kafka existant

Configurez l'agent AxonOps sur vos brokers Kafka à partir des paramètres de connexion d'`axonops-config.env` :

```bash
# Agent connection details
AXON_AGENT_SERVER_HOST=axon-server-agent.axonops.svc.cluster.local
AXON_AGENT_SERVER_PORT=1888
```

## Vérifier le déploiement

### Contrôler l'état des composants

```bash
# View all AxonOps pods
kubectl get pods -n axonops

# View all services
kubectl get svc -n axonops

# Check Helm releases
helm list -n axonops
```

Résultat attendu :
- 4 releases Helm : `axon-server`, `axondb-timeseries`, `axondb-search`, `axon-dash`
- tous les pods à l'état Running
- des services avec des endpoints ClusterIP

### Consulter les logs

```bash
# AxonOps Server logs
kubectl logs -n axonops deployment/axon-server -f

# Dashboard logs
kubectl logs -n axonops deployment/axon-dash -f

# Timeseries DB logs
kubectl logs -n axonops statefulset/axondb-timeseries -f

# Search DB logs
kubectl logs -n axonops statefulset/axondb-search -f
```

### Tester l'accès au dashboard

```bash
# Port-forward and open browser
kubectl port-forward -n axonops svc/axon-dash 3000:3000

# In another terminal or browser, navigate to:
# http://localhost:3000
```

## Dépannage

### Pods bloqués à l'état Pending

**Vérifiez les PersistentVolumeClaims :**

```bash
kubectl get pvc -n axonops
```

**Causes possibles :**
- aucune storage class disponible
- capacité de stockage insuffisante
- en mode hostPath : répertoires non créés ou permissions incorrectes

**Solutions :**

```bash
# Check available storage classes
kubectl get storageclass

# For hostPath mode, verify directories exist
ssh <node> "ls -la /data/axon-timeseries /data/axon-search"

# Check pod events
kubectl describe pod <pod-name> -n axonops
```

### Problèmes de connexion à la base Search

**Symptôme :** AxonOps Server n'arrive pas à se connecter à la base Search

**Vérifiez la configuration du mot de passe :**

```bash
# Verify secret exists
kubectl get secret axon-server-config -n axonops

# Check server configuration
kubectl get secret axon-server-config -n axonops -o jsonpath='{.data.axon-server\.yml}' | base64 -d
```

**Solution :**

```bash
# Recreate the secret with correct password
kubectl delete secret axon-server-config -n axonops
export AXON_SEARCH_PASSWORD='your-password'
export AXON_SERVER_CQL_PASSWORD='your-cql-password'
./axonops-setup.sh
```

### Dashboard inaccessible

**Vérifiez le type de service :**

```bash
kubectl get svc axon-dash -n axonops
```

**Avec un NodePort, vérifiez que le port est joignable :**

```bash
# Check firewall rules
# Ensure node port is open in security groups/firewall

# Test connectivity
curl http://<node-ip>:<nodeport>
```

**Avec un Ingress, vérifiez la configuration de l'Ingress :**

```bash
kubectl get ingress -n axonops
kubectl describe ingress axon-dash -n axonops
```

### Problèmes de certificats

**Vérifiez l'état de cert-manager :**

```bash
kubectl get pods -n cert-manager
kubectl get clusterissuer
```

**Consultez l'état des certificats :**

```bash
kubectl get certificate -n axonops
kubectl describe certificate -n axonops
```

## Référence de configuration

### Fichier de configuration généré

Après déploiement, `axonops-config.env` est créé avec ces variables :

```bash
NS_AXONOPS=axonops
AXON_SERVER_AGENTS_PORT=1888
AXON_SERVER_API_PORT=8080
AXON_SERVER_ORG_NAME=example
```

Sourcez ce fichier avant de déployer Kafka pour bénéficier de l'intégration automatique.

### Versions des charts Helm

Le script utilise des versions de charts précises :

- **axondb-timeseries** : la plus récente du dépôt AxonOps
- **axondb-search** : la plus récente du dépôt AxonOps
- **axon-server** : la plus récente du dépôt AxonOps
- **axon-dash** : la plus récente du dépôt AxonOps

## Nettoyage

### Supprimer les services AxonOps

```bash
# Uninstall Helm releases
helm uninstall -n axonops axon-dash
helm uninstall -n axonops axon-server
helm uninstall -n axonops axondb-search
helm uninstall -n axonops axondb-timeseries

# Delete namespace
kubectl delete namespace axonops
```

### Supprimer les données (ATTENTION : supprime toutes les données)

Pour le stockage hostPath :

```bash
# On the Kubernetes node
sudo rm -rf /data/axon-timeseries
sudo rm -rf /data/axon-search
```

Pour le stockage PVC, supprimez les PVC :

```bash
kubectl delete pvc -n axonops --all
```

### Supprimer cert-manager (optionnel)

Uniquement s'il n'est pas utilisé par d'autres services :

```bash
helm uninstall -n cert-manager cert-manager
kubectl delete namespace cert-manager
```

## Considérations de production

Pour les déploiements de production :

1. **Stockage** : utilisez un stockage distribué, avec sauvegarde et plan de reprise
2. **Haute disponibilité** : envisagez plusieurs réplicas (exige de personnaliser les charts Helm)
3. **Sécurité** :
   - utilisez des mots de passe robustes
   - activez TLS sur tous les composants
   - configurez un RBAC adapté
   - utilisez des network policies
4. **Supervision** : supervisez les composants AxonOps eux-mêmes
5. **Limites de ressources** : fixez des limites CPU et mémoire adaptées
6. **Sauvegarde** : sauvegardez régulièrement les bases Search et Timeseries
7. **Contrôle d'accès** : utilisez un Ingress avec authentification et autorisation

## Exemples de configuration

Des configurations prêtes à l'emploi se trouvent dans le répertoire [axonops/](axonops/) :

- `axonops-config.env` — les variables d'environnement
- `axonops-setup.sh` — le script de déploiement automatisé
- `axonops-server-secret.yaml` — un exemple de configuration du serveur
- les fichiers de values Helm de chaque composant

## Ressources complémentaires

- **Documentation AxonOps** : [https://docs.axonops.com](https://docs.axonops.com)
- **Installation de l'agent AxonOps** : [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Intégration Strimzi Kafka** : [STRIMZI_DEPLOYMENT.fr.md](STRIMZI_DEPLOYMENT.fr.md)
- **Intégration K8ssandra Cassandra** : [K8SSANDRA_DEPLOYMENT.fr.md](K8SSANDRA_DEPLOYMENT.fr.md)
- **Exemples Strimzi cloud** : [strimzi/cloud/](strimzi/cloud/) — des manifestes Kubernetes prêts à l'emploi
- **Exemples K8ssandra** : [k8ssandra/](k8ssandra/) — des exemples de clusters Cassandra
- **Charts Helm** : le dépôt Helm AxonOps
- **Support** : contactez le support AxonOps pour les déploiements de production

---

**Dernière mise à jour :** 2026-02-13
