#!/bin/bash

# Fix Nginx RTMP Module Installation
# This script installs Nginx with RTMP module support

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

print_status "Installing Nginx with RTMP module support..."

# Remove existing nginx if installed
if command -v nginx &> /dev/null; then
    print_status "Removing existing Nginx installation..."
    sudo apt remove --purge -y nginx nginx-common nginx-full
    sudo apt autoremove -y
fi

# Install dependencies
print_status "Installing build dependencies..."
sudo apt update
sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev

# Create working directory
WORK_DIR="/tmp/nginx-build"
mkdir -p $WORK_DIR
cd $WORK_DIR

# Download Nginx source
print_status "Downloading Nginx source..."
NGINX_VERSION="1.21.6"
wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz
tar -xzf nginx-$NGINX_VERSION.tar.gz
cd nginx-$NGINX_VERSION

# Download RTMP module
print_status "Downloading RTMP module..."
git clone https://github.com/arut/nginx-rtmp-module.git

# Configure Nginx with RTMP module
print_status "Configuring Nginx with RTMP module..."
./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --add-module=./nginx-rtmp-module

# Compile and install
print_status "Compiling Nginx..."
make -j$(nproc)

print_status "Installing Nginx..."
sudo make install

# Create nginx user and group
sudo groupadd -f nginx
sudo useradd -r -g nginx nginx

# Create cache directory
sudo mkdir -p /var/cache/nginx
sudo chown nginx:nginx /var/cache/nginx

# Create systemd service
print_status "Creating systemd service..."
sudo tee /etc/systemd/system/nginx.service > /dev/null << 'EOF'
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=process
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Enable and start nginx
sudo systemctl daemon-reload
sudo systemctl enable nginx
sudo systemctl start nginx

# Create symbolic links for common commands
sudo ln -sf /usr/sbin/nginx /usr/bin/nginx

# Clean up
cd /
rm -rf $WORK_DIR

print_status "Nginx with RTMP module installed successfully!"
nginx -V 2>&1 | grep -o -- '--add-module=.*' || print_warning "RTMP module not found in nginx -V output"

print_status "Testing Nginx configuration..."
sudo nginx -t

print_status "Nginx RTMP module installation completed!"