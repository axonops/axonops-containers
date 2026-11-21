# AxonOps Deployment Guide

**English** | [Français](AXONOPS_DEPLOYMENT.fr.md) | [Español](AXONOPS_DEPLOYMENT.es.md) | [Galego](AXONOPS_DEPLOYMENT.gl.md)

This guide installs a self-hosted AxonOps stack on Kubernetes with the script in [axonops/](axonops/). The [axonops/README.md](axonops/README.md) lists every setting.

## Components

| Component | Purpose |
| --- | --- |
| axondb-timeseries | Metrics store (Cassandra) |
| axondb-search | Logs and events (OpenSearch) |
| axon-server | Receives data from the agents and serves the API |
| axon-dash | Web UI, with the `axon-reporting` sidecar for Reports v2 |

All four are installed in one namespace, `AXONOPS_NAMESPACE` (default `axonops`), from the charts at `oci://ghcr.io/axonops/charts`. TLS on the databases is off by default, and so is cert-manager.

## Quick start

```bash
cd examples/axonops
source axonops-config.env
export AXON_SEARCH_PASSWORD="$(openssl rand -base64 24)"
export AXON_SERVER_CQL_PASSWORD="$(openssl rand -base64 24)"
./axonops-setup.sh
```

The script writes the Helm values and the axon-server configuration Secret to `axonops/generated/`, installs each release with `helm upgrade --install --wait`, and prints how to reach the dashboard. Re-running it upgrades the releases in place. Keep the same passwords for every run.

## Storage

| Mode | Settings | Use |
| --- | --- | --- |
| PVC (default) | `AXON_TIMESERIES_STORAGE_CLASS`, `AXON_SEARCH_STORAGE_CLASS`, `AXON_*_VOLUME_SIZE` | Any cluster with a StorageClass |
| hostPath | `AXON_TIMESERIES_USE_HOSTPATH=true`, `AXON_SEARCH_USE_HOSTPATH=true` | Single-node test clusters |
| None | `AXON_*_PERSISTENCE_ENABLED=false` | Throwaway tests; data is lost with the pod |

For hostPath, create the directories on the node before running the script:

```bash
sudo mkdir -p /data/axon-timeseries /data/axon-search
sudo chown -R 999:999 /data/axon-timeseries /data/axon-search
```

## Dashboard access

| Method | Settings | Address |
| --- | --- | --- |
| Port-forward (default) | none | `kubectl port-forward -n "$AXONOPS_NAMESPACE" svc/axon-dash-svc 3000:3000`, then <http://localhost:3000> |
| NodePort | `AXON_DASH_NODEPORT_ENABLED=true` | `http://<node-ip>:<port>`; the script prints the port |
| Ingress | `AXON_DASH_INGRESS_ENABLED=true`, `AXON_DASH_INGRESS_HOST`, `AXON_DASH_INGRESS_CLASS_NAME` | `https://<host>` |

## Connecting Kafka and Cassandra

Agents in the same cluster connect to:

```text
axon-server-agent.<AXONOPS_NAMESPACE>.svc.cluster.local:1888   (TLS disabled)
```

The [Strimzi on-premises](strimzi/on-premises/), [Strimzi local-disk](strimzi/local-disk/) and [K8ssandra](k8ssandra/README.md#examples) examples read `AXONOPS_NAMESPACE`, `AXON_SERVER_ORG_NAME` and `AXON_SERVER_AGENTS_PORT` from `axonops/axonops-config.env`. Source it before their own configuration file:

```bash
source examples/axonops/axonops-config.env
source examples/strimzi/on-premises/strimzi-config.env
```

For agents outside the cluster, enable the gRPC Ingress with `AXON_SERVER_AGENT_INGRESS_ENABLED=true` and `AXON_SERVER_AGENT_INGRESS_HOST`, and point the agents at that host on port 443 with `AXON_AGENT_TLS_MODE=TLS`.

## Verify

```bash
helm list -n "$AXONOPS_NAMESPACE"
kubectl get pods,pvc -n "$AXONOPS_NAMESPACE"
kubectl logs -n "$AXONOPS_NAMESPACE" deploy/axon-server --tail=50
```

## Remove

```bash
for r in axon-dash axon-server axondb-search axondb-timeseries; do
  helm uninstall "$r" -n "$AXONOPS_NAMESPACE"
done
kubectl delete secret axon-server-config -n "$AXONOPS_NAMESPACE"
kubectl delete pvc --all -n "$AXONOPS_NAMESPACE"   # deletes all AxonOps data
kubectl delete namespace "$AXONOPS_NAMESPACE"
```

## Production notes

- Use a StorageClass with backups and size the volumes for your retention.
- Set a licence key with `AXON_SERVER_LICENSE_KEY`.
- To turn on TLS between axon-server and the databases, set `AXON_TIMESERIES_TLS_ENABLED=true` and `AXON_SEARCH_TLS_ENABLED=true`. The certificates come from cert-manager (`CERT_MANAGER_INSTALL=true` installs it) or from your own Secrets; see [axonops/README.md](axonops/README.md#tls).
- Store the generated passwords in a secrets manager; `axonops/generated/` holds them in plain text.
- The [AxonOps meta-chart](../axonops/charts/axonops/README.md) installs the same stack as a single Helm release, which suits GitOps tools better than a script.

## Related

- [axonops/README.md](axonops/README.md): every setting of the script
- [Deployment guide](DEPLOYMENT_GUIDE.md)
- [AxonOps documentation](https://docs.axonops.com)
