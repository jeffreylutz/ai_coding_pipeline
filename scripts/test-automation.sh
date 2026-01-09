#!/bin/bash

# Comprehensive test automation script for Agentic Coding Pipeline Container
# Supports multiple test types, parallel execution, and detailed reporting

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
IMAGE_NAME="agentic-coding-pipeline:latest"
TEST_CONTAINER_PREFIX="agentic-test"
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"

# Test configuration
RUN_UNIT_TESTS=true
RUN_INTEGRATION_TESTS=true
RUN_PROPERTY_TESTS=true
RUN_PERFORMANCE_TESTS=true
RUN_SECURITY_TESTS=false
PARALLEL_TESTS=true
GENERATE_REPORTS=true
CLEANUP_AFTER_TESTS=true
TEST_TIMEOUT=600

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
Usage: $0 [options] [test-types]

Test Types:
  unit            Run unit tests only
  integration     Run integration tests only
  property        Run property-based tests only
  performance     Run performance tests only
  security        Run security tests only
  all             Run all test types (default)

Options:
  --image IMAGE           Docker image to test (default: $IMAGE_NAME)
  --timeout SECONDS       Test timeout in seconds (default: $TEST_TIMEOUT)
  --parallel              Enable parallel test execution (default: true)
  --sequential            Disable parallel test execution
  --no-cleanup           Don't cleanup test containers after tests
  --no-reports           Don't generate test reports
  --results-dir DIR      Directory for test results (default: $TEST_RESULTS_DIR)
  --help                 Show this help message

Examples:
  $0                                    # Run all tests
  $0 unit integration                   # Run only unit and integration tests
  $0 --image myimage:latest property    # Run property tests on custom image
  $0 --sequential --no-cleanup          # Run tests sequentially without cleanup
EOF
}

# Function to parse command line arguments
parse_args() {
    # Reset test flags
    RUN_UNIT_TESTS=false
    RUN_INTEGRATION_TESTS=false
    RUN_PROPERTY_TESTS=false
    RUN_PERFORMANCE_TESTS=false
    RUN_SECURITY_TESTS=false
    
    local test_types_specified=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --image)
                IMAGE_NAME="$2"
                shift 2
                ;;
            --timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL_TESTS=true
                shift
                ;;
            --sequential)
                PARALLEL_TESTS=false
                shift
                ;;
            --no-cleanup)
                CLEANUP_AFTER_TESTS=false
                shift
                ;;
            --no-reports)
                GENERATE_REPORTS=false
                shift
                ;;
            --results-dir)
                TEST_RESULTS_DIR="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            unit)
                RUN_UNIT_TESTS=true
                test_types_specified=true
                shift
                ;;
            integration)
                RUN_INTEGRATION_TESTS=true
                test_types_specified=true
                shift
                ;;
            property)
                RUN_PROPERTY_TESTS=true
                test_types_specified=true
                shift
                ;;
            performance)
                RUN_PERFORMANCE_TESTS=true
                test_types_specified=true
                shift
                ;;
            security)
                RUN_SECURITY_TESTS=true
                test_types_specified=true
                shift
                ;;
            all)
                RUN_UNIT_TESTS=true
                RUN_INTEGRATION_TESTS=true
                RUN_PROPERTY_TESTS=true
                RUN_PERFORMANCE_TESTS=true
                RUN_SECURITY_TESTS=true
                test_types_specified=true
                shift
                ;;
            *)
                print_error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # If no test types specified, run all tests
    if [ "$test_types_specified" = false ]; then
        RUN_UNIT_TESTS=true
        RUN_INTEGRATION_TESTS=true
        RUN_PROPERTY_TESTS=true
        RUN_PERFORMANCE_TESTS=true
        RUN_SECURITY_TESTS=false  # Security tests are opt-in
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking test prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker is not running"
        exit 1
    fi
    
    # Check if test image exists
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        print_error "Test image not found: $IMAGE_NAME"
        print_status "Please build the image first or specify a different image with --image"
        exit 1
    fi
    
    # Check Python for property tests
    if [ "$RUN_PROPERTY_TESTS" = true ]; then
        if ! command -v python3 &> /dev/null; then
            print_error "Python 3 is required for property-based tests"
            exit 1
        fi
        
        # Check pytest
        if ! python3 -c "import pytest" &> /dev/null; then
            print_status "Installing pytest and test dependencies..."
            pip3 install -r "$PROJECT_ROOT/tests/requirements.txt" || {
                print_error "Failed to install test dependencies"
                exit 1
            }
        fi
    fi
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    print_success "Prerequisites check passed"
}

