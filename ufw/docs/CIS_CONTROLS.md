<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# CIS Benchmark Controls - UFW

CIS Ubuntu 24.04 LTS Benchmark v1.0.0 - Section 3.5 (Host Based Firewall)

## Overview

| Control | Description | Level | Status |
|---------|-------------|-------|--------|
| 3.5.1.1 | Ensure ufw is installed | L1 | ✅ |
| 3.5.1.2 | Ensure iptables-persistent is not installed | L1 | ✅ |
| 3.5.1.3 | Ensure ufw service is enabled | L1 | ✅ |
| 3.5.1.4 | Ensure loopback traffic is configured | L1 | ✅ |
| 3.5.1.5 | Ensure outbound connections are configured | L1 | ✅ |
| 3.5.1.6 | Ensure firewall rules for open ports | L1 | ✅ |
| 3.5.1.7 | Ensure default deny policy | L1 | ✅ |

**Additionally recommended**:

| Control | Description | Level | Status |
|---------|-------------|-------|--------|
| 3.1.1 | Ensure IPv6 is disabled | L2 | ✅ (optional) |

## Control Details

### 3.5.1.1 - UFW installed

**Description**: UFW (Uncomplicated Firewall) must be installed.

**Audit**:
```bash
dpkg -l | grep ufw
# Expected: ii  ufw  ...
```

**Remediation**:
```bash
sudo apt update
sudo apt install ufw
```

### 3.5.1.2 - iptables-persistent NOT installed

**Description**: `iptables-persistent` conflicts with UFW and must not be installed.

**Audit**:
```bash
dpkg -l | grep iptables-persistent
# Expected: no output
```

**Remediation**:
```bash
sudo apt purge iptables-persistent
```

**Rationale**: Both tools try to manage iptables rules, which leads to conflicts.

### 3.5.1.3 - UFW service enabled

**Description**: The UFW service must be enabled and running.

**Audit**:
```bash
systemctl is-enabled ufw
# Expected: enabled

systemctl is-active ufw
# Expected: active

sudo ufw status
# Expected: Status: active
```

**Remediation**:
```bash
sudo systemctl enable ufw
sudo ufw enable
```

### 3.5.1.4 - Loopback traffic configured

**Description**: Traffic on the loopback interface (localhost) must be allowed.

**Audit**:
```bash
sudo ufw status verbose
# Check: loopback in/out allowed
```

**Note**: UFW configures loopback correctly on its own when enabled.

**Manual verification** (if needed):
```bash
sudo iptables -L INPUT -v -n | grep lo
sudo iptables -L OUTPUT -v -n | grep lo
```

### 3.5.1.5 - Outbound connections configured

**Description**: Outbound connections must be explicitly allowed or blocked.

**Audit**:
```bash
sudo ufw status verbose | grep "Default:"
# Expected: Default: deny (incoming), allow (outgoing), ...
```

**Remediation**:
```bash
sudo ufw default allow outgoing
```

**Alternative** (more restrictive, Level 2):
```bash
sudo ufw default deny outgoing
sudo ufw allow out 53/udp  # DNS
sudo ufw allow out 80/tcp  # HTTP
sudo ufw allow out 443/tcp # HTTPS
sudo ufw allow out 123/udp # NTP
```

### 3.5.1.6 - Firewall rules for open ports

**Description**: Every open port must have a matching firewall rule.

**Audit**:
```bash
# 1. Identify open ports
ss -tuln | grep LISTEN

# 2. Inspect UFW rules
sudo ufw status numbered

# 3. Compare: every LISTEN port should be allowed in UFW
```

**Remediation**: Create a rule for every port you need:
```bash
sudo ufw allow <PORT>/tcp comment 'Service Name'
```

**Best practice**: Only open the ports you need (principle of least privilege).

### 3.5.1.7 - Default deny policy

**Description**: The default policy must block incoming connections.

**Audit**:
```bash
sudo ufw status verbose | grep "Default:"
# Expected: Default: deny (incoming), ...
```

**Remediation**:
```bash
sudo ufw default deny incoming
```

## Additional recommendations

### 3.1.1 - Disable IPv6 (optional)

**Description**: If IPv6 is not in use, it should be disabled.

**Audit**:
```bash
grep "^IPV6" /etc/default/ufw
# Check: IPV6=no
```

**Remediation**:
```bash
# Edit /etc/default/ufw
sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
sudo ufw reload
```

**Benefit**: Reduces the attack surface and the number of UFW rules.

## Automated compliance check

### Quick check script

```bash
#!/bin/bash
# CIS UFW Compliance Check

echo "=== CIS UFW Compliance Check ==="

# 3.5.1.1
echo -n "3.5.1.1 UFW installed: "
dpkg -l ufw &>/dev/null && echo "PASS" || echo "FAIL"

# 3.5.1.2
echo -n "3.5.1.2 iptables-persistent absent: "
! dpkg -l iptables-persistent &>/dev/null && echo "PASS" || echo "FAIL"

# 3.5.1.3
echo -n "3.5.1.3 UFW enabled: "
systemctl is-enabled ufw &>/dev/null && echo "PASS" || echo "FAIL"

# 3.5.1.7
echo -n "3.5.1.7 Default deny: "
sudo ufw status verbose | grep -q "deny (incoming)" && echo "PASS" || echo "FAIL"
```

### Full check

Use the bundled script: [../scripts/check-ufw-status.sh](../scripts/check-ufw-status.sh)

## Compliance matrix

| Control | Audit Command | Expected Result |
|---------|--------------|-----------------|
| 3.5.1.1 | `dpkg -l ufw` | Package installed |
| 3.5.1.2 | `dpkg -l iptables-persistent` | Not found |
| 3.5.1.3 | `systemctl is-enabled ufw` | enabled |
| 3.5.1.4 | Automatic | Loopback configured |
| 3.5.1.5 | `ufw status verbose` | allow (outgoing) |
| 3.5.1.7 | `ufw status verbose` | deny (incoming) |

## Common compliance failures

### Problem: iptables-persistent installed

```bash
# Symptom
dpkg -l | grep iptables-persistent
ii  iptables-persistent  ...

# Fix
sudo apt purge iptables-persistent
sudo ufw reload
```

### Problem: default policy is not deny

```bash
# Symptom
sudo ufw status verbose
Default: allow (incoming), ...

# Fix
sudo ufw default deny incoming
```

### Problem: service not active

```bash
# Symptom
systemctl is-active ufw
inactive

# Fix
sudo ufw enable
```

## References

- [CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [UFW Official Documentation](https://help.ubuntu.com/community/UFW)
- [Ubuntu Server Guide - Firewall](https://ubuntu.com/server/docs/security-firewall)
