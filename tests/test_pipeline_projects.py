#!/usr/bin/env python3
"""
Property-based tests for all pipeline projects installation validation.

Feature: docker-container-setup, Property 3: Pipeline Project Installation Completeness
Validates: Requirements 2.8

This module tests that all multi-agent pipeline projects are properly installed
with all dependencies satisfied and accessible.
"""

import pytest
import docker
import json
import time
from hypothesis import given, strategies as st, settings
from typing import List, Dict, Any


class TestPipelineProjectsInstallation:
    """Test suite for all pipeline projects installation validation."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment."""
        cls.client = docker.from_env()
        cls.image_name = "agentic-coding-pipeline:latest"
        cls.container_name = "test-pipeline-projects"
        
        # Define all pipeline projects
        cls.pipeline_projects = [
            {
                "name": "kiro",
                "path": "/opt/pipelines/kiro",
                "startup_script": "/opt/pipelines/kiro/start-kiro.sh",
                "config_path": "/opt/configs/kiro/config.json",
                "type": "proprietary"
            },
            {
                "name": "auto-claude",
                "path": "/opt/pipelines/auto-claude",
                "startup_script": "/opt/pipelines/auto-claude/start-auto-claude.sh",
                "config_path": "/opt/configs/auto-claude/config.yaml",
                "type": "python"
            },
            {
                "name": "continuous-claude",
                "path": "/opt/pipelines/continuous-claude",
                "startup_script": "/opt/pipelines/continuous-claude/start-continuous-claude.sh",
                "config_path": "/opt/configs/continuous-claude/config.json",
                "type": "nodejs"
            },
            {
                "name": "automaker",
                "path": "/opt/pipelines/automaker",
                "startup_script": "/opt/pipelines/automaker/start-automaker.sh",
                "config_path": "/opt/configs/automaker/config.yaml",
                "type": "python"
            },
            {
                "name": "infiagent",
                "path": "/opt/pipelines/infiagent",
                "startup_script": "/opt/pipelines/infiagent/start-infiagent.sh",
                "config_path": "/opt/configs/infiagent/mla-config.yaml",
                "type": "python"
            },
            {
                "name": "mai-ui",
                "path": "/opt/pipelines/mai-ui",
                "startup_script": "/opt/pipelines/mai-ui/start-mai-ui.sh",
                "config_path": "/opt/configs/mai-ui/config.yaml",
                "type": "python"
            },
            {
                "name": "loki-mode",
                "path": "/opt/pipelines/loki-mode",
                "startup_script": "/opt/pipelines/loki-mode/start-loki-mode.sh",
                "config_path": "/opt/configs/loki-mode/config.json",
                "type": "nodejs"
            }
        ]
        
    @classmethod
    def teardown_class(cls):
        """Clean up test environment."""
        try:
            container = cls.client.containers.get(cls.container_name)
            container.remove(force=True)
        except docker.errors.NotFound:
            pass
    
    def test_all_pipeline_projects_directory_structure(self):
        """Test that all pipeline projects have proper directory structure."""
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
            
            for project in self.pipeline_projects:
                # Test project directory exists
                exit_code, output = container.exec_run(f"test -d {project['path']}")
                assert exit_code == 0, f"Pipeline project {project['name']} directory should exist at {project['path']}"
                
                # Test startup script exists and is executable
                exit_code, output = container.exec_run(f"test -x {project['startup_script']}")
                assert exit_code == 0, f"Startup script for {project['name']} should exist and be executable"
                
                # Test configuration file exists
                exit_code, output = container.exec_run(f"test -f {project['config_path']}")
                assert exit_code == 0, f"Configuration file for {project['name']} should exist"
                
        finally:
            container.stop()
    
    def test_all_pipeline_projects_startup_scripts(self):
        """Test that all pipeline project startup scripts execute without errors."""
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
            time.sleep(2)
            
            for project in self.pipeline_projects:
                # Execute startup script
                exit_code, output = container.exec_run(project['startup_script'])
                assert exit_code == 0, f"Startup script for {project['name']} should execute successfully"
                
                output_text = output.decode()
                assert len(output_text) > 0, f"Startup script for {project['name']} should produce output"
                
                # Check for common startup messages
                project_name_variations = [
                    project['name'].lower(),
                    project['name'].replace('-', ' ').title(),
                    project['name'].replace('-', '').upper()
                ]
                
                found_project_reference = any(
                    variation in output_text for variation in project_name_variations
                )
                assert found_project_reference, f"Startup output for {project['name']} should reference the project"
                
        finally:
            container.stop()
    
    def test_pipeline_projects_integration_readiness(self):
        """Test that all pipeline projects are ready for integration with each other."""
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
            
            # Test shared workspace access
            for project in self.pipeline_projects:
                exit_code, output = container.exec_run(f"touch /workspace/{project['name']}-integration-test")
                assert exit_code == 0, f"Project {project['name']} should be able to write to shared workspace"
            
            # Test shared configuration access
            for project in self.pipeline_projects:
                exit_code, output = container.exec_run(f"ls -la /opt/configs/{project['name']}")
                assert exit_code == 0, f"Project {project['name']} configuration should be accessible"
            
            # Test that projects can access common tools
            common_tools = ["git", "docker", "python", "node"]
            for project in self.pipeline_projects:
                for tool in common_tools:
                    exit_code, output = container.exec_run(f"which {tool}")
                    assert exit_code == 0, f"Tool {tool} should be available for {project['name']}"
            
            # Cleanup test files
            for project in self.pipeline_projects:
                container.exec_run(f"rm -f /workspace/{project['name']}-integration-test")
                
        finally:
            container.stop()
    
    def test_pipeline_projects_logs_and_monitoring(self):
        """Test that all pipeline projects have proper logging setup."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-logs",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(2)
            
            for project in self.pipeline_projects:
                # Test that logs directory can be created
                exit_code, output = container.exec_run(f"mkdir -p /opt/logs/{project['name']}")
                assert exit_code == 0, f"Should be able to create logs directory for {project['name']}"
                
                # Test log directory permissions
                exit_code, output = container.exec_run(f"test -w /opt/logs/{project['name']}")
                assert exit_code == 0, f"Logs directory for {project['name']} should be writable"
                
                # Test that startup script mentions logging
                exit_code, output = container.exec_run(project['startup_script'])
                output_text = output.decode().lower()
                assert "log" in output_text, f"Startup script for {project['name']} should mention logging"
                
        finally:
            container.stop()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])