# Security Log Monitor - Configuration Guide

Complete reference for configuring security-log-monitor behavior.

## Configuration Methods

Configuration can be provided via:

1. **Environment Variables** in `/etc/default/security-log-monitor`
2. **systemd Override** in `/etc/systemd/system/security-log-monitor.service.d/override.conf`
3. **Command Line** (for testing)

---

## Environment Variables Reference

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `BASH_TOOLKIT_PATH` | `/usr/local/lib/bash-production-toolkit` | Path to bash-production-toolkit installation |
| `STATE_DIR` | `/var/lib/security-monitoring` | State directory for deduplication files |
| `CHECK_INTERVAL_MIN` | `15` | Check interval in minutes (must match timer) |

### Telegram Alerting

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `TELEGRAM_BOT_TOKEN` | - | ✅ | Telegram Bot API token |
| `TELEGRAM_CHAT_ID` | - | ✅ | Telegram Chat/Group ID |
| `TELEGRAM_PREFIX` | `[Security]` | ❌ | Message prefix (customize per server) |
| `RATE_LIMIT_SECONDS` | `1800` | ❌ | Minimum seconds between alerts (30min) |
| `ENABLE_RECOVERY_ALERTS` | `false` | ❌ | Send alerts when events recover |

### Detection Thresholds

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_FAILURE_THRESHOLD` | `5` | Alert if SSH failures exceed this count |
| `UFW_BLOCK_THRESHOLD` | `10` | Alert if UFW blocks from same IP exceed this |

---

## Configuration Examples

### Basic Configuration

Create `/etc/default/security-log-monitor`:

```bash
# Telegram Credentials (REQUIRED)
TELEGRAM_BOT_TOKEN="1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
TELEGRAM_CHAT_ID="-1001234567890"
```

### Advanced Configuration

```bash
# Telegram Configuration
TELEGRAM_BOT_TOKEN="1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
TELEGRAM_CHAT_ID="-1001234567890"
TELEGRAM_PREFIX="[🔐 Production Server]"

# Increase alert rate limit to 1 hour
RATE_LIMIT_SECONDS=3600

# Lower SSH threshold for stricter monitoring
SSH_FAILURE_THRESHOLD=3

# Raise UFW threshold for noisier networks
UFW_BLOCK_THRESHOLD=50

# Enable recovery alerts (notify when events stop)
ENABLE_RECOVERY_ALERTS=true
```

### Per-Server Customization

For multi-server deployments, customize the prefix:

```bash
# webserver-01
TELEGRAM_PREFIX="[🌐 Web-01]"

# database-01
TELEGRAM_PREFIX="[💾 DB-01]"

# gateway-01
TELEGRAM_PREFIX="[🌍 Gateway]"
```

---

## Threshold Tuning

### SSH Failure Threshold

**Default**: 5 failures

**When to adjust**:
- **Increase (10-20)**: High-traffic SSH servers, development environments
- **Decrease (3)**: Production servers, strict security posture

```bash
# Strict mode
SSH_FAILURE_THRESHOLD=3

# Relaxed mode
SSH_FAILURE_THRESHOLD=15
```

### UFW Block Threshold

**Default**: 10 blocks from same IP

**When to adjust**:
- **Increase (50-100)**: Internet-facing servers with high scan activity
- **Decrease (5)**: Internal networks, low-traffic servers

```bash
# High scan activity
UFW_BLOCK_THRESHOLD=100

# Low traffic
UFW_BLOCK_THRESHOLD=5
```

---

## Alert Rate Limiting

### How It Works

Rate limiting prevents alert fatigue by enforcing a minimum time between alerts for the same event type.

**Default**: 1800 seconds (30 minutes)

**State Files**: `/var/lib/security-monitoring/.last_alert_<type>`

### Adjusting Rate Limits

```bash
# More frequent alerts (10 minutes)
RATE_LIMIT_SECONDS=600

# Less frequent alerts (1 hour)
RATE_LIMIT_SECONDS=3600

