# Exemple 00 — La plateforme AxonOps seule

[English](README.md) | **Français**

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Une installation AxonOps auto-hébergée complète — et rien d'autre. Faites-y
pointer les agents de vos propres hôtes, ou servez-vous-en comme base pour les
autres exemples.

- Vous voulez un cluster Cassandra supervisé dans le même projet ?
  [Exemple 01](../01-cassandra-cluster/README.fr.md) — la plateforme plus trois
  nœuds.
- Vous avez un compte AxonOps Cloud ?
  [Exemple 02](../02-saas-cassandra-cluster/README.fr.md) — un cluster qui
  remonte vers le SaaS, aucune plateforme à exécuter.

## Démarrage rapide

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose ps            # wait for all four services to report healthy
```

Ouvrez ensuite <http://localhost:3000>.

Un démarrage à froid prend 2 à 3 minutes : les deux magasins de données
s'initialisent d'abord, puis `axon-server` et le tableau de bord démarrent
derrière eux.

## Ce qui est exécuté

| Service | Image | Rôle | Port publié |
|---------|-------|------|-------------|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Stockage des métriques (Cassandra) | — |
| `axondb-search` | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Stockage des logs et événements (OpenSearch) | — |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35` | Backend et point de connexion des agents | `1888` |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash:2.0.37` | Tableau de bord web | `3000` |

Tags et digests actuels de chaque image : [VERSIONS.md](../../VERSIONS.md).

## Configuration

Tout se règle dans `.env`. Liste complète avec les valeurs par défaut :
[`env.example`](env.example).

| Variable | Défaut | Description |
|----------|--------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Nom de l'organisation, affiché dans le tableau de bord. Les agents doivent utiliser la même valeur. |
| `AXONOPS_LICENSE_KEY` | (vide) | Clé de licence ; vide, l'exécution se fait en mode d'évaluation |
| `AXONOPS_DB_PASSWORD` | `axonops` | Mot de passe d'`axondb-timeseries` |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Mot de passe administrateur d'`axondb-search` |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `4G` | Heap d'`axondb-timeseries` |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `4g` | Heap d'`axondb-search` |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS d'`axon-server` vers `axondb-search` |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS d'`axon-server` vers `axondb-timeseries` — voir ci-dessous |

`axon-server` se configure entièrement par variables d'environnement ; il n'y a
aucun fichier de configuration à monter ou à générer. Chacune remplace le champ
correspondant de l'`axon-server.yml` embarqué dans l'image —
`AXONSERVER_ORGNAME`, `LICENSE_KEY`, `TLS_MODE`, l'ensemble `CQL_*` pour le
stockage des métriques et l'ensemble `SEARCH_DB_*` pour celui des logs. La
correspondance complète figure dans
[l'exemple 01](../01-cassandra-cluster/README.fr.md#configuration).

### TLS entre les services

**Vers `axondb-search` : activé.** L'image génère ses propres certificats
auto-signés, `axon-server` s'y connecte en HTTPS et n'en vérifie pas la
validité.

**Vers `axondb-timeseries` : désactivé.** L'image n'active les
`client_encryption_options` de Cassandra que lorsqu'un keystore est monté sur
`CASSANDRA_KEYSTORE_PATH` — aucune variable d'environnement ne les active à elle
seule — le transport natif est donc en clair et `axon-server` doit s'aligner.
Activer `AXONOPS_CASSANDRA_SSL` sans monter de keystore casse la connexion ;
voir [Dépannage](#dépannage).

Tout ce trafic reste à l'intérieur du réseau Compose.

## Connecter des agents

Le point de connexion des agents (`1888`) est publié, les agents d'autres hôtes
peuvent donc s'y connecter :

```yaml
# axon-agent.yml on the monitored host
axon-server:
  hosts: "your-docker-host:1888"
axon-agent:
  org: "my-company"        # must match AXONOPS_ORG_NAME
```

Les agents en conteneur prennent les mêmes réglages sous forme de variables
d'environnement — `AXON_AGENT_SERVER_HOST`, `AXON_AGENT_SERVER_PORT`,
`AXON_AGENT_ORG`. L'exemple 01 met exactement cela en place pour un cluster
Cassandra dans le même projet.

## Figer une image : tags ou sommes de contrôle

Chaque `image:` de `docker-compose.yaml` peut s'écrire de deux façons. Les deux
sont montrées ci-dessous et fonctionnent — mais elles n'offrent pas du tout les
mêmes garanties.

```yaml
# Tag — readable, mutable
image: ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0

