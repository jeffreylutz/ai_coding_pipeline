#!/bin/bash

# Advanced build automation script for Agentic Coding Pipeline Container
# Supports multi-platform builds, caching, and automated testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="agentic-coding-pipeline"
DEFAULT_TAG="latest"
DOCKERFILE="Dockerfile"
BUILD_CONTEXT="$PROJECT_ROOT"

# Build configuration
PLATFORMS="linux/amd64,linux/arm64"
CACHE_TYPE="registry"
REGISTRY="ghcr.io"
PUSH_TO_REGISTRY=false
RUN_TESTS=true
PARALLEL_BUILDS=true
BUILD_ARGS=""

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

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [options]

Options:
  --tag TAG               Docker image tag (default: $DEFAULT_TAG)
  --platforms PLATFORMS   Target platforms (default: $PLATFORMS)
  --push                  Push to registry after build
  --registry REGISTRY     Container registry (default: $REGISTRY)
  --no-cache             Disable build cache
  --no-tests             Skip running tests after build
  --build-arg ARG=VALUE  Pass build argument to Docker
  --parallel             Enable parallel builds (default: true)
  --sequential           Disable parallel builds
  --help                 Show this help message

Examples:
  $0 --tag v1.2.3 --push
  $0 --platforms linux/amd64 --no-tests
  $0 --build-arg USERNAME=developer --build-arg USER_UID=1001
EOF
}

# Function to parse command line arguments
parse_args() {
    TAG="$DEFAULT_TAG"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tag)
                TAG="$2"
                shift 2
                ;;
            --platforms)
                PLATFORMS="$2"
                shift 2
                ;;
            --push)
                PUSH_TO_REGISTRY=true
                shift
                ;;
            --registry)
                REGISTRY="$2"
                shift 2
                ;;
            --no-cache)
                CACHE_TYPE="none"
                shift
                ;;
            --no-tests)
                RUN_TESTS=false
                shift
                ;;
            --build-arg)
                BUILD_ARGS="$BUILD_ARGS --build-arg $2"
                shift 2
                ;;
            --parallel)
                PARALLEL_BUILDS=true
                shift
                ;;
            --sequential)
                PARALLEL_BUILDS=false
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking build prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    # Check Docker Buildx
    if ! docker buildx version &> /dev/null; then
        print_error "Docker Buildx is not available"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running"
        exit 1
    fi
    
    # Check Dockerfile
    if [ ! -f "$BUILD_CONTEXT/$DOCKERFILE" ]; then
        print_error "Dockerfile not found at $BUILD_CONTEXT/$DOCKERFILE"
        exit 1
    fi
    
    # Check for multi-platform support if needed
    if [[ "$PLATFORMS" == *","* ]]; then
        if ! docker buildx ls | grep -q "docker-container"; then
            print_status "Creating buildx builder for multi-platform support..."
            docker buildx create --name multiplatform --driver docker-container --use
            docker buildx inspect --bootstrap
        fi
    fi
    
    print_success "Prerequisites check passed"
}

# Function to setup build cache
setup_build_cache() {
    print_status "Setting up build cache..."
    
    case "$CACHE_TYPE" in
        registry)
            CACHE_FROM="--cache-from type=registry,ref=${REGISTRY}/${IMAGE_NAME}:cache"
            CACHE_TO="--cache-to type=registry,ref=${REGISTRY}/${IMAGE_NAME}:cache,mode=max"
            ;;
        local)
            CACHE_FROM="--cache-from type=local,src=/tmp/.buildx-cache"
            CACHE_TO="--cache-to type=local,dest=/tmp/.buildx-cache-new,mode=max"
            ;;
        none)
            CACHE_FROM=""
            CACHE_TO=""
            ;;
        *)
            print_warning "Unknown cache type: $CACHE_TYPE. Disabling cache."
            CACHE_FROM=""
            CACHE_TO=""
            ;;
    esac
    
    print_success "Build cache configured: $CACHE_TYPE"
}

