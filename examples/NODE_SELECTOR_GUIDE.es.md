# Guía de configuración de node selectors de Strimzi

[English](NODE_SELECTOR_GUIDE.md) | [Français](NODE_SELECTOR_GUIDE.fr.md) | **Español** | [Galego](NODE_SELECTOR_GUIDE.gl.md)

## Visión general

Esta guía explica cómo usar el script de despliegue de Strimzi para fijar los
brokers y los controllers de Kafka a nodos concretos de Kubernetes. Esto es
imprescindible cuando necesita:

- Garantizar la localidad de los datos por rendimiento
- Fijar componentes a nodos con hardware concreto (NVMe, mucha memoria, etc.)
- Repartir los brokers entre zonas de disponibilidad
- Controlar la ubicación del almacenamiento de los volúmenes persistentes

**Prestaciones clave:**
- Configuración automática de la afinidad de nodo para almacenamiento hostPath
- Soporte tanto de despliegues de un solo nodo como de varios nodos
- Correspondencia flexible entre réplicas y nodos
- Validación de la disponibilidad de los nodos antes del despliegue
- Verificación de la ubicación de los pods después del despliegue

## Inicio rápido

### Despliegue en un solo nodo

```bash
# Default behavior - all components on one node
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh
```

### Despliegue en varios nodos

```bash
# Distribute brokers across nodes
export KAFKA_BROKER_NODE_SELECTORS="broker-0:worker-1,broker-1:worker-2,broker-2:worker-3"

# Keep controllers together on one node
export KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,ctrl-1:control-1,ctrl-2:control-1"

# Run the deployment
./strimzi-setup.sh
```

¡Y ya está! El script:
- Valida que todos los nodos indicados existen y están listos
- Crea PersistentVolumes con afinidad de nodo (en modo hostPath)
- Inyecta la afinidad de nodo en los KafkaNodePools automáticamente
- Verifica la ubicación de los pods tras el despliegue

## Opciones de configuración

### Variables de entorno

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `KAFKA_BROKER_NODE_SELECTORS` | Pares broker:nodo separados por comas | `"broker-0:node1,broker-1:node2"` |
| `KAFKA_CONTROLLER_NODE_SELECTORS` | Pares controller:nodo separados por comas | `"controller-0:node1,controller-1:node2"` |
| `KAFKA_BROKER_REPLICAS` | Número de réplicas de broker | `3` |
| `KAFKA_CONTROLLER_REPLICAS` | Número de réplicas de controller | `3` |
| `STRIMZI_NODE_HOSTNAME` | Nodo por defecto cuando no se indican selectores | `"worker-1"` |
| `STORAGE_MODE` | Modo de almacenamiento: `hostPath` o `pvc` | `"hostPath"` |

### Formato de los selectores

Los node selectors usan el formato `id-de-réplica:nombre-de-nodo`.

- **ID de réplica**: admite varios formatos:
  - Nombre completo del broker: `broker-0`, `broker-1`, etc.
  - Nombre completo del controller: `controller-0`, `controller-1`, etc.
  - Nombre corto del controller: `ctrl-0`, `ctrl-1`, etc.
  - Sólo el número: `0`, `1`, `2`, etc.
- **Nombre del nodo**: debe ser el nombre exacto del nodo de Kubernetes

Ejemplos:
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

## Escenarios de despliegue

### Escenario 1: todos los componentes en un solo nodo

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

### Escenario 2: brokers repartidos, controllers juntos

```bash
# Brokers across different nodes for better throughput
export KAFKA_BROKER_NODE_SELECTORS="0:worker-1,1:worker-2,2:worker-3"

# Controllers on a single control node for better coordination
export KAFKA_CONTROLLER_NODE_SELECTORS="ctrl-0:control-1,ctrl-1:control-1,ctrl-2:control-1"

./strimzi-setup.sh
```

### Escenario 3: alta disponibilidad entre zonas

