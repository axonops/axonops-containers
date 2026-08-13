# Example 02 — AxonOps SaaS monitoring a 3-node Cassandra cluster

<p align="center">
  <a href="https://axonops.com"><img src="https://axonops.com/img/axonops-logo.svg" alt="AxonOps" height="60"></a>
</p>

A 3-node Apache Cassandra cluster whose agents report to AxonOps SaaS. No
AxonOps platform runs locally — the only containers are the Cassandra nodes,
and the dashboard is the hosted one.

Use [example 01](../01-cassandra-cluster/) instead if you want the whole
platform running on your own machine.

## Quick start

```bash
cp env.example .env          # set AXONOPS_ORG_NAME and AXONOPS_AGENT_KEY
docker compose up -d
docker compose ps            # wait for all three nodes to report healthy
```

Then open <https://console.axonops.cloud> and pick the `saas-demo-cluster`
cluster. Nodes appear as they start; a cold start takes 3–5 minutes because they
bootstrap one at a time.

Your organisation name and agent key both come from the AxonOps console:
**Settings → Agents**. The agents will not start without them — Compose fails
immediately with `set AXONOPS_AGENT_KEY in .env` rather than starting a cluster
that reports nowhere.

## What it runs

| Service | Image | Purpose | Published port |
|---------|-------|---------|----------------|
| `cassandra-0` | `ghcr.io/axonops/cassandra/cassandra:5.0.8` | Seed node, `rack0` | `9042` |
| `cassandra-1` | `ghcr.io/axonops/cassandra/cassandra:5.0.8` | `rack1` | — |
| `cassandra-2` | `ghcr.io/axonops/cassandra/cassandra:5.0.8` | `rack2` | — |

One datacentre, `dc1`, with one rack per node. Only `cassandra-0` publishes CQL
to the host; the others are reachable inside the compose network and through
`docker exec`.

Current tags and digests for every image: [VERSIONS.md](../../VERSIONS.md).

## How this differs from example 01

| | 01 self-hosted | 02 SaaS (this one) |
|---|---|---|
| Containers | 7 | 3 |
| RAM at defaults | ~10 GB | ~5 GB |
| Dashboard | `http://localhost:3000` | <https://console.axonops.cloud> |
| Agent endpoint | `axon-server:1888` on the compose network | `agents.axonops.cloud:443` outbound |
| Agent transport | plaintext (`AXON_AGENT_TLS_MODE=disabled`) | TLS, the image default |
| Credentials | organisation name only | organisation name **and** agent key |
| Metrics stored | in your `axondb-timeseries` | in AxonOps SaaS |

## Configuration

Everything is set in `.env`. Full list with defaults: [`env.example`](env.example).

| Variable | Default | Description |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | — | AxonOps organisation. Required. |
| `AXONOPS_AGENT_KEY` | — | Agent key from the console. Required. |
| `CASSANDRA_CLUSTER_NAME` | `saas-demo-cluster` | Cluster name shown in AxonOps |
| `CASSANDRA_DC` | `dc1` | Datacentre name |
| `CASSANDRA_IMAGE` | `ghcr.io/axonops/cassandra/cassandra:5.0.8` | Image for the nodes |
| `CASSANDRA_HEAP_SIZE` | `1G` | Heap per node |
| `CASSANDRA_HEAP_NEWSIZE` | `256M` | Young generation per node |
| `CQL_PORT` | `9042` | Host port for CQL on `cassandra-0` |
| `AXONOPS_SERVER_HOST` | `agents.axonops.cloud` | Agent endpoint |
| `AXONOPS_SERVER_PORT` | `443` | Agent endpoint port |
| `AXONOPS_NTP_HOST` | `time.google.com` | NTP host for the agent's clock-skew check |

The agent key is a credential. `.env` is gitignored — do not commit it, and do
not bake it into an image.

## Network requirements

The agents make **outbound** TLS connections to `agents.axonops.cloud:443`.
Nothing inbound is needed. Behind an egress proxy or firewall, allow that host
and port; there is no fallback to plaintext.

Check an agent is connected:

```bash
docker compose exec cassandra-0 tail -f /var/log/axonops/axon-agent.log
```

A healthy agent logs a successful connection. `Unable to connect to axonops
services` means the endpoint is unreachable or the key is wrong.

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
docker compose ps                       # health of every node
docker compose logs -f cassandra-0      # Cassandra output
docker compose exec cassandra-0 tail -f /var/log/axonops/axon-agent.log
docker compose down                     # stop, keep data
docker compose down -v                  # stop and delete all volumes
```

## Requirements

- Docker Engine 20.10+ and Compose V2
- 5 GB RAM free at the defaults above, 10 GB disk
- Port 9042 free on the host, or set `CQL_PORT`
- Outbound HTTPS to `agents.axonops.cloud`
- An AxonOps SaaS organisation and agent key

## Troubleshooting

**Compose refuses to start with `set AXONOPS_AGENT_KEY in .env`.** That is the
intended behaviour — both `AXONOPS_ORG_NAME` and `AXONOPS_AGENT_KEY` are
required, and a cluster with no key would report to nothing.

**The cluster never appears in the console.** Check the agent log for the
connection line. The usual causes are a key from a different organisation,
egress filtering on port 443, or a clock more than a few seconds out — the agent
logs an NTP warning in that case.

**A node never becomes healthy.** Nodes bootstrap one at a time and
`start_period` is 90s. Watch `docker compose logs -f cassandra-1`. Out of memory
is the usual cause — lower `CASSANDRA_HEAP_SIZE`.

**Nodes are healthy but show as one rack.** `CASSANDRA_RACK` is fixed per
service in `docker-compose.yaml`; if you change `CASSANDRA_DC` after first
start, the existing data directories keep the old value. `docker compose down -v`
and start again.

## Support

Maintained by [AxonOps](https://axonops.com). For support, contact us at
[axonops.com/contact](https://axonops.com/contact).
