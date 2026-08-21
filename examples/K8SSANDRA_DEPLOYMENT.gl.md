# Guía de despregamento de K8ssandra

[English](K8SSANDRA_DEPLOYMENT.md) | [Français](K8SSANDRA_DEPLOYMENT.fr.md) | [Español](K8SSANDRA_DEPLOYMENT.es.md) | **Galego**

Esta guía cobre o despregamento de Apache Cassandra co operador K8ssandra sobre
Kubernetes, con integración opcional da monitorización de AxonOps.

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

## Visión xeral

K8ssandra é unha plataforma lista para produción que executa Apache Cassandra
sobre Kubernetes. Este despregamento usa:

- **o operador K8ssandra**: o operador de Kubernetes que xestiona os clústeres de
  Cassandra
- **as imaxes de AxonOps**: imaxes de Cassandra co axente de AxonOps incorporado
- **AxonOps Cloud**: integración opcional de monitorización e xestión

### Prestacións

- Despregamento e escalado automatizados
- Actualizacións e reparacións progresivas
- Capacidades de copia de seguranza e restauración
- Integración coa monitorización de AxonOps

## Requisitos previos

1. **Un clúster de Kubernetes** (v1.21+)
   - Admite un só nodo ou varios nodos
2. **Ferramentas necesarias**:
   - `kubectl`: a CLI de Kubernetes
   - `helm`: o xestor de paquetes Helm v3.x
   - `envsubst`: substitución de variables (parte do paquete `gettext`)
3. **Almacenamento**: soporte de PersistentVolume ou o provisionador local-path
4. **Opcional**: unha conta de AxonOps para a integración da monitorización

## Instalar o operador K8ssandra

### Paso 1: engadir o repositorio de Helm

```bash
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update
```

### Paso 2: instalar o operador

```bash
# Create namespace and install operator
helm install k8ssandra-operator k8ssandra/k8ssandra-operator \
  -n k8ssandra-operator \
  --create-namespace
```

### Paso 3: verificar a instalación

```bash
# Check operator pods
kubectl get pods -n k8ssandra-operator

# Wait for operator to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=k8ssandra-operator \
  -n k8ssandra-operator \
  --timeout=300s
```

Saída esperada:

```text
NAME                                                READY   STATUS    RESTARTS   AGE
k8ssandra-operator-xxxxxxx-xxxxx                    1/1     Running   0          1m
k8ssandra-operator-cass-operator-xxxxxxx-xxxxx      1/1     Running   0          1m
```

## Configuración

### Variables de entorno

Cree ou edite `k8ssandra/k8ssandra-config.env`:

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

### Referencia das variables de configuración

| Variable | Valor por defecto | Descrición |
| --- | --- | --- |
| `K8SSANDRA_CLUSTER_NAME` | `axonops-k8ssandra` | Nome do clúster de Cassandra |
| `K8SSANDRA_NAMESPACE` | `k8ssandra-operator` | Espazo de nomes de Kubernetes |
| `CASSANDRA_VERSION` | `5.0.6` | Versión de Cassandra |
| `IMAGE_NAME` | `ghcr.io/axonops/cassandra:5.0.6` | Imaxe de Cassandra de AxonOps |
| `CASSANDRA_DC_NAME` | `dc1` | Nome do datacenter |
| `CASSANDRA_DC_SIZE` | `3` | Número de nodos de Cassandra |
| `STORAGE_CLASS` | `local-path` | StorageClass de Kubernetes |
| `STORAGE_SIZE` | `10Gi` | Almacenamento por nodo |
| `AXON_AGENT_KEY` | - | Chave de API de AxonOps |
| `AXON_AGENT_ORG` | - | Nome da organización de AxonOps |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | Nome de host do servidor de AxonOps |
| `AXON_AGENT_SERVER_PORT` | `443` | Porto do servidor de AxonOps |

## Despregamento

### Usar envsubst

Os manifestos de exemplo usan marcadores de variables de entorno. Use `envsubst`
para substituír os valores antes de aplicalos:

```bash
cd k8ssandra/

# 1. Source configuration
export $(grep -v '^#' k8ssandra-config.env | xargs)

# 2. Apply cluster manifest with variable substitution
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

### Despregamento manual

Como alternativa, edite o ficheiro YAML directamente e aplíqueo:

```bash
# Edit the manifest
vi k8ssandra/cluster-axonops-ubi.yaml