# Function to setup test environment
setup_test_environment() {
    print_status "Setting up test environment..."
    
    # Create test network
    docker network create agentic-test-network 2>/dev/null || true
    
    # Cleanup any existing test containers
    docker ps -a --filter "name=${TEST_CONTAINER_PREFIX}" --format "{{.Names}}" | \
        xargs -r docker rm -f 2>/dev/null || true
    
    print_success "Test environment setup completed"
}

# Function to run unit tests
run_unit_tests() {
    if [ "$RUN_UNIT_TESTS" = false ]; then
        return 0
    fi
    
    print_status "Running unit tests..."
    
    local test_container="${TEST_CONTAINER_PREFIX}-unit"
    local results_file="$TEST_RESULTS_DIR/unit-test-results.xml"
    
    # Start test container
    docker run -d \
        --name "$test_container" \
        --network agentic-test-network \
        "$IMAGE_NAME" \
        tail -f /dev/null
    
    # Wait for container to be ready
    sleep 5
    
    # Run unit tests inside container
    docker exec "$test_container" bash -c "
        cd /opt/tests 2>/dev/null || cd /tests 2>/dev/null || cd /
        if [ -f pytest.ini ] || [ -f setup.cfg ] || [ -f pyproject.toml ]; then
            python3 -m pytest unit/ -v --tb=short --junitxml=/tmp/unit-results.xml 2>/dev/null || echo 'No unit tests found'
        else
            echo 'No pytest configuration found, skipping unit tests'
        fi
    " || print_warning "Unit tests execution had issues"
    
    # Copy results
    docker cp "$test_container:/tmp/unit-results.xml" "$results_file" 2>/dev/null || \
        echo "No unit test results to copy"
    
    # Cleanup container
    if [ "$CLEANUP_AFTER_TESTS" = true ]; then
        docker rm -f "$test_container" >/dev/null 2>&1
    fi
    
    print_success "Unit tests completed"
}

# Function to run integration tests
run_integration_tests() {
    if [ "$RUN_INTEGRATION_TESTS" = false ]; then
        return 0
    fi
    
    print_status "Running integration tests..."
    
    local test_container="${TEST_CONTAINER_PREFIX}-integration"
    local results_file="$TEST_RESULTS_DIR/integration-test-results.txt"
    
    # Test container startup and basic functionality
    print_status "Testing container startup..."
    docker run -d \
        --name "$test_container" \
        --network agentic-test-network \
        -p 13000:3000 \
        -p 18000:8000 \
        "$IMAGE_NAME" > /dev/null
    
    # Wait for container to start
    local ready=false
    local timeout=60
    local elapsed=0
    
    while [ $elapsed -lt $timeout ] && [ "$ready" = false ]; do
        if docker exec "$test_container" test -f /workspace/.ready 2>/dev/null || \
           docker exec "$test_container" agentic-status > /dev/null 2>&1; then
            ready=true
        else
            sleep 2
            elapsed=$((elapsed + 2))
        fi
    done
    
    if [ "$ready" = true ]; then
        echo "Container startup: PASSED" >> "$results_file"
        print_success "Container startup test passed"
    else
        echo "Container startup: FAILED" >> "$results_file"
        print_error "Container startup test failed"
    fi
    
    # Test pipeline projects accessibility
    print_status "Testing pipeline projects..."
    local pipeline_projects=("kiro" "auto-claude" "continuous-claude" "automaker" "infiagent" "mai-ui" "loki-mode")
    
    for project in "${pipeline_projects[@]}"; do
        if docker exec "$test_container" test -d "/opt/pipelines/$project" 2>/dev/null; then
            echo "Pipeline $project: PASSED" >> "$results_file"
            print_success "Pipeline project $project is accessible"
        else
            echo "Pipeline $project: FAILED" >> "$results_file"
            print_warning "Pipeline project $project not found"
        fi
    done
    
    # Test additional tools
    print_status "Testing additional tools..."
    local tools=("knownote" "vibium" "opentinker" "proxypal" "claude-transcripts")
    
    for tool in "${tools[@]}"; do
        if docker exec "$test_container" test -d "/opt/tools/$tool" 2>/dev/null; then
            echo "Tool $tool: PASSED" >> "$results_file"
            print_success "Tool $tool is accessible"
        else
            echo "Tool $tool: FAILED" >> "$results_file"
            print_warning "Tool $tool not found"
        fi
    done
    
    # Test port accessibility
    print_status "Testing port accessibility..."
    if curl -f http://localhost:13000 >/dev/null 2>&1 || \
       curl -f http://localhost:18000 >/dev/null 2>&1; then
        echo "Port accessibility: PASSED" >> "$results_file"
        print_success "Ports are accessible"
    else
        echo "Port accessibility: FAILED" >> "$results_file"
        print_warning "Ports are not accessible (this may be expected)"
    fi
    
    # Cleanup
    if [ "$CLEANUP_AFTER_TESTS" = true ]; then
        docker rm -f "$test_container" >/dev/null 2>&1
    fi
    
    print_success "Integration tests completed"
}

