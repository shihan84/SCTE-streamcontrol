# SCTE-35 Streaming Control Center - Complete Deployment Guide

This comprehensive guide provides step-by-step instructions for deploying the SCTE-35 Streaming Control Center with proper RTMP module support.

## Prerequisites

- Ubuntu 20.04/22.04 LTS
- Root or sudo access
- Internet connection
- Minimum 2GB RAM, 2 CPU cores
- 20GB disk space

## Quick Deployment Options

### Option 1: Automated Full Deployment

```bash
# Download and run the complete deployment script
wget https://raw.githubusercontent.com/shihan84/SCTE-streamcontrol/main/full-deploy.sh
chmod +x full-deploy.sh
sudo ./full-deploy.sh
```

### Option 2: RTMP Module Fix Only

If you already have the project but need to fix the RTMP module issue:

```bash
# Download and run the RTMP module fix script
wget https://raw.githubusercontent.com/shihan84/SCTE-streamcontrol/main/nginx-rtmp-module-fix.sh
chmod +x nginx-rtmp-module-fix.sh
sudo ./nginx-rtmp-module-fix.sh
```

### Option 3: Quick RTMP Fix (Alternative)

```bash
# Download and run the quick RTMP fix script
wget https://raw.githubusercontent.com/shihan84/SCTE-streamcontrol/main/nginx-rtmp-quick-fix.sh
chmod +x nginx-rtmp-quick-fix.sh
sudo ./nginx-rtmp-quick-fix.sh
```

## Manual Deployment Steps

### Step 1: System Preparation

```bash
# Update system
sudo apt update
sudo apt upgrade -y

# Install basic tools
sudo apt install -y git curl wget htop vim net-tools build-essential python3-dev ufw fail2ban
```

### Step 2: Install Node.js and PM2

```bash
# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node --version
npm --version

# Install PM2
sudo npm install -g pm2
```

### Step 3: Install Nginx with RTMP Module

```bash
# Remove existing Nginx
sudo apt remove --purge -y nginx nginx-common nginx-full nginx-core || true
sudo apt autoremove -y
sudo apt autoclean

# Install build dependencies
sudo apt install -y build-essential libpcre3-dev libssl-dev zlib1g-dev git wget

# Download and compile Nginx with RTMP
cd /tmp
wget https://nginx.org/download/nginx-1.25.3.tar.gz
tar -xzf nginx-1.25.3.tar.gz
cd nginx-1.25.3
git clone https://github.com/arut/nginx-rtmp-module.git

# Configure Nginx
./configure \
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
    --add-dynamic-module=./nginx-rtmp-module

# Compile and install
make -j$(nproc)
sudo make install

# Create nginx user
sudo id -u www-data &>/dev/null || sudo useradd -r -s /bin/false www-data

# Create systemd service
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

# Enable nginx
sudo systemctl daemon-reload
sudo systemctl enable nginx

# Clean up
cd /
rm -rf /tmp/nginx-1.25.3
```

### Step 4: Configure Nginx

```bash
# Create directories
sudo mkdir -p /etc/nginx/conf.d
sudo mkdir -p /var/log/nginx
sudo mkdir -p /var/www/rtmp/hls
sudo mkdir -p /var/www/rtmp/dash
sudo chown -R www-data:www-data /var/www/rtmp
sudo chmod -R 755 /var/www/rtmp

# Create nginx.conf
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
        server_name localhost;
        
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

# Test configuration
sudo nginx -t
sudo systemctl start nginx
```

### Step 5: Configure Firewall

```bash
# Configure UFW firewall
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 1935/tcp  # RTMP
sudo ufw allow 1936/tcp  # RTMP stats
sudo ufw --force enable
```

### Step 6: Clone and Setup Project

```bash
# Clone the project
cd ~
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol

# Install dependencies
npm install

# Build application
npm run build

# Create environment configuration
SERVER_IP=$(hostname -I | awk '{print $1}')
cat > .env << EOF
NODE_ENV=production
PORT=3000
RTMP_PORT=1935
RTMP_HTTP_PORT=1936
NEXT_PUBLIC_APP_URL=http://$SERVER_IP
DATABASE_URL="file:./dev.db"
EOF
```

### Step 7: Deploy with PM2

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

