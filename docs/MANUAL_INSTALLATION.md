# SCTE-35 Streaming Control Center - Manual Installation Guide

This guide provides detailed step-by-step instructions for manually installing the SCTE-35 Streaming Control Center on Ubuntu/Debian systems. This manual approach gives you full control over the installation process and helps troubleshoot any issues that may arise.

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ or Debian 10+
- **CPU**: 2 cores (4 cores recommended)
- **RAM**: 4GB (8GB recommended)
- **Storage**: 25GB SSD (50GB recommended)
- **Network**: 10 Mbps upload bandwidth

### Required Permissions
- **sudo access** for system package installation
- **internet connection** for downloading dependencies
- **basic command line knowledge**

## 🚀 Quick Start - Automated Manual Installation

For the easiest manual installation experience, use the provided automated manual installation script:

```bash
# Clone the repository
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol

# Run the manual installation script
chmod +x manual-installation.sh
./manual-installation.sh
```

This script will guide you through each step with detailed explanations and error recovery options.

## 📖 Detailed Manual Installation Steps

### Step 1: System Preparation

#### 1.1 Update System Packages
```bash
# Update package lists
sudo apt update

# Upgrade system packages
sudo apt upgrade -y

# Install basic tools
sudo apt install -y curl wget git
```

#### 1.2 Verify System Requirements
```bash
# Check OS version
cat /etc/os-release

# Check available memory
free -h

# Check available disk space
df -h

# Check CPU cores
nproc
```

### Step 2: Install Node.js and npm

#### 2.1 Add Node.js Repository
```bash
# Add Node.js 18.x repository
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
```

#### 2.2 Install Node.js
```bash
# Install Node.js
sudo apt install -y nodejs

# Verify installation
node --version
npm --version
```

#### 2.3 Install PM2
```bash
# Install PM2 globally
sudo npm install -g pm2

# Verify PM2 installation
pm2 --version
```

### Step 3: Install Build Dependencies

```bash
# Install build tools and development libraries
sudo apt install -y \
    build-essential cmake make gcc g++ pkg-config \
    libtool automake autoconf nasm yasm
```

### Step 4: Install FFmpeg Dependencies

#### 4.1 Install FFmpeg Development Libraries
```bash
# Install FFmpeg dependencies (this may take a while)
sudo apt install -y \
    libx264-dev libx265-dev libmp3lame-dev libopus-dev libvpx-dev \
    libfdk-aac-dev libass-dev libfreetype6-dev libfontconfig1-dev \
    libxvidcore-dev libv4l-dev libpulse-dev libjack-jackd2-dev \
    libcdio-paranoia-dev librubberband-dev libsdl2-dev libopenjp2-7-dev \
    librtmp-dev libgnutls28-dev libbluray-dev libsoxr-dev libssh-dev \
    libvidstab-dev libzimg-dev libwebp-dev libopenal-dev \
    libgl1-mesa-dev libgles2-mesa-dev libva-dev libdrm-dev libxcb1-dev \
    libxcb-shm0-dev libxcb-xfixes0-dev libxcb-shape0-dev libx11-dev \
    libxfixes-dev libxext-dev libxrandr-dev libvdpau-dev libvulkan-dev \
    libharfbuzz-dev libfribidi-dev liblzma-dev libzvbi-dev \
    libcdio-cdda-dev libcdio-paranoia-dev libmodplug-dev libgme-dev \
    libopenmpt-dev libshine-dev libsnappy-dev libspeex-dev libtheora-dev \
    libtwolame-dev libvo-amrwbenc-dev libwavpack-dev libwebp-dev \
    libzmq3-dev libzvbi-dev ladspa-sdk libmysofa-dev libgsm1-dev \
    libdc1394-22-dev libchromaprint-dev libbs2b-dev libcaca-dev \
    libflite1-dev libfluidsynth-dev libgme-dev libinstpatch-dev \
    liblilv-dev liblv2-dev libserd-dev libsord-dev libsratom-dev \
    libsamplerate-dev librubberband-dev libsrt-dev libsvtav1-dev \
    libtesseract-dev libx265-dev libxvidcore-dev libzmq5-dev libzvbi-dev
```

#### 4.2 Optional: Install VMAF (Video Quality Assessment)
```bash
# VMAF is optional for video quality assessment
# If this fails, continue without it - it's not critical for SCTE-35
sudo apt install -y libvmaf-dev || echo "VMAF installation failed - continuing without it"
```

### Step 5: Compile and Install FFmpeg

#### 5.1 Download FFmpeg Source
```bash
# Create build directory
mkdir -p /tmp/ffmpeg-build
cd /tmp/ffmpeg-build

# Download FFmpeg source code
git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
cd ffmpeg
```

#### 5.2 Configure FFmpeg
```bash
# Configure FFmpeg with SCTE-35 support
./configure \
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
    --extra-version=-SCTE35-Enhanced --prefix=/usr/local
```

#### 5.3 Build and Install FFmpeg
```bash
# Build FFmpeg (this will take 30+ minutes)
make -j$(nproc)

# Install FFmpeg
sudo make install

# Update shared library cache
sudo ldconfig

# Verify installation
ffmpeg -version
```

