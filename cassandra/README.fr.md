# Conteneur Apache Cassandra AxonOps

[English](README.md) | **Français**

[![Paquet GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/cassandra%2Fcassandra)

Apache Cassandra avec l'agent de supervision et de gestion AxonOps, sans la Management API K8ssandra. Pour exécuter Cassandra en dehors de Kubernetes, ou à l'intérieur de Kubernetes sans l'opérateur K8ssandra.

Si vous déployez avec l'opérateur K8ssandra, utilisez plutôt [`ghcr.io/axonops/k8ssandra/cassandra`](../k8ssandra/README.fr.md).

## Comment l'image est construite

Il n'y a pas de Dockerfile séparé. Cette image est [`k8ssandra/5.0/Dockerfile`](../k8ssandra/5.0/Dockerfile) construit avec `INCLUDE_MGMT_API=false`, ce qui :

- supprime `/opt/management-api` et `/opt/cdc_agent`
- supprime de `cassandra-env.sh` l'agent java de la Management API, que l'image de base y intègre
- démarre Cassandra directement au lieu de passer par l'entrypoint de la Management API
- effectue le healthcheck de Cassandra sur le native transport au lieu de l'endpoint de liveness de la Management API (la vérification de l'agent est identique dans les deux cas)

Tout le reste — image de base, agent AxonOps, cqlai, jemalloc — est identique à l'image K8ssandra, et un seul Dockerfile sert les deux.

**Réserve sur la taille :** les fichiers de la Management API sont supprimés dans une couche dérivée. Ils ont donc disparu du conteneur en cours d'exécution, mais les couches de l'image de base les transportent toujours. Le téléchargement de l'image est environ 93 Mo plus lourd que son contenu ne le justifie.

## Image

```
ghcr.io/axonops/cassandra/cassandra:{CASSANDRA}-{AGENT}-{BUILD}
```

Par exemple, `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.0.0` correspond à Apache Cassandra 5.0.8 avec l'agent AxonOps 2.0.31, issu du build 1.0.0.

| Forme du tag | Mutable ? | Signification |
|----------|----------|---------|
| `5.0.8-2.0.31-1.0.0` | Non | Version exacte de Cassandra, version exacte de l'agent, build exact |
| `5.0.8-2.0.31` | Oui | Dernier build pour ce couple Cassandra + agent |
| `5.0.8` | Oui | Derniers agent et build pour cette version de Cassandra |
| `5.0-latest` | Oui | Dernière version corrective 5.0.x |
| `latest` | Oui | Dernière version toutes séries confondues |

La partie agent d'un tag est toujours une version concrète. Passer `latest` comme version d'agent au pipeline la résout vers la version réellement installée avant l'écriture du moindre tag.

Les builds de développement vont dans `ghcr.io/axonops/development/cassandra`, aux côtés des images de développement des autres composants, et ne sont pas destinés à la production.

Épinglez par digest tout ce à quoi vous tenez :

```bash
docker buildx imagetools inspect ghcr.io/axonops/cassandra/cassandra:5.0.8
```

## Démarrage rapide

```bash
docker run -d --name cassandra \
  -e AXON_AGENT_ORG=your-org \
  -e AXON_AGENT_KEY=your-agent-key \
  -e AXON_AGENT_CLUSTER_NAME=my-cluster \
  -p 9042:9042 \
  ghcr.io/axonops/cassandra/cassandra:5.0.8
```

`AXON_AGENT_ORG` est obligatoire ; le conteneur refuse de démarrer sans cette variable. Suivez la progression avec :

```bash
docker logs -f cassandra
docker exec cassandra nodetool status
docker exec cassandra cqlai -e "SELECT release_version FROM system.local;"
```

Des exemples multi-nœuds exécutables utilisant cette image se trouvent dans
[`docker-compose/`](../docker-compose/README.fr.md) : [01](../docker-compose/01-cassandra-cluster/)
supervise le cluster avec une stack AxonOps auto-hébergée,
[02](../docker-compose/02-saas-cassandra-cluster/) remonte vers AxonOps SaaS.

## Configuration

### Agent AxonOps

