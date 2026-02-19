#!/bin/bash
set -e

# AxonOps Schema Registry Entrypoint Script
# Displays startup banner with build info and executes the main process

# Display comprehensive startup banner
print_startup_banner() {
    if [ -f /etc/axonops/build-info.txt ]; then
      source /etc/axonops/build-info.txt 2>/dev/null || true
    fi

    echo "================================================================================"
    # Title
    echo "AxonOps Schema Registry ${SR_VERSION:-unknown}"

    # Image and build info (CI builds only - not shown for local/unknown builds)
    if [ -n "${CONTAINER_IMAGE}" ] && [ "${CONTAINER_IMAGE}" != "unknown" ] && [ "${CONTAINER_IMAGE}" != "" ]; then
      echo "Image: ${CONTAINER_IMAGE}"
    fi
    if [ -n "${CONTAINER_BUILD_DATE}" ] && [ "${CONTAINER_BUILD_DATE}" != "unknown" ] && [ "${CONTAINER_BUILD_DATE}" != "" ]; then
      echo "Built: ${CONTAINER_BUILD_DATE}"
    fi

    # Show release/tag link if available (CI builds)
    if [ -n "${CONTAINER_GIT_TAG}" ] && [ "${CONTAINER_GIT_TAG}" != "unknown" ] && [ "${CONTAINER_GIT_TAG}" != "" ]; then
      if [ "${IS_PRODUCTION_RELEASE:-false}" = "true" ]; then
        # Production build - link to release page (has release notes)
        echo "Release: https://github.com/axonops/axonops-containers/releases/tag/${CONTAINER_GIT_TAG}"
      else
        # Development build - link to tag/tree
        echo "Tag:     https://github.com/axonops/axonops-containers/tree/${CONTAINER_GIT_TAG}"
      fi
    fi

    # Show who built it if available (CI builds)
    if [ -n "${CONTAINER_BUILT_BY}" ] && [ "${CONTAINER_BUILT_BY}" != "unknown" ] && [ "${CONTAINER_BUILT_BY}" != "" ]; then
      if [ "${CONTAINER_BUILT_BY}" = "GitHub Actions" ] || [ "${IS_PRODUCTION_RELEASE:-false}" = "true" ]; then
        echo "Built by: ${CONTAINER_BUILT_BY}"
      fi
    fi

    echo "================================================================================"
    echo ""

    # Component versions (from build-info.txt)
    echo "Component Versions:"
    echo "  Schema Registry:    ${SR_VERSION:-unknown}"
    echo "  Binary Version:     ${SR_BINARY_VERSION:-unknown}"
    echo "  Container Version:  ${CONTAINER_VERSION_TAG:-unknown}"
    echo "  OS:                 ${OS_VERSION:-unknown}"
    echo "  Platform:           ${PLATFORM:-unknown}"
    echo ""

    # Supply chain verification (base image digest for security audit)
    echo "Supply Chain Security:"
    echo "  Base image:         registry.access.redhat.com/ubi9/ubi-minimal:latest"
    echo "  Base image digest:  ${UBI9_BASE_DIGEST:-unknown}"
    echo ""

    # Runtime environment (dynamic - only knowable at runtime)
    echo "Runtime Environment:"
    echo "  Hostname:           $(hostname 2>/dev/null || echo 'unknown')"

    # Kubernetes detection (safe - only if vars exist)
    if [ -n "${KUBERNETES_SERVICE_HOST}" ]; then
      echo "  Kubernetes:         Yes"
      echo "    API Server:       ${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"
      if [ -n "${HOSTNAME}" ]; then
        echo "    Pod:              ${HOSTNAME}"
      fi
    fi
    echo ""

    echo "================================================================================"
    echo "Starting Schema Registry..."
    echo "================================================================================"
    echo ""
}

print_startup_banner

# Execute the main process (CMD from Dockerfile)
exec "$@"
