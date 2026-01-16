# fail2ban Custom Actions

Custom fail2ban actions for enhanced alerting and logging.

## Actions Pattern

fail2ban actions define what happens when an IP is banned or unbanned. Standard actions include:
- `iptables-multiport` - Block IP on specific ports
- `iptables-allports` - Block IP on all ports
- `sendmail` - Send email notification

This directory provides **custom actions** for production environments.

## Included Actions

| Action | Description | Requirements |
|--------|-------------|--------------|
| [telegram.conf](telegram.conf) | Telegram ban/unban notifications | Telegram Bot + curl |
| [telegram-send.sh](telegram-send.sh) | Telegram alert script with IP context | Telegram Bot + curl + whois |

## Telegram Action

### Features
- ✅ Real-time ban/unban notifications
- ✅ IP context (Country, ISP via whois)
- ✅ Rate limiting (5min cooldown per IP)
- ✅ HTML-formatted messages with emojis
- ✅ Device-agnostic (works on any Ubuntu server)

### Prerequisites

1. **Create Telegram Bot**:
   ```bash
   # Talk to @BotFather on Telegram
   # Send: /newbot
   # Follow prompts to get BOT_TOKEN
   ```

2. **Get Chat ID**:
   ```bash
   # Send a message to your bot
   # Then visit (replace YOUR_BOT_TOKEN):
   curl https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates
   # Look for "chat":{"id":123456789}
   ```

3. **Configure Secrets**:
   ```bash
   # Add to /etc/$(hostname -s)/.env.secrets
   TELEGRAM_BOT_TOKEN="your_bot_token_here"
   TELEGRAM_CHAT_ID="your_chat_id_here"
   ```

### Installation

```bash
# Copy action definition
sudo cp telegram.conf /etc/fail2ban/action.d/

# Copy and install script
sudo cp telegram-send.sh /etc/fail2ban/action.d/
sudo chmod 755 /etc/fail2ban/action.d/telegram-send.sh
```

### Usage

Add telegram action to jail configuration:

```ini
[sshd]
enabled = true
# ... other settings ...

# Add telegram action
action = %(action_)s
         telegram[name=SSH]
```

Multiple jails example:

```ini
[nginx-http-auth]
enabled = true
action = %(action_)s
         telegram[name=Nginx-Auth]

[sshd-geoip]
enabled = true
action = %(action_)s
         telegram[name=SSH-GeoIP]
```

### Testing

```bash
# Manual test (requires .env.secrets configured)
sudo /etc/fail2ban/action.d/telegram-send.sh ban 1.2.3.4 5 sshd 600

# Expected: Telegram message with ban details

# Check logs
sudo journalctl -u fail2ban -f
# Or device-specific log:
sudo tail -f /var/log/$(hostname -s)/fail2ban-telegram.log
```

## Creating Your Own Actions

Example: Webhook notification

```bash
# File: /etc/fail2ban/action.d/webhook.conf

[Definition]
actionban = curl -X POST https://your-webhook.com/ban \
            -H "Content-Type: application/json" \
            -d '{"ip":"<ip>","jail":"<name>","failures":<failures>}'

actionunban = curl -X POST https://your-webhook.com/unban \
              -H "Content-Type: application/json" \
              -d '{"ip":"<ip>","jail":"<name>"}'

[Init]
```

**Available Variables**:
- `<ip>` - Banned IP address
- `<failures>` - Number of failed attempts
- `<name>` - Jail name
- `<bantime>` - Ban duration in seconds
- `<time>` - Current timestamp

## Troubleshooting

**Problem**: Telegram alerts not sending

**Solution**:
1. Check bot token and chat ID in `.env.secrets`
2. Test bot manually:
   ```bash
   curl -X POST "https://api.telegram.org/bot<YOUR_TOKEN>/sendMessage" \
     -d "chat_id=<YOUR_CHAT_ID>" \
     -d "text=Test message"
   ```
3. Check fail2ban logs: `sudo journalctl -u fail2ban -n 50`
4. Verify script permissions: `ls -la /etc/fail2ban/action.d/telegram-send.sh`

**Problem**: Rate limiting (too many messages)

**Solution**: Adjust `ALERT_COOLDOWN` in `telegram-send.sh` (default: 300 seconds)

**Problem**: IP context not showing (Country, ISP)

**Solution**: Install `whois` package:
```bash
sudo apt install whois
```

See [../docs/TELEGRAM_INTEGRATION.md](../docs/TELEGRAM_INTEGRATION.md) for detailed setup guide.
