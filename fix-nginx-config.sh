#!/bin/bash

# Complete Nginx Configuration Fix for SCTE-35 Streaming
# This script fixes the Nginx configuration to serve the Next.js app instead of default page

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to ask for user confirmation
ask_confirmation() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "$prompt [y/n]: " response
        case $response in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Function to run command with error handling
run_command() {
    local cmd="$1"
    local description="$2"
    local critical="$3"
    
    print_status "$description"
    echo "Running: $cmd"
    
    if eval "$cmd"; then
        print_status "✓ $description completed successfully"
    else
        if [ "$critical" = "true" ]; then
            print_error "✗ $description failed"
            print_error "This step is critical. Please fix the issue manually and try again."
            print_error "Command that failed: $cmd"
            exit 1
        else
            print_warning "✗ $description failed, but continuing..."
            print_warning "You may need to fix this manually later."
            print_warning "Command that failed: $cmd"
        fi
    fi
}

# Function to check if Next.js is running
check_nextjs() {
    print_status "Checking if Next.js application is running..."
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|302"; then
        print_status "✓ Next.js application is running on port 3000"
        return 0
    else
        print_warning "✗ Next.js application is not responding on port 3000"
        
        if ask_confirmation "Do you want to start the Next.js application now?"; then
            print_status "Starting Next.js application..."
            
            # Check if we're in the project directory
            if [ ! -f "package.json" ]; then
                print_error "package.json not found. Please navigate to your project directory first."
                return 1
            fi
            
            # Start with PM2 if available, otherwise with npm
            if command -v pm2 &> /dev/null; then
                if [ -f "ecosystem.config.js" ]; then
                    run_command "pm2 start ecosystem.config.js" "Starting application with PM2" "false"
                else
                    run_command "pm2 start npm --name scte35-app -- start" "Starting application with PM2" "false"
                fi
            else
                print_warning "PM2 not found. Starting with npm in background..."
                nohup npm start > /dev/null 2>&1 &
                print_status "Application started in background"
            fi
            
            # Wait a bit for the application to start
            sleep 10
            
            # Check again
            if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|302"; then
                print_status "✓ Next.js application is now running"
                return 0
            else
                print_warning "Next.js application still not responding. You may need to start it manually."
                return 1
            fi
        else
            print_warning "Please start the Next.js application manually before continuing."
            print_warning "Command: cd /path/to/project && npm start"
            return 1
        fi
    fi
}

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         SCTE-35 Streaming - Nginx Configuration Fix         ║"
echo "║                                                              ║"
echo "║  This script will configure Nginx to serve your Next.js app  ║"
echo "║  instead of the default Nginx welcome page.                 ║"
echo "║                                                              ║"
echo "║  Server IP: 103.167.123.195                                 ║"
echo "║  Nginx: Package-based with RTMP module                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_warning "This script requires sudo privileges for some operations."
    if ! ask_confirmation "Do you want to continue?"; then
        print_error "Script cancelled."
        exit 1
    fi
fi

# Step 1: System Information
print_step "Gathering system information..."
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"
echo "Nginx version: $(nginx -V 2>&1 | head -1)"
echo "Nginx binary: $(which nginx)"
echo ""

# Step 2: Check Next.js Application
print_step "Checking Next.js application..."
if ! check_nextjs; then
    print_warning "Next.js application may not be running properly."
    if ! ask_confirmation "Do you want to continue anyway?"; then
        print_error "Script cancelled."
        exit 1
    fi
fi

# Step 3: Backup Current Configuration
print_step "Backing up current Nginx configuration..."
if [ -f "/etc/nginx/nginx.conf" ]; then
    run_command "sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)" "Backing up nginx.conf" "true"
else
    print_warning "nginx.conf not found, creating new one"
fi

# Step 4: Create Directories
print_step "Creating required directories..."
run_command "sudo mkdir -p /var/www/rtmp/hls" "Creating HLS directory" "false"
run_command "sudo mkdir -p /var/www/rtmp/dash" "Creating DASH directory" "false"
run_command "sudo chown -R www-data:www-data /var/www/rtmp" "Setting RTMP directory permissions" "false"
run_command "sudo chmod -R 755 /var/www/rtmp" "Setting RTMP directory permissions" "false"

