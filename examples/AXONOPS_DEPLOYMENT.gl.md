# Guía de despregamento de AxonOps

[English](AXONOPS_DEPLOYMENT.md) | [Français](AXONOPS_DEPLOYMENT.fr.md) | [Español](AXONOPS_DEPLOYMENT.es.md) | **Galego**

Esta guía cobre o despregamento dos servizos de monitorización e xestión de
AxonOps sobre Kubernetes.

## Inicio rápido

```bash
# Set the required passwords
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-password'

# Deploy AxonOps services
./axonops-setup.sh
```

E xa está! Os servizos de AxonOps quedarán despregados e listos para monitorizar
os seus clústeres de Kafka.

---

## Visión xeral

AxonOps ofrece monitorización e xestión completas para clústeres de Apache Kafka.
O despregamento consta de catro compoñentes principais:

- **axon-server**: o servidor central de monitorización e xestión
- **axondb-timeseries**: a base de datos de series temporais para almacenar as
  métricas
- **axondb-search**: a base de datos de busca para agregar e consultar rexistros
- **axon-dash**: o panel web de visualización

## Requisitos previos

1. **Un clúster de Kubernetes** (dun ou varios nodos)
2. **Ferramentas necesarias**:
   - `kubectl`: a CLI de Kubernetes
   - `helm`: o xestor de paquetes Helm v3.x ou posterior
3. **Espazo de nomes**: por defecto usa o espazo de nomes `axonops` (creado
   automaticamente)

## Configuración

### Configuración obrigatoria

**CRÍTICO**: defina os contrasinais obrigatorios antes de despregar:

```bash
export AXON_SEARCH_PASSWORD='YourSecurePasswordHere'
export AXON_SERVER_CQL_PASSWORD='YourSecureCQLPasswordHere'
```

### Configuración opcional

Personalice o despregamento definindo estas variables de entorno:

```bash
# Namespace
export NS_AXONOPS="axonops"           # Default namespace for AxonOps

# AxonOps Server configuration
export AXON_SERVER_AGENTS_PORT="1888"       # Port for Kafka agents (default: 1888)
export AXON_SERVER_API_PORT="8080"          # API port (default: 8080)

# Storage configuration
export AXON_SEARCH_USE_HOSTPATH="false"     # Use hostPath for Search DB (default: false)
export AXON_TIMESERIES_USE_HOSTPATH="false" # Use hostPath for Timeseries DB (default: false)

# Storage sizes (for PVC mode)
export AXON_TIMESERIES_VOLUME_SIZE="10Gi"   # Timeseries DB storage
export AXON_SEARCH_VOLUME_SIZE="10Gi"       # Search DB storage

# Dashboard access
export AXON_DASH_INGRESS_ENABLED="false"    # Enable Ingress (default: false)
export AXON_DASH_INGRESS_HOST=""            # Ingress hostname
export AXON_DASH_NODEPORT_ENABLED="false"   # Enable NodePort (default: false)
export AXON_DASH_NODEPORT_PORT=""           # NodePort port number

export AXON_SEARCH_USER=admin
export AXON_SEARCH_PASSWORD=secure-password-here-5o02GzIn+58JbgU437WI8QksSHE
export AXON_SERVER_CQL_USERNAME=axonops
export AXON_SERVER_CQL_PASSWORD=secure-password-here-4kaZo3tLV3zuBRsLN2Xtudn1qwc
```

### Opcións de almacenamento

AxonOps admite dous modos de almacenamento para as súas bases de datos:

#### Modo PVC (por defecto, recomendado)

Usa PersistentVolumeClaims dinámicos coa clase de almacenamento por defecto do
seu clúster, ou a que indique:

```bash
# Use default storage class
./axonops-setup.sh

# Or specify storage sizes
export AXON_TIMESERIES_VOLUME_SIZE="50Gi"
export AXON_SEARCH_VOLUME_SIZE="20Gi"
./axonops-setup.sh
```

**Vantaxes:**
- Funciona con calquera provedor de almacenamento
- Apto para entornos de produción
- Admite clústeres de varios nodos
- Xestión automática dos volumes

#### Modo hostPath (só para probas nun só nodo)

Usa directorios locais do nodo de Kubernetes:

```bash
export AXON_SEARCH_USE_HOSTPATH="true"
export AXON_TIMESERIES_USE_HOSTPATH="true"
./axonops-setup.sh
```

**Limitacións:**
- Require un clúster dun só nodo
- Non é apto para produción
- Hai que crear os directorios a man

Se usa o modo hostPath, cree os directorios no nodo:

```bash
# On the Kubernetes node
sudo mkdir -p /data/axon-timeseries /data/axon-search
sudo chown -R 999:999 /data/axon-timeseries /data/axon-search
sudo chmod -R 755 /data/axon-timeseries /data/axon-search
```

