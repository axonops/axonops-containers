# AxonOps Server

[English](README.md) | **Français** | [Español](README.es.md) | [Galego](README.gl.md)

![Version: 2.1.3](https://img.shields.io/badge/Version-2.1.3-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

Un chart Helm pour déployer AxonOps Server — la plateforme d'observabilité unifiée d'Apache Cassandra. AxonOps Server est le composant central : il collecte les métriques et les logs des clusters Cassandra, les stocke dans les bases time-series et de recherche, et expose les API du dashboard AxonOps.

**Site web :** <https://axonops.com>

## Table des matières

- [Vue d'ensemble de l'architecture](#vue-densemble-de-larchitecture)
- [Prérequis](#prérequis)
- [Démarrage rapide](#démarrage-rapide)
- [Exemples d'installation](#exemples-dinstallation)
  - [Installation de base](#installation-de-base)
  - [Installation avec des bases externes](#installation-avec-des-bases-externes)
  - [Installation avec les identifiants de base dans des secrets](#installation-avec-les-identifiants-de-base-dans-des-secrets)
  - [Installation avec un secret de configuration externe](#installation-avec-un-secret-de-configuration-externe)
  - [Installation avec Ingress](#installation-avec-ingress)
  - [Installation avec TLS/mTLS](#installation-avec-tlsmtls)
  - [Installation avec authentification LDAP](#installation-avec-authentification-ldap)
  - [Installation prête pour la production](#installation-prête-pour-la-production)
- [Configuration](#configuration)
- [Mise à jour](#mise-à-jour)
- [Désinstallation](#désinstallation)
- [Dépannage](#dépannage)

## Vue d'ensemble de l'architecture

AxonOps Server est le composant central de la plateforme AxonOps :

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

## Prérequis

Avant de commencer, assurez-vous de disposer de ce qui suit :

### Composants obligatoires

- **Un cluster Kubernetes** : version 1.19 ou ultérieure
- **kubectl** : configuré pour dialoguer avec votre cluster
- **Helm** : version 3.0 ou ultérieure ([guide d'installation](https://helm.sh/docs/intro/install/))
- **AxonDB Timeseries** : déjà déployé ([guide d'installation](../axondb-timeseries/))
- **AxonDB Search** : déjà déployé ([guide d'installation](../axondb-search/))
- **Une clé de licence AxonOps** : contactez AxonOps pour l'obtenir

### Composants optionnels

- **Un contrôleur Ingress** : nécessaire pour un accès externe à l'API ou aux agents
- **cert-manager** : pour la gestion automatique des certificats TLS
- **Un serveur LDAP** : si vous utilisez l'authentification LDAP

### Vérifier votre installation

Vérifiez que les bases de données tournent :
```bash
# Check timeseries database
kubectl get pods -l app.kubernetes.io/name=axondb-timeseries

# Check search database
kubectl get pods -l app.kubernetes.io/name=axondb-search
```

Vérifiez que Helm est installé :
```bash
helm version
```

## Démarrage rapide

Le moyen le plus rapide de démarrer avec AxonOps Server :

```bash
# Install with default settings (connects to local databases)
helm install axon-server ./axon-server \
  --set config.license_key="YOUR_LICENSE_KEY" \
  --set config.org_name="your-organization"

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axon-server
```

Cela déploie AxonOps Server avec :
- une connexion aux instances AxonDB locales
- aucun accès externe (services ClusterIP)
- l'authentification par défaut (désactivée)
- 1 Gi de stockage persistant

## Exemples d'installation

### Installation de base

Installation minimale, adaptée au développement et aux tests :

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

Installation :

```bash
helm install axon-server ./axon-server -f values-basic.yaml
```

### Installation avec des bases externes

Configurez les connexions vers des instances de bases de données externes :

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

**Si vous utilisez des certificats TLS pour la connexion Cassandra :**

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

Installation :

```bash
helm install axon-server ./axon-server -f values-external-dbs.yaml
```

### Installation avec les identifiants de base dans des secrets

Plutôt que de placer les identifiants de base de données directement dans les values Helm, vous pouvez référencer des Secrets Kubernetes externes, pour Cassandra (time-series) comme pour OpenSearch. C'est l'approche recommandée en production.

Créez les secrets d'identifiants :

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

Configurez les values Helm pour référencer ces secrets :

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

Installez le chart :

```bash
helm install axon-server ./axon-server -f values-db-secrets.yaml
```

Points importants :

- lorsque `config.db_secret` est défini, les identifiants Cassandra sont injectés comme variables d'environnement (`CQL_USERNAME`, `CQL_PASSWORD`)
- lorsque `searchDb.search_secret` est défini, les identifiants OpenSearch sont injectés comme variables d'environnement (`SEARCH_DB_USERNAME`, `SEARCH_DB_PASSWORD`)
- les valeurs en ligne `cql_username`/`cql_password` et `searchDb.username`/`searchDb.password` sont ignorées lorsque des secrets sont utilisés
- les noms de clés du secret OpenSearch (`AXONOPS_SEARCH_USER`, `AXONOPS_SEARCH_PASSWORD`) sont compatibles avec le chart axondb-search, ce qui permet de partager le même secret entre les deux charts

### Installation avec un secret de configuration externe

Plutôt que de laisser le chart générer automatiquement un Secret contenant la configuration d'axon-server, vous pouvez désigner un Secret Kubernetes préexistant via la value `configurationSecret`. Dans ce cas :

- le chart **ne crée pas** son propre Secret de configuration — il s'attend à ce que le Secret existe déjà dans le cluster ;
- le Secret doit contenir une clé nommée **`axon-server.yml`**, avec la configuration axon-server **complète** au format YAML ;
- **toutes les values `config.*` et `searchDb.*` de Helm sont ignorées** — le Secret externe est l'unique source de configuration ;
- les values hors configuration (ressources, persistance, ingress, services, sondes, etc.) continuent de fonctionner normalement.

Cette approche est utile lorsque :

- vous gérez les secrets avec des outils externes (vals-operator, Sealed Secrets, External Secrets Operator, etc.)
- vous devez partager une configuration entre plusieurs déploiements
- vous voulez versionner séparément des secrets chiffrés
- vous suivez un workflow GitOps où les secrets sont gérés en dehors des values Helm

**Étape 1 : créer votre secret de configuration**

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

Appliquez le secret :

```bash
kubectl apply -f axon-server-config-secret.yaml
```

**Étape 2 : créer le fichier de values qui référence le secret externe**

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

**Étape 3 : installer avec le secret externe**

```bash
helm install axon-server ./axon-server -f values-external-secret.yaml
```

**Points importants :**
- lorsque `configurationSecret` est défini, le chart ne crée PAS sa propre ressource Secret
- le secret externe doit contenir une clé `axon-server.yml` avec la configuration complète
- toute la configuration qui irait normalement dans les values `config.*` doit se trouver dans le secret externe
- les values `searchDb.*` de Helm sont ignorées lorsqu'un secret externe est utilisé
- vous pouvez toujours configurer les autres values Helm : ressources, persistance, ingress, etc.

**Vérifier le déploiement :**

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

### Installation avec Ingress

Exposer les API d'AxonOps Server vers l'extérieur via un Ingress :

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

Installation :

```bash
helm install axon-server ./axon-server -f values-ingress.yaml
```

### Installation avec TLS/mTLS

Configurer TLS ou le TLS mutuel pour les connexions des agents :

**Étape 1 : créer le secret TLS**

```bash
kubectl create secret generic axon-server-tls \
  --from-file=tls.crt=path/to/server.crt \
  --from-file=tls.key=path/to/server.key \
  --from-file=ca.crt=path/to/ca.crt
```

**Étape 2 : créer le fichier de values**

**Pour TLS :**

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

**Pour mTLS (TLS mutuel) :**

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

Installation :

```bash
# For TLS
helm install axon-server ./axon-server -f values-tls.yaml

# OR for mTLS
helm install axon-server ./axon-server -f values-mtls.yaml
```

### Installation avec authentification LDAP

Configurer l'authentification LDAP / Active Directory :

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

Installation :

```bash
helm install axon-server ./axon-server -f values-ldap.yaml
```

### Installation prête pour la production

Une configuration de production complète, avec tous les réglages recommandés :

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

**Avant l'installation :**

```bash
# Create TLS secret for server
kubectl create secret generic axon-server-tls \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key \
  --from-file=ca.crt=path/to/ca.crt \
  -n production
```

**Installer le déploiement de production :**

```bash
helm install axon-server ./axon-server \
  -f values-production.yaml \
  --namespace production \
  --create-namespace
```

**Vérifier le déploiement :**

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

## Configuration

### Principales options de configuration

| Paramètre | Description | Défaut |
|-----------|-------------|---------|
| `configurationSecret` | Nom du Secret externe contenant la configuration axon-server.yml | `""` |
| `config.org_name` | Nom de l'organisation | `"example"` |
| `config.license_key` | Clé de licence AxonOps (obligatoire) | `""` |
| `config.listener.api_port` | Port de l'API, pour les connexions du dashboard | `8080` |
| `config.listener.agents_port` | Port des connexions des agents | `1888` |
| `config.tls.mode` | Mode TLS : disabled, TLS, mTLS | `"disabled"` |
| `config.auth.enabled` | Activer l'authentification | `false` |
| `config.extraConfig.cql_hosts` | Hôtes Cassandra de la base time-series | `[]` |
| `config.extraConfig.cql_username` | Nom d'utilisateur Cassandra | `""` |
| `config.db_secret` | Nom du secret Kubernetes portant les identifiants Cassandra | `""` |
| `searchDb.hosts` | Hôtes de la base de recherche | `[]` |
| `searchDb.username` | Nom d'utilisateur de la base de recherche | `""` |
| `searchDb.search_secret` | Nom du secret Kubernetes portant les identifiants OpenSearch | `""` |
| `dashboardUrl` | URL publique du dashboard AxonOps | `""` |
| `apiIngress.enabled` | Activer l'ingress de l'API | `false` |
| `agentIngress.enabled` | Activer l'ingress des agents | `false` |
| `persistence.enabled` | Activer le stockage persistant | `true` |
| `persistence.size` | Taille du volume persistant | `1Gi` |

### Points importants

**Clé de licence :**
- une clé de licence AxonOps valide est obligatoire en production
- contactez AxonOps à <info@axonops.com> pour l'obtenir

**Secret de configuration externe :**
- utilisez `configurationSecret` pour référencer un Secret externe plutôt que d'en générer un automatiquement
- pratique pour les workflows GitOps et les outils de gestion de secrets (Sealed Secrets, External Secrets, etc.)
- lorsqu'il est défini, toutes les values `config.*` et `searchDb.*` de Helm sont ignorées

**Connexions aux bases de données :**
- le serveur a besoin d'une connexion à la base time-series comme à la base de recherche
- assurez-vous que les bases tournent et sont joignables avant de déployer le serveur
- utilisez les noms de services pour les bases internes au cluster, ou des FQDN pour les bases externes

**Nombre de réplicas :**
- un seul réplica est pris en charge pour l'instant
- la disponibilité repose sur le StatefulSet et le stockage persistant

**Modes TLS :**
- `disabled` : pas de TLS (développement uniquement)
- `TLS` : chiffrement TLS côté serveur
- `mTLS` : TLS mutuel (exige des certificats client sur les agents)

### Référence complète des values

<details>
<summary>Cliquez pour dérouler le tableau complet des values</summary>

| Clé | Type | Défaut | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Règles d'affinité de pods |
| agentIngress.annotations | object | `{}` | Annotations de l'ingress des agents |
| agentIngress.className | string | `"nginx"` | Classe d'ingress des agents |
| agentIngress.enabled | bool | `false` | Activer l'ingress des agents |
| agentIngress.hosts | list | `[{"host":"agents.example.com","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Hôtes de l'ingress des agents |
| agentIngress.tls | list | `[]` | Configuration TLS de l'ingress des agents |
| agentService.annotations | object | `{}` | Annotations du service des agents |
| agentService.listenPort | int | `1888` | Port du service des agents |
| agentService.type | string | `"ClusterIP"` | Type du service des agents |
| apiIngress.annotations | object | `{}` | Annotations de l'ingress de l'API |
| apiIngress.className | string | `"traefik"` | Classe d'ingress de l'API |
| apiIngress.enabled | bool | `false` | Activer l'ingress de l'API |
| apiIngress.hosts | list | `[{"host":"api.example.com","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Hôtes de l'ingress de l'API |
| apiIngress.tls | list | `[]` | Configuration TLS de l'ingress de l'API |
| apiService.annotations | object | `{}` | Annotations du service de l'API |
| apiService.listenPort | int | `8080` | Port du service de l'API |
| apiService.type | string | `"ClusterIP"` | Type du service de l'API |
| configurationSecret | string | `""` | Nom du Secret externe contenant la configuration axon-server.yml |
| config.alerting.notification_interval | string | `"3h"` | Intervalle de notification des alertes |
| config.auth.enabled | bool | `false` | Activer l'authentification |
| config.db_secret | string | `""` | Nom du secret Kubernetes portant les identifiants Cassandra (clés : AXONOPS_DB_USER, AXONOPS_DB_PASSWORD) |
| config.extraConfig | object | `{}` | Options de configuration supplémentaires |
| config.license_key | string | `""` | Clé de licence AxonOps |
| config.listener.agents_port | int | `1888` | Port d'écoute des agents |
| config.listener.api_port | int | `8080` | Port d'écoute de l'API |
| config.listener.host | string | `"0.0.0.0"` | Hôte d'écoute |
| config.org_name | string | `"example"` | Nom de l'organisation |
| config.sslSecretName | string | `""` | Nom du secret contenant les certificats SSL |
| config.tls.mode | string | `"disabled"` | Mode TLS (disabled, TLS, mTLS) |
| dashboardUrl | string | `""` | URL publique du dashboard |
| deployment.annotations | object | `{}` | Annotations du déploiement |
| deployment.env | object | `{}` | Variables d'environnement supplémentaires |
| deployment.secretEnv | string | `""` | Secret contenant des variables d'environnement |
| extraVolumeMounts | list | `[]` | Montages de volumes supplémentaires |
| extraVolumes | list | `[]` | Volumes supplémentaires |
| fullnameOverride | string | `""` | Remplacer le nom complet des ressources |
| image.pullPolicy | string | `"IfNotPresent"` | Politique de pull de l'image |
| image.repository | string | `"registry.axonops.com/axonops-public/axonops-docker/axon-server"` | Dépôt de l'image |
| image.tag | string | `""` | Tag de l'image (par défaut, appVersion) |
| imagePullSecrets | list | `[]` | Secrets de pull d'image |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":30,"periodSeconds":10,"timeoutSeconds":5}` | Configuration de la sonde de liveness |
| nameOverride | string | `""` | Remplacer le nom du chart |
| nodeSelector | object | `{}` | Labels de nœud pour l'affectation des pods |
| persistence.accessMode | string | `"ReadWriteOnce"` | Mode d'accès du PVC |
| persistence.annotations | object | `{}` | Annotations du PVC |
| persistence.enableInitChown | bool | `true` | Activer l'init container qui ajuste les droits |
| persistence.enabled | bool | `true` | Activer le stockage persistant |
| persistence.size | string | `"1Gi"` | Taille du volume persistant |
| persistence.storageClass | string | `""` | Nom de la storage class |
| podAnnotations | object | `{}` | Annotations des pods |
| podLabels | object | `{}` | Labels des pods |
| podSecurityContext.enabled | bool | `false` | Activer le contexte de sécurité du pod |
| podSecurityContext.fsGroup | int | `9988` | FSGroup du pod |
| podSecurityContext.runAsNonRoot | bool | `true` | Exécuter sous un utilisateur non root |
| podSecurityContext.runAsUser | int | `9988` | UID d'exécution du pod |
| readinessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":10,"periodSeconds":5,"timeoutSeconds":3}` | Configuration de la sonde de readiness |
| resources | object | `{}` | Limites et requêtes de ressources |
| searchDb.hosts | list | `[]` | Hôtes de la base de recherche |
| searchDb.password | string | `""` | Mot de passe de la base de recherche |
| searchDb.search_secret | string | `""` | Nom du secret Kubernetes portant les identifiants OpenSearch (clés : AXONOPS_SEARCH_USER, AXONOPS_SEARCH_PASSWORD) |
| searchDb.skip_verify | bool | `true` | Ignorer la vérification TLS de la base de recherche |
| searchDb.username | string | `""` | Nom d'utilisateur de la base de recherche |
| securityContext | object | `{"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":false,"runAsNonRoot":true,"runAsUser":9988}` | Contexte de sécurité du conteneur |
| serviceAccount.annotations | object | `{}` | Annotations du service account |
| serviceAccount.automount | bool | `true` | Monter automatiquement le token du service account |
| serviceAccount.create | bool | `true` | Créer le service account |
| serviceAccount.createClusterRole | bool | `false` | Créer le cluster role |
| serviceAccount.name | string | `""` | Nom du service account |
| startupProbe | object | `{"failureThreshold":60,"httpGet":{"path":"/api/v1/healthz","port":"api"},"initialDelaySeconds":0,"periodSeconds":2,"timeoutSeconds":3}` | Configuration de la sonde de démarrage |
| tolerations | list | `[]` | Tolerations pour l'affectation des pods |
| updateStrategy.type | string | `"RollingUpdate"` | Type de stratégie de mise à jour |

</details>

## Mise à jour

Pour mettre à jour une installation existante :

```bash
# Update the chart
helm upgrade axon-server ./axon-server -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axon-server
```

**Points importants :**
- relisez toujours le changelog avant une mise à jour
- testez d'abord les mises à jour hors production
- sauvegardez le volume persistant avant de mettre à jour
- le serveur peut être brièvement indisponible pendant l'opération

## Désinstallation

Pour supprimer AxonOps Server :

```bash
# Uninstall the release
helm uninstall axon-server

# Optional: Delete PVC (this will delete server data!)
kubectl delete pvc -l app.kubernetes.io/name=axon-server
```

**Avertissement :** supprimer le PVC efface :
- la configuration du serveur
- les données utilisateurs (si vous n'utilisez pas LDAP)
- l'historique des alertes et l'état des notifications

## Dépannage

### Problèmes courants

**1. Le serveur ne se connecte pas aux bases de données**

Vérifiez la connectivité aux bases :
```bash
# Get server pod logs
kubectl logs axon-server-0

# Look for connection errors
kubectl logs axon-server-0 | grep -i "error\|connection\|failed"
```

Causes fréquentes :
- noms d'hôtes ou de services de base incorrects
- mauvais identifiants (vérifiez le couple utilisateur / mot de passe)
- base non prête (assurez-vous que les bases tournent d'abord)
- des network policies bloquent les connexions

**2. Erreurs de clé de licence**

En cas d'erreur de licence :
```bash
# Check if license key is set
kubectl get statefulset axon-server -o yaml | grep -A 5 license_key
```

- vérifiez que `config.license_key` est renseigné dans les values
- contactez AxonOps pour obtenir une clé de licence valide
- vérifiez qu'il n'y a ni faute de frappe ni espace superflu dans la clé

**3. Les agents ne se connectent pas**

Vérifiez la connectivité des agents :
```bash
# Check agent service
kubectl get svc axon-server-agents

# Check if port is accessible
kubectl port-forward svc/axon-server-agents 1888:1888

# In another terminal
telnet localhost 1888
```

Causes fréquentes :
- les agents utilisent un mauvais nom d'hôte ou un mauvais port
- désaccord de mode TLS (serveur en TLS, agents non configurés)
- des network policies ou pare-feux bloquent le port 1888
- l'ingress est mal configuré pour les agents externes

**4. Le dashboard ne joint pas l'API**

Vérifiez le service de l'API :
```bash
# Check API service
kubectl get svc axon-server-api

# Test API health
kubectl port-forward svc/axon-server-api 8080:8080
curl http://localhost:8080/api/v1/healthz
```

Avec un ingress :
```bash
# Check ingress configuration
kubectl get ingress

# Test external access
curl https://api.axonops.example.com/api/v1/healthz
```

**5. L'authentification LDAP échoue**

Vérifiez la configuration LDAP :
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

Testez la connectivité LDAP :
```bash
# From within the pod
kubectl exec -it axon-server-0 -- sh
# Try to connect to LDAP server
nc -zv ldap.example.com 636
```

**6. Consommation mémoire élevée**

Vérifiez l'usage des ressources :
```bash
kubectl top pod axon-server-0
```

Augmentez les ressources si nécessaire :
```yaml
resources:
  limits:
    memory: 4Gi
  requests:
    memory: 2Gi
```

**7. Problèmes de volume persistant**

Vérifiez l'état du PVC :
```bash
kubectl get pvc
kubectl describe pvc data-axon-server-0
```

Si le PVC reste Pending :
- vérifiez que la StorageClass existe et qu'elle est par défaut
- vérifiez que le quota de stockage est suffisant
- assurez-vous que le provisionnement dynamique est activé

**8. Problèmes de certificats TLS**

Pour les problèmes TLS/mTLS :
```bash
# Check if secret exists
kubectl get secret axon-server-tls

# Verify secret contains required keys
kubectl describe secret axon-server-tls

# Check server logs for TLS errors
kubectl logs axon-server-0 | grep -i tls
```

Assurez-vous que les certificats :
- sont au format PEM
- ont les bonnes permissions
- ne sont pas expirés
- correspondent au nom d'hôte du serveur

### Obtenir de l'aide

Pour un support complémentaire :

- **Consultez les logs :** `kubectl logs -f axon-server-0`
- **Consultez les événements :** `kubectl get events --sort-by='.lastTimestamp'`
- **Décrivez le pod :** `kubectl describe pod axon-server-0`
- **Testez l'endpoint de santé :**
  ```bash
  kubectl port-forward svc/axon-server-api 8080:8080
  curl http://localhost:8080/api/v1/healthz
  ```
- **Documentation :** <https://docs.axonops.com>
- **Support :** <info@axonops.com>
- **Communauté :** <https://community.axonops.com>

## Mainteneurs

| Nom | E-mail | URL |
| ---- | ------ | --- |
| AxonOps Team | <info@axonops.com> | <https://axonops.com> |

## Code source

* <https://github.com/axonops/axonops-containers>

---

*Généré avec les charts Helm AxonOps*
