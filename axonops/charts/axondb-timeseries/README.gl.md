# Base de datos de series temporais de AxonOps

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

![Versión: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Tipo: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 5.0.5-1.0.0](https://img.shields.io/badge/AppVersion-5.0.5--1.0.0-informational?style=flat-square)

Un chart de Helm para despregar a base de datos de series temporais de AxonOps
(baseada en Cassandra) sobre Kubernetes. Esta base de datos almacena as métricas e
os datos de monitorización da plataforma AxonOps.

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
  - [Instalación lista para produción](#instalación-lista-para-produción)
- [Configuración de copias de seguranza](#configuración-de-copias-de-seguranza)
  - [Copias de seguranza locais](#copias-de-seguranza-locais)
  - [Copias de seguranza remotas (S3)](#copias-de-seguranza-remotas-s3)
  - [Restaurar dende unha copia de seguranza](#restaurar-dende-unha-copia-de-seguranza)
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
- **Recursos**: recoméndanse polo menos 2 GB de memoria dispoñible e 2 núcleos de CPU

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

A forma máis rápida de comezar coa base de datos de series temporais de AxonOps:

```bash
# Add the AxonOps Helm repository (if available)
# helm repo add axonops https://axonops.github.io/helm-charts
# helm repo update

# Install with default settings
helm install axondb-timeseries ./axondb-timeseries

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axondb-timeseries
```

Isto desprega unha base de datos de series temporais dun só nodo con:
- 10 Gi de almacenamento persistente
- Os límites de recursos por defecto
- Sen autenticación (só para desenvolvemento)
- Sen cifrado TLS

## Exemplos de instalación

### Instalación básica

Instalación coa configuración mínima, apta para desenvolvemento e probas:

```bash
helm install axondb-timeseries ./axondb-timeseries \
  --set replicaCount=1
```

Ou cree un ficheiro `values-basic.yaml`:

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

Instale usando o ficheiro de values:

```bash
helm install axondb-timeseries ./axondb-timeseries -f values-basic.yaml
```

### Instalación con almacenamento personalizado

Configure o almacenamento persistente cunha StorageClass e un tamaño concretos:

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

Protexa a súa base de datos con credenciais de autenticación:

**Opción 1: valores directos (só desenvolvemento)**

```yaml
# values-auth.yaml
replicaCount: 1

authentication:
  db_user: "axonops"
  db_password: "your-secure-password"
```

**Opción 2: segredos de Kubernetes (recomendado en produción)**

Primeiro, cree un segredo de Kubernetes:

```bash
kubectl create secret generic axondb-credentials \
  --from-literal=AXONOPS_DB_USER=axonops \
  --from-literal=AXONOPS_DB_PASSWORD=your-secure-password
```

Despois cree o seu ficheiro de values:

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

### Instalación con TLS (certificados manuais)

Use certificados TLS xa existentes para cifrar a comunicación:

**Paso 1: cree un segredo cos seus certificados**

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

**Paso 2: cree o seu ficheiro de values**

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

**Cun issuer existente (produción):**

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

**Verifique a creación do certificado:**

```bash
kubectl get certificate
kubectl describe certificate axondb-timeseries-tls
```

### Instalación lista para produción

Unha configuración de produción completa, con todos os axustes recomendados:

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

**Antes de instalar, cree o segredo de autenticación:**

```bash
kubectl create secret generic axondb-credentials \
  --from-literal=AXONOPS_DB_USER=axonops \
  --from-literal=AXONOPS_DB_PASSWORD=$(openssl rand -base64 32)
```

**Instale o despregamento de produción:**

```bash
helm install axondb-timeseries ./axondb-timeseries \
  -f values-production.yaml \
  --namespace axonops \
  --create-namespace
```

## Configuración de copias de seguranza

O chart axondb-timeseries inclúe unha funcionalidade completa de copias de
seguranza baseada en snapshots de Cassandra con deduplicación mediante rsync. As
copias poden gardarse en local ou sincronizarse con almacenamento remoto
compatible con S3.

**Nota:** AxonDB Timeseries está pensado só para despregamentos dun só nodo. Os
clústeres de varios nodos non están admitidos para as operacións de copia de
seguranza.

### Copias de seguranza locais

Configure copias locais baseadas en snapshots con deduplicación por ligazóns
duras:

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

### Copias de seguranza remotas (S3)

Configure as copias para que se sincronicen con AWS S3 ou con almacenamento
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

Cree o segredo coas credenciais de S3:

```bash
kubectl create secret generic backup-s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE \
  --from-literal=AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  --from-literal=AWS_DEFAULT_REGION=us-east-1
```

Para almacenamento compatible con S3 (MinIO, Ceph), engada a configuración do
endpoint:

```bash
kubectl create secret generic backup-s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=minioadmin \
  --from-literal=AWS_SECRET_ACCESS_KEY=minioadmin \
  --from-literal=AWS_ENDPOINT_URL=http://minio.minio.svc.cluster.local:9000
```

### Restaurar dende unha copia de seguranza

Para restaurar dende unha copia remota ao inicializar o pod:

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

**Importante:** o proceso de restauración descarga a copia indicada do
almacenamento remoto e restáuraa antes de que arranque Cassandra.

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

Cando vals-operator está activado, créase un recurso `ValsSecret` que
vals-operator reconcilia nun segredo estándar de Kubernetes. Así intégrase sen
fricción cos almacéns de segredos externos.

## Configuración

### Opcións de configuración principais

| Parámetro | Descrición | Valor por defecto |
|-----------|-------------|---------|
| `replicaCount` | Número de réplicas da base de datos | `1` |
| `heapSize` | Tamaño do heap da JVM de Cassandra | `1024M` |
| `image.repository` | O repositorio da imaxe de contedor | `ghcr.io/axonops/axondb-timeseries` |
| `image.tag` | A etiqueta da imaxe de contedor | `""` (usa a appVersion) |
| `authentication.db_user` | O usuario da base de datos (só desenvolvemento) | `""` |
| `authentication.db_password` | O contrasinal da base de datos (só desenvolvemento) | `""` |
| `authentication.db_secret` | O nome do segredo de Kubernetes coas credenciais | `""` |
| `persistence.enabled` | Activa o almacenamento persistente | `true` |
| `persistence.data.size` | O tamaño do volume de datos | `10Gi` |
| `persistence.data.storageClass` | A StorageClass do volume de datos | `""` (a de por defecto) |
| `persistence.commitlog.enabled` | Activa un volume á parte para o commitlog | `false` |
| `tls.enabled` | Activa o cifrado TLS/SSL | `false` |
| `tls.certManager.enabled` | Usa cert-manager para os certificados | `false` |
| `resources.requests.memory` | Petición de memoria | `nil` |
| `resources.limits.memory` | Límite de memoria | `nil` |

### Referencia completa de values

<details>
<summary>Prema para despregar a táboa completa de values</summary>

| Chave | Tipo | Valor por defecto | Descrición |
|-----|------|---------|-------------|
| affinity | object | `{}` | Regras de afinidade de pod para a planificación |
| authentication.db_password | string | `""` | O contrasinal da base de datos (en texto plano: só desenvolvemento) |
| authentication.db_secret | string | `""` | O nome do segredo de Kubernetes que contén AXONOPS_DB_USER e AXONOPS_DB_PASSWORD |
| authentication.db_user | string | `""` | O usuario da base de datos (en texto plano: só desenvolvemento) |
| envVars | list | `[]` | Variables de entorno adicionais, como lista |
| envVarsSecret | string | `""` | O nome dun segredo que contén variables de entorno |
| extraVolumeMounts | list | `[]` | Montaxes de volume adicionais para o pod |
| extraVolumes | list | `[]` | Volumes adicionais para o pod |
| fullnameOverride | string | `""` | Substitúe o nome completo do recurso |
| heapSize | string | `"1024M"` | O tamaño do heap da JVM (por exemplo, 1024M, 8G) |
| image.pullPolicy | string | `"IfNotPresent"` | Política de descarga da imaxe |
| image.repository | string | `"ghcr.io/axonops/axondb-timeseries"` | O repositorio da imaxe de contedor |
| image.tag | string | `""` | A etiqueta da imaxe (por defecto, a appVersion do chart) |
| imagePullSecrets | list | `[]` | Segredos de descarga de imaxes para rexistros privados |
| livenessProbe.enabled | bool | `true` | Activa a sonda de vida |
| livenessProbe.failureThreshold | int | `5` | Limiar de fallos da sonda de vida |
| livenessProbe.initialDelaySeconds | int | `60` | Retardo inicial antes de que comece a sonda de vida |
| livenessProbe.periodSeconds | int | `30` | Cada canto se executa a sonda |
| livenessProbe.successThreshold | int | `1` | Limiar de éxitos da sonda de vida |
| livenessProbe.timeoutSeconds | int | `30` | Timeout da sonda de vida |
| nameOverride | string | `""` | Substitúe o nome do chart |
| nodeSelector | object | `{}` | Etiquetas de nodo para asignar os pods |
| persistence.commitlog.accessMode | string | `"ReadWriteOnce"` | Modo de acceso do volume de commitlog |
| persistence.commitlog.annotations | object | `{}` | Anotacións da PVC de commitlog |
| persistence.commitlog.enabled | bool | `false` | Activa un volume á parte para o commitlog |
| persistence.commitlog.mountPath | string | `"/var/lib/cassandra/commitlog"` | Ruta de montaxe do commitlog |
| persistence.commitlog.size | string | `"5Gi"` | Tamaño do volume de commitlog |
| persistence.commitlog.storageClass | string | `""` | StorageClass do commitlog |
| persistence.data.accessMode | string | `"ReadWriteOnce"` | Modo de acceso do volume de datos |
| persistence.data.annotations | object | `{}` | Anotacións da PVC de datos |
| persistence.data.mountPath | string | `"/var/lib/cassandra"` | Ruta de montaxe dos datos |
| persistence.data.size | string | `"10Gi"` | Tamaño do volume de datos |
| persistence.data.storageClass | string | `""` | StorageClass do volume de datos |
| persistence.enabled | bool | `true` | Activa o almacenamento persistente |
| podAnnotations | object | `{}` | Anotacións dos pods |
| podLabels | object | `{}` | Etiquetas adicionais dos pods |
| podSecurityContext.fsGroup | int | `999` | FSGroup do contexto de seguridade do pod |
| readinessProbe.enabled | bool | `true` | Activa a sonda de dispoñibilidade |
| readinessProbe.failureThreshold | int | `5` | Limiar de fallos da sonda de dispoñibilidade |
| readinessProbe.initialDelaySeconds | int | `60` | Retardo inicial antes de que comece a sonda de dispoñibilidade |
| readinessProbe.periodSeconds | int | `10` | Cada canto se executa a sonda |
| readinessProbe.successThreshold | int | `1` | Limiar de éxitos da sonda de dispoñibilidade |
| readinessProbe.timeoutSeconds | int | `30` | Timeout da sonda de dispoñibilidade |
| replicaCount | int | `1` | Número de réplicas |
| resources | object | `{}` | Peticións e límites de CPU e memoria |
| securityContext.readOnlyRootFilesystem | bool | `false` | Monta o sistema de ficheiros raíz en só lectura |
| securityContext.runAsNonRoot | bool | `true` | Executa o contedor como usuario non root |
| securityContext.runAsUser | int | `999` | O ID de usuario co que se executa o contedor |
| service.port | int | `9042` | O porto do servizo CQL |
| service.type | string | `"ClusterIP"` | O tipo de servizo de Kubernetes |
| serviceAccount.annotations | object | `{}` | Anotacións da conta de servizo |
| serviceAccount.automount | bool | `true` | Monta automaticamente o token da conta de servizo |
| serviceAccount.create | bool | `true` | Crea a conta de servizo |
| serviceAccount.name | string | `""` | O nome da conta de servizo |
| serviceMonitor.annotations | object | `{}` | Anotacións do ServiceMonitor |
| serviceMonitor.enabled | bool | `false` | Activa o ServiceMonitor de Prometheus |
| serviceMonitor.interval | string | `"30s"` | Intervalo de recollida |
| serviceMonitor.labels | object | `{}` | Etiquetas adicionais do ServiceMonitor |
| serviceMonitor.metricRelabelings | list | `[]` | Configuración de reetiquetado de métricas |
| serviceMonitor.port | string | `"jmx"` | O porto do que recoller as métricas |
| serviceMonitor.relabelings | list | `[]` | Configuración de reetiquetado |
| serviceMonitor.scrapeTimeout | string | `"10s"` | Timeout da recollida |
| serviceMonitor.selector | object | `{}` | Etiquetas de selector adicionais |
| tls.cassandra.internode.acceptedProtocols | string | `"TLSv1.2,TLSv1.3"` | Protocolos TLS aceptados entre nodos |
| tls.cassandra.internode.cipherSuites | list | `[]` | Conxuntos de cifrado do cifrado entre nodos |
| tls.cassandra.internode.encryption | string | `"all"` | Cifrado entre nodos: none, dc, rack, all |
| tls.cassandra.internode.protocol | string | `"TLS"` | Versión do protocolo TLS |
| tls.certManager.certificate.commonName | string | `""` | O common name do certificado |
| tls.certManager.certificate.dnsNames | list | `[]` | Os SAN de DNS do certificado |
| tls.certManager.certificate.duration | string | `"43800h"` | Duración de validez do certificado |
| tls.certManager.certificate.ipAddresses | list | `[]` | Os SAN de IP do certificado |
| tls.certManager.certificate.renewBefore | string | `"720h"` | Renova o certificado con esta antelación |
| tls.certManager.certificate.secretName | string | `"axondb-timeseries-tls-cert"` | O nome do segredo do certificado |
| tls.certManager.enabled | bool | `false` | Usa cert-manager para TLS |
| tls.certManager.issuer.createSelfSigned | bool | `true` | Crea un issuer autoasinado |
| tls.certManager.issuer.kind | string | `"ClusterIssuer"` | O tipo de issuer: Issuer ou ClusterIssuer |
| tls.certManager.issuer.name | string | `""` | O nome dun issuer existente |
| tls.certManager.keystorePassword | string | `"changeme"` | O contrasinal do keystore dos ficheiros JKS |
| tls.enabled | bool | `false` | Activa TLS/SSL |
| tls.manual.existingSecret | string | `""` | O segredo existente cos certificados manuais |
| tolerations | list | `[]` | Tolerancias para asignar os pods |

</details>

## Actualización

Para actualizar unha instalación existente:

```bash
# Update the chart
helm upgrade axondb-timeseries ./axondb-timeseries -f values-production.yaml

# Check rollout status
kubectl rollout status statefulset/axondb-timeseries
```

## Desinstalación

Para eliminar a base de datos de series temporais de AxonOps:

```bash
# Uninstall the release
helm uninstall axondb-timeseries

# Optional: Delete PVCs (this will delete all data!)
kubectl delete pvc -l app.kubernetes.io/name=axondb-timeseries
```

**Aviso:** borrar as PVC elimina de forma permanente todos os datos da base de
datos. Asegúrese de ter copias de seguranza antes de seguir.

## Resolución de problemas

### Problemas habituais

**1. Os pods non arrancan (CrashLoopBackOff)**

Revise os rexistros do pod:
```bash
kubectl logs axondb-timeseries-0
```

Causas habituais:
- Memoria insuficiente (suba `heapSize` e `resources.limits.memory`)
- Problemas ao aprovisionar o almacenamento (revise o estado das PVC con `kubectl get pvc`)
- Erros de configuración (verifique o seu ficheiro de values)

**2. Problemas de almacenamento**

Revise o estado das PVC:
```bash
kubectl get pvc
kubectl describe pvc data-axondb-timeseries-0
```

Se a PVC está en Pending:
- Comprobe que a StorageClass existe: `kubectl get storageclass`
- Comprobe que o aprovisionamento dinámico está activado no seu clúster

**3. Problemas cos certificados (cert-manager)**

Revise o estado do certificado:
```bash
kubectl get certificate
kubectl describe certificate axondb-timeseries-tls
kubectl get certificaterequest
```

Revise os rexistros de cert-manager:
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

**4. Erros de conexión rexeitada**

Verifique o servizo:
```bash
kubectl get svc axondb-timeseries
kubectl describe svc axondb-timeseries
```

Probe a conectividade dende outro pod:
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  telnet axondb-timeseries 9042
```

**5. Uso alto de memoria**

Revise o uso real de memoria:
```bash
kubectl top pod axondb-timeseries-0
```

Axuste o tamaño do heap (debería ser arredor do 50 % da memoria do contedor):
```yaml
heapSize: 4096M
resources:
  limits:
    memory: 8Gi
```

### Obter axuda

Para soporte adicional:
- Revise os rexistros: `kubectl logs -f axondb-timeseries-0`
- Consulte os eventos: `kubectl get events --sort-by='.lastTimestamp'`
- Describa o StatefulSet: `kubectl describe statefulset axondb-timeseries`
- Visite a documentación de AxonOps: <https://docs.axonops.com>
- Contacte co soporte de AxonOps: <info@axonops.com>

## Mantedores

| Nome | Correo | URL |
| ---- | ------ | --- |
| O equipo de AxonOps | <info@aoxnops.com> |  |

---

*Xerado cos charts de Helm de AxonOps*
