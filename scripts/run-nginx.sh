#!/bin/bash

# Simple Nginx Runner for Container Environment
# This script runs Nginx directly without systemd

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

echo -e "${GREEN}Nginx Runner for Container Environment${NC}"
echo "========================================"

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    print_error "Nginx is not installed. Please run setup-nginx-container.sh first."
    exit 1
fi

# Check if nginx is already running
if pgrep nginx > /dev/null; then
    print_warning "Nginx is already running"
    print_status "Stopping existing nginx processes..."
    pkill nginx || true
    sleep 2
fi

# Test configuration
print_status "Testing nginx configuration..."
if ! nginx -t; then
    print_error "Nginx configuration test failed"
    exit 1
fi

# Start nginx
print_status "Starting nginx..."
nginx

# Check if nginx started successfully
sleep 2
if pgrep nginx > /dev/null; then
    print_status "Nginx started successfully"
    
    # Show process information
    print_status "Nginx processes:"
    ps aux | grep nginx | grep -v grep
    
    # Check ports
    print_status "Checking port status..."
    if netstat -tlnp 2>/dev/null | grep -q ":80"; then
        print_status "✓ Port 80 (HTTP) is listening"
    else
        print_warning "✗ Port 80 is not listening"
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q ":1935"; then
        print_status "✓ Port 1935 (RTMP) is listening"
    else
        print_warning "✗ Port 1935 is not listening"
    fi
    
    # Show access information
    echo ""
    echo -e "${GREEN}Nginx is running!${NC}"
    echo "=================="
    echo "Application URL: http://localhost:80"
    echo "RTMP Server: rtmp://localhost:1935/live"
    echo "HLS Stream: http://localhost/hls"
    echo "RTMP Stats: http://localhost/stat"
    echo ""
    echo "To stop nginx: nginx -s stop"
    echo "To reload config: nginx -s reload"
    echo "To test config: nginx -t"
    
else
    print_error "Nginx failed to start"
    print_warning "Checking nginx error logs..."
    if [ -f "/var/log/nginx/error.log" ]; then
        tail -n 10 /var/log/nginx/error.log
    fi
    exit 1
fi