### Step 6: Install Nginx with RTMP Module

#### 6.1 Install Nginx Dependencies
```bash
# Install Nginx dependencies
sudo apt install -y \
    libpcre3 libpcre3-dev libssl-dev zlib1g-dev
```

#### 6.2 Download Nginx and RTMP Module
```bash
# Create build directory
mkdir -p /tmp/nginx-build
cd /tmp/nginx-build

# Download Nginx source
wget http://nginx.org/download/nginx-1.25.3.tar.gz
tar -xzf nginx-1.25.3.tar.gz

# Download RTMP module
git clone https://github.com/arut/nginx-rtmp-module.git
```

#### 6.3 Compile and Install Nginx
```bash
# Navigate to Nginx source directory
cd nginx-1.25.3

# Configure Nginx with RTMP module
./configure \
    --add-module=../nginx-rtmp-module \
    --prefix=/etc/nginx \
    --with-http_ssl_module \
    --with-http_v2_module

# Build Nginx
make

# Install Nginx
sudo make install
```

#### 6.4 Create Nginx User and Directories
```bash
# Create nginx user
sudo useradd -r -s /bin/false nginx

# Create RTMP directories
sudo mkdir -p /var/www/rtmp/hls /var/www/rtmp/dash

# Set permissions
sudo chown -R nginx:nginx /var/www/rtmp
```

### Step 7: Configure Nginx

#### 7.1 Create Nginx Configuration
```bash
# Backup existing configuration (if any)
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup 2>/dev/null || true

# Create new configuration
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
```

#### 7.2 Test Nginx Configuration
```bash
# Test Nginx configuration
sudo nginx -t

# If test passes, start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### Step 8: Setup SCTE-35 Streaming Project

#### 8.1 Clone the Repository
```bash
# Navigate to home directory
cd ~

# Clone the repository
git clone https://github.com/shihan84/SCTE-streamcontrol.git

# Navigate to project directory
cd SCTE-streamcontrol
```

#### 8.2 Install Node.js Dependencies
```bash
# Install project dependencies
npm install
```

#### 8.3 Setup Database
```bash
# Setup database
npm run db:push
```

### Step 9: Create FFmpeg Configuration

#### 9.1 Create FFmpeg Configuration Directory
```bash
# Create FFmpeg configuration directory
sudo mkdir -p /etc/ffmpeg
```

#### 9.2 Create SCTE-35 Configuration
```bash
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
```

#### 9.3 Create FFmpeg Test Script
```bash
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

# Make script executable
sudo chmod +x /usr/local/bin/test-ffmpeg-scte35.sh
```

### Step 10: Deploy Application with PM2

#### 10.1 Create PM2 Configuration
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
      PORT: 3000,
      RTMP_PORT: 1935,
      RTMP_HTTP_PORT: 1936,
      NEXT_PUBLIC_APP_URL: 'http://YOUR_SERVER_IP',
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

# Replace YOUR_SERVER_IP with actual IP
sed -i "s/YOUR_SERVER_IP/$(hostname -I | awk '{print $1}')/g" ecosystem.config.js
```

#### 10.2 Setup PM2
```bash
# Create PM2 log directory
sudo mkdir -p /var/log/pm2
sudo chown ubuntu:ubuntu /var/log/pm2

# Stop existing application if running
pm2 stop scte35-app 2>/dev/null || true
pm2 delete scte35-app 2>/dev/null || true

# Start application
pm2 start ecosystem.config.js

# Setup PM2 startup
pm2 startup

# Save PM2 configuration
pm2 save
```

### Step 11: Final Testing and Verification

#### 11.1 Test Application Health
```bash
# Test application health endpoint
curl http://localhost:3000/health

# Test web interface
curl http://localhost/
```

#### 11.2 Test FFmpeg
```bash
# Test FFmpeg installation
ffmpeg -version

# Run FFmpeg SCTE-35 test script
test-ffmpeg-scte35.sh
```

#### 11.3 Test Nginx
```bash
# Test Nginx configuration
sudo nginx -t

# Test Nginx status
sudo systemctl status nginx

# Test HTTP endpoints
curl http://localhost/health
curl http://localhost/stat
```

#### 11.4 Test Streaming
```bash
# Test RTMP publishing (you'll need a test video file)
# ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test

# Test HLS stream
# curl -I http://localhost/hls/test.m3u8

# Test DASH stream
# curl -I http://localhost/dash/test.mpd
```

### Step 12: Clean Up

```bash
# Clean up temporary build files
rm -rf /tmp/ffmpeg-build /tmp/nginx-build

# Clean up package cache
sudo apt-get clean
sudo apt-get autoremove -y
```

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. FFmpeg Compilation Fails
**Problem**: FFmpeg fails to compile during make
**Solution**:
```bash
# Check available memory
free -h

# If memory is low, try building with fewer jobs
make -j1

# Check for missing dependencies
sudo apt install -y build-essential
```

