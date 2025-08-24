#!/bin/bash

# Fix Sudo Issues for Deployment
# This script helps handle sudo requirements during deployment

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

echo -e "${GREEN}Sudo Fix for Deployment${NC}"
echo "============================"

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    print_error "sudo command not found. Please install sudo:"
    echo "  apt update && apt install -y sudo"
    echo "  Then add your user to sudo group:"
    echo "  usermod -aG sudo \$USER"
    echo "  Log out and log back in"
    exit 1
fi

# Check if user has sudo privileges
print_status "Checking sudo privileges..."
if ! sudo -n true 2>/dev/null; then
    print_warning "sudo requires password. Let's configure passwordless sudo for deployment..."
    
    # Create sudoers file for deployment
    print_status "Creating sudoers configuration..."
    sudo tee /etc/sudoers.d/deployment > /dev/null << 'EOF'
# Allow passwordless sudo for deployment user
%sudo ALL=(ALL) NOPASSWD: ALL
EOF
    
    print_status "Sudoers configuration updated"
    
    # Test sudo again
    if sudo -n true 2>/dev/null; then
        print_status "Passwordless sudo is now configured"
    else
        print_warning "Passwordless sudo still not working. You may need to:"
        echo "  1. Log out and log back in"
        echo "  2. Or run the deployment script with sudo:"
        echo "     sudo bash deploy.sh"
        echo ""
        print_warning "Continuing with manual sudo prompts..."
    fi
else
    print_status "Passwordless sudo is already configured"
fi

# Check if user is in sudo group
if ! groups | grep -q sudo; then
    print_warning "User is not in sudo group. Adding to sudo group..."
    sudo usermod -aG sudo $USER
    
    print_warning "User added to sudo group. Please log out and log back in for changes to take effect."
    print_warning "Then run the deployment script again."
    exit 1
fi

# Check if firewall is available
if command -v ufw &> /dev/null; then
    print_status "Configuring firewall rules..."
    sudo ufw allow 22/tcp    # SSH
    sudo ufw allow 80/tcp    # HTTP
    sudo ufw allow 443/tcp   # HTTPS
    sudo ufw allow 1935/tcp  # RTMP
    sudo ufw allow 1936/tcp  # RTMP stats
    sudo ufw --force enable
    print_status "Firewall configured"
else
    print_warning "UFW firewall not found. Skipping firewall configuration."
fi

# Create necessary directories
print_status "Creating necessary directories..."
sudo mkdir -p /usr/local/nginx/conf/rtmp
sudo mkdir -p /usr/local/nginx/conf/sites-available
sudo mkdir -p /usr/local/nginx/conf/sites-enabled
sudo mkdir -p /var/www/rtmp/hls
sudo mkdir -p /var/www/rtmp/dash
sudo mkdir -p /var/log/pm2

# Set proper permissions
print_status "Setting permissions..."
sudo chown -R $USER:$USER /usr/local/nginx/conf
sudo chown -R $USER:$USER /var/www/rtmp
sudo chown -R $USER:$USER /var/log/pm2

print_status "Sudo fix completed successfully!"
echo ""
echo "You can now run the deployment script:"
echo "  bash deploy.sh"
echo ""
echo "Or if you still have issues, try:"
echo "  bash deploy-no-sudo.sh"
echo ""
echo "Useful Commands:"
echo "  Check sudo status: sudo -l"
echo "  Check groups: groups"
echo "  Test sudo: sudo whoami"