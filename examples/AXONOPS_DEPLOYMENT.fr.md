# Guide de déploiement AxonOps

[English](AXONOPS_DEPLOYMENT.md) | **Français** | [Español](AXONOPS_DEPLOYMENT.es.md) | [Galego](AXONOPS_DEPLOYMENT.gl.md)

Ce guide installe une stack AxonOps auto-hébergée sur Kubernetes avec le script de [axonops/](axonops/). Le fichier [axonops/README.md](axonops/README.md) liste tous les réglages.

## Composants

| Composant | Rôle |
| --- | --- |
| axondb-timeseries | Stockage des métriques (Cassandra) |
| axondb-search | Logs et événements (OpenSearch) |
| axon-server | Reçoit les données des agents et sert l'API |
| axon-dash | Interface web, avec le sidecar `axon-reporting` pour Reports v2 |

Les quatre sont installés dans un seul namespace, `AXONOPS_NAMESPACE` (`axonops` par défaut), à partir des charts de `oci://ghcr.io/axonops/charts`. TLS sur les bases de données est désactivé par défaut, tout comme cert-manager.

## Démarrage rapide

```bash
cd examples/axonops
source axonops-config.env
export AXON_SEARCH_PASSWORD="$(openssl rand -base64 24)"
export AXON_SERVER_CQL_PASSWORD="$(openssl rand -base64 24)"
./axonops-setup.sh
```

Le script écrit les values Helm et le Secret de configuration d'axon-server dans `axonops/generated/`, installe chaque release avec `helm upgrade --install --wait`, puis indique comment accéder au dashboard. Le relancer met à jour les releases en place. Gardez les mêmes mots de passe à chaque exécution.

## Stockage

| Mode | Réglages | Usage |
| --- | --- | --- |
| PVC (par défaut) | `AXON_TIMESERIES_STORAGE_CLASS`, `AXON_SEARCH_STORAGE_CLASS`, `AXON_*_VOLUME_SIZE` | Tout cluster avec une StorageClass |
| hostPath | `AXON_TIMESERIES_USE_HOSTPATH=true`, `AXON_SEARCH_USE_HOSTPATH=true` | Clusters de test à un seul nœud |
| Aucun | `AXON_*_PERSISTENCE_ENABLED=false` | Tests jetables ; les données disparaissent avec le pod |

Pour hostPath, créez les répertoires sur le nœud avant de lancer le script :

```bash
sudo mkdir -p /data/axon-timeseries /data/axon-search
sudo chown -R 999:999 /data/axon-timeseries /data/axon-search
```

## Accès au dashboard

| Méthode | Réglages | Adresse |
| --- | --- | --- |
| Port-forward (par défaut) | aucun | `kubectl port-forward -n "$AXONOPS_NAMESPACE" svc/axon-dash-svc 3000:3000`, puis <http://localhost:3000> |
| NodePort | `AXON_DASH_NODEPORT_ENABLED=true` | `http://<node-ip>:<port>` ; le script affiche le port |
| Ingress | `AXON_DASH_INGRESS_ENABLED=true`, `AXON_DASH_INGRESS_HOST`, `AXON_DASH_INGRESS_CLASS_NAME` | `https://<host>` |

## Connecter Kafka et Cassandra

Les agents du même cluster se connectent à :

```text
axon-server-agent.<AXONOPS_NAMESPACE>.svc.cluster.local:1888   (TLS disabled)
```

Les exemples [Strimzi on-premises](strimzi/on-premises/), [Strimzi local-disk](strimzi/local-disk/) et [K8ssandra](k8ssandra/README.md#examples) lisent `AXONOPS_NAMESPACE`, `AXON_SERVER_ORG_NAME` et `AXON_SERVER_AGENTS_PORT` dans `axonops/axonops-config.env`. Chargez ce fichier avant leur propre fichier de configuration :

```bash
source examples/axonops/axonops-config.env
source examples/strimzi/on-premises/strimzi-config.env
```

Pour des agents hors du cluster, activez l'Ingress gRPC avec `AXON_SERVER_AGENT_INGRESS_ENABLED=true` et `AXON_SERVER_AGENT_INGRESS_HOST`, puis pointez les agents vers cet hôte sur le port 443 avec `AXON_AGENT_TLS_MODE=TLS`.

## Vérifier

```bash
helm list -n "$AXONOPS_NAMESPACE"
kubectl get pods,pvc -n "$AXONOPS_NAMESPACE"
kubectl logs -n "$AXONOPS_NAMESPACE" deploy/axon-server --tail=50
```

## Supprimer

```bash
for r in axon-dash axon-server axondb-search axondb-timeseries; do
  helm uninstall "$r" -n "$AXONOPS_NAMESPACE"
done
kubectl delete secret axon-server-config -n "$AXONOPS_NAMESPACE"
kubectl delete pvc --all -n "$AXONOPS_NAMESPACE"   # deletes all AxonOps data
kubectl delete namespace "$AXONOPS_NAMESPACE"
```

## Notes de production

- Utilisez une StorageClass avec sauvegardes et dimensionnez les volumes selon votre rétention.
- Définissez une clé de licence avec `AXON_SERVER_LICENSE_KEY`.
- Pour activer TLS entre axon-server et les bases de données, définissez `AXON_TIMESERIES_TLS_ENABLED=true` et `AXON_SEARCH_TLS_ENABLED=true`. Les certificats viennent de cert-manager (`CERT_MANAGER_INSTALL=true` l'installe) ou de vos propres Secrets ; voir [axonops/README.md](axonops/README.md#tls).
- Stockez les mots de passe générés dans un gestionnaire de secrets ; `axonops/generated/` les contient en clair.
- Le [méta-chart AxonOps](../axonops/charts/axonops/README.fr.md) installe la même stack en une seule release Helm, ce qui convient mieux aux outils GitOps qu'un script.

## Voir aussi

- [axonops/README.md](axonops/README.md) : tous les réglages du script
- [Guide de déploiement](DEPLOYMENT_GUIDE.fr.md)
- [Documentation AxonOps](https://docs.axonops.com)
