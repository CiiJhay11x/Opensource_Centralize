#!/bin/bash

##############################################################################
#  PISONET - Centralized Internet Cafe Management System                    #
#  Smart Setup Script with Port Detection & Diagnostics                      #
#  Version 7.0.0                                                             #
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/CiiJhay11x/Opensource_Centralize.git"
INSTALL_DIR="/opt/pisonet"
VENV_DIR="$INSTALL_DIR/venv"
DATA_DIR="$INSTALL_DIR/data"
LOG_DIR="/var/log/pisonet"
SERVICE_NAME="pisonet"
SERVICE_FILE="/etc/systemd/system/pisonet.service"

# Port configuration
SERVER_PORT=5000
NGINX_PORT=80
HTTPS_PORT=443

echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║  🎮  PISONET - Internet Cafe Management System                  ║
║      Smart Setup with Port Detection & Diagnostics              ║
║      Version 7.0.0                                              ║
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

pause_execution() {
    read -p "Press Enter to continue..."
}

##############################################################################
# SYSTEM CHECKS
##############################################################################

check_root() {
    show_info "Checking root privileges..."
    if [[ $EUID -ne 0 ]]; then
        show_error "This script must be run as root"
        exit 1
    fi
    show_success "Running with root privileges"
}

check_os() {
    show_info "Checking operating system..."
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        show_success "OS: $NAME $VERSION"
    else
        show_warning "Could not detect OS version"
    fi
}

check_python() {
    show_info "Checking Python installation..."
    if ! command -v python3 &> /dev/null; then
        show_error "Python3 not found. Installing..."
        apt-get update
        apt-get install -y python3 python3-venv python3-pip
    fi
    
    PYTHON_VERSION=$(python3 --version)
    show_success "Python found: $PYTHON_VERSION"
}

##############################################################################
# PORT DIAGNOSTICS & DETECTION
##############################################################################

detect_port_status() {
    local port=$1
    local service_name=$2
    
    # Check if port is in use
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo "IN_USE"
    elif ss -tuln 2>/dev/null | grep -q ":$port "; then
        echo "IN_USE"
    else
        echo "AVAILABLE"
    fi
}

get_process_on_port() {
    local port=$1
    lsof -i:$port 2>/dev/null | tail -n +2 | awk '{print $1, "(" $2 ")"}' || echo "Unknown"
}

check_firewall_status() {
    show_info "Checking firewall configuration..."
    
    if command -v ufw &> /dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            show_success "Firewall (UFW): ACTIVE"
            return 0
        else
            show_warning "Firewall (UFW): INACTIVE"
            return 1
        fi
    elif command -v firewalld &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            show_success "Firewall (firewalld): ACTIVE"
            return 0
        else
            show_warning "Firewall (firewalld): INACTIVE"
            return 1
        fi
    else
        show_warning "No firewall detected (UFW/firewalld)"
        return 1
    fi
}

check_port_firewall() {
    local port=$1
    
    if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
        if sudo ufw status | grep -q "$port"; then
            echo "OPEN"
        else
            echo "BLOCKED"
        fi
    else
        echo "UNKNOWN"
    fi
}

run_port_diagnostics() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\\━━━━━━━━━━━━━━━━━━━━━━━\n"
    show_info "Running Port Detection & Diagnostics\n"
    
    # Create diagnostics report
    local diagnostics_file="/tmp/pisonet_port_diagnostics.txt"
    cat > "$diagnostics_file" << 'DIAG_EOF'
┌──────────────────────────────────────────────────────────────────┐
│              PISONET PORT DIAGNOSTICS REPORT                      │
└──────────────────────────────────────────────────────────────────┘

