# SuperKabuki FFmpeg Integration Guide

## Overview

This guide explains how to integrate and use the SuperKabuki FFmpeg patch with the SCTE-35 Streaming Control Center. The SuperKabuki patch provides enhanced SCTE-35 support including passthrough, descriptor support, and improved timestamp preservation.

## What is SuperKabuki FFmpeg?

SuperKabuki FFmpeg is a custom build of FFmpeg with a specialized patch that enhances SCTE-35 handling capabilities:

### Key Features
- **SCTE-35 Passthrough**: Copy SCTE-35 streams as SCTE-35 during encoding
- **Descriptor Support**: Adds SCTE-35 Descriptor (CUEI / 0x49455543)
- **Minimal Patch**: Only 7 lines of code added to two FFmpeg files
- **Full Compatibility**: Works like standard FFmpeg but with enhanced SCTE-35 support

### Technical Details
The patch modifies:
- `libavformat/mpegts.c` - MPEG-TS demuxer enhancements
- `libavformat/mpegtsenc.c` - MPEG-TS muxer enhancements

## Installation

### Automated Installation

The easiest way to install SuperKabuki FFmpeg is through our automated script:

```bash
# Install SuperKabuki FFmpeg
sudo ./scripts/install-superkabuki-ffmpeg.sh

# Verify installation
test-scte35.sh
```

### Manual Installation

For manual installation, follow these steps:

1. **Clone the SuperKabuki repository**:
```bash
git clone https://github.com/superkabuki/SCTE35_FFmpeg.git
cd SCTE35_FFmpeg
```

2. **Extract the FFmpeg build**:
```bash
tar -xvjf ffmpg-scte35.tbz
```

3. **Configure and build**:
```bash
cd ffmpeg*
./configure --enable-shared --extra-version=-SuperKabuki-patch --enable-gpl --enable-nonfree --enable-libx264 --enable-libx265
make all
sudo make install
```

4. **Update shared library cache**:
```bash
sudo ldconfig
```

## Configuration

### FFmpeg Configuration

The SuperKabuki FFmpeg is configured with the following SCTE-35 enhancements:

```json
{
  "ffmpeg": {
    "path": "/usr/local/bin/ffmpeg",
    "version": "SuperKabuki-patch",
    "features": {
      "scte35_passthrough": true,
      "scte35_descriptor": true,
      "copyts": true,
      "muxpreload": 0,
      "muxdelay": 0
    }
  },
  "scte35": {
    "pid": 500,
    "null_pid": 8191,
    "auto_insert": true
  }
}
```

### Application Configuration

The streaming control center automatically detects and uses SuperKabuki FFmpeg when available. The configuration is stored in:

```bash
config/superkabuki-ffmpeg-config.json
```

## Usage Examples

### Basic SCTE-35 Transcoding

```bash
# Transcode while preserving SCTE-35 markers
ffmpeg -copyts -i input.ts -map 0 -c:v libx265 -c:a aac -c:d copy -muxpreload 0 -muxdelay 0 output.ts
```

### Stream Copy with SCTE-35

```bash
# Copy streams while preserving SCTE-35
ffmpeg -copyts -ss 200 -i input.ts -map 0 -c copy -muxpreload 0 -muxdelay 0 output.ts
```

### SCTE-35 Data Extraction

```bash
# Extract SCTE-35 data for analysis
ffmpeg -i input.ts -map 0:d -f data -y output.bin
```

### HLS Streaming with SCTE-35

```bash
# Create HLS stream with SCTE-35 support
ffmpeg -copyts -i input.ts \
  -c:v libx264 -c:a aac -c:d copy \
  -f hls \
  -hls_time 2 -hls_list_size 6 \
  -hls_flags delete_segments+independent_segments \
  -muxpreload 0 -muxdelay 0 \
  -metadata scte35=true \
  output.m3u8
```

### DASH Streaming with SCTE-35

```bash
# Create DASH stream with SCTE-35 support
ffmpeg -copyts -i input.ts \
  -c:v libx264 -c:a aac -c:d copy \
  -f dash \
  -seg_duration 2 -window_size 6 \
  -use_template 1 -use_timeline 1 \
  -muxpreload 0 -muxdelay 0 \
  -metadata scte35=true \
  output.mpd
```

## Integration with Streaming Control Center

### Automatic Detection

The streaming control center automatically detects SuperKabuki FFmpeg and enables enhanced features:

```typescript
// Check for SuperKabuki FFmpeg
const ffmpegVersion = execSync('ffmpeg -version').toString();
const hasSuperKabuki = ffmpegVersion.includes('SuperKabuki-patch');

if (hasSuperKabuki) {
  // Enable enhanced SCTE-35 features
  config.scte35.enhanced = true;
  config.scte35.passthrough = true;
  config.scte35.descriptor = true;
}
```

### Enhanced FFmpeg Arguments

When SuperKabuki FFmpeg is detected, the streaming control center automatically adds these arguments:

```typescript
const args = [
  '-copyts',           // Preserve timestamps
  '-c:d', 'copy',      // Copy SCTE-35 data
  '-muxpreload', '0',  // No preload
  '-muxdelay', '0',    // No delay
  '-metadata', 'scte35=true',
  '-metadata', 'scte35_passthrough=true',
  '-metadata', 'scte35_descriptor=true'
];
```

