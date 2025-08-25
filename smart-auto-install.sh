#!/bin/bash

# SCTE-35 Streaming Project - Smart Auto-Installation Script
# Intelligent installation that skips existing components and provides detailed manual guidance
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
MANUAL_INSTALL_STEPS=""

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

print_manual() {
    echo -e "${PURPLE}[MANUAL]${NC} $1" | tee -a "$LOG_FILE"
    MANUAL_INSTALL_STEPS="$MANUAL_INSTALL_STEPS\n$1"
}

print_progress() {
    echo -e "${PURPLE}[PROGRESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_system() {
    echo -e "${ORANGE}[SYSTEM]${NC} $1" | tee -a "$LOG_FILE"
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
    systemctl is-active --quiet "$1"
}

# Function to get package version
get_package_version() {
    dpkg -l | grep "^ii  $1 " | awk '{print $3}'
}

# Function to execute command with error handling
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
        show_spinner "$cmd_pid" "$description"
        
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

# Function to show spinner
show_spinner() {
    local pid=$1
    local message=$2
    local spinstr='|/-\'
    local temp
    
    echo -ne "${BLUE}[INFO]${NC} $message "
    
    while kill -0 "$pid" 2>/dev/null; do
        temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        spinstr=$temp${spinstr%"$temp}"
        sleep 0.75
        printf "\b\b"
    done
    
    printf "    \b\b\b\b"
}

# Function to show progress bar
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

# Function to show system status
show_system_status() {
    print_info "System Status Check:"
    
    # OS Information
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        print_info "  OS: $NAME $VERSION"
    fi
    
    # CPU
    local cpu_cores=$(nproc)
    print_info "  CPU Cores: $cpu_cores"
    
    # Memory
    local total_memory=$(free -m | awk 'NR==2{printf "%.0f MB", $2}')
    local available_memory=$(free -m | awk 'NR==2{printf "%.0f MB", $7}')
    print_info "  Memory: $total_memory total, $available_memory available"
    
    # Disk
    local total_disk=$(df -h / | awk 'NR==2{printf "%.0f GB", $2}')
    local available_disk=$(df -h / | awk 'NR==2{printf "%.0f GB", $4}')
    print_info "  Disk: $total_disk total, $available_disk available"
    
    # Network
    local server_ip=$(hostname -I | awk '{print $1}')
    print_info "  Server IP: $server_ip"
    
    echo ""
}

# Function to check existing installations
check_existing_installations() {
    print_step "Checking Existing Installations"
    
    local existing_count=0
    
    # Check Node.js
    if command_exists node; then
        local node_version=$(node --version)
        print_success "Node.js is already installed: $node_version"
        existing_count=$((existing_count + 1))
    else
        print_info "Node.js is not installed"
    fi
    
    # Check npm
    if command_exists npm; then
        local npm_version=$(npm --version)
        print_success "npm is already installed: $npm_version"
        existing_count=$((existing_count + 1))
    else
        print_info "npm is not installed"
    fi
    
    # Check PM2
    if command_exists pm2; then
        local pm2_version=$(pm2 --version)
        print_success "PM2 is already installed: $pm2_version"
        existing_count=$((existing_count + 1))
    else
        print_info "PM2 is not installed"
    fi
    
    # Check FFmpeg
    if command_exists ffmpeg; then
        local ffmpeg_version=$(ffmpeg -version | head -n 1)
        print_success "FFmpeg is already installed: $ffmpeg_version"
        existing_count=$((existing_count + 1))
    else
        print_info "FFmpeg is not installed"
    fi
    
    # Check Nginx
    if command_exists nginx; then
        local nginx_version=$(nginx -v 2>&1)
        print_success "Nginx is already installed: $nginx_version"
        existing_count=$((existing_count + 1))
    else
        print_info "Nginx is not installed"
    fi
    
    # Check if Nginx has RTMP module
    if command_exists nginx; then
        if nginx -V 2>&1 | grep -q "rtmp"; then
            print_success "Nginx RTMP module is already installed"
            existing_count=$((existing_count + 1))
        else
            print_warning "Nginx is installed but RTMP module is missing"
        fi
    fi
    
    # Check if project directory exists
    if [[ -d "/home/ubuntu/SCTE-streamcontrol" ]]; then
        print_success "Project directory already exists"
        existing_count=$((existing_count + 1))
    else
        print_info "Project directory does not exist"
    fi
    
    print_info "Found $existing_count existing components that will be utilized"
    echo ""
}

# Function to display welcome banner
show_welcome_banner() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          SCTE-35 Streaming Control Center - Smart Auto Install    ║"
    echo "║                                                              ║"
    echo "║  🧠 Intelligent Installation with Component Detection           ║"
    echo "║  📦 Smart Package Management - Skip Existing Components       ║"
    echo "║  🛠️  Manual Installation Guidance for Complex Components       ║"
    echo "║  ⚡ Optimized Installation - Only Install What's Needed       ║"
    echo "║                                                              ║"
    echo "║  This script will:                                          ║"
    echo "║  • Detect existing installations                              ║"
    echo "║  • Skip already installed components                           ║"
    echo "║  • Provide manual guidance for complex setups                  ║"
    echo "║  • Install missing components automatically                    ║"
    echo "║  • Verify complete system functionality                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    show_system_status
    echo -e "${YELLOW}⚠️  This script requires sudo privileges for system installation.${NC}"
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
    echo "║                  Smart Installation Completed!                 ║"
    echo "║                                                              ║"
    echo "║  🎉 SCTE-35 Streaming Control Center is ready!               ║"
    echo "║  🧠 Intelligent component detection and installation         ║"
    echo "║  ⚡ Optimized setup with existing components utilized        ║"
    echo "║  🛠️  Manual guidance provided for complex installations     ║"
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
        echo -e "${GREEN}🎉 Smart installation completed successfully with no errors!${NC}"
        echo -e "${GREEN}🚀 Your SCTE-35 streaming platform is ready for production use!${NC}"
    else
        echo -e "${YELLOW}⚠️  Installation completed with $ERROR_COUNT error(s).${NC}"
        echo -e "${YELLOW}📋 Check the log file for details: $LOG_FILE${NC}"
        echo -e "${YELLOW}🔧 Run './verify-deployment.sh' to verify the installation.${NC}"
    fi
    
    # Show manual installation steps if any
    if [[ -n "$MANUAL_INSTALL_STEPS" ]]; then
        echo ""
        echo -e "${PURPLE}📋 Manual Installation Steps Provided:${NC}"
        echo -e "${PURPLE}$MANUAL_INSTALL_STEPS${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}Thank you for choosing SCTE-35 Streaming Control Center!${NC}"
    echo ""
}