| Variable | Défaut | Description |
|----------|---------|-------------|
| `AXON_AGENT_ORG` | — | Organisation AxonOps. Obligatoire. |
| `AXON_AGENT_KEY` | — | Clé d'agent pour AxonOps SaaS. |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | Serveur AxonOps auquel se connecter. À renseigner en auto-hébergé. |
| `AXON_AGENT_SERVER_PORT` | `443` | Port du serveur AxonOps. |
| `AXON_AGENT_CLUSTER_NAME` | — | Nom du cluster affiché dans AxonOps. |
| `AXON_AGENT_TLS_MODE` | — | Mettre à `disabled` pour un serveur auto-hébergé en clair. |
| `AXON_AGENT_NTP_HOST` | détecté automatiquement | Hôte NTP utilisé pour les contrôles de dérive d'horloge. |
| `AXON_AGENT_ARGS` | — | Arguments supplémentaires passés à `axon-agent`. |

### Cassandra

Les mêmes variables `CASSANDRA_*` que celles acceptées par l'image K8ssandra et par l'image officielle Cassandra. Elles sont appliquées à `cassandra.yaml` et `cassandra-rackdc.properties` au démarrage.

| Variable | Défaut | Description |
|----------|---------|-------------|
| `CASSANDRA_SEEDS` | sa propre adresse de broadcast | Liste de seeds séparés par des virgules |
| `CASSANDRA_CLUSTER_NAME` | `Test Cluster` | Nom du cluster |
| `CASSANDRA_LISTEN_ADDRESS` | `auto` | `auto` se résout vers l'IP du conteneur |
| `CASSANDRA_BROADCAST_ADDRESS` | adresse d'écoute | Adresse utilisée par les autres nœuds |
| `CASSANDRA_RPC_ADDRESS` | `0.0.0.0` | Adresse d'écoute CQL |
| `CASSANDRA_BROADCAST_RPC_ADDRESS` | adresse de broadcast | Adresse annoncée aux clients |
| `CASSANDRA_NUM_TOKENS` | défaut Cassandra | Nombre de vnodes |
| `CASSANDRA_ENDPOINT_SNITCH` | défaut Cassandra | Snitch |
| `CASSANDRA_NATIVE_TRANSPORT_PORT` | `9042` | Port CQL |
| `CASSANDRA_AUTHENTICATOR` | `AllowAllAuthenticator` | Mettre à `PasswordAuthenticator` pour exiger des identifiants |
| `CASSANDRA_AUTHORIZER` | `AllowAllAuthorizer` | Mettre à `CassandraAuthorizer` pour appliquer les permissions |
| `CASSANDRA_ROLE_MANAGER` | `CassandraRoleManager` | Implémentation du gestionnaire de rôles |
| `CASSANDRA_DC` | défaut Cassandra | Datacenter dans `cassandra-rackdc.properties` |
| `CASSANDRA_RACK` | défaut Cassandra | Rack dans `cassandra-rackdc.properties` |

Un répertoire monté sur `/config` est copié par-dessus `$CASSANDRA_CONF` avant l'application de ces variables : monter un `cassandra.yaml` est donc le moyen de régler tout ce qui n'est pas listé ci-dessus.

Exemple multi-nœuds :

```bash
docker run -d --name cassandra-1 \
  -e AXON_AGENT_ORG=your-org -e AXON_AGENT_KEY=your-agent-key \
  -e CASSANDRA_CLUSTER_NAME=prod -e CASSANDRA_SEEDS=10.0.0.1,10.0.0.2 \
  -e CASSANDRA_DC=dc1 -e CASSANDRA_RACK=rack1 \
  -v /data/cassandra:/var/lib/cassandra \
  --network host \
  ghcr.io/axonops/cassandra/cassandra:5.0.8
```

| Chemin | Rôle |
|------|---------|
| `/opt/cassandra/conf` | Configuration Cassandra |
| `/config` | Surcouche de configuration optionnelle, copiée par-dessus la précédente au démarrage |
| `/var/lib/cassandra` | Répertoire de données |
| `/var/log/cassandra` | Logs Cassandra |
| `/var/log/axonops/axon-agent.log` | Log de l'agent |
| `/etc/axonops/build-info.txt` | Versions figées à la construction, affichées dans la bannière de démarrage |

