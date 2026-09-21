# Base de données time-series AxonDB

[English](README.md) | **Français** | [Español](README.es.md) | [Galego](README.gl.md)

[![Paquet GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axondb-timeseries)

Conteneur Apache Cassandra 5.0.6 prêt pour la production, optimisé pour les charges time-series des déploiements AxonOps auto-hébergés.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Images Docker préconstruites](#images-docker-préconstruites)
  - [Images disponibles](#images-disponibles)
  - [Stratégie de tags](#stratégie-de-tags)
- [Bonne pratique de production](#bonne-pratique-de-production)
- [Déploiement](#déploiement)
- [Construire les images Docker](#construire-les-images-docker)
- [Variables d'environnement](#variables-denvironnement)
  - [Configuration Cassandra](#configuration-cassandra)
  - [Contrôle de l'initialisation](#contrôle-de-linitialisation)
- [Fonctionnalités du conteneur](#fonctionnalités-du-conteneur)
  - [Script d'entrypoint](#script-dentrypoint)
  - [Bannière de version au démarrage](#bannière-de-version-au-démarrage)
  - [Sondes de healthcheck](#sondes-de-healthcheck)
  - [Initialisation automatisée (keyspaces système et utilisateur de base)](#initialisation-automatisée-keyspaces-système-et-utilisateur-de-base)
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

AxonDB Time-Series est un conteneur Apache Cassandra prêt pour la production, conçu spécifiquement pour les déploiements AxonOps auto-hébergés. Il est optimisé pour les charges de base de données time-series et se déploie dans le cadre de la stack AxonOps complète, via les charts Helm AxonOps.

**Fonctionnalités du conteneur :**
- **Shell CQL moderne** : [cqlai](https://github.com/axonops/cqlai) v0.1.2, pour une interaction facilitée avec la base
- **Optimisation mémoire** : jemalloc, pour une meilleure gestion de la mémoire
- **Mise en place automatisée** : initialisation des keyspaces système et création d'un utilisateur personnalisé
- **Base entreprise** : construit sur Red Hat UBI 9 minimal, pour la stabilité en production
- **Sécurité de la chaîne d'approvisionnement** : images de base épinglées par digest, pour des builds immuables
- **Supervision de production** : sondes de healthcheck intégrées (startup, liveness, readiness)

**Important :** ce conteneur est destiné exclusivement aux déploiements AxonOps auto-hébergés. Il est déployé et configuré via les charts Helm AxonOps, qui prennent en charge l'orchestration, le réseau et l'intégration avec la plateforme de supervision et de gestion AxonOps. Pour en savoir plus sur AxonOps, voir [axonops.com](https://axonops.com).

## Images Docker préconstruites

Des images préconstruites sont disponibles sur le GitHub Container Registry (GHCR). C'est la façon la plus simple de démarrer.

### Images disponibles

Toutes les images sont disponibles à l'adresse : `ghcr.io/axonops/axondb-timeseries`

Parcourir tous les tags disponibles : [GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axondb-timeseries)

### Stratégie de tags

Les images suivent une stratégie de tags à deux dimensions :

| Forme du tag | Exemple | Description | Cas d'usage |
|-------------|---------|-------------|----------|
| `{CASS}-{AXON}` | `5.0.6-1.0.0` | Totalement immuable (version de Cassandra + version AxonOps) | **Production** : épingler les versions exactes pour une traçabilité complète |
| `@sha256:<digest>` | `@sha256:abc123...` | Fondé sur le digest (immuable cryptographiquement) | **Sécurité maximale** : intégrité de l'image garantie |
| `{CASS}` | `5.0.6` | Dernier AxonOps pour cette version de Cassandra | Suivre les mises à jour d'AxonOps pour une version de Cassandra donnée |
| `latest` | `latest` | La plus récente, toutes versions confondues | Essais rapides uniquement (PAS pour la production) |

**Dimensions de versionnage :**
- **CASS** — version de Cassandra (par exemple 5.0.6)
- **AXON** — version du conteneur AxonOps (par exemple 1.0.0, en SemVer)

**Exemples de tags :**

Lorsque `5.0.6-1.0.0` est construit (et qu'il est le plus récent) :
- `5.0.6-1.0.0` (immuable — ne change jamais)
- `5.0.6` (flottant — se déplace vers les builds AxonOps plus récents)
- `latest` (flottant — se déplace vers les versions de Cassandra plus récentes)

## 💡 Bonne pratique de production

⚠️ **Utiliser `latest` ou des tags flottants en production est un anti-pattern**. Cela vaut pour `latest` comme pour `5.0.6`, parce que :
- **Aucune traçabilité** : impossible de déterminer la version exacte déployée à un instant donné
- **Mises à jour inattendues** : les orchestrateurs de conteneurs peuvent tirer de nouvelles images lors d'un redémarrage
- **Retours arrière difficiles** : impossible de revenir de façon fiable à une version antérieure
- **Problèmes de conformité** : de nombreux référentiels exigent un suivi de version immuable

👍 **Stratégies de déploiement recommandées (par ordre de sécurité) :**

1. **🥇 Référence absolue — par digest** (sécurité maximale)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries@sha256:abc123...
   ```
   - immuable à 100 %, garanti cryptographiquement
   - requis dans les environnements réglementés
   - vérifiez la signature avec Cosign (voir la note de sécurité ci-dessous)

2. **🥈 Tag immuable** (standard de production)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
   ```
   - épinglé sur une version précise (Cassandra 5.0.6 + AxonOps 1.0.0)
   - facile à lire et à gérer
   - traçabilité complète conservée

3. **🥉 Tags flottants** (développement / test uniquement)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries:latest
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
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0

# Check signature exists
cosign tree ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

## Déploiement

Ce conteneur se déploie exclusivement via les **charts Helm AxonOps**, dans le cadre de la stack AxonOps auto-hébergée. Les charts Helm prennent en charge toute la configuration, l'orchestration et l'intégration avec les composants de supervision et de gestion AxonOps.

Pour les instructions de déploiement, reportez-vous à la documentation de déploiement AxonOps auto-hébergé (disponible à la publication des charts Helm).

## Construire les images Docker

Si vous préférez construire les images vous-même plutôt que d'utiliser les images préconstruites :

```bash
cd axonops/axondb-timeseries/5.0.6

# Minimal build (required args only)
docker build \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg CQLAI_VERSION=0.1.4 \
  -t axondb-timeseries:5.0.6-1.0.0 \
  .

# Multi-arch build (amd64 + arm64) using buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg CQLAI_VERSION=0.1.4 \
  -t axondb-timeseries:5.0.6-1.0.0 \
  .
```

**Arguments de build obligatoires :**
- `CASSANDRA_VERSION` — version de Cassandra (par exemple 5.0.6)
- `CQLAI_VERSION` — version de cqlai à installer (voir la [dernière release](https://github.com/axonops/cqlai/releases))

**Fichiers de configuration personnalisés :**

Le conteneur embarque des fichiers de configuration Cassandra adaptés aux déploiements conteneurisés :

| Fichier | Rôle | Principales adaptations |
|------|---------|-------------------|
| `cassandra.yaml` | Réglages Cassandra de base | Valeurs par défaut de production, pour charges time-series |
| `jvm-server.options` | Options JVM | Réglages mémoire, configuration du GC |
| `jvm17-server.options` | Options propres au JDK 17 | GC Shenandoah, réglages de heap (8G par défaut) |
| `cassandra-env.sh` | Environnement Cassandra | Paramètres JVM, optimisation mémoire |
| `logback.xml` | Configuration des logs | Rétention réduite (1 Go au total, 7 jours), logs de debug désactivés en production |

**Points saillants de logback.xml :**
- **SYSTEMLOG** (system.log) : niveau INFO, fichiers de 50 Mo, rétention de 7 jours, **plafond global de 1 Go** (contre 5 Go par défaut)
- **DEBUGLOG** (debug.log) : désactivé par défaut (réactivable en décommentant l'appender-ref)
- **Audit logging** : l'infrastructure est présente mais désactivée (activable dans cassandra.yaml si besoin)
- optimisé pour les environnements conteneurisés, avec une croissance des logs maîtrisée

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

Le conteneur accepte 14 variables d'environnement de configuration :

| Variable | Description | Défaut | Catégorie |
|----------|-------------|---------|----------|
| `CASSANDRA_CLUSTER_NAME` | Nom du cluster | `axonopsdb-timeseries` | Cassandra |
| `CASSANDRA_NUM_TOKENS` | Nombre de tokens par nœud (vnodes) | `8` | Cassandra |
| `CASSANDRA_DC` | Nom du datacenter | `axonopsdb_dc1` | Cassandra |
| `CASSANDRA_RACK` | Nom du rack | `rack1` | Cassandra |
| `CASSANDRA_LISTEN_ADDRESS` | Adresse IP d'écoute (`auto` = détection automatique) | `auto` | Cassandra |
| `CASSANDRA_BROADCAST_ADDRESS` | Adresse IP annoncée aux autres nœuds | Identique à `CASSANDRA_LISTEN_ADDRESS` | Cassandra |
| `CASSANDRA_RPC_ADDRESS` | Adresse du native transport CQL | `0.0.0.0` (toutes les interfaces) | Cassandra |
| `CASSANDRA_BROADCAST_RPC_ADDRESS` | Adresse RPC annoncée aux clients | Identique à `CASSANDRA_LISTEN_ADDRESS` | Cassandra |
| `CASSANDRA_SEEDS` | Adresses des nœuds seeds (séparées par des virgules) | Sa propre IP (mono-nœud) | Cassandra |
| `CASSANDRA_HEAP_SIZE` | Taille du heap JVM (-Xms et -Xmx) | `8G` | Cassandra |
| `INIT_SYSTEM_KEYSPACES_AND_ROLES` | Convertir automatiquement les keyspaces système et créer les rôles personnalisés | `true` | Initialisation |
| `INIT_TIMEOUT` | Délai, en secondes, pendant lequel le script d'initialisation attend Cassandra | `600` (10 min) | Initialisation |
| `AXONOPS_DB_USER` | Créer un superutilisateur personnalisé portant ce nom (optionnel) | - | Initialisation |
| `AXONOPS_DB_PASSWORD` | Mot de passe du superutilisateur personnalisé (obligatoire si `AXONOPS_DB_USER` est défini) | - | Initialisation |

### Configuration Cassandra

Les 10 premières variables règlent le comportement de base de Cassandra. Elles sont traitées par le script d'entrypoint et appliquées aux fichiers de configuration avant le démarrage de Cassandra.

**Configuration réseau :**
- `CASSANDRA_LISTEN_ADDRESS` — mettre `auto` pour la détection automatique de l'IP, ou indiquer une adresse
- `CASSANDRA_BROADCAST_ADDRESS` — vaut l'adresse d'écoute par défaut ; à surcharger en cas de NAT ou de pare-feu
- `CASSANDRA_RPC_ADDRESS` — mettre `0.0.0.0` pour écouter sur toutes les interfaces
- `CASSANDRA_SEEDS` — liste séparée par des virgules, pour les clusters multi-nœuds

**Configuration de la topologie :**
- `CASSANDRA_DC` et `CASSANDRA_RACK` — définissent le datacenter et le rack, pour une réplication correcte
- écrits dans `cassandra-rackdc.properties` et lus par `GossipingPropertyFileSnitch`
- valeurs par défaut : `axonopsdb_dc1` / `rack1` (à surcharger en production)

**Configuration des ressources :**
- `CASSANDRA_HEAP_SIZE` — pilote le heap JVM (-Xms et -Xmx reçoivent la même valeur)

**Exemple :**
```bash
docker run -d --name axondb \
  -e CASSANDRA_CLUSTER_NAME=production-cluster \
  -e CASSANDRA_DC=us-east-1 \
  -e CASSANDRA_RACK=1a \
  -e CASSANDRA_SEEDS=10.0.1.10,10.0.1.11,10.0.1.12 \
  -e CASSANDRA_HEAP_SIZE=16G \
  -p 9042:9042 \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

### Contrôle de l'initialisation

Les 4 dernières variables (`INIT_SYSTEM_KEYSPACES_AND_ROLES`, `INIT_TIMEOUT`, `AXONOPS_DB_USER`, `AXONOPS_DB_PASSWORD`) pilotent l'initialisation automatique qui a lieu après le démarrage de Cassandra.

**Initialisation des keyspaces système :**

Au premier démarrage d'un cluster mono-nœud vierge, le conteneur convertit automatiquement les keyspaces système de `SimpleStrategy` vers `NetworkTopologyStrategy`, pour un état prêt pour la production.

**Configuration du délai :**
Le script d'initialisation attend jusqu'à `INIT_TIMEOUT` secondes (600 par défaut, soit 10 minutes) que Cassandra soit prêt. Si votre environnement démarre lentement (heap important, disques lents), augmentez cette valeur :

```bash
docker run -d --name axondb \
  -e INIT_TIMEOUT=1200 \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

**Le processus d'initialisation :**

- ne s'exécute que sur des clusters mono-nœud avec les identifiants par défaut `cassandra/cassandra`
- détecte le nom du datacenter depuis l'instance Cassandra en cours
- convertit : `system_auth`, `system_distributed`, `system_traces`
- écrit des fichiers sémaphores, pour la coordination avec le healthcheck
- se saute si la conversion a déjà eu lieu ou si un cluster multi-nœuds est détecté

Pour le désactiver : `INIT_SYSTEM_KEYSPACES_AND_ROLES=false`

**Utilisateur de base personnalisé :**

Créer automatiquement un superutilisateur personnalisé et désactiver l'utilisateur `cassandra` par défaut :

```bash
docker run -d --name axondb \
  -e AXONOPS_DB_USER=admin \
  -e AXONOPS_DB_PASSWORD=SecurePassword123 \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  -p 9042:9042 \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0

# Connect with new credentials (after ~2 minutes for initialization)
docker exec -it axondb cqlai -u admin -p SecurePassword123
```

**Important :**
- la création d'un utilisateur personnalisé ne fonctionne que sur un cluster vierge, avec les identifiants par défaut
- l'utilisateur `cassandra` par défaut est désactivé après création de l'utilisateur personnalisé (`can_login=false`)
- la création de l'utilisateur a lieu après l'initialisation des keyspaces système
- les deux opérations sont assurées par le même script : `init-system-keyspaces.sh`
- logs de progression : `/var/log/cassandra/init-system-keyspaces.log`
- marqueurs de fin (dans le volume persistant) :
  - `/var/lib/cassandra/.axonops/init-system-keyspaces.done`
  - `/var/lib/cassandra/.axonops/init-db-user.done`

## Fonctionnalités du conteneur

### Script d'entrypoint

Le script d'entrypoint (`/usr/local/bin/docker-entrypoint.sh`) est le chef d'orchestre : il configure Cassandra et pilote le démarrage du conteneur. Il s'exécute en PID 1 via [tini](https://github.com/krallin/tini) et réalise l'initialisation critique avant de lancer Cassandra.

#### tini — un système d'init minimal

Le conteneur utilise **tini** comme système d'init (PID 1). Tini est un init minimal conçu pour les conteneurs, qui :

- **gère correctement les signaux** — transmet les signaux (SIGTERM, SIGINT) aux processus enfants, pour un arrêt propre
- **récupère les processus zombies** — nettoie les processus enfants terminés, qui s'accumuleraient sinon
- **est extrêmement léger** — un seul binaire statique (environ 10 Ko), négligeable
- **est un standard du secteur** — c'est l'init utilisé par Docker avec l'option `--init`

Le Dockerfile place tini comme wrapper d'entrypoint :
```dockerfile
ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["cassandra", "-f"]
```

L'arbre des processus est donc :
```
tini (PID 1)
  └─► docker-entrypoint.sh
       └─► cassandra -f (after exec)
```

Après `exec cassandra -f`, Cassandra remplace le script shell mais tini reste PID 1, ce qui garantit une gestion correcte des signaux pour tout le conteneur.

**En savoir plus :** [github.com/krallin/tini](https://github.com/krallin/tini)

#### Ce qu'il fait

**1. Affiche la bannière de démarrage**
- source les métadonnées de build depuis `/etc/axonops/build-info.txt`
- affiche l'information de version complète (Cassandra, Java, cqlai, jemalloc, OS)
- indique l'environnement d'exécution (détection de Kubernetes, nom d'hôte)
- affiche les informations de chaîne d'approvisionnement (digest de l'image de base)

**2. Configure le réseau et les adresses IP**
- détecte automatiquement l'IP du conteneur si `CASSANDRA_LISTEN_ADDRESS=auto`
- fixe les adresses de broadcast à partir de l'adresse d'écoute
- configure les adresses RPC (CQL) pour les connexions clientes
- garantit une configuration correcte des nœuds seeds

**3. Applique les variables d'environnement à la configuration Cassandra**
- traite toutes les variables `CASSANDRA_*`
- met à jour `cassandra.yaml` avec les réglages fournis
- modifie `cassandra-rackdc.properties` pour la configuration DC/Rack
- ajuste la taille du heap JVM dans `jvm17-server.options`
- utilise `GossipingPropertyFileSnitch` (préconfiguré dans cassandra.yaml), qui lit le DC et le rack depuis cassandra-rackdc.properties

**4. Active l'optimisation mémoire jemalloc**
- définit `LD_PRELOAD=/usr/lib64/libjemalloc.so.2`
- améliore les performances d'allocation mémoire
- repli sûr si jemalloc est introuvable

**5. Lance l'initialisation en arrière-plan**
- démarre `init-system-keyspaces.sh` en arrière-plan (non bloquant)
- ou écrit les sémaphores de saut si `INIT_SYSTEM_KEYSPACES_AND_ROLES=false`
- permet à Cassandra de démarrer immédiatement pendant que l'init attend qu'il soit prêt

**6. Démarre Cassandra**
- exécute `cassandra -f` (mode premier plan)
- remplace le processus d'entrypoint (devient PID 1)
- Cassandra devient le processus principal du conteneur

#### Ordre d'exécution

```
entrypoint.sh (PID 1 via tini)
  │
  ├─► 1. Print startup banner
  │
  ├─► 2. Set default environment variables
  │      (CASSANDRA_CLUSTER_NAME, CASSANDRA_DC, CASSANDRA_RACK, etc.)
  │
  ├─► 3. Resolve IP addresses
  │      (auto-detect if CASSANDRA_LISTEN_ADDRESS=auto)
  │
  ├─► 4. Apply environment variables to cassandra.yaml
  │      (cluster_name, num_tokens, listen_address, rpc_address, etc.)
  │
  ├─► 5. Apply DC/Rack to cassandra-rackdc.properties
  │
  ├─► 6. Apply heap size to jvm17-server.options
  │
  ├─► 7. Enable jemalloc (set LD_PRELOAD)
  │
  ├─► 8. Launch init-system-keyspaces.sh in background (&)
  │      - Non-blocking, runs in parallel with Cassandra
  │
  └─► 9. exec cassandra -f
         - Replaces entrypoint process
         - Cassandra becomes PID 1
         - Container runs Cassandra from this point
```

#### Fichiers de configuration modifiés

L'entrypoint modifie ces fichiers de configuration Cassandra à partir des variables d'environnement :

| Fichier | Ce qui est modifié | Variables d'environnement |
|------|----------------|----------------------|
| `/etc/cassandra/cassandra.yaml` | Réglages Cassandra de base | `CASSANDRA_CLUSTER_NAME`, `CASSANDRA_NUM_TOKENS`, `CASSANDRA_LISTEN_ADDRESS`, `CASSANDRA_RPC_ADDRESS`, `CASSANDRA_BROADCAST_ADDRESS`, `CASSANDRA_BROADCAST_RPC_ADDRESS`, `CASSANDRA_SEEDS` |
| `/etc/cassandra/cassandra-rackdc.properties` | Topologie datacenter et rack | `CASSANDRA_DC` (défaut : `axonopsdb_dc1`), `CASSANDRA_RACK` (défaut : `rack1`) |
| `/etc/cassandra/jvm17-server.options` | Réglages de mémoire heap de la JVM | `CASSANDRA_HEAP_SIZE` |

**Note :** le conteneur utilise `GossipingPropertyFileSnitch` (préconfiguré dans cassandra.yaml), qui lit la topologie DC/Rack dans `cassandra-rackdc.properties`. Les valeurs de DC et de rack valent `axonopsdb_dc1` et `rack1` si elles ne sont pas définies.

#### Choix de conception

**Pourquoi exec cassandra -f ?**
- `exec` remplace le processus shell par Cassandra
- Cassandra devient PID 1 et reçoit les signaux directement
- l'arrêt du conteneur est propre
- aucun shell orphelin ne consomme de ressources

**Pourquoi une initialisation en arrière-plan ?**
- le script d'init a besoin de Cassandra en fonctionnement (accès CQL)
- démarrer Cassandra d'abord permet à l'init d'attendre qu'il soit prêt
- démarrage non bloquant — le conteneur ne reste pas suspendu pendant l'init
- la sonde de démarrage du healthcheck impose la fin de l'init avant tout routage de trafic

**Pourquoi tini comme système d'init ?**
- **transmission des signaux** — garantit que SIGTERM/SIGINT atteignent Cassandra, pour un arrêt propre
- **récupération des zombies** — nettoie les processus enfants terminés (important pour le script d'init en arrière-plan)
- **bonne pratique conteneur** — évite les problèmes lorsque le moteur de conteneurs envoie un signal d'arrêt
- **surcoût minimal** — un tout petit binaire statique (environ 10 Ko), sans dépendances
- **standard du secteur** — le même init que Docker avec l'option `--init`
- sans tini, un script shell (PID 1) ne transmet pas correctement les signaux, ce qui provoque des kills forcés

**Plus d'informations :** [Why you need an init system](https://github.com/krallin/tini#why-tini) dans les conteneurs

### Bannière de version au démarrage

Tous les conteneurs affichent au démarrage une information de version complète :

```
================================================================================
AxonOps AxonDB Time-Series (Apache Cassandra 5.0.6)
Image: ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
Built: 2025-12-13T10:30:00Z
Release: https://github.com/axonops/axonops-containers/releases/tag/axondb-timeseries-1.0.0
Built by: GitHub Actions
================================================================================

Component Versions:
  Cassandra:          5.0.6
  Java:               OpenJDK Runtime Environment (Red_Hat-17.0.17.0.10-1)
  cqlai:              v0.1.2
  jemalloc:           jemalloc-5.2.1-2.el9.x86_64
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI - Universal Base Image, freely redistributable)
  Platform:           x86_64

Supply Chain Security:
  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest
  Base image digest:  sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2

Runtime Environment:
  Hostname:           axondb-node-1
  Kubernetes:         No

================================================================================
Starting Cassandra...
================================================================================
```

**Afficher la bannière :**
```bash
docker logs axondb | head -30
```

### Sondes de healthcheck

Le conteneur embarque un script de healthcheck optimisé, prenant en charge trois types de sondes, conçu pour un surcoût minimal sans sacrifier la fiabilité :

**1. Sonde de démarrage** (`healthcheck.sh startup`)
- **attend la fin des scripts d'initialisation** (essentiel avec l'init asynchrone)
- cherche les fichiers sémaphores dans le stockage persistant :
  - `/var/lib/cassandra/.axonops/init-system-keyspaces.done` (doit exister)
  - `/var/lib/cassandra/.axonops/init-db-user.done` (doit exister)
- **contrôle le champ RESULT** — échoue si l'un des sémaphores porte `RESULT=failed`
- vérifie que le processus Cassandra tourne (`pgrep -f cassandra`)
- vérifie que le port CQL (9042) écoute (test TCP via `nc`)
- **légère** — aucun appel à nodetool, seulement des contrôles de processus et de port
- **bloque le statut « Started » du pod jusqu'à la fin réussie de l'init**
- à utiliser pour : la `startupProbe` Kubernetes (garantit la fin de l'init avant tout routage de trafic)

**2. Sonde de liveness** (`healthcheck.sh liveness`)
- **ultra-légère** — prévue pour s'exécuter fréquemment (toutes les 10 secondes)
- vérifie que le processus Cassandra tourne (`pgrep -f cassandra`)
- vérifie que le port CQL (9042) écoute (test TCP via `nc`)
- **aucun appel à nodetool** — surcoût minimal, exécution très rapide
- à utiliser pour : la `livenessProbe` Kubernetes (détection d'un crash du processus Cassandra)

**3. Sonde de readiness** (`healthcheck.sh readiness`)
- vérifie que le port CQL (9042) écoute (test TCP via `nc`)
- exécute `nodetool info` pour contrôler l'état interne de Cassandra
- vérifie « Native Transport active: true » dans la sortie
- vérifie « Gossip active: true » dans la sortie
- **plus poussée** que la liveness — garantit que Cassandra est pleinement opérationnel
- à utiliser pour : la `readinessProbe` Kubernetes (contrôles du répartiteur de charge, routage du trafic)

**Healthcheck Docker :**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect axondb --format='{{json .State.Health}}' | jq
```

**Test manuel du healthcheck :**
```bash
# Test startup probe
docker exec axondb /usr/local/bin/healthcheck.sh startup

# Test liveness probe
docker exec axondb /usr/local/bin/healthcheck.sh liveness

# Test readiness probe
docker exec axondb /usr/local/bin/healthcheck.sh readiness
```

**Note :** la configuration des sondes de healthcheck est prise en charge automatiquement par les charts Helm AxonOps. Les modes ci-dessus restent disponibles pour des déploiements personnalisés.

### Initialisation automatisée (keyspaces système et utilisateur de base)

Le conteneur réalise une initialisation automatique au premier démarrage : conversion des keyspaces système et, en option, création d'un utilisateur de base personnalisé. Les deux opérations sont assurées par un unique script d'arrière-plan (`init-system-keyspaces.sh`), lancé après le démarrage de Cassandra.

#### Comment cela fonctionne (déroulé)

L'initialisation repose sur un **processus d'arrière-plan asynchrone**, coordonné par des **fichiers sémaphores**, pour garantir le bon ordonnancement :

```
1. entrypoint.sh starts (PID 1 via tini)
   │
   ├─► 2. Launches init-system-keyspaces.sh in background (&)
   │      - Does NOT block Cassandra startup
   │      - Runs in parallel with Cassandra
   │
   └─► 3. Starts Cassandra (exec cassandra -f)
        │
        ├─► Cassandra starts and begins accepting connections
        │
        ├─► init-system-keyspaces.sh waits for Cassandra to be ready
        │   - Waits for CQL port (9042) to be listening
        │   - Waits for native transport + gossip active
        │   - Converts system keyspaces to NetworkTopologyStrategy
        │   - Creates custom database user (if AXONOPS_DB_USER set)
        │   - Writes semaphore files to persistent storage:
        │       /var/lib/cassandra/.axonops/init-system-keyspaces.done
        │       /var/lib/cassandra/.axonops/init-db-user.done
        │
        └─► healthcheck.sh (startup probe) checks for semaphores
            - Blocks until BOTH semaphore files exist
            - Only then marks container as "Started"
            - Kubernetes won't route traffic until this succeeds
```

**Pourquoi ce schéma est sûr :**

1. **Cassandra doit tourner d'abord** — le script d'init a besoin d'un accès CQL
2. **Exécution en arrière-plan** — l'init ne bloque pas le démarrage de Cassandra
3. **Coordination par sémaphores** — le healthcheck attend la fin de l'init avant de déclarer le conteneur prêt
4. **Application par Kubernetes** — le pod n'est pas marqué « Started » tant que les sémaphores n'existent pas
5. **Sémaphores persistants** — stockés dans `/var/lib/cassandra` (volume), ce qui évite une réinitialisation aux redémarrages

#### Phase 1 : conversion des keyspaces système

La première phase convertit les keyspaces système de `SimpleStrategy` vers `NetworkTopologyStrategy`, pour un état prêt pour la production.

**Ce qu'elle fait :**
1. attend que Cassandra soit prêt (port CQL à l'écoute, native transport actif)
2. vérifie qu'il s'agit d'un cluster mono-nœud avec les identifiants par défaut
3. détecte le nom du datacenter depuis l'instance Cassandra en cours
4. convertit `system_auth`, `system_distributed`, `system_traces` en `NetworkTopologyStrategy`
5. écrit le sémaphore de fin dans le stockage persistant : `/var/lib/cassandra/.axonops/init-system-keyspaces.done`

**Note :** aucun repair n'est lancé, puisqu'il s'agit d'un déploiement mono-nœud (le repair n'a de sens qu'avec plusieurs réplicas).

**Contrôles de sûreté :**
- ne s'exécute que sur un cluster mono-nœud (saute les clusters multi-nœuds et écrit un sémaphore de saut)
- ne s'exécute que si le facteur de réplication vaut 1 (saute s'il a déjà été personnalisé, et écrit un sémaphore de saut)
- ne s'exécute que si `SimpleStrategy` est en place (saute si `NetworkTopologyStrategy` est déjà là, et écrit un sémaphore de saut)
- exige les identifiants par défaut `cassandra/cassandra`
- **le sémaphore est TOUJOURS écrit** (succès ou saut motivé)

#### Phase 2 : création d'un utilisateur de base personnalisé (optionnelle)

La seconde phase crée un superutilisateur personnalisé et désactive l'utilisateur `cassandra` par défaut (uniquement si les variables d'environnement le demandent).

**Ce qu'elle fait :**
1. attend la fin de l'initialisation des keyspaces système
2. crée le superutilisateur avec le nom et le mot de passe indiqués
3. lui accorde les permissions de superutilisateur
4. teste l'authentification du nouvel utilisateur
5. désactive l'utilisateur `cassandra` par défaut (`can_login=false`)
6. écrit le sémaphore de fin : `/var/lib/cassandra/.axonops/init-db-user.done`

**Exemple :**
```bash
docker run -d --name axondb \
  -e AXONOPS_DB_USER=dbadmin \
  -e AXONOPS_DB_PASSWORD=MySecurePassword123! \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0

# Wait for initialization (~2 minutes)
docker logs -f axondb

# Connect with new credentials
docker exec -it axondb cqlai -u dbadmin -p MySecurePassword123!
```

**Contrôles de sûreté :**
- ne s'exécute que si `AXONOPS_DB_USER` et `AXONOPS_DB_PASSWORD` sont tous deux définis
- ne s'exécute que sur un cluster vierge, avec les identifiants par défaut
- teste l'authentification du nouvel utilisateur avant de désactiver l'utilisateur par défaut
- annule la création de l'utilisateur si le test d'authentification échoue
- **le sémaphore est TOUJOURS écrit** (succès, saut ou échec motivé)

#### Contrôle et désactivation

**Désactiver toute l'initialisation :**
```bash
docker run -d --name axondb \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

Lorsqu'elle est désactivée, les fichiers sémaphores sont écrits immédiatement avec `RESULT=skipped`, pour que le healthcheck puisse passer.

#### Fichiers sémaphores

L'initialisation utilise des fichiers sémaphores pour se coordonner avec la sonde de démarrage du healthcheck.

**Emplacement :** `/var/lib/cassandra/.axonops/`

Les sémaphores sont stockés dans le répertoire de données de Cassandra (et non dans `/etc`) parce que :
- `/var/lib/cassandra` est généralement un volume persistant dans Kubernetes
- une fois persistants, les sémaphores survivent aux redémarrages de conteneur ou de pod
- cela évite une réinitialisation au redémarrage d'un pod (par exemple pendant un rolling update)
- le healthcheck peut passer immédiatement après un redémarrage, sans rejouer l'init

**Important :** configurez `/var/lib/cassandra` comme volume persistant (PersistentVolumeClaim) dans votre déploiement Kubernetes. Les charts Helm AxonOps le font automatiquement.

**Fichiers créés :**
- `init-system-keyspaces.done` — état de la conversion des keyspaces système
- `init-db-user.done` — état de la création de l'utilisateur personnalisé

**Format des fichiers :**
```
COMPLETED=2025-12-14T09:32:17Z
RESULT=success
REASON=initialized_to_nts
```

**Valeurs de RESULT pour init-system-keyspaces.done :**
- `success` — keyspaces système convertis avec succès
  - `initialized_to_nts` — convertis en NetworkTopologyStrategy
- `skipped` — conversion sautée sans risque (avec un REASON qui l'explique)
  - `multi_node_cluster` — cluster multi-nœuds détecté (init impossible sans risque)
  - `already_nts` — NetworkTopologyStrategy déjà en place (déjà fait)
  - `custom_rf` — facteur de réplication différent de 1 (déjà personnalisé par l'utilisateur)
  - `disabled_by_env_var` — INIT_SYSTEM_KEYSPACES_AND_ROLES=false (désactivé par l'utilisateur)
- `failed` — l'initialisation a échoué (avec un REASON) — **le script d'init se termine avec le code 1**
  - `cql_port_timeout` — le port CQL ne s'est pas ouvert dans le délai imparti (10 min par défaut, réglable via `INIT_TIMEOUT`)
  - `native_transport_timeout` — le native transport ne s'est pas activé dans le délai imparti
  - `cql_connectivity_failed` — connexion impossible avec les identifiants cassandra/cassandra
  - `dc_detection_failed` — nom du datacenter introuvable, ni via nodetool ni via cassandra-rackdc.properties

**Quand ces échecs surviennent :**
- `cql_port_timeout` / `native_transport_timeout` — Cassandra ne démarre pas correctement (consultez les logs)
- `cql_connectivity_failed` — identifiants par défaut modifiés, ou authentification mal configurée
- `dc_detection_failed` — Cassandra ne remonte pas le nom du datacenter (problème de configuration)

**Configuration du délai :**
- délai par défaut : 600 secondes (10 minutes)
- réglable via la variable d'environnement `INIT_TIMEOUT`
- exemple : `-e INIT_TIMEOUT=1200` pour 20 minutes si Cassandra démarre lentement

**Valeurs de RESULT pour init-db-user.done :**
- `success` — utilisateur personnalisé créé avec succès
  - `user_initialized` — utilisateur créé et utilisateur cassandra désactivé
  - `user_created_cassandra_disable_failed` — utilisateur créé, mais la désactivation de l'utilisateur cassandra a échoué (non fatal, le conteneur continue)
- `skipped` — création d'utilisateur sautée (avec un REASON)
  - `no_custom_user_requested` — AXONOPS_DB_USER non défini
  - `user_already_exists` — l'utilisateur personnalisé existe déjà
  - `init_disabled` — INIT_SYSTEM_KEYSPACES_AND_ROLES=false
- `failed` — la création d'utilisateur a échoué (avec un REASON) — **le script d'init se termine avec le code 1**
  - `create_user_failed` — échec de la création de l'utilisateur (CREATE ROLE CQL en échec)
  - `new_user_auth_failed` — utilisateur créé, mais le test d'authentification a échoué

**Quand ces échecs surviennent :**
- `create_user_failed` — possible si :
  - la connexion CQL échoue pendant la création de l'utilisateur
  - le format du nom d'utilisateur ou du mot de passe est invalide
  - Cassandra rencontre une erreur interne lors de la création du rôle
- `new_user_auth_failed` — possible si :
  - l'utilisateur est créé mais le système d'authentification est mal configuré
  - le mot de passe n'est pas correctement enregistré dans system_auth
  - un problème de protocole d'authentification CQL survient

**Important :** lorsque `RESULT=failed` est écrit, le script d'init se termine avec le code 1 (échec) et la sonde de démarrage du healthcheck échoue, ce qui empêche le conteneur d'être marqué « Started » dans Kubernetes.

**Garantie :** les deux fichiers sémaphores sont **TOUJOURS** écrits, quel que soit le chemin d'exécution. La sonde de démarrage du healthcheck :
1. exige l'existence des deux fichiers sémaphores
2. contrôle le champ RESULT de chacun
3. **échoue si l'un des RESULT vaut failed**
4. ne passe que si les deux valent success ou skipped

Le conteneur ne peut donc pas être marqué « Started » si l'initialisation a échoué.

#### Logs d'initialisation

Consultez la progression et le résultat de l'initialisation :

```bash
# View complete initialization log (both system keyspaces and user creation)
docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log

# Check system keyspace conversion status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-system-keyspaces.done

# Check custom user creation status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-db-user.done
```

## Pipeline CI/CD

### Workflows

Le dépôt contient des workflows GitHub Actions complets :

**Build and Test** (`.github/workflows/axondb-timeseries-build-and-test.yml`)
- **Déclencheurs :** push / PR vers les branches main, development, feature/*, fix/*
  - lorsque `axonops/axondb-timeseries/**` change (hors fichiers `*.md`)
  - lorsque les workflows (`.github/workflows/axondb-timeseries-*.yml`) changent
  - lorsque les actions (`.github/actions/axondb-timeseries-*/**`) changent
- **Tests :** build Docker, vérification de version, healthcheck, cqlai, cqlsh, analyse de sécurité
- **Durée :** environ 10 minutes

**Publication de production** (`.github/workflows/axondb-timeseries-publish-signed.yml`)
- **Déclencheur :** dispatch manuel du workflow avec un tag Git
- **Processus :** valider → tester → créer la release → construire → signer → publier → vérifier
- **Registre :** `ghcr.io/axonops/axondb-timeseries`
- **Plateformes :** linux/amd64, linux/arm64
- **Signature :** Cosign en mode keyless (OIDC)

**Publication de développement** (`.github/workflows/axondb-timeseries-development-publish-signed.yml`)
- **Déclencheur :** dispatch manuel du workflow depuis la branche development
- **Registre :** `ghcr.io/axonops/development/axondb-timeseries`
- **Usage :** tester les images avant une release de production

### Tests automatisés

Le pipeline CI comprend des tests complets :

**Tests fonctionnels :**
- vérification de la construction du conteneur (multi-architecture)
- vérification de la bannière de démarrage (production ou développement)
- vérification des versions (jemalloc, Cassandra, Java, cqlai)
- tests du script de healthcheck (startup, liveness, readiness)
- vérification de l'initialisation des keyspaces système
- opérations CQL avec cqlai
- opérations CQL avec cqlsh
- traitement des variables d'environnement

**Tests de sécurité :**
- analyse des vulnérabilités du conteneur avec Trivy (sévérités CRITICAL et HIGH)
- résultats remontés dans l'onglet Security de GitHub
- CVE amont connues documentées dans `.trivyignore`

**Actions composites (14 actions) :**
Situées dans `.github/actions/axondb-timeseries-*/` :
- `start-and-wait` — démarre le conteneur et attend qu'il soit prêt
- `verify-startup-banner` — vérifie le contenu de la bannière
- `verify-no-startup-errors` — cherche les erreurs de démarrage
- `verify-versions` — vérifie les versions des composants
- `test-healthcheck` — teste tous les modes de healthcheck
- `verify-init-scripts` — vérifie que l'initialisation s'est terminée
- `test-cqlai` — teste le fonctionnement de cqlai
- `test-cqlsh` — teste le fonctionnement de cqlsh
- `test-all-env-vars` — teste la configuration par variables d'environnement (10 Cassandra + 4 initialisation = 14 au total)
- `test-dc-detection` — teste la détection du datacenter
- `sign-container` — signature Cosign
- `verify-published-image` — vérification après publication
- `collect-logs` — collecte les logs du conteneur
- `determine-latest` — détermine les tags latest

### Processus de publication

**Release de développement :**
```bash
# Tag on development branch
git checkout development
git tag vdev-axondb-timeseries-1.0.0
git push origin vdev-axondb-timeseries-1.0.0

# Publish to development registry
gh workflow run axondb-timeseries-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=vdev-axondb-timeseries-1.0.0 \
  -f container_version=1.0.0
```

**Release de production :**
```bash
# Tag on main branch
git checkout main
git tag axondb-timeseries-1.0.0
git push origin axondb-timeseries-1.0.0

# Publish to production registry
gh workflow run axondb-timeseries-publish-signed.yml \
  --ref main \
  -f main_git_tag=axondb-timeseries-1.0.0 \
  -f container_version=1.0.0
```

Voir [RELEASE.md](./RELEASE.md) pour la documentation complète du processus de release.

## Dépannage

### Vérifier la version du conteneur

Consultez la bannière de démarrage pour voir toutes les versions des composants :

```bash
docker logs axondb | head -30
```

La bannière affiche :
- la version du conteneur et la révision git
- les versions de Cassandra, Java, cqlai et jemalloc
- le digest de l'image de base (pour la vérification de la chaîne d'approvisionnement)
- les détails de l'environnement d'exécution

### Logs du script d'initialisation

Consultez la progression et le résultat de l'initialisation :

```bash
# View init script output
docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log

# Check system keyspace init status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-system-keyspaces.done

# Check custom user creation status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-db-user.done
```

**Format des fichiers sémaphores :**
```
COMPLETED=2025-12-13T10:45:00Z
RESULT=success
```

Valeurs possibles de `RESULT` :
- `success` — opération terminée avec succès
- `skipped` — opération sautée (le champ REASON explique pourquoi)

### Déboguer le healthcheck

Testez les sondes de healthcheck à la main :

```bash
# Test all three probe types
docker exec axondb /usr/local/bin/healthcheck.sh startup
docker exec axondb /usr/local/bin/healthcheck.sh liveness
docker exec axondb /usr/local/bin/healthcheck.sh readiness

# Check Docker healthcheck status
docker inspect axondb --format='{{json .State.Health}}' | jq

# View healthcheck logs
docker exec axondb cat /var/log/cassandra/system.log | grep healthcheck
```

### Le conteneur ne démarre pas

**Consultez les logs :**
```bash
docker logs axondb
```

**Problèmes courants :**

1. **Mémoire insuffisante :**
   - le heap vaut 8G par défaut ; prévoyez au moins 12 Go de RAM pour le conteneur
   - ajustez avec : `-e CASSANDRA_HEAP_SIZE=4G`

2. **Conflits de ports :**
   - CQL : 9042
   - JMX : 7199
   - à vérifier avec : `netstat -tuln | grep 9042`

3. **Problèmes de permissions :**
   - le conteneur s'exécute sous l'utilisateur `cassandra` (UID 999)
   - assurez-vous des permissions du volume : `chown -R 999:999 /data/cassandra`

4. **Délai d'initialisation dépassé :**
   - les scripts d'init attendent Cassandra jusqu'à 10 minutes
   - à vérifier : `docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log`

**Récupérer les logs Cassandra :**
```bash
docker exec axondb cat /var/log/cassandra/system.log
```

**Vérifier que Cassandra tourne :**
```bash
docker exec axondb nodetool status
```

## Considérations de production

1. **Stockage persistant**
   - utilisez toujours des volumes pour `/var/lib/cassandra` (données)
   - utilisez des volumes pour `/var/log/cassandra` (logs)
   - exemple : `-v /data/cassandra:/var/lib/cassandra`

2. **Allocation de ressources**
   - mémoire : au moins 1,5 fois la taille du heap (par exemple 12 Go pour un heap de 8 Go)
   - CPU : 4 cœurs ou plus recommandés
   - disque : stockage SSD pour les charges de production

3. **Réseau**
   - exposez les ports nécessaires : 9042 (CQL), 7199 (JMX), 7000 (inter-nœuds)
   - appliquez des règles de pare-feu adaptées
   - envisagez TLS pour les communications inter-nœuds et clientes

4. **Sécurité**
   - utilisez un utilisateur de base personnalisé (variables `AXONOPS_DB_USER` et `AXONOPS_DB_PASSWORD`)
   - vérifiez les signatures des conteneurs avec Cosign
   - référencez les images par digest, pour l'immuabilité
   - gardez les images de base à jour (automatisé sur UBI)

5. **Supervision**
   - utilisez les sondes de healthcheck pour la supervision de disponibilité
   - surveillez l'usage du heap via JMX
   - mettez en place une agrégation des logs de `/var/log/cassandra/`
   - envisagez une intégration à AxonOps pour une supervision complète

6. **Sauvegarde et restauration**

   Ce conteneur embarque des fonctions de sauvegarde et de restauration, conçues pour des déploiements mono-nœud.

   **Démarrage rapide :**
   ```bash
   # Enable scheduled backups (every 6 hours, keep 168 hours / 7 days)
   docker run -d \
     -v /backup:/backup \
     -e BACKUP_SCHEDULE="0 */6 * * *" \
     -e BACKUP_RETENTION_HOURS=168 \
     axondb-timeseries:latest

   # Restore from backup
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     axondb-timeseries:latest
   ```

   **Points clés :**
   - sauvegardes par snapshot, avec déduplication par hardlinks (76 % d'espace économisé)
   - compatibles Kubernetes (restauration non bloquante, sûre vis-à-vis de la sonde de démarrage)
   - rétention automatique, avec suppression asynchrone
   - préservation des sémaphores `.axonops` (évite une réinitialisation à la restauration)
   - prise en charge des changements d'adresse IP
   - rotation des logs avec compression

   **Configuration :**

   | Variable | Obligatoire | Défaut | Description |
   |----------|----------|---------|-------------|
   | `BACKUP_SCHEDULE` | Non | - | Expression cron (par exemple `0 */6 * * *` pour toutes les 6 heures) |
   | `BACKUP_RETENTION_HOURS` | Si un schedule est défini | - | Durée de conservation des sauvegardes, en heures (par exemple `168` pour 7 jours) |
   | `BACKUP_MINIMUM_RETENTION_COUNT` | Non | `1` | Toujours conserver au moins N sauvegardes |
   | `BACKUP_USE_HARDLINKS` | Non | `true` | Utiliser la déduplication par hardlinks |
   | `BACKUP_CALCULATE_STATS` | Non | `false` | Calculer l'espace économisé (coûteux) |
   | `BACKUP_RSYNC_RETRIES` | Non | `3` | Nombre de tentatives rsync |
   | `BACKUP_RSYNC_TIMEOUT_MINUTES` | Non | `120` | Délai d'expiration de rsync (gros volumes) |
   | `RESTORE_FROM_BACKUP` | Non | - | Nom de la sauvegarde, ou `latest` |
   | `RESTORE_ENABLED` | Non | `false` | Activer la restauration sans nom de sauvegarde |
   | `RESTORE_RESET_CREDENTIALS` | Non | `false` | Supprimer system_auth à la restauration (retour à cassandra/cassandra) |
   | `RSYNC_BWLIMIT_KB` | Non | - | Limite de bande passante des sauvegardes, en Ko/s |
   | `ENABLE_SEMAPHORE_MONITOR` | Non | `false` | Surveiller l'état des sauvegardes / restaurations |

   **Exemple Kubernetes :**
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: axondb
   spec:
     containers:
     - name: cassandra
       image: axondb-timeseries:latest
       env:
       - name: BACKUP_SCHEDULE
         value: "0 */6 * * *"
       - name: BACKUP_RETENTION_HOURS
         value: "168"
       volumeMounts:
       - name: data
         mountPath: /var/lib/cassandra
       - name: backup
         mountPath: /backup
     volumes:
     - name: data
       persistentVolumeClaim:
         claimName: cassandra-data
     - name: backup
       persistentVolumeClaim:
         claimName: cassandra-backup
   ```

   **Restaurer depuis une sauvegarde (recréation du pod) :**
   ```yaml
   # After pod deletion, restore from backup on new pod
   env:
   - name: RESTORE_FROM_BACKUP
     value: "latest"  # or specific: "backup-20251226-120000"
   ```

   **Points importants :**
   - **Mono-nœud uniquement** : les sauvegardes sont conçues pour des clusters mono-nœud
   - **Les hardlinks sont locaux** : en copiant les sauvegardes vers un stockage distant (S3, NFS), les hardlinks deviennent des fichiers indépendants (copie intégrale)
   - **Préservation de `.axonops`** : les sémaphores d'init sont sauvegardés et restaurés, pour éviter une réinitialisation
   - **Restauration non bloquante** : la restauration s'exécute en arrière-plan, le conteneur démarre normalement (compatible K8s)
   - **Identifiants préservés** : les identifiants personnalisés issus de la sauvegarde sont restaurés automatiquement (sauf si `RESTORE_RESET_CREDENTIALS=true`)
   - **Réinitialisation des identifiants** (`RESTORE_RESET_CREDENTIALS=true`) : supprime tous les utilisateurs et rôles de la sauvegarde
     - retour à cassandra/cassandra (l'utilisateur personnalisé est recréé si AXONOPS_DB_USER est défini)
     - toutes les permissions et attributions de la sauvegarde sont perdues
     - à utiliser pour les restaurations prod → dev, lorsque la réinitialisation des identifiants est souhaitée

   **Emplacement des sauvegardes :**
   - montez un volume `/backup` pour la persistance
   - les sauvegardes sont stockées ainsi : `/backup/data_backup-YYYYMMDD-HHMMSS/`
   - elles comprennent un export du schéma (`schema.cql`) et les snapshots de données

   **Exemples de restauration :**
   ```bash
   # Restore latest backup
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="latest" \
     axondb-timeseries:latest

   # Restore specific backup
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     axondb-timeseries:latest

   # List available backups
   ls -1dt /backup/data_backup-* | head -10

   # Restore with credential reset (prod → dev)
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     -e RESTORE_RESET_CREDENTIALS=true \
     axondb-timeseries:latest
   # After restore: credentials are cassandra/cassandra

   # Restore with credential reset + new custom user
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     -e RESTORE_RESET_CREDENTIALS=true \
     -e AXONOPS_DB_USER=devuser \
     -e AXONOPS_DB_PASSWORD=devpass123 \
     axondb-timeseries:latest
   # After restore: credentials are devuser/devpass123 (auto-created)
   ```

   **Superviser les sauvegardes :**
   ```bash
   # Enable semaphore monitor (logs backup/restore state every 60s)
   docker run -d \
     -e BACKUP_SCHEDULE="0 */6 * * *" \
     -e BACKUP_RETENTION_HOURS=168 \
     -e ENABLE_SEMAPHORE_MONITOR=true \
     axondb-timeseries:latest

   # Check backup logs
   docker exec axondb cat /var/log/cassandra/backup-cron.log
   docker exec axondb cat /var/log/cassandra/retention-cleanup.log

   # Check restore logs
   docker exec axondb cat /var/log/cassandra/restore.log
   ```

   **Dépannage :**

   | Problème | À vérifier | Solution |
   |-------|-------|----------|
   | Aucune sauvegarde créée | `cat /var/log/cassandra/backup-scheduler.log` | Vérifier que BACKUP_SCHEDULE est une expression cron valide |
   | La rétention ne s'applique pas | `cat /var/log/cassandra/retention-cleanup.log` | Vérifier que BACKUP_RETENTION_HOURS est défini |
   | La restauration échoue | `cat /var/log/cassandra/restore.log` | Vérifier que la sauvegarde existe : `ls /backup/data_backup-*` |
   | L'init se relance à la restauration | `cat /var/lib/cassandra/.axonops/init-*.done` | Vérifier la présence de .axonops dans la sauvegarde |
   | Erreurs de verrou | `cat /tmp/axonops-backup.lock` | Attendre la fin de la sauvegarde précédente |

   Pour les tests détaillés, voir [tests/README.md](./5.0.6/tests/README.md).

7. **Déploiement en cluster**
   - utilisez les mêmes `CASSANDRA_DC` et `CASSANDRA_RACK` sur tous les nœuds
   - renseignez `CASSANDRA_SEEDS` avec plusieurs nœuds seeds
   - définissez `CASSANDRA_CLUSTER_NAME` de façon cohérente
   - anticipez les déploiements multi-datacenters si nécessaire

Pour le workflow de développement et les tests, voir [DEVELOPMENT.md](./DEVELOPMENT.md).

Pour le processus de release, voir [RELEASE.md](./RELEASE.md).
