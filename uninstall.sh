#!/bin/bash
# WireGuard Complete Uninstallation Script
# Date: 2025-06-24

echo "[$(date +"%Y-%m-%d %H:%M:%S")] Starting WireGuard uninstallation..."

# 1. Stop WireGuard services
echo "[+] Stopping WireGuard services..."
systemctl stop wg-quick@wg0
systemctl disable wg-quick@wg0

# 2. Remove WireGuard interfaces
echo "[+] Removing WireGuard interfaces..."
ip link delete wg0 2>/dev/null

# 3. Remove client configurations
echo "[+] Removing client configurations..."
rm -rf /etc/wireguard/clients/

# 4. Remove WireGuard configurations
echo "[+] Removing WireGuard configurations..."
rm -f /etc/wireguard/wg0.conf
rm -rf /etc/wireguard/*.conf
rm -rf /etc/wireguard/*.key

# 5. Clean up iptables rules related to WireGuard
echo "[+] Cleaning up firewall rules..."
# Delete forwarding rules
iptables -D FORWARD -i wg0 -j ACCEPT 2>/dev/null
iptables -D FORWARD -o wg0 -j ACCEPT 2>/dev/null
# Delete NAT rules
iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE 2>/dev/null
# Try with other common interfaces if eth0 isn't used
iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o ens3 -j MASQUERADE 2>/dev/null
iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o ens5 -j MASQUERADE 2>/dev/null
iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o enp0s3 -j MASQUERADE 2>/dev/null

# 6. Uninstall WireGuard packages based on distro
echo "[+] Removing WireGuard packages..."
if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    apt-get purge -y wireguard wireguard-tools wireguard-dkms
    apt-get autoremove -y
elif [ -f /etc/redhat-release ]; then
    # CentOS/RHEL
    yum remove -y wireguard-tools kmod-wireguard
    # For newer versions
    dnf remove -y wireguard-tools
elif [ -f /etc/arch-release ]; then
    # Arch Linux
    pacman -Rs wireguard-tools
elif [ -f /etc/gentoo-release ]; then
    # Gentoo
    emerge --deselect net-vpn/wireguard-tools
    emerge --depclean
fi

# 7. Remove any custom scripts that might have been added
echo "[+] Removing custom scripts..."
rm -f /usr/local/bin/wireguard_vpn_setup-v2.sh
rm -f /usr/local/bin/wg-*

# 8. Disable IP forwarding if no longer needed
# Uncomment if you're sure no other services need IP forwarding
# echo "[+] Disabling IP forwarding..."
# echo 0 > /proc/sys/net/ipv4/ip_forward
# sysctl -w net.ipv4.ip_forward=0

echo "[$(date +"%Y-%m-%d %H:%M:%S")] WireGuard has been completely uninstalled from the system."
echo "Note: If you've made system-level changes for WireGuard (like in sysctl.conf),"
echo "you may want to review those files manually."
