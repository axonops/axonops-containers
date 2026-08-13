# Example 01 — Self-hosted AxonOps monitoring a 3-node Cassandra cluster

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

A complete AxonOps installation and the Apache Cassandra cluster it monitors, in
one Docker Compose project. Every image comes from this repository or the AxonOps
public registry.

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
| `axondb-search` | `ghcr.io/axonops/axondb-search:3.7.0-1.6.0` | Log and event store (OpenSearch) | — |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35` | AxonOps backend and agent endpoint | `1888` |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash:2.0.37` | Web dashboard | `3000` |
| `cassandra-0` | `ghcr.io/axonops/cassandra/cassandra:5.0.8` | Monitored cluster, seed node | `9042` |
| `cassandra-1` | `ghcr.io/axonops/cassandra/cassandra:5.0.8` | Monitored cluster, rack1 | — |
| `cassandra-2` | `ghcr.io/axonops/cassandra/cassandra:5.0.8` | Monitored cluster, rack2 | — |

`cassandra-0` through `cassandra-2` are one datacentre, `dc1`, with one rack
each. Only `cassandra-0` publishes CQL to the host; the other two are reachable
inside the compose network and with `docker exec`.

Current tags and digests for every image: [VERSIONS.md](../../VERSIONS.md).

## Configuration

Everything is set in `.env`. Full list with defaults: [`env.example`](env.example).

| Variable | Default | Description |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | `my-organization` | Organisation name. Shared by `axon-server` and the agents — they must match. |
| `CASSANDRA_CLUSTER_NAME` | `demo-cluster` | Name of the monitored cluster in AxonOps |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8` | Image for the monitored nodes |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap per monitored node |
| `CASSANDRA_HEAP_NEWSIZE` | `256M` | Young generation per monitored node |
| `AXONOPS_LICENSE_KEY` | (empty) | License key; empty runs in trial mode |
| `AXONOPS_DB_PASSWORD` | `axonops` | `axondb-timeseries` password |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | `axondb-search` admin password |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `2G` | `axondb-timeseries` heap |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `2g` | `axondb-search` heap |
| `AXONOPS_CASSANDRA_SSL` | `true` | TLS from `axon-server` to `axondb-timeseries` |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS from `axon-server` to `axondb-search` |

`axon-server` is configured from [`config/axon-server.yml.template`](config/axon-server.yml.template),
rendered at start-up by [`config/init-config.sh`](config/init-config.sh). Edit the
template to change anything the environment variables do not cover.

The agents connect to `axon-server:1888` in plaintext (`AXON_AGENT_TLS_MODE=disabled`)
because the traffic never leaves the compose network. Use TLS for agents on any
other host.

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
[docker/](../../docker/README.md#system-requirements) stack documentation.

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

## Support

Maintained by [AxonOps](https://axonops.com). For support, contact us at
[axonops.com/contact](https://axonops.com/contact).