# Step 5: Create Main Nginx Configuration
print_step "Creating main Nginx configuration..."
cat > /tmp/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

# RTMP Configuration
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

http {
    ##
    # Basic Settings
    ##

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # SSL Settings
    ##

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    ##
    # Logging Settings
    ##

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    ##
    # Gzip Settings
    ##

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    ##
    # Virtual Host Configs
    ##

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

run_command "sudo cp /tmp/nginx.conf /etc/nginx/nginx.conf" "Installing new nginx.conf" "true"
rm -f /tmp/nginx.conf

# Step 6: Create Site Configuration
print_step "Creating site configuration..."
cat > /tmp/scte35 << EOF
server {
    listen 80;
    server_name 103.167.123.195 localhost;
    
    # Next.js application proxy
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
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
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
        
        # Prevent hotlinking
        valid_referers none blocked server_names
                   103.167.123.195;
        if (\$invalid_referer) {
            return 403;
        }
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
        
        # Prevent hotlinking
        valid_referers none blocked server_names
                   103.167.123.195;
        if (\$invalid_referer) {
            return 403;
        }
    }
    
    # RTMP statistics
    location /stat {
        rtmp_stat all;
        rtmp_stat_stylesheet stat.xsl;
    }
    
    location /stat.xsl {
        root /etc/nginx;
    }
    
    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
}
EOF

run_command "sudo cp /tmp/scte35 /etc/nginx/sites-available/scte35" "Installing site configuration" "true"
rm -f /tmp/scte35

