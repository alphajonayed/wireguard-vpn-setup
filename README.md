# wireguard-vpn-setup
# WireGuard VPN Server Setup Script

A comprehensive bash script for setting up WireGuard VPN server with port forwarding capabilities on VPS servers. This script automates the entire process from installation to client management.

## 🚀 Features

- **Automated Installation**: One-command setup for WireGuard VPN server
- **Port Forwarding**: Built-in support for TCP/UDP port forwarding
- **Client Management**: Easy add/remove/list clients with configuration generation
- **Multi-OS Support**: Works on Ubuntu, Debian, CentOS, RHEL, Rocky Linux, Alma Linux
- **QR Code Generation**: Automatic QR codes for mobile client setup
- **Backup & Restore**: Configuration backup functionality
- **Security**: Proper firewall configuration and secure key generation
- **Monitoring**: Status checking and connection monitoring

## 📋 Server Requirements

### Minimum System Requirements
- **RAM**: 512 MB (1 GB recommended)
- **Storage**: 1 GB free space
- **CPU**: 1 vCPU (2 vCPU recommended for high traffic)
- **Network**: 100 Mbps connection

### Supported Operating Systems
- Ubuntu 18.04+ (LTS recommended)
- Debian 9+ (Buster/Bullseye)
- CentOS 7/8 (Stream)
- RHEL 7/8/9
- Rocky Linux 8/9
- Alma Linux 8/9

### Required Privileges
- Root access or sudo privileges
- SSH access to the server

### Network Requirements
- Public IP address
- Open UDP port (default: 51820) for WireGuard
- Additional ports for forwarding services
- Firewall access (script configures automatically)

## 🛠️ Installation

### Step 1: Download the Script

```bash
# Download the script
Version-1
wget https://raw.githubusercontent.com/alphajonayed/wireguard-vpn-setup/main/wireguard_vpn_setup.sh
version-2
wget https://raw.githubusercontent.com/alphajonayed/wireguard-vpn-setup/main/wireguard_vpn_setup-v2.sh

# Or using curl
version 1
curl -O https://raw.githubusercontent.com/alphajonayed/wireguard-vpn-setup/main/wireguard_vpn_setup.sh
version-2
curl -O https://raw.githubusercontent.com/alphajonayed/wireguard-vpn-setup/main/wireguard_vpn_setup-v2.sh


# Make it executable
chmod +x wireguard_vpn_setup.sh
chmod +x wireguard_vpn_setup-v2.sh
```

### Step 2: Configure Server IP

Edit the script to set your server's public IP address:

```bash
nano wireguard_vpn_setup.sh
nano wireguard_vpn_setup-v2.sh
```

Find and update this line:
```bash
SERVER_IP="YOUR_SERVER_PUBLIC_IP"
```

### Step 3: Install WireGuard Server

```bash
# Run as root or with sudo
sudo ./wireguard_vpn_setup.sh install
sudo ./wireguard_vpn_setup-v2.sh install
```

The installation process will:
1. Install WireGuard and dependencies
2. Generate server keys
3. Create server configuration
4. Configure firewall rules
5. Start WireGuard service
6. Enable IP forwarding

## 📖 Usage Guide

### Basic Commands

```bash
# Show help
./wireguard_vpn_setup.sh help

# Install WireGuard server
./wireguard_vpn_setup.sh install

# Add a client
./wireguard_vpn_setup.sh add-client <name> <external-port> [internal-port] [protocol]

# List all clients
./wireguard_vpn_setup.sh list-clients

# Remove a client
./wireguard_vpn_setup.sh remove-client <name>

# Show server status
./wireguard_vpn_setup.sh status

# Backup configuration
./wireguard_vpn_setup.sh backup

# Show firewall status
./wireguard_vpn_setup.sh firewall
```

### Client Management Examples

#### SSH Access
```bash
# Forward port 2222 to client's SSH (port 22)
./wireguard_vpn_setup.sh add-client alice 2222

# Connect via SSH
ssh user@YOUR_SERVER_IP -p 2222
```

#### Web Server
```bash
# Forward port 8080 to client's web server (port 80)
./wireguard_vpn_setup.sh add-client webserver 8080 80 tcp

# Access via browser
http://YOUR_SERVER_IP:8080
```

