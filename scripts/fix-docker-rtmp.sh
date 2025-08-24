#!/bin/bash

# Fix Docker RTMP Service
# This script fixes the Docker RTMP service that failed to start

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${GREEN}Docker RTMP Service Fix${NC}"
echo "============================"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Check if Docker is running
print_status "Checking Docker status..."
if ! sudo systemctl is-active --quiet docker; then
    print_status "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Navigate to project directory
cd /home/ubuntu/scte35-project

# Check if docker-compose file exists
if [ ! -f "docker-compose-rtmp.yml" ]; then
    print_error "docker-compose-rtmp.yml not found"
    exit 1
fi

# Stop existing service if running
print_status "Stopping existing RTMP service..."
sudo systemctl stop rtmp-docker.service 2>/dev/null || true

# Stop existing containers
print_status "Stopping existing containers..."
docker compose -f docker-compose-rtmp.yml down 2>/dev/null || true

# Remove existing containers
print_status "Removing existing containers..."
docker rm -f rtmp-server nginx-proxy 2>/dev/null || true

# Create necessary directories
print_status "Creating directories..."
mkdir -p rtmp/conf rtmp/data rtmp/stat

# Start containers manually first
print_status "Starting RTMP containers..."
docker compose -f docker-compose-rtmp.yml up -d

# Wait for containers to start
print_status "Waiting for containers to start..."
sleep 10

# Check container status
print_status "Checking container status..."
docker ps

# Restart systemd service
print_status "Restarting systemd service..."
sudo systemctl daemon-reload
sudo systemctl enable rtmp-docker.service
sudo systemctl start rtmp-docker.service

# Check service status
print_status "Checking service status..."
sudo systemctl status rtmp-docker.service --no-pager

# Test RTMP functionality
print_status "Testing RTMP functionality..."
sleep 5

if docker ps | grep -q "rtmp-server"; then
    print_status "RTMP server container is running!"
    
    # Check if port 1935 is available
    if sudo netstat -tlnp | grep -q ":1935"; then
        print_status "RTMP port 1935 is listening!"
    else
        print_warning "RTMP port 1935 is not listening. Checking container logs..."
        docker logs rtmp-server
    fi
else
    print_error "RTMP server container failed to start"
    print_warning "Checking container logs..."
    docker logs rtmp-server
    exit 1
fi

echo ""
echo -e "${GREEN}Docker RTMP Service Fix Completed!${NC}"
echo "=========================================="
echo ""
echo "Service Status:"
echo "  RTMP Service: sudo systemctl status rtmp-docker.service"
echo "  Docker Containers: docker ps"
echo ""
echo "Useful Commands:"
echo "  View logs: docker logs rtmp-server"
echo "  Restart service: sudo systemctl restart rtmp-docker.service"
echo "  Stop service: sudo systemctl stop rtmp-docker.service"
echo ""
echo "RTMP Server Information:"
echo "  RTMP URL: rtmp://$(hostname -I | awk '{print $1}'):1935/live"
echo "  HLS URL: http://$(hostname -I | awk '{print $1}')/hls"
echo "  Stats URL: http://$(hostname -I | awk '{print $1}')/stat"
echo ""
echo "Next Steps:"
echo "1. Test RTMP streaming using FFmpeg:"
echo "   ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test"
echo "2. Access HLS stream at: http://localhost/hls/test.m3u8"
echo "3. Continue with your application deployment"
echo ""