```bash
# Distribute across availability zones
export KAFKA_BROKER_NODE_SELECTORS="0:az1-node1,1:az2-node1,2:az3-node1"
export KAFKA_CONTROLLER_NODE_SELECTORS="0:az1-node2,1:az2-node2,2:az3-node2"

./strimzi-setup.sh
```

### Escenario 4: ubicación optimizada para el almacenamiento

```bash
# Pin to nodes with NVMe storage for better performance
export KAFKA_BROKER_NODE_SELECTORS="0:nvme-node-1,1:nvme-node-2,2:nvme-node-3"

# Controllers on standard nodes (less I/O intensive)
export KAFKA_CONTROLLER_NODE_SELECTORS="0:standard-node-1,1:standard-node-1,2:standard-node-1"

./strimzi-setup.sh
```

### Escenario 5: selectores de nodo parciales

```bash
# Only specify some replicas, others use default
export KAFKA_BROKER_NODE_SELECTORS="0:special-node-1"  # Only broker-0 pinned
export STRIMZI_NODE_HOSTNAME="default-node"  # broker-1 and broker-2 use this

./strimzi-setup.sh
```

## Consideraciones sobre el almacenamiento

### Modo hostPath

Al usar el modo de almacenamiento `hostPath` con node selectors:

1. **Cree los directorios en los nodos de destino** antes de desplegar:
   ```bash
   # On each target node
   sudo mkdir -p /data/strimzi/my-cluster/broker-pool-0
   sudo mkdir -p /data/strimzi/my-cluster/controller-0
   sudo chown -R 1001:1001 /data/strimzi
   sudo chmod -R 755 /data/strimzi
   ```

2. **Los PersistentVolumes se crean automáticamente** con una afinidad de nodo
   que coincide con la ubicación de los pods:
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

3. **Los KafkaNodePools reciben automáticamente la afinidad de nodo** para
   asegurar que los pods arrancan en los nodos donde está su almacenamiento:
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

   Esto garantiza que:
   - Los pods sólo puedan planificarse en nodos donde existe el almacenamiento
   - Almacenamiento y cómputo estén juntos, para un rendimiento óptimo
   - Los pods caídos no se planifiquen en nodos que no tienen sus datos

### Modo PVC

Al usar el modo PVC con aprovisionamiento dinámico:

```bash
export STORAGE_MODE="pvc"
export STORAGE_CLASS="fast-ssd"  # Or leave empty for default
export STORAGE_SIZE="100Gi"

# Node selectors still control pod placement (no node affinity injection needed)
export KAFKA_BROKER_NODE_SELECTORS="0:node1,1:node2,2:node3"

./strimzi-setup.sh
```

**Nota:** en modo PVC, la afinidad de nodo NO se inyecta automáticamente en los
KafkaNodePools, porque el provisionador de almacenamiento se ocupa de la
ubicación de los volúmenes. Los pods pueden planificarse con más flexibilidad
según los recursos disponibles.

## Validación previa al despliegue

El script realiza varias comprobaciones de validación:

### 1. Comprobación de la existencia de los nodos
```bash
# Script validates all specified nodes exist
# If a node doesn't exist, deployment is aborted
```

### 2. Comprobación de que los nodos están listos
```bash
# Warns if nodes are not in Ready state
# Deployment continues with warning
```

### 3. Comprobación de la etiqueta de almacenamiento (opcional)
```bash
# Checks for kafka-storage=true label
# Informational only, not required

# To add label:
kubectl label node worker-1 kafka-storage=true
```

## Pruebas

### Ejecutar la batería de pruebas

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

**Síntoma**: los pods se quedan en estado Pending.

**Causas posibles**:
1. El nodo no tiene recursos suficientes
2. La afinidad de nodo del PV no coincide con la ubicación del pod
3. El almacenamiento no está disponible en el nodo de destino

**Solución**:
```bash
# Check pod events
kubectl describe pod broker-pool-0 -n kafka

# Check node resources
kubectl describe node worker-1

# Verify PV node affinity matches pod node
kubectl get pv pv-my-cluster-broker-pool-0 -o yaml
```

