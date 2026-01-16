# AIDE Setup Guide

Complete installation and configuration guide for AIDE (Advanced Intrusion Detection Environment).

## Prerequisites

- Ubuntu 20.04+ or Debian 11+
- Root access (`sudo`)
- At least 1GB free disk space for AIDE database
- Optional: Prometheus for metrics, Telegram for alerts

## Installation

### 1. Install AIDE Package

```bash
# Update package list
sudo apt update

# Install AIDE
sudo apt install aide aide-common

# Verify installation
aide --version
```

### 2. Initialize AIDE Database

**First-time initialization** (takes 5-15 minutes):

```bash
# Initialize database
sudo aideinit

# Move new database to active location
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

**Check database size**:
```bash
ls -lh /var/lib/aide/aide.db
# Expected: 15-50 MB (depends on filesystem size)
```

---

## Configuration

### 3. Deploy Main Configuration

```bash
# Copy template to AIDE config directory
sudo cp aide.conf.template /etc/aide/aide.conf

# Verify syntax
sudo aide --config=/etc/aide/aide.conf --check-config
```

### 4. Setup Drop-in Excludes

**Create drop-in directory**:
```bash
sudo mkdir -p /etc/aide/aide.conf.d
```

**Deploy service-specific excludes**:
```bash
# Docker excludes (if using Docker)
sudo cp drop-ins/10-docker-excludes.conf /etc/aide/aide.conf.d/

# Monitoring excludes (Prometheus, Grafana)
sudo cp drop-ins/15-monitoring-excludes.conf /etc/aide/aide.conf.d/

# Backup excludes
sudo cp drop-ins/16-backups-excludes.conf /etc/aide/aide.conf.d/

# PostgreSQL excludes (if using PostgreSQL)
sudo cp drop-ins/20-postgresql-excludes.conf /etc/aide/aide.conf.d/

# Systemd excludes
sudo cp drop-ins/40-systemd-excludes.conf /etc/aide/aide.conf.d/
```

**Apply custom excludes** (edit as needed):
```bash
sudo nano /etc/aide/aide.conf.d/99-custom-excludes.conf
```

---

## Automation Setup

### 5. Deploy Update Script

```bash
# Copy script to system location
sudo cp scripts/update-aide-db.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/update-aide-db.sh

# Test script
sudo /usr/local/bin/update-aide-db.sh --check
```

### 6. Setup systemd Timer

```bash
# Copy service unit
sudo cp systemd/aide-update.service.template /etc/systemd/system/aide-update.service

# Copy timer unit
sudo cp systemd/aide-update.timer.template /etc/systemd/system/aide-update.timer

# Edit service unit (replace placeholders)
sudo nano /etc/systemd/system/aide-update.service
```

**Replace placeholders**:
- `{{SCRIPT_PATH}}` → `/usr/local/bin/update-aide-db.sh`
- `{{LOG_DIR}}` → `/var/log/aide`
- `{{TIMEOUT}}` → `90` (minutes)

**Enable timer**:
```bash
sudo systemctl daemon-reload
sudo systemctl enable aide-update.timer
sudo systemctl start aide-update.timer

# Verify timer is active
systemctl status aide-update.timer
systemctl list-timers aide-update.timer
```

---

## Permission Hardening

### 7. Create _aide Group

```bash
# Create system group
sudo groupadd --system _aide

# Add monitoring user to group
sudo usermod -aG _aide monitoring-user

# Verify
getent group _aide
```

### 8. Set Correct Permissions

```bash
# Directory permissions (750)
sudo chown root:_aide /var/lib/aide
sudo chmod 750 /var/lib/aide

# Database permissions (640)
sudo chown root:_aide /var/lib/aide/aide.db
sudo chmod 640 /var/lib/aide/aide.db

# Verify permissions
ls -ld /var/lib/aide
ls -l /var/lib/aide/aide.db
```

**Test read access**:
```bash
# Test as monitoring user
sudo -u monitoring-user test -r /var/lib/aide/aide.db && echo "✅ OK" || echo "❌ FAILED"
```

### 9. Immutable Flag Protection

```bash
# Protect AIDE binary
sudo chattr +i /usr/bin/aide

# Protect configuration
sudo chattr +i /etc/aide/aide.conf

