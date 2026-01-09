#!/bin/bash

# Build script for Agentic Coding Pipeline Container
# This script builds the Docker container with proper error handling and optimization

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="agentic-coding-pipeline"
IMAGE_TAG="latest"
DOCKERFILE="Dockerfile"

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
    print_status "Building Docker image: $IMAGE_NAME:$IMAGE_TAG"
    print_status "This may take several minutes..."
    
    # Build with BuildKit for better performance and caching
    DOCKER_BUILDKIT=1 docker build \
        --tag "$IMAGE_NAME:$IMAGE_TAG" \
        --file "$DOCKERFILE" \
        --progress=plain \
        --no-cache \
        .
    
    if [ $? -eq 0 ]; then
        print_success "Docker image built successfully!"
    else
        print_error "Docker image build failed!"
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
        
        # Check if size is reasonable (under 8GB as per requirements)
        if [ $IMAGE_SIZE_GB -gt 8 ]; then
            print_warning "Image size exceeds 8GB. Consider optimizing the build."
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
    echo "  1. Run with Docker:"
    echo "     docker run -it --privileged -p 3000:3000 -p 8000:8000 -p 8080:8080 -p 9000:9000 $IMAGE_NAME:$IMAGE_TAG"
    echo ""
    echo "  2. Run with Docker Compose:"
    echo "     docker-compose up -d"
    echo ""
    echo "  3. Access the container:"
    echo "     docker exec -it agentic-coding-container bash"
    echo ""
    print_status "The container includes all multi-agent coding pipeline projects and development tools."
}

# Main execution
main() {
    echo "========================================"
    echo "Agentic Coding Pipeline Container Build"
    echo "========================================"
    echo ""
    
    check_prerequisites
    echo ""
    
    build_image
    echo ""
    
    verify_image
    echo ""
    
    show_usage
}

# Run main function
main "$@"