#!/bin/bash
# run.sh - Stop, remove, and start the Agentic Coding Pipeline container
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Container configuration
CONTAINER_NAME="agentic-coding-container"
IMAGE_NAME="agentic-coding-pipeline:latest"
COMPOSE_FILE="docker-compose.yml"

echo -e "${BLUE}=== Agentic Coding Pipeline Container Manager ===${NC}"
echo ""

# Check if docker-compose.yml exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}Error: $COMPOSE_FILE not found!${NC}"
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

# Stop the container if it's running
if container_running; then
    echo -e "${YELLOW}Stopping running container: ${CONTAINER_NAME}...${NC}"
    docker-compose down --timeout 30
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
echo -e "${BLUE}Starting new container...${NC}"
echo ""

# Start the container with docker-compose
docker-compose up -d

echo ""
echo -e "${GREEN}=== Container Started Successfully ===${NC}"
echo ""
echo "Container Name: ${CONTAINER_NAME}"
echo "Image: ${IMAGE_NAME}"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f"
echo ""
echo "To access the container:"
echo "  docker exec -it ${CONTAINER_NAME} bash"
echo ""
echo "To stop the container:"
echo "  docker-compose down"
echo ""
echo -e "${GREEN}Container is ready for development!${NC}"
