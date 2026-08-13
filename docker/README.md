# Moved

The Docker Compose stack that lived here is now
[`docker-compose/00-axonops-platform/`](../docker-compose/00-axonops-platform/README.md).

Every Compose stack in this repository now lives under
[`docker-compose/`](../docker-compose/README.md), following one set of
conventions:

| Example | What it deploys |
|---------|-----------------|
| [00-axonops-platform](../docker-compose/00-axonops-platform/) | The AxonOps platform on its own — what used to be here |
| [01-cassandra-cluster](../docker-compose/01-cassandra-cluster/) | The platform plus a monitored 3-node Apache Cassandra cluster |
| [02-saas-cassandra-cluster](../docker-compose/02-saas-cassandra-cluster/) | A Cassandra cluster reporting to AxonOps SaaS |

The stack also picked up fixes in the move — as it stood here it could not
start from a clean state. See
[Image Pinning: Tags vs Checksums](../docker-compose/00-axonops-platform/README.md#image-pinning-tags-vs-checksums)
for the pinning guidance that used to be at `docker/README.md`.
