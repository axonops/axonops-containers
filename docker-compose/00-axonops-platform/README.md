# Example 00 — The AxonOps platform on its own

**English** | [Français](README.fr.md) | [Español](README.es.md) | [Galego](README.gl.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

A complete self-hosted AxonOps installation — and nothing else. Point agents on
your own hosts at it, or use it as the base for the other examples.

- Want a monitored Cassandra cluster in the same project?
  [Example 01](../01-cassandra-cluster/) — the platform plus three nodes.
- Have an AxonOps Cloud account? [Example 02](../02-saas-cassandra-cluster/) —
  a cluster reporting to SaaS, no platform to run.

## Quick start

```bash
cp env.example .env          # set AXONOPS_ORG_NAME
docker compose up -d
docker compose ps            # wait for all services to be up and healthy
```

Then open <http://localhost:3000>.

A cold start takes 2–3 minutes: the two data stores initialise first, then
`axon-server` and the dashboard come up behind them.

## What it runs

| Service | Image | Purpose | Published port |
|---------|-------|---------|----------------|
| `axondb-timeseries` | `ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0` | Metrics store (Cassandra) | — |
| `axondb-search` | `ghcr.io/axonops/axondb-search:3.7.0-1.6.1` | Log and event store (OpenSearch) | — |
| `axon-server` | `registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.39` | Backend and agent endpoint | `1888` |
| `axon-dash` | `registry.axonops.com/axonops-public/axonops-docker/axon-dash:2.0.39` | Web dashboard | `3000` |
| `axon-reporting` | `europe-docker.pkg.dev/axonops-public/axonops-docker-dev/axon-reporting:latest` | Reports v2, see [below](#reports-v2) | — |

Current tags and digests for every image: [VERSIONS.md](../../VERSIONS.md).

### Reports v2

`axon-reporting` serves Reports v2. It runs beside `axon-dash` and shares its
network namespace (`network_mode: "service:axon-dash"`), so the two reach each
other on `127.0.0.1` and `axon-server` reaches it as `axon-dash:8081`. It
publishes no port and has no healthcheck — the image ships neither `curl` nor
`wget`.

| Setting | Service | Value |
|---------|---------|-------|
| `AXON_REPORTING_URL` | `axon-server` | `http://axon-dash:8081` |
| `AXONDASH_REPORTING_URL` (`axon-dash.reporting_url`) | `axon-dash` | `http://127.0.0.1:8081` |
| `AXONDASH_URL_TEMPLATE` | `axon-reporting` | `http://127.0.0.1:3000` |
| `AXONDASH_PATH_PREFIX` | `axon-reporting` | (empty) |

From 2.0.39, `AXON_REPORTING_URL` replaces `AXONDASH_HOST`, `AXONDASH_PORT` and
`AXONDASH_HTTPS` on `axon-server`, which no longer reads them.
`AXONDASH_URL_TEMPLATE` and `AXONDASH_PATH_PREFIX` are set explicitly because
the image's built-in defaults point at a hosted dashboard.

The image is a development build
(`europe-docker.pkg.dev/axonops-public/axonops-docker-dev/axon-reporting:latest`)
until it is published to `registry.axonops.com`. It is built for `linux/amd64`
only; on Apple Silicon, Docker runs it under emulation.

Recreating `axon-dash` on its own leaves `axon-reporting` attached to the old
container's network namespace, where nothing can reach it. Recreate it straight
after:

```bash
docker compose up -d --force-recreate axon-reporting
```

## Configuration

Everything is set in `.env`. Full list with defaults: [`env.example`](env.example).

| Variable | Default | Description |
|----------|---------|-------------|
| `AXONOPS_ORG_NAME` | `example` | Organisation name, shown in the dashboard. Agents must use the same value. |
| `AXONOPS_LICENSE_KEY` | (empty) | License key; empty runs in trial mode |
| `AXONOPS_DB_PASSWORD` | `axonops` | `axondb-timeseries` password |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | `axondb-search` admin password |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `4G` | `axondb-timeseries` heap |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `4g` | `axondb-search` heap |
| `AXONOPS_OPENSEARCH_SSL` | `true` | TLS from `axon-server` to `axondb-search` |
| `AXONOPS_CASSANDRA_SSL` | `false` | TLS from `axon-server` to `axondb-timeseries` — see below |

`axon-server` is configured entirely through environment variables; there is no
config file to mount or render. Each one overrides the corresponding field of
the `axon-server.yml` shipped inside the image — `AXONSERVER_ORGNAME`,
`LICENSE_KEY`, `TLS_MODE`, the `CQL_*` set for the metrics store and the
`SEARCH_DB_*` set for the log store. The full mapping is in
[example 01](../01-cassandra-cluster/README.md#configuration).

### TLS between the services

**To `axondb-search`: on.** The image generates its own self-signed
certificates, `axon-server` connects over HTTPS and skips verification.

**To `axondb-timeseries`: off.** The image only enables Cassandra's
`client_encryption_options` when a keystore is mounted at
`CASSANDRA_KEYSTORE_PATH` — no environment variable turns it on by itself — so
the native transport is plaintext and `axon-server` must match. Turning
`AXONOPS_CASSANDRA_SSL` on without mounting a keystore breaks the connection;
see [Troubleshooting](#troubleshooting).

All of this traffic stays inside the compose network.

## Connecting agents

The agent endpoint (`1888`) is published, so agents on other hosts can connect:

```yaml
# axon-agent.yml on the monitored host
axon-server:
  hosts: "your-docker-host:1888"
axon-agent:
  org: "my-company"        # must match AXONOPS_ORG_NAME
```

Agents in containers take the same settings as environment variables —
`AXON_AGENT_SERVER_HOST`, `AXON_AGENT_SERVER_PORT`, `AXON_AGENT_ORG`. Example 01
wires exactly that up for a Cassandra cluster in the same project.

## Image Pinning: Tags vs Checksums

Every `image:` in `docker-compose.yaml` can be written two ways. Both are shown
below, and both work — but they give you very different guarantees.

```yaml
# Tag — readable, mutable
image: ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0

# Digest (SHA256 checksum) — preferred
image: ghcr.io/axonops/axondb-timeseries@sha256:1ae990a737d36b7c6f8eb92d6d3baf5234e5eae2a4e37fa208acd1108cad934c
```

**Use the digest.** A digest is a cryptographic checksum of the exact image
content, so `docker compose pull` can only ever fetch the bytes you tested
against. A tag is just a mutable pointer: whoever controls the registry can move
it, and the same compose file then silently starts a different image. That is
the supply-chain risk digests remove.

Practical guidance:

| Reference | When to use |
|-----------|-------------|
| `@sha256:<digest>` | **Production, and anything you need to reproduce.** Immutable, verifiable, auditable. |
| `:5.0.8-1.4.0` (version tag) | Development and evaluation, where readability matters more than immutability. This repository never overwrites a published version tag, so these are stable in practice — just not cryptographically guaranteed. |
| `:latest`, `:5.0.8` (floating tags) | Never in production. These move with every release. |

The trade-off is legibility: a digest tells you nothing about which version you
are running. Keep the version tag next to it in a comment, as
`docker-compose.yaml` does, and record the mapping in
[VERSIONS.md](../../VERSIONS.md).

### Finding the Digest for a Version

Copy-paste ready references for the current release of every image are in
[VERSIONS.md](../../VERSIONS.md), regenerated by `../../scripts/update-versions.sh`.

To resolve one yourself, without pulling the image:

```bash
docker buildx imagetools inspect ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0 \
  --format '{{ .Manifest.Digest }}'
```

Or, if you have already pulled it:

```bash
docker inspect ghcr.io/axonops/axondb-timeseries:5.0.8-1.4.0 \
  --format '{{ index .RepoDigests 0 }}'
```

All images published to GHCR are signed with Sigstore Cosign. Verify the
signature against the digest before deploying — see
[Gold Standard Security Deployment](../../README.md#gold-standard-security-deployment)
for the full procedure and rationale.

## Operations

```bash
docker compose ps                       # health of every service
docker compose logs -f                  # follow everything
docker compose logs -f axon-server      # follow one service
docker compose down                     # stop, keep data
docker compose down -v                  # stop and delete all volumes
```

Data lives in named volumes: `axondb-timeseries-data`, `axondb-timeseries-logs`,
`axondb-search-data`, `axondb-search-logs`, `axon-server-data`.

## Requirements

- Docker Engine 20.10+ and Compose V2
- 10 GB RAM free at the defaults above, 16 GB recommended; 20 GB disk
- Ports 3000 and 1888 free on the host

For a development machine with less memory, lower both heaps:

```bash
AXONOPS_CASSANDRA_HEAP_SIZE=2G
AXONOPS_OPENSEARCH_HEAP_SIZE=2g
```

## Troubleshooting

**A service never becomes healthy.** First start takes 2–3 minutes. Watch it
with `docker compose ps`, then read that service's log:
`docker compose logs -f axondb-timeseries`.

**`axon-server` restarts.** It needs both data stores healthy —
`depends_on: condition: service_healthy` enforces the order, so check
`docker compose logs axondb-timeseries axondb-search` first. Then confirm
`AXONOPS_DB_PASSWORD` and `AXONOPS_SEARCH_PASSWORD` match between the stores and
`axon-server`.

**Out of memory.** Lower `AXONOPS_CASSANDRA_HEAP_SIZE` and
`AXONOPS_OPENSEARCH_HEAP_SIZE` as above.

**The dashboard does not load.** Check the dash can reach the backend:

```bash
docker exec axon-dash curl -s http://axon-server:8080/api/v1/healthz
```

**Cassandra logs `Invalid or unsupported protocol version (22)`, `axon-server`
logs `tls: first record does not look like a TLS handshake`.** One side is using
TLS and the other is not — 22 is `0x16`, the first byte of a TLS ClientHello read
as a CQL protocol version. Set `AXONOPS_CASSANDRA_SSL=false` unless you have
mounted a keystore, as explained under
[TLS between the services](#tls-between-the-services).

**Reports do not generate.** Check each hop to `axon-reporting`; both print
`{"data":"OK"}`:

```bash
docker exec axon-dash curl -s http://127.0.0.1:8081/healthz     # axon-dash -> axon-reporting
docker exec axon-server curl -s http://axon-dash:8081/healthz   # axon-server -> axon-reporting
docker compose logs axon-reporting
```

Its first log line names the dashboard it renders from:
`"axon_dash": "http://127.0.0.1:3000"`.

**Other settings that look right but are ignored.** Three of these images take
configuration under names that differ from the ones their own READMEs suggest,
and each fails without naming the variable at fault. Example 01 documents all
three: [configuration variables that look right but are not](../01-cassandra-cluster/README.md#configuration-variables-that-look-right-but-are-not).

## Licensing

AxonOps requires a license for production use — <https://axonops.com>. The stack
runs without a license key in trial mode, which is enough for evaluation and for
the other examples here.

## Support

Maintained by [AxonOps](https://axonops.com). For support, contact us at
[axonops.com/contact](https://axonops.com/contact).
