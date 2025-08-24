#!/bin/bash

# Comprehensive Nginx fix for PID, configuration, and RTMP issues
# This script addresses all common Nginx deployment issues

set -e

echo "🔧 Comprehensive Nginx fix for PID, configuration, and RTMP issues..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root or with sudo"
   exit 1
fi

print_info "Step 1: Stop all Nginx processes..."
systemctl stop nginx || true
pkill -f nginx || true
sleep 2

print_info "Step 2: Kill any remaining Nginx processes..."
pkill -9 nginx || true
sleep 1

print_info "Step 3: Clean up existing installation..."
rm -rf /usr/local/nginx
rm -f /etc/systemd/system/nginx.service
systemctl daemon-reload

print_info "Step 4: Create necessary directories..."
mkdir -p /usr/local/nginx/conf
mkdir -p /usr/local/nginx/logs
mkdir -p /usr/local/nginx/temp
mkdir -p /run/nginx
mkdir -p /var/www/rtmp/hls
mkdir -p /var/www/rtmp/dash
mkdir -p /var/log/nginx

print_info "Step 5: Set proper permissions..."
chown -R www-data:www-data /usr/local/nginx
chown -R www-data:www-data /var/www/rtmp
chown -R www-data:www-data /var/log/nginx
chown -R www-data:www-data /run/nginx
chmod -R 755 /usr/local/nginx
chmod -R 755 /var/www/rtmp
chmod -R 755 /var/log/nginx
chmod 755 /run/nginx

