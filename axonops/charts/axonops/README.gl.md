# Meta-chart de AxonOps

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

## Visión xeral

Este chart de Helm desprega a pila de observabilidade completa de AxonOps para
monitorizar Apache Cassandra e Kafka. Actúa como chart paraugas que orquestra o
despregamento de todos os compoñentes de AxonOps con valores por defecto
sensatos.

### Compoñentes

O meta-chart desprega os seguintes compoñentes, nesta orde:

1. **axondb-timeseries**: a base de datos de series temporais (Cassandra 5.0.6) para almacenar as métricas
2. **axondb-search**: o backend de busca (OpenSearch 3.3.2) para os rexistros e a funcionalidade de busca
3. **axon-server**: a plataforma central de observabilidade de AxonOps
4. **axon-dash**: a interface web do panel

Todos os subcharts están aloxados no rexistro OCI de AxonOps, en
`ghcr.io/axonops/charts`.

## Requisitos previos

- Kubernetes 1.19+
- Helm 3.8+
- Soporte de aprovisionador de PV no clúster (para almacenamento persistente)
- Recursos mínimos do clúster (cos axustes de heap de 8G por defecto):
  - 8 núcleos de CPU
  - 40 GB de RAM (para 8G de heap nas dúas bases de datos, máis a marxe)
  - 200 GB de almacenamento (100 GB por base de datos)

## Instalación

### Inicio rápido

Despregue a pila completa de AxonOps cos axustes por defecto:

```bash
# Navigate to the chart directory
cd axonops/charts/axonops

# Update dependencies from OCI registry
helm dependency update

# Install the chart
helm install axonops . --namespace axonops --create-namespace
```

