# Contedores K8ssandra de AxonOps

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

[![Paquete GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra)

Contedores Docker de Apache Cassandra co axente de monitorización e xestión de
AxonOps integrado, pensados para despregarse en Kubernetes co operador K8ssandra.

## Índice

- [Visión xeral](#visión-xeral)
- [Imaxes de Docker precompiladas](#imaxes-de-docker-precompiladas)
  - [Imaxes dispoñibles](#imaxes-dispoñibles)
  - [Versións de Cassandra admitidas](#versións-de-cassandra-admitidas)
- [Boa práctica en produción](#boa-práctica-en-produción)
- [Inicio rápido con Docker/Podman](#inicio-rápido-con-dockerpodman)
  - [Uso con Kubernetes (K8ssandra)](#uso-con-kubernetes-k8ssandra)
- [Requisitos previos](#requisitos-previos)
- [Liñas de Cassandra](#liñas-de-cassandra)
- [Primeiros pasos](#primeiros-pasos)
- [Construír as imaxes de Docker](#construír-as-imaxes-de-docker)
  - [Engadir soporte para novas versións de Cassandra](#engadir-soporte-para-novas-versións-de-cassandra)
  - [Actualizar para novas versións da Management API de k8ssandra](#actualizar-para-novas-versións-da-management-api-de-k8ssandra)
- [Despregar en Kubernetes](#despregar-en-kubernetes)
  - [Usar a configuración de exemplo](#usar-a-configuración-de-exemplo)
  - [Verificar o despregamento](#verificar-o-despregamento)
  - [Conectarse ao clúster](#conectarse-ao-clúster)
  - [Opcións de configuración principais](#opcións-de-configuración-principais)
- [Configuración](#configuración)
  - [Configuración do axente de AxonOps](#configuración-do-axente-de-axonops)
  - [Variables de entorno do contedor](#variables-de-entorno-do-contedor)
  - [Comprobación de saúde](#comprobación-de-saúde)
- [Referencia de scripts](#referencia-de-scripts)
  - [scripts/install_k8ssandra.sh](#scriptsinstall_k8ssandrash)
  - [scripts/rebuild.sh](#scriptsrebuildsh)
- [Exemplos](#exemplos)
  - [examples/k8ssandra/cluster-axonops-ubi.yaml](#examplesk8ssandracluster-axonops-ubiyaml)
  - [Personalizar o exemplo](#personalizar-o-exemplo)
- [Pipeline de CI/CD](#pipeline-de-cicd)
  - [Builds e probas automatizados](#builds-e-probas-automatizados)
- [Prestacións do contedor](#prestacións-do-contedor)
  - [Banner de versión ao arrancar](#banner-de-versión-ao-arrancar)
- [Monitorización con AxonOps](#monitorización-con-axonops)
- [Resolución de problemas](#resolución-de-problemas)
  - [Comprobar a versión do contedor](#comprobar-a-versión-do-contedor)
  - [Problemas de conexión do axente](#problemas-de-conexión-do-axente)
  - [Erros ao descargar a imaxe](#erros-ao-descargar-a-imaxe)
  - [O clúster non arranca](#o-clúster-non-arranca)
- [Consideracións para produción](#consideracións-para-produción)

## Visión xeral

Este repositorio ofrece imaxes de Docker preconfiguradas que combinan:
- Apache Cassandra 5.0.x
- A Management API de K8ssandra
- O axente de AxonOps, para monitorización e xestión
- [cqlai](https://github.com/axonops/cqlai), unha shell de CQL moderna

Estes contedores están optimizados para despregamentos en Kubernetes co operador
K8ssandra e inclúen pipelines de CI/CD automatizados para construílos e
publicalos en GitHub Container Registry.

**Nota:** actualmente só se publican versións de Cassandra 5.0. O soporte de
Cassandra 4.0 e 4.1 está no repositorio, pero aínda non se publica por problemas
de compatibilidade do axente de AxonOps. Póñase en contacto connosco se precisa
soporte de 4.0 ou 4.1.

## Imaxes de Docker precompiladas

Hai imaxes precompiladas dispoñibles en GitHub Container Registry (GHCR). É a
forma máis sinxela de comezar.

### Imaxes dispoñibles

As imaxes usan unha estratexia de etiquetado tridimensional que inclúe o
seguimento da versión da API de k8ssandra:

| Patrón de etiqueta | Exemplo | Descrición | Caso de uso |
|-------------|---------|-------------|----------|
| `{CASS}-v{K8S_API}-{AXON}` | `5.0.6-v0.1.110-1.0.0` | Totalmente inmutable (as 3 versións) | **Produción**: fixe versións exactas para unha auditabilidade completa |
| `@sha256:<digest>` | `@sha256:412c852...` | Baseada en digest (inmutable) | **Máxima seguridade**: imaxe garantida criptograficamente (véxase [Despregamento con seguridade de referencia](../README.gl.md#despregamento-con-seguridade-de-referencia)) |
| `{CASS}-v{K8S_API}` | `5.0.6-v0.1.110` | O último AxonOps para esa combinación de Cassandra + k8ssandra | Seguir as actualizacións de AxonOps para unhas versións concretas de Cassandra + k8ssandra |
| `{CASS}` | `5.0.6` | A última API de k8ssandra + AxonOps para ese menor de Cassandra | Seguir as actualizacións de k8ssandra + AxonOps dun menor de Cassandra |
| `{MAJOR}-latest` | `5.0-latest` | O último menor do maior 5.0 de Cassandra | Seguir o último menor 5.0.x de Cassandra e os seus compoñentes |
| `latest` | `latest` | A última de todos os maiores de Cassandra | Probas rápidas (migra a 5.1, 5.2 ou 6.0 cando se publiquen) |

**Dimensións do versionado:**
- **CASS**: a versión de Cassandra (por exemplo, 5.0.6)
- **K8S_API**: a versión da Management API de k8ssandra (por exemplo, v0.1.110)
- **AXON**: a versión do contedor de AxonOps (por exemplo, 1.0.0, en SemVer)

**Exemplos de etiquetado:**

Cando se constrúe `5.0.6-v0.1.110-1.0.0` (e é a última de todo):
- `5.0.6-v0.1.110-1.0.0` (inmutable: non cambia nunca)
- `5.0.6-v0.1.110` (flotante: reetiquétase a builds de AxonOps máis novos)
- `5.0.6` (flotante: reetiquétase cando se actualizan a API de k8ssandra ou AxonOps)
- `5.0-latest` (flotante: reetiquétase cando se publica un menor 5.0.x máis novo, por exemplo 5.0.7)
- `latest` (flotante: **móvese a 5.1, 5.2 ou 6.0 cando se publique un novo maior de Cassandra**)

### Versións de Cassandra admitidas

A lista de versións vive nun único sitio: a sección `build_matrix` de
[`versions.yaml`](../versions.yaml), na raíz do repositorio. Todas as matrices dos
workflows, as etiquetas flotantes e as versións por defecto derívanse de aí, así
que este README non pode quedar desincronizado co que se constrúe de verdade. Lea
a lista actual con:

```bash
./scripts/build-matrix.sh versions      # every published version
./scripts/build-matrix.sh newest        # what `latest` resolves to
```

**Publicadas actualmente:**
- **5.0.x:** 5.0.1, 5.0.2, 5.0.3, 5.0.4, 5.0.5, 5.0.6, 5.0.7 e 5.0.8 (8 versións).
  A máis recente é 5.0.8, así que `latest` e `5.0-latest` resolven a ela.

**Política de soporte.** Unha release de parche de Cassandra engádese á matriz
cando se cumpren dúas cousas: que Apache a publicase e que k8ssandra publicase
unha imaxe base `cass-management-api` correspondente. Estas imaxes constrúense
`FROM` esa base, así que a segunda condición é estrita: unha versión engadida
antes de tempo fai fallar todos os seus jobs de build con «No k8ssandra version
found». Non se quita nada da matriz cando aparece un parche máis novo; os parches
antigos séguense construíndo e escaneando, de xeito que un despregamento existente
pode quedar na súa versión fixada e seguir recibindo reconstrucións. Unha liña só
se retira cando chega á súa fin de vida upstream, e iso rexístrase en
`versions.yaml` co motivo.

**Non construídas:**
- **5.0.9:** publicada por Apache, pero k8ssandra non publica ningunha imaxe
  `cass-management-api` para 5.0.9. Comprobe se xa apareceu con:

  ```bash
  curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=5.0.9-ubi" | \
    jq -r '.results[].name'
  ```

  Cando apareza, siga
  [Engadir soporte para novas versións de Cassandra](#engadir-soporte-para-novas-versións-de-cassandra).
- **4.0.x e 4.1.x:** os Dockerfiles mantéñense en `k8ssandra/4.0/` e
  `k8ssandra/4.1/`, pero non se publica ningunha imaxe: o axente de AxonOps aínda
  non é compatible coas imaxes base de 4.x baseadas en JDK 11. Ambas as liñas
  están declaradas `published: false` en `versions.yaml` con ese motivo, e todos
  os workflows sáltanas. Póñase en contacto connosco se as precisa.

Consulte todas as etiquetas dispoñibles:
[GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/k8ssandra%2Fcassandra)

## Boa práctica en produción

⚠️ **Usar CALQUERA etiqueta `-latest` en produción é un antipatrón.** Isto inclúe
`latest`, `5.0-latest` e `5.0.6-latest`, porque:
- **Non hai rastro de auditoría**: non pode determinar que versión exacta estaba despregada nun momento dado
- **Actualizacións inesperadas**: Kubernetes pode descargar unha imaxe nova ao reiniciar un pod, provocando cambios de versión non buscados
- **Dificultades para volver atrás**: non pode retroceder de forma fiable a unha versión anterior
- **Problemas de cumprimento**: moitos marcos normativos esixen un seguimento de versións inmutable

👍 **Estratexias de despregamento recomendadas (de maior a menor seguridade):**

1. **🥇 Referencia de ouro: baseada en digest** (máxima seguridade)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra@sha256:412c852252ec4ebcb8d377a505881828a7f6a5f9dc725cc4f20fda2a1bcb3494"
   ```
   - 100 % inmutable, garantido criptograficamente
   - Obrigatoria en entornos regulados
   - Véxase [Despregamento con seguridade de referencia](../README.gl.md#despregamento-con-seguridade-de-referencia)

2. **🥈 Etiqueta inmutable** (o estándar de produción)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5"
   ```
   - Fixada a unha versión concreta (Cassandra 5.0.6 + API de k8ssandra v0.1.110 + AxonOps 1.0.5)
   - Doada de ler e de xestionar
   - Mantén un rastro de auditoría completo

3. **🥉 Etiquetas latest** (só desenvolvemento e probas)
   ```yaml
   serverImage: "ghcr.io/axonops/k8ssandra/cassandra:latest"
   ```
   - Iteración rápida
   - NON para produción
   - Úseas só para probas de concepto e probas

**Xestión de CVE:** véxase a [política de CVE](../README.gl.md#política-de-cve)
para saber como tratamos as vulnerabilidades de seguridade e as releases de
versión.

**Actualización de imaxes con K8ssandra:** cando actualice a imaxe de contedor no
seu manifesto K8ssandraCluster, o operador K8ssandra encárgase do proceso de
actualización progresiva. Véxase a
[documentación do operador K8ssandra](https://docs.k8ssandra.io/) para os detalles
dos procedementos de actualización e as boas prácticas.

## Inicio rápido con Docker/Podman

Execute unha instancia de Cassandra dun só nodo en local, para probas:

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

**⚠️ Para uso en produción, fixe unha versión inmutable concreta:**
```bash
docker pull ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5
```

### Uso con Kubernetes (K8ssandra)

Para despregamentos en Kubernetes, use a imaxe co operador K8ssandra:

```bash
export IMAGE_NAME="ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.5"
export AXON_AGENT_KEY="your-key"
export AXON_AGENT_ORG="your-org"
export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"

cat examples/k8ssandra/cluster-axonops-ubi.yaml | envsubst | kubectl apply -f -
```

Véxase [Despregar en Kubernetes](#despregar-en-kubernetes) para as instrucións
detalladas.

## Requisitos previos

- Un clúster de Kubernetes (local ou en cloud)
- `kubectl` configurado para acceder ao seu clúster
- Helm 3.x
- Docker (para os builds locais)
- `envsubst` (para substituír variables de entorno nos ficheiros YAML)
  - macOS: `brew install gettext`
  - Linux: adoita vir preinstalado, ou `apt install gettext` / `yum install gettext`
- Unha conta de AxonOps cunha chave de API válida e un identificador de organización (véxase a [guía de configuración de AxonOps Cloud](https://docs.axonops.com/get_started/cloud/))

## Liñas de Cassandra

Que versións se constrúen, e a política detrás diso, está en
[Versións de Cassandra admitidas](#versións-de-cassandra-admitidas), máis arriba;
a lista non se repite aquí, porque a copia que adoitaba estar nesta sección dicía
da 5.0.1 á 5.0.6 moito despois de que se publicasen a 5.0.7 e a 5.0.8. O que segue
é o que diferencia unhas liñas doutras.

| Liña | Imaxe base | JDK | Directorio de build | Publicada |
|------|------------|-----|-----------------|-----------|
| 5.0 | `k8ssandra/cass-management-api:5.0-ubi` | 17 | `k8ssandra/5.0/` | Si |
| 4.1 | `k8ssandra/cass-management-api:4.1-ubi` | 11 | `k8ssandra/4.1/` | Non: compatibilidade do axente de AxonOps |
| 4.0 | `k8ssandra/cass-management-api:4.0-ubi` | 11 | `k8ssandra/4.0/` | Non: compatibilidade do axente de AxonOps |

Todas as liñas inclúen o axente de AxonOps, cqlai e jemalloc. As imaxes base
fíxanse por digest, nunca pola etiqueta amosada arriba: véxase
[Seguridade da cadea de subministración](#engadir-soporte-para-novas-versións-de-cassandra).

## Primeiros pasos

**Nota:** os comandos seguintes supoñen que está no directorio `k8ssandra/`, agás
que se indique outra cousa.

### 1. Instalar o operador K8ssandra

Execute o script de instalación para preparar o operador K8ssandra e as súas
dependencias:

```bash
./scripts/install_k8ssandra.sh
```

Este script:
- Instala cert-manager (v1.19.1) no espazo de nomes `cert-manager`
- Engade o repositorio de Helm de K8ssandra
- Instala o operador K8ssandra (v1.29.0) no espazo de nomes `k8ssandra-operator`

### 2. Configurar as variables de entorno

Defina as súas credenciais de AxonOps:

```bash
export AXON_AGENT_KEY="your-axonops-agent-key" # Obtained from AxonOps Cloud Console
export AXON_AGENT_ORG="your-organization-id" # AxonOps Cloud organization name
export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"
```

Opcional: indique un nome de imaxe propio (por defecto usa ttl.sh cun TTL dunha
hora):

```bash
export IMAGE_NAME="your-registry/your-image:tag"
```

### 3. Construír e despregar

Use o script de reconstrución para construír, subir e despregar o seu clúster:

```bash
# Change to the version directory (contains Dockerfile)
cd 5.0

# Run the rebuild script (builds from current directory)
../scripts/rebuild.sh
```

O script:
1. Elimina calquera despregamento de clúster existente
2. Limpa as imaxes de contedor antigas
3. Constrúe unha nova imaxe de Docker
4. Sobe a imaxe ao rexistro
5. Aplica a configuración do clúster con substitución de variables de entorno
6. Desprega o clúster en Kubernetes

## Construír as imaxes de Docker

**Nota:** os comandos desta sección supoñen que está no directorio `k8ssandra/`.

Se prefire construír as imaxes vostede mesmo no canto de usar as
[imaxes precompiladas](#imaxes-de-docker-precompiladas):

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

**Argumentos de build obrigatorios:**
- `CASSANDRA_VERSION`: a versión completa de Cassandra (por exemplo, 5.0.6)
- `MAJOR_VERSION`: a versión maior.menor correspondente ao directorio (por exemplo, 5.0)
- `K8SSANDRA_BASE_DIGEST`: o digest SHA256 da imaxe base de k8ssandra (seguridade da cadea de subministración)
- `K8SSANDRA_API_VERSION`: a versión da Management API de k8ssandra (por exemplo, 0.1.110)
- `CQLAI_VERSION`: a versión de cqlai que instalar (véxase a [última release](https://github.com/axonops/cqlai/releases))

**Argumentos de build opcionais (por defecto valen «unknown» se non se
proporcionan):**
- `BUILD_DATE`: a marca de tempo do build (formato ISO 8601, por exemplo, `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF`: o SHA do commit de git (por exemplo, `$(git rev-parse HEAD)`)
- `VERSION`: a versión do contedor (por exemplo, 1.0.0)
- `GIT_TAG`: o nome da etiqueta de git (para as ligazóns de release/tag do banner)
- `GITHUB_ACTOR`: o usuario que lanzou o build (para o rastro de auditoría)
- `IS_PRODUCTION_RELEASE`: póñao a `true` para produción (por defecto: `false`)
- `IMAGE_FULL_NAME`: o nome completo da imaxe coa etiqueta (amósase no banner de arranque)

**Nota:** os argumentos opcionais enriquecen o banner de arranque e as etiquetas
de metadatos, pero non fan falta para o funcionamento.

### Construír sen a Management API

O mesmo Dockerfile constrúe a imaxe de Cassandra independente que se publica como
`ghcr.io/axonops/cassandra/cassandra`. Pase `INCLUDE_MGMT_API=false` e o build
elimina `/opt/management-api` e `/opt/cdc_agent`, quita o axente Java da
Management API de `cassandra-env.sh` e deixa que o entrypoint arranque Cassandra
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

`INCLUDE_MGMT_API` vale `true` por defecto, así que os builds de K8ssandra non se
ven afectados. Véxase [cassandra/README.gl.md](../cassandra/README.gl.md) para a
imaxe independente, o seu esquema de etiquetado e as súas variables de entorno
`CASSANDRA_*`.

### Engadir soporte para novas versións de Cassandra

Cando se publica unha nova versión de Cassandra (por exemplo, 5.0.7), siga estes
pasos:

**1. Obteña o digest da imaxe base de k8ssandra:**

```bash
# Find the latest k8ssandra API version for the new Cassandra version
VERSION="5.0.7"
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${VERSION}-ubi" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'].startswith('${VERSION}-ubi-v')]; \
  results.sort(key=lambda x: x['name'], reverse=True); \
  print(f\"Tag: {results[0]['name']}\nDigest: {results[0]['digest']}\") if results else print('Not found')"
```

Isto amosará algo así:
```
Tag: 5.0.7-ubi-v0.1.112
Digest: sha256:newdigest123...
```

**2. Actualice a variable de repositorio `K8SSANDRA_VERSIONS`:**

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

**3. Engada a versión a `versions.yaml`:**

A matriz de build vive nun único sitio. Engada a nova versión ao final da lista
`versions` da súa liña, na sección `build_matrix` de
[`versions.yaml`](../versions.yaml). A lista vai da máis antiga á máis recente, e
a última entrada é a onde resolven as etiquetas flotantes `latest` e
`{line}-latest`, así que a orde importa e nada a ordena por vostede:

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

Non hai que cambiar ningún ficheiro de workflow. Todas as matrices, o equivalente
de `ALL_VERSIONS` e as condicións das etiquetas flotantes derívanse desa lista con
`scripts/build-matrix.sh`.

**4. Compróbeo antes de subir:**

```bash
./scripts/build-matrix.sh check \
  --k8ssandra-versions "$(gh variable get K8SSANDRA_VERSIONS --repo axonops/axonops-containers)"
```

Isto falla se a nova versión non ten imaxe base `cass-management-api`: a
comprobación que, se non, lle custaría un build de 15 minutos descubrir. Os
workflows de publicación e de build e probas executan o mesmo comando antes de
construír nada.

**5. Probe e publique:**

```bash
# Development test
git tag vdev-5.0.7-test
git push origin vdev-5.0.7-test
gh workflow run k8ssandra-development-publish-signed.yml \
  -f dev_git_tag=vdev-5.0.7-test \
  -f container_version=1.0.0

# If tests pass, publish to production via main branch
```

### Actualizar para novas versións da Management API de k8ssandra

Cando k8ssandra publica unha nova versión da Management API (por exemplo,
v0.1.111) para versións de Cassandra existentes:

**1. Obteña os digests novos de todas as versións de Cassandra afectadas:**

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

**2. Actualice a variable `K8SSANDRA_VERSIONS` coa nova versión de API:**

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

**3. Incremente a versión do contedor de AxonOps:**

Como a versión da API de k8ssandra é unha actualización de compoñente, incremente
a versión MENOR:
- Actual: `1.0.0`
- Nova: `1.1.0` (suba MENOR por actualización de compoñente)

**4. Probe e publique:**

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

**Nota:** k8ssandra adoita publicar novas versións da Management API mensualmente.
O workflow nocturno de comprobación de versións (por implementar) detectaraas
automaticamente.

**⚠️ Aviso sobre a seguridade da cadea de subministración:**

Os nosos Dockerfiles estenden as imaxes base de k8ssandra fixándoas por digest
(non por etiqueta) para evitar ataques á cadea de subministración:

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
FROM docker.io/k8ssandra/cass-management-api@sha256:aa2de19866f3487abe0dff65e6b74f5a68c6c5a7d211b5b7a3e0b961603ba5af

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM docker.io/k8ssandra/cass-management-api:5.0.6-ubi
```

**Por que importa fixar por digest:**
- As etiquetas poden substituírse de forma maliciosa (mesma etiqueta, imaxe maliciosa distinta)
- Os digests son criptograficamente inmutables: non poden cambiarse
- Evita comprometer en silencio a súa cadea de subministración de contedores
- É a boa práctica do sector para os builds de contedores de produción

**Ao estender CALQUERA imaxe de contedor:**
1. Obteña o digest con: `docker inspect <image:tag> --format='{{.RepoDigests}}'`
2. Use `FROM image@digest` no seu Dockerfile
3. Documente a etiqueta de versión nun comentario, para que se lea ben

**Seguridade da cadea de subministración:**

Os nosos contedores estenden as imaxes base de `k8ssandra/cass-management-api`.
Por seguridade da cadea de subministración, fixamos as imaxes base por digest
(inmutable) no canto de por etiqueta. `K8SSANDRA_BASE_DIGEST` asocia versións de
Cassandra a digests de imaxe verificados, o que evita ataques á cadea de
subministración nos que as imaxes upstream poderían substituírse de forma
maliciosa.

A correspondencia en si non se reproduce aquí. Vive na variable de repositorio
`K8SSANDRA_VERSIONS`, coa chave `{CASSANDRA_VERSION}+{K8SSANDRA_API_VERSION}`, e é
o que len os builds. A copia que adoitaba estar nesta sección estaba fixada á API
de k8ssandra v0.1.120 e xa a adiantara a v0.1.124: todos os seus digests eran
incorrectos, e nada en CI podía advertilo. Lea a correspondencia en vivo con:

```bash
gh variable get K8SSANDRA_VERSIONS --repo axonops/axonops-containers | jq .
```

`scripts/build-matrix.sh check --k8ssandra-versions "$(gh variable get K8SSANDRA_VERSIONS --repo axonops/axonops-containers)"`
verifica que todas as versións da matriz de build teñen unha entrada alí; os
workflows de publicación e de build e probas execútano antes de construír nada.

**Como obter os digests das versións novas de k8ssandra:**

Cando k8ssandra publica unha versión nova de Cassandra, obteña o digest coa API de
Docker Hub:

```bash
# For a specific version (e.g., 5.0.7)
VERSION="5.0.7"
curl -sL "https://hub.docker.com/v2/repositories/k8ssandra/cass-management-api/tags?page_size=100&name=${VERSION}-ubi" | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  results = [r for r in data.get('results', []) if r['name'].startswith('${VERSION}-ubi')]; \
  [print(f\"Version: {r['name']}\nDigest: {r['digest']}\") for r in results[:1]]"
```

Ou consiga todas as versións 5.0.x dunha vez:

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

Unha vez teña o digest, actualice a variable de repositorio `K8SSANDRA_VERSIONS`
coa nova chave composta versión+digest.

## Despregar en Kubernetes

**Nota:** os comandos desta sección supoñen que está no directorio `k8ssandra/`.

### Usar a configuración de exemplo

`examples/k8ssandra/cluster-axonops-ubi.yaml` é un modelo para despregar un
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

### Verificar o despregamento

Tras o despregamento, verifique que o seu clúster está a funcionar:

```bash
# Check cluster status
kubectl get k8ssandraclusters -n k8ssandra-operator

# Watch pods come up (wait for all to show Running and Ready)
kubectl get pods -n k8ssandra-operator -w

# Check detailed cluster status
kubectl describe k8ssandracluster <cluster-name> -n k8ssandra-operator
```

Todos os pods de Cassandra deberían amosar `2/2` na columna READY cando arrancasen
de todo.

### Conectarse ao clúster

#### Con cqlsh

Conéctese directamente a un pod de Cassandra:

```bash
kubectl exec -it <pod-name> -n k8ssandra-operator -c cassandra -- cqlsh
```

#### Acceso externo (port-forward)

> **Nota:** o port-forward vale para desenvolvemento local e probas. En entornos
> de produción (AWS, GCP, Azure, etc.), valore usar un servizo LoadBalancer, un
> controlador de Ingress ou acceso por VPN, segundo os seus requisitos de
> seguridade.

Para conectarse dende fóra do clúster de Kubernetes (por exemplo, dende a súa
máquina local):

1. Obteña as credenciais do superusuario:
   ```bash
   # Username
   kubectl get secret <cluster-name>-superuser -n k8ssandra-operator -o jsonpath='{.data.username}' | base64 -d

   # Password
   kubectl get secret <cluster-name>-superuser -n k8ssandra-operator -o jsonpath='{.data.password}' | base64 -d
   ```

2. Arranque o port-forward:
   ```bash
   kubectl port-forward svc/<cluster-name>-dc1-service 9042:9042 -n k8ssandra-operator
   ```

3. Conéctese con cqlsh ou con calquera cliente CQL a `localhost:9042`, coas
   credenciais do paso 1.

#### AxonOps Workbench

[AxonOps Workbench](https://axonops.com/workbench) é un IDE de escritorio gratuíto
para que desenvolvedores e DBA se conecten a clústeres de Cassandra e os
xestionen. Ofrece unha interface moderna para lanzar consultas, explorar o esquema
e xestionar os datos. Use o método de port-forward de arriba para conectar
Workbench ao seu clúster sobre Kubernetes.

### Opcións de configuración principais

O clúster de exemplo inclúe:
- **Tamaño do clúster**: 3 nodos no datacenter `dc1`
- **Recursos**:
  - CPU: 1 núcleo (petición e límite)
  - Memoria: 1 Gi de petición, 2 Gi de límite
- **Axustes da JVM**:
  - Heap inicial: 1G
  - Heap máximo: 1G
- **Almacenamento**:
  - Clase de almacenamento: `local-path`
  - Tamaño: 2 Gi por nodo
  - Modo de acceso: ReadWriteOnce
- **Antiafinidade**: antiafinidade de pod branda activada

## Configuración

### Configuración do axente de AxonOps

O axente de AxonOps configúrase mediante variables de entorno pasadas ao contedor
de Cassandra:

| Variable | Descrición | Valor por defecto |
|----------|-------------|---------|
| `AXON_AGENT_KEY` | A súa chave de axente de AxonOps | Obrigatoria |
| `AXON_AGENT_ORG` | O identificador da súa organización de AxonOps | Obrigatorio |
| `AXON_AGENT_SERVER_HOST` | O nome de host do servidor de AxonOps | `agents.axonops.cloud` |
| `AXON_AGENT_LOG_OUTPUT` | O destino da saída de rexistro do axente | `std` |
| `AXON_AGENT_NTP_HOST` | O servidor NTP usado para as comprobacións de desviación do reloxo, `host` ou `host:porto` (o porto é `123` por defecto) | `pool.ntp.org` |

A autodetección de NTP non funciona dentro de Kubernetes, así que o contedor pon
`AXON_AGENT_NTP_HOST` por defecto ao `pool.ntp.org` público e rexistra un aviso en
cada arranque ata que o cambie. Póñao á mesma fonte NTP que usan os seus hosts de
Cassandra; se non, as lecturas de desviación do reloxo compáranse cun pool co que
os seus nodos nunca se sincronizan.
| `AXON_AGENT_ARGS` | Argumentos adicionais do axente | - |

### Variables de entorno do contedor

As variables de entorno inxéctanse na configuración do clúster de K8ssandra:

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

### Comprobación de saúde

A comprobación de saúde do contedor (`/usr/local/bin/axonops-healthcheck.sh`,
executada cada 30 s tras un período de arranque de 120 s) comproba dúas cousas:

1. **Cassandra**: o endpoint de liveness da Management API, a mesma sonda na que
   se apoia o operador K8ssandra. Nas imaxes construídas sen a Management API
   (`INCLUDE_MGMT_API=false`) é, no seu lugar, `nodetool statusbinary` máis unha
   comprobación do porto CQL.
2. **Axente de AxonOps**: o proceso `axon-agent` está en execución, así que o nodo
   está realmente monitorizado.

Por defecto, un axente caído reflíctese na saída da comprobación de saúde, pero
non volve unhealthy o contedor: Cassandra segue servindo CQL, e facer fallar a
comprobación pode levar a Kubernetes a reiniciar ou baleirar un nodo que está a
facer traballo útil. Poña `HEALTHCHECK_REQUIRE_AGENT=true` para tratar un axente
caído como un fallo.

| Variable | Valor por defecto | Descrición |
|----------|---------|-------------|
| `HEALTHCHECK_REQUIRE_AGENT` | `false` | `true` volve unhealthy o contedor cando `axon-agent` non está en execución |

```yaml
containers:
  - name: cassandra
    env:
      - name: HEALTHCHECK_REQUIRE_AGENT
        value: "true"
```

Teña en conta que o operador K8ssandra define as súas propias sondas de liveness e
readiness no pod; isto non as afecta e seguen usando os endpoints da Management
API. A comprobación de saúde de aquí é a do nivel de contedor, visible con
`docker inspect` e para calquera runtime que respecte `HEALTHCHECK`.

```bash
docker inspect --format '{{.State.Health.Status}}' <container>
kubectl exec <pod> -c cassandra -- /usr/local/bin/axonops-healthcheck.sh
```

## Referencia de scripts

### scripts/install_k8ssandra.sh

Instala o operador K8ssandra e os seus requisitos previos.

**Uso:**
```bash
./scripts/install_k8ssandra.sh
```

**Que fai:**
- Instala cert-manager con Helm
- Engade o repositorio de Helm de K8ssandra
- Instala o operador K8ssandra v1.29.0

**Non require parámetros.**

### scripts/rebuild.sh

Constrúe, sobe e desprega un clúster de Cassandra con integración de AxonOps.

> **Nota:** este script está pensado para entornos de Kubernetes con acceso
> directo ao nodo mediante `crictl`. Pode non funcionar en instalacións de
> desenvolvemento local como minikube, kind ou Docker Desktop. Para
> desenvolvemento local, véxanse os pasos manuais de build e despregamento nas
> seccións [Construír as imaxes de Docker](#construír-as-imaxes-de-docker) e
> [Despregar en Kubernetes](#despregar-en-kubernetes).

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

**Que fai:**
1. Xera un nome de imaxe único se non se proporciona (usando ttl.sh cun TTL dunha hora)
2. Elimina o despregamento de clúster existente
3. Limpa as imaxes de contedor antigas con crictl
4. Constrúe a nova imaxe de Docker
5. Sobe a imaxe ao rexistro
6. Descarga a imaxe con crictl
7. Substitúe as variables de entorno en `cluster-axonops.yaml` (copia de [examples/k8ssandra/cluster-axonops-ubi.yaml](../examples/k8ssandra/cluster-axonops-ubi.yaml))
8. Desprega a configuración de clúster actualizada

**Variables de entorno:**
- `IMAGE_NAME`: o nome da imaxe de Docker (opcional)
- `AXON_AGENT_KEY`: a chave de API de AxonOps (obrigatoria na configuración do clúster)
- `AXON_AGENT_ORG`: a organización de AxonOps (obrigatoria na configuración do clúster)
- `AXON_AGENT_SERVER_HOST`: o host de AxonOps (obrigatorio na configuración do clúster)

## Exemplos

### examples/k8ssandra/cluster-axonops-ubi.yaml

Unha definición completa de recurso K8ssandraCluster que amosa:

**Especificacións do clúster:**
- Nome: `axonops-k8ssandra-50`
- Espazo de nomes: `k8ssandra-operator`
- Versión de Cassandra: 5.0.6
- Imaxe: `ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0` (por defecto)
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

**Configuración do almacenamento:**
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

**Volume de AxonOps (obrigatorio):**

AxonOps precisa un volume persistente para gardar a súa configuración. Engada isto
á súa configuración de clúster:

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
`examples/k8ssandra/k8ssandra-config.env`. Defínao antes de renderizar o manifesto
para cambiar o tamaño. A maioría das StorageClass non poden encoller un volume
unha vez creado, así que escolla o tamaño antes do primeiro apply.

**Integración con AxonOps:**
O exemplo amosa a inxección correcta de variables de entorno para o axente de
AxonOps, co enfoque de variables a nivel de contedor que esixe K8ssandra.

### Personalizar o exemplo

**Nota:** os comandos desta sección supoñen que está no directorio `k8ssandra/`.

Para usar este exemplo:

1. Copie o ficheiro de exemplo:
   ```bash
   cp examples/k8ssandra/cluster-axonops-ubi.yaml my-cluster.yml
   ```

2. Actualice os valores de `my-cluster.yml`:
   - **Nome do clúster**: edite o campo `metadata.name` (por exemplo, cambie `axonops-k8ssandra-50` por `my-cassandra-cluster`). Nota: o nome do clúster úsase para xerar os nomes de servizos, segredos e pods.
   - **Espazo de nomes**: edite `metadata.namespace` se desprega noutro espazo de nomes
   - **Número de nodos**: axuste `size` baixo `datacenters` (por defecto son 3)
   - **Recursos**: modifique as asignacións de CPU e memoria baixo `resources`
   - **Almacenamento**: actualice o tamaño de `storage` baixo `storageConfig`

3. Despregue:
   ```bash
   export AXON_AGENT_KEY="your-key"
   export AXON_AGENT_ORG="your-org"
   export AXON_AGENT_SERVER_HOST="agents.axonops.cloud"
   # Optional: Override default image
   export IMAGE_NAME="ghcr.io/axonops/k8ssandra/cassandra:5.0.6-v0.1.110-1.0.0"

   cat my-cluster.yml | envsubst | kubectl apply -f -
   ```

**Nota:** o exemplo usa o novo formato de imaxe `5.0.6-v0.1.110-1.0.0`, que
inclúe:
- A versión de Cassandra: 5.0.6
- A versión da API de k8ssandra: v0.1.110
- A versión do contedor de AxonOps: 1.0.0

## Pipeline de CI/CD

### Builds e probas automatizados

O repositorio inclúe workflows completos de GitHub Actions para construír, probar
e publicar imaxes de Docker.

**Workflows:**
- **Build e probas:** `.github/workflows/k8ssandra-build-and-test.yml`, probas de build de Docker con validación completa
- **Probas E2E:** `.github/workflows/k8ssandra-e2e-test.yml`, probas de despregamento en Kubernetes de extremo a extremo
- **Escaneo de seguridade:** `.github/workflows/k8ssandra-nightly-security-scan.yml`, escaneo diario de CVE con avisos por correo
- **Publicación de produción (asinada):** `.github/workflows/k8ssandra-publish-signed.yml`, releases de produción manuais con sinatura Cosign
- **Publicación de desenvolvemento (asinada):** `.github/workflows/k8ssandra-development-publish-signed.yml`, builds de desenvolvemento con sinatura Cosign

**Disparadores do workflow de build e probas:**
- Push ás ramas `development` ou `main` (con cambios en `k8ssandra/**`)
- Pull requests a `development` ou `main` (con cambios en `k8ssandra/**`)

**Workflow de probas E2E:**
- Lánzase a man dende a interface de GitHub Actions ou con `gh workflow run k8ssandra-e2e-test.yml`
- Desprega os contedores nun clúster k3s sobre o runner de GitHub Actions
- Proba a Management API, o axente de AxonOps, cqlai e as operacións CQL
- Valida a conectividade con AxonOps SaaS
- Duración: uns 3 ou 4 minutos

**Workflow de escaneo de seguridade:**
- Programado: todos os días ás 2:00 UTC
- Pódese lanzar a man dende a interface de GitHub Actions
- Escanea todas as versións publicadas na busca de CVE
- Notificacións por correo cando se detectan problemas de severidade CRITICAL ou HIGH

**Workflows de publicación:**
- Lánzanse a man dende a interface de GitHub Actions ou coa CLI `gh`
- Requiren unha etiqueta de git e unha versión de contedor
- Véxase [RELEASE.md](./RELEASE.md) para as instrucións detalladas

**Batería de probas:**
O pipeline de CI inclúe probas exhaustivas:
- As probas execútanse primeiro para 5.0.6, e logo para as demais versións 5.0 en paralelo (5.0.1 a 5.0.5)
- Comprobacións de saúde da Management API (liveness, readiness)
- Operacións do axente Java da Management API (crear keyspace e táboa, flush, compact)
- Operacións CQL con cqlai (CREATE, INSERT, SELECT, DROP)
- Verificación do proceso do axente de AxonOps
- Verificación de jemalloc (sen avisos, carga correcta)
- Verificación da versión de Java (JDK17 para 5.0)
- Escaneo de seguridade do contedor con Trivy
  - Os CVE upstream coñecidos documéntanse en `.trivyignore`
  - Véxase [.trivyignore](./.trivyignore) para a lista de vulnerabilidades suprimidas

**Proceso de publicación:**
1. O desenvolvedor crea unha etiqueta de git (por exemplo, `git tag 1.0.0 && git push origin 1.0.0`)
2. O desenvolvedor lanza o workflow de publicación dende a interface de GitHub ou con `gh workflow run`
3. O workflow valida que a versión non existe xa en GHCR
4. A batería de probas completa execútase primeiro sobre 5.0.6, para validar
5. Constrúense imaxes multiarquitectura (amd64, arm64) para as 6 versións (máximo 3 en paralelo)
6. As imaxes sóbense a GHCR con etiquetas específicas de versión e as etiquetas latest
7. Créase automaticamente unha GitHub Release

Para as instrucións completas de release, véxase [RELEASE.md](./RELEASE.md).

**Etiquetas de imaxe:**
Cada release usa etiquetado tridimensional con seguimento da versión da API de
k8ssandra:

```
ghcr.io/axonops/k8ssandra/cassandra:{CASS}-v{K8S_API}-{AXON}  # Fully immutable (all 3 versions)
ghcr.io/axonops/k8ssandra/cassandra:{CASS}-v{K8S_API}         # Latest AxonOps for this Cassandra + k8ssandra combo
ghcr.io/axonops/k8ssandra/cassandra:{CASS}                    # Latest k8ssandra API + AxonOps for this Cassandra minor
ghcr.io/axonops/k8ssandra/cassandra:{MAJOR}-latest            # Latest minor in Cassandra major
ghcr.io/axonops/k8ssandra/cassandra:latest                    # Latest across all Cassandra majors
```

**Exemplo:** para unha release de Cassandra `5.0.6`, API de k8ssandra `v0.1.110` e
AxonOps `1.0.0`:

**Etiquetas totalmente inmutables** (1 por versión de Cassandra, 6 en total):
- `5.0.1-v0.1.110-1.0.0`, `5.0.2-v0.1.110-1.0.0`, `5.0.3-v0.1.110-1.0.0`, `5.0.4-v0.1.110-1.0.0`, `5.0.5-v0.1.110-1.0.0`, `5.0.6-v0.1.110-1.0.0`

**Etiquetas flotantes** (seguen o último AxonOps de cada combinación Cassandra + k8ssandra, 6 en total):
- `5.0.1-v0.1.110` → `5.0.1-v0.1.110-1.0.0`
- `5.0.2-v0.1.110` → `5.0.2-v0.1.110-1.0.0`
- `5.0.3-v0.1.110` → `5.0.3-v0.1.110-1.0.0`
- `5.0.4-v0.1.110` → `5.0.4-v0.1.110-1.0.0`
- `5.0.5-v0.1.110` → `5.0.5-v0.1.110-1.0.0`
- `5.0.6-v0.1.110` → `5.0.6-v0.1.110-1.0.0`

**Etiquetas flotantes** (seguen o último k8ssandra + AxonOps de cada menor de Cassandra, 6 en total):
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

## Prestacións do contedor

### Banner de versión ao arrancar

Todos os contedores amosan ao arrancar un banner de versión completo que indica:
- A versión de build do contedor e a revisión de git
- A versión de Cassandra
- A versión de Java
- As versións do axente de AxonOps (o independente e o axente Java)
- A versión de cqlai
- A versión de jemalloc
- O sistema operativo e a plataforma
- O entorno de execución (detección de Kubernetes, nome de host)
- O estado da configuración de AxonOps

**Ver o banner:**
```bash
# Docker/Podman
docker logs <container-name> | head -30

# Kubernetes
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | head -30
```

**Exemplo de saída (release de produción):**
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

Os **builds de produción** inclúen metadatos adicionais: os campos `Image`, a
ligazón `Release` e `Built by`. Os **builds de desenvolvemento** amosan só os
campos esenciais (a marca de tempo `Built`).

Este banner facilita moito a depuración de entornos de cliente, porque amosa toda
a información de versión relevante nun mesmo sitio.

## Monitorización con AxonOps

Unha vez despregado, o seu clúster de Cassandra fará automaticamente o seguinte:
- Rexistrarse en AxonOps coa chave de API e a organización proporcionadas
- Enviar métricas e rexistros á plataforma AxonOps
- Habilitar as prestacións de monitorización, alertado e xestión do clúster

Acceda á monitorización do seu clúster en:
- AxonOps Cloud: https://axonops.cloud
- Instalación propia: a URL de AxonOps que configurase

## Resolución de problemas

### Comprobar a versión do contedor

Consulte o banner de arranque para ver todas as versións dos compoñentes:
```bash
# Kubernetes
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | head -30

# Docker/Podman
docker logs <container-name> | head -30
```

O banner amosa a versión do contedor, a revisión de git e todas as versións dos
compoñentes, o que axuda a identificar exactamente que se está a executar.

### Problemas de conexión do axente

Revise os rexistros do axente:
```bash
kubectl logs <pod-name> -n k8ssandra-operator -c cassandra | grep axon
```

Verifique as variables de entorno:
```bash
kubectl describe pod <pod-name> -n k8ssandra-operator
```

Comprobe que o banner de arranque amosa a configuración de AxonOps correcta.

### Erros ao descargar a imaxe

Asegúrese de que a súa imaxe é accesible:
```bash
docker pull $IMAGE_NAME
```

Para as imaxes de ttl.sh, teña en conta que expiran ao cabo dunha hora. Use un
rexistro persistente en produción.

### O clúster non arranca

Revise os rexistros do operador K8ssandra:
```bash
kubectl logs -n k8ssandra-operator deployment/k8ssandra-operator
```

Verifique o estado do clúster:
```bash
kubectl get k8ssandraclusters -n k8ssandra-operator
kubectl describe k8ssandracluster <cluster-name> -n k8ssandra-operator
```

## Consideracións para produción

1. **Rexistro de imaxes**: use un rexistro de contedores persistente no canto de ttl.sh
2. **Dimensionamento de recursos**: axuste CPU, memoria e almacenamento segundo a carga
3. **Alta dispoñibilidade**: despregue en varias zonas de dispoñibilidade
4. **Estratexia de copia de seguranza**: configure Medusa de K8ssandra para as copias
5. **Seguridade**:
   - Use segredos para as credenciais de AxonOps, no canto de variables de entorno
   - Active o cifrado en repouso e en tránsito
   - Configure RBAC e network policies
6. **Monitorización**: configure alertas en AxonOps para as métricas críticas
