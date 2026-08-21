# Base de datos de series temporais AxonDB

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

[![Paquete GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/axondb-timeseries)

Contedor de Apache Cassandra 5.0.6 listo para produción, optimizado para cargas
de series temporais en despregamentos autoaloxados de AxonOps.

## Índice

- [Visión xeral](#visión-xeral)
- [Imaxes de Docker precompiladas](#imaxes-de-docker-precompiladas)
  - [Imaxes dispoñibles](#imaxes-dispoñibles)
  - [Estratexia de etiquetado](#estratexia-de-etiquetado)
- [Boa práctica en produción](#boa-práctica-en-produción)
- [Despregamento](#despregamento)
- [Construír as imaxes de Docker](#construír-as-imaxes-de-docker)
- [Variables de entorno](#variables-de-entorno)
  - [Configuración de Cassandra](#configuración-de-cassandra)
  - [Control da inicialización](#control-da-inicialización)
- [Prestacións do contedor](#prestacións-do-contedor)
  - [Script de entrypoint](#script-de-entrypoint)
  - [Banner de versión ao arrancar](#banner-de-versión-ao-arrancar)
  - [Sondas de saúde](#sondas-de-saúde)
  - [Inicialización automatizada (keyspaces de sistema e usuario de base de datos)](#inicialización-automatizada-keyspaces-de-sistema-e-usuario-de-base-de-datos)
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

AxonDB Time-Series é un contedor de Apache Cassandra listo para produción,
deseñado expresamente para os despregamentos autoaloxados de AxonOps. Está
optimizado para cargas de base de datos de series temporais e desprégase como
parte da pila completa de AxonOps cos charts de Helm de AxonOps.

**Prestacións do contedor:**
- **Shell de CQL moderna**: [cqlai](https://github.com/axonops/cqlai) v0.1.2, para unha interacción mellorada coa base de datos
- **Optimización de memoria**: jemalloc, para unha mellor xestión da memoria
- **Configuración automatizada**: inicialización dos keyspaces de sistema e creación dun usuario propio
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

Todas as imaxes están en: `ghcr.io/axonops/axondb-timeseries`

Consulte todas as etiquetas dispoñibles:
[GitHub Container Registry](https://github.com/axonops/axonops-containers/pkgs/container/axondb-timeseries)

### Estratexia de etiquetado

As imaxes usan unha estratexia de etiquetado bidimensional:

| Patrón de etiqueta | Exemplo | Descrición | Caso de uso |
|-------------|---------|-------------|----------|
| `{CASS}-{AXON}` | `5.0.6-1.0.0` | Totalmente inmutable (versión de Cassandra + de AxonOps) | **Produción**: fixe versións exactas para unha auditabilidade completa |
| `@sha256:<digest>` | `@sha256:abc123...` | Baseada en digest (criptograficamente inmutable) | **Máxima seguridade**: integridade da imaxe garantida |
| `{CASS}` | `5.0.6` | O último AxonOps para esa versión de Cassandra | Seguir as actualizacións de AxonOps dunha versión concreta de Cassandra |
| `latest` | `latest` | A última de todas as versións | Só para probas rápidas (NON para produción) |

**Dimensións do versionado:**
- **CASS**: a versión de Cassandra (por exemplo, 5.0.6)
- **AXON**: a versión do contedor de AxonOps (por exemplo, 1.0.0, en SemVer)

**Exemplos de etiquetado:**

Cando se constrúe `5.0.6-1.0.0` (e é a máis recente):
- `5.0.6-1.0.0` (inmutable: non cambia nunca)
- `5.0.6` (flotante: reetiquétase a builds de AxonOps máis novos)
- `latest` (flotante: móvese a versións de Cassandra máis novas)

## 💡 Boa práctica en produción

⚠️ **Usar `latest` ou etiquetas flotantes en produción é un antipatrón.** Isto
inclúe `latest` e `5.0.6`, porque:
- **Non hai rastro de auditoría**: non se pode determinar que versión exacta estaba despregada nun momento dado
- **Actualizacións inesperadas**: os orquestradores de contedores poden descargar imaxes novas ao reiniciar
- **Dificultades para volver atrás**: non se pode retroceder de forma fiable a versións anteriores
- **Problemas de cumprimento**: moitos marcos normativos esixen un seguimento de versións inmutable

👍 **Estratexias de despregamento recomendadas (de maior a menor seguridade):**

1. **🥇 Referencia de ouro: baseada en digest** (máxima seguridade)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries@sha256:abc123...
   ```
   - 100 % inmutable, garantido criptograficamente
   - Obrigatoria en entornos regulados
   - Verifique a sinatura con Cosign (véxase [Seguridade](#seguridade))

2. **🥈 Etiqueta inmutable** (o estándar de produción)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
   ```
   - Fixada a unha versión concreta (Cassandra 5.0.6 + AxonOps 1.0.0)
   - Doada de ler e de xestionar
   - Mantén un rastro de auditoría completo

3. **🥉 Etiquetas flotantes** (só desenvolvemento e probas)
   ```bash
   docker pull ghcr.io/axonops/axondb-timeseries:latest
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
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0

# Check signature exists
cosign tree ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

## Despregamento

Este contedor desprégase exclusivamente mediante os **charts de Helm de AxonOps**,
como parte da pila autoaloxada de AxonOps. Os charts de Helm ocúpanse de toda a
configuración, a orquestración e a integración cos compoñentes de monitorización
e xestión de AxonOps.

Para as instrucións de despregamento, consulte a documentación de despregamento
autoaloxado de AxonOps (dispoñible cando se publiquen os charts de Helm).

## Construír as imaxes de Docker

Se prefire construír as imaxes vostede mesmo no canto de usar as precompiladas:

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

**Argumentos de build obrigatorios:**
- `CASSANDRA_VERSION`: a versión de Cassandra (por exemplo, 5.0.6)
- `CQLAI_VERSION`: a versión de cqlai que instalar (véxase a [última release](https://github.com/axonops/cqlai/releases))

**Ficheiros de configuración propios:**

O contedor inclúe ficheiros de configuración de Cassandra personalizados e
optimizados para despregamentos en contedores:

| Ficheiro | Propósito | Personalizacións clave |
|------|---------|-------------------|
| `cassandra.yaml` | Axustes centrais de Cassandra | Valores por defecto listos para produción, para cargas de series temporais |
| `jvm-server.options` | Opcións da JVM | Axustes de memoria e configuración do GC |
| `jvm17-server.options` | Opcións específicas de JDK 17 | GC Shenandoah, axustes de heap (8G por defecto) |
| `cassandra-env.sh` | Entorno de Cassandra | Parámetros da JVM, optimización de memoria |
| `logback.xml` | Configuración de rexistro | Retención reducida (1 GB en total, 7 días), rexistro de depuración desactivado en produción |

**Puntos destacados de logback.xml:**
- **SYSTEMLOG** (system.log): nivel INFO, ficheiros de 50 MB, retención de 7 días, **tope total de 1 GB** (reducido dende os 5 GB por defecto)
- **DEBUGLOG** (debug.log): desactivado por defecto (pódese activar descomentando o appender-ref)
- **Rexistro de auditoría**: a infraestrutura está presente pero desactivada (pódese activar en cassandra.yaml se fai falta)
- Optimizado para entornos de contedores, cun crecemento dos rexistros controlado

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

O contedor admite 14 variables de entorno de configuración:

| Variable | Descrición | Valor por defecto | Categoría |
|----------|-------------|---------|----------|
| `CASSANDRA_CLUSTER_NAME` | O nome do clúster | `axonopsdb-timeseries` | Cassandra |
| `CASSANDRA_NUM_TOKENS` | Número de tokens por nodo (vnodes) | `8` | Cassandra |
| `CASSANDRA_DC` | O nome do datacenter | `axonopsdb_dc1` | Cassandra |
| `CASSANDRA_RACK` | O nome do rack | `rack1` | Cassandra |
| `CASSANDRA_LISTEN_ADDRESS` | O enderezo IP de escoita (`auto` = autodetectar) | `auto` | Cassandra |
| `CASSANDRA_BROADCAST_ADDRESS` | O enderezo IP que se difunde aos demais nodos | O mesmo ca `CASSANDRA_LISTEN_ADDRESS` | Cassandra |
| `CASSANDRA_RPC_ADDRESS` | O enderezo do transporte nativo de CQL | `0.0.0.0` (todas as interfaces) | Cassandra |
| `CASSANDRA_BROADCAST_RPC_ADDRESS` | O enderezo RPC difundido aos clientes | O mesmo ca `CASSANDRA_LISTEN_ADDRESS` | Cassandra |
| `CASSANDRA_SEEDS` | Os enderezos dos nodos seed (separados por comas) | O IP propio (para un só nodo) | Cassandra |
| `CASSANDRA_HEAP_SIZE` | O tamaño do heap da JVM (tanto -Xms como -Xmx) | `8G` | Cassandra |
| `INIT_SYSTEM_KEYSPACES_AND_ROLES` | Converte automaticamente os keyspaces de sistema e crea os roles propios | `true` | Inicialización |
| `INIT_TIMEOUT` | Segundos que o script de inicialización agarda por Cassandra | `600` (10 min) | Inicialización |
| `AXONOPS_DB_USER` | Crea un superusuario propio con este nome (opcional) | - | Inicialización |
| `AXONOPS_DB_PASSWORD` | O contrasinal do superusuario propio (obrigatorio se se define `AXONOPS_DB_USER`) | - | Inicialización |

### Configuración de Cassandra

As 10 primeiras variables configuran o comportamento central de Cassandra. O
script de entrypoint procésaas e aplícaas aos ficheiros de configuración de
Cassandra antes de que Cassandra arranque.

**Configuración de rede:**
- `CASSANDRA_LISTEN_ADDRESS`: póñaa a `auto` para detectar o IP automaticamente, ou indique un enderezo IP
- `CASSANDRA_BROADCAST_ADDRESS`: por defecto, o enderezo de escoita; cámbiea en escenarios con NAT ou cortalumes
- `CASSANDRA_RPC_ADDRESS`: póñaa a `0.0.0.0` para escoitar en todas as interfaces
- `CASSANDRA_SEEDS`: lista separada por comas, para clústeres de varios nodos

**Configuración da topoloxía:**
- `CASSANDRA_DC` e `CASSANDRA_RACK`: definen o datacenter e o rack, para unha replicación correcta
- Escríbense en `cassandra-rackdc.properties` e leas `GossipingPropertyFileSnitch`
- Valores por defecto: `axonopsdb_dc1` / `rack1` (cámbieos en despregamentos de produción)

**Configuración de recursos:**
- `CASSANDRA_HEAP_SIZE`: controla o heap da JVM (tanto -Xms como -Xmx toman o mesmo valor)

**Exemplo:**
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

### Control da inicialización

As 4 últimas variables (`INIT_SYSTEM_KEYSPACES_AND_ROLES`, `INIT_TIMEOUT`,
`AXONOPS_DB_USER`, `AXONOPS_DB_PASSWORD`) controlan o comportamento da
inicialización automática que ocorre despois de que Cassandra arranque.

**Inicialización dos keyspaces de sistema:**

No primeiro arranque dun clúster dun só nodo recén creado, o contedor converte
automaticamente os keyspaces de sistema de `SimpleStrategy` a
`NetworkTopologyStrategy`, para que estean listos para produción.

**Configuración do timeout:**
O script de inicialización agarda ata `INIT_TIMEOUT` segundos (por defecto: 600,
é dicir, 10 minutos) a que Cassandra estea lista. Se o seu entorno arranca lento
(heap grande, discos lentos), suba ese valor:

```bash
docker run -d --name axondb \
  -e INIT_TIMEOUT=1200 \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

**O proceso de inicialización:**

- Só se executa en clústeres dun só nodo coas credenciais por defecto `cassandra/cassandra`
- Detecta o nome do datacenter da instancia de Cassandra en marcha
- Converte: `system_auth`, `system_distributed`, `system_traces`
- Escribe ficheiros semáforo para coordinarse coa comprobación de saúde
- Sáltase se xa se converteu ou se detecta un clúster de varios nodos

Para desactivalo: `INIT_SYSTEM_KEYSPACES_AND_ROLES=false`

**Usuario de base de datos propio:**

Cree automaticamente un superusuario propio e desactive o usuario `cassandra` por
defecto:

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
- A creación do usuario propio só funciona en clústeres recén creados coas credenciais por defecto
- O usuario `cassandra` por defecto desactívase tras crear o usuario propio (póñenselle `can_login=false`)
- A creación do usuario execútase despois de que remate a inicialización dos keyspaces de sistema
- Ambas as operacións faias o mesmo script: `init-system-keyspaces.sh`
- Rexistros de progreso: `/var/log/cassandra/init-system-keyspaces.log`
- Marcadores de finalización (no volume persistente):
  - `/var/lib/cassandra/.axonops/init-system-keyspaces.done`
  - `/var/lib/cassandra/.axonops/init-db-user.done`

## Prestacións do contedor

### Script de entrypoint

O script de entrypoint (`/usr/local/bin/docker-entrypoint.sh`) é o orquestrador
principal que configura Cassandra e xestiona o arranque do contedor. Execútase
como PID 1 a través de [tini](https://github.com/krallin/tini) e fai a
inicialización crítica antes de arrancar Cassandra.

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
CMD ["cassandra", "-f"]
```

Iso significa que a árbore de procesos real é:
```
tini (PID 1)
  └─► docker-entrypoint.sh
       └─► cassandra -f (after exec)
```

Tras `exec cassandra -f`, Cassandra substitúe o script de shell, pero tini segue
sendo o PID 1, o que garante un manexo correcto dos sinais en todo o contedor.

**Máis información:** [github.com/krallin/tini](https://github.com/krallin/tini)

#### Que fai

**1. Amosa o banner de arranque**
- Toma os metadatos do build de `/etc/axonops/build-info.txt`
- Imprime información de versión completa (Cassandra, Java, cqlai, jemalloc, sistema operativo)
- Amosa o entorno de execución (detección de Kubernetes, nome de host)
- Amosa a información de seguridade da cadea de subministración (o digest da imaxe base)

**2. Configura a rede e os enderezos IP**
- Autodetecta o IP do contedor se `CASSANDRA_LISTEN_ADDRESS=auto`
- Fixa os enderezos de difusión a partir do enderezo de escoita
- Configura os enderezos RPC (CQL) para as conexións dos clientes
- Garante unha configuración correcta dos nodos seed

**3. Aplica as variables de entorno á configuración de Cassandra**
- Procesa todas as variables de entorno `CASSANDRA_*`
- Actualiza `cassandra.yaml` cos axustes indicados polo usuario
- Modifica `cassandra-rackdc.properties` para a configuración de DC e rack
- Axusta o tamaño do heap da JVM en `jvm17-server.options`
- Usa `GossipingPropertyFileSnitch` (preconfigurado en cassandra.yaml), que le o DC e o rack de cassandra-rackdc.properties

**4. Activa a optimización de memoria con jemalloc**
- Define `LD_PRELOAD=/usr/lib64/libjemalloc.so.2`
- Mellora o rendemento da asignación de memoria
- Repregue seguro se non atopa jemalloc

**5. Lanza a inicialización en segundo plano**
- Arranca `init-system-keyspaces.sh` en segundo plano (sen bloquear)
- Ou escribe os semáforos de omisión se `INIT_SYSTEM_KEYSPACES_AND_ROLES=false`
- Permite que Cassandra arranque de inmediato mentres a inicialización agarda a que estea lista

**6. Arranca Cassandra**
- Executa `cassandra -f` (en primeiro plano)
- Substitúe o proceso do entrypoint (pasa a ser o PID 1)
- Cassandra queda como proceso principal do contedor

#### Orde de execución

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

#### Ficheiros de configuración modificados

O entrypoint modifica estes ficheiros de configuración de Cassandra a partir das
variables de entorno:

| Ficheiro | Que modifica | Variables de entorno |
|------|----------------|----------------------|
| `/etc/cassandra/cassandra.yaml` | Axustes centrais de Cassandra | `CASSANDRA_CLUSTER_NAME`, `CASSANDRA_NUM_TOKENS`, `CASSANDRA_LISTEN_ADDRESS`, `CASSANDRA_RPC_ADDRESS`, `CASSANDRA_BROADCAST_ADDRESS`, `CASSANDRA_BROADCAST_RPC_ADDRESS`, `CASSANDRA_SEEDS` |
| `/etc/cassandra/cassandra-rackdc.properties` | A topoloxía de datacenter e rack | `CASSANDRA_DC` (por defecto: `axonopsdb_dc1`), `CASSANDRA_RACK` (por defecto: `rack1`) |
| `/etc/cassandra/jvm17-server.options` | Os axustes de memoria do heap da JVM | `CASSANDRA_HEAP_SIZE` |

**Nota:** o contedor usa `GossipingPropertyFileSnitch` (preconfigurado en
cassandra.yaml), que le a topoloxía de DC e rack de
`cassandra-rackdc.properties`. Os valores de DC e rack son `axonopsdb_dc1` e
`rack1` por defecto se non se definen explicitamente.

#### Decisións de deseño clave

**Por que `exec cassandra -f`?**
- Usar `exec` substitúe o proceso da shell por Cassandra
- Cassandra pasa a ser o PID 1 e recibe os sinais directamente
- Garante un apagado limpo cando se para o contedor
- Non queda ningún proceso de shell orfo consumindo recursos

**Por que a inicialización en segundo plano?**
- O script de inicialización precisa Cassandra en marcha (require acceso CQL)
- Arrancar Cassandra primeiro permite que a inicialización agarde a que estea lista
- Arranque sen bloqueo: o contedor non queda colgado durante a inicialización
- A sonda de arranque da comprobación de saúde impón que remate antes de encamiñar tráfico

**Por que tini como sistema de init?**
- **Reenvío de sinais**: garante que SIGTERM/SIGINT cheguen a Cassandra, para un apagado ordenado
- **Recollida de zombis**: limpa os procesos fillos rematados (importante co script de inicialización en segundo plano)
- **Boa práctica en contedores**: evita problemas cando o motor de contedores envía sinais de parada
- **Sobrecarga mínima**: un binario estático diminuto (~10 KB) e sen dependencias
- **Estándar do sector**: o mesmo sistema de init que usa Docker co flag `--init`
- Sen tini, os scripts de shell (PID 1) non reenvían ben os sinais, e iso provoca matanzas forzadas

**Máis información:** [por que fai falta un sistema de init](https://github.com/krallin/tini#why-tini) nos contedores

### Banner de versión ao arrancar

Todos os contedores amosan ao arrancar información de versión completa:

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

**Ver o banner:**
```bash
docker logs axondb | head -30
```

### Sondas de saúde

O contedor inclúe un script de comprobación de saúde optimizado que admite tres
tipos de sonda, deseñado para ter unha sobrecarga mínima sen renunciar á
fiabilidade:

**1. Sonda de arranque** (`healthcheck.sh startup`)
- **Agarda a que rematen os scripts de inicialización** (crítico co patrón de inicialización asíncrona)
- Busca os ficheiros semáforo no almacenamento persistente:
  - `/var/lib/cassandra/.axonops/init-system-keyspaces.done` (debe existir)
  - `/var/lib/cassandra/.axonops/init-db-user.done` (debe existir)
- **Valida o campo RESULT**: falla se algún dos semáforos ten `RESULT=failed`
- Verifica que o proceso de Cassandra está en marcha (`pgrep -f cassandra`)
- Comproba que o porto CQL (9042) está a escoitar (comprobación TCP con `nc`)
- **Lixeira**: sen chamadas a nodetool, só comprobacións de proceso e de porto
- **Bloquea o estado «Started» do pod ata que a inicialización remata correctamente**
- Úsea para: o `startupProbe` de Kubernetes (garante que a inicialización acaba antes de encamiñar tráfico)

**2. Sonda de vida** (`healthcheck.sh liveness`)
- **Ultralixeira**: pensada para executarse a miúdo (cada 10 segundos)
- Comproba que o proceso de Cassandra está en marcha (`pgrep -f cassandra`)
- Comproba que o porto CQL (9042) está a escoitar (comprobación TCP con `nc`)
- **Sen chamadas a nodetool**: sobrecarga mínima, execución moi rápida
- Úsea para: o `livenessProbe` de Kubernetes (detectar se o proceso de Cassandra caeu)

**3. Sonda de dispoñibilidade** (`healthcheck.sh readiness`)
- Comproba que o porto CQL (9042) está a escoitar (comprobación TCP con `nc`)
- Executa `nodetool info` para verificar o estado interno de Cassandra
- Verifica que a saída indica «Native Transport active: true»
- Verifica que a saída indica «Gossip active: true»
- **Máis exhaustiva** ca a de vida: garante que Cassandra está plenamente operativa
- Úsea para: o `readinessProbe` de Kubernetes (comprobacións do balanceador de carga, encamiñamento de tráfico)

**Comprobación de saúde de Docker:**
```bash
# Built-in Docker healthcheck (uses readiness by default)
docker inspect axondb --format='{{json .State.Health}}' | jq
```

**Probar a comprobación de saúde a man:**
```bash
# Test startup probe
docker exec axondb /usr/local/bin/healthcheck.sh startup

# Test liveness probe
docker exec axondb /usr/local/bin/healthcheck.sh liveness

# Test readiness probe
docker exec axondb /usr/local/bin/healthcheck.sh readiness
```

**Nota:** a configuración das sondas de saúde xestiónana automaticamente os
charts de Helm de AxonOps. Os modos de arriba están dispoñibles para
despregamentos propios, se fan falta.

### Inicialización automatizada (keyspaces de sistema e usuario de base de datos)

O contedor fai unha inicialización automatizada no primeiro arranque, que cobre
tanto a conversión dos keyspaces de sistema como a creación opcional dun usuario
de base de datos propio. Ambas as operacións faias un único script en segundo
plano (`init-system-keyspaces.sh`) que se executa despois de que Cassandra
arranque.

#### Como funciona (fluxo de execución)

A inicialización usa un **proceso asíncrono en segundo plano** coordinado
mediante **ficheiros semáforo**, para garantir a orde correcta:

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

**Por que este patrón é seguro:**

1. **Cassandra debe executarse primeiro**: o script de inicialización precisa acceso CQL, así que Cassandra ten que estar en marcha
2. **Execución en segundo plano**: a inicialización non bloquea o arranque de Cassandra
3. **Coordinación por semáforos**: a comprobación de saúde agarda a que a inicialización remate antes de dar o contedor por listo
4. **Aplicación por Kubernetes**: o pod non se marca «Started» ata que existen os semáforos
5. **Semáforos persistentes**: gárdanse en `/var/lib/cassandra` (volume), o que evita reinicializar nos reinicios

#### Fase 1: conversión dos keyspaces de sistema

A primeira fase converte os keyspaces de sistema de `SimpleStrategy` a
`NetworkTopologyStrategy`, para que estean listos para produción.

**Que fai:**
1. Agarda a que Cassandra estea lista (porto CQL a escoitar, transporte nativo activo)
2. Verifica que se trata dun clúster dun só nodo coas credenciais por defecto
3. Detecta o nome do datacenter da instancia de Cassandra en marcha
4. Converte `system_auth`, `system_distributed` e `system_traces` a `NetworkTopologyStrategy`
5. Escribe o semáforo de finalización no almacenamento persistente: `/var/lib/cassandra/.axonops/init-system-keyspaces.done`

**Nota:** NON se executa ningunha reparación, porque este é un despregamento dun
só nodo (a reparación só ten sentido con varias réplicas).

**Comprobacións de seguridade:**
- Só se executa en clústeres dun só nodo (sáltanse os de varios nodos e escríbese un semáforo de omisión)
- Só se executa se o factor de replicación é 1 (sáltase se xa se personalizou e escríbese un semáforo de omisión)
- Só se executa se se usa `SimpleStrategy` (sáltase se xa é `NetworkTopologyStrategy` e escríbese un semáforo de omisión)
- Require as credenciais por defecto `cassandra/cassandra`
- **O semáforo escríbese SEMPRE** (con éxito, ou omitido co seu motivo)

#### Fase 2: creación dun usuario de base de datos propio (opcional)

A segunda fase crea un superusuario propio e desactiva o usuario `cassandra` por
defecto (só se se pide mediante as variables de entorno).

**Que fai:**
1. Agarda a que remate a inicialización dos keyspaces de sistema
2. Crea o novo superusuario co nome e o contrasinal indicados
3. Concédelle permisos completos de superusuario
4. Proba a autenticación co novo usuario
5. Desactiva o usuario `cassandra` por defecto (póñenselle `can_login=false`)
6. Escribe o semáforo de finalización: `/var/lib/cassandra/.axonops/init-db-user.done`

**Exemplo:**
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

**Comprobacións de seguridade:**
- Só se executa se están definidas tanto `AXONOPS_DB_USER` como `AXONOPS_DB_PASSWORD`
- Só se executa en clústeres recén creados coas credenciais por defecto
- Proba a autenticación do novo usuario antes de desactivar o usuario por defecto
- Desfai a creación do usuario se a proba de autenticación falla
- **O semáforo escríbese SEMPRE** (con éxito, omitido ou fallido, co seu motivo)

#### Control e desactivación

**Desactivar toda a inicialización:**
```bash
docker run -d --name axondb \
  -e INIT_SYSTEM_KEYSPACES_AND_ROLES=false \
  ghcr.io/axonops/axondb-timeseries:5.0.6-1.0.0
```

Cando está desactivada, os ficheiros semáforo escríbense de inmediato con
`RESULT=skipped`, para que a comprobación de saúde poida seguir adiante.

#### Ficheiros semáforo

O proceso de inicialización usa ficheiros semáforo para coordinarse entre o
script de inicialización en segundo plano e a sonda de arranque da comprobación
de saúde.

**Ubicación:** `/var/lib/cassandra/.axonops/`

Os ficheiros semáforo gárdanse no directorio de datos de Cassandra (non en
`/etc`) porque:
- `/var/lib/cassandra` adoita configurarse como volume persistente en Kubernetes
- Ao seren persistentes, os semáforos sobreviven aos reinicios de contedor ou de pod
- Evita reinicializar nos reinicios de pod (por exemplo, durante unha actualización progresiva)
- Permite que a comprobación de saúde pase de inmediato tras un reinicio, sen volver executar a inicialización

**Importante:** configure `/var/lib/cassandra` como volume persistente
(PersistentVolumeClaim) no seu despregamento de Kubernetes. Os charts de Helm de
AxonOps fano automaticamente.

**Ficheiros creados:**
- `init-system-keyspaces.done`: o estado da conversión dos keyspaces de sistema
- `init-db-user.done`: o estado da creación do usuario propio

**Formato do ficheiro:**
```
COMPLETED=2025-12-14T09:32:17Z
RESULT=success
REASON=initialized_to_nts
```

**Valores de RESULT en init-system-keyspaces.done:**
- `success`: os keyspaces de sistema convertéronse correctamente
  - `initialized_to_nts`: convertidos a NetworkTopologyStrategy
- `skipped`: a conversión omitiuse de forma segura (con REASON explicando por que)
  - `multi_node_cluster`: detectouse un clúster de varios nodos (non se pode inicializar con seguridade)
  - `already_nts`: xa usa NetworkTopologyStrategy (xa estaba feito)
  - `custom_rf`: o factor de replicación non é 1 (o usuario xa o personalizou)
  - `disabled_by_env_var`: INIT_SYSTEM_KEYSPACES_AND_ROLES=false (o usuario desactivouno)
- `failed`: a inicialización fallou (con REASON). **O script de inicialización remata con código 1**
  - `cql_port_timeout`: o porto CQL non se abriu dentro do timeout (por defecto: 10 min, configurable con `INIT_TIMEOUT`)
  - `native_transport_timeout`: o transporte nativo non se activou dentro do timeout
  - `cql_connectivity_failed`: non se pode conectar coas credenciais cassandra/cassandra
  - `dc_detection_failed`: non se puido detectar o nome do datacenter con nodetool nin en cassandra-rackdc.properties

**Cando se producen os fallos:**
- `cql_port_timeout` / `native_transport_timeout`: Cassandra non arranca correctamente (revise os rexistros)
- `cql_connectivity_failed`: cambiáronse as credenciais por defecto ou a autenticación está mal configurada
- `dc_detection_failed`: Cassandra non informa do nome do datacenter (problema de configuración)

**Configuración do timeout:**
- Timeout por defecto: 600 segundos (10 minutos)
- Configurable coa variable de entorno `INIT_TIMEOUT`
- Exemplo: `-e INIT_TIMEOUT=1200` para 20 minutos, se Cassandra arranca lento

**Valores de RESULT en init-db-user.done:**
- `success`: o usuario propio creouse correctamente
  - `user_initialized`: usuario creado e usuario cassandra desactivado
  - `user_created_cassandra_disable_failed`: usuario creado, pero non se puido desactivar o usuario cassandra (non é fatal, o contedor continúa)
- `skipped`: a creación do usuario omitiuse (con REASON)
  - `no_custom_user_requested`: AXONOPS_DB_USER non está definida
  - `user_already_exists`: o usuario propio xa existe
  - `init_disabled`: INIT_SYSTEM_KEYSPACES_AND_ROLES=false
- `failed`: a creación do usuario fallou (con REASON). **O script de inicialización remata con código 1**
  - `create_user_failed`: non se puido crear o usuario (fallou o CREATE ROLE de CQL)
  - `new_user_auth_failed`: o usuario creouse, pero a proba de autenticación fallou

**Cando se producen os fallos:**
- `create_user_failed` pode darse se:
  - Falla a conexión CQL durante a creación do usuario
  - O formato do nome de usuario ou do contrasinal é inválido
  - Hai un erro interno de Cassandra ao crear o rol
- `new_user_auth_failed` pode darse se:
  - O usuario creouse, pero o sistema de autenticación está mal configurado
  - O contrasinal non se gardou correctamente en system_auth
  - Hai un problema do protocolo de autenticación de CQL

**Importante:** cando se escribe `RESULT=failed`, o script de inicialización
remata con código 1 (fallo), e a sonda de arranque da comprobación de saúde
falla, o que impide que o contedor se marque «Started» en Kubernetes.

**Garantía:** ambos os ficheiros semáforo escríbense **SEMPRE**, en todas as
ramas de execución. A sonda de arranque da comprobación de saúde:
1. Esixe que existan os dous ficheiros semáforo
2. Comproba o campo RESULT de cada un
3. **Fai fallar a sonda de arranque se algún ten RESULT=failed**
4. Só pasa se ambos son RESULT=success ou RESULT=skipped

Así se garante que o contedor non se marque «Started» se a inicialización fallou.

#### Rexistros da inicialización

Consulte o progreso e os resultados da inicialización:

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

O repositorio inclúe workflows completos de GitHub Actions:

**Build e probas** (`.github/workflows/axondb-timeseries-build-and-test.yml`)
- **Disparadores:** push ou PR ás ramas main, development, feature/* e fix/*
  - Cando cambia `axonops/axondb-timeseries/**` (excluíndo os ficheiros `*.md`)
  - Cando cambian os workflows (`.github/workflows/axondb-timeseries-*.yml`)
  - Cando cambian as actions (`.github/actions/axondb-timeseries-*/**`)
- **Probas:** build de Docker, verificación de versión, comprobación de saúde, cqlai, cqlsh e escaneo de seguridade
- **Duración:** uns 10 minutos

**Publicación de produción** (`.github/workflows/axondb-timeseries-publish-signed.yml`)
- **Disparador:** execución manual do workflow cunha etiqueta de git
- **Proceso:** validar → probar → crear a release → construír → asinar → publicar → verificar
- **Rexistro:** `ghcr.io/axonops/axondb-timeseries`
- **Plataformas:** linux/amd64, linux/arm64
- **Sinatura:** sinatura sen chaves con Cosign (OIDC)

**Publicación de desenvolvemento** (`.github/workflows/axondb-timeseries-development-publish-signed.yml`)
- **Disparador:** execución manual do workflow dende a rama development
- **Rexistro:** `ghcr.io/axonops/development/axondb-timeseries`
- **Uso:** probar imaxes antes dunha release de produción

### Probas automatizadas

O pipeline de CI inclúe probas exhaustivas:

**Probas funcionais:**
- Verificación do build do contedor (multiarquitectura)
- Verificación do banner de arranque (produción fronte a desenvolvemento)
- Verificación de versións (jemalloc, Cassandra, Java, cqlai)
- Probas do script de comprobación de saúde (startup, liveness, readiness)
- Verificación da inicialización dos keyspaces de sistema
- Operacións CQL con cqlai
- Operacións CQL con cqlsh
- Tratamento das variables de entorno

**Probas de seguridade:**
- Escaneo de vulnerabilidades do contedor con Trivy (severidade CRITICAL e HIGH)
- Os resultados sóbense á lapela Security de GitHub
- Os CVE upstream coñecidos documéntanse en `.trivyignore`

**Accións compostas (14 accións):**
En `.github/actions/axondb-timeseries-*/`:
- `start-and-wait`: arranca o contedor e agarda a que estea listo
- `verify-startup-banner`: verifica o contido do banner
- `verify-no-startup-errors`: busca erros de arranque
- `verify-versions`: verifica as versións dos compoñentes
- `test-healthcheck`: proba todos os modos de comprobación de saúde
- `verify-init-scripts`: verifica que a inicialización rematou
- `test-cqlai`: proba o funcionamento de cqlai
- `test-cqlsh`: proba o funcionamento de cqlsh
- `test-all-env-vars`: proba a configuración por variables de entorno (10 de Cassandra + 4 de inicialización = 14 en total)
- `test-dc-detection`: proba a detección do datacenter
- `sign-container`: sinatura con Cosign
- `verify-published-image`: verificación tras a publicación
- `collect-logs`: recolle os rexistros do contedor
- `determine-latest`: determina as etiquetas latest

### Proceso de publicación

**Release de desenvolvemento:**
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

**Release de produción:**
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

Véxase [RELEASE.md](./RELEASE.md) para a documentación completa do proceso de
release.

## Resolución de problemas

### Comprobar a versión do contedor

Consulte o banner de arranque para ver todas as versións dos compoñentes:

```bash
docker logs axondb | head -30
```

O banner amosa:
- A versión do contedor e a revisión de git
- As versións de Cassandra, Java, cqlai e jemalloc
- O digest da imaxe base (para verificar a cadea de subministración)
- Os detalles do entorno de execución

### Rexistros do script de inicialización

Consulte o progreso e os resultados da inicialización:

```bash
# View init script output
docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log

# Check system keyspace init status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-system-keyspaces.done

# Check custom user creation status (in persistent volume)
docker exec axondb cat /var/lib/cassandra/.axonops/init-db-user.done
```

**Formato do ficheiro semáforo:**
```
COMPLETED=2025-12-13T10:45:00Z
RESULT=success
```

Valores posibles de `RESULT`:
- `success`: a operación rematou correctamente
- `skipped`: a operación omitiuse (cun campo REASON explicando por que)

### Depurar a comprobación de saúde

Probe as sondas de saúde a man:

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

### O contedor non arranca

**Revise os rexistros:**
```bash
docker logs axondb
```

**Problemas habituais:**

1. **Memoria insuficiente:**
   - O heap por defecto é de 8G; asegúrese de que o contedor ten polo menos 12 GB de RAM
   - Axústeo con: `-e CASSANDRA_HEAP_SIZE=4G`

2. **Conflitos de portos:**
   - CQL: 9042
   - JMX: 7199
   - Compróbeo con: `netstat -tuln | grep 9042`

3. **Problemas de permisos:**
   - O contedor execútase como o usuario `cassandra` (UID 999)
   - Asegure os permisos do volume: `chown -R 999:999 /data/cassandra`

4. **Timeout da inicialización:**
   - Os scripts de inicialización agardan ata 10 minutos por Cassandra
   - Revise: `docker exec axondb cat /var/log/cassandra/init-system-keyspaces.log`

**Consultar os rexistros de Cassandra:**
```bash
docker exec axondb cat /var/log/cassandra/system.log
```

**Verificar que Cassandra está en marcha:**
```bash
docker exec axondb nodetool status
```

## Consideracións para produción

1. **Almacenamento persistente**
   - Use sempre volumes para `/var/lib/cassandra` (datos)
   - Use volumes para `/var/log/cassandra` (rexistros)
   - Exemplo: `-v /data/cassandra:/var/lib/cassandra`

2. **Asignación de recursos**
   - Memoria: polo menos 1,5 veces o tamaño do heap (por exemplo, 12 GB para un heap de 8 GB)
   - CPU: recoméndanse 4 ou máis núcleos
   - Disco: almacenamento SSD para cargas de produción

3. **Rede**
   - Expoña os portos necesarios: 9042 (CQL), 7199 (JMX), 7000 (entre nodos)
   - Use regras de cortalumes axeitadas
   - Valore usar TLS para a comunicación entre nodos e cos clientes

4. **Seguridade**
   - Use un usuario de base de datos propio (defina `AXONOPS_DB_USER` e `AXONOPS_DB_PASSWORD`)
   - Verifique as sinaturas dos contedores con Cosign
   - Use referencias de imaxe baseadas en digest, por inmutabilidade
   - Manteña as imaxes base actualizadas (automatizado en UBI)

5. **Monitorización**
   - Use as sondas de saúde para monitorizar a dispoñibilidade
   - Vixíe o uso do heap por JMX
   - Configure a agregación de rexistros de `/var/log/cassandra/`
   - Valore integralo con AxonOps para unha monitorización completa

6. **Copia de seguranza e restauración**

   Este contedor inclúe funcionalidade integrada de copia de seguranza e
   restauración, pensada para despregamentos dun só nodo.

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

   **Prestacións clave:**
   - Copias baseadas en snapshots con deduplicación por ligazóns duras (76 % de aforro de espazo)
   - Compatible con Kubernetes (restauración sen bloqueo, segura coa sonda de arranque)
   - Retención automática con borrado asíncrono
   - Conservación dos semáforos `.axonops` (evita reinicializar ao restaurar)
   - Tratamento dos cambios de enderezo IP
   - Rotación de rexistros con compresión

   **Configuración:**

   | Variable | Obrigatoria | Valor por defecto | Descrición |
   |----------|----------|---------|-------------|
   | `BACKUP_SCHEDULE` | Non | - | Expresión cron (por exemplo, `0 */6 * * *` para cada 6 horas) |
   | `BACKUP_RETENTION_HOURS` | Se hai schedule | - | Horas que se conservan as copias (por exemplo, `168` para 7 días) |
   | `BACKUP_MINIMUM_RETENTION_COUNT` | Non | `1` | Conserva sempre polo menos N copias |
   | `BACKUP_USE_HARDLINKS` | Non | `true` | Usa deduplicación por ligazóns duras |
   | `BACKUP_CALCULATE_STATS` | Non | `false` | Calcula o aforro de espazo (custoso) |
   | `BACKUP_RSYNC_RETRIES` | Non | `3` | Número de reintentos de rsync |
   | `BACKUP_RSYNC_TIMEOUT_MINUTES` | Non | `120` | Timeout de rsync (conxuntos de datos grandes) |
   | `RESTORE_FROM_BACKUP` | Non | - | O nome da copia, ou `latest` |
   | `RESTORE_ENABLED` | Non | `false` | Activa a restauración sen indicar o nome da copia |
   | `RESTORE_RESET_CREDENTIALS` | Non | `false` | Borra system_auth ao restaurar (volve a cassandra/cassandra) |
   | `RSYNC_BWLIMIT_KB` | Non | - | Límite de largura de banda das copias, en KB/s |
   | `ENABLE_SEMAPHORE_MONITOR` | Non | `false` | Vixía o estado de copia e restauración |

   **Exemplo para Kubernetes:**
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

   **Restaurar dende unha copia (recreación do pod):**
   ```yaml
   # After pod deletion, restore from backup on new pod
   env:
   - name: RESTORE_FROM_BACKUP
     value: "latest"  # or specific: "backup-20251226-120000"
   ```

   **Notas importantes:**
   - **Só un nodo**: as copias están pensadas para clústeres dun só nodo
   - **As ligazóns duras son locais**: ao copiar as copias a almacenamento remoto (S3, NFS), as ligazóns duras pasan a ser ficheiros independentes (copia completa)
   - **Conservación de `.axonops`**: os semáforos de inicialización cópianse e restáuranse, para evitar reinicializar
   - **Restauración sen bloqueo**: a restauración corre en segundo plano e o contedor arranca con normalidade (compatible con Kubernetes)
   - **Credenciais conservadas**: as credenciais propias da copia restáuranse automaticamente (agás con `RESTORE_RESET_CREDENTIALS=true`)
   - **Reinicio de credenciais** (`RESTORE_RESET_CREDENTIALS=true`): borra todos os usuarios e roles da copia
     - Volve a cassandra/cassandra (o usuario propio créase automaticamente se se define AXONOPS_DB_USER)
     - Pérdense todos os permisos e concesións da copia
     - Úseo en restauracións de produción a desenvolvemento, onde interesa reiniciar as credenciais

   **Ubicación das copias:**
   - Monte o volume `/backup` para que persistan
   - As copias gárdanse como: `/backup/data_backup-YYYYMMDD-HHMMSS/`
   - Inclúen un volcado do esquema (`schema.cql`) e os snapshots de datos

   **Exemplos de restauración:**
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

   **Vixiar as copias:**
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

   | Problema | Que revisar | Solución |
   |-------|-------|----------|
   | Non se crean copias | `cat /var/log/cassandra/backup-scheduler.log` | Comprobe que BACKUP_SCHEDULE é un cron válido |
   | A retención non funciona | `cat /var/log/cassandra/retention-cleanup.log` | Comprobe que BACKUP_RETENTION_HOURS está definida |
   | A restauración falla | `cat /var/log/cassandra/restore.log` | Comprobe que a copia existe: `ls /backup/data_backup-*` |
   | A inicialización execútase ao restaurar | `cat /var/lib/cassandra/.axonops/init-*.done` | Comprobe que `.axonops` está na copia |
   | Erros de bloqueo | `cat /tmp/axonops-backup.lock` | Agarde a que remate a copia anterior |

   Para as probas detalladas, véxase [tests/README.md](./5.0.6/tests/README.md).

7. **Despregamento en clúster**
   - Use valores consistentes de `CASSANDRA_DC` e `CASSANDRA_RACK` en todos os nodos
   - Configure `CASSANDRA_SEEDS` con varios nodos seed
   - Defina `CASSANDRA_CLUSTER_NAME` de forma consistente
   - Planifique os despregamentos multidatacenter se os precisa

Para o fluxo de traballo de desenvolvemento e as probas, véxase
[DEVELOPMENT.md](./DEVELOPMENT.md).

Para o proceso de release, véxase [RELEASE.md](./RELEASE.md).
