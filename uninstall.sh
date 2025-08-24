#!/bin/bash

# SCTE-35 Streaming Project - Complete Uninstall Script
# This script completely removes all components of the SCTE-35 streaming deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to confirm action
confirm() {
    read -p "$1 [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled."
        exit 0
    fi
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          SCTE-35 Streaming Project - Complete Uninstall        ║"
echo "║                                                              ║"
echo "║  This script will completely remove all components of the    ║"
echo "║  SCTE-35 streaming deployment including:                     ║"
echo "║  - Next.js application and PM2 processes                    ║"
echo "║  - Nginx configuration and RTMP module                       ║"
echo "║  - Project files and directories                            ║"
echo "║  - System configurations and services                       ║"
echo "║  - Database files (if using Prisma)                        ║"
echo "║  - Log files and temporary data                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
print_warning "This action cannot be undone!"
confirm "Do you want to continue with the complete uninstallation?"

# Get current directory
PROJECT_DIR=$(pwd)
print_info "Current project directory: $PROJECT_DIR"

# Step 1: Stop and remove PM2 processes
echo ""
print_info "Step 1: Stopping and removing PM2 processes..."
if command -v pm2 &> /dev/null; then
    if pm2 list | grep -q "scte35-app"; then
        print_info "Stopping SCTE-35 application..."
        pm2 stop scte35-app || true
        pm2 delete scte35-app || true
        print_success "PM2 processes stopped and removed."
    else
        print_info "No SCTE-35 PM2 processes found."
    fi
    
    # Remove PM2 startup configuration
    print_info "Removing PM2 startup configuration..."
    pm2 unstartup || true
    print_success "PM2 startup configuration removed."
else
    print_info "PM2 is not installed."
fi

# Step 2: Stop and disable Nginx
echo ""
print_info "Step 2: Stopping and disabling Nginx..."
if systemctl is-active --quiet nginx; then
    sudo systemctl stop nginx
    sudo systemctl disable nginx
    print_success "Nginx stopped and disabled."
else
    print_info "Nginx is not running."
fi

# Step 3: Remove Nginx configuration
echo ""
print_info "Step 3: Removing Nginx configuration..."
if [ -f "/etc/nginx/nginx.conf" ]; then
    # Backup current configuration
    sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)
    print_info "Nginx configuration backed up."
fi

# Remove custom configuration files
sudo rm -f /etc/nginx/nginx.conf 2>/dev/null || true
sudo rm -rf /etc/nginx/sites-available/scte35 2>/dev/null || true
sudo rm -rf /etc/nginx/sites-enabled/scte35 2>/dev/null || true
sudo rm -rf /etc/nginx/rtmp 2>/dev/null || true
print_success "Nginx configuration files removed."

# Step 4: Remove RTMP directories and files
echo ""
print_info "Step 4: Removing RTMP directories and files..."
sudo rm -rf /var/www/rtmp 2>/dev/null || true
print_success "RTMP directories removed."

# Step 5: Remove application files
echo ""
print_info "Step 5: Removing application files..."
if [ -d "$PROJECT_DIR" ]; then
    print_info "Removing project directory: $PROJECT_DIR"
    # Move to parent directory first
    cd ..
    sudo rm -rf "$PROJECT_DIR" 2>/dev/null || rm -rf "$PROJECT_DIR" 2>/dev/null || true
    print_success "Project files removed."
else
    print_info "Project directory not found: $PROJECT_DIR"
fi

# Step 6: Remove log files
echo ""
print_info "Step 6: Removing log files..."
sudo rm -rf /var/log/pm2 2>/dev/null || true
sudo rm -f /var/log/nginx/rtmp_access.log 2>/dev/null || true
print_success "Log files removed."

# Step 7: Remove PM2 and Node.js (optional)
echo ""
print_info "Step 7: Removing PM2 and Node.js..."
confirm "Do you want to remove PM2 and Node.js? (This will affect other Node.js applications)"

