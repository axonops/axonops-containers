# Exemple 02 — AxonOps SaaS supervisant un cluster Cassandra de 3 nœuds

[English](README.md) | **Français**

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Un cluster Apache Cassandra de 3 nœuds dont les agents remontent vers AxonOps
SaaS. Aucune plateforme AxonOps ne tourne localement — les seuls conteneurs sont
les nœuds Cassandra, et le tableau de bord est celui hébergé.

- Vous préférez toute la plateforme sur votre propre machine ?
  [Exemple 01](../01-cassandra-cluster/README.fr.md) — même cluster, AxonOps
  auto-hébergé.
- Vous exploitez déjà Cassandra ou Kafka ailleurs ?
  [Exemple 00](../00-axonops-platform/README.fr.md) — la plateforme seule.

## Démarrage rapide

```bash
cp env.example .env          # set AXONOPS_ORG_NAME and AXONOPS_AGENT_KEY
docker compose up -d
docker compose ps            # wait for all three nodes to report healthy
```

Ouvrez ensuite <https://console.axonops.cloud> et choisissez le cluster
`saas-demo-cluster`. Les nœuds apparaissent au fur et à mesure de leur
démarrage ; un démarrage à froid prend 3 à 5 minutes car ils démarrent un à un.

Le nom de votre organisation et votre clé d'agent proviennent tous deux de votre
compte AxonOps Cloud — inscrivez-vous sur <https://axonops.cloud>, et consultez
la [configuration de l'agent](https://axonops.com/docs/get_started/agent_setup/)
pour savoir où la clé est affichée. Les agents ne démarreront pas sans eux :
Compose échoue immédiatement avec `set AXONOPS_AGENT_KEY in .env` plutôt que de
démarrer un cluster qui ne remonterait nulle part.

## Ce qui est exécuté

| Service | Image | Rôle | Port publié |
|---------|-------|------|-------------|
| `cassandra-0` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Nœud seed, `rack0` | `9042` |
| `cassandra-1` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | `rack1` | — |
| `cassandra-2` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | `rack2` | — |

Un seul datacentre, `dc1`, avec un rack par nœud. Seul `cassandra-0` publie CQL
vers l'hôte ; les autres sont joignables à l'intérieur du réseau Compose et via
`docker exec`.

Tags et digests actuels de chaque image : [VERSIONS.md](../../VERSIONS.md).

## Ce que le SaaS change

Trois différences comptent lorsque vous utilisez cet exemple plutôt que
[l'exemple 01](../01-cassandra-cluster/README.fr.md) ; la comparaison complète
figure dans [l'index](../README.fr.md#lequel-me-faut-il-).

- **Les identifiants.** Le SaaS exige une clé d'agent en plus d'un nom
  d'organisation. Les deux sont obligatoires — Compose refuse de démarrer sans
  eux.
- **TLS est activé.** Les agents utilisent par défaut
  `AXON_AGENT_TLS_MODE=TLS` avec vérification du certificat ; l'exemple 01
  désactive TLS parce que ce trafic ne quitte jamais le réseau Compose, ce qui
  n'est pas le cas ici.
- **Vos métriques quittent l'hôte.** Elles sont stockées dans AxonOps SaaS
  plutôt que dans un `axondb-timeseries` local, et le tableau de bord est celui
  hébergé.

## Configuration

Tout se règle dans `.env`. Liste complète avec les valeurs par défaut :
[`env.example`](env.example).

| Variable | Défaut | Description |
|----------|--------|-------------|
| `AXONOPS_ORG_NAME` | — | Organisation AxonOps. Obligatoire. |
| `AXONOPS_AGENT_KEY` | — | Clé d'agent issue de la console. Obligatoire. |
| `CASSANDRA_CLUSTER_NAME` | `saas-demo-cluster` | Nom du cluster affiché dans AxonOps |
| `CASSANDRA_DC` | `dc1` | Nom du datacentre |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Image des nœuds |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap par nœud |
| `CASSANDRA_HEAP_NEWSIZE` | `256M` | Génération jeune par nœud |
| `CQL_PORT` | `9042` | Port hôte pour CQL sur `cassandra-0` |
| `AXONOPS_SERVER_HOST` | `agents.axonops.cloud` | Point de connexion des agents |
| `AXONOPS_SERVER_PORT` | `443` | Port du point de connexion des agents |
| `AXONOPS_NTP_HOST` | `time.google.com` | Hôte NTP pour le contrôle de dérive d'horloge de l'agent |

La clé d'agent est un secret. `.env` est ignoré par git — ne le committez pas,
et n'intégrez pas la clé dans une image.

### Prérequis réseau

Les agents établissent des connexions TLS **sortantes** vers
`agents.axonops.cloud:443`. Aucun flux entrant n'est nécessaire. Derrière un
proxy de sortie ou un pare-feu, autorisez cet hôte et ce port ; il n'existe
aucun repli en clair.

Vérifiez qu'un agent est connecté :

```bash
docker compose exec cassandra-0 tail -f /var/log/axonops/axon-agent.log
```

Un agent en bonne santé journalise une connexion réussie. `Unable to connect to
axonops services` signifie que le point de connexion est injoignable ou que la
clé est erronée.

### Santé des nœuds

Les nœuds utilisent le healthcheck fourni par l'image,
`/usr/local/bin/axonops-healthcheck.sh`, plutôt qu'un contrôle écrit ici. Il
vérifie à la fois que Cassandra sert bien CQL et que le processus `axon-agent`
tourne — ce qui compte davantage ici que dans les exemples auto-hébergés,
puisqu'un nœud dont l'agent est mort ne remonte plus rien au SaaS tout en
continuant de répondre aux requêtes.

Un agent mort est signalé dans la sortie du contrôle mais ne rend pas à lui seul
le conteneur non sain ; faire échouer le contrôle peut amener un orchestrateur à
redémarrer ou vider un nœud qui sert encore. Mettez
`HEALTHCHECK_REQUIRE_AGENT=true` pour traiter ce cas comme un échec :

```bash
docker compose exec cassandra-0 /usr/local/bin/axonops-healthcheck.sh
```

L'agent ne démarre qu'une fois Cassandra opérationnel, il est donc normalement
absent pendant une partie de la période de démarrage de 90 s.

Le contrôle de l'agent est arrivé dans `axonops-healthcheck.sh` après la
publication de l'image actuellement figée : sur
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`, le script ne vérifie
donc que Cassandra et `HEALTHCHECK_REQUIRE_AGENT` n'a aucun effet. Les deux
prendront effet à la prochaine publication de l'image Cassandra.

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
docker compose ps                       # health of every node
docker compose logs -f cassandra-0      # Cassandra output
docker compose exec cassandra-0 tail -f /var/log/axonops/axon-agent.log
docker compose down                     # stop, keep data
docker compose down -v                  # stop and delete all volumes
```

## Prérequis

- Docker Engine 20.10+ et Compose V2
- 5 Go de RAM libres aux valeurs par défaut ci-dessus, 10 Go de disque
- Port 9042 libre sur l'hôte, ou définissez `CQL_PORT`
- HTTPS sortant vers `agents.axonops.cloud`
- Une organisation AxonOps SaaS et une clé d'agent

## Dépannage

**Compose refuse de démarrer avec `set AXONOPS_AGENT_KEY in .env`.** C'est le
comportement voulu — `AXONOPS_ORG_NAME` et `AXONOPS_AGENT_KEY` sont tous deux
obligatoires, et un cluster sans clé ne remonterait vers rien.

**Le cluster n'apparaît jamais dans la console.** Cherchez la ligne de connexion
dans le log de l'agent. Les causes habituelles sont une clé appartenant à une
autre organisation, un filtrage de sortie sur le port 443, ou une horloge
décalée de plus de quelques secondes — l'agent journalise alors un
avertissement NTP.

**Un nœud ne devient jamais sain.** Les nœuds démarrent un à un et
`start_period` vaut 90 s. Surveillez `docker compose logs -f cassandra-1`. Le
manque de mémoire en est la cause habituelle — abaissez `CASSANDRA_HEAP_SIZE`.

**Une variable semble ignorée.** L'agent lit les noms `AXON_AGENT_*` liés dans
son propre paquet de configuration — `AXON_AGENT_ORG`, `AXON_AGENT_KEY`,
`AXON_AGENT_SERVER_HOST`, `AXON_AGENT_SERVER_PORT`, `AXON_AGENT_CLUSTER_NAME`,
`AXON_AGENT_TLS_MODE`, `AXON_AGENT_NTP_HOST`. Les noms proches mais inexacts
sont ignorés silencieusement. L'exemple 01 documente
[le même piège dans les autres services](../01-cassandra-cluster/README.fr.md#des-variables-de-configuration-qui-semblent-correctes-mais-ne-le-sont-pas).

**Les nœuds sont sains mais apparaissent dans un seul rack.**
`CASSANDRA_RACK` est fixé par service dans `docker-compose.yaml` ; si vous
changez `CASSANDRA_DC` après le premier démarrage, les répertoires de données
existants conservent l'ancienne valeur. Faites `docker compose down -v` et
recommencez.

## Support

Maintenu par [AxonOps](https://axonops.com). Pour toute assistance,
contactez-nous sur [axonops.com/contact](https://axonops.com/contact).
