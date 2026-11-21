# Guía de despregamento de K8ssandra

[English](K8SSANDRA_DEPLOYMENT.md) | [Français](K8SSANDRA_DEPLOYMENT.fr.md) | [Español](K8SSANDRA_DEPLOYMENT.es.md) | **Galego**

Esta guía desprega Apache Cassandra co operador K8ssandra e a imaxe de Cassandra de AxonOps, que executa o axente de AxonOps xunto a Cassandra. Os manifestos e todas as opcións están en [k8ssandra/](k8ssandra/README.md).

## Instalar o operador K8ssandra

O operador precisa cert-manager. Instale os dous unha vez por clúster de Kubernetes:

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

Instalado así, o operador só xestiona clústeres do seu propio espazo de nomes, que é o valor por defecto do exemplo. Para despregar clústeres noutros espazos de nomes, engada `--set global.clusterScoped=true`.

## Despregar un clúster

```bash
cd examples/k8ssandra
source k8ssandra-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key

envsubst < axonops-agent-secret.yaml | kubectl apply -f -
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
kubectl wait k8ssandracluster/"$K8SSANDRA_CLUSTER_NAME" -n "$K8SSANDRA_NAMESPACE" \
  --for=condition=CassandraInitialized --timeout=20m
```

Aplique primeiro o Secret: o contedor de Cassandra le del a configuración do axente.

## Destino de AxonOps

| Destino | Opcións |
| --- | --- |
| AxonOps Cloud (por defecto) | `AXON_AGENT_ORG`, `AXON_AGENT_KEY`; servidor `agents.axonops.cloud:443`, TLS |
| AxonOps autoaloxado | `AXON_AGENT_SERVER_HOST=axon-server-agent.$AXONOPS_NAMESPACE.svc.cluster.local`, `AXON_AGENT_SERVER_PORT=1888`, `AXON_AGENT_TLS_MODE=disabled` |

Para un servidor autoaloxado instalado dende [axonops/](axonops/), faga primeiro `source` de `axonops/axonops-config.env` e siga o [exemplo autoaloxado](k8ssandra/README.md#examples).

## Versións da imaxe

`IMAGE_NAME` debe coincidir con `CASSANDRA_VERSION`. As etiquetas teñen a forma `<cassandra>-v<k8ssandra api>-<image>`, por exemplo `5.0.9-v0.1.125-1.6.3`. As etiquetas publicadas están listadas en [VERSIONS.md](../VERSIONS.md) e no [README da imaxe de K8ssandra](../k8ssandra/README.gl.md).

## Escalado

Cambie `CASSANDRA_DC_SIZE` e aplique o manifesto de novo:

```bash
export CASSANDRA_DC_SIZE=5
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

Ao reducir o tamaño, o operador retira (decommission) os nodos eliminados dun en dun. Asegúrese antes de que os nodos restantes teñen espazo para os seus datos.

## Resolución de problemas

| Síntoma | Comprobación |
| --- | --- |
| Pod `CreateContainerConfigError` | Falta o Secret do axente: `kubectl get secret "$K8SSANDRA_CLUSTER_NAME-axonops-agent" -n "$K8SSANDRA_NAMESPACE"` |
| Pods `Pending` | `kubectl get pvc -n "$K8SSANDRA_NAMESPACE"`; defina `STORAGE_CLASS` se non hai StorageClass por defecto |
| Non se crea nada tras o apply | O espazo de nomes do clúster é distinto do do operador e o operador non ten ámbito de clúster |
| O clúster non aparece en AxonOps | `kubectl logs <pod> -c cassandra \| grep -i axon` para ver erros de conexión; comprobe host, porto, modo TLS e chave |

## Notas para produción

- Dea a cada nodo polo menos 4 CPU e 8 GiB de memoria, e aumente `HEAP_SIZE` en consonancia.
- Use StorageClass rápidas baseadas en SSD.
- Use factor de replicación 3 para os keyspaces das aplicacións.
- Configure copias de seguridade, por exemplo con K8ssandra Medusa.

## Relacionado

- [k8ssandra/README.md](k8ssandra/README.md): ficheiros e todas as opcións
- [Imaxe K8ssandra de AxonOps](../k8ssandra/README.gl.md)
- [Documentación de K8ssandra](https://docs.k8ssandra.io/)
