#!/bin/bash

##############################################################################
#  PISONET Port & Connectivity Diagnostic Tool                              #
#  Use this script to troubleshoot admin panel access issues                 #
#  Version 1.0                                                               #
##############################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║  🔍 PISONET Port & Connectivity Diagnostic Tool                ║
║     Troubleshoot admin panel access issues                     ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

##############################################################################
# DIAGNOSTIC FUNCTIONS
##############################################################################

print_section() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

check_port_listening() {
    local port=$1
    local name=$2
    
    echo -e "🔍 Checking $name (port $port)..."
    
    if ss -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}  ✅ PORT IS LISTENING${NC}"
        ss -tuln | grep ":$port" | sed 's/^/    /'
        
        # Get process info
        echo -e "\n  Process Information:"
        lsof -i :$port 2>/dev/null | tail -n +2 | while read line; do
            echo -e "    ${GREEN}$line${NC}"
        done
        return 0
    else
        echo -e "${RED}  ❌ PORT NOT LISTENING${NC}"
        return 1
    fi
}

check_port_open_in_firewall() {
    local port=$1
    local name=$2
    
    echo -e "\n🔒 Checking Firewall Rules for $name (port $port)..."
    
    if command -v ufw &> /dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            echo -e "  Firewall Status: ${GREEN}ACTIVE${NC}"
            
            # Check if port is allowed
            if sudo ufw status | grep -qE "^$port"; then
                echo -e "  Port $port: ${GREEN}ALLOWED${NC}"
            else
                echo -e "  Port $port: ${RED}NOT IN RULES${NC}"
                echo -e "  ${YELLOW}Hint: Run 'sudo ufw allow $port/tcp'${NC}"
            fi
            
            echo -e "\n  Current UFW Rules:"
            sudo ufw status numbered | head -20 | sed 's/^/    /'
            return 0
        else
            echo -e "  Firewall Status: ${YELLOW}INACTIVE${NC}"
            return 1
        fi
    else
        echo -e "  ${YELLOW}ℹ️  UFW not found - checking iptables...${NC}"
        
        if sudo iptables -L -n 2>/dev/null | grep -q "$port"; then
            echo -e "  iptables rules exist for port $port"
        else
            echo -e "  ${YELLOW}No specific iptables rules found${NC}"
        fi
    fi
}

test_local_connectivity() {
    echo -e "\n📡 Testing Local Connectivity (127.0.0.1)..."
    
    echo -e "  Testing Flask Server (127.0.0.1:5000)..."
    if curl -s http://127.0.0.1:5000/ > /dev/null 2>&1; then
        echo -e "    ${GREEN}✅ Successfully connected${NC}"
    else
        echo -e "    ${RED}❌ Connection failed${NC}"
    fi
    
    echo -e "\n  Testing Nginx (127.0.0.1:80)..."
    if curl -s http://127.0.0.1:80/ > /dev/null 2>&1; then
        echo -e "    ${GREEN}✅ Successfully connected${NC}"
    else
        echo -e "    ${RED}❌ Connection failed${NC}"
    fi
}

test_network_connectivity() {
    echo -e "\n🌐 Testing Network Connectivity..."
    
    local ip=$(hostname -I | awk '{print $1}')
    
    if [ -z "$ip" ]; then
        echo -e "  ${RED}❌ Could not determine IP address${NC}"
        return 1
    fi
    
    echo -e "  Server IP: ${CYAN}$ip${NC}"
    
    echo -e "\n  Testing Flask Server ($ip:5000)..."
    if curl -s http://$ip:5000/ > /dev/null 2>&1; then
        echo -e "    ${GREEN}✅ Successfully connected${NC}"
    else
        echo -e "    ${RED}❌ Connection failed${NC}"
        echo -e "    ${YELLOW}Possible issues:${NC}"
        echo -e "    1. Firewall blocking port 5000"
        echo -e "    2. Flask server not running"
        echo -e "    3. Flask bound to localhost only"
    fi
    
    echo -e "\n  Testing Nginx ($ip:80)..."
    if curl -s http://$ip:80/ > /dev/null 2>&1; then
        echo -e "    ${GREEN}✅ Successfully connected${NC}"
    else
        echo -e "    ${RED}❌ Connection failed${NC}"
        echo -e "    ${YELLOW}Possible issues:${NC}"
        echo -e "    1. Firewall blocking port 80"
        echo -e "    2. Nginx not running"
        echo -e "    3. Nginx proxy not configured"
    fi
}

