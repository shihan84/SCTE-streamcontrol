#!/bin/bash

# Alternative RTMP Setup using Docker
# This script sets up RTMP server using Docker if Nginx RTMP module is not available

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

print_status "Setting up RTMP server using Docker..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_status "Installing Docker..."
    sudo apt update
    sudo apt install -y docker.io docker-compose
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    print_warning "You may need to log out and log back in for Docker permissions to take effect"
fi

# Create RTMP directories
print_status "Creating RTMP directories..."
sudo mkdir -p /var/www/rtmp/hls
sudo mkdir -p /var/www/rtmp/dash
sudo chown -R $USER:$USER /var/www/rtmp

# Create Docker Compose configuration
print_status "Creating Docker Compose configuration..."
cat > docker-compose-rtmp.yml << 'EOF'
version: '3.8'

services:
  rtmp:
    image: alqutami/rtmp-hls:latest
    container_name: rtmp-server
    ports:
      - "1935:1935"  # RTMP
      - "8080:80"    # HLS
    volumes:
      - ./rtmp/conf:/etc/nginx/conf.d
      - ./rtmp/data:/tmp/hls
      - ./rtmp/stat:/usr/share/nginx/html/stat
    environment:
      - HTTP_PORT=80
      - RTMP_PORT=1935
    restart: unless-stopped

  nginx-proxy:
    image: nginx:alpine
    container_name: nginx-proxy
    ports:
      - "80:80"
    volumes:
      - ./nginx-proxy.conf:/etc/nginx/nginx.conf:ro
      - ./rtmp/data:/usr/share/nginx/html/hls:ro
    depends_on:
      - rtmp
    restart: unless-stopped
EOF

# Create RTMP configuration
print_status "Creating RTMP configuration..."
mkdir -p rtmp/conf
cat > rtmp/conf/rtmp.conf << 'EOF'
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
            hls_path /tmp/hls;
            hls_fragment 3;
            hls_playlist_length 60;
            
            # DASH configuration
            dash on;
            dash_path /tmp/hls;
            dash_fragment 3;
            dash_playlist_length 60;
            
            # SCTE-35 support
            on_publish http://host.docker.internal:3000/api/rtmp/on-publish;
            on_play http://host.docker.internal:3000/api/rtmp/on-play;
            on_publish_done http://host.docker.internal:3000/api/rtmp/on-publish-done;
            
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

http {
    server {
        listen 80;
        
        # HLS streaming
        location /hls {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /tmp;
            add_header Cache-Control no-cache;
            add_header 'Access-Control-Allow-Origin' '*' always;
        }
        
        # RTMP statistics
        location /stat {
            rtmp_stat all;
            rtmp_stat_stylesheet stat.xsl;
        }
        
        location /stat.xsl {
            root /etc/nginx;
        }
    }
}
EOF

# Create Nginx proxy configuration
print_status "Creating Nginx proxy configuration..."
cat > nginx-proxy.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    server {
        listen 80;
        server_name localhost;
        
        # Next.js application
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
        
        # HLS streaming (from RTMP container)
        location /hls {
            proxy_pass http://rtmp:80/hls;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # RTMP statistics
        location /stat {
            proxy_pass http://rtmp:80/stat;
            proxy_set_header Host $host;
        }
    }
}
EOF

# Create systemd service for Docker Compose
print_status "Creating systemd service..."
sudo tee /etc/systemd/system/rtmp-docker.service > /dev/null << 'EOF'
[Unit]
Description=RTMP Server Docker Compose
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/scte35-project
ExecStart=/usr/bin/docker compose -f docker-compose-rtmp.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose-rtmp.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable rtmp-docker.service
sudo systemctl start rtmp-docker.service

print_status "Docker RTMP setup completed!"
print_status "RTMP server is now running on port 1935"
print_status "HLS streams available at: http://localhost/hls"
print_status "RTMP stats available at: http://localhost/stat"