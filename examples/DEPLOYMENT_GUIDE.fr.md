# Guide de déploiement

[English](DEPLOYMENT_GUIDE.md) | **Français** | [Español](DEPLOYMENT_GUIDE.es.md) | [Galego](DEPLOYMENT_GUIDE.gl.md)

Ces exemples déploient sur Kubernetes AxonOps, ainsi que des clusters Kafka ou Cassandra supervisés par AxonOps. Chaque répertoire d'exemple est autonome : un fichier de configuration, les manifestes ou le script, et un README avec les étapes exactes.

## Exemples

| Répertoire | Déploie | Cible AxonOps |
| --- | --- | --- |
| [axonops/](axonops/) | AxonOps auto-hébergé : serveur, dashboard, bases Timeseries et Search | - |
| [strimzi/cloud/](strimzi/cloud/) | Strimzi Kafka sur des volumes provisionnés dynamiquement | AxonOps Cloud |
| [strimzi/on-premises/](strimzi/on-premises/) | Strimzi Kafka sur des volumes provisionnés dynamiquement | AxonOps auto-hébergé |
| [strimzi/local-disk/](strimzi/local-disk/) | Strimzi Kafka sur des volumes hostPath attachés à des nœuds | AxonOps auto-hébergé |
| [k8ssandra/](k8ssandra/) | Cassandra avec l'opérateur K8ssandra | AxonOps Cloud ou auto-hébergé |

Guides : [AxonOps](AXONOPS_DEPLOYMENT.fr.md), [Strimzi](STRIMZI_DEPLOYMENT.fr.md), [K8ssandra](K8SSANDRA_DEPLOYMENT.fr.md), [node selectors pour les disques locaux](NODE_SELECTOR_GUIDE.fr.md).

## Prérequis

- Kubernetes 1.27 ou plus récent, et un contexte `kubectl` avec les droits cluster-admin
- `helm` 3.8 ou plus récent
- `envsubst`, fourni par le paquet `gettext` : `brew install gettext` sur macOS, `apt-get install gettext-base` sur Debian et Ubuntu, `dnf install gettext` sur RHEL
- Une StorageClass par défaut, sauf pour `strimzi/local-disk/`

## Fonctionnement des exemples

Tous les exemples suivent le même schéma :

1. Placez-vous (`cd`) dans le répertoire de l'exemple et chargez (`source`) son fichier `.env`. Chaque fichier est une liste de lignes `export` ; modifiez-le, ou exportez vos valeurs avant de le charger. Les valeurs déjà définies sont conservées et celles qui en dérivent suivent.
2. Exportez les secrets dans le shell au lieu de les écrire dans le fichier : `AXON_SEARCH_PASSWORD` et `AXON_SERVER_CQL_PASSWORD` pour AxonOps, `AXON_AGENT_KEY` pour AxonOps Cloud.
3. Appliquez les manifestes avec `envsubst < file.yaml | kubectl apply -f -`, ou lancez le script de l'exemple.

Rien n'est lié à un namespace fixe. Chaque composant a une variable :

| Variable | Défaut | Utilisée par |
| --- | --- | --- |
| `AXONOPS_NAMESPACE` | `axonops` | `axonops/`, et les exemples Kafka et Cassandra pour trouver le serveur AxonOps |
| `KAFKA_NAMESPACE` | `kafka` | `strimzi/*` |
| `STRIMZI_OPERATOR_NAMESPACE` | `strimzi` | Opérateur Strimzi |
| `K8SSANDRA_NAMESPACE` | `k8ssandra-operator` | `k8ssandra/` |

Les agents joignent un serveur auto-hébergé sur `axon-server-agent.$AXONOPS_NAMESPACE.svc.cluster.local:1888`. Les exemples qui s'y connectent construisent cette adresse à partir de `axonops/axonops-config.env` : chargez donc ce fichier d'abord, dans le même shell.

## Scénarios

### AxonOps seul

```bash
cd examples/axonops
source axonops-config.env
export AXON_SEARCH_PASSWORD="$(openssl rand -base64 24)"
export AXON_SERVER_CQL_PASSWORD="$(openssl rand -base64 24)"
./axonops-setup.sh
```

### Kafka supervisé par AxonOps auto-hébergé

Installez AxonOps comme ci-dessus, installez l'[opérateur Strimzi](STRIMZI_DEPLOYMENT.fr.md#installer-lopérateur-strimzi), puis, depuis le même shell :

```bash
cd ../strimzi/on-premises
source ../../axonops/axonops-config.env
source strimzi-config.env
kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
```

Pour des volumes hostPath sur des nœuds choisis, utilisez plutôt [strimzi/local-disk/](strimzi/local-disk/) et son `strimzi-setup.sh`.

### Kafka supervisé par AxonOps Cloud

```bash
cd examples/strimzi/cloud
source strimzi-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key
kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
```

### Cassandra supervisé par AxonOps Cloud

Installez l'[opérateur K8ssandra](K8SSANDRA_DEPLOYMENT.fr.md#installer-lopérateur-k8ssandra), puis :

```bash
cd examples/k8ssandra
source k8ssandra-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key
envsubst < axonops-agent-secret.yaml | kubectl apply -f -
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

Pour un serveur auto-hébergé, voir l'[exemple K8ssandra](k8ssandra/README.md#examples).

## Générer pour revue ou GitOps

`envsubst` écrit sur la sortie standard : toute commande d'application devient donc une commande de génération :

```bash
envsubst < kafka-cluster.yaml > kafka-cluster.rendered.yaml
```

Les scripts acceptent `RENDER_ONLY=true` et écrivent dans un répertoire `generated/`, ignoré par git. Les fichiers générés peuvent contenir des mots de passe et des clés d'agent ; ne les commitez pas.

## Support

- [Documentation AxonOps](https://docs.axonops.com)
- [Documentation Strimzi](https://strimzi.io/docs/operators/latest/)
- [Documentation K8ssandra](https://docs.k8ssandra.io/)
