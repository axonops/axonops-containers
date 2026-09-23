<!--
  GENERATED FILE - DO NOT EDIT.
  Source: versions.yaml
  Regenerate: ./scripts/update-versions.sh
-->

# Current Versions

The current release of every container image and Helm chart published from this
repository. Registry data last verified **2026-09-23**.

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
| `ghcr.io/axonops/axondb-search` | `3.7.0-1.6.1` | `sha256:a7f2d508a54b3f0d890e70bf0bec1710345ea34696aa0a2bc66c66a0d075f565` | `axondb-search-1.6.1` |
| `ghcr.io/axonops/axondb-search-backups` | `1.2.0` | `sha256:8f6cb72748ad243a1083d9323e5170cd2b881e5bff8d12280a855faded5b439a` | `—` |
| `registry.axonops.com/axonops-public/axonops-docker/axon-server` | `2.0.39` | `sha256:b7c41009929155942c34df77b262812fe1c39a32cdf7e132ef3437654a4bc4c1` | `—` |
| `registry.axonops.com/axonops-public/axonops-docker/axon-dash` | `2.0.39` | `sha256:4cffd1d1e724a479c8ec489299972a43e0da0eef797e7aa27aa3acf6ae28423d` | `—` |
| `ghcr.io/axonops/axonops-schema-registry` | `0.2.1` | `sha256:352a644f75c9f6ddedbbdb8c0f9c897573edc148cea1c1b1230640681b9b9164` | `axonops-schema-registry-0.2.0-0.0.1` |
| `ghcr.io/axonops/k8ssandra/cassandra` | `5.0.9-v0.1.125-1.6.2` | `sha256:a45e8b26f64a65c61e5ec1d84f096c9cf8c97f645117ab3a0d9e8372d670dd83` | `k8ssandra-1.6.2` |
| `ghcr.io/axonops/cassandra/cassandra` | `5.0.9-2.0.32-1.2.2` | `sha256:1711a7e0f85a6eb7e8cee97335ecf2c99019280723f9e76881df64fca67ba911` | `cassandra-1.2.2` |
| `ghcr.io/axonops/strimzi/kafka` | `1.1.0-4.3.0-2.0.20-0.1.26` | `sha256:f71af17b1a42bc9fe86837db0d584e9a534067a7124eb38672e5e964f51d5d87` | `strimzi-0.1.26` |

## Helm charts

| Chart | Version | Git tag |
|-------|---------|---------|
| `oci://ghcr.io/axonops/charts/axonops` | `1.1.28` | `helm-1.1.28` |
| `oci://ghcr.io/axonops/charts/axon-server` | `2.1.19` | `helm-1.1.28` |
| `oci://ghcr.io/axonops/charts/axon-dash` | `0.1.12` | `helm-1.1.28` |
| `oci://ghcr.io/axonops/charts/axondb-timeseries` | `0.2.0` | `helm-1.1.28` |
| `oci://ghcr.io/axonops/charts/axondb-search` | `0.3.0` | `helm-1.1.28` |

## Pinned references

Copy these straight into a compose file, manifest or Helm values file.

```
ghcr.io/axonops/axondb-timeseries@sha256:1ae990a737d36b7c6f8eb92d6d3baf5234e5eae2a4e37fa208acd1108cad934c
ghcr.io/axonops/axondb-search@sha256:a7f2d508a54b3f0d890e70bf0bec1710345ea34696aa0a2bc66c66a0d075f565
ghcr.io/axonops/axondb-search-backups@sha256:8f6cb72748ad243a1083d9323e5170cd2b881e5bff8d12280a855faded5b439a
registry.axonops.com/axonops-public/axonops-docker/axon-server@sha256:b7c41009929155942c34df77b262812fe1c39a32cdf7e132ef3437654a4bc4c1
registry.axonops.com/axonops-public/axonops-docker/axon-dash@sha256:4cffd1d1e724a479c8ec489299972a43e0da0eef797e7aa27aa3acf6ae28423d
ghcr.io/axonops/axonops-schema-registry@sha256:352a644f75c9f6ddedbbdb8c0f9c897573edc148cea1c1b1230640681b9b9164
ghcr.io/axonops/k8ssandra/cassandra@sha256:a45e8b26f64a65c61e5ec1d84f096c9cf8c97f645117ab3a0d9e8372d670dd83
ghcr.io/axonops/cassandra/cassandra@sha256:1711a7e0f85a6eb7e8cee97335ecf2c99019280723f9e76881df64fca67ba911
ghcr.io/axonops/strimzi/kafka@sha256:f71af17b1a42bc9fe86837db0d584e9a534067a7124eb38672e5e964f51d5d87
```

