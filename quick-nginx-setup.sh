#!/bin/bash

# Quick Nginx Setup for Current Environment
# This script quickly sets up Nginx with RTMP support

echo "Setting up Nginx with RTMP support..."

# Update and install nginx
apt update && apt install -y nginx libnginx-mod-rtmp

# Create directories
mkdir -p /etc/nginx/rtmp /var/www/rtmp/hls /var/www/rtmp/dash

# Create RTMP config
cat > /etc/nginx/rtmp/rtmp.conf << 'EOF'
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        allow play all;
        
        application live {
            live on;
            record off;
            hls on;
            hls_path /var/www/rtmp/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            dash on;
            dash_path /var/www/rtmp/dash;
            dash_fragment 3;
            dash_playlist_length 60;
            on_publish http://localhost:3000/api/rtmp/on-publish;
            on_play http://localhost:3000/api/rtmp/on-play;
            on_publish_done http://localhost:3000/api/rtmp/on-publish-done;
            allow publish all;
            allow play all;
        }
        
        application stat {
            live on;
            allow play all;
        }
    }
}
EOF

# Create main config
cat > /etc/nginx/nginx.conf << 'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

include /etc/nginx/rtmp/rtmp.conf;

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Create site config
cat > /etc/nginx/sites-available/scte35 << EOF
server {
    listen 80;
    server_name localhost;
    
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
    
    location /hls {
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
        root /var/www/rtmp;
        add_header Cache-Control no-cache;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
    
    location /dash {
        types {
            application/dash+xml mpd;
            video/mp4 mp4;
        }
        root /var/www/rtmp;
        add_header Cache-Control no-cache;
        add_header 'Access-Control-Allow-Origin' '*' always;
    }
    
    location /stat {
        rtmp_stat all;
        rtmp_stat_stylesheet stat.xsl;
    }
    
    location /stat.xsl {
        root /etc/nginx/rtmp;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/scte35 /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Set permissions
chown -R www-data:www-data /var/www/rtmp

# Test and start
nginx -t && nginx

echo "Nginx setup complete!"
echo "Check status: ps aux | grep nginx"
echo "Test config: nginx -t"
echo "Access app: http://localhost:80"