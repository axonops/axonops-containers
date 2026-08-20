# Ejemplo 03 — Un clúster asegurado de 3 racks, monitorizado por AxonOps

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Un clúster de Cassandra de tres nodos con la autenticación activada, JMX remoto
abierto, un rack por nodo y una dirección fija para cada contenedor; y luego la
plataforma AxonOps completa monitorizándolo.

Es un port de una pila comunitaria muy difundida,
[crystalloide/cassandra-reaper](https://github.com/crystalloide/cassandra-reaper)
(«Cluster 3 noeuds 3 racks 1 DC Prometheus Grafana Reaper sécurisé»). El clúster
se mantiene tal cual estaba; Prometheus, Grafana, los tres sidecars
`cassandra_exporter` y Reaper se sustituyen por AxonOps, que cubre métricas,
registros, alertas y planificación de reparaciones en un mismo sitio.
[Qué cambió](#qué-cambió-respecto-de-la-pila-original) enumera todas las
diferencias.

- ¿Quiere lo mismo sin los ajustes de seguridad ni el direccionamiento estático?
  [Ejemplo 01](../01-cassandra-cluster/): la pila autoalojada más sencilla.
- ¿Tiene una cuenta de AxonOps Cloud? [Ejemplo 02](../02-saas-cassandra-cluster/):
  un clúster que reporta a SaaS, sin plataforma que ejecutar.

## Antes de empezar

Los tres nodos están fijados a la etiqueta de versión completa
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`, no a la flotante
`5.0.8`. Aquí eso importa más que en los demás ejemplos.

La autenticación se define con `CASSANDRA_AUTHENTICATOR` y
`CASSANDRA_AUTHORIZER`, que el entrypoint de la imagen aplica a
`cassandra.yaml`. **Las imágenes publicadas antes de la build 1.1.0 ignoran ambas
variables**: el clúster arranca, se une y aparece en AxonOps exactamente como
debe, y acepta cualquier conexión sin contraseña. Nada en los registros lo
señala.

Así que, si cambia `CASSANDRA_IMAGE`, manténgalo en 1.1.0 o posterior, y
compruebe qué obtuvo realmente una vez la pila esté levantada:

```bash
for n in cassandra01 cassandra02 cassandra03; do
  printf '%s: ' "$n"
  docker exec "$n" grep '^authenticator:' /opt/cassandra/conf/cassandra.yaml
done
# authenticator: PasswordAuthenticator   <- secured
# authenticator: AllowAllAuthenticator   <- image too old, see above
```

Compruebe todos los nodos, no sólo el primero. Un único nodo que se quede con una
imagen que ignora `CASSANDRA_AUTHENTICATOR` se une al clúster y acepta conexiones
sin autenticar en su propio puerto CQL: el clúster sólo está tan asegurado como
su nodo menos asegurado.

## Inicio rápido

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
./setup.sh                   # create and seed ./docker/, once
docker compose up -d
docker compose ps            # wait for all seven services to report healthy
```

`setup.sh` no es opcional: los tres nodos leen su configuración de directorios
del host bajo [`./docker/`](#almacenamiento), y Cassandra no arranca contra uno
vacío.

Después abra <http://localhost:3000>.

Un arranque en frío tarda de 6 a 10 minutos. Primero se inicializan los dos
almacenes de datos de AxonOps, después `axon-server` y el panel, y sólo entonces
el clúster: de un nodo en un nodo, porque Cassandra arranca un solo nodo cada
vez.

Una vez el clúster esté levantado, haga los
[dos pasos de seguridad posteriores al arranque](#terminar-de-asegurar-el-clúster).
Cassandra viene con un superusuario por defecto de sobra conocido y con un
keyspace `system_auth` que no sobrevive a la pérdida de un nodo.

## Qué ejecuta

| Servicio | Dirección | Imagen | Propósito | Puerto publicado |
|---------|---------|-------|---------|----------------|
| `cassandra01` | 10.17.64.5 | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Nodo del clúster, rack1 | `9142` CQL, `7199` JMX¹ |
| `cassandra02` | 10.17.64.6 | la misma | Nodo del clúster, rack2 | `9242` CQL, `7299` JMX¹ |
| `cassandra03` | 10.17.64.7 | la misma | Nodo del clúster, rack3 | `9342` CQL, `7399` JMX¹ |
| `axondb-timeseries` | 10.17.64.20 | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Almacén de métricas (Cassandra de un solo nodo) | — |
| `axondb-search` | 10.17.64.21 | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Almacén de registros y eventos (OpenSearch) | — |
| `axon-server` | 10.17.64.22 | `axon-server:2.0.35` | Backend y endpoint de los agentes | `1888` |
| `axon-dash` | 10.17.64.23 | `axon-dash:2.0.37` | Panel web | `3000` |

¹ Ligados únicamente a `127.0.0.1`: véase [JMX remoto](#jmx-remoto).

Las etiquetas y digests actuales de cada imagen: [VERSIONS.md](../../VERSIONS.md).

## El clúster

| | |
|---|---|
| Topología | 1 datacenter, 3 racks, un nodo por rack |
| Snitch | `GossipingPropertyFileSnitch` |
| Direccionamiento | Estático, en la red bridge `10.17.64.0/24` |
| Seeds | Los tres nodos |
| Tokens | 16 por nodo |
| Autenticación | `PasswordAuthenticator` |
| Autorización | `CassandraAuthorizer` |
| JMX | Remoto, sin autenticar, publicado sólo en localhost |
| Recolector de basura | ZGC, en lugar del G1 por defecto de Cassandra 5.0 |

**Por qué direcciones estáticas.** JMX remoto necesita que
`java.rmi.server.hostname` apunte a una dirección que un cliente pueda alcanzar
de verdad, y el stub RMI que devuelve un nodo lleva esa dirección. Una dirección
de Docker asignada por DHCP cambia al recrear el contenedor, y el valor grabado
en `JVM_EXTRA_OPTS` apuntaría entonces a otro sitio. Por eso la subred está fija
en `docker-compose.yaml` y no es una variable: cambiarla significa cambiar a la
vez las siete entradas `ipv4_address`, `CASSANDRA_SEEDS`,
`CASSANDRA_LISTEN_ADDRESS`, `CASSANDRA_BROADCAST_RPC_ADDRESS` y
`java.rmi.server.hostname`.

**Por qué los tres nodos son seeds.** Heredado de la pila original. Está bien
para un clúster creado desde cero, que es lo que es este: los seeds se saltan el
streaming de bootstrap, y no hay nada que transmitir. Para un clúster que vaya a
hacer crecer después, haga que los nodos nuevos no sean seeds, para que arranquen
correctamente.

## Almacenamiento

Los tres nodos del clúster guardan tanto sus datos como su configuración en
directorios del host, no en volúmenes gestionados por Docker:

```
docker/cassandra01        ->  /var/lib/cassandra    data, plain bind mount
docker/cassandra01-conf   ->  /opt/cassandra/conf   configuration, a named
                                                    volume bound to the path
```

…y lo mismo para `cassandra02` y `cassandra03`. Los servicios de la plataforma
AxonOps usan volúmenes con nombre normales.

Ambas rutas se escriben como `${PWD}/docker/…`, como en la pila original, así que
**ejecute `docker compose` desde este directorio**. Lanzarlo desde otro sitio con
`-f docker-compose/03-secure-3-rack-cluster/docker-compose.yaml` resuelve `${PWD}`
a donde usted esté y monta los directorios equivocados.

**Esto es deliberado, y no es lo que escribiría desde cero.** Reproduce un
entorno de cliente, donde la configuración tiene que ser editable en el host e
inspeccionable después de que el contenedor haya desaparecido. Los costes son
reales: los directorios no son portables entre máquinas, `docker compose down -v`
no los limpia, y en Linux su propiedad debe coincidir con la del usuario
`cassandra` de la imagen (uid 999) o Cassandra no podrá escribir. `setup.sh` se
encarga de la propiedad y le avisa cuando no ha podido.

### setup.sh

```bash
./setup.sh              # create anything missing, seed configuration from the image
./setup.sh --force      # re-seed the configuration directories, discarding edits
./setup.sh --help
```

Puebla cada directorio `-conf` a partir de `/opt/cassandra/conf` **dentro de la
imagen que está a punto de ejecutar**, así que la configuración siempre coincide
con esa versión de Cassandra. Lee `CASSANDRA_IMAGE` de `.env` si define una allí.

Los directorios existentes se dejan en paz. Ejecútelo tantas veces como quiera;
sólo `--force` sobrescribe, y sólo la configuración.

**Qué hace realmente**, en orden:

1. **Analiza los argumentos**: `-f`/`--force` y `-h`/`--help`. Cualquier otra
   cosa es un error. `--help` imprime el comentario de cabecera del propio
   script.
2. **Comprueba Docker**: que `docker` esté en el `PATH` y que el daemon sea
   alcanzable. Sale antes de tocar el sistema de ficheros si falla cualquiera de
   las dos cosas.
3. **Resuelve la imagen.** Busca con grep `CASSANDRA_IMAGE=` en `./.env` (gana la
   última aparición, quitando las comillas circundantes) y recurre al valor por
   defecto compilado en el script,
   `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`, que debe coincidir
   con el valor por defecto de `docker-compose.yaml`. No analiza el fichero de
   Compose.
4. **Descarga la imagen si no está presente en local**, para que el paso de
   poblado siguiente no pueda fallar por una imagen ausente.
5. **Para cada uno de `cassandra01`, `cassandra02` y `cassandra03`:**
   - Crea `docker/<node>/` (el directorio de datos) si no existe, y lo dice. Uno
     ya existente no se toca nunca: sus datos están a salvo.
   - Puebla `docker/<node>-conf/` salvo que ya contenga un `cassandra.yaml` y no
     se haya pasado `--force`. Poblarlo es `docker create` sobre la imagen (un
     contenedor que nunca se arranca), `docker cp <container>:/opt/cassandra/conf/.`
     al directorio, y luego `docker rm -f`. El directorio se borra y se vuelve a
     crear primero, así que `--force` **descarta todas las ediciones locales que
     haya en él**.
   - Intenta un `chown -R 999:999` sobre ambos directorios: el uid/gid del
     usuario `cassandra` de la imagen.
6. **Imprime qué hacer a continuación** (`cp env.example .env`,
   `docker compose up -d`).

El `chown` es de mejor esfuerzo. En Docker Desktop (macOS, Windows) falla y eso
es lo esperado: la capa de compartición de ficheros mapea la propiedad por usted.
En Linux un fallo es real, y el script avisa con el comando exacto
`sudo chown -R 999:999 docker/` que hay que ejecutar. Todo lo demás es fatal: el
script es `set -euo pipefail`, así que un daemon inalcanzable, una imagen que no
se puede descargar o un `docker cp` fallido lo detienen con una línea `error:` en
lugar de dejar atrás un directorio a medio poblar.

Nunca escribe `.env`, nunca edita `docker-compose.yaml` y nunca arranca un
contenedor.

### Editar la configuración

Todo lo que las variables de entorno no cubran, edítelo directamente en el host y
reinicie el nodo:

```bash
$EDITOR docker/cassandra01-conf/cassandra.yaml
docker compose restart cassandra01
```

Dos cosas que conviene saber antes de hacerlo:

- **Las variables de entorno ganan.** En cada arranque, el entrypoint reescribe
  `cluster_name`, `authenticator`, `authorizer`, `listen_address`,
  `broadcast_rpc_address`, los seeds, `endpoint_snitch`, `num_tokens`,
  `native_transport_port`, y `dc`/`rack` en `cassandra-rackdc.properties`, a
  partir de los valores de `docker-compose.yaml`. Editar esas claves en el host
  no tiene efecto. Todo lo demás que edite se conserva.
- **`cassandra-env.sh` gana una línea.** El entrypoint añade
  `. /usr/share/axonops/axonops-jvm.options` para que se cargue el agente Java de
  AxonOps. Lo comprueba antes, así que un reinicio no la añade dos veces.

### Mantenerlo fuera de git

`docker/` está en el gitignore. Cassandra reescribe partes de la configuración en
tiempo de ejecución, así que subirla produce ruido constante, y los directorios
de datos son grandes. Si quiere la configuración de un cliente en el control de
versiones, suba los ficheros concretos de forma deliberada con `git add -f`.

## Terminar de asegurar el clúster

Dos cosas que Cassandra no puede hacer por usted. Haga ambas una vez los tres
nodos estén levantados (`docker compose ps` los muestra todos healthy).

**1. Replicación de `system_auth`.** Se crea con `SimpleStrategy` y factor de
replicación 1, así que la caída de un solo nodo se lleva por delante los inicios
de sesión. Súbalo a una réplica por rack:

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra -e \
  "ALTER KEYSPACE system_auth WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 3}"

docker exec cassandra01 nodetool repair -full system_auth
docker exec cassandra02 nodetool repair -full system_auth
docker exec cassandra03 nodetool repair -full system_auth
```

Use su propio valor si cambió `CASSANDRA_DC`.

**2. El superusuario por defecto.** Cassandra crea `cassandra` / `cassandra` en
el primer arranque con la autenticación activada. Es de dominio público.
Sustitúyalo:

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra
```

```sql
CREATE ROLE admin WITH PASSWORD = 'a-password-you-choose'
  AND SUPERUSER = true AND LOGIN = true;
```

Vuelva a conectarse como `admin` y deje la cuenta por defecto fuera de uso:

```sql
ALTER ROLE cassandra WITH PASSWORD = 'a-long-random-string-nobody-keeps'
  AND SUPERUSER = false;
```

El agente de AxonOps no necesita ninguna de estas credenciales. Recopila a través
del agente Java en proceso y de JMX, no de CQL, así que la autenticación del
clúster no afecta a la monitorización.

## JMX remoto

`LOCAL_JMX=no` abre JMX a la red, que es lo que hacía la pila original para que
Reaper pudiera lanzar reparaciones. AxonOps no lo necesita —el agente se ejecuta
dentro del contenedor—, así que está aquí sólo para herramientas externas como
`jmxterm`, `nodetool` desde otro host o un profiler de la JVM.

`cassandra-env.sh` activa la autenticación de JMX siempre que `LOCAL_JMX=no`, y
eso necesita un fichero `jmxremote.password` que esta imagen no incluye, así que
`JVM_EXTRA_OPTS` define
`-Dcom.sun.management.jmxremote.authenticate=false`. Funciona porque
`JVM_EXTRA_OPTS` se añade el último y gana el último `-D` de una propiedad de
sistema repetida.

El resultado es un **puerto JMX sin autenticar con control total sobre el nodo**:
JMX puede cambiar el esquema, drenar y decomisionar. Los puertos se publican sólo
a `127.0.0.1`, así que nada de fuera del host puede alcanzarlos:

```yaml
ports:
  - "127.0.0.1:7199:7199"
```

No quite el prefijo `127.0.0.1:`. Si necesita JMX remoto de verdad, configure
antes
[la autenticación de JMX](https://cassandra.apache.org/doc/stable/cassandra/operating/security.html#jmx-access)
con un fichero de contraseñas y TLS. Para quitar JMX remoto por completo, elimine
`LOCAL_JMX=no`, los dos flags `-D` y las líneas de puertos JMX; todo lo demás de
este ejemplo sigue funcionando.

## Configuración

Todo se define en `.env`. Lista completa con los valores por defecto:
[`env.example`](env.example).

| Variable | Valor por defecto | Descripción |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Nombre de la organización; los agentes usan el mismo valor |
| `AXONOPS_LICENSE_KEY` | (vacío) | Clave de licencia; vacío ejecuta en modo de prueba |
| `AXONOPS_DB_PASSWORD` | `axonops` | Contraseña de `axondb-timeseries` |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Contraseña de administración de `axondb-search` |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `2G` | Heap de `axondb-timeseries` |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `2g` | Heap de `axondb-search` |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS de `axon-server` a `axondb-search` |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS de `axon-server` a `axondb-timeseries` |
| `CASSANDRA_CLUSTER_NAME` | `secure-cluster` | Nombre del clúster mostrado en AxonOps |
| `CASSANDRA_DC` | `dc1` | Nombre del datacenter |
| `CASSANDRA_IMAGE` | `…/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Imagen de los tres nodos: 1.1.0 o posterior, véase [Antes de empezar](#antes-de-empezar) |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap por nodo del clúster |
| `CASSANDRA_MEM_LIMIT` | `2g` | Límite de memoria del contenedor por nodo |
| `CASSANDRA_CPUS` | `2.0` | Límite de CPU por nodo |

Los nombres de rack, las direcciones y la subred están fijados en
`docker-compose.yaml` porque dependen unos de otros; véase
[El clúster](#el-clúster).

`axon-server` se configura por completo mediante variables de entorno: no hay
ningún fichero de configuración que montar ni renderizar. La correspondencia
completa está en
[el ejemplo 01](../01-cassandra-cluster/README.es.md#configuración).

## Operación

```bash
docker compose ps                          # health of every service
docker compose logs -f cassandra01         # follow one node
docker exec cassandra01 nodetool status    # cluster view, racks and ownership
docker compose down                        # stop, keep data
docker compose down -v                     # stop and delete all volumes
```

Conéctese con CQL desde el host: cada nodo publica su propio puerto.

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra
cqlsh 127.0.0.1 9142 -u cassandra -p cassandra    # if you have cqlsh locally
```

`nodetool status` debería mostrar tres nodos `UN`, uno por rack. Si falta un
rack, ese nodo no leyó `cassandra-rackdc.properties` como se esperaba: revise
`CASSANDRA_DC` y `CASSANDRA_RACK` en su entorno.

### Salud de los nodos del clúster

Los tres nodos usan la comprobación de salud que trae la imagen,
`/usr/local/bin/axonops-healthcheck.sh`, en lugar de una escrita aquí. Verifica
que Cassandra está sirviendo CQL y que el proceso `axon-agent` está en ejecución;
un nodo cuyo agente ha muerto sigue respondiendo consultas pero ha dejado de
estar monitorizado en silencio.

**Qué hace realmente.** Dos comprobaciones independientes, una línea de salida
cada una y un único código de salida:

1. **Cassandra.** `nodetool statusbinary` debe imprimir `running`, y el puerto
   CQL debe estar escuchando (`ss -ln`). El puerto se lee del
   `native_transport_port` de `cassandra.yaml`, con `9042` por defecto: así sigue
   el puerto que usted defina en lugar de suponer uno. Que falle cualquiera de
   las dos cosas termina con código distinto de cero, que es lo que vuelve
   unhealthy el contenedor.
   (En las imágenes de K8ssandra, donde está presente la Management API de
   DataStax, se usa en su lugar su endpoint `/api/v0/probes/liveness`, la misma
   sonda en la que se apoya el operador de K8ssandra. Estos tres nodos usan la
   imagen de Cassandra sin más, así que la vía que se ejecuta es la de
   `nodetool`.)
2. **El agente de AxonOps.** Recorre `/proc/<pid>/cmdline` buscando
   `/usr/share/axonops/axon-agent` (se puede cambiar con `AXON_AGENT_BIN`). Lee
   `/proc` directamente en lugar de usar `pgrep`, que no está garantizado que
   exista en la imagen base UBI.

Un agente caído se refleja en la salida de la comprobación, pero por sí solo no
vuelve unhealthy el contenedor, porque hacer fallar la comprobación puede llevar
a un orquestador a reiniciar o vaciar un nodo que sigue sirviendo. Ponga
`HEALTHCHECK_REQUIRE_AGENT=true` en un nodo para tratarlo como un fallo: eso es
lo único que cambia la variable; el agente se comprueba y se reporta en cualquier
caso.

```bash
# Run it by hand — the output names which of the two checks failed
docker exec cassandra01 /usr/local/bin/axonops-healthcheck.sh

# What Docker last saw
docker inspect --format '{{.State.Health.Status}}' cassandra01
docker inspect --format '{{(index .State.Health.Log 0).Output}}' cassandra01
```

Compose la ejecuta cada 15 s con un timeout de 10 s, 20 reintentos y un periodo
de arranque de 120 s. El agente sólo arranca una vez Cassandra está levantada,
así que normalmente está ausente durante parte de ese periodo de arranque, que es
para lo que está. En un nodo lento con `HEALTHCHECK_REQUIRE_AGENT=true`, suba
`start_period` en lugar de bajar `retries`.

Tanto la comprobación del agente como `HEALTHCHECK_REQUIRE_AGENT` están en la
imagen fijada, `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`. En
cualquier imagen anterior el script verifica sólo Cassandra y la variable no
tiene efecto.

Los datos y la configuración del clúster viven bajo `./docker/` en el host:
véase [Almacenamiento](#almacenamiento). `docker compose down -v` elimina los
volúmenes de AxonOps pero deja esos directorios; bórrelos a mano para arrancar el
clúster desde cero.

## Requisitos

- Docker Engine 20.10+ y Compose V2
- 12 GB de RAM libres con los valores por defecto, 16 GB recomendados; 30 GB de
  disco, la mayor parte bajo `./docker/`
- La subred `10.17.64.0/24` libre en el host
- Puertos 3000, 1888, 9142, 9242 y 9342 libres, y 7199, 7299 y 7399 en localhost

Para una máquina más pequeña, baje los heaps en `.env`:

```bash
CASSANDRA_HEAP_SIZE=1G
CASSANDRA_MEM_LIMIT=2g
AXONOPS_CASSANDRA_HEAP_SIZE=2G
AXONOPS_OPENSEARCH_HEAP_SIZE=2g
```

## Qué cambió respecto de la pila original

| Original | Aquí | Por qué |
|----------|------|-----|
| Prometheus, Grafana, 3× `cassandra_exporter`, Reaper | `axondb-timeseries`, `axondb-search`, `axon-server`, `axon-dash` | El sentido del port. Métricas, registros, alertas y planificación de reparaciones en una sola plataforma, y ningún sidecar de exportador JMX que configurar |
| `cassandra:5.0.8` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | La misma Cassandra, con el agente de AxonOps y el agente Java ya instalados |
| Bind mounts bajo `${PWD}/docker/` | Se mantienen | Reproduce el entorno del cliente. `setup.sh` los crea y los puebla: véase [Almacenamiento](#almacenamiento) |
| Volúmenes `conf` montados por bind | Se mantienen | La misma razón. La imagen puede gobernarse enteramente con variables de entorno, pero así la configuración es editable en el host |
| `7000` y `7001` publicados por nodo | No se publican | Son puertos internodo; nada fuera de la red de Compose los usa |
| `7199` JMX publicado en todas las interfaces | Publicado sólo en `127.0.0.1` | El puerto no está autenticado. Véase [JMX remoto](#jmx-remoto) |
| Healthcheck de `cqlsh` con credenciales incrustadas | El propio `axonops-healthcheck.sh` de la imagen | La imagen incluye `cqlai` y `cqlsh`, y la comprobación no necesita credenciales. Verifica además que el `axon-agent` está vivo: véase [Salud de los nodos del clúster](#salud-de-los-nodos-del-clúster) |
| Contraseñas en el YAML | En `.env`, en el gitignore | Nada secreto en un fichero subido |
| `restart: always` | `restart: unless-stopped` | Coincide con los demás ejemplos; un contenedor que usted paró se queda parado |
| `CASSANDRA_OPEN_JMX`, `JMXPORT` | Eliminadas | Ni Cassandra ni la imagen las leen: tampoco hacían nada en el original |

Se mantienen tal cual estaban: la subred y todas las direcciones, la disposición
de clúster y racks, la lista de seeds, `GossipingPropertyFileSnitch`,
`PasswordAuthenticator`, `CassandraAuthorizer`, `LOCAL_JMX=no`, los flags de ZGC,
los ulimits `memlock` y `nofile`, la disposición de almacenamiento en `./docker/`
para datos y configuración, y los números de puerto CQL publicados.

## Resolución de problemas

**`authenticator: AllowAllAuthenticator` después de arrancar.**
`CASSANDRA_IMAGE` apunta a una imagen anterior a la build 1.1.0, previa al
soporte del entrypoint para `CASSANDRA_AUTHENTICATOR`. Véase
[Antes de empezar](#antes-de-empezar).

**`Provided username cassandra and/or password are incorrect` justo después de
que el clúster arranque.** El superusuario por defecto se crea unos segundos
después de que el primer nodo termine de arrancar, no durante el arranque.
Espere a `Created default superuser role 'cassandra'` y reinténtelo:

```bash
docker compose logs cassandra01 | grep "default superuser"
```

**`Expecting URI in variable: [cassandra.config]. Found[cassandra.yaml]`, con
`sed: can't read /opt/cassandra/conf/cassandra.yaml` encima.** El nodo tiene un
directorio de configuración vacío. O bien nunca se ejecutó `setup.sh`, o bien el
bind mount no se resuelve al directorio que usted cree. Compruebe qué ve
realmente el contenedor:

```bash
docker run --rm -v "$PWD/docker/cassandra01-conf:/x" busybox ls /x | wc -l
```

Cero significa que Docker creó un directorio vacío en lugar de compartir el suyo:
en Docker Desktop, una ruta fuera de la lista de compartición de ficheros
configurada hace exactamente eso. Mueva el proyecto a una ruta compartida, o
añada la ruta en Docker Desktop en Settings → Resources → File sharing.

**`Permission denied` al escribir en el directorio de configuración o de datos
(Linux).** Los directorios deben ser escribibles por el uid 999, el usuario
`cassandra` de la imagen:

```bash
sudo chown -R 999:999 docker/
```

`setup.sh` lo intenta y avisa cuando no puede. Docker Desktop en macOS y Windows
mapea la propiedad por usted, así que esto sólo afecta a los hosts Linux.

**Un nodo nunca llega a estar healthy.** Los nodos arrancan en secuencia, así que
un arranque en frío tarda varios minutos. Observe
`docker compose logs -f cassandra02`. Si se queda atascado en el gossip, confirme
que las direcciones de los seeds coinciden con las entradas `ipv4_address`.

**`Cannot assign requested address` o un conflicto de subred en el `up`.** Algo
más en el host usa `10.17.64.0/24`, a menudo otra red de Docker. Compruébelo con
`docker network ls` e `ip route`, y luego elimine la red en conflicto o edite la
subred y las siete direcciones a la vez.

**`nodetool status` muestra menos de tres nodos.** Compruebe que el nodo que
falta llegó a arrancar (`docker compose ps`), y luego busque una discrepancia en
el nombre del clúster: un nodo que se unió con un `CASSANDRA_CLUSTER_NAME`
distinto en una ejecución anterior lo conserva en su directorio de datos. Aquí
`docker compose down -v` **no** lo limpia, porque los datos son un bind mount del
host: elimine `docker/cassandra0*/` a mano.

**JMX desde otro host da timeout.** Es lo esperado: los puertos están ligados a
`127.0.0.1`. Véase [JMX remoto](#jmx-remoto).

**Cassandra registra `Invalid or unsupported protocol version (22)` y
`axon-server` registra `tls: first record does not look like a TLS handshake`.**
Un lado está usando TLS y el otro no; 22 es `0x16`, el primer byte de un
ClientHello de TLS leído como una versión de protocolo CQL. Deje
`AXONOPS_CASSANDRA_SSL=false` a menos que haya montado un keystore en
`axondb-timeseries`.

**Otros ajustes que parecen correctos pero se ignoran.** Tres de estas imágenes
admiten configuración bajo nombres distintos de los que sugieren sus propios
READMEs, y cada una falla sin nombrar la variable culpable. El ejemplo 01
documenta las tres:
[variables de configuración que parecen correctas pero no lo son](../01-cassandra-cluster/README.es.md#variables-de-configuración-que-parecen-correctas-pero-no-lo-son).

## Licencias

AxonOps requiere licencia para uso en producción: <https://axonops.com>. La pila
funciona sin clave de licencia en modo de prueba, lo que basta para la
evaluación.

## Soporte

Mantenido por [AxonOps](https://axonops.com). Para soporte, contacte con nosotros en
[axonops.com/contact](https://axonops.com/contact).
