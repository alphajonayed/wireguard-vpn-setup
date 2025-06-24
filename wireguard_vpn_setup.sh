#!/bin/bash

# Enhanced WireGuard VPN Setup Script
# Updated: 2025-06-24
# Author: alphajonayed

# Error handling
set -euo pipefail

# Configuration
WG_CONF="/etc/wireguard/wg0.conf"
WG_IFACE="wg0"
SERVER_IP="20.163.96.79"
SERVER_PORT=51820
WG_NETWORK="10.0.0.0/24"
WG_NETMASK=24
WG_INTERFACE_IP="10.0.0.1"
CLIENT_START_IP=2

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Configuration validation
validate_config() {
    log "Validating configuration..."
    
    # Check if IP is valid
    if ! [[ $SERVER_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        error "Invalid SERVER_IP format: $SERVER_IP"
        exit 1
    fi
    
    # Check if port is valid
    if ! [[ $SERVER_PORT =~ ^[0-9]+$ ]] || [ $SERVER_PORT -lt 1 ] || [ $SERVER_PORT -gt 65535 ]; then
        error "Invalid SERVER_PORT. Must be between 1-65535"
        exit 1
    fi
    
    # Check if WireGuard is already installed
    if systemctl is-active --quiet wg-quick@$WG_IFACE 2>/dev/null; then
        warning "WireGuard is already running on interface $WG_IFACE"
    fi
}

# Get next available client IP
get_next_client_ip() {
    local next_ip
    if [[ ! -f $WG_CONF ]]; then
        echo "10.0.0.2"
        return
    fi
    
    # Find the highest used IP
    local highest_ip=$(grep -oP 'AllowedIPs = 10\.0\.0\.\K[0-9]+' $WG_CONF 2>/dev/null | sort -n | tail -1)
    if [[ -z $highest_ip ]]; then
        next_ip=2
    else
        next_ip=$((highest_ip + 1))
    fi
    
    if [[ $next_ip -gt 254 ]]; then
        error "No more IP addresses available in subnet"
        exit 1
    fi
    
    echo "10.0.0.$next_ip"
}

# Install WireGuard and dependencies
install_wireguard() {
    check_root
    validate_config
    
    log "Installing WireGuard and dependencies..."
    
    # Detect OS and install accordingly
    if command -v dnf >/dev/null 2>&1; then
        # RHEL/CentOS/Rocky/Alma Linux
        dnf update -y
        dnf install -y epel-release firewalld kmod-wireguard wireguard-tools nano qrencode
    elif command -v yum >/dev/null 2>&1; then
        # Older CentOS
        yum update -y
        yum install -y epel-release firewalld wireguard-tools nano qrencode
    elif command -v apt >/dev/null 2>&1; then
        # Ubuntu/Debian
        apt update
        apt install -y wireguard firewalld nano qrencode
    else
        error "Unsupported package manager. Please install WireGuard manually."
        exit 1
    fi
    
    # Enable and start firewall
    systemctl enable firewalld --now
    
    log "Enabling IP forwarding..."
    # Remove duplicate entries first
    sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    sed -i '/net.ipv6.conf.all.forwarding/d' /etc/sysctl.conf
    
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    sysctl -p
    
    log "WireGuard installation completed"
}

# Generate server keys
generate_server_keys() {
    log "Generating server keys..."
    mkdir -p /etc/wireguard
    
    # Generate keys only if they don't exist
    if [[ ! -f /etc/wireguard/server_private.key ]]; then
        wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
        chmod 600 /etc/wireguard/server_private.key
        chmod 644 /etc/wireguard/server_public.key
        log "New server keys generated"
    else
        warning "Server keys already exist, skipping generation"
    fi
    
    SERVER_PRIV_KEY=$(cat /etc/wireguard/server_private.key)
    SERVER_PUB_KEY=$(cat /etc/wireguard/server_public.key)
}

# Create server configuration
create_server_config() {
    log "Creating WireGuard server configuration..."
    
    # Backup existing config if it exists
    if [[ -f $WG_CONF ]]; then
        cp $WG_CONF $WG_CONF.backup.$(date +%s)
        warning "Existing config backed up"
    fi
    
    cat > $WG_CONF <<EOF
# WireGuard Server Configuration
# Generated: $(date)
# Server: $SERVER_IP:$SERVER_PORT

[Interface]
Address = $WG_INTERFACE_IP/$WG_NETMASK
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIV_KEY
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; iptables -A INPUT -p udp --dport $SERVER_PORT -j ACCEPT
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; iptables -D INPUT -p udp --dport $SERVER_PORT -j ACCEPT
EOF
    
    chmod 600 $WG_CONF
    log "Server configuration created"
}

# Setup firewall rules
setup_firewall() {
    log "Configuring firewall..."
    
    # Add WireGuard port
    firewall-cmd --add-port=$SERVER_PORT/udp --permanent
    
    # Enable masquerading for NAT
    firewall-cmd --zone=public --add-masquerade --permanent
    
    # Allow forwarding
    firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -i $WG_IFACE -j ACCEPT
    firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -o $WG_IFACE -j ACCEPT
    
    # Reload firewall
    firewall-cmd --reload
    
    log "Firewall configured successfully"
}

# Setup port forwarding
setup_port_forwarding() {
    local client_ip=$1
    local external_port=$2
    local internal_port=${3:-22}
    local protocol=${4:-tcp}
    
    log "Setting up port forwarding: $external_port/$protocol -> $client_ip:$internal_port"
    
    # Check if port is already in use
    if ss -tuln | grep -q ":$external_port "; then
        warning "Port $external_port appears to be in use"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Port forwarding setup cancelled"
            return 1
        fi
    fi
    
    # Add iptables rules
    iptables -t nat -A PREROUTING -p $protocol --dport $external_port -j DNAT --to-destination $client_ip:$internal_port
    iptables -A FORWARD -p $protocol -d $client_ip --dport $internal_port -j ACCEPT
    
    # Add firewall rule
    firewall-cmd --add-port=$external_port/$protocol --permanent
    firewall-cmd --reload
    
    # Save iptables rules for persistence
    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > /etc/iptables.rules
        
        # Create systemd service to restore iptables on boot
        cat > /etc/systemd/system/iptables-restore.service <<EOF
[Unit]
Description=Restore iptables rules
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables.rules
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        systemctl enable iptables-restore.service
    fi
    
    log "Port forwarding configured: $external_port/$protocol -> $client_ip:$internal_port"
}

# Start WireGuard service
start_wireguard() {
    log "Starting WireGuard service..."
    
    # Enable and start the service
    systemctl enable wg-quick@$WG_IFACE
    systemctl start wg-quick@$WG_IFACE
    
    # Wait a moment and check status
    sleep 2
    if systemctl is-active --quiet wg-quick@$WG_IFACE; then
        log "WireGuard service started successfully"
    else
        error "Failed to start WireGuard service"
        systemctl status wg-quick@$WG_IFACE --no-pager
        exit 1
    fi
}

# Add client with enhanced validation
add_client() {
    check_root
    
    local client_name=$1
    local external_port=$2
    local internal_port=${3:-22}
    local protocol=${4:-tcp}
    
    if [[ -z $client_name || -z $external_port ]]; then
        error "Usage: $0 add-client <client-name> <external-port> [internal-port] [protocol]"
        echo "Examples:"
        echo "  $0 add-client alice 2222               # SSH access"
        echo "  $0 add-client bob 8080 80 tcp          # Web server"
        echo "  $0 add-client charlie 25565 25565 tcp  # Minecraft server"
        exit 1
    fi
    
    # Validate client name
    if ! [[ $client_name =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Client name must contain only alphanumeric characters, underscores, and dashes"
        exit 1
    fi
    
    # Validate port numbers
    if ! [[ $external_port =~ ^[0-9]+$ ]] || [ $external_port -lt 1 ] || [ $external_port -gt 65535 ]; then
        error "Invalid external port. Must be between 1-65535"
        exit 1
    fi
    
    if ! [[ $internal_port =~ ^[0-9]+$ ]] || [ $internal_port -lt 1 ] || [ $internal_port -gt 65535 ]; then
        error "Invalid internal port. Must be between 1-65535"
        exit 1
    fi
    
    # Validate protocol
    if [[ $protocol != "tcp" && $protocol != "udp" ]]; then
        error "Protocol must be either 'tcp' or 'udp'"
        exit 1
    fi
    
    # Check if server is running
    if ! systemctl is-active --quiet wg-quick@$WG_IFACE; then
        error "WireGuard server is not running. Please run '$0 install' first."
        exit 1
    fi
    
    # Check if client already exists
    if grep -q "# $client_name" $WG_CONF; then
        error "Client '$client_name' already exists"
        exit 1
    fi
    
    local client_ip=$(get_next_client_ip)
    
    log "Creating client '$client_name' with IP: $client_ip"
    
    # Generate client keys
    local client_priv_key=$(wg genkey)
    local client_pub_key=$(echo $client_priv_key | wg pubkey)
    
    # Backup current config
    cp $WG_CONF $WG_CONF.backup.$(date +%s)
    
    # Add client to server config
    cat >> $WG_CONF <<EOF

[Peer]
# $client_name - Created: $(date)
PublicKey = $client_pub_key
AllowedIPs = $client_ip/32
EOF

    # Reload WireGuard
    systemctl restart wg-quick@$WG_IFACE
    
    # Setup port forwarding
    if ! setup_port_forwarding $client_ip $external_port $internal_port $protocol; then
        error "Failed to setup port forwarding"
        exit 1
    fi
    
    # Create client config directory
    mkdir -p /etc/wireguard/clients
    
    # Create client config file
    local client_conf="/etc/wireguard/clients/${client_name}.conf"
    cat > $client_conf <<EOF
# WireGuard Client Configuration for $client_name
# Created: $(date)
# VPN IP: $client_ip
# Port forwarding: $SERVER_IP:$external_port -> $client_ip:$internal_port ($protocol)

[Interface]
PrivateKey = $client_priv_key
Address = $client_ip/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
PublicKey = $(cat /etc/wireguard/server_public.key)
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    chmod 600 $client_conf
    
    log "Client '$client_name' created successfully!"
    info "Configuration saved to: $client_conf"
    info "VPN IP: $client_ip"
    info "Port forwarding: $SERVER_IP:$external_port -> $client_ip:$internal_port ($protocol)"
    
    # Generate QR code if available
    if command -v qrencode >/dev/null 2>&1; then
        echo ""
        info "QR Code for mobile clients:"
        qrencode -t ansiutf8 < $client_conf
    else
        warning "Install 'qrencode' package to generate QR codes for mobile clients"
    fi
    
    # Show client config content
    echo ""
    info "Client configuration (copy this to your WireGuard client):"
    echo "----------------------------------------"
    cat $client_conf
    echo "----------------------------------------"
}

# List all clients
list_clients() {
    log "Listing all clients:"
    
    if [[ ! -f $WG_CONF ]]; then
        warning "No WireGuard configuration found"
        return 1
    fi
    
    local client_count=0
    echo ""
    printf "%-15s %-15s %-20s %-10s\n" "CLIENT NAME" "VPN IP" "CREATED" "STATUS"
    echo "---------------------------------------------------------------"
    
    while IFS= read -r line; do
        if [[ $line =~ ^#[[:space:]]+([^[:space:]]+)[[:space:]]+-[[:space:]]+Created:[[:space:]]+(.+)$ ]]; then
            local client_name="${BASH_REMATCH[1]}"
            local created_date="${BASH_REMATCH[2]}"
            
            # Get the next line which should contain AllowedIPs
            read -r next_line
            if [[ $next_line =~ AllowedIPs[[:space:]]*=[[:space:]]*([0-9.]+)/32 ]]; then
                local client_ip="${BASH_REMATCH[1]}"
                local status="Active"
                
                printf "%-15s %-15s %-20s %-10s\n" "$client_name" "$client_ip" "${created_date:0:16}" "$status"
                ((client_count++))
            fi
        fi
    done < $WG_CONF
    
    echo ""
    info "Total clients: $client_count"
    
    # Show WireGuard interface status
    if systemctl is-active --quiet wg-quick@$WG_IFACE; then
        echo ""
        info "WireGuard interface status:"
        wg show
    fi
}

# Remove client
remove_client() {
    check_root
    
    local client_name=$1
    if [[ -z $client_name ]]; then
        error "Usage: $0 remove-client <client-name>"
        exit 1
    fi
    
    if [[ ! -f $WG_CONF ]]; then
        error "WireGuard configuration not found"
        exit 1
    fi
    
    if ! grep -q "# $client_name" $WG_CONF; then
        error "Client '$client_name' not found"
        exit 1
    fi
    
    log "Removing client '$client_name'..."
    
    # Get client IP before removal
    local client_ip=$(grep -A1 "# $client_name" $WG_CONF | grep "AllowedIPs" | grep -oP '10\.0\.0\.[0-9]+')
    
    # Backup config
    cp $WG_CONF $WG_CONF.backup.$(date +%s)
    
    # Remove client from config (remove comment line and next 2 lines)
    sed -i "/^# $client_name/,+2d" $WG_CONF
    
    # Remove empty lines
    sed -i '/^$/N;/^\n$/d' $WG_CONF
    
    # Remove client config file
    local client_conf="/etc/wireguard/clients/${client_name}.conf"
    if [[ -f $client_conf ]]; then
        rm -f $client_conf
        log "Client configuration file removed"
    fi
    
    # Restart WireGuard
    systemctl restart wg-quick@$WG_IFACE
    
    log "Client '$client_name' removed successfully"
    warning "Note: Port forwarding rules may still exist. Check with 'iptables -t nat -L' if needed."
}

# Show WireGuard status
show_status() {
    log "WireGuard Service Status:"
    systemctl status wg-quick@$WG_IFACE --no-pager
    
    echo ""
    if systemctl is-active --quiet wg-quick@$WG_IFACE; then
        log "WireGuard Interface Details:"
        wg show
        
        echo ""
        log "Network Configuration:"
        ip addr show $WG_IFACE 2>/dev/null || warning "Interface $WG_IFACE not found"
        
        echo ""
        log "Active Connections:"
        ss -tuln | grep $SERVER_PORT || warning "No connections found on port $SERVER_PORT"
    else
        warning "WireGuard is not running"
    fi
}

# Backup configuration
backup_config() {
    check_root
    
    local backup_dir="/root/wireguard-backups"
    local backup_file="$backup_dir/wireguard-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    mkdir -p $backup_dir
    
    log "Creating backup..."
    tar -czf $backup_file /etc/wireguard/ /etc/iptables.rules 2>/dev/null || true
    
    if [[ -f $backup_file ]]; then
        log "Configuration backed up to: $backup_file"
        info "Backup size: $(du -h $backup_file | cut -f1)"
    else
        error "Backup failed"
        exit 1
    fi
}

# Show firewall status
show_firewall() {
    log "Firewall Status:"
    firewall-cmd --list-all
    
    echo ""
    log "Port Forwarding Rules:"
    iptables -t nat -L PREROUTING -n --line-numbers | grep -E "DNAT|tcp|udp" || info "No port forwarding rules found"
}

# Show usage
show_usage() {
    echo ""
    echo "WireGuard VPN Setup Script v2.0"
    echo "Updated: 2025-06-24 by alphajonayed"
    echo ""
    echo "USAGE:"
    echo "  $0 <command> [options]"
    echo ""
    echo "COMMANDS:"
    echo "  install                                    Install and setup WireGuard server"
    echo "  add-client <name> <ext-port> [int-port] [protocol]   Add client with port forwarding"
    echo "  list-clients                               List all clients"
    echo "  remove-client <name>                       Remove a client"
    echo "  status                                     Show WireGuard status"
    echo "  backup                                     Backup configuration"
    echo "  firewall                                   Show firewall status"
    echo "  help                                       Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 install                                 # Install WireGuard server"
    echo "  $0 add-client alice 2222                   # SSH access (port 22)"
    echo "  $0 add-client bob 8080 80 tcp              # Web server"
    echo "  $0 add-client charlie 25565 25565 tcp      # Minecraft server"
    echo "  $0 add-client dave 27015 27015 udp         # Game server (UDP)"
    echo "  $0 list-clients                            # Show all clients"
    echo "  $0 remove-client alice                     # Remove client"
    echo "  $0 status                                  # Show status"
    echo ""
    echo "NOTES:"
    echo "  - Default internal port is 22 (SSH)"
    echo "  - Default protocol is TCP"
    echo "  - All commands require root privileges"
    echo "  - Client configs are saved to /etc/wireguard/clients/"
    echo ""
}

# Main script logic
case "${1:-}" in
    install)
        log "Starting WireGuard installation..."
        install_wireguard
        generate_server_keys
        create_server_config
        setup_firewall
        start_wireguard
        echo ""
        log "WireGuard installation completed successfully!"
        info "Server public key: $(cat /etc/wireguard/server_public.key)"
        info "Server endpoint: $SERVER_IP:$SERVER_PORT"
        info "VPN network: $WG_NETWORK"
        echo ""
        info "Next steps:"
        echo "  1. Add clients: $0 add-client <name> <port>"
        echo "  2. Check status: $0 status"
        echo "  3. List clients: $0 list-clients"
        ;;
    add-client)
        shift
        add_client "$@"
        ;;
    list-clients)
        list_clients
        ;;
    remove-client)
        shift
        remove_client "$@"
        ;;
    status)
        show_status
        ;;
    backup)
        backup_config
        ;;
    firewall)
        show_firewall
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        error "Unknown command: ${1:-}"
        show_usage
        exit 1
        ;;
esac