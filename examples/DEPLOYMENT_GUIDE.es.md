# Guía de despliegue on-premises

[English](DEPLOYMENT_GUIDE.md) | [Français](DEPLOYMENT_GUIDE.fr.md) | **Español** | [Galego](DEPLOYMENT_GUIDE.gl.md)

Bienvenido a la guía de despliegue on-premises de AxonOps y de soluciones de
plataforma de datos sobre Kubernetes.

## Visión general

Esta guía ofrece instrucciones de despliegue para ejecutar varias plataformas de
datos sobre Kubernetes, con capacidades opcionales de monitorización y gestión de
AxonOps.

## Navegación rápida

| Componente | Descripción | Guía |
| --- | --- | --- |
| AxonOps | Plataforma de monitorización y gestión | [AXONOPS_DEPLOYMENT.es.md](AXONOPS_DEPLOYMENT.es.md) |
| Strimzi Kafka | Apache Kafka sobre Kubernetes | [STRIMZI_DEPLOYMENT.es.md](STRIMZI_DEPLOYMENT.es.md) |
| K8ssandra | Apache Cassandra sobre Kubernetes | [K8SSANDRA_DEPLOYMENT.es.md](K8SSANDRA_DEPLOYMENT.es.md) |

## Manifiestos de ejemplo

Hay manifiestos de Kubernetes listos para usar en los siguientes directorios:

| Directorio | Descripción |
| --- | --- |
| [axonops/](axonops/) | Servidor, panel y componentes de base de datos de AxonOps |
| [strimzi/cloud/](strimzi/cloud/) | Strimzi Kafka de producción para entornos cloud |
| [strimzi/local-disk/](strimzi/local-disk/) | Strimzi Kafka con volúmenes persistentes locales |
| [k8ssandra/](k8ssandra/) | Ejemplos de clúster de Cassandra con K8ssandra |

## Requisitos previos

Todos los despliegues requieren:

1. **Un clúster de Kubernetes** (v1.21+)
   - Admite un solo nodo o varios nodos

2. **Herramientas de línea de comandos**
   - `kubectl`: la CLI de Kubernetes
   - `helm`: el gestor de paquetes Helm v3.x o posterior
   - `envsubst`: sustitución de variables (parte del paquete `gettext`)

3. **Acceso al clúster**
   - Un contexto de `kubectl` configurado
   - Permisos suficientes (cluster-admin o equivalente)

4. **Almacenamiento** (elija uno)
   - Un provisionador de almacenamiento dinámico (recomendado para producción)
   - Almacenamiento hostPath (para pruebas en un solo nodo)

### Instalar envsubst

El comando `envsubst` se usa para sustituir variables de entorno en plantillas
YAML.

**macOS:**
```bash
brew install gettext
brew link --force gettext
```

**Ubuntu/Debian:**
```bash
sudo apt-get install gettext-base
```

**RHEL/CentOS:**
```bash
sudo yum install gettext
```

**Verificar la instalación:**
```bash
envsubst --version
```

---

## Escenarios de despliegue

### Escenario 1: sólo AxonOps

Despliegue únicamente la plataforma de monitorización, para monitorizar clústeres
existentes:

```bash
cd axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh
```

Consulte [AXONOPS_DEPLOYMENT.es.md](AXONOPS_DEPLOYMENT.es.md) para todos los
detalles.

---

### Escenario 2: Kafka con monitorización de AxonOps (recomendado)

Despliegue Kafka con monitorización completa:

```bash
# Step 1: Deploy AxonOps monitoring platform
cd axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh

# Step 2: Configure Strimzi (edit strimzi-setup.env as needed)
vi strimzi-setup.env

# Step 3: Deploy Kafka with automatic monitoring integration
source axonops-config.env
source strimzi-setup.env
./strimzi-setup.sh
```

Consulte [AXONOPS_DEPLOYMENT.es.md](AXONOPS_DEPLOYMENT.es.md) y
[STRIMZI_DEPLOYMENT.es.md](STRIMZI_DEPLOYMENT.es.md).

---

### Escenario 3: Kafka por su cuenta (ejemplos de cloud)

Despliegue Kafka usando los manifiestos de ejemplo para cloud:

