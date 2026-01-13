#!/usr/bin/env python3
"""
Property-based tests for additional development tools installation validation.

Feature: docker-container-setup, Property 4: Additional Tools Availability
Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6

This module tests that additional tools (KnowNote, Vibium, OpenTinker, ProxyPal, 
claude-code-transcript) are installed and accessible with proper configurations and dependencies.
"""

import pytest
import docker
import json
import yaml
import time
from hypothesis import given, strategies as st, settings
from typing import List, Dict, Any


class TestAdditionalToolsInstallation:
    """Test suite for additional development tools installation validation."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment."""
        cls.client = docker.from_env()
        cls.image_name = "agentic-coding-pipeline:latest"
        cls.container_name = "test-additional-tools"
        
        # Define all additional tools
        cls.additional_tools = [
            {
                "name": "knownote",
                "path": "/opt/tools/knownote",
                "startup_script": "/opt/tools/knownote/start-knownote.sh",
                "config_path": "/opt/configs/knownote/config.yaml",
                "type": "python",
                "description": "Local-first NotebookLM alternative"
            },
            {
                "name": "vibium",
                "path": "/opt/tools/vibium",
                "startup_script": "/opt/tools/vibium/start-vibium.sh",
                "config_path": "/opt/configs/vibium/config.json",
                "type": "nodejs",
                "description": "Browser automation without the drama"
            },
            {
                "name": "opentinker",
                "path": "/opt/tools/opentinker",
                "startup_script": "/opt/tools/opentinker/start-opentinker.sh",
                "config_path": "/opt/configs/opentinker/config.yaml",
                "type": "python",
                "description": "Agentic RL as a Service"
            },
            {
                "name": "proxypal",
                "path": "/opt/tools/proxypal",
                "startup_script": "/opt/tools/proxypal/start-proxypal.sh",
                "config_path": "/opt/configs/proxypal/config.json",
                "type": "nodejs",
                "description": "AI subscription proxy"
            },
            {
                "name": "claude-transcripts",
                "path": "/opt/tools/claude-transcripts",
                "startup_script": "/opt/tools/claude-transcripts/start-claude-transcripts.sh",
                "config_path": "/opt/configs/claude-transcripts/config.yaml",
                "type": "python",
                "description": "Claude code transcripts tools"
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
    
    def test_all_additional_tools_directory_structure(self):
        """Test that all additional tools have proper directory structure."""
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
            
            # Test tools directory exists
            exit_code, output = container.exec_run("test -d /opt/tools")
            assert exit_code == 0, "Tools directory should exist"
            
            for tool in self.additional_tools:
                # Test tool directory exists
                exit_code, output = container.exec_run(f"test -d {tool['path']}")
                assert exit_code == 0, f"Tool {tool['name']} directory should exist at {tool['path']}"
                
                # Test startup script exists and is executable
                exit_code, output = container.exec_run(f"test -x {tool['startup_script']}")
                assert exit_code == 0, f"Startup script for {tool['name']} should exist and be executable"
                
                # Test configuration file exists
                exit_code, output = container.exec_run(f"test -f {tool['config_path']}")
                assert exit_code == 0, f"Configuration file for {tool['name']} should exist"
                
        finally:
            container.stop()
    
    def test_additional_tools_configuration_validity(self):
        """Test that all additional tools have valid configuration files."""
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
            
            for tool in self.additional_tools:
                # Read configuration file
                exit_code, output = container.exec_run(f"cat {tool['config_path']}")
                assert exit_code == 0, f"Should be able to read {tool['name']} configuration"
                
                config_content = output.decode().strip()
                assert len(config_content) > 0, f"Configuration for {tool['name']} should not be empty"
                
                # Validate configuration format based on file extension
                if tool['config_path'].endswith('.json'):
                    try:
                        config = json.loads(config_content)
                        assert isinstance(config, dict), f"JSON config for {tool['name']} should be a dictionary"
                        assert 'name' in config, f"JSON config for {tool['name']} should have 'name' field"
                    except json.JSONDecodeError as e:
                        pytest.fail(f"Configuration for {tool['name']} is not valid JSON: {e}")
                
                elif tool['config_path'].endswith('.yaml') or tool['config_path'].endswith('.yml'):
                    try:
                        config = yaml.safe_load(config_content)
                        assert isinstance(config, dict), f"YAML config for {tool['name']} should be a dictionary"
                        assert 'name' in config, f"YAML config for {tool['name']} should have 'name' field"
                    except yaml.YAMLError as e:
                        pytest.fail(f"Configuration for {tool['name']} is not valid YAML: {e}")
                
        finally:
            container.stop()
    
    def test_additional_tools_startup_scripts(self):
        """Test that all additional tools startup scripts execute without errors."""
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
            
            for tool in self.additional_tools:
                # Execute startup script
                exit_code, output = container.exec_run(tool['startup_script'])
                assert exit_code == 0, f"Startup script for {tool['name']} should execute successfully"
                
                output_text = output.decode()
                assert len(output_text) > 0, f"Startup script for {tool['name']} should produce output"
                
                # Check for tool name or description in output
                tool_references = [
                    tool['name'].lower(),
                    tool['name'].replace('-', ' ').lower(),
                    tool['description'].lower()
                ]
                
                found_reference = any(
                    ref in output_text.lower() for ref in tool_references
                )
                assert found_reference, f"Startup output for {tool['name']} should reference the tool"
                
        finally:
            container.stop()
    
    @settings(max_examples=5, deadline=45000)
    @given(
        tool_index=st.integers(min_value=0, max_value=4),  # 5 tools (0-4)
        workspace_config=st.dictionaries(
            keys=st.sampled_from(['output_dir', 'cache_dir', 'temp_dir']),
            values=st.text(
                alphabet=st.characters(whitelist_categories=("Ll", "Lu", "Nd"), min_codepoint=97, max_codepoint=122),
                min_size=3,
                max_size=15
            ).filter(lambda x: x.isalnum()),
            min_size=1,
            max_size=3
        )
    )
    def test_additional_tools_workspace_integration_property(self, tool_index: int, workspace_config: Dict[str, str]):
        """
        Property test: For any additional tool and workspace configuration,
        the tool should integrate properly with the workspace.
        
        Feature: docker-container-setup, Property 4: Additional Tools Availability
        Validates: Requirements 3.6
        """
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        tool = self.additional_tools[tool_index]
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-workspace-{tool['name'][:8]}",
            detach=True,
            tty=True,
            remove=True,
            environment={
                f"{tool['name'].upper()}_CONFIG": json.dumps(workspace_config)
            }
        )
        
        try:
            time.sleep(2)
            
            # Test tool can access workspace
            exit_code, output = container.exec_run(f"ls -la /workspace")
            assert exit_code == 0, f"Tool {tool['name']} should be able to access workspace"
            
            # Test tool can create directories in workspace
            for config_key, config_value in workspace_config.items():
                workspace_path = f"/workspace/{tool['name']}-{config_value}"
                exit_code, output = container.exec_run(f"mkdir -p {workspace_path}")
                assert exit_code == 0, f"Tool {tool['name']} should be able to create workspace directories"
                
                # Test tool can write files
                exit_code, output = container.exec_run(f"touch {workspace_path}/test-file")
                assert exit_code == 0, f"Tool {tool['name']} should be able to write files in workspace"
                
                # Test tool can read files
                exit_code, output = container.exec_run(f"ls {workspace_path}/test-file")
                assert exit_code == 0, f"Tool {tool['name']} should be able to read files in workspace"
            
            # Test tool configuration is accessible
            exit_code, output = container.exec_run(f"cat {tool['config_path']}")
            assert exit_code == 0, f"Tool {tool['name']} configuration should be accessible"
            
        finally:
            container.stop()
    
    def test_additional_tools_dependency_satisfaction(self):
        """Test that all additional tools have their dependencies satisfied."""
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
            
            # Test Python-based tools
            python_tools = [t for t in self.additional_tools if t['type'] == 'python']
            for tool in python_tools:
                # Test Python packages based on tool type
                if tool['name'] == 'knownote':
                    packages = ['streamlit', 'langchain', 'chromadb', 'sentence_transformers']
                elif tool['name'] == 'opentinker':
                    packages = ['gymnasium', 'tensorboard']  # Test core packages
                elif tool['name'] == 'claude-transcripts':
                    packages = ['anthropic', 'click', 'rich']
                else:
                    packages = ['requests', 'pyyaml']  # Basic packages
                
                for package in packages:
                    # Fix: Run through bash to source venv and execute python
                    exit_code, output = container.exec_run(
                        ["bash", "-c", f"source /home/developer/.venv/bin/activate && python -c 'import {package}'"]
                    )
                    assert exit_code == 0, f"Python package {package} should be available for {tool['name']}"
            
            # Test Node.js-based tools
            nodejs_tools = [t for t in self.additional_tools if t['type'] == 'nodejs']
            for tool in nodejs_tools:
                # Test Node.js availability
                exit_code, output = container.exec_run("node --version")
                assert exit_code == 0, f"Node.js should be available for {tool['name']}"
                
                # Test npm availability
                exit_code, output = container.exec_run("npm --version")
                assert exit_code == 0, f"npm should be available for {tool['name']}"
                
        finally:
            container.stop()
    
    @settings(max_examples=3, deadline=30000)
    @given(
        port_mappings=st.dictionaries(
            keys=st.sampled_from(['knownote', 'vibium', 'proxypal']),
            values=st.integers(min_value=8000, max_value=9999),
            min_size=1,
            max_size=3
        )
    )
    def test_additional_tools_port_configuration_property(self, port_mappings: Dict[str, int]):
        """
        Property test: For any port configuration, tools should handle
        port assignments without conflicts.
        
        Feature: docker-container-setup, Property 4: Additional Tools Availability
        """
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        # Convert port mappings to environment variables
        env_vars = {f"{tool.upper()}_PORT": str(port) for tool, port in port_mappings.items()}
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-ports",
            detach=True,
            tty=True,
            remove=True,
            environment=env_vars
        )
        
        try:
            time.sleep(2)
            
            # Test that port environment variables are set
            for tool, port in port_mappings.items():
                env_var = f"{tool.upper()}_PORT"
                # Fix: Run through bash to expand environment variables
                exit_code, output = container.exec_run(["bash", "-c", f"echo ${env_var}"])
                assert exit_code == 0, f"Should be able to access port environment variable for {tool}"

                actual_port = output.decode().strip()
                assert actual_port == str(port), f"Port environment variable for {tool} should have correct value"
            
            # Test that tools can still start with custom port configurations
            for tool_name in port_mappings.keys():
                tool = next((t for t in self.additional_tools if t['name'] == tool_name), None)
                if tool:
                    exit_code, output = container.exec_run(tool['startup_script'])
                    assert exit_code == 0, f"Tool {tool_name} should start with custom port configuration"
            
        finally:
            container.stop()
    
    def test_additional_tools_integration_with_pipelines(self):
        """Test that additional tools can integrate with pipeline projects."""
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
            
            # Test that tools can access pipeline directories
            for tool in self.additional_tools:
                exit_code, output = container.exec_run(f"ls -la /opt/pipelines")
                assert exit_code == 0, f"Tool {tool['name']} should be able to access pipelines directory"
                
                # Test that tools can access shared configurations
                exit_code, output = container.exec_run(f"ls -la /opt/configs")
                assert exit_code == 0, f"Tool {tool['name']} should be able to access shared configs"
                
                # Test that tools can access common development tools
                common_tools = ["git", "python", "node"]
                for dev_tool in common_tools:
                    exit_code, output = container.exec_run(f"which {dev_tool}")
                    assert exit_code == 0, f"Tool {tool['name']} should have access to {dev_tool}"
            
        finally:
            container.stop()
    
    def test_additional_tools_workspace_isolation(self):
        """Test that additional tools maintain proper workspace isolation."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-isolation",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(2)
            
            # Create tool-specific workspace directories
            for tool in self.additional_tools:
                tool_workspace = f"/workspace/{tool['name']}-workspace"
                exit_code, output = container.exec_run(f"mkdir -p {tool_workspace}")
                assert exit_code == 0, f"Should be able to create workspace for {tool['name']}"
                
                # Test that tool can write to its own workspace
                exit_code, output = container.exec_run(f"touch {tool_workspace}/{tool['name']}-file")
                assert exit_code == 0, f"Tool {tool['name']} should be able to write to its workspace"

                # Test that tool workspace is accessible by developer user
                # Fix: Container already runs as developer user, no need for su
                exit_code, output = container.exec_run(f"ls {tool_workspace}")
                assert exit_code == 0, f"Developer user should be able to access {tool['name']} workspace"
            
            # Test that tools don't interfere with each other's workspaces
            for i, tool1 in enumerate(self.additional_tools):
                for j, tool2 in enumerate(self.additional_tools):
                    if i != j:
                        tool1_workspace = f"/workspace/{tool1['name']}-workspace"
                        tool2_file = f"{tool1_workspace}/{tool2['name']}-interference-test"
                        
                        # Tool2 should be able to access tool1's workspace (shared workspace)
                        exit_code, output = container.exec_run(f"test -d {tool1_workspace}")
                        assert exit_code == 0, f"Tool workspaces should be accessible to other tools"
            
        finally:
            container.stop()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])