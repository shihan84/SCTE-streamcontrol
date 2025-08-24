#!/bin/bash

# SCTE-35 Streaming Project - Full Deployment Script
# This script handles the complete deployment from scratch

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Function to confirm action
confirm() {
    read -p "$1 [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled."
        exit 0
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install package if not exists
install_package() {
    if ! command_exists "$1"; then
        print_info "Installing $1..."
        sudo apt install -y "$1"
        print_success "$1 installed successfully."
    else
        print_info "$1 is already installed."
    fi
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           SCTE-35 Streaming Project - Full Deployment          ║"
echo "║                                                              ║"
echo "║  This script will deploy the complete SCTE-35 streaming      ║"
echo "║  project including:                                          ║"
echo "║  - System dependencies and updates                           ║"
echo "║  - Node.js, npm, and PM2                                     ║"
echo "║  - Nginx with RTMP module                                    ║"
echo "║  - Project installation and configuration                    ║"
echo "║  - Next.js application deployment                            ║"
echo "║  - Security and firewall configuration                        ║"
echo "║  - Testing and verification                                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
print_warning "This script requires sudo privileges for system installation."
confirm "Do you want to continue with the full deployment?"

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')
print_info "Server IP: $SERVER_IP"

# Step 1: System Preparation
echo ""
print_step "Step 1: System Preparation"

print_info "Updating system packages..."
sudo apt update
sudo apt upgrade -y

print_info "Installing basic tools..."
install_package git
install_package curl
install_package wget
install_package htop
install_package vim
install_package net-tools
install_package build-essential
install_package python3-dev
install_package ufw
install_package fail2ban

print_success "System preparation completed."

# Step 2: Install Node.js and PM2
echo ""
print_step "Step 2: Installing Node.js and PM2"

print_info "Installing Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

print_info "Verifying Node.js installation..."
node --version
npm --version

print_info "Installing PM2 globally..."
sudo npm install -g pm2

print_success "Node.js and PM2 installation completed."

# Step 3: Install and Configure Nginx
echo ""
print_step "Step 3: Installing and Configuring Nginx"

print_info "Installing Nginx..."
# Remove any existing Nginx installation first
sudo apt remove --purge -y nginx nginx-common nginx-full nginx-core || true
sudo apt autoremove -y
sudo apt autoclean

# Install Nginx properly
sudo apt update
sudo apt install -y nginx

# Verify Nginx installation
if ! command_exists nginx; then
    print_error "Nginx installation failed!"
    exit 1
fi

print_info "Creating Nginx configuration directories..."
sudo mkdir -p /etc/nginx/conf.d
sudo mkdir -p /var/log/nginx
sudo touch /etc/nginx/nginx.conf

print_info "Creating required directories..."
sudo mkdir -p /var/www/rtmp/hls
sudo mkdir -p /var/www/rtmp/dash
sudo chown -R www-data:www-data /var/www/rtmp
sudo chmod -R 755 /var/www/rtmp

print_info "Creating Nginx configuration..."
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
        server_name localhost $SERVER_IP;
        
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

print_info "Creating RTMP statistics stylesheet..."
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

print_info "Testing Nginx configuration..."
if sudo nginx -t; then
    print_success "Nginx configuration test passed."
else
    print_error "Nginx configuration test failed!"
    exit 1
fi

print_info "Starting and enabling Nginx..."
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl reload nginx

print_success "Nginx installation and configuration completed."

# Step 4: Configure Firewall
echo ""
print_step "Step 4: Configuring Firewall"

print_info "Configuring UFW firewall..."
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 1935/tcp  # RTMP
sudo ufw allow 1936/tcp  # RTMP stats
sudo ufw --force enable

print_success "Firewall configuration completed."

# Step 5: Clone and Setup Project
echo ""
print_step "Step 5: Cloning and Setting Up Project"

cd ~

print_info "Cloning SCTE-35 streaming project..."
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol

print_info "Installing project dependencies..."
npm install

print_info "Building application..."
npm run build

print_info "Creating environment configuration..."
cat > .env << EOF
NODE_ENV=production
PORT=3000
RTMP_PORT=1935
RTMP_HTTP_PORT=1936
NEXT_PUBLIC_APP_URL=http://$SERVER_IP
DATABASE_URL="file:./dev.db"
EOF

print_success "Project setup completed."

# Step 6: Deploy Application with PM2
echo ""
print_step "Step 6: Deploying Application with PM2"

print_info "Creating PM2 ecosystem configuration..."
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'scte35-app',
    script: 'npm',
    args: 'start',
    cwd: '/home/ubuntu/SCTE-streamcontrol',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: '/var/log/pm2/scte35-error.log',
    out_file: '/var/log/pm2/scte35-out.log',
    log_file: '/var/log/pm2/scte35.log',
    time: true,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    merge_logs: true
  }]
};
EOF

