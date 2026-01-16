<!--
Copyright (c) 2025-2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# SSH Drop-in Override Patterns

Architectural guide for modular SSH configuration using drop-in overrides.

## Architecture Overview

### The Problem

Traditional SSH hardening faces a trade-off:
- **Secure by default** = Disable all features → breaks legitimate use cases
- **Feature-rich** = Enable everything → security vulnerabilities

**Example**: A development server needs X11 forwarding, but a production server doesn't. How do you share the same base hardening?

### The Solution: Drop-in Pattern

**Base Config** = Maximum security (disable all risky features)
**Overrides** = Enable features only where needed (modular, role-specific)

```
Base Config (sshd_config.template):
  - PasswordAuthentication no
  - PermitRootLogin no
  - X11Forwarding no           ← Secure default
  - AllowTcpForwarding no      ← Secure default
  - AllowAgentForwarding no    ← Secure default

Override (20-development.conf):
  - X11Forwarding yes          ← Enable for dev servers only
  - AllowTcpForwarding yes
  - AllowAgentForwarding yes
```

**Result**: Production servers use base only (100% secure). Development servers use base + override (secure + functional).

---

## How Drop-ins Work

### sshd_config.d/ Loading Order

Ubuntu 22.04+ includes drop-ins automatically:

```bash
# Main config
/etc/ssh/sshd_config

# Drop-ins (loaded in alphanumeric order)
/etc/ssh/sshd_config.d/
  ├── 10-gateway.conf         # Loaded 1st
  ├── 20-development.conf     # Loaded 2nd
  └── 99-ssh-hardening.conf   # Loaded 3rd (base)
```

**Loading Mechanism**:
```bash
# In /etc/ssh/sshd_config (Ubuntu 22.04+ default):
Include /etc/ssh/sshd_config.d/*.conf
```

### Merge Behavior

**Last directive wins**:
```bash
# 10-gateway.conf
AllowTcpForwarding yes

# 99-ssh-hardening.conf
AllowTcpForwarding no

# Result: yes (10-gateway.conf loads first, but has higher priority semantically)
```

**Wait, that's backwards!**

Actually, **later files override earlier files**:
```bash
# Correct understanding:
# Files load in order: 10 → 20 → 99
# Later files (99) override earlier (10)

# But our base is 99 (should be lowest priority)
# So we want overrides to load AFTER base

# Solution: Use numeric prefixes intentionally:
# 99-ssh-hardening.conf = Base (loads last, but has LOWEST semantic priority)
# 10-gateway.conf = Override (loads first, but overrides base settings)
```

**Confusing? Use this rule**: **Lower numbers = Higher priority overrides**

---

## Why This Pattern?

### Modularity

**Traditional approach**:
```bash
# One monolithic sshd_config per server type
/etc/ssh/sshd_config.gateway
/etc/ssh/sshd_config.development
/etc/ssh/sshd_config.production

# Problem: Duplicate 90% of settings across files
# Update hardening = Edit all 3 files
```

**Drop-in approach**:
```bash
# Shared base
/etc/ssh/sshd_config.d/99-ssh-hardening.conf  # 146 lines, shared

# Role-specific overrides
/etc/ssh/sshd_config.d/10-gateway.conf        # 47 lines, only differences
/etc/ssh/sshd_config.d/20-development.conf    # 59 lines, only differences

# Update hardening = Edit base only (1 file, 146 lines)
```

**Result**: ~80% reduction in duplicate configuration

---

### Flexibility

Mix and match overrides for multi-role servers:

```bash
# Gateway + Development server
sudo cp sshd_config.template /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo cp drop-ins/10-gateway.conf /etc/ssh/sshd_config.d/
sudo cp drop-ins/20-development.conf /etc/ssh/sshd_config.d/

# Result: TCP forwarding (gateway) + X11 forwarding (development)
```

**Traditional approach**: Create new monolithic config (gateway-development.conf) with all settings.

---

### Maintainability

**Single source of truth** for hardening:

```bash
# Update: Disable weak cipher
# Traditional: Edit 3+ files (gateway, dev, prod configs)
# Drop-in: Edit 1 file (base config)

# Deploy:
# Traditional: Copy correct file per server type
# Drop-in: Copy base + role-specific overrides
```

**Result**: Updates propagate to all servers by updating base only.

---

## Override Design Principles

### Principle 1: Secure by Default

**Base config disables everything risky**:
```bash
# sshd_config.template (base)
X11Forwarding no              # Risky (X11 vulnerabilities)
AllowTcpForwarding no         # Risky (firewall bypass)
AllowAgentForwarding no       # Risky (agent hijacking)
PermitTunnel no               # Risky (VPN bypass)
GatewayPorts no               # Risky (remote port forwarding)
```

