#!/bin/bash

# SCTE-35 Streaming Project Deployment Script (No Sudo Version)
# Run this script when sudo is not available or requires password

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

# Configuration
SERVER_IP=$(hostname -I | awk '{print $1}')
# Detect project directory - use current directory if it contains package.json, otherwise use default
if [ -f "$(pwd)/package.json" ]; then
    PROJECT_DIR=$(pwd)
    print_status "Detected project in current directory: $PROJECT_DIR"
else
    PROJECT_DIR="/home/ubuntu/scte35-project"
    print_status "Using default project directory: $PROJECT_DIR"
fi
APP_USER="ubuntu"

echo -e "${GREEN}SCTE-35 Streaming Project Deployment Script (No Sudo)${NC}"
echo "========================================================"
echo "Server IP: $SERVER_IP"
echo "Project Directory: $PROJECT_DIR"
echo ""

# Check if running as root or with sudo privileges
if [[ $EUID -eq 0 ]]; then
    print_status "Running as root user"
    USE_SUDO=""
else
    print_warning "Not running as root. Some operations may require manual intervention."
    USE_SUDO="sudo"
fi

# Function to run command with sudo if available
run_with_sudo() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        echo "Running with sudo: $*"
        if ! sudo "$@"; then
            print_error "Failed to run: $*"
            print_warning "Please run this command manually:"
            echo "  sudo $*"
            echo ""
            print_warning "Then press Enter to continue..."
            read -r
        fi
    fi
}

# Update system
print_status "Updating system packages..."
run_with_sudo apt update && run_with_sudo apt upgrade -y

# Install system dependencies
print_status "Installing system dependencies..."
run_with_sudo apt install -y git curl wget htop vim net-tools build-essential python3-dev sqlite3 libsqlite3-dev

# Install Node.js 18.x
print_status "Installing Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | run_with_sudo bash -
run_with_sudo apt-get install -y nodejs

# Verify Node.js installation
print_status "Verifying Node.js installation..."
node --version
npm --version

# Install PM2
print_status "Installing PM2..."
run_with_sudo npm install -g pm2

# Nginx is already manually compiled with RTMP support
print_status "Nginx with RTMP module is already installed..."

# Add nginx to PATH if not already there
if ! grep -q "/usr/local/nginx/sbin" /etc/environment; then
    print_status "Adding nginx to PATH..."
    echo "PATH=\$PATH:/usr/local/nginx/sbin" | run_with_sudo tee -a /etc/environment
    export PATH=\$PATH:/usr/local/nginx/sbin
fi

# Create nginx systemd service if not exists
if [ ! -f "/etc/systemd/system/nginx.service" ]; then
    print_status "Creating nginx systemd service..."
    run_with_sudo tee /etc/systemd/system/nginx.service > /dev/null << 'EOF'
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=process
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    
    run_with_sudo systemctl daemon-reload
    run_with_sudo systemctl enable nginx
fi

# Configure firewall
print_status "Configuring firewall..."
run_with_sudo ufw allow 22/tcp    # SSH
run_with_sudo ufw allow 80/tcp    # HTTP
run_with_sudo ufw allow 443/tcp   # HTTPS
run_with_sudo ufw allow 1935/tcp  # RTMP
run_with_sudo ufw allow 1936/tcp  # RTMP stats
run_with_sudo ufw --force enable

# Create project directory if it doesn't exist
print_status "Checking project directory..."
if [ ! -d "$PROJECT_DIR" ]; then
    print_status "Creating project directory: $PROJECT_DIR"
    mkdir -p $PROJECT_DIR
fi