check_service_status() {
    echo -e "\n⚙️  Checking Service Status..."
    
    echo -e "\n  PISONET Server Service:"
    if systemctl is-active pisonet > /dev/null 2>&1; then
        echo -e "    ${GREEN}✅ Running${NC}"
        systemctl status pisonet --no-pager | sed 's/^/    /'
    else
        echo -e "    ${RED}❌ Not running${NC}"
        echo -e "    ${YELLOW}Start with: sudo systemctl start pisonet${NC}"
    fi
    
    echo -e "\n  Nginx Service:"
    if systemctl is-active nginx > /dev/null 2>&1; then
        echo -e "    ${GREEN}✅ Running${NC}"
    else
        echo -e "    ${RED}❌ Not running${NC}"
        echo -e "    ${YELLOW}Start with: sudo systemctl start nginx${NC}"
    fi
}

check_server_logs() {
    echo -e "\n📝 Recent Server Logs..."
    
    echo -e "\n  Last 10 lines of PISONET log:"
    if [ -f /var/log/pisonet/server.log ]; then
        tail -10 /var/log/pisonet/server.log | sed 's/^/    /'
    else
        echo -e "    ${YELLOW}Log file not found${NC}"
    fi
    
    echo -e "\n  Systemd journal (last 20 lines):"
    sudo journalctl -u pisonet -n 20 --no-pager | sed 's/^/    /'
}

check_nginx_config() {
    echo -e "\n⚙️  Nginx Configuration..."
    
    echo -e "  Testing Nginx syntax:"
    if sudo nginx -t 2>&1 | grep -q "successful"; then
        echo -e "    ${GREEN}✅ Syntax OK${NC}"
    else
        echo -e "    ${RED}❌ Configuration error${NC}"
        sudo nginx -t 2>&1 | sed 's/^/    /'
    fi
    
    echo -e "\n  Reverse proxy configuration (port 80 → 5000):"
    if [ -f /etc/nginx/sites-available/pisonet ]; then
        grep "proxy_pass" /etc/nginx/sites-available/pisonet | sed 's/^/    /'
    else
        echo -e "    ${YELLOW}Nginx PISONET config not found${NC}"
    fi
}

generate_report() {
    local report_file="/tmp/pisonet_diagnostic_report.txt"
    
    echo -e "\n${CYAN}Generating comprehensive diagnostic report...${NC}"
    
    cat > "$report_file" << 'REPORT_EOF'
╔════════════════════════════════════════════════════════════════╗
║  PISONET DIAGNOSTIC REPORT                                     ║
║  Generated: $(date)
╚════════════════════════════════════════════════════════════════╝

=== SYSTEM INFORMATION ===
Hostname: $(hostname)
Kernel: $(uname -r)
Uptime: $(uptime)

=== NETWORK STATUS ===
IP Address: $(hostname -I | awk '{print $1}')
DNS: $(cat /etc/resolv.conf 2>/dev/null | head -5)

=== PORT STATUS ===
Port 5000 (Flask): $(ss -tuln | grep -q ":5000" && echo "LISTENING" || echo "NOT LISTENING")
Port 80 (HTTP): $(ss -tuln | grep -q ":80" && echo "LISTENING" || echo "NOT LISTENING")
Port 443 (HTTPS): $(ss -tuln | grep -q ":443" && echo "LISTENING" || echo "NOT LISTENING")

=== SERVICE STATUS ===
PISONET: $(systemctl is-active pisonet 2>/dev/null || echo "NOT INSTALLED")
Nginx: $(systemctl is-active nginx 2>/dev/null || echo "NOT INSTALLED")

=== FIREWALL ===
UFW Status: $(sudo ufw status 2>/dev/null | head -1 || echo "Not available")

REPORT_EOF
    
    echo -e "  Report saved to: ${GREEN}$report_file${NC}"
    echo -e "  Use: ${CYAN}cat $report_file${NC}\n"
}

