# Dashboard AxonOps

[English](README.md) | **Français**

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: latest](https://img.shields.io/badge/AppVersion-latest-informational?style=flat-square)

Un chart Helm pour déployer le dashboard AxonOps — l'interface web de la plateforme d'observabilité AxonOps. Le dashboard offre une interface riche pour superviser les clusters Apache Cassandra, consulter les métriques, configurer les alertes et gérer les sauvegardes.

**Site web :** <https://axonops.com>

## Table des matières

- [Vue d'ensemble de l'architecture](#vue-densemble-de-larchitecture)
- [Prérequis](#prérequis)
- [Démarrage rapide](#démarrage-rapide)
- [Exemples d'installation](#exemples-dinstallation)
  - [Installation de base](#installation-de-base)
  - [Installation avec Ingress](#installation-avec-ingress)
  - [Installation avec TLS](#installation-avec-tls)
  - [Installation sous un sous-chemin (context path)](#installation-sous-un-sous-chemin-context-path)
  - [Installation avec autoscaling](#installation-avec-autoscaling)
  - [Installation prête pour la production](#installation-prête-pour-la-production)
- [Configuration](#configuration)
- [Mise à jour](#mise-à-jour)
- [Désinstallation](#désinstallation)
- [Dépannage](#dépannage)

## Vue d'ensemble de l'architecture

Le dashboard AxonOps est le composant d'interface web de la plateforme AxonOps :

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

## Prérequis

Avant de commencer, assurez-vous de disposer de ce qui suit :

### Composants obligatoires

- **Un cluster Kubernetes** : version 1.19 ou ultérieure
- **kubectl** : configuré pour dialoguer avec votre cluster
- **Helm** : version 3.0 ou ultérieure ([guide d'installation](https://helm.sh/docs/intro/install/))
- **AxonOps Server** : déjà déployé et accessible ([guide d'installation](../axon-server/))

### Composants optionnels

- **Un contrôleur Ingress** : nécessaire pour un accès externe (nginx, traefik, etc.)
- **cert-manager** : pour la gestion automatique des certificats TLS
- **Un contrôleur Gateway API** : si vous utilisez HTTPRoute plutôt qu'Ingress

### Vérifier votre installation

Vérifiez qu'AxonOps Server tourne :
```bash
kubectl get pods -l app.kubernetes.io/name=axon-server
```

Vérifiez que Helm est installé :
```bash
helm version
```

## Démarrage rapide

Le moyen le plus rapide de démarrer avec le dashboard AxonOps :

```bash
# Install with default settings (connects to local axon-server)
helm install axon-dash ./axon-dash \
  --set config.axonServerUrl="http://axon-server-api:8080"

# Check the deployment status
kubectl get pods -l app.kubernetes.io/name=axon-dash
```

Cela déploie le dashboard AxonOps avec :
- un seul réplica
- un service ClusterIP (accès interne uniquement)
- une connexion à l'AxonOps Server local
- le port 3000

**Pour accéder au dashboard en local :**
```bash
kubectl port-forward svc/axon-dash 3000:3000
```

Puis ouvrez votre navigateur sur : http://localhost:3000

## Exemples d'installation

### Installation de base

Installation minimale, adaptée au développement et aux tests :

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

Installation :

```bash
helm install axon-dash ./axon-dash -f values-basic.yaml
```

Accéder au dashboard :
```bash
# Port forward to access locally
kubectl port-forward svc/axon-dash 3000:3000

# Open browser to http://localhost:3000
```

### Installation avec Ingress

Exposer le dashboard vers l'extérieur via un Ingress :

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

Installation :

```bash
helm install axon-dash ./axon-dash -f values-ingress.yaml
```

Accéder au dashboard :
```bash
# Wait for certificate to be issued
kubectl get certificate

# Access via browser
open https://axonops.example.com
```

### Installation avec TLS

Configurer TLS/SSL sur l'application dashboard elle-même :

**Étape 1 : créer le secret TLS**

```bash
kubectl create secret generic axon-dash-ssl \
  --from-file=cert.pem=path/to/cert.pem \
  --from-file=key.pem=path/to/key.pem
```

**Étape 2 : créer le fichier de values**

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

Installation :

```bash
helm install axon-dash ./axon-dash -f values-tls.yaml
```

### Installation sous un sous-chemin (context path)

Faire tourner le dashboard sous un sous-chemin d'URL (par exemple `/axonops`) :

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

Installation :

```bash
helm install axon-dash ./axon-dash -f values-subpath.yaml
```

Accès à l'adresse : https://example.com/axonops

### Installation avec autoscaling

Activer l'autoscaling horizontal des pods, pour la haute disponibilité :

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

Installation :

```bash
helm install axon-dash ./axon-dash -f values-autoscaling.yaml
```

Suivre l'autoscaling :
```bash
# Check HPA status
kubectl get hpa

# Watch pod scaling
kubectl get pods -l app.kubernetes.io/name=axon-dash -w
```

### Installation prête pour la production

Une configuration de production complète, avec tous les réglages recommandés :

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

**Installer le déploiement de production :**

```bash
helm install axon-dash ./axon-dash \
  -f values-production.yaml \
  --namespace production \
  --create-namespace
```

**Vérifier le déploiement :**

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

### Principales options de configuration

| Paramètre | Description | Défaut |
|-----------|-------------|---------|
| `replicaCount` | Nombre de réplicas du dashboard | `1` |
| `config.axonServerUrl` | URL de l'API AxonOps Server | `"http://axon-server:3000"` |
| `config.contextPath` | Sous-chemin d'URL (context path) | `""` |
| `config.listener.host` | Hôte d'écoute | `"0.0.0.0"` |
| `config.listener.port` | Port d'écoute | `3000` |
| `config.listener.ssl.enabled` | Activer SSL sur l'application | `false` |
| `service.type` | Type de service Kubernetes | `"ClusterIP"` |
| `service.port` | Port du service | `3000` |
| `ingress.enabled` | Activer l'ingress | `false` |
| `ingress.className` | Nom de la classe d'ingress | `""` |
| `autoscaling.enabled` | Activer l'autoscaling horizontal des pods | `false` |
| `autoscaling.minReplicas` | Nombre minimal de réplicas du HPA | `1` |
| `autoscaling.maxReplicas` | Nombre maximal de réplicas du HPA | `100` |
| `resources.requests.cpu` | Requête CPU | `nil` |
| `resources.requests.memory` | Requête mémoire | `nil` |

### Points importants

**URL d'AxonOps Server :**
- doit pointer vers l'endpoint de l'API AxonOps Server
- utilisez le nom du service pour un déploiement dans le cluster : `http://axon-server-api:8080`
- utilisez le FQDN complet pour un accès inter-namespaces : `http://axon-server-api.namespace.svc.cluster.local:8080`
- utilisez une URL externe si le serveur est hors du cluster

**Context path :**
- laissez vide (`""`) pour servir à la racine
- mettez `/chemin` pour servir sous un sous-chemin (par exemple `https://example.com/axonops`)
- exige une configuration de réécriture dans l'ingress

**Haute disponibilité :**
- exécutez au moins 2 réplicas en production
- activez l'autoscaling pour une mise à l'échelle dynamique
- utilisez l'anti-affinité de pods pour répartir entre nœuds
- configurez des pod disruption budgets

**Sécurité :**
- utilisez toujours HTTPS en production (via l'ingress)
- activez les en-têtes de sécurité dans les annotations d'ingress
- utilisez une authentification en bonne et due forme (configurée dans AxonOps Server)
- restreignez l'accès réseau avec des network policies

### Référence complète des values

<details>
<summary>Cliquez pour dérouler le tableau complet des values</summary>

| Clé | Type | Défaut | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Règles d'affinité de pods pour l'ordonnancement |
| autoscaling.enabled | bool | `false` | Activer l'autoscaling horizontal des pods |
| autoscaling.maxReplicas | int | `100` | Nombre maximal de réplicas du HPA |
| autoscaling.minReplicas | int | `1` | Nombre minimal de réplicas du HPA |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Pourcentage d'utilisation CPU visé |
| config.axonServerUrl | string | `"http://axon-server:3000"` | Endpoint de l'API AxonOps Server |
| config.contextPath | string | `""` | Sous-chemin d'URL de l'application |
| config.extraConfig | object | `{}` | Options de configuration supplémentaires |
| config.listener.host | string | `"0.0.0.0"` | Hôte d'écoute |
| config.listener.port | int | `3000` | Port d'écoute |
| config.listener.ssl.enabled | bool | `false` | Activer SSL sur l'application |
| fullnameOverride | string | `""` | Remplacer le nom complet des ressources |
| httpRoute.annotations | object | `{}` | Annotations de l'HTTPRoute |
| httpRoute.enabled | bool | `false` | Activer l'HTTPRoute (Gateway API) |
| httpRoute.hostnames | list | `["chart-example.local"]` | Noms d'hôtes de l'HTTPRoute |
| httpRoute.parentRefs | list | `[{"name":"gateway","sectionName":"http"}]` | Références de Gateway |
| httpRoute.rules | list | `[{"matches":[{"path":{"type":"PathPrefix","value":"/headers"}}]}]` | Règles de l'HTTPRoute |
| image.pullPolicy | string | `"IfNotPresent"` | Politique de pull de l'image |
| image.repository | string | `"registry.axonops.com/axonops-public/axonops-docker/axon-dash"` | Dépôt de l'image de conteneur |
| image.tag | string | `""` | Tag de l'image (par défaut, appVersion) |
| imagePullSecrets | list | `[]` | Secrets de pull d'image pour les registres privés |
| ingress.annotations | object | `{}` | Annotations de l'ingress |
| ingress.className | string | `""` | Nom de la classe d'ingress |
| ingress.enabled | bool | `false` | Activer l'ingress |
| ingress.hosts | list | `[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Configuration des hôtes d'ingress |
| ingress.tls | list | `[]` | Configuration TLS de l'ingress |
| livenessProbe.httpGet.path | string | `"/"` | Chemin HTTP de la sonde de liveness |
| livenessProbe.httpGet.port | string | `"http"` | Port HTTP de la sonde de liveness |
| nameOverride | string | `""` | Remplacer le nom du chart |
| nodeSelector | object | `{}` | Labels de nœud pour l'affectation des pods |
| podAnnotations | object | `{}` | Annotations des pods |
| podLabels | object | `{}` | Labels supplémentaires des pods |
| podSecurityContext | object | `{}` | Contexte de sécurité du pod |
| readinessProbe.httpGet.path | string | `"/"` | Chemin HTTP de la sonde de readiness |
| readinessProbe.httpGet.port | string | `"http"` | Port HTTP de la sonde de readiness |
| replicaCount | int | `1` | Nombre de réplicas |
| resources | object | `{}` | Requêtes et limites de CPU / mémoire |
| securityContext | object | `{}` | Contexte de sécurité du conteneur |
| service.port | int | `3000` | Port du service |
| service.type | string | `"ClusterIP"` | Type de service Kubernetes |
| serviceAccount.annotations | object | `{}` | Annotations du service account |
| serviceAccount.automount | bool | `true` | Monter automatiquement le token du service account |
| serviceAccount.create | bool | `true` | Créer le service account |
| serviceAccount.name | string | `""` | Nom du service account |
| tolerations | list | `[]` | Tolerations pour l'affectation des pods |
| volumeMounts | list | `[]` | Montages de volumes supplémentaires |
| volumes | list | `[]` | Volumes supplémentaires |

</details>

## Mise à jour

Pour mettre à jour une installation existante :

```bash
# Update the chart
helm upgrade axon-dash ./axon-dash -f values-production.yaml

# Check rollout status
kubectl rollout status deployment/axon-dash
```

**Points importants :**
- avec plusieurs réplicas, les mises à jour du dashboard se font en général sans interruption
- les anciens pods ne sont arrêtés qu'une fois les nouveaux prêts
- testez d'abord les mises à jour hors production
- relisez le changelog avant toute mise à jour

## Désinstallation

Pour supprimer le dashboard AxonOps :

```bash
# Uninstall the release
helm uninstall axon-dash

# Optional: Remove any remaining resources
kubectl delete ingress -l app.kubernetes.io/name=axon-dash
kubectl delete hpa -l app.kubernetes.io/name=axon-dash
```

**Note :** le dashboard est sans état ; aucune donnée n'est perdue à la désinstallation.

## Dépannage

### Problèmes courants

**1. Le dashboard ne se connecte pas à AxonOps Server**

Vérifiez la configuration de l'URL du serveur :
```bash
# Get the dashboard pod logs
kubectl logs -l app.kubernetes.io/name=axon-dash

# Check if server URL is correct
kubectl get deployment axon-dash -o yaml | grep -A 3 axonServerUrl
```

Causes fréquentes :
- valeur `config.axonServerUrl` incorrecte
- AxonOps Server arrêté ou inaccessible
- une network policy bloque les connexions
- mauvais nom de service ou mauvais namespace

Testez la connectivité au serveur :
```bash
# Exec into dashboard pod
kubectl exec -it deployment/axon-dash -- sh

# Test connection to server
curl http://axon-server-api:8080/api/v1/healthz
```

**2. Le dashboard n'est pas accessible depuis l'extérieur**

Vérifiez la configuration de l'ingress :
```bash
# Check ingress status
kubectl get ingress

# Describe ingress for details
kubectl describe ingress axon-dash

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

Causes fréquentes :
- ingress non activé (`ingress.enabled: false`)
- mauvais nom de classe d'ingress
- DNS ne pointant pas vers le contrôleur d'ingress
- certificat TLS non émis (vérifiez cert-manager)

Testez l'ingress :
```bash
# Get ingress address
kubectl get ingress axon-dash

# Test DNS resolution
nslookup axonops.example.com

# Test HTTP/HTTPS
curl -I https://axonops.example.com
```

**3. Les pods plantent ou ne démarrent pas**

Vérifiez l'état et les logs des pods :
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=axon-dash

# View pod logs
kubectl logs -l app.kubernetes.io/name=axon-dash

# Describe pod for events
kubectl describe pod -l app.kubernetes.io/name=axon-dash
```

Causes fréquentes :
- ressources insuffisantes (augmentez `resources.limits`)
- configuration invalide
- erreurs de pull d'image (vérifiez `imagePullSecrets`)
- échecs des sondes de santé

**4. Le context path / sous-chemin ne fonctionne pas**

Si le dashboard ne fonctionne pas sous un sous-chemin :

```bash
# Check context path configuration
kubectl get deployment axon-dash -o yaml | grep contextPath

# Check ingress path configuration
kubectl get ingress axon-dash -o yaml
```

Assurez-vous que :
- `config.contextPath` correspond au chemin de l'ingress
- l'ingress porte les bonnes annotations de réécriture
- aucun slash final ne traîne dans la configuration du chemin

Exemple de configuration correcte :
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

**5. Consommation mémoire ou CPU élevée**

Vérifiez l'usage des ressources :
```bash
kubectl top pods -l app.kubernetes.io/name=axon-dash
```

Si elle reste durablement élevée :
- augmentez les limites de ressources
- activez l'autoscaling
- cherchez d'éventuelles fuites mémoire dans les logs
- vérifiez qu'il n'y a ni boucle infinie ni problème de performance

**6. L'autoscaling ne fonctionne pas**

Vérifiez l'état du HPA :
```bash
# Check HPA
kubectl get hpa

# Describe HPA
kubectl describe hpa axon-dash

# Check metrics server
kubectl top nodes
```

Causes fréquentes :
- metrics server non installé
- requêtes de ressources non définies
- cibles du HPA injoignables
- ressources du cluster insuffisantes

**7. Problèmes de certificat TLS/SSL**

En cas de problème de certificat :
```bash
# Check certificate status
kubectl get certificate

# Describe certificate
kubectl describe certificate axon-dash-tls

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

Assurez-vous que :
- cert-manager est installé et fonctionne
- le ClusterIssuer / Issuer existe
- le DNS est correctement configuré
- le challenge ACME peut aboutir

**8. Problèmes de répartition de charge avec plusieurs réplicas**

Si les requêtes ne sont pas réparties :
```bash
# Check service endpoints
kubectl get endpoints axon-dash

# Verify all pods are ready
kubectl get pods -l app.kubernetes.io/name=axon-dash

# Check service configuration
kubectl describe svc axon-dash
```

Assurez-vous que :
- tous les pods passent leurs sondes de readiness
- le sélecteur du service correspond aux labels des pods
- l'affinité de session est configurée si nécessaire

### Obtenir de l'aide

Pour un support complémentaire :

- **Consultez les logs :** `kubectl logs -l app.kubernetes.io/name=axon-dash`
- **Consultez les événements :** `kubectl get events --sort-by='.lastTimestamp'`
- **Décrivez le déploiement :** `kubectl describe deployment axon-dash`
- **Testez en local :**
  ```bash
  kubectl port-forward svc/axon-dash 3000:3000
  open http://localhost:3000
  ```
- **Documentation :** <https://docs.axonops.com>
- **Support :** <info@axonops.com>
- **Communauté :** <https://community.axonops.com>

## Mainteneurs

| Nom | E-mail | URL |
| ---- | ------ | --- |
| AxonOps Team | <info@axonops.com> | <https://axonops.com> |

---

*Généré avec les charts Helm AxonOps*
