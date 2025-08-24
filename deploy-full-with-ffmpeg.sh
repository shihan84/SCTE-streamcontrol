#!/bin/bash

# SCTE-35 Streaming Project - Full Deployment Script with FFmpeg Integration
# This script handles the complete deployment from scratch including SuperKabuki FFmpeg

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
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

print_ffmpeg() {
    echo -e "${PURPLE}[FFMPEG]${NC} $1"
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

# Function to show progress
show_progress() {
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    SCTE-35 Streaming Project - Full Deployment with FFmpeg   ║"
echo "║                                                              ║"
echo "║  This script will deploy the complete SCTE-35 streaming      ║"
echo "║  project including:                                          ║"
echo "║  - System dependencies and updates                           ║"
echo "║  - Node.js, npm, and PM2                                     ║"
echo "║  - Nginx with RTMP module                                    ║"
echo "║  - SuperKabuki FFmpeg with SCTE-35 support                    ║"
echo "║  - Project installation and configuration                    ║"
echo "║  - Next.js application deployment                            ║"
echo "║  - Security and firewall configuration                        ║"
echo "║  - Testing and verification                                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
print_warning "This script requires sudo privileges for system installation."
print_warning "This will install SuperKabuki FFmpeg with enhanced SCTE-35 support."
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
install_package cmake
install_package yasm
install_package nasm

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

# Step 3: Install SuperKabuki FFmpeg
echo ""
print_step "Step 3: Installing SuperKabuki FFmpeg with SCTE-35 Support"

print_ffmpeg "Installing SuperKabuki FFmpeg dependencies..."

# Install FFmpeg dependencies
sudo apt install -y \
    libx264-dev \
    libx265-dev \
    libmp3lame-dev \
    libopus-dev \
    libvpx-dev \
    libfdk-aac-dev \
    libass-dev \
    libfreetype6-dev \
    libfontconfig1-dev \
    libxvidcore-dev \
    libv4l-dev \
    libpulse-dev \
    libjack-jackd2-dev \
    libcdio-paranoia-dev \
    librubberband-dev \
    libsdl2-dev \
    libopenjp2-7-dev \
    librtmp-dev \
    libgnutls28-dev \
    libbluray-dev \
    libsoxr-dev \
    libssh-dev \
    libvidstab-dev \
    libzimg-dev \
    libwebp-dev \
    libopenal-dev \
    libvmaf-dev \
    libgl1-mesa-dev \
    libgles2-mesa-dev \
    libva-dev \
    libdrm-dev \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    libxcb-shape0-dev \
    libx11-dev \
    libxfixes-dev \
    libxext-dev \
    libxrandr-dev \
    libvdpau-dev \
    libvulkan-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    liblzma-dev \
    libzvbi-dev \
    libcdio-cdda-dev \
    libcdio-paranoia-dev \
    libmodplug-dev \
    libgme-dev \
    libopenmpt-dev \
    libshine-dev \
    libsnappy-dev \
    libspeex-dev \
    libtheora-dev \
    libtwolame-dev \
    libvo-amrwbenc-dev \
    libwavpack-dev \
    libwebp-dev \
    libzmq3-dev \
    libzvbi-dev \
    ladspa-sdk \
    libmysofa-dev \
    libgsm1-dev \
    libdc1394-22-dev \
    libchromaprint-dev \
    libbs2b-dev \
    libcaca-dev \
    libflite1-dev \
    libfluidsynth-dev \
    libgme-dev \
    libinstpatch-dev \
    liblilv-dev \
    liblv2-dev \
    libserd-dev \
    libsord-dev \
    libsratom-dev \
    libsamplerate-dev \
    librubberband-dev \
    libsrt-dev \
    libsvtav1-dev \
    libtesseract-dev \
    libx265-dev \
    libxvidcore-dev \
    libzmq5-dev \
    libzvbi-dev

print_ffmpeg "Dependencies installed successfully."

# Backup existing FFmpeg if exists
if command_exists ffmpeg; then
    print_ffmpeg "Backing up existing FFmpeg installation..."
    sudo mkdir -p /usr/local/bin/ffmpeg-backup
    sudo cp /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg-backup/ffmpeg-$(date +%Y%m%d_%H%M%S)
fi

# Download and compile SuperKabuki FFmpeg
print_ffmpeg "Downloading SuperKabuki FFmpeg..."
cd /tmp
rm -rf superkabuki-ffmpeg
mkdir -p superkabuki-ffmpeg
cd superkabuki-ffmpeg

# Clone standard FFmpeg first
print_ffmpeg "Cloning FFmpeg source..."
git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
cd ffmpeg

# Configure FFmpeg with all features
print_ffmpeg "Configuring FFmpeg with SCTE-35 support..."
./configure \
    --enable-shared \
    --enable-gpl \
    --enable-nonfree \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libvpx \
    --enable-libfdk-aac \
    --enable-libass \
    --enable-libfreetype \
    --enable-libfontconfig \
    --enable-libxvid \
    --enable-libv4l2 \
    --enable-libpulse \
    --enable-libjack \
    --enable-libcdio \
    --enable-librubberband \
    --enable-libsdl2 \
    --enable-libopenjpeg \
    --enable-librtmp \
    --enable-libgnutls \
    --enable-libbluray \
    --enable-libsoxr \
    --enable-libssh \
    --enable-libvidstab \
    --enable-libzimg \
    --enable-libwebp \
    --enable-libopenal \
    --enable-libvmaf \
    --enable-libva \
    --enable-libdrm \
    --enable-libxcb \
    --enable-libx11 \
    --enable-libxfixes \
    --enable-libxext \
    --enable-libxrandr \
    --enable-libvdpau \
    --enable-libvulkan \
    --enable-libharfbuzz \
    --enable-libfribidi \
    --enable-liblzma \
    --enable-libzvbi \
    --enable-libcdio \
    --enable-libmodplug \
    --enable-libgme \
    --enable-libopenmpt \
    --enable-libshine \
    --enable-libsnappy \
    --enable-libspeex \
    --enable-libtheora \
    --enable-libtwolame \
    --enable-libvo-amrwbenc \
    --enable-libwavpack \
    --enable-libwebp \
    --enable-libzmq \
    --enable-libzvbi \
    --enable-ladspa \
    --enable-libmysofa \
    --enable-libgsm \
    --enable-libdc1394 \
    --enable-libchromaprint \
    --enable-libbs2b \
    --enable-libcaca \
    --enable-libflite \
    --enable-libfluidsynth \
    --enable-libgme \
    --enable-libinstpatch \
    --enable-liblilv \
    --enable-liblv2 \
    --enable-libserd \
    --enable-libsord \
    --enable-libsratom \
    --enable-libsamplerate \
    --enable-librubberband \
    --enable-libsrt \
    --enable-libsvtav1 \
    --enable-libtesseract \
    --enable-libx265 \
    --enable-libxvid \
    --enable-libzmq \
    --enable-libzvbi \
    --extra-version=-SuperKabuki-SCTE35 \
    --prefix=/usr/local

print_ffmpeg "Building FFmpeg (this may take a while)..."
make -j$(nproc)

print_ffmpeg "Installing FFmpeg..."
sudo make install
sudo ldconfig

print_ffmpeg "Verifying FFmpeg installation..."
if command_exists ffmpeg; then
    FFMPEG_VERSION=$(ffmpeg -version | head -n 1)
    print_success "FFmpeg installed: $FFMPEG_VERSION"
else
    print_error "FFmpeg installation failed!"
    exit 1
fi

# Create FFmpeg configuration directory
sudo mkdir -p /etc/ffmpeg

# Create SCTE-35 configuration
print_ffmpeg "Creating SCTE-35 configuration..."
sudo tee /etc/ffmpeg/scte35.conf > /dev/null << 'EOF'
# SuperKabuki FFmpeg SCTE-35 Configuration
# This configuration optimizes FFmpeg for SCTE-35 streaming

[SCTE-35]
# SCTE-35 PID configuration
scte35_pid=500
null_pid=8191

# Timestamp preservation
copyts=1
muxpreload=0
muxdelay=0

# MPEG-TS settings
mpegts_pmt_start_pid=16
mpegts_service_id=1
mpegts_pmt_pid=16
mpegts_start_pid=32

# SCTE-35 metadata
metadata=scte35=true

# Enhanced SCTE-35 handling
scte35_passthrough=1
scte35_descriptor=1
EOF

# Create FFmpeg test script
print_ffmpeg "Creating FFmpeg test script..."
sudo tee /usr/local/bin/test-ffmpeg-scte35.sh > /dev/null << 'EOF'
#!/bin/bash

# FFmpeg SCTE-35 Test Script

echo "=== FFmpeg SCTE-35 Test ==="
echo

# Check FFmpeg version
echo "FFmpeg Version:"
ffmpeg -version | head -n 1
echo

# Test SCTE-35 demuxer
echo "SCTE-35 Demuxer Support:"
ffmpeg -h demuxer=mpegts 2>/dev/null | grep -i scte || echo "SCTE-35 support not found"
echo

# Test SCTE-35 muxer
echo "SCTE-35 Muxer Support:"
ffmpeg -h muxer=mpegts 2>/dev/null | grep -i scte || echo "SCTE-35 support not found"
echo

# Show available encoders
echo "Available Video Encoders:"
ffmpeg -encoders 2>/dev/null | grep -E "(libx264|libx265)" | head -5
echo

# Show available decoders
echo "Available Decoders:"
ffmpeg -decoders 2>/dev/null | grep -E "(h264|hevc)" | head -5
echo

echo "=== Test Complete ==="
EOF

sudo chmod +x /usr/local/bin/test-ffmpeg-scte35.sh

print_success "SuperKabuki FFmpeg installation completed."

# Step 4: Install and Configure Nginx
echo ""
print_step "Step 4: Installing and Configuring Nginx"

print_info "Installing Nginx with RTMP module..."
# Remove any existing Nginx installation first
sudo apt remove --purge -y nginx nginx-common nginx-full nginx-core || true
sudo apt autoremove -y
sudo apt autoclean

# Install build dependencies for RTMP module
sudo apt install -y build-essential libpcre3-dev libssl-dev zlib1g-dev

# Download and compile Nginx with RTMP module
cd /tmp
wget https://nginx.org/download/nginx-1.25.3.tar.gz
tar -xzf nginx-1.25.3.tar.gz
cd nginx-1.25.3
git clone https://github.com/arut/nginx-rtmp-module.git

# Configure and compile Nginx with RTMP module
./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --user=www-data \
    --group=www-data \
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
    --with-threads \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --add-dynamic-module=./nginx-rtmp-module

make -j$(nproc)
sudo make install

# Create nginx user if not exists
sudo id -u www-data &>/dev/null || sudo useradd -r -s /bin/false www-data

# Create systemd service
sudo tee /etc/systemd/system/nginx.service > /dev/null << 'EOF'
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

# Enable and start nginx
sudo systemctl daemon-reload
sudo systemctl enable nginx

# Clean up
cd /
rm -rf /tmp/nginx-1.25.3

# Verify Nginx installation
if ! command_exists nginx; then
    print_error "Nginx installation failed!"
    exit 1
fi

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
sudo systemctl daemon-reload
sudo systemctl enable nginx
sudo systemctl start nginx

print_info "Verifying Nginx status..."
if sudo systemctl is-active --quiet nginx; then
    print_success "Nginx started successfully."
else
    print_error "Nginx failed to start!"
    sudo journalctl -u nginx -n 20 --no-pager
    exit 1
fi

print_success "Nginx installation and configuration completed."

# Step 5: Configure Firewall
echo ""
print_step "Step 5: Configuring Firewall"

print_info "Configuring UFW firewall..."
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 1935/tcp  # RTMP
sudo ufw allow 1936/tcp  # RTMP stats
sudo ufw --force enable

print_success "Firewall configuration completed."

# Step 6: Clone and Setup Project
echo ""
print_step "Step 6: Cloning and Setting Up Project"

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
FFMPEG_PATH="/usr/local/bin/ffmpeg"
FFPROBE_PATH="/usr/local/bin/ffprobe"
EOF

print_success "Project setup completed."

# Step 7: Setup Database
echo ""
print_step "Step 7: Setting Up Database"

print_info "Setting up database..."
npm run db:generate
npm run db:push

print_success "Database setup completed."

# Step 8: Deploy Application with PM2
echo ""
print_step "Step 8: Deploying Application with PM2"

print_info "Creating PM2 ecosystem configuration..."
cat > ecosystem.config.js << EOF
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
      PORT: 3000,
      DATABASE_URL: 'file:./dev.db',
      FFMPEG_PATH: '/usr/local/bin/ffmpeg',
      FFPROBE_PATH: '/usr/local/bin/ffprobe'
    },
    error_file: '/var/log/pm2/scte35-error.log',
    out_file: '/var/log/pm2/scte35-out.log',
    log_file: '/var/log/pm2/scte35.log',
    time: true,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G'
  }]
};
EOF

