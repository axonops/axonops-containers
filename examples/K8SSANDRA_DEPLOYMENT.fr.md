# Guide de déploiement K8ssandra

[English](K8SSANDRA_DEPLOYMENT.md) | **Français** | [Español](K8SSANDRA_DEPLOYMENT.es.md) | [Galego](K8SSANDRA_DEPLOYMENT.gl.md)

Ce guide déploie Apache Cassandra avec l'opérateur K8ssandra et l'image Cassandra AxonOps, qui exécute l'agent AxonOps à côté de Cassandra. Les manifestes et tous les réglages se trouvent dans [k8ssandra/](k8ssandra/README.md).

## Installer l'opérateur K8ssandra

L'opérateur a besoin de cert-manager. Installez les deux une fois par cluster Kubernetes :

```bash
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true --wait

export K8SSANDRA_OPERATOR_NAMESPACE=k8ssandra-operator
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update
helm upgrade --install k8ssandra-operator k8ssandra/k8ssandra-operator \
  --version 1.29.0 \
  --namespace "$K8SSANDRA_OPERATOR_NAMESPACE" --create-namespace \
  --wait
```

Installé ainsi, l'opérateur ne gère que les clusters de son propre namespace, ce qui correspond au défaut de l'exemple. Pour déployer des clusters dans d'autres namespaces, ajoutez `--set global.clusterScoped=true`.

## Déployer un cluster

```bash
cd examples/k8ssandra
source k8ssandra-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key

envsubst < axonops-agent-secret.yaml | kubectl apply -f -
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
kubectl wait k8ssandracluster/"$K8SSANDRA_CLUSTER_NAME" -n "$K8SSANDRA_NAMESPACE" \
  --for=condition=CassandraInitialized --timeout=20m
```

Appliquez d'abord le Secret : le conteneur Cassandra y lit les réglages de l'agent.

## Cible AxonOps

| Cible | Réglages |
| --- | --- |
| AxonOps Cloud (par défaut) | `AXON_AGENT_ORG`, `AXON_AGENT_KEY` ; serveur `agents.axonops.cloud:443`, TLS |
| AxonOps auto-hébergé | `AXON_AGENT_SERVER_HOST=axon-server-agent.$AXONOPS_NAMESPACE.svc.cluster.local`, `AXON_AGENT_SERVER_PORT=1888`, `AXON_AGENT_TLS_MODE=disabled` |

Pour un serveur auto-hébergé installé depuis [axonops/](axonops/), chargez d'abord `axonops/axonops-config.env` et suivez l'[exemple auto-hébergé](k8ssandra/README.md#examples).

## Versions d'image

`IMAGE_NAME` doit correspondre à `CASSANDRA_VERSION`. La valeur par défaut est le tag flottant `<cassandra>`, par exemple `5.0.9`, qui pointe toujours vers le dernier build AxonOps pour cette version de Cassandra. Cela convient à une démo ; en production, épinglez l'image par digest SHA256 (`ghcr.io/axonops/k8ssandra/cassandra@sha256:<digest>`) afin que tous les nœuds exécutent le même build. Les tags immuables se lisent `<cassandra>-v<k8ssandra api>-<image>`, par exemple `5.0.9-v0.1.125-1.6.3`. Les tags publiés sont listés dans [VERSIONS.md](../VERSIONS.md) et dans le [README de l'image K8ssandra](../k8ssandra/README.fr.md).

## Mise à l'échelle

Modifiez `CASSANDRA_DC_SIZE` et appliquez de nouveau le manifeste :

```bash
export CASSANDRA_DC_SIZE=5
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

Lors d'une réduction, l'opérateur décommissionne les nœuds retirés un par un. Vérifiez d'abord que les nœuds restants ont la place pour leurs données.

## Dépannage

| Symptôme | Vérification |
| --- | --- |
| Pod `CreateContainerConfigError` | Le Secret de l'agent est absent : `kubectl get secret "$K8SSANDRA_CLUSTER_NAME-axonops-agent" -n "$K8SSANDRA_NAMESPACE"` |
| Pods `Pending` | `kubectl get pvc -n "$K8SSANDRA_NAMESPACE"` ; définissez `STORAGE_CLASS` s'il n'y a pas de StorageClass par défaut |
| Rien n'est créé après l'apply | Le namespace du cluster diffère de celui de l'opérateur, et l'opérateur n'est pas cluster-scoped |
| Cluster absent dans AxonOps | `kubectl logs <pod> -c cassandra \| grep -i axon` pour les erreurs de connexion ; vérifiez l'hôte, le port, le mode TLS et la clé |

## Notes de production

- Donnez à chaque nœud au moins 4 CPU et 8 GiB de mémoire, et augmentez `HEAP_SIZE` en conséquence.
- Utilisez des StorageClasses rapides sur SSD.
- Utilisez un facteur de réplication de 3 pour les keyspaces applicatifs.
- Configurez les sauvegardes, par exemple avec K8ssandra Medusa.

## Voir aussi

- [k8ssandra/README.md](k8ssandra/README.md) : fichiers et tous les réglages
- [Image K8ssandra AxonOps](../k8ssandra/README.fr.md)
- [Documentation K8ssandra](https://docs.k8ssandra.io/)
