#!/bin/bash

# SCTE-35 Streaming Control Center - SCTE-35 Validation Script
# 
# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
# 
# This script validates SCTE-35 preservation and SuperKabuki FFmpeg functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INPUT_FILE="$1"
OUTPUT_FILE="$2"

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <input_file> <output_file>"
    echo ""
    echo "This script validates SCTE-35 preservation between input and output files"
    echo "using SuperKabuki FFmpeg with enhanced SCTE-35 support."
    echo ""
    echo "Example:"
    echo "  $0 input.ts output.ts"
    echo ""
}

# Function to check if FFmpeg is available
check_ffmpeg() {
    if ! command -v ffmpeg &> /dev/null; then
        error "FFmpeg is not installed or not in PATH"
        exit 1
    fi
    
    # Check for SuperKabuki patch
    FFMPEG_VERSION=$(ffmpeg -version | head -n 1)
    if [[ $FFMPEG_VERSION == *"SuperKabuki-patch"* ]]; then
        log "✅ SuperKabuki FFmpeg detected"
    else
        warn "⚠️  SuperKabuki patch not detected in FFmpeg version"
        warn "   Consider installing SuperKabuki FFmpeg for enhanced SCTE-35 support"
    fi
}

# Function to validate input files
validate_files() {
    if [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
        error "Both input and output files must be specified"
        show_usage
        exit 1
    fi
    
    if [ ! -f "$INPUT_FILE" ]; then
        error "Input file '$INPUT_FILE' does not exist"
        exit 1
    fi
    
    if [ ! -f "$OUTPUT_FILE" ]; then
        error "Output file '$OUTPUT_FILE' does not exist"
        exit 1
    fi
    
    log "✅ Input file: $INPUT_FILE"
    log "✅ Output file: $OUTPUT_FILE"
}

# Function to extract SCTE-35 data
extract_scte35_data() {
    local file="$1"
    local prefix="$2"
    
    info "Extracting SCTE-35 data from $prefix file..."
    
    # Create temporary file for SCTE-35 data
    local temp_file="/tmp/${prefix}_scte35_$(date +%s).bin"
    
    # Extract SCTE-35 data using FFmpeg
    if ffmpeg -i "$file" -map 0:d -f data -y "$temp_file" 2>/dev/null; then
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            local file_size=$(stat -c%s "$temp_file")
            echo "$file_size"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
    
    # Clean up
    rm -f "$temp_file"
}

# Function to count SCTE-35 events
count_scte35_events() {
    local file="$1"
    local prefix="$2"
    
    info "Counting SCTE-35 events in $prefix file..."
    
    # Use FFprobe to analyze SCTE-35 data
    local event_count=$(ffprobe -v error -show_frames -show_entries frame=pict_type,pkt_pts_time,pkt_dts_time -select_streams d "$file" 2>/dev/null | grep -c "pict_type=I" || echo "0")
    
    echo "$event_count"
}

# Function to validate timestamp preservation
validate_timestamps() {
    local input_file="$1"
    local output_file="$2"
    
    info "Validating timestamp preservation..."
    
    # Get duration of both files
    local input_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null || echo "0")
    local output_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$output_file" 2>/dev/null || echo "0")
    
    # Calculate duration difference
    local duration_diff=$(echo "$input_duration - $output_duration" | bc -l 2>/dev/null || echo "0")
    local duration_diff_abs=$(echo "if ($duration_diff < 0) -$duration_diff else $duration_diff" | bc -l 2>/dev/null || echo "0")
    
    # Check if duration difference is acceptable (within 1 second)
    local threshold=1.0
    if (( $(echo "$duration_diff_abs <= $threshold" | bc -l) )); then
        log "✅ Timestamp preservation: Good (diff: ${duration_diff_abs}s)"
        return 0
    else
        warn "⚠️  Timestamp preservation: Poor (diff: ${duration_diff_abs}s)"
        return 1
    fi
}

# Function to check for SuperKabuki specific features
check_superkabuki_features() {
    local file="$1"
    local prefix="$2"
    
    info "Checking SuperKabuki features in $prefix file..."
    
    # Check for SCTE-35 descriptor
    local has_descriptor=$(ffprobe -v error -show_entries frame=side_data_list -select_streams d "$file" 2>/dev/null | grep -c "CUEI" || echo "0")
    
    # Check for passthrough metadata
    local has_passthrough=$(ffprobe -v error -show_format -show_streams "$file" 2>/dev/null | grep -c "scte35" || echo "0")
    
    echo "$has_descriptor:$has_passthrough"
}

