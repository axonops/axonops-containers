# Exemple 04 — AxonOps auto-hébergé avec les alertes définies comme du code

[English](README.md) | **Français** | [Español](README.es.md) | [Galego](README.gl.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

AxonOps auto-hébergé supervisant un nœud Apache Cassandra, avec des règles
d'alerte appliquées depuis un fichier plutôt que saisies dans le tableau de
bord. La stack reprend l'[exemple 01](../01-cassandra-cluster/README.fr.md)
réduit à un seul nœud supervisé, plus un conteneur supplémentaire qui exécute un
playbook Ansible contre l'API AxonOps puis s'arrête.

À utiliser lorsque vous voulez que votre alerting vive dans git : relisible,
reproductible et identique sur tous les clusters que vous exploitez.

## Démarrage rapide

```bash
cp env.example .env          # définissez AXONOPS_ORG_NAME
docker compose up -d
docker compose logs -f config
open http://localhost:3000
```

Le conteneur `config` démarre en dernier, applique
[`config.yaml`](config.yaml), puis s'arrête. Le voir en `Exited (0)` dans
`docker compose ps` est le résultat attendu — c'est une tâche ponctuelle, pas un
service. Dans le tableau de bord, les règles apparaissent sous
**Alerts → Rules** pour votre cluster.

Environ 6 Go de RAM aux valeurs par défaut. Cinq conteneurs de longue durée.

## Ce qui est exécuté

| Service | Image | Rôle |
|---|---|---|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries` | Cassandra, stockage des métriques d'AxonOps |
| `axondb-search` | `ghcr.io/axonops/axondb-search` | OpenSearch, stockage des logs et événements |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server` | Backend AxonOps, point d'entrée des agents sur 1888 |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash` | Tableau de bord sur 3000, sert aussi de proxy à l'API |
| `cassandra` | `ghcr.io/axonops/cassandra/cassandra` | Le nœud supervisé, Cassandra + agent |
| `config` | `ghcr.io/axonops/axonops-ansible-ee` | Ponctuel. Applique `config.yaml`, puis s'arrête |

L'image `config` est l'environnement d'exécution Ansible d'AxonOps. Elle
contient déjà Ansible et la collection
[`axonops.axonops`](https://galaxy.ansible.com/ui/repo/published/axonops/axonops/),
donc rien n'est installé à l'exécution et le conteneur n'a besoin d'aucun volume
en dehors du playbook lui-même.

## Modifier les alertes

Modifiez [`config.yaml`](config.yaml), puis réappliquez :

```bash
docker compose run --rm config
```

Le playbook est idempotent — l'exécuter deux fois ne change rien la seconde fois
— il peut donc être lancé à chaque déploiement sans risque. Pour n'appliquer
qu'une partie, surchargez la commande et utilisez les tags du rôle :

```bash
docker compose run --rm config \
  ansible-playbook -i localhost, --connection=local -v /config.yaml --tags metrics
```

Tags : `metrics`, `log_alerts`, `service_checks`, `routes`, `slack`, `teams`,
`pagerduty`, `backups`, `adaptive_repair`, `dashboards`.

## Règles d'alerte sur les métriques

Une alerte de métrique surveille un graphique d'un tableau de bord — les mêmes
noms que ceux affichés dans l'interface AxonOps — et se déclenche lorsque la
valeur franchit un seuil pendant plus longtemps que `duration` :

```yaml
axonops_alert_rules:
  - name: CPU usage per host
    dashboard: System
    chart: CPU usage per host
    operator: '>='
    warning_value: 90
    critical_value: 99
    duration: 1h
    description: Sustained high CPU on a Cassandra host
```

| Champ | Requis | Notes |
|---|---|---|
| `name` | oui | Affiché dans l'interface et utilisé pour retrouver la règle lors d'une réapplication |
| `dashboard` | oui | Nom du tableau de bord, exactement tel que l'interface l'écrit |
| `chart` | oui | Nom du graphique sur ce tableau de bord, exactement tel que l'interface l'écrit |
| `operator` | oui | `>=`, `<=`, `>`, `<`, `==`, `!=`. Mettez-le entre guillemets, sinon YAML l'interprète comme un tag |
| `warning_value` | oui | Seuil d'avertissement |
| `critical_value` | oui | Seuil critique |
| `duration` | oui | Durée pendant laquelle la condition doit tenir : `5m`, `15m`, `1h` |
| `description` | non | Dites ce que cela signifie pour l'exploitant, pas ce qu'est la métrique |
| `present` | non | `false` supprime la règle. Par défaut `true` |
| `scope`, `dc`, `rack`, `host_id`, `keyspace` | non | Restreint la règle à une partie du cluster |
| `group_by`, `percentile`, `consistency` | non | Correspond à l'agrégation du graphique |
| `routing` | non | Envoie cette règle ailleurs que vers la route par défaut |

`dashboard` et `chart` doivent correspondre à l'interface caractère pour
caractère. Une faute de frappe ne produit pas d'erreur — la règle est créée et
n'est simplement jamais évaluée.

## Au-delà des alertes de métriques

`config.yaml` livre le reste en commentaire. Décommentez ce dont vous avez
besoin :

- **`axonops_log_alert_rule`** — alerte sur le volume de lignes de log
  correspondantes remontées par l'agent (`content`, `level`, `type`, `source`).
- **`axonops_tcp_check`** / **`axonops_shell_check`** — contrôles de service
  exécutés sur le nœud supervisé via son agent, avec alerte en cas d'échec.
- **`axonops_slack_integrations`** — une cible de notification. Le webhook est un
  secret : placez-le dans `.env` sous `SLACK_WEBHOOK_URL`, que le service
  `config` transmet au playbook. Ne l'écrivez jamais en clair dans le fichier.
- **`axonops_alert_routes`** — envoie une sévérité vers une intégration.

Le même rôle gère aussi les sauvegardes, la réparation adaptative, l'archivage
des commitlogs, les tableaux de bord ainsi que les intégrations PagerDuty et
Teams. Voir la
[documentation de la collection](https://github.com/axonops/axonops-ansible-collection).

## Configuration

Tout se définit dans `.env` ; aucun fichier de ce répertoire n'a besoin d'être
modifié pour démarrer. Voir [`env.example`](env.example) pour la liste complète
avec les valeurs par défaut.

| Variable | Défaut | Notes |
|---|---|---|
| `AXONOPS_ORG_NAME` | `example` | Organisation. L'agent, axon-server et le conteneur config doivent être d'accord |
| `CASSANDRA_CLUSTER_NAME` | `demo-cluster` | Cluster auquel les règles d'alerte sont rattachées |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Image du nœud supervisé |
| `CASSANDRA_HEAP_SIZE` | `1G` | Valeur de développement |
| `AXONOPS_DB_PASSWORD` | `axonops` | Changez-le. La valeur par défaut est publique |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Changez-le. L'image impose une politique de mot de passe |
| `AXONOPS_LICENSE_KEY` | vide | Optionnel ; mode d'essai sans elle |
| `SLACK_WEBHOOK_URL` | vide | Nécessaire uniquement pour le bloc Slack de `config.yaml` |

## Dépannage

**`config` se termine avec un code non nul et « cluster not found ».** Une règle
d'alerte est rattachée à un cluster, et le cluster n'existe dans AxonOps qu'une
fois son agent enregistré. Le service attend le healthcheck de `cassandra`, ce
qui suffit normalement ; si le nœud a mis du temps à s'enregistrer, relancez
simplement `docker compose run --rm config`.

**Les tâches sont marquées `censored`.** Les modules masquent leur sortie par
défaut, car les mêmes champs peuvent contenir des identifiants — ce qui masque
aussi les erreurs de l'API. `enable_logging: true` dans `config.yaml` la
réactive. Laissez-la activée jusqu'à ce que la configuration s'applique
proprement.

**La règle est créée mais ne se déclenche jamais.** Vérifiez `dashboard` et
`chart` par rapport à l'interface. Un nom qui ne correspond à rien est accepté
silencieusement.

**Rien n'apparaît du tout dans le tableau de bord.** Vérifiez que l'agent s'est
enregistré dans l'organisation que vous consultez : `AXON_AGENT_ORG` sur le
service `cassandra` et `AXONSERVER_ORGNAME` sur `axon-server` proviennent tous
deux de `AXONOPS_ORG_NAME`, ils ne divergent donc que si vous l'avez changé
après le premier démarrage. Changez-le avant le premier démarrage, pas après.

**Utiliser AxonOps Cloud au lieu de cette stack.** Retirez `AXONOPS_URL` de
`config.yaml` et définissez `AXONOPS_TOKEN` avec un jeton d'API issu de la
console. La configuration des alertes elle-même ne change pas.

## Voir aussi

- [00-axonops-platform](../00-axonops-platform/README.fr.md) — AxonOps seul, pour des clusters que vous exploitez déjà
- [01-cassandra-cluster](../01-cassandra-cluster/README.fr.md) — la même stack avec trois nœuds supervisés
- [03-secure-3-rack-cluster](../03-secure-3-rack-cluster/README.fr.md) — un cluster sécurisé, proche de la production
- [VERSIONS.md](../../VERSIONS.md) — empreinte actuelle de chaque image

## Support

Maintenu par [AxonOps](https://axonops.com). Pour toute assistance, contactez-nous
à [axonops.com/contact](https://axonops.com/contact).
