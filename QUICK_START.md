# Quick Start Deployment Guide

This is a condensed version of the deployment guide for getting your SCTE-35 project running quickly on Ubuntu 22.04.

## 🚀 Prerequisites
- Ubuntu 22.04 installed on VirtualBox or cloud server
- Internet connection
- SSH access to the VM

## ⚡ Automated Deployment (Recommended)

### Connect to your VM
```bash
ssh ubuntu@your-vm-ip
```

### Download and run the deployment script
```bash
# Clone the repository
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol

# Run the deployment script
./deploy.sh
```

## 🔧 Manual Setup (Alternative)

If you prefer manual setup, run these commands:

### System Updates
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget htop vim net-tools build-essential python3-dev
```

### Install Node.js and PM2
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2
```

### Install Nginx
```bash
sudo apt install -y nginx
sudo ufw allow 22,80,443,1935,1936/tcp
sudo ufw --force enable
```

### Project Setup
```bash
cd ~
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol
npm install
npm run build
```

### Environment Configuration
```bash
echo "NODE_ENV=production
PORT=3000
RTMP_PORT=1935
RTMP_HTTP_PORT=1936
NEXT_PUBLIC_APP_URL=http://$(hostname -I | awk '{print $1}')" > .env
```

### Start Application
```bash
pm2 start npm --name "scte35-app" -- start
pm2 save
pm2 startup
```

### Configure Nginx
```bash
# Run the automated Nginx configuration script
./fix-nginx-config.sh
```

## 🧪 Testing Your Deployment

### Check Application Status
```bash
pm2 status
pm2 logs
```

### Test Web Interface
Open your browser and navigate to:
```
http://your-vm-ip
```

### Test RTMP Streaming
First, install FFmpeg:
```bash
sudo apt install -y ffmpeg
```

Push a test stream (you'll need a test video file):
```bash
ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test
```

### Test HLS Output
Access the HLS stream in your browser or VLC player:
```
http://your-vm-ip/hls/test.m3u8
```

### Check RTMP Statistics
```
http://your-vm-ip/stat
```

### Health Check
```
http://your-vm-ip/health
```

## 🛠️ Useful Commands

### Application Management
```bash
pm2 list          # List all processes
pm2 logs          # View logs
pm2 monit         # Monitor processes
pm2 restart scte35-app  # Restart application
pm2 stop scte35-app     # Stop application
pm2 reload scte35-app   # Reload application
```

### Nginx Management
```bash
sudo systemctl status nginx    # Check nginx status
sudo systemctl restart nginx   # Restart nginx
sudo nginx -t                  # Test nginx configuration
sudo systemctl reload nginx     # Reload nginx
```

### System Monitoring
```bash
htop                           # System monitor
df -h                          # Disk usage
free -h                        # Memory usage
netstat -tulpn | grep :1935    # Check RTMP port
sudo journalctl -u nginx -f     # Monitor nginx logs
```

### Git and Updates
```bash
./update-from-github.sh         # Interactive repository update
./git-reset-pull.sh            # Quick reset-based update
git status                     # Check git status
git pull origin master          # Pull latest changes
```

## 🚨 Troubleshooting

### Application Not Starting
```bash
# Check PM2 logs
pm2 logs

# Check if port 3000 is available
sudo netstat -tulpn | grep :3000

# Check Node.js version
node --version
npm --version

# Restart application
pm2 restart scte35-app
```

### RTMP Streaming Issues
```bash
# Check nginx configuration
sudo nginx -t

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log

# Check if RTMP port is listening
sudo netstat -tulpn | grep :1935

# Test RTMP connection
telnet localhost 1935
```

### Nginx Configuration Issues
```bash
# Test nginx configuration
sudo nginx -t

# Check nginx status
sudo systemctl status nginx

# Reload nginx
sudo systemctl reload nginx

# Check nginx logs
sudo journalctl -u nginx -f
```

### Permission Issues
```bash
# Fix file permissions
sudo chown -R ubuntu:ubuntu /home/ubuntu/SCTE-streamcontrol
sudo chmod -R 755 /home/ubuntu/SCTE-streamcontrol

# Fix RTMP directory permissions
sudo chown -R www-data:www-data /var/www/rtmp
sudo chmod -R 755 /var/www/rtmp
```

### Performance Issues
```bash
# Check system resources
free -h
cat /proc/loadavg
df -h

# Check PM2 memory usage
pm2 info scte35-app

# Monitor processes
pm2 monit
htop
```

## 🌟 Production Tips

### Security
```bash
# Install fail2ban for SSH protection
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Configure firewall
sudo ufw status
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 1935/tcp  # RTMP
sudo ufw allow 1936/tcp  # RTMP stats
```

### SSL/TLS (Optional)
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate (replace with your domain)
sudo certbot --nginx -d your-domain.com

# Auto-renew SSL certificates
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Backups
```bash
# Run backup manually
./backup.sh

# Check backup cron job
crontab -l

# Create backup script if not exists
cat > backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/ubuntu/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/project_$DATE.tar.gz -C /home/ubuntu SCTE-streamcontrol
sudo cp -r /etc/nginx $BACKUP_DIR/nginx_$DATE
pm2 save > $BACKUP_DIR/pm2_$DATE.dump
find $BACKUP_DIR -type f -mtime +7 -delete
echo "Backup completed: $DATE"
EOF
chmod +x backup.sh
```

## 📋 Next Steps

1. **Configure Your Domain**: Update the environment file with your actual domain
2. **Set Up SSL**: Install SSL certificates for secure connections
3. **Configure Monitoring**: Set up system monitoring and alerts
4. **Test SCTE-35 Functionality**: Use the web interface to create and test SCTE-35 templates
5. **Load Testing**: Test with multiple concurrent streams
6. **Set Up Backups**: Configure automated backups using the backup script

## 📞 Support

If you encounter any issues:
1. Check the logs using `pm2 logs`
2. Verify all services are running with `pm2 status` and `sudo systemctl status nginx`
3. Review the full deployment guide in `DEPLOYMENT_GUIDE.md`
4. Check system resources with `htop` and `df -h`
5. Use the automated update scripts to get the latest fixes: `./update-from-github.sh`

## 🌐 Access URLs

After successful deployment, your services will be available at:

- **Main Application**: `http://your-server-ip/`
- **RTMP Statistics**: `http://your-server-ip/stat`
- **Health Check**: `http://your-server-ip/health`
- **RTMP Publish**: `rtmp://your-server-ip:1935/live/stream-key`
- **HLS Stream**: `http://your-server-ip/hls/stream-key.m3u8`
- **DASH Stream**: `http://your-server-ip/dash/stream-key.mpd`

Replace `your-server-ip` with your actual server IP address or domain name.