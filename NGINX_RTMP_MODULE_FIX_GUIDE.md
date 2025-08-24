# Nginx RTMP Module Fix Guide

This guide provides comprehensive instructions for fixing the Nginx RTMP module issue in the SCTE-35 Streaming Control Center project.

## Problem Description

When deploying the SCTE-35 Streaming Control Center, you may encounter the following error:

```
nginx: [emerg] unknown directive "rtmp" in /etc/nginx/nginx.conf:11
nginx: configuration file /etc/nginx/nginx.conf test failed
```

This error occurs because the standard Nginx installation doesn't include the RTMP module. The RTMP module is required for streaming functionality in the SCTE-35 Streaming Control Center.

## Solution Overview

The solution involves compiling Nginx from source with the RTMP module included. This ensures full compatibility with the SCTE-35 streaming requirements.

## Quick Fix Script

We've created a comprehensive script that automates the entire process:

```bash
# Make the script executable
sudo chmod +x nginx-rtmp-module-fix.sh

# Run the script
sudo ./nginx-rtmp-module-fix.sh
```

## Manual Installation Steps

If you prefer to install manually, follow these steps:

### 1. Install Build Dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    libpcre3-dev \
    libssl-dev \
    zlib1g-dev \
    wget \
    git \
    unzip
```

### 2. Download and Compile Nginx with RTMP Module

```bash
# Create working directory
mkdir -p /tmp/nginx-rtmp-build
cd /tmp/nginx-rtmp-build

# Download Nginx source
NGINX_VERSION="1.25.3"
wget "https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz"
tar -xzf "nginx-$NGINX_VERSION.tar.gz"
cd "nginx-$NGINX_VERSION"

# Download RTMP module
git clone https://github.com/arut/nginx-rtmp-module.git

# Create Nginx user
sudo useradd -r -s /bin/false nginx

# Configure Nginx with RTMP module
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
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-stream_realip_module \
    --with-stream_geoip_module=dynamic \
    --add-dynamic-module=./nginx-rtmp-module

# Compile and install
make -j$(nproc)
sudo make install
```

### 3. Create Systemd Service

```bash
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
```

### 4. Create Directories and Set Permissions

```bash
sudo mkdir -p /etc/nginx/conf.d
sudo mkdir -p /var/log/nginx
sudo mkdir -p /var/www/html
sudo chown -R nginx:nginx /var/log/nginx
sudo chown -R nginx:nginx /var/www/html
```

### 5. Create Nginx Configuration

```bash
sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user nginx;
worker_processes auto;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    error_log   /var/log/nginx/error.log;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    types_hash_max_size 2048;

    include /etc/nginx/conf.d/*.conf;
}

# RTMP Configuration
rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        application live {
            live on;
            record off;
            
            # SCTE-35 support
            on_play http://localhost:3000/api/scte-35/on-play;
            on_publish http://localhost:3000/api/scte-35/on-publish;
            on_done http://localhost:3000/api/scte-35/on-done;
        }
    }
}
EOF
```

### 6. Create Default Site Configuration

```bash
sudo tee /etc/nginx/conf.d/default.conf > /dev/null << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /stat {
        rtmp_stat all;
        rtmp_stat_stylesheet stat.xsl;
    }

    location /stat.xsl {
        root /etc/nginx/;
    }

    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /var/www/html;
    }
}
EOF
```

### 7. Start Nginx

```bash
sudo systemctl daemon-reload
sudo systemctl enable nginx
sudo systemctl start nginx
```

### 8. Test Configuration

```bash
sudo /usr/sbin/nginx -t
sudo systemctl status nginx
```

## Verification

After installation, verify that everything is working:

### 1. Check Nginx Status

```bash
sudo systemctl status nginx
```

### 2. Test RTMP Module

```bash
sudo /usr/sbin/nginx -t 2>&1 | grep rtmp
```

### 3. Test RTMP Streaming

```bash
# Test with ffmpeg (install if needed)
sudo apt-get install -y ffmpeg

# Create a test stream
ffmpeg -re -i /dev/zero -c:v libx264 -t 10 -f flv rtmp://localhost:1935/live/test
```

### 4. Check RTMP Statistics

Open your browser and navigate to:
```
http://your-server-ip/stat
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   sudo chown -R nginx:nginx /var/log/nginx
   sudo chown -R nginx:nginx /var/www/html
   ```

2. **Port Already in Use**
   ```bash
   sudo netstat -tulpn | grep :1935
   sudo kill -9 <PID>
   ```

3. **Configuration Test Fails**
   ```bash
   sudo /usr/sbin/nginx -t
   # Check error logs
   sudo tail -f /var/log/nginx/error.log
   ```

### Log Files

- Nginx Error Log: `/var/log/nginx/error.log`
- Nginx Access Log: `/var/log/nginx/access.log`
- Systemd Journal: `journalctl -u nginx -f`

## Integration with SCTE-35 Streaming Control Center

Once Nginx with RTMP module is installed, your SCTE-35 Streaming Control Center can:

1. **Stream Management**: Create and manage live streams
2. **SCTE-35 Cue Insertion**: Insert SCTE-35 cues into streams
3. **Ad Break Management**: Control ad insertion timing
4. **Stream Monitoring**: Monitor stream health and statistics

## Next Steps

1. **Deploy SCTE-35 Application**: Use the deployment scripts provided in the project
2. **Configure SCTE-35 Endpoints**: Update the RTMP configuration with your actual endpoints
3. **Test SCTE-35 Functionality**: Verify cue insertion and ad break management
4. **Monitor Performance**: Use the RTMP statistics page for monitoring

## Support

For additional support, please refer to the project documentation or contact Morus Broadcasting Pvt Ltd support.

---

© 2024 Morus Broadcasting Pvt Ltd. All rights reserved.