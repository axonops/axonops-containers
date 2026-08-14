# Exemple 01 — AxonOps auto-hébergé supervisant un cluster Cassandra de 3 nœuds

[English](README.md) | **Français**

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Une installation AxonOps complète et le cluster Apache Cassandra qu'elle
supervise, dans un seul projet Docker Compose. Chaque image provient de ce dépôt
ou du registre public AxonOps. Commencez ici si vous évaluez AxonOps.

- Vous exploitez déjà Cassandra ou Kafka et cherchez seulement un endroit où les
  agents peuvent remonter leurs données ?
  [Exemple 00](../00-axonops-platform/README.fr.md) — la plateforme seule.
- Vous avez un compte AxonOps Cloud ?
  [Exemple 02](../02-saas-cassandra-cluster/README.fr.md) — le même cluster,
  aucune plateforme à exécuter.

## Démarrage rapide

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose ps            # wait for all services to report healthy
```

Ouvrez ensuite <http://localhost:3000>, choisissez votre organisation, puis le
cluster `demo-cluster`.

Un démarrage à froid prend 5 à 10 minutes : les magasins de données AxonOps
s'initialisent d'abord, puis les nœuds Cassandra démarrent un à un.

## Ce qui est exécuté

| Service | Image | Rôle | Port publié |
|---------|-------|------|-------------|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Stockage des métriques (Cassandra) | — |
| `axondb-search` | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Stockage des logs et événements (OpenSearch) | — |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35` | Backend AxonOps et point de connexion des agents | `1888` |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash:2.0.37` | Tableau de bord web | `3000` |
| `cassandra-0` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Cluster supervisé, nœud seed | `9042` |
| `cassandra-1` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Cluster supervisé, rack1 | — |
| `cassandra-2` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Cluster supervisé, rack2 | — |

`cassandra-0` à `cassandra-2` forment un seul datacentre, `dc1`, avec un rack
chacun. Seul `cassandra-0` publie CQL vers l'hôte ; les deux autres sont
joignables à l'intérieur du réseau Compose et via `docker exec`.

Tags et digests actuels de chaque image : [VERSIONS.md](../../VERSIONS.md).

## Configuration

Tout se règle dans `.env`. Liste complète avec les valeurs par défaut :
[`env.example`](env.example).

| Variable | Défaut | Description |
|----------|--------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Nom de l'organisation. Partagé par `axon-server` et les agents — les valeurs doivent concorder. |
| `CASSANDRA_CLUSTER_NAME` | `demo-cluster` | Nom du cluster supervisé dans AxonOps |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Image des nœuds supervisés |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap par nœud supervisé |
| `CASSANDRA_HEAP_NEWSIZE` | `256M` | Génération jeune par nœud supervisé |
| `AXONOPS_LICENSE_KEY` | (vide) | Clé de licence ; vide, l'exécution se fait en mode d'évaluation |
| `AXONOPS_DB_PASSWORD` | `axonops` | Mot de passe d'`axondb-timeseries` |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Mot de passe administrateur d'`axondb-search` |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `2G` | Heap d'`axondb-timeseries` |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `2g` | Heap d'`axondb-search` |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS d'`axon-server` vers `axondb-timeseries` — laissez désactivé sauf si vous montez un keystore, voir [ci-dessous](#des-variables-de-configuration-qui-semblent-correctes-mais-ne-le-sont-pas) |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS d'`axon-server` vers `axondb-search` |

`axon-server` se configure entièrement par variables d'environnement — il n'y a
aucun fichier de configuration à monter ou à générer. Chaque variable remplace le
champ correspondant de l'`axon-server.yml` embarqué dans l'image :

| axon-server.yml | Variable d'environnement |
|-----------------|--------------------------|
| `org_name` | `AXONSERVER_ORGNAME` |
| `license_key` | `LICENSE_KEY` |
| `tls.mode` | `TLS_MODE` |
| `log_file` | `AXON_LOG_FILE` |
| `axon_dash_url` | `AXONDASH_HOST`, `AXONDASH_PORT`, `AXONDASH_HTTPS` |
| `cql_hosts` | `CQL_HOSTS` (séparés par des virgules) |
| `cql_username` / `cql_password` | `CQL_USERNAME` / `CQL_PASSWORD` |
| `cql_local_dc` | `CQL_LOCAL_DC` |
| `cql_ssl` / `cql_skip_verify` | `CQL_SSL` / `CQL_SSL_SKIP_VERIFY` |
| `cql_keyspace_replication` | `CQL_KS_REPLICATION` |
| `search_db.hosts` | `SEARCH_DB_HOSTS` (séparés par des virgules) |
| `search_db.username` / `password` | `SEARCH_DB_USERNAME` / `SEARCH_DB_PASSWORD` |
| `search_db.skip_verify` | `SEARCH_DB_SKIP_VERIFY` |

axon-server lie 72 variables au total, couvrant la politique de réessai et de
reconnexion, les niveaux de cohérence, les fenêtres de compaction,
l'authentification LDAP et SMTP. Tout ce qui n'est pas défini conserve la valeur
de l'`axon-server.yml` propre à l'image.

Les anciennes variables `ELASTIC_*` sont la génération précédente des variables
`SEARCH_DB_*` — ne mélangez pas les deux formes.

Les agents se connectent à `axon-server:1888` en clair
(`AXON_AGENT_TLS_MODE=disabled`) parce que ce trafic ne quitte jamais le réseau
Compose. Utilisez TLS pour des agents situés sur tout autre hôte.

### Santé des nœuds supervisés

Les nœuds Cassandra utilisent le healthcheck fourni par l'image,
`/usr/local/bin/axonops-healthcheck.sh`, plutôt qu'un contrôle écrit ici. Il
vérifie deux choses : que Cassandra sert bien CQL, et que le processus
`axon-agent` tourne — un nœud dont l'agent est mort répond encore aux requêtes
mais a discrètement disparu d'AxonOps, et un contrôle qui ne regarde que
Cassandra le déclare sain.

Un agent mort est signalé dans la sortie du contrôle mais ne rend pas à lui seul
le conteneur non sain, car faire échouer le contrôle peut amener un
orchestrateur à redémarrer ou vider un nœud qui sert encore. Mettez
`HEALTHCHECK_REQUIRE_AGENT=true` sur un nœud pour traiter ce cas comme un
échec :

```bash
docker compose exec cassandra-0 /usr/local/bin/axonops-healthcheck.sh
```

L'agent ne démarre qu'une fois Cassandra opérationnel, il est donc normalement
absent pendant une partie de la période de démarrage de 90 s.

Le contrôle de l'agent et `HEALTHCHECK_REQUIRE_AGENT` sont tous deux présents
dans l'image figée, `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`.
Sur toute image antérieure, le script ne vérifie que Cassandra et la variable
n'a aucun effet.

## Utiliser le cluster

```bash
# CQL from the host
cqlsh 127.0.0.1 9042

