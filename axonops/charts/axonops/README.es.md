# Meta-chart de AxonOps

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

## Visión general

Este chart de Helm despliega la pila de observabilidad completa de AxonOps para
monitorizar Apache Cassandra y Kafka. Actúa como chart paraguas que orquesta el
despliegue de todos los componentes de AxonOps con valores por defecto sensatos.

### Componentes

El meta-chart despliega los siguientes componentes, en este orden:

1. **axondb-timeseries**: la base de datos de series temporales (Cassandra 5.0.6) para almacenar las métricas
2. **axondb-search**: el backend de búsqueda (OpenSearch 3.3.2) para los registros y la funcionalidad de búsqueda
3. **axon-server**: la plataforma central de observabilidad de AxonOps
4. **axon-dash**: la interfaz web del panel

Todos los subcharts están alojados en el registro OCI de AxonOps, en
`ghcr.io/axonops/charts`.

## Requisitos previos

- Kubernetes 1.19+
- Helm 3.8+
- Soporte de aprovisionador de PV en el clúster (para almacenamiento persistente)
- Recursos mínimos del clúster (con los ajustes de heap de 8G por defecto):
  - 8 núcleos de CPU
  - 40 GB de RAM (para 8G de heap en ambas bases de datos, más el margen)
  - 200 GB de almacenamiento (100 GB por base de datos)

## Instalación

### Inicio rápido

Despliegue la pila completa de AxonOps con los ajustes por defecto:

```bash
# Navigate to the chart directory
cd axonops/charts/axonops

# Update dependencies from OCI registry
helm dependency update

# Install the chart
helm install axonops . --namespace axonops --create-namespace
```

