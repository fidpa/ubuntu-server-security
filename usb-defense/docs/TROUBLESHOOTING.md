# USB Defense System - Troubleshooting

Common issues and solutions for the USB defense system.

## Table of Contents

- [Service Not Starting](#service-not-starting)
- [No Email Alerts](#no-email-alerts)
- [USB Still Mountable](#usb-still-mountable)
- [Keyboard/Mouse Not Working](#keyboardmouse-not-working)
- [False Positive Alerts](#false-positive-alerts)
- [High CPU Usage](#high-cpu-usage)
- [auditd Rules Not Loading](#auditd-rules-not-loading)

---

## Service Not Starting

### Symptom
```bash
systemctl status usb-device-watcher.service
# Output: failed (code=exited, status=1)
```

### Diagnosis
```bash
journalctl -u usb-device-watcher.service -n 50
```

### Common Causes

**1. State directory doesn't exist**
```
[ERROR] Cannot create state directory: /var/lib/usb-defense
```

**Fix:**
```bash
sudo mkdir -p /var/lib/usb-defense
sudo chmod 755 /var/lib/usb-defense
sudo systemctl restart usb-device-watcher.service
```

**2. Another instance running**
```
[ERROR] Another instance is already running (lock: /var/lib/usb-defense/usb-device-watcher.lock)
```

**Fix:**
```bash
sudo rm /var/lib/usb-defense/usb-device-watcher.lock
sudo systemctl restart usb-device-watcher.service
```

**3. lsusb command not found**
```
[ERROR] Cannot get initial USB devices
```

**Fix:**
```bash
sudo apt install usbutils
sudo systemctl restart usb-device-watcher.service
```

---

## No Email Alerts

### Symptom
USB device detected but no email received.

### Diagnosis
```bash
# Check if alerts are being generated
journalctl -u usb-device-watcher.service | grep "Sending alert"

# Test mail command
echo "Test" | mail -s "Test" root
```

### Common Causes

**1. No mail command available**
```
[WARNING] No mail command available - alert logged only
```

**Fix - Option 1 (mail command):**
```bash
sudo apt install mailutils
echo "Test" | mail -s "Test" root
```

**Fix - Option 2 (msmtp):**
```bash
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
EOF

sudo chmod 600 /etc/msmtprc
echo "Test" | msmtp root
```

**2. Alert in cooldown**
```
[INFO] Device in cooldown (45s < 3600s), skipping alert
```

This is expected behavior. Wait 1 hour or reduce cooldown:
```bash
sudo systemctl edit usb-device-watcher.service
# Add: Environment="USB_DEFENSE_COOLDOWN=300"
sudo systemctl restart usb-device-watcher.service
```

**3. Device filtered (HID)**
```
[INFO] Filtered: HID device or Hub (USB class 03/09)
```

This is correct - keyboards/mice should be filtered.

---

## USB Still Mountable

### Symptom
```bash
lsblk
# Shows: sdb (USB device)
```

### Diagnosis
```bash
# Check if usb-storage module loaded
lsmod | grep usb_storage

# Check blacklist file
cat /etc/modprobe.d/blacklist-usb-storage.conf
```

### Common Causes

**1. Wrong blacklist syntax**
```
# BAD (insufficient for hotplug)
blacklist usb-storage

# GOOD (blocks all loading attempts)
install usb-storage /bin/false
```

**Fix:**
```bash
sudo tee /etc/modprobe.d/blacklist-usb-storage.conf <<'EOF'
install usb-storage /bin/false
install uas /bin/false
EOF

sudo rmmod usb_storage
sudo update-initramfs -u
```

**2. Module loaded before blacklist**
```bash
# Check when module was loaded
systemctl status systemd-modules-load.service
```

**Fix:**
```bash
sudo rmmod usb_storage
# Unplug and replug USB device
```

**3. Blacklist not boot-persistent**

**Fix:**
```bash
sudo update-initramfs -u
sudo reboot
```

---

## Keyboard/Mouse Not Working

### Symptom
Keyboard/mouse stops working after deployment.

### Diagnosis
```bash
lsmod | grep -E "usbhid|usb_storage"
# Expected: usbhid is loaded, usb_storage is NOT
```

### Fix

**Keyboards/mice use `usbhid`, NOT `usb-storage`.**

If truly affected:
```bash
# Boot from Live USB
# Mount root filesystem
sudo mount /dev/vg0/root /mnt

# Remove blacklist
sudo rm /mnt/etc/modprobe.d/blacklist-usb-storage.conf

# Rebuild initramfs
sudo chroot /mnt update-initramfs -u

# Reboot
sudo reboot
```

---

## False Positive Alerts

### Symptom
Receiving alerts for legitimate devices (keyboards, internal hubs).

### Diagnosis
```bash
# Check what triggered alert
journalctl -u usb-device-watcher.service | grep "New USB device"
```

### Common Causes

**1. HID filtering not working**

Check USB class via sysfs:
```bash
# Find device
lsusb
# Example: Bus 002 Device 005: ID 046d:c534

# Check interface class
cat /sys/bus/usb/devices/2-1/*/bInterfaceClass
# 03 = HID (should be filtered)
```

**2. Device misidentified**

Some devices report multiple interfaces. Check script logic:
```bash
# View full device info
lsusb -v -s 002:005 | grep bInterfaceClass
```

**Fix - Whitelist specific device:**
Edit `/usr/local/bin/usb-device-watcher.sh`:
```bash
# Add after line with VID:PID extraction
if [[ "$vidpid" == "046d:c534" ]]; then
    log_info "Filtered: Whitelisted device (Logitech Mouse)"
    return 0
fi
```

Restart:
```bash
sudo systemctl restart usb-device-watcher.service
```

---

## High CPU Usage

### Symptom
```bash
top
# usb-device-watcher.sh using >5% CPU
```

### Diagnosis
```bash
# Check polling interval
journalctl -u usb-device-watcher.service | grep "interval:"

# Check state file size
ls -lh /var/lib/usb-defense/usb-devices.state
```

### Fix

**Increase polling interval:**
```bash
sudo systemctl edit usb-device-watcher.service
```

Add:
```ini
[Service]
Environment="USB_DEFENSE_POLL_INTERVAL=5"
```

Restart:
```bash
sudo systemctl restart usb-device-watcher.service
```

**Expected CPU usage:**
- 2s interval: ~1% CPU
- 5s interval: ~0.5% CPU
- 10s interval: ~0.2% CPU

---

## auditd Rules Not Loading

### Symptom
```bash
sudo auditctl -l | grep usb_
# No output
```

### Diagnosis
```bash
# Check if auditd running
systemctl status auditd

# Check rules file exists
ls -la /etc/audit/rules.d/99-usb-defense.rules

# Check audit.log
sudo ausearch -k usb_device_activity -i
```

### Fix

**1. auditd not running:**
```bash
sudo systemctl start auditd
sudo systemctl enable auditd
```

**2. Rules file missing:**
```bash
sudo cp configs/99-usb-defense.rules /etc/audit/rules.d/
sudo chmod 644 /etc/audit/rules.d/99-usb-defense.rules
```

**3. Rules not loaded:**
```bash
# Reload rules
sudo augenrules --load

# Or restart auditd
sudo systemctl restart auditd

# Verify
sudo auditctl -l | grep usb_ | wc -l
# Expected: 7
```

---

## Rollback Issues

### Symptom
USB still not working after rollback.

### Diagnosis
```bash
# Check if blacklist removed
ls /etc/modprobe.d/blacklist-usb-storage.conf

# Check if module can load
sudo modprobe usb-storage
lsmod | grep usb_storage
```

### Fix

**Complete rollback:**
```bash
# Remove all components
sudo ./scripts/deploy-usb-defense.sh --rollback

# Force reload module
sudo modprobe usb-storage

# Reboot if still not working
sudo reboot
```

---

## Getting Help

If issue persists:

1. **Collect diagnostics:**
```bash
# Create debug report
cat > /tmp/usb-defense-debug.txt <<EOF
=== System Info ===
$(uname -a)

=== Service Status ===
$(systemctl status usb-device-watcher.service)

=== Recent Logs ===
$(journalctl -u usb-device-watcher.service -n 100)

=== USB Devices ===
$(lsusb)

=== Kernel Modules ===
$(lsmod | grep usb)

=== auditd Rules ===
$(sudo auditctl -l | grep usb_)

=== Blacklist File ===
$(cat /etc/modprobe.d/blacklist-usb-storage.conf)
EOF
```

2. **Open issue**: https://github.com/fidpa/ubuntu-server-security/issues
3. **Attach**: `/tmp/usb-defense-debug.txt`

---

## See Also

- [SETUP.md](SETUP.md) - Installation guide
- [THREE_LAYER_DEFENSE.md](THREE_LAYER_DEFENSE.md) - Architecture details
- [ALERT_CONFIGURATION.md](ALERT_CONFIGURATION.md) - Email setup
