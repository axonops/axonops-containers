# Guía de configuración de node selectors de Strimzi

[English](NODE_SELECTOR_GUIDE.md) | [Français](NODE_SELECTOR_GUIDE.fr.md) | [Español](NODE_SELECTOR_GUIDE.es.md) | **Galego**

## Visión xeral

Esta guía explica como usar o script de despregamento de Strimzi para fixar os
brokers e os controllers de Kafka a nodos concretos de Kubernetes. Isto é
imprescindible cando precisa:

- Garantir a localidade dos datos por rendemento
- Fixar compoñentes a nodos con hardware concreto (NVMe, moita memoria, etc.)
- Repartir os brokers entre zonas de dispoñibilidade
- Controlar a ubicación do almacenamento dos volumes persistentes

**Prestacións clave:**
- Configuración automática da afinidade de nodo para almacenamento hostPath
- Soporte tanto de despregamentos dun só nodo como de varios nodos
- Correspondencia flexible entre réplicas e nodos
- Validación da dispoñibilidade dos nodos antes do despregamento
- Verificación da ubicación dos pods despois do despregamento

## Inicio rápido

### Despregamento nun só nodo

```bash
# Default behavior - all components on one node
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

### Despregamento en varios nodos

```bash
# Distribute brokers across nodes
export KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1,broker-1:worker-2,broker-2:worker-3"

# Keep controllers together on one node
export KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,ctrl-1:control-1,ctrl-2:control-1"

# Run the deployment
./strimzi-setup.sh
```

E xa está! O script:
- Valida que todos os nodos indicados existen e están listos
- Crea PersistentVolumes con afinidade de nodo (en modo hostPath)
- Inxecta a afinidade de nodo nos KafkaNodePools automaticamente
- Verifica a ubicación dos pods tras o despregamento

## Opcións de configuración

### Variables de entorno

| Variable | Descrición | Exemplo |
|----------|-------------|---------|
| `KAFKA_BROKER_NODE_SELECTORS` | Pares broker:nodo separados por comas | `"broker-0:node1,broker-1:node2"` |
| `KAFKA_CONTROLLER_NODE_SELECTORS` | Pares controller:nodo separados por comas | `"controller-0:node1,controller-1:node2"` |
| `KAFKA_BROKER_REPLICAS` | Número de réplicas de broker | `3` |
| `KAFKA_CONTROLLER_REPLICAS` | Número de réplicas de controller | `3` |
| `STRIMZI_NODE_HOSTNAME` | Nodo por defecto cando non se indican selectores | `"worker-1"` |
| `STORAGE_MODE` | Modo de almacenamento: `hostPath` ou `pvc` | `"hostPath"` |

### Formato dos selectores

Os node selectors usan o formato `id-de-réplica:nome-de-nodo`.

- **ID de réplica**: admite varios formatos:
  - Nome completo do broker: `broker-0`, `broker-1`, etc.
  - Nome completo do controller: `controller-0`, `controller-1`, etc.
  - Nome curto do controller: `ctrl-0`, `ctrl-1`, etc.
  - Só o número: `0`, `1`, `2`, etc.
- **Nome do nodo**: debe ser o nome exacto do nodo de Kubernetes

Exemplos:
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

## Escenarios de despregamento

### Escenario 1: todos os compoñentes nun só nodo

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

### Escenario 2: brokers repartidos, controllers xuntos

```bash
# Brokers across different nodes for better throughput
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"

# Controllers on a single control node for better coordination
export KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,ctrl-1:control-1,ctrl-2:control-1"

./strimzi-setup.sh
```

### Escenario 3: alta dispoñibilidade entre zonas

```bash
# Distribute across availability zones
export KAFKA_BROKER_NODE_SELECTORS="0:az1-node1,1:az2-node1,2:az3-node1"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:az1-node2,1:az2-node2,2:az3-node2"

