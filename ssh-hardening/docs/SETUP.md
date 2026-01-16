<!--
Copyright (c) 2025-2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# SSH Hardening - Setup Guide

Complete guide for deploying hardened SSH configuration on Ubuntu servers.

## Prerequisites

### System Requirements
- Ubuntu 22.04 LTS or later
- OpenSSH Server 8.2+
- Root or sudo access
- Existing SSH key authentication configured

### Critical Pre-Deployment Checks

**⚠️ WARNING**: Deploying SSH hardening without proper preparation can lock you out!

Before proceeding, verify:

```bash
# 1. Confirm you have SSH keys configured
ls -la ~/.ssh/id_* ~/.ssh/authorized_keys

# 2. Verify sshd_config.d/ drop-in support (Ubuntu 22.04+)
grep "Include /etc/ssh/sshd_config.d/\*.conf" /etc/ssh/sshd_config

# 3. Test SSH connection with key (NOT password)
ssh -o PreferredAuthentications=publickey localhost

# 4. Have console/rescue access ready (in case of lockout)
# Physical console, VPS console, or rescue mode
```

If any check fails, **DO NOT PROCEED** until resolved.

## Installation

### Option 1: Basic Hardening (Recommended for First Deployment)

Deploy base hardened config only:

```bash
# 1. Clone repository
git clone https://github.com/fidpa/ubuntu-server-security.git
cd ubuntu-server-security/ssh-hardening

# 2. Validate current SSH config
./scripts/validate-sshd-config.sh --config /etc/ssh/sshd_config

# 3. Backup existing config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)

# 4. Deploy base hardening
sudo cp sshd_config.template /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo chmod 644 /etc/ssh/sshd_config.d/99-ssh-hardening.conf

# 5. Validate syntax (CRITICAL - prevents lockout)
sudo sshd -t
echo "Exit code: $?"  # Must be 0

# 6. Restart SSH
sudo systemctl restart ssh

# 7. Test new connection (WITHOUT closing current session!)
# Open new terminal:
ssh your-server

# 8. If test passes, close old session. If fails, revert:
# sudo rm /etc/ssh/sshd_config.d/99-ssh-hardening.conf
# sudo systemctl restart ssh
```

### Option 2: Role-Specific Deployment (Gateway/Development)

Deploy base + role-specific override:

```bash
# Follow Option 1 steps 1-5, then:

# For gateway/router:
sudo cp drop-ins/10-gateway.conf /etc/ssh/sshd_config.d/
sudo chmod 644 /etc/ssh/sshd_config.d/10-gateway.conf

# OR for development server:
sudo cp drop-ins/20-development.conf /etc/ssh/sshd_config.d/
sudo chmod 644 /etc/ssh/sshd_config.d/20-development.conf

# Re-validate and restart (Option 1 steps 5-8)
```

### Option 3: Pre-Built Examples

Use ready-to-deploy scenario:

```bash
# Basic hardening (single file):
cd examples/basic-hardening
sudo cp sshd_config /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo chmod 644 /etc/ssh/sshd_config.d/99-ssh-hardening.conf

# Production hardening (modular):
cd examples/production-hardening
sudo cp sshd_config /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo cp sshd_config.d/* /etc/ssh/sshd_config.d/
sudo chmod 644 /etc/ssh/sshd_config.d/*.conf

# Validate and restart (Option 1 steps 5-8)
```

## Drop-in Selection Guide

Choose override based on server role:

| Server Role | Base Config | Override | Reason |
|-------------|-------------|----------|--------|
| **Gateway/Router** | ✅ | 10-gateway.conf | Needs TCP forwarding for VPN, tunnels |
| **Development Server** | ✅ | 20-development.conf | Needs X11 forwarding, Docker port access |
| **Production App Server** | ✅ | None | Maximum security, no extra features |
| **Headless/IoT Device** | ✅ | None or 30-minimal.conf | Minimal SSH usage |
| **Multi-Purpose Server** | ✅ | Multiple overrides | Combine gateway + development if needed |

See [../drop-ins/README.md](../drop-ins/README.md) for detailed use cases.

## Validation Before Deployment

**⚠️ CRITICAL**: Always validate before restarting SSH!

### Syntax Validation
```bash
# Validate SSH config syntax
sudo sshd -t

# Validate specific config file
sudo sshd -t -f /etc/ssh/sshd_config.d/99-ssh-hardening.conf
```

### Baseline Compliance Check
```bash
# Run validation script
./scripts/validate-sshd-config.sh --config /etc/ssh/sshd_config

# JSON output for CI/CD
./scripts/validate-sshd-config.sh --config /etc/ssh/sshd_config --json
```

**Exit codes**:
- `0` = OK (safe to deploy)
- `1` = Warning (review before deploying)
- `2` = Error (do not deploy)
- `3` = **Lockout risk** (deployment would break SSH access)

### Permission Validation
```bash
# Check file permissions
stat -c "%a %n" /etc/ssh/sshd_config.d/*.conf

# Should be 644 or 600
# Fix if needed:
sudo chmod 644 /etc/ssh/sshd_config.d/*.conf
```

## Testing Without SSH Lockout

**Safe testing workflow**:

1. **Keep existing SSH session open** (do not close!)
2. **Deploy config** in new terminal
3. **Test new connection** in another terminal:
   ```bash
   ssh your-server
   ```
