# Guía de despliegue de AxonOps

[English](AXONOPS_DEPLOYMENT.md) | [Français](AXONOPS_DEPLOYMENT.fr.md) | **Español** | [Galego](AXONOPS_DEPLOYMENT.gl.md)

Esta guía cubre el despliegue de los servicios de monitorización y gestión de
AxonOps sobre Kubernetes.

## Inicio rápido

```bash
# Set the required passwords
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-password'

# Deploy AxonOps services
./axonops-setup.sh
```

¡Y ya está! Los servicios de AxonOps quedarán desplegados y listos para
monitorizar sus clústeres de Kafka.

---

## Visión general

AxonOps ofrece monitorización y gestión completas para clústeres de Apache Kafka.
El despliegue consta de cuatro componentes principales:

- **axon-server**: el servidor central de monitorización y gestión
- **axondb-timeseries**: la base de datos de series temporales para almacenar las
  métricas
- **axondb-search**: la base de datos de búsqueda para agregar y consultar
  registros
- **axon-dash**: el panel web de visualización

## Requisitos previos

1. **Un clúster de Kubernetes** (de uno o varios nodos)
2. **Herramientas necesarias**:
   - `kubectl`: la CLI de Kubernetes
   - `helm`: el gestor de paquetes Helm v3.x o posterior
3. **Espacio de nombres**: por defecto usa el espacio de nombres `axonops`
   (creado automáticamente)

## Configuración

### Configuración obligatoria

**CRÍTICO**: defina las contraseñas obligatorias antes de desplegar:

```bash
export AXON_SEARCH_PASSWORD='YourSecurePasswordHere'
export AXON_SERVER_CQL_PASSWORD='YourSecureCQLPasswordHere'
```

### Configuración opcional

Personalice el despliegue definiendo estas variables de entorno:

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

### Opciones de almacenamiento

AxonOps admite dos modos de almacenamiento para sus bases de datos:

#### Modo PVC (por defecto, recomendado)

Usa PersistentVolumeClaims dinámicos con la clase de almacenamiento por defecto
de su clúster, o la que indique:

```bash
# Use default storage class
./axonops-setup.sh

# Or specify storage sizes
export AXON_TIMESERIES_VOLUME_SIZE="50Gi"
export AXON_SEARCH_VOLUME_SIZE="20Gi"
./axonops-setup.sh
```

**Ventajas:**
- Funciona con cualquier proveedor de almacenamiento
- Apto para entornos de producción
- Admite clústeres de varios nodos
- Gestión automática de los volúmenes

#### Modo hostPath (sólo para pruebas en un solo nodo)

Usa directorios locales del nodo de Kubernetes:

```bash
export AXON_SEARCH_USE_HOSTPATH="true"
export AXON_TIMESERIES_USE_HOSTPATH="true"
./axonops-setup.sh
```

**Limitaciones:**
- Requiere un clúster de un solo nodo
- No es apto para producción
- Hay que crear los directorios a mano

Si usa el modo hostPath, cree los directorios en el nodo:

```bash
# On the Kubernetes node
sudo mkdir -p /data/axon-timeseries /data/axon-search
sudo chown -R 999:999 /data/axon-timeseries /data/axon-search
sudo chmod -R 755 /data/axon-timeseries /data/axon-search
```

## Pasos del despliegue

### Paso 1: definir las contraseñas obligatorias

```bash
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
```

### Paso 2: (opcional) personalizar la configuración

```bash
# Example: Change namespace
export NS_AXONOPS="monitoring"

# Example: Use larger storage
export AXON_TIMESERIES_VOLUME_SIZE="100Gi"
export AXON_SEARCH_VOLUME_SIZE="50Gi"
```

### Paso 3: ejecutar el script de despliegue

```bash
chmod +x axonops-setup.sh
./axonops-setup.sh
```

El script:
1. Instala cert-manager (si no está ya instalado)
2. Despliega la base de datos AxonDB Timeseries
3. Despliega la base de datos AxonDB Search
4. Despliega el servidor de AxonOps
5. Despliega el panel de AxonOps
6. Crea `axonops-config.env` con los datos de conexión

