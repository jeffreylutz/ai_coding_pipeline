#!/bin/bash

# Deployment script for Agentic Coding Pipeline Container
# Supports multiple environments: local, staging, production

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
Usage: $0 <environment> <action> [options]

Environments:
  local       Deploy locally using Docker Compose
  staging     Deploy to staging Kubernetes cluster
  production  Deploy to production Kubernetes cluster

Actions:
  deploy      Deploy the application
  validate    Validate deployment configuration
  status      Check deployment status
  logs        Show application logs
  rollback    Rollback to previous version
  cleanup     Clean up resources

Options:
  --tag TAG           Docker image tag (default: $DEFAULT_TAG)
  --namespace NS      Kubernetes namespace (default: environment name)
  --dry-run          Show what would be deployed without actually deploying
  --force            Force deployment even if validation fails
  --help             Show this help message

Examples:
  $0 local deploy
  $0 staging deploy --tag v1.2.3
  $0 production validate --dry-run
  $0 staging status
  $0 production rollback
EOF
}

# Function to parse command line arguments
parse_args() {
    ENVIRONMENT=""
    ACTION=""
    TAG="$DEFAULT_TAG"
    NAMESPACE=""
    DRY_RUN=false
    FORCE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tag)
                TAG="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                if [ -z "$ENVIRONMENT" ]; then
                    ENVIRONMENT="$1"
                elif [ -z "$ACTION" ]; then
                    ACTION="$1"
                else
                    print_error "Unknown argument: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Set default namespace if not provided
    if [ -z "$NAMESPACE" ]; then
        NAMESPACE="$ENVIRONMENT"
    fi
    
    # Validate required arguments
    if [ -z "$ENVIRONMENT" ] || [ -z "$ACTION" ]; then
        print_error "Environment and action are required"
        show_usage
        exit 1
    fi
}

# Function to validate environment
validate_environment() {
    case "$ENVIRONMENT" in
        local|staging|production)
            print_status "Environment: $ENVIRONMENT"
            ;;
        *)
            print_error "Invalid environment: $ENVIRONMENT"
            print_error "Valid environments: local, staging, production"
            exit 1
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites for $ENVIRONMENT environment..."
    
    case "$ENVIRONMENT" in
        local)
            # Check Docker and Docker Compose
            if ! command -v docker &> /dev/null; then
                print_error "Docker is not installed"
                exit 1
            fi
            
            if ! command -v docker compose &> /dev/null; then
                print_error "Docker Compose is not installed"
                exit 1
            fi
            
            if ! docker info &> /dev/null; then
                print_error "Docker is not running"
                exit 1
            fi
            ;;
            
        staging|production)
            # Check kubectl and cluster access
            if ! command -v kubectl &> /dev/null; then
                print_error "kubectl is not installed"
                exit 1
            fi
            
            if ! kubectl cluster-info &> /dev/null; then
                print_error "Cannot connect to Kubernetes cluster"
                exit 1
            fi
            
            # Check if namespace exists
            if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
                print_warning "Namespace '$NAMESPACE' does not exist. Creating..."
                kubectl create namespace "$NAMESPACE"
            fi
            ;;
    esac
    
    print_success "Prerequisites check passed"
}

# Function to validate deployment configuration
validate_config() {
    print_status "Validating deployment configuration..."
    
    case "$ENVIRONMENT" in
        local)
            # Validate docker compose.yml
            if [ ! -f "$PROJECT_ROOT/docker compose.yml" ]; then
                print_error "docker compose.yml not found"
                exit 1
            fi
            
            docker compose -f "$PROJECT_ROOT/docker compose.yml" config --quiet
            print_success "Docker Compose configuration is valid"
            ;;
            
        staging|production)
            # Validate Kubernetes manifests
            if [ ! -f "$PROJECT_ROOT/kubernetes/deployment.yaml" ]; then
                print_error "Kubernetes deployment manifest not found"
                exit 1
            fi
            
            # Create temporary manifest with environment-specific values
            local temp_manifest="/tmp/deployment-${ENVIRONMENT}.yaml"
            sed "s/agentic-coding-pipeline:latest/${IMAGE_NAME}:${TAG}/g" \
                "$PROJECT_ROOT/kubernetes/deployment.yaml" > "$temp_manifest"
            
            kubectl apply --dry-run=client -f "$temp_manifest" -n "$NAMESPACE"
            rm -f "$temp_manifest"
            
            print_success "Kubernetes configuration is valid"
            ;;
    esac
}

# Function to deploy locally
deploy_local() {
    print_status "Deploying to local environment..."
    
    cd "$PROJECT_ROOT"
    
    # Set environment variables
    export IMAGE_TAG="$TAG"
    export COMPOSE_PROJECT_NAME="agentic-coding-pipeline"
    
    if [ "$DRY_RUN" = true ]; then
        print_status "Dry run - showing what would be deployed:"
        docker compose config
        return 0
    fi
    
    # Pull/build image if needed
    if ! docker image inspect "${IMAGE_NAME}:${TAG}" &> /dev/null; then
        print_status "Image ${IMAGE_NAME}:${TAG} not found locally. Building..."
        ./build.sh
    fi
    
    # Deploy with Docker Compose
    docker compose up -d
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    sleep 10
    
    # Check service health
    if docker compose ps | grep -q "Up"; then
        print_success "Local deployment completed successfully"
        print_status "Services are available at:"
        print_status "  - Web: http://localhost:3000"
        print_status "  - Python: http://localhost:8000"
        print_status "  - Alt Web: http://localhost:8080"
        print_status "  - Service: http://localhost:9000"
    else
        print_error "Some services failed to start"
        docker compose logs
        exit 1
    fi
}

