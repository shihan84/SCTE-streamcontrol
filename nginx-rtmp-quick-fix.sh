#!/bin/bash

# SCTE-35 Streaming Control Center - Quick Nginx RTMP Fix
# This script provides an alternative approach using pre-built packages
# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

log "Starting quick Nginx RTMP fix..."

# Remove existing Nginx installation
log "Removing existing Nginx installation..."
apt-get remove -y nginx nginx-common nginx-full nginx-core || true
apt-get autoremove -y || true
rm -rf /etc/nginx || true
rm -rf /var/log/nginx || true
rm -rf /var/www/html || true

# Update package list
log "Updating package list..."
apt-get update

# Install dependencies
log "Installing dependencies..."
apt-get install -y \
    wget \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    curl

# Add Ubuntu Nginx PPA (which has more modules)
log "Adding Nginx PPA..."
add-apt-repository -y ppa:nginx/stable
apt-get update

# Install Nginx with common modules
log "Installing Nginx with common modules..."
apt-get install -y nginx-full

# Download and build RTMP module
log "Building RTMP module..."
cd /tmp
git clone https://github.com/arut/nginx-rtmp-module.git
cd nginx-rtmp-module

# Create dynamic module
log "Creating dynamic RTMP module..."
apt-get install -y build-essential libpcre3-dev libssl-dev zlib1g-dev
nginx -V 2>&1 | grep -o -- '--with-cc-opt=[^ ]*' | head -1 > /tmp/nginx-opts
nginx -V 2>&1 | grep -o -- '--with-ld-opt=[^ ]*' | head -1 >> /tmp/nginx-opts

# Compile RTMP module as dynamic module
./configure \
    $(nginx -V 2>&1 | grep -o -- '--[^ ]*' | tr '\n' ' ') \
    --add-dynamic-module=.

make modules

# Copy the dynamic module
cp objs/ngx_rtmp_module.so /usr/lib/nginx/modules/

# Create directories
log "Creating directories..."
mkdir -p /etc/nginx/conf.d
mkdir -p /var/log/nginx
mkdir -p /var/www/html
chown -R www-data:www-data /var/log/nginx
chown -R www-data:www-data /var/www/html

# Create nginx.conf with RTMP module
log "Creating nginx.conf with RTMP module..."
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

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

# Load RTMP module
load_module /usr/lib/nginx/modules/ngx_rtmp_module.so;

# RTMP Configuration
rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        application live {
            live on;
            record off;
            
            # SCTE-35 support
            on_play http://localhost:3000/api/scte-35/on-play;
            on_publish http://localhost:3000/api/scte-35/on-publish;
            on_done http://localhost:3000/api/scte-35/on-done;
        }
    }
}
EOF

# Create default site
log "Creating default site..."
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /stat {
        rtmp_stat all;
        rtmp_stat_stylesheet stat.xsl;
    }

    location /stat.xsl {
        root /etc/nginx/;
    }

    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /var/www/html;
    }
}
EOF

# Enable default site
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Create RTMP statistics stylesheet
log "Creating RTMP statistics stylesheet..."
cat > /etc/nginx/stat.xsl << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html"/>
<xsl:template match="/">
<html>
<head>
    <title>RTMP Stream Statistics</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .server { background-color: #e8f5e8; }
        .app { background-color: #f0f8ff; }
        .stream { background-color: #fff5ee; }
    </style>
</head>
<body>
    <h1>RTMP Stream Statistics</h1>
    <xsl:apply-templates select="rtmp"/>
</body>
</html>
</xsl:template>

<xsl:template match="rtmp">
    <xsl:apply-templates select="server"/>
</xsl:template>

<xsl:template match="server">
    <h2>Server</h2>
    <table>
        <tr><th>Property</th><th>Value</th></tr>
        <tr><td>Application</td><td><xsl:value-of select="application"/></td></tr>
        <tr><td>Live Streams</td><td><xsl:value-of select="live/streams"/></td></tr>
        <tr><td>Clients</td><td><xsl:value-of select="live/clients"/></td></tr>
    </table>
    <xsl:apply-templates select="application"/>
</xsl:template>

<xsl:template match="application">
    <div class="app">
        <h3>Application: <xsl:value-of select="@name"/></h3>
        <xsl:apply-templates select="live"/>
    </div>
</xsl:template>

<xsl:template match="live">
    <xsl:apply-templates select="stream"/>
</xsl:template>

<xsl:template match="stream">
    <div class="stream">
        <h4>Stream: <xsl:value-of select="@name"/></h4>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>Time</td><td><xsl:value-of select="time"/></td></tr>
            <tr><td>Video</td><td><xsl:value-of select="video"/></td></tr>
            <tr><td>Audio</td><td><xsl:value-of select="audio"/></td></tr>
            <tr><td>Clients</td><td><xsl:value-of select="clients"/></td></tr>
        </table>
    </div>
</xsl:template>
</xsl:stylesheet>
EOF

# Set permissions
log "Setting permissions..."
chown -R www-data:www-data /etc/nginx
chmod 644 /etc/nginx/nginx.conf
chmod 644 /etc/nginx/sites-available/default
chmod 644 /etc/nginx/stat.xsl

# Test configuration
log "Testing Nginx configuration..."
nginx -t

# Start Nginx
log "Starting Nginx..."
systemctl enable nginx
systemctl start nginx

# Show status
log "Nginx status:"
systemctl status nginx --no-pager

# Cleanup
log "Cleaning up..."
cd /
rm -rf /tmp/nginx-rtmp-module

log "Quick Nginx RTMP fix completed successfully!"
log "RTMP server is running on port 1935"
log "HTTP server is running on port 80"
log "RTMP statistics available at http://your-server-ip/stat"

echo ""
echo "Next steps:"
echo "1. Test RTMP streaming: ffmpeg -re -i input.mp4 -c copy -f flv rtmp://your-server-ip:1935/live/stream"
echo "2. View RTMP stats: http://your-server-ip/stat"
echo "3. Your SCTE-35 application can now use RTMP features"

# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.