### Paso 4: esperar a que los servicios estén listos

```bash
# Check pod status
kubectl get pods -n axonops

# Wait for all pods to be Running
kubectl wait --for=condition=ready pod --all -n axonops --timeout=300s
```

## Acceder al panel de AxonOps

### Opción 1: port-forward (acceso rápido)

```bash
kubectl port-forward -n axonops svc/axon-dash 3000:3000

# Access at: http://localhost:3000
```

### Opción 2: NodePort (acceso externo)

Active NodePort durante el despliegue:

```bash
export AXON_DASH_NODEPORT_ENABLED="true"
export AXON_DASH_NODEPORT_PORT="32000"
./axonops-setup.sh

# Access at: http://<node-ip>:32000
```

### Opción 3: Ingress (producción)

Active Ingress durante el despliegue:

```bash
export AXON_DASH_INGRESS_ENABLED="true"
export AXON_DASH_INGRESS_HOST="axonops.yourdomain.com"
./axonops-setup.sh

# Access at: https://axonops.yourdomain.com
```

**Nota:** requiere un controlador de Ingress instalado en su clúster.

## Integración con Kafka

Tras desplegar AxonOps, puede conectarlo con sus clústeres de Kafka:

### Para despliegues nuevos de Strimzi

```bash
# Source the AxonOps configuration
source axonops-config.env

# Deploy Strimzi with AxonOps integration
./strimzi-setup.sh
```

Consulte [STRIMZI_DEPLOYMENT.es.md](STRIMZI_DEPLOYMENT.es.md) para los detalles.

### Para clústeres de Kafka existentes

Configure el agente de AxonOps en sus brokers de Kafka con los datos de conexión
de `axonops-config.env`:

```bash
# Agent connection details
AXON_AGENT_SERVER_HOST=axon-server-agent.axonops.svc.cluster.local
AXON_AGENT_SERVER_PORT=1888
```

## Verificar el despliegue

### Comprobar el estado de los componentes

```bash
# View all AxonOps pods
kubectl get pods -n axonops

# View all services
kubectl get svc -n axonops

# Check Helm releases
helm list -n axonops
```

Salida esperada:
- 4 releases de Helm: `axon-server`, `axondb-timeseries`, `axondb-search`,
  `axon-dash`
- Todos los pods en estado Running
- Servicios con endpoints ClusterIP

### Consultar los registros

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

### Probar el acceso al panel

```bash
# Port-forward and open browser
kubectl port-forward -n axonops svc/axon-dash 3000:3000

# In another terminal or browser, navigate to:
# http://localhost:3000
```

## Resolución de problemas

### Pods atascados en estado Pending

**Revise las PersistentVolumeClaims:**

```bash
kubectl get pvc -n axonops
```

**Causas posibles:**
- No hay ninguna clase de almacenamiento disponible
- Capacidad de almacenamiento insuficiente
- En modo hostPath: los directorios no se han creado o tienen permisos
  incorrectos

**Soluciones:**

```bash
# Check available storage classes
kubectl get storageclass

# For hostPath mode, verify directories exist
ssh <node> "ls -la /data/axon-timeseries /data/axon-search"

# Check pod events
kubectl describe pod <pod-name> -n axonops
```

### Problemas de conexión con la base de datos de búsqueda

**Síntoma:** el servidor de AxonOps no puede conectarse a la base de datos de
búsqueda.

**Revise la configuración de contraseñas:**

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

### El panel no es accesible

**Compruebe el tipo de servicio:**

```bash
kubectl get svc axon-dash -n axonops
```

**Si usa NodePort, verifique que el puerto es accesible:**

```bash
# Check firewall rules
# Ensure node port is open in security groups/firewall

# Test connectivity
curl http://<node-ip>:<nodeport>
```

**Si usa Ingress, verifique la configuración del Ingress:**

