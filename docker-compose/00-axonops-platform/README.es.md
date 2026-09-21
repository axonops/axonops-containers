# Ejemplo 00 — La plataforma AxonOps por sí sola

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Una instalación autoalojada completa de AxonOps, y nada más. Apunte a ella los
agentes de sus propios hosts, o úsela como base para los demás ejemplos.

- ¿Quiere un clúster de Cassandra monitorizado en el mismo proyecto?
  [Ejemplo 01](../01-cassandra-cluster/): la plataforma más tres nodos.
- ¿Tiene una cuenta de AxonOps Cloud? [Ejemplo 02](../02-saas-cassandra-cluster/):
  un clúster que reporta a SaaS, sin plataforma que ejecutar.

## Inicio rápido

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose ps            # wait for all four services to report healthy
```

Después abra <http://localhost:3000>.

Un arranque en frío tarda de 2 a 3 minutos: primero se inicializan los dos
almacenes de datos, y detrás de ellos suben `axon-server` y el panel.

## Qué ejecuta

| Servicio | Imagen | Propósito | Puerto publicado |
|---------|-------|---------|----------------|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Almacén de métricas (Cassandra) | — |
| `axondb-search` | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Almacén de registros y eventos (OpenSearch) | — |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35` | Backend y endpoint de los agentes | `1888` |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash:2.0.37` | Panel web | `3000` |

Las etiquetas y digests actuales de cada imagen: [VERSIONS.md](../../VERSIONS.md).

## Configuración

Todo se define en `.env`. Lista completa con los valores por defecto:
[`env.example`](env.example).

| Variable | Valor por defecto | Descripción |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Nombre de la organización, mostrado en el panel. Los agentes deben usar el mismo valor. |
| `AXONOPS_LICENSE_KEY` | (vacío) | Clave de licencia; vacío ejecuta en modo de prueba |
| `AXONOPS_DB_PASSWORD` | `axonops` | Contraseña de `axondb-timeseries` |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Contraseña de administración de `axondb-search` |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `4G` | Heap de `axondb-timeseries` |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `4g` | Heap de `axondb-search` |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS de `axon-server` a `axondb-search` |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS de `axon-server` a `axondb-timeseries`: véase más abajo |

`axon-server` se configura por completo mediante variables de entorno; no hay
ningún fichero de configuración que montar ni renderizar. Cada una sobrescribe el
campo correspondiente del `axon-server.yml` incluido en la imagen:
`AXONSERVER_ORGNAME`, `LICENSE_KEY`, `TLS_MODE`, el conjunto `CQL_*` para el
almacén de métricas y el conjunto `SEARCH_DB_*` para el almacén de registros. La
correspondencia completa está en
[el ejemplo 01](../01-cassandra-cluster/README.es.md#configuración).

### TLS entre los servicios

**Hacia `axondb-search`: activado.** La imagen genera sus propios certificados
autofirmados, `axon-server` se conecta por HTTPS y omite la verificación.

**Hacia `axondb-timeseries`: desactivado.** La imagen sólo activa las
`client_encryption_options` de Cassandra cuando hay un keystore montado en
`CASSANDRA_KEYSTORE_PATH` —ninguna variable de entorno lo activa por sí sola—,
así que el transporte nativo va en texto plano y `axon-server` debe hacer lo
mismo. Activar `AXONOPS_CASSANDRA_SSL` sin montar un keystore rompe la conexión;
véase [Resolución de problemas](#resolución-de-problemas).

Todo este tráfico permanece dentro de la red de Compose.

## Conectar agentes

El endpoint de los agentes (`1888`) está publicado, así que los agentes de otros
hosts pueden conectarse:

```yaml
# axon-agent.yml on the monitored host
axon-server:
  hosts: "your-docker-host:1888"
axon-agent:
  org: "my-company"        # must match AXONOPS_ORG_NAME
```

Los agentes en contenedores toman los mismos ajustes como variables de entorno:
`AXON_AGENT_SERVER_HOST`, `AXON_AGENT_SERVER_PORT`, `AXON_AGENT_ORG`. El ejemplo
01 conecta exactamente eso para un clúster de Cassandra en el mismo proyecto.

## Fijar la imagen: etiquetas frente a sumas de verificación

Cada `image:` de `docker-compose.yaml` puede escribirse de dos maneras. Las dos
se muestran a continuación y las dos funcionan, pero dan garantías muy distintas.

```yaml
# Tag — readable, mutable
image: ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0