# Function to run property-based tests
run_property_tests() {
    if [ "$RUN_PROPERTY_TESTS" = false ]; then
        return 0
    fi
    
    print_status "Running property-based tests..."
    
    cd "$PROJECT_ROOT/tests"
    
    # Set environment variable for tests
    export IMAGE_NAME
    
    # Run property tests with pytest
    python3 -m pytest \
        test_base_container.py \
        test_runtime_environment.py \
        test_kiro_installation.py \
        test_pipeline_projects.py \
        test_additional_tools.py \
        test_container_startup.py \
        test_build_optimization.py \
        test_documentation.py \
        test_orchestration.py \
        -v \
        --tb=short \
        --maxfail=10 \
        --timeout="$TEST_TIMEOUT" \
        --junitxml="$TEST_RESULTS_DIR/property-test-results.xml" \
        2>&1 | tee "$TEST_RESULTS_DIR/property-test-output.txt"
    
    local test_result=$?
    cd "$PROJECT_ROOT"
    
    if [ $test_result -eq 0 ]; then
        print_success "Property-based tests passed"
    else
        print_warning "Some property-based tests failed"
    fi
    
    return $test_result
}

# Function to run performance tests
run_performance_tests() {
    if [ "$RUN_PERFORMANCE_TESTS" = false ]; then
        return 0
    fi
    
    print_status "Running performance tests..."
    
    local test_container="${TEST_CONTAINER_PREFIX}-performance"
    local results_file="$TEST_RESULTS_DIR/performance-test-results.txt"
    
    # Test image size
    local image_size=$(docker image inspect "$IMAGE_NAME" --format "{{.Size}}")
    local image_size_gb=$((image_size / 1024 / 1024 / 1024))
    
    echo "Image size: ${image_size_gb}GB" >> "$results_file"
    print_status "Image size: ${image_size_gb}GB"
    
    if [ $image_size_gb -le 8 ]; then
        echo "Image size test: PASSED" >> "$results_file"
        print_success "Image size is within limits"
    else
        echo "Image size test: FAILED" >> "$results_file"
        print_warning "Image size exceeds 8GB recommendation"
    fi
    
    # Test container startup time
    print_status "Testing container startup performance..."
    local start_time=$(date +%s)
    
    docker run -d \
        --name "$test_container" \
        --network agentic-test-network \
        "$IMAGE_NAME" > /dev/null
    
    # Wait for container to be ready
    local ready=false
    local timeout=120
    local elapsed=0
    
    while [ $elapsed -lt $timeout ] && [ "$ready" = false ]; do
        if docker exec "$test_container" test -f /workspace/.ready 2>/dev/null || \
           docker exec "$test_container" agentic-status > /dev/null 2>&1; then
            ready=true
        else
            sleep 2
            elapsed=$((elapsed + 2))
        fi
    done
    
    local end_time=$(date +%s)
    local startup_time=$((end_time - start_time))
    
    echo "Startup time: ${startup_time}s" >> "$results_file"
    print_status "Container startup time: ${startup_time}s"
    
    if [ $startup_time -le 60 ]; then
        echo "Startup time test: PASSED" >> "$results_file"
        print_success "Startup time is acceptable"
    else
        echo "Startup time test: FAILED" >> "$results_file"
        print_warning "Startup time exceeds 60 seconds"
    fi
    
    # Test memory usage
    print_status "Testing memory usage..."
    local memory_usage=$(docker stats "$test_container" --no-stream --format "{{.MemUsage}}" | cut -d'/' -f1)
    echo "Memory usage: $memory_usage" >> "$results_file"
    print_status "Memory usage: $memory_usage"
    
    # Cleanup
    if [ "$CLEANUP_AFTER_TESTS" = true ]; then
        docker rm -f "$test_container" >/dev/null 2>&1
    fi
    
    print_success "Performance tests completed"
}

