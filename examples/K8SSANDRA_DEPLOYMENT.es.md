# Guía de despliegue de K8ssandra

[English](K8SSANDRA_DEPLOYMENT.md) | [Français](K8SSANDRA_DEPLOYMENT.fr.md) | **Español** | [Galego](K8SSANDRA_DEPLOYMENT.gl.md)

Esta guía cubre el despliegue de Apache Cassandra con el operador K8ssandra sobre
Kubernetes, con integración opcional de la monitorización de AxonOps.

## Inicio rápido

```bash
# 1. Install K8ssandra operator
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update
helm install k8ssandra-operator k8ssandra/k8ssandra-operator -n k8ssandra-operator --create-namespace

# 2. Configure and deploy cluster
cd k8ssandra/
export $(grep -v '^#' k8ssandra-config.env | xargs)
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

---

## Visión general

K8ssandra es una plataforma lista para producción que ejecuta Apache Cassandra
sobre Kubernetes. Este despliegue usa:

- **el operador K8ssandra**: el operador de Kubernetes que gestiona los clústeres
  de Cassandra
- **las imágenes de AxonOps**: imágenes de Cassandra con el agente de AxonOps
  incorporado
- **AxonOps Cloud**: integración opcional de monitorización y gestión

### Prestaciones

- Despliegue y escalado automatizados
- Actualizaciones y reparaciones progresivas
- Capacidades de copia de seguridad y restauración
- Integración con la monitorización de AxonOps

## Requisitos previos

1. **Un clúster de Kubernetes** (v1.21+)
   - Admite un solo nodo o varios nodos
2. **Herramientas necesarias**:
   - `kubectl`: la CLI de Kubernetes
   - `helm`: el gestor de paquetes Helm v3.x
   - `envsubst`: sustitución de variables (parte del paquete `gettext`)
3. **Almacenamiento**: soporte de PersistentVolume o el provisionador local-path
4. **Opcional**: una cuenta de AxonOps para la integración de la monitorización

## Instalar el operador K8ssandra

### Paso 1: añadir el repositorio de Helm

```bash
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update
```

### Paso 2: instalar el operador

```bash
# Create namespace and install operator
helm install k8ssandra-operator k8ssandra/k8ssandra-operator \
  -n k8ssandra-operator \
  --create-namespace
```

### Paso 3: verificar la instalación

```bash
# Check operator pods
kubectl get pods -n k8ssandra-operator

# Wait for operator to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=k8ssandra-operator \
  -n k8ssandra-operator \
  --timeout=300s
```

Salida esperada:

```text
NAME                                                READY   STATUS    RESTARTS   AGE
k8ssandra-operator-xxxxxxx-xxxxx                    1/1     Running   0          1m
k8ssandra-operator-cass-operator-xxxxxxx-xxxxx      1/1     Running   0          1m
```

## Configuración

### Variables de entorno

Cree o edite `k8ssandra/k8ssandra-config.env`:

```bash
# K8ssandra Cluster Configuration
K8SSANDRA_CLUSTER_NAME=axonops-k8ssandra
K8SSANDRA_NAMESPACE=k8ssandra-operator
CASSANDRA_VERSION=5.0.6
CASSANDRA_DC_NAME=dc1
CASSANDRA_DC_SIZE=3

# AxonOps Container Image
IMAGE_NAME=ghcr.io/axonops/cassandra:5.0.6

# Storage Configuration
STORAGE_CLASS=local-path
STORAGE_SIZE=10Gi

# Resource Limits
CPU_LIMIT=2
CPU_REQUEST=1
MEMORY_LIMIT=4Gi
MEMORY_REQUEST=2Gi
HEAP_SIZE=1G