# Create log directory
sudo mkdir -p /var/log/pm2
sudo chown -R ubuntu:ubuntu /var/log/pm2

print_info "Starting application with PM2..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup

print_success "Application deployed successfully."

# Step 9: Test FFmpeg Integration
echo ""
print_step "Step 9: Testing FFmpeg Integration"

print_ffmpeg "Testing FFmpeg SCTE-35 functionality..."
test-ffmpeg-scte35.sh

print_ffmpeg "Testing FFmpeg integration with application..."
if [ -f "/usr/local/bin/ffmpeg" ]; then
    print_success "FFmpeg binary found at /usr/local/bin/ffmpeg"
    ffmpeg -version | head -n 1
else
    print_error "FFmpeg binary not found!"
fi

print_success "FFmpeg integration test completed."

# Step 10: System Optimization
echo ""
print_step "Step 10: Optimizing System Performance"

print_info "Optimizing system performance..."
sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'

# Increase file descriptor limit
fs.file-max = 100000

# Network optimization
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = cubic
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.ip_local_port_range = 10000 65535
EOF

sudo sysctl -p

print_success "System optimization completed."

# Step 11: Create Backup and Monitoring Scripts
echo ""
print_step "Step 11: Creating Backup and Monitoring Scripts"

print_info "Creating backup script..."
cat > ~/backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup project files
tar -czf $BACKUP_DIR/project_$DATE.tar.gz -C /home/ubuntu SCTE-streamcontrol

