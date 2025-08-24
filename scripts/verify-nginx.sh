#!/bin/bash

# Verify Nginx Setup for Manual Installation
# This script verifies that the manually compiled Nginx is working correctly

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

echo -e "${GREEN}Nginx Setup Verification${NC}"
echo "==========================="

# Check nginx binary
print_status "Checking Nginx binary..."
if [ -f "/usr/local/nginx/sbin/nginx" ]; then
    print_status "Nginx binary found at: /usr/local/nginx/sbin/nginx"
    
    # Check nginx version
    print_status "Nginx version:"
    /usr/local/nginx/sbin/nginx -V 2>&1 | head -1
else
    print_error "Nginx binary not found at: /usr/local/nginx/sbin/nginx"
    exit 1
fi

# Check nginx configuration directory
print_status "Checking Nginx configuration..."
if [ -d "/usr/local/nginx/conf" ]; then
    print_status "Nginx configuration directory found"
    
    # Check main config file
    if [ -f "/usr/local/nginx/conf/nginx.conf" ]; then
        print_status "Main nginx.conf found"
    else
        print_error "Main nginx.conf not found"
        exit 1
    fi
else
    print_error "Nginx configuration directory not found"
    exit 1
fi

# Check nginx logs directory
print_status "Checking Nginx logs..."
if [ -d "/usr/local/nginx/logs" ]; then
    print_status "Nginx logs directory found"
else
    print_warning "Nginx logs directory not found, creating..."
    sudo mkdir -p /usr/local/nginx/logs
    sudo chown -R nginx:nginx /usr/local/nginx/logs
fi

# Check nginx systemd service
print_status "Checking systemd service..."
if [ -f "/etc/systemd/system/nginx.service" ]; then
    print_status "Nginx systemd service found"
    
    # Check if service is running
    if sudo systemctl is-active --quiet nginx; then
        print_status "Nginx service is running"
    else
        print_warning "Nginx service is not running"
        
        # Try to start the service
        print_status "Attempting to start nginx service..."
        sudo systemctl start nginx
        
        if sudo systemctl is-active --quiet nginx; then
            print_status "Nginx service started successfully"
        else
            print_error "Failed to start nginx service"
            print_warning "Checking service status..."
            sudo systemctl status nginx --no-pager -l
            exit 1
        fi
    fi
else
    print_error "Nginx systemd service not found"
    print_warning "Please run the deployment script to create the service"
    exit 1
fi

# Test nginx configuration
print_status "Testing Nginx configuration..."
if sudo /usr/local/nginx/sbin/nginx -t; then
    print_status "Nginx configuration test passed"
else
    print_error "Nginx configuration test failed"
    print_warning "Checking error logs..."
    sudo tail -n 10 /usr/local/nginx/logs/error.log
    exit 1
fi

# Check if RTMP module is loaded
print_status "Checking RTMP module..."
if /usr/local/nginx/sbin/nginx -V 2>&1 | grep -q "rtmp"; then
    print_status "RTMP module is loaded"
else
    print_warning "RTMP module not found in version output, but it might still be compiled in"
fi

# Check RTMP configuration
print_status "Checking RTMP configuration..."
if [ -f "/usr/local/nginx/conf/rtmp/rtmp.conf" ]; then
    print_status "RTMP configuration file found"
    
    # Check if RTMP is included in main config
    if grep -q "include.*rtmp.conf" /usr/local/nginx/conf/nginx.conf; then
        print_status "RTMP configuration is included in nginx.conf"
    else
        print_warning "RTMP configuration is not included in nginx.conf"
    fi
else
    print_warning "RTMP configuration file not found"
fi

# Check if ports are listening
print_status "Checking port availability..."
if sudo netstat -tlnp | grep -q ":80"; then
    print_status "Port 80 (HTTP) is listening"
else
    print_warning "Port 80 is not listening"
fi

if sudo netstat -tlnp | grep -q ":1935"; then
    print_status "Port 1935 (RTMP) is listening"
else
    print_warning "Port 1935 is not listening"
fi

# Check site configuration
print_status "Checking site configuration..."
if [ -f "/usr/local/nginx/conf/sites-available/scte35" ]; then
    print_status "Site configuration file found"
    
    if [ -L "/usr/local/nginx/conf/sites-enabled/scte35" ]; then
        print_status "Site is enabled"
    else
        print_warning "Site is not enabled"
    fi
else
    print_warning "Site configuration file not found"
fi

echo ""
echo -e "${GREEN}Nginx Setup Verification Completed!${NC}"
echo "=========================================="
echo ""
echo "Status Summary:"
echo "  ✓ Nginx binary: /usr/local/nginx/sbin/nginx"
echo "  ✓ Configuration: /usr/local/nginx/conf/"
echo "  ✓ Logs: /usr/local/nginx/logs/"
echo "  ✓ Systemd service: nginx"
echo "  ✓ Configuration test: PASSED"
echo ""
echo "Useful Commands:"
echo "  Test config: sudo /usr/local/nginx/sbin/nginx -t"
echo "  Reload config: sudo systemctl reload nginx"
echo "  Restart nginx: sudo systemctl restart nginx"
echo "  View status: sudo systemctl status nginx"
echo "  View logs: sudo tail -f /usr/local/nginx/logs/error.log"
echo ""
echo "Configuration Files:"
echo "  Main config: /usr/local/nginx/conf/nginx.conf"
echo "  RTMP config: /usr/local/nginx/conf/rtmp/rtmp.conf"
echo "  Site config: /usr/local/nginx/conf/sites-available/scte35"
echo ""
echo "Next Steps:"
echo "1. Run the deployment script: sudo bash deploy.sh"
echo "2. Test RTMP streaming with FFmpeg"
echo "3. Access your application at: http://$(hostname -I | awk '{print $1}')"
echo ""