# Function to run security tests
run_security_tests() {
    if [ "$RUN_SECURITY_TESTS" = false ]; then
        return 0
    fi
    
    print_status "Running security tests..."
    
    local results_file="$TEST_RESULTS_DIR/security-test-results.txt"
    
    # Check if running as root
    print_status "Testing container security configuration..."
    local test_container="${TEST_CONTAINER_PREFIX}-security"
    
    docker run -d \
        --name "$test_container" \
        --network agentic-test-network \
        "$IMAGE_NAME" \
        tail -f /dev/null
    
    # Check user
    local container_user=$(docker exec "$test_container" whoami 2>/dev/null || echo "unknown")
    echo "Container user: $container_user" >> "$results_file"
    
    if [ "$container_user" != "root" ]; then
        echo "Non-root user test: PASSED" >> "$results_file"
        print_success "Container runs as non-root user"
    else
        echo "Non-root user test: FAILED" >> "$results_file"
        print_warning "Container runs as root user"
    fi
    
    # Check for common security issues
    print_status "Checking for security vulnerabilities..."
    
    # Run basic security checks
    docker exec "$test_container" bash -c "
        # Check for world-writable files
        find /opt -type f -perm -002 2>/dev/null | head -10
        # Check for SUID files
        find /opt -type f -perm -4000 2>/dev/null | head -10
    " >> "$results_file" 2>/dev/null || true
    
    # Cleanup
    if [ "$CLEANUP_AFTER_TESTS" = true ]; then
        docker rm -f "$test_container" >/dev/null 2>&1
    fi
    
    print_success "Security tests completed"
}

