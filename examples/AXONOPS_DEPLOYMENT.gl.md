# Guía de despregamento de AxonOps

[English](AXONOPS_DEPLOYMENT.md) | [Français](AXONOPS_DEPLOYMENT.fr.md) | [Español](AXONOPS_DEPLOYMENT.es.md) | **Galego**

Esta guía instala unha pila de AxonOps autoaloxada sobre Kubernetes co script de [axonops/](axonops/). O [axonops/README.md](axonops/README.md) lista todas as opcións.

## Compoñentes

| Compoñente | Función |
| --- | --- |
| axondb-timeseries | Almacén de métricas (Cassandra) |
| axondb-search | Rexistros e eventos (OpenSearch) |
| axon-server | Recibe os datos dos axentes e serve a API |
| axon-dash | Interface web, co sidecar `axon-reporting` para Reports v2 |

Os catro instálanse nun só espazo de nomes, `AXONOPS_NAMESPACE` (por defecto `axonops`), a partir dos charts de `oci://ghcr.io/axonops/charts`. TLS nas bases de datos está desactivado por defecto, igual que cert-manager.

## Inicio rápido

```bash
cd examples/axonops
source axonops-config.env
export AXON_SEARCH_PASSWORD="$(openssl rand -base64 24)"
export AXON_SERVER_CQL_PASSWORD="$(openssl rand -base64 24)"
./axonops-setup.sh
```

O script escribe os valores de Helm e o Secret de configuración de axon-server en `axonops/generated/`, instala cada release con `helm upgrade --install --wait` e mostra como acceder ao panel. Ao executalo de novo actualiza as releases no sitio. Use os mesmos contrasinais en todas as execucións.

## Almacenamento

| Modo | Opcións | Uso |
| --- | --- | --- |
| PVC (por defecto) | `AXON_TIMESERIES_STORAGE_CLASS`, `AXON_SEARCH_STORAGE_CLASS`, `AXON_*_VOLUME_SIZE` | Calquera clúster cunha StorageClass |
| hostPath | `AXON_TIMESERIES_USE_HOSTPATH=true`, `AXON_SEARCH_USE_HOSTPATH=true` | Clústeres de proba dun só nodo |
| Ningún | `AXON_*_PERSISTENCE_ENABLED=false` | Probas desbotables; os datos pérdense co pod |

Para hostPath, cree os directorios no nodo antes de executar o script:

```bash
sudo mkdir -p /data/axon-timeseries /data/axon-search
sudo chown -R 999:999 /data/axon-timeseries /data/axon-search
```

## Acceso ao panel

| Método | Opcións | Enderezo |
| --- | --- | --- |
| Port-forward (por defecto) | ningunha | `kubectl port-forward -n "$AXONOPS_NAMESPACE" svc/axon-dash-svc 3000:3000`, despois <http://localhost:3000> |
| NodePort | `AXON_DASH_NODEPORT_ENABLED=true` | `http://<node-ip>:<port>`; o script mostra o porto |
| Ingress | `AXON_DASH_INGRESS_ENABLED=true`, `AXON_DASH_INGRESS_HOST`, `AXON_DASH_INGRESS_CLASS_NAME` | `https://<host>` |

## Conectar Kafka e Cassandra

Os axentes do mesmo clúster conéctanse a:

```text
axon-server-agent.<AXONOPS_NAMESPACE>.svc.cluster.local:1888   (TLS disabled)
```

Os exemplos [Strimzi on-premises](strimzi/on-premises/), [Strimzi local-disk](strimzi/local-disk/) e [K8ssandra](k8ssandra/README.md#examples) len `AXONOPS_NAMESPACE`, `AXON_SERVER_ORG_NAME` e `AXON_SERVER_AGENTS_PORT` de `axonops/axonops-config.env`. Faga `source` del antes do seu propio ficheiro de configuración:

```bash
source examples/axonops/axonops-config.env
source examples/strimzi/on-premises/strimzi-config.env
```

Para axentes fóra do clúster, active o Ingress gRPC con `AXON_SERVER_AGENT_INGRESS_ENABLED=true` e `AXON_SERVER_AGENT_INGRESS_HOST`, e apunte os axentes a ese host no porto 443 con `AXON_AGENT_TLS_MODE=TLS`.

## Verificar

```bash
helm list -n "$AXONOPS_NAMESPACE"
kubectl get pods,pvc -n "$AXONOPS_NAMESPACE"
kubectl logs -n "$AXONOPS_NAMESPACE" deploy/axon-server --tail=50
```

## Eliminar

```bash
for r in axon-dash axon-server axondb-search axondb-timeseries; do
  helm uninstall "$r" -n "$AXONOPS_NAMESPACE"
done
kubectl delete secret axon-server-config -n "$AXONOPS_NAMESPACE"
kubectl delete pvc --all -n "$AXONOPS_NAMESPACE"   # deletes all AxonOps data
kubectl delete namespace "$AXONOPS_NAMESPACE"
```

## Notas para produción

- Use unha StorageClass con copias de seguridade e dimensione os volumes segundo a súa retención.
- Defina unha chave de licenza con `AXON_SERVER_LICENSE_KEY`.
- Para activar TLS entre axon-server e as bases de datos, defina `AXON_TIMESERIES_TLS_ENABLED=true` e `AXON_SEARCH_TLS_ENABLED=true`. Os certificados veñen de cert-manager (`CERT_MANAGER_INSTALL=true` instálao) ou dos seus propios Secrets; consulte [axonops/README.md](axonops/README.md#tls).
- Garde os contrasinais xerados nun xestor de segredos; `axonops/generated/` contéñenos en texto plano.
- O [meta-chart de AxonOps](../axonops/charts/axonops/README.gl.md) instala a mesma pila como unha única release de Helm, que encaixa mellor ca un script coas ferramentas de GitOps.

## Relacionado

- [axonops/README.md](axonops/README.md): todas as opcións do script
- [Guía de despregamento](DEPLOYMENT_GUIDE.gl.md)
- [Documentación de AxonOps](https://docs.axonops.com)
