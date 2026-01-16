<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# nftables Setup Guide

Production-ready deployment guide for nftables firewall on Ubuntu servers.

## TL;DR (30 seconds)

```bash
# 1. Install
sudo apt update && sudo apt install nftables

# 2. Choose template
sudo cp drop-ins/10-gateway.nft.template /etc/nftables.conf

# 3. Customize
sudo nano /etc/nftables.conf  # Edit WAN_INTERFACE, LAN_INTERFACE, networks

# 4. Deploy
sudo scripts/validate-nftables.sh /etc/nftables.conf
sudo scripts/deploy-nftables.sh /etc/nftables.conf
```

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Template Selection](#template-selection)
- [Customization](#customization)
- [Validation](#validation)
- [Deployment](#deployment)
- [Verification](#verification)
- [Migration from ufw/iptables](#migration)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

**Supported Systems**:
- Ubuntu 22.04 LTS or newer
- Debian 11 (Bullseye) or newer
- Any Linux with nftables 0.9.3+

**Requirements**:
- Root access (sudo)
- Basic networking knowledge
- SSH access (recommended: separate management network)

**Before You Start**:
- ⚠️ **CRITICAL**: Have physical/console access OR SSH from management network
- ⚠️ **BACKUP**: Take system snapshot if using VM
- ⚠️ **PLAN**: Know your interfaces (`ip link show`)

---

## Installation

### Install nftables

```bash
# Update package list
sudo apt update

# Install nftables
sudo apt install nftables

# Verify installation
nft --version
# Expected: nftables v0.9.3 or newer

# Check service status
systemctl status nftables.service
```

### Disable Conflicting Firewalls

**IMPORTANT**: Only one firewall should be active at a time.

```bash
# If using ufw (Ubuntu Firewall)
sudo ufw disable
sudo systemctl disable ufw

# If using iptables-persistent
sudo systemctl stop netfilter-persistent
sudo systemctl disable netfilter-persistent

# Verify no conflicts
sudo iptables -L -n  # Should show default ACCEPT policies
```

---

## Template Selection

Choose a template based on your device role:

### Gateway/Router (10-gateway.nft)

**Use when**:
- Home gateway
- Raspberry Pi router
- pfSense/OPNsense replacement
- Multi-WAN failover

**Includes**:
- NAT masquerading
- FORWARD chain for routing
- LAN → WAN internet access
- MSS clamping (critical for NAT)

```bash
sudo cp drop-ins/10-gateway.nft.template /etc/nftables.conf
```

---

### Server/NAS (20-server.nft)

**Use when**:
- NAS server (Samba, NFS)
- Database server (PostgreSQL, MariaDB)
- Application server (Nextcloud, Grafana)

**Includes**:
- File sharing ports (Samba, NFS)
- Database ports
- Monitoring ports (Prometheus, Grafana)
- NO NAT/routing

```bash
sudo cp drop-ins/20-server.nft.template /etc/nftables.conf
```

---

### Minimal (30-minimal.nft)

**Use when**:
- Web server only (nginx, Apache)
- Minimal attack surface
- Entry-level hardening

**Includes**:
- SSH (restricted to management network)
- HTTP/HTTPS (public)
- Nothing else (least privilege)

```bash
sudo cp drop-ins/30-minimal.nft.template /etc/nftables.conf
```

---

### Docker Host (40-docker.nft)

**Use when**:
- Running Docker containers
- Docker Compose stacks

**Includes**:
- Docker DOCKER chain preservation
- Container → Internet access
- LAN → Container access
- Inter-container communication

**CRITICAL**: Never use `flush ruleset` with this template!

```bash
sudo cp drop-ins/40-docker.nft.template /etc/nftables.conf
```

---

## Customization

### Identify Your Interfaces

```bash
# List all interfaces
ip link show

# Common interface names:
# - eth0, eth1 (Ethernet)
# - enp0s31f6 (systemd predictable names)
# - wlan0 (WiFi)
# - br0 (Bridge)
```

### Edit Configuration

```bash
sudo nano /etc/nftables.conf
```

**Required Variables** (customize for your system):

```nft
# WAN Interface (connects to Internet)
define WAN_INTERFACE = "eth0"      # YOUR WAN INTERFACE HERE

# LAN Interface (connects to local network)
define LAN_INTERFACE = "eth3"      # YOUR LAN INTERFACE HERE

# Management Network (optional)
define MGMT_INTERFACE = "eth1"     # YOUR MANAGEMENT INTERFACE

# Network Ranges
define LAN_NETWORK = 192.168.100.0/24    # YOUR SUBNET HERE
define MGMT_NETWORK = 10.0.0.0/24        # YOUR MANAGEMENT SUBNET
```

**Docker Users**: Add your Docker networks

```bash
# Find Docker networks
docker network inspect bridge | grep Subnet
docker network inspect <your-network> | grep Subnet

# Add to config
define DOCKER_NETWORKS = { 172.17.0.0/16, 172.18.0.0/16 }
```

---

## Validation

**ALWAYS validate before deployment!**

```bash
# Basic syntax check
sudo nft -c -f /etc/nftables.conf

# Full validation (recommended)
sudo scripts/validate-nftables.sh /etc/nftables.conf
```

**Validation Checks**:
- ✅ Syntax correctness
- ✅ Rule order (accept before drop)
- ✅ Docker chain preservation
- ✅ Interface existence
- ✅ Security best practices
- ✅ NAT configuration

**Exit Codes**:
- 0: Valid configuration
- 1: Warnings (non-critical)
- 2: Errors (critical issues)
- 3: Lockout risk (SSH issues)

---

## Deployment

### Safe Deployment (Recommended)

```bash
# Use deployment script (with automatic rollback)
sudo scripts/deploy-nftables.sh /etc/nftables.conf
```

**What it does**:
1. Validates configuration
2. Creates backup
3. Applies rules
4. Waits for confirmation (30s)
5. Rolls back if no confirmation

**IMPORTANT**: Keep your SSH session open during deployment!

---

### Manual Deployment (Advanced)

```bash
# 1. Backup current config
sudo cp /etc/nftables.conf /etc/nftables.conf.backup

# 2. Apply new rules
sudo nft -f /etc/nftables.conf

# 3. Test connectivity
ping 8.8.8.8
ssh user@host

# 4. If OK, enable service
sudo systemctl enable nftables.service
sudo systemctl restart nftables.service

# 5. If FAILED, rollback
sudo nft flush ruleset
sudo nft -f /etc/nftables.conf.backup
```

---

## Verification

### Check Rules

```bash
# List all rules
sudo nft list ruleset

# List specific table
sudo nft list table inet filter

# List NAT table
sudo nft list table ip nat

# Check specific chain
sudo nft list chain inet filter input
```

### Test Connectivity

**Gateway/Router**:
```bash
# From LAN client, test internet
ping 8.8.8.8
curl https://www.google.com

# From router, check NAT
sudo nft list table ip nat | grep masquerade
```

**Server/NAS**:
```bash
# Test SSH
ssh user@server-ip

# Test Samba
smbclient -L //server-ip

# Test web services
curl http://server-ip
```

**Docker Host**:
```bash
# Test container internet access
docker run --rm alpine ping -c 3 8.8.8.8

# Check Docker chains
sudo nft list ruleset | grep DOCKER
```

### Check Logs

```bash
# System logs
sudo journalctl -u nftables.service

# Dropped packets (if logging enabled)
sudo journalctl -k | grep nft
sudo dmesg | grep nft
```

---

## Migration

### From ufw

```bash
# 1. List current ufw rules
sudo ufw status numbered

# 2. Map to nftables syntax
# ufw allow 22/tcp → tcp dport 22 accept
# ufw allow from 192.168.1.0/24 → ip saddr 192.168.1.0/24 accept

# 3. Disable ufw
sudo ufw disable

# 4. Deploy nftables
sudo scripts/deploy-nftables.sh /etc/nftables.conf
```

### From iptables

```bash
# 1. Export iptables rules
sudo iptables-save > iptables.rules

# 2. Convert to nftables (manual - no automatic tool)
# iptables -A INPUT -p tcp --dport 22 -j ACCEPT
# → tcp dport 22 accept

# 3. Stop iptables
sudo systemctl stop netfilter-persistent

# 4. Deploy nftables
sudo scripts/deploy-nftables.sh /etc/nftables.conf
```

**Common Mappings**:
| iptables | nftables |
|----------|----------|
| `-A INPUT -j ACCEPT` | `accept` |
| `-A INPUT -j DROP` | `drop` |
| `-p tcp --dport 22` | `tcp dport 22` |
| `-s 192.168.1.0/24` | `ip saddr 192.168.1.0/24` |
| `-i eth0` | `iifname "eth0"` |
| `-o eth0` | `oifname "eth0"` |

---

## Troubleshooting

### Lost SSH Access

**Emergency Fix** (via console/physical access):

```bash
# Flush all rules (WARNING: No firewall!)
sudo nft flush ruleset

# Restore backup
sudo nft -f /etc/nftables.conf.backup

# OR: Allow SSH temporarily
sudo nft add rule inet filter input tcp dport 22 accept
```

### Internet Not Working (Gateway)

**Check**:
```bash
# 1. Check NAT
sudo nft list table ip nat | grep masquerade

# 2. Check routing
ip route show

# 3. Check forward chain
sudo nft list chain inet filter forward
```

**Common Issues**:
- Missing masquerade rule
- Wrong WAN interface
- Forward chain blocking

### Docker No Internet

**Check**:
```bash
# 1. Check Docker chains exist
sudo nft list ruleset | grep DOCKER

# 2. Check forward rules
sudo nft list chain inet filter forward

# 3. Test from container
docker run --rm alpine ping -c 3 8.8.8.8
```

**Common Issues**:
- Used `flush ruleset` (destroyed Docker chains)
- Missing Docker forward rules
- Missing Docker NAT rules

---

## Next Steps

- **Monitoring**: [nftables-metrics.sh](../scripts/nftables-metrics.sh) for Prometheus
- **Advanced Features**: [WIREGUARD_INTEGRATION.md](WIREGUARD_INTEGRATION.md)
- **Docker Networking**: [DOCKER_NETWORKING.md](DOCKER_NETWORKING.md)
- **CIS Compliance**: [CIS_CONTROLS.md](CIS_CONTROLS.md)
- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

**Questions?** Open an issue at https://github.com/fidpa/ubuntu-server-security
