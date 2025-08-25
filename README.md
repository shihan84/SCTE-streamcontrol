# 📺 SCTE-35 Streaming Control Center

*A comprehensive web-based solution for managing live TV streams with SCTE-35 ad insertion, featuring complete deployment automation and professional broadcast capabilities with enhanced SuperKabuki FFmpeg integration.*

**© 2024 Morus Broadcasting Pvt Ltd. All rights reserved.**

## 🎯 Overview

This application provides a complete control center for live TV streaming with SCTE-35 support, designed for professional broadcasters. Built with Next.js 15 and modern web technologies, it offers real-time monitoring, event management, and configuration tools with **one-click deployment**, **complete automation**, and **enhanced SCTE-35 handling** through SuperKabuki FFmpeg patch.

## ✨ Key Features

### 🚀 **SuperKabuki FFmpeg Integration**
- **Enhanced SCTE-35 Support**: SuperKabuki FFmpeg patch for superior SCTE-35 handling
- **SCTE-35 Passthrough**: Preserve SCTE-35 markers during transcoding
- **Descriptor Support**: Full CUEI descriptor (0x49455543) implementation
- **Timestamp Preservation**: Accurate timestamp maintenance with `-copyts`
- **One-Click Installation**: Automated SuperKabuki FFmpeg deployment

### 🚀 **One-Click Deployment**
- **Automated installation** with `./full-deploy.sh`
- **Complete system setup** including Nginx, RTMP, and SuperKabuki FFmpeg
- **Zero configuration required** - just run the script
- **Production-ready** out of the box with enhanced SCTE-35 capabilities

### 🎬 **Professional Stream Control**
- **Real-time stream monitoring** with viewers, bitrate, audio levels, and latency
- **One-click stream start/stop** with proper SCTE-35 initialization
- **RTMP server integration** with HLS/DASH support
- **OBS Studio configuration generation** with professional broadcast settings

### 📡 **SCTE-35 Management**
- **Instant CUE-OUT/CUE-IN triggers** for ad insertion
- **Sequential Event ID management** (starting from 100023)
- **Configurable ad duration** and pre-roll settings
- **Event history tracking** with status monitoring
- **SCTE Data PID configuration** (PID 500)

### ⚙️ **Technical Excellence**
- **Video Settings**: 1920x1080 HD, H.264, High@Auto, GOP 12, 5 B-Frames, 5 Mbps
- **Audio Settings**: AAC-LC, 128 Kbps, -20 dB LKFS, 48 kHz
- **SCTE-35 Settings**: Data PID 500, Null PID 8191, 2000ms latency
- **Aspect Ratio**: 16:9, Chroma: 4:2:0

### 🛡️ **Enterprise-Ready**
- **Security hardening** with fail2ban and firewall
- **SSL/TLS support** with Let's Encrypt integration
- **Automated backups** with configurable retention
- **Health monitoring** with real-time alerts
- **Log rotation** and comprehensive logging

## 🚀 **Quick Start - 5 Minute Deployment**

### **Option 1: Full Deployment with FFmpeg (Recommended)**
```bash
# Clone the repository
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol

# Run the complete deployment script with SuperKabuki FFmpeg
./deploy-full-with-ffmpeg.sh
```

**This includes everything:**
- ✅ System updates and dependencies
- ✅ SuperKabuki FFmpeg installation with SCTE-35 patch
- ✅ Node.js, npm, and PM2 installation
- ✅ Nginx with RTMP module configuration
- ✅ Firewall and security setup
- ✅ Application deployment and startup
- ✅ Health checks and verification
- ✅ Monitoring and backup scripts
- ✅ System optimization
- ✅ Enhanced error handling and logging
- ✅ Comprehensive testing and validation

### **Option 2: Manual Installation (Step-by-Step Guide)**
```bash
# Clone the repository
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol

# Run the comprehensive manual installation script
chmod +x manual-installation.sh
./manual-installation.sh
```

**This provides:**
- ✅ **Step-by-step guidance** with detailed explanations
- ✅ **Error recovery** options for each step
- ✅ **Component verification** after each installation phase
- ✅ **Comprehensive logging** for troubleshooting
- ✅ **Manual control** over the entire installation process
- ✅ **Full documentation** with troubleshooting guide