## Notes

- **axondb-timeseries** — The publish workflow builds one Cassandra version per run (`cassandra_dir` input). Dockerfiles exist for 5.0.6 through 5.0.9, but only the tags listed here are published.
- **axondb-search** — Dockerfiles exist for OpenSearch 3.3.2 and 3.7.0; 1.6.1 was built for 3.7.0 only. 1.6.1 fixes three entrypoint bugs in how opensearch.yml is written: OPENSEARCH_DISCOVERY_TYPE is now applied, path.repo and plugins.security.disabled replace their key instead of appending to it, and the plugins.security.ssl.http delete no longer uses sed -i.
- **axondb-search-backups** — The published tag does not correspond to any `axondb-search-backups-*` git tag in this repository (the newest of those is 0.0.26) and TAG_CHANGELOG.md still lists the old `3.3.2-0.0.x` image tags. Reconcile the tagging scheme before pinning anything to this image.
- **axon-server** — Built and published outside this repository; consumed by the compose stack and the Helm charts.
- **axon-dash** — Built and published outside this repository; consumed by the compose stack and the Helm charts.
- **axonops-schema-registry** — Pre-release. The published tags do not yet follow the documented `{SR_VERSION}-{CONTAINER_VERSION}` pattern, and the newest tags in the registry are feature builds (`0.4.0-mcp-phase7`), not releases.
- **k8ssandra-cassandra** — Each release publishes one tag per Cassandra version. Build 1.6.2 covers the 4.0, 4.1 and 5.0 lines listed in build_matrix, built against k8ssandra Management API v0.1.125. `current.digest` is the digest of the 5.0.9 variant only; every other Cassandra version has its own digest.
- **cassandra** — Build 1.2.2 publishes every Cassandra version listed in build_matrix, each with AxonOps agent 2.0.32, plus the floating `{cassandra}-{agent}`, `{cassandra}`, `5.0-latest` and `latest` tags. `current.digest` is the digest of the 5.0.9 variant, which `latest` and `5.0-latest` also resolve to; every other Cassandra version has its own digest.
- **strimzi-kafka** — Build 0.1.26 publishes one tag per supported operator/Kafka combination (operators 0.46.1 through 1.1.0, AxonOps agent 2.0.20). `current.tag` is the newest combination; see the VERSION_MATRIX in .github/workflows/strimzi-publish-signed.yml for the full set.
- **chart-axonops** — Chart version comes from axonops/charts/axonops/Chart.yaml.

## Previous releases

Newest-first, per component. Full git-tag-to-image history lives in
[TAG_CHANGELOG.md](TAG_CHANGELOG.md).

- **axondb-timeseries**: `5.0.6-1.2.0`, `5.0.6-1.1.0`, `5.0.6-1.0.0`
- **axondb-search**: `3.7.0-1.6.0`, `3.3.2-1.5.0`, `3.3.2-1.4.0`, `3.3.2-1.3.0`, `3.3.2-1.2.0`
- **axon-server**: `2.0.38`, `2.0.37`, `2.0.36`, `2.0.35`
- **axon-dash**: `2.0.38`, `2.0.37`, `2.0.36`
- **axonops-schema-registry**: `0.2.0`, `0.1.0`, `0.0.1`
- **k8ssandra-cassandra**: `5.0.9-v0.1.125-1.6.1`, `5.0.9-v0.1.125-1.6.0`, `5.0.8-v0.1.120-1.5.6`, `5.0.8-v0.1.120-1.5.5`, `5.0.8-v0.1.120-1.5.3`
- **cassandra**: `5.0.9-2.0.32-1.2.1`, `5.0.9-2.0.31-1.2.0`, `5.0.8-2.0.31-1.1.0`, `5.0.8-2.0.31-1.0.0`
- **strimzi-kafka**: `1.1.0-4.3.0-2.0.20-0.1.25`, `1.1.0-4.3.0-2.0.20-0.1.24`
- **chart-axonops**: `1.1.27`, `1.1.23`, `1.1.21`
- **chart-axon-server**: `2.1.18`, `2.1.17`, `2.1.16`, `2.1.14`
- **chart-axon-dash**: `0.1.11`, `0.1.10`
- **chart-axondb-timeseries**: `0.1.7`
- **chart-axondb-search**: `0.2.9`
