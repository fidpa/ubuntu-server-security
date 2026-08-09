<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# UFW Setup Guide

## TL;DR (30 seconds)

```bash
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp
sudo ufw enable
sudo ufw status verbose
```

## Requirements

- Ubuntu 22.04 LTS or 24.04 LTS
- Root/sudo access
- SSH access (create the SSH rule BEFORE enabling UFW!)

**Important**: `iptables-persistent` must NOT be installed (it conflicts with UFW):

```bash
dpkg -l | grep iptables-persistent
# If installed:
sudo apt purge iptables-persistent
```

## Installation

### 1. Install UFW

```bash
sudo apt update
sudo apt install ufw
```

### 2. Set default policies

```bash
# Incoming connections: DENY (block everything)
sudo ufw default deny incoming

# Outgoing connections: ALLOW (permit everything)
sudo ufw default allow outgoing

# Routed traffic (only relevant for routers/gateways)
sudo ufw default deny routed
```

### 3. SSH rule (CRITICAL!)

**Always secure SSH access before enabling UFW.**

```bash
# Option A: Rate-limited (recommended)
sudo ufw limit 22/tcp comment 'SSH Rate-Limited'

# Option B: Plain allow
sudo ufw allow 22/tcp comment 'SSH'

# Option C: Network-restricted (most secure)
sudo ufw allow from 10.0.0.0/24 to any port 22 proto tcp comment 'SSH Management'
```

### 4. Enable UFW

```bash
sudo ufw enable
# Confirm with 'y'
```

### 5. Check status

```bash
# Overview
sudo ufw status verbose

# With rule numbers (for editing)
sudo ufw status numbered
```

## Base configuration

### Web server (HTTP/HTTPS)

```bash
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```

### Samba (file sharing)

```bash
sudo ufw allow from 10.0.0.0/24 to any port 139,445 proto tcp comment 'Samba Management'
sudo ufw allow from 192.168.100.0/24 to any port 139,445 proto tcp comment 'Samba LAN'
```

### Monitoring ports

```bash
# Management network only
sudo ufw allow from 10.0.0.0/24 to any port 9090 proto tcp comment 'Prometheus'
sudo ufw allow from 10.0.0.0/24 to any port 3000 proto tcp comment 'Grafana'
```

## Drop-in integration

Drop-ins are pre-built rule sets for specific use cases.

```bash
# 1. Pick a drop-in
cat drop-ins/10-webserver.rules

# 2. Apply the rules
source drop-ins/10-webserver.rules
# Or run them individually:
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```

Available drop-ins: [drop-ins/README.md](../drop-ins/README.md)

## Disabling IPv6 (optional)

If IPv6 is not needed (CIS 3.1.1):

```bash
# Edit /etc/default/ufw
sudo nano /etc/default/ufw

# Change to:
IPV6=no

# Reload UFW
sudo ufw reload
```

**Benefit**: Fewer rules, smaller attack surface.

## Configuring logging

```bash
# Set logging level (recommended: medium)
sudo ufw logging medium

# Inspect the log file
sudo tail -f /var/log/ufw.log
```

| Level | Description |
|-------|-------------|
| off | No logging |
| low | Blocked packets |
| medium | + Invalid + new connections |
| high | + Rate-limited packets |
| full | Everything |

## Verification

### CIS Benchmark checks

```bash
# 3.5.1.1 - UFW installed
dpkg -l | grep ufw

# 3.5.1.3 - Service active
systemctl is-enabled ufw
systemctl is-active ufw

# 3.5.1.7 - Default deny
sudo ufw status verbose | grep -E "^Default:"
```

### Rule validation

```bash
# Show all rules
sudo ufw status numbered

# Test a rule (from another host)
nc -zv SERVER_IP 22
nc -zv SERVER_IP 80
```

## Managing rules

### Add a rule

```bash
# By port
sudo ufw allow 8080/tcp comment 'Custom Service'

# By service name
sudo ufw allow ssh
sudo ufw allow http

# Network-restricted
sudo ufw allow from 192.168.1.0/24 to any port 3306
```

### Delete a rule

```bash
# By number
sudo ufw status numbered
sudo ufw delete 5

# By rule
sudo ufw delete allow 8080/tcp
```

### Insert a rule (at a position)

```bash
# Insert at position 1
sudo ufw insert 1 deny from 10.0.0.50 to any
```

## Troubleshooting quick links

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common problems
- [DOCKER_NETWORKING.md](DOCKER_NETWORKING.md) - Docker/UFW issues
- [CIS_CONTROLS.md](CIS_CONTROLS.md) - Compliance checks

## Automation

### systemd service

UFW runs as a systemd service:

```bash
# Status
sudo systemctl status ufw

# Inspect the unit file
systemctl cat ufw
```

### NOPASSWD for status checks

For automated monitoring scripts:

```bash
# /etc/sudoers.d/ufw-monitoring
admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status
admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status verbose
admin ALL=(ALL) NOPASSWD: /usr/sbin/ufw status numbered
```

Details: [../scripts/check-ufw-status.sh](../scripts/check-ufw-status.sh)

## Backup & recovery

### Export rules

```bash
# Back up the UFW configuration
sudo cp -r /etc/ufw /etc/ufw.backup.$(date +%Y%m%d)
sudo cp /etc/default/ufw /etc/default/ufw.backup.$(date +%Y%m%d)
```

### Import rules

```bash
# Restore from backup
sudo cp -r /etc/ufw.backup.YYYYMMDD/* /etc/ufw/
sudo ufw reload
```

## Next steps

1. [CIS_CONTROLS.md](CIS_CONTROLS.md) - Ensure compliance
2. [DOCKER_NETWORKING.md](DOCKER_NETWORKING.md) - Docker integration
3. [../drop-ins/](../drop-ins/) - Choose matching templates
4. [../examples/](../examples/) - Production examples
