#!/bin/bash

# Fix RTMP Module for Debian/Ubuntu
# This script installs the RTMP module for existing Nginx installation

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

print_status "Installing RTMP module for Nginx..."

# Install the RTMP module package
print_status "Installing libnginx-mod-rtmp..."
sudo apt update
sudo apt install -y libnginx-mod-rtmp

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    print_status "Installing nginx..."
    sudo apt install -y nginx
fi

# Create RTMP configuration directory
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

# Add RTMP configuration to nginx.conf
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
sudo nginx -t

# Restart nginx
print_status "Restarting Nginx..."
sudo systemctl restart nginx

print_status "RTMP module installation completed successfully!"
print_status "RTMP server is now running on port 1935"