# fail2ban Setup Guide

Complete installation and deployment guide for fail2ban with production-ready configuration.

## Prerequisites

**Supported Platforms**:
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)
- Debian 11+ (Bullseye, Bookworm)

**Minimum Requirements**:
- fail2ban >= 1.0.2
- systemd (for backend and timer automation)
- Root/sudo access

**Optional Requirements**:
- `geoip-bin` + `geoip-database` (for GeoIP filtering)
- `curl` (for Telegram alerts)
- `whois` (for IP context in alerts)
- Prometheus + node_exporter (for metrics)

## Step 1: Install fail2ban

```bash
# Update package cache
sudo apt update

# Install fail2ban
sudo apt install fail2ban

# Verify installation
fail2ban-client --version
# Expected: v1.0.2 or higher
```

## Step 2: Deploy Base Configuration

### Main Configuration

```bash
# Navigate to component directory
cd fail2ban/

# Copy base configuration
sudo cp fail2ban.local.template /etc/fail2ban/fail2ban.local

# Edit configuration (adjust bantime, ignoreip, etc.)
sudo nano /etc/fail2ban/fail2ban.local
```

**Key settings to configure**:
```ini
# Ban duration (default: 10 minutes = 600 seconds)
bantime = 600

# Management network whitelist (prevent banning admin IPs)
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/24
```

### Jail Configuration

```bash
# Copy jail configuration
sudo cp jail.local.template /etc/fail2ban/jail.local

# Optional: Edit jail settings
sudo nano /etc/fail2ban/jail.local
```

## Step 3: Deploy Drop-in Jails

```bash
# Create jail drop-in directory
sudo mkdir -p /etc/fail2ban/jail.d

# Copy all drop-ins (or only those you need)
sudo cp drop-ins/*.conf /etc/fail2ban/jail.d/

# Remove drop-ins for services you don't use
# Example: If you don't use VNC:
sudo rm /etc/fail2ban/jail.d/30-vnc.conf

# Example: If you don't want GeoIP filtering:
sudo rm /etc/fail2ban/jail.d/40-geoip.conf
```

**Recommended jails**:
- `10-sshd.conf` - ✅ Always include (SSH protection)
- `20-nginx.conf` - Include if using nginx
- `30-vnc.conf` - Include if using VNC
- `40-geoip.conf` - Include if using GeoIP filtering (requires setup)

## Step 4: Deploy Custom Filters (Optional)

```bash
# Copy custom filters
sudo cp filters/*.conf /etc/fail2ban/filter.d/
```

**Note**: VNC filter is only needed if using `30-vnc.conf` jail.

## Step 5: Validate Configuration

```bash
# Test configuration syntax
sudo fail2ban-client --test

# Expected output: No errors

# If you get errors, check:
# - Syntax in jail.d/*.conf files
# - Filter existence in filter.d/
# - Action existence in action.d/
```

## Step 6: Start fail2ban

```bash
# Enable service on boot
sudo systemctl enable fail2ban

# Start service
sudo systemctl start fail2ban

# Check status
sudo systemctl status fail2ban
```

## Step 7: Verify Active Jails

```bash
# List active jails
sudo fail2ban-client status

# Expected output:
# Status
# |- Number of jail:      2
# `- Jail list:   sshd, nginx-http-auth

# Check specific jail
sudo fail2ban-client status sshd
```

## Optional: GeoIP Filtering Setup

**Prerequisites**:
```bash
# Install GeoIP packages
sudo apt install geoip-bin geoip-database

# Verify installation
geoiplookup 8.8.8.8
# Expected: Country code and name
```

**Deploy script**:
```bash
# Copy geoip-whitelist script
sudo cp scripts/geoip-whitelist.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/geoip-whitelist.sh

# Test script
/usr/local/bin/geoip-whitelist.sh 8.8.8.8
# Expected: Exit 1 (US not in whitelist)

/usr/local/bin/geoip-whitelist.sh 10.0.0.1
# Expected: Exit 0 (private IP whitelisted)
```

**Enable GeoIP jail**:
```bash
# Already enabled if you copied drop-ins/40-geoip.conf
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd-geoip
```

See [GEOIP_FILTERING.md](GEOIP_FILTERING.md) for detailed configuration.

## Optional: Telegram Alerts Setup

**Prerequisites**:
1. Create Telegram Bot via @BotFather
2. Get Chat ID
3. Install curl: `sudo apt install curl`

**Configure secrets**:
```bash
# Create secrets file (device-specific path)
sudo mkdir -p /etc/$(hostname -s)
sudo nano /etc/$(hostname -s)/.env.secrets

