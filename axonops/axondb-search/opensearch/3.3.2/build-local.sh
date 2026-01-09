#!/bin/bash
# Local development build script for macOS
# Detects architecture and sets TARGETARCH for proper cqlai/tini installation

set -e

# Detect host architecture and map to Docker TARGETARCH naming
HOST_ARCH=$(uname -m)
if [ "$HOST_ARCH" = "arm64" ] || [ "$HOST_ARCH" = "aarch64" ]; then
    TARGETARCH="arm64"
    PLATFORM="linux/arm64"
elif [ "$HOST_ARCH" = "x86_64" ]; then
    TARGETARCH="amd64"
    PLATFORM="linux/amd64"
else
    echo "ERROR: Unsupported architecture: $HOST_ARCH"
    exit 1
fi


TOKEN=$(curl -s "https://sso.redhat.com/auth/realms/rhcc/protocol/redhat-docker-v2/auth?service=docker-registry&client_id=curl&scope=repository:ubi9/ubi-minimal:pull" | jq -r .access_token)
DIGEST=$(curl -s -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
     "https://registry.access.redhat.com/v2/ubi9/ubi-minimal/manifests/latest" | jq ".manifests[] | select(.platform.architecture == \"$TARGETARCH\")" | jq -r .digest)


IMAGE_NAME=${1:-axondb-search:latest}
shift

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
    --build-arg UBI9_MINIMAL_DIGEST=$DIGEST \
    -t $IMAGE_NAME \
    "$@" \
    .

echo ""
echo "=========================================="
echo "Build complete!"
echo "Image tagged: ${IMAGE_NAME}"
echo "=========================================="
