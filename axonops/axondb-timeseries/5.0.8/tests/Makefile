.PHONY: build test test-smoke test-integration test-all clean help

# Default target
all: test

# Build the image
build:
	@echo "Building image: localhost/axondb-timeseries:backup-complete"
	@cd .. && ./build-local.sh -t localhost/axondb-timeseries:backup-complete

# Run all test suites (builds first)
test: build clean
	@echo "Running complete test suite..."
	@bash run-all-tests.sh

# Quick smoke tests only
test-smoke: clean
	@echo "Running smoke tests..."
	@bash smoke/basic-functionality.sh

# Integration tests only
test-integration: clean
	@echo "Running integration tests..."
	@for test in integration/0*.sh; do \
		echo "Running $$test..."; \
		bash $$test || exit 1; \
	done

# Run everything (alias for test)
test-all: test

# Clean test artifacts
clean:
	@echo "Cleaning test resources..."
	@podman rm -f $$(podman ps -aq) 2>/dev/null || true
	@podman network ls --format "{{.Name}}" | grep -E "ip-test|test-" | xargs -r podman network rm 2>/dev/null || true
	@sudo rm -rf .test-backups/* 2>/dev/null || true
	@rm -f results/*.log results/*-results.txt 2>/dev/null || true
	@echo "✓ Clean"

# Help
help:
	@echo "AxonDB Backup/Restore Test Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make test              - Run all test suites (default)"
	@echo "  make test-smoke        - Run smoke tests only (quick)"
	@echo "  make test-integration  - Run integration tests only"
	@echo "  make clean             - Clean test artifacts"
	@echo "  make help              - Show this help"
	@echo ""
	@echo "Or run directly:"
	@echo "  ./run-all-tests.sh     - Same as 'make test'"
