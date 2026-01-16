# USB Defense System - Setup Guide

Complete installation and configuration guide for the 3-layer USB defense system.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Installation](#quick-installation)
3. [Manual Installation](#manual-installation)
4. [Configuration](#configuration)
5. [Testing](#testing)
6. [Verification](#verification)

---

## Prerequisites

### Required Packages

```bash
# Install required packages
sudo apt update
sudo apt install -y auditd usbutils coreutils util-linux

# Optional: Email support
sudo apt install -y msmtp mailutils
```

### Required Services

```bash
# Verify auditd is running
systemctl status auditd

# Start if not running
sudo systemctl start auditd
sudo systemctl enable auditd
```

### Permissions

- Root/sudo access required for installation
- Scripts can run as unprivileged user after deployment

---

## Quick Installation

**One-command deployment** (recommended for most users):

```bash
# Clone repository
git clone https://github.com/fidpa/ubuntu-server-security.git
cd ubuntu-server-security/usb-defense

# Deploy all 3 layers
sudo ./scripts/deploy-usb-defense.sh
```

**Expected output:**
```
[INFO] USB Defense System Deployment v1.0.0
[INFO] Checking prerequisites...
[SUCCESS] Prerequisites OK
[INFO] Deploying Layer 1: Kernel module blacklist...
[SUCCESS] Layer 1 deployed: Kernel blacklist active
[INFO] Deploying Layer 2: USB device watcher...
[SUCCESS] Layer 2 deployed: USB device watcher active
[INFO] Deploying Layer 3: auditd bypass detection...
[SUCCESS] Layer 3 deployed: auditd bypass detection active
[INFO] Verifying deployment...
[SUCCESS] All layers verified successfully!
```

**What the script does:**
1. Copies blacklist config to `/etc/modprobe.d/`
2. Updates initramfs (boot-persistent)
3. Installs USB watcher script to `/usr/local/bin/`
4. Creates systemd service `usb-device-watcher.service`
5. Installs auditd rules to `/etc/audit/rules.d/`
6. Creates systemd timer `check-usb-activity.timer`

---

## Manual Installation

If you prefer step-by-step installation:

### Layer 1: Kernel Blacklist

```bash
# Copy blacklist config
sudo cp configs/blacklist-usb-storage.conf /etc/modprobe.d/
sudo chmod 644 /etc/modprobe.d/blacklist-usb-storage.conf

# Update initramfs (boot-persistent)
sudo update-initramfs -u

# Unload module if currently loaded
sudo rmmod usb_storage 2>/dev/null || true

# Verify
lsmod | grep usb_storage  # Should return nothing
```

### Layer 2: USB Device Watcher

```bash
# Create state directory
sudo mkdir -p /var/lib/usb-defense
sudo chmod 755 /var/lib/usb-defense

# Install script
sudo cp scripts/usb-device-watcher.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/usb-device-watcher.sh

# Install systemd service
sudo cp systemd/usb-device-watcher.service.template \
        /etc/systemd/system/usb-device-watcher.service

# Start service
sudo systemctl daemon-reload
sudo systemctl enable usb-device-watcher.service
sudo systemctl start usb-device-watcher.service

# Verify
systemctl status usb-device-watcher.service
```

### Layer 3: auditd Bypass Detection

```bash
# Install auditd rules
sudo cp configs/99-usb-defense.rules /etc/audit/rules.d/
sudo chmod 644 /etc/audit/rules.d/99-usb-defense.rules

# Reload rules
sudo augenrules --load

# Install monitoring script
sudo cp scripts/check-usb-activity.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/check-usb-activity.sh

# Install systemd service + timer
sudo cp systemd/check-usb-activity.service.template \
        /etc/systemd/system/check-usb-activity.service
sudo cp systemd/check-usb-activity.timer.template \
        /etc/systemd/system/check-usb-activity.timer

# Start timer
sudo systemctl daemon-reload
sudo systemctl enable check-usb-activity.timer
sudo systemctl start check-usb-activity.timer

# Verify
systemctl status check-usb-activity.timer
sudo auditctl -l | grep usb_  # Should show 7 rules
```

---

## Configuration

### Email Alerts

**Option 1: Using mail command** (simplest):
```bash
# Install
sudo apt install mailutils

# Test
echo "Test" | mail -s "Test Alert" root
```

**Option 2: Using msmtp** (recommended for production):
```bash
# Install
sudo apt install msmtp

# Configure /etc/msmtprc
sudo tee /etc/msmtprc <<EOF
account default
host smtp.example.com
port 587
from alerts@example.com
user alerts@example.com
password your-password
auth on
tls on
tls_starttls on
logfile /var/log/msmtp.log
EOF

sudo chmod 600 /etc/msmtprc

# Test
echo "Test" | msmtp root
```

### Environment Variables

Add to systemd service files or shell environment:

```bash
# Alert recipient
USB_DEFENSE_ALERT_EMAIL="security@example.com"

# Polling interval (seconds)
USB_DEFENSE_POLL_INTERVAL="2"

# Alert cooldown (seconds)
USB_DEFENSE_COOLDOWN="3600"

# State directory
USB_DEFENSE_STATE_DIR="/var/lib/usb-defense"
```

**Example systemd service customization:**
```bash
sudo systemctl edit usb-device-watcher.service
```

Add:
```ini
[Service]
Environment="USB_DEFENSE_ALERT_EMAIL=security@example.com"
Environment="USB_DEFENSE_COOLDOWN=1800"
```

Restart:
```bash
sudo systemctl restart usb-device-watcher.service
```

---

## Testing

### Test 1: Real USB Device (RECOMMENDED)

```bash
# 1. Plug in USB stick
# 2. Wait 2-4 seconds
# 3. Check results

# Verify device detected
lsusb | grep -i "sandisk\|kingston\|mass"
# Expected: Device visible

# Verify NOT mountable
lsblk | grep -E "sd[b-z]"
# Expected: NO OUTPUT

# Check email inbox
# Expected: Alert within 2-4 seconds
```

### Test 2: Service Health

```bash
# Check watcher service
systemctl status usb-device-watcher.service
# Expected: active (running)

# Check logs
journalctl -u usb-device-watcher.service -n 20
# Expected: Shows "USB Device Watcher v3.0.0 started"

# Check state file
ls -la /var/lib/usb-defense/usb-devices.state
# Expected: File exists, updated recently
```

### Test 3: Bypass Attempt (Advanced)

```bash
# Simulate attacker loading usb-storage module
sudo modprobe usb-storage

# Check if module loaded
lsmod | grep usb_storage
# Expected: Module IS loaded

# Check audit log
sudo ausearch -k usb_module_loading | tail -5
# Expected: Shows modprobe execution

# Wait 10 minutes for timer to run
# Expected: Email alert about bypass attempt

# Cleanup
sudo modprobe -r usb-storage
```

---

## Verification

### Complete System Check

```bash
# Layer 1: Kernel blacklist
cat /etc/modprobe.d/blacklist-usb-storage.conf
lsmod | grep usb_storage  # Should be empty

# Layer 2: USB watcher
systemctl status usb-device-watcher.service  # Should be active
ls -la /var/lib/usb-defense/  # Should exist

# Layer 3: auditd
systemctl status check-usb-activity.timer  # Should be active
sudo auditctl -l | grep usb_ | wc -l  # Should show 7
```

### Service Logs

```bash
# USB watcher logs
journalctl -u usb-device-watcher.service -f

# Timer logs
journalctl -u check-usb-activity.service -n 50

# auditd logs
sudo ausearch -k usb_device_activity -i | tail -20
```

---

## Next Steps

1. **Customize alerts**: Configure email recipient and cooldown
2. **Monitor logs**: Review logs weekly for suspicious activity
3. **Test regularly**: Plug in USB device monthly to verify system works
4. **Document**: Add to runbooks and incident response procedures

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues.
