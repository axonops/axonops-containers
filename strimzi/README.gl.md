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
helm repo add strimzi https://strimzi.io/charts/
helm install my-strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --version 0.46.0 \
  --set watchAnyNamespace=true
```

### 2. Crear o espazo de nomes de Kafka

```bash
kubectl create namespace kafka
```

### 3. Despregar o clúster de Kafka

Escolla un dos métodos de configuración de abaixo segundo as súas necesidades.

#### Opción A: despregamento en cloud (varios nodos)

Para despregamentos de produción en cloud con pools separados de controllers e
brokers.

Consulte o directorio [`examples/strimzi/cloud/`](../examples/strimzi/cloud/)
para todos os manifestos necesarios:

- `kafka-cluster.yaml`: a configuración principal do clúster de Kafka
- `kafka-node-pool-controller.yaml`: o pool de nodos controller
- `kafka-node-pool-brokers.yaml`: o pool de nodos broker
- `kafka-logging-cm.yaml`: a configuración de rexistro
- `axonops-config-secret.yaml`: as credenciais de AxonOps

**Actualice os seguintes valores**:

- `YOUR_AXONOPS_HOST`: o nome de host do seu servidor de AxonOps (por exemplo, `agents.axonops.com`)
- `YOUR_AXONOPS_API_KEY`: a chave de API da súa organización de AxonOps
- `YOUR_CLUSTER_NAME`: un nome único para este clúster de Kafka
- `YOUR_ORG_NAME`: o nome da súa organización de AxonOps

Despois aplique:

```bash
kubectl apply -f ../examples/strimzi/cloud/ -n kafka
kubectl get pod -n kafka --watch
```

#### Opción B: un só nodo (desenvolvemento e probas)

Para desenvolvemento ou probas, pode despregar un clúster de Kafka dun só nodo
cos roles de controller e broker combinados.

Consulte o directorio [`examples/strimzi/cloud/`](../examples/strimzi/cloud/):

- `kafka-single-node.yaml`: o clúster de Kafka dun só nodo
- `axonops-agent-config.yaml`: a configuración do axente de AxonOps
- `axonops-kafka-logging.yaml`: a configuración de rexistro
- `axonops-kafka-nodepool.yaml`: a configuración do pool de nodos

**Actualice os valores** e aplique:

```bash
kubectl apply -f ../examples/strimzi/cloud/ -n kafka
kubectl get pod -n kafka --watch
```

#### Opción C: almacenamento en disco local

Para despregamentos que usan volumes persistentes locais.

Consulte o directorio
[`examples/strimzi/local-disk/`](../examples/strimzi/local-disk/) para todos os
manifestos necesarios.

```bash
kubectl apply -f ../examples/strimzi/local-disk/ -n kafka
kubectl get pod -n kafka --watch
```

#### Opción D: clúster de Kafka Connect

Despregue un clúster de Kafka Connect para transmitir datos entre Kafka e outros
sistemas.

**Requisitos previos**: ter un clúster de Kafka en funcionamento (despregado
cunha das opcións anteriores).

**Actualice os seguintes valores** en
[`examples/strimzi/cloud/kafka-connect.yaml`](../examples/strimzi/cloud/kafka-connect.yaml):

- `YOUR_AXONOPS_HOST`: o nome de host do seu servidor de AxonOps (por exemplo, `agents.axonops.com`)
- `YOUR_AXONOPS_API_KEY`: a chave de API da súa organización de AxonOps
- `YOUR_CLUSTER_NAME`: un nome único para este clúster de Kafka Connect
- `YOUR_ORG_NAME`: o nome da súa organización de AxonOps
- `ghcr.io/axonops/strimzi/kafka:latest`: substitúaa pola súa imaxe concreta de Kafka con AxonOps
- `my-cluster-kafka-bootstrap:9092`: substitúaa polo enderezo real do seu servidor bootstrap de Kafka

Despois aplique:

```bash
kubectl apply -f ../examples/strimzi/cloud/kafka-connect.yaml -n kafka
kubectl get pod -n kafka --watch
```

**Nota**: o soporte de Kafka Connect está actualmente en beta. Os workers de
Connect reportarán métricas a AxonOps co tipo de nodo `connect`.

## Detalles de configuración

### Variables de entorno obrigatorias

Ao usar a configuración por variables de entorno, hai que definir estas
variables:

| Variable | Descrición | Exemplo |
|----------|-------------|---------|
| `KAFKA_NODE_TYPE` | Rol do nodo de Kafka | `kraft-controller` ou `kraft-broker` |
| `AXON_AGENT_SERVER_HOST` | Nome de host do servidor de AxonOps | `agents.axonops.com` |
| `AXON_AGENT_KEY` | Chave de API de AxonOps | A súa chave de API do panel de AxonOps |
| `AGENT_CLUSTER_NAME` | Identificador único do clúster | `my-kafka-prod` |
| `AXON_AGENT_ORG` | Nome da organización de AxonOps | O nome da súa organización |

### Variables de entorno opcionais

| Variable | Descrición | Valor por defecto |
|----------|-------------|---------|
| `KAFKA_CLIENT_BROKERS` | Enderezos dos brokers (para os brokers) | `0.0.0.0:9092` |

### Configuración por ConfigMap

O enfoque de ConfigMap permite proporcionar un ficheiro `axon-agent.yml`
completo. Resulta útil para:

- Configuración avanzada da recollida de métricas
- Axustes de rexistro personalizados
- Despregamentos en varios datacenters
- Control fino do comportamento do axente

Consulte [`examples/strimzi/cloud/`](../examples/strimzi/cloud/) para a estrutura
completa.

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
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    rack:
      topologyKey: topology.kubernetes.io/zone
```