**Nota:** la configuración por defecto usa 8 GB de heap en ambas bases de datos.
Para entornos de desarrollo con recursos limitados, véase la sección
[Configuración de recursos](#configuración-de-recursos) más abajo.

### Instalación personalizada

Instale con un fichero de values propio:

```bash
# Create a custom values file
cat > custom-values.yaml <<EOF
axon-server:
  config:
    org_name: "my-organization"
    license_key: "your-license-key"
  dashboardUrl: https://axonops.mydomain.com

axondb-timeseries:
  persistence:
    size: 50Gi

axondb-search:
  persistence:
    size: 50Gi
EOF

# Install with custom values
helm install axonops . -f custom-values.yaml --namespace axonops --create-namespace
```

### Instalación en producción

Para los despliegues en producción, DEBE:

1. **Cambiar todas las contraseñas por defecto**
2. **Definir el nombre de su organización y la clave de licencia**
3. **Configurar límites de recursos adecuados**
4. **Habilitar el almacenamiento persistente con tamaños adecuados**

```bash
# Generate secure passwords
SEARCH_PASSWORD=$(openssl rand -base64 32)
CASSANDRA_PASSWORD=$(openssl rand -base64 32)

# Install with secure configuration
helm install axonops . \
  --namespace axonops \
  --create-namespace \
  --set axon-server.config.org_name="production-org" \
  --set axon-server.config.license_key="YOUR_LICENSE_KEY" \
  --set axon-server.dashboardUrl="https://axonops.yourdomain.com" \
  --set axondb-search.security.adminPassword="$SEARCH_PASSWORD" \
  --set axondb-timeseries.cassandra.auth.password="$CASSANDRA_PASSWORD" \
  --set axon-server.searchDb.password="$SEARCH_PASSWORD" \
  --set axon-server.config.extraConfig.cql_password="$CASSANDRA_PASSWORD" \
  --set axon-server.config.extraConfig.cql_username="cassandra" \
  --set axondb-timeseries.cassandra.auth.username="cassandra" \
  --set axondb-timeseries.persistence.size=200Gi \
  --set axondb-search.persistence.size=200Gi
```

## Configuración

### Parámetros de configuración principales

| Parámetro | Descripción | Valor por defecto |
|-----------|-------------|---------|
| `axondb-timeseries.enabled` | Habilita la base de datos de series temporales Cassandra | `true` |
| `axondb-search.enabled` | Habilita el backend de OpenSearch | `true` |
| `axon-server.enabled` | Habilita el servidor de AxonOps | `true` |
| `axon-dash.enabled` | Habilita la interfaz del panel | `true` |
| `axondb-timeseries.heapSize` | Tamaño del heap de la JVM de Cassandra | `8192M` |
| `axondb-search.opensearchHeapSize` | Tamaño del heap de la JVM de OpenSearch | `8g` |
| `axon-server.config.org_name` | El nombre de su organización | `example` |
| `axon-server.config.license_key` | La clave de licencia de AxonOps | `""` |
| `axon-server.dashboardUrl` | La URL pública del panel | `https://axonops.example.com` |

### Configuración de recursos

Asignación de recursos por defecto, con 8G de heap para producción:

```yaml
axondb-timeseries:
  heapSize: 8192M  # 8G heap for production
  resources:
    requests:
      memory: 9Gi    # Heap + overhead
      cpu: 1000m
    limits:
      memory: 10Gi
      cpu: 2000m

axondb-search:
  opensearchHeapSize: "8g"  # 8G heap for production
  resources:
    requests:
      memory: 9Gi    # Heap + overhead
      cpu: 1000m
    limits:
      memory: 10Gi
      cpu: 2000m

axon-server:
  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 1Gi
      cpu: 500m
```

En entornos de desarrollo y pruebas, puede reducir los tamaños de heap:

```yaml
axondb-timeseries:
  heapSize: 2048M  # 2G heap for dev/test

axondb-search:
  opensearchHeapSize: "2g"  # 2G heap for dev/test
```

### Configuración del almacenamiento

Configuración de almacenamiento por defecto (100 Gi por base de datos):

```yaml
axondb-timeseries:
  persistence:
    enabled: true
    size: 100Gi  # Default for production
    # storageClass: "fast-ssd"  # Optional: specify storage class

axondb-search:
  persistence:
    enabled: true
    size: 100Gi  # Default for production
    # storageClass: "fast-ssd"  # Optional: specify storage class
```

## Seguridad

### AVISO: credenciales por defecto

Este chart incluye contraseñas por defecto para desarrollo y pruebas. **¡No use
nunca esos valores por defecto en producción!**

Credenciales por defecto:
- Administrador de OpenSearch: `admin` / `MyS3cur3P@ss2025`
- Cassandra: `cassandra` / `cassandra`

### Cambiar las contraseñas

Defina siempre contraseñas propias en producción:

```bash
helm install axonops . \
  --set axondb-search.security.adminPassword="YOUR_SECURE_PASSWORD" \
  --set axondb-timeseries.cassandra.auth.password="YOUR_SECURE_PASSWORD" \
  --set axon-server.searchDb.password="YOUR_SECURE_PASSWORD" \
  --set axon-server.config.extraConfig.cql_password="YOUR_SECURE_PASSWORD"
```

### Usar secretos de Kubernetes para las credenciales de las bases de datos (recomendado)

En entornos de producción se recomienda guardar las credenciales de las bases de
datos en secretos de Kubernetes, en lugar de en los values de Helm. Este enfoque
ofrece más seguridad y facilita la rotación de credenciales.

#### Paso 1: crear los secretos

```bash
# Create secret for Cassandra/timeseries database credentials
kubectl create secret generic cassandra-credentials -n axonops \
  --from-literal=AXONOPS_DB_USER=axonops \
  --from-literal=AXONOPS_DB_PASSWORD=$(openssl rand -base64 32)

# Create secret for OpenSearch credentials
kubectl create secret generic opensearch-credentials -n axonops \
  --from-literal=AXONOPS_SEARCH_USER=axonops \
  --from-literal=AXONOPS_SEARCH_PASSWORD=$(openssl rand -base64 32)
```

#### Paso 2: configurar axon-server para que use los secretos

```yaml
axon-server:
  config:
    # Reference the Cassandra credentials secret
    db_secret: "cassandra-credentials"
    extraConfig:
      cql_hosts:
        - axondb-timeseries-headless.axonops.svc.cluster.local
      cql_local_dc: "datacenter1"
      # Note: cql_username and cql_password are ignored when db_secret is set

  # Reference the OpenSearch credentials secret
  searchDb:
    hosts:
      - https://axondb-search-cluster-master:9200
    search_secret: "opensearch-credentials"
    # Note: username and password are ignored when search_secret is set
```

Notas importantes:

- El secreto de Cassandra debe contener las claves `AXONOPS_DB_USER` y `AXONOPS_DB_PASSWORD`
- El secreto de OpenSearch debe contener las claves `AXONOPS_SEARCH_USER` y `AXONOPS_SEARCH_PASSWORD`
- Estos nombres de clave son compatibles con los charts axondb-timeseries y axondb-search, lo que permite compartir secretos entre charts

### Configuración de TLS

Habilite TLS en axon-server:

```yaml
axon-server:
  config:
    tls:
      mode: "TLS"  # or "mTLS" for mutual TLS
      cert: |
        -----BEGIN CERTIFICATE-----
        YOUR_CERTIFICATE_HERE
        -----END CERTIFICATE-----
      key: |
        -----BEGIN PRIVATE KEY-----
        YOUR_PRIVATE_KEY_HERE
        -----END PRIVATE KEY-----
```

## Despliegue selectivo

Puede desplegar sólo determinados componentes deshabilitando los demás:

### Desplegar sólo las bases de datos

```bash
helm install axonops-db . \
  --set axon-server.enabled=false \
  --set axon-dash.enabled=false
```

### Desplegar sin el panel

```bash
helm install axonops . \
  --set axon-dash.enabled=false
```

### Desplegar sin el backend de búsqueda

```bash
helm install axonops . \
  --set axondb-search.enabled=false
```

### Despliegue de desarrollo con menos recursos

```bash
# Deploy with 2G heap for development/testing
helm install axonops-dev . \
  --namespace axonops-dev \
  --create-namespace \
  --set axondb-timeseries.heapSize=2048M \
  --set axondb-timeseries.resources.requests.memory=3Gi \
  --set axondb-timeseries.resources.limits.memory=4Gi \
  --set axondb-search.opensearchHeapSize="2g" \
  --set axondb-search.resources.requests.memory=3Gi \
  --set axondb-search.resources.limits.memory=4Gi \
  --set axondb-timeseries.persistence.size=20Gi \
  --set axondb-search.persistence.size=20Gi
```

## Acceder a los servicios

### Acceso al panel

Tras la instalación, acceda al panel:

1. **Port-forward** (para pruebas):
```bash
kubectl port-forward -n axonops svc/axonops-axon-dash 3000:3000
# Access at http://localhost:3000
```

2. **Ingress** (para producción):
Configure el ingress en los values:
```yaml
axon-dash:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: axonops.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: axonops-tls
        hosts:
          - axonops.yourdomain.com
```

### Acceso a la API

La API de AxonOps está disponible en:
```bash
kubectl port-forward -n axonops svc/axonops-axon-server-api 8080:8080
# API at http://localhost:8080
```

### Conexión de los agentes

Los agentes de Cassandra se conectan a:

- Servicio: `axonops-axon-server-agent`
- Puerto: `1888`
- Endpoint desde fuera del clúster: configure un ingress o un LoadBalancer

## Monitorización

### Comprobar el estado de los pods

```bash
# Watch pod startup
kubectl get pods -n axonops --watch

# Check pod logs
kubectl logs -n axonops deployment/axonops-axon-server
kubectl logs -n axonops statefulset/axondb-timeseries
kubectl logs -n axonops statefulset/axondb-search-cluster-master
```

### Orden de arranque esperado

1. `axondb-timeseries-0`: debería estar Running el primero
2. `axondb-search-cluster-master-0`: debería estar Running el segundo
3. `axonops-axon-server-*`: arranca cuando las bases de datos están listas
4. `axonops-axon-dash-*`: arranca el último

### Verificar los servicios

```bash
# List all services
kubectl get svc -n axonops

# Expected services (assuming release name "axonops"):
# - axondb-timeseries
# - axondb-timeseries-headless
# - axondb-search-cluster-master
# - axondb-search-cluster-master-headless
# - axonops-axon-server-api
# - axonops-axon-server-agent
# - axonops-axon-dash
```

### Probar la conectividad

```bash
# Test OpenSearch
kubectl exec -n axonops deploy/axonops-axon-server -- \
  curl -k -u admin:MyS3cur3P@ss2025 https://axondb-search-cluster-master:9200

# Test Cassandra
kubectl exec -n axonops deploy/axonops-axon-server -- \
  nc -zv axondb-timeseries-headless 9042
```

## Resolución de problemas

### Los pods no arrancan

1. **Revise los eventos**:
```bash
kubectl describe pod -n axonops <pod-name>
```

2. **Revise los registros**:
```bash
kubectl logs -n axonops <pod-name> --previous
```

3. **Problemas habituales**:
- Recursos insuficientes: suba los límites de memoria y CPU
- Problemas de almacenamiento: revise el estado de las PVC
- Errores al descargar la imagen: revise el acceso al registro

### Problemas de conexión entre servicios

1. **Verifique la resolución DNS**:
```bash
kubectl exec -n axonops deploy/axonops-axon-server -- nslookup axondb-timeseries-headless
```

2. **Revise los endpoints de los servicios**:
```bash
kubectl get endpoints -n axonops
```

3. **Pruebe la conectividad de los puertos**:
```bash
kubectl exec -n axonops deploy/axonops-axon-server -- nc -zv axondb-search-cluster-master 9200
```

### Problemas con las bases de datos

**Cassandra no está lista**:
```bash
# Check Cassandra status
kubectl exec -n axonops axondb-timeseries-0 -- nodetool status
```

**OpenSearch no está listo**:
```bash
# Check cluster health
kubectl exec -n axonops axondb-search-cluster-master-0 -- \
  curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health?pretty
```

### Reinstalar

Si necesita reinstalar:

```bash
# Uninstall
helm uninstall axonops -n axonops

# Clean up PVCs (WARNING: This deletes data!)
kubectl delete pvc -n axonops --all

# Reinstall
helm install axonops . --namespace axonops --create-namespace
```

## Pruebas

### Validación de las versiones de las dependencias

El meta-chart incluye una validación automatizada que comprueba que las versiones
de las dependencias de `Chart.yaml` corresponden a las versiones reales de los
subcharts. Esta validación se ejecuta automáticamente en GitHub Actions en cada
push y cada pull request.

**Qué valida:**

- Que todas las versiones de dependencia del meta-chart coinciden con las versiones reales de los subcharts
- Que no hay discrepancias de versión antes de construir las dependencias
- Que el chart está listo para publicarse

**Integración con CI/CD:**

La validación se ejecuta como parte del workflow `helm-charts-test.yml`, en el job
`validate-dependency-versions`:

- ✅ Se ejecuta automáticamente en los pushes a las ramas development y feature
- ✅ Se ejecuta en las pull requests a las ramas main y development
- ✅ Puede lanzarse a mano mediante workflow_dispatch
- ✅ Ejecución rápida (unos 30 segundos)
- ✅ Hace fallar el build si las versiones no coinciden

**Qué ocurre cuando falla:**

Si se detecta una discrepancia de versión, el workflow falla con un mensaje claro
que indica:

- Qué chart tiene la discrepancia
- La versión esperada (la del subchart)
- La versión indicada en las dependencias del meta-chart
- Cómo corregirlo

## Actualización

Para actualizar el despliegue:

```bash
# Update dependencies
helm dependency update

# Upgrade release
helm upgrade axonops . -n axonops
```

## Desinstalación

Para eliminar el despliegue:

```bash
# Uninstall the chart
helm uninstall axonops -n axonops

# Optional: Remove namespace
kubectl delete namespace axonops

# Optional: Remove persistent volumes (WARNING: Data loss!)
kubectl delete pvc -n axonops --all
```

## Referencia de values

Véase [values.yaml](values.yaml) para la lista completa de opciones de
configuración, con comentarios detallados.

## Soporte

Para incidencias, preguntas o contribuciones:
- GitHub: https://github.com/axonops/axonops-containers
- Correo: info@axonops.com
- Documentación: https://axonops.com/docs

## Licencia

Copyright AxonOps. Todos los derechos reservados.
