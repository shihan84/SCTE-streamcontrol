#!/bin/bash

# Quick Fix for RTMP Module Issue
# Run this script to fix the "unknown directive 'rtmp'" error

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

echo -e "${GREEN}SCTE-35 RTMP Module Quick Fix${NC}"
echo "=================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Update package list
print_status "Updating package list..."
sudo apt update

# Install RTMP module
print_status "Installing RTMP module for Nginx..."
sudo apt install -y libnginx-mod-rtmp

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    print_status "Installing nginx..."
    sudo apt install -y nginx
fi

# Create RTMP configuration directory
print_status "Creating RTMP configuration directory..."
sudo mkdir -p /etc/nginx/rtmp

# Create RTMP configuration
print_status "Creating RTMP configuration..."
sudo tee /etc/nginx/rtmp/rtmp.conf > /dev/null << 'EOF'
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        allow play all;
        
        application live {
            live on;
            record off;
            
            # HLS configuration
            hls on;
            hls_path /var/www/rtmp/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            
            # DASH configuration
            dash on;
            dash_path /var/www/rtmp/dash;
            dash_fragment 3;
            dash_playlist_length 60;
            
            # SCTE-35 support
            on_publish http://localhost:3000/api/rtmp/on-publish;
            on_play http://localhost:3000/api/rtmp/on-play;
            on_publish_done http://localhost:3000/api/rtmp/on-publish-done;
            
            # Access control
            allow publish all;
            allow play all;
        }
        
        # Statistics
        application stat {
            live on;
            allow play all;
        }
    }
}
EOF

# Add RTMP configuration to nginx.conf if not already present
print_status "Adding RTMP configuration to nginx.conf..."
if ! grep -q "include /etc/nginx/rtmp/rtmp.conf;" /etc/nginx/nginx.conf; then
    sudo sed -i '/http {/i \
# Include RTMP configuration\
include /etc/nginx/rtmp/rtmp.conf;\
' /etc/nginx/nginx.conf
fi

# Create RTMP directories
print_status "Creating RTMP directories..."
sudo mkdir -p /var/www/rtmp/hls
sudo mkdir -p /var/www/rtmp/dash
sudo chown -R www-data:www-data /var/www/rtmp

# Test nginx configuration
print_status "Testing Nginx configuration..."
if sudo nginx -t; then
    print_status "Nginx configuration test passed!"
else
    print_error "Nginx configuration test failed!"
    print_warning "Checking nginx error logs..."
    sudo tail -n 20 /var/log/nginx/error.log
    exit 1
fi

# Restart nginx
print_status "Restarting Nginx..."
sudo systemctl restart nginx

# Check if nginx started successfully
if sudo systemctl is-active --quiet nginx; then
    print_status "Nginx restarted successfully!"
else
    print_error "Nginx failed to restart!"
    print_warning "Checking nginx status..."
    sudo systemctl status nginx
    exit 1
fi

# Check if RTMP port is listening
print_status "Checking RTMP port..."
if sudo netstat -tlnp | grep -q ":1935"; then
    print_status "RTMP server is listening on port 1935!"
else
    print_warning "RTMP port 1935 is not listening. This might be normal if nginx is still starting up."
fi

# Verify RTMP module is loaded
print_status "Verifying RTMP module..."
if nginx -V 2>&1 | grep -q "rtmp"; then
    print_status "RTMP module is loaded!"
else
    print_warning "RTMP module not found in nginx -V output, but it might still work."
fi

echo ""
echo -e "${GREEN}RTMP Module Fix Completed Successfully!${NC}"
echo "=============================================="
echo ""
echo "Next Steps:"
echo "1. Continue with the deployment: sudo bash deploy.sh"
echo "2. Or test RTMP functionality manually"
echo ""
echo "Useful Commands:"
echo "  Test nginx: sudo nginx -t"
echo "  Restart nginx: sudo systemctl restart nginx"
echo "  Check nginx status: sudo systemctl status nginx"
echo "  View nginx logs: sudo tail -f /var/log/nginx/error.log"
echo "  Check RTMP port: sudo netstat -tlnp | grep 1935"
echo ""
echo "RTMP Server Information:"
echo "  RTMP URL: rtmp://$(hostname -I | awk '{print $1}'):1935/live"
echo "  HLS URL: http://$(hostname -I | awk '{print $1}')/hls"
echo "  Stats URL: http://$(hostname -I | awk '{print $1}')/stat"
echo ""