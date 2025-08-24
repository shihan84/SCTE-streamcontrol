#!/bin/bash

# SCTE-35 Streaming Platform - Enhanced Deployment Verification Script
# Comprehensive testing and verification of all deployed components
# 
# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="/tmp/scte35-verification-$(date +%Y%m%d_%H%M%S).log"
REPORT_FILE="/tmp/scte35-verification-report-$(date +%Y%m%d_%H%M%S).json"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
WARNING_TESTS=0
SERVER_IP=$(hostname -I | awk '{print $1}')

# Test categories
declare -A TEST_CATEGORIES
TEST_CATEGORIES["system"]="System Services"
TEST_CATEGORIES["ffmpeg"]="FFmpeg Integration"
TEST_CATEGORIES["nginx"]="Nginx Configuration"
TEST_CATEGORIES["application"]="Application Components"
TEST_CATEGORIES["network"]="Network & Ports"
TEST_CATEGORIES["database"]="Database Connectivity"
TEST_CATEGORIES["security"]="Security & Access"
TEST_CATEGORIES["performance"]="Performance & Resources"
TEST_CATEGORIES["integration"]="Integration Testing"

# Test results storage
declare -A TEST_RESULTS
declare -A TEST_MESSAGES

# Function to print colored output with logging
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

print_ffmpeg() {
    echo -e "${PURPLE}[FFMPEG]${NC} $1" | tee -a "$LOG_FILE"
}

print_system() {
    echo -e "${ORANGE}[SYSTEM]${NC} $1" | tee -a "$LOG_FILE"
}

print_test() {
    local category="$1"
    local test_name="$2"
    local status="$3"
    local message="$4"
    
    case $status in
        "PASS")
            echo -e "${GREEN}✓${NC} [$category] $test_name"
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} [$category] $test_name"
            ;;
        "SKIP")
            echo -e "${YELLOW}−${NC} [$category] $test_name"
            ;;
        "WARN")
            echo -e "${ORANGE}!${NC} [$category] $test_name"
            ;;
    esac
    
    # Store test result
    local test_key="${category}_${test_name}"
    TEST_RESULTS["$test_key"]="$status"
    TEST_MESSAGES["$test_key"]="$message"
    
    # Update counters
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    case $status in
        "PASS") PASSED_TESTS=$((PASSED_TESTS + 1)) ;;
        "FAIL") FAILED_TESTS=$((FAILED_TESTS + 1)) ;;
        "SKIP") SKIPPED_TESTS=$((SKIPPED_TESTS + 1)) ;;
        "WARN") WARNING_TESTS=$((WARNING_TESTS + 1)) ;;
    esac
}

# Function to run test with error handling
run_test() {
    local category="$1"
    local test_name="$2"
    local test_command="$3"
    local expected_result="${4:-0}"
    local critical="${5:-false}"
    
    print_info "Testing $test_name..."
    echo "Test: $test_name" >> "$LOG_FILE"
    echo "Command: $test_command" >> "$LOG_FILE"
    
    local start_time=$(date +%s)
    local output=""
    local result=0
    
    # Run test with timeout
    if timeout 30 bash -c "$test_command" >/dev/null 2>&1; then
        result=$expected_result
    else
        result=$((1 - expected_result))
    fi
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Get command output for logging
    output=$(eval "$test_command" 2>&1 || true)
    echo "Output: $output" >> "$LOG_FILE"
    echo "Duration: ${duration}s" >> "$LOG_FILE"
    
    if [[ $result -eq $expected_result ]]; then
        print_test "$category" "$test_name" "PASS" "Completed in ${duration}s"
        return 0
    else
        print_test "$category" "$test_name" "FAIL" "Failed in ${duration}s: $output"
        if [[ "$critical" == "true" ]]; then
            print_error "Critical test failed: $test_name"
        fi
        return 1
    fi
}

