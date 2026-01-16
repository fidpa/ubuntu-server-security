# auditd - Linux Audit Daemon

Kernel-level audit logging with CIS Benchmark 4.1.x rules and SIEM-ready output.

## Features

- ✅ **CIS Benchmark Aligned** - 20+ rules from CIS Ubuntu Linux Benchmark 4.1.x
- ✅ **Three Rule Profiles** - Base (Level 1), Aggressive (Level 2), Docker-aware
- ✅ **Immutable Rules** - Prevents tampering (requires reboot to change)
- ✅ **Prometheus Metrics** - Export audit statistics for monitoring
- ✅ **SIEM-Ready** - Standard format for log aggregation (rsyslog, Filebeat)
- ✅ **Production Scripts** - Deploy, validate, and monitor audit rules

## Quick Start

```bash
# 1. Install auditd
sudo apt install auditd audispd-plugins

# 2. Deploy CIS-aligned rules (choose one)
sudo cp audit-base.rules.template /etc/audit/rules.d/99-cis-base.rules

# 3. Load rules
sudo augenrules --load
sudo systemctl restart auditd
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation, rule deployment, and SIEM integration |
| [CIS_CONTROLS.md](docs/CIS_CONTROLS.md) | CIS Benchmark 4.1.x mapping and rule explanations |
| [RULE_PROFILES.md](docs/RULE_PROFILES.md) | Base vs Aggressive vs Docker-aware profiles |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues (log rotation, performance impact) |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- auditd v3.0+
- Root/sudo access
- Optional: Prometheus + node_exporter (for metrics)

## Rule Profiles

| Profile | Level | Rules | Use Case |
|---------|-------|-------|----------|
| **Base** | CIS Level 1 | ~50 rules | Production servers (balanced) |
| **Aggressive** | CIS Level 2 / STIG | ~80 rules | High-security environments |
| **Docker-aware** | Custom | ~60 rules | Container hosts (excludes Docker paths) |

## Use Cases

- ✅ **Production Servers** - Real-time "who did what when" forensics
- ✅ **Compliance** - Meet CIS Benchmark and STIG requirements
- ✅ **Incident Response** - Kernel-level event logging for investigations
- ✅ **SIEM Integration** - Feed logs to Splunk, ELK, or other SIEMs
- ✅ **Container Hosts** - Monitor Docker configuration changes

## Resources

- [Linux Audit Documentation](https://github.com/linux-audit/audit-documentation)
- [CIS Ubuntu Linux Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [Red Hat auditd Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/security_guide/chap-system_auditing)
