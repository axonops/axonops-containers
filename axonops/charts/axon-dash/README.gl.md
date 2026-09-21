# Panel de AxonOps

[English](README.md) | [Français](README.fr.md) | [Español](README.es.md) | **Galego**

![Versión: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Tipo: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

Un chart de Helm para despregar o panel de AxonOps, a interface web da plataforma
de observabilidade de AxonOps. O panel ofrece unha interface rica para monitorizar
clústeres de Apache Cassandra, consultar métricas, configurar alertas e xestionar
copias de seguranza.

**Páxina do proxecto:** <https://axonops.com>

## Índice

- [Visión xeral da arquitectura](#visión-xeral-da-arquitectura)
- [Requisitos previos](#requisitos-previos)
- [Inicio rápido](#inicio-rápido)
- [Exemplos de instalación](#exemplos-de-instalación)
  - [Instalación básica](#instalación-básica)
  - [Instalación con Ingress](#instalación-con-ingress)
  - [Instalación con TLS](#instalación-con-tls)
  - [Instalación con subruta (context path)](#instalación-con-subruta-context-path)
  - [Instalación con autoescalado](#instalación-con-autoescalado)
  - [Instalación lista para produción](#instalación-lista-para-produción)
- [Configuración](#configuración)
- [Actualización](#actualización)
- [Desinstalación](#desinstalación)
- [Resolución de problemas](#resolución-de-problemas)

## Visión xeral da arquitectura

O panel de AxonOps é o compoñente de interface web da plataforma AxonOps:

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

Antes de comezar, asegúrese de ter o seguinte:

### Compoñentes obrigatorios

- **Un clúster de Kubernetes**: versión 1.19 ou superior
- **kubectl**: configurado para comunicarse co seu clúster
- **Helm**: versión 3.0 ou superior instalada ([guía de instalación](https://helm.sh/docs/intro/install/))
- **O servidor de AxonOps**: xa despregado e accesible ([guía de instalación](../axon-server/))

### Compoñentes opcionais

- **Un controlador de Ingress**: necesario para o acceso externo (nginx, traefik, etc.)
- **cert-manager**: para a xestión automática de certificados TLS
- **Un controlador da Gateway API**: se usa HTTPRoute no canto de Ingress

### Verificar a súa instalación

Comprobe que o servidor de AxonOps está en marcha:
```bash
kubectl get pods -l app.kubernetes.io/name=axon-server
```

Comprobe que Helm está instalado:
```bash
helm version
```

## Inicio rápido

A forma máis rápida de comezar co panel de AxonOps:

```bash
# Install with default settings (connects to local axon-server)
helm install axon-dash ./axon-dash \
  --set config.axonServerUrl="http://axon-server-api:8080"

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axon-dash
```

Isto desprega o panel de AxonOps con:
- Unha soa réplica
- Un servizo ClusterIP (só acceso interno)
- Conexión ao servidor de AxonOps local
- O porto 3000

**Para acceder ao panel en local:**
```bash
kubectl port-forward svc/axon-dash 3000:3000
```

Despois abra o navegador en http://localhost:3000

## Exemplos de instalación

### Instalación básica

Instalación coa configuración mínima, apta para desenvolvemento e probas:

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

Acceda ao panel:
```bash
# Port forward to access locally
kubectl port-forward svc/axon-dash 3000:3000

# Open browser to http://localhost:3000
```

### Instalación con Ingress

Expoña o panel ao exterior cun Ingress:

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

Acceda ao panel:
```bash
# Wait for certificate to be issued
kubectl get certificate

# Access via browser
open https://axonops.example.com
```

### Instalación con TLS

Configure TLS/SSL na propia aplicación do panel:

**Paso 1: crear o segredo TLS**

```bash
kubectl create secret generic axon-dash-ssl \
  --from-file=cert.pem=path/to/cert.pem \
  --from-file=key.pem=path/to/key.pem
```

**Paso 2: crear o ficheiro de values**

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

Execute o panel baixo unha subruta da URL (por exemplo, `/axonops`):

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

Active o autoescalado horizontal de pods para alta dispoñibilidade:

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

Vixíe o autoescalado:
```bash
# Check HPA status
kubectl get hpa

# Watch pod scaling
kubectl get pods -l app.kubernetes.io/name=axon-dash -w
```

### Instalación lista para produción

Unha configuración de produción completa, con todos os axustes recomendados:

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

**Instale o despregamento de produción:**

```bash
helm install axon-dash ./axon-dash \
  -f values-production.yaml \
  --namespace production \
  --create-namespace
```

**Verifique o despregamento:**

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

### Opcións de configuración principais

| Parámetro | Descrición | Valor por defecto |
|-----------|-------------|---------|
| `replicaCount` | Número de réplicas do panel | `1` |
| `config.axonServerUrl` | A URL da API do servidor de AxonOps | `"http://axon-server:3000"` |
| `config.contextPath` | A subruta da URL | `""` |
| `config.listener.host` | O host de escoita | `"0.0.0.0"` |
| `config.listener.port` | O porto de escoita | `3000` |
| `config.listener.ssl.enabled` | Activa SSL na aplicación | `false` |
| `service.type` | O tipo de servizo de Kubernetes | `"ClusterIP"` |
| `service.port` | O porto do servizo | `3000` |
| `ingress.enabled` | Activa o ingress | `false` |
| `ingress.className` | O nome da clase de ingress | `""` |
| `autoscaling.enabled` | Activa o autoescalado horizontal de pods | `false` |
| `autoscaling.minReplicas` | Réplicas mínimas do HPA | `1` |
| `autoscaling.maxReplicas` | Réplicas máximas do HPA | `100` |
| `resources.requests.cpu` | Petición de CPU | `nil` |
| `resources.requests.memory` | Petición de memoria | `nil` |

### Notas importantes

**A URL do servidor de AxonOps:**
- Debe apuntar ao endpoint da API do servidor de AxonOps
- Use o nome do servizo para un despregamento dentro do clúster: `http://axon-server-api:8080`
- Use o FQDN completo entre espazos de nomes: `http://axon-server-api.namespace.svc.cluster.local:8080`
- Use unha URL externa se o servidor está fóra do clúster

**A subruta (context path):**
- Déixea baleira (`""`) para executar na raíz
- Póñaa a `/ruta` para executar baixo unha subruta (por exemplo, `https://example.com/axonops`)
- Require configurar a reescritura no ingress

**Alta dispoñibilidade:**
- Execute polo menos 2 réplicas en produción
- Active o autoescalado para escalar dinamicamente
- Use antiafinidade de pods para repartir entre nodos
- Configure pod disruption budgets

**Seguridade:**
- Use sempre HTTPS en produción (a través do ingress)
- Active as cabeceiras de seguridade nas anotacións do ingress
- Use unha autenticación axeitada (configúrase no servidor de AxonOps)
- Restrinxa o acceso de rede con network policies

### Referencia completa de values

<details>
<summary>Prema para despregar a táboa completa de values</summary>

| Chave | Tipo | Valor por defecto | Descrición |
|-----|------|---------|-------------|
| affinity | object | `{}` | Regras de afinidade de pod para a planificación |
| autoscaling.enabled | bool | `false` | Activa o autoescalado horizontal de pods |
| autoscaling.maxReplicas | int | `100` | Réplicas máximas do HPA |
| autoscaling.minReplicas | int | `1` | Réplicas mínimas do HPA |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Porcentaxe obxectivo de uso de CPU |
| config.axonServerUrl | string | `"http://axon-server:3000"` | O endpoint da API do servidor de AxonOps |
| config.contextPath | string | `""` | A subruta da URL da aplicación |
| config.extraConfig | object | `{}` | Opcións de configuración adicionais |
| config.listener.host | string | `"0.0.0.0"` | O host de escoita |
| config.listener.port | int | `3000` | O porto de escoita |
| config.listener.ssl.enabled | bool | `false` | Activa SSL na aplicación |
| fullnameOverride | string | `""` | Substitúe o nome completo do recurso |
| httpRoute.annotations | object | `{}` | Anotacións do HTTPRoute |
| httpRoute.enabled | bool | `false` | Activa HTTPRoute (Gateway API) |
| httpRoute.hostnames | list | `["chart-example.local"]` | Nomes de host do HTTPRoute |
| httpRoute.parentRefs | list | `[{"name":"gateway","sectionName":"http"}]` | Referencias ao gateway |
| httpRoute.rules | list | `[{"matches":[{"path":{"type":"PathPrefix","value":"/headers"}}]}]` | Regras do HTTPRoute |
| image.pullPolicy | string | `"IfNotPresent"` | Política de descarga da imaxe |
| image.repository | string | `"registry.axonops.com/axonops-public/axonops-docker/axon-dash"` | O repositorio da imaxe de contedor |
| image.tag | string | `""` | A etiqueta da imaxe (por defecto, a appVersion) |
| imagePullSecrets | list | `[]` | Segredos de descarga de imaxes para rexistros privados |
| ingress.annotations | object | `{}` | Anotacións do ingress |
| ingress.className | string | `""` | O nome da clase de ingress |
| ingress.enabled | bool | `false` | Activa o ingress |
| ingress.hosts | list | `[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Configuración de hosts do ingress |
| ingress.tls | list | `[]` | Configuración de TLS do ingress |
| livenessProbe.httpGet.path | string | `"/"` | A ruta HTTP da sonda de vida |
| livenessProbe.httpGet.port | string | `"http"` | O porto HTTP da sonda de vida |
| nameOverride | string | `""` | Substitúe o nome do chart |
| nodeSelector | object | `{}` | Etiquetas de nodo para asignar os pods |
| podAnnotations | object | `{}` | Anotacións dos pods |
| podLabels | object | `{}` | Etiquetas adicionais dos pods |
| podSecurityContext | object | `{}` | O contexto de seguridade do pod |
| readinessProbe.httpGet.path | string | `"/"` | A ruta HTTP da sonda de dispoñibilidade |
| readinessProbe.httpGet.port | string | `"http"` | O porto HTTP da sonda de dispoñibilidade |
| replicaCount | int | `1` | Número de réplicas |
| resources | object | `{}` | Peticións e límites de CPU e memoria |
| securityContext | object | `{}` | O contexto de seguridade do contedor |
| service.port | int | `3000` | O porto do servizo |
| service.type | string | `"ClusterIP"` | O tipo de servizo de Kubernetes |
| serviceAccount.annotations | object | `{}` | Anotacións da conta de servizo |
| serviceAccount.automount | bool | `true` | Monta automaticamente o token da conta de servizo |
| serviceAccount.create | bool | `true` | Crea a conta de servizo |
| serviceAccount.name | string | `""` | O nome da conta de servizo |
| tolerations | list | `[]` | Tolerancias para asignar os pods |
| volumeMounts | list | `[]` | Montaxes de volume adicionais |
| volumes | list | `[]` | Volumes adicionais |

</details>

## Actualización

Para actualizar unha instalación existente:

```bash
# Update the chart
helm upgrade axon-dash ./axon-dash -f values-production.yaml

# Check rollout status
kubectl rollout status deployment/axon-dash
```

**Notas importantes:**
- As actualizacións do panel adoitan ser sen corte de servizo se hai varias réplicas
- Os pods antigos só se terminan cando os novos están listos
- Probe primeiro as actualizacións fóra de produción
- Revise o changelog antes de actualizar

## Desinstalación

Para eliminar o panel de AxonOps:

```bash
# Uninstall the release
helm uninstall axon-dash

# Optional: Remove any remaining resources
kubectl delete ingress -l app.kubernetes.io/name=axon-dash
kubectl delete hpa -l app.kubernetes.io/name=axon-dash
```

**Nota:** o panel é sen estado, así que non se perde ningún dato ao desinstalalo.

## Resolución de problemas

### Problemas habituais

**1. O panel non conecta co servidor de AxonOps**

Revise a configuración da URL do servidor:
```bash
# Get the dashboard pod logs
kubectl logs -l app.kubernetes.io/name=axon-dash

# Check if server URL is correct
kubectl get deployment axon-dash -o yaml | grep -A 3 axonServerUrl
```

Causas habituais:
- Un valor incorrecto en `config.axonServerUrl`
- O servidor de AxonOps non está en marcha ou non é accesible
- Unha network policy que bloquea as conexións
- Un nome de servizo ou de espazo de nomes equivocado

Probe a conectividade co servidor:
```bash
# Exec into dashboard pod
kubectl exec -it deployment/axon-dash -- sh

# Test connection to server
curl http://axon-server-api:8080/api/v1/healthz
```

**2. Non se pode acceder ao panel dende fóra**

Verifique a configuración do ingress:
```bash
# Check ingress status
kubectl get ingress

# Describe ingress for details
kubectl describe ingress axon-dash

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

Causas habituais:
- O ingress non está activado (`ingress.enabled: false`)
- Un nome de clase de ingress equivocado
- O DNS non apunta ao controlador de ingress
- O certificado TLS non se emitiu (revise cert-manager)

Probe o ingress:
```bash
# Get ingress address
kubectl get ingress axon-dash

# Test DNS resolution
nslookup axonops.example.com

# Test HTTP/HTTPS
curl -I https://axonops.example.com
```

**3. Os pods caen ou non arrancan**

Revise o estado e os rexistros dos pods:
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=axon-dash

# View pod logs
kubectl logs -l app.kubernetes.io/name=axon-dash

# Describe pod for events
kubectl describe pod -l app.kubernetes.io/name=axon-dash
```

Causas habituais:
- Recursos insuficientes (suba `resources.limits`)
- Configuración inválida
- Erros ao descargar a imaxe (revise `imagePullSecrets`)
- Fallos das sondas de saúde

**4. A subruta (context path) non funciona**

Se o panel non funciona baixo unha subruta:

```bash
# Check context path configuration
kubectl get deployment axon-dash -o yaml | grep contextPath

# Check ingress path configuration
kubectl get ingress axon-dash -o yaml
```

Asegúrese de que:
- `config.contextPath` coincide coa ruta do ingress
- O ingress ten as anotacións de reescritura correctas
- Non hai barras finais na configuración da ruta

Exemplo de configuración correcta:
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

**5. Uso alto de memoria ou de CPU**

Revise o uso de recursos:
```bash
kubectl top pods -l app.kubernetes.io/name=axon-dash
```

Se se mantén alto:
- Suba os límites de recursos
- Active o autoescalado
- Busque fugas de memoria nos rexistros
- Comprobe que non hai bucles infinitos nin problemas de rendemento

**6. O autoescalado non funciona**

Verifique o estado do HPA:
```bash
# Check HPA
kubectl get hpa

# Describe HPA
kubectl describe hpa axon-dash

# Check metrics server
kubectl top nodes
```

Causas habituais:
- O metrics server non está instalado
- Non se definiron peticións de recursos
- Os obxectivos do HPA non son alcanzables
- Recursos de clúster insuficientes

**7. Problemas cos certificados TLS/SSL**

Para os problemas de certificados:
```bash
# Check certificate status
kubectl get certificate

# Describe certificate
kubectl describe certificate axon-dash-tls

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

Asegúrese de que:
- cert-manager está instalado e en marcha
- Existe o ClusterIssuer ou Issuer
- O DNS está ben configurado
- O desafío ACME pode completarse

**8. Problemas de balanceo de carga con varias réplicas**

Se as peticións non se reparten:
```bash
# Check service endpoints
kubectl get endpoints axon-dash

# Verify all pods are ready
kubectl get pods -l app.kubernetes.io/name=axon-dash

# Check service configuration
kubectl describe svc axon-dash
```

Asegúrese de que:
- Todos os pods pasan as sondas de dispoñibilidade
- O selector do servizo coincide coas etiquetas dos pods
- A afinidade de sesión está configurada se fai falta

### Obter axuda

Para soporte adicional:

- **Revise os rexistros:** `kubectl logs -l app.kubernetes.io/name=axon-dash`
- **Consulte os eventos:** `kubectl get events --sort-by='.lastTimestamp'`
- **Describa o despregamento:** `kubectl describe deployment axon-dash`
- **Próbeo en local:**
  ```bash
  kubectl port-forward svc/axon-dash 3000:3000
  open http://localhost:3000
  ```
- **Documentación:** <https://docs.axonops.com>
- **Soporte:** <info@axonops.com>
- **Comunidade:** <https://community.axonops.com>

## Mantedores

| Nome | Correo | URL |
| ---- | ------ | --- |
| O equipo de AxonOps | <info@axonops.com> | <https://axonops.com> |

---

*Xerado cos charts de Helm de AxonOps*
