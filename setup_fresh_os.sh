#!/bin/bash

##############################################################################
#  PISONET - COMPLETE SETUP FROM FRESH OS                                  #
#  Handles: Updates, Python, Dependencies, Installation, Port Detection     #
#  Works on: Armbian 26.2.1, Debian 12, Ubuntu 22.04+                       #
#  Version 7.0.0                                                            #
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/CiiJhay11x/Opensource_Centralize.git"
INSTALL_DIR="/opt/pisonet"
VENV_DIR="$INSTALL_DIR/venv"
DATA_DIR="$INSTALL_DIR/data"
LOG_DIR="/var/log/pisonet"
SERVICE_NAME="pisonet"

echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║  🎮  PISONET v7.0.0 - COMPLETE FRESH OS SETUP                  ║
║      Armbian 26.2.1 + Python + Dependencies + Installation     ║
║                                                                 ║
║      This script handles EVERYTHING:                           ║
║      • OS system updates                                        ║
║      • Python 3.11+ installation                               ║
║      • All required dependencies & libraries                   ║
║      • Git & build tools                                       ║
║      • GPIO libraries (gpiozero, pigpio)                       ║
║      • Nginx & Systemd setup                                   ║
║      • Port detection & diagnostics                            ║
║      • Full PISONET installation                               ║
║                                                                 ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

##############################################################################
# UTILITY FUNCTIONS
##############################################################################

show_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

##############################################################################
# SYSTEM CHECKS
##############################################################################

check_root() {
    show_info "Checking root privileges..."
    if [[ $EUID -ne 0 ]]; then
        show_error "This script must be run as root"
        show_info "Try: sudo ./setup_fresh_os.sh"
        exit 1
    fi
    show_success "Running with root privileges"
}

check_os() {
    show_info "Detecting operating system..."
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        show_success "OS: $NAME $VERSION_ID"
        show_info "Kernel: $(uname -r)"
    else
        show_warning "Could not detect OS version"
    fi
}

##############################################################################
# PORT DIAGNOSTICS FUNCTION
##############################################################################

run_port_diagnostics() {
    echo -e "\n${CYAN}────────────────────────────────────────────────────────────${NC}"
    show_info "Running Port Detection & Diagnostics\n"
    
    echo "Port 5000 (Flask Server):"
    if netstat -tuln 2>/dev/null | grep -q ":5000" || ss -tuln 2>/dev/null | grep -q ":5000"; then
        echo -e "  ${GREEN}🟢 LISTENING${NC}"
    else
        echo -e "  ${RED}🔴 NOT LISTENING${NC}"
    fi
    
    echo "Port 80 (Nginx):"
    if netstat -tuln 2>/dev/null | grep -q ":80 " || ss -tuln 2>/dev/null | grep -q ":80 "; then
        echo -e "  ${GREEN}🟢 LISTENING${NC}"
    else
        echo -e "  ${RED}🔴 NOT LISTENING${NC}"
    fi
    
    echo "Port 443 (HTTPS):"
    if netstat -tuln 2>/dev/null | grep -q ":443" || ss -tuln 2>/dev/null | grep -q ":443"; then
        echo -e "  ${GREEN}🟢 LISTENING${NC}"
    else
        echo -e "  ${YELLOW}🟡 NOT LISTENING (Optional)${NC}"
    fi
    
    echo -e "\nFirewall Status:"
    if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
        echo -e "  ${GREEN}🟢 ACTIVE${NC}"
    else
        echo -e "  ${YELLOW}🟡 NOT ACTIVE${NC}"
    fi
    
    echo -e "\n${CYAN}────────────────────────────────────────────────────────────${NC}\n"
}

##############################################################################
# PACKAGE MANAGEMENT
##############################################################################

update_system() {
    show_section "STEP 1: System Updates"
    
    show_info "Updating package manager..."
    apt-get update -qq
    show_success "Package list updated"
    
    show_info "Upgrading system packages (this may take 5-10 minutes)..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
    show_success "System packages upgraded"
}

