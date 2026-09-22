# Exemplo 01 — AxonOps autoaloxado monitorizando un clúster de Cassandra de 3 nodos

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Unha instalación completa de AxonOps e o clúster de Apache Cassandra que
monitoriza, nun único proxecto de Docker Compose. Todas as imaxes veñen deste
repositorio ou do rexistro público de AxonOps. Empece aquí se está a avaliar
AxonOps.

- Xa executa Cassandra ou Kafka e só precisa un sitio ao que reporten os axentes?
  [Exemplo 00](../00-axonops-platform/): a plataforma por si soa.
- Ten unha conta de AxonOps Cloud? [Exemplo 02](../02-saas-cassandra-cluster/):
  o mesmo clúster, sen plataforma que executar.

## Inicio rápido

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose ps            # wait for all services to report healthy
```

Despois abra <http://localhost:3000>, escolla a súa organización e logo o clúster
`demo-cluster`.

Un arranque en frío tarda de 5 a 10 minutos: primeiro inicialízanse os almacéns
de datos de AxonOps, e despois os nodos de Cassandra arrancan dun en un.

## Que executa

| Servizo | Imaxe | Propósito | Porto publicado |
|---------|-------|---------|----------------|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Almacén de métricas (Cassandra) | — |
| `axondb-search` | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Almacén de rexistros e eventos (OpenSearch) | — |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35` | Backend de AxonOps e endpoint dos axentes | `1888` |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash:2.0.37` | Panel web | `3000` |
| `cassandra-0` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Clúster monitorizado, nodo seed | `9042` |
| `cassandra-1` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Clúster monitorizado, rack1 | — |
| `cassandra-2` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Clúster monitorizado, rack2 | — |

De `cassandra-0` a `cassandra-2` forman un único datacenter, `dc1`, cun rack cada
un. Só `cassandra-0` publica CQL ao host; os outros dous son accesibles dentro da
rede de Compose e con `docker exec`.

As etiquetas e digests actuais de cada imaxe: [VERSIONS.md](../../VERSIONS.md).

## Configuración

Todo se define no `.env`. Lista completa cos valores por defecto:
[`env.example`](env.example).

| Variable | Valor por defecto | Descrición |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Nome da organización. Compartido por `axon-server` e os axentes: deben coincidir. |
| `CASSANDRA_CLUSTER_NAME` | `demo-cluster` | Nome do clúster monitorizado en AxonOps |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Imaxe dos nodos monitorizados |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap por nodo monitorizado |
| `CASSANDRA_HEAP_NEWSIZE` | `256M` | Xeración nova por nodo monitorizado |
| `AXONOPS_LICENSE_KEY` | (baleiro) | Chave de licenza; baleiro executa en modo de proba |
| `AXONOPS_DB_PASSWORD` | `axonops` | Contrasinal de `axondb-timeseries` |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Contrasinal de administración de `axondb-search` |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `2G` | Heap de `axondb-timeseries` |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `2g` | Heap de `axondb-search` |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS de `axon-server` a `axondb-timeseries`: déixeo desactivado agás que monte un keystore, véxase [máis abaixo](#variables-de-configuración-que-parecen-correctas-pero-non-o-son) |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS de `axon-server` a `axondb-search` |

`axon-server` configúrase por completo mediante variables de entorno: non hai
ningún ficheiro de configuración que montar nin renderizar. Cada variable
sobrescribe o campo correspondente do `axon-server.yml` incluído na imaxe:

| axon-server.yml | Variable de entorno |
|-----------------|----------------------|
| `org_name` | `AXONSERVER_ORGNAME` |
| `license_key` | `LICENSE_KEY` |
| `tls.mode` | `TLS_MODE` |
| `log_file` | `AXON_LOG_FILE` |
| `axon_dash_url` | `AXONDASH_HOST`, `AXONDASH_PORT`, `AXONDASH_HTTPS` |
| `cql_hosts` | `CQL_HOSTS` (separadas por comas) |
| `cql_username` / `cql_password` | `CQL_USERNAME` / `CQL_PASSWORD` |
| `cql_local_dc` | `CQL_LOCAL_DC` |
| `cql_ssl` / `cql_skip_verify` | `CQL_SSL` / `CQL_SSL_SKIP_VERIFY` |
| `cql_keyspace_replication` | `CQL_KS_REPLICATION` |
| `search_db.hosts` | `SEARCH_DB_HOSTS` (separadas por comas) |
| `search_db.username` / `password` | `SEARCH_DB_USERNAME` / `SEARCH_DB_PASSWORD` |
| `search_db.skip_verify` | `SEARCH_DB_SKIP_VERIFY` |

axon-server liga 72 variables en total, que cobren a política de reintentos e
reconexión, os niveis de consistencia, as xanelas de compactación, a
autenticación LDAP e SMTP. Todo o que non se defina conserva o valor do propio
`axon-server.yml` da imaxe.

As antigas variables `ELASTIC_*` son a xeración anterior das `SEARCH_DB_*`: non
mesture as dúas formas.

Os axentes conéctanse a `axon-server:1888` en texto plano
(`AXON_AGENT_TLS_MODE=disabled`) porque o tráfico nunca sae da rede de Compose.
Use TLS para axentes en calquera outro host.

### Saúde dos nodos monitorizados

Os nodos de Cassandra usan a comprobación de saúde que trae a imaxe,
`/usr/local/bin/axonops-healthcheck.sh`, no canto dunha escrita aquí. Verifica
dúas cousas: que Cassandra está a servir CQL, e que o proceso `axon-agent` está
en execución; un nodo cuxo axente morreu segue respondendo consultas pero
desapareceu en silencio de AxonOps, e unha comprobación que só mire a Cassandra
dará por san.

Un axente caído reflíctese na saída da comprobación, pero por si só non volve
unhealthy o contedor, porque facer fallar a comprobación pode levar a un
orquestrador a reiniciar ou baleirar un nodo que segue servindo. Poña
`HEALTHCHECK_REQUIRE_AGENT=true` nun nodo para tratalo como un fallo:

```bash
docker compose exec cassandra-0 /usr/local/bin/axonops-healthcheck.sh
```

O axente só arranca unha vez Cassandra está levantada, así que normalmente está
ausente durante parte do período de arranque de 90 s.

Tanto a comprobación do axente como `HEALTHCHECK_REQUIRE_AGENT` están na imaxe
fixada, `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`. En calquera
imaxe anterior o script verifica só Cassandra e a variable non ten efecto.

## Usar o clúster

```bash
# CQL from the host
cqlsh 127.0.0.1 9042