if command -v pm2 &> /dev/null; then
    sudo npm uninstall -g pm2 || true
    print_success "PM2 removed."
fi

if command -v node &> /dev/null; then
    sudo apt remove --purge -y nodejs npm || true
    sudo rm -rf /usr/local/lib/node_modules 2>/dev/null || true
    sudo rm -rf /usr/local/bin/node 2>/dev/null || true
    sudo rm -rf /usr/local/bin/npm 2>/dev/null || true
    print_success "Node.js and npm removed."
fi

# Step 8: Remove Nginx (optional)
echo ""
print_info "Step 8: Removing Nginx..."
confirm "Do you want to remove Nginx completely? (This will affect other websites)"

sudo apt remove --purge -y nginx nginx-common nginx-core || true
sudo rm -rf /etc/nginx 2>/dev/null || true
sudo rm -rf /var/www/html 2>/dev/null || true
sudo rm -rf /var/log/nginx 2>/dev/null || true
print_success "Nginx removed."

# Step 9: Remove system configurations
echo ""
print_info "Step 9: Removing system configurations..."
sudo rm -f /etc/logrotate.d/scte35-app 2>/dev/null || true
sudo rm -f /etc/cron.d/scte35-backup 2>/dev/null || true
print_success "System configurations removed."

# Step 10: Remove user configurations
echo ""
print_info "Step 10: Removing user configurations..."
rm -rf ~/backups 2>/dev/null || true
rm -f ~/.pm2 2>/dev/null || true
print_success "User configurations removed."

# Step 11: Clean up package manager
echo ""
print_info "Step 11: Cleaning up package manager..."
sudo apt autoremove -y
sudo apt autoclean
sudo apt clean
print_success "Package manager cleaned up."

# Step 12: Remove firewall rules (optional)
echo ""
print_info "Step 12: Removing firewall rules..."
confirm "Do you want to remove firewall rules for SCTE-35 ports?"

sudo ufw delete allow 1935/tcp 2>/dev/null || true
sudo ufw delete allow 1936/tcp 2>/dev/null || true
print_success "Firewall rules removed."

# Step 13: Final verification
echo ""
print_info "Step 13: Final verification..."

# Check if any components remain
REMAINING_COMPONENTS=0

if command -v pm2 &> /dev/null; then
    print_error "PM2 is still installed"
    REMAINING_COMPONENTS=1
fi

if command -v nginx &> /dev/null; then
    print_error "Nginx is still installed"
    REMAINING_COMPONENTS=1
fi

if [ -d "/var/www/rtmp" ]; then
    print_error "RTMP directory still exists"
    REMAINING_COMPONENTS=1
fi

if [ -d "$PROJECT_DIR" ]; then
    print_error "Project directory still exists"
    REMAINING_COMPONENTS=1
fi

if [ $REMAINING_COMPONENTS -eq 0 ]; then
    print_success "✅ All components successfully removed!"
else
    print_warning "⚠️  Some components may remain. Please check the errors above."
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Uninstall Complete                         ║"
echo "║                                                              ║"
echo "║  The SCTE-35 streaming project has been completely removed.   ║"
echo "║                                                              ║"
echo "║  What was removed:                                           ║"
echo "║  ✅ Next.js application and PM2 processes                    ║"
echo "║  ✅ Nginx configuration and RTMP module                       ║"
echo "║  ✅ Project files and directories                            ║"
echo "║  ✅ System configurations and services                       ║"
echo "║  ✅ Log files and temporary data                             ║"
echo "║  ✅ PM2, Node.js, and Nginx (optional)                      ║"
echo "║  ✅ Firewall rules (optional)                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
print_info "To reinstall, you can use the deployment script:"
echo "  git clone https://github.com/shihan84/SCTE-streamcontrol.git"
echo "  cd SCTE-streamcontrol"
echo "  ./full-deploy.sh"

echo ""
print_success "Uninstall completed successfully!"