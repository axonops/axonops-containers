# Exemples Docker Compose

[English](README.md) | **Français**

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Stacks Docker Compose exécutables, construites à partir des images de conteneurs
publiées par ce dépôt. Chaque répertoire est autonome : copiez-le, modifiez
`.env`, lancez `docker compose up -d`.

## Avant de lancer quoi que ce soit

Les valeurs par défaut de `env.example` sont des valeurs de développement.
Définissez celles-ci dans votre `.env` avant de démarrer une stack qui compte
pour vous :

| Variable | Pourquoi |
|---|---|
| `AXONOPS_ORG_NAME` | Vaut `example` par défaut (`my-organization` dans l'exemple 02). Elle nomme votre organisation dans tout AxonOps et est figée dans l'enregistrement des agents — changez-la avant le premier démarrage, pas après. |
| `AXONOPS_DB_PASSWORD` | Mot de passe de la base de données de séries temporelles (`axondb-timeseries`). La valeur par défaut `axonops` est publique. Utilisez une valeur forte et unique. |
| `AXONOPS_SEARCH_PASSWORD` | Mot de passe de la base de recherche (`axondb-search`). Même raisonnement. L'image de recherche applique en plus sa propre politique de mot de passe — une valeur faible fait refuser le démarrage du conteneur. |
| `AXONOPS_LICENSE_KEY` | Facultatif. Sans elle, AxonOps ne propose que les fonctionnalités de l'édition gratuite. Voir [les éditions AxonOps](https://axonops.com/docs/editions/) pour le contenu de chaque édition. |

L'exemple 02 (SaaS) fait exception : AxonOps s'exécute dans AxonOps Cloud, donc
seuls `AXONOPS_ORG_NAME` et votre clé d'agent s'appliquent — il n'y a aucune
base de données locale à protéger par mot de passe.

Les mots de passe vivent dans `.env`, qui est ignoré par git. N'en committez
jamais un.

## Lequel me faut-il ?

| | [00-axonops-platform](00-axonops-platform/README.fr.md) | [01-cassandra-cluster](01-cassandra-cluster/README.fr.md) | [02-saas-cassandra-cluster](02-saas-cassandra-cluster/README.fr.md) | [03-secure-3-rack-cluster](03-secure-3-rack-cluster/README.fr.md) |
|---|---|---|---|---|
| **À utiliser pour** | exécuter AxonOps pour des clusters que vous avez déjà | voir l'ensemble fonctionner de bout en bout | superviser un cluster sans exécuter AxonOps | modéliser un cluster sécurisé, proche de la production |
| AxonOps | auto-hébergé | auto-hébergé | SaaS | auto-hébergé |
| Cassandra | aucun — apportez le vôtre | 3 nœuds, supervisés | 3 nœuds, supervisés | 3 nœuds, 3 racks, supervisés |
| Authentification du cluster | — | désactivée | désactivée | `PasswordAuthenticator` |
| Conteneurs | 4 | 7 | 3 | 7 |
| RAM aux valeurs par défaut | ~10 Go | ~10 Go | ~5 Go | ~12 Go |
| Tableau de bord | `localhost:3000` | `localhost:3000` | console AxonOps | `localhost:3000` |
| Prérequis | rien | rien | une organisation SaaS et une clé d'agent | rien |

Commencez par **01** si vous évaluez AxonOps et voulez voir un vrai cluster
apparaître dans un tableau de bord. Commencez par **00** si vous exploitez déjà
Cassandra ou Kafka et cherchez un endroit où ses agents peuvent remonter leurs
données. Commencez par **02** si vous avez un compte AxonOps Cloud. Commencez
par **03** si vous voulez un cluster qui ressemble à un déploiement réel —
authentification, un rack par nœud, adressage fixe et JMX distant — ou si vous
portez la très répandue
[stack Compose Prometheus / Grafana / Reaper](https://github.com/crystalloide/cassandra-reaper)
dont il est issu.

## Conventions

Chaque exemple suit la même structure :

```
<example>/
  docker-compose.yaml   Services, figés sur des tags de version immuables
  env.example           Toutes les variables, avec leurs valeurs par défaut, commentées
  README.md             Démarrage rapide, référence de configuration, dépannage
```

- **La configuration passe uniquement par `.env`** : aucun `docker-compose.yaml`
  n'a besoin d'être modifié pour démarrer. L'exemple 03 est la seule exception :
  il reproduit un environnement client qui monte le répertoire de configuration
  de Cassandra depuis l'hôte, il fournit donc aussi un `setup.sh` qui le crée et
  l'initialise.
- **Les images** proviennent de `ghcr.io/axonops/*` ou de
  `registry.axonops.com/axonops-public/*`, figées sur un tag de version avec le
  digest SHA256 en commentaire au-dessus. Déployez le digest en production —
  voir
  [Figer une image : tags ou sommes de contrôle](00-axonops-platform/README.fr.md#figer-une-image--tags-ou-sommes-de-contrôle)
  et [VERSIONS.md](../VERSIONS.md).
- **Le dimensionnement** utilise des valeurs de développement. Chaque README
  indique ce qu'il faut abaisser.
- **TLS** protège tout ce qui quitte un hôte. Le trafic des agents à l'intérieur
  d'un même réseau Compose est en clair par conception ; l'exemple SaaS utilise
  TLS de bout en bout.
- **Les secrets** vivent dans `.env`, qui est ignoré par git. N'en committez
  jamais un.

## Prérequis

- Docker Engine 20.10+ et Docker Compose V2
- Les besoins en RAM, disque et ports propres à chaque exemple figurent dans son
  README

## FAQ

### Comment mettre à jour `axon-server`, `axon-dash` et l'agent ?

Chaque image de ces fichiers est figée sur un tag de version exact, donc
`docker compose pull` seul ne vous apporte rien de neuf — une mise à niveau
implique de modifier le tag (ou le digest, si vous déployez la forme digest) et
de recréer ce service précis. Les tags et digests actuels de chaque image :
[VERSIONS.md](../VERSIONS.md).

**Ordre.** Les magasins de données d'abord s'ils ont changé, puis
`axon-server`, puis `axon-dash`, puis les agents. Gardez `axon-server` et
`axon-dash` sur des versions du même lot — le dash appelle l'API du serveur, pas
l'inverse, donc un dash plus récent face à un serveur plus ancien est la
combinaison à éviter.

**`axon-server` et `axon-dash`.** Les deux sont figés directement dans
`docker-compose.yaml`, avec le digest en commentaire au-dessus du tag :

```yaml
  axon-server:
    # Preferred (immutable): registry.axonops.com/…/axon-server@sha256:c75f6672…
    image: registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35
```

Changez le tag et le commentaire de digest ensemble — un commentaire périmé à
côté d'un nouveau tag est la façon dont quelqu'un déploie plus tard la mauvaise
image — puis recréez ce seul service :

```bash
docker compose pull axon-server
docker compose up -d axon-server        # recreates only this container
docker compose logs -f axon-server      # watch it come up
docker compose ps                       # healthy?
```

Ensuite les deux mêmes commandes pour `axon-dash`. L'exemple 02 n'a ni l'un ni
l'autre — AxonOps Cloud les exécute et les met à niveau pour vous, l'agent y est
donc la seule chose à mettre à jour. Les deux sont sans état : tout réside dans
`axondb-timeseries` et `axondb-search`, auxquels vous ne touchez pas, une
recréation ne perd donc aucune donnée. Les agents se reconnectent d'eux-mêmes
dès que le serveur est de retour.

**L'agent.** Il est embarqué dans l'image Cassandra plutôt que dans son propre
conteneur, et c'est le composant central du tag —
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` correspond à Cassandra
5.0.8 avec l'agent 2.0.31 issu du build 1.1.0. Mettre à niveau l'agent revient
donc à passer à un nouveau tag d'image, ce qui, dans les exemples 01, 02 et 03,
se fait via `CASSANDRA_IMAGE` dans `.env` :

```bash
CASSANDRA_IMAGE=ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0
```

Recréez les nœuds **un à la fois**, en attendant que chacun revienne en bonne
santé avant de démarrer le suivant, et videz-le d'abord (`drain`) pour que le
nœud cesse d'accepter des écritures qu'il perdrait :

```bash
docker compose pull
docker compose exec cassandra-1 nodetool drain
docker compose up -d --no-deps cassandra-1
docker compose ps                            # wait for healthy, then the next node
docker compose exec cassandra-1 nodetool status
```

Les nœuds sont `cassandra-0`, `cassandra-1` et `cassandra-2` dans les exemples
01 et 02, et `cassandra01`, `cassandra02` et `cassandra03` dans l'exemple 03.

Les données survivent — elles sont sur un volume nommé (l'exemple 03 utilise des
répertoires de l'hôte sous `./docker/`), et ni l'un ni l'autre n'est supprimé
par la recréation d'un conteneur. Dans l'exemple 00, il n'y a aucun conteneur
Cassandra à mettre à niveau : les agents tournent sur vos propres hôtes, et
c'est là que vous les mettez à niveau.

**Changer la version de Cassandra n'est pas la même chose.** Seul le premier
composant du tag correspond à Cassandra lui-même, et le déplacer constitue une
véritable mise à niveau de base de données — snapshot, `nodetool
upgradesstables` ensuite, notes de version amont — et non un simple échange
d'image. Pour récupérer un nouvel agent ou un nouveau build, laissez la version
de Cassandra où elle est et ne changez que le deuxième ou le troisième
composant.

**Revenir en arrière** est la même opération avec l'ancien tag : remettez-le,
puis relancez `docker compose up -d <service>`.

## Quand quelque chose ne démarre pas

Chaque README contient une section de dépannage propre à sa stack. Une catégorie
de problème mérite d'être connue d'avance : plusieurs de ces images acceptent des
paramètres sous des noms différents de ceux que leur propre documentation
suggère, et un nom erroné est ignoré silencieusement plutôt que rejeté. Les trois
cas trouvés à ce jour — dans `axondb-search`, `axondb-timeseries` et `axon-dash`
— sont décrits dans
[des variables de configuration qui semblent correctes mais ne le sont pas](01-cassandra-cluster/README.fr.md#des-variables-de-configuration-qui-semblent-correctes-mais-ne-le-sont-pas),
avec l'erreur que chacun produit.

## Support

Maintenu par [AxonOps](https://axonops.com). Pour toute assistance,
contactez-nous sur [axonops.com/contact](https://axonops.com/contact).
