# Exemple 03 — Un cluster sécurisé à 3 racks, supervisé par AxonOps

[English](README.md) | **Français** | [Español](README.es.md) | [Galego](README.gl.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Un cluster Cassandra de trois nœuds avec l'authentification activée, le JMX
distant ouvert, un rack par nœud et une adresse fixe pour chaque conteneur —
puis toute la plateforme AxonOps qui le supervise.

Il s'agit d'un portage d'une stack communautaire très répandue,
[crystalloide/cassandra-reaper](https://github.com/crystalloide/cassandra-reaper)
(« Cluster 3 noeuds 3 racks 1 DC Prometheus Grafana Reaper sécurisé »). Le
cluster est conservé tel quel ; Prometheus, Grafana, les trois sidecars
`cassandra_exporter` et Reaper sont remplacés par AxonOps, qui couvre les
métriques, les logs, les alertes et la planification des réparations au même
endroit. [Ce qui a changé](#ce-qui-a-changé-par-rapport-à-la-stack-dorigine)
liste toutes les différences.

- Vous voulez la même chose sans les réglages de sécurité ni l'adressage
  statique ? [Exemple 01](../01-cassandra-cluster/README.fr.md) — la stack
  auto-hébergée la plus simple.
- Vous avez un compte AxonOps Cloud ?
  [Exemple 02](../02-saas-cassandra-cluster/README.fr.md) — un cluster qui
  remonte vers le SaaS, aucune plateforme à exécuter.

## Avant de commencer

Les trois nœuds sont figés sur le tag de version complet
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`, et non sur le tag
flottant `5.0.8`. Cela compte davantage ici que dans les autres exemples.

L'authentification est définie par `CASSANDRA_AUTHENTICATOR` et
`CASSANDRA_AUTHORIZER`, que le point d'entrée de l'image applique à
`cassandra.yaml`. **Les images publiées avant le build 1.1.0 ignorent les deux
variables** : le cluster démarre, rejoint l'anneau et apparaît dans AxonOps
exactement comme prévu, et accepte toutes les connexions sans mot de passe.
Rien dans les logs ne le signale.

Donc si vous changez `CASSANDRA_IMAGE`, restez en 1.1.0 ou plus récent, et
vérifiez ce que vous avez réellement obtenu une fois la stack démarrée :

```bash
for n in cassandra01 cassandra02 cassandra03; do
  printf '%s: ' "$n"
  docker exec "$n" grep '^authenticator:' /opt/cassandra/conf/cassandra.yaml
done
# authenticator: PasswordAuthenticator   <- secured
# authenticator: AllowAllAuthenticator   <- image too old, see above
```

Vérifiez chaque nœud, pas seulement le premier. Un seul nœud resté sur une image
qui ignore `CASSANDRA_AUTHENTICATOR` rejoint le cluster et accepte des
connexions non authentifiées sur son propre port CQL — un cluster n'est sécurisé
qu'à hauteur de son nœud le moins sécurisé.

## Démarrage rapide

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
./setup.sh                   # create and seed ./docker/, once
docker compose up -d
docker compose ps            # wait for all seven services to report healthy
```

`setup.sh` n'est pas facultatif : les trois nœuds lisent leur configuration dans
des répertoires de l'hôte sous [`./docker/`](#stockage), et Cassandra ne
démarrera pas avec un répertoire vide.

Ouvrez ensuite <http://localhost:3000>.

Un démarrage à froid prend 6 à 10 minutes. Les deux magasins de données AxonOps
s'initialisent d'abord, puis `axon-server` et le tableau de bord, et seulement
ensuite le cluster — un nœud à la fois, car Cassandra ne démarre qu'un nœud à la
fois.

Une fois le cluster opérationnel, effectuez les
[deux étapes de sécurisation post-démarrage](#finir-de-sécuriser-le-cluster).
Cassandra est livré avec un superutilisateur par défaut bien connu et un
keyspace `system_auth` qui ne survit pas à la perte d'un nœud.

## Ce qui est exécuté

| Service | Adresse | Image | Rôle | Port publié |
|---------|---------|-------|------|-------------|
| `cassandra01` | 10.17.64.5 | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Nœud du cluster, rack1 | `9142` CQL, `7199` JMX¹ |
| `cassandra02` | 10.17.64.6 | idem | Nœud du cluster, rack2 | `9242` CQL, `7299` JMX¹ |
| `cassandra03` | 10.17.64.7 | idem | Nœud du cluster, rack3 | `9342` CQL, `7399` JMX¹ |
| `axondb-timeseries` | 10.17.64.20 | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Stockage des métriques (Cassandra mono-nœud) | — |
| `axondb-search` | 10.17.64.21 | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Stockage des logs et événements (OpenSearch) | — |
| `axon-server` | 10.17.64.22 | `axon-server:2.0.35` | Backend et point de connexion des agents | `1888` |
| `axon-dash` | 10.17.64.23 | `axon-dash:2.0.37` | Tableau de bord web | `3000` |

¹ Liés à `127.0.0.1` uniquement — voir [JMX distant](#jmx-distant).

Tags et digests actuels de chaque image : [VERSIONS.md](../../VERSIONS.md).

## Le cluster

| | |
|---|---|
| Topologie | 1 datacentre, 3 racks, un nœud par rack |
| Snitch | `GossipingPropertyFileSnitch` |
| Adressage | Statique, sur le réseau bridge `10.17.64.0/24` |
| Seeds | Les trois nœuds |
| Tokens | 16 par nœud |
| Authentification | `PasswordAuthenticator` |
| Autorisation | `CassandraAuthorizer` |
| JMX | Distant, non authentifié, publié sur localhost uniquement |
| Ramasse-miettes | ZGC, en remplacement du G1 par défaut de Cassandra 5.0 |

**Pourquoi des adresses statiques.** Le JMX distant exige que
`java.rmi.server.hostname` pointe vers une adresse qu'un client peut réellement
joindre, et le stub RMI que renvoie un nœud transporte cette adresse. Une adresse
Docker attribuée par DHCP change à chaque recréation, et la valeur figée dans
`JVM_EXTRA_OPTS` pointerait alors ailleurs. Le sous-réseau est donc fixé dans
`docker-compose.yaml`, et non paramétrable : le changer implique de modifier
ensemble les sept entrées `ipv4_address`, `CASSANDRA_SEEDS`,
`CASSANDRA_LISTEN_ADDRESS`, `CASSANDRA_BROADCAST_RPC_ADDRESS` et
`java.rmi.server.hostname`.

**Pourquoi les trois nœuds sont des seeds.** Hérité de la stack d'origine. C'est
acceptable pour un cluster créé à vide, ce qui est le cas ici : les seeds
sautent le streaming de bootstrap, et il n'y a rien à streamer. Pour un cluster
que vous agrandissez ensuite, faites des nouveaux nœuds des non-seeds afin
qu'ils effectuent correctement leur bootstrap.

## Stockage

Les trois nœuds du cluster conservent à la fois leurs données et leur
configuration dans des répertoires de l'hôte, et non dans des volumes gérés par
Docker :

```
docker/cassandra01        ->  /var/lib/cassandra    données, simple bind mount
docker/cassandra01-conf   ->  /opt/cassandra/conf   configuration, un volume
                                                    nommé lié au chemin
```

… et de même pour `cassandra02` et `cassandra03`. Les services de la plateforme
AxonOps utilisent des volumes nommés ordinaires.

Les deux chemins s'écrivent `${PWD}/docker/…`, comme dans la stack d'origine :
**lancez donc `docker compose` depuis ce répertoire**. Le piloter d'ailleurs avec
`-f docker-compose/03-secure-3-rack-cluster/docker-compose.yaml` résout `${PWD}`
vers l'endroit où vous êtes et monte les mauvais répertoires.

**C'est délibéré, et ce n'est pas ce que vous écririez en partant de zéro.**
Cela reproduit un environnement client, où la configuration doit être modifiable
sur l'hôte et consultable une fois le conteneur disparu. Les inconvénients sont
réels : les répertoires ne sont pas portables d'une machine à l'autre,
`docker compose down -v` ne les nettoie pas, et sous Linux leur propriétaire doit
correspondre à l'utilisateur `cassandra` de l'image (uid 999), sans quoi
Cassandra ne peut pas écrire. `setup.sh` s'occupe de la propriété et vous
prévient lorsqu'il n'y parvient pas.

### setup.sh

```bash
./setup.sh              # create anything missing, seed configuration from the image
./setup.sh --force      # re-seed the configuration directories, discarding edits
./setup.sh --help
```

Il initialise chaque répertoire `-conf` à partir de `/opt/cassandra/conf` **dans
l'image que vous vous apprêtez à exécuter**, de sorte que la configuration
corresponde toujours à cette version de Cassandra. Il lit `CASSANDRA_IMAGE`
depuis `.env` si vous y en définissez une.

Les répertoires existants sont laissés intacts. Lancez-le aussi souvent que vous
le souhaitez ; seul `--force` écrase, et uniquement la configuration.

**Ce qu'il fait réellement**, dans l'ordre :

1. **Analyse les arguments** — `-f`/`--force` et `-h`/`--help`. Tout autre
   argument est une erreur. `--help` affiche le commentaire d'en-tête du script
   lui-même.
2. **Vérifie Docker** — `docker` présent dans le `PATH` et démon joignable. Il
   s'arrête avant de toucher au système de fichiers si l'un des deux échoue.
3. **Résout l'image.** Il extrait `CASSANDRA_IMAGE=` de `./.env` par grep (la
   dernière occurrence l'emporte, les guillemets encadrants sont retirés) et
   retombe sur la valeur par défaut compilée dans le script,
   `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` — qui doit
   correspondre à celle de `docker-compose.yaml`. Il n'analyse pas le fichier
   Compose.
4. **Télécharge l'image si elle n'est pas présente localement**, pour que
   l'étape d'initialisation ci-dessous ne puisse pas échouer faute d'image.
5. **Pour chacun de `cassandra01`, `cassandra02`, `cassandra03` :**
   - Crée `docker/<node>/` (le répertoire de données) s'il n'existe pas, et le
     signale. Un répertoire existant n'est jamais touché — vos données sont en
     sécurité.
   - Initialise `docker/<node>-conf/` sauf s'il contient déjà un
     `cassandra.yaml` et que `--force` n'a pas été fourni. L'initialisation
     consiste en un `docker create` sur l'image (un conteneur jamais démarré),
     un `docker cp <container>:/opt/cassandra/conf/.` vers le répertoire, puis un
     `docker rm -f`. Le répertoire est d'abord supprimé puis recréé : `--force`
     **détruit donc toute modification locale qu'il contient**.
   - Tente un `chown -R 999:999` sur les deux répertoires — uid/gid de
     l'utilisateur `cassandra` dans l'image.
6. **Affiche la suite à faire** (`cp env.example .env`,
   `docker compose up -d`).

Le `chown` est au mieux-effort. Sur Docker Desktop (macOS, Windows) il échoue et
c'est attendu — la couche de partage de fichiers gère la propriété pour vous.
Sous Linux, un échec est réel, et le script avertit en indiquant la commande
exacte à exécuter : `sudo chown -R 999:999 docker/`. Tout le reste est fatal :
le script est en `set -euo pipefail`, donc un démon injoignable, une image
impossible à télécharger ou un `docker cp` en échec l'arrêtent avec une ligne
`error:` plutôt que de laisser derrière lui un répertoire à moitié initialisé.

Il n'écrit jamais `.env`, ne modifie jamais `docker-compose.yaml`, et ne démarre
jamais de conteneur.

### Modifier la configuration

Pour tout ce que les variables d'environnement ne couvrent pas, modifiez
directement sur l'hôte et redémarrez le nœud :

```bash
$EDITOR docker/cassandra01-conf/cassandra.yaml
docker compose restart cassandra01
```

Deux choses à savoir avant de le faire :

- **Les variables d'environnement l'emportent.** À chaque démarrage, le point
  d'entrée réécrit `cluster_name`, `authenticator`, `authorizer`,
  `listen_address`, `broadcast_rpc_address`, les seeds, `endpoint_snitch`,
  `num_tokens`, `native_transport_port`, ainsi que `dc`/`rack` dans
  `cassandra-rackdc.properties`, à partir des valeurs de
  `docker-compose.yaml`. Modifier ces clés sur l'hôte n'a aucun effet. Tout le
  reste de ce que vous modifiez est conservé.
- **`cassandra-env.sh` gagne une ligne.** Le point d'entrée y ajoute
  `. /usr/share/axonops/axonops-jvm.options` pour que l'agent Java AxonOps se
  charge. Il vérifie au préalable, un redémarrage ne l'ajoute donc pas deux
  fois.

### Garder tout cela hors de git

`docker/` est ignoré par git. Cassandra réécrit une partie de la configuration à
l'exécution, la committer produit donc un bruit permanent, et les répertoires de
données sont volumineux. Si vous voulez la configuration d'un client sous
gestion de version, committez délibérément les fichiers concernés avec
`git add -f`.

## Finir de sécuriser le cluster

Deux choses que Cassandra ne peut pas faire à votre place. Effectuez les deux
une fois les trois nœuds démarrés (`docker compose ps` les montre tous sains).

**1. La réplication de `system_auth`.** Elle est créée avec `SimpleStrategy` et
un facteur de réplication de 1, donc la perte d'un seul nœud emporte les
connexions avec elle. Passez à un réplica par rack :

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra -e \
  "ALTER KEYSPACE system_auth WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 3}"

docker exec cassandra01 nodetool repair -full system_auth
docker exec cassandra02 nodetool repair -full system_auth
docker exec cassandra03 nodetool repair -full system_auth
```

Utilisez votre propre valeur si vous avez changé `CASSANDRA_DC`.

**2. Le superutilisateur par défaut.** Cassandra crée `cassandra` / `cassandra`
au premier démarrage lorsque l'authentification est activée. C'est de notoriété
publique. Remplacez-le :

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra
```

```sql
CREATE ROLE admin WITH PASSWORD = 'a-password-you-choose'
  AND SUPERUSER = true AND LOGIN = true;
```

Reconnectez-vous en tant qu'`admin`, puis mettez le compte par défaut hors
service :

```sql
ALTER ROLE cassandra WITH PASSWORD = 'a-long-random-string-nobody-keeps'
  AND SUPERUSER = false;
```

L'agent AxonOps n'a besoin d'aucun de ces identifiants. Il collecte via l'agent
Java in-process et JMX, pas via CQL : l'authentification sur le cluster
n'affecte donc pas la supervision.

## JMX distant

`LOCAL_JMX=no` ouvre JMX au réseau, ce que faisait la stack d'origine pour que
Reaper puisse piloter les réparations. AxonOps n'en a pas besoin — l'agent
tourne dans le conteneur — c'est donc présent uniquement pour des outils
externes tels que `jmxterm`, `nodetool` depuis un autre hôte, ou un profileur
JVM.

`cassandra-env.sh` active l'authentification JMX dès que `LOCAL_JMX=no`, et cela
exige un fichier `jmxremote.password` que cette image ne fournit pas ;
`JVM_EXTRA_OPTS` définit donc
`-Dcom.sun.management.jmxremote.authenticate=false`. Cela fonctionne parce que
`JVM_EXTRA_OPTS` est ajouté en dernier et que, pour une propriété système
répétée, le dernier `-D` l'emporte.

Le résultat est un **port JMX non authentifié offrant le contrôle total du
nœud** — JMX permet de modifier le schéma, de vider (`drain`) et de
décommissionner. Les ports sont publiés sur `127.0.0.1` uniquement, rien à
l'extérieur de l'hôte ne peut donc les atteindre :

```yaml
ports:
  - "127.0.0.1:7199:7199"
```

Ne retirez pas le préfixe `127.0.0.1:`. Si vous avez réellement besoin de JMX
distant, mettez d'abord en place
[l'authentification JMX](https://cassandra.apache.org/doc/stable/cassandra/operating/security.html#jmx-access)
avec un fichier de mots de passe et TLS. Pour supprimer entièrement le JMX
distant, retirez `LOCAL_JMX=no`, les deux options `-D` et les lignes de port
JMX ; tout le reste de cet exemple continue de fonctionner.

## Configuration

Tout se règle dans `.env`. Liste complète avec les valeurs par défaut :
[`env.example`](env.example).

| Variable | Défaut | Description |
|----------|--------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Nom de l'organisation ; les agents utilisent la même valeur |
| `AXONOPS_LICENSE_KEY` | (vide) | Clé de licence ; vide, l'exécution se fait en mode d'évaluation |
| `AXONOPS_DB_PASSWORD` | `axonops` | Mot de passe d'`axondb-timeseries` |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Mot de passe administrateur d'`axondb-search` |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `2G` | Heap d'`axondb-timeseries` |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `2g` | Heap d'`axondb-search` |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS d'`axon-server` vers `axondb-search` |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS d'`axon-server` vers `axondb-timeseries` |
| `CASSANDRA_CLUSTER_NAME` | `secure-cluster` | Nom du cluster affiché dans AxonOps |
| `CASSANDRA_DC` | `dc1` | Nom du datacentre |
| `CASSANDRA_IMAGE` | `…/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Image des trois nœuds — 1.1.0 ou plus récent, voir [Avant de commencer](#avant-de-commencer) |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap par nœud du cluster |
| `CASSANDRA_MEM_LIMIT` | `2g` | Limite mémoire du conteneur par nœud |
| `CASSANDRA_CPUS` | `2.0` | Limite CPU par nœud |

Les noms de racks, les adresses et le sous-réseau sont fixés dans
`docker-compose.yaml` parce qu'ils dépendent les uns des autres ; voir
[Le cluster](#le-cluster).

`axon-server` se configure entièrement par variables d'environnement — il n'y a
aucun fichier de configuration à monter ou à générer. La correspondance complète
figure dans [l'exemple 01](../01-cassandra-cluster/README.fr.md#configuration).

## Exploitation

```bash
docker compose ps                          # health of every service
docker compose logs -f cassandra01         # follow one node
docker exec cassandra01 nodetool status    # cluster view, racks and ownership
docker compose down                        # stop, keep data
docker compose down -v                     # stop and delete all volumes
```

Connectez-vous en CQL depuis l'hôte — chaque nœud publie son propre port :

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra
cqlsh 127.0.0.1 9142 -u cassandra -p cassandra    # if you have cqlsh locally
```

`nodetool status` doit montrer trois nœuds `UN`, un par rack. S'il manque un
rack, c'est que ce nœud n'a pas lu `cassandra-rackdc.properties` comme prévu —
vérifiez `CASSANDRA_DC` et `CASSANDRA_RACK` dans son environnement.

### Santé des nœuds du cluster

Les trois nœuds utilisent le healthcheck fourni par l'image,
`/usr/local/bin/axonops-healthcheck.sh`, plutôt qu'un contrôle écrit ici. Il
vérifie que Cassandra sert bien CQL et que le processus `axon-agent` tourne — un
nœud dont l'agent est mort répond encore aux requêtes mais a discrètement cessé
d'être supervisé.

**Ce qu'il fait réellement.** Deux contrôles indépendants, une ligne de sortie
chacun, et un seul code de retour :

1. **Cassandra.** `nodetool statusbinary` doit afficher `running`, et le port
   CQL doit être en écoute (`ss -ln`). Le port est lu depuis le
   `native_transport_port` de `cassandra.yaml`, avec `9042` par défaut — il suit
   donc le port que vous avez défini au lieu d'en supposer un. L'échec de l'un
   ou l'autre donne un code de retour non nul, ce qui rend le conteneur non
   sain.
   (Dans les images K8ssandra, où l'API de gestion DataStax est présente, c'est
   son endpoint `/api/v0/probes/liveness` qui est utilisé à la place — la sonde
   même sur laquelle s'appuie l'opérateur K8ssandra. Ces trois nœuds utilisent
   l'image Cassandra simple, c'est donc le chemin `nodetool` qui s'exécute.)
2. **L'agent AxonOps.** Il parcourt `/proc/<pid>/cmdline` à la recherche de
   `/usr/share/axonops/axon-agent` (surchargeable via `AXON_AGENT_BIN`).
   `/proc` est lu directement plutôt qu'avec `pgrep`, dont la présence n'est pas
   garantie dans l'image de base UBI.

Un agent mort est signalé dans la sortie du contrôle mais ne rend pas à lui seul
le conteneur non sain, car faire échouer le contrôle peut amener un
orchestrateur à redémarrer ou vider un nœud qui sert encore. Mettez
`HEALTHCHECK_REQUIRE_AGENT=true` sur un nœud pour traiter ce cas comme un
échec — c'est la seule chose que la variable change ; l'agent est vérifié et
signalé dans les deux cas.

```bash
# Run it by hand — the output names which of the two checks failed
docker exec cassandra01 /usr/local/bin/axonops-healthcheck.sh

# What Docker last saw
docker inspect --format '{{.State.Health.Status}}' cassandra01
docker inspect --format '{{(index .State.Health.Log 0).Output}}' cassandra01
```

Compose l'exécute toutes les 15 s avec un délai d'expiration de 10 s, 20
réessais et une période de démarrage de 120 s. L'agent ne démarre qu'une fois
Cassandra opérationnel, il est donc normalement absent pendant une partie de
cette période de démarrage — c'est précisément à cela qu'elle sert. Sur un nœud
lent avec `HEALTHCHECK_REQUIRE_AGENT=true`, augmentez `start_period` plutôt que
de baisser `retries`.

Le contrôle de l'agent et `HEALTHCHECK_REQUIRE_AGENT` sont tous deux présents
dans l'image figée, `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`.
Sur toute image antérieure, le script ne vérifie que Cassandra et la variable
n'a aucun effet.

Les données et la configuration du cluster résident sous `./docker/` sur l'hôte
— voir [Stockage](#stockage). `docker compose down -v` supprime les volumes
AxonOps mais laisse ces répertoires ; supprimez-les à la main pour repartir d'un
cluster vide.

## Prérequis

- Docker Engine 20.10+ et Compose V2
- 12 Go de RAM libres aux valeurs par défaut, 16 Go recommandés ; 30 Go de
  disque, majoritairement sous `./docker/`
- Le sous-réseau `10.17.64.0/24` libre sur l'hôte
- Ports 3000, 1888, 9142, 9242, 9342 libres, et 7199, 7299, 7399 sur localhost

Sur une machine plus modeste, abaissez les heaps dans `.env` :

```bash
CASSANDRA_HEAP_SIZE=1G
CASSANDRA_MEM_LIMIT=2g
AXONOPS_CASSANDRA_HEAP_SIZE=2G
AXONOPS_OPENSEARCH_HEAP_SIZE=2g
```

## Ce qui a changé par rapport à la stack d'origine

| Origine | Ici | Pourquoi |
|---------|-----|----------|
| Prometheus, Grafana, 3× `cassandra_exporter`, Reaper | `axondb-timeseries`, `axondb-search`, `axon-server`, `axon-dash` | C'est tout l'objet du portage. Métriques, logs, alertes et planification des réparations dans une seule plateforme, et aucun sidecar exportateur JMX à configurer |
| `cassandra:5.0.8` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Le même Cassandra, avec l'agent AxonOps et l'agent Java déjà installés |
| Bind mounts sous `${PWD}/docker/` | Conservés | Reproduit l'environnement client. `setup.sh` les crée et les initialise — voir [Stockage](#stockage) |
| Volumes `conf` en bind mount | Conservés | Même raison. L'image peut être pilotée entièrement par variables d'environnement, mais ainsi la configuration reste modifiable sur l'hôte |
| `7000`, `7001` publiés par nœud | Non publiés | Ports internœuds ; rien hors du réseau Compose ne les utilise |
| `7199` JMX publié sur toutes les interfaces | Publié sur `127.0.0.1` uniquement | Le port n'est pas authentifié. Voir [JMX distant](#jmx-distant) |
| Healthcheck `cqlsh` avec identifiants en dur | L'`axonops-healthcheck.sh` propre à l'image | L'image embarque `cqlai` et `cqlsh`, et le contrôle n'a besoin d'aucun identifiant. Il vérifie aussi que l'`axon-agent` est vivant — voir [Santé des nœuds du cluster](#santé-des-nœuds-du-cluster) |
| Mots de passe dans le YAML | `.env`, ignoré par git | Rien de secret dans un fichier committé |
| `restart: always` | `restart: unless-stopped` | Aligné sur les autres exemples ; un conteneur que vous avez arrêté reste arrêté |
| `CASSANDRA_OPEN_JMX`, `JMXPORT` | Supprimés | Ni Cassandra ni l'image ne les lisent — ils ne faisaient rien dans l'original non plus |

Conservés tels quels : le sous-réseau et toutes les adresses, la disposition du
cluster et des racks, la liste des seeds, `GossipingPropertyFileSnitch`,
`PasswordAuthenticator`, `CassandraAuthorizer`, `LOCAL_JMX=no`, les options ZGC,
les ulimits `memlock` et `nofile`, l'organisation du stockage sous `./docker/`
pour les données et la configuration, et les numéros de port CQL publiés.

## Dépannage

**`authenticator: AllowAllAuthenticator` après le démarrage.**
`CASSANDRA_IMAGE` pointe vers une image antérieure au build 1.1.0, qui précède
la prise en charge de `CASSANDRA_AUTHENTICATOR` par le point d'entrée. Voir
[Avant de commencer](#avant-de-commencer).

**`Provided username cassandra and/or password are incorrect` juste après le
démarrage du cluster.** Le superutilisateur par défaut est créé quelques
secondes après la fin du démarrage du premier nœud, et non pendant le démarrage.
Attendez `Created default superuser role 'cassandra'` puis réessayez :

```bash
docker compose logs cassandra01 | grep "default superuser"
```

**`Expecting URI in variable: [cassandra.config]. Found[cassandra.yaml]`, avec
`sed: can't read /opt/cassandra/conf/cassandra.yaml` au-dessus.** Le nœud a un
répertoire de configuration vide. Soit `setup.sh` n'a jamais été lancé, soit le
bind mount ne pointe pas vers le répertoire que vous croyez. Vérifiez ce que le
conteneur voit réellement :

```bash
docker run --rm -v "$PWD/docker/cassandra01-conf:/x" busybox ls /x | wc -l
```

Zéro signifie que Docker a créé un répertoire vide au lieu de partager le vôtre
— sur Docker Desktop, un chemin hors de la liste de partage de fichiers
configurée produit exactement cela. Déplacez le projet sous un chemin partagé,
ou ajoutez le chemin dans Docker Desktop sous Settings → Resources → File
sharing.

**`Permission denied` à l'écriture dans le répertoire de configuration ou de
données (Linux).** Les répertoires doivent être accessibles en écriture par
l'uid 999, l'utilisateur `cassandra` de l'image :

```bash
sudo chown -R 999:999 docker/
```

`setup.sh` tente cette opération et avertit lorsqu'il n'y parvient pas. Docker
Desktop sur macOS et Windows gère la propriété pour vous, cela ne concerne donc
que les hôtes Linux.

**Un nœud ne devient jamais sain.** Les nœuds démarrent en séquence, un
démarrage à froid prend donc plusieurs minutes. Surveillez
`docker compose logs -f cassandra02`. S'il reste bloqué sur le gossip,
confirmez que les adresses des seeds correspondent aux entrées `ipv4_address`.

**`Cannot assign requested address` ou un conflit de sous-réseau au `up`.**
Autre chose sur l'hôte utilise `10.17.64.0/24` — souvent un autre réseau Docker.
Vérifiez avec `docker network ls` et `ip route`, puis supprimez le réseau en
conflit ou modifiez le sous-réseau et les sept adresses ensemble.

**`nodetool status` montre moins de trois nœuds.** Vérifiez que le nœud manquant
a bien démarré (`docker compose ps`), puis cherchez une divergence de nom de
cluster — un nœud ayant rejoint l'anneau avec un `CASSANDRA_CLUSTER_NAME`
différent lors d'une exécution antérieure le conserve dans son répertoire de
données. `docker compose down -v` n'efface **pas** cela ici, car les données
sont un bind mount de l'hôte : supprimez `docker/cassandra0*/` à la main.

**Le JMX depuis un autre hôte expire.** C'est attendu — les ports sont liés à
`127.0.0.1`. Voir [JMX distant](#jmx-distant).

**Cassandra journalise `Invalid or unsupported protocol version (22)` et
`axon-server` journalise `tls: first record does not look like a TLS
handshake`.** Un côté utilise TLS et l'autre non ; 22 vaut `0x16`, le premier
octet d'un ClientHello TLS lu comme une version de protocole CQL. Laissez
`AXONOPS_CASSANDRA_SSL=false` sauf si vous avez monté un keystore dans
`axondb-timeseries`.

**D'autres réglages qui semblent corrects mais sont ignorés.** Trois de ces
images acceptent des paramètres sous des noms différents de ceux que leurs
propres README suggèrent, et chacune échoue sans nommer la variable fautive.
L'exemple 01 documente les trois :
[des variables de configuration qui semblent correctes mais ne le sont pas](../01-cassandra-cluster/README.fr.md#des-variables-de-configuration-qui-semblent-correctes-mais-ne-le-sont-pas).

## Licence

AxonOps requiert une licence pour un usage en production —
<https://axonops.com>. La stack fonctionne sans clé de licence en mode
d'évaluation, ce qui suffit pour l'évaluer.

## Support

Maintenu par [AxonOps](https://axonops.com). Pour toute assistance,
contactez-nous sur [axonops.com/contact](https://axonops.com/contact).
