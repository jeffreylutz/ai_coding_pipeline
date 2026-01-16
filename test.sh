#!/bin/bash

# Test automation script for Agentic Coding Pipeline Container
# This script runs comprehensive tests to validate the container build and functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="agentic-coding-pipeline:latest"
COMPOSE_FILE="compose.yml"

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
    print_status "Checking test prerequisites..."

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi

    # Check if docker compose is available
    if ! docker compose version &> /dev/null; then
        print_error "docker compose is not available. Please install docker compose."
        exit 1
    fi

    # Check if $COMPOSE_FILE exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "$COMPOSE_FILE not found in current directory."
        exit 1
    fi

    # Check if Python is available for tests
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not available. Required for running tests."
        exit 1
    fi

    # Check if pytest is available
    if ! python3 -c "import pytest" &> /dev/null; then
        print_warning "pytest not found. Installing test dependencies..."
        pip3 install -r tests/requirements.txt
    fi

    print_success "Prerequisites check passed."
}

# Function to run Docker build tests
run_build_tests() {
    print_status "Running Docker build tests..."
    
    # Test Dockerfile syntax
    if [ -f "Dockerfile" ]; then
        print_status "Validating Dockerfile syntax..."
        # Use docker buildx to validate syntax without building
        if command -v docker-buildx &> /dev/null; then
            docker buildx build --dry-run . > /dev/null 2>&1 || {
                print_error "Dockerfile syntax validation failed"
                return 1
            }
        else
            # Fallback: just check if Dockerfile can be parsed
            docker build --no-cache --target base . > /dev/null 2>&1 || {
                print_error "Dockerfile syntax validation failed"
                return 1
            }
        fi
        print_success "Dockerfile syntax is valid"
    else
        print_error "Dockerfile not found"
        return 1
    fi
    
    # Test docker compose configuration
    if [ -f "$COMPOSE_FILE" ]; then
        print_status "Validating docker compose configuration..."
        docker compose config --quiet || {
            print_error "docker compose configuration validation failed"
            return 1
        }
        print_success "docker compose configuration is valid"
    fi
    
    return 0
}

# Function to build the container if needed
build_container_if_needed() {
    print_status "Checking if container image exists..."

    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        print_warning "Container image not found. Building with docker compose..."
        docker compose -f "$COMPOSE_FILE" build
    else
        print_success "Container image found: $IMAGE_NAME"
    fi
}

# Function to run property-based tests
run_property_tests() {
    print_status "Running property-based tests..."

    # Run all property tests with appropriate settings
    # Note: Run from project root so tests can find Dockerfile and compose.yml
    python3 -m pytest \
        tests/test_base_container.py \
        tests/test_kiro_installation.py \
        tests/test_pipeline_projects.py \
        tests/test_additional_tools.py \
        tests/test_container_startup.py \
        tests/test_orchestration.py \
        -v \
        --tb=short \
        --maxfail=5 \
        --timeout=300

    local test_result=$?

    if [ $test_result -eq 0 ]; then
        print_success "All property-based tests passed"
    else
        print_error "Some property-based tests failed"
        return 1
    fi

    return 0
}

# Function to run integration tests
run_integration_tests() {
    print_status "Running integration tests..."

    # Test container startup
    print_status "Testing container startup with docker compose..."
    docker compose -f $COMPOSE_FILE up -d > /dev/null

    # Wait for container to start
    sleep 5

    # Test basic functionality
    if docker compose -f $COMPOSE_FILE exec -T agentic-coding-pipeline agentic-status > /dev/null 2>&1; then
        print_success "Container startup and basic functionality test passed"
    else
        print_error "Container startup or basic functionality test failed"
        docker compose -f $COMPOSE_FILE logs
        docker compose -f $COMPOSE_FILE down > /dev/null 2>&1
        return 1
    fi

    # Test pipeline projects accessibility
    print_status "Testing pipeline projects accessibility..."
    for project in kiro auto-claude continuous-claude automaker infiagent mai-ui loki-mode; do
        if docker compose -f $COMPOSE_FILE exec -T agentic-coding-pipeline test -d "/opt/pipelines/$project"; then
            print_success "Pipeline project $project is accessible"
        else
            print_warning "Pipeline project $project not found"
        fi
    done

    # Test additional tools accessibility
    print_status "Testing additional tools accessibility..."
    for tool in knownote vibium opentinker proxypal claude-transcripts; do
        if docker compose -f $COMPOSE_FILE exec -T agentic-coding-pipeline test -d "/opt/tools/$tool"; then
            print_success "Tool $tool is accessible"
        else
            print_warning "Tool $tool not found"
        fi
    done

    # Cleanup
    docker compose -f $COMPOSE_FILE down > /dev/null 2>&1

    return 0
}

