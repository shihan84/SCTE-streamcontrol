# Nginx PID File and Service Fix Guide

## 🔧 Issue Description

When running the `nginx-fix-deploy.sh` script, you may encounter the following error:

```
○ nginx.service - Nginx with RTMP
     Loaded: loaded (/etc/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: inactive (dead)
Aug 23 15:10:37 root systemd[1]: /etc/systemd/system/nginx.service:7: PIDFile= references a pa…e accordingly.
```

This error occurs because the Nginx systemd service is trying to use a PID file path (`/run/nginx.pid`) that either doesn't exist or Nginx cannot write to it.

## 🛠️ Solutions

### Solution 1: Quick PID Fix (Recommended)

Run the PID fix script to resolve the systemd service issue:

```bash
# Navigate to project directory
cd SCTE-streamcontrol

# Run the PID fix script
sudo ./nginx-pid-fix.sh
```

This script will:
- Create the necessary PID directory (`/run/nginx`)
- Set proper permissions for the PID directory
- Fix the systemd service file with proper PID handling
- Restart Nginx service correctly
- Verify the service is running

### Solution 2: Comprehensive Nginx Fix

If the quick fix doesn't work, use the comprehensive fix script:

```bash
# Navigate to project directory
cd SCTE-streamcontrol

# Run the comprehensive fix script
sudo ./nginx-comprehensive-fix.sh
```

This script will:
- Completely reinstall Nginx with proper configuration
- Fix all PID file and systemd service issues
- Create proper directory structure and permissions
- Configure RTMP module correctly
- Set up comprehensive logging and monitoring

### Solution 3: Manual Fix

If you prefer to fix it manually, run these commands:

```bash
# Stop Nginx service
sudo systemctl stop nginx

# Create PID directory with proper permissions
sudo mkdir -p /run/nginx
sudo chown www-data:www-data /run/nginx
sudo chmod 755 /run/nginx

# Create proper systemd service file
sudo tee /etc/systemd/system/nginx.service > /dev/null << 'EOF'
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf
ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

# Create PID directory before starting
ExecStartPre=/bin/mkdir -p /run/nginx
ExecStartPre=/bin/chown www-data:www-data /run/nginx
ExecStartPre=/bin/chmod 755 /run/nginx

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start Nginx
sudo systemctl daemon-reload
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify Nginx is running
sudo systemctl status nginx
```

## 🔍 Verification

After applying any of the fixes, verify that Nginx is properly running:

```bash
# Check Nginx service status
sudo systemctl status nginx

# Check if Nginx is responding
curl -s http://localhost/health

# Check RTMP port
nc -z localhost 1935

# Check Nginx logs
journalctl -u nginx -n 20 --no-pager
```

## 📋 Expected Output

After successful fix, you should see:

```bash
● nginx.service - The NGINX HTTP and reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since [timestamp]
   Main PID: [pid] (nginx)
      Tasks: [number]
     Memory: [memory]
        CPU: [cpu]
     CGroup: /system.slice/nginx.service
             ├─[pid] nginx: master process /usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
             └─[pid] nginx: worker process
```

## 🚨 Troubleshooting

### If Nginx still fails to start:

1. **Check for port conflicts**:
   ```bash
   sudo netstat -tulpn | grep :80
   sudo netstat -tulpn | grep :1935
   sudo ss -tulpn | grep :80
   sudo ss -tulpn | grep :1935
   ```

2. **Check Nginx configuration**:
   ```bash
   sudo /usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf
   ```

3. **Check file permissions**:
   ```bash
   ls -la /run/nginx
   ls -la /usr/local/nginx/conf/nginx.conf
   ls -la /var/log/nginx
   ```

4. **Check system logs**:
   ```bash
   sudo journalctl -u nginx -n 50 --no-pager
   sudo tail -f /var/log/syslog
   ```

5. **Try manual startup**:
   ```bash
   sudo /usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
   sudo ps aux | grep nginx
   ```

### If PID file issues persist:

1. **Create PID file manually**:
   ```bash
   sudo touch /run/nginx.pid
   sudo chown www-data:www-data /run/nginx.pid
   sudo chmod 644 /run/nginx.pid
   ```

2. **Modify service file to use different PID path**:
   ```bash
   sudo tee /etc/systemd/system/nginx.service > /dev/null << 'EOF'
   [Unit]
   Description=The NGINX HTTP and reverse proxy server
   After=syslog.target network.target remote-fs.target nss-lookup.target

   [Service]
   Type=forking
   PIDFile=/var/run/nginx.pid
   ExecStartPre=/usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf
   ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
   ExecReload=/bin/kill -s HUP $MAINPID
   ExecStop=/bin/kill -s QUIT $MAINPID
   PrivateTmp=true

   [Install]
   WantedBy=multi-user.target
   EOF
   ```

3. **Restart systemd and Nginx**:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart nginx
   ```

## 🔄 Next Steps

After fixing the PID file issue, you can:

1. **Continue with deployment**:
   ```bash
   # Continue from where the nginx-fix-deploy.sh script failed
   # The script should continue automatically if you re-run it
   sudo ./nginx-fix-deploy.sh
   ```

2. **Deploy the application**:
   ```bash
   cd SCTE-streamcontrol
   ./full-deploy.sh
   ```

3. **Test the streaming server**:
   ```bash
   # Test health endpoint
   curl http://localhost/health
   
   # Test RTMP stats
   curl http://localhost/stat
   
   # Test streaming with FFmpeg
   ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test
   ```

## 📞 Support

If you continue to experience issues with Nginx PID files:

1. **Check the specific error message** in the systemd service output
2. **Verify all directory permissions** are correct
3. **Ensure no other services** are using the required ports
4. **Check disk space** and system resources
5. **Review the comprehensive fix script** for additional troubleshooting steps

For additional support, please check the project documentation or create an issue on GitHub.

## 📚 Related Documentation

- [NGINX_FIX_GUIDE.md](NGINX_FIX_GUIDE.md) - General Nginx installation fixes
- [nginx-quick-fix.sh](nginx-quick-fix.sh) - Quick Nginx installation fix
- [nginx-comprehensive-fix.sh](nginx-comprehensive-fix.sh) - Comprehensive Nginx fix
- [nginx-pid-fix.sh](nginx-pid-fix.sh) - PID file specific fix

---

**© 2024 Morus Broadcasting Pvt Ltd. All rights reserved.**