# CQL from inside a node, using the bundled cqlai client
docker compose exec cassandra-0 cqlai -e "SELECT release_version FROM system.local;"

# Ring status
docker compose exec cassandra-0 nodetool status
```

Escriba algúns datos para que o panel teña algo que amosar:

```bash
docker compose exec cassandra-0 cqlai -e "
  CREATE KEYSPACE IF NOT EXISTS demo
    WITH replication = {'class':'NetworkTopologyStrategy','dc1':3};
  CREATE TABLE IF NOT EXISTS demo.events (
    id uuid PRIMARY KEY, created timestamp, payload text);
  INSERT INTO demo.events (id, created, payload)
    VALUES (uuid(), toTimestamp(now()), 'hello');"
```

## Operación

```bash
docker compose ps                       # health of every service
docker compose logs -f axon-server      # follow one service
docker compose logs -f cassandra-0
docker compose exec cassandra-0 tail -f /var/log/axonops/axon-agent.log
docker compose down                     # stop, keep data
docker compose down -v                  # stop and delete all volumes
```

## Requisitos

- Docker Engine 20.10+ e Compose V2
- 10 GB de RAM libres cos valores por defecto de arriba, 20 GB de disco
- Portos 3000, 1888 e 9042 libres no host

Baixe `CASSANDRA_HEAP_SIZE`, `AXONOPS_CASSANDRA_HEAP_SIZE` e
`AXONOPS_OPENSEARCH_HEAP_SIZE` se ten menos memoria. Esta é unha pila de
desenvolvemento e avaliación; o dimensionamento de produción está na
documentación da pila do
[exemplo 00](../00-axonops-platform/README.gl.md#requisitos).

## Resolución de problemas

**Un nodo de Cassandra nunca chega a estar healthy.** Os nodos arrancan dun en un
e `start_period` é de 90 s. Obsérveo con `docker compose logs -f cassandra-1`. A
falta de memoria é a causa habitual: baixe `CASSANDRA_HEAP_SIZE`.

**O clúster non aparece no panel.** O axente e `axon-server` deben compartir
organización. `AXONOPS_ORG_NAME` no `.env` define ambos; compróbeo con
`docker compose exec cassandra-0 env | grep AXON_AGENT_ORG`.

**`axon-server` reiníciase.** Precisa os dous almacéns de datos healthy. Revise
`docker compose logs axondb-timeseries axondb-search`, e confirme que
`AXONOPS_DB_PASSWORD` e `AXONOPS_SEARCH_PASSWORD` coinciden entre eles e
`axon-server`.

### Variables de configuración que parecen correctas pero non o son

Tres dos servizos admiten configuración baixo nomes distintos dos que suxiren os
seus READMEs. Cada un destes casos deuse ao levantar este exemplo, e cada un
falla dun xeito que non nomea a variable culpable.

**`axondb-search` remata cun fallo de bootstrap check.**

```
ERROR: [1] bootstrap checks failed
[1]: the default discovery settings are unsuitable for production use;
     at least one of [discovery.seed_hosts, discovery.seed_providers,
     cluster.initial_cluster_manager_nodes] must be configured
