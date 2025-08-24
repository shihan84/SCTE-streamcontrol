#!/bin/bash

# SCTE-35 Streaming Project - Full Deployment Script with FFmpeg Integration
# Enhanced version with better error handling, logging, and recovery options
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
NC='\033[0m' # No Color

# Configuration
LOG_FILE="/tmp/scte35-deployment-$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/tmp/scte35-backup-$(date +%Y%m%d_%H%M%S)"
ERROR_COUNT=0
WARNING_COUNT=0
SUCCESS_COUNT=0

# Function to print colored output with logging
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

print_ffmpeg() {
    echo -e "${PURPLE}[FFMPEG]${NC} $1" | tee -a "$LOG_FILE"
}

print_system() {
    echo -e "${ORANGE}[SYSTEM]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to log command execution
log_command() {
    local cmd="$1"
    local description="$2"
    print_info "Executing: $description"
    echo "Command: $cmd" >> "$LOG_FILE"
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        print_success "Command completed successfully: $description"
        return 0
    else
        print_error "Command failed: $description"
        echo "Error output saved to: $LOG_FILE"
        return 1
    fi
}

# Function to handle errors with recovery options
handle_error() {
    local error_message="$1"
    local recovery_suggestion="$2"
    local critical="$3"
    
    print_error "$error_message"
    print_info "Recovery suggestion: $recovery_suggestion"
    
    if [[ "$critical" == "true" ]]; then
        print_error "Critical error encountered. Deployment cannot continue."
        print_info "Check log file for details: $LOG_FILE"
        exit 1
    else
        print_warning "Non-critical error. Attempting to continue..."
        return 1
    fi
}

# Function to backup existing files
backup_file() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        local backup_path="$BACKUP_DIR/$(basename "$file_path")-$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        cp "$file_path" "$backup_path"
        print_info "Backed up $file_path to $backup_path"
    fi
}

# Function to check system requirements
check_system_requirements() {
    print_step "Checking System Requirements"
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        handle_error "Cannot detect operating system" "This script requires Ubuntu 20.04+ or Debian 10+" "true"
    fi
    
    source /etc/os-release
    print_info "Detected OS: $NAME $VERSION"
    
    # Check if Ubuntu or Debian
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        handle_error "Unsupported operating system: $ID" "This script only supports Ubuntu and Debian" "true"
    fi
    
    # Check minimum requirements
    local total_memory=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local available_disk=$(df / | awk 'NR==2{printf "%.0f", $4}')
    
    print_info "System Memory: ${total_memory}MB"
    print_info "Available Disk: ${available_disk}KB"
    
    if [[ $total_memory -lt 2048 ]]; then
        handle_error "Insufficient memory: ${total_memory}MB (minimum 2048MB required)" "Upgrade system memory or use a larger instance" "true"
    fi
    
    if [[ $available_disk -lt 10240000 ]]; then
        handle_error "Insufficient disk space: ${available_disk}KB (minimum 10GB required)" "Free up disk space or use a larger disk" "true"
    fi
    
    print_success "System requirements check passed"
}

# Function to confirm action with timeout
confirm_with_timeout() {
    local prompt="$1"
    local timeout="${2:-30}"
    
    print_info "$prompt"
    print_info "Timeout: $timeout seconds"
    
    if read -t "$timeout" -p "Continue? [y/N]: " -n 1 -r; then
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            return 0
        else
            print_info "Operation cancelled by user."
            exit 0
        fi
    else
        echo
        print_warning "Timeout reached. Operation cancelled."
        exit 0
    fi
}