## Pasos do despregamento

### Paso 1: definir os contrasinais obrigatorios

```bash
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
```

### Paso 2: (opcional) personalizar a configuración

```bash
# Example: Change namespace
export NS_AXONOPS="monitoring"

# Example: Use larger storage
export AXON_TIMESERIES_VOLUME_SIZE="100Gi"
export AXON_SEARCH_VOLUME_SIZE="50Gi"
```

### Paso 3: executar o script de despregamento

```bash
chmod +x axonops-setup.sh
./axonops-setup.sh
```

O script:
1. Instala cert-manager (se non está xa instalado)
2. Desprega a base de datos AxonDB Timeseries
3. Desprega a base de datos AxonDB Search
4. Desprega o servidor de AxonOps
5. Desprega o panel de AxonOps
6. Crea `axonops-config.env` cos datos de conexión

### Paso 4: agardar a que os servizos estean listos

```bash
# Check pod status
kubectl get pods -n axonops

# Wait for all pods to be Running
kubectl wait --for=condition=ready pod --all -n axonops --timeout=300s
```

## Acceder ao panel de AxonOps

### Opción 1: port-forward (acceso rápido)

```bash
kubectl port-forward -n axonops svc/axon-dash 3000:3000

# Access at: http://localhost:3000
```

### Opción 2: NodePort (acceso externo)

Active NodePort durante o despregamento:

```bash
export AXON_DASH_NODEPORT_ENABLED="true"
export AXON_DASH_NODEPORT_PORT="32000"
./axonops-setup.sh

# Access at: http://<node-ip>:32000
```

### Opción 3: Ingress (produción)

Active Ingress durante o despregamento:

```bash
export AXON_DASH_INGRESS_ENABLED="true"
export AXON_DASH_INGRESS_HOST="axonops.yourdomain.com"
./axonops-setup.sh

# Access at: https://axonops.yourdomain.com
```

**Nota:** require un controlador de Ingress instalado no seu clúster.

## Integración con Kafka

Tras despregar AxonOps, pode conectalo cos seus clústeres de Kafka:

### Para despregamentos novos de Strimzi

```bash
# Source the AxonOps configuration
source axonops-config.env

# Deploy Strimzi with AxonOps integration
./strimzi-setup.sh
```

Consulte [STRIMZI_DEPLOYMENT.gl.md](STRIMZI_DEPLOYMENT.gl.md) para os detalles.

### Para clústeres de Kafka existentes

Configure o axente de AxonOps nos seus brokers de Kafka cos datos de conexión de
`axonops-config.env`:

```bash
# Agent connection details
AXON_AGENT_SERVER_HOST=axon-server-agent.axonops.svc.cluster.local
AXON_AGENT_SERVER_PORT=1888
```

## Verificar o despregamento

### Comprobar o estado dos compoñentes

```bash
# View all AxonOps pods
kubectl get pods -n axonops

# View all services
kubectl get svc -n axonops

# Check Helm releases
helm list -n axonops
```

Saída esperada:
- 4 releases de Helm: `axon-server`, `axondb-timeseries`, `axondb-search`,
  `axon-dash`
- Todos os pods en estado Running
- Servizos con endpoints ClusterIP

### Consultar os rexistros

```bash
# AxonOps Server logs
kubectl logs -n axonops deployment/axon-server -f

# Dashboard logs
kubectl logs -n axonops deployment/axon-dash -f

# Timeseries DB logs
kubectl logs -n axonops statefulset/axondb-timeseries -f

# Search DB logs
kubectl logs -n axonops statefulset/axondb-search -f
```

### Probar o acceso ao panel

```bash
# Port-forward and open browser
kubectl port-forward -n axonops svc/axon-dash 3000:3000

# In another terminal or browser, navigate to:
# http://localhost:3000
```

## Resolución de problemas

### Pods atascados en estado Pending

**Revise as PersistentVolumeClaims:**

```bash
kubectl get pvc -n axonops
```

**Causas posibles:**
- Non hai ningunha clase de almacenamento dispoñible
- Capacidade de almacenamento insuficiente
- En modo hostPath: os directorios non se crearon ou teñen permisos incorrectos

**Solucións:**

```bash
# Check available storage classes
kubectl get storageclass

# For hostPath mode, verify directories exist
ssh <node> "ls -la /data/axon-timeseries /data/axon-search"

# Check pod events
kubectl describe pod <pod-name> -n axonops
```

### Problemas de conexión coa base de datos de busca

**Síntoma:** o servidor de AxonOps non pode conectarse á base de datos de busca.

**Revise a configuración de contrasinais:**

```bash
# Verify secret exists
kubectl get secret axon-server-config -n axonops

# Check server configuration
kubectl get secret axon-server-config -n axonops -o jsonpath='{.data.axon-server\.yml}' | base64 -d
```

