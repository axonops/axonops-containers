# Contenedores K8ssandra de AxonOps

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

[![Paquete GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra)

Contenedores Docker de Apache Cassandra con el agente de monitorización y gestión
de AxonOps integrado, pensados para desplegarse en Kubernetes con el operador
K8ssandra.

## Índice

- [Visión general](#visión-general)
- [Imágenes de Docker precompiladas](#imágenes-de-docker-precompiladas)
  - [Imágenes disponibles](#imágenes-disponibles)
  - [Versiones de Cassandra admitidas](#versiones-de-cassandra-admitidas)
- [Buena práctica en producción](#buena-práctica-en-producción)
- [Inicio rápido con Docker/Podman](#inicio-rápido-con-dockerpodman)
  - [Uso con Kubernetes (K8ssandra)](#uso-con-kubernetes-k8ssandra)
- [Requisitos previos](#requisitos-previos)
- [Líneas de Cassandra](#líneas-de-cassandra)
- [Primeros pasos](#primeros-pasos)
- [Construir las imágenes de Docker](#construir-las-imágenes-de-docker)
  - [Añadir soporte para nuevas versiones de Cassandra](#añadir-soporte-para-nuevas-versiones-de-cassandra)
  - [Actualizar para nuevas versiones de la Management API de k8ssandra](#actualizar-para-nuevas-versiones-de-la-management-api-de-k8ssandra)
- [Desplegar en Kubernetes](#desplegar-en-kubernetes)
  - [Usar la configuración de ejemplo](#usar-la-configuración-de-ejemplo)
  - [Verificar el despliegue](#verificar-el-despliegue)
  - [Conectarse al clúster](#conectarse-al-clúster)
  - [Opciones de configuración principales](#opciones-de-configuración-principales)
- [Configuración](#configuración)
  - [Configuración del agente de AxonOps](#configuración-del-agente-de-axonops)
  - [Variables de entorno del contenedor](#variables-de-entorno-del-contenedor)
  - [Comprobación de salud](#comprobación-de-salud)
- [Referencia de scripts](#referencia-de-scripts)
  - [scripts/install_k8ssandra.sh](#scriptsinstall_k8ssandrash)
  - [scripts/rebuild.sh](#scriptsrebuildsh)
- [Ejemplos](#ejemplos)
  - [examples/k8ssandra/cluster-axonops-ubi.yaml](#examplesk8ssandracluster-axonops-ubiyaml)
  - [Personalizar el ejemplo](#personalizar-el-ejemplo)
- [Pipeline de CI/CD](#pipeline-de-cicd)
  - [Builds y pruebas automatizados](#builds-y-pruebas-automatizados)
- [Prestaciones del contenedor](#prestaciones-del-contenedor)
  - [Banner de versión al arrancar](#banner-de-versión-al-arrancar)
- [Monitorización con AxonOps](#monitorización-con-axonops)
- [Resolución de problemas](#resolución-de-problemas)
  - [Comprobar la versión del contenedor](#comprobar-la-versión-del-contenedor)
  - [Problemas de conexión del agente](#problemas-de-conexión-del-agente)
  - [Errores al descargar la imagen](#errores-al-descargar-la-imagen)
  - [El clúster no arranca](#el-clúster-no-arranca)
- [Consideraciones para producción](#consideraciones-para-producción)

## Visión general

Este repositorio ofrece imágenes de Docker preconfiguradas que combinan:
- Apache Cassandra 5.0.x
- La Management API de K8ssandra
- El agente de AxonOps, para monitorización y gestión
- [cqlai](https://github.com/axonops/cqlai), una shell de CQL moderna

Estos contenedores están optimizados para despliegues en Kubernetes con el
operador K8ssandra e incluyen pipelines de CI/CD automatizados para construirlos y
publicarlos en GitHub Container Registry.

**Nota:** actualmente sólo se publican versiones de Cassandra 5.0. El soporte de
Cassandra 4.0 y 4.1 está en el repositorio, pero todavía no se publica por
problemas de compatibilidad del agente de AxonOps. Póngase en contacto con
nosotros si necesita soporte de 4.0 o 4.1.

## Imágenes de Docker precompiladas

Hay imágenes precompiladas disponibles en GitHub Container Registry (GHCR). Es la
forma más sencilla de empezar.

### Imágenes disponibles

Las imágenes usan una estrategia de etiquetado tridimensional que incluye el
seguimiento de la versión de la API de k8ssandra:

| Patrón de etiqueta | Ejemplo | Descripción | Caso de uso |
|-------------|---------|-------------|----------|
| `{CASS}-v{K8S_API}-{AXON}` | `5.0.6-v0.1.110-1.0.0` | Totalmente inmutable (las 3 versiones) | **Producción**: fije versiones exactas para una auditabilidad completa |
| `@sha256:<digest>` | `@sha256:412c852...` | Basada en digest (inmutable) | **Máxima seguridad**: imagen garantizada criptográficamente (véase [Despliegue con seguridad de referencia](../README.es.md#despliegue-con-seguridad-de-referencia)) |
| `{CASS}-v{K8S_API}` | `5.0.6-v0.1.110` | El último AxonOps para esa combinación de Cassandra + k8ssandra | Seguir las actualizaciones de AxonOps para unas versiones concretas de Cassandra + k8ssandra |
| `{CASS}` | `5.0.6` | La última API de k8ssandra + AxonOps para ese menor de Cassandra | Seguir las actualizaciones de k8ssandra + AxonOps de un menor de Cassandra |
| `{MAJOR}-latest` | `5.0-latest` | El último menor del mayor 5.0 de Cassandra | Seguir el último menor 5.0.x de Cassandra y sus componentes |
| `latest` | `latest` | La última de todos los mayores de Cassandra | Pruebas rápidas (migra a 5.1, 5.2 o 6.0 cuando se publiquen) |

**Dimensiones del versionado:**
- **CASS**: la versión de Cassandra (por ejemplo, 5.0.6)
- **K8S_API**: la versión de la Management API de k8ssandra (por ejemplo, v0.1.110)
- **AXON**: la versión del contenedor de AxonOps (por ejemplo, 1.0.0, en SemVer)

**Ejemplos de etiquetado:**

Cuando se construye `5.0.6-v0.1.110-1.0.0` (y es la última de todo):
- `5.0.6-v0.1.110-1.0.0` (inmutable: no cambia nunca)
- `5.0.6-v0.1.110` (flotante: se reetiqueta a builds de AxonOps más nuevos)
- `5.0.6` (flotante: se reetiqueta cuando se actualizan la API de k8ssandra o AxonOps)
- `5.0-latest` (flotante: se reetiqueta cuando se publica un menor 5.0.x más nuevo, por ejemplo 5.0.7)
- `latest` (flotante: **se mueve a 5.1, 5.2 o 6.0 cuando se publique un nuevo mayor de Cassandra**)

### Versiones de Cassandra admitidas

La lista de versiones vive en un único sitio: la sección `build_matrix` de
[`versions.yaml`](../versions.yaml), en la raíz del repositorio. Todas las
matrices de los workflows, las etiquetas flotantes y las versiones por defecto se
derivan de ahí, así que este README no puede quedar desincronizado con lo que se
construye de verdad. Lea la lista actual con:

```bash
./scripts/build-matrix.sh versions      # every published version
./scripts/build-matrix.sh newest        # what `latest` resolves to
```

**Publicadas actualmente:**
- **5.0.x:** 5.0.1, 5.0.2, 5.0.3, 5.0.4, 5.0.5, 5.0.6, 5.0.7 y 5.0.8 (8 versiones).
  La más reciente es 5.0.8, así que `latest` y `5.0-latest` resuelven a ella.

**Política de soporte.** Una release de parche de Cassandra se añade a la matriz
cuando se cumplen dos cosas: que Apache la haya publicado y que k8ssandra haya
publicado una imagen base `cass-management-api` correspondiente. Estas imágenes se
construyen `FROM` esa base, así que la segunda condición es estricta: una versión
añadida antes de tiempo hace fallar todos sus jobs de build con «No k8ssandra
version found». No se quita nada de la matriz cuando aparece un parche más nuevo;
los parches antiguos se siguen construyendo y escaneando, de modo que un
despliegue existente puede quedarse en su versión fijada y seguir recibiendo
reconstrucciones. Una línea sólo se retira cuando llega a su fin de vida upstream,
y eso se registra en `versions.yaml` con el motivo.

**No construidas:**
- **5.0.9:** publicada por Apache, pero k8ssandra no publica ninguna imagen
  `cass-management-api` para 5.0.9. Compruebe si ya ha aparecido con:

  ```bash
  curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=5.0.9-ubi" | \
    jq -r '.results[].name'
  ```

  Cuando aparezca, siga
  [Añadir soporte para nuevas versiones de Cassandra](#añadir-soporte-para-nuevas-versiones-de-cassandra).
- **4.0.x y 4.1.x:** los Dockerfiles se mantienen en `k8ssandra/4.0/` y
  `k8ssandra/4.1/`, pero no se publica ninguna imagen: el agente de AxonOps
  todavía no es compatible con las imágenes base de 4.x basadas en JDK 11. Ambas
  líneas están declaradas `published: false` en `versions.yaml` con ese motivo, y
  todos los workflows las saltan. Póngase en contacto con nosotros si las
  necesita.

Consulte todas las etiquetas disponibles:
[GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra)

## Buena práctica en producción

⚠️ **Usar CUALQUIER etiqueta `-latest` en producción es un antipatrón.** Esto
incluye `latest`, `5.0-latest` y `5.0.6-latest`, porque:
- **No hay rastro de auditoría**: no puede determinar qué versión exacta estaba desplegada en un momento dado
- **Actualizaciones inesperadas**: Kubernetes puede descargar una imagen nueva al reiniciar un pod, provocando cambios de versión no buscados
- **Dificultades para volver atrás**: no puede retroceder de forma fiable a una versión anterior
- **Problemas de cumplimiento**: muchos marcos normativos exigen un seguimiento de versiones inmutable

👍 **Estrategias de despliegue recomendadas (de mayor a menor seguridad):**

1. **🥇 Referencia de oro: basada en digest** (máxima seguridad)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra@sha256:412c852252ec4ebcb8d377a505881828a7f6a5f9dc725cc4f20fda2a1bcb3494"
   ```
   - 100 % inmutable, garantizado criptográficamente
   - Obligatoria en entornos regulados
   - Véase [Despliegue con seguridad de referencia](../README.es.md#despliegue-con-seguridad-de-referencia)

2. **🥈 Etiqueta inmutable** (el estándar de producción)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5"
   ```
   - Fijada a una versión concreta (Cassandra 5.0.6 + API de k8ssandra v0.1.110 + AxonOps 1.0.5)
   - Fácil de leer y de gestionar
   - Mantiene un rastro de auditoría completo

3. **🥉 Etiquetas latest** (sólo desarrollo y pruebas)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra:latest"
   ```
   - Iteración rápida
   - NO para producción
   - Úselas sólo para pruebas de concepto y pruebas

**Gestión de CVE:** véase la [política de CVE](../README.es.md#política-de-cve)
para saber cómo tratamos las vulnerabilidades de seguridad y las releases de
versión.

**Actualización de imágenes con K8ssandra:** cuando actualice la imagen de
contenedor en su manifiesto K8ssandraCluster, el operador K8ssandra se encarga del
proceso de actualización progresiva. Véase la
[documentación del operador K8ssandra](https://docs.k8ssandra.io/) para los
detalles de los procedimientos de actualización y las buenas prácticas.

## Inicio rápido con Docker/Podman

Ejecute una instancia de Cassandra de un solo nodo en local, para pruebas:

```bash
# Pull the latest 5.0 image (TESTING ONLY - not for production!)
# Note: 5.0-latest is a floating tag that points to the latest 5.0.x minor + components
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0-latest

# Run with AxonOps agent (replace with your credentials)
docker run -d --name cassandra \
  -e AXON_AGENT_KEY="your-axonops-agent-key" \
  -e AXON_AGENT_ORG="your-organization" \
  -e AXON_AGENT_SERVER_HOST="agents.axonops.cloud" \
  -p 9042:9042 \
  -p 8080:8080 \
  ghcr.io/axonops/k8ssandra/cassandra:5.0-latest

# Wait for Cassandra to be ready (check Management API)
curl http://localhost:8080/api/v0/probes/readiness

# Connect using cqlai (included in the image)
docker exec -it cassandra cqlai
```

**⚠️ Para uso en producción, fije una versión inmutable concreta:**
```bash
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

### Uso con Kubernetes (K8ssandra)

Para despliegues en Kubernetes, use la imagen con el operador K8ssandra:

```bash
export IMAGE_NAME="ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5"
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"

cat examples/k8ssandra/cluster-axonops-ubi.yaml | envsubst | kubectl apply -f -
```

Véase [Desplegar en Kubernetes](#desplegar-en-kubernetes) para las instrucciones
detalladas.

## Requisitos previos

- Un clúster de Kubernetes (local o en cloud)
- `kubectl` configurado para acceder a su clúster
- Helm 3.x
- Docker (para los builds locales)
- `envsubst` (para sustituir variables de entorno en los ficheros YAML)
  - macOS: `brew install gettext`
  - Linux: suele venir preinstalado, o `apt install gettext` / `yum install gettext`
- Una cuenta de AxonOps con una clave de API válida y un identificador de organización (véase la [guía de configuración de AxonOps Cloud](https://docs.axonops.com/get_started/cloud/))

## Líneas de Cassandra

Qué versiones se construyen, y la política detrás de eso, está en
[Versiones de Cassandra admitidas](#versiones-de-cassandra-admitidas), más arriba;
la lista no se repite aquí, porque la copia que solía estar en esta sección decía
de la 5.0.1 a la 5.0.6 mucho después de que se publicaran la 5.0.7 y la 5.0.8. Lo
que sigue es lo que diferencia unas líneas de otras.

| Línea | Imagen base | JDK | Directorio de build | Publicada |
|------|------------|-----|-----------------|-----------|
| 5.0 | `k8ssandra/cass-management-api:5.0-ubi` | 17 | `k8ssandra/5.0/` | Sí |
| 4.1 | `k8ssandra/cass-management-api:4.1-ubi` | 11 | `k8ssandra/4.1/` | No: compatibilidad del agente de AxonOps |
| 4.0 | `k8ssandra/cass-management-api:4.0-ubi` | 11 | `k8ssandra/4.0/` | No: compatibilidad del agente de AxonOps |

Todas las líneas incluyen el agente de AxonOps, cqlai y jemalloc. Las imágenes
base se fijan por digest, nunca por la etiqueta mostrada arriba: véase
[Seguridad de la cadena de suministro](#añadir-soporte-para-nuevas-versiones-de-cassandra).

## Primeros pasos

**Nota:** los comandos siguientes suponen que está en el directorio `k8ssandra/`,
salvo que se indique otra cosa.

### 1. Instalar el operador K8ssandra

Ejecute el script de instalación para preparar el operador K8ssandra y sus
dependencias:

```bash
./scripts/install_k8ssandra.sh
```

Este script:
- Instala cert-manager (v1.19.1) en el espacio de nombres `cert-manager`
- Añade el repositorio de Helm de K8ssandra
- Instala el operador K8ssandra (v1.29.0) en el espacio de nombres `k8ssandra-operator`

### 2. Configurar las variables de entorno

Defina sus credenciales de AxonOps:

```bash
export AXON_AGENT_KEY="your-axonops-agent-key" # Obtained from AxonOps Cloud Console
export AXON_AGENT_ORG="your-organization-id" # AxonOps Cloud organization name
export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"
```

Opcional: indique un nombre de imagen propio (por defecto usa ttl.sh con un TTL de
1 hora):

```bash
export IMAGE_NAME="your-registry/your-image:tag"
```

### 3. Construir y desplegar

Use el script de reconstrucción para construir, subir y desplegar su clúster:

```bash
# Change to the version directory (contains Dockerfile)
cd 5.0

# Run the rebuild script (builds from current directory)
../scripts/rebuild.sh
```

El script:
1. Elimina cualquier despliegue de clúster existente
2. Limpia las imágenes de contenedor antiguas
3. Construye una nueva imagen de Docker
4. Sube la imagen al registro
5. Aplica la configuración del clúster con sustitución de variables de entorno
6. Despliega el clúster en Kubernetes

## Construir las imágenes de Docker

**Nota:** los comandos de esta sección suponen que está en el directorio
`k8ssandra/`.

Si prefiere construir las imágenes usted mismo en lugar de usar las
[imágenes precompiladas](#imágenes-de-docker-precompiladas):

```bash
cd 5.0

# Minimal build (required args only)
docker build \
  --build-arg CASSANDRA_VERSION=5.0.6 \
  --build-arg MAJOR_VERSION=5.0 \
  --build-arg K8SSANDRA_BASE_DIGEST=sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af \
  --build-arg K8SSANDRA_API_VERSION=0.1.110 \
  --build-arg CQLAI_VERSION=0.1.4 \
  -t your-registry/axonops-cassandra:5.0.6-v0.1.110-1.0.0 \
  .

docker push your-registry/axonops-cassandra:5.0.6-v0.1.110-1.0.0
```

**Argumentos de build obligatorios:**
- `CASSANDRA_VERSION`: la versión completa de Cassandra (por ejemplo, 5.0.6)
- `MAJOR_VERSION`: la versión mayor.menor correspondiente al directorio (por ejemplo, 5.0)
- `K8SSANDRA_BASE_DIGEST`: el digest SHA256 de la imagen base de k8ssandra (seguridad de la cadena de suministro)
- `K8SSANDRA_API_VERSION`: la versión de la Management API de k8ssandra (por ejemplo, 0.1.110)
- `CQLAI_VERSION`: la versión de cqlai que instalar (véase la [última release](https://github.com/axonops/cqlai/releases))

**Argumentos de build opcionales (por defecto valen «unknown» si no se
proporcionan):**
- `BUILD_DATE`: la marca de tiempo del build (formato ISO 8601, por ejemplo, `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF`: el SHA del commit de git (por ejemplo, `$(git rev-parse HEAD)`)
- `VERSION`: la versión del contenedor (por ejemplo, 1.0.0)
- `GIT_TAG`: el nombre de la etiqueta de git (para los enlaces de release/tag del banner)
- `GITHUB_ACTOR`: el usuario que lanzó el build (para el rastro de auditoría)
- `IS_PRODUCTION_RELEASE`: póngalo a `true` para producción (por defecto: `false`)
- `IMAGE_FULL_NAME`: el nombre completo de la imagen con la etiqueta (se muestra en el banner de arranque)

**Nota:** los argumentos opcionales enriquecen el banner de arranque y las
etiquetas de metadatos, pero no hacen falta para el funcionamiento.

### Construir sin la Management API

El mismo Dockerfile construye la imagen de Cassandra independiente que se publica
como `ghcr.io/axonops/cassandra/cassandra`. Pase `INCLUDE_MGMT_API=false` y el
build elimina `/opt/management-api` y `/opt/cdc_agent`, quita el agente Java de la
Management API de `cassandra-env.sh` y deja que el entrypoint arranque Cassandra
directamente.

```bash
docker build \
  --build-arg CASSANDRA_VERSION=5.0.8 \
  --build-arg MAJOR_VERSION=5.0 \
  --build-arg K8SSANDRA_BASE_DIGEST=sha256:... \
  --build-arg K8SSANDRA_API_VERSION=0.1.120 \
  --build-arg INCLUDE_MGMT_API=false \
  --build-arg CQLAI_VERSION=0.1.7 \
  -t your-registry/axonops-cassandra:5.0.8-standalone \
  .
```

`INCLUDE_MGMT_API` vale `true` por defecto, así que los builds de K8ssandra no se
ven afectados. Véase [cassandra/README.es.md](../cassandra/README.es.md) para la
imagen independiente, su esquema de etiquetado y sus variables de entorno
`CASSANDRA_*`.

### Añadir soporte para nuevas versiones de Cassandra

Cuando se publica una nueva versión de Cassandra (por ejemplo, 5.0.7), siga estos
pasos:

**1. Obtenga el digest de la imagen base de k8ssandra:**

```bash
# Find the latest k8ssandra API version for the new Cassandra version
VERSION="5.0.7"
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${VERSION}-ubi" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'].startswith('${VERSION}-ubi-v')]; \
  results.sort(key=lambda x: x['name'], reverse=True); \
  print(f\"Tag: {results[0]['name']}\nDigest: {results[0]['digest']}\") if results else print('Not found')"
```

Esto mostrará algo así:
```
Tag: 5.0.7-ubi-v0.1.112
Digest: sha256:newdigest123...
```

**2. Actualice la variable de repositorio `K8SSANDRA_VERSIONS`:**

```bash
# Add the new version+digest to the JSON variable
gh variable set K8SSANDRA_VERSIONS --body '{
  "5.0.1+0.1.110": "sha256:...",
  "5.0.2+0.1.110": "sha256:...",
  ...
  "5.0.6+0.1.110": "sha256:...",
  "5.0.7+0.1.112": "sha256:newdigest123..."
}'
```

**3. Añada la versión a `versions.yaml`:**

La matriz de build vive en un único sitio. Añada la nueva versión al final de la
lista `versions` de su línea, en la sección `build_matrix` de
[`versions.yaml`](../versions.yaml). La lista va de la más antigua a la más
reciente, y la última entrada es a lo que resuelven las etiquetas flotantes
`latest` y `{line}-latest`, así que el orden importa y nada lo ordena por usted:

```yaml
build_matrix:
  lines:
    - line: "5.0"
      published: true
      versions:
        - "5.0.1"
        # ...
        - "5.0.7"      # <- appended
```

No hay que cambiar ningún fichero de workflow. Todas las matrices, el equivalente
de `ALL_VERSIONS` y las condiciones de las etiquetas flotantes se derivan de esa
lista con `scripts/build-matrix.sh`.

**4. Compruébelo antes de subir:**

```bash
./scripts/build-matrix.sh check \
  --k8ssandra-versions "$(gh variable get K8SSANDRA_VERSIONS --repo axonops/axonops-containers)"
```

Esto falla si la nueva versión no tiene imagen base `cass-management-api`: la
comprobación que, si no, le costaría un build de 15 minutos descubrir. Los
workflows de publicación y de build y pruebas ejecutan el mismo comando antes de
construir nada.

**5. Pruebe y publique:**

```bash
# Development test
git tag vdev-5.0.7-test
git push origin vdev-5.0.7-test
gh workflow run k8ssandra-development-publish-signed.yml \
  -f dev_git_tag=vdev-5.0.7-test \
  -f container_version=1.0.0

# If tests pass, publish to production via main branch
```

### Actualizar para nuevas versiones de la Management API de k8ssandra

Cuando k8ssandra publica una nueva versión de la Management API (por ejemplo,
v0.1.111) para versiones de Cassandra existentes:

**1. Obtenga los digests nuevos de todas las versiones de Cassandra afectadas:**

```bash
# Check what changed - k8ssandra typically updates all versions together
for version in 5.0.1 5.0.2 5.0.3 5.0.4 5.0.5 5.0.6; do
  echo "=== Cassandra $version ==="
  curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${version}-ubi-v0.1.111" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'] == '${version}-ubi-v0.1.111']; \
  print(f\"  Digest: {results[0]['digest']}\") if results else print('  Not found')"
done
```

**2. Actualice la variable `K8SSANDRA_VERSIONS` con la nueva versión de API:**

```bash
# Replace or add new composite keys with updated API version
gh variable set K8SSANDRA_VERSIONS --body '{
  "5.0.1+0.1.111": "sha256:new_digest_1...",
  "5.0.2+0.1.111": "sha256:new_digest_2...",
  "5.0.3+0.1.111": "sha256:new_digest_3...",
  "5.0.4+0.1.111": "sha256:new_digest_4...",
  "5.0.5+0.1.111": "sha256:new_digest_5...",
  "5.0.6+0.1.111": "sha256:new_digest_6..."
}'
```

**3. Incremente la versión del contenedor de AxonOps:**

Como la versión de la API de k8ssandra es una actualización de componente,
incremente la versión MENOR:
- Actual: `1.0.0`
- Nueva: `1.1.0` (subida MENOR por actualización de componente)

**4. Pruebe y publique:**

```bash
# Test in development
git tag vdev-k8s-api-update
git push origin vdev-k8s-api-update
gh workflow run k8ssandra-development-publish-signed.yml \
  -f dev_git_tag=vdev-k8s-api-update \
  -f container_version=1.1.0

# After tests pass, create production release
git checkout main
git merge development
git tag k8ssandra-1.1.0
git push origin main k8ssandra-1.1.0

gh workflow run k8ssandra-publish-signed.yml \
  -f main_git_tag=k8ssandra-1.1.0 \
  -f container_version=1.1.0
```

**Nota:** k8ssandra suele publicar nuevas versiones de la Management API
mensualmente. El workflow nocturno de comprobación de versiones (por implementar)
las detectará automáticamente.

**⚠️ Aviso sobre la seguridad de la cadena de suministro:**

Nuestros Dockerfiles extienden las imágenes base de k8ssandra fijándolas por
digest (no por etiqueta) para evitar ataques a la cadena de suministro:

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
FROM docker.io/k8ssandra/cass-management-api@sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM docker.io/k8ssandra/cass-management-api:5.0.6-ubi
```

**Por qué importa fijar por digest:**
- Las etiquetas pueden sustituirse de forma maliciosa (misma etiqueta, imagen maliciosa distinta)
- Los digests son criptográficamente inmutables: no pueden cambiarse
- Evita comprometer en silencio su cadena de suministro de contenedores
- Es la buena práctica del sector para los builds de contenedores de producción

**Al extender CUALQUIER imagen de contenedor:**
1. Obtenga el digest con: `docker inspect <image:tag> --format='{{.RepoDigests}}'`
2. Use `FROM image@digest` en su Dockerfile
3. Documente la etiqueta de versión en un comentario, para que se lea bien

**Seguridad de la cadena de suministro:**

Nuestros contenedores extienden las imágenes base de
`k8ssandra/cass-management-api`. Por seguridad de la cadena de suministro, fijamos
las imágenes base por digest (inmutable) en lugar de por etiqueta.
`K8SSANDRA_BASE_DIGEST` asocia versiones de Cassandra a digests de imagen
verificados, lo que evita ataques a la cadena de suministro en los que las
imágenes upstream podrían sustituirse de forma maliciosa.

La correspondencia en sí no se reproduce aquí. Vive en la variable de repositorio
`K8SSANDRA_VERSIONS`, con la clave `{CASSANDRA_VERSION}+{K8SSANDRA_API_VERSION}`, y
es lo que leen los builds. La copia que solía estar en esta sección estaba fijada
a la API de k8ssandra v0.1.120 y ya la había adelantado la v0.1.124: todos sus
digests eran incorrectos, y nada en CI podía advertirlo. Lea la correspondencia en
vivo con:

```bash
gh variable get K8SSANDRA_VERSIONS --repo axonops/axonops-containers | jq .
```

`scripts/build-matrix.sh check --k8ssandra-versions "$(gh variable get K8SSANDRA_VERSIONS --repo axonops/axonops-containers)"`
verifica que todas las versiones de la matriz de build tienen una entrada allí;
los workflows de publicación y de build y pruebas lo ejecutan antes de construir
nada.

**Cómo obtener los digests de las versiones nuevas de k8ssandra:**

Cuando k8ssandra publica una versión nueva de Cassandra, obtenga el digest con la
API de Docker Hub:

```bash
# For a specific version (e.g., 5.0.7)
VERSION="5.0.7"
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${VERSION}-ubi" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'].startswith('${VERSION}-ubi')]; \
  [print(f\"Version: {r['name']}\nDigest: {r['digest']}\") for r in results[:1]]"
```

O consiga todas las versiones 5.0.x de una vez:

```bash
for version in 5.0.1 5.0.2 5.0.3 5.0.4 5.0.5 5.0.6; do
  echo "=== Cassandra $version ==="
  curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${version}-ubi" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'].startswith('${version}-ubi')]; \
  [print(f\"  {r['digest']}\") for r in results[:1]]"
  echo ""
done
```

Una vez tenga el digest, actualice la variable de repositorio
`K8SSANDRA_VERSIONS` con la nueva clave compuesta versión+digest.

## Desplegar en Kubernetes

**Nota:** los comandos de esta sección suponen que está en el directorio
`k8ssandra/`.

### Usar la configuración de ejemplo

`examples/k8ssandra/cluster-axonops-ubi.yaml` es una plantilla para desplegar un
clúster de Cassandra 5.0 de 3 nodos:

```bash
# Set your environment variables
export IMAGE_NAME="your-image"
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"

# Apply the configuration
cat examples/k8ssandra/cluster-axonops-ubi.yaml | envsubst | kubectl apply -f -
```

### Verificar el despliegue

Tras el despliegue, verifique que su clúster está funcionando:

```bash
# Check cluster status
kubectl get k8ssandraclusters -n k8ssandra-operator

# Watch pods come up (wait for all to show Running and Ready)
kubectl get pods -n k8ssandra-operator -w

# Check detailed cluster status
kubectl describe k8ssandracluster <cluster-name> -n k8ssandra-operator
```

Todos los pods de Cassandra deberían mostrar `2/2` en la columna READY cuando
hayan arrancado del todo.

### Conectarse al clúster

#### Con cqlsh

Conéctese directamente a un pod de Cassandra:

```bash
kubectl exec -it <pod-name> -n k8ssandra-operator -c cassandra -- cqlsh
```

#### Acceso externo (port-forward)

> **Nota:** el port-forward vale para desarrollo local y pruebas. En entornos de
> producción (AWS, GCP, Azure, etc.), valore usar un servicio LoadBalancer, un
> controlador de Ingress o acceso por VPN, según sus requisitos de seguridad.

Para conectarse desde fuera del clúster de Kubernetes (por ejemplo, desde su
máquina local):

1. Obtenga las credenciales del superusuario:
   ```bash
   # Username
   kubectl get secret <cluster-name>-superuser -n k8ssandra-operator -o jsonpath='{.data.username}' | base64 -d

   # Password
   kubectl get secret <cluster-name>-superuser -n k8ssandra-operator -o jsonpath='{.data.password}' | base64 -d
   ```

2. Arranque el port-forward:
   ```bash
   kubectl port-forward svc/<cluster-name>-dc1-service 9042:9042 -n k8ssandra-operator
   ```

3. Conéctese con cqlsh o con cualquier cliente CQL a `localhost:9042`, con las
   credenciales del paso 1.

#### AxonOps Workbench

[AxonOps Workbench](https://axonops.com/workbench) es un IDE de escritorio
gratuito para que desarrolladores y DBA se conecten a clústeres de Cassandra y los
gestionen. Ofrece una interfaz moderna para lanzar consultas, explorar el esquema
y gestionar los datos. Use el método de port-forward de arriba para conectar
Workbench a su clúster sobre Kubernetes.

### Opciones de configuración principales

El clúster de ejemplo incluye:
- **Tamaño del clúster**: 3 nodos en el datacenter `dc1`
- **Recursos**:
  - CPU: 1 núcleo (petición y límite)
  - Memoria: 1 Gi de petición, 2 Gi de límite
- **Ajustes de la JVM**:
  - Heap inicial: 1G
  - Heap máximo: 1G
- **Almacenamiento**:
  - Clase de almacenamiento: `local-path`
  - Tamaño: 2 Gi por nodo
  - Modo de acceso: ReadWriteOnce
- **Antiafinidad**: antiafinidad de pod blanda activada

## Configuración

### Configuración del agente de AxonOps

El agente de AxonOps se configura mediante variables de entorno pasadas al
contenedor de Cassandra:

| Variable | Descripción | Valor por defecto |
|----------|-------------|---------|
| `AXON_AGENT_KEY` | Su clave de agente de AxonOps | Obligatoria |
| `AXON_AGENT_ORG` | El identificador de su organización de AxonOps | Obligatorio |
| `AXON_AGENT_SERVER_HOST` | El nombre de host del servidor de AxonOps | `agents.axonops.cloud` |
| `AXON_AGENT_LOG_OUTPUT` | El destino de la salida de registro del agente | `std` |
| `AXON_AGENT_NTP_HOST` | El servidor NTP usado para las comprobaciones de desviación del reloj, `host` o `host:puerto` (el puerto es `123` por defecto) | `pool.ntp.org` |

La autodetección de NTP no funciona dentro de Kubernetes, así que el contenedor
pone `AXON_AGENT_NTP_HOST` por defecto al `pool.ntp.org` público y registra un
aviso en cada arranque hasta que lo cambie. Póngalo a la misma fuente NTP que usan
sus hosts de Cassandra; si no, las lecturas de desviación del reloj se comparan
con un pool con el que sus nodos nunca se sincronizan.
| `AXON_AGENT_ARGS` | Argumentos adicionales del agente | - |

### Variables de entorno del contenedor

Las variables de entorno se inyectan en la configuración del clúster de K8ssandra:

```yaml
containers:
  - name: cassandra
    env:
      - name: AXON_AGENT_KEY
        value: "${AXON_AGENT_KEY}"
      - name: AXON_AGENT_ORG
        value: "${AXON_AGENT_ORG}"
      - name: AXON_AGENT_SERVER_HOST
        value: "${AXON_AGENT_SERVER_HOST}"
```

### Comprobación de salud

La comprobación de salud del contenedor
(`/usr/local/bin/axonops-healthcheck.sh`, ejecutada cada 30 s tras un periodo de
arranque de 120 s) comprueba dos cosas:

1. **Cassandra**: el endpoint de liveness de la Management API, la misma sonda en
   la que se apoya el operador K8ssandra. En las imágenes construidas sin la
   Management API (`INCLUDE_MGMT_API=false`) es, en su lugar, `nodetool
   statusbinary` más una comprobación del puerto CQL.
2. **Agente de AxonOps**: el proceso `axon-agent` está en ejecución, así que el
   nodo está realmente monitorizado.

Por defecto, un agente caído se refleja en la salida de la comprobación de salud,
pero no vuelve unhealthy el contenedor: Cassandra sigue sirviendo CQL, y hacer
fallar la comprobación puede llevar a Kubernetes a reiniciar o vaciar un nodo que
está haciendo trabajo útil. Ponga `HEALTHCHECK_REQUIRE_AGENT=true` para tratar un
agente caído como un fallo.

| Variable | Valor por defecto | Descripción |
|----------|---------|-------------|
| `HEALTHCHECK_REQUIRE_AGENT` | `false` | `true` vuelve unhealthy el contenedor cuando `axon-agent` no está en ejecución |

```yaml
containers:
  - name: cassandra
    env:
      - name: HEALTHCHECK_REQUIRE_AGENT
        value: "true"
```

Tenga en cuenta que el operador K8ssandra define sus propias sondas de liveness y
readiness en el pod; esto no las afecta y siguen usando los endpoints de la
Management API. La comprobación de salud de aquí es la del nivel de contenedor,
visible con `docker inspect` y para cualquier runtime que respete `HEALTHCHECK`.

```bash
docker inspect --format '{{.State.Health.Status}}' <container>
kubectl exec <pod> -c cassandra -- /usr/local/bin/axonops-healthcheck.sh
```

## Referencia de scripts

### scripts/install_k8ssandra.sh

Instala el operador K8ssandra y sus requisitos previos.

**Uso:**
```bash
./scripts/install_k8ssandra.sh
```

**Qué hace:**
- Instala cert-manager con Helm
- Añade el repositorio de Helm de K8ssandra
- Instala el operador K8ssandra v1.29.0

**No requiere parámetros.**

### scripts/rebuild.sh

Construye, sube y despliega un clúster de Cassandra con integración de AxonOps.

> **Nota:** este script está pensado para entornos de Kubernetes con acceso
> directo al nodo mediante `crictl`. Puede no funcionar en instalaciones de
> desarrollo local como minikube, kind o Docker Desktop. Para desarrollo local,
> véanse los pasos manuales de build y despliegue en las secciones
> [Construir las imágenes de Docker](#construir-las-imágenes-de-docker) y
> [Desplegar en Kubernetes](#desplegar-en-kubernetes).

**Uso:**
```bash
export IMAGE_NAME="your-registry/image:tag"  # Optional, defaults to ttl.sh
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_SERVER_HOST="your-host"  # Optional

# Change to version directory (script runs docker build from here)
cd 5.0
../scripts/rebuild.sh
```

**Qué hace:**
1. Genera un nombre de imagen único si no se proporciona (usando ttl.sh con un TTL de 1 hora)
2. Elimina el despliegue de clúster existente
3. Limpia las imágenes de contenedor antiguas con crictl
4. Construye la nueva imagen de Docker
5. Sube la imagen al registro
6. Descarga la imagen con crictl
7. Sustituye las variables de entorno en `cluster-axonops.yaml` (copia de [examples/k8ssandra/cluster-axonops-ubi.yaml](../examples/k8ssandra/cluster-axonops-ubi.yaml))
8. Despliega la configuración de clúster actualizada

**Variables de entorno:**
- `IMAGE_NAME`: el nombre de la imagen de Docker (opcional)
- `AXON_AGENT_KEY`: la clave de API de AxonOps (obligatoria en la configuración del clúster)
- `AXON_AGENT_ORG`: la organización de AxonOps (obligatoria en la configuración del clúster)
- `AXON_AGENT_SERVER_HOST`: el host de AxonOps (obligatorio en la configuración del clúster)

## Ejemplos

### examples/k8ssandra/cluster-axonops-ubi.yaml

Una definición completa de recurso K8ssandraCluster que muestra:

**Especificaciones del clúster:**
- Nombre: `axonops-k8ssandra-50`
- Espacio de nombres: `k8ssandra-operator`
- Versión de Cassandra: 5.0.6
- Imagen: `ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0` (por defecto)
- Datacenter: `dc1` con 3 nodos

**Asignación de recursos:**
```yaml
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 1
    memory: 1Gi
```

**Configuración del almacenamiento:**
```yaml
storageConfig:
  cassandraDataVolumeClaimSpec:
    storageClassName: local-path
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 2Gi
```

**Volumen de AxonOps (obligatorio):**

AxonOps necesita un volumen persistente para guardar su configuración. Añada esto
a su configuración de clúster:

```yaml
        extraVolumes:
          pvcs:
            - name: axonops-data
              mountPath: /var/lib/axonops
              pvcSpec:
                accessModes:
                  - ReadWriteOnce
                resources:
                  requests:
                    storage: ${AXONOPS_STORAGE_SIZE}
```

`AXONOPS_STORAGE_SIZE` vale `2Gi` por defecto en
`examples/k8ssandra/k8ssandra-config.env`. Defínalo antes de renderizar el
manifiesto para cambiar el tamaño. La mayoría de las StorageClass no pueden
encoger un volumen una vez creado, así que elija el tamaño antes del primer apply.

**Integración con AxonOps:**
El ejemplo muestra la inyección correcta de variables de entorno para el agente de
AxonOps, con el enfoque de variables a nivel de contenedor que exige K8ssandra.

### Personalizar el ejemplo

**Nota:** los comandos de esta sección suponen que está en el directorio
`k8ssandra/`.

Para usar este ejemplo:

1. Copie el fichero de ejemplo:
   ```bash
   cp examples/k8ssandra/cluster-axonops-ubi.yaml my-cluster.yml
   ```

2. Actualice los valores de `my-cluster.yml`:
   - **Nombre del clúster**: edite el campo `metadata.name` (por ejemplo, cambie `axonops-k8ssandra-50` por `my-cassandra-cluster`). Nota: el nombre del clúster se usa para generar los nombres de servicios, secretos y pods.
   - **Espacio de nombres**: edite `metadata.namespace` si despliega en otro espacio de nombres
   - **Número de nodos**: ajuste `size` bajo `datacenters` (por defecto son 3)
   - **Recursos**: modifique las asignaciones de CPU y memoria bajo `resources`
   - **Almacenamiento**: actualice el tamaño de `storage` bajo `storageConfig`

3. Despliegue:
   ```bash
   export AXON_AGENT_KEY="your-key"
   export AXON_AGENT_ORG="your-org"
   export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"
   # Optional: Override default image
   export IMAGE_NAME="ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0"

   cat my-cluster.yml | envsubst | kubectl apply -f -
   ```

**Nota:** el ejemplo usa el nuevo formato de imagen `5.0.6-v0.1.110-1.0.0`, que
incluye:
- La versión de Cassandra: 5.0.6
- La versión de la API de k8ssandra: v0.1.110
- La versión del contenedor de AxonOps: 1.0.0

## Pipeline de CI/CD

### Builds y pruebas automatizados

El repositorio incluye workflows completos de GitHub Actions para construir,
probar y publicar imágenes de Docker.

**Workflows:**
- **Build y pruebas:** `.github/workflows/k8ssandra-build-and-test.yml`, pruebas de build de Docker con validación completa
- **Pruebas E2E:** `.github/workflows/k8ssandra-e2e-test.yml`, pruebas de despliegue en Kubernetes de extremo a extremo
- **Escaneo de seguridad:** `.github/workflows/k8ssandra-nightly-security-scan.yml`, escaneo diario de CVE con avisos por correo
- **Publicación de producción (firmada):** `.github/workflows/k8ssandra-publish-signed.yml`, releases de producción manuales con firma Cosign
- **Publicación de desarrollo (firmada):** `.github/workflows/k8ssandra-development-publish-signed.yml`, builds de desarrollo con firma Cosign

**Disparadores del workflow de build y pruebas:**
- Push a las ramas `development` o `main` (con cambios en `k8ssandra/**`)
- Pull requests a `development` o `main` (con cambios en `k8ssandra/**`)

**Workflow de pruebas E2E:**
- Se lanza a mano desde la interfaz de GitHub Actions o con `gh workflow run k8ssandra-e2e-test.yml`
- Despliega los contenedores en un clúster k3s sobre el runner de GitHub Actions
- Prueba la Management API, el agente de AxonOps, cqlai y las operaciones CQL
- Valida la conectividad con AxonOps SaaS
- Duración: unos 3 o 4 minutos

**Workflow de escaneo de seguridad:**
- Programado: todos los días a las 2:00 UTC
- Se puede lanzar a mano desde la interfaz de GitHub Actions
- Escanea todas las versiones publicadas en busca de CVE
- Notificaciones por correo cuando se detectan problemas de severidad CRITICAL o HIGH

**Workflows de publicación:**
- Se lanzan a mano desde la interfaz de GitHub Actions o con la CLI `gh`
- Requieren una etiqueta de git y una versión de contenedor
- Véase [RELEASE.md](./RELEASE.md) para las instrucciones detalladas

**Batería de pruebas:**
El pipeline de CI incluye pruebas exhaustivas:
- Las pruebas se ejecutan primero para 5.0.6, y luego para las demás versiones 5.0 en paralelo (5.0.1 a 5.0.5)
- Comprobaciones de salud de la Management API (liveness, readiness)
- Operaciones del agente Java de la Management API (crear keyspace y tabla, flush, compact)
- Operaciones CQL con cqlai (CREATE, INSERT, SELECT, DROP)
- Verificación del proceso del agente de AxonOps
- Verificación de jemalloc (sin avisos, carga correcta)
- Verificación de la versión de Java (JDK17 para 5.0)
- Escaneo de seguridad del contenedor con Trivy
  - Los CVE upstream conocidos se documentan en `.trivyignore`
  - Véase [.trivyignore](./.trivyignore) para la lista de vulnerabilidades suprimidas

**Proceso de publicación:**
1. El desarrollador crea una etiqueta de git (por ejemplo, `git tag 1.0.0 && git push origin 1.0.0`)
2. El desarrollador lanza el workflow de publicación desde la interfaz de GitHub o con `gh workflow run`
3. El workflow valida que la versión no existe ya en GHCR
4. La batería de pruebas completa se ejecuta primero sobre 5.0.6, para validar
5. Se construyen imágenes multiarquitectura (amd64, arm64) para las 6 versiones (máximo 3 en paralelo)
6. Las imágenes se suben a GHCR con etiquetas específicas de versión y las etiquetas latest
7. Se crea automáticamente una GitHub Release

Para las instrucciones completas de release, véase [RELEASE.md](./RELEASE.md).

**Etiquetas de imagen:**
Cada release usa etiquetado tridimensional con seguimiento de la versión de la API
de k8ssandra:

```
ghcr.io/axonops/k8ssandra/cassandra:{CASS}-v{K8S_API}-{AXON}  # Fully immutable (all 3 versions)
ghcr.io/axonops/k8ssandra/cassandra:{CASS}-v{K8S_API}         # Latest AxonOps for this Cassandra + k8ssandra combo
ghcr.io/axonops/k8ssandra/cassandra:{CASS}                    # Latest k8ssandra API + AxonOps for this Cassandra minor
ghcr.io/axonops/k8ssandra/cassandra:{MAJOR}-latest            # Latest minor in Cassandra major
ghcr.io/axonops/k8ssandra/cassandra:latest                    # Latest across all Cassandra majors
```

**Ejemplo:** para una release de Cassandra `5.0.6`, API de k8ssandra `v0.1.110` y
AxonOps `1.0.0`:

**Etiquetas totalmente inmutables** (1 por versión de Cassandra, 6 en total):
- `5.0.1-v0.1.110-1.0.0`, `5.0.2-v0.1.110-1.0.0`, `5.0.3-v0.1.110-1.0.0`, `5.0.4-v0.1.110-1.0.0`, `5.0.5-v0.1.110-1.0.0`, `5.0.6-v0.1.110-1.0.0`

**Etiquetas flotantes** (siguen el último AxonOps de cada combinación Cassandra + k8ssandra, 6 en total):
- `5.0.1-v0.1.110` → `5.0.1-v0.1.110-1.0.0`
- `5.0.2-v0.1.110` → `5.0.2-v0.1.110-1.0.0`
- `5.0.3-v0.1.110` → `5.0.3-v0.1.110-1.0.0`
- `5.0.4-v0.1.110` → `5.0.4-v0.1.110-1.0.0`
- `5.0.5-v0.1.110` → `5.0.5-v0.1.110-1.0.0`
- `5.0.6-v0.1.110` → `5.0.6-v0.1.110-1.0.0`

**Etiquetas flotantes** (siguen el último k8ssandra + AxonOps de cada menor de Cassandra, 6 en total):
- `5.0.1` → `5.0.1-v0.1.110-1.0.0`
- `5.0.2` → `5.0.2-v0.1.110-1.0.0`
- `5.0.3` → `5.0.3-v0.1.110-1.0.0`
- `5.0.4` → `5.0.4-v0.1.110-1.0.0`
- `5.0.5` → `5.0.5-v0.1.110-1.0.0`
- `5.0.6` → `5.0.6-v0.1.110-1.0.0`

**Etiqueta latest a nivel de menor** (1):
- `5.0-latest` → `5.0.6-v0.1.110-1.0.0`

**Etiqueta latest global** (1):
- `latest` → `5.0.6-v0.1.110-1.0.0`

**Total:** 20 etiquetas (6 inmutables + 6 flotantes de k8ssandra + 6 flotantes de
Cassandra + 1 latest de menor + 1 latest global)

## Prestaciones del contenedor

### Banner de versión al arrancar

Todos los contenedores muestran al arrancar un banner de versión completo que
indica:
- La versión de build del contenedor y la revisión de git
- La versión de Cassandra
- La versión de Java
- Las versiones del agente de AxonOps (el independiente y el agente Java)
- La versión de cqlai
- La versión de jemalloc
- El sistema operativo y la plataforma
- El entorno de ejecución (detección de Kubernetes, nombre de host)
- El estado de la configuración de AxonOps

**Ver el banner:**
```bash
# Docker/Podman
docker logs <container-name> | head -30

# Kubernetes
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | head -30
```

**Ejemplo de salida (release de producción):**
```
================================================================================
AxonOps K8ssandra Apache Cassandra 5.0.6
Image: ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0
Built: 2025-12-09T14:40:13Z
Release: https://github.com/axonops/axonops-containers/releases/tag/1.0.0
Built by: GitHub Actions
================================================================================

Component Versions:
  Cassandra:          5.0.6
  k8ssandra API:      0.1.110
  Java:               OpenJDK Runtime Environment (Red_Hat-17.0.17.0.10-1) (build 17.0.17+10-LTS)
  AxonOps Agent:      2.0.11
  AxonOps Java Agent: axon-cassandra5.0-agent-jdk17-1.0.12-1.noarch
  cqlai:              v0.1.2
  jemalloc:           jemalloc-5.2.1-2.el9.x86_64
  OS:                 Red Hat Enterprise Linux 9.7 (Plow) (UBI - Universal Base Image, freely redistributable)
  Platform:           x86_64

Supply Chain Security:
  Base image:         k8ssandra/cass-management-api:5.0.6-ubi-v0.1.110
  Base image digest:  sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af

Runtime Environment:
  Hostname:           demo-dc1-default-sts-0
  Kubernetes:         Yes
    API Server:       10.43.0.1:443
    Pod:              demo-dc1-default-sts-0

AxonOps Configuration:
  Server:             agents.axonops.cloud
  Organization:       your-org
  Agent Key:          ***configured***

================================================================================
Starting Cassandra with Management API and AxonOps Agent...
================================================================================
```

Los **builds de producción** incluyen metadatos adicionales: los campos `Image`,
el enlace `Release` y `Built by`. Los **builds de desarrollo** muestran sólo los
campos esenciales (la marca de tiempo `Built`).

Este banner facilita mucho la depuración de entornos de cliente, porque muestra
toda la información de versión relevante en un mismo sitio.

## Monitorización con AxonOps

Una vez desplegado, su clúster de Cassandra hará automáticamente lo siguiente:
- Registrarse en AxonOps con la clave de API y la organización proporcionadas
- Enviar métricas y registros a la plataforma AxonOps
- Habilitar las prestaciones de monitorización, alertado y gestión del clúster

Acceda a la monitorización de su clúster en:
- AxonOps Cloud: https://axonops.cloud
- Instalación propia: la URL de AxonOps que haya configurado

## Resolución de problemas

### Comprobar la versión del contenedor

Consulte el banner de arranque para ver todas las versiones de los componentes:
```bash
# Kubernetes
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | head -30

# Docker/Podman
docker logs <container-name> | head -30
```

El banner muestra la versión del contenedor, la revisión de git y todas las
versiones de los componentes, lo que ayuda a identificar exactamente qué se está
ejecutando.

### Problemas de conexión del agente

Revise los registros del agente:
```bash
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | grep axon
```

Verifique las variables de entorno:
```bash
kubectl describe pod <pod-name> -n k8ssandra-operator
```

Compruebe que el banner de arranque muestra la configuración de AxonOps correcta.

### Errores al descargar la imagen

Asegúrese de que su imagen es accesible:
```bash
docker pull $IMAGE_NAME
```

Para las imágenes de ttl.sh, tenga en cuenta que expiran al cabo de 1 hora. Use un
registro persistente en producción.

### El clúster no arranca

Revise los registros del operador K8ssandra:
```bash
kubectl logs -n k8ssandra-operator deployment/k8ssandra-operator
```

Verifique el estado del clúster:
```bash
kubectl get k8ssandraclusters -n k8ssandra-operator
kubectl describe k8ssandracluster <cluster-name> -n k8ssandra-operator
```

## Consideraciones para producción

1. **Registro de imágenes**: use un registro de contenedores persistente en lugar de ttl.sh
2. **Dimensionado de recursos**: ajuste CPU, memoria y almacenamiento según la carga
3. **Alta disponibilidad**: despliegue en varias zonas de disponibilidad
4. **Estrategia de copia de seguridad**: configure Medusa de K8ssandra para las copias
5. **Seguridad**:
   - Use secretos para las credenciales de AxonOps, en lugar de variables de entorno
   - Active el cifrado en reposo y en tránsito
   - Configure RBAC y network policies
6. **Monitorización**: configure alertas en AxonOps para las métricas críticas
