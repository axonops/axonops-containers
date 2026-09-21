# Guía de despregamento de Strimzi Kafka

[English](STRIMZI_DEPLOYMENT.md) | [Français](STRIMZI_DEPLOYMENT.fr.md) | [Español](STRIMZI_DEPLOYMENT.es.md) | **Galego**

Esta guía trata o despregamento de Apache Kafka co operador Strimzi sobre Kubernetes, con integración opcional da monitorización de AxonOps.

## Inicio rápido

### Paso 1: instalar o operador Strimzi

Antes de despregar clústeres de Kafka, instale o operador Strimzi con Helm.

**Importante:** consulte a [páxina de descargas de Strimzi](https://strimzi.io/downloads/) para comprobar que versión de Strimzi admite a versión de Kafka desexada. A matriz de compatibilidade indica as versións de Kafka compatibles con cada release de Strimzi.

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

### Paso 2: despregar o clúster de Kafka

Escolla un dos exemplos de despregamento segundo o seu caso de uso. Cada exemplo inclúe o seu propio README con instrucións de despregamento detalladas:

| Directorio | Caso de uso | Descrición |
| --- | --- | --- |
| [strimzi/cloud/](strimzi/cloud/) | Produción | 6 brokers, 3 controllers, almacenamento na nube |
| [strimzi/local-disk/](strimzi/local-disk/) | On-premises | Volumes persistentes locais, configurables |

Cada directorio de exemplo contén:

- `README.md`: as instrucións de despregamento completas
- `strimzi-config.env`: as variables de configuración
- os manifestos YAML de todos os compoñentes do clúster de Kafka

### Paso 3: engadir a monitorización de AxonOps (opcional)

Consulte [AXONOPS_DEPLOYMENT.gl.md](AXONOPS_DEPLOYMENT.gl.md) para despregar a monitorización de AxonOps. Os manifestos de exemplo de Strimzi xa inclúen as variables de configuración do axente de AxonOps.

---

## Compatibilidade das versións de Strimzi

Comprobe sempre a [matriz de compatibilidade de Strimzi](https://strimzi.io/downloads/) antes de instalar, para asegurarse da compatibilidade:

| Versión de Strimzi | Versións de Kafka admitidas | Versións de Kubernetes |
| --- | --- | --- |
| 0.45.0 | 3.8.x, 3.9.x | 1.25+ |
| 0.44.0 | 3.7.x, 3.8.x | 1.25+ |
| 0.43.0 | 3.7.x, 3.8.x | 1.23+ |

*Nota: esta táboa é unicamente orientativa. Verifique sempre a compatibilidade actual en [strimzi.io/downloads](https://strimzi.io/downloads/).*

## Recursos adicionais

- **Documentación de Strimzi**: [https://strimzi.io/docs/](https://strimzi.io/docs/)
- **Strimzi en GitHub**: [https://github.com/strimzi/strimzi-kafka-operator](https://github.com/strimzi/strimzi-kafka-operator)
- **Guía de node selectors**: [NODE_SELECTOR_GUIDE.gl.md](NODE_SELECTOR_GUIDE.gl.md)

---

**Última actualización:** 2026-02-13
