# AxonOps Strimzi Kafka

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

Este repositorio ofrece imaxes de contedor de Strimzi Kafka personalizadas, cos
compoñentes de monitorización e observabilidade de AxonOps integrados.

## Visión xeral

A integración de AxonOps con Strimzi permite construír clústeres de Kafka sobre
Kubernetes co [operador Strimzi](https://strimzi.io/) que reportan
automaticamente métricas e rexistros a AxonOps. Isto conséguese estendendo as
imaxes estándar de Strimzi Kafka cos compoñentes do axente de AxonOps.

## Prestacións

- **Soporte de KRaft**: construídas sobre o modo KRaft de Strimzi (Kafka sen ZooKeeper)
- **Monitorización de AxonOps**: recollida automática de métricas e envío de rexistros
- **Configuración flexible**: admite configuración por ConfigMap e por variables de entorno
- **Conciencia de rack**: soporte da conciencia de rack baseada na topoloxía de Kubernetes
- **Escaneo de seguridade**: escaneo de seguridade con Trivy integrado no CI/CD

## Requisitos previos

- Un clúster de Kubernetes (probado con k3s, pero debería funcionar con calquera distribución de Kubernetes)
- Helm 3.x
- `kubectl` configurado para acceder ao seu clúster
- Unha conta de AxonOps con chave de API

## Inicio rápido

### 1. Instalar o operador Strimzi

```bash
helm upgrade --install strimzi-kafka-operator \
  oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  --version 1.1.0 \
  --namespace strimzi --create-namespace \
  --set watchAnyNamespace=true \
  --wait
```

### 2. Despregar un clúster de Kafka

Hai manifestos listos para usar en [`examples/strimzi/`](../examples/strimzi/).
Cada directorio ten un ficheiro `strimzi-config.env` e un README cos pasos
completos:

| Exemplo | Almacenamento | Destino de AxonOps |
| --- | --- | --- |
| [`cloud/`](../examples/strimzi/cloud/) | PVC dunha StorageClass | AxonOps Cloud |
| [`on-premises/`](../examples/strimzi/on-premises/) | PVC dunha StorageClass | AxonOps autoaloxado |
| [`local-disk/`](../examples/strimzi/local-disk/) | Volumes hostPath fixados a nodos | AxonOps autoaloxado |

```bash
cd examples/strimzi/cloud
source strimzi-config.env
export AXON_AGENT_ORG=your-org AXON_AGENT_KEY=your-agent-key
kubectl create namespace "$KAFKA_NAMESPACE"
for f in axonops-agent-secret.yaml kafka-node-pool-controller.yaml \
         kafka-node-pool-brokers.yaml kafka-cluster.yaml; do
  envsubst < "$f" | kubectl apply -f -
done
kubectl get pods -n "$KAFKA_NAMESPACE" --watch
```

`kafka-connect.yaml`, nos mesmos directorios, engade un clúster de Kafka Connect
cuxos workers reportan a AxonOps co tipo de nodo `connect`. O soporte de Kafka
Connect está en beta.

Consulte a [guía de despregamento de Strimzi](../examples/STRIMZI_DEPLOYMENT.gl.md)
para a compatibilidade de versións do operador e da imaxe.

## Detalles de configuración

### Variables de entorno do axente

A imaxe le a configuración do axente das variables de entorno do contedor de
Kafka. Os exemplos defínenas a partir dun Secret con `valueFrom.secretKeyRef`.

| Variable | Descrición | Exemplo |
|----------|-------------|---------|
| `KAFKA_NODE_TYPE` | Rol do nodo de Kafka | `kraft-controller`, `kraft-broker` ou `connect` |
| `AXON_AGENT_CLUSTER_NAME` | Nome do clúster que se mostra en AxonOps | `my-kafka-prod` |
| `AXON_AGENT_ORG` | Nome da organización de AxonOps | O nome da súa organización |
| `AXON_AGENT_KEY` | Chave do axente de AxonOps | A súa chave da consola de AxonOps |
| `AXON_AGENT_SERVER_HOST` | Nome de host do servidor de AxonOps | `agents.axonops.cloud` |
| `AXON_AGENT_SERVER_PORT` | Porto do servidor de AxonOps | `443`, ou `1888` para un servidor autoaloxado |
| `AXON_AGENT_TLS_MODE` | Modo TLS do axente | `TLS` ou `disabled` |

### Ficheiro de configuración

Para configurar o axente cun ficheiro `axon-agent.yml` completo, mónteo en
`/mnt/axon-agent.yml`, por exemplo dende un ConfigMap mediante
`template.pod.volumes` e `template.kafkaContainer.volumeMounts` no KafkaNodePool.
A imaxe enlázao en `/etc/axonops/axon-agent.yml` no arranque.

## Conciencia de rack

A conciencia de rack de Kafka apóiase nas etiquetas de nodo de Kubernetes. Axuda
a garantir que as réplicas se reparten entre zonas de dispoñibilidade.

### Etiquete os seus nodos

```bash
kubectl label node <node-name> topology.kubernetes.io/zone=<zone-name>
```

Exemplo:

```bash
kubectl label node worker-1 topology.kubernetes.io/zone=us-east-1a
kubectl label node worker-2 topology.kubernetes.io/zone=us-east-1b
kubectl label node worker-3 topology.kubernetes.io/zone=us-east-1c
```

### Configúreo no CRD de Kafka

A configuración de conciencia de rack xa vén nos manifestos de exemplo:

```yaml
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    rack:
      topologyKey: topology.kubernetes.io/zone
```

Os exemplos definen `topologyKey` a partir de `KAFKA_RACK_TOPOLOGY_KEY`:
`topology.kubernetes.io/zone` en `cloud/`, `kubernetes.io/hostname` en
`on-premises/` e `local-disk/`.

## Construír imaxes personalizadas

### Build local para desenvolvemento

Para construír unha imaxe personalizada en local, para probas:

```bash
# For Kafka 3.x versions
docker build \
  --build-arg STRIMZI_VERSION=0.46.1 \
  --build-arg KAFKA_VERSION=3.9.0 \
  --build-arg KAFKA_AGENT_PACKAGE=axon-kafka3-agent \
  --build-arg AXONOPS_REPO_FILE=axonops.repo.dev \
  -t axonkafka:local \
  .

# For Kafka 4.x versions
docker build \
  --build-arg STRIMZI_VERSION=0.49.1 \
  --build-arg KAFKA_VERSION=4.1.0 \
  --build-arg KAFKA_AGENT_PACKAGE=axon-kafka4-agent \
  --build-arg AXONOPS_REPO_FILE=axonops.repo.dev \
  -t axonkafka:local \
  .
```

**Importante**: use `axon-kafka3-agent` para as versións 3.x de Kafka e
`axon-kafka4-agent` para as 4.x.

### Pipeline de CI/CD

O repositorio inclúe un workflow de GitHub Actions en
[`.github/workflows/strimzi-build-and-test.yml`](../.github/workflows/strimzi-build-and-test.yml)
que:

1. Constrúe a imaxe do operador Strimzi cos compoñentes de AxonOps
2. Executa o escaneo de seguridade con Trivy
3. Valida o proceso de build da imaxe

O workflow dispárase con:
- Pushes ás ramas `main`, `development`, `feature/**`, `feat/**`, `fix/**` e `bug/**`
- Pull requests a `main` ou `development`
- Cambios en ficheiros do directorio `strimzi/`

### Etiquetado para builds de produción

Para lanzar un pipeline de build de produción, cree unha etiqueta con este
formato:

```
<environment>/<strimzi-version>-kafka-<kafka-version>-<build-number>
```

**Exemplos:**

```bash
# Development build
git tag dev/0.49.1-kafka-4.1.0-1
git push origin dev/0.49.1-kafka-4.1.0-1

# Beta build
git tag beta/0.49.1-kafka-4.1.0-1
git push origin beta/0.49.1-kafka-4.1.0-1

# Production release
git tag release/0.49.1-kafka-4.1.0-1
git push origin release/0.49.1-kafka-4.1.0-1
```

**Onde:**
- `<environment>`: `dev`, `beta` ou `release`
- `<strimzi-version>`: a versión do operador Strimzi (por exemplo, `0.49.1`)
- `<kafka-version>`: a versión de Kafka (por exemplo, `4.1.0`)
- `<build-number>`: un número de build incremental (por exemplo, `1`, `2`, `3`)

## Limpeza

### Eliminar o clúster de Kafka

Para eliminar todos os recursos de Kafka do clúster de exemplo:

```bash
# Delete all Strimzi resources
kubectl delete $(kubectl get strimzi -o name -n "$KAFKA_NAMESPACE") -n "$KAFKA_NAMESPACE"

# Delete persistent volume claims
kubectl delete pvc --all -n "$KAFKA_NAMESPACE"

# Uninstall Strimzi operator
helm uninstall strimzi-kafka-operator -n strimzi

# Clean up local images (if needed)
docker rmi axonkafka:local
```

### Limpar as imaxes de Kubernetes (exemplo con k3s)

```bash
k3s crictl rmi ghcr.io/axonops/strimzi/kafka:0.47.0-3.9.0
```

## Resolución de problemas

### Comprobar o estado dos pods

```bash
kubectl get pods -n "$KAFKA_NAMESPACE"
kubectl describe pod <pod-name> -n "$KAFKA_NAMESPACE"
```

### Consultar os rexistros

```bash
# Kafka broker logs
kubectl logs <broker-pod-name> -n "$KAFKA_NAMESPACE"

# AxonOps agent logs
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- tail -f /var/log/axonops/axon-agent.log

# Follow all logs from a pod
kubectl logs -f <pod-name> -n "$KAFKA_NAMESPACE"
```

### Verificar a conexión con AxonOps

```bash
# Check if agent is running
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- ps aux | grep axon

# Check agent configuration
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- cat /etc/axonops/axon-agent.yml
```

### Problemas habituais

**Problema**: os pods quedan en `Pending` ou `CrashLoopBackOff`.
- Comprobe a dispoñibilidade de recursos: `kubectl describe pod <pod-name> -n "$KAFKA_NAMESPACE"`
- Verifique o estado das PVC: `kubectl get pvc -n "$KAFKA_NAMESPACE"`

**Problema**: o axente de AxonOps non reporta métricas.
- Verifique que a chave de API é correcta na configuración
- Comprobe a conectividade de rede co servidor de AxonOps
- Revise os rexistros do axente na busca de erros

## Arquitectura

As imaxes personalizadas constrúense así:

1. Pártese da imaxe base oficial de Strimzi Kafka (`quay.io/strimzi/kafka`)
2. Engádese o repositorio YUM de AxonOps
3. Instálanse os paquetes do axente de AxonOps e do axente de Kafka
4. Inxéctase o script envolveiro de AxonOps nos scripts de arranque de Kafka
5. Configúranse os permisos e a pertenza a grupos

Ficheiros clave:

- [`Dockerfile`](Dockerfile): a definición do build da imaxe
- [`files/axonops-wrapper.sh`](files/axonops-wrapper.sh): o envolveiro de arranque para a integración de AxonOps
  O envolveiro tamén engade `-XX:-UseBASE64Intrinsics` a `KAFKA_OPTS` para mitigar CVE-2026-114938. Vai en primeiro lugar, de modo que un `-XX:+UseBASE64Intrinsics` posterior no teu propio `KAFKA_OPTS` anúlao.
- [`files/axonops.repo.dev`](files/axonops.repo.dev): a configuración do repositorio YUM de AxonOps (dev)
- [`files/axonops.repo.release`](files/axonops.repo.release): a configuración do repositorio YUM de AxonOps (release)

## Configuracións de exemplo

Os exemplos descríbense en [`examples/STRIMZI_DEPLOYMENT.gl.md`](../examples/STRIMZI_DEPLOYMENT.gl.md).
Os tres crean un clúster de Kafka con pools separados de controllers e brokers
KRaft, conciencia de rack e o axente de AxonOps en cada contedor.

## Compatibilidade de versións

| Compoñente | Versión | Notas |
| --------- | ------- | ----- |
| Strimzi | 1.2.0 (última) | O soporte de ConfigMap require 0.44+, e o modo KRaft é obrigatorio |
| Kafka | 4.3.1 (última) | A versión 1.2.0 admite Kafka 4.2.0, 4.2.1, 4.3.0 e 4.3.1 |
| Kubernetes | 1.24+ | Calquera distribución conforme á CNCF |
| Axente de AxonOps | Última | Instálase automaticamente dende o repositorio |

### Historial de versións de Strimzi

| Versión de Strimzi | Versións de Kafka admitidas | Data de publicación |
| --------------- | ------------------------ | ------------ |
| 1.2.0 | 4.2.0, 4.2.1, 4.3.0, 4.3.1 | ago. 2026 |
| 1.1.0 | 4.2.0, 4.2.1, 4.3.0 | xuñ. 2026 |
| 1.0.1 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | xuñ. 2026 |
| 1.0.0 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | abr. 2026 |
| 0.51.0 | 4.1.0, 4.1.1, 4.2.0 | mar. 2026 |
| 0.50.0 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | feb. 2025 |
| 0.49.1 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | dec. 2024 |
| 0.48.0 | 4.0.0, 4.1.0 | nov. 2024 |
| 0.47.0 | 3.9.0, 3.9.1 | out. 2024 |

## Limitacións coñecidas e pendentes

- **Kafka Connect**: ofrécese unha configuración de exemplo, pero as probas de integración completas están en curso
- **Mirror Maker**: aínda non se constrúe nin se proba
- **Modo ZooKeeper**: non está admitido (só KRaft)
- **hostId persistente**: valore usar volumes persistentes para o ficheiro hostId do axente de AxonOps

## Soporte

Para incidencias relacionadas con:

- **A integración con AxonOps**: contacte co soporte de AxonOps
- **O operador Strimzi**: véxase a [documentación de Strimzi](https://strimzi.io/docs/)
- **Este repositorio**: abra unha incidencia no repositorio

## Recursos adicionais

- [Documentación de Strimzi](https://strimzi.io/docs/)
- [Documentación de AxonOps](https://docs.axonops.com/)
- [O modo KRaft de Kafka](https://kafka.apache.org/documentation/#kraft)
- [Etiquetas de nodo de Kubernetes](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
