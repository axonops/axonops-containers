# Guide de configuration des node selectors Strimzi

[English](NODE_SELECTOR_GUIDE.md) | **Français** | [Español](NODE_SELECTOR_GUIDE.es.md) | [Galego](NODE_SELECTOR_GUIDE.gl.md)

## Vue d'ensemble

Ce guide explique comment utiliser le script de déploiement Strimzi pour épingler les brokers et les controllers Kafka sur des nœuds Kubernetes précis. C'est indispensable lorsque vous devez :

- garantir la localité des données pour la performance
- épingler des composants sur des nœuds au matériel particulier (NVMe, forte mémoire, etc.)
- répartir les brokers entre zones de disponibilité
- maîtriser le placement du stockage des volumes persistants

**Points clés :**
- configuration automatique de l'affinité de nœud pour le stockage hostPath
- prise en charge des déploiements mono-nœud comme multi-nœuds
- association souple entre réplicas et nœuds
- validation de la disponibilité des nœuds avant déploiement
- vérification du placement des pods après déploiement

## Démarrage rapide

### Déploiement mono-nœud

```bash
# Default behavior - all components on one node
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

### Déploiement multi-nœuds

```bash
# Distribute brokers across nodes
export KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1,broker-1:worker-2,broker-2:worker-3"

# Keep controllers together on one node
export KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,ctrl-1:control-1,ctrl-2:control-1"

# Run the deployment
./strimzi-setup.sh
```

C'est tout : le script va

- vérifier que tous les nœuds indiqués existent et sont prêts
- créer les PersistentVolumes avec l'affinité de nœud (en mode hostPath)
- injecter automatiquement l'affinité de nœud dans les KafkaNodePools
- vérifier le placement des pods après déploiement

## Options de configuration

### Variables d'environnement

| Variable | Description | Exemple |
|----------|-------------|---------|
| `KAFKA_BROKER_NODE_SELECTORS` | Paires broker:nœud séparées par des virgules | `"broker-0:node1,broker-1:node2"` |
| `KAFKA_CONTROLLER_NODE_SELECTORS` | Paires controller:nœud séparées par des virgules | `"controller-0:node1,controller-1:node2"` |
| `KAFKA_BROKER_REPLICAS` | Nombre de réplicas broker | `3` |
| `KAFKA_CONTROLLER_REPLICAS` | Nombre de réplicas controller | `3` |
| `STRIMZI_NODE_HOSTNAME` | Nœud par défaut lorsqu'aucun selector n'est indiqué | `"worker-1"` |
| `STORAGE_MODE` | Mode de stockage : `hostPath` ou `pvc` | `"hostPath"` |

### Format des selectors

Les node selectors s'écrivent sous la forme `replica-id:node-name`

- **Identifiant de réplica** : plusieurs formes sont acceptées :
  - nom complet du broker : `broker-0`, `broker-1`, etc.
  - nom complet du controller : `controller-0`, `controller-1`, etc.
  - nom court du controller : `ctrl-0`, `ctrl-1`, etc.
  - numéro seul : `0`, `1`, `2`, etc.
- **Nom du nœud** : doit être exactement le nom du nœud Kubernetes

Exemples :
```bash
# Broker formats (all equivalent for broker 0)
KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1"
KAFKA_BROKER_NODE_SELECTORS="0:worker-1"

# Controller formats (all equivalent for controller 0)
KAFKA_CONTROLLER_NODE_SELECTORS="controller-0:control-1"
KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1"
KAFKA_CONTROLLER_NODE_SELECTORS="0:control-1"

# Mixed formats work too
KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1,1:worker-2,broker-2:worker-3"
KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,controller-1:control-1,2:control-1"
```

## Scénarios de déploiement

### Scénario 1 : tous les composants sur un seul nœud

```bash
# Explicitly set all to same node
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-1,2:worker-1"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:worker-1,1:worker-1,2:worker-1"

# Or use default behavior (simpler and recommended)
export STRIMZI_NODE_HOSTNAME="worker-1"
unset KAFKA_BROKER_NODE_SELECTORS
unset KAFKA_CONTROLLER_NODE_SELECTORS

