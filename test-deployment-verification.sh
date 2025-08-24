#!/bin/bash

# SCTE-35 Streaming Control Center - Deployment Verification Script
# This script tests and verifies that the deployment is working correctly
# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   warn "This script should be run as root for full system access"
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        SCTE-35 Streaming Control Center - Verification          ║"
echo "║                                                              ║"
echo "║  This script will test and verify your deployment to ensure  ║"
echo "║  all components are working correctly.                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
log "Starting deployment verification..."

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')
log "Server IP: $SERVER_IP"

# Step 1: Check System Services
echo ""
info "Step 1: Checking System Services"

log "Checking Nginx status..."
if systemctl is-active --quiet nginx; then
    log "✅ Nginx is running"
    NGINX_STATUS=$(systemctl status nginx --no-pager -l)
    log "Nginx version: $(nginx -v 2>&1 | cut -d' ' -f3)"
else
    error "❌ Nginx is not running"
fi

log "Checking PM2 status..."
if command_exists pm2; then
    if pm2 list | grep -q "scte35-app"; then
        APP_STATUS=$(pm2 show scte35-app | grep -E "status|restarts" | head -2)
        log "✅ SCTE-35 application is running"
        log "Application details: $APP_STATUS"
    else
        warn "⚠️  SCTE-35 application not found in PM2"
    fi
else
    warn "⚠️  PM2 is not installed"
fi

# Step 2: Check Port Availability
echo ""
info "Step 2: Checking Port Availability"

declare -a ports=(80 3000 1935 1936)
for port in "${ports[@]}"; do
    if netstat -tulpn 2>/dev/null | grep -q ":$port "; then
        log "✅ Port $port is open and listening"
        SERVICE=$(netstat -tulpn 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1)
        log "   Service: $SERVICE"
    else
        warn "⚠️  Port $port is not listening"
    fi
done

# Step 3: Test Nginx Configuration
echo ""
info "Step 3: Testing Nginx Configuration"

log "Testing Nginx configuration syntax..."
if nginx -t 2>/dev/null; then
    log "✅ Nginx configuration syntax is valid"
else
    error "❌ Nginx configuration syntax is invalid"
fi

log "Checking RTMP module support..."
if nginx -V 2>&1 | grep -q "rtmp"; then
    log "✅ RTMP module is loaded"
else
    warn "⚠️  RTMP module may not be properly loaded"
fi

# Step 4: Test HTTP Endpoints
echo ""
info "Step 4: Testing HTTP Endpoints"

declare -a endpoints=("/health" "/" "/stat")
for endpoint in "${endpoints[@]}"; do
    log "Testing endpoint: http://localhost$endpoint"
    if curl -s -f "http://localhost$endpoint" > /dev/null 2>&1; then
        log "✅ Endpoint $endpoint is responding"
        
        # Get additional info for specific endpoints
        case $endpoint in
            "/health")
                HEALTH_RESPONSE=$(curl -s "http://localhost$endpoint")
                log "   Health response: $HEALTH_RESPONSE"
                ;;
            "/stat")
                if curl -s "http://localhost$endpoint" | grep -q "rtmp"; then
                    log "✅ RTMP statistics are available"
                else
                    warn "⚠️  RTMP statistics may not be working"
                fi
                ;;
        esac
    else
        warn "⚠️  Endpoint $endpoint is not responding"
    fi
done

# Step 5: Test Application API Endpoints
echo ""
info "Step 5: Testing Application API Endpoints"

declare -a api_endpoints=("/api/health" "/api/monitoring" "/api/scte/events")
for endpoint in "${api_endpoints[@]}"; do
    log "Testing API endpoint: http://localhost:3000$endpoint"
    if curl -s -f "http://localhost:3000$endpoint" > /dev/null 2>&1; then
        log "✅ API endpoint $endpoint is responding"
        
        # Get response for monitoring endpoint
        if [[ "$endpoint" == "/api/monitoring" ]]; then
            MONITOR_RESPONSE=$(curl -s "http://localhost:3000$endpoint")
            log "   Monitoring status: Available"
        fi
    else
        warn "⚠️  API endpoint $endpoint is not responding"
    fi
done

# Step 6: Test SCTE-35 Webhook Endpoints
echo ""
info "Step 6: Testing SCTE-35 Webhook Endpoints"

declare -a webhook_endpoints=("/api/scte35/on-publish" "/api/scte35/on-play")
for endpoint in "${webhook_endpoints[@]}"; do
    log "Testing webhook endpoint: http://localhost:3000$endpoint"
    
    # Send test POST request
    TEST_DATA='{"app":"live","name":"test","addr":"127.0.0.1"}'
    if curl -s -f -X POST -H "Content-Type: application/json" -d "$TEST_DATA" "http://localhost:3000$endpoint" > /dev/null 2>&1; then
        log "✅ Webhook endpoint $endpoint is responding"
    else
        warn "⚠️  Webhook endpoint $endpoint is not responding"
    fi
done

