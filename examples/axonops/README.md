# Self-hosted AxonOps on Kubernetes

`axonops-setup.sh` installs a complete AxonOps stack in one namespace using the AxonOps Helm charts:

| Component | Chart | Purpose |
| --- | --- | --- |
| AxonDB Timeseries | `oci://ghcr.io/axonops/charts/axondb-timeseries` | Metrics store (Cassandra) |
| AxonDB Search | `oci://ghcr.io/axonops/charts/axondb-search` | Logs and events (OpenSearch) |
| axon-server | `oci://ghcr.io/axonops/charts/axon-server` | Receives agent data, serves the API |
| axon-dash | `oci://ghcr.io/axonops/charts/axon-dash` | Web UI, with the Reports v2 `axon-reporting` sidecar |

TLS on the databases is off by default, and so is cert-manager. To turn TLS on, see [TLS](#tls).

## Prerequisites

- Kubernetes 1.27 or newer, with a default StorageClass (or set the storage variables below)
- `kubectl` and `helm` 3.8 or newer
- About 4 CPU and 8 GiB of memory free for the default sizes

## Quick start

```bash
cd examples/axonops
source axonops-config.env
export AXON_SEARCH_PASSWORD="$(openssl rand -base64 24)"
export AXON_SERVER_CQL_PASSWORD="$(openssl rand -base64 24)"
./axonops-setup.sh
```

The script waits for every release to become ready, then prints how to reach the dashboard and the address agents should use:

```text
axon-server-agent.axonops.svc.cluster.local:1888
```

Keep the passwords: running the script again with different ones breaks the connection between axon-server and the databases.

## Files

| File | Purpose |
| --- | --- |
| `axonops-config.env` | Main settings. Also read by the Strimzi and K8ssandra examples to find this server. |
| `axonops-setup.sh` | Installs or upgrades the stack. Safe to re-run. |
| `generated/` | Values files and the axon-server Secret written by the script. Contains passwords; ignored by git. |

## Examples

Install into a different namespace with a named StorageClass:

```bash
source axonops-config.env
export AXONOPS_NAMESPACE=monitoring
export AXON_TIMESERIES_STORAGE_CLASS=fast-ssd AXON_SEARCH_STORAGE_CLASS=fast-ssd
export AXON_TIMESERIES_VOLUME_SIZE=100Gi AXON_SEARCH_VOLUME_SIZE=50Gi
./axonops-setup.sh
```

Expose the dashboard and the agent endpoint through an Ingress controller:

```bash
source axonops-config.env
export AXON_DASH_INGRESS_ENABLED=true AXON_DASH_INGRESS_CLASS_NAME=nginx
export AXON_DASH_INGRESS_HOST=axonops.example.com
export AXON_SERVER_AGENT_INGRESS_ENABLED=true
export AXON_SERVER_AGENT_INGRESS_HOST=agents.example.com
./axonops-setup.sh
```

Render the values files and print the commands a real run would execute, without changing the cluster (`RENDER_ONLY=true`):

```bash
source axonops-config.env
RENDER_ONLY=true ./axonops-setup.sh
ls generated/
```

## TLS

TLS between axon-server and the databases is off by default. To turn it on with certificates from cert-manager:

```bash
source axonops-config.env
export AXON_TIMESERIES_TLS_ENABLED=true AXON_SEARCH_TLS_ENABLED=true
export CERT_MANAGER_INSTALL=true   # only needed if cert-manager is not installed yet
./axonops-setup.sh
```

The script creates the self-signed `ClusterIssuer` `selfsigned-cluster-issuer`; set `CLUSTER_ISSUER_CREATE=false` and `CLUSTER_ISSUER_NAME` to use your own. Without cert-manager, put the certificates in a Secret and set `AXON_TIMESERIES_TLS_EXISTING_SECRET` / `AXON_SEARCH_TLS_EXISTING_SECRET` with `AXON_*_CERTMANAGER_ENABLED=false`. For AxonDB Timeseries the script stops when TLS is on and neither source is set, because the database would start without TLS and axon-server could not connect. AxonDB Search falls back to the certificates built into its image.

## Configuration

Set variables in `axonops-config.env`, or export them before sourcing it; values already set are kept. The script has the same defaults, so it also runs without the file.

| Variable | Default | Description |
| --- | --- | --- |
| `AXONOPS_NAMESPACE` | `axonops` | Namespace for every component. `NS_AXONOPS` is still accepted. |
| `AXON_SERVER_ORG_NAME` | `example` | Organisation name. Agents must send the same value as `AXON_AGENT_ORG`. |
| `AXON_SEARCH_PASSWORD` | none, required | OpenSearch admin password |
| `AXON_SERVER_CQL_PASSWORD` | none, required | Timeseries database password |
| `AXON_SEARCH_USER` | `admin` | OpenSearch admin user |
| `AXON_SERVER_CQL_USERNAME` | `axonops` | Timeseries database user |
| `AXON_SERVER_AGENTS_PORT` | `1888` | Port agents connect to |
| `AXON_SERVER_API_PORT` | `8080` | axon-server API port |
| `AXON_SERVER_LICENSE_KEY` | empty | AxonOps licence key |
| `AXON_TIMESERIES_PERSISTENCE_ENABLED` / `AXON_SEARCH_PERSISTENCE_ENABLED` | `true` | Use a PVC. `false` keeps data only for the life of the pod. |
| `AXON_TIMESERIES_STORAGE_CLASS` / `AXON_SEARCH_STORAGE_CLASS` | empty (cluster default) | StorageClass for the PVC |
| `AXON_TIMESERIES_VOLUME_SIZE` / `AXON_SEARCH_VOLUME_SIZE` | `10Gi` | PVC size |
| `AXON_TIMESERIES_HEAP_SIZE` / `AXON_SEARCH_HEAP_SIZE` | `2048M` / `2g` | JVM heap |
| `AXON_TIMESERIES_USE_HOSTPATH` / `AXON_SEARCH_USE_HOSTPATH` | `false` | Store data in a hostPath directory instead of a PVC. Single-node clusters only. |
| `AXON_TIMESERIES_HOSTPATH_DIR` / `AXON_SEARCH_HOSTPATH_DIR` | `/data/axon-timeseries` / `/data/axon-search` | hostPath directory, owned by UID 999 |
| `AXON_TIMESERIES_HOSTPATH_CREATE` / `AXON_SEARCH_HOSTPATH_CREATE` | `false` | Create the hostPath directory with `sudo` on the machine running the script |
| `AXON_DASH_NODEPORT_ENABLED` | `false` | Expose axon-dash as a NodePort Service. The script prints the assigned port. |
| `AXON_DASH_INGRESS_ENABLED`, `AXON_DASH_INGRESS_HOST`, `AXON_DASH_INGRESS_CLASS_NAME` | `false`, `axonops.example.com`, empty | Dashboard Ingress |
| `AXON_*_INGRESS_CERT_ISSUER_ANNOTATION` | empty | cert-manager `ClusterIssuer` added as an Ingress annotation |
| `AXON_SERVER_API_INGRESS_ENABLED`, `AXON_SERVER_API_INGRESS_HOST` | `false`, `api.example.com` | API Ingress |
| `AXON_SERVER_AGENT_INGRESS_ENABLED`, `AXON_SERVER_AGENT_INGRESS_HOST` | `false`, `agents.example.com` | gRPC Ingress for agents outside the cluster |
| `CERT_MANAGER_INSTALL` | `false` | With database TLS on: install cert-manager when it is missing. An installed cert-manager is always reused, never reinstalled. |
| `CLUSTER_ISSUER_CREATE` | `true` | Create `CLUSTER_ISSUER_NAME` as a self-signed `ClusterIssuer` when it does not exist. An existing issuer is never modified. |
| `AXON_TIMESERIES_TLS_ENABLED` / `AXON_SEARCH_TLS_ENABLED` | `false` | TLS on the database. axon-server connects with TLS to match. |
| `AXON_TIMESERIES_CERTMANAGER_ENABLED` / `AXON_SEARCH_CERTMANAGER_ENABLED` | `true` | Issue the database certificate with cert-manager |
| `AXON_TIMESERIES_TLS_EXISTING_SECRET` / `AXON_SEARCH_TLS_EXISTING_SECRET` | empty | Secret with your own TLS material, used instead of cert-manager. With Timeseries TLS on, the script stops unless cert-manager or this Secret provides the certificate. |
| `CLUSTER_ISSUER_NAME` | `selfsigned-cluster-issuer` | Issuer for the database certificates |
| `AXON_DASH_REPORTING_IMAGE_TAG` | `1.0.3` | `axon-reporting` sidecar image tag |
| `AXON_*_CHART` | `oci://ghcr.io/axonops/charts/<chart>` | Chart reference, for example a local path such as `../../axonops/charts/axon-server` |
| `AXON_*_HELM_EXTRA_ARGS` | empty | Extra arguments for each `helm upgrade --install` |
| `HELM_WAIT` | `true` | Install each AxonOps release with `helm --wait`. `false` returns without waiting for the pods; cert-manager always waits. |
| `HELM_TIMEOUT` | `10m` | Timeout for each release when `HELM_WAIT=true` |
| `RENDER_ONLY` | `false` | Write `generated/` and print the commands a real run would execute; install nothing |

Release names (`AXON_TIMESERIES_RELEASE_NAME`, `AXON_SEARCH_RELEASE_NAME`, `AXON_SERVER_RELEASE_NAME`, `AXON_DASH_RELEASE_NAME`) can be changed; the script derives the Service names from them.

## Reports v2

The axon-dash pod runs `axon-reporting` as a sidecar and axon-server reaches it at `axon_reporting_url`. The script configures both; nothing needs enabling. It needs axon-server 2.0.39 or newer. Check that the sidecar runs:

```bash
kubectl get pods -n "$AXONOPS_NAMESPACE" -l app.kubernetes.io/instance=axon-dash \
  -o jsonpath='{.items[*].spec.containers[*].name}'
# axon-dash axon-reporting
```

## Connecting agents

Agents in the same cluster connect to `axon-server-agent.<namespace>.svc.cluster.local:1888` with TLS disabled. The [Strimzi on-premises](../strimzi/on-premises/), [Strimzi local-disk](../strimzi/local-disk/) and [K8ssandra](../k8ssandra/) examples build that address from `AXONOPS_NAMESPACE`, so source `axonops-config.env` in the same shell before their configuration files.

## Verify

```bash
helm list -n "$AXONOPS_NAMESPACE"
kubectl get pods -n "$AXONOPS_NAMESPACE"
kubectl port-forward -n "$AXONOPS_NAMESPACE" svc/axon-dash-svc 3000:3000
```

Then open <http://localhost:3000>.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Pods stay `Pending` | `kubectl get pvc -n "$AXONOPS_NAMESPACE"`. Without a default StorageClass, set `AXON_*_STORAGE_CLASS`. |
| axon-server cannot reach the databases | The passwords changed between runs. Compare `generated/axon-server-secret.yaml` with the values used by the database releases. |
| axon-server logs `tls: first record does not look like a TLS handshake` | The database has no certificate, so it runs without TLS. `kubectl logs axondb-timeseries-0` shows `SSL encryption not enabled`. Keep `AXON_TIMESERIES_CERTMANAGER_ENABLED=true` or set `AXON_TIMESERIES_TLS_EXISTING_SECRET`, then reinstall the database. |
| Certificates not issued | `kubectl get clusterissuer` and `kubectl get certificate -n "$AXONOPS_NAMESPACE"` |

## Remove

```bash
for r in axon-dash axon-server axondb-search axondb-timeseries; do
  helm uninstall "$r" -n "$AXONOPS_NAMESPACE"
done
kubectl delete secret axon-server-config -n "$AXONOPS_NAMESPACE"
# Deletes all AxonOps data:
kubectl delete pvc --all -n "$AXONOPS_NAMESPACE"
kubectl delete namespace "$AXONOPS_NAMESPACE"
```

## Related

- [AxonOps deployment guide](../AXONOPS_DEPLOYMENT.md)
- [AxonOps meta-chart](../../axonops/charts/axonops/README.md), a single Helm release for the same stack
- [AxonOps documentation](https://docs.axonops.com)
