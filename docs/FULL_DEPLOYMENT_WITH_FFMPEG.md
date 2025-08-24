# Full Deployment with FFmpeg Integration

This guide provides comprehensive instructions for deploying the SCTE-35 Streaming Control Center with full FFmpeg integration, including the SuperKabuki FFmpeg patch for enhanced SCTE-35 support.

## 🎯 Overview

The full deployment includes:
- **System Dependencies**: Ubuntu 22.04 with all required packages
- **Node.js & PM2**: Application runtime and process management
- **Nginx with RTMP**: High-performance streaming server
- **SuperKabuki FFmpeg**: Enhanced FFmpeg with superior SCTE-35 support
- **Next.js Application**: SCTE-35 streaming control center
- **Database**: SQLite for configuration and metadata
- **Security**: Firewall and system hardening
- **Monitoring**: Automated monitoring and backup scripts
- **Enhanced Features**: Advanced error handling, logging, and system optimization

## 🚀 Quick Start

### 1. Run the Full Deployment Script

```bash
# Make the script executable
chmod +x deploy-full-with-ffmpeg.sh

# Run the deployment
./deploy-full-with-ffmpeg.sh
```

The script will:
- Update system packages
- Install Node.js 18.x and PM2
- Install SuperKabuki FFmpeg with SCTE-35 support
- Compile and configure Nginx with RTMP module
- Clone and set up the SCTE-35 streaming project
- Configure database and environment
- Deploy application with PM2
- Set up monitoring and backup scripts
- Perform comprehensive testing
- Provide detailed deployment reports and logs

### 2. Access Your Deployment

After deployment completes, access your streaming platform:

- **Web Interface**: http://your-server-ip
- **RTMP Server**: rtmp://your-server-ip:1935/live
- **HLS Streams**: http://your-server-ip/hls
- **DASH Streams**: http://your-server-ip/dash
- **RTMP Statistics**: http://your-server-ip/stat

## 🚀 Enhanced Deployment Features

### **Advanced Error Handling**
- **Comprehensive Error Detection**: Identifies issues at every deployment stage
- **Automatic Recovery**: Attempts to recover from non-critical errors
- **Critical Error Handling**: Stops deployment on unrecoverable errors with clear guidance
- **Rollback Capabilities**: Automatically backs up configuration files before changes

### **Enhanced Logging System**
- **Real-time Logging**: Logs all operations to both console and file
- **Structured Format**: Timestamped, categorized logs with severity levels
- **Performance Metrics**: Tracks deployment progress and resource usage
- **Debug Information**: Detailed command execution and output logging

### **System Optimization**
- **Resource Tuning**: Automatically optimizes system limits for streaming
- **Network Configuration**: Optimizes network stack for high-performance streaming
- **Memory Management**: Configures optimal memory settings for FFmpeg and Nginx
- **File Descriptor Limits**: Adjusts system limits for high concurrent connections

### **Progress Monitoring**
- **Visual Progress Indicators**: Real-time progress bars with ETA estimates
- **Stage Tracking**: Clear indication of current deployment stage
- **Success/Failure Reporting**: Immediate feedback on operation results
- **Performance Benchmarks**: Tracks time taken for each major operation

## 🔧 Manual Installation (Step-by-Step)

### Step 1: System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install basic tools
sudo apt install -y git curl wget htop vim net-tools build-essential python3-dev ufw fail2ban cmake yasm nasm
```

### Step 2: Install Node.js and PM2

```bash
# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2
sudo npm install -g pm2

# Verify installation
node --version
npm --version
```

### Step 3: Install SuperKabuki FFmpeg

```bash
# Install FFmpeg dependencies
sudo apt install -y \
    libx264-dev libx265-dev libmp3lame-dev libopus-dev libvpx-dev \
    libfdk-aac-dev libass-dev libfreetype6-dev libfontconfig1-dev \
    libxvidcore-dev libv4l-dev libpulse-dev libjack-jackd2-dev \
    libcdio-paranoia-dev librubberband-dev libsdl2-dev libopenjp2-7-dev \
    librtmp-dev libgnutls28-dev libbluray-dev libsoxr-dev libssh-dev \
    libvidstab-dev libzimg-dev libwebp-dev libopenal-dev libvmaf-dev \
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

