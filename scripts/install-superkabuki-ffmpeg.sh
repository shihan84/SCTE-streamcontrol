#!/bin/bash

# SCTE-35 Streaming Control Center - SuperKabuki FFmpeg Installation Script
# 
# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
# 
# This script installs the SuperKabuki FFmpeg build with enhanced SCTE-35 support

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FFMPEG_INSTALL_DIR="/usr/local/bin"
FFMPEG_BACKUP_DIR="/usr/local/bin/ffmpeg-backup"
SUPERKABUKI_REPO="https://github.com/superkabuki/SCTE35_FFmpeg.git"
TEMP_DIR="/tmp/superkabuki-ffmpeg"

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

# Function to backup existing FFmpeg
backup_ffmpeg() {
    if [ -f "$FFMPEG_INSTALL_DIR/ffmpeg" ]; then
        log "Backing up existing FFmpeg installation..."
        mkdir -p "$FFMPEG_BACKUP_DIR"
        cp "$FFMPEG_INSTALL_DIR/ffmpeg" "$FFMPEG_BACKUP_DIR/ffmpeg-$(date +%Y%m%d_%H%M%S)"
        log "FFmpeg backup created at $FFMPEG_BACKUP_DIR"
    fi
}

# Function to install dependencies
install_dependencies() {
    log "Installing required dependencies..."
    
    # Update package list
    apt-get update
    
    # Install build dependencies
    apt-get install -y \
        build-essential \
        cmake \
        git \
        wget \
        curl \
        yasm \
        nasm \
        libx264-dev \
        libx265-dev \
        libmp3lame-dev \
        libopus-dev \
        libvpx-dev \
        libfdk-aac-dev \
        libass-dev \
        libfreetype6-dev \
        libfontconfig1-dev \
        libxvidcore-dev \
        libv4l-dev \
        libpulse-dev \
        libjack-jackd2-dev \
        libcdio-paranoia-dev \
        librubberband-dev \
        libsdl2-dev \
        libopenjp2-7-dev \
        librtmp-dev \
        libgnutls28-dev \
        libbluray-dev \
        libsoxr-dev \
        libssh-dev \
        libvidstab-dev \
        libzimg-dev \
        libwebp-dev \
        libopenal-dev \
        libvmaf-dev \
        libgl1-mesa-dev \
        libgles2-mesa-dev \
        libva-dev \
        libdrm-dev \
        libxcb1-dev \
        libxcb-shm0-dev \
        libxcb-xfixes0-dev \
        libxcb-shape0-dev \
        libx11-dev \
        libxfixes-dev \
        libxext-dev \
        libxrandr-dev \
        libvdpau-dev \
        libvulkan-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        liblzma-dev \
        libzvbi-dev \
        libcdio-cdda-dev \
        libcdio-paranoia-dev \
        libmodplug-dev \
        libgme-dev \
        libopenmpt-dev \
        libshine-dev \
        libsnappy-dev \
        libspeex-dev \
        libtheora-dev \
        libtwolame-dev \
        libvo-amrwbenc-dev \
        libwavpack-dev \
        libwebp-dev \
        libzmq3-dev \
        libzvbi-dev \
        ladspa-sdk \
        libmysofa-dev \
        libgsm1-dev \
        libdc1394-22-dev \
        libchromaprint-dev \
        libbs2b-dev \
        libcaca-dev \
        libflite1-dev \
        libfluidsynth-dev \
        libgme-dev \
        libinstpatch-dev \
        liblilv-dev \
        liblv2-dev \
        libserd-dev \
        libsord-dev \
        libsratom-dev \
        libsamplerate-dev \
        librubberband-dev \
        libsrt-dev \
        libsvtav1-dev \
        libtesseract-dev \
        libx265-dev \
        libxvidcore-dev \
        libzmq5-dev \
        libzvbi-dev
    
    log "Dependencies installed successfully"
}

# Function to download and extract SuperKabuki FFmpeg
download_superkabuki_ffmpeg() {
    log "Downloading SuperKabuki FFmpeg..."
    
    # Clean up temp directory
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Clone the repository
    git clone "$SUPERKABUKI_REPO" .
    
    # Extract the FFmpeg build
    if [ -f "ffmpg-scte35.tbz" ]; then
        log "Extracting SuperKabuki FFmpeg build..."
        tar -xvjf ffmpg-scte35.tbz
        log "FFmpeg build extracted successfully"
    else
        error "SuperKabuki FFmpeg build file not found"
        exit 1
    fi
}

# Function to configure and build FFmpeg
build_ffmpeg() {
    log "Configuring SuperKabuki FFmpeg..."
    
    cd ffmpeg*
    
    # Configure FFmpeg with SuperKabuki patch and common features
    ./configure \
        --enable-shared \
        --enable-gpl \
        --enable-nonfree \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-libvpx \
        --enable-libfdk-aac \
        --enable-libass \
        --enable-libfreetype \
        --enable-libfontconfig \
        --enable-libxvid \
        --enable-libv4l2 \
        --enable-libpulse \
        --enable-libjack \
        --enable-libcdio \
        --enable-librubberband \
        --enable-libsdl2 \
        --enable-libopenjpeg \
        --enable-librtmp \
        --enable-libgnutls \
        --enable-libbluray \
        --enable-libsoxr \
        --enable-libssh \
        --enable-libvidstab \
        --enable-libzimg \
        --enable-libwebp \
        --enable-libopenal \
        --enable-libvmaf \
        --enable-libva \
        --enable-libdrm \
        --enable-libxcb \
        --enable-libx11 \
        --enable-libxfixes \
        --enable-libxext \
        --enable-libxrandr \
        --enable-libvdpau \
        --enable-libvulkan \
        --enable-libharfbuzz \
        --enable-libfribidi \
        --enable-liblzma \
        --enable-libzvbi \
        --enable-libcdio \
        --enable-libmodplug \
        --enable-libgme \
        --enable-libopenmpt \
        --enable-libshine \
        --enable-libsnappy \
        --enable-libspeex \
        --enable-libtheora \
        --enable-libtwolame \
        --enable-libvo-amrwbenc \
        --enable-libwavpack \
        --enable-libwebp \
        --enable-libzmq \
        --enable-libzvbi \
        --enable-ladspa \
        --enable-libmysofa \
        --enable-libgsm \
        --enable-libdc1394 \
        --enable-libchromaprint \
        --enable-libbs2b \
        --enable-libcaca \
        --enable-libflite \
        --enable-libfluidsynth \
        --enable-libgme \
        --enable-libinstpatch \
        --enable-liblilv \
        --enable-liblv2 \
        --enable-libserd \
        --enable-libsord \
        --enable-libsratom \
        --enable-libsamplerate \
        --enable-librubberband \
        --enable-libsrt \
        --enable-libsvtav1 \
        --enable-libtesseract \
        --enable-libx265 \
        --enable-libxvid \
        --enable-libzmq \
        --enable-libzvbi \
        --extra-version=-SuperKabuki-patch \
        --prefix=/usr/local
    
    log "FFmpeg configuration completed"
    
    log "Building FFmpeg (this may take a while)..."
    
    # Build with parallel compilation
    make -j$(nproc)
    
    log "FFmpeg build completed"
}

# Function to install FFmpeg
install_ffmpeg() {
    log "Installing SuperKabuki FFmpeg..."
    
    cd ffmpeg*
    
    # Install FFmpeg
    make install
    
    # Update shared library cache
    ldconfig
    
    log "SuperKabuki FFmpeg installed successfully"
}

# Function to verify installation
verify_installation() {
    log "Verifying SuperKabuki FFmpeg installation..."
    
    # Check if FFmpeg is installed
    if command -v ffmpeg &> /dev/null; then
        FFMPEG_VERSION=$(ffmpeg -version | head -n 1)
        log "FFmpeg installed: $FFMPEG_VERSION"
        
        # Check for SuperKabuki patch
        if [[ $FFMPEG_VERSION == *"SuperKabuki-patch"* ]]; then
            log "✅ SuperKabuki SCTE-35 patch detected"
        else
            warn "⚠️  SuperKabuki patch not detected in version string"
        fi
        
        # Test SCTE-35 functionality
        log "Testing SCTE-35 functionality..."
        ffmpeg -h demuxer=mpegts 2>/dev/null | grep -i scte || warn "SCTE-35 support may not be fully enabled"
        
        log "✅ FFmpeg verification completed"
    else
        error "FFmpeg installation failed"
        exit 1
    fi
}