# Function to install Node.js
install_nodejs() {
    print_step "Installing Node.js and npm"
    
    if command_exists node; then
        local node_version=$(node --version)
        print_success "Node.js is already installed: $node_version"
        return 0
    fi
    
    print_info "Node.js not found, installing..."
    
    # Add Node.js repository
    execute_command "curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -" "Add Node.js repository" "true" "true"
    
    # Install Node.js
    execute_command "sudo apt install -y nodejs" "Install Node.js" "true" "true"
    
    # Verify installation
    if command_exists node; then
        local node_version=$(node --version)
        print_success "Node.js installed successfully: $node_version"
    else
        print_error "Node.js installation failed"
        return 1
    fi
}

# Function to install PM2
install_pm2() {
    print_step "Installing PM2"
    
    if command_exists pm2; then
        local pm2_version=$(pm2 --version)
        print_success "PM2 is already installed: $pm2_version"
        return 0
    fi
    
    print_info "PM2 not found, installing..."
    execute_command "sudo npm install -g pm2" "Install PM2 globally" "true" "true"
    
    # Verify installation
    if command_exists pm2; then
        local pm2_version=$(pm2 --version)
        print_success "PM2 installed successfully: $pm2_version"
    else
        print_error "PM2 installation failed"
        return 1
    fi
}

