# AxonOps Schema Registry

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

[![Paquete GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axonops-schema-registry)

Schema Registry de Kafka compatible con Confluent e listo para produción, con
soporte de varios backends de almacenamento, construído sobre Red Hat UBI 9.

## Índice

- [Visión xeral](#visión-xeral)
- [Imaxes de Docker precompiladas](#imaxes-de-docker-precompiladas)
  - [Imaxes dispoñibles](#imaxes-dispoñibles)
  - [Estratexia de etiquetado](#estratexia-de-etiquetado)
- [Boa práctica en produción](#boa-práctica-en-produción)
- [Construír as imaxes de Docker](#construír-as-imaxes-de-docker)
- [Variables de entorno](#variables-de-entorno)
- [Prestacións do contedor](#prestacións-do-contedor)
  - [Script de entrypoint](#script-de-entrypoint)
  - [Banner de versión ao arrancar](#banner-de-versión-ao-arrancar)
  - [Sondas de saúde](#sondas-de-saúde)
- [Pipeline de CI/CD](#pipeline-de-cicd)
  - [Workflows](#workflows)
  - [Probas automatizadas](#probas-automatizadas)
  - [Proceso de publicación](#proceso-de-publicación)
- [Resolución de problemas](#resolución-de-problemas)
  - [Comprobar a versión do contedor](#comprobar-a-versión-do-contedor)
  - [Depurar a comprobación de saúde](#depurar-a-comprobación-de-saúde)
  - [O contedor non arranca](#o-contedor-non-arranca)
- [Consideracións para produción](#consideracións-para-produción)

## Visión xeral

AxonOps Schema Registry é un Schema Registry de Kafka compatible con Confluent
que ofrece xestión de esquemas con soporte de varios backends de almacenamento. É
un único binario de Go sen estado que expón unha API REST no porto 8081.

**Prestacións do contedor:**
- **Almacenamento multibackend**: PostgreSQL, MySQL, Cassandra 5+ e almacenamento en memoria
- **Compatible coa API de Confluent**: substituto directo do Schema Registry de Confluent
- **Base empresarial**: construído sobre Red Hat UBI 9 minimal, para estabilidade en produción
- **Seguridade da cadea de subministración**: imaxes base fixadas por digest, para builds inmutables
- **Monitorización de produción**: sondas de saúde integradas (startup, liveness, readiness)
- **Lixeiro**: un único binario de Go, cunha pegada de memoria duns 50 MB

**Endpoints da API:**
- Comprobación de saúde: `GET /`
- Documentación Swagger: `GET /docs`
- API do Schema Registry: porto 8081

## Imaxes de Docker precompiladas

Hai imaxes precompiladas dispoñibles en GitHub Container Registry (GHCR). É a
forma máis sinxela de comezar.

### Imaxes dispoñibles

Todas as imaxes están en: `ghcr.io/axonops/axonops-schema-registry`

Consulte todas as etiquetas dispoñibles:
[GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axonops-schema-registry)

### Estratexia de etiquetado

As imaxes usan unha estratexia de etiquetado multidimensional con dous eixos
independentes:

- **SR_VERSION**: a versión da aplicación Schema Registry (por exemplo, `0.2.0`)
- **CONTAINER_VERSION**: a versión do contedor (semver, por exemplo, `0.0.1`, `0.0.2`, `0.1.0`)

| Patrón de etiqueta | Exemplo | Descrición | Caso de uso |
|-------------|---------|-------------|----------|
| `{SR_VERSION}-{CONTAINER_VERSION}` | `0.2.0-0.0.1` | Totalmente inmutable (versión de SR + versión de contedor) | **Produción**: fixe versións exactas para unha auditabilidade completa |
| `@sha256:<digest>` | `@sha256:abc123...` | Baseada en digest (criptograficamente inmutable) | **Máxima seguridade**: integridade da imaxe garantida |
| `{SR_VERSION}` | `0.2.0` | A última versión de contedor desa versión de SR | Seguir as actualizacións de contedor dunha versión de SR concreta |
| `latest` | `latest` | A última de todas as versións | Só para probas rápidas (NON para produción) |

**Exemplos de etiquetado:**

Cando se constrúe `0.2.0-0.0.1` (e é a máis recente):
- `0.2.0-0.0.1` (inmutable: non cambia nunca)
- `0.2.0` (flotante: reetiquétase a versións de contedor máis novas da mesma versión de SR)
- `latest` (flotante: móvese a versións de SR máis novas)

Cando se constrúe `0.2.0-0.0.2` (só sobe o contedor, mesma versión de SR):
- `0.2.0-0.0.2` (inmutable: non cambia nunca)
- `0.2.0` (flotante: agora apunta á versión de contedor 0.0.2)
- `latest` (flotante: agora apunta á versión de contedor 0.0.2)

Cando se constrúe `0.3.0-0.0.1` (nova versión de SR, a de contedor volve a 0.0.1):
- `0.3.0-0.0.1` (inmutable: non cambia nunca)
- `0.3.0` (flotante: a última versión de contedor de 0.3.0)
- `latest` (flotante: agora apunta a 0.3.0-0.0.1)

## Boa práctica en produción

**Usar `latest` ou etiquetas flotantes en produción é un antipatrón.** Isto inclúe
`latest` e `0.2.0`, porque:
- **Non hai rastro de auditoría**: non se pode determinar que versión exacta estaba despregada nun momento dado
- **Actualizacións inesperadas**: os orquestradores de contedores poden descargar imaxes novas ao reiniciar
- **Dificultades para volver atrás**: non se pode retroceder de forma fiable a versións anteriores
- **Problemas de cumprimento**: moitos marcos normativos esixen un seguimento de versións inmutable

**Estratexias de despregamento recomendadas (de maior a menor seguridade):**

1. **Referencia de ouro: baseada en digest** (máxima seguridade)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry@sha256:abc123...
   ```
   - 100 % inmutable, garantido criptograficamente
   - Obrigatoria en entornos regulados
   - Verifique a sinatura con Cosign (véxase máis abaixo)

2. **Etiqueta inmutable** (o estándar de produción)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
   ```
   - Fixada a unha versión concreta (SR 0.2.0, contedor 0.0.1)
   - Doada de ler e de xestionar
   - Mantén un rastro de auditoría completo

3. **Etiquetas flotantes** (só desenvolvemento e probas)
   ```bash
   docker pull ghcr.io/axonops/axonops-schema-registry:latest
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
  ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1

# Check signature exists
cosign tree ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
```

## Construír as imaxes de Docker

Se prefire construír as imaxes vostede mesmo no canto de usar as precompiladas:

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

**Argumentos de build opcionais (melloran os metadatos, pero non son
obrigatorios):**
- `SR_VERSION`: a versión do Schema Registry (por defecto: `0.2.0`)
- `BUILD_DATE`: a marca de tempo do build (formato ISO 8601, por exemplo, `$(date -u +"%Y-%m-%dT%H:%M:%SZ")`)
- `VCS_REF`: o SHA do commit de git (por exemplo, `$(git rev-parse HEAD)`)
- `VERSION`: a cadea de versión completa (por exemplo, `0.2.0-0.0.1`)
- `CONTAINER_VERSION`: a versión do contedor (por exemplo, `0.0.1`)
- `GIT_TAG`: o nome da etiqueta de git (para as ligazóns de release/tag do banner)
- `GITHUB_ACTOR`: o usuario que lanzou o build (para o rastro de auditoría)
- `IS_PRODUCTION_RELEASE`: póñao a `true` para produción (por defecto: `false`)
- `IMAGE_FULL_NAME`: o nome completo da imaxe coa etiqueta (amósase no banner de arranque)

**Seguridade da cadea de subministración:**

O noso Dockerfile usa imaxes base fixadas por digest, por seguridade da cadea de
subministración:

```dockerfile
# CORRECT - Digest-pinned (immutable, secure)
ARG UBI9_MINIMAL_DIGEST=sha256:1bc3c5c15720506a0cf48adfdf8b623dfe704377e007d7bbae8d14876392ca6a
FROM registry.access.redhat.com/ubi9/ubi-minimal@${UBI9_MINIMAL_DIGEST}

# WRONG - Tag-based (mutable, vulnerable to supply chain attacks!)
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest
```

## Variables de entorno

O Schema Registry configúrase principalmente mediante o seu ficheiro de
configuración YAML (`/etc/axonops-schema-registry/config.yaml`). Pode
sobrescribilo montando un ficheiro de configuración propio.

| Variable | Descrición | Valor por defecto |
|----------|-------------|---------|
| `SR_PORT` | O porto da API para o script de comprobación de saúde | `8081` |
| `HEALTH_CHECK_TIMEOUT` | O timeout da comprobación de saúde, en segundos | `10` |

**Configuración propia:**

Monte un ficheiro de configuración propio para substituír o de por defecto:

```bash
docker run -d --name schema-registry \
  -v /path/to/config.yaml:/etc/axonops-schema-registry/config.yaml:ro \
  -p 8081:8081 \
  ghcr.io/axonops/axonops-schema-registry:0.2.0-0.0.1
```

## Prestacións do contedor

### Script de entrypoint

O script de entrypoint (`/usr/local/bin/docker-entrypoint.sh`) amosa o banner de
arranque e logo executa o proceso principal. Execútase a través de
[tini](https://github.com/krallin/tini), para un manexo correcto dos sinais e a
recollida de procesos zombis.

```dockerfile
ENTRYPOINT ["/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["axonops-schema-registry", "--config", "/etc/axonops-schema-registry/config.yaml"]
```

Árbore de procesos:
```
tini (PID 1)
  └── docker-entrypoint.sh
       └── axonops-schema-registry (after exec)
```

### Banner de versión ao arrancar

Todos os contedores amosan ao arrancar información de versión completa:

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

**Ver o banner:**
```bash
docker logs schema-registry | head -25
```

### Sondas de saúde

O contedor inclúe un script de comprobación de saúde que admite tres tipos de
sonda:

**1. Sonda de arranque** (`healthcheck.sh startup`)
- Comproba que o proceso do Schema Registry está en execución (`pgrep`)
- Comproba que o porto da API responde a peticións HTTP
- Úsea para: o `startupProbe` de Kubernetes

**2. Sonda de vida** (`healthcheck.sh liveness`)
- Comproba que o proceso do Schema Registry está en execución (`pgrep`)
- Ultralixeira, execútase a miúdo
- Úsea para: o `livenessProbe` de Kubernetes

**3. Sonda de dispoñibilidade** (`healthcheck.sh readiness`)
- Comprobación HTTP completa contra o endpoint `GET /`
- Verifica unha resposta HTTP 200
- Úsea para: o `readinessProbe` de Kubernetes e o HEALTHCHECK de Docker

**Comprobación de saúde de Docker:**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect schema-registry --format='{{json .State.Health}}' | jq
```

**Probar a comprobación de saúde a man:**
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

**Build e probas** (`.github/workflows/axonops-schema-registry-build-and-test.yml`)
- **Disparadores:** push ou PR ás ramas main, development, feature/* e fix/*
  - Cando cambia `axonops-schema-registry/**` (excluíndo os ficheiros `*.md`)
  - Cando cambian os workflows (`.github/workflows/axonops-schema-registry-*.yml`)
  - Cando cambian as actions (`.github/actions/axonops-schema-registry-*/**`)
- **Probas:** build de Docker, verificación de versión, comprobación de saúde, probas da API e escaneo de seguridade
- **Duración:** uns 5 minutos

**Publicación de produción** (`.github/workflows/axonops-schema-registry-publish-signed.yml`)
- **Disparador:** execución manual do workflow cunha etiqueta de git
- **Proceso:** validar -> probar -> crear a release -> construír -> asinar -> publicar -> verificar
- **Rexistro:** `ghcr.io/axonops/axonops-schema-registry`
- **Plataformas:** linux/amd64, linux/arm64
- **Sinatura:** sinatura sen chaves con Cosign (OIDC)

**Publicación de desenvolvemento** (`.github/workflows/axonops-schema-registry-development-publish-signed.yml`)
- **Disparador:** execución manual do workflow dende a rama development
- **Rexistro:** `ghcr.io/axonops/development/axonops-schema-registry`
- **Uso:** probar imaxes antes dunha release de produción

### Probas automatizadas

O pipeline de CI inclúe:

**Probas funcionais:**
- Verificación do build do contedor (multiarquitectura)
- Verificación do banner de arranque (produción fronte a desenvolvemento)
- Verificación de versións (versión de SR, versión de contedor)
- Probas do script de comprobación de saúde (startup, liveness, readiness)
- Probas da API do Schema Registry (`GET /`)

**Probas de seguridade:**
- Escaneo de vulnerabilidades do contedor con Trivy (severidade CRITICAL e HIGH)
- Os resultados sóbense á lapela Security de GitHub
- Os CVE upstream coñecidos documéntanse en `.trivyignore`

### Proceso de publicación

**Release de desenvolvemento:**
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

**Release de produción:**
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

Véxase [RELEASE.md](./RELEASE.md) para a documentación completa do proceso de
release.

## Resolución de problemas

### Comprobar a versión do contedor

Consulte o banner de arranque para ver todas as versións dos compoñentes:

```bash
docker logs schema-registry | head -25
```

### Depurar a comprobación de saúde

Probe as sondas de saúde a man:

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

### O contedor non arranca

**Revise os rexistros:**
```bash
docker logs schema-registry
```

**Problemas habituais:**

1. **Conflitos de portos:**
   - API do Schema Registry: 8081
   - Compróbeo con: `netstat -tuln | grep 8081`

2. **Problemas de permisos:**
   - O contedor execútase como o usuario `schemaregistry` (UID 999)
   - Asegure os permisos do volume: `chown -R 999:999 /data/schema-registry`

3. **Problemas de configuración:**
   - Verifique o ficheiro de configuración: `docker exec schema-registry cat /etc/axonops-schema-registry/config.yaml`

## Consideracións para produción

1. **Almacenamento persistente**
   - Use volumes para `/var/lib/axonops-schema-registry` (datos)
   - Use volumes para `/var/log/axonops-schema-registry` (rexistros)

2. **Asignación de recursos**
   - Memoria: uns 50 MB de forma habitual, asigne 256 MB como mínimo
   - CPU: 1 núcleo abonda para a maioría das cargas

3. **Rede**
   - Expoña o porto 8081 para a API do Schema Registry
   - Use regras de cortalumes axeitadas

4. **Seguridade**
   - Verifique as sinaturas dos contedores con Cosign
   - Use referencias de imaxe baseadas en digest, por inmutabilidade
   - Manteña as imaxes base actualizadas

5. **Monitorización**
   - Use as sondas de saúde para monitorizar a dispoñibilidade
   - Vixíe os tempos de resposta da API con `GET /`
   - Configure a agregación de rexistros de `/var/log/axonops-schema-registry/`

6. **Alta dispoñibilidade**
   - O Schema Registry é sen estado cando se usan backends de almacenamento externos
   - Execute varias instancias tras un balanceador de carga para alta dispoñibilidade

Para o fluxo de traballo de desenvolvemento e as probas, véxase
[DEVELOPMENT.md](./DEVELOPMENT.md).

Para o proceso de release, véxase [RELEASE.md](./RELEASE.md).