./strimzi-setup.sh
```

### Scénario 2 : brokers répartis, controllers regroupés

```bash
# Brokers across different nodes for better throughput
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"

# Controllers on a single control node for better coordination
export KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,ctrl-1:control-1,ctrl-2:control-1"

./strimzi-setup.sh
```

### Scénario 3 : haute disponibilité entre zones

```bash
# Distribute across availability zones
export KAFKA_BROKER_NODE_SELECTORS="0:az1-node1,1:az2-node1,2:az3-node1"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:az1-node2,1:az2-node2,2:az3-node2"

./strimzi-setup.sh
```

### Scénario 4 : placement optimisé pour le stockage

```bash
# Pin to nodes with NVMe storage for better performance
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-node-1,1:nvme-node-2,2:nvme-node-3"

# Controllers on standard nodes (less I/O intensive)
export KAFKA_CONTROLLER_NODE_SELECTORS="0:standard-node-1,1:standard-node-1,2:standard-node-1"

./strimzi-setup.sh
```

### Scénario 5 : node selectors partiels

```bash
# Only specify some replicas, others use default
export KAFKA_BROKER_NODE_SELECTORS="0:special-node-1"  # Only broker-0 pinned
export STRIMZI_NODE_HOSTNAME="default-node"  # broker-1 and broker-2 use this

./strimzi-setup.sh
```

## Considérations de stockage

### Mode hostPath

Avec le mode de stockage `hostPath` et des node selectors :

1. **Créez les répertoires sur les nœuds cibles** avant le déploiement :
   ```bash
   # On each target node
   sudo mkdir -p /data/strimzi/my-cluster/broker-pool-0
   sudo mkdir -p /data/strimzi/my-cluster/controller-0
   sudo chown -R 1001:1001 /data/strimzi
   sudo chmod -R 755 /data/strimzi
   ```

2. **Les PersistentVolumes sont créés automatiquement**, avec une affinité de nœud correspondant au placement des pods :
   ```yaml
   # Example: Broker 0 on worker-1
   nodeAffinity:
     required:
       nodeSelectorTerms:
       - matchExpressions:
         - key: kubernetes.io/hostname
           operator: In
           values:
           - worker-1  # Matches KAFKA_BROKER_NODE_SELECTORS for broker-0
   ```

3. **Les KafkaNodePools reçoivent automatiquement une affinité de nœud**, pour que les pods démarrent sur les nœuds qui portent leur stockage :
   ```yaml
   # Automatically injected by the script
   template:
     pod:
       affinity:
         nodeAffinity:
           requiredDuringSchedulingIgnoredDuringExecution:
             nodeSelectorTerms:
             - matchExpressions:
               - key: kubernetes.io/hostname
                 operator: In
                 values:
                 - worker-1  # All nodes used by this pool
                 - worker-2
                 - worker-3
   ```

   Cela garantit que :
   - les pods ne peuvent être planifiés que sur les nœuds où le stockage existe
   - stockage et calcul restent colocalisés, pour des performances optimales
   - un pod en échec ne sera pas replanifié sur un nœud dépourvu de ses données

### Mode PVC

Avec le mode PVC et le provisionnement dynamique :

```bash
export STORAGE_MODE="pvc"
export STORAGE_CLASS="fast-ssd"  # Or leave empty for default
export STORAGE_SIZE="100Gi"

# Node selectors still control pod placement (no node affinity injection needed)
export KAFKA_BROKER_NODE_SELECTORS="0:node1,1:node2,2:node3"

./strimzi-setup.sh
```

**Note :** en mode PVC, l'affinité de nœud n'est PAS injectée automatiquement dans les KafkaNodePools, puisque le provisionneur de stockage gère lui-même le placement des volumes. Les pods peuvent alors être planifiés plus librement, selon les ressources disponibles.

## Validation avant déploiement

Le script effectue plusieurs contrôles :

### 1. Contrôle d'existence des nœuds
```bash
# Script validates all specified nodes exist
# If a node doesn't exist, deployment is aborted
```

### 2. Contrôle de disponibilité des nœuds
```bash
# Warns if nodes are not in Ready state
# Deployment continues with warning
```

### 3. Contrôle du label de stockage (optionnel)
```bash
# Checks for kafka-storage=true label
# Informational only, not required