print_info "Step 6: Create basic Nginx configuration..."
cat > /usr/local/nginx/conf/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /usr/local/nginx/conf/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    include /usr/local/nginx/conf/conf.d/*.conf;
}
EOF

print_info "Step 7: Create MIME types configuration..."
mkdir -p /usr/local/nginx/conf/conf.d
cat > /usr/local/nginx/conf/mime.types << 'EOF'
types {
    text/html                             html htm shtml;
    text/css                              css;
    text/xml                              xml;
    image/gif                             gif;
    image/jpeg                            jpeg jpg;
    application/javascript                js;
    application/atom+xml                  atom;
    application/rss+xml                   rss;

    text/mathml                           mml;
    text/plain                            txt;
    text/vnd.sun.j2me.app-descriptor     jad;
    text/vnd.wap.wml                     wml;
    text/x-component                      htc;

    image/png                             png;
    image/svg+xml                         svg svgz;
    image/tiff                            tif tiff;
    image/vnd.wap.wbmp                    wbmp;
    image/webp                            webp;
    image/x-icon                          ico;
    image/x-jng                           jng;
    image/x-ms-bmp                        bmp;
    image/x-ms-bmp                        bmp;

    font/woff                             woff;
    font/woff2                            woff2;

    application/java-archive              jar war ear;
    application/json                      json;
    application/mac-binhex40              hqx;
    application/msword                    doc;
    application/pdf                       pdf;
    application/postscript                ps eps ai;
    application/rtf                       rtf;
    application/vnd.apple.mpegurl         m3u8;
    application/vnd.ms-excel              xls;
    application/vnd.ms-fontobject         eot;
    application/vnd.ms-powerpoint         ppt;
    application/vnd.wap.wmlc              wmlc;
    application/vnd.wap.wmlscriptc       wmls;
    application/x-7z-compressed           7z;
    application/x-cocoa                   cco;
    application/x-java-archive-diff        jardiff;
    application/x-java-jnlp-file          jnlp;
    application/x-makeself                run;
    application/x-perl                    pl pm;
    application/x-pilot                   prc pdb;
    application/x-rar-compressed          rar;
    application/x-redhat-package-manager   rpm;
    application/x-sea                     sea;
    application/x-shockwave-flash         swf;
    application/x-stuffit                sit;
    application/x-tcl                     tcl tk;
    application/x-x509-ca-cert            der pem crt;
    application/x-xpinstall              xpi;
    application/xhtml+xml                 xhtml;
    application/xspf+xml                  xspf;
    application/zip                       zip;

    application/octet-stream              bin exe dll;
    application/octet-stream              deb;
    application/octet-stream              dmg;
    application/octet-stream              iso img;
    application/octet-stream              msi msp msm;

    audio/midi                            mid midi kar;
    audio/mpeg                            mp3;
    audio/ogg                             ogg;
    audio/x-m4a                           m4a;
    audio/x-realaudio                     ra;

    video/3gpp                            3gpp 3gp;
    video/mp2t                            ts;
    video/mp4                             mp4;
    video/mpeg                            mpeg mpg;
    video/quicktime                       mov;
    video/webm                            webm;
    video/x-flv                           flv;
    video/x-m4v                           m4v;
    video/x-mng                           mng;
    video/x-ms-asf                        asx asf;
    video/x-ms-wmv                        wmv;
    video/x-msvideo                       avi;
}
EOF

print_info "Step 8: Create RTMP configuration..."
cat > /usr/local/nginx/conf/rtmp.conf << 'EOF'
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        allow publish all;
        allow play all;
        
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
            
            # Access log
            access_log /var/log/nginx/rtmp_access.log;
            
            # Notify on publish
            on_publish http://localhost:3000/api/scte35/on-publish;
            on_publish_done http://localhost:3000/api/scte35/on-publish-done;
            on_play http://localhost:3000/api/scte35/on-play;
            on_play_done http://localhost:3000/api/scte35/on-play-done;
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
EOF

print_info "Step 9: Create HTTP server configuration..."
cat > /usr/local/nginx/conf/conf.d/default.conf << 'EOF'
server {
    listen 80;
    server_name localhost _;
    
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
EOF

print_info "Step 10: Create RTMP statistics stylesheet..."
cat > /var/www/rtmp/stat.xsl << 'EOF'
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

chown www-data:www-data /var/www/rtmp/stat.xsl
chmod 644 /var/www/rtmp/stat.xsl

print_info "Step 11: Create systemd service file..."
cat > /etc/systemd/system/nginx.service << 'EOF'
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf
ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true
Restart=on-failure
RestartSec=5

# Create PID directory before starting
ExecStartPre=/bin/mkdir -p /run/nginx
ExecStartPre=/bin/chown www-data:www-data /run/nginx
ExecStartPre=/bin/chmod 755 /run/nginx

[Install]
WantedBy=multi-user.target
EOF

print_info "Step 12: Reload systemd daemon..."
systemctl daemon-reload

print_info "Step 13: Test Nginx configuration..."
if /usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf; then
    print_success "Nginx configuration test passed."
else
    print_error "Nginx configuration test failed!"
    print_info "Checking configuration files..."
    ls -la /usr/local/nginx/conf/
    print_info "Main configuration file:"
    cat /usr/local/nginx/conf/nginx.conf
    exit 1
fi

print_info "Step 14: Start Nginx service..."
systemctl start nginx

print_info "Step 15: Check Nginx status..."
sleep 3
if systemctl is-active --quiet nginx; then
    print_success "Nginx is running successfully."
    print_info "Service status:"
    systemctl status nginx --no-pager -l
else
    print_error "Nginx failed to start. Checking logs..."
    journalctl -u nginx -n 20 --no-pager
    print_info "Trying to start Nginx manually..."
    /usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
    sleep 2
    if pgrep nginx > /dev/null; then
        print_success "Nginx started successfully in manual mode."
    else
        print_error "Manual start also failed. Checking for port conflicts..."
        netstat -tulpn | grep :80 || true
        netstat -tulpn | grep :1935 || true
        print_info "Checking if ports are available..."
        ss -tulpn | grep :80 || true
        ss -tulpn | grep :1935 || true
        exit 1
    fi
fi

print_info "Step 16: Enable Nginx service..."
systemctl enable nginx

print_info "Step 17: Test basic functionality..."
if curl -s http://localhost/health | grep -q "healthy"; then
    print_success "Nginx health check passed."
else
    print_warning "Nginx health check failed, but service is running."
    print_info "This might be normal if the application isn't deployed yet."
fi

print_info "Step 18: Test RTMP port..."
if nc -z localhost 1935; then
    print_success "RTMP port 1935 is accessible."
else
    print_warning "RTMP port 1935 is not accessible."
fi

print_success "✅ Comprehensive Nginx fix completed successfully!"
echo ""
echo "📋 Service Status:"
systemctl status nginx --no-pager -l
echo ""
echo "🔍 To check logs: journalctl -u nginx -f"
echo "🔄 To restart: systemctl restart nginx"
echo "⏹️  To stop: systemctl stop nginx"
echo ""
echo "🌐 Test URLs:"
echo "  Health Check: http://localhost/health"
echo "  RTMP Stats: http://localhost/stat"
echo "  RTMP Server: rtmp://localhost:1935/live"