# Check if project already exists
if [ ! -f "$PROJECT_DIR/package.json" ]; then
    print_error "Project not found in: $PROJECT_DIR"
    echo ""
    echo "Please choose one of the following options:"
    echo ""
    echo "Option 1: Clone from GitHub"
    echo "  cd $PROJECT_DIR"
    echo "  git clone https://github.com/shihan84/SCTE-streamcontrol.git ."
    echo "  Then run this script again from: $PROJECT_DIR"
    echo ""
    echo "Option 2: Copy existing project files"
    echo "  Copy your project files to: $PROJECT_DIR"
    echo "  Make sure package.json is included"
    echo "  Then run this script again"
    echo ""
    echo "Option 3: Run from existing project directory"
    echo "  Navigate to your project directory that contains package.json"
    echo "  Run: ./deploy.sh"
    echo ""
    print_warning "Project setup required. Please complete one of the options above."
    exit 1
fi

# Navigate to project directory
cd $PROJECT_DIR

# Install project dependencies
print_status "Installing project dependencies..."
npm install

# Build the application
print_status "Building the application..."
npm run build

# Create environment file FIRST (before database operations)
print_status "Creating environment configuration..."
cat > .env << EOF
NODE_ENV=production
PORT=3000
RTMP_PORT=1935
RTMP_HTTP_PORT=1936
NEXT_PUBLIC_APP_URL=http://$SERVER_IP
DATABASE_URL="file:./dev.db"
EOF

# Setup database AFTER environment file is created
print_status "Setting up database..."
npm run db:generate
npm run db:push

# Create RTMP directories
print_status "Creating RTMP directories..."
run_with_sudo mkdir -p /var/www/rtmp/hls
run_with_sudo mkdir -p /var/www/rtmp/dash
run_with_sudo chown -R $APP_USER:$APP_USER /var/www/rtmp

# Create RTMP configuration
print_status "Configuring RTMP server..."
run_with_sudo mkdir -p /usr/local/nginx/conf/rtmp

run_with_sudo tee /usr/local/nginx/conf/rtmp/rtmp.conf > /dev/null << 'EOF'
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        allow play all;
        
        application live {
            live on;
            record off;
            
            # HLS configuration
            hls on;
            hls_path /var/www/rtmp/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            
            # DASH configuration
            dash on;
            dash_path /var/www/rtmp/dash;
            dash_fragment 3;
            dash_playlist_length 60;
            
            # SCTE-35 support
            on_publish http://localhost:3000/api/rtmp/on-publish;
            on_play http://localhost:3000/api/rtmp/on-play;
            on_publish_done http://localhost:3000/api/rtmp/on-publish-done;
            
            # Access control
            allow publish all;
            allow play all;
        }
        
        # Statistics
        application stat {
            live on;
            allow play all;
        }
    }
}
EOF

# Create Nginx site configuration
print_status "Configuring Nginx..."
run_with_sudo mkdir -p /usr/local/nginx/conf/sites-available
run_with_sudo mkdir -p /usr/local/nginx/conf/sites-enabled

run_with_sudo tee /usr/local/nginx/conf/sites-available/scte35 > /dev/null << EOF
server {
    listen 80;
    server_name $SERVER_IP;
    
    # Next.js application
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # HLS streaming
    location /hls {
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
        root /var/www/rtmp;
        add_header Cache-Control no-cache;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
    
    # DASH streaming
    location /dash {
        types {
            application/dash+xml mpd;
            video/mp4 mp4;
        }
        root /var/www/rtmp;
        add_header Cache-Control no-cache;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
    
    # RTMP statistics
    location /stat {
        rtmp_stat all;
        rtmp_stat_stylesheet stat.xsl;
    }
    
    location /stat.xsl {
        root /usr/local/nginx/conf/rtmp;
    }
}
EOF

# Enable site
run_with_sudo ln -sf /usr/local/nginx/conf/sites-available/scte35 /usr/local/nginx/conf/sites-enabled/

# Add RTMP configuration to nginx.conf
if ! grep -q "include /usr/local/nginx/conf/rtmp/rtmp.conf" /usr/local/nginx/conf/nginx.conf; then
    run_with_sudo sed -i '/http {/i \
# Include RTMP configuration\
include /usr/local/nginx/conf/rtmp/rtmp.conf;\
' /usr/local/nginx/conf/nginx.conf
fi

# Add sites-enabled include to nginx.conf
if ! grep -q "include /usr/local/nginx/conf/sites-enabled" /usr/local/nginx/conf/nginx.conf; then
    run_with_sudo sed -i '/http {/,/}/s/}/    include \/usr\/local\/nginx\/conf\/sites-enabled\/*;\n}/' /usr/local/nginx/conf/nginx.conf
fi

# Test nginx configuration
print_status "Testing Nginx configuration..."
if ! run_with_sudo /usr/local/nginx/sbin/nginx -t; then
    print_error "Nginx configuration test failed. Please check the configuration manually."
    print_warning "Checking nginx error logs..."
    run_with_sudo tail -n 20 /usr/local/nginx/logs/error.log
    exit 1
fi

# Restart nginx
print_status "Restarting Nginx..."
run_with_sudo systemctl restart nginx

# Create PM2 configuration
print_status "Creating PM2 configuration..."
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'scte35-app',
    script: 'npm',
    args: 'start',
    cwd: '$PROJECT_DIR',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'file:./dev.db'
    },
    error_file: '/var/log/pm2/scte35-error.log',
    out_file: '/var/log/pm2/scte35-out.log',
    log_file: '/var/log/pm2/scte35.log',
    time: true,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G'
  }]
};
EOF

