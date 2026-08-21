# Servidor de AxonOps

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

![Versión: 2.1.3](https://img.shields.io/badge/Version-2.1.3-informational?style=flat-square) ![Tipo: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

Un chart de Helm para despregar o servidor de AxonOps, a plataforma de
observabilidade unificada para Apache Cassandra. O servidor de AxonOps é o
compoñente central que recolle as métricas e os rexistros dos clústeres de
Cassandra, almacénaos nas bases de datos de series temporais e de busca, e ofrece
as API para o panel de AxonOps.

**Páxina do proxecto:** <https://axonops.com>

## Índice

- [Visión xeral da arquitectura](#visión-xeral-da-arquitectura)
- [Requisitos previos](#requisitos-previos)
- [Inicio rápido](#inicio-rápido)
- [Exemplos de instalación](#exemplos-de-instalación)
  - [Instalación básica](#instalación-básica)
  - [Instalación con bases de datos externas](#instalación-con-bases-de-datos-externas)
  - [Instalación coas credenciais de base de datos en segredos](#instalación-coas-credenciais-de-base-de-datos-en-segredos)
  - [Instalación cun segredo de configuración externo](#instalación-cun-segredo-de-configuración-externo)
  - [Instalación con Ingress](#instalación-con-ingress)
  - [Instalación con TLS/mTLS](#instalación-con-tlsmtls)
  - [Instalación con autenticación LDAP](#instalación-con-autenticación-ldap)
  - [Instalación lista para produción](#instalación-lista-para-produción)
- [Configuración](#configuración)
- [Actualización](#actualización)
- [Desinstalación](#desinstalación)
- [Resolución de problemas](#resolución-de-problemas)

## Visión xeral da arquitectura

O servidor de AxonOps é o compoñente central da plataforma AxonOps:

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

Antes de comezar, asegúrese de ter o seguinte:

### Compoñentes obrigatorios

- **Un clúster de Kubernetes**: versión 1.19 ou superior
- **kubectl**: configurado para comunicarse co seu clúster
- **Helm**: versión 3.0 ou superior instalada ([guía de instalación](https://helm.sh/docs/intro/install/))
- **AxonDB Timeseries**: xa despregada ([guía de instalación](../axondb-timeseries/))
- **AxonDB Search**: xa despregada ([guía de instalación](../axondb-search/))
- **Unha chave de licenza de AxonOps**: contacte con AxonOps para obtela

### Compoñentes opcionais

- **Un controlador de Ingress**: necesario se quere acceso externo á API ou aos axentes
- **cert-manager**: para a xestión automática de certificados TLS
- **Un servidor LDAP**: se usa autenticación LDAP

### Verificar a súa instalación

Comprobe que as bases de datos están en marcha:
```bash
# Check timeseries database
kubectl get pods -l app.kubernetes.io/name=axondb-timeseries

# Check search database
kubectl get pods -l app.kubernetes.io/name=axondb-search
```

Comprobe que Helm está instalado:
```bash
helm version
```

## Inicio rápido

A forma máis rápida de comezar co servidor de AxonOps:

```bash
# Install with default settings (connects to local databases)
helm install axon-server ./axon-server \
  --set config.license_key="YOUR_LICENSE_KEY" \
  --set config.org_name="your-organization"

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axon-server
```

Isto desprega o servidor de AxonOps con:
- Conexión ás instancias locais de AxonDB
- Sen acceso externo (servizos ClusterIP)
- A autenticación por defecto (desactivada)
- 1 Gi de almacenamento persistente

## Exemplos de instalación

### Instalación básica

Instalación coa configuración mínima, apta para desenvolvemento e probas:

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

Configure as conexións a instancias de base de datos externas:

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

**Se usa certificados TLS para a conexión con Cassandra:**

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

### Instalación coas credenciais de base de datos en segredos

No canto de gardar as credenciais das bases de datos directamente nos values de
Helm, pode referenciar segredos externos de Kubernetes tanto para as credenciais
de Cassandra (series temporais) como para as de OpenSearch. Este enfoque é o
recomendado en entornos de produción.

Cree os segredos coas credenciais:

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

Configure os values de Helm para que referencien os segredos:

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

Instale o chart:

```bash
helm install axon-server ./axon-server -f values-db-secrets.yaml
```

Notas importantes:

- Cando se define `config.db_secret`, as credenciais de Cassandra inxéctanse como variables de entorno (`CQL_USERNAME`, `CQL_PASSWORD`)
- Cando se define `searchDb.search_secret`, as credenciais de OpenSearch inxéctanse como variables de entorno (`SEARCH_DB_USERNAME`, `SEARCH_DB_PASSWORD`)
- Os valores en liña `cql_username`/`cql_password` e `searchDb.username`/`searchDb.password` ignóranse cando se usan segredos
- Os nomes de chave do segredo de OpenSearch (`AXONOPS_SEARCH_USER`, `AXONOPS_SEARCH_PASSWORD`) son compatibles co chart axondb-search, o que permite compartir o mesmo segredo entre ambos os charts

### Instalación cun segredo de configuración externo

No canto de deixar que o chart xere automaticamente un segredo coa configuración
de axon-server, pode apuntar a un segredo de Kubernetes xa existente co valor
`configurationSecret`. Cando se define:

- O chart **non** crea o seu propio segredo de configuración: agarda que o segredo xa exista no clúster.
- O segredo debe conter unha chave chamada **`axon-server.yml`** coa configuración **completa** de axon-server en formato YAML.
- **Todos os valores `config.*` e `searchDb.*` de Helm ignóranse**: o segredo externo é a única fonte de configuración.
- Os valores que non son de configuración (recursos, persistencia, ingress, servizos, sondas, etc.) seguen funcionando con normalidade.

Este enfoque é útil cando:

- Xestiona os segredos con ferramentas externas (vals-operator, Sealed Secrets, External Secrets Operator, etc.)
- Precisa compartir a configuración entre varios despregamentos
- Quere versionar os segredos cifrados á parte
- Usa un fluxo GitOps no que os segredos se xestionan fóra dos values de Helm

**Paso 1: cree o seu segredo de configuración**

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

Aplique o segredo:

```bash
kubectl apply -f axon-server-config-secret.yaml
```

**Paso 2: cree o ficheiro de values que referencia o segredo externo**

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

**Paso 3: instale usando o segredo externo**

```bash
helm install axon-server ./axon-server -f values-external-secret.yaml
```

**Notas importantes:**
- Cando se define `configurationSecret`, o chart NON crea o seu propio recurso Secret
- O segredo externo debe conter unha chave chamada `axon-server.yml` coa configuración completa
- Toda a configuración que normalmente iría nos valores `config.*` debe estar no segredo externo
- Os valores `searchDb.*` dos values de Helm ignóranse cando se usa un segredo externo
- Pode seguir configurando outros values de Helm, como recursos, persistencia, ingress, etc.

**Verifique o despregamento:**

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

Expoña as API do servidor de AxonOps ao exterior con Ingress:

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

Configure TLS ou TLS mutuo para as conexións dos axentes:

**Paso 1: cree o segredo TLS**

```bash
kubectl create secret generic axon-server-tls \
  --from-file=tls.crt=path/to/server.crt \
  --from-file=tls.key=path/to/server.key \
  --from-file=ca.crt=path/to/ca.crt
```

**Paso 2: cree o ficheiro de values**

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

Configure a autenticación con LDAP ou Active Directory:

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

### Instalación lista para produción

Unha configuración de produción completa, con todos os axustes recomendados:

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

**Instale o despregamento de produción:**

```bash
helm install axon-server ./axon-server \
  -f values-production.yaml \
  --namespace production \
  --create-namespace
```

**Verifique o despregamento:**

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

### Opcións de configuración principais

| Parámetro | Descrición | Valor por defecto |
|-----------|-------------|---------|
| `configurationSecret` | O nome do segredo externo coa configuración axon-server.yml | `""` |
| `config.org_name` | O nome da organización | `"example"` |
| `config.license_key` | A chave de licenza de AxonOps (obrigatoria) | `""` |
| `config.listener.api_port` | O porto da API para as conexións do panel | `8080` |
| `config.listener.agents_port` | O porto para as conexións dos axentes | `1888` |
| `config.tls.mode` | O modo TLS: disabled, TLS, mTLS | `"disabled"` |
| `config.auth.enabled` | Activa a autenticación | `false` |
| `config.extraConfig.cql_hosts` | Os hosts de Cassandra da base de datos de series temporais | `[]` |
| `config.extraConfig.cql_username` | O usuario de Cassandra | `""` |
| `config.db_secret` | O nome do segredo de Kubernetes coas credenciais de Cassandra | `""` |
| `searchDb.hosts` | Os hosts da base de datos de busca | `[]` |
| `searchDb.username` | O usuario da base de datos de busca | `""` |
| `searchDb.search_secret` | O nome do segredo de Kubernetes coas credenciais de OpenSearch | `""` |
| `dashboardUrl` | A URL pública do panel de AxonOps | `""` |
| `apiIngress.enabled` | Activa o ingress da API | `false` |
| `agentIngress.enabled` | Activa o ingress dos axentes | `false` |
| `persistence.enabled` | Activa o almacenamento persistente | `true` |
| `persistence.size` | O tamaño do volume persistente | `1Gi` |

### Notas importantes

**A chave de licenza:**
- Fai falta unha chave de licenza de AxonOps válida para uso en produción
- Contacte con AxonOps en <info@axonops.com> para obter unha licenza

**O segredo de configuración externo:**
- Use `configurationSecret` para referenciar un segredo externo no canto de xerar un automaticamente
- É útil en fluxos GitOps e con ferramentas de xestión de segredos (Sealed Secrets, External Secrets, etc.)
- Cando se define, ignóranse todos os valores `config.*` e `searchDb.*` de Helm

**As conexións ás bases de datos:**
- O servidor precisa conexión coas bases de datos de series temporais e de busca
- Asegúrese de que as bases de datos están en marcha e accesibles antes de despregar o servidor
- Use nomes de servizo para as bases de datos dentro do clúster, ou FQDN para as externas

**O número de réplicas:**
- Actualmente só se admite 1 réplica
- A alta dispoñibilidade conséguese co StatefulSet e o almacenamento persistente

**Os modos TLS:**
- `disabled`: sen TLS (só desenvolvemento)
- `TLS`: cifrado TLS do lado do servidor
- `mTLS`: TLS mutuo (require certificados de cliente nos axentes)

### Referencia completa de values

<details>
<summary>Prema para despregar a táboa completa de values</summary>

| Chave | Tipo | Valor por defecto | Descrición |
|-----|------|---------|-------------|
| affinity | object | `{}` | Regras de afinidade de pod |
| agentIngress.annotations | object | `{}` | Anotacións do ingress de axentes |
| agentIngress.className | string | `"nginx"` | A clase de ingress dos axentes |
| agentIngress.enabled | bool | `false` | Activa o ingress de axentes |
| agentIngress.hosts | list | `[{"host":"agents.example.com","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Os hosts do ingress de axentes |
| agentIngress.tls | list | `[]` | Configuración de TLS do ingress de axentes |
| agentService.annotations | object | `{}` | Anotacións do servizo de axentes |
| agentService.listenPort | int | `1888` | O porto do servizo de axentes |
| agentService.type | string | `"ClusterIP"` | O tipo do servizo de axentes |
| apiIngress.annotations | object | `{}` | Anotacións do ingress da API |
| apiIngress.className | string | `"traefik"` | A clase de ingress da API |
| apiIngress.enabled | bool | `false` | Activa o ingress da API |
| apiIngress.hosts | list | `[{"host":"api.example.com","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Os hosts do ingress da API |
| apiIngress.tls | list | `[]` | Configuración de TLS do ingress da API |
| apiService.annotations | object | `{}` | Anotacións do servizo da API |
| apiService.listenPort | int | `8080` | O porto do servizo da API |
| apiService.type | string | `"ClusterIP"` | O tipo do servizo da API |
| configurationSecret | string | `""` | O nome do segredo externo coa configuración axon-server.yml |
| config.alerting.notification_interval | string | `"3h"` | O intervalo de notificación de alertas |
| config.auth.enabled | bool | `false` | Activa a autenticación |
| config.db_secret | string | `""` | O nome do segredo de Kubernetes coas credenciais de Cassandra (chaves: AXONOPS_DB_USER, AXONOPS_DB_PASSWORD) |
| config.extraConfig | object | `{}` | Opcións de configuración adicionais |
| config.license_key | string | `""` | A chave de licenza de AxonOps |
| config.listener.agents_port | int | `1888` | O porto de escoita dos axentes |
| config.listener.api_port | int | `8080` | O porto de escoita da API |
| config.listener.host | string | `"0.0.0.0"` | O host de escoita |
| config.org_name | string | `"example"` | O nome da organización |
| config.sslSecretName | string | `""` | O nome do segredo cos certificados SSL |
| config.tls.mode | string | `"disabled"` | O modo TLS (disabled, TLS, mTLS) |
| dashboardUrl | string | `""` | A URL pública do panel |
| deployment.annotations | object | `{}` | Anotacións do deployment |
| deployment.env | object | `{}` | Variables de entorno adicionais |
| deployment.secretEnv | string | `""` | O segredo que contén as variables de entorno |
| extraVolumeMounts | list | `[]` | Montaxes de volume adicionais |
| extraVolumes | list | `[]` | Volumes adicionais |
| fullnameOverride | string | `""` | Substitúe o nome completo do recurso |
| image.pullPolicy | string | `"IfNotPresent"` | Política de descarga da imaxe |
| image.repository | string | `"registry.axonops.com/axonops-public/axonops-docker/axon-server"` | O repositorio da imaxe |
| image.tag | string | `""` | A etiqueta da imaxe (por defecto, a appVersion) |
| imagePullSecrets | list | `[]` | Segredos de descarga de imaxes |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":5}` | Configuración da sonda de vida |
| nameOverride | string | `""` | Substitúe o nome do chart |
| nodeSelector | object | `{}` | Etiquetas de nodo para asignar os pods |
| persistence.accessMode | string | `"ReadWriteOnce"` | O modo de acceso da PVC |
| persistence.annotations | object | `{}` | Anotacións da PVC |
| persistence.enableInitChown | bool | `true` | Activa un contedor de inicialización que fixa a propiedade |
| persistence.enabled | bool | `true` | Activa o almacenamento persistente |
| persistence.size | string | `"1Gi"` | O tamaño do volume persistente |
| persistence.storageClass | string | `""` | O nome da clase de almacenamento |
| podAnnotations | object | `{}` | Anotacións dos pods |
| podLabels | object | `{}` | Etiquetas dos pods |
| podSecurityContext.enabled | bool | `false` | Activa o contexto de seguridade do pod |
| podSecurityContext.fsGroup | int | `9988` | O FSGroup do pod |
| podSecurityContext.runAsNonRoot | bool | `true` | Executa como usuario non root |
| podSecurityContext.runAsUser | int | `9988` | O ID de usuario co que se executa o pod |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":3}` | Configuración da sonda de dispoñibilidade |
| resources | object | `{}` | Peticións e límites de recursos |
| searchDb.hosts | list | `[]` | Os hosts da base de datos de busca |
| searchDb.password | string | `""` | O contrasinal da base de datos de busca |
| searchDb.search_secret | string | `""` | O nome do segredo de Kubernetes coas credenciais de OpenSearch (chaves: AXONOPS_SEARCH_USER, AXONOPS_SEARCH_PASSWORD) |
| searchDb.skip_verify | bool | `true` | Omite a verificación TLS da base de datos de busca |
| searchDb.username | string | `""` | O usuario da base de datos de busca |
| securityContext | object | `{"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":false,"runAsNonRoot":true,"runAsUser":9988}` | O contexto de seguridade do contedor |
| serviceAccount.annotations | object | `{}` | Anotacións da conta de servizo |
| serviceAccount.automount | bool | `true` | Monta automaticamente o token da conta de servizo |
| serviceAccount.create | bool | `true` | Crea a conta de servizo |
| serviceAccount.createClusterRole | bool | `false` | Crea o cluster role |
| serviceAccount.name | string | `""` | O nome da conta de servizo |
| startupProbe | object | `{"failureThreshold":60,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":0,"periodSeconds":2,"timeoutSeconds":3}` | Configuración da sonda de arranque |
| tolerations | list | `[]` | Tolerancias para asignar os pods |
| updateStrategy.type | string | `"RollingUpdate"` | O tipo de estratexia de actualización |

</details>

## Actualización

Para actualizar unha instalación existente:

```bash
# Update the chart
helm upgrade axon-server ./axon-server -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axon-server
```

**Notas importantes:**
- Revise sempre o changelog antes de actualizar
- Probe primeiro as actualizacións fóra de produción
- Faga copia de seguranza do volume persistente antes de actualizar
- O servidor pode quedar brevemente non dispoñible durante a actualización

## Desinstalación

Para eliminar o servidor de AxonOps:

```bash
# Uninstall the release
helm uninstall axon-server

# Optional: Delete PVC (this will delete server data!)
kubectl delete pvc -l app.kubernetes.io/name=axon-server
```

**Aviso:** borrar a PVC elimina:
- A configuración do servidor
- Os datos de usuario (se non usa LDAP)
- O histórico de alertas e o estado das notificacións

## Resolución de problemas

### Problemas habituais

**1. O servidor non conecta coas bases de datos**

Revise a conectividade coas bases de datos:
```bash
# Get server pod logs
kubectl logs axon-server-0

# Look for connection errors
kubectl logs axon-server-0 | grep -i "error\|connection\|failed"
```

Causas habituais:
- Nomes de host ou de servizo de base de datos incorrectos
- Credenciais equivocadas (revise o usuario e o contrasinal)
- A base de datos non está lista (asegúrese de que arranca antes)
- Network policies que bloquean as conexións

**2. Erros da chave de licenza**

Se ve erros de licenza:
```bash
# Check if license key is set
kubectl get statefulset axon-server -o yaml | grep -A 5 license_key
```

- Asegúrese de que `config.license_key` está definido nos values
- Contacte con AxonOps para conseguir unha chave de licenza válida
- Comprobe que non hai erratas nin espazos de máis na chave

**3. Os axentes non conectan**

Revise a conectividade dos axentes:
```bash
# Check agent service
kubectl get svc axon-server-agents

# Check if port is accessible
kubectl port-forward svc/axon-server-agents 1888:1888

# In another terminal
telnet localhost 1888
```

Causas habituais:
- Os axentes usan un nome de host ou un porto equivocados
- Discrepancia no modo TLS (o servidor en TLS e os axentes sen configurar)
- Network policies ou cortalumes que bloquean o porto 1888
- O ingress non está ben configurado para os axentes externos

**4. O panel non pode conectar coa API**

Verifique o servizo da API:
```bash
# Check API service
kubectl get svc axon-server-api

# Test API health
kubectl port-forward svc/axon-server-api 8080:8080
curl http://localhost:8080/api/v1/healthz
```

Se usa ingress:
```bash
# Check ingress configuration
kubectl get ingress

# Test external access
curl https://api.axonops.example.com/api/v1/healthz
```

**5. A autenticación LDAP falla**

Revise a configuración de LDAP:
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

Probe a conectividade con LDAP:
```bash
# From within the pod
kubectl exec -it axon-server-0 -- sh
# Try to connect to LDAP server
nc -zv ldap.example.com 636
```

**6. Uso alto de memoria**

Revise o uso de recursos:
```bash
kubectl top pod axon-server-0
```

Suba os recursos se fai falta:
```yaml
resources:
  limits:
    memory: 4Gi
  requests:
    memory: 2Gi
```

**7. Problemas co volume persistente**

Revise o estado da PVC:
```bash
kubectl get pvc
kubectl describe pvc data-axon-server-0
```

Se a PVC está en Pending:
- Comprobe que a StorageClass existe e é a de por defecto
- Comprobe que hai cota de almacenamento abonda
- Asegúrese de que o aprovisionamento dinámico está activado

**8. Problemas cos certificados TLS**

Para os problemas de TLS/mTLS:
```bash
# Check if secret exists
kubectl get secret axon-server-tls

# Verify secret contains required keys
kubectl describe secret axon-server-tls

# Check server logs for TLS errors
kubectl logs axon-server-0 | grep -i tls
```

Asegúrese de que os certificados:
- Están en formato PEM
- Teñen os permisos correctos
- Non caducaron
- Corresponden ao nome de host do servidor

### Obter axuda

Para soporte adicional:

- **Revise os rexistros:** `kubectl logs -f axon-server-0`
- **Consulte os eventos:** `kubectl get events --sort-by='.lastTimestamp'`
- **Describa o pod:** `kubectl describe pod axon-server-0`
- **Probe o endpoint de saúde:**
  ```bash
  kubectl port-forward svc/axon-server-api 8080:8080
  curl http://localhost:8080/api/v1/healthz
  ```
- **Documentación:** <https://docs.axonops.com>
- **Soporte:** <info@axonops.com>
- **Comunidade:** <https://community.axonops.com>

## Mantedores

| Nome | Correo | URL |
| ---- | ------ | --- |
| O equipo de AxonOps | <info@axonops.com> | <https://axonops.com> |

## Código fonte

* <https://github.com/axonops/axonops-containers>

---

*Xerado cos charts de Helm de AxonOps*