# Digest (SHA256 checksum) — preferred
image: ghcr.io/axonops/axondb-timeseries@sha256:1ae990a737d36b7c6f8eb92d6d3baf5234e5eae2a4e37fa208acd1108cad934c
```

**Use el digest.** Un digest es una suma de verificación criptográfica del
contenido exacto de la imagen, así que `docker compose pull` sólo puede
descargar los bytes contra los que usted probó. Una etiqueta no es más que un
puntero mutable: quien controle el registro puede moverla, y entonces el mismo
fichero de Compose arranca en silencio una imagen distinta. Ese es el riesgo de
cadena de suministro que eliminan los digests.

Guía práctica:

| Referencia | Cuándo usarla |
|-----------|-------------|
| `@sha256:<digest>` | **Producción, y todo lo que necesite reproducir.** Inmutable, verificable, auditable. |
| `:5.0.8-1.4.0` (etiqueta de versión) | Desarrollo y evaluación, donde la legibilidad importa más que la inmutabilidad. Este repositorio nunca sobrescribe una etiqueta de versión publicada, así que en la práctica son estables, sólo que sin garantía criptográfica. |
| `:latest`, `:5.0.8` (etiquetas flotantes) | Nunca en producción. Se mueven con cada release. |

La contrapartida es la legibilidad: un digest no le dice nada sobre qué versión
está ejecutando. Mantenga la etiqueta de versión a su lado en un comentario, como
hace `docker-compose.yaml`, y registre la correspondencia en
[VERSIONS.md](../../VERSIONS.md).

### Encontrar el digest de una versión

En [VERSIONS.md](../../VERSIONS.md) hay referencias listas para copiar y pegar de
la release actual de cada imagen, regeneradas por
`../../scripts/update-versions.sh`.

Para resolver una usted mismo, sin descargar la imagen:

```bash
docker buildx imagetools inspect ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0 \
  --format '{{ .Manifest.Digest }}'
```

O, si ya la ha descargado:

```bash
docker inspect ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0 \
  --format '{{ index .RepoDigests 0 }}'
```

Todas las imágenes publicadas en GHCR están firmadas con Cosign de Sigstore.
Verifique la firma contra el digest antes de desplegar: consulte
[Despliegue con seguridad de referencia](../../README.es.md#despliegue-con-seguridad-de-referencia)
para el procedimiento completo y su justificación.

## Operación

```bash
docker compose ps                       # health of every service
docker compose logs -f                  # follow everything
docker compose logs -f axon-server      # follow one service
docker compose down                     # stop, keep data
docker compose down -v                  # stop and delete all volumes
```

Los datos viven en volúmenes con nombre: `axondb-timeseries-data`,
`axondb-timeseries-logs`, `axondb-search-data`, `axondb-search-logs`,
`axon-server-data`.

## Requisitos

- Docker Engine 20.10+ y Compose V2
- 10 GB de RAM libres con los valores por defecto de arriba, 16 GB recomendados; 20 GB de disco
- Puertos 3000 y 1888 libres en el host

Para una máquina de desarrollo con menos memoria, baje los dos heaps:

```bash
AXONOPS_CASSANDRA_HEAP_SIZE=2G
AXONOPS_OPENSEARCH_HEAP_SIZE=2g
```

## Resolución de problemas

**Un servicio nunca llega a estar healthy.** El primer arranque tarda de 2 a 3
minutos. Obsérvelo con `docker compose ps` y luego lea el registro de ese
servicio: `docker compose logs -f axondb-timeseries`.

**`axon-server` se reinicia.** Necesita los dos almacenes de datos healthy;
`depends_on: condition: service_healthy` impone el orden, así que revise primero
`docker compose logs axondb-timeseries axondb-search`. Después confirme que
`AXONOPS_DB_PASSWORD` y `AXONOPS_SEARCH_PASSWORD` coinciden entre los almacenes y
`axon-server`.

**Falta de memoria.** Baje `AXONOPS_CASSANDRA_HEAP_SIZE` y
`AXONOPS_OPENSEARCH_HEAP_SIZE` como se indica arriba.

**El panel no carga.** Compruebe que el dash llega al backend:

```bash
docker exec axon-dash curl -s http://axon-server:8080/api/v1/healthz
```

**Cassandra registra `Invalid or unsupported protocol version (22)` y
`axon-server` registra `tls: first record does not look like a TLS handshake`.**
Un lado está usando TLS y el otro no: 22 es `0x16`, el primer byte de un
ClientHello de TLS leído como una versión de protocolo CQL. Ponga
`AXONOPS_CASSANDRA_SSL=false` a menos que haya montado un keystore, como se
explica en [TLS entre los servicios](#tls-entre-los-servicios).

**Otros ajustes que parecen correctos pero se ignoran.** Tres de estas imágenes
admiten configuración bajo nombres distintos de los que sugieren sus propios
READMEs, y cada una falla sin nombrar la variable culpable. El ejemplo 01
documenta las tres:
[variables de configuración que parecen correctas pero no lo son](../01-cassandra-cluster/README.es.md#variables-de-configuración-que-parecen-correctas-pero-no-lo-son).

## Licencias

AxonOps requiere licencia para uso en producción: <https://axonops.com>. La pila
funciona sin clave de licencia en modo de prueba, lo que basta para la evaluación
y para los demás ejemplos de aquí.

## Soporte

Mantenido por [AxonOps](https://axonops.com). Para soporte, contacte con nosotros en
[axonops.com/contact](https://axonops.com/contact).
