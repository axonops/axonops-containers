# Example 03 — A secured 3-rack cluster, monitored by AxonOps

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

The three nodes default to
`ghcr.io/axonops/development/cassandra:5.0.8-2.0.31-dev-auth-1`, not to the
production `ghcr.io/axonops/cassandra/cassandra:5.0.8`. That is deliberate and
temporary.

Authentication here is set with `CASSANDRA_AUTHENTICATOR` and
`CASSANDRA_AUTHORIZER`, which the image entrypoint applies to `cassandra.yaml`.
**Images published before that entrypoint support ignore both variables**: the
cluster starts, joins and appears in AxonOps exactly as it should, and accepts
every connection without a password. Nothing in the logs calls this out. The
current production image predates the change; the development image above is the
first build that carries it.

Move `CASSANDRA_IMAGE` to the production tag once the next Cassandra release
ships — `env.example` has both lines ready.

Either way, check what you actually got once the stack is up:

```bash
docker exec cassandra01 grep '^authenticator:' /opt/cassandra/conf/cassandra.yaml
# authenticator: PasswordAuthenticator   <- secured
# authenticator: AllowAllAuthenticator   <- image too old, see above
```

## Quick start

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose ps            # wait for all seven services to report healthy
```

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
| `cassandra01` | 10.17.64.5 | `ghcr.io/axonops/development/cassandra:5.0.8-2.0.31-dev-auth-1` | Cluster node, rack1 | `9142` CQL, `7199` JMX¹ |
| `cassandra02` | 10.17.64.6 | same | Cluster node, rack2 | `9242` CQL, `7299` JMX¹ |
| `cassandra03` | 10.17.64.7 | same | Cluster node, rack3 | `9342` CQL, `7399` JMX¹ |
| `axondb-timeseries` | 10.17.64.20 | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Metrics store (single-node Cassandra) | — |
| `axondb-search` | 10.17.64.21 | `ghcr.io/axonops/axondb-search:3.7.0-1.6.0` | Log and event store (OpenSearch) | — |
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
changing the eight `ipv4_address` entries, `CASSANDRA_SEEDS`,
`CASSANDRA_LISTEN_ADDRESS`, `CASSANDRA_BROADCAST_RPC_ADDRESS` and
`java.rmi.server.hostname` together.

**Why all three nodes are seeds.** Carried over from the original stack. It is
fine for a cluster created from empty, which is what this is: seeds skip
bootstrap streaming, and there is nothing to stream. For a cluster you grow
later, make the new nodes non-seeds so they bootstrap properly.

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
| `CASSANDRA_IMAGE` | `…/development/cassandra:5.0.8-2.0.31-dev-auth-1` | Image for the three nodes — see [Before you start](#before-you-start) |
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

Data lives in named volumes: `cassandra01-data`, `cassandra02-data`,
`cassandra03-data`, plus the four AxonOps volumes.

## Requirements

- Docker Engine 20.10+ and Compose V2
- 12 GB RAM free at the defaults, 16 GB recommended; 30 GB disk
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
| `cassandra:5.0.8` | `ghcr.io/axonops/development/cassandra:5.0.8-…` | Same Cassandra, with the AxonOps agent and Java agent already installed. Development image for now — see [Before you start](#before-you-start) |
| Bind mounts under `${PWD}/docker/` | Named volumes | Nothing to create before the first run, and `docker compose down -v` cleans up |
| Bind-mounted `conf` volumes | None | This image takes its configuration from environment variables |
| `7000`, `7001` published per node | Not published | Internode ports; nothing outside the compose network uses them |
| `7199` JMX published on all interfaces | Published on `127.0.0.1` only | The port is unauthenticated. See [Remote JMX](#remote-jmx) |
| `cqlsh` healthcheck with hardcoded credentials | `nodetool statusbinary` | The image ships `cqlai`, not `cqlsh`, and the check needs no credentials |
| Passwords in the YAML | `.env`, gitignored | Nothing secret in a committed file |
| `restart: always` | `restart: unless-stopped` | Matches the other examples; a container you stopped stays stopped |
| `CASSANDRA_OPEN_JMX`, `JMXPORT` | Removed | Neither is read by Cassandra or by the image — they did nothing in the original either |

Kept as they were: the subnet and every address, cluster and rack layout, the
seed list, `GossipingPropertyFileSnitch`, `PasswordAuthenticator`,
`CassandraAuthorizer`, `LOCAL_JMX=no`, the ZGC flags, the `memlock` and `nofile`
ulimits, and the published CQL port numbers.

## Troubleshooting

**`authenticator: AllowAllAuthenticator` after starting.** The image predates
entrypoint support for `CASSANDRA_AUTHENTICATOR`. See
[Before you start](#before-you-start).

**`Provided username cassandra and/or password are incorrect` right after the
cluster comes up.** The default superuser is created a few seconds after the
first node finishes starting, not during startup. Wait for
`Created default superuser role 'cassandra'` and retry:

```bash
docker compose logs cassandra01 | grep "default superuser"
```

**A node never becomes healthy.** Nodes start in sequence, so a cold start takes
several minutes. Watch `docker compose logs -f cassandra02`. If it is stuck on
gossip, confirm the seed addresses match the `ipv4_address` entries.

**`Cannot assign requested address` or a subnet conflict on `up`.** Something
else on the host uses `10.17.64.0/24` — often another Docker network. Check with
`docker network ls` and `ip route`, then either remove the conflicting network
or edit the subnet and all eight addresses together.

**`nodetool status` shows fewer than three nodes.** Check the node that is
missing came up (`docker compose ps`), then look for a cluster-name mismatch —
a node that joined with a different `CASSANDRA_CLUSTER_NAME` on an earlier run
keeps it in its data volume. `docker compose down -v` clears that.

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
