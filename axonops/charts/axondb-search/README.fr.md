# Base de recherche AxonOps

[English](README.md) | **Français**

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3.7.0-1.6.1](https://img.shields.io/badge/AppVersion-3.7.0--1.6.1-informational?style=flat-square)

Un chart Helm pour déployer la base de recherche AxonOps sur Kubernetes. Cette base assure l'indexation et la recherche des logs, des événements et des données d'exploitation de la plateforme AxonOps.

**Site web :** <https://axonops.com>

## Table des matières

- [Prérequis](#prérequis)
- [Démarrage rapide](#démarrage-rapide)
- [Exemples d'installation](#exemples-dinstallation)
  - [Installation de base](#installation-de-base)
  - [Installation avec un stockage personnalisé](#installation-avec-un-stockage-personnalisé)
  - [Installation avec authentification](#installation-avec-authentification)
  - [Installation avec TLS (certificats manuels)](#installation-avec-tls-certificats-manuels)
  - [Installation avec TLS (cert-manager)](#installation-avec-tls-cert-manager)
  - [Installation en cluster multi-nœuds](#installation-en-cluster-multi-nœuds)
  - [Installation prête pour la production](#installation-prête-pour-la-production)
- [Configuration des sauvegardes](#configuration-des-sauvegardes)
  - [Sauvegardes locales](#sauvegardes-locales)
  - [Sauvegardes S3](#sauvegardes-s3)
- [Gestion externe des secrets (vals-operator)](#gestion-externe-des-secrets-vals-operator)
- [Configuration](#configuration)
- [Mise à jour](#mise-à-jour)
  - [Mise à jour vers le chart 0.3.0 (OpenSearch 3.3.2 vers 3.7.0)](#mise-à-jour-vers-le-chart-030-opensearch-332-vers-370)
- [Désinstallation](#désinstallation)
- [Dépannage](#dépannage)

## Prérequis

Avant de commencer, assurez-vous de disposer de ce qui suit :

- **Un cluster Kubernetes** : version 1.19 ou ultérieure
- **kubectl** : configuré pour dialoguer avec votre cluster
- **Helm** : version 3.0 ou ultérieure ([guide d'installation](https://helm.sh/docs/intro/install/))
- **Du stockage** : une StorageClass par défaut configurée dans votre cluster, ou une StorageClass dédiée aux volumes persistants
- **Des ressources** : au moins 4 Go de mémoire disponible et 2 cœurs CPU recommandés

### Prérequis optionnels

- **cert-manager** : nécessaire uniquement si vous voulez une gestion automatique des certificats TLS ([guide d'installation](https://cert-manager.io/docs/installation/))
- **Prometheus Operator** : nécessaire uniquement si vous voulez activer la supervision des métriques via un ServiceMonitor

### Vérifier votre installation

Vérifiez que Helm est installé :
```bash
helm version
```

Vérifiez que kubectl est configuré :
```bash
kubectl cluster-info
```

Listez les StorageClasses disponibles :
```bash
kubectl get storageclass
```

## Démarrage rapide

Le moyen le plus rapide de démarrer avec la base de recherche AxonOps :

```bash
# Add the AxonOps Helm repository (if available)
# helm repo add axonops https://axonops.github.io/helm-charts
# helm repo update

# Install with default settings (single-node mode)
helm install axondb-search ./axondb-search

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axondb-search
```

Cela déploie une base de recherche mono-nœud avec :
- 8 Gi de stockage persistant
- les limites de ressources par défaut (4 Go de mémoire, 1 CPU)
- le mode de découverte mono-nœud
- HTTPS activé par défaut
- une configuration de sécurité de base

## Exemples d'installation

### Installation de base

Installation minimale, adaptée au développement et aux tests :

```bash
helm install axondb-search ./axondb-search \
  --set replicas=1 \
  --set singleNode=true
```

Ou créez un fichier `values-basic.yaml` :

```yaml
# values-basic.yaml
# Single-node configuration for development

replicas: 1
singleNode: true

# Increase heap size for better performance
opensearchHeapSize: "2g"

# Resource limits
resources:
  requests:
    cpu: 1000m
    memory: 4Gi
  limits:
    cpu: 2000m
    memory: 4Gi

# Persistent storage
persistence:
  enabled: true
  size: 10Gi
```

Installez avec le fichier de values :

```bash
helm install axondb-search ./axondb-search -f values-basic.yaml
```

### Installation avec un stockage personnalisé

Configurez le stockage persistant avec une StorageClass et une taille précises :

```yaml
# values-storage.yaml
replicas: 1
singleNode: true

# Heap size (should be ~50% of container memory)
opensearchHeapSize: "4g"

persistence:
  enabled: true
  # Use your cluster's StorageClass (e.g., gp3, standard, fast-ssd)
  # storageClass: "gp3"
  size: 50Gi
  accessModes:
    - ReadWriteOnce
  # Optional: Add annotations for the PVC
  annotations: {}
  # Optional: Enable volume labels
  labels:
    enabled: true
    additionalLabels:
      app: axondb-search
      environment: production

resources:
  requests:
    cpu: 2000m
    memory: 8Gi
  limits:
    cpu: 4000m
    memory: 8Gi
```

Installation :

```bash
helm install axondb-search ./axondb-search -f values-storage.yaml
```

### Installation avec authentification

Protégez votre base de recherche avec des identifiants :

**Option 1 : valeurs directes (développement uniquement)**

```yaml
# values-auth.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

authentication:
  opensearch_user: "axonops"
  opensearch_password: "your-secure-password"
```

**Option 2 : secrets Kubernetes (recommandé en production)**

Créez d'abord un secret Kubernetes :

```bash
kubectl create secret generic -n axonops axondb-search-credentials \
  --from-literal=AXONOPS_SEARCH_USER=axonops \
  --from-literal=AXONOPS_SEARCH_PASSWORD=secure-password
```

Créez ensuite votre fichier de values :

```yaml
# values-auth-secret.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

authentication:
  opensearch_secret: "axondb-search-credentials"
```

Installation :

```bash
helm install axondb-search ./axondb-search -f values-auth-secret.yaml
```

### Installation avec TLS (certificats manuels)

Utilisez des certificats TLS existants pour chiffrer les communications :

**Étape 1 : créer un secret contenant vos certificats**

```bash
kubectl create secret generic axondb-search-tls-manual \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key \
  --from-file=ca.crt=path/to/ca.crt
```

**Étape 2 : créer votre fichier de values**

```yaml
# values-tls-manual.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

# Enable HTTPS protocol
protocol: https

tls:
  enabled: true
  manual:
    existingSecret: "axondb-search-tls-manual"

# Security configuration
securityConfig:
  enabled: true
```

Installation :

```bash
helm install axondb-search ./axondb-search -f values-tls-manual.yaml
```

### Installation avec TLS (cert-manager)

Générez et gérez les certificats TLS automatiquement avec cert-manager :

**Prérequis :**
- cert-manager doit être installé dans votre cluster

**Étape 1 : installer cert-manager (s'il ne l'est pas déjà)**

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

Attendez que cert-manager soit prêt :

```bash
kubectl wait --for=condition=Available --timeout=300s \
  deployment/cert-manager -n cert-manager
```

**Étape 2 : créer votre fichier de values**

**Avec des certificats auto-signés (développement / test) :**

```yaml
# values-tls-certmanager-selfsigned.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

# Enable HTTPS protocol
protocol: https

tls:
  enabled: true
  certManager:
    enabled: true
    # Keystore password (change this!)
    keystorePassword: "my-secure-keystore-password"

    issuer:
      # Automatically create a self-signed issuer
      createSelfSigned: true
      kind: "ClusterIssuer"

    certificate:
      # Certificate will be valid for 5 years
      duration: 43800h
      # Renew 30 days before expiry
      renewBefore: 720h
      secretName: "axondb-search-tls-cert"

# Security configuration
securityConfig:
  enabled: true
```

**Avec un issuer existant (production) :**

```yaml
# values-tls-certmanager-production.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

# Enable HTTPS protocol
protocol: https

tls:
  enabled: true
  certManager:
    enabled: true
    keystorePassword: "my-secure-keystore-password"

    issuer:
      # Use your existing ClusterIssuer
      name: "letsencrypt-prod"
      kind: "ClusterIssuer"
      createSelfSigned: false

    certificate:
      # Custom DNS names for the certificate
      commonName: "axondb-search.example.com"
      dnsNames:
        - "axondb-search.example.com"
        - "*.axondb-search.example.com"
      duration: 2160h  # 90 days
      renewBefore: 360h  # 15 days
      secretName: "axondb-search-tls-cert"

securityConfig:
  enabled: true
```

Installation :

```bash
# For self-signed certificates
helm install axondb-search ./axondb-search -f values-tls-certmanager-selfsigned.yaml

# OR for production with existing issuer
helm install axondb-search ./axondb-search -f values-tls-certmanager-production.yaml
```

**Vérifier la création du certificat :**

```bash
kubectl get certificate
kubectl describe certificate axondb-search-tls
```

### Installation en cluster multi-nœuds

Déployez un cluster multi-nœuds, pour la haute disponibilité et de meilleures performances :

```yaml
# values-cluster.yaml
# Multi-node cluster configuration

# Disable single-node mode for clustering
singleNode: false

# Deploy 3 nodes for high availability
replicas: 3

clusterName: "axondb-search-cluster"

# Node roles (master, data, ingest)
roles:
  - master
  - ingest
  - data
  - remote_cluster_client

# Heap size per node
opensearchHeapSize: "4g"

# Resource allocation per node
resources:
  requests:
    cpu: 2000m
    memory: 8Gi
  limits:
    cpu: 4000m
    memory: 8Gi

# Persistent storage per node
persistence:
  enabled: true
  size: 50Gi
  accessModes:
    - ReadWriteOnce

# Anti-affinity to spread pods across nodes
antiAffinity: "hard"
antiAffinityTopologyKey: "kubernetes.io/hostname"

# Pod management policy
podManagementPolicy: "Parallel"

# Security configuration
securityConfig:
  enabled: true

# Node certificate DNs for inter-node security (multi-node clusters)
# Configures which certificate Distinguished Names can join the cluster
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.default.svc.cluster.local;CN=axondb-search-cluster-master-0;CN=axondb-search-cluster-master-1;CN=axondb-search-cluster-master-2"

# Service configuration
service:
  type: ClusterIP
  httpPortName: http
  transportPortName: transport
```

Installation :

```bash
helm install axondb-search ./axondb-search -f values-cluster.yaml
```

### Installation prête pour la production

Une configuration de production complète, avec tous les réglages recommandés :

```yaml
# values-production.yaml
# Production configuration for AxonOps Search DB

# Multi-node cluster for high availability
singleNode: false
replicas: 3

clusterName: "axondb-search-production"

# Node roles
roles:
  - master
  - ingest
  - data
  - remote_cluster_client

# Heap size (50% of container memory)
opensearchHeapSize: "8g"

# Authentication using Kubernetes secrets
authentication:
  opensearch_secret: "axondb-search-credentials"

# Resource limits for production workloads
resources:
  requests:
    cpu: 2000m
    memory: 16Gi
  limits:
    cpu: 4000m
    memory: 16Gi

# Persistent storage configuration
persistence:
  enabled: true
  size: 100Gi
  accessModes:
    - ReadWriteOnce
  # storageClass: "gp3"  # Uncomment and set your StorageClass
  labels:
    enabled: true
    additionalLabels:
      environment: production

# TLS encryption with cert-manager
protocol: https
tls:
  enabled: true
  certManager:
    enabled: true
    keystorePassword: "change-this-secure-password"
    issuer:
      name: "letsencrypt-prod"
      kind: "ClusterIssuer"
      createSelfSigned: false
    certificate:
      commonName: "axondb-search.prod.example.com"
      dnsNames:
        - "axondb-search.prod.example.com"
        - "*.axondb-search.prod.example.com"
      duration: 2160h
      renewBefore: 360h

# Security configuration
securityConfig:
  enabled: true

# Node certificate DNs for inter-node security
# IMPORTANT: Configure this for multi-node clusters to control which nodes can join
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.prod.example.com;CN=axondb-search-production-0;CN=axondb-search-production-1;CN=axondb-search-production-2"

# Health check probes
startupProbe:
  tcpSocket:
    port: 9200
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 30

readinessProbe:
  tcpSocket:
    port: 9200
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# Pod security context
podSecurityContext:
  fsGroup: 999
  runAsUser: 999

securityContext:
  capabilities:
    drop:
      - ALL
  runAsNonRoot: true
  runAsUser: 999

# Service configuration
service:
  type: ClusterIP
  annotations: {}
  labels:
    environment: production

# Anti-affinity rules to spread pods across nodes
antiAffinity: "hard"
antiAffinityTopologyKey: "kubernetes.io/hostname"

# Pod management policy (Parallel for faster startup)
podManagementPolicy: "Parallel"

# System settings
sysctlVmMaxMapCount: 262144
sysctlInit:
  enabled: false  # Set to true if not configured at OS level

# Graceful shutdown period
terminationGracePeriod: 120

# Enable Prometheus monitoring (requires prometheus-exporter plugin)
serviceMonitor:
  enabled: false  # Enable after installing prometheus-exporter plugin
  interval: 30s
  path: /_prometheus/metrics
  scheme: https
  labels:
    prometheus: kube-prometheus

# Network policy (optional)
networkPolicy:
  create: false

# Tolerations for dedicated nodes (optional)
# tolerations:
#   - key: "workload"
#     operator: "Equal"
#     value: "search"
#     effect: "NoSchedule"

# Node selector for dedicated nodes (optional)
# nodeSelector:
#   workload: search
```

**Avant l'installation, créez le secret d'authentification :**

```bash
kubectl create secret generic axondb-search-credentials \
  --from-literal=OPENSEARCH_USER=axonops \
  --from-literal=OPENSEARCH_PASSWORD=$(openssl rand -base64 32)
```

**Installer le déploiement de production :**

```bash
helm install axondb-search ./axondb-search \
  -f values-production.yaml \
  --namespace axonops \
  --create-namespace
```

**Vérifier la santé du cluster :**

```bash
# Check all pods are running
kubectl get pods -l app.kubernetes.io/name=axondb-search -n axonops

# Check cluster health (port-forward to access)
kubectl port-forward svc/axondb-search-cluster-master 9200:9200 -n axonops

# In another terminal (if using default credentials)
curl -k -u admin:ChangeThisSecurePassword123! https://localhost:9200/_cluster/health
```

## Configuration des sauvegardes

Le chart axondb-search embarque une fonctionnalité de sauvegarde fondée sur les snapshots OpenSearch. Les sauvegardes peuvent rester locales ou aller vers un stockage compatible S3.

### Sauvegardes locales

Configurer des sauvegardes sur système de fichiers local, avec un PVC dédié :

```yaml
# values-backup-local.yaml
backups:
  enabled: true
  schedule: "0 8 * * *"  # Daily at 8am UTC

  # Snapshot retention
  retention:
    days: 30
    count: ""  # Optional: max number of snapshots

  # Local backup target
  target:
    type: local
    local:
      path: "/mnt/backups"
      size: "50Gi"
      storageClass: ""  # Uses default storage class
```

Installation :

```bash
helm install axondb-search ./axondb-search -f values-backup-local.yaml
```

### Sauvegardes S3

Configurer les sauvegardes vers AWS S3 ou un stockage compatible S3 (MinIO, Ceph, etc.) :

#### Avec AWS S3

```yaml
# values-backup-s3.yaml
backups:
  enabled: true
  schedule: "0 */6 * * *"  # Every 6 hours

  retention:
    days: 30

  target:
    type: s3
    s3:
      bucket: "my-opensearch-backups"
      region: "us-east-1"
      basePath: "axondb-search"

      # Method 1: Use existing Kubernetes secret (recommended)
      credentials:
        existingSecret: "aws-backup-credentials"
        # Secret must contain keys: aws-access-key-id, aws-secret-access-key

      # Method 2: Inline credentials (NOT recommended for production)
      # credentials:
      #   accessKeyId: "AKIAIOSFODNN7EXAMPLE"
      #   secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

Créez le secret contenant les identifiants :

```bash
kubectl create secret generic aws-backup-credentials \
  --from-literal=aws-access-key-id=AKIAIOSFODNN7EXAMPLE \
  --from-literal=aws-secret-access-key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

#### Avec un stockage compatible S3 (MinIO)

```yaml
# values-backup-minio.yaml
backups:
  enabled: true
  schedule: "0 */4 * * *"

  target:
    type: s3
    s3:
      bucket: "opensearch-backups"
      endpoint: "http://minio.minio.svc.cluster.local:9000"
      pathStyleAccess: true  # Required for MinIO

      credentials:
        existingSecret: "minio-credentials"
```

#### Avec des rôles IAM AWS (EKS avec IRSA)

Pour les clusters EKS utilisant les IAM Roles for Service Accounts :

```yaml
# values-backup-irsa.yaml
backups:
  enabled: true
  target:
    type: s3
    s3:
      bucket: "my-opensearch-backups"
      region: "us-east-1"
      # Leave credentials empty for IRSA

rbac:
  create: true
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/opensearch-backup-role
```

## Gestion externe des secrets (vals-operator)

Le chart prend en charge [vals-operator](https://github.com/digitalis-io/vals-operator) pour récupérer les secrets depuis des coffres externes tels qu'AWS Secrets Manager, HashiCorp Vault, Google Secret Manager ou Azure Key Vault.

### Installation de vals-operator

Installez vals-operator dans votre cluster :

```bash
helm repo add digitalis https://digitalis-io.github.io/helm-charts
helm install vals-operator digitalis/vals-operator
```

### Configuration de vals-operator

```yaml
# values-vals.yaml
vals:
  enabled: true
  ttl: 3600  # Refresh interval in seconds

  # OpenSearch authentication from external secret store
  authentication:
    # AWS Secrets Manager example
    opensearch_user: "ref+awssecrets://axonops/search#username"
    opensearch_password: "ref+awssecrets://axonops/search#password"

    # HashiCorp Vault example
    # opensearch_user: "ref+vault://secret/data/axonops/search#username"
    # opensearch_password: "ref+vault://secret/data/axonops/search#password"

  # TLS keystore password (if using TLS)
  tls:
    keystorePassword: "ref+awssecrets://axonops/tls#keystore-password"

  # S3 backup credentials
  s3Credentials:
    accessKeyId: "ref+awssecrets://axonops/s3#access-key-id"
    secretAccessKey: "ref+awssecrets://axonops/s3#secret-access-key"

  # ServiceMonitor basic auth (if using Prometheus)
  serviceMonitor:
    username: "ref+awssecrets://axonops/monitoring#username"
    password: "ref+awssecrets://axonops/monitoring#password"
```

Installation :

```bash
helm install axondb-search ./axondb-search -f values-vals.yaml
```

Lorsque vals-operator est activé, une ressource `ValsSecret` est créée ; vals-operator la réconcilie en un Secret Kubernetes standard. L'intégration avec les coffres externes se fait ainsi de façon transparente.

## Configuration

### Principales options de configuration

| Paramètre | Description | Défaut |
|-----------|-------------|---------|
| `replicas` | Nombre de réplicas de la base de recherche | `1` |
| `singleNode` | Activer le mode mono-nœud (désactive le clustering) | `true` |
| `opensearchHeapSize` | Taille du heap JVM | `2g` |
| `image.repository` | Dépôt de l'image de conteneur | `ghcr.io/axonops/axondb-search` |
| `image.tag` | Tag de l'image de conteneur | `""` (utilise appVersion) |
| `authentication.opensearch_user` | Nom d'utilisateur (dev uniquement) | `""` |
| `authentication.opensearch_password` | Mot de passe (dev uniquement) | `""` |
| `authentication.opensearch_secret` | Nom du secret Kubernetes portant les identifiants | `""` |
| `persistence.enabled` | Activer le stockage persistant | `true` |
| `persistence.size` | Taille du volume de données | `8Gi` |
| `protocol` | Protocole HTTP (http ou https) | `https` |
| `tls.enabled` | Activer le chiffrement TLS/SSL | `false` |
| `tls.certManager.enabled` | Utiliser cert-manager pour les certificats | `false` |
| `resources.requests.memory` | Requête mémoire | `4096Mi` |
| `resources.requests.cpu` | Requête CPU | `1000m` |

### Points importants

**Taille du heap :**
- le heap doit représenter environ 50 % de la mémoire du conteneur
- exemple : avec `resources.limits.memory: 8Gi`, mettez `opensearchHeapSize: "4g"`
- ne dépassez jamais 32 Go de heap (limite des OOP compressés)

**Mode mono-nœud ou mode cluster :**
- `singleNode: true` — pour le développement et les tests ; force `replicas: 1`
- `singleNode: false` — pour la production ; autorise plusieurs réplicas et la haute disponibilité

**Sécurité :**
- utilisez toujours des secrets Kubernetes pour les identifiants en production
- activez TLS sur les déploiements de production

**Sécurité multi-nœuds (DN des certificats de nœud) :**

Sur un cluster multi-nœuds, indiquez quels Distinguished Names (DN) de certificats sont autorisés à rejoindre le cluster, via la variable d'environnement `OPENSEARCH_SECURITY_NODES_DN`. C'est essentiel pour sécuriser la couche transport entre nœuds.

Configuration via `extraEnvs` :
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.example.svc.cluster.local;CN=node-1;CN=node-2"
```

**Points clés :**
- séparez plusieurs DN par des points-virgules (`;`)
- les jokers sont acceptés (par exemple `CN=*.svc.cluster.local`), pratiques pour les noms de pods dynamiques dans Kubernetes
- seuls les nœuds dont le certificat correspond à ces DN peuvent rejoindre le cluster
- indispensable pour empêcher un nœud non autorisé de rejoindre votre cluster
- valeur par défaut : `CN=*.axonops.svc.cluster.local`

**Exemple pour Kubernetes avec un DNS joker :**
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.default.svc.cluster.local"
```

**Exemple avec des noms de nœuds explicites :**
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=axondb-search-0;CN=axondb-search-1;CN=axondb-search-2"
```

### Référence complète des values

<details>
<summary>Cliquez pour dérouler le tableau complet des values</summary>

| Clé | Type | Défaut | Description |
|-----|------|---------|-------------|
| antiAffinity | string | `"soft"` | Réglage d'anti-affinité (soft, hard ou personnalisé) |
| antiAffinityTopologyKey | string | `"kubernetes.io/hostname"` | Clé de topologie de l'anti-affinité |
| authentication.opensearch_password | string | `""` | Mot de passe de la base (en clair — dev uniquement) |
| authentication.opensearch_secret | string | `""` | Nom du secret Kubernetes portant les identifiants |
| authentication.opensearch_user | string | `""` | Nom d'utilisateur de la base (en clair — dev uniquement) |
| clusterName | string | `"axondb-search-cluster"` | Nom du cluster de recherche |
| config.opensearch.yml | string | `"cluster.name: opensearch-cluster\n\nnetwork.host: 0.0.0.0\n"` | Contenu du fichier de configuration |
| enableServiceLinks | bool | `true` | Activer l'injection des service links |
| envFrom | list | `[]` | Charger les variables d'environnement depuis des secrets / configmaps |
| extraContainers | list | `[]` | Conteneurs sidecar supplémentaires |
| extraEnvs | list | `[]` | Variables d'environnement supplémentaires (à utiliser pour OPENSEARCH_SECURITY_NODES_DN sur un cluster multi-nœuds) |
| extraInitContainers | list | `[]` | Init containers supplémentaires |
| extraVolumeMounts | list | `[]` | Montages de volumes supplémentaires |
| extraVolumes | list | `[]` | Volumes supplémentaires |
| fullnameOverride | string | `""` | Remplacer le nom complet des ressources |
| httpPort | int | `9200` | Port HTTP du service |
| image.pullPolicy | string | `"IfNotPresent"` | Politique de pull de l'image |
| image.repository | string | `"ghcr.io/axonops/axondb-search"` | Dépôt de l'image de conteneur |
| image.tag | string | `""` | Tag de l'image (par défaut, l'appVersion du chart) |
| imagePullSecrets | list | `[]` | Secrets de pull d'image pour les registres privés |
| ingress.enabled | bool | `false` | Activer l'ingress |
| ingress.annotations | object | `{}` | Annotations de l'ingress |
| ingress.hosts | list | `["chart-example.local"]` | Noms d'hôtes de l'ingress |
| labels | object | `{}` | Labels supplémentaires des ressources |
| lifecycle | object | `{}` | Hooks de cycle de vie des conteneurs |
| livenessProbe | object | `{}` | Configuration de la sonde de liveness |
| majorVersion | string | `"3"` | Version majeure du moteur de recherche |
| masterService | string | `"axondb-search-cluster-master"` | Nom du service master pour le clustering |
| maxUnavailable | int | `1` | Nombre maximal de pods indisponibles pendant une mise à jour |
| metricsPort | int | `9600` | Port des métriques |
| nameOverride | string | `""` | Remplacer le nom du chart |
| networkHost | string | `"0.0.0.0"` | Adresse d'écoute réseau |
| networkPolicy.create | bool | `false` | Créer une network policy |
| nodeSelector | object | `{}` | Labels de nœud pour l'affectation des pods |
| opensearchHeapSize | string | `"2g"` | Taille du heap JVM |
| opensearchJavaOps | string | `""` | Options Java supplémentaires |
| persistence.enabled | bool | `true` | Activer le stockage persistant |
| persistence.size | string | `"8Gi"` | Taille du volume de données |
| persistence.accessModes | list | `["ReadWriteOnce"]` | Modes d'accès du PVC |
| persistence.annotations | object | `{}` | Annotations du PVC |
| persistence.existingClaim | string | `""` | Utiliser un PVC existant |
| plugins.enabled | bool | `false` | Activer la gestion des plugins |
| plugins.installList | list | `[]` | Liste des plugins à installer |
| podAnnotations | object | `{}` | Annotations des pods |
| podManagementPolicy | string | `"Parallel"` | Politique de gestion des pods |
| podSecurityContext.fsGroup | int | `999` | FSGroup du contexte de sécurité du pod |
| podSecurityContext.runAsUser | int | `999` | UID d'exécution des pods |
| protocol | string | `"https"` | Protocole HTTP (http ou https) |
| rbac.create | bool | `false` | Créer les ressources RBAC |
| readinessProbe.failureThreshold | int | `3` | Seuil d'échec de la sonde de readiness |
| readinessProbe.periodSeconds | int | `5` | Fréquence du contrôle |
| readinessProbe.timeoutSeconds | int | `3` | Délai d'expiration de la sonde de readiness |
| replicas | int | `1` | Nombre de réplicas |
| resources.requests.cpu | string | `"1000m"` | Requête CPU |
| resources.requests.memory | string | `"4096Mi"` | Requête mémoire |
| roles | list | `["master","ingest","data","remote_cluster_client"]` | Rôles des nœuds |
| securityConfig.enabled | bool | `true` | Activer la configuration de sécurité |
| securityContext.capabilities.drop | list | `["ALL"]` | Retirer toutes les capabilities |
| securityContext.runAsNonRoot | bool | `true` | Exécuter sous un utilisateur non root |
| securityContext.runAsUser | int | `999` | UID d'exécution du conteneur |
| service.type | string | `"ClusterIP"` | Type de service Kubernetes |
| service.httpPortName | string | `"http"` | Nom du port HTTP |
| service.transportPortName | string | `"transport"` | Nom du port transport |
| serviceMonitor.enabled | bool | `false` | Activer le ServiceMonitor Prometheus |
| serviceMonitor.interval | string | `"10s"` | Intervalle de scrape |
| serviceMonitor.path | string | `"/_prometheus/metrics"` | Chemin des métriques |
| singleNode | bool | `true` | Activer le mode mono-nœud |
| startupProbe.failureThreshold | int | `30` | Seuil d'échec de la sonde de démarrage |
| startupProbe.initialDelaySeconds | int | `5` | Délai avant la première sonde de démarrage |
| startupProbe.periodSeconds | int | `10` | Fréquence du contrôle |
| sysctlVmMaxMapCount | int | `262144` | Valeur de vm.max_map_count |
| terminationGracePeriod | int | `120` | Délai d'arrêt gracieux |
| tls.enabled | bool | `false` | Activer TLS/SSL |
| tls.certManager.enabled | bool | `false` | Activer cert-manager pour TLS |
| tls.certManager.keystorePassword | string | `"changeme"` | Mot de passe du keystore |
| tls.certManager.issuer.createSelfSigned | bool | `true` | Créer un issuer auto-signé |
| tls.certManager.issuer.kind | string | `"ClusterIssuer"` | Type d'issuer |
| tls.certManager.certificate.duration | string | `"43800h"` | Durée de validité du certificat |
| tls.manual.existingSecret | string | `""` | Secret existant contenant des certificats fournis manuellement |
| tolerations | list | `[]` | Tolerations pour l'affectation des pods |
| transportPort | int | `9300` | Port transport des communications entre nœuds |
| updateStrategy | string | `"RollingUpdate"` | Stratégie de mise à jour |

</details>

## Mise à jour

Pour mettre à jour une installation existante :

```bash
# Update the chart
helm upgrade axondb-search ./axondb-search -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axondb-search-cluster-master
```

**Important :** sur un cluster multi-nœuds, la mise à jour se fait en rolling update. Assurez-vous d'avoir la capacité d'absorber le trafic pendant l'opération.

### Mise à jour vers le chart 0.3.0 (OpenSearch 3.3.2 vers 3.7.0)

Le chart 0.3.0 fait passer `appVersion` de `3.3.2-1.5.0` à `3.7.0-1.6.1`. Comme `image.tag` est vide par défaut, le chart prend son tag d'image depuis `appVersion` : un `helm upgrade` vers 0.3.0 fait donc franchir à OpenSearch une ligne de version, et non un simple correctif. L'opération n'est pas réversible en revenant en arrière sur le chart : dès qu'un nœud a démarré en 3.7.0, il a mis à jour son index Lucene sur disque, et 3.3.2 ne saura plus le lire.

Avant la mise à jour :

```bash
# 1. Take a snapshot. The chart's backup support is documented under "Backup Configuration" above.
#    Verify the snapshot completed before going any further.
kubectl exec -it axondb-search-cluster-master-0 -- \
  curl -s -k -u admin:"$OPENSEARCH_PASSWORD" \
  "https://localhost:9200/_snapshot/<repository>/<snapshot>?pretty"

# 2. Confirm the cluster is green — never upgrade a yellow or red cluster.
kubectl exec -it axondb-search-cluster-master-0 -- \
  curl -s -k -u admin:"$OPENSEARCH_PASSWORD" "https://localhost:9200/_cluster/health?pretty"
```

Le rolling update arrête chaque nœud à tour de rôle : la latence des requêtes augmente, et une installation mono-nœud est indisponible pendant toute l'opération. Pour rester sur OpenSearch 3.3.2 tout en récupérant les changements de templates du chart, épinglez explicitement l'ancienne image :

```yaml
image:
  tag: "3.3.2-1.5.0"
```

## Désinstallation

Pour supprimer la base de recherche AxonOps :

```bash
# Uninstall the release
helm uninstall axondb-search

# Optional: Delete PVCs (this will delete all data!)
kubectl delete pvc -l app.kubernetes.io/name=axondb-search
```

**Avertissement :** supprimer les PVC détruit définitivement toutes les données indexées. Assurez-vous d'avoir des sauvegardes ou des snapshots avant de continuer.

## Dépannage

### Problèmes courants

**1. Les pods ne démarrent pas (CrashLoopBackOff)**

Consultez les logs du pod :
```bash
kubectl logs axondb-search-cluster-master-0
```

Causes fréquentes :
- mémoire insuffisante (augmentez `opensearchHeapSize` et `resources.limits.memory`)
- problèmes de provisionnement du stockage (vérifiez l'état des PVC avec `kubectl get pvc`)
- `vm.max_map_count` non défini (activez `sysctlInit.enabled: true`)

**2. Erreur « vm.max_map_count is too low »**

Le moteur de recherche exige un `vm.max_map_count` d'au moins 262144. Deux options :

**Option A : activer sysctlInit dans le chart Helm (exige des conteneurs privilégiés) :**
```yaml
sysctlInit:
  enabled: true
```

**Option B : régler au niveau du nœud (recommandé) :**
```bash
# On each Kubernetes node
sudo sysctl -w vm.max_map_count=262144

# Make it persistent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

**3. Problèmes de stockage**

Vérifiez l'état des PVC :
```bash
kubectl get pvc
kubectl describe pvc axondb-search-cluster-master-axondb-search-cluster-master-0
```

Si un PVC reste Pending :
- vérifiez que la StorageClass existe : `kubectl get storageclass`
- vérifiez que le provisionnement dynamique est activé dans votre cluster
- assurez-vous d'avoir un quota de stockage suffisant

**4. Problèmes de certificats (cert-manager)**

Vérifiez l'état des certificats :
```bash
kubectl get certificate
kubectl describe certificate axondb-search-tls
kubectl get certificaterequest
```

Consultez les logs de cert-manager :
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

**5. Le cluster ne se forme pas (multi-nœuds)**

Si les nœuds ne se découvrent pas :

```bash
# Check all pods are running
kubectl get pods -l app.kubernetes.io/name=axondb-search

# Check service endpoints
kubectl get endpoints axondb-search-cluster-master-headless

# Check logs for discovery issues
kubectl logs axondb-search-cluster-master-0 | grep -i discovery
```

Vérifiez que :
- `singleNode: false` est bien défini
- `masterService` pointe vers le bon nom de service
- les pods peuvent communiquer sur le port 9300 (transport)

**6. Erreurs « connection refused »**

Vérifiez le service :
```bash
kubectl get svc
kubectl describe svc axondb-search-cluster-master
```

Testez la connectivité :
```bash
# Port-forward to access locally
kubectl port-forward svc/axondb-search-cluster-master 9200:9200

# Test the connection
curl -k https://localhost:9200
```

**7. Consommation mémoire élevée ou OOM kills**

Vérifiez la consommation réelle :
```bash
kubectl top pod -l app.kubernetes.io/name=axondb-search
```

Ajustez la taille du heap et les limites mémoire :
```yaml
opensearchHeapSize: "4g"
resources:
  limits:
    memory: 8Gi  # Should be at least 2x heap size
```

**Règles importantes sur la taille du heap :**
- fixez le heap à environ 50 % de la mémoire du conteneur
- ne dépassez jamais 31–32 Go (limite des OOP compressés)
- gardez `requests.memory` et `limits.memory` identiques, pour éviter les OOM

**8. Problèmes de performance**

Pour de meilleures performances :

1. activez un volume de commitlog séparé (si votre configuration le permet)
2. utilisez des storage classes adossées à des SSD
3. augmentez le nombre de réplicas, pour mieux répartir les requêtes
4. surveillez les métriques JVM et ajustez la taille du heap en conséquence

### Obtenir de l'aide

Pour un support complémentaire :
- consultez les logs : `kubectl logs -f axondb-search-cluster-master-0`
- consultez les événements : `kubectl get events --sort-by='.lastTimestamp'`
- décrivez le StatefulSet : `kubectl describe statefulset axondb-search-cluster-master`
- interrogez la santé du cluster via l'API (après un port-forward) :
  ```bash
  curl -k -u admin:password https://localhost:9200/_cluster/health?pretty
  ```
- consultez la documentation AxonOps : <https://docs.axonops.com>
- contactez le support AxonOps : <info@axonops.com>

## Mainteneurs

| Nom | E-mail | URL |
| ---- | ------ | --- |
| AxonOps Team | <info@aoxnops.com> |  |

---

*Généré avec les charts Helm AxonOps*
