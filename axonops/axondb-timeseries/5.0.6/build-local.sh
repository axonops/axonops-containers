#!/bin/bash
# Local development build script for macOS
# Detects architecture and sets TARGETARCH for proper cqlai/tini installation

set -e

# Detect host architecture and map to Docker TARGETARCH naming
HOST_ARCH=$(uname -m)
if [ "$HOST_ARCH" = "arm64" ]; then
    TARGETARCH="arm64"
    PLATFORM="linux/arm64"
elif [ "$HOST_ARCH" = "x86_64" ]; then
    TARGETARCH="amd64"
    PLATFORM="linux/amd64"
else
    echo "ERROR: Unsupported architecture: $HOST_ARCH"
    exit 1
fi

echo "=========================================="
echo "Building AxonDB Time-Series Cassandra"
echo "=========================================="
echo "Host architecture: $HOST_ARCH"
echo "Target architecture: $TARGETARCH"
echo "Platform: $PLATFORM"
echo "=========================================="
echo ""

# Build with explicit platform and TARGETARCH
podman build \
    --platform "$PLATFORM" \
    --build-arg TARGETARCH="$TARGETARCH" \
    --build-arg CQLAI_VERSION=0.0.31 \
    -t axondb-timeseries:latest \
    "$@" \
    .

echo ""
echo "=========================================="
echo "Build complete!"
echo "Image tagged: axondb-timeseries:latest"
echo "=========================================="
