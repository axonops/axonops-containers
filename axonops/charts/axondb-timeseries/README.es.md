# Base de datos de series temporales de AxonOps

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

![Versión: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Tipo: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 5.0.5-1.0.0](https://img.shields.io/badge/AppVersion-5.0.5--1.0.0-informational?style=flat-square)

Un chart de Helm para desplegar la base de datos de series temporales de AxonOps
(basada en Cassandra) sobre Kubernetes. Esta base de datos almacena las métricas y
los datos de monitorización de la plataforma AxonOps.

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
  - [Instalación lista para producción](#instalación-lista-para-producción)
- [Configuración de copias de seguridad](#configuración-de-copias-de-seguridad)
  - [Copias de seguridad locales](#copias-de-seguridad-locales)
  - [Copias de seguridad remotas (S3)](#copias-de-seguridad-remotas-s3)
  - [Restaurar desde una copia de seguridad](#restaurar-desde-una-copia-de-seguridad)
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
- **Recursos**: se recomiendan al menos 2 GB de memoria disponible y 2 núcleos de CPU

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

La forma más rápida de empezar con la base de datos de series temporales de
AxonOps:

```bash
# Add the AxonOps Helm repository (if available)
# helm repo add axonops https://axonops.github.io/helm-charts
# helm repo update

# Install with default settings
helm install axondb-timeseries ./axondb-timeseries

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axondb-timeseries
```

Esto despliega una base de datos de series temporales de un solo nodo con:
- 10 Gi de almacenamiento persistente
- Los límites de recursos por defecto
- Sin autenticación (sólo para desarrollo)
- Sin cifrado TLS

## Ejemplos de instalación

### Instalación básica

Instalación con la configuración mínima, apta para desarrollo y pruebas:

```bash
helm install axondb-timeseries ./axondb-timeseries \
  --set replicaCount=1
```

O cree un fichero `values-basic.yaml`:

```yaml
# values-basic.yaml
replicaCount: 1

# Optional: Increase heap size for better performance
heapSize: 2048M

# Optional: Set resource limits
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

Instale usando el fichero de values:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-basic.yaml
```

### Instalación con almacenamiento personalizado

Configure el almacenamiento persistente con una StorageClass y un tamaño
concretos:

```yaml
# values-storage.yaml
replicaCount: 1

persistence:
  enabled: true
  data:
    # Use your cluster's StorageClass (e.g., gp3, standard, fast-ssd)
    storageClass: "gp3"
    size: 50Gi
    accessMode: ReadWriteOnce

  # Optional: Separate commitlog volume for better I/O performance
  commitlog:
    enabled: true
    storageClass: "fast-ssd"  # Use SSD for commitlog
    size: 10Gi
    accessMode: ReadWriteOnce
```

Instale:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-storage.yaml
```

### Instalación con autenticación

Proteja su base de datos con credenciales de autenticación:

**Opción 1: valores directos (sólo desarrollo)**

```yaml
# values-auth.yaml
replicaCount: 1

authentication:
  db_user: "axonops"
  db_password: "your-secure-password"
```

**Opción 2: secretos de Kubernetes (recomendado en producción)**

Primero, cree un secreto de Kubernetes:

```bash
kubectl create secret generic axondb-credentials \
  --from-literal=AXONOPS_DB_USER=axonops \
  --from-literal=AXONOPS_DB_PASSWORD=your-secure-password
```

Después cree su fichero de values:

```yaml
# values-auth-secret.yaml
replicaCount: 1

authentication:
  db_secret: "axondb-credentials"
```

Instale:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-auth-secret.yaml
```

### Instalación con TLS (certificados manuales)

Use certificados TLS ya existentes para cifrar la comunicación:

**Paso 1: cree un secreto con sus certificados**

```bash
kubectl create secret generic axondb-tls-manual \
  --from-file=tls.crt=path/to/tls.crt \
  --from-file=tls.key=path/to/tls.key \
  --from-file=ca.crt=path/to/ca.crt \
  --from-file=keystore.jks=path/to/keystore.jks \
  --from-file=truststore.jks=path/to/truststore.jks \
  --from-literal=keystore-password=your-keystore-password \
  --from-literal=truststore-password=your-truststore-password
```

**Paso 2: cree su fichero de values**

```yaml
# values-tls-manual.yaml
replicaCount: 1

tls:
  enabled: true
  manual:
    existingSecret: "axondb-tls-manual"

  cassandra:
    # Configure internode (node-to-node) encryption
    internode:
      encryption: "all"          # Options: none, dc, rack, all
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"
```

Instale:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-tls-manual.yaml
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
replicaCount: 1

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
      secretName: "axondb-timeseries-tls-cert"

  cassandra:
    internode:
      encryption: "all"
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"
```

**Con un issuer existente (producción):**

```yaml
# values-tls-certmanager-production.yaml
replicaCount: 1

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
      commonName: "axondb.example.com"
      dnsNames:
        - "axondb.example.com"
        - "*.axondb.example.com"
      duration: 2160h  # 90 days
      renewBefore: 360h  # 15 days
      secretName: "axondb-timeseries-tls-cert"

  cassandra:
    internode:
      encryption: "all"
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"
```

Instale:

```bash
# For self-signed certificates
helm install axondb-timeseries ./axondb-timeseries -f values-tls-certmanager-selfsigned.yaml

# OR for production with existing issuer
helm install axondb-timeseries ./axondb-timeseries -f values-tls-certmanager-production.yaml
```

**Verifique la creación del certificado:**

```bash
kubectl get certificate
kubectl describe certificate axondb-timeseries-tls
```

### Instalación lista para producción

Una configuración de producción completa, con todos los ajustes recomendados:

```yaml
# values-production.yaml
# Production configuration for AxonOps Timeseries Database

# Run at least 3 nodes for high availability
replicaCount: 3

image:
  repository: ghcr.io/axonops/axondb-timeseries
  pullPolicy: IfNotPresent
  tag: ""  # Uses chart appVersion

# Increase heap size for production workloads
heapSize: 8192M

# Authentication using Kubernetes secrets
authentication:
  db_secret: "axondb-credentials"

# Resource limits for production
resources:
  requests:
    cpu: 2000m
    memory: 10Gi
  limits:
    cpu: 4000m
    memory: 16Gi

# Persistent storage configuration
persistence:
  enabled: true
  data:
    storageClass: "gp3"
    size: 100Gi
    accessMode: ReadWriteOnce
  commitlog:
    enabled: true
    storageClass: "fast-ssd"
    size: 20Gi
    accessMode: ReadWriteOnce

# TLS encryption with cert-manager
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
      commonName: "axondb.prod.example.com"
      dnsNames:
        - "axondb.prod.example.com"
        - "*.axondb.prod.example.com"
      duration: 2160h
      renewBefore: 360h
  cassandra:
    internode:
      encryption: "all"
      requireClientAuth: true
      protocol: "TLS"
      acceptedProtocols: "TLSv1.2,TLSv1.3"

# Health check probes
livenessProbe:
  enabled: true
  initialDelaySeconds: 90
  periodSeconds: 30
  timeoutSeconds: 30
  failureThreshold: 5

readinessProbe:
  enabled: true
  initialDelaySeconds: 90
  periodSeconds: 10
  timeoutSeconds: 30
  failureThreshold: 5

# Pod security context
podSecurityContext:
  fsGroup: 999

securityContext:
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 999

# Service configuration
service:
  type: ClusterIP
  port: 9042

# Enable Prometheus monitoring
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
  labels:
    prometheus: kube-prometheus

# Pod placement rules
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
                - axondb-timeseries
        topologyKey: kubernetes.io/hostname

# Tolerations for dedicated nodes (optional)
# tolerations:
#   - key: "workload"
#     operator: "Equal"
#     value: "database"
#     effect: "NoSchedule"

# Node selector for dedicated nodes (optional)
# nodeSelector:
#   workload: database
```

**Antes de instalar, cree el secreto de autenticación:**

```bash
kubectl create secret generic axondb-credentials \
  --from-literal=AXONOPS_DB_USER=axonops \
  --from-literal=AXONOPS_DB_PASSWORD=$(openssl rand -base64 32)
```

**Instale el despliegue de producción:**

```bash
helm install axondb-timeseries ./axondb-timeseries \
  -f values-production.yaml \
  --namespace axonops \
  --create-namespace
```

## Configuración de copias de seguridad

El chart axondb-timeseries incluye una funcionalidad completa de copias de
seguridad basada en snapshots de Cassandra con deduplicación mediante rsync. Las
copias pueden guardarse en local o sincronizarse con almacenamiento remoto
compatible con S3.

**Nota:** AxonDB Timeseries está pensado sólo para despliegues de un solo nodo.
Los clústeres de varios nodos no están admitidos para las operaciones de copia de
seguridad.

### Copias de seguridad locales

Configure copias locales basadas en snapshots con deduplicación por enlaces duros:

```yaml
# values-backup-local.yaml
backups:
  enabled: true

  # Backup volume configuration
  volume:
    size: "50Gi"
    storageClass: ""  # Uses default storage class
    mountPath: /backup

  # Backup schedule (cron format)
  schedule:
    cronSchedule: "0 */4 * * *"  # Every 4 hours
    successfulJobsHistoryLimit: 3
    failedJobsHistoryLimit: 3

  # Backup settings
  settings:
    tagPrefix: "backup"
    retentionHours: 168  # 7 days
    minimumRetentionCount: 3  # Always keep at least 3 backups
    useHardlinks: true  # Enable deduplication
```

Instale:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-backup-local.yaml
```

### Copias de seguridad remotas (S3)

Configure las copias para que se sincronicen con AWS S3 o con almacenamiento
compatible con S3 mediante rclone:

```yaml
# values-backup-remote.yaml
backups:
  enabled: true

  volume:
    size: "50Gi"

  schedule:
    cronSchedule: "0 */4 * * *"

  settings:
    retentionHours: 168
    useHardlinks: true

  # Remote sync configuration
  remote:
    enabled: true
    syncIntervalSeconds: 3600  # Sync to remote every hour
    initialDelaySeconds: 300   # Wait 5 minutes before first sync

    # Remote storage path (rclone format)
    name: "s3"  # rclone remote name
    path: "my-bucket/cassandra-backups"

    # Retention in remote storage
    retentionDays: "30"

    # Authentication via Kubernetes secret
    authMethod: "env"
    secretName: "backup-s3-credentials"

    # Resource limits for rclone sidecar
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

Cree el secreto con las credenciales de S3:

```bash
kubectl create secret generic backup-s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE \
  --from-literal=AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  --from-literal=AWS_DEFAULT_REGION=us-east-1
```

Para almacenamiento compatible con S3 (MinIO, Ceph), añada la configuración del
endpoint:

```bash
kubectl create secret generic backup-s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=minioadmin \
  --from-literal=AWS_SECRET_ACCESS_KEY=minioadmin \
  --from-literal=AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000
```

### Restaurar desde una copia de seguridad

Para restaurar desde una copia remota al inicializar el pod:

```yaml
# values-restore.yaml
# Restore from the latest backup
restoreFromBackup: "latest"

# Or restore from a specific backup
# restoreFromBackup: "backup-20260114-102241"

backups:
  enabled: true
  remote:
    enabled: true
    name: "s3"
    path: "my-bucket/cassandra-backups"
    secretName: "backup-s3-credentials"
```

Instale con restauración:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-restore.yaml
```

**Importante:** el proceso de restauración descarga la copia indicada del
almacenamiento remoto y la restaura antes de que arranque Cassandra.

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

  # Database authentication from external secret store
  authentication:
    # AWS Secrets Manager example
    db_user: "ref+awssecrets://axonops/timeseries#username"
    db_password: "ref+awssecrets://axonops/timeseries#password"

    # HashiCorp Vault example
    # db_user: "ref+vault://secret/data/axonops/timeseries#username"
    # db_password: "ref+vault://secret/data/axonops/timeseries#password"

  # TLS keystore password (if using TLS)
  tls:
    keystorePassword: "ref+awssecrets://axonops/tls#keystore-password"

  # Remote backup credentials
  backup:
    awsAccessKeyId: "ref+awssecrets://axonops/backup#access-key-id"
    awsSecretAccessKey: "ref+awssecrets://axonops/backup#secret-access-key"
```

Instale:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-vals.yaml
```

Cuando vals-operator está activado, se crea un recurso `ValsSecret` que
vals-operator reconcilia en un secreto estándar de Kubernetes. Así se integra sin
fricción con los almacenes de secretos externos.

## Configuración

### Opciones de configuración principales

| Parámetro | Descripción | Valor por defecto |
|-----------|-------------|---------|
| `replicaCount` | Número de réplicas de la base de datos | `1` |
| `heapSize` | Tamaño del heap de la JVM de Cassandra | `1024M` |
| `image.repository` | El repositorio de la imagen de contenedor | `ghcr.io/axonops/axondb-timeseries` |
| `image.tag` | La etiqueta de la imagen de contenedor | `""` (usa la appVersion) |
| `authentication.db_user` | El usuario de la base de datos (sólo desarrollo) | `""` |
| `authentication.db_password` | La contraseña de la base de datos (sólo desarrollo) | `""` |
| `authentication.db_secret` | El nombre del secreto de Kubernetes con las credenciales | `""` |
| `persistence.enabled` | Activa el almacenamiento persistente | `true` |
| `persistence.data.size` | El tamaño del volumen de datos | `10Gi` |
| `persistence.data.storageClass` | La StorageClass del volumen de datos | `""` (la de por defecto) |
| `persistence.commitlog.enabled` | Activa un volumen aparte para el commitlog | `false` |
| `tls.enabled` | Activa el cifrado TLS/SSL | `false` |
| `tls.certManager.enabled` | Usa cert-manager para los certificados | `false` |
| `resources.requests.memory` | Petición de memoria | `nil` |
| `resources.limits.memory` | Límite de memoria | `nil` |

### Referencia completa de values

<details>
<summary>Pulse para desplegar la tabla completa de values</summary>

| Clave | Tipo | Valor por defecto | Descripción |
|-----|------|---------|-------------|
| affinity | object | `{}` | Reglas de afinidad de pod para la planificación |
| authentication.db_password | string | `""` | La contraseña de la base de datos (en texto plano: sólo desarrollo) |
| authentication.db_secret | string | `""` | El nombre del secreto de Kubernetes que contiene AXONOPS_DB_USER y AXONOPS_DB_PASSWORD |
| authentication.db_user | string | `""` | El usuario de la base de datos (en texto plano: sólo desarrollo) |
| envVars | list | `[]` | Variables de entorno adicionales, como lista |
| envVarsSecret | string | `""` | El nombre de un secreto que contiene variables de entorno |
| extraVolumeMounts | list | `[]` | Montajes de volumen adicionales para el pod |
| extraVolumes | list | `[]` | Volúmenes adicionales para el pod |
| fullnameOverride | string | `""` | Sustituye el nombre completo del recurso |
| heapSize | string | `"1024M"` | El tamaño del heap de la JVM (por ejemplo, 1024M, 8G) |
| image.pullPolicy | string | `"IfNotPresent"` | Política de descarga de la imagen |
| image.repository | string | `"ghcr.io/axonops/axondb-timeseries"` | El repositorio de la imagen de contenedor |
| image.tag | string | `""` | La etiqueta de la imagen (por defecto, la appVersion del chart) |
| imagePullSecrets | list | `[]` | Secretos de descarga de imágenes para registros privados |
| livenessProbe.enabled | bool | `true` | Activa la sonda de vida |
| livenessProbe.failureThreshold | int | `5` | Umbral de fallos de la sonda de vida |
| livenessProbe.initialDelaySeconds | int | `60` | Retardo inicial antes de que empiece la sonda de vida |
| livenessProbe.periodSeconds | int | `30` | Cada cuánto se ejecuta la sonda |
| livenessProbe.successThreshold | int | `1` | Umbral de éxitos de la sonda de vida |
| livenessProbe.timeoutSeconds | int | `30` | Timeout de la sonda de vida |
| nameOverride | string | `""` | Sustituye el nombre del chart |
| nodeSelector | object | `{}` | Etiquetas de nodo para asignar los pods |
| persistence.commitlog.accessMode | string | `"ReadWriteOnce"` | Modo de acceso del volumen de commitlog |
| persistence.commitlog.annotations | object | `{}` | Anotaciones de la PVC de commitlog |
| persistence.commitlog.enabled | bool | `false` | Activa un volumen aparte para el commitlog |
| persistence.commitlog.mountPath | string | `"/var/lib/cassandra/commitlog"` | Ruta de montaje del commitlog |
| persistence.commitlog.size | string | `"5Gi"` | Tamaño del volumen de commitlog |
| persistence.commitlog.storageClass | string | `""` | StorageClass del commitlog |
| persistence.data.accessMode | string | `"ReadWriteOnce"` | Modo de acceso del volumen de datos |
| persistence.data.annotations | object | `{}` | Anotaciones de la PVC de datos |
| persistence.data.mountPath | string | `"/var/lib/cassandra"` | Ruta de montaje de los datos |
| persistence.data.size | string | `"10Gi"` | Tamaño del volumen de datos |
| persistence.data.storageClass | string | `""` | StorageClass del volumen de datos |
| persistence.enabled | bool | `true` | Activa el almacenamiento persistente |
| podAnnotations | object | `{}` | Anotaciones de los pods |
| podLabels | object | `{}` | Etiquetas adicionales de los pods |
| podSecurityContext.fsGroup | int | `999` | FSGroup del contexto de seguridad del pod |
| readinessProbe.enabled | bool | `true` | Activa la sonda de disponibilidad |
| readinessProbe.failureThreshold | int | `5` | Umbral de fallos de la sonda de disponibilidad |
| readinessProbe.initialDelaySeconds | int | `60` | Retardo inicial antes de que empiece la sonda de disponibilidad |
| readinessProbe.periodSeconds | int | `10` | Cada cuánto se ejecuta la sonda |
| readinessProbe.successThreshold | int | `1` | Umbral de éxitos de la sonda de disponibilidad |
| readinessProbe.timeoutSeconds | int | `30` | Timeout de la sonda de disponibilidad |
| replicaCount | int | `1` | Número de réplicas |
| resources | object | `{}` | Peticiones y límites de CPU y memoria |
| securityContext.readOnlyRootFilesystem | bool | `false` | Monta el sistema de ficheros raíz en sólo lectura |
| securityContext.runAsNonRoot | bool | `true` | Ejecuta el contenedor como usuario no root |
| securityContext.runAsUser | int | `999` | El ID de usuario con el que se ejecuta el contenedor |
| service.port | int | `9042` | El puerto del servicio CQL |
| service.type | string | `"ClusterIP"` | El tipo de servicio de Kubernetes |
| serviceAccount.annotations | object | `{}` | Anotaciones de la cuenta de servicio |
| serviceAccount.automount | bool | `true` | Monta automáticamente el token de la cuenta de servicio |
| serviceAccount.create | bool | `true` | Crea la cuenta de servicio |
| serviceAccount.name | string | `""` | El nombre de la cuenta de servicio |
| serviceMonitor.annotations | object | `{}` | Anotaciones del ServiceMonitor |
| serviceMonitor.enabled | bool | `false` | Activa el ServiceMonitor de Prometheus |
| serviceMonitor.interval | string | `"30s"` | Intervalo de recogida |
| serviceMonitor.labels | object | `{}` | Etiquetas adicionales del ServiceMonitor |
| serviceMonitor.metricRelabelings | list | `[]` | Configuración de reetiquetado de métricas |
| serviceMonitor.port | string | `"jmx"` | El puerto del que recoger las métricas |
| serviceMonitor.relabelings | list | `[]` | Configuración de reetiquetado |
| serviceMonitor.scrapeTimeout | string | `"10s"` | Timeout de la recogida |
| serviceMonitor.selector | object | `{}` | Etiquetas de selector adicionales |
| tls.cassandra.internode.acceptedProtocols | string | `"TLSv1.2,TLSv1.3"` | Protocolos TLS aceptados entre nodos |
| tls.cassandra.internode.cipherSuites | list | `[]` | Conjuntos de cifrado del cifrado entre nodos |
| tls.cassandra.internode.encryption | string | `"all"` | Cifrado entre nodos: none, dc, rack, all |
| tls.cassandra.internode.protocol | string | `"TLS"` | Versión del protocolo TLS |
| tls.certManager.certificate.commonName | string | `""` | El common name del certificado |
| tls.certManager.certificate.dnsNames | list | `[]` | Los SAN de DNS del certificado |
| tls.certManager.certificate.duration | string | `"43800h"` | Duración de validez del certificado |
| tls.certManager.certificate.ipAddresses | list | `[]` | Los SAN de IP del certificado |
| tls.certManager.certificate.renewBefore | string | `"720h"` | Renueva el certificado con esta antelación |
| tls.certManager.certificate.secretName | string | `"axondb-timeseries-tls-cert"` | El nombre del secreto del certificado |
| tls.certManager.enabled | bool | `false` | Usa cert-manager para TLS |
| tls.certManager.issuer.createSelfSigned | bool | `true` | Crea un issuer autofirmado |
| tls.certManager.issuer.kind | string | `"ClusterIssuer"` | El tipo de issuer: Issuer o ClusterIssuer |
| tls.certManager.issuer.name | string | `""` | El nombre de un issuer existente |
| tls.certManager.keystorePassword | string | `"changeme"` | La contraseña del keystore de los ficheros JKS |
| tls.enabled | bool | `false` | Activa TLS/SSL |
| tls.manual.existingSecret | string | `""` | El secreto existente con los certificados manuales |
| tolerations | list | `[]` | Toleraciones para asignar los pods |

</details>

## Actualización

Para actualizar una instalación existente:

```bash
# Update the chart
helm upgrade axondb-timeseries ./axondb-timeseries -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axondb-timeseries
```

## Desinstalación

Para eliminar la base de datos de series temporales de AxonOps:

```bash
# Uninstall the release
helm uninstall axondb-timeseries

# Optional: Delete PVCs (this will delete all data!)
kubectl delete pvc -l app.kubernetes.io/name=axondb-timeseries
```

**Aviso:** borrar las PVC elimina de forma permanente todos los datos de la base
de datos. Asegúrese de tener copias de seguridad antes de seguir.

## Resolución de problemas

### Problemas habituales

**1. Los pods no arrancan (CrashLoopBackOff)**

Revise los registros del pod:
```bash
kubectl logs axondb-timeseries-0
```

Causas habituales:
- Memoria insuficiente (suba `heapSize` y `resources.limits.memory`)
- Problemas al aprovisionar el almacenamiento (revise el estado de las PVC con `kubectl get pvc`)
- Errores de configuración (verifique su fichero de values)

**2. Problemas de almacenamiento**

Revise el estado de las PVC:
```bash
kubectl get pvc
kubectl describe pvc data-axondb-timeseries-0
```

Si la PVC está en Pending:
- Compruebe que la StorageClass existe: `kubectl get storageclass`
- Compruebe que el aprovisionamiento dinámico está activado en su clúster

**3. Problemas con los certificados (cert-manager)**

Revise el estado del certificado:
```bash
kubectl get certificate
kubectl describe certificate axondb-timeseries-tls
kubectl get certificaterequest
```

Revise los registros de cert-manager:
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

**4. Errores de conexión rechazada**

Verifique el servicio:
```bash
kubectl get svc axondb-timeseries
kubectl describe svc axondb-timeseries
```

Pruebe la conectividad desde otro pod:
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  telnet axondb-timeseries 9042
```

**5. Uso alto de memoria**

Revise el uso real de memoria:
```bash
kubectl top pod axondb-timeseries-0
```

Ajuste el tamaño del heap (debería ser en torno al 50 % de la memoria del
contenedor):
```yaml
heapSize: 4096M
resources:
  limits:
    memory: 8Gi
```

### Obtener ayuda

Para soporte adicional:
- Revise los registros: `kubectl logs -f axondb-timeseries-0`
- Consulte los eventos: `kubectl get events --sort-by='.lastTimestamp'`
- Describa el StatefulSet: `kubectl describe statefulset axondb-timeseries`
- Visite la documentación de AxonOps: <https://docs.axonops.com>
- Contacte con el soporte de AxonOps: <info@axonops.com>

## Mantenedores

| Nombre | Correo | URL |
| ---- | ------ | --- |
| El equipo de AxonOps | <info@aoxnops.com> |  |

---

*Generado con los charts de Helm de AxonOps*
