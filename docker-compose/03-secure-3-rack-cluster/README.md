# Example 03 — A secured 3-rack cluster, monitored by AxonOps

**English** | [Français](README.fr.md) | [Español](README.es.md) | [Galego](README.gl.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

A three-node Cassandra cluster with authentication on, remote JMX open, one rack
per node and a fixed address for every container — then the whole AxonOps
platform monitoring it.

This is a port of a widely-shared community stack,
[crystalloide/cassandra-reaper](https://github.com/crystalloide/cassandra-reaper)
("Cluster 3 noeuds 3 racks 1 DC Prometheus Grafana Reaper sécurisé"). The
cluster is kept as it was; Prometheus, Grafana, the three `cassandra_exporter`
sidecars and Reaper are replaced by AxonOps, which covers metrics, logs,
alerting and repair scheduling in one place. [What changed](#what-changed-from-the-original-stack)
lists every difference.

- Want the same thing without the security settings and static addressing?
  [Example 01](../01-cassandra-cluster/) — the simplest self-hosted stack.
- Have an AxonOps Cloud account? [Example 02](../02-saas-cassandra-cluster/) —
  a cluster reporting to SaaS, no platform to run.

## Before you start

The three nodes are pinned to the full version tag
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`, not to the floating
`5.0.8`. That matters here more than in the other examples.

Authentication is set with `CASSANDRA_AUTHENTICATOR` and `CASSANDRA_AUTHORIZER`,
which the image entrypoint applies to `cassandra.yaml`. **Images published
before the 1.1.0 build ignore both variables**: the cluster starts, joins and
appears in AxonOps exactly as it should, and accepts every connection without a
password. Nothing in the logs calls this out.

So if you change `CASSANDRA_IMAGE`, keep it at 1.1.0 or later, and check what
you actually got once the stack is up:

```bash
for n in cassandra01 cassandra02 cassandra03; do
  printf '%s: ' "$n"
  docker exec "$n" grep '^authenticator:' /opt/cassandra/conf/cassandra.yaml
done
# authenticator: PasswordAuthenticator   <- secured
# authenticator: AllowAllAuthenticator   <- image too old, see above
```

Check every node, not just the first. A single node left on an image that
ignores `CASSANDRA_AUTHENTICATOR` joins the cluster and accepts unauthenticated
connections on its own CQL port — the cluster is only as secured as its least
secured node.

## Quick start

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
./setup.sh                   # create and seed ./docker/, once
docker compose up -d
docker compose ps            # wait for all seven services to report healthy
```

`setup.sh` is not optional: the three nodes read their configuration from host
directories under [`./docker/`](#storage), and Cassandra will not start against
an empty one.

Then open <http://localhost:3000>.

A cold start takes 6–10 minutes. The two AxonOps data stores initialise first,
then `axon-server` and the dashboard, and only then the cluster — one node at a
time, because Cassandra bootstraps a single node at a time.

Once the cluster is up, do the [two post-start security steps](#finish-securing-the-cluster).
Cassandra ships with a well-known default superuser and a `system_auth` keyspace
that does not survive losing a node.

## What it runs

| Service | Address | Image | Purpose | Published port |
|---------|---------|-------|---------|----------------|
| `cassandra01` | 10.17.64.5 | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Cluster node, rack1 | `9142` CQL, `7199` JMX¹ |
| `cassandra02` | 10.17.64.6 | same | Cluster node, rack2 | `9242` CQL, `7299` JMX¹ |
| `cassandra03` | 10.17.64.7 | same | Cluster node, rack3 | `9342` CQL, `7399` JMX¹ |
| `axondb-timeseries` | 10.17.64.20 | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Metrics store (single-node Cassandra) | — |
| `axondb-search` | 10.17.64.21 | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Log and event store (OpenSearch) | — |
| `axon-server` | 10.17.64.22 | `axon-server:2.0.35` | Backend and agent endpoint | `1888` |
| `axon-dash` | 10.17.64.23 | `axon-dash:2.0.37` | Web dashboard | `3000` |

¹ Bound to `127.0.0.1` only — see [Remote JMX](#remote-jmx).

Current tags and digests for every image: [VERSIONS.md](../../VERSIONS.md).

## The cluster

| | |
|---|---|
| Topology | 1 datacentre, 3 racks, one node per rack |
| Snitch | `GossipingPropertyFileSnitch` |
| Addressing | Static, on the `10.17.64.0/24` bridge network |
| Seeds | All three nodes |
| Tokens | 16 per node |
| Authentication | `PasswordAuthenticator` |
| Authorization | `CassandraAuthorizer` |
| JMX | Remote, unauthenticated, published on localhost only |
| Garbage collector | ZGC, replacing the Cassandra 5.0 default of G1 |

**Why static addresses.** Remote JMX needs `java.rmi.server.hostname` set to an
address a client can actually reach, and the RMI stub a node hands back carries
that address. A DHCP-assigned Docker address changes on recreate and the value
baked into `JVM_EXTRA_OPTS` would then point somewhere else. The subnet is
therefore fixed in `docker-compose.yaml`, not a variable: changing it means
changing the seven `ipv4_address` entries, `CASSANDRA_SEEDS`,
`CASSANDRA_LISTEN_ADDRESS`, `CASSANDRA_BROADCAST_RPC_ADDRESS` and
`java.rmi.server.hostname` together.

**Why all three nodes are seeds.** Carried over from the original stack. It is
fine for a cluster created from empty, which is what this is: seeds skip
bootstrap streaming, and there is nothing to stream. For a cluster you grow
later, make the new nodes non-seeds so they bootstrap properly.

## Storage

The three cluster nodes keep both their data and their configuration in host
directories, not in Docker-managed volumes:

```
docker/cassandra01        ->  /var/lib/cassandra    data, plain bind mount
docker/cassandra01-conf   ->  /opt/cassandra/conf   configuration, a named
                                                    volume bound to the path
```

…and the same for `cassandra02` and `cassandra03`. The AxonOps platform services
use ordinary named volumes.

Both paths are written as `${PWD}/docker/…`, as in the original stack, so **run
`docker compose` from this directory**. Driving it from elsewhere with
`-f docker-compose/03-secure-3-rack-cluster/docker-compose.yaml` resolves `${PWD}`
to wherever you are and mounts the wrong directories.

**This is deliberate, and it is not what you would write from scratch.** It
reproduces a customer environment, where the configuration has to be editable on
the host and inspectable after the container is gone. The costs are real: the
directories are not portable between machines, `docker compose down -v` does not
clean them up, and on Linux their ownership has to match the `cassandra` user in
the image (uid 999) or Cassandra cannot write. `setup.sh` handles the ownership
and tells you when it could not.

### setup.sh

```bash
./setup.sh              # create anything missing, seed configuration from the image
./setup.sh --force      # re-seed the configuration directories, discarding edits
./setup.sh --help
```

It seeds each `-conf` directory from `/opt/cassandra/conf` **inside the image
you are about to run**, so the configuration always matches that Cassandra
version. It reads `CASSANDRA_IMAGE` from `.env` if you set one there.

Existing directories are left alone. Run it as often as you like; only `--force`
overwrites, and only the configuration.

**What it actually does**, in order:

1. **Parses the arguments** — `-f`/`--force` and `-h`/`--help`. Anything else is
   an error. `--help` prints the header comment of the script itself.
2. **Checks Docker** — `docker` on `PATH` and the daemon reachable. It exits
   before touching the filesystem if either fails.
3. **Resolves the image.** It greps `CASSANDRA_IMAGE=` out of `./.env` (last
   occurrence wins, surrounding quotes stripped) and falls back to the default
   compiled into the script,
   `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` — which must match
   the default in `docker-compose.yaml`. It does not parse the compose file.
4. **Pulls the image if it is not present locally**, so the seeding step below
   cannot fail on a missing image.
5. **For each of `cassandra01`, `cassandra02`, `cassandra03`:**
   - Creates `docker/<node>/` (the data directory) if it does not exist, and
     says so. An existing one is never touched — your data is safe.
   - Seeds `docker/<node>-conf/` unless it already contains a `cassandra.yaml`
     and `--force` was not given. Seeding is `docker create` on the image (a
     container that is never started), `docker cp <container>:/opt/cassandra/conf/.`
     into the directory, then `docker rm -f`. The directory is deleted and
     recreated first, so `--force` **discards every local edit in it**.
   - Attempts `chown -R 999:999` on both directories — uid/gid of the
     `cassandra` user in the image.
6. **Prints what to do next** (`cp env.example .env`, `docker compose up -d`).

The `chown` is best-effort. On Docker Desktop (macOS, Windows) it fails and that
is expected — the file-sharing layer maps ownership for you. On Linux a failure
is real, and the script warns with the exact `sudo chown -R 999:999 docker/`
command to run. Everything else is fatal: the script is `set -euo pipefail`, so
an unreachable daemon, an unpullable image or a failed `docker cp` stops it with
an `error:` line rather than leaving a half-seeded directory behind.

It never writes `.env`, never edits `docker-compose.yaml`, and never starts a
container.

### Editing the configuration

Anything the environment variables do not cover, edit directly on the host and
restart the node:

```bash
$EDITOR docker/cassandra01-conf/cassandra.yaml
docker compose restart cassandra01
```

Two things to know before you do:

- **The environment variables win.** On every start the entrypoint rewrites
  `cluster_name`, `authenticator`, `authorizer`, `listen_address`,
  `broadcast_rpc_address`, seeds, `endpoint_snitch`, `num_tokens`,
  `native_transport_port`, and `dc`/`rack` in `cassandra-rackdc.properties`, from
  the values in `docker-compose.yaml`. Editing those keys on the host has no
  effect. Everything else you edit is kept.
- **`cassandra-env.sh` gains a line.** The entrypoint appends
  `. /usr/share/axonops/axonops-jvm.options` so the AxonOps Java agent loads. It
  checks first, so a restart does not add it twice.

### Keeping it out of git

`docker/` is gitignored. Cassandra rewrites parts of the configuration at
runtime, so committing it produces constant churn, and the data directories are
large. If you want a customer's configuration in version control, commit the
specific files deliberately with `git add -f`.

## Finish securing the cluster

Two things Cassandra cannot do for you. Run both once the three nodes are up
(`docker compose ps` shows all healthy).

**1. `system_auth` replication.** It is created with `SimpleStrategy` and
replication factor 1, so a single node going down takes logins with it. Raise it
to one replica per rack:

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra -e \
  "ALTER KEYSPACE system_auth WITH replication = {'class': 'NetworkTopologyStrategy', 'dc1': 3}"

docker exec cassandra01 nodetool repair -full system_auth
docker exec cassandra02 nodetool repair -full system_auth
docker exec cassandra03 nodetool repair -full system_auth
```

Use your own value if you changed `CASSANDRA_DC`.

**2. The default superuser.** Cassandra creates `cassandra` / `cassandra` on
first start with authentication enabled. It is public knowledge. Replace it:

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra
```

```sql
CREATE ROLE admin WITH PASSWORD = 'a-password-you-choose'
  AND SUPERUSER = true AND LOGIN = true;
```

Reconnect as `admin`, then take the default account out of use:

```sql
ALTER ROLE cassandra WITH PASSWORD = 'a-long-random-string-nobody-keeps'
  AND SUPERUSER = false;
```

The AxonOps agent needs none of these credentials. It collects through the
in-process Java agent and JMX, not CQL, so authentication on the cluster does
not affect monitoring.

## Remote JMX

`LOCAL_JMX=no` opens JMX to the network, which is what the original stack did so
Reaper could drive repairs. AxonOps does not need it — the agent runs inside the
container — so it is here only for external tools such as `jmxterm`,
`nodetool` from another host, or a JVM profiler.

`cassandra-env.sh` turns on JMX authentication whenever `LOCAL_JMX=no`, and that
needs a `jmxremote.password` file this image does not ship, so `JVM_EXTRA_OPTS`
sets `-Dcom.sun.management.jmxremote.authenticate=false`. It works because
`JVM_EXTRA_OPTS` is appended last and the last `-D` of a repeated system
property wins.

The result is an **unauthenticated JMX port with full control over the node** —
JMX can change schema, drain, and decommission. The ports are published to
`127.0.0.1` only, so nothing outside the host can reach them:

```yaml
ports:
  - "127.0.0.1:7199:7199"
```

Do not remove the `127.0.0.1:` prefix. If you need remote JMX for real, set up
[JMX authentication](https://cassandra.apache.org/doc/stable/cassandra/operating/security.html#jmx-access)
with a password file and TLS first. To drop remote JMX entirely, delete
`LOCAL_JMX=no`, the two `-D` flags and the JMX port lines; everything else in
this example keeps working.

## Configuration

Everything is set in `.env`. Full list with defaults: [`env.example`](env.example).

| Variable | Default | Description |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Organisation name; agents use the same value |
| `AXONOPS_LICENSE_KEY` | (empty) | License key; empty runs in trial mode |
| `AXONOPS_DB_PASSWORD` | `axonops` | `axondb-timeseries` password |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | `axondb-search` admin password |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `2G` | `axondb-timeseries` heap |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `2g` | `axondb-search` heap |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS from `axon-server` to `axondb-search` |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS from `axon-server` to `axondb-timeseries` |
| `CASSANDRA_CLUSTER_NAME` | `secure-cluster` | Cluster name shown in AxonOps |
| `CASSANDRA_DC` | `dc1` | Datacentre name |
| `CASSANDRA_IMAGE` | `…/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Image for the three nodes — 1.1.0 or later, see [Before you start](#before-you-start) |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap per cluster node |
| `CASSANDRA_MEM_LIMIT` | `2g` | Container memory limit per node |
| `CASSANDRA_CPUS` | `2.0` | CPU limit per node |

Rack names, addresses and the subnet are fixed in `docker-compose.yaml` because
they depend on each other; see [The cluster](#the-cluster).

`axon-server` is configured entirely through environment variables — there is no
config file to mount or render. The full mapping is in
[example 01](../01-cassandra-cluster/README.md#configuration).

## Operations

```bash
docker compose ps                          # health of every service
docker compose logs -f cassandra01         # follow one node
docker exec cassandra01 nodetool status    # cluster view, racks and ownership
docker compose down                        # stop, keep data
docker compose down -v                     # stop and delete all volumes
```

Connect with CQL from the host — each node publishes its own port:

```bash
docker exec -it cassandra01 cqlai -u cassandra -p cassandra
cqlsh 127.0.0.1 9142 -u cassandra -p cassandra    # if you have cqlsh locally
```

`nodetool status` should show three nodes `UN`, one per rack. If a rack is
missing, that node did not read `cassandra-rackdc.properties` as expected —
check `CASSANDRA_DC` and `CASSANDRA_RACK` in its environment.

### Health of the cluster nodes

The three nodes use the healthcheck the image ships,
`/usr/local/bin/axonops-healthcheck.sh`, rather than a check written here. It
verifies that Cassandra is serving CQL and that the `axon-agent` process is
running — a node whose agent has died still answers queries but has quietly
stopped being monitored.

**What it actually does.** Two independent checks, one line of output each, and
one exit code:

1. **Cassandra.** `nodetool statusbinary` must print `running`, and the CQL port
   must be listening (`ss -ln`). The port is read out of
   `cassandra.yaml`'s `native_transport_port`, defaulting to `9042` — so it
   follows the port you set rather than assuming one. Either failing exits
   non-zero, which is what makes the container unhealthy.
   (In the K8ssandra images, where the DataStax Management API is present, its
   `/api/v0/probes/liveness` endpoint is used instead — the same probe the
   K8ssandra Operator relies on. These three nodes use the plain Cassandra image,
   so the `nodetool` path is the one that runs.)
2. **The AxonOps agent.** It walks `/proc/<pid>/cmdline` looking for
   `/usr/share/axonops/axon-agent` (override with `AXON_AGENT_BIN`). `/proc` is
   read directly rather than with `pgrep`, which is not guaranteed to exist in
   the UBI base image.

A dead agent is reported in the check output but does not by itself make the
container unhealthy, because failing the check can make an orchestrator restart
or drain a node that is still serving. Set `HEALTHCHECK_REQUIRE_AGENT=true` on a
node to treat it as a failure — that is the only thing the variable changes; the
agent is checked and reported either way.

```bash
# Run it by hand — the output names which of the two checks failed
docker exec cassandra01 /usr/local/bin/axonops-healthcheck.sh

# What Docker last saw
docker inspect --format '{{.State.Health.Status}}' cassandra01
docker inspect --format '{{(index .State.Health.Log 0).Output}}' cassandra01
```

Compose runs it every 15s with a 10s timeout, 20 retries and a 120s start
period. The agent starts only once Cassandra is up, so it is normally absent for
part of that start period — which is what the start period is for. On a slow
node with `HEALTHCHECK_REQUIRE_AGENT=true`, raise `start_period` rather than
lowering `retries`.

Both the agent check and `HEALTHCHECK_REQUIRE_AGENT` are in the pinned image,
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`. On any earlier image
the script verifies Cassandra only and the variable has no effect.

Cluster data and configuration live under `./docker/` on the host — see
[Storage](#storage). `docker compose down -v` removes the AxonOps volumes but
leaves those directories; delete them by hand to start the cluster from empty.

## Requirements

- Docker Engine 20.10+ and Compose V2
- 12 GB RAM free at the defaults, 16 GB recommended; 30 GB disk, most of it
  under `./docker/`
- The `10.17.64.0/24` subnet free on the host
- Ports 3000, 1888, 9142, 9242, 9342 free, and 7199, 7299, 7399 on localhost

For a smaller machine, lower the heaps in `.env`:

```bash
CASSANDRA_HEAP_SIZE=1G
CASSANDRA_MEM_LIMIT=2g
AXONOPS_CASSANDRA_HEAP_SIZE=2G
AXONOPS_OPENSEARCH_HEAP_SIZE=2g
```

## What changed from the original stack

| Original | Here | Why |
|----------|------|-----|
| Prometheus, Grafana, 3× `cassandra_exporter`, Reaper | `axondb-timeseries`, `axondb-search`, `axon-server`, `axon-dash` | The point of the port. Metrics, logs, alerting and repair scheduling in one platform, and no JMX exporter sidecars to configure |
| `cassandra:5.0.8` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Same Cassandra, with the AxonOps agent and Java agent already installed |
| Bind mounts under `${PWD}/docker/` | Kept | Reproduces the customer environment. `setup.sh` creates and seeds them — see [Storage](#storage) |
| Bind-mounted `conf` volumes | Kept | Same reason. The image can be driven entirely by environment variables, but this way the configuration is editable on the host |
| `7000`, `7001` published per node | Not published | Internode ports; nothing outside the compose network uses them |
| `7199` JMX published on all interfaces | Published on `127.0.0.1` only | The port is unauthenticated. See [Remote JMX](#remote-jmx) |
| `cqlsh` healthcheck with hardcoded credentials | The image's own `axonops-healthcheck.sh` | The image ships with `cqlai` and `cqlsh`, and the check needs no credentials. It also verifies the `axon-agent` is alive — see [Health of the cluster nodes](#health-of-the-cluster-nodes) |
| Passwords in the YAML | `.env`, gitignored | Nothing secret in a committed file |
| `restart: always` | `restart: unless-stopped` | Matches the other examples; a container you stopped stays stopped |
| `CASSANDRA_OPEN_JMX`, `JMXPORT` | Removed | Neither is read by Cassandra or by the image — they did nothing in the original either |

Kept as they were: the subnet and every address, cluster and rack layout, the
seed list, `GossipingPropertyFileSnitch`, `PasswordAuthenticator`,
`CassandraAuthorizer`, `LOCAL_JMX=no`, the ZGC flags, the `memlock` and `nofile`
ulimits, the `./docker/` storage layout for data and configuration, and the
published CQL port numbers.

## Troubleshooting

**`authenticator: AllowAllAuthenticator` after starting.** `CASSANDRA_IMAGE`
points at an image older than the 1.1.0 build, which predates entrypoint support
for `CASSANDRA_AUTHENTICATOR`. See [Before you start](#before-you-start).

**`Provided username cassandra and/or password are incorrect` right after the
cluster comes up.** The default superuser is created a few seconds after the
first node finishes starting, not during startup. Wait for
`Created default superuser role 'cassandra'` and retry:

```bash
docker compose logs cassandra01 | grep "default superuser"
```

**`Expecting URI in variable: [cassandra.config]. Found[cassandra.yaml]`, with
`sed: can't read /opt/cassandra/conf/cassandra.yaml` above it.** The node has an
empty configuration directory. Either `setup.sh` was never run, or the bind
mount is not resolving to the directory you think it is. Check what the
container actually sees:

```bash
docker run --rm -v "$PWD/docker/cassandra01-conf:/x" busybox ls /x | wc -l
```

Zero means Docker created an empty directory instead of sharing yours — on
Docker Desktop, a path outside the configured file-sharing list does exactly
that. Move the project under a shared path, or add the path in Docker Desktop
under Settings → Resources → File sharing.

**`Permission denied` writing to the configuration or data directory (Linux).**
The directories must be writable by uid 999, the `cassandra` user in the image:

```bash
sudo chown -R 999:999 docker/
```

`setup.sh` attempts this and warns when it cannot. Docker Desktop on macOS and
Windows maps ownership for you, so this only affects Linux hosts.

**A node never becomes healthy.** Nodes start in sequence, so a cold start takes
several minutes. Watch `docker compose logs -f cassandra02`. If it is stuck on
gossip, confirm the seed addresses match the `ipv4_address` entries.

**`Cannot assign requested address` or a subnet conflict on `up`.** Something
else on the host uses `10.17.64.0/24` — often another Docker network. Check with
`docker network ls` and `ip route`, then either remove the conflicting network
or edit the subnet and all seven addresses together.

**`nodetool status` shows fewer than three nodes.** Check the node that is
missing came up (`docker compose ps`), then look for a cluster-name mismatch —
a node that joined with a different `CASSANDRA_CLUSTER_NAME` on an earlier run
keeps it in its data directory. `docker compose down -v` does **not** clear that
here, because the data is a host bind mount: remove `docker/cassandra0*/` by
hand.

**JMX from another host times out.** Expected — the ports are bound to
`127.0.0.1`. See [Remote JMX](#remote-jmx).

**Cassandra logs `Invalid or unsupported protocol version (22)` and
`axon-server` logs `tls: first record does not look like a TLS handshake`.** One
side is using TLS and the other is not; 22 is `0x16`, the first byte of a TLS
ClientHello read as a CQL protocol version. Leave `AXONOPS_CASSANDRA_SSL=false`
unless you have mounted a keystore into `axondb-timeseries`.

**Other settings that look right but are ignored.** Three of these images take
configuration under names that differ from the ones their own READMEs suggest,
and each fails without naming the variable at fault. Example 01 documents all
three: [configuration variables that look right but are not](../01-cassandra-cluster/README.md#configuration-variables-that-look-right-but-are-not).

## Licensing

AxonOps requires a license for production use — <https://axonops.com>. The stack
runs without a license key in trial mode, which is enough for evaluation.

## Support

Maintained by [AxonOps](https://axonops.com). For support, contact us at
[axonops.com/contact](https://axonops.com/contact).
