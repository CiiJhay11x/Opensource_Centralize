# 🎮 PISONET - Centralized Internet Cafe Management System

**A complete coin-operated internet cafe management system** with centralized server architecture, web-based administration, GPIO coin detection, and secure client locking.

> **v7.0.0** - Production-ready with comprehensive port diagnostics and troubleshooting tools

## ✨ Key Features

### 🖥️ Server Features
- **Web-based Admin Dashboard** - Real-time client monitoring and management
- **RESTful API** - Clean interface for client communication
- **GPIO Coin Detection** - Native support for coin sensors and relay modules
- **SQLite Database** - Robust data storage with transaction logs
- **Automatic Port Detection** - Diagnose firewall and network issues
- **Systemd Integration** - Production-ready service management
- **Nginx Reverse Proxy** - Professional HTTP routing

### 💻 Client Features
- **Full-screen Lock Screen** - Secure workstation locking via tkinter
- **Real-time Credit Display** - Live countdown timer
- **Admin Hotkeys** - Secure admin access (Ctrl+Shift+A)
- **Network Resilience** - Automatic server reconnection
- **Cross-platform** - Windows 10/11 and Linux support

### 🔧 Hardware Support
- **Orange Pi One** - Primary target (Allwinner H3 SOC)
- **Coin Acceptors** - GPIO-based coin detection
- **Relay Modules** - GPIO control for client machines
- **Ethernet** - Network-based client communication

## 🚀 Quick Start

### Fastest Way (Automated Setup)
```bash
chmod +x setup.sh
sudo ./setup.sh
```

The setup script will automatically:
- Detect open/closed ports with diagnostics
- Install all dependencies
- Configure firewall rules
- Setup systemd service
- Configure Nginx proxy
- Initialize database
- Report any connection issues

**See [INSTALLATION.md](INSTALLATION.md) for detailed setup instructions**

### Access After Installation
```
Admin Dashboard:  http://<server-ip>/admin
Port Check Tool:  ./diagnose.sh
```

**Default Credentials:**
- Username: `root`
- Password: `1234`

## 🔍 Port Diagnostics & Troubleshooting

### If Admin Panel is Not Accessible

Run the diagnostic tool (detects port issues automatically):
```bash
sudo ./diagnose.sh
```

This will:
- ✅ Check if Flask is listening on port 5000
- ✅ Check if Nginx is listening on port 80
- ✅ Verify firewall rules
- ✅ Test local and network connectivity
- ✅ Display service status
- ✅ Show recent logs
- ✅ Suggest fixes

### Common Issues & Fixes

| Issue | Command |
|-------|---------|
| Admin panel won't load | `sudo systemctl restart pisonet` |
| "Connection refused" | `sudo systemctl status nginx` |
| Port already in use | `sudo lsof -i :5000` |
| Firewall blocking | `sudo ufw allow 80/tcp` |
| Check all ports | `sudo ./diagnose.sh` |

## 📊 Architecture

```
┌─────────────────────────────────────────────────────┐
│          Admin Dashboard (Web UI)                    │
│    http://server-ip/admin                            │
└────────────────┬────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
    ┌───▼────┐        ┌──▼────┐
    │ Nginx  │        │Flask  │
    │ Port80 │        │Port5000
    └───┬────┘        └──┬────┘
        │ Reverse       │ API
        │ Proxy         │ Endpoints
        └───────┬───────┘
                │
         ┌──────▼──────┐
         │  SQLite DB  │
         │  GPIO Pins  │
         └─────────────┘
                │
    ┌───────────┼───────────┐
    │           │           │
 ┌──▼─┐    ┌───▼──┐    ┌──▼──┐
 │PC-1│    │ PC-2 │    │PC-n │
 └────┘    └──────┘    └─────┘
  PISONET Clients
```

## 📁 Project Structure

```
.
├── setup.sh              # Automated installation script
├── diagnose.sh           # Port & connectivity diagnostics
├── server.py             # Flask server application
├── client.py             # Tkinter client application
├── requirements.txt      # Python dependencies
├── pisonet.service       # Systemd service file
├── templates/
│   └── admin.html        # Admin dashboard web UI
├── INSTALLATION.md       # Detailed setup guide
└── README.md            # This file
```

## 🔧 Installation Options

### Option 1: Automated (Recommended) ⭐
```bash
sudo ./setup.sh
```
Includes port detection, firewall setup, and diagnostics.

