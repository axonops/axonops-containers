# Contedor de Apache Cassandra de AxonOps

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

[![Paquete GHCR](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/cassandra%2Fcassandra)

Apache Cassandra co axente de monitorización e xestión de AxonOps, sen a Management API de K8ssandra. Para executar Cassandra fóra de Kubernetes, ou dentro del sen o operador de K8ssandra.

Se vai despregar co operador de K8ssandra, use [`ghcr.io/axonops/k8ssandra/cassandra`](../k8ssandra/README.gl.md) no seu lugar.

## Como se constrúe

Non hai un Dockerfile á parte. Esta imaxe é [`k8ssandra/5.0/Dockerfile`](../k8ssandra/5.0/Dockerfile) construído con `INCLUDE_MGMT_API=false`, o que:

- elimina `/opt/management-api` e `/opt/cdc_agent`
- elimina o axente Java da Management API de `cassandra-env.sh`, que a imaxe base incorpora
- arranca Cassandra directamente en lugar de a través do entrypoint da Management API
- comproba a saúde de Cassandra polo transporte nativo en lugar do endpoint de liveness da Management API (a comprobación do axente é a mesma nos dous casos)

Todo o demais —imaxe base, axente de AxonOps, cqlai, jemalloc— é idéntico á imaxe de K8ssandra, e un único Dockerfile serve para as dúas.

**Advertencia sobre o tamaño:** os ficheiros da Management API elimínanse nunha capa derivada, así que non están no contedor en execución, pero as capas da imaxe base seguen levándoos. A descarga da imaxe é uns 93 MB maior do que o seu contido xustifica.

## Imaxe

```
ghcr.io/axonops/cassandra/cassandra:{CASSANDRA}-{AGENT}-{BUILD}
```

Por exemplo, `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.0.0` é Apache Cassandra 5.0.8 co axente de AxonOps 2.0.31, da build 1.0.0.

| Forma da etiqueta | Mutable? | Significado |
|----------|----------|---------|
| `5.0.8-2.0.31-1.0.0` | Non | Versión exacta de Cassandra, versión exacta do axente, build exacta |
| `5.0.8-2.0.31` | Si | Última build para ese par Cassandra + axente |
| `5.0.8` | Si | Último axente e última build para esa versión de Cassandra |
| `5.0-latest` | Si | Última release de parche 5.0.x |
| `latest` | Si | Última versión en xeral |

O compoñente de axente dunha etiqueta é sempre unha versión concreta. Pasar `latest` como versión do axente ao pipeline resólveo á versión realmente instalada antes de escribir ningunha etiqueta.

As builds de desenvolvemento van a `ghcr.io/axonops/development/cassandra`, xunto ás imaxes de desenvolvemento dos demais compoñentes, e non son para uso en produción.

Fixe por digest todo aquilo que lle importe:

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

`AXON_AGENT_ORG` é obrigatoria; o contedor négase a arrancar sen ela. Comprobe o progreso con:

```bash
docker logs -f cassandra
docker exec cassandra nodetool status
docker exec cassandra cqlai -e "SELECT release_version FROM system.local;"
```

En [`docker-compose/`](../docker-compose/README.gl.md) hai exemplos multinodo executables que usan esta imaxe: [01](../docker-compose/01-cassandra-cluster/) monitoriza o clúster cunha pila de AxonOps autoaloxada, [02](../docker-compose/02-saas-cassandra-cluster/) reporta a AxonOps SaaS.

## Configuración

### Axente de AxonOps

| Variable | Valor por defecto | Descrición |
|----------|---------|-------------|
| `AXON_AGENT_ORG` | — | Organización de AxonOps. Obrigatoria. |
| `AXON_AGENT_KEY` | — | Chave de axente para AxonOps SaaS. |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | Servidor de AxonOps ao que conectarse. Defínaa para instalacións autoaloxadas. |
| `AXON_AGENT_SERVER_PORT` | `443` | Porto do servidor de AxonOps. |
| `AXON_AGENT_CLUSTER_NAME` | — | Nome do clúster amosado en AxonOps. |
| `AXON_AGENT_TLS_MODE` | — | Póñaa a `disabled` para un servidor autoaloxado en texto plano. |
| `AXON_AGENT_NTP_HOST` | autodetectado | Host NTP usado para as comprobacións de desviación do reloxo. |
| `AXON_AGENT_ARGS` | — | Argumentos adicionais pasados a `axon-agent`. |

### Cassandra

As mesmas variables `CASSANDRA_*` que aceptan a imaxe de K8ssandra e a imaxe oficial de Cassandra. Aplícanse a `cassandra.yaml` e `cassandra-rackdc.properties` no arranque.

| Variable | Valor por defecto | Descrición |
|----------|---------|-------------|
| `CASSANDRA_SEEDS` | enderezo de difusión propio | Lista de seeds separada por comas |
| `CASSANDRA_CLUSTER_NAME` | `Test Cluster` | Nome do clúster |
| `CASSANDRA_LISTEN_ADDRESS` | `auto` | `auto` resólvese ao IP do contedor |
| `CASSANDRA_BROADCAST_ADDRESS` | enderezo de escoita | Enderezo que usan os demais nodos |
| `CASSANDRA_RPC_ADDRESS` | `0.0.0.0` | Enderezo de escoita de CQL |
| `CASSANDRA_BROADCAST_RPC_ADDRESS` | enderezo de difusión | Enderezo que se lles indica aos clientes |
| `CASSANDRA_NUM_TOKENS` | valor por defecto de Cassandra | Número de vnodes |
| `CASSANDRA_ENDPOINT_SNITCH` | valor por defecto de Cassandra | Snitch |
| `CASSANDRA_NATIVE_TRANSPORT_PORT` | `9042` | Porto CQL |
| `CASSANDRA_AUTHENTICATOR` | `AllowAllAuthenticator` | Póñaa a `PasswordAuthenticator` para esixir credenciais |
| `CASSANDRA_AUTHORIZER` | `AllowAllAuthorizer` | Póñaa a `CassandraAuthorizer` para aplicar permisos |
| `CASSANDRA_ROLE_MANAGER` | `CassandraRoleManager` | Implementación do xestor de roles |
| `CASSANDRA_DC` | valor por defecto de Cassandra | Datacenter en `cassandra-rackdc.properties` |
| `CASSANDRA_RACK` | valor por defecto de Cassandra | Rack en `cassandra-rackdc.properties` |

Un directorio montado en `/config` cópiase sobre `$CASSANDRA_CONF` antes de aplicar esas variables, así que montar un `cassandra.yaml` é a maneira de fixar calquera cousa non listada arriba.

Exemplo multinodo:

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
| `/config` | Superposición de configuración opcional, copiada sobre a anterior no arranque |
| `/var/lib/cassandra` | Directorio de datos |
| `/var/log/cassandra` | Rexistros de Cassandra |
| `/var/log/axonops/axon-agent.log` | Rexistro do axente |
| `/etc/axonops/build-info.txt` | Versións capturadas en tempo de build, amosadas no banner de arranque |

Cassandra execútase como o usuario `cassandra`, nunca como root. O axente execútase baixo un supervisor que o reinicia ao saír, con backoff fronte a bucles de caída ([#154](https://github.com/axonops/axonops-containers/issues/154)); o contedor vive e morre co proceso de Cassandra.

### Comprobación de saúde

A comprobación de saúde do contedor (`/usr/local/bin/axonops-healthcheck.sh`, executada cada 30 s) comproba dúas cousas:

1. **Cassandra**: `nodetool statusbinary` informa de que o transporte nativo está en marcha, e o porto CQL acepta conexións. Na imaxe de K8ssandra, onde a Management API está presente, úsase o seu endpoint de liveness no seu lugar.
2. **Axente de AxonOps**: o proceso `axon-agent` está a executarse, así que o nodo está realmente monitorizado.

Por defecto, un axente caído reflíctese na saída da comprobación de saúde, pero non volve unhealthy o contedor: Cassandra segue servindo CQL, e facer fallar a comprobación pode levar a un orquestrador a reiniciar ou baleirar un nodo que está a facer traballo útil. Poña `HEALTHCHECK_REQUIRE_AGENT=true` para tratar un axente caído como un fallo.

| Variable | Valor por defecto | Descrición |
|----------|---------|-------------|
| `HEALTHCHECK_REQUIRE_AGENT` | `false` | `true` volve unhealthy o contedor cando `axon-agent` non está en execución |

```bash
# Current status and the last check's output
docker inspect --format '{{.State.Health.Status}}' cassandra-1
docker inspect --format '{{(index .State.Health.Log 0).Output}}' cassandra-1

# Run it by hand
docker exec cassandra-1 /usr/local/bin/axonops-healthcheck.sh
```

O axente só se arranca unha vez Cassandra está levantada, así que normalmente está ausente durante a primeira parte do período de arranque de 120 s. Para iso está ese período: con `HEALTHCHECK_REQUIRE_AGENT=true` nun nodo de arranque lento, súbao en lugar de baixar os reintentos.

## Versións admitidas

Apache Cassandra da 5.0.1 á 5.0.8. A matriz está acoutada pola variable de repositorio `K8SSANDRA_VERSIONS`, que fixa un digest de imaxe base por versión de Cassandra: unha versión só pode construírse aquí unha vez ten unha entrada alí.

## Construción local

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

Quite `INCLUDE_MGMT_API=false` para construír no seu lugar a imaxe de K8ssandra: o seu valor por defecto é `true`.

## Pipelines

Os comandos de activación están en [PIPELINES.md](../PIPELINES.md).

| Workflow | Propósito |
|----------|---------|
| `cassandra-build-and-test.yml` | Constrúe e proba nas pull requests; non publica nada |
| `cassandra-publish-signed.yml` | Build de produción, publicación e sinatura con cosign a partir dunha etiqueta en `main` |
| `cassandra-development-publish-signed.yml` | Build de desenvolvemento publicada en `ghcr.io/axonops/development/cassandra` |

Toda imaxe publicada asínase con cosign de Sigstore sen chaves:

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/axonops/axonops-containers" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.0.0
```

## Soporte

Mantido por [AxonOps](https://axonops.com). Para soporte, contacte connosco en [axonops.com/contact](https://axonops.com/contact).
