# Makefile for Agentic Coding Pipeline Container
# Provides convenient targets for building, testing, and deploying

.PHONY: help build test deploy clean lint security docs all

# Configuration
IMAGE_NAME := agentic-coding-pipeline
IMAGE_TAG := latest
REGISTRY := ghcr.io
PLATFORMS := linux/amd64,linux/arm64

# Default target
.DEFAULT_GOAL := help

# Help target
help: ## Show this help message
	@echo "Agentic Coding Pipeline Container - Build Automation"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Configuration:"
	@echo "  IMAGE_NAME: $(IMAGE_NAME)"
	@echo "  IMAGE_TAG:  $(IMAGE_TAG)"
	@echo "  REGISTRY:   $(REGISTRY)"
	@echo "  PLATFORMS:  $(PLATFORMS)"

# Build targets
build: ## Build the Docker image locally
	@echo "Building Docker image..."
	./build.sh

build-advanced: ## Build with advanced automation script
	@echo "Building with advanced automation..."
	./scripts/build-automation.sh --tag $(IMAGE_TAG)

build-multi: ## Build multi-platform image
	@echo "Building multi-platform image..."
	./scripts/build-automation.sh --tag $(IMAGE_TAG) --platforms $(PLATFORMS)

build-push: ## Build and push to registry
	@echo "Building and pushing to registry..."
	./scripts/build-automation.sh --tag $(IMAGE_TAG) --push --registry $(REGISTRY)

# Test targets
test: ## Run all tests
	@echo "Running all tests..."
	./test.sh

test-unit: ## Run unit tests only
	@echo "Running unit tests..."
	./scripts/test-automation.sh unit

test-integration: ## Run integration tests only
	@echo "Running integration tests..."
	./scripts/test-automation.sh integration

test-property: ## Run property-based tests only
	@echo "Running property-based tests..."
	./scripts/test-automation.sh property

test-performance: ## Run performance tests only
	@echo "Running performance tests..."
	./scripts/test-automation.sh performance

test-security: ## Run security tests
	@echo "Running security tests..."
	./scripts/test-automation.sh security

test-all: ## Run comprehensive test suite
	@echo "Running comprehensive test suite..."
	./scripts/test-automation.sh all

# Deployment targets
deploy-local: ## Deploy locally with Docker Compose
	@echo "Deploying locally..."
	./scripts/deploy.sh local deploy

deploy-staging: ## Deploy to staging environment
	@echo "Deploying to staging..."
	./scripts/deploy.sh staging deploy --tag $(IMAGE_TAG)

deploy-production: ## Deploy to production environment
	@echo "Deploying to production..."
	./scripts/deploy.sh production deploy --tag $(IMAGE_TAG)

# Validation targets
validate: ## Validate all configurations
	@echo "Validating configurations..."
	./scripts/deploy.sh local validate
	./scripts/deploy.sh staging validate
	./scripts/deploy.sh production validate

validate-docker: ## Validate Docker configuration
	@echo "Validating Docker configuration..."
	docker compose config --quiet
	@echo "Docker Compose configuration is valid"

validate-k8s: ## Validate Kubernetes manifests
	@echo "Validating Kubernetes manifests..."
	kubectl apply --dry-run=client -f kubernetes/deployment.yaml
	@echo "Kubernetes manifests are valid"

# Linting targets
lint: ## Run all linting checks
	@echo "Running linting checks..."
	$(MAKE) lint-docker
	$(MAKE) lint-shell
	$(MAKE) lint-yaml

lint-docker: ## Lint Dockerfile
	@echo "Linting Dockerfile..."
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint Dockerfile; \
	else \
		echo "hadolint not found. Install it for Dockerfile linting."; \
	fi

lint-shell: ## Lint shell scripts
	@echo "Linting shell scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name "*.sh" -exec shellcheck {} \;; \
	else \
		echo "shellcheck not found. Install it for shell script linting."; \
	fi

lint-yaml: ## Lint YAML files
	@echo "Linting YAML files..."
	@if command -v yamllint >/dev/null 2>&1; then \
		find . -name "*.yml" -o -name "*.yaml" | xargs yamllint; \
	else \
		echo "yamllint not found. Install it for YAML linting."; \
	fi

# Security targets
security: ## Run security scans
	@echo "Running security scans..."
	$(MAKE) security-dockerfile
	$(MAKE) security-image

security-dockerfile: ## Scan Dockerfile for security issues
	@echo "Scanning Dockerfile for security issues..."
	@if command -v docker-bench-security >/dev/null 2>&1; then \
		docker-bench-security; \
	else \
		echo "docker-bench-security not found. Skipping Dockerfile security scan."; \
	fi

security-image: ## Scan Docker image for vulnerabilities
	@echo "Scanning Docker image for vulnerabilities..."
	@if command -v trivy >/dev/null 2>&1; then \
		trivy image $(IMAGE_NAME):$(IMAGE_TAG); \
	else \
		echo "trivy not found. Install it for image vulnerability scanning."; \
	fi

