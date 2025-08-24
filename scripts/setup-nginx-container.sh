#!/bin/bash

# Fix Nginx Setup for Container Environment
# This script sets up Nginx with RTMP support in a container environment

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

echo -e "${GREEN}Nginx Setup for Container Environment${NC}"
echo "======================================="

# Check if we're in a container
if [[ ! -d "/.dockerenv" ]] && [[ ! -f "/.containerenv" ]]; then
    print_warning "Not running in a container environment. This script is designed for containers."
fi

# Update package list
print_status "Updating package list..."
apt update

# Install Nginx with RTMP support
print_status "Installing Nginx with RTMP support..."
apt install -y nginx libnginx-mod-rtmp

# Check if nginx is installed
if command -v nginx &> /dev/null; then
    print_status "Nginx installed successfully"
    nginx -V
else
    print_error "Nginx installation failed"
    exit 1
fi

# Create necessary directories
print_status "Creating directories..."
mkdir -p /etc/nginx/rtmp
mkdir -p /var/www/rtmp/hls
mkdir -p /var/www/rtmp/dash

# Create RTMP configuration
print_status "Creating RTMP configuration..."
cat > /etc/nginx/rtmp/rtmp.conf << 'EOF'
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

# Create main nginx configuration
print_status "Creating main nginx configuration..."
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

# Include RTMP configuration
include /etc/nginx/rtmp/rtmp.conf;

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Create site configuration
print_status "Creating site configuration..."
cat > /etc/nginx/sites-available/scte35 << EOF
server {
    listen 80;
    server_name localhost;
    
    # Next.js application
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # HLS streaming
    location /hls {
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
        root /var/www/rtmp;
        add_header Cache-Control no-cache;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
    
    # DASH streaming
    location /dash {
        types {
            application/dash+xml mpd;
            video/mp4 mp4;
        }
        root /var/www/rtmp;
        add_header Cache-Control no-cache;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
    
    # RTMP statistics
    location /stat {
        rtmp_stat all;
        rtmp_stat_stylesheet stat.xsl;
    }
    
    location /stat.xsl {
        root /etc/nginx/rtmp;
    }
}
EOF

# Enable site
print_status "Enabling site..."
ln -sf /etc/nginx/sites-available/scte35 /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Set permissions
print_status "Setting permissions..."
chown -R www-data:www-data /var/www/rtmp
chmod -R 755 /var/www/rtmp

# Test configuration
print_status "Testing nginx configuration..."
nginx -t

# Start nginx
print_status "Starting nginx..."
nginx

# Check if nginx is running
if pgrep nginx > /dev/null; then
    print_status "Nginx started successfully"
else
    print_error "Nginx failed to start"
    exit 1
fi

# Check ports
print_status "Checking ports..."
sleep 2
if netstat -tlnp | grep -q ":80"; then
    print_status "Port 80 (HTTP) is listening"
else
    print_warning "Port 80 is not listening"
fi

if netstat -tlnp | grep -q ":1935"; then
    print_status "Port 1935 (RTMP) is listening"
else
    print_warning "Port 1935 is not listening"
fi

print_status "Nginx setup completed successfully!"
echo ""
echo "Service URLs:"
echo "  Application: http://localhost:80"
echo "  RTMP Server: rtmp://localhost:1935/live"
echo "  HLS Stream: http://localhost/hls"
echo "  RTMP Stats: http://localhost/stat"
echo ""
echo "Useful Commands:"
echo "  Test config: nginx -t"
echo "  Start nginx: nginx"
echo "  Stop nginx: nginx -s stop"
echo "  Reload config: nginx -s reload"
echo "  Check processes: ps aux | grep nginx"
echo "  Check ports: netstat -tlnp | grep -E ':80|:1935'"