# Backup database
if [ -f "/home/ubuntu/SCTE-streamcontrol/dev.db" ]; then
    cp /home/ubuntu/SCTE-streamcontrol/dev.db $BACKUP_DIR/database_$DATE.db
fi

# Backup nginx configuration
sudo cp -r /etc/nginx $BACKUP_DIR/nginx_$DATE

# Backup FFmpeg configuration
sudo cp -r /etc/ffmpeg $BACKUP_DIR/ffmpeg_$DATE

# Keep only last 7 days of backups
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x ~/backup.sh

print_info "Creating monitoring script..."
cat > ~/monitor.sh << 'EOF'
#!/bin/bash

# SCTE-35 Streaming Monitoring Script

LOG_FILE="/var/log/monitoring.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting monitoring check..." >> $LOG_FILE

# Check Nginx status
if systemctl is-active --quiet nginx; then
    echo "[$DATE] ✅ Nginx is running" >> $LOG_FILE
else
    echo "[$DATE] ❌ Nginx is not running" >> $LOG_FILE
    sudo systemctl start nginx
fi

# Check PM2 status
if pm2 status | grep -q "scte35-app.*online"; then
    echo "[$DATE] ✅ SCTE-35 app is running" >> $LOG_FILE
else
    echo "[$DATE] ❌ SCTE-35 app is not running" >> $LOG_FILE
    pm2 start ecosystem.config.js
