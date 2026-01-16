<!--
Copyright (c) 2025-2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# Basic SSH Hardening Example

Single-file SSH hardening configuration for quick deployment.

## What This Is

A **pre-configured single-file** SSH hardening config that combines:
- Base hardening (key-only auth, modern crypto, rate limiting)
- Gateway features (TCP forwarding for VPN/tunnels)

**Use case**: Network gateway, router, VPN endpoint

**Complexity**: ⭐ Simple (1 file, 3 commands)

---

## What's Included

| File | Purpose |
|------|---------|
| [sshd_config](sshd_config) | Combined base + gateway hardening (inline) |

**Security Features**:
- ✅ Key-only authentication (no passwords)
- ✅ Ed25519 preferred
- ✅ Root login disabled
- ✅ Modern ciphers/MACs
- ✅ Rate limiting (MaxAuthTries 3, MaxStartups 3:50:10)
- ✅ TCP forwarding enabled (for VPN/tunnels)

---

## Deployment

### Prerequisites
- Ubuntu 22.04 LTS or later
- SSH keys configured (`~/.ssh/authorized_keys`)
- Console/rescue access ready (in case of lockout)

### Installation

```bash
# 1. Backup existing config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)

# 2. Deploy hardening config
sudo cp sshd_config /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo chmod 644 /etc/ssh/sshd_config.d/99-ssh-hardening.conf

# 3. Validate (CRITICAL - prevents lockout)
sudo sshd -t
echo "Exit code: $?"  # Must be 0

# 4. Restart SSH (keep existing session open!)
sudo systemctl restart ssh

# 5. Test new connection from different terminal
ssh your-server
```

**If test fails**: Revert in existing session
```bash
sudo rm /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo systemctl restart ssh
```

---

## Verification

```bash
# Check SSH service status
sudo systemctl status ssh

# Verify active config
sudo sshd -T | grep -E "(passwordauthentication|permitrootlogin|allowtcpforwarding|ciphers)"

# Expected:
# passwordauthentication no
# permitrootlogin no
# allowtcpforwarding yes  (gateway feature enabled)
# ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,...
```

---

## Use Cases

✅ **Gateway/Router** - TCP forwarding for VPN, tunnels, port forwarding

✅ **VPN Endpoint** - Needs SSH tunneling capabilities

✅ **Simple Deployment** - Quick hardening with minimal complexity

❌ **Development Server** - Use production-hardening example (includes X11)

❌ **Production App Server** - Use base config only (no TCP forwarding)

---

## CIS Benchmark Compliance

**Implemented Controls**: 15/18 (83%)

**Relaxed Controls** (for gateway functionality):
- 5.2.23 (AllowTcpForwarding) - Set to `yes` (needed for tunnels)

**All other CIS controls enforced** (passwords disabled, root disabled, modern crypto, etc.)

See [../../docs/CIS_CONTROLS.md](../../docs/CIS_CONTROLS.md) for detailed mapping.

---

## Customization

### Enable X11 Forwarding (for remote GUI)
```bash
# Edit deployed config
sudo nano /etc/ssh/sshd_config.d/99-ssh-hardening.conf

# Add these lines:
X11Forwarding yes
X11DisplayOffset 10
X11UseLocalhost yes

# Validate and restart
sudo sshd -t
sudo systemctl restart ssh
```

### Disable TCP Forwarding (if not needed)
```bash
# Edit deployed config
sudo nano /etc/ssh/sshd_config.d/99-ssh-hardening.conf

# Change:
AllowTcpForwarding no

# Validate and restart
sudo sshd -t
sudo systemctl restart ssh
```

---

## See Also

- [../production-hardening/](../production-hardening/) - Modular config with drop-ins
- [../../docs/SETUP.md](../../docs/SETUP.md) - Full deployment guide
- [../../docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md) - Common issues

---

**Version**: 1.0
**Deployment Time**: ~2 minutes
**Recommended For**: Quick gateway hardening
