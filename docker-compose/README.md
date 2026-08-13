# Docker Compose Examples

<p align="center">
  <a href="https://axonops.com"><img src="https://axonops.com/img/axonops-logo.svg" alt="AxonOps" height="60"></a>
</p>

Runnable Docker Compose examples built from the container images published by
this repository. Each directory is self-contained: copy it, edit `.env`, run
`docker compose up -d`.

For the plain AxonOps platform stack with no monitored workload, use
[`../docker/`](../docker/README.md) instead.

## Examples

| Example | What it deploys |
|---------|-----------------|
| [01-cassandra-cluster](01-cassandra-cluster/) | Self-hosted AxonOps (`axondb-timeseries`, `axondb-search`, `axon-server`, `axon-dash`) monitoring a 3-node Apache Cassandra cluster |

## Conventions

Every example follows the same shape:

```
<example>/
  docker-compose.yaml   Services, pinned to immutable version tags
  env.example           Every variable, with defaults, commented
  README.md             Quick start, configuration reference, troubleshooting
  config/               Files mounted into containers, if any
```

- **Images** come from `ghcr.io/axonops/*` or
  `registry.axonops.com/axonops-public/*`, pinned to a version tag with the
  SHA256 digest in a comment above it. Deploy the digest in production — see
  [Image Pinning: Tags vs Checksums](../docker/README.md#image-pinning-tags-vs-checksums)
  and [VERSIONS.md](../VERSIONS.md).
- **Configuration** is environment variables in `.env` only. No example requires
  editing `docker-compose.yaml` to run.
- **Sizing** defaults to development values. Production sizing guidance is in
  each README.
- **TLS** is enabled between AxonOps and its data stores. Agent traffic inside a
  single compose network is plaintext; anything crossing a host uses TLS.

## Requirements

- Docker Engine 20.10+
- Docker Compose V2
- Per-example RAM, disk and port requirements are in that example's README

## Support

Maintained by [AxonOps](https://axonops.com). For support, contact us at
[axonops.com/contact](https://axonops.com/contact).