# Function to run test with output check
run_test_with_output() {
    local category="$1"
    local test_name="$2"
    local test_command="$3"
    local expected_pattern="$4"
    local critical="${5:-false}"
    
    print_info "Testing $test_name..."
    echo "Test: $test_name" >> "$LOG_FILE"
    echo "Command: $test_command" >> "$LOG_FILE"
    
    local start_time=$(date +%s)
    local output=""
    
    # Run test with timeout
    if output=$(timeout 30 bash -c "$test_command" 2>&1); then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo "Output: $output" >> "$LOG_FILE"
        echo "Duration: ${duration}s" >> "$LOG_FILE"
        
        if [[ "$output" =~ $expected_pattern ]]; then
            print_test "$category" "$test_name" "PASS" "Pattern matched in ${duration}s"
            return 0
        else
            print_test "$category" "$test_name" "FAIL" "Pattern not matched in ${duration}s"
            if [[ "$critical" == "true" ]]; then
                print_error "Critical test failed: $test_name"
            fi
            return 1
        fi
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_test "$category" "$test_name" "FAIL" "Command failed in ${duration}s"
        if [[ "$critical" == "true" ]]; then
            print_error "Critical test failed: $test_name"
        fi
        return 1
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if port is listening
port_is_listening() {
    local port="$1"
    nc -z localhost "$port" >/dev/null 2>&1
}

# Function to check if service is running
service_is_running() {
    local service="$1"
    systemctl is-active --quiet "$service"
}

# Function to check file exists and is readable
file_exists() {
    local file="$1"
    [[ -f "$file" && -r "$file" ]]
}

# Function to check directory exists
directory_exists() {
    local dir="$1"
    [[ -d "$dir" ]]
}

# Function to generate JSON report
generate_json_report() {
    local report_file="$1"
    
    cat > "$report_file" << EOF
{
  "verification_report": {
    "timestamp": "$(date -Iseconds)",
    "server_ip": "$SERVER_IP",
    "summary": {
      "total_tests": $TOTAL_TESTS,
      "passed_tests": $PASSED_TESTS,
      "failed_tests": $FAILED_TESTS,
      "skipped_tests": $SKIPPED_TESTS,
      "warning_tests": $WARNING_TESTS,
      "success_rate": $((PASSED_TESTS * 100 / TOTAL_TESTS))
    },
    "categories": {
EOF
    
    # Add category results
    local first_category=true
    for category in "${!TEST_CATEGORIES[@]}"; do
        if [[ "$first_category" == "true" ]]; then
            first_category=false
        else
            echo "," >> "$report_file"
        fi
        
        cat >> "$report_file" << EOF
      "$category": {
        "name": "${TEST_CATEGORIES[$category]}",
        "total": 0,
        "passed": 0,
        "failed": 0,
        "skipped": 0,
        "warnings": 0,
        "tests": []
EOF
        
        # Count tests in this category
        local category_total=0
        local category_passed=0
        local category_failed=0
        local category_skipped=0
        local category_warnings=0
        
        for test_key in "${!TEST_RESULTS[@]}"; do
            if [[ "$test_key" == "${category}_"* ]]; then
                category_total=$((category_total + 1))
                case "${TEST_RESULTS[$test_key]}" in
                    "PASS") category_passed=$((category_passed + 1)) ;;
                    "FAIL") category_failed=$((category_failed + 1)) ;;
                    "SKIP") category_skipped=$((category_skipped + 1)) ;;
                    "WARN") category_warnings=$((category_warnings + 1)) ;;
                esac
            fi
        done
        
        cat >> "$report_file" << EOF
        }
EOF
    done
    
    cat >> "$report_file" << EOF
    },
    "detailed_results": {
EOF
    
    # Add detailed results
    local first_test=true
    for test_key in "${!TEST_RESULTS[@]}"; do
        if [[ "$first_test" == "true" ]]; then
            first_test=false
        else
            echo "," >> "$report_file"
        fi
        
        cat >> "$report_file" << EOF
      "$test_key": {
        "status": "${TEST_RESULTS[$test_key]}",
        "message": "${TEST_MESSAGES[$test_key]}"
      }
EOF
    done
    
    cat >> "$report_file" << EOF
    }
  }
}
EOF
    
    print_success "JSON report generated: $report_file"
}

