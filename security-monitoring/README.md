# Security Monitoring

Unified security event monitoring with smart deduplication and aggregated Telegram alerts.

## Features

- ✅ **Multi-Tool Monitoring** - fail2ban, SSH, UFW, auditd, AIDE, rkhunter in one script
- ✅ **Smart Deduplication** - Alert only on new events (state-based)
- ✅ **Aggregated Alerts** - Single Telegram message per run
- ✅ **Configurable Thresholds** - Customize when to alert
- ✅ **15-Minute Interval** - Real-time security awareness
- ✅ **Production-Ready** - Built on bash-production-toolkit

## Quick Start

```bash
# 1. Install bash-production-toolkit (if not already installed)
git clone https://github.com/fidpa/bash-production-toolkit.git
cd bash-production-toolkit
sudo make install

# 2. Deploy security-log-monitor script
sudo cp security-monitoring/scripts/security-log-monitor.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/security-log-monitor.sh

# 3. Configure Telegram credentials
sudo nano /etc/default/security-log-monitor
# Add: TELEGRAM_BOT_TOKEN="your-token"
#      TELEGRAM_CHAT_ID="your-chat-id"

# 4. Deploy systemd units
sudo cp security-monitoring/systemd/security-log-monitor.* /etc/systemd/system/
sudo systemctl daemon-reload

# 5. Enable timer
sudo systemctl enable --now security-log-monitor.timer

# 6. Verify
sudo systemctl status security-log-monitor.timer
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation, configuration, systemd setup |
| [CONFIGURATION.md](docs/CONFIGURATION.md) | Environment variables, thresholds, state management |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and debugging |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- systemd (for timer automation)
- Root/sudo access
- bash-production-toolkit (logging, alerts, secure file utils)
- Optional: ausearch (auditd), aide, rkhunter

## Use Cases

- ✅ **Security Operations Center** - Centralized security event monitoring
- ✅ **Compliance** - Track security events for audit trails
- ✅ **DevOps** - Real-time security awareness for development servers
- ✅ **Production Servers** - Automated intrusion detection and alerting
- ✅ **Multi-Server Environments** - Deploy to multiple hosts with consistent monitoring

## Monitored Components

| Component | Events Monitored | Alert Trigger |
|-----------|------------------|---------------|
| **fail2ban** | Ban/Unban events | Any new ban |
| **SSH** | Failed login attempts | >5 failures + new IPs |
| **UFW** | Blocked external IPs | >10 blocks from same IP |
| **auditd** | Security policy violations | Any new denied event |
| **AIDE** | File integrity changes | Exit code ≥1 |
| **rkhunter** | Rootkit detection | Any warnings |

## How It Works

1. **Check Phase**: Script queries journalctl for events in last 15 minutes
2. **Deduplication**: Compare current events with saved state
3. **Aggregation**: Collect all new events into single message
4. **Alerting**: Send Telegram notification with rate limiting (30min)
5. **State Persistence**: Save current state for next run

**Why Deduplication?** Prevents alert fatigue by only notifying on new events, not recurring ones.

---

**See also**:
- [bash-production-toolkit](https://github.com/fidpa/bash-production-toolkit) - Required dependency
- [ubuntu-server-security](https://github.com/fidpa/ubuntu-server-security) - Full hardening suite