# Download and compile FFmpeg
cd /tmp
git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
cd ffmpeg

# Configure with all features
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
    --prefix=/usr/local

# Build and install
make -j$(nproc)
sudo make install
sudo ldconfig

# Verify installation
ffmpeg -version
```

### Step 4: Install Nginx with RTMP

```bash
# Remove existing Nginx
sudo apt remove --purge -y nginx nginx-common nginx-full nginx-core || true
sudo apt autoremove -y

# Install build dependencies
sudo apt install -y build-essential libpcre3-dev libssl-dev zlib1g-dev

# Download and compile Nginx with RTMP
cd /tmp
wget https://nginx.org/download/nginx-1.25.3.tar.gz
tar -xzf nginx-1.25.3.tar.gz
cd nginx-1.25.3
git clone https://github.com/arut/nginx-rtmp-module.git

# Configure and compile
./configure \
    --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --user=www-data --group=www-data \
    --with-http_ssl_module --with-http_v2_module \
    --with-http_realip_module --with-http_addition_module \
    --with-http_sub_module --with-http_dav_module \
    --with-http_flv_module --with-http_mp4_module \
    --with-http_gunzip_module --with-http_gzip_static_module \
    --with-http_random_index_module --with-http_secure_link_module \
    --with-http_stub_status_module --with-http_auth_request_module \
    --with-threads --with-stream --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --add-dynamic-module=./nginx-rtmp-module

make -j$(nproc)
sudo make install

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

# Enable and start Nginx
sudo systemctl daemon-reload
sudo systemctl enable nginx
sudo systemctl start nginx
```

### Step 5: Setup Project

```bash
# Clone project
cd ~
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol

# Install dependencies
npm install

# Build application
npm run build

# Create environment file
cat > .env << EOF
NODE_ENV=production
PORT=3000
RTMP_PORT=1935
RTMP_HTTP_PORT=1936
NEXT_PUBLIC_APP_URL=http://your-server-ip
DATABASE_URL="file:./dev.db"
FFMPEG_PATH="/usr/local/bin/ffmpeg"
FFPROBE_PATH="/usr/local/bin/ffprobe"
EOF

# Setup database
npm run db:generate
npm run db:push
```

### Step 6: Configure Nginx

Create the Nginx configuration file at `/etc/nginx/nginx.conf` with the content from the deployment script, including:
- RTMP server configuration
- HTTP server configuration
- HLS/DASH streaming endpoints
- SCTE-35 webhook endpoints

### Step 7: Deploy with PM2

```bash
# Create PM2 ecosystem configuration
cat > ecosystem.config.js << EOF
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
    max_memory_restart: '1G'
  }]
};
EOF

# Start application
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

### Step 8: Configure Firewall

```bash
# Configure UFW
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 1935/tcp  # RTMP
sudo ufw allow 1936/tcp  # RTMP stats
sudo ufw --force enable
```

## 🎬 FFmpeg SCTE-35 Features

### Enhanced SCTE-35 Support

The SuperKabuki FFmpeg build includes:

- **SCTE-35 Preservation**: Maintains SCTE-35 markers during transcoding
- **Descriptor Support**: Full CUEI descriptor (0x49455543) implementation
- **Timestamp Accuracy**: Precise timestamp preservation with `-copyts`
- **Multi-format Support**: Works with MPEG-TS, HLS, and DASH

### FFmpeg Configuration

The deployment creates `/etc/ffmpeg/scte35.conf` with optimized settings:

```ini
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
```

### Usage Examples

#### 1. Transcode with SCTE-35 Preservation

