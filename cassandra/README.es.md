# Contenedor de Apache Cassandra de AxonOps

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

[![Paquete GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/cassandra%2Fcassandra)

Apache Cassandra con el agente de monitorización y gestión de AxonOps, sin la Management API de K8ssandra. Para ejecutar Cassandra fuera de Kubernetes, o dentro de él sin el operador de K8ssandra.

Si va a desplegar con el operador de K8ssandra, use [`ghcr.io/axonops/k8ssandra/cassandra`](../k8ssandra/README.es.md) en su lugar.

## Cómo se construye

No hay un Dockerfile aparte. Esta imagen es [`k8ssandra/5.0/Dockerfile`](../k8ssandra/5.0/Dockerfile) construido con `INCLUDE_MGMT_API=false`, lo que:

- elimina `/opt/management-api` y `/opt/cdc_agent`
- elimina el agente Java de la Management API de `cassandra-env.sh`, que la imagen base incorpora
- arranca Cassandra directamente en lugar de a través del entrypoint de la Management API
- comprueba la salud de Cassandra por el transporte nativo en lugar del endpoint de liveness de la Management API (la comprobación del agente es la misma en ambos casos)

Todo lo demás —imagen base, agente de AxonOps, cqlai, jemalloc— es idéntico a la imagen de K8ssandra, y un único Dockerfile sirve para ambas.

**Advertencia sobre el tamaño:** los ficheros de la Management API se eliminan en una capa derivada, así que no están en el contenedor en ejecución, pero las capas de la imagen base siguen incluyéndolos. La descarga de la imagen es unos 93 MB mayor de lo que su contenido justifica.

## Imagen

```
ghcr.io/axonops/cassandra/cassandra:{CASSANDRA}-{AGENT}-{BUILD}
```

Por ejemplo, `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.0.0` es Apache Cassandra 5.0.8 con el agente de AxonOps 2.0.31, de la build 1.0.0.

| Forma de la etiqueta | ¿Mutable? | Significado |
|----------|----------|---------|
| `5.0.8-2.0.31-1.0.0` | No | Versión exacta de Cassandra, versión exacta del agente, build exacta |
| `5.0.8-2.0.31` | Sí | Última build para ese par Cassandra + agente |
| `5.0.8` | Sí | Último agente y última build para esa versión de Cassandra |
| `5.0-latest` | Sí | Última release de parche 5.0.x |
| `latest` | Sí | Última versión en general |

El componente de agente de una etiqueta es siempre una versión concreta. Pasar `latest` como versión del agente al pipeline lo resuelve a la versión realmente instalada antes de escribir ninguna etiqueta.

Las builds de desarrollo van a `ghcr.io/axonops/development/cassandra`, junto a las imágenes de desarrollo de los demás componentes, y no son para uso en producción.

Fije por digest todo aquello que le importe:

```bash
docker buildx imagetools inspect ghcr.io/axonops/cassandra/cassandra:5.0.8
```

## Inicio rápido

```bash
docker run -d --name cassandra \
  -e AXON_AGENT_ORG=your-org \
  -e AXON_AGENT_KEY=your-agent-key \
  -e AXON_AGENT_CLUSTER_NAME=my-cluster \
  -p 9042:9042 \
  ghcr.io/axonops/cassandra/cassandra:5.0.8
```

`AXON_AGENT_ORG` es obligatoria; el contenedor se niega a arrancar sin ella. Compruebe el progreso con:

```bash
docker logs -f cassandra
docker exec cassandra nodetool status
docker exec cassandra cqlai -e "SELECT release_version FROM system.local;"
```

En [`docker-compose/`](../docker-compose/README.es.md) hay ejemplos multinodo ejecutables que usan esta imagen: [01](../docker-compose/01-cassandra-cluster/) monitoriza el clúster con una pila de AxonOps autoalojada, [02](../docker-compose/02-saas-cassandra-cluster/) reporta a AxonOps SaaS.

## Configuración

### Agente de AxonOps

| Variable | Valor por defecto | Descripción |
|----------|---------|-------------|
| `AXON_AGENT_ORG` | — | Organización de AxonOps. Obligatoria. |
| `AXON_AGENT_KEY` | — | Clave de agente para AxonOps SaaS. |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | Servidor de AxonOps al que conectarse. Defínala para instalaciones autoalojadas. |
| `AXON_AGENT_SERVER_PORT` | `443` | Puerto del servidor de AxonOps. |
| `AXON_AGENT_CLUSTER_NAME` | — | Nombre del clúster mostrado en AxonOps. |
| `AXON_AGENT_TLS_MODE` | — | Póngala a `disabled` para un servidor autoalojado en texto plano. |
| `AXON_AGENT_NTP_HOST` | autodetectado | Host NTP usado para las comprobaciones de desviación del reloj. |
| `AXON_AGENT_ARGS` | — | Argumentos adicionales pasados a `axon-agent`. |

### Cassandra

Las mismas variables `CASSANDRA_*` que aceptan la imagen de K8ssandra y la imagen oficial de Cassandra. Se aplican a `cassandra.yaml` y `cassandra-rackdc.properties` en el arranque.

| Variable | Valor por defecto | Descripción |
|----------|---------|-------------|
| `CASSANDRA_SEEDS` | dirección de difusión propia | Lista de seeds separada por comas |
| `CASSANDRA_CLUSTER_NAME` | `Test Cluster` | Nombre del clúster |
| `CASSANDRA_LISTEN_ADDRESS` | `auto` | `auto` se resuelve a la IP del contenedor |
| `CASSANDRA_BROADCAST_ADDRESS` | dirección de escucha | Dirección que usan los demás nodos |
| `CASSANDRA_RPC_ADDRESS` | `0.0.0.0` | Dirección de escucha de CQL |
| `CASSANDRA_BROADCAST_RPC_ADDRESS` | dirección de difusión | Dirección que se indica a los clientes |
| `CASSANDRA_NUM_TOKENS` | valor por defecto de Cassandra | Número de vnodes |
| `CASSANDRA_ENDPOINT_SNITCH` | valor por defecto de Cassandra | Snitch |
| `CASSANDRA_NATIVE_TRANSPORT_PORT` | `9042` | Puerto CQL |
| `CASSANDRA_AUTHENTICATOR` | `AllowAllAuthenticator` | Póngala a `PasswordAuthenticator` para exigir credenciales |
| `CASSANDRA_AUTHORIZER` | `AllowAllAuthorizer` | Póngala a `CassandraAuthorizer` para aplicar permisos |
| `CASSANDRA_ROLE_MANAGER` | `CassandraRoleManager` | Implementación del gestor de roles |
| `CASSANDRA_DC` | valor por defecto de Cassandra | Datacenter en `cassandra-rackdc.properties` |
| `CASSANDRA_RACK` | valor por defecto de Cassandra | Rack en `cassandra-rackdc.properties` |

Un directorio montado en `/config` se copia sobre `$CASSANDRA_CONF` antes de aplicar esas variables, así que montar un `cassandra.yaml` es la manera de fijar cualquier cosa no listada arriba.

Ejemplo multinodo:

```bash
docker run -d --name cassandra-1 \
  -e AXON_AGENT_ORG=your-org -e AXON_AGENT_KEY=your-agent-key \
  -e CASSANDRA_CLUSTER_NAME=prod -e CASSANDRA_SEEDS=10.0.0.1,10.0.0.2 \
  -e CASSANDRA_DC=dc1 -e CASSANDRA_RACK=rack1 \
  -v /data/cassandra:/var/lib/cassandra \
  --network host \
  ghcr.io/axonops/cassandra/cassandra:5.0.8
```

| Ruta | Propósito |
|------|---------|
| `/opt/cassandra/conf` | Configuración de Cassandra |
| `/config` | Superposición de configuración opcional, copiada sobre la anterior en el arranque |
| `/var/lib/cassandra` | Directorio de datos |
| `/var/log/cassandra` | Registros de Cassandra |
| `/var/log/axonops/axon-agent.log` | Registro del agente |
| `/etc/axonops/build-info.txt` | Versiones capturadas en tiempo de build, mostradas en el banner de arranque |

Cassandra se ejecuta como el usuario `cassandra`, nunca como root. El agente se ejecuta bajo un supervisor que lo reinicia al salir, con backoff frente a bucles de caída ([#154](https://github.com/axonops/axonops-containers/issues/154)); el contenedor vive y muere con el proceso de Cassandra.

### Comprobación de salud

La comprobación de salud del contenedor (`/usr/local/bin/axonops-healthcheck.sh`, ejecutada cada 30 s) comprueba dos cosas:

1. **Cassandra**: `nodetool statusbinary` informa de que el transporte nativo está en marcha, y el puerto CQL acepta conexiones. En la imagen de K8ssandra, donde la Management API está presente, se usa su endpoint de liveness en su lugar.
2. **Agente de AxonOps**: el proceso `axon-agent` se está ejecutando, así que el nodo está realmente monitorizado.

Por defecto, un agente caído se refleja en la salida de la comprobación de salud, pero no vuelve al contenedor unhealthy: Cassandra sigue sirviendo CQL, y hacer fallar la comprobación puede llevar a un orquestador a reiniciar o vaciar un nodo que está haciendo trabajo útil. Ponga `HEALTHCHECK_REQUIRE_AGENT=true` para tratar un agente caído como un fallo.

| Variable | Valor por defecto | Descripción |
|----------|---------|-------------|
| `HEALTHCHECK_REQUIRE_AGENT` | `false` | `true` vuelve unhealthy el contenedor cuando `axon-agent` no está en ejecución |

```bash
# Current status and the last check's output
docker inspect --format '{{.State.Health.Status}}' cassandra-1
docker inspect --format '{{(index .State.Health.Log 0).Output}}' cassandra-1

# Run it by hand
docker exec cassandra-1 /usr/local/bin/axonops-healthcheck.sh
```

El agente sólo se arranca una vez Cassandra está levantada, así que normalmente está ausente durante la primera parte del periodo de arranque de 120 s. Para eso está ese periodo: con `HEALTHCHECK_REQUIRE_AGENT=true` en un nodo de arranque lento, súbalo en lugar de bajar los reintentos.

## Versiones admitidas

Apache Cassandra de la 5.0.1 a la 5.0.8. La matriz está acotada por la variable de repositorio `K8SSANDRA_VERSIONS`, que fija un digest de imagen base por versión de Cassandra: una versión sólo puede construirse aquí una vez tiene una entrada allí.

## Construcción local

```bash
DIGEST=$(gh api /repos/axonops/axonops-containers/actions/variables/K8SSANDRA_VERSIONS \
  --jq '.value | fromjson | ."5.0.8+0.1.120"')

docker build -t axonops-cassandra:local \
  --build-arg CASSANDRA_VERSION=5.0.8 \
  --build-arg MAJOR_VERSION=5.0 \
  --build-arg K8SSANDRA_BASE_DIGEST="$DIGEST" \
  --build-arg K8SSANDRA_API_VERSION=0.1.120 \
  --build-arg INCLUDE_MGMT_API=false \
  --build-arg CQLAI_VERSION=0.1.7 \
  k8ssandra/5.0
```

Quite `INCLUDE_MGMT_API=false` para construir en su lugar la imagen de K8ssandra: su valor por defecto es `true`.

## Pipelines

Los comandos de activación están en [PIPELINES.md](../PIPELINES.md).

| Workflow | Propósito |
|----------|---------|
| `cassandra-build-and-test.yml` | Construye y prueba en las pull requests; no publica nada |
| `cassandra-publish-signed.yml` | Build de producción, publicación y firma con cosign a partir de una etiqueta en `main` |
| `cassandra-development-publish-signed.yml` | Build de desarrollo publicada en `ghcr.io/axonops/development/cassandra` |

Toda imagen publicada se firma con cosign de Sigstore sin claves:

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/axonops/axonops-containers" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.0.0
```

## Soporte

Mantenido por [AxonOps](https://axonops.com). Para soporte, contacte con nosotros en [axonops.com/contact](https://axonops.com/contact).