# Verify flags
sudo lsattr /usr/bin/aide /etc/aide/aide.conf
# Expected: ----i---------e------- (i = immutable)
```

**Important**: Before APT upgrades, remove immutable flag:
```bash
sudo chattr -i /usr/bin/aide
sudo apt upgrade aide
sudo chattr +i /usr/bin/aide
```

---

### 10. Fix systemd-tmpfiles Permission Reset

**Problem**: Default `/usr/lib/tmpfiles.d/aide-common.conf` sets wrong permissions on reboot

```bash
# Check default config
cat /usr/lib/tmpfiles.d/aide-common.conf
# Shows: d /var/lib/aide  0700  _aide  root
# Problem: Group root, Permissions 0700 (no group read)
```

**Solution**: Create override in `/etc/tmpfiles.d/`

```bash
# Create override
sudo tee /etc/tmpfiles.d/aide-common.conf > /dev/null << 'TMPFILES'
# Override: Group _aide (not root), Permissions 0750 (not 0700)
# Fix for systemd-tmpfiles permission reset on reboot
d /run/aide            0700    _aide    root
d /var/log/aide        2755    _aide    adm
d /var/lib/aide        0750    _aide    _aide
TMPFILES

# Apply immediately (no reboot needed)
sudo systemd-tmpfiles --create /etc/tmpfiles.d/aide-common.conf

# Verify
sudo ls -ld /var/lib/aide/
# Expected: drwxr-x--- _aide _aide
```

**Why needed**:
- systemd-tmpfiles runs at boot and resets permissions
- Default config has `_aide:root 0700` (blocks group read)
- Override ensures `_aide:_aide 0750` persists across reboots

---

## Optional: Monitoring Integration

### 10. Prometheus Metrics (Optional)

```bash
# Create metrics directory
sudo mkdir -p /var/lib/node_exporter/textfile_collector

# Copy metrics exporter
sudo cp scripts/aide-metrics-exporter.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/aide-metrics-exporter.sh

# Test metrics export
sudo /usr/local/bin/aide-metrics-exporter.sh
cat /var/lib/node_exporter/textfile_collector/aide.prom
```

### 11. Telegram Alerts (Optional)

**Setup**:
1. Create Telegram bot via @BotFather
2. Get bot token and chat ID
3. Store credentials in `/etc/aide/telegram.conf`:

```bash
TELEGRAM_BOT_TOKEN="your-bot-token"
TELEGRAM_CHAT_ID="your-chat-id"
```

**Deploy alert script**:
```bash
sudo cp scripts/aide-failure-alert.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/aide-failure-alert.sh
```

---

## Verification

### 12. Test AIDE Functionality

**Manual check**:
```bash
sudo aide --check --config=/etc/aide/aide.conf
```

**Test update**:
```bash
# Create test file
sudo touch /etc/test-aide-file

# Run check (should report new file)
sudo aide --check

# Update database
sudo /usr/local/bin/update-aide-db.sh

# Check again (should be clean)
sudo aide --check
```

**Cleanup**:
```bash
sudo rm /etc/test-aide-file
```

### 13. Validate Configuration

```bash
# Run validation scripts
./scripts/validate-permissions.sh monitoring-user
./scripts/validate-immutable-flags.sh
```

---

## Post-Installation Checklist

- [ ] AIDE database initialized and exists
- [ ] Main configuration deployed (`/etc/aide/aide.conf`)
- [ ] Drop-in excludes deployed (service-specific)
- [ ] Update script deployed (`/usr/local/bin/update-aide-db.sh`)
- [ ] systemd timer enabled and active
- [ ] _aide group created and monitoring user added
- [ ] Permissions set correctly (750/640)
- [ ] Immutable flags set on binary and config
- [ ] Manual AIDE check successful
- [ ] Timer will run at scheduled time
- [ ] Validation scripts pass

---

## Next Steps

- **Configure excludes**: Edit `/etc/aide/aide.conf.d/99-custom-excludes.conf`
- **Setup monitoring**: See [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md)
- **Reduce false-positives**: See [FALSE_POSITIVE_REDUCTION.md](FALSE_POSITIVE_REDUCTION.md)
- **Troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Best practices**: See [BEST_PRACTICES.md](BEST_PRACTICES.md)

---

## Quick Reference Commands

```bash
# Check timer status
systemctl list-timers aide-update.timer

# Manual check
sudo aide --check

# Manual database update
sudo /usr/local/bin/update-aide-db.sh

# View logs
journalctl -u aide-update.service -n 50

# Validation
./scripts/validate-permissions.sh
./scripts/validate-immutable-flags.sh
```
