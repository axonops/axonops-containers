# Base de datos de busca AxonDB

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

[![Paquete GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axondb-search)

Contedor de OpenSearch 3.3.2 listo para produción, optimizado para cargas de
busca en despregamentos autoaloxados de AxonOps.

## Índice

- [Visión xeral](#visión-xeral)
- [Imaxes de Docker precompiladas](#imaxes-de-docker-precompiladas)
  - [Imaxes dispoñibles](#imaxes-dispoñibles)
  - [Estratexia de etiquetado](#estratexia-de-etiquetado)
- [Boa práctica en produción](#boa-práctica-en-produción)
- [Despregamento](#despregamento)
  - [Requisitos do despregamento en Kubernetes](#requisitos-do-despregamento-en-kubernetes)
- [Construír as imaxes de Docker](#construír-as-imaxes-de-docker)
- [Variables de entorno](#variables-de-entorno)
- [Prestacións do contedor](#prestacións-do-contedor)
  - [Script de entrypoint](#script-de-entrypoint)
  - [Banner de versión ao arrancar](#banner-de-versión-ao-arrancar)
  - [Sondas de saúde](#sondas-de-saúde)
  - [Seguridade e xestión de certificados](#seguridade-e-xestión-de-certificados)
  - [Inicialización automatizada (configuración de seguridade e usuario administrador)](#inicialización-automatizada-configuración-de-seguridade-e-usuario-administrador)
- [Ficheiros de configuración](#ficheiros-de-configuración)
- [Pipeline de CI/CD](#pipeline-de-cicd)
  - [Workflows](#workflows)
  - [Probas automatizadas](#probas-automatizadas)
  - [Proceso de publicación](#proceso-de-publicación)
- [Resolución de problemas](#resolución-de-problemas)
  - [Comprobar a versión do contedor](#comprobar-a-versión-do-contedor)
  - [Rexistros do script de inicialización](#rexistros-do-script-de-inicialización)
  - [Depurar a comprobación de saúde](#depurar-a-comprobación-de-saúde)
  - [O contedor non arranca](#o-contedor-non-arranca)
- [Consideracións para produción](#consideracións-para-produción)

## Visión xeral

AxonDB Search é un contedor de OpenSearch listo para produción, deseñado
expresamente para os despregamentos autoaloxados de AxonOps. Está optimizado para
cargas de base de datos de busca e desprégase como parte da pila completa de
AxonOps cos charts de Helm de AxonOps.

**Prestacións do contedor:**
- **Motor de busca moderno**: OpenSearch 3.3.2, con busca de texto completo, analítica e capacidades de visualización
- **Seguridade de produción**: certificados TLS coa marca AxonOps (RSA 3072, non certificados de demostración)
- **Configuración automatizada**: plugin de seguridade preconfigurado, con creación opcional dun usuario administrador propio
- **Base empresarial**: construído sobre Red Hat UBI 9 minimal, para estabilidade en produción
- **Seguridade da cadea de subministración**: imaxes base fixadas por digest, para builds inmutables
- **Monitorización de produción**: sondas de saúde integradas (startup, liveness, readiness)

**Importante:** este contedor está pensado exclusivamente para despregamentos
autoaloxados de AxonOps. Desprégase e configúrase a través dos charts de Helm de
AxonOps, que se ocupan de toda a orquestración, a rede e a integración coa
plataforma de monitorización e xestión de AxonOps. Para máis información sobre
AxonOps, véxase [axonops.com](https://axonops.com).

## Imaxes de Docker precompiladas

Hai imaxes precompiladas dispoñibles en GitHub Container Registry (GHCR). É a
forma máis sinxela de comezar.

### Imaxes dispoñibles

Todas as imaxes están en: `ghcr.io/axonops/axondb-search`

Consulte todas as etiquetas dispoñibles:
[GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axondb-search)

### Estratexia de etiquetado

As imaxes usan unha estratexia de etiquetado bidimensional:

| Patrón de etiqueta | Exemplo | Descrición | Caso de uso |
|-------------|---------|-------------|----------|
| `{OPENSEARCH}-{AXON}` | `3.3.2-1.0.0` | Totalmente inmutable (versión de OpenSearch + de AxonOps) | **Produción**: fixe versións exactas para unha auditabilidade completa |
| `@sha256:<digest>` | `@sha256:abc123...` | Baseada en digest (criptograficamente inmutable) | **Máxima seguridade**: integridade da imaxe garantida |
| `{OPENSEARCH}` | `3.3.2` | O último AxonOps para esa versión de OpenSearch | Seguir as actualizacións de AxonOps dunha versión concreta de OpenSearch |
| `latest` | `latest` | A última de todas as versións | Só para probas rápidas (NON para produción) |

**Dimensións do versionado:**
- **OPENSEARCH**: a versión de OpenSearch (por exemplo, 3.3.2)
- **AXON**: a versión do contedor de AxonOps (por exemplo, 1.0.0, en SemVer)

**Exemplos de etiquetado:**

Cando se constrúe `3.3.2-1.0.0` (e é a máis recente):
- `3.3.2-1.0.0` (inmutable: non cambia nunca)
- `3.3.2` (flotante: reetiquétase a builds de AxonOps máis novos)
- `latest` (flotante: móvese a versións de OpenSearch máis novas)

## 💡 Boa práctica en produción

⚠️ **Usar `latest` ou etiquetas flotantes en produción é un antipatrón.** Isto
inclúe `latest` e `3.3.2`, porque:
- **Non hai rastro de auditoría**: non se pode determinar que versión exacta estaba despregada nun momento dado
- **Actualizacións inesperadas**: os orquestradores de contedores poden descargar imaxes novas ao reiniciar
- **Dificultades para volver atrás**: non se pode retroceder de forma fiable a versións anteriores
- **Problemas de cumprimento**: moitos marcos normativos esixen un seguimento de versións inmutable

👍 **Estratexias de despregamento recomendadas (de maior a menor seguridade):**

1. **🥇 Referencia de ouro: baseada en digest** (máxima seguridade)
   ```bash
   docker pull ghcr.io/axonops/axondb-search@sha256:abc123...
   ```
   - 100 % inmutable, garantido criptograficamente
   - Obrigatoria en entornos regulados
   - Verifique a sinatura con Cosign (véxase [Seguridade](#seguridade))

2. **🥈 Etiqueta inmutable** (o estándar de produción)
   ```bash
   docker pull ghcr.io/axonops/axondb-search:3.3.2-1.0.0
   ```
   - Fixada a unha versión concreta (OpenSearch 3.3.2 + AxonOps 1.0.0)
   - Doada de ler e de xestionar
   - Mantén un rastro de auditoría completo

3. **🥉 Etiquetas flotantes** (só desenvolvemento e probas)
   ```bash
   docker pull ghcr.io/axonops/axondb-search:latest
   ```
   - Iteración rápida
   - NON para produción
   - Úseas só para probas de concepto e probas

**Nota de seguridade:** todas as imaxes de produción están asinadas
criptograficamente con Cosign de Sigstore, con sinatura sen chaves. Verifique as
sinaturas antes de despregar:

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

## Despregamento

Este contedor desprégase exclusivamente mediante os **charts de Helm de AxonOps**,
como parte da pila autoaloxada de AxonOps. Os charts de Helm ocúpanse de toda a
configuración, a orquestración e a integración cos compoñentes de monitorización
e xestión de AxonOps.

Para as instrucións de despregamento, consulte a documentación de despregamento
autoaloxado de AxonOps (dispoñible cando se publiquen os charts de Helm).

### Requisitos do despregamento en Kubernetes

**Requisitos previos CRÍTICOS para os despregamentos en Kubernetes:**

OpenSearch precisa configuracións concretas a nivel de sistema nos nodos de
Kubernetes e nos contextos de seguridade dos pods. Estes axustes son obrigatorios
nos despregamentos de produción.

#### 1. Configuración a nivel de nodo (vm.max_map_count)

OpenSearch usa un directorio mmapfs para gardar os índices. Os límites por defecto
do sistema operativo sobre o número de mmap adoitan ser demasiado baixos, e iso
pode provocar excepcións por falta de memoria.

**Requisito: `vm.max_map_count` >= 262144 en TODOS os nodos de Kubernetes**

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

#### 2. Contexto de seguridade do pod (ulimits e capacidades)

**Requisito: `ulimits.nofile` (descritores de ficheiro máximos) >= 65536**

OpenSearch precisa un número alto de descritores de ficheiro. Ademais,
`bootstrap.memory_lock: true` (configurado en `opensearch.yml`) require a
capacidade `IPC_LOCK`, para evitar que a memoria vaia a swap.

**Configuración de seguridade do pod completa:**

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

**Exemplo de StatefulSet (para clústeres de produción):**

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
- **vm.max_map_count**: hai que fixalo en TODOS os nodos de Kubernetes (non só no pod)
- **ulimits.nofile**: fíxase con `securityContext` ou cun contedor de inicialización
- **IPC_LOCK**: fai falta para `bootstrap.memory_lock: true` (evita o swap)
- **Volumes persistentes**: use almacenamento SSD con IOPS axeitadas en produción
- **Memoria**: asigne polo menos 1,5 veces o tamaño do heap (por exemplo, 12 Gi para un heap de 8 G)

## Construír as imaxes de Docker

Se prefire construír as imaxes vostede mesmo no canto de usar as precompiladas:

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

**Argumentos de build obrigatorios:**
- `OPENSEARCH_VERSION`: a versión de OpenSearch (por exemplo, 3.3.2)

**Argumentos de build opcionais (melloran os metadatos, pero non son
obrigatorios):**
- `BUILD_DATE`: a marca de tempo do build (formato ISO 8601, por exemplo, `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF`: o SHA do commit de git (por exemplo, `$(git rev-parse HEAD)`)
- `VERSION`: a versión do contedor (por exemplo, 1.0.0)
- `GIT_TAG`: o nome da etiqueta de git (para as ligazóns de release/tag do banner)
- `GITHUB_ACTOR`: o usuario que lanzou o build (para o rastro de auditoría)
- `IS_PRODUCTION_RELEASE`: póñao a `true` para produción (por defecto: `false`)
- `IMAGE_FULL_NAME`: o nome completo da imaxe coa etiqueta (amósase no banner de arranque)

**Seguridade da cadea de subministración:**

O noso Dockerfile usa imaxes base fixadas por digest, por seguridade da cadea de
subministración:

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
ARG UBI9_MINIMAL_DIGEST=sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2
FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
```

**Por que importa fixar por digest:**
- As etiquetas poden substituírse de forma maliciosa (mesma etiqueta, imaxe distinta)
- Os digests son criptograficamente inmutables: non poden cambiarse
- Evita comprometer en silencio a súa cadea de subministración de contedores
- É a boa práctica do sector para os builds de produción

## Variables de entorno

O contedor admite 18 variables de entorno de configuración:

| Variable | Descrición | Valor por defecto | Categoría |
|----------|-------------|---------|----------|
| `OPENSEARCH_CLUSTER_NAME` | O nome do clúster | `axonopsdb-search` | Configuración de OpenSearch |
| `OPENSEARCH_NODE_NAME` | O nome do nodo | `${HOSTNAME}` | Configuración de OpenSearch |
| `OPENSEARCH_NETWORK_HOST` | O enderezo de escoita de rede | `0.0.0.0` | Configuración de OpenSearch |
| `OPENSEARCH_DISCOVERY_TYPE` | O tipo de descubrimento do clúster (`single-node` ou multinodo) | `single-node` | Configuración de OpenSearch |
| `OPENSEARCH_HEAP_SIZE` | O tamaño do heap da JVM (tanto -Xms como -Xmx) | `8g` | Configuración de OpenSearch |
| `OPENSEARCH_HTTP_PORT` | O porto da API HTTP | `9200` | Configuración de OpenSearch |
| `OPENSEARCH_DATA_DIR` | A ruta do directorio de datos | `/var/lib/opensearch` | Configuración de OpenSearch |
| `OPENSEARCH_LOG_DIR` | A ruta do directorio de rexistros | `/var/log/opensearch` | Configuración de OpenSearch |
| `OPENSEARCH_PATH_CONF` | A ruta do directorio de configuración | `/etc/opensearch` | Configuración de OpenSearch |
| `AXONOPS_SEARCH_USER` | Crea un usuario administrador propio con este nome (substitúe o admin por defecto) | - | Seguridade e inicialización |
| `AXONOPS_SEARCH_PASSWORD` | O contrasinal do administrador propio (obrigatorio se se define `AXONOPS_SEARCH_USER`) | - | Seguridade e inicialización |
| `AXONOPS_SEARCH_TLS_ENABLED` | Activa HTTPS na API REST (póñao a `false` se o balanceador termina o TLS) | `true` | Seguridade e inicialización |
| `GENERATE_CERTS_ON_STARTUP` | Xera os certificados por defecto de AxonOps en tempo de execución se faltan | `true` | Seguridade e inicialización |
| `OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE` | O tamaño da cola do pool de fíos de escritura (súbao con moitas escrituras) | `10000` | Avanzado e transporte |
| `OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION` | Esixe a verificación do nome de host no SSL de transporte | `false` | Avanzado e transporte |
| `OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE` | O modo de autenticación de cliente HTTP (`NONE`, `OPTIONAL`, `REQUIRED`) | `NONE` | Avanzado e transporte |
| `OPENSEARCH_SECURITY_ADMIN_DN` | O DN do certificado de administración propio (para escenarios con certificados propios) | `OU=Database,O=AxonOps,CN=admin.axondbsearch.axonops.com` | Avanzado e transporte |
| `OPENSEARCH_SECURITY_NODES_DN` | Os DN dos certificados de nodo para a comunicación entre nodos (lista separada por puntos e coma, admite comodíns) | `CN=*.axonops.svc.cluster.local` | Avanzado e transporte |
| `DISABLE_SECURITY_PLUGIN` | Desactiva por completo o plugin de seguridade (NON recomendado en produción) | `false` | Control de plugins |
| `DISABLE_PERFORMANCE_ANALYZER_AGENT_CLI` | Desactiva o analizador de rendemento (AxonOps xa achega a monitorización) | `true` | Control de plugins |

### Configuración de OpenSearch

As 9 primeiras variables configuran o comportamento central de OpenSearch. O
script de entrypoint procésaas e aplícaas aos ficheiros de configuración antes de
que OpenSearch arranque.

**Configuración de rede:**
- `OPENSEARCH_NETWORK_HOST`: póñaa a `0.0.0.0` para escoitar en todas as interfaces
- `OPENSEARCH_HTTP_PORT`: o porto da API REST (por defecto: 9200)

**Configuración do clúster:**
- `OPENSEARCH_CLUSTER_NAME`: un nome descritivo para o clúster
- `OPENSEARCH_NODE_NAME`: por defecto, o nome de host do pod en Kubernetes
- `OPENSEARCH_DISCOVERY_TYPE`: póñaa a `single-node` para clústeres dun só nodo, ou configure os seed hosts para varios nodos

**Configuración de recursos:**
- `OPENSEARCH_HEAP_SIZE`: controla o heap da JVM (tanto -Xms como -Xmx toman o mesmo valor)
- Recomendación: o 50 % da memoria do contedor, cun máximo de 32 GB

**Exemplo:**
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

### Control da seguridade e a inicialización

**Configuración de TLS/SSL:**

Por defecto, o contedor activa HTTPS na API REST con certificados da marca
AxonOps. Se usa un balanceador de carga ou un ingress que termina o TLS, pode
desactivar o SSL de HTTP:

```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_TLS_ENABLED=false \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Importante:** o SSL da capa de transporte (a comunicación entre nodos) segue
activo aínda que se desactive o SSL de HTTP.

**Usuario administrador propio (modelo de SUBSTITUCIÓN):**

O contedor permite crear un usuario administrador propio que **SUBSTITÚE** o
usuario administrador por defecto. Isto é distinto de AxonDB Time-Series, que
engade un usuario propio: en OpenSearch, por seguridade, só debería existir un
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
- A creación do usuario propio ocorre **antes** de que OpenSearch arranque (previa ao arranque, non en segundo plano)
- O usuario `admin` por defecto ELIMÍNASE de `internal_users.yml`
- Só existirá o usuario propio (sen admin por defecto)
- A creación do usuario é atómica: ou remata por completo, ou se desfai

### Configuración avanzada

**Configuración do pool de fíos:**

Con cargas de moita escritura, pode que precise subir o tamaño da cola do pool de
fíos de escritura:

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE=20000 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Configuración do SSL de transporte:**

Para clústeres de varios nodos con requisitos de seguridade estritos:

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION=true \
  -e OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE=OPTIONAL \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**DN dos certificados de nodo (seguridade multinodo):**

Nos clústeres de varios nodos, configure que Distinguished Names (DN) de
certificado se admiten para a comunicación entre nodos. É crítico para asegurar a
comunicación da capa de transporte entre nodos de OpenSearch.

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
- Use puntos e coma (`;`) para separar varios DN
- Admite comodíns (por exemplo, `CN=*.svc.cluster.local`) para os nomes de pod dinámicos de Kubernetes
- Os espazos arredor dos DN recórtanse automaticamente
- Só os nodos con certificados que casen con eses DN poden unirse ao clúster
- É esencial para impedir que nodos non autorizados se unan ao seu clúster

**Exemplo de StatefulSet de Kubernetes:**
```yaml
env:
  - name: OPENSEARCH_SECURITY_NODES_DN
    value: "CN=*.axondb-search.default.svc.cluster.local;CN=axondb-search-0;CN=axondb-search-1;CN=axondb-search-2"
```

Esta configuración xera o seguinte en `opensearch.yml`:
```yaml
plugins.security.nodes_dn:
  - "CN=*.axondb-search.default.svc.cluster.local"
  - "CN=axondb-search-0"
  - "CN=axondb-search-1"
  - "CN=axondb-search-2"
```

## Prestacións do contedor

### Script de entrypoint

O script de entrypoint (`/usr/local/bin/docker-entrypoint.sh`) é o orquestrador
principal que configura OpenSearch e xestiona o arranque do contedor. Execútase
como PID 1 a través de [tini](https://github.com/krallin/tini) e fai a
inicialización crítica antes de arrancar OpenSearch.

#### tini: un sistema de init mínimo

O contedor usa **tini** como sistema de init (PID 1). Tini é un sistema de init
mínimo, pensado expresamente para contedores, que:

- **Manexa ben os sinais**: reenvía os sinais (SIGTERM, SIGINT) aos procesos fillos, para un apagado ordenado
- **Recolle os procesos zombis**: limpa os procesos fillos rematados que, se non, se irían acumulando
- **É extremadamente lixeiro**: un único binario estático (~10 KB), cunha sobrecarga mínima
- **É un estándar do sector**: Docker úsao como init por defecto cando se pasa `--init`

O Dockerfile fixa tini como envolveiro do entrypoint:
```dockerfile
ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["opensearch"]
```

Iso significa que a árbore de procesos real é:
```
tini (PID 1)
  └─► docker-entrypoint.sh
       └─► opensearch (after exec)
```

Tras `exec opensearch`, OpenSearch substitúe o script de shell, pero tini segue
sendo o PID 1, o que garante un manexo correcto dos sinais en todo o contedor.

**Máis información:** [github.com/krallin/tini](https://github.com/krallin/tini)

#### Que fai

**1. Amosa o banner de arranque**
- Toma os metadatos do build de `/etc/axonops/build-info.txt`
- Imprime información de versión completa (OpenSearch, Java, sistema operativo)
- Amosa o entorno de execución (detección de Kubernetes, nome de host)
- Amosa a información de seguridade da cadea de subministración (o digest da imaxe base)

**2. Define as variables de entorno por defecto**
- `OPENSEARCH_CLUSTER_NAME` (por defecto: `axonopsdb-search`)
- `OPENSEARCH_NODE_NAME` (por defecto: o nome de host)
- `OPENSEARCH_NETWORK_HOST` (por defecto: `0.0.0.0`)
- `OPENSEARCH_DISCOVERY_TYPE` (por defecto: `single-node`)
- `OPENSEARCH_HEAP_SIZE` (por defecto: `8g`)
- `AXONOPS_SEARCH_TLS_ENABLED` (por defecto: `true`)

**3. Aplica as variables de entorno á configuración de OpenSearch**
- Actualiza `opensearch.yml` co nome do clúster, o nome do nodo e os axustes de rede
- Axusta o tamaño do heap da JVM en `jvm.options`
- Configura o pool de fíos, os axustes de SSL e o DN de administración de seguridade
- Xestiona a activación ou desactivación do TLS na capa HTTP

**4. Crea o usuario administrador propio (antes do arranque)**
- Se están definidas `AXONOPS_SEARCH_USER` e `AXONOPS_SEARCH_PASSWORD`
- Xera o hash bcrypt do contrasinal coas ferramentas de seguridade de OpenSearch
- **SUBSTITÚE** `internal_users.yml` só polo usuario propio (borra o admin por defecto)
- Ocorre antes de que OpenSearch arranque (operación atómica)
- Escribe o ficheiro semáforo de inmediato en `/var/lib/opensearch/.axonops/init-security.done`

**5. Arranca OpenSearch**
- Executa `opensearch` (en primeiro plano)
- Substitúe o proceso do entrypoint (pasa a ser o proceso principal do contedor)
- OpenSearch toma o control, con tini como PID 1

#### Orde de execución

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

#### Ficheiros de configuración modificados

O entrypoint modifica estes ficheiros de configuración de OpenSearch a partir das
variables de entorno:

| Ficheiro | Que modifica | Variables de entorno |
|------|----------------|----------------------|
| `/etc/opensearch/opensearch.yml` | Axustes centrais de OpenSearch | `OPENSEARCH_CLUSTER_NAME`, `OPENSEARCH_NODE_NAME`, `OPENSEARCH_NETWORK_HOST`, `OPENSEARCH_DISCOVERY_TYPE`, `OPENSEARCH_THREAD_POOL_WRITE_QUEUE_SIZE`, `OPENSEARCH_SSL_TRANSPORT_ENFORCE_HOSTNAME_VERIFICATION`, `OPENSEARCH_SSL_HTTP_CLIENTAUTH_MODE`, `OPENSEARCH_SECURITY_ADMIN_DN`, `OPENSEARCH_SECURITY_NODES_DN`, `AXONOPS_SEARCH_TLS_ENABLED` |
| `/etc/opensearch/jvm.options` | Os axustes de memoria do heap da JVM | `OPENSEARCH_HEAP_SIZE` |
| `/etc/opensearch/opensearch-security/internal_users.yml` | A configuración do usuario administrador | `AXONOPS_SEARCH_USER`, `AXONOPS_SEARCH_PASSWORD` (SUBSTITÚE o ficheiro enteiro) |

#### Decisións de deseño clave

**Por que `exec opensearch`?**
- Usar `exec` substitúe o proceso da shell por OpenSearch
- OpenSearch pasa a ser o proceso principal baixo tini (o envolveiro PID 1)
- Garante un apagado limpo cando se para o contedor
- Non queda ningún proceso de shell orfo consumindo recursos

**Por que crear o usuario antes do arranque (e non en segundo plano)?**
- A creación do administrador modifica `internal_users.yml` antes de que OpenSearch o lea
- Garante unha operación limpa e atómica (sen condicións de carreira)
- OpenSearch le a configuración definitiva no primeiro arranque
- É máis sinxelo ca usar a ferramenta securityadmin tras o arranque (que esixe TLS)
- **Modelo de substitución**: só existe UN usuario administrador (o propio ou o de por defecto, nunca os dous)

**Por que tini como sistema de init?**
- **Reenvío de sinais**: garante que SIGTERM/SIGINT cheguen a OpenSearch, para un apagado ordenado
- **Recollida de zombis**: limpa os procesos fillos rematados
- **Boa práctica en contedores**: evita problemas cando o motor de contedores envía sinais de parada
- **Sobrecarga mínima**: un binario estático diminuto (~10 KB) e sen dependencias
- **Estándar do sector**: o mesmo sistema de init que usa Docker co flag `--init`
- Sen tini, os scripts de shell (PID 1) non reenvían ben os sinais, e iso provoca matanzas forzadas

**Máis información:** [por que fai falta un sistema de init](https://github.com/krallin/tini#why-tini) nos contedores

### Banner de versión ao arrancar

Todos os contedores amosan ao arrancar información de versión completa:

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

**Ver o banner:**
```bash
docker logs axondb-search | head -30
```

### Sondas de saúde

O contedor inclúe un script de comprobación de saúde optimizado que admite tres
tipos de sonda, deseñado para ter unha sobrecarga mínima sen renunciar á
fiabilidade:

**1. Sonda de arranque** (`healthcheck.sh startup`)
- **Agarda a que remate a inicialización** (crítico coa creación do administrador previa ao arranque)
- Busca o ficheiro semáforo no almacenamento persistente: `/var/lib/opensearch/.axonops/init-security.done`
- **Valida o campo RESULT**: falla se o semáforo ten `RESULT=failed`
- Verifica que o proceso de OpenSearch está en marcha (`pgrep -f OpenSearch`)
- Comproba que o porto HTTP (9200) está a escoitar (comprobación TCP con `nc`)
- Comproba o endpoint de saúde do plugin de seguridade (lixeiro, sen autenticación)
- **Bloquea o estado «Started» do pod ata que a inicialización remata correctamente**
- Úsea para: o `startupProbe` de Kubernetes (garante que o administrador se crea antes de encamiñar tráfico)

**2. Sonda de vida** (`healthcheck.sh liveness`)
- **Ultralixeira**: pensada para executarse a miúdo (cada 10 segundos)
- Comproba que o proceso de OpenSearch está en marcha (`pgrep -f OpenSearch`)
- Comproba que o porto HTTP (9200) está a escoitar (comprobación TCP con `nc`)
- Comproba o endpoint de saúde do plugin de seguridade (lixeiro, sen autenticación)
- **Sen chamadas á API de saúde do clúster**: sobrecarga mínima, execución moi rápida
- Úsea para: o `livenessProbe` de Kubernetes (detectar se o proceso de OpenSearch caeu)

**3. Sonda de dispoñibilidade** (`healthcheck.sh readiness`)
- Comproba que o porto HTTP (9200) está a escoitar (comprobación TCP con `nc`)
- Fai unha chamada autenticada á API `/_cluster/health`
- Verifica que o estado do clúster non é «red» (amarelo ou verde son aceptables)
- **Máis exhaustiva** ca a de vida: garante que OpenSearch está plenamente operativo
- Detecta automaticamente as credenciais de administración no ficheiro semáforo (o usuario propio, se se creou)
- Úsea para: o `readinessProbe` de Kubernetes (comprobacións do balanceador de carga, encamiñamento de tráfico)

**Comprobación de saúde de Docker:**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect axondb-search --format='{{json .State.Health}}' | jq
```

**Probar a comprobación de saúde a man:**
```bash
# Test startup probe
docker exec axondb-search /usr/local/bin/healthcheck.sh startup

# Test liveness probe
docker exec axondb-search /usr/local/bin/healthcheck.sh liveness

# Test readiness probe
docker exec axondb-search /usr/local/bin/healthcheck.sh readiness
```

**Nota:** a configuración das sondas de saúde xestiónana automaticamente os
charts de Helm de AxonOps. Os modos de arriba están dispoñibles para
despregamentos propios, se fan falta.

### Seguridade e xestión de certificados

O contedor inclúe unha configuración de seguridade completa con certificados TLS
da marca AxonOps xerados **en tempo de execución** (ao arrancar o contedor), o que
achega mellor seguridade e máis flexibilidade en escenarios con almacenamento
persistente.

#### Xeración de certificados en tempo de execución

**Como funciona:**

O contedor xera os certificados automaticamente ao arrancar:

1. **Comprobación ao arrancar**: ao arrancar o contedor, o script de entrypoint comproba se existen os ficheiros de certificado
2. **Xeración automática**: se faltan certificados, xéranse automaticamente coa marca AxonOps
3. **Seguimento con semáforo**: un ficheiro semáforo rexistra o estado da xeración
4. **Sáltase ao reiniciar**: se os certificados xa existen (volume persistente), a xeración omítese

**Vantaxes da xeración en tempo de execución:**

- **Compatible con almacenamento persistente**: os certificados persisten entre recreacións do contedor se se usan volumes
- **Certificados recén xerados**: os despregamentos novos reciben certificados novos
- **Certificados propios**: é doado achegar os seus desactivando a xeración automática
- **Funcionamento transparente**: totalmente automático, con valores por defecto sensatos

**Controlar a xeración de certificados:**

Use a variable de entorno `GENERATE_CERTS_ON_STARTUP` para controlar este
comportamento:

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

**Escenarios de xeración:**

| Escenario | `GENERATE_CERTS_ON_STARTUP` | Existen os certificados? | Resultado |
|----------|----------------------------|---------------------|--------|
| **Primeiro arranque (volume baleiro)** | `true` (por defecto) | Non | ✓ Xéranse os certificados |
| **Primeiro arranque (sen volume)** | `true` (por defecto) | Non | ✓ Xéranse os certificados (efémeros) |
| **Reinicio con volume persistente** | `true` (por defecto) | Si | ✓ Omítese (úsanse os existentes) |
| **Certificados propios** | `false` | Si | ✓ Úsanse os seus |
| **Certificados propios** | `false` | Non | ✗ O contedor falla (sen certificados) |

**Ficheiro semáforo:**

O estado da xeración de certificados rexístrase en
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
- `success`: os certificados xeráronse correctamente
- `skipped`: os certificados xa existían, a xeración omitiuse
- `disabled`: a xeración de certificados está desactivada con `GENERATE_CERTS_ON_STARTUP=false`

#### Certificados coa marca AxonOps (NON certificados de demostración)

**DIFERENZA CRÍTICA respecto da configuración de demostración:**

- **Os certificados de demostración BÓRRANSE** durante o build de Docker (nunca están na imaxe final)
- **Os certificados coa marca AxonOps** xéranse con axustes de nivel de produción
- **Detalles do certificado:**
  - **Algoritmo:** RSA de 3072 bits (seguridade forte)
  - **Validez:** 5 anos (1825 días)
  - **Organización:** AxonOps
  - **Unidade organizativa:** Database
  - **Common Names:**
    - CA raíz: `AxonOps Root CA`
    - Certificado de nodo: `axondbsearch.axonops.com`
    - Certificado de administración: `admin.axondbsearch.axonops.com`
  - **Subject Alternative Names (SAN):** `axondbsearch.axonops.com`, `*.axondbsearch.axonops.com`, `localhost`, `127.0.0.1`, `::1`

**Configuración de seguridade (opensearch.yml):**

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

#### Ficheiros de certificado xerados

Estes ficheiros de certificado créanse en `/etc/opensearch/certs/` (co prefixo
`axondbsearch-default-`, para identificar claramente os certificados
autoxerados):

| Ficheiro | Tipo | Descrición |
|------|------|-------------|
| `axondbsearch-default-root-ca.pem` | Certificado de CA raíz | A CA raíz de AxonOps (certificado público) |
| `axondbsearch-default-root-ca-key.pem` | Chave privada da CA raíz | A chave privada da CA raíz (permisos 600) |
| `axondbsearch-default-node.pem` | Certificado de nodo | O certificado de nodo para o SSL de transporte e de HTTP |
| `axondbsearch-default-node-key.pem` | Chave privada do nodo | A chave privada do nodo, en formato PKCS#8 (permisos 600) |
| `axondbsearch-default-admin.pem` | Certificado de administración | O certificado de cliente de administración para a ferramenta securityadmin |
| `axondbsearch-default-admin-key.pem` | Chave privada de administración | A chave privada de administración, en formato PKCS#8 (permisos 600) |

**Convención de nomes de ficheiro:**

Os ficheiros de certificado usan o prefixo `axondbsearch-default-` para:
- Identificar claramente os certificados autoxerados por AxonOps
- Distinguilos dos certificados achegados polo usuario
- Deixar claro que certificados se poden substituír sen risco

**Verificación dos certificados:**

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

Para achegar os seus propios certificados no canto de usar os autoxerados por
AxonOps:

**Opción 1: desactivar a autoxeración e montar os seus certificados**
```bash
docker run -d --name axondb-search \
  -e GENERATE_CERTS_ON_STARTUP=false \
  -v /path/to/your/certs:/etc/opensearch/certs:ro \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Opción 2: substituír os certificados do volume persistente**
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

**Ficheiros de certificado necesarios (se achega os seus):**
- `root-ca.pem` (ou o nome do seu certificado de CA)
- `node.pem` (ou o nome do seu certificado de nodo)
- `node-key.pem` (ou o nome da súa chave de nodo, en formato PKCS#8)
- `admin.pem` (ou o nome do seu certificado de administración)
- `admin-key.pem` (ou o nome da súa chave de administración, en formato PKCS#8)

Actualice `opensearch.yml` para que apunte aos nomes dos seus ficheiros de
certificado se difiren dos de AxonOps por defecto.

#### Modelo de substitución do usuario administrador

A diferenza de AxonDB Time-Series (que engade un usuario propio), AxonDB Search
usa un modelo de **SUBSTITUCIÓN**, por seguridade:

**Configuración por defecto (sen usuario propio):**
- Usuario administrador por defecto: `admin`
- Contrasinal por defecto: `MyS3cur3P@ss2025`
- Ubicación: `/etc/opensearch/opensearch-security/internal_users.yml`

**Configuración con usuario propio (recomendada en produción):**
```bash
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_USER=dbadmin \
  -e AXONOPS_SEARCH_PASSWORD=MySecurePassword123 \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Que ocorre:**
1. O script de entrypoint xera o hash bcrypt do contrasinal do usuario propio
2. **SUBSTITÚE** o ficheiro `internal_users.yml` enteiro, só co usuario propio
3. O usuario `admin` por defecto ELIMÍNASE (non existe na configuración final)
4. Só existe UN usuario administrador no sistema (o propio)
5. Escríbese o ficheiro semáforo en `/var/lib/opensearch/.axonops/init-security.done`

**Xustificación de seguridade:**
- **Principio de mínimo privilexio**: unha soa conta de administración reduce a superficie de ataque
- **Sen credenciais por defecto**: elimina o risco de esquecer o administrador por defecto
- **Operación atómica**: a creación do usuario é atómica (ocorre antes de que OpenSearch arranque)
- **Modelo de seguridade limpo**: sen contas herdadas nin usuarios desactivados

#### Opcións de configuración de TLS

**Activar ou desactivar o SSL de HTTP:**

Por defecto, HTTPS está activado na API REST. Pode desactivalo se o TLS termina no
balanceador de carga:

```bash
# Disable HTTP SSL (TLS terminated at load balancer)
docker run -d --name axondb-search \
  -e AXONOPS_SEARCH_TLS_ENABLED=false \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

**Importante:**
- O SSL da capa de transporte (entre nodos) segue activo aínda que se desactive o de HTTP
- É o recomendado cando se usa un balanceador de carga ou un controlador de ingress que termina o TLS
- A comunicación interna do clúster vai sempre cifrada

**DN do certificado propio (avanzado):**

En escenarios con certificados propios, pode cambiar o DN do certificado de
administración:

```bash
docker run -d --name axondb-search \
  -e OPENSEARCH_SECURITY_ADMIN_DN="CN=mycustomadmin,O=MyOrg,OU=MyUnit" \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

### Inicialización automatizada (configuración de seguridade e usuario administrador)

O contedor fai unha inicialización de seguridade automatizada, que cobre tanto a
verificación dos certificados como a creación opcional dun usuario administrador
propio. A inicialización coordínase con ficheiros semáforo, para que a orde coas
sondas de saúde sexa a correcta.

#### Como funciona (fluxo de execución)

A inicialización usa **configuración previa ao arranque** (non un proceso en
segundo plano) para crear o administrador, cun script de verificación en segundo
plano:

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

**Por que este patrón é seguro:**

1. **O administrador créase antes de que OpenSearch arranque**: sen condicións de carreira, operación atómica
2. **Só existe UN usuario administrador**: modelo de substitución (o propio ou o de por defecto, nunca os dous)
3. **Coordinación por semáforos**: a comprobación de saúde agarda a que a inicialización remate
4. **Semáforos persistentes**: gárdanse en `/var/lib/opensearch` (volume), o que evita reinicializar nos reinicios
5. **Aplicación por Kubernetes**: o pod non se marca «Started» ata que o semáforo confirma o éxito

#### Creación do usuario administrador (antes do arranque)

O entrypoint crea un usuario administrador propio e elimina o administrador por
defecto **antes** de que OpenSearch arranque.

**Que fai:**
1. Xera o hash bcrypt do contrasinal do usuario propio (coa ferramenta hash.sh de OpenSearch)
2. **SUBSTITÚE** `internal_users.yml` só coa definición do usuario propio
3. O usuario `admin` por defecto elimínase (non existe na configuración final)
4. Escribe o semáforo inicial no almacenamento persistente: `/var/lib/opensearch/.axonops/init-security.done`

**Exemplo:**
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

**Comprobacións de seguridade:**
- Só se executa se están definidas tanto `AXONOPS_SEARCH_USER` como `AXONOPS_SEARCH_PASSWORD`
- A xeración do hash do contrasinal valídase (debe ser un bcrypt válido)
- A substitución do ficheiro é atómica (escríbese enteiro antes de que OpenSearch arranque)
- **O semáforo escríbese SEMPRE** (con éxito ou con erro)

#### Fin do arranque

Cando o entrypoint remata toda a configuración previa ao arranque:

**Que ocorre:**
1. O proceso de OpenSearch arranca con toda a configuración aplicada
2. O plugin de seguridade carga co administrador preconfigurado
3. Úsanse os certificados de AxonOps para o TLS
4. A sonda de arranque da comprobación de saúde verifica que o semáforo indica RESULT=success
5. O contedor márcase «Started» en Kubernetes só cando a comprobación de saúde pasa

#### Control e desactivación

**Desactivar por completo o plugin de seguridade (NON recomendado en produción):**
```bash
docker run -d --name axondb-search \
  -e DISABLE_SECURITY_PLUGIN=true \
  ghcr.io/axonops/axondb-search:3.3.2-1.0.0
```

Cando está desactivado, os ficheiros semáforo escríbense de inmediato con
`RESULT=skipped`, para que a comprobación de saúde poida seguir adiante.

#### Ficheiros semáforo

O proceso de inicialización usa ficheiros semáforo para coordinarse entre o script
de entrypoint, a verificación en segundo plano e as sondas de saúde.

**Ubicación:** `/var/lib/opensearch/.axonops/`

Os ficheiros semáforo gárdanse no directorio de datos de OpenSearch (non en
`/etc`) porque:
- `/var/lib/opensearch` adoita configurarse como volume persistente en Kubernetes
- Ao seren persistentes, os semáforos sobreviven aos reinicios de contedor ou de pod
- Evita reinicializar nos reinicios de pod (por exemplo, durante unha actualización progresiva)
- Permite que a comprobación de saúde pase de inmediato tras un reinicio, sen volver executar a inicialización

**Importante:** configure `/var/lib/opensearch` como volume persistente
(PersistentVolumeClaim) no seu despregamento de Kubernetes. Os charts de Helm de
AxonOps fano automaticamente.

**Ficheiro creado:**
- `init-security.done`: o estado da configuración de seguridade e do usuario administrador

**Formato do ficheiro:**
```
COMPLETED=2025-12-16T09:32:17Z
RESULT=success
REASON=custom_user_created_prestartup
ADMIN_USER=dbadmin
```

**Valores de RESULT en init-security.done:**
- `success`: a inicialización de seguridade rematou correctamente
  - `custom_user_created_prestartup`: creouse o administrador propio (o admin por defecto eliminouse)
  - `default_config`: úsase o administrador e o contrasinal por defecto

**Nota:** se a inicialización falla (por exemplo, se falla a xeración do hash do
contrasinal), o script de entrypoint remata con código 1 antes de escribir o
semáforo, o que impide que o contedor arranque.

**Garantía:** o ficheiro semáforo escríbeo **SEMPRE** o script de entrypoint. A
sonda de arranque da comprobación de saúde:
1. Esixe que exista o ficheiro semáforo
2. Comproba o campo RESULT
3. Pasa se RESULT=success

Se o entrypoint atopa erros durante a inicialización previa ao arranque, remata
con código 1 antes de chegar a arrancar OpenSearch, así que o contedor nunca chega
a arrancar de todo.

#### Rexistros da inicialización

Consulte o progreso e os resultados da inicialización:

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

## Ficheiros de configuración

O contedor inclúe 13 ficheiros de configuración que controlan o comportamento de
OpenSearch:

### Ficheiros de configuración principais

| Ficheiro | Propósito | Personalizacións clave |
|------|---------|-------------------|
| `opensearch.yml` | Axustes centrais de OpenSearch | Valores por defecto listos para produción para cargas de busca, configuración do plugin de seguridade, rutas dos certificados de AxonOps |
| `jvm.options` | Opcións da JVM | Axustes de heap (8G por defecto), configuración do GC optimizada para busca |
| `log4j2.properties` | Configuración de rexistro | Retención reducida, optimizada para entornos de contedores |

### Ficheiros de configuración do plugin de seguridade (9 ficheiros)

En `/etc/opensearch/opensearch-security/`:

| Ficheiro | Propósito | Descrición |
|------|---------|-------------|
| `config.yml` | Configuración principal do plugin de seguridade | Backends de autenticación e autorización (basic auth, LDAP, JWT, etc.) |
| `internal_users.yml` | Base de datos de usuarios internos | A definición do usuario administrador (o entrypoint SUBSTITÚEA se se indica un usuario propio) |
| `roles.yml` | Definicións de roles | Roles predefinidos (admin, readall, etc.) |
| `roles_mapping.yml` | Correspondencias de usuario a rol | Asocia usuarios e roles de backend a roles de OpenSearch |
| `action_groups.yml` | Definicións de grupos de accións | Grupos de permisos, para simplificar a creación de roles |
| `tenants.yml` | Configuración de multiinquilino | Definicións de inquilinos, para illar os paneis |
| `nodes_dn.yml` | Distinguished names dos nodos | Os DN de certificado admitidos na comunicación entre nodos (herdado; use a variable `OPENSEARCH_SECURITY_NODES_DN` no seu lugar) |
| `allowlist.yml` | Lista branca da API | Os endpoints da API REST permitidos cando a seguridade está restrinxida |
| `audit.yml` | Configuración do rexistro de auditoría | Axustes do rexistro de auditoría (desactivado por defecto, pódese activar) |

**Puntos destacados da configuración:**

**opensearch.yml:**
- **Clúster:** `axonopsdb-search` (configurable con `OPENSEARCH_CLUSTER_NAME`)
- **Descubrimento:** `single-node` por defecto (configurable con `OPENSEARCH_DISCOVERY_TYPE`)
- **Bloqueo de memoria:** `bootstrap.memory_lock: true` (require a capacidade IPC_LOCK)
- **Rede:** escoita en `0.0.0.0` (todas as interfaces)
- **Pool de fíos:** `thread_pool.write.queue_size: 10000` (súbao con moitas escrituras)
- **Seguridade:** certificados coa marca AxonOps, certificados de demostración desactivados (`allow_unsafe_democertificates: false`)
- **Nodes DN:** comodín por defecto `CN=*.axonops.svc.cluster.local` (configurable con `OPENSEARCH_SECURITY_NODES_DN`)

**jvm.options:**
- **Heap:** 8G por defecto (`-Xms8g -Xmx8g`), configurable con `OPENSEARCH_HEAP_SIZE`
- **GC:** optimizado para JVM modernas (JDK 17+)

**log4j2.properties:**
- **Niveis de rexistro:** INFO por defecto; pódese activar DEBUG se fai falta
- **Retención:** optimizada para entornos de contedores, cun crecemento dos rexistros controlado
- **Ubicación:** `/var/log/opensearch/`

**internal_users.yml:**
- **Por defecto:** contén o usuario `admin` co contrasinal en hash bcrypt
- **Usuario propio:** **SUBSTITÚESE por completo** se se define `AXONOPS_SEARCH_USER` (só existe o usuario propio)
- **Formato:** YAML con hashes bcrypt dos contrasinais

**config.yml:**
- **Autenticación:** HTTP Basic activada por defecto contra a base de datos de usuarios internos
- **Autorización:** correspondencia interna de roles
- **Autenticación adicional:** LDAP, JWT, Kerberos e certificados de cliente dispoñibles (desactivados por defecto)

## Pipeline de CI/CD

### Workflows

O repositorio inclúe workflows completos de GitHub Actions:

**Build e probas** (`.github/workflows/axondb-search-build-and-test.yml`)
- **Disparadores:** push ou PR ás ramas main, development, feature/* e fix/*
  - Cando cambia `axonops/axondb-search/**` (excluíndo os ficheiros `*.md`)
  - Cando cambian os workflows (`.github/workflows/axondb-search-*.yml`)
  - Cando cambian as actions (`.github/actions/axondb-search-*/**`)
- **Probas:** build de Docker, verificación de versión, comprobación de saúde e escaneo de seguridade
- **Duración:** uns 10 minutos

**Publicación de produción** (`.github/workflows/axondb-search-publish-signed.yml`)
- **Disparador:** execución manual do workflow cunha etiqueta de git
- **Proceso:** validar → probar → crear a release → construír → asinar → publicar → verificar
- **Rexistro:** `ghcr.io/axonops/axondb-search`
- **Plataformas:** linux/amd64, linux/arm64
- **Sinatura:** sinatura sen chaves con Cosign (OIDC)

**Publicación de desenvolvemento** (`.github/workflows/axondb-search-development-publish-signed.yml`)
- **Disparador:** execución manual do workflow dende a rama development
- **Rexistro:** `ghcr.io/axonops/development/axondb-search`
- **Uso:** probar imaxes antes dunha release de produción

### Probas automatizadas

O pipeline de CI inclúe probas exhaustivas:

**Probas funcionais:**
- Verificación do build do contedor (multiarquitectura)
- Verificación do banner de arranque (produción fronte a desenvolvemento)
- Verificación de versións (OpenSearch, Java)
- Probas do script de comprobación de saúde (startup, liveness, readiness)
- Verificación da inicialización de seguridade
- Operacións da API REST con curl
- Tratamento das variables de entorno (20 variables)
- Verificación dos certificados

**Probas de seguridade:**
- Escaneo de vulnerabilidades do contedor con Trivy (severidade CRITICAL e HIGH)
- Os resultados sóbense á lapela Security de GitHub
- Os CVE upstream coñecidos documéntanse en `.trivyignore`
- Verificación dos certificados (coa marca AxonOps, non de demostración)

**Accións compostas:**
En `.github/actions/axondb-search-*/`:
- `start-and-wait`: arranca o contedor e agarda a que estea listo
- `verify-startup-banner`: verifica o contido do banner
- `verify-no-startup-errors`: busca erros de arranque
- `verify-versions`: verifica as versións dos compoñentes
- `test-healthcheck`: proba todos os modos de comprobación de saúde
- `verify-init-scripts`: verifica que a inicialización de seguridade rematou
- `test-rest-api`: proba o funcionamento da API REST
- `test-all-env-vars`: proba a configuración por variables de entorno (20 variables)
- `verify-certificates`: verifica os certificados de AxonOps (non os de demostración)
- `sign-container`: sinatura con Cosign
- `verify-published-image`: verificación tras a publicación
- `collect-logs`: recolle os rexistros do contedor
- `determine-latest`: determina as etiquetas latest

### Proceso de publicación

**Release de desenvolvemento:**
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

**Release de produción:**
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

Véxase [RELEASE.md](./RELEASE.md) para a documentación completa do proceso de
release.

## Resolución de problemas

### Comprobar a versión do contedor

Consulte o banner de arranque para ver todas as versións dos compoñentes:

```bash
docker logs axondb-search | head -30
```

O banner amosa:
- A versión do contedor e a revisión de git
- As versións de OpenSearch, Java e do sistema operativo
- O digest da imaxe base (para verificar a cadea de subministración)
- Os detalles do entorno de execución

### Rexistros do script de inicialización

Consulte o progreso e os resultados da inicialización:

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

**Formato do ficheiro semáforo:**
```
COMPLETED=2025-12-16T10:45:00Z
RESULT=success
REASON=custom_user_created_prestartup
ADMIN_USER=dbadmin
```

Valores posibles de `RESULT`:
- `success`: a operación rematou correctamente
- `skipped`: a operación omitiuse (cun campo REASON explicando por que)
- `failed`: a operación fallou (cun campo REASON explicando por que)

### Depurar a comprobación de saúde

Probe as sondas de saúde a man:

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

### O contedor non arranca

**Revise os rexistros:**
```bash
docker logs axondb-search
```

**Problemas habituais:**

1. **Memoria insuficiente:**
   - O heap por defecto é de 8G; asegúrese de que o contedor ten polo menos 12 GB de RAM (1,5 veces o heap)
   - Axústeo con: `-e OPENSEARCH_HEAP_SIZE=4g`

2. **Conflitos de portos:**
   - HTTP: 9200
   - Transporte: 9300
   - Compróbeo con: `netstat -tuln | grep 9200`

3. **Problemas de permisos:**
   - O contedor execútase como o usuario `opensearch` (UID 999)
   - Asegure os permisos do volume: `chown -R 999:999 /data/opensearch`

4. **`vm.max_map_count` demasiado baixo:**
   - Compróbeo: `sysctl vm.max_map_count`
   - Fíxeo: `sudo sysctl -w vm.max_map_count=262144`
   - De forma permanente: engádao a `/etc/sysctl.conf`

5. **Problemas de inicialización:**
   - Revise o semáforo: `docker exec axondb-search cat /var/lib/opensearch/.axonops/init-security.done`
   - Busque RESULT=failed ou un REASON concreto

**Consultar os rexistros de OpenSearch:**
```bash
docker exec axondb-search cat /var/log/opensearch/axonopsdb-search.log
```

**Verificar que OpenSearch está en marcha:**
```bash
docker exec axondb-search ps aux | grep opensearch
```

**Probar a conectividade da API REST:**
```bash
# With default credentials
curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health

# With custom credentials
curl -k -u dbadmin:MySecurePassword123 https://localhost:9200/_cluster/health

# Without TLS (if AXONOPS_SEARCH_TLS_ENABLED=false)
curl -u admin:MyS3cur3P@ss2025 http://localhost:9200/_cluster/health
```

## Consideracións para produción

1. **Almacenamento persistente**
   - Use sempre volumes para `/var/lib/opensearch` (datos e semáforos)
   - Use volumes para `/var/log/opensearch` (rexistros)
   - Exemplo: `-v /data/opensearch:/var/lib/opensearch`
   - Use almacenamento SSD para cargas de produción (fan falta moitas IOPS)

2. **Asignación de recursos**
   - Memoria: polo menos 1,5 veces o tamaño do heap (por exemplo, 12 GB para un heap de 8 GB)
   - CPU: recoméndanse 4 ou máis núcleos
   - Disco: almacenamento SSD rápido con IOPS axeitadas
   - Heap: máximo 32 GB (pola optimización de punteiros comprimidos da JVM)

3. **Configuración do sistema**
   - **vm.max_map_count:** debe ser >= 262144 en todos os nodos
   - **ulimits.nofile:** póñao a 65536 (descritores de ficheiro abertos máximos)
   - **Capacidade IPC_LOCK:** fai falta para `bootstrap.memory_lock: true`
   - Desactive o swap, para o mellor rendemento

4. **Rede**
   - Expoña os portos necesarios: 9200 (HTTP), 9300 (transporte)
   - Use regras de cortalumes axeitadas
   - Valore terminar o TLS no balanceador de carga (poña `AXONOPS_SEARCH_TLS_ENABLED=false`)
   - O SSL da capa de transporte segue activo para a comunicación entre nodos

5. **Seguridade**
   - Use un usuario administrador propio (defina `AXONOPS_SEARCH_USER` e `AXONOPS_SEARCH_PASSWORD`)
   - **NUNCA** use as credenciais por defecto en produción
   - Verifique as sinaturas dos contedores con Cosign
   - Use referencias de imaxe baseadas en digest, por inmutabilidade
   - Manteña as imaxes base actualizadas (automatizado en UBI)
   - Os certificados coa marca AxonOps son de nivel de produción (RSA 3072, 5 anos de validez)

6. **Monitorización**
   - Use as sondas de saúde para monitorizar a dispoñibilidade
   - Vixíe o uso do heap coas métricas da JVM
   - Configure a agregación de rexistros de `/var/log/opensearch/`
   - Valore integralo con AxonOps para unha monitorización completa
   - Vixíe a saúde do clúster coa API `/_cluster/health`

7. **Estratexia de copias de seguranza**
   - Faga snapshots periódicos de `/var/lib/opensearch/data`
   - Use a API de repositorio de snapshots de OpenSearch
   - Probe os procedementos de restauración
   - Documente os obxectivos de tempo de recuperación (RTO)

8. **Despregamento en clúster**
   - Use un `OPENSEARCH_CLUSTER_NAME` consistente en todos os nodos
   - Configure os seed hosts para o descubrimento entre varios nodos
   - Planifique os nodos elixibles como cluster-manager (mínimo 3, para o quórum)
   - Use nodos cluster-manager dedicados en clústeres grandes
   - Configure correctamente a conciencia de asignación de shards

Para o fluxo de traballo de desenvolvemento e as probas, véxase
[DEVELOPMENT.md](./DEVELOPMENT.md).

Para o proceso de release, véxase [RELEASE.md](./RELEASE.md).