##############################################################################
# QUICK FIXES
##############################################################################

show_quick_fixes() {
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}COMMON FIXES${NC}\n"
    
    echo -e "If admin panel is not accessible:\n"
    
    echo -e "${CYAN}1. Start Flask Server:${NC}"
    echo -e "   ${GREEN}sudo systemctl start pisonet${NC}\n"
    
    echo -e "${CYAN}2. Start Nginx:${NC}"
    echo -e "   ${GREEN}sudo systemctl start nginx${NC}\n"
    
    echo -e "${CYAN}3. Allow port 5000 in firewall:${NC}"
    echo -e "   ${GREEN}sudo ufw allow 5000/tcp${NC}\n"
    
    echo -e "${CYAN}4. Allow port 80 in firewall:${NC}"
    echo -e "   ${GREEN}sudo ufw allow 80/tcp${NC}\n"
    
    echo -e "${CYAN}5. Reload firewall:${NC}"
    echo -e "   ${GREEN}sudo ufw reload${NC}\n"
    
    echo -e "${CYAN}6. Restart PISONET:${NC}"
    echo -e "   ${GREEN}sudo systemctl restart pisonet${NC}\n"
    
    echo -e "${CYAN}7. Restart Nginx:${NC}"
    echo -e "   ${GREEN}sudo systemctl restart nginx${NC}\n"
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

##############################################################################
# MAIN EXECUTION
##############################################################################

main() {
    print_section "1. CHECKING PORT LISTENERS"
    check_port_listening 5000 "Flask Server"
    check_port_listening 80 "Nginx HTTP Server"
    
    print_section "2. CHECKING FIREWALL RULES"
    check_port_open_in_firewall 5000 "Flask"
    check_port_open_in_firewall 80 "Nginx"
    
    print_section "3. TESTING LOCAL CONNECTIVITY"
    test_local_connectivity
    
    print_section "4. TESTING NETWORK CONNECTIVITY"
    test_network_connectivity
    
    print_section "5. CHECKING SERVICE STATUS"
    check_service_status
    
    print_section "6. CHECKING NGINX CONFIGURATION"
    check_nginx_config
    
    print_section "7. CHECKING SERVER LOGS"
    check_server_logs
    
    show_quick_fixes
    
    print_section "SUMMARY"
    
    local flask_ok=0
    local nginx_ok=0
    local firewall_ok=0
    
    # Quick result check
    if ss -tuln 2>/dev/null | grep -q ":5000"; then
        echo -e "${GREEN}✅ Flask Server is listening on port 5000${NC}"
        flask_ok=1
    else
        echo -e "${RED}❌ Flask Server not listening on port 5000${NC}"
    fi
    
    if ss -tuln 2>/dev/null | grep -q ":80"; then
        echo -e "${GREEN}✅ Nginx is listening on port 80${NC}"
        nginx_ok=1
    else
        echo -e "${RED}❌ Nginx not listening on port 80${NC}"
    fi
    
    if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
        echo -e "${GREEN}✅ Firewall is active and configured${NC}"
        firewall_ok=1
    else
        echo -e "${YELLOW}⚠️  Firewall not active or not configured${NC}"
    fi
    
    if [ $flask_ok -eq 1 ] && [ $nginx_ok -eq 1 ]; then
        echo -e "\n${GREEN}✅ PISONET should be accessible!${NC}"
        echo -e "Access at: ${CYAN}http://$(hostname -I | awk '{print $1}')${NC}\n"
    else
        echo -e "\n${RED}❌ PISONET is not fully accessible${NC}"
        echo -e "Use the common fixes above to resolve issues\n"
    fi
}

# Run main
main "$@"