**Nota:** a configuración por defecto usa 8 GB de heap nas dúas bases de datos.
Para entornos de desenvolvemento con recursos limitados, véxase a sección
[Configuración de recursos](#configuración-de-recursos) máis abaixo.

### Instalación personalizada

Instale cun ficheiro de values propio:

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

### Instalación en produción

Para os despregamentos en produción, DEBE:

1. **Cambiar todos os contrasinais por defecto**
2. **Definir o nome da súa organización e a chave de licenza**
3. **Configurar límites de recursos axeitados**
4. **Habilitar o almacenamento persistente con tamaños axeitados**

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

### Parámetros de configuración principais

| Parámetro | Descrición | Valor por defecto |
|-----------|-------------|---------|
| `axondb-timeseries.enabled` | Habilita a base de datos de series temporais Cassandra | `true` |
| `axondb-search.enabled` | Habilita o backend de OpenSearch | `true` |
| `axon-server.enabled` | Habilita o servidor de AxonOps | `true` |
| `axon-dash.enabled` | Habilita a interface do panel | `true` |
| `axondb-timeseries.heapSize` | Tamaño do heap da JVM de Cassandra | `8192M` |
| `axondb-search.opensearchHeapSize` | Tamaño do heap da JVM de OpenSearch | `8g` |
| `axon-server.config.org_name` | O nome da súa organización | `example` |
| `axon-server.config.license_key` | A chave de licenza de AxonOps | `""` |
| `axon-server.dashboardUrl` | A URL pública do panel | `https://axonops.example.com` |

### Configuración de recursos

Asignación de recursos por defecto, con 8G de heap para produción:

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

En entornos de desenvolvemento e probas, pode reducir os tamaños de heap:

```yaml
axondb-timeseries:
  heapSize: 2048M  # 2G heap for dev/test

axondb-search:
  opensearchHeapSize: "2g"  # 2G heap for dev/test
```

### Configuración do almacenamento

Configuración de almacenamento por defecto (100 Gi por base de datos):

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

## Seguridade

### AVISO: credenciais por defecto

Este chart inclúe contrasinais por defecto para desenvolvemento e probas. **Non
use nunca eses valores por defecto en produción!**

Credenciais por defecto:
- Administrador de OpenSearch: `admin` / `MyS3cur3P@ss2025`
- Cassandra: `cassandra` / `cassandra`

### Cambiar os contrasinais

Defina sempre contrasinais propios en produción:

```bash
helm install axonops . \
  --set axondb-search.security.adminPassword="YOUR_SECURE_PASSWORD" \
  --set axondb-timeseries.cassandra.auth.password="YOUR_SECURE_PASSWORD" \
  --set axon-server.searchDb.password="YOUR_SECURE_PASSWORD" \
  --set axon-server.config.extraConfig.cql_password="YOUR_SECURE_PASSWORD"
```

### Usar segredos de Kubernetes para as credenciais das bases de datos (recomendado)

En entornos de produción recoméndase gardar as credenciais das bases de datos en
segredos de Kubernetes, no canto de nos values de Helm. Este enfoque ofrece máis
seguridade e facilita a rotación de credenciais.

#### Paso 1: crear os segredos

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

#### Paso 2: configurar axon-server para que use os segredos

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

- O segredo de Cassandra debe conter as chaves `AXONOPS_DB_USER` e `AXONOPS_DB_PASSWORD`
- O segredo de OpenSearch debe conter as chaves `AXONOPS_SEARCH_USER` e `AXONOPS_SEARCH_PASSWORD`
- Estes nomes de chave son compatibles cos charts axondb-timeseries e axondb-search, o que permite compartir segredos entre charts

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

## Despregamento selectivo

Pode despregar só determinados compoñentes deshabilitando os demais:

### Despregar só as bases de datos

```bash
helm install axonops-db . \
  --set axon-server.enabled=false \
  --set axon-dash.enabled=false
```

### Despregar sen o panel

```bash
helm install axonops . \
  --set axon-dash.enabled=false
```

### Despregar sen o backend de busca

```bash
helm install axonops . \
  --set axondb-search.enabled=false
```

### Despregamento de desenvolvemento con menos recursos

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

## Acceder aos servizos

### Acceso ao panel

Tras a instalación, acceda ao panel:

1. **Port-forward** (para probas):
```bash
kubectl port-forward -n axonops svc/axonops-axon-dash 3000:3000
# Access at http://localhost:3000
```

2. **Ingress** (para produción):
Configure o ingress nos values:
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

### Acceso á API

A API de AxonOps está dispoñible en:
```bash
kubectl port-forward -n axonops svc/axonops-axon-server-api 8080:8080
# API at http://localhost:8080
```

### Conexión dos axentes

Os axentes de Cassandra conéctanse a:

- Servizo: `axonops-axon-server-agent`
- Porto: `1888`
- Endpoint dende fóra do clúster: configure un ingress ou un LoadBalancer

## Monitorización

### Comprobar o estado dos pods

```bash
# Watch pod startup
kubectl get pods -n axonops --watch

# Check pod logs
kubectl logs -n axonops deployment/axonops-axon-server
kubectl logs -n axonops statefulset/axondb-timeseries
kubectl logs -n axonops statefulset/axondb-search-cluster-master
```

### Orde de arranque esperada

1. `axondb-timeseries-0`: debería estar Running o primeiro
2. `axondb-search-cluster-master-0`: debería estar Running o segundo
3. `axonops-axon-server-*`: arranca cando as bases de datos están listas
4. `axonops-axon-dash-*`: arranca o último

### Verificar os servizos

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

### Probar a conectividade

```bash
# Test OpenSearch
kubectl exec -n axonops deploy/axonops-axon-server -- \
  curl -k -u admin:MyS3cur3P@ss2025 https://axondb-search-cluster-master:9200

# Test Cassandra
kubectl exec -n axonops deploy/axonops-axon-server -- \
  nc -zv axondb-timeseries-headless 9042
```

## Resolución de problemas

### Os pods non arrancan

1. **Revise os eventos**:
```bash
kubectl describe pod -n axonops <pod-name>
```

2. **Revise os rexistros**:
```bash
kubectl logs -n axonops <pod-name> --previous
```

3. **Problemas habituais**:
- Recursos insuficientes: suba os límites de memoria e CPU
- Problemas de almacenamento: revise o estado das PVC
- Erros ao descargar a imaxe: revise o acceso ao rexistro

### Problemas de conexión entre servizos

1. **Verifique a resolución DNS**:
```bash
kubectl exec -n axonops deploy/axonops-axon-server -- nslookup axondb-timeseries-headless
```

2. **Revise os endpoints dos servizos**:
```bash
kubectl get endpoints -n axonops
```

3. **Probe a conectividade dos portos**:
```bash
kubectl exec -n axonops deploy/axonops-axon-server -- nc -zv axondb-search-cluster-master 9200
```

### Problemas coas bases de datos

**Cassandra non está lista**:
```bash
# Check Cassandra status
kubectl exec -n axonops axondb-timeseries-0 -- nodetool status
```

**OpenSearch non está listo**:
```bash
# Check cluster health
kubectl exec -n axonops axondb-search-cluster-master-0 -- \
  curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health?pretty
```

### Reinstalar

Se precisa reinstalar:

```bash
# Uninstall
helm uninstall axonops -n axonops

# Clean up PVCs (WARNING: This deletes data!)
kubectl delete pvc -n axonops --all

# Reinstall
helm install axonops . --namespace axonops --create-namespace
```

## Probas

### Validación das versións das dependencias

O meta-chart inclúe unha validación automatizada que comproba que as versións das
dependencias de `Chart.yaml` corresponden ás versións reais dos subcharts. Esta
validación execútase automaticamente en GitHub Actions en cada push e cada pull
request.

**Que valida:**

- Que todas as versións de dependencia do meta-chart coinciden coas versións reais dos subcharts
- Que non hai discrepancias de versión antes de construír as dependencias
- Que o chart está listo para publicarse

**Integración con CI/CD:**

A validación execútase como parte do workflow `helm-charts-test.yml`, no job
`validate-dependency-versions`:

- ✅ Execútase automaticamente nos pushes ás ramas development e feature
- ✅ Execútase nas pull requests ás ramas main e development
- ✅ Pode lanzarse a man mediante workflow_dispatch
- ✅ Execución rápida (uns 30 segundos)
- ✅ Fai fallar o build se as versións non coinciden

**Que ocorre cando falla:**

Se se detecta unha discrepancia de versión, o workflow falla cunha mensaxe clara
que indica:

- Que chart ten a discrepancia
- A versión agardada (a do subchart)
- A versión indicada nas dependencias do meta-chart
- Como corrixilo

## Actualización

Para actualizar o despregamento:

```bash
# Update dependencies
helm dependency update

# Upgrade release
helm upgrade axonops . -n axonops
```

## Desinstalación

Para eliminar o despregamento:

```bash
# Uninstall the chart
helm uninstall axonops -n axonops

# Optional: Remove namespace
kubectl delete namespace axonops

# Optional: Remove persistent volumes (WARNING: Data loss!)
kubectl delete pvc -n axonops --all
```

## Referencia de values

Véxase [values.yaml](values.yaml) para a lista completa de opcións de
configuración, con comentarios detallados.

## Soporte

Para incidencias, preguntas ou contribucións:
- GitHub: https://github.com/axonops/axonops-containers
- Correo: info@axonops.com
- Documentación: https://axonops.com/docs

## Licenza

Copyright AxonOps. Todos os dereitos reservados.
