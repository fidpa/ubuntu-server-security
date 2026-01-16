# Telegram Integration for fail2ban

Real-time ban/unban notifications via Telegram with IP context.

## Features

- ✅ Instant ban/unban notifications
- ✅ IP context (Country via GeoIP, ISP via whois)
- ✅ HTML-formatted messages with emojis
- ✅ Rate limiting (5min cooldown per IP)
- ✅ Device-agnostic (works on any Ubuntu server)
- ✅ Multiple jail support

## Prerequisites

### 1. Create Telegram Bot

1. Open Telegram and search for `@BotFather`
2. Send `/newbot` command
3. Follow prompts to choose bot name and username
4. **Save the Bot Token** (format: `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`)

### 2. Get Chat ID

**Option A: Manual method**
1. Send any message to your bot
2. Visit (replace `YOUR_BOT_TOKEN`):
   ```
   https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates
   ```
3. Look for `"chat":{"id":123456789}`
4. **Save the Chat ID** (format: `123456789` or negative for groups)

**Option B: Using curl**
```bash
# Replace YOUR_BOT_TOKEN with your actual token
curl https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates

# Look for: "chat":{"id":123456789}
```

### 3. Install Dependencies

```bash
# Install curl (for Telegram API)
sudo apt install curl

# Optional: Install whois (for IP context - Country, ISP)
sudo apt install whois
```

## Installation

### 1. Configure Secrets

```bash
# Create device-specific secrets directory
sudo mkdir -p /etc/$(hostname -s)

# Create .env.secrets file
sudo nano /etc/$(hostname -s)/.env.secrets

# Add Telegram credentials:
TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
TELEGRAM_CHAT_ID="123456789"

# Secure permissions (CRITICAL!)
sudo chmod 600 /etc/$(hostname -s)/.env.secrets
sudo chown root:root /etc/$(hostname -s)/.env.secrets
```

**Security Note**: The `.env.secrets` file contains sensitive credentials. Never commit to git or share publicly.

### 2. Deploy Telegram Action

```bash
# Copy action configuration
sudo cp actions/telegram.conf /etc/fail2ban/action.d/

# Copy action script
sudo cp actions/telegram-send.sh /etc/fail2ban/action.d/

# Make script executable
sudo chmod 755 /etc/fail2ban/action.d/telegram-send.sh

# Verify deployment
ls -la /etc/fail2ban/action.d/telegram*
```

### 3. Test Telegram Script

```bash
# Manual test (should send message to Telegram)
sudo /etc/fail2ban/action.d/telegram-send.sh ban 1.2.3.4 5 test-jail 600

# Check Telegram app - you should receive a message
# Expected format:
# 🚨 [YourHost] fail2ban Ban
# IP: 1.2.3.4
# Country: US 🌍
# ISP: Google LLC
# Failures: 5 attempts
# Jail: test-jail
# Ban-Time: 600s
```

## Configuration

### Enable Telegram for Specific Jail

Edit jail configuration (e.g., `/etc/fail2ban/jail.d/10-sshd.conf`):

```ini
[sshd]
enabled = true
backend = systemd
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 600

# Add Telegram action
action = %(action_)s
         telegram[name=SSH]
```

**Restart fail2ban**:
```bash
sudo systemctl restart fail2ban
```

### Enable Telegram for Multiple Jails

**nginx jail** (`/etc/fail2ban/jail.d/20-nginx.conf`):
```ini
[nginx-http-auth]
enabled = true
# ... other settings ...

action = %(action_)s
         telegram[name=Nginx-Auth]
```

**GeoIP jail** (`/etc/fail2ban/jail.d/40-geoip.conf`):
```ini
[sshd-geoip]
enabled = true
# ... other settings ...

action = %(action_)s
         telegram[name=SSH-GeoIP]
```

### Customize Alert Prefix

Edit `/etc/fail2ban/action.d/telegram-send.sh`:

```bash
# Customize device detection (line ~80)
get_alert_prefix() {
    case "$(hostname -s)" in
        pi-router) echo "Pi5-Router" ;;
        nas)       echo "NAS-Server" ;;
        web01)     echo "Web-Server-01" ;;  # Add your custom prefix
        *)         echo "$(hostname -s)" ;;
    esac
}
```

### Adjust Rate Limiting

Edit `/etc/fail2ban/action.d/telegram-send.sh`:

```bash
# Change cooldown period (line ~43)
readonly ALERT_COOLDOWN=300  # Default: 5 minutes

# Examples:
# readonly ALERT_COOLDOWN=60   # 1 minute (more alerts)
# readonly ALERT_COOLDOWN=600  # 10 minutes (fewer alerts)
# readonly ALERT_COOLDOWN=0    # No rate limiting (not recommended)
```