# Function to run performance tests
run_performance_tests() {
    print_status "Running performance tests..."

    # Test image size
    local image_size=$(docker image inspect "$IMAGE_NAME" --format "{{.Size}}")
    local image_size_gb=$((image_size / 1024 / 1024 / 1024))

    print_status "Container image size: ${image_size_gb}GB"

    if [ $image_size_gb -gt 8 ]; then
        print_warning "Container image size exceeds 8GB recommendation"
    else
        print_success "Container image size is within acceptable limits"
    fi

    # Test container startup time
    print_status "Testing container startup time with docker compose..."
    local start_time=$(date +%s)

    docker compose -f $COMPOSE_FILE up -d > /dev/null

    # Wait for container to be ready
    local ready=false
    local timeout=60
    local elapsed=0

    while [ $elapsed -lt $timeout ] && [ "$ready" = false ]; do
        if docker compose -f $COMPOSE_FILE exec -T agentic-coding-pipeline test -f /workspace/.ready 2>/dev/null || \
           docker compose -f $COMPOSE_FILE exec -T agentic-coding-pipeline agentic-status > /dev/null 2>&1; then
            ready=true
        else
            sleep 2
            elapsed=$((elapsed + 2))
        fi
    done

    local end_time=$(date +%s)
    local startup_time=$((end_time - start_time))

    print_status "Container startup time: ${startup_time} seconds"

    if [ $startup_time -gt 30 ]; then
        print_warning "Container startup time exceeds 30 seconds"
    else
        print_success "Container startup time is acceptable"
    fi

    # Cleanup
    docker compose -f $COMPOSE_FILE down > /dev/null 2>&1

    return 0
}

# Function to generate test report
generate_test_report() {
    print_status "Generating test report..."
    
    local report_file="test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
Agentic Coding Pipeline Container Test Report
Generated: $(date)
Image: $IMAGE_NAME

Test Results Summary:
- Build Tests: $build_test_result
- Property Tests: $property_test_result  
- Integration Tests: $integration_test_result
- Performance Tests: $performance_test_result

Container Information:
$(docker image inspect "$IMAGE_NAME" --format "Size: {{.Size}} bytes")
$(docker image inspect "$IMAGE_NAME" --format "Created: {{.Created}}")
$(docker image inspect "$IMAGE_NAME" --format "Architecture: {{.Architecture}}")

Test Environment:
Docker Version: $(docker --version)
System: $(uname -a)
EOF
    
    print_success "Test report generated: $report_file"
}

# Main execution
main() {
    echo "========================================"
    echo "Agentic Coding Pipeline Container Tests"
    echo "========================================"
    echo ""
    
    # Initialize test results
    build_test_result="SKIPPED"
    property_test_result="SKIPPED"
    integration_test_result="SKIPPED"
    performance_test_result="SKIPPED"
    
    # Run test phases
    check_prerequisites
    echo ""
    
    if run_build_tests; then
        build_test_result="PASSED"
    else
        build_test_result="FAILED"
        print_error "Build tests failed. Stopping test execution."
        exit 1
    fi
    echo ""
    
    build_container_if_needed
    echo ""
    
    if run_property_tests; then
        property_test_result="PASSED"
    else
        property_test_result="FAILED"
        print_warning "Property tests failed but continuing with other tests..."
    fi
    echo ""
    
    if run_integration_tests; then
        integration_test_result="PASSED"
    else
        integration_test_result="FAILED"
        print_warning "Integration tests failed but continuing with other tests..."
    fi
    echo ""
    
    if run_performance_tests; then
        performance_test_result="PASSED"
    else
        performance_test_result="FAILED"
        print_warning "Performance tests failed but continuing..."
    fi
    echo ""
    
    generate_test_report
    echo ""
    
    # Final summary
    echo "========================================"
    echo "Test Execution Summary"
    echo "========================================"
    echo "Build Tests:       $build_test_result"
    echo "Property Tests:    $property_test_result"
    echo "Integration Tests: $integration_test_result"
    echo "Performance Tests: $performance_test_result"
    echo ""
    
    # Determine overall result
    if [ "$build_test_result" = "PASSED" ] && \
       [ "$property_test_result" = "PASSED" ] && \
       [ "$integration_test_result" = "PASSED" ] && \
       [ "$performance_test_result" = "PASSED" ]; then
        print_success "All tests passed successfully!"
        exit 0
    else
        print_warning "Some tests failed. Check the results above."
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    "build")
        check_prerequisites
        run_build_tests
        ;;
    "property")
        check_prerequisites
        build_container_if_needed
        run_property_tests
        ;;
    "integration")
        check_prerequisites
        build_container_if_needed
        run_integration_tests
        ;;
    "performance")
        check_prerequisites
        build_container_if_needed
        run_performance_tests
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [build|property|integration|performance|help]"
        echo ""
        echo "Options:"
        echo "  build       Run build validation tests only"
        echo "  property    Run property-based tests only"
        echo "  integration Run integration tests only"
        echo "  performance Run performance tests only"
        echo "  help        Show this help message"
        echo ""
        echo "If no option is specified, all tests will be run."
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac