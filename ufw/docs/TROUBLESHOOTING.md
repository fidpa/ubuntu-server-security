<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# UFW Troubleshooting

Common problems and how to solve them.

## Table of contents

- [SSH lockout](#ssh-lockout)
- [Service unreachable](#service-unreachable)
- [Docker bypasses UFW](#docker-bypasses-ufw)
- [Rate limiting too strict](#rate-limiting-too-strict)
- [Logging problems](#logging-problems)
- [Rule conflicts](#rule-conflicts)
- [IPv6 problems](#ipv6-problems)

## SSH lockout

### Problem

No SSH access after `ufw enable`.

### Cause

The SSH rule was not created BEFORE enabling UFW.

### Solution

**If you have physical or console access**:
```bash
# Disable UFW
sudo ufw disable

# Add the SSH rule
sudo ufw allow 22/tcp

# Enable UFW again
sudo ufw enable
```

**Via a serial/IPMI console**:
```bash
sudo ufw status
sudo ufw allow ssh
sudo ufw reload
```

### Prevention

**ALWAYS** create the SSH rule BEFORE enabling UFW:
```bash
sudo ufw allow 22/tcp
# ONLY THEN:
sudo ufw enable
```

## Service unreachable

### Problem

A service is not reachable from outside even though its process is running.

### Diagnosis

```bash
# 1. Is the service running?
systemctl status <service>
ss -tuln | grep <PORT>

# 2. Does a UFW rule exist?
sudo ufw status numbered | grep <PORT>

# 3. Check the log
sudo grep "UFW BLOCK" /var/log/ufw.log | tail -20
```

### Solution

```bash
# Add the rule
sudo ufw allow <PORT>/tcp comment 'Service Name'

# More specific (network-restricted)
sudo ufw allow from 10.0.0.0/24 to any port <PORT> proto tcp
```

### Debugging method

```bash
# From the client:
nc -zv SERVER_IP PORT

# On the server: live log
sudo tail -f /var/log/ufw.log | grep <PORT>
```

## Docker bypasses UFW

### Problem

Docker containers are reachable from outside despite the UFW rules.

### Cause

Docker manipulates iptables directly and inserts the DOCKER/DOCKER-USER chains BEFORE UFW.

### Diagnosis

```bash
# Inspect the Docker chains
sudo iptables -L DOCKER -n -v
sudo iptables -L DOCKER-USER -n -v
```

### Solutions

**Option 1: bind the service to localhost**

```yaml
# docker-compose.yml
ports:
  - "127.0.0.1:8080:8080"  # localhost only
  # NOT: "8080:8080"       # all interfaces!
```

**Option 2: use the DOCKER-USER chain**

```bash
# Allow from the management network only
sudo iptables -I DOCKER-USER -i eth0 -s 10.0.0.0/24 -j ACCEPT
sudo iptables -I DOCKER-USER -i eth0 -j DROP
```

**Option 3: Reverse Proxy**

```
Client → UFW (Port 443) → Nginx → Container (localhost:8080)
```

Details: [DOCKER_NETWORKING.md](DOCKER_NETWORKING.md)

## Rate limiting too strict

### Problem

Legitimate SSH connections get blocked (during automation or deployment).

### Symptom

```bash
sudo grep "UFW LIMIT BLOCK" /var/log/ufw.log
# [UFW LIMIT BLOCK] ... DPT=22 ...
```

### Cause

UFW LIMIT allows at most 6 connections per 30 seconds.

### Solutions

**Option 1: replace LIMIT with ALLOW**

```bash
sudo ufw delete limit 22/tcp
sudo ufw allow 22/tcp
```

**Option 2: network-restricted, without a limit**

```bash
sudo ufw delete limit 22/tcp
sudo ufw allow from 10.0.0.0/24 to any port 22 proto tcp comment 'SSH Management'
```

**Option 3: whitelist plus limit**

```bash
# Automation server without a limit
sudo ufw insert 1 allow from 10.0.0.10 to any port 22 proto tcp
# Everything else with a limit
sudo ufw limit 22/tcp
```

## Logging problems

### Problem: log file missing or empty

```bash
ls -la /var/log/ufw.log
# File does not exist
```

### Solution

```bash
# Enable logging
sudo ufw logging on
sudo ufw logging medium

# Is rsyslog configured?
grep -r "ufw" /etc/rsyslog.d/
```

### Problem: too much logging

```bash
# The log grows too fast

# Reduce logging
sudo ufw logging low

# Or disable it temporarily
sudo ufw logging off
```

### Log rotation

```bash
# /etc/logrotate.d/ufw (Ubuntu default)
/var/log/ufw.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

## Rule conflicts

### Problem: a rule has no effect

**Cause**: rule order (first match wins).

### Diagnosis

```bash
sudo ufw status numbered
```

```
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 22/tcp                     DENY IN     10.0.0.50
```

**Problem**: rule 2 is never reached because rule 1 already matches.

### Solution

```bash
# Put the specific rule BEFORE the general one
sudo ufw delete 2
sudo ufw insert 1 deny from 10.0.0.50 to any port 22
```

### Best practice

Rule order:
1. DENY specific IPs/hosts
2. ALLOW specific networks
3. LIMIT for rate-limited services
4. ALLOW in general

## IPv6 problems

### Problem: duplicate rules (IPv4 + IPv6)

```bash
sudo ufw status
To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
22/tcp (v6)                ALLOW       Anywhere (v6)
```

### Solution (disable IPv6)

```bash
# /etc/default/ufw
IPV6=no

sudo ufw reload
```

### Problem: IPv6 service unreachable

If you do need IPv6:

```bash
# /etc/default/ufw
IPV6=yes

# Explicit IPv6 rule
sudo ufw allow from 2001:db8::/32 to any port 22 proto tcp
```

## Recovery commands

### Reset UFW completely

```bash
sudo ufw reset
# Deletes ALL rules!

# Restore the base setup
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp
sudo ufw enable
```

### Back up before making changes

```bash
# Save the UFW state
sudo cp /etc/ufw/user.rules /etc/ufw/user.rules.backup
sudo cp /etc/ufw/user6.rules /etc/ufw/user6.rules.backup
```

### Restore from backup

```bash
sudo cp /etc/ufw/user.rules.backup /etc/ufw/user.rules
sudo ufw reload
```

## Useful commands

| Command | Description |
|---------|-------------|
| `sudo ufw status verbose` | Full status |
| `sudo ufw status numbered` | With rule numbers |
| `sudo ufw show raw` | Raw iptables output |
| `sudo ufw show added` | Rules that were added |
| `sudo tail -f /var/log/ufw.log` | Live log |
| `sudo ufw reload` | Reload the rules |
| `sudo ufw reset` | Delete all rules |