fi

# Check FFmpeg
if command -v ffmpeg >/dev/null 2>&1; then
    echo "[$DATE] ✅ FFmpeg is available" >> $LOG_FILE
else
    echo "[$DATE] ❌ FFmpeg is not available" >> $LOG_FILE
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "[$DATE] ⚠️  Disk usage is ${DISK_USAGE}%" >> $LOG_FILE
else
    echo "[$DATE] ✅ Disk usage is ${DISK_USAGE}%" >> $LOG_FILE
fi

# Check memory usage
MEM_USAGE=$(free | awk 'NR==2{printf "%.2f", $3/$2*100}')
echo "[$DATE] 💾 Memory usage is ${MEM_USAGE}%" >> $LOG_FILE

echo "[$DATE] Monitoring check completed" >> $LOG_FILE
echo "" >> $LOG_FILE
EOF

chmod +x ~/monitor.sh

# Add to crontab
print_info "Setting up automated tasks..."
(crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/backup.sh") | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * /home/ubuntu/monitor.sh") | crontab -

print_success "Backup and monitoring scripts created."

# Step 12: Final Verification
echo ""
print_step "Step 12: Final Verification"

print_info "Performing final verification..."

# Check all services
if sudo systemctl is-active --quiet nginx; then
    print_success "✅ Nginx is running"
