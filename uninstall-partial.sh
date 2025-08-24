#!/bin/bash

# SCTE-35 Streaming Control Center - Partial Uninstall Script
# This script allows selective removal of specific components
# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
   error "This script must be run as root. Use: sudo ./uninstall-partial.sh"
fi

# Function to display menu
show_menu() {
    echo ""
    echo "🔧 SCTE-35 Streaming Control Center - Partial Uninstall"
    echo "======================================================"
    echo ""
    echo "Select components to uninstall:"
    echo ""
    echo "1.  📱 Application Only (keep database and config)"
    echo "2.  🗄️  Database Only (keep application and config)"
    echo "3.  🌐 Nginx Only (keep application and database)"
    echo "4.  ⚙️  PM2 Processes Only"
    echo "5.  📁 Log Files Only"
    echo "6.  💾 Backup Files Only"
    echo "7.  🔥 Application + Database"
    echo "8.  🌐 Nginx + PM2"
    echo "9.  📱 Application + Logs"
    echo "10. 🗄️  Database + Backups"
    echo "11. 🧹 Clean Configuration Files"
    echo "12. 🔄 Reset Application (keep database)"
    echo "13. 🛑 Stop Services Only"
    echo "14. 📊 Show Current Status"
    echo "15. 🚪 Exit"
    echo ""
    read -p "Enter your choice (1-15): " choice
}

# Function to get current user
get_current_user() {
    echo ${SUDO_USER:-$(whoami)}
}