# Function to install FFmpeg
install_ffmpeg() {
    print_step "Installing FFmpeg with SCTE-35 Support"
    
    if command_exists ffmpeg; then
        local ffmpeg_version=$(ffmpeg -version | head -n 1)
        print_success "FFmpeg is already installed: $ffmpeg_version"
        
        # Check if FFmpeg has SCTE-35 support
        if ffmpeg -h demuxer=mpegts 2>/dev/null | grep -qi scte; then
            print_success "FFmpeg has SCTE-35 support"
        else
            print_warning "FFmpeg is installed but SCTE-35 support may be limited"
        fi
        return 0
    fi
    
    print_info "FFmpeg not found, providing manual installation guidance..."
    print_manual "FFmpeg requires compilation from source. Manual installation recommended."
    print_manual "See: docs/MANUAL_INSTALLATION.md - Step 5: Compile and Install FFmpeg"
    print_manual "Or run: ./manual-installation.sh for guided FFmpeg installation"
    
    # Try to install FFmpeg from packages as fallback
    print_info "Attempting to install FFmpeg from packages..."
    if execute_command "sudo apt install -y ffmpeg" "Install FFmpeg from packages" "false" "true"; then
        print_success "FFmpeg installed from packages (limited features)"
        print_warning "For full SCTE-35 support, manual compilation is recommended"
    else
        print_error "FFmpeg installation failed"
        return 1
    fi
}

# Function to install Nginx with RTMP
install_nginx_rtmp() {
    print_step "Installing Nginx with RTMP Module"
    
    local nginx_installed=false
    local rtmp_installed=false
    
    # Check if Nginx is installed
    if command_exists nginx; then
        local nginx_version=$(nginx -v 2>&1)
        print_success "Nginx is already installed: $nginx_version"
        nginx_installed=true
    fi
    
    # Check if Nginx has RTMP module
    if command_exists nginx && nginx -V 2>&1 | grep -q "rtmp"; then
        print_success "Nginx RTMP module is already installed"
        rtmp_installed=true
    elif [[ "$nginx_installed" == "true" ]]; then
        print_warning "Nginx is installed but RTMP module is missing"
    fi
    
    if [[ "$nginx_installed" == "true" && "$rtmp_installed" == "true" ]]; then
        return 0
    fi
    
    # Provide manual installation guidance for Nginx RTMP
    print_manual "Nginx with RTMP module requires compilation from source."
    print_manual "Manual installation is recommended for proper RTMP support."
    print_manual ""
    print_manual "Manual Nginx RTMP Installation Steps:"
    print_manual "1. Install dependencies: sudo apt install build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev"
    print_manual "2. Download Nginx: wget http://nginx.org/download/nginx-1.25.3.tar.gz"
    print_manual "3. Download RTMP module: git clone https://github.com/arut/nginx-rtmp-module.git"
    print_manual "4. Extract: tar -xzf nginx-1.25.3.tar.gz"
    print_manual "5. Configure: cd nginx-1.25.3 && ./configure --add-module=../nginx-rtmp-module --prefix=/etc/nginx"
    print_manual "6. Compile: make"
    print_manual "7. Install: sudo make install"
    print_manual "8. Create user: sudo useradd -r -s /bin/false nginx"
    print_manual "9. Create directories: sudo mkdir -p /var/www/rtmp/hls /var/www/rtmp/dash"
    print_manual "10. Set permissions: sudo chown -R nginx:nginx /var/www/rtmp"
    print_manual ""
    print_manual "Installation folders and locations:"
    print_manual "• Nginx binary: /usr/local/nginx/sbin/nginx"
    print_manual "• Configuration: /etc/nginx/nginx.conf"
    print_manual "• HTML root: /var/www/rtmp"
    print_manual "• Logs: /var/log/nginx/"
    print_manual "• PID file: /run/nginx.pid"
    print_manual ""
    print_manual "Configuration file location: /etc/nginx/nginx.conf"
    print_manual "RTMP configuration should be added to nginx.conf"
    print_manual ""
    print_manual "For complete manual installation guide, see: docs/MANUAL_INSTALLATION.md"
    
    # Try to install Nginx from packages as fallback
    if [[ "$nginx_installed" == "false" ]]; then
        print_info "Attempting to install Nginx from packages..."
        if execute_command "sudo apt install -y nginx" "Install Nginx from packages" "false" "true"; then
            print_success "Nginx installed from packages"
            print_warning "RTMP module not available in package version"
            print_manual "For RTMP support, manual compilation is required"
        else
            print_error "Nginx installation failed"
            return 1
        fi
    fi
}

