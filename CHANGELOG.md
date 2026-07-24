# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Process supervision and automatic restart for the `axon-agent` sidecar process in the k8ssandra (`k8ssandra/{4.0,4.1,5.0}/axonops-entrypoint.sh`) and strimzi (`strimzi/files/axonops-wrapper.sh`) container images. If the agent exits it is now restarted automatically, with crash-loop protection (>5 restarts in 60s triggers a 30s backoff) and death/restart events logged to stdout and `/var/log/axonops/axon-agent.log`. Previously a dead agent was never detected or restarted for the life of the container ([#154](https://github.com/axonops/axonops-containers/issues/154)).
- Strimzi operator 0.51.0, 1.0.1 and 1.1.0 added to the build matrix across all four strimzi CI workflows (`strimzi-build-and-test`, `strimzi-development-build-and-test`, `strimzi-publish-signed`, `strimzi-development-publish-signed`), with pinned base-image digests and `VERSION_MATRIX` entries. Supported Kafka versions: 0.51.0 → 4.1.0/4.1.1/4.2.0; 1.0.1 → 4.1.0/4.1.1/4.1.2/4.2.0; 1.1.0 → 4.2.0/4.2.1/4.3.0.
- OpenSearch 3.7.0 support: new `axonops/axondb-search/opensearch/3.7.0/` Dockerfile directory.
- OpenSearch 3.7.0 added to the `axondb-search-build-and-test` and `axondb-search-development-publish-signed` CI matrix alongside 3.3.2.
- `opensearch_version` input (default `3.7.0`) added to `axondb-search-publish-signed` workflow to allow version-targeted production releases.
- Cassandra 5.0.7 added to `k8ssandra-build-and-test` secondary version matrix.
- Cassandra 5.0.8 support across k8ssandra and AxonDB TimeSeries CI workflows: build-and-test, nightly security scan, publish-signed, development-publish-signed, e2e-test, cloud-install-test, backups-publish-signed.
- New `axonops/axondb-timeseries/5.0.8/` Dockerfile directory for AxonDB TimeSeries images.
- New helper script `k8ssandra/scripts/set_latest_k8ssandra_version.sh` that reads the `K8SSANDRA_VERSIONS` GitHub Actions repository variable and sets `K8SSANDRA_VERSION` to the highest Cassandra semver found. Supports `--repo OWNER/REPO` and `--dry-run`; requires the `gh` CLI and `jq`.

### Fixed
- Bumped all k8ssandra base images from `cass-management-api v0.1.113` to `v0.1.120` (newer UBI 9 base), resolving unignored CRITICAL/HIGH CVEs detected by the nightly Trivy scan.
- Fixed stale digest for Cassandra 5.0.6 that caused the `security-scan (5.0.6)` job to fail before Trivy could run.
- Added new Cassandra versions available in k8ssandra v0.1.120: 4.0.20, 4.1.11, 5.0.8.


### Changed
- k8ssandra 4.0/4.1 containers no longer exit when `axon-agent` dies; the agent is now restarted under supervision and the container lifecycle is tied to the Management API only (matching 5.0 behaviour).
- Default Cassandra version bumped to 5.0.8 in all workflow inputs that previously defaulted to 5.0.6 or 5.0.7.
- `k8ssandra-development-publish-signed.yml` `:latest` and `:5.0-latest` tags now point to 5.0.8 (previously 5.0.6).
- Updated `axondb-timeseries/.trivyignore` comment for CVE-2026-27314 to note it is fixed in 5.0.7+ and retained only for older matrix versions.
- Bumped the Strimzi example manifests (`examples/strimzi/{cloud,local-disk,on-premises}/*.yaml`) from `apiVersion: kafka.strimzi.io/v1beta2` to `kafka.strimzi.io/v1` for the `Kafka`, `KafkaConnect` and `KafkaNodePool` resources. The `v1` API is served by Strimzi operator ≥0.49.0 and is the only version served from 1.0.1 onwards (where `v1beta2` is dropped), so this keeps the examples working against the newly added 1.0.1/1.1.0 operators. Requires Strimzi operator ≥0.49.0.