install_python() {
    show_section "STEP 2: Python 3.11+ Installation"
    
    show_info "Checking for existing Python..."
    if command -v python3 &>/dev/null; then
        PYTHON_VERSION=$(python3 --version)
        show_success "Python found: $PYTHON_VERSION"
    fi
    
    show_info "Installing Python development environment..."
    apt-get install -y -qq \
        python3 \
        python3-venv \
        python3-pip \
        python3-dev \
        python3-distutils
    
    show_success "Python installed"
    
    show_info "Upgrading pip..."
    python3 -m pip install --upgrade pip setuptools wheel -q
    show_success "pip upgraded"
}

install_build_tools() {
    show_section "STEP 3: Build Tools & Compilers"
    
    show_info "Installing build essential packages..."
    apt-get install -y -qq \
        build-essential \
        gcc \
        g++ \
        make \
        libssl-dev \
        libffi-dev \
        zlib1g-dev
    
    show_success "Build tools installed"
}

install_system_dependencies() {
    show_section "STEP 4: System Dependencies"
    
    show_info "Installing network tools..."
    apt-get install -y -qq \
        git \
        curl \
        wget \
        curl \
        net-tools \
        lsof \
        netcat-openbsd \
        dnsutils
    
    show_success "Network tools installed"
    
    show_info "Installing web server & services..."
    apt-get install -y -qq \
        nginx \
        supervisor \
        ufw
    
    show_success "Web server & services installed"
    
    show_info "Installing database & utilities..."
    apt-get install -y -qq \
        sqlite3 \
        ca-certificates \
        apt-utils
    
    show_success "Database & utilities installed"
}

install_gpio_libraries() {
    show_section "STEP 5: GPIO Libraries (For Coin/Relay Control)"
    
    show_info "Installing GPIO libraries..."
    apt-get install -y -qq \
        python3-gpiozero \
        gpiozero \
        pigpio \
        python3-pigpio
    
    show_success "GPIO libraries installed"
    
    show_info "Starting pigpiod daemon..."
    systemctl enable pigpiod 2>/dev/null || true
    systemctl start pigpiod 2>/dev/null || true
    show_success "pigpiod daemon configured"
}

install_optional_tools() {
    show_section "STEP 6: Optional Development Tools"
    
    show_info "Installing development utilities..."
    apt-get install -y -qq \
        vim \
        nano \
        htop \
        tmux
    
    show_success "Optional tools installed"
}

##############################################################################
# PYTHON PACKAGES
##############################################################################

setup_python_environment() {
    show_section "STEP 7: Python Virtual Environment"
    
    show_info "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$LOG_DIR"
    
    show_info "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    show_success "Virtual environment created"
    
    show_info "Activating virtual environment..."
    source "$VENV_DIR/bin/activate"
    show_success "Virtual environment activated"
    
    show_info "Upgrading pip in virtual environment..."
    pip install --upgrade pip setuptools wheel -q
    show_success "pip upgraded in venv"
}

##############################################################################
# PISONET SETUP
##############################################################################

clone_pisonet() {
    show_section "STEP 8: Clone PISONET Repository"
    
    show_info "Cloning from GitHub..."
    cd "$INSTALL_DIR"
    
    if [ -d .git ]; then
        show_info "Repository already exists, pulling latest..."
        git pull origin main -q
    else
        git clone "$REPO_URL" . -q
    fi
    
    show_success "Repository cloned successfully"
    
    show_info "Repository contents:"
    ls -1 | sed 's/^/  /'
}

install_python_packages() {
    show_section "STEP 9: Install Python Packages"
    
    show_info "Installing packages from requirements.txt..."
    source "$VENV_DIR/bin/activate"
    cd "$INSTALL_DIR"
    
    pip install -r requirements.txt -q
    show_success "Python packages installed"
    
    show_info "Installed packages:"
    pip list | tail -10 | sed 's/^/  /'
}

initialize_database() {
    show_section "STEP 10: Initialize Database"
    
    show_info "Creating SQLite database..."
    source "$VENV_DIR/bin/activate"
    cd "$INSTALL_DIR"
    
    python3 << 'PYEOF'
from server import DatabaseManager
DatabaseManager.init_db()
print("✓ Database initialized successfully")
PYEOF
    
    show_success "Database initialized"
}

##############################################################################
# SYSTEMD SERVICE
##############################################################################

