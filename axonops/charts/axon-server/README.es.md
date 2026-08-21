# Servidor de AxonOps

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

![Versión: 2.1.3](https://img.shields.io/badge/Version-2.1.3-informational?style=flat-square) ![Tipo: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

Un chart de Helm para desplegar el servidor de AxonOps, la plataforma de
observabilidad unificada para Apache Cassandra. El servidor de AxonOps es el
componente central que recoge las métricas y los registros de los clústeres de
Cassandra, los almacena en las bases de datos de series temporales y de búsqueda,
y ofrece las API para el panel de AxonOps.

**Página del proyecto:** <https://axonops.com>

## Índice

- [Visión general de la arquitectura](#visión-general-de-la-arquitectura)
- [Requisitos previos](#requisitos-previos)
- [Inicio rápido](#inicio-rápido)
- [Ejemplos de instalación](#ejemplos-de-instalación)
  - [Instalación básica](#instalación-básica)
  - [Instalación con bases de datos externas](#instalación-con-bases-de-datos-externas)
  - [Instalación con las credenciales de base de datos en secretos](#instalación-con-las-credenciales-de-base-de-datos-en-secretos)
  - [Instalación con un secreto de configuración externo](#instalación-con-un-secreto-de-configuración-externo)
  - [Instalación con Ingress](#instalación-con-ingress)
  - [Instalación con TLS/mTLS](#instalación-con-tlsmtls)
  - [Instalación con autenticación LDAP](#instalación-con-autenticación-ldap)
  - [Instalación lista para producción](#instalación-lista-para-producción)
- [Configuración](#configuración)
- [Actualización](#actualización)
- [Desinstalación](#desinstalación)
- [Resolución de problemas](#resolución-de-problemas)

## Visión general de la arquitectura

El servidor de AxonOps es el componente central de la plataforma AxonOps:

```
┌─────────────────┐         ┌──────────────────┐
│  AxonOps Agents │────────>│  AxonOps Server  │
│  (on Cassandra) │  :1888  │                  │
└─────────────────┘         │  - Metrics API   │
                            │  - Agent Listener│
┌─────────────────┐  :8080  │  - Data Pipeline │
│ AxonOps Dashboard│<───────┤                  │
└─────────────────┘         └──────────────────┘
                                   │     │
                   ┌───────────────┘     └──────────────┐
                   v                                     v
         ┌──────────────────┐                  ┌─────────────────┐
         │ AxonDB Timeseries│                  │ AxonDB Search   │
         │ (Cassandra)      │                  │ (Search Engine) │
         └──────────────────┘                  └─────────────────┘
```

## Requisitos previos

Antes de empezar, asegúrese de tener lo siguiente:

### Componentes obligatorios

- **Un clúster de Kubernetes**: versión 1.19 o superior
- **kubectl**: configurado para comunicarse con su clúster
- **Helm**: versión 3.0 o superior instalada ([guía de instalación](https://helm.sh/docs/intro/install/))
- **AxonDB Timeseries**: ya desplegada ([guía de instalación](../axondb-timeseries/))
- **AxonDB Search**: ya desplegada ([guía de instalación](../axondb-search/))
- **Una clave de licencia de AxonOps**: contacte con AxonOps para obtenerla

### Componentes opcionales

- **Un controlador de Ingress**: necesario si quiere acceso externo a la API o a los agentes
- **cert-manager**: para la gestión automática de certificados TLS
- **Un servidor LDAP**: si usa autenticación LDAP

### Verificar su instalación

Compruebe que las bases de datos están en marcha:
```bash
# Check timeseries database
kubectl get pods -l app.kubernetes.io/name=axondb-timeseries

# Check search database
kubectl get pods -l app.kubernetes.io/name=axondb-search
```

Compruebe que Helm está instalado:
```bash
helm version
```

## Inicio rápido

La forma más rápida de empezar con el servidor de AxonOps:

```bash
# Install with default settings (connects to local databases)
helm install axon-server ./axon-server \
  --set config.license_key="YOUR_LICENSE_KEY" \
  --set config.org_name="your-organization"

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axon-server
```

Esto despliega el servidor de AxonOps con:
- Conexión a las instancias locales de AxonDB
- Sin acceso externo (servicios ClusterIP)
- La autenticación por defecto (desactivada)
- 1 Gi de almacenamiento persistente

## Ejemplos de instalación

### Instalación básica

Instalación con la configuración mínima, apta para desarrollo y pruebas:

```yaml
# values-basic.yaml
# Basic AxonOps Server configuration

# Organization and licensing
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  # Listener configuration
  listener:
    host: 0.0.0.0
    api_port: 8080      # API for dashboard
    agents_port: 1888   # Port for agents

  # Database connections
  extraConfig:
    # Timeseries database (Cassandra) connection
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    cql_username: "axonops"
    cql_password: "your-db-password"
    cql_local_dc: "datacenter1"
    cql_ssl: true
    cql_skip_verify: true

# Search database connection
searchDb:
  hosts:
    - https://axondb-search-cluster-master:9200
  username: "admin"
  password: "your-search-password"
  skip_verify: true

# Dashboard URL (used in notifications and links)
dashboardUrl: "https://axonops.example.com"

# Resource limits
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

Instale:

```bash
helm install axon-server ./axon-server -f values-basic.yaml
```

### Instalación con bases de datos externas

Configure las conexiones a instancias de base de datos externas:

```yaml
# values-external-dbs.yaml
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  extraConfig:
    # External Cassandra timeseries database
    cql_hosts:
      - cassandra-1.example.com
      - cassandra-2.example.com
      - cassandra-3.example.com
    cql_username: "axonops"
    cql_password: "secure-password"
    cql_local_dc: "dc1"
    cql_proto_version: 4

    # Connection tuning
    cql_reconnectionpolicy_maxretries: 10
    cql_reconnectionpolicy_initialinterval: 1s
    cql_reconnectionpolicy_maxinterval: 10s
    cql_retrypolicy_numretries: 3
    cql_retrypolicy_min: 2s
    cql_retrypolicy_max: 10s

    # Performance tuning
    cql_max_searchqueriesparallelism: 100
    cql_batch_size: 100
    cql_page_size: 100

    # Metrics cache
    cql_metrics_cache_max_size: 128  # MB
    cql_metrics_cache_max_items: 500000

    # TLS configuration for Cassandra
    cql_ssl: true
    cql_skip_verify: false
    # cql_ca_file: /ssl/ca.crt
    # cql_cert_file: /ssl/tls.crt
    # cql_key_file: /ssl/tls.key

# External search database
searchDb:
  hosts:
    - https://search-1.example.com:9200
    - https://search-2.example.com:9200
  username: "axonops"
  password: "secure-search-password"
  skip_verify: false

dashboardUrl: "https://axonops.example.com"
```

**Si usa certificados TLS para la conexión con Cassandra:**

```bash
# Create secret with certificates
kubectl create secret generic axon-server-cql-tls \
  --from-file=ca.crt=path/to/ca.crt \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key

# Update values to mount the secret
```

```yaml
# Add to values file
config:
  sslSecretName: "axon-server-cql-tls"
  extraConfig:
    cql_ssl: true
    cql_skip_verify: false
    cql_ca_file: /ssl/ca.crt
    cql_cert_file: /ssl/tls.crt
    cql_key_file: /ssl/tls.key
```

Instale:

```bash
helm install axon-server ./axon-server -f values-external-dbs.yaml
```

### Instalación con las credenciales de base de datos en secretos

En lugar de guardar las credenciales de las bases de datos directamente en los
values de Helm, puede referenciar secretos externos de Kubernetes tanto para las
credenciales de Cassandra (series temporales) como para las de OpenSearch. Este
enfoque es el recomendado en entornos de producción.

Cree los secretos con las credenciales:

```bash
# Cassandra/timeseries credentials (keys: AXONOPS_DB_USER, AXONOPS_DB_PASSWORD)
kubectl create secret generic cassandra-credentials \
  --from-literal=AXONOPS_DB_USER=axonops \
  --from-literal=AXONOPS_DB_PASSWORD=your-cassandra-password

# OpenSearch credentials (keys: AXONOPS_SEARCH_USER, AXONOPS_SEARCH_PASSWORD)
kubectl create secret generic opensearch-credentials \
  --from-literal=AXONOPS_SEARCH_USER=axonops \
  --from-literal=AXONOPS_SEARCH_PASSWORD=your-opensearch-password
```

Configure los values de Helm para que referencien los secretos:

```yaml
# values-db-secrets.yaml
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  # Reference the external secret for Cassandra credentials
  db_secret: "cassandra-credentials"

  extraConfig:
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    # Note: cql_username and cql_password are ignored when db_secret is set
    cql_local_dc: "datacenter1"
    cql_ssl: true
    cql_skip_verify: true

# Search database configuration using external secret
searchDb:
  hosts:
    - https://axondb-search-cluster-master:9200
  skip_verify: true
  # Reference the external secret for OpenSearch credentials
  search_secret: "opensearch-credentials"

dashboardUrl: "https://axonops.example.com"
```

Instale el chart:

```bash
helm install axon-server ./axon-server -f values-db-secrets.yaml
```

Notas importantes:

- Cuando se define `config.db_secret`, las credenciales de Cassandra se inyectan como variables de entorno (`CQL_USERNAME`, `CQL_PASSWORD`)
- Cuando se define `searchDb.search_secret`, las credenciales de OpenSearch se inyectan como variables de entorno (`SEARCH_DB_USERNAME`, `SEARCH_DB_PASSWORD`)
- Los valores en línea `cql_username`/`cql_password` y `searchDb.username`/`searchDb.password` se ignoran cuando se usan secretos
- Los nombres de clave del secreto de OpenSearch (`AXONOPS_SEARCH_USER`, `AXONOPS_SEARCH_PASSWORD`) son compatibles con el chart axondb-search, lo que permite compartir el mismo secreto entre ambos charts

### Instalación con un secreto de configuración externo

En lugar de dejar que el chart genere automáticamente un secreto con la
configuración de axon-server, puede apuntar a un secreto de Kubernetes ya
existente con el valor `configurationSecret`. Cuando se define:

- El chart **no** crea su propio secreto de configuración: espera que el secreto ya exista en el clúster.
- El secreto debe contener una clave llamada **`axon-server.yml`** con la configuración **completa** de axon-server en formato YAML.
- **Todos los valores `config.*` y `searchDb.*` de Helm se ignoran**: el secreto externo es la única fuente de configuración.
- Los valores que no son de configuración (recursos, persistencia, ingress, servicios, sondas, etc.) siguen funcionando con normalidad.

Este enfoque es útil cuando:

- Gestiona los secretos con herramientas externas (vals-operator, Sealed Secrets, External Secrets Operator, etc.)
- Necesita compartir la configuración entre varios despliegues
- Quiere versionar los secretos cifrados por separado
- Usa un flujo GitOps en el que los secretos se gestionan fuera de los values de Helm

**Paso 1: cree su secreto de configuración**

```yaml
# axon-server-config-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-axon-server-config
  namespace: default
type: Opaque
stringData:
  axon-server.yml: |
    # Listener configuration
    host: 0.0.0.0
    api_port: 8080
    agents_port: 1888

    # Search database configuration
    search_db:
      hosts:
        - https://axondb-search-cluster-master:9200
      username: admin
      password: mysecurepassword
      skip_verify: true

    # Organization configuration
    org_name: my-organization
    license_key: YOUR_LICENSE_KEY_HERE

    # Dashboard URL
    axon_dash_url: https://axonops.example.com

    # Log to stdout for Kubernetes
    log_file: /dev/stdout

    # Cassandra timeseries database configuration
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    cql_username: axonops
    cql_password: cassandra-password
    cql_local_dc: datacenter1
    cql_ssl: true
    cql_skip_verify: true

    # Optional: Authentication configuration
    auth:
      enabled: true
      type: LDAP
      settings:
        host: ldap.example.com
        port: 636
        base: dc=example,dc=com
        useSSL: true
        bindDN: cn=axonops,ou=services,dc=example,dc=com
        bindPassword: ldap-bind-password
        userFilter: (cn=%s)
        rolesAttribute: memberOf

    # Optional: TLS configuration
    tls:
      mode: TLS

    # Optional: Alerting configuration
    alerting:
      notification_interval: 3h
```

Aplique el secreto:

```bash
kubectl apply -f axon-server-config-secret.yaml
```

**Paso 2: cree el fichero de values que referencia el secreto externo**

```yaml
# values-external-secret.yaml
# Reference the external configuration secret
configurationSecret: "my-axon-server-config"

# Resource limits
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi

# Persistence settings
persistence:
  enabled: true
  size: 5Gi

# Services configuration
apiService:
  type: ClusterIP
  listenPort: 8080

agentService:
  type: ClusterIP
  listenPort: 1888

# Optional: Ingress configuration
apiIngress:
  enabled: false

agentIngress:
  enabled: false
```

**Paso 3: instale usando el secreto externo**

```bash
helm install axon-server ./axon-server -f values-external-secret.yaml
```

**Notas importantes:**
- Cuando se define `configurationSecret`, el chart NO crea su propio recurso Secret
- El secreto externo debe contener una clave llamada `axon-server.yml` con la configuración completa
- Toda la configuración que normalmente iría en los valores `config.*` debe estar en el secreto externo
- Los valores `searchDb.*` de los values de Helm se ignoran cuando se usa un secreto externo
- Puede seguir configurando otros values de Helm, como recursos, persistencia, ingress, etc.

**Verifique el despliegue:**

```bash
# Check that the pod is using the external secret
kubectl get statefulset axon-server -o yaml | grep -A 2 "secretName"

# Should show:
#   - name: config
#     secret:
#       secretName: my-axon-server-config

# Verify the pod is running with the configuration
kubectl logs axon-server-0 | head -20
```

### Instalación con Ingress

Exponga las API del servidor de AxonOps al exterior con Ingress:

```yaml
# values-ingress.yaml
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  extraConfig:
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    cql_username: "axonops"
    cql_password: "password"

searchDb:
  hosts:
    - https://axondb-search-cluster-master:9200
  username: "admin"
  password: "password"

dashboardUrl: "https://axonops.example.com"

# API Ingress (for Dashboard access)
apiIngress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: api.axonops.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: axon-api-tls
      hosts:
        - api.axonops.example.com

# Agent Ingress (for external Cassandra agents)
agentIngress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: agents.axonops.example.com
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: axon-agents-tls
      hosts:
        - agents.axonops.example.com
```

Instale:

```bash
helm install axon-server ./axon-server -f values-ingress.yaml
```

### Instalación con TLS/mTLS

Configure TLS o TLS mutuo para las conexiones de los agentes:

**Paso 1: cree el secreto TLS**

```bash
kubectl create secret generic axon-server-tls \
  --from-file=tls.crt=path/to/server.crt \
  --from-file=tls.key=path/to/server.key \
  --from-file=ca.crt=path/to/ca.crt
```

**Paso 2: cree el fichero de values**

**Para TLS:**

```yaml
# values-tls.yaml
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  # Enable TLS mode
  tls:
    mode: "TLS"  # Options: disabled, TLS, mTLS

  # Mount the SSL secret
  sslSecretName: "axon-server-tls"

  extraConfig:
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    cql_username: "axonops"
    cql_password: "password"

searchDb:
  hosts:
    - https://axondb-search-cluster-master:9200
  username: "admin"
  password: "password"

dashboardUrl: "https://axonops.example.com"
```

**Para mTLS (TLS mutuo):**

```yaml
# values-mtls.yaml
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  # Enable mTLS mode (requires client certificates)
  tls:
    mode: "mTLS"

  sslSecretName: "axon-server-tls"

  extraConfig:
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    cql_username: "axonops"
    cql_password: "password"

searchDb:
  hosts:
    - https://axondb-search-cluster-master:9200
  username: "admin"
  password: "password"

dashboardUrl: "https://axonops.example.com"
```

Instale:

```bash
# For TLS
helm install axon-server ./axon-server -f values-tls.yaml

# OR for mTLS
helm install axon-server ./axon-server -f values-mtls.yaml
```

### Instalación con autenticación LDAP

Configure la autenticación con LDAP o Active Directory:

```yaml
# values-ldap.yaml
config:
  org_name: "my-organization"
  license_key: "YOUR_LICENSE_KEY_HERE"

  # Enable authentication
  auth:
    enabled: true
    type: "LDAP"
    settings:
      host: "ldap.example.com"
      port: 636
      base: "dc=example,dc=com"
      useSSL: true
      startTLS: false
      insecureSkipVerify: false
      bindDN: "cn=axonops,ou=services,dc=example,dc=com"
      bindPassword: "ldap-bind-password"
      userFilter: "(cn=%s)"
      rolesAttribute: "memberOf"
      callAttempts: 3

      # Role mappings
      rolesMapping:
        # Global roles (apply across all organizations/clusters)
        _global_:
          superUserRole: "cn=axonops-superuser,ou=groups,dc=example,dc=com"
          readOnlyRole: "cn=axonops-readonly,ou=groups,dc=example,dc=com"
          adminRole: "cn=axonops-admin,ou=groups,dc=example,dc=com"
          backupAdminRole: "cn=axonops-backup-admin,ou=groups,dc=example,dc=com"

        # Organization-specific roles
        my-organization:
          superUserRole: "cn=org-superuser,ou=groups,dc=example,dc=com"
          readOnlyRole: "cn=org-readonly,ou=groups,dc=example,dc=com"
          adminRole: "cn=org-admin,ou=groups,dc=example,dc=com"
          backupAdminRole: "cn=org-backup-admin,ou=groups,dc=example,dc=com"

        # Cluster type-specific roles
        my-organization/cassandra:
          adminRole: "cn=cassandra-admin,ou=groups,dc=example,dc=com"

        # Specific cluster roles
        my-organization/cassandra/production:
          superUserRole: "cn=prod-admin,ou=groups,dc=example,dc=com"

  extraConfig:
    cql_hosts:
      - axondb-timeseries-headless.default.svc.cluster.local
    cql_username: "axonops"
    cql_password: "password"

searchDb:
  hosts:
    - https://axondb-search-cluster-master:9200
  username: "admin"
  password: "password"

dashboardUrl: "https://axonops.example.com"
```

Instale:

```bash
helm install axon-server ./axon-server -f values-ldap.yaml
```

### Instalación lista para producción

Una configuración de producción completa, con todos los ajustes recomendados:

```yaml
# values-production.yaml
# Production configuration for AxonOps Server

# Organization and licensing
config:
  org_name: "production-org"
  license_key: "YOUR_PRODUCTION_LICENSE_KEY"

  # Listener configuration
  listener:
    host: 0.0.0.0
    api_port: 8080
    agents_port: 1888

  # Enable TLS for agent connections
  tls:
    mode: "TLS"

  # SSL certificates for TLS
  sslSecretName: "axon-server-tls"

  # Enable LDAP authentication
  auth:
    enabled: true
    type: "LDAP"
    settings:
      host: "ldap.production.example.com"
      port: 636
      base: "dc=production,dc=example,dc=com"
      useSSL: true
      startTLS: false
      insecureSkipVerify: false
      bindDN: "cn=axonops,ou=services,dc=production,dc=example,dc=com"
      bindPassword: "secure-ldap-password"
      userFilter: "(cn=%s)"
      rolesAttribute: "memberOf"
      callAttempts: 3
      rolesMapping:
        _global_:
          superUserRole: "cn=axonops-superuser,ou=groups,dc=production,dc=example,dc=com"
          readOnlyRole: "cn=axonops-readonly,ou=groups,dc=production,dc=example,dc=com"
          adminRole: "cn=axonops-admin,ou=groups,dc=production,dc=example,dc=com"
          backupAdminRole: "cn=axonops-backup-admin,ou=groups,dc=production,dc=example,dc=com"

  # Alerting configuration
  alerting:
    notification_interval: 3h

  # Database connection configuration
  extraConfig:
    # Cassandra timeseries database
    cql_hosts:
      - axondb-timeseries-0.axondb-timeseries-headless.production.svc.cluster.local
      - axondb-timeseries-1.axondb-timeseries-headless.production.svc.cluster.local
      - axondb-timeseries-2.axondb-timeseries-headless.production.svc.cluster.local
    cql_username: "axonops"
    cql_password: "secure-cassandra-password"
    cql_local_dc: "datacenter1"
    cql_proto_version: 4
    cql_keyspace_replication: "{ 'class': 'NetworkTopologyStrategy', 'datacenter1': 3 }"

    # Connection settings
    cql_reconnectionpolicy_maxretries: 10
    cql_reconnectionpolicy_initialinterval: 1s
    cql_reconnectionpolicy_maxinterval: 10s
    cql_retrypolicy_numretries: 3
    cql_retrypolicy_min: 2s
    cql_retrypolicy_max: 10s

    # Performance tuning
    cql_max_searchqueriesparallelism: 100
    cql_batch_size: 100
    cql_page_size: 100
    cql_autocreate_tables: true

    # Metrics cache configuration
    cql_metrics_cache_max_size: 256  # MB
    cql_metrics_cache_max_items: 1000000

    # TLS for Cassandra
    cql_ssl: true
    cql_skip_verify: false
    cql_ca_file: /ssl/ca.crt
    cql_cert_file: /ssl/tls.crt
    cql_key_file: /ssl/tls.key

# Search database configuration
searchDb:
  hosts:
    - https://axondb-search-cluster-master-0.axondb-search-cluster-master-headless.production.svc.cluster.local:9200
    - https://axondb-search-cluster-master-1.axondb-search-cluster-master-headless.production.svc.cluster.local:9200
    - https://axondb-search-cluster-master-2.axondb-search-cluster-master-headless.production.svc.cluster.local:9200
  username: "axonops"
  password: "secure-search-password"
  skip_verify: false

# Dashboard URL (used in notifications and email links)
dashboardUrl: "https://axonops.production.example.com"

# API Service (for dashboard connections)
apiService:
  type: ClusterIP
  listenPort: 8080
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"

# API Ingress
apiIngress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  hosts:
    - host: api.axonops.production.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: axon-api-tls
      hosts:
        - api.axonops.production.example.com

# Agent Service (for agent connections)
agentService:
  type: LoadBalancer
  listenPort: 1888
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"

# Agent Ingress (optional if using LoadBalancer)
agentIngress:
  enabled: false

# Resource limits
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 4000m
    memory: 4Gi

# Health check probes
livenessProbe:
  httpGet:
    path: /api/v1/healthz
    port: api
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /api/v1/healthz
    port: api
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

startupProbe:
  httpGet:
    path: /api/v1/healthz
    port: api
  initialDelaySeconds: 0
  periodSeconds: 2
  timeoutSeconds: 3
  failureThreshold: 60

# Persistence
persistence:
  enabled: true
  enableInitChown: true
  size: 10Gi
  # storageClass: "gp3"
  accessMode: ReadWriteOnce
  annotations:
    backup.velero.io/backup-volumes: "data"

# Security context
podSecurityContext:
  enabled: true
  runAsUser: 9988
  fsGroup: 9988
  runAsNonRoot: true

securityContext:
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 9988

# Node selection
nodeSelector:
  workload: monitoring

# Tolerations
tolerations:
  - key: "workload"
    operator: "Equal"
    value: "monitoring"
    effect: "NoSchedule"

# Pod annotations
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/metrics"
```

**Antes de instalar:**

```bash
# Create TLS secret for server
kubectl create secret generic axon-server-tls \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key \
  --from-file=ca.crt=path/to/ca.crt \
  -n production
```

**Instale el despliegue de producción:**

```bash
helm install axon-server ./axon-server \
  -f values-production.yaml \
  --namespace production \
  --create-namespace
```

**Verifique el despliegue:**

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=axon-server -n production

# Check services
kubectl get svc -l app.kubernetes.io/name=axon-server -n production

# Check ingress
kubectl get ingress -n production

# Test health endpoint
kubectl port-forward svc/axon-server-api 8080:8080 -n production
curl http://localhost:8080/api/v1/healthz
```

## Configuración

### Opciones de configuración principales

| Parámetro | Descripción | Valor por defecto |
|-----------|-------------|---------|
| `configurationSecret` | El nombre del secreto externo con la configuración axon-server.yml | `""` |
| `config.org_name` | El nombre de la organización | `"example"` |
| `config.license_key` | La clave de licencia de AxonOps (obligatoria) | `""` |
| `config.listener.api_port` | El puerto de la API para las conexiones del panel | `8080` |
| `config.listener.agents_port` | El puerto para las conexiones de los agentes | `1888` |
| `config.tls.mode` | El modo TLS: disabled, TLS, mTLS | `"disabled"` |
| `config.auth.enabled` | Activa la autenticación | `false` |
| `config.extraConfig.cql_hosts` | Los hosts de Cassandra de la base de datos de series temporales | `[]` |
| `config.extraConfig.cql_username` | El usuario de Cassandra | `""` |
| `config.db_secret` | El nombre del secreto de Kubernetes con las credenciales de Cassandra | `""` |
| `searchDb.hosts` | Los hosts de la base de datos de búsqueda | `[]` |
| `searchDb.username` | El usuario de la base de datos de búsqueda | `""` |
| `searchDb.search_secret` | El nombre del secreto de Kubernetes con las credenciales de OpenSearch | `""` |
| `dashboardUrl` | La URL pública del panel de AxonOps | `""` |
| `apiIngress.enabled` | Activa el ingress de la API | `false` |
| `agentIngress.enabled` | Activa el ingress de los agentes | `false` |
| `persistence.enabled` | Activa el almacenamiento persistente | `true` |
| `persistence.size` | El tamaño del volumen persistente | `1Gi` |

### Notas importantes

**La clave de licencia:**
- Hace falta una clave de licencia de AxonOps válida para uso en producción
- Contacte con AxonOps en <info@axonops.com> para obtener una licencia

**El secreto de configuración externo:**
- Use `configurationSecret` para referenciar un secreto externo en lugar de generar uno automáticamente
- Es útil en flujos GitOps y con herramientas de gestión de secretos (Sealed Secrets, External Secrets, etc.)
- Cuando se define, se ignoran todos los valores `config.*` y `searchDb.*` de Helm

**Las conexiones a las bases de datos:**
- El servidor necesita conexión con las bases de datos de series temporales y de búsqueda
- Asegúrese de que las bases de datos están en marcha y accesibles antes de desplegar el servidor
- Use nombres de servicio para las bases de datos dentro del clúster, o FQDN para las externas

**El número de réplicas:**
- Actualmente sólo se admite 1 réplica
- La alta disponibilidad se consigue con el StatefulSet y el almacenamiento persistente

**Los modos TLS:**
- `disabled`: sin TLS (sólo desarrollo)
- `TLS`: cifrado TLS del lado del servidor
- `mTLS`: TLS mutuo (requiere certificados de cliente en los agentes)

### Referencia completa de values

<details>
<summary>Pulse para desplegar la tabla completa de values</summary>

| Clave | Tipo | Valor por defecto | Descripción |
|-----|------|---------|-------------|
| affinity | object | `{}` | Reglas de afinidad de pod |
| agentIngress.annotations | object | `{}` | Anotaciones del ingress de agentes |
| agentIngress.className | string | `"nginx"` | La clase de ingress de los agentes |
| agentIngress.enabled | bool | `false` | Activa el ingress de agentes |
| agentIngress.hosts | list | `[{"host":"agents.example.com","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Los hosts del ingress de agentes |
| agentIngress.tls | list | `[]` | Configuración de TLS del ingress de agentes |
| agentService.annotations | object | `{}` | Anotaciones del servicio de agentes |
| agentService.listenPort | int | `1888` | El puerto del servicio de agentes |
| agentService.type | string | `"ClusterIP"` | El tipo del servicio de agentes |
| apiIngress.annotations | object | `{}` | Anotaciones del ingress de la API |
| apiIngress.className | string | `"traefik"` | La clase de ingress de la API |
| apiIngress.enabled | bool | `false` | Activa el ingress de la API |
| apiIngress.hosts | list | `[{"host":"api.example.com","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Los hosts del ingress de la API |
| apiIngress.tls | list | `[]` | Configuración de TLS del ingress de la API |
| apiService.annotations | object | `{}` | Anotaciones del servicio de la API |
| apiService.listenPort | int | `8080` | El puerto del servicio de la API |
| apiService.type | string | `"ClusterIP"` | El tipo del servicio de la API |
| configurationSecret | string | `""` | El nombre del secreto externo con la configuración axon-server.yml |
| config.alerting.notification_interval | string | `"3h"` | El intervalo de notificación de alertas |
| config.auth.enabled | bool | `false` | Activa la autenticación |
| config.db_secret | string | `""` | El nombre del secreto de Kubernetes con las credenciales de Cassandra (claves: AXONOPS_DB_USER, AXONOPS_DB_PASSWORD) |
| config.extraConfig | object | `{}` | Opciones de configuración adicionales |
| config.license_key | string | `""` | La clave de licencia de AxonOps |
| config.listener.agents_port | int | `1888` | El puerto de escucha de los agentes |
| config.listener.api_port | int | `8080` | El puerto de escucha de la API |
| config.listener.host | string | `"0.0.0.0"` | El host de escucha |
| config.org_name | string | `"example"` | El nombre de la organización |
| config.sslSecretName | string | `""` | El nombre del secreto con los certificados SSL |
| config.tls.mode | string | `"disabled"` | El modo TLS (disabled, TLS, mTLS) |
| dashboardUrl | string | `""` | La URL pública del panel |
| deployment.annotations | object | `{}` | Anotaciones del deployment |
| deployment.env | object | `{}` | Variables de entorno adicionales |
| deployment.secretEnv | string | `""` | El secreto que contiene las variables de entorno |
| extraVolumeMounts | list | `[]` | Montajes de volumen adicionales |
| extraVolumes | list | `[]` | Volúmenes adicionales |
| fullnameOverride | string | `""` | Sustituye el nombre completo del recurso |
| image.pullPolicy | string | `"IfNotPresent"` | Política de descarga de la imagen |
| image.repository | string | `"registry.axonops.com/axonops-public/axonops-docker/axon-server"` | El repositorio de la imagen |
| image.tag | string | `""` | La etiqueta de la imagen (por defecto, la appVersion) |
| imagePullSecrets | list | `[]` | Secretos de descarga de imágenes |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":5}` | Configuración de la sonda de vida |
| nameOverride | string | `""` | Sustituye el nombre del chart |
| nodeSelector | object | `{}` | Etiquetas de nodo para asignar los pods |
| persistence.accessMode | string | `"ReadWriteOnce"` | El modo de acceso de la PVC |
| persistence.annotations | object | `{}` | Anotaciones de la PVC |
| persistence.enableInitChown | bool | `true` | Activa un contenedor de inicialización que fija la propiedad |
| persistence.enabled | bool | `true` | Activa el almacenamiento persistente |
| persistence.size | string | `"1Gi"` | El tamaño del volumen persistente |
| persistence.storageClass | string | `""` | El nombre de la clase de almacenamiento |
| podAnnotations | object | `{}` | Anotaciones de los pods |
| podLabels | object | `{}` | Etiquetas de los pods |
| podSecurityContext.enabled | bool | `false` | Activa el contexto de seguridad del pod |
| podSecurityContext.fsGroup | int | `9988` | El FSGroup del pod |
| podSecurityContext.runAsNonRoot | bool | `true` | Ejecuta como usuario no root |
| podSecurityContext.runAsUser | int | `9988` | El ID de usuario con el que se ejecuta el pod |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":3}` | Configuración de la sonda de disponibilidad |
| resources | object | `{}` | Peticiones y límites de recursos |
| searchDb.hosts | list | `[]` | Los hosts de la base de datos de búsqueda |
| searchDb.password | string | `""` | La contraseña de la base de datos de búsqueda |
| searchDb.search_secret | string | `""` | El nombre del secreto de Kubernetes con las credenciales de OpenSearch (claves: AXONOPS_SEARCH_USER, AXONOPS_SEARCH_PASSWORD) |
| searchDb.skip_verify | bool | `true` | Omite la verificación TLS de la base de datos de búsqueda |
| searchDb.username | string | `""` | El usuario de la base de datos de búsqueda |
| securityContext | object | `{"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":false,"runAsNonRoot":true,"runAsUser":9988}` | El contexto de seguridad del contenedor |
| serviceAccount.annotations | object | `{}` | Anotaciones de la cuenta de servicio |
| serviceAccount.automount | bool | `true` | Monta automáticamente el token de la cuenta de servicio |
| serviceAccount.create | bool | `true` | Crea la cuenta de servicio |
| serviceAccount.createClusterRole | bool | `false` | Crea el cluster role |
| serviceAccount.name | string | `""` | El nombre de la cuenta de servicio |
| startupProbe | object | `{"failureThreshold":60,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":0,"periodSeconds":2,"timeoutSeconds":3}` | Configuración de la sonda de arranque |
| tolerations | list | `[]` | Toleraciones para asignar los pods |
| updateStrategy.type | string | `"RollingUpdate"` | El tipo de estrategia de actualización |

</details>

## Actualización

Para actualizar una instalación existente:

```bash
# Update the chart
helm upgrade axon-server ./axon-server -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axon-server
```

**Notas importantes:**
- Revise siempre el changelog antes de actualizar
- Pruebe primero las actualizaciones fuera de producción
- Haga copia de seguridad del volumen persistente antes de actualizar
- El servidor puede quedar brevemente no disponible durante la actualización

## Desinstalación

Para eliminar el servidor de AxonOps:

```bash
# Uninstall the release
helm uninstall axon-server

# Optional: Delete PVC (this will delete server data!)
kubectl delete pvc -l app.kubernetes.io/name=axon-server
```

**Aviso:** borrar la PVC elimina:
- La configuración del servidor
- Los datos de usuario (si no usa LDAP)
- El histórico de alertas y el estado de las notificaciones

## Resolución de problemas

### Problemas habituales

**1. El servidor no conecta con las bases de datos**

Revise la conectividad con las bases de datos:
```bash
# Get server pod logs
kubectl logs axon-server-0

# Look for connection errors
kubectl logs axon-server-0 | grep -i "error\|connection\|failed"
```

Causas habituales:
- Nombres de host o de servicio de base de datos incorrectos
- Credenciales equivocadas (revise el usuario y la contraseña)
- La base de datos no está lista (asegúrese de que arranca antes)
- Network policies que bloquean las conexiones

**2. Errores de la clave de licencia**

Si ve errores de licencia:
```bash
# Check if license key is set
kubectl get statefulset axon-server -o yaml | grep -A 5 license_key
```

- Asegúrese de que `config.license_key` está definido en los values
- Contacte con AxonOps para conseguir una clave de licencia válida
- Compruebe que no hay erratas ni espacios de más en la clave

**3. Los agentes no conectan**

Revise la conectividad de los agentes:
```bash
# Check agent service
kubectl get svc axon-server-agents

# Check if port is accessible
kubectl port-forward svc/axon-server-agents 1888:1888

# In another terminal
telnet localhost 1888
```

Causas habituales:
- Los agentes usan un nombre de host o un puerto equivocados
- Discrepancia en el modo TLS (el servidor en TLS y los agentes sin configurar)
- Network policies o cortafuegos que bloquean el puerto 1888
- El ingress no está bien configurado para los agentes externos

**4. El panel no puede conectar con la API**

Verifique el servicio de la API:
```bash
# Check API service
kubectl get svc axon-server-api

# Test API health
kubectl port-forward svc/axon-server-api 8080:8080
curl http://localhost:8080/api/v1/healthz
```

Si usa ingress:
```bash
# Check ingress configuration
kubectl get ingress

# Test external access
curl https://api.axonops.example.com/api/v1/healthz
```

**5. La autenticación LDAP falla**

Revise la configuración de LDAP:
```bash
# View server logs for LDAP errors
kubectl logs axon-server-0 | grep -i ldap

# Common issues:
# - Incorrect bind DN or password
# - Wrong LDAP host or port
# - SSL/TLS certificate issues
# - Incorrect user filter or base DN
# - Role attribute not found
```

Pruebe la conectividad con LDAP:
```bash
# From within the pod
kubectl exec -it axon-server-0 -- sh
# Try to connect to LDAP server
nc -zv ldap.example.com 636
```

**6. Uso alto de memoria**

Revise el uso de recursos:
```bash
kubectl top pod axon-server-0
```

Suba los recursos si hace falta:
```yaml
resources:
  limits:
    memory: 4Gi
  requests:
    memory: 2Gi
```

**7. Problemas con el volumen persistente**

Revise el estado de la PVC:
```bash
kubectl get pvc
kubectl describe pvc data-axon-server-0
```

Si la PVC está en Pending:
- Compruebe que la StorageClass existe y es la de por defecto
- Compruebe que hay cuota de almacenamiento suficiente
- Asegúrese de que el aprovisionamiento dinámico está activado

**8. Problemas con los certificados TLS**

Para los problemas de TLS/mTLS:
```bash
# Check if secret exists
kubectl get secret axon-server-tls

# Verify secret contains required keys
kubectl describe secret axon-server-tls

# Check server logs for TLS errors
kubectl logs axon-server-0 | grep -i tls
```

Asegúrese de que los certificados:
- Están en formato PEM
- Tienen los permisos correctos
- No han caducado
- Corresponden al nombre de host del servidor

### Obtener ayuda

Para soporte adicional:

- **Revise los registros:** `kubectl logs -f axon-server-0`
- **Consulte los eventos:** `kubectl get events --sort-by='.lastTimestamp'`
- **Describa el pod:** `kubectl describe pod axon-server-0`
- **Pruebe el endpoint de salud:**
  ```bash
  kubectl port-forward svc/axon-server-api 8080:8080
  curl http://localhost:8080/api/v1/healthz
  ```
- **Documentación:** <https://docs.axonops.com>
- **Soporte:** <info@axonops.com>
- **Comunidad:** <https://community.axonops.com>

## Mantenedores

| Nombre | Correo | URL |
| ---- | ------ | --- |
| El equipo de AxonOps | <info@axonops.com> | <https://axonops.com> |

## Código fuente

* <https://github.com/axonops/axonops-containers>

---

*Generado con los charts de Helm de AxonOps*
