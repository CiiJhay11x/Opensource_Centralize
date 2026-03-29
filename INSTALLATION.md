# PISONET - Installation & Deployment Guide

Complete setup instructions for the Centralized Internet Cafe Management System with comprehensive port diagnostics.

## 📋 Quick Start

### Prerequisites
- Ubuntu/Debian-based system
- Root access
- Internet connection
- Network interface (Ethernet recommended)

### Automated Installation (Recommended)

```bash
# Download and run the setup script
chmod +x setup.sh
sudo ./setup.sh
```

The setup script will:
- ✅ Verify system requirements
- ✅ Run port diagnostics before installation
- ✅ Install all dependencies
- ✅ Setup Python virtual environment
- ✅ Initialize database
- ✅ Configure firewall rules
- ✅ Setup systemd service
- ✅ Configure Nginx reverse proxy
- ✅ Run post-installation verification
- ✅ Display access credentials

## 🔍 Port Detection & Diagnostics

### Automatic Port Detection (During Setup)
The setup script automatically:
1. Detects available ports (5000, 80, 443)
2. Identifies processes using those ports
3. Checks firewall configuration
4. Provides detailed diagnostics

### Manual Port Diagnostics

If admin panel is not accessible, run the diagnostic tool:

```bash
chmod +x diagnose.sh
sudo ./diagnose.sh
```

This will check:
- Flask server listening status
- Nginx reverse proxy status
- Firewall rules and open ports
- Service status
- Network connectivity
- Configuration errors
- Recent logs

## 📊 Understanding Port Issues

### Port 5000 - Flask Application Server
```
Status: Should be LISTENING on 127.0.0.1:5000
Check: sudo lsof -i :5000
Fix: sudo systemctl restart pisonet
```

### Port 80 - Nginx HTTP Proxy
```
Status: Should be LISTENING on 0.0.0.0:80
Check: sudo lsof -i :80
Fix: sudo systemctl restart nginx
```

### Firewall Rules
```bash
# Check current rules
sudo ufw status

# Allow Flask (if direct access needed)
sudo ufw allow 5000/tcp

# Allow HTTP (Nginx)
sudo ufw allow 80/tcp

# Allow HTTPS
sudo ufw allow 443/tcp

# Reload firewall
sudo ufw reload
```

## 🚀 Accessing PISONET

After installation:

```
Admin Dashboard: http://<server-ip>/admin
Server Status:   http://<server-ip>/api/status
API Base:        http://<server-ip>/api
```

**Default Credentials:**
- **Username:** root
- **Password:** 1234

## 🔧 Manual Installation (If Setup Script Fails)

```bash
# Create installation directory
sudo mkdir -p /opt/pisonet
cd /opt/pisonet

# Clone repository
git clone https://github.com/CiiJhay11x/Opensource_Centralize.git .

# Setup Python environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Initialize database
python3 -c "from server import DatabaseManager; DatabaseManager.init_db()"

# Setup systemd service
sudo cp pisonet.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable pisonet
sudo systemctl start pisonet

# Setup firewall
sudo ufw allow 5000/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Test server
curl http://localhost:5000/
```

## 🐛 Troubleshooting

### Admin Panel Not Accessible

**Step 1: Check if Flask is running**
```bash
sudo systemctl status pisonet
sudo lsof -i :5000
```

**Step 2: Check if Nginx is running**
```bash
sudo systemctl status nginx
sudo lsof -i :80
```

**Step 3: Test localhost connectivity**
```bash
curl http://127.0.0.1:5000/
curl http://127.0.0.1/
```

**Step 4: Test network connectivity**
```bash
# Replace X.X.X.X with your server IP
curl http://X.X.X.X:5000/
curl http://X.X.X.X/
```

**Step 5: Check firewall rules**
```bash
sudo ufw status verbose
sudo ufw allow 5000/tcp
sudo ufw allow 80/tcp
sudo ufw reload
```

**Step 6: View detailed logs**
```bash
# Flask logs
sudo tail -f /var/log/pisonet/server.log

# Nginx error log
sudo tail -f /var/log/nginx/error.log

# Systemd journal
sudo journalctl -u pisonet -n 50
```

### Port Already in Use

If port 5000 or 80 is already in use:

```bash
# Find what's using the port
sudo lsof -i :5000
sudo lsof -i :80

# Either:
# 1. Stop the other service
sudo systemctl stop <service-name>

# 2. Or change Flask port in server.py
# Find: app.run(host='0.0.0.0', port=5000)
# Edit to: app.run(host='0.0.0.0', port=5001)
# Then update Nginx proxy_pass
```

### Firewall Blocking Traffic