**Solución:**

```bash
# Recreate the secret with correct password
kubectl delete secret axon-server-config -n axonops
export AXON_SEARCH_PASSWORD='your-password'
export AXON_SERVER_CQL_PASSWORD='your-cql-password'
./axonops-setup.sh
```

### O panel non é accesible

**Comprobe o tipo de servizo:**

```bash
kubectl get svc axon-dash -n axonops
```

**Se usa NodePort, verifique que o porto é accesible:**

```bash
# Check firewall rules
# Ensure node port is open in security groups/firewall

# Test connectivity
curl http://<node-ip>:<nodeport>
```

**Se usa Ingress, verifique a configuración do Ingress:**

```bash
kubectl get ingress -n axonops
kubectl describe ingress axon-dash -n axonops
```

### Problemas cos certificados

**Comprobe o estado de cert-manager:**

```bash
kubectl get pods -n cert-manager
kubectl get clusterissuer
```

**Consulte o estado dos certificados:**

```bash
kubectl get certificate -n axonops
kubectl describe certificate -n axonops
```

## Referencia de configuración

### Ficheiro de configuración xerado

Tras o despregamento créase `axonops-config.env` con estas variables:

```bash
NS_AXONOPS=axonops
AXON_SERVER_AGENTS_PORT=1888
AXON_SERVER_API_PORT=8080
AXON_SERVER_ORG_NAME=example
```

Cargue este ficheiro antes de despregar Kafka para habilitar a integración
automática.

### Versións dos charts de Helm

O script usa versións concretas dos charts:

- **axondb-timeseries**: a última do repositorio de AxonOps
- **axondb-search**: a última do repositorio de AxonOps
- **axon-server**: a última do repositorio de AxonOps
- **axon-dash**: a última do repositorio de AxonOps

## Limpeza

### Eliminar os servizos de AxonOps

```bash
# Uninstall Helm releases
helm uninstall -n axonops axon-dash
helm uninstall -n axonops axon-server
helm uninstall -n axonops axondb-search
helm uninstall -n axonops axondb-timeseries

# Delete namespace
kubectl delete namespace axonops
```

### Eliminar os datos (ATENCIÓN: borra todos os datos)

Para almacenamento hostPath:

```bash
# On the Kubernetes node
sudo rm -rf /data/axon-timeseries
sudo rm -rf /data/axon-search
```

Para almacenamento PVC, borre as PVC:

```bash
kubectl delete pvc -n axonops --all
```

### Eliminar cert-manager (opcional)

Só se non o usan outros servizos:

```bash
helm uninstall -n cert-manager cert-manager
kubectl delete namespace cert-manager
```

## Consideracións para produción

Para despregamentos en produción:

1. **Almacenamento**: use almacenamento distribuído con copias de seguranza e
   recuperación ante desastres axeitadas
2. **Alta dispoñibilidade**: valore despregar varias réplicas (require
   personalizar os charts de Helm)
3. **Seguridade**:
   - Use contrasinais fortes
   - Active TLS en todos os compoñentes
   - Configure un RBAC axeitado
   - Use network policies
4. **Monitorización**: monitorice os propios compoñentes de AxonOps
5. **Límites de recursos**: fixe límites de CPU e memoria axeitados
6. **Copias de seguranza**: faga copias periódicas das bases de datos de busca e
   de series temporais
7. **Control de acceso**: use Ingress con autenticación e autorización

## Configuracións de exemplo

Hai configuracións listas para usar no directorio [axonops/](axonops/):

- `axonops-config.env`: variables de entorno
- `axonops-setup.sh`: script de despregamento automatizado
- `axonops-server-secret.yaml`: exemplo de configuración do servidor
- Ficheiros de values de Helm para cada compoñente

## Recursos adicionais

- **Documentación de AxonOps**: [https://docs.axonops.com](https://docs.axonops.com)
- **Configuración do axente de AxonOps**: [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Integración con Strimzi Kafka**: [STRIMZI_DEPLOYMENT.gl.md](STRIMZI_DEPLOYMENT.gl.md)
- **Integración con K8ssandra Cassandra**: [K8SSANDRA_DEPLOYMENT.gl.md](K8SSANDRA_DEPLOYMENT.gl.md)
- **Exemplos de Strimzi para cloud**: [strimzi/cloud/](strimzi/cloud/), manifestos de Kubernetes listos para usar
- **Exemplos de K8ssandra**: [k8ssandra/](k8ssandra/), exemplos de clúster de Cassandra
- **Charts de Helm**: o repositorio de Helm de AxonOps
- **Soporte**: contacte co soporte de AxonOps para despregamentos en produción

---

**Última actualización:** 2026-02-13
