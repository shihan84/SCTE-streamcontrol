# SCTE-35 Streaming Project - Quick Start Guide

Get your SCTE-35 streaming server running in minutes with this quick start guide.

## 🚀 One-Command Deployment

### Automated Setup (Recommended)
```bash
# Clone and run deployment
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol
./deploy.sh
```

## 📋 Prerequisites

- **Ubuntu 20.04+** or **Debian 10+**
- **2GB RAM** minimum (4GB recommended)
- **25GB Storage** minimum
- **Internet connection**
- **SSH access** (for remote servers)

## ⚡ Quick Manual Setup

### 1. System Preparation
```bash
# Update system and install basics
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget htop vim net-tools build-essential python3-dev

# Install Node.js and PM2
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2

# Install Nginx and configure firewall
sudo apt install -y nginx
sudo ufw allow 22,80,443,1935,1936/tcp
sudo ufw --force enable
```

### 2. Project Setup
```bash
# Clone repository
cd ~
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol

# Install dependencies
npm install
npm run build

# Configure environment
echo "NODE_ENV=production
PORT=3000
RTMP_PORT=1935
RTMP_HTTP_PORT=1936
NEXT_PUBLIC_APP_URL=http://$(hostname -I | awk '{print $1}')" > .env
```

### 3. Start Application
```bash
# Start with PM2
pm2 start npm --name "scte35-app" -- start
pm2 save
pm2 startup

# Configure Nginx
./fix-nginx-config.sh
```

## 🧪 Testing Your Setup

### Health Checks
```bash
# Check application status
pm2 status

# Test application health
curl http://localhost:3000/health

# Test Nginx proxy
curl http://$(hostname -I | awk '{print $1}')/health
```

### Test Streaming

#### Install FFmpeg for testing
```bash
sudo apt install -y ffmpeg
```

#### Push a test stream
```bash
# Create a test video (30 seconds)
ffmpeg -f lavfi -i testsrc2=duration=30:size=640x480:rate=30 -f lavfi -i sine=frequency=1000:duration=30 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test

# Or use an existing video file
ffmpeg -re -i your-video.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test
```

#### Test playback
Open these URLs in your browser or VLC player:

- **Web Interface**: `http://your-server-ip/`
- **HLS Stream**: `http://your-server-ip/hls/test.m3u8`
- **DASH Stream**: `http://your-server-ip/dash/test.mpd`
- **RTMP Stats**: `http://your-server-ip/stat`

## 🎯 Key URLs and Commands

### Application URLs
- **Main App**: `http://your-server-ip/`
- **Health Check**: `http://your-server-ip/health`
- **RTMP Stats**: `http://your-server-ip/stat`

### Streaming URLs
- **RTMP Publish**: `rtmp://your-server-ip:1935/live/stream-key`
- **HLS Playback**: `http://your-server-ip/hls/stream-key.m3u8`
- **DASH Playback**: `http://your-server-ip/dash/stream-key.mpd`

### Management Commands
```bash
# Application management
pm2 list          # Show all processes
pm2 logs          # View application logs
pm2 monit         # Monitor in real-time
pm2 restart scte35-app  # Restart application
pm2 stop scte35-app     # Stop application

# Nginx management
sudo systemctl status nginx    # Check nginx status
sudo systemctl restart nginx   # Restart nginx
sudo nginx -t                  # Test configuration

# System monitoring
htop                           # System monitor
df -h                          # Disk usage
netstat -tulpn | grep :1935    # Check RTMP port
```

## 🔧 Common Tasks

### Update Application
```bash
cd ~/SCTE-streamcontrol

# Use automated update script
./update-from-github.sh

# Or manual update
git pull
npm install
npm run build
pm2 reload scte35-app
```

### Restart Services
```bash
# Restart application only
pm2 restart scte35-app

# Restart nginx only
sudo systemctl restart nginx

# Restart everything
pm2 restart scte35-app
sudo systemctl restart nginx
```

### Check Logs
```bash
# Application logs
pm2 logs

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log

# RTMP logs
sudo tail -f /var/log/nginx/rtmp_access.log
```

## 🚨 Quick Troubleshooting

### Application Issues
```bash
# Check if app is running
pm2 status

# View error logs
pm2 logs

# Check port availability
sudo netstat -tulpn | grep :3000

# Restart application
pm2 restart scte35-app
```

### RTMP Streaming Issues
```bash
# Test nginx configuration
sudo nginx -t

# Check RTMP port
sudo netstat -tulpn | grep :1935

# View nginx error logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx
sudo systemctl restart nginx
```

### Permission Issues
```bash
# Fix project permissions
sudo chown -R $USER:$USER ~/SCTE-streamcontrol
sudo chmod -R 755 ~/SCTE-streamcontrol

# Fix RTMP directory permissions
sudo chown -R www-data:www-data /var/www/rtmp
sudo chmod -R 755 /var/www/rtmp
```

## 📚 Next Steps

### Production Setup
1. **Domain Configuration**: Point your domain to the server IP
2. **SSL Certificate**: Install SSL with Let's Encrypt
3. **Security Setup**: Configure fail2ban and firewall rules
4. **Monitoring**: Set up system monitoring and alerts

### Advanced Configuration
1. **Load Balancing**: Set up multiple servers
2. **CDN Integration**: Configure CDN for streaming
3. **Database Setup**: Configure external database
4. **Backup System**: Set up automated backups

### SCTE-35 Features
1. **Create Templates**: Use web interface to create SCTE-35 templates
2. **Test Injection**: Test SCTE-35 marker injection
3. **Monitor Events**: Monitor SCTE-35 events in real-time
4. **Schedule Ads**: Set up scheduled ad breaks

## 🆘 Getting Help

### Quick Help Commands
```bash
# Show system status
pm2 status
sudo systemctl status nginx
sudo nginx -t

# Show resource usage
htop
df -h
free -h

# Show network connections
netstat -tulpn
ss -tulpn
```

### Documentation
- **Complete Guide**: `COMPLETE_DEPLOYMENT_GUIDE.md`
- **Deployment Scripts**: `deploy.sh`, `fix-nginx-config.sh`
- **Update Scripts**: `update-from-github.sh`, `git-reset-pull.sh`

### Support Resources
- **GitHub Issues**: Report bugs and request features
- **Log Files**: Check `/var/log/pm2/` and `/var/log/nginx/`
- **Community**: Check repository discussions and issues

---

This quick start guide will get you running in minutes. For detailed configuration and production setup, refer to the `COMPLETE_DEPLOYMENT_GUIDE.md`.