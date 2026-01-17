#!/bin/bash

# Build script for Agentic Coding Pipeline Base Container
# This script builds only the base stage of the Docker container (Ubuntu + Desktop Environment)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="agentic-coding-base"
IMAGE_TAG="latest"
DOCKERFILE="Dockerfile"
BUILD_TARGET="base"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi

    # Check if Dockerfile exists
    if [ ! -f "$DOCKERFILE" ]; then
        print_error "Dockerfile not found in current directory."
        exit 1
    fi

    print_success "Prerequisites check passed."
}

# Function to build the Docker image
build_image() {
    print_status "Building Docker image (base stage only): $IMAGE_NAME:$IMAGE_TAG"
    print_status "Target stage: $BUILD_TARGET"
    print_status "This may take several minutes..."

    # Build with BuildKit targeting the base stage only
    DOCKER_BUILDKIT=1 docker build \
        --target "$BUILD_TARGET" \
        --tag "$IMAGE_NAME:$IMAGE_TAG" \
        --no-cache \
        --progress=plain \
        --file "$DOCKERFILE" \
        .

    if [ $? -eq 0 ]; then
        print_success "Docker base image built successfully!"
    else
        print_error "Docker base image build failed!"
        exit 1
    fi
}

# Function to verify the built image
verify_image() {
    print_status "Verifying built image..."

    # Check if image exists
    if docker image inspect "$IMAGE_NAME:$IMAGE_TAG" &> /dev/null; then
        print_success "Image verification passed."

        # Display image information
        echo ""
        print_status "Image Information:"
        docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format "Size: {{.Size}} bytes"
        docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format "Created: {{.Created}}"
        docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format "Architecture: {{.Architecture}}"

        # Display image size in human-readable format
        IMAGE_SIZE=$(docker image inspect "$IMAGE_NAME:$IMAGE_TAG" --format "{{.Size}}")
        IMAGE_SIZE_MB=$((IMAGE_SIZE / 1024 / 1024))
        IMAGE_SIZE_GB=$((IMAGE_SIZE_MB / 1024))

        if [ $IMAGE_SIZE_GB -gt 0 ]; then
            print_status "Image size: ${IMAGE_SIZE_GB}GB (${IMAGE_SIZE_MB}MB)"
        else
            print_status "Image size: ${IMAGE_SIZE_MB}MB"
        fi

        # Check if size is reasonable (base should be smaller than full image)
        if [ $IMAGE_SIZE_GB -gt 4 ]; then
            print_warning "Base image size exceeds 4GB. This is larger than expected."
        fi

    else
        print_error "Image verification failed!"
        exit 1
    fi
}

# Function to display usage instructions
show_usage() {
    echo ""
    print_success "Build completed successfully!"
    echo ""
    print_status "Usage Instructions:"
    echo "  1. Run the container (recommended):"
    echo "     ./run-base.sh"
    echo ""
    echo "  2. Run manually with docker:"
    echo "     docker run -it --rm \\"
    echo "       -p 5901:5901 -p 6080:6080 \\"
    echo "       -v \$(pwd)/workspace:/workspace \\"
    echo "       $IMAGE_NAME:$IMAGE_TAG"
    echo ""
    echo "  3. Access the container:"
    echo "     docker exec -it agentic-base-container bash"
    echo ""
    echo "  4. Access desktop environment:"
    echo "     VNC: localhost:5901 (password: ubuntu)"
    echo "     NoVNC: http://localhost:6080/vnc.html"
    echo ""
    print_status "The base image includes:"
    echo "  - Ubuntu 24.04 LTS"
    echo "  - IceWM desktop environment"
    echo "  - VNC and NoVNC servers"
    echo "  - Essential development tools"
    echo ""
    print_status "To build the full image with all AI frameworks, use ./build.sh instead"
}

# Main execution
main() {
    echo "========================================"
    echo "Agentic Coding Pipeline - Base Container Build"
    echo "========================================"
    echo ""

    check_prerequisites
    echo ""

    build_image
    echo ""

    verify_image
    echo ""

    show_usage

    # Start the container
    ./run-base.sh

    which say && say "Build completed"
}

# Run main function
main "$@"