# Add Telegram credentials:
TELEGRAM_BOT_TOKEN="your_bot_token_here"
TELEGRAM_CHAT_ID="your_chat_id_here"

# Secure permissions
sudo chmod 600 /etc/$(hostname -s)/.env.secrets
```

**Deploy action**:
```bash
# Copy Telegram action
sudo cp actions/telegram.conf /etc/fail2ban/action.d/
sudo cp actions/telegram-send.sh /etc/fail2ban/action.d/
sudo chmod 755 /etc/fail2ban/action.d/telegram-send.sh
```

**Enable in jail** (edit `/etc/fail2ban/jail.d/10-sshd.conf`):
```ini
[sshd]
enabled = true
# ... other settings ...

action = %(action_)s
         telegram[name=SSH]
```

**Test**:
```bash
# Restart fail2ban
sudo systemctl restart fail2ban

# Manual ban test
sudo fail2ban-client set sshd banip 1.2.3.4

# Expected: Telegram message received
```

See [TELEGRAM_INTEGRATION.md](TELEGRAM_INTEGRATION.md) for detailed setup.

## Optional: Prometheus Metrics

**Prerequisites**:
- Prometheus + node_exporter installed
- node_exporter configured with textfile collector

**Deploy metrics exporter**:
```bash
# Copy script
sudo cp scripts/fail2ban-metrics-exporter.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/fail2ban-metrics-exporter.sh

# Create metrics directory
sudo mkdir -p /var/lib/node_exporter/textfile_collector

# Test manual export
sudo /usr/local/bin/fail2ban-metrics-exporter.sh

# Check metrics file
cat /var/lib/node_exporter/textfile_collector/fail2ban.prom
```

**Create systemd timer** (optional, for periodic export):
```bash
# Create service
sudo nano /etc/systemd/system/fail2ban-metrics.service

[Unit]
Description=fail2ban Prometheus Metrics Exporter

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fail2ban-metrics-exporter.sh

# Create timer
sudo nano /etc/systemd/system/fail2ban-metrics.timer

[Unit]
Description=fail2ban Metrics Export Timer

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target

# Enable timer
sudo systemctl daemon-reload
sudo systemctl enable --now fail2ban-metrics.timer
```

See [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) for Grafana dashboards.

## Testing

### Test SSH Jail

```bash
# From a different machine, try invalid SSH login 3 times
ssh invalid_user@your_server_ip

# Check if IP was banned
sudo fail2ban-client status sshd
# Look for "Banned IP list"

# Manual unban
sudo fail2ban-client set sshd unbanip <ip_address>
```

### Test GeoIP Filtering

```bash
# Check logs
sudo tail -f /var/log/$(hostname -s)/fail2ban-geoip.log

# Expected entries for each SSH attempt:
# [2026-01-10 12:00:00] IP=1.2.3.4 COUNTRY=US
# [2026-01-10 12:00:00] DENY: 1.2.3.4 (Not in whitelist)
```

### Test Telegram Alerts

```bash
# Manual test
sudo fail2ban-client set sshd banip 1.2.3.4

# Expected: Telegram message within 5 seconds

# Check logs
sudo journalctl -u fail2ban -f
```

## Troubleshooting

**Problem**: fail2ban won't start

**Solution**:
```bash
sudo journalctl -u fail2ban -n 50
sudo fail2ban-client --test
```

**Problem**: Jails not loading

**Solution**:
```bash
# Check jail syntax
sudo fail2ban-client status

# Validate configuration
sudo fail2ban-client --test
```

**Problem**: GeoIP not working

**Solution**:
```bash
# Test geoiplookup manually
geoiplookup 8.8.8.8

# Check script permissions
ls -la /usr/local/bin/geoip-whitelist.sh

# Check logs
sudo tail -f /var/log/$(hostname -s)/fail2ban-geoip.log
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

## Next Steps

1. **Monitor bans**: `sudo fail2ban-client status`
2. **Check logs**: `sudo journalctl -u fail2ban -f`
3. **Review whitelist**: Add trusted IPs to `ignoreip` in `/etc/fail2ban/fail2ban.local`
4. **Tune policies**: Adjust `maxretry`, `findtime`, `bantime` per jail
5. **Setup monitoring**: Deploy Prometheus metrics
6. **Regular audits**: Check false positives weekly

## See Also

- [GEOIP_FILTERING.md](GEOIP_FILTERING.md) - GeoIP setup and configuration
- [TELEGRAM_INTEGRATION.md](TELEGRAM_INTEGRATION.md) - Alert setup
- [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) - Metrics and monitoring
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