```bash
ffmpeg -copyts -i input.ts -map 0 -c:v libx265 -c:a aac -c:d copy -muxpreload 0 -muxdelay 0 output.ts
```

#### 2. Stream Copy with SCTE-35

```bash
ffmpeg -copyts -ss 200 -i input.ts -map 0 -c copy -muxpreload 0 -muxdelay 0 output.ts
```

#### 3. Extract SCTE-35 Data

```bash
ffmpeg -i input.ts -map 0:d -f data -y output.bin
```

#### 4. Live Streaming with SCTE-35

```bash
ffmpeg -re -i input.mp4 -c:v libx264 -c:a aac -f flv rtmp://server:1935/live/stream
```

#### 5. Test SCTE-35 Functionality

```bash
test-ffmpeg-scte35.sh
```

## 🔍 Testing and Verification

### Test FFmpeg Installation

```bash
# Run the test script
test-ffmpeg-scte35.sh

# Check version
ffmpeg -version

# Test SCTE-35 demuxer
ffmpeg -h demuxer=mpegts | grep -i scte

# Test SCTE-35 muxer
ffmpeg -h muxer=mpegts | grep -i scte
```

### Test Streaming

```bash
# Test RTMP publishing
ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test

# Test HLS playback
curl http://localhost/hls/test.m3u8

# Test DASH playback
curl http://localhost/dash/test.mpd
```

### Test Web Application

```bash
# Check application status
pm2 status

# View logs
pm2 logs

# Test health endpoint
curl http://localhost/health
```

## 📊 Monitoring and Maintenance

### System Monitoring

```bash
# Run monitoring script
~/monitor.sh

# View monitoring logs
tail -f /var/log/monitoring.log

# Check system resources
htop
df -h
free -h
```

### Application Monitoring

```bash
# PM2 monitoring
pm2 monit

# View application logs
pm2 logs scte35-app

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

### Backup and Recovery

```bash
# Run backup
~/backup.sh

# List backups
ls -la ~/backups/

# Restore from backup
tar -xzf ~/backups/project_YYYYMMDD_HHMMSS.tar.gz -C /home/ubuntu/
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. FFmpeg Not Found

```bash
# Check if FFmpeg is installed
which ffmpeg
ffmpeg -version

# If not found, reinstall
sudo ldconfig
```

#### 2. Nginx Fails to Start

```bash
# Test configuration
sudo nginx -t

# Check logs
sudo journalctl -u nginx -n 50
sudo tail -f /var/log/nginx/error.log
```

#### 3. RTMP Streaming Issues

```bash
# Check RTMP port
sudo netstat -tlnp | grep 1935

# Test RTMP connection
telnet localhost 1935

# Check RTMP logs
sudo tail -f /var/log/nginx/rtmp_access.log
```

#### 4. Application Not Running

```bash
# Check PM2 status
pm2 status

# Restart application
pm2 restart scte35-app

# Check logs
pm2 logs scte35-app
```

### Performance Optimization

#### System Optimization

```bash
# Apply system optimizations
sudo sysctl -p

# Check current limits
ulimit -n
```

#### FFmpeg Optimization

```bash
# Test different encoding presets
ffmpeg -i input.mp4 -c:v libx264 -preset fast -c:a aac output.mp4

# Use hardware acceleration if available
ffmpeg -i input.mp4 -c:v h264_videotoolbox -c:a aac output.mp4
```

#### Nginx Optimization

```bash
# Test Nginx performance
sudo nginx -t
sudo systemctl reload nginx

# Monitor connections
sudo netstat -an | grep :80 | wc -l
```

## 📚 Advanced Configuration

### Custom FFmpeg Builds

To customize the FFmpeg build, modify the configuration options in the deployment script:

```bash
./configure \
    --enable-custom-feature \
    --disable-unused-feature \
    # ... other options
```

### Nginx Configuration

For advanced Nginx configuration, edit `/etc/nginx/nginx.conf`:

