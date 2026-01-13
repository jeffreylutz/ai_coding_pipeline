#!/usr/bin/env python3
"""
Integration tests for the complete agentic coding pipeline container system.

This module tests the full system integration including build process,
container startup, service availability, and end-to-end functionality.
"""

import pytest
import docker
import subprocess
import time
import os
import tempfile
from typing import Dict, List


class TestFullSystemIntegration:
    """Integration test suite for the complete system."""
    
    @classmethod
    def setup_class(cls):
        """Set up integration test environment."""
        cls.client = docker.from_env()
        cls.image_name = "agentic-coding-pipeline:latest"
        cls.container_name = "integration-test-container"
        
    @classmethod
    def teardown_class(cls):
        """Clean up integration test environment."""
        try:
            container = cls.client.containers.get(cls.container_name)
            container.remove(force=True)
        except docker.errors.NotFound:
            pass
    
    def test_complete_build_process(self):
        """Test the complete Docker build process from scratch."""
        if not os.path.exists("Dockerfile"):
            pytest.skip("Dockerfile not found")
        
        # Remove existing image to test fresh build
        try:
            self.client.images.remove(f"{self.image_name}-integration", force=True)
        except docker.errors.ImageNotFound:
            pass
        
        # Build the image
        start_time = time.time()
        try:
            image, build_logs = self.client.images.build(
                path=".",
                tag=f"{self.image_name}-integration",
                rm=True,
                forcerm=True,
                nocache=False  # Allow caching for faster builds
            )
            build_time = time.time() - start_time
            
            assert image is not None, "Build should produce a valid image"
            assert build_time < 3600, f"Build should complete within 1 hour, took {build_time:.2f}s"
            
            # Verify image properties
            image.reload()
            assert image.attrs['Size'] > 0, "Image should have non-zero size"
            
            # Test image size is reasonable
            image_size_gb = image.attrs['Size'] / (1024 ** 3)
            assert image_size_gb < 10, f"Image size should be under 10GB, actual: {image_size_gb:.2f}GB"
            
        except docker.errors.BuildError as e:
            pytest.fail(f"Docker build failed: {e}")
        finally:
            # Cleanup integration image
            try:
                self.client.images.remove(f"{self.image_name}-integration", force=True)
            except:
                pass
    
    def test_container_full_startup_sequence(self):
        """Test the complete container startup sequence and readiness."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        # Start container and monitor startup
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-startup",
            detach=True,
            tty=True,
            remove=True,
            environment={
                "WORKSPACE_DIR": "/workspace",
                "LOG_LEVEL": "info"
            }
        )
        
        try:
            # Wait for container to be ready
            max_wait_time = 60
            start_time = time.time()
            ready = False
            
            while time.time() - start_time < max_wait_time and not ready:
                try:
                    container.reload()
                    if container.status == "running":
                        # Test if startup script has completed
                        exit_code, output = container.exec_run("agentic-status", timeout=10)
                        if exit_code == 0:
                            ready = True
                        else:
                            time.sleep(2)
                    else:
                        time.sleep(2)
                except Exception:
                    time.sleep(2)
            
            assert ready, f"Container should be ready within {max_wait_time} seconds"
            
            # Verify all essential services are available
            essential_services = [
                ("python", "python --version"),
                ("node", "node --version"),
                ("npm", "npm --version"),
                ("git", "git --version"),
                ("docker", "docker --version")
            ]
            
            for service_name, command in essential_services:
                exit_code, output = container.exec_run(command)
                assert exit_code == 0, f"Service {service_name} should be available"
                assert len(output.decode().strip()) > 0, f"Service {service_name} should return version info"
            
        finally:
            container.stop()
    
    def test_all_pipeline_projects_integration(self):
        """Test that all pipeline projects are properly integrated and functional."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-pipelines",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(3)
            
            pipeline_projects = [
                ("kiro", "/opt/pipelines/kiro/start-kiro.sh"),
                ("auto-claude", "/opt/pipelines/auto-claude/start-auto-claude.sh"),
                ("continuous-claude", "/opt/pipelines/continuous-claude/start-continuous-claude.sh"),
                ("automaker", "/opt/pipelines/automaker/start-automaker.sh"),
                ("infiagent", "/opt/pipelines/infiagent/start-infiagent.sh"),
                ("mai-ui", "/opt/pipelines/mai-ui/start-mai-ui.sh"),
                ("loki-mode", "/opt/pipelines/loki-mode/start-loki-mode.sh")
            ]
            
            for project_name, startup_script in pipeline_projects:
                # Test project directory exists
                exit_code, output = container.exec_run(f"test -d /opt/pipelines/{project_name}")
                assert exit_code == 0, f"Pipeline project {project_name} directory should exist"
                
                # Test startup script exists and is executable
                exit_code, output = container.exec_run(f"test -x {startup_script}")
                assert exit_code == 0, f"Startup script for {project_name} should be executable"
                
                # Test startup script runs without errors
                # Fix: Use list format for consistent script execution
                exit_code, output = container.exec_run(["bash", "-c", startup_script])
                assert exit_code == 0, f"Startup script for {project_name} should execute successfully"
                
                # Test configuration exists
                config_patterns = [
                    f"/opt/configs/{project_name}/config.json",
                    f"/opt/configs/{project_name}/config.yaml",
                    f"/opt/configs/{project_name}/*.yaml",
                    f"/opt/configs/{project_name}/*.json"
                ]
                
                config_found = False
                for pattern in config_patterns:
                    # Fix: Use list format for proper shell operator handling
                    exit_code, output = container.exec_run(["bash", "-c", f"ls {pattern} 2>/dev/null || true"])
                    if exit_code == 0 and len(output.decode().strip()) > 0:
                        config_found = True
                        break
                
                assert config_found, f"Configuration file for {project_name} should exist"
            
        finally:
            container.stop()
    
    def test_all_additional_tools_integration(self):
        """Test that all additional tools are properly integrated and functional."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-tools",
            detach=True,
            tty=True,
            remove=True
        )
        
        try:
            time.sleep(3)
            
            additional_tools = [
                ("knownote", "/opt/tools/knownote/start-knownote.sh"),
                ("vibium", "/opt/tools/vibium/start-vibium.sh"),
                ("opentinker", "/opt/tools/opentinker/start-opentinker.sh"),
                ("proxypal", "/opt/tools/proxypal/start-proxypal.sh"),
                ("claude-transcripts", "/opt/tools/claude-transcripts/start-claude-transcripts.sh")
            ]
            
            for tool_name, startup_script in additional_tools:
                # Test tool directory exists
                exit_code, output = container.exec_run(f"test -d /opt/tools/{tool_name}")
                assert exit_code == 0, f"Tool {tool_name} directory should exist"
                
                # Test startup script exists and is executable
                exit_code, output = container.exec_run(f"test -x {startup_script}")
                assert exit_code == 0, f"Startup script for {tool_name} should be executable"
                
                # Test startup script runs without errors
                # Fix: Use list format for consistent script execution
                exit_code, output = container.exec_run(["bash", "-c", startup_script])
                assert exit_code == 0, f"Startup script for {tool_name} should execute successfully"
                
                # Test configuration exists
                config_patterns = [
                    f"/opt/configs/{tool_name}/config.json",
                    f"/opt/configs/{tool_name}/config.yaml"
                ]
                
                config_found = False
                for pattern in config_patterns:
                    exit_code, output = container.exec_run(f"test -f {pattern}")
                    if exit_code == 0:
                        config_found = True
                        break
                
                assert config_found, f"Configuration file for {tool_name} should exist"
            
        finally:
            container.stop()
    
    def test_end_to_end_development_workflow(self):
        """Test a complete end-to-end development workflow."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        # Create a temporary directory for workspace
        with tempfile.TemporaryDirectory() as temp_workspace:
            container = self.client.containers.run(
                self.image_name,
                name=f"{self.container_name}-workflow",
                detach=True,
                tty=True,
                remove=True,
                volumes={temp_workspace: {'bind': '/workspace', 'mode': 'rw'}}
            )
            
            try:
                time.sleep(3)
                
                # Test 1: Create a new project
                exit_code, output = container.exec_run("init-project test-e2e-project mixed")
                assert exit_code == 0, "Should be able to create a new project"
                
                # Verify project was created
                exit_code, output = container.exec_run("test -d /workspace/projects/test-e2e-project")
                assert exit_code == 0, "Project directory should be created"
                
                # Test 2: Work with Python environment
                exit_code, output = container.exec_run(
                    "cd /workspace/projects/test-e2e-project && source /home/developer/.venv/bin/activate && python -c 'print(\"Python works\")'"
                )
                assert exit_code == 0, "Python environment should work in project"
                
                # Test 3: Work with Node.js environment
                exit_code, output = container.exec_run(
                    "cd /workspace/projects/test-e2e-project && node -e 'console.log(\"Node.js works\")'"
                )
                assert exit_code == 0, "Node.js environment should work in project"
                
                # Test 4: Git operations
                exit_code, output = container.exec_run(
                    "cd /workspace/projects/test-e2e-project && git status"
                )
                assert exit_code == 0, "Git should work in project"
                
                # Test 5: Create and run a simple Python script
                exit_code, output = container.exec_run(
                    'cd /workspace/projects/test-e2e-project && echo "print(\\"Hello from E2E test\\")" > test_script.py'
                )
                assert exit_code == 0, "Should be able to create Python script"
                
                exit_code, output = container.exec_run(
                    "cd /workspace/projects/test-e2e-project && source /home/developer/.venv/bin/activate && python test_script.py"
                )
                assert exit_code == 0, "Should be able to run Python script"
                
                script_output = output.decode().strip()
                assert "Hello from E2E test" in script_output, "Python script should produce expected output"
                
                # Test 6: Create and run a simple Node.js script
                exit_code, output = container.exec_run(
                    'cd /workspace/projects/test-e2e-project && echo "console.log(\\"Hello from Node.js E2E test\\");" > test_script.js'
                )
                assert exit_code == 0, "Should be able to create Node.js script"
                
                exit_code, output = container.exec_run(
                    "cd /workspace/projects/test-e2e-project && node test_script.js"
                )
                assert exit_code == 0, "Should be able to run Node.js script"
                
                js_output = output.decode().strip()
                assert "Hello from Node.js E2E test" in js_output, "Node.js script should produce expected output"
                
                # Test 7: Verify files persist in mounted volume
                project_files = os.listdir(os.path.join(temp_workspace, "projects", "test-e2e-project"))
                assert "test_script.py" in project_files, "Python script should persist in workspace"
                assert "test_script.js" in project_files, "Node.js script should persist in workspace"
                
            finally:
                container.stop()
    
    def test_docker_compose_integration(self):
        """Test Docker Compose integration and deployment."""
        if not os.path.exists("compose.yml"):
            pytest.skip("compose.yml not found")
        
        # Test docker-compose configuration
        result = subprocess.run(
            ["docker-compose", "config"],
            capture_output=True,
            text=True,
            cwd="."
        )
        assert result.returncode == 0, f"docker-compose config should be valid: {result.stderr}"
        
        # Test docker-compose build (if build is specified)
        result = subprocess.run(
            ["docker-compose", "config", "--services"],
            capture_output=True,
            text=True,
            cwd="."
        )
        
        if result.returncode == 0:
            services = result.stdout.strip().split('\n')
            assert len(services) > 0, "Should have at least one service defined"
            
            # Test that we can pull/build the services (dry run)
            for service in services:
                if service.strip():
                    result = subprocess.run(
                        ["docker-compose", "config", "--quiet"],
                        capture_output=True,
                        text=True,
                        cwd="."
                    )
                    assert result.returncode == 0, f"Service {service} configuration should be valid"
    
    def test_kubernetes_deployment_integration(self):
        """Test Kubernetes deployment configuration."""
        k8s_file = "kubernetes/deployment.yaml"
        if not os.path.exists(k8s_file):
            pytest.skip("Kubernetes deployment file not found")
        
        # Test YAML syntax
        import yaml
        with open(k8s_file, "r") as f:
            try:
                documents = list(yaml.safe_load_all(f.read()))
                assert len(documents) > 0, "Should have at least one Kubernetes resource"
                
                # Verify resource types
                resource_kinds = [doc.get("kind") for doc in documents if doc]
                expected_kinds = ["Deployment", "Service", "PersistentVolumeClaim"]
                
                for expected_kind in expected_kinds:
                    assert expected_kind in resource_kinds, f"Should have {expected_kind} resource"
                
            except yaml.YAMLError as e:
                pytest.fail(f"Kubernetes YAML is invalid: {e}")
    
    def test_system_resource_usage(self):
        """Test system resource usage under normal operation."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        container = self.client.containers.run(
            self.image_name,
            name=f"{self.container_name}-resources",
            detach=True,
            tty=True,
            remove=True,
            mem_limit="4g",  # Set memory limit for testing
            cpus="2.0"       # Set CPU limit for testing
        )
        
        try:
            time.sleep(5)
            
            # Test memory usage
            exit_code, output = container.exec_run("free -m")
            assert exit_code == 0, "Should be able to check memory usage"
            
            memory_output = output.decode()
            # Extract memory information (basic check)
            assert "Mem:" in memory_output, "Memory information should be available"
            
            # Test CPU usage (basic check)
            exit_code, output = container.exec_run("nproc")
            assert exit_code == 0, "Should be able to check CPU count"
            
            cpu_count = int(output.decode().strip())
            assert cpu_count > 0, "Should have at least one CPU core available"
            
            # Test disk usage
            exit_code, output = container.exec_run("df -h /workspace")
            assert exit_code == 0, "Should be able to check disk usage"
            
            # Test that container is responsive under resource limits
            exit_code, output = container.exec_run("agentic-status")
            assert exit_code == 0, "Container should remain responsive under resource limits"
            
        finally:
            container.stop()
    
    def test_multi_container_compatibility(self):
        """Test running multiple container instances simultaneously."""
        try:
            self.client.images.get(self.image_name)
        except docker.errors.ImageNotFound:
            pytest.skip(f"Docker image {self.image_name} not found. Run build first.")
        
        containers = []
        try:
            # Start multiple container instances
            for i in range(2):
                container = self.client.containers.run(
                    self.image_name,
                    name=f"{self.container_name}-multi-{i}",
                    detach=True,
                    tty=True,
                    remove=True,
                    ports={f"{3000+i}": 3000}  # Map to different host ports
                )
                containers.append(container)
            
            # Wait for containers to start
            time.sleep(5)
            
            # Test that all containers are running
            for i, container in enumerate(containers):
                container.reload()
                assert container.status == "running", f"Container {i} should be running"
                
                # Test basic functionality in each container
                exit_code, output = container.exec_run("agentic-status")
                assert exit_code == 0, f"Container {i} should be functional"
                
                # Test that containers are isolated
                exit_code, output = container.exec_run(f"echo 'container-{i}' > /workspace/container-id.txt")
                assert exit_code == 0, f"Should be able to write to workspace in container {i}"
                
                exit_code, output = container.exec_run("cat /workspace/container-id.txt")
                assert exit_code == 0, f"Should be able to read from workspace in container {i}"
                
                content = output.decode().strip()
                assert f"container-{i}" in content, f"Container {i} should have isolated workspace"
            
        finally:
            # Cleanup all containers
            for container in containers:
                try:
                    container.stop()
                except:
                    pass


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])