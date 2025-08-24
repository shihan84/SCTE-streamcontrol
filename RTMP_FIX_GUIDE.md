# RTMP Module Installation Fix Guide

## Problem
The deployment script fails with error:
```
nginx: [emerg] unknown directive "rtmp" in /etc/nginx/rtmp/rtmp.conf:1
```

This occurs because the standard Nginx package doesn't include the RTMP module.

## Solution Options

### Option 1: Install RTMP Module Package (Recommended)

This is the easiest solution for Debian/Ubuntu systems:

```bash
# Run this command to fix the RTMP module
sudo apt update
sudo apt install -y libnginx-mod-rtmp

# Restart nginx
sudo systemctl restart nginx
```

### Option 2: Use the Fix Script

Run the provided fix script:

```bash
# Navigate to your project directory
cd /home/ubuntu/scte35-project

# Run the fix script
sudo bash scripts/fix-rtmp.sh
```

### Option 3: Docker-based RTMP Server

If you prefer using Docker:

```bash
# Run the Docker RTMP setup script
sudo bash scripts/docker-rtmp.sh
```

### Option 4: Manual Nginx Compilation

For advanced users who need full control:

```bash
# Run the manual compilation script
sudo bash scripts/install-nginx-rtmp.sh
```

## Verification

After applying any fix, verify the installation:

```bash
# Test nginx configuration
sudo nginx -t

# Check if RTMP module is loaded
nginx -V 2>&1 | grep rtmp

# Test RTMP port
netstat -tlnp | grep 1935
```

## Updated Deployment Process

1. **Fix RTMP Module First** (choose one option above)
2. **Continue with Deployment**:
   ```bash
   cd /home/ubuntu/scte35-project
   sudo bash deploy.sh
   ```

## Troubleshooting

### If RTMP module still not found:
```bash
# Check nginx modules directory
ls /usr/lib/nginx/modules/

# Check loaded modules
nginx -V 2>&1 | grep module
```

### If port 1935 is not listening:
```bash
# Check nginx status
sudo systemctl status nginx

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log

# Check if port is available
sudo netstat -tlnp | grep 1935
```

### If Docker option is used:
```bash
# Check Docker containers
docker ps

# Check Docker logs
docker logs rtmp-server

# Restart Docker service
sudo systemctl restart rtmp-docker.service
```

## Configuration Files

The following files are created/modified:
- `/etc/nginx/rtmp/rtmp.conf` - RTMP server configuration
- `/etc/nginx/nginx.conf` - Main nginx configuration (RTMP include added)
- `/var/www/rtmp/` - RTMP data directory
- Docker files (if using Docker option)

## Testing RTMP Server

After successful installation, test the RTMP server:

```bash
# Test with FFmpeg (if available)
ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test

# Access HLS stream
curl http://localhost/hls/test.m3u8

# Access RTMP statistics
curl http://localhost/stat
```

## Next Steps

1. Apply one of the RTMP module fixes
2. Continue with the deployment script
3. Verify RTMP functionality
4. Test streaming capabilities

## Support

If you encounter any issues:
1. Check the nginx error logs: `sudo tail -f /var/log/nginx/error.log`
2. Verify port availability: `sudo netstat -tlnp | grep 1935`
3. Check module loading: `nginx -V`
4. Review the deployment logs: `sudo journalctl -u nginx`