# AxonOps Dashboard

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

A Helm chart for deploying the AxonOps Dashboard - the web-based user interface for the AxonOps observability platform. The dashboard provides a rich UI for monitoring Apache Cassandra clusters, viewing metrics, configuring alerts, and managing backups.

**Homepage:** <https://axonops.com>

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation Examples](#installation-examples)
  - [Basic Installation](#basic-installation)
  - [Installation with Ingress](#installation-with-ingress)
  - [Installation with TLS](#installation-with-tls)
  - [Installation with Subpath (Context Path)](#installation-with-subpath-context-path)
  - [Installation with Autoscaling](#installation-with-autoscaling)
  - [Production-Ready Installation](#production-ready-installation)
- [Configuration](#configuration)
- [Upgrading](#upgrading)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)

## Architecture Overview

The AxonOps Dashboard is the web UI component of the AxonOps platform:

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

## Prerequisites

Before you begin, ensure you have the following:

### Required Components

- **Kubernetes cluster**: Version 1.19 or higher
- **kubectl**: Configured to communicate with your cluster
- **Helm**: Version 3.0 or higher installed ([Installation guide](https://helm.sh/docs/intro/install/))
- **AxonOps Server**: Already deployed and accessible ([Installation guide](../axon-server/))

### Optional Components

- **Ingress Controller**: Required for external access (nginx, traefik, etc.)
- **cert-manager**: For automatic TLS certificate management
- **Gateway API Controller**: If using HTTPRoute instead of Ingress

### Verifying Your Setup

Check if the AxonOps Server is running:
```bash
kubectl get pods -l app.kubernetes.io/name=axon-server
```

Check if Helm is installed:
```bash
helm version
```

## Quick Start

The fastest way to get started with the AxonOps Dashboard:

```bash
# Install with default settings (connects to local axon-server)
helm install axon-dash ./axon-dash \
  --set config.axonServerUrl="http://axon-server-api:8080"

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axon-dash
```

This will deploy the AxonOps Dashboard with:
- Single replica
- ClusterIP service (internal access only)
- Connection to local AxonOps Server
- Port 3000

**To access the dashboard locally:**
```bash
kubectl port-forward svc/axon-dash 3000:3000
```

Then open your browser to: http://localhost:3000

## Installation Examples

### Basic Installation

Install with minimal configuration suitable for development/testing:

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

Install:

```bash
helm install axon-dash ./axon-dash -f values-basic.yaml
```

Access the dashboard:
```bash
# Port forward to access locally
kubectl port-forward svc/axon-dash 3000:3000

# Open browser to http://localhost:3000
```

### Installation with Ingress

Expose the dashboard externally using Ingress:

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

Install:

```bash
helm install axon-dash ./axon-dash -f values-ingress.yaml
```

Access the dashboard:
```bash
# Wait for certificate to be issued
kubectl get certificate

# Access via browser
open https://axonops.example.com
```

### Installation with TLS

Configure TLS/SSL for the dashboard application itself:

**Step 1: Create TLS secret**

```bash
kubectl create secret generic axon-dash-ssl \
  --from-file=cert.pem=path/to/cert.pem \
  --from-file=key.pem=path/to/key.pem
```

**Step 2: Create values file**

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

Install:

```bash
helm install axon-dash ./axon-dash -f values-tls.yaml
```

### Installation with Subpath (Context Path)

Run the dashboard under a URL subpath (e.g., `/axonops`):

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

Install:

```bash
helm install axon-dash ./axon-dash -f values-subpath.yaml
```

Access at: https://example.com/axonops

### Installation with Autoscaling

Enable horizontal pod autoscaling for high availability:

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

Install:

```bash
helm install axon-dash ./axon-dash -f values-autoscaling.yaml
```

Monitor autoscaling:
```bash
# Check HPA status
kubectl get hpa

# Watch pod scaling
kubectl get pods -l app.kubernetes.io/name=axon-dash -w
```

### Production-Ready Installation

A complete production configuration with all recommended settings:

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

**Install the production deployment:**

```bash
helm install axon-dash ./axon-dash \
  -f values-production.yaml \
  --namespace production \
  --create-namespace
```

**Verify the deployment:**

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

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of dashboard replicas | `1` |
| `config.axonServerUrl` | AxonOps Server API URL | `"http://axon-server:3000"` |
| `config.contextPath` | URL context path (subpath) | `""` |
| `config.listener.host` | Listener host | `"0.0.0.0"` |
| `config.listener.port` | Listener port | `3000` |
| `config.listener.ssl.enabled` | Enable SSL for application | `false` |
| `service.type` | Kubernetes service type | `"ClusterIP"` |
| `service.port` | Service port | `3000` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `autoscaling.enabled` | Enable horizontal pod autoscaling | `false` |
| `autoscaling.minReplicas` | Minimum replicas for HPA | `1` |
| `autoscaling.maxReplicas` | Maximum replicas for HPA | `100` |
| `resources.requests.cpu` | CPU request | `nil` |
| `resources.requests.memory` | Memory request | `nil` |

### Important Notes

**AxonOps Server URL:**
- Must point to the AxonOps Server API endpoint
- Use service name for in-cluster deployment: `http://axon-server-api:8080`
- Use full FQDN for cross-namespace: `http://axon-server-api.namespace.svc.cluster.local:8080`
- Use external URL if server is outside cluster

**Context Path:**
- Leave empty (`""`) to run at root path
- Set to `/path` to run under a subpath (e.g., `https://example.com/axonops`)
- Requires ingress rewrite configuration

**High Availability:**
- Run at least 2 replicas in production
- Enable autoscaling for dynamic scaling
- Use pod anti-affinity to spread across nodes
- Configure pod disruption budgets

**Security:**
- Always use HTTPS in production (via ingress)
- Enable security headers in ingress annotations
- Use proper authentication (configured in AxonOps Server)
- Restrict network access with network policies

### Complete Values Reference

<details>
<summary>Click to expand full values table</summary>

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Pod affinity rules for scheduling |
| autoscaling.enabled | bool | `false` | Enable horizontal pod autoscaling |
| autoscaling.maxReplicas | int | `100` | Maximum replicas for HPA |
| autoscaling.minReplicas | int | `1` | Minimum replicas for HPA |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization percentage |
| config.axonServerUrl | string | `"http://axon-server:3000"` | AxonOps Server API endpoint |
| config.contextPath | string | `""` | URL context path for the application |
| config.extraConfig | object | `{}` | Additional configuration options |
| config.listener.host | string | `"0.0.0.0"` | Listener host |
| config.listener.port | int | `3000` | Listener port |
| config.listener.ssl.enabled | bool | `false` | Enable SSL for the application |
| fullnameOverride | string | `""` | Override the full resource name |
| httpRoute.annotations | object | `{}` | Annotations for HTTPRoute |
| httpRoute.enabled | bool | `false` | Enable HTTPRoute (Gateway API) |
| httpRoute.hostnames | list | `["chart-example.local"]` | Hostnames for HTTPRoute |
| httpRoute.parentRefs | list | `[{"name":"gateway","sectionName":"http"}]` | Gateway references |
| httpRoute.rules | list | `[{"matches":[{"path":{"type":"PathPrefix","value":"/headers"}}]}]` | HTTPRoute rules |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"registry.axonops.com/axonops-public/axonops-docker/axon-dash"` | Container image repository |
| image.tag | string | `""` | Image tag (defaults to appVersion) |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| ingress.annotations | object | `{}` | Annotations for ingress |
| ingress.className | string | `""` | Ingress class name |
| ingress.enabled | bool | `false` | Enable ingress |
| ingress.hosts | list | `[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Ingress hosts configuration |
| ingress.tls | list | `[]` | TLS configuration for ingress |
| livenessProbe.httpGet.path | string | `"/"` | Liveness probe HTTP path |
| livenessProbe.httpGet.port | string | `"http"` | Liveness probe HTTP port |
| nameOverride | string | `""` | Override the chart name |
| nodeSelector | object | `{}` | Node labels for pod assignment |
| podAnnotations | object | `{}` | Annotations for pods |
| podLabels | object | `{}` | Additional labels for pods |
| podSecurityContext | object | `{}` | Pod security context |
| readinessProbe.httpGet.path | string | `"/"` | Readiness probe HTTP path |
| readinessProbe.httpGet.port | string | `"http"` | Readiness probe HTTP port |
| replicaCount | int | `1` | Number of replicas |
| resources | object | `{}` | CPU/Memory resource requests and limits |
| securityContext | object | `{}` | Container security context |
| service.port | int | `3000` | Service port |
| service.type | string | `"ClusterIP"` | Kubernetes service type |
| serviceAccount.annotations | object | `{}` | Annotations for service account |
| serviceAccount.automount | bool | `true` | Automount service account token |
| serviceAccount.create | bool | `true` | Create service account |
| serviceAccount.name | string | `""` | Service account name |
| tolerations | list | `[]` | Tolerations for pod assignment |
| volumeMounts | list | `[]` | Additional volume mounts |
| volumes | list | `[]` | Additional volumes |

</details>

## Upgrading

To upgrade an existing installation:

```bash
# Update the chart
helm upgrade axon-dash ./axon-dash -f values-production.yaml

# Check rollout status
kubectl rollout status deployment/axon-dash
```

**Important Notes:**
- Dashboard upgrades typically have zero downtime with multiple replicas
- Old pods are terminated only after new pods are ready
- Test upgrades in a non-production environment first
- Review the changelog before upgrading

## Uninstalling

To remove the AxonOps Dashboard:

```bash
# Uninstall the release
helm uninstall axon-dash

# Optional: Remove any remaining resources
kubectl delete ingress -l app.kubernetes.io/name=axon-dash
kubectl delete hpa -l app.kubernetes.io/name=axon-dash
```

**Note:** The dashboard is stateless, so no data is lost when uninstalling.

## Troubleshooting

### Common Issues

**1. Dashboard not connecting to AxonOps Server**

Check the server URL configuration:
```bash
# Get the dashboard pod logs
kubectl logs -l app.kubernetes.io/name=axon-dash

# Check if server URL is correct
kubectl get deployment axon-dash -o yaml | grep -A 3 axonServerUrl
```

Common causes:
- Incorrect `config.axonServerUrl` value
- AxonOps Server not running or not accessible
- Network policy blocking connections
- Wrong service name or namespace

Test server connectivity:
```bash
# Exec into dashboard pod
kubectl exec -it deployment/axon-dash -- sh

# Test connection to server
curl http://axon-server-api:8080/api/v1/healthz
```

**2. Cannot access dashboard externally**

Verify ingress configuration:
```bash
# Check ingress status
kubectl get ingress

# Describe ingress for details
kubectl describe ingress axon-dash

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

Common causes:
- Ingress not enabled (`ingress.enabled: false`)
- Wrong ingress class name
- DNS not pointing to ingress controller
- TLS certificate not issued (check cert-manager)

Test ingress:
```bash
# Get ingress address
kubectl get ingress axon-dash

# Test DNS resolution
nslookup axonops.example.com

# Test HTTP/HTTPS
curl -I https://axonops.example.com
```

**3. Pods crashing or failing to start**

Check pod status and logs:
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=axon-dash

# View pod logs
kubectl logs -l app.kubernetes.io/name=axon-dash

# Describe pod for events
kubectl describe pod -l app.kubernetes.io/name=axon-dash
```

Common causes:
- Insufficient resources (increase `resources.limits`)
- Invalid configuration
- Image pull errors (check `imagePullSecrets`)
- Health probe failures

**4. Context path / subpath not working**

If dashboard doesn't work under a subpath:

```bash
# Check context path configuration
kubectl get deployment axon-dash -o yaml | grep contextPath

# Check ingress path configuration
kubectl get ingress axon-dash -o yaml
```

Ensure:
- `config.contextPath` matches ingress path
- Ingress has correct rewrite annotations
- No trailing slashes in path configuration

Example correct configuration:
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

**5. High memory or CPU usage**

Check resource usage:
```bash
kubectl top pods -l app.kubernetes.io/name=axon-dash
```

If consistently high:
- Increase resource limits
- Enable autoscaling
- Check for memory leaks in logs
- Verify no infinite loops or performance issues

**6. Autoscaling not working**

Verify HPA status:
```bash
# Check HPA
kubectl get hpa

# Describe HPA
kubectl describe hpa axon-dash

# Check metrics server
kubectl top nodes
```

Common causes:
- Metrics server not installed
- Resource requests not set
- HPA targets unreachable
- Insufficient cluster resources

**7. TLS/SSL certificate issues**

For certificate problems:
```bash
# Check certificate status
kubectl get certificate

# Describe certificate
kubectl describe certificate axon-dash-tls

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

Ensure:
- cert-manager is installed and running
- ClusterIssuer/Issuer exists
- DNS is properly configured
- ACME challenge can complete

**8. Load balancing issues with multiple replicas**

If requests aren't distributed:
```bash
# Check service endpoints
kubectl get endpoints axon-dash

# Verify all pods are ready
kubectl get pods -l app.kubernetes.io/name=axon-dash

# Check service configuration
kubectl describe svc axon-dash
```

Ensure:
- All pods pass readiness probes
- Service selector matches pod labels
- Session affinity configured if needed

### Getting Help

For additional support:

- **Check logs:** `kubectl logs -l app.kubernetes.io/name=axon-dash`
- **View events:** `kubectl get events --sort-by='.lastTimestamp'`
- **Describe deployment:** `kubectl describe deployment axon-dash`
- **Test locally:**
  ```bash
  kubectl port-forward svc/axon-dash 3000:3000
  open http://localhost:3000
  ```
- **Documentation:** <https://docs.axonops.com>
- **Support:** <info@axonops.com>
- **Community:** <https://community.axonops.com>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| AxonOps Team | <info@axonops.com> | <https://axonops.com> |

---

*Generated with AxonOps Helm Charts*