# Function to show test results summary
show_test_summary() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Verification Summary                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📊 Test Results:"
    echo "  📈 Total Tests: $TOTAL_TESTS"
    echo "  ✅ Passed: $PASSED_TESTS"
    echo "  ❌ Failed: $FAILED_TESTS"
    echo "  ⏭️  Skipped: $SKIPPED_TESTS"
    echo "  ⚠️  Warnings: $WARNING_TESTS"
    echo ""
    
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo "  📊 Success Rate: ${success_rate}%"
        echo ""
    fi
    
    echo "📂 Results by Category:"
    for category in "${!TEST_CATEGORIES[@]}"; do
        local category_total=0
        local category_passed=0
        local category_failed=0
        
        for test_key in "${!TEST_RESULTS[@]}"; do
            if [[ "$test_key" == "${category}_"* ]]; then
                category_total=$((category_total + 1))
                case "${TEST_RESULTS[$test_key]}" in
                    "PASS") category_passed=$((category_passed + 1)) ;;
                    "FAIL") category_failed=$((category_failed + 1)) ;;
                esac
            fi
        done
        
        if [[ $category_total -gt 0 ]]; then
            local category_success=$((category_passed * 100 / category_total))
            echo "  ${TEST_CATEGORIES[$category]}: $category_passed/$category_total (${category_success}%)"
        fi
    done
    echo ""
    
    echo "📁 Log Files:"
    echo "  📋 Verification Log: $LOG_FILE"
    echo "  📊 JSON Report: $REPORT_FILE"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed! Deployment is working correctly.${NC}"
        echo ""
        echo "🌐 Access Points:"
        echo "  🖥️  Web Interface: http://$SERVER_IP"
        echo "  📺 RTMP Server: rtmp://$SERVER_IP:1935/live"
        echo "  📱 HLS Stream: http://$SERVER_IP/hls"
        echo "  📊 DASH Stream: http://$SERVER_IP/dash"
        echo "  📈 RTMP Stats: http://$SERVER_IP/stat"
        echo "  ❤️  Health Check: http://$SERVER_IP/health"
        echo ""
        echo "🛠️  Next Steps:"
        echo "  1. 🌐 Open web interface in browser"
        echo "  2. 🎬 Test streaming with FFmpeg"
        echo "  3. 📱 Verify HLS/DASH playback"
        echo "  4. 📊 Check RTMP statistics"
        echo ""
    else
        echo -e "${YELLOW}⚠️  $FAILED_TESTS test(s) failed. Please review the issues above.${NC}"
        echo ""
        echo "🔧 Troubleshooting Steps:"
        echo "  1. 📋 Check log file: $LOG_FILE"
        echo "  2. 📊 Review JSON report: $REPORT_FILE"
        echo "  3. 🔄 Restart failed services"
        echo "  4. 🧪 Run individual tests"
        echo "  5. 📞 Check documentation for help"
        echo ""
    fi
    
    echo "For additional support, refer to the documentation."
    echo "╚══════════════════════════════════════════════════════════════╝"
}

