# Build and Test Automation

This document describes the comprehensive build and test automation system for the Agentic Coding Pipeline Container.

## Overview

The automation system provides:

- **Automated Building**: Multi-platform Docker builds with caching and optimization
- **Comprehensive Testing**: Unit, integration, property-based, performance, and security tests
- **Continuous Integration**: GitHub Actions workflow for automated validation
- **Multi-Environment Deployment**: Local, staging, and production deployment automation
- **Quality Assurance**: Linting, security scanning, and compliance checking

## Quick Start

### Prerequisites

```bash
# Install required tools
make setup

# Or manually install:
# - Docker 20.10+
# - Docker Compose 2.0+
# - Python 3.12+
# - kubectl (for Kubernetes deployments)
```

### Basic Usage

```bash
# Build and test everything
make all

# Quick build and test
make quick

# Build only
make build

# Test only
make test

# Deploy locally
make deploy-local
```

## Build Automation

### Build Scripts

#### 1. Enhanced Build Script (`build.sh`)
The original build script with error handling and optimization:

```bash
./build.sh
```

#### 2. Advanced Build Automation (`scripts/build-automation.sh`)
Comprehensive build system with multi-platform support:

```bash
# Basic build
./scripts/build-automation.sh

# Multi-platform build
./scripts/build-automation.sh --platforms linux/amd64,linux/arm64

# Build and push to registry
./scripts/build-automation.sh --tag v1.2.3 --push --registry ghcr.io

# Build with custom arguments
./scripts/build-automation.sh --build-arg USERNAME=developer --build-arg USER_UID=1001
```

**Features:**
- Multi-platform builds (AMD64, ARM64)
- Build caching (registry, local, or disabled)
- Parallel builds for performance
- Dockerfile validation with hadolint
- Automated testing after build
- Build reports and metrics

### Build Configuration

Configure builds via `automation.config`:

```bash
# Image settings
IMAGE_NAME=agentic-coding-pipeline
IMAGE_TAG=latest
PLATFORMS=linux/amd64,linux/arm64

# Build settings
BUILD_CACHE_TYPE=registry
BUILD_PARALLEL=true
BUILD_TIMEOUT=3600
```

## Test Automation

### Test Scripts

#### 1. Basic Test Script (`test.sh`)
Original test script with Docker and property-based tests:

```bash
./test.sh
```

#### 2. Comprehensive Test Automation (`scripts/test-automation.sh`)
Advanced testing system with multiple test types:

```bash
# Run all tests
./scripts/test-automation.sh all

# Run specific test types
./scripts/test-automation.sh unit integration
./scripts/test-automation.sh property performance
./scripts/test-automation.sh security

# Custom configuration
./scripts/test-automation.sh --image myimage:latest --timeout 300 property
```

### Test Types

#### Unit Tests
- Test individual components and functions
- Fast execution for quick feedback
- Located in container at `/opt/tests/unit/`

#### Integration Tests
- Test container startup and service availability
- Test pipeline project accessibility
- Test port connectivity and basic functionality

#### Property-Based Tests
- Test universal properties across all inputs
- Use Hypothesis for Python-based property testing
- Validate correctness properties from design document

#### Performance Tests
- Test image size (target: <8GB)
- Test container startup time (target: <60s)
- Test memory usage and resource consumption

#### Security Tests
- Test container security configuration
- Check for non-root user execution
- Scan for common security vulnerabilities

### Test Configuration

```bash
# Test settings
TEST_TIMEOUT=600
TEST_PARALLEL=true
RUN_PROPERTY_TESTS=true
RUN_SECURITY_TESTS=false

# Performance thresholds
MAX_IMAGE_SIZE_GB=8
MAX_STARTUP_TIME_SECONDS=60
```

## Continuous Integration

### GitHub Actions Workflow

The CI/CD pipeline (`.github/workflows/ci.yml`) provides:

1. **Lint and Validate**
   - Dockerfile linting with hadolint
   - Docker Compose validation
   - Kubernetes manifest validation
   - Shell script linting with shellcheck

2. **Build and Test**
   - Multi-platform builds
   - Comprehensive test suite
   - Performance validation
   - Test result artifacts

3. **Security Scanning**
   - Vulnerability scanning with Trivy
   - Security report generation
   - SARIF upload for GitHub Security

4. **Build and Push**
   - Registry push on main branch
   - Image tagging and metadata
   - Build caching optimization

5. **Deployment**
   - Automated staging deployment
   - Production deployment with approval
   - Rollback capabilities

### Triggering CI/CD

```bash
# Trigger on push to main
git push origin main

# Trigger on pull request
git push origin feature-branch

# Manual trigger via GitHub Actions UI
# Scheduled nightly builds at 2 AM UTC
```

## Deployment Automation

### Deployment Script (`scripts/deploy.sh`)

Supports multiple environments and deployment platforms:

```bash
# Local deployment with Docker Compose
./scripts/deploy.sh local deploy

# Staging deployment to Kubernetes
./scripts/deploy.sh staging deploy --tag v1.2.3

# Production deployment
./scripts/deploy.sh production deploy --tag v1.2.3

# Validate configurations
./scripts/deploy.sh staging validate --dry-run

# Check deployment status
./scripts/deploy.sh production status

# View logs
./scripts/deploy.sh staging logs

# Rollback deployment
./scripts/deploy.sh production rollback
```

### Environment Configurations

#### Local Development
- Docker Compose with development overrides
- Volume mounts for live development
- Debug mode enabled
- All ports exposed

#### Staging Environment
- Kubernetes deployment with reduced resources
- Debug logging enabled
- Experimental features allowed
- Kustomize configuration

