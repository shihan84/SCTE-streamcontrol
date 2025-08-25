# Nginx RTMP Module - Manual Installation Guide

This guide provides detailed instructions for manually installing Nginx with the RTMP module, which is essential for the SCTE-35 Streaming Control Center.

## 🎯 Why Manual Installation for Nginx RTMP?

The RTMP module is not included in the standard Nginx packages and requires compilation from source. This manual installation gives you:

- **Full Control**: Complete control over compilation options
- **Latest Features**: Access to the latest RTMP module features
- **Custom Configuration**: Ability to customize Nginx build
- **Better Performance**: Optimized build for your specific system
- **Troubleshooting**: Better understanding of the installation process

## 📋 System Requirements

- **OS**: Ubuntu 20.04+ or Debian 10+
- **RAM**: 2GB minimum (4GB recommended)
- **Storage**: 1GB for compilation
- **Tools**: Basic development tools (gcc, make, etc.)

## 🛠️ Installation Steps

### Step 1: Install Dependencies

```bash
# Update package lists
sudo apt update

# Install build tools and development libraries
sudo apt install -y \
    build-essential \
    cmake \
    make \
    gcc \
    g++ \
    pkg-config \
    libtool \
    automake \
    autoconf \
    libpcre3 \
    libpcre3-dev \
    libssl-dev \
    zlib1g-dev \
    libgd-dev \
    libgeoip-dev \
    libxslt1-dev \
    libgdal-dev
```

### Step 2: Download Nginx Source Code

```bash
# Create working directory
mkdir -p ~/nginx-build
cd ~/nginx-build

# Download Nginx source code
wget http://nginx.org/download/nginx-1.25.3.tar.gz

# Extract the source code
tar -xzf nginx-1.25.3.tar.gz

# Download RTMP module
git clone https://github.com/arut/nginx-rtmp-module.git
```

### Step 3: Configure Nginx with RTMP Module

```bash
# Navigate to Nginx source directory
cd nginx-1.25.3

# Configure Nginx with RTMP module and other useful modules
./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --user=nginx \
    --group=nginx \
    --build=Ubuntu \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
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
    --with-http_xslt_module=dynamic \
    --with-http_image_filter_module=dynamic \
    --with-http_geoip_module=dynamic \
    --with-threads \
    --with-file-aio \
    --with-http_slice_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream_realip_module \
    --with-stream_ssl_preread_module \
    --add-module=../nginx-rtmp-module \
    --with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2' \
    --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now'
```

### Step 4: Compile and Install Nginx

```bash
# Compile Nginx (this may take 10-20 minutes)
make -j$(nproc)

# Install Nginx
sudo make install
```

### Step 5: Create Nginx User and Directories

```bash
# Create nginx user
sudo useradd -r -s /bin/false nginx

# Create required directories
sudo mkdir -p /var/www/rtmp/hls
sudo mkdir -p /var/www/rtmp/dash
sudo mkdir -p /var/cache/nginx/client_temp
sudo mkdir -p /var/log/nginx

# Set proper permissions
sudo chown -R nginx:nginx /var/www/rtmp
sudo chown -R nginx:nginx /var/cache/nginx
sudo chown -R nginx:nginx /var/log/nginx
```

### Step 6: Create Systemd Service File

```bash
# Create systemd service file
sudo tee /etc/systemd/system/nginx.service > /dev/null << 'EOF'
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -HUP $MAINPID
TimeoutStopSec=5
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
sudo systemctl daemon-reload

# Enable nginx service
sudo systemctl enable nginx
```

## 📁 Installation Folders and Locations

### Primary Installation Locations

| Component | Location | Description |
|-----------|----------|-------------|
| **Nginx Binary** | `/usr/sbin/nginx` | Main Nginx executable |
| **Configuration** | `/etc/nginx/nginx.conf` | Main configuration file |
| **Modules** | `/usr/lib/nginx/modules/` | Nginx modules including RTMP |
| **HTML Root** | `/var/www/rtmp/` | Root directory for web content |
| **HLS Directory** | `/var/www/rtmp/hls/` | HLS stream files |
| **DASH Directory** | `/var/www/rtmp/dash/` | DASH stream files |
| **Log Files** | `/var/log/nginx/` | Nginx log files |
| **PID File** | `/var/run/nginx.pid` | Process ID file |
| **Cache Directory** | `/var/cache/nginx/` | Cache files |

### Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| **Main Config** | `/etc/nginx/nginx.conf` | Main Nginx configuration |
| **MIME Types** | `/etc/nginx/mime.types` | MIME type mappings |
| **FastCGI Params** | `/etc/nginx/fastcgi_params` | FastCGI parameters |
| **Scgi Params** | `/etc/nginx/scgi_params` | SCGI parameters |
| **UWSGI Params** | `/etc/nginx/uwsgi_params` | UWSGI parameters |

### Source and Build Files

| Component | Location | Description |
|-----------|----------|-------------|
| **Source Code** | `~/nginx-build/nginx-1.25.3/` | Nginx source code |
| **RTMP Module** | `~/nginx-build/nginx-rtmp-module/` | RTMP module source |
| **Object Files** | `~/nginx-build/nginx-1.25.3/objs/` | Compiled object files |

## ⚙️ Configuration for SCTE-35 Streaming

### Basic Nginx Configuration with RTMP

```bash
# Create backup of existing config
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup

# Create new configuration with RTMP support
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
            root /home/ubuntu/nginx-build/nginx-rtmp-module;
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

## 🔧 Management Commands

### Service Management

```bash
# Start Nginx
sudo systemctl start nginx

# Stop Nginx
sudo systemctl stop nginx

# Restart Nginx
sudo systemctl restart nginx

# Check Nginx status
sudo systemctl status nginx

# Enable Nginx on boot
sudo systemctl enable nginx

# Disable Nginx on boot
sudo systemctl disable nginx
```

### Configuration Testing

```bash
# Test Nginx configuration
sudo nginx -t

# Test configuration and show modules
sudo nginx -V

# Check RTMP module is loaded
sudo nginx -V 2>&1 | grep rtmp
```

### Log Management

```bash
# View Nginx error log
sudo tail -f /var/log/nginx/error.log

# View Nginx access log
sudo tail -f /var/log/nginx/access.log

# View RTMP access log
sudo tail -f /var/log/nginx/rtmp_access.log

# Rotate logs
sudo logrotate -f /etc/logrotate.d/nginx
```

### Process Management

```bash
# Check Nginx process
ps aux | grep nginx

# Check Nginx master process
pgrep -f "nginx: master process"

# Check Nginx worker processes
pgrep -f "nginx: worker process"

# Reload Nginx configuration
sudo nginx -s reload

# Reopen log files
sudo nginx -s reopen
```

## 🔍 Verification and Testing

### Test Nginx Installation

```bash
# Check Nginx version
nginx -v

# Check Nginx modules
nginx -V

# Test configuration
sudo nginx -t

# Check if Nginx is running
sudo systemctl status nginx

# Check Nginx process
ps aux | grep nginx
```

### Test RTMP Module

```bash
# Check if RTMP module is loaded
nginx -V 2>&1 | grep rtmp

# Test RTMP port (1935)
sudo netstat -tulpn | grep :1935

# Test RTMP statistics port (1936)
sudo netstat -tulpn | grep :1936

# Test HTTP port (80)
sudo netstat -tulpn | grep :80
```

### Test Web Interface

```bash
# Test HTTP server
curl http://localhost/

# Test health endpoint
curl http://localhost/health

# Test RTMP statistics
curl http://localhost/stat

# Test HLS directory
curl -I http://localhost/hls/

# Test DASH directory
curl -I http://localhost/dash/
```

## 🚨 Troubleshooting

### Common Issues and Solutions

#### 1. Nginx Won't Start
```bash
# Check error logs
sudo tail -f /var/log/nginx/error.log

# Test configuration
sudo nginx -t

# Check if port is available
sudo netstat -tulpn | grep :80

# Check permissions
sudo ls -la /var/log/nginx/
sudo ls -la /var/www/rtmp/
```

#### 2. RTMP Module Not Loaded
```bash
# Check if RTMP module was compiled
nginx -V 2>&1 | grep rtmp

# If not found, recompile with RTMP module
cd ~/nginx-build/nginx-1.25.3
make clean
./configure --add-module=../nginx-rtmp-module [other options]
make
sudo make install
```

#### 3. Port Already in Use
```bash
# Check what's using the port
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :1935
sudo netstat -tulpn | grep :1936

# Kill the process using the port
sudo kill -9 <PID>

# Or change ports in configuration
```

#### 4. Permission Denied Errors
```bash
# Check file permissions
sudo ls -la /usr/sbin/nginx
sudo ls -la /etc/nginx/
sudo ls -la /var/www/rtmp/
sudo ls -la /var/log/nginx/

# Fix permissions
sudo chown -R nginx:nginx /var/www/rtmp
sudo chown -R nginx:nginx /var/log/nginx
sudo chmod +x /usr/sbin/nginx
```

#### 5. Configuration Syntax Errors
```bash
# Test configuration
sudo nginx -t