# To add label:
kubectl label node worker-1 kafka-storage=true
```

## Tests

### Lancer la suite de tests

```bash
# Interactive test menu
./test-node-selectors.sh

# Run all tests automatically
./test-node-selectors.sh all

# Check current placement
./test-node-selectors.sh status

# Clean up test deployment
./test-node-selectors.sh cleanup
```

### Vérification manuelle

```bash
# Check pod placement
kubectl get pods -n kafka -o wide

# Verify specific pod placement
kubectl get pod broker-pool-0 -n kafka -o jsonpath='{.spec.nodeName}'

# Check PV node affinity
kubectl get pv -l strimzi.io/cluster=my-cluster -o yaml | grep -A5 nodeAffinity

# Monitor pod scheduling events
kubectl describe pod broker-pool-0 -n kafka | grep -A10 Events
```

## Dépannage

### Problème : pods bloqués en Pending

**Symptôme** : les pods restent à l'état Pending

**Causes possibles** :
1. le nœud n'a pas assez de ressources
2. l'affinité de nœud du PV ne correspond pas au placement du pod
3. le stockage n'est pas disponible sur le nœud cible

**Solution** :
```bash
# Check pod events
kubectl describe pod broker-pool-0 -n kafka

# Check node resources
kubectl describe node worker-1

# Verify PV node affinity matches pod node
kubectl get pv pv-my-cluster-broker-pool-0 -o yaml
```

### Problème : erreur « nœud introuvable »

**Symptôme** : le script échoue avec « Node not found in cluster »

**Solution** :
```bash
# List available nodes
kubectl get nodes

# Use exact node names from the output
export KAFKA_BROKER_NODE_SELECTORS="0:actual-node-name"
```

### Problème : le stockage ne se lie pas

**Symptôme** : les PVC restent à l'état Pending

**Causes possibles** :
1. l'affinité de nœud du PV ne correspond pas au nœud du pod
2. les répertoires de stockage n'existent pas sur le nœud
3. des problèmes de permissions

**Solution** :
```bash
# Check PVC status
kubectl get pvc -n kafka

# Verify PV node affinity
kubectl get pv -o yaml | grep -B5 -A5 nodeAffinity

# SSH to node and check directories
ssh node-1 "ls -la /data/strimzi/my-cluster"
```

### Problème : répartition déséquilibrée

**Symptôme** : plusieurs brokers sur le même nœud malgré des selectors différents

**À vérifier** :
```bash
# Verify environment variables
echo $KAFKA_BROKER_NODE_SELECTORS

# Check actual pod placement
kubectl get pods -n kafka -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName

# Look for topology constraints
kubectl get kafkanodepool broker-pool -n kafka -o yaml | grep -A10 affinity
```

## Bonnes pratiques

### 1. Labellisez vos nœuds

```bash
# Label nodes by role
kubectl label node worker-1 node-role=kafka-broker
kubectl label node control-1 node-role=kafka-controller

# Label by storage type
kubectl label node nvme-node-1 storage-type=nvme
kubectl label node worker-1 storage-type=standard
```

### 2. Planifiez l'agencement du stockage

- **Colocalisez stockage et calcul** : placez les PV sur les mêmes nœuds que les pods
- **Utilisez du stockage local pour la performance** : hostPath ou PV local donnent les meilleurs résultats
- **Pensez aux domaines de panne** : répartissez entre zones et racks

### 3. Surveillez l'usage des ressources

```bash
# Check node resources before deployment
kubectl top nodes

