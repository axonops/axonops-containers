# AxonOps Docker Compose

Deploy the complete AxonOps observability stack using Docker Compose. This provides a simple way to run AxonOps locally or in standalone environments without Kubernetes.

## Quick Start

1. **Copy the example environment file:**
   ```bash
   cp env.example .env
   ```

2. **Edit `.env` with your organization name:**
   ```bash
   AXONOPS_ORG_NAME=my-company
   ```

3. **Start the stack:**
   ```bash
   docker compose up -d
   ```

4. **Access the dashboard:**
   Open http://localhost:3000 in your browser.

## Services

| Service | Description | Port |
|---------|-------------|------|
| axondb-timeseries | Cassandra 5.0.6 for metrics storage | - |
| axondb-search | OpenSearch 3.3.2 for logs and search | - |
| axon-server | AxonOps API backend | 1888 (agents) |
| axon-dash | Web dashboard | 3000 |

## Configuration

### Required Settings

| Variable | Description |
|----------|-------------|
| `AXONOPS_ORG_NAME` | Your organization name (displayed in dashboard) |

### Optional Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `AXONOPS_LICENSE_KEY` | (empty) | License key (optional for trial) |
| `AXONOPS_DB_PASSWORD` | `axonops` | Cassandra password |
| `AXONOPS_SEARCH_PASSWORD` | `MyS3cur3P@ss2025` | OpenSearch admin password |
| `AXONOPS_CASSANDRA_HEAP_SIZE` | `4G` | Cassandra JVM heap |
| `AXONOPS_OPENSEARCH_HEAP_SIZE` | `4g` | OpenSearch JVM heap |

### SSL/TLS

SSL is enabled by default for both databases:
- **Cassandra**: Client-to-node encryption with auto-generated certificates
- **OpenSearch**: HTTPS with auto-generated self-signed certificates

To disable SSL (not recommended for production):
```bash
AXONOPS_CASSANDRA_SSL=false
AXONOPS_OPENSEARCH_SSL=false
```

## Connecting Agents

The agent port (1888) is exposed by default. Configure your Cassandra or Kafka agents to connect to:

```
Agent endpoint: <docker-host>:1888
```

For example, in your `axon-agent.yml`:
```yaml
axon-server:
  hosts: "your-docker-host:1888"
```

## System Requirements

- **Docker Engine**: 20.10+
- **Docker Compose**: 2.0+ (V2)
- **Memory**: Minimum 10GB RAM (16GB recommended)
  - Cassandra: 4GB heap
  - OpenSearch: 4GB heap
  - axon-server + axon-dash: ~1GB
- **Disk**: 20GB minimum (more for long-term data retention)

### Reducing Memory (Development Only)

For development/testing with limited resources:
```bash
AXONOPS_CASSANDRA_HEAP_SIZE=2G
AXONOPS_OPENSEARCH_HEAP_SIZE=2g
```

## Operations

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f axon-server
```

### Check Service Health

```bash
docker compose ps
```

### Stop the Stack

```bash
docker compose down
```

### Reset All Data

```bash
docker compose down -v
```

## Troubleshooting

### Services not starting

Services may take 2-3 minutes to become healthy on first start. Monitor status with:
```bash
docker compose ps
watch docker compose ps
```

### Health check failures

Check individual service logs:
```bash
docker compose logs axondb-timeseries
docker compose logs axondb-search
docker compose logs axon-server
```

### Connection refused to databases

Ensure the databases are fully healthy before axon-server starts. The compose file enforces this via `depends_on` with `condition: service_healthy`.

### Out of memory

Reduce heap sizes in `.env`:
```bash
AXONOPS_CASSANDRA_HEAP_SIZE=2G
AXONOPS_OPENSEARCH_HEAP_SIZE=2g
```

### Dashboard not loading

1. Check axon-dash can reach axon-server:
   ```bash
   docker exec axon-dash curl -s http://axon-server:8080/api/v1/healthz
   ```

2. Check browser console for errors

## Data Persistence

Data is stored in Docker volumes:

| Volume | Contents |
|--------|----------|
| `axonops-timeseries-data` | Cassandra metrics data |
| `axonops-timeseries-logs` | Cassandra logs |
| `axonops-search-data` | OpenSearch logs/indices |
| `axonops-search-logs` | OpenSearch logs |
| `axonops-server-data` | axon-server state |

## License

AxonOps requires a license for production use. Get your license at https://axonops.com

For evaluation, the stack works without a license key (trial mode).