# Disable rate limiting (not recommended)
RATE_LIMIT_SECONDS=0
```

### Per-Event-Type Rate Limits

Currently, rate limiting applies globally to all event types. To customize per-event:

1. Fork the script
2. Modify `send_telegram_alert()` function
3. Pass custom rate limits per alert type

---

## State Management

### State Files Location

State files are stored in `$STATE_DIR` (default: `/var/lib/security-monitoring/`):

```
/var/lib/security-monitoring/
├── .security-log-monitor_fail2ban_state
├── .security-log-monitor_ssh_state
├── .security-log-monitor_ufw_state
├── .security-log-monitor_audit_state
├── .security-log-monitor_aide_timestamp_state
├── .security-log-monitor_rkhunter_mtime_state
└── .last_alert_security_events
```

### Reset State (Force Re-Alert)

To reset deduplication and force alerts on next run:

```bash
# Reset all state
sudo rm -f /var/lib/security-monitoring/.security-log-monitor_*

# Reset specific component
sudo rm -f /var/lib/security-monitoring/.security-log-monitor_ssh_state

# Reset rate limit (force immediate alert)
sudo rm -f /var/lib/security-monitoring/.last_alert_*
```

### Backup State Files

For production systems, consider backing up state files:

```bash
# Backup state directory
sudo tar -czf security-monitor-state-$(date +%Y%m%d).tar.gz \
    /var/lib/security-monitoring/

# Restore state
sudo tar -xzf security-monitor-state-20260115.tar.gz -C /
```

---

## systemd Integration

### Override Configuration

Create systemd override file:

```bash
sudo systemctl edit security-log-monitor.service
```

Add custom environment variables:

```ini
[Service]
Environment="SSH_FAILURE_THRESHOLD=10"
Environment="UFW_BLOCK_THRESHOLD=50"
Environment="TELEGRAM_PREFIX=[🔐 Production]"
```

### Memory and CPU Limits

Adjust resource limits in service file:

```ini
[Service]
MemoryMax=512M
CPUQuota=100%
```

### Change Timer Interval

Edit timer file to run every 30 minutes:

```bash
sudo systemctl edit security-log-monitor.timer
```

```ini
[Timer]
OnCalendar=*:0/30
```

---

## Monitoring Multiple Servers

### Centralized Alerting

All servers can send to the same Telegram chat:

```bash
# All servers use same TELEGRAM_CHAT_ID
TELEGRAM_CHAT_ID="-1001234567890"

# Differentiate servers via TELEGRAM_PREFIX
# Server 1
TELEGRAM_PREFIX="[Web-01]"

# Server 2
TELEGRAM_PREFIX="[DB-01]"
```

### Separate Alert Channels

Use different Chat IDs for different server groups:

```bash
# Production servers → Security Ops channel
TELEGRAM_CHAT_ID="-1001234567890"

# Development servers → Dev Team channel
TELEGRAM_CHAT_ID="-1009876543210"
```

---

## Vaultwarden Integration

If using Vaultwarden/Bitwarden for credential management:

### Store Token in Vaultwarden

```bash
# 1. Add Secure Note to Vaultwarden named "Telegram Bot Token"
# 2. Set note content to your bot token

# 3. Only configure Chat ID in /etc/default/security-log-monitor
TELEGRAM_CHAT_ID="-1001234567890"
```

The script will automatically fetch the token from Vaultwarden via `bash-production-toolkit`.

### Required Vaultwarden Setup

Ensure `bw` CLI is configured:

```bash
# Login to Vaultwarden
bw config server https://vaultwarden.example.com
bw login your-email@example.com

# Test retrieval
bw get notes "Telegram Bot Token"
```

---

## Debugging Configuration

### Dry-Run Mode

Test configuration without sending alerts:

```bash
sudo /usr/local/bin/security-log-monitor.sh --dry-run
```

### Verbose Logging

Enable debug logging in `logging.sh`:

```bash
# Set LOG_LEVEL in /etc/default/security-log-monitor
LOG_LEVEL=DEBUG
```

### Check Configuration

Verify environment variables are loaded:

```bash
# Run service manually with env print
sudo systemd-run --unit=test-security-monitor \
    --collect --wait \
    bash -c 'set | grep -E "(TELEGRAM|SSH|UFW)"; /usr/local/bin/security-log-monitor.sh --dry-run'
```

---

## Next Steps

- [Setup Guide](SETUP.md) - Installation instructions
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Common issues
- [Main README](../README.md) - Component overview

---

**Last Updated**: 15. Januar 2026