# Function to show current status
show_status() {
    echo ""
    echo "📊 Current System Status"
    echo "========================"
    
    CURRENT_USER=$(get_current_user)
    
    # Check PM2 status
    if command -v pm2 &> /dev/null; then
        echo -e "${CYAN}PM2 Status:${NC}"
        pm2 list 2>/dev/null || echo "  No PM2 processes running"
    else
        echo -e "${YELLOW}PM2:${NC} Not installed"
    fi
    
    # Check Nginx status
    echo -e "${CYAN}Nginx Status:${NC}"
    if systemctl is-active --quiet nginx; then
        echo "  ✅ Running (PID: $(systemctl show --property MainPID --value nginx))"
        echo "  📡 RTMP Module: $(nginx -V 2>&1 | grep -q rtmp && echo '✅ Installed' || echo '❌ Not found')"
    else
        echo "  ❌ Not running"
    fi
    
    # Check application directories
    echo -e "${CYAN}Application Directories:${NC}"
    APP_DIRS=(
        "/home/$CURRENT_USER/SCTE-streamcontrol"
        "/home/$CURRENT_USER/streamcontrol"
        "/home/ubuntu/SCTE-streamcontrol"
        "/home/ubuntu/streamcontrol"
    )
    
    for dir in "${APP_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "  📁 $dir ($(du -sh "$dir" 2>/dev/null | cut -f1))"
        fi
    done
    
    # Check database files
    echo -e "${CYAN}Database Files:${NC}"
    find /home -name "custom.db" -path "*/SCTE-streamcontrol/*" -type f 2>/dev/null | while read -r db; do
        echo "  🗄️  $db ($(du -sh "$db" 2>/dev/null | cut -f1))"
    done
    
    # Check firewall status
    echo -e "${CYAN}Firewall Status:${NC}"
    if command -v ufw &> /dev/null; then
        ufw status | head -5
    else
        echo "  UFW: Not installed"
    fi
    
    # Check port usage
    echo -e "${CYAN}Port Usage:${NC}"
    for port in 80 443 1935 1936 3000; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo "  🔌 Port $port: $(netstat -tlnp 2>/dev/null | grep ":$port " | head -1 | awk '{print $7}')"
        else
            echo "  🔌 Port $port: Free"
        fi
    done
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to remove application only
remove_application_only() {
    log "Removing application files only..."
    
    CURRENT_USER=$(get_current_user)
    APP_DIRS=(
        "/home/$CURRENT_USER/SCTE-streamcontrol"
        "/home/$CURRENT_USER/streamcontrol"
        "/home/ubuntu/SCTE-streamcontrol"
        "/home/ubuntu/streamcontrol"
    )
    
    for dir in "${APP_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            log "Removing $dir..."
            rm -rf "$dir" || true
        fi
    done
    
    # Stop PM2 processes but keep PM2 installed
    if command -v pm2 &> /dev/null; then
        pm2 stop all || true
        pm2 delete all || true
    fi
    
    log "Application files removed (database and configuration preserved)"
}

# Function to remove database only
remove_database_only() {
    log "Removing database files only..."
    
    CURRENT_USER=$(get_current_user)
    
    # Remove database files
    find /home -name "custom.db" -path "*/SCTE-streamcontrol/*" -type f -delete 2>/dev/null || true
    find /home -name "*.db" -path "*/SCTE-streamcontrol/*" -type f -delete 2>/dev/null || true
    find /home -name "*.db" -path "*/streamcontrol/*" -type f -delete 2>/dev/null || true
    
    # Remove backup directories
    find /home -name "backups" -path "*/SCTE-streamcontrol/*" -type d -exec rm -rf {} + 2>/dev/null || true
    find /home -name "backups" -path "*/streamcontrol/*" -type d -exec rm -rf {} + 2>/dev/null || true
    
    log "Database files removed (application and configuration preserved)"
}

# Function to remove nginx only
remove_nginx_only() {
    log "Removing Nginx only..."
    
    # Stop Nginx
    systemctl stop nginx || true
    systemctl disable nginx || true
    
    # Remove Nginx packages
    apt-get remove --purge -y nginx nginx-common nginx-full nginx-core nginx-extras || true
    
    # Remove Nginx configuration
    rm -rf /etc/nginx || true
    rm -rf /var/log/nginx || true
    rm -rf /var/www/html || true
    
    # Remove systemd service
    rm -f /etc/systemd/system/nginx.service || true
    systemctl daemon-reload || true
    
    log "Nginx removed (application and database preserved)"
}

# Function to remove PM2 processes only
remove_pm2_only() {
    log "Removing PM2 processes only..."
    
    if command -v pm2 &> /dev/null; then
        pm2 stop all || true
        pm2 delete all || true
        pm2 kill || true
        
        # Clear PM2 logs
        rm -rf /var/log/pm2 || true
        rm -rf ~/.pm2 || true
    fi
    
    log "PM2 processes removed (PM2 binary still available)"
}

# Function to remove log files only
remove_logs_only() {
    log "Removing log files only..."
    
    # Remove application logs
    rm -rf /var/log/scte35* || true
    rm -rf /var/log/streamcontrol* || true
    rm -rf /var/log/pm2 || true
    
    # Remove Nginx logs
    rm -rf /var/log/nginx/* || true
    
    # Find and remove log files in home directories
    find /home -name "*.log" -path "*/SCTE-streamcontrol/*" -type f -delete 2>/dev/null || true
    find /home -name "*.log" -path "*/streamcontrol/*" -type f -delete 2>/dev/null || true
    
    log "Log files removed"
}

# Function to remove backup files only
remove_backups_only() {
    log "Removing backup files only..."
    
    # Remove backup files
    find /home -name "*backup*" -path "*/SCTE-streamcontrol/*" -type f -delete 2>/dev/null || true
    find /home -name "*backup*" -path "*/streamcontrol/*" -type f -delete 2>/dev/null || true
    
    # Remove backup directories
    find /home -name "backups" -path "*/SCTE-streamcontrol/*" -type d -exec rm -rf {} + 2>/dev/null || true
    find /home -name "backups" -path "*/streamcontrol/*" -type d -exec rm -rf {} + 2>/dev/null || true
    
    log "Backup files removed"
}

# Function to remove application and database
remove_app_database() {
    log "Removing application and database..."
    
    remove_application_only
    remove_database_only
    
    log "Application and database removed"
}

# Function to remove nginx and PM2
remove_nginx_pm2() {
    log "Removing Nginx and PM2..."
    
    remove_nginx_only
    remove_pm2_only
    
    log "Nginx and PM2 removed"
}

# Function to remove application and logs
remove_app_logs() {
    log "Removing application and logs..."
    
    remove_application_only
    remove_logs_only
    
    log "Application and logs removed"
}

# Function to remove database and backups
remove_database_backups() {
    log "Removing database and backups..."
    
    remove_database_only
    remove_backups_only
    
    log "Database and backups removed"
}

# Function to clean configuration files
clean_config_files() {
    log "Cleaning configuration files..."
    
    # Remove systemd service files
    rm -f /etc/systemd/system/scte35* || true
    rm -f /etc/systemd/system/streamcontrol* || true
    systemctl daemon-reload || true
    
    # Remove cron jobs
    crontab -l 2>/dev/null | grep -v "SCTE-streamcontrol" | grep -v "streamcontrol" | crontab - || true
    rm -f /etc/cron.d/scte35* || true
    rm -f /etc/cron.d/streamcontrol* || true
    
    # Remove environment files
    find /home -name ".env" -path "*/SCTE-streamcontrol/*" -type f -delete 2>/dev/null || true
    find /home -name ".env" -path "*/streamcontrol/*" -type f -delete 2>/dev/null || true
    
    log "Configuration files cleaned"
}

# Function to reset application
reset_application() {
    log "Resetting application (keeping database)..."
    
    CURRENT_USER=$(get_current_user)
    
    # Stop services
    systemctl stop nginx || true
    if command -v pm2 &> /dev/null; then
        pm2 stop all || true
        pm2 delete all || true
    fi
    
    # Remove application files but preserve database
    APP_DIRS=(
        "/home/$CURRENT_USER/SCTE-streamcontrol"
        "/home/$CURRENT_USER/streamcontrol"
        "/home/ubuntu/SCTE-streamcontrol"
        "/home/ubuntu/streamcontrol"
    )
    
    for dir in "${APP_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            # Backup database first
            if [[ -d "$dir/db" ]]; then
                cp -r "$dir/db" "/tmp/db_backup_$(date +%Y%m%d_%H%M%S)" || true
            fi
            # Remove application directory
            rm -rf "$dir" || true
        fi
    done
    
    # Clean logs
    remove_logs_only
    
    log "Application reset complete (database preserved in /tmp/)"
}

# Function to stop services only
stop_services_only() {
    log "Stopping services only..."
    
    # Stop PM2 processes
    if command -v pm2 &> /dev/null; then
        pm2 stop all || true
    fi
    
    # Stop Nginx
    systemctl stop nginx || true
    
    # Stop firewall
    if command -v ufw &> /dev/null; then
        ufw --force disable || true
    fi
    
    log "All services stopped"
}

# Function to confirm action
confirm_action() {
    local action="$1"
    echo ""
    echo -e "${YELLOW}⚠️  $action${NC}"
    echo "This action cannot be undone."
    read -p "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Action cancelled."
        return 1
    fi
    return 0
}

# Main menu loop
main() {
    while true; do
        show_menu
        
        case $choice in
            1)
                confirm_action "Remove application files only (keep database and config)" && \
                remove_application_only
                ;;
            2)
                confirm_action "Remove database files only (keep application and config)" && \
                remove_database_only
                ;;
            3)
                confirm_action "Remove Nginx only (keep application and database)" && \
                remove_nginx_only
                ;;
            4)
                confirm_action "Remove PM2 processes only" && \
                remove_pm2_only
                ;;
            5)
                confirm_action "Remove log files only" && \
                remove_logs_only
                ;;
            6)
                confirm_action "Remove backup files only" && \
                remove_backups_only
                ;;
            7)
                confirm_action "Remove application and database" && \
                remove_app_database
                ;;
            8)
                confirm_action "Remove Nginx and PM2" && \
                remove_nginx_pm2
                ;;
            9)
                confirm_action "Remove application and logs" && \
                remove_app_logs
                ;;
            10)
                confirm_action "Remove database and backups" && \
                remove_database_backups
                ;;
            11)
                confirm_action "Clean configuration files" && \
                clean_config_files
                ;;
            12)
                confirm_action "Reset application (keep database)" && \
                reset_application
                ;;
            13)
                stop_services_only
                ;;
            14)
                show_status
                ;;
            15)
                echo ""
                echo -e "${BLUE}Thank you for using SCTE-35 Streaming Control Center!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please select 1-15.${NC}"
                sleep 2
                ;;
        esac
        
        if [[ $choice -ne 14 && $choice -ne 15 ]]; then
            echo ""
            echo -e "${GREEN}✅ Operation completed successfully!${NC}"
            read -p "Press Enter to continue..."
        fi
    done
}

# Run main function
main "$@"

# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.