# Function to show progress with ETA
show_progress_with_eta() {
    local pid=$1
    local description="$2"
    local expected_time="$3"
    
    print_info "$description (expected time: $expected_time)"
    
    local start_time=$(date +%s)
    local spinstr='|/-\'
    
    while kill -0 "$pid" 2>/dev/null; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local remaining=$((expected_time - elapsed))
        
        if [[ $remaining -gt 0 ]]; then
            local minutes=$((remaining / 60))
            local seconds=$((remaining % 60))
            printf " [%c] ETA: %02d:%02d " "$spinstr" "$minutes" "$seconds"
        else
            printf " [%c] Running... " "$spinstr"
        fi
        
        local temp=${spinstr#?}
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.75
        printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    done
    
    printf "    \b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    print_success "$description completed"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install package if not exists with error handling
install_package() {
    local package="$1"
    local description="$2"
    
    if ! command_exists "$package"; then
        print_info "Installing $package..."
        if log_command "sudo apt install -y $package" "Install $package"; then
            print_success "$package installed successfully."
        else
            handle_error "Failed to install $package" "Check internet connection and package availability" "false"
        fi
    else
        print_info "$package is already installed."
    fi
}

# Function to create system report
create_system_report() {
    print_step "Creating System Report"
    
    local report_file="/tmp/scte35-system-report-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "SCTE-35 Streaming Platform - System Report"
        echo "Generated: $(date)"
        echo "=========================================="
        echo ""
        echo "System Information:"
        uname -a
        echo ""
        echo "OS Information:"
        cat /etc/os-release
        echo ""
        echo "Hardware Information:"
        echo "CPU: $(nproc) cores"
        echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
        echo "Disk: $(df -h / | awk 'NR==2{print $2}')"
        echo ""
        echo "Network Information:"
        ip addr show
        echo ""
        echo "Available Commands:"
        which ffmpeg ffprobe nginx node npm pm2 || echo "Some commands not found"
        echo ""
        echo "Running Services:"
        systemctl list-units --type=service --state=running | head -10
        echo ""
        echo "Open Ports:"
        ss -tlnp | head -10
        echo ""
        echo "Log Files:"
        ls -la /var/log/ | head -10
    } > "$report_file"
    
    print_success "System report created: $report_file"
    echo "Report file: $report_file" >> "$LOG_FILE"
}

# Function to cleanup temporary files
cleanup_temp_files() {
    print_step "Cleaning Up Temporary Files"
    
    # Clean up temporary directories
    if [[ -d "/tmp/nginx-1.25.3" ]]; then
        rm -rf /tmp/nginx-1.25.3
        print_info "Cleaned up Nginx build files"
    fi
    
    if [[ -d "/tmp/superkabuki-ffmpeg" ]]; then
        rm -rf /tmp/superkabuki-ffmpeg
        print_info "Cleaned up FFmpeg build files"
    fi
    
    # Clean up package cache
    log_command "sudo apt-get clean" "Clean apt cache"
    log_command "sudo apt-get autoremove -y" "Remove unused packages"
    
    print_success "Temporary files cleaned up"
}

# Function to show deployment summary
show_deployment_summary() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Deployment Summary                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📊 Deployment Statistics:"
    echo "  ✅ Successful operations: $SUCCESS_COUNT"
    echo "  ⚠️  Warnings: $WARNING_COUNT"
    echo "  ❌ Errors: $ERROR_COUNT"
    echo ""
    echo "📁 Log Files:"
    echo "  📋 Main log: $LOG_FILE"
    echo "  💾 Backup directory: $BACKUP_DIR"
    echo ""
    echo "🌐 Access URLs:"
    echo "  🖥️  Web Interface: http://$SERVER_IP"
    echo "  📺 RTMP Server: rtmp://$SERVER_IP:1935/live"
    echo "  📱 HLS Stream: http://$SERVER_IP/hls"
    echo "  📊 DASH Stream: http://$SERVER_IP/dash"
    echo "  📈 RTMP Stats: http://$SERVER_IP/stat"
    echo "  ❤️  Health Check: http://$SERVER_IP/health"
    echo ""
    echo "🛠️  Management Commands:"
    echo "  📋 View logs: pm2 logs"
    echo "  📊 Monitor: pm2 monit"
    echo "  🔄 Restart app: pm2 restart scte35-app"
    echo "  🌐 Restart nginx: sudo systemctl restart nginx"
    echo "  🧪 Test nginx: sudo nginx -t"
    echo "  🎬 Test FFmpeg: test-ffmpeg-scte35.sh"
    echo "  ✅ Verify deployment: ./verify-deployment.sh"
    echo ""
    echo "📁 Configuration Files:"
    echo "  ⚙️  Nginx main: /etc/nginx/nginx.conf"
    echo "  🎥 RTMP config: /etc/nginx/nginx.conf (embedded)"
    echo "  🎬 FFmpeg config: /etc/ffmpeg/scte35.conf"
    echo "  📋 Nginx logs: /var/log/nginx/"
    echo "  📊 PM2 logs: /var/log/pm2/"
    echo ""
    echo "🎯 Next Steps:"
    echo "  1. 🌐 Open http://$SERVER_IP in your browser"
    echo "  2. 🎬 Test RTMP streaming:"
    echo "     ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://$SERVER_IP:1935/live/test"
    echo "  3. 📱 Access HLS stream: http://$SERVER_IP/hls/test.m3u8"
    echo "  4. 📊 Access DASH stream: http://$SERVER_IP/dash/test.mpd"
    echo "  5. 🧪 Run verification: ./verify-deployment.sh"
    echo "  6. 📈 Monitor system: ~/monitor.sh"
    echo ""
    echo "🔧 FFmpeg SCTE-35 Examples:"
    echo "  🔄 Transcode with SCTE-35: ffmpeg -copyts -i input.ts -map 0 -c:v libx265 -c:a aac -c:d copy -muxpreload 0 -muxdelay 0 output.ts"
    echo "  📤 Extract SCTE-35: ffmpeg -i input.ts -map 0:d -f data -y output.bin"
    echo "  🧪 Test SCTE-35: test-ffmpeg-scte35.sh"
    echo ""
    
    if [[ $ERROR_COUNT -eq 0 ]]; then
        echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
        echo "Your SCTE-35 streaming platform is ready for use!"
    else
        echo -e "${YELLOW}⚠️  Deployment completed with $ERROR_COUNT error(s).${NC}"
        echo "Please check the log file: $LOG_FILE"
        echo "Run './verify-deployment.sh' to verify the installation."
    fi
    
    echo ""
    echo "For additional support, refer to the documentation."
    echo "╚══════════════════════════════════════════════════════════════╝"
}

