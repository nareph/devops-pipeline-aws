#!/bin/bash

# Test script for Blue/Green deployment pattern
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Blue/Green Deployment Test    ${NC}"
echo -e "${BLUE}================================${NC}"

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        exit 1
    fi
}

# Check prerequisites
check_command docker
check_command curl

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up containers...${NC}"
    docker stop rust-api-blue rust-api-green 2>/dev/null
    docker rm rust-api-blue rust-api-green 2>/dev/null
    echo -e "${GREEN}Cleanup complete${NC}"
}

# Trap Ctrl+C and cleanup
trap cleanup EXIT INT TERM

# Build the Docker image
echo -e "\n${BLUE}[1/7] Building Docker image...${NC}"
docker build -t rust-api:test app

# Check image size
echo -e "\n${BLUE}Image size:${NC}"
docker image inspect rust-api:test --format='{{.Size}}' | \
  awk '{printf "   %.1f MB\n", $1/1024/1024}'

# Remove any existing containers
cleanup

# Start BLUE deployment
echo -e "\n${BLUE}[2/7] Starting BLUE deployment (port 8080)...${NC}"
docker run -d \
  --name rust-api-blue \
  -p 8080:8080 \
  -e DEPLOYMENT_SLOT=blue \
  -e PORT=8080 \
  -e APP_VERSION=0.1.0 \
  rust-api:test

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start BLUE container${NC}"
    exit 1
fi
echo -e "${GREEN}✓ BLUE container started${NC}"

# Start GREEN deployment
echo -e "\n${BLUE}[3/7] Starting GREEN deployment (port 8081)...${NC}"
docker run -d \
  --name rust-api-green \
  -p 8081:8080 \
  -e DEPLOYMENT_SLOT=green \
  -e PORT=8080 \
  -e APP_VERSION=0.1.0 \
  rust-api:test

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to start GREEN container${NC}"
    exit 1
fi
echo -e "${GREEN}✓ GREEN container started${NC}"

# Wait for services to be ready
echo -e "\n${BLUE}[4/7] Waiting for services to start (5 seconds)...${NC}"
sleep 5

# Test BLUE deployment
echo -e "\n${BLUE}[5/7] Testing BLUE deployment (http://localhost:8080)...${NC}"
BLUE_RESPONSE=$(curl -s http://localhost:8080/health)
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ BLUE is responding${NC}"
    echo -e "   Response: ${YELLOW}$BLUE_RESPONSE${NC}"

    # Check if it's actually BLUE
    if [[ $BLUE_RESPONSE == *"blue"* ]]; then
        echo -e "   ${GREEN}✓ Correct slot: blue${NC}"
    else
        echo -e "   ${RED}✗ Wrong slot! Expected 'blue'${NC}"
    fi
else
    echo -e "${RED}✗ Failed to connect to BLUE${NC}"
fi

# Test GREEN deployment
echo -e "\n${BLUE}[6/7] Testing GREEN deployment (http://localhost:8081)...${NC}"
GREEN_RESPONSE=$(curl -s http://localhost:8081/health)
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ GREEN is responding${NC}"
    echo -e "   Response: ${YELLOW}$GREEN_RESPONSE${NC}"

    # Check if it's actually GREEN
    if [[ $GREEN_RESPONSE == *"green"* ]]; then
        echo -e "   ${GREEN}✓ Correct slot: green${NC}"
    else
        echo -e "   ${RED}✗ Wrong slot! Expected 'green'${NC}"
    fi
else
    echo -e "${RED}✗ Failed to connect to GREEN${NC}"
fi

# Show container logs
echo -e "\n${BLUE}[7/7] Container logs:${NC}"
echo -e "\n${YELLOW}--- BLUE container logs (last 5 lines) ---${NC}"
docker logs rust-api-blue --tail 5

echo -e "\n${YELLOW}--- GREEN container logs (last 5 lines) ---${NC}"
docker logs rust-api-green --tail 5

# Summary
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}          Test Summary           ${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "BLUE:  http://localhost:8080/health"
echo -e "GREEN: http://localhost:8081/health"
echo -e "\n${YELLOW}To test manually:${NC}"
echo "  curl http://localhost:8080/health"
echo "  curl http://localhost:8081/health"
echo -e "\n${YELLOW}To stop containers:${NC}"
echo "  docker stop rust-api-blue rust-api-green"
echo "  docker rm rust-api-blue rust-api-green"

# Ask if user wants to keep containers running
echo -e "\n${BLUE}Keep containers running? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^[Nn]$ ]]; then
    cleanup
else
    echo -e "\n${GREEN}Containers are still running.${NC}"
    echo "Use './test-blue-green.sh' again to rerun tests"
    echo "Use 'docker logs rust-api-blue' to view logs"
fi
