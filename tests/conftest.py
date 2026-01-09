"""
Pytest configuration for Docker container tests.
"""

import pytest
import docker
import subprocess
import os


def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "docker: mark test as requiring Docker"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )
    config.addinivalue_line(
        "markers", "integration: mark test as integration test"
    )


@pytest.fixture(scope="session")
def docker_client():
    """Provide Docker client for tests."""
    try:
        client = docker.from_env()
        # Test Docker connection
        client.ping()
        return client
    except Exception as e:
        pytest.skip(f"Docker not available: {e}")


@pytest.fixture(scope="session")
def image_name():
    """Provide the Docker image name for tests."""
    return "agentic-coding-pipeline:latest"


@pytest.fixture(scope="session")
def ensure_image_built(docker_client, image_name):
    """Ensure the Docker image is built before running tests."""
    try:
        docker_client.images.get(image_name)
    except docker.errors.ImageNotFound:
        # Try to build the image
        if os.path.exists("Dockerfile"):
            print(f"Building Docker image {image_name}...")
            result = subprocess.run(
                ["docker", "build", "-t", image_name, "."],
                capture_output=True,
                text=True
            )
            if result.returncode != 0:
                pytest.skip(f"Failed to build Docker image: {result.stderr}")
        else:
            pytest.skip(f"Docker image {image_name} not found and no Dockerfile available")


@pytest.fixture
def test_container(docker_client, image_name, ensure_image_built):
    """Provide a test container that is automatically cleaned up."""
    containers = []
    
    def _create_container(*args, **kwargs):
        container = docker_client.containers.run(
            image_name,
            detach=True,
            tty=True,
            remove=True,
            *args,
            **kwargs
        )
        containers.append(container)
        return container
    
    yield _create_container
    
    # Cleanup
    for container in containers:
        try:
            container.stop()
        except:
            pass