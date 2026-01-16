<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# nftables Troubleshooting Guide

Common issues and solutions for nftables firewall on Ubuntu servers.

## Table of Contents

- [Emergency Recovery](#emergency-recovery)
- [Internet Not Working](#internet-not-working-gateway)
- [SSH Access Issues](#ssh-access-issues)
- [Docker Connectivity](#docker-connectivity-problems)
- [Rate Limiting Issues](#rate-limiting-not-working)
- [Negation Bug](#negation-bug-interval-sets)
- [Diagnostic Commands](#diagnostic-commands)

---

## Emergency Recovery

### Lost SSH Access (No Console)

**⚠️ CRITICAL**: Prevention is key - always have console/physical access OR use deployment script with auto-rollback!

**Recovery via Another SSH Session** (if you have one open):

```bash
# Flush all rules (WARNING: Removes ALL firewall protection!)
sudo nft flush ruleset

# Restore from backup
sudo nft -f /etc/nftables.conf.backup

# OR: Add temporary SSH rule
sudo nft add rule inet filter input tcp dport 22 accept
```

**Recovery via Physical/Console Access**:

```bash
# 1. Login via console
# 2. Flush rules
sudo nft flush ruleset

# 3. Check backups
ls -lh /etc/nftables/backups/

# 4. Restore latest backup
sudo nft -f /etc/nftables/backups/nftables.conf.backup.<timestamp>

# 5. Restart service
sudo systemctl restart nftables.service
```

---

## Internet Not Working (Gateway)

### Symptom

LAN clients cannot access Internet (ping 8.8.8.8 fails)

### Diagnosis

```bash
# 1. Check NAT configuration
sudo nft list table ip nat | grep masquerade
# Expected: oifname $WAN_INTERFACE ip saddr $LAN_NETWORK masquerade

# 2. Check routing
ip route show
# Expected: default via <gateway-ip> dev <wan-interface>

# 3. Check forward chain
sudo nft list chain inet filter forward
# Expected: iifname $LAN_INTERFACE oifname $WAN_INTERFACE accept

# 4. Test from router itself
ping -c 3 8.8.8.8
# Should work (router has internet)
```

### Common Causes

#### Cause 1: Missing NAT Masquerade Rule

**Problem**: Forward chain allows traffic, but no NAT configured

**Symptom**: LAN clients can't ping Internet IPs

**Fix**:

```nft
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # Add masquerade rule
        oifname $WAN_INTERFACE ip saddr $LAN_NETWORK masquerade comment "LAN NAT"
    }
}
```

**Reload**:

```bash
sudo nft -f /etc/nftables.conf
```

---

#### Cause 2: Wrong WAN Interface

**Problem**: NAT rule uses wrong interface name

**Symptom**: NAT rule exists but doesn't match traffic

**Fix**:

```bash
# 1. Identify correct WAN interface
ip route show | grep default
# Output: default via 192.168.1.1 dev eth0

# 2. Update config
sudo nano /etc/nftables.conf
define WAN_INTERFACE = "eth0"  # ← Correct interface

# 3. Reload
sudo nft -f /etc/nftables.conf
```

---

#### Cause 3: Forward Chain Blocking

**Problem**: Forward chain has `policy drop` but no allow rules

**Symptom**: Packets dropped in forward chain

**Fix**:

```nft
chain forward {
    type filter hook forward priority 0; policy drop;

    # Add these rules
    ct state established,related accept
    iifname $LAN_INTERFACE oifname $WAN_INTERFACE accept comment "LAN to Internet"
}
```

---

## SSH Access Issues

### Symptom

Cannot SSH to server (connection refused or timeout)

### Diagnosis

```bash
# 1. Check SSH service
sudo systemctl status sshd
# Expected: active (running)

# 2. Check SSH port listening
sudo ss -tlnp | grep :22
# Expected: LISTEN 0 128 0.0.0.0:22

# 3. Check nftables rules
sudo nft list chain inet filter input | grep "tcp dport 22"
# Expected: tcp dport 22 accept (with interface/IP restrictions)

# 4. Test from server itself
ssh localhost
# Should work (loopback always allowed)
```

### Common Causes

#### Cause 1: Rule Order Error

**Problem**: Drop rule before accept rule

**Symptom**: SSH rule exists but never matches

**Fix**:

```nft
# ❌ WRONG ORDER
counter drop
tcp dport 22 accept  # ← Never reached!

# ✅ CORRECT ORDER
tcp dport 22 accept  # ← Processed first
counter drop
```

**Reload**:

```bash
sudo nft -f /etc/nftables.conf
```

---

#### Cause 2: Wrong Interface/IP Restriction

**Problem**: SSH rule restricts to wrong interface or IP range

**Symptom**: SSH works from some networks, not others

**Fix**:

```bash
# 1. Check current SSH rule
sudo nft list chain inet filter input | grep "tcp dport 22"

# 2. Identify your source IP
curl ifconfig.me

# 3. Update SSH rule
sudo nano /etc/nftables.conf

# Examples:
# Allow from specific IP
ip saddr 203.0.113.100 tcp dport 22 accept

# Allow from specific network
ip saddr 192.168.1.0/24 tcp dport 22 accept

# Allow from specific interface
iifname $MGMT_INTERFACE tcp dport 22 accept

# 4. Reload
sudo nft -f /etc/nftables.conf
```

---

#### Cause 3: Default Policy Drops SSH

**Problem**: No SSH rule exists at all

**Symptom**: Immediate connection refused

**Fix**:

```bash
# Emergency fix (via console)
sudo nft add rule inet filter input tcp dport 22 accept

# Permanent fix
sudo nano /etc/nftables.conf
# Add: tcp dport 22 accept

sudo nft -f /etc/nftables.conf
```

---

## Docker Connectivity Problems

### Symptom

Docker containers cannot access Internet (docker exec <container> ping 8.8.8.8 fails)

### Diagnosis

```bash
# 1. Check Docker is running
sudo systemctl status docker
# Expected: active (running)

# 2. Check Docker chains exist
sudo nft list ruleset | grep DOCKER
# Expected: chain DOCKER, chain DOCKER-USER

# 3. Check forward rules
sudo nft list chain inet filter forward | grep -i docker

# 4. Check NAT
sudo nft list table ip nat | grep -i docker

# 5. Test from host
ping -c 3 8.8.8.8
# Should work (host has internet)
```

### Common Causes

#### Cause 1: Used `flush ruleset` (Destroyed Docker Chains)

**Problem**: Config uses `flush ruleset` which destroys Docker's DOCKER chain

**Symptom**: `nft list ruleset | grep DOCKER` returns nothing

**Fix**:

```bash
# 1. Update config to flush specific tables
sudo nano /etc/nftables.conf

# ❌ WRONG
flush ruleset

# ✅ CORRECT
flush table inet filter
flush table ip nat

# 2. Restart Docker to recreate chains
sudo systemctl restart docker

# 3. Reload nftables
sudo nft -f /etc/nftables.conf

# 4. Verify Docker chains
sudo nft list ruleset | grep DOCKER
```

---

#### Cause 2: Missing Docker Forward Rules

**Problem**: Forward chain blocks Docker traffic

**Symptom**: Docker chains exist but containers still can't access Internet

**Fix**:

```nft
chain forward {
    type filter hook forward priority 0; policy drop;

    # Add these rules
    ct state established,related accept

    # Docker containers → Internet
    ip saddr $DOCKER_NETWORKS oifname $WAN_INTERFACE accept comment "Docker to Internet"

    # LAN → Docker containers
    iifname $LAN_INTERFACE ip daddr $DOCKER_NETWORKS accept comment "LAN to Docker"

    # Docker inter-container
    ip saddr $DOCKER_NETWORKS ip daddr $DOCKER_NETWORKS accept comment "Docker inter-container"
}
```

**Identify Docker Networks**:

```bash
docker network inspect bridge | grep Subnet
# Output: "Subnet": "172.17.0.0/16"

# Add to config
define DOCKER_NETWORKS = { 172.17.0.0/16 }
```

---

#### Cause 3: Missing Docker NAT

**Problem**: Forward rules allow traffic but no NAT configured

**Symptom**: Docker containers can't access external IPs

**Fix**:

```nft
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # Add Docker NAT
        oifname $WAN_INTERFACE ip saddr $DOCKER_NETWORKS masquerade comment "Docker NAT"
    }
}
```

---

## Rate Limiting Not Working

### Symptom

Rate limiting rules present but not triggering (no drops/rejects)

### Diagnosis

```bash
# 1. Check rate limit rules
sudo nft list ruleset | grep "limit rate"

# 2. Check counters
sudo nft list chain inet filter input -a
# Look for counter values next to rate limit rules

# 3. Test rate limiting
for i in {1..200}; do curl -s http://server-ip >/dev/null & done
# Should see connection refused after ~100 requests
```

### Common Cause: Rule Order Error

**Problem**: Accept rule BEFORE rate limit rule

**Symptom**: All connections accepted, limit never checked

**Fix**:

```nft
# ❌ WRONG ORDER
tcp dport 80 accept  # ← Accepts everything, limit never checked
tcp dport 80 limit rate over 100/minute drop

# ✅ CORRECT ORDER
tcp dport 80 limit rate over 100/minute drop  # ← Checked FIRST
tcp dport 80 accept  # ← Only if under limit
```

**Reload**:

```bash
sudo nft -f /etc/nftables.conf
```

---

## Negation Bug (Interval Sets)

### Symptom

Negation (`!=`) with sets doesn't work as expected

### Problem

nftables limitation: negation (`!=`) doesn't work with interval sets

**Example from Pi 5 Router Incident (NFTABLES_INTERVAL_SET_NEGATION_BUG_221225.md)**:

```nft
# ❌ BROKEN - Doesn't work!
tcp dport 8000 ip saddr != @whitelist reject
```

### Solution: Use Positive Matching

```nft
# ✅ CORRECT - Positive matching
define whitelist = { 192.168.1.100, 192.168.1.200, 10.0.0.0/24 }

# Accept whitelist first
tcp dport 8000 ip saddr @whitelist accept comment "Whitelist"

# Reject everyone else
tcp dport 8000 counter reject comment "Not in whitelist"
```

**Why it works**: Accept whitelist first, then reject all remaining traffic

---

## Diagnostic Commands

### View Current Rules

```bash
# All rules
sudo nft list ruleset

# Specific table
sudo nft list table inet filter
sudo nft list table ip nat

# Specific chain
sudo nft list chain inet filter input
sudo nft list chain inet filter forward

# With counters and handles
sudo nft list ruleset -a
```

### Check Counters

```bash
# View packet counters
sudo nft list chain inet filter input -a | grep counter

# Reset counters (for testing)
sudo nft reset counters table inet filter
```

### Live Packet Tracing

```bash
# Trace packets matching a rule
sudo nft add rule inet filter input tcp dport 22 log prefix "SSH: "

# View traces
sudo journalctl -k -f | grep SSH

# Remove trace rule
sudo nft list ruleset -a  # Find handle number
sudo nft delete rule inet filter input handle <number>
```

### Check Interfaces

```bash
# List all interfaces
ip link show

# Show routes
ip route show

# Show interface statistics
ip -s link show

# Test interface connectivity
ping -I eth0 8.8.8.8
```

### Check Connections

```bash
# Active connections
sudo ss -tunap

# Connection tracking
sudo conntrack -L

# NAT connections
sudo conntrack -L -p tcp --dport 80
```

---

## See Also

- [SETUP.md](SETUP.md) - Installation and deployment
- [NFTABLES_RULES.md](NFTABLES_RULES.md) - Rule syntax reference
- [DOCKER_NETWORKING.md](DOCKER_NETWORKING.md) - Docker-specific troubleshooting
- [WIREGUARD_INTEGRATION.md](WIREGUARD_INTEGRATION.md) - VPN troubleshooting

---

**Still Stuck?** Open an issue at https://github.com/fidpa/ubuntu-server-security