# Create log directory
run_with_sudo mkdir -p /var/log/pm2
run_with_sudo chown -R $APP_USER:$APP_USER /var/log/pm2

# Start application with PM2
print_status "Starting application with PM2..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Optimize system performance
print_status "Optimizing system performance..."
run_with_sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'

# Increase file descriptor limit
fs.file-max = 100000

# Network optimization
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = cubic
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.ip_local_port_range = 10000 65535
EOF

run_with_sudo sysctl -p

# Create backup script
print_status "Creating backup script..."
cat > ~/backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup project files
tar -czf $BACKUP_DIR/project_$DATE.tar.gz -C /home/ubuntu scte35-project

# Backup database
if [ -f "/home/ubuntu/scte35-project/dev.db" ]; then
    cp /home/ubuntu/scte35-project/dev.db $BACKUP_DIR/database_$DATE.db
fi

# Backup nginx configuration
cp -r /usr/local/nginx/conf $BACKUP_DIR/nginx_$DATE

# Keep only last 7 days of backups
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x ~/backup.sh

# Add daily backup to crontab
(crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/backup.sh") | crontab -

# Display deployment summary
echo ""
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo "=============================================="
echo "Application URL: http://$SERVER_IP"
echo "RTMP Server: rtmp://$SERVER_IP:1935/live"
echo "HLS Stream: http://$SERVER_IP/hls"
echo "RTMP Stats: http://$SERVER_IP/stat"
echo "Database: SQLite (dev.db)"
echo ""
echo "Useful Commands:"
echo "  View logs: pm2 logs"
echo "  Monitor: pm2 monit"
echo "  Restart app: pm2 restart scte35-app"
echo "  Restart nginx: systemctl restart nginx"
echo "  Test nginx: /usr/local/nginx/sbin/nginx -t"
echo "  Nginx logs: tail -f /usr/local/nginx/logs/error.log"
echo "  Database operations: npm run db:push"
echo ""
echo "Configuration Files:"
echo "  Nginx main: /usr/local/nginx/conf/nginx.conf"
echo "  RTMP config: /usr/local/nginx/conf/rtmp/rtmp.conf"
echo "  Site config: /usr/local/nginx/conf/sites-available/scte35"
echo "  Nginx logs: /usr/local/nginx/logs/"
echo ""
echo "Next Steps:"
echo "1. Open http://$SERVER_IP in your browser"
echo "2. Test RTMP streaming using FFmpeg:"
echo "   ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://$SERVER_IP:1935/live/test"
echo "3. Access HLS stream at: http://$SERVER_IP/hls/test.m3u8"
echo "4. Database file is located at: $PROJECT_DIR/dev.db"
echo ""
echo -e "${YELLOW}Note: Make sure to replace test.mp4 with your actual video file${NC}"