# Base de datos de búsqueda AxonDB

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

[![Paquete GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axondb-search)

Contenedor de OpenSearch 3.3.2 listo para producción, optimizado para cargas de
búsqueda en despliegues autoalojados de AxonOps.

## Índice

- [Visión general](#visión-general)
- [Imágenes de Docker precompiladas](#imágenes-de-docker-precompiladas)
  - [Imágenes disponibles](#imágenes-disponibles)
  - [Estrategia de etiquetado](#estrategia-de-etiquetado)
- [Buena práctica en producción](#buena-práctica-en-producción)
- [Despliegue](#despliegue)
  - [Requisitos del despliegue en Kubernetes](#requisitos-del-despliegue-en-kubernetes)
- [Construir las imágenes de Docker](#construir-las-imágenes-de-docker)
- [Variables de entorno](#variables-de-entorno)
- [Prestaciones del contenedor](#prestaciones-del-contenedor)
  - [Script de entrypoint](#script-de-entrypoint)
  - [Banner de versión al arrancar](#banner-de-versión-al-arrancar)
  - [Sondas de salud](#sondas-de-salud)
  - [Seguridad y gestión de certificados](#seguridad-y-gestión-de-certificados)
  - [Inicialización automatizada (configuración de seguridad y usuario administrador)](#inicialización-automatizada-configuración-de-seguridad-y-usuario-administrador)
- [Ficheros de configuración](#ficheros-de-configuración)
- [Pipeline de CI/CD](#pipeline-de-cicd)
  - [Workflows](#workflows)
  - [Pruebas automatizadas](#pruebas-automatizadas)
  - [Proceso de publicación](#proceso-de-publicación)
- [Resolución de problemas](#resolución-de-problemas)
  - [Comprobar la versión del contenedor](#comprobar-la-versión-del-contenedor)
  - [Registros del script de inicialización](#registros-del-script-de-inicialización)
  - [Depurar la comprobación de salud](#depurar-la-comprobación-de-salud)
  - [El contenedor no arranca](#el-contenedor-no-arranca)
- [Consideraciones para producción](#consideraciones-para-producción)

## Visión general

AxonDB Search es un contenedor de OpenSearch listo para producción, diseñado
expresamente para los despliegues autoalojados de AxonOps. Está optimizado para
cargas de base de datos de búsqueda y se despliega como parte de la pila completa
de AxonOps con los charts de Helm de AxonOps.

**Prestaciones del contenedor:**
- **Motor de búsqueda moderno**: OpenSearch 3.3.2, con búsqueda de texto completo, analítica y capacidades de visualización
- **Seguridad de producción**: certificados TLS con la marca AxonOps (RSA 3072, no certificados de demostración)
- **Configuración automatizada**: plugin de seguridad preconfigurado, con creación opcional de un usuario administrador propio
- **Base empresarial**: construido sobre Red Hat UBI 9 minimal, para estabilidad en producción
- **Seguridad de la cadena de suministro**: imágenes base fijadas por digest, para builds inmutables
- **Monitorización de producción**: sondas de salud integradas (startup, liveness, readiness)

**Importante:** este contenedor está pensado exclusivamente para despliegues
autoalojados de AxonOps. Se despliega y se configura a través de los charts de
Helm de AxonOps, que se ocupan de toda la orquestación, la red y la integración
con la plataforma de monitorización y gestión de AxonOps. Para más información
sobre AxonOps, véase [axonops.com](https://axonops.com).

## Imágenes de Docker precompiladas

Hay imágenes precompiladas disponibles en GitHub Container Registry (GHCR). Es la
forma más sencilla de empezar.

### Imágenes disponibles

Todas las imágenes están en: `ghcr.io/axonops/axondb-search`

Consulte todas las etiquetas disponibles:
[GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axondb-search)

### Estrategia de etiquetado

Las imágenes usan una estrategia de etiquetado bidimensional:

| Patrón de etiqueta | Ejemplo | Descripción | Caso de uso |
|-------------|---------|-------------|----------|
| `{OPENSEARCH}-{AXON}` | `3.3.2-1.0.0` | Totalmente inmutable (versión de OpenSearch + de AxonOps) | **Producción**: fije versiones exactas para una auditabilidad completa |
| `@sha256:<digest>` | `@sha256:abc123...` | Basada en digest (criptográficamente inmutable) | **Máxima seguridad**: integridad de la imagen garantizada |
| `{OPENSEARCH}` | `3.3.2` | El último AxonOps para esa versión de OpenSearch | Seguir las actualizaciones de AxonOps de una versión concreta de OpenSearch |
| `latest` | `latest` | La última de todas las versiones | Sólo para pruebas rápidas (NO para producción) |

**Dimensiones del versionado:**
- **OPENSEARCH**: la versión de OpenSearch (por ejemplo, 3.3.2)
- **AXON**: la versión del contenedor de AxonOps (por ejemplo, 1.0.0, en SemVer)

**Ejemplos de etiquetado:**

Cuando se construye `3.3.2-1.0.0` (y es la más reciente):
- `3.3.2-1.0.0` (inmutable: no cambia nunca)
- `3.3.2` (flotante: se reetiqueta a builds de AxonOps más nuevos)
- `latest` (flotante: se mueve a versiones de OpenSearch más nuevas)

## 💡 Buena práctica en producción

⚠️ **Usar `latest` o etiquetas flotantes en producción es un antipatrón.** Esto
incluye `latest` y `3.3.2`, porque:
- **No hay rastro de auditoría**: no se puede determinar qué versión exacta estaba desplegada en un momento dado
- **Actualizaciones inesperadas**: los orquestadores de contenedores pueden descargar imágenes nuevas al reiniciar
- **Dificultades para volver atrás**: no se puede retroceder de forma fiable a versiones anteriores
- **Problemas de cumplimiento**: muchos marcos normativos exigen un seguimiento de versiones inmutable

👍 **Estrategias de despliegue recomendadas (de mayor a menor seguridad):**

1. **🥇 Referencia de oro: basada en digest** (máxima seguridad)
   ```bash
   docker pull ghcr.io/axonops/axondb-search@sha256:abc123...
   ```
   - 100 % inmutable, garantizado criptográficamente
   - Obligatoria en entornos regulados
   - Verifique la firma con Cosign (véase la nota de seguridad más abajo)

2. **🥈 Etiqueta inmutable** (el estándar de producción)
   ```bash
   docker pull ghcr.io/axonops/axondb-search:3.3.2-1.0.0
   ```
   - Fijada a una versión concreta (OpenSearch 3.3.2 + AxonOps 1.0.0)
   - Fácil de leer y de gestionar
   - Mantiene un rastro de auditoría completo

3. **🥉 Etiquetas flotantes** (sólo desarrollo y pruebas)
   ```bash
   docker pull ghcr.io/axonops/axondb-search:latest
   ```
   - Iteración rápida
   - NO para producción
   - Úselas sólo para pruebas de concepto y pruebas

**Nota de seguridad:** todas las imágenes de producción están firmadas
criptográficamente con Cosign de Sigstore, con firma sin claves. Verifique las
firmas antes de desplegar:

```bash
# Install cosign
# macOS: brew install cosign
# Linux: https://docs.sigstore.dev/cosign/installation

# Verify signature
cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Check signature exists
cosign tree ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

## Despliegue

Este contenedor se despliega exclusivamente mediante los **charts de Helm de
AxonOps**, como parte de la pila autoalojada de AxonOps. Los charts de Helm se
ocupan de toda la configuración, la orquestación y la integración con los
componentes de monitorización y gestión de AxonOps.

Para las instrucciones de despliegue, consulte la documentación de despliegue
autoalojado de AxonOps (disponible cuando se publiquen los charts de Helm).

### Requisitos del despliegue en Kubernetes

**Requisitos previos CRÍTICOS para los despliegues en Kubernetes:**

OpenSearch necesita configuraciones concretas a nivel de sistema en los nodos de
Kubernetes y en los contextos de seguridad de los pods. Estos ajustes son
obligatorios en los despliegues de producción.

#### 1. Configuración a nivel de nodo (vm.max_map_count)

OpenSearch usa un directorio mmapfs para guardar los índices. Los límites por
defecto del sistema operativo sobre el número de mmap suelen ser demasiado bajos,
y eso puede provocar excepciones por falta de memoria.

**Requisito: `vm.max_map_count` >= 262144 en TODOS los nodos de Kubernetes**

```bash
# Check current value on node
sysctl vm.max_map_count

# Set permanently on each Kubernetes node
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# OR use a DaemonSet to set on all nodes automatically
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: opensearch-sysctl
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: opensearch-sysctl
  template:
    metadata:
      labels:
        name: opensearch-sysctl
    spec:
      hostNetwork: true
      hostPID: true
      initContainers:
      - name: sysctl
        image: busybox
        command: ['sh', '-c', 'sysctl -w vm.max_map_count=262144']
        securityContext:
          privileged: true
      containers:
      - name: pause
        image: gcr.io/google_containers/pause
EOF
```

#### 2. Contexto de seguridad del pod (ulimits y capacidades)

**Requisito: `ulimits.nofile` (descriptores de fichero máximos) >= 65536**

OpenSearch necesita un número alto de descriptores de fichero. Además,
`bootstrap.memory_lock: true` (configurado en `opensearch.yml`) requiere la
capacidad `IPC_LOCK`, para evitar que la memoria se vaya a swap.

**Configuración de seguridad del pod completa:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: axondb-search
spec:
  # Enable IPC_LOCK capability for bootstrap.memory_lock
  securityContext:
    capabilities:
      add:
        - IPC_LOCK
    # Memory lock requires memlock=-1 (unlimited)
    # This is handled by the IPC_LOCK capability in Kubernetes

  containers:
  - name: opensearch
    image: ghcr.io/axonops/axondb-search:3.3.2-1.0.0

    # CRITICAL: Set resource limits
    resources:
      requests:
        memory: "12Gi"  # 1.5x heap size (8G default)
        cpu: "4"
      limits:
        memory: "16Gi"
        cpu: "8"

    # CRITICAL: Set ulimits via securityContext
    securityContext:
      # OpenSearch runs as UID 999 (opensearch user)
      runAsUser: 999
      runAsGroup: 999
      # Allow memory locking (for bootstrap.memory_lock)
      capabilities:
        add:
          - IPC_LOCK
      # Set nofile (max open files) to 65536
      # Note: In Kubernetes, this is set via container securityContext
      # The actual ulimit is controlled by the container runtime
      # For containerd/CRI-O, set limits in container runtime config
      allowPrivilegeEscalation: false

    env:
    # Heap size (default: 8g)
    - name: OPENSEARCH_HEAP_SIZE
      value: "8g"

    # Custom admin user (optional but recommended)
    - name: AXONOPS_SEARCH_USER
      value: "dbadmin"
    - name: AXONOPS_SEARCH_PASSWORD
      valueFrom:
        secretKeyRef:
          name: opensearch-credentials
          key: admin-password

    # TLS enabled (default: true)
    - name: AXONOPS_SEARCH_TLS_ENABLED
      value: "true"

    # Cluster configuration
    - name: OPENSEARCH_CLUSTER_NAME
      value: "axonops-production"
    - name: OPENSEARCH_NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name

    # Volume mounts
    volumeMounts:
    - name: data
      mountPath: /var/lib/opensearch
    - name: logs
      mountPath: /var/log/opensearch

    # Healthcheck probes
    startupProbe:
      exec:
        command:
          - /usr/local/bin/healthcheck.sh
          - startup
      initialDelaySeconds: 30
      periodSeconds: 10
      timeoutSeconds: 10
      failureThreshold: 30  # 5 minutes max startup time

    livenessProbe:
      exec:
        command:
          - /usr/local/bin/healthcheck.sh
          - liveness
      initialDelaySeconds: 60
      periodSeconds: 10
      timeoutSeconds: 10
      failureThreshold: 3

    readinessProbe:
      exec:
        command:
          - /usr/local/bin/healthcheck.sh
          - readiness
      initialDelaySeconds: 60
      periodSeconds: 10
      timeoutSeconds: 10
      failureThreshold: 3

  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: opensearch-data
  - name: logs
    emptyDir: {}
```

**Ejemplo de StatefulSet (para clústeres de producción):**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: axondb-search
spec:
  serviceName: axondb-search
  replicas: 3
  selector:
    matchLabels:
      app: axondb-search
  template:
    metadata:
      labels:
        app: axondb-search
    spec:
      # Anti-affinity to spread pods across nodes
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: axondb-search
            topologyKey: kubernetes.io/hostname

      # Init container to set ulimits (if container runtime doesn't support it)
      initContainers:
      - name: increase-ulimit
        image: busybox
        command:
          - sh
          - -c
          - ulimit -n 65536
        securityContext:
          privileged: true

      # OpenSearch container (see Pod example above for full configuration)
      containers:
      - name: opensearch
        image: ghcr.io/axonops/axondb-search:3.3.2-1.0.0
        # ... (rest of container config from Pod example)

  # Persistent volume claim template
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 500Gi
```

**Notas importantes:**
- **vm.max_map_count**: hay que fijarlo en TODOS los nodos de Kubernetes (no sólo en el pod)
- **ulimits.nofile**: se fija con `securityContext` o con un contenedor de inicialización
- **IPC_LOCK**: hace falta para `bootstrap.memory_lock: true` (evita el swap)
- **Volúmenes persistentes**: use almacenamiento SSD con IOPS adecuadas en producción
- **Memoria**: asigne al menos 1,5 veces el tamaño del heap (por ejemplo, 12 Gi para un heap de 8 G)

## Construir las imágenes de Docker

Si prefiere construir las imágenes usted mismo en lugar de usar las
precompiladas:

```bash
cd axonops/axondb-search/opensearch/3.3.2

# Minimal build (required args only)
docker build \
  --build-arg OPENSEARCH_VERSION=3.3.2 \
  -t axondb-search:3.3.2-1.0.0 \
  .

# Multi-arch build (amd64 + arm64) using buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg OPENSEARCH_VERSION=3.3.2 \
  -t axondb-search:3.3.2-1.0.0 \
  .
```

**Argumentos de build obligatorios:**
- `OPENSEARCH_VERSION`: la versión de OpenSearch (por ejemplo, 3.3.2)

**Argumentos de build opcionales (mejoran los metadatos, pero no son
obligatorios):**
- `BUILD_DATE`: la marca de tiempo del build (formato ISO 8601, por ejemplo, `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF`: el SHA del commit de git (por ejemplo, `$(git rev-parse HEAD)`)
- `VERSION`: la versión del contenedor (por ejemplo, 1.0.0)
- `GIT_TAG`: el nombre de la etiqueta de git (para los enlaces de release/tag del banner)
- `GITHUB_ACTOR`: el usuario que lanzó el build (para el rastro de auditoría)
- `IS_PRODUCTION_RELEASE`: póngalo a `true` para producción (por defecto: `false`)
- `IMAGE_FULL_NAME`: el nombre completo de la imagen con la etiqueta (se muestra en el banner de arranque)

**Seguridad de la cadena de suministro:**

Nuestro Dockerfile usa imágenes base fijadas por digest, por seguridad de la
cadena de suministro:

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
ARG UBI9_MINIMAL_DIGEST=sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2
FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
```

**Por qué importa fijar por digest:**
- Las etiquetas pueden sustituirse de forma maliciosa (misma etiqueta, imagen distinta)
- Los digests son criptográficamente inmutables: no pueden cambiarse
- Evita comprometer en silencio su cadena de suministro de contenedores
- Es la buena práctica del sector para los builds de producción

## Variables de entorno

El contenedor admite 18 variables de entorno de configuración:

| Variable | Descripción | Valor por defecto | Categoría |
|----------|-------------|---------|----------|
| `OPENSEARCH_CLUSTER_NAME` | El nombre del clúster | `axonopsdb-search` | Configuración de OpenSearch |
| `OPENSEARCH_NODE_NAME` | El nombre del nodo | `${HOSTNAME}` | Configuración de OpenSearch |
| `OPENSEARCH_NETWORK_HOST` | La dirección de escucha de red | `0.0.0.0` | Configuración de OpenSearch |
| `OPENSEARCH_DISCOVERY_TYPE` | El tipo de descubrimiento del clúster (`single-node` o multinodo) | `single-node` | Configuración de OpenSearch |
| `OPENSEARCH_HEAP_SIZE` | El tamaño del heap de la JVM (tanto -Xms como -Xmx) | `8g` | Configuración de OpenSearch |
| `OPENSEARCH_HTTP_PORT` | El puerto de la API HTTP | `9200` | Configuración de OpenSearch |
| `OPENSEARCH_DATA_DIR` | La ruta del directorio de datos | `/var/lib/opensearch` | Configuración de OpenSearch |
| `OPENSEARCH_LOG_DIR` | La ruta del directorio de registros | `/var/log/opensearch` | Configuración de OpenSearch |
| `OPENSEARCH_PATH_CONF` | La ruta del directorio de configuración | `/etc/opensearch` | Configuración de OpenSearch |
| `AXONOPS_SEARCH_USER` | Crea un usuario administrador propio con este nombre (sustituye al admin por defecto) | - | Seguridad e inicialización |
| `AXONOPS_SEARCH_PASSWORD` | La contraseña del administrador propio (obligatoria si se define `AXONOPS_SEARCH_USER`) | - | Seguridad e inicialización |
| `AXONOPS_SEARCH_TLS_ENABLED` | Activa HTTPS en la API REST (póngalo a `false` si el balanceador termina el TLS) | `true` | Seguridad e inicialización |
| `GENERATE_CERTS_ON_STARTUP` | Genera los certificados por defecto de AxonOps en tiempo de ejecución si faltan | `true` | Seguridad e inicialización |
| `OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE` | El tamaño de la cola del pool de hilos de escritura (súbalo con muchas escrituras) | `10000` | Avanzado y transporte |
| `OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION` | Exige la verificación del nombre de host en el SSL de transporte | `false` | Avanzado y transporte |
| `OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE` | El modo de autenticación de cliente HTTP (`NONE`, `OPTIONAL`, `REQUIRED`) | `NONE` | Avanzado y transporte |
| `OPENSEARCH_SECURITY_ADMIN_DN` | El DN del certificado de administración propio (para escenarios con certificados propios) | `OU=Database,O=AxonOps,CN=admin.axondbsearch.axonops.com` | Avanzado y transporte |
| `OPENSEARCH_SECURITY_NODES_DN` | Los DN de los certificados de nodo para la comunicación entre nodos (lista separada por puntos y coma, admite comodines) | `CN=*.axonops.svc.cluster.local` | Avanzado y transporte |
| `DISABLE_SECURITY_PLUGIN` | Desactiva por completo el plugin de seguridad (NO recomendado en producción) | `false` | Control de plugins |
| `DISABLE_PERFORMANCE_ANALYZER_AGENT_CLI` | Desactiva el analizador de rendimiento (AxonOps ya aporta la monitorización) | `true` | Control de plugins |

### Configuración de OpenSearch

Las 9 primeras variables configuran el comportamiento central de OpenSearch. El
script de entrypoint las procesa y las aplica a los ficheros de configuración
antes de que OpenSearch arranque.

**Configuración de red:**
- `OPENSEARCH_NETWORK_HOST`: póngala a `0.0.0.0` para escuchar en todas las interfaces
- `OPENSEARCH_HTTP_PORT`: el puerto de la API REST (por defecto: 9200)

**Configuración del clúster:**
- `OPENSEARCH_CLUSTER_NAME`: un nombre descriptivo para el clúster
- `OPENSEARCH_NODE_NAME`: por defecto, el nombre de host del pod en Kubernetes
- `OPENSEARCH_DISCOVERY_TYPE`: póngala a `single-node` para clústeres de un solo nodo, o configure los seed hosts para varios nodos

**Configuración de recursos:**
- `OPENSEARCH_HEAP_SIZE`: controla el heap de la JVM (tanto -Xms como -Xmx toman el mismo valor)
- Recomendación: el 50 % de la memoria del contenedor, con un máximo de 32 GB

**Ejemplo:**
```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_CLUSTER_NAME=production-search \
  -e OPENSEARCH_NODE_NAME=search-node-01 \
  -e OPENSEARCH_HEAP_SIZE=16g \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=SecurePassword123 \
  -p 9200:9200 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

### Control de la seguridad y la inicialización

**Configuración de TLS/SSL:**

Por defecto, el contenedor activa HTTPS en la API REST con certificados de la
marca AxonOps. Si usa un balanceador de carga o un ingress que termina el TLS,
puede desactivar el SSL de HTTP:

```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_TLS_ENABLED=false \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Importante:** el SSL de la capa de transporte (la comunicación entre nodos)
sigue activo aunque se desactive el SSL de HTTP.

**Usuario administrador propio (modelo de SUSTITUCIÓN):**

El contenedor permite crear un usuario administrador propio que **SUSTITUYE** al
usuario administrador por defecto. Esto es distinto de AxonDB Time-Series, que
añade un usuario propio: en OpenSearch, por seguridad, sólo debería existir un
usuario administrador.

```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=MySecurePassword123 \
  -p 9200:9200 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Connect with new credentials
curl -k -u dbadmin:MySecurePassword123 https://localhost:9200/_cluster/health
```

**Importante:**
- La creación del usuario propio ocurre **antes** de que OpenSearch arranque (previa al arranque, no en segundo plano)
- El usuario `admin` por defecto se **ELIMINA** de `internal_users.yml`
- Sólo existirá el usuario propio (sin admin por defecto)
- La creación del usuario es atómica: o termina por completo, o se deshace

### Configuración avanzada

**Configuración del pool de hilos:**

Con cargas de mucha escritura, puede que necesite subir el tamaño de la cola del
pool de hilos de escritura:

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE=20000 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Configuración del SSL de transporte:**

Para clústeres de varios nodos con requisitos de seguridad estrictos:

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION=true \
  -e OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE=OPTIONAL \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**DN de los certificados de nodo (seguridad multinodo):**

En los clústeres de varios nodos, configure qué Distinguished Names (DN) de
certificado se admiten para la comunicación entre nodos. Es crítico para asegurar
la comunicación de la capa de transporte entre nodos de OpenSearch.

```bash
# Single DN (default)
docker run -d --name axondb-search \
  -e OPENSEARCH_SECURITY_NODES_DN="CN=*.axonops.svc.cluster.local" \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Multiple DNs (semicolon-separated)
docker run -d --name axondb-search \
  -e OPENSEARCH_SECURITY_NODES_DN="CN=*.example.svc.cluster.local;CN=node-1.example.com;CN=node-2.example.com" \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Importante:**
- Use puntos y coma (`;`) para separar varios DN
- Admite comodines (por ejemplo, `CN=*.svc.cluster.local`) para los nombres de pod dinámicos de Kubernetes
- Los espacios alrededor de los DN se recortan automáticamente
- Sólo los nodos con certificados que casen con esos DN pueden unirse al clúster
- Es esencial para impedir que nodos no autorizados se unan a su clúster

**Ejemplo de StatefulSet de Kubernetes:**
```yaml
env:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.default.svc.cluster.local;CN=axondb-search-0;CN=axondb-search-1;CN=axondb-search-2"
```

Esta configuración genera lo siguiente en `opensearch.yml`:
```yaml
plugins.security.nodes_dn:
  - "CN=*.axondb-search.default.svc.cluster.local"
  - "CN=axondb-search-0"
  - "CN=axondb-search-1"
  - "CN=axondb-search-2"
```

## Prestaciones del contenedor

### Script de entrypoint

El script de entrypoint (`/usr/local/bin/docker-entrypoint.sh`) es el
orquestador principal que configura OpenSearch y gestiona el arranque del
contenedor. Se ejecuta como PID 1 a través de
[tini](https://github.com/krallin/tini) y hace la inicialización crítica antes de
arrancar OpenSearch.

#### tini: un sistema de init mínimo

El contenedor usa **tini** como sistema de init (PID 1). Tini es un sistema de
init mínimo, pensado expresamente para contenedores, que:

- **Maneja bien las señales**: reenvía las señales (SIGTERM, SIGINT) a los procesos hijos, para un apagado ordenado
- **Recoge los procesos zombis**: limpia los procesos hijos terminados que, si no, se irían acumulando
- **Es extremadamente ligero**: un único binario estático (~10 KB), con una sobrecarga mínima
- **Es un estándar del sector**: Docker lo usa como init por defecto cuando se pasa `--init`

El Dockerfile fija tini como envoltorio del entrypoint:
```dockerfile
ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["opensearch"]
```

Eso significa que el árbol de procesos real es:
```
tini (PID 1)
  └─► docker-entrypoint.sh
       └─► opensearch (after exec)
```

Tras `exec opensearch`, OpenSearch sustituye al script de shell, pero tini sigue
siendo el PID 1, lo que garantiza un manejo correcto de las señales en todo el
contenedor.

**Más información:** [github.com/krallin/tini](https://github.com/krallin/tini)

#### Qué hace

**1. Muestra el banner de arranque**
- Toma los metadatos del build de `/etc/axonops/build-info.txt`
- Imprime información de versión completa (OpenSearch, Java, sistema operativo)
- Muestra el entorno de ejecución (detección de Kubernetes, nombre de host)
- Muestra la información de seguridad de la cadena de suministro (el digest de la imagen base)

**2. Define las variables de entorno por defecto**
- `OPENSEARCH_CLUSTER_NAME` (por defecto: `axonopsdb-search`)
- `OPENSEARCH_NODE_NAME` (por defecto: el nombre de host)
- `OPENSEARCH_NETWORK_HOST` (por defecto: `0.0.0.0`)
- `OPENSEARCH_DISCOVERY_TYPE` (por defecto: `single-node`)
- `OPENSEARCH_HEAP_SIZE` (por defecto: `8g`)
- `AXONOPS_SEARCH_TLS_ENABLED` (por defecto: `true`)

**3. Aplica las variables de entorno a la configuración de OpenSearch**
- Actualiza `opensearch.yml` con el nombre del clúster, el nombre del nodo y los ajustes de red
- Ajusta el tamaño del heap de la JVM en `jvm.options`
- Configura el pool de hilos, los ajustes de SSL y el DN de administración de seguridad
- Gestiona la activación o desactivación del TLS en la capa HTTP

**4. Crea el usuario administrador propio (antes del arranque)**
- Si están definidas `AXONOPS_SEARCH_USER` y `AXONOPS_SEARCH_PASSWORD`
- Genera el hash bcrypt de la contraseña con las herramientas de seguridad de OpenSearch
- **SUSTITUYE** `internal_users.yml` sólo por el usuario propio (borra el admin por defecto)
- Ocurre antes de que OpenSearch arranque (operación atómica)
- Escribe el fichero semáforo de inmediato en `/var/lib/opensearch/.axonops/init-security.done`

**5. Arranca OpenSearch**
- Ejecuta `opensearch` (en primer plano)
- Sustituye al proceso del entrypoint (pasa a ser el proceso principal del contenedor)
- OpenSearch toma el control, con tini como PID 1

#### Orden de ejecución

```
entrypoint.sh (PID 1 via tini)
  │
  ├─► 1. Print startup banner
  │
  ├─► 2. Set default environment variables
  │      (OPENSEARCH_CLUSTER_NAME, OPENSEARCH_NODE_NAME, etc.)
  │
  ├─► 3. Apply environment variables to opensearch.yml
  │      (cluster.name, node.name, network.host, discovery.type, etc.)
  │
  ├─► 4. Apply heap size to jvm.options
  │
  ├─► 5. Apply advanced settings (thread pool, SSL, security admin DN)
  │
  ├─► 6. Create custom admin user (PRE-STARTUP, if requested)
  │      - Generate password hash
  │      - REPLACE internal_users.yml with ONLY custom user
  │      - Write semaphore file
  │
  └─► 7. exec opensearch
         - Replaces entrypoint process
         - OpenSearch becomes main process
         - Container runs OpenSearch from this point
```

#### Ficheros de configuración modificados

El entrypoint modifica estos ficheros de configuración de OpenSearch a partir de
las variables de entorno:

| Fichero | Qué modifica | Variables de entorno |
|------|----------------|----------------------|
| `/etc/opensearch/opensearch.yml` | Ajustes centrales de OpenSearch | `OPENSEARCH_CLUSTER_NAME`, `OPENSEARCH_NODE_NAME`, `OPENSEARCH_NETWORK_HOST`, `OPENSEARCH_DISCOVERY_TYPE`, `OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE`, `OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION`, `OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE`, `OPENSEARCH_SECURITY_ADMIN_DN`, `OPENSEARCH_SECURITY_NODES_DN`, `AXONOPS_SEARCH_TLS_ENABLED` |
| `/etc/opensearch/jvm.options` | Los ajustes de memoria del heap de la JVM | `OPENSEARCH_HEAP_SIZE` |
| `/etc/opensearch/opensearch-security/internal_users.yml` | La configuración del usuario administrador | `AXONOPS_SEARCH_USER`, `AXONOPS_SEARCH_PASSWORD` (SUSTITUYE el fichero entero) |

#### Decisiones de diseño clave

**¿Por qué `exec opensearch`?**
- Usar `exec` sustituye el proceso de la shell por OpenSearch
- OpenSearch pasa a ser el proceso principal bajo tini (el envoltorio PID 1)
- Garantiza un apagado limpio cuando se para el contenedor
- No queda ningún proceso de shell huérfano consumiendo recursos

**¿Por qué crear el usuario antes del arranque (y no en segundo plano)?**
- La creación del administrador modifica `internal_users.yml` antes de que OpenSearch lo lea
- Garantiza una operación limpia y atómica (sin condiciones de carrera)
- OpenSearch lee la configuración definitiva en el primer arranque
- Es más sencillo que usar la herramienta securityadmin tras el arranque (que exige TLS)
- **Modelo de sustitución**: sólo existe UN usuario administrador (el propio o el de por defecto, nunca los dos)

**¿Por qué tini como sistema de init?**
- **Reenvío de señales**: garantiza que SIGTERM/SIGINT lleguen a OpenSearch, para un apagado ordenado
- **Recogida de zombis**: limpia los procesos hijos terminados
- **Buena práctica en contenedores**: evita problemas cuando el motor de contenedores envía señales de parada
- **Sobrecarga mínima**: un binario estático diminuto (~10 KB) y sin dependencias
- **Estándar del sector**: el mismo sistema de init que usa Docker con el flag `--init`
- Sin tini, los scripts de shell (PID 1) no reenvían bien las señales, y eso provoca matanzas forzadas

**Más información:** [por qué hace falta un sistema de init](https://github.com/krallin/tini#why-tini) en los contenedores

### Banner de versión al arrancar

Todos los contenedores muestran al arrancar información de versión completa:

```
================================================================================
AxonOps AxonDB Search (OpenSearch 3.3.2)
Image: ghcr.io/axonops/axondb-search:3.3.2-1.0.0
Built: 2025-12-13T10:30:00Z
Release: https://github.com/axonops/axonops-containers/releases/tag/axondb-search-1.0.0
Built by: GitHub Actions
================================================================================

Component Versions:
  OpenSearch:         3.3.2
  Java:               OpenJDK Runtime Environment (Red_Hat-17.0.17.0.10-1)
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI - Universal Base Image, freely redistributable)
  Platform:           x86_64

Supply Chain Security:
  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest
  Base image digest:  sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2

Runtime Environment:
  Hostname:           axondb-search-node-1
  Kubernetes:         Yes
    API Server:       10.0.0.1:443
    Pod:              axondb-search-node-1

================================================================================
Starting OpenSearch...
================================================================================
```

**Ver el banner:**
```bash
docker logs axondb-search | head -30
```

### Sondas de salud

El contenedor incluye un script de comprobación de salud optimizado que admite
tres tipos de sonda, diseñado para tener una sobrecarga mínima sin renunciar a la
fiabilidad:

**1. Sonda de arranque** (`healthcheck.sh startup`)
- **Espera a que termine la inicialización** (crítico con la creación del administrador previa al arranque)
- Busca el fichero semáforo en el almacenamiento persistente: `/var/lib/opensearch/.axonops/init-security.done`
- **Valida el campo RESULT**: falla si el semáforo tiene `RESULT=failed`
- Verifica que el proceso de OpenSearch está en marcha (`pgrep -f OpenSearch`)
- Comprueba que el puerto HTTP (9200) está escuchando (comprobación TCP con `nc`)
- Comprueba el endpoint de salud del plugin de seguridad (ligero, sin autenticación)
- **Bloquea el estado «Started» del pod hasta que la inicialización termina correctamente**
- Úsela para: el `startupProbe` de Kubernetes (garantiza que el administrador se crea antes de encaminar tráfico)

**2. Sonda de vida** (`healthcheck.sh liveness`)
- **Ultraligera**: pensada para ejecutarse a menudo (cada 10 segundos)
- Comprueba que el proceso de OpenSearch está en marcha (`pgrep -f OpenSearch`)
- Comprueba que el puerto HTTP (9200) está escuchando (comprobación TCP con `nc`)
- Comprueba el endpoint de salud del plugin de seguridad (ligero, sin autenticación)
- **Sin llamadas a la API de salud del clúster**: sobrecarga mínima, ejecución muy rápida
- Úsela para: el `livenessProbe` de Kubernetes (detectar si el proceso de OpenSearch ha caído)

**3. Sonda de disponibilidad** (`healthcheck.sh readiness`)
- Comprueba que el puerto HTTP (9200) está escuchando (comprobación TCP con `nc`)
- Hace una llamada autenticada a la API `/_cluster/health`
- Verifica que el estado del clúster no es «red» (amarillo o verde son aceptables)
- **Más exhaustiva** que la de vida: garantiza que OpenSearch está plenamente operativo
- Detecta automáticamente las credenciales de administración en el fichero semáforo (el usuario propio, si se creó)
- Úsela para: el `readinessProbe` de Kubernetes (comprobaciones del balanceador de carga, encaminamiento de tráfico)

**Comprobación de salud de Docker:**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect axondb-search --format='{{json .State.Health}}' | jq
```

**Probar la comprobación de salud a mano:**
```bash
# Test startup probe
docker exec axondb-search /usr/local/bin/healthcheck.sh startup

# Test liveness probe
docker exec axondb-search /usr/local/bin/healthcheck.sh liveness

# Test readiness probe
docker exec axondb-search /usr/local/bin/healthcheck.sh readiness
```

**Nota:** la configuración de las sondas de salud la gestionan automáticamente los
charts de Helm de AxonOps. Los modos de arriba están disponibles para despliegues
propios, si hacen falta.

### Seguridad y gestión de certificados

El contenedor incluye una configuración de seguridad completa con certificados
TLS de la marca AxonOps generados **en tiempo de ejecución** (al arrancar el
contenedor), lo que aporta mejor seguridad y más flexibilidad en escenarios con
almacenamiento persistente.

#### Generación de certificados en tiempo de ejecución

**Cómo funciona:**

El contenedor genera los certificados automáticamente al arrancar:

1. **Comprobación al arrancar**: al arrancar el contenedor, el script de entrypoint comprueba si existen los ficheros de certificado
2. **Generación automática**: si faltan certificados, se generan automáticamente con la marca AxonOps
3. **Seguimiento con semáforo**: un fichero semáforo registra el estado de la generación
4. **Se salta al reiniciar**: si los certificados ya existen (volumen persistente), la generación se omite

**Ventajas de la generación en tiempo de ejecución:**

- **Compatible con almacenamiento persistente**: los certificados persisten entre recreaciones del contenedor si se usan volúmenes
- **Certificados recién generados**: los despliegues nuevos reciben certificados nuevos
- **Certificados propios**: es fácil aportar los suyos desactivando la generación automática
- **Funcionamiento transparente**: totalmente automático, con valores por defecto sensatos

**Controlar la generación de certificados:**

Use la variable de entorno `GENERATE_CERTS_ON_STARTUP` para controlar este
comportamiento:

```bash
# Default: Auto-generate certificates if missing
docker run -d --name axondb-search \
  -e GENERATE_CERTS_ON_STARTUP=true \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Disable: Require user-provided certificates
docker run -d --name axondb-search \
  -e GENERATE_CERTS_ON_STARTUP=false \
  -v /path/to/your/certs:/etc/opensearch/certs \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Escenarios de generación:**

| Escenario | `GENERATE_CERTS_ON_STARTUP` | ¿Existen los certificados? | Resultado |
|----------|----------------------------|---------------------|--------|
| **Primer arranque (volumen vacío)** | `true` (por defecto) | No | ✓ Se generan los certificados |
| **Primer arranque (sin volumen)** | `true` (por defecto) | No | ✓ Se generan los certificados (efímeros) |
| **Reinicio con volumen persistente** | `true` (por defecto) | Sí | ✓ Se omite (se usan los existentes) |
| **Certificados propios** | `false` | Sí | ✓ Se usan los suyos |
| **Certificados propios** | `false` | No | ✗ El contenedor falla (sin certificados) |

**Fichero semáforo:**

El estado de la generación de certificados se registra en
`/var/lib/opensearch/.axonops/generate-certs.done`:

```bash
# Check certificate generation status
docker exec axondb-search cat /var/lib/opensearch/.axonops/generate-certs.done

# Example output:
COMPLETED=2025-12-16T05:47:02Z
RESULT=success
REASON=certs_generated
```

**Valores posibles de `RESULT`:**
- `success`: los certificados se generaron correctamente
- `skipped`: los certificados ya existían, la generación se omitió
- `disabled`: la generación de certificados está desactivada con `GENERATE_CERTS_ON_STARTUP=false`

#### Certificados con la marca AxonOps (NO certificados de demostración)

**DIFERENCIA CRÍTICA respecto a la configuración de demostración:**

- **Los certificados de demostración se BORRAN** durante el build de Docker (nunca están en la imagen final)
- **Los certificados con la marca AxonOps** se generan con ajustes de nivel de producción
- **Detalles del certificado:**
  - **Algoritmo:** RSA de 3072 bits (seguridad fuerte)
  - **Validez:** 5 años (1825 días)
  - **Organización:** AxonOps
  - **Unidad organizativa:** Database
  - **Common Names:**
    - CA raíz: `AxonOps Root CA`
    - Certificado de nodo: `axondbsearch.axonops.com`
    - Certificado de administración: `admin.axondbsearch.axonops.com`
  - **Subject Alternative Names (SAN):** `axondbsearch.axonops.com`, `*.axondbsearch.axonops.com`, `localhost`, `127.0.0.1`, `::1`

**Configuración de seguridad (opensearch.yml):**

```yaml
# Transport layer SSL/TLS (node-to-node communication)
plugins.security.ssl.transport.pemcert_filepath: certs/axondbsearch-default-node.pem
plugins.security.ssl.transport.pemkey_filepath: certs/axondbsearch-default-node-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: certs/axondbsearch-default-root-ca.pem
plugins.security.ssl.transport.enforce_hostname_verification: false

# HTTP layer SSL/TLS (REST API)
plugins.security.ssl.http.enabled: true
plugins.security.ssl.http.pemcert_filepath: certs/axondbsearch-default-node.pem
plugins.security.ssl.http.pemkey_filepath: certs/axondbsearch-default-node-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: certs/axondbsearch-default-root-ca.pem
plugins.security.ssl.http.clientauth_mode: NONE

# Admin certificate DN (for securityadmin tool)
plugins.security.authcz.admin_dn:
  - "OU=Database,O=AxonOps,CN=admin.axondbsearch.axonops.com"

# Demo certificates NOT allowed (we use AxonOps-branded certificates)
plugins.security.allow_unsafe_democertificates: false
```

#### Ficheros de certificado generados

Estos ficheros de certificado se crean en `/etc/opensearch/certs/` (con el
prefijo `axondbsearch-default-`, para identificar claramente los certificados
autogenerados):

| Fichero | Tipo | Descripción |
|------|------|-------------|
| `axondbsearch-default-root-ca.pem` | Certificado de CA raíz | La CA raíz de AxonOps (certificado público) |
| `axondbsearch-default-root-ca-key.pem` | Clave privada de la CA raíz | La clave privada de la CA raíz (permisos 600) |
| `axondbsearch-default-node.pem` | Certificado de nodo | El certificado de nodo para el SSL de transporte y de HTTP |
| `axondbsearch-default-node-key.pem` | Clave privada del nodo | La clave privada del nodo, en formato PKCS#8 (permisos 600) |
| `axondbsearch-default-admin.pem` | Certificado de administración | El certificado de cliente de administración para la herramienta securityadmin |
| `axondbsearch-default-admin-key.pem` | Clave privada de administración | La clave privada de administración, en formato PKCS#8 (permisos 600) |

**Convención de nombres de fichero:**

Los ficheros de certificado usan el prefijo `axondbsearch-default-` para:
- Identificar claramente los certificados autogenerados por AxonOps
- Distinguirlos de los certificados aportados por el usuario
- Dejar claro qué certificados se pueden sustituir sin riesgo

**Verificación de los certificados:**

```bash
# View node certificate details
docker exec axondb-search openssl x509 -in /etc/opensearch/certs/axondbsearch-default-node.pem -noout -text

# Verify certificate chain
docker exec axondb-search openssl verify \
  -CAfile /etc/opensearch/certs/axondbsearch-default-root-ca.pem \
  /etc/opensearch/certs/axondbsearch-default-node.pem

# Check certificate generation semaphore
docker exec axondb-search cat /var/lib/opensearch/.axonops/generate-certs.done
```

#### Usar certificados propios

Para aportar sus propios certificados en lugar de usar los autogenerados por
AxonOps:

**Opción 1: desactivar la autogeneración y montar sus certificados**
```bash
docker run -d --name axondb-search \
  -e GENERATE_CERTS_ON_STARTUP=false \
  -v /path/to/your/certs:/etc/opensearch/certs:ro \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Opción 2: sustituir los certificados del volumen persistente**
```bash
# Create volume
docker volume create opensearch-certs

# Start container with auto-generation first time
docker run -d --name axondb-search \
  -v opensearch-certs:/etc/opensearch/certs \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Stop container and replace certificates
docker stop axondb-search
docker run --rm -v opensearch-certs:/certs busybox sh -c "rm /certs/axondbsearch-default-*.pem"
docker cp /path/to/your/certs/. axondb-search:/etc/opensearch/certs/

# Restart with your certificates
docker start axondb-search
```

**Ficheros de certificado necesarios (si aporta los suyos):**
- `root-ca.pem` (o el nombre de su certificado de CA)
- `node.pem` (o el nombre de su certificado de nodo)
- `node-key.pem` (o el nombre de su clave de nodo, en formato PKCS#8)
- `admin.pem` (o el nombre de su certificado de administración)
- `admin-key.pem` (o el nombre de su clave de administración, en formato PKCS#8)

Actualice `opensearch.yml` para que apunte a los nombres de sus ficheros de
certificado si difieren de los de AxonOps por defecto.

#### Modelo de sustitución del usuario administrador

A diferencia de AxonDB Time-Series (que añade un usuario propio), AxonDB Search
usa un modelo de **SUSTITUCIÓN**, por seguridad:

**Configuración por defecto (sin usuario propio):**
- Usuario administrador por defecto: `admin`
- Contraseña por defecto: `MyS3cur3P@ss2025`
- Ubicación: `/etc/opensearch/opensearch-security/internal_users.yml`

**Configuración con usuario propio (recomendada en producción):**
```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=MySecurePassword123 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Qué ocurre:**
1. El script de entrypoint genera el hash bcrypt de la contraseña del usuario propio
2. **SUSTITUYE** el fichero `internal_users.yml` entero, sólo con el usuario propio
3. El usuario `admin` por defecto se **ELIMINA** (no existe en la configuración final)
4. Sólo existe UN usuario administrador en el sistema (el propio)
5. Se escribe el fichero semáforo en `/var/lib/opensearch/.axonops/init-security.done`

**Justificación de seguridad:**
- **Principio de mínimo privilegio**: una sola cuenta de administración reduce la superficie de ataque
- **Sin credenciales por defecto**: elimina el riesgo de olvidar el administrador por defecto
- **Operación atómica**: la creación del usuario es atómica (ocurre antes de que OpenSearch arranque)
- **Modelo de seguridad limpio**: sin cuentas heredadas ni usuarios desactivados

#### Opciones de configuración de TLS

**Activar o desactivar el SSL de HTTP:**

Por defecto, HTTPS está activado en la API REST. Puede desactivarlo si el TLS
termina en el balanceador de carga:

```bash
# Disable HTTP SSL (TLS terminated at load balancer)
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_TLS_ENABLED=false \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Importante:**
- El SSL de la capa de transporte (entre nodos) sigue activo aunque se desactive el de HTTP
- Es lo recomendado cuando se usa un balanceador de carga o un controlador de ingress que termina el TLS
- La comunicación interna del clúster va siempre cifrada

**DN del certificado propio (avanzado):**

En escenarios con certificados propios, puede cambiar el DN del certificado de
administración:

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_SECURITY_ADMIN_DN="CN=mycustomadmin,O=MyOrg,OU=MyUnit" \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

### Inicialización automatizada (configuración de seguridad y usuario administrador)

El contenedor hace una inicialización de seguridad automatizada, que cubre tanto
la verificación de los certificados como la creación opcional de un usuario
administrador propio. La inicialización se coordina con ficheros semáforo, para
que el orden con las sondas de salud sea el correcto.

#### Cómo funciona (flujo de ejecución)

La inicialización usa **configuración previa al arranque** (no un proceso en
segundo plano) para crear el administrador, con un script de verificación en
segundo plano:

```
1. entrypoint.sh starts (PID 1 via tini)
   │
   ├─► 2. Apply configuration (opensearch.yml, jvm.options)
   │
   ├─► 3. Create custom admin user (PRE-STARTUP, if requested)
   │      - Generate password hash
   │      - REPLACE internal_users.yml with ONLY custom user
   │      - Write initial semaphore file
   │      (This happens BEFORE OpenSearch starts)
   │
   └─► 4. Start OpenSearch (exec opensearch)
        │
        ├─► OpenSearch starts and begins accepting connections
        │   - Security plugin uses pre-configured settings from entrypoint
        │   - AxonOps certificates loaded from /etc/opensearch/certs/
        │   - Custom admin user (if created) is immediately active
        │
        └─► healthcheck.sh (startup probe) checks semaphore
            - Blocks until semaphore file exists
            - Verifies RESULT is not "failed"
            - Only then marks container as "Started"
```

**Por qué este patrón es seguro:**

1. **El administrador se crea antes de que OpenSearch arranque**: sin condiciones de carrera, operación atómica
2. **Sólo existe UN usuario administrador**: modelo de sustitución (el propio o el de por defecto, nunca los dos)
3. **Coordinación por semáforos**: la comprobación de salud espera a que la inicialización termine
4. **Semáforos persistentes**: se guardan en `/var/lib/opensearch` (volumen), lo que evita reinicializar en los reinicios
5. **Aplicación por Kubernetes**: el pod no se marca «Started» hasta que el semáforo confirma el éxito

#### Creación del usuario administrador (antes del arranque)

El entrypoint crea un usuario administrador propio y elimina el administrador por
defecto **antes** de que OpenSearch arranque.

**Qué hace:**
1. Genera el hash bcrypt de la contraseña del usuario propio (con la herramienta hash.sh de OpenSearch)
2. **SUSTITUYE** `internal_users.yml` sólo por la definición del usuario propio
3. El usuario `admin` por defecto se elimina (no existe en la configuración final)
4. Escribe el semáforo inicial en el almacenamiento persistente: `/var/lib/opensearch/.axonops/init-security.done`

**Ejemplo:**
```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=MySecurePassword123 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0

# Wait for startup (~1-2 minutes)
docker logs -f axondb-search

# Connect with custom credentials
curl -k -u dbadmin:MySecurePassword123 https://localhost:9200/_cluster/health
```

**Comprobaciones de seguridad:**
- Sólo se ejecuta si están definidas tanto `AXONOPS_SEARCH_USER` como `AXONOPS_SEARCH_PASSWORD`
- La generación del hash de la contraseña se valida (debe ser un bcrypt válido)
- La sustitución del fichero es atómica (se escribe entero antes de que OpenSearch arranque)
- **El semáforo se escribe SIEMPRE** (con éxito o con error)

#### Fin del arranque

Cuando el entrypoint termina toda la configuración previa al arranque:

**Qué ocurre:**
1. El proceso de OpenSearch arranca con toda la configuración aplicada
2. El plugin de seguridad carga con el administrador preconfigurado
3. Se usan los certificados de AxonOps para el TLS
4. La sonda de arranque de la comprobación de salud verifica que el semáforo indica RESULT=success
5. El contenedor se marca «Started» en Kubernetes sólo cuando la comprobación de salud pasa

#### Control y desactivación

**Desactivar por completo el plugin de seguridad (NO recomendado en producción):**
```bash
docker run -d --name axondb-search \
  -e DISABLE_SECURITY_PLUGIN=true \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

Cuando está desactivado, los ficheros semáforo se escriben de inmediato con
`RESULT=skipped`, para que la comprobación de salud pueda seguir adelante.

#### Ficheros semáforo

El proceso de inicialización usa ficheros semáforo para coordinarse entre el
script de entrypoint, la verificación en segundo plano y las sondas de salud.

**Ubicación:** `/var/lib/opensearch/.axonops/`

Los ficheros semáforo se guardan en el directorio de datos de OpenSearch (no en
`/etc`) porque:
- `/var/lib/opensearch` suele configurarse como volumen persistente en Kubernetes
- Al ser persistentes, los semáforos sobreviven a los reinicios de contenedor o de pod
- Evita reinicializar en los reinicios de pod (por ejemplo, durante una actualización progresiva)
- Permite que la comprobación de salud pase de inmediato tras un reinicio, sin volver a ejecutar la inicialización

**Importante:** configure `/var/lib/opensearch` como volumen persistente
(PersistentVolumeClaim) en su despliegue de Kubernetes. Los charts de Helm de
AxonOps lo hacen automáticamente.

**Fichero creado:**
- `init-security.done`: el estado de la configuración de seguridad y del usuario administrador

**Formato del fichero:**
```
COMPLETED=2025-12-16T09:32:17Z
RESULT=success
REASON=custom_user_created_prestartup
ADMIN_USER=dbadmin
```

**Valores de RESULT en init-security.done:**
- `success`: la inicialización de seguridad terminó correctamente
  - `custom_user_created_prestartup`: se creó el administrador propio (el admin por defecto se eliminó)
  - `default_config`: se usa el administrador y la contraseña por defecto

**Nota:** si la inicialización falla (por ejemplo, si falla la generación del hash
de la contraseña), el script de entrypoint termina con código 1 antes de escribir
el semáforo, lo que impide que el contenedor arranque.

**Garantía:** el fichero semáforo lo escribe **SIEMPRE** el script de entrypoint.
La sonda de arranque de la comprobación de salud:
1. Exige que exista el fichero semáforo
2. Comprueba el campo RESULT
3. Pasa si RESULT=success

Si el entrypoint encuentra errores durante la inicialización previa al arranque,
termina con código 1 antes de llegar a arrancar OpenSearch, así que el contenedor
nunca llega a arrancar del todo.

#### Registros de la inicialización

Consulte el progreso y los resultados de la inicialización:

```bash
# View OpenSearch startup logs
docker logs axondb-search

# Check security initialization status (in persistent volume)
docker exec axondb-search cat /var/lib/opensearch/.axonops/init-security.done

# View internal_users.yml to verify custom user
docker exec axondb-search cat /etc/opensearch/opensearch-security/internal_users.yml

# Verify AxonOps certificates
docker exec axondb-search ls -la /etc/opensearch/certs/
```

## Ficheros de configuración

El contenedor incluye 13 ficheros de configuración que controlan el
comportamiento de OpenSearch:

### Ficheros de configuración principales

| Fichero | Propósito | Personalizaciones clave |
|------|---------|-------------------|
| `opensearch.yml` | Ajustes centrales de OpenSearch | Valores por defecto listos para producción para cargas de búsqueda, configuración del plugin de seguridad, rutas de los certificados de AxonOps |
| `jvm.options` | Opciones de la JVM | Ajustes de heap (8G por defecto), configuración del GC optimizada para búsqueda |
| `log4j2.properties` | Configuración de registro | Retención reducida, optimizada para entornos de contenedores |

### Ficheros de configuración del plugin de seguridad (9 ficheros)

En `/etc/opensearch/opensearch-security/`:

| Fichero | Propósito | Descripción |
|------|---------|-------------|
| `config.yml` | Configuración principal del plugin de seguridad | Backends de autenticación y autorización (basic auth, LDAP, JWT, etc.) |
| `internal_users.yml` | Base de datos de usuarios internos | La definición del usuario administrador (el entrypoint la SUSTITUYE si se indica un usuario propio) |
| `roles.yml` | Definiciones de roles | Roles predefinidos (admin, readall, etc.) |
| `roles_mapping.yml` | Correspondencias de usuario a rol | Asocia usuarios y roles de backend a roles de OpenSearch |
| `action_groups.yml` | Definiciones de grupos de acciones | Grupos de permisos, para simplificar la creación de roles |
| `tenants.yml` | Configuración de multiinquilino | Definiciones de inquilinos, para aislar los paneles |
| `nodes_dn.yml` | Distinguished names de los nodos | Los DN de certificado admitidos en la comunicación entre nodos (heredado; use la variable `OPENSEARCH_SECURITY_NODES_DN` en su lugar) |
| `allowlist.yml` | Lista blanca de la API | Los endpoints de la API REST permitidos cuando la seguridad está restringida |
| `audit.yml` | Configuración del registro de auditoría | Ajustes del registro de auditoría (desactivado por defecto, se puede activar) |

**Puntos destacados de la configuración:**

**opensearch.yml:**
- **Clúster:** `axonopsdb-search` (configurable con `OPENSEARCH_CLUSTER_NAME`)
- **Descubrimiento:** `single-node` por defecto (configurable con `OPENSEARCH_DISCOVERY_TYPE`)
- **Bloqueo de memoria:** `bootstrap.memory_lock: true` (requiere la capacidad IPC_LOCK)
- **Red:** escucha en `0.0.0.0` (todas las interfaces)
- **Pool de hilos:** `thread_pool.write.queue_size: 10000` (súbalo con muchas escrituras)
- **Seguridad:** certificados con la marca AxonOps, certificados de demostración desactivados (`allow_unsafe_democertificates: false`)
- **Nodes DN:** comodín por defecto `CN=*.axonops.svc.cluster.local` (configurable con `OPENSEARCH_SECURITY_NODES_DN`)

**jvm.options:**
- **Heap:** 8G por defecto (`-Xms8g -Xmx8g`), configurable con `OPENSEARCH_HEAP_SIZE`
- **GC:** optimizado para JVM modernas (JDK 17+)

**log4j2.properties:**
- **Niveles de registro:** INFO por defecto; se puede activar DEBUG si hace falta
- **Retención:** optimizada para entornos de contenedores, con un crecimiento de los registros controlado
- **Ubicación:** `/var/log/opensearch/`

**internal_users.yml:**
- **Por defecto:** contiene el usuario `admin` con la contraseña en hash bcrypt
- **Usuario propio:** se **SUSTITUYE por completo** si se define `AXONOPS_SEARCH_USER` (sólo existe el usuario propio)
- **Formato:** YAML con hashes bcrypt de las contraseñas

**config.yml:**
- **Autenticación:** HTTP Basic activada por defecto contra la base de datos de usuarios internos
- **Autorización:** correspondencia interna de roles
- **Autenticación adicional:** LDAP, JWT, Kerberos y certificados de cliente disponibles (desactivados por defecto)

## Pipeline de CI/CD

### Workflows

El repositorio incluye workflows completos de GitHub Actions:

**Build y pruebas** (`.github/workflows/axondb-search-build-and-test.yml`)
- **Disparadores:** push o PR a las ramas main, development, feature/* y fix/*
  - Cuando cambia `axonops/axondb-search/**` (excluyendo los ficheros `*.md`)
  - Cuando cambian los workflows (`.github/workflows/axondb-search-*.yml`)
  - Cuando cambian las actions (`.github/actions/axondb-search-*/**`)
- **Pruebas:** build de Docker, verificación de versión, comprobación de salud y escaneo de seguridad
- **Duración:** unos 10 minutos

**Publicación de producción** (`.github/workflows/axondb-search-publish-signed.yml`)
- **Disparador:** ejecución manual del workflow con una etiqueta de git
- **Proceso:** validar → probar → crear la release → construir → firmar → publicar → verificar
- **Registro:** `ghcr.io/axonops/axondb-search`
- **Plataformas:** linux/amd64, linux/arm64
- **Firma:** firma sin claves con Cosign (OIDC)

**Publicación de desarrollo** (`.github/workflows/axondb-search-development-publish-signed.yml`)
- **Disparador:** ejecución manual del workflow desde la rama development
- **Registro:** `ghcr.io/axonops/development/axondb-search`
- **Uso:** probar imágenes antes de una release de producción

### Pruebas automatizadas

El pipeline de CI incluye pruebas exhaustivas:

**Pruebas funcionales:**
- Verificación del build del contenedor (multiarquitectura)
- Verificación del banner de arranque (producción frente a desarrollo)
- Verificación de versiones (OpenSearch, Java)
- Pruebas del script de comprobación de salud (startup, liveness, readiness)
- Verificación de la inicialización de seguridad
- Operaciones de la API REST con curl
- Tratamiento de las variables de entorno (20 variables)
- Verificación de los certificados

**Pruebas de seguridad:**
- Escaneo de vulnerabilidades del contenedor con Trivy (severidad CRITICAL y HIGH)
- Los resultados se suben a la pestaña Security de GitHub
- Los CVE upstream conocidos se documentan en `.trivyignore`
- Verificación de los certificados (con la marca AxonOps, no de demostración)

**Acciones compuestas:**
En `.github/actions/axondb-search-*/`:
- `start-and-wait`: arranca el contenedor y espera a que esté listo
- `verify-startup-banner`: verifica el contenido del banner
- `verify-no-startup-errors`: busca errores de arranque
- `verify-versions`: verifica las versiones de los componentes
- `test-healthcheck`: prueba todos los modos de comprobación de salud
- `verify-init-scripts`: verifica que la inicialización de seguridad terminó
- `test-rest-api`: prueba el funcionamiento de la API REST
- `test-all-env-vars`: prueba la configuración por variables de entorno (20 variables)
- `verify-certificates`: verifica los certificados de AxonOps (no los de demostración)
- `sign-container`: firma con Cosign
- `verify-published-image`: verificación tras la publicación
- `collect-logs`: recoge los registros del contenedor
- `determine-latest`: determina las etiquetas latest

### Proceso de publicación

**Release de desarrollo:**
```bash
# Tag on development branch
git checkout development
git tag vdev-axondb-search-1.0.0
git push origin vdev-axondb-search-1.0.0

# Publish to development registry
gh workflow run axondb-search-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=vdev-axondb-search-1.0.0 \
  -f container_version=1.0.0
```

**Release de producción:**
```bash
# Tag on main branch
git checkout main
git tag axondb-search-1.0.0
git push origin axondb-search-1.0.0

# Publish to production registry
gh workflow run axondb-search-publish-signed.yml \
  --ref main \
  -f main_git_tag=axondb-search-1.0.0 \
  -f container_version=1.0.0
```

Véase [RELEASE.md](./RELEASE.md) para la documentación completa del proceso de
release.

## Resolución de problemas

### Comprobar la versión del contenedor

Consulte el banner de arranque para ver todas las versiones de los componentes:

```bash
docker logs axondb-search | head -30
```

El banner muestra:
- La versión del contenedor y la revisión de git
- Las versiones de OpenSearch, Java y del sistema operativo
- El digest de la imagen base (para verificar la cadena de suministro)
- Los detalles del entorno de ejecución

### Registros del script de inicialización

Consulte el progreso y los resultados de la inicialización:

```bash
# View OpenSearch startup logs
docker logs axondb-search

# Check security initialization status (in persistent volume)
docker exec axondb-search cat /var/lib/opensearch/.axonops/init-security.done

# View internal_users.yml to verify admin user configuration
docker exec axondb-search cat /etc/opensearch/opensearch-security/internal_users.yml

# List AxonOps certificates
docker exec axondb-search ls -la /etc/opensearch/certs/
```

**Formato del fichero semáforo:**
```
COMPLETED=2025-12-16T10:45:00Z
RESULT=success
REASON=custom_user_created_prestartup
ADMIN_USER=dbadmin
```

Valores posibles de `RESULT`:
- `success`: la operación terminó correctamente
- `skipped`: la operación se omitió (con un campo REASON explicando por qué)
- `failed`: la operación falló (con un campo REASON explicando por qué)

### Depurar la comprobación de salud

Pruebe las sondas de salud a mano:

```bash
# Test all three probe types
docker exec axondb-search /usr/local/bin/healthcheck.sh startup
docker exec axondb-search /usr/local/bin/healthcheck.sh liveness
docker exec axondb-search /usr/local/bin/healthcheck.sh readiness

# Check Docker healthcheck status
docker inspect axondb-search --format='{{json .State.Health}}' | jq

# Test REST API manually
docker exec axondb-search curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health
```

### El contenedor no arranca

**Revise los registros:**
```bash
docker logs axondb-search
```

**Problemas habituales:**

1. **Memoria insuficiente:**
   - El heap por defecto es de 8G; asegúrese de que el contenedor tiene al menos 12 GB de RAM (1,5 veces el heap)
   - Ajústelo con: `-e OPENSEARCH_HEAP_SIZE=4g`

2. **Conflictos de puertos:**
   - HTTP: 9200
   - Transporte: 9300
   - Compruébelo con: `netstat -tuln | grep 9200`

3. **Problemas de permisos:**
   - El contenedor se ejecuta como el usuario `opensearch` (UID 999)
   - Asegure los permisos del volumen: `chown -R 999:999 /data/opensearch`

4. **`vm.max_map_count` demasiado bajo:**
   - Compruébelo: `sysctl vm.max_map_count`
   - Fíjelo: `sudo sysctl -w vm.max_map_count=262144`
   - De forma permanente: añádalo a `/etc/sysctl.conf`

5. **Problemas de inicialización:**
   - Revise el semáforo: `docker exec axondb-search cat /var/lib/opensearch/.axonops/init-security.done`
   - Busque RESULT=failed o un REASON concreto

**Consultar los registros de OpenSearch:**
```bash
docker exec axondb-search cat /var/log/opensearch/axonopsdb-search.log
```

**Verificar que OpenSearch está en marcha:**
```bash
docker exec axondb-search ps aux | grep opensearch
```

**Probar la conectividad de la API REST:**
```bash
# With default credentials
curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health

# With custom credentials
curl -k -u dbadmin:MySecurePassword123 https://localhost:9200/_cluster/health

# Without TLS (if AXONOPS_SEARCH_TLS_ENABLED=false)
curl -u admin:MyS3cur3P@ss2025 http://localhost:9200/_cluster/health
```

## Consideraciones para producción

1. **Almacenamiento persistente**
   - Use siempre volúmenes para `/var/lib/opensearch` (datos y semáforos)
   - Use volúmenes para `/var/log/opensearch` (registros)
   - Ejemplo: `-v /data/opensearch:/var/lib/opensearch`
   - Use almacenamiento SSD para cargas de producción (hacen falta muchas IOPS)

2. **Asignación de recursos**
   - Memoria: al menos 1,5 veces el tamaño del heap (por ejemplo, 12 GB para un heap de 8 GB)
   - CPU: se recomiendan 4 o más núcleos
   - Disco: almacenamiento SSD rápido con IOPS adecuadas
   - Heap: máximo 32 GB (por la optimización de punteros comprimidos de la JVM)

3. **Configuración del sistema**
   - **vm.max_map_count:** debe ser >= 262144 en todos los nodos
   - **ulimits.nofile:** póngalo a 65536 (descriptores de fichero abiertos máximos)
   - **Capacidad IPC_LOCK:** hace falta para `bootstrap.memory_lock: true`
   - Desactive el swap, para el mejor rendimiento

4. **Red**
   - Exponga los puertos necesarios: 9200 (HTTP), 9300 (transporte)
   - Use reglas de cortafuegos adecuadas
   - Valore terminar el TLS en el balanceador de carga (ponga `AXONOPS_SEARCH_TLS_ENABLED=false`)
   - El SSL de la capa de transporte sigue activo para la comunicación entre nodos

5. **Seguridad**
   - Use un usuario administrador propio (defina `AXONOPS_SEARCH_USER` y `AXONOPS_SEARCH_PASSWORD`)
   - **NUNCA** use las credenciales por defecto en producción
   - Verifique las firmas de los contenedores con Cosign
   - Use referencias de imagen basadas en digest, por inmutabilidad
   - Mantenga las imágenes base actualizadas (automatizado en UBI)
   - Los certificados con la marca AxonOps son de nivel de producción (RSA 3072, 5 años de validez)

6. **Monitorización**
   - Use las sondas de salud para monitorizar la disponibilidad
   - Vigile el uso del heap con las métricas de la JVM
   - Configure la agregación de registros de `/var/log/opensearch/`
   - Valore integrarlo con AxonOps para una monitorización completa
   - Vigile la salud del clúster con la API `/_cluster/health`

7. **Estrategia de copias de seguridad**
   - Haga snapshots periódicos de `/var/lib/opensearch/data`
   - Use la API de repositorio de snapshots de OpenSearch
   - Pruebe los procedimientos de restauración
   - Documente los objetivos de tiempo de recuperación (RTO)

8. **Despliegue en clúster**
   - Use un `OPENSEARCH_CLUSTER_NAME` consistente en todos los nodos
   - Configure los seed hosts para el descubrimiento entre varios nodos
   - Planifique los nodos elegibles como cluster-manager (mínimo 3, para el quórum)
   - Use nodos cluster-manager dedicados en clústeres grandes
   - Configure correctamente la conciencia de asignación de shards

Para el flujo de trabajo de desarrollo y las pruebas, véase
[DEVELOPMENT.md](./DEVELOPMENT.md).

Para el proceso de release, véase [RELEASE.md](./RELEASE.md).
