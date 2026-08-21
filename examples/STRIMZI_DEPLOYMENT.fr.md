# Guide de déploiement Strimzi Kafka

[English](STRIMZI_DEPLOYMENT.md) | **Français** | [Español](STRIMZI_DEPLOYMENT.es.md) | [Galego](STRIMZI_DEPLOYMENT.gl.md)

Ce guide traite du déploiement d'Apache Kafka avec l'opérateur Strimzi sur Kubernetes, avec l'intégration de la supervision AxonOps en option.

## Démarrage rapide

### Étape 1 : installer l'opérateur Strimzi

Avant de déployer des clusters Kafka, installez l'opérateur Strimzi avec Helm.

**Important :** consultez la [page de téléchargement de Strimzi](https://strimzi.io/downloads/) pour vérifier quelle version de Strimzi prend en charge la version de Kafka visée. La matrice de support indique les versions de Kafka compatibles avec chaque release de Strimzi.

```bash
# Add Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Create namespaces
kubectl create namespace strimzi
kubectl create namespace kafka

# Check available versions
helm search repo strimzi --versions

# Install the operator (specify version based on support matrix)
# Example: Strimzi 0.50.0 supports Kafka 4.1.1
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  -n strimzi \
  --version 0.50.0 \
  --set watchNamespaces="{kafka}" \
  --wait

# Verify installation
kubectl get pods -n strimzi
kubectl get crd | grep strimzi
```

### Étape 2 : déployer le cluster Kafka

Choisissez l'un des exemples de déploiement selon votre cas d'usage. Chaque exemple possède son propre README, avec des instructions de déploiement détaillées :

| Répertoire | Cas d'usage | Description |
| --- | --- | --- |
| [strimzi/cloud/](strimzi/cloud/) | Production | 6 brokers, 3 controllers, stockage cloud |
| [strimzi/local-disk/](strimzi/local-disk/) | On-premises | Volumes persistants locaux, configurables |
| [strimzi/single/](strimzi/single/) | Développement | Un seul nœud à double rôle |

Chaque répertoire d'exemple contient :

- `README.md` — les instructions de déploiement complètes
- `strimzi-config.env` — les variables de configuration
- les manifestes YAML de tous les composants du cluster Kafka

### Étape 3 : ajouter la supervision AxonOps (optionnel)

Voir [AXONOPS_DEPLOYMENT.fr.md](AXONOPS_DEPLOYMENT.fr.md) pour déployer la supervision AxonOps. Les manifestes d'exemple Strimzi contiennent déjà les variables de configuration de l'agent AxonOps.

---

## Compatibilité des versions de Strimzi

Consultez toujours la [matrice de support Strimzi](https://strimzi.io/downloads/) avant l'installation, pour vous assurer de la compatibilité :

| Version Strimzi | Versions de Kafka prises en charge | Versions de Kubernetes |
| --- | --- | --- |
| 0.45.0 | 3.8.x, 3.9.x | 1.25+ |
| 0.44.0 | 3.7.x, 3.8.x | 1.25+ |
| 0.43.0 | 3.7.x, 3.8.x | 1.23+ |

*Note : ce tableau n'est donné qu'à titre indicatif. Vérifiez toujours la compatibilité courante sur [strimzi.io/downloads](https://strimzi.io/downloads/).*

## Ressources complémentaires

- **Documentation Strimzi** : [https://strimzi.io/docs/](https://strimzi.io/docs/)
- **Strimzi sur GitHub** : [https://github.com/strimzi/strimzi-kafka-operator](https://github.com/strimzi/strimzi-kafka-operator)
- **Guide des node selectors** : [NODE_SELECTOR_GUIDE.fr.md](NODE_SELECTOR_GUIDE.fr.md)

---

**Dernière mise à jour :** 2026-02-13