```bash
kubectl get ingress -n axonops
kubectl describe ingress axon-dash -n axonops
```

### Problemas con los certificados

**Compruebe el estado de cert-manager:**

```bash
kubectl get pods -n cert-manager
kubectl get clusterissuer
```

**Consulte el estado de los certificados:**

```bash
kubectl get certificate -n axonops
kubectl describe certificate -n axonops
```

## Referencia de configuración

### Fichero de configuración generado

Tras el despliegue se crea `axonops-config.env` con estas variables:

```bash
NS_AXONOPS=axonops
AXON_SERVER_AGENTS_PORT=1888
AXON_SERVER_API_PORT=8080
AXON_SERVER_ORG_NAME=example
```

Cargue este fichero antes de desplegar Kafka para habilitar la integración
automática.

### Versiones de los charts de Helm

El script usa versiones concretas de los charts:

- **axondb-timeseries**: la última del repositorio de AxonOps
- **axondb-search**: la última del repositorio de AxonOps
- **axon-server**: la última del repositorio de AxonOps
- **axon-dash**: la última del repositorio de AxonOps

## Limpieza

### Eliminar los servicios de AxonOps

```bash
# Uninstall Helm releases
helm uninstall -n axonops axon-dash
helm uninstall -n axonops axon-server
helm uninstall -n axonops axondb-search
helm uninstall -n axonops axondb-timeseries

# Delete namespace
kubectl delete namespace axonops
```

### Eliminar los datos (ATENCIÓN: borra todos los datos)

Para almacenamiento hostPath:

```bash
# On the Kubernetes node
sudo rm -rf /data/axon-timeseries
sudo rm -rf /data/axon-search
```

Para almacenamiento PVC, borre las PVC:

```bash
kubectl delete pvc -n axonops --all
```

### Eliminar cert-manager (opcional)

Sólo si no lo usan otros servicios:

```bash
helm uninstall -n cert-manager cert-manager
kubectl delete namespace cert-manager
```

## Consideraciones para producción

Para despliegues en producción:

1. **Almacenamiento**: use almacenamiento distribuido con copias de seguridad y
   recuperación ante desastres adecuadas
2. **Alta disponibilidad**: valore desplegar varias réplicas (requiere
   personalizar los charts de Helm)
3. **Seguridad**:
   - Use contraseñas fuertes
   - Active TLS en todos los componentes
   - Configure un RBAC adecuado
   - Use network policies
4. **Monitorización**: monitorice los propios componentes de AxonOps
5. **Límites de recursos**: fije límites de CPU y memoria adecuados
6. **Copias de seguridad**: haga copias periódicas de las bases de datos de
   búsqueda y de series temporales
7. **Control de acceso**: use Ingress con autenticación y autorización

## Configuraciones de ejemplo

Hay configuraciones listas para usar en el directorio [axonops/](axonops/):

- `axonops-config.env`: variables de entorno
- `axonops-setup.sh`: script de despliegue automatizado
- `axonops-server-secret.yaml`: ejemplo de configuración del servidor
- Ficheros de values de Helm para cada componente

## Recursos adicionales

- **Documentación de AxonOps**: [https://docs.axonops.com](https://docs.axonops.com)
- **Configuración del agente de AxonOps**: [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Integración con Strimzi Kafka**: [STRIMZI_DEPLOYMENT.es.md](STRIMZI_DEPLOYMENT.es.md)
- **Integración con K8ssandra Cassandra**: [K8SSANDRA_DEPLOYMENT.es.md](K8SSANDRA_DEPLOYMENT.es.md)
- **Ejemplos de Strimzi para cloud**: [strimzi/cloud/](strimzi/cloud/), manifiestos de Kubernetes listos para usar
- **Ejemplos de K8ssandra**: [k8ssandra/](k8ssandra/), ejemplos de clúster de Cassandra
- **Charts de Helm**: el repositorio de Helm de AxonOps
- **Soporte**: contacte con el soporte de AxonOps para despliegues en producción

---

**Última actualización:** 2026-02-13