### Option 2: Manual
See [INSTALLATION.md - Manual Installation](INSTALLATION.md#-manual-installation-if-setup-script-fails)

### Option 3: Docker (Coming Soon)
```bash
docker-compose up -d
```

## 📚 Documentation

- **[INSTALLATION.md](INSTALLATION.md)** - Complete setup and troubleshooting guide
- **[API Documentation](#api-endpoints)** - REST API reference
- **[GPIO Setup](#-hardware-wiring)** - Hardware connection guide
- **[Troubleshooting](#-troubleshooting)** - Common issues and solutions

## 🔌 Hardware Wiring

### Coin Acceptor Connection
```
Coin Acceptor Signal → Orange Pi GPIO 3 (Physical Pin 5)
Coin Acceptor GND   → Orange Pi GND (Physical Pin 6)
Coin Acceptor VCC   → Orange Pi 3.3V (Physical Pin 1)
```

### Relay Module Connection (Active LOW)
```
Orange Pi GPIO 5 (Physical Pin 29) → Relay Signal
Orange Pi GND (Physical Pin 30)     → Relay GND
Orange Pi 5V (Physical Pin 2)       → Relay VCC
```

## 📡 API Endpoints

### Client Registration
```bash
curl -X POST http://localhost:5000/api/register \
  -H "Content-Type: application/json" \
  -d '{"client_id":"client_123","hostname":"PC-01","ip_address":"192.168.1.100"}'
```

### Check Credit
```bash
curl -X POST http://localhost:5000/api/get_credit \
  -H "Content-Type: application/json" \
  -d '{"client_id":"client_123"}'
```

### Request Coin Slot
```bash
curl -X POST http://localhost:5000/api/request_coin \
  -H "Content-Type: application/json" \
  -d '{"client_id":"client_123"}'
```

### Add Credit (Admin)
```bash
curl -X POST http://localhost:5000/api/add_credit \
  -H "Content-Type: application/json" \
  -d '{"admin_password":"1234","client_id":"client_123","amount":30}'
```

## 🐛 Troubleshooting

### Admin Panel Not Accessible?

1. **Run diagnostic tool first** (fastest way to find issues):
   ```bash
   sudo ./diagnose.sh
   ```

2. **Check if services are running:**
   ```bash
   sudo systemctl status pisonet
   sudo systemctl status nginx
   ```

3. **Check if ports are open:**
   ```bash
   sudo ufw status
   sudo ufw allow 80/tcp
   sudo ufw allow 5000/tcp
   ```

4. **View logs:**
   ```bash
   sudo tail -f /var/log/pisonet/server.log
   sudo journalctl -u pisonet -n 50
   ```

5. **Test connectivity:**
   ```bash
   # Local test
   curl http://127.0.0.1:5000/api/status
   
   # Network test (replace IP)
   curl http://192.168.1.X/api/status
   ```

**For complete troubleshooting guide, see [INSTALLATION.md](INSTALLATION.md#-troubleshooting)**

## 🔐 Security Features

- ✅ Full-screen client locking (prevents Alt+F4, Ctrl+W)
- ✅ Admin password protection
- ✅ Firewall integration with UFW
- ✅ User isolation (dedicated pisonet user)
- ✅ File permissions restricted to data directories
- ✅ HTTPS ready (SSL certificate support)

## 📊 Admin Dashboard Features

- Real-time client monitoring
- Revenue tracking and analytics
- Credit management interface
- Client connection status
- System logs and audit trail
- One-click service restart
- Emergency credit reset

## 🖥️ System Requirements

### Server
- **Hardware:** Orange Pi One or compatible SBC/PC
- **OS:** Armbian 26.2.1, Debian 12+ or Ubuntu 22.04+
- **Python:** 3.8 or higher
- **Memory:** 512 MB minimum (1 GB recommended)
- **Storage:** 2 GB minimum for OS + software

### Clients
- **OS:** Windows 10/11 or Linux
- **Python:** 3.8 or higher
- **Network:** Ethernet connection to server
- **Display:** Full HD (1920x1080 recommended)

## 📈 Monitoring

### View Real-time Statistics
```bash
# Dashboard stats
curl http://localhost:5000/api/admin/statistics?password=1234

# Check all clients
curl http://localhost:5000/api/admin/clients?password=1234

# Monitor logs
tail -f /var/log/pisonet/server.log
```

### Performance Metrics
- Active client count
- Total revenue (peso value)
- Coins inserted (transaction count)
- Session times and usage patterns

## 🔄 Service Management

```bash
# Start service
sudo systemctl start pisonet

# Stop service
sudo systemctl stop pisonet

# Restart service
sudo systemctl restart pisonet

# Check status
sudo systemctl status pisonet

# View live logs
sudo journalctl -u pisonet -f
```

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see LICENSE file for details.

## 📞 Support

- **Quick Diagnostics:** Run `sudo ./diagnose.sh`
- **Setup Help:** See `INSTALLATION.md`
- **Issues:** Check the troubleshooting guide
- **Logs:** Check `/var/log/pisonet/` directory

## 🎯 Roadmap

- [ ] WebSocket real-time updates
- [ ] Mobile admin app
- [ ] Advanced analytics dashboard
- [ ] Multi-server clustering
- [ ] Docker deployment
- [ ] Automated backups to cloud
- [ ] SMS notifications
- [ ] QR code for client registration

## 📝 Changelog

### Version 7.0.0 (Current)
- Complete repository restructure
- Automatic port detection & diagnostics
- Improved admin dashboard
- Enhanced error logging
- Comprehensive installation guide
- Production-ready deployment

### Version 6.0.0
- Web-based setup wizard
- GPIO compatibility improvements
- Package management updates

---

**PISONET v7.0.0** - Making internet cafe management simple, secure, and profitable. 🎮

For complete documentation, see [INSTALLATION.md](INSTALLATION.md)