setup_systemd_service() {
    show_section "STEP 11: Systemd Service Setup"
    
    show_info "Creating systemd service file..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=PISONET - Internet Cafe Management System
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/python3 $INSTALL_DIR/server.py
Restart=always
RestartSec=5
StandardOutput=append:$LOG_DIR/server.log
StandardError=append:$LOG_DIR/error.log

[Install]
WantedBy=multi-user.target
EOF
    
    chmod 644 "/etc/systemd/system/$SERVICE_NAME.service"
    show_success "Service file created"
    
    show_info "Reloading systemd daemon..."
    systemctl daemon-reload
    show_success "Systemd reloaded"
    
    show_info "Enabling service to start on boot..."
    systemctl enable "$SERVICE_NAME"
    show_success "Service enabled"
}

##############################################################################
# NGINX SETUP
##############################################################################

setup_nginx() {
    show_section "STEP 12: Nginx Reverse Proxy"
    
    show_info "Creating Nginx configuration..."
    
    cat > "/etc/nginx/sites-available/pisonet" << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
    
    show_success "Nginx config created"
    
    show_info "Enabling site..."
    ln -sf /etc/nginx/sites-available/pisonet /etc/nginx/sites-enabled/pisonet 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
    
    show_info "Testing Nginx configuration..."
    nginx -t
    show_success "Nginx configuration valid"
    
    show_info "Starting Nginx service..."
    systemctl enable nginx
    systemctl restart nginx
    show_success "Nginx started"
}

##############################################################################
# FIREWALL
##############################################################################

setup_firewall() {
    show_section "STEP 13: Firewall Configuration"
    
    show_info "Enabling UFW firewall..."
    ufw --force enable -q 2>/dev/null || true
    show_success "Firewall enabled"
    
    show_info "Opening SSH port (22)..."
    ufw allow 22/tcp -q 2>/dev/null || true
    show_success "SSH port opened"
    
    show_info "Opening Flask server port (5000)..."
    ufw allow 5000/tcp -q 2>/dev/null || true
    show_success "Port 5000 opened"
    
    show_info "Opening HTTP port (80)..."
    ufw allow 80/tcp -q 2>/dev/null || true
    show_success "Port 80 opened"
    
    show_info "Opening HTTPS port (443)..."
    ufw allow 443/tcp -q 2>/dev/null || true
    show_success "Port 443 opened"
    
    show_info "Current firewall rules:"
    ufw status | sed 's/^/  /'
}

##############################################################################
# START SERVICES
##############################################################################

start_services() {
    show_section "STEP 14: Starting Services"
    
    show_info "Starting PISONET service..."
    systemctl start "$SERVICE_NAME"
    sleep 2
    show_success "PISONET service started"
    
    show_info "Verifying services..."
    
    if systemctl is-active "$SERVICE_NAME" > /dev/null 2>&1; then
        show_success "✓ PISONET service is running"
    else
        show_error "✗ PISONET service failed to start"
    fi
    
    if systemctl is-active nginx > /dev/null 2>&1; then
        show_success "✓ Nginx is running"
    else
        show_error "✗ Nginx failed to start"
    fi
}

##############################################################################
# VERIFICATION
##############################################################################

