# Security Log Monitor - Troubleshooting Guide

Common issues and their solutions.

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Telegram Alerting Issues](#telegram-alerting-issues)
3. [Component-Specific Issues](#component-specific-issues)
4. [Performance Issues](#performance-issues)
5. [State Management Issues](#state-management-issues)

---

## Installation Issues

### bash-production-toolkit Not Found

**Error**:
```
FATAL: Failed to load logging.sh from bash-production-toolkit
```

**Solution**:
```bash
# Check if toolkit is installed
ls -la /usr/local/lib/bash-production-toolkit/

# If missing, install it
git clone https://github.com/fidpa/bash-production-toolkit.git
cd bash-production-toolkit
sudo make install
```

**Alternative**: Set custom path in `/etc/default/security-log-monitor`:
```bash
BASH_TOOLKIT_PATH="/opt/bash-production-toolkit"
```

### Permission Denied Errors

**Error**:
```
mkdir: cannot create directory '/var/lib/security-monitoring': Permission denied
```

**Solution**:
```bash
# Run as root
sudo /usr/local/bin/security-log-monitor.sh

# Or ensure systemd service runs as root
sudo systemctl cat security-log-monitor.service | grep User=
# Should show: User=root
```

---

## Telegram Alerting Issues

### No Alerts Received

**Check 1**: Verify Telegram credentials

```bash
# Test telegram API directly
BOT_TOKEN="your-bot-token"
CHAT_ID="your-chat-id"
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=Test from security-log-monitor"
```

Expected response: `{"ok":true,...}`

**Check 2**: Verify credentials are loaded

```bash
# Check environment file
cat /etc/default/security-log-monitor

# Run dry-run to see if credentials are picked up
sudo /usr/local/bin/security-log-monitor.sh --dry-run
```

**Check 3**: Check logs for errors

```bash
sudo journalctl -u security-log-monitor.service -n 100 | grep -i telegram
```

### Rate Limiting

**Symptom**: Alerts stop after first one, even with new events

**Cause**: Rate limiting is working as designed

**Solution**:

```bash
# Option 1: Wait for rate limit to expire (default: 30 minutes)
# Option 2: Reset rate limit state
sudo rm -f /var/lib/security-monitoring/.last_alert_*

# Option 3: Adjust rate limit in config
# /etc/default/security-log-monitor
RATE_LIMIT_SECONDS=300  # 5 minutes
```

### "Failed to load Telegram config"

**Error in logs**:
```
Failed to load Telegram config - alert will not be sent
```

**Solution**:

Check if bash-production-toolkit can access Telegram credentials:

```bash
# If using Vaultwarden
bw get notes "Telegram Bot Token"

# If using environment variables
grep TELEGRAM /etc/default/security-log-monitor
```

---

## Component-Specific Issues

### fail2ban: No Events Detected

**Issue**: fail2ban is running but script reports no events

**Check**:
```bash
# Verify fail2ban is active
sudo systemctl status fail2ban

# Check recent bans manually
sudo journalctl -u fail2ban --since "15 minutes ago" | grep "Ban "

# Test fail2ban detection
sudo fail2ban-client set sshd banip 1.2.3.4
sudo systemctl start security-log-monitor.service
sudo fail2ban-client set sshd unbanip 1.2.3.4
```

### SSH: Failures Below Threshold

**Issue**: SSH attacks happening but no alerts

**Cause**: Threshold not exceeded (default: 5 failures)

**Solution**:

Lower threshold in `/etc/default/security-log-monitor`:
```bash
SSH_FAILURE_THRESHOLD=3
```

Or check actual failure count:
```bash
sudo journalctl -u sshd --since "15 minutes ago" | grep -iE "Failed password|Invalid user" | wc -l
```

### UFW: No Blocks Detected

**Issue**: UFW is blocking IPs but script doesn't detect them

**Check**:
```bash
# Verify UFW is active
sudo ufw status

# Check kernel logs for UFW blocks
sudo journalctl -k --since "15 minutes ago" | grep "UFW BLOCK"

# Trigger test block
# (from another machine, or use nc to trigger)
```

**Note**: Only **external** IPs trigger alerts (private ranges filtered out)

### auditd: Check Skipped

**Issue**: "ausearch not available" or "requires root"

**Solution**:
```bash
# Install auditd
sudo apt install auditd audispd-plugins

# Enable auditd
sudo systemctl enable --now auditd

# Verify ausearch works
sudo ausearch -m avc -ts recent
```

### AIDE: No Runs Detected

**Issue**: AIDE installed but no alerts

**Check**:
```bash
# Verify AIDE timer is active
sudo systemctl status aide-update.timer

# Check last run
sudo journalctl -u aide-update --since "24 hours ago"

# Manually trigger AIDE
sudo systemctl start aide-update.service
```

### rkhunter: Log Not Found

**Issue**: "rkhunter: Log not found, skipping"

**Solution**:
```bash
# Install rkhunter
sudo apt install rkhunter

# Initialize database
sudo rkhunter --propupd

# Run scan
sudo rkhunter --check --skip-keypress

# Verify log exists
ls -la /var/log/rkhunter.log
```

---

## Performance Issues

### Script Takes Too Long

**Symptom**: Script execution exceeds 10 seconds

**Check**:
```bash
# Time script execution
time sudo /usr/local/bin/security-log-monitor.sh --dry-run

# Check which components are slow
sudo journalctl -u security-log-monitor.service -n 100 | grep "Checking"
```

**Solution**:

Disable slow components by commenting them out in script:

```bash
# Edit script
sudo nano /usr/local/bin/security-log-monitor.sh

# Comment out slow checks
# check_audit_events || log_warn "auditd check failed"
# check_rkhunter_events || log_warn "rkhunter check failed"
```

### High CPU Usage

**Symptom**: `security-log-monitor.sh` consumes >50% CPU

**Check**:
```bash
# Monitor CPU during execution
top -p $(pgrep -f security-log-monitor)

# Check if journalctl is slow
time sudo journalctl -u sshd --since "15 minutes ago"
```

**Solution**:

Adjust systemd CPU limits in `/etc/systemd/system/security-log-monitor.service`:
```ini
[Service]
CPUQuota=25%
```

---

## State Management Issues

### Duplicate Alerts

**Symptom**: Same events trigger alerts multiple times

**Cause**: State files are being reset or not saved properly

**Check**:
```bash
# Verify state files exist
ls -la /var/lib/security-monitoring/

# Check permissions
ls -ld /var/lib/security-monitoring/

# Expected:
# drwxr-xr-x 2 root root 4096 Jan 15 10:00 /var/lib/security-monitoring
```

**Solution**:
```bash
# Ensure state directory is writable
sudo chown root:root /var/lib/security-monitoring/
sudo chmod 755 /var/lib/security-monitoring/

# Clear corrupted state
sudo rm -f /var/lib/security-monitoring/.security-log-monitor_*

# Run again
sudo systemctl start security-log-monitor.service
```

### No Alerts Ever

**Symptom**: Events are happening but no alerts are ever sent

**Cause**: State files might contain stale data

**Solution**:
```bash
# Reset all state
sudo rm -f /var/lib/security-monitoring/.security-log-monitor_*

# Force immediate alert (bypass rate limit)
sudo rm -f /var/lib/security-monitoring/.last_alert_*

# Run monitor
sudo systemctl start security-log-monitor.service
```

---

## Debugging Steps

### Enable Dry-Run Mode

Test without sending alerts:
```bash
sudo /usr/local/bin/security-log-monitor.sh --dry-run
```

### Check Script Output Directly

```bash
# Run script manually to see full output
sudo /usr/local/bin/security-log-monitor.sh

# Capture output
sudo /usr/local/bin/security-log-monitor.sh 2>&1 | tee /tmp/monitor.log
```

### Enable Debug Logging

In `/etc/default/security-log-monitor`:
```bash
LOG_LEVEL=DEBUG
```

### Verify systemd Service

```bash
# Check service status
sudo systemctl status security-log-monitor.service

# View full logs
sudo journalctl -u security-log-monitor.service --no-pager

# Check timer
sudo systemctl list-timers security-log-monitor.timer
```

---

## Getting Help

If none of these solutions work:

1. **Collect Debug Info**:
```bash
# System info
uname -a
systemctl --version

# Service status
sudo systemctl status security-log-monitor.{service,timer}

# Recent logs
sudo journalctl -u security-log-monitor.service -n 100

# State files
ls -la /var/lib/security-monitoring/

# Configuration
cat /etc/default/security-log-monitor
```

2. **Check Repository Issues**: https://github.com/fidpa/ubuntu-server-security/issues

3. **Review bash-production-toolkit Docs**: https://github.com/fidpa/bash-production-toolkit

---

## Next Steps

- [Configuration Guide](CONFIGURATION.md) - Adjust thresholds and behavior
- [Setup Guide](SETUP.md) - Re-install if needed
- [Main README](../README.md) - Component overview

---

**Last Updated**: 15. Januar 2026
