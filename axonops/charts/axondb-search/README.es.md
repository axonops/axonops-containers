# Base de datos de búsqueda de AxonOps

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

![Versión: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Tipo: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3.3.2-1.1.0](https://img.shields.io/badge/AppVersion-3.3.2--1.1.0-informational?style=flat-square)

Un chart de Helm para desplegar la base de datos de búsqueda de AxonOps sobre
Kubernetes. Esta base de datos da soporte a las capacidades de indexación y
búsqueda de la plataforma AxonOps para registros, eventos y datos operativos.

**Página del proyecto:** <https://axonops.com>

## Índice

- [Requisitos previos](#requisitos-previos)
- [Inicio rápido](#inicio-rápido)
- [Ejemplos de instalación](#ejemplos-de-instalación)
  - [Instalación básica](#instalación-básica)
  - [Instalación con almacenamiento personalizado](#instalación-con-almacenamiento-personalizado)
  - [Instalación con autenticación](#instalación-con-autenticación)
  - [Instalación con TLS (certificados manuales)](#instalación-con-tls-certificados-manuales)
  - [Instalación con TLS (cert-manager)](#instalación-con-tls-cert-manager)
  - [Instalación de un clúster de varios nodos](#instalación-de-un-clúster-de-varios-nodos)
  - [Instalación lista para producción](#instalación-lista-para-producción)
- [Configuración de copias de seguridad](#configuración-de-copias-de-seguridad)
  - [Copias de seguridad locales](#copias-de-seguridad-locales)
  - [Copias de seguridad en S3](#copias-de-seguridad-en-s3)
- [Gestión externa de secretos (vals-operator)](#gestión-externa-de-secretos-vals-operator)
- [Configuración](#configuración)
- [Actualización](#actualización)
- [Desinstalación](#desinstalación)
- [Resolución de problemas](#resolución-de-problemas)

## Requisitos previos

Antes de empezar, asegúrese de tener lo siguiente:

- **Un clúster de Kubernetes**: versión 1.19 o superior
- **kubectl**: configurado para comunicarse con su clúster
- **Helm**: versión 3.0 o superior instalada ([guía de instalación](https://helm.sh/docs/intro/install/))
- **Almacenamiento**: una StorageClass por defecto configurada en su clúster, o una StorageClass concreta para los volúmenes persistentes
- **Recursos**: se recomiendan al menos 4 GB de memoria disponible y 2 núcleos de CPU

### Requisitos previos opcionales

- **cert-manager**: sólo hace falta si quiere gestión automática de certificados TLS ([guía de instalación](https://cert-manager.io/docs/installation/))
- **El Prometheus Operator**: sólo hace falta si quiere activar la monitorización de métricas con ServiceMonitor

### Verificar su instalación

Compruebe que Helm está instalado:
```bash
helm version
```

Compruebe que kubectl está configurado:
```bash
kubectl cluster-info
```

Consulte las StorageClass disponibles:
```bash
kubectl get storageclass
```

## Inicio rápido

La forma más rápida de empezar con la base de datos de búsqueda de AxonOps:

```bash
# Add the AxonOps Helm repository (if available)
# helm repo add axonops https://axonops.github.io/helm-charts
# helm repo update

# Install with default settings (single-node mode)
helm install axondb-search ./axondb-search

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axondb-search
```

Esto despliega una base de datos de búsqueda de un solo nodo con:
- 8 Gi de almacenamiento persistente
- Los límites de recursos por defecto (4 GB de memoria, 1 CPU)
- Modo de descubrimiento de un solo nodo
- HTTPS activado por defecto
- Una configuración de seguridad básica

## Ejemplos de instalación

### Instalación básica

Instalación con la configuración mínima, apta para desarrollo y pruebas:

```bash
helm install axondb-search ./axondb-search \
  --set replicas=1 \
  --set singleNode=true
```

O cree un fichero `values-basic.yaml`:

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

Instale usando el fichero de values:

```bash
helm install axondb-search ./axondb-search -f values-basic.yaml
```

### Instalación con almacenamiento personalizado

Configure el almacenamiento persistente con una StorageClass y un tamaño
concretos:

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

Proteja su base de datos de búsqueda con credenciales de autenticación:

**Opción 1: valores directos (sólo desarrollo)**

```yaml
# values-auth.yaml
replicas: 1
singleNode: true

opensearchHeapSize: "2g"

authentication:
  opensearch_user: "axonops"
  opensearch_password: "your-secure-password"
```

**Opción 2: secretos de Kubernetes (recomendado en producción)**

Primero, cree un secreto de Kubernetes:

```bash
kubectl create secret generic -n axonops axondb-search-credentials \
  --from-literal=AXONOPS_SEARCH_USER=axonops \
  --from-literal=AXONOPS_SEARCH_PASSWORD=secure-password
```

Después cree su fichero de values:

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

### Instalación con TLS (certificados manuales)

Use certificados TLS ya existentes para cifrar la comunicación:

**Paso 1: cree un secreto con sus certificados**

```bash
kubectl create secret generic axondb-search-tls-manual \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key \
  --from-file=ca.crt=path/to/ca.crt
```

**Paso 2: cree su fichero de values**

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

Genere y gestione los certificados TLS automáticamente con cert-manager:

**Requisitos previos:**
- cert-manager debe estar instalado en su clúster

**Paso 1: instale cert-manager (si no lo está ya)**

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

Espere a que cert-manager esté listo:

```bash
kubectl wait --for=condition=Available --timeout=300s \
  deployment/cert-manager -n cert-manager
```

**Paso 2: cree su fichero de values**

**Con certificados autofirmados (desarrollo y pruebas):**

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

**Con un issuer existente (producción):**

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

**Verifique la creación del certificado:**

```bash
kubectl get certificate
kubectl describe certificate axondb-search-tls
```

### Instalación de un clúster de varios nodos

Despliegue un clúster de varios nodos para alta disponibilidad y mejor
rendimiento:

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

### Instalación lista para producción

Una configuración de producción completa, con todos los ajustes recomendados:

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

**Antes de instalar, cree el secreto de autenticación:**

```bash
kubectl create secret generic axondb-search-credentials \
  --from-literal=OPENSEARCH_USER=axonops \
  --from-literal=OPENSEARCH_PASSWORD=$(openssl rand -base64 32)
```

**Instale el despliegue de producción:**

```bash
helm install axondb-search ./axondb-search \
  -f values-production.yaml \
  --namespace axonops \
  --create-namespace
```

**Verifique que el clúster está sano:**

```bash
# Check all pods are running
kubectl get pods -l app.kubernetes.io/name=axondb-search -n axonops

# Check cluster health (port-forward to access)
kubectl port-forward svc/axondb-search-cluster-master 9200:9200 -n axonops

# In another terminal (if using default credentials)
curl -k -u admin:ChangeThisSecurePassword123! https://localhost:9200/_cluster/health
```

## Configuración de copias de seguridad

El chart axondb-search incluye funcionalidad de copias de seguridad integrada,
basada en snapshots de OpenSearch. Las copias pueden guardarse en local o en
almacenamiento compatible con S3.

### Copias de seguridad locales

Configure copias en el sistema de ficheros local con una PVC dedicada:

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

### Copias de seguridad en S3

Configure las copias hacia AWS S3 o hacia almacenamiento compatible con S3
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

Cree el secreto con las credenciales:

```bash
kubectl create secret generic aws-backup-credentials \
  --from-literal=aws-access-key-id=AKIAIOSFODNN7EXAMPLE \
  --from-literal=aws-secret-access-key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

#### Con almacenamiento compatible con S3 (MinIO)

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

## Gestión externa de secretos (vals-operator)

El chart admite [vals-operator](https://github.com/digitalis-io/vals-operator)
para obtener secretos de almacenes externos como AWS Secrets Manager, HashiCorp
Vault, Google Secret Manager y Azure Key Vault.

### Instalar vals-operator

Instale vals-operator en su clúster:

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

Cuando vals-operator está activado, se crea un recurso `ValsSecret` que
vals-operator reconcilia en un secreto estándar de Kubernetes. Así se integra sin
fricción con los almacenes de secretos externos.

## Configuración

### Opciones de configuración principales

| Parámetro | Descripción | Valor por defecto |
|-----------|-------------|---------|
| `replicas` | Número de réplicas de la base de datos de búsqueda | `1` |
| `singleNode` | Activa el modo de un solo nodo (desactiva el clustering) | `true` |
| `opensearchHeapSize` | El tamaño del heap de la JVM | `2g` |
| `image.repository` | El repositorio de la imagen de contenedor | `ghcr.io/axonops/axondb-search` |
| `image.tag` | La etiqueta de la imagen de contenedor | `""` (usa la appVersion) |
| `authentication.opensearch_user` | El usuario (sólo desarrollo) | `""` |
| `authentication.opensearch_password` | La contraseña (sólo desarrollo) | `""` |
| `authentication.opensearch_secret` | El nombre del secreto de Kubernetes con las credenciales | `""` |
| `persistence.enabled` | Activa el almacenamiento persistente | `true` |
| `persistence.size` | El tamaño del volumen de datos | `8Gi` |
| `protocol` | El protocolo HTTP (http o https) | `https` |
| `tls.enabled` | Activa el cifrado TLS/SSL | `false` |
| `tls.certManager.enabled` | Usa cert-manager para los certificados | `false` |
| `resources.requests.memory` | Petición de memoria | `4096Mi` |
| `resources.requests.cpu` | Petición de CPU | `1000m` |

### Notas importantes

**Configuración del tamaño del heap:**
- El heap debería ser aproximadamente el 50 % de la memoria del contenedor
- Ejemplo: si `resources.limits.memory: 8Gi`, ponga `opensearchHeapSize: "4g"`
- No fije nunca un heap mayor de 32 GB (el límite de los OOP comprimidos)

**Modo de un solo nodo frente a modo clúster:**
- `singleNode: true`: úselo en desarrollo y pruebas; fija automáticamente `replicas: 1`
- `singleNode: false`: úselo en producción; permite varias réplicas para alta disponibilidad

**Seguridad:**
- Use siempre secretos de Kubernetes para las credenciales en producción
- Active TLS en los despliegues de producción

**Seguridad multinodo (los DN de los certificados de nodo):**

En los clústeres de varios nodos, configure qué Distinguished Names (DN) de
certificado pueden unirse al clúster mediante la variable de entorno
`OPENSEARCH_SECURITY_NODES_DN`. Es crítico para asegurar la comunicación de la
capa de transporte entre nodos.

Configúrelo con `extraEnvs`:
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.example.svc.cluster.local;CN=node-1;CN=node-2"
```

**Puntos clave:**
- Use puntos y coma (`;`) para separar varios DN
- Admite comodines (por ejemplo, `CN=*.svc.cluster.local`) para los nombres de pod dinámicos de Kubernetes
- Sólo los nodos con certificados que casen con esos DN pueden unirse al clúster
- Es esencial para impedir que nodos no autorizados se unan a su clúster
- Valor por defecto: `CN=*.axonops.svc.cluster.local`

**Ejemplo para Kubernetes con DNS comodín:**
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.default.svc.cluster.local"
```

**Ejemplo con nombres de nodo explícitos:**
```yaml
extraEnvs:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=axondb-search-0;CN=axondb-search-1;CN=axondb-search-2"
```

### Referencia completa de values

<details>
<summary>Pulse para desplegar la tabla completa de values</summary>

| Clave | Tipo | Valor por defecto | Descripción |
|-----|------|---------|-------------|
| antiAffinity | string | `"soft"` | Ajuste de antiafinidad (soft, hard o personalizado) |
| antiAffinityTopologyKey | string | `"kubernetes.io/hostname"` | La clave de topología de la antiafinidad |
| authentication.opensearch_password | string | `""` | La contraseña de la base de datos (en texto plano: sólo desarrollo) |
| authentication.opensearch_secret | string | `""` | El nombre del secreto de Kubernetes con las credenciales |
| authentication.opensearch_user | string | `""` | El usuario de la base de datos (en texto plano: sólo desarrollo) |
| clusterName | string | `"axondb-search-cluster"` | El nombre del clúster de búsqueda |
| config.opensearch.yml | string | `"cluster.name: opensearch-cluster\n\nnetwork.host: 0.0.0.0\n"` | El contenido del fichero de configuración |
| enableServiceLinks | bool | `true` | Activa la inyección de service links |
| envFrom | list | `[]` | Carga variables de entorno desde secretos o configmaps |
| extraContainers | list | `[]` | Contenedores sidecar adicionales |
| extraEnvs | list | `[]` | Variables de entorno adicionales (úselas para OPENSEARCH_SECURITY_NODES_DN en clústeres de varios nodos) |
| extraInitContainers | list | `[]` | Contenedores de inicialización adicionales |
| extraVolumeMounts | list | `[]` | Montajes de volumen adicionales |
| extraVolumes | list | `[]` | Volúmenes adicionales |
| fullnameOverride | string | `""` | Sustituye el nombre completo del recurso |
| httpPort | int | `9200` | El puerto HTTP del servicio |
| image.pullPolicy | string | `"IfNotPresent"` | Política de descarga de la imagen |
| image.repository | string | `"ghcr.io/axonops/axondb-search"` | El repositorio de la imagen de contenedor |
| image.tag | string | `""` | La etiqueta de la imagen (por defecto, la appVersion del chart) |
| imagePullSecrets | list | `[]` | Secretos de descarga de imágenes para registros privados |
| ingress.enabled | bool | `false` | Activa el ingress |
| ingress.annotations | object | `{}` | Anotaciones del ingress |
| ingress.hosts | list | `["chart-example.local"]` | Nombres de host del ingress |
| labels | object | `{}` | Etiquetas adicionales de los recursos |
| lifecycle | object | `{}` | Hooks de ciclo de vida de los contenedores |
| livenessProbe | object | `{}` | Configuración de la sonda de vida |
| majorVersion | string | `"3"` | La versión mayor del motor de búsqueda |
| masterService | string | `"axondb-search-cluster-master"` | El nombre del servicio maestro para el clustering |
| maxUnavailable | int | `1` | Pods máximos no disponibles durante las actualizaciones |
| metricsPort | int | `9600` | El puerto de métricas |
| nameOverride | string | `""` | Sustituye el nombre del chart |
| networkHost | string | `"0.0.0.0"` | La dirección de escucha de red |
| networkPolicy.create | bool | `false` | Crea una network policy |
| nodeSelector | object | `{}` | Etiquetas de nodo para asignar los pods |
| opensearchHeapSize | string | `"2g"` | El tamaño del heap de la JVM |
| opensearchJavaOps | string | `""` | Opciones adicionales de Java |
| persistence.enabled | bool | `true` | Activa el almacenamiento persistente |
| persistence.size | string | `"8Gi"` | El tamaño del volumen de datos |
| persistence.accessModes | list | `["ReadWriteOnce"]` | Los modos de acceso de la PVC |
| persistence.annotations | object | `{}` | Anotaciones de la PVC |
| persistence.existingClaim | string | `""` | Usa una PVC existente |
| plugins.enabled | bool | `false` | Activa la gestión de plugins |
| plugins.installList | list | `[]` | La lista de plugins que instalar |
| podAnnotations | object | `{}` | Anotaciones de los pods |
| podManagementPolicy | string | `"Parallel"` | La política de gestión de pods |
| podSecurityContext.fsGroup | int | `999` | FSGroup del contexto de seguridad del pod |
| podSecurityContext.runAsUser | int | `999` | El ID de usuario con el que se ejecutan los pods |
| protocol | string | `"https"` | El protocolo HTTP (http o https) |
| rbac.create | bool | `false` | Crea los recursos de RBAC |
| readinessProbe.failureThreshold | int | `3` | Umbral de fallos de la sonda de disponibilidad |
| readinessProbe.periodSeconds | int | `5` | Cada cuánto se ejecuta la sonda |
| readinessProbe.timeoutSeconds | int | `3` | Timeout de la sonda de disponibilidad |
| replicas | int | `1` | Número de réplicas |
| resources.requests.cpu | string | `"1000m"` | Petición de CPU |
| resources.requests.memory | string | `"4096Mi"` | Petición de memoria |
| roles | list | `["master","ingest","data","remote_cluster_client"]` | Los roles del nodo |
| securityConfig.enabled | bool | `true` | Activa la configuración de seguridad |
| securityContext.capabilities.drop | list | `["ALL"]` | Descarta todas las capacidades |
| securityContext.runAsNonRoot | bool | `true` | Ejecuta como usuario no root |
| securityContext.runAsUser | int | `999` | El ID de usuario con el que se ejecuta el contenedor |
| service.type | string | `"ClusterIP"` | El tipo de servicio de Kubernetes |
| service.httpPortName | string | `"http"` | El nombre del puerto HTTP |
| service.transportPortName | string | `"transport"` | El nombre del puerto de transporte |
| serviceMonitor.enabled | bool | `false` | Activa el ServiceMonitor de Prometheus |
| serviceMonitor.interval | string | `"10s"` | Intervalo de recogida |
| serviceMonitor.path | string | `"/_prometheus/metrics"` | La ruta de las métricas |
| singleNode | bool | `true` | Activa el modo de un solo nodo |
| startupProbe.failureThreshold | int | `30` | Umbral de fallos de la sonda de arranque |
| startupProbe.initialDelaySeconds | int | `5` | Retardo inicial antes de la sonda de arranque |
| startupProbe.periodSeconds | int | `10` | Cada cuánto se ejecuta la sonda |
| sysctlVmMaxMapCount | int | `262144` | El valor de vm.max_map_count |
| terminationGracePeriod | int | `120` | Timeout de apagado ordenado |
| tls.enabled | bool | `false` | Activa TLS/SSL |
| tls.certManager.enabled | bool | `false` | Usa cert-manager para TLS |
| tls.certManager.keystorePassword | string | `"changeme"` | La contraseña del keystore |
| tls.certManager.issuer.createSelfSigned | bool | `true` | Crea un issuer autofirmado |
| tls.certManager.issuer.kind | string | `"ClusterIssuer"` | El tipo de issuer |
| tls.certManager.certificate.duration | string | `"43800h"` | La duración del certificado |
| tls.manual.existingSecret | string | `""` | El secreto existente con los certificados manuales |
| tolerations | list | `[]` | Toleraciones para asignar los pods |
| transportPort | int | `9300` | El puerto de transporte para la comunicación entre nodos |
| updateStrategy | string | `"RollingUpdate"` | La estrategia de actualización |

</details>

## Actualización

Para actualizar una instalación existente:

```bash
# Update the chart
helm upgrade axondb-search ./axondb-search -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axondb-search-cluster-master
```

**Importante:** en los clústeres de varios nodos, las actualizaciones se hacen con
una estrategia de actualización progresiva. Asegúrese de tener capacidad
suficiente para asumir el tráfico durante la actualización.

## Desinstalación

Para eliminar la base de datos de búsqueda de AxonOps:

```bash
# Uninstall the release
helm uninstall axondb-search

# Optional: Delete PVCs (this will delete all data!)
kubectl delete pvc -l app.kubernetes.io/name=axondb-search
```

**Aviso:** borrar las PVC elimina de forma permanente todos los datos indexados.
Asegúrese de tener copias de seguridad o snapshots antes de seguir.

## Resolución de problemas

### Problemas habituales

**1. Los pods no arrancan (CrashLoopBackOff)**

Revise los registros del pod:
```bash
kubectl logs axondb-search-cluster-master-0
```

Causas habituales:
- Memoria insuficiente (suba `opensearchHeapSize` y `resources.limits.memory`)
- Problemas al aprovisionar el almacenamiento (revise el estado de las PVC con `kubectl get pvc`)
- `vm.max_map_count` sin definir (active `sysctlInit.enabled: true`)

**2. Error «vm.max_map_count is too low»**

El motor de búsqueda necesita que `vm.max_map_count` valga al menos 262144. Tiene
dos opciones:

**Opción A: activar sysctlInit en el chart de Helm (requiere contenedores
privilegiados):**
```yaml
sysctlInit:
  enabled: true
```

**Opción B: definirlo a nivel de nodo (recomendado):**
```bash
# On each Kubernetes node
sudo sysctl -w vm.max_map_count=262144

# Make it persistent
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

**3. Problemas de almacenamiento**

Revise el estado de las PVC:
```bash
kubectl get pvc
kubectl describe pvc axondb-search-cluster-master-axondb-search-cluster-master-0
```

Si la PVC está en Pending:
- Compruebe que la StorageClass existe: `kubectl get storageclass`
- Compruebe que el aprovisionamiento dinámico está activado en su clúster
- Asegúrese de tener cuota de almacenamiento suficiente

**4. Problemas con los certificados (cert-manager)**

Revise el estado del certificado:
```bash
kubectl get certificate
kubectl describe certificate axondb-search-tls
kubectl get certificaterequest
```

Revise los registros de cert-manager:
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

**5. El clúster no se forma (varios nodos)**

Si los nodos no se descubren entre sí:

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
- `masterService` apunta al nombre de servicio correcto
- Los pods pueden comunicarse por el puerto 9300 (transporte)

**6. Errores de conexión rechazada**

Verifique el servicio:
```bash
kubectl get svc
kubectl describe svc axondb-search-cluster-master
```

Pruebe la conectividad:
```bash
# Port-forward to access locally
kubectl port-forward svc/axondb-search-cluster-master 9200:9200

# Test the connection
curl -k https://localhost:9200
```

**7. Uso alto de memoria o muertes por OOM**

Revise el uso real de memoria:
```bash
kubectl top pod -l app.kubernetes.io/name=axondb-search
```

Ajuste el tamaño del heap y los límites de memoria:
```yaml
opensearchHeapSize: "4g"
resources:
  limits:
    memory: 8Gi  # Should be at least 2x heap size
```

**Reglas importantes sobre el tamaño del heap:**
- Fije el heap en torno al 50 % de la memoria del contenedor
- No supere nunca 31-32 GB (el límite de los OOP comprimidos)
- Haga que `requests.memory` y `limits.memory` sean iguales, para evitar OOM

**8. Problemas de rendimiento**

Para mejorar el rendimiento:

1. Active un volumen de commitlog aparte (si su configuración lo admite)
2. Use clases de almacenamiento respaldadas por SSD
3. Suba el número de réplicas, para repartir mejor las consultas
4. Vigile las métricas de la JVM y ajuste el heap en consecuencia

### Obtener ayuda

Para soporte adicional:
- Revise los registros: `kubectl logs -f axondb-search-cluster-master-0`
- Consulte los eventos: `kubectl get events --sort-by='.lastTimestamp'`
- Describa el StatefulSet: `kubectl describe statefulset axondb-search-cluster-master`
- Consulte la salud del clúster por la API (tras hacer port-forward):
  ```bash
  curl -k -u admin:password https://localhost:9200/_cluster/health?pretty
  ```
- Visite la documentación de AxonOps: <https://docs.axonops.com>
- Contacte con el soporte de AxonOps: <info@axonops.com>

## Mantenedores

| Nombre | Correo | URL |
| ---- | ------ | --- |
| El equipo de AxonOps | <info@aoxnops.com> |  |

---

*Generado con los charts de Helm de AxonOps*
