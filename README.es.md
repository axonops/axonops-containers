# Imágenes de contenedor de AxonOps

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

[![Licencia](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Incidencias de GitHub](https://img.shields.io/github/issues/axonops/axonops-containers)](https://github.com/axonops/axonops-containers/issues)
[![Multiarquitectura](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-brightgreen)](https://github.com/axonops/axonops-containers)

Definiciones de build de contenedores y pipelines de CI/CD de las imágenes de
contenedor de AxonOps.

## Índice

- [Componentes](#componentes)
- [Versiones actuales](VERSIONS.md)
- [Docker Compose](#docker-compose)
  - [Inicio rápido](#inicio-rápido)
  - [Qué pila](#qué-pila)
  - [¿Compose o Kubernetes?](#compose-o-kubernetes)
- [Red Hat Universal Base Image (UBI)](#red-hat-universal-base-image-ubi)
- [Versiones admitidas](#versiones-admitidas)
- [Convenciones del repositorio](#convenciones-del-repositorio)
- [Seguridad](#seguridad)
  - [Política de CVE](#política-de-cve)
  - [Despliegue con seguridad de referencia](#despliegue-con-seguridad-de-referencia)
- [Desarrollo](#desarrollo)
  - [Estándares de seguridad de contenedores](#estándares-de-seguridad-de-contenedores-todos-los-componentes)
- [Publicación de releases](#publicación-de-releases)
  - [Publicación de desarrollo](#publicación-de-desarrollo)
  - [Publicación de producción](#publicación-de-producción)
  - [Documentación de release por componente](#documentación-de-release-por-componente)
- [Agradecimientos](#agradecimientos)
  - [Apache Cassandra](#apache-cassandra)
  - [K8ssandra](#k8ssandra)
  - [AxonOps Schema Registry](#axonops-schema-registry)
- [Licencia](#licencia)
- [Avisos legales](#avisos-legales)
  - [Marcas registradas](#marcas-registradas)

## Componentes

### Bases de datos
- **[cassandra/](./cassandra/)**: Apache Cassandra con el agente de AxonOps y sin la Management API de K8ssandra, construida a partir del Dockerfile de k8ssandra con `INCLUDE_MGMT_API=false` (`ghcr.io/axonops/cassandra/cassandra`)

### Distribuciones de Kubernetes
- **[k8ssandra/](./k8ssandra/)**: Apache Cassandra con integración de AxonOps para el operador K8ssandra

### AxonOps autoalojado
- **[axonops/](./axonops/)**: la pila autoalojada de AxonOps (todos los componentes de la plataforma)

### Integraciones
- **[axonops-schema-registry/](./axonops-schema-registry/)**: Schema Registry compatible con Confluent, con soporte de varios backends de almacenamiento

### Pilas de Compose
- **[docker-compose/](./docker-compose/)**: todas las pilas de Compose: la plataforma AxonOps por sí sola, la plataforma con un clúster de Cassandra monitorizado, un clúster que reporta a AxonOps SaaS y un clúster asegurado de 3 racks sobre una subred fija

## Docker Compose

Docker Compose es una vía de despliegue de primer nivel en este repositorio.
Todas las pilas viven bajo [`docker-compose/`](./docker-compose/), se construyen
a partir de las imágenes publicadas aquí y se configuran enteramente mediante
`.env`: no hace falta editar ningún fichero de Compose para ejecutar una.

### Inicio rápido

Una plataforma AxonOps autoalojada completa en un solo host:

```bash
git clone https://github.com/axonops/axonops-containers.git
cd axonops-containers/docker-compose/00-axonops-platform
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose ps            # wait for all four services to report healthy
```

Después abra <http://localhost:3000>. Un arranque en frío tarda de 2 a 3 minutos:
primero se inicializan los dos almacenes de datos, y detrás de ellos suben
`axon-server` y el panel.

Los valores por defecto de `env.example` son valores de desarrollo. Antes de
ejecutar una pila que le importe, defina `AXONOPS_ORG_NAME`,
`AXONOPS_DB_PASSWORD` y `AXONOPS_SEARCH_PASSWORD`: véase
[docker-compose/README.es.md](./docker-compose/README.es.md#antes-de-ejecutar-nada).

### Qué pila

| Pila | Úsela para |
|---|---|
| [00-axonops-platform](./docker-compose/00-axonops-platform/) | ejecutar AxonOps para clústeres que ya tiene |
| [01-cassandra-cluster](./docker-compose/01-cassandra-cluster/) | ver el conjunto funcionando de extremo a extremo: la plataforma más 3 nodos monitorizados |
| [02-saas-cassandra-cluster](./docker-compose/02-saas-cassandra-cluster/) | monitorizar un clúster desde AxonOps SaaS, sin plataforma que ejecutar en local |
| [03-secure-3-rack-cluster](./docker-compose/03-secure-3-rack-cluster/) | modelar un clúster con forma de producción: autenticación, 3 racks, direccionamiento fijo y JMX remoto |

Comparación completa, con el número de contenedores y la RAM con los valores por
defecto:
[docker-compose/README.es.md](./docker-compose/README.es.md#cuál-quiero).

### ¿Compose o Kubernetes?

Ambas vías despliegan las mismas imágenes; se diferencian en dónde se ejecuta la
pila y en qué la opera.

| | Docker Compose | Kubernetes |
|---|---|---|
| **Dónde** | un único host | un clúster |
| **Para qué** | evaluación, demos, desarrollo, despliegues pequeños en un solo host | producción, alta disponibilidad, cualquier cosa que deba sobrevivir a un host |
| **Plataforma AxonOps** | las pilas de [`docker-compose/`](./docker-compose/) | los charts de Helm `oci://ghcr.io/axonops/charts/*`: véase [VERSIONS.md](VERSIONS.md#helm-charts) y [examples/AXONOPS_DEPLOYMENT.es.md](./examples/AXONOPS_DEPLOYMENT.es.md) |
| **Cassandra** | la imagen [`cassandra/`](./cassandra/), ejecutada directamente | la imagen [`k8ssandra/`](./k8ssandra/) mediante el operador K8ssandra: véase [examples/K8SSANDRA_DEPLOYMENT.es.md](./examples/K8SSANDRA_DEPLOYMENT.es.md) |
| **Escalado y conmutación por error** | manuales | operador y planificador |

Los agentes reportan a `axon-server` igual en ambas, así que un clúster
monitorizado por una plataforma sobre Compose puede apuntarse después a una sobre
Kubernetes sin tocar los nodos monitorizados.

## Red Hat Universal Base Image (UBI)

Todos los contenedores de este repositorio se construyen sobre **Red Hat
Universal Base Image (UBI) 9**, que aporta seguridad, estabilidad y cumplimiento
de nivel empresarial.

**¿Por qué Red Hat UBI?**

- **Redistribuible libremente**: no hace falta suscripción para usarla ni redistribuirla
- **Seguridad empresarial**: actualizaciones de seguridad y parches de CVE periódicos de Red Hat
- **Endurecida para producción**: superficie de ataque mínima, sólo con los paquetes esenciales
- **Lista para el cumplimiento**: cumple los requisitos de sectores regulados (finanzas, sanidad, administración pública)
- **Soporte a largo plazo**: base estable con un ciclo de vida predecible (RHEL 9 con soporte hasta 2032)
- **Optimizada para contenedores**: diseñada expresamente para cargas en contenedores, con una huella mínima

**Más información:**
- [El proyecto Red Hat UBI](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image)
- [Catálogo de contenedores UBI 9](https://catalog.redhat.com/software/containers/search?q=ubi9)
- [Documentación de UBI](https://developers.redhat.com/products/rhel/ubi)

## Versiones admitidas

Qué versiones de Apache Cassandra construye este repositorio se declara una sola
vez, en la sección `build_matrix` de [versions.yaml](versions.yaml). Las matrices
de los workflows, las versiones por defecto, los destinos de las etiquetas
flotantes y las notas de release se derivan todos de ahí: ningún fichero de
workflow nombra una versión de Cassandra.

```bash
./scripts/build-matrix.sh versions   # every version built
./scripts/build-matrix.sh newest     # what the `latest` tag resolves to
```

**La política:**

- **Se añade** cuando Apache ha publicado el parche *y* k8ssandra ha publicado una
  imagen base `cass-management-api` correspondiente. Las dos imágenes de Cassandra
  de aquí se construyen `FROM` esa base, así que la segunda condición no es
  negociable: una versión añadida antes de que exista su base hace fallar todos
  sus jobs de build. Cassandra 5.0.9 está hoy exactamente en esa situación:
  publicada upstream, sin imagen base y, por tanto, no construida.
- **Se conserva** una vez añadida. Un parche más nuevo no retira uno más antiguo:
  todas las versiones de la matriz se siguen reconstruyendo y escaneando en busca
  de CVE, así que un despliegue fijado a un parche antiguo sigue recibiendo
  correcciones.
- **Se retira** sólo cuando la línea llega a su fin de vida upstream, o cuando una
  dependencia la vuelve imposible de construir. En cualquiera de los dos casos la
  línea permanece en `versions.yaml` marcada como `published: false` con el
  motivo, en lugar de borrarse.
- **Se conserva pero no se publica** cuando los Dockerfiles se mantienen y las
  imágenes no se distribuyen. Cassandra 4.0 y 4.1 están en ese estado: el agente
  de AxonOps todavía no es compatible con sus imágenes base con JDK 11. Póngase en
  contacto con nosotros si las necesita.

Publicadas actualmente: **Cassandra 5.0.1 – 5.0.8**, con `latest` y `5.0-latest`
resolviendo a 5.0.8. Véase
[k8ssandra/README.es.md](k8ssandra/README.es.md#versiones-de-cassandra-admitidas)
para el detalle por línea, y [VERSIONS.md](VERSIONS.md) para la etiqueta y el
digest actuales de cada imagen publicada.

## Convenciones del repositorio

- **Soporte multiarquitectura**: linux/amd64, linux/arm64
- **Publicadas en**: GitHub Container Registry, `ghcr.io/axonops/<image-name>:<tag>`
- **CI/CD automatizado**: GitHub Actions con pruebas exhaustivas
- **Escaneo de seguridad**: escaneo de vulnerabilidades con Trivy en todas las imágenes
- **Imágenes base**: Red Hat UBI 9 (fijadas por digest, por seguridad de la cadena de suministro)
- **Versiones actuales**: [VERSIONS.md](VERSIONS.md) lista la etiqueta y el digest actuales de cada imagen y chart publicados. Se genera a partir de [versions.yaml](versions.yaml) con `./scripts/update-versions.sh`: edite el YAML, nunca el Markdown.
- **Matriz de build**: las versiones de Cassandra que se construyen se declaran una sola vez, en la sección `build_matrix` de [versions.yaml](versions.yaml), y los workflows las leen a través de `./scripts/build-matrix.sh`. Nunca escriba una lista de versiones en un fichero de workflow: véase [Versiones admitidas](#versiones-admitidas).

## Seguridad

### Política de CVE

**Etiquetado inmutable:** todas las imágenes de contenedor usan versionado
inmutable. Cuando se descubren y se parchean CVE, publicamos versiones NUEVAS en
lugar de sobrescribir etiquetas existentes.

**Incrementos de versión:**
- CVE críticos (severidad CRITICAL, HIGH): release de parche inmediata (por ejemplo, `1.0.3` → `1.0.4`)
- CVE no críticos (MEDIUM, LOW): agrupados en releases mensuales
- Un incremento de versión de parche puede incluir: correcciones de CVE, actualizaciones de componentes (por ejemplo, el agente de AxonOps), corrección de errores o nuevas prestaciones

**Comportamiento de la etiqueta `latest`:**
- La etiqueta `latest` apunta siempre a la versión segura más reciente
- Ofrece actualizaciones de seguridad automáticas si se usa la etiqueta latest
- **NO se recomienda para producción**: use versiones concretas

**Despliegue en producción:**
- Fije siempre versiones inmutables concretas (por ejemplo, `5.0.6-v0.1.110-1.0.5`)
- No use nunca las etiquetas `latest`, `5.0-latest` ni `{version}-latest` en producción
- Revise las notas de release antes de actualizar
- Pruebe primero las actualizaciones en entornos que no sean de producción

**Notificaciones de CVE:**
- Escaneos de seguridad nocturnos automatizados con Trivy
- Notificaciones por correo de los nuevos CVE CRITICAL/HIGH
- Divulgación transparente en las notas de release

**Para los entornos de máxima seguridad**, véase
[Despliegue con seguridad de referencia](#despliegue-con-seguridad-de-referencia).

---

### Despliegue con seguridad de referencia

El **despliegue basado en digest** ofrece el máximo nivel de seguridad e
inmutabilidad para los despliegues de contenedores.

#### ¿Qué es el despliegue basado en digest?

En lugar de usar etiquetas (que pueden ser mutables), despliegue usando el digest
SHA256 de la imagen:

```yaml
# Tag-based (good)
image: ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Digest-based (best)
image: ghcr.io/axonops/k8ssandra/cassandra@sha256:412c85225...
```

#### Ventajas

✅ **100 % inmutable**: exactamente la misma imagen siempre, para siempre

✅ **Resiste la manipulación de etiquetas**: no le afecta que las etiquetas se cambien por accidente o de forma maliciosa

✅ **Lista para el cumplimiento**: cumple los requisitos de los entornos regulados (finanzas, sanidad, administración pública)

✅ **Rastro de auditoría**: el digest en el manifiesto de despliegue es la prueba criptográfica de la imagen exacta

✅ **Seguridad de la cadena de suministro**: junto con la verificación de firmas, da una procedencia completa

#### Encontrar los digests de las imágenes

**Método 1: desde la interfaz de GHCR**
1. Vaya al paquete: https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra
2. Haga clic en la versión concreta
3. Copie el digest SHA256 que se muestra

**Método 2: con Docker o Podman**
```bash
# Pull the image first
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Get digest
docker inspect ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5 \
  --format='{{index .RepoDigests 0}}'

# Output: ghcr.io/axonops/k8ssandra/cassandra@sha256:412c85225...
```

**Método 3: durante el workflow**
- Consulte los registros del workflow de GitHub Actions tras la publicación
- El digest se imprime en la salida del build

#### Ejemplo de despliegue en Kubernetes

**Manifiesto K8ssandraCluster:**
```yaml
apiVersion: k8ssandra.io/v1alpha1
kind: K8ssandraCluster
metadata:
  name: production-cluster
spec:
  cassandra:
    serverVersion: "5.0.6"
    # Use digest instead of tag
    serverImage: "ghcr.io/axonops/k8ssandra/cassandra@sha256:412c852252ec4ebcb8d377a505881828a7f6a5f9dc725cc4f20fda2a1bcb3494"
    datacenters:
      - metadata:
          name: dc1
        size: 3
        # ... rest of configuration
```

#### Verificar las firmas

Todas las imágenes publicadas en GHCR se firman con
[Cosign de Sigstore](https://github.com/sigstore/cosign), con firma sin claves.

**Verificación estándar:**
```bash
# Install cosign
brew install sigstore/tap/cosign  # macOS
# or: https://docs.sigstore.dev/cosign/installation/

# Verify signature
cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Check signature exists
cosign tree ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

**Resolución de problemas (en macOS):**

Si tiene problemas con cosign local en macOS, use la imagen de contenedor oficial
de Cosign:

```bash
# Using Docker
docker run --rm gcr.io/projectsigstore/cosign:v2.4.1 verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Using Podman
podman run --rm gcr.io/projectsigstore/cosign:v2.4.1 verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

Esto usa el [contenedor oficial de Cosign](https://github.com/sigstore/cosign) y
funciona de forma fiable en todas las plataformas.

**Una verificación correcta demuestra:**
- ✅ Que la imagen la construyó el workflow oficial de GitHub Actions
- ✅ Que la imagen no se ha manipulado
- ✅ Que la procedencia del build es trazable hasta un commit y una ejecución de workflow concretos

#### Exigir imágenes firmadas en Kubernetes

Para entornos de producción que requieren verificar la firma antes de desplegar:

**Herramientas de aplicación de políticas:**
- **Kyverno**: motor de políticas nativo de Kubernetes
- **OPA Gatekeeper**: Open Policy Agent para Kubernetes
- **Sigstore Policy Controller**: el controlador de admisión oficial de Sigstore

**Ejemplo: política de Kyverno**

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-axonops-images
spec:
  validationFailureAction: Enforce
  rules:
    # RULE 1: Deny any image NOT from ghcr.io/axonops/
    - name: check-registry
      match:
        any:
        - resources:
            kinds: [Pod]
            namespaces: [kafka,k8ssandra-operator,strimzi]
      validate:
        message: "Only images from ghcr.io/axonops/ are allowed in this namespace."
        foreach:
        - list: "request.object.spec.containers"
          deny:
            conditions:
              all:
              - key: "{{ element.image }}"
                operator: NotEquals # Use NotEquals with wildcards
                value: "ghcr.io/axonops/*"

    # RULE 2: Verify the signatures of those images
    - name: verify-signature
      match:
        any:
        - resources:
            kinds: [Pod]
            namespaces: [kafka,k8ssandra-operator,strimzi]
      verifyImages:
        - imageReferences:
            - "ghcr.io/axonops/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/axonops/axonops-containers/*"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

**Soporte de los proveedores cloud:**
- **AWS EKS**: use Kyverno u OPA Gatekeeper mediante Helm
- **Google GKE**: Binary Authorization con atestaciones de Cosign
- **Azure AKS**: Azure Policy con Ratify + Cosign
- **Rancher/RKE**: Kyverno u OPA Gatekeeper mediante Rancher Apps

Para la configuración detallada, consulte la documentación de su distribución de
Kubernetes sobre controladores de admisión y aplicación de políticas de imagen.

#### Buenas prácticas

**Para clústeres de producción:**
1. ✅ Use despliegue basado en digest
2. ✅ Verifique las firmas antes de desplegar (imágenes firmadas)
3. ✅ Fije el digest en el control de versiones (GitOps)
4. ✅ Documente la correspondencia digest → versión en las notas de release
5. ✅ Actualice los digests sólo tras probarlos fuera de producción

**Para desarrollo y pruebas:**
- El despliegue basado en etiquetas es aceptable, para iterar más rápido
- Use el registro de imágenes de desarrollo para las pruebas

**Actualizar los digests:**
```bash
# 1. Pull new version
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# 2. Get new digest
NEW_DIGEST=$(docker inspect ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5 \
  --format='{{index .RepoDigests 0}}' | cut -d@ -f2)

# 3. Update manifest
sed -i "s|@sha256:.*|@${NEW_DIGEST}\"|" k8ssandra-cluster.yaml

# 4. Review, test, and commit
git diff k8ssandra-cluster.yaml
```

---

## Desarrollo

**Estructura de ramas:**
- `development`: la rama por defecto, se commitea directamente aquí
- `main`: sólo releases de producción (requiere PR)
- `feature/*`: opcional, para prestaciones complejas

Véase [DEVELOPMENT.md](./DEVELOPMENT.md) para las pautas completas.

**Flujo de trabajo del desarrollador:**
```bash
# Work directly on development
git checkout development && git pull origin development
git add . && git commit -S -m "Add feature" && git push origin development

# For production: create PR development → main (approval required)
```

### Estándares de seguridad de contenedores (TODOS los componentes)

**Todos los contenedores que construimos DEBEN seguir estas prácticas de
seguridad:**

1. **Fijado por digest (seguridad de la cadena de suministro)**
   - Fije **SIEMPRE** las imágenes base por digest SHA256, NUNCA por etiqueta
   - Las etiquetas son mutables: pueden sustituirse de forma maliciosa
   - Los digests son inmutables: están garantizados criptográficamente
   - Ejemplo:
     ```dockerfile
     # CORRECT
     FROM upstream/image@sha256:abc123...

     # WRONG - Supply chain vulnerability!
     FROM upstream/image:latest
     FROM upstream/image:v1.0.0
     ```

2. **Firma de contenedores (autenticidad)**
   - **TODAS** las imágenes publicadas DEBEN firmarse con Cosign
   - Use la firma sin claves con OIDC de GitHub (sin gestión de secretos)
   - Firme por digest inmediatamente después del build
   - Publique en `ghcr.io/axonops/<component>/<image-name>:tag`

3. **Verificación y pruebas**
   - Verifique las sumas de comprobación de los artefactos descargados (RPM, tarballs, etc.)
   - Verifique que el digest de la imagen base corresponde a la versión esperada
   - Detección automatizada de errores de arranque
   - Escaneo de seguridad con Trivy antes de publicar

**Por qué importan estos estándares:**
- Evitan ataques a la cadena de suministro (imágenes base maliciosas)
- Garantizan la autenticidad de las imágenes (firmas de Cosign)
- Aportan un rastro de auditoría completo (digests + firmas)
- Cumplen los requisitos de cumplimiento de los entornos regulados

## Publicación de releases

### Publicación de desarrollo

**Propósito:** publicar imágenes firmadas en el registro de desarrollo, para
probarlas antes de una release de producción.

**Registro:** `ghcr.io/axonops/development/<component>/<image-name>`

**Ejemplo:** `ghcr.io/axonops/development/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0`

**Características:**
- Todas las imágenes están firmadas con Cosign (igual que en producción)
- Usa los mismos estándares de seguridad que producción (fijado por digest, sumas de comprobación, verificación)
- Permite probar con versiones concretas
- No se crean GitHub Releases
- Se etiqueta desde la rama `development`

**Proceso:**

```bash
# 1. Tag development branch (any name, e.g., dev-feature-x, dev-1.0.0)
git checkout development && git pull origin development
git tag dev-1.0.0 && git push origin dev-1.0.0

# 2. Trigger development publish workflow
gh workflow run development-<component>-publish.yml \
  -f dev_git_tag=dev-1.0.0 \
  -f container_version=dev-1.0.0

# 3. Test development image
docker pull ghcr.io/axonops/development-<image>:5.0.6-dev-1.0.0
# Run tests, validate functionality

# 4. Promote to main (auto-creates PR)
git tag merge-1.0.0 && git push origin merge-1.0.0
# PR auto-created, review and merge to main
```

**Úsela para:** pruebas de prestaciones, pruebas de integración y validación de QA
antes de producción.

---

### Publicación de producción

**Propósito:** publicar imágenes estables y probadas en el registro de producción.

**Registro:** `ghcr.io/axonops/<image-name>`

**Características:**
- Inmutable (la validación de versión impide sobrescrituras)
- Crea GitHub Releases
- Se etiqueta sólo desde la rama `main`
- Sólo después de probar en desarrollo

**Requisitos previos:**
- Los cambios fusionados en `development` y probados
- Las imágenes de desarrollo validadas (si se publicaron)
- La PR de `development` a `main` aprobada y fusionada

**Proceso:**

**Paso 1: crear la etiqueta de git en la rama main**

**IMPORTANTE:** las etiquetas deben crearse en la rama `main`. El workflow de
publicación lo valida.

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main

# Tag the commit
git tag 1.0.0

# Push tag to remote
git push origin 1.0.0
```

La etiqueta puede tener cualquier nombre (por ejemplo, `1.0.0`, `v1.0.0`,
`release-2024-12`). Marca la instantánea exacta del código desde la que
construir.

**Nota:** si etiqueta un commit que no está en `main`, el workflow de publicación
fallará con un error.

**Paso 2: lanzar el workflow de publicación**

Puede lanzar el workflow de publicación desde la **CLI de GitHub** o desde la
**interfaz de GitHub**.

#### Opción A: la CLI de GitHub

Instálela y autentíquese (sólo la primera vez):
```bash
# macOS
brew install gh

# Linux
# See: https://github.com/cli/cli#installation

# Authenticate
gh auth login
```

Lance el workflow de publicación firmada:
```bash
gh workflow run <component>-publish-signed.yml \
  -f main_git_tag=1.0.0 \
  -f container_version=1.0.0
```

**Explicación de los argumentos:**
- `-f main_git_tag=1.0.0`: la etiqueta de git en la rama main de la que hacer checkout y construir (la que creó en el paso 1)
- `-f container_version=1.0.0`: la versión de contenedor para las imágenes de GHCR (por ejemplo, produce `5.0.6-v0.1.110-1.0.5`)

**Nota:** use los workflows `-signed` (`k8ssandra-publish-signed.yml`) para las
releases nuevas. Publican en las nuevas rutas de imagen con firmas
criptográficas. Los workflows antiguos siguen ahí por compatibilidad, pero están
obsoletos.

Siga el progreso:
```bash
gh run watch
```

#### Opción B: la interfaz de GitHub

1. Vaya a la pestaña **Actions** del repositorio de GitHub
2. Seleccione el workflow de publicación (por ejemplo, **K8ssandra Publish to GHCR**)
3. Pulse el botón **Run workflow** (arriba a la derecha)
4. Aparece un formulario con estos campos:
   - **main_git_tag**: introduzca la etiqueta de git de la rama main creada en el paso 1 (por ejemplo, `1.0.0`)
     - Determina qué código se construye
   - **container_version**: introduzca la versión de contenedor (por ejemplo, `1.0.0`)
     - Pasa a ser la versión de contenedor de las imágenes publicadas
     - Ejemplo: `5.0.6-v0.1.110-1.0.5`, donde `1.0.0` es la versión de contenedor
5. Pulse **Run workflow** para empezar

**Paso 3: ejecución del workflow**

El workflow de publicación firmada:
- Valida que la etiqueta está en la rama main (falla si no)
- Valida que `container_version` no existe ya en GHCR (falla si está duplicada)
- Hace checkout del commit de `main_git_tag` (la instantánea exacta del código)
- Ejecuta la batería de pruebas completa
- Construye imágenes multiarquitectura (amd64, arm64)
- Sube a GHCR con etiquetas multidimensionales
- **Firma las imágenes** con Cosign de Sigstore (sin claves, con OIDC de GitHub)
- Vuelve a subir las etiquetas para que se muestren correctamente en la interfaz de GHCR
- Crea una GitHub Release llamada `<component>-signed-<container_version>`

**Las imágenes se firman** con firma sin claves y con entradas en el registro de
transparencia. Las firmas pueden verificarse con `cosign verify` (véase
[Verificar las firmas](#verificar-las-firmas)).

**Paso 4: verificar la release**

```bash
# View GitHub Release
gh release view k8ssandra-signed-1.0.0

# Pull and test image
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Verify signature
cosign verify \
  --certificate-identity-regexp='https://github.com/axonops/axonops-containers' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com' \
  ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Or check signature exists
cosign tree ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

Todas las imágenes de producción están firmadas criptográficamente. La
verificación de la firma demuestra que la imagen la construyeron los workflows
oficiales y que no se ha manipulado. Véase
[Despliegue con seguridad de referencia](#despliegue-con-seguridad-de-referencia)
para más detalles.

### Documentación de release por componente

Cada componente tiene su documentación de release detallada:
- [Proceso de release de K8ssandra](./k8ssandra/RELEASE.md)
- [Proceso de release del Schema Registry](./axonops-schema-registry/RELEASE.md)

## Agradecimientos

### Apache Cassandra
Queremos expresar nuestro reconocimiento a la comunidad de
[Apache Cassandra](https://cassandra.apache.org/) por su magnífico trabajo y sus
aportaciones al campo de las bases de datos distribuidas. Apache Cassandra es un
sistema gestor de bases de datos NoSQL distribuido, de tipo wide-column, libre y
de código abierto, diseñado para manejar grandes volúmenes de datos repartidos
entre muchos servidores convencionales, con alta disponibilidad y sin ningún
punto único de fallo.

Más información:
- [Web de Apache Cassandra](https://cassandra.apache.org/)
- [Apache Cassandra en GitHub](https://github.com/apache/cassandra)
- [Documentación de Apache Cassandra](https://cassandra.apache.org/doc/latest/)

### K8ssandra
Reconocemos el trabajo de [K8ssandra](https://k8ssandra.io/), que aporta un
excelente operador de Kubernetes y herramientas de gestión para Apache Cassandra.
K8ssandra es una plataforma lista para producción que ejecuta Apache Cassandra
sobre Kubernetes, con copia de seguridad y restauración, reparaciones y
capacidades de monitorización.

Más información:
- [Web de K8ssandra](https://k8ssandra.io/)
- [K8ssandra en GitHub](https://github.com/k8ssandra/k8ssandra-operator)
- [Documentación de K8ssandra](https://docs.k8ssandra.io/)

### AxonOps Schema Registry
Reconocemos el trabajo de
[AxonOps Schema Registry](https://github.com/axonops/axonops-schema-registry),
que aporta un Schema Registry compatible con Confluent con soporte de varios
backends de almacenamiento, entre ellos PostgreSQL, MySQL y Apache Cassandra.

Más información:
- [AxonOps Schema Registry en GitHub](https://github.com/axonops/axonops-schema-registry)

## Licencia

Este proyecto se publica bajo la licencia Apache 2.0: véase el fichero
[LICENSE](LICENSE) para los detalles.

## Avisos legales

Este proyecto puede contener marcas o logotipos de proyectos, productos o
servicios. Todo uso de marcas o logotipos de terceros está sujeto a las políticas
de esos terceros.

### Marcas registradas

- **AxonOps** es una marca registrada de AxonOps Limited
- **Apache**, **Apache Cassandra** y **Cassandra** son marcas de la Apache Software Foundation o de sus filiales en Canadá, Estados Unidos y otros países
- **Apache Kafka** y **Kafka** son marcas de la Apache Software Foundation
- **K8ssandra** es una marca de la Apache Software Foundation
- **Docker** es una marca o marca registrada de Docker, Inc. en Estados Unidos y otros países
- **Podman** es una marca de Red Hat, Inc.
- **OpenSearch** es una marca de Amazon.com, Inc. o de sus filiales
- **Kubernetes** es una marca registrada de The Linux Foundation

---

<div align="center">

**Hecho con ❤️ por [AxonOps](https://axonops.com)**

</div>