DIAG_EOF
    
    # Check system networking
    {
        echo ""
        echo "1. NETWORK INFORMATION:"
        echo "   ├─ Hostname: $(hostname)"
        echo "   ├─ IP Address: $(hostname -I | awk '{print $1}')"
        echo "   └─ Network Interfaces:"
        ifconfig 2>/dev/null | grep "inet " | awk '{print "       └─", $0}' || ip addr | grep "inet " | awk '{print "       └─", $0}'
    } >> "$diagnostics_file"
    
    # Check ports
    {
        echo ""
        echo "2. PORT STATUS:"
        echo "   ├─ Flask Server (5000):"
        
        local port_5000=$(detect_port_status 5000 "Flask")
        if [ "$port_5000" = "IN_USE" ]; then
            echo "   │  ├─ Status: 🔴 IN USE"
            echo "   │  └─ Process: $(get_process_on_port 5000)"
        else
            echo "   │  ├─ Status: 🟢 AVAILABLE"
            echo "   │  └─ Process: None"
        fi
        
        echo "   ├─ HTTP (80):"
        local port_80=$(detect_port_status 80 "HTTP")
        if [ "$port_80" = "IN_USE" ]; then
            echo "   │  ├─ Status: 🔴 IN USE"
            echo "   │  └─ Process: $(get_process_on_port 80)"
        else
            echo "   │  ├─ Status: 🟢 AVAILABLE"
            echo "   │  └─ Process: None"
        fi
        
        echo "   └─ HTTPS (443):"
        local port_443=$(detect_port_status 443 "HTTPS")
        if [ "$port_443" = "IN_USE" ]; then
            echo "      ├─ Status: 🔴 IN USE"
            echo "      └─ Process: $(get_process_on_port 443)"
        else
            echo "      ├─ Status: 🟢 AVAILABLE"
            echo "      └─ Process: None"
        fi
    } >> "$diagnostics_file"
    
    # Check firewall
    {
        echo ""
        echo "3. FIREWALL STATUS:"
        if check_firewall_status > /dev/null 2>&1; then
            echo "   ├─ Status: 🟢 ACTIVE"
            echo "   ├─ Port 5000: $(check_port_firewall 5000)"
            echo "   ├─ Port 80: $(check_port_firewall 80)"
            echo "   └─ Port 443: $(check_port_firewall 443)"
        else
            echo "   └─ Status: 🟠 NO FIREWALL DETECTED"
        fi
    } >> "$diagnostics_file"
    
    # Display diagnostics
    cat "$diagnostics_file"
    
    # Store for later use
    cp "$diagnostics_file" "$DATA_DIR/diagnostics.txt" 2>/dev/null || true
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

##############################################################################
# FIREWALL SETUP
##############################################################################

setup_firewall() {
    show_info "Configuring firewall rules..."
    
    if ! command -v ufw &> /dev/null; then
        show_warning "UFW not installed. Installing..."
        apt-get update
        apt-get install -y ufw
    fi
    
    # Enable UFW
    show_info "Enabling UFW firewall..."
    ufw --force enable
    
    # Allow SSH (important!)
    show_info "Opening SSH port (22)..."
    ufw allow 22/tcp
    
    # Allow Flask server
    show_info "Opening Flask server port (5000)..."
    ufw allow 5000/tcp
    
    # Allow HTTP
    show_info "Opening HTTP port (80)..."
    ufw allow 80/tcp
    
    # Allow HTTPS
    show_info "Opening HTTPS port (443)..."
    ufw allow 443/tcp
    
    show_success "Firewall configured successfully"
}

##############################################################################
# INSTALLATION FUNCTIONS
##############################################################################

install_dependencies() {
    show_info "Installing system dependencies..."
    apt-get update
    apt-get install -y \
        build-essential \
        libssl-dev \
        libffi-dev \
        python3-dev \
        git \
        curl \
        wget \
        net-tools \
        lsof \
        nginx \
        supervisor
    show_success "System dependencies installed"
}

create_installation_directory() {
    show_info "Creating installation directory..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$LOG_DIR"
    show_success "Directory structure created"
}

setup_python_environment() {
    show_info "Setting up Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip setuptools wheel
    show_success "Python virtual environment created"
}

install_python_packages() {
    show_info "Installing Python packages..."
    source "$VENV_DIR/bin/activate"
    pip install -r requirements.txt
    show_success "Python packages installed"
}

initialize_database() {
    show_info "Initializing database..."
    source "$VENV_DIR/bin/activate"
    cd "$INSTALL_DIR"
    python3 << 'PYEOF'
from server import DatabaseManager
DatabaseManager.init_db()
print("Database initialized successfully")
PYEOF
    show_success "Database initialized"
}

##############################################################################
# SYSTEMD SERVICE SETUP
##############################################################################

create_systemd_service() {
    show_info "Creating systemd service..."
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=PISONET - Internet Cafe Management System
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/python3 server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_FILE"
    systemctl daemon-reload
    show_success "Systemd service created"
}

##############################################################################
# NGINX SETUP
##############################################################################

setup_nginx() {
    show_info "Configuring Nginx reverse proxy..."
    
    cat > /etc/nginx/sites-available/pisonet << 'EOF'
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

    # Enable site
    ln -sf /etc/nginx/sites-available/pisonet /etc/nginx/sites-enabled/pisonet
    rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx config
    nginx -t
    
    # Start nginx
    systemctl enable nginx
    systemctl restart nginx
    
    show_success "Nginx configured"
}

##############################################################################
# FINAL SETUP & VERIFICATION
##############################################################################

start_services() {
    show_info "Starting services..."
    
    # Start Flask server
    systemctl enable $SERVICE_NAME
    systemctl start $SERVICE_NAME
    sleep 2
    
    show_success "Services started"
}

