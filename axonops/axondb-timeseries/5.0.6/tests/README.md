# AxonDB Cassandra Backup/Restore Test Suite

Professional test framework for validating backup/restore functionality in AxonDB Cassandra containers.

## Quick Start

```bash
# Run all tests (builds image first, then runs smoke + 9 integration tests)
make test

# Or use the runner directly
./run-all-tests.sh
```

## Test Structure

```
tests/
├── Makefile                      # Build + test automation
├── run-all-tests.sh              # Unified test runner
├── lib/
│   └── test-common.sh            # Shared utilities (cleanup, wait, register)
├── smoke/
│   └── basic-functionality.sh    # 25 smoke tests (script validation)
├── integration/
│   ├── 01-kubernetes-restore.sh  # K8s pod recreation + .axonops preservation
│   ├── 02-retention-policy.sh    # Retention with name-based timestamps + async deletion
│   ├── 03-full-copy-mode.sh      # BACKUP_USE_HARDLINKS=false validation
│   ├── 04-hardlink-chain.sh      # Hardlink integrity after deletion
│   ├── 05-env-vars.sh            # Environment variable integration
│   ├── 06-hardlink-portability.sh# rsync --link-dest behavior
│   ├── 07-ip-address-change.sh   # IP change restore validation
│   ├── 08-lock-semaphore.sh      # Backup overlap prevention
│   └── 09-log-rotation.sh        # Log rotation + retention
└── results/                       # All test outputs (.gitignored)
```

## Makefile Targets

```bash
make test              # Build image + run all tests (default)
make test-smoke        # Run smoke tests only (quick validation)
make test-integration  # Run integration tests only (9 tests)
make build             # Build the container image
make clean             # Clean test artifacts
make help              # Show help
```

## Test Coverage

### Smoke Tests (25 checks)
- Backup script existence and executability
- Restore script existence and executability
- Hardlink deduplication
- Retention policy configuration
- Error handling and retry mechanisms
- Lock semaphore implementation
- Orphaned snapshot cleanup
- Backup scheduler integration

### Integration Tests (9 tests)

**01-kubernetes-restore.sh**
- Creates container with init enabled + custom credentials
- Backs up data + .axonops directory
- Destroys container (simulates pod deletion)
- Restores to new container
- Validates: init NOT re-run, credentials work, data restored

**02-retention-policy.sh**
- Creates 3 old backups (4h ago by NAME timestamp)
- Creates 2 recent backups
- Runs retention with 2h policy
- Validates: async deletion, 5 → 3 backups

**03-full-copy-mode.sh**
- Creates 2 backups with BACKUP_USE_HARDLINKS=false
- Validates: 0 files with Links > 1

**04-hardlink-chain.sh**
- Creates 3 backups (hardlink chain)
- Picks file from backup-2, records inode
- Deletes backup-1
- Validates: same inode, data intact

**05-env-vars.sh**
- Tests BACKUP_SCHEDULE triggers scheduler
- Tests RESTORE_FROM_BACKUP="latest"
- Tests missing retention causes exit

**06-hardlink-portability.sh**
- Validates rsync --link-dest behavior
- Confirms hardlinks preserved across backups

**07-ip-address-change.sh**
- Creates backup with IP 172.30.0.100
- Restores to container with IP 172.30.0.200
- Validates: Cassandra starts, data accessible

**08-lock-semaphore.sh**
- Starts backup in background
- Tries to start second backup
- Validates: second backup rejected, lock cleaned up

**09-log-rotation.sh**
- Creates log > 10MB
- Runs log-rotate.sh
- Validates: .1.gz created, original truncated, retention enforced

## Test Features

### Automatic Cleanup
All tests use `trap cleanup_test_resources EXIT` to ensure:
- Containers removed after test
- Networks removed after test
- No manual cleanup required
- Tests can run repeatedly

### Shared Library (lib/test-common.sh)
Common functions:
- `register_container()` - Track container for cleanup
- `register_network()` - Track network for cleanup
- `cleanup_test_resources()` - Remove all tracked resources
- `wait_for_cassandra_ready()` - Wait for Cassandra to be ready
- `create_test_container()` - Create container with common settings
- `pass_test()` / `fail_test()` - Test result tracking
- `print_test_summary()` - Print results

### Results Directory
All test outputs written to `results/`:
- `smoke-test-results.txt`
- Individual integration test logs
- .gitignored (not committed)

## Running Tests

### All Tests (Recommended)
```bash
make test
```
Runs:
1. Build image (localhost/axondb-timeseries:backup-complete)
2. Clean previous artifacts
3. Smoke tests (25 checks)
4. Integration tests (9 tests)
5. Final summary

### Smoke Tests Only
```bash
make test-smoke
```
Quick validation (2-3 minutes):
- Script existence checks
- Basic backup/restore functionality
- Configuration validation

### Integration Tests Only
```bash
make test-integration
```
Full scenarios (15-20 minutes):
- K8s pod recreation
- Retention policies
- Hardlink chains
- IP address changes

### Individual Test
```bash
cd integration
./01-kubernetes-restore.sh
```

## Test Requirements

### Environment
- Podman or Docker
- Linux system (uses sudo for cleanup)
- Bash 4.0+
- ~10GB disk space for backups
- ~8GB RAM for containers

### Backup Volume
Tests use: `.test-backups/` (project-local directory)

Created automatically, cleaned between tests, added to .gitignore.

## Test Repeatability

Tests are designed to run repeatedly without manual cleanup:

```bash
make test  # Run 1
make test  # Run 2 (no manual cleanup needed)
make test  # Run 3 (no manual cleanup needed)
```

All tests should pass every time.

## Debugging Failed Tests

### Check Results
```bash
cat results/smoke-test-results.txt
cat results/*-results.txt
```

### Check Logs
```bash
# Container logs
podman logs <container-name>

# Test output
cat results/*.log
```

### Run Individual Test
```bash
# Run single test for debugging
bash integration/01-kubernetes-restore.sh
```

### Manual Cleanup (if needed)
```bash
make clean

# Or manually:
podman rm -f $(podman ps -aq)
sudo rm -rf ~/axondb-backup-testing/backup-volume/*
```

## CI/CD Integration

### GitHub Actions Example
```yaml
- name: Run backup/restore tests
  run: |
    cd tests
    make test
```

### Jenkins Example
```groovy
stage('Test') {
    steps {
        sh 'cd tests && make test'
    }
}
```

## Test Development

### Adding New Tests

1. Create test file: `integration/10-new-test.sh`
2. Use template pattern:
```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/test-common.sh"

trap cleanup_test_resources EXIT

run_test

# Create container
create_test_container "test-name"

# Run test steps
# ...

# Verify results
pass_test "Test description"
print_test_summary
```

3. Make executable: `chmod +x integration/10-new-test.sh`
4. Run: `make test`

### Best Practices
- Source lib/test-common.sh
- Set trap for cleanup
- Register all containers/networks
- Use descriptive test names
- Clean backups at start of test
- Validate results explicitly
- Return proper exit codes (0 = pass, 1 = fail)

## Support

For issues or questions:
- Check existing test results in `results/`
- Review test logs
- Verify image built correctly: `podman images | grep axondb-timeseries`