# Apply directly
kubectl apply -f k8ssandra/cluster-axonops-ubi.yaml
```

### Agardar a que o clúster estea listo

```bash
# Watch cluster status
kubectl get k8ssandraclusters -n k8ssandra-operator -w

# Check pods
kubectl get pods -n k8ssandra-operator -l cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME

# View cluster details
kubectl describe k8ssandracluster $K8SSANDRA_CLUSTER_NAME -n k8ssandra-operator
```

## Verificar o despregamento

### Comprobar o estado do clúster

```bash
# View K8ssandraCluster resource
kubectl get k8ssandraclusters -n k8ssandra-operator

# View CassandraDatacenter
kubectl get cassandradatacenters -n k8ssandra-operator

# View all pods
kubectl get pods -n k8ssandra-operator -o wide
```

### Probar a conectividade con Cassandra

```bash
# Get a shell in a Cassandra pod
kubectl exec -it ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- cqlsh

# Run a simple query
cqlsh> SELECT cluster_name, listen_address FROM system.local;
cqlsh> DESCRIBE KEYSPACES;
```

### Comprobar a integración con AxonOps

Se usa AxonOps Cloud:

```bash
# Check agent logs
kubectl logs ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator | grep -i axon

# Verify agent environment variables
kubectl exec ${K8SSANDRA_CLUSTER_NAME}-${CASSANDRA_DC_NAME}-default-sts-0 \
  -n k8ssandra-operator -- env | grep AXON
```

Despois consulte o panel de AxonOps en
[https://console.axonops.cloud](https://console.axonops.cloud) para comprobar que
o seu clúster aparece.

## Opcións de integración con AxonOps

### Opción 1: AxonOps Cloud (SaaS)

Use AxonOps Cloud para unha monitorización xestionada:

1. Déase de alta en [https://axonops.cloud](https://axonops.cloud)
2. Cree unha organización e obteña a súa chave de API
3. Configure as variables de entorno do axente en `k8ssandra-config.env`:

```bash
AXON_AGENT_KEY=your-api-key
AXON_AGENT_ORG=your-organization
AXON_AGENT_SERVER_HOST=agents.axonops.cloud
AXON_AGENT_SERVER_PORT=443
```

### Opción 2: AxonOps autoaloxado

Despregue AxonOps on-premises primeiro, e logo configure Cassandra para
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

## Escalar o clúster

### Engadir nodos

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

Reduza a escala con coidado para non perder datos:

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

### Cassandra non arranca

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

### O axente de AxonOps non conecta

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

## Limpeza

### Eliminar o clúster de Cassandra

```bash
# Delete the K8ssandraCluster
kubectl delete k8ssandracluster $K8SSANDRA_CLUSTER_NAME -n k8ssandra-operator

# Delete PVCs (WARNING: deletes all data)
kubectl delete pvc -l cassandra.datastax.com/cluster=$K8SSANDRA_CLUSTER_NAME \
  -n k8ssandra-operator
```

### Eliminar o operador K8ssandra

```bash
# Uninstall operator
helm uninstall k8ssandra-operator -n k8ssandra-operator

# Delete namespace
kubectl delete namespace k8ssandra-operator
```

## Consideracións para produción

1. **Almacenamento**: use SSD de alto rendemento con IOPS axeitadas
2. **Recursos**: asigne CPU e memoria abondas (recoméndanse 4 ou máis núcleos e
   8 GB ou máis de RAM por nodo)
3. **Replicación**: use un factor de replicación de 3 en produción
4. **Copias de seguranza**: configure Medusa para copias automatizadas
5. **Monitorización**: use AxonOps para unha monitorización e alertado completos
6. **Seguridade**: active o cifrado TLS e a autenticación
7. **Rede**: use unha rede dedicada para a comunicación entre nodos

## Recursos adicionais

- **Documentación de K8ssandra**: [https://docs.k8ssandra.io/](https://docs.k8ssandra.io/)
- **K8ssandra en GitHub**: [https://github.com/k8ssandra/k8ssandra](https://github.com/k8ssandra/k8ssandra)
- **Documentación de AxonOps**: [https://docs.axonops.com](https://docs.axonops.com)
- **Configuración do axente de AxonOps**: [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Documentación de Apache Cassandra**: [https://cassandra.apache.org/doc/](https://cassandra.apache.org/doc/)
- **Manifestos de exemplo**: [k8ssandra/](k8ssandra/)

---

**Última actualización:** 2026-02-13