**Rationale**: If a server doesn't deploy an override, it gets maximum security by default.

---

### Principle 2: Override Only What's Needed

**Bad override** (changes too much):
```bash
# 10-gateway.conf (BAD)
AllowTcpForwarding yes
X11Forwarding yes              # ← Not needed for gateway!
PasswordAuthentication yes     # ← Weakens security!
PermitRootLogin yes            # ← Major security risk!
```

**Good override** (minimal, targeted):
```bash
# 10-gateway.conf (GOOD)
AllowTcpForwarding yes         # ← Only what's needed
GatewayPorts clientspecified   # ← Specific to gateway role
```

**Rule**: Override files should be **10-30 lines max** (only differences).

---

### Principle 3: Document the Why

**Every override should explain**:
1. **What** it enables
2. **Why** it's needed
3. **Security impact**
4. **Use cases**

**Example**:
```bash
# 10-gateway.conf
# Purpose: Gateway/Router-specific SSH configuration overrides
# Rationale: Gateways need port forwarding capabilities for tunneling and VPN access

# Allow TCP forwarding (needed for VPN, tunnels, port forwarding)
# Override: base config disables this for security
AllowTcpForwarding yes

# Security considerations:
# - AllowTcpForwarding: Required for gateway functionality
# - GatewayPorts: Limited to "clientspecified" (not "yes" - that's insecure)
# - All other hardening from base config remains active
```

---

## Creating Custom Overrides

### Template
```bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# Custom SSH Override Configuration
# Purpose: [Your specific use case]
# Deployment: /etc/ssh/sshd_config.d/[NN]-custom.conf
# Device Role: [Your server role]
#
# Rationale: [Why these overrides are needed]

# ═══════════════════════════════════════════════════════════
# [Feature Category]
# ═══════════════════════════════════════════════════════════

# [Setting explanation]
# Override: [What base setting this changes]
[Setting] [Value]

# ═══════════════════════════════════════════════════════════
# Notes
# ═══════════════════════════════════════════════════════════

# These overrides enable:
# - [Feature 1]
# - [Feature 2]
#
# Security considerations:
# - [Risk 1 and mitigation]
# - [Risk 2 and mitigation]
#
# Use cases:
# - [Example 1]
# - [Example 2]
```

### Naming Convention

**Prefix determines load order**:
- `10-*.conf` - Infrastructure (gateway, router)
- `20-*.conf` - Development (workstation, Docker)
- `30-*.conf` - Minimal (headless, IoT)
- `40-*.conf` - Custom (user-defined)
- `50-*.conf` - Service-specific (per-application)
- `99-*.conf` - Base config (lowest priority)

**Suffix describes role**:
- `10-gateway.conf` - Clear purpose
- `20-development.conf` - Clear purpose
- `40-custom-myapp.conf` - Custom with context

---

## Common Override Patterns

### Pattern 1: Gateway/Router

**Use Case**: Network gateway, VPN endpoint, router

**Features Needed**:
- TCP forwarding (for tunnels)
- Gateway ports (for remote access)

**Override**:
```bash
AllowTcpForwarding yes
AllowStreamLocalForwarding yes
GatewayPorts clientspecified  # NOT "yes" (insecure)
```

**CIS Impact**: Relaxes 5.2.23 (AllowTcpForwarding)

---

### Pattern 2: Development Server

**Use Case**: Development workstation, Docker host, remote GUI

**Features Needed**:
- X11 forwarding (for GUI apps)
- Agent forwarding (for git SSH)
- TCP forwarding (for port access)

**Override**:
```bash
X11Forwarding yes
X11UseLocalhost yes           # Security: localhost only
AllowAgentForwarding yes
AllowTcpForwarding yes
```

**CIS Impact**: Relaxes 5.2.3 (X11), 5.2.23 (TCP), 5.2.24 (Agent)

---

### Pattern 3: Minimal/Production

**Use Case**: Production app server, headless server, IoT

**Features Needed**: None (base is sufficient)

**Override**: None (or empty 30-minimal.conf for documentation)

**CIS Impact**: None (100% CIS compliance)

---

### Pattern 4: Multi-Role Server

**Use Case**: Server that acts as gateway AND development

**Approach**: Deploy multiple overrides
```bash
sudo cp sshd_config.template /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo cp drop-ins/10-gateway.conf /etc/ssh/sshd_config.d/
sudo cp drop-ins/20-development.conf /etc/ssh/sshd_config.d/
```

**Result**: Features from both overrides enabled

