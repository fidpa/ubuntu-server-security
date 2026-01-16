# fail2ban - Brute-Force Protection

Intrusion prevention with GeoIP filtering, Telegram alerts, and multi-service protection.

## Features

- ✅ **Multi-Service Protection** - SSH, nginx, Apache, Postfix, Dovecot jails
- ✅ **GeoIP Filtering** - Country-based blocking (optional)
- ✅ **Telegram Alerts** - Real-time ban notifications
- ✅ **Permanent Bans** - Persistent ban database across reboots
- ✅ **Customizable Thresholds** - Flexible maxretry and bantime settings
- ✅ **Prometheus Metrics** - Export ban statistics for monitoring

## Quick Start

```bash
# 1. Install fail2ban
sudo apt install fail2ban

# 2. Deploy configuration
sudo cp jail.local.template /etc/fail2ban/jail.local

# 3. Enable and start
sudo systemctl enable --now fail2ban

# 4. Verify
sudo fail2ban-client status
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation, jail configuration, and testing |
| [GEOIP_FILTERING.md](docs/GEOIP_FILTERING.md) | Country-based blocking setup |
| [TELEGRAM_ALERTS.md](docs/TELEGRAM_ALERTS.md) | Real-time ban notifications |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues (false positives, unban procedures) |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- fail2ban v0.11+
- Root/sudo access
- Optional: Telegram Bot Token (for alerts)
- Optional: GeoIP database (for country filtering)

## Available Jails

| Jail | Service | Default | Description |
|------|---------|---------|-------------|
| **sshd** | SSH | ✅ Enabled | Protects SSH from brute-force attacks |
| **nginx-http-auth** | nginx | ❌ Disabled | HTTP Basic Auth failures |
| **nginx-noscript** | nginx | ❌ Disabled | Script execution attempts |
| **apache-auth** | Apache | ❌ Disabled | Apache authentication failures |
| **postfix** | Mail | ❌ Disabled | SMTP brute-force protection |
| **dovecot** | Mail | ❌ Disabled | IMAP/POP3 protection |

## Use Cases

- ✅ **SSH Servers** - Prevent brute-force SSH attacks
- ✅ **Web Servers** - Protect nginx/Apache authentication endpoints
- ✅ **Mail Servers** - Secure SMTP/IMAP against credential stuffing
- ✅ **Geoblocking** - Block entire countries (if required)
- ✅ **Compliance** - Automated intrusion prevention logging

## Resources

- [fail2ban Official Documentation](https://www.fail2ban.org/)
- [fail2ban Wiki](https://github.com/fail2ban/fail2ban/wiki)
- [Ubuntu fail2ban Guide](https://help.ubuntu.com/community/Fail2ban)