**For detailed manual installation instructions, see:** [Manual Installation Guide](docs/MANUAL_INSTALLATION.md)

### **Option 3: Manual SuperKabuki FFmpeg Installation**
```bash
# Install SuperKabuki FFmpeg separately
sudo ./scripts/install-superkabuki-ffmpeg.sh

# Verify installation
test-scte35.sh

# Then deploy the application
./deploy-full-with-ffmpeg.sh
```

### **Option 4: Basic Manual Installation**
```bash
# System requirements
- Ubuntu 20.04+ or Debian 10+
- 2GB RAM (4GB recommended)
- 25GB storage (50GB recommended)
- Internet connection

# Quick commands
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget

# Clone and deploy
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol
./deploy-full-with-ffmpeg.sh
```

## 🌐 **Access URLs After Deployment**

Once deployed, your streaming server will be available at:

| Service | URL | Description |
|---------|-----|-------------|
| **Main Application** | `http://your-server-ip/` | Web control interface |
| **Health Check** | `http://your-server-ip/health` | System health status |
| **RTMP Statistics** | `http://your-server-ip/stat` | Live streaming stats |
| **RTMP Publish** | `rtmp://your-server-ip:1935/live/stream-key` | Stream publishing endpoint |
| **HLS Stream** | `http://your-server-ip/hls/stream-key.m3u8` | HTTP Live Streaming |
| **DASH Stream** | `http://your-server-ip/dash/stream-key.mpd` | DASH Adaptive Streaming |

## 🛠️ **Management Commands**

### **Application Management**
```bash
pm2 list                    # List all processes
pm2 logs                    # View application logs
pm2 monit                   # Monitor in real-time
pm2 restart scte35-app      # Restart application
pm2 stop scte35-app         # Stop application
```

### **System Management**
```bash
sudo systemctl status nginx    # Check Nginx status
sudo systemctl restart nginx   # Restart Nginx
sudo nginx -t                  # Test Nginx configuration
```

### **Uninstallation Management**
```bash
# Complete uninstallation
sudo ./uninstall.sh             # Remove all components

# Partial uninstallation
sudo ./uninstall-partial.sh     # Selective component removal

# Quick status check
sudo ./uninstall-partial.sh     # Choose option 14 to show status
```

### **Updates and Maintenance**
```bash
# Interactive update with conflict resolution
./update-from-github.sh

# Manual update process
git pull origin master
npm install
npm run build
pm2 reload scte35-app
```

### **Enhanced Verification and Testing**
```bash
# Run comprehensive deployment verification
./verify-deployment.sh

# Test SuperKabuki FFmpeg installation
test-ffmpeg-scte35.sh

# Test streaming with FFmpeg
ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test

# Test health endpoints
curl http://localhost/health
curl http://localhost/stat
```

### **Enhanced Deployment Features**
The enhanced deployment scripts include:

#### **🚀 Enhanced Error Handling**
- Comprehensive error detection and recovery
- Automatic rollback on critical failures
- Detailed logging with timestamps
- Progress indicators with ETA estimates

#### **📊 Advanced Logging**
- Real-time logging to console and file
- Structured log format with timestamps
- Error categorization and severity levels
- Performance metrics and resource monitoring

#### **🔧 System Optimization**
- Automatic system resource optimization
- File descriptor limits adjustment
- Network stack tuning for streaming
- Memory management improvements

#### **🛡️ Enhanced Security**
- Advanced firewall configuration
- Fail2ban integration with custom rules
- Security header optimization
- SSL/TLS readiness checks

#### **📈 Monitoring and Reporting**
- Real-time deployment progress tracking
- System health monitoring
- Performance benchmarking
- Comprehensive deployment reports

## 🧹 **Cleanup and Uninstallation**

### **Complete Uninstallation**
```bash
# Full uninstallation (removes everything)
sudo ./uninstall.sh

# This will remove:
# - Application files and directories
# - Nginx with RTMP module
# - PM2 processes and configuration
# - Database files
# - System services
# - Firewall rules
# - Log files
# - Backup files
# - System users and groups
```

### **Partial Uninstallation**
```bash
# Selective component removal
sudo ./uninstall-partial.sh

# Available options:
# 1. Application Only (keep database and config)
# 2. Database Only (keep application and config)
# 3. Nginx Only (keep application and database)
# 4. PM2 Processes Only
# 5. Log Files Only
# 6. Backup Files Only
# 7. Application + Database
# 8. Nginx + PM2
# 9. Application + Logs
# 10. Database + Backups
# 11. Clean Configuration Files
# 12. Reset Application (keep database)
# 13. Stop Services Only
# 14. Show Current Status
```