# Documentation targets
docs: ## Generate documentation
	@echo "Generating documentation..."
	@echo "Documentation is available in README.md"
	@echo "API documentation would be generated here if applicable"

docs-serve: ## Serve documentation locally
	@echo "Serving documentation locally..."
	@if command -v python3 >/dev/null 2>&1; then \
		cd docs 2>/dev/null || mkdir -p docs; \
		python3 -m http.server 8080; \
	else \
		echo "Python 3 not found. Cannot serve documentation."; \
	fi

# Cleanup targets
clean: ## Clean up build artifacts and containers
	@echo "Cleaning up..."
	$(MAKE) clean-containers
	$(MAKE) clean-images
	$(MAKE) clean-volumes
	$(MAKE) clean-networks

clean-containers: ## Remove all test containers
	@echo "Removing test containers..."
	@docker ps -a --filter "name=agentic-test" --format "{{.Names}}" | xargs -r docker rm -f 2>/dev/null || true
	@docker ps -a --filter "name=agentic-coding-container" --format "{{.Names}}" | xargs -r docker rm -f 2>/dev/null || true

clean-images: ## Remove dangling images
	@echo "Removing dangling images..."
	@docker image prune -f

clean-volumes: ## Remove unused volumes
	@echo "Removing unused volumes..."
	@docker volume prune -f

clean-networks: ## Remove unused networks
	@echo "Removing unused networks..."
	@docker network prune -f

clean-all: ## Complete cleanup including built images
	@echo "Performing complete cleanup..."
	$(MAKE) clean
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	@docker system prune -af

# Status targets
status: ## Show deployment status
	@echo "Checking deployment status..."
	./scripts/deploy.sh local status || echo "Local deployment not running"
	./scripts/deploy.sh staging status || echo "Staging deployment not found"
	./scripts/deploy.sh production status || echo "Production deployment not found"

logs: ## Show application logs
	@echo "Showing application logs..."
	./scripts/deploy.sh local logs || echo "No local deployment logs available"

# Development targets
dev: ## Start development environment
	@echo "Starting development environment..."
	docker compose -f docker compose.yml -f deployments/local/docker compose.override.yml up -d

dev-stop: ## Stop development environment
	@echo "Stopping development environment..."
	docker compose -f docker compose.yml -f deployments/local/docker compose.override.yml down

dev-logs: ## Show development environment logs
	@echo "Showing development environment logs..."
	docker compose -f docker compose.yml -f deployments/local/docker compose.override.yml logs -f

# CI/CD targets
ci: ## Run CI pipeline locally
	@echo "Running CI pipeline locally..."
	$(MAKE) lint
	$(MAKE) build
	$(MAKE) test
	$(MAKE) security

cd: ## Run CD pipeline (build and deploy)
	@echo "Running CD pipeline..."
	$(MAKE) build-push
	$(MAKE) deploy-staging

# Comprehensive targets
all: ## Build, test, and validate everything
	@echo "Running complete build and test pipeline..."
	$(MAKE) lint
	$(MAKE) build
	$(MAKE) test-all
	$(MAKE) validate
	$(MAKE) security

quick: ## Quick build and test
	@echo "Running quick build and test..."
	$(MAKE) build
	$(MAKE) test-integration

# Environment setup
setup: ## Setup development environment
	@echo "Setting up development environment..."
	@echo "Installing required tools..."
	@if command -v brew >/dev/null 2>&1; then \
		brew install hadolint shellcheck yamllint; \
	elif command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update && sudo apt-get install -y shellcheck yamllint; \
		wget -O hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64; \
		chmod +x hadolint && sudo mv hadolint /usr/local/bin/; \
	else \
		echo "Please install hadolint, shellcheck, and yamllint manually"; \
	fi
	@echo "Installing Python test dependencies..."
	pip3 install -r tests/requirements.txt
	@echo "Development environment setup complete"

# Version management
version: ## Show version information
	@echo "Agentic Coding Pipeline Container"
	@echo "Version: $(IMAGE_TAG)"
	@echo "Registry: $(REGISTRY)"
	@echo "Platforms: $(PLATFORMS)"
	@echo ""
	@echo "Tool versions:"
	@docker --version 2>/dev/null || echo "Docker: not installed"
	@docker compose --version 2>/dev/null || echo "Docker Compose: not installed"
	@kubectl version --client 2>/dev/null || echo "kubectl: not installed"
	@python3 --version 2>/dev/null || echo "Python 3: not installed"

# Configuration
config: ## Show current configuration
	@echo "Current Configuration:"
	@echo "  IMAGE_NAME: $(IMAGE_NAME)"
	@echo "  IMAGE_TAG:  $(IMAGE_TAG)"
	@echo "  REGISTRY:   $(REGISTRY)"
	@echo "  PLATFORMS:  $(PLATFORMS)"
	@echo ""
	@echo "Available scripts:"
	@ls -la scripts/
	@echo ""
	@echo "Available deployments:"
	@ls -la deployments/