#### 2. Nginx Configuration Test Fails
**Problem**: `nginx -t` fails with configuration errors
**Solution**:
```bash
# Check Nginx error log
sudo tail -f /var/log/nginx/error.log

# Review configuration syntax
sudo nginx -t

# Fix configuration issues and test again
```

#### 3. PM2 Application Won't Start
**Problem**: Application fails to start with PM2
**Solution**:
```bash
# Check PM2 logs
pm2 logs

# Check application status
pm2 status

# Restart application
pm2 restart scte35-app

# Check system logs
journalctl -u pm2
```

#### 4. Port Already in Use
**Problem**: Ports 3000, 1935, or 80 are already in use
**Solution**:
```bash
# Check port usage
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :1935
sudo netstat -tulpn | grep :80

# Kill processes using ports
sudo kill -9 <PID>

# Or change ports in configuration files
```

#### 5. Permission Denied Errors
**Problem**: Permission denied errors during installation
**Solution**:
```bash
# Ensure proper permissions
sudo chown -R ubuntu:ubuntu /home/ubuntu/SCTE-streamcontrol
sudo chown -R ubuntu:ubuntu /var/log/pm2

# Check file permissions
ls -la /var/log/pm2/
ls -la /home/ubuntu/SCTE-streamcontrol/
```

### Verification Commands

Use these commands to verify your installation:

```bash
# Check all services status
pm2 status
sudo systemctl status nginx

# Check all listening ports
sudo netstat -tulpn

# Test all endpoints
curl http://localhost/health
curl http://localhost/stat
curl http://localhost/

# Test FFmpeg functionality
ffmpeg -version
test-ffmpeg-scte35.sh

# Check log files
pm2 logs
sudo tail -f /var/log/nginx/error.log
```

## 🌐 Access URLs After Installation

Once installation is complete, your streaming server will be available at:

| Service | URL | Description |
|---------|-----|-------------|
| **Main Application** | `http://your-server-ip/` | Web control interface |
| **Health Check** | `http://your-server-ip/health` | System health status |
| **RTMP Statistics** | `http://your-server-ip/stat` | Live streaming stats |
| **RTMP Publish** | `rtmp://your-server-ip:1935/live/stream-key` | Stream publishing endpoint |
| **HLS Stream** | `http://your-server-ip/hls/stream-key.m3u8` | HTTP Live Streaming |
| **DASH Stream** | `http://your-server-ip/dash/stream-key.mpd` | DASH Adaptive Streaming |

## 🛠️ Management Commands

### Application Management
```bash
pm2 list                    # List all processes
pm2 logs                    # View application logs
pm2 monit                   # Monitor in real-time
pm2 restart scte35-app      # Restart application
pm2 stop scte35-app         # Stop application
pm2 reload scte35-app       # Reload application
```

### System Management
```bash
sudo systemctl status nginx    # Check Nginx status
sudo systemctl restart nginx   # Restart Nginx
sudo nginx -t                  # Test Nginx configuration
sudo tail -f /var/log/nginx/error.log  # View Nginx error logs
```

### FFmpeg Testing
```bash
test-ffmpeg-scte35.sh         # Test FFmpeg SCTE-35 functionality
ffmpeg -version               # Check FFmpeg version
ffmpeg -encoders              # List available encoders
```

### Database Operations
```bash
npm run db:push               # Push database schema
npm run db:generate           # Generate Prisma client
npm run db:migrate            # Run database migrations
```

## 📚 Additional Resources

### Documentation
- **Main README**: `./README.md`
- **Automated Deployment**: `./deploy-full-with-ffmpeg.sh`
- **Verification Script**: `./verify-deployment.sh`
- **Update Script**: `./update-from-github.sh`

### Configuration Files
- **Nginx Configuration**: `/etc/nginx/nginx.conf`
- **FFmpeg Configuration**: `/etc/ffmpeg/scte35.conf`
- **PM2 Configuration**: `./ecosystem.config.js`

### Log Files
- **Application Logs**: `/var/log/pm2/`
- **Nginx Logs**: `/var/log/nginx/`
- **RTMP Logs**: `/var/log/nginx/rtmp_access.log`
- **System Logs**: `/var/log/syslog`

## 🎯 Next Steps After Installation

1. **Access Web Interface**: Open `http://your-server-ip` in your browser
2. **Test Streaming**: Use FFmpeg to publish a test stream
3. **Verify SCTE-35**: Test SCTE-35 event injection
4. **Configure Monitoring**: Set up system monitoring
5. **Setup Backups**: Configure automated backups
6. **Security Hardening**: Implement security best practices

## 🤝 Getting Help

If you encounter issues during manual installation:

1. **Check Logs**: Review all log files for error messages
2. **Verify Dependencies**: Ensure all required packages are installed
3. **Test Components**: Test each component individually
4. **Check Ports**: Verify no port conflicts exist
5. **Permissions**: Ensure proper file and directory permissions

For additional support, refer to the main project documentation or create an issue on the GitHub repository.

---

**© 2024 Morus Broadcasting Pvt Ltd. All rights reserved.**