```nginx
# Add custom RTMP settings
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        application live {
            live on;
            record off;
            
            # Custom settings
            exec_push ffmpeg -i rtmp://localhost/live/$name \
                -c:v libx264 -c:a aac -f flv rtmp://localhost/hls/$name;
        }
    }
}
```

### Environment Variables

Customize the application behavior with environment variables:

```bash
# In .env file
NODE_ENV=production
PORT=3000
RTMP_PORT=1935
RTMP_HTTP_PORT=1936
NEXT_PUBLIC_APP_URL=http://your-server-ip
DATABASE_URL="file:./dev.db"
FFMPEG_PATH="/usr/local/bin/ffmpeg"
FFPROBE_PATH="/usr/local/bin/ffprobe"

# Custom settings
SCTE35_ENABLED=true
SCTE35_PID=500
HLS_FRAGMENT_DURATION=3
DASH_FRAGMENT_DURATION=3
```

## 🔒 Security Considerations

### System Security

```bash
# Update system regularly
sudo apt update && sudo apt upgrade -y

# Configure firewall properly
sudo ufw status
sudo ufw allow [specific-ip] 22/tcp

# Use fail2ban for intrusion prevention
sudo systemctl status fail2ban
```

### Application Security

```bash
# Use HTTPS in production
# Obtain SSL certificate (Let's Encrypt)
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com

# Secure RTMP with authentication
# Add to nginx.conf:
rtmp {
    server {
        listen 1935;
        application live {
            live on;
            on_publish http://localhost:3000/api/auth;
        }
    }
}
```

### Network Security

```bash
# Monitor network connections
sudo netstat -tlnp
sudo ss -tlnp

# Use VPN for remote access
# Configure VPN server on your network
```

## 📈 Performance Tuning

### System Performance

```bash
# Optimize file descriptors
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize network settings
sudo tee -a /etc/sysctl.conf << EOF
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF
sudo sysctl -p
```

### FFmpeg Performance

```bash
# Use appropriate presets
# ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
ffmpeg -i input.mp4 -c:v libx264 -preset fast -c:a aac output.mp4

# Use hardware acceleration
# Check available encoders
ffmpeg -encoders | grep -E "(h264|hevc)"
```

### Nginx Performance

```bash
# Optimize worker processes
# In nginx.conf:
worker_processes auto;
worker_connections 1024;

# Enable caching
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=my_cache:10m max_size=10g inactive=60m;
```

## 🚀 Deployment Automation

### CI/CD Pipeline

Create a GitHub Actions workflow for automated deployment:

```yaml
name: Deploy SCTE-35 Streaming Platform
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Deploy to server
      uses: appleboy/ssh-action@master
      with:
        host: ${{ secrets.SERVER_HOST }}
        username: ${{ secrets.SERVER_USER }}
        key: ${{ secrets.SERVER_KEY }}
        script: |
          cd ~/SCTE-streamcontrol
          git pull origin main
          npm install
          npm run build
          pm2 restart scte35-app
```

### Infrastructure as Code

Use Docker for containerized deployment:

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]
```

## 📞 Support and Resources

### Documentation

- [SCTE-35 Standards](https://www.scte.org/SCTE35/)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [Nginx RTMP Module](https://github.com/arut/nginx-rtmp-module)
- [Next.js Documentation](https://nextjs.org/docs)

### Community

- [GitHub Repository](https://github.com/shihan84/SCTE-streamcontrol)
- [FFmpeg Community](https://ffmpeg.org/community.html)
- [Nginx Community](https://www.nginx.com/resources/community/)

### Troubleshooting Resources

- [FFmpeg Bug Tracker](https://trac.ffmpeg.org/)
- [Nginx Wiki](https://www.nginx.com/resources/wiki/)
- [Stack Overflow](https://stackoverflow.com/)

---

This comprehensive deployment guide provides everything needed to deploy and maintain a professional SCTE-35 streaming platform with enhanced FFmpeg support. For additional assistance, refer to the project documentation or community resources.