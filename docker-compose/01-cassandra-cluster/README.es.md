# Ejemplo 01 — AxonOps autoalojado monitorizando un clúster de Cassandra de 3 nodos

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Una instalación completa de AxonOps y el clúster de Apache Cassandra que
monitoriza, en un único proyecto de Docker Compose. Todas las imágenes vienen de
este repositorio o del registro público de AxonOps. Empiece aquí si está
evaluando AxonOps.

- ¿Ya ejecuta Cassandra o Kafka y sólo necesita un sitio al que reporten los
  agentes? [Ejemplo 00](../00-axonops-platform/): la plataforma por sí sola.
- ¿Tiene una cuenta de AxonOps Cloud? [Ejemplo 02](../02-saas-cassandra-cluster/):
  el mismo clúster, sin plataforma que ejecutar.

## Inicio rápido

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose ps            # wait for all services to report healthy
```

Después abra <http://localhost:3000>, elija su organización y luego el clúster
`demo-cluster`.

Un arranque en frío tarda de 5 a 10 minutos: primero se inicializan los almacenes
de datos de AxonOps, y después los nodos de Cassandra arrancan de uno en uno.

## Qué ejecuta

| Servicio | Imagen | Propósito | Puerto publicado |
|---------|-------|---------|----------------|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Almacén de métricas (Cassandra) | — |
| `axondb-search` | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Almacén de registros y eventos (OpenSearch) | — |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35` | Backend de AxonOps y endpoint de los agentes | `1888` |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash:2.0.37` | Panel web | `3000` |
| `cassandra-0` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Clúster monitorizado, nodo seed | `9042` |
| `cassandra-1` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Clúster monitorizado, rack1 | — |
| `cassandra-2` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Clúster monitorizado, rack2 | — |

De `cassandra-0` a `cassandra-2` forman un único datacenter, `dc1`, con un rack
cada uno. Sólo `cassandra-0` publica CQL al host; los otros dos son accesibles
dentro de la red de Compose y con `docker exec`.

Las etiquetas y digests actuales de cada imagen: [VERSIONS.md](../../VERSIONS.md).

## Configuración

Todo se define en `.env`. Lista completa con los valores por defecto:
[`env.example`](env.example).

| Variable | Valor por defecto | Descripción |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Nombre de la organización. Compartido por `axon-server` y los agentes: deben coincidir. |
| `CASSANDRA_CLUSTER_NAME` | `demo-cluster` | Nombre del clúster monitorizado en AxonOps |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Imagen de los nodos monitorizados |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap por nodo monitorizado |
| `CASSANDRA_HEAP_NEWSIZE` | `256M` | Generación joven por nodo monitorizado |
| `AXONOPS_LICENSE_KEY` | (vacío) | Clave de licencia; vacío ejecuta en modo de prueba |
| `AXONOPS_DB_PASSWORD` | `axonops` | Contraseña de `axondb-timeseries` |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Contraseña de administración de `axondb-search` |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `2G` | Heap de `axondb-timeseries` |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `2g` | Heap de `axondb-search` |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS de `axon-server` a `axondb-timeseries`: déjelo desactivado salvo que monte un keystore, véase [más abajo](#variables-de-configuración-que-parecen-correctas-pero-no-lo-son) |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS de `axon-server` a `axondb-search` |

`axon-server` se configura por completo mediante variables de entorno: no hay
ningún fichero de configuración que montar ni renderizar. Cada variable
sobrescribe el campo correspondiente del `axon-server.yml` incluido en la imagen:

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

axon-server enlaza 72 variables en total, que cubren la política de reintentos y
reconexión, los niveles de consistencia, las ventanas de compactación, la
autenticación LDAP y SMTP. Todo lo que no se defina conserva el valor del propio
`axon-server.yml` de la imagen.

Las antiguas variables `ELASTIC_*` son la generación anterior de las
`SEARCH_DB_*`: no mezcle las dos formas.

Los agentes se conectan a `axon-server:1888` en texto plano
(`AXON_AGENT_TLS_MODE=disabled`) porque el tráfico nunca sale de la red de
Compose. Use TLS para agentes en cualquier otro host.

### Salud de los nodos monitorizados

Los nodos de Cassandra usan la comprobación de salud que trae la imagen,
`/usr/local/bin/axonops-healthcheck.sh`, en lugar de una escrita aquí. Verifica
dos cosas: que Cassandra está sirviendo CQL, y que el proceso `axon-agent` está
en ejecución; un nodo cuyo agente ha muerto sigue respondiendo consultas pero ha
desaparecido en silencio de AxonOps, y una comprobación que sólo mire a Cassandra
lo dará por sano.

Un agente caído se refleja en la salida de la comprobación, pero por sí solo no
vuelve unhealthy el contenedor, porque hacer fallar la comprobación puede llevar
a un orquestador a reiniciar o vaciar un nodo que sigue sirviendo. Ponga
`HEALTHCHECK_REQUIRE_AGENT=true` en un nodo para tratarlo como un fallo:

```bash
docker compose exec cassandra-0 /usr/local/bin/axonops-healthcheck.sh
```

El agente sólo arranca una vez Cassandra está levantada, así que normalmente está
ausente durante parte del periodo de arranque de 90 s.

Tanto la comprobación del agente como `HEALTHCHECK_REQUIRE_AGENT` están en la
imagen fijada, `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`. En
cualquier imagen anterior el script verifica sólo Cassandra y la variable no
tiene efecto.

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
docker compose ps                       # health of every service
docker compose logs -f axon-server      # follow one service
docker compose logs -f cassandra-0
docker compose exec cassandra-0 tail -f /var/log/axonops/axon-agent.log
docker compose down                     # stop, keep data
docker compose down -v                  # stop and delete all volumes
```

