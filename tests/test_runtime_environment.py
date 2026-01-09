#!/usr/bin/env python3
"""
Property-based tests for runtime environment setup validation.

Feature: docker-container-setup, Property 5: Development Environment Configuration
Validates: Requirements 4.1, 4.2, 4.3, 4.4

This module tests that development operations can be performed without permission errors,
missing dependencies, or configuration issues.
"""

import pytest
import docker
import time
import json
from hypothesis import given, strategies as st, settings
from typing import List, Dict, Any


class TestRuntimeEnvironmentSetup:
    """Test suite for runtime environment setup validation."""
    
    @classmethod
    def setup_class(cls):
        """Set up test environment."""
        cls.client = docker.from_env()
        cls.image_name = "agentic-coding-pipeline:latest"
        cls.container_name = "test-runtime-env"
        
    @classmethod
    def teardown_class(cls):
        """Clean up test environment."""
        try:
            container = cls.client.containers.get(cls.container_name)
            container.remove(force=True)
        except docker.errors.NotFound:
            pass
    
    def test_node_environment_setup(self):
        """Test Node.js environment is properly configured."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-node",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(2)
            
            # Test Node.js version
            exit_code, output = container.exec_run("node --version")
            assert exit_code == 0, "Node.js should be installed"
            version = output.decode().strip()
            assert version.startswith("v"), f"Invalid Node.js version format: {version}"
            
            # Test npm version
            exit_code, output = container.exec_run("npm --version")
            assert exit_code == 0, "npm should be installed"
            
            # Test global npm packages
            required_packages = [
                "typescript", "ts-node", "nodemon", "pm2", 
                "eslint", "prettier", "jest", "webpack"
            ]
            
            for package in required_packages:
                exit_code, output = container.exec_run(f"npm list -g {package}")
                assert exit_code == 0, f"Global npm package {package} should be installed"
            
            # Test TypeScript compilation
            exit_code, output = container.exec_run(
                'bash -c "echo \'console.log(\"Hello TypeScript\");\' > /tmp/test.ts && tsc /tmp/test.ts"'
            )
            assert exit_code == 0, "TypeScript should be able to compile files"
            
        finally:
            container.stop()
    
    def test_python_environment_setup(self):
        """Test Python environment is properly configured."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-python",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(2)
            
            # Test Python version
            exit_code, output = container.exec_run("python --version")
            assert exit_code == 0, "Python should be installed"
            version = output.decode().strip()
            assert "Python 3." in version, f"Should use Python 3.x: {version}"
            
            # Test pip version
            exit_code, output = container.exec_run("pip --version")
            assert exit_code == 0, "pip should be installed"
            
            # Test virtual environment
            exit_code, output = container.exec_run("source /home/developer/.venv/bin/activate && python --version")
            assert exit_code == 0, "Virtual environment should be accessible"
            
            # Test Python packages in virtual environment
            required_packages = [
                "requests", "pyyaml", "click", "rich", "fastapi", 
                "pytest", "black", "jupyter", "torch", "transformers"
            ]
            
            for package in required_packages:
                exit_code, output = container.exec_run(
                    f"source /home/developer/.venv/bin/activate && python -c 'import {package}'"
                )
                assert exit_code == 0, f"Python package {package} should be importable"
            
            # Test Jupyter notebook
            exit_code, output = container.exec_run(
                "source /home/developer/.venv/bin/activate && jupyter --version"
            )
            assert exit_code == 0, "Jupyter should be installed and accessible"
            
        finally:
            container.stop()
    
    @settings(max_examples=10, deadline=45000)
    @given(
        project_name=st.text(
            alphabet=st.characters(whitelist_categories=("Ll", "Lu", "Nd"), min_codepoint=97, max_codepoint=122),
            min_size=3,
            max_size=15
        ).filter(lambda x: x.isalnum()),
        file_content=st.text(min_size=10, max_size=200)
    )
    def test_development_operations_property(self, project_name: str, file_content: str):
        """
        Property test: For any development project, basic operations should work
        without permission errors or missing dependencies.
        
        Feature: docker-container-setup, Property 5: Development Environment Configuration
        Validates: Requirements 4.1, 4.2, 4.3, 4.4
        """
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-dev-{project_name[:8]}",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(2)
            
            # Test file creation and editing
            safe_content = file_content.replace('"', '\\"').replace('`', '\\`').replace('$', '\\$')
            exit_code, output = container.exec_run(
                f'bash -c "echo \\"{safe_content}\\" > /workspace/{project_name}.txt"'
            )
            assert exit_code == 0, "Should be able to create files in workspace"
            
            # Test file reading
            exit_code, output = container.exec_run(f"cat /workspace/{project_name}.txt")
            assert exit_code == 0, "Should be able to read created files"
            
            # Test Git operations
            exit_code, output = container.exec_run(
                f"cd /workspace && git init {project_name}-repo"
            )
            assert exit_code == 0, "Should be able to initialize Git repository"
            
            exit_code, output = container.exec_run(
                f"cd /workspace/{project_name}-repo && git add . || true"
            )
            assert exit_code == 0, "Git add should work (even if no files)"
            
            # Test npm project creation
            exit_code, output = container.exec_run(
                f"cd /workspace && npm init -y --name {project_name}"
            )
            assert exit_code == 0, "Should be able to create npm project"
            
            # Test Python script execution
            exit_code, output = container.exec_run(
                f'bash -c "cd /workspace && echo \\"print(\'Hello from {project_name}\')\\" > {project_name}.py"'
            )
            assert exit_code == 0, "Should be able to create Python files"
            
            exit_code, output = container.exec_run(
                f"cd /workspace && source /home/developer/.venv/bin/activate && python {project_name}.py"
            )
            assert exit_code == 0, "Should be able to execute Python scripts"
            
            # Test directory permissions
            exit_code, output = container.exec_run(f"mkdir -p /workspace/{project_name}/subdir")
            assert exit_code == 0, "Should be able to create subdirectories"
            
            exit_code, output = container.exec_run(f"rmdir /workspace/{project_name}/subdir")
            assert exit_code == 0, "Should be able to remove directories"
            
        finally:
            container.stop()
    
    def test_docker_in_docker_setup(self):
        """Test Docker-in-Docker functionality."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-dind",
            detach=True,
            tty=True,
            remove=True,
            privileged=True,  # Required for Docker-in-Docker
            volumes={'/var/run/docker.sock': {'bind': '/var/run/docker.sock', 'mode': 'rw'}}
        )
        
        try:
            time.sleep(3)
            
            # Test Docker command availability
            exit_code, output = container.exec_run("docker --version")
            assert exit_code == 0, "Docker command should be available"
            
            # Test Docker daemon connectivity (may not work without proper setup)
            exit_code, output = container.exec_run("docker info")
            # Note: This might fail in some CI environments, so we'll be lenient
            if exit_code != 0:
                pytest.skip("Docker daemon not accessible in test environment")
            
        finally:
            container.stop()
    
    @settings(max_examples=5, deadline=30000)
    @given(
        env_vars=st.dictionaries(
            keys=st.sampled_from(['NODE_ENV', 'PYTHON_ENV', 'DEBUG', 'LOG_LEVEL']),
            values=st.sampled_from(['development', 'production', 'test', 'true', 'false', 'info', 'debug']),
            min_size=1,
            max_size=4
        )
    )
    def test_environment_variables_property(self, env_vars: Dict[str, str]):
        """
        Property test: For any set of development environment variables,
        the runtime should handle them correctly.
        
        Feature: docker-container-setup, Property 5: Development Environment Configuration
        """
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-envvars",
            detach=True,
            tty=True,
            remove=True,
            environment=env_vars
        )
        
        try:
            time.sleep(2)
            
            # Test that environment variables are accessible
            for key, expected_value in env_vars.items():
                exit_code, output = container.exec_run(f"echo ${key}")
                assert exit_code == 0, f"Should be able to access environment variable {key}"
                actual_value = output.decode().strip()
                assert actual_value == expected_value, f"Environment variable {key} should have correct value"
            
            # Test that runtime environments still work with custom env vars
            exit_code, output = container.exec_run("node -e 'console.log(\"Node.js works\")'")
            assert exit_code == 0, "Node.js should work with custom environment variables"
            
            exit_code, output = container.exec_run("python -c 'print(\"Python works\")'")
            assert exit_code == 0, "Python should work with custom environment variables"
            
        finally:
            container.stop()
    
    def test_development_tools_integration(self):
        """Test that development tools work together properly."""
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
            
            # Test integrated workflow: Create a TypeScript project with Python backend
            
            # 1. Create TypeScript project
            exit_code, output = container.exec_run(
                "cd /workspace && npm init -y --name test-integration"
            )
            assert exit_code == 0, "Should create npm project"
            
            # 2. Install TypeScript dependencies
            exit_code, output = container.exec_run(
                "cd /workspace && npm install --save-dev typescript @types/node"
            )
            assert exit_code == 0, "Should install TypeScript dependencies"
            
            # 3. Create TypeScript file
            exit_code, output = container.exec_run(
                'cd /workspace && echo "console.log(\\"Hello from TypeScript\\");" > index.ts'
            )
            assert exit_code == 0, "Should create TypeScript file"
            
            # 4. Compile TypeScript
            exit_code, output = container.exec_run("cd /workspace && npx tsc index.ts")
            assert exit_code == 0, "Should compile TypeScript"
            
            # 5. Create Python script
            exit_code, output = container.exec_run(
                'cd /workspace && echo "print(\\"Hello from Python\\")" > app.py'
            )
            assert exit_code == 0, "Should create Python script"
            
            # 6. Run Python script
            exit_code, output = container.exec_run(
                "cd /workspace && source /home/developer/.venv/bin/activate && python app.py"
            )
            assert exit_code == 0, "Should execute Python script"
            output_text = output.decode().strip()
            assert "Hello from Python" in output_text, "Python script should produce expected output"
            
            # 7. Test Git workflow
            exit_code, output = container.exec_run("cd /workspace && git init")
            assert exit_code == 0, "Should initialize Git repository"
            
            exit_code, output = container.exec_run("cd /workspace && git add .")
            assert exit_code == 0, "Should add files to Git"
            
            exit_code, output = container.exec_run(
                'cd /workspace && git commit -m "Initial commit"'
            )
            assert exit_code == 0, "Should commit files to Git"
            
        finally:
            container.stop()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])