Cassandra s'exécute sous l'utilisateur `cassandra`, jamais en root. L'agent tourne sous un superviseur qui le redémarre lorsqu'il s'arrête, avec un backoff anti-crash-loop ([#154](https://github.com/axonops/axonops-containers/issues/154)) ; le conteneur vit et meurt avec le processus Cassandra.

### Healthcheck

Le healthcheck du conteneur (`/usr/local/bin/axonops-healthcheck.sh`, exécuté toutes les 30 s) vérifie deux choses :

1. **Cassandra** — `nodetool statusbinary` indique que le native transport tourne, et le port CQL accepte les connexions. Dans l'image K8ssandra, où la Management API est présente, c'est son endpoint de liveness qui est utilisé à la place.
2. **Agent AxonOps** — le processus `axon-agent` tourne, donc le nœud est réellement supervisé.

Par défaut, un agent mort est signalé dans la sortie du healthcheck mais ne rend pas le conteneur unhealthy : Cassandra sert toujours le CQL, et faire échouer la vérification peut amener un orchestrateur à redémarrer ou à drainer un nœud qui fait un travail utile. Mettez `HEALTHCHECK_REQUIRE_AGENT=true` pour traiter un agent mort comme un échec.

| Variable | Défaut | Description |
|----------|---------|-------------|
| `HEALTHCHECK_REQUIRE_AGENT` | `false` | `true` rend le conteneur unhealthy lorsque `axon-agent` ne tourne pas |

```bash
# Current status and the last check's output
docker inspect --format '{{.State.Health.Status}}' cassandra-1
docker inspect --format '{{(index .State.Health.Log 0).Output}}' cassandra-1

# Run it by hand
docker exec cassandra-1 /usr/local/bin/axonops-healthcheck.sh
```

L'agent n'est démarré qu'une fois Cassandra opérationnel : il est donc normalement absent pendant la première partie de la période de démarrage de 120 s. C'est à cela que sert cette période — avec `HEALTHCHECK_REQUIRE_AGENT=true` sur un nœud lent à démarrer, augmentez-la plutôt que de réduire le nombre de tentatives.

## Versions prises en charge

Apache Cassandra 4.0.0 à 4.0.21, 4.1.0 à 4.1.12 et 5.0.1 à 5.0.9 — 42 versions au total (4.0.2 et 4.0.16 n'ont pas d'image de base et sont ignorées). La matrice est bornée par la variable de dépôt `K8SSANDRA_VERSIONS`, qui épingle un digest d'image de base par version de Cassandra — une version ne peut être construite ici que si elle y possède une entrée.

## Construire en local

```bash
DIGEST=$(gh api /repos/axonops/axonops-containers/actions/variables/K8SSANDRA_VERSIONS \
  --jq '.value | fromjson | ."5.0.9+0.1.125"')

docker build -t axonops-cassandra:local \
  --build-arg CASSANDRA_VERSION=5.0.9 \
  --build-arg MAJOR_VERSION=5.0 \
  --build-arg K8SSANDRA_BASE_DIGEST="$DIGEST" \
  --build-arg K8SSANDRA_API_VERSION=0.1.125 \
  --build-arg INCLUDE_MGMT_API=false \
  --build-arg CQLAI_VERSION=0.1.7 \
  k8ssandra/5.0
```

Retirez `INCLUDE_MGMT_API=false` pour construire l'image K8ssandra à la place — la valeur par défaut est `true`.

## Pipelines

Les commandes de déclenchement sont dans [PIPELINES.md](../PIPELINES.md).

| Workflow | Rôle |
|----------|---------|
| `cassandra-build-and-test.yml` | Construit et teste sur les pull requests ; ne publie rien |
| `cassandra-publish-signed.yml` | Build de production, publication et signature cosign depuis un tag sur `main` |
| `cassandra-development-publish-signed.yml` | Build de développement publié sur `ghcr.io/axonops/development/cassandra` |

Chaque image publiée est signée avec cosign Sigstore en mode keyless :

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/axonops/axonops-containers" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.0.0
```

## Support

Maintenu par [AxonOps](https://axonops.com). Pour toute demande de support, contactez-nous à [axonops.com/contact](https://axonops.com/contact).
