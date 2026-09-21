# Meta-chart AxonOps

[English](README.md) | **Français** | [Español](README.es.md) | [Galego](README.gl.md)

## Vue d'ensemble

Ce chart Helm déploie la stack d'observabilité AxonOps complète pour la supervision d'Apache Cassandra et de Kafka. Il joue le rôle de chart parapluie qui orchestre le déploiement de tous les composants AxonOps avec des valeurs par défaut raisonnables.

### Composants

Le meta-chart déploie les composants suivants, dans cet ordre :

1. **axondb-timeseries** — la base time-series (Cassandra 5.0.6) de stockage des métriques
2. **axondb-search** — le backend de recherche (OpenSearch 3.3.2) pour les logs et la recherche
3. **axon-server** — la plateforme d'observabilité AxonOps
4. **axon-dash** — l'interface web du dashboard

Tous les sous-charts sont hébergés sur le registre OCI AxonOps, à l'adresse `ghcr.io/axonops/charts`.

## Prérequis

- Kubernetes 1.19+
- Helm 3.8+
- la prise en charge d'un provisionneur de PV dans le cluster (pour le stockage persistant)
- des ressources minimales dans le cluster (avec les 8 Go de heap par défaut) :
  - 8 cœurs CPU
  - 40 Go de RAM (pour 8 Go de heap sur chacune des deux bases, plus l'overhead)
  - 200 Go de stockage (100 Go par base)

## Installation

### Démarrage rapide

Déployer la stack AxonOps complète avec les réglages par défaut :

```bash
# Navigate to the chart directory
cd axonops/charts/axonops

# Update dependencies from OCI registry
helm dependency update

# Install the chart
helm install axonops . --namespace axonops --create-namespace
```

**Note :** la configuration par défaut utilise 8 Go de heap pour les deux bases. Pour un environnement de développement aux ressources limitées, voir la section [Configuration des ressources](#configuration-des-ressources) ci-dessous.

### Installation personnalisée

Installer avec un fichier de values personnalisé :

```bash
# Create a custom values file
cat > custom-values.yaml <<EOF
axon-server:
  config:
    org_name: "my-organization"
    license_key: "your-license-key"
  dashboardUrl: https://axonops.mydomain.com

axondb-timeseries:
  persistence:
    size: 50Gi

axondb-search:
  persistence:
    size: 50Gi
EOF

# Install with custom values
helm install axonops . -f custom-values.yaml --namespace axonops --create-namespace
```

### Installation de production

Pour un déploiement de production, vous DEVEZ :

1. **changer tous les mots de passe par défaut**
2. **renseigner le nom de votre organisation et votre clé de licence**
3. **configurer des limites de ressources adaptées**
4. **activer le stockage persistant avec des tailles adaptées**

```bash
# Generate secure passwords
SEARCH_PASSWORD=$(openssl rand -base64 32)
CASSANDRA_PASSWORD=$(openssl rand -base64 32)

# Install with secure configuration
helm install axonops . \
  --namespace axonops \
  --create-namespace \
  --set axon-server.config.org_name="production-org" \
  --set axon-server.config.license_key="YOUR_LICENSE_KEY" \
  --set axon-server.dashboardUrl="https://axonops.yourdomain.com" \
  --set axondb-search.security.adminPassword="$SEARCH_PASSWORD" \
  --set axondb-timeseries.cassandra.auth.password="$CASSANDRA_PASSWORD" \
  --set axon-server.searchDb.password="$SEARCH_PASSWORD" \
  --set axon-server.config.extraConfig.cql_password="$CASSANDRA_PASSWORD" \
  --set axon-server.config.extraConfig.cql_username="cassandra" \
  --set axondb-timeseries.cassandra.auth.username="cassandra" \
  --set axondb-timeseries.persistence.size=200Gi \
  --set axondb-search.persistence.size=200Gi
```

## Configuration

### Principaux paramètres de configuration

| Paramètre | Description | Défaut |
|-----------|-------------|---------|
| `axondb-timeseries.enabled` | Activer la base time-series Cassandra | `true` |
| `axondb-search.enabled` | Activer le backend OpenSearch | `true` |
| `axon-server.enabled` | Activer le serveur AxonOps | `true` |
| `axon-dash.enabled` | Activer l'interface du dashboard | `true` |
| `axondb-timeseries.heapSize` | Taille du heap JVM de Cassandra | `8192M` |
| `axondb-search.opensearchHeapSize` | Taille du heap JVM d'OpenSearch | `8g` |
| `axon-server.config.org_name` | Le nom de votre organisation | `example` |
| `axon-server.config.license_key` | Clé de licence AxonOps | `""` |
| `axon-server.dashboardUrl` | URL publique du dashboard | `https://axonops.example.com` |

### Configuration des ressources

Allocations de ressources par défaut, avec 8 Go de heap pour la production :

```yaml
axondb-timeseries:
  heapSize: 8192M  # 8G heap for production
  resources:
    requests:
      memory: 9Gi    # Heap + overhead
      cpu: 1000m
    limits:
      memory: 10Gi
      cpu: 2000m

axondb-search:
  opensearchHeapSize: "8g"  # 8G heap for production
  resources:
    requests:
      memory: 9Gi    # Heap + overhead
      cpu: 1000m
    limits:
      memory: 10Gi
      cpu: 2000m

axon-server:
  resources:
    requests:
      memory: 512Mi
      cpu: 250m
    limits:
      memory: 1Gi
      cpu: 500m
```

Pour un environnement de développement ou de test, vous pouvez réduire les tailles de heap :

```yaml
axondb-timeseries:
  heapSize: 2048M  # 2G heap for dev/test

axondb-search:
  opensearchHeapSize: "2g"  # 2G heap for dev/test
```

### Configuration du stockage

Configuration de stockage par défaut (100 Gi par base) :

```yaml
axondb-timeseries:
  persistence:
    enabled: true
    size: 100Gi  # Default for production
    # storageClass: "fast-ssd"  # Optional: specify storage class

axondb-search:
  persistence:
    enabled: true
    size: 100Gi  # Default for production
    # storageClass: "fast-ssd"  # Optional: specify storage class
```

## Sécurité

### AVERTISSEMENT : identifiants par défaut

Ce chart contient des mots de passe par défaut, destinés au développement et aux tests. **Ne les utilisez JAMAIS en production !**

Identifiants par défaut :
- administrateur OpenSearch : `admin` / `MyS3cur3P@ss2025`
- Cassandra : `cassandra` / `cassandra`

### Changer les mots de passe

Définissez toujours vos propres mots de passe en production :

```bash
helm install axonops . \
  --set axondb-search.security.adminPassword="YOUR_SECURE_PASSWORD" \
  --set axondb-timeseries.cassandra.auth.password="YOUR_SECURE_PASSWORD" \
  --set axon-server.searchDb.password="YOUR_SECURE_PASSWORD" \
  --set axon-server.config.extraConfig.cql_password="YOUR_SECURE_PASSWORD"
```

### Utiliser des Secrets Kubernetes pour les identifiants de base de données (recommandé)

En production, il est recommandé de conserver les identifiants de base de données dans des secrets Kubernetes plutôt que dans les values Helm. Cette approche renforce la sécurité et facilite la rotation des identifiants.

#### Étape 1 : créer les secrets

```bash
# Create secret for Cassandra/timeseries database credentials
kubectl create secret generic cassandra-credentials -n axonops \
  --from-literal=AXONOPS_DB_USER=axonops \
  --from-literal=AXONOPS_DB_PASSWORD=$(openssl rand -base64 32)

# Create secret for OpenSearch credentials
kubectl create secret generic opensearch-credentials -n axonops \
  --from-literal=AXONOPS_SEARCH_USER=axonops \
  --from-literal=AXONOPS_SEARCH_PASSWORD=$(openssl rand -base64 32)
```

#### Étape 2 : configurer axon-server pour utiliser les secrets

```yaml
axon-server:
  config:
    # Reference the Cassandra credentials secret
    db_secret: "cassandra-credentials"
    extraConfig:
      cql_hosts:
        - axondb-timeseries-headless.axonops.svc.cluster.local
      cql_local_dc: "datacenter1"
      # Note: cql_username and cql_password are ignored when db_secret is set

  # Reference the OpenSearch credentials secret
  searchDb:
    hosts:
      - https://axondb-search-cluster-master:9200
    search_secret: "opensearch-credentials"
    # Note: username and password are ignored when search_secret is set
```

Points importants :

- le secret Cassandra doit contenir les clés `AXONOPS_DB_USER` et `AXONOPS_DB_PASSWORD`
- le secret OpenSearch doit contenir les clés `AXONOPS_SEARCH_USER` et `AXONOPS_SEARCH_PASSWORD`
- ces noms de clés sont compatibles avec les charts axondb-timeseries et axondb-search, ce qui permet de partager les secrets entre charts

### Configuration TLS

Activer TLS pour axon-server :

```yaml
axon-server:
  config:
    tls:
      mode: "TLS"  # or "mTLS" for mutual TLS
      cert: |
        -----BEGIN CERTIFICATE-----
        YOUR_CERTIFICATE_HERE
        -----END CERTIFICATE-----
      key: |
        -----BEGIN PRIVATE KEY-----
        YOUR_PRIVATE_KEY_HERE
        -----END PRIVATE KEY-----
```

## Déploiement sélectif

Vous pouvez ne déployer que certains composants, en désactivant les autres :

### Déployer uniquement les bases de données

```bash
helm install axonops-db . \
  --set axon-server.enabled=false \
  --set axon-dash.enabled=false
```

### Déployer sans le dashboard

```bash
helm install axonops . \
  --set axon-dash.enabled=false
```

### Déployer sans le backend de recherche

```bash
helm install axonops . \
  --set axondb-search.enabled=false
```

### Déploiement de développement, à ressources réduites

```bash
# Deploy with 2G heap for development/testing
helm install axonops-dev . \
  --namespace axonops-dev \
  --create-namespace \
  --set axondb-timeseries.heapSize=2048M \
  --set axondb-timeseries.resources.requests.memory=3Gi \
  --set axondb-timeseries.resources.limits.memory=4Gi \
  --set axondb-search.opensearchHeapSize="2g" \
  --set axondb-search.resources.requests.memory=3Gi \
  --set axondb-search.resources.limits.memory=4Gi \
  --set axondb-timeseries.persistence.size=20Gi \
  --set axondb-search.persistence.size=20Gi
```

## Accéder aux services

### Accès au dashboard

Après installation, accédez au dashboard :

1. **Port-forward** (pour les tests) :
```bash
kubectl port-forward -n axonops svc/axonops-axon-dash 3000:3000
# Access at http://localhost:3000
```

2. **Ingress** (pour la production) :
Configurez l'ingress dans les values :
```yaml
axon-dash:
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: axonops.yourdomain.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: axonops-tls
        hosts:
          - axonops.yourdomain.com
```

### Accès à l'API

L'API AxonOps est disponible ainsi :
```bash
kubectl port-forward -n axonops svc/axonops-axon-server-api 8080:8080
# API at http://localhost:8080
```

### Connexion des agents

Les agents Cassandra se connectent à :

- service : `axonops-axon-server-agent`
- port : `1888`
- endpoint depuis l'extérieur du cluster : configurez un ingress ou un LoadBalancer

## Supervision

### Vérifier l'état des pods

```bash
# Watch pod startup
kubectl get pods -n axonops --watch

# Check pod logs
kubectl logs -n axonops deployment/axonops-axon-server
kubectl logs -n axonops statefulset/axondb-timeseries
kubectl logs -n axonops statefulset/axondb-search-cluster-master
```

### Ordre de démarrage attendu

1. `axondb-timeseries-0` — doit passer Running en premier
2. `axondb-search-cluster-master-0` — doit passer Running en deuxième
3. `axonops-axon-server-*` — démarre une fois les bases prêtes
4. `axonops-axon-dash-*` — démarre en dernier

### Vérifier les services

```bash
# List all services
kubectl get svc -n axonops

# Expected services (assuming release name "axonops"):
# - axondb-timeseries
# - axondb-timeseries-headless
# - axondb-search-cluster-master
# - axondb-search-cluster-master-headless
# - axonops-axon-server-api
# - axonops-axon-server-agent
# - axonops-axon-dash
```

### Tester la connectivité

```bash
# Test OpenSearch
kubectl exec -n axonops deploy/axonops-axon-server -- \
  curl -k -u admin:MyS3cur3P@ss2025 https://axondb-search-cluster-master:9200

# Test Cassandra
kubectl exec -n axonops deploy/axonops-axon-server -- \
  nc -zv axondb-timeseries-headless 9042
```

## Dépannage

### Les pods ne démarrent pas

1. **Consultez les événements** :
```bash
kubectl describe pod -n axonops <pod-name>
```

2. **Consultez les logs** :
```bash
kubectl logs -n axonops <pod-name> --previous
```

3. **Problèmes courants** :
- ressources insuffisantes : augmentez les limites mémoire / CPU
- problèmes de stockage : vérifiez l'état des PVC
- erreurs de pull d'image : vérifiez l'accès au registre

### Problèmes de connexion aux services

1. **Vérifiez la résolution DNS** :
```bash
kubectl exec -n axonops deploy/axonops-axon-server -- nslookup axondb-timeseries-headless
```

2. **Vérifiez les endpoints des services** :
```bash
kubectl get endpoints -n axonops
```

3. **Testez la connectivité des ports** :
```bash
kubectl exec -n axonops deploy/axonops-axon-server -- nc -zv axondb-search-cluster-master 9200
```

### Problèmes de base de données

**Cassandra n'est pas prêt** :
```bash
# Check Cassandra status
kubectl exec -n axonops axondb-timeseries-0 -- nodetool status
```

**OpenSearch n'est pas prêt** :
```bash
# Check cluster health
kubectl exec -n axonops axondb-search-cluster-master-0 -- \
  curl -k -u admin:MyS3cur3P@ss2025 https://localhost:9200/_cluster/health?pretty
```

### Réinstaller

S'il vous faut réinstaller :

```bash
# Uninstall
helm uninstall axonops -n axonops

# Clean up PVCs (WARNING: This deletes data!)
kubectl delete pvc -n axonops --all

# Reinstall
helm install axonops . --namespace axonops --create-namespace
```

## Tests

### Validation des versions de dépendances

Le meta-chart embarque une validation automatisée qui vérifie que les versions de dépendances déclarées dans `Chart.yaml` correspondent aux versions réelles des sous-charts. Cette validation s'exécute automatiquement dans GitHub Actions à chaque push et à chaque pull request.

**Ce qu'elle valide :**

- toutes les versions de dépendances du meta-chart correspondent aux versions réelles des sous-charts
- aucun écart de version ne subsiste avant la construction des dépendances
- le chart est prêt pour une release

**Intégration CI/CD :**

La validation s'exécute dans le workflow `helm-charts-test.yml`, dans le job `validate-dependency-versions` :

- ✅ s'exécute automatiquement sur les push vers development et les branches de fonctionnalité
- ✅ s'exécute sur les pull requests vers main et development
- ✅ peut être déclenchée manuellement via workflow_dispatch
- ✅ exécution rapide (environ 30 secondes)
- ✅ fait échouer le build si les versions ne correspondent pas

**Que se passe-t-il en cas d'échec :**

Si un écart de version est détecté, le workflow échoue avec un message explicite qui indique :

- quel chart présente l'écart
- la version attendue (celle du sous-chart)
- la version indiquée dans les dépendances du meta-chart
- la marche à suivre pour corriger

## Mise à jour

Pour mettre le déploiement à jour :

```bash
# Update dependencies
helm dependency update

# Upgrade release
helm upgrade axonops . -n axonops
```

## Désinstallation

Pour supprimer le déploiement :

```bash
# Uninstall the chart
helm uninstall axonops -n axonops

# Optional: Remove namespace
kubectl delete namespace axonops

# Optional: Remove persistent volumes (WARNING: Data loss!)
kubectl delete pvc -n axonops --all
```

## Référence des values

Voir [values.yaml](values.yaml) pour la liste complète des options de configuration, avec des commentaires détaillés.

## Support

Pour les problèmes, questions ou contributions :
- GitHub : https://github.com/axonops/axonops-containers
- E-mail : info@axonops.com
- Documentation : https://axonops.com/docs

## Licence

Copyright AxonOps. Tous droits réservés.