# Main verification function
main() {
    # Initialize log file
    echo "SCTE-35 Streaming Platform Verification Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    echo "User: $(whoami)" >> "$LOG_FILE"
    echo "Server: $(hostname)" >> "$LOG_FILE"
    echo "Server IP: $SERVER_IP" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
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
    echo "║  - Security and access control                               ║"
    echo "║  - Performance and resource monitoring                        ║"
    echo "║  - Integration testing                                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    print_info "Server IP: $SERVER_IP"
    print_info "Starting comprehensive verification..."
    
    # Step 1: System Services Check
    echo ""
    print_step "Step 1: System Services Check"
    
    # Check Nginx
    if service_is_running nginx; then
        print_test "system" "Nginx Service" "PASS" "Nginx is running"
    else
        print_test "system" "Nginx Service" "FAIL" "Nginx is not running"
    fi
    
    # Check PM2
    if command_exists pm2; then
        print_test "system" "PM2 Service" "PASS" "PM2 is available"
    else
        print_test "system" "PM2 Service" "FAIL" "PM2 is not available"
    fi
    
    # Check PM2 app status
    if command_exists pm2 && pm2 status | grep -q 'scte35-app.*online'; then
        print_test "system" "SCTE-35 Application" "PASS" "SCTE-35 app is running"
    else
        print_test "system" "SCTE-35 Application" "FAIL" "SCTE-35 app is not running"
    fi
    
    # Check firewall
    if command_exists ufw && ufw status | grep -q 'Status: active'; then
        print_test "system" "UFW Firewall" "PASS" "UFW firewall is active"
    else
        print_test "system" "UFW Firewall" "WARN" "UFW firewall is not active"
    fi
    
    # Check fail2ban
    if service_is_running fail2ban; then
        print_test "system" "Fail2ban Service" "PASS" "Fail2ban is running"
    else
        print_test "system" "Fail2ban Service" "WARN" "Fail2ban is not running"
    fi
    
    # Step 2: FFmpeg Verification
    echo ""
    print_step "Step 2: FFmpeg Verification"
    
    # Check FFmpeg binary
    if command_exists ffmpeg; then
        print_test "ffmpeg" "FFmpeg Binary" "PASS" "FFmpeg is available"
        
        # Check FFmpeg version
        local ffmpeg_version=$(ffmpeg -version | head -n 1)
        print_test "ffmpeg" "FFmpeg Version" "PASS" "Version: $ffmpeg_version"
        
        # Check for SuperKabuki patch
        if [[ "$ffmpeg_version" == *"SuperKabuki"* ]] || [[ "$ffmpeg_version" == *"SCTE35"* ]]; then
            print_test "ffmpeg" "SuperKabuki Patch" "PASS" "SuperKabuki patch detected"
        else
            print_test "ffmpeg" "SuperKabuki Patch" "WARN" "SuperKabuki patch not detected"
        fi
        
        # Check SCTE-35 support
        if ffmpeg -h demuxer=mpegts 2>/dev/null | grep -qi scte; then
            print_test "ffmpeg" "SCTE-35 Demuxer" "PASS" "SCTE-35 demuxer support found"
        else
            print_test "ffmpeg" "SCTE-35 Demuxer" "FAIL" "SCTE-35 demuxer support not found"
        fi
        
        # Check SCTE-35 muxer
        if ffmpeg -h muxer=mpegts 2>/dev/null | grep -qi scte; then
            print_test "ffmpeg" "SCTE-35 Muxer" "PASS" "SCTE-35 muxer support found"
        else
            print_test "ffmpeg" "SCTE-35 Muxer" "FAIL" "SCTE-35 muxer support not found"
        fi
        
        # Check key encoders
        if ffmpeg -encoders 2>/dev/null | grep -q "libx264"; then
            print_test "ffmpeg" "H.264 Encoder" "PASS" "libx264 encoder available"
        else
            print_test "ffmpeg" "H.264 Encoder" "FAIL" "libx264 encoder not available"
        fi
        
        if ffmpeg -encoders 2>/dev/null | grep -q "libx265"; then
            print_test "ffmpeg" "H.265 Encoder" "PASS" "libx265 encoder available"
        else
            print_test "ffmpeg" "H.265 Encoder" "WARN" "libx265 encoder not available"
        fi
        
    else
        print_test "ffmpeg" "FFmpeg Binary" "FAIL" "FFmpeg is not available"
        print_test "ffmpeg" "FFmpeg Version" "SKIP" "FFmpeg not available"
        print_test "ffmpeg" "SuperKabuki Patch" "SKIP" "FFmpeg not available"
        print_test "ffmpeg" "SCTE-35 Demuxer" "SKIP" "FFmpeg not available"
        print_test "ffmpeg" "SCTE-35 Muxer" "SKIP" "FFmpeg not available"
        print_test "ffmpeg" "H.264 Encoder" "SKIP" "FFmpeg not available"
        print_test "ffmpeg" "H.265 Encoder" "SKIP" "FFmpeg not available"
    fi
    
    # Check FFprobe binary
    if command_exists ffprobe; then
        print_test "ffmpeg" "FFprobe Binary" "PASS" "FFprobe is available"
    else
        print_test "ffmpeg" "FFprobe Binary" "FAIL" "FFprobe is not available"
    fi
    
    # Check FFmpeg configuration file
    if file_exists "/etc/ffmpeg/scte35.conf"; then
        print_test "ffmpeg" "FFmpeg Config" "PASS" "Configuration file exists"
    else
        print_test "ffmpeg" "FFmpeg Config" "WARN" "Configuration file not found"
    fi
    
    # Check test script
    if file_exists "/usr/local/bin/test-ffmpeg-scte35.sh"; then
        print_test "ffmpeg" "FFmpeg Test Script" "PASS" "Test script exists"
    else
        print_test "ffmpeg" "FFmpeg Test Script" "WARN" "Test script not found"
    fi
    
    # Step 3: Nginx Configuration Check
    echo ""
    print_step "Step 3: Nginx Configuration Check"
    
    # Check Nginx configuration
    if command_exists nginx && nginx -t >/dev/null 2>&1; then
        print_test "nginx" "Nginx Configuration" "PASS" "Configuration is valid"
    else
        print_test "nginx" "Nginx Configuration" "FAIL" "Configuration test failed"
    fi
    
    # Check Nginx main config
    if file_exists "/etc/nginx/nginx.conf"; then
        print_test "nginx" "Nginx Main Config" "PASS" "Main configuration exists"
    else
        print_test "nginx" "Nginx Main Config" "FAIL" "Main configuration not found"
    fi
    
    # Check RTMP configuration
    if command_exists nginx && nginx -T 2>/dev/null | grep -q "rtmp"; then
        print_test "nginx" "RTMP Configuration" "PASS" "RTMP is configured"
    else
        print_test "nginx" "RTMP Configuration" "FAIL" "RTMP not configured"
    fi
    
    # Check required directories
    if directory_exists "/var/www/rtmp/hls" && directory_exists "/var/www/rtmp/dash"; then
        print_test "nginx" "RTMP Directories" "PASS" "RTMP directories exist"
    else
        print_test "nginx" "RTMP Directories" "FAIL" "RTMP directories missing"
    fi
    
    # Check statistics stylesheet
    if file_exists "/var/www/rtmp/stat.xsl"; then
        print_test "nginx" "Statistics Stylesheet" "PASS" "Stylesheet exists"
    else
        print_test "nginx" "Statistics Stylesheet" "WARN" "Stylesheet not found"
    fi
    
    # Step 4: Application Check
    echo ""
    print_step "Step 4: Application Check"
    
    # Check project directory
    if directory_exists "/home/ubuntu/SCTE-streamcontrol"; then
        print_test "application" "Project Directory" "PASS" "Project directory exists"
    else
        print_test "application" "Project Directory" "FAIL" "Project directory not found"
    fi
    
    # Check package.json
    if file_exists "/home/ubuntu/SCTE-streamcontrol/package.json"; then
        print_test "application" "Package.json" "PASS" "Package.json exists"
    else
        print_test "application" "Package.json" "FAIL" "Package.json not found"
    fi
    
    # Check environment file
    if file_exists "/home/ubuntu/SCTE-streamcontrol/.env"; then
        print_test "application" "Environment File" "PASS" "Environment file exists"
    else
        print_test "application" "Environment File" "WARN" "Environment file not found"
    fi
    
    # Check database file
    if file_exists "/home/ubuntu/SCTE-streamcontrol/dev.db"; then
        print_test "application" "Database File" "PASS" "Database file exists"
    else
        print_test "application" "Database File" "FAIL" "Database file not found"
    fi
    
    # Check PM2 configuration
    if file_exists "/home/ubuntu/SCTE-streamcontrol/ecosystem.config.js"; then
        print_test "application" "PM2 Configuration" "PASS" "PM2 configuration exists"
    else
        print_test "application" "PM2 Configuration" "WARN" "PM2 configuration not found"
    fi
    
    # Step 5: Network and Port Check
    echo ""
    print_step "Step 5: Network and Port Check"
    
    # Check if ports are listening
    if port_is_listening 80; then
        print_test "network" "Port 80 (HTTP)" "PASS" "HTTP port is accessible"
    else
        print_test "network" "Port 80 (HTTP)" "FAIL" "HTTP port is not accessible"
    fi
    
    if port_is_listening 1935; then
        print_test "network" "Port 1935 (RTMP)" "PASS" "RTMP port is accessible"
    else
        print_test "network" "Port 1935 (RTMP)" "FAIL" "RTMP port is not accessible"
    fi
    
    if port_is_listening 1936; then
        print_test "network" "Port 1936 (RTMP Stats)" "PASS" "RTMP stats port is accessible"
    else
        print_test "network" "Port 1936 (RTMP Stats)" "WARN" "RTMP stats port is not accessible"
    fi
    
    if port_is_listening 3000; then
        print_test "network" "Port 3000 (Next.js)" "PASS" "Next.js port is accessible"
    else
        print_test "network" "Port 3000 (Next.js)" "FAIL" "Next.js port is not accessible"
    fi
    
    # Check firewall rules
    if command_exists ufw; then
        if ufw status | grep -q "80/tcp"; then
            print_test "network" "Firewall Port 80" "PASS" "Firewall allows port 80"
        else
            print_test "network" "Firewall Port 80" "WARN" "Firewall may not allow port 80"
        fi
        
        if ufw status | grep -q "1935/tcp"; then
            print_test "network" "Firewall Port 1935" "PASS" "Firewall allows port 1935"
        else
            print_test "network" "Firewall Port 1935" "WARN" "Firewall may not allow port 1935"
        fi
        
        if ufw status | grep -q "1936/tcp"; then
            print_test "network" "Firewall Port 1936" "PASS" "Firewall allows port 1936"
        else
            print_test "network" "Firewall Port 1936" "WARN" "Firewall may not allow port 1936"
        fi
    else
        print_test "network" "Firewall Port 80" "SKIP" "UFW not available"
        print_test "network" "Firewall Port 1935" "SKIP" "UFW not available"
        print_test "network" "Firewall Port 1936" "SKIP" "UFW not available"
    fi
    
    # Step 6: Database Check
    echo ""
    print_step "Step 6: Database Check"
    
    # Check database connectivity
    if [ -f "/home/ubuntu/SCTE-streamcontrol/dev.db" ]; then
        print_test "database" "Database File" "PASS" "Database file exists"
        
        # Test database operations
        cd /home/ubuntu/SCTE-streamcontrol
        if npm run db:push >/dev/null 2>&1; then
            print_test "database" "Database Operations" "PASS" "Database operations work"
        else
            print_test "database" "Database Operations" "FAIL" "Database operations failed"
        fi
    else
        print_test "database" "Database File" "FAIL" "Database file not found"
        print_test "database" "Database Operations" "SKIP" "Database not available"
    fi
    
    # Step 7: Security Check
    echo ""
    print_step "Step 7: Security Check"
    
    # Check for basic security headers
    if command_exists curl; then
        local headers=$(curl -s -I http://localhost/health 2>/dev/null || true)
        if echo "$headers" | grep -q "X-Frame-Options"; then
            print_test "security" "X-Frame-Options Header" "PASS" "Security header present"
        else
            print_test "security" "X-Frame-Options Header" "WARN" "Security header missing"
        fi
        
        if echo "$headers" | grep -q "X-Content-Type-Options"; then
            print_test "security" "X-Content-Type-Options Header" "PASS" "Security header present"
        else
            print_test "security" "X-Content-Type-Options Header" "WARN" "Security header missing"
        fi
    else
        print_test "security" "X-Frame-Options Header" "SKIP" "curl not available"
        print_test "security" "X-Content-Type-Options Header" "SKIP" "curl not available"
    fi
    
    # Check for default credentials
    if file_exists "/home/ubuntu/SCTE-streamcontrol/.env"; then
        if grep -q "password.*default" "/home/ubuntu/SCTE-streamcontrol/.env"; then
            print_test "security" "Default Credentials" "FAIL" "Default credentials detected"
        else
            print_test "security" "Default Credentials" "PASS" "No default credentials found"
        fi
    else
        print_test "security" "Default Credentials" "SKIP" "Environment file not found"
    fi
    
    # Step 8: Performance Check
    echo ""
    print_step "Step 8: Performance Check"
    
    # Check system resources
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free | awk 'NR==2{printf "%.2f", $3/$2*100}')
    local disk_usage=$(df / | awk 'NR==2{printf "%s", $5}')
    
    print_info "System Resources: CPU ${cpu_usage}%, Memory ${memory_usage}%, Disk ${disk_usage}"
    
    # Check file descriptors
    local file_limit=$(ulimit -n)
    if [ "$file_limit" -ge 65536 ]; then
        print_test "performance" "File Descriptor Limit" "PASS" "Limit: $file_limit"
    else
        print_test "performance" "File Descriptor Limit" "WARN" "Limit low: $file_limit"
    fi
    
    # Check memory usage
    if (( $(echo "$memory_usage < 80" | bc -l) )); then
        print_test "performance" "Memory Usage" "PASS" "Usage: ${memory_usage}%"
    else
        print_test "performance" "Memory Usage" "WARN" "Usage high: ${memory_usage}%"
    fi
    
    # Check disk usage
    local disk_percent=$(echo "$disk_usage" | cut -d'%' -f1)
    if [ "$disk_percent" -lt 80 ]; then
        print_test "performance" "Disk Usage" "PASS" "Usage: ${disk_usage}"
    else
        print_test "performance" "Disk Usage" "WARN" "Usage high: ${disk_usage}"
    fi
    
    # Step 9: Integration Testing
    echo ""
    print_step "Step 9: Integration Testing"
    
    # Test FFmpeg integration
    if command_exists ffmpeg && [ -f "/usr/local/bin/test-ffmpeg-scte35.sh" ]; then
        print_ffmpeg "Running FFmpeg SCTE-35 integration test..."
        if /usr/local/bin/test-ffmpeg-scte35.sh >/dev/null 2>&1; then
            print_test "integration" "FFmpeg Integration" "PASS" "FFmpeg integration test passed"
        else
            print_test "integration" "FFmpeg Integration" "FAIL" "FFmpeg integration test failed"
        fi
    else
        print_test "integration" "FFmpeg Integration" "SKIP" "FFmpeg or test script not available"
    fi
    
    # Test web application health
    if command_exists curl; then
        if curl -s http://localhost/health | grep -q "healthy"; then
            print_test "integration" "Health Endpoint" "PASS" "Health endpoint responding"
        else
            print_test "integration" "Health Endpoint" "FAIL" "Health endpoint not responding"
        fi
        
        if curl -s http://localhost/stat | grep -q "RTMP"; then
            print_test "integration" "RTMP Statistics" "PASS" "RTMP statistics available"
        else
            print_test "integration" "RTMP Statistics" "FAIL" "RTMP statistics not available"
        fi
    else
        print_test "integration" "Health Endpoint" "SKIP" "curl not available"
        print_test "integration" "RTMP Statistics" "SKIP" "curl not available"
    fi
    
    # Test complete deployment functionality
    if service_is_running nginx && pm2 status | grep -q 'scte35-app.*online' && command_exists ffmpeg; then
        print_test "integration" "Complete Deployment" "PASS" "All major components running"
    else
        print_test "integration" "Complete Deployment" "FAIL" "One or more major components not running"
    fi
    
    # Generate JSON report
    generate_json_report "$REPORT_FILE"
    
    # Show summary
    show_test_summary
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Function to handle script interruption
handle_interrupt() {
    echo ""
    print_warning "Script interrupted by user"
    print_info "Generating partial report..."
    generate_json_report "$REPORT_FILE"
    print_info "Log file available at: $LOG_FILE"
    print_info "JSON report available at: $REPORT_FILE"
    exit 1
}

# Set up interrupt handlers
trap handle_interrupt INT TERM

# Function to show help
show_help() {
    echo "SCTE-35 Streaming Platform - Enhanced Verification Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --verbose       Enable verbose logging"
    echo "  -q, --quiet         Quiet mode (minimal output)"
    echo "  -j, --json-only     Only generate JSON report"
    echo "  -c, --category CAT  Test specific category only"
    echo "  -l, --log FILE      Specify custom log file"
    echo "  -r, --report FILE   Specify custom report file"
    echo ""
    echo "Available Categories:"
    for category in "${!TEST_CATEGORIES[@]}"; do
        echo "  $category - ${TEST_CATEGORIES[$category]}"
    done
    echo ""
    echo "Examples:"
    echo "  $0                  # Standard verification"
    echo "  $0 --verbose        # Verbose verification"
    echo "  $0 --category ffmpeg # Test FFmpeg only"
    echo "  $0 --json-only      # Generate JSON report only"
    echo ""
    echo "For more information, refer to the documentation."
}

# Parse command line arguments
VERBOSE=false
QUIET=false
JSON_ONLY=false
SPECIFIC_CATEGORY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -j|--json-only)
            JSON_ONLY=true
            shift
            ;;
        -c|--category)
            SPECIFIC_CATEGORY="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -r|--report)
            REPORT_FILE="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main verification
main "$@"

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