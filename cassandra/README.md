# AxonOps Apache Cassandra Container

[![GHCR Package](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/cassandra%2Fcassandra)

Apache Cassandra with the AxonOps monitoring and management agent, built on Red Hat UBI 9 minimal. No K8ssandra components, no Kubernetes assumptions — just Cassandra and the agent.

If you are deploying with the K8ssandra Operator, use [`ghcr.io/axonops/k8ssandra/cassandra`](../k8ssandra/README.md) instead.

## Image

```
ghcr.io/axonops/cassandra/cassandra:{CASSANDRA}-{AGENT}-{BUILD}
```

For example `ghcr.io/axonops/cassandra/cassandra:5.0.9-2.0.31-1.0.0` is Apache Cassandra 5.0.9 with AxonOps agent 2.0.31, from build 1.0.0.

| Tag form | Mutable? | Meaning |
|----------|----------|---------|
| `5.0.9-2.0.31-1.0.0` | No | Exact Cassandra version, exact agent version, exact build |
| `5.0.9-2.0.31` | Yes | Latest build for that Cassandra + agent pair |
| `5.0.9` | Yes | Latest agent and build for that Cassandra version |
| `5.0-latest` | Yes | Latest 5.0.x patch release |
| `latest` | Yes | Latest version overall |

The agent component of a tag is always a concrete version. Passing `latest` as the agent version to the pipeline resolves it to the version actually installed before any tag is written.

Development builds are published separately to `ghcr.io/axonops/cassandra/cassandra-dev` and are not for production use.

Pin by digest in anything you care about:

```bash
docker buildx imagetools inspect ghcr.io/axonops/cassandra/cassandra:5.0.9
```

## Quick start

```bash
docker run -d --name cassandra \
  -e AXON_AGENT_ORG=your-org \
  -e AXON_AGENT_KEY=your-agent-key \
  -e AXON_AGENT_CLUSTER_NAME=my-cluster \
  -p 9042:9042 \
  ghcr.io/axonops/cassandra/cassandra:5.0.9
```

`AXON_AGENT_ORG` is required; the container refuses to start without it. Check progress with:

```bash
docker logs -f cassandra
docker exec cassandra nodetool status
docker exec cassandra cqlai -e "SELECT release_version FROM system.local;"
```

## Configuration

All AxonOps agent configuration is supplied through environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `AXON_AGENT_ORG` | — | AxonOps organisation. Required. |
| `AXON_AGENT_KEY` | — | Agent key for AxonOps SaaS. |
| `AXON_AGENT_SERVER_HOST` | `agents.axonops.cloud` | AxonOps server to connect to. Set this for self-hosted. |
| `AXON_AGENT_SERVER_PORT` | `443` | AxonOps server port. |
| `AXON_AGENT_CLUSTER_NAME` | — | Cluster name shown in AxonOps. |
| `AXON_AGENT_TLS_MODE` | — | Set to `disabled` for a plaintext self-hosted server. |
| `AXON_AGENT_NTP_HOST` | auto-detected | NTP host used for clock-skew checks. |
| `AXON_AGENT_ARGS` | — | Extra arguments passed to `axon-agent`. |

Cassandra itself is configured the conventional way: mount your own files over `/etc/cassandra`, which is symlinked to `/opt/cassandra/conf`.

| Path | Purpose |
|------|---------|
| `/etc/cassandra` | Cassandra configuration |
| `/var/lib/cassandra` | Data directory (volume) |
| `/var/log/cassandra` | Cassandra logs (volume) |
| `/var/log/axonops/axon-agent.log` | Agent log |
| `/etc/axonops/build-info.txt` | Versions captured at build time, printed in the startup banner |

Exposed ports: 7000 (intra-node), 7001 (TLS intra-node), 7199 (JMX), 9042 (CQL).

## What is in the image

- Apache Cassandra, downloaded from the Apache mirrors and verified against the SHA512 recorded in [`versions.json`](versions.json)
- The AxonOps agent and the Cassandra 5.0 Java agent, from the AxonOps yum repository
- [cqlai](https://github.com/axonops/cqlai), verified against its published SHA256SUMS
- jemalloc, tini, Java 17
- Red Hat UBI 9 minimal as the base, pinned by digest

Cassandra runs as the `cassandra` user (UID/GID 999), never as root. The agent runs under a supervisor that restarts it on exit with crash-loop backoff; the container lives and dies with the Cassandra process.

## Building locally

```bash
docker build -t axonops-cassandra:local \
  --build-arg CASSANDRA_VERSION=5.0.9 \
  --build-arg CASSANDRA_SHA512=$(jq -r '.versions["5.0.9"]' cassandra/versions.json) \
  --build-arg CQLAI_VERSION=0.1.7 \
  cassandra/5.0
```

`CASSANDRA_SHA512` and `CQLAI_VERSION` are required; the build fails without them.

### K8ssandra Management API variant

The Dockerfile can also produce a variant that carries the K8ssandra Management API, copied from the pinned k8ssandra base image:

```bash
docker build -t axonops-cassandra:local-mgmtapi \
  --build-arg CASSANDRA_VERSION=5.0.9 \
  --build-arg CASSANDRA_SHA512=$(jq -r '.versions["5.0.9"]' cassandra/versions.json) \
  --build-arg CQLAI_VERSION=0.1.7 \
  --build-arg INSTALL_K8SSANDRA_API=true \
  --build-arg K8SSANDRA_API_VERSION=0.1.120 \
  --build-arg K8SSANDRA_BASE_DIGEST=sha256:... \
  cassandra/5.0
```

With the switch off — the default — no Management API components are present and the k8ssandra base image is never pulled. This variant is not published by the pipeline yet; for K8ssandra Operator deployments use the [k8ssandra image](../k8ssandra/README.md).

## Supported versions

Apache Cassandra 5.0.1 through 5.0.9. Versions and their checksums live in [`versions.json`](versions.json), which is the single source of truth for the build matrix. To add a version, fetch its checksum from Apache and add an entry:

```bash
curl -s https://archive.apache.org/dist/cassandra/5.0.10/apache-cassandra-5.0.10-bin.tar.gz.sha512
```

## Pipelines

Trigger commands for the production and development pipelines are in [PIPELINES.md](../PIPELINES.md).

| Workflow | Purpose |
|----------|---------|
| `cassandra-build-and-test.yml` | Builds and tests on pull requests; publishes nothing |
| `cassandra-publish-signed.yml` | Production build, publish and cosign signing from a tag on `main` |
| `cassandra-development-publish-signed.yml` | Development build published to the `-dev` image path |

Every published image is signed with keyless Sigstore cosign:

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/axonops/axonops-containers" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/axonops/cassandra/cassandra:5.0.9-2.0.31-1.0.0
```

## Support

Maintained by [AxonOps](https://axonops.com). For support, contact us at [axonops.com/contact](https://axonops.com/contact).