```bash
cd strimzi/cloud/

# Configure and source environment variables
vi strimzi-config.env
source strimzi-config.env

# Create the AxonOps secret
kubectl create secret generic axonops-agent -n kafka \
  --from-literal=AXON_AGENT_CLUSTER_NAME=$AXON_AGENT_CLUSTER_NAME \
  --from-literal=AXON_AGENT_ORG=$AXON_AGENT_ORG \
  --from-literal=AXON_AGENT_SERVER_HOST=$AXON_AGENT_SERVER_HOST \
  --from-literal=AXON_AGENT_KEY=$AXON_AGENT_KEY

# Apply manifests
kubectl apply -f kafka-logging-cm.yaml
kubectl apply -f kafka-node-pool-controller.yaml
kubectl apply -f kafka-node-pool-brokers.yaml
kubectl apply -f kafka-cluster.yaml
```

Consulte [strimzi/cloud/README.md](strimzi/cloud/README.md) para todos los
detalles.

---

### Escenario 4: Cassandra con K8ssandra

Despliegue Apache Cassandra usando K8ssandra:

```bash
cd k8ssandra/

# Configure environment variables
export $(grep -v '^#' k8ssandra-config.env | xargs)

# Apply the cluster manifest
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

Consulte [K8SSANDRA_DEPLOYMENT.es.md](K8SSANDRA_DEPLOYMENT.es.md) para todos los
detalles.

---

### Escenario 5: pila completa (AxonOps + Kafka + Cassandra)

Despliegue la pila completa de monitorización y plataforma de datos:

```bash
# Step 1: Deploy AxonOps
cd axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh
source axonops-config.env

# Step 2: Deploy Kafka
export STRIMZI_NODE_HOSTNAME='your-node-name'
./strimzi-setup.sh

# Step 3: Deploy Cassandra
cd ../k8ssandra/
export $(grep -v '^#' k8ssandra-config.env | xargs)
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

---

## Usar envsubst con los manifiestos

Muchos manifiestos de ejemplo usan marcadores de variables de entorno
(`${VAR_NAME}`). Use `envsubst` para sustituir los valores antes de aplicarlos:

### Uso básico

```bash
# Source configuration file
export $(grep -v '^#' config.env | xargs)

# Apply manifest with variable substitution
envsubst < manifest.yaml | kubectl apply -f -
```

### Procesar varios ficheros

```bash
# Source configuration
source strimzi-config.env

# Apply all manifests in order
for f in manifest1.yaml manifest2.yaml manifest3.yaml; do
  envsubst < $f | kubectl apply -f -
done
```

### Generar manifiestos ya procesados

Para GitOps o para revisión, genere manifiestos completamente procesados:

```bash
export $(grep -v '^#' config.env | xargs)

# Generate single output file
envsubst < input.yaml > processed-output.yaml

# Or generate multiple files
for f in *.yaml; do
  envsubst < $f > processed/$f
done
```

### Sustitución selectiva de variables

Para sustituir sólo determinadas variables:

```bash
# Only substitute NAMESPACE and CLUSTER_NAME
envsubst '$NAMESPACE $CLUSTER_NAME' < manifest.yaml | kubectl apply -f -
```

---

## Verificación

Tras el despliegue, verifique que todos los componentes están en ejecución:

```bash
# Check all namespaces
kubectl get pods -A | grep -E "axonops|kafka|k8ssandra|strimzi"

# Check specific namespace
kubectl get pods -n kafka
kubectl get pods -n axonops
kubectl get pods -n k8ssandra-operator
```

---

## Soporte

- **Documentación de AxonOps**: [https://docs.axonops.com](https://docs.axonops.com)
- **Configuración del agente de AxonOps**: [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Documentación de Strimzi**: [https://strimzi.io/docs/](https://strimzi.io/docs/)
- **Documentación de K8ssandra**: [https://docs.k8ssandra.io/](https://docs.k8ssandra.io/)
- **Documentación de Apache Kafka**: [https://kafka.apache.org/documentation/](https://kafka.apache.org/documentation/)
- **Documentación de Apache Cassandra**: [https://cassandra.apache.org/doc/](https://cassandra.apache.org/doc/)

---

**Última actualización:** 2026-02-13
