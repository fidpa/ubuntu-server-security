<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# Minimal Web Server UFW Configuration

Minimal UFW configuration for a simple web server (Nginx/Apache).

## Use case

- Static website
- Simple reverse proxy
- Single-application server
- Low-attack-surface setup

## Architecture

```
                    ┌──────────────────────────┐
                    │     Ubuntu Server        │
                    │                          │
Internet ──────────►│  UFW (22, 80, 443)      │
                    │         │                │
                    │         ▼                │
                    │     Nginx/Apache         │
                    │         │                │
                    │         ▼                │
                    │    Application          │
                    └──────────────────────────┘
```

## Features

- ✅ SSH with rate limiting (brute-force protection)
- ✅ HTTP (redirect to HTTPS)
- ✅ HTTPS
- ✅ IPv6 disabled (optional)
- ✅ Default deny policy
- ✅ CIS Benchmark 3.5.1.x compliant

## Rules

**Total: 6 rules (3 services)**

| Port | Protocol | Action | Comment |
|------|----------|--------|---------|
| 22 | TCP | LIMIT | SSH Rate-Limited |
| 80 | TCP | ALLOW | HTTP |
| 443 | TCP | ALLOW | HTTPS |

## Deployment

### 1. UFW installation and base setup

```bash
# Installation
sudo apt update && sudo apt install ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

### 2. Add the rules

```bash
# SSH with rate limiting (IMPORTANT: before `ufw enable`!)
sudo ufw limit 22/tcp comment 'SSH Rate-Limited'

# HTTP/HTTPS
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```

### 3. Disable IPv6 (optional)

```bash
# Disable IPv6 (reduces the attack surface)
sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
```

### 4. Enable UFW

```bash
sudo ufw enable
```

### 5. Verification

```bash
# Check the status
sudo ufw status verbose

# Expected output:
# Status: active
# Logging: on (low)
# Default: deny (incoming), allow (outgoing), deny (routed)
#
# To                         Action      From
# --                         ------      ----
# 22/tcp                     LIMIT       Anywhere
# 80/tcp                     ALLOW       Anywhere
# 443/tcp                    ALLOW       Anywhere
```

## Variants

### A) Network-restricted SSH

For servers on a private network:

```bash
# SSH from the management network only
sudo ufw delete limit 22/tcp
sudo ufw allow from 10.0.0.0/24 to any port 22 proto tcp comment 'SSH Management'
```

### B) With HTTP/3 (QUIC)

For modern browser support:

```bash
# HTTP/3 over UDP
sudo ufw allow 443/udp comment 'HTTPS QUIC'
```

### C) Without HTTP (HTTPS only)

If no HTTP redirect is needed:

```bash
# HTTPS only
sudo ufw delete allow 80/tcp
```

## CIS Compliance

| Control | Status | Verification |
|---------|--------|--------------|
| 3.5.1.1 | ✅ | `dpkg -l ufw` |
| 3.5.1.3 | ✅ | `systemctl is-enabled ufw` |
| 3.5.1.7 | ✅ | `ufw status verbose \| grep "deny (incoming)"` |

## Logging

```bash
# Enable logging (recommended: low or medium)
sudo ufw logging low

# Inspect the log
sudo tail -f /var/log/ufw.log
```

## Troubleshooting

### SSH connection refused?

```bash
# From another terminal/console:
sudo ufw status numbered
# Does the SSH rule exist?

# If not:
sudo ufw allow 22/tcp
```

### Website unreachable?

```bash
# Are ports 80/443 blocked?
sudo grep "UFW BLOCK" /var/log/ufw.log | grep "DPT=80\|DPT=443"

# Is Nginx running?
systemctl status nginx
ss -tuln | grep -E ":80|:443"
```

## Next steps

- [SETUP.md](../docs/SETUP.md) - Detailed guide
- [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) - Problem solving
- [../drop-ins/](../drop-ins/) - Additional rules