# Check syntax errors
sudo nginx -t 2>&1

# Fix configuration file
sudo nano /etc/nginx/nginx.conf
```

### Log File Locations

| Log Type | Location | Description |
|----------|----------|-------------|
| **Error Log** | `/var/log/nginx/error.log` | Nginx error messages |
| **Access Log** | `/var/log/nginx/access.log` | HTTP access requests |
| **RTMP Log** | `/var/log/nginx/rtmp_access.log` | RTMP streaming access |
| **System Log** | `/var/log/syslog` | System-level messages |
| **Auth Log** | `/var/log/auth.log` | Authentication messages |

## 📊 Performance Optimization

### Worker Process Configuration

```bash
# Optimize worker processes based on CPU cores
worker_processes auto;  # Sets to number of CPU cores

# Or set manually
worker_processes 4;  # For 4 CPU cores

# Set worker connections
events {
    worker_connections 1024;
    multi_accept on;
}
```

### Buffer Optimization

```bash
# Add to http block in nginx.conf
http {
    client_body_buffer_size 10K;
    client_header_buffer_size 1k;
    client_max_body_size 8m;
    large_client_header_buffers 4 4k;
    output_buffers 1 32k;
    postpone_output 1460;
}
```

### RTMP Optimization

```bash
# Add to rtmp block in nginx.conf
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        buflen 5ms;
        sync 10ms;
        max_streams 64;
        max_connections 1000;
        drop_idle_publisher 30s;
        
        application live {
            live on;
            record off;
            wait_key on;
            wait_video on;
            
            # HLS optimization
            hls on;
            hls_fragment 3;
            hls_playlist_length 60;
            hls_sync 2ms;
            hls_continuous on;
            hls_cleanup on;
            hls_nested on;
            
            # DASH optimization
            dash on;
            dash_fragment 3;
            dash_playlist_length 60;
            dash_cleanup on;
        }
    }
}
```

## 🔄 Updates and Maintenance

### Update Nginx

```bash
# Download new version
cd ~/nginx-build
wget http://nginx.org/download/nginx-1.25.4.tar.gz
tar -xzf nginx-1.25.4.tar.gz
cd nginx-1.25.4

# Configure with same options as before
./configure [same options as before]

# Compile and install
make
sudo make install

# Restart Nginx
sudo systemctl restart nginx
```

### Update RTMP Module

```bash
# Update RTMP module
cd ~/nginx-build/nginx-rtmp-module
git pull origin master

# Recompile Nginx
cd ../nginx-1.25.3
make clean
./configure --add-module=../nginx-rtmp-module [other options]
make
sudo make install

# Restart Nginx
sudo systemctl restart nginx
```

## 🎯 Integration with SCTE-35 Streaming Control Center

### After installing Nginx with RTMP, integrate with the main application:

```bash
# Navigate to project directory
cd /home/ubuntu/SCTE-streamcontrol

# Update application configuration
# The application should automatically detect Nginx RTMP

# Test integration
./verify-deployment.sh

# Test streaming
ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test

# Access streams
curl http://localhost/hls/test.m3u8
curl http://localhost/dash/test.mpd
```

### Configuration File Locations for Integration

| Component | Location | Used By |
|-----------|----------|----------|
| **Nginx Config** | `/etc/nginx/nginx.conf` | Application proxy, RTMP, HLS, DASH |
| **RTMP Config** | Embedded in nginx.conf | RTMP server and streaming |
| **Web Root** | `/var/www/rtmp/` | HLS and DASH stream files |
| **Log Files** | `/var/log/nginx/` | Application monitoring and debugging |

## 📚 Additional Resources

### Documentation
- **Nginx Documentation**: https://nginx.org/en/docs/
- **RTMP Module Documentation**: https://github.com/arut/nginx-rtmp-module
- **SCTE-35 Streaming Guide**: `docs/MANUAL_INSTALLATION.md`
- **Main Application README**: `README.md`

### Community Support
- **Nginx Forums**: https://forum.nginx.org/
- **RTMP Module Issues**: https://github.com/arut/nginx-rtmp-module/issues
- **SCTE-35 Streaming**: https://github.com/shihan84/SCTE-streamcontrol/issues

### Tools and Utilities
- **Nginx Config Tester**: `sudo nginx -t`
- **RTMP Statistics**: http://localhost:1936/stat
- **Stream Testing**: FFmpeg, VLC, OBS Studio
- **Log Analysis**: `grep`, `awk`, `sed`

---

**© 2024 Morus Broadcasting Pvt Ltd. All rights reserved.**