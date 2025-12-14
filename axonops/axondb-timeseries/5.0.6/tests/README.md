# AxonDB Time-Series Container Tests

Automated test suite for validating container initialization and configuration.

## Test Scenarios

### Scenario 1: Default Behavior
- **File**: `test-scenario-1-default.yml`
- **Config**: No custom env vars
- **Expected**: System keyspace init runs, no custom user creation
- **Validates**: Default DC detection, NetworkTopologyStrategy conversion

### Scenario 2: Skip Keyspace and Role Init
- **File**: `test-scenario-2-skip-init.yml`
- **Config**: `INIT_SYSTEM_KEYSPACES_AND_ROLES=false`
- **Expected**: Keyspace and role init skipped, semaphores written immediately
- **Validates**: Init script can be disabled

### Scenario 3: Custom User Creation
- **File**: `test-scenario-3-custom-user.yml`
- **Config**: `AXONOPS_DB_USER=axonops`, `AXONOPS_DB_PASSWORD=securepass123`
- **Expected**: Custom user created, default cassandra user disabled
- **Validates**: User creation, authentication, default user lockout

### Scenario 4: Combined (Skip Init + Custom User)
- **File**: `test-scenario-4-combined.yml`
- **Config**: `INIT_SYSTEM_KEYSPACES_AND_ROLES=false`, custom user credentials
- **Expected**: Both keyspace init and user creation skipped (init disabled)
- **Validates**: When init is disabled, both operations are skipped

### Scenario 5: Multi-Node Cluster
- **File**: `test-compose.yml`
- **Config**: 3-node cluster
- **Expected**: Init scripts only run on first node, skip on others
- **Validates**: Multi-node cluster detection

### Scenario 6: Default DC Test
- **File**: `test-scenario-default-dc.yml`
- **Config**: No CASSANDRA_DC specified
- **Expected**: Uses default `axonopsdb_dc1` datacenter
- **Validates**: Default DC behavior

## Running Tests

### Run All Scenarios
```bash
./run-tests.sh
```

This will:
1. Build the container image (if not already built)
2. Run all test scenarios sequentially
3. Validate initialization scripts
4. Check semaphore files
5. Verify keyspace replication strategies
6. Test user authentication
7. Generate test results report

### Test Results
Results are written to `test-results.txt` with pass/fail status for each scenario.

## Prerequisites

- `podman` or `docker` installed
- `podman-compose` or `docker-compose` installed
- Container image built: `axondb-timeseries:latest`

## Build Container
```bash
podman build --build-arg CQLAI_VERSION=0.0.31 -t axondb-timeseries:latest -f ../Dockerfile ..
```

## Manual Testing

To test a specific scenario:
```bash
podman-compose -f test-scenario-1-default.yml up -d
podman logs cassandra-test1 -f
podman exec cassandra-test1 nodetool status
podman exec cassandra-test1 cat /var/lib/cassandra/.axonops/init-system-keyspaces.done
podman-compose -f test-scenario-1-default.yml down -v
```

## What Tests Validate

1. **DC Detection**: Verifies actual datacenter name is detected from Cassandra
2. **Keyspace Conversion**: Confirms system keyspaces use NetworkTopologyStrategy
3. **User Management**: Validates custom user creation and default user lockout
4. **Semaphore Files**: Ensures healthcheck coordination works correctly
5. **Multi-Node Safety**: Confirms init only runs on single-node clusters
6. **Configuration Flexibility**: Tests various env var combinations