# CQL from inside a node, using the bundled cqlai client
docker compose exec cassandra-0 cqlai -e "SELECT release_version FROM system.local;"

# Ring status
docker compose exec cassandra-0 nodetool status
```

Écrivez quelques données pour que le tableau de bord ait quelque chose à
montrer :

```bash
docker compose exec cassandra-0 cqlai -e "
  CREATE KEYSPACE IF NOT EXISTS demo
    WITH replication = {'class':'NetworkTopologyStrategy','dc1':3};
  CREATE TABLE IF NOT EXISTS demo.events (
    id uuid PRIMARY KEY, created timestamp, payload text);
  INSERT INTO demo.events (id, created, payload)
    VALUES (uuid(), toTimestamp(now()), 'hello');"
```

## Exploitation

```bash
docker compose ps                       # health of every service
docker compose logs -f axon-server      # follow one service
docker compose logs -f cassandra-0
docker compose exec cassandra-0 tail -f /var/log/axonops/axon-agent.log
docker compose down                     # stop, keep data
docker compose down -v                  # stop and delete all volumes
```

## Prérequis

- Docker Engine 20.10+ et Compose V2
- 10 Go de RAM libres aux valeurs par défaut ci-dessus, 20 Go de disque
- Ports 3000, 1888 et 9042 libres sur l'hôte

Abaissez `CASSANDRA_HEAP_SIZE`, `AXONOPS_CASSANDRA_HEAP_SIZE` et
`AXONOPS_OPENSEARCH_HEAP_SIZE` si vous disposez de moins de mémoire. Il s'agit
d'une stack de développement et d'évaluation ; le dimensionnement pour la
production est décrit dans la documentation de la stack de
[l'exemple 00](../00-axonops-platform/README.fr.md#prérequis).

## Dépannage

**Un nœud Cassandra ne devient jamais sain.** Les nœuds démarrent un à un et
`start_period` vaut 90 s. Surveillez avec
`docker compose logs -f cassandra-1`. Le manque de mémoire en est la cause
habituelle — abaissez `CASSANDRA_HEAP_SIZE`.

**Le cluster n'apparaît pas dans le tableau de bord.** L'agent et `axon-server`
doivent partager une organisation. `AXONOPS_ORG_NAME` dans `.env` définit les
deux ; vérifiez avec
`docker compose exec cassandra-0 env | grep AXON_AGENT_ORG`.

**`axon-server` redémarre en boucle.** Il lui faut les deux magasins de données
en bonne santé. Vérifiez `docker compose logs axondb-timeseries axondb-search`,
et confirmez que `AXONOPS_DB_PASSWORD` et `AXONOPS_SEARCH_PASSWORD` concordent
entre eux et `axon-server`.

### Des variables de configuration qui semblent correctes mais ne le sont pas

Trois des services acceptent des paramètres sous des noms différents de ceux que
leurs README suggèrent. Chacun de ces cas a été rencontré en montant cet
exemple, et chacun échoue d'une manière qui ne nomme pas la variable fautive.

**`axondb-search` s'arrête sur un échec de bootstrap check.**

```
ERROR: [1] bootstrap checks failed
[1]: the default discovery settings are unsuitable for production use;
     at least one of [discovery.seed_hosts, discovery.seed_providers,
     cluster.initial_cluster_manager_nodes] must be configured