### **Manual Cleanup**
```bash
# Stop services
pm2 stop scte35-app
sudo systemctl stop nginx

# Remove application files
rm -rf /home/ubuntu/SCTE-streamcontrol

# Remove PM2 process
pm2 delete scte35-app
```
## 📊 **System Requirements**

### **Minimum Requirements**
- **OS**: Ubuntu 20.04+ or Debian 10+
- **CPU**: 2 cores (4 cores recommended)
- **RAM**: 4GB (8GB recommended)
- **Storage**: 25GB SSD (50GB recommended)
- **Network**: 10 Mbps upload bandwidth

### **Recommended Requirements**
- **OS**: Ubuntu 22.04 LTS
- **CPU**: 4+ cores
- **RAM**: 8GB+ (16GB for high traffic)
- **Storage**: 50GB+ SSD
- **Network**: 100 Mbps+ upload bandwidth

## 🏗️ **Architecture**

### **Frontend**
- **Next.js 15**: React framework with App Router
- **TypeScript**: Type-safe JavaScript
- **Tailwind CSS**: Utility-first CSS framework
- **shadcn/ui**: Modern UI component library
- **Lucide React**: Beautiful icon library

### **Backend**
- **Node.js**: JavaScript runtime environment
- **Express.js**: Web application framework
- **Socket.IO**: Real-time bidirectional communication
- **SQLite**: Lightweight database
- **Prisma**: Database ORM

### **Streaming Infrastructure**
- **Nginx**: High-performance web server and reverse proxy
- **RTMP Module**: Real-time messaging protocol support
- **HLS/DASH**: Adaptive streaming protocols
- **FFmpeg**: Multimedia processing framework

### **Monitoring & Management**
- **PM2**: Production process manager
- **Health Checks**: System health monitoring
- **Log Management**: Comprehensive logging and rotation
- **Backup System**: Automated backup procedures

## 📋 **Compliance & Standards**

### **Video Specifications ✅**
- [x] **Stream Name**: Configurable service name
- [x] **Video Resolution**: 1920x1080 (HD)
- [x] **Video codec**: H.264
- [x] **PCR**: Video Embedded
- [x] **Profile@Level**: High@Auto
- [x] **GOP**: 12
- [x] **No of B Frames**: 5
- [x] **Video Bitrate**: 5 Mbps
- [x] **Chroma**: 4:2:0
- [x] **Aspect ratio**: 16:9

### **Audio Specifications ✅**
- [x] **Audio Codec**: AAC-LC
- [x] **Audio Bitrate**: 128 Kbps
- [x] **Audio LKFS**: -20 dB
- [x] **Audio Sampling Rate**: 48 kHz

### **SCTE-35 Requirements ✅**
- [x] **Data SCTE PID**: 500
- [x] **Null PID**: 8191
- [x] **Latency**: 2000 milliseconds (2 seconds)
- [x] **Ad duration value**: Configurable in seconds
- [x] **SCTE Event ID**: Sequential increment starting from 100023
- [x] **SCTE START**: CUE-OUT (Program out point)
- [x] **SCTE STOP**: CUE-IN (Program in point)
- [x] **Crash out scenario**: CUE-IN support
- [x] **Pre-roll Ad duration**: 0-10 seconds configurable
- [x] **SCTE Data PID value**: 500

## 🔧 **Configuration**

### **Environment Variables**
```bash
# Production settings
NODE_ENV=production
PORT=3000

# RTMP Server settings
RTMP_PORT=1935
RTMP_HTTP_PORT=1936

# Application URL
NEXT_PUBLIC_APP_URL=http://your-server-ip

# Database settings
DATABASE_URL="file:./dev.db"
```

### **Nginx Configuration**
The deployment script automatically configures Nginx with:
- **RTMP server** on port 1935
- **HTTP proxy** to Next.js application on port 3000
- **HLS streaming** support
- **DASH streaming** support
- **RTMP statistics** on port 1936
- **Security headers** and CORS support
- **Health check endpoints**

