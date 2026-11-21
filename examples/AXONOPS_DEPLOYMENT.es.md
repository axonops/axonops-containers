# Guía de despliegue de AxonOps

[English](AXONOPS_DEPLOYMENT.md) | [Français](AXONOPS_DEPLOYMENT.fr.md) | **Español** | [Galego](AXONOPS_DEPLOYMENT.gl.md)

Esta guía instala un stack de AxonOps autoalojado en Kubernetes con el script de [axonops/](axonops/). El [axonops/README.md](axonops/README.md) enumera todos los ajustes.

## Componentes

| Componente | Función |
| --- | --- |
| axondb-timeseries | Almacén de métricas (Cassandra) |
| axondb-search | Logs y eventos (OpenSearch) |
| axon-server | Recibe los datos de los agentes y sirve la API |
| axon-dash | Interfaz web, con el sidecar `axon-reporting` para Reports v2 |

Los cuatro se instalan en un mismo namespace, `AXONOPS_NAMESPACE` (por defecto `axonops`), a partir de los charts de `oci://ghcr.io/axonops/charts`. TLS en las bases de datos está desactivado por defecto, igual que cert-manager.

## Inicio rápido

```bash
cd examples/axonops
source axonops-config.env
export AXON_SEARCH_PASSWORD="$(openssl rand -base64 24)"
export AXON_SERVER_CQL_PASSWORD="$(openssl rand -base64 24)"
./axonops-setup.sh
```

El script escribe los values de Helm y el Secret de configuración de axon-server en `axonops/generated/`, instala cada release con `helm upgrade --install --wait` e indica cómo acceder al dashboard. Volver a ejecutarlo actualiza las releases en el sitio. Mantenga las mismas contraseñas en todas las ejecuciones.

## Almacenamiento

| Modo | Ajustes | Uso |
| --- | --- | --- |
| PVC (por defecto) | `AXON_TIMESERIES_STORAGE_CLASS`, `AXON_SEARCH_STORAGE_CLASS`, `AXON_*_VOLUME_SIZE` | Cualquier clúster con una StorageClass |
| hostPath | `AXON_TIMESERIES_USE_HOSTPATH=true`, `AXON_SEARCH_USE_HOSTPATH=true` | Clústeres de prueba de un solo nodo |
| Ninguno | `AXON_*_PERSISTENCE_ENABLED=false` | Pruebas desechables; los datos se pierden con el pod |

Para hostPath, cree los directorios en el nodo antes de ejecutar el script:

```bash
sudo mkdir -p /data/axon-timeseries /data/axon-search
sudo chown -R 999:999 /data/axon-timeseries /data/axon-search
```

## Acceso al dashboard

| Método | Ajustes | Dirección |
| --- | --- | --- |
| Port-forward (por defecto) | ninguno | `kubectl port-forward -n "$AXONOPS_NAMESPACE" svc/axon-dash-svc 3000:3000`, y después <http://localhost:3000> |
| NodePort | `AXON_DASH_NODEPORT_ENABLED=true` | `http://<node-ip>:<port>`; el script muestra el puerto |
| Ingress | `AXON_DASH_INGRESS_ENABLED=true`, `AXON_DASH_INGRESS_HOST`, `AXON_DASH_INGRESS_CLASS_NAME` | `https://<host>` |

## Conexión de Kafka y Cassandra

Los agentes del mismo clúster se conectan a:

```text
axon-server-agent.<AXONOPS_NAMESPACE>.svc.cluster.local:1888   (TLS disabled)
```

Los ejemplos [Strimzi on-premises](strimzi/on-premises/), [Strimzi local-disk](strimzi/local-disk/) y [K8ssandra](k8ssandra/README.md#examples) leen `AXONOPS_NAMESPACE`, `AXON_SERVER_ORG_NAME` y `AXON_SERVER_AGENTS_PORT` de `axonops/axonops-config.env`. Cárguelo antes que su propio fichero de configuración:

```bash
source examples/axonops/axonops-config.env
source examples/strimzi/on-premises/strimzi-config.env
```

Para agentes fuera del clúster, active el Ingress gRPC con `AXON_SERVER_AGENT_INGRESS_ENABLED=true` y `AXON_SERVER_AGENT_INGRESS_HOST`, y apunte los agentes a ese host en el puerto 443 con `AXON_AGENT_TLS_MODE=TLS`.

## Verificación

```bash
helm list -n "$AXONOPS_NAMESPACE"
kubectl get pods,pvc -n "$AXONOPS_NAMESPACE"
kubectl logs -n "$AXONOPS_NAMESPACE" deploy/axon-server --tail=50
```

## Eliminación

```bash
for r in axon-dash axon-server axondb-search axondb-timeseries; do
  helm uninstall "$r" -n "$AXONOPS_NAMESPACE"
done
kubectl delete secret axon-server-config -n "$AXONOPS_NAMESPACE"
kubectl delete pvc --all -n "$AXONOPS_NAMESPACE"   # deletes all AxonOps data
kubectl delete namespace "$AXONOPS_NAMESPACE"
```

## Notas para producción

- Use una StorageClass con copias de seguridad y dimensione los volúmenes según su retención.
- Configure una clave de licencia con `AXON_SERVER_LICENSE_KEY`.
- Para activar TLS entre axon-server y las bases de datos, configure `AXON_TIMESERIES_TLS_ENABLED=true` y `AXON_SEARCH_TLS_ENABLED=true`. Los certificados vienen de cert-manager (`CERT_MANAGER_INSTALL=true` lo instala) o de sus propios Secrets; consulte [axonops/README.md](axonops/README.md#tls).
- Guarde las contraseñas generadas en un gestor de secretos; `axonops/generated/` las contiene en texto plano.
- El [meta-chart de AxonOps](../axonops/charts/axonops/README.es.md) instala el mismo stack como una única release de Helm, lo que encaja mejor con herramientas GitOps que un script.

## Relacionado

- [axonops/README.md](axonops/README.md): todos los ajustes del script
- [Guía de despliegue](DEPLOYMENT_GUIDE.es.md)
- [Documentación de AxonOps](https://docs.axonops.com)