```

`OPENSEARCH_DISCOVERY_TYPE` était documentée et affichée dans la bannière de
démarrage du conteneur, mais les builds antérieurs à `3.7.0-1.6.1` ne l'ont
jamais écrite dans `opensearch.yml`. Elle fonctionne à partir de
`3.7.0-1.6.1`. Cet exemple passe aussi le `discovery.type=single-node` propre à
OpenSearch, que le processus lit directement, si bien que le fichier continue de
fonctionner avec une image plus ancienne ; supprimez cette ligne une fois que
vous êtes partout en `3.7.0-1.6.1` ou plus récent.

**Cassandra journalise `Invalid or unsupported protocol version (22)`, et
`axon-server` journalise `tls: first record does not look like a TLS
handshake`.**

22 vaut `0x16`, le premier octet d'un ClientHello TLS lu comme une version de
protocole CQL — un côté utilise TLS et l'autre non. `axondb-timeseries` n'active
`client_encryption_options` que lorsqu'un keystore est monté sur
`CASSANDRA_KEYSTORE_PATH` ; aucune variable ne l'active à elle seule, et
`CASSANDRA_CLIENT_ENCRYPTION_ENABLED` ne fait rien. Le transport natif est donc
en clair et `CQL_SSL` doit valoir `false` pour s'aligner. Pour utiliser TLS,
montez un keystore et réglez les deux côtés ensemble.

**`axon-dash` redémarre en boucle avec `findHost | no reachable endpoints` et
`ECONNREFUSED 127.0.0.1:8080`.**

`axon-dash` fait correspondre son `axon-dash.yml` à des variables
d'environnement par section et par clé — `axon-server.private_endpoints` devient
`AXONSERVER_PRIVATE_ENDPOINTS`, `axon-dash.port` devient `AXONDASH_PORT`. Il
accepte aussi tout ce qui est préfixé par `AXON_SERVER_`, le passe en minuscules
et le fusionne dans la section `axon-server` — ce qui signifie qu'un nom erroné
tel que `AXON_SERVER_URL` est accepté silencieusement et apparaît dans la
configuration que le dash affiche au démarrage, sans avoir le moindre effet.
L'adresse que le dash contacte réellement est `private_endpoints` ; vérifiez-la
dans ce bloc de configuration affiché.

## Support

Maintenu par [AxonOps](https://axonops.com). Pour toute assistance,
contactez-nous sur [axonops.com/contact](https://axonops.com/contact).
