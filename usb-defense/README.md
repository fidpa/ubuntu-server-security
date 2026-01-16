# USB Defense System

3-layer defense-in-depth protection against USB-based attacks on Ubuntu servers.

## Features

- ✅ **3-Layer Defense** - Kernel blacklist + real-time detection (2-4s) + auditd bypass monitoring
- ✅ **HID Filtering** - Keyboards/mice excluded automatically (USB class-based)
- ✅ **Rate Limiting** - 1-hour cooldown per device (prevents alert floods)
- ✅ **Email Alerts** - HTML-formatted alerts with security status
- ✅ **Zero Dependencies** - Standalone scripts (no external libraries)
- ✅ **Production-Proven** - Running on multiple servers since Jan 2026

## Quick Start

```bash
# Deploy all 3 layers (requires root)
sudo ./scripts/deploy-usb-defense.sh

# Test with USB device (recommended)
# 1. Plug in USB stick
# 2. Wait 2-4 seconds
# 3. Check email for alert
# 4. Verify: lsblk (should NOT show USB device)

# Monitor service health
systemctl status usb-device-watcher.service
journalctl -u usb-device-watcher.service -f
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation & configuration guide |
| [THREE_LAYER_DEFENSE.md](docs/THREE_LAYER_DEFENSE.md) | Architecture & threat model |
| [ALERT_CONFIGURATION.md](docs/ALERT_CONFIGURATION.md) | E-mail alert setup |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues & solutions |

## Requirements

**Minimum**:
- Ubuntu 22.04+ / Debian 11+ (systemd-based)
- Root/sudo access
- auditd service running (for Layer 3)

**Optional**:
- mail or msmtp (for email alerts)

## Use Cases

- ✅ Servers in office environments (no camera surveillance)
- ✅ Physical access by multiple personnel
- ✅ Compliance requirements (prevent data exfiltration)
- ✅ Defense against naive USB attacks (99% of threats)

## What Gets Blocked

- ❌ USB flash drives (Mass Storage devices)
- ❌ External USB hard drives
- ❌ USB card readers

## What Still Works

- ✅ Keyboards/mice (use usbhid, not usb-storage)
- ✅ Live USB sticks for recovery (boot with own kernel)
- ✅ SSH access (network-based, unaffected)

## Configuration

Customize via environment variables:

```bash
# Alert email recipient (default: root)
export USB_DEFENSE_ALERT_EMAIL="security@example.com"

# Polling interval in seconds (default: 2)
export USB_DEFENSE_POLL_INTERVAL="2"

# Alert cooldown in seconds (default: 3600)
export USB_DEFENSE_COOLDOWN="3600"
```

See [configs/usb-defense.conf.example](configs/usb-defense.conf.example) for all options.

## Rollback

```bash
sudo ./scripts/deploy-usb-defense.sh --rollback
sudo reboot  # Required to re-enable usb-storage
```

## Resources

- [Linux USB Subsystem Documentation](https://www.kernel.org/doc/html/latest/driver-api/usb/index.html)
- [Linux Audit Framework](https://github.com/linux-audit/audit-documentation)
- [CIS Ubuntu Linux Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux) - Physical security guidance

## License

MIT License - see [LICENSE](../LICENSE) for details.