# Step 7: Test RTMP Streaming Capability
echo ""
info "Step 7: Testing RTMP Streaming Capability"

log "Testing RTMP server connectivity..."
if timeout 5 bash -c "</dev/tcp/localhost/1935" 2>/dev/null; then
    log "✅ RTMP server is accepting connections on port 1935"
else
    warn "⚠️  RTMP server may not be accepting connections"
fi

log "Checking RTMP statistics endpoint..."
if curl -s -f "http://localhost:1936/stat" > /dev/null 2>&1; then
    log "✅ RTMP statistics endpoint is accessible"
else
    warn "⚠️  RTMP statistics endpoint may not be accessible"
fi

# Step 8: Check Filesystem and Permissions
echo ""
info "Step 8: Checking Filesystem and Permissions"

declare -a directories=("/var/www/rtmp/hls" "/var/www/rtmp/dash" "/var/log/nginx")
for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]]; then
        log "✅ Directory $dir exists"
        if [[ -w "$dir" ]]; then
            log "✅ Directory $dir is writable"
        else
            warn "⚠️  Directory $dir may not be writable"
        fi
    else
        warn "⚠️  Directory $dir does not exist"
    fi
done

# Step 9: Test Database Connectivity
echo ""
info "Step 9: Testing Database Connectivity"

if [[ -f "/home/ubuntu/SCTE-streamcontrol/prisma/dev.db" ]]; then
    log "✅ Database file exists"
    
    # Test basic database operation if sqlite3 is available
    if command_exists sqlite3; then
        if sqlite3 "/home/ubuntu/SCTE-streamcontrol/prisma/dev.db" "SELECT name FROM sqlite_master WHERE type='table';" > /dev/null 2>&1; then
            log "✅ Database is accessible and readable"
        else
            warn "⚠️  Database may not be accessible"
        fi
    else
        log "ℹ️  sqlite3 not available for database testing"
    fi
else
    warn "⚠️  Database file not found"
fi

# Step 10: Performance and Resource Check
echo ""
info "Step 10: Performance and Resource Check"

# Check system resources
log "System resource usage:"
if command_exists htop; then
    log "✅ htop available for monitoring"
else
    log "ℹ️  htop not installed"
fi

# Check memory usage
MEMORY_USAGE=$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')
log "Memory usage: $MEMORY_USAGE"

# Check disk usage
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}')
log "Disk usage: $DISK_USAGE"

# Step 11: Generate Test Stream (Optional)
echo ""
info "Step 11: Test Stream Generation (Optional)"

if command_exists ffmpeg; then
    log "✅ FFmpeg is available for testing"
    log "To test RTMP streaming, run:"
    info "ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test"
else
    log "ℹ️  FFmpeg not installed - install with: sudo apt install ffmpeg"
fi

# Step 12: Summary Report
echo ""
info "Step 12: Verification Summary"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    VERIFICATION SUMMARY                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo ""
log "Access URLs for your SCTE-35 Streaming Control Center:"
echo ""
echo "🌐 Main Application:     http://$SERVER_IP/"
echo "📊 RTMP Statistics:     http://$SERVER_IP/stat"
echo "❤️  Health Check:        http://$SERVER_IP/health"
echo "📡 RTMP Publish:        rtmp://$SERVER_IP:1935/live/stream-key"
echo "📺 HLS Stream:          http://$SERVER_IP/hls/stream-key.m3u8"
echo "🎬 DASH Stream:         http://$SERVER_IP/dash/stream-key.mpd"
echo ""

log "Management Commands:"
echo ""
echo "📋 Application Status:  pm2 status"
echo "📝 Application Logs:    pm2 logs"
echo "🔄 Restart Application: pm2 restart scte35-app"
echo "🛑 Stop Application:     pm2 stop scte35-app"
echo "🔧 Nginx Status:        sudo systemctl status nginx"
echo "🔄 Restart Nginx:       sudo systemctl restart nginx"
echo ""

log "Testing Commands:"
echo ""
echo "🎥 Test RTMP Stream:     ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test"
echo "🔍 Test Health:         curl http://localhost/health"
echo "📈 Test RTMP Stats:      curl http://localhost/stat"
echo ""

# Final status
echo ""
if [[ $(grep -c "✅" <<< "$(systemctl is-active nginx 2>/dev/null && pm2 list 2>/dev/null | grep -q scte35-app && echo "success")") -gt 0 ]]; then
    log "🎉 Deployment verification completed successfully!"
    log "Your SCTE-35 Streaming Control Center is ready to use!"
else
    warn "⚠️  Deployment verification completed with some warnings"
    log "Please review the warnings above and take corrective action"
fi

echo ""
log "For additional help, check the documentation:"
echo "📖 Complete Deployment Guide: COMPLETE_DEPLOYMENT_GUIDE.md"
echo "🔧 RTMP Module Fix Guide:   NGINX_RTMP_MODULE_FIX_GUIDE.md"
echo ""

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Verification completed - Happy streaming! 🚀           ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.