# Deployment Guide

**English** | [Français](DEPLOYMENT_GUIDE.fr.md) | [Español](DEPLOYMENT_GUIDE.es.md) | [Galego](DEPLOYMENT_GUIDE.gl.md)

These examples deploy AxonOps, and Kafka or Cassandra clusters monitored by AxonOps, on Kubernetes. Each example directory is self-contained: a configuration file, the manifests or script, and a README with the exact steps.

## Examples

| Directory | Deploys | AxonOps target |
| --- | --- | --- |
| [axonops/](axonops/) | Self-hosted AxonOps: server, dashboard, Timeseries and Search databases | - |
| [strimzi/cloud/](strimzi/cloud/) | Strimzi Kafka on dynamically provisioned volumes | AxonOps Cloud |
| [strimzi/on-premises/](strimzi/on-premises/) | Strimzi Kafka on dynamically provisioned volumes | Self-hosted AxonOps |
| [strimzi/local-disk/](strimzi/local-disk/) | Strimzi Kafka on hostPath volumes pinned to nodes | Self-hosted AxonOps |
| [k8ssandra/](k8ssandra/) | Cassandra with the K8ssandra operator | AxonOps Cloud or self-hosted |

Guides: [AxonOps](AXONOPS_DEPLOYMENT.md), [Strimzi](STRIMZI_DEPLOYMENT.md), [K8ssandra](K8SSANDRA_DEPLOYMENT.md), [node selectors for local disks](NODE_SELECTOR_GUIDE.md).

## Prerequisites

- Kubernetes 1.27 or newer and a `kubectl` context with cluster-admin rights
- `helm` 3.8 or newer
- `envsubst`, from the `gettext` package: `brew install gettext` on macOS, `apt-get install gettext-base` on Debian and Ubuntu, `dnf install gettext` on RHEL
- A default StorageClass, except for `strimzi/local-disk/`

## How the examples work

Every example follows the same pattern:

1. `cd` into the example directory and `source` its `.env` file. Each file is a list of `export` lines; edit it, or export overrides before sourcing it. Values that are already set are kept, and values derived from them follow.
2. Export secrets in the shell instead of writing them in the file: `AXON_SEARCH_PASSWORD` and `AXON_SERVER_CQL_PASSWORD` for AxonOps, `AXON_AGENT_KEY` for AxonOps Cloud.
3. Apply the manifests with `envsubst < file.yaml | kubectl apply -f -`, or run the example script.

Nothing is tied to a fixed namespace. Each component has one variable:

| Variable | Default | Used by |
| --- | --- | --- |
| `AXONOPS_NAMESPACE` | `axonops` | `axonops/`, and the Kafka and Cassandra examples to find the AxonOps server |
| `KAFKA_NAMESPACE` | `kafka` | `strimzi/*` |
| `STRIMZI_OPERATOR_NAMESPACE` | `strimzi` | Strimzi operator |
| `K8SSANDRA_NAMESPACE` | `k8ssandra-operator` | `k8ssandra/` |

Agents find a self-hosted server at `axon-server-agent.$AXONOPS_NAMESPACE.svc.cluster.local:1888`. The examples that report to it build this address from `axonops/axonops-config.env`, so source that file first in the same shell.

## Scenarios

### AxonOps only

```bash
cd examples/axonops
source axonops-config.env
export AXON_SEARCH_PASSWORD="$(openssl rand -base64 24)"
export AXON_SERVER_CQL_PASSWORD="$(openssl rand -base64 24)"
./axonops-setup.sh
```

### Kafka monitored by self-hosted AxonOps

Install AxonOps as above, install the [Strimzi operator](STRIMZI_DEPLOYMENT.md#install-the-strimzi-operator), then from the same shell:

```bash
cd ../strimzi/on-premises
source ../../axonops/axonops-config.env
source strimzi-config.env
kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
```

For hostPath volumes on chosen nodes, use [strimzi/local-disk/](strimzi/local-disk/) and its `strimzi-setup.sh` instead.

### Kafka monitored by AxonOps Cloud

```bash
cd examples/strimzi/cloud
source strimzi-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key
kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
```

### Cassandra monitored by AxonOps Cloud

Install the [K8ssandra operator](K8SSANDRA_DEPLOYMENT.md#install-the-k8ssandra-operator), then:

```bash
cd examples/k8ssandra
source k8ssandra-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key
envsubst < axonops-agent-secret.yaml | kubectl apply -f -
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

For a self-hosted server, see the [K8ssandra example](k8ssandra/README.md#examples).

## Rendering for review or GitOps

`envsubst` writes to standard output, so any apply command becomes a render command:

```bash
envsubst < kafka-cluster.yaml > kafka-cluster.rendered.yaml
```

The scripts take `RENDER_ONLY=true` and write to a `generated/` directory, which git ignores. Rendered files can contain passwords and agent keys; do not commit them.

## Support

- [AxonOps documentation](https://docs.axonops.com)
- [Strimzi documentation](https://strimzi.io/docs/operators/latest/)
- [K8ssandra documentation](https://docs.k8ssandra.io/)