### SCTE-35 Validation

The control center includes enhanced validation for SCTE-35 preservation:

```typescript
// Validate SCTE-35 preservation
const validation = await scte35Injector.validateSCTE35Preservation(
  'input.ts',
  'output.ts'
);

console.log(`Preservation rate: ${validation.preservationRate}%`);
console.log(`Details: ${validation.details.join(', ')}`);
```

## Validation and Testing

### Automated Testing

Use the validation script to test SCTE-35 preservation:

```bash
# Validate SCTE-35 preservation between files
./scripts/validate-scte35.sh input.ts output.ts
```

### Manual Testing

Test SuperKabuki FFmpeg functionality:

```bash
# Test SuperKabuki installation
test-scte35.sh

# Check FFmpeg version
ffmpeg -version | head -n 1

# Test SCTE-35 demuxer
ffmpeg -h demuxer=mpegts | grep -i scte

# Test SCTE-35 muxer
ffmpeg -h muxer=mpegts | grep -i scte
```

### Performance Testing

Test performance with SCTE-35 streams:

```bash
# Performance test with SCTE-35
time ffmpeg -copyts -i input.ts \
  -c:v libx264 -c:a aac -c:d copy \
  -muxpreload 0 -muxdelay 0 \
  output.ts

# Check CPU usage
top -p $(pgrep ffmpeg)
```

## Troubleshooting

### Common Issues

#### FFmpeg Not Found
```bash
# Check if FFmpeg is installed
which ffmpeg

# Check PATH
echo $PATH

# Reinstall if necessary
sudo ./scripts/install-superkabuki-ffmpeg.sh
```

#### SuperKabuki Patch Not Detected
```bash
# Check FFmpeg version
ffmpeg -version

# Look for SuperKabuki in version string
ffmpeg -version | grep SuperKabuki

# Reinstall with patch
sudo ./scripts/install-superkabuki-ffmpeg.sh
```

#### SCTE-35 Data Not Preserved
```bash
# Validate SCTE-35 preservation
./scripts/validate-scte35.sh input.ts output.ts

# Check if copyts is being used
ffmpeg -i input.ts -copyts -c copy output.ts

# Verify SCTE-35 PID configuration
ffmpeg -i input.ts -scte35_pid 500 -c copy output.ts
```

### Debug Commands

```bash
# Check FFmpeg build configuration
ffmpeg -buildconf

# Check available codecs
ffmpeg -codecs | grep -E "(h264|hevc|aac)"

# Check available formats
ffmpeg -formats | grep -E "(mpegts|hls|dash)"

# Check available bitstream filters
ffmpeg -bsfs | grep -i scte

# Check available protocols
ffmpeg -protocols | grep -E "(rtmp|srt|http)"
```

### Log Analysis

```bash
# Monitor FFmpeg output in real-time
ffmpeg -copyts -i input.ts -c copy output.ts 2>&1 | tee ffmpeg.log

# Analyze SCTE-35 related messages
grep -i scte ffmpeg.log

# Check for errors
grep -i error ffmpeg.log

# Check for warnings
grep -i warning ffmpeg.log
```

## Best Practices

### Configuration Best Practices

1. **Always use `-copyts`**: This preserves timestamps critical for SCTE-35
2. **Set `-muxpreload 0` and `-muxdelay 0`**: Prevents timing issues
3. **Use `-c:d copy`**: Ensures SCTE-35 data streams are copied
4. **Add metadata**: Include `scte35=true` and related metadata

### Performance Best Practices

1. **Use appropriate codecs**: H.264 for compatibility, H.265 for efficiency
2. **Optimize GOP structure**: 12-frame GOP with 5 B-frames
3. **Monitor resource usage**: Keep CPU usage below 80%
4. **Test with real content**: Validate with actual broadcast streams

### Monitoring Best Practices

1. **Regular validation**: Use the validation script regularly
2. **Monitor preservation rates**: Aim for 95%+ SCTE-35 preservation
3. **Check timestamp accuracy**: Ensure timestamps are preserved
4. **Log analysis**: Regularly review FFmpeg logs for issues

## Integration Checklist

- [ ] Install SuperKabuki FFmpeg
- [ ] Verify installation with `test-scte35.sh`
- [ ] Test basic SCTE-35 transcoding
- [ ] Validate SCTE-35 preservation
- [ ] Configure streaming control center
- [ ] Test with actual broadcast streams
- [ ] Set up monitoring and validation
- [ ] Document the integration

## Support

### Getting Help

- **Documentation**: Check this guide and the main README
- **Issues**: Report bugs on GitHub Issues
- **Community**: Join discussions on GitHub Discussions
- **SuperKabuki**: Refer to the SuperKabuki repository for patch details

### Resources

- [SuperKabuki SCTE-35 FFmpeg Repository](https://github.com/superkabuki/SCTE35_FFmpeg)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [SCTE-35 Standards](https://www.scte.org/SCTE35/)
- [Streaming Control Center Documentation](README.md)

---

This guide provides comprehensive information for integrating SuperKabuki FFmpeg with the SCTE-35 Streaming Control Center. For additional support, please refer to the resources listed above or create an issue on GitHub.