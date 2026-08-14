# Docker Compose Examples

**English** | [Français](README.fr.md)

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Runnable Docker Compose stacks built from the container images published by this
repository. Each directory is self-contained: copy it, edit `.env`, run
`docker compose up -d`.

## Before you run anything

The defaults in `env.example` are development values. Set these in your `.env`
before starting a stack you care about:

| Variable | Why |
|---|---|
| `AXONOPS_ORG_NAME` | Defaults to `example` (`my-organization` in 02). It names your organisation throughout AxonOps and is baked into agent registration — change it before first start, not after. |
| `AXONOPS_DB_PASSWORD` | Password for the time series database (`axondb-timeseries`). The default `axonops` is public knowledge. Use a strong, unique value. |
| `AXONOPS_SEARCH_PASSWORD` | Password for the search database (`axondb-search`). Same reasoning. The search image also enforces its own password policy — a weak value makes the container refuse to start. |
| `AXONOPS_LICENSE_KEY` | Optional. Without it AxonOps runs with free edition features only. See [AxonOps editions](https://axonops.com/docs/editions/) for what each edition includes. |

Example 02 (SaaS) is the exception: AxonOps runs in AxonOps Cloud, so only
`AXONOPS_ORG_NAME` and your agent key apply — there are no local databases to
give passwords to.

Passwords live in `.env`, which is gitignored. Never commit one.

## Which one do I want?

| | [00-axonops-platform](00-axonops-platform/) | [01-cassandra-cluster](01-cassandra-cluster/) | [02-saas-cassandra-cluster](02-saas-cassandra-cluster/) | [03-secure-3-rack-cluster](03-secure-3-rack-cluster/) |
|---|---|---|---|---|
| **Use it to** | run AxonOps for clusters you already have | see the whole thing working end to end | monitor a cluster without running AxonOps | model a production-shaped, secured cluster |
| AxonOps | self-hosted | self-hosted | SaaS | self-hosted |
| Cassandra | none — bring your own | 3 nodes, monitored | 3 nodes, monitored | 3 nodes, 3 racks, monitored |
| Cluster auth | — | off | off | `PasswordAuthenticator` |
| Containers | 4 | 7 | 3 | 7 |
| RAM at defaults | ~10 GB | ~10 GB | ~5 GB | ~12 GB |
| Dashboard | `localhost:3000` | `localhost:3000` | AxonOps console | `localhost:3000` |
| You need | nothing | nothing | a SaaS org and agent key | nothing |

Start with **01** if you are evaluating AxonOps and want to watch a real cluster
appear in a dashboard. Start with **00** if you already run Cassandra or Kafka
and want somewhere for its agents to report. Start with **02** if you have an
AxonOps Cloud account. Start with **03** if you want a cluster that resembles a
real deployment — authentication, one rack per node, fixed addressing and remote
JMX — or if you are porting the widely-shared
[Prometheus / Grafana / Reaper Compose stack](https://github.com/crystalloide/cassandra-reaper)
that it is based on.

## Conventions

Every example follows the same shape:

```
<example>/
  docker-compose.yaml   Services, pinned to immutable version tags
  env.example           Every variable, with defaults, commented
  README.md             Quick start, configuration reference, troubleshooting
```

- **Configuration is `.env` only**, and no `docker-compose.yaml` needs editing to
  run. Example 03 is the one exception: it reproduces a customer environment
  that bind-mounts Cassandra's configuration directory from the host, so it also
  ships a `setup.sh` that creates and seeds it.
- **Images** come from `ghcr.io/axonops/*` or
  `registry.axonops.com/axonops-public/*`, pinned to a version tag with the
  SHA256 digest in a comment above it. Deploy the digest in production — see
  [Image Pinning: Tags vs Checksums](00-axonops-platform/README.md#image-pinning-tags-vs-checksums)
  and [VERSIONS.md](../VERSIONS.md).
- **Sizing** defaults to development values. Each README says what to lower.
- **TLS** protects anything that leaves a host. Agent traffic inside a single
  compose network is plaintext by design; the SaaS example uses TLS throughout.
- **Secrets** live in `.env`, which is gitignored. Never commit one.

## Requirements

- Docker Engine 20.10+ and Docker Compose V2
- Per-example RAM, disk and port requirements are in that example's README

## FAQ

### How do I update `axon-server`, `axon-dash` and the agent?

Every image in these files is pinned to an exact version tag, so
`docker compose pull` on its own gets you nothing new — an upgrade means editing
the tag (or the digest, if you deploy the digest form) and recreating that one
service. Current tags and digests for every image:
[VERSIONS.md](../VERSIONS.md).

**Order.** Data stores first if they changed, then `axon-server`, then
`axon-dash`, then the agents. Keep `axon-server` and `axon-dash` on releases from
the same batch — the dash talks to the server's API, not the other way round, so
a newer dash against an older server is the combination to avoid.

**`axon-server` and `axon-dash`.** Both are pinned directly in
`docker-compose.yaml`, with the digest in a comment above the tag:

```yaml
  axon-server:
    # Preferred (immutable): registry.axonops.com/…/axon-server@sha256:c75f6672…
    image: registry.axonops.com/axonops-public/axonops-docker/axon-server:2.0.35
```

Change the tag and the digest comment together — a stale comment beside a new
tag is how someone later deploys the wrong image — then recreate just that
service:

```bash
docker compose pull axon-server
docker compose up -d axon-server        # recreates only this container
docker compose logs -f axon-server      # watch it come up
docker compose ps                       # healthy?
```

Then the same two commands for `axon-dash`. Example 02 has neither — AxonOps
Cloud runs and upgrades both for you, so there the agent is the only thing you
update. Both are stateless: everything lives
in `axondb-timeseries` and `axondb-search`, which you are not touching, so a
recreate loses no data. Agents reconnect on their own once the server is back.

**The agent.** It ships inside the Cassandra image rather than as its own
container, and it is the middle component of the tag —
`ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0` is Cassandra 5.0.8 with
agent 2.0.31 from build 1.1.0. Upgrading the agent therefore means moving to a
new image tag, which in examples 01, 02 and 03 is `CASSANDRA_IMAGE` in `.env`:

```bash
CASSANDRA_IMAGE=ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.1.0
```

Recreate the nodes **one at a time**, waiting for each to come back healthy
before starting the next, and drain first so the node stops taking writes it
would lose:

```bash
docker compose pull
docker compose exec cassandra-1 nodetool drain
docker compose up -d --no-deps cassandra-1
docker compose ps                            # wait for healthy, then the next node
docker compose exec cassandra-1 nodetool status
```

The nodes are `cassandra-0`, `cassandra-1` and `cassandra-2` in examples 01 and
02, and `cassandra01`, `cassandra02` and `cassandra03` in example 03.

Data survives — it is on a named volume (example 03 uses host directories under
`./docker/`), and neither is removed by recreating a container. In example 00
there are no Cassandra containers to upgrade: the agents run on your own hosts,
and you upgrade them there.

**Changing the Cassandra version is not the same thing.** Only the first
component of the tag is Cassandra itself, and moving it is a real database
upgrade — snapshot, `nodetool upgradesstables` afterwards, upstream release
notes — not an image swap. To pick up a new agent or build, keep the Cassandra
version where it is and change the second or third component only.

**Rolling back** is the same operation with the old tag: put it back, run
`docker compose up -d <service>` again.

### How do I update AxonOps without touching the Cassandra cluster?

Upgrading AxonOps and upgrading Cassandra are separate operations. Everything on
the AxonOps side — `axondb-timeseries`, `axondb-search`, `axon-server`,
`axon-dash` — can be replaced while the cluster keeps running, because no
Cassandra container is recreated and no `nodetool` command is involved. The
agents are the one exception: they ship inside the Cassandra image, so upgrading
an agent does recreate a Cassandra container (see above).

**What the cluster sees.** Nothing. Agents buffer in memory while `axon-server`
is down and flush when it returns; Cassandra itself never learns the monitoring
stack restarted. Expect a gap in metrics for the length of the restart, and
alerts that depend on data arriving may fire — silence noisy ones first if you
have integrations wired up.

**Before you start.**

```bash
docker compose ps                       # note what is healthy now
docker compose config | grep image:     # record the tags you are moving away from
```

Back up the data volumes if the stack holds history you care about
(`axondb-timeseries-data`, `axondb-search-data`, `axon-server-data` in example
00). Recreating a container does not delete a named volume, but a rollback is
easier with a copy.

**Order.** Databases, then `axon-server`, then `axon-dash` — dependencies first,
so nothing talks to something older than itself. Skip any component whose tag has
not changed. Do one service at a time and confirm it is healthy before the next:

```bash
# 1. Edit docker-compose.yaml: new tag AND the digest comment above it
# 2. Then, per service:
docker compose pull <service>
docker compose up -d --no-deps <service>   # --no-deps: do not restart anything else
docker compose logs -f <service>
docker compose ps                          # healthy before moving on
```

`--no-deps` matters here. Without it Compose may restart linked services, which
in examples 01 and 03 pulls the Cassandra containers into an upgrade you did not
ask for.

**Verify, in this order:**

```bash
docker compose ps                       # all healthy
docker compose exec axon-server \
  curl -sf http://localhost:8080/api/v1/healthz
```

`axon-server`'s API port is not published to the host in these examples, which is
why the check runs inside the container — it is the same probe the service's own
healthcheck uses. Then open the dashboard on `localhost:3000` and confirm every
node is still listed and metrics resume. A node showing as disconnected for more
than a minute or two after the server is healthy means the agent did not
reconnect — restart that agent's Cassandra container last, not first.

**Rolling back** is the same loop with the previous tags. Database images are the
one component where a rollback is not always safe: a newer version may have
migrated its on-disk format, so roll `axondb-*` back only onto a restored volume
copy, not onto data a newer version has already written.

**Version skew.** Keep `axon-server` and `axon-dash` on releases from the same
batch. Agents are the tolerant part — an older agent reporting to a newer server
is normal and expected during a staged rollout, which is why agents come last and
can wait for a maintenance window on the cluster.

## When something does not start

Each README has a troubleshooting section for its own stack. One class of
problem is worth knowing about up front: several of these images accept
configuration under names that differ from the ones their own documentation
suggests, and a wrong name is ignored silently rather than rejected. The three
found so far — in `axondb-search`, `axondb-timeseries` and `axon-dash` — are
written up in
[configuration variables that look right but are not](01-cassandra-cluster/README.md#configuration-variables-that-look-right-but-are-not),
with the error each one produces.

## Support

Maintained by [AxonOps](https://axonops.com). For support, contact us at
[axonops.com/contact](https://axonops.com/contact).