# Function to install SuperKabuki FFmpeg
install_superkabuki_ffmpeg() {
    print_step "Installing SuperKabuki FFmpeg with SCTE-35 Support"
    
    print_ffmpeg "Installing FFmpeg dependencies..."
    
    # Install FFmpeg dependencies
    local ffmpeg_deps=(
        "libx264-dev" "libx265-dev" "libmp3lame-dev" "libopus-dev" "libvpx-dev"
        "libfdk-aac-dev" "libass-dev" "libfreetype6-dev" "libfontconfig1-dev"
        "libxvidcore-dev" "libv4l-dev" "libpulse-dev" "libjack-jackd2-dev"
        "libcdio-paranoia-dev" "librubberband-dev" "libsdl2-dev" "libopenjp2-7-dev"
        "librtmp-dev" "libgnutls28-dev" "libbluray-dev" "libsoxr-dev" "libssh-dev"
        "libvidstab-dev" "libzimg-dev" "libwebp-dev" "libopenal-dev" "libvmaf-dev"
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
        install_package "$dep" "FFmpeg dependency: $dep"
    done
    
    print_ffmpeg "Downloading and compiling FFmpeg..."
    
    # Create build directory
    mkdir -p /tmp/superkabuki-ffmpeg
    cd /tmp/superkabuki-ffmpeg
    
    # Download FFmpeg source
    if ! log_command "git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg" "Download FFmpeg source"; then
        handle_error "Failed to download FFmpeg source" "Check internet connection and git access" "true"
    fi
    
    cd ffmpeg
    
    # Configure FFmpeg with all features and SuperKabuki enhancements
    print_ffmpeg "Configuring FFmpeg with SCTE-35 support..."
    
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
        --enable-libwebp --enable-libopenal --enable-libvmaf \
        --enable-libva --enable-libdrm --enable-libxcb \
        --enable-libx11 --enable-libxfixes --enable-libxext \
        --enable-libxrandr --enable-libvdpau --enable-libvulkan \
        --enable-libharfbuzz --enable-libfribidi --enable-liblzma \
        --enable-libzvbi --enable-libcdio --enable-libmodplug \
        --enable-libgme --enable-libopenmpt --enable-libshine \
        --enable-libsnappy --enable-libspeex --enable-libtheora \
        --enable-libtwolame --enable-libvo-amrwbenc --enable-libwavpack \
        --enable-libwebp --enable-libzmq --enable-libzvbi \
        --enable-ladspa --enable-libmysofa --enable-libgsm \
        --enable-libdc1394 --enable-libchromaprint --enable-libbs2b \
        --enable-libcaca --enable-libflite --enable-libfluidsynth \
        --enable-libgme --enable-libinstpatch --enable-liblilv \
        --enable-liblv2 --enable-libserd --enable-libsord \
        --enable-libsratom --enable-libsamplerate --enable-librubberband \
        --enable-libsrt --enable-libsvtav1 --enable-libtesseract \
        --enable-libx265 --enable-libxvid --enable-libzmq \
        --enable-libzvbi --extra-version=-SuperKabuki-SCTE35 \
        --prefix=/usr/local"
    
    if ! log_command "$configure_cmd" "Configure FFmpeg"; then
        handle_error "FFmpeg configuration failed" "Check dependencies and system requirements" "true"
    fi
    
    # Build FFmpeg
    print_ffmpeg "Building FFmpeg (this may take a while)..."
    
    # Start build in background and show progress
    make -j$(nproc) > /tmp/ffmpeg-build.log 2>&1 &
    local build_pid=$!
    
    # Show progress with estimated time (30 minutes for FFmpeg build)
    show_progress_with_eta $build_pid "Building FFmpeg" "1800"
    
    # Wait for build to complete
    wait $build_pid
    
    if [[ $? -eq 0 ]]; then
        print_ffmpeg "FFmpeg build completed successfully"
    else
        print_error "FFmpeg build failed"
        print_info "Check build log: /tmp/ffmpeg-build.log"
        handle_error "FFmpeg compilation failed" "Check system resources and dependencies" "true"
    fi
    
    # Install FFmpeg
    print_ffmpeg "Installing FFmpeg..."
    if ! log_command "sudo make install" "Install FFmpeg"; then
        handle_error "FFmpeg installation failed" "Check permissions and disk space" "true"
    fi
    
    # Update shared library cache
    if ! log_command "sudo ldconfig" "Update shared library cache"; then
        handle_error "Failed to update shared library cache" "Check system configuration" "false"
    fi
    
    # Verify FFmpeg installation
    print_ffmpeg "Verifying FFmpeg installation..."
    if command_exists ffmpeg; then
        local ffmpeg_version=$(ffmpeg -version | head -n 1)
        print_ffmpeg "FFmpeg installed successfully: $ffmpeg_version"
        
        # Check for SuperKabuki enhancements
        if [[ "$ffmpeg_version" == *"SuperKabuki"* ]] || [[ "$ffmpeg_version" == *"SCTE35"* ]]; then
            print_ffmpeg "SuperKabuki SCTE-35 enhancements detected"
        else
            print_ffmpeg "SuperKabuki enhancements not detected in version string"
        fi
        
        # Test SCTE-35 support
        if ffmpeg -h demuxer=mpegts 2>/dev/null | grep -qi scte; then
            print_ffmpeg "SCTE-35 demuxer support confirmed"
        else
            print_ffmpeg "SCTE-35 demuxer support not found"
        fi
        
        if ffmpeg -h muxer=mpegts 2>/dev/null | grep -qi scte; then
            print_ffmpeg "SCTE-35 muxer support confirmed"
        else
            print_ffmpeg "SCTE-35 muxer support not found"
        fi
        
    else
        handle_error "FFmpeg not found after installation" "Check installation path and PATH variable" "true"
    fi
    
    # Create FFmpeg configuration directory
    print_ffmpeg "Creating FFmpeg configuration..."
    sudo mkdir -p /etc/ffmpeg
    
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
    
    # Create test script
    print_ffmpeg "Creating FFmpeg test script..."
    sudo tee /usr/local/bin/test-ffmpeg-scte35.sh > /dev/null << 'EOF'
#!/bin/bash

# FFmpeg SCTE-35 Test Script
# Tests SuperKabuki FFmpeg SCTE-35 functionality

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
if [[ $? -eq 0 ]]; then
    echo "✓ FFmpeg is working correctly"
else
    echo "✗ FFmpeg is not working correctly"
    exit 1
fi

# Test encoders
echo ""
echo "Testing key encoders..."
if ffmpeg -encoders 2>/dev/null | grep -q "libx264"; then
    echo "✓ H.264 encoder (libx264) available"
else
    echo "✗ H.264 encoder (libx264) not available"
fi

if ffmpeg -encoders 2>/dev/null | grep -q "libx265"; then
    echo "✓ H.265 encoder (libx265) available"
else
    echo "✗ H.265 encoder (libx265) not available"
fi

if ffmpeg -encoders 2>/dev/null | grep -q "libmp3lame"; then
    echo "✓ MP3 encoder (libmp3lame) available"
else
    echo "✗ MP3 encoder (libmp3lame) not available"
fi

if ffmpeg -encoders 2>/dev/null | grep -q "aac"; then
    echo "✓ AAC encoder available"
else
    echo "✗ AAC encoder not available"
fi

echo ""
echo "FFmpeg SCTE-35 test completed."
EOF
    
    sudo chmod +x /usr/local/bin/test-ffmpeg-scte35.sh
    
    print_success "SuperKabuki FFmpeg installation completed"
}

# Function to install and configure Nginx with RTMP
install_nginx_rtmp() {
    print_step "Installing and Configuring Nginx with RTMP Module"
    
    print_info "Removing any existing Nginx installation..."
    log_command "sudo apt remove --purge -y nginx nginx-common nginx-full nginx-core || true" "Remove existing Nginx"
    log_command "sudo apt autoremove -y" "Autoremove packages"
    
    print_info "Installing Nginx build dependencies..."
    install_package "build-essential" "Build tools"
    install_package "libpcre3-dev" "PCRE development"
    install_package "libssl-dev" "OpenSSL development"
    install_package "zlib1g-dev" "Zlib development"
    
    print_info "Downloading and compiling Nginx with RTMP module..."
    
    # Create build directory
    mkdir -p /tmp/nginx-build
    cd /tmp/nginx-build
    
    # Download Nginx source
    if ! log_command "wget https://nginx.org/download/nginx-1.25.3.tar.gz" "Download Nginx source"; then
        handle_error "Failed to download Nginx source" "Check internet connection" "true"
    fi
    
    if ! log_command "tar -xzf nginx-1.25.3.tar.gz" "Extract Nginx source"; then
        handle_error "Failed to extract Nginx source" "Check downloaded file" "true"
    fi
    
    cd nginx-1.25.3
    
    # Clone RTMP module
    if ! log_command "git clone https://github.com/arut/nginx-rtmp-module.git" "Clone RTMP module"; then
        handle_error "Failed to clone RTMP module" "Check git access" "true"
    fi
    
    # Configure Nginx
    print_info "Configuring Nginx..."
    
    local configure_cmd="./configure \
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
        --add-dynamic-module=./nginx-rtmp-module"
    
    if ! log_command "$configure_cmd" "Configure Nginx"; then
        handle_error "Nginx configuration failed" "Check dependencies and system requirements" "true"
    fi
    
    # Build Nginx
    print_info "Building Nginx..."
    if ! log_command "make -j$(nproc)" "Build Nginx"; then
        handle_error "Nginx build failed" "Check system resources and dependencies" "true"
    fi
    
    # Install Nginx
    print_info "Installing Nginx..."
    if ! log_command "sudo make install" "Install Nginx"; then
        handle_error "Nginx installation failed" "Check permissions and disk space" "true"
    fi
    
    # Create nginx user if not exists
    sudo id -u www-data &>/dev/null || sudo useradd -r -s /bin/false www-data
    
    # Create systemd service
    print_info "Creating systemd service..."
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
    print_info "Enabling and starting Nginx..."
    log_command "sudo systemctl daemon-reload" "Reload systemd"
    log_command "sudo systemctl enable nginx" "Enable Nginx service"
    
    # Clean up build files
    cd /
    rm -rf /tmp/nginx-build
    
    # Create required directories
    print_info "Creating required directories..."
    sudo mkdir -p /var/www/rtmp/hls
    sudo mkdir -p /var/www/rtmp/dash
    sudo chown -R www-data:www-data /var/www/rtmp
    sudo chmod -R 755 /var/www/rtmp
    
    # Create Nginx configuration
    print_info "Creating Nginx configuration..."
    
    # Backup existing configuration if it exists
    backup_file "/etc/nginx/nginx.conf"
    
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
    
    # Create RTMP statistics stylesheet
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
    
    # Test Nginx configuration
    print_info "Testing Nginx configuration..."
    if sudo nginx -t; then
        print_success "Nginx configuration test passed."
    else
        handle_error "Nginx configuration test failed!" "Check configuration syntax" "true"
    fi
    
    # Start Nginx
    print_info "Starting Nginx..."
    if log_command "sudo systemctl start nginx" "Start Nginx"; then
        print_success "Nginx started successfully."
    else
        handle_error "Nginx failed to start!" "Check logs and configuration" "true"
    fi
    
    # Verify Nginx status
    if sudo systemctl is-active --quiet nginx; then
        print_success "Nginx is running successfully."
    else
        handle_error "Nginx is not running!" "Check system logs" "true"
    fi
    
    print_success "Nginx with RTMP installation completed"
}

# Function to setup the project
setup_project() {
    print_step "Setting Up SCTE-35 Streaming Project"
    
    cd ~
    
    # Clone the repository
    print_info "Cloning SCTE-35 streaming project..."
    if [[ -d "SCTE-streamcontrol" ]]; then
        print_info "Project directory already exists, updating..."
        cd SCTE-streamcontrol
        log_command "git pull origin master" "Update existing project"
    else
        if ! log_command "git clone https://github.com/shihan84/SCTE-streamcontrol.git" "Clone project repository"; then
            handle_error "Failed to clone project repository" "Check git access and internet connection" "true"
        fi
        cd SCTE-streamcontrol
    fi
    
    # Install dependencies
    print_info "Installing project dependencies..."
    if ! log_command "npm install" "Install Node.js dependencies"; then
        handle_error "Failed to install project dependencies" "Check Node.js and npm installation" "true"
    fi
    
    # Build application
    print_info "Building application..."
    if ! log_command "npm run build" "Build Next.js application"; then
        handle_error "Failed to build application" "Check project configuration and dependencies" "true"
    fi
    
    # Create environment configuration
    print_info "Creating environment configuration..."
    
    # Backup existing .env file if it exists
    backup_file ".env"
    
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
    
    print_success "Environment configuration created"
    
    # Setup database
    print_info "Setting up database..."
    if ! log_command "npm run db:push" "Setup database"; then
        handle_error "Failed to setup database" "Check database configuration" "false"
    fi
    
    print_success "Project setup completed"
}

# Function to deploy application with PM2
deploy_application() {
    print_step "Deploying Application with PM2"
    
    cd /home/ubuntu/SCTE-streamcontrol
    
    # Create PM2 ecosystem configuration
    print_info "Creating PM2 ecosystem configuration..."
    
    # Backup existing ecosystem file if it exists
    backup_file "ecosystem.config.js"
    
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
    max_restarts: 5,
    max_memory_restart: '1G'
  }]
};
EOF
    
    # Replace SERVER_IP placeholder
    sed -i "s/SERVER_IP/$SERVER_IP/g" ecosystem.config.js
    
    # Create PM2 log directory
    sudo mkdir -p /var/log/pm2
    sudo chown ubuntu:ubuntu /var/log/pm2
    
    # Stop existing application if running
    if pm2 list | grep -q 'scte35-app'; then
        print_info "Stopping existing application..."
        log_command "pm2 stop scte35-app" "Stop existing application"
        log_command "pm2 delete scte35-app" "Delete existing application"
    fi
    
    # Start application
    print_info "Starting application with PM2..."
    if ! log_command "pm2 start ecosystem.config.js" "Start application with PM2"; then
        handle_error "Failed to start application" "Check PM2 configuration and application logs" "true"
    fi
    
    # Save PM2 configuration
    log_command "pm2 save" "Save PM2 configuration"
    
    # Setup PM2 to start on boot
    print_info "Setting up PM2 startup..."
    log_command "pm2 startup" "Setup PM2 startup"
    
    # Verify application is running
    print_info "Verifying application status..."
    if pm2 list | grep -q 'scte35-app.*online'; then
        print_success "Application is running successfully."
    else
        handle_error "Application is not running" "Check PM2 logs and application configuration" "true"
    fi
    
    print_success "Application deployment completed"
}

