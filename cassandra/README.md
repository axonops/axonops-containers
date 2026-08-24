# AxonOps Apache Cassandra Container

**English** | [Français](README.fr.md)

[![GHCR Package](https://img.shields.io/badge/GHCR-Package-blue?logo=docker)](https://github.com/axonops/axonops-containers/pkgs/container/cassandra%2Fcassandra)

Apache Cassandra with the AxonOps monitoring and management agent, without the K8ssandra Management API. For running Cassandra outside Kubernetes, or inside it without the K8ssandra Operator.

If you are deploying with the K8ssandra Operator, use [`ghcr.io/axonops/k8ssandra/cassandra`](../k8ssandra/README.md) instead.

## How it is built

There is no separate Dockerfile. This image is [`k8ssandra/5.0/Dockerfile`](../k8ssandra/5.0/Dockerfile) built with `INCLUDE_MGMT_API=false`, which:

- removes `/opt/management-api` and `/opt/cdc_agent`
- removes the Management API java agent from `cassandra-env.sh`, which the base image bakes in
- starts Cassandra directly instead of through the Management API entrypoint
- healthchecks Cassandra on the native transport instead of the Management API liveness endpoint (the agent check is the same in both)

Everything else — base image, AxonOps agent, cqlai, jemalloc — is identical to the K8ssandra image, and one Dockerfile serves both.

**Size caveat:** the Management API files are removed in a derived layer, so they are gone from the running container but the base image layers still carry them. The image download is around 93 MB larger than its contents warrant.

## Image

```
ghcr.io/axonops/cassandra/cassandra:{CASSANDRA}-{AGENT}-{BUILD}
```

For example `ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.0.0` is Apache Cassandra 5.0.8 with AxonOps agent 2.0.31, from build 1.0.0.

| Tag form | Mutable? | Meaning |
|----------|----------|---------|
| `5.0.8-2.0.31-1.0.0` | No | Exact Cassandra version, exact agent version, exact build |
| `5.0.8-2.0.31` | Yes | Latest build for that Cassandra + agent pair |
| `5.0.8` | Yes | Latest agent and build for that Cassandra version |
| `5.0-latest` | Yes | Latest 5.0.x patch release |
| `latest` | Yes | Latest version overall |

The agent component of a tag is always a concrete version. Passing `latest` as the agent version to the pipeline resolves it to the version actually installed before any tag is written.

Development builds go to `ghcr.io/axonops/development/cassandra`, alongside the other components' development images, and are not for production use.

Pin by digest in anything you care about:

```bash
docker buildx imagetools inspect ghcr.io/axonops/cassandra/cassandra:5.0.8
```

## Quick start

```bash
docker run -d --name cassandra \
  -e AXON_AGENT_ORG=your-org \
  -e AXON_AGENT_KEY=your-agent-key \
  -e AXON_AGENT_CLUSTER_NAME=my-cluster \
  -p 9042:9042 \
  ghcr.io/axonops/cassandra/cassandra:5.0.8
```

`AXON_AGENT_ORG` is required; the container refuses to start without it. Check progress with:

```bash
docker logs -f cassandra
docker exec cassandra nodetool status
docker exec cassandra cqlai -e "SELECT release_version FROM system.local;"
```

Runnable multi-node examples using this image are in
[`docker-compose/`](../docker-compose/README.md): [01](../docker-compose/01-cassandra-cluster/)
monitors the cluster with a self-hosted AxonOps stack,
[02](../docker-compose/02-saas-cassandra-cluster/) reports to AxonOps SaaS.

## Configuration

### AxonOps agent

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

### Cassandra

The same `CASSANDRA_*` variables the K8ssandra image and the official Cassandra image accept. They are applied to `cassandra.yaml` and `cassandra-rackdc.properties` at startup.

| Variable | Default | Description |
|----------|---------|-------------|
| `CASSANDRA_SEEDS` | own broadcast address | Comma-separated seed list |
| `CASSANDRA_CLUSTER_NAME` | `Test Cluster` | Cluster name |
| `CASSANDRA_LISTEN_ADDRESS` | `auto` | `auto` resolves to the container IP |
| `CASSANDRA_BROADCAST_ADDRESS` | listen address | Address other nodes use |
| `CASSANDRA_RPC_ADDRESS` | `0.0.0.0` | CQL bind address |
| `CASSANDRA_BROADCAST_RPC_ADDRESS` | broadcast address | Address clients are told to use |
| `CASSANDRA_NUM_TOKENS` | Cassandra default | vnode count |
| `CASSANDRA_ENDPOINT_SNITCH` | Cassandra default | Snitch |
| `CASSANDRA_NATIVE_TRANSPORT_PORT` | `9042` | CQL port |
| `CASSANDRA_AUTHENTICATOR` | `AllowAllAuthenticator` | Set to `PasswordAuthenticator` to require credentials |
| `CASSANDRA_AUTHORIZER` | `AllowAllAuthorizer` | Set to `CassandraAuthorizer` to enforce permissions |
| `CASSANDRA_ROLE_MANAGER` | `CassandraRoleManager` | Role manager implementation |
| `CASSANDRA_DC` | Cassandra default | Datacentre in `cassandra-rackdc.properties` |
| `CASSANDRA_RACK` | Cassandra default | Rack in `cassandra-rackdc.properties` |

A directory mounted at `/config` is copied over `$CASSANDRA_CONF` before those variables are applied, so a mounted `cassandra.yaml` is the way to set anything not listed above.

Multi-node example:

```bash
docker run -d --name cassandra-1 \
  -e AXON_AGENT_ORG=your-org -e AXON_AGENT_KEY=your-agent-key \
  -e CASSANDRA_CLUSTER_NAME=prod -e CASSANDRA_SEEDS=10.0.0.1,10.0.0.2 \
  -e CASSANDRA_DC=dc1 -e CASSANDRA_RACK=rack1 \
  -v /data/cassandra:/var/lib/cassandra \
  --network host \
  ghcr.io/axonops/cassandra/cassandra:5.0.8
```

| Path | Purpose |
|------|---------|
| `/opt/cassandra/conf` | Cassandra configuration |
| `/config` | Optional config overlay, copied over the above at startup |
| `/var/lib/cassandra` | Data directory |
| `/var/log/cassandra` | Cassandra logs |
| `/var/log/axonops/axon-agent.log` | Agent log |
| `/etc/axonops/build-info.txt` | Versions captured at build time, printed in the startup banner |

Cassandra runs as the `cassandra` user, never as root. The agent runs under a supervisor that restarts it on exit with crash-loop backoff ([#154](https://github.com/axonops/axonops-containers/issues/154)); the container lives and dies with the Cassandra process.

### Healthcheck

The container healthcheck (`/usr/local/bin/axonops-healthcheck.sh`, run every 30s) checks two things:

1. **Cassandra** — `nodetool statusbinary` reports the native transport running, and the CQL port is accepting connections. In the K8ssandra image, where the Management API is present, its liveness endpoint is used instead.
2. **AxonOps agent** — the `axon-agent` process is running, so the node is actually being monitored.

By default a dead agent is reported in the healthcheck output but does not make the container unhealthy: Cassandra is still serving CQL, and failing the check can make an orchestrator restart or drain a node that is doing useful work. Set `HEALTHCHECK_REQUIRE_AGENT=true` to treat a dead agent as a failure.

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTHCHECK_REQUIRE_AGENT` | `false` | `true` makes the container unhealthy when `axon-agent` is not running |

```bash
# Current status and the last check's output
docker inspect --format '{{.State.Health.Status}}' cassandra-1
docker inspect --format '{{(index .State.Health.Log 0).Output}}' cassandra-1

# Run it by hand
docker exec cassandra-1 /usr/local/bin/axonops-healthcheck.sh
```

The agent is started only once Cassandra is up, so it is normally absent for the first part of the 120s start period. That is what the start period is for — with `HEALTHCHECK_REQUIRE_AGENT=true` on a slow-starting node, raise it rather than lowering the retries.

## Supported versions

Apache Cassandra 4.0.0 through 4.0.21, 4.1.0 through 4.1.12, and 5.0.1 through 5.0.9 — 42 versions in all (4.0.2 and 4.0.16 have no base image and are skipped). The matrix is bounded by the `K8SSANDRA_VERSIONS` repository variable, which pins a base image digest per Cassandra version — a version can only be built here once it has an entry there.

## Building locally

```bash
DIGEST=$(gh api /repos/axonops/axonops-containers/actions/variables/K8SSANDRA_VERSIONS \
  --jq '.value | fromjson | ."5.0.9+0.1.125"')

docker build -t axonops-cassandra:local \
  --build-arg CASSANDRA_VERSION=5.0.9 \
  --build-arg MAJOR_VERSION=5.0 \
  --build-arg K8SSANDRA_BASE_DIGEST="$DIGEST" \
  --build-arg K8SSANDRA_API_VERSION=0.1.125 \
  --build-arg INCLUDE_MGMT_API=false \
  --build-arg CQLAI_VERSION=0.1.7 \
  k8ssandra/5.0
```

Drop `INCLUDE_MGMT_API=false` to build the K8ssandra image instead — it defaults to `true`.

## Pipelines

Trigger commands are in [PIPELINES.md](../PIPELINES.md).

| Workflow | Purpose |
|----------|---------|
| `cassandra-build-and-test.yml` | Builds and tests on pull requests; publishes nothing |
| `cassandra-publish-signed.yml` | Production build, publish and cosign signing from a tag on `main` |
| `cassandra-development-publish-signed.yml` | Development build published to `ghcr.io/axonops/development/cassandra` |

Every published image is signed with keyless Sigstore cosign:

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/axonops/axonops-containers" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/axonops/cassandra/cassandra:5.0.8-2.0.31-1.0.0
```

## Support

Maintained by [AxonOps](https://axonops.com). For support, contact us at [axonops.com/contact](https://axonops.com/contact).
