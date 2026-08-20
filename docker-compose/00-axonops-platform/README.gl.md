# Exemplo 00 — A plataforma AxonOps por si soa

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Unha instalación autoaloxada completa de AxonOps, e nada máis. Apunte a ela os
axentes dos seus propios hosts, ou úsea como base para os demais exemplos.

- Quere un clúster de Cassandra monitorizado no mesmo proxecto?
  [Exemplo 01](../01-cassandra-cluster/): a plataforma máis tres nodos.
- Ten unha conta de AxonOps Cloud? [Exemplo 02](../02-saas-cassandra-cluster/):
  un clúster que reporta a SaaS, sen plataforma que executar.

## Inicio rápido

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose ps            # wait for all four services to report healthy
```

Despois abra <http://localhost:3000>.

Un arranque en frío tarda de 2 a 3 minutos: primeiro inicialízanse os dous
almacéns de datos, e detrás deles soben `axon-server` e o panel.

## Que executa

| Servizo | Imaxe | Propósito | Porto publicado |
|---------|-------|---------|----------------|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Almacén de métricas (Cassandra) | — |
| `axondb-search` | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Almacén de rexistros e eventos (OpenSearch) | — |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35` | Backend e endpoint dos axentes | `1888` |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash:2.0.37` | Panel web | `3000` |

As etiquetas e digests actuais de cada imaxe: [VERSIONS.md](../../VERSIONS.md).

## Configuración

Todo se define no `.env`. Lista completa cos valores por defecto:
[`env.example`](env.example).

| Variable | Valor por defecto | Descrición |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Nome da organización, amosado no panel. Os axentes deben usar o mesmo valor. |
| `AXONOPS_LICENSE_KEY` | (baleiro) | Chave de licenza; baleiro executa en modo de proba |
| `AXONOPS_DB_PASSWORD` | `axonops` | Contrasinal de `axondb-timeseries` |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Contrasinal de administración de `axondb-search` |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `4G` | Heap de `axondb-timeseries` |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `4g` | Heap de `axondb-search` |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS de `axon-server` a `axondb-search` |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS de `axon-server` a `axondb-timeseries`: véxase máis abaixo |

`axon-server` configúrase por completo mediante variables de entorno; non hai
ningún ficheiro de configuración que montar nin renderizar. Cada unha sobrescribe
o campo correspondente do `axon-server.yml` incluído na imaxe:
`AXONSERVER_ORGNAME`, `LICENSE_KEY`, `TLS_MODE`, o conxunto `CQL_*` para o
almacén de métricas e o conxunto `SEARCH_DB_*` para o almacén de rexistros. A
correspondencia completa está no
[exemplo 01](../01-cassandra-cluster/README.gl.md#configuración).

### TLS entre os servizos

**Cara a `axondb-search`: activado.** A imaxe xera os seus propios certificados
autoasinados, `axon-server` conéctase por HTTPS e omite a verificación.

**Cara a `axondb-timeseries`: desactivado.** A imaxe só activa as
`client_encryption_options` de Cassandra cando hai un keystore montado en
`CASSANDRA_KEYSTORE_PATH` —ningunha variable de entorno o activa por si soa—,
así que o transporte nativo vai en texto plano e `axon-server` debe facer o
mesmo. Activar `AXONOPS_CASSANDRA_SSL` sen montar un keystore rompe a conexión;
véxase [Resolución de problemas](#resolución-de-problemas).

Todo este tráfico permanece dentro da rede de Compose.

## Conectar axentes

O endpoint dos axentes (`1888`) está publicado, así que os axentes doutros hosts
poden conectarse:

```yaml
# axon-agent.yml on the monitored host
axon-server:
  hosts: "your-docker-host:1888"
axon-agent:
  org: "my-company"        # must match AXONOPS_ORG_NAME
```

Os axentes en contedores toman os mesmos axustes como variables de entorno:
`AXON_AGENT_SERVER_HOST`, `AXON_AGENT_SERVER_PORT`, `AXON_AGENT_ORG`. O exemplo
01 conecta exactamente iso para un clúster de Cassandra no mesmo proxecto.

## Fixar a imaxe: etiquetas fronte a sumas de verificación

Cada `image:` de `docker-compose.yaml` pode escribirse de dúas maneiras. As dúas
amósanse a continuación e as dúas funcionan, pero dan garantías moi distintas.

```yaml
# Tag — readable, mutable
image: ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0

