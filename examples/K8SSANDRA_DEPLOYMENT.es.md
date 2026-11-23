# Guía de despliegue de K8ssandra

[English](K8SSANDRA_DEPLOYMENT.md) | [Français](K8SSANDRA_DEPLOYMENT.fr.md) | **Español** | [Galego](K8SSANDRA_DEPLOYMENT.gl.md)

Esta guía despliega Apache Cassandra con el operador K8ssandra y la imagen de Cassandra de AxonOps, que ejecuta el agente de AxonOps junto a Cassandra. Los manifiestos y todos los ajustes están en [k8ssandra/](k8ssandra/README.md).

## Instalar el operador K8ssandra

El operador necesita cert-manager. Instale ambos una vez por clúster de Kubernetes:

```bash
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.1 \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true --wait

export K8SSANDRA_OPERATOR_NAMESPACE=k8ssandra-operator
helm repo add k8ssandra https://helm.k8ssandra.io/stable
helm repo update
helm upgrade --install k8ssandra-operator k8ssandra/k8ssandra-operator \
  --version 1.29.0 \
  --namespace "$K8SSANDRA_OPERATOR_NAMESPACE" --create-namespace \
  --wait
```

Instalado así, el operador solo gestiona clústeres de su propio namespace, que es el valor por defecto del ejemplo. Para desplegar clústeres en otros namespaces, añada `--set global.clusterScoped=true`.

## Desplegar un clúster

```bash
cd examples/k8ssandra
source k8ssandra-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key

envsubst < axonops-agent-secret.yaml | kubectl apply -f -
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
kubectl wait k8ssandracluster/"$K8SSANDRA_CLUSTER_NAME" -n "$K8SSANDRA_NAMESPACE" \
  --for=condition=CassandraInitialized --timeout=20m
```

Aplique primero el Secret: el contenedor de Cassandra lee de él los ajustes del agente.

## Destino de AxonOps

| Destino | Ajustes |
| --- | --- |
| AxonOps Cloud (por defecto) | `AXON_AGENT_ORG`, `AXON_AGENT_KEY`; servidor `agents.axonops.cloud:443`, TLS |
| AxonOps autoalojado | `AXON_AGENT_SERVER_HOST=axon-server-agent.$AXONOPS_NAMESPACE.svc.cluster.local`, `AXON_AGENT_SERVER_PORT=1888`, `AXON_AGENT_TLS_MODE=disabled` |

Para un servidor autoalojado instalado desde [axonops/](axonops/), cargue antes `axonops/axonops-config.env` y siga el [ejemplo autoalojado](k8ssandra/README.md#examples).

## Versiones de imagen

`IMAGE_NAME` debe corresponder a `CASSANDRA_VERSION`. El valor por defecto es la etiqueta flotante `<cassandra>`, por ejemplo `5.0.9`, que siempre apunta a la última build de AxonOps para esa versión de Cassandra. Sirve para una demo; en producción, fije la imagen por digest SHA256 (`ghcr.io/axonops/k8ssandra/cassandra@sha256:<digest>`) para que todos los nodos ejecuten la misma build. Las etiquetas inmutables siguen el formato `<cassandra>-v<k8ssandra api>-<image>`, por ejemplo `5.0.9-v0.1.125-1.6.3`. Las etiquetas publicadas se enumeran en [VERSIONS.md](../VERSIONS.md) y en el [README de la imagen de K8ssandra](../k8ssandra/README.es.md).

## Escalado

Cambie `CASSANDRA_DC_SIZE` y vuelva a aplicar el manifiesto:

```bash
export CASSANDRA_DC_SIZE=5
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

Al reducir el tamaño, el operador retira los nodos eliminados de uno en uno. Asegúrese antes de que los nodos restantes tienen espacio para sus datos.

## Resolución de problemas

| Síntoma | Comprobación |
| --- | --- |
| Pod `CreateContainerConfigError` | Falta el Secret del agente: `kubectl get secret "$K8SSANDRA_CLUSTER_NAME-axonops-agent" -n "$K8SSANDRA_NAMESPACE"` |
| Pods `Pending` | `kubectl get pvc -n "$K8SSANDRA_NAMESPACE"`; configure `STORAGE_CLASS` si no hay StorageClass por defecto |
| No se crea nada tras aplicar | El namespace del clúster no es el del operador y el operador no tiene ámbito de clúster |
| El clúster no aparece en AxonOps | `kubectl logs <pod> -c cassandra \| grep -i axon` para ver errores de conexión; compruebe host, puerto, modo TLS y clave |

## Notas para producción

- Asigne a cada nodo al menos 4 CPU y 8 GiB de memoria, y aumente `HEAP_SIZE` en consonancia.
- Use StorageClasses rápidas respaldadas por SSD.
- Use factor de replicación 3 para los keyspaces de aplicación.
- Configure copias de seguridad, por ejemplo con K8ssandra Medusa.

## Relacionado

- [k8ssandra/README.md](k8ssandra/README.md): ficheros y todos los ajustes
- [Imagen K8ssandra de AxonOps](../k8ssandra/README.es.md)
- [Documentación de K8ssandra](https://docs.k8ssandra.io/)