# Monitor after deployment
kubectl top pods -n kafka
```

### 4. Utilisez des nœuds dédiés

En production :
- envisagez de dédier des nœuds à Kafka
- utilisez taints et tolerations pour un ordonnancement exclusif
- séparez les nœuds controller et broker sur les grands clusters

### 5. Documentez votre configuration

Créez un fichier de configuration :
```bash
# kafka-placement.env
export KAFKA_BROKER_NODE_SELECTORS="0:prod-kafka-1,1:prod-kafka-2,2:prod-kafka-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:prod-control-1,1:prod-control-2,2:prod-control-3"
export STORAGE_MODE="hostPath"
export STRIMZI_HOST_BASE_DIR="/data/kafka"

# Source before deployment
source kafka-placement.env
./strimzi-setup-with-node-selectors.sh
```

## Migration depuis un déploiement existant

### Étape 1 : sauvegarder la configuration actuelle

```bash
# Export current Kafka configuration
kubectl get kafka my-cluster -n kafka -o yaml > kafka-backup.yaml
kubectl get kafkanodepool -n kafka -o yaml > nodepool-backup.yaml
```

### Étape 2 : planifier l'association aux nœuds

```bash
# Check current pod placement
kubectl get pods -n kafka -o wide

# Plan new placement based on requirements
```

### Étape 3 : préparer les nœuds cibles

```bash
# On each target node
sudo mkdir -p /data/strimzi/my-cluster
sudo chown -R 1001:1001 /data/strimzi
```

### Étape 4 : déployer avec les node selectors

```bash
# Set your node mappings
export KAFKA_BROKER_NODE_SELECTORS="0:new-node-1,1:new-node-2,2:new-node-3"

# Run migration (consider doing this during maintenance window)
./strimzi-setup.sh
```

## Configuration avancée

### Règles d'affinité personnalisées

Pour des besoins d'affinité plus complexes, modifiez le NodePool généré :

```yaml
template:
  pod:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: node-role
              operator: In
              values: ["kafka-broker"]
        preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          preference:
            matchExpressions:
            - key: storage-type
              operator: In
              values: ["nvme"]
```

### Usage avec les opérateurs Kubernetes

La configuration des node selectors fonctionne avec :
- **Cluster Autoscaler** : préprovisionnez ou labellisez les groupes de nœuds
- **Karpenter** : utilisez les requirements du provisioner
- **Node Feature Discovery** : appuyez-vous sur les labels matériels

## Support et retours

En cas de problème ou de question :
1. consultez la section dépannage
2. relisez la sortie des tests : `./test-node-selectors.sh all`
3. examinez les événements des pods : `kubectl describe pod <pod-name> -n kafka`
4. consultez les logs de l'opérateur : `kubectl logs -n strimzi -l name=strimzi-cluster-operator`

## Annexe : exemple complet

```bash
#!/bin/bash
# Complete deployment example

# 1. Check available nodes
echo "Available nodes:"
kubectl get nodes

# 2. Label nodes for clarity
kubectl label node worker-1 kafka-role=broker storage=nvme
kubectl label node worker-2 kafka-role=broker storage=nvme
kubectl label node worker-3 kafka-role=broker storage=nvme
kubectl label node control-1 kafka-role=controller storage=ssd

# 3. Set configuration
export STRIMZI_CLUSTER_NAME="production-kafka"
export NS_KAFKA="kafka-prod"
export STORAGE_MODE="hostPath"
export STRIMZI_HOST_BASE_DIR="/data/kafka"

# 4. Configure node placement
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:control-1,1:control-1,2:control-1"

# 5. Configure resources
export KAFKA_BROKER_REPLICAS=3
export KAFKA_CONTROLLER_REPLICAS=3
export STRIMZI_BROKER_STORAGE_SIZE="100Gi"
export STRIMZI_CONTROLLER_STORAGE_SIZE="10Gi"

# 6. Deploy
./strimzi-setup.sh

# 7. Verify
kubectl get pods -n kafka-prod -o wide
kubectl get pv -l strimzi.io/cluster=production-kafka

# 8. Test
kubectl run kafka-test -ti --image=quay.io/strimzi/kafka:latest-kafka-3.9.0 \
  --rm=true --restart=Never -- \
  bin/kafka-topics.sh --bootstrap-server production-kafka-kafka-bootstrap:9092 --list
```