# Function to validate Dockerfile
validate_dockerfile() {
    print_status "Validating Dockerfile..."
    
    # Check Dockerfile syntax with hadolint if available
    if command -v hadolint &> /dev/null; then
        print_status "Running hadolint validation..."
        hadolint "$BUILD_CONTEXT/$DOCKERFILE" || {
            print_warning "Hadolint found issues in Dockerfile"
        }
    else
        print_warning "hadolint not found. Skipping Dockerfile linting."
    fi
    
    # Basic Docker build dry-run
    docker build --dry-run "$BUILD_CONTEXT" > /dev/null 2>&1 || {
        print_error "Dockerfile syntax validation failed"
        exit 1
    }
    
    print_success "Dockerfile validation passed"
}

# Function to build Docker image
build_image() {
    print_status "Building Docker image..."
    print_status "Image: $IMAGE_NAME:$TAG"
    print_status "Platforms: $PLATFORMS"
    print_status "Context: $BUILD_CONTEXT"
    
    # Prepare build command
    local build_cmd="docker buildx build"
    
    # Add platforms
    build_cmd="$build_cmd --platform $PLATFORMS"
    
    # Add cache options
    if [ -n "$CACHE_FROM" ]; then
        build_cmd="$build_cmd $CACHE_FROM"
    fi
    if [ -n "$CACHE_TO" ]; then
        build_cmd="$build_cmd $CACHE_TO"
    fi
    
    # Add build arguments
    if [ -n "$BUILD_ARGS" ]; then
        build_cmd="$build_cmd $BUILD_ARGS"
    fi
    
    # Add tags
    build_cmd="$build_cmd --tag $IMAGE_NAME:$TAG"
    if [ "$PUSH_TO_REGISTRY" = true ]; then
        build_cmd="$build_cmd --tag $REGISTRY/$IMAGE_NAME:$TAG"
    fi
    
    # Add push option
    if [ "$PUSH_TO_REGISTRY" = true ]; then
        build_cmd="$build_cmd --push"
    else
        build_cmd="$build_cmd --load"
    fi
    
    # Add build context and Dockerfile
    build_cmd="$build_cmd --file $BUILD_CONTEXT/$DOCKERFILE $BUILD_CONTEXT"
    
    # Execute build
    print_status "Executing: $build_cmd"
    
    if [ "$PARALLEL_BUILDS" = true ]; then
        # Use BuildKit for parallel builds
        DOCKER_BUILDKIT=1 $build_cmd
    else
        # Sequential build
        $build_cmd
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Docker image built successfully"
    else
        print_error "Docker image build failed"
        exit 1
    fi
    
    # Move cache if using local cache
    if [ "$CACHE_TYPE" = "local" ] && [ -d "/tmp/.buildx-cache-new" ]; then
        rm -rf /tmp/.buildx-cache
        mv /tmp/.buildx-cache-new /tmp/.buildx-cache
    fi
}

# Function to verify built image
verify_image() {
    print_status "Verifying built image..."
    
    # Skip verification if image was pushed to registry
    if [ "$PUSH_TO_REGISTRY" = true ]; then
        print_status "Image was pushed to registry. Skipping local verification."
        return 0
    fi
    
    # Check if image exists locally
    if docker image inspect "$IMAGE_NAME:$TAG" &> /dev/null; then
        print_success "Image verification passed"
        
        # Display image information
        local image_size=$(docker image inspect "$IMAGE_NAME:$TAG" --format "{{.Size}}")
        local image_size_mb=$((image_size / 1024 / 1024))
        local image_size_gb=$((image_size_mb / 1024))
        
        print_status "Image Information:"
        print_status "  Size: ${image_size_mb}MB (${image_size_gb}GB)"
        print_status "  Created: $(docker image inspect "$IMAGE_NAME:$TAG" --format "{{.Created}}")"
        print_status "  Architecture: $(docker image inspect "$IMAGE_NAME:$TAG" --format "{{.Architecture}}")"
        
        # Check size limits
        if [ $image_size_gb -gt 8 ]; then
            print_warning "Image size exceeds 8GB recommendation"
        else
            print_success "Image size is within acceptable limits"
        fi
    else
        print_error "Image verification failed - image not found locally"
        exit 1
    fi
}