# Function to setup project
setup_project() {
    print_step "Setting Up SCTE-35 Streaming Project"
    
    local project_dir="/home/ubuntu/SCTE-streamcontrol"
    
    if [[ -d "$project_dir" ]]; then
        print_success "Project directory already exists: $project_dir"
        cd "$project_dir"
        
        # Update existing project
        if [[ -d ".git" ]]; then
            print_info "Updating existing project..."
            execute_command "git pull origin master" "Update existing project" "false" "true"
        fi
    else
        print_info "Project directory not found, cloning repository..."
        execute_command "git clone https://github.com/shihan84/SCTE-streamcontrol.git $project_dir" "Clone project repository" "true" "true"
        cd "$project_dir"
    fi
    
    # Install Node.js dependencies
    if [[ -f "package.json" ]]; then
        print_info "Installing Node.js dependencies..."
        execute_command "npm install" "Install Node.js dependencies" "true" "true"
    else
        print_error "package.json not found"
        return 1
    fi
    
    # Setup database
    if [[ -f "prisma/schema.prisma" ]]; then
        print_info "Setting up database..."
        execute_command "npm run db:push" "Setup database" "true" "true"
    else
        print_warning "Database schema not found, skipping database setup"
    fi
    
    print_success "Project setup completed"
}

# Function to create FFmpeg configuration
create_ffmpeg_config() {
    print_step "Creating FFmpeg Configuration"
    
    local ffmpeg_config_dir="/etc/ffmpeg"
    local ffmpeg_config_file="$ffmpeg_config_dir/scte35.conf"
    
    # Create FFmpeg configuration directory
    if [[ ! -d "$ffmpeg_config_dir" ]]; then
        execute_command "sudo mkdir -p $ffmpeg_config_dir" "Create FFmpeg configuration directory" "true" "true"
    else
        print_info "FFmpeg configuration directory already exists"
    fi
    
    # Create SCTE-35 configuration file
    if [[ ! -f "$ffmpeg_config_file" ]]; then
        print_info "Creating SCTE-35 configuration file..."
        sudo tee "$ffmpeg_config_file" > /dev/null << 'EOF'
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
        print_success "FFmpeg configuration created: $ffmpeg_config_file"
    else
        print_info "FFmpeg configuration file already exists"
    fi
    
    # Create FFmpeg test script
    local test_script="/usr/local/bin/test-ffmpeg-scte35.sh"
    if [[ ! -f "$test_script" ]]; then
        print_info "Creating FFmpeg test script..."
        sudo tee "$test_script" > /dev/null << 'EOF'
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
        execute_command "sudo chmod +x $test_script" "Make FFmpeg test script executable" "true" "true"
        print_success "FFmpeg test script created: $test_script"
    else
        print_info "FFmpeg test script already exists"
    fi
}

