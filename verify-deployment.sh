#!/bin/bash

# SCTE-35 Streaming Platform - Deployment Verification Script
# This script verifies that all components of the deployment are working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

print_ffmpeg() {
    echo -e "${PURPLE}[FFMPEG]${NC} $1"
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          SCTE-35 Streaming Platform - Verification           ║"
echo "║                                                              ║"
echo "║  This script verifies that all components of the deployment  ║"
echo "║  are working correctly including:                            ║"
echo "║  - System services and processes                             ║"
echo "║  - FFmpeg with SCTE-35 support                               ║"
echo "║  - Nginx with RTMP module                                    ║"
echo "║  - Next.js application                                        ║"
echo "║  - Database connectivity                                     ║"
echo "║  - Network ports and accessibility                            ║"
echo "║  - Streaming functionality                                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo ""

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')
print_info "Server IP: $SERVER_IP"

# Initialize counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="${3:-0}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Step 1: System Services Check
echo ""
print_step "Step 1: System Services Check"

# Check Nginx
run_test "Nginx Service" "sudo systemctl is-active --quiet nginx"

# Check PM2
run_test "PM2 Service" "pm2 status >/dev/null 2>&1"

# Check PM2 app status
run_test "SCTE-35 Application" "pm2 status | grep -q 'scte35-app.*online'"

# Check firewall
run_test "UFW Firewall" "sudo ufw status | grep -q 'Status: active'"

# Step 2: FFmpeg Verification
echo ""
print_step "Step 2: FFmpeg Verification"

# Check FFmpeg binary
run_test "FFmpeg Binary" "command -v ffmpeg"

# Check FFmpeg version
if command -v ffmpeg >/dev/null 2>&1; then
    print_ffmpeg "FFmpeg Version: $(ffmpeg -version | head -n 1)"
    run_test "FFmpeg Version Check" "ffmpeg -version >/dev/null 2>&1"
fi

# Check FFprobe binary
run_test "FFprobe Binary" "command -v ffprobe"

# Check SCTE-35 support
if command -v ffmpeg >/dev/null 2>&1; then
    print_ffmpeg "Checking SCTE-35 support..."
    if ffmpeg -h demuxer=mpegts 2>/dev/null | grep -qi scte; then
        print_success "✓ SCTE-35 demuxer support found"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    else
        print_warning "⚠ SCTE-35 demuxer support not found"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
fi

# Check FFmpeg configuration file
run_test "FFmpeg Config" "test -f /etc/ffmpeg/scte35.conf"

# Check test script
run_test "FFmpeg Test Script" "test -f /usr/local/bin/test-ffmpeg-scte35.sh"

# Step 3: Nginx Configuration Check
echo ""
print_step "Step 3: Nginx Configuration Check"

# Check Nginx configuration
run_test "Nginx Configuration" "sudo nginx -t"

# Check Nginx main config
run_test "Nginx Main Config" "test -f /etc/nginx/nginx.conf"

# Check RTMP configuration
run_test "RTMP Configuration" "sudo nginx -t 2>&1 | grep -q 'syntax is ok'"

# Check required directories
run_test "RTMP Directories" "test -d /var/www/rtmp/hls && test -d /var/www/rtmp/dash"

# Check statistics stylesheet
run_test "Statistics Stylesheet" "test -f /var/www/rtmp/stat.xsl"

# Step 4: Application Check
echo ""
print_step "Step 4: Application Check"

# Check project directory
run_test "Project Directory" "test -d /home/ubuntu/SCTE-streamcontrol"

# Check package.json
run_test "Package.json" "test -f /home/ubuntu/SCTE-streamcontrol/package.json"

# Check environment file
run_test "Environment File" "test -f /home/ubuntu/SCTE-streamcontrol/.env"

# Check database file
run_test "Database File" "test -f /home/ubuntu/SCTE-streamcontrol/dev.db"

# Check PM2 configuration
run_test "PM2 Configuration" "test -f /home/ubuntu/SCTE-streamcontrol/ecosystem.config.js"

# Step 5: Network and Port Check
echo ""
print_step "Step 5: Network and Port Check"

# Check if ports are listening
run_test "Port 80 (HTTP)" "nc -z localhost 80"
run_test "Port 1935 (RTMP)" "nc -z localhost 1935"
run_test "Port 1936 (RTMP Stats)" "nc -z localhost 1936"
run_test "Port 3000 (Next.js)" "nc -z localhost 3000"

# Check firewall rules
run_test "Firewall Port 80" "sudo ufw status | grep -q '80/tcp'"
run_test "Firewall Port 1935" "sudo ufw status | grep -q '1935/tcp'"
run_test "Firewall Port 1936" "sudo ufw status | grep -q '1936/tcp'"

# Step 6: Web Application Test
echo ""
print_step "Step 6: Web Application Test"

# Test health endpoint
if command -v curl >/dev/null 2>&1; then
    run_test "Health Endpoint" "curl -s http://localhost/health | grep -q 'healthy'"
    
    # Test main application
    run_test "Main Application" "curl -s http://localhost:3000 | grep -q 'html'"
    
    # Test RTMP stats
    run_test "RTMP Statistics" "curl -s http://localhost/stat | grep -q 'RTMP'"
else
    print_warning "curl not available, skipping web application tests"
fi

# Step 7: Database Check
echo ""
print_step "Step 7: Database Check"

# Check database connectivity
if [ -f "/home/ubuntu/SCTE-streamcontrol/dev.db" ]; then
    run_test "Database File" "test -f /home/ubuntu/SCTE-streamcontrol/dev.db"
    
    # Test database operations
    cd /home/ubuntu/SCTE-streamcontrol
    run_test "Database Operations" "npm run db:push >/dev/null 2>&1"
else
    print_warning "Database file not found"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

# Step 8: Monitoring Scripts Check
echo ""
print_step "Step 8: Monitoring Scripts Check"

# Check backup script
run_test "Backup Script" "test -f /home/ubuntu/backup.sh"

# Check monitoring script
run_test "Monitoring Script" "test -f /home/ubuntu/monitor.sh"

# Check crontab entries
if crontab -l 2>/dev/null | grep -q "backup.sh"; then
    print_success "✓ Backup crontab entry found"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
else
    print_warning "⚠ Backup crontab entry not found"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

if crontab -l 2>/dev/null | grep -q "monitor.sh"; then
    print_success "✓ Monitoring crontab entry found"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
else
    print_warning "⚠ Monitoring crontab entry not found"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

# Step 9: Performance Check
echo ""
print_step "Step 9: Performance Check"

# Check system resources
print_info "System Resources:"
print_info "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
print_info "Memory Usage: $(free | awk 'NR==2{printf "%.2f%%", $3/$2*100}')"
print_info "Disk Usage: $(df / | awk 'NR==2{printf "%s", $5}')"

# Check file descriptors
FILE_LIMIT=$(ulimit -n)
if [ "$FILE_LIMIT" -ge 65536 ]; then
    print_success "✓ File descriptor limit: $FILE_LIMIT"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
else
    print_warning "⚠ File descriptor limit low: $FILE_LIMIT"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

# Step 10: Final Integration Test
echo ""
print_step "Step 10: Final Integration Test"

# Test FFmpeg integration
if command -v ffmpeg >/dev/null 2>&1 && [ -f "/usr/local/bin/test-ffmpeg-scte35.sh" ]; then
    print_ffmpeg "Running FFmpeg SCTE-35 integration test..."
    if /usr/local/bin/test-ffmpeg-scte35.sh >/dev/null 2>&1; then
        print_success "✓ FFmpeg SCTE-35 integration test passed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    else
        print_warning "⚠ FFmpeg SCTE-35 integration test failed"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
    fi
fi

# Test complete deployment functionality
print_info "Testing complete deployment functionality..."

# Check if all major components are running
if sudo systemctl is-active --quiet nginx && pm2 status | grep -q 'scte35-app.*online' && command -v ffmpeg >/dev/null 2>&1; then
    print_success "✓ All major components are running"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
else
    print_error "✗ One or more major components are not running"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                      Verification Summary                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Total Tests: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! Deployment is working correctly.${NC}"
    echo ""
    echo "🌐 Access Points:"
    echo "  Web Interface: http://$SERVER_IP"
    echo "  RTMP Server: rtmp://$SERVER_IP:1935/live"
    echo "  HLS Streams: http://$SERVER_IP/hls"
    echo "  DASH Streams: http://$SERVER_IP/dash"
    echo "  RTMP Stats: http://$SERVER_IP/stat"
    echo ""
    echo "🛠️  Management Commands:"
    echo "  View logs: pm2 logs"
    echo "  Monitor: pm2 monit"
    echo "  Restart app: pm2 restart scte35-app"
    echo "  Test FFmpeg: test-ffmpeg-scte35.sh"
    echo ""
    echo "📊 Monitoring:"
    echo "  System monitoring: ~/monitor.sh"
    echo "  Backup: ~/backup.sh"
    echo ""
    echo "✅ Your SCTE-35 streaming platform is fully operational!"
else
    echo -e "${YELLOW}⚠️  $FAILED_TESTS test(s) failed. Please review the issues above.${NC}"
    echo ""
    echo "🔧 Troubleshooting Steps:"
    echo "1. Check service status: sudo systemctl status nginx"
    echo "2. Check PM2 status: pm2 status"
    echo "3. Check logs: pm2 logs"
    echo "4. Test FFmpeg: test-ffmpeg-scte35.sh"
    echo "5. Verify network connectivity: netstat -tlnp"
    echo ""
    echo "📞 For additional support, refer to the documentation."
fi

echo ""
echo "Verification completed at: $(date)"
echo ""