### **PM2 Configuration**
The deployment script sets up PM2 with:
- **Cluster mode** for maximum performance
- **Automatic restart** on crashes
- **Log rotation** and management
- **Systemd integration** for startup on boot
- **Memory management** with restart limits

### **Documentation**
- **Comprehensive documentation** included in this README
- **Full deployment guide**: `docs/FULL_DEPLOYMENT_WITH_FFMPEG.md`
- **Manual installation guide**: `docs/MANUAL_INSTALLATION.md`
- **SuperKabuki integration**: `docs/SUPERKABUKI_INTEGRATION.md`
- **Complete deployment with FFmpeg**: `./deploy-full-with-ffmpeg.sh`
- **Manual installation script**: `./manual-installation.sh`
- **Testing and verification**: `./verify-deployment.sh`
- **Repository updates**: `./update-from-github.sh`
- **Complete uninstallation**: `./uninstall.sh`
- **Partial uninstallation**: `./uninstall-partial.sh`

### **Troubleshooting**
- **Comprehensive troubleshooting** included in this README
- **Health check endpoints** for system monitoring
- **Log management** with centralized logging
- **Performance monitoring** with real-time metrics

## 🧪 **Testing & Verification**

### **Automated Testing**
```bash
# Health checks
curl http://localhost/health          # Application health
curl http://localhost/stat            # RTMP statistics

# Stream testing
ffmpeg -re -i test.mp4 -c:v libx264 -c:a aac -f flv rtmp://localhost:1935/live/test

# Playback testing
curl -I http://localhost/hls/test.m3u8    # HLS stream
curl -I http://localhost/dash/test.mpd    # DASH stream
```

### **Manual Verification**
1. **Web Interface**: Open `http://your-server-ip/` in browser
2. **RTMP Stats**: Check `http://your-server-ip/stat`
3. **Stream Test**: Use FFmpeg to publish a test stream
4. **Playback Test**: Verify HLS/DASH streams work in players

### **Manual Installation Verification**
If you used the manual installation script, verify each component:
```bash
# Verify FFmpeg installation
ffmpeg -version
test-ffmpeg-scte35.sh

# Verify Nginx installation
sudo nginx -t
sudo systemctl status nginx

# Verify application status
pm2 status
pm2 logs

# Verify all endpoints
curl http://localhost/health
curl http://localhost/stat
curl http://localhost/

# Check manual installation log
cat /tmp/scte35-manual-install-*.log
```

## 🚨 **Troubleshooting**

### **Common Issues**
```bash
# Application not starting
pm2 logs                    # Check application logs
pm2 restart scte35-app      # Restart application

# Nginx issues
sudo nginx -t              # Test configuration
sudo systemctl restart nginx # Restart Nginx

# Port conflicts
sudo netstat -tulpn | grep :3000  # Check port usage
sudo netstat -tulpn | grep :1935  # Check RTMP port

# Permission issues
sudo chown -R ubuntu:ubuntu /home/ubuntu/SCTE-streamcontrol
sudo chmod -R 755 /home/ubuntu/SCTE-streamcontrol
```

### **Log Files**
- **Application logs**: `/var/log/pm2/`
- **Nginx logs**: `/var/log/nginx/`
- **RTMP logs**: `/var/log/nginx/rtmp_access.log`
- **System logs**: `/var/log/syslog`

## 🔒 **Security Features**

### **System Security**
- **UFW Firewall**: Configured with necessary ports only
- **Fail2ban**: SSH and web application protection
- **Security Headers**: XSS, CSRF, and clickjacking protection
- **CORS Configuration**: Proper cross-origin resource sharing

### **Application Security**
- **Environment Variables**: Sensitive data protection
- **Input Validation**: Request sanitization
- **Rate Limiting**: API endpoint protection
- **Secure Headers**: Comprehensive security headers

### **Network Security**
- **Port Management**: Only essential ports open
- **SSL/TLS Ready**: Let's Encrypt integration
- **Access Control**: IP-based restrictions
- **Monitoring**: Real-time threat detection

## 📈 **Monitoring & Analytics**

### **Real-time Metrics**
- **System Metrics**: CPU, memory, disk, network usage
- **Stream Metrics**: Viewers, bitrate, latency, uptime
- **Application Metrics**: Response times, error rates, performance
- **SCTE-35 Metrics**: Events, success rate, timing accuracy

