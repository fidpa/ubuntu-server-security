# USB Defense System - Alert Configuration

Complete guide to configuring email alerts for USB detection.

## Table of Contents

- [Email Methods](#email-methods)
- [Configuration Options](#configuration-options)
- [Testing Alerts](#testing-alerts)
- [Alert Customization](#alert-customization)
- [Troubleshooting](#troubleshooting)

---

## Email Methods

USB Defense supports two email methods (automatically detected):

### Method 1: mail Command (Simplest)

**Installation:**
```bash
sudo apt install mailutils
```

**Configuration:**
Usually works out-of-the-box with local mail delivery to root.

**Test:**
```bash
echo "Test message" | mail -s "Test Subject" root
```

**Pros:**
- Zero configuration
- Works immediately
- Local delivery to root user

**Cons:**
- May not reach external email addresses
- Depends on system mail configuration

### Method 2: msmtp (Recommended for Production)

**Installation:**
```bash
sudo apt install msmtp msmtp-mta
```

**Configuration:**

Create `/etc/msmtprc`:
```bash
sudo tee /etc/msmtprc <<EOF
# Default account
account default

# SMTP server
host smtp.example.com
port 587

# Credentials
from alerts@example.com
user alerts@example.com
password your-secure-password

# Security
auth on
tls on
tls_starttls on

# Logging
logfile /var/log/msmtp.log
EOF

# Set permissions (important!)
sudo chmod 600 /etc/msmtprc
```

**Gmail Example:**
```bash
account default
host smtp.gmail.com
port 587
from your-email@gmail.com
user your-email@gmail.com
password your-app-specific-password
auth on
tls on
tls_starttls on
logfile /var/log/msmtp.log
```

**Note:** For Gmail, create an App-Specific Password:
1. Go to https://myaccount.google.com/apppasswords
2. Generate new password for "Mail"
3. Use this password (not your regular Gmail password)

**Test:**
```bash
echo "Test from msmtp" | msmtp your-email@example.com
```

**Check logs:**
```bash
sudo tail -f /var/log/msmtp.log
```

---

## Configuration Options

### Environment Variables

Configure via systemd service environment:

```bash
sudo systemctl edit usb-device-watcher.service
```

Add:
```ini
[Service]
# Alert recipient (default: root)
Environment="USB_DEFENSE_ALERT_EMAIL=security@example.com"

# Alert cooldown in seconds (default: 3600 = 1 hour)
Environment="USB_DEFENSE_COOLDOWN=3600"

# Polling interval in seconds (default: 2)
Environment="USB_DEFENSE_POLL_INTERVAL=2"

# Warmup cycles (default: 5 = 10 seconds)
Environment="USB_DEFENSE_WARMUP_CYCLES=5"
```

**Apply changes:**
```bash
sudo systemctl daemon-reload
sudo systemctl restart usb-device-watcher.service
```

### Per-Script Configuration

Alternatively, export variables in shell:

```bash
# Set alert recipient
export USB_DEFENSE_ALERT_EMAIL="admin@example.com"

# Run script manually
sudo -E /usr/local/bin/usb-device-watcher.sh
```

### Multiple Recipients

**Method 1: msmtp aliases**

Edit `/etc/msmtprc`:
```bash
# Add aliases file
aliases /etc/aliases
```

Create `/etc/aliases`:
```bash
root: security@example.com, admin@example.com, oncall@example.com
```

**Method 2: mail command**

```bash
# Comma-separated list
echo "Alert" | mail -s "USB Alert" security@example.com,admin@example.com
```

**Method 3: Script modification**

Edit `/usr/local/bin/usb-device-watcher.sh`:
```bash
readonly ALERT_EMAIL="${USB_DEFENSE_ALERT_EMAIL:-root,security@example.com}"
```

---

## Testing Alerts

### Test 1: Script Direct Execution

```bash
# Temporarily enable short cooldown for testing
export USB_DEFENSE_COOLDOWN=10
export USB_DEFENSE_ALERT_EMAIL="your-email@example.com"

# Run script in foreground (Ctrl+C to stop)
sudo -E /usr/local/bin/usb-device-watcher.sh
```

Then plug in USB device and check email inbox.

### Test 2: Service Execution

```bash
# Stop service
sudo systemctl stop usb-device-watcher.service

# Configure test email
sudo systemctl edit usb-device-watcher.service
# Add: Environment="USB_DEFENSE_ALERT_EMAIL=your-email@example.com"
# Add: Environment="USB_DEFENSE_COOLDOWN=10"

# Restart
sudo systemctl daemon-reload
sudo systemctl start usb-device-watcher.service

# Watch logs
journalctl -u usb-device-watcher.service -f
```

Plug in USB device and verify email received.

### Test 3: Manual Email Test

```bash
# Test mail command
echo "Manual test" | mail -s "USB Defense Test" your-email@example.com

# Test msmtp
echo "Manual test" | msmtp your-email@example.com

# Check logs
sudo journalctl -u usb-device-watcher.service -n 50
```

---

## Alert Customization

### Alert Frequency

**Default**: 1 alert per device per hour

**Increase frequency (more alerts):**
```bash
# 5 minutes cooldown
Environment="USB_DEFENSE_COOLDOWN=300"
```

**Decrease frequency (fewer alerts):**
```bash
# 24 hours cooldown
Environment="USB_DEFENSE_COOLDOWN=86400"
```

### Alert Content

Edit `/usr/local/bin/usb-device-watcher.sh` to customize HTML email format.

**Example: Add custom header:**
```bash
# Around line 265
local message="<div style='font-family: monospace;'>"
message+="<h2>COMPANY NAME - USB SECURITY ALERT</h2>"
message+="<div style='margin-bottom: 20px;'>"
...
```

**Example: Add custom footer:**
```bash
# Around line 313
message+="</div>"
message+="<p>This is an automated alert from USB Defense System</p>"
message+="<p>If you recognize this device, no action needed.</p>"
```

### Subject Line Customization

Edit `/usr/local/bin/usb-device-watcher.sh`:
```bash
# Around line 318
send_usb_alert "[SECURITY] USB Device Detected - $(hostname)" "$message"
```

---

## Integration with External Systems

### Slack Notifications

Install webhook support:
```bash
sudo apt install curl
```

Edit `/usr/local/bin/usb-device-watcher.sh`, add after email alert:
```bash
# Send to Slack
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -H 'Content-Type: application/json' \
  -d "{\"text\":\"USB Device Detected: $full_info\"}"
```

### Telegram Notifications

```bash
# Install telegram-send
sudo apt install python3-pip
sudo pip3 install telegram-send

# Configure
telegram-send --configure

# Add to script
telegram-send "USB Device Detected: $full_info"
```

### Syslog Integration

```bash
# Add to script
logger -t usb-defense -p security.warning "USB Device Detected: $full_info"
```

View in syslog:
```bash
grep usb-defense /var/log/syslog
```

---

## Troubleshooting

### Problem: No emails received

**Diagnosis:**
```bash
# Check service logs
journalctl -u usb-device-watcher.service | grep -E "Sending alert|Alert sent"

# Check mail logs
sudo tail -f /var/log/mail.log
sudo tail -f /var/log/msmtp.log
```

**Common fixes:**
1. Verify mail command works: `echo "Test" | mail -s "Test" root`
2. Check email configuration: `cat /etc/msmtprc`
3. Verify permissions: `ls -la /etc/msmtprc` (should be 600)

### Problem: Too many alerts

**Diagnosis:**
```bash
# Check cooldown files
ls -la /var/lib/usb-defense/usb-alert-cooldown.*

# Check recent alerts
journalctl -u usb-device-watcher.service | grep "Sending alert"
```

**Fix:**
Increase cooldown period (see Configuration Options above).

### Problem: Alerts delayed

**Diagnosis:**
```bash
# Check polling interval
journalctl -u usb-device-watcher.service | grep "interval:"
```

**Fix:**
Reduce polling interval (default is 2s, already fast).

---

## Best Practices

1. **Test email configuration** before deploying to production
2. **Use dedicated alert email** (not personal inbox)
3. **Configure email filtering** to prioritize USB alerts
4. **Document response procedure** for USB alerts
5. **Review alerts weekly** to tune false positives
6. **Keep cooldown at 1 hour** (prevents alert fatigue)

---

## See Also

- [SETUP.md](SETUP.md) - Installation guide
- [THREE_LAYER_DEFENSE.md](THREE_LAYER_DEFENSE.md) - Architecture details
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
