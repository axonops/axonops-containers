# Exemplos de Docker Compose

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Pilas de Docker Compose executables, construídas a partir das imaxes de contedor
publicadas por este repositorio. Cada directorio é autónomo: cópieo, edite o
`.env` e execute `docker compose up -d`.

## Antes de executar nada

Os valores por defecto de `env.example` son valores de desenvolvemento. Defina
estes no seu `.env` antes de arrancar unha pila que lle importe:

| Variable | Por que |
|---|---|
| `AXONOPS_ORG_NAME` | O seu valor por defecto é `example` (`my-organization` no 02). Dá nome á súa organización en todo AxonOps e queda gravado no rexistro dos axentes: cámbieo antes do primeiro arranque, non despois. |
| `AXONOPS_DB_PASSWORD` | Contrasinal da base de datos de series temporais (`axondb-timeseries`). O valor por defecto `axonops` é de dominio público. Use un valor forte e único. |
| `AXONOPS_SEARCH_PASSWORD` | Contrasinal da base de datos de busca (`axondb-search`). O mesmo razoamento. A imaxe de busca aplica ademais a súa propia política de contrasinais: cun valor feble o contedor négase a arrancar. |
| `AXONOPS_LICENSE_KEY` | Opcional. Sen ela, AxonOps funciona só coas prestacións da edición gratuíta. Consulte [as edicións de AxonOps](https://axonops.com/docs/editions/) para ver que inclúe cada unha. |

O exemplo 02 (SaaS) é a excepción: AxonOps execútase en AxonOps Cloud, así que só
se aplican `AXONOPS_ORG_NAME` e a súa chave de axente; non hai bases de datos
locais ás que darlles contrasinais.

Os contrasinais viven en `.env`, que está no gitignore. Nunca suba ningún.

## Cal quero?

| | [00-axonops-platform](00-axonops-platform/) | [01-cassandra-cluster](01-cassandra-cluster/) | [02-saas-cassandra-cluster](02-saas-cassandra-cluster/) | [03-secure-3-rack-cluster](03-secure-3-rack-cluster/) | [04-cassandra-cluster-and-config](04-cassandra-cluster-and-config/) |
|---|---|---|---|---|---|
| **Úseo para** | executar AxonOps para clústeres que xa ten | ver o conxunto funcionando de extremo a extremo | monitorizar un clúster sen executar AxonOps | modelar un clúster con forma de produción e asegurado | manter as alertas en git no canto de na interface |
| AxonOps | autoaloxado | autoaloxado | SaaS | autoaloxado | autoaloxado |
| Cassandra | ningunha: traia a súa | 3 nodos, monitorizados | 3 nodos, monitorizados | 3 nodos, 3 racks, monitorizados | 1 nodo, monitorizado |
| Autenticación do clúster | — | desactivada | desactivada | `PasswordAuthenticator` | desactivada |
| Contedores | 4 | 7 | 3 | 7 | 5, máis un job de configuración dun só uso |
| RAM cos valores por defecto | ~10 GB | ~10 GB | ~5 GB | ~12 GB | ~6 GB |
| Panel | `localhost:3000` | `localhost:3000` | consola de AxonOps | `localhost:3000` | `localhost:3000` |
| Necesita | nada | nada | unha organización SaaS e unha chave de axente | nada | nada |

Empece polo **01** se está avaliando AxonOps e quere ver un clúster real aparecer
nun panel. Empece polo **00** se xa executa Cassandra ou Kafka e quere un sitio ao
que os seus axentes reporten. Empece polo **02** se ten unha conta de AxonOps
Cloud. Empece polo **03** se quere un clúster que se pareza a un despregamento
real —autenticación, un rack por nodo, enderezamento fixo e JMX remoto— ou se
está a portar a moi difundida
[pila de Compose Prometheus / Grafana / Reaper](https://github.com/crystalloide/cassandra-reaper)
na que se basea. Empece polo **04** se quere regras de alerta, comprobacións de
servizo e rutas de notificación definidas nun ficheiro e aplicadas por un
contedor, no canto de premidas no panel.

## Convencións

Todos os exemplos seguen a mesma forma:

```
<example>/
  docker-compose.yaml   Services, pinned to immutable version tags
  env.example           Every variable, with defaults, commented
  README.md             Quick start, configuration reference, troubleshooting
```

- **A configuración está só en `.env`**, e non fai falta editar ningún
  `docker-compose.yaml` para executalos. O exemplo 03 é a única excepción:
  reproduce un entorno de cliente que monta por bind o directorio de
  configuración de Cassandra dende o host, así que inclúe ademais un `setup.sh`
  que o crea e o enche.
- **As imaxes** veñen de `ghcr.io/axonops/*` ou de
  `registry.axonops.com/axonops-public/*`, fixadas a unha etiqueta de versión co
  digest SHA256 nun comentario enriba. Despregue o digest en produción: consulte
  [Fixar a imaxe: etiquetas fronte a sumas de verificación](00-axonops-platform/README.gl.md#fixar-a-imaxe-etiquetas-fronte-a-sumas-de-verificación)
  e [VERSIONS.md](../VERSIONS.md).
- **O dimensionamento** usa por defecto valores de desenvolvemento. Cada README
  indica que baixar.
- **TLS** protexe todo o que sae dun host. O tráfico dos axentes dentro dunha
  única rede de Compose vai en texto plano por deseño; o exemplo SaaS usa TLS de
  principio a fin.
- **Os segredos** viven en `.env`, que está no gitignore. Nunca suba ningún.

## Requisitos

- Docker Engine 20.10+ e Docker Compose V2
- Os requisitos de RAM, disco e portos de cada exemplo están no README dese exemplo

## Preguntas frecuentes

### Como actualizo `axon-server`, `axon-dash` e o axente?

Todas as imaxes destes ficheiros están fixadas a unha etiqueta de versión exacta,
así que `docker compose pull` por si só non lle trae nada novo: unha
actualización significa editar a etiqueta (ou o digest, se desprega a forma con
digest) e recrear ese único servizo. As etiquetas e digests actuais de cada
imaxe: [VERSIONS.md](../VERSIONS.md).

**Orde.** Primeiro os almacéns de datos se cambiaron, logo `axon-server`, logo
`axon-dash`, logo os axentes. Manteña `axon-server` e `axon-dash` en releases do
mesmo lote: o dash fala coa API do servidor, non ao revés, así que un dash máis
novo contra un servidor máis vello é a combinación que hai que evitar.

**`axon-server` e `axon-dash`.** Ambos están fixados directamente en
`docker-compose.yaml`, co digest nun comentario enriba da etiqueta:

```yaml
  axon-server:
    # Preferred (immutable): registry.axonops.com/…/axon-server@sha256:c75f6672…
    image: registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35
```

Cambie a etiqueta e o comentario do digest á vez —un comentario obsoleto a carón
dunha etiqueta nova é o xeito no que alguén despois desprega a imaxe
equivocada— e logo recree só ese servizo:

```bash
docker compose pull axon-server
docker compose up -d axon-server        # recreates only this container
docker compose logs -f axon-server      # watch it come up
docker compose ps                       # healthy?
```

Despois, os mesmos dous comandos para `axon-dash`. O exemplo 02 non ten ningún
dos dous: AxonOps Cloud execútaos e actualízaos por vostede, así que alí o axente
é o único que actualiza. Ambos son sen estado: todo vive en `axondb-timeseries` e
`axondb-search`, que non está a tocar, así que recrealos non perde datos. Os
axentes reconéctanse sós en canto o servidor volve.

**O axente.** Viaxa dentro da imaxe de Cassandra no canto de como o seu propio
contedor, e é o compoñente central da etiqueta:
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` é Cassandra 5.0.8 co
axente 2.0.31 da build 1.1.0. Actualizar o axente significa, polo tanto, pasar a
unha nova etiqueta de imaxe, que nos exemplos 01, 02 e 03 é `CASSANDRA_IMAGE` no
`.env`:

```bash
CASSANDRA_IMAGE=ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0
```

Recree os nodos **dun en un**, agardando a que cada un volva estar healthy antes
de comezar co seguinte, e drene primeiro para que o nodo deixe de aceptar
escrituras que perdería:

```bash
docker compose pull
docker compose exec cassandra-1 nodetool drain
docker compose up -d --no-deps cassandra-1
docker compose ps                            # wait for healthy, then the next node
docker compose exec cassandra-1 nodetool status
```

Os nodos son `cassandra-0`, `cassandra-1` e `cassandra-2` nos exemplos 01 e 02, e
`cassandra01`, `cassandra02` e `cassandra03` no exemplo 03.

Os datos sobreviven: están nun volume con nome (o exemplo 03 usa directorios do
host baixo `./docker/`), e recrear un contedor non elimina ningún dos dous. No
exemplo 00 non hai contedores de Cassandra que actualizar: os axentes execútanse
nos seus propios hosts, e alí actualízaos vostede.

**Cambiar a versión de Cassandra non é o mesmo.** Só o primeiro compoñente da
etiqueta é Cassandra en si, e movelo é unha actualización de base de datos de
verdade —snapshot, `nodetool upgradesstables` despois, notas da release
upstream—, non un cambio de imaxe. Para adoptar un axente ou unha build novos,
deixe a versión de Cassandra onde está e cambie só o segundo ou o terceiro
compoñente.

**Volver atrás** é a mesma operación coa etiqueta antiga: póñaa de novo e execute
outra vez `docker compose up -d <service>`.

### Como actualizo AxonOps sen tocar o clúster de Cassandra?

Actualizar AxonOps e actualizar Cassandra son operacións distintas. Todo o do
lado de AxonOps —`axondb-timeseries`, `axondb-search`, `axon-server`,
`axon-dash`— pode substituírse mentres o clúster segue funcionando, porque non se
recrea ningún contedor de Cassandra nin intervén ningún comando `nodetool`. Os
axentes son a única excepción: viaxan dentro da imaxe de Cassandra, así que
actualizar un axente si recrea un contedor de Cassandra (véxase máis arriba).

**Que ve o clúster.** Nada. Os axentes almacenan en memoria mentres `axon-server`
está caído e volcan cando volve; Cassandra nin sequera se entera de que a pila de
monitorización se reiniciou. Agarde un oco nas métricas durante o que dure o
reinicio, e teña en conta que as alertas que dependen da chegada de datos poden
dispararse: silencie primeiro as ruidosas se ten integracións conectadas.

**Antes de comezar.**

```bash
docker compose ps                       # note what is healthy now
docker compose config | grep image:     # record the tags you are moving away from
```

Faga copia de seguranza dos volumes de datos se a pila garda un histórico que lle
importa (`axondb-timeseries-data`, `axondb-search-data`, `axon-server-data` no
exemplo 00). Recrear un contedor non borra un volume con nome, pero volver atrás
é máis doado cunha copia.

**Orde.** As bases de datos, logo `axon-server`, logo `axon-dash`: as
dependencias primeiro, para que nada fale con algo máis vello ca si mesmo. Omita
calquera compoñente cuxa etiqueta non cambiase. Faga un servizo cada vez e
confirme que está healthy antes de pasar ao seguinte:

```bash
# 1. Edit docker-compose.yaml: new tag AND the digest comment above it
# 2. Then, per service:
docker compose pull <service>
docker compose up -d --no-deps <service>   # --no-deps: do not restart anything else
docker compose logs -f <service>
docker compose ps                          # healthy before moving on
```

Aquí `--no-deps` importa. Sen el, Compose pode reiniciar servizos ligados, o que
nos exemplos 01 e 03 arrastra os contedores de Cassandra a unha actualización que
vostede non pediu.

**Verifique, nesta orde:**

```bash
docker compose ps                       # all healthy
docker compose exec axon-server \
  curl -sf http://localhost:8080/api/v1/healthz
```

O porto da API de `axon-server` non se publica ao host nestes exemplos, e por iso
a comprobación execútase dentro do contedor: é a mesma sonda que usa o propio
healthcheck do servizo. Despois, abra o panel en `localhost:3000` e confirme que
todos os nodos seguen listados e que as métricas se retoman. Un nodo que apareza
como desconectado máis dun minuto ou dous despois de que o servidor estea healthy
significa que o axente non se reconectou: reinicie o contedor de Cassandra dese
axente o último, non o primeiro.

**Volver atrás** é o mesmo bucle coas etiquetas anteriores. As imaxes de base de
datos son o único compoñente no que volver atrás non sempre é seguro: unha
versión máis nova pode ter migrado o seu formato en disco, así que faga retroceder
`axondb-*` só sobre unha copia restaurada do volume, non sobre datos que unha
versión máis nova xa escribiu.

**Desfase de versións.** Manteña `axon-server` e `axon-dash` en releases do mesmo
lote. Os axentes son a parte tolerante: un axente máis vello reportando a un
servidor máis novo é normal e esperable durante un despregamento escalonado,
razón pola cal os axentes van os últimos e poden agardar por unha xanela de
mantemento do clúster.

## Cando algo non arranca

Cada README ten unha sección de resolución de problemas para a súa propia pila.
Hai unha clase de problema que convén coñecer de antemán: varias destas imaxes
aceptan configuración baixo nomes distintos dos que suxire a súa propia
documentación, e un nome equivocado ignórase en silencio no canto de rexeitarse.
Os tres atopados ata agora —en `axondb-search`, `axondb-timeseries` e
`axon-dash`— están documentados en
[variables de configuración que parecen correctas pero non o son](01-cassandra-cluster/README.gl.md#variables-de-configuración-que-parecen-correctas-pero-non-o-son),
co erro que produce cada unha.

## Soporte

Mantido por [AxonOps](https://axonops.com). Para soporte, contacte connosco en
[axonops.com/contact](https://axonops.com/contact).
