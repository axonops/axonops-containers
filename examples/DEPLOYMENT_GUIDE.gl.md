# Guía de despregamento on-premises

[English](DEPLOYMENT_GUIDE.md) | [Français](DEPLOYMENT_GUIDE.fr.md) | [Español](DEPLOYMENT_GUIDE.es.md) | **Galego**

Benvido á guía de despregamento on-premises de AxonOps e de solucións de
plataforma de datos sobre Kubernetes.

## Visión xeral

Esta guía ofrece instrucións de despregamento para executar varias plataformas de
datos sobre Kubernetes, con capacidades opcionais de monitorización e xestión de
AxonOps.

## Navegación rápida

| Compoñente | Descrición | Guía |
| --- | --- | --- |
| AxonOps | Plataforma de monitorización e xestión | [AXONOPS_DEPLOYMENT.gl.md](AXONOPS_DEPLOYMENT.gl.md) |
| Strimzi Kafka | Apache Kafka sobre Kubernetes | [STRIMZI_DEPLOYMENT.gl.md](STRIMZI_DEPLOYMENT.gl.md) |
| K8ssandra | Apache Cassandra sobre Kubernetes | [K8SSANDRA_DEPLOYMENT.gl.md](K8SSANDRA_DEPLOYMENT.gl.md) |

## Manifestos de exemplo

Hai manifestos de Kubernetes listos para usar nos seguintes directorios:

| Directorio | Descrición |
| --- | --- |
| [axonops/](axonops/) | Servidor, panel e compoñentes de base de datos de AxonOps |
| [strimzi/cloud/](strimzi/cloud/) | Strimzi Kafka de produción para entornos cloud |
| [strimzi/local-disk/](strimzi/local-disk/) | Strimzi Kafka con volumes persistentes locais |
| [k8ssandra/](k8ssandra/) | Exemplos de clúster de Cassandra con K8ssandra |

## Requisitos previos

Todos os despregamentos requiren:

1. **Un clúster de Kubernetes** (v1.21+)
   - Admite un só nodo ou varios nodos

2. **Ferramentas de liña de comandos**
   - `kubectl`: a CLI de Kubernetes
   - `helm`: o xestor de paquetes Helm v3.x ou posterior
   - `envsubst`: substitución de variables (parte do paquete `gettext`)

3. **Acceso ao clúster**
   - Un contexto de `kubectl` configurado
   - Permisos abondos (cluster-admin ou equivalente)

4. **Almacenamento** (escolla un)
   - Un provisionador de almacenamento dinámico (recomendado para produción)
   - Almacenamento hostPath (para probas nun só nodo)

### Instalar envsubst

O comando `envsubst` úsase para substituír variables de entorno en modelos YAML.

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

**Verificar a instalación:**
```bash
envsubst --version
```

---

## Escenarios de despregamento

### Escenario 1: só AxonOps

Despregue unicamente a plataforma de monitorización, para monitorizar clústeres
existentes:

```bash
cd axonops/
export AXON_SEARCH_PASSWORD='your-secure-password'
export AXON_SERVER_CQL_PASSWORD='your-secure-cql-password'
./axonops-setup.sh
```

Consulte [AXONOPS_DEPLOYMENT.gl.md](AXONOPS_DEPLOYMENT.gl.md) para todos os
detalles.

---

### Escenario 2: Kafka con monitorización de AxonOps (recomendado)

Despregue Kafka con monitorización completa:

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

Consulte [AXONOPS_DEPLOYMENT.gl.md](AXONOPS_DEPLOYMENT.gl.md) e
[STRIMZI_DEPLOYMENT.gl.md](STRIMZI_DEPLOYMENT.gl.md).

---

### Escenario 3: Kafka pola súa conta (exemplos de cloud)

Despregue Kafka usando os manifestos de exemplo para cloud:

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

Consulte [strimzi/cloud/README.md](strimzi/cloud/README.md) para todos os
detalles.

---

### Escenario 4: Cassandra con K8ssandra

Despregue Apache Cassandra usando K8ssandra:

```bash
cd k8ssandra/

# Configure environment variables
export $(grep -v '^#' k8ssandra-config.env | xargs)

# Apply the cluster manifest
envsubst < cluster-axonops-ubi.yaml | kubectl apply -f -
```

Consulte [K8SSANDRA_DEPLOYMENT.gl.md](K8SSANDRA_DEPLOYMENT.gl.md) para todos os
detalles.

---

### Escenario 5: pila completa (AxonOps + Kafka + Cassandra)

Despregue a pila completa de monitorización e plataforma de datos:

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

## Usar envsubst cos manifestos

Moitos manifestos de exemplo usan marcadores de variables de entorno
(`${VAR_NAME}`). Use `envsubst` para substituír os valores antes de aplicalos:

### Uso básico

```bash
# Source configuration file
export $(grep -v '^#' config.env | xargs)

# Apply manifest with variable substitution
envsubst < manifest.yaml | kubectl apply -f -
```

### Procesar varios ficheiros

```bash
# Source configuration
source strimzi-config.env

# Apply all manifests in order
for f in manifest1.yaml manifest2.yaml manifest3.yaml; do
  envsubst < $f | kubectl apply -f -
done
```

### Xerar manifestos xa procesados

Para GitOps ou para revisión, xere manifestos completamente procesados:

```bash
export $(grep -v '^#' config.env | xargs)

# Generate single output file
envsubst < input.yaml > processed-output.yaml

# Or generate multiple files
for f in *.yaml; do
  envsubst < $f > processed/$f
done
```

### Substitución selectiva de variables

Para substituír só determinadas variables:

```bash
# Only substitute NAMESPACE and CLUSTER_NAME
envsubst '$NAMESPACE $CLUSTER_NAME' < manifest.yaml | kubectl apply -f -
```

---

## Verificación

Tras o despregamento, verifique que todos os compoñentes están en execución:

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
- **Configuración do axente de AxonOps**: [https://axonops.com/docs/get_started/agent_setup/](https://axonops.com/docs/get_started/agent_setup/)
- **Documentación de Strimzi**: [https://strimzi.io/docs/](https://strimzi.io/docs/)
- **Documentación de K8ssandra**: [https://docs.k8ssandra.io/](https://docs.k8ssandra.io/)
- **Documentación de Apache Kafka**: [https://kafka.apache.org/documentation/](https://kafka.apache.org/documentation/)
- **Documentación de Apache Cassandra**: [https://cassandra.apache.org/doc/](https://cassandra.apache.org/doc/)

---

**Última actualización:** 2026-02-13
