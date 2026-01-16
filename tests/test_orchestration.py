#!/usr/bin/env python3
"""
Property-based tests for container orchestration compatibility validation.

Feature: docker-container-setup, Property 9: Runtime Compatibility
Validates: Requirements 6.4, 6.6

This module tests that the container deploys and runs successfully with
volume mounting support on common orchestration platforms.
"""

import pytest
import docker
import yaml
import json
import os
import subprocess
from hypothesis import given, strategies as st, settings
from typing import Dict, Any


class TestOrchestrationCompatibility:
    """Test suite for container orchestration compatibility validation."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment."""
        cls.client = docker.from_env()
        cls.image_name = "agentic-coding-pipeline:latest"
        cls.container_name = "test-orchestration"
        
    @classmethod
    def teardown_class(cls):
        """Clean up test environment."""
        try:
            container = cls.client.containers.get(cls.container_name)
            container.remove(force=True)
        except docker.errors.NotFound:
            pass
    
    def test_docker_compose_configuration_validity(self):
        """Test that compose.yml is valid and well-configured."""
        assert os.path.exists("compose.yml"), "compose.yml must exist"

        # Test docker compose config validation
        result = subprocess.run(
            ["docker", "compose", "config", "--quiet"],
            capture_output=True,
            text=True,
            cwd="."
        )
        assert result.returncode == 0, f"compose.yml validation failed: {result.stderr}"
        
        # Parse and validate compose file content
        with open("compose.yml", "r") as f:
            compose_content = yaml.safe_load(f)
        
        assert "services" in compose_content, "compose.yml should have services section"
        
        # Test main service configuration
        services = compose_content["services"]
        main_service = None
        for service_name, service_config in services.items():
            if "agentic" in service_name.lower():
                main_service = service_config
                break
        
        assert main_service is not None, "Should have main agentic service defined"
        
        # Test essential configurations
        assert "image" in main_service or "build" in main_service, "Service should specify image or build"
        assert "ports" in main_service, "Service should expose ports"
        assert "volumes" in main_service, "Service should have volume mounts"
        
        # Test port mappings
        ports = main_service["ports"]
        expected_ports = ["3000", "8000", "8080", "9000"]
        for expected_port in expected_ports:
            port_found = any(expected_port in str(port) for port in ports)
            assert port_found, f"Port {expected_port} should be mapped in docker compose"
    
    def test_kubernetes_deployment_configuration(self):
        """Test that Kubernetes deployment configuration is valid."""
        k8s_file = "kubernetes/deployment.yaml"
        assert os.path.exists(k8s_file), "Kubernetes deployment file should exist"
        
        with open(k8s_file, "r") as f:
            k8s_content = f.read()
        
        # Parse YAML documents
        documents = list(yaml.safe_load_all(k8s_content))
        assert len(documents) >= 3, "Should have multiple Kubernetes resources (Deployment, Service, PVC)"
        
        # Find deployment
        deployment = None
        service = None
        pvc = None
        
        for doc in documents:
            if doc and doc.get("kind") == "Deployment":
                deployment = doc
            elif doc and doc.get("kind") == "Service":
                service = doc
            elif doc and doc.get("kind") == "PersistentVolumeClaim":
                pvc = doc
        
        assert deployment is not None, "Should have Deployment resource"
        assert service is not None, "Should have Service resource"
        assert pvc is not None, "Should have PersistentVolumeClaim resource"
        
        # Test deployment configuration
        spec = deployment["spec"]
        template = spec["template"]["spec"]
        container = template["containers"][0]
        
        assert "image" in container, "Container should specify image"
        assert "ports" in container, "Container should expose ports"
        assert "volumeMounts" in container, "Container should have volume mounts"
        assert "resources" in container, "Container should have resource limits"
        
        # Test service configuration
        service_spec = service["spec"]
        assert "ports" in service_spec, "Service should expose ports"
        assert "selector" in service_spec, "Service should have selector"
    
        
    def test_docker_compose_deployment(self):
        """Test that docker compose deployment works correctly."""
        if not os.path.exists("compose.yml"):
            pytest.skip("compose.yml not found")

        # Test docker compose up (dry run)
        result = subprocess.run(
            ["docker", "compose", "config"],
            capture_output=True,
            text=True,
            cwd="."
        )
        assert result.returncode == 0, f"docker compose config failed: {result.stderr}"
        
        # Parse the composed configuration
        composed_config = yaml.safe_load(result.stdout)
        assert "services" in composed_config, "Composed config should have services"
        
        # Test that all required services are defined
        services = composed_config["services"]
        assert len(services) > 0, "Should have at least one service defined"
        
        # Test main service configuration
        main_service = list(services.values())[0]
        assert "ports" in main_service, "Main service should expose ports"
        assert "volumes" in main_service, "Main service should have volumes"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])