### Problema: error de nodo no encontrado

**Síntoma**: el script falla con «Node not found in cluster».

**Solución**:
```bash
# List available nodes
kubectl get nodes

# Use exact node names from the output
export KAFKA_BROKER_NODE_SELECTORS="0:actual-node-name"
```

### Problema: el almacenamiento no se enlaza

**Síntoma**: las PVC se quedan en estado Pending.

**Causas posibles**:
1. La afinidad de nodo del PV no coincide con el nodo del pod
2. Los directorios de almacenamiento no existen en el nodo
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

**Síntoma**: varios brokers en el mismo nodo pese a tener selectores distintos.

**Comprobaciones**:
```bash
# Verify environment variables
echo $KAFKA_BROKER_NODE_SELECTORS

# Check actual pod placement
kubectl get pods -n kafka -o custom-columns=POD:.metadata.name,NODE:.spec.nodeName

# Look for topology constraints
kubectl get kafkanodepool broker-pool -n kafka -o yaml | grep -A10 affinity
```

## Buenas prácticas

### 1. Etiquete sus nodos

```bash
# Label nodes by role
kubectl label node worker-1 node-role=kafka-broker
kubectl label node control-1 node-role=kafka-controller

# Label by storage type
kubectl label node nvme-node-1 storage-type=nvme
kubectl label node worker-1 storage-type=standard
```

### 2. Planifique la disposición del almacenamiento

- **Junte almacenamiento y cómputo**: asegúrese de que los PV están en los mismos
  nodos que los pods
- **Use almacenamiento local por rendimiento**: hostPath o PV locales dan el mejor
  rendimiento
- **Tenga en cuenta los dominios de fallo**: reparta entre zonas o racks

### 3. Vigile el uso de recursos

```bash
# Check node resources before deployment
kubectl top nodes

# Monitor after deployment
kubectl top pods -n kafka
```

### 4. Use nodos dedicados

En producción:
- Valore dedicar nodos a Kafka
- Use taints y toleraciones para una planificación exclusiva
- Separe los nodos de controller y de broker en clústeres grandes

### 5. Documente su configuración

Cree un fichero de configuración:
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

## Migrar desde un despliegue existente

### Paso 1: haga copia de la configuración actual

```bash
# Export current Kafka configuration
kubectl get kafka my-cluster -n kafka -o yaml > kafka-backup.yaml
kubectl get kafkanodepool -n kafka -o yaml > nodepool-backup.yaml
```

### Paso 2: planifique la correspondencia con los nodos

```bash
# Check current pod placement
kubectl get pods -n kafka -o wide

# Plan new placement based on requirements
```

### Paso 3: prepare los nodos de destino

```bash
# On each target node
sudo mkdir -p /data/strimzi/my-cluster
sudo chown -R 1001:1001 /data/strimzi
```

### Paso 4: despliegue con node selectors

```bash
# Set your node mappings
export KAFKA_BROKER_NODE_SELECTORS="0:new-node-1,1:new-node-2,2:new-node-3"

# Run migration (consider doing this during maintenance window)
./strimzi-setup.sh
```

## Configuración avanzada

### Reglas de afinidad personalizadas

Para requisitos de afinidad más complejos, modifique el NodePool generado:

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

La configuración de node selectors funciona con:
- **Cluster Autoscaler**: preaprovisione o etiquete grupos de nodos
- **Karpenter**: use los requisitos del provisioner
- **Node Feature Discovery**: aproveche las etiquetas de hardware

## Soporte y comentarios

Para problemas o preguntas:
1. Revise la sección de resolución de problemas
2. Revise la salida de las pruebas: `./test-node-selectors.sh all`
3. Examine los eventos del pod: `kubectl describe pod <pod-name> -n kafka`
4. Revise los registros del operador: `kubectl logs -n strimzi -l name=strimzi-cluster-operator`

## Apéndice: ejemplo completo

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
