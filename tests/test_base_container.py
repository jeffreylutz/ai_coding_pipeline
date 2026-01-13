#!/usr/bin/env python3
"""
Property-based tests for base container setup validation.

Feature: docker-container-setup, Property 1: Base Container Integration Completeness
Validates: Requirements 1.1, 1.3

This module tests that the Docker container includes all components from the Base Container Image
and maintains all configurations and tools from the original setup.
"""

import pytest
import docker
import subprocess
import os
import time
from hypothesis import given, strategies as st, settings
from typing import List, Dict, Any


class TestBaseContainerSetup:
    """Test suite for base container setup validation."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment."""
        cls.client = docker.from_env()
        cls.image_name = "agentic-coding-pipeline:latest"
        cls.container_name = "test-base-container"
        
    @classmethod
    def teardown_class(cls):
        """Clean up test environment."""
        try:
            # Remove test container if it exists
            container = cls.client.containers.get(cls.container_name)
            container.remove(force=True)
        except docker.errors.NotFound:
            pass
    
    def test_dockerfile_exists(self):
        """Test that Dockerfile exists and is readable."""
        assert os.path.exists("Dockerfile"), "Dockerfile must exist"
        assert os.path.isfile("Dockerfile"), "Dockerfile must be a file"
        
        with open("Dockerfile", "r") as f:
            content = f.read()
            assert len(content) > 0, "Dockerfile must not be empty"
            assert "FROM ubuntu:24.04" in content, "Must use Ubuntu 24.04 as base image"
    
    def test_docker_compose_exists(self):
        """Test that docker-compose.yml exists and is valid."""
        assert os.path.exists("docker-compose.yml"), "docker-compose.yml must exist"
        
        # Test docker-compose config validation
        result = subprocess.run(
            ["docker-compose", "config", "--quiet"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"docker-compose.yml validation failed: {result.stderr}"
    
    @settings(max_examples=10, deadline=60000)  # 60 second deadline for Docker operations
    @given(
        user_id=st.integers(min_value=1000, max_value=65535),
        workspace_path=st.text(
            alphabet=st.characters(whitelist_categories=("Ll", "Lu", "Nd"), min_codepoint=32, max_codepoint=126),
            min_size=1,
            max_size=20
        ).filter(lambda x: x.isalnum() and not x.startswith('.'))
    )
    def test_base_container_components_property(self, user_id: int, workspace_path: str):
        """
        Property test: For any valid user configuration, the base container should include
        all essential components and maintain proper structure.
        
        Feature: docker-container-setup, Property 1: Base Container Integration Completeness
        Validates: Requirements 1.1, 1.3
        """
        # Skip if Docker image doesn't exist (build required first)
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        # Create container with random user configuration
        try:
            container = self.client.containers.run(
                self.image_name,
                name=f"{self.container_name}-{user_id}",
                detach=True,
                tty=True,
                remove=True,
                environment={
                    "WORKSPACE_DIR": f"/workspace/{workspace_path}",
                    "USER_ID": str(user_id)
                }
            )
            
            # Wait for container to start
            time.sleep(2)
            
            # Test essential system components
            essential_commands = [
                "which git",
                "which curl",
                "which wget",
                "which vim",
                "which nano",
                "which node",
                "which npm",
                "which python",
                "which pip",
                "which docker"
            ]
            
            for cmd in essential_commands:
                exit_code, output = container.exec_run(cmd)
                assert exit_code == 0, f"Essential command '{cmd}' not found in container"
                assert len(output.decode().strip()) > 0, f"Command '{cmd}' returned empty path"
            
            # Test directory structure
            essential_directories = [
                "/opt/pipelines",
                "/opt/tools", 
                "/opt/configs",
                "/workspace",
                "/home/developer"
            ]
            
            for directory in essential_directories:
                exit_code, output = container.exec_run(f"test -d {directory}")
                assert exit_code == 0, f"Essential directory '{directory}' not found"
            
            # Test user permissions
            exit_code, output = container.exec_run("whoami")
            assert exit_code == 0, "Failed to get current user"
            current_user = output.decode().strip()
            assert current_user == "developer", f"Expected user 'developer', got '{current_user}'"
            
            # Test sudo access
            exit_code, output = container.exec_run("sudo -n true")
            assert exit_code == 0, "Developer user should have sudo access"
            
            # Test Git configuration
            exit_code, output = container.exec_run("git config --global user.name")
            assert exit_code == 0, "Git user.name should be configured"
            
            exit_code, output = container.exec_run("git config --global user.email")
            assert exit_code == 0, "Git user.email should be configured"
            
            # Test Python virtual environment
            exit_code, output = container.exec_run("test -d /home/developer/.venv")
            assert exit_code == 0, "Python virtual environment should exist"
            
            # Test Node.js global packages
            exit_code, output = container.exec_run("npm list -g --depth=0")
            assert exit_code == 0, "Should be able to list global npm packages"
            
        finally:
            # Cleanup
            try:
                container.stop()
            except:
                pass
    
    def test_base_image_requirements(self):
        """Test that the base image meets all requirements."""
        # Skip if Docker image doesn't exist
        try:
            image = self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        # Test image labels
        labels = image.attrs.get('Config', {}).get('Labels', {})
        assert 'maintainer' in labels, "Image should have maintainer label"
        assert 'description' in labels, "Image should have description label"
        assert 'version' in labels, "Image should have version label"
        
        # Test exposed ports
        exposed_ports = image.attrs.get('Config', {}).get('ExposedPorts', {})
        required_ports = ['3000/tcp', '8000/tcp', '8080/tcp', '9000/tcp']
        
        for port in required_ports:
            assert port in exposed_ports, f"Port {port} should be exposed"
    
    def test_container_startup_script(self):
        """Test that the container startup script exists and is executable."""
        # Skip if Docker image doesn't exist
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-startup",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            # Test startup script exists
            exit_code, output = container.exec_run("test -f /usr/local/bin/start-container.sh")
            assert exit_code == 0, "Startup script should exist"
            
            # Test startup script is executable
            exit_code, output = container.exec_run("test -x /usr/local/bin/start-container.sh")
            assert exit_code == 0, "Startup script should be executable"
            
        finally:
            container.stop()
    
    @settings(max_examples=5, deadline=30000)
    @given(
        environment_vars=st.dictionaries(
            keys=st.text(
                alphabet=st.characters(whitelist_categories=("Lu", "Nd"), min_codepoint=65, max_codepoint=90),
                min_size=3,
                max_size=10
            ),
            # Fix: Use printable ASCII characters to avoid null bytes and special characters
            values=st.text(
                alphabet=st.characters(whitelist_categories=("Ll", "Lu", "Nd"), min_codepoint=32, max_codepoint=126),
                min_size=1,
                max_size=50
            ).filter(lambda x: '\x00' not in x),  # Explicitly filter null bytes
            min_size=1,
            max_size=5
        )
    )
    def test_environment_variable_handling(self, environment_vars: Dict[str, str]):
        """
        Property test: For any set of environment variables, the container should
        handle them properly without breaking core functionality.
        
        Feature: docker-container-setup, Property 1: Base Container Integration Completeness
        """
        # Skip if Docker image doesn't exist
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        # Filter out potentially problematic environment variables
        safe_env_vars = {
            k: v for k, v in environment_vars.items() 
            if k not in ['PATH', 'HOME', 'USER', 'SHELL'] and not k.startswith('DOCKER_')
        }
        
        if not safe_env_vars:
            return  # Skip if no safe environment variables
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-env",
            detach=True,
            tty=True,
            remove=True,
            environment=safe_env_vars
        )
        
        try:
            time.sleep(2)  # Wait for container to start
            
            # Test that environment variables are set
            for key, expected_value in safe_env_vars.items():
                # Fix: Run through bash to expand environment variables
                exit_code, output = container.exec_run(["bash", "-c", f"echo ${key}"])
                assert exit_code == 0, f"Failed to read environment variable {key}"
                actual_value = output.decode().strip()
                assert actual_value == expected_value, f"Environment variable {key} mismatch"
            
            # Test that core functionality still works
            exit_code, output = container.exec_run("python --version")
            assert exit_code == 0, "Python should still work with custom environment variables"
            
            exit_code, output = container.exec_run("node --version")
            assert exit_code == 0, "Node.js should still work with custom environment variables"
            
        finally:
            container.stop()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])