#### Game Servers
```bash
# Minecraft server
./wireguard_vpn_setup.sh add-client minecraft 25565 25565 tcp

# Counter-Strike server (UDP)
./wireguard_vpn_setup.sh add-client csgo 27015 27015 udp

# Rust server
./wireguard_vpn_setup.sh add-client rust 28015 28015 tcp
```

#### Database Access
```bash
# MySQL/MariaDB
./wireguard_vpn_setup.sh add-client mysql 3306 3306 tcp

# PostgreSQL
./wireguard_vpn_setup.sh add-client postgres 5432 5432 tcp

# MongoDB
./wireguard_vpn_setup.sh add-client mongodb 27017 27017 tcp
```

#### Remote Desktop
```bash
# RDP (Windows)
./wireguard_vpn_setup.sh add-client rdp 3389 3389 tcp

# VNC
./wireguard_vpn_setup.sh add-client vnc 5900 5900 tcp
```

## 🔧 Configuration Files

### Server Configuration
- **Location**: `/etc/wireguard/wg0.conf`
- **Permissions**: 600 (read/write for root only)
- **Backup**: Automatic backups created before modifications

### Client Configurations
- **Location**: `/etc/wireguard/clients/`
- **Format**: `<client-name>.conf`
- **Contains**: Complete client configuration ready for import

### Example Client Configuration
```ini
# WireGuard Client Configuration for alice
# Created: 2025-06-24 11:51:19
# VPN IP: 10.0.0.2
# Port forwarding: 20.163.96.79:2222 -> 10.0.0.2:22

[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.0.0.2/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = 20.163.96.79:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

## 📱 Client Installation

### Windows
1. Download [WireGuarԀ for Windows](https://www.wireguard.com/install/)
2. Import the `.conf` file or scan QR code
3. Connect to the VPN

### macOS
1. Install from App Store or download from [WireGuard website](https://www.wireguard.com/install/)
2. Import configuration file
3. Connect to the VPN

### Linux
```bash
# Install WireGuard
sudo apt install wireguard  # Ubuntu/Debian
sudo dnf install wireguard-tools  # Fedora/CentOS

# Copy configuration
sudo cp client.conf /etc/wireguard/

# Start connection
sudo wg-quick up client
```

### iOS/Android
1. Install WireGuard app from App Store/Play Store
2. Scan QR code displayed by the script
3. Connect to the VPN

## 🔍 Monitoring & Troubleshooting

### Check Server Status
```bash
# Service status
sudo systemctl status wg-quick@wg0

# Interface details
sudo wg show

# Network interface
ip addr show wg0

# Active connections
sudo ss -tuln | grep 51820
```

### Check Port Forwarding
```bash
# List port forwarding rules
sudo iptables -t nat -L PREROUTING -n --line-numbers

# Check specific port
sudo netstat -tlnp | grep :2222
```

### View Logs
```bash
# WireGuard logs
sudo journalctl -u wg-quick@wg0 -f

# System logs
sudo tail -f /var/log/messages
```

### Common Issues & Solutions

#### 1. Connection Timeout
```bash
# Check firewall
sudo firewall-cmd --list-all

# Verify port is open
sudo ss -tuln | grep 51820

# Test connectivity
nc -u -v YOUR_SERVER_IP 51820
```

#### 2. Port Forwarding Not Working
```bash
# Check iptables rules
sudo iptables -t nat -L -n

# Verify client IP
sudo wg show

# Check service on client
# Connect to VPN first, then test port
```

#### 3. DNS Issues
```bash
# Test DNS resolution
nslookup google.com

