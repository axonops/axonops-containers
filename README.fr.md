# Images de conteneurs AxonOps

[English](README.md) | **Français**

[![Licence](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Tickets GitHub](https://img.shields.io/github/issues/axonops/axonops-containers)](https://github.com/axonops/axonops-containers/issues)
[![Multi-architecture](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-brightgreen)](https://github.com/axonops/axonops-containers)

Définitions de build de conteneurs et pipelines CI/CD des images de conteneurs AxonOps.

## Table des matières

- [Composants](#composants)
- [Versions actuelles](VERSIONS.md)
- [Red Hat Universal Base Image (UBI)](#red-hat-universal-base-image-ubi)
- [Conventions du dépôt](#conventions-du-dépôt)
- [Sécurité](#sécurité)
  - [Politique CVE](#politique-cve)
  - [Déploiement sécurisé de référence](#déploiement-sécurisé-de-référence)
- [Développement](#développement)
  - [Standards de sécurité des conteneurs](#standards-de-sécurité-des-conteneurs-tous-les-composants)
- [Publication des versions](#publication-des-versions)
  - [Publication en développement](#publication-en-développement)
  - [Publication en production](#publication-en-production)
  - [Documentation de release par composant](#documentation-de-release-par-composant)
- [Remerciements](#remerciements)
  - [Apache Cassandra](#apache-cassandra)
  - [K8ssandra](#k8ssandra)
  - [AxonOps Schema Registry](#axonops-schema-registry)
- [Licence](#licence)
- [Mentions légales](#mentions-légales)
  - [Marques déposées](#marques-déposées)

## Composants

### Bases de données
- **[cassandra/](./cassandra/)** - Apache Cassandra avec l'agent AxonOps et sans la Management API K8ssandra, construit à partir du Dockerfile k8ssandra avec `INCLUDE_MGMT_API=false` (`ghcr.io/axonops/cassandra/cassandra`)

### Distributions Kubernetes
- **[k8ssandra/](./k8ssandra/)** - Apache Cassandra avec l'intégration AxonOps pour l'opérateur K8ssandra

### AxonOps auto-hébergé
- **[axonops/](./axonops/)** - Stack AxonOps auto-hébergée (tous les composants de la plateforme)

### Intégrations
- **[axonops-schema-registry/](./axonops-schema-registry/)** - Schema Registry compatible Confluent avec prise en charge de plusieurs backends de stockage

### Docker Compose
- **[docker-compose/](./docker-compose/)** - Toutes les stacks Compose : la plateforme AxonOps seule, la plateforme avec un cluster Cassandra supervisé, un cluster reportant vers AxonOps SaaS, et un cluster sécurisé à 3 racks sur un sous-réseau fixe

## Red Hat Universal Base Image (UBI)

Tous les conteneurs de ce dépôt sont construits sur **Red Hat Universal Base Image (UBI) 9**, qui apporte un niveau de sécurité, de stabilité et de conformité adapté à l'entreprise.

**Pourquoi Red Hat UBI ?**

- **Librement redistribuable** - Aucun abonnement requis pour l'utiliser ou la redistribuer
- **Sécurité de niveau entreprise** - Mises à jour de sécurité et correctifs CVE réguliers de Red Hat
- **Durcie pour la production** - Surface d'attaque minimale, uniquement les paquets essentiels
- **Prête pour la conformité** - Répond aux exigences des secteurs régulés (finance, santé, secteur public)
- **Support long terme** - Base stable au cycle de vie prévisible (RHEL 9 supporté jusqu'en 2032)
- **Optimisée pour les conteneurs** - Conçue pour les charges de travail conteneurisées, avec une empreinte minimale

**En savoir plus :**
- [Projet Red Hat UBI](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image)
- [Catalogue de conteneurs UBI 9](https://catalog.redhat.com/software/containers/search?q=ubi9)
- [Documentation UBI](https://developers.redhat.com/products/rhel/ubi)

## Conventions du dépôt

- **Prise en charge multi-architecture** : linux/amd64, linux/arm64
- **Publié sur** : GitHub Container Registry `ghcr.io/axonops/<image-name>:<tag>`
- **CI/CD automatisée** : GitHub Actions avec une couverture de tests complète
- **Analyse de sécurité** : analyse de vulnérabilités Trivy sur toutes les images
- **Images de base** : Red Hat UBI 9 (épinglées par digest pour la sécurité de la chaîne d'approvisionnement)
- **Versions actuelles** : [VERSIONS.md](VERSIONS.md) liste le tag et le digest actuels de chaque image et chart publiés. Ce fichier est généré à partir de [versions.yaml](versions.yaml) par `./scripts/update-versions.sh` — modifiez le YAML, jamais le Markdown.

## Sécurité

### Politique CVE

**Tags immuables :** toutes les images de conteneurs utilisent un versionnage immuable. Lorsqu'une CVE est découverte et corrigée, nous publions de NOUVELLES versions plutôt que d'écraser les tags existants.

**Incréments de version :**
- CVE critiques (sévérité CRITICAL, HIGH) : release corrective immédiate (par exemple `1.0.3` → `1.0.4`)
- CVE non critiques (MEDIUM, LOW) : regroupées dans les releases mensuelles
- Un incrément de version patch peut inclure : correctifs CVE, mises à jour de composants (par exemple l'agent AxonOps), corrections de bugs ou ajouts de fonctionnalités

**Comportement du tag `latest` :**
- Le tag `latest` pointe toujours vers la version sécurisée la plus récente
- Il fournit des mises à jour de sécurité automatiques
- **Déconseillé en production** - utilisez plutôt des versions précises

**Déploiement en production :**
- Épinglez toujours une version immuable précise (par exemple `5.0.6-v0.1.110-1.0.5`)
- N'utilisez jamais les tags `latest`, `5.0-latest` ou `{version}-latest` en production
- Lisez les notes de release avant toute montée de version
- Testez d'abord les montées de version hors production

**Notifications CVE :**
- Analyses de sécurité nocturnes automatisées avec Trivy
- Notifications par e-mail pour les nouvelles CVE CRITICAL/HIGH
- Divulgation transparente dans les notes de release

**Pour les environnements aux exigences de sécurité les plus élevées**, voir [Déploiement sécurisé de référence](#déploiement-sécurisé-de-référence).

---

### Déploiement sécurisé de référence

Le **déploiement par digest** offre le plus haut niveau de sécurité et d'immuabilité pour les déploiements de conteneurs.

#### Qu'est-ce que le déploiement par digest ?

Plutôt que d'utiliser des tags (qui peuvent être mutables), déployez à partir du digest SHA256 de l'image :

```yaml
# Tag-based (good)
image: ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Digest-based (best)
image: ghcr.io/axonops/k8ssandra/cassandra@sha256:412c85225...
```

#### Bénéfices

✅ **100 % immuable** - Exactement la même image à chaque fois, définitivement

✅ **Insensible à la manipulation des tags** - Sans effet si un tag est modifié accidentellement ou malicieusement

✅ **Prêt pour la conformité** - Répond aux exigences des environnements régulés (finance, santé, secteur public)

✅ **Piste d'audit** - Le digest présent dans le manifeste de déploiement constitue une preuve cryptographique de l'image exacte

✅ **Sécurité de la chaîne d'approvisionnement** - Combiné à la vérification de signature, il fournit une provenance complète

#### Trouver le digest d'une image

**Méthode 1 : depuis l'interface GHCR**
1. Ouvrez le package : https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra
2. Cliquez sur la version voulue
3. Copiez le digest SHA256 affiché

**Méthode 2 : avec Docker/Podman**
```bash
# Pull the image first
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Get digest
docker inspect ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5 \
  --format='{{index .RepoDigests 0}}'

# Output: ghcr.io/axonops/k8ssandra/cassandra@sha256:412c85225...
```

**Méthode 3 : pendant le workflow**
- Consultez les logs du workflow GitHub Actions après publication
- Le digest est affiché dans la sortie de build

#### Exemple de déploiement Kubernetes

**Manifeste K8ssandraCluster :**
```yaml
apiVersion: k8ssandra.io/v1alpha1
kind: K8ssandraCluster
metadata:
  name: production-cluster
spec:
  cassandra:
    serverVersion: "5.0.6"
    # Use digest instead of tag
    serverImage: "ghcr.io/axonops/k8ssandra/cassandra@sha256:412c852252ec4ebcb8d377a505881828a7f6a5f9dc725cc4f20fda2a1bcb3494"
    datacenters:
      - metadata:
          name: dc1
        size: 3
        # ... rest of configuration
```

#### Vérifier les signatures

Toutes les images publiées sur GHCR sont signées avec [Sigstore Cosign](https://github.com/sigstore/cosign) en signature sans clé (keyless).

**Vérification standard :**
```bash
# Install cosign
brew install sigstore/tap/cosign  # macOS
# or: https://docs.sigstore.dev/cosign/installation/

# Verify signature
cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Check signature exists
cosign tree ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

**Dépannage (problèmes sous macOS) :**

Si vous rencontrez des problèmes avec cosign installé localement sous macOS, utilisez l'image de conteneur officielle Cosign :

```bash
# Using Docker
docker run --rm gcr.io/projectsigstore/cosign:v2.4.1 verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Using Podman
podman run --rm gcr.io/projectsigstore/cosign:v2.4.1 verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

Cette méthode utilise le [conteneur Cosign officiel](https://github.com/sigstore/cosign) et fonctionne de façon fiable sur toutes les plateformes.

**Une vérification réussie prouve que :**
- ✅ L'image a été construite par le workflow GitHub Actions officiel
- ✅ L'image n'a pas été altérée
- ✅ La provenance du build est traçable jusqu'à un commit et une exécution de workflow précis

#### Imposer des images signées dans Kubernetes

Pour les environnements de production exigeant une vérification de signature avant déploiement :

**Outils d'application de politiques :**
- **Kyverno** - Moteur de politiques natif Kubernetes
- **OPA Gatekeeper** - Open Policy Agent pour Kubernetes
- **Sigstore Policy Controller** - Contrôleur d'admission officiel Sigstore

**Exemple : politique Kyverno**

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-axonops-images
spec:
  validationFailureAction: Enforce
  rules:
    # RULE 1: Deny any image NOT from ghcr.io/axonops/
    - name: check-registry
      match:
        any:
        - resources:
            kinds: [Pod]
            namespaces: [kafka,k8ssandra-operator,strimzi]
      validate:
        message: "Only images from ghcr.io/axonops/ are allowed in this namespace."
        foreach:
        - list: "request.object.spec.containers"
          deny:
            conditions:
              all:
              - key: "{{ element.image }}"
                operator: NotEquals # Use NotEquals with wildcards
                value: "ghcr.io/axonops/*"

    # RULE 2: Verify the signatures of those images
    - name: verify-signature
      match:
        any:
        - resources:
            kinds: [Pod]
            namespaces: [kafka,k8ssandra-operator,strimzi]
      verifyImages:
        - imageReferences:
            - "ghcr.io/axonops/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/axonops/axonops-containers/*"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

**Prise en charge par fournisseur cloud :**
- **AWS EKS** - Kyverno ou OPA Gatekeeper via Helm
- **Google GKE** - Binary Authorization avec des attestations Cosign
- **Azure AKS** - Azure Policy avec Ratify + Cosign
- **Rancher/RKE** - Kyverno ou OPA Gatekeeper via les Apps Rancher

Pour la mise en place détaillée, consultez la documentation de votre distribution Kubernetes sur les contrôleurs d'admission et l'application de politiques d'images.

#### Bonnes pratiques

**Pour les clusters de production :**
1. ✅ Déployez par digest
2. ✅ Vérifiez les signatures avant déploiement (images signées)
3. ✅ Épinglez le digest dans le gestionnaire de versions (GitOps)
4. ✅ Documentez la correspondance digest → version dans les notes de release
5. ✅ Ne mettez à jour les digests qu'après des tests hors production

**Pour le développement et les tests :**
- Le déploiement par tag est acceptable pour itérer plus vite
- Utilisez le registre d'images de développement pour les tests

**Mettre à jour un digest :**
```bash
# 1. Pull new version
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# 2. Get new digest
NEW_DIGEST=$(docker inspect ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5 \
  --format='{{index .RepoDigests 0}}' | cut -d@ -f2)

# 3. Update manifest
sed -i "s|@sha256:.*|@${NEW_DIGEST}\"|" k8ssandra-cluster.yaml

# 4. Review, test, and commit
git diff k8ssandra-cluster.yaml
```

---

## Développement

**Structure des branches :**
- `development` - Branche par défaut, les commits y vont directement
- `main` - Releases de production uniquement (PR obligatoire)
- `feature/*` - Optionnelle, pour les fonctionnalités complexes

Voir [DEVELOPMENT.md](./DEVELOPMENT.md) pour les règles complètes.

**Workflow du développeur :**
```bash
# Work directly on development
git checkout development && git pull origin development
git add . && git commit -S -m "Add feature" && git push origin development

# For production: create PR development → main (approval required)
```

### Standards de sécurité des conteneurs (TOUS les composants)

**Chaque conteneur que nous construisons DOIT respecter ces pratiques de sécurité :**

1. **Épinglage par digest (sécurité de la chaîne d'approvisionnement)**
   - Épinglez **TOUJOURS** les images de base par digest SHA256, JAMAIS par tag
   - Les tags sont mutables — ils peuvent être remplacés de façon malveillante
   - Les digests sont immuables — garantis cryptographiquement
   - Exemple :
     ```dockerfile
     # CORRECT
     FROM upstream/image@sha256:abc123...

     # WRONG - Supply chain vulnerability!
     FROM upstream/image:latest
     FROM upstream/image:v1.0.0
     ```

2. **Signature des conteneurs (authenticité)**
   - **TOUTES** les images publiées DOIVENT être signées avec Cosign
   - Utilisez la signature sans clé avec GitHub OIDC (aucun secret à gérer)
   - Signez par digest immédiatement après le build
   - Publiez sur `ghcr.io/axonops/<component>/<image-name>:tag`

3. **Vérification et tests**
   - Vérifiez les sommes de contrôle des artefacts téléchargés (RPM, archives, etc.)
   - Vérifiez que le digest de l'image de base correspond à la version attendue
   - Détection automatisée des erreurs au démarrage
   - Analyse de sécurité avec Trivy avant publication

**Pourquoi ces standards comptent :**
- Ils empêchent les attaques sur la chaîne d'approvisionnement (images de base malveillantes)
- Ils garantissent l'authenticité des images (signatures Cosign)
- Ils fournissent une piste d'audit complète (digests + signatures)
- Ils répondent aux exigences de conformité des environnements régulés

## Publication des versions

### Publication en développement

**Objectif :** publier des images signées sur le registre de développement afin de les tester avant une release de production.

**Registre :** `ghcr.io/axonops/development/<component>/<image-name>`

**Exemple :** `ghcr.io/axonops/development/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0`

**Caractéristiques :**
- Toutes les images sont signées avec Cosign (comme en production)
- Mêmes standards de sécurité qu'en production (épinglage par digest, sommes de contrôle, vérification)
- Permet de tester des versions précises
- Aucune GitHub Release n'est créée
- Taguées depuis la branche `development`

**Procédure :**

```bash
# 1. Tag development branch (any name, e.g., dev-feature-x, dev-1.0.0)
git checkout development && git pull origin development
git tag dev-1.0.0 && git push origin dev-1.0.0

# 2. Trigger development publish workflow
gh workflow run development-<component>-publish.yml \
  -f dev_git_tag=dev-1.0.0 \
  -f container_version=dev-1.0.0

# 3. Test development image
docker pull ghcr.io/axonops/development-<image>:5.0.6-dev-1.0.0
# Run tests, validate functionality

# 4. Promote to main (auto-creates PR)
git tag merge-1.0.0 && git push origin merge-1.0.0
# PR auto-created, review and merge to main
```

**À utiliser pour :** tests de fonctionnalités, tests d'intégration, validation QA avant la mise en production.

---

### Publication en production

**Objectif :** publier des images stables et testées sur le registre de production.

**Registre :** `ghcr.io/axonops/<image-name>`

**Caractéristiques :**
- Immuable (la validation de version empêche les écrasements)
- Crée des GitHub Releases
- Taguée depuis la branche `main` uniquement
- Uniquement après des tests en développement

**Prérequis :**
- Modifications fusionnées dans `development` et testées
- Images de développement validées (si publiées)
- PR `development` → `main` approuvée et fusionnée

**Procédure :**

**Étape 1 : créer le tag Git sur la branche main**

**IMPORTANT :** les tags doivent être créés sur la branche `main`. Le workflow de publication le vérifie.

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main

# Tag the commit
git tag 1.0.0

# Push tag to remote
git push origin 1.0.0
```

Le tag peut porter n'importe quel nom (par exemple `1.0.0`, `v1.0.0`, `release-2024-12`). Il marque l'instantané de code exact à partir duquel construire.

**Note :** si vous taguez un commit qui n'est pas sur `main`, le workflow de publication échouera avec une erreur.

**Étape 2 : déclencher le workflow de publication**

Vous pouvez déclencher le workflow de publication via la **CLI GitHub** ou l'**interface GitHub**.

#### Option A : CLI GitHub

Installation et authentification (la première fois seulement) :
```bash
# macOS
brew install gh

# Linux
# See: https://github.com/cli/cli#installation

# Authenticate
gh auth login
```

Déclencher le workflow de publication signée :
```bash
gh workflow run <component>-publish-signed.yml \
  -f main_git_tag=1.0.0 \
  -f container_version=1.0.0
```

**Explication des arguments :**
- `-f main_git_tag=1.0.0` - Le tag Git sur la branche main à extraire et construire (celui créé à l'étape 1)
- `-f container_version=1.0.0` - La version de conteneur pour les images GHCR (produit par exemple `5.0.6-v0.1.110-1.0.5`)

**Note :** utilisez les workflows `-signed` (`k8ssandra-publish-signed.yml`) pour les nouvelles releases. Ils publient sur les nouveaux chemins d'images avec des signatures cryptographiques. Les anciens workflows subsistent pour compatibilité ascendante mais sont dépréciés.

Suivre l'avancement :
```bash
gh run watch
```

#### Option B : interface GitHub

1. Ouvrez l'onglet **Actions** du dépôt GitHub
2. Sélectionnez le workflow de publication (par exemple **K8ssandra Publish to GHCR**)
3. Cliquez sur le bouton **Run workflow** (en haut à droite)
4. Un formulaire apparaît avec ces champs :
   - **main_git_tag** : saisissez le tag Git de la branche main créé à l'étape 1 (par exemple `1.0.0`)
     - Il détermine quel code est construit
   - **container_version** : saisissez la version de conteneur (par exemple `1.0.0`)
     - Elle devient la version de conteneur des images publiées
     - Exemple : `5.0.6-v0.1.110-1.0.5`, où `1.0.0` est la version de conteneur
5. Cliquez sur **Run workflow** pour démarrer

**Étape 3 : exécution du workflow**

Le workflow de publication signée va :
- Vérifier que le tag est sur la branche main (échec sinon)
- Vérifier que `container_version` n'existe pas déjà dans GHCR (échec en cas de doublon)
- Extraire le commit `main_git_tag` (instantané de code exact)
- Exécuter la suite de tests complète
- Construire les images multi-architecture (amd64, arm64)
- Pousser vers GHCR avec des tags multi-dimensionnels
- **Signer les images** avec Sigstore Cosign (keyless, GitHub OIDC)
- Repousser les tags pour un affichage correct dans l'interface GHCR
- Créer une GitHub Release nommée `<component>-signed-<container_version>`

**Les images sont signées** en mode keyless avec des entrées dans le journal de transparence. Les signatures se vérifient avec `cosign verify` (voir [Vérifier les signatures](#vérifier-les-signatures)).

**Étape 4 : vérifier la release**

```bash
# View GitHub Release
gh release view k8ssandra-signed-1.0.0

# Pull and test image
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Verify signature
cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Or check signature exists
cosign tree ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

Toutes les images de production sont signées cryptographiquement. La vérification de signature prouve que l'image a été construite par les workflows officiels et qu'elle n'a pas été altérée. Voir [Déploiement sécurisé de référence](#déploiement-sécurisé-de-référence) pour plus de détails.

### Documentation de release par composant

Chaque composant dispose d'une documentation de release détaillée :
- [Processus de release K8ssandra](./k8ssandra/RELEASE.md)
- [Processus de release Schema Registry](./axonops-schema-registry/RELEASE.md)

## Remerciements

### Apache Cassandra
Nous saluons la communauté [Apache Cassandra](https://cassandra.apache.org/) pour son travail remarquable et ses contributions au domaine des bases de données distribuées. Apache Cassandra est un système de gestion de base de données NoSQL distribué, libre et open source, de type wide-column store, conçu pour traiter de grands volumes de données sur de nombreux serveurs standard, avec une haute disponibilité et sans point de défaillance unique.

Pour en savoir plus :
- [Site Apache Cassandra](https://cassandra.apache.org/)
- [GitHub Apache Cassandra](https://github.com/apache/cassandra)
- [Documentation Apache Cassandra](https://cassandra.apache.org/doc/latest/)

### K8ssandra
Nous saluons [K8ssandra](https://k8ssandra.io/), qui fournit un excellent opérateur Kubernetes et des outils d'administration pour Apache Cassandra. K8ssandra est une plateforme prête pour la production destinée à exécuter Apache Cassandra sur Kubernetes, avec sauvegarde/restauration, réparations et supervision.

Pour en savoir plus :
- [Site K8ssandra](https://k8ssandra.io/)
- [GitHub K8ssandra](https://github.com/k8ssandra/k8ssandra-operator)
- [Documentation K8ssandra](https://docs.k8ssandra.io/)

### AxonOps Schema Registry
Nous saluons [AxonOps Schema Registry](https://github.com/axonops/axonops-schema-registry), qui fournit un Schema Registry compatible Confluent prenant en charge plusieurs backends de stockage, dont PostgreSQL, MySQL et Apache Cassandra.

Pour en savoir plus :
- [GitHub AxonOps Schema Registry](https://github.com/axonops/axonops-schema-registry)

## Licence

Ce projet est distribué sous licence Apache License 2.0 — voir le fichier [LICENSE](LICENSE) pour les détails.

## Mentions légales

Ce projet peut contenir des marques ou des logos de projets, produits ou services tiers. Toute utilisation de marques ou de logos tiers est soumise aux politiques de ces tiers.

### Marques déposées

- **AxonOps** est une marque déposée d'AxonOps Limited
- **Apache**, **Apache Cassandra** et **Cassandra** sont des marques de l'Apache Software Foundation ou de ses filiales au Canada, aux États-Unis et/ou dans d'autres pays
- **Apache Kafka** et **Kafka** sont des marques de l'Apache Software Foundation
- **K8ssandra** est une marque de l'Apache Software Foundation
- **Docker** est une marque ou une marque déposée de Docker, Inc. aux États-Unis et/ou dans d'autres pays
- **Podman** est une marque de Red Hat, Inc.
- **OpenSearch** est une marque d'Amazon.com, Inc. ou de ses filiales
- **Kubernetes** est une marque déposée de The Linux Foundation

---

<div align="center">

**Made with ❤️ by [AxonOps](https://axonops.com)**

</div>