./strimzi-setup.sh
```

### Escenario 4: ubicación optimizada para o almacenamento

```bash
# Pin to nodes with NVMe storage for better performance
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-node-1,1:nvme-node-2,2:nvme-node-3"

# Controllers on standard nodes (less I/O intensive)
export KAFKA_CONTROLLER_NODE_SELECTORS="0:standard-node-1,1:standard-node-1,2:standard-node-1"

./strimzi-setup.sh
```

### Escenario 5: selectores de nodo parciais

```bash
# Only specify some replicas, others use default
export KAFKA_BROKER_NODE_SELECTORS="0:special-node-1"  # Only broker-0 pinned
export STRIMZI_NODE_HOSTNAME="default-node"  # broker-1 and broker-2 use this

./strimzi-setup.sh
```

## Consideracións sobre o almacenamento

### Modo hostPath

Ao usar o modo de almacenamento `hostPath` con node selectors:

1. **Cree os directorios nos nodos de destino** antes de despregar:
   ```bash
   # On each target node
   sudo mkdir -p /data/strimzi/my-cluster/broker-pool-0
   sudo mkdir -p /data/strimzi/my-cluster/controller-0
   sudo chown -R 1001:1001 /data/strimzi
   sudo chmod -R 755 /data/strimzi
   ```

2. **Os PersistentVolumes créanse automaticamente** cunha afinidade de nodo que
   coincide coa ubicación dos pods:
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

3. **Os KafkaNodePools reciben automaticamente a afinidade de nodo** para
   asegurar que os pods arrancan nos nodos onde está o seu almacenamento:
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

   Isto garante que:
   - Os pods só poidan planificarse en nodos onde existe o almacenamento
   - Almacenamento e cómputo estean xuntos, para un rendemento óptimo
   - Os pods caídos non se planifiquen en nodos que non teñen os seus datos

### Modo PVC

Ao usar o modo PVC con aprovisionamento dinámico:

```bash
export STORAGE_MODE="pvc"
export STORAGE_CLASS="fast-ssd"  # Or leave empty for default
export STORAGE_SIZE="100Gi"

# Node selectors still control pod placement (no node affinity injection needed)
export KAFKA_BROKER_NODE_SELECTORS="0:node1,1:node2,2:node3"

./strimzi-setup.sh
```

**Nota:** en modo PVC, a afinidade de nodo NON se inxecta automaticamente nos
KafkaNodePools, porque o provisionador de almacenamento se ocupa da ubicación dos
volumes. Os pods poden planificarse con máis flexibilidade segundo os recursos
dispoñibles.

## Validación previa ao despregamento

O script realiza varias comprobacións de validación:

### 1. Comprobación da existencia dos nodos
```bash
# Script validates all specified nodes exist
# If a node doesn't exist, deployment is aborted
```

### 2. Comprobación de que os nodos están listos
```bash
# Warns if nodes are not in Ready state
# Deployment continues with warning
```

### 3. Comprobación da etiqueta de almacenamento (opcional)
```bash
# Checks for kafka-storage=true label
# Informational only, not required

# To add label:
kubectl label node worker-1 kafka-storage=true
```

## Probas

### Executar a batería de probas

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

### Verificación manual

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

## Resolución de problemas

### Problema: pods atascados en Pending

**Síntoma**: os pods quedan en estado Pending.

**Causas posibles**:
1. O nodo non ten recursos abondos
2. A afinidade de nodo do PV non coincide coa ubicación do pod
3. O almacenamento non está dispoñible no nodo de destino

**Solución**:
```bash
# Check pod events
kubectl describe pod broker-pool-0 -n kafka

# Check node resources
kubectl describe node worker-1

# Verify PV node affinity matches pod node
kubectl get pv pv-my-cluster-broker-pool-0 -o yaml
```

### Problema: erro de nodo non atopado

**Síntoma**: o script falla con «Node not found in cluster».

**Solución**:
```bash
# List available nodes
kubectl get nodes

