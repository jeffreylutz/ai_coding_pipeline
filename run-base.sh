#!/bin/bash
# run-base.sh - Stop, remove, and start the Agentic Coding Pipeline base container
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Container configuration
CONTAINER_NAME="agentic-base-container"
IMAGE_NAME="agentic-coding-base:latest"

# Ensure workspace directory exists
WORKSPACE_DIR="$(pwd)/workspace"
mkdir -p "$WORKSPACE_DIR"

echo -e "${BLUE}=== Agentic Coding Pipeline - Base Container Manager ===${NC}"
echo ""

# Function to check if container exists
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Function to check if container is running
container_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Check if image exists
if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
    echo -e "${RED}Error: Image ${IMAGE_NAME} not found!${NC}"
    echo -e "${YELLOW}Please build the base image first using: ./build-base.sh${NC}"
    exit 1
fi

# Stop the container if it's running
if container_running; then
    echo -e "${YELLOW}Stopping running container: ${CONTAINER_NAME}...${NC}"
    docker stop "${CONTAINER_NAME}" --time 10
    echo -e "${GREEN}Container stopped successfully${NC}"
else
    echo -e "${BLUE}Container is not currently running${NC}"
fi

# Remove the container if it exists
if container_exists; then
    echo -e "${YELLOW}Removing existing container: ${CONTAINER_NAME}...${NC}"
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
    echo -e "${GREEN}Container removed successfully${NC}"
else
    echo -e "${BLUE}No existing container to remove${NC}"
fi

echo ""
echo -e "${BLUE}Starting new base container...${NC}"
echo ""

# Start the container with docker run
# Using --privileged for desktop environment capabilities
# Start supervisord to manage VNC and NoVNC services
docker run -d \
    --name "${CONTAINER_NAME}" \
    --hostname agentic-base \
    -p 5901:5901 \
    -p 6080:6080 \
    -v "${WORKSPACE_DIR}:/workspace" \
    --restart unless-stopped \
    "${IMAGE_NAME}" \
    /usr/bin/supervisord -c /etc/supervisor/supervisord.conf

# Wait for container to start
sleep 2

# Check if container started successfully
if container_running; then
    echo ""
    echo -e "${GREEN}=== Base Container Started Successfully ===${NC}"
    echo ""
    echo "Container Name: ${CONTAINER_NAME}"
    echo "Image: ${IMAGE_NAME}"
    echo "Workspace: ${WORKSPACE_DIR}"
    echo ""
    echo -e "${BLUE}Desktop Environment Access:${NC}"
    echo "  VNC Server:   localhost:5901"
    echo "  VNC Password: ubuntu"
    echo "  NoVNC Web:    http://localhost:6080/vnc.html"
    echo ""
    echo -e "${BLUE}Container Management:${NC}"
    echo "  View logs:          docker logs -f ${CONTAINER_NAME}"
    echo "  Access container:   docker exec -it ${CONTAINER_NAME} bash"
    echo "  Stop container:     docker stop ${CONTAINER_NAME}"
    echo "  Remove container:   docker rm -f ${CONTAINER_NAME}"
    echo ""
    echo -e "${BLUE}What's Included in Base Image:${NC}"
    echo "  - Ubuntu 24.04 LTS"
    echo "  - IceWM desktop environment"
    echo "  - VNC and NoVNC servers"
    echo "  - Essential development tools (git, vim, curl, etc.)"
    echo "  - Supervisor for service management"
    echo ""
    echo -e "${GREEN}Container is ready! Desktop services are starting...${NC}"
    echo -e "${YELLOW}Note: Desktop may take 10-15 seconds to fully initialize${NC}"
    echo ""
    echo -e "${BLUE}To check desktop status inside container:${NC}"
    echo "  docker exec -it ${CONTAINER_NAME} desktop-status.sh"
else
    echo ""
    echo -e "${RED}=== Container Failed to Start ===${NC}"
    echo ""
    echo "Check container logs:"
    echo "  docker logs ${CONTAINER_NAME}"
    exit 1
fi