#### Production Environment
- Kubernetes deployment with full resources
- Production security settings
- Monitoring and metrics enabled
- High availability configuration

### Deployment Files

```
deployments/
├── local/
│   └── docker-compose.override.yml
├── staging/
│   └── kustomization.yaml
└── production/
    └── kustomization.yaml
```

## Makefile Automation

The `Makefile` provides convenient targets for all automation tasks:

### Build Targets
```bash
make build              # Basic Docker build
make build-advanced     # Advanced build with automation script
make build-multi        # Multi-platform build
make build-push         # Build and push to registry
```

### Test Targets
```bash
make test               # Run all tests
make test-unit          # Unit tests only
make test-integration   # Integration tests only
make test-property      # Property-based tests only
make test-performance   # Performance tests only
make test-security      # Security tests
```

### Deployment Targets
```bash
make deploy-local       # Deploy locally
make deploy-staging     # Deploy to staging
make deploy-production  # Deploy to production
```

### Quality Targets
```bash
make lint               # Run all linting
make security           # Run security scans
make validate           # Validate configurations
```

### Utility Targets
```bash
make clean              # Clean up containers and images
make status             # Show deployment status
make logs               # Show application logs
make setup              # Setup development environment
```

## Configuration Management

### Configuration Files

1. **`automation.config`** - Main automation configuration
2. **`.github/workflows/ci.yml`** - CI/CD pipeline configuration
3. **`docker-compose.yml`** - Local deployment configuration
4. **`kubernetes/deployment.yaml`** - Kubernetes base configuration
5. **`deployments/*/kustomization.yaml`** - Environment-specific configurations

### Environment Variables

Key environment variables for automation:

```bash
# Build configuration
export IMAGE_NAME=agentic-coding-pipeline
export IMAGE_TAG=latest
export REGISTRY=ghcr.io

# Test configuration
export TEST_TIMEOUT=600
export RUN_SECURITY_TESTS=false

# Deployment configuration
export ENVIRONMENT=staging
export NAMESPACE=staging
```

## Monitoring and Reporting

### Test Reports

Test automation generates comprehensive reports:

- **JUnit XML**: For CI/CD integration
- **HTML Reports**: Human-readable test results
- **Performance Metrics**: Image size, startup time, resource usage
- **Security Reports**: Vulnerability scans and compliance checks

### Build Reports

Build automation provides detailed reports:

- **Build Metrics**: Build time, image size, layer information
- **Cache Statistics**: Cache hit rates and optimization metrics
- **Multi-platform Results**: Build status for each target platform

### Deployment Reports

Deployment automation tracks:

- **Deployment Status**: Success/failure for each environment
- **Resource Usage**: CPU, memory, storage consumption
- **Health Checks**: Service availability and readiness

## Troubleshooting

### Common Issues

#### Build Failures
```bash
# Check Docker daemon
docker info

# Validate Dockerfile
make lint-docker

# Check build logs
./scripts/build-automation.sh --no-cache
```

#### Test Failures
```bash
# Run tests with verbose output
./scripts/test-automation.sh --sequential property

# Check test results
ls -la test-results/

# Debug specific test
docker run -it agentic-coding-pipeline:latest bash
```

#### Deployment Issues
```bash
# Validate configuration
./scripts/deploy.sh staging validate

# Check cluster connectivity
kubectl cluster-info

# View deployment logs
kubectl logs -f deployment/agentic-coding-pipeline-staging
```

### Performance Optimization

#### Build Performance
- Enable BuildKit: `export DOCKER_BUILDKIT=1`
- Use build cache: `--cache-from` and `--cache-to`
- Optimize Dockerfile layer ordering
- Use multi-stage builds

#### Test Performance
- Run tests in parallel: `--parallel`
- Use test result caching
- Optimize test data generation
- Skip slow tests in development

#### Deployment Performance
- Use image caching
- Optimize resource requests and limits
- Use readiness and liveness probes
- Enable horizontal pod autoscaling

## Security Considerations

### Build Security
- Scan base images for vulnerabilities
- Use minimal base images
- Avoid running as root user
- Sign and verify images

### Test Security
- Isolate test environments
- Use secure test data
- Scan test dependencies
- Validate security configurations

### Deployment Security
- Use Kubernetes security contexts
- Enable network policies
- Implement RBAC
- Regular security updates

## Best Practices

### Development Workflow
1. Use feature branches for development
2. Run local tests before pushing
3. Use pre-commit hooks for quality checks
4. Keep automation scripts updated

### CI/CD Workflow
1. Fail fast with early validation
2. Use parallel execution for performance
3. Cache build artifacts and dependencies
4. Generate comprehensive reports

### Deployment Workflow
1. Deploy to staging first
2. Run smoke tests after deployment
3. Use blue-green or rolling deployments
4. Have rollback procedures ready

## Contributing

### Adding New Tests
1. Create test files in appropriate directories
2. Update test automation scripts
3. Add test configuration to `automation.config`
4. Update documentation

### Modifying Build Process
1. Update build scripts and Dockerfile
2. Test changes locally
3. Update CI/CD pipeline if needed
4. Document configuration changes

### Environment Changes
1. Update deployment configurations
2. Test in staging environment first
3. Update automation scripts
4. Document environment-specific settings

## Support

For issues with the automation system:

1. Check the troubleshooting section
2. Review automation logs and reports
3. Validate configurations with `make validate`
4. Open an issue with detailed information

## References

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Kubernetes Deployment Guide](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Property-Based Testing Guide](https://hypothesis.readthedocs.io/)
- [Container Security Best Practices](https://kubernetes.io/docs/concepts/security/)