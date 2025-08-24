#!/bin/bash

# SCTE-35 Deployment Test Script
# This script tests various aspects of your deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP=$(hostname -I | awk '{print $1}')
TEST_VIDEO_URL="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
TEST_VIDEO_FILE="test_video.mp4"

echo -e "${BLUE}SCTE-35 Deployment Test Script${NC}"
echo "======================================"
echo "Server IP: $SERVER_IP"
echo ""

# Function to print status messages
print_status() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Test 1: System Resources
print_info "Testing system resources..."
echo "--------------------------------"

# Check disk space
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -lt 90 ]; then
    print_status "Disk space usage: ${DISK_USAGE}% (OK)"
else
    print_error "Disk space usage: ${DISK_USAGE}% (High)"
fi

# Check memory
MEM_AVAILABLE=$(free -m | awk '/Mem:/ {print $7}')
if [ $MEM_AVAILABLE -gt 512 ]; then
    print_status "Available memory: ${MEM_AVAILABLE}MB (OK)"
else
    print_error "Available memory: ${MEM_AVAILABLE}MB (Low)"
fi

# Check CPU load
LOAD_1MIN=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
LOAD_1MIN_NUM=$(echo $LOAD_1MIN | awk '{printf "%.0f", $1}')
if [ $LOAD_1MIN_NUM -lt 2 ]; then
    print_status "CPU load (1min): $LOAD_1MIN (OK)"
else
    print_warning "CPU load (1min): $LOAD_1MIN (High)"
fi

echo ""

# Test 2: Service Status
print_info "Testing service status..."
echo "-------------------------------"

# Check PM2 status
if pm2 status > /dev/null 2>&1; then
    print_status "PM2 is running"
    
    # Check if SCTE-35 app is running
    if pm2 describe scte35-app > /dev/null 2>&1; then
        APP_STATUS=$(pm2 describe scte35-app | grep -o '"status": "[^"]*"' | cut -d'"' -f4)
        if [ "$APP_STATUS" = "online" ]; then
            print_status "SCTE-35 app is running"
        else
            print_error "SCTE-35 app status: $APP_STATUS"
        fi
    else
        print_error "SCTE-35 app not found in PM2"
    fi
else
    print_error "PM2 is not running"
fi

# Check Nginx status
if systemctl is-active --quiet nginx; then
    print_status "Nginx is running"
else
    print_error "Nginx is not running"
fi

echo ""

# Test 3: Port Availability
print_info "Testing port availability..."
echo "--------------------------------"

# Test ports
declare -a ports=("3000" "80" "1935" "1936")
for port in "${ports[@]}"; do
    if netstat -tulpn 2>/dev/null | grep -q ":$port "; then
        print_status "Port $port is open and listening"
    else
        print_error "Port $port is not listening"
    fi
done

echo ""

# Test 4: Web Application
print_info "Testing web application..."
echo "--------------------------------"

# Test HTTP response
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    print_status "Web application responding (HTTP $HTTP_CODE)"
else
    print_error "Web application not responding (HTTP $HTTP_CODE)"
fi

# Test through Nginx proxy
HTTP_CODE_NGINX=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE_NGINX" = "200" ]; then
    print_status "Nginx proxy working (HTTP $HTTP_CODE_NGINX)"
else
    print_error "Nginx proxy not working (HTTP $HTTP_CODE_NGINX)"
fi

echo ""

# Test 5: RTMP Server
print_info "Testing RTMP server..."
echo "---------------------------"

# Test RTMP statistics page
RTMP_STAT_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/stat 2>/dev/null || echo "000")
if [ "$RTMP_STAT_CODE" = "200" ]; then
    print_status "RTMP statistics page accessible (HTTP $RTMP_STAT_CODE)"
else
    print_error "RTMP statistics page not accessible (HTTP $RTMP_STAT_CODE)"
fi

echo ""

# Test 6: Directory Structure
print_info "Testing directory structure..."
echo "-----------------------------------"

