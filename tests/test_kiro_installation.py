#!/usr/bin/env python3
"""
Property-based tests for Kiro Autonomous Agent installation validation.

Feature: docker-container-setup, Property 3: Pipeline Project Installation Completeness
Validates: Requirements 2.1

This module tests that Kiro Autonomous Agent is properly installed and configured
with all required dependencies and proper configuration.
"""

import pytest
import docker
import json
import time
from hypothesis import given, strategies as st, settings
from typing import Dict, Any


class TestKiroInstallation:
    """Test suite for Kiro Autonomous Agent installation validation."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment."""
        cls.client = docker.from_env()
        cls.image_name = "agentic-coding-pipeline:latest"
        cls.container_name = "test-kiro"
        
    @classmethod
    def teardown_class(cls):
        """Clean up test environment."""
        try:
            container = cls.client.containers.get(cls.container_name)
            container.remove(force=True)
        except docker.errors.NotFound:
            pass
    
    def test_kiro_directory_structure(self):
        """Test that Kiro directory structure is properly created."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-structure",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(2)
            
            # Test Kiro pipeline directory exists
            exit_code, output = container.exec_run("test -d /opt/pipelines/kiro")
            assert exit_code == 0, "Kiro pipeline directory should exist"
            
            # Test Kiro configuration directory exists
            exit_code, output = container.exec_run("test -d /opt/configs/kiro")
            assert exit_code == 0, "Kiro configuration directory should exist"
            
            # Test Kiro startup script exists
            exit_code, output = container.exec_run("test -f /opt/pipelines/kiro/start-kiro.sh")
            assert exit_code == 0, "Kiro startup script should exist"
            
            # Test startup script is executable
            exit_code, output = container.exec_run("test -x /opt/pipelines/kiro/start-kiro.sh")
            assert exit_code == 0, "Kiro startup script should be executable"
            
            # Test configuration file exists
            exit_code, output = container.exec_run("test -f /opt/configs/kiro/config.json")
            assert exit_code == 0, "Kiro configuration file should exist"
            
        finally:
            container.stop()
    
    def test_kiro_configuration_validity(self):
        """Test that Kiro configuration is valid JSON and contains required fields."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-config",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(2)
            
            # Read and validate configuration file
            exit_code, output = container.exec_run("cat /opt/configs/kiro/config.json")
            assert exit_code == 0, "Should be able to read Kiro configuration"
            
            config_content = output.decode().strip()
            assert len(config_content) > 0, "Configuration file should not be empty"
            
            # Parse JSON to validate format
            try:
                config = json.loads(config_content)
            except json.JSONDecodeError as e:
                pytest.fail(f"Kiro configuration is not valid JSON: {e}")
            
            # Validate required configuration fields
            required_fields = ["name", "version", "description", "sandbox", "autonomous_operation", "workspace"]
            for field in required_fields:
                assert field in config, f"Configuration should contain '{field}' field"
            
            # Validate sandbox configuration
            assert "sandbox" in config, "Configuration should have sandbox section"
            sandbox_config = config["sandbox"]
            assert sandbox_config.get("enabled") is True, "Sandbox should be enabled"
            assert sandbox_config.get("dockerfile_detection") is True, "Dockerfile detection should be enabled"
            assert sandbox_config.get("environment") == "containerized", "Environment should be containerized"
            
            # Validate autonomous operation configuration
            assert "autonomous_operation" in config, "Configuration should have autonomous_operation section"
            auto_config = config["autonomous_operation"]
            assert auto_config.get("enabled") is True, "Autonomous operation should be enabled"
            assert auto_config.get("context_maintenance") is True, "Context maintenance should be enabled"
            
            # Validate workspace path
            assert config.get("workspace") == "/workspace", "Workspace should be set to /workspace"
            
        finally:
            container.stop()
    
    @settings(max_examples=5, deadline=30000)
    @given(
        workspace_path=st.text(
            alphabet=st.characters(whitelist_categories=("Ll", "Lu", "Nd"), min_codepoint=97, max_codepoint=122),
            min_size=3,
            max_size=15
        ).filter(lambda x: x.isalnum()),
        log_level=st.sampled_from(["debug", "info", "warning", "error"])
    )
    def test_kiro_startup_script_property(self, workspace_path: str, log_level: str):
        """
        Property test: For any valid workspace configuration, Kiro startup script
        should execute without errors and provide proper status information.
        
        Feature: docker-container-setup, Property 3: Pipeline Project Installation Completeness
        Validates: Requirements 2.1
        """
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-startup-{workspace_path[:8]}",
            detach=True,
            tty=True,
            remove=True,
            environment={
                "WORKSPACE_PATH": f"/workspace/{workspace_path}",
                "LOG_LEVEL": log_level
            }
        )
        
        try:
            time.sleep(2)
            
            # Test startup script execution
            exit_code, output = container.exec_run("/opt/pipelines/kiro/start-kiro.sh")
            assert exit_code == 0, "Kiro startup script should execute successfully"
            
            output_text = output.decode()
            assert "Starting Kiro Autonomous Agent" in output_text, "Should display startup message"
            assert "Configuration:" in output_text, "Should display configuration path"
            assert "Workspace:" in output_text, "Should display workspace path"
            assert "Logs:" in output_text, "Should display logs path"
            
            # Test that logs directory is created
            exit_code, output = container.exec_run("test -d /opt/logs/kiro")
            assert exit_code == 0, "Kiro logs directory should be created"
            
            # Test directory permissions
            exit_code, output = container.exec_run("ls -la /opt/logs/kiro")
            assert exit_code == 0, "Should be able to list logs directory"
            
        finally:
            container.stop()
    
    def test_kiro_dependencies_availability(self):
        """Test that Kiro has access to required dependencies."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-deps",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(2)
            
            # Test Node.js availability (required for Kiro)
            exit_code, output = container.exec_run("node --version")
            assert exit_code == 0, "Node.js should be available for Kiro"
            
            # Test Docker availability (required for sandbox)
            exit_code, output = container.exec_run("docker --version")
            assert exit_code == 0, "Docker should be available for Kiro sandbox"
            
            # Test workspace directory accessibility
            exit_code, output = container.exec_run("test -w /workspace")
            assert exit_code == 0, "Workspace should be writable for Kiro"
            
            # Test configuration directory accessibility
            exit_code, output = container.exec_run("test -r /opt/configs/kiro")
            assert exit_code == 0, "Kiro configuration should be readable"
            
            # Test that developer user can access Kiro files
            # Fix: Container already runs as developer, no need for su command
            exit_code, output = container.exec_run("test -r /opt/pipelines/kiro/start-kiro.sh")
            assert exit_code == 0, "Developer user should be able to access Kiro files"
            
        finally:
            container.stop()
    
    def test_kiro_integration_readiness(self):
        """Test that Kiro is ready for integration with other pipeline projects."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-integration",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(2)
            
            # Test that Kiro can access other pipeline directories
            exit_code, output = container.exec_run("test -d /opt/pipelines")
            assert exit_code == 0, "Kiro should have access to pipelines directory"
            
            # Test that Kiro can access shared configuration
            exit_code, output = container.exec_run("test -d /opt/configs")
            assert exit_code == 0, "Kiro should have access to shared configs"
            
            # Test that Kiro can write to workspace
            exit_code, output = container.exec_run("touch /workspace/kiro-test-file")
            assert exit_code == 0, "Kiro should be able to write to workspace"
            
            exit_code, output = container.exec_run("rm -f /workspace/kiro-test-file")
            assert exit_code == 0, "Should be able to clean up test files"
            
            # Test that Kiro has access to development tools
            exit_code, output = container.exec_run("which git")
            assert exit_code == 0, "Kiro should have access to Git"
            
            exit_code, output = container.exec_run("which python")
            assert exit_code == 0, "Kiro should have access to Python"
            
            exit_code, output = container.exec_run("which node")
            assert exit_code == 0, "Kiro should have access to Node.js"
            
        finally:
            container.stop()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])