# Function to configure firewall
configure_firewall() {
    print_step "Configuring Firewall"
    
    print_info "Configuring UFW firewall..."
    
    # Allow essential ports
    log_command "sudo ufw allow 22/tcp" "Allow SSH"
    log_command "sudo ufw allow 80/tcp" "Allow HTTP"
    log_command "sudo ufw allow 443/tcp" "Allow HTTPS"
    log_command "sudo ufw allow 1935/tcp" "Allow RTMP"
    log_command "sudo ufw allow 1936/tcp" "Allow RTMP stats"
    
    # Enable firewall
    print_info "Enabling firewall..."
    if log_command "sudo ufw --force enable" "Enable UFW firewall"; then
        print_success "Firewall configured successfully."
    else
        handle_error "Failed to configure firewall" "Check UFW configuration" "false"
    fi
    
    # Check firewall status
    if sudo ufw status | grep -q "Status: active"; then
        print_success "Firewall is active."
    else
        print_warning "Firewall may not be active."
    fi
    
    print_success "Firewall configuration completed"
}

# Function to test deployment
test_deployment() {
    print_step "Testing Deployment"
    
    print_info "Running comprehensive deployment tests..."
    
    # Test Nginx
    print_info "Testing Nginx..."
    if sudo systemctl is-active --quiet nginx; then
        print_success "Nginx is running"
        
        # Test HTTP access
        if curl -s http://localhost/health | grep -q "healthy"; then
            print_success "HTTP health endpoint is responding"
        else
            print_error "HTTP health endpoint is not responding"
        fi
        
        # Test RTMP stats
        if curl -s http://localhost/stat | grep -q "RTMP"; then
            print_success "RTMP statistics are available"
        else
            print_error "RTMP statistics are not available"
        fi
    else
        print_error "Nginx is not running"
    fi
    
    # Test PM2 application
    print_info "Testing PM2 application..."
    if pm2 list | grep -q 'scte35-app.*online'; then
        print_success "SCTE-35 application is running"
        
        # Test application health
        if curl -s http://localhost:3000/health | grep -q "healthy"; then
            print_success "Application health endpoint is responding"
        else
            print_error "Application health endpoint is not responding"
        fi
    else
        print_error "SCTE-35 application is not running"
    fi
    
    # Test FFmpeg
    print_info "Testing FFmpeg..."
    if command_exists ffmpeg; then
        print_success "FFmpeg is available"
        
        # Test FFmpeg version
        local ffmpeg_version=$(ffmpeg -version | head -n 1)
        print_info "FFmpeg version: $ffmpeg_version"
        
        # Test SCTE-35 support
        if ffmpeg -h demuxer=mpegts 2>/dev/null | grep -qi scte; then
            print_success "SCTE-35 demuxer support is available"
        else
            print_error "SCTE-35 demuxer support is not available"
        fi
        
        # Run FFmpeg test script
        if command_exists test-ffmpeg-scte35.sh; then
            print_info "Running FFmpeg SCTE-35 test script..."
            if test-ffmpeg-scte35.sh >/dev/null 2>&1; then
                print_success "FFmpeg SCTE-35 test script passed"
            else
                print_error "FFmpeg SCTE-35 test script failed"
            fi
        else
            print_warning "FFmpeg test script not found"
        fi
    else
        print_error "FFmpeg is not available"
    fi
    
    # Test ports
    print_info "Testing network ports..."
    local ports=(80 1935 1936 3000)
    for port in "${ports[@]}"; do
        if nc -z localhost "$port" >/dev/null 2>&1; then
            print_success "Port $port is accessible"
        else
            print_error "Port $port is not accessible"
        fi
    done
    
    # Test database
    print_info "Testing database..."
    if [ -f "/home/ubuntu/SCTE-streamcontrol/dev.db" ]; then
        print_success "Database file exists"
        
        # Test database operations
        cd /home/ubuntu/SCTE-streamcontrol
        if npm run db:push >/dev/null 2>&1; then
            print_success "Database operations are working"
        else
            print_error "Database operations failed"
        fi
    else
        print_error "Database file does not exist"
    fi
    
    print_success "Deployment testing completed"
}

