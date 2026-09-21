# Panel de AxonOps

[English](README.md) | [Français](README.fr.md) | **Español** | [Galego](README.gl.md)

![Versión: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Tipo: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

Un chart de Helm para desplegar el panel de AxonOps, la interfaz web de la
plataforma de observabilidad de AxonOps. El panel ofrece una interfaz rica para
monitorizar clústeres de Apache Cassandra, consultar métricas, configurar alertas
y gestionar copias de seguridad.

**Página del proyecto:** <https://axonops.com>

## Índice

- [Visión general de la arquitectura](#visión-general-de-la-arquitectura)
- [Requisitos previos](#requisitos-previos)
- [Inicio rápido](#inicio-rápido)
- [Ejemplos de instalación](#ejemplos-de-instalación)
  - [Instalación básica](#instalación-básica)
  - [Instalación con Ingress](#instalación-con-ingress)
  - [Instalación con TLS](#instalación-con-tls)
  - [Instalación con subruta (context path)](#instalación-con-subruta-context-path)
  - [Instalación con autoescalado](#instalación-con-autoescalado)
  - [Instalación lista para producción](#instalación-lista-para-producción)
- [Configuración](#configuración)
- [Actualización](#actualización)
- [Desinstalación](#desinstalación)
- [Resolución de problemas](#resolución-de-problemas)

## Visión general de la arquitectura

El panel de AxonOps es el componente de interfaz web de la plataforma AxonOps:

```
┌──────────────┐
│   Browser    │
│   (User)     │
└──────────────┘
       │
       │ HTTPS :443 (via Ingress)
       ↓
┌──────────────────┐
│  AxonOps Dashboard│  Port: 3000
│  (Web UI)        │
└──────────────────┘
       │
       │ HTTP/HTTPS :8080
       ↓
┌──────────────────┐
│  AxonOps Server  │
│  (API Backend)   │
└──────────────────┘
```

## Requisitos previos

Antes de empezar, asegúrese de tener lo siguiente:

### Componentes obligatorios

- **Un clúster de Kubernetes**: versión 1.19 o superior
- **kubectl**: configurado para comunicarse con su clúster
- **Helm**: versión 3.0 o superior instalada ([guía de instalación](https://helm.sh/docs/intro/install/))
- **El servidor de AxonOps**: ya desplegado y accesible ([guía de instalación](../axon-server/))

### Componentes opcionales

- **Un controlador de Ingress**: necesario para el acceso externo (nginx, traefik, etc.)
- **cert-manager**: para la gestión automática de certificados TLS
- **Un controlador de la Gateway API**: si usa HTTPRoute en lugar de Ingress

### Verificar su instalación

Compruebe que el servidor de AxonOps está en marcha:
```bash
kubectl get pods -l app.kubernetes.io/name=axon-server
```

Compruebe que Helm está instalado:
```bash
helm version
```

## Inicio rápido

La forma más rápida de empezar con el panel de AxonOps:

```bash
# Install with default settings (connects to local axon-server)
helm install axon-dash ./axon-dash \
  --set config.axonServerUrl="http://axon-server-api:8080"

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axon-dash
```

Esto despliega el panel de AxonOps con:
- Una sola réplica
- Un servicio ClusterIP (sólo acceso interno)
- Conexión al servidor de AxonOps local
- El puerto 3000

**Para acceder al panel en local:**
```bash
kubectl port-forward svc/axon-dash 3000:3000
```

Después abra el navegador en http://localhost:3000

## Ejemplos de instalación

### Instalación básica

Instalación con la configuración mínima, apta para desarrollo y pruebas:

```yaml
# values-basic.yaml
# Basic AxonOps Dashboard configuration

# Number of replicas
replicaCount: 1

# Configuration
config:
  # URL to AxonOps Server API
  axonServerUrl: "http://axon-server-api:8080"

  # Listener configuration
  listener:
    host: "0.0.0.0"
    port: 3000

# Resource limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Service configuration
service:
  type: ClusterIP
  port: 3000
```

Instale:

```bash
helm install axon-dash ./axon-dash -f values-basic.yaml
```

Acceda al panel:
```bash
# Port forward to access locally
kubectl port-forward svc/axon-dash 3000:3000

# Open browser to http://localhost:3000
```

### Instalación con Ingress

Exponga el panel al exterior con un Ingress:

```yaml
# values-ingress.yaml
replicaCount: 2

config:
  axonServerUrl: "http://axon-server-api:8080"
  listener:
    host: "0.0.0.0"
    port: 3000

# Enable ingress
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: axonops.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: axon-dash-tls
      hosts:
        - axonops.example.com

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 512Mi
```

Instale:

```bash
helm install axon-dash ./axon-dash -f values-ingress.yaml
```

Acceda al panel:
```bash
# Wait for certificate to be issued
kubectl get certificate

# Access via browser
open https://axonops.example.com
```

### Instalación con TLS

Configure TLS/SSL en la propia aplicación del panel:

**Paso 1: crear el secreto TLS**

```bash
kubectl create secret generic axon-dash-ssl \
  --from-file=cert.pem=path/to/cert.pem \
  --from-file=key.pem=path/to/key.pem
```

**Paso 2: crear el fichero de values**

```yaml
# values-tls.yaml
replicaCount: 2

config:
  axonServerUrl: "http://axon-server-api:8080"

  listener:
    host: "0.0.0.0"
    port: 3000
    # Enable SSL for the application
    ssl:
      enabled: true
      cert: /etc/ssl/certs/cert.pem
      key: /etc/ssl/certs/key.pem

# Mount the SSL certificates
volumes:
  - name: ssl-certs
    secret:
      secretName: axon-dash-ssl

volumeMounts:
  - name: ssl-certs
    mountPath: /etc/ssl/certs
    readOnly: true

# Update service to use HTTPS
service:
  type: ClusterIP
  port: 3000

# Update probes to use HTTPS
livenessProbe:
  httpGet:
    path: /
    port: http
    scheme: HTTPS

readinessProbe:
  httpGet:
    path: /
    port: http
    scheme: HTTPS
```

Instale:

```bash
helm install axon-dash ./axon-dash -f values-tls.yaml
```

### Instalación con subruta (context path)

Ejecute el panel bajo una subruta de la URL (por ejemplo, `/axonops`):

```yaml
# values-subpath.yaml
replicaCount: 2

config:
  axonServerUrl: "http://axon-server-api:8080"

  # Set context path
  contextPath: "/axonops"

  listener:
    host: "0.0.0.0"
    port: 3000

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
  hosts:
    - host: example.com
      paths:
        - path: /axonops(/|$)(.*)
          pathType: ImplementationSpecific
  tls:
    - secretName: example-tls
      hosts:
        - example.com

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 512Mi
```

Instale:

```bash
helm install axon-dash ./axon-dash -f values-subpath.yaml
```

Acceda en: https://example.com/axonops

### Instalación con autoescalado

Active el autoescalado horizontal de pods para alta disponibilidad:

```yaml
# values-autoscaling.yaml
# Minimum replicas managed by HPA
replicaCount: 2

config:
  axonServerUrl: "http://axon-server-api:8080"
  listener:
    host: "0.0.0.0"
    port: 3000

# Enable autoscaling
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  # Optional: target memory utilization
  # targetMemoryUtilizationPercentage: 80

# Resource limits (required for autoscaling)
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 512Mi

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: axonops.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: axon-dash-tls
      hosts:
        - axonops.example.com
```

Instale:

```bash
helm install axon-dash ./axon-dash -f values-autoscaling.yaml
```

Vigile el autoescalado:
```bash
# Check HPA status
kubectl get hpa

# Watch pod scaling
kubectl get pods -l app.kubernetes.io/name=axon-dash -w
```

### Instalación lista para producción

Una configuración de producción completa, con todos los ajustes recomendados:

```yaml
# values-production.yaml
# Production configuration for AxonOps Dashboard

# Multiple replicas for high availability
replicaCount: 3

# Image configuration
image:
  repository: registry.axonops.com/axonops-public/axonops-docker/axon-dash
  pullPolicy: IfNotPresent
  tag: ""  # Uses chart appVersion

# Dashboard configuration
config:
  # AxonOps Server API endpoint (internal service)
  axonServerUrl: "http://axon-server-api.production.svc.cluster.local:8080"

  # No context path (root)
  contextPath: ""

  # Listener configuration
  listener:
    host: "0.0.0.0"
    port: 3000
    ssl:
      enabled: false  # SSL handled by ingress

  # Additional configuration
  extraConfig:
    logging:
      level: info

# Service configuration
service:
  type: ClusterIP
  port: 3000

# Ingress configuration
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    # Security headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Frame-Options: SAMEORIGIN";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-XSS-Protection: 1; mode=block";
      more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";
  hosts:
    - host: axonops.production.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: axon-dash-production-tls
      hosts:
        - axonops.production.example.com

# Resource limits
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 512Mi

# Health check probes
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

# Autoscaling configuration
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Pod security context
podSecurityContext:
  fsGroup: 9988
  runAsNonRoot: true
  runAsUser: 9988

securityContext:
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: false
  runAsNonRoot: true
  runAsUser: 9988

# Pod disruption budget
podDisruptionBudget:
  minAvailable: 2

# Pod anti-affinity to spread across nodes
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - axon-dash
          topologyKey: kubernetes.io/hostname

# Node selection
nodeSelector:
  workload: web

# Tolerations
tolerations:
  - key: "workload"
    operator: "Equal"
    value: "web"
    effect: "NoSchedule"

# Pod annotations
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "3000"
  prometheus.io/path: "/metrics"

# Service account
serviceAccount:
  create: true
  automount: true
  annotations: {}
```

**Instale el despliegue de producción:**

```bash
helm install axon-dash ./axon-dash \
  -f values-production.yaml \
  --namespace production \
  --create-namespace
```

**Verifique el despliegue:**

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=axon-dash -n production

# Check service
kubectl get svc axon-dash -n production

# Check ingress
kubectl get ingress -n production

# Check HPA
kubectl get hpa -n production

# Test access
curl -I https://axonops.production.example.com
```

## Configuración

### Opciones de configuración principales

| Parámetro | Descripción | Valor por defecto |
|-----------|-------------|---------|
| `replicaCount` | Número de réplicas del panel | `1` |
| `config.axonServerUrl` | La URL de la API del servidor de AxonOps | `"http://axon-server:3000"` |
| `config.contextPath` | La subruta de la URL | `""` |
| `config.listener.host` | El host de escucha | `"0.0.0.0"` |
| `config.listener.port` | El puerto de escucha | `3000` |
| `config.listener.ssl.enabled` | Activa SSL en la aplicación | `false` |
| `service.type` | El tipo de servicio de Kubernetes | `"ClusterIP"` |
| `service.port` | El puerto del servicio | `3000` |
| `ingress.enabled` | Activa el ingress | `false` |
| `ingress.className` | El nombre de la clase de ingress | `""` |
| `autoscaling.enabled` | Activa el autoescalado horizontal de pods | `false` |
| `autoscaling.minReplicas` | Réplicas mínimas del HPA | `1` |
| `autoscaling.maxReplicas` | Réplicas máximas del HPA | `100` |
| `resources.requests.cpu` | Petición de CPU | `nil` |
| `resources.requests.memory` | Petición de memoria | `nil` |

### Notas importantes

**La URL del servidor de AxonOps:**
- Debe apuntar al endpoint de la API del servidor de AxonOps
- Use el nombre del servicio para un despliegue dentro del clúster: `http://axon-server-api:8080`
- Use el FQDN completo entre espacios de nombres: `http://axon-server-api.namespace.svc.cluster.local:8080`
- Use una URL externa si el servidor está fuera del clúster

**La subruta (context path):**
- Déjela vacía (`""`) para ejecutar en la raíz
- Póngala a `/ruta` para ejecutar bajo una subruta (por ejemplo, `https://example.com/axonops`)
- Requiere configurar la reescritura en el ingress

**Alta disponibilidad:**
- Ejecute al menos 2 réplicas en producción
- Active el autoescalado para escalar dinámicamente
- Use antiafinidad de pods para repartir entre nodos
- Configure pod disruption budgets

**Seguridad:**
- Use siempre HTTPS en producción (a través del ingress)
- Active las cabeceras de seguridad en las anotaciones del ingress
- Use una autenticación adecuada (se configura en el servidor de AxonOps)
- Restrinja el acceso de red con network policies

### Referencia completa de values

<details>
<summary>Pulse para desplegar la tabla completa de values</summary>

| Clave | Tipo | Valor por defecto | Descripción |
|-----|------|---------|-------------|
| affinity | object | `{}` | Reglas de afinidad de pod para la planificación |
| autoscaling.enabled | bool | `false` | Activa el autoescalado horizontal de pods |
| autoscaling.maxReplicas | int | `100` | Réplicas máximas del HPA |
| autoscaling.minReplicas | int | `1` | Réplicas mínimas del HPA |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Porcentaje objetivo de uso de CPU |
| config.axonServerUrl | string | `"http://axon-server:3000"` | El endpoint de la API del servidor de AxonOps |
| config.contextPath | string | `""` | La subruta de la URL de la aplicación |
| config.extraConfig | object | `{}` | Opciones de configuración adicionales |
| config.listener.host | string | `"0.0.0.0"` | El host de escucha |
| config.listener.port | int | `3000` | El puerto de escucha |
| config.listener.ssl.enabled | bool | `false` | Activa SSL en la aplicación |
| fullnameOverride | string | `""` | Sustituye el nombre completo del recurso |
| httpRoute.annotations | object | `{}` | Anotaciones del HTTPRoute |
| httpRoute.enabled | bool | `false` | Activa HTTPRoute (Gateway API) |
| httpRoute.hostnames | list | `["chart-example.local"]` | Nombres de host del HTTPRoute |
| httpRoute.parentRefs | list | `[{"name":"gateway","sectionName":"http"}]` | Referencias al gateway |
| httpRoute.rules | list | `[{"matches":[{"path":{"type":"PathPrefix","value":"/headers"}}]}]` | Reglas del HTTPRoute |
| image.pullPolicy | string | `"IfNotPresent"` | Política de descarga de la imagen |
| image.repository | string | `"registry.axonops.com/axonops-public/axonops-docker/axon-dash"` | El repositorio de la imagen de contenedor |
| image.tag | string | `""` | La etiqueta de la imagen (por defecto, la appVersion) |
| imagePullSecrets | list | `[]` | Secretos de descarga de imágenes para registros privados |
| ingress.annotations | object | `{}` | Anotaciones del ingress |
| ingress.className | string | `""` | El nombre de la clase de ingress |
| ingress.enabled | bool | `false` | Activa el ingress |
| ingress.hosts | list | `[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Configuración de hosts del ingress |
| ingress.tls | list | `[]` | Configuración de TLS del ingress |
| livenessProbe.httpGet.path | string | `"/"` | La ruta HTTP de la sonda de vida |
| livenessProbe.httpGet.port | string | `"http"` | El puerto HTTP de la sonda de vida |
| nameOverride | string | `""` | Sustituye el nombre del chart |
| nodeSelector | object | `{}` | Etiquetas de nodo para asignar los pods |
| podAnnotations | object | `{}` | Anotaciones de los pods |
| podLabels | object | `{}` | Etiquetas adicionales de los pods |
| podSecurityContext | object | `{}` | El contexto de seguridad del pod |
| readinessProbe.httpGet.path | string | `"/"` | La ruta HTTP de la sonda de disponibilidad |
| readinessProbe.httpGet.port | string | `"http"` | El puerto HTTP de la sonda de disponibilidad |
| replicaCount | int | `1` | Número de réplicas |
| resources | object | `{}` | Peticiones y límites de CPU y memoria |
| securityContext | object | `{}` | El contexto de seguridad del contenedor |
| service.port | int | `3000` | El puerto del servicio |
| service.type | string | `"ClusterIP"` | El tipo de servicio de Kubernetes |
| serviceAccount.annotations | object | `{}` | Anotaciones de la cuenta de servicio |
| serviceAccount.automount | bool | `true` | Monta automáticamente el token de la cuenta de servicio |
| serviceAccount.create | bool | `true` | Crea la cuenta de servicio |
| serviceAccount.name | string | `""` | El nombre de la cuenta de servicio |
| tolerations | list | `[]` | Toleraciones para asignar los pods |
| volumeMounts | list | `[]` | Montajes de volumen adicionales |
| volumes | list | `[]` | Volúmenes adicionales |

</details>

## Actualización

Para actualizar una instalación existente:

```bash
# Update the chart
helm upgrade axon-dash ./axon-dash -f values-production.yaml

# Check rollout status
kubectl rollout status deployment/axon-dash
```

**Notas importantes:**
- Las actualizaciones del panel suelen ser sin corte de servicio si hay varias réplicas
- Los pods antiguos sólo se terminan cuando los nuevos están listos
- Pruebe primero las actualizaciones fuera de producción
- Revise el changelog antes de actualizar

## Desinstalación

Para eliminar el panel de AxonOps:

```bash
# Uninstall the release
helm uninstall axon-dash

# Optional: Remove any remaining resources
kubectl delete ingress -l app.kubernetes.io/name=axon-dash
kubectl delete hpa -l app.kubernetes.io/name=axon-dash
```

**Nota:** el panel es sin estado, así que no se pierde ningún dato al
desinstalarlo.

## Resolución de problemas

### Problemas habituales

**1. El panel no conecta con el servidor de AxonOps**

Revise la configuración de la URL del servidor:
```bash
# Get the dashboard pod logs
kubectl logs -l app.kubernetes.io/name=axon-dash

# Check if server URL is correct
kubectl get deployment axon-dash -o yaml | grep -A 3 axonServerUrl
```

Causas habituales:
- Un valor incorrecto en `config.axonServerUrl`
- El servidor de AxonOps no está en marcha o no es accesible
- Una network policy que bloquea las conexiones
- Un nombre de servicio o de espacio de nombres equivocado

Pruebe la conectividad con el servidor:
```bash
# Exec into dashboard pod
kubectl exec -it deployment/axon-dash -- sh

# Test connection to server
curl http://axon-server-api:8080/api/v1/healthz
```

**2. No se puede acceder al panel desde fuera**

Verifique la configuración del ingress:
```bash
# Check ingress status
kubectl get ingress

# Describe ingress for details
kubectl describe ingress axon-dash

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

Causas habituales:
- El ingress no está activado (`ingress.enabled: false`)
- Un nombre de clase de ingress equivocado
- El DNS no apunta al controlador de ingress
- El certificado TLS no se ha emitido (revise cert-manager)

Pruebe el ingress:
```bash
# Get ingress address
kubectl get ingress axon-dash

# Test DNS resolution
nslookup axonops.example.com

# Test HTTP/HTTPS
curl -I https://axonops.example.com
```

**3. Los pods caen o no arrancan**

Revise el estado y los registros de los pods:
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=axon-dash

# View pod logs
kubectl logs -l app.kubernetes.io/name=axon-dash

# Describe pod for events
kubectl describe pod -l app.kubernetes.io/name=axon-dash
```

Causas habituales:
- Recursos insuficientes (suba `resources.limits`)
- Configuración inválida
- Errores al descargar la imagen (revise `imagePullSecrets`)
- Fallos de las sondas de salud

**4. La subruta (context path) no funciona**

Si el panel no funciona bajo una subruta:

```bash
# Check context path configuration
kubectl get deployment axon-dash -o yaml | grep contextPath

# Check ingress path configuration
kubectl get ingress axon-dash -o yaml
```

Asegúrese de que:
- `config.contextPath` coincide con la ruta del ingress
- El ingress tiene las anotaciones de reescritura correctas
- No hay barras finales en la configuración de la ruta

Ejemplo de configuración correcta:
```yaml
config:
  contextPath: "/axonops"

ingress:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
  hosts:
    - host: example.com
      paths:
        - path: /axonops(/|$)(.*)
          pathType: ImplementationSpecific
```

**5. Uso alto de memoria o de CPU**

Revise el uso de recursos:
```bash
kubectl top pods -l app.kubernetes.io/name=axon-dash
```

Si se mantiene alto:
- Suba los límites de recursos
- Active el autoescalado
- Busque fugas de memoria en los registros
- Compruebe que no hay bucles infinitos ni problemas de rendimiento

**6. El autoescalado no funciona**

Verifique el estado del HPA:
```bash
# Check HPA
kubectl get hpa

# Describe HPA
kubectl describe hpa axon-dash

# Check metrics server
kubectl top nodes
```

Causas habituales:
- El metrics server no está instalado
- No se han definido peticiones de recursos
- Los objetivos del HPA no son alcanzables
- Recursos de clúster insuficientes

**7. Problemas con los certificados TLS/SSL**

Para los problemas de certificados:
```bash
# Check certificate status
kubectl get certificate

# Describe certificate
kubectl describe certificate axon-dash-tls

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

Asegúrese de que:
- cert-manager está instalado y en marcha
- Existe el ClusterIssuer o Issuer
- El DNS está bien configurado
- El desafío ACME puede completarse

**8. Problemas de balanceo de carga con varias réplicas**

Si las peticiones no se reparten:
```bash
# Check service endpoints
kubectl get endpoints axon-dash

# Verify all pods are ready
kubectl get pods -l app.kubernetes.io/name=axon-dash

# Check service configuration
kubectl describe svc axon-dash
```

Asegúrese de que:
- Todos los pods pasan las sondas de disponibilidad
- El selector del servicio coincide con las etiquetas de los pods
- La afinidad de sesión está configurada si hace falta

### Obtener ayuda

Para soporte adicional:

- **Revise los registros:** `kubectl logs -l app.kubernetes.io/name=axon-dash`
- **Consulte los eventos:** `kubectl get events --sort-by='.lastTimestamp'`
- **Describa el despliegue:** `kubectl describe deployment axon-dash`
- **Pruébelo en local:**
  ```bash
  kubectl port-forward svc/axon-dash 3000:3000
  open http://localhost:3000
  ```
- **Documentación:** <https://docs.axonops.com>
- **Soporte:** <info@axonops.com>
- **Comunidad:** <https://community.axonops.com>

## Mantenedores

| Nombre | Correo | URL |
| ---- | ------ | --- |
| El equipo de AxonOps | <info@axonops.com> | <https://axonops.com> |

---

*Generado con los charts de Helm de AxonOps*
