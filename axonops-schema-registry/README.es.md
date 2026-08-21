# AxonOps Schema Registry

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

[![Paquete GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axonops-schema-registry)

Schema Registry de Kafka compatible con Confluent y listo para producción, con
soporte de varios backends de almacenamiento, construido sobre Red Hat UBI 9.

## Índice

- [Visión general](#visión-general)
- [Imágenes de Docker precompiladas](#imágenes-de-docker-precompiladas)
  - [Imágenes disponibles](#imágenes-disponibles)
  - [Estrategia de etiquetado](#estrategia-de-etiquetado)
- [Buena práctica en producción](#buena-práctica-en-producción)
- [Construir las imágenes de Docker](#construir-las-imágenes-de-docker)
- [Variables de entorno](#variables-de-entorno)
- [Prestaciones del contenedor](#prestaciones-del-contenedor)
  - [Script de entrypoint](#script-de-entrypoint)
  - [Banner de versión al arrancar](#banner-de-versión-al-arrancar)
  - [Sondas de salud](#sondas-de-salud)
- [Pipeline de CI/CD](#pipeline-de-cicd)
  - [Workflows](#workflows)
  - [Pruebas automatizadas](#pruebas-automatizadas)
  - [Proceso de publicación](#proceso-de-publicación)
- [Resolución de problemas](#resolución-de-problemas)
  - [Comprobar la versión del contenedor](#comprobar-la-versión-del-contenedor)
  - [Depurar la comprobación de salud](#depurar-la-comprobación-de-salud)
  - [El contenedor no arranca](#el-contenedor-no-arranca)
- [Consideraciones para producción](#consideraciones-para-producción)

## Visión general

AxonOps Schema Registry es un Schema Registry de Kafka compatible con Confluent
que ofrece gestión de esquemas con soporte de varios backends de almacenamiento.
Es un único binario de Go sin estado que expone una API REST en el puerto 8081.

**Prestaciones del contenedor:**
- **Almacenamiento multibackend**: PostgreSQL, MySQL, Cassandra 5+ y almacenamiento en memoria
- **Compatible con la API de Confluent**: sustituto directo del Schema Registry de Confluent
- **Base empresarial**: construido sobre Red Hat UBI 9 minimal, para estabilidad en producción
- **Seguridad de la cadena de suministro**: imágenes base fijadas por digest, para builds inmutables
- **Monitorización de producción**: sondas de salud integradas (startup, liveness, readiness)
- **Ligero**: un único binario de Go, con una huella de memoria de unos 50 MB

**Endpoints de la API:**
- Comprobación de salud: `GET /`
- Documentación Swagger: `GET /docs`
- API del Schema Registry: puerto 8081

## Imágenes de Docker precompiladas

Hay imágenes precompiladas disponibles en GitHub Container Registry (GHCR). Es la
forma más sencilla de empezar.

### Imágenes disponibles

Todas las imágenes están en: `ghcr.io/axonops/axonops-schema-registry`

Consulte todas las etiquetas disponibles:
[GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axonops-schema-registry)

### Estrategia de etiquetado

Las imágenes usan una estrategia de etiquetado multidimensional con dos ejes
independientes:

- **SR_VERSION**: la versión de la aplicación Schema Registry (por ejemplo, `0.2.0`)
- **CONTAINER_VERSION**: la versión del contenedor (semver, por ejemplo, `0.0.1`, `0.0.2`, `0.1.0`)

| Patrón de etiqueta | Ejemplo | Descripción | Caso de uso |
|-------------|---------|-------------|----------|
| `{SR_VERSION}-{CONTAINER_VERSION}` | `0.2.0-0.0.1` | Totalmente inmutable (versión de SR + versión de contenedor) | **Producción**: fije versiones exactas para una auditabilidad completa |
| `@sha256:<digest>` | `@sha256:abc123...` | Basada en digest (criptográficamente inmutable) | **Máxima seguridad**: integridad de la imagen garantizada |
| `{SR_VERSION}` | `0.2.0` | La última versión de contenedor de esa versión de SR | Seguir las actualizaciones de contenedor de una versión de SR concreta |
| `latest` | `latest` | La última de todas las versiones | Sólo para pruebas rápidas (NO para producción) |

**Ejemplos de etiquetado:**

Cuando se construye `0.2.0-0.0.1` (y es la más reciente):
- `0.2.0-0.0.1` (inmutable: no cambia nunca)
- `0.2.0` (flotante: se reetiqueta a versiones de contenedor más nuevas de la misma versión de SR)
- `latest` (flotante: se mueve a versiones de SR más nuevas)

Cuando se construye `0.2.0-0.0.2` (sólo sube el contenedor, misma versión de SR):
- `0.2.0-0.0.2` (inmutable: no cambia nunca)
- `0.2.0` (flotante: ahora apunta a la versión de contenedor 0.0.2)
- `latest` (flotante: ahora apunta a la versión de contenedor 0.0.2)

Cuando se construye `0.3.0-0.0.1` (nueva versión de SR, la de contenedor vuelve a 0.0.1):
- `0.3.0-0.0.1` (inmutable: no cambia nunca)
- `0.3.0` (flotante: la última versión de contenedor de 0.3.0)
- `latest` (flotante: ahora apunta a 0.3.0-0.0.1)

## Buena práctica en producción

**Usar `latest` o etiquetas flotantes en producción es un antipatrón.** Esto
incluye `latest` y `0.2.0`, porque:
- **No hay rastro de auditoría**: no se puede determinar qué versión exacta estaba desplegada en un momento dado
- **Actualizaciones inesperadas**: los orquestadores de contenedores pueden descargar imágenes nuevas al reiniciar
- **Dificultades para volver atrás**: no se puede retroceder de forma fiable a versiones anteriores
- **Problemas de cumplimiento**: muchos marcos normativos exigen un seguimiento de versiones inmutable

**Estrategias de despliegue recomendadas (de mayor a menor seguridad):**

1. **Referencia de oro: basada en digest** (máxima seguridad)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry@sha256:abc123...
   ```
   - 100 % inmutable, garantizado criptográficamente
   - Obligatoria en entornos regulados
   - Verifique la firma con Cosign (véase más abajo)

2. **Etiqueta inmutable** (el estándar de producción)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
   ```
   - Fijada a una versión concreta (SR 0.2.0, contenedor 0.0.1)
   - Fácil de leer y de gestionar
   - Mantiene un rastro de auditoría completo

3. **Etiquetas flotantes** (sólo desarrollo y pruebas)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry:latest
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
  ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1

# Check signature exists
cosign tree ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
```

## Construir las imágenes de Docker

Si prefiere construir las imágenes usted mismo en lugar de usar las
precompiladas:

```bash
cd axonops-schema-registry

# Minimal build (required args only)
docker build \
  -t axonops-schema-registry:0.2.0-0.0.1 \
  .

# Multi-arch build (amd64 + arm64) using buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t axonops-schema-registry:0.2.0-0.0.1 \
  .
```

**Argumentos de build opcionales (mejoran los metadatos, pero no son
obligatorios):**
- `SR_VERSION`: la versión del Schema Registry (por defecto: `0.2.0`)
- `BUILD_DATE`: la marca de tiempo del build (formato ISO 8601, por ejemplo, `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF`: el SHA del commit de git (por ejemplo, `$(git rev-parse HEAD)`)
- `VERSION`: la cadena de versión completa (por ejemplo, `0.2.0-0.0.1`)
- `CONTAINER_VERSION`: la versión del contenedor (por ejemplo, `0.0.1`)
- `GIT_TAG`: el nombre de la etiqueta de git (para los enlaces de release/tag del banner)
- `GITHUB_ACTOR`: el usuario que lanzó el build (para el rastro de auditoría)
- `IS_PRODUCTION_RELEASE`: póngalo a `true` para producción (por defecto: `false`)
- `IMAGE_FULL_NAME`: el nombre completo de la imagen con la etiqueta (se muestra en el banner de arranque)

**Seguridad de la cadena de suministro:**

Nuestro Dockerfile usa imágenes base fijadas por digest, por seguridad de la
cadena de suministro:

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
ARG UBI9_MINIMAL_DIGEST=sha256:1bc3c5c15720506a0cf48adfdf8b623dfe704377e007d7bbae8d14876392ca6a
FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
```

## Variables de entorno

El Schema Registry se configura principalmente mediante su fichero de
configuración YAML (`/etc/axonops-schema-registry/config.yaml`). Puede
sobrescribirlo montando un fichero de configuración propio.

| Variable | Descripción | Valor por defecto |
|----------|-------------|---------|
| `SR_PORT` | El puerto de la API para el script de comprobación de salud | `8081` |
| `HEALTH_CHECK_TIMEOUT` | El timeout de la comprobación de salud, en segundos | `10` |

**Configuración propia:**

Monte un fichero de configuración propio para sustituir al de por defecto:

```bash
docker run -d --name schema-registry \
  -v /path/to/config.yaml:/etc/axonops-schema-registry/config.yaml:ro \
  -p 8081:8081 \
  ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
```

## Prestaciones del contenedor

### Script de entrypoint

El script de entrypoint (`/usr/local/bin/docker-entrypoint.sh`) muestra el banner
de arranque y luego ejecuta el proceso principal. Se ejecuta a través de
[tini](https://github.com/krallin/tini), para un manejo correcto de las señales y
la recogida de procesos zombis.

```dockerfile
ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["axonops-schema-registry", "--config", "/etc/axonops-schema-registry/config.yaml"]
```

Árbol de procesos:
```
tini (PID 1)
  └── docker-entrypoint.sh
       └── axonops-schema-registry (after exec)
```

### Banner de versión al arrancar

Todos los contenedores muestran al arrancar información de versión completa:

```
================================================================================
AxonOps Schema Registry 0.2.0
Image: ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
Built: 2025-12-13T10:30:00Z
Release: https://github.com/axonops/axonops-containers/releases/tag/axonops-schema-registry-0.2.0-0.0.1
Built by: GitHub Actions
================================================================================

Component Versions:
  Schema Registry:    0.2.0
  Binary Version:     v0.2.0
  Container Version:  0.0.1
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI)
  Platform:           x86_64

Supply Chain Security:
  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest
  Base image digest:  sha256:6fc28bcb6776e387...

Runtime Environment:
  Hostname:           schema-registry-1

================================================================================
Starting Schema Registry...
================================================================================
```

**Ver el banner:**
```bash
docker logs schema-registry | head -25
```

### Sondas de salud

El contenedor incluye un script de comprobación de salud que admite tres tipos de
sonda:

**1. Sonda de arranque** (`healthcheck.sh startup`)
- Comprueba que el proceso del Schema Registry está en ejecución (`pgrep`)
- Comprueba que el puerto de la API responde a peticiones HTTP
- Úsela para: el `startupProbe` de Kubernetes

**2. Sonda de vida** (`healthcheck.sh liveness`)
- Comprueba que el proceso del Schema Registry está en ejecución (`pgrep`)
- Ultraligera, se ejecuta a menudo
- Úsela para: el `livenessProbe` de Kubernetes

**3. Sonda de disponibilidad** (`healthcheck.sh readiness`)
- Comprobación HTTP completa contra el endpoint `GET /`
- Verifica una respuesta HTTP 200
- Úsela para: el `readinessProbe` de Kubernetes y el HEALTHCHECK de Docker

**Comprobación de salud de Docker:**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect schema-registry --format='{{json .State.Health}}' | jq
```

**Probar la comprobación de salud a mano:**
```bash
# Test startup probe
docker exec schema-registry /usr/local/bin/healthcheck.sh startup

# Test liveness probe
docker exec schema-registry /usr/local/bin/healthcheck.sh liveness

# Test readiness probe
docker exec schema-registry /usr/local/bin/healthcheck.sh readiness
```

## Pipeline de CI/CD

### Workflows

**Build y pruebas** (`.github/workflows/axonops-schema-registry-build-and-test.yml`)
- **Disparadores:** push o PR a las ramas main, development, feature/* y fix/*
  - Cuando cambia `axonops-schema-registry/**` (excluyendo los ficheros `*.md`)
  - Cuando cambian los workflows (`.github/workflows/axonops-schema-registry-*.yml`)
  - Cuando cambian las actions (`.github/actions/axonops-schema-registry-*/**`)
- **Pruebas:** build de Docker, verificación de versión, comprobación de salud, pruebas de la API y escaneo de seguridad
- **Duración:** unos 5 minutos

**Publicación de producción** (`.github/workflows/axonops-schema-registry-publish-signed.yml`)
- **Disparador:** ejecución manual del workflow con una etiqueta de git
- **Proceso:** validar -> probar -> crear la release -> construir -> firmar -> publicar -> verificar
- **Registro:** `ghcr.io/axonops/axonops-schema-registry`
- **Plataformas:** linux/amd64, linux/arm64
- **Firma:** firma sin claves con Cosign (OIDC)

**Publicación de desarrollo** (`.github/workflows/axonops-schema-registry-development-publish-signed.yml`)
- **Disparador:** ejecución manual del workflow desde la rama development
- **Registro:** `ghcr.io/axonops/development/axonops-schema-registry`
- **Uso:** probar imágenes antes de una release de producción

### Pruebas automatizadas

El pipeline de CI incluye:

**Pruebas funcionales:**
- Verificación del build del contenedor (multiarquitectura)
- Verificación del banner de arranque (producción frente a desarrollo)
- Verificación de versiones (versión de SR, versión de contenedor)
- Pruebas del script de comprobación de salud (startup, liveness, readiness)
- Pruebas de la API del Schema Registry (`GET /`)

**Pruebas de seguridad:**
- Escaneo de vulnerabilidades del contenedor con Trivy (severidad CRITICAL y HIGH)
- Los resultados se suben a la pestaña Security de GitHub
- Los CVE upstream conocidos se documentan en `.trivyignore`

### Proceso de publicación

**Release de desarrollo:**
```bash
# Tag on development branch
git checkout development
git pull origin development
git tag vdev-axonops-schema-registry-0.2.0-0.0.1
git push origin vdev-axonops-schema-registry-0.2.0-0.0.1

# Publish to development registry
gh workflow run axonops-schema-registry-development-publish-signed.yml \
  --ref development \
  -f dev_git_tag=vdev-axonops-schema-registry-0.2.0-0.0.1 \
  -f sr_version=0.2.0 \
  -f container_version=0.0.1
```

**Release de producción:**
```bash
# Tag on main branch
git checkout main
git pull origin main
git tag axonops-schema-registry-0.2.0-0.0.1
git push origin axonops-schema-registry-0.2.0-0.0.1

# Publish to production registry
gh workflow run axonops-schema-registry-publish-signed.yml \
  --ref main \
  -f main_git_tag=axonops-schema-registry-0.2.0-0.0.1 \
  -f sr_version=0.2.0 \
  -f container_version=0.0.1
```

Véase [RELEASE.md](./RELEASE.md) para la documentación completa del proceso de
release.

## Resolución de problemas

### Comprobar la versión del contenedor

Consulte el banner de arranque para ver todas las versiones de los componentes:

```bash
docker logs schema-registry | head -25
```

### Depurar la comprobación de salud

Pruebe las sondas de salud a mano:

```bash
# Test all three probe types
docker exec schema-registry /usr/local/bin/healthcheck.sh startup
docker exec schema-registry /usr/local/bin/healthcheck.sh liveness
docker exec schema-registry /usr/local/bin/healthcheck.sh readiness

# Check Docker healthcheck status
docker inspect schema-registry --format='{{json .State.Health}}' | jq

# Test API directly
curl -s http://localhost:8081/
```

### El contenedor no arranca

**Revise los registros:**
```bash
docker logs schema-registry
```

**Problemas habituales:**

1. **Conflictos de puertos:**
   - API del Schema Registry: 8081
   - Compruébelo con: `netstat -tuln | grep 8081`

2. **Problemas de permisos:**
   - El contenedor se ejecuta como el usuario `schemaregistry` (UID 999)
   - Asegure los permisos del volumen: `chown -R 999:999 /data/schema-registry`

3. **Problemas de configuración:**
   - Verifique el fichero de configuración: `docker exec schema-registry cat /etc/axonops-schema-registry/config.yaml`

## Consideraciones para producción

1. **Almacenamiento persistente**
   - Use volúmenes para `/var/lib/axonops-schema-registry` (datos)
   - Use volúmenes para `/var/log/axonops-schema-registry` (registros)

2. **Asignación de recursos**
   - Memoria: unos 50 MB de forma habitual, asigne 256 MB como mínimo
   - CPU: 1 núcleo basta para la mayoría de las cargas

3. **Red**
   - Exponga el puerto 8081 para la API del Schema Registry
   - Use reglas de cortafuegos adecuadas

4. **Seguridad**
   - Verifique las firmas de los contenedores con Cosign
   - Use referencias de imagen basadas en digest, por inmutabilidad
   - Mantenga las imágenes base actualizadas

5. **Monitorización**
   - Use las sondas de salud para monitorizar la disponibilidad
   - Vigile los tiempos de respuesta de la API con `GET /`
   - Configure la agregación de registros de `/var/log/axonops-schema-registry/`

6. **Alta disponibilidad**
   - El Schema Registry es sin estado cuando se usan backends de almacenamiento externos
   - Ejecute varias instancias tras un balanceador de carga para alta disponibilidad

Para el flujo de trabajo de desarrollo y las pruebas, véase
[DEVELOPMENT.md](./DEVELOPMENT.md).

Para el proceso de release, véase [RELEASE.md](./RELEASE.md).
