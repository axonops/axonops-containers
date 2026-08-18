# Conteneurs AxonOps K8ssandra

[English](README.md) | **Français**

[![Paquet GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra)

Conteneurs Docker d'Apache Cassandra intégrant l'agent de supervision et de gestion AxonOps, conçus pour un déploiement sur Kubernetes avec l'opérateur K8ssandra.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Images Docker préconstruites](#images-docker-préconstruites)
  - [Images disponibles](#images-disponibles)
  - [Versions de Cassandra prises en charge](#versions-de-cassandra-prises-en-charge)
- [Bonne pratique de production](#bonne-pratique-de-production)
- [Démarrage rapide avec Docker/Podman](#démarrage-rapide-avec-dockerpodman)
  - [Utilisation avec Kubernetes (K8ssandra)](#utilisation-avec-kubernetes-k8ssandra)
- [Prérequis](#prérequis)
- [Lignes de Cassandra](#lignes-de-cassandra)
- [Prise en main](#prise-en-main)
- [Construire les images Docker](#construire-les-images-docker)
  - [Ajouter la prise en charge d'une nouvelle version de Cassandra](#ajouter-la-prise-en-charge-dune-nouvelle-version-de-cassandra)
  - [Mettre à jour pour une nouvelle version de la Management API k8ssandra](#mettre-à-jour-pour-une-nouvelle-version-de-la-management-api-k8ssandra)
- [Déployer sur Kubernetes](#déployer-sur-kubernetes)
  - [Utiliser la configuration d'exemple](#utiliser-la-configuration-dexemple)
  - [Vérifier le déploiement](#vérifier-le-déploiement)
  - [Se connecter au cluster](#se-connecter-au-cluster)
  - [Principales options de configuration](#principales-options-de-configuration)
- [Configuration](#configuration)
  - [Configuration de l'agent AxonOps](#configuration-de-lagent-axonops)
  - [Variables d'environnement du conteneur](#variables-denvironnement-du-conteneur)
  - [Healthcheck](#healthcheck)
- [Référence des scripts](#référence-des-scripts)
  - [scripts/install_k8ssandra.sh](#scriptsinstall_k8ssandrash)
  - [scripts/rebuild.sh](#scriptsrebuildsh)
- [Exemples](#exemples)
  - [examples/k8ssandra/cluster-axonops-ubi.yaml](#examplesk8ssandracluster-axonops-ubiyaml)
  - [Adapter l'exemple](#adapter-lexemple)
- [Pipeline CI/CD](#pipeline-cicd)
  - [Builds et tests automatisés](#builds-et-tests-automatisés)
- [Fonctionnalités du conteneur](#fonctionnalités-du-conteneur)
  - [Bannière de version au démarrage](#bannière-de-version-au-démarrage)
- [Supervision avec AxonOps](#supervision-avec-axonops)
- [Dépannage](#dépannage)
  - [Vérifier la version du conteneur](#vérifier-la-version-du-conteneur)
  - [Problèmes de connexion de l'agent](#problèmes-de-connexion-de-lagent)
  - [Erreurs de pull d'image](#erreurs-de-pull-dimage)
  - [Le cluster ne démarre pas](#le-cluster-ne-démarre-pas)
- [Considérations de production](#considérations-de-production)

## Vue d'ensemble

Ce dépôt fournit des images Docker préconfigurées combinant :
- Apache Cassandra 5.0.x
- la Management API K8ssandra
- l'agent AxonOps de supervision et de gestion
- [cqlai](https://github.com/axonops/cqlai) — un shell CQL moderne

Ces conteneurs sont optimisés pour des déploiements Kubernetes avec l'opérateur K8ssandra et disposent de pipelines CI/CD automatisés de construction et de publication vers le GitHub Container Registry.

**Note :** seules les versions Cassandra 5.0 sont publiées pour l'instant. La prise en charge de Cassandra 4.0 et 4.1 existe dans le dépôt mais n'est pas publiée, en raison de problèmes de compatibilité de l'agent AxonOps. Contactez-nous si vous avez besoin de 4.0 ou 4.1.

## Images Docker préconstruites

Des images préconstruites sont disponibles sur le GitHub Container Registry (GHCR). C'est la façon la plus simple de démarrer.

### Images disponibles

Les images suivent une stratégie de tags à trois dimensions, avec suivi de la version de l'API k8ssandra :

| Forme du tag | Exemple | Description | Cas d'usage |
|-------------|---------|-------------|----------|
| `{CASS}-v{K8S_API}-{AXON}` | `5.0.6-v0.1.110-1.0.0` | Totalement immuable (les 3 versions) | **Production** : épingler les versions exactes pour une traçabilité complète |
| `@sha256:<digest>` | `@sha256:412c852...` | Fondé sur le digest (immuable) | **Sécurité maximale** : image garantie cryptographiquement (voir [Déploiement sécurisé de référence](../README.fr.md#déploiement-sécurisé-de-référence)) |
| `{CASS}-v{K8S_API}` | `5.0.6-v0.1.110` | Dernier AxonOps pour ce couple Cassandra + k8ssandra | Suivre les mises à jour d'AxonOps pour un couple Cassandra + k8ssandra donné |
| `{CASS}` | `5.0.6` | Dernières API k8ssandra + AxonOps pour cette version mineure de Cassandra | Suivre les mises à jour k8ssandra + AxonOps d'une version mineure de Cassandra |
| `{MAJOR}-latest` | `5.0-latest` | Dernière mineure de la majeure Cassandra 5.0 | Suivre la dernière 5.0.x et ses composants |
| `latest` | `latest` | La plus récente, toutes majeures confondues | Essais rapides (migre vers 5.1, 5.2, 6.0 dès leur sortie) |

**Dimensions de versionnage :**
- **CASS** — version de Cassandra (par exemple 5.0.6)
- **K8S_API** — version de la Management API k8ssandra (par exemple v0.1.110)
- **AXON** — version du conteneur AxonOps (par exemple 1.0.0, en SemVer)

**Exemples de tags :**

Lorsque `5.0.6-v0.1.110-1.0.0` est construit (et qu'il est le plus récent sur tous les axes) :
- `5.0.6-v0.1.110-1.0.0` (immuable — ne change jamais)
- `5.0.6-v0.1.110` (flottant — se déplace vers les builds AxonOps plus récents)
- `5.0.6` (flottant — se déplace lors d'une mise à jour de l'API k8ssandra ou d'AxonOps)
- `5.0-latest` (flottant — se déplace à la sortie d'une 5.0.x plus récente, par exemple 5.0.7)
- `latest` (flottant — **passe à 5.1, 5.2, 6.0 à la sortie d'une nouvelle majeure de Cassandra**)

### Versions de Cassandra prises en charge

La liste des versions vit à un seul endroit : la section `build_matrix` de
[`versions.yaml`](../versions.yaml), à la racine du dépôt. Chaque matrice de workflow,
chaque tag flottant et chaque version par défaut en est dérivé, si bien que ce README ne
peut pas diverger de ce qui est réellement construit. Lisez la liste courante avec :

```bash
./scripts/build-matrix.sh versions      # toutes les versions publiées
./scripts/build-matrix.sh newest        # ce que `latest` désigne
```

**Actuellement publiées :**
- **5.0.x :** 5.0.1, 5.0.2, 5.0.3, 5.0.4, 5.0.5, 5.0.6, 5.0.7, 5.0.8 (8 versions).
  La plus récente est la 5.0.8, `latest` et `5.0-latest` la désignent donc.

**Politique de prise en charge.** Un correctif de Cassandra entre dans la matrice quand
deux conditions sont réunies : Apache l'a publié, et k8ssandra a publié l'image de base
`cass-management-api` correspondante. Ces images sont construites `FROM` cette base, la
seconde condition est donc stricte — une version ajoutée trop tôt fait échouer tous ses
jobs de build avec « No k8ssandra version found ». Rien n'est retiré de la matrice quand
un correctif plus récent paraît : les anciens continuent d'être construits et analysés,
pour qu'un déploiement épinglé reste sur sa version tout en recevant les reconstructions.
Une ligne n'est abandonnée que lorsqu'elle est en fin de vie en amont, et cela est
consigné dans `versions.yaml` avec la raison.

**Non construites :**
- **5.0.9 :** publiée par Apache, mais k8ssandra ne publie aucune image
  `cass-management-api` 5.0.9. Vérifiez si elle est apparue avec :

  ```bash
  curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=5.0.9-ubi" | \
    jq -r '.results[].name'
  ```

  Quand ce sera le cas, suivez [Ajouter la prise en charge de nouvelles versions de Cassandra](#ajouter-la-prise-en-charge-de-nouvelles-versions-de-cassandra).
- **4.0.x et 4.1.x :** les Dockerfiles sont entretenus dans `k8ssandra/4.0/` et
  `k8ssandra/4.1/`, mais aucune image n'est publiée — l'agent AxonOps n'est pas encore
  compatible avec les images de base 4.x en JDK 11. Les deux lignes sont déclarées
  `published: false` dans `versions.yaml` avec cette raison, et tous les workflows les
  ignorent. Contactez-nous si vous en avez besoin.

Parcourir tous les tags disponibles : [GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra)

## 💡 Bonne pratique de production

⚠️ **Utiliser N'IMPORTE QUEL tag `-latest` en production est un anti-pattern**. Cela vaut pour `latest`, `5.0-latest` et `5.0.6-latest`, parce que :
- **Aucune traçabilité** : impossible de déterminer la version exacte déployée à un instant donné
- **Mises à jour inattendues** : Kubernetes peut tirer une nouvelle image au redémarrage d'un pod, changeant la version à votre insu
- **Retours arrière difficiles** : impossible de revenir de façon fiable à une version antérieure
- **Problèmes de conformité** : de nombreux référentiels exigent un suivi de version immuable

👍 **Stratégies de déploiement recommandées (par ordre de sécurité) :**

1. **🥇 Référence absolue — par digest** (sécurité maximale)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra@sha256:412c852252ec4ebcb8d377a505881828a7f6a5f9dc725cc4f20fda2a1bcb3494"
   ```
   - immuable à 100 %, garanti cryptographiquement
   - requis dans les environnements réglementés
   - voir [Déploiement sécurisé de référence](../README.fr.md#déploiement-sécurisé-de-référence)

2. **🥈 Tag immuable** (standard de production)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5"
   ```
   - épinglé sur une version précise (Cassandra 5.0.6 + API k8ssandra v0.1.110 + AxonOps 1.0.5)
   - facile à lire et à gérer
   - traçabilité complète conservée

3. **🥉 Tags latest** (développement / test uniquement)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra:latest"
   ```
   - itération rapide
   - PAS pour la production
   - à réserver aux POC et aux tests

**Gestion des CVE :** voir la [politique CVE](../README.fr.md#politique-cve) pour savoir comment nous traitons les vulnérabilités de sécurité et les publications de versions.

**Mise à jour de l'image avec K8ssandra :** lorsque vous changez l'image de conteneur dans votre manifeste K8ssandraCluster, l'opérateur K8ssandra prend en charge le rolling update. Voir la [documentation de l'opérateur K8ssandra](https://docs.k8ssandra.io/) pour les procédures de montée de version et les bonnes pratiques.

## Démarrage rapide avec Docker/Podman

Lancer une instance Cassandra mono-nœud en local, à des fins de test :

```bash
# Pull the latest 5.0 image (TESTING ONLY - not for production!)
# Note: 5.0-latest is a floating tag that points to the latest 5.0.x minor + components
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0-latest

# Run with AxonOps agent (replace with your credentials)
docker run -d --name cassandra \
  -e AXON_AGENT_KEY="your-axonops-agent-key" \
  -e AXON_AGENT_ORG="your-organization" \
  -e AXON_AGENT_SERVER_HOST="agents.axonops.cloud" \
  -p 9042:9042 \
  -p 8080:8080 \
  ghcr.io/axonops/k8ssandra/cassandra:5.0-latest

# Wait for Cassandra to be ready (check Management API)
curl http://localhost:8080/api/v0/probes/readiness

# Connect using cqlai (included in the image)
docker exec -it cassandra cqlai
```

**⚠️ En production, épinglez une version immuable précise :**
```bash
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

### Utilisation avec Kubernetes (K8ssandra)

Pour un déploiement Kubernetes, utilisez l'image avec l'opérateur K8ssandra :

```bash
export IMAGE_NAME="ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5"
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"

cat examples/k8ssandra/cluster-axonops-ubi.yaml | envsubst | kubectl apply -f -
```

Voir [Déployer sur Kubernetes](#déployer-sur-kubernetes) pour les instructions détaillées.

## Prérequis

- Un cluster Kubernetes (local ou cloud)
- kubectl configuré pour accéder à votre cluster
- Helm 3.x
- Docker (pour les builds locaux)
- envsubst (pour la substitution de variables d'environnement dans les fichiers YAML)
  - macOS : `brew install gettext`
  - Linux : généralement préinstallé, sinon `apt install gettext` / `yum install gettext`
- Un compte AxonOps avec une clé d'API et un identifiant d'organisation valides (voir le [guide de mise en route AxonOps Cloud](https://docs.axonops.com/get_started/cloud/))

## Lignes de Cassandra

Les versions construites, et la politique qui les gouverne, sont décrites dans
[Versions de Cassandra prises en charge](#versions-de-cassandra-prises-en-charge)
ci-dessus — la liste n'est pas répétée ici, parce que la copie qui occupait cette
section annonçait encore 5.0.1 à 5.0.6 longtemps après la publication des 5.0.7 et
5.0.8. Ce qui suit est ce qui distingue les lignes entre elles.

| Ligne | Image de base | JDK | Répertoire de build | Publiée |
|-------|---------------|-----|---------------------|---------|
| 5.0 | `k8ssandra/cass-management-api:5.0-ubi` | 17 | `k8ssandra/5.0/` | Oui |
| 4.1 | `k8ssandra/cass-management-api:4.1-ubi` | 11 | `k8ssandra/4.1/` | Non — compatibilité de l'agent AxonOps |
| 4.0 | `k8ssandra/cass-management-api:4.0-ubi` | 11 | `k8ssandra/4.0/` | Non — compatibilité de l'agent AxonOps |

Chaque ligne contient l'agent AxonOps, cqlai et jemalloc. Les images de base sont
épinglées par digest, jamais par le tag indiqué ci-dessus — voir
[Sécurité de la chaîne d'approvisionnement](#ajouter-la-prise-en-charge-de-nouvelles-versions-de-cassandra).

## Prise en main

**Note :** sauf mention contraire, les commandes qui suivent supposent que vous êtes dans le répertoire `k8ssandra/`.

### 1. Installer l'opérateur K8ssandra

Lancez le script d'installation pour mettre en place l'opérateur K8ssandra et ses dépendances :

```bash
./scripts/install_k8ssandra.sh
```

Ce script va :
- installer cert-manager (v1.19.1) dans le namespace `cert-manager`
- ajouter le dépôt Helm K8ssandra
- installer l'opérateur K8ssandra (v1.29.0) dans le namespace `k8ssandra-operator`

### 2. Définir les variables d'environnement

Renseignez vos identifiants AxonOps :

```bash
export AXON_AGENT_KEY="your-axonops-agent-key" # Obtained from AxonOps Cloud Console
export AXON_AGENT_ORG="your-organization-id" # AxonOps Cloud organization name
export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"
```

Optionnel : indiquer un nom d'image personnalisé (par défaut ttl.sh, avec un TTL d'une heure) :

```bash
export IMAGE_NAME="your-registry/your-image:tag"
```

### 3. Construire et déployer

Utilisez le script rebuild pour construire, pousser et déployer votre cluster :

```bash
# Change to the version directory (contains Dockerfile)
cd 5.0

# Run the rebuild script (builds from current directory)
../scripts/rebuild.sh
```

Le script va :
1. supprimer tout déploiement de cluster existant
2. nettoyer les anciennes images de conteneurs
3. construire une nouvelle image Docker
4. pousser l'image vers le registre
5. appliquer la configuration du cluster avec substitution des variables d'environnement
6. déployer le cluster sur Kubernetes

## Construire les images Docker

**Note :** les commandes de cette section supposent que vous êtes dans le répertoire `k8ssandra/`.

Si vous préférez construire les images vous-même plutôt que d'utiliser les [images préconstruites](#images-docker-préconstruites) :

```bash
cd 5.0

# Minimal build (required args only)
docker build \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg MAJOR_VERSION=5.0 \
  --build-arg K8SSANDRA_BASE_DIGEST=sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af \
  --build-arg K8SSANDRA_API_VERSION=0.1.110 \
  --build-arg CQLAI_VERSION=0.1.4 \
  -t your-registry/axonops-cassandra:5.0.6-v0.1.110-1.0.0 \
  .

docker push your-registry/axonops-cassandra:5.0.6-v0.1.110-1.0.0
```

**Arguments de build obligatoires :**
- `CASSANDRA_VERSION` — version complète de Cassandra (par exemple 5.0.6)
- `MAJOR_VERSION` — version majeure.mineure correspondant au répertoire (par exemple 5.0)
- `K8SSANDRA_BASE_DIGEST` — digest SHA256 de l'image de base k8ssandra (sécurité de la chaîne d'approvisionnement)
- `K8SSANDRA_API_VERSION` — version de la Management API k8ssandra (par exemple 0.1.110)
- `CQLAI_VERSION` — version de cqlai à installer (voir la [dernière release](https://github.com/axonops/cqlai/releases))

**Arguments de build optionnels (valeur « unknown » s'ils sont absents) :**
- `BUILD_DATE` — horodatage du build (format ISO 8601, par exemple `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF` — SHA du commit Git (par exemple `$(git rev-parse HEAD)`)
- `VERSION` — version du conteneur (par exemple 1.0.0)
- `GIT_TAG` — nom du tag Git (pour les liens de release / tag de la bannière)
- `GITHUB_ACTOR` — utilisateur ayant déclenché le build (pour la traçabilité)
- `IS_PRODUCTION_RELEASE` — mettre à `true` pour la production (défaut : `false`)
- `IMAGE_FULL_NAME` — nom complet de l'image avec son tag (affiché dans la bannière de démarrage)

**Note :** les arguments optionnels enrichissent la bannière de démarrage et les labels, mais ne sont pas nécessaires au fonctionnement.

### Construire sans la Management API

Le même Dockerfile produit l'image Cassandra autonome publiée sous `ghcr.io/axonops/cassandra/cassandra`. Passez `INCLUDE_MGMT_API=false` : le build supprime `/opt/management-api` et `/opt/cdc_agent`, retire l'agent java de la Management API de `cassandra-env.sh` et laisse l'entrypoint démarrer Cassandra directement.

```bash
docker build \
  --build-arg CASSANDRA_VERSION=5.0.8 \
  --build-arg MAJOR_VERSION=5.0 \
  --build-arg K8SSANDRA_BASE_DIGEST=sha256:... \
  --build-arg K8SSANDRA_API_VERSION=0.1.120 \
  --build-arg INCLUDE_MGMT_API=false \
  --build-arg CQLAI_VERSION=0.1.7 \
  -t your-registry/axonops-cassandra:5.0.8-standalone \
  .
```

`INCLUDE_MGMT_API` vaut `true` par défaut : les builds K8ssandra ne sont donc pas affectés. Voir [cassandra/README.fr.md](../cassandra/README.fr.md) pour l'image autonome, sa stratégie de tags et ses variables d'environnement `CASSANDRA_*`.

### Ajouter la prise en charge d'une nouvelle version de Cassandra

À la sortie d'une nouvelle version de Cassandra (par exemple 5.0.7), procédez ainsi :

**1. Récupérer le digest de l'image de base k8ssandra :**

```bash
# Find the latest k8ssandra API version for the new Cassandra version
VERSION="5.0.7"
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${VERSION}-ubi" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'].startswith('${VERSION}-ubi-v')]; \
  results.sort(key=lambda x: x['name'], reverse=True); \
  print(f\"Tag: {results[0]['name']}\nDigest: {results[0]['digest']}\") if results else print('Not found')"
```

Ce qui affiche quelque chose comme :
```
Tag: 5.0.7-ubi-v0.1.112
Digest: sha256:newdigest123...
```

**2. Mettre à jour la variable de dépôt `K8SSANDRA_VERSIONS` :**

```bash
# Add the new version+digest to the JSON variable
gh variable set K8SSANDRA_VERSIONS --body '{
  "5.0.1+0.1.110": "sha256:...",
  "5.0.2+0.1.110": "sha256:...",
  ...
  "5.0.6+0.1.110": "sha256:...",
  "5.0.7+0.1.112": "sha256:newdigest123..."
}'
```

**3. Ajouter la version à `versions.yaml` :**

La matrice de build vit à un seul endroit. Ajoutez la nouvelle version à la fin de la
liste `versions` de sa ligne, dans la section `build_matrix` de
[`versions.yaml`](../versions.yaml) — la liste va de la plus ancienne à la plus récente
et la dernière entrée est ce que désignent les tags flottants `latest` et
`{line}-latest` : l'ordre compte et rien ne le trie pour vous :

```yaml
build_matrix:
  lines:
    - line: "5.0"
      published: true
      versions:
        - "5.0.1"
        # ...
        - "5.0.7"      # <- ajoutée
```

Aucune modification de fichier de workflow. Chaque matrice, l'équivalent d'`ALL_VERSIONS`
et les conditions des tags flottants sont dérivés de cette liste par
`scripts/build-matrix.sh`.

**4. Vérifier avant de pousser :**

```bash
./scripts/build-matrix.sh check \
  --k8ssandra-versions "$(gh variable get K8SSANDRA_VERSIONS --repo axonops/axonops-containers)"
```

La commande échoue si la nouvelle version n'a pas d'image de base
`cass-management-api` — la vérification qui vous coûterait sinon un build de 15 minutes
pour être découverte. Les workflows de publication et de build-and-test exécutent la
même commande avant de construire quoi que ce soit.

**5. Tester et publier :**

```bash
# Development test
git tag vdev-5.0.7-test
git push origin vdev-5.0.7-test
gh workflow run k8ssandra-development-publish-signed.yml \
  -f dev_git_tag=vdev-5.0.7-test \
  -f container_version=1.0.0

# If tests pass, publish to production via main branch
```

### Mettre à jour pour une nouvelle version de la Management API k8ssandra

Lorsque k8ssandra publie une nouvelle version de la Management API (par exemple v0.1.111) pour des versions de Cassandra existantes :

**1. Récupérer les nouveaux digests de toutes les versions concernées :**

```bash
# Check what changed - k8ssandra typically updates all versions together
for version in 5.0.1 5.0.2 5.0.3 5.0.4 5.0.5 5.0.6; do
  echo "=== Cassandra $version ==="
  curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${version}-ubi-v0.1.111" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'] == '${version}-ubi-v0.1.111']; \
  print(f\"  Digest: {results[0]['digest']}\") if results else print('  Not found')"
done
```

**2. Mettre à jour la variable `K8SSANDRA_VERSIONS` avec la nouvelle version d'API :**

```bash
# Replace or add new composite keys with updated API version
gh variable set K8SSANDRA_VERSIONS --body '{
  "5.0.1+0.1.111": "sha256:new_digest_1...",
  "5.0.2+0.1.111": "sha256:new_digest_2...",
  "5.0.3+0.1.111": "sha256:new_digest_3...",
  "5.0.4+0.1.111": "sha256:new_digest_4...",
  "5.0.5+0.1.111": "sha256:new_digest_5...",
  "5.0.6+0.1.111": "sha256:new_digest_6..."
}'
```

**3. Incrémenter la version du conteneur AxonOps :**

La version de l'API k8ssandra étant une mise à jour de composant, incrémentez la version MINEURE :
- actuelle : `1.0.0`
- nouvelle : `1.1.0` (bump MINEUR pour une mise à jour de composant)

**4. Tester et publier :**

```bash
# Test in development
git tag vdev-k8s-api-update
git push origin vdev-k8s-api-update
gh workflow run k8ssandra-development-publish-signed.yml \
  -f dev_git_tag=vdev-k8s-api-update \
  -f container_version=1.1.0

# After tests pass, create production release
git checkout main
git merge development
git tag k8ssandra-1.1.0
git push origin main k8ssandra-1.1.0

gh workflow run k8ssandra-publish-signed.yml \
  -f main_git_tag=k8ssandra-1.1.0 \
  -f container_version=1.1.0
```

**Note :** k8ssandra publie généralement une nouvelle version de la Management API chaque mois. Le workflow nocturne de vérification des versions (à implémenter) les détectera automatiquement.

**⚠️ Avertissement sur la chaîne d'approvisionnement :**

Nos Dockerfiles étendent les images de base k8ssandra en épinglant le digest (et non le tag), afin de prévenir les attaques sur la chaîne d'approvisionnement :

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
FROM docker.io/k8ssandra/cass-management-api@sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM docker.io/k8ssandra/cass-management-api:5.0.6-ubi
```

**Pourquoi l'épinglage par digest compte :**
- un tag peut être remplacé de façon malveillante (même tag, image différente)
- un digest est cryptographiquement immuable — il ne peut pas changer
- cela prévient une compromission silencieuse de votre chaîne d'approvisionnement de conteneurs
- c'est la bonne pratique du secteur pour les builds de production

**Lorsque vous étendez N'IMPORTE QUELLE image de conteneur :**
1. récupérez le digest avec : `docker inspect <image:tag> --format='{{.RepoDigests}}'`
2. utilisez `FROM image@digest` dans votre Dockerfile
3. documentez le tag de version en commentaire, pour la lisibilité humaine

**Sécurité de la chaîne d'approvisionnement :**

Nos conteneurs étendent les images de base `k8ssandra/cass-management-api`. Pour la sécurité de la chaîne d'approvisionnement, nous épinglons les images de base par digest (immuable) plutôt que par tag. `K8SSANDRA_BASE_DIGEST` associe chaque version de Cassandra à un digest d'image vérifié, ce qui empêche une attaque où une image amont serait remplacée de façon malveillante.

La correspondance elle-même n'est pas reproduite ici. Elle vit dans la variable de dépôt
`K8SSANDRA_VERSIONS`, indexée par `{CASSANDRA_VERSION}+{K8SSANDRA_API_VERSION}`, et
c'est elle que lisent les builds. La copie qui occupait cette section était figée sur
l'API k8ssandra v0.1.120 et avait déjà été dépassée par la v0.1.124 — chaque digest y
était faux, et rien dans la CI ne pouvait s'en apercevoir. Lisez la correspondance
réelle avec :

```bash
gh variable get K8SSANDRA_VERSIONS --repo axonops/axonops-containers | jq .
```

`scripts/build-matrix.sh check --k8ssandra-versions "$(gh variable get K8SSANDRA_VERSIONS --repo axonops/axonops-containers)"`
vérifie que chaque version de la matrice de build y possède une entrée ; les workflows de
publication et de build-and-test l'exécutent avant de construire quoi que ce soit.

**Comment obtenir les digests des nouvelles versions k8ssandra :**

À la sortie d'une nouvelle version de Cassandra chez k8ssandra, récupérez le digest via l'API Docker Hub :

```bash
# For a specific version (e.g., 5.0.7)
VERSION="5.0.7"
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${VERSION}-ubi" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'].startswith('${VERSION}-ubi')]; \
  [print(f\"Version: {r['name']}\nDigest: {r['digest']}\") for r in results[:1]]"
```

Ou récupérez toutes les versions 5.0.x d'un coup :

```bash
for version in 5.0.1 5.0.2 5.0.3 5.0.4 5.0.5 5.0.6; do
  echo "=== Cassandra $version ==="
  curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${version}-ubi" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'].startswith('${version}-ubi')]; \
  [print(f\"  {r['digest']}\") for r in results[:1]]"
  echo ""
done
```

Une fois le digest obtenu, mettez à jour la variable de dépôt `K8SSANDRA_VERSIONS` avec la nouvelle clé composite version+digest.

## Déployer sur Kubernetes

**Note :** les commandes de cette section supposent que vous êtes dans le répertoire `k8ssandra/`.

### Utiliser la configuration d'exemple

`examples/k8ssandra/cluster-axonops-ubi.yaml` fournit un modèle de déploiement d'un cluster Cassandra 5.0 à trois nœuds :

```bash
# Set your environment variables
export IMAGE_NAME="your-image"
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"

# Apply the configuration
cat examples/k8ssandra/cluster-axonops-ubi.yaml | envsubst | kubectl apply -f -
```

### Vérifier le déploiement

Après le déploiement, vérifiez que votre cluster tourne :

```bash
# Check cluster status
kubectl get k8ssandraclusters -n k8ssandra-operator

# Watch pods come up (wait for all to show Running and Ready)
kubectl get pods -n k8ssandra-operator -w

# Check detailed cluster status
kubectl describe k8ssandracluster <cluster-name> -n k8ssandra-operator
```

Tous les pods Cassandra doivent afficher `2/2` dans la colonne READY une fois complètement démarrés.

### Se connecter au cluster

#### Avec cqlsh

Connectez-vous directement à un pod Cassandra :

```bash
kubectl exec -it <pod-name> -n k8ssandra-operator -c cassandra -- cqlsh
```

#### Accès externe (port-forward)

> **Note :** le port-forwarding convient au développement local et aux tests. En production (AWS, GCP, Azure, etc.), préférez un service LoadBalancer, un contrôleur Ingress ou un accès par VPN, selon vos exigences de sécurité.

Pour vous connecter depuis l'extérieur du cluster Kubernetes (depuis votre poste, par exemple) :

1. Récupérez les identifiants du superutilisateur :
   ```bash
   # Username
   kubectl get secret <cluster-name>-superuser -n k8ssandra-operator -o jsonpath='{.data.username}' | base64 -d

   # Password
   kubectl get secret <cluster-name>-superuser -n k8ssandra-operator -o jsonpath='{.data.password}' | base64 -d
   ```

2. Lancez le port-forwarding :
   ```bash
   kubectl port-forward svc/<cluster-name>-dc1-service 9042:9042 -n k8ssandra-operator
   ```

3. Connectez-vous avec cqlsh ou tout autre client CQL sur `localhost:9042`, avec les identifiants de l'étape 1.

#### AxonOps Workbench

[AxonOps Workbench](https://axonops.com/workbench) est un IDE de bureau gratuit permettant aux développeurs et aux DBA de se connecter à des clusters Cassandra et de les gérer. Il offre une interface moderne pour exécuter des requêtes, parcourir le schéma et gérer vos données. Utilisez la méthode de port-forward ci-dessus pour connecter Workbench à votre cluster Kubernetes.

### Principales options de configuration

Le cluster d'exemple comprend :
- **Taille du cluster** : 3 nœuds dans le datacenter `dc1`
- **Ressources** :
  - CPU : 1 cœur (requête et limite)
  - mémoire : 1 Gi en requête, 2 Gi en limite
- **Réglages JVM** :
  - heap initial : 1G
  - heap maximum : 1G
- **Stockage** :
  - storage class : `local-path`
  - taille : 2 Gi par nœud
  - mode d'accès : ReadWriteOnce
- **Anti-affinité** : anti-affinité de pods souple activée

## Configuration

### Configuration de l'agent AxonOps

L'agent AxonOps se configure par des variables d'environnement passées au conteneur Cassandra :

| Variable | Description | Défaut |
|----------|-------------|---------|
| `AXON_AGENT_KEY` | Votre clé d'agent AxonOps | Obligatoire |
| `AXON_AGENT_ORG` | L'identifiant de votre organisation AxonOps | Obligatoire |
| `AXON_AGENT_SERVER_HOST` | Nom d'hôte du serveur AxonOps | `agents.axonops.cloud` |
| `AXON_AGENT_LOG_OUTPUT` | Destination des logs de l'agent | `std` |
| `AXON_AGENT_NTP_HOST` | Serveur NTP utilisé pour les contrôles de dérive d'horloge, `hôte` ou `hôte:port` (le port par défaut est `123`) | `pool.ntp.org` |

La détection automatique NTP ne fonctionne pas dans Kubernetes : le conteneur applique donc par défaut `AXON_AGENT_NTP_HOST=pool.ntp.org` et journalise un avertissement à chaque démarrage tant que la valeur n'est pas remplacée. Définissez-la sur la source NTP utilisée par vos hôtes Cassandra, sinon les mesures de dérive d'horloge sont comparées à un pool avec lequel vos nœuds ne se synchronisent jamais.
| `AXON_AGENT_ARGS` | Arguments supplémentaires de l'agent | - |

### Variables d'environnement du conteneur

Les variables d'environnement sont injectées dans la configuration du cluster K8ssandra :

```yaml
containers:
  - name: cassandra
    env:
      - name: AXON_AGENT_KEY
        value: "${AXON_AGENT_KEY}"
      - name: AXON_AGENT_ORG
        value: "${AXON_AGENT_ORG}"
      - name: AXON_AGENT_SERVER_HOST
        value: "${AXON_AGENT_SERVER_HOST}"
```

### Healthcheck

Le healthcheck du conteneur (`/usr/local/bin/axonops-healthcheck.sh`, exécuté toutes les 30 s après une période de démarrage de 120 s) vérifie deux choses :

1. **Cassandra** — l'endpoint de liveness de la Management API, la sonde même sur laquelle s'appuie l'opérateur K8ssandra. Dans les images construites sans la Management API (`INCLUDE_MGMT_API=false`), c'est `nodetool statusbinary` plus une vérification du port CQL.
2. **Agent AxonOps** — le processus `axon-agent` tourne, donc le nœud est réellement supervisé.

Par défaut, un agent mort est signalé dans la sortie du healthcheck mais ne rend pas le conteneur unhealthy : Cassandra sert toujours le CQL, et faire échouer la vérification peut amener Kubernetes à redémarrer ou à drainer un nœud qui fait un travail utile. Mettez `HEALTHCHECK_REQUIRE_AGENT=true` pour traiter un agent mort comme un échec.

| Variable | Défaut | Description |
|----------|---------|-------------|
| `HEALTHCHECK_REQUIRE_AGENT` | `false` | `true` rend le conteneur unhealthy lorsque `axon-agent` ne tourne pas |

```yaml
containers:
  - name: cassandra
    env:
      - name: HEALTHCHECK_REQUIRE_AGENT
        value: "true"
```

Notez que l'opérateur K8ssandra pose ses propres sondes de liveness et de readiness sur le pod ; elles ne sont pas affectées et continuent d'utiliser les endpoints de la Management API. Le healthcheck décrit ici est celui du conteneur, visible via `docker inspect` et pris en compte par tout runtime qui honore `HEALTHCHECK`.

```bash
docker inspect --format '{{.State.Health.Status}}' <container>
kubectl exec <pod> -c cassandra -- /usr/local/bin/axonops-healthcheck.sh
```

## Référence des scripts

### scripts/install_k8ssandra.sh

Installe l'opérateur K8ssandra et ses prérequis.

**Usage :**
```bash
./scripts/install_k8ssandra.sh
```

**Ce qu'il fait :**
- installe cert-manager avec Helm
- ajoute le dépôt Helm K8ssandra
- installe l'opérateur K8ssandra v1.29.0

**Aucun paramètre requis.**

### scripts/rebuild.sh

Construit, pousse et déploie un cluster Cassandra avec l'intégration AxonOps.

> **Note :** ce script est prévu pour des environnements Kubernetes offrant un accès direct aux nœuds via `crictl`. Il peut ne pas fonctionner sur des installations locales comme minikube, kind ou Docker Desktop. Pour le développement local, voir les étapes manuelles de build et de déploiement dans les sections [Construire les images Docker](#construire-les-images-docker) et [Déployer sur Kubernetes](#déployer-sur-kubernetes).

**Usage :**
```bash
export IMAGE_NAME="your-registry/image:tag"  # Optional, defaults to ttl.sh
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_SERVER_HOST="your-host"  # Optional

# Change to version directory (script runs docker build from here)
cd 5.0
../scripts/rebuild.sh
```

**Ce qu'il fait :**
1. génère un nom d'image unique s'il n'est pas fourni (via ttl.sh, avec un TTL d'une heure)
2. supprime le déploiement de cluster existant
3. nettoie les anciennes images de conteneurs avec crictl
4. construit la nouvelle image Docker
5. pousse l'image vers le registre
6. tire l'image avec crictl
7. substitue les variables d'environnement dans `cluster-axonops.yaml` (copie de [examples/k8ssandra/cluster-axonops-ubi.yaml](../examples/k8ssandra/cluster-axonops-ubi.yaml))
8. déploie la configuration de cluster mise à jour

**Variables d'environnement :**
- `IMAGE_NAME` : nom de l'image Docker (optionnel)
- `AXON_AGENT_KEY` : clé d'API AxonOps (obligatoire dans la configuration du cluster)
- `AXON_AGENT_ORG` : organisation AxonOps (obligatoire dans la configuration du cluster)
- `AXON_AGENT_SERVER_HOST` : hôte AxonOps (obligatoire dans la configuration du cluster)

## Exemples

### examples/k8ssandra/cluster-axonops-ubi.yaml

Une définition complète de ressource K8ssandraCluster, qui illustre :

**Spécifications du cluster :**
- nom : `axonops-k8ssandra-50`
- namespace : `k8ssandra-operator`
- version de Cassandra : 5.0.6
- image : `ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0` (par défaut)
- datacenter : `dc1`, avec 3 nœuds

**Allocation de ressources :**
```yaml
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 1
    memory: 1Gi
```

**Configuration du stockage :**
```yaml
storageConfig:
  cassandraDataVolumeClaimSpec:
    storageClassName: local-path
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 2Gi
```

**Volume AxonOps (obligatoire) :**

AxonOps a besoin d'un volume persistant pour stocker sa configuration. Ajoutez ceci à votre configuration de cluster :

```yaml
        extraVolumes:
          pvcs:
            - name: axonops-data
              mountPath: /var/lib/axonops
              pvcSpec:
                accessModes:
                  - ReadWriteOnce
                resources:
                  requests:
                    storage: 512Mi
```

**Intégration AxonOps :**
L'exemple montre l'injection correcte des variables d'environnement de l'agent AxonOps, au niveau du conteneur — l'approche exigée par K8ssandra.

### Adapter l'exemple

**Note :** les commandes de cette section supposent que vous êtes dans le répertoire `k8ssandra/`.

Pour utiliser cet exemple :

1. Copiez le fichier d'exemple :
   ```bash
   cp examples/k8ssandra/cluster-axonops-ubi.yaml my-cluster.yml
   ```

2. Modifiez les valeurs dans `my-cluster.yml` :
   - **Nom du cluster** : le champ `metadata.name` (par exemple, remplacez `axonops-k8ssandra-50` par `my-cassandra-cluster`). Note : le nom du cluster sert à générer les noms de services, de secrets et de pods.
   - **Namespace** : `metadata.namespace`, si vous déployez dans un autre namespace
   - **Nombre de nœuds** : `size` sous `datacenters` (3 par défaut)
   - **Ressources** : les allocations CPU / mémoire sous `resources`
   - **Stockage** : la taille de `storage` sous `storageConfig`

3. Déployez :
   ```bash
   export AXON_AGENT_KEY="your-key"
   export AXON_AGENT_ORG="your-org"
   export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"
   # Optional: Override default image
   export IMAGE_NAME="ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0"

   cat my-cluster.yml | envsubst | kubectl apply -f -
   ```

**Note :** l'exemple utilise le nouveau format d'image `5.0.6-v0.1.110-1.0.0`, qui comprend :
- la version de Cassandra : 5.0.6
- la version de l'API k8ssandra : v0.1.110
- la version du conteneur AxonOps : 1.0.0

## Pipeline CI/CD

### Builds et tests automatisés

Le dépôt contient des workflows GitHub Actions complets de construction, de test et de publication des images Docker.

**Workflows :**
- **Build and Test :** `.github/workflows/k8ssandra-build-and-test.yml` — tests de build Docker avec validation complète
- **E2E Testing :** `.github/workflows/k8ssandra-e2e-test.yml` — tests de déploiement Kubernetes de bout en bout
- **Security Scanning :** `.github/workflows/k8ssandra-nightly-security-scan.yml` — analyse quotidienne des CVE, avec alertes par e-mail
- **Production Publish (Signed) :** `.github/workflows/k8ssandra-publish-signed.yml` — releases de production manuelles, signées avec Cosign
- **Development Publish (Signed) :** `.github/workflows/k8ssandra-development-publish-signed.yml` — builds de développement signés avec Cosign

**Déclencheurs du workflow Build and Test :**
- push sur la branche `development` ou `main` (avec des modifications dans `k8ssandra/**`)
- pull requests vers `development` ou `main` (avec des modifications dans `k8ssandra/**`)

**Workflow E2E Test :**
- déclenchement manuel depuis l'interface GitHub Actions ou via `gh workflow run k8ssandra-e2e-test.yml`
- déploie les conteneurs dans un cluster k3s sur le runner GitHub Actions
- teste la Management API, l'agent AxonOps, cqlai et les opérations CQL
- valide la connectivité à AxonOps SaaS
- durée : environ 3 à 4 minutes

**Workflow Security Scan :**
- planifié : tous les jours à 2 h UTC
- déclenchement manuel depuis l'interface GitHub Actions
- analyse toutes les versions publiées à la recherche de CVE
- notifications par e-mail en cas de détection de sévérité CRITICAL ou HIGH

**Workflows de publication :**
- déclenchement manuel depuis l'interface GitHub Actions ou la CLI `gh`
- exigent un tag Git et une version de conteneur
- voir [RELEASE.md](./RELEASE.md) pour les instructions détaillées

**Suite de tests :**
Le pipeline CI comprend des tests complets :
- les tests s'exécutent d'abord pour 5.0.6, puis en parallèle pour les autres versions 5.0 (5.0.1 à 5.0.5)
- contrôles de santé de la Management API (liveness, readiness)
- opérations de l'agent java de la Management API (création de keyspace, de table, flush, compact)
- opérations CQL avec cqlai (CREATE, INSERT, SELECT, DROP)
- vérification du processus de l'agent AxonOps
- vérification de jemalloc (aucun avertissement, chargement réussi)
- vérification de la version de Java (JDK17 pour la 5.0)
- analyse de sécurité du conteneur avec Trivy
  - les CVE amont connues sont documentées dans `.trivyignore`
  - voir [.trivyignore](./.trivyignore) pour la liste des vulnérabilités supprimées

**Processus de publication :**
1. le développeur crée un tag Git (par exemple `git tag 1.0.0 && git push origin 1.0.0`)
2. le développeur déclenche le workflow de publication depuis l'interface GitHub ou via `gh workflow run`
3. le workflow vérifie que la version n'existe pas déjà sur GHCR
4. la suite de tests complète s'exécute d'abord sur 5.0.6, pour validation
5. des images multi-architectures (amd64, arm64) sont construites pour les 6 versions (3 en parallèle au maximum)
6. les images sont poussées vers GHCR avec les tags spécifiques à la version et les tags latest
7. une release GitHub est créée automatiquement

Pour les instructions de release complètes, voir [RELEASE.md](./RELEASE.md)

**Tags d'image :**
Chaque release utilise un tagging à trois dimensions, avec suivi de la version de l'API k8ssandra :

```
ghcr.io/axonops/k8ssandra/cassandra:{CASS}-v{K8S_API}-{AXON}  # Fully immutable (all 3 versions)
ghcr.io/axonops/k8ssandra/cassandra:{CASS}-v{K8S_API}         # Latest AxonOps for this Cassandra + k8ssandra combo
ghcr.io/axonops/k8ssandra/cassandra:{CASS}                    # Latest k8ssandra API + AxonOps for this Cassandra minor
ghcr.io/axonops/k8ssandra/cassandra:{MAJOR}-latest            # Latest minor in Cassandra major
ghcr.io/axonops/k8ssandra/cassandra:latest                    # Latest across all Cassandra majors
```

**Exemple :** pour une release Cassandra `5.0.6`, API k8ssandra `v0.1.110` et AxonOps `1.0.0` :

**Tags totalement immuables** (1 par version de Cassandra, 6 au total) :
- `5.0.1-v0.1.110-1.0.0`, `5.0.2-v0.1.110-1.0.0`, `5.0.3-v0.1.110-1.0.0`, `5.0.4-v0.1.110-1.0.0`, `5.0.5-v0.1.110-1.0.0`, `5.0.6-v0.1.110-1.0.0`

**Tags flottants** (suivent le dernier AxonOps pour un couple Cassandra + k8ssandra, 6 au total) :
- `5.0.1-v0.1.110` → `5.0.1-v0.1.110-1.0.0`
- `5.0.2-v0.1.110` → `5.0.2-v0.1.110-1.0.0`
- `5.0.3-v0.1.110` → `5.0.3-v0.1.110-1.0.0`
- `5.0.4-v0.1.110` → `5.0.4-v0.1.110-1.0.0`
- `5.0.5-v0.1.110` → `5.0.5-v0.1.110-1.0.0`
- `5.0.6-v0.1.110` → `5.0.6-v0.1.110-1.0.0`

**Tags flottants** (suivent les derniers k8ssandra + AxonOps de chaque version mineure de Cassandra, 6 au total) :
- `5.0.1` → `5.0.1-v0.1.110-1.0.0`
- `5.0.2` → `5.0.2-v0.1.110-1.0.0`
- `5.0.3` → `5.0.3-v0.1.110-1.0.0`
- `5.0.4` → `5.0.4-v0.1.110-1.0.0`
- `5.0.5` → `5.0.5-v0.1.110-1.0.0`
- `5.0.6` → `5.0.6-v0.1.110-1.0.0`

**Tag latest de niveau mineur** (1) :
- `5.0-latest` → `5.0.6-v0.1.110-1.0.0`

**Tag latest global** (1) :
- `latest` → `5.0.6-v0.1.110-1.0.0`

**Total :** 20 tags (6 immuables + 6 flottants k8ssandra + 6 flottants Cassandra + 1 minor-latest + 1 global-latest)

## Fonctionnalités du conteneur

### Bannière de version au démarrage

Tous les conteneurs affichent au démarrage une bannière de version complète, indiquant :
- la version de build du conteneur et la révision git
- la version de Cassandra
- la version de Java
- les versions de l'agent AxonOps (autonome et agent Java)
- la version de cqlai
- la version de jemalloc
- le système d'exploitation et la plateforme
- l'environnement d'exécution (détection de Kubernetes, nom d'hôte)
- l'état de la configuration AxonOps

**Afficher la bannière :**
```bash
# Docker/Podman
docker logs <container-name> | head -30

# Kubernetes
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | head -30
```

**Exemple de sortie (release de production) :**
```
================================================================================
AxonOps K8ssandra Apache Cassandra 5.0.6
Image: ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0
Built: 2025-12-09T14:40:13Z
Release: https://github.com/axonops/axonops-containers/releases/tag/1.0.0
Built by: GitHub Actions
================================================================================

Component Versions:
  Cassandra:          5.0.6
  k8ssandra API:      0.1.110
  Java:               OpenJDK Runtime Environment (Red_Hat-17.0.17.0.10-1) (build 17.0.17+10-LTS)
  AxonOps Agent:      2.0.11
  AxonOps Java Agent: axon-cassandra5.0-agent-jdk17-1.0.12-1.noarch
  cqlai:              v0.1.2
  jemalloc:           jemalloc-5.2.1-2.el9.x86_64
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI - Universal Base Image, freely redistributable)
  Platform:           x86_64

Supply Chain Security:
  Base image:         k8ssandra/cass-management-api:5.0.6-ubi-v0.1.110
  Base image digest:  sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af

Runtime Environment:
  Hostname:           demo-dc1-default-sts-0
  Kubernetes:         Yes
    API Server:       10.43.0.1:443
    Pod:              demo-dc1-default-sts-0

AxonOps Configuration:
  Server:             agents.axonops.cloud
  Organization:       your-org
  Agent Key:          ***configured***

================================================================================
Starting Cassandra with Management API and AxonOps Agent...
================================================================================
```

Les **builds de production** ajoutent des métadonnées : les champs `Image`, le lien `Release` et `Built by`. Les **builds de développement** n'affichent que l'essentiel (l'horodatage `Built`).

Cette bannière simplifie beaucoup le débogage chez les clients, en réunissant toutes les informations de version au même endroit.

## Supervision avec AxonOps

Une fois déployé, votre cluster Cassandra va automatiquement :
- s'enregistrer auprès d'AxonOps avec la clé d'API et l'organisation fournies
- envoyer métriques et logs à la plateforme AxonOps
- activer la supervision, l'alerte et les fonctions de gestion du cluster

Accédez à la supervision de votre cluster :
- AxonOps Cloud : https://axonops.cloud
- installation personnalisée : votre URL AxonOps

## Dépannage

### Vérifier la version du conteneur

Consultez la bannière de démarrage pour voir toutes les versions des composants :
```bash
# Kubernetes
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | head -30

# Docker/Podman
docker logs <container-name> | head -30
```

La bannière affiche la version du conteneur, la révision git et toutes les versions des composants, ce qui permet d'identifier exactement ce qui tourne.

### Problèmes de connexion de l'agent

Consultez les logs de l'agent :
```bash
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | grep axon
```

Vérifiez les variables d'environnement :
```bash
kubectl describe pod <pod-name> -n k8ssandra-operator
```

Vérifiez sur la bannière de démarrage que la configuration AxonOps est correcte.

### Erreurs de pull d'image

Assurez-vous que votre image est accessible :
```bash
docker pull $IMAGE_NAME
```

Pour les images ttl.sh, notez qu'elles expirent au bout d'une heure. Utilisez un registre pérenne en production.

### Le cluster ne démarre pas

Consultez les logs de l'opérateur K8ssandra :
```bash
kubectl logs -n k8ssandra-operator deployment/k8ssandra-operator
```

Vérifiez l'état du cluster :
```bash
kubectl get k8ssandraclusters -n k8ssandra-operator
kubectl describe k8ssandracluster <cluster-name> -n k8ssandra-operator
```

## Considérations de production

1. **Registre d'images** : utilisez un registre de conteneurs pérenne plutôt que ttl.sh
2. **Dimensionnement** : ajustez CPU, mémoire et stockage à la charge réelle
3. **Haute disponibilité** : déployez sur plusieurs zones de disponibilité
4. **Stratégie de sauvegarde** : configurez K8ssandra Medusa pour les sauvegardes
5. **Sécurité** :
   - utilisez des secrets pour les identifiants AxonOps plutôt que des variables d'environnement
   - activez le chiffrement au repos et en transit
   - configurez le RBAC et les network policies
6. **Supervision** : mettez en place des alertes AxonOps sur les métriques critiques