### **Health Monitoring**
- **Overall Health**: System-wide health status
- **Component Health**: Individual service monitoring
- **Performance Trends**: Historical performance data
- **Alert Management**: Configurable thresholds and notifications

## 🔄 **Updates & Maintenance**

### **Automated Updates**
```bash
# Interactive update with conflict resolution
./update-from-github.sh

# Manual update process
git pull origin master
npm install
npm run build
pm2 reload scte35-app
```

### **Backup & Recovery**
```bash
# Create database backup
./scripts/backup-database.sh

# Restore database from backup
./scripts/restore-database.sh

# Automated backups (scheduled daily)
crontab -l  # View backup schedule
```

### **System Maintenance**
```bash
# Log rotation (automated)
sudo logrotate -f /etc/logrotate.d/scte35-app

# System updates
sudo apt update && sudo apt upgrade -y

# Performance monitoring
htop           # System monitor
df -h          # Disk usage
free -h        # Memory usage
```

## 🤝 **Contributing**

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### **Development Workflow**
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### **Code Standards**
- Use TypeScript for type safety
- Follow ESLint configuration
- Write comprehensive tests
- Update documentation
- Use conventional commit messages

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **Next.js Team**: For the excellent React framework
- **shadcn/ui**: For the beautiful UI components
- **Nginx Team**: For the high-performance web server
- **FFmpeg Community**: For the multimedia processing framework
- **Contributors**: All the developers who have contributed to this project

## 📞 **Support**

### **Getting Help**
- **Documentation**: Check this comprehensive README
- **Issues**: Report bugs and request features on [GitHub Issues](https://github.com/shihan84/SCTE-streamcontrol/issues)
- **Discussions**: Join community discussions on [GitHub Discussions](https://github.com/shihan84/SCTE-streamcontrol/discussions)

### **Quick Help Commands**
```bash
# Check system status
pm2 status && sudo systemctl status nginx

# View logs
pm2 logs && sudo tail -f /var/log/nginx/error.log

# Test connectivity
curl http://localhost/health && curl http://localhost/stat

# Monitor resources
htop && df -h && free -h
```

### **Community Resources**
- **GitHub**: Repository and issue tracking
- **Comprehensive README**: Complete documentation and tutorials
- **Automated Scripts**: Deployment, testing, and management tools

---

## 🎯 **Roadmap**

### **Upcoming Features**
- [ ] **Advanced Analytics**: Enhanced monitoring dashboard
- [ ] **Multi-tenant Support**: Multiple channel management
- [ ] **Mobile App**: Remote management application
- [ ] **Cloud Integration**: AWS, Azure, GCP deployment
- [ ] **Advanced SSAI**: Server-side ad insertion improvements
- [ ] **Load Balancing**: Multi-server support

### **Performance Improvements**
- [ ] **Enhanced Caching**: Improved performance optimization
- [ ] **Database Optimization**: Better query performance
- [ ] **Streaming Optimization**: Reduced latency streaming
- [ ] **Resource Management**: Better resource utilization

---

**Built with ❤️ for the streaming community**

[![GitHub stars](https://img.shields.io/github/stars/shihan84/SCTE-streamcontrol.svg?style=social&label=Star)](https://github.com/shihan84/SCTE-streamcontrol)
[![GitHub forks](https://img.shields.io/github/forks/shihan84/SCTE-streamcontrol.svg?style=social&label=Fork)](https://github.com/shihan84/SCTE-streamcontrol)
[![GitHub issues](https://img.shields.io/github/issues/shihan84/SCTE-streamcontrol.svg)](https://github.com/shihan84/SCTE-streamcontrol/issues)
[![License](https://img.shields.io/github/license/shihan84/SCTE-streamcontrol.svg)](https://github.com/shihan84/SCTE-streamcontrol/blob/master/LICENSE)

---

## 🚀 **Quick Start Summary**

```bash
# 1. Clone and Deploy
git clone https://github.com/shihan84/SCTE-streamcontrol.git
cd SCTE-streamcontrol
./full-deploy.sh

# 2. Access Your Server
open http://your-server-ip/

# 3. Start Streaming!
# Use OBS Studio or FFmpeg to stream to: rtmp://your-server-ip:1935/live/stream-key
```

**🎉 Your professional SCTE-35 streaming server is ready in minutes!**