```

`OPENSEARCH_DISCOVERY_TYPE` estaba documentada e imprimíase no banner de arranque
do contedor, pero as builds anteriores a `3.7.0-1.6.1` nunca a escribían en
`opensearch.yml`. Funciona a partir de `3.7.0-1.6.1`. Este exemplo segue pasando
ademais o `discovery.type=single-node` propio de OpenSearch, que o proceso le
directamente, así que o ficheiro segue funcionando contra unha imaxe máis antiga;
quite esa liña cando estea en `3.7.0-1.6.1` ou posterior en todas partes.

**Cassandra rexistra `Invalid or unsupported protocol version (22)` e
`axon-server` rexistra `tls: first record does not look like a TLS handshake`.**

22 é `0x16`, o primeiro byte dun ClientHello de TLS lido como unha versión de
protocolo CQL: un lado está a usar TLS e o outro non. `axondb-timeseries` só
activa as `client_encryption_options` cando hai un keystore montado en
`CASSANDRA_KEYSTORE_PATH`; non hai ningunha variable que o active por si soa, e
`CASSANDRA_CLIENT_ENCRYPTION_ENABLED` non fai nada. Así que o transporte nativo
vai en texto plano e `CQL_SSL` debe estar a `false` para facer o mesmo. Para usar
TLS, monte un keystore e configure os dous lados á vez.

**`axon-dash` entra en bucle de caída con `findHost | no reachable endpoints` e
`ECONNREFUSED 127.0.0.1:8080`.**

`axon-dash` mapea o seu `axon-dash.yml` sobre variables de entorno por sección e
chave: `axon-server.private_endpoints` convértese en
`AXONSERVER_PRIVATE_ENDPOINTS`, e `axon-dash.port` en `AXONDASH_PORT`. Acepta
ademais calquera cousa co prefixo `AXON_SERVER_`, pásaa a minúsculas e fúndea na
sección `axon-server`, o que significa que un nome equivocado como
`AXON_SERVER_URL` acéptase en silencio e aparece na configuración que o dash
imprime ao arrancar sen ter ningún efecto. O enderezo que o dash marca realmente
é `private_endpoints`; compróbeo nese bloque de configuración impreso.

## Soporte

Mantido por [AxonOps](https://axonops.com). Para soporte, contacte connosco en
[axonops.com/contact](https://axonops.com/contact).
