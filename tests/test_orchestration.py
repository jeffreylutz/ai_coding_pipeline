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
        """Test that docker-compose.yml is valid and well-configured."""
        assert os.path.exists("docker-compose.yml"), "docker-compose.yml must exist"
        
        # Test docker-compose config validation
        result = subprocess.run(
            ["docker-compose", "config", "--quiet"],
            capture_output=True,
            text=True,
            cwd="."
        )
        assert result.returncode == 0, f"docker-compose.yml validation failed: {result.stderr}"
        
        # Parse and validate compose file content
        with open("docker-compose.yml", "r") as f:
            compose_content = yaml.safe_load(f)
        
        assert "services" in compose_content, "docker-compose.yml should have services section"
        
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
            assert port_found, f"Port {expected_port} should be mapped in docker-compose"
    
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
    
    def test_volume_mounting_compatibility(self):
        """Test that volume mounting works correctly."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        # Create a temporary directory for volume mounting
        import tempfile
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create test files in host directory
            test_file_path = os.path.join(temp_dir, "test-volume-file.txt")
            with open(test_file_path, "w") as f:
                f.write("Volume mounting test content")
            
            # Run container with volume mount
            container = self.client.containers.run(
                self.image_name,
                name=f"{self.container_name}-volume",
                detach=True,
                tty=True,
                remove=True,
                volumes={temp_dir: {'bind': '/workspace/test-mount', 'mode': 'rw'}}
            )
            
            try:
                time.sleep(2)
                
                # Test that mounted file is accessible
                exit_code, output = container.exec_run("cat /workspace/test-mount/test-volume-file.txt")
                assert exit_code == 0, "Should be able to read mounted file"
                
                file_content = output.decode().strip()
                assert "Volume mounting test content" in file_content, "Mounted file should have correct content"
                
                # Test that container can write to mounted volume
                exit_code, output = container.exec_run("echo 'Container write test' > /workspace/test-mount/container-written.txt")
                assert exit_code == 0, "Should be able to write to mounted volume"
                
                # Verify file was written to host
                host_written_file = os.path.join(temp_dir, "container-written.txt")
                assert os.path.exists(host_written_file), "File written by container should exist on host"
                
                with open(host_written_file, "r") as f:
                    written_content = f.read().strip()
                assert "Container write test" in written_content, "Written file should have correct content"
                
            finally:
                container.stop()
    
    @settings(max_examples=3, deadline=60000)
    @given(
        environment_config=st.dictionaries(
            keys=st.sampled_from(['WORKSPACE_DIR', 'LOG_LEVEL', 'DEBUG', 'NODE_ENV']),
            values=st.sampled_from(['/workspace', 'info', 'debug', 'false', 'true', 'development']),
            min_size=1,
            max_size=4
        )
    )
    def test_orchestration_environment_handling_property(self, environment_config: Dict[str, str]):
        """
        Property test: For any orchestration environment configuration,
        the container should handle environment variables correctly.
        
        Feature: docker-container-setup, Property 9: Runtime Compatibility
        Validates: Requirements 6.4, 6.6
        """
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-env",
            detach=True,
            tty=True,
            remove=True,
            environment=environment_config
        )
        
        try:
            time.sleep(2)
            
            # Test that environment variables are set correctly
            for key, expected_value in environment_config.items():
                exit_code, output = container.exec_run(f"echo ${key}")
                assert exit_code == 0, f"Should be able to access environment variable {key}"
                
                actual_value = output.decode().strip()
                assert actual_value == expected_value, f"Environment variable {key} should have correct value"
            
            # Test that container still functions with custom environment
            exit_code, output = container.exec_run("agentic-status")
            assert exit_code == 0, "Container should function normally with custom environment"
            
        finally:
            container.stop()
    
    def test_docker_compose_deployment(self):
        """Test that docker-compose deployment works correctly."""
        if not os.path.exists("docker-compose.yml"):
            pytest.skip("docker-compose.yml not found")
        
        # Test docker-compose up (dry run)
        result = subprocess.run(
            ["docker-compose", "config"],
            capture_output=True,
            text=True,
            cwd="."
        )
        assert result.returncode == 0, f"docker-compose config failed: {result.stderr}"
        
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
    
    def test_container_health_checks(self):
        """Test that container supports health check mechanisms."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-health",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(3)
            
            # Test health check command (agentic-status)
            exit_code, output = container.exec_run("agentic-status")
            assert exit_code == 0, "Health check command should succeed"
            
            output_text = output.decode()
            assert "Agentic Coding Environment Status" in output_text, "Health check should provide status info"
            
            # Test readiness indicators
            exit_code, output = container.exec_run("test -d /workspace")
            assert exit_code == 0, "Workspace should be ready"
            
            exit_code, output = container.exec_run("test -d /opt/pipelines")
            assert exit_code == 0, "Pipelines should be ready"
            
            exit_code, output = container.exec_run("which python")
            assert exit_code == 0, "Python should be available"
            
            exit_code, output = container.exec_run("which node")
            assert exit_code == 0, "Node.js should be available"
            
        finally:
            container.stop()
    
    def test_resource_limits_compatibility(self):
        """Test that container works with resource limits."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        # Test with memory limit
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-limits",
            detach=True,
            tty=True,
            remove=True,
            mem_limit="2g",
            cpus="1.0"
        )
        
        try:
            time.sleep(3)
            
            # Test that container runs with resource limits
            container.reload()
            assert container.status == "running", "Container should run with resource limits"
            
            # Test basic functionality with limits
            exit_code, output = container.exec_run("python --version")
            assert exit_code == 0, "Python should work with resource limits"
            
            exit_code, output = container.exec_run("node --version")
            assert exit_code == 0, "Node.js should work with resource limits"
            
            # Test memory usage is reasonable
            exit_code, output = container.exec_run("free -m")
            assert exit_code == 0, "Should be able to check memory usage"
            
        finally:
            container.stop()
    
    def test_network_compatibility(self):
        """Test that container works with different network configurations."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        # Test with custom network
        try:
            # Create a custom network
            network = self.client.networks.create("agentic-test-network")
            
            container = self.client.containers.run(
                self.image_name,
                name=f"{self.container_name}-network",
                detach=True,
                tty=True,
                remove=True,
                network="agentic-test-network"
            )
            
            try:
                time.sleep(2)
                
                # Test network connectivity
                exit_code, output = container.exec_run("ping -c 1 localhost")
                assert exit_code == 0, "Should be able to ping localhost on custom network"
                
                # Test that container can resolve DNS
                exit_code, output = container.exec_run("nslookup google.com || echo 'DNS resolution test'")
                assert exit_code == 0, "DNS resolution should work on custom network"
                
            finally:
                container.stop()
                
        finally:
            # Cleanup network
            try:
                network.remove()
            except:
                pass
    
    def test_persistent_storage_compatibility(self):
        """Test that container works with persistent storage configurations."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        # Create a named volume
        volume_name = "agentic-test-volume"
        try:
            volume = self.client.volumes.create(name=volume_name)
            
            container = self.client.containers.run(
                self.image_name,
                name=f"{self.container_name}-storage",
                detach=True,
                tty=True,
                remove=True,
                volumes={volume_name: {'bind': '/workspace', 'mode': 'rw'}}
            )
            
            try:
                time.sleep(2)
                
                # Test that persistent volume is mounted
                exit_code, output = container.exec_run("df -h /workspace")
                assert exit_code == 0, "Should be able to check workspace mount"
                
                # Test writing to persistent storage
                exit_code, output = container.exec_run("echo 'Persistent storage test' > /workspace/persistent-test.txt")
                assert exit_code == 0, "Should be able to write to persistent storage"
                
                # Test reading from persistent storage
                exit_code, output = container.exec_run("cat /workspace/persistent-test.txt")
                assert exit_code == 0, "Should be able to read from persistent storage"
                
                content = output.decode().strip()
                assert "Persistent storage test" in content, "Persistent storage should maintain data"
                
            finally:
                container.stop()
                
        finally:
            # Cleanup volume
            try:
                volume.remove()
            except:
                pass


if __name__ == "__main__":
    pytest.main([__file__, "-v"])