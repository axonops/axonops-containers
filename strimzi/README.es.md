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
helm upgrade --install strimzi-kafka-operator \
  oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  --version 1.1.0 \
  --namespace strimzi --create-namespace \
  --set watchAnyNamespace=true \
  --wait
```

### 2. Desplegar un clúster de Kafka

En [`examples/strimzi/`](../examples/strimzi/) hay manifiestos listos para usar. Cada directorio tiene un fichero `strimzi-config.env` y un README con los pasos completos:

| Ejemplo | Almacenamiento | Destino de AxonOps |
| --- | --- | --- |
| [`cloud/`](../examples/strimzi/cloud/) | PVCs de una StorageClass | AxonOps Cloud |
| [`on-premises/`](../examples/strimzi/on-premises/) | PVCs de una StorageClass | AxonOps autoalojado |
| [`local-disk/`](../examples/strimzi/local-disk/) | Volúmenes hostPath fijados a nodos | AxonOps autoalojado |

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

`kafka-connect.yaml`, en los mismos directorios, añade un clúster de Kafka Connect cuyos workers reportan a AxonOps con el tipo de nodo `connect`. El soporte de Kafka Connect está en beta.

Consulte la [guía de despliegue de Strimzi](../examples/STRIMZI_DEPLOYMENT.es.md) para la compatibilidad de versiones del operador y de la imagen.

## Detalles de configuración

### Variables de entorno del agente

La imagen lee los ajustes del agente de variables de entorno del contenedor de Kafka. Los ejemplos las definen desde un Secret con `valueFrom.secretKeyRef`.

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `KAFKA_NODE_TYPE` | Rol del nodo de Kafka | `kraft-controller`, `kraft-broker` o `connect` |
| `AXON_AGENT_CLUSTER_NAME` | Nombre del clúster que se muestra en AxonOps | `my-kafka-prod` |
| `AXON_AGENT_ORG` | Nombre de la organización de AxonOps | El nombre de su organización |
| `AXON_AGENT_KEY` | Clave del agente de AxonOps | Su clave de la consola de AxonOps |
| `AXON_AGENT_SERVER_HOST` | Nombre de host del servidor de AxonOps | `agents.axonops.cloud` |
| `AXON_AGENT_SERVER_PORT` | Puerto del servidor de AxonOps | `443`, o `1888` para un servidor autoalojado |
| `AXON_AGENT_TLS_MODE` | Modo TLS del agente | `TLS` o `disabled` |

### Fichero de configuración

Para configurar el agente con un fichero `axon-agent.yml` completo, móntelo en `/mnt/axon-agent.yml`, por ejemplo desde un ConfigMap mediante `template.pod.volumes` y `template.kafkaContainer.volumeMounts` en el KafkaNodePool. La imagen lo enlaza a `/etc/axonops/axon-agent.yml` al arrancar.

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
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    rack:
      topologyKey: topology.kubernetes.io/zone
```

Los ejemplos definen `topologyKey` a partir de `KAFKA_RACK_TOPOLOGY_KEY`:
`topology.kubernetes.io/zone` en `cloud/`, `kubernetes.io/hostname` en
`on-premises/` y `local-disk/`.

## Construir imágenes personalizadas

### Build local para desarrollo

Para construir una imagen personalizada en local, para pruebas:

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
kubectl delete $(kubectl get strimzi -o name -n "$KAFKA_NAMESPACE") -n "$KAFKA_NAMESPACE"

# Delete persistent volume claims
kubectl delete pvc --all -n "$KAFKA_NAMESPACE"

# Uninstall Strimzi operator
helm uninstall strimzi-kafka-operator -n strimzi

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
kubectl get pods -n "$KAFKA_NAMESPACE"
kubectl describe pod <pod-name> -n "$KAFKA_NAMESPACE"
```

### Consultar los registros

```bash
# Kafka broker logs
kubectl logs <broker-pod-name> -n "$KAFKA_NAMESPACE"

# AxonOps agent logs
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- tail -f /var/log/axonops/axon-agent.log

# Follow all logs from a pod
kubectl logs -f <pod-name> -n "$KAFKA_NAMESPACE"
```

### Verificar la conexión con AxonOps

```bash
# Check if agent is running
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- ps aux | grep axon

# Check agent configuration
kubectl exec <pod-name> -n "$KAFKA_NAMESPACE" -- cat /etc/axonops/axon-agent.yml
```

### Problemas habituales

**Problema**: los pods se quedan en `Pending` o `CrashLoopBackOff`.
- Compruebe la disponibilidad de recursos: `kubectl describe pod <pod-name> -n "$KAFKA_NAMESPACE"`
- Verifique el estado de las PVC: `kubectl get pvc -n "$KAFKA_NAMESPACE"`

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
  El envoltorio también añade `-XX:-UseBASE64Intrinsics` a `KAFKA_OPTS` para mitigar CVE-2026-114938. Va en primer lugar, de modo que un `-XX:+UseBASE64Intrinsics` posterior en tu propio `KAFKA_OPTS` lo anula.
- [`files/axonops.repo.dev`](files/axonops.repo.dev): la configuración del repositorio YUM de AxonOps (dev)
- [`files/axonops.repo.release`](files/axonops.repo.release): la configuración del repositorio YUM de AxonOps (release)

## Configuraciones de ejemplo

Los ejemplos se describen en [`examples/STRIMZI_DEPLOYMENT.es.md`](../examples/STRIMZI_DEPLOYMENT.es.md). Los tres crean un clúster de Kafka con pools separados de controllers y brokers KRaft, conciencia de rack y el agente de AxonOps en cada contenedor.

## Compatibilidad de versiones

| Componente | Versión | Notas |
| --------- | ------- | ----- |
| Strimzi | 1.2.0 (última) | El soporte de ConfigMap requiere 0.44+, y el modo KRaft es obligatorio |
| Kafka | 4.3.1 (última) | La versión 1.2.0 admite Kafka 4.2.0, 4.2.1, 4.3.0 y 4.3.1 |
| Kubernetes | 1.24+ | Cualquier distribución conforme a la CNCF |
| Agente de AxonOps | Última | Se instala automáticamente desde el repositorio |

### Historial de versiones de Strimzi

| Versión de Strimzi | Versiones de Kafka admitidas | Fecha de publicación |
| --------------- | ------------------------ | ------------ |
| 1.2.0 | 4.2.0, 4.2.1, 4.3.0, 4.3.1 | ago. 2026 |
| 1.1.0 | 4.2.0, 4.2.1, 4.3.0 | jun. 2026 |
| 1.0.1 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | jun. 2026 |
| 1.0.0 | 4.1.0, 4.1.1, 4.1.2, 4.2.0 | abr. 2026 |
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
