# SCTE-35 Streaming Project - Complete Deployment Guide

This comprehensive guide provides step-by-step instructions for deploying the SCTE-35 streaming project with all the latest features and optimizations.

## 🚀 Quick Start

### Automated Deployment (Recommended)
```bash
# Clone the repository
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol

# Run the deployment script
./deploy.sh
```

### Manual Quick Setup
```bash
# System updates and dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget htop vim net-tools build-essential python3-dev

# Install Node.js and PM2
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2

# Install Nginx with RTMP module
sudo apt install -y nginx
sudo ufw allow 22,80,443,1935,1936/tcp
sudo ufw --force enable

# Setup project
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol
npm install
npm run build

# Configure environment
echo "NODE_ENV=production
PORT=3000
RTMP_PORT=1935
RTMP_HTTP_PORT=1936
NEXT_PUBLIC_APP_URL=http://$(hostname -I | awk '{print $1}')" > .env

# Start application
pm2 start npm --name "scte35-app" -- start
pm2 save
pm2 startup

# Configure Nginx
./fix-nginx-config.sh
```

## 📋 Table of Contents

1. [System Requirements](#system-requirements)
2. [Environment Setup](#environment-setup)
3. [Project Installation](#project-installation)
4. [Nginx Configuration](#nginx-configuration)
5. [Application Deployment](#application-deployment)
6. [SCTE-35 Configuration](#scte-35-configuration)
7. [Testing and Verification](#testing-and-verification)
8. [Production Optimization](#production-optimization)
9. [Maintenance and Updates](#maintenance-and-updates)
10. [Troubleshooting](#troubleshooting)

## 🖥️ System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04+ or Debian 10+
- **CPU**: 2 cores (4 cores recommended)
- **RAM**: 4GB (8GB recommended)
- **Storage**: 25GB SSD (50GB recommended)
- **Network**: 10 Mbps upload bandwidth

### Recommended Requirements
- **OS**: Ubuntu 22.04 LTS
- **CPU**: 4+ cores
- **RAM**: 8GB+ (16GB for high traffic)
- **Storage**: 50GB+ SSD
- **Network**: 100 Mbps+ upload bandwidth

## 🌍 Environment Setup

### VirtualBox Configuration (Development)
```bash
# VM Settings
- Name: SCTE35-Server
- Type: Linux (64-bit)
- Memory: 4096 MB
- CPU: 2 cores (enable PAE/NX and Nested VT-x)
- Network: Bridged Adapter
- Storage: 25GB+ dynamically allocated VDI
```

### Cloud Server Setup (Production)
```bash
# Initial server setup
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget htop vim net-tools build-essential python3-dev
sudo apt install -y ufw fail2ban
sudo hostnamectl set-hostname scte35-server

# Configure firewall
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 1935/tcp  # RTMP
sudo ufw allow 1936/tcp  # RTMP stats
sudo ufw --force enable
```

## 📦 Project Installation

### Clone and Setup Repository
```bash
# Navigate to home directory
cd ~

# Clone the repository
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol

# Install dependencies
npm install

# Build the application
npm run build

# Create environment file
cp .env.example .env
nano .env
```

### Environment Configuration
```bash
# Production environment settings
NODE_ENV=production
PORT=3000

# RTMP Server settings
RTMP_PORT=1935
RTMP_HTTP_PORT=1936

# Application URL
NEXT_PUBLIC_APP_URL=http://your-server-ip

# Database settings (if using Prisma)
DATABASE_URL="file:./dev.db"

# Optional: SSL and domain settings
NEXT_PUBLIC_APP_URL=https://your-domain.com
```

## ⚙️ Nginx Configuration

### Automated Configuration Setup
```bash
# Run the comprehensive Nginx configuration script
./fix-nginx-config.sh

# This script automatically:
# - Creates required directories (/var/www/rtmp/hls, /var/www/rtmp/dash)
# - Sets proper permissions
# - Configures main nginx.conf with RTMP support
# - Sets up proxy for Next.js application
# - Configures HLS/DASH streaming
# - Sets up RTMP statistics
# - Adds security headers and CORS support
# - Tests and reloads Nginx configuration
```

### Manual Configuration (Alternative)
```bash
# Create required directories
sudo mkdir -p /var/www/rtmp/hls /var/www/rtmp/dash
sudo chown -R www-data:www-data /var/www/rtmp
sudo chmod -R 755 /var/www/rtmp

# Create main nginx configuration
sudo nano /etc/nginx/nginx.conf
```

**Complete nginx.conf configuration:**
```nginx
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

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
        server_name your-server-ip localhost;
        
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
```

### Test and Reload Nginx
```bash
# Test nginx configuration
sudo nginx -t

# If test passes, reload nginx
sudo systemctl reload nginx

# Check nginx status
sudo systemctl status nginx
```

## 🚀 Application Deployment

### PM2 Configuration
```bash
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
      PORT: 3000
    },
    error_file: '/var/log/pm2/scte35-error.log',
    out_file: '/var/log/pm2/scte35-out.log',
    log_file: '/var/log/pm2/scte35.log',
    time: true,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    merge_logs: true
  }]
};
EOF

# Create log directory
sudo mkdir -p /var/log/pm2
sudo chown -R ubuntu:ubuntu /var/log/pm2

# Start application with PM2
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
```

### Application Management Commands
```bash
# List all processes
pm2 list

# Monitor application
pm2 monit

# View logs
pm2 logs

# Restart application
pm2 restart scte35-app

# Stop application
pm2 stop scte35-app

# Update application
git pull
npm install
npm run build
pm2 reload scte35-app
```

## 🎛️ SCTE-35 Configuration

### SCTE-35 Webhook Setup
The application includes SCTE-35 webhook endpoints that are automatically configured in the Nginx setup:

- **`/api/scte35/on-publish`** - Triggered when a stream starts
- **`/api/scte35/on-publish-done`** - Triggered when a stream ends
- **`/api/scte35/on-play`** - Triggered when a client starts playing
- **`/api/scte35/on-play-done`** - Triggered when a client stops playing

### SCTE-35 Template Management
Use the web interface to:
1. Create SCTE-35 insertion templates
2. Configure timing and duration
3. Set up ad break scheduling
4. Monitor SCTE-35 events in real-time

### Stream Configuration
```bash
# RTMP stream URL for publishing
rtmp://your-server-ip:1935/live/stream-key

# HLS playback URL
http://your-server-ip/hls/stream-key.m3u8

# DASH playback URL
http://your-server-ip/dash/stream-key.mpd

# RTMP statistics
http://your-server-ip/stat
```

## 🧪 Testing and Verification

### Health Checks
```bash
# Check application health
curl http://localhost:3000/health

# Check Nginx health
curl http://your-server-ip/health

# Check RTMP statistics
curl http://your-server-ip/stat
```

### Test RTMP Streaming
```bash
# Install FFmpeg for testing
sudo apt install -y ffmpeg

# Push a test stream (create a test video first)
ffmpeg -f lavfi -i testsrc2=duration=30:size=640x480:rate=30 -f lavfi -i sine=frequency=1000:duration=30 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test

# Test with a video file
ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test
```

### Verify Streaming Outputs
```bash
# Test HLS stream
curl -I http://your-server-ip/hls/test.m3u8

# Test DASH stream
curl -I http://your-server-ip/dash/test.mpd

# Test RTMP statistics
curl -I http://your-server-ip/stat
```

### Web Interface Testing
Open your browser and navigate to:
- **Main Application**: `http://your-server-ip/`
- **RTMP Statistics**: `http://your-server-ip/stat`
- **Health Check**: `http://your-server-ip/health`

## ⚡ Production Optimization

### SSL/TLS Configuration
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com

# Auto-renew SSL certificates
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### System Security
```bash
# Install and configure fail2ban
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Configure fail2ban
sudo nano /etc/fail2ban/jail.local
```

**fail2ban configuration:**
```ini
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
```

### Performance Optimization
```bash
# System optimization
sudo nano /etc/sysctl.conf
```

**Add these lines to sysctl.conf:**
```ini
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
```

Apply changes:
```bash
sudo sysctl -p
```

### Nginx Performance Tuning
```bash
# Edit nginx configuration for performance
sudo nano /etc/nginx/nginx.conf
```

**Add to http block:**
```nginx
# Performance optimizations
worker_processes auto;
worker_rlimit_nofile 65535;
multi_accept on;

# Connection optimization
keepalive_timeout 30;
keepalive_requests 1000;
reset_timedout_connection on;

# Buffer optimization
client_body_buffer_size 128k;
client_max_body_size 100m;
client_header_buffer_size 1k;
large_client_header_buffers 4 4k;
output_buffers 1 32k;
postpone_output 1460;
```

## 🔧 Maintenance and Updates

### Repository Updates
```bash
# Use the automated update scripts
./update-from-github.sh    # Interactive update
./git-reset-pull.sh        # Quick reset-based update

# Manual update process
git pull origin master
npm install
npm run build
pm2 reload scte35-app
```

### Backup Procedures
```bash
# Create backup script
cat > backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup project files
tar -czf $BACKUP_DIR/project_$DATE.tar.gz -C /home/ubuntu SCTE-streamcontrol

# Backup nginx configuration
sudo cp -r /etc/nginx $BACKUP_DIR/nginx_$DATE

# Backup PM2 configuration
pm2 save > $BACKUP_DIR/pm2_$DATE.dump

# Keep only last 7 days of backups
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup completed: $DATE"
EOF

chmod +x backup.sh

# Setup automatic backups
crontab -e
# Add: 0 2 * * * /home/ubuntu/SCTE-streamcontrol/backup.sh
```

### System Monitoring
```bash
# Monitor system resources
htop
df -h
free -h

# Monitor application logs
pm2 logs

# Monitor nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Monitor RTMP logs
sudo tail -f /var/log/nginx/rtmp_access.log
```

### Log Rotation
```bash
# Configure logrotate for application logs
sudo nano /etc/logrotate.d/scte35-app
```

**logrotate configuration:**
```
/var/log/pm2/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
    postrotate
        pm2 reload scte35-app
    endscript
}
```

## 🚨 Troubleshooting

### Common Issues and Solutions

#### Application Won't Start
```bash
# Check PM2 logs
pm2 logs

# Check if port 3000 is available
sudo netstat -tulpn | grep :3000

# Check Node.js version
node --version
npm --version

# Restart application
pm2 restart scte35-app
```

#### RTMP Streaming Issues
```bash
# Check nginx configuration
sudo nginx -t

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log

# Check if RTMP port is listening
sudo netstat -tulpn | grep :1935

# Test RTMP connection
telnet localhost 1935
```

#### Nginx Configuration Issues
```bash
# Test nginx configuration
sudo nginx -t

# Check nginx status
sudo systemctl status nginx

# Reload nginx
sudo systemctl reload nginx

# Check nginx logs
sudo journalctl -u nginx -f
```

#### Performance Issues
```bash
# Check system resources
free -h
cat /proc/loadavg
df -h

# Check PM2 memory usage
pm2 info scte35-app

# Monitor processes
pm2 monit
htop
```

#### Permission Issues
```bash
# Fix file permissions
sudo chown -R ubuntu:ubuntu /home/ubuntu/SCTE-streamcontrol
sudo chmod -R 755 /home/ubuntu/SCTE-streamcontrol

# Fix RTMP directory permissions
sudo chown -R www-data:www-data /var/www/rtmp
sudo chmod -R 755 /var/www/rtmp
```

### Log File Locations
- **Application logs**: `/var/log/pm2/`
- **Nginx logs**: `/var/log/nginx/`
- **RTMP logs**: `/var/log/nginx/rtmp_access.log`
- **System logs**: `/var/log/syslog`
- **Authentication logs**: `/var/log/auth.log`

### Useful Commands
```bash
# System information
uname -a
lscpu
free -h
df -h

# Network information
ip addr show
netstat -tulpn
ss -tulpn

# Process management
ps aux | grep node
pm2 list
pm2 monit

# Service management
sudo systemctl status nginx
sudo systemctl restart nginx
sudo systemctl status pm2-init

# File system
find /home/ubuntu/SCTE-streamcontrol -name "*.log"
du -sh /home/ubuntu/SCTE-streamcontrol
```

## 📞 Support and Resources

### Getting Help
1. **Check logs**: Use `pm2 logs` and `sudo tail -f /var/log/nginx/error.log`
2. **Verify services**: Check `pm2 status` and `sudo systemctl status nginx`
3. **Test connectivity**: Use `curl http://localhost:3000/health`
4. **Review documentation**: Check this guide and `QUICK_START.md`

### Community Resources
- **GitHub Issues**: Report bugs and request features
- **Documentation**: All guides and scripts are in the repository
- **Update Scripts**: Use `./update-from-github.sh` for latest fixes

### Emergency Recovery
```bash
# Restore from backup
cd /home/ubuntu/backups
tar -xzf project_latest.tar.gz -C /home/ubuntu/
sudo cp -r nginx_latest/* /etc/nginx/

# Restart services
pm2 restart scte35-app
sudo systemctl restart nginx
```

---

This guide provides a complete deployment solution for your SCTE-35 streaming project. For additional support or to contribute improvements, please visit the GitHub repository.