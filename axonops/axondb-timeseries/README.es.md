# Base de datos de series temporales AxonDB

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

[![Paquete GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axondb-timeseries)

Contenedor de Apache Cassandra 5.0.6 listo para producción, optimizado para
cargas de series temporales en despliegues autoalojados de AxonOps.

## Índice

- [Visión general](#visión-general)
- [Imágenes de Docker precompiladas](#imágenes-de-docker-precompiladas)
  - [Imágenes disponibles](#imágenes-disponibles)
  - [Estrategia de etiquetado](#estrategia-de-etiquetado)
- [Buena práctica en producción](#buena-práctica-en-producción)
- [Despliegue](#despliegue)
- [Construir las imágenes de Docker](#construir-las-imágenes-de-docker)
- [Variables de entorno](#variables-de-entorno)
  - [Configuración de Cassandra](#configuración-de-cassandra)
  - [Control de la inicialización](#control-de-la-inicialización)
- [Prestaciones del contenedor](#prestaciones-del-contenedor)
  - [Script de entrypoint](#script-de-entrypoint)
  - [Banner de versión al arrancar](#banner-de-versión-al-arrancar)
  - [Sondas de salud](#sondas-de-salud)
  - [Inicialización automatizada (keyspaces de sistema y usuario de base de datos)](#inicialización-automatizada-keyspaces-de-sistema-y-usuario-de-base-de-datos)
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

AxonDB Time-Series es un contenedor de Apache Cassandra listo para producción,
diseñado expresamente para los despliegues autoalojados de AxonOps. Está
optimizado para cargas de base de datos de series temporales y se despliega como
parte de la pila completa de AxonOps con los charts de Helm de AxonOps.

**Prestaciones del contenedor:**
- **Shell de CQL moderna**: [cqlai](https://github.com/axonops/cqlai) v0.1.2, para una interacción mejorada con la base de datos
- **Optimización de memoria**: jemalloc, para una mejor gestión de la memoria
- **Configuración automatizada**: inicialización de los keyspaces de sistema y creación de un usuario propio
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

Todas las imágenes están en: `ghcr.io/axonops/axondb-timeseries`

Consulte todas las etiquetas disponibles:
[GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axondb-timeseries)

### Estrategia de etiquetado

Las imágenes usan una estrategia de etiquetado bidimensional:

| Patrón de etiqueta | Ejemplo | Descripción | Caso de uso |
|-------------|---------|-------------|----------|
| `{CASS}-{AXON}` | `5.0.6-1.0.0` | Totalmente inmutable (versión de Cassandra + de AxonOps) | **Producción**: fije versiones exactas para una auditabilidad completa |
| `@sha256:<digest>` | `@sha256:abc123...` | Basada en digest (criptográficamente inmutable) | **Máxima seguridad**: integridad de la imagen garantizada |
| `{CASS}` | `5.0.6` | El último AxonOps para esa versión de Cassandra | Seguir las actualizaciones de AxonOps de una versión concreta de Cassandra |
| `latest` | `latest` | La última de todas las versiones | Sólo para pruebas rápidas (NO para producción) |

**Dimensiones del versionado:**
- **CASS**: la versión de Cassandra (por ejemplo, 5.0.6)
- **AXON**: la versión del contenedor de AxonOps (por ejemplo, 1.0.0, en SemVer)

**Ejemplos de etiquetado:**

Cuando se construye `5.0.6-1.0.0` (y es la más reciente):
- `5.0.6-1.0.0` (inmutable: no cambia nunca)
- `5.0.6` (flotante: se reetiqueta a builds de AxonOps más nuevos)
- `latest` (flotante: se mueve a versiones de Cassandra más nuevas)

## 💡 Buena práctica en producción

⚠️ **Usar `latest` o etiquetas flotantes en producción es un antipatrón.** Esto
incluye `latest` y `5.0.6`, porque:
- **No hay rastro de auditoría**: no se puede determinar qué versión exacta estaba desplegada en un momento dado
- **Actualizaciones inesperadas**: los orquestadores de contenedores pueden descargar imágenes nuevas al reiniciar
- **Dificultades para volver atrás**: no se puede retroceder de forma fiable a versiones anteriores
- **Problemas de cumplimiento**: muchos marcos normativos exigen un seguimiento de versiones inmutable

👍 **Estrategias de despliegue recomendadas (de mayor a menor seguridad):**

1. **🥇 Referencia de oro: basada en digest** (máxima seguridad)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries@sha256:abc123...
   ```
   - 100 % inmutable, garantizado criptográficamente
   - Obligatoria en entornos regulados
   - Verifique la firma con Cosign (véase [Seguridad](#seguridad))

2. **🥈 Etiqueta inmutable** (el estándar de producción)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
   ```
   - Fijada a una versión concreta (Cassandra 5.0.6 + AxonOps 1.0.0)
   - Fácil de leer y de gestionar
   - Mantiene un rastro de auditoría completo

3. **🥉 Etiquetas flotantes** (sólo desarrollo y pruebas)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries:latest
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
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0

# Check signature exists
cosign tree ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

## Despliegue

Este contenedor se despliega exclusivamente mediante los **charts de Helm de
AxonOps**, como parte de la pila autoalojada de AxonOps. Los charts de Helm se
ocupan de toda la configuración, la orquestación y la integración con los
componentes de monitorización y gestión de AxonOps.

Para las instrucciones de despliegue, consulte la documentación de despliegue
autoalojado de AxonOps (disponible cuando se publiquen los charts de Helm).

## Construir las imágenes de Docker

Si prefiere construir las imágenes usted mismo en lugar de usar las
precompiladas:

```bash
cd axonops/axondb-timeseries/5.0.6

# Minimal build (required args only)
docker build \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg CQLAI_VERSION=0.1.4 \
  -t axondb-timeseries:5.0.6-1.0.0 \
  .

# Multi-arch build (amd64 + arm64) using buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg CQLAI_VERSION=0.1.4 \
  -t axondb-timeseries:5.0.6-1.0.0 \
  .
```

**Argumentos de build obligatorios:**
- `CASSANDRA_VERSION`: la versión de Cassandra (por ejemplo, 5.0.6)
- `CQLAI_VERSION`: la versión de cqlai que instalar (véase la [última release](https://github.com/axonops/cqlai/releases))

**Ficheros de configuración propios:**

El contenedor incluye ficheros de configuración de Cassandra personalizados y
optimizados para despliegues en contenedores:

| Fichero | Propósito | Personalizaciones clave |
|------|---------|-------------------|
| `cassandra.yaml` | Ajustes centrales de Cassandra | Valores por defecto listos para producción, para cargas de series temporales |
| `jvm-server.options` | Opciones de la JVM | Ajustes de memoria y configuración del GC |
| `jvm17-server.options` | Opciones específicas de JDK 17 | GC Shenandoah, ajustes de heap (8G por defecto) |
| `cassandra-env.sh` | Entorno de Cassandra | Parámetros de la JVM, optimización de memoria |
| `logback.xml` | Configuración de registro | Retención reducida (1 GB en total, 7 días), registro de depuración desactivado en producción |

**Puntos destacados de logback.xml:**
- **SYSTEMLOG** (system.log): nivel INFO, ficheros de 50 MB, retención de 7 días, **tope total de 1 GB** (reducido desde los 5 GB por defecto)
- **DEBUGLOG** (debug.log): desactivado por defecto (se puede activar descomentando el appender-ref)
- **Registro de auditoría**: la infraestructura está presente pero desactivada (se puede activar en cassandra.yaml si hace falta)
- Optimizado para entornos de contenedores, con un crecimiento de los registros controlado

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

El contenedor admite 14 variables de entorno de configuración:

| Variable | Descripción | Valor por defecto | Categoría |
|----------|-------------|---------|----------|
| `CASSANDRA_CLUSTER_NAME` | El nombre del clúster | `axonopsdb-timeseries` | Cassandra |
| `CASSANDRA_NUM_TOKENS` | Número de tokens por nodo (vnodes) | `8` | Cassandra |
| `CASSANDRA_DC` | El nombre del datacenter | `axonopsdb_dc1` | Cassandra |
| `CASSANDRA_RACK` | El nombre del rack | `rack1` | Cassandra |
| `CASSANDRA_LISTEN_ADDRESS` | La dirección IP de escucha (`auto` = autodetectar) | `auto` | Cassandra |
| `CASSANDRA_BROADCAST_ADDRESS` | La dirección IP que se difunde a los demás nodos | La misma que `CASSANDRA_LISTEN_ADDRESS` | Cassandra |
| `CASSANDRA_RPC_ADDRESS` | La dirección del transporte nativo de CQL | `0.0.0.0` (todas las interfaces) | Cassandra |
| `CASSANDRA_BROADCAST_RPC_ADDRESS` | La dirección RPC difundida a los clientes | La misma que `CASSANDRA_LISTEN_ADDRESS` | Cassandra |
| `CASSANDRA_SEEDS` | Las direcciones de los nodos seed (separadas por comas) | La IP propia (para un solo nodo) | Cassandra |
| `CASSANDRA_HEAP_SIZE` | El tamaño del heap de la JVM (tanto -Xms como -Xmx) | `8G` | Cassandra |
| `INIT_SYSTEM_KEYSPACES_AND_ROLES` | Convierte automáticamente los keyspaces de sistema y crea los roles propios | `true` | Inicialización |
| `INIT_TIMEOUT` | Segundos que el script de inicialización espera a Cassandra | `600` (10 min) | Inicialización |
| `AXONOPS_DB_USER` | Crea un superusuario propio con este nombre (opcional) | - | Inicialización |
| `AXONOPS_DB_PASSWORD` | La contraseña del superusuario propio (obligatoria si se define `AXONOPS_DB_USER`) | - | Inicialización |

### Configuración de Cassandra

Las 10 primeras variables configuran el comportamiento central de Cassandra. El
script de entrypoint las procesa y las aplica a los ficheros de configuración de
Cassandra antes de que Cassandra arranque.

**Configuración de red:**
- `CASSANDRA_LISTEN_ADDRESS`: póngala a `auto` para detectar la IP automáticamente, o indique una dirección IP
- `CASSANDRA_BROADCAST_ADDRESS`: por defecto, la dirección de escucha; cámbiela en escenarios con NAT o cortafuegos
- `CASSANDRA_RPC_ADDRESS`: póngala a `0.0.0.0` para escuchar en todas las interfaces
- `CASSANDRA_SEEDS`: lista separada por comas, para clústeres de varios nodos

**Configuración de la topología:**
- `CASSANDRA_DC` y `CASSANDRA_RACK`: definen el datacenter y el rack, para una replicación correcta
- Se escriben en `cassandra-rackdc.properties` y las lee `GossipingPropertyFileSnitch`
- Valores por defecto: `axonopsdb_dc1` / `rack1` (cámbielos en despliegues de producción)

**Configuración de recursos:**
- `CASSANDRA_HEAP_SIZE`: controla el heap de la JVM (tanto -Xms como -Xmx toman el mismo valor)

**Ejemplo:**
```bash
docker run -d --name axondb \
  -e CASSANDRA_CLUSTER_NAME=production-cluster \
  -e CASSANDRA_DC=us-east-1 \
  -e CASSANDRA_RACK=1a \
  -e CASSANDRA_SEEDS=10.0.1.10,10.0.1.11,10.0.1.12 \
  -e CASSANDRA_HEAP_SIZE=16G \
  -p 9042:9042 \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

### Control de la inicialización

Las 4 últimas variables (`INIT_SYSTEM_KEYSPACES_AND_ROLES`, `INIT_TIMEOUT`,
`AXONOPS_DB_USER`, `AXONOPS_DB_PASSWORD`) controlan el comportamiento de la
inicialización automática que ocurre después de que Cassandra arranque.

**Inicialización de los keyspaces de sistema:**

En el primer arranque de un clúster de un solo nodo recién creado, el contenedor
convierte automáticamente los keyspaces de sistema de `SimpleStrategy` a
`NetworkTopologyStrategy`, para que estén listos para producción.

**Configuración del timeout:**
El script de inicialización espera hasta `INIT_TIMEOUT` segundos (por defecto:
600, es decir, 10 minutos) a que Cassandra esté lista. Si su entorno arranca
lento (heap grande, discos lentos), suba ese valor:

```bash
docker run -d --name axondb \
  -e INIT_TIMEOUT=1200 \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

**El proceso de inicialización:**

- Sólo se ejecuta en clústeres de un solo nodo con las credenciales por defecto `cassandra/cassandra`
- Detecta el nombre del datacenter de la instancia de Cassandra en marcha
- Convierte: `system_auth`, `system_distributed`, `system_traces`
- Escribe ficheros semáforo para coordinarse con la comprobación de salud
- Se salta si ya se convirtió o si detecta un clúster de varios nodos

Para desactivarlo: `INIT_SYSTEM_KEYSPACES_AND_ROLES=false`

**Usuario de base de datos propio:**

Cree automáticamente un superusuario propio y desactive el usuario `cassandra`
por defecto:

```bash
docker run -d --name axondb \
  -e AXONOPS_DB_USER=admin \
  -e AXONOPS_DB_PASSWORD=SecurePassword123 \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  -p 9042:9042 \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0

# Connect with new credentials (after ~2 minutes for initialization)
docker exec -it axondb cqlai -u admin -p SecurePassword123
```

**Importante:**
- La creación del usuario propio sólo funciona en clústeres recién creados con las credenciales por defecto
- El usuario `cassandra` por defecto se desactiva tras crear el usuario propio (se le pone `can_login=false`)
- La creación del usuario se ejecuta después de que termine la inicialización de los keyspaces de sistema
- Ambas operaciones las hace el mismo script: `init-system-keyspaces.sh`
- Registros de progreso: `/var/log/cassandra/init-system-keyspaces.log`
- Marcadores de finalización (en el volumen persistente):
  - `/var/lib/cassandra/.axonops/init-system-keyspaces.done`
  - `/var/lib/cassandra/.axonops/init-db-user.done`

## Prestaciones del contenedor

### Script de entrypoint

El script de entrypoint (`/usr/local/bin/docker-entrypoint.sh`) es el
orquestador principal que configura Cassandra y gestiona el arranque del
contenedor. Se ejecuta como PID 1 a través de
[tini](https://github.com/krallin/tini) y hace la inicialización crítica antes de
arrancar Cassandra.

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
CMD ["cassandra", "-f"]
```

Eso significa que el árbol de procesos real es:
```
tini (PID 1)
  └─► docker-entrypoint.sh
       └─► cassandra -f (after exec)
```

Tras `exec cassandra -f`, Cassandra sustituye al script de shell, pero tini sigue
siendo el PID 1, lo que garantiza un manejo correcto de las señales en todo el
contenedor.

**Más información:** [github.com/krallin/tini](https://github.com/krallin/tini)

#### Qué hace

**1. Muestra el banner de arranque**
- Toma los metadatos del build de `/etc/axonops/build-info.txt`
- Imprime información de versión completa (Cassandra, Java, cqlai, jemalloc, sistema operativo)
- Muestra el entorno de ejecución (detección de Kubernetes, nombre de host)
- Muestra la información de seguridad de la cadena de suministro (el digest de la imagen base)

**2. Configura la red y las direcciones IP**
- Autodetecta la IP del contenedor si `CASSANDRA_LISTEN_ADDRESS=auto`
- Fija las direcciones de difusión a partir de la dirección de escucha
- Configura las direcciones RPC (CQL) para las conexiones de los clientes
- Garantiza una configuración correcta de los nodos seed

**3. Aplica las variables de entorno a la configuración de Cassandra**
- Procesa todas las variables de entorno `CASSANDRA_*`
- Actualiza `cassandra.yaml` con los ajustes indicados por el usuario
- Modifica `cassandra-rackdc.properties` para la configuración de DC y rack
- Ajusta el tamaño del heap de la JVM en `jvm17-server.options`
- Usa `GossipingPropertyFileSnitch` (preconfigurado en cassandra.yaml), que lee el DC y el rack de cassandra-rackdc.properties

**4. Activa la optimización de memoria con jemalloc**
- Define `LD_PRELOAD=/usr/lib64/libjemalloc.so.2`
- Mejora el rendimiento de la asignación de memoria
- Repliegue seguro si no encuentra jemalloc

**5. Lanza la inicialización en segundo plano**
- Arranca `init-system-keyspaces.sh` en segundo plano (sin bloquear)
- O escribe los semáforos de omisión si `INIT_SYSTEM_KEYSPACES_AND_ROLES=false`
- Permite que Cassandra arranque de inmediato mientras la inicialización espera a que esté lista

**6. Arranca Cassandra**
- Ejecuta `cassandra -f` (en primer plano)
- Sustituye al proceso del entrypoint (pasa a ser el PID 1)
- Cassandra queda como proceso principal del contenedor

#### Orden de ejecución

```
entrypoint.sh (PID 1 via tini)
  │
  ├─► 1. Print startup banner
  │
  ├─► 2. Set default environment variables
  │      (CASSANDRA_CLUSTER_NAME, CASSANDRA_DC, CASSANDRA_RACK, etc.)
  │
  ├─► 3. Resolve IP addresses
  │      (auto-detect if CASSANDRA_LISTEN_ADDRESS=auto)
  │
  ├─► 4. Apply environment variables to cassandra.yaml
  │      (cluster_name, num_tokens, listen_address, rpc_address, etc.)
  │
  ├─► 5. Apply DC/Rack to cassandra-rackdc.properties
  │
  ├─► 6. Apply heap size to jvm17-server.options
  │
  ├─► 7. Enable jemalloc (set LD_PRELOAD)
  │
  ├─► 8. Launch init-system-keyspaces.sh in background (&)
  │      - Non-blocking, runs in parallel with Cassandra
  │
  └─► 9. exec cassandra -f
         - Replaces entrypoint process
         - Cassandra becomes PID 1
         - Container runs Cassandra from this point
```

#### Ficheros de configuración modificados

El entrypoint modifica estos ficheros de configuración de Cassandra a partir de
las variables de entorno:

| Fichero | Qué modifica | Variables de entorno |
|------|----------------|----------------------|
| `/etc/cassandra/cassandra.yaml` | Ajustes centrales de Cassandra | `CASSANDRA_CLUSTER_NAME`, `CASSANDRA_NUM_TOKENS`, `CASSANDRA_LISTEN_ADDRESS`, `CASSANDRA_RPC_ADDRESS`, `CASSANDRA_BROADCAST_ADDRESS`, `CASSANDRA_BROADCAST_RPC_ADDRESS`, `CASSANDRA_SEEDS` |
| `/etc/cassandra/cassandra-rackdc.properties` | La topología de datacenter y rack | `CASSANDRA_DC` (por defecto: `axonopsdb_dc1`), `CASSANDRA_RACK` (por defecto: `rack1`) |
| `/etc/cassandra/jvm17-server.options` | Los ajustes de memoria del heap de la JVM | `CASSANDRA_HEAP_SIZE` |

**Nota:** el contenedor usa `GossipingPropertyFileSnitch` (preconfigurado en
cassandra.yaml), que lee la topología de DC y rack de
`cassandra-rackdc.properties`. Los valores de DC y rack son `axonopsdb_dc1` y
`rack1` por defecto si no se definen explícitamente.

#### Decisiones de diseño clave

**¿Por qué `exec cassandra -f`?**
- Usar `exec` sustituye el proceso de la shell por Cassandra
- Cassandra pasa a ser el PID 1 y recibe las señales directamente
- Garantiza un apagado limpio cuando se para el contenedor
- No queda ningún proceso de shell huérfano consumiendo recursos

**¿Por qué la inicialización en segundo plano?**
- El script de inicialización necesita Cassandra en marcha (requiere acceso CQL)
- Arrancar Cassandra primero permite que la inicialización espere a que esté lista
- Arranque sin bloqueo: el contenedor no se queda colgado durante la inicialización
- La sonda de arranque de la comprobación de salud impone que termine antes de encaminar tráfico

**¿Por qué tini como sistema de init?**
- **Reenvío de señales**: garantiza que SIGTERM/SIGINT lleguen a Cassandra, para un apagado ordenado
- **Recogida de zombis**: limpia los procesos hijos terminados (importante con el script de inicialización en segundo plano)
- **Buena práctica en contenedores**: evita problemas cuando el motor de contenedores envía señales de parada
- **Sobrecarga mínima**: un binario estático diminuto (~10 KB) y sin dependencias
- **Estándar del sector**: el mismo sistema de init que usa Docker con el flag `--init`
- Sin tini, los scripts de shell (PID 1) no reenvían bien las señales, y eso provoca matanzas forzadas

**Más información:** [por qué hace falta un sistema de init](https://github.com/krallin/tini#why-tini) en los contenedores

### Banner de versión al arrancar

Todos los contenedores muestran al arrancar información de versión completa:

```
================================================================================
AxonOps AxonDB Time-Series (Apache Cassandra 5.0.6)
Image: ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
Built: 2025-12-13T10:30:00Z
Release: https://github.com/axonops/axonops-containers/releases/tag/axondb-timeseries-1.0.0
Built by: GitHub Actions
================================================================================

Component Versions:
  Cassandra:          5.0.6
  Java:               OpenJDK Runtime Environment (Red_Hat-17.0.17.0.10-1)
  cqlai:              v0.1.2
  jemalloc:           jemalloc-5.2.1-2.el9.x86_64
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI - Universal Base Image, freely redistributable)
  Platform:           x86_64

Supply Chain Security:
  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest
  Base image digest:  sha256:80f3902b6dcb47005a90e14140eef9080ccc1bb22df70ee16b27d5891524edb2

Runtime Environment:
  Hostname:           axondb-node-1
  Kubernetes:         No

================================================================================
Starting Cassandra...
================================================================================
```

**Ver el banner:**
```bash
docker logs axondb | head -30
```

### Sondas de salud

El contenedor incluye un script de comprobación de salud optimizado que admite
tres tipos de sonda, diseñado para tener una sobrecarga mínima sin renunciar a la
fiabilidad:

**1. Sonda de arranque** (`healthcheck.sh startup`)
- **Espera a que terminen los scripts de inicialización** (crítico con el patrón de inicialización asíncrona)
- Busca los ficheros semáforo en el almacenamiento persistente:
  - `/var/lib/cassandra/.axonops/init-system-keyspaces.done` (debe existir)
  - `/var/lib/cassandra/.axonops/init-db-user.done` (debe existir)
- **Valida el campo RESULT**: falla si alguno de los semáforos tiene `RESULT=failed`
- Verifica que el proceso de Cassandra está en marcha (`pgrep -f cassandra`)
- Comprueba que el puerto CQL (9042) está escuchando (comprobación TCP con `nc`)
- **Ligera**: sin llamadas a nodetool, sólo comprobaciones de proceso y de puerto
- **Bloquea el estado «Started» del pod hasta que la inicialización termina correctamente**
- Úsela para: el `startupProbe` de Kubernetes (garantiza que la inicialización acaba antes de encaminar tráfico)

**2. Sonda de vida** (`healthcheck.sh liveness`)
- **Ultraligera**: pensada para ejecutarse a menudo (cada 10 segundos)
- Comprueba que el proceso de Cassandra está en marcha (`pgrep -f cassandra`)
- Comprueba que el puerto CQL (9042) está escuchando (comprobación TCP con `nc`)
- **Sin llamadas a nodetool**: sobrecarga mínima, ejecución muy rápida
- Úsela para: el `livenessProbe` de Kubernetes (detectar si el proceso de Cassandra ha caído)

**3. Sonda de disponibilidad** (`healthcheck.sh readiness`)
- Comprueba que el puerto CQL (9042) está escuchando (comprobación TCP con `nc`)
- Ejecuta `nodetool info` para verificar el estado interno de Cassandra
- Verifica que la salida indica «Native Transport active: true»
- Verifica que la salida indica «Gossip active: true»
- **Más exhaustiva** que la de vida: garantiza que Cassandra está plenamente operativa
- Úsela para: el `readinessProbe` de Kubernetes (comprobaciones del balanceador de carga, encaminamiento de tráfico)

**Comprobación de salud de Docker:**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect axondb --format='{{json .State.Health}}' | jq
```

**Probar la comprobación de salud a mano:**
```bash
# Test startup probe
docker exec axondb /usr/local/bin/healthcheck.sh startup

# Test liveness probe
docker exec axondb /usr/local/bin/healthcheck.sh liveness

# Test readiness probe
docker exec axondb /usr/local/bin/healthcheck.sh readiness
```

**Nota:** la configuración de las sondas de salud la gestionan automáticamente los
charts de Helm de AxonOps. Los modos de arriba están disponibles para despliegues
propios, si hacen falta.

### Inicialización automatizada (keyspaces de sistema y usuario de base de datos)

El contenedor hace una inicialización automatizada en el primer arranque, que
cubre tanto la conversión de los keyspaces de sistema como la creación opcional
de un usuario de base de datos propio. Ambas operaciones las hace un único script
en segundo plano (`init-system-keyspaces.sh`) que se ejecuta después de que
Cassandra arranque.

#### Cómo funciona (flujo de ejecución)

La inicialización usa un **proceso asíncrono en segundo plano** coordinado
mediante **ficheros semáforo**, para garantizar el orden correcto:

```
1. entrypoint.sh starts (PID 1 via tini)
   │
   ├─► 2. Launches init-system-keyspaces.sh in background (&)
   │      - Does NOT block Cassandra startup
   │      - Runs in parallel with Cassandra
   │
   └─► 3. Starts Cassandra (exec cassandra -f)
        │
        ├─► Cassandra starts and begins accepting connections
        │
        ├─► init-system-keyspaces.sh waits for Cassandra to be ready
        │   - Waits for CQL port (9042) to be listening
        │   - Waits for native transport + gossip active
        │   - Converts system keyspaces to NetworkTopologyStrategy
        │   - Creates custom database user (if AXONOPS_DB_USER set)
        │   - Writes semaphore files to persistent storage:
        │       /var/lib/cassandra/.axonops/init-system-keyspaces.done
        │       /var/lib/cassandra/.axonops/init-db-user.done
        │
        └─► healthcheck.sh (startup probe) checks for semaphores
            - Blocks until BOTH semaphore files exist
            - Only then marks container as "Started"
            - Kubernetes won't route traffic until this succeeds
```

**Por qué este patrón es seguro:**

1. **Cassandra debe ejecutarse primero**: el script de inicialización necesita acceso CQL, así que Cassandra tiene que estar en marcha
2. **Ejecución en segundo plano**: la inicialización no bloquea el arranque de Cassandra
3. **Coordinación por semáforos**: la comprobación de salud espera a que la inicialización termine antes de dar el contenedor por listo
4. **Aplicación por Kubernetes**: el pod no se marca «Started» hasta que existen los semáforos
5. **Semáforos persistentes**: se guardan en `/var/lib/cassandra` (volumen), lo que evita reinicializar en los reinicios

#### Fase 1: conversión de los keyspaces de sistema

La primera fase convierte los keyspaces de sistema de `SimpleStrategy` a
`NetworkTopologyStrategy`, para que estén listos para producción.

**Qué hace:**
1. Espera a que Cassandra esté lista (puerto CQL escuchando, transporte nativo activo)
2. Verifica que se trata de un clúster de un solo nodo con las credenciales por defecto
3. Detecta el nombre del datacenter de la instancia de Cassandra en marcha
4. Convierte `system_auth`, `system_distributed` y `system_traces` a `NetworkTopologyStrategy`
5. Escribe el semáforo de finalización en el almacenamiento persistente: `/var/lib/cassandra/.axonops/init-system-keyspaces.done`

**Nota:** NO se ejecuta ninguna reparación, porque este es un despliegue de un
solo nodo (la reparación sólo tiene sentido con varias réplicas).

**Comprobaciones de seguridad:**
- Sólo se ejecuta en clústeres de un solo nodo (se salta los de varios nodos y escribe un semáforo de omisión)
- Sólo se ejecuta si el factor de replicación es 1 (se salta si ya se personalizó y escribe un semáforo de omisión)
- Sólo se ejecuta si se usa `SimpleStrategy` (se salta si ya es `NetworkTopologyStrategy` y escribe un semáforo de omisión)
- Requiere las credenciales por defecto `cassandra/cassandra`
- **El semáforo se escribe SIEMPRE** (con éxito, o omitido con su motivo)

#### Fase 2: creación de un usuario de base de datos propio (opcional)

La segunda fase crea un superusuario propio y desactiva el usuario `cassandra`
por defecto (sólo si se pide mediante las variables de entorno).

**Qué hace:**
1. Espera a que termine la inicialización de los keyspaces de sistema
2. Crea el nuevo superusuario con el nombre y la contraseña indicados
3. Le concede permisos completos de superusuario
4. Prueba la autenticación con el nuevo usuario
5. Desactiva el usuario `cassandra` por defecto (le pone `can_login=false`)
6. Escribe el semáforo de finalización: `/var/lib/cassandra/.axonops/init-db-user.done`

**Ejemplo:**
```bash
docker run -d --name axondb \
  -e AXONOPS_DB_USER=dbadmin \
  -e AXONOPS_DB_PASSWORD=MySecurePassword123! \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=true \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0

# Wait for initialization (~2 minutes)
docker logs -f axondb

# Connect with new credentials
docker exec -it axondb cqlai -u dbadmin -p MySecurePassword123!
```

**Comprobaciones de seguridad:**
- Sólo se ejecuta si están definidas tanto `AXONOPS_DB_USER` como `AXONOPS_DB_PASSWORD`
- Sólo se ejecuta en clústeres recién creados con las credenciales por defecto
- Prueba la autenticación del nuevo usuario antes de desactivar el usuario por defecto
- Deshace la creación del usuario si la prueba de autenticación falla
- **El semáforo se escribe SIEMPRE** (con éxito, omitido o fallido, con su motivo)

#### Control y desactivación

**Desactivar toda la inicialización:**
```bash
docker run -d --name axondb \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

Cuando está desactivada, los ficheros semáforo se escriben de inmediato con
`RESULT=skipped`, para que la comprobación de salud pueda seguir adelante.

#### Ficheros semáforo

El proceso de inicialización usa ficheros semáforo para coordinarse entre el
script de inicialización en segundo plano y la sonda de arranque de la
comprobación de salud.

**Ubicación:** `/var/lib/cassandra/.axonops/`

Los ficheros semáforo se guardan en el directorio de datos de Cassandra (no en
`/etc`) porque:
- `/var/lib/cassandra` suele configurarse como volumen persistente en Kubernetes
- Al ser persistentes, los semáforos sobreviven a los reinicios de contenedor o de pod
- Evita reinicializar en los reinicios de pod (por ejemplo, durante una actualización progresiva)
- Permite que la comprobación de salud pase de inmediato tras un reinicio, sin volver a ejecutar la inicialización

**Importante:** configure `/var/lib/cassandra` como volumen persistente
(PersistentVolumeClaim) en su despliegue de Kubernetes. Los charts de Helm de
AxonOps lo hacen automáticamente.

**Ficheros creados:**
- `init-system-keyspaces.done`: el estado de la conversión de los keyspaces de sistema
- `init-db-user.done`: el estado de la creación del usuario propio

**Formato del fichero:**
```
COMPLETED=2025-12-14T09:32:17Z
RESULT=success
REASON=initialized_to_nts
```

**Valores de RESULT en init-system-keyspaces.done:**
- `success`: los keyspaces de sistema se convirtieron correctamente
  - `initialized_to_nts`: convertidos a NetworkTopologyStrategy
- `skipped`: la conversión se omitió de forma segura (con REASON explicando por qué)
  - `multi_node_cluster`: se detectó un clúster de varios nodos (no se puede inicializar con seguridad)
  - `already_nts`: ya usa NetworkTopologyStrategy (ya estaba hecho)
  - `custom_rf`: el factor de replicación no es 1 (el usuario ya lo personalizó)
  - `disabled_by_env_var`: INIT_SYSTEM_KEYSPACES_AND_ROLES=false (el usuario lo desactivó)
- `failed`: la inicialización falló (con REASON). **El script de inicialización termina con código 1**
  - `cql_port_timeout`: el puerto CQL no se abrió dentro del timeout (por defecto: 10 min, configurable con `INIT_TIMEOUT`)
  - `native_transport_timeout`: el transporte nativo no se activó dentro del timeout
  - `cql_connectivity_failed`: no se puede conectar con las credenciales cassandra/cassandra
  - `dc_detection_failed`: no se pudo detectar el nombre del datacenter con nodetool ni en cassandra-rackdc.properties

**Cuándo se producen los fallos:**
- `cql_port_timeout` / `native_transport_timeout`: Cassandra no arranca correctamente (revise los registros)
- `cql_connectivity_failed`: se cambiaron las credenciales por defecto o la autenticación está mal configurada
- `dc_detection_failed`: Cassandra no informa del nombre del datacenter (problema de configuración)

**Configuración del timeout:**
- Timeout por defecto: 600 segundos (10 minutos)
- Configurable con la variable de entorno `INIT_TIMEOUT`
- Ejemplo: `-e INIT_TIMEOUT=1200` para 20 minutos, si Cassandra arranca lento

**Valores de RESULT en init-db-user.done:**
- `success`: el usuario propio se creó correctamente
  - `user_initialized`: usuario creado y usuario cassandra desactivado
  - `user_created_cassandra_disable_failed`: usuario creado, pero no se pudo desactivar el usuario cassandra (no es fatal, el contenedor continúa)
- `skipped`: la creación del usuario se omitió (con REASON)
  - `no_custom_user_requested`: AXONOPS_DB_USER no está definida
  - `user_already_exists`: el usuario propio ya existe
  - `init_disabled`: INIT_SYSTEM_KEYSPACES_AND_ROLES=false
- `failed`: la creación del usuario falló (con REASON). **El script de inicialización termina con código 1**
  - `create_user_failed`: no se pudo crear el usuario (falló el CREATE ROLE de CQL)
  - `new_user_auth_failed`: el usuario se creó, pero la prueba de autenticación falló

**Cuándo se producen los fallos:**
- `create_user_failed` puede darse si:
  - Falla la conexión CQL durante la creación del usuario
  - El formato del nombre de usuario o de la contraseña es inválido
  - Hay un error interno de Cassandra al crear el rol
- `new_user_auth_failed` puede darse si:
  - El usuario se creó, pero el sistema de autenticación está mal configurado
  - La contraseña no se guardó correctamente en system_auth
  - Hay un problema del protocolo de autenticación de CQL

**Importante:** cuando se escribe `RESULT=failed`, el script de inicialización
termina con código 1 (fallo), y la sonda de arranque de la comprobación de salud
falla, lo que impide que el contenedor se marque «Started» en Kubernetes.

**Garantía:** ambos ficheros semáforo se escriben **SIEMPRE**, en todas las
ramas de ejecución. La sonda de arranque de la comprobación de salud:
1. Exige que existan los dos ficheros semáforo
2. Comprueba el campo RESULT de cada uno
3. **Hace fallar la sonda de arranque si alguno tiene RESULT=failed**
4. Sólo pasa si ambos son RESULT=success o RESULT=skipped

Así se garantiza que el contenedor no se marque «Started» si la inicialización
falló.

#### Registros de la inicialización

Consulte el progreso y los resultados de la inicialización:

```bash
# View complete initialization log (both system keyspaces and user creation)
docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log

# Check system keyspace conversion status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-system-keyspaces.done

# Check custom user creation status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-db-user.done
```

## Pipeline de CI/CD

### Workflows

El repositorio incluye workflows completos de GitHub Actions:

**Build y pruebas** (`.github/workflows/axondb-timeseries-build-and-test.yml`)
- **Disparadores:** push o PR a las ramas main, development, feature/* y fix/*
  - Cuando cambia `axonops/axondb-timeseries/**` (excluyendo los ficheros `*.md`)
  - Cuando cambian los workflows (`.github/workflows/axondb-timeseries-*.yml`)
  - Cuando cambian las actions (`.github/actions/axondb-timeseries-*/**`)
- **Pruebas:** build de Docker, verificación de versión, comprobación de salud, cqlai, cqlsh y escaneo de seguridad
- **Duración:** unos 10 minutos

**Publicación de producción** (`.github/workflows/axondb-timeseries-publish-signed.yml`)
- **Disparador:** ejecución manual del workflow con una etiqueta de git
- **Proceso:** validar → probar → crear la release → construir → firmar → publicar → verificar
- **Registro:** `ghcr.io/axonops/axondb-timeseries`
- **Plataformas:** linux/amd64, linux/arm64
- **Firma:** firma sin claves con Cosign (OIDC)

**Publicación de desarrollo** (`.github/workflows/axondb-timeseries-development-publish-signed.yml`)
- **Disparador:** ejecución manual del workflow desde la rama development
- **Registro:** `ghcr.io/axonops/development/axondb-timeseries`
- **Uso:** probar imágenes antes de una release de producción

### Pruebas automatizadas

El pipeline de CI incluye pruebas exhaustivas:

**Pruebas funcionales:**
- Verificación del build del contenedor (multiarquitectura)
- Verificación del banner de arranque (producción frente a desarrollo)
- Verificación de versiones (jemalloc, Cassandra, Java, cqlai)
- Pruebas del script de comprobación de salud (startup, liveness, readiness)
- Verificación de la inicialización de los keyspaces de sistema
- Operaciones CQL con cqlai
- Operaciones CQL con cqlsh
- Tratamiento de las variables de entorno

**Pruebas de seguridad:**
- Escaneo de vulnerabilidades del contenedor con Trivy (severidad CRITICAL y HIGH)
- Los resultados se suben a la pestaña Security de GitHub
- Los CVE upstream conocidos se documentan en `.trivyignore`

**Acciones compuestas (14 acciones):**
En `.github/actions/axondb-timeseries-*/`:
- `start-and-wait`: arranca el contenedor y espera a que esté listo
- `verify-startup-banner`: verifica el contenido del banner
- `verify-no-startup-errors`: busca errores de arranque
- `verify-versions`: verifica las versiones de los componentes
- `test-healthcheck`: prueba todos los modos de comprobación de salud
- `verify-init-scripts`: verifica que la inicialización terminó
- `test-cqlai`: prueba el funcionamiento de cqlai
- `test-cqlsh`: prueba el funcionamiento de cqlsh
- `test-all-env-vars`: prueba la configuración por variables de entorno (10 de Cassandra + 4 de inicialización = 14 en total)
- `test-dc-detection`: prueba la detección del datacenter
- `sign-container`: firma con Cosign
- `verify-published-image`: verificación tras la publicación
- `collect-logs`: recoge los registros del contenedor
- `determine-latest`: determina las etiquetas latest

### Proceso de publicación

**Release de desarrollo:**
```bash
# Tag on development branch
git checkout development
git tag vdev-axondb-timeseries-1.0.0
git push origin vdev-axondb-timeseries-1.0.0

# Publish to development registry
gh workflow run axondb-timeseries-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=vdev-axondb-timeseries-1.0.0 \
  -f container_version=1.0.0
```

**Release de producción:**
```bash
# Tag on main branch
git checkout main
git tag axondb-timeseries-1.0.0
git push origin axondb-timeseries-1.0.0

# Publish to production registry
gh workflow run axondb-timeseries-publish-signed.yml \
  --ref main \
  -f main_git_tag=axondb-timeseries-1.0.0 \
  -f container_version=1.0.0
```

Véase [RELEASE.md](./RELEASE.md) para la documentación completa del proceso de
release.

## Resolución de problemas

### Comprobar la versión del contenedor

Consulte el banner de arranque para ver todas las versiones de los componentes:

```bash
docker logs axondb | head -30
```

El banner muestra:
- La versión del contenedor y la revisión de git
- Las versiones de Cassandra, Java, cqlai y jemalloc
- El digest de la imagen base (para verificar la cadena de suministro)
- Los detalles del entorno de ejecución

### Registros del script de inicialización

Consulte el progreso y los resultados de la inicialización:

```bash
# View init script output
docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log

# Check system keyspace init status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-system-keyspaces.done

# Check custom user creation status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-db-user.done
```

**Formato del fichero semáforo:**
```
COMPLETED=2025-12-13T10:45:00Z
RESULT=success
```

Valores posibles de `RESULT`:
- `success`: la operación terminó correctamente
- `skipped`: la operación se omitió (con un campo REASON explicando por qué)

### Depurar la comprobación de salud

Pruebe las sondas de salud a mano:

```bash
# Test all three probe types
docker exec axondb /usr/local/bin/healthcheck.sh startup
docker exec axondb /usr/local/bin/healthcheck.sh liveness
docker exec axondb /usr/local/bin/healthcheck.sh readiness

# Check Docker healthcheck status
docker inspect axondb --format='{{json .State.Health}}' | jq

# View healthcheck logs
docker exec axondb cat /var/log/cassandra/system.log | grep healthcheck
```

### El contenedor no arranca

**Revise los registros:**
```bash
docker logs axondb
```

**Problemas habituales:**

1. **Memoria insuficiente:**
   - El heap por defecto es de 8G; asegúrese de que el contenedor tiene al menos 12 GB de RAM
   - Ajústelo con: `-e CASSANDRA_HEAP_SIZE=4G`

2. **Conflictos de puertos:**
   - CQL: 9042
   - JMX: 7199
   - Compruébelo con: `netstat -tuln | grep 9042`

3. **Problemas de permisos:**
   - El contenedor se ejecuta como el usuario `cassandra` (UID 999)
   - Asegure los permisos del volumen: `chown -R 999:999 /data/cassandra`

4. **Timeout de la inicialización:**
   - Los scripts de inicialización esperan hasta 10 minutos a Cassandra
   - Revise: `docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log`

**Consultar los registros de Cassandra:**
```bash
docker exec axondb cat /var/log/cassandra/system.log
```

**Verificar que Cassandra está en marcha:**
```bash
docker exec axondb nodetool status
```

## Consideraciones para producción

1. **Almacenamiento persistente**
   - Use siempre volúmenes para `/var/lib/cassandra` (datos)
   - Use volúmenes para `/var/log/cassandra` (registros)
   - Ejemplo: `-v /data/cassandra:/var/lib/cassandra`

2. **Asignación de recursos**
   - Memoria: al menos 1,5 veces el tamaño del heap (por ejemplo, 12 GB para un heap de 8 GB)
   - CPU: se recomiendan 4 o más núcleos
   - Disco: almacenamiento SSD para cargas de producción

3. **Red**
   - Exponga los puertos necesarios: 9042 (CQL), 7199 (JMX), 7000 (entre nodos)
   - Use reglas de cortafuegos adecuadas
   - Valore usar TLS para la comunicación entre nodos y con los clientes

4. **Seguridad**
   - Use un usuario de base de datos propio (defina `AXONOPS_DB_USER` y `AXONOPS_DB_PASSWORD`)
   - Verifique las firmas de los contenedores con Cosign
   - Use referencias de imagen basadas en digest, por inmutabilidad
   - Mantenga las imágenes base actualizadas (automatizado en UBI)

5. **Monitorización**
   - Use las sondas de salud para monitorizar la disponibilidad
   - Vigile el uso del heap por JMX
   - Configure la agregación de registros de `/var/log/cassandra/`
   - Valore integrarlo con AxonOps para una monitorización completa

6. **Copia de seguridad y restauración**

   Este contenedor incluye funcionalidad integrada de copia de seguridad y
   restauración, pensada para despliegues de un solo nodo.

   **Inicio rápido:**
   ```bash
   # Enable scheduled backups (every 6 hours, keep 168 hours / 7 days)
   docker run -d \
     -v /backup:/backup \
     -e BACKUP_SCHEDULE="0 */6 * * *" \
     -e BACKUP_RETENTION_HOURS=168 \
     axondb-timeseries:latest

   # Restore from backup
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     axondb-timeseries:latest
   ```

   **Prestaciones clave:**
   - Copias basadas en snapshots con deduplicación por enlaces duros (76 % de ahorro de espacio)
   - Compatible con Kubernetes (restauración sin bloqueo, segura con la sonda de arranque)
   - Retención automática con borrado asíncrono
   - Conservación de los semáforos `.axonops` (evita reinicializar al restaurar)
   - Tratamiento de los cambios de dirección IP
   - Rotación de registros con compresión

   **Configuración:**

   | Variable | Obligatoria | Valor por defecto | Descripción |
   |----------|----------|---------|-------------|
   | `BACKUP_SCHEDULE` | No | - | Expresión cron (por ejemplo, `0 */6 * * *` para cada 6 horas) |
   | `BACKUP_RETENTION_HOURS` | Si hay schedule | - | Horas que se conservan las copias (por ejemplo, `168` para 7 días) |
   | `BACKUP_MINIMUM_RETENTION_COUNT` | No | `1` | Conserva siempre al menos N copias |
   | `BACKUP_USE_HARDLINKS` | No | `true` | Usa deduplicación por enlaces duros |
   | `BACKUP_CALCULATE_STATS` | No | `false` | Calcula el ahorro de espacio (costoso) |
   | `BACKUP_RSYNC_RETRIES` | No | `3` | Número de reintentos de rsync |
   | `BACKUP_RSYNC_TIMEOUT_MINUTES` | No | `120` | Timeout de rsync (conjuntos de datos grandes) |
   | `RESTORE_FROM_BACKUP` | No | - | El nombre de la copia, o `latest` |
   | `RESTORE_ENABLED` | No | `false` | Activa la restauración sin indicar el nombre de la copia |
   | `RESTORE_RESET_CREDENTIALS` | No | `false` | Borra system_auth al restaurar (vuelve a cassandra/cassandra) |
   | `RSYNC_BWLIMIT_KB` | No | - | Límite de ancho de banda de las copias, en KB/s |
   | `ENABLE_SEMAPHORE_MONITOR` | No | `false` | Vigila el estado de copia y restauración |

   **Ejemplo para Kubernetes:**
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: axondb
   spec:
     containers:
     - name: cassandra
       image: axondb-timeseries:latest
       env:
       - name: BACKUP_SCHEDULE
         value: "0 */6 * * *"
       - name: BACKUP_RETENTION_HOURS
         value: "168"
       volumeMounts:
       - name: data
         mountPath: /var/lib/cassandra
       - name: backup
         mountPath: /backup
     volumes:
     - name: data
       persistentVolumeClaim:
         claimName: cassandra-data
     - name: backup
       persistentVolumeClaim:
         claimName: cassandra-backup
   ```

   **Restaurar desde una copia (recreación del pod):**
   ```yaml
   # After pod deletion, restore from backup on new pod
   env:
   - name: RESTORE_FROM_BACKUP
     value: "latest"  # or specific: "backup-20251226-120000"
   ```

   **Notas importantes:**
   - **Sólo un nodo**: las copias están pensadas para clústeres de un solo nodo
   - **Los enlaces duros son locales**: al copiar las copias a almacenamiento remoto (S3, NFS), los enlaces duros pasan a ser ficheros independientes (copia completa)
   - **Conservación de `.axonops`**: los semáforos de inicialización se copian y se restauran, para evitar reinicializar
   - **Restauración sin bloqueo**: la restauración corre en segundo plano y el contenedor arranca con normalidad (compatible con Kubernetes)
   - **Credenciales conservadas**: las credenciales propias de la copia se restauran automáticamente (salvo con `RESTORE_RESET_CREDENTIALS=true`)
   - **Reinicio de credenciales** (`RESTORE_RESET_CREDENTIALS=true`): borra todos los usuarios y roles de la copia
     - Vuelve a cassandra/cassandra (el usuario propio se crea automáticamente si se define AXONOPS_DB_USER)
     - Se pierden todos los permisos y concesiones de la copia
     - Úselo en restauraciones de producción a desarrollo, donde interesa reiniciar las credenciales

   **Ubicación de las copias:**
   - Monte el volumen `/backup` para que persistan
   - Las copias se guardan como: `/backup/data_backup-YYYYMMDD-HHMMSS/`
   - Incluyen un volcado del esquema (`schema.cql`) y los snapshots de datos

   **Ejemplos de restauración:**
   ```bash
   # Restore latest backup
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="latest" \
     axondb-timeseries:latest

   # Restore specific backup
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     axondb-timeseries:latest

   # List available backups
   ls -1dt /backup/data_backup-* | head -10

   # Restore with credential reset (prod → dev)
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     -e RESTORE_RESET_CREDENTIALS=true \
     axondb-timeseries:latest
   # After restore: credentials are cassandra/cassandra

   # Restore with credential reset + new custom user
   docker run -d \
     -v /backup:/backup \
     -e RESTORE_FROM_BACKUP="backup-20251226-120000" \
     -e RESTORE_RESET_CREDENTIALS=true \
     -e AXONOPS_DB_USER=devuser \
     -e AXONOPS_DB_PASSWORD=devpass123 \
     axondb-timeseries:latest
   # After restore: credentials are devuser/devpass123 (auto-created)
   ```

   **Vigilar las copias:**
   ```bash
   # Enable semaphore monitor (logs backup/restore state every 60s)
   docker run -d \
     -e BACKUP_SCHEDULE="0 */6 * * *" \
     -e BACKUP_RETENTION_HOURS=168 \
     -e ENABLE_SEMAPHORE_MONITOR=true \
     axondb-timeseries:latest

   # Check backup logs
   docker exec axondb cat /var/log/cassandra/backup-cron.log
   docker exec axondb cat /var/log/cassandra/retention-cleanup.log

   # Check restore logs
   docker exec axondb cat /var/log/cassandra/restore.log
   ```

   **Resolución de problemas:**

   | Problema | Qué revisar | Solución |
   |-------|-------|----------|
   | No se crean copias | `cat /var/log/cassandra/backup-scheduler.log` | Compruebe que BACKUP_SCHEDULE es un cron válido |
   | La retención no funciona | `cat /var/log/cassandra/retention-cleanup.log` | Compruebe que BACKUP_RETENTION_HOURS está definida |
   | La restauración falla | `cat /var/log/cassandra/restore.log` | Compruebe que la copia existe: `ls /backup/data_backup-*` |
   | La inicialización se ejecuta al restaurar | `cat /var/lib/cassandra/.axonops/init-*.done` | Compruebe que `.axonops` está en la copia |
   | Errores de bloqueo | `cat /tmp/axonops-backup.lock` | Espere a que termine la copia anterior |

   Para las pruebas detalladas, véase [tests/README.md](./5.0.6/tests/README.md).

7. **Despliegue en clúster**
   - Use valores consistentes de `CASSANDRA_DC` y `CASSANDRA_RACK` en todos los nodos
   - Configure `CASSANDRA_SEEDS` con varios nodos seed
   - Defina `CASSANDRA_CLUSTER_NAME` de forma consistente
   - Planifique los despliegues multidatacenter si los necesita

Para el flujo de trabajo de desarrollo y las pruebas, véase
[DEVELOPMENT.md](./DEVELOPMENT.md).

Para el proceso de release, véase [RELEASE.md](./RELEASE.md).