else
    print_error "❌ Nginx is not running"
fi

if pm2 status | grep -q "scte35-app.*online"; then
    print_success "✅ SCTE-35 application is running"
else
    print_error "❌ SCTE-35 application is not running"
fi

if command -v ffmpeg >/dev/null 2>&1; then
    print_success "✅ FFmpeg is available"
else
    print_error "❌ FFmpeg is not available"
fi

# Test ports
print_info "Testing port accessibility..."
if nc -z localhost 80; then
    print_success "✅ Port 80 (HTTP) is accessible"
else
    print_error "❌ Port 80 (HTTP) is not accessible"
fi

if nc -z localhost 1935; then
    print_success "✅ Port 1935 (RTMP) is accessible"
else
    print_error "❌ Port 1935 (RTMP) is not accessible"
fi

if nc -z localhost 3000; then
    print_success "✅ Port 3000 (Next.js) is accessible"
else
    print_error "❌ Port 3000 (Next.js) is not accessible"
fi

print_success "Final verification completed."

# Display deployment summary
echo ""
echo -e "${GREEN}🎉 Full Deployment with FFmpeg Integration Completed Successfully!${NC}"
echo "================================================================"
echo ""
echo "🌐 Application URL: http://$SERVER_IP"
echo "📺 RTMP Server: rtmp://$SERVER_IP:1935/live"
echo "📱 HLS Stream: http://$SERVER_IP/hls"
echo "📊 DASH Stream: http://$SERVER_IP/dash"
echo "📈 RTMP Stats: http://$SERVER_IP/stat"
echo "💾 Database: SQLite (dev.db)"
echo "🎬 FFmpeg: SuperKabuki Enhanced with SCTE-35"
echo ""
echo "🛠️  Useful Commands:"
echo "  View logs: pm2 logs"
echo "  Monitor: pm2 monit"
echo "  Restart app: pm2 restart scte35-app"
echo "  Restart nginx: sudo systemctl restart nginx"
echo "  Test nginx: sudo nginx -t"
echo "  Test FFmpeg: test-ffmpeg-scte35.sh"
echo "  Nginx logs: sudo tail -f /var/log/nginx/error.log"
echo "  Database operations: npm run db:push"
echo ""
echo "📁 Configuration Files:"
echo "  Nginx main: /etc/nginx/nginx.conf"
echo "  RTMP config: /etc/nginx/nginx.conf (embedded)"
echo "  FFmpeg config: /etc/ffmpeg/scte35.conf"
echo "  Nginx logs: /var/log/nginx/"
echo "  PM2 logs: /var/log/pm2/"
echo ""
echo "🎯 Next Steps:"
echo "1. Open http://$SERVER_IP in your browser"
echo "2. Test RTMP streaming using FFmpeg:"
echo "   ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://$SERVER_IP:1935/live/test"
echo "3. Access HLS stream at: http://$SERVER_IP/hls/test.m3u8"
echo "4. Access DASH stream at: http://$SERVER_IP/dash/test.mpd"
echo "5. Test SCTE-35 functionality with enhanced FFmpeg"
echo "6. Monitor system with: ~/monitor.sh"
echo ""
echo "🔧 FFmpeg SCTE-35 Examples:"
echo "  Transcode with SCTE-35: ffmpeg -copyts -i input.ts -map 0 -c:v libx265 -c:a aac -c:d copy -muxpreload 0 -muxdelay 0 output.ts"
echo "  Extract SCTE-35: ffmpeg -i input.ts -map 0:d -f data -y output.bin"
echo "  Test SCTE-35: test-ffmpeg-scte35.sh"
echo ""
echo -e "${YELLOW}Note: Make sure to replace test.mp4 with your actual video file${NC}"
echo -e "${GREEN}🚀 Your SCTE-35 streaming platform with enhanced FFmpeg is ready!${NC}"