# Use exact node names from the output
export KAFKA_BROKER_NODE_SELECTORS="0:actual-node-name"
```

### Problema: o almacenamento non se liga

**Síntoma**: as PVC quedan en estado Pending.

**Causas posibles**:
1. A afinidade de nodo do PV non coincide co nodo do pod
2. Os directorios de almacenamento non existen no nodo
3. Problemas de permisos

**Solución**:
```bash
# Check PVC status
kubectl get pvc -n kafka

# Verify PV node affinity
kubectl get pv -o yaml | grep -B5 -A5 nodeAffinity

# SSH to node and check directories
ssh node-1 "ls -la /data/strimzi/my-cluster"
```

### Problema: reparto desigual

**Síntoma**: varios brokers no mesmo nodo malia teren selectores distintos.

**Comprobacións**:
```bash
# Verify environment variables
echo $KAFKA_BROKER_NODE_SELECTORS

# Check actual pod placement
kubectl get pods -n kafka -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName

# Look for topology constraints
kubectl get kafkanodepool broker-pool -n kafka -o yaml | grep -A10 affinity
```

## Boas prácticas

### 1. Etiquete os seus nodos

```bash
# Label nodes by role
kubectl label node worker-1 node-role=kafka-broker
kubectl label node control-1 node-role=kafka-controller

# Label by storage type
kubectl label node nvme-node-1 storage-type=nvme
kubectl label node worker-1 storage-type=standard
```

### 2. Planifique a disposición do almacenamento

- **Xunte almacenamento e cómputo**: asegúrese de que os PV están nos mesmos
  nodos ca os pods
- **Use almacenamento local por rendemento**: hostPath ou PV locais dan o mellor
  rendemento
- **Teña en conta os dominios de fallo**: reparta entre zonas ou racks

### 3. Vixíe o uso de recursos

```bash
# Check node resources before deployment
kubectl top nodes

# Monitor after deployment
kubectl top pods -n kafka
```

### 4. Use nodos dedicados

En produción:
- Valore dedicar nodos a Kafka
- Use taints e tolerancias para unha planificación exclusiva
- Separe os nodos de controller e de broker en clústeres grandes

### 5. Documente a súa configuración

Cree un ficheiro de configuración:
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

## Migrar dende un despregamento existente

### Paso 1: faga copia da configuración actual

```bash
# Export current Kafka configuration
kubectl get kafka my-cluster -n kafka -o yaml > kafka-backup.yaml
kubectl get kafkanodepool -n kafka -o yaml > nodepool-backup.yaml
```

### Paso 2: planifique a correspondencia cos nodos

```bash
# Check current pod placement
kubectl get pods -n kafka -o wide

# Plan new placement based on requirements
```

### Paso 3: prepare os nodos de destino

```bash
# On each target node
sudo mkdir -p /data/strimzi/my-cluster
sudo chown -R 1001:1001 /data/strimzi
```

### Paso 4: despregue con node selectors

```bash
# Set your node mappings
export KAFKA_BROKER_NODE_SELECTORS="0:new-node-1,1:new-node-2,2:new-node-3"

# Run migration (consider doing this during maintenance window)
./strimzi-setup.sh
```

## Configuración avanzada

### Regras de afinidade personalizadas

Para requisitos de afinidade máis complexos, modifique o NodePool xerado:

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

### Uso con operadores de Kubernetes

A configuración de node selectors funciona con:
- **Cluster Autoscaler**: preaprovisione ou etiquete grupos de nodos
- **Karpenter**: use os requisitos do provisioner
- **Node Feature Discovery**: aproveite as etiquetas de hardware

## Soporte e comentarios

Para problemas ou preguntas:
1. Revise a sección de resolución de problemas
2. Revise a saída das probas: `./test-node-selectors.sh all`
3. Examine os eventos do pod: `kubectl describe pod <pod-name> -n kafka`
4. Revise os rexistros do operador: `kubectl logs -n strimzi -l name=strimzi-cluster-operator`

## Apéndice: exemplo completo

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
