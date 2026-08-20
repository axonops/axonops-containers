# Ejemplo 02 — AxonOps SaaS monitorizando un clúster de Cassandra de 3 nodos

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Un clúster de Apache Cassandra de 3 nodos cuyos agentes reportan a AxonOps SaaS.
No se ejecuta ninguna plataforma AxonOps en local: los únicos contenedores son
los nodos de Cassandra, y el panel es el alojado.

- ¿Prefiere la plataforma entera en su propia máquina?
  [Ejemplo 01](../01-cassandra-cluster/): el mismo clúster, con AxonOps autoalojado.
- ¿Ya ejecuta Cassandra o Kafka en otro sitio?
  [Ejemplo 00](../00-axonops-platform/): la plataforma por sí sola.

## Inicio rápido

```bash
cp env.example .env          # set AXONOPS_ORG_NAME and AXONOPS_AGENT_KEY
docker compose up -d
docker compose ps            # wait for all three nodes to report healthy
```

Después abra <https://console.axonops.cloud> y elija el clúster
`saas-demo-cluster`. Los nodos van apareciendo según arrancan; un arranque en
frío tarda de 3 a 5 minutos porque arrancan de uno en uno.

El nombre de su organización y la clave de agente vienen ambos de su cuenta de
AxonOps Cloud: dese de alta en <https://axonops.cloud>, y consulte
[la configuración del agente](https://axonops.com/docs/get_started/agent_setup/)
para ver dónde se muestra la clave. Los agentes no arrancarán sin ellos: Compose
falla de inmediato con `set AXONOPS_AGENT_KEY in .env` en lugar de arrancar un
clúster que no reporta a ninguna parte.

## Qué ejecuta

| Servicio | Imagen | Propósito | Puerto publicado |
|---------|-------|---------|----------------|
| `cassandra-0` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Nodo seed, `rack0` | `9042` |
| `cassandra-1` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | `rack1` | — |
| `cassandra-2` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | `rack2` | — |

Un único datacenter, `dc1`, con un rack por nodo. Sólo `cassandra-0` publica CQL
al host; los demás son accesibles dentro de la red de Compose y a través de
`docker exec`.

Las etiquetas y digests actuales de cada imagen: [VERSIONS.md](../../VERSIONS.md).

## Qué cambia con SaaS

Hay tres diferencias que importan al ejecutar esto en lugar del
[ejemplo 01](../01-cassandra-cluster/); la comparación completa está en el
[índice](../README.es.md#cuál-quiero).

- **Credenciales.** SaaS necesita una clave de agente además del nombre de la
  organización. Ambas son obligatorias: Compose se niega a arrancar sin ellas.
- **TLS está activado.** Los agentes usan por defecto `AXON_AGENT_TLS_MODE=TLS`
  con verificación de certificado; el ejemplo 01 desactiva TLS porque ese tráfico
  nunca sale de la red de Compose, lo que aquí no es cierto.
- **Sus métricas salen del host.** Se almacenan en AxonOps SaaS en lugar de en un
  `axondb-timeseries` local, y el panel es el alojado.

## Configuración

Todo se define en `.env`. Lista completa con los valores por defecto:
[`env.example`](env.example).

| Variable | Valor por defecto | Descripción |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | — | Organización de AxonOps. Obligatoria. |
| `AXONOPS_AGENT_KEY` | — | Clave de agente de la consola. Obligatoria. |
| `CASSANDRA_CLUSTER_NAME` | `saas-demo-cluster` | Nombre del clúster mostrado en AxonOps |
| `CASSANDRA_DC` | `dc1` | Nombre del datacenter |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Imagen de los nodos |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap por nodo |
| `CASSANDRA_HEAP_NEWSIZE` | `256M` | Generación joven por nodo |
| `CQL_PORT` | `9042` | Puerto del host para CQL en `cassandra-0` |
| `AXONOPS_SERVER_HOST` | `agents.axonops.cloud` | Endpoint de los agentes |
| `AXONOPS_SERVER_PORT` | `443` | Puerto del endpoint de los agentes |
| `AXONOPS_NTP_HOST` | `time.google.com` | Host NTP para la comprobación de desviación del reloj del agente |

La clave de agente es una credencial. `.env` está en el gitignore: no la suba, y
no la incruste en una imagen.

### Requisitos de red

Los agentes hacen conexiones TLS **salientes** a `agents.axonops.cloud:443`. No
se necesita nada entrante. Tras un proxy de salida o un cortafuegos, permita ese
host y ese puerto; no hay repliegue a texto plano.

Compruebe que un agente está conectado:

```bash
docker compose exec cassandra-0 tail -f /var/log/axonops/axon-agent.log
```

Un agente sano registra una conexión correcta. `Unable to connect to axonops
services` significa que el endpoint es inalcanzable o que la clave es incorrecta.

### Salud de los nodos

Los nodos usan la comprobación de salud que trae la imagen,
`/usr/local/bin/axonops-healthcheck.sh`, en lugar de una escrita aquí. Verifica
tanto que Cassandra está sirviendo CQL como que el proceso `axon-agent` está en
ejecución, lo que aquí importa más que en los ejemplos autoalojados, porque un
nodo cuyo agente ha muerto no reporta nada a SaaS aunque siga respondiendo
consultas.

Un agente caído se refleja en la salida de la comprobación, pero por sí solo no
vuelve unhealthy el contenedor; hacer fallar la comprobación puede llevar a un
orquestador a reiniciar o vaciar un nodo que sigue sirviendo. Ponga
`HEALTHCHECK_REQUIRE_AGENT=true` para tratarlo como un fallo:

```bash
docker compose exec cassandra-0 /usr/local/bin/axonops-healthcheck.sh
```

El agente sólo arranca una vez Cassandra está levantada, así que normalmente está
ausente durante parte del periodo de arranque de 90 s.

La comprobación del agente llegó a `axonops-healthcheck.sh` después de publicarse
la imagen fijada actualmente, así que en
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` el script verifica sólo
Cassandra y `HEALTHCHECK_REQUIRE_AGENT` no tiene efecto. Ambos entran en vigor
con la siguiente release de la imagen de Cassandra.

## Usar el clúster

```bash
# CQL from the host
cqlsh 127.0.0.1 9042

# CQL from inside a node, using the bundled cqlai client
docker compose exec cassandra-0 cqlai -e "SELECT release_version FROM system.local;"

# Ring status
docker compose exec cassandra-0 nodetool status
```

Escriba algunos datos para que el panel tenga algo que mostrar:

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

- Docker Engine 20.10+ y Compose V2
- 5 GB de RAM libres con los valores por defecto de arriba, 10 GB de disco
- Puerto 9042 libre en el host, o defina `CQL_PORT`
- HTTPS saliente hacia `agents.axonops.cloud`
- Una organización de AxonOps SaaS y una clave de agente

## Resolución de problemas

**Compose se niega a arrancar con `set AXONOPS_AGENT_KEY in .env`.** Ese es el
comportamiento previsto: tanto `AXONOPS_ORG_NAME` como `AXONOPS_AGENT_KEY` son
obligatorias, y un clúster sin clave no reportaría a nada.

**El clúster nunca aparece en la consola.** Revise la línea de conexión en el
registro del agente. Las causas habituales son una clave de otra organización,
filtrado de salida en el puerto 443, o un reloj desviado más de unos pocos
segundos: en ese caso el agente registra un aviso de NTP.

**Un nodo nunca llega a estar healthy.** Los nodos arrancan de uno en uno y
`start_period` es de 90 s. Observe `docker compose logs -f cassandra-1`. La falta
de memoria es la causa habitual: baje `CASSANDRA_HEAP_SIZE`.

**Una variable parece ignorarse.** El agente lee los nombres `AXON_AGENT_*`
enlazados en su propio paquete de configuración: `AXON_AGENT_ORG`,
`AXON_AGENT_KEY`, `AXON_AGENT_SERVER_HOST`, `AXON_AGENT_SERVER_PORT`,
`AXON_AGENT_CLUSTER_NAME`, `AXON_AGENT_TLS_MODE`, `AXON_AGENT_NTP_HOST`. Los
nombres parecidos a estos pero no exactos se ignoran en silencio. El ejemplo 01
documenta
[la misma trampa en los demás servicios](../01-cassandra-cluster/README.es.md#variables-de-configuración-que-parecen-correctas-pero-no-lo-son).

**Los nodos están healthy pero aparecen como un solo rack.** `CASSANDRA_RACK`
está fijado por servicio en `docker-compose.yaml`; si cambia `CASSANDRA_DC`
después del primer arranque, los directorios de datos existentes conservan el
valor antiguo. Haga `docker compose down -v` y arranque de nuevo.

## Soporte

Mantenido por [AxonOps](https://axonops.com). Para soporte, contacte con nosotros en
[axonops.com/contact](https://axonops.com/contact).
