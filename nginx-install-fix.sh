#!/bin/bash

# Nginx Installation and Configuration Fix Script
# This script handles package-based Nginx installation and configuration

echo "=== Nginx Installation and Configuration Fix ==="

# Check if user has sudo privileges
echo "Checking sudo access..."
if ! sudo -n true 2>/dev/null; then
    echo "NOTE: This script requires sudo privileges. You will be prompted for password."
fi

# Step 1: Install Nginx
echo "Step 1: Installing Nginx..."
sudo apt update
sudo apt install -y nginx

# Step 2: Verify Nginx installation
echo "Step 2: Verifying Nginx installation..."
sudo nginx -v
sudo systemctl status nginx --no-pager

# Step 3: Create required directories
echo "Step 3: Creating required directories..."
sudo mkdir -p /var/www/rtmp/hls
sudo mkdir -p /var/www/rtmp/dash
sudo chown -R www-data:www-data /var/www/rtmp
sudo chmod -R 755 /var/www/rtmp

# Step 4: Create comprehensive Nginx configuration
echo "Step 4: Creating Nginx configuration..."
sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

# RTMP configuration
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        application live {
            live on;
            record off;
            
            # Enable SCTE-35
            wait_key on;
            wait_video on;
            
            # HLS output
            hls on;
            hls_path /var/www/rtmp/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            hls_continuous on;
            hls_cleanup on;
            hls_nested on;
            
            # DASH output
            dash on;
            dash_path /var/www/rtmp/dash;
            dash_fragment 3;
            dash_playlist_length 60;
            dash_cleanup on;
            
            # SCTE-35 webhook
            on_publish http://localhost:3000/api/scte35/on-publish;
            on_publish_done http://localhost:3000/api/scte35/on-publish-done;
            on_play http://localhost:3000/api/scte35/on-play;
            on_play_done http://localhost:3000/api/scte35/on-play-done;
            
            # Access log
            access_log /var/log/nginx/rtmp_access.log;
        }
    }
    
    # RTMP statistics
    server {
        listen 1936;
        server_name localhost;
        location /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet stat.xsl;
        }
        location /stat.xsl {
            root /var/www/rtmp;
        }
    }
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Main server configuration
    server {
        listen 80;
        server_name localhost;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        
        # Next.js application proxy
        location / {
            proxy_pass http://localhost:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 86400;
        }
        
        # HLS streaming
        location /hls {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /var/www/rtmp;
            add_header Cache-Control no-cache;
            add_header Access-Control-Allow-Origin *;
            
            # CORS headers
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
        }
        
        # DASH streaming
        location /dash {
            types {
                application/dash+xml mpd;
                video/mp4 mp4;
            }
            root /var/www/rtmp;
            add_header Cache-Control no-cache;
            add_header Access-Control-Allow-Origin *;
            
            # CORS headers
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
        }
        
        # RTMP statistics
        location /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet /stat.xsl;
        }
        
        location /stat.xsl {
            root /var/www/rtmp;
        }
        
        # Health check endpoint
        location /health {
            access_log off;
            return 200 'healthy\n';
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Step 5: Create RTMP statistics stylesheet
echo "Step 5: Creating RTMP statistics stylesheet..."
sudo tee /var/www/rtmp/stat.xsl > /dev/null << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html"/>
<xsl:template match="/">
<html>
<head>
    <title>RTMP Statistics</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .server { background-color: #e8f5e8; }
        .application { background-color: #e8f0ff; }
        .stream { background-color: #fff8e8; }
        .client { background-color: #ffe8e8; }
    </style>
</head>
<body>
    <h1>RTMP Server Statistics</h1>
    <xsl:apply-templates select="rtmp"/>
</body>
</html>
</xsl:template>

<xsl:template match="rtmp">
    <xsl:apply-templates select="server"/>
</xsl:template>

<xsl:template match="server">
    <div class="server">
        <h2>Server</h2>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>Application</td><td><xsl:value-of select="application"/></td></tr>
            <tr><td>Live</td><td><xsl:value-of select="live"/></td></tr>
            <tr><td>Time</td><td><xsl:value-of select="nginx_rtmp_timestamp"/></td></tr>
        </table>
    </div>
    <xsl:apply-templates select="application"/>
</xsl:template>

<xsl:template match="application">
    <div class="application">
        <h3>Application: <xsl:value-of select="@name"/></h3>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>Live</td><td><xsl:value-of select="live"/></td></tr>
            <tr><td>Time</td><td><xsl:value-of select="nginx_rtmp_timestamp"/></td></tr>
        </table>
    </div>
    <xsl:apply-templates select="live"/>
</xsl:template>

<xsl:template match="live">
    <div class="stream">
        <h4>Live Stream: <xsl:value-of select="@stream"/></h4>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>Time</td><td><xsl:value-of select="@time"/></td></tr>
            <tr><td>Video</td><td><xsl:value-of select="video"/></td></tr>
            <tr><td>Audio</td><td><xsl:value-of select="audio"/></td></tr>
        </table>
    </div>
    <xsl:apply-templates select="client"/>
</xsl:template>

<xsl:template match="client">
    <div class="client">
        <h5>Client: <xsl:value-of select="@id"/></h5>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>Address</td><td><xsl:value-of select="@address"/></td></tr>
            <tr><td>Time</td><td><xsl:value-of select="@time"/></td></tr>
            <tr><td>Flash Version</td><td><xsl:value-of select="@flashver"/></td></tr>
            <tr><td>Page URL</td><td><xsl:value-of select="@pageurl"/></td></tr>
            <tr><td>SWF URL</td><td><xsl:value-of select="@swfurl"/></td></tr>
        </table>
    </div>
</xsl:template>
</xsl:stylesheet>
EOF

sudo chown www-data:www-data /var/www/rtmp/stat.xsl
sudo chmod 644 /var/www/rtmp/stat.xsl

# Step 6: Test Nginx configuration
echo "Step 6: Testing Nginx configuration..."
if sudo nginx -t; then
    echo "✅ Nginx configuration test passed!"
    
    # Step 7: Start and enable Nginx
    echo "Step 7: Starting and enabling Nginx..."
    sudo systemctl start nginx
    sudo systemctl enable nginx
    sudo systemctl reload nginx
    
    echo "✅ Nginx started and enabled successfully!"
    
    # Step 8: Configure firewall
    echo "Step 8: Configuring firewall..."
    sudo ufw allow 22/tcp    # SSH
    sudo ufw allow 80/tcp    # HTTP
    sudo ufw allow 1935/tcp  # RTMP
    sudo ufw allow 1936/tcp  # RTMP stats
    sudo ufw --force enable
    
    echo "✅ Firewall configured successfully!"
    
    # Step 9: Verify setup
    echo "Step 9: Verifying setup..."
    echo "Nginx status:"
    sudo systemctl status nginx --no-pager -l
    
    echo ""
    echo "Checking if ports are listening:"
    sudo netstat -tulpn | grep -E ':80|:1935|:1936'
    
    echo ""
    echo "🎉 Nginx installation and configuration completed successfully!"
    echo ""
    echo "📋 Access URLs:"
    echo "- Main Application: http://$(hostname -I | awk '{print $1}')/"
    echo "- Health Check: http://$(hostname -I | awk '{print $1}')/health"
    echo "- RTMP Statistics: http://$(hostname -I | awk '{print $1}')/stat"
    echo "- RTMP Stream: rtmp://$(hostname -I | awk '{print $1}'):1935/live/stream-key"
    echo "- HLS Stream: http://$(hostname -I | awk '{print $1}')/hls/stream-key.m3u8"
    echo "- DASH Stream: http://$(hostname -I | awk '{print $1}')/dash/stream-key.mpd"
    
else
    echo "❌ Nginx configuration test failed!"
    echo "Please check the error messages above and fix the configuration."
    exit 1
fi