4. **If test succeeds**: Close old session
5. **If test fails**: Revert in existing session:
   ```bash
   sudo rm /etc/ssh/sshd_config.d/99-ssh-hardening.conf
   sudo systemctl restart ssh
   ```

**Test checklist**:
- ✅ SSH connection succeeds with key
- ✅ Password authentication rejected (if configured)
- ✅ Root login rejected
- ✅ Port forwarding works (if using gateway override)
- ✅ X11 forwarding works (if using development override)

## Post-Deployment Verification

```bash
# 1. Check SSH service status
sudo systemctl status ssh

# 2. Verify active config
sudo sshd -T | grep -E "(passwordauthentication|pubkeyauthentication|permitrootlogin|ciphers|macs)"

# 3. Check auth log for errors
sudo journalctl -u ssh -n 50 --no-pager

# 4. Verify fingerprint changes (if keys regenerated)
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

## SSH Key Generation

If you need to generate Ed25519 host keys:

```bash
# Generate Ed25519 key (recommended)
sudo ./scripts/generate-hostkeys.sh --key-type ed25519

# Generate with immutable flag (rootkit protection)
sudo ./scripts/generate-hostkeys.sh --key-type ed25519 --immutable

# Generate ECDSA fallback (for older clients)
sudo ./scripts/generate-hostkeys.sh --key-type ecdsa
```

**Note**: After generating new host keys:
1. Clients will see "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!"
2. Remove old entry: `ssh-keygen -R your-server`
3. Accept new fingerprint on first connection

## Recovery Procedures

### Locked Out of SSH

**If you still have one working SSH session**:
```bash
# Revert config
sudo rm /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo systemctl restart ssh

# Restore backup
sudo cp /etc/ssh/sshd_config.backup.YYYYMMDD /etc/ssh/sshd_config
sudo systemctl restart ssh
```

**If completely locked out**:
1. Use console access (physical, VPS console, or rescue mode)
2. Remove hardening config:
   ```bash
   rm /etc/ssh/sshd_config.d/99-ssh-hardening.conf
   systemctl restart ssh
   ```
3. Investigate issue (check auth logs)
4. Re-deploy with corrections

### Common Lockout Causes
- No SSH keys configured (`~/.ssh/authorized_keys` missing)
- Wrong file permissions (`chmod 600 ~/.ssh/authorized_keys`)
- SELinux/AppArmor blocking SSH key access
- Firewall blocking SSH port

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed recovery steps.

## Integration with Existing Config

### sshd_config.d/ Drop-in Pattern

Ubuntu 22.04+ uses drop-in config pattern:

```
/etc/ssh/sshd_config          # Main config (DO NOT EDIT)
/etc/ssh/sshd_config.d/       # Drop-ins (ADD FILES HERE)
  ├── 10-gateway.conf         # Override 1
  ├── 20-development.conf     # Override 2
  └── 99-ssh-hardening.conf   # Base hardening
```

**Loading order**: Numeric prefix determines order (10 → 20 → 99)

**Merge behavior**: Last directive wins (later files override earlier ones)

### Preserving Custom Settings

If you have custom SSH settings:

**Option 1**: Create 50-custom.conf (loads after base, before specific overrides)
```bash
sudo nano /etc/ssh/sshd_config.d/50-custom.conf
```

**Option 2**: Modify base template before deploying
```bash
# Edit template locally
nano sshd_config.template
# Then deploy
```

**Option 3**: Use 99-custom.conf (highest priority)
```bash
sudo nano /etc/ssh/sshd_config.d/99-custom.conf
# Overrides all other settings
```

## Automation

### systemd Timer for Validation

Auto-validate SSH config daily:

```bash
# Create validation service
sudo tee /etc/systemd/system/sshd-config-validator.service <<EOF
[Unit]
Description=SSH Configuration Validator
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/validate-sshd-config.sh --config /etc/ssh/sshd_config
StandardOutput=journal
StandardError=journal
EOF

# Create timer
sudo tee /etc/systemd/system/sshd-config-validator.timer <<EOF
[Unit]
Description=Daily SSH Configuration Validation

[Timer]
OnCalendar=daily
OnBootSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Enable timer
sudo systemctl daemon-reload
sudo systemctl enable --now sshd-config-validator.timer
```

### CI/CD Integration

```bash
# Pre-deployment validation in CI/CD pipeline
./scripts/validate-sshd-config.sh --config /etc/ssh/sshd_config --json > validation-result.json

# Check exit code
if [ $? -eq 3 ]; then
  echo "LOCKOUT RISK DETECTED - Deployment aborted"
  exit 1
fi
```

## Best Practices

1. **Always validate before restart**: `sudo sshd -t`
2. **Keep existing session open** during testing
3. **Backup config** before changes
4. **Test from multiple clients** (different OSes, SSH versions)
5. **Document custom overrides** (comments in 50-custom.conf)
6. **Monitor auth logs** after deployment (`journalctl -u ssh -f`)
7. **Update authorized_keys** regularly (remove old keys)
8. **Use Ed25519 keys** for new deployments (modern, fast, secure)

## See Also

- [CIS_CONTROLS.md](CIS_CONTROLS.md) - CIS Benchmark mapping
- [OVERRIDE_PATTERNS.md](OVERRIDE_PATTERNS.md) - Drop-in architecture
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and recovery
- [../drop-ins/README.md](../drop-ins/README.md) - Override use cases

---

**Version**: 1.0
**Last Updated**: 2026-01-04