## Requisitos

- Docker Engine 20.10+ y Compose V2
- 10 GB de RAM libres con los valores por defecto de arriba, 20 GB de disco
- Puertos 3000, 1888 y 9042 libres en el host

Baje `CASSANDRA_HEAP_SIZE`, `AXONOPS_CASSANDRA_HEAP_SIZE` y
`AXONOPS_OPENSEARCH_HEAP_SIZE` si tiene menos memoria. Esta es una pila de
desarrollo y evaluación; el dimensionado de producción está en la documentación
de la pila del [ejemplo 00](../00-axonops-platform/README.es.md#requisitos).

## Resolución de problemas

**Un nodo de Cassandra nunca llega a estar healthy.** Los nodos arrancan de uno
en uno y `start_period` es de 90 s. Obsérvelo con
`docker compose logs -f cassandra-1`. La falta de memoria es la causa habitual:
baje `CASSANDRA_HEAP_SIZE`.

**El clúster no aparece en el panel.** El agente y `axon-server` deben compartir
organización. `AXONOPS_ORG_NAME` en `.env` define ambos; compruébelo con
`docker compose exec cassandra-0 env | grep AXON_AGENT_ORG`.

**`axon-server` se reinicia.** Necesita los dos almacenes de datos healthy.
Revise `docker compose logs axondb-timeseries axondb-search`, y confirme que
`AXONOPS_DB_PASSWORD` y `AXONOPS_SEARCH_PASSWORD` coinciden entre ellos y
`axon-server`.

### Variables de configuración que parecen correctas pero no lo son

Tres de los servicios admiten configuración bajo nombres distintos de los que
sugieren sus READMEs. Cada uno de estos casos se dio al levantar este ejemplo, y
cada uno falla de una forma que no nombra la variable culpable.

**`axondb-search` termina con un fallo de bootstrap check.**

```
ERROR: [1] bootstrap checks failed
[1]: the default discovery settings are unsuitable for production use;
     at least one of [discovery.seed_hosts, discovery.seed_providers,
     cluster.initial_cluster_manager_nodes] must be configured
```

`OPENSEARCH_DISCOVERY_TYPE` estaba documentada y se imprimía en el banner de
arranque del contenedor, pero las builds anteriores a `3.7.0-1.6.1` nunca la
escribían en `opensearch.yml`. Funciona a partir de `3.7.0-1.6.1`. Este ejemplo
sigue pasando además el `discovery.type=single-node` propio de OpenSearch, que el
proceso lee directamente, así que el fichero sigue funcionando contra una imagen
más antigua; quite esa línea cuando esté en `3.7.0-1.6.1` o posterior en todas
partes.

**Cassandra registra `Invalid or unsupported protocol version (22)` y
`axon-server` registra `tls: first record does not look like a TLS handshake`.**

22 es `0x16`, el primer byte de un ClientHello de TLS leído como una versión de
protocolo CQL: un lado está usando TLS y el otro no. `axondb-timeseries` sólo
activa las `client_encryption_options` cuando hay un keystore montado en
`CASSANDRA_KEYSTORE_PATH`; no hay ninguna variable que lo active por sí sola, y
`CASSANDRA_CLIENT_ENCRYPTION_ENABLED` no hace nada. Así que el transporte nativo
va en texto plano y `CQL_SSL` debe estar a `false` para hacer lo mismo. Para usar
TLS, monte un keystore y configure los dos lados a la vez.

**`axon-dash` entra en bucle de caída con `findHost | no reachable endpoints` y
`ECONNREFUSED 127.0.0.1:8080`.**

`axon-dash` mapea su `axon-dash.yml` sobre variables de entorno por sección y
clave: `axon-server.private_endpoints` se convierte en
`AXONSERVER_PRIVATE_ENDPOINTS`, y `axon-dash.port` en `AXONDASH_PORT`. Acepta
además cualquier cosa con el prefijo `AXON_SERVER_`, la pasa a minúsculas y la
funde en la sección `axon-server`, lo que significa que un nombre equivocado como
`AXON_SERVER_URL` se acepta en silencio y aparece en la configuración que el dash
imprime al arrancar sin tener ningún efecto. La dirección que el dash marca
realmente es `private_endpoints`; compruébela en ese bloque de configuración
impreso.

## Soporte

Mantenido por [AxonOps](https://axonops.com). Para soporte, contacte con nosotros en
[axonops.com/contact](https://axonops.com/contact).