## Message Format

### Ban Notification

```
🚨 [YourHost] fail2ban Ban

IP: 1.2.3.4
Country: US 🌍
ISP: Google LLC
Failures: 5 attempts
Jail: sshd
Ban-Time: 600s

Time: 2026-01-10 12:00:00
Host: 192.168.100.1 (your-hostname)
```

### Unban Notification

```
✅ [YourHost] fail2ban Unban

IP: 1.2.3.4
Jail: sshd
Status: Ban lifted

Time: 2026-01-10 12:10:00
Host: 192.168.100.1 (your-hostname)
```

## Monitoring

### View Telegram Logs

```bash
# Follow Telegram alert logs
sudo tail -f /var/log/$(hostname -s)/fail2ban-telegram.log

# Example output:
# [2026-01-10 12:00:00] INFO: Ban alert sent for 1.2.3.4 (jail: sshd)
# [2026-01-10 12:05:00] INFO: Rate-limited: ban_1.2.3.4 (cooldown: 60s remaining)
# [2026-01-10 12:10:00] INFO: Unban alert sent for 1.2.3.4 (jail: sshd)
```

### Check fail2ban Logs

```bash
# View fail2ban logs
sudo journalctl -u fail2ban -f

# Look for Telegram action execution
# grep for "telegram" or "action.d"
```

### Test Ban/Unban Cycle

```bash
# Manual ban
sudo fail2ban-client set sshd banip 1.2.3.4

# Expected: Telegram ban notification within 5 seconds

# Manual unban
sudo fail2ban-client set sshd unbanip 1.2.3.4

# Expected: Telegram unban notification within 5 seconds
```

## Troubleshooting

### Problem: No Telegram messages received

**Check bot token and chat ID**:
```bash
# View secrets file
sudo cat /etc/$(hostname -s)/.env.secrets

# Verify format:
# TELEGRAM_BOT_TOKEN="123456:ABC-DEF..."
# TELEGRAM_CHAT_ID="123456789"
```

**Test Telegram API manually**:
```bash
# Replace with your credentials
BOT_TOKEN="your_bot_token"
CHAT_ID="your_chat_id"

curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  -d "text=Test message from fail2ban"

# Expected: {"ok":true,...}
# Check Telegram app for message
```

### Problem: Script fails with "Secrets file not found"

**Check secrets file location**:
```bash
# Verify file exists
ls -la /etc/$(hostname -s)/.env.secrets

# If not found, create it (see Installation step 1)
```

### Problem: IP context shows "Unknown"

**Install whois**:
```bash
sudo apt install whois

# Test manually
whois 8.8.8.8 | grep -E "Country|OrgName"
```

### Problem: Rate limiting (too many messages)

**Symptoms**: Logs show "Rate-limited" messages

**Solution**: Adjust `ALERT_COOLDOWN` in `telegram-send.sh` (see Configuration)

### Problem: Permission denied

**Fix script permissions**:
```bash
sudo chmod 755 /etc/fail2ban/action.d/telegram-send.sh
sudo chown root:root /etc/fail2ban/action.d/telegram-send.sh
```

**Fix secrets file permissions**:
```bash
sudo chmod 600 /etc/$(hostname -s)/.env.secrets
sudo chown root:root /etc/$(hostname -s)/.env.secrets
```

## Best Practices

1. **Use Rate Limiting**: Keep default 5min cooldown to avoid spam
2. **Separate Bots per Server**: Use different bot tokens for production vs. staging
3. **Monitor Log Files**: Check logs weekly for alert delivery issues
4. **Secure Secrets**: Never commit `.env.secrets` to git
5. **Test Regularly**: Manual ban/unban tests monthly
6. **Group Chat for Teams**: Use Telegram group chat ID for team notifications
7. **Custom Alert Prefixes**: Customize per server for easy identification

## Advanced: Multiple Recipients

To send alerts to multiple Telegram chats:

1. **Create multiple bots** (via @BotFather)
2. **Add multiple secrets**:
   ```bash
   # In .env.secrets
   TELEGRAM_BOT_TOKEN="bot1_token"
   TELEGRAM_CHAT_ID="chat1_id"
   TELEGRAM_BOT_TOKEN_SECONDARY="bot2_token"
   TELEGRAM_CHAT_ID_SECONDARY="chat2_id"
   ```

3. **Modify `telegram-send.sh`** to loop over multiple recipients

**Or** use a Telegram group:
1. Add bot to group
2. Get group chat ID (negative number)
3. Use group chat ID in `.env.secrets`

## See Also

- [SETUP.md](SETUP.md) - Initial installation
- [GEOIP_FILTERING.md](GEOIP_FILTERING.md) - GeoIP with Telegram alerts
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