# AxonOps Agent Configuration (for AxonOps Cloud)
AXON_AGENT_KEY=your-agent-key
AXON_AGENT_ORG=your-organization
AXON_AGENT_SERVER_HOST=agents.axonops.cloud
AXON_AGENT_SERVER_PORT=443
```

### Referencia de las variables de configuración

| Variable | Valor por defecto | Descripción |
| --- | --- | --- |
| `K8SSANDRA_CLUSTER_NAME` | `axonops-k8ssandra` | Nombre del clúster de Cassandra |
| `K8SSANDRA_NAMESPACE` | `k8ssandra-operator` | Espacio de nombres de Kubernetes |
| `CASSANDRA_VERSION` | `5.0.6` | Versión de Cassandra |
| `IMAGE_NAME` | `ghcr.io/axonops/cassandra:5.0.6` | Imagen de Cassandra de AxonOps |
| `CASSANDRA_DC_NAME` | `dc1` | Nombre del datacenter |
| `CASSANDRA_DC_SIZE` | `3` | Número de nodos de Cassandra |
| `STORAGE_CLASS` | `local-path` | StorageClass de Kubernetes |
| `STORAGE_SIZE` | `10Gi` | Almacenamiento por nodo |
| `AXON_AGENT_KEY` | - | Clave de API de AxonOps |
| `AXON_AGENT_ORG` | - | Nombre de la organización de AxonOps |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | Nombre de host del servidor de AxonOps |
| `AXON_AGENT_SERVER_PORT` | `443` | Puerto del servidor de AxonOps |

## Despliegue

### Usar envsubst

Los manifiestos de ejemplo usan marcadores de variables de entorno. Use
`envsubst` para sustituir los valores antes de aplicarlos:

```bash
cd k8ssandra/

# 1. Source configuration
export $(grep -v '^#' k8ssandra-config.env | xargs)

# 2. Apply cluster manifest with variable substitution
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

### Despliegue manual

Como alternativa, edite el fichero YAML directamente y aplíquelo:

```bash
# Edit the manifest
vi k8ssandra/cluster-axonops-ubi.yaml

# Apply directly
kubectl apply -f k8ssandra/cluster-axonops-ubi.yaml
```

### Esperar a que el clúster esté listo

```bash
# Watch cluster status
kubectl get k8ssandraclusters -n k8ssandra-operator -w

# Check pods
kubectl get pods -n k8ssandra-operator -l cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME

# View cluster details
kubectl describe k8ssandracluster $K8SSANDRA_CLUSTER_NAME -n k8ssandra-operator
```

## Verificar el despliegue

### Comprobar el estado del clúster

```bash
# View K8ssandraCluster resource
kubectl get k8ssandraclusters -n k8ssandra-operator

# View CassandraDatacenter
kubectl get cassandradatacenters -n k8ssandra-operator

# View all pods
kubectl get pods -n k8ssandra-operator -o wide
```

### Probar la conectividad con Cassandra

```bash
# Get a shell in a Cassandra pod
kubectl exec -it ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- cqlsh

# Run a simple query
cqlsh> SELECT cluster_name, listen_address FROM system.local;
cqlsh> DESCRIBE KEYSPACES;
```

### Comprobar la integración con AxonOps

Si usa AxonOps Cloud:

```bash
# Check agent logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator | grep -i axon

# Verify agent environment variables
kubectl exec ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- env | grep AXON
```

