# Nginx Installation Fix Guide

## 🔧 Issue Description

When running the `full-deploy.sh` script, you may encounter the following error:

```
[STEP] Step 3: Installing and Configuring Nginx
[INFO] nginx is already installed.
[INFO] Creating required directories...
[INFO] Creating Nginx configuration...
tee: /etc/nginx/nginx.conf: No such file or directory
```

This error occurs when the Nginx installation is incomplete or the configuration files are missing.

## 🛠️ Solutions

### Solution 1: Quick Fix (Recommended)

Run the quick fix script to resolve the Nginx installation issue:

```bash
# Navigate to project directory
cd SCTE-streamcontrol

# Run the quick fix script
sudo ./nginx-quick-fix.sh
```

This script will:
- Remove any existing Nginx installation
- Install Nginx properly
- Create necessary directories and configuration files
- Verify the installation

After running this script, you can re-run the full deployment:

```bash
./full-deploy.sh
```

### Solution 2: Complete Nginx Fix Deployment

If the quick fix doesn't work, use the comprehensive Nginx fix script:

```bash
# Navigate to project directory
cd SCTE-streamcontrol

# Run the complete Nginx fix deployment script
sudo ./nginx-fix-deploy.sh
```

This script will:
- Completely reinstall Nginx with RTMP module
- Configure all necessary settings
- Deploy the entire application
- Set up security and monitoring

### Solution 3: Manual Fix

If you prefer to fix it manually, run these commands:

```bash
# Remove existing Nginx installation
sudo apt remove --purge -y nginx nginx-common nginx-full nginx-core || true
sudo apt autoremove -y
sudo apt autoclean

# Update package lists
sudo apt update

# Install Nginx
sudo apt install -y nginx

# Create necessary directories
sudo mkdir -p /etc/nginx/conf.d
sudo mkdir -p /var/log/nginx
sudo mkdir -p /var/www/rtmp/hls
sudo mkdir -p /var/www/rtmp/dash
sudo touch /etc/nginx/nginx.conf

# Set proper permissions
sudo chown -R www-data:www-data /var/www/rtmp
sudo chmod -R 755 /var/www/rtmp

# Verify installation
nginx -v
sudo nginx -t
```

After fixing manually, re-run the deployment:

```bash
./full-deploy.sh
```

## 🔍 Verification

After applying any of the fixes, verify that Nginx is properly installed:

```bash
# Check Nginx version
nginx -v

# Test Nginx configuration
sudo nginx -t

# Check Nginx status
sudo systemctl status nginx
```

## 📋 Updated full-deploy.sh

The `full-deploy.sh` script has been updated to handle this issue automatically. The updated script includes:

- Proper Nginx installation verification
- Creation of necessary directories before configuration
- Error handling for missing configuration files

If you're using the latest version of the script, this issue should not occur.

## 🚨 Troubleshooting

### If Nginx still fails to install:

1. **Check for conflicting packages**:
   ```bash
   dpkg -l | grep nginx
   sudo apt remove --purge -y $(dpkg -l | grep nginx | awk '{print $2}')
   ```

2. **Clean up package manager**:
   ```bash
   sudo apt clean
   sudo apt autoremove -y
   sudo apt autoclean
   ```

3. **Reinstall dependencies**:
   ```bash
   sudo apt install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring
   ```

4. **Try alternative installation method**:
   ```bash
   # Add official Nginx repository
   curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
   echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu/ $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
   sudo apt update
   sudo apt install -y nginx
   ```

### If RTMP module is needed:

The complete Nginx fix script (`nginx-fix-deploy.sh`) includes RTMP module compilation. If you need RTMP support specifically, use that script instead of the quick fix.

## 📞 Support

If you continue to experience issues with Nginx installation:

1. Check the system logs: `sudo tail -f /var/log/syslog`
2. Check for package manager errors: `sudo apt update`
3. Verify system requirements: Ubuntu 20.04+ or Debian 10+
4. Ensure you have sufficient disk space: `df -h`

For additional support, please check the project documentation or create an issue on GitHub.

---

**© 2024 Morus Broadcasting Pvt Ltd. All rights reserved.**