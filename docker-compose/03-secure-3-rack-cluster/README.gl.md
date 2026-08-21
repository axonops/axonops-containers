# Exemplo 03 — Un clúster asegurado de 3 racks, monitorizado por AxonOps

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Un clúster de Cassandra de tres nodos coa autenticación activada, JMX remoto
aberto, un rack por nodo e un enderezo fixo para cada contedor; e logo a
plataforma AxonOps completa monitorizándoo.

É un port dunha pila comunitaria moi difundida,
[crystalloide/cassandra-reaper](https://github.com/crystalloide/cassandra-reaper)
(«Cluster 3 noeuds 3 racks 1 DC Prometheus Grafana Reaper sécurisé»). O clúster
mantense tal e como estaba; Prometheus, Grafana, os tres sidecars
`cassandra_exporter` e Reaper substitúense por AxonOps, que cobre métricas,
rexistros, alertas e planificación de reparacións nun mesmo sitio.
[Que cambiou](#que-cambiou-respecto-da-pila-orixinal) enumera todas as
diferenzas.

- Quere o mesmo sen os axustes de seguridade nin o enderezamento estático?
  [Exemplo 01](../01-cassandra-cluster/): a pila autoaloxada máis sinxela.
- Ten unha conta de AxonOps Cloud? [Exemplo 02](../02-saas-cassandra-cluster/):
  un clúster que reporta a SaaS, sen plataforma que executar.

## Antes de comezar

Os tres nodos están fixados á etiqueta de versión completa
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`, non á flotante `5.0.8`.
Aquí iso importa máis ca nos demais exemplos.

A autenticación defínese con `CASSANDRA_AUTHENTICATOR` e `CASSANDRA_AUTHORIZER`,
que o entrypoint da imaxe aplica a `cassandra.yaml`. **As imaxes publicadas antes
da build 1.1.0 ignoran ambas as variables**: o clúster arranca, únese e aparece en
AxonOps exactamente como debe, e acepta calquera conexión sen contrasinal. Nada
nos rexistros o sinala.

Así que, se cambia `CASSANDRA_IMAGE`, manténao en 1.1.0 ou posterior, e comprobe
que obtivo realmente unha vez a pila estea levantada:

```bash
for n in cassandra01 cassandra02 cassandra03; do
  printf '%s: ' "$n"
  docker exec "$n" grep '^authenticator:' /opt/cassandra/conf/cassandra.yaml
done
# authenticator: PasswordAuthenticator   <- secured
# authenticator: AllowAllAuthenticator   <- image too old, see above
```

Comprobe todos os nodos, non só o primeiro. Un único nodo que quede cunha imaxe
que ignora `CASSANDRA_AUTHENTICATOR` únese ao clúster e acepta conexións sen
autenticar no seu propio porto CQL: o clúster só está tan asegurado como o seu
nodo menos asegurado.

## Inicio rápido

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
./setup.sh                   # create and seed ./docker/, once
docker compose up -d
docker compose ps            # wait for all seven services to report healthy
```

`setup.sh` non é opcional: os tres nodos len a súa configuración de directorios
do host baixo [`./docker/`](#almacenamento), e Cassandra non arranca contra un
baleiro.

Despois abra <http://localhost:3000>.

Un arranque en frío tarda de 6 a 10 minutos. Primeiro inicialízanse os dous
almacéns de datos de AxonOps, despois `axon-server` e o panel, e só entón o
clúster: dun nodo en un nodo, porque Cassandra arranca un só nodo cada vez.

Unha vez o clúster estea levantado, faga os
[dous pasos de seguridade posteriores ao arranque](#rematar-de-asegurar-o-clúster).
Cassandra vén cun superusuario por defecto de sobra coñecido e cun keyspace
`system_auth` que non sobrevive á perda dun nodo.

## Que executa

| Servizo | Enderezo | Imaxe | Propósito | Porto publicado |
|---------|---------|-------|---------|----------------|
| `cassandra01` | 10.17.64.5 | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Nodo do clúster, rack1 | `9142` CQL, `7199` JMX¹ |
| `cassandra02` | 10.17.64.6 | a mesma | Nodo do clúster, rack2 | `9242` CQL, `7299` JMX¹ |
| `cassandra03` | 10.17.64.7 | a mesma | Nodo do clúster, rack3 | `9342` CQL, `7399` JMX¹ |
| `axondb-timeseries` | 10.17.64.20 | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Almacén de métricas (Cassandra dun só nodo) | — |
| `axondb-search` | 10.17.64.21 | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Almacén de rexistros e eventos (OpenSearch) | — |
| `axon-server` | 10.17.64.22 | `axon-server:2.0.35` | Backend e endpoint dos axentes | `1888` |
| `axon-dash` | 10.17.64.23 | `axon-dash:2.0.37` | Panel web | `3000` |

¹ Ligados unicamente a `127.0.0.1`: véxase [JMX remoto](#jmx-remoto).

As etiquetas e digests actuais de cada imaxe: [VERSIONS.md](../../VERSIONS.md).

## O clúster

| | |
|---|---|
| Topoloxía | 1 datacenter, 3 racks, un nodo por rack |
| Snitch | `GossipingPropertyFileSnitch` |
| Enderezamento | Estático, na rede bridge `10.17.64.0/24` |
| Seeds | Os tres nodos |
| Tokens | 16 por nodo |
| Autenticación | `PasswordAuthenticator` |
| Autorización | `CassandraAuthorizer` |
| JMX | Remoto, sen autenticar, publicado só en localhost |
| Recolector de lixo | ZGC, no canto do G1 por defecto de Cassandra 5.0 |

**Por que enderezos estáticos.** JMX remoto precisa que
`java.rmi.server.hostname` apunte a un enderezo que un cliente poida alcanzar de
verdade, e o stub RMI que devolve un nodo leva ese enderezo. Un enderezo de
Docker asignado por DHCP cambia ao recrear o contedor, e o valor gravado en
`JVM_EXTRA_OPTS` apuntaría entón a outro sitio. Por iso a subrede está fixa en
`docker-compose.yaml` e non é unha variable: cambiala significa cambiar á vez as
sete entradas `ipv4_address`, `CASSANDRA_SEEDS`, `CASSANDRA_LISTEN_ADDRESS`,
`CASSANDRA_BROADCAST_RPC_ADDRESS` e `java.rmi.server.hostname`.

**Por que os tres nodos son seeds.** Herdado da pila orixinal. Está ben para un
clúster creado dende cero, que é o que é este: os seeds saltan o streaming de
bootstrap, e non hai nada que transmitir. Para un clúster que vaia facer medrar
despois, faga que os nodos novos non sexan seeds, para que arranquen
correctamente.

## Almacenamento

Os tres nodos do clúster gardan tanto os seus datos como a súa configuración en
directorios do host, non en volumes xestionados por Docker:

```
docker/cassandra01        ->  /var/lib/cassandra    data, plain bind mount
docker/cassandra01-conf   ->  /opt/cassandra/conf   configuration, a named
                                                    volume bound to the path
```

…e o mesmo para `cassandra02` e `cassandra03`. Os servizos da plataforma AxonOps
usan volumes con nome normais.

Ambas as rutas escríbense como `${PWD}/docker/…`, como na pila orixinal, así que
**execute `docker compose` dende este directorio**. Lanzalo doutro sitio con
`-f docker-compose/03-secure-3-rack-cluster/docker-compose.yaml` resolve `${PWD}`
a onde vostede estea e monta os directorios equivocados.

**Isto é deliberado, e non é o que escribiría dende cero.** Reproduce un entorno
de cliente, onde a configuración ten que ser editable no host e inspeccionable
despois de que o contedor desaparecese. Os custos son reais: os directorios non
son portables entre máquinas, `docker compose down -v` non os limpa, e en Linux a
súa propiedade debe coincidir coa do usuario `cassandra` da imaxe (uid 999) ou
Cassandra non poderá escribir. `setup.sh` encárgase da propiedade e avísao cando
non puido.

### setup.sh

```bash
./setup.sh              # create anything missing, seed configuration from the image
./setup.sh --force      # re-seed the configuration directories, discarding edits
./setup.sh --help
```

Enche cada directorio `-conf` a partir de `/opt/cassandra/conf` **dentro da imaxe
que está a piques de executar**, así que a configuración sempre coincide con esa
versión de Cassandra. Le `CASSANDRA_IMAGE` do `.env` se define unha alí.

Os directorios existentes déixanse en paz. Execúteo tantas veces como queira; só
`--force` sobrescribe, e só a configuración.

**Que fai realmente**, en orde:

1. **Analiza os argumentos**: `-f`/`--force` e `-h`/`--help`. Calquera outra cousa
   é un erro. `--help` imprime o comentario de cabeceira do propio script.
2. **Comproba Docker**: que `docker` estea no `PATH` e que o daemon sexa
   alcanzable. Sae antes de tocar o sistema de ficheiros se falla calquera das
   dúas cousas.
3. **Resolve a imaxe.** Busca con grep `CASSANDRA_IMAGE=` en `./.env` (gaña a
   última aparición, quitando as comiñas circundantes) e recorre ao valor por
   defecto compilado no script,
   `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`, que debe coincidir
   co valor por defecto de `docker-compose.yaml`. Non analiza o ficheiro de
   Compose.
4. **Descarga a imaxe se non está presente en local**, para que o paso de enchido
   seguinte non poida fallar por unha imaxe ausente.
5. **Para cada un de `cassandra01`, `cassandra02` e `cassandra03`:**
   - Crea `docker/<node>/` (o directorio de datos) se non existe, e dío. Un xa
     existente non se toca nunca: os seus datos están a salvo.
   - Enche `docker/<node>-conf/` agás que xa conteña un `cassandra.yaml` e non se
     pasase `--force`. Enchelo é `docker create` sobre a imaxe (un contedor que
     nunca se arranca), `docker cp <container>:/opt/cassandra/conf/.` ao
     directorio, e logo `docker rm -f`. O directorio bórrase e créase de novo
     primeiro, así que `--force` **descarta todas as edicións locais que haxa
     nel**.
   - Tenta un `chown -R 999:999` sobre ambos os directorios: o uid/gid do usuario
     `cassandra` da imaxe.
6. **Imprime que facer a continuación** (`cp env.example .env`,
   `docker compose up -d`).

O `chown` é de mellor esforzo. En Docker Desktop (macOS, Windows) falla e iso é o
esperado: a capa de compartición de ficheiros mapea a propiedade por vostede. En
Linux un fallo é real, e o script avisa co comando exacto
`sudo chown -R 999:999 docker/` que hai que executar. Todo o demais é fatal: o
script é `set -euo pipefail`, así que un daemon inalcanzable, unha imaxe que non
se pode descargar ou un `docker cp` fallido detéñeno cunha liña `error:` no canto
de deixar atrás un directorio a medio encher.

Nunca escribe `.env`, nunca edita `docker-compose.yaml` e nunca arranca un
contedor.

### Editar a configuración

Todo o que as variables de entorno non cubran, éditeo directamente no host e
reinicie o nodo:

```bash
$EDITOR docker/cassandra01-conf/cassandra.yaml
docker compose restart cassandra01
```

Dúas cousas que convén saber antes de facelo:

- **As variables de entorno gañan.** En cada arranque, o entrypoint reescribe
  `cluster_name`, `authenticator`, `authorizer`, `listen_address`,
  `broadcast_rpc_address`, os seeds, `endpoint_snitch`, `num_tokens`,
  `native_transport_port`, e `dc`/`rack` en `cassandra-rackdc.properties`, a
  partir dos valores de `docker-compose.yaml`. Editar esas chaves no host non ten
  efecto. Todo o demais que edite consérvase.
- **`cassandra-env.sh` gaña unha liña.** O entrypoint engade
  `. /usr/share/axonops/axonops-jvm.options` para que se cargue o axente Java de
  AxonOps. Compróbao antes, así que un reinicio non a engade dúas veces.

### Mantelo fóra de git

`docker/` está no gitignore. Cassandra reescribe partes da configuración en tempo
de execución, así que subila produce ruído constante, e os directorios de datos
son grandes. Se quere a configuración dun cliente no control de versións, suba os
ficheiros concretos de forma deliberada con `git add -f`.

## Rematar de asegurar o clúster

Dúas cousas que Cassandra non pode facer por vostede. Faga ambas unha vez os tres
nodos estean levantados (`docker compose ps` amósaos todos healthy).

**1. Replicación de `system_auth`.** Créase con `SimpleStrategy` e factor de
replicación 1, así que a caída dun só nodo lévase por diante os inicios de
sesión. Súbao a unha réplica por rack:

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra -e \
  "ALTER KEYSPACE system_auth WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 3}"

docker exec cassandra01 nodetool repair -full system_auth
docker exec cassandra02 nodetool repair -full system_auth
docker exec cassandra03 nodetool repair -full system_auth
```

Use o seu propio valor se cambiou `CASSANDRA_DC`.

**2. O superusuario por defecto.** Cassandra crea `cassandra` / `cassandra` no
primeiro arranque coa autenticación activada. É de dominio público. Substitúao:

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra
```

```sql
CREATE ROLE admin WITH PASSWORD = 'a-password-you-choose'
  AND SUPERUSER = true AND LOGIN = true;
```

Volva conectarse como `admin` e deixe a conta por defecto fóra de uso:

```sql
ALTER ROLE cassandra WITH PASSWORD = 'a-long-random-string-nobody-keeps'
  AND SUPERUSER = false;
```

O axente de AxonOps non precisa ningunha destas credenciais. Recompila a través
do axente Java en proceso e de JMX, non de CQL, así que a autenticación do
clúster non afecta á monitorización.

## JMX remoto

`LOCAL_JMX=no` abre JMX á rede, que é o que facía a pila orixinal para que Reaper
puidese lanzar reparacións. AxonOps non o precisa —o axente execútase dentro do
contedor—, así que está aquí só para ferramentas externas como `jmxterm`,
`nodetool` dende outro host ou un profiler da JVM.

`cassandra-env.sh` activa a autenticación de JMX sempre que `LOCAL_JMX=no`, e iso
precisa un ficheiro `jmxremote.password` que esta imaxe non inclúe, así que
`JVM_EXTRA_OPTS` define `-Dcom.sun.management.jmxremote.authenticate=false`.
Funciona porque `JVM_EXTRA_OPTS` engádese o último e gaña o último `-D` dunha
propiedade de sistema repetida.

O resultado é un **porto JMX sen autenticar con control total sobre o nodo**: JMX
pode cambiar o esquema, drenar e decomisionar. Os portos publícanse só a
`127.0.0.1`, así que nada de fóra do host pode alcanzalos:

```yaml
ports:
  - "127.0.0.1:7199:7199"
```

Non quite o prefixo `127.0.0.1:`. Se precisa JMX remoto de verdade, configure
antes
[a autenticación de JMX](https://cassandra.apache.org/doc/stable/cassandra/operating/security.html#jmx-access)
cun ficheiro de contrasinais e TLS. Para quitar JMX remoto por completo, elimine
`LOCAL_JMX=no`, os dous flags `-D` e as liñas de portos JMX; todo o demais deste
exemplo segue funcionando.

## Configuración

Todo se define no `.env`. Lista completa cos valores por defecto:
[`env.example`](env.example).

| Variable | Valor por defecto | Descrición |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Nome da organización; os axentes usan o mesmo valor |
| `AXONOPS_LICENSE_KEY` | (baleiro) | Chave de licenza; baleiro executa en modo de proba |
| `AXONOPS_DB_PASSWORD` | `axonops` | Contrasinal de `axondb-timeseries` |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | Contrasinal de administración de `axondb-search` |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `2G` | Heap de `axondb-timeseries` |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `2g` | Heap de `axondb-search` |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS de `axon-server` a `axondb-search` |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS de `axon-server` a `axondb-timeseries` |
| `CASSANDRA_CLUSTER_NAME` | `secure-cluster` | Nome do clúster amosado en AxonOps |
| `CASSANDRA_DC` | `dc1` | Nome do datacenter |
| `CASSANDRA_IMAGE` | `…/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Imaxe dos tres nodos: 1.1.0 ou posterior, véxase [Antes de comezar](#antes-de-comezar) |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap por nodo do clúster |
| `CASSANDRA_MEM_LIMIT` | `2g` | Límite de memoria do contedor por nodo |
| `CASSANDRA_CPUS` | `2.0` | Límite de CPU por nodo |

Os nomes de rack, os enderezos e a subrede están fixados en
`docker-compose.yaml` porque dependen uns dos outros; véxase
[O clúster](#o-clúster).

`axon-server` configúrase por completo mediante variables de entorno: non hai
ningún ficheiro de configuración que montar nin renderizar. A correspondencia
completa está no
[exemplo 01](../01-cassandra-cluster/README.gl.md#configuración).

## Operación

```bash
docker compose ps                          # health of every service
docker compose logs -f cassandra01         # follow one node
docker exec cassandra01 nodetool status    # cluster view, racks and ownership
docker compose down                        # stop, keep data
docker compose down -v                     # stop and delete all volumes
```

Conéctese con CQL dende o host: cada nodo publica o seu propio porto.

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra
cqlsh 127.0.0.1 9142 -u cassandra -p cassandra    # if you have cqlsh locally
```

`nodetool status` debería amosar tres nodos `UN`, un por rack. Se falta un rack,
ese nodo non leu `cassandra-rackdc.properties` como se agardaba: revise
`CASSANDRA_DC` e `CASSANDRA_RACK` no seu entorno.

### Saúde dos nodos do clúster

Os tres nodos usan a comprobación de saúde que trae a imaxe,
`/usr/local/bin/axonops-healthcheck.sh`, no canto dunha escrita aquí. Verifica
que Cassandra está a servir CQL e que o proceso `axon-agent` está en execución;
un nodo cuxo axente morreu segue respondendo consultas pero deixou de estar
monitorizado en silencio.

**Que fai realmente.** Dúas comprobacións independentes, unha liña de saída cada
unha e un único código de saída:

1. **Cassandra.** `nodetool statusbinary` debe imprimir `running`, e o porto CQL
   debe estar escoitando (`ss -ln`). O porto lese do `native_transport_port` de
   `cassandra.yaml`, con `9042` por defecto: así segue o porto que vostede defina
   no canto de supor un. Que falle calquera das dúas cousas remata con código
   distinto de cero, que é o que volve unhealthy o contedor.
   (Nas imaxes de K8ssandra, onde está presente a Management API de DataStax,
   úsase no seu lugar o seu endpoint `/api/v0/probes/liveness`, a mesma sonda na
   que se apoia o operador de K8ssandra. Estes tres nodos usan a imaxe de
   Cassandra sen máis, así que a vía que se executa é a de `nodetool`.)
2. **O axente de AxonOps.** Percorre `/proc/<pid>/cmdline` buscando
   `/usr/share/axonops/axon-agent` (pódese cambiar con `AXON_AGENT_BIN`). Le
   `/proc` directamente no canto de usar `pgrep`, que non está garantido que
   exista na imaxe base UBI.

Un axente caído reflíctese na saída da comprobación, pero por si só non volve
unhealthy o contedor, porque facer fallar a comprobación pode levar a un
orquestrador a reiniciar ou baleirar un nodo que segue servindo. Poña
`HEALTHCHECK_REQUIRE_AGENT=true` nun nodo para tratalo como un fallo: iso é o
único que cambia a variable; o axente compróbase e repórtase en calquera caso.

```bash
# Run it by hand — the output names which of the two checks failed
docker exec cassandra01 /usr/local/bin/axonops-healthcheck.sh

# What Docker last saw
docker inspect --format '{{.State.Health.Status}}' cassandra01
docker inspect --format '{{(index .State.Health.Log 0).Output}}' cassandra01
```

Compose execútaa cada 15 s cun timeout de 10 s, 20 reintentos e un período de
arranque de 120 s. O axente só arranca unha vez Cassandra está levantada, así que
normalmente está ausente durante parte dese período de arranque, que é para o que
está. Nun nodo lento con `HEALTHCHECK_REQUIRE_AGENT=true`, suba `start_period` no
canto de baixar `retries`.

Tanto a comprobación do axente como `HEALTHCHECK_REQUIRE_AGENT` están na imaxe
fixada, `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`. En calquera
imaxe anterior o script verifica só Cassandra e a variable non ten efecto.

Os datos e a configuración do clúster viven baixo `./docker/` no host: véxase
[Almacenamento](#almacenamento). `docker compose down -v` elimina os volumes de
AxonOps pero deixa eses directorios; bórreos a man para arrancar o clúster dende
cero.

## Requisitos

- Docker Engine 20.10+ e Compose V2
- 12 GB de RAM libres cos valores por defecto, 16 GB recomendados; 30 GB de
  disco, a maior parte baixo `./docker/`
- A subrede `10.17.64.0/24` libre no host
- Portos 3000, 1888, 9142, 9242 e 9342 libres, e 7199, 7299 e 7399 en localhost

Para unha máquina máis pequena, baixe os heaps no `.env`:

```bash
CASSANDRA_HEAP_SIZE=1G
CASSANDRA_MEM_LIMIT=2g
AXONOPS_CASSANDRA_HEAP_SIZE=2G
AXONOPS_OPENSEARCH_HEAP_SIZE=2g
```

## Que cambiou respecto da pila orixinal

| Orixinal | Aquí | Por que |
|----------|------|-----|
| Prometheus, Grafana, 3× `cassandra_exporter`, Reaper | `axondb-timeseries`, `axondb-search`, `axon-server`, `axon-dash` | O sentido do port. Métricas, rexistros, alertas e planificación de reparacións nunha soa plataforma, e ningún sidecar de exportador JMX que configurar |
| `cassandra:5.0.8` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | A mesma Cassandra, co axente de AxonOps e o axente Java xa instalados |
| Bind mounts baixo `${PWD}/docker/` | Mantéñense | Reproduce o entorno do cliente. `setup.sh` créaos e énchéos: véxase [Almacenamento](#almacenamento) |
| Volumes `conf` montados por bind | Mantéñense | A mesma razón. A imaxe pode gobernarse enteiramente con variables de entorno, pero así a configuración é editable no host |
| `7000` e `7001` publicados por nodo | Non se publican | Son portos internodo; nada fóra da rede de Compose os usa |
| `7199` JMX publicado en todas as interfaces | Publicado só en `127.0.0.1` | O porto non está autenticado. Véxase [JMX remoto](#jmx-remoto) |
| Healthcheck de `cqlsh` con credenciais incrustadas | O propio `axonops-healthcheck.sh` da imaxe | A imaxe inclúe `cqlai` e `cqlsh`, e a comprobación non precisa credenciais. Verifica ademais que o `axon-agent` está vivo: véxase [Saúde dos nodos do clúster](#saúde-dos-nodos-do-clúster) |
| Contrasinais no YAML | No `.env`, no gitignore | Nada segredo nun ficheiro subido |
| `restart: always` | `restart: unless-stopped` | Coincide cos demais exemplos; un contedor que vostede parou queda parado |
| `CASSANDRA_OPEN_JMX`, `JMXPORT` | Eliminadas | Nin Cassandra nin a imaxe as len: tampouco facían nada no orixinal |

Mantéñense tal e como estaban: a subrede e todos os enderezos, a disposición de
clúster e racks, a lista de seeds, `GossipingPropertyFileSnitch`,
`PasswordAuthenticator`, `CassandraAuthorizer`, `LOCAL_JMX=no`, os flags de ZGC,
os ulimits `memlock` e `nofile`, a disposición de almacenamento en `./docker/`
para datos e configuración, e os números de porto CQL publicados.

## Resolución de problemas

**`authenticator: AllowAllAuthenticator` despois de arrancar.**
`CASSANDRA_IMAGE` apunta a unha imaxe anterior á build 1.1.0, previa ao soporte
do entrypoint para `CASSANDRA_AUTHENTICATOR`. Véxase
[Antes de comezar](#antes-de-comezar).

**`Provided username cassandra and/or password are incorrect` xusto despois de
que o clúster arranque.** O superusuario por defecto créase uns segundos despois
de que o primeiro nodo remate de arrancar, non durante o arranque. Agarde por
`Created default superuser role 'cassandra'` e reinténteo:

```bash
docker compose logs cassandra01 | grep "default superuser"
```

**`Expecting URI in variable: [cassandra.config]. Found[cassandra.yaml]`, con
`sed: can't read /opt/cassandra/conf/cassandra.yaml` enriba.** O nodo ten un
directorio de configuración baleiro. Ou ben nunca se executou `setup.sh`, ou ben
o bind mount non se resolve ao directorio que vostede cre. Comprobe que ve
realmente o contedor:

```bash
docker run --rm -v "$PWD/docker/cassandra01-conf:/x" busybox ls /x | wc -l
```

Cero significa que Docker creou un directorio baleiro no canto de compartir o
seu: en Docker Desktop, unha ruta fóra da lista de compartición de ficheiros
configurada fai exactamente iso. Mova o proxecto a unha ruta compartida, ou
engada a ruta en Docker Desktop en Settings → Resources → File sharing.

**`Permission denied` ao escribir no directorio de configuración ou de datos
(Linux).** Os directorios deben ser escribibles polo uid 999, o usuario
`cassandra` da imaxe:

```bash
sudo chown -R 999:999 docker/
```

`setup.sh` téntao e avisa cando non pode. Docker Desktop en macOS e Windows mapea
a propiedade por vostede, así que isto só afecta aos hosts Linux.

**Un nodo nunca chega a estar healthy.** Os nodos arrancan en secuencia, así que
un arranque en frío tarda varios minutos. Observe
`docker compose logs -f cassandra02`. Se queda atascado no gossip, confirme que
os enderezos dos seeds coinciden coas entradas `ipv4_address`.

**`Cannot assign requested address` ou un conflito de subrede no `up`.** Algo máis
no host usa `10.17.64.0/24`, a miúdo outra rede de Docker. Compróbeo con
`docker network ls` e `ip route`, e logo elimine a rede en conflito ou edite a
subrede e os sete enderezos á vez.

**`nodetool status` amosa menos de tres nodos.** Comprobe que o nodo que falta
chegou a arrancar (`docker compose ps`), e logo busque unha discrepancia no nome
do clúster: un nodo que se uniu cun `CASSANDRA_CLUSTER_NAME` distinto nunha
execución anterior consérvao no seu directorio de datos. Aquí
`docker compose down -v` **non** o limpa, porque os datos son un bind mount do
host: elimine `docker/cassandra0*/` a man.

**JMX dende outro host dá timeout.** É o esperado: os portos están ligados a
`127.0.0.1`. Véxase [JMX remoto](#jmx-remoto).

**Cassandra rexistra `Invalid or unsupported protocol version (22)` e
`axon-server` rexistra `tls: first record does not look like a TLS handshake`.**
Un lado está a usar TLS e o outro non; 22 é `0x16`, o primeiro byte dun
ClientHello de TLS lido como unha versión de protocolo CQL. Deixe
`AXONOPS_CASSANDRA_SSL=false` a menos que teña montado un keystore en
`axondb-timeseries`.

**Outros axustes que parecen correctos pero se ignoran.** Tres destas imaxes
admiten configuración baixo nomes distintos dos que suxiren os seus propios
READMEs, e cada unha falla sen nomear a variable culpable. O exemplo 01 documenta
as tres:
[variables de configuración que parecen correctas pero non o son](../01-cassandra-cluster/README.gl.md#variables-de-configuración-que-parecen-correctas-pero-non-o-son).

## Licenzas

AxonOps require licenza para uso en produción: <https://axonops.com>. A pila
funciona sen chave de licenza en modo de proba, o que abonda para a avaliación.

## Soporte

Mantido por [AxonOps](https://axonops.com). Para soporte, contacte connosco en
[axonops.com/contact](https://axonops.com/contact).