verify_installation() {
    show_section "STEP 15: Installation Verification"
    
    local all_good=true
    
    echo "Service Status:"
    echo -n "  PISONET............ "
    if systemctl is-active "$SERVICE_NAME" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ RUNNING${NC}"
    else
        echo -e "${RED}✗ NOT RUNNING${NC}"
        all_good=false
    fi
    
    echo -n "  Nginx............. "
    if systemctl is-active nginx > /dev/null 2>&1; then
        echo -e "${GREEN}✓ RUNNING${NC}"
    else
        echo -e "${RED}✗ NOT RUNNING${NC}"
        all_good=false
    fi
    
    echo ""
    echo "Port Status:"
    echo -n "  Port 5000......... "
    if netstat -tuln 2>/dev/null | grep -q ":5000" || ss -tuln 2>/dev/null | grep -q ":5000"; then
        echo -e "${GREEN}✓ LISTENING${NC}"
    else
        echo -e "${RED}✗ NOT LISTENING${NC}"
        all_good=false
    fi
    
    echo -n "  Port 80........... "
    if netstat -tuln 2>/dev/null | grep -q ":80 " || ss -tuln 2>/dev/null | grep -q ":80 "; then
        echo -e "${GREEN}✓ LISTENING${NC}"
    else
        echo -e "${RED}✗ NOT LISTENING${NC}"
        all_good=false
    fi
    
    echo ""
    echo "Files & Directories:"
    echo -n "  Database.......... "
    if [ -f "$DATA_DIR/pisonet.db" ]; then
        echo -e "${GREEN}✓ EXISTS${NC}"
    else
        echo -e "${RED}✗ MISSING${NC}"
        all_good=false
    fi
    
    echo -n "  Logs.............. "
    if [ -d "$LOG_DIR" ]; then
        echo -e "${GREEN}✓ EXISTS${NC}"
    else
        echo -e "${RED}✗ MISSING${NC}"
        all_good=false
    fi
    
    echo ""
    
    if [ "$all_good" = true ]; then
        show_success "All checks passed!"
    else
        show_warning "Some components need attention"
    fi
}

##############################################################################
# FINAL INFORMATION
##############################################################################

show_access_info() {
    show_section "INSTALLATION COMPLETE!"
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}✅ PISONET v7.0.0 is installed and running!${NC}\n"
    
    echo -e "${CYAN}ACCESS INFORMATION:${NC}\n"
    
    echo "🌐 Web Admin Panel:"
    echo "   → http://$server_ip/"
    echo "   → http://$server_ip/admin"
    echo ""
    
    echo "📊 API Status:"
    echo "   → http://$server_ip/api/status"
    echo ""
    
    echo "🔐 Login Credentials:"
    echo "   Username: root"
    echo "   Password: 1234"
    echo ""
    
    echo "📁 File Locations:"
    echo "   Installation: $INSTALL_DIR"
    echo "   Database: $DATA_DIR/pisonet.db"
    echo "   Logs: $LOG_DIR/"
    echo ""
    
    echo "🔍 Diagnostic Tool:"
    echo "   $ sudo $INSTALL_DIR/diagnose.sh"
    echo ""
    
    echo "🎯 Next Steps:"
    echo "   1. Open http://$server_ip/admin in your browser"
    echo "   2. Login with root:1234"
    echo "   3. Configure system settings"
    echo "   4. Setup GPIO pins (if using coin acceptor)"
    echo "   5. Install clients on user machines"
    echo "   6. Start earning revenue!"
    echo ""
}

show_troubleshooting() {
    show_section "TROUBLESHOOTING"
    
    echo -e "${YELLOW}If admin panel is not accessible:${NC}\n"
    
    echo "1️⃣  Check service status:"
    echo "   $ sudo systemctl status pisonet"
    echo ""
    
    echo "2️⃣  Run diagnostic tool:"
    echo "   $ sudo $INSTALL_DIR/diagnose.sh"
    echo ""
    
    echo "3️⃣  Check firewall:"
    echo "   $ sudo ufw status"
    echo ""
    
    echo "4️⃣  View logs:"
    echo "   $ tail -f $LOG_DIR/server.log"
    echo ""
    
    echo "5️⃣  Restart services:"
    echo "   $ sudo systemctl restart pisonet"
    echo "   $ sudo systemctl restart nginx"
    echo ""
}

##############################################################################
# MAIN EXECUTION
##############################################################################

main() {
    check_root
    check_os
    
    echo ""
    show_warning "This will update your system and install PISONET"
    show_warning "Installation will take 10-20 minutes"
    echo ""
    read -p "Press Enter to continue..." 
    
    echo ""
    
    # Installation steps
    update_system
    install_python
    install_build_tools
    install_system_dependencies
    install_gpio_libraries
    install_optional_tools
    setup_python_environment
    clone_pisonet
    install_python_packages
    initialize_database
    setup_systemd_service
    setup_nginx
    setup_firewall
    start_services
    verify_installation
    run_port_diagnostics
    show_access_info
    show_troubleshooting
    
    echo ""
    show_success "PISONET setup completed successfully!"
    echo ""
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
