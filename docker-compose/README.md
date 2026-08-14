# Docker Compose Examples

<p align="center">
  <a href="https://axonops.com"><img src="https://digitalis-marketplace-assets.s3.us-east-1.amazonaws.com/axonops-small-logo.png" alt="AxonOps" height="60"></a>
</p>

Runnable Docker Compose stacks built from the container images published by this
repository. Each directory is self-contained: copy it, edit `.env`, run
`docker compose up -d`.

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