**Note**: If conflicts exist, later file (20-) wins

---

## Anti-Patterns (Don't Do This)

### Anti-Pattern 1: Hardcoding Values in Base

**Bad**:
```bash
# sshd_config.template (BAD)
AllowUsers admin john@192.168.1.100

# Problem: Hardcoded users/IPs in shared base config
# Every server gets these users, even if not applicable
```

**Good**:
```bash
# sshd_config.template (GOOD)
# No AllowUsers directive (allows all users by default)

# 40-custom-server1.conf
AllowUsers admin john@192.168.1.100

# Each server gets its own user restrictions
```

---

### Anti-Pattern 2: Disabling Base Hardening in Override

**Bad**:
```bash
# 40-custom.conf (BAD)
PasswordAuthentication yes     # ← Re-enables passwords!
PermitRootLogin yes            # ← Re-enables root login!
PermitEmptyPasswords yes       # ← Major security hole!

# Problem: Override undoes base hardening
```

**Good**:
```bash
# 40-custom.conf (GOOD)
AllowTcpForwarding yes         # ← Enables feature, doesn't weaken base

# Base hardening (passwords disabled, root disabled) remains active
```

**Rule**: Overrides should **enable features**, not **weaken security**.

---

### Anti-Pattern 3: Duplicate Base Settings in Override

**Bad**:
```bash
# 10-gateway.conf (BAD)
PasswordAuthentication no      # ← Already in base!
PermitRootLogin no             # ← Already in base!
MaxAuthTries 3                 # ← Already in base!
AllowTcpForwarding yes         # ← Only this is needed
```

**Good**:
```bash
# 10-gateway.conf (GOOD)
AllowTcpForwarding yes         # ← Only the override
# All base settings inherited automatically
```

**Rule**: Override files should be **minimal** (only differences).

---

## Testing Overrides

### Syntax Validation
```bash
# Test base only
sudo sshd -t -f /etc/ssh/sshd_config.d/99-ssh-hardening.conf

# Test base + override (simulated merge)
sudo sshd -T | grep -E "(allowtcpforwarding|x11forwarding|allowagentforwarding)"
```

### Effective Configuration
```bash
# Show final merged config
sudo sshd -T

# Filter specific directives
sudo sshd -T | grep allowtcpforwarding
# Expected: allowtcpforwarding yes (if override deployed)
```

### Verification Checklist
```bash
# 1. Base hardening still active?
sudo sshd -T | grep passwordauthentication  # Should be "no"
sudo sshd -T | grep permitrootlogin         # Should be "no"

# 2. Override features enabled?
sudo sshd -T | grep allowtcpforwarding      # Should be "yes" (if override deployed)
sudo sshd -T | grep x11forwarding           # Should be "yes" (if dev override deployed)

# 3. No conflicts?
sudo sshd -t   # Exit code 0 = no conflicts
```

---

## Best Practices

1. **Base is sacred**: Never weaken base hardening in overrides
2. **Overrides are minimal**: 10-30 lines max, only differences
3. **Document the why**: Every override explains its purpose
4. **Use numeric prefixes**: 10-20-30 for priority control
5. **Test before deploy**: `sshd -t` catches syntax errors
6. **Verify merged config**: `sshd -T` shows final result
7. **Review regularly**: Remove unused overrides

---

## Debugging

### Override Not Taking Effect

**Check 1**: Include directive exists
```bash
grep "Include" /etc/ssh/sshd_config
# Should contain: Include /etc/ssh/sshd_config.d/*.conf
```

**Check 2**: File permissions
```bash
ls -l /etc/ssh/sshd_config.d/*.conf
# Should be: -rw-r--r-- (644)
```

**Check 3**: File naming
```bash
ls /etc/ssh/sshd_config.d/
# Should match: [0-9][0-9]-*.conf pattern
```

**Check 4**: Syntax errors
```bash
sudo sshd -t
# Should exit 0
```

### Conflicting Overrides

**Symptom**: Setting doesn't match expected value

**Debug**:
```bash
# Show load order
ls -1 /etc/ssh/sshd_config.d/*.conf

# Show final value
sudo sshd -T | grep [directive]

# Check which file sets it last
grep -r "[directive]" /etc/ssh/sshd_config.d/
```

**Solution**: Rename files to control priority (10 > 20 > 99)

---

## See Also

- [SETUP.md](SETUP.md) - Deployment guide
- [CIS_CONTROLS.md](CIS_CONTROLS.md) - CIS Benchmark mapping
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [../drop-ins/README.md](../drop-ins/README.md) - Override use cases

---

**Version**: 1.0
**Last Updated**: 2026-01-04