```bash
# Check if firewall is active
sudo ufw status

# If active, check rules
sudo ufw status numbered

# Add missing rules
sudo ufw allow 5000/tcp
sudo ufw allow 80/tcp

# Reload
sudo ufw reload

# Or disable temporarily for testing
sudo ufw disable
```

## 📝 Service Management

```bash
# Start PISONET
sudo systemctl start pisonet

# Stop PISONET
sudo systemctl stop pisonet

# Restart PISONET
sudo systemctl restart pisonet

# Check status
sudo systemctl status pisonet

# View logs
sudo journalctl -u pisonet
sudo tail -f /var/log/pisonet/server.log
```

## 🔐 Security Settings

### Change Admin Password

```bash
# Connect to database
sqlite3 /opt/pisonet/data/pisonet.db

# Update password
UPDATE config SET value='newpassword' WHERE key='admin_password';

# Exit and restart service
.quit
sudo systemctl restart pisonet
```

### Enable HTTPS

```bash
# Install certbot
sudo apt-get install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo systemctl enable certbot.timer
```

## 📊 Monitoring

### Real-time Monitoring
```bash
# Watch service status
watch sudo systemctl status pisonet

# Monitor ports
watch sudo lsof -i :5000,:80

# Check resource usage
top
htop
```

### Log Analysis
```bash
# Recent errors
grep ERROR /var/log/pisonet/server.log | tail -20

# Connection attempts
grep "registered\|connected" /var/log/pisonet/server.log

# API usage
grep "api/" /var/log/pisonet/server.log
```

## 🎯 Common Port Diagnostics Scenarios

### Scenario 1: Flask runs, but admin panel shows "connection refused"
```
Problem: Flask listening but Nginx not configured
Solution: sudo systemctl restart nginx
          sudo nginx -t
```

### Scenario 2: Both running but page times out
```
Problem: Firewall blocking port 80 or 5000
Solution: sudo ufw allow 80/tcp
          sudo ufw allow 5000/tcp
          sudo ufw reload
```

### Scenario 3: "Connection reset" errors
```
Problem: Services not fully initialized
Solution: Wait 5 seconds and retry
          sudo systemctl restart pisonet
          sudo systemctl restart nginx
```

### Scenario 4: "No route to host" from another machine
```
Problem: Server IP not bound correctly or firewall blocking
Solution: Check IP: hostname -I
          Test from server: curl http://127.0.0.1/
          Check firewall: sudo ufw status
          Allow traffic: sudo ufw allow 80/tcp
```

## 📱 Client Setup

### Windows Client
```bash
# 1. Install Python 3.8+
# 2. Download client.py
# 3. Run:
python client.py http://<server-ip>:5000
```

### Linux Client
```bash
# Install dependencies
sudo apt install python3 python3-tk python3-requests

# Run client
python3 client.py http://<server-ip>:5000
```

## 📞 Support Resources

- **Diagnostic Tool:** `./diagnose.sh` - Run this first for troubleshooting
- **Setup Script:** `./setup.sh` - Complete automated installation
- **Logs:** `/var/log/pisonet/` - Server logs
- **Database:** `/opt/pisonet/data/pisonet.db` - SQLite database

## 🔄 System Updates

### Update PISONET
```bash
cd /opt/pisonet
git pull origin main

# Reinstall dependencies if needed
source venv/bin/activate
pip install -r requirements.txt --upgrade

# Restart service
sudo systemctl restart pisonet
```

### Backup Database
```bash
# Manual backup
cp /opt/pisonet/data/pisonet.db /backup/pisonet_$(date +%Y%m%d).db

# Automated daily backup
(crontab -l 2>/dev/null; echo "0 2 * * * cp /opt/pisonet/data/pisonet.db /backup/pisonet_\$(date +\%Y\%m\%d).db") | crontab -
```

## ✨ Features Included

- ✅ Web-based Admin Dashboard (HTML5)
- ✅ RESTful API for client communication
- ✅ GPIO support for coin/relay control
- ✅ SQLite database with transactions
- ✅ Real-time credit management
- ✅ Systemd service integration
- ✅ Nginx reverse proxy
- ✅ Comprehensive logging
- ✅ Automatic port detection
- ✅ Detailed diagnostics

## 📈 Performance Tuning

### Increase File Limits
```bash
# Edit /etc/security/limits.conf
sudo nano /etc/security/limits.conf

# Add:
* soft nofile 65536
* hard nofile 65536

# Apply
sudo sysctl -p
```

### Optimize Nginx
```bash
# Edit /etc/nginx/nginx.conf
sudo nano /etc/nginx/nginx.conf

# Adjust worker_processes and connections
```

---

**PISONET v7.0.0** - Making internet cafe management simple and secure.
