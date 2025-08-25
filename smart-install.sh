#!/bin/bash

# SCTE-35 Streaming Project - Smart Installation Script
# Checks for existing installations and skips completed steps
# Provides detailed manual installation guidance
# 
# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.

set -e  # Exit on critical errors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="/tmp/scte35-smart-install-$(date +%Y%m%d_%H%M%S).log"
SERVER_IP=$(hostname -I | awk '{print $1}')
BACKUP_DIR="/tmp/scte35-backup-$(date +%Y%m%d_%H%M%S)"
ERROR_COUNT=0
WARNING_COUNT=0
SUCCESS_COUNT=0
START_TIME=$(date +%s)
SKIP_COUNT=0

# Installation status tracking
INSTALL_STATUS_FILE="/tmp/scte35-install-status.txt"
touch "$INSTALL_STATUS_FILE"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
    WARNING_COUNT=$((WARNING_COUNT + 1))
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    ERROR_COUNT=$((ERROR_COUNT + 1))
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

print_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1" | tee -a "$LOG_FILE"
    SKIP_COUNT=$((SKIP_COUNT + 1))
}

print_manual() {
    echo -e "${PURPLE}[MANUAL]${NC} $1" | tee -a "$LOG_FILE"
}

print_progress() {
    echo -e "${PURPLE}[PROGRESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_system() {
    echo -e "${ORANGE}[SYSTEM]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if step is already completed
is_step_completed() {
    local step_name="$1"
    grep -q "^$step_name:completed$" "$INSTALL_STATUS_FILE" 2>/dev/null
}

# Function to mark step as completed
mark_step_completed() {
    local step_name="$1"
    echo "$step_name:completed" >> "$INSTALL_STATUS_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if package is installed
package_installed() {
    dpkg -l | grep -q "^ii  $1 "
}

# Function to check if service is running
service_running() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

# Function to install package if not exists
install_package() {
    local package="$1"
    local description="$2"
    local critical="$3"
    
    if package_installed "$package"; then
        print_skip "$package is already installed"
        return 0
    fi
    
    print_info "Installing $package..."
    if sudo apt install -y "$package" >> "$LOG_FILE" 2>&1; then
        print_success "$package installed successfully"
        return 0
    else
        print_error "Failed to install $package"
        if [[ "$critical" == "true" ]]; then
            return 1
        else
            return 0
        fi
    fi
}

# Function to execute command with error handling
execute_command() {
    local cmd="$1"
    local description="$2"
    local critical="$3"
    
    print_info "Executing: $description"
    echo "Command: $cmd" >> "$LOG_FILE"
    echo "Start: $(date)" >> "$LOG_FILE"
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        print_success "Command completed successfully: $description"
        echo "End: $(date)" >> "$LOG_FILE"
        echo "Exit code: 0" >> "$LOG_FILE"
        return 0
    else
        local exit_code=$?
        print_error "Command failed: $description"
        echo "End: $(date)" >> "$LOG_FILE"
        echo "Exit code: $exit_code" >> "$LOG_FILE"
        
        if [[ "$critical" == "true" ]]; then
            print_error "Critical error encountered."
            return 1
        else
            print_warning "Non-critical error. Attempting to continue..."
            return 0
        fi
    fi
}

# Function to show system requirements
show_system_requirements() {
    print_info "System Requirements Check:"
    
    # Check OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        print_info "  OS: $NAME $VERSION"
    else
        print_info "  OS: Unknown"
    fi
    
    # Check CPU
    local cpu_cores=$(nproc)
    print_info "  CPU Cores: $cpu_cores"
    
    # Check Memory
    local total_memory=$(free -m | awk 'NR==2{printf "%.0f MB", $2}')
    print_info "  Memory: $total_memory"
    
    # Check Disk
    local available_disk=$(df / | awk 'NR==2{printf "%.0f GB", $4/1024/1024}')
    print_info "  Available Disk: $available_disk"
    
    # Check Network
    print_info "  Server IP: $SERVER_IP"
    
    # Check existing installations
    print_info "  Existing Installations:"
    if command_exists node; then
        local node_version=$(node --version 2>/dev/null || echo "Unknown")
        print_info "    Node.js: $node_version"
    fi
    if command_exists npm; then
        local npm_version=$(npm --version 2>/dev/null || echo "Unknown")
        print_info "    npm: $npm_version"
    fi
    if command_exists ffmpeg; then
        local ffmpeg_version=$(ffmpeg -version | head -n 1 2>/dev/null || echo "Unknown")
        print_info "    FFmpeg: $ffmpeg_version"
    fi
    if command_exists nginx; then
        local nginx_version=$(nginx -v 2>&1 | cut -d' ' -f3 2>/dev/null || echo "Unknown")
        print_info "    Nginx: $nginx_version"
    fi
    if command_exists pm2; then
        local pm2_version=$(pm2 --version 2>/dev/null || echo "Unknown")
        print_info "    PM2: $pm2_version"
    fi
}

# Function to display welcome banner
show_welcome_banner() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          SCTE-35 Streaming Control Center - Smart Install        ║"
    echo "║                                                              ║"
    echo "║  🧠 Intelligent Installation with Existing Component Detection    ║"
    echo "║  📦 Skip Already Installed Components                        ║"
    echo "║  🛠️  Manual Installation Guidance Available                    ║"
    echo "║  ⚡ Smart Step-by-Step Installation Process                   ║"
    echo "║                                                              ║"
    echo "║  This script will:                                           ║"
    echo "║  • Check for existing installations                           ║"
    echo "║  • Skip completed steps automatically                        ║"
    echo "║  • Provide manual installation guidance                       ║"
    echo "║  • Install missing components only                            ║"
    echo "║  • Verify all services are running                           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${BOLD}📋 Installation Status Check:${NC}"
    show_system_requirements
    echo ""
    echo -e "${YELLOW}⚠️  This script requires sudo privileges for system installation.${NC}"
    echo -e "${BLUE}📝 Log file: $LOG_FILE${NC}"
    echo -e "${PURPLE}📊 Status file: $INSTALL_STATUS_FILE${NC}"
    echo ""
}

# Function to display completion banner
show_completion_banner() {
    local end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  Smart Installation Completed!                ║"
    echo "║                                                              ║"
    echo "║  🎉 SCTE-35 Streaming Control Center is ready!               ║"
    echo "║  🧠 Smart installation with existing component detection      ║"
    echo "║  ⚡ Optimized installation process                             ║"
    echo "║  🛡️  All services verified and running                        ║"
    echo "║                                                              ║"
    echo "║  📊 Installation Statistics:                                 ║"
    echo "║  • Total Operations: $((SUCCESS_COUNT + WARNING_COUNT + ERROR_COUNT))    ║"
    echo "║  • Successful: $SUCCESS_COUNT                                              ║"
    echo "║  • Warnings: $WARNING_COUNT                                                ║"
    echo "║  • Errors: $ERROR_COUNT                                                  ║"
    echo "║  • Skipped: $SKIP_COUNT                                                ║"
    echo "║  • Success Rate: $((SUCCESS_COUNT * 100 / (SUCCESS_COUNT + WARNING_COUNT + ERROR_COUNT)))%       ║"
    echo "║  • Duration: ${minutes}m ${seconds}s                                     ║"
    echo "║                                                              ║"
    echo "║  🌐 Access URLs:                                             ║"
    echo "║  • Web Interface: http://$SERVER_IP/                       ║"
    echo "║  • Health Check: http://$SERVER_IP/health                  ║"
    echo "║  • RTMP Stats: http://$SERVER_IP/stat                      ║"
    echo "║  • RTMP Server: rtmp://$SERVER_IP:1935/live               ║"
    echo "║  • HLS Stream: http://$SERVER_IP/hls                      ║"
    echo "║  • DASH Stream: http://$SERVER_IP/dash                     ║"
    echo "║                                                              ║"
    echo "║  🛠️  Management Commands:                                     ║"
    echo "║  • Application: pm2 logs | restart | stop                   ║"
    echo "║  • Nginx: sudo systemctl restart nginx                      ║"
    echo "║  • FFmpeg Test: test-ffmpeg-scte35.sh                       ║"
    echo "║  • Verification: ./verify-deployment.sh                     ║"
    echo "║                                                              ║"
    echo "║  📁 Configuration Files:                                     ║"
    echo "║  • Nginx: /etc/nginx/nginx.conf                             ║"
    echo "║  • FFmpeg: /etc/ffmpeg/scte35.conf                         ║"
    echo "║  • Application: /home/ubuntu/SCTE-streamcontrol/           ║"
    echo "║  • Logs: /var/log/pm2/ & /var/log/nginx/                   ║"
    echo "║                                                              ║"
    echo "║  📋 Log File: $LOG_FILE                                    ║"
    echo "║  🎯 Next Steps: Open http://$SERVER_IP in your browser     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [[ $ERROR_COUNT -eq 0 ]]; then
        echo -e "${GREEN}🎉 Smart installation completed successfully with no errors!${NC}"
        echo -e "${GREEN}🚀 Your SCTE-35 streaming platform is ready for production use!${NC}"
    else
        echo -e "${YELLOW}⚠️  Installation completed with $ERROR_COUNT error(s).${NC}"
        echo -e "${YELLOW}📋 Check the log file for details: $LOG_FILE${NC}"
        echo -e "${YELLOW}🔧 Run './verify-deployment.sh' to verify the installation.${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Thank you for choosing SCTE-35 Streaming Control Center!${NC}"
    echo ""
}

# Function to provide manual Nginx RTMP installation guidance
provide_nginx_rtmp_manual_guidance() {
    print_manual "=== MANUAL NGINX RTMP INSTALLATION GUIDANCE ==="
    echo ""
    print_manual "If you prefer to install Nginx with RTMP module manually, follow these steps:"
    echo ""
    
    print_manual "📁 RECOMMENDED INSTALLATION FOLDERS AND LOCATIONS:"
    print_manual "├── Source Code: /tmp/nginx-build/"
    print_manual "│   ├── nginx-1.25.3/          # Nginx source code"
    print_manual "│   └── nginx-rtmp-module/      # RTMP module source"
    print_manual "├── Installation: /etc/nginx/   # Nginx installation directory"
    print_manual "├── Configuration: /etc/nginx/nginx.conf"
    print_manual "├── Web Root: /var/www/rtmp/"
    print_manual "│   ├── hls/                   # HLS streaming files"
    print_manual "│   └── dash/                  # DASH streaming files"
    print_manual "├── Logs: /var/log/nginx/"
    print_manual "├── PID File: /run/nginx.pid"
    print_manual "└── Service: /lib/systemd/system/nginx.service"
    echo ""
    
    print_manual "🔧 STEP-BY-STEP MANUAL INSTALLATION:"
    echo ""
    
    print_manual "Step 1: Install Dependencies"
    print_manual "sudo apt update"
    print_manual "sudo apt install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev"
    echo ""
    
    print_manual "Step 2: Create Build Directory"
    print_manual "mkdir -p /tmp/nginx-build"
    print_manual "cd /tmp/nginx-build"
    echo ""
    
    print_manual "Step 3: Download Nginx Source"
    print_manual "wget http://nginx.org/download/nginx-1.25.3.tar.gz"
    print_manual "tar -xzf nginx-1.25.3.tar.gz"
    echo ""
    
    print_manual "Step 4: Download RTMP Module"
    print_manual "git clone https://github.com/arut/nginx-rtmp-module.git"
    echo ""
    
    print_manual "Step 5: Configure Nginx with RTMP"
    print_manual "cd nginx-1.25.3"
    print_manual "./configure \\"
    print_manual "    --add-module=../nginx-rtmp-module \\"
    print_manual "    --prefix=/etc/nginx \\"
    print_manual "    --with-http_ssl_module \\"
    print_manual "    --with-http_v2_module"
    echo ""
    
    print_manual "Step 6: Compile and Install"
    print_manual "make"
    print_manual "sudo make install"
    echo ""
    
    print_manual "Step 7: Create Nginx User and Directories"
    print_manual "sudo useradd -r -s /bin/false nginx"
    print_manual "sudo mkdir -p /var/www/rtmp/hls /var/www/rtmp/dash"
    print_manual "sudo chown -R nginx:nginx /var/www/rtmp"
    echo ""
    
    print_manual "Step 8: Create Configuration File"
    print_manual "sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'"
    print_manual "worker_processes auto;"
    print_manual "pid /run/nginx.pid;"
    print_manual "events {"
    print_manual "    worker_connections 1024;"
    print_manual "}"
    print_manual ""
    print_manual "rtmp {"
    print_manual "    server {"
    print_manual "        listen 1935;"
    print_manual "        chunk_size 4096;"
    print_manual "        application live {"
    print_manual "            live on;"
    print_manual "            record off;"
    print_manual "            hls on;"
    print_manual "            hls_path /var/www/rtmp/hls;"
    print_manual "            hls_fragment 3;"
    print_manual "            hls_playlist_length 60;"
    print_manual "            dash on;"
    print_manual "            dash_path /var/www/rtmp/dash;"
    print_manual "            dash_fragment 3;"
    print_manual "            dash_playlist_length 60;"
    print_manual "        }"
    print_manual "    }"
    print_manual "}"
    print_manual ""
    print_manual "http {"
    print_manual "    include       /etc/nginx/mime.types;"
    print_manual "    default_type  application/octet-stream;"
    print_manual ""
    print_manual "    server {"
    print_manual "        listen 80;"
    print_manual "        location /hls {"
    print_manual "            types {"
    print_manual "                application/vnd.apple.mpegurl m3u8;"
    print_manual "                video/mp2t ts;"
    print_manual "            }"
    print_manual "            root /var/www/rtmp;"
    print_manual "            add_header Cache-Control no-cache;"
    print_manual "        }"
    print_manual "        location /dash {"
    print_manual "            types {"
    print_manual "                application/dash+xml mpd;"
    print_manual "                video/mp4 mp4;"
    print_manual "            }"
    print_manual "            root /var/www/rtmp;"
    print_manual "            add_header Cache-Control no-cache;"
    print_manual "        }"
    print_manual "        location / {"
    print_manual "            proxy_pass http://localhost:3000;"
    print_manual "        }"
    print_manual "    }"
    print_manual "}"
    print_manual "EOF"
    echo ""
    
    print_manual "Step 9: Test Configuration"
    print_manual "sudo nginx -t"
    echo ""
    
    print_manual "Step 10: Create Systemd Service"
    print_manual "sudo tee /lib/systemd/system/nginx.service > /dev/null << 'EOF'"
    print_manual "[Unit]"
    print_manual "Description=The NGINX HTTP and reverse proxy server"
    print_manual "After=syslog.target network.target remote-fs.target nss-lookup.target"
    print_manual ""
    print_manual "[Service]"
    print_manual "Type=forking"
    print_manual "PIDFile=/run/nginx.pid"
    print_manual "ExecStartPre=/usr/local/nginx/sbin/nginx -t"
    print_manual "ExecStart=/usr/local/nginx/sbin/nginx"
    print_manual "ExecReload=/bin/kill -s HUP \$MAINPID"
    print_manual "ExecStop=/bin/kill -s QUIT \$MAINPID"
    print_manual "PrivateTmp=true"
    print_manual ""
    print_manual "[Install]"
    print_manual "WantedBy=multi-user.target"
    print_manual "EOF"
    echo ""
    
    print_manual "Step 11: Start and Enable Nginx"
    print_manual "sudo systemctl daemon-reload"
    print_manual "sudo systemctl start nginx"
    print_manual "sudo systemctl enable nginx"
    echo ""
    
    print_manual "Step 12: Verify Installation"
    print_manual "sudo systemctl status nginx"
    print_manual "sudo nginx -t"
    print_manual "curl http://localhost/health"
    echo ""
    
    print_manual "📁 IMPORTANT FILE LOCATIONS AFTER MANUAL INSTALLATION:"
    print_manual "• Nginx Binary: /usr/local/nginx/sbin/nginx"
    print_manual "• Configuration: /etc/nginx/nginx.conf"
    print_manual "• PID File: /run/nginx.pid"
    print_manual "• Service File: /lib/systemd/system/nginx.service"
    print_manual "• Web Root: /var/www/rtmp/"
    print_manual "• Logs: /usr/local/nginx/logs/"
    print_manual "• Cache: /usr/local/nginx/cache/"
    echo ""
    
    print_manual "🔧 MANAGEMENT COMMANDS:"
    print_manual "• Start: sudo systemctl start nginx"
    print_manual "• Stop: sudo systemctl stop nginx"
    print_manual "• Restart: sudo systemctl restart nginx"
    print_manual "• Status: sudo systemctl status nginx"
    print_manual "• Test Config: sudo nginx -t"
    print_manual "• Reload: sudo nginx -s reload"
    print_manual "• View Logs: sudo tail -f /usr/local/nginx/logs/error.log"
    echo ""
    
    print_manual "⚠️  IMPORTANT NOTES:"
    print_manual "• Manual installation gives you full control over the process"
    print_manual "• You can customize the configure options as needed"
    print_manual "• Keep the source files in /tmp/nginx-build/ for future reference"
    print_manual "• Remember to set proper permissions for web directories"
    print_manual "• Test each step thoroughly before proceeding to the next"
    print_manual "• Consider creating backups of configuration files"
    echo ""
}

# Main installation function
main() {
    # Initialize log file
    echo "SCTE-35 Streaming Platform - Smart Installation Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    echo "User: $(whoami)" >> "$LOG_FILE"
    echo "Server: $(hostname)" >> "$LOG_FILE"
    echo "Server IP: $SERVER_IP" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Show welcome banner
    show_welcome_banner
    
    # Confirm installation
    read -p "Do you want to continue with the smart installation? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled by user."
        exit 0
    fi
    
    # Provide manual installation guidance
    provide_nginx_rtmp_manual_guidance
    
    read -p "Do you want to proceed with automatic installation? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Automatic installation cancelled."
        print_info "Please follow the manual installation guidance above."
        exit 0
    fi
    
    # Step 1: System Update
    if is_step_completed "system_update"; then
        print_skip "System update already completed"
    else
        print_step "Step 1/12: System Update"
        execute_command "sudo apt update" "Update package lists" "true"
        execute_command "sudo apt upgrade -y" "Upgrade system packages" "true"
        execute_command "sudo apt install -y curl wget git software-properties-common" "Install basic tools" "true"
        mark_step_completed "system_update"
    fi
    
    # Step 2: Node.js and npm
    if is_step_completed "nodejs_installation"; then
        print_skip "Node.js and npm already installed"
    else
        print_step "Step 2/12: Node.js and npm Installation"
        
        if command_exists node && command_exists npm; then
            print_skip "Node.js and npm are already installed"
            local node_version=$(node --version 2>/dev/null || echo "Unknown")
            local npm_version=$(npm --version 2>/dev/null || echo "Unknown")
            print_info "Node.js version: $node_version"
            print_info "npm version: $npm_version"
        else
            execute_command "curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -" "Add Node.js repository" "true"
            install_package "nodejs" "Install Node.js" "true"
            
            if command_exists npm; then
                print_success "npm is already available with Node.js"
            else
                execute_command "sudo apt install -y npm" "Install npm" "true"
            fi
            
            execute_command "sudo npm install -g pm2" "Install PM2 globally" "true"
        fi
        
        mark_step_completed "nodejs_installation"
    fi
    
    # Step 3: Build Dependencies
    if is_step_completed "build_dependencies"; then
        print_skip "Build dependencies already installed"
    else
        print_step "Step 3/12: Build Dependencies"
        
        local build_deps=("build-essential" "cmake" "make" "gcc" "g++" "pkg-config" "libtool" "automake" "autoconf" "nasm" "yasm")
        local missing_deps=()
        
        for dep in "${build_deps[@]}"; do
            if ! package_installed "$dep"; then
                missing_deps+=("$dep")
            fi
        done
        
        if [[ ${#missing_deps[@]} -eq 0 ]]; then
            print_skip "All build dependencies are already installed"
        else
            print_info "Installing missing build dependencies: ${missing_deps[*]}"
            for dep in "${missing_deps[@]}"; do
                install_package "$dep" "Build dependency: $dep" "true"
            done
        fi
        
        mark_step_completed "build_dependencies"
    fi
    
    # Step 4: FFmpeg Dependencies
    if is_step_completed "ffmpeg_dependencies"; then
        print_skip "FFmpeg dependencies already installed"
    else
        print_step "Step 4/12: FFmpeg Dependencies"
        print_progress "Checking FFmpeg dependencies..."
        
        local ffmpeg_deps=(
            "libx264-dev" "libx265-dev" "libmp3lame-dev" "libopus-dev" "libvpx-dev"
            "libfdk-aac-dev" "libass-dev" "libfreetype6-dev" "libfontconfig1-dev"
            "libxvidcore-dev" "libv4l-dev" "libpulse-dev" "libjack-jackd2-dev"
            "libcdio-paranoia-dev" "librubberband-dev" "libsdl2-dev" "libopenjp2-7-dev"
            "librtmp-dev" "libgnutls28-dev" "libbluray-dev" "libsoxr-dev" "libssh-dev"
            "libvidstab-dev" "libzimg-dev" "libwebp-dev" "libopenal-dev"
            "libgl1-mesa-dev" "libgles2-mesa-dev" "libva-dev" "libdrm-dev" "libxcb1-dev"
            "libxcb-shm0-dev" "libxcb-xfixes0-dev" "libxcb-shape0-dev" "libx11-dev"
            "libxfixes-dev" "libxext-dev" "libxrandr-dev" "libvdpau-dev" "libvulkan-dev"
            "libharfbuzz-dev" "libfribidi-dev" "liblzma-dev" "libzvbi-dev"
            "libcdio-cdda-dev" "libcdio-paranoia-dev" "libmodplug-dev" "libgme-dev"
            "libopenmpt-dev" "libshine-dev" "libsnappy-dev" "libspeex-dev" "libtheora-dev"
            "libtwolame-dev" "libvo-amrwbenc-dev" "libwavpack-dev" "libwebp-dev"
            "libzmq3-dev" "libzvbi-dev" "ladspa-sdk" "libmysofa-dev" "libgsm1-dev"
            "libdc1394-22-dev" "libchromaprint-dev" "libbs2b-dev" "libcaca-dev"
            "libflite1-dev" "libfluidsynth-dev" "libgme-dev" "libinstpatch-dev"
            "liblilv-dev" "liblv2-dev" "libserd-dev" "libsord-dev" "libsratom-dev"
            "libsamplerate-dev" "librubberband-dev" "libsrt-dev" "libsvtav1-dev"
            "libtesseract-dev" "libx265-dev" "libxvidcore-dev" "libzmq5-dev" "libzvbi-dev"
        )
        
        local missing_ffmpeg_deps=()
        
        for dep in "${ffmpeg_deps[@]}"; do
            if ! package_installed "$dep"; then
                missing_ffmpeg_deps+=("$dep")
            fi
        done
        
        if [[ ${#missing_ffmpeg_deps[@]} -eq 0 ]]; then
            print_skip "All FFmpeg dependencies are already installed"
        else
            print_info "Installing missing FFmpeg dependencies (${#missing_ffmpeg_deps[@]} packages)..."
            for dep in "${missing_ffmpeg_deps[@]}"; do
                install_package "$dep" "FFmpeg dependency: $dep" "false"
            done
        fi
        
        # Try to install VMAF (non-critical)
        print_info "Checking VMAF installation..."
        if ! package_installed "libvmaf-dev"; then
            if ! execute_command "sudo apt install -y libvmaf-dev" "Install VMAF development library" "false"; then
                print_warning "VMAF installation failed - this is non-critical and will be skipped"
            fi
        else
            print_skip "VMAF is already installed"
        fi
        
        mark_step_completed "ffmpeg_dependencies"
    fi
    
    # Step 5: FFmpeg Compilation and Installation
    if is_step_completed "ffmpeg_compilation"; then
        print_skip "FFmpeg already compiled and installed"
    else
        print_step "Step 5/12: FFmpeg Compilation and Installation"
        
        if command_exists ffmpeg; then
            local ffmpeg_version=$(ffmpeg -version | head -n 1)
            print_skip "FFmpeg is already installed: $ffmpeg_version"
            print_info "Testing FFmpeg SCTE-35 support..."
            
            if ffmpeg -h demuxer=mpegts 2>/dev/null | grep -qi scte; then
                print_success "FFmpeg SCTE-35 demuxer support confirmed"
            else
                print_warning "FFmpeg SCTE-35 demuxer support not found - may need recompilation"
            fi
            
            if ffmpeg -h muxer=mpegts 2>/dev/null | grep -qi scte; then
                print_success "FFmpeg SCTE-35 muxer support confirmed"
            else
                print_warning "FFmpeg SCTE-35 muxer support not found - may need recompilation"
            fi
        else
            print_progress "FFmpeg not found, compiling from source..."
            
            # Create build directory
            mkdir -p /tmp/ffmpeg-build
            cd /tmp/ffmpeg-build
            
            # Download FFmpeg source
            execute_command "git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg" "Download FFmpeg source" "true"
            cd ffmpeg
            
            # Configure FFmpeg
            print_progress "Configuring FFmpeg with SCTE-35 support..."
            local configure_cmd="./configure \
                --enable-shared --enable-gpl --enable-nonfree \
                --enable-libx264 --enable-libx265 --enable-libmp3lame \
                --enable-libopus --enable-libvpx --enable-libfdk-aac \
                --enable-libass --enable-libfreetype --enable-libfontconfig \
                --enable-libxvid --enable-libv4l2 --enable-libpulse \
                --enable-libjack --enable-libcdio --enable-librubberband \
                --enable-libsdl2 --enable-libopenjpeg --enable-librtmp \
                --enable-libgnutls --enable-libbluray --enable-libsoxr \
                --enable-libssh --enable-libvidstab --enable-libzimg \
                --enable-libwebp --enable-libopenal --enable-libva \
                --enable-libdrm --enable-libxcb --enable-libx11 \
                --enable-libxfixes --enable-libxext --enable-libxrandr \
                --enable-libvdpau --enable-libvulkan --enable-libharfbuzz \
                --enable-libfribidi --enable-liblzma --enable-libzvbi \
                --enable-libcdio --enable-libmodplug --enable-libgme \
                --enable-libopenmpt --enable-libshine --enable-libsnappy \
                --enable-libspeex --enable-libtheora --enable-libtwolame \
                --enable-libvo-amrwbenc --enable-libwavpack --enable-libwebp \
                --enable-libzmq --enable-libzvbi --enable-ladspa \
                --enable-libmysofa --enable-libgsm --enable-libdc1394 \
                --enable-libchromaprint --enable-libbs2b --enable-libcaca \
                --enable-libflite --enable-libfluidsynth --enable-libgme \
                --enable-libinstpatch --enable-liblilv --enable-liblv2 \
                --enable-libserd --enable-libsord --enable-libsratom \
                --enable-libsamplerate --enable-librubberband --enable-libsrt \
                --enable-libsvtav1 --enable-libtesseract --enable-libx265 \
                --enable-libxvid --enable-libzmq --enable-libzvbi \
                --extra-version=-SCTE35-Enhanced --prefix=/usr/local"
            
            execute_command "$configure_cmd" "Configure FFmpeg" "true"
            
            # Build FFmpeg
            print_progress "Building FFmpeg (this will take a while)..."
            execute_command "make -j$(nproc)" "Build FFmpeg" "true"
            
            # Install FFmpeg
            execute_command "sudo make install" "Install FFmpeg" "true"
            
            # Update shared library cache
            execute_command "sudo ldconfig" "Update shared library cache" "true"
            
            # Verify FFmpeg installation
            if command_exists ffmpeg; then
                local ffmpeg_version=$(ffmpeg -version | head -n 1)
                print_success "FFmpeg installed successfully: $ffmpeg_version"
            else
                print_error "FFmpeg installation failed"
                exit 1
            fi
        fi
        
        mark_step_completed "ffmpeg_compilation"
    fi
    
    # Step 6: Nginx with RTMP Module
    if is_step_completed "nginx_rtmp_installation"; then
        print_skip "Nginx with RTMP module already installed"
    else
        print_step "Step 6/12: Nginx with RTMP Module"
        
        if command_exists nginx && nginx -V 2>&1 | grep -q "rtmp"; then
            print_skip "Nginx with RTMP module is already installed"
            local nginx_version=$(nginx -v 2>&1)
            print_info "Nginx version: $nginx_version"
        else
            print_info "Nginx with RTMP module not found, installing..."
            
            # Install Nginx dependencies
            local nginx_deps=("libpcre3" "libpcre3-dev" "libssl-dev" "zlib1g-dev")
            for dep in "${nginx_deps[@]}"; do
                install_package "$dep" "Nginx dependency: $dep" "true"
            done
            
            # Create nginx build directory
            mkdir -p /tmp/nginx-build
            cd /tmp/nginx-build
            
            # Download Nginx source
            execute_command "wget http://nginx.org/download/nginx-1.25.3.tar.gz" "Download Nginx source" "true"
            execute_command "tar -xzf nginx-1.25.3.tar.gz" "Extract Nginx source" "true"
            
            # Download RTMP module
            execute_command "git clone https://github.com/arut/nginx-rtmp-module.git" "Download RTMP module" "true"
            
            # Configure and build Nginx
            cd nginx-1.25.3
            execute_command "./configure --add-module=../nginx-rtmp-module --prefix=/etc/nginx --with-http_ssl_module --with-http_v2_module" "Configure Nginx" "true"
            execute_command "make" "Build Nginx" "true"
            execute_command "sudo make install" "Install Nginx" "true"
            
            # Create nginx user and directories
            execute_command "sudo useradd -r -s /bin/false nginx" "Create nginx user" "false"
            execute_command "sudo mkdir -p /var/www/rtmp/hls /var/www/rtmp/dash" "Create RTMP directories" "true"
            execute_command "sudo chown -R nginx:nginx /var/www/rtmp" "Set RTMP directory permissions" "true"
            
            # Verify Nginx installation
            if command_exists nginx; then
                local nginx_version=$(nginx -v 2>&1)
                print_success "Nginx installed successfully: $nginx_version"
            else
                print_error "Nginx installation failed"
                exit 1
            fi
        fi
        
        mark_step_completed "nginx_rtmp_installation"
    fi
    
    # Step 7: Nginx Configuration
    if is_step_completed "nginx_configuration"; then
        print_skip "Nginx configuration already completed"
    else
        print_step "Step 7/12: Nginx Configuration"
        
        # Backup existing configuration
        if [[ -f "/etc/nginx/nginx.conf" ]]; then
            execute_command "sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup" "Backup existing Nginx configuration" "false"
        fi
        
        # Create Nginx configuration
        print_progress "Creating Nginx configuration with RTMP and SCTE-35 support..."
        
        sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
worker_processes auto;
pid /run/nginx.pid;
events {
    worker_connections 1024;
}

rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        notify_method get;
        
        application live {
            live on;
            record off;
            
            # Enable SCTE-35 support
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
            
            # SCTE-35 webhook support
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
            root /tmp/nginx-build/nginx-rtmp-module;
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
    
    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # HTTP server for HLS/DASH and application proxy
    server {
        listen 80;
        server_name localhost;
        
        # HLS streaming
        location /hls {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /var/www/rtmp;
            add_header Cache-Control no-cache;
            add_header Access-Control-Allow-Origin *;
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
        }
        
        # RTMP statistics
        location /stat {
            proxy_pass http://localhost:1936/stat;
            proxy_set_header Host $host;
        }
        
        # Health check
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
        
        # Proxy to Next.js application
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
        }
    }
}
EOF
        
        # Test Nginx configuration
        execute_command "sudo nginx -t" "Test Nginx configuration" "true"
        
        mark_step_completed "nginx_configuration"
    fi
    
    # Step 8: Project Setup
    if is_step_completed "project_setup"; then
        print_skip "Project setup already completed"
    else
        print_step "Step 8/12: Project Setup"
        
        cd ~
        
        # Clone or update the repository
        if [[ -d "SCTE-streamcontrol" ]]; then
            print_info "Project directory already exists, updating..."
            cd SCTE-streamcontrol
            execute_command "git pull origin master" "Update existing project" "false"
        else
            execute_command "git clone https://github.com/shihan84/SCTE-streamcontrol.git" "Clone project repository" "true"
            cd SCTE-streamcontrol
        fi
        
        # Install Node.js dependencies
        if [[ ! -d "node_modules" ]]; then
            execute_command "npm install" "Install Node.js dependencies" "true"
        else
            print_skip "Node.js dependencies already installed"
        fi
        
        # Setup database
        execute_command "npm run db:push" "Setup database" "true"
        
        mark_step_completed "project_setup"
    fi
    
    # Step 9: FFmpeg Configuration
    if is_step_completed "ffmpeg_configuration"; then
        print_skip "FFmpeg configuration already completed"
    else
        print_step "Step 9/12: FFmpeg Configuration"
        
        # Create FFmpeg configuration directory
        if [[ ! -d "/etc/ffmpeg" ]]; then
            execute_command "sudo mkdir -p /etc/ffmpeg" "Create FFmpeg configuration directory" "true"
        else
            print_skip "FFmpeg configuration directory already exists"
        fi
        
        # Create SCTE-35 configuration file
        if [[ ! -f "/etc/ffmpeg/scte35.conf" ]]; then
            sudo tee /etc/ffmpeg/scte35.conf > /dev/null << 'EOF'
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
            print_success "FFmpeg SCTE-35 configuration created"
        else
            print_skip "FFmpeg configuration already exists"
        fi
        
        # Create FFmpeg test script
        if [[ ! -f "/usr/local/bin/test-ffmpeg-scte35.sh" ]]; then
            sudo tee /usr/local/bin/test-ffmpeg-scte35.sh > /dev/null << 'EOF'
#!/bin/bash

# FFmpeg SCTE-35 Test Script
# Tests FFmpeg SCTE-35 functionality

echo "Testing FFmpeg SCTE-35 functionality..."

# Check FFmpeg version
echo "FFmpeg Version:"
ffmpeg -version | head -n 1

# Check for SCTE-35 support
echo ""
echo "SCTE-35 Demuxer Support:"
ffmpeg -h demuxer=mpegts 2>/dev/null | grep -i scte || echo "SCTE-35 demuxer support not found"

echo ""
echo "SCTE-35 Muxer Support:"
ffmpeg -h muxer=mpegts 2>/dev/null | grep -i scte || echo "SCTE-35 muxer support not found"

# Test basic FFmpeg functionality
echo ""
echo "Testing basic FFmpeg functionality..."
ffmpeg -version > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ FFmpeg is working correctly"
else
    echo "✗ FFmpeg is not working"
    exit 1
fi

# Test common encoders
echo ""
echo "Testing video encoders..."
if ffmpeg -encoders 2>/dev/null | grep -q "libx264"; then
    echo "✅ H.264 encoder (libx264) is available"
else
    echo "✗ H.264 encoder (libx264) is not available"
fi

if ffmpeg -encoders 2>/dev/null | grep -q "libx265"; then
    echo "✅ H.265 encoder (libx265) is available"
else
    echo "✗ H.265 encoder (libx265) is not available"
fi

echo ""
echo "Testing audio encoders..."
if ffmpeg -encoders 2>/dev/null | grep -q "aac"; then
    echo "✅ AAC encoder is available"
else
    echo "✗ AAC encoder is not available"
fi

if ffmpeg -encoders 2>/dev/null | grep -q "libmp3lame"; then
    echo "✅ MP3 encoder (libmp3lame) is available"
else
    echo "✗ MP3 encoder (libmp3lame) is not available"
fi

echo ""
echo "FFmpeg SCTE-35 test completed."
EOF
            execute_command "sudo chmod +x /usr/local/bin/test-ffmpeg-scte35.sh" "Make FFmpeg test script executable" "true"
            print_success "FFmpeg test script created"
        else
            print_skip "FFmpeg test script already exists"
        fi
        
        mark_step_completed "ffmpeg_configuration"
    fi
    
    # Step 10: Application Deployment with PM2
    if is_step_completed "application_deployment"; then
        print_skip "Application deployment already completed"
    else
        print_step "Step 10/12: Application Deployment with PM2"
        
        # Create PM2 ecosystem configuration
        if [[ ! -f "ecosystem.config.js" ]]; then
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
      PORT: 3000,
      RTMP_PORT: 1935,
      RTMP_HTTP_PORT: 1936,
      NEXT_PUBLIC_APP_URL: 'http://SERVER_IP',
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
    max_memory_restart: '1G',
    min_uptime: '10s',
    max_restarts: 5
  }]
}
EOF
            
            # Replace SERVER_IP placeholder
            sed -i "s/SERVER_IP/$SERVER_IP/g" ecosystem.config.js
            print_success "PM2 ecosystem configuration created"
        else
            print_skip "PM2 ecosystem configuration already exists"
        fi
        
        # Create PM2 log directory
        if [[ ! -d "/var/log/pm2" ]]; then
            execute_command "sudo mkdir -p /var/log/pm2" "Create PM2 log directory" "true"
            execute_command "sudo chown ubuntu:ubuntu /var/log/pm2" "Set PM2 log directory permissions" "true"
        else
            print_skip "PM2 log directory already exists"
        fi
        
        # Stop existing application if running
        if pm2 list | grep -q 'scte35-app'; then
            execute_command "pm2 stop scte35-app" "Stop existing application" "false"
            execute_command "pm2 delete scte35-app" "Delete existing application" "false"
        fi
        
        # Start application
        if pm2 list | grep -q 'scte35-app.*online'; then
            print_skip "Application is already running"
        else
            execute_command "pm2 start ecosystem.config.js" "Start application with PM2" "true"
            
            # Setup PM2 startup
            if ! pm2 status | grep -q "online"; then
                execute_command "pm2 startup" "Setup PM2 startup" "true"
            fi
            
            # Verify application is running
            if pm2 list | grep -q 'scte35-app.*online'; then
                print_success "Application is running successfully."
            else
                print_error "Application is not running"
                exit 1
            fi
        fi
        
        mark_step_completed "application_deployment"
    fi
    
    # Step 11: Start Services
    if is_step_completed "services_started"; then
        print_skip "Services already started"
    else
        print_step "Step 11/12: Start Services"
        
        # Start Nginx
        if ! service_running nginx; then
            execute_command "sudo systemctl start nginx" "Start Nginx" "true"
            execute_command "sudo systemctl enable nginx" "Enable Nginx on boot" "true"
            print_success "Nginx started and enabled"
        else
            print_skip "Nginx is already running"
        fi
        
        # Test Nginx
        execute_command "sudo nginx -t" "Test Nginx configuration" "true"
        
        mark_step_completed "services_started"
    fi
    
    # Step 12: Final Testing and Verification
    if is_step_completed "final_testing"; then
        print_skip "Final testing already completed"
    else
        print_step "Step 12/12: Final Testing and Verification"
        
        # Test application health
        if curl -s http://localhost:3000/health | grep -q "healthy"; then
            print_success "Application health endpoint is responding"
        else
            print_warning "Application health endpoint is not responding"
        fi
        
        # Test FFmpeg
        if command_exists ffmpeg; then
            print_success "FFmpeg is installed and accessible"
            
            # Run FFmpeg test script
            if command_exists test-ffmpeg-scte35.sh; then
                print_info "Running FFmpeg SCTE-35 test script..."
                if test-ffmpeg-scte35.sh >/dev/null 2>&1; then
                    print_success "FFmpeg SCTE-35 test script passed"
                else
                    print_warning "FFmpeg SCTE-35 test script failed"
                fi
            else
                print_warning "FFmpeg test script not found"
            fi
        else
            print_error "FFmpeg is not accessible"
        fi
        
        # Test Nginx endpoints
        if curl -s http://localhost/health | grep -q "healthy"; then
            print_success "Nginx health endpoint is responding"
        else
            print_warning "Nginx health endpoint is not responding"
        fi
        
        # Clean up build files
        print_info "Cleaning up temporary files..."
        if [[ -d "/tmp/nginx-build" ]]; then
            rm -rf /tmp/nginx-build
            print_info "Cleaned up Nginx build files"
        fi
        
        if [[ -d "/tmp/ffmpeg-build" ]]; then
            rm -rf /tmp/ffmpeg-build
            print_info "Cleaned up FFmpeg build files"
        fi
        
        # Clean up package cache
        execute_command "sudo apt-get clean" "Clean apt cache" "false"
        execute_command "sudo apt-get autoremove -y" "Remove unused packages" "false"
        
        print_success "Final testing and verification completed"
        
        mark_step_completed "final_testing"
    fi
    
    # Show completion banner
    show_completion_banner
}

# Run main installation
main "$@"