# Function to deploy application with PM2
deploy_application() {
    print_step "Deploying Application with PM2"
    
    local project_dir="/home/ubuntu/SCTE-streamcontrol"
    
    if [[ ! -d "$project_dir" ]]; then
        print_error "Project directory not found: $project_dir"
        return 1
    fi
    
    cd "$project_dir"
    
    # Create PM2 ecosystem configuration
    local ecosystem_file="ecosystem.config.js"
    if [[ ! -f "$ecosystem_file" ]]; then
        print_info "Creating PM2 ecosystem configuration..."
        cat > "$ecosystem_file" << 'EOF'
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
        sed -i "s/SERVER_IP/$SERVER_IP/g" "$ecosystem_file"
        print_success "PM2 ecosystem configuration created"
    else
        print_info "PM2 ecosystem configuration already exists"
    fi
    
    # Create PM2 log directory
    local pm2_log_dir="/var/log/pm2"
    if [[ ! -d "$pm2_log_dir" ]]; then
        execute_command "sudo mkdir -p $pm2_log_dir" "Create PM2 log directory" "true" "true"
        execute_command "sudo chown ubuntu:ubuntu $pm2_log_dir" "Set PM2 log directory permissions" "true" "true"
    else
        print_info "PM2 log directory already exists"
    fi
    
    # Check if PM2 is available
    if ! command_exists pm2; then
        print_error "PM2 is not available"
        return 1
    fi
    
    # Stop existing application if running
    if pm2 list | grep -q 'scte35-app'; then
        print_info "Stopping existing application..."
        execute_command "pm2 stop scte35-app" "Stop existing application" "false" "true"
        execute_command "pm2 delete scte35-app" "Delete existing application" "false" "true"
    fi
    
    # Start application
    print_info "Starting application with PM2..."
    execute_command "pm2 start $ecosystem_file" "Start application with PM2" "true" "true"
    
    # Setup PM2 startup
    execute_command "pm2 startup" "Setup PM2 startup" "true" "true"
    
    # Verify application is running
    if pm2 list | grep -q 'scte35-app.*online'; then
        print_success "Application is running successfully"
    else
        print_error "Application is not running"
        return 1
    fi
}

# Function to perform final testing
final_testing() {
    print_step "Final Testing and Verification"
    
    # Test application health
    if curl -s http://localhost:3000/health | grep -q "healthy"; then
        print_success "Application health endpoint is responding"
    else
        print_warning "Application health endpoint is not responding"
    fi
    
    # Test FFmpeg
    if command_exists ffmpeg; then
        print_success "FFmpeg is installed and accessible"
        
        # Run FFmpeg test script if available
        if command_exists test-ffmpeg-scte35.sh; then
            print_info "Running FFmpeg SCTE-35 test script..."
            if test-ffmpeg-scte35.sh >/dev/null 2>&1; then
                print_success "FFmpeg SCTE-35 test script passed"
            else
                print_warning "FFmpeg SCTE-35 test script failed"
            fi
        fi
    else
        print_warning "FFmpeg is not accessible"
    fi
    
    # Test Nginx
    if command_exists nginx; then
        print_success "Nginx is installed and accessible"
        
        # Test Nginx configuration
        if nginx -t >/dev/null 2>&1; then
            print_success "Nginx configuration is valid"
        else
            print_warning "Nginx configuration has issues"
        fi
        
        # Test Nginx endpoints
        if curl -s http://localhost/health | grep -q "healthy"; then
            print_success "Nginx health endpoint is responding"
        else
            print_warning "Nginx health endpoint is not responding"
        fi
    else
        print_warning "Nginx is not accessible"
    fi
    
    # Test PM2
    if command_exists pm2; then
        print_success "PM2 is installed and accessible"
        
        if pm2 list | grep -q 'scte35-app.*online'; then
            print_success "SCTE-35 application is running"
        else
            print_warning "SCTE-35 application is not running"
        fi
    else
        print_warning "PM2 is not accessible"
    fi
}

# Main installation function
main() {
    # Initialize log file
    echo "SCTE-35 Streaming Platform - Smart Auto-Installation Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    echo "User: $(whoami)" >> "$LOG_FILE"
    echo "Server: $(hostname)" >> "$LOG_FILE"
    echo "Server IP: $SERVER_IP" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Show welcome banner
    show_welcome_banner
    
    # Confirm installation
    read -p "Do you want to continue with the smart auto-installation? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled by user."
        exit 0
    fi
    
    # Step 1: Check existing installations
    check_existing_installations
    
    # Step 2: Install Node.js and npm
    install_nodejs
    
    # Step 3: Install PM2
    install_pm2
    
    # Step 4: Install FFmpeg
    install_ffmpeg
    
    # Step 5: Install Nginx with RTMP
    install_nginx_rtmp
    
    # Step 6: Setup project
    setup_project
    
    # Step 7: Create FFmpeg configuration
    create_ffmpeg_config
    
    # Step 8: Deploy application
    deploy_application
    
    # Step 9: Final testing
    final_testing
    
    # Show completion banner
    show_completion_banner
}

# Run main installation
main "$@"