# AxonOps Strimzi Kafka

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

Este repositorio ofrece imágenes de contenedor de Strimzi Kafka personalizadas,
con los componentes de monitorización y observabilidad de AxonOps integrados.

## Visión general

La integración de AxonOps con Strimzi permite construir clústeres de Kafka sobre
Kubernetes con el [operador Strimzi](https://strimzi.io/) que reportan
automáticamente métricas y registros a AxonOps. Esto se consigue extendiendo las
imágenes estándar de Strimzi Kafka con los componentes del agente de AxonOps.

## Prestaciones

- **Soporte de KRaft**: construidas sobre el modo KRaft de Strimzi (Kafka sin ZooKeeper)
- **Monitorización de AxonOps**: recogida automática de métricas y envío de registros
- **Configuración flexible**: admite configuración por ConfigMap y por variables de entorno
- **Conciencia de rack**: soporte de la conciencia de rack basada en la topología de Kubernetes
- **Escaneo de seguridad**: escaneo de seguridad con Trivy integrado en el CI/CD

## Requisitos previos

- Un clúster de Kubernetes (probado con k3s, pero debería funcionar con cualquier distribución de Kubernetes)
- Helm 3.x
- `kubectl` configurado para acceder a su clúster
- Una cuenta de AxonOps con clave de API

## Inicio rápido

### 1. Instalar el operador Strimzi

```bash
helm repo add strimzi https://strimzi.io/charts/
helm install my-strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --version 0.46.0 \
  --set watchAnyNamespace=true
```

### 2. Crear el espacio de nombres de Kafka

```bash
kubectl create namespace kafka
```

### 3. Desplegar el clúster de Kafka

Elija uno de los métodos de configuración de abajo según sus necesidades.

#### Opción A: despliegue en cloud (varios nodos)

Para despliegues de producción en cloud con pools separados de controllers y
brokers.

Consulte el directorio
[`examples/strimzi/cloud/`](../examples/strimzi/cloud/) para todos los
manifiestos necesarios:

- `kafka-cluster.yaml`: la configuración principal del clúster de Kafka
- `kafka-node-pool-controller.yaml`: el pool de nodos controller
- `kafka-node-pool-brokers.yaml`: el pool de nodos broker
- `kafka-logging-cm.yaml`: la configuración de registro
- `axonops-config-secret.yaml`: las credenciales de AxonOps

**Actualice los siguientes valores**:

- `YOUR_AXONOPS_HOST`: el nombre de host de su servidor de AxonOps (por ejemplo, `agents.axonops.com`)
- `YOUR_AXONOPS_API_KEY`: la clave de API de su organización de AxonOps
- `YOUR_CLUSTER_NAME`: un nombre único para este clúster de Kafka
- `YOUR_ORG_NAME`: el nombre de su organización de AxonOps

Después aplique:

```bash
kubectl apply -f ../examples/strimzi/cloud/ -n kafka
kubectl get pod -n kafka --watch
```

#### Opción B: un solo nodo (desarrollo y pruebas)

Para desarrollo o pruebas, puede desplegar un clúster de Kafka de un solo nodo
con los roles de controller y broker combinados.

Consulte el directorio [`examples/strimzi/cloud/`](../examples/strimzi/cloud/):

- `kafka-single-node.yaml`: el clúster de Kafka de un solo nodo
- `axonops-agent-config.yaml`: la configuración del agente de AxonOps
- `axonops-kafka-logging.yaml`: la configuración de registro
- `axonops-kafka-nodepool.yaml`: la configuración del pool de nodos

**Actualice los valores** y aplique:

```bash
kubectl apply -f ../examples/strimzi/cloud/ -n kafka
kubectl get pod -n kafka --watch
```

#### Opción C: almacenamiento en disco local

Para despliegues que usan volúmenes persistentes locales.

Consulte el directorio
[`examples/strimzi/local-disk/`](../examples/strimzi/local-disk/) para todos los
manifiestos necesarios.

```bash
kubectl apply -f ../examples/strimzi/local-disk/ -n kafka
kubectl get pod -n kafka --watch
```

#### Opción D: clúster de Kafka Connect

Despliegue un clúster de Kafka Connect para transmitir datos entre Kafka y otros
sistemas.

**Requisitos previos**: tener un clúster de Kafka en funcionamiento (desplegado
con alguna de las opciones anteriores).

**Actualice los siguientes valores** en
[`examples/strimzi/cloud/kafka-connect.yaml`](../examples/strimzi/cloud/kafka-connect.yaml):

- `YOUR_AXONOPS_HOST`: el nombre de host de su servidor de AxonOps (por ejemplo, `agents.axonops.com`)
- `YOUR_AXONOPS_API_KEY`: la clave de API de su organización de AxonOps
- `YOUR_CLUSTER_NAME`: un nombre único para este clúster de Kafka Connect
- `YOUR_ORG_NAME`: el nombre de su organización de AxonOps
- `ghcr.io/axonops/strimzi/kafka:latest`: sustitúyala por su imagen concreta de Kafka con AxonOps
- `my-cluster-kafka-bootstrap:9092`: sustitúyala por la dirección real de su servidor bootstrap de Kafka

Después aplique:

```bash
kubectl apply -f ../examples/strimzi/cloud/kafka-connect.yaml -n kafka
kubectl get pod -n kafka --watch
```

**Nota**: el soporte de Kafka Connect está actualmente en beta. Los workers de
Connect reportarán métricas a AxonOps con el tipo de nodo `connect`.

## Detalles de configuración

### Variables de entorno obligatorias

Al usar la configuración por variables de entorno, hay que definir estas
variables:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `KAFKA_NODE_TYPE` | Rol del nodo de Kafka | `kraft-controller` o `kraft-broker` |
| `AXON_AGENT_SERVER_HOST` | Nombre de host del servidor de AxonOps | `agents.axonops.com` |
| `AXON_AGENT_KEY` | Clave de API de AxonOps | Su clave de API del panel de AxonOps |
| `AGENT_CLUSTER_NAME` | Identificador único del clúster | `my-kafka-prod` |
| `AXON_AGENT_ORG` | Nombre de la organización de AxonOps | El nombre de su organización |

### Variables de entorno opcionales

| Variable | Descripción | Valor por defecto |
|----------|-------------|---------|
| `KAFKA_CLIENT_BROKERS` | Direcciones de los brokers (para los brokers) | `0.0.0.0:9092` |

### Configuración por ConfigMap

El enfoque de ConfigMap permite proporcionar un fichero `axon-agent.yml`
completo. Resulta útil para:

- Configuración avanzada de la recogida de métricas
- Ajustes de registro personalizados
- Despliegues en varios datacenters
- Control fino del comportamiento del agente

Consulte [`examples/strimzi/cloud/`](../examples/strimzi/cloud/) para la
estructura completa.

## Conciencia de rack

La conciencia de rack de Kafka se apoya en las etiquetas de nodo de Kubernetes.
Ayuda a garantizar que las réplicas se reparten entre zonas de disponibilidad.

### Etiquete sus nodos

```bash
kubectl label node <node-name> topology.kubernetes.io/zone=<zone-name>
```

Ejemplo:

```bash
kubectl label node worker-1 topology.kubernetes.io/zone=us-east-1a
kubectl label node worker-2 topology.kubernetes.io/zone=us-east-1b
kubectl label node worker-3 topology.kubernetes.io/zone=us-east-1c
```

### Configúrelo en el CRD de Kafka

La configuración de conciencia de rack ya viene en los manifiestos de ejemplo:

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

La etiqueta de nodo es `topology.kubernetes.io/zone` por defecto, pero puede
cambiarse con el parámetro `topologyKey`.

## Construir imágenes personalizadas

### Build local para desarrollo

Para construir una imagen personalizada en local, para pruebas:

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

**Importante**: use `axon-kafka3-agent` para las versiones 3.x de Kafka y
`axon-kafka4-agent` para las 4.x.

### Pipeline de CI/CD

El repositorio incluye un workflow de GitHub Actions en
[`.github/workflows/strimzi-build-and-test.yml`](../.github/workflows/strimzi-build-and-test.yml)
que:

1. Construye la imagen del operador Strimzi con los componentes de AxonOps
2. Ejecuta el escaneo de seguridad con Trivy
3. Valida el proceso de build de la imagen

El workflow se dispara con:
- Pushes a las ramas `main`, `development`, `feature/**`, `feat/**`, `fix/**` y `bug/**`
- Pull requests a `main` o `development`
- Cambios en ficheros del directorio `strimzi/`

### Etiquetado para builds de producción

Para lanzar un pipeline de build de producción, cree una etiqueta con este
formato:

```
<environment>/<strimzi-version>-kafka-<kafka-version>-<build-number>
```

**Ejemplos:**

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

**Donde:**
- `<environment>`: `dev`, `beta` o `release`
- `<strimzi-version>`: la versión del operador Strimzi (por ejemplo, `0.49.1`)
- `<kafka-version>`: la versión de Kafka (por ejemplo, `4.1.0`)
- `<build-number>`: un número de build incremental (por ejemplo, `1`, `2`, `3`)

## Limpieza

### Eliminar el clúster de Kafka

Para eliminar todos los recursos de Kafka del clúster de ejemplo:

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

### Limpiar las imágenes de Kubernetes (ejemplo con k3s)

```bash
k3s crictl rmi ghcr.io/axonops/strimzi/kafka:0.47.0-3.9.0
```

## Resolución de problemas

### Comprobar el estado de los pods

```bash
kubectl get pods -n kafka
kubectl describe pod <pod-name> -n kafka
```

### Consultar los registros

```bash
# Kafka broker logs
kubectl logs <broker-pod-name> -n kafka

# AxonOps agent logs
kubectl exec <pod-name> -n kafka -- tail -f /var/log/axonops/axon-agent.log

# Follow all logs from a pod
kubectl logs -f <pod-name> -n kafka
```

### Verificar la conexión con AxonOps

```bash
# Check if agent is running
kubectl exec <pod-name> -n kafka -- ps aux | grep axon

# Check agent configuration
kubectl exec <pod-name> -n kafka -- cat /etc/axonops/axon-agent.yml
```

### Problemas habituales

**Problema**: los pods se quedan en `Pending` o `CrashLoopBackOff`.
- Compruebe la disponibilidad de recursos: `kubectl describe pod <pod-name> -n kafka`
- Verifique el estado de las PVC: `kubectl get pvc -n kafka`

**Problema**: el agente de AxonOps no reporta métricas.
- Verifique que la clave de API es correcta en la configuración
- Compruebe la conectividad de red con el servidor de AxonOps
- Revise los registros del agente en busca de errores

## Arquitectura

Las imágenes personalizadas se construyen así:

1. Se parte de la imagen base oficial de Strimzi Kafka (`quay.io/strimzi/kafka`)
2. Se añade el repositorio YUM de AxonOps
3. Se instalan los paquetes del agente de AxonOps y del agente de Kafka
4. Se inyecta el script envoltorio de AxonOps en los scripts de arranque de Kafka
5. Se configuran los permisos y la pertenencia a grupos

Ficheros clave:

- [`Dockerfile`](Dockerfile): la definición del build de la imagen
- [`files/axonops-wrapper.sh`](files/axonops-wrapper.sh): el envoltorio de arranque para la integración de AxonOps
- [`files/axonops.repo.dev`](files/axonops.repo.dev): la configuración del repositorio YUM de AxonOps (dev)
- [`files/axonops.repo.release`](files/axonops.repo.release): la configuración del repositorio YUM de AxonOps (release)

## Configuraciones de ejemplo

### Clúster de un solo nodo

**Directorio**: [`examples/strimzi/cloud/`](../examples/strimzi/cloud/)

- **Topología**: un solo nodo con los roles de controller y broker combinados
- **Réplicas**: 1
- **Almacenamiento**: volumen persistente
- **Método de configuración**: por ConfigMap
- **Caso de uso**: desarrollo, pruebas, demos

### Despliegue en cloud (varios nodos)

**Directorio**: [`examples/strimzi/cloud/`](../examples/strimzi/cloud/)

- **Topología**: pools separados de controllers y brokers
- **Controllers**: 3 réplicas
- **Brokers**: 3 réplicas
- **Método de configuración**: por ConfigMap con la configuración completa del agente
- **Prestaciones**:
  - Conciencia de rack activada
  - Configuración de registro personalizada
  - Configuración de AxonOps separada para controllers y brokers
- **Caso de uso**: despliegues de producción en cloud

### Almacenamiento en disco local

**Directorio**: [`examples/strimzi/local-disk/`](../examples/strimzi/local-disk/)

- **Topología**: pools separados de controllers y brokers
- **Almacenamiento**: volúmenes persistentes locales
- **Prestaciones**:
  - Configuración de StorageClass
  - Configuración de RBAC
  - Aprovisionamiento de volúmenes
- **Caso de uso**: despliegues on-premises con almacenamiento local

### Clúster de Kafka Connect

**Fichero**: [`examples/strimzi/cloud/kafka-connect.yaml`](../examples/strimzi/cloud/kafka-connect.yaml)

- **Componente**: workers de Kafka Connect
- **Réplicas**: 1 (se puede escalar según haga falta)
- **Método de configuración**: por ConfigMap
- **Prestaciones**:
  - Soporte de recursos Connector activado
  - Monitorización de AxonOps para los workers de Connect
  - Topics de almacenamiento configurables para los metadatos de Connect
- **Topics de configuración**:
  - Almacenamiento de configuración: `connect-configs`
  - Almacenamiento de estado: `connect-status`
  - Almacenamiento de offsets: `connect-offsets`
- **Caso de uso**: integración de datos, pipelines ETL, transmisión de datos entre Kafka y sistemas externos

## Compatibilidad de versiones

| Componente | Versión | Notas |
| --------- | ------- | ----- |
| Strimzi | 1.1.0 (última) | El soporte de ConfigMap requiere 0.44+, y el modo KRaft es obligatorio |
| Kafka | 4.3.0 (última) | La versión 1.1.0 admite Kafka 4.2.0, 4.2.1 y 4.3.0 |
| Kubernetes | 1.24+ | Cualquier distribución conforme a la CNCF |
| Agente de AxonOps | Última | Se instala automáticamente desde el repositorio |

### Historial de versiones de Strimzi

| Versión de Strimzi | Versiones de Kafka admitidas | Fecha de publicación |
| --------------- | ------------------------ | ------------ |
| 1.1.0 | 4.2.0, 4.2.1, 4.3.0 | jun. 2026 |
| 1.0.1 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | jun. 2026 |
| 0.51.0 | 4.1.0, 4.1.1, 4.2.0 | mar. 2026 |
| 0.50.0 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | feb. 2025 |
| 0.49.1 | 4.0.0, 4.0.1, 4.1.0, 4.1.1 | dic. 2024 |
| 0.48.0 | 4.0.0, 4.1.0 | nov. 2024 |
| 0.47.0 | 3.9.0, 3.9.1 | oct. 2024 |

## Limitaciones conocidas y pendientes

- **Kafka Connect**: se ofrece una configuración de ejemplo, pero las pruebas de integración completas están en curso
- **Mirror Maker**: todavía no se construye ni se prueba
- **Modo ZooKeeper**: no está admitido (sólo KRaft)
- **hostId persistente**: valore usar volúmenes persistentes para el fichero hostId del agente de AxonOps

## Soporte

Para incidencias relacionadas con:

- **La integración con AxonOps**: contacte con el soporte de AxonOps
- **El operador Strimzi**: véase la [documentación de Strimzi](https://strimzi.io/docs/)
- **Este repositorio**: abra una incidencia en el repositorio

## Recursos adicionales

- [Documentación de Strimzi](https://strimzi.io/docs/)
- [Documentación de AxonOps](https://docs.axonops.com/)
- [El modo KRaft de Kafka](https://kafka.apache.org/documentation/#kraft)
- [Etiquetas de nodo de Kubernetes](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
