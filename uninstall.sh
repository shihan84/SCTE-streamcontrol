#!/bin/bash

# SCTE-35 Streaming Control Center - Complete Uninstall Script
# This script removes all components of the SCTE-35 Streaming Control Center
# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root. Use: sudo ./uninstall.sh"
fi

# Function to confirm uninstallation
confirm_uninstall() {
    echo ""
    echo -e "${RED}⚠️  WARNING: This will completely remove the SCTE-35 Streaming Control Center!${NC}"
    echo -e "${RED}   The following will be removed:${NC}"
    echo "   • Application files and directories"
    echo "   • Nginx with RTMP module"
    echo "   • PM2 processes and configuration"
    echo "   • Database files"
    echo "   • System services"
    echo "   • Firewall rules"
    echo "   • Log files"
    echo "   • Backup files"
    echo ""
    echo -e "${YELLOW}This action cannot be undone!${NC}"
    echo ""
    read -p "Are you sure you want to continue? (Type 'YES' to confirm): " confirm
    if [[ "$confirm" != "YES" ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
}

# Function to stop services
stop_services() {
    log "Stopping services..."
    
    # Stop PM2 processes
    if command -v pm2 &> /dev/null; then
        log "Stopping PM2 processes..."
        pm2 stop all || true
        pm2 delete all || true
        pm2 kill || true
    fi
    
    # Stop Nginx
    if systemctl is-active --quiet nginx; then
        log "Stopping Nginx..."
        systemctl stop nginx || true
    fi
    
    # Stop other related services
    systemctl stop fail2ban || true
    systemctl stop ufw || true
}

# Function to remove PM2 and Node.js applications
remove_pm2_apps() {
    log "Removing PM2 applications..."
    
    # Remove PM2 startup configuration
    if command -v pm2 &> /dev/null; then
        pm2 unstartup || true
    fi
    
    # Remove PM2 log files
    rm -rf /var/log/pm2 || true
    rm -rf ~/.pm2 || true
    
    log "PM2 applications removed"
}

# Function to remove Nginx
remove_nginx() {
    log "Removing Nginx..."
    
    # Stop and disable Nginx service
    systemctl disable nginx || true
    systemctl stop nginx || true
    
    # Remove Nginx packages
    apt-get remove --purge -y nginx nginx-common nginx-full nginx-core nginx-extras || true
    apt-get autoremove -y || true
    
    # Remove Nginx configuration and files
    rm -rf /etc/nginx || true
    rm -rf /var/log/nginx || true
    rm -rf /var/www/html || true
    rm -rf /usr/sbin/nginx || true
    rm -rf /usr/lib/nginx || true
    
    # Remove systemd service file
    rm -f /etc/systemd/system/nginx.service || true
    systemctl daemon-reload || true
    
    log "Nginx removed"
}

# Function to remove application files
remove_application_files() {
    log "Removing application files..."
    
    # Get the current user who ran the script
    CURRENT_USER=${SUDO_USER:-$(whoami)}
    APP_DIRS=(
        "/home/$CURRENT_USER/SCTE-streamcontrol"
        "/home/$CURRENT_USER/streamcontrol"
        "/home/ubuntu/SCTE-streamcontrol"
        "/home/ubuntu/streamcontrol"
        "/opt/SCTE-streamcontrol"
        "/opt/streamcontrol"
    )
    
    for dir in "${APP_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            log "Removing $dir..."
            rm -rf "$dir" || true
        fi
    done
    
    # Remove any remaining application files
    rm -rf /tmp/scte35* || true
    rm -rf /tmp/nginx* || true
    
    log "Application files removed"
}

# Function to remove database files
remove_database_files() {
    log "Removing database files..."
    
    # Remove database files
    DATABASE_DIRS=(
        "/home/$CURRENT_USER/SCTE-streamcontrol/db"
        "/home/$CURRENT_USER/streamcontrol/db"
        "/home/ubuntu/SCTE-streamcontrol/db"
        "/home/ubuntu/streamcontrol/db"
        "./db"
    )
    
    for dir in "${DATABASE_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            log "Removing database directory: $dir..."
            rm -rf "$dir" || true
        fi
    done
    
    # Remove specific database files
    find /home -name "custom.db" -type f -delete 2>/dev/null || true
    find /home -name "*.db" -path "*/SCTE-streamcontrol/*" -type f -delete 2>/dev/null || true
    find /home -name "*.db" -path "*/streamcontrol/*" -type f -delete 2>/dev/null || true
    
    log "Database files removed"
}

# Function to remove firewall rules
remove_firewall_rules() {
    log "Removing firewall rules..."
    
    # Remove UFW rules
    if command -v ufw &> /dev/null; then
        ufw delete allow 22/tcp || true
        ufw delete allow 80/tcp || true
        ufw delete allow 443/tcp || true
        ufw delete allow 1935/tcp || true
        ufw delete allow 1936/tcp || true
        ufw --force disable || true
    fi
    
    # Remove iptables rules (if any)
    iptables -F INPUT || true
    iptables -F OUTPUT || true
    iptables -F FORWARD || true
    
    log "Firewall rules removed"
}

# Function to remove system users and groups
remove_users_groups() {
    log "Removing system users and groups..."
    
    # Remove Nginx user
    if id "nginx" &>/dev/null; then
        userdel -r nginx || true
    fi
    
    # Remove www-data user (if created for this app)
    if id "www-data" &>/dev/null; then
        # www-data might be used by other services, so only remove if it's not a system user
        if ! id -u www-data &>/dev/null || [[ $(id -u www-data) -ge 1000 ]]; then
            userdel -r www-data || true
        fi
    fi
    
    log "Users and groups removed"
}

# Function to remove log files and backups
remove_logs_backups() {
    log "Removing log files and backups..."
    
    # Remove log files
    rm -rf /var/log/scte35* || true
    rm -rf /var/log/streamcontrol* || true
    find /var/log -name "*scte35*" -type f -delete 2>/dev/null || true
    find /var/log -name "*streamcontrol*" -type f -delete 2>/dev/null || true
    
    # Remove backup files
    find /home -name "*backup*" -path "*/SCTE-streamcontrol/*" -type f -delete 2>/dev/null || true
    find /home -name "*backup*" -path "*/streamcontrol/*" -type f -delete 2>/dev/null || true
    find /home -name "backups" -path "*/SCTE-streamcontrol/*" -type d -exec rm -rf {} + 2>/dev/null || true
    find /home -name "backups" -path "*/streamcontrol/*" -type d -exec rm -rf {} + 2>/dev/null || true
    
    log "Log files and backups removed"
}

# Function to remove cron jobs
remove_cron_jobs() {
    log "Removing cron jobs..."
    
    # Remove cron jobs related to the application
    crontab -l 2>/dev/null | grep -v "SCTE-streamcontrol" | grep -v "streamcontrol" | crontab - || true
    
    # Remove system cron jobs
    rm -f /etc/cron.d/scte35* || true
    rm -f /etc/cron.d/streamcontrol* || true
    rm -f /etc/cron.daily/scte35* || true
    rm -f /etc/cron.daily/streamcontrol* || true
    
    log "Cron jobs removed"
}

# Function to clean up package cache
cleanup_package_cache() {
    log "Cleaning up package cache..."
    
    apt-get clean || true
    apt-get autoremove -y || true
    apt-get autoclean || true
    
    log "Package cache cleaned"
}

# Function to generate uninstallation report
generate_report() {
    log "Generating uninstallation report..."
    
    REPORT_FILE="/tmp/scte35_uninstall_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$REPORT_FILE" << 'EOF'
SCTE-35 Streaming Control Center - Uninstallation Report
========================================================
Date: $(date)
Uninstallation completed successfully.

Components Removed:
- PM2 processes and configuration
- Nginx with RTMP module
- Application files and directories
- Database files
- System services
- Firewall rules
- Log files
- Backup files
- Cron jobs
- System users and groups (app-specific)

Note: Some system packages that were installed as dependencies
may remain on the system. These can be removed manually if needed.

© 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
EOF
    
    log "Uninstallation report saved to: $REPORT_FILE"
}

# Main uninstallation process
main() {
    echo ""
    echo "🗑️  SCTE-35 Streaming Control Center - Complete Uninstall"
    echo "========================================================"
    echo ""
    
    # Confirm uninstallation
    confirm_uninstall
    
    echo ""
    log "Starting uninstallation process..."
    
    # Execute uninstallation steps
    stop_services
    remove_pm2_apps
    remove_nginx
    remove_application_files
    remove_database_files
    remove_firewall_rules
    remove_users_groups
    remove_logs_backups
    remove_cron_jobs
    cleanup_package_cache
    generate_report
    
    echo ""
    echo -e "${GREEN}✅ Uninstallation completed successfully!${NC}"
    echo ""
    echo "📋 Summary:"
    echo "   • All SCTE-35 Streaming Control Center components removed"
    echo "   • System services stopped and disabled"
    echo "   • Application files and databases deleted"
    echo "   • Firewall rules removed"
    echo "   • Log files and backups cleaned up"
    echo ""
    echo "📄 Uninstallation report generated in: /tmp/"
    echo ""
    echo "🔧 Note: Some system packages may remain. These can be removed"
    echo "   manually if they are no longer needed."
    echo ""
    echo -e "${BLUE}Thank you for using SCTE-35 Streaming Control Center!${NC}"
    echo ""
}

# Run main function
main "$@"

# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.