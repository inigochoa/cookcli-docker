#!/bin/bash

set -e

# Configuration
IMAGE_NAME="inigochoa/cookcli"
VERSION="${VERSION:-latest}"
PLATFORMS="linux/amd64,linux/arm64"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Build function - builds image for local architecture only
build() {
    LOCAL_ARCH=$(uname -m)
    case "${LOCAL_ARCH}" in
        x86_64) PLATFORM="linux/amd64" ;;
        aarch64|arm64) PLATFORM="linux/arm64" ;;
        *) log_error "Unsupported architecture: ${LOCAL_ARCH}"; exit 1 ;;
    esac

    log_info "Building ${IMAGE_NAME} for local platform (${PLATFORM})"
    if [ "${VERSION}" = "latest" ]; then
        log_info "Version: will fetch latest release from GitHub during build"
    else
        log_info "Version: ${VERSION}"
    fi

    docker buildx build \
        --platform "${PLATFORM}" \
        --build-arg VERSION="${VERSION}" \
        -t "${IMAGE_NAME}:${VERSION}" \
        -t "${IMAGE_NAME}:latest" \
        --load \
        -f Dockerfile \
        .

    log_info "Build completed successfully!"
    log_info "Tagged as: ${IMAGE_NAME}:${VERSION} and ${IMAGE_NAME}:latest"
    log_warn "Note: This is a single-architecture build for ${PLATFORM}"
    log_warn "Use 'publish' command for multi-architecture builds"
}

# Test function - builds and runs the image locally
test() {
    log_info "Building and testing ${IMAGE_NAME}"
    if [ "${VERSION}" = "latest" ]; then
        log_info "Version: will fetch latest release from GitHub during build"
    else
        log_info "Version: ${VERSION}"
    fi

    # Build for local platform only (faster)
    docker buildx build \
        --build-arg VERSION="${VERSION}" \
        -t "${IMAGE_NAME}:test" \
        --load \
        -f Dockerfile \
        .

    # Create test directory
    TEST_DIR="./test-recipes"
    mkdir -p "${TEST_DIR}"

    # Create a sample recipe if directory is empty
    if [ -z "$(ls -A ${TEST_DIR})" ]; then
        log_info "Creating sample recipe for testing..."
        cat > "${TEST_DIR}/test.cook" << 'EOF'
>> title: Test Recipe
>> tags: test

This is a test recipe.

Mix @flour{2%cups} with @water{1%cup}.
EOF
    fi

    log_info "Starting container for testing..."

    # Stop and remove existing test container if exists
    docker stop cookcli-test 2>/dev/null || true
    docker rm cookcli-test 2>/dev/null || true

    # Run the container
    docker run -d \
        --name cookcli-test \
        -p 9080:9080 \
        -v "$(pwd)/${TEST_DIR}:/recipes" \
        --cpus="0.10" \
        --memory="32m" \
        "${IMAGE_NAME}:test"

    log_info "Waiting for server to start..."
    sleep 5

    # Test health check
    MAX_RETRIES=10
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -f http://localhost:9080/ > /dev/null 2>&1; then
            log_info "✓ Health check passed!"
            log_info "✓ Server is running at http://localhost:9080"
            log_info ""
            log_info "Test completed successfully!"
            log_info "Container 'cookcli-test' is running."
            log_info "To stop: docker stop cookcli-test"
            log_info "To view logs: docker logs cookcli-test"
            return 0
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        log_warn "Health check failed, retrying... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 3
    done

    log_error "Health check failed after $MAX_RETRIES attempts"
    log_error "Container logs:"
    docker logs cookcli-test
    docker stop cookcli-test
    docker rm cookcli-test
    exit 1
}

# Publish function - builds and pushes multi-arch image to Docker Hub
publish() {
    log_info "Publishing ${IMAGE_NAME} to Docker Hub"

    # Resolve version for tagging
    if [ "${VERSION}" = "latest" ]; then
        log_info "Fetching latest CookCLI version for tagging..."
        RESOLVED_VERSION=$(curl -s https://api.github.com/repos/cooklang/cookcli/releases/latest | jq -r '.tag_name' | sed 's/^v//')
        log_info "Latest version: ${RESOLVED_VERSION}"
    else
        RESOLVED_VERSION="${VERSION}"
    fi

    # Check if logged in
    if ! docker info 2>/dev/null | grep -q "Username"; then
        log_error "Not logged in to Docker Hub. Please run: docker login"
        exit 1
    fi

    log_info "Building and pushing multi-architecture image..."

    # Create buildx builder if not exists
    if ! docker buildx inspect multiarch-builder > /dev/null 2>&1; then
        log_info "Creating buildx builder..."
        docker buildx create --name multiarch-builder --use
        docker buildx inspect --bootstrap
    else
        docker buildx use multiarch-builder
    fi

    # Extract version tags
    MAJOR=$(echo ${RESOLVED_VERSION} | cut -d. -f1)
    MINOR=$(echo ${RESOLVED_VERSION} | cut -d. -f1-2)

    # Build and push
    docker buildx build \
        --platform "${PLATFORMS}" \
        --build-arg VERSION="${RESOLVED_VERSION}" \
        -t "${IMAGE_NAME}:${RESOLVED_VERSION}" \
        -t "${IMAGE_NAME}:${MINOR}" \
        -t "${IMAGE_NAME}:${MAJOR}" \
        -t "${IMAGE_NAME}:latest" \
        --push \
        -f Dockerfile \
        .

    log_info "Successfully published to Docker Hub!"
    log_info "Available at: https://hub.docker.com/r/${IMAGE_NAME}"
    log_info "Tags: ${RESOLVED_VERSION}, ${MINOR}, ${MAJOR}, latest"
}

# Show usage
usage() {
    echo "Usage: $0 {build|test|publish} [VERSION]"
    echo ""
    echo "Commands:"
    echo "  build   - Build image for local architecture only (fast, for development)"
    echo "  test    - Build and test the image locally with sample recipe"
    echo "  publish - Build and push multi-architecture image to Docker Hub (amd64 + arm64)"
    echo ""
    echo "Environment variables:"
    echo "  VERSION - CookCLI version to build (default: latest - auto-fetches from GitHub)"
    echo ""
    echo "Examples:"
    echo "  $0 build                    # Build with latest version from GitHub"
    echo "  VERSION=0.18.1 $0 build     # Build specific version"
    echo "  $0 test                     # Test with latest version"
    echo "  $0 publish                  # Build multi-arch with latest and push to Docker Hub"
    echo "  VERSION=0.18.0 $0 publish   # Publish specific version"
    exit 1
}

# Main script
if [ $# -eq 0 ]; then
    usage
fi

case "$1" in
    build)
        build
        ;;
    test)
        test
        ;;
    publish)
        publish
        ;;
    *)
        log_error "Unknown command: $1"
        usage
        ;;
esac
