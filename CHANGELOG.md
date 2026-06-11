# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Cassandra 5.0.7 added to `k8ssandra-build-and-test` secondary version matrix.
- Cassandra 5.0.8 support across k8ssandra and AxonDB TimeSeries CI workflows: build-and-test, nightly security scan, publish-signed, development-publish-signed, e2e-test, cloud-install-test, backups-publish-signed.
- New `axonops/axondb-timeseries/5.0.8/` Dockerfile directory for AxonDB TimeSeries images.

### Changed
- Default Cassandra version bumped to 5.0.8 in all workflow inputs that previously defaulted to 5.0.6 or 5.0.7.
- `k8ssandra-development-publish-signed.yml` `:latest` and `:5.0-latest` tags now point to 5.0.8 (previously 5.0.6).
- Updated `axondb-timeseries/.trivyignore` comment for CVE-2026-27314 to note it is fixed in 5.0.7+ and retained only for older matrix versions.
