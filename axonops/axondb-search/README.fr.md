# Base de recherche AxonDB

[English](README.md) | **Français**

[![Paquet GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axondb-search)

Conteneur OpenSearch 3.3.2 prêt pour la production, optimisé pour les charges de recherche des déploiements AxonOps auto-hébergés.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Images Docker préconstruites](#images-docker-préconstruites)
  - [Images disponibles](#images-disponibles)
  - [Stratégie de tags](#stratégie-de-tags)
- [Bonne pratique de production](#bonne-pratique-de-production)
- [Déploiement](#déploiement)
  - [Prérequis de déploiement Kubernetes](#prérequis-de-déploiement-kubernetes)
- [Construire les images Docker](#construire-les-images-docker)
- [Variables d'environnement](#variables-denvironnement)
- [Fonctionnalités du conteneur](#fonctionnalités-du-conteneur)
  - [Script d'entrypoint](#script-dentrypoint)
  - [Bannière de version au démarrage](#bannière-de-version-au-démarrage)
  - [Sondes de healthcheck](#sondes-de-healthcheck)
  - [Sécurité et gestion des certificats](#sécurité-et-gestion-des-certificats)
  - [Initialisation automatisée (configuration de sécurité et utilisateur admin)](#initialisation-automatisée-configuration-de-sécurité-et-utilisateur-admin)
- [Fichiers de configuration](#fichiers-de-configuration)
- [Pipeline CI/CD](#pipeline-cicd)
  - [Workflows](#workflows)
  - [Tests automatisés](#tests-automatisés)
  - [Processus de publication](#processus-de-publication)
- [Dépannage](#dépannage)
  - [Vérifier la version du conteneur](#vérifier-la-version-du-conteneur)
  - [Logs du script d'initialisation](#logs-du-script-dinitialisation)
  - [Déboguer le healthcheck](#déboguer-le-healthcheck)
  - [Le conteneur ne démarre pas](#le-conteneur-ne-démarre-pas)
- [Considérations de production](#considérations-de-production)

## Vue d'ensemble

AxonDB Search est un conteneur OpenSearch prêt pour la production, conçu spécifiquement pour les déploiements AxonOps auto-hébergés. Il est optimisé pour les charges de base de recherche et se déploie dans le cadre de la stack AxonOps complète, via les charts Helm AxonOps.

**Fonctionnalités du conteneur :**
- **Moteur de recherche moderne** : OpenSearch 3.3.2, avec recherche plein texte, analytique et visualisation
- **Sécurité de production** : certificats TLS aux couleurs d'AxonOps (RSA 3072, et non des certificats de démonstration)
- **Mise en place automatisée** : plugin de sécurité préconfiguré, avec création optionnelle d'un utilisateur admin personnalisé
- **Base entreprise** : construit sur Red Hat UBI 9 minimal, pour la stabilité en production
- **Sécurité de la chaîne d'approvisionnement** : images de base épinglées par digest, pour des builds immuables
- **Supervision de production** : sondes de healthcheck intégrées (startup, liveness, readiness)

**Important :** ce conteneur est destiné exclusivement aux déploiements AxonOps auto-hébergés. Il est déployé et configuré via les charts Helm AxonOps, qui prennent en charge l'orchestration, le réseau et l'intégration avec la plateforme de supervision et de gestion AxonOps. Pour en savoir plus sur AxonOps, voir [axonops.com](https://axonops.com).

## Images Docker préconstruites

Des images préconstruites sont disponibles sur le GitHub Container Registry (GHCR). C'est la façon la plus simple de démarrer.

### Images disponibles

Toutes les images sont disponibles à l'adresse : `ghcr.io/axonops/axondb-search`

Parcourir tous les tags disponibles : [GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axondb-search)

### Stratégie de tags

Les images suivent une stratégie de tags à deux dimensions :

| Forme du tag | Exemple | Description | Cas d'usage |
|-------------|---------|-------------|----------|
| `{OPENSEARCH}-{AXON}` | `3.3.2-1.0.0` | Totalement immuable (version d'OpenSearch + version AxonOps) | **Production** : épingler les versions exactes pour une traçabilité complète |
| `@sha256:<digest>` | `@sha256:abc123...` | Fondé sur le digest (immuable cryptographiquement) | **Sécurité maximale** : intégrité de l'image garantie |
| `{OPENSEARCH}` | `3.3.2` | Dernier AxonOps pour cette version d'OpenSearch | Suivre les mises à jour d'AxonOps pour une version d'OpenSearch donnée |
| `latest` | `latest` | La plus récente, toutes versions confondues | Essais rapides uniquement (PAS pour la production) |

**Dimensions de versionnage :**
- **OPENSEARCH** — version d'OpenSearch (par exemple 3.3.2)
- **AXON** — version du conteneur AxonOps (par exemple 1.0.0, en SemVer)

**Exemples de tags :**

Lorsque `3.3.2-1.0.0` est construit (et qu'il est le plus récent) :
- `3.3.2-1.0.0` (immuable — ne change jamais)
- `3.3.2` (flottant — se déplace vers les builds AxonOps plus récents)
- `latest` (flottant — se déplace vers les versions d'OpenSearch plus récentes)

## 💡 Bonne pratique de production

⚠️ **Utiliser `latest` ou des tags flottants en production est un anti-pattern**. Cela vaut pour `latest` comme pour `3.3.2`, parce que :
- **Aucune traçabilité** : impossible de déterminer la version exacte déployée à un instant donné
- **Mises à jour inattendues** : les orchestrateurs de conteneurs peuvent tirer de nouvelles images lors d'un redémarrage
- **Retours arrière difficiles** : impossible de revenir de façon fiable à une version antérieure
- **Problèmes de conformité** : de nombreux référentiels exigent un suivi de version immuable

👍 **Stratégies de déploiement recommandées (par ordre de sécurité) :**

1. **🥇 Référence absolue — par digest** (sécurité maximale)
   ```bash
   docker pull ghcr.io/axonops/axondb-search@sha256:abc123...
   ```
   - immuable à 100 %, garanti cryptographiquement
   - requis dans les environnements réglementés
   - vérifiez la signature avec Cosign (voir [Sécurité](#security))

2. **🥈 Tag immuable** (standard de production)
   ```bash
   docker pull ghcr.io/axonops/axondb-search:3.3.2-1.0.0
   ```
   - épinglé sur une version précise (OpenSearch 3.3.2 + AxonOps 1.0.0)
   - facile à lire et à gérer
   - traçabilité complète conservée

3. **🥉 Tags flottants** (développement / test uniquement)
   ```bash
   docker pull ghcr.io/axonops/axondb-search:latest
   ```
   - itération rapide
   - PAS pour la production
   - à réserver aux POC et aux tests

**Note de sécurité :** toutes les images de production sont signées cryptographiquement avec Sigstore Cosign en mode keyless. Vérifiez les signatures avant tout déploiement :

```bash
# Install cosign
# macOS: brew install cosign
# Linux: https://docs.sigstore.dev/cosign/installation

# Verify signature
cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Check signature exists
cosign tree ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

## Déploiement

Ce conteneur se déploie exclusivement via les **charts Helm AxonOps**, dans le cadre de la stack AxonOps auto-hébergée. Les charts Helm prennent en charge toute la configuration, l'orchestration et l'intégration avec les composants de supervision et de gestion AxonOps.

Pour les instructions de déploiement, reportez-vous à la documentation de déploiement AxonOps auto-hébergé (disponible à la publication des charts Helm).

### Prérequis de déploiement Kubernetes

**Prérequis CRITIQUES pour les déploiements Kubernetes :**

OpenSearch exige des réglages système précis sur les nœuds Kubernetes, ainsi que des contextes de sécurité de pod adaptés. Ces réglages sont obligatoires en production.

#### 1. Configuration au niveau du nœud (vm.max_map_count)

OpenSearch utilise un répertoire mmapfs pour stocker les index. Les limites par défaut du système d'exploitation sur le nombre de mmap sont généralement trop basses, ce qui peut provoquer des erreurs de mémoire insuffisante.

**Exigence : `vm.max_map_count` >= 262144 sur TOUS les nœuds Kubernetes**

```bash
# Check current value on node
sysctl vm.max_map_count

# Set permanently on each Kubernetes node
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# OR use a DaemonSet to set on all nodes automatically
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: opensearch-sysctl
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: opensearch-sysctl
  template:
    metadata:
      labels:
        name: opensearch-sysctl
    spec:
      hostNetwork: true
      hostPID: true
      initContainers:
      - name: sysctl
        image: busybox
        command: ['sh', '-c', 'sysctl -w vm.max_map_count=262144']
        securityContext:
          privileged: true
      containers:
      - name: pause
        image: gcr.io/google_containers/pause
EOF
```

#### 2. Contexte de sécurité du pod (ulimits et capabilities)

**Exigence : `ulimits.nofile` (nombre maximal de descripteurs de fichiers) >= 65536**

OpenSearch a besoin d'un grand nombre de descripteurs de fichiers. Par ailleurs, `bootstrap.memory_lock: true` (configuré dans `opensearch.yml`) exige la capability `IPC_LOCK`, afin d'empêcher le swap de la mémoire.

**Configuration de sécurité complète du pod :**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: axondb-search
spec:
  # Enable IPC_LOCK capability for bootstrap.memory_lock
  securityContext:
    capabilities:
      add:
        - IPC_LOCK
    # Memory lock requires memlock=-1 (unlimited)
    # This is handled by the IPC_LOCK capability in Kubernetes

  containers:
  - name: opensearch
    image: ghcr.io/axonops/axondb-search:3.3.2-1.0.0

    # CRITICAL: Set resource limits
    resources:
      requests:
        memory: "12Gi"  # 1.5x heap size (8G default)
        cpu: "4"
      limits:
        memory: "16Gi"
        cpu: "8"

    # CRITICAL: Set ulimits via securityContext
    securityContext:
      # OpenSearch runs as UID 999 (opensearch user)
      runAsUser: 999
      runAsGroup: 999
      # Allow memory locking (for bootstrap.memory_lock)
      capabilities:
        add:
          - IPC_LOCK
      # Set nofile (max open files) to 65536
      # Note: In Kubernetes, this is set via container securityContext
      # The actual ulimit is controlled by the container runtime
      # For containerd/CRI-O, set limits in container runtime config
      allowPrivilegeEscalation: false

    env:
    # Heap size (default: 8g)
    - name: OPENSEARCH_HEAP_SIZE
      value: "8g"

    # Custom admin user (optional but recommended)
    - name: AXONOPS_SEARCH_USER
      value: "dbadmin"
    - name: AXONOPS_SEARCH_PASSWORD
      valueFrom:
        secretKeyRef:
          name: opensearch-credentials
          key: admin-password

    # TLS enabled (default: true)
    - name: AXONOPS_SEARCH_TLS_ENABLED
      value: "true"

    # Cluster configuration
    - name: OPENSEARCH_CLUSTER_NAME
      value: "axonops-production"
    - name: OPENSEARCH_NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name

    # Volume mounts
    volumeMounts:
    - name: data
      mountPath: /var/lib/opensearch
    - name: logs
      mountPath: /var/log/opensearch

    # Healthcheck probes
    startupProbe:
      exec:
        command:
          - /usr/local/bin/healthcheck.sh
          - startup
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 10
      failureThreshold: 30  # 5 minutes max startup time

    livenessProbe:
      exec:
        command:
          - /usr/local/bin/healthcheck.sh
          - liveness
      initialDelaySeconds: 60
      periodSeconds: 10
      timeoutSeconds: 10
      failureThreshold: 3

    readinessProbe:
      exec:
        command:
          - /usr/local/bin/healthcheck.sh
          - readiness
      initialDelaySeconds: 60
      periodSeconds: 10
      timeoutSeconds: 10
      failureThreshold: 3

  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: opensearch-data
  - name: logs
    emptyDir: {}
```

**Exemple de StatefulSet (clusters de production) :**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: axondb-search
spec:
  serviceName: axondb-search
  replicas: 3
  selector:
    matchLabels:
      app: axondb-search
  template:
    metadata:
      labels:
        app: axondb-search
    spec:
      # Anti-affinity to spread pods across nodes
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: axondb-search
            topologyKey: kubernetes.io/hostname

      # Init container to set ulimits (if container runtime doesn't support it)
      initContainers:
      - name: increase-ulimit
        image: busybox
        command:
          - sh
          - -c
          - ulimit -n 65536
        securityContext:
          privileged: true

      # OpenSearch container (see Pod example above for full configuration)
      containers:
      - name: opensearch
        image: ghcr.io/axonops/axondb-search:3.3.2-1.0.0
        # ... (rest of container config from Pod example)

  # Persistent volume claim template
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 500Gi
```

**Points importants :**
- **vm.max_map_count** : doit être défini sur TOUS les nœuds Kubernetes (pas seulement sur le pod)
- **ulimits.nofile** : à définir via le `securityContext` ou un init container
- **IPC_LOCK** : nécessaire pour `bootstrap.memory_lock: true` (empêche le swap)
- **Volumes persistants** : utilisez du stockage SSD avec des IOPS suffisantes en production
- **Mémoire** : allouez au moins 1,5 fois la taille du heap (par exemple 12 Gi pour un heap de 8 Go)

## Construire les images Docker

Si vous préférez construire les images vous-même plutôt que d'utiliser les images préconstruites :

```bash
cd axonops/axondb-search/opensearch/3.3.2

# Minimal build (required args only)
docker build \
  --build-arg OPENSEARCH_VERSION=3.3.2 \
  -t axondb-search:3.3.2-1.0.0 \
  .

# Multi-arch build (amd64 + arm64) using buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg OPENSEARCH_VERSION=3.3.2 \
  -t axondb-search:3.3.2-1.0.0 \
  .
```

**Arguments de build obligatoires :**
- `OPENSEARCH_VERSION` — version d'OpenSearch (par exemple 3.3.2)

**Arguments de build optionnels (ils enrichissent les métadonnées mais ne sont pas obligatoires) :**
- `BUILD_DATE` — horodatage du build (format ISO 8601, par exemple `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF` — SHA du commit Git (par exemple `$(git rev-parse HEAD)`)
- `VERSION` — version du conteneur (par exemple 1.0.0)
- `GIT_TAG` — nom du tag Git (pour les liens de release / tag de la bannière)
- `GITHUB_ACTOR` — utilisateur ayant déclenché le build (pour la traçabilité)
- `IS_PRODUCTION_RELEASE` — mettre à `true` pour la production (défaut : `false`)
- `IMAGE_FULL_NAME` — nom complet de l'image avec son tag (affiché dans la bannière de démarrage)

**Sécurité de la chaîne d'approvisionnement :**

Notre Dockerfile utilise des images de base épinglées par digest, pour la sécurité de la chaîne d'approvisionnement :

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
ARG UBI9_MINIMAL_DIGEST=sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2
FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
```

**Pourquoi l'épinglage par digest compte :**
- un tag peut être remplacé de façon malveillante (même tag, image différente)
- un digest est cryptographiquement immuable — il ne peut pas changer
- cela prévient une compromission silencieuse de votre chaîne d'approvisionnement de conteneurs
- c'est la bonne pratique du secteur pour les builds de production

## Variables d'environnement

Le conteneur accepte 18 variables d'environnement de configuration :

| Variable | Description | Défaut | Catégorie |
|----------|-------------|---------|----------|
| `OPENSEARCH_CLUSTER_NAME` | Nom du cluster | `axonopsdb-search` | Configuration OpenSearch |
| `OPENSEARCH_NODE_NAME` | Nom du nœud | `${HOSTNAME}` | Configuration OpenSearch |
| `OPENSEARCH_NETWORK_HOST` | Adresse d'écoute réseau | `0.0.0.0` | Configuration OpenSearch |
| `OPENSEARCH_DISCOVERY_TYPE` | Type de découverte du cluster (`single-node` ou multi-nœuds) | `single-node` | Configuration OpenSearch |
| `OPENSEARCH_HEAP_SIZE` | Taille du heap JVM (-Xms et -Xmx) | `8g` | Configuration OpenSearch |
| `OPENSEARCH_HTTP_PORT` | Port de l'API HTTP | `9200` | Configuration OpenSearch |
| `OPENSEARCH_DATA_DIR` | Chemin du répertoire de données | `/var/lib/opensearch` | Configuration OpenSearch |
| `OPENSEARCH_LOG_DIR` | Chemin du répertoire de logs | `/var/log/opensearch` | Configuration OpenSearch |
| `OPENSEARCH_PATH_CONF` | Chemin du répertoire de configuration | `/etc/opensearch` | Configuration OpenSearch |
| `AXONOPS_SEARCH_USER` | Créer un utilisateur admin personnalisé portant ce nom (remplace l'admin par défaut) | - | Sécurité et init |
| `AXONOPS_SEARCH_PASSWORD` | Mot de passe de l'admin personnalisé (obligatoire si `AXONOPS_SEARCH_USER` est défini) | - | Sécurité et init |
| `AXONOPS_SEARCH_TLS_ENABLED` | Activer HTTPS sur l'API REST (mettre `false` si le LB termine le TLS) | `true` | Sécurité et init |
| `GENERATE_CERTS_ON_STARTUP` | Générer les certificats AxonOps par défaut au démarrage s'ils manquent | `true` | Sécurité et init |
| `OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE` | Taille de la file du thread pool d'écriture (à augmenter pour les charges à forte écriture) | `10000` | Avancé / transport |
| `OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION` | Imposer la vérification du nom d'hôte pour le SSL transport | `false` | Avancé / transport |
| `OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE` | Mode d'authentification client HTTP (`NONE`, `OPTIONAL`, `REQUIRED`) | `NONE` | Avancé / transport |
| `OPENSEARCH_SECURITY_ADMIN_DN` | DN du certificat admin personnalisé (scénarios de certificats personnalisés) | `OU=Database,O=AxonOps,CN=admin.axondbsearch.axonops.com` | Avancé / transport |
| `OPENSEARCH_SECURITY_NODES_DN` | DN des certificats de nœuds pour les communications inter-nœuds (liste séparée par des points-virgules, jokers acceptés) | `CN=*.axonops.svc.cluster.local` | Avancé / transport |
| `DISABLE_SECURITY_PLUGIN` | Désactiver entièrement le plugin de sécurité (DÉCONSEILLÉ en production) | `false` | Contrôle des plugins |
| `DISABLE_PERFORMANCE_ANALYZER_AGENT_CLI` | Désactiver le performance analyzer (AxonOps assure la supervision) | `true` | Contrôle des plugins |

### Configuration OpenSearch

Les 9 premières variables règlent le comportement de base d'OpenSearch. Elles sont traitées par le script d'entrypoint et appliquées aux fichiers de configuration avant le démarrage d'OpenSearch.

**Configuration réseau :**
- `OPENSEARCH_NETWORK_HOST` — mettre `0.0.0.0` pour écouter sur toutes les interfaces
- `OPENSEARCH_HTTP_PORT` — port de l'API REST (9200 par défaut)

**Configuration du cluster :**
- `OPENSEARCH_CLUSTER_NAME` — un nom de cluster explicite
- `OPENSEARCH_NODE_NAME` — vaut le nom d'hôte du pod par défaut, sous Kubernetes
- `OPENSEARCH_DISCOVERY_TYPE` — mettre `single-node` pour un cluster mono-nœud, ou configurer les seed hosts en multi-nœuds

**Configuration des ressources :**
- `OPENSEARCH_HEAP_SIZE` — pilote le heap JVM (-Xms et -Xmx reçoivent la même valeur)
- recommandation : 50 % de la mémoire du conteneur, 32 Go au maximum

**Exemple :**
```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_CLUSTER_NAME=production-search \
  -e OPENSEARCH_NODE_NAME=search-node-01 \
  -e OPENSEARCH_HEAP_SIZE=16g \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=SecurePassword123 \
  -p 9200:9200 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

### Sécurité et contrôle de l'initialisation

**Configuration TLS/SSL :**

Par défaut, le conteneur active HTTPS sur l'API REST, avec des certificats aux couleurs d'AxonOps. Si un répartiteur de charge ou un ingress termine le TLS, vous pouvez désactiver le SSL HTTP :

```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_TLS_ENABLED=false \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Important :** le SSL de la couche transport (communications entre nœuds) reste activé même lorsque le SSL HTTP est désactivé.

**Utilisateur admin personnalisé (modèle de REMPLACEMENT) :**

Le conteneur permet de créer un utilisateur admin personnalisé qui **REMPLACE** l'utilisateur admin par défaut. Cela diffère d'AxonDB Time-Series, qui ajoute un utilisateur : dans OpenSearch, pour des raisons de sécurité, un seul utilisateur admin doit exister.

```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=MySecurePassword123 \
  -p 9200:9200 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Connect with new credentials
curl -k -u dbadmin:MySecurePassword123 https://localhost:9200/_cluster/health
```

**Important :**
- la création de l'utilisateur personnalisé a lieu **avant** le démarrage d'OpenSearch (en amont, pas en arrière-plan)
- l'utilisateur `admin` par défaut est **SUPPRIMÉ** d'`internal_users.yml`
- seul l'utilisateur personnalisé existe (plus d'admin par défaut)
- la création est atomique — elle réussit complètement ou elle est annulée

### Configuration avancée

**Configuration du thread pool :**

Pour les charges à forte écriture, il peut être nécessaire d'agrandir la file du thread pool d'écriture :

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE=20000 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Configuration du SSL transport :**

Pour les clusters multi-nœuds aux exigences de sécurité strictes :

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION=true \
  -e OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE=OPTIONAL \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**DN des certificats de nœuds (sécurité multi-nœuds) :**

Sur un cluster multi-nœuds, indiquez quels Distinguished Names (DN) de certificats sont autorisés pour les communications inter-nœuds. C'est essentiel pour sécuriser la couche transport entre nœuds OpenSearch.

```bash
# Single DN (default)
docker run -d --name axondb-search \
  -e OPENSEARCH_SECURITY_NODES_DN="CN=*.axonops.svc.cluster.local" \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Multiple DNs (semicolon-separated)
docker run -d --name axondb-search \
  -e OPENSEARCH_SECURITY_NODES_DN="CN=*.example.svc.cluster.local;CN=node-1.example.com;CN=node-2.example.com" \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Important :**
- séparez plusieurs DN par des points-virgules (`;`)
- les jokers sont acceptés (par exemple `CN=*.svc.cluster.local`), pratiques pour les noms de pods dynamiques dans Kubernetes
- les espaces autour des DN sont supprimés automatiquement
- seuls les nœuds dont le certificat correspond à ces DN peuvent rejoindre le cluster
- indispensable pour empêcher un nœud non autorisé de rejoindre votre cluster

**Exemple de StatefulSet Kubernetes :**
```yaml
env:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.default.svc.cluster.local;CN=axondb-search-0;CN=axondb-search-1;CN=axondb-search-2"
```

Cette configuration produit ceci dans `opensearch.yml` :
```yaml
plugins.security.nodes_dn:
  - "CN=*.axondb-search.default.svc.cluster.local"
  - "CN=axondb-search-0"
  - "CN=axondb-search-1"
  - "CN=axondb-search-2"
```

## Fonctionnalités du conteneur

### Script d'entrypoint

Le script d'entrypoint (`/usr/local/bin/docker-entrypoint.sh`) est le chef d'orchestre : il configure OpenSearch et pilote le démarrage du conteneur. Il s'exécute en PID 1 via [tini](https://github.com/krallin/tini) et réalise l'initialisation critique avant de lancer OpenSearch.

#### tini — un système d'init minimal

Le conteneur utilise **tini** comme système d'init (PID 1). Tini est un init minimal conçu pour les conteneurs, qui :

- **gère correctement les signaux** — transmet les signaux (SIGTERM, SIGINT) aux processus enfants, pour un arrêt propre
- **récupère les processus zombies** — nettoie les processus enfants terminés, qui s'accumuleraient sinon
- **est extrêmement léger** — un seul binaire statique (environ 10 Ko), négligeable
- **est un standard du secteur** — c'est l'init utilisé par Docker avec l'option `--init`

Le Dockerfile place tini comme wrapper d'entrypoint :
```dockerfile
ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["opensearch"]
```

L'arbre des processus est donc :
```
tini (PID 1)
  └─► docker-entrypoint.sh
       └─► opensearch (after exec)
```

Après `exec opensearch`, OpenSearch remplace le script shell mais tini reste PID 1, ce qui garantit une gestion correcte des signaux pour tout le conteneur.

**En savoir plus :** [github.com/krallin/tini](https://github.com/krallin/tini)

#### Ce qu'il fait

**1. Affiche la bannière de démarrage**
- source les métadonnées de build depuis `/etc/axonops/build-info.txt`
- affiche l'information de version complète (OpenSearch, Java, OS)
- indique l'environnement d'exécution (détection de Kubernetes, nom d'hôte)
- affiche les informations de chaîne d'approvisionnement (digest de l'image de base)

**2. Définit les variables d'environnement par défaut**
- `OPENSEARCH_CLUSTER_NAME` (défaut : `axonopsdb-search`)
- `OPENSEARCH_NODE_NAME` (défaut : le nom d'hôte)
- `OPENSEARCH_NETWORK_HOST` (défaut : `0.0.0.0`)
- `OPENSEARCH_DISCOVERY_TYPE` (défaut : `single-node`)
- `OPENSEARCH_HEAP_SIZE` (défaut : `8g`)
- `AXONOPS_SEARCH_TLS_ENABLED` (défaut : `true`)

**3. Applique les variables d'environnement à la configuration OpenSearch**
- met à jour `opensearch.yml` avec le nom de cluster, le nom de nœud et les réglages réseau
- ajuste la taille du heap JVM dans `jvm.options`
- configure le thread pool, les réglages SSL et le DN admin de sécurité
- gère l'activation ou la désactivation du TLS sur la couche HTTP

**4. Crée l'utilisateur admin personnalisé (avant démarrage)**
- si `AXONOPS_SEARCH_USER` et `AXONOPS_SEARCH_PASSWORD` sont définis
- génère le hash bcrypt du mot de passe avec les outils de sécurité OpenSearch
- **REMPLACE** `internal_users.yml` par le seul utilisateur personnalisé (supprime l'admin par défaut)
- cela a lieu avant le démarrage d'OpenSearch (opération atomique)
- écrit immédiatement le fichier sémaphore dans `/var/lib/opensearch/.axonops/init-security.done`

**5. Démarre OpenSearch**
- exécute `opensearch` (mode premier plan)
- remplace le processus d'entrypoint (devient le processus principal du conteneur)
- OpenSearch prend le relais, avec tini en PID 1

#### Ordre d'exécution

```
entrypoint.sh (PID 1 via tini)
  │
  ├─► 1. Print startup banner
  │
  ├─► 2. Set default environment variables
  │      (OPENSEARCH_CLUSTER_NAME, OPENSEARCH_NODE_NAME, etc.)
  │
  ├─► 3. Apply environment variables to opensearch.yml
  │      (cluster.name, node.name, network.host, discovery.type, etc.)
  │
  ├─► 4. Apply heap size to jvm.options
  │
  ├─► 5. Apply advanced settings (thread pool, SSL, security admin DN)
  │
  ├─► 6. Create custom admin user (PRE-STARTUP, if requested)
  │      - Generate password hash
  │      - REPLACE internal_users.yml with ONLY custom user
  │      - Write semaphore file
  │
  └─► 7. exec opensearch
         - Replaces entrypoint process
         - OpenSearch becomes main process
         - Container runs OpenSearch from this point
```

#### Fichiers de configuration modifiés

L'entrypoint modifie ces fichiers de configuration OpenSearch à partir des variables d'environnement :

| Fichier | Ce qui est modifié | Variables d'environnement |
|------|----------------|----------------------|
| `/etc/opensearch/opensearch.yml` | Réglages OpenSearch de base | `OPENSEARCH_CLUSTER_NAME`, `OPENSEARCH_NODE_NAME`, `OPENSEARCH_NETWORK_HOST`, `OPENSEARCH_DISCOVERY_TYPE`, `OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE`, `OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION`, `OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE`, `OPENSEARCH_SECURITY_ADMIN_DN`, `OPENSEARCH_SECURITY_NODES_DN`, `AXONOPS_SEARCH_TLS_ENABLED` |
| `/etc/opensearch/jvm.options` | Réglages de mémoire heap de la JVM | `OPENSEARCH_HEAP_SIZE` |
| `/etc/opensearch/opensearch-security/internal_users.yml` | Configuration de l'utilisateur admin | `AXONOPS_SEARCH_USER`, `AXONOPS_SEARCH_PASSWORD` (REMPLACE tout le fichier) |

#### Choix de conception

**Pourquoi exec opensearch ?**
- `exec` remplace le processus shell par OpenSearch
- OpenSearch devient le processus principal sous tini (le wrapper PID 1)
- l'arrêt du conteneur est propre
- aucun shell orphelin ne consomme de ressources

**Pourquoi créer l'utilisateur avant le démarrage (et non en arrière-plan) ?**
- la création de l'admin modifie `internal_users.yml` avant qu'OpenSearch ne le lise
- l'opération est propre et atomique (aucune condition de course)
- OpenSearch lit la configuration finale dès son premier démarrage
- plus simple que l'outil securityadmin post-démarrage (qui exige TLS)
- **modèle de REMPLACEMENT** : un seul utilisateur admin existe (le personnalisé OU celui par défaut, jamais les deux)

**Pourquoi tini comme système d'init ?**
- **transmission des signaux** — garantit que SIGTERM/SIGINT atteignent OpenSearch, pour un arrêt propre
- **récupération des zombies** — nettoie les processus enfants terminés
- **bonne pratique conteneur** — évite les problèmes lorsque le moteur de conteneurs envoie un signal d'arrêt
- **surcoût minimal** — un tout petit binaire statique (environ 10 Ko), sans dépendances
- **standard du secteur** — le même init que Docker avec l'option `--init`
- sans tini, un script shell (PID 1) ne transmet pas correctement les signaux, ce qui provoque des kills forcés

**Plus d'informations :** [Why you need an init system](https://github.com/krallin/tini#why-tini) dans les conteneurs

### Bannière de version au démarrage

Tous les conteneurs affichent au démarrage une information de version complète :

```
================================================================================
AxonOps AxonDB Search (OpenSearch 3.3.2)
Image: ghcr.io/axonops/axondb-search:3.3.2-1.0.0
Built: 2025-12-13T10:30:00Z
Release: https://github.com/axonops/axonops-containers/releases/tag/axondb-search-1.0.0
Built by: GitHub Actions
================================================================================

Component Versions:
  OpenSearch:         3.3.2
  Java:               OpenJDK Runtime Environment (Red_Hat-17.0.17.0.10-1)
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI - Universal Base Image, freely redistributable)
  Platform:           x86_64

Supply Chain Security:
  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest
  Base image digest:  sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2

Runtime Environment:
  Hostname:           axondb-search-node-1
  Kubernetes:         Yes
    API Server:       10.0.0.1:443
    Pod:              axondb-search-node-1

================================================================================
Starting OpenSearch...
================================================================================
```

**Afficher la bannière :**
```bash
docker logs axondb-search | head -30
```

### Sondes de healthcheck

Le conteneur embarque un script de healthcheck optimisé, prenant en charge trois types de sondes, conçu pour un surcoût minimal sans sacrifier la fiabilité :

**1. Sonde de démarrage** (`healthcheck.sh startup`)
- **attend la fin de l'initialisation** (essentiel pour la création d'admin avant démarrage)
- cherche le fichier sémaphore dans le stockage persistant : `/var/lib/opensearch/.axonops/init-security.done`
- **contrôle le champ RESULT** — échoue si le sémaphore porte `RESULT=failed`
- vérifie que le processus OpenSearch tourne (`pgrep -f OpenSearch`)
- vérifie que le port HTTP (9200) écoute (test TCP via `nc`)
- interroge l'endpoint de santé du plugin de sécurité (léger, sans authentification)
- **bloque le statut « Started » du pod jusqu'à la fin réussie de l'init**
- à utiliser pour : la `startupProbe` Kubernetes (garantit la création de l'admin avant tout routage de trafic)

**2. Sonde de liveness** (`healthcheck.sh liveness`)
- **ultra-légère** — prévue pour s'exécuter fréquemment (toutes les 10 secondes)
- vérifie que le processus OpenSearch tourne (`pgrep -f OpenSearch`)
- vérifie que le port HTTP (9200) écoute (test TCP via `nc`)
- interroge l'endpoint de santé du plugin de sécurité (léger, sans authentification)
- **aucun appel à l'API de santé du cluster** — surcoût minimal, exécution très rapide
- à utiliser pour : la `livenessProbe` Kubernetes (détection d'un crash du processus OpenSearch)

**3. Sonde de readiness** (`healthcheck.sh readiness`)
- vérifie que le port HTTP (9200) écoute (test TCP via `nc`)
- appelle l'API `/_cluster/health` en s'authentifiant
- vérifie que l'état du cluster n'est pas « red » (yellow ou green sont acceptables)
- **plus poussée** que la liveness — garantit qu'OpenSearch est pleinement opérationnel
- détecte automatiquement les identifiants admin depuis le fichier sémaphore (l'utilisateur personnalisé s'il a été créé)
- à utiliser pour : la `readinessProbe` Kubernetes (contrôles du répartiteur de charge, routage du trafic)

**Healthcheck Docker :**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect axondb-search --format='{{json .State.Health}}' | jq
```

**Test manuel du healthcheck :**
```bash
# Test startup probe
docker exec axondb-search /usr/local/bin/healthcheck.sh startup

# Test liveness probe
docker exec axondb-search /usr/local/bin/healthcheck.sh liveness

# Test readiness probe
docker exec axondb-search /usr/local/bin/healthcheck.sh readiness
```

**Note :** la configuration des sondes de healthcheck est prise en charge automatiquement par les charts Helm AxonOps. Les modes ci-dessus restent disponibles pour des déploiements personnalisés.

### Sécurité et gestion des certificats

Le conteneur embarque une configuration de sécurité complète, avec des certificats TLS aux couleurs d'AxonOps générés **à l'exécution** (au démarrage du conteneur), ce qui apporte davantage de sécurité et de souplesse dans les scénarios à stockage persistant.

#### Génération des certificats à l'exécution

**Comment cela fonctionne :**

Le conteneur génère les certificats automatiquement à son démarrage :

1. **Contrôle au démarrage** : au lancement, le script d'entrypoint vérifie si les fichiers de certificats existent
2. **Génération automatique** : s'ils manquent, ils sont générés automatiquement aux couleurs d'AxonOps
3. **Suivi par sémaphore** : un fichier sémaphore enregistre l'état de la génération
4. **Saut au redémarrage** : si les certificats existent déjà (volume persistant), la génération est sautée

**Avantages de la génération à l'exécution :**

- **Compatible avec le stockage persistant** : les certificats survivent aux recréations de conteneur lorsqu'un volume est utilisé
- **Certificats neufs** : un nouveau déploiement obtient des certificats fraîchement générés
- **Certificats fournis par l'utilisateur** : facile à mettre en place, en désactivant la génération automatique
- **Fonctionnement transparent** : entièrement automatique, avec des valeurs par défaut raisonnables

**Contrôler la génération des certificats :**

La variable d'environnement `GENERATE_CERTS_ON_STARTUP` pilote ce comportement :

```bash
# Default: Auto-generate certificates if missing
docker run -d --name axondb-search \
  -e GENERATE_CERTS_ON_STARTUP=true \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Disable: Require user-provided certificates
docker run -d --name axondb-search \
  -e GENERATE_CERTS_ON_STARTUP=false \
  -v /path/to/your/certs:/etc/opensearch/certs \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Scénarios de génération :**

| Scénario | `GENERATE_CERTS_ON_STARTUP` | Certificats présents ? | Résultat |
|----------|----------------------------|---------------------|--------|
| **Premier démarrage (volume vide)** | `true` (défaut) | Non | ✓ Certificats générés |
| **Premier démarrage (sans volume)** | `true` (défaut) | Non | ✓ Certificats générés (éphémères) |
| **Redémarrage avec volume persistant** | `true` (défaut) | Oui | ✓ Génération sautée (certificats existants réutilisés) |
| **Certificats fournis par l'utilisateur** | `false` | Oui | ✓ Certificats de l'utilisateur utilisés |
| **Certificats fournis par l'utilisateur** | `false` | Non | ✗ Le conteneur échoue (aucun certificat) |

**Fichier sémaphore :**

L'état de la génération des certificats est consigné dans `/var/lib/opensearch/.axonops/generate-certs.done` :

```bash
# Check certificate generation status
docker exec axondb-search cat /var/lib/opensearch/.axonops/generate-certs.done

# Example output:
COMPLETED=2025-12-16T05:47:02Z
RESULT=success
REASON=certs_generated
```

**Valeurs possibles de `RESULT` :**
- `success` — certificats générés avec succès
- `skipped` — certificats déjà présents, génération sautée
- `disabled` — génération désactivée via `GENERATE_CERTS_ON_STARTUP=false`

#### Certificats aux couleurs d'AxonOps (et NON des certificats de démonstration)

**DIFFÉRENCE CRITIQUE avec une installation de démonstration :**

- **les certificats de démonstration sont SUPPRIMÉS** pendant la construction Docker (ils ne figurent jamais dans l'image finale)
- **les certificats aux couleurs d'AxonOps** sont générés avec des réglages de qualité production
- **détails des certificats :**
  - **Algorithme :** RSA 3072 bits (sécurité robuste)
  - **Validité :** 5 ans (1825 jours)
  - **Organisation :** AxonOps
  - **Unité d'organisation :** Database
  - **Common Names :**
    - CA racine : `AxonOps Root CA`
    - certificat de nœud : `axondbsearch.axonops.com`
    - certificat admin : `admin.axondbsearch.axonops.com`
  - **Subject Alternative Names (SAN) :** `axondbsearch.axonops.com`, `*.axondbsearch.axonops.com`, `localhost`, `127.0.0.1`, `::1`

**Configuration de sécurité (opensearch.yml) :**

```yaml
# Transport layer SSL/TLS (node-to-node communication)
plugins.security.ssl.transport.pemcert_filepath: certs/axondbsearch-default-node.pem
plugins.security.ssl.transport.pemkey_filepath: certs/axondbsearch-default-node-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: certs/axondbsearch-default-root-ca.pem
plugins.security.ssl.transport.enforce_hostname_verification: false

# HTTP layer SSL/TLS (REST API)
plugins.security.ssl.http.enabled: true
plugins.security.ssl.http.pemcert_filepath: certs/axondbsearch-default-node.pem
plugins.security.ssl.http.pemkey_filepath: certs/axondbsearch-default-node-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: certs/axondbsearch-default-root-ca.pem
plugins.security.ssl.http.clientauth_mode: NONE

# Admin certificate DN (for securityadmin tool)
plugins.security.authcz.admin_dn:
  - "OU=Database,O=AxonOps,CN=admin.axondbsearch.axonops.com"

# Demo certificates NOT allowed (we use AxonOps-branded certificates)
plugins.security.allow_unsafe_democertificates: false
```

#### Fichiers de certificats générés

Les fichiers de certificats suivants sont créés dans `/etc/opensearch/certs/` (le préfixe `axondbsearch-default-` identifie clairement les certificats générés automatiquement) :

| Fichier | Type | Description |
|------|------|-------------|
| `axondbsearch-default-root-ca.pem` | Certificat de CA racine | CA racine AxonOps (certificat public) |
| `axondbsearch-default-root-ca-key.pem` | Clé privée de la CA racine | Clé privée de la CA racine (permissions 600) |
| `axondbsearch-default-node.pem` | Certificat de nœud | Certificat de nœud pour le SSL transport et HTTP |
| `axondbsearch-default-node-key.pem` | Clé privée du nœud | Clé privée du nœud, au format PKCS#8 (permissions 600) |
| `axondbsearch-default-admin.pem` | Certificat admin | Certificat client admin pour l'outil securityadmin |
| `axondbsearch-default-admin-key.pem` | Clé privée admin | Clé privée admin, au format PKCS#8 (permissions 600) |

**Convention de nommage :**

Les fichiers de certificats utilisent le préfixe `axondbsearch-default-` afin de :
- identifier clairement les certificats générés automatiquement par AxonOps
- les distinguer des certificats fournis par l'utilisateur
- rendre évident quels certificats peuvent être remplacés sans risque

**Vérification des certificats :**

```bash
# View node certificate details
docker exec axondb-search openssl x509 -in /etc/opensearch/certs/axondbsearch-default-node.pem -noout -text

# Verify certificate chain
docker exec axondb-search openssl verify \
  -CAfile /etc/opensearch/certs/axondbsearch-default-root-ca.pem \
  /etc/opensearch/certs/axondbsearch-default-node.pem

# Check certificate generation semaphore
docker exec axondb-search cat /var/lib/opensearch/.axonops/generate-certs.done
```

#### Utiliser vos propres certificats

Pour fournir vos certificats plutôt que ceux générés automatiquement par AxonOps :

**Option 1 : désactiver la génération automatique et monter vos certificats**
```bash
docker run -d --name axondb-search \
  -e GENERATE_CERTS_ON_STARTUP=false \
  -v /path/to/your/certs:/etc/opensearch/certs:ro \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Option 2 : remplacer les certificats dans le volume persistant**
```bash
# Create volume
docker volume create opensearch-certs

# Start container with auto-generation first time
docker run -d --name axondb-search \
  -v opensearch-certs:/etc/opensearch/certs \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Stop container and replace certificates
docker stop axondb-search
docker run --rm -v opensearch-certs:/certs busybox sh -c "rm /certs/axondbsearch-default-*.pem"
docker cp /path/to/your/certs/. axondb-search:/etc/opensearch/certs/

# Restart with your certificates
docker start axondb-search
```

**Fichiers de certificats requis (si vous fournissez les vôtres) :**
- `root-ca.pem` (ou le nom de votre certificat de CA)
- `node.pem` (ou le nom de votre certificat de nœud)
- `node-key.pem` (ou le nom de votre clé de nœud, au format PKCS#8)
- `admin.pem` (ou le nom de votre certificat admin)
- `admin-key.pem` (ou le nom de votre clé admin, au format PKCS#8)

Mettez à jour `opensearch.yml` pour référencer vos noms de fichiers s'ils diffèrent des valeurs par défaut d'AxonOps.

#### Modèle de remplacement de l'utilisateur admin

Contrairement à AxonDB Time-Series (qui ajoute un utilisateur personnalisé), AxonDB Search applique un modèle de **REMPLACEMENT**, par sécurité :

**Configuration par défaut (sans utilisateur personnalisé) :**
- utilisateur admin par défaut : `admin`
- mot de passe par défaut : `MyS3cur3P@ss2025`
- emplacement : `/etc/opensearch/opensearch-security/internal_users.yml`

**Configuration avec utilisateur personnalisé (recommandée en production) :**
```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=MySecurePassword123 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Ce qui se passe :**
1. le script d'entrypoint génère le hash bcrypt du mot de passe de l'utilisateur personnalisé
2. il **REMPLACE** entièrement `internal_users.yml` par le seul utilisateur personnalisé
3. l'utilisateur `admin` par défaut est **SUPPRIMÉ** (il ne figure pas dans la configuration finale)
4. un seul utilisateur admin existe dans le système (le personnalisé)
5. le fichier sémaphore est écrit dans `/var/lib/opensearch/.axonops/init-security.done`

**Justification sécurité :**
- **principe du moindre privilège** — un seul compte admin réduit la surface d'attaque
- **aucun identifiant par défaut** — élimine le risque d'un admin par défaut oublié
- **opération atomique** — la création a lieu avant le démarrage d'OpenSearch
- **modèle de sécurité propre** — aucun compte hérité ni désactivé

#### Options de configuration TLS

**Activer / désactiver le SSL HTTP :**

Par défaut, HTTPS est activé sur l'API REST. Vous pouvez le désactiver si le TLS est terminé par un répartiteur de charge :

```bash
# Disable HTTP SSL (TLS terminated at load balancer)
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_TLS_ENABLED=false \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Important :**
- le SSL de la couche transport (entre nœuds) reste activé même lorsque le SSL HTTP est désactivé
- c'est la configuration recommandée avec un répartiteur de charge ou un contrôleur ingress qui termine le TLS
- les communications internes du cluster sont toujours chiffrées

**DN de certificat personnalisé (avancé) :**

Pour des scénarios de certificats personnalisés, vous pouvez surcharger le DN du certificat admin :

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_SECURITY_ADMIN_DN="CN=mycustomadmin,O=MyOrg,OU=MyUnit" \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

### Initialisation automatisée (configuration de sécurité et utilisateur admin)

Le conteneur réalise une initialisation de sécurité automatisée, qui couvre la vérification des certificats et, en option, la création d'un utilisateur admin personnalisé. Elle est coordonnée par des fichiers sémaphores, pour un ordonnancement correct avec les sondes de healthcheck.

#### Comment cela fonctionne (déroulé)

L'initialisation applique la configuration **avant le démarrage** (et non via un processus d'arrière-plan) pour la création de l'admin, avec un script de vérification en arrière-plan :

```
1. entrypoint.sh starts (PID 1 via tini)
   │
   ├─► 2. Apply configuration (opensearch.yml, jvm.options)
   │
   ├─► 3. Create custom admin user (PRE-STARTUP, if requested)
   │      - Generate password hash
   │      - REPLACE internal_users.yml with ONLY custom user
   │      - Write initial semaphore file
   │      (This happens BEFORE OpenSearch starts)
   │
   └─► 4. Start OpenSearch (exec opensearch)
        │
        ├─► OpenSearch starts and begins accepting connections
        │   - Security plugin uses pre-configured settings from entrypoint
        │   - AxonOps certificates loaded from /etc/opensearch/certs/
        │   - Custom admin user (if created) is immediately active
        │
        └─► healthcheck.sh (startup probe) checks semaphore
            - Blocks until semaphore file exists
            - Verifies RESULT is not "failed"
            - Only then marks container as "Started"
```

**Pourquoi ce schéma est sûr :**

1. **L'admin est créé avant le démarrage d'OpenSearch** — aucune condition de course, opération atomique
2. **Un seul utilisateur admin existe** — modèle de REMPLACEMENT (le personnalisé OU celui par défaut, jamais les deux)
3. **Coordination par sémaphore** — le healthcheck attend la fin de l'initialisation
4. **Sémaphores persistants** — stockés dans `/var/lib/opensearch` (volume), ce qui évite une réinitialisation aux redémarrages
5. **Application par Kubernetes** — le pod n'est pas marqué « Started » tant que le sémaphore n'atteste pas le succès

#### Création de l'utilisateur admin (avant démarrage)

L'entrypoint crée l'utilisateur admin personnalisé et supprime l'admin par défaut **avant** le démarrage d'OpenSearch.

**Ce qu'il fait :**
1. génère le hash bcrypt du mot de passe de l'utilisateur personnalisé (avec l'outil hash.sh d'OpenSearch)
2. **REMPLACE** `internal_users.yml` par la seule définition de l'utilisateur personnalisé
3. l'utilisateur `admin` par défaut est supprimé (il ne figure pas dans la configuration finale)
4. écrit le sémaphore initial dans le stockage persistant : `/var/lib/opensearch/.axonops/init-security.done`

**Exemple :**
```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=MySecurePassword123 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Wait for startup (~1-2 minutes)
docker logs -f axondb-search

# Connect with custom credentials
curl -k -u dbadmin:MySecurePassword123 https://localhost:9200/_cluster/health
```

**Contrôles de sûreté :**
- ne s'exécute que si `AXONOPS_SEARCH_USER` et `AXONOPS_SEARCH_PASSWORD` sont tous deux définis
- la génération du hash du mot de passe est validée (elle doit produire un bcrypt valide)
- le remplacement du fichier est atomique (le nouveau fichier est écrit entièrement avant le démarrage d'OpenSearch)
- **le sémaphore est TOUJOURS écrit** (succès ou erreur)

#### Fin du démarrage

Une fois toute la configuration préalable appliquée par l'entrypoint :

**Ce qui se passe :**
1. le processus OpenSearch démarre avec toute la configuration appliquée
2. le plugin de sécurité se charge avec l'utilisateur admin préconfiguré
3. les certificats AxonOps sont utilisés pour le TLS
4. la sonde de démarrage du healthcheck vérifie que le fichier sémaphore porte RESULT=success
5. le conteneur n'est marqué « Started » dans Kubernetes qu'après le succès du healthcheck

#### Contrôle et désactivation

**Désactiver entièrement le plugin de sécurité (DÉCONSEILLÉ en production) :**
```bash
docker run -d --name axondb-search \
  -e DISABLE_SECURITY_PLUGIN=true \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

Lorsqu'il est désactivé, les fichiers sémaphores sont écrits immédiatement avec `RESULT=skipped`, pour que le healthcheck puisse passer.

#### Fichiers sémaphores

L'initialisation utilise des fichiers sémaphores pour se coordonner entre le script d'entrypoint, la vérification en arrière-plan et les sondes de healthcheck.

**Emplacement :** `/var/lib/opensearch/.axonops/`

Les sémaphores sont stockés dans le répertoire de données d'OpenSearch (et non dans `/etc`) parce que :
- `/var/lib/opensearch` est généralement un volume persistant dans Kubernetes
- une fois persistants, les sémaphores survivent aux redémarrages de conteneur ou de pod
- cela évite une réinitialisation au redémarrage d'un pod (par exemple pendant un rolling update)
- le healthcheck peut passer immédiatement après un redémarrage, sans rejouer l'init

**Important :** configurez `/var/lib/opensearch` comme volume persistant (PersistentVolumeClaim) dans votre déploiement Kubernetes. Les charts Helm AxonOps le font automatiquement.

**Fichier créé :**
- `init-security.done` — état de la configuration de sécurité et de l'utilisateur admin

**Format du fichier :**
```
COMPLETED=2025-12-16T09:32:17Z
RESULT=success
REASON=custom_user_created_prestartup
ADMIN_USER=dbadmin
```

**Valeurs de RESULT pour init-security.done :**
- `success` — initialisation de la sécurité terminée avec succès
  - `custom_user_created_prestartup` — utilisateur admin personnalisé créé (admin par défaut supprimé)
  - `default_config` — utilisation de l'utilisateur et du mot de passe admin par défaut

**Note :** si l'initialisation échoue (échec de la génération du hash, par exemple), le script d'entrypoint se termine avec le code 1 avant d'écrire le sémaphore, ce qui empêche le conteneur de démarrer.

**Garantie :** le fichier sémaphore est **TOUJOURS** écrit par le script d'entrypoint. La sonde de démarrage du healthcheck :
1. exige l'existence du fichier sémaphore
2. contrôle le champ RESULT
3. ne passe que si RESULT=success

Si l'entrypoint rencontre une erreur pendant l'initialisation préalable, il se termine avec le code 1 avant d'atteindre le démarrage d'OpenSearch : le conteneur ne démarre donc jamais complètement.

#### Logs d'initialisation

Consultez la progression et le résultat de l'initialisation :

```bash
# View OpenSearch startup logs
docker logs axondb-search

# Check security initialization status (in persistent volume)
docker exec axondb-search cat /var/lib/opensearch/.axonops/init-security.done

# View internal_users.yml to verify custom user
docker exec axondb-search cat /etc/opensearch/opensearch-security/internal_users.yml

# Verify AxonOps certificates
docker exec axondb-search ls -la /etc/opensearch/certs/
```

## Fichiers de configuration

Le conteneur embarque 13 fichiers de configuration qui pilotent le comportement d'OpenSearch :

### Fichiers de configuration principaux

| Fichier | Rôle | Principales adaptations |
|------|---------|-------------------|
| `opensearch.yml` | Réglages OpenSearch de base | Valeurs par défaut de production pour les charges de recherche, configuration du plugin de sécurité, chemins des certificats AxonOps |
| `jvm.options` | Options JVM | Réglages de heap (8G par défaut), configuration du GC optimisée pour la recherche |
| `log4j2.properties` | Configuration des logs | Rétention réduite, optimisée pour les environnements conteneurisés |

### Fichiers de configuration du plugin de sécurité (9 fichiers)

Situés dans `/etc/opensearch/opensearch-security/` :

| Fichier | Rôle | Description |
|------|---------|-------------|
| `config.yml` | Configuration principale du plugin de sécurité | Backends d'authentification et d'autorisation (basic auth, LDAP, JWT, etc.) |
| `internal_users.yml` | Base d'utilisateurs interne | Définition de l'utilisateur admin (REMPLACÉE par l'entrypoint si un utilisateur personnalisé est demandé) |
| `roles.yml` | Définitions de rôles | Rôles prédéfinis (admin, readall, etc.) |
| `roles_mapping.yml` | Association utilisateurs / rôles | Associe utilisateurs et rôles backend aux rôles OpenSearch |
| `action_groups.yml` | Définitions de groupes d'actions | Groupes de permissions, pour simplifier la création de rôles |
| `tenants.yml` | Configuration multi-tenant | Définitions de tenants, pour l'isolation du dashboard |
| `nodes_dn.yml` | Distinguished names des nœuds | DN de certificats autorisés pour les communications entre nœuds (hérité ; préférez la variable `OPENSEARCH_SECURITY_NODES_DN`) |
| `allowlist.yml` | Liste blanche d'API | Endpoints de l'API REST autorisés lorsque la sécurité est restreinte |
| `audit.yml` | Configuration de l'audit | Réglages des logs d'audit (désactivés par défaut, activables) |

**Points saillants de la configuration :**

**opensearch.yml :**
- **Cluster :** `axonopsdb-search` (réglable via `OPENSEARCH_CLUSTER_NAME`)
- **Découverte :** `single-node` par défaut (réglable via `OPENSEARCH_DISCOVERY_TYPE`)
- **Verrouillage mémoire :** `bootstrap.memory_lock: true` (exige la capability IPC_LOCK)
- **Réseau :** écoute sur `0.0.0.0` (toutes les interfaces)
- **Thread pool :** `thread_pool.write.queue_size: 10000` (à augmenter pour les charges à forte écriture)
- **Sécurité :** certificats aux couleurs d'AxonOps, certificats de démonstration désactivés (`allow_unsafe_democertificates: false`)
- **Nodes DN :** joker `CN=*.axonops.svc.cluster.local` par défaut (réglable via `OPENSEARCH_SECURITY_NODES_DN`)

**jvm.options :**
- **Heap :** 8G par défaut (`-Xms8g -Xmx8g`), réglable via `OPENSEARCH_HEAP_SIZE`
- **GC :** optimisé pour les JVM modernes (JDK 17+)

**log4j2.properties :**
- **Niveaux de log :** INFO par défaut, DEBUG activable si nécessaire
- **Rétention :** optimisée pour les environnements conteneurisés, avec une croissance maîtrisée
- **Emplacement :** `/var/log/opensearch/`

**internal_users.yml :**
- **Par défaut :** contient l'utilisateur `admin`, avec un mot de passe haché en bcrypt
- **Utilisateur personnalisé :** **entièrement REMPLACÉ** si `AXONOPS_SEARCH_USER` est défini (seul l'utilisateur personnalisé existe)
- **Format :** YAML, avec des hash de mots de passe bcrypt

**config.yml :**
- **Authentification :** HTTP Basic activée par défaut, contre la base d'utilisateurs interne
- **Autorisation :** association de rôles interne
- **Authentifications complémentaires :** LDAP, JWT, Kerberos, certificats clients disponibles (désactivés par défaut)

## Pipeline CI/CD

### Workflows

Le dépôt contient des workflows GitHub Actions complets :

**Build and Test** (`.github/workflows/axondb-search-build-and-test.yml`)
- **Déclencheurs :** push / PR vers les branches main, development, feature/*, fix/*
  - lorsque `axonops/axondb-search/**` change (hors fichiers `*.md`)
  - lorsque les workflows (`.github/workflows/axondb-search-*.yml`) changent
  - lorsque les actions (`.github/actions/axondb-search-*/**`) changent
- **Tests :** build Docker, vérification de version, healthcheck, analyse de sécurité
- **Durée :** environ 10 minutes

**Publication de production** (`.github/workflows/axondb-search-publish-signed.yml`)
- **Déclencheur :** dispatch manuel du workflow avec un tag Git
- **Processus :** valider → tester → créer la release → construire → signer → publier → vérifier
- **Registre :** `ghcr.io/axonops/axondb-search`
- **Plateformes :** linux/amd64, linux/arm64
- **Signature :** Cosign en mode keyless (OIDC)

**Publication de développement** (`.github/workflows/axondb-search-development-publish-signed.yml`)
- **Déclencheur :** dispatch manuel du workflow depuis la branche development
- **Registre :** `ghcr.io/axonops/development/axondb-search`
- **Usage :** tester les images avant une release de production

### Tests automatisés

Le pipeline CI comprend des tests complets :

**Tests fonctionnels :**
- vérification de la construction du conteneur (multi-architecture)
- vérification de la bannière de démarrage (production ou développement)
- vérification des versions (OpenSearch, Java)
- tests du script de healthcheck (startup, liveness, readiness)
- vérification de l'initialisation de la sécurité
- opérations sur l'API REST avec curl
- traitement des variables d'environnement (20 variables)
- vérification des certificats

**Tests de sécurité :**
- analyse des vulnérabilités du conteneur avec Trivy (sévérités CRITICAL et HIGH)
- résultats remontés dans l'onglet Security de GitHub
- CVE amont connues documentées dans `.trivyignore`
- vérification des certificats (aux couleurs d'AxonOps, non de démonstration)

**Actions composites :**
Situées dans `.github/actions/axondb-search-*/` :
- `start-and-wait` — démarre le conteneur et attend qu'il soit prêt
- `verify-startup-banner` — vérifie le contenu de la bannière
- `verify-no-startup-errors` — cherche les erreurs de démarrage
- `verify-versions` — vérifie les versions des composants
- `test-healthcheck` — teste tous les modes de healthcheck
- `verify-init-scripts` — vérifie que l'initialisation de la sécurité s'est terminée
- `test-rest-api` — teste le fonctionnement de l'API REST
- `test-all-env-vars` — teste la configuration par variables d'environnement (20 variables)
- `verify-certificates` — vérifie les certificats AxonOps (et non ceux de démonstration)
- `sign-container` — signature Cosign
- `verify-published-image` — vérification après publication
- `collect-logs` — collecte les logs du conteneur
- `determine-latest` — détermine les tags latest

### Processus de publication

**Release de développement :**
```bash
# Tag on development branch
git checkout development
git tag vdev-axondb-search-1.0.0
git push origin vdev-axondb-search-1.0.0

# Publish to development registry
gh workflow run axondb-search-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=vdev-axondb-search-1.0.0 \
  -f container_version=1.0.0
```

**Release de production :**
```bash
# Tag on main branch
git checkout main
git tag axondb-search-1.0.0
git push origin axondb-search-1.0.0

# Publish to production registry
gh workflow run axondb-search-publish-signed.yml \
  --ref main \
  -f main_git_tag=axondb-search-1.0.0 \
  -f container_version=1.0.0
```

Voir [RELEASE.md](./RELEASE.md) pour la documentation complète du processus de release.

## Dépannage

### Vérifier la version du conteneur

Consultez la bannière de démarrage pour voir toutes les versions des composants :

```bash
docker logs axondb-search | head -30
```

La bannière affiche :
- la version du conteneur et la révision git
- les versions d'OpenSearch, de Java et de l'OS
- le digest de l'image de base (pour la vérification de la chaîne d'approvisionnement)
- les détails de l'environnement d'exécution

### Logs du script d'initialisation

Consultez la progression et le résultat de l'initialisation :

```bash
# View OpenSearch startup logs
docker logs axondb-search

# Check security initialization status (in persistent volume)
docker exec axondb-search cat /var/lib/opensearch/.axonops/init-security.done

# View internal_users.yml to verify admin user configuration
docker exec axondb-search cat /etc/opensearch/opensearch-security/internal_users.yml

# List AxonOps certificates
docker exec axondb-search ls -la /etc/opensearch/certs/
```

**Format du fichier sémaphore :**
```
COMPLETED=2025-12-16T10:45:00Z
RESULT=success
REASON=custom_user_created_prestartup
ADMIN_USER=dbadmin
```

Valeurs possibles de `RESULT` :
- `success` — opération terminée avec succès
- `skipped` — opération sautée (le champ REASON explique pourquoi)
- `failed` — opération en échec (le champ REASON explique pourquoi)

### Déboguer le healthcheck

Testez les sondes de healthcheck à la main :

```bash
# Test all three probe types
docker exec axondb-search /usr/local/bin/healthcheck.sh startup
docker exec axondb-search /usr/local/bin/healthcheck.sh liveness
docker exec axondb-search /usr/local/bin/healthcheck.sh readiness

# Check Docker healthcheck status
docker inspect axondb-search --format='{{json .State.Health}}' | jq

# Test REST API manually
docker exec axondb-search curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health
```

### Le conteneur ne démarre pas

**Consultez les logs :**
```bash
docker logs axondb-search
```

**Problèmes courants :**

1. **Mémoire insuffisante :**
   - le heap vaut 8G par défaut ; prévoyez au moins 12 Go de RAM (1,5 fois le heap)
   - ajustez avec : `-e OPENSEARCH_HEAP_SIZE=4g`

2. **Conflits de ports :**
   - HTTP : 9200
   - transport : 9300
   - à vérifier avec : `netstat -tuln | grep 9200`

3. **Problèmes de permissions :**
   - le conteneur s'exécute sous l'utilisateur `opensearch` (UID 999)
   - assurez-vous des permissions du volume : `chown -R 999:999 /data/opensearch`

4. **vm.max_map_count trop bas :**
   - à vérifier : `sysctl vm.max_map_count`
   - à régler : `sudo sysctl -w vm.max_map_count=262144`
   - de façon permanente : ajoutez la ligne à `/etc/sysctl.conf`

5. **Problèmes d'initialisation :**
   - vérifiez le sémaphore : `docker exec axondb-search cat /var/lib/opensearch/.axonops/init-security.done`
   - cherchez RESULT=failed ou le REASON correspondant

**Récupérer les logs OpenSearch :**
```bash
docker exec axondb-search cat /var/log/opensearch/axonopsdb-search.log
```

**Vérifier qu'OpenSearch tourne :**
```bash
docker exec axondb-search ps aux | grep opensearch
```

**Tester la connectivité de l'API REST :**
```bash
# With default credentials
curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health

# With custom credentials
curl -k -u dbadmin:MySecurePassword123 https://localhost:9200/_cluster/health

# Without TLS (if AXONOPS_SEARCH_TLS_ENABLED=false)
curl -u admin:MyS3cur3P@ss2025 http://localhost:9200/_cluster/health
```

## Considérations de production

1. **Stockage persistant**
   - utilisez toujours des volumes pour `/var/lib/opensearch` (données et sémaphores)
   - utilisez des volumes pour `/var/log/opensearch` (logs)
   - exemple : `-v /data/opensearch:/var/lib/opensearch`
   - utilisez du stockage SSD en production (des IOPS élevées sont nécessaires)

2. **Allocation de ressources**
   - mémoire : au moins 1,5 fois la taille du heap (par exemple 12 Go pour un heap de 8 Go)
   - CPU : 4 cœurs ou plus recommandés
   - disque : SSD rapide, avec des IOPS suffisantes
   - heap : 32 Go au maximum (optimisation des pointeurs compressés de la JVM)

3. **Configuration système**
   - **vm.max_map_count :** doit valoir au moins 262144 sur tous les nœuds
   - **ulimits.nofile :** à fixer à 65536 (descripteurs de fichiers ouverts)
   - **capability IPC_LOCK :** nécessaire pour `bootstrap.memory_lock: true`
   - désactivez le swap, pour de meilleures performances

4. **Réseau**
   - exposez les ports nécessaires : 9200 (HTTP), 9300 (transport)
   - appliquez des règles de pare-feu adaptées
   - envisagez de terminer le TLS au répartiteur de charge (mettre `AXONOPS_SEARCH_TLS_ENABLED=false`)
   - le SSL de la couche transport reste actif pour les communications entre nœuds

5. **Sécurité**
   - utilisez un utilisateur admin personnalisé (variables `AXONOPS_SEARCH_USER` et `AXONOPS_SEARCH_PASSWORD`)
   - n'utilisez **JAMAIS** les identifiants par défaut en production
   - vérifiez les signatures des conteneurs avec Cosign
   - référencez les images par digest, pour l'immuabilité
   - gardez les images de base à jour (automatisé sur UBI)
   - les certificats aux couleurs d'AxonOps sont de qualité production (RSA 3072, validité de 5 ans)

6. **Supervision**
   - utilisez les sondes de healthcheck pour la supervision de disponibilité
   - surveillez l'usage du heap via les métriques JVM
   - mettez en place une agrégation des logs de `/var/log/opensearch/`
   - envisagez une intégration à AxonOps pour une supervision complète
   - surveillez la santé du cluster via l'API `/_cluster/health`

7. **Stratégie de sauvegarde**
   - snapshots réguliers de `/var/lib/opensearch/data`
   - utilisez l'API de dépôt de snapshots d'OpenSearch
   - testez les procédures de restauration
   - documentez les objectifs de temps de reprise (RTO)

8. **Déploiement en cluster**
   - utilisez le même `OPENSEARCH_CLUSTER_NAME` sur tous les nœuds
   - configurez les seed hosts pour la découverte multi-nœuds
   - prévoyez les nœuds éligibles cluster-manager (3 au minimum, pour le quorum)
   - utilisez des nœuds cluster-manager dédiés sur les grands clusters
   - configurez correctement la répartition des shards (shard allocation awareness)

Pour le workflow de développement et les tests, voir [DEVELOPMENT.md](./DEVELOPMENT.md).

Pour le processus de release, voir [RELEASE.md](./RELEASE.md).