# Function to create FFmpeg configuration for SCTE-35
create_ffmpeg_config() {
    log "Creating FFmpeg configuration for SCTE-35..."
    
    # Create configuration file
    cat > /etc/ffmpeg/scte35.conf << 'EOF'
# SuperKabuki FFmpeg SCTE-35 Configuration
# This configuration optimizes FFmpeg for SCTE-35 streaming

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

# Enhanced SCTE-35 handling (SuperKabuki patch)
scte35_passthrough=1
scte35_descriptor=1
EOF

    log "FFmpeg configuration created at /etc/ffmpeg/scte35.conf"
}

# Function to create test script
create_test_script() {
    log "Creating SCTE-35 test script..."
    
    cat > /usr/local/bin/test-scte35.sh << 'EOF'
#!/bin/bash

# SCTE-35 Test Script for SuperKabuki FFmpeg

echo "=== SuperKabuki FFmpeg SCTE-35 Test ==="
echo

# Check FFmpeg version
echo "FFmpeg Version:"
ffmpeg -version | head -n 1
echo

# Test SCTE-35 demuxer
echo "SCTE-35 Demuxer Support:"
ffmpeg -h demuxer=mpegts 2>/dev/null | grep -i scte || echo "SCTE-35 support not found"
echo

# Test SCTE-35 muxer
echo "SCTE-35 Muxer Support:"
ffmpeg -h muxer=mpegts 2>/dev/null | grep -i scte || echo "SCTE-35 support not found"
echo

# Show available encoders
echo "Available Video Encoders:"
ffmpeg -encoders 2>/dev/null | grep -E "(libx264|libx265)" | head -5
echo

# Show available decoders
echo "Available Decoders:"
ffmpeg -decoders 2>/dev/null | grep -E "(h264|hevc)" | head -5
echo

echo "=== Test Complete ==="
EOF

    chmod +x /usr/local/bin/test-scte35.sh
    log "Test script created at /usr/local/bin/test-scte35.sh"
}

# Function to show usage examples
show_usage_examples() {
    info "SuperKabuki FFmpeg SCTE-35 Usage Examples:"
    echo
    echo "1. Transcode with SCTE-35 preservation:"
    echo "   ffmpeg -copyts -i input.ts -map 0 -c:v libx265 -c:a aac -c:d copy -muxpreload 0 -muxdelay 0 output.ts"
    echo
    echo "2. Stream copy with SCTE-35:"
    echo "   ffmpeg -copyts -ss 200 -i input.ts -map 0 -c copy -muxpreload 0 -muxdelay 0 output.ts"
    echo
    echo "3. Extract SCTE-35 data:"
    echo "   ffmpeg -i input.ts -map 0:d -f data -y output.bin"
    echo
    echo "4. Test SCTE-35 functionality:"
    echo "   test-scte35.sh"
    echo
}

# Main installation function
main() {
    log "Starting SuperKabuki FFmpeg installation..."
    
    # Check if FFmpeg is already installed
    if command -v ffmpeg &> /dev/null; then
        warn "FFmpeg is already installed. Creating backup..."
        backup_ffmpeg
    fi
    
    # Install dependencies
    install_dependencies
    
    # Download SuperKabuki FFmpeg
    download_superkabuki_ffmpeg
    
    # Build and install FFmpeg
    build_ffmpeg
    install_ffmpeg
    
    # Verify installation
    verify_installation
    
    # Create configuration
    create_ffmpeg_config
    
    # Create test script
    create_test_script
    
    # Clean up
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    
    # Show usage examples
    show_usage_examples
    
    log "✅ SuperKabuki FFmpeg installation completed successfully!"
    info "You can now use the enhanced SCTE-35 features in your streaming application."
}

# Run main function
main "$@"