# Function to generate validation report
generate_report() {
    local input_data_size="$1"
    local output_data_size="$2"
    local input_events="$3"
    local output_events="$4"
    local timestamp_ok="$5"
    local input_features="$6"
    local output_features="$7"
    
    echo ""
    echo "=== SCTE-35 Validation Report ==="
    echo ""
    
    # Data preservation
    if [ "$input_data_size" -gt 0 ] && [ "$output_data_size" -gt 0 ]; then
        local preservation_rate=$(echo "scale=2; $output_data_size * 100 / $input_data_size" | bc -l 2>/dev/null || echo "0")
        echo "📊 SCTE-35 Data Preservation:"
        echo "   Input data size: $input_data_size bytes"
        echo "   Output data size: $output_data_size bytes"
        echo "   Preservation rate: ${preservation_rate}%"
        
        if (( $(echo "$preservation_rate >= 95" | bc -l) )); then
            echo "   Status: ✅ Excellent"
        elif (( $(echo "$preservation_rate >= 80" | bc -l) )); then
            echo "   Status: ⚠️  Good"
        else
            echo "   Status: ❌ Poor"
        fi
    else
        echo "📊 SCTE-35 Data Preservation:"
        echo "   Input data size: $input_data_size bytes"
        echo "   Output data size: $output_data_size bytes"
        echo "   Status: ❌ No SCTE-35 data detected"
    fi
    
    echo ""
    
    # Event preservation
    echo "🎯 SCTE-35 Event Preservation:"
    echo "   Input events: $input_events"
    echo "   Output events: $output_events"
    
    if [ "$input_events" -gt 0 ] && [ "$output_events" -gt 0 ]; then
        local event_preservation=$(echo "scale=2; $output_events * 100 / $input_events" | bc -l 2>/dev/null || echo "0")
        echo "   Event preservation rate: ${event_preservation}%"
        
        if (( $(echo "$event_preservation >= 95" | bc -l) )); then
            echo "   Status: ✅ Excellent"
        elif (( $(echo "$event_preservation >= 80" | bc -l) )); then
            echo "   Status: ⚠️  Good"
        else
            echo "   Status: ❌ Poor"
        fi
    else
        echo "   Status: ❌ No SCTE-35 events detected"
    fi
    
    echo ""
    
    # Timestamp preservation
    echo "⏰ Timestamp Preservation:"
    if [ "$timestamp_ok" -eq 0 ]; then
        echo "   Status: ✅ Good"
    else
        echo "   Status: ⚠️  Issues detected"
    fi
    
    echo ""
    
    # SuperKabuki features
    echo "🚀 SuperKabuki Features:"
    
    IFS=':' read -r input_desc input_passthrough <<< "$input_features"
    IFS=':' read -r output_desc output_passthrough <<< "$output_features"
    
    echo "   Input file:"
    echo "     Descriptor support: $([ "$input_desc" -gt 0 ] && echo "✅ Yes" || echo "❌ No")"
    echo "     Passthrough support: $([ "$input_passthrough" -gt 0 ] && echo "✅ Yes" || echo "❌ No")"
    
    echo "   Output file:"
    echo "     Descriptor support: $([ "$output_desc" -gt 0 ] && echo "✅ Yes" || echo "❌ No")"
    echo "     Passthrough support: $([ "$output_passthrough" -gt 0 ] && echo "✅ Yes" || echo "❌ No")"
    
    echo ""
    
    # Overall assessment
    echo "📋 Overall Assessment:"
    local overall_score=0
    local max_score=100
    
    # Data preservation (40 points)
    if [ "$input_data_size" -gt 0 ] && [ "$output_data_size" -gt 0 ]; then
        local preservation_rate=$(echo "scale=2; $output_data_size * 100 / $input_data_size" | bc -l 2>/dev/null || echo "0")
        local data_score=$(echo "scale=0; $preservation_rate * 40 / 100" | bc -l 2>/dev/null || echo "0")
        overall_score=$(echo "scale=0; $overall_score + $data_score" | bc -l 2>/dev/null || echo "0")
    fi
    
    # Event preservation (30 points)
    if [ "$input_events" -gt 0 ] && [ "$output_events" -gt 0 ]; then
        local event_preservation=$(echo "scale=2; $output_events * 100 / $input_events" | bc -l 2>/dev/null || echo "0")
        local event_score=$(echo "scale=0; $event_preservation * 30 / 100" | bc -l 2>/dev/null || echo "0")
        overall_score=$(echo "scale=0; $overall_score + $event_score" | bc -l 2>/dev/null || echo "0")
    fi
    
    # Timestamp preservation (20 points)
    if [ "$timestamp_ok" -eq 0 ]; then
        overall_score=$(echo "scale=0; $overall_score + 20" | bc -l 2>/dev/null || echo "0")
    fi
    
    # SuperKabuki features (10 points)
    if [ "$output_desc" -gt 0 ]; then
        overall_score=$(echo "scale=0; $overall_score + 5" | bc -l 2>/dev/null || echo "0")
    fi
    if [ "$output_passthrough" -gt 0 ]; then
        overall_score=$(echo "scale=0; $overall_score + 5" | bc -l 2>/dev/null || echo "0")
    fi
    
    echo "   Overall Score: ${overall_score}/${max_score}"
    
    if (( $(echo "$overall_score >= 90" | bc -l) )); then
        echo "   Grade: 🏆 Excellent"
    elif (( $(echo "$overall_score >= 80" | bc -l) )); then
        echo "   Grade: ✅ Good"
    elif (( $(echo "$overall_score >= 70" | bc -l) )); then
        echo "   Grade: ⚠️  Fair"
    else
        echo "   Grade: ❌ Poor"
    fi
    
    echo ""
    echo "=== End of Report ==="
}

# Main validation function
main() {
    log "Starting SCTE-35 validation..."
    
    # Check if FFmpeg is available
    check_ffmpeg
    
    # Validate input files
    validate_files
    
    # Extract SCTE-35 data
    local input_data_size=$(extract_scte35_data "$INPUT_FILE" "input")
    local output_data_size=$(extract_scte35_data "$OUTPUT_FILE" "output")
    
    # Count SCTE-35 events
    local input_events=$(count_scte35_events "$INPUT_FILE" "input")
    local output_events=$(count_scte35_events "$OUTPUT_FILE" "output")
    
    # Validate timestamp preservation
    validate_timestamps "$INPUT_FILE" "$OUTPUT_FILE"
    local timestamp_ok=$?
    
    # Check SuperKabuki features
    local input_features=$(check_superkabuki_features "$INPUT_FILE" "input")
    local output_features=$(check_superkabuki_features "$OUTPUT_FILE" "output")
    
    # Generate report
    generate_report "$input_data_size" "$output_data_size" "$input_events" "$output_events" "$timestamp_ok" "$input_features" "$output_features"
    
    log "✅ SCTE-35 validation completed"
}

# Run main function
main "$@"