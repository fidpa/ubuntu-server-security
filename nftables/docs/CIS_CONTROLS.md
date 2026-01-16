<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# CIS Benchmark Compliance

nftables configuration alignment with CIS Ubuntu 22.04 LTS Benchmark v1.1.0.

## Overview

All templates in this repository are designed to meet or exceed:
- **CIS Benchmark Level 1** (essential security controls)
- **CIS Benchmark Level 2** (defense-in-depth controls)

**Benchmark**: CIS Ubuntu Linux 22.04 LTS Benchmark v1.1.0
**Section**: 3.5 Firewall Configuration
**Last Verified**: January 2026

---

## Table of Contents

- [Level 1 Controls](#level-1-controls)
- [Level 2 Controls](#level-2-controls)
- [Verification Commands](#verification-commands)
- [Template Compliance Matrix](#template-compliance-matrix)

---

## Level 1 Controls

### 3.5.1.1 - Ensure nftables is installed

**Requirement**: nftables package must be installed

**Implementation**:

```bash
sudo apt install nftables
```

**Verification**:

```bash
dpkg -s nftables | grep Status
# Expected: Status: install ok installed

nft --version
# Expected: nftables v0.9.3 or newer
```

**Compliance**: ✅ All templates require nftables installation

---

### 3.5.2.1 - Ensure a default deny firewall policy exists

**Requirement**: INPUT and FORWARD chains must have default deny policy

**Implementation**:

```nft
chain input {
    type filter hook input priority 0; policy drop;  # ← Default DENY
    # ... rules ...
}

chain forward {
    type filter hook forward priority 0; policy drop;  # ← Default DENY
    # ... rules ...
}
```

**Verification**:

```bash
sudo nft list ruleset | grep -E "policy (drop|reject)"
# Expected: policy drop (for input and forward)
```

**Compliance**: ✅ All templates use `policy drop` by default

---

### 3.5.2.2 - Ensure loopback traffic is configured

**Requirement**: Allow loopback traffic (localhost communication)

**Implementation**:

```nft
# Allow all traffic on loopback interface
iif lo accept
```

**Why**: Required for inter-process communication on localhost (127.0.0.1)

**Verification**:

```bash
sudo nft list chain inet filter input | grep "iif lo accept"
# Expected: iif lo accept
```

**Compliance**: ✅ All templates include loopback rule as first rule

---

### 3.5.2.3 - Ensure established connections are configured

**Requirement**: Allow established and related connections

**Implementation**:

```nft
# Allow established and related connections
ct state established,related accept
```

**Why**: Required for return traffic (e.g., responses to outgoing requests)

**Verification**:

```bash
sudo nft list chain inet filter input | grep "ct state"
# Expected: ct state established,related accept
```

**Compliance**: ✅ All templates include connection tracking as second rule

---

### 3.5.2.4 - Ensure firewall rules exist for all open ports

**Requirement**: Every open port must have an explicit allow rule

**Implementation**:

```nft
# Example: Allow SSH (port 22)
iifname $MGMT_INTERFACE tcp dport 22 accept comment "SSH"

# Example: Allow HTTP/HTTPS (ports 80, 443)
tcp dport { 80, 443 } accept comment "Web server"
```

**Verification**:

```bash
# List open ports
sudo ss -tulnp

# Check nftables rules for each open port
sudo nft list ruleset | grep "tcp dport"
```

**Compliance**: ✅ All templates include explicit rules for all services

---

### 3.5.3.1 - Ensure nftables service is enabled

**Requirement**: nftables service must start on boot

**Implementation**:

```bash
sudo systemctl enable nftables.service
```

**Verification**:

```bash
systemctl is-enabled nftables.service
# Expected: enabled
```

**Compliance**: ✅ Deployment script enables service automatically

---

### 3.5.3.2 - Ensure nftables rules are persistent

**Requirement**: Firewall rules must persist across reboots

**Implementation**:

```bash
# Rules are stored in /etc/nftables.conf
# Loaded by nftables.service on boot
sudo systemctl restart nftables.service
```

**Verification**:

```bash
# Check config file exists
ls -l /etc/nftables.conf

# Test persistence (after reboot)
sudo reboot
# ... system reboots ...
sudo nft list ruleset  # Rules should still be present
```

**Compliance**: ✅ All templates deploy to /etc/nftables.conf

---

## Level 2 Controls

### Rate Limiting (Enhanced Security)

**Requirement**: Protect against DoS/brute-force attacks

**Implementation**:

```nft
# SSH rate limiting (5 connections/minute)
tcp dport 22 ct state new limit rate over 5/minute counter log prefix "nft[ssh-ratelimit]: " reject

# HTTP rate limiting (100 requests/minute)
tcp dport { 80, 443 } ct state new limit rate over 100/minute counter drop
```

**Verification**:

```bash
sudo nft list ruleset | grep "limit rate"
```

**Compliance**: ⚠️ Optional - Available in 60-rate-limiting.nft.template

---

### ICMP Protection (Ping Flood Prevention)

**Requirement**: Allow ICMP but rate-limit to prevent ping floods

**Implementation**:

```nft
# Allow ICMP but rate-limit
ip protocol icmp limit rate over 10/second drop
ip protocol icmp accept
```

**Verification**:

```bash
# Test rate limiting
ping -f <server-ip>
# Should see packet loss after rate limit
```

**Compliance**: ⚠️ Optional - Basic ICMP included, rate-limiting optional

---

### Logging (Audit Trail)

**Requirement**: Log dropped packets for security auditing

**Implementation**:

```nft
# Rate-limited logging (prevents log spam)
limit rate 5/minute counter log prefix "nft[input-drop]: " drop
counter drop
```

**Verification**:

```bash
# View firewall logs
sudo journalctl -k | grep nft
sudo dmesg | grep nft
```

**Compliance**: ✅ All templates include rate-limited logging

---

## Verification Commands

### Complete Compliance Check

```bash
#!/bin/bash

echo "CIS 3.5.1.1 - nftables installed"
dpkg -s nftables | grep -q "install ok installed" && echo "✅ PASS" || echo "❌ FAIL"

echo "CIS 3.5.2.1 - Default deny policy"
sudo nft list ruleset | grep -q "policy drop" && echo "✅ PASS" || echo "❌ FAIL"

echo "CIS 3.5.2.2 - Loopback configured"
sudo nft list chain inet filter input | grep -q "iif lo accept" && echo "✅ PASS" || echo "❌ FAIL"

echo "CIS 3.5.2.3 - Established connections"
sudo nft list chain inet filter input | grep -q "ct state established,related accept" && echo "✅ PASS" || echo "❌ FAIL"

echo "CIS 3.5.3.1 - Service enabled"
systemctl is-enabled nftables.service | grep -q "enabled" && echo "✅ PASS" || echo "❌ FAIL"

echo "CIS 3.5.3.2 - Persistent config"
[ -f /etc/nftables.conf ] && echo "✅ PASS" || echo "❌ FAIL"
```

---

## Template Compliance Matrix

| Template | Level 1 | Level 2 | Notes |
|----------|---------|---------|-------|
| **10-gateway.nft** | ✅ Full | ⚠️ Partial | Add 60-rate-limiting.nft for full L2 |
| **20-server.nft** | ✅ Full | ⚠️ Partial | Add 60-rate-limiting.nft for full L2 |
| **30-minimal.nft** | ✅ Full | ❌ None | Minimal hardening only |
| **40-docker.nft** | ✅ Full | ⚠️ Partial | Docker-specific, add rate-limiting |
| **50-vpn-wireguard.nft** | ✅ Full | ⚠️ Partial | VPN-specific |
| **60-rate-limiting.nft** | N/A | ✅ Full | Level 2 add-on |

**Legend**:
- ✅ Full - Meets all requirements
- ⚠️ Partial - Meets some requirements
- ❌ None - Does not target this level

---

## CIS Benchmark Deviations

### Intentional Deviations

**1. OUTPUT Chain Policy**

- **CIS Recommendation**: policy drop (restrictive egress)
- **Our Implementation**: policy accept (allow outbound)
- **Rationale**: Servers need outbound connectivity (updates, API calls, DNS)
- **Risk**: Low (outbound restrictions rarely needed for servers)

**2. IPv6 Support**

- **CIS Recommendation**: Configure IPv6 if used
- **Our Implementation**: Basic IPv6 rules included
- **Rationale**: IPv6 adoption varies; templates support both IPv4/IPv6
- **Risk**: Low (disable IPv6 if not needed)

---

## Beyond CIS Benchmark

Our templates go beyond CIS requirements:

### Enhanced Security Features

1. **Management Network Isolation**
   - SSH restricted to management network (not just any IP)
   - Separates admin access from production traffic

2. **MSS Clamping**
   - Prevents MTU/fragmentation issues for NAT clients
   - Not required by CIS but critical for routers

3. **Docker Chain Preservation**
   - Prevents accidental destruction of Docker networking
   - Production-tested pattern

4. **WireGuard VPN Integration**
   - Secure remote access patterns
   - Full DNS takeover support

---

## Audit and Remediation

### Run CIS Compliance Check

```bash
# Download CIS-CAT tool (CIS Members)
https://www.cisecurity.org/cybersecurity-tools/cis-cat-pro/

# OR: Manual verification
sudo scripts/validate-nftables.sh /etc/nftables.conf
```

### Remediation Steps

**If failing 3.5.2.1 (default deny)**:

```nft
# Add to chain definition
chain input {
    type filter hook input priority 0; policy drop;  # ← Add "policy drop"
}
```

**If failing 3.5.2.2 (loopback)**:

```nft
# Add as FIRST rule
iif lo accept
```

**If failing 3.5.3.1 (service enabled)**:

```bash
sudo systemctl enable nftables.service
```

---

## See Also

- [SETUP.md](SETUP.md) - Installation and deployment
- [NFTABLES_RULES.md](NFTABLES_RULES.md) - Rule syntax
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues

**CIS Benchmark**: https://www.cisecurity.org/benchmark/ubuntu_linux

---

**Questions?** Open an issue at https://github.com/fidpa/ubuntu-server-security