# Check DNS settings in client config
# Ensure DNS = 8.8.8.8, 1.1.1.1 is set
```

## 🔒 Security Best Practices

### Server Security
- Keep system updated: `sudo apt update && sudo apt upgrade`
- Use strong passwords and SSH keys
- Disable password authentication for SSH
- Enable automatic security updates
- Regular backup of configurations

### VPN Security
- Rotate keys periodically
- Monitor connected clients
- Use strong client names (avoid personal info)
- Regular security audits
- Limit client access as needed

### Firewall Configuration
```bash
# Allow only necessary ports
sudo firewall-cmd --permanent --remove-service=ssh  # If using custom SSH port
sudo firewall-cmd --permanent --add-port=2222/tcp   # Custom SSH port
sudo firewall-cmd --reload
```

## 📊 Performance Optimization

### Server Optimization
```bash
# Increase network buffers
echo 'net.core.rmem_max = 26214400' >> /etc/sysctl.conf
echo 'net.core.rmem_default = 26214400' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 26214400' >> /etc/sysctl.conf
echo 'net.core.wmem_default = 26214400' >> /etc/sysctl.conf
sysctl -p
```

### Client Optimization
- Use `PersistentKeepalive = 25` for NAT traversal
- Adjust MTU if experiencing issues: `MTU = 1420`
- Use closest DNS servers for better performance

## 🗂️ File Structure

```
/etc/wireguard/
├── wg0.conf                 # Server configuration
├── server_private.key       # Server private key
├── server_public.key        # Server public key
├── clients/                 # Client configurations
│   ├── alice.conf
│   ├── webserver.conf
│   └── minecraft.conf
└── backups/                 # Configuration backups
    ├── wg0.conf.backup.1719235879
    └── wg0.conf.backup.1719235901

/root/wireguard-backups/     # Full system backups
├── wireguard-backup-20250624-115119.tar.gz
└── wireguard-backup-20250624-120000.tar.gz
```

## 🔄 Backup & Recovery

### Manual Backup
```bash
# Create backup
./wireguard_vpn_setup.sh backup

# Backup location
ls -la /root/wireguard-backups/
```

### Restore from Backup
```bash
# Stop WireGuard
sudo systemctl stop wg-quick@wg0

# Restore configuration
sudo tar -xzf /root/wireguard-backups/wireguard-backup-YYYYMMDD-HHMMSS.tar.gz -C /

# Start WireGuard
sudo systemctl start wg-quick@wg0
```

## 🚀 Advanced Use Cases

### 1. Multi-Server Setup
```bash
# Server 1: Web services
./wireguard_vpn_setup.sh add-client web-eu 8080 80 tcp
./wireguard_vpn_setup.sh add-client web-eu 8443 443 tcp

# Server 2: Database services
./wireguard_vpn_setup.sh add-client db-us 3306 3306 tcp
./wireguard_vpn_setup.sh add-client db-us 5432 5432 tcp
```

### 2. Development Environment
```bash
# Development server
./wireguard_vpn_setup.sh add-client dev-server 3000 3000 tcp  # Node.js
./wireguard_vpn_setup.sh add-client dev-server 8000 8000 tcp  # Django
./wireguard_vpn_setup.sh add-client dev-server 9000 9000 tcp  # Custom app
```

### 3. Home Lab Access
```bash
# Home services
./wireguard_vpn_setup.sh add-client homelab 8080 80 tcp     # Router admin
./wireguard_vpn_setup.sh add-client homelab 8181 8080 tcp   # Docker admin
./wireguard_vpn_setup.sh add-client homelab 9090 9000 tcp   # Monitoring
```

## 📈 Monitoring & Analytics

### Connection Monitoring
```bash
# Active clients
sudo wg show wg0 peers

# Data transfer
sudo wg show wg0 transfer

# Latest handshakes
sudo wg show wg0 latest-handshakes
```

### Log Analysis
```bash
# Connection logs
sudo journalctl -u wg-quick@wg0 --since "1 hour ago"

# Port forwarding statistics
sudo iptables -t nat -L -n -v
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

### Getting Help
- Create an issue on GitHub
- Check the troubleshooting section
- Review WireGuard documentation

### Reporting Bugs
Please include:
- Operating system and version
- WireGuard version
- Error messages
- Configuration files (without private keys)
- Steps to reproduce

## 📅 Changelog

### v2.0.0 (2025-06-24)
- Enhanced error handling and validation
- Improved client management
- Advanced port forwarding options
- Better user experience with colored output
- QR code generation for mobile clients
- Comprehensive backup functionality
- Multi-OS support improvements

### v1.0.0 (2025-06-20)
- Initial release
- Basic WireGuard server setup
- Simple client management
- Port forwarding support

## 🙏 Acknowledgments

- WireGuard development team
- Contributors and testers
- Community feedback and suggestions

---

**Author**: alphajonayed  
**Last Updated**: 2025-06-24  
**Version**: 2.0.0

For more information, visit the [WireGuard official website](https://www.wireguard.com/).