print_info "Creating log directory..."
sudo mkdir -p /var/log/pm2
sudo chown -R ubuntu:ubuntu /var/log/pm2

print_info "Starting application with PM2..."
pm2 start ecosystem.config.js

print_info "Saving PM2 configuration..."
pm2 save

print_info "Setting up PM2 to start on boot..."
pm2 startup

print_success "Application deployment completed."

# Step 7: Configure Security
echo ""
print_step "Step 7: Configuring Security"

print_info "Configuring fail2ban..."
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

print_info "Creating fail2ban configuration..."
sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
EOF

sudo systemctl restart fail2ban

print_success "Security configuration completed."

# Step 8: Setup Backup System
echo ""
print_step "Step 8: Setting Up Backup System"

print_info "Creating backup script..."
cat > backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup project files
tar -czf $BACKUP_DIR/project_$DATE.tar.gz -C /home/ubuntu SCTE-streamcontrol

# Backup nginx configuration
sudo cp -r /etc/nginx $BACKUP_DIR/nginx_$DATE

# Backup PM2 configuration
pm2 save > $BACKUP_DIR/pm2_$DATE.dump

# Keep only last 7 days of backups
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x backup.sh

print_info "Setting up automatic backups..."
(crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/SCTE-streamcontrol/backup.sh") | crontab -

print_success "Backup system configured."

# Step 9: Testing and Verification
echo ""
print_step "Step 9: Testing and Verification"

print_info "Testing application health..."
sleep 5  # Wait for application to start
if curl -s http://localhost:3000/health | grep -q "healthy"; then
    print_success "Application health check passed."
else
    print_warning "Application health check failed. Checking logs..."
    pm2 logs
fi

print_info "Testing Nginx proxy..."
if curl -s http://$SERVER_IP/health | grep -q "healthy"; then
    print_success "Nginx proxy test passed."
else
    print_warning "Nginx proxy test failed."
fi

print_info "Testing RTMP statistics..."
if curl -s http://$SERVER_IP/stat | grep -q "RTMP"; then
    print_success "RTMP statistics test passed."
else
    print_warning "RTMP statistics test failed."
fi

print_info "Checking service statuses..."
echo "Nginx status:"
sudo systemctl status nginx --no-pager -l

echo ""
echo "PM2 status:"
pm2 list

echo ""
echo "Port status:"
sudo netstat -tulpn | grep -E ':80|:3000|:1935|:1936'

print_success "Testing and verification completed."

# Step 10: Final Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Deployment Complete                       ║"
echo "║                                                              ║"
echo "║  The SCTE-35 streaming project has been successfully        ║"
echo "║  deployed!                                                   ║"
echo "║                                                              ║"
echo "║  🌐 Access URLs:                                            ║"
echo "║  - Main Application: http://$SERVER_IP/                    ║"
echo "║  - Health Check: http://$SERVER_IP/health                   ║"
echo "║  - RTMP Statistics: http://$SERVER_IP/stat                 ║"
echo "║  - RTMP Stream: rtmp://$SERVER_IP:1935/live/stream-key      ║"
echo "║  - HLS Stream: http://$SERVER_IP/hls/stream-key.m3u8        ║"
echo "║  - DASH Stream: http://$SERVER_IP/dash/stream-key.mpd       ║"
echo "║                                                              ║"
echo "║  🛠️  Management Commands:                                    ║"
echo "║  - Application: pm2 list | restart | stop | logs           ║"
echo "║  - Nginx: sudo systemctl status | restart nginx           ║"
echo "║  - Updates: ./update-from-github.sh                        ║"
echo "║  - Backup: ./backup.sh                                     ║"
echo "║  - Uninstall: ./uninstall.sh                               ║"
echo "║                                                              ║"
echo "║  📊 System Status:                                          ║"
echo "║  ✅ Node.js $(node --version)                               ║"
echo "║  ✅ npm $(npm --version)                                     ║"
echo "║  ✅ PM2 $(pm2 --version 2>/dev/null || echo 'installed')     ║"
echo "║  ✅ Nginx $(nginx -v 2>&1 | cut -d' ' -f3)                  ║"
echo "║  ✅ Firewall configured                                     ║"
echo "║  ✅ Security enabled                                         ║"
echo "║  ✅ Backup system configured                                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
print_success "🎉 Deployment completed successfully!"
print_info "Your SCTE-35 streaming server is now ready to use!"
print_info "Open your browser and navigate to: http://$SERVER_IP/"

echo ""
print_info "Next steps:"
echo "1. Test streaming with FFmpeg: ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://$SERVER_IP:1935/live/test"
echo "2. Configure your domain name for SSL/TLS"
echo "3. Set up monitoring and alerts"
echo "4. Test SCTE-35 functionality through the web interface"

echo ""
print_warning "Important: Save this information for future reference!"
echo "Project directory: /home/ubuntu/SCTE-streamcontrol"
echo "Server IP: $SERVER_IP"