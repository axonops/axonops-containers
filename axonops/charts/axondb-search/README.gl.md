# Base de datos de busca de AxonOps

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

![Versión: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Tipo: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3.3.2-1.1.0](https://img.shields.io/badge/AppVersion-3.3.2--1.1.0-informational?style=flat-square)

Un chart de Helm para despregar a base de datos de busca de AxonOps sobre
Kubernetes. Esta base de datos dá soporte ás capacidades de indexación e busca da
plataforma AxonOps para rexistros, eventos e datos operativos.

**Páxina do proxecto:** <https://axonops.com>

## Índice

- [Requisitos previos](#requisitos-previos)
- [Inicio rápido](#inicio-rápido)
- [Exemplos de instalación](#exemplos-de-instalación)
  - [Instalación básica](#instalación-básica)
  - [Instalación con almacenamento personalizado](#instalación-con-almacenamento-personalizado)
  - [Instalación con autenticación](#instalación-con-autenticación)
  - [Instalación con TLS (certificados manuais)](#instalación-con-tls-certificados-manuais)
  - [Instalación con TLS (cert-manager)](#instalación-con-tls-cert-manager)
  - [Instalación dun clúster de varios nodos](#instalación-dun-clúster-de-varios-nodos)
  - [Instalación lista para produción](#instalación-lista-para-produción)
- [Configuración de copias de seguranza](#configuración-de-copias-de-seguranza)
  - [Copias de seguranza locais](#copias-de-seguranza-locais)
  - [Copias de seguranza en S3](#copias-de-seguranza-en-s3)
- [Xestión externa de segredos (vals-operator)](#xestión-externa-de-segredos-vals-operator)
- [Configuración](#configuración)
- [Actualización](#actualización)
- [Desinstalación](#desinstalación)
- [Resolución de problemas](#resolución-de-problemas)

## Requisitos previos

Antes de comezar, asegúrese de ter o seguinte:

- **Un clúster de Kubernetes**: versión 1.19 ou superior
- **kubectl**: configurado para comunicarse co seu clúster
- **Helm**: versión 3.0 ou superior instalada ([guía de instalación](https://helm.sh/docs/intro/install/))
- **Almacenamento**: unha StorageClass por defecto configurada no seu clúster, ou unha StorageClass concreta para os volumes persistentes
- **Recursos**: recoméndanse polo menos 4 GB de memoria dispoñible e 2 núcleos de CPU

### Requisitos previos opcionais

- **cert-manager**: só fai falta se quere xestión automática de certificados TLS ([guía de instalación](https://cert-manager.io/docs/installation/))
- **O Prometheus Operator**: só fai falta se quere activar a monitorización de métricas con ServiceMonitor

### Verificar a súa instalación

Comprobe que Helm está instalado:
```bash
helm version
```

Comprobe que kubectl está configurado:
```bash
kubectl cluster-info
```

Consulte as StorageClass dispoñibles:
```bash
kubectl get storageclass
```

## Inicio rápido

A forma máis rápida de comezar coa base de datos de busca de AxonOps:

```bash
# Add the AxonOps Helm repository (if available)
# helm repo add axonops https://axonops.github.io/helm-charts
# helm repo update

# Install with default settings (single-node mode)
helm install axondb-search ./axondb-search

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axondb-search
```

Isto desprega unha base de datos de busca dun só nodo con:
- 8 Gi de almacenamento persistente
- Os límites de recursos por defecto (4 GB de memoria, 1 CPU)
- Modo de descubrimento dun só nodo
- HTTPS activado por defecto
- Unha configuración de seguridade básica

## Exemplos de instalación

### Instalación básica

Instalación coa configuración mínima, apta para desenvolvemento e probas:

```bash
helm install axondb-search ./axondb-search \
  --set replicas=1 \
  --set singleNode=true
```

Ou cree un ficheiro `values-basic.yaml`:

```yaml
# values-basic.yaml
# Single-node configuration for development

replicas: 1
singleNode: true

# Increase heap size for better performance
opensearchHeapSize: "2g"

# Resource limits
resources:
  requests:
    cpu: 1000m
    memory: 4Gi
  limits:
    cpu: 2000m
    memory: 4Gi

# Persistent storage
persistence:
  enabled: true
  size: 10Gi
```

Instale usando o ficheiro de values:

```bash
helm install axondb-search ./axondb-search -f values-basic.yaml
```

### Instalación con almacenamento personalizado

Configure o almacenamento persistente cunha StorageClass e un tamaño concretos:

```yaml
# values-storage.yaml
replicas: 1
singleNode: true

# Heap size (should be ~50% of container memory)
opensearchHeapSize: "4g"

persistence:
  enabled: true
  # Use your cluster's StorageClass (e.g., gp3, standard, fast-ssd)
  # storageClass: "gp3"
  size: 50Gi
  accessModes:
    - ReadWriteOnce
  # Optional: Add annotations for the PVC
  annotations: {}
  # Optional: Enable volume labels
  labels:
    enabled: true
    additionalLabels:
      app: axondb-search
      environment: production

resources:
  requests:
    cpu: 2000m
    memory: 8Gi
  limits:
    cpu: 4000m
    memory: 8Gi
```

Instale:

```bash
helm install axondb-search ./axondb-search -f values-storage.yaml
```

### Instalación con autenticación

Protexa a súa base de datos de busca con credenciais de autenticación:

**Opción 1: valores directos (só desenvolvemento)**

```yaml
# values-auth.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

authentication:
  opensearch_user: "axonops"
  opensearch_password: "your-secure-password"
```

**Opción 2: segredos de Kubernetes (recomendado en produción)**

Primeiro, cree un segredo de Kubernetes:

```bash
kubectl create secret generic -n axonops axondb-search-credentials \
  --from-literal=AXONOPS_SEARCH_USER=axonops \
  --from-literal=AXONOPS_SEARCH_PASSWORD=secure-password
```

Despois cree o seu ficheiro de values:

```yaml
# values-auth-secret.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

authentication:
  opensearch_secret: "axondb-search-credentials"
```

Instale:

```bash
helm install axondb-search ./axondb-search -f values-auth-secret.yaml
```

### Instalación con TLS (certificados manuais)

Use certificados TLS xa existentes para cifrar a comunicación:

**Paso 1: cree un segredo cos seus certificados**

```bash
kubectl create secret generic axondb-search-tls-manual \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key \
  --from-file=ca.crt=path/to/ca.crt
```

**Paso 2: cree o seu ficheiro de values**

```yaml
# values-tls-manual.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

# Enable HTTPS protocol
protocol: https

tls:
  enabled: true
  manual:
    existingSecret: "axondb-search-tls-manual"

# Security configuration
securityConfig:
  enabled: true
```

Instale:

```bash
helm install axondb-search ./axondb-search -f values-tls-manual.yaml
```

### Instalación con TLS (cert-manager)

Xere e xestione os certificados TLS automaticamente con cert-manager:

**Requisitos previos:**
- cert-manager debe estar instalado no seu clúster

**Paso 1: instale cert-manager (se non o está xa)**

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

Agarde a que cert-manager estea listo:

```bash
kubectl wait --for=condition=Available --timeout=300s \
  deployment/cert-manager -n cert-manager
```

**Paso 2: cree o seu ficheiro de values**

**Con certificados autoasinados (desenvolvemento e probas):**

```yaml
# values-tls-certmanager-selfsigned.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

# Enable HTTPS protocol
protocol: https

tls:
  enabled: true
  certManager:
    enabled: true
    # Keystore password (change this!)
    keystorePassword: "my-secure-keystore-password"

    issuer:
      # Automatically create a self-signed issuer
      createSelfSigned: true
      kind: "ClusterIssuer"

    certificate:
      # Certificate will be valid for 5 years
      duration: 43800h
      # Renew 30 days before expiry
      renewBefore: 720h
      secretName: "axondb-search-tls-cert"

# Security configuration
securityConfig:
  enabled: true
```

**Cun issuer existente (produción):**

```yaml
# values-tls-certmanager-production.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

# Enable HTTPS protocol
protocol: https

tls:
  enabled: true
  certManager:
    enabled: true
    keystorePassword: "my-secure-keystore-password"

    issuer:
      # Use your existing ClusterIssuer
      name: "letsencrypt-prod"
      kind: "ClusterIssuer"
      createSelfSigned: false

    certificate:
      # Custom DNS names for the certificate
      commonName: "axondb-search.example.com"
      dnsNames:
        - "axondb-search.example.com"
        - "*.axondb-search.example.com"
      duration: 2160h  # 90 days
      renewBefore: 360h  # 15 days
      secretName: "axondb-search-tls-cert"

securityConfig:
  enabled: true
```

Instale:

```bash
# For self-signed certificates
helm install axondb-search ./axondb-search -f values-tls-certmanager-selfsigned.yaml

# OR for production with existing issuer
helm install axondb-search ./axondb-search -f values-tls-certmanager-production.yaml
```

**Verifique a creación do certificado:**

```bash
kubectl get certificate
kubectl describe certificate axondb-search-tls
```

### Instalación dun clúster de varios nodos

Despregue un clúster de varios nodos para alta dispoñibilidade e mellor
rendemento:

```yaml
# values-cluster.yaml
# Multi-node cluster configuration

# Disable single-node mode for clustering
singleNode: false

# Deploy 3 nodes for high availability
replicas: 3

clusterName: "axondb-search-cluster"

# Node roles (master, data, ingest)
roles:
  - master
  - ingest
  - data
  - remote_cluster_client

# Heap size per node
opensearchHeapSize: "4g"

# Resource allocation per node
resources:
  requests:
    cpu: 2000m
    memory: 8Gi
  limits:
    cpu: 4000m
    memory: 8Gi

# Persistent storage per node
persistence:
  enabled: true
  size: 50Gi
  accessModes:
    - ReadWriteOnce

# Anti-affinity to spread pods across nodes
antiAffinity: "hard"
antiAffinityTopologyKey: "kubernetes.io/hostname"

# Pod management policy
podManagementPolicy: "Parallel"

# Security configuration
securityConfig:
  enabled: true

# Node certificate DNs for inter-node security (multi-node clusters)
# Configures which certificate Distinguished Names can join the cluster
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.default.svc.cluster.local;CN=axondb-search-cluster-master-0;CN=axondb-search-cluster-master-1;CN=axondb-search-cluster-master-2"

# Service configuration
service:
  type: ClusterIP
  httpPortName: http
  transportPortName: transport
```

Instale:

```bash
helm install axondb-search ./axondb-search -f values-cluster.yaml
```

### Instalación lista para produción

Unha configuración de produción completa, con todos os axustes recomendados:

```yaml
# values-production.yaml
# Production configuration for AxonOps Search DB

# Multi-node cluster for high availability
singleNode: false
replicas: 3

clusterName: "axondb-search-production"

# Node roles
roles:
  - master
  - ingest
  - data
  - remote_cluster_client

# Heap size (50% of container memory)
opensearchHeapSize: "8g"

# Authentication using Kubernetes secrets
authentication:
  opensearch_secret: "axondb-search-credentials"

# Resource limits for production workloads
resources:
  requests:
    cpu: 2000m
    memory: 16Gi
  limits:
    cpu: 4000m
    memory: 16Gi

# Persistent storage configuration
persistence:
  enabled: true
  size: 100Gi
  accessModes:
    - ReadWriteOnce
  # storageClass: "gp3"  # Uncomment and set your StorageClass
  labels:
    enabled: true
    additionalLabels:
      environment: production

# TLS encryption with cert-manager
protocol: https
tls:
  enabled: true
  certManager:
    enabled: true
    keystorePassword: "change-this-secure-password"
    issuer:
      name: "letsencrypt-prod"
      kind: "ClusterIssuer"
      createSelfSigned: false
    certificate:
      commonName: "axondb-search.prod.example.com"
      dnsNames:
        - "axondb-search.prod.example.com"
        - "*.axondb-search.prod.example.com"
      duration: 2160h
      renewBefore: 360h

# Security configuration
securityConfig:
  enabled: true

# Node certificate DNs for inter-node security
# IMPORTANT: Configure this for multi-node clusters to control which nodes can join
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.prod.example.com;CN=axondb-search-production-0;CN=axondb-search-production-1;CN=axondb-search-production-2"

# Health check probes
startupProbe:
  tcpSocket:
    port: 9200
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 30

readinessProbe:
  tcpSocket:
    port: 9200
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# Pod security context
podSecurityContext:
  fsGroup: 999
  runAsUser: 999

securityContext:
  capabilities:
    drop:
      - ALL
  runAsNonRoot: true
  runAsUser: 999

# Service configuration
service:
  type: ClusterIP
  annotations: {}
  labels:
    environment: production

# Anti-affinity rules to spread pods across nodes
antiAffinity: "hard"
antiAffinityTopologyKey: "kubernetes.io/hostname"

# Pod management policy (Parallel for faster startup)
podManagementPolicy: "Parallel"

# System settings
sysctlVmMaxMapCount: 262144
sysctlInit:
  enabled: false  # Set to true if not configured at OS level

# Graceful shutdown period
terminationGracePeriod: 120

# Enable Prometheus monitoring (requires prometheus-exporter plugin)
serviceMonitor:
  enabled: false  # Enable after installing prometheus-exporter plugin
  interval: 30s
  path: /_prometheus/metrics
  scheme: https
  labels:
    prometheus: kube-prometheus

# Network policy (optional)
networkPolicy:
  create: false

# Tolerations for dedicated nodes (optional)
# tolerations:
#   - key: "workload"
#     operator: "Equal"
#     value: "search"
#     effect: "NoSchedule"

# Node selector for dedicated nodes (optional)
# nodeSelector:
#   workload: search
```

**Antes de instalar, cree o segredo de autenticación:**

```bash
kubectl create secret generic axondb-search-credentials \
  --from-literal=OPENSEARCH_USER=axonops \
  --from-literal=OPENSEARCH_PASSWORD=$(openssl rand -base64 32)
```

**Instale o despregamento de produción:**

```bash
helm install axondb-search ./axondb-search \
  -f values-production.yaml \
  --namespace axonops \
  --create-namespace
```

**Verifique que o clúster está san:**

```bash
# Check all pods are running
kubectl get pods -l app.kubernetes.io/name=axondb-search -n axonops

# Check cluster health (port-forward to access)
kubectl port-forward svc/axondb-search-cluster-master 9200:9200 -n axonops

# In another terminal (if using default credentials)
curl -k -u admin:ChangeThisSecurePassword123! https://localhost:9200/_cluster/health
```

## Configuración de copias de seguranza

O chart axondb-search inclúe funcionalidade de copias de seguranza integrada,
baseada en snapshots de OpenSearch. As copias poden gardarse en local ou en
almacenamento compatible con S3.

### Copias de seguranza locais

Configure copias no sistema de ficheiros local cunha PVC dedicada:

```yaml
# values-backup-local.yaml
backups:
  enabled: true
  schedule: "0 8 * * *"  # Daily at 8am UTC

  # Snapshot retention
  retention:
    days: 30
    count: ""  # Optional: max number of snapshots

  # Local backup target
  target:
    type: local
    local:
      path: "/mnt/backups"
      size: "50Gi"
      storageClass: ""  # Uses default storage class
```

Instale:

```bash
helm install axondb-search ./axondb-search -f values-backup-local.yaml
```

### Copias de seguranza en S3

Configure as copias cara a AWS S3 ou cara a almacenamento compatible con S3
(MinIO, Ceph, etc.):

#### Con AWS S3

```yaml
# values-backup-s3.yaml
backups:
  enabled: true
  schedule: "0 */6 * * *"  # Every 6 hours

  retention:
    days: 30

  target:
    type: s3
    s3:
      bucket: "my-opensearch-backups"
      region: "us-east-1"
      basePath: "axondb-search"

      # Method 1: Use existing Kubernetes secret (recommended)
      credentials:
        existingSecret: "aws-backup-credentials"
        # Secret must contain keys: aws-access-key-id, aws-secret-access-key

      # Method 2: Inline credentials (NOT recommended for production)
      # credentials:
      #   accessKeyId: "AKIAIOSFODNN7EXAMPLE"
      #   secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

Cree o segredo coas credenciais:

```bash
kubectl create secret generic aws-backup-credentials \
  --from-literal=aws-access-key-id=AKIAIOSFODNN7EXAMPLE \
  --from-literal=aws-secret-access-key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

#### Con almacenamento compatible con S3 (MinIO)

```yaml
# values-backup-minio.yaml
backups:
  enabled: true
  schedule: "0 */4 * * *"

  target:
    type: s3
    s3:
      bucket: "opensearch-backups"
      endpoint: "http://minio.minio.svc.cluster.local:9000"
      pathStyleAccess: true  # Required for MinIO

      credentials:
        existingSecret: "minio-credentials"
```

#### Con roles de IAM de AWS (EKS con IRSA)

Para clústeres de EKS con IAM Roles for Service Accounts:

```yaml
# values-backup-irsa.yaml
backups:
  enabled: true
  target:
    type: s3
    s3:
      bucket: "my-opensearch-backups"
      region: "us-east-1"
      # Leave credentials empty for IRSA

rbac:
  create: true
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/opensearch-backup-role
```

## Xestión externa de segredos (vals-operator)

O chart admite [vals-operator](https://github.com/digitalis-io/vals-operator) para
obter segredos de almacéns externos como AWS Secrets Manager, HashiCorp Vault,
Google Secret Manager e Azure Key Vault.

### Instalar vals-operator

Instale vals-operator no seu clúster:

```bash
helm repo add digitalis https://digitalis-io.github.io/helm-charts
helm install vals-operator digitalis/vals-operator
```

### Configuración de vals-operator

```yaml
# values-vals.yaml
vals:
  enabled: true
  ttl: 3600  # Refresh interval in seconds

  # OpenSearch authentication from external secret store
  authentication:
    # AWS Secrets Manager example
    opensearch_user: "ref+awssecrets://axonops/search#username"
    opensearch_password: "ref+awssecrets://axonops/search#password"

    # HashiCorp Vault example
    # opensearch_user: "ref+vault://secret/data/axonops/search#username"
    # opensearch_password: "ref+vault://secret/data/axonops/search#password"

  # TLS keystore password (if using TLS)
  tls:
    keystorePassword: "ref+awssecrets://axonops/tls#keystore-password"

  # S3 backup credentials
  s3Credentials:
    accessKeyId: "ref+awssecrets://axonops/s3#access-key-id"
    secretAccessKey: "ref+awssecrets://axonops/s3#secret-access-key"

  # ServiceMonitor basic auth (if using Prometheus)
  serviceMonitor:
    username: "ref+awssecrets://axonops/monitoring#username"
    password: "ref+awssecrets://axonops/monitoring#password"
```

Instale:

```bash
helm install axondb-search ./axondb-search -f values-vals.yaml
```

Cando vals-operator está activado, créase un recurso `ValsSecret` que
vals-operator reconcilia nun segredo estándar de Kubernetes. Así intégrase sen
fricción cos almacéns de segredos externos.

## Configuración

### Opcións de configuración principais

| Parámetro | Descrición | Valor por defecto |
|-----------|-------------|---------|
| `replicas` | Número de réplicas da base de datos de busca | `1` |
| `singleNode` | Activa o modo dun só nodo (desactiva o clustering) | `true` |
| `opensearchHeapSize` | O tamaño do heap da JVM | `2g` |
| `image.repository` | O repositorio da imaxe de contedor | `ghcr.io/axonops/axondb-search` |
| `image.tag` | A etiqueta da imaxe de contedor | `""` (usa a appVersion) |
| `authentication.opensearch_user` | O usuario (só desenvolvemento) | `""` |
| `authentication.opensearch_password` | O contrasinal (só desenvolvemento) | `""` |
| `authentication.opensearch_secret` | O nome do segredo de Kubernetes coas credenciais | `""` |
| `persistence.enabled` | Activa o almacenamento persistente | `true` |
| `persistence.size` | O tamaño do volume de datos | `8Gi` |
| `protocol` | O protocolo HTTP (http ou https) | `https` |
| `tls.enabled` | Activa o cifrado TLS/SSL | `false` |
| `tls.certManager.enabled` | Usa cert-manager para os certificados | `false` |
| `resources.requests.memory` | Petición de memoria | `4096Mi` |
| `resources.requests.cpu` | Petición de CPU | `1000m` |

### Notas importantes

**Configuración do tamaño do heap:**
- O heap debería ser aproximadamente o 50 % da memoria do contedor
- Exemplo: se `resources.limits.memory: 8Gi`, poña `opensearchHeapSize: "4g"`
- Non fixe nunca un heap maior de 32 GB (o límite dos OOP comprimidos)

**Modo dun só nodo fronte a modo clúster:**
- `singleNode: true`: úseo en desenvolvemento e probas; fixa automaticamente `replicas: 1`
- `singleNode: false`: úseo en produción; permite varias réplicas para alta dispoñibilidade

**Seguridade:**
- Use sempre segredos de Kubernetes para as credenciais en produción
- Active TLS nos despregamentos de produción

**Seguridade multinodo (os DN dos certificados de nodo):**

Nos clústeres de varios nodos, configure que Distinguished Names (DN) de
certificado poden unirse ao clúster mediante a variable de entorno
`OPENSEARCH_SECURITY_NODES_DN`. É crítico para asegurar a comunicación da capa de
transporte entre nodos.

Configúreo con `extraEnvs`:
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.example.svc.cluster.local;CN=node-1;CN=node-2"
```

**Puntos clave:**
- Use puntos e coma (`;`) para separar varios DN
- Admite comodíns (por exemplo, `CN=*.svc.cluster.local`) para os nomes de pod dinámicos de Kubernetes
- Só os nodos con certificados que casen con eses DN poden unirse ao clúster
- É esencial para impedir que nodos non autorizados se unan ao seu clúster
- Valor por defecto: `CN=*.axonops.svc.cluster.local`

**Exemplo para Kubernetes con DNS comodín:**
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.default.svc.cluster.local"
```

**Exemplo con nomes de nodo explícitos:**
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=axondb-search-0;CN=axondb-search-1;CN=axondb-search-2"
```

### Referencia completa de values

<details>
<summary>Prema para despregar a táboa completa de values</summary>

| Chave | Tipo | Valor por defecto | Descrición |
|-----|------|---------|-------------|
| antiAffinity | string | `"soft"` | Axuste de antiafinidade (soft, hard ou personalizado) |
| antiAffinityTopologyKey | string | `"kubernetes.io/hostname"` | A chave de topoloxía da antiafinidade |
| authentication.opensearch_password | string | `""` | O contrasinal da base de datos (en texto plano: só desenvolvemento) |
| authentication.opensearch_secret | string | `""` | O nome do segredo de Kubernetes coas credenciais |
| authentication.opensearch_user | string | `""` | O usuario da base de datos (en texto plano: só desenvolvemento) |
| clusterName | string | `"axondb-search-cluster"` | O nome do clúster de busca |
| config.opensearch.yml | string | `"cluster.name: opensearch-cluster\n\nnetwork.host: 0.0.0.0\n"` | O contido do ficheiro de configuración |
| enableServiceLinks | bool | `true` | Activa a inxección de service links |
| envFrom | list | `[]` | Carga variables de entorno dende segredos ou configmaps |
| extraContainers | list | `[]` | Contedores sidecar adicionais |
| extraEnvs | list | `[]` | Variables de entorno adicionais (úseas para OPENSEARCH_SECURITY_NODES_DN en clústeres de varios nodos) |
| extraInitContainers | list | `[]` | Contedores de inicialización adicionais |
| extraVolumeMounts | list | `[]` | Montaxes de volume adicionais |
| extraVolumes | list | `[]` | Volumes adicionais |
| fullnameOverride | string | `""` | Substitúe o nome completo do recurso |
| httpPort | int | `9200` | O porto HTTP do servizo |
| image.pullPolicy | string | `"IfNotPresent"` | Política de descarga da imaxe |
| image.repository | string | `"ghcr.io/axonops/axondb-search"` | O repositorio da imaxe de contedor |
| image.tag | string | `""` | A etiqueta da imaxe (por defecto, a appVersion do chart) |
| imagePullSecrets | list | `[]` | Segredos de descarga de imaxes para rexistros privados |
| ingress.enabled | bool | `false` | Activa o ingress |
| ingress.annotations | object | `{}` | Anotacións do ingress |
| ingress.hosts | list | `["chart-example.local"]` | Nomes de host do ingress |
| labels | object | `{}` | Etiquetas adicionais dos recursos |
| lifecycle | object | `{}` | Hooks de ciclo de vida dos contedores |
| livenessProbe | object | `{}` | Configuración da sonda de vida |
| majorVersion | string | `"3"` | A versión maior do motor de busca |
| masterService | string | `"axondb-search-cluster-master"` | O nome do servizo mestre para o clustering |
| maxUnavailable | int | `1` | Pods máximos non dispoñibles durante as actualizacións |
| metricsPort | int | `9600` | O porto de métricas |
| nameOverride | string | `""` | Substitúe o nome do chart |
| networkHost | string | `"0.0.0.0"` | O enderezo de escoita de rede |
| networkPolicy.create | bool | `false` | Crea unha network policy |
| nodeSelector | object | `{}` | Etiquetas de nodo para asignar os pods |
| opensearchHeapSize | string | `"2g"` | O tamaño do heap da JVM |
| opensearchJavaOps | string | `""` | Opcións adicionais de Java |
| persistence.enabled | bool | `true` | Activa o almacenamento persistente |
| persistence.size | string | `"8Gi"` | O tamaño do volume de datos |
| persistence.accessModes | list | `["ReadWriteOnce"]` | Os modos de acceso da PVC |
| persistence.annotations | object | `{}` | Anotacións da PVC |
| persistence.existingClaim | string | `""` | Usa unha PVC existente |
| plugins.enabled | bool | `false` | Activa a xestión de plugins |
| plugins.installList | list | `[]` | A lista de plugins que instalar |
| podAnnotations | object | `{}` | Anotacións dos pods |
| podManagementPolicy | string | `"Parallel"` | A política de xestión de pods |
| podSecurityContext.fsGroup | int | `999` | FSGroup do contexto de seguridade do pod |
| podSecurityContext.runAsUser | int | `999` | O ID de usuario co que se executan os pods |
| protocol | string | `"https"` | O protocolo HTTP (http ou https) |
| rbac.create | bool | `false` | Crea os recursos de RBAC |
| readinessProbe.failureThreshold | int | `3` | Limiar de fallos da sonda de dispoñibilidade |
| readinessProbe.periodSeconds | int | `5` | Cada canto se executa a sonda |
| readinessProbe.timeoutSeconds | int | `3` | Timeout da sonda de dispoñibilidade |
| replicas | int | `1` | Número de réplicas |
| resources.requests.cpu | string | `"1000m"` | Petición de CPU |
| resources.requests.memory | string | `"4096Mi"` | Petición de memoria |
| roles | list | `["master","ingest","data","remote_cluster_client"]` | Os roles do nodo |
| securityConfig.enabled | bool | `true` | Activa a configuración de seguridade |
| securityContext.capabilities.drop | list | `["ALL"]` | Descarta todas as capacidades |
| securityContext.runAsNonRoot | bool | `true` | Executa como usuario non root |
| securityContext.runAsUser | int | `999` | O ID de usuario co que se executa o contedor |
| service.type | string | `"ClusterIP"` | O tipo de servizo de Kubernetes |
| service.httpPortName | string | `"http"` | O nome do porto HTTP |
| service.transportPortName | string | `"transport"` | O nome do porto de transporte |
| serviceMonitor.enabled | bool | `false` | Activa o ServiceMonitor de Prometheus |
| serviceMonitor.interval | string | `"10s"` | Intervalo de recollida |
| serviceMonitor.path | string | `"/_prometheus/metrics"` | A ruta das métricas |
| singleNode | bool | `true` | Activa o modo dun só nodo |
| startupProbe.failureThreshold | int | `30` | Limiar de fallos da sonda de arranque |
| startupProbe.initialDelaySeconds | int | `5` | Retardo inicial antes da sonda de arranque |
| startupProbe.periodSeconds | int | `10` | Cada canto se executa a sonda |
| sysctlVmMaxMapCount | int | `262144` | O valor de vm.max_map_count |
| terminationGracePeriod | int | `120` | Timeout de apagado ordenado |
| tls.enabled | bool | `false` | Activa TLS/SSL |
| tls.certManager.enabled | bool | `false` | Usa cert-manager para TLS |
| tls.certManager.keystorePassword | string | `"changeme"` | O contrasinal do keystore |
| tls.certManager.issuer.createSelfSigned | bool | `true` | Crea un issuer autoasinado |
| tls.certManager.issuer.kind | string | `"ClusterIssuer"` | O tipo de issuer |
| tls.certManager.certificate.duration | string | `"43800h"` | A duración do certificado |
| tls.manual.existingSecret | string | `""` | O segredo existente cos certificados manuais |
| tolerations | list | `[]` | Tolerancias para asignar os pods |
| transportPort | int | `9300` | O porto de transporte para a comunicación entre nodos |
| updateStrategy | string | `"RollingUpdate"` | A estratexia de actualización |

</details>

## Actualización

Para actualizar unha instalación existente:

```bash
# Update the chart
helm upgrade axondb-search ./axondb-search -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axondb-search-cluster-master
```

**Importante:** nos clústeres de varios nodos, as actualizacións fanse cunha
estratexia de actualización progresiva. Asegúrese de ter capacidade abonda para
asumir o tráfico durante a actualización.

## Desinstalación

Para eliminar a base de datos de busca de AxonOps:

```bash
# Uninstall the release
helm uninstall axondb-search

# Optional: Delete PVCs (this will delete all data!)
kubectl delete pvc -l app.kubernetes.io/name=axondb-search
```

**Aviso:** borrar as PVC elimina de forma permanente todos os datos indexados.
Asegúrese de ter copias de seguranza ou snapshots antes de seguir.

## Resolución de problemas

### Problemas habituais

**1. Os pods non arrancan (CrashLoopBackOff)**

Revise os rexistros do pod:
```bash
kubectl logs axondb-search-cluster-master-0
```

Causas habituais:
- Memoria insuficiente (suba `opensearchHeapSize` e `resources.limits.memory`)
- Problemas ao aprovisionar o almacenamento (revise o estado das PVC con `kubectl get pvc`)
- `vm.max_map_count` sen definir (active `sysctlInit.enabled: true`)

**2. Erro «vm.max_map_count is too low»**

O motor de busca precisa que `vm.max_map_count` valla polo menos 262144. Ten dúas
opcións:

**Opción A: activar sysctlInit no chart de Helm (require contedores
privilexiados):**
```yaml
sysctlInit:
  enabled: true
```

**Opción B: definilo a nivel de nodo (recomendado):**
```bash
# On each Kubernetes node
sudo sysctl -w vm.max_map_count=262144

# Make it persistent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

**3. Problemas de almacenamento**

Revise o estado das PVC:
```bash
kubectl get pvc
kubectl describe pvc axondb-search-cluster-master-axondb-search-cluster-master-0
```

Se a PVC está en Pending:
- Comprobe que a StorageClass existe: `kubectl get storageclass`
- Comprobe que o aprovisionamento dinámico está activado no seu clúster
- Asegúrese de ter cota de almacenamento abonda

**4. Problemas cos certificados (cert-manager)**

Revise o estado do certificado:
```bash
kubectl get certificate
kubectl describe certificate axondb-search-tls
kubectl get certificaterequest
```

Revise os rexistros de cert-manager:
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

**5. O clúster non se forma (varios nodos)**

Se os nodos non se descobren entre si:

```bash
# Check all pods are running
kubectl get pods -l app.kubernetes.io/name=axondb-search

# Check service endpoints
kubectl get endpoints axondb-search-cluster-master-headless

# Check logs for discovery issues
kubectl logs axondb-search-cluster-master-0 | grep -i discovery
```

Verifique que:
- `singleNode: false` está definido
- `masterService` apunta ao nome de servizo correcto
- Os pods poden comunicarse polo porto 9300 (transporte)

**6. Erros de conexión rexeitada**

Verifique o servizo:
```bash
kubectl get svc
kubectl describe svc axondb-search-cluster-master
```

Probe a conectividade:
```bash
# Port-forward to access locally
kubectl port-forward svc/axondb-search-cluster-master 9200:9200

# Test the connection
curl -k https://localhost:9200
```

**7. Uso alto de memoria ou mortes por OOM**

Revise o uso real de memoria:
```bash
kubectl top pod -l app.kubernetes.io/name=axondb-search
```

Axuste o tamaño do heap e os límites de memoria:
```yaml
opensearchHeapSize: "4g"
resources:
  limits:
    memory: 8Gi  # Should be at least 2x heap size
```

**Regras importantes sobre o tamaño do heap:**
- Fixe o heap arredor do 50 % da memoria do contedor
- Non supere nunca 31-32 GB (o límite dos OOP comprimidos)
- Faga que `requests.memory` e `limits.memory` sexan iguais, para evitar OOM

**8. Problemas de rendemento**

Para mellorar o rendemento:

1. Active un volume de commitlog á parte (se a súa configuración o admite)
2. Use clases de almacenamento respaldadas por SSD
3. Suba o número de réplicas, para repartir mellor as consultas
4. Vixíe as métricas da JVM e axuste o heap en consecuencia

### Obter axuda

Para soporte adicional:
- Revise os rexistros: `kubectl logs -f axondb-search-cluster-master-0`
- Consulte os eventos: `kubectl get events --sort-by='.lastTimestamp'`
- Describa o StatefulSet: `kubectl describe statefulset axondb-search-cluster-master`
- Consulte a saúde do clúster pola API (tras facer port-forward):
  ```bash
  curl -k -u admin:password https://localhost:9200/_cluster/health?pretty
  ```
- Visite a documentación de AxonOps: <https://docs.axonops.com>
- Contacte co soporte de AxonOps: <info@axonops.com>

## Mantedores

| Nome | Correo | URL |
| ---- | ------ | --- |
| O equipo de AxonOps | <info@aoxnops.com> |  |

---

*Xerado cos charts de Helm de AxonOps*