Después consulte el panel de AxonOps en
[https://console.axonops.cloud](https://console.axonops.cloud) para comprobar que
su clúster aparece.

## Opciones de integración con AxonOps

### Opción 1: AxonOps Cloud (SaaS)

Use AxonOps Cloud para una monitorización gestionada:

1. Dese de alta en [https://axonops.cloud](https://axonops.cloud)
2. Cree una organización y obtenga su clave de API
3. Configure las variables de entorno del agente en `k8ssandra-config.env`:

```bash
AXON_AGENT_KEY=your-api-key
AXON_AGENT_ORG=your-organization
AXON_AGENT_SERVER_HOST=agents.axonops.cloud
AXON_AGENT_SERVER_PORT=443
```

### Opción 2: AxonOps autoalojado

Despliegue AxonOps on-premises primero, y luego configure Cassandra para
conectarse:

```bash
# Deploy AxonOps (see AXONOPS_DEPLOYMENT.md)
cd ../axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh
source axonops-config.env

# Configure K8ssandra to use self-hosted AxonOps
export AXON_AGENT_SERVER_HOST=axon-server-agent.axonops.svc.cluster.local
export AXON_AGENT_SERVER_PORT=1888
export AXON_AGENT_ORG=$AXON_SERVER_ORG_NAME

# Deploy K8ssandra
cd ../k8ssandra/
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

## Escalar el clúster

### Añadir nodos

```bash
# Edit the datacenter size
kubectl patch k8ssandracluster $K8SSANDRA_CLUSTER_NAME \
  -n k8ssandra-operator \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/cassandra/datacenters/0/size", "value": 5}]'

# Or edit the manifest and reapply
export CASSANDRA_DC_SIZE=5
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

### Quitar nodos

Reduzca la escala con cuidado para no perder datos:

```bash
# Decommission nodes first, then reduce size
kubectl patch k8ssandracluster $K8SSANDRA_CLUSTER_NAME \
  -n k8ssandra-operator \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/cassandra/datacenters/0/size", "value": 3}]'
```

## Resolución de problemas

### Pods atascados en Pending

```bash
# Check PVC status
kubectl get pvc -n k8ssandra-operator

# Check events
kubectl get events -n k8ssandra-operator --sort-by='.lastTimestamp'

# Verify storage class exists
kubectl get storageclass
```

### Cassandra no arranca

```bash
# Check pod logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator

# Check init container logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -c server-config-init

# Describe pod for events
kubectl describe pod ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator
```

### El agente de AxonOps no conecta

```bash
# Verify environment variables
kubectl exec ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- env | grep AXON

# Test network connectivity to AxonOps
kubectl exec ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- nc -zv $AXON_AGENT_SERVER_HOST $AXON_AGENT_SERVER_PORT

# Check agent logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator | grep -i "axon\|agent"
```

## Limpieza

### Eliminar el clúster de Cassandra

```bash
# Delete the K8ssandraCluster
kubectl delete k8ssandracluster $K8SSANDRA_CLUSTER_NAME -n k8ssandra-operator

# Delete PVCs (WARNING: deletes all data)
kubectl delete pvc -l cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME \
  -n k8ssandra-operator
```

### Eliminar el operador K8ssandra

```bash
# Uninstall operator
helm uninstall k8ssandra-operator -n k8ssandra-operator

# Delete namespace
kubectl delete namespace k8ssandra-operator
```

## Consideraciones para producción

1. **Almacenamiento**: use SSD de alto rendimiento con IOPS adecuadas
2. **Recursos**: asigne CPU y memoria suficientes (se recomiendan 4 o más núcleos
   y 8 GB o más de RAM por nodo)
3. **Replicación**: use un factor de replicación de 3 en producción
4. **Copias de seguridad**: configure Medusa para copias automatizadas
5. **Monitorización**: use AxonOps para una monitorización y alertado completos
6. **Seguridad**: active el cifrado TLS y la autenticación
7. **Red**: use una red dedicada para la comunicación entre nodos

## Recursos adicionales

- **Documentación de K8ssandra**: [https://docs.k8ssandra.io/](https://docs.k8ssandra.io/)
- **K8ssandra en GitHub**: [https://github.com/k8ssandra/k8ssandra](https://github.com/k8ssandra/k8ssandra)
- **Documentación de AxonOps**: [https://docs.axonops.com](https://docs.axonops.com)
- **Configuración del agente de AxonOps**: [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Documentación de Apache Cassandra**: [https://cassandra.apache.org/doc/](https://cassandra.apache.org/doc/)
- **Manifiestos de ejemplo**: [k8ssandra/](k8ssandra/)

---

**Última actualización:** 2026-02-13