verify_installation() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    show_info "Verifying installation...\n"
    
    local all_good=true
    
    # Check Flask server
    echo -n "  Flask Server (5000).......... "
    if detect_port_status 5000 "Flask" | grep -q "IN_USE"; then
        echo -e "${GREEN}✅ RUNNING${NC}"
    else
        echo -e "${RED}❌ NOT RUNNING${NC}"
        all_good=false
    fi
    
    # Check Nginx
    echo -n "  Nginx Reverse Proxy (80).... "
    if systemctl is-active nginx > /dev/null 2>&1; then
        echo -e "${GREEN}✅ RUNNING${NC}"
    else
        echo -e "${RED}❌ NOT RUNNING${NC}"
        all_good=false
    fi
    
    # Test HTTP connectivity
    echo -n "  HTTP Connectivity........... "
    if curl -s http://localhost/ > /dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${YELLOW}⚠️  PENDING${NC}"
    fi
    
    # Check database
    echo -n "  Database..................... "
    if [ -f "$DATA_DIR/pisonet.db" ]; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ MISSING${NC}"
        all_good=false
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ "$all_good" = true ]; then
        show_success "Installation verified successfully!"
    else
        show_warning "Some components need attention"
    fi
}

##############################################################################
# TROUBLESHOOTING GUIDE
##############################################################################

show_troubleshooting_guide() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}TROUBLESHOOTING GUIDE${NC}\n"
    
    echo "If the admin panel is not accessible:"
    echo ""
    echo "  1️⃣  Check if Flask server is running:"
    echo "      → sudo systemctl status pisonet"
    echo ""
    echo "  2️⃣  Check if port 5000 is listening:"
    echo "      → sudo lsof -i :5000"
    echo ""
    echo "  3️⃣  Check if port 80 (Nginx) is listening:"
    echo "      → sudo lsof -i :80"
    echo ""
    echo "  4️⃣  Check firewall rules:"
    echo "      → sudo ufw status"
    echo ""
    echo "  5️⃣  Test Flask server directly:"
    echo "      → curl http://localhost:5000/"
    echo ""
    echo "  6️⃣  Test through Nginx:"
    echo "      → curl http://$(hostname -I | awk '{print $1}')/"
    echo ""
    echo "  7️⃣  Check system logs:"
    echo "      → sudo journalctl -u pisonet -n 50"
    echo ""
    echo "  8️⃣  View Nginx logs:"
    echo "      → tail -f /var/log/nginx/error.log"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

##############################################################################
# ACCESS INFORMATION
##############################################################################

show_access_information() {
    echo -e "\n${GREEN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║  ✅  PISONET INSTALLATION COMPLETE!                             ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo -e "${CYAN}ACCESS INFORMATION:${NC}\n"
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    echo "  🌐  Web Admin Panel:"
    echo "      → http://$server_ip/"
    echo "      → http://$server_ip/admin"
    echo ""
    echo "  📡  API Endpoints:"
    echo "      → http://$server_ip:5000/api/status"
    echo ""
    echo "  🔐  Admin Credentials:"
    echo "      → Username: root"
    echo "      → Password: 1234"
    echo "      → Change in database: UPDATE config SET value='newpassword' WHERE key='admin_password'"
    echo ""
    echo "  📝  Log Files:"
    echo "      → Server: $LOG_DIR/"
    echo "      → Nginx: /var/log/nginx/"
    echo ""
    echo "  🗄️   Database:"
    echo "      → Location: $DATA_DIR/pisonet.db"
    echo ""
    echo "  ✨  Next Steps:"
    echo "      1. Open http://$server_ip in your browser"
    echo "      2. Go to Admin Panel at /admin"
    echo "      3. Configure system settings"
    echo "      4. Set up GPIO pins for coin/relay control"
    echo "      5. Start registering client machines"
    echo ""
}

##############################################################################
# MAIN EXECUTION
##############################################################################

main() {
    echo ""
    
    # Perform system checks
    check_root
    check_os
    check_python
    
    echo ""
    
    # Run port diagnostics BEFORE installation
    create_installation_directory  # Create data dir for diagnostics
    run_port_diagnostics
    
    echo ""
    show_warning "This script will install PISONET on this system"
    show_warning "With credentials - Username: root, Password: 1234"
    echo ""
    read -p "Press Enter to continue with installation..." 
    
    echo ""
    
    # Install system
    install_dependencies
    setup_python_environment
    install_python_packages
    initialize_database
    
    echo ""
    
    # Setup services
    setup_firewall
    create_systemd_service
    setup_nginx
    start_services
    
    echo ""
    
    # Verify and display results
    verify_installation
    run_port_diagnostics  # Run again after installation
    show_access_information
    show_troubleshooting_guide
    
    echo ""
    show_success "PISONET setup completed successfully!"
    echo ""
}

# Run main if not sourced
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
