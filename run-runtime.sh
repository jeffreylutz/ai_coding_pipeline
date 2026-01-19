#!/bin/bash
# run-runtime.sh - Stop, remove, and start the Agentic Coding Pipeline runtime container using docker compose
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Container configuration - these will override compose.yml defaults via environment variables
export CONTAINER_NAME="agentic-runtime-container"
export IMAGE_NAME="agentic-coding-runtime:latest"
export BUILD_TARGET="runtime"
export COMPOSE_COMMAND="/usr/bin/supervisord -c /etc/supervisor/supervisord.conf"
export WORKDIR="/home/ubuntu"
COMPOSE_FILE="compose.yml"

# Ensure workspace directory exists
WORKSPACE_DIR="$(pwd)/workspace"
mkdir -p "$WORKSPACE_DIR"

echo -e "${BLUE}=== Agentic Coding Pipeline - runtime Container Manager ===${NC}"
echo ""
echo -e "${BLUE}Using compose file: ${COMPOSE_FILE}${NC}"
echo -e "${BLUE}Image: ${IMAGE_NAME}${NC}"
echo -e "${BLUE}Container: ${CONTAINER_NAME}${NC}"
echo ""

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}Error: Compose file ${COMPOSE_FILE} not found!${NC}"
    exit 1
fi

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
    echo -e "${YELLOW}Please build the runtime image first using: ./build-runtime.sh${NC}"
    exit 1
fi

# Stop and remove existing container using docker compose
if container_exists; then
    echo -e "${YELLOW}Stopping and removing existing container using docker compose...${NC}"
    docker compose -f "$COMPOSE_FILE" down --timeout 10 2>/dev/null || true
    echo -e "${GREEN}Container stopped and removed successfully${NC}"
else
    echo -e "${BLUE}No existing container to remove${NC}"
fi

echo ""
echo -e "${BLUE}Starting new runtime container with docker compose...${NC}"
echo ""

# Start the container with docker compose
docker compose -f "$COMPOSE_FILE" up -d

# Wait for container to start
sleep 2

# Check if container started successfully
if container_running; then
    echo ""
    echo -e "${GREEN}=== runtime Container Started Successfully ===${NC}"
    echo ""
    echo "Container Name: ${CONTAINER_NAME}"
    echo "Image: ${IMAGE_NAME}"
    echo "Workspace: ${WORKSPACE_DIR}"
    echo ""
    echo -e "${BLUE}Desktop Environment Access:${NC}"
    echo "  VNC Server:   localhost:5901"
    echo "  VNC Password: ubuntu"
    echo "  NoVNC Web:    http://localhost:6080/vnc.html"
    echo "  xRDP Server:  localhost:3389 (RDP protocol)"
    echo "  xRDP User:    ubuntu"
    echo ""
    echo -e "${BLUE}Container Management (Docker Compose):${NC}"
    echo "  View logs:          CONTAINER_NAME=${CONTAINER_NAME} docker compose logs -f"
    echo "  Access container:   CONTAINER_NAME=${CONTAINER_NAME} docker compose exec agentic-coding-pipeline bash"
    echo "  Stop container:     CONTAINER_NAME=${CONTAINER_NAME} docker compose stop"
    echo "  Restart container:  CONTAINER_NAME=${CONTAINER_NAME} docker compose restart"
    echo "  Stop and remove:    CONTAINER_NAME=${CONTAINER_NAME} docker compose down"
    echo ""
    echo -e "${BLUE}Alternative (Direct Docker Commands):${NC}"
    echo "  View logs:          docker logs -f ${CONTAINER_NAME}"
    echo "  Access container:   docker exec -it ${CONTAINER_NAME} bash"
    echo ""
    echo -e "${BLUE}What's Included in runtime Image:${NC}"
    echo "  - Ubuntu 24.04 LTS"
    echo "  - IceWM desktop environment"
    echo "  - VNC and NoVNC servers"
    echo "  - xRDP server (Remote Desktop Protocol)"
    echo "  - Essential development tools (git, vim, curl, etc.)"
    echo "  - Supervisor for service management"
    echo ""
    echo -e "${GREEN}Container is ready! Desktop services are starting...${NC}"
    echo -e "${YELLOW}Note: Desktop may take 10-15 seconds to fully initialize${NC}"
    echo ""
    echo -e "${BLUE}To check desktop status inside container:${NC}"
    echo "  docker exec -it ${CONTAINER_NAME} desktop-status.sh"
    echo ""
    echo -e "${BLUE}Kiro IDE Configuration:${NC}"
    echo "  Set environment variables in ${COMPOSE_FILE} under 'environment:' section:"
    echo "    - KIRO_START_URL=https://your-kiro-url.com"
    echo "    - KIRO_AWS_REGION=us-east-1"
    echo "  Or export before running this script:"
    echo "    export KIRO_START_URL=https://your-kiro-url.com"
    echo "    export KIRO_AWS_REGION=us-east-1"
    echo "    ./run-runtime.sh"
else
    echo ""
    echo -e "${RED}=== Container Failed to Start ===${NC}"
    echo ""
    echo "Check container logs:"
    echo "  CONTAINER_NAME=${CONTAINER_NAME} docker compose logs"
    echo "  docker logs ${CONTAINER_NAME}"
    exit 1
fi

which say && say "Launched runtime image container"