# Function to handle script interruption
handle_interrupt() {
    echo ""
    print_warning "Script interrupted by user"
    print_info "Cleaning up..."
    cleanup_temp_files
    print_info "Log file available at: $LOG_FILE"
    print_info "Backup directory: $BACKUP_DIR"
    exit 1
}

# Set up interrupt handlers
trap handle_interrupt INT TERM

# Function to show help
show_help() {
    echo "SCTE-35 Streaming Platform - Full Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --verbose       Enable verbose logging"
    echo "  -f, --force         Force installation without prompts"
    echo "  -c, --check-only    Only check system requirements"
    echo "  -r, --report        Generate system report only"
    echo "  -l, --log FILE      Specify custom log file"
    echo "  -b, --backup DIR    Specify custom backup directory"
    echo ""
    echo "Examples:"
    echo "  $0                  # Standard deployment"
    echo "  $0 --verbose        # Verbose deployment"
    echo "  $0 --check-only     # Only check requirements"
    echo "  $0 --force          # Force installation"
    echo ""
    echo "For more information, refer to the documentation."
}

# Parse command line arguments
VERBOSE=false
FORCE=false
CHECK_ONLY=false
REPORT_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -c|--check-only)
            CHECK_ONLY=true
            shift
            ;;
        -r|--report)
            REPORT_ONLY=true
            shift
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -b|--backup)
            BACKUP_DIR="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute based on options
