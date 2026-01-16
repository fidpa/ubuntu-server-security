<!--
Copyright (c) 2025-2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# Production SSH Hardening Example

Modular SSH hardening configuration with drop-in overrides.

## What This Is

A **production-ready modular** SSH hardening config that uses:
- Base hardening (key-only auth, modern crypto, rate limiting)
- Drop-in overrides (gateway + development features)

**Use case**: Multi-purpose server (development + gateway capabilities)

**Complexity**: ⭐⭐ Moderate (modular, flexible, production-ready)

---

## What's Included

| File | Purpose |
|------|---------|
| [sshd_config](sshd_config) | Base hardening (secure-by-default) |
| [sshd_config.d/10-gateway.conf](sshd_config.d/10-gateway.conf) | Gateway override (TCP forwarding) |
| [sshd_config.d/20-development.conf](sshd_config.d/20-development.conf) | Development override (X11, agent forwarding) |

**Security Features**:
- ✅ Key-only authentication (no passwords)
- ✅ Ed25519 preferred
- ✅ Root login disabled
- ✅ Modern ciphers/MACs
- ✅ Rate limiting (MaxAuthTries 3, MaxStartups 3:50:10)
- ✅ Modular overrides (enable only features you need)

**Enabled Features** (via overrides):
- ✅ TCP forwarding (for VPN/tunnels)
- ✅ X11 forwarding (for remote GUI apps)
- ✅ Agent forwarding (for git SSH operations)

---

## Deployment

### Prerequisites
- Ubuntu 22.04 LTS or later
- SSH keys configured (`~/.ssh/authorized_keys`)
- Console/rescue access ready (in case of lockout)

### Full Installation (Base + Both Overrides)

```bash
# 1. Backup existing config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)

# 2. Deploy base config
sudo cp sshd_config /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo chmod 644 /etc/ssh/sshd_config.d/99-ssh-hardening.conf

# 3. Deploy overrides
sudo cp sshd_config.d/* /etc/ssh/sshd_config.d/
sudo chmod 644 /etc/ssh/sshd_config.d/*.conf

# 4. Validate (CRITICAL - prevents lockout)
sudo sshd -t
echo "Exit code: $?"  # Must be 0

# 5. Restart SSH (keep existing session open!)
sudo systemctl restart ssh

# 6. Test new connection from different terminal
ssh your-server
```

### Selective Installation (Base + Specific Override)

**Gateway only** (no X11):
```bash
sudo cp sshd_config /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo cp sshd_config.d/10-gateway.conf /etc/ssh/sshd_config.d/
sudo chmod 644 /etc/ssh/sshd_config.d/*.conf
sudo sshd -t && sudo systemctl restart ssh
```

**Development only** (no gateway):
```bash
sudo cp sshd_config /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo cp sshd_config.d/20-development.conf /etc/ssh/sshd_config.d/
sudo chmod 644 /etc/ssh/sshd_config.d/*.conf
sudo sshd -t && sudo systemctl restart ssh
```

**Base only** (maximum security):
```bash
sudo cp sshd_config /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo chmod 644 /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo sshd -t && sudo systemctl restart ssh
```

---

## Verification

```bash
# Check SSH service status
sudo systemctl status ssh

# List active configs
ls -la /etc/ssh/sshd_config.d/*.conf

# Verify merged config
sudo sshd -T | grep -E "(passwordauthentication|permitrootlogin|allowtcpforwarding|x11forwarding|allowagentforwarding)"

# Expected (with both overrides):
# passwordauthentication no
# permitrootlogin no
# allowtcpforwarding yes       (gateway override)
# x11forwarding yes            (development override)
# allowagentforwarding yes     (development override)
```

---

## Use Cases

✅ **Multi-Purpose Server** - Gateway + Development features

✅ **Flexible Deployment** - Enable only features you need

✅ **Production Ready** - Modular, maintainable, upgradeable

✅ **Development Server** - X11, agent forwarding for remote work

✅ **Gateway/Router** - TCP forwarding for VPN, tunnels

❌ **Simple Deployment** - Use basic-hardening example (less complexity)

---

## Architecture

### Modular Design

**Base config** (99-ssh-hardening.conf):
- Secure-by-default (all risky features disabled)
- Shared across all server types
- Update once, deploy everywhere

**Overrides** (10-gateway.conf, 20-development.conf):
- Enable features only where needed
- Role-specific (gateway, development)
- Mix and match for multi-purpose servers

**Loading order**: 10 → 20 → 99 (later files override earlier)

### Why Modular?

**Maintainability**:
- Update base hardening in one place
- Add/remove overrides per server role
- No duplicate configuration

**Flexibility**:
- Gateway server: Base + 10-gateway.conf
- Development server: Base + 20-development.conf
- Multi-purpose: Base + 10-gateway.conf + 20-development.conf
- Production: Base only (maximum security)

**Security**:
- Secure-by-default base (100% CIS if no overrides)
- Overrides only enable required features
- No accidental feature creep

---

## CIS Benchmark Compliance

**Base config**: 100% CIS compliance (15/15 controls)

**With overrides**: 83% compliance (15/18)

**Relaxed controls** (intentional, for functionality):
- 5.2.3 (X11Forwarding) - Enabled in 20-development.conf
- 5.2.23 (AllowTcpForwarding) - Enabled in 10-gateway.conf + 20-development.conf
- 5.2.24 (AllowAgentForwarding) - Enabled in 20-development.conf

See [../../docs/CIS_CONTROLS.md](../../docs/CIS_CONTROLS.md) for detailed mapping.

---

## Customization

### Add Custom Override

Create 50-custom.conf:
```bash
sudo nano /etc/ssh/sshd_config.d/50-custom.conf
```

Example content:
```bash
# Custom SSH Override
# Purpose: Allow specific users only

AllowUsers admin developer@192.168.1.0/24
```

Validate and restart:
```bash
sudo sshd -t
sudo systemctl restart ssh
```

### Remove Specific Override

```bash
# Disable X11 forwarding (remove development override)
sudo rm /etc/ssh/sshd_config.d/20-development.conf
sudo systemctl restart ssh

# Verify X11 disabled
sudo sshd -T | grep x11forwarding
# Expected: x11forwarding no
```

---

## Troubleshooting

### Override Not Taking Effect

**Check load order**:
```bash
ls -1 /etc/ssh/sshd_config.d/*.conf
# Should list: 10-gateway.conf, 20-development.conf, 99-ssh-hardening.conf
```

**Check final merged config**:
```bash
sudo sshd -T | grep allowtcpforwarding
# Expected: allowtcpforwarding yes (if override deployed)
```

### Conflicting Settings

**Debug**:
```bash
# Show which file sets directive
grep -r "AllowTcpForwarding" /etc/ssh/sshd_config.d/

# Show final value
sudo sshd -T | grep allowtcpforwarding
```

**Solution**: Rename files to control priority (10 > 20 > 99)

See [../../docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md) for detailed recovery procedures.

---

## See Also

- [../basic-hardening/](../basic-hardening/) - Single-file config (simpler)
- [../../docs/SETUP.md](../../docs/SETUP.md) - Full deployment guide
- [../../docs/OVERRIDE_PATTERNS.md](../../docs/OVERRIDE_PATTERNS.md) - Drop-in architecture
- [../../docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md) - Common issues

---

**Version**: 1.0
**Deployment Time**: ~5 minutes
**Recommended For**: Production multi-purpose servers