# Check if directories exist
declare -a dirs=("/var/www/rtmp/hls" "/var/www/rtmp/dash" "/var/log/pm2")
for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
        print_status "Directory exists: $dir"
    else
        print_error "Directory missing: $dir"
    fi
done

echo ""

# Test 7: Download Test Video (Optional)
print_info "Testing video streaming (optional)..."
echo "----------------------------------------"

if command -v ffmpeg >/dev/null 2>&1; then
    print_status "FFmpeg is installed"
    
    # Download test video if not exists
    if [ ! -f "$TEST_VIDEO_FILE" ]; then
        print_info "Downloading test video..."
        if wget -q --timeout=30 -O "$TEST_VIDEO_FILE" "$TEST_VIDEO_URL"; then
            print_status "Test video downloaded successfully"
        else
            print_error "Failed to download test video"
        fi
    else
        print_status "Test video already exists"
    fi
    
    # Test video file
    if [ -f "$TEST_VIDEO_FILE" ]; then
        FILE_SIZE=$(du -h "$TEST_VIDEO_FILE" | cut -f1)
        print_status "Test video file: $FILE_SIZE"
        
        # Test video duration
        VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TEST_VIDEO_FILE" 2>/dev/null || echo "0")
        if [ "$VIDEO_DURATION" != "0" ]; then
            print_status "Video duration: ${VIDEO_DURATION}s"
        else
            print_error "Could not read video duration"
        fi
    fi
else
    print_warning "FFmpeg not installed - skipping video tests"
fi

echo ""

# Test 8: Configuration Files
print_info "Testing configuration files..."
echo "----------------------------------"

# Check environment file
if [ -f ".env" ]; then
    print_status "Environment file exists"
    
    # Check key environment variables
    if grep -q "NODE_ENV=production" .env; then
        print_status "Production mode configured"
    else
        print_warning "Production mode not set in .env"
    fi
    
    if grep -q "PORT=3000" .env; then
        print_status "Port 3000 configured"
    else
        print_warning "Port not properly configured in .env"
    fi
else
    print_error "Environment file not found"
fi

# Check PM2 configuration
if [ -f "ecosystem.config.js" ]; then
    print_status "PM2 ecosystem configuration exists"
else
    print_error "PM2 ecosystem configuration not found"
fi

echo ""

# Test 9: Log Files
print_info "Testing log files..."
echo "-------------------------"

# Check PM2 logs
if pm2 logs scte35-app --lines 1 > /dev/null 2>&1; then
    print_status "PM2 logs accessible"
else
    print_error "PM2 logs not accessible"
fi

# Check Nginx logs
if [ -f "/var/log/nginx/access.log" ] && [ -f "/var/log/nginx/error.log" ]; then
    print_status "Nginx logs exist"
else
    print_error "Nginx logs not found"
fi

echo ""

# Test 10: Network Connectivity
print_info "Testing network connectivity..."
echo "----------------------------------"

# Test external connectivity
if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    print_status "External network connectivity OK"
else
    print_error "No external network connectivity"
fi

echo ""

# Summary
echo -e "${BLUE}Test Summary${NC}"
echo "============"

# Count passed and failed tests
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# This is a simple count - in a real script you'd track actual test results
echo "Manual verification required. Please review the output above."
echo ""

# Next Steps
echo -e "${BLUE}Next Steps${NC}"
echo "=========="
echo "1. If all tests pass, your deployment is ready!"
echo "2. If any tests failed, review the error messages above"
echo "3. Test RTMP streaming with:"
echo "   ffmpeg -re -i $TEST_VIDEO_FILE -c:v libx264 -c:a aac -f flv rtmp://$SERVER_IP:1935/live/test"
echo "4. Access HLS stream at:"
echo "   http://$SERVER_IP/hls/test.m3u8"
echo "5. Test SCTE-35 functionality through the web interface"
echo ""

echo -e "${GREEN}Deployment test completed!${NC}"