# Digest (SHA256 checksum) — preferred
image: ghcr.io/axonops/axondb-timeseries@sha256:1ae990a737d36b7c6f8eb92d6d3baf5234e5eae2a4e37fa208acd1108cad934c
```

**Use o digest.** Un digest é unha suma de verificación criptográfica do contido
exacto da imaxe, así que `docker compose pull` só pode descargar os bytes contra
os que vostede probou. Unha etiqueta non é máis ca un punteiro mutable: quen
controle o rexistro pode movela, e entón o mesmo ficheiro de Compose arranca en
silencio unha imaxe distinta. Ese é o risco de cadea de subministración que
eliminan os digests.

Guía práctica:

| Referencia | Cando usala |
|-----------|-------------|
| `@sha256:<digest>` | **Produción, e todo o que necesite reproducir.** Inmutable, verificable, auditable. |
| `:5.0.8-1.4.0` (etiqueta de versión) | Desenvolvemento e avaliación, onde a lexibilidade importa máis ca a inmutabilidade. Este repositorio nunca sobrescribe unha etiqueta de versión publicada, así que na práctica son estables, só que sen garantía criptográfica. |
| `:latest`, `:5.0.8` (etiquetas flotantes) | Nunca en produción. Móvense con cada release. |

A contrapartida é a lexibilidade: un digest non lle di nada sobre que versión
está a executar. Manteña a etiqueta de versión ao seu carón nun comentario, como
fai `docker-compose.yaml`, e rexistre a correspondencia en
[VERSIONS.md](../../VERSIONS.md).

### Atopar o digest dunha versión

En [VERSIONS.md](../../VERSIONS.md) hai referencias listas para copiar e pegar da
release actual de cada imaxe, rexeradas por `../../scripts/update-versions.sh`.

Para resolver unha vostede mesmo, sen descargar a imaxe:

```bash
docker buildx imagetools inspect ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0 \
  --format '{{ .Manifest.Digest }}'
```

Ou, se xa a descargou:

```bash
docker inspect ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0 \
  --format '{{ index .RepoDigests 0 }}'
```

Todas as imaxes publicadas en GHCR están asinadas con Cosign de Sigstore.
Verifique a sinatura contra o digest antes de despregar: consulte
[Despregamento con seguridade de referencia](../../README.gl.md#despregamento-con-seguridade-de-referencia)
para o procedemento completo e a súa xustificación.

## Operación

```bash
docker compose ps                       # health of every service
docker compose logs -f                  # follow everything
docker compose logs -f axon-server      # follow one service
docker compose down                     # stop, keep data
docker compose down -v                  # stop and delete all volumes
```

Os datos viven en volumes con nome: `axondb-timeseries-data`,
`axondb-timeseries-logs`, `axondb-search-data`, `axondb-search-logs`,
`axon-server-data`.

## Requisitos

- Docker Engine 20.10+ e Compose V2
- 10 GB de RAM libres cos valores por defecto de arriba, 16 GB recomendados; 20 GB de disco
- Portos 3000 e 1888 libres no host

Para unha máquina de desenvolvemento con menos memoria, baixe os dous heaps:

```bash
AXONOPS_CASSANDRA_HEAP_SIZE=2G
AXONOPS_OPENSEARCH_HEAP_SIZE=2g
```

## Resolución de problemas

**Un servizo nunca chega a estar healthy.** O primeiro arranque tarda de 2 a 3
minutos. Obsérveo con `docker compose ps` e logo lea o rexistro dese servizo:
`docker compose logs -f axondb-timeseries`.

**`axon-server` reiníciase.** Precisa os dous almacéns de datos healthy;
`depends_on: condition: service_healthy` impón a orde, así que revise primeiro
`docker compose logs axondb-timeseries axondb-search`. Despois confirme que
`AXONOPS_DB_PASSWORD` e `AXONOPS_SEARCH_PASSWORD` coinciden entre os almacéns e
`axon-server`.

**Falta de memoria.** Baixe `AXONOPS_CASSANDRA_HEAP_SIZE` e
`AXONOPS_OPENSEARCH_HEAP_SIZE` como se indica arriba.

**O panel non carga.** Comprobe que o dash chega ao backend:

```bash
docker exec axon-dash curl -s http://axon-server:8080/api/v1/healthz
```

**Cassandra rexistra `Invalid or unsupported protocol version (22)` e
`axon-server` rexistra `tls: first record does not look like a TLS handshake`.**
Un lado está a usar TLS e o outro non: 22 é `0x16`, o primeiro byte dun
ClientHello de TLS lido como unha versión de protocolo CQL. Poña
`AXONOPS_CASSANDRA_SSL=false` a menos que teña montado un keystore, como se
explica en [TLS entre os servizos](#tls-entre-os-servizos).

**Outros axustes que parecen correctos pero se ignoran.** Tres destas imaxes
admiten configuración baixo nomes distintos dos que suxiren os seus propios
READMEs, e cada unha falla sen nomear a variable culpable. O exemplo 01 documenta
as tres:
[variables de configuración que parecen correctas pero non o son](../01-cassandra-cluster/README.gl.md#variables-de-configuración-que-parecen-correctas-pero-non-o-son).

## Licenzas

AxonOps require licenza para uso en produción: <https://axonops.com>. A pila
funciona sen chave de licenza en modo de proba, o que abonda para a avaliación e
para os demais exemplos de aquí.

## Soporte

Mantido por [AxonOps](https://axonops.com). Para soporte, contacte connosco en
[axonops.com/contact](https://axonops.com/contact).
