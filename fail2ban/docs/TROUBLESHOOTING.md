# fail2ban Troubleshooting Guide

Common issues and solutions for fail2ban configuration and operation.

## fail2ban Service Issues

### Problem: fail2ban won't start

**Symptoms**:
```bash
sudo systemctl status fail2ban
# Status: failed
```

**Check logs**:
```bash
sudo journalctl -u fail2ban -n 50 --no-pager

# Look for error messages:
# - "ERROR: Invalid configuration"
# - "ERROR: Unable to read filter"
# - "ERROR: Socket file not found"
```

**Solutions**:

1. **Configuration syntax error**:
   ```bash
   sudo fail2ban-client --test
   # This will show detailed syntax errors
   ```

2. **Permission issues**:
   ```bash
   sudo chmod 755 /etc/fail2ban
   sudo chmod 644 /etc/fail2ban/*.conf
   sudo chmod 644 /etc/fail2ban/jail.d/*.conf
   ```

3. **Socket file issues**:
   ```bash
   sudo rm /var/run/fail2ban/fail2ban.sock
   sudo systemctl restart fail2ban
   ```

### Problem: fail2ban crashes after starting

**Check**:
```bash
sudo journalctl -u fail2ban -f
# Watch for repeated crashes
```

**Common causes**:
1. **Invalid filter regex**: Check filter.d/*.conf files
2. **Missing log files**: Check logpath in jail configuration
3. **Permission issues**: fail2ban needs read access to log files

**Solution**:
```bash
# Test each jail individually
sudo fail2ban-client start
sudo fail2ban-client status

# Add jails one by one to identify problematic jail
```

## Jail Configuration Issues

### Problem: Jails not loading

**Check active jails**:
```bash
sudo fail2ban-client status

# Expected output should list jails:
# Jail list: sshd, nginx-http-auth
```

**Solution**:

1. **Verify jail files exist**:
   ```bash
   ls /etc/fail2ban/jail.d/*.conf
   ```

2. **Check jail syntax**:
   ```bash
   sudo fail2ban-client --test 2>&1 | grep ERROR
   ```

3. **Verify enabled = true**:
   ```bash
   grep "enabled" /etc/fail2ban/jail.d/*.conf
   # All jails should have: enabled = true
   ```

### Problem: Jail enabled but not banning IPs

**Check jail status**:
```bash
sudo fail2ban-client status sshd

# Look for:
# - Currently failed: 0 (should increase with failed attempts)
# - Total failed: 0 (should increase over time)
```

**Solutions**:

1. **Wrong log file**:
   ```bash
   # Check if logpath exists and is readable
   sudo ls -la /var/log/auth.log
   sudo tail -f /var/log/auth.log
   ```

2. **Backend mismatch**:
   ```bash
   # Ensure backend = systemd for modern systems
   grep "backend" /etc/fail2ban/jail.d/10-sshd.conf
   # Should be: backend = systemd
   ```

3. **Filter not matching**:
   ```bash
   # Test filter against log file
   sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf

   # Expected: "Lines: X lines, X ignored, X matched"
   # If 0 matched → filter regex is wrong
   ```

### Problem: Too many false positives (legitimate users banned)

**Check ban list**:
```bash
sudo fail2ban-client status sshd
# Review "Banned IP list"
```

**Solutions**:

1. **Add to whitelist**:
   ```bash
   sudo nano /etc/fail2ban/fail2ban.local

   # Add trusted IPs (space or comma separated)
   ignoreip = 127.0.0.1/8 ::1 10.0.0.0/24 192.168.1.0/24
   ```

2. **Increase maxretry**:
   ```bash
   sudo nano /etc/fail2ban/jail.d/10-sshd.conf

   # Change from:
   maxretry = 3

   # To:
   maxretry = 5
   ```

3. **Increase findtime**:
   ```bash
   # Allow more time before resetting failure count
   findtime = 1800  # 30 minutes instead of 10
   ```

## GeoIP Issues

### Problem: geoiplookup not found

**Error**:
```
/usr/local/bin/geoip-whitelist.sh: line 50: geoiplookup: command not found
```

**Solution**:
```bash
sudo apt update
sudo apt install geoip-bin geoip-database

# Verify installation
geoiplookup 8.8.8.8
# Expected: GeoIP Country Edition: US, United States
```

### Problem: GeoIP whitelisted country is banned

**Debug**:
```bash
# Test manual lookup
geoiplookup <ip_address>

# Check whitelist regex
grep WHITELIST_COUNTRIES /usr/local/bin/geoip-whitelist.sh

# Test script directly
/usr/local/bin/geoip-whitelist.sh <ip_address>
echo $?  # 0 = allow, 1 = ban
```

**Solutions**:

1. **Country code mismatch**:
   ```bash
   # Edit whitelist (add missing country code)
   sudo nano /usr/local/bin/geoip-whitelist.sh

   # Example: Add US to whitelist
   readonly WHITELIST_COUNTRIES="${GEOIP_WHITELIST:-DE|AT|CH|NL|FR|BE|LU|US}"
   ```

2. **GeoIP database outdated**:
   ```bash
   sudo apt update
   sudo apt install --reinstall geoip-database
   ```

### Problem: Private IPs are banned

**Check**:
```bash
# Private IPs should always be whitelisted
/usr/local/bin/geoip-whitelist.sh 10.0.0.1
echo $?  # Should be 0
```

**Solution**:
```bash
# Add to fail2ban whitelist
sudo nano /etc/fail2ban/fail2ban.local

ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 192.168.0.0/16 172.16.0.0/12
```

## Telegram Issues

### Problem: No Telegram messages received

**Check secrets**:
```bash
sudo cat /etc/$(hostname -s)/.env.secrets

# Verify format:
# TELEGRAM_BOT_TOKEN="123456:ABC-DEF..."
# TELEGRAM_CHAT_ID="123456789"
```

**Test Telegram API**:
```bash
# Replace with your credentials
BOT_TOKEN="your_bot_token"
CHAT_ID="your_chat_id"

curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=Test"

# Expected: {"ok":true,...}
```

**Check curl**:
```bash
# Ensure curl is installed
which curl
# If not found: sudo apt install curl
```

**Check logs**:
```bash
sudo tail -f /var/log/$(hostname -s)/fail2ban-telegram.log

# Look for errors:
# - "Secrets file not found"
# - "Missing Telegram credentials"
# - "Alert failed to send"
```

### Problem: Telegram rate limiting

**Symptoms**: Logs show "Rate-limited" messages

**Check cooldown**:
```bash
grep ALERT_COOLDOWN /etc/fail2ban/action.d/telegram-send.sh
# Default: 300 seconds (5 minutes)
```

**Adjust if needed**:
```bash
sudo nano /etc/fail2ban/action.d/telegram-send.sh

# Change cooldown (line ~43)
readonly ALERT_COOLDOWN=60  # 1 minute (more alerts)
```

## Metrics Issues

### Problem: Metrics not exported

**Check metrics file**:
```bash
cat /var/lib/node_exporter/textfile_collector/fail2ban.prom

# If file doesn't exist:
sudo /usr/local/bin/fail2ban-metrics-exporter.sh
```

**Check timer**:
```bash
systemctl status fail2ban-metrics.timer

# If not active:
sudo systemctl enable --now fail2ban-metrics.timer
```

**Check node_exporter**:
```bash
curl http://localhost:9100/metrics | grep fail2ban

# If no output:
# - Verify node_exporter has textfile collector enabled
# - Check --collector.textfile.directory flag
```

### Problem: Metrics not updating

**Check last export time**:
```bash
ls -la /var/lib/node_exporter/textfile_collector/fail2ban.prom
# Timestamp should be recent

# Check timer last run
sudo journalctl -u fail2ban-metrics.service -n 5
```

**Force manual update**:
```bash
sudo systemctl start fail2ban-metrics.service

# Verify new timestamp
ls -la /var/lib/node_exporter/textfile_collector/fail2ban.prom
```

## General Debugging

### Enable Debug Logging

Edit `/etc/fail2ban/fail2ban.local`:
```ini
[Definition]
loglevel = DEBUG
```

Restart fail2ban:
```bash
sudo systemctl restart fail2ban
sudo journalctl -u fail2ban -f
```

**Warning**: Debug logging is VERY verbose. Disable after troubleshooting.

### Check fail2ban Version

```bash
fail2ban-client --version

# Ensure >= 1.0.2
# If outdated: sudo apt update && sudo apt upgrade fail2ban
```

### Validate Configuration

```bash
# Test configuration syntax
sudo fail2ban-client --test

# Start in debug mode (foreground)
sudo fail2ban-client -x start

# Check specific jail
sudo fail2ban-client get sshd logpath
sudo fail2ban-client get sshd maxretry
```

### Manually Ban/Unban IP (Testing)

```bash
# Manual ban
sudo fail2ban-client set sshd banip 1.2.3.4

# Check ban
sudo fail2ban-client status sshd

# Manual unban
sudo fail2ban-client set sshd unbanip 1.2.3.4
```

## Performance Issues

### Problem: High CPU usage

**Check**:
```bash
top
# Look for fail2ban-server process

ps aux | grep fail2ban
```

**Solutions**:

1. **Too many log files**:
   ```bash
   # Review logpath in jails
   grep "logpath" /etc/fail2ban/jail.d/*.conf

   # Remove unnecessary jails
   ```

2. **Complex regex filters**:
   ```bash
   # Simplify filter.d/*.conf patterns
   # Use anchored regex (^...$) for performance
   ```

3. **Polling backend**:
   ```bash
   # Use systemd backend instead of polling
   sudo nano /etc/fail2ban/fail2ban.local

   backend = systemd  # Not: polling, auto, pyinotify
   ```

## Common Error Messages

### "ERROR: Failed during configuration"

**Cause**: Syntax error in configuration file

**Solution**:
```bash
sudo fail2ban-client --test
# Shows exact file and line number
```

### "ERROR: No file(s) found for glob"

**Cause**: Logpath doesn't exist

**Solution**:
```bash
# Check logpath
grep "logpath" /etc/fail2ban/jail.d/10-sshd.conf

# Verify file exists
ls -la /var/log/auth.log

# If missing: check syslog configuration
```

### "WARNING: Invalid command"

**Cause**: fail2ban-client command syntax error

**Solution**:
```bash
# Check command format
fail2ban-client --help

# Example correct syntax:
fail2ban-client status sshd
```

## Getting Help

If you've tried all solutions above and still have issues:

1. **Check GitHub Issues**: [fidpa/ubuntu-server-security](https://github.com/fidpa/ubuntu-server-security/issues)
2. **Review fail2ban Logs**:
   ```bash
   sudo journalctl -u fail2ban -n 100 --no-pager
   ```
3. **Collect Debug Info**:
   ```bash
   fail2ban-client --version
   uname -a
   cat /etc/os-release
   sudo fail2ban-client --test
   ```

## See Also

- [SETUP.md](SETUP.md) - Installation guide
- [GEOIP_FILTERING.md](GEOIP_FILTERING.md) - GeoIP troubleshooting
- [TELEGRAM_INTEGRATION.md](TELEGRAM_INTEGRATION.md) - Telegram troubleshooting
- [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) - Metrics troubleshooting
- [fail2ban Manual](https://www.fail2ban.org/wiki/index.php/MANUAL_0_8)
