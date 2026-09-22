# Ejemplos de Docker Compose

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Pilas de Docker Compose ejecutables, construidas a partir de las imágenes de
contenedor publicadas por este repositorio. Cada directorio es autónomo: cópielo,
edite el `.env` y ejecute `docker compose up -d`.

## Antes de ejecutar nada

Los valores por defecto de `env.example` son valores de desarrollo. Defina estos
en su `.env` antes de arrancar una pila que le importe:

| Variable | Por qué |
|---|---|
| `AXONOPS_ORG_NAME` | Su valor por defecto es `example` (`my-organization` en 02). Da nombre a su organización en todo AxonOps y queda grabado en el registro de los agentes: cámbielo antes del primer arranque, no después. |
| `AXONOPS_DB_PASSWORD` | Contraseña de la base de datos de series temporales (`axondb-timeseries`). El valor por defecto `axonops` es de dominio público. Use un valor fuerte y único. |
| `AXONOPS_SEARCH_PASSWORD` | Contraseña de la base de datos de búsqueda (`axondb-search`). El mismo razonamiento. La imagen de búsqueda aplica además su propia política de contraseñas: con un valor débil el contenedor se niega a arrancar. |
| `AXONOPS_LICENSE_KEY` | Opcional. Sin ella, AxonOps funciona sólo con las prestaciones de la edición gratuita. Consulte [las ediciones de AxonOps](https://axonops.com/docs/editions/) para ver qué incluye cada una. |

El ejemplo 02 (SaaS) es la excepción: AxonOps se ejecuta en AxonOps Cloud, así
que sólo se aplican `AXONOPS_ORG_NAME` y su clave de agente; no hay bases de
datos locales a las que dar contraseñas.

Las contraseñas viven en `.env`, que está en el gitignore. Nunca suba ninguna.

## ¿Cuál quiero?

| | [00-axonops-platform](00-axonops-platform/) | [01-cassandra-cluster](01-cassandra-cluster/) | [02-saas-cassandra-cluster](02-saas-cassandra-cluster/) | [03-secure-3-rack-cluster](03-secure-3-rack-cluster/) | [04-cassandra-cluster-and-config](04-cassandra-cluster-and-config/) |
|---|---|---|---|---|---|
| **Úselo para** | ejecutar AxonOps para clústeres que ya tiene | ver el conjunto funcionando de extremo a extremo | monitorizar un clúster sin ejecutar AxonOps | modelar un clúster con forma de producción y asegurado | mantener las alertas en git en lugar de en la interfaz |
| AxonOps | autoalojado | autoalojado | SaaS | autoalojado | autoalojado |
| Cassandra | ninguna: traiga la suya | 3 nodos, monitorizados | 3 nodos, monitorizados | 3 nodos, 3 racks, monitorizados | 1 nodo, monitorizado |
| Autenticación del clúster | — | desactivada | desactivada | `PasswordAuthenticator` | desactivada |
| Contenedores | 4 | 7 | 3 | 7 | 5, más un job de configuración de un solo uso |
| RAM con los valores por defecto | ~10 GB | ~10 GB | ~5 GB | ~12 GB | ~6 GB |
| Panel | `localhost:3000` | `localhost:3000` | consola de AxonOps | `localhost:3000` | `localhost:3000` |
| Necesita | nada | nada | una organización SaaS y una clave de agente | nada | nada |

Empiece por **01** si está evaluando AxonOps y quiere ver un clúster real
aparecer en un panel. Empiece por **00** si ya ejecuta Cassandra o Kafka y quiere
un sitio al que sus agentes reporten. Empiece por **02** si tiene una cuenta de
AxonOps Cloud. Empiece por **03** si quiere un clúster que se parezca a un
despliegue real —autenticación, un rack por nodo, direccionamiento fijo y JMX
remoto— o si está portando la muy difundida
[pila de Compose Prometheus / Grafana / Reaper](https://github.com/crystalloide/cassandra-reaper)
en la que se basa. Empiece por **04** si quiere reglas de alerta, comprobaciones
de servicio y rutas de notificación definidas en un fichero y aplicadas por un
contenedor, en lugar de pulsadas en el panel.

## Convenciones

Todos los ejemplos siguen la misma forma:

```
<example>/
  docker-compose.yaml   Services, pinned to immutable version tags
  env.example           Every variable, with defaults, commented
  README.md             Quick start, configuration reference, troubleshooting
```

- **La configuración está sólo en `.env`**, y no hace falta editar ningún
  `docker-compose.yaml` para ejecutarlos. El ejemplo 03 es la única excepción:
  reproduce un entorno de cliente que monta por bind el directorio de
  configuración de Cassandra desde el host, así que incluye además un `setup.sh`
  que lo crea y lo puebla.
- **Las imágenes** vienen de `ghcr.io/axonops/*` o de
  `registry.axonops.com/axonops-public/*`, fijadas a una etiqueta de versión con
  el digest SHA256 en un comentario encima. Despliegue el digest en producción:
  consulte
  [Fijar la imagen: etiquetas frente a sumas de verificación](00-axonops-platform/README.es.md#fijar-la-imagen-etiquetas-frente-a-sumas-de-verificación)
  y [VERSIONS.md](../VERSIONS.md).
- **El dimensionado** usa por defecto valores de desarrollo. Cada README indica
  qué bajar.
- **TLS** protege todo lo que sale de un host. El tráfico de los agentes dentro
  de una única red de Compose va en texto plano por diseño; el ejemplo SaaS usa
  TLS de principio a fin.
- **Los secretos** viven en `.env`, que está en el gitignore. Nunca suba ninguno.

## Requisitos

- Docker Engine 20.10+ y Docker Compose V2
- Los requisitos de RAM, disco y puertos de cada ejemplo están en el README de ese ejemplo

## Preguntas frecuentes

### ¿Cómo actualizo `axon-server`, `axon-dash` y el agente?

Todas las imágenes de estos ficheros están fijadas a una etiqueta de versión
exacta, así que `docker compose pull` por sí solo no le trae nada nuevo: una
actualización significa editar la etiqueta (o el digest, si despliega la forma
con digest) y recrear ese único servicio. Las etiquetas y digests actuales de
cada imagen: [VERSIONS.md](../VERSIONS.md).

**Orden.** Primero los almacenes de datos si cambiaron, luego `axon-server`,
luego `axon-dash`, luego los agentes. Mantenga `axon-server` y `axon-dash` en
releases del mismo lote: el dash habla con la API del servidor, no al revés, así
que un dash más nuevo contra un servidor más antiguo es la combinación que hay
que evitar.

**`axon-server` y `axon-dash`.** Ambos están fijados directamente en
`docker-compose.yaml`, con el digest en un comentario encima de la etiqueta:

```yaml
  axon-server:
    # Preferred (immutable): registry.axonops.com/…/axon-server@sha256:c75f6672…
    image: registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35
```

Cambie la etiqueta y el comentario del digest a la vez —un comentario obsoleto
junto a una etiqueta nueva es la forma en que alguien despliega después la imagen
equivocada— y luego recree sólo ese servicio:

```bash
docker compose pull axon-server
docker compose up -d axon-server        # recreates only this container
docker compose logs -f axon-server      # watch it come up
docker compose ps                       # healthy?
```

Después, los mismos dos comandos para `axon-dash`. El ejemplo 02 no tiene
ninguno de los dos: AxonOps Cloud los ejecuta y los actualiza por usted, así que
ahí el agente es lo único que actualiza. Ambos son sin estado: todo vive en
`axondb-timeseries` y `axondb-search`, que no está tocando, así que recrearlos no
pierde datos. Los agentes se reconectan solos en cuanto el servidor vuelve.

**El agente.** Viaja dentro de la imagen de Cassandra en lugar de como su propio
contenedor, y es el componente central de la etiqueta:
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` es Cassandra 5.0.8 con
el agente 2.0.31 de la build 1.1.0. Actualizar el agente significa, por tanto,
pasar a una nueva etiqueta de imagen, que en los ejemplos 01, 02 y 03 es
`CASSANDRA_IMAGE` en `.env`:

```bash
CASSANDRA_IMAGE=ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0
```

Recree los nodos **de uno en uno**, esperando a que cada uno vuelva a estar
healthy antes de empezar con el siguiente, y drene primero para que el nodo deje
de aceptar escrituras que perdería:

```bash
docker compose pull
docker compose exec cassandra-1 nodetool drain
docker compose up -d --no-deps cassandra-1
docker compose ps                            # wait for healthy, then the next node
docker compose exec cassandra-1 nodetool status
```

Los nodos son `cassandra-0`, `cassandra-1` y `cassandra-2` en los ejemplos 01 y
02, y `cassandra01`, `cassandra02` y `cassandra03` en el ejemplo 03.

Los datos sobreviven: están en un volumen con nombre (el ejemplo 03 usa
directorios del host bajo `./docker/`), y recrear un contenedor no elimina
ninguno de los dos. En el ejemplo 00 no hay contenedores de Cassandra que
actualizar: los agentes se ejecutan en sus propios hosts, y allí los actualiza.

**Cambiar la versión de Cassandra no es lo mismo.** Sólo el primer componente de
la etiqueta es Cassandra en sí, y moverlo es una actualización de base de datos
de verdad —snapshot, `nodetool upgradesstables` después, notas de la release
upstream—, no un cambio de imagen. Para adoptar un agente o una build nuevos,
deje la versión de Cassandra donde está y cambie sólo el segundo o el tercer
componente.

**Volver atrás** es la misma operación con la etiqueta antigua: póngala de nuevo
y ejecute otra vez `docker compose up -d <service>`.

### ¿Cómo actualizo AxonOps sin tocar el clúster de Cassandra?

Actualizar AxonOps y actualizar Cassandra son operaciones distintas. Todo lo del
lado de AxonOps —`axondb-timeseries`, `axondb-search`, `axon-server`,
`axon-dash`— puede sustituirse mientras el clúster sigue funcionando, porque no
se recrea ningún contenedor de Cassandra ni interviene ningún comando
`nodetool`. Los agentes son la única excepción: viajan dentro de la imagen de
Cassandra, así que actualizar un agente sí recrea un contenedor de Cassandra
(véase más arriba).

**Qué ve el clúster.** Nada. Los agentes almacenan en memoria mientras
`axon-server` está caído y vuelcan cuando vuelve; Cassandra ni siquiera se entera
de que la pila de monitorización se reinició. Espere un hueco en las métricas
durante lo que dure el reinicio, y tenga en cuenta que las alertas que dependen
de la llegada de datos pueden dispararse: silencie primero las ruidosas si tiene
integraciones conectadas.

**Antes de empezar.**

```bash
docker compose ps                       # note what is healthy now
docker compose config | grep image:     # record the tags you are moving away from
```

Haga copia de seguridad de los volúmenes de datos si la pila guarda un histórico
que le importa (`axondb-timeseries-data`, `axondb-search-data`,
`axon-server-data` en el ejemplo 00). Recrear un contenedor no borra un volumen
con nombre, pero volver atrás es más fácil con una copia.

**Orden.** Las bases de datos, luego `axon-server`, luego `axon-dash`: las
dependencias primero, para que nada hable con algo más antiguo que él mismo.
Omita cualquier componente cuya etiqueta no haya cambiado. Haga un servicio cada
vez y confirme que está healthy antes de pasar al siguiente:

```bash
# 1. Edit docker-compose.yaml: new tag AND the digest comment above it
# 2. Then, per service:
docker compose pull <service>
docker compose up -d --no-deps <service>   # --no-deps: do not restart anything else
docker compose logs -f <service>
docker compose ps                          # healthy before moving on
```

Aquí `--no-deps` importa. Sin él, Compose puede reiniciar servicios enlazados, lo
que en los ejemplos 01 y 03 arrastra los contenedores de Cassandra a una
actualización que usted no pidió.

**Verifique, en este orden:**

```bash
docker compose ps                       # all healthy
docker compose exec axon-server \
  curl -sf http://localhost:8080/api/v1/healthz
```

El puerto de la API de `axon-server` no se publica al host en estos ejemplos, y
por eso la comprobación se ejecuta dentro del contenedor: es la misma sonda que
usa el propio healthcheck del servicio. Después, abra el panel en
`localhost:3000` y confirme que todos los nodos siguen listados y que las
métricas se reanudan. Un nodo que aparezca como desconectado más de un minuto o
dos después de que el servidor esté healthy significa que el agente no se
reconectó: reinicie el contenedor de Cassandra de ese agente el último, no el
primero.

**Volver atrás** es el mismo bucle con las etiquetas anteriores. Las imágenes de
base de datos son el único componente en el que volver atrás no siempre es
seguro: una versión más nueva puede haber migrado su formato en disco, así que
haga retroceder `axondb-*` sólo sobre una copia restaurada del volumen, no sobre
datos que una versión más nueva ya ha escrito.

**Desfase de versiones.** Mantenga `axon-server` y `axon-dash` en releases del
mismo lote. Los agentes son la parte tolerante: un agente más antiguo reportando
a un servidor más nuevo es normal y esperable durante un despliegue escalonado,
razón por la cual los agentes van los últimos y pueden esperar a una ventana de
mantenimiento del clúster.

## Cuando algo no arranca

Cada README tiene una sección de resolución de problemas para su propia pila.
Hay una clase de problema que conviene conocer de antemano: varias de estas
imágenes aceptan configuración bajo nombres distintos de los que sugiere su
propia documentación, y un nombre equivocado se ignora en silencio en lugar de
rechazarse. Los tres encontrados hasta ahora —en `axondb-search`,
`axondb-timeseries` y `axon-dash`— están documentados en
[variables de configuración que parecen correctas pero no lo son](01-cassandra-cluster/README.es.md#variables-de-configuración-que-parecen-correctas-pero-no-lo-son),
con el error que produce cada una.

## Soporte

Mantenido por [AxonOps](https://axonops.com). Para soporte, contacte con nosotros en
[axonops.com/contact](https://axonops.com/contact).
