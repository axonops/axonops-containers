<!--
  GENERATED FILE - DO NOT EDIT.
  Source: versions.yaml
  Regenerate: ./scripts/update-versions.sh
-->

# Current Versions

The current release of every container image and Helm chart published from this
repository. Registry data last verified **2026-08-13**.

Components are listed in deployment order: data stores, then the AxonOps
services that depend on them, then the operator images, then the Helm charts.

**Pin by digest, not by tag.** A digest is a cryptographic checksum of the exact
image; a tag is a mutable pointer that can be moved. See
[Gold Standard Security Deployment](README.md#gold-standard-security-deployment)
for the full rationale and the verification steps.

## Images

| Component | Current tag | Digest | Git tag |
|-----------|-------------|--------|---------|
| `ghcr.io/axonops/axondb-timeseries` | `5.0.8-1.4.0` | `sha256:1ae990a737d36b7c6f8eb92d6d3baf5234e5eae2a4e37fa208acd1108cad934c` | `axondb-timeseries-1.4.0` |
| `ghcr.io/axonops/axondb-search` | `3.7.0-1.6.0` | `sha256:4291a1b3c099639e2cf7178eb27c576906e6404c3baaefa0634068d1ab53f41d` | `axondb-search-1.6.0` |
| `ghcr.io/axonops/axondb-search-backups` | `1.2.0` | `sha256:8f6cb72748ad243a1083d9323e5170cd2b881e5bff8d12280a855faded5b439a` | `—` |
| `registry.axonops.com/axonops-public/axonops-docker/axon-server` | `2.0.35` | `sha256:c75f66727d158bcc3fc033f097f998b05fa1e8f45e3fef600c53fc8c107472e7` | `—` |
| `registry.axonops.com/axonops-public/axonops-docker/axon-dash` | `2.0.37` | `sha256:7db6b2590b3e65bcf39c2d8a5b76b098c57ef161333b80a488dc32d676dc4362` | `—` |
| `ghcr.io/axonops/axonops-schema-registry` | `0.2.1` | `sha256:352a644f75c9f6ddedbbdb8c0f9c897573edc148cea1c1b1230640681b9b9164` | `axonops-schema-registry-0.2.0-0.0.1` |
| `ghcr.io/axonops/k8ssandra/cassandra` | `5.0.8-v0.1.120-1.5.6` | `sha256:9c50b1b0ed49a3badffedaf7f171e4405e8c48440b76b0c79b18ead0e418478c` | `k8ssandra-1.5.6` |
| `ghcr.io/axonops/cassandra/cassandra` | `—` | `—` | `cassandra-1.0.0` |
| `ghcr.io/axonops/strimzi/kafka` | `1.1.0-4.3.0-2.0.20-0.1.26` | `sha256:f71af17b1a42bc9fe86837db0d584e9a534067a7124eb38672e5e964f51d5d87` | `strimzi-0.1.26` |

## Helm charts

| Chart | Version | Git tag |
|-------|---------|---------|
| `oci://ghcr.io/axonops/charts/axonops` | `1.1.21` | `helm-1.1.21` |
| `oci://ghcr.io/axonops/charts/axon-server` | `2.1.14` | `helm-1.1.21` |
| `oci://ghcr.io/axonops/charts/axon-dash` | `0.1.10` | `helm-1.1.21` |
| `oci://ghcr.io/axonops/charts/axondb-timeseries` | `0.1.7` | `helm-1.1.21` |
| `oci://ghcr.io/axonops/charts/axondb-search` | `0.2.9` | `helm-1.1.21` |

## Pinned references

Copy these straight into a compose file, manifest or Helm values file.

```
ghcr.io/axonops/axondb-timeseries@sha256:1ae990a737d36b7c6f8eb92d6d3baf5234e5eae2a4e37fa208acd1108cad934c
ghcr.io/axonops/axondb-search@sha256:4291a1b3c099639e2cf7178eb27c576906e6404c3baaefa0634068d1ab53f41d
ghcr.io/axonops/axondb-search-backups@sha256:8f6cb72748ad243a1083d9323e5170cd2b881e5bff8d12280a855faded5b439a
registry.axonops.com/axonops-public/axonops-docker/axon-server@sha256:c75f66727d158bcc3fc033f097f998b05fa1e8f45e3fef600c53fc8c107472e7
registry.axonops.com/axonops-public/axonops-docker/axon-dash@sha256:7db6b2590b3e65bcf39c2d8a5b76b098c57ef161333b80a488dc32d676dc4362
ghcr.io/axonops/axonops-schema-registry@sha256:352a644f75c9f6ddedbbdb8c0f9c897573edc148cea1c1b1230640681b9b9164
ghcr.io/axonops/k8ssandra/cassandra@sha256:9c50b1b0ed49a3badffedaf7f171e4405e8c48440b76b0c79b18ead0e418478c
ghcr.io/axonops/strimzi/kafka@sha256:f71af17b1a42bc9fe86837db0d584e9a534067a7124eb38672e5e964f51d5d87
```

## Notes

- **axondb-timeseries** — The publish workflow builds one Cassandra version per run (`cassandra_dir` input). Dockerfiles exist for 5.0.6 through 5.0.9, but only the tags listed here are published.
- **axondb-search** — Dockerfiles exist for OpenSearch 3.3.2 and 3.7.0.
- **axondb-search-backups** — The published tag does not correspond to any `axondb-search-backups-*` git tag in this repository (the newest of those is 0.0.26) and TAG_CHANGELOG.md still lists the old `3.3.2-0.0.x` image tags. Reconcile the tagging scheme before pinning anything to this image.
- **axon-server** — Built and published outside this repository; consumed by the compose stack and the Helm charts.
- **axon-dash** — Built and published outside this repository; consumed by the compose stack and the Helm charts.
- **axonops-schema-registry** — Pre-release. The published tags do not yet follow the documented `{SR_VERSION}-{CONTAINER_VERSION}` pattern, and the newest tags in the registry are feature builds (`0.4.0-mcp-phase7`), not releases.
- **k8ssandra-cassandra** — Each release publishes one tag per Cassandra version. Build 1.5.6 covers 5.0.1, 5.0.2, 5.0.3, 5.0.5, 5.0.6, 5.0.7 and 5.0.8 — 5.0.4 was last built at 1.5.5 and 5.0.9 has never been published here. `current.digest` is the digest of the 5.0.8 variant only; every other Cassandra version has its own digest.
- **cassandra** — Tagged (cassandra-1.0.0) but not yet published — the repository has no tags in the registry. Build matrix is Cassandra 5.0.1 through 5.0.8.
- **strimzi-kafka** — Build 0.1.26 publishes one tag per supported operator/Kafka combination (operators 0.46.1 through 1.1.0, AxonOps agent 2.0.20). `current.tag` is the newest combination; see the VERSION_MATRIX in .github/workflows/strimzi-publish-signed.yml for the full set.
- **chart-axonops** — Chart version comes from axonops/charts/axonops/Chart.yaml.

## Previous releases

Newest-first, per component. Full git-tag-to-image history lives in
[TAG_CHANGELOG.md](TAG_CHANGELOG.md).

- **axondb-timeseries**: `5.0.6-1.2.0`, `5.0.6-1.1.0`, `5.0.6-1.0.0`
- **axondb-search**: `3.3.2-1.5.0`, `3.3.2-1.4.0`, `3.3.2-1.3.0`, `3.3.2-1.2.0`
- **axon-server**: `2.0.34`
- **axon-dash**: `2.0.36`
- **axonops-schema-registry**: `0.2.0`, `0.1.0`, `0.0.1`
- **k8ssandra-cassandra**: `5.0.8-v0.1.120-1.5.5`, `5.0.8-v0.1.120-1.5.3`, `5.0.8-v0.1.120-1.5.2`
- **strimzi-kafka**: `1.1.0-4.3.0-2.0.20-0.1.25`, `1.1.0-4.3.0-2.0.20-0.1.24`
