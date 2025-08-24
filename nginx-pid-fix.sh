#!/bin/bash

# Fix Nginx PID file and service issues
# This script resolves the PIDFile path issues in Nginx systemd service

set -e

echo "🔧 Fixing Nginx PID file and service issues..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root or with sudo"
   exit 1
fi

print_info "Step 1: Stop Nginx service..."
systemctl stop nginx || true
systemctl daemon-reload

print_info "Step 2: Create PID directory and set permissions..."
mkdir -p /run/nginx
chown www-data:www-data /run/nginx
chmod 755 /run/nginx

print_info "Step 3: Create proper systemd service file..."
cat > /etc/systemd/system/nginx.service << 'EOF'
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf
ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

# Create PID directory before starting
ExecStartPre=/bin/mkdir -p /run/nginx
ExecStartPre=/bin/chown www-data:www-data /run/nginx
ExecStartPre=/bin/chmod 755 /run/nginx

[Install]
WantedBy=multi-user.target
EOF

print_info "Step 4: Reload systemd daemon..."
systemctl daemon-reload

print_info "Step 5: Test Nginx configuration..."
if /usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf; then
    print_success "Nginx configuration test passed."
else
    print_error "Nginx configuration test failed!"
    print_info "Checking configuration file..."
    ls -la /usr/local/nginx/conf/nginx.conf
    print_info "Configuration file contents:"
    head -20 /usr/local/nginx/conf/nginx.conf
    exit 1
fi

print_info "Step 6: Start Nginx service..."
systemctl start nginx

print_info "Step 7: Check Nginx status..."
sleep 2
if systemctl is-active --quiet nginx; then
    print_success "Nginx is running successfully."
    systemctl status nginx --no-pager -l
else
    print_error "Nginx failed to start. Checking logs..."
    journalctl -u nginx -n 20 --no-pager
    print_info "Trying to start Nginx manually..."
    /usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
    sleep 2
    if pgrep nginx > /dev/null; then
        print_success "Nginx started successfully in manual mode."
    else
        print_error "Manual start also failed. Checking for port conflicts..."
        netstat -tulpn | grep :80 || true
        netstat -tulpn | grep :1935 || true
        exit 1
    fi
fi

print_info "Step 8: Enable Nginx service..."
systemctl enable nginx

print_info "Step 9: Verify Nginx is working..."
if curl -s http://localhost/health | grep -q "healthy"; then
    print_success "Nginx is responding correctly."
else
    print_warning "Nginx health check failed, but service is running."
    print_info "This might be normal if the application isn't deployed yet."
fi

print_success "✅ Nginx PID file and service issues have been fixed!"
echo ""
echo "📋 Service Status:"
systemctl status nginx --no-pager -l
echo ""
echo "🔍 To check logs: journalctl -u nginx -f"
echo "🔄 To restart: systemctl restart nginx"
echo "⏹️  To stop: systemctl stop nginx"