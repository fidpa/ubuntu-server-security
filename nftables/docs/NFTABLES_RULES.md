<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# nftables Rules Reference

Complete guide to nftables rule syntax and patterns.

## Table of Contents

- [Rule Anatomy](#rule-anatomy)
- [Essential Rules](#essential-rules)
- [Advanced Patterns](#advanced-patterns)
- [Common Mistakes](#common-mistakes)
- [Quick Reference](#quick-reference)

---

## Rule Anatomy

### Basic Structure

```nft
chain input {
    type filter hook input priority 0; policy drop;

    [match] [action] [comment]
}
```

### Example Breakdown

```nft
iifname "eth0" tcp dport 22 accept comment "SSH from LAN"
│       │      │   │     │  │      │
│       │      │   │     │  │      └─ Optional comment
│       │      │   │     │  └─ Action (accept/drop/reject)
│       │      │   │     └─ Match: port 22
│       │      │   └─ Match: TCP protocol
│       │      └─ Match: destination port
│       └─ Match: interface name
└─ Match: input interface
```

---

## Essential Rules

### Baseline Rules (ALWAYS FIRST)

```nft
# Allow loopback (required for localhost communication)
iif lo accept

# Allow established and related connections
ct state established,related accept

# Allow ICMP (ping, traceroute, etc.)
ip protocol icmp accept
ip6 nexthdr icmpv6 accept
```

**Why first?**: Performance - most traffic is established connections.

---

### SSH Patterns

**1. Restricted to Management Network (Recommended)**

```nft
iifname $MGMT_INTERFACE tcp dport 22 accept comment "SSH from Management"
```

**2. Restricted to Specific IPs**

```nft
ip saddr { 192.168.1.100, 10.0.0.0/24 } tcp dport 22 accept comment "SSH whitelist"
```

**3. Multiple Interfaces**

```nft
iifname { $LAN_INTERFACE, $MGMT_INTERFACE } tcp dport 22 accept comment "SSH from LAN + Management"
```

**❌ AVOID: Unrestricted SSH**

```nft
tcp dport 22 accept  # ⚠️ Allows SSH from 0.0.0.0/0 (entire Internet)
```

---

### NAT Rules (Gateway/Router)

**Masquerading (SNAT)**

```nft
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # LAN → Internet NAT
        oifname $WAN_INTERFACE ip saddr $LAN_NETWORK masquerade comment "LAN NAT"
    }
}
```

**Port Forwarding (DNAT)**

```nft
table ip nat {
    chain prerouting {
        type nat hook prerouting priority -100; policy accept;

        # Forward WAN port 80 to LAN server
        iifname $WAN_INTERFACE tcp dport 80 dnat to 192.168.100.10:80
    }
}
```

---

### Rate Limiting

**Pattern 1: Drop Over Limit**

```nft
# Allow up to 100/min, drop rest
tcp dport { 80, 443 } ct state new limit rate over 100/minute counter drop
tcp dport { 80, 443 } accept comment "HTTP/HTTPS rate-limited"
```

**Pattern 2: Log and Reject**

```nft
# Log and reject over limit
tcp dport 22 ct state new limit rate over 5/minute counter log prefix "nft[ssh-ratelimit]: " reject
tcp dport 22 accept comment "SSH rate-limited"
```

**Pattern 3: Whitelist + Rate Limit**

```nft
# Whitelist bypasses rate limit
ip saddr @whitelist tcp dport 8000 accept comment "Whitelist"
tcp dport 8000 ct state new limit rate over 50/minute counter reject
tcp dport 8000 accept comment "Rate-limited"
```

**⚠️ CRITICAL: Order Matters!**

```nft
# ✅ CORRECT - Limit BEFORE accept
limit rate over 100/minute drop
tcp dport 80 accept

# ❌ WRONG - Accept BEFORE limit (limit never triggers!)
tcp dport 80 accept
limit rate over 100/minute drop
```

---

### Docker Networking

**Forward Chain (Container Traffic)**

```nft
chain forward {
    type filter hook forward priority 0; policy drop;

    # Baseline
    ct state established,related accept

    # Docker containers → Internet
    ip saddr $DOCKER_NETWORKS oifname $WAN_INTERFACE accept comment "Docker to Internet"

    # LAN → Docker containers
    iifname $LAN_INTERFACE ip daddr $DOCKER_NETWORKS accept comment "LAN to Docker"

    # Docker inter-container
    ip saddr $DOCKER_NETWORKS ip daddr $DOCKER_NETWORKS accept comment "Docker inter-container"
}
```

**NAT for Docker**

```nft
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # Docker containers → Internet NAT
        oifname $WAN_INTERFACE ip saddr $DOCKER_NETWORKS masquerade comment "Docker NAT"
    }
}
```

**⚠️ CRITICAL: Docker Chain Preservation**

```nft
# ✅ CORRECT - Flush specific tables
flush table inet filter
flush table ip nat

# ❌ WRONG - Destroys Docker's DOCKER chain!
flush ruleset
```

---

## Advanced Patterns

### Sets (IP Lists)

**Define Set**

```nft
define whitelist = { 192.168.1.100, 192.168.1.200, 10.0.0.0/24 }
```

**Use Set**

```nft
# Accept from whitelist
ip saddr @whitelist tcp dport 22 accept comment "SSH whitelist"

# Reject everyone else
tcp dport 22 reject
```

**Named Sets (Dynamic)**

```nft
table inet filter {
    set admin_ips {
        type ipv4_addr
        elements = { 192.168.1.100, 192.168.1.200 }
    }

    chain input {
        ip saddr @admin_ips tcp dport 22 accept
    }
}
```

---

### MSS Clamping (NAT MTU Fix)

**Problem**: NAT clients may experience MTU/fragmentation issues

**Solution**: MSS Clamping

```nft
chain forward {
    type filter hook forward priority 0; policy drop;

    # ⚠️ CRITICAL: Must be FIRST rule in forward chain!
    tcp flags syn tcp option maxseg size set rt mtu

    # ... rest of forward rules
}
```

**What it does**: Adjusts TCP Maximum Segment Size to Path MTU

---

### Logging

**Pattern 1: Rate-Limited Logging**

```nft
# Log at most 5/min (prevents log spam)
limit rate 5/minute counter log prefix "nft[input-drop]: " drop
counter drop  # Drop without logging (after rate limit)
```

**Pattern 2: Selective Logging**

```nft
# Log only SSH attempts
tcp dport 22 limit rate 5/minute log prefix "nft[ssh]: "
tcp dport 22 accept
```

**View Logs**

```bash
# System logs
sudo journalctl -k | grep nft

# Kernel logs
sudo dmesg | grep nft
```

---

### Negation (⚠️ LIMITATION!)

**❌ BROKEN: Negation with Interval Sets**

```nft
# ❌ WRONG - Doesn't work with interval sets!
tcp dport 8000 ip saddr != @whitelist reject
```

**✅ CORRECT: Positive Matching**

```nft
# ✅ Accept whitelist first
tcp dport 8000 ip saddr @whitelist accept comment "Whitelist"

# ✅ Reject everyone else
tcp dport 8000 counter reject comment "Not in whitelist"
```

**Why?**: nftables limitation - negation (`!=`) doesn't work with interval sets.

**Source**: Pi 5 Router Incident (NFTABLES_INTERVAL_SET_NEGATION_BUG_221225.md)

---

## Common Mistakes

### 1. Wrong Rule Order

**❌ WRONG**

```nft
# Drop rule BEFORE accept rule → accept never triggers!
counter drop
tcp dport 22 accept
```

**✅ CORRECT**

```nft
# Accept rules BEFORE drop rules
tcp dport 22 accept
counter drop
```

---

### 2. Missing NAT for LAN Clients

**❌ WRONG**

```nft
# Forward chain allows traffic, but no NAT → Internet won't work!
chain forward {
    iifname $LAN_INTERFACE oifname $WAN_INTERFACE accept
}
```

**✅ CORRECT**

```nft
# Forward chain + NAT masquerade
chain forward {
    iifname $LAN_INTERFACE oifname $WAN_INTERFACE accept
}

table ip nat {
    chain postrouting {
        oifname $WAN_INTERFACE ip saddr $LAN_NETWORK masquerade
    }
}
```

---

### 3. Unrestricted SSH

**❌ WRONG**

```nft
# Allows SSH from entire Internet
tcp dport 22 accept
```

**✅ CORRECT**

```nft
# Restrict to management network
iifname $MGMT_INTERFACE tcp dport 22 accept
```

---

### 4. Flushing Docker Chains

**❌ WRONG**

```nft
#!/usr/sbin/nft -f
flush ruleset  # ⚠️ Destroys Docker's DOCKER chain!
```

**✅ CORRECT**

```nft
#!/usr/sbin/nft -f
flush table inet filter  # Only flush specific tables
flush table ip nat
```

---

### 5. Missing MSS Clamping (Gateway)

**❌ WRONG**

```nft
# Forward chain without MSS clamping → NAT clients may have MTU issues
chain forward {
    ct state established,related accept
    iifname $LAN_INTERFACE oifname $WAN_INTERFACE accept
}
```

**✅ CORRECT**

```nft
# MSS clamping FIRST in forward chain
chain forward {
    tcp flags syn tcp option maxseg size set rt mtu  # ⚠️ FIRST!
    ct state established,related accept
    iifname $LAN_INTERFACE oifname $WAN_INTERFACE accept
}
```

---

## Quick Reference

### Match Expressions

| Match | Syntax | Example |
|-------|--------|---------|
| Input interface | `iifname "eth0"` | `iifname $WAN_INTERFACE` |
| Output interface | `oifname "eth0"` | `oifname $LAN_INTERFACE` |
| Source IP | `ip saddr 192.168.1.0/24` | `ip saddr $LAN_NETWORK` |
| Dest IP | `ip daddr 192.168.1.10` | `ip daddr $SERVER_IP` |
| TCP port | `tcp dport 22` | `tcp dport { 80, 443 }` |
| UDP port | `udp dport 53` | `udp dport { 67, 68 }` |
| Connection state | `ct state established,related` | `ct state new` |
| Protocol | `ip protocol icmp` | `ip6 nexthdr icmpv6` |

### Actions

| Action | Description | Use Case |
|--------|-------------|----------|
| `accept` | Allow packet | Normal allow rule |
| `drop` | Silently discard packet | Stealth mode |
| `reject` | Discard with ICMP error | Better for debugging |
| `counter` | Count packets | Statistics |
| `log` | Log packet | Debugging |
| `masquerade` | Source NAT (dynamic) | Router/gateway |
| `dnat` | Destination NAT | Port forwarding |

### Chain Types

| Type | Hook | Use Case |
|------|------|----------|
| `filter` | `input` | Traffic to host |
| `filter` | `forward` | Traffic through host (routing) |
| `filter` | `output` | Traffic from host |
| `nat` | `prerouting` | DNAT (port forwarding) |
| `nat` | `postrouting` | SNAT (masquerading) |

---

## See Also

- [SETUP.md](SETUP.md) - Installation and deployment
- [WIREGUARD_INTEGRATION.md](WIREGUARD_INTEGRATION.md) - VPN integration
- [DOCKER_NETWORKING.md](DOCKER_NETWORKING.md) - Container networking
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues

---

**Need Help?** Open an issue at https://github.com/fidpa/ubuntu-server-security