# Function to run tests
run_tests() {
    if [ "$RUN_TESTS" = false ]; then
        print_status "Skipping tests as requested"
        return 0
    fi
    
    print_status "Running automated tests..."
    
    # Set environment variable for test script
    export IMAGE_NAME="$IMAGE_NAME:$TAG"
    
    # Run test script if it exists
    if [ -f "$PROJECT_ROOT/test.sh" ]; then
        cd "$PROJECT_ROOT"
        ./test.sh
        
        if [ $? -eq 0 ]; then
            print_success "All tests passed"
        else
            print_error "Some tests failed"
            exit 1
        fi
    else
        print_warning "Test script not found. Skipping automated tests."
    fi
}

# Function to generate build report
generate_build_report() {
    print_status "Generating build report..."
    
    local report_file="build-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
Agentic Coding Pipeline Container Build Report
Generated: $(date)
Image: $IMAGE_NAME:$TAG
Platforms: $PLATFORMS
Registry: $REGISTRY
Pushed: $PUSH_TO_REGISTRY

Build Configuration:
- Cache Type: $CACHE_TYPE
- Parallel Builds: $PARALLEL_BUILDS
- Tests Run: $RUN_TESTS
- Build Args: $BUILD_ARGS

Build Environment:
- Docker Version: $(docker --version)
- Buildx Version: $(docker buildx version)
- System: $(uname -a)

EOF

    if [ "$PUSH_TO_REGISTRY" = false ] && docker image inspect "$IMAGE_NAME:$TAG" &> /dev/null; then
        cat >> "$report_file" << EOF
Image Information:
$(docker image inspect "$IMAGE_NAME:$TAG" --format "Size: {{.Size}} bytes")
$(docker image inspect "$IMAGE_NAME:$TAG" --format "Created: {{.Created}}")
$(docker image inspect "$IMAGE_NAME:$TAG" --format "Architecture: {{.Architecture}}")
EOF
    fi
    
    print_success "Build report generated: $report_file"
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up build artifacts..."
    
    # Clean up Docker build cache if using local cache
    if [ "$CACHE_TYPE" = "local" ]; then
        rm -rf /tmp/.buildx-cache /tmp/.buildx-cache-new
    fi
    
    # Clean up dangling images
    docker image prune -f > /dev/null 2>&1 || true
    
    print_success "Cleanup completed"
}

# Main execution function
main() {
    echo "========================================"
    echo "Advanced Build Automation"
    echo "Agentic Coding Pipeline Container"
    echo "========================================"
    echo ""
    
    parse_args "$@"
    
    print_status "Build Configuration:"
    print_status "  Image: $IMAGE_NAME:$TAG"
    print_status "  Platforms: $PLATFORMS"
    print_status "  Registry: $REGISTRY"
    print_status "  Push: $PUSH_TO_REGISTRY"
    print_status "  Cache: $CACHE_TYPE"
    print_status "  Tests: $RUN_TESTS"
    print_status "  Parallel: $PARALLEL_BUILDS"
    echo ""
    
    # Execute build pipeline
    check_prerequisites
    echo ""
    
    validate_dockerfile
    echo ""
    
    setup_build_cache
    echo ""
    
    build_image
    echo ""
    
    verify_image
    echo ""
    
    run_tests
    echo ""
    
    generate_build_report
    echo ""
    
    cleanup
    echo ""
    
    print_success "Build automation completed successfully!"
    
    if [ "$PUSH_TO_REGISTRY" = true ]; then
        print_status "Image available at: $REGISTRY/$IMAGE_NAME:$TAG"
    else
        print_status "Image available locally as: $IMAGE_NAME:$TAG"
    fi
}

# Handle cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"