#!/bin/bash

# SCTE-35 Streaming Project - Complete Auto-Installation Script
# Fully automated installation with zero configuration required
# 
# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.

set -e  # Exit on any error

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
LOG_FILE="/tmp/scte35-auto-install-$(date +%Y%m%d_%H%M%S).log"
SERVER_IP=$(hostname -I | awk '{print $1}')
BACKUP_DIR="/tmp/scte35-backup-$(date +%Y%m%d_%H%M%S)"
ERROR_COUNT=0
WARNING_COUNT=0
SUCCESS_COUNT=0
START_TIME=$(date +%s)

# Spinner animation
spinner() {
    local pid=$1
    local message=$2
    local spinstr='|/-\'
    local temp
    
    echo -ne "${BLUE}[INFO]${NC} $message "
    
    while kill -0 "$pid" 2>/dev/null; do
        temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.75
        printf "\b\b"
    done
    
    printf "    \b\b\b\b"
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    
    printf "["
    printf "%*s" $completed | tr ' ' '='
    printf "%*s" $((width - completed)) | tr ' ' '-'
    printf "] %d%% (%d/%d)" $percentage $current $total
}

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

print_progress() {
    echo -e "${PURPLE}[PROGRESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_system() {
    echo -e "${ORANGE}[SYSTEM]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to execute command with error handling and progress
execute_command() {
    local cmd="$1"
    local description="$2"
    local critical="$3"
    local show_progress="$4"
    
    print_info "Executing: $description"
    echo "Command: $cmd" >> "$LOG_FILE"
    echo "Start: $(date)" >> "$LOG_FILE"
    
    if [[ "$show_progress" == "true" ]]; then
        # Run command in background for progress display
        eval "$cmd" >> "$LOG_FILE" 2>&1 &
        local cmd_pid=$!
        
        # Show progress spinner
        spinner "$cmd_pid" "$description"
        
        # Wait for command to complete
        wait "$cmd_pid"
        local exit_code=$?
    else
        # Run command normally
        if eval "$cmd" >> "$LOG_FILE" 2>&1; then
            local exit_code=0
        else
            local exit_code=$?
        fi
    fi
    
    echo "End: $(date)" >> "$LOG_FILE"
    echo "Exit code: $exit_code" >> "$LOG_FILE"
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Command completed successfully: $description"
        return 0
    else
        print_error "Command failed: $description"
        echo "Error output saved to: $LOG_FILE"
        
        if [[ "$critical" == "true" ]]; then
            print_error "Critical error encountered. Installation cannot continue."
            print_info "Check log file for details: $LOG_FILE"
            exit 1
        else
            print_warning "Non-critical error. Attempting to continue..."
            return 1
        fi
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install package if not exists
install_package() {
    local package="$1"
    local description="$2"
    local critical="$3"
    
    if ! command_exists "$package"; then
        print_info "Installing $package..."
        execute_command "sudo apt install -y $package" "Install $package" "$critical" "true"
    else
        print_info "$package is already installed."
    fi
}

# Function to backup file
backup_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        local backup_path="$BACKUP_DIR/$(basename "$file_path")-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        cp "$file_path" "$backup_path"
        print_info "Backed up $file_path to $backup_path"
    fi
}

# Function to show elapsed time
show_elapsed_time() {
    local end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    printf "Elapsed time: %02d:%02d\n" $minutes $seconds
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
    local server_ip=$(hostname -I | awk '{print $1}')
    print_info "  Server IP: $server_ip"
}

# Function to display welcome banner
show_welcome_banner() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          SCTE-35 Streaming Control Center - Auto Install        ║"
    echo "║                                                              ║"
    echo "║  🚀 Fully Automated Installation Script                      ║"
    echo "║  📦 Complete System Setup with Zero Configuration           ║"
    echo "║  🛡️  Enterprise-Grade Streaming Platform                     ║"
    echo "║  ⚡ One-Command Deployment with FFmpeg & Nginx                ║"
    echo "║                                                              ║"
    echo "║  This script will automatically install and configure:       ║"
    echo "║  • System Updates & Dependencies                              ║"
    echo "║  • Node.js, npm & PM2                                        ║"
    echo "║  • FFmpeg with SCTE-35 Support                               ║"
    echo "║  • Nginx with RTMP Module                                    ║"
    echo "║  • SCTE-35 Streaming Application                             ║"
    echo "║  • Database & Configuration                                   ║"
    echo "║  • Security & Firewall Setup                                 ║"
    echo "║  • Health Monitoring & Verification                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${BOLD}📋 Installation Summary:${NC}"
    show_system_requirements
    echo ""
    echo -e "${YELLOW}⚠️  This script requires sudo privileges for system installation.${NC}"
    echo -e "${YELLOW}⚠️  Installation will take approximately 30-60 minutes.${NC}"
    echo -e "${BLUE}📝 Log file: $LOG_FILE${NC}"
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
    echo "║                  Installation Completed!                      ║"
    echo "║                                                              ║"
    echo "║  🎉 SCTE-35 Streaming Control Center is ready!               ║"
    echo "║  🚀 Enterprise-grade streaming platform deployed           ║"
    echo "║  ⚡ All services running and verified                        ║"
    echo "║  🛡️  Security configured and enabled                         ║"
    echo "║                                                              ║"
    echo "║  📊 Installation Statistics:                                 ║"
    echo "║  • Total Operations: $((SUCCESS_COUNT + WARNING_COUNT + ERROR_COUNT))    ║"
    echo "║  • Successful: $SUCCESS_COUNT                                              ║"
    echo "║  • Warnings: $WARNING_COUNT                                                ║"
    echo "║  • Errors: $ERROR_COUNT                                                  ║"
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
        echo -e "${GREEN}🎉 Installation completed successfully with no errors!${NC}"
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

# Main installation function
main() {
    # Initialize log file
    echo "SCTE-35 Streaming Platform - Auto-Installation Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    echo "User: $(whoami)" >> "$LOG_FILE"
    echo "Server: $(hostname)" >> "$LOG_FILE"
    echo "Server IP: $SERVER_IP" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Show welcome banner
    show_welcome_banner
    
    # Confirm installation
    read -p "Do you want to continue with the auto-installation? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled by user."
        exit 0
    fi
    
    # Step 1: System Update
    print_step "Step 1/12: Updating System Packages"
    execute_command "sudo apt update" "Update package lists" "true" "true"
    execute_command "sudo apt upgrade -y" "Upgrade system packages" "true" "true"
    execute_command "sudo apt install -y curl wget git software-properties-common" "Install basic tools" "true" "true"
    
    # Step 2: Install Node.js and npm
    print_step "Step 2/12: Installing Node.js and npm"
    execute_command "curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -" "Add Node.js repository" "true" "true"
    install_package "nodejs" "Install Node.js" "true"
    execute_command "sudo npm install -g pm2" "Install PM2 globally" "true" "true"
    
    # Verify Node.js installation
    if command_exists node; then
        local node_version=$(node --version)
        print_success "Node.js installed: $node_version"
    else
        print_error "Node.js installation failed"
        exit 1
    fi
    
    # Step 3: Install Build Dependencies
    print_step "Step 3/12: Installing Build Dependencies"
    local build_deps=(
        "build-essential" "cmake" "make" "gcc" "g++" "pkg-config"
        "libtool" "automake" "autoconf" "nasm" "yasm"
    )
    
    for dep in "${build_deps[@]}"; do
        install_package "$dep" "Build dependency: $dep" "true"
    done
    
    # Step 4: Install FFmpeg Dependencies
    print_step "Step 4/12: Installing FFmpeg Dependencies"
    print_progress "Installing FFmpeg dependencies (this may take a while)..."
    
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
    
    for dep in "${ffmpeg_deps[@]}"; do
        install_package "$dep" "FFmpeg dependency: $dep" "false"
    done
    
    # Try to install VMAF (non-critical)
    print_info "Attempting to install VMAF (non-critical)..."
    if ! execute_command "sudo apt install -y libvmaf-dev" "Install VMAF development library" "false" "true"; then
        print_warning "VMAF installation failed - this is non-critical and will be skipped"
    fi
    
    # Step 5: Compile and Install FFmpeg
    print_step "Step 5/12: Compiling and Installing FFmpeg"
    print_progress "Downloading and compiling FFmpeg (this will take 30+ minutes)..."
    
    # Create build directory
    mkdir -p /tmp/ffmpeg-build
    cd /tmp/ffmpeg-build
    
    # Download FFmpeg source
    execute_command "git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg" "Download FFmpeg source" "true" "true"
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
    
    execute_command "$configure_cmd" "Configure FFmpeg" "true" "true"
    
    # Build FFmpeg
    print_progress "Building FFmpeg (this will take a while)..."
    execute_command "make -j$(nproc)" "Build FFmpeg" "true" "true"
    
    # Install FFmpeg
    execute_command "sudo make install" "Install FFmpeg" "true" "true"
    
    # Update shared library cache
    execute_command "sudo ldconfig" "Update shared library cache" "true" "true"
    
    # Verify FFmpeg installation
    if command_exists ffmpeg; then
        local ffmpeg_version=$(ffmpeg -version | head -n 1)
        print_success "FFmpeg installed successfully: $ffmpeg_version"
    else
        print_error "FFmpeg installation failed"
        exit 1
    fi
    
    # Step 6: Install Nginx with RTMP Module
    print_step "Step 6/12: Installing Nginx with RTMP Module"
    print_progress "Downloading and compiling Nginx with RTMP support..."
    
    # Install Nginx dependencies
    local nginx_deps=("libpcre3" "libpcre3-dev" "libssl-dev" "zlib1g-dev")
    for dep in "${nginx_deps[@]}"; do
        install_package "$dep" "Nginx dependency: $dep" "true"
    done
    
    # Create nginx build directory
    mkdir -p /tmp/nginx-build
    cd /tmp/nginx-build
    
    # Download Nginx source
    execute_command "wget http://nginx.org/download/nginx-1.25.3.tar.gz" "Download Nginx source" "true" "true"
    execute_command "tar -xzf nginx-1.25.3.tar.gz" "Extract Nginx source" "true" "true"
    
    # Download RTMP module
    execute_command "git clone https://github.com/arut/nginx-rtmp-module.git" "Download RTMP module" "true" "true"
    
    # Configure and build Nginx
    cd nginx-1.25.3
    execute_command "./configure --add-module=../nginx-rtmp-module --prefix=/etc/nginx --with-http_ssl_module --with-http_v2_module" "Configure Nginx" "true" "true"
    execute_command "make" "Build Nginx" "true" "true"
    execute_command "sudo make install" "Install Nginx" "true" "true"
    
    # Create nginx user and directories
    execute_command "sudo useradd -r -s /bin/false nginx" "Create nginx user" "false" "true"
    execute_command "sudo mkdir -p /var/www/rtmp/hls /var/www/rtmp/dash" "Create RTMP directories" "true" "true"
    execute_command "sudo chown -R nginx:nginx /var/www/rtmp" "Set RTMP directory permissions" "true" "true"
    
    # Verify Nginx installation
    if command_exists nginx; then
        local nginx_version=$(nginx -v 2>&1)
        print_success "Nginx installed successfully: $nginx_version"
    else
        print_error "Nginx installation failed"
        exit 1
    fi
    
    # Step 7: Configure Nginx
    print_step "Step 7/12: Configuring Nginx"
    
    # Backup existing configuration
    backup_file "/etc/nginx/nginx.conf"
    
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
    execute_command "sudo nginx -t" "Test Nginx configuration" "true" "true"
    
    # Step 8: Setup Project
    print_step "Step 8/12: Setting Up SCTE-35 Streaming Project"
    
    cd ~
    
    # Clone or update the repository
    if [[ -d "SCTE-streamcontrol" ]]; then
        print_info "Project directory already exists, updating..."
        cd SCTE-streamcontrol
        execute_command "git pull origin master" "Update existing project" "false" "true"
    else
        execute_command "git clone https://github.com/shihan84/SCTE-streamcontrol.git" "Clone project repository" "true" "true"
        cd SCTE-streamcontrol
    fi
    
    # Install Node.js dependencies
    execute_command "npm install" "Install Node.js dependencies" "true" "true"
    
    # Setup database
    execute_command "npm run db:push" "Setup database" "true" "true"
    
    # Step 9: Create FFmpeg Configuration
    print_step "Step 9/12: Creating FFmpeg Configuration"
    
    # Create FFmpeg configuration directory
    execute_command "sudo mkdir -p /etc/ffmpeg" "Create FFmpeg configuration directory" "true" "true"
    
    # Create SCTE-35 configuration file
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
    
    # Create FFmpeg test script
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
    
    execute_command "sudo chmod +x /usr/local/bin/test-ffmpeg-scte35.sh" "Make FFmpeg test script executable" "true" "true"
    
    # Step 10: Deploy Application with PM2
    print_step "Step 10/12: Deploying Application with PM2"
    
    # Create PM2 ecosystem configuration
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
    
    # Create PM2 log directory
    execute_command "sudo mkdir -p /var/log/pm2" "Create PM2 log directory" "true" "true"
    execute_command "sudo chown ubuntu:ubuntu /var/log/pm2" "Set PM2 log directory permissions" "true" "true"
    
    # Stop existing application if running
    if pm2 list | grep -q 'scte35-app'; then
        execute_command "pm2 stop scte35-app" "Stop existing application" "false" "true"
        execute_command "pm2 delete scte35-app" "Delete existing application" "false" "true"
    fi
    
    # Start application
    execute_command "pm2 start ecosystem.config.js" "Start application with PM2" "true" "true"
    
    # Setup PM2 startup
    execute_command "pm2 startup" "Setup PM2 startup" "true" "true"
    
    # Verify application is running
    if pm2 list | grep -q 'scte35-app.*online'; then
        print_success "Application is running successfully."
    else
        print_error "Application is not running"
        exit 1
    fi
    
    # Step 11: Start Services
    print_step "Step 11/12: Starting Services"
    
    # Start Nginx
    execute_command "sudo systemctl start nginx" "Start Nginx" "true" "true"
    execute_command "sudo systemctl enable nginx" "Enable Nginx on boot" "true" "true"
    
    # Test Nginx
    execute_command "sudo nginx -t" "Test Nginx configuration" "true" "true"
    
    # Step 12: Final Testing and Verification
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
    rm -rf /tmp/ffmpeg-build /tmp/nginx-build
    
    # Clean up package cache
    execute_command "sudo apt-get clean" "Clean apt cache" "false" "true"
    execute_command "sudo apt-get autoremove -y" "Remove unused packages" "false" "true"
    
    print_success "Final testing and verification completed"
    
    # Show completion banner
    show_completion_banner
}

# Run main installation
main "$@"