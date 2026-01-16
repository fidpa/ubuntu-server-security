# Security Log Monitor - Setup Guide

Complete installation and configuration guide for security-log-monitor.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Telegram Configuration](#telegram-configuration)
4. [systemd Setup](#systemd-setup)
5. [Verification](#verification)
6. [Optional Components](#optional-components)

---

## Prerequisites

### Required Dependencies

1. **bash-production-toolkit**

```bash
# Install bash-production-toolkit
git clone https://github.com/fidpa/bash-production-toolkit.git
cd bash-production-toolkit
sudo make install

# Verify installation
ls -la /usr/local/lib/bash-production-toolkit/src/
```

2. **systemd** (included in Ubuntu 22.04+)

```bash
systemctl --version
```

3. **journalctl** (included in systemd)

```bash
journalctl --version
```

### Optional Dependencies

Install the security tools you want to monitor:

```bash
# AIDE (file integrity monitoring)
sudo apt install aide aide-common

# rkhunter (rootkit detection)
sudo apt install rkhunter

# auditd (kernel auditing)
sudo apt install auditd audispd-plugins
```

---

## Installation

### 1. Deploy Script

```bash
# Copy script to /usr/local/bin
sudo cp security-monitoring/scripts/security-log-monitor.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/security-log-monitor.sh

# Verify
/usr/local/bin/security-log-monitor.sh --dry-run
```

### 2. Create State Directory

```bash
# Create state directory (systemd will do this automatically, but manual works too)
sudo mkdir -p /var/lib/security-monitoring
sudo chown root:root /var/lib/security-monitoring
sudo chmod 755 /var/lib/security-monitoring
```

---

## Telegram Configuration

### Option 1: Simple Configuration (Environment Variables)

Create `/etc/default/security-log-monitor`:

```bash
sudo nano /etc/default/security-log-monitor
```

Add the following:

```bash
# Telegram Bot Configuration
TELEGRAM_BOT_TOKEN="1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
TELEGRAM_CHAT_ID="-1001234567890"

# Optional: Customize alert prefix
TELEGRAM_PREFIX="[🔐 MyServer]"

# Optional: Adjust thresholds
SSH_FAILURE_THRESHOLD=10
UFW_BLOCK_THRESHOLD=20
```

### Option 2: Vaultwarden Integration

If you use Vaultwarden/Bitwarden for credential management:

1. Store Telegram Bot Token in Vaultwarden as Secure Note named "Telegram Bot Token"
2. Store Chat ID in `/etc/default/security-log-monitor`:

```bash
TELEGRAM_CHAT_ID="-1001234567890"
```

The script will automatically use `bash-production-toolkit`'s Vaultwarden integration.

### How to Get Telegram Credentials

1. **Create Bot**: Message [@BotFather](https://t.me/botfather) on Telegram
   - Send `/newbot`
   - Follow prompts to get your `TELEGRAM_BOT_TOKEN`

2. **Get Chat ID**:
   - Add bot to your group/channel
   - Send a message to the group
   - Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Look for `"chat":{"id":-1234567890}` in the response

---

## systemd Setup

### 1. Deploy systemd Units

```bash
# Copy service and timer
sudo cp security-monitoring/systemd/security-log-monitor.service.template \
    /etc/systemd/system/security-log-monitor.service

sudo cp security-monitoring/systemd/security-log-monitor.timer.template \
    /etc/systemd/system/security-log-monitor.timer

# Reload systemd
sudo systemctl daemon-reload
```

### 2. Enable Timer

```bash
# Enable timer (starts automatically on boot)
sudo systemctl enable security-log-monitor.timer

# Start timer immediately
sudo systemctl start security-log-monitor.timer
```

### 3. Optional: Adjust Timer Schedule

Edit `/etc/systemd/system/security-log-monitor.timer` to change interval:

```ini
[Timer]
# Run every 30 minutes instead of 15
OnCalendar=*:0/30
```

Then reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart security-log-monitor.timer
```

---

## Verification

### Check Timer Status

```bash
# Verify timer is active
sudo systemctl status security-log-monitor.timer

# List timers
sudo systemctl list-timers security-log-monitor.timer
```

Expected output:
```
● security-log-monitor.timer - Security Log Monitor Timer
     Loaded: loaded (/etc/systemd/system/security-log-monitor.timer; enabled)
     Active: active (waiting) since Wed 2026-01-15 10:00:00 CET; 1min ago
    Trigger: Wed 2026-01-15 10:15:00 CET; 13min left
```

### Run Manual Test

```bash
# Test script with dry-run
sudo /usr/local/bin/security-log-monitor.sh --dry-run

# Run actual check
sudo systemctl start security-log-monitor.service

# View logs
sudo journalctl -u security-log-monitor.service -n 50
```

### Expected Log Output

```
Jan 15 10:00:00 myserver systemd[1]: Starting Security Log Monitor...
Jan 15 10:00:00 myserver security-log-monitor.sh[12345]: ====================================================
Jan 15 10:00:00 myserver security-log-monitor.sh[12345]: Security Log Monitor v1.3.0 starting...
Jan 15 10:00:00 myserver security-log-monitor.sh[12345]: Hostname: myserver.example.com
Jan 15 10:00:00 myserver security-log-monitor.sh[12345]: Check interval: 15 minutes
Jan 15 10:00:00 myserver security-log-monitor.sh[12345]: ====================================================
Jan 15 10:00:01 myserver security-log-monitor.sh[12345]: Checking fail2ban events...
Jan 15 10:00:01 myserver security-log-monitor.sh[12345]: fail2ban: No new bans detected
Jan 15 10:00:01 myserver security-log-monitor.sh[12345]: Checking SSH failed login attempts...
Jan 15 10:00:01 myserver security-log-monitor.sh[12345]: SSH: 3 failures (below threshold of 5)
...
Jan 15 10:00:02 myserver security-log-monitor.sh[12345]: No new security events to report
Jan 15 10:00:02 myserver security-log-monitor.sh[12345]: ====================================================
Jan 15 10:00:02 myserver security-log-monitor.sh[12345]: Security Log Monitor completed successfully
Jan 15 10:00:02 myserver security-log-monitor.sh[12345]: ====================================================
Jan 15 10:00:02 myserver systemd[1]: security-log-monitor.service: Succeeded.
```

### Test Telegram Alerting

Generate a test event to trigger an alert:

```bash
# Trigger fail2ban ban (will reverse immediately)
sudo fail2ban-client set sshd banip 1.2.3.4
sleep 2
sudo fail2ban-client set sshd unbanip 1.2.3.4

# Run monitor
sudo systemctl start security-log-monitor.service

# Check for Telegram message
```

You should receive a Telegram alert like:
```
🔐 Security Alert

🚨 fail2ban: 1 new ban(s)
• 1.2.3.4
```

---

## Optional Components

### Enable Additional Security Tools

#### AIDE (File Integrity Monitoring)

```bash
# Install AIDE
sudo apt install aide aide-common

# Initialize database
sudo aideinit

# Enable daily checks
sudo systemctl enable --now aide-update.timer
```

#### rkhunter (Rootkit Detection)

```bash
# Install rkhunter
sudo apt install rkhunter

# Update database
sudo rkhunter --propupd

# Enable daily scans
sudo systemctl enable --now rkhunter.timer
```

#### auditd (Kernel Auditing)

```bash
# Install auditd
sudo apt install auditd audispd-plugins

# Enable service
sudo systemctl enable --now auditd

# Verify
sudo auditctl -l
```

---

## Next Steps

- [Configuration Guide](CONFIGURATION.md) - Customize thresholds and behavior
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Common issues and solutions
- [Main README](../README.md) - Component overview

---

**Last Updated**: 15. Januar 2026