A etiqueta de nodo é `topology.kubernetes.io/zone` por defecto, pero pode
cambiarse co parámetro `topologyKey`.

## Construír imaxes personalizadas

### Build local para desenvolvemento

Para construír unha imaxe personalizada en local, para probas:

```bash
# For Kafka 3.x versions
docker build \
  --build-arg STRIMZI_VERSION=0.46.0 \
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
kubectl delete $(kubectl get strimzi -o name -n kafka) -n kafka

# Delete persistent volume claims
kubectl delete pvc --all -n kafka

# Uninstall Strimzi operator
helm uninstall my-strimzi-kafka-operator

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
kubectl get pods -n kafka
kubectl describe pod <pod-name> -n kafka
```

### Consultar os rexistros

```bash
# Kafka broker logs
kubectl logs <broker-pod-name> -n kafka

# AxonOps agent logs
kubectl exec <pod-name> -n kafka -- tail -f /var/log/axonops/axon-agent.log

# Follow all logs from a pod
kubectl logs -f <pod-name> -n kafka
```

### Verificar a conexión con AxonOps

```bash
# Check if agent is running
kubectl exec <pod-name> -n kafka -- ps aux | grep axon

# Check agent configuration
kubectl exec <pod-name> -n kafka -- cat /etc/axonops/axon-agent.yml
```

### Problemas habituais

**Problema**: os pods quedan en `Pending` ou `CrashLoopBackOff`.
- Comprobe a dispoñibilidade de recursos: `kubectl describe pod <pod-name> -n kafka`
- Verifique o estado das PVC: `kubectl get pvc -n kafka`

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
- [`files/axonops.repo.dev`](files/axonops.repo.dev): a configuración do repositorio YUM de AxonOps (dev)
- [`files/axonops.repo.release`](files/axonops.repo.release): a configuración do repositorio YUM de AxonOps (release)

## Configuracións de exemplo

### Clúster dun só nodo

**Directorio**: [`examples/strimzi/cloud/`](../examples/strimzi/cloud/)

- **Topoloxía**: un só nodo cos roles de controller e broker combinados
- **Réplicas**: 1
- **Almacenamento**: volume persistente
- **Método de configuración**: por ConfigMap
- **Caso de uso**: desenvolvemento, probas, demos

### Despregamento en cloud (varios nodos)

**Directorio**: [`examples/strimzi/cloud/`](../examples/strimzi/cloud/)

- **Topoloxía**: pools separados de controllers e brokers
- **Controllers**: 3 réplicas
- **Brokers**: 3 réplicas
- **Método de configuración**: por ConfigMap coa configuración completa do axente
- **Prestacións**:
  - Conciencia de rack activada
  - Configuración de rexistro personalizada
  - Configuración de AxonOps separada para controllers e brokers
- **Caso de uso**: despregamentos de produción en cloud

### Almacenamento en disco local

**Directorio**: [`examples/strimzi/local-disk/`](../examples/strimzi/local-disk/)

- **Topoloxía**: pools separados de controllers e brokers
- **Almacenamento**: volumes persistentes locais
- **Prestacións**:
  - Configuración de StorageClass
  - Configuración de RBAC
  - Aprovisionamento de volumes
- **Caso de uso**: despregamentos on-premises con almacenamento local

### Clúster de Kafka Connect

**Ficheiro**: [`examples/strimzi/cloud/kafka-connect.yaml`](../examples/strimzi/cloud/kafka-connect.yaml)

- **Compoñente**: workers de Kafka Connect
- **Réplicas**: 1 (pódese escalar segundo faga falta)
- **Método de configuración**: por ConfigMap
- **Prestacións**:
  - Soporte de recursos Connector activado
  - Monitorización de AxonOps para os workers de Connect
  - Topics de almacenamento configurables para os metadatos de Connect
- **Topics de configuración**:
  - Almacenamento de configuración: `connect-configs`
  - Almacenamento de estado: `connect-status`
  - Almacenamento de offsets: `connect-offsets`
- **Caso de uso**: integración de datos, pipelines ETL, transmisión de datos entre Kafka e sistemas externos

## Compatibilidade de versións

| Compoñente | Versión | Notas |
| --------- | ------- | ----- |
| Strimzi | 1.1.0 (última) | O soporte de ConfigMap require 0.44+, e o modo KRaft é obrigatorio |
| Kafka | 4.3.0 (última) | A versión 1.1.0 admite Kafka 4.2.0, 4.2.1 e 4.3.0 |
| Kubernetes | 1.24+ | Calquera distribución conforme á CNCF |
| Axente de AxonOps | Última | Instálase automaticamente dende o repositorio |

### Historial de versións de Strimzi

| Versión de Strimzi | Versións de Kafka admitidas | Data de publicación |
| --------------- | ------------------------ | ------------ |
| 1.1.0 | 4.2.0, 4.2.1, 4.3.0 | xuñ. 2026 |
| 1.0.1 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | xuñ. 2026 |
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