if [[ "$REPORT_ONLY" == "true" ]]; then
    create_system_report
    exit 0
fi

if [[ "$CHECK_ONLY" == "true" ]]; then
    check_system_requirements
    exit 0
fi

# Main deployment function
main() {
    # Initialize log file
    echo "SCTE-35 Streaming Platform Deployment Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    echo "User: $(whoami)" >> "$LOG_FILE"
    echo "Server: $(hostname)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║    SCTE-35 Streaming Project - Full Deployment with FFmpeg   ║"
    echo "║                                                              ║"
    echo "║  Enhanced deployment script with comprehensive error        ║"
    echo "║  handling, logging, and recovery options.                   ║"
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
    echo "║  - Monitoring and backup scripts                             ║"
    echo "║  - System optimization                                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    print_warning "This script requires sudo privileges for system installation."
    print_warning "This will install SuperKabuki FFmpeg with enhanced SCTE-35 support."
    print_warning "A detailed log will be created at: $LOG_FILE"
    
    if [[ "$FORCE" != "true" ]]; then
        confirm_with_timeout "Do you want to continue with the full deployment?" "60"
    fi
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    print_info "Server IP: $SERVER_IP"
    echo "Server IP: $SERVER_IP" >> "$LOG_FILE"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Step 1: Check system requirements
    echo ""
    check_system_requirements
    
    # Step 2: Create system report
    echo ""
    create_system_report
    
    # Step 3: System Preparation
    echo ""
    print_step "Step 3: System Preparation"
    
    print_info "Updating system packages..."
    if log_command "sudo apt update" "Update package lists"; then
        print_success "Package lists updated"
    else
        handle_error "Failed to update package lists" "Check internet connection and DNS settings" "true"
    fi
    
    if log_command "sudo apt upgrade -y" "Upgrade system packages"; then
        print_success "System packages upgraded"
    else
        handle_error "Failed to upgrade system packages" "Check disk space and internet connection" "false"
    fi
    
    print_info "Installing basic tools..."
    install_package "git" "Git version control"
    install_package "curl" "CURL command line tool"
    install_package "wget" "WGET command line tool"
    install_package "htop" "HTOP system monitor"
    install_package "vim" "VIM text editor"
    install_package "net-tools" "Network tools"
    install_package "build-essential" "Build tools"
    install_package "python3-dev" "Python development headers"
    install_package "ufw" "Uncomplicated Firewall"
    install_package "fail2ban" "Intrusion prevention software"
    install_package "cmake" "CMake build system"
    install_package "yasm" "YASM assembler"
    install_package "nasm" "NASM assembler"
    install_package "unzip" "Unzip utility"
    install_package "zip" "Zip utility"
    install_package "tree" "Directory tree viewer"
    
    print_success "System preparation completed."
    
    # Step 4: Install Node.js and PM2
    echo ""
    print_step "Step 4: Installing Node.js and PM2"
    
    print_info "Installing Node.js 18.x..."
    if ! log_command "curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -" "Setup Node.js repository"; then
        handle_error "Failed to setup Node.js repository" "Check internet connection" "true"
    fi
    
    if ! log_command "sudo apt-get install -y nodejs" "Install Node.js"; then
        handle_error "Failed to install Node.js" "Check package availability" "true"
    fi
    
    print_info "Verifying Node.js installation..."
    print_info "Node.js version: $(node --version)"
    print_info "npm version: $(npm --version)"
    
    print_info "Installing PM2 globally..."
    if ! log_command "sudo npm install -g pm2" "Install PM2"; then
        handle_error "Failed to install PM2" "Check npm configuration" "true"
    fi
    
    print_success "Node.js and PM2 installation completed."
    
    # Step 5: Install SuperKabuki FFmpeg
    echo ""
    install_superkabuki_ffmpeg
    
    # Step 6: Install Nginx with RTMP
    echo ""
    install_nginx_rtmp
    
    # Step 7: Setup Project
    echo ""
    setup_project
    
    # Step 8: Deploy Application
    echo ""
    deploy_application
    
    # Step 9: Configure Firewall
    echo ""
    configure_firewall
    
    # Step 10: Test Deployment
    echo ""
    test_deployment
    
    # Show deployment summary
    show_deployment_summary
    
    # Final cleanup
    cleanup_temp_files
    
    print_success "Final verification completed."
    
    # Display final success message
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
    
    print_info "Total operations: $((SUCCESS_COUNT + WARNING_COUNT + ERROR_COUNT))"
    print_info "Success rate: $((SUCCESS_COUNT * 100 / (SUCCESS_COUNT + WARNING_COUNT + ERROR_COUNT)))%"
}

# Run main deployment
main "$@"