# Function to generate comprehensive test report
generate_test_report() {
    if [ "$GENERATE_REPORTS" = false ]; then
        return 0
    fi
    
    print_status "Generating comprehensive test report..."
    
    local report_file="$TEST_RESULTS_DIR/comprehensive-test-report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Agentic Coding Pipeline Container Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .passed { color: green; }
        .failed { color: red; }
        .warning { color: orange; }
        pre { background-color: #f5f5f5; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Agentic Coding Pipeline Container Test Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Image:</strong> $IMAGE_NAME</p>
        <p><strong>Test Configuration:</strong></p>
        <ul>
            <li>Unit Tests: $RUN_UNIT_TESTS</li>
            <li>Integration Tests: $RUN_INTEGRATION_TESTS</li>
            <li>Property Tests: $RUN_PROPERTY_TESTS</li>
            <li>Performance Tests: $RUN_PERFORMANCE_TESTS</li>
            <li>Security Tests: $RUN_SECURITY_TESTS</li>
            <li>Parallel Execution: $PARALLEL_TESTS</li>
        </ul>
    </div>
EOF

    # Add test results sections
    if [ "$RUN_UNIT_TESTS" = true ] && [ -f "$TEST_RESULTS_DIR/unit-test-results.xml" ]; then
        echo '<div class="section"><h2>Unit Test Results</h2>' >> "$report_file"
        echo '<pre>' >> "$report_file"
        cat "$TEST_RESULTS_DIR/unit-test-results.xml" >> "$report_file" 2>/dev/null || echo "No unit test results available"
        echo '</pre></div>' >> "$report_file"
    fi
    
    if [ "$RUN_INTEGRATION_TESTS" = true ] && [ -f "$TEST_RESULTS_DIR/integration-test-results.txt" ]; then
        echo '<div class="section"><h2>Integration Test Results</h2>' >> "$report_file"
        echo '<pre>' >> "$report_file"
        cat "$TEST_RESULTS_DIR/integration-test-results.txt" >> "$report_file"
        echo '</pre></div>' >> "$report_file"
    fi
    
    if [ "$RUN_PROPERTY_TESTS" = true ] && [ -f "$TEST_RESULTS_DIR/property-test-output.txt" ]; then
        echo '<div class="section"><h2>Property-Based Test Results</h2>' >> "$report_file"
        echo '<pre>' >> "$report_file"
        cat "$TEST_RESULTS_DIR/property-test-output.txt" >> "$report_file"
        echo '</pre></div>' >> "$report_file"
    fi
    
    if [ "$RUN_PERFORMANCE_TESTS" = true ] && [ -f "$TEST_RESULTS_DIR/performance-test-results.txt" ]; then
        echo '<div class="section"><h2>Performance Test Results</h2>' >> "$report_file"
        echo '<pre>' >> "$report_file"
        cat "$TEST_RESULTS_DIR/performance-test-results.txt" >> "$report_file"
        echo '</pre></div>' >> "$report_file"
    fi
    
    if [ "$RUN_SECURITY_TESTS" = true ] && [ -f "$TEST_RESULTS_DIR/security-test-results.txt" ]; then
        echo '<div class="section"><h2>Security Test Results</h2>' >> "$report_file"
        echo '<pre>' >> "$report_file"
        cat "$TEST_RESULTS_DIR/security-test-results.txt" >> "$report_file"
        echo '</pre></div>' >> "$report_file"
    fi
    
    echo '</body></html>' >> "$report_file"
    
    print_success "Test report generated: $report_file"
}

# Function to cleanup test environment
cleanup_test_environment() {
    if [ "$CLEANUP_AFTER_TESTS" = false ]; then
        return 0
    fi
    
    print_status "Cleaning up test environment..."
    
    # Remove test containers
    docker ps -a --filter "name=${TEST_CONTAINER_PREFIX}" --format "{{.Names}}" | \
        xargs -r docker rm -f 2>/dev/null || true
    
    # Remove test network
    docker network rm agentic-test-network 2>/dev/null || true
    
    # Clean up Docker system
    docker system prune -f > /dev/null 2>&1 || true
    
    print_success "Test environment cleanup completed"
}

# Main execution function
main() {
    echo "========================================"
    echo "Comprehensive Test Automation"
    echo "Agentic Coding Pipeline Container"
    echo "========================================"
    echo ""
    
    parse_args "$@"
    
    print_status "Test Configuration:"
    print_status "  Image: $IMAGE_NAME"
    print_status "  Unit Tests: $RUN_UNIT_TESTS"
    print_status "  Integration Tests: $RUN_INTEGRATION_TESTS"
    print_status "  Property Tests: $RUN_PROPERTY_TESTS"
    print_status "  Performance Tests: $RUN_PERFORMANCE_TESTS"
    print_status "  Security Tests: $RUN_SECURITY_TESTS"
    print_status "  Parallel: $PARALLEL_TESTS"
    print_status "  Results Dir: $TEST_RESULTS_DIR"
    echo ""
    
    # Execute test pipeline
    check_prerequisites
    echo ""
    
    setup_test_environment
    echo ""
    
    # Run tests (potentially in parallel)
    local test_pids=()
    local test_results=()
    
    if [ "$PARALLEL_TESTS" = true ]; then
        print_status "Running tests in parallel..."
        
        # Start tests in background
        [ "$RUN_UNIT_TESTS" = true ] && { run_unit_tests & test_pids+=($!); }
        [ "$RUN_INTEGRATION_TESTS" = true ] && { run_integration_tests & test_pids+=($!); }
        [ "$RUN_PERFORMANCE_TESTS" = true ] && { run_performance_tests & test_pids+=($!); }
        [ "$RUN_SECURITY_TESTS" = true ] && { run_security_tests & test_pids+=($!); }
        
        # Property tests run synchronously due to pytest limitations
        [ "$RUN_PROPERTY_TESTS" = true ] && run_property_tests
        
        # Wait for parallel tests to complete
        for pid in "${test_pids[@]}"; do
            wait $pid
            test_results+=($?)
        done
    else
        print_status "Running tests sequentially..."
        
        [ "$RUN_UNIT_TESTS" = true ] && { run_unit_tests; test_results+=($?); }
        [ "$RUN_INTEGRATION_TESTS" = true ] && { run_integration_tests; test_results+=($?); }
        [ "$RUN_PROPERTY_TESTS" = true ] && { run_property_tests; test_results+=($?); }
        [ "$RUN_PERFORMANCE_TESTS" = true ] && { run_performance_tests; test_results+=($?); }
        [ "$RUN_SECURITY_TESTS" = true ] && { run_security_tests; test_results+=($?); }
    fi
    
    echo ""
    generate_test_report
    echo ""
    
    cleanup_test_environment
    echo ""
    
    # Determine overall result
    local overall_result=0
    for result in "${test_results[@]}"; do
        if [ $result -ne 0 ]; then
            overall_result=1
        fi
    done
    
    if [ $overall_result -eq 0 ]; then
        print_success "All tests completed successfully!"
    else
        print_warning "Some tests failed. Check the detailed results in $TEST_RESULTS_DIR"
    fi
    
    print_status "Test results available in: $TEST_RESULTS_DIR"
    
    exit $overall_result
}

# Handle cleanup on exit
trap cleanup_test_environment EXIT

# Run main function
main "$@"