# Step 7: Create RTMP Statistics XSL File
print_step "Creating RTMP statistics XSL file..."
cat > /tmp/stat.xsl << 'EOF'
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
        .stream { background-color: #fff5e8; }
        .client { background-color: #f5e8ff; }
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
            <tr><td>Uptime</td><td><xsl:value-of select="uptime"/></td></tr>
            <tr><td>Version</td><td><xsl:value-of select="nginx_version"/></td></tr>
            <tr><td>Connected</td><td><xsl:value-of select="naccepted"/></td></tr>
        </table>
    </div>
    <xsl:apply-templates select="application"/>
</xsl:template>

<xsl:template match="application">
    <div class="application">
        <h3>Application: <xsl:value-of select="@name"/></h3>
        <xsl:apply-templates select="live"/>
        <xsl:apply-templates select="play"/>
    </div>
</xsl:template>

<xsl:template match="live|play">
    <div class="stream">
        <h4><xsl:value-of select="name()"/> Streams</h4>
        <xsl:apply-templates select="stream"/>
    </div>
</xsl:template>

<xsl:template match="stream">
    <div class="client">
        <h5>Stream: <xsl:value-of select="@name"/></h5>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>Time</td><td><xsl:value-of select="time"/></td></tr>
            <tr><td>Bytes</td><td><xsl:value-of select="bytes"/></td></tr>
            <tr><td> Clients</td><td><xsl:value-of select="nclients"/></td></tr>
        </table>
        <xsl:apply-templates select="client"/>
    </div>
</xsl:template>

<xsl:template match="client">
    <table>
        <tr><th>Client</th><th>Value</th></tr>
        <tr><td>ID</td><td><xsl:value-of select="@id"/></td></tr>
        <tr><td>Address</td><td><xsl:value-of select="@address"/></td></tr>
        <tr><td>Time</td><td><xsl:value-of select="@time"/></td></tr>
    </table>
</xsl:template>
</xsl:stylesheet>
EOF

run_command "sudo cp /tmp/stat.xsl /etc/nginx/stat.xsl" "Installing RTMP statistics XSL file" "false"
rm -f /tmp/stat.xsl

# Step 8: Enable Site Configuration
print_step "Enabling site configuration..."
run_command "sudo rm -f /etc/nginx/sites-enabled/default" "Removing default site" "false"
run_command "sudo ln -sf /etc/nginx/sites-available/scte35 /etc/nginx/sites-enabled/scte35" "Enabling SCTE-35 site" "true"

# Step 9: Test Nginx Configuration
print_step "Testing Nginx configuration..."
if sudo nginx -t; then
    print_status "✓ Nginx configuration test passed"
else
    print_error "✗ Nginx configuration test failed"
    print_error "Please check the configuration files manually"
    print_error "Command: sudo nginx -t"
    
    if ask_confirmation "Do you want to see the error logs?"; then
        echo ""
        echo "=== Nginx Error Log ==="
        sudo tail -n 20 /var/log/nginx/error.log
        echo ""
    fi
    
    if ask_confirmation "Do you want to continue anyway?"; then
        print_warning "Continuing with broken configuration..."
    else
        print_error "Script cancelled."
        exit 1
    fi
fi

# Step 10: Restart Nginx
print_step "Restarting Nginx..."
if sudo systemctl restart nginx; then
    print_status "✓ Nginx restarted successfully"
else
    print_error "✗ Failed to restart Nginx"
    
    if ask_confirmation "Do you want to try reloading instead?"; then
        if sudo systemctl reload nginx; then
            print_status "✓ Nginx reloaded successfully"
        else
            print_error "✗ Failed to reload Nginx too"
            print_error "Please restart Nginx manually: sudo systemctl restart nginx"
        fi
    fi
fi

# Step 11: Verify Configuration
print_step "Verifying configuration..."
sleep 3  # Wait for Nginx to fully start

# Check if Nginx is running
if sudo systemctl is-active --quiet nginx; then
    print_status "✓ Nginx is running"
else
    print_warning "✗ Nginx is not running"
fi

# Check main page
print_status "Testing main page access..."
if curl -s -o /dev/null -w "%{http_code}" http://103.167.123.195/ | grep -q "200\|302"; then
    print_status "✓ Main page is accessible"
else
    print_warning "✗ Main page is not accessible"
fi

# Check RTMP stats
print_status "Testing RTMP statistics..."
if curl -s http://103.167.123.195/stat | grep -q "rtmp\|RTMP"; then
    print_status "✓ RTMP statistics are accessible"
else
    print_warning "✗ RTMP statistics are not accessible"
fi

# Check health endpoint
print_status "Testing health endpoint..."
if curl -s http://103.167.123.195/health | grep -q "healthy"; then
    print_status "✓ Health endpoint is working"
else
    print_warning "✗ Health endpoint is not working"
fi

# Step 12: Final Summary
echo ""
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Configuration Complete!                     ║"
echo "║                                                              ║"
echo "║  Your Nginx has been configured to serve your Next.js app     ║"
echo "║  instead of the default welcome page.                        ║"
echo "║                                                              ║"
echo "║  Server IP: 103.167.123.195                                 ║"
echo "║  Main App: http://103.167.123.195/                          ║"
echo "║  RTMP Stats: http://103.167.123.195/stat                    ║"
echo "║  Health: http://103.167.123.195/health                     ║"
echo "║  RTMP Server: rtmp://103.167.123.195:1935/live              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo "Useful Commands:"
echo "  Check Nginx status: sudo systemctl status nginx"
echo "  Test configuration: sudo nginx -t"
echo "  View access logs: sudo tail -f /var/log/nginx/access.log"
echo "  View error logs: sudo tail -f /var/log/nginx/error.log"
echo "  Restart Nginx: sudo systemctl restart nginx"
echo "  Reload Nginx: sudo systemctl reload nginx"
echo ""

echo "Testing Commands:"
echo "  Test main page: curl -I http://103.167.123.195/"
echo "  Test RTMP stats: curl http://103.167.123.195/stat"
echo "  Test health: curl http://103.167.123.195/health"
echo ""

echo "RTMP Streaming Test:"
echo "  Broadcast: ffmpeg -re -i video.mp4 -c:v libx264 -c:a aac -f flv rtmp://103.167.123.195:1935/live/test"
echo "  View HLS: http://103.167.123.195/hls/test.m3u8"
echo ""

# Ask if user wants to test now
if ask_confirmation "Do you want to test the main page now?"; then
    echo ""
    echo "Testing main page..."
    if curl -s http://103.167.123.195/ | head -20; then
        echo ""
        print_status "✓ Main page test completed"
    else
        print_warning "✗ Main page test failed"
    fi
fi

echo ""
echo -e "${GREEN}Script completed successfully!${NC}"
echo "Your SCTE-35 streaming server should now be fully operational."
echo ""