# Start application
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
```

### Step 8: Configure Security

```bash
# Configure fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Create fail2ban configuration
sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
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
EOF

sudo systemctl restart fail2ban
```

## Testing and Verification

### 1. Check Nginx Status

```bash
sudo systemctl status nginx
sudo nginx -t
```

### 2. Test RTMP Module

```bash
# Test RTMP streaming
ffmpeg -re -i /dev/zero -c:v libx264 -t 10 -f flv rtmp://localhost:1935/live/test

# View RTMP statistics
curl http://localhost/stat
```

### 3. Check Application Status

```bash
pm2 status
pm2 logs scte35-app
```

### 4. Test Web Interface

Open your browser and navigate to:
```
http://your-server-ip/
```

## Troubleshooting

### Common Issues

#### 1. RTMP Module Not Found

**Error**: `nginx: [emerg] unknown directive "rtmp"`

**Solution**: Use the RTMP module fix script:
```bash
sudo ./nginx-rtmp-module-fix.sh
```

#### 2. Port Already in Use

**Error**: `Address already in use`

**Solution**:
```bash
sudo netstat -tulpn | grep :1935
sudo kill -9 <PID>
```

#### 3. Permission Issues

**Error**: `Permission denied`

**Solution**:
```bash
sudo chown -R www-data:www-data /var/www/rtmp
sudo chown -R www-data:www-data /var/log/nginx
```

#### 4. Configuration Test Fails

**Error**: `nginx: configuration test failed`

**Solution**:
```bash
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

### Log Files

- Nginx Error Log: `/var/log/nginx/error.log`
- Nginx Access Log: `/var/log/nginx/access.log`
- RTMP Access Log: `/var/log/nginx/rtmp_access.log`
- PM2 Logs: `/var/log/pm2/scte35-*.log`
- Systemd Journal: `journalctl -u nginx -f`

## Advanced Configuration

### SSL/TLS Configuration

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Load Balancing

```bash
# Update nginx.conf for multiple instances
upstream scte35_app {
    server localhost:3000;
    server localhost:3001;
    server localhost:3002;
}

# Update proxy_pass in server configuration
proxy_pass http://scte35_app;
```

### Monitoring Setup

```bash
# Install monitoring tools
sudo apt install htop iotop nethogs

# Create monitoring script
cat > monitor.sh << 'EOF'
#!/bin/bash
echo "=== System Resources ==="
htop -n 1 | head -20
echo ""
echo "=== Nginx Status ==="
sudo systemctl status nginx --no-pager
echo ""
echo "=== PM2 Status ==="
pm2 status
echo ""
echo "=== Disk Usage ==="
df -h
echo ""
echo "=== Memory Usage ==="
free -h
EOF

chmod +x monitor.sh
```

## Backup and Recovery

### Backup Script

```bash
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
(crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/SCTE-streamcontrol/backup.sh") | crontab -
```

### Recovery Process

```bash
# Restore from backup
cd /home/ubuntu
tar -xzf backups/project_YYYYMMDD_HHMMSS.tar.gz

# Restore nginx configuration
sudo cp -r backups/nginx_YYYYMMDD_HHMMSS/* /etc/nginx/

# Restore PM2 configuration
pm2 resurrect backups/pm2_YYYYMMDD_HHMMSS.dump
```

## Performance Optimization

### Nginx Optimization

```bash
# Update nginx.conf worker settings
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    multi_accept on;
    use epoll;
}
```

### System Optimization

```bash
# Update system limits
sudo tee /etc/security/limits.conf > /dev/null << 'EOF'
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# Update sysctl settings
sudo tee /etc/sysctl.conf > /dev/null << 'EOF'
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = cubic
EOF

sudo sysctl -p
```

## Support and Maintenance

### Regular Maintenance Tasks

1. **Daily**: Check logs, monitor system resources
2. **Weekly**: Update packages, check security patches
3. **Monthly**: Review performance, clean up logs
4. **Quarterly**: Full system audit, backup verification

### Contact Support

For technical support and assistance:
- GitHub Issues: https://github.com/shihan84/SCTE-streamcontrol/issues
- Documentation: https://github.com/shihan84/SCTE-streamcontrol/wiki
- Email Support: support@morusbroadcasting.com

---

© 2024 Morus Broadcasting Pvt Ltd. All rights reserved.