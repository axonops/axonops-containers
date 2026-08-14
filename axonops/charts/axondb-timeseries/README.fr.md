# Base de données time-series AxonOps

[English](README.md) | **Français**

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 5.0.5-1.0.0](https://img.shields.io/badge/AppVersion-5.0.5--1.0.0-informational?style=flat-square)

Un chart Helm pour déployer la base de données time-series AxonOps (fondée sur Cassandra) sur Kubernetes. Cette base stocke les métriques et les données de supervision de la plateforme AxonOps.

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
  - [Installation prête pour la production](#installation-prête-pour-la-production)
- [Configuration des sauvegardes](#configuration-des-sauvegardes)
  - [Sauvegardes locales](#sauvegardes-locales)
  - [Sauvegardes distantes (S3)](#sauvegardes-distantes-s3)
  - [Restaurer depuis une sauvegarde](#restaurer-depuis-une-sauvegarde)
- [Gestion externe des secrets (vals-operator)](#gestion-externe-des-secrets-vals-operator)
- [Configuration](#configuration)
- [Mise à jour](#mise-à-jour)
- [Désinstallation](#désinstallation)
- [Dépannage](#dépannage)

## Prérequis

Avant de commencer, assurez-vous de disposer de ce qui suit :

- **Un cluster Kubernetes** : version 1.19 ou ultérieure
- **kubectl** : configuré pour dialoguer avec votre cluster
- **Helm** : version 3.0 ou ultérieure ([guide d'installation](https://helm.sh/docs/intro/install/))
- **Du stockage** : une StorageClass par défaut configurée dans votre cluster, ou une StorageClass dédiée aux volumes persistants
- **Des ressources** : au moins 2 Go de mémoire disponible et 2 cœurs CPU recommandés

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

Le moyen le plus rapide de démarrer avec la base time-series AxonOps :

```bash
# Add the AxonOps Helm repository (if available)
# helm repo add axonops https://axonops.github.io/helm-charts
# helm repo update

# Install with default settings
helm install axondb-timeseries ./axondb-timeseries

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axondb-timeseries
```

Cela déploie une base time-series mono-nœud avec :
- 10 Gi de stockage persistant
- les limites de ressources par défaut
- aucune authentification (développement uniquement)
- aucun chiffrement TLS

## Exemples d'installation

### Installation de base

Installation minimale, adaptée au développement et aux tests :

```bash
helm install axondb-timeseries ./axondb-timeseries \
  --set replicaCount=1
```

Ou créez un fichier `values-basic.yaml` :

```yaml
# values-basic.yaml
replicaCount: 1

# Optional: Increase heap size for better performance
heapSize: 2048M

# Optional: Set resource limits
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

Installez avec le fichier de values :

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-basic.yaml
```

### Installation avec un stockage personnalisé

Configurez le stockage persistant avec une StorageClass et une taille précises :

```yaml
# values-storage.yaml
replicaCount: 1

persistence:
  enabled: true
  data:
    # Use your cluster's StorageClass (e.g., gp3, standard, fast-ssd)
    storageClass: "gp3"
    size: 50Gi
    accessMode: ReadWriteOnce

  # Optional: Separate commitlog volume for better I/O performance
  commitlog:
    enabled: true
    storageClass: "fast-ssd"  # Use SSD for commitlog
    size: 10Gi
    accessMode: ReadWriteOnce
```

Installation :

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-storage.yaml
```

### Installation avec authentification

Protégez votre base avec des identifiants :

**Option 1 : valeurs directes (développement uniquement)**

```yaml
# values-auth.yaml
replicaCount: 1

authentication:
  db_user: "axonops"
  db_password: "your-secure-password"
```

**Option 2 : secrets Kubernetes (recommandé en production)**

Créez d'abord un secret Kubernetes :

```bash
kubectl create secret generic axondb-credentials \
  --from-literal=AXONOPS_DB_USER=axonops \
  --from-literal=AXONOPS_DB_PASSWORD=your-secure-password
```

Créez ensuite votre fichier de values :

```yaml
# values-auth-secret.yaml
replicaCount: 1

authentication:
  db_secret: "axondb-credentials"
```

Installation :

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-auth-secret.yaml
```

### Installation avec TLS (certificats manuels)

Utilisez des certificats TLS existants pour chiffrer les communications :

**Étape 1 : créer un secret contenant vos certificats**

```bash
kubectl create secret generic axondb-tls-manual \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key \
  --from-file=ca.crt=path/to/ca.crt \
  --from-file=keystore.jks=path/to/keystore.jks \
  --from-file=truststore.jks=path/to/truststore.jks \
  --from-literal=keystore-password=your-keystore-password \
  --from-literal=truststore-password=your-truststore-password
```

**Étape 2 : créer votre fichier de values**

```yaml
# values-tls-manual.yaml
replicaCount: 1

tls:
  enabled: true
  manual:
    existingSecret: "axondb-tls-manual"

  cassandra:
    # Configure internode (node-to-node) encryption
    internode:
      encryption: "all"          # Options: none, dc, rack, all
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"
```

Installation :

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-tls-manual.yaml
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
replicaCount: 1

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
      secretName: "axondb-timeseries-tls-cert"

  cassandra:
    internode:
      encryption: "all"
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"
```

**Avec un issuer existant (production) :**

```yaml
# values-tls-certmanager-production.yaml
replicaCount: 1

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
      commonName: "axondb.example.com"
      dnsNames:
        - "axondb.example.com"
        - "*.axondb.example.com"
      duration: 2160h  # 90 days
      renewBefore: 360h  # 15 days
      secretName: "axondb-timeseries-tls-cert"

  cassandra:
    internode:
      encryption: "all"
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"
```

Installation :

```bash
# For self-signed certificates
helm install axondb-timeseries ./axondb-timeseries -f values-tls-certmanager-selfsigned.yaml

# OR for production with existing issuer
helm install axondb-timeseries ./axondb-timeseries -f values-tls-certmanager-production.yaml
```

**Vérifier la création du certificat :**

```bash
kubectl get certificate
kubectl describe certificate axondb-timeseries-tls
```

### Installation prête pour la production

Une configuration de production complète, avec tous les réglages recommandés :

```yaml
# values-production.yaml
# Production configuration for AxonOps Timeseries Database

# Run at least 3 nodes for high availability
replicaCount: 3

image:
  repository: ghcr.io/axonops/axondb-timeseries
  pullPolicy: IfNotPresent
  tag: ""  # Uses chart appVersion

# Increase heap size for production workloads
heapSize: 8192M

# Authentication using Kubernetes secrets
authentication:
  db_secret: "axondb-credentials"

# Resource limits for production
resources:
  requests:
    cpu: 2000m
    memory: 10Gi
  limits:
    cpu: 4000m
    memory: 16Gi

# Persistent storage configuration
persistence:
  enabled: true
  data:
    storageClass: "gp3"
    size: 100Gi
    accessMode: ReadWriteOnce
  commitlog:
    enabled: true
    storageClass: "fast-ssd"
    size: 20Gi
    accessMode: ReadWriteOnce

# TLS encryption with cert-manager
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
      commonName: "axondb.prod.example.com"
      dnsNames:
        - "axondb.prod.example.com"
        - "*.axondb.prod.example.com"
      duration: 2160h
      renewBefore: 360h
  cassandra:
    internode:
      encryption: "all"
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"

# Health check probes
livenessProbe:
  enabled: true
  initialDelaySeconds: 90
  periodSeconds: 30
  timeoutSeconds: 30
  failureThreshold: 5

readinessProbe:
  enabled: true
  initialDelaySeconds: 90
  periodSeconds: 10
  timeoutSeconds: 30
  failureThreshold: 5

# Pod security context
podSecurityContext:
  fsGroup: 999

securityContext:
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 999

# Service configuration
service:
  type: ClusterIP
  port: 9042

# Enable Prometheus monitoring
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
  labels:
    prometheus: kube-prometheus

# Pod placement rules
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
                - axondb-timeseries
        topologyKey: kubernetes.io/hostname

# Tolerations for dedicated nodes (optional)
# tolerations:
#   - key: "workload"
#     operator: "Equal"
#     value: "database"
#     effect: "NoSchedule"

# Node selector for dedicated nodes (optional)
# nodeSelector:
#   workload: database
```

**Avant l'installation, créez le secret d'authentification :**

```bash
kubectl create secret generic axondb-credentials \
  --from-literal=AXONOPS_DB_USER=axonops \
  --from-literal=AXONOPS_DB_PASSWORD=$(openssl rand -base64 32)
```

**Installer le déploiement de production :**

```bash
helm install axondb-timeseries ./axondb-timeseries \
  -f values-production.yaml \
  --namespace axonops \
  --create-namespace
```

## Configuration des sauvegardes

Le chart axondb-timeseries embarque une fonctionnalité de sauvegarde complète, fondée sur les snapshots Cassandra avec déduplication par rsync. Les sauvegardes peuvent rester locales ou être synchronisées vers un stockage distant compatible S3.

**Note :** AxonDB Timeseries est conçu pour des déploiements mono-nœud uniquement. Les clusters multi-nœuds ne sont pas pris en charge par les opérations de sauvegarde.

### Sauvegardes locales

Configurer des sauvegardes locales par snapshot, avec déduplication par hardlinks :

```yaml
# values-backup-local.yaml
backups:
  enabled: true

  # Backup volume configuration
  volume:
    size: "50Gi"
    storageClass: ""  # Uses default storage class
    mountPath: /backup

  # Backup schedule (cron format)
  schedule:
    cronSchedule: "0 */4 * * *"  # Every 4 hours
    successfulJobsHistoryLimit: 3
    failedJobsHistoryLimit: 3

  # Backup settings
  settings:
    tagPrefix: "backup"
    retentionHours: 168  # 7 days
    minimumRetentionCount: 3  # Always keep at least 3 backups
    useHardlinks: true  # Enable deduplication
```

Installation :

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-backup-local.yaml
```

### Sauvegardes distantes (S3)

Configurer la synchronisation des sauvegardes vers AWS S3 ou un stockage compatible S3, via rclone :

```yaml
# values-backup-remote.yaml
backups:
  enabled: true

  volume:
    size: "50Gi"

  schedule:
    cronSchedule: "0 */4 * * *"

  settings:
    retentionHours: 168
    useHardlinks: true

  # Remote sync configuration
  remote:
    enabled: true
    syncIntervalSeconds: 3600  # Sync to remote every hour
    initialDelaySeconds: 300   # Wait 5 minutes before first sync

    # Remote storage path (rclone format)
    name: "s3"  # rclone remote name
    path: "my-bucket/cassandra-backups"

    # Retention in remote storage
    retentionDays: "30"

    # Authentication via Kubernetes secret
    authMethod: "env"
    secretName: "backup-s3-credentials"

    # Resource limits for rclone sidecar
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

Créez le secret contenant les identifiants S3 :

```bash
kubectl create secret generic backup-s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE \
  --from-literal=AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  --from-literal=AWS_DEFAULT_REGION=us-east-1
```

Pour un stockage compatible S3 (MinIO, Ceph), ajoutez la configuration de l'endpoint :

```bash
kubectl create secret generic backup-s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=minioadmin \
  --from-literal=AWS_SECRET_ACCESS_KEY=minioadmin \
  --from-literal=AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000
```

### Restaurer depuis une sauvegarde

Pour restaurer une sauvegarde distante à l'initialisation du pod :

```yaml
# values-restore.yaml
# Restore from the latest backup
restoreFromBackup: "latest"

# Or restore from a specific backup
# restoreFromBackup: "backup-20260114-102241"

backups:
  enabled: true
  remote:
    enabled: true
    name: "s3"
    path: "my-bucket/cassandra-backups"
    secretName: "backup-s3-credentials"
```

Installer avec restauration :

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-restore.yaml
```

**Important :** le processus de restauration télécharge la sauvegarde indiquée depuis le stockage distant et la restaure avant le démarrage de Cassandra.

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

  # Database authentication from external secret store
  authentication:
    # AWS Secrets Manager example
    db_user: "ref+awssecrets://axonops/timeseries#username"
    db_password: "ref+awssecrets://axonops/timeseries#password"

    # HashiCorp Vault example
    # db_user: "ref+vault://secret/data/axonops/timeseries#username"
    # db_password: "ref+vault://secret/data/axonops/timeseries#password"

  # TLS keystore password (if using TLS)
  tls:
    keystorePassword: "ref+awssecrets://axonops/tls#keystore-password"

  # Remote backup credentials
  backup:
    awsAccessKeyId: "ref+awssecrets://axonops/backup#access-key-id"
    awsSecretAccessKey: "ref+awssecrets://axonops/backup#secret-access-key"
```

Installation :

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-vals.yaml
```

Lorsque vals-operator est activé, une ressource `ValsSecret` est créée ; vals-operator la réconcilie en un Secret Kubernetes standard. L'intégration avec les coffres externes se fait ainsi de façon transparente.

## Configuration

### Principales options de configuration

| Paramètre | Description | Défaut |
|-----------|-------------|---------|
| `replicaCount` | Nombre de réplicas de la base | `1` |
| `heapSize` | Taille du heap JVM de Cassandra | `1024M` |
| `image.repository` | Dépôt de l'image de conteneur | `ghcr.io/axonops/axondb-timeseries` |
| `image.tag` | Tag de l'image de conteneur | `""` (utilise appVersion) |
| `authentication.db_user` | Nom d'utilisateur de la base (dev uniquement) | `""` |
| `authentication.db_password` | Mot de passe de la base (dev uniquement) | `""` |
| `authentication.db_secret` | Nom du secret Kubernetes portant les identifiants | `""` |
| `persistence.enabled` | Activer le stockage persistant | `true` |
| `persistence.data.size` | Taille du volume de données | `10Gi` |
| `persistence.data.storageClass` | StorageClass du volume de données | `""` (défaut) |
| `persistence.commitlog.enabled` | Activer un volume séparé pour le commitlog | `false` |
| `tls.enabled` | Activer le chiffrement TLS/SSL | `false` |
| `tls.certManager.enabled` | Utiliser cert-manager pour les certificats | `false` |
| `resources.requests.memory` | Requête mémoire | `nil` |
| `resources.limits.memory` | Limite mémoire | `nil` |

### Référence complète des values

<details>
<summary>Cliquez pour dérouler le tableau complet des values</summary>

| Clé | Type | Défaut | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Règles d'affinité de pods pour l'ordonnancement |
| authentication.db_password | string | `""` | Mot de passe de la base (en clair — dev uniquement) |
| authentication.db_secret | string | `""` | Nom du secret Kubernetes contenant AXONOPS_DB_USER et AXONOPS_DB_PASSWORD |
| authentication.db_user | string | `""` | Nom d'utilisateur de la base (en clair — dev uniquement) |
| envVars | list | `[]` | Variables d'environnement supplémentaires, sous forme de liste |
| envVarsSecret | string | `""` | Nom d'un secret contenant des variables d'environnement |
| extraVolumeMounts | list | `[]` | Montages de volumes supplémentaires du pod |
| extraVolumes | list | `[]` | Volumes supplémentaires du pod |
| fullnameOverride | string | `""` | Remplacer le nom complet des ressources |
| heapSize | string | `"1024M"` | Taille du heap JVM (par exemple 1024M, 8G) |
| image.pullPolicy | string | `"IfNotPresent"` | Politique de pull de l'image |
| image.repository | string | `"ghcr.io/axonops/axondb-timeseries"` | Dépôt de l'image de conteneur |
| image.tag | string | `""` | Tag de l'image (par défaut, l'appVersion du chart) |
| imagePullSecrets | list | `[]` | Secrets de pull d'image pour les registres privés |
| livenessProbe.enabled | bool | `true` | Activer la sonde de liveness |
| livenessProbe.failureThreshold | int | `5` | Seuil d'échec de la sonde de liveness |
| livenessProbe.initialDelaySeconds | int | `60` | Délai avant le premier contrôle de liveness |
| livenessProbe.periodSeconds | int | `30` | Fréquence du contrôle |
| livenessProbe.successThreshold | int | `1` | Seuil de succès de la sonde de liveness |
| livenessProbe.timeoutSeconds | int | `30` | Délai d'expiration de la sonde de liveness |
| nameOverride | string | `""` | Remplacer le nom du chart |
| nodeSelector | object | `{}` | Labels de nœud pour l'affectation des pods |
| persistence.commitlog.accessMode | string | `"ReadWriteOnce"` | Mode d'accès du volume de commitlog |
| persistence.commitlog.annotations | object | `{}` | Annotations du PVC de commitlog |
| persistence.commitlog.enabled | bool | `false` | Activer un volume séparé pour le commitlog |
| persistence.commitlog.mountPath | string | `"/var/lib/cassandra/commitlog"` | Point de montage du commitlog |
| persistence.commitlog.size | string | `"5Gi"` | Taille du volume de commitlog |
| persistence.commitlog.storageClass | string | `""` | StorageClass du commitlog |
| persistence.data.accessMode | string | `"ReadWriteOnce"` | Mode d'accès du volume de données |
| persistence.data.annotations | object | `{}` | Annotations du PVC de données |
| persistence.data.mountPath | string | `"/var/lib/cassandra"` | Point de montage des données |
| persistence.data.size | string | `"10Gi"` | Taille du volume de données |
| persistence.data.storageClass | string | `""` | StorageClass du volume de données |
| persistence.enabled | bool | `true` | Activer le stockage persistant |
| podAnnotations | object | `{}` | Annotations des pods |
| podLabels | object | `{}` | Labels supplémentaires des pods |
| podSecurityContext.fsGroup | int | `999` | FSGroup du contexte de sécurité du pod |
| readinessProbe.enabled | bool | `true` | Activer la sonde de readiness |
| readinessProbe.failureThreshold | int | `5` | Seuil d'échec de la sonde de readiness |
| readinessProbe.initialDelaySeconds | int | `60` | Délai avant le premier contrôle de readiness |
| readinessProbe.periodSeconds | int | `10` | Fréquence du contrôle |
| readinessProbe.successThreshold | int | `1` | Seuil de succès de la sonde de readiness |
| readinessProbe.timeoutSeconds | int | `30` | Délai d'expiration de la sonde de readiness |
| replicaCount | int | `1` | Nombre de réplicas |
| resources | object | `{}` | Requêtes et limites de CPU / mémoire |
| securityContext.readOnlyRootFilesystem | bool | `false` | Monter le système de fichiers racine en lecture seule |
| securityContext.runAsNonRoot | bool | `true` | Exécuter le conteneur sous un utilisateur non root |
| securityContext.runAsUser | int | `999` | UID d'exécution du conteneur |
| service.port | int | `9042` | Port du service CQL |
| service.type | string | `"ClusterIP"` | Type de service Kubernetes |
| serviceAccount.annotations | object | `{}` | Annotations du service account |
| serviceAccount.automount | bool | `true` | Monter automatiquement le token du service account |
| serviceAccount.create | bool | `true` | Créer le service account |
| serviceAccount.name | string | `""` | Nom du service account |
| serviceMonitor.annotations | object | `{}` | Annotations du ServiceMonitor |
| serviceMonitor.enabled | bool | `false` | Activer le ServiceMonitor Prometheus |
| serviceMonitor.interval | string | `"30s"` | Intervalle de scrape |
| serviceMonitor.labels | object | `{}` | Labels supplémentaires du ServiceMonitor |
| serviceMonitor.metricRelabelings | list | `[]` | Configuration de relabeling des métriques |
| serviceMonitor.port | string | `"jmx"` | Port de collecte des métriques |
| serviceMonitor.relabelings | list | `[]` | Configuration de relabeling |
| serviceMonitor.scrapeTimeout | string | `"10s"` | Délai d'expiration du scrape |
| serviceMonitor.selector | object | `{}` | Labels de sélection supplémentaires |
| tls.cassandra.internode.acceptedProtocols | string | `"TLSv1.2,TLSv1.3"` | Protocoles TLS acceptés entre nœuds |
| tls.cassandra.internode.cipherSuites | list | `[]` | Suites de chiffrement du trafic entre nœuds |
| tls.cassandra.internode.encryption | string | `"all"` | Chiffrement entre nœuds : none, dc, rack, all |
| tls.cassandra.internode.protocol | string | `"TLS"` | Version du protocole TLS |
| tls.certManager.certificate.commonName | string | `""` | Common name du certificat |
| tls.certManager.certificate.dnsNames | list | `[]` | SAN DNS du certificat |
| tls.certManager.certificate.duration | string | `"43800h"` | Durée de validité du certificat |
| tls.certManager.certificate.ipAddresses | list | `[]` | SAN IP du certificat |
| tls.certManager.certificate.renewBefore | string | `"720h"` | Délai de renouvellement avant expiration |
| tls.certManager.certificate.secretName | string | `"axondb-timeseries-tls-cert"` | Nom du secret portant le certificat |
| tls.certManager.enabled | bool | `false` | Activer cert-manager pour TLS |
| tls.certManager.issuer.createSelfSigned | bool | `true` | Créer un issuer auto-signé |
| tls.certManager.issuer.kind | string | `"ClusterIssuer"` | Type d'issuer : Issuer ou ClusterIssuer |
| tls.certManager.issuer.name | string | `""` | Nom d'un issuer existant |
| tls.certManager.keystorePassword | string | `"changeme"` | Mot de passe du keystore des fichiers JKS |
| tls.enabled | bool | `false` | Activer TLS/SSL |
| tls.manual.existingSecret | string | `""` | Secret existant contenant des certificats fournis manuellement |
| tolerations | list | `[]` | Tolerations pour l'affectation des pods |

</details>

## Mise à jour

Pour mettre à jour une installation existante :

```bash
# Update the chart
helm upgrade axondb-timeseries ./axondb-timeseries -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axondb-timeseries
```

## Désinstallation

Pour supprimer la base time-series AxonOps :

```bash
# Uninstall the release
helm uninstall axondb-timeseries

# Optional: Delete PVCs (this will delete all data!)
kubectl delete pvc -l app.kubernetes.io/name=axondb-timeseries
```

**Avertissement :** supprimer les PVC détruit définitivement toutes les données de la base. Assurez-vous d'avoir des sauvegardes avant de continuer.

## Dépannage

### Problèmes courants

**1. Les pods ne démarrent pas (CrashLoopBackOff)**

Consultez les logs du pod :
```bash
kubectl logs axondb-timeseries-0
```

Causes fréquentes :
- mémoire insuffisante (augmentez `heapSize` et `resources.limits.memory`)
- problèmes de provisionnement du stockage (vérifiez l'état des PVC avec `kubectl get pvc`)
- erreurs de configuration (relisez votre fichier de values)

**2. Problèmes de stockage**

Vérifiez l'état des PVC :
```bash
kubectl get pvc
kubectl describe pvc data-axondb-timeseries-0
```

Si un PVC reste Pending :
- vérifiez que la StorageClass existe : `kubectl get storageclass`
- vérifiez que le provisionnement dynamique est activé dans votre cluster

**3. Problèmes de certificats (cert-manager)**

Vérifiez l'état des certificats :
```bash
kubectl get certificate
kubectl describe certificate axondb-timeseries-tls
kubectl get certificaterequest
```

Consultez les logs de cert-manager :
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

**4. Erreurs « connection refused »**

Vérifiez le service :
```bash
kubectl get svc axondb-timeseries
kubectl describe svc axondb-timeseries
```

Testez la connectivité depuis un autre pod :
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  telnet axondb-timeseries 9042
```

**5. Consommation mémoire élevée**

Vérifiez la consommation réelle :
```bash
kubectl top pod axondb-timeseries-0
```

Ajustez la taille du heap (environ 50 % de la mémoire du conteneur) :
```yaml
heapSize: 4096M
resources:
  limits:
    memory: 8Gi
```

### Obtenir de l'aide

Pour un support complémentaire :
- consultez les logs : `kubectl logs -f axondb-timeseries-0`
- consultez les événements : `kubectl get events --sort-by='.lastTimestamp'`
- décrivez le StatefulSet : `kubectl describe statefulset axondb-timeseries`
- consultez la documentation AxonOps : <https://docs.axonops.com>
- contactez le support AxonOps : <info@axonops.com>

## Mainteneurs

| Nom | E-mail | URL |
| ---- | ------ | --- |
| AxonOps Team | <info@aoxnops.com> |  |

---

*Généré avec les charts Helm AxonOps*
