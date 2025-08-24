#!/bin/bash

# Quick fix for Nginx installation issue in full-deploy.sh
# Run this script if you get the error: "tee: /etc/nginx/nginx.conf: No such file or directory"

set -e

echo "🔧 Fixing Nginx installation issue..."

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

print_info "Step 1: Remove existing Nginx installation..."
apt remove --purge -y nginx nginx-common nginx-full nginx-core || true
apt autoremove -y
apt autoclean

print_info "Step 2: Update package lists..."
apt update

print_info "Step 3: Install Nginx..."
apt install -y nginx

print_info "Step 4: Create necessary directories..."
mkdir -p /etc/nginx/conf.d
mkdir -p /var/log/nginx
mkdir -p /var/www/rtmp/hls
mkdir -p /var/www/rtmp/dash
touch /etc/nginx/nginx.conf

print_info "Step 5: Set proper permissions..."
chown -R www-data:www-data /var/www/rtmp
chmod -R 755 /var/www/rtmp

print_info "Step 6: Verify Nginx installation..."
if command -v nginx >/dev/null 2>&1; then
    print_success "Nginx is now installed: $(nginx -v 2>&1)"
else
    print_error "Nginx installation failed"
    exit 1
fi

print_info "Step 7: Test Nginx configuration..."
nginx -t

print_success "✅ Nginx installation issue has been fixed!"
echo ""
echo "You can now re-run the full-deploy.sh script:"
echo "  ./full-deploy.sh"
echo ""
echo "Or continue with the deployment from where it failed."