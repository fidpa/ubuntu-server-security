<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# WireGuard VPN Integration with nftables

Complete guide to integrating WireGuard VPN with nftables firewall.

## Table of Contents

- [Quick Setup](#quick-setup)
- [Full DNS Takeover](#full-dns-takeover)
- [Advanced Scenarios](#advanced-scenarios)
- [Troubleshooting](#troubleshooting)

---

## Quick Setup

### 1. Install WireGuard

```bash
# Ubuntu 22.04+
sudo apt update
sudo apt install wireguard

# Verify
wg --version
```

### 2. Generate Keys

```bash
# Server keys
wg genkey | sudo tee /etc/wireguard/server_private.key
sudo chmod 600 /etc/wireguard/server_private.key
sudo cat /etc/wireguard/server_private.key | wg pubkey | sudo tee /etc/wireguard/server_public.key

# Client keys (repeat for each client)
wg genkey | tee client_private.key
cat client_private.key | wg pubkey | tee client_public.key
```

### 3. Server Configuration

Create `/etc/wireguard/wg0.conf`:

```ini
[Interface]
Address = 10.29.93.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>

# Client 1
[Peer]
PublicKey = <CLIENT1_PUBLIC_KEY>
AllowedIPs = 10.29.93.2/32

# Client 2
[Peer]
PublicKey = <CLIENT2_PUBLIC_KEY>
AllowedIPs = 10.29.93.3/32
```

**Start WireGuard**:

```bash
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Verify
sudo wg show wg0
```

### 4. nftables Configuration

**Add to /etc/nftables.conf**:

```nft
# VPN Configuration
define VPN_INTERFACE = "wg0"
define VPN_NETWORK = 10.29.93.0/24
define VPN_PORT = 51820

table inet filter {
    chain input {
        # ... baseline rules ...

        # WireGuard handshake (UDP)
        udp dport $VPN_PORT accept comment "WireGuard VPN"

        # SSH from VPN
        iifname $VPN_INTERFACE tcp dport 22 accept comment "SSH from VPN"

        # DNS from VPN (for Full DNS takeover)
        iifname $VPN_INTERFACE udp dport 53 accept comment "DNS from VPN"
        iifname $VPN_INTERFACE tcp dport 53 accept comment "DNS from VPN"

        # Web services from VPN
        iifname $VPN_INTERFACE tcp dport { 80, 443 } accept comment "HTTP/HTTPS from VPN"
    }

    chain forward {
        # ... baseline rules ...

        # VPN → Internet
        iifname $VPN_INTERFACE oifname $WAN_INTERFACE accept comment "VPN to Internet"

        # VPN → LAN
        iifname $VPN_INTERFACE oifname $LAN_INTERFACE accept comment "VPN to LAN"

        # VPN peer-to-peer (critical for client ↔ client communication)
        iifname $VPN_INTERFACE oifname $VPN_INTERFACE accept comment "VPN peer-to-peer"
    }
}

table ip nat {
    chain postrouting {
        # ... existing rules ...

        # VPN → Internet NAT
        oifname $WAN_INTERFACE ip saddr $VPN_NETWORK masquerade comment "VPN to Internet"

        # VPN → LAN NAT (required for return traffic!)
        oifname $LAN_INTERFACE ip saddr $VPN_NETWORK masquerade comment "VPN to LAN"
    }
}
```

**Deploy**:

```bash
sudo scripts/validate-nftables.sh /etc/nftables.conf
sudo scripts/deploy-nftables.sh /etc/nftables.conf
```

---

## Full DNS Takeover

**Use Case**: Force all DNS queries through VPN (no DNS leaks)

**Based on**: Pi 5 Router production pattern (24.12.2025)

### Server Setup

**1. Configure DNS Server** (dnsmasq or AdGuard Home):

```bash
# dnsmasq example
sudo apt install dnsmasq

# Configure to listen on VPN interface
sudo nano /etc/dnsmasq.conf
interface=wg0
listen-address=10.29.93.1
```

**2. nftables Rules** (already included above):

```nft
# DNS on VPN interface
iifname $VPN_INTERFACE udp dport 53 accept comment "DNS from VPN"
iifname $VPN_INTERFACE tcp dport 53 accept comment "DNS from VPN"
```

### Client Setup (Linux)

**Add to client WireGuard config**:

```ini
[Interface]
Address = 10.29.93.2/32
PrivateKey = <CLIENT_PRIVATE_KEY>
DNS = 10.29.93.1

# Full DNS takeover
PostUp = resolvectl domain wg0 "~."
PostUp = resolvectl dns wg0 10.29.93.1
PostUp = resolvectl default-route wg0 true

PostDown = resolvectl revert wg0

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = home.pi-router.de:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

**What it does**:
- `resolvectl domain wg0 "~."` - Route ALL DNS queries through wg0
- `resolvectl dns wg0 10.29.93.1` - Use VPN server's DNS
- `resolvectl default-route wg0 true` - Make wg0 the default DNS route

**Verify**:

```bash
# Check DNS configuration
resolvectl status wg0

# Test DNS resolution
dig @10.29.93.1 google.com

# Check for DNS leaks
curl https://dnsleaktest.com
```

### Client Setup (macOS)

**Manual DNS Configuration**:

1. Connect WireGuard
2. System Settings → Network → WireGuard → DNS
3. Add: `10.29.93.1`
4. Remove other DNS servers

**OR: Use Tunnelblick** (OpenVPN alternative with better DNS handling)

---

## Advanced Scenarios

### VPN → NAS Access

**Allow VPN clients to access NAS services**:

```nft
chain forward {
    # VPN → NAS Samba
    iifname $VPN_INTERFACE ip daddr $NAS_IP tcp dport { 139, 445 } accept comment "VPN to NAS Samba"

    # VPN → NAS NFS
    iifname $VPN_INTERFACE ip daddr $NAS_IP tcp dport { 2049, 111 } accept comment "VPN to NAS NFS"

    # VPN → NAS Web Services
    iifname $VPN_INTERFACE ip daddr $NAS_IP tcp dport { 80, 443 } accept comment "VPN to NAS HTTP/HTTPS"
}

table ip nat {
    chain postrouting {
        # VPN → NAS NAT (critical for return traffic!)
        oifname $LAN_INTERFACE ip saddr $VPN_NETWORK ip daddr $NAS_IP masquerade comment "VPN to NAS"
    }
}
```

**Client Access**:

```bash
# Via VPN
smbclient //192.168.100.2/share
ssh user@192.168.100.2
```

---

### VPN Peer-to-Peer

**Allow VPN clients to communicate with each other**:

```nft
chain forward {
    # VPN peer-to-peer (critical!)
    iifname $VPN_INTERFACE oifname $VPN_INTERFACE accept comment "VPN peer-to-peer"
}
```

**Use Cases**:
- File sharing between VPN clients
- Remote desktop between VPN clients
- Gaming/voice chat

**Test**:

```bash
# From VPN client 1
ping 10.29.93.3  # VPN client 2
ssh user@10.29.93.3
```

---

### Dual-WAN with VPN

**Route VPN traffic through backup WAN if primary fails**:

```nft
chain forward {
    # VPN → Internet (Dual-WAN)
    iifname $VPN_INTERFACE oifname { $WAN_PRIMARY, $WAN_BACKUP } accept comment "VPN to Internet (Dual-WAN)"
}

table ip nat {
    chain postrouting {
        # VPN NAT via both WANs
        oifname { $WAN_PRIMARY, $WAN_BACKUP } ip saddr $VPN_NETWORK masquerade comment "VPN NAT (Dual-WAN)"
    }
}
```

**Routing** (handled by NetworkManager/systemd-networkd):

```bash
# Primary WAN metric 50
# Backup WAN metric 200
# Automatic failover when primary fails
```

---

## Troubleshooting

### VPN Connects But No Internet

**Symptoms**:
- WireGuard handshake successful
- Ping to VPN server works (10.29.93.1)
- Ping to Internet fails (8.8.8.8)

**Diagnosis**:

```bash
# 1. Check VPN interface
ip addr show wg0
# Expected: 10.29.93.2/32

# 2. Check routing
ip route show
# Expected: 0.0.0.0/0 via 10.29.93.1 dev wg0

# 3. Test from VPN server
# SSH to VPN server, then:
ping -c 3 8.8.8.8
# Should work (server has internet)

# 4. Check nftables forward rules
sudo nft list chain inet filter forward | grep -i vpn
# Expected: iifname "wg0" oifname "eth0" accept

# 5. Check NAT
sudo nft list table ip nat | grep -i vpn
# Expected: oifname "eth0" ip saddr 10.29.93.0/24 masquerade
```

**Common Fixes**:

1. **Missing forward rule**:
   ```nft
   iifname $VPN_INTERFACE oifname $WAN_INTERFACE accept
   ```

2. **Missing NAT**:
   ```nft
   oifname $WAN_INTERFACE ip saddr $VPN_NETWORK masquerade
   ```

3. **Wrong WAN interface**:
   ```bash
   # Check default route
   ip route show | grep default
   # Update WAN_INTERFACE in config
   ```

---

### Can't Access LAN from VPN

**Symptoms**:
- VPN works, internet works
- Can't ping LAN devices (192.168.100.x)

**Diagnosis**:

```bash
# 1. Check VPN → LAN forward rule
sudo nft list chain inet filter forward | grep -i lan

# 2. Check VPN → LAN NAT
sudo nft list table ip nat | grep "VPN to LAN"

# 3. Test from VPN server
ping 192.168.100.2
# Should work (server is on LAN)
```

**Common Fixes**:

1. **Missing forward rule**:
   ```nft
   iifname $VPN_INTERFACE oifname $LAN_INTERFACE accept
   ```

2. **Missing NAT** (critical!):
   ```nft
   oifname $LAN_INTERFACE ip saddr $VPN_NETWORK masquerade comment "VPN to LAN NAT"
   ```

3. **Client AllowedIPs too restrictive**:
   ```ini
   # Client config
   [Peer]
   AllowedIPs = 0.0.0.0/0  # ← Route ALL traffic through VPN
   # NOT: AllowedIPs = 10.29.93.0/24  # ← Only VPN subnet
   ```

---

### DNS Leaks

**Symptoms**:
- DNS queries bypass VPN
- dnsleaktest.com shows ISP DNS servers

**Diagnosis**:

```bash
# Check DNS configuration
resolvectl status

# Test DNS via VPN
dig @10.29.93.1 google.com

# Check for leaks
curl https://dnsleaktest.com
```

**Fixes**:

1. **Client: Add DNS to WireGuard config**:
   ```ini
   DNS = 10.29.93.1
   ```

2. **Client: Full DNS takeover**:
   ```ini
   PostUp = resolvectl domain wg0 "~."
   PostUp = resolvectl dns wg0 10.29.93.1
   PostUp = resolvectl default-route wg0 true
   ```

3. **Server: Ensure DNS port open**:
   ```nft
   iifname $VPN_INTERFACE udp dport 53 accept
   iifname $VPN_INTERFACE tcp dport 53 accept
   ```

---

## See Also

- [SETUP.md](SETUP.md) - nftables installation
- [NFTABLES_RULES.md](NFTABLES_RULES.md) - Rule syntax
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting
- [examples/production-gateway.nft](../examples/production-gateway.nft) - Complete WireGuard + nftables example

**WireGuard Documentation**: https://www.wireguard.com/

---

**Questions?** Open an issue at https://github.com/fidpa/ubuntu-server-security