# Digest (SHA256 checksum) — preferred
image: ghcr.io/axonops/axondb-timeseries@sha256:1ae990a737d36b7c6f8eb92d6d3baf5234e5eae2a4e37fa208acd1108cad934c
```

**Utilisez le digest.** Un digest est une somme de contrôle cryptographique du
contenu exact de l'image : `docker compose pull` ne peut donc récupérer que les
octets sur lesquels vous avez testé. Un tag n'est qu'un pointeur mutable :
quiconque contrôle le registre peut le déplacer, et le même fichier Compose
démarre alors silencieusement une image différente. C'est ce risque sur la
chaîne d'approvisionnement que les digests suppriment.

Conseils pratiques :

| Référence | Quand l'utiliser |
|-----------|------------------|
| `@sha256:<digest>` | **En production, et pour tout ce que vous devez pouvoir reproduire.** Immuable, vérifiable, auditable. |
| `:5.0.8-1.4.0` (tag de version) | Développement et évaluation, là où la lisibilité compte plus que l'immuabilité. Ce dépôt ne réécrit jamais un tag de version publié, ces tags sont donc stables en pratique — simplement pas garantis cryptographiquement. |
| `:latest`, `:5.0.8` (tags flottants) | Jamais en production. Ils bougent à chaque release. |

Le compromis porte sur la lisibilité : un digest ne vous dit rien sur la version
que vous exécutez. Gardez le tag de version juste à côté, en commentaire, comme
le fait `docker-compose.yaml`, et consignez la correspondance dans
[VERSIONS.md](../../VERSIONS.md).

### Trouver le digest d'une version

Des références prêtes à copier-coller pour la version courante de chaque image
figurent dans [VERSIONS.md](../../VERSIONS.md), régénéré par
`../../scripts/update-versions.sh`.

Pour en résoudre un vous-même, sans télécharger l'image :

```bash
docker buildx imagetools inspect ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0 \
  --format '{{ .Manifest.Digest }}'
```

Ou, si vous l'avez déjà téléchargée :

```bash
docker inspect ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0 \
  --format '{{ index .RepoDigests 0 }}'
```

Toutes les images publiées sur GHCR sont signées avec Sigstore Cosign. Vérifiez
la signature contre le digest avant tout déploiement — voir
[Déploiement sécurisé de référence](../../README.fr.md#déploiement-sécurisé-de-référence)
pour la procédure complète et sa justification.

## Exploitation

```bash
docker compose ps                       # health of every service
docker compose logs -f                  # follow everything
docker compose logs -f axon-server      # follow one service
docker compose down                     # stop, keep data
docker compose down -v                  # stop and delete all volumes
```

Les données résident dans des volumes nommés : `axondb-timeseries-data`,
`axondb-timeseries-logs`, `axondb-search-data`, `axondb-search-logs`,
`axon-server-data`.

## Prérequis

- Docker Engine 20.10+ et Compose V2
- 10 Go de RAM libres aux valeurs par défaut ci-dessus, 16 Go recommandés ;
  20 Go de disque
- Ports 3000 et 1888 libres sur l'hôte

Sur une machine de développement disposant de moins de mémoire, abaissez les
deux heaps :

```bash
AXONOPS_CASSANDRA_HEAP_SIZE=2G
AXONOPS_OPENSEARCH_HEAP_SIZE=2g
```

## Dépannage

**Un service ne devient jamais sain.** Le premier démarrage prend 2 à 3 minutes.
Surveillez-le avec `docker compose ps`, puis lisez le log du service concerné :
`docker compose logs -f axondb-timeseries`.

**`axon-server` redémarre en boucle.** Il lui faut les deux magasins de données
en bonne santé — `depends_on: condition: service_healthy` impose l'ordre,
vérifiez donc d'abord `docker compose logs axondb-timeseries axondb-search`.
Confirmez ensuite que `AXONOPS_DB_PASSWORD` et `AXONOPS_SEARCH_PASSWORD`
concordent entre les magasins et `axon-server`.

**Mémoire insuffisante.** Abaissez `AXONOPS_CASSANDRA_HEAP_SIZE` et
`AXONOPS_OPENSEARCH_HEAP_SIZE` comme indiqué ci-dessus.

**Le tableau de bord ne se charge pas.** Vérifiez que le dash atteint le
backend :

```bash
docker exec axon-dash curl -s http://axon-server:8080/api/v1/healthz
```

**Cassandra journalise `Invalid or unsupported protocol version (22)` et
`axon-server` journalise `tls: first record does not look like a TLS
handshake`.** Un côté utilise TLS et l'autre non — 22 vaut `0x16`, le premier
octet d'un ClientHello TLS lu comme une version de protocole CQL. Mettez
`AXONOPS_CASSANDRA_SSL=false` sauf si vous avez monté un keystore, comme
expliqué dans [TLS entre les services](#tls-entre-les-services).

**D'autres réglages qui semblent corrects mais sont ignorés.** Trois de ces
images acceptent des paramètres sous des noms différents de ceux que leurs
propres README suggèrent, et chacune échoue sans nommer la variable fautive.
L'exemple 01 documente les trois :
[des variables de configuration qui semblent correctes mais ne le sont pas](../01-cassandra-cluster/README.fr.md#des-variables-de-configuration-qui-semblent-correctes-mais-ne-le-sont-pas).

## Licence

AxonOps requiert une licence pour un usage en production —
<https://axonops.com>. La stack fonctionne sans clé de licence en mode
d'évaluation, ce qui suffit pour tester et pour les autres exemples proposés
ici.

## Support

Maintenu par [AxonOps](https://axonops.com). Pour toute assistance,
contactez-nous sur [axonops.com/contact](https://axonops.com/contact).
