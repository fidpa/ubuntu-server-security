# AppArmor Setup Guide

Complete guide for deploying AppArmor profiles on Ubuntu Server.

## Prerequisites

### 1. Verify AppArmor is Installed

```bash
# Check if AppArmor is installed
dpkg -l | grep apparmor

# Expected output:
# ii  apparmor    4.0.1...    amd64    user-space parser utility for AppArmor
# ii  libapparmor1    4.0.1...    amd64    changehat AppArmor library
```

If not installed:
```bash
sudo apt update
sudo apt install apparmor apparmor-utils
```

### 2. Verify Kernel Support

```bash
# Check if AppArmor is enabled in kernel
cat /sys/module/apparmor/parameters/enabled
# Expected: Y

# Check LSM configuration
cat /sys/kernel/security/lsm
# Expected: includes "apparmor"
```

### 3. Check Current Status

```bash
sudo aa-status
```

## Installation

### Method 1: Using Deploy Script (Recommended)

```bash
# Clone repository
git clone https://github.com/fidpa/ubuntu-server-security.git
cd ubuntu-server-security/apparmor

# Deploy PostgreSQL profile in COMPLAIN mode
sudo ./scripts/deploy-profile.sh profiles/usr.lib.postgresql.16.bin.postgres

# After testing (24-48h), switch to ENFORCE
sudo aa-enforce /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
```

### Method 2: Manual Installation

```bash
# 1. Copy profile
sudo cp profiles/usr.lib.postgresql.16.bin.postgres /etc/apparmor.d/

# 2. Set permissions
sudo chmod 644 /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres

# 3. Load in COMPLAIN mode
sudo apparmor_parser -r -C /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres

# 4. Verify
sudo aa-status | grep postgresql
```

## Two-Phase Deployment

### Phase 1: COMPLAIN Mode (24-48 hours)

COMPLAIN mode logs violations without blocking. This allows you to identify missing permissions before enforcing.

```bash
# Load profile in COMPLAIN mode
sudo apparmor_parser -r -C /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres

# Monitor violations
sudo tail -f /var/log/syslog | grep apparmor

# Or use the check script
./scripts/check-violations.sh postgresql --recent
```

**What to Look For**:
- `ALLOWED` messages - operations that would be blocked in ENFORCE mode
- `DENIED` messages - operations that are blocked (shouldn't appear in COMPLAIN)

### Phase 2: ENFORCE Mode (Production)

After confirming no issues in COMPLAIN mode:

```bash
# Switch to ENFORCE
sudo aa-enforce /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres

# Verify
sudo aa-status | grep -A2 "profiles are in enforce"

# Test service
sudo systemctl restart postgresql@16-main
sudo -u postgres psql -c "SELECT version();"
```

## Profile Customization

### Adding Paths

If your PostgreSQL uses non-standard paths:

```bash
sudo nano /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
```

Add custom paths:
```
# Custom data directory
/custom/postgresql/data/** rwk,

# Custom log directory
/custom/logs/postgresql/** rw,
```

Reload profile:
```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
```

### Adding Extensions

For PostgreSQL extensions:
```
/usr/lib/postgresql/16/lib/*.so mr,
/usr/share/postgresql/16/extension/** r,
```

### SSL Certificate Access

```
/etc/ssl/certs/** r,
/etc/ssl/private/** r,
/etc/letsencrypt/live/** r,
/etc/letsencrypt/archive/** r,
```

## Persistence

AppArmor profiles in `/etc/apparmor.d/` are automatically loaded at boot. No additional configuration required.

To verify after reboot:
```bash
sudo aa-status | grep postgresql
```

## Rollback

### Switch to COMPLAIN Mode

```bash
sudo aa-complain /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
```

### Disable Profile Completely

```bash
sudo aa-disable /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
sudo systemctl restart postgresql@16-main
```

### Remove Profile

```bash
sudo aa-disable /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
sudo rm /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
```

## Validation Checklist

- [ ] AppArmor module loaded (`aa-status` shows "apparmor module is loaded")
- [ ] Profile syntax valid (`apparmor_parser -p` succeeds)
- [ ] Profile loaded (`aa-status | grep postgresql`)
- [ ] Service starts successfully
- [ ] No violations in logs (COMPLAIN mode)
- [ ] Application functions correctly
- [ ] Profile switched to ENFORCE mode
- [ ] Profile persists after reboot

## Common Commands

| Command | Purpose |
|---------|---------|
| `sudo aa-status` | Show all profiles and status |
| `sudo aa-enforce <profile>` | Switch profile to ENFORCE |
| `sudo aa-complain <profile>` | Switch profile to COMPLAIN |
| `sudo aa-disable <profile>` | Disable profile |
| `sudo apparmor_parser -r <profile>` | Reload profile |
| `sudo aa-logprof` | Generate profile updates from logs |