# Function to deploy to Kubernetes
deploy_kubernetes() {
    print_status "Deploying to $ENVIRONMENT Kubernetes environment..."
    
    # Create temporary manifest with environment-specific values
    local temp_manifest="/tmp/deployment-${ENVIRONMENT}.yaml"
    
    # Replace image tag and add environment-specific configurations
    sed -e "s/agentic-coding-pipeline:latest/${IMAGE_NAME}:${TAG}/g" \
        -e "s/name: agentic-coding-pipeline/name: agentic-coding-pipeline-${ENVIRONMENT}/g" \
        -e "s/app: agentic-coding-pipeline/app: agentic-coding-pipeline-${ENVIRONMENT}/g" \
        "$PROJECT_ROOT/kubernetes/deployment.yaml" > "$temp_manifest"
    
    # Add environment-specific resource limits
    case "$ENVIRONMENT" in
        staging)
            # Reduce resources for staging
            sed -i 's/memory: "8Gi"/memory: "4Gi"/g' "$temp_manifest"
            sed -i 's/cpu: "4000m"/cpu: "2000m"/g' "$temp_manifest"
            ;;
        production)
            # Keep full resources for production
            ;;
    esac
    
    if [ "$DRY_RUN" = true ]; then
        print_status "Dry run - showing what would be deployed:"
        cat "$temp_manifest"
        rm -f "$temp_manifest"
        return 0
    fi
    
    # Apply the manifest
    kubectl apply -f "$temp_manifest" -n "$NAMESPACE"
    rm -f "$temp_manifest"
    
    # Wait for deployment to be ready
    print_status "Waiting for deployment to be ready..."
    kubectl rollout status deployment/agentic-coding-pipeline-${ENVIRONMENT} -n "$NAMESPACE" --timeout=600s
    
    # Check pod status
    if kubectl get pods -n "$NAMESPACE" -l app=agentic-coding-pipeline-${ENVIRONMENT} | grep -q "Running"; then
        print_success "Kubernetes deployment completed successfully"
        
        # Show service information
        kubectl get services -n "$NAMESPACE" -l app=agentic-coding-pipeline-${ENVIRONMENT}
    else
        print_error "Deployment failed"
        kubectl get pods -n "$NAMESPACE" -l app=agentic-coding-pipeline-${ENVIRONMENT}
        exit 1
    fi
}

# Function to check deployment status
check_status() {
    print_status "Checking deployment status for $ENVIRONMENT..."
    
    case "$ENVIRONMENT" in
        local)
            docker compose ps
            ;;
        staging|production)
            kubectl get deployments -n "$NAMESPACE" -l app=agentic-coding-pipeline-${ENVIRONMENT}
            kubectl get pods -n "$NAMESPACE" -l app=agentic-coding-pipeline-${ENVIRONMENT}
            kubectl get services -n "$NAMESPACE" -l app=agentic-coding-pipeline-${ENVIRONMENT}
            ;;
    esac
}

# Function to show logs
show_logs() {
    print_status "Showing logs for $ENVIRONMENT..."
    
    case "$ENVIRONMENT" in
        local)
            docker compose logs -f
            ;;
        staging|production)
            kubectl logs -f deployment/agentic-coding-pipeline-${ENVIRONMENT} -n "$NAMESPACE"
            ;;
    esac
}

# Function to rollback deployment
rollback_deployment() {
    print_status "Rolling back deployment in $ENVIRONMENT..."
    
    case "$ENVIRONMENT" in
        local)
            print_warning "Rollback not supported for local deployments"
            print_status "Use 'docker compose down && docker compose up -d' to restart"
            ;;
        staging|production)
            kubectl rollout undo deployment/agentic-coding-pipeline-${ENVIRONMENT} -n "$NAMESPACE"
            kubectl rollout status deployment/agentic-coding-pipeline-${ENVIRONMENT} -n "$NAMESPACE"
            print_success "Rollback completed"
            ;;
    esac
}

# Function to cleanup resources
cleanup_resources() {
    print_status "Cleaning up resources in $ENVIRONMENT..."
    
    case "$ENVIRONMENT" in
        local)
            docker compose down -v
            docker system prune -f
            print_success "Local cleanup completed"
            ;;
        staging|production)
            kubectl delete deployment agentic-coding-pipeline-${ENVIRONMENT} -n "$NAMESPACE" --ignore-not-found
            kubectl delete service agentic-coding-service -n "$NAMESPACE" --ignore-not-found
            kubectl delete pvc agentic-workspace-pvc -n "$NAMESPACE" --ignore-not-found
            kubectl delete configmap agentic-config -n "$NAMESPACE" --ignore-not-found
            print_success "Kubernetes cleanup completed"
            ;;
    esac
}

# Main execution function
main() {
    parse_args "$@"
    validate_environment
    
    print_status "Starting deployment operation..."
    print_status "Environment: $ENVIRONMENT"
    print_status "Action: $ACTION"
    print_status "Image Tag: $TAG"
    print_status "Namespace: $NAMESPACE"
    
    case "$ACTION" in
        deploy)
            check_prerequisites
            validate_config
            
            case "$ENVIRONMENT" in
                local)
                    deploy_local
                    ;;
                staging|production)
                    deploy_kubernetes
                    ;;
            esac
            ;;
            
        validate)
            check_prerequisites
            validate_config
            print_success "Validation completed successfully"
            ;;
            
        status)
            check_status
            ;;
            
        logs)
            show_logs
            ;;
            
        rollback)
            rollback_deployment
            ;;
            
        cleanup)
            cleanup_resources
            ;;
            
        *)
            print_error "Invalid action: $ACTION"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"