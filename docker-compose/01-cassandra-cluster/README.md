# Example 01 — Self-hosted AxonOps monitoring a 3-node Cassandra cluster

**English** | [Français](README.fr.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

A complete AxonOps installation and the Apache Cassandra cluster it monitors, in
one Docker Compose project. Every image comes from this repository or the AxonOps
public registry. Start here if you are evaluating AxonOps.

- Already run Cassandra or Kafka and just need somewhere for the agents to
  report? [Example 00](../00-axonops-platform/) — the platform on its own.
- Have an AxonOps Cloud account? [Example 02](../02-saas-cassandra-cluster/) —
  the same cluster, no platform to run.

## Quick start

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose ps            # wait for all services to report healthy
```

Then open <http://localhost:3000> and pick your organisation, then the
`demo-cluster` cluster.

A cold start takes 5–10 minutes: the AxonOps data stores initialise first, then
the Cassandra nodes bootstrap one at a time.

## What it runs

| Service | Image | Purpose | Published port |
|---------|-------|---------|----------------|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Metrics store (Cassandra) | — |
| `axondb-search` | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Log and event store (OpenSearch) | — |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35` | AxonOps backend and agent endpoint | `1888` |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash:2.0.37` | Web dashboard | `3000` |
| `cassandra-0` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Monitored cluster, seed node | `9042` |
| `cassandra-1` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Monitored cluster, rack1 | — |
| `cassandra-2` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Monitored cluster, rack2 | — |

`cassandra-0` through `cassandra-2` are one datacentre, `dc1`, with one rack
each. Only `cassandra-0` publishes CQL to the host; the other two are reachable
inside the compose network and with `docker exec`.

Current tags and digests for every image: [VERSIONS.md](../../VERSIONS.md).

## Configuration

Everything is set in `.env`. Full list with defaults: [`env.example`](env.example).

| Variable | Default | Description |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Organisation name. Shared by `axon-server` and the agents — they must match. |
| `CASSANDRA_CLUSTER_NAME` | `demo-cluster` | Name of the monitored cluster in AxonOps |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` | Image for the monitored nodes |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap per monitored node |
| `CASSANDRA_HEAP_NEWSIZE` | `256M` | Young generation per monitored node |
| `AXONOPS_LICENSE_KEY` | (empty) | License key; empty runs in trial mode |
| `AXONOPS_DB_PASSWORD` | `axonops` | `axondb-timeseries` password |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | `axondb-search` admin password |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `2G` | `axondb-timeseries` heap |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `2g` | `axondb-search` heap |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS from `axon-server` to `axondb-timeseries` — leave off unless you mount a keystore, see [below](#configuration-variables-that-look-right-but-are-not) |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS from `axon-server` to `axondb-search` |

`axon-server` is configured entirely through environment variables — there is no
config file to mount or render. Each variable overrides the corresponding field
of the `axon-server.yml` shipped inside the image:

| axon-server.yml | Environment variable |
|-----------------|----------------------|
| `org_name` | `AXONSERVER_ORGNAME` |
| `license_key` | `LICENSE_KEY` |
| `tls.mode` | `TLS_MODE` |
| `log_file` | `AXON_LOG_FILE` |
| `axon_dash_url` | `AXONDASH_HOST`, `AXONDASH_PORT`, `AXONDASH_HTTPS` |
| `cql_hosts` | `CQL_HOSTS` (comma-separated) |
| `cql_username` / `cql_password` | `CQL_USERNAME` / `CQL_PASSWORD` |
| `cql_local_dc` | `CQL_LOCAL_DC` |
| `cql_ssl` / `cql_skip_verify` | `CQL_SSL` / `CQL_SSL_SKIP_VERIFY` |
| `cql_keyspace_replication` | `CQL_KS_REPLICATION` |
| `search_db.hosts` | `SEARCH_DB_HOSTS` (comma-separated) |
| `search_db.username` / `password` | `SEARCH_DB_USERNAME` / `SEARCH_DB_PASSWORD` |
| `search_db.skip_verify` | `SEARCH_DB_SKIP_VERIFY` |

axon-server binds 72 variables in total, covering retry and reconnection policy,
consistency levels, compaction windows, LDAP auth and SMTP. Anything not set
keeps the value from the image's own `axon-server.yml`.

The older `ELASTIC_*` variables are the previous generation of the `SEARCH_DB_*`
ones — do not mix the two forms.

The agents connect to `axon-server:1888` in plaintext (`AXON_AGENT_TLS_MODE=disabled`)
because the traffic never leaves the compose network. Use TLS for agents on any
other host.

### Health of the monitored nodes

The Cassandra nodes use the healthcheck the image ships,
`/usr/local/bin/axonops-healthcheck.sh`, rather than a check written here. It
verifies two things: Cassandra is serving CQL, and the `axon-agent` process is
running — a node whose agent has died still answers queries but has quietly
disappeared from AxonOps, and a check that only looks at Cassandra reports it
healthy.

A dead agent is reported in the check output but does not by itself make the
container unhealthy, because failing the check can make an orchestrator restart
or drain a node that is still serving. Set `HEALTHCHECK_REQUIRE_AGENT=true` on a
node to treat it as a failure:

```bash
docker compose exec cassandra-0 /usr/local/bin/axonops-healthcheck.sh
```

The agent starts only once Cassandra is up, so it is normally absent for part of
the 90s start period.

Both the agent check and `HEALTHCHECK_REQUIRE_AGENT` are in the pinned image,
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0`. On any earlier image
the script verifies Cassandra only and the variable has no effect.

## Using the cluster

```bash
# CQL from the host
cqlsh 127.0.0.1 9042

# CQL from inside a node, using the bundled cqlai client
docker compose exec cassandra-0 cqlai -e "SELECT release_version FROM system.local;"

# Ring status
docker compose exec cassandra-0 nodetool status
```

Write some data so the dashboard has something to show:

```bash
docker compose exec cassandra-0 cqlai -e "
  CREATE KEYSPACE IF NOT EXISTS demo
    WITH replication = {'class':'NetworkTopologyStrategy','dc1':3};
  CREATE TABLE IF NOT EXISTS demo.events (
    id uuid PRIMARY KEY, created timestamp, payload text);
  INSERT INTO demo.events (id, created, payload)
    VALUES (uuid(), toTimestamp(now()), 'hello');"
```

## Operations

```bash
docker compose ps                       # health of every service
docker compose logs -f axon-server      # follow one service
docker compose logs -f cassandra-0
docker compose exec cassandra-0 tail -f /var/log/axonops/axon-agent.log
docker compose down                     # stop, keep data
docker compose down -v                  # stop and delete all volumes
```

## Requirements

- Docker Engine 20.10+ and Compose V2
- 10 GB RAM free at the defaults above, 20 GB disk
- Ports 3000, 1888 and 9042 free on the host

Lower `CASSANDRA_HEAP_SIZE`, `AXONOPS_CASSANDRA_HEAP_SIZE` and
`AXONOPS_OPENSEARCH_HEAP_SIZE` if you have less memory. This is a development
and evaluation stack; production sizing is in the
[example 00](../00-axonops-platform/README.md#requirements) stack documentation.

## Troubleshooting

**A Cassandra node never becomes healthy.** Nodes bootstrap one at a time and
`start_period` is 90s. Watch it with `docker compose logs -f cassandra-1`. Out of
memory is the usual cause — lower `CASSANDRA_HEAP_SIZE`.

**The cluster does not appear in the dashboard.** The agent and `axon-server`
must share an organisation. `AXONOPS_ORG_NAME` in `.env` sets both; check with
`docker compose exec cassandra-0 env | grep AXON_AGENT_ORG`.

**`axon-server` restarts.** It needs both data stores healthy. Check
`docker compose logs axondb-timeseries axondb-search`, and confirm
`AXONOPS_DB_PASSWORD` and `AXONOPS_SEARCH_PASSWORD` match between them and
`axon-server`.

### Configuration variables that look right but are not

Three of the services take configuration under names that differ from the ones
their READMEs suggest. Each of these was hit bringing this example up, and each
fails in a way that does not name the variable at fault.

**`axondb-search` exits with a bootstrap check failure.**

```
ERROR: [1] bootstrap checks failed
[1]: the default discovery settings are unsuitable for production use;
     at least one of [discovery.seed_hosts, discovery.seed_providers,
     cluster.initial_cluster_manager_nodes] must be configured
```

`OPENSEARCH_DISCOVERY_TYPE` was documented and printed in the container's
startup banner, but builds before `3.7.0-1.6.1` never wrote it to
`opensearch.yml`. It works from `3.7.0-1.6.1` onwards. This example still also
passes OpenSearch's own `discovery.type=single-node`, which the process reads
directly, so the file keeps working against an older image; drop that line once
you are on `3.7.0-1.6.1` or later everywhere.

**Cassandra logs `Invalid or unsupported protocol version (22)`,
`axon-server` logs `tls: first record does not look like a TLS handshake`.**

22 is `0x16`, the first byte of a TLS ClientHello being read as a CQL protocol
version — one side is using TLS and the other is not. `axondb-timeseries` only
enables `client_encryption_options` when a keystore is mounted at
`CASSANDRA_KEYSTORE_PATH`; there is no variable that turns it on by itself, and
`CASSANDRA_CLIENT_ENCRYPTION_ENABLED` does nothing. So the native transport is
plaintext and `CQL_SSL` must be `false` to match. To use TLS, mount a keystore
and set both sides together.

**`axon-dash` crash-loops with `findHost | no reachable endpoints` and
`ECONNREFUSED 127.0.0.1:8080`.**

`axon-dash` maps its `axon-dash.yml` onto environment variables by section and
key — `axon-server.private_endpoints` becomes `AXONSERVER_PRIVATE_ENDPOINTS`,
`axon-dash.port` becomes `AXONDASH_PORT`. It also accepts anything prefixed
`AXON_SERVER_`, lower-cases it and merges it into the `axon-server` section,
which means a wrong name such as `AXON_SERVER_URL` is accepted silently and
appears in the config the dash prints at startup without having any effect. The
address the dash actually dials is `private_endpoints`; check it in that printed
config block.

## Support

Maintained by [AxonOps](https://axonops.com). For support, contact us at
[axonops.com/contact](https://axonops.com/contact).
