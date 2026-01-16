# rkhunter - Rootkit Hunter

Rootkit and malware detection for Ubuntu servers with automated scanning and false-positive management.

## Features

- ✅ **Automated Daily Scans** - Runs via cron.daily at 06:25 (systemd timer)
- ✅ **Weekly Database Updates** - Automatic rootkit signature updates
- ✅ **Email Alerts** - Configurable notifications on warnings
- ✅ **False-Positive Whitelisting** - Production-tested exclusions
- ✅ **Low Overhead** - Minimal system impact (~30 seconds scan time)
- ✅ **Complementary to AIDE** - Signature-based detection vs integrity-based

## Quick Start

```bash
# 1. Install and initialize
sudo apt install rkhunter
sudo rkhunter --update && sudo rkhunter --propupd

# 2. Run first scan
sudo rkhunter --check --skip-keypress

# 3. Configure email alerts (optional)
sudo nano /etc/rkhunter.conf  # Set: MAIL-ON-WARNING=your@email.com
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation, configuration, and automation setup |
| [FALSE_POSITIVES.md](docs/FALSE_POSITIVES.md) | Known false positives and whitelisting strategies |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- rkhunter v1.4.6+
- Mail transfer agent (for email alerts - optional)

## Comparison with AIDE

rkhunter and AIDE are complementary tools for defense-in-depth:

| Feature | rkhunter | AIDE |
|---------|----------|------|
| **Detection Method** | Signature-based | Integrity-based |
| **Speed** | Fast (~30 seconds) | Slow (~5 minutes) |
| **Rootkit Detection** | ✅ Specialized | ❌ No |
| **File Integrity** | Basic | ✅ Advanced |
| **False Positives** | Low-Medium | High (needs tuning) |
| **Use Case** | Known rootkit scanning | File change detection |

**Recommendation:** Run both for comprehensive coverage.

## Use Cases

- ✅ **Production Servers** - Detect known rootkits and backdoors
- ✅ **Defense-in-Depth** - Complement AIDE and auditd monitoring
- ✅ **Compliance** - Regular security scanning requirements
- ✅ **Post-Incident** - Verify system integrity after compromise

## Resources

- [rkhunter Official Documentation](http://rkhunter.sourceforge.net/docs/)
- [Ubuntu rkhunter Package](https://packages.ubuntu.com/search?keywords=rkhunter)
