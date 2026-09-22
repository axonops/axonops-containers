# Guía de despliegue de Strimzi Kafka

[English](STRIMZI_DEPLOYMENT.md) | [Français](STRIMZI_DEPLOYMENT.fr.md) | **Español** | [Galego](STRIMZI_DEPLOYMENT.gl.md)

Esta guía cubre el despliegue de Apache Kafka con el operador Strimzi sobre Kubernetes, con integración opcional de la monitorización de AxonOps.

## Inicio rápido

### Paso 1: instalar el operador Strimzi

Antes de desplegar clústeres de Kafka, instale el operador Strimzi con Helm.

**Importante:** consulte la [página de descargas de Strimzi](https://strimzi.io/downloads/) para comprobar qué versión de Strimzi admite la versión de Kafka que desea. La matriz de compatibilidad indica las versiones de Kafka compatibles con cada release de Strimzi.

```bash
# Add Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Create namespaces
kubectl create namespace strimzi
kubectl create namespace kafka

# Check available versions
helm search repo strimzi --versions

# Install the operator (specify version based on support matrix)
# Example: Strimzi 0.50.0 supports Kafka 4.1.1
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  -n strimzi \
  --version 0.50.0 \
  --set watchNamespaces="{kafka}" \
  --wait

# Verify installation
kubectl get pods -n strimzi
kubectl get crd | grep strimzi
```

### Paso 2: desplegar el clúster de Kafka

Elija uno de los ejemplos de despliegue según su caso de uso. Cada ejemplo incluye su propio README con instrucciones de despliegue detalladas:

| Directorio | Caso de uso | Descripción |
| --- | --- | --- |
| [strimzi/cloud/](strimzi/cloud/) | Producción | 6 brokers, 3 controllers, almacenamiento en la nube |
| [strimzi/local-disk/](strimzi/local-disk/) | On-premises | Volúmenes persistentes locales, configurables |

Cada directorio de ejemplo contiene:

- `README.md`: las instrucciones de despliegue completas
- `strimzi-config.env`: las variables de configuración
- los manifiestos YAML de todos los componentes del clúster de Kafka

### Paso 3: añadir la monitorización de AxonOps (opcional)

Consulte [AXONOPS_DEPLOYMENT.es.md](AXONOPS_DEPLOYMENT.es.md) para desplegar la monitorización de AxonOps. Los manifiestos de ejemplo de Strimzi ya incluyen las variables de configuración del agente de AxonOps.

---

## Compatibilidad de versiones de Strimzi

Compruebe siempre la [matriz de compatibilidad de Strimzi](https://strimzi.io/downloads/) antes de instalar, para asegurarse de la compatibilidad:

| Versión de Strimzi | Versiones de Kafka admitidas | Versiones de Kubernetes |
| --- | --- | --- |
| 0.45.0 | 3.8.x, 3.9.x | 1.25+ |
| 0.44.0 | 3.7.x, 3.8.x | 1.25+ |
| 0.43.0 | 3.7.x, 3.8.x | 1.23+ |

*Nota: esta tabla es únicamente orientativa. Verifique siempre la compatibilidad actual en [strimzi.io/downloads](https://strimzi.io/downloads/).*

## Recursos adicionales

- **Documentación de Strimzi**: [https://strimzi.io/docs/](https://strimzi.io/docs/)
- **Strimzi en GitHub**: [https://github.com/strimzi/strimzi-kafka-operator](https://github.com/strimzi/strimzi-kafka-operator)
- **Guía de node selectors**: [NODE_SELECTOR_GUIDE.es.md](NODE_SELECTOR_GUIDE.es.md)

---

**Última actualización:** 2026-02-13
