# AxonOps Schema Registry

[English](README.md) | **Français** | [Español](README.es.md) | [Galego](README.gl.md)

[![Paquet GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axonops-schema-registry)

Schema Registry Kafka compatible Confluent, prêt pour la production, avec prise en charge de plusieurs backends de stockage, construit sur Red Hat UBI 9.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Images Docker préconstruites](#images-docker-préconstruites)
  - [Images disponibles](#images-disponibles)
  - [Stratégie de tags](#stratégie-de-tags)
- [Bonne pratique de production](#bonne-pratique-de-production)
- [Construire les images Docker](#construire-les-images-docker)
- [Variables d'environnement](#variables-denvironnement)
- [Fonctionnalités du conteneur](#fonctionnalités-du-conteneur)
  - [Script d'entrypoint](#script-dentrypoint)
  - [Bannière de version au démarrage](#bannière-de-version-au-démarrage)
  - [Sondes de healthcheck](#sondes-de-healthcheck)
- [Pipeline CI/CD](#pipeline-cicd)
  - [Workflows](#workflows)
  - [Tests automatisés](#tests-automatisés)
  - [Processus de publication](#processus-de-publication)
- [Dépannage](#dépannage)
  - [Vérifier la version du conteneur](#vérifier-la-version-du-conteneur)
  - [Déboguer le healthcheck](#déboguer-le-healthcheck)
  - [Le conteneur ne démarre pas](#le-conteneur-ne-démarre-pas)
- [Considérations de production](#considérations-de-production)

## Vue d'ensemble

AxonOps Schema Registry est un Schema Registry Kafka compatible Confluent qui assure la gestion des schémas avec plusieurs backends de stockage. C'est un binaire Go unique et sans état, qui expose une API REST sur le port 8081.

**Fonctionnalités du conteneur :**
- **Stockage multi-backend** : backends PostgreSQL, MySQL, Cassandra 5+ et en mémoire
- **Compatible avec l'API Confluent** : remplacement direct du Schema Registry Confluent
- **Base entreprise** : construit sur Red Hat UBI 9 minimal, pour la stabilité en production
- **Sécurité de la chaîne d'approvisionnement** : images de base épinglées par digest, pour des builds immuables
- **Supervision de production** : sondes de healthcheck intégrées (startup, liveness, readiness)
- **Léger** : un seul binaire Go, empreinte mémoire d'environ 50 Mo

**Endpoints de l'API :**
- Vérification de santé : `GET /`
- Documentation Swagger : `GET /docs`
- API Schema Registry : port 8081

## Images Docker préconstruites

Des images préconstruites sont disponibles sur le GitHub Container Registry (GHCR). C'est la façon la plus simple de démarrer.

### Images disponibles

Toutes les images sont disponibles à l'adresse : `ghcr.io/axonops/axonops-schema-registry`

Parcourir tous les tags disponibles : [GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axonops-schema-registry)

### Stratégie de tags

Les images suivent une stratégie de tags multidimensionnelle, avec deux axes indépendants :

- **SR_VERSION** — version applicative du Schema Registry (par exemple `0.2.0`)
- **CONTAINER_VERSION** — version du conteneur (semver, par exemple `0.0.1`, `0.0.2`, `0.1.0`)

| Forme du tag | Exemple | Description | Cas d'usage |
|-------------|---------|-------------|----------|
| `{SR_VERSION}-{CONTAINER_VERSION}` | `0.2.0-0.0.1` | Totalement immuable (version SR + version du conteneur) | **Production** : épingler les versions exactes pour une traçabilité complète |
| `@sha256:<digest>` | `@sha256:abc123...` | Fondé sur le digest (immuable cryptographiquement) | **Sécurité maximale** : intégrité de l'image garantie |
| `{SR_VERSION}` | `0.2.0` | Dernière version de conteneur pour cette version de SR | Suivre les mises à jour du conteneur pour une version de SR donnée |
| `latest` | `latest` | La plus récente, toutes versions confondues | Essais rapides uniquement (PAS pour la production) |

**Exemples de tags :**

Lorsque `0.2.0-0.0.1` est construit (et qu'il s'agit du plus récent) :
- `0.2.0-0.0.1` (immuable — ne change jamais)
- `0.2.0` (flottant — se déplace vers les versions de conteneur plus récentes de la même version de SR)
- `latest` (flottant — se déplace vers les versions de SR plus récentes)

Lorsque `0.2.0-0.0.2` est construit (montée de version du conteneur seul, même version de SR) :
- `0.2.0-0.0.2` (immuable — ne change jamais)
- `0.2.0` (flottant — pointe désormais vers la version de conteneur 0.0.2)
- `latest` (flottant — pointe désormais vers la version de conteneur 0.0.2)

Lorsque `0.3.0-0.0.1` est construit (nouvelle version de SR, la version du conteneur repart à 0.0.1) :
- `0.3.0-0.0.1` (immuable — ne change jamais)
- `0.3.0` (flottant — dernière version de conteneur de 0.3.0)
- `latest` (flottant — pointe désormais vers 0.3.0-0.0.1)

## Bonne pratique de production

**Utiliser `latest` ou des tags flottants en production est un anti-pattern**. Cela vaut pour `latest` comme pour `0.2.0`, parce que :
- **Aucune traçabilité** : impossible de déterminer la version exacte déployée à un instant donné
- **Mises à jour inattendues** : les orchestrateurs de conteneurs peuvent tirer de nouvelles images lors d'un redémarrage
- **Retours arrière difficiles** : impossible de revenir de façon fiable à une version antérieure
- **Problèmes de conformité** : de nombreux référentiels exigent un suivi de version immuable

**Stratégies de déploiement recommandées (par ordre de sécurité) :**

1. **Référence absolue — par digest** (sécurité maximale)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry@sha256:abc123...
   ```
   - immuable à 100 %, garanti cryptographiquement
   - requis dans les environnements réglementés
   - vérifiez la signature avec Cosign (voir ci-dessous)

2. **Tag immuable** (standard de production)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
   ```
   - épinglé sur une version précise (SR 0.2.0, conteneur 0.0.1)
   - facile à lire et à gérer
   - traçabilité complète conservée

3. **Tags flottants** (développement / test uniquement)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry:latest
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
  ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1

# Check signature exists
cosign tree ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
```

## Construire les images Docker

Si vous préférez construire les images vous-même plutôt que d'utiliser les images préconstruites :

```bash
cd axonops-schema-registry

# Minimal build (required args only)
docker build \
  -t axonops-schema-registry:0.2.0-0.0.1 \
  .

# Multi-arch build (amd64 + arm64) using buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t axonops-schema-registry:0.2.0-0.0.1 \
  .
```

**Arguments de build optionnels (ils enrichissent les métadonnées mais ne sont pas obligatoires) :**
- `SR_VERSION` — version du Schema Registry (défaut : `0.2.0`)
- `BUILD_DATE` — horodatage du build (format ISO 8601, par exemple `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF` — SHA du commit Git (par exemple `$(git rev-parse HEAD)`)
- `VERSION` — chaîne de version complète (par exemple `0.2.0-0.0.1`)
- `CONTAINER_VERSION` — version du conteneur (par exemple `0.0.1`)
- `GIT_TAG` — nom du tag Git (pour les liens de release / tag de la bannière)
- `GITHUB_ACTOR` — utilisateur ayant déclenché le build (pour la traçabilité)
- `IS_PRODUCTION_RELEASE` — mettre à `true` pour la production (défaut : `false`)
- `IMAGE_FULL_NAME` — nom complet de l'image avec son tag (affiché dans la bannière de démarrage)

**Sécurité de la chaîne d'approvisionnement :**

Notre Dockerfile utilise des images de base épinglées par digest, pour la sécurité de la chaîne d'approvisionnement :

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
ARG UBI9_MINIMAL_DIGEST=sha256:1bc3c5c15720506a0cf48adfdf8b623dfe704377e007d7bbae8d14876392ca6a
FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
```

## Variables d'environnement

Le Schema Registry se configure principalement via son fichier de configuration YAML (`/etc/axonops-schema-registry/config.yaml`). Vous pouvez le remplacer en montant votre propre fichier de configuration.

| Variable | Description | Défaut |
|----------|-------------|---------|
| `SR_PORT` | Port de l'API utilisé par le script de healthcheck | `8081` |
| `HEALTH_CHECK_TIMEOUT` | Délai d'expiration du healthcheck, en secondes | `10` |

**Configuration personnalisée :**

Montez votre propre fichier de configuration pour remplacer celui par défaut :

```bash
docker run -d --name schema-registry \
  -v /path/to/config.yaml:/etc/axonops-schema-registry/config.yaml:ro \
  -p 8081:8081 \
  ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
```

## Fonctionnalités du conteneur

### Script d'entrypoint

Le script d'entrypoint (`/usr/local/bin/docker-entrypoint.sh`) affiche la bannière de démarrage puis exécute le processus principal. Il tourne via [tini](https://github.com/krallin/tini), pour une gestion correcte des signaux et le nettoyage des processus zombies.

```dockerfile
ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["axonops-schema-registry", "--config", "/etc/axonops-schema-registry/config.yaml"]
```

Arbre des processus :
```
tini (PID 1)
  └── docker-entrypoint.sh
       └── axonops-schema-registry (after exec)
```

### Bannière de version au démarrage

Tous les conteneurs affichent au démarrage une information de version complète :

```
================================================================================
AxonOps Schema Registry 0.2.0
Image: ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
Built: 2025-12-13T10:30:00Z
Release: https://github.com/axonops/axonops-containers/releases/tag/axonops-schema-registry-0.2.0-0.0.1
Built by: GitHub Actions
================================================================================

Component Versions:
  Schema Registry:    0.2.0
  Binary Version:     v0.2.0
  Container Version:  0.0.1
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI)
  Platform:           x86_64

Supply Chain Security:
  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest
  Base image digest:  sha256:6fc28bcb6776e387...

Runtime Environment:
  Hostname:           schema-registry-1

================================================================================
Starting Schema Registry...
================================================================================
```

**Afficher la bannière :**
```bash
docker logs schema-registry | head -25
```

### Sondes de healthcheck

Le conteneur embarque un script de healthcheck prenant en charge trois types de sondes :

**1. Sonde de démarrage** (`healthcheck.sh startup`)
- vérifie que le processus Schema Registry tourne (`pgrep`)
- vérifie que le port de l'API répond aux requêtes HTTP
- à utiliser pour : la `startupProbe` Kubernetes

**2. Sonde de liveness** (`healthcheck.sh liveness`)
- vérifie que le processus Schema Registry tourne (`pgrep`)
- ultra-légère, exécutée fréquemment
- à utiliser pour : la `livenessProbe` Kubernetes

**3. Sonde de readiness** (`healthcheck.sh readiness`)
- vérification HTTP complète sur l'endpoint `GET /`
- contrôle la réponse HTTP 200
- à utiliser pour : la `readinessProbe` Kubernetes et le HEALTHCHECK Docker

**Healthcheck Docker :**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect schema-registry --format='{{json .State.Health}}' | jq
```

**Test manuel du healthcheck :**
```bash
# Test startup probe
docker exec schema-registry /usr/local/bin/healthcheck.sh startup

# Test liveness probe
docker exec schema-registry /usr/local/bin/healthcheck.sh liveness

# Test readiness probe
docker exec schema-registry /usr/local/bin/healthcheck.sh readiness
```

## Pipeline CI/CD

### Workflows

**Build et test** (`.github/workflows/axonops-schema-registry-build-and-test.yml`)
- **Déclencheurs :** push / PR vers les branches main, development, feature/*, fix/*
  - lorsque `axonops-schema-registry/**` change (hors fichiers `*.md`)
  - lorsque les workflows (`.github/workflows/axonops-schema-registry-*.yml`) changent
  - lorsque les actions (`.github/actions/axonops-schema-registry-*/**`) changent
- **Tests :** build Docker, vérification de version, healthcheck, tests d'API, analyse de sécurité
- **Durée :** environ 5 minutes

**Publication de production** (`.github/workflows/axonops-schema-registry-publish-signed.yml`)
- **Déclencheur :** dispatch manuel du workflow avec un tag Git
- **Processus :** valider -> tester -> créer la release -> construire -> signer -> publier -> vérifier
- **Registre :** `ghcr.io/axonops/axonops-schema-registry`
- **Plateformes :** linux/amd64, linux/arm64
- **Signature :** Cosign en mode keyless (OIDC)

**Publication de développement** (`.github/workflows/axonops-schema-registry-development-publish-signed.yml`)
- **Déclencheur :** dispatch manuel du workflow depuis la branche development
- **Registre :** `ghcr.io/axonops/development/axonops-schema-registry`
- **Usage :** tester les images avant une release de production

### Tests automatisés

Le pipeline CI comprend :

**Tests fonctionnels :**
- vérification de la construction du conteneur (multi-architecture)
- vérification de la bannière de démarrage (production ou développement)
- vérification des versions (version de SR, version du conteneur)
- tests du script de healthcheck (startup, liveness, readiness)
- tests de l'API Schema Registry (`GET /`)

**Tests de sécurité :**
- analyse des vulnérabilités du conteneur avec Trivy (sévérités CRITICAL et HIGH)
- résultats remontés dans l'onglet Security de GitHub
- CVE amont connues documentées dans `.trivyignore`

### Processus de publication

**Release de développement :**
```bash
# Tag on development branch
git checkout development
git pull origin development
git tag vdev-axonops-schema-registry-0.2.0-0.0.1
git push origin vdev-axonops-schema-registry-0.2.0-0.0.1

# Publish to development registry
gh workflow run axonops-schema-registry-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=vdev-axonops-schema-registry-0.2.0-0.0.1 \
  -f sr_version=0.2.0 \
  -f container_version=0.0.1
```

**Release de production :**
```bash
# Tag on main branch
git checkout main
git pull origin main
git tag axonops-schema-registry-0.2.0-0.0.1
git push origin axonops-schema-registry-0.2.0-0.0.1

# Publish to production registry
gh workflow run axonops-schema-registry-publish-signed.yml \
  --ref main \
  -f main_git_tag=axonops-schema-registry-0.2.0-0.0.1 \
  -f sr_version=0.2.0 \
  -f container_version=0.0.1
```

Voir [RELEASE.md](./RELEASE.md) pour la documentation complète du processus de release.

## Dépannage

### Vérifier la version du conteneur

Consultez la bannière de démarrage pour voir toutes les versions des composants :

```bash
docker logs schema-registry | head -25
```

### Déboguer le healthcheck

Testez les sondes de healthcheck à la main :

```bash
# Test all three probe types
docker exec schema-registry /usr/local/bin/healthcheck.sh startup
docker exec schema-registry /usr/local/bin/healthcheck.sh liveness
docker exec schema-registry /usr/local/bin/healthcheck.sh readiness

# Check Docker healthcheck status
docker inspect schema-registry --format='{{json .State.Health}}' | jq

# Test API directly
curl -s http://localhost:8081/
```

### Le conteneur ne démarre pas

**Consultez les logs :**
```bash
docker logs schema-registry
```

**Problèmes courants :**

1. **Conflits de ports :**
   - API Schema Registry : 8081
   - à vérifier avec : `netstat -tuln | grep 8081`

2. **Problèmes de permissions :**
   - le conteneur s'exécute sous l'utilisateur `schemaregistry` (UID 999)
   - assurez-vous des permissions du volume : `chown -R 999:999 /data/schema-registry`

3. **Problèmes de configuration :**
   - vérifiez le fichier de configuration : `docker exec schema-registry cat /etc/axonops-schema-registry/config.yaml`

## Considérations de production

1. **Stockage persistant**
   - utilisez des volumes pour `/var/lib/axonops-schema-registry` (données)
   - utilisez des volumes pour `/var/log/axonops-schema-registry` (logs)

2. **Allocation de ressources**
   - mémoire : environ 50 Mo en usage courant, allouez au minimum 256 Mo
   - CPU : un cœur suffit pour la plupart des charges

3. **Réseau**
   - exposez le port 8081 pour l'API Schema Registry
   - appliquez des règles de pare-feu adaptées

4. **Sécurité**
   - vérifiez les signatures des conteneurs avec Cosign
   - référencez les images par digest, pour l'immuabilité
   - gardez les images de base à jour

5. **Supervision**
   - utilisez les sondes de healthcheck pour la supervision de disponibilité
   - surveillez les temps de réponse de l'API via `GET /`
   - mettez en place une agrégation des logs de `/var/log/axonops-schema-registry/`

6. **Haute disponibilité**
   - le Schema Registry est sans état lorsqu'il utilise un backend de stockage externe
   - exécutez plusieurs instances derrière un répartiteur de charge pour la HA

Pour le workflow de développement et les tests, voir [DEVELOPMENT.md](./DEVELOPMENT.md).

Pour le processus de release, voir [RELEASE.md](./RELEASE.md).
