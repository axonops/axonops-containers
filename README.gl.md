# Imaxes de contedor de AxonOps

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

[![Licenza](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Incidencias de GitHub](https://img.shields.io/github/issues/axonops/axonops-containers)](https://github.com/axonops/axonops-containers/issues)
[![Multiarquitectura](https://img.shields.io/badge/arch-amd64%20%7C%20arm64-brightgreen)](https://github.com/axonops/axonops-containers)

Definicións de build de contedores e pipelines de CI/CD das imaxes de contedor de
AxonOps.

## Índice

- [Compoñentes](#compoñentes)
- [Versións actuais](VERSIONS.md)
- [Docker Compose](#docker-compose)
  - [Inicio rápido](#inicio-rápido)
  - [Que pila](#que-pila)
  - [Compose ou Kubernetes?](#compose-ou-kubernetes)
- [Red Hat Universal Base Image (UBI)](#red-hat-universal-base-image-ubi)
- [Versións admitidas](#versións-admitidas)
- [Convencións do repositorio](#convencións-do-repositorio)
- [Seguridade](#seguridade)
  - [Política de CVE](#política-de-cve)
  - [Despregamento con seguridade de referencia](#despregamento-con-seguridade-de-referencia)
- [Desenvolvemento](#desenvolvemento)
  - [Estándares de seguridade de contedores](#estándares-de-seguridade-de-contedores-todos-os-compoñentes)
- [Publicación de releases](#publicación-de-releases)
  - [Publicación de desenvolvemento](#publicación-de-desenvolvemento)
  - [Publicación de produción](#publicación-de-produción)
  - [Documentación de release por compoñente](#documentación-de-release-por-compoñente)
- [Agradecementos](#agradecementos)
  - [Apache Cassandra](#apache-cassandra)
  - [K8ssandra](#k8ssandra)
  - [AxonOps Schema Registry](#axonops-schema-registry)
- [Licenza](#licenza)
- [Avisos legais](#avisos-legais)
  - [Marcas rexistradas](#marcas-rexistradas)

## Compoñentes

### Bases de datos
- **[cassandra/](./cassandra/)**: Apache Cassandra co axente de AxonOps e sen a Management API de K8ssandra, construída a partir do Dockerfile de k8ssandra con `INCLUDE_MGMT_API=false` (`ghcr.io/axonops/cassandra/cassandra`)

### Distribucións de Kubernetes
- **[k8ssandra/](./k8ssandra/)**: Apache Cassandra con integración de AxonOps para o operador K8ssandra

### AxonOps autoaloxado
- **[axonops/](./axonops/)**: a pila autoaloxada de AxonOps (todos os compoñentes da plataforma)

### Integracións
- **[axonops-schema-registry/](./axonops-schema-registry/)**: Schema Registry compatible con Confluent, con soporte de varios backends de almacenamento

### Pilas de Compose
- **[docker-compose/](./docker-compose/)**: todas as pilas de Compose: a plataforma AxonOps por si soa, a plataforma cun clúster de Cassandra monitorizado, un clúster que reporta a AxonOps SaaS e un clúster asegurado de 3 racks sobre unha subrede fixa

## Docker Compose

Docker Compose é unha vía de despregamento de primeiro nivel neste repositorio.
Todas as pilas viven baixo [`docker-compose/`](./docker-compose/), constrúense a
partir das imaxes publicadas aquí e configúranse enteiramente mediante `.env`:
non fai falta editar ningún ficheiro de Compose para executar unha.

### Inicio rápido

Unha plataforma AxonOps autoaloxada completa nun só host:

```bash
git clone https://github.com/axonops/axonops-containers.git
cd axonops-containers/docker-compose/00-axonops-platform
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose ps            # wait for all four services to report healthy
```

Despois abra <http://localhost:3000>. Un arranque en frío tarda de 2 a 3 minutos:
primeiro inicialízanse os dous almacéns de datos, e detrás deles soben
`axon-server` e o panel.

Os valores por defecto de `env.example` son valores de desenvolvemento. Antes de
executar unha pila que lle importe, defina `AXONOPS_ORG_NAME`,
`AXONOPS_DB_PASSWORD` e `AXONOPS_SEARCH_PASSWORD`: véxase
[docker-compose/README.gl.md](./docker-compose/README.gl.md#antes-de-executar-nada).

### Que pila

| Pila | Úsea para |
|---|---|
| [00-axonops-platform](./docker-compose/00-axonops-platform/) | executar AxonOps para clústeres que xa ten |
| [01-cassandra-cluster](./docker-compose/01-cassandra-cluster/) | ver o conxunto funcionando de extremo a extremo: a plataforma máis 3 nodos monitorizados |
| [02-saas-cassandra-cluster](./docker-compose/02-saas-cassandra-cluster/) | monitorizar un clúster dende AxonOps SaaS, sen plataforma que executar en local |
| [03-secure-3-rack-cluster](./docker-compose/03-secure-3-rack-cluster/) | modelar un clúster con forma de produción: autenticación, 3 racks, enderezamento fixo e JMX remoto |

Comparación completa, co número de contedores e a RAM cos valores por defecto:
[docker-compose/README.gl.md](./docker-compose/README.gl.md#cal-quero).

### Compose ou Kubernetes?

As dúas vías despregan as mesmas imaxes; diferéncianse en onde se executa a pila
e en que a opera.

| | Docker Compose | Kubernetes |
|---|---|---|
| **Onde** | un único host | un clúster |
| **Para que** | avaliación, demos, desenvolvemento, despregamentos pequenos nun só host | produción, alta dispoñibilidade, calquera cousa que deba sobrevivir a un host |
| **Plataforma AxonOps** | as pilas de [`docker-compose/`](./docker-compose/) | os charts de Helm `oci://ghcr.io/axonops/charts/*`: véxase [VERSIONS.md](VERSIONS.md#helm-charts) e [examples/AXONOPS_DEPLOYMENT.gl.md](./examples/AXONOPS_DEPLOYMENT.gl.md) |
| **Cassandra** | a imaxe [`cassandra/`](./cassandra/), executada directamente | a imaxe [`k8ssandra/`](./k8ssandra/) mediante o operador K8ssandra: véxase [examples/K8SSANDRA_DEPLOYMENT.gl.md](./examples/K8SSANDRA_DEPLOYMENT.gl.md) |
| **Escalado e conmutación por erro** | manuais | operador e planificador |

Os axentes reportan a `axon-server` igual nas dúas, así que un clúster
monitorizado por unha plataforma sobre Compose pode apuntarse despois a unha
sobre Kubernetes sen tocar os nodos monitorizados.

## Red Hat Universal Base Image (UBI)

Todos os contedores deste repositorio constrúense sobre **Red Hat Universal Base
Image (UBI) 9**, que achega seguridade, estabilidade e cumprimento de nivel
empresarial.

**Por que Red Hat UBI?**

- **Redistribuíble libremente**: non fai falta subscrición para usala nin redistribuíla
- **Seguridade empresarial**: actualizacións de seguridade e parches de CVE periódicos de Red Hat
- **Endurecida para produción**: superficie de ataque mínima, só cos paquetes esenciais
- **Lista para o cumprimento**: cumpre os requisitos de sectores regulados (finanzas, sanidade, administración pública)
- **Soporte a longo prazo**: base estable cun ciclo de vida predicible (RHEL 9 con soporte ata 2032)
- **Optimizada para contedores**: deseñada expresamente para cargas en contedores, cunha pegada mínima

**Máis información:**
- [O proxecto Red Hat UBI](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image)
- [Catálogo de contedores UBI 9](https://catalog.redhat.com/software/containers/search?q=ubi9)
- [Documentación de UBI](https://developers.redhat.com/products/rhel/ubi)

## Versións admitidas

Que versións de Apache Cassandra constrúe este repositorio decláranse unha soa
vez, na sección `build_matrix` de [versions.yaml](versions.yaml). As matrices dos
workflows, as versións por defecto, os destinos das etiquetas flotantes e as
notas de release derívanse todos de aí: ningún ficheiro de workflow nomea unha
versión de Cassandra.

```bash
./scripts/build-matrix.sh versions   # every version built
./scripts/build-matrix.sh newest     # what the `latest` tag resolves to
```

**A política:**

- **Engádese** cando Apache publicou o parche *e* k8ssandra publicou unha imaxe
  base `cass-management-api` correspondente. As dúas imaxes de Cassandra de aquí
  constrúense `FROM` esa base, así que a segunda condición non é negociable: unha
  versión engadida antes de que exista a súa base fai fallar todos os seus jobs de
  build. Cassandra 5.0.9 está hoxe exactamente nesa situación: publicada upstream,
  sen imaxe base e, polo tanto, non construída.
- **Consérvase** unha vez engadida. Un parche máis novo non retira un máis vello:
  todas as versións da matriz séguense reconstruíndo e escaneando na busca de CVE,
  así que un despregamento fixado a un parche antigo segue recibindo correccións.
- **Retírase** só cando a liña chega á súa fin de vida upstream, ou cando unha
  dependencia a volve imposible de construír. En calquera dos dous casos a liña
  permanece en `versions.yaml` marcada como `published: false` co motivo, no canto
  de borrarse.
- **Consérvase pero non se publica** cando os Dockerfiles se manteñen e as imaxes
  non se distribúen. Cassandra 4.0 e 4.1 están nese estado: o axente de AxonOps
  aínda non é compatible coas súas imaxes base con JDK 11. Póñase en contacto
  connosco se as precisa.

Publicadas actualmente: **Cassandra 5.0.1 – 5.0.8**, con `latest` e `5.0-latest`
resolvendo a 5.0.8. Véxase
[k8ssandra/README.gl.md](k8ssandra/README.gl.md#versións-de-cassandra-admitidas)
para o detalle por liña, e [VERSIONS.md](VERSIONS.md) para a etiqueta e o digest
actuais de cada imaxe publicada.

## Convencións do repositorio

- **Soporte multiarquitectura**: linux/amd64, linux/arm64
- **Publicadas en**: GitHub Container Registry, `ghcr.io/axonops/<image-name>:<tag>`
- **CI/CD automatizado**: GitHub Actions con probas exhaustivas
- **Escaneo de seguridade**: escaneo de vulnerabilidades con Trivy en todas as imaxes
- **Imaxes base**: Red Hat UBI 9 (fixadas por digest, por seguridade da cadea de subministración)
- **Versións actuais**: [VERSIONS.md](VERSIONS.md) lista a etiqueta e o digest actuais de cada imaxe e chart publicados. Xérase a partir de [versions.yaml](versions.yaml) con `./scripts/update-versions.sh`: edite o YAML, nunca o Markdown.
- **Matriz de build**: as versións de Cassandra que se constrúen decláranse unha soa vez, na sección `build_matrix` de [versions.yaml](versions.yaml), e os workflows lenas a través de `./scripts/build-matrix.sh`. Nunca escriba unha lista de versións nun ficheiro de workflow: véxase [Versións admitidas](#versións-admitidas).

## Seguridade

### Política de CVE

**Etiquetado inmutable:** todas as imaxes de contedor usan versionado inmutable.
Cando se descobren e se parchean CVE, publicamos versións NOVAS no canto de
sobrescribir etiquetas existentes.

**Incrementos de versión:**
- CVE críticos (severidade CRITICAL, HIGH): release de parche inmediata (por exemplo, `1.0.3` → `1.0.4`)
- CVE non críticos (MEDIUM, LOW): agrupados en releases mensuais
- Un incremento de versión de parche pode incluír: correccións de CVE, actualizacións de compoñentes (por exemplo, o axente de AxonOps), corrección de erros ou novas prestacións

**Comportamento da etiqueta `latest`:**
- A etiqueta `latest` apunta sempre á versión segura máis recente
- Ofrece actualizacións de seguridade automáticas se se usa a etiqueta latest
- **NON se recomenda para produción**: use versións concretas

**Despregamento en produción:**
- Fixe sempre versións inmutables concretas (por exemplo, `5.0.6-v0.1.110-1.0.5`)
- Non use nunca as etiquetas `latest`, `5.0-latest` nin `{version}-latest` en produción
- Revise as notas de release antes de actualizar
- Probe primeiro as actualizacións en entornos que non sexan de produción

**Notificacións de CVE:**
- Escaneos de seguridade nocturnos automatizados con Trivy
- Notificacións por correo dos novos CVE CRITICAL/HIGH
- Divulgación transparente nas notas de release

**Para os entornos de máxima seguridade**, véxase
[Despregamento con seguridade de referencia](#despregamento-con-seguridade-de-referencia).

---

### Despregamento con seguridade de referencia

O **despregamento baseado en digest** ofrece o máximo nivel de seguridade e
inmutabilidade para os despregamentos de contedores.

#### Que é o despregamento baseado en digest?

No canto de usar etiquetas (que poden ser mutables), despregue usando o digest
SHA256 da imaxe:

```yaml
# Tag-based (good)
image: ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Digest-based (best)
image: ghcr.io/axonops/k8ssandra/cassandra@sha256:412c85225...
```

#### Vantaxes

✅ **100 % inmutable**: exactamente a mesma imaxe sempre, para sempre

✅ **Resiste a manipulación de etiquetas**: non lle afecta que as etiquetas se cambien por accidente ou de forma maliciosa

✅ **Lista para o cumprimento**: cumpre os requisitos dos entornos regulados (finanzas, sanidade, administración pública)

✅ **Rastro de auditoría**: o digest no manifesto de despregamento é a proba criptográfica da imaxe exacta

✅ **Seguridade da cadea de subministración**: xunto coa verificación de sinaturas, dá unha procedencia completa

#### Atopar os digests das imaxes

**Método 1: dende a interface de GHCR**
1. Vaia ao paquete: https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra
2. Prema na versión concreta
3. Copie o digest SHA256 que se amosa

**Método 2: con Docker ou Podman**
```bash
# Pull the image first
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5

# Get digest
docker inspect ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5 \
  --format='{{index .RepoDigests 0}}'

# Output: ghcr.io/axonops/k8ssandra/cassandra@sha256:412c85225...
```

**Método 3: durante o workflow**
- Consulte os rexistros do workflow de GitHub Actions tras a publicación
- O digest imprímese na saída do build

#### Exemplo de despregamento en Kubernetes

**Manifesto K8ssandraCluster:**
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

#### Verificar as sinaturas

Todas as imaxes publicadas en GHCR asínanse con
[Cosign de Sigstore](https://github.com/sigstore/cosign), con sinatura sen chaves.

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

Se ten problemas co cosign local en macOS, use a imaxe de contedor oficial de
Cosign:

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

Isto usa o [contedor oficial de Cosign](https://github.com/sigstore/cosign) e
funciona de forma fiable en todas as plataformas.

**Unha verificación correcta demostra:**
- ✅ Que a imaxe a construíu o workflow oficial de GitHub Actions
- ✅ Que a imaxe non se manipulou
- ✅ Que a procedencia do build é trazable ata un commit e unha execución de workflow concretos

#### Esixir imaxes asinadas en Kubernetes

Para entornos de produción que requiren verificar a sinatura antes de despregar:

**Ferramentas de aplicación de políticas:**
- **Kyverno**: motor de políticas nativo de Kubernetes
- **OPA Gatekeeper**: Open Policy Agent para Kubernetes
- **Sigstore Policy Controller**: o controlador de admisión oficial de Sigstore

**Exemplo: política de Kyverno**

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

**Soporte dos provedores cloud:**
- **AWS EKS**: use Kyverno ou OPA Gatekeeper mediante Helm
- **Google GKE**: Binary Authorization con atestacións de Cosign
- **Azure AKS**: Azure Policy con Ratify + Cosign
- **Rancher/RKE**: Kyverno ou OPA Gatekeeper mediante Rancher Apps

Para a configuración detallada, consulte a documentación da súa distribución de
Kubernetes sobre controladores de admisión e aplicación de políticas de imaxe.

#### Boas prácticas

**Para clústeres de produción:**
1. ✅ Use despregamento baseado en digest
2. ✅ Verifique as sinaturas antes de despregar (imaxes asinadas)
3. ✅ Fixe o digest no control de versións (GitOps)
4. ✅ Documente a correspondencia digest → versión nas notas de release
5. ✅ Actualice os digests só tras probalos fóra de produción

**Para desenvolvemento e probas:**
- O despregamento baseado en etiquetas é aceptable, para iterar máis rápido
- Use o rexistro de imaxes de desenvolvemento para as probas

**Actualizar os digests:**
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

## Desenvolvemento

**Estrutura de ramas:**
- `development`: a rama por defecto, commitéase directamente aquí
- `main`: só releases de produción (require PR)
- `feature/*`: opcional, para prestacións complexas

Véxase [DEVELOPMENT.md](./DEVELOPMENT.md) para as pautas completas.

**Fluxo de traballo do desenvolvedor:**
```bash
# Work directly on development
git checkout development && git pull origin development
git add . && git commit -S -m "Add feature" && git push origin development

# For production: create PR development → main (approval required)
```

### Estándares de seguridade de contedores (TODOS os compoñentes)

**Todos os contedores que construímos DEBEN seguir estas prácticas de
seguridade:**

1. **Fixado por digest (seguridade da cadea de subministración)**
   - Fixe **SEMPRE** as imaxes base por digest SHA256, NUNCA por etiqueta
   - As etiquetas son mutables: poden substituírse de forma maliciosa
   - Os digests son inmutables: están garantidos criptograficamente
   - Exemplo:
     ```dockerfile
     # CORRECT
     FROM upstream/image@sha256:abc123...

     # WRONG - Supply chain vulnerability!
     FROM upstream/image:latest
     FROM upstream/image:v1.0.0
     ```

2. **Sinatura de contedores (autenticidade)**
   - **TODAS** as imaxes publicadas DEBEN asinarse con Cosign
   - Use a sinatura sen chaves con OIDC de GitHub (sen xestión de segredos)
   - Asine por digest inmediatamente despois do build
   - Publique en `ghcr.io/axonops/<component>/<image-name>:tag`

3. **Verificación e probas**
   - Verifique as sumas de comprobación dos artefactos descargados (RPM, tarballs, etc.)
   - Verifique que o digest da imaxe base corresponde á versión agardada
   - Detección automatizada de erros de arranque
   - Escaneo de seguridade con Trivy antes de publicar

**Por que importan estes estándares:**
- Evitan ataques á cadea de subministración (imaxes base maliciosas)
- Garanten a autenticidade das imaxes (sinaturas de Cosign)
- Achegan un rastro de auditoría completo (digests + sinaturas)
- Cumpren os requisitos de cumprimento dos entornos regulados

## Publicación de releases

### Publicación de desenvolvemento

**Propósito:** publicar imaxes asinadas no rexistro de desenvolvemento, para
probalas antes dunha release de produción.

**Rexistro:** `ghcr.io/axonops/development/<component>/<image-name>`

**Exemplo:** `ghcr.io/axonops/development/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0`

**Características:**
- Todas as imaxes están asinadas con Cosign (igual ca en produción)
- Usa os mesmos estándares de seguridade ca produción (fixado por digest, sumas de comprobación, verificación)
- Permite probar con versións concretas
- Non se crean GitHub Releases
- Etiquétase dende a rama `development`

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

**Úsea para:** probas de prestacións, probas de integración e validación de QA
antes de produción.

---

### Publicación de produción

**Propósito:** publicar imaxes estables e probadas no rexistro de produción.

**Rexistro:** `ghcr.io/axonops/<image-name>`

**Características:**
- Inmutable (a validación de versión impide sobrescrituras)
- Crea GitHub Releases
- Etiquétase só dende a rama `main`
- Só despois de probar en desenvolvemento

**Requisitos previos:**
- Os cambios fusionados en `development` e probados
- As imaxes de desenvolvemento validadas (se se publicaron)
- A PR de `development` a `main` aprobada e fusionada

**Proceso:**

**Paso 1: crear a etiqueta de git na rama main**

**IMPORTANTE:** as etiquetas deben crearse na rama `main`. O workflow de
publicación valídao.

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main

# Tag the commit
git tag 1.0.0

# Push tag to remote
git push origin 1.0.0
```

A etiqueta pode ter calquera nome (por exemplo, `1.0.0`, `v1.0.0`,
`release-2024-12`). Marca a instantánea exacta do código dende a que construír.

**Nota:** se etiqueta un commit que non está en `main`, o workflow de publicación
fallará cun erro.

**Paso 2: lanzar o workflow de publicación**

Pode lanzar o workflow de publicación dende a **CLI de GitHub** ou dende a
**interface de GitHub**.

#### Opción A: a CLI de GitHub

Instálea e autentíquese (só a primeira vez):
```bash
# macOS
brew install gh

# Linux
# See: https://github.com/cli/cli#installation

# Authenticate
gh auth login
```

Lance o workflow de publicación asinada:
```bash
gh workflow run <component>-publish-signed.yml \
  -f main_git_tag=1.0.0 \
  -f container_version=1.0.0
```

**Explicación dos argumentos:**
- `-f main_git_tag=1.0.0`: a etiqueta de git na rama main da que facer checkout e construír (a que creou no paso 1)
- `-f container_version=1.0.0`: a versión de contedor para as imaxes de GHCR (por exemplo, produce `5.0.6-v0.1.110-1.0.5`)

**Nota:** use os workflows `-signed` (`k8ssandra-publish-signed.yml`) para as
releases novas. Publican nas novas rutas de imaxe con sinaturas criptográficas.
Os workflows antigos seguen aí por compatibilidade, pero están obsoletos.

Siga o progreso:
```bash
gh run watch
```

#### Opción B: a interface de GitHub

1. Vaia á lapela **Actions** do repositorio de GitHub
2. Seleccione o workflow de publicación (por exemplo, **K8ssandra Publish to GHCR**)
3. Prema o botón **Run workflow** (arriba á dereita)
4. Aparece un formulario con estes campos:
   - **main_git_tag**: introduza a etiqueta de git da rama main creada no paso 1 (por exemplo, `1.0.0`)
     - Determina que código se constrúe
   - **container_version**: introduza a versión de contedor (por exemplo, `1.0.0`)
     - Pasa a ser a versión de contedor das imaxes publicadas
     - Exemplo: `5.0.6-v0.1.110-1.0.5`, onde `1.0.0` é a versión de contedor
5. Prema **Run workflow** para comezar

**Paso 3: execución do workflow**

O workflow de publicación asinada:
- Valida que a etiqueta está na rama main (falla se non)
- Valida que `container_version` non existe xa en GHCR (falla se está duplicada)
- Fai checkout do commit de `main_git_tag` (a instantánea exacta do código)
- Executa a batería de probas completa
- Constrúe imaxes multiarquitectura (amd64, arm64)
- Sobe a GHCR con etiquetas multidimensionais
- **Asina as imaxes** con Cosign de Sigstore (sen chaves, con OIDC de GitHub)
- Volve subir as etiquetas para que se amosen correctamente na interface de GHCR
- Crea unha GitHub Release chamada `<component>-signed-<container_version>`

**As imaxes asínanse** con sinatura sen chaves e con entradas no rexistro de
transparencia. As sinaturas poden verificarse con `cosign verify` (véxase
[Verificar as sinaturas](#verificar-as-sinaturas)).

**Paso 4: verificar a release**

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

Todas as imaxes de produción están asinadas criptograficamente. A verificación da
sinatura demostra que a imaxe a construíron os workflows oficiais e que non se
manipulou. Véxase
[Despregamento con seguridade de referencia](#despregamento-con-seguridade-de-referencia)
para máis detalles.

### Documentación de release por compoñente

Cada compoñente ten a súa documentación de release detallada:
- [Proceso de release de K8ssandra](./k8ssandra/RELEASE.md)
- [Proceso de release do Schema Registry](./axonops-schema-registry/RELEASE.md)

## Agradecementos

### Apache Cassandra
Queremos expresar o noso recoñecemento á comunidade de
[Apache Cassandra](https://cassandra.apache.org/) polo seu magnífico traballo e
as súas achegas ao campo das bases de datos distribuídas. Apache Cassandra é un
sistema xestor de bases de datos NoSQL distribuído, de tipo wide-column, libre e
de código aberto, deseñado para manexar grandes volumes de datos repartidos entre
moitos servidores convencionais, con alta dispoñibilidade e sen ningún punto
único de fallo.

Máis información:
- [Web de Apache Cassandra](https://cassandra.apache.org/)
- [Apache Cassandra en GitHub](https://github.com/apache/cassandra)
- [Documentación de Apache Cassandra](https://cassandra.apache.org/doc/latest/)

### K8ssandra
Recoñecemos o traballo de [K8ssandra](https://k8ssandra.io/), que achega un
excelente operador de Kubernetes e ferramentas de xestión para Apache Cassandra.
K8ssandra é unha plataforma lista para produción que executa Apache Cassandra
sobre Kubernetes, con copia de seguranza e restauración, reparacións e
capacidades de monitorización.

Máis información:
- [Web de K8ssandra](https://k8ssandra.io/)
- [K8ssandra en GitHub](https://github.com/k8ssandra/k8ssandra-operator)
- [Documentación de K8ssandra](https://docs.k8ssandra.io/)

### AxonOps Schema Registry
Recoñecemos o traballo de
[AxonOps Schema Registry](https://github.com/axonops/axonops-schema-registry),
que achega un Schema Registry compatible con Confluent con soporte de varios
backends de almacenamento, entre eles PostgreSQL, MySQL e Apache Cassandra.

Máis información:
- [AxonOps Schema Registry en GitHub](https://github.com/axonops/axonops-schema-registry)

## Licenza

Este proxecto publícase baixo a licenza Apache 2.0: véxase o ficheiro
[LICENSE](LICENSE) para os detalles.

## Avisos legais

Este proxecto pode conter marcas ou logotipos de proxectos, produtos ou servizos.
Todo uso de marcas ou logotipos de terceiros está suxeito ás políticas deses
terceiros.

### Marcas rexistradas

- **AxonOps** é unha marca rexistrada de AxonOps Limited
- **Apache**, **Apache Cassandra** e **Cassandra** son marcas da Apache Software Foundation ou das súas filiais en Canadá, Estados Unidos e outros países
- **Apache Kafka** e **Kafka** son marcas da Apache Software Foundation
- **K8ssandra** é unha marca da Apache Software Foundation
- **Docker** é unha marca ou marca rexistrada de Docker, Inc. en Estados Unidos e outros países
- **Podman** é unha marca de Red Hat, Inc.
- **OpenSearch** é unha marca de Amazon.com, Inc. ou das súas filiais
- **Kubernetes** é unha marca rexistrada de The Linux Foundation

---

<div align="center">

**Feito con ❤️ por [AxonOps](https://axonops.com)**

</div>
