# AIDE Failure Alerting

Real-time Telegram notifications when AIDE file integrity checks fail.

## Overview

The **aide-failure-alert** component provides instant alerts via Telegram when AIDE database updates fail, complementing the existing Prometheus metrics integration with a real-time notification layer.

## Features

- ✅ **Instant Telegram Alerts** - Real-time notifications when AIDE fails
- ✅ **Rate Limiting** - Prevents alert spam (1 alert per hour by default)
- ✅ **Dual Configuration Modes** - Simple environment variables or Vaultwarden integration
- ✅ **Systemd OnFailure Hook** - Automatic triggering when aide-update.service fails
- ✅ **Production-Ready** - Uses bash-production-toolkit libraries (logging, alerts, error handling)

## Architecture

```
aide-update.service (fails)
         ↓
OnFailure=aide-failure-alert.service
         ↓
aide-failure-alert.sh
         ↓
bash-production-toolkit/alerts.sh
         ↓
Telegram API → Alert sent
```

## Prerequisites

### Required

1. **bash-production-toolkit** installed at `/usr/local/lib/bash-production-toolkit`
   - See: https://github.com/fidpa/bash-production-toolkit

2. **Telegram Bot Token** and **Chat ID**
   - Create bot via [@BotFather](https://t.me/BotFather)
   - Get chat ID via [@userinfobot](https://t.me/userinfobot)

### Optional (Advanced)

3. **Vaultwarden** for secrets management
   - See: [VAULTWARDEN_INTEGRATION.md](VAULTWARDEN_INTEGRATION.md)
   - Requires Bitwarden CLI (`bw`)

## Installation

### Step 1: Deploy Script

```bash
# Copy script to system location
sudo mkdir -p /usr/local/sbin/aide
sudo cp aide/scripts/aide-failure-alert.sh /usr/local/sbin/aide/
sudo chmod 755 /usr/local/sbin/aide/aide-failure-alert.sh
```

### Step 2: Configure systemd Service

**Option A: Simple Configuration (Environment Variables)**

```bash
# Create service file from template
sudo cp aide/systemd/aide-failure-alert.service.template \
        /etc/systemd/system/aide-failure-alert.service

# Edit service file
sudo nano /etc/systemd/system/aide-failure-alert.service
```

Replace placeholders:
```ini
# Script path
ExecStart=/usr/local/sbin/aide/aide-failure-alert.sh

# Bash Production Toolkit path
Environment="BASH_TOOLKIT_PATH=/usr/local/lib/bash-production-toolkit"

# Telegram credentials (Simple mode)
Environment="TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
Environment="TELEGRAM_CHAT_ID=-1001234567890"

# Alert customization
Environment="TELEGRAM_PREFIX=[🚨 AIDE - $(hostname -s)]"
Environment="RATE_LIMIT_SECONDS=3600"
```

**Option B: Vaultwarden Integration (Advanced)**

```bash
# Same as Option A, but use Vaultwarden for secrets
sudo nano /etc/systemd/system/aide-failure-alert.service
```

Replace Telegram env vars with Vaultwarden:
```ini
# Vaultwarden configuration
Environment="VAULTWARDEN_URL=https://vaultwarden.example.com"
Environment="BW_SESSION=your-bitwarden-session-token"

# Vaultwarden item names (used by load_telegram_config)
Environment="VAULTWARDEN_ITEM_TELEGRAM_BOT=Telegram Bot Token"
Environment="VAULTWARDEN_ITEM_TELEGRAM_CHAT=Telegram Chat ID"
```

### Step 3: Enable OnFailure Hook

Edit `aide-update.service` to trigger alerts on failure:

```bash
sudo nano /etc/systemd/system/aide-update.service
```

Add to `[Unit]` section:
```ini
[Unit]
Description=AIDE Database Update
OnFailure=aide-failure-alert.service
```

### Step 4: Reload and Enable

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable aide-failure-alert (stays dormant until triggered)
sudo systemctl enable aide-failure-alert.service

# Restart aide-update.timer (picks up OnFailure hook)
sudo systemctl restart aide-update.timer
```

## Testing

### Test Alert Manually

```bash
# Trigger aide-failure-alert directly
sudo systemctl start aide-failure-alert.service

# Check logs
sudo journalctl -u aide-failure-alert.service -n 50
```

Expected output:
```
AIDE Failure Alert
Service Status: ActiveState=failed, SubState=failed, ExitCode=15
Sending Telegram alert...
✅ Telegram alert sent successfully
```

### Simulate AIDE Failure

```bash
# Corrupt AIDE database temporarily (CAUTION!)
sudo mv /var/lib/aide/aide.db /var/lib/aide/aide.db.bak

# Trigger aide-update (will fail)
sudo systemctl start aide-update.service

# Check if alert was sent
sudo journalctl -u aide-failure-alert.service -n 20
```

**Cleanup**:
```bash
# Restore database
sudo mv /var/lib/aide/aide.db.bak /var/lib/aide/aide.db
```

## Alert Message Format

```
⚠️ AIDE File Integrity Check FAILED!

🖥️ Device: server.example.com
❌ Status: failed (dead)
🔢 Exit Code: 15
⏰ Time: 2026-01-04 17:30:00

⚡ Critical: File Integrity Monitoring non-functional!

📋 Logs:
journalctl -u aide-update.service -n 50

🔧 Check:
systemctl status aide-update.service
ls -lh /var/lib/aide/aide.db*
```

## Configuration Options

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BASH_TOOLKIT_PATH` | `/usr/local/lib/bash-production-toolkit` | Bash Production Toolkit installation path |
| `TELEGRAM_BOT_TOKEN` | - | Telegram bot API token (Simple mode) |
| `TELEGRAM_CHAT_ID` | - | Telegram chat ID (Simple mode) |
| `TELEGRAM_PREFIX` | `[🚨 AIDE]` | Alert prefix (customize per server) |
| `STATE_DIR` | `/var/lib/aide` | Directory for rate limit state files |
| `RATE_LIMIT_SECONDS` | `3600` | Minimum time between alerts (prevents spam) |

### Vaultwarden Variables (Advanced)

| Variable | Default | Description |
|----------|---------|-------------|
| `VAULTWARDEN_URL` | - | Vaultwarden server URL |
| `BW_SESSION` | - | Bitwarden CLI session token |
| `VAULTWARDEN_ITEM_TELEGRAM_BOT` | `Telegram Bot Token` | Vaultwarden item name for bot token |
| `VAULTWARDEN_ITEM_TELEGRAM_CHAT` | `Telegram Chat ID` | Vaultwarden item name for chat ID |

## Rate Limiting

**Why Rate Limiting?**
- Prevents Telegram spam if AIDE fails repeatedly
- Default: 1 alert per hour (3600 seconds)
- State tracked via `/var/lib/aide/.aide-failure_state`

**Adjust Rate Limit**:
```ini
# In aide-failure-alert.service
Environment="RATE_LIMIT_SECONDS=1800"  # 30 minutes
```

## Integration with Prometheus

aide-failure-alert **complements** Prometheus alerting:

| Aspect | Prometheus | aide-failure-alert |
|--------|------------|-------------------|
| **Trigger** | Polling (scrape interval) | Instant (systemd OnFailure) |
| **Latency** | 1-5 minutes | <1 second |
| **Use Case** | Trends, dashboards | Critical instant alerts |
| **Complexity** | High (Alertmanager config) | Low (systemd hook) |

**Recommendation**: Use **both** for dual-layer alerting (see [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md)).

## Troubleshooting

### Alert Not Received

**Check service status**:
```bash
sudo systemctl status aide-failure-alert.service
```

**Common issues**:
1. **Rate limited** - Check state file:
   ```bash
   cat /var/lib/aide/.aide-failure_state
   ```

2. **Invalid Telegram credentials** - Test manually:
   ```bash
   curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
        -d "chat_id=<CHAT_ID>" \
        -d "text=Test"
   ```

3. **bash-production-toolkit not found**:
   ```bash
   ls /usr/local/lib/bash-production-toolkit/src/monitoring/alerts.sh
   ```

### Logs

```bash
# aide-failure-alert logs
sudo journalctl -u aide-failure-alert.service -f

# AIDE update logs (root cause)
sudo journalctl -u aide-update.service -n 100
```

## Security Considerations

1. **Secrets Management**
   - Option A (Simple): Store in systemd service file (protected by file permissions)
   - Option B (Advanced): Use Vaultwarden (centralized, auditable)

2. **File Permissions**
   ```bash
   # Service file must be root-owned
   sudo chown root:root /etc/systemd/system/aide-failure-alert.service
   sudo chmod 644 /etc/systemd/system/aide-failure-alert.service
   ```

3. **State Directory**
   ```bash
   # Create if missing
   sudo mkdir -p /var/lib/aide
   sudo chown root:root /var/lib/aide
   sudo chmod 755 /var/lib/aide
   ```

## Performance Impact

- **CPU**: Negligible (<0.1% during execution)
- **Memory**: ~10MB (bash + libraries)
- **Network**: 1-2 KB per alert (Telegram API)
- **Execution Time**: <1 second (excluding rate limit checks)

## Best Practices

1. **Customize Telegram Prefix** per server:
   ```ini
   Environment="TELEGRAM_PREFIX=[🚨 AIDE - Production DB]"
   ```

2. **Set Reasonable Rate Limits**:
   - Production: 3600s (1 hour)
   - Staging: 1800s (30 minutes)
   - Development: 600s (10 minutes)

3. **Test Before Deployment**:
   ```bash
   sudo systemctl start aide-failure-alert.service
   ```

4. **Monitor Alert Delivery**:
   ```bash
   # Count alerts sent today
   sudo journalctl -u aide-failure-alert.service --since today | grep "alert sent"
   ```

## Related Documentation

- [SETUP.md](SETUP.md) - Main AIDE installation guide
- [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) - Metrics and alerting
- [VAULTWARDEN_INTEGRATION.md](VAULTWARDEN_INTEGRATION.md) - Secrets management
- [bash-production-toolkit](https://github.com/fidpa/bash-production-toolkit) - Library documentation

## Support

For issues with:
- **AIDE configuration**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **bash-production-toolkit**: https://github.com/fidpa/bash-production-toolkit/issues
- **Telegram integration**: Check bot permissions and chat ID

---

**Version**: 1.0 (Initial Release)
**License**: MIT
