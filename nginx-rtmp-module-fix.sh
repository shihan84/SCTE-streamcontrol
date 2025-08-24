#!/bin/bash

# SCTE-35 Streaming Control Center - Nginx RTMP Module Fix
# This script compiles Nginx with RTMP module support from source
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

log "Starting Nginx RTMP module installation..."

# Update package list
log "Updating package list..."
apt-get update

# Install build dependencies
log "Installing build dependencies..."
apt-get install -y \
    build-essential \
    libpcre3-dev \
    libssl-dev \
    zlib1g-dev \
    wget \
    git \
    unzip

# Create working directory
WORK_DIR="/tmp/nginx-rtmp-build"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Download Nginx source
NGINX_VERSION="1.25.3"
log "Downloading Nginx source v$NGINX_VERSION..."
wget "https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz"
tar -xzf "nginx-$NGINX_VERSION.tar.gz"
cd "nginx-$NGINX_VERSION"

# Download RTMP module
log "Downloading RTMP module..."
git clone https://github.com/arut/nginx-rtmp-module.git

# Create Nginx user if not exists
id -u nginx &>/dev/null || useradd -r -s /bin/false nginx

# Configure Nginx with RTMP module
log "Configuring Nginx with RTMP module..."
./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --user=nginx \
    --group=nginx \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_realip_module \
    --with-stream_geoip_module=dynamic \
    --add-dynamic-module=./nginx-rtmp-module

# Compile and install Nginx
log "Compiling Nginx (this may take a while)..."
make -j$(nproc)
make install

# Create systemd service file
log "Creating systemd service..."
cat > /etc/systemd/system/nginx.service << 'EOF'
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Create directories
log "Creating directories..."
mkdir -p /etc/nginx/conf.d
mkdir -p /var/log/nginx
mkdir -p /var/www/html
chown -R nginx:nginx /var/log/nginx
chown -R nginx:nginx /var/www/html

# Create basic nginx.conf with RTMP support
log "Creating nginx.conf with RTMP support..."
cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    error_log   /var/log/nginx/error.log;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    types_hash_max_size 2048;

    include /etc/nginx/conf.d/*.conf;
}

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

# Create default site configuration
log "Creating default site configuration..."
cat > /etc/nginx/conf.d/default.conf << 'EOF'
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
chmod +x /usr/sbin/nginx
chmod 644 /etc/nginx/nginx.conf
chmod 644 /etc/nginx/conf.d/default.conf
chmod 644 /etc/nginx/stat.xsl

# Enable and start Nginx
log "Enabling and starting Nginx..."
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx

# Test configuration
log "Testing Nginx configuration..."
if /usr/sbin/nginx -t; then
    log "Nginx configuration test successful!"
else
    error "Nginx configuration test failed!"
fi

# Show status
log "Nginx status:"
systemctl status nginx --no-pager

# Cleanup
log "Cleaning up..."
cd /
rm -rf "$WORK_DIR"

log "Nginx with RTMP module installation completed successfully!"
log "RTMP server is running on port 1935"
log "HTTP server is running on port 80"
log "RTMP statistics available at http://your-server-ip/stat"

echo ""
echo "Next steps:"
echo "1. Test RTMP streaming: ffmpeg -re -i input.mp4 -c copy -f flv rtmp://your-server-ip:1935/live/stream"
echo "2. View RTMP stats: http://your-server-ip/stat"
echo "3. Your SCTE-35 application can now use RTMP features"

# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.