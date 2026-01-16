<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# Docker Networking with nftables

Complete guide to integrating Docker with nftables firewall.

## Table of Contents

- [Docker Chain Architecture](#docker-chain-architecture)
- [Basic Integration](#basic-integration)
- [Common Pitfalls](#common-pitfalls)
- [Advanced Scenarios](#advanced-scenarios)
- [Debugging](#debugging)

---

## Docker Chain Architecture

### How Docker Uses nftables

Docker creates its own chains at runtime:
- **DOCKER chain**: Manages container port bindings
- **DOCKER-USER chain**: User-defined rules (inserted before DOCKER chain)

**Critical**: These chains are created dynamically by Docker daemon, NOT in your nftables config!

### Chain Hierarchy

```
inet filter forward (your rules)
    ↓
docker DOCKER-USER (user rules)
    ↓
docker DOCKER (Docker rules)
    ↓
your remaining forward rules
```

**⚠️ IMPORTANT**: Your nftables rules run BEFORE Docker's chains!

---

## Basic Integration

### 1. Identify Docker Networks

```bash
# List Docker networks
docker network ls

# Get network details
docker network inspect bridge | grep Subnet
# Output: "Subnet": "172.17.0.0/16"

docker network inspect <custom-network> | grep Subnet
# Output: "Subnet": "172.25.0.0/24"
```

**Common Docker Networks**:
- `172.17.0.0/16` - Default bridge
- `172.18.0.0/16` - Custom bridge 1
- `172.25.0.0/24` - Custom bridge 2

### 2. Configure nftables

**Add to /etc/nftables.conf**:

```nft
#!/usr/sbin/nft -f

# Docker Networks (customize with your subnets)
define DOCKER_NETWORKS = { 172.17.0.0/16, 172.18.0.0/16, 172.25.0.0/24 }

# WAN Interface
define WAN_INTERFACE = "eth0"

# LAN Interface
define LAN_INTERFACE = "eth3"

# ═══════════════════════════════════════════════════════════════════════════
# Flush Configuration
# ═══════════════════════════════════════════════════════════════════════════
# ⚠️ CRITICAL: Do NOT use "flush ruleset" with Docker!

flush table inet filter
flush table ip nat

# ═══════════════════════════════════════════════════════════════════════════
# Firewall Table
# ═══════════════════════════════════════════════════════════════════════════

table inet filter {
    chain forward {
        type filter hook forward priority 0; policy drop;

        # Baseline
        ct state established,related accept

        # Docker containers → Internet
        ip saddr $DOCKER_NETWORKS oifname $WAN_INTERFACE accept comment "Docker to Internet"

        # LAN → Docker containers
        iifname $LAN_INTERFACE ip daddr $DOCKER_NETWORKS accept comment "LAN to Docker"

        # Docker inter-container communication
        ip saddr $DOCKER_NETWORKS ip daddr $DOCKER_NETWORKS accept comment "Docker inter-container"
    }
}

# ═══════════════════════════════════════════════════════════════════════════
# NAT Table
# ═══════════════════════════════════════════════════════════════════════════

table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # Docker containers → Internet NAT
        oifname $WAN_INTERFACE ip saddr $DOCKER_NETWORKS masquerade comment "Docker NAT"
    }
}
```

### 3. Deploy

```bash
# Validate
sudo scripts/validate-nftables.sh /etc/nftables.conf

# Deploy
sudo scripts/deploy-nftables.sh /etc/nftables.conf

# Restart Docker to recreate chains
sudo systemctl restart docker
```

### 4. Verify

```bash
# Check Docker chains exist
sudo nft list ruleset | grep DOCKER
# Expected: chain DOCKER, chain DOCKER-USER

# Test container internet access
docker run --rm alpine ping -c 3 8.8.8.8
# Expected: 3 packets transmitted, 3 received

# Test LAN → Container
curl http://<container-ip>
```

---

## Common Pitfalls

### Pitfall 1: Using `flush ruleset`

**❌ PROBLEM**:

```nft
#!/usr/sbin/nft -f
flush ruleset  # ⚠️ DESTROYS Docker's DOCKER chain!
```

**Symptom**: Containers lose internet access after nftables reload

**✅ SOLUTION**:

```nft
#!/usr/sbin/nft -f
# Flush specific tables only
flush table inet filter
flush table ip nat
```

**Recovery**:

```bash
# Restart Docker to recreate chains
sudo systemctl restart docker

# Reload nftables
sudo nft -f /etc/nftables.conf
```

---

### Pitfall 2: Missing Inter-Container Rule

**❌ PROBLEM**:

```nft
# Missing inter-container rule
chain forward {
    ip saddr $DOCKER_NETWORKS oifname $WAN_INTERFACE accept  # Internet OK
    # ⚠️ But containers can't talk to each other!
}
```

**Symptom**: Docker Compose services can't communicate

**✅ SOLUTION**:

```nft
chain forward {
    # Allow Docker inter-container communication
    ip saddr $DOCKER_NETWORKS ip daddr $DOCKER_NETWORKS accept comment "Docker inter-container"

    # Internet access
    ip saddr $DOCKER_NETWORKS oifname $WAN_INTERFACE accept comment "Docker to Internet"
}
```

**Test**:

```bash
# Create two containers
docker run -d --name web nginx
docker run --rm alpine ping -c 3 web
# Should work
```

---

### Pitfall 3: Missing Docker NAT

**❌ PROBLEM**:

```nft
# Forward chain allows traffic, but no NAT
chain forward {
    ip saddr $DOCKER_NETWORKS oifname $WAN_INTERFACE accept
}
# ⚠️ No NAT table = no internet for containers!
```

**Symptom**: Containers can't reach external IPs

**✅ SOLUTION**:

```nft
table ip nat {
    chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # Add Docker NAT
        oifname $WAN_INTERFACE ip saddr $DOCKER_NETWORKS masquerade comment "Docker NAT"
    }
}
```

**Verify**:

```bash
# Check NAT rules
sudo nft list table ip nat | grep Docker

# Test
docker run --rm alpine ping -c 3 8.8.8.8
```

---

## Advanced Scenarios

### Restrict Docker Internet Access

**Use Case**: Allow LAN access but block Internet for security

```nft
chain forward {
    # Baseline
    ct state established,related accept

    # LAN → Docker (ALLOW)
    iifname $LAN_INTERFACE ip daddr $DOCKER_NETWORKS accept comment "LAN to Docker"

    # Docker inter-container (ALLOW)
    ip saddr $DOCKER_NETWORKS ip daddr $DOCKER_NETWORKS accept comment "Docker inter-container"

    # Docker → Internet (BLOCK)
    ip saddr $DOCKER_NETWORKS oifname $WAN_INTERFACE drop comment "Block Docker Internet"
}
```

**Whitelist Specific Containers**:

```nft
# Allow specific container to internet
ip saddr 172.17.0.5 oifname $WAN_INTERFACE accept comment "Container 172.17.0.5 to Internet"

# Block all other containers
ip saddr $DOCKER_NETWORKS oifname $WAN_INTERFACE drop
```

---

### Dual-WAN with Docker

**Use Case**: Route Docker traffic through primary or backup WAN

```nft
define WAN_PRIMARY = "eth0"
define WAN_BACKUP = "lte0"

chain forward {
    # Docker → Internet (Dual-WAN)
    ip saddr $DOCKER_NETWORKS oifname { $WAN_PRIMARY, $WAN_BACKUP } accept comment "Docker to Internet (Dual-WAN)"
}

table ip nat {
    chain postrouting {
        # Docker NAT via both WANs
        oifname { $WAN_PRIMARY, $WAN_BACKUP } ip saddr $DOCKER_NETWORKS masquerade comment "Docker NAT (Dual-WAN)"
    }
}
```

**Routing**: Handled by NetworkManager/systemd-networkd metrics

---

### Expose Container Port to WAN

**Use Case**: Allow external access to container service (e.g., web server)

**Docker Side**:

```bash
# Publish port 80 → 8080
docker run -d -p 8080:80 nginx
```

**nftables Side**:

```nft
# Allow WAN → Container port
chain input {
    # Allow port 8080 from WAN
    iifname $WAN_INTERFACE tcp dport 8080 accept comment "Container web server"
}
```

**OR: Port Forwarding**:

```nft
table ip nat {
    chain prerouting {
        type nat hook prerouting priority -100; policy accept;

        # Forward WAN port 80 to container
        iifname $WAN_INTERFACE tcp dport 80 dnat to 172.17.0.5:80
    }
}

chain forward {
    # Allow forwarded traffic
    iifname $WAN_INTERFACE ip daddr 172.17.0.5 tcp dport 80 accept
}
```

---

### Rate-Limit Container Traffic

**Use Case**: Prevent container DoS attacks

```nft
chain forward {
    # Rate-limit container → Internet
    ip saddr $DOCKER_NETWORKS oifname $WAN_INTERFACE ct state new limit rate over 1000/second drop
    ip saddr $DOCKER_NETWORKS oifname $WAN_INTERFACE accept comment "Docker to Internet (rate-limited)"
}
```

---

## Debugging

### Check Docker Chains

```bash
# List all chains
sudo nft list ruleset | grep -A 10 "chain DOCKER"

# Check DOCKER chain
sudo nft list chain docker DOCKER

# Check DOCKER-USER chain
sudo nft list chain docker DOCKER-USER
```

**Expected**:
```
chain DOCKER {
    type filter hook forward priority -1; policy accept;
    # ... Docker rules ...
}

chain DOCKER-USER {
    type filter hook forward priority -1; policy accept;
    return
}
```

---

### Trace Container Traffic

```bash
# Enable tracing
sudo nft add rule inet filter forward ip saddr 172.17.0.0/16 log prefix "DOCKER-TRACE: "

# View traces
sudo journalctl -k -f | grep DOCKER-TRACE

# Test
docker run --rm alpine ping -c 3 8.8.8.8

# Remove trace rule
sudo nft list ruleset -a  # Find handle
sudo nft delete rule inet filter forward handle <number>
```

---

### Check Container Routes

```bash
# Enter container
docker exec -it <container> sh

# Check routes
ip route show
# Expected: default via 172.17.0.1 dev eth0

# Check DNS
cat /etc/resolv.conf
# Expected: nameserver 172.17.0.1 (or custom)

# Test connectivity
ping 8.8.8.8
```

---

### Check Docker NAT

```bash
# List NAT table
sudo nft list table ip nat

# List Docker NAT entries
sudo conntrack -L -p tcp --dport 80 | grep 172.17

# Check masquerade counters
sudo nft list chain ip nat postrouting -a | grep masquerade
```

---

### Common Error Messages

**Error**: `docker: Error response from daemon: driver failed programming external connectivity`

**Cause**: nftables forward chain blocking Docker

**Fix**:
```nft
# Add forward rules BEFORE policy drop
ip saddr $DOCKER_NETWORKS accept
```

---

**Error**: `failed to create endpoint ... Firewall reload in progress`

**Cause**: nftables reload while Docker is running

**Fix**:
```bash
# Restart Docker after nftables reload
sudo systemctl restart docker
```

---

## See Also

- [SETUP.md](SETUP.md) - nftables installation
- [NFTABLES_RULES.md](NFTABLES_RULES.md) - Rule syntax
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting
- [examples/nas-docker-stack.nft](../examples/nas-docker-stack.nft) - Complete Docker + nftables example

**Docker Networking**: https://docs.docker.com/network/

---

**Questions?** Open an issue at https://github.com/fidpa/ubuntu-server-security
