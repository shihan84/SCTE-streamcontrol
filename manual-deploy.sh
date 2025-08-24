#!/bin/bash

# SCTE-35 Streaming Project - Manual Deployment Guide
# This script provides manual commands for deployment when sudo is not available

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
PROJECT_DIR=$(pwd)

echo -e "${GREEN}SCTE-35 Streaming Project - Manual Deployment Guide${NC}"
echo "======================================================"
echo "Server IP: $SERVER_IP"
echo "Project Directory: $PROJECT_DIR"
echo ""

print_status "This script will guide you through the manual deployment process."
print_status "Please run the following commands manually when prompted:"
echo ""

# Step 1: System Dependencies
print_status "Step 1: Install System Dependencies"
echo "Run these commands:"
echo "  sudo apt update"
echo "  sudo apt upgrade -y"
echo "  sudo apt install -y git curl wget htop vim net-tools build-essential python3-dev sqlite3 libsqlite3-dev"
echo ""

# Step 2: Node.js
print_status "Step 2: Install Node.js 18.x"
echo "Run these commands:"
echo "  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -"
echo "  sudo apt-get install -y nodejs"
echo ""

# Step 3: PM2
print_status "Step 3: Install PM2"
echo "Run this command:"
echo "  sudo npm install -g pm2"
echo ""

# Step 4: Nginx PATH
print_status "Step 4: Add Nginx to PATH"
echo "Run this command:"
echo '  echo "PATH=\$PATH:/usr/local/nginx/sbin" | sudo tee -a /etc/environment'
echo ""

# Step 5: Nginx Service
print_status "Step 5: Create Nginx Systemd Service"
echo "Create this file: /etc/systemd/system/nginx.service"
echo "Content:"
cat << 'EOF'
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
echo ""
echo "Then run:"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable nginx"
echo ""

# Step 6: Firewall
print_status "Step 6: Configure Firewall"
echo "Run these commands:"
echo "  sudo ufw allow 22/tcp"
echo "  sudo ufw allow 80/tcp"
echo "  sudo ufw allow 443/tcp"
echo "  sudo ufw allow 1935/tcp"
echo "  sudo ufw allow 1936/tcp"
echo "  sudo ufw --force enable"
echo ""

# Wait for user to complete the above steps
print_warning "Please complete all the above steps before continuing."
echo "Press Enter when you're ready to continue with the application setup..."
read -r

# Step 7: Application Setup (no sudo needed)
print_status "Step 7: Setting up Application"
echo "Installing project dependencies..."
npm install

echo "Building the application..."
npm run build

echo "Creating environment configuration..."
cat > .env << EOF
NODE_ENV=production
PORT=3000
RTMP_PORT=1935
RTMP_HTTP_PORT=1936
NEXT_PUBLIC_APP_URL=http://$SERVER_IP
DATABASE_URL="file:./dev.db"
EOF

echo "Setting up database..."
npm run db:generate
npm run db:push

# Step 8: Manual Nginx Configuration
print_status "Step 8: Manual Nginx Configuration"
echo "Run these commands:"
echo ""
echo "Create RTMP directories:"
echo "  sudo mkdir -p /var/www/rtmp/hls"
echo "  sudo mkdir -p /var/www/rtmp/dash"
echo "  sudo chown -R ubuntu:ubuntu /var/www/rtmp"
echo ""
echo "Create RTMP configuration directory:"
echo "  sudo mkdir -p /usr/local/nginx/conf/rtmp"
echo ""
echo "Create RTMP configuration file: /usr/local/nginx/conf/rtmp/rtmp.conf"
echo "Content:"
cat << 'EOF'
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
echo ""
echo "Create sites directories:"
echo "  sudo mkdir -p /usr/local/nginx/conf/sites-available"
echo "  sudo mkdir -p /usr/local/nginx/conf/sites-enabled"
echo ""
echo "Create site configuration: /usr/local/nginx/conf/sites-available/scte35"
echo "Content:"
cat << EOF
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
echo ""
echo "Enable the site:"
echo "  sudo ln -sf /usr/local/nginx/conf/sites-available/scte35 /usr/local/nginx/conf/sites-enabled/"
echo ""
echo "Add RTMP configuration to nginx.conf:"
echo "  sudo sed -i '/http {/i \\# Include RTMP configuration\\include /usr/local/nginx/conf/rtmp/rtmp.conf;\\' /usr/local/nginx/conf/nginx.conf"
echo ""
echo "Add sites-enabled include to nginx.conf:"
echo "  sudo sed -i '/http {/,/}/s/}/    include \\/usr\\/local\\/nginx\\/conf\\/sites-enabled\\/*;\\n}/' /usr/local/nginx/conf/nginx.conf"
echo ""
echo "Test nginx configuration:"
echo "  sudo /usr/local/nginx/sbin/nginx -t"
echo ""
echo "Restart nginx:"
echo "  sudo systemctl restart nginx"
echo ""

# Wait for user to complete nginx configuration
print_warning "Please complete all the Nginx configuration steps above."
echo "Press Enter when you're ready to continue with the application startup..."
read -r

# Step 9: Start Application
print_status "Step 9: Starting Application"
echo "Creating PM2 configuration..."
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

echo "Creating log directory (run with sudo):"
echo "  sudo mkdir -p /var/log/pm2"
echo "  sudo chown -R ubuntu:ubuntu /var/log/pm2"
echo ""

echo "Starting application with PM2..."
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Step 10: System Optimization
print_status "Step 10: System Optimization"
echo "Add these lines to /etc/sysctl.conf (run with sudo):"
cat << 'EOF'

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
echo ""
echo "Then run:"
echo "  sudo sysctl -p"
echo ""

# Step 11: Backup Setup
print_status "Step 11: Backup Setup"
echo "Creating backup script..."
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

echo "Add daily backup to crontab:"
echo "  (crontab -l 2>/dev/null; echo \"0 2 * * * /home/ubuntu/backup.sh\") | crontab -"
echo ""

# Final Summary
echo ""
echo -e "${GREEN}Manual Deployment Guide Completed!${NC}"
echo "=========================================="
echo ""
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
echo "  Restart nginx: sudo systemctl restart nginx"
echo "  Test nginx: sudo /usr/local/nginx/sbin/nginx -t"
echo "  Nginx logs: sudo tail -f /usr/local/nginx/logs/error.log"
echo "  Database operations: npm run db:push"
echo ""
echo "Configuration Files:"
echo "  Nginx main: /usr/local/nginx/conf/nginx.conf"
echo "  RTMP config: /usr/local/nginx/conf/rtmp/rtmp.conf"
echo "  Site config: /usr/local/nginx/conf/sites-available/scte35"
echo "  Nginx logs: /usr/local/nginx/logs/"
echo ""
echo "Next Steps:"
echo "1. Complete all manual commands above"
echo "2. Open http://$SERVER_IP in your browser"
echo "3. Test RTMP streaming using FFmpeg:"
echo "   ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://$SERVER_IP:1935/live/test"
echo "4. Access HLS stream at: http://$SERVER_IP/hls/test.m3u8"
echo "5. Database file is located at: $PROJECT_DIR/dev.db"
echo ""
echo -e "${YELLOW}Note: Make sure to replace test.mp4 with your actual video file${NC}"