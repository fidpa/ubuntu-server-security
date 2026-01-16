# AIDE - Advanced Intrusion Detection Environment

File integrity monitoring with production-tuned excludes and 99.7% false-positive reduction.

## Features

- ✅ **Production-Tuned Excludes** - Pre-configured for Docker, PostgreSQL, Nextcloud
- ✅ **False-Positive Reduction** - 99.7% reduction based on production data (3,799 → 12 changes/day)
- ✅ **Drop-in Configuration Pattern** - Modular service-specific excludes
- ✅ **Prometheus Metrics** - Integration for monitoring and alerting
- ✅ **Non-Root Monitoring** - Permission management via `_aide` group
- ✅ **Immutable Binary Protection** - Automated validation and alerts

## Quick Start

```bash
# 1. Install AIDE
sudo apt install aide aide-common

# 2. Deploy configuration
sudo cp aide.conf.template /etc/aide/aide.conf
sudo cp drop-ins/*.conf /etc/aide/aide.conf.d/

# 3. Initialize database
sudo aideinit
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation and configuration guide |
| [FALSE_POSITIVE_REDUCTION.md](docs/FALSE_POSITIVE_REDUCTION.md) | Production lessons and tuning strategies |
| [PROMETHEUS_INTEGRATION.md](docs/PROMETHEUS_INTEGRATION.md) | Metrics exporters and Grafana dashboards |
| [FAILURE_ALERTING.md](docs/FAILURE_ALERTING.md) | Real-time Telegram alerts for AIDE failures |
| [BOOT_RESILIENCY.md](docs/BOOT_RESILIENCY.md) | Boot-time behavior and recovery |
| [MONITORING_AIDE_ACCESS.md](docs/MONITORING_AIDE_ACCESS.md) | Permission monitoring and _aide group setup |
| [AIDE_BINARY_VALIDATION.md](docs/AIDE_BINARY_VALIDATION.md) | Immutable flag validation |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and solutions |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- AIDE v0.18.6+ (for modern hash algorithms)
- systemd (for timer automation)
- Optional: Prometheus + node_exporter (for metrics)

## Use Cases

- ✅ **Production Servers** - Detect unauthorized file changes
- ✅ **Container Hosts** - Monitor Docker configuration drift
- ✅ **Database Servers** - Track PostgreSQL configuration changes
- ✅ **Compliance** - Generate file integrity audit reports
- ✅ **Defense-in-Depth** - Complement rkhunter and auditd monitoring
