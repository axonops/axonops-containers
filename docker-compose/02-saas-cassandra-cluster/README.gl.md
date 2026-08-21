# Exemplo 02 — AxonOps SaaS monitorizando un clúster de Cassandra de 3 nodos

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Un clúster de Apache Cassandra de 3 nodos cuxos axentes reportan a AxonOps SaaS.
Non se executa ningunha plataforma AxonOps en local: os únicos contedores son os
nodos de Cassandra, e o panel é o aloxado.

- Prefire a plataforma enteira na súa propia máquina?
  [Exemplo 01](../01-cassandra-cluster/): o mesmo clúster, con AxonOps autoaloxado.
- Xa executa Cassandra ou Kafka noutro sitio?
  [Exemplo 00](../00-axonops-platform/): a plataforma por si soa.

## Inicio rápido

```bash
cp env.example .env          # set AXONOPS_ORG_NAME and AXONOPS_AGENT_KEY
docker compose up -d
docker compose ps            # wait for all three nodes to report healthy
```

Despois abra <https://console.axonops.cloud> e escolla o clúster
`saas-demo-cluster`. Os nodos van aparecendo segundo arrancan; un arranque en
frío tarda de 3 a 5 minutos porque arrancan dun en un.

O nome da súa organización e a chave de axente veñen ambos da súa conta de
AxonOps Cloud: déase de alta en <https://axonops.cloud>, e consulte
[a configuración do axente](https://axonops.com/docs/get_started/agent_setup/)
para ver onde se amosa a chave. Os axentes non arrancarán sen eles: Compose falla
de inmediato con `set AXONOPS_AGENT_KEY in .env` no canto de arrancar un clúster
que non reporta a ningures.

## Que executa

| Servizo | Imaxe | Propósito | Porto publicado |
|---------|-------|---------|----------------|
| `cassandra-0` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Nodo seed, `rack0` | `9042` |
| `cassandra-1` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | `rack1` | — |
| `cassandra-2` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | `rack2` | — |

Un único datacenter, `dc1`, cun rack por nodo. Só `cassandra-0` publica CQL ao
host; os demais son accesibles dentro da rede de Compose e a través de
`docker exec`.

As etiquetas e digests actuais de cada imaxe: [VERSIONS.md](../../VERSIONS.md).

## Que cambia con SaaS

Hai tres diferenzas que importan ao executar isto no canto do
[exemplo 01](../01-cassandra-cluster/); a comparación completa está no
[índice](../README.gl.md#cal-quero).

- **Credenciais.** SaaS precisa unha chave de axente ademais do nome da
  organización. Ambas son obrigatorias: Compose négase a arrancar sen elas.
- **TLS está activado.** Os axentes usan por defecto `AXON_AGENT_TLS_MODE=TLS`
  con verificación de certificado; o exemplo 01 desactiva TLS porque ese tráfico
  nunca sae da rede de Compose, o que aquí non é certo.
- **As súas métricas saen do host.** Almacénanse en AxonOps SaaS no canto de nun
  `axondb-timeseries` local, e o panel é o aloxado.

## Configuración

Todo se define no `.env`. Lista completa cos valores por defecto:
[`env.example`](env.example).

| Variable | Valor por defecto | Descrición |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | — | Organización de AxonOps. Obrigatoria. |
| `AXONOPS_AGENT_KEY` | — | Chave de axente da consola. Obrigatoria. |
| `CASSANDRA_CLUSTER_NAME` | `saas-demo-cluster` | Nome do clúster amosado en AxonOps |
| `CASSANDRA_DC` | `dc1` | Nome do datacenter |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Imaxe dos nodos |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap por nodo |
| `CASSANDRA_HEAP_NEWSIZE` | `256M` | Xeración nova por nodo |
| `CQL_PORT` | `9042` | Porto do host para CQL en `cassandra-0` |
| `AXONOPS_SERVER_HOST` | `agents.axonops.cloud` | Endpoint dos axentes |
| `AXONOPS_SERVER_PORT` | `443` | Porto do endpoint dos axentes |
| `AXONOPS_NTP_HOST` | `time.google.com` | Host NTP para a comprobación de desviación do reloxo do axente |

A chave de axente é unha credencial. `.env` está no gitignore: non a suba, e non
a incruste nunha imaxe.

### Requisitos de rede

Os axentes fan conexións TLS **saíntes** a `agents.axonops.cloud:443`. Non se
precisa nada entrante. Tras un proxy de saída ou un cortalumes, permita ese host
e ese porto; non hai repregue a texto plano.

Comprobe que un axente está conectado:

```bash
docker compose exec cassandra-0 tail -f /var/log/axonops/axon-agent.log
```

Un axente san rexistra unha conexión correcta. `Unable to connect to axonops
services` significa que o endpoint é inalcanzable ou que a chave é incorrecta.

### Saúde dos nodos

Os nodos usan a comprobación de saúde que trae a imaxe,
`/usr/local/bin/axonops-healthcheck.sh`, no canto dunha escrita aquí. Verifica
tanto que Cassandra está a servir CQL como que o proceso `axon-agent` está en
execución, o que aquí importa máis ca nos exemplos autoaloxados, porque un nodo
cuxo axente morreu non reporta nada a SaaS aínda que siga respondendo consultas.

Un axente caído reflíctese na saída da comprobación, pero por si só non volve
unhealthy o contedor; facer fallar a comprobación pode levar a un orquestrador a
reiniciar ou baleirar un nodo que segue servindo. Poña
`HEALTHCHECK_REQUIRE_AGENT=true` para tratalo como un fallo:

```bash
docker compose exec cassandra-0 /usr/local/bin/axonops-healthcheck.sh
```

O axente só arranca unha vez Cassandra está levantada, así que normalmente está
ausente durante parte do período de arranque de 90 s.

A comprobación do axente chegou a `axonops-healthcheck.sh` despois de publicarse
a imaxe fixada actualmente, así que en
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` o script verifica só
Cassandra e `HEALTHCHECK_REQUIRE_AGENT` non ten efecto. Ambos entran en vigor coa
seguinte release da imaxe de Cassandra.

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
docker compose ps                       # health of every node
docker compose logs -f cassandra-0      # Cassandra output
docker compose exec cassandra-0 tail -f /var/log/axonops/axon-agent.log
docker compose down                     # stop, keep data
docker compose down -v                  # stop and delete all volumes
```

## Requisitos

- Docker Engine 20.10+ e Compose V2
- 5 GB de RAM libres cos valores por defecto de arriba, 10 GB de disco
- Porto 9042 libre no host, ou defina `CQL_PORT`
- HTTPS saínte cara a `agents.axonops.cloud`
- Unha organización de AxonOps SaaS e unha chave de axente

## Resolución de problemas

**Compose négase a arrancar con `set AXONOPS_AGENT_KEY in .env`.** Ese é o
comportamento previsto: tanto `AXONOPS_ORG_NAME` como `AXONOPS_AGENT_KEY` son
obrigatorias, e un clúster sen chave non reportaría a nada.

**O clúster nunca aparece na consola.** Revise a liña de conexión no rexistro do
axente. As causas habituais son unha chave doutra organización, filtrado de saída
no porto 443, ou un reloxo desviado máis duns poucos segundos: nese caso o axente
rexistra un aviso de NTP.

**Un nodo nunca chega a estar healthy.** Os nodos arrancan dun en un e
`start_period` é de 90 s. Observe `docker compose logs -f cassandra-1`. A falta
de memoria é a causa habitual: baixe `CASSANDRA_HEAP_SIZE`.

**Unha variable parece ignorarse.** O axente le os nomes `AXON_AGENT_*` ligados
no seu propio paquete de configuración: `AXON_AGENT_ORG`, `AXON_AGENT_KEY`,
`AXON_AGENT_SERVER_HOST`, `AXON_AGENT_SERVER_PORT`, `AXON_AGENT_CLUSTER_NAME`,
`AXON_AGENT_TLS_MODE`, `AXON_AGENT_NTP_HOST`. Os nomes parecidos a estes pero non
exactos ignóranse en silencio. O exemplo 01 documenta
[a mesma trampa nos demais servizos](../01-cassandra-cluster/README.gl.md#variables-de-configuración-que-parecen-correctas-pero-non-o-son).

**Os nodos están healthy pero aparecen como un só rack.** `CASSANDRA_RACK` está
fixado por servizo en `docker-compose.yaml`; se cambia `CASSANDRA_DC` despois do
primeiro arranque, os directorios de datos existentes conservan o valor antigo.
Faga `docker compose down -v` e arranque de novo.

## Soporte

Mantido por [AxonOps](https://axonops.com). Para soporte, contacte connosco en
[axonops.com/contact](https://axonops.com/contact).
