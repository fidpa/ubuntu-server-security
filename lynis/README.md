# Lynis - Security Auditing

Comprehensive security auditing with Hardening Index and CIS compliance validation.

## Features

- ✅ **Hardening Index** - Numeric score (0-100) for security posture
- ✅ **CIS Compliance Checks** - Validate all CIS Benchmark controls
- ✅ **300+ Tests** - File permissions, services, kernel parameters, crypto
- ✅ **Automated Scanning** - Weekly audits via systemd timer
- ✅ **Custom Profiles** - Ubuntu-specific checks and recommendations
- ✅ **Prometheus Metrics** - Export Hardening Index for monitoring

## Quick Start

```bash
# 1. Install Lynis
sudo apt install lynis

# 2. Run full audit
sudo lynis audit system

# 3. Review report
cat /var/log/lynis-report.dat
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation, automation, and report interpretation |
| [HARDENING_GUIDE.md](docs/HARDENING_GUIDE.md) | Step-by-step hardening based on Lynis findings |
| [CIS_VALIDATION.md](docs/CIS_VALIDATION.md) | Using Lynis to validate CIS Benchmark compliance |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common warnings and how to address them |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- Lynis v3.0+
- Root/sudo access
- Optional: Prometheus + node_exporter (for metrics)

## Audit Categories

| Category | Tests | Examples |
|----------|-------|----------|
| **Boot & Services** | 40+ | Boot loader security, service configuration |
| **Kernel & Memory** | 30+ | sysctl parameters, kernel modules |
| **Authentication** | 25+ | PAM, password policies, SSH |
| **Filesystem** | 35+ | Mount options, file permissions |
| **Networking** | 30+ | Firewall rules, open ports |
| **Crypto** | 20+ | SSL/TLS certificates, key strength |

## Use Cases

- ✅ **Baseline Audits** - Establish security posture before hardening
- ✅ **Compliance Validation** - Verify CIS Benchmark implementation
- ✅ **Progress Tracking** - Monitor Hardening Index over time (60% → 95%)
- ✅ **Continuous Monitoring** - Weekly automated audits with Prometheus
- ✅ **Pre-Production Checks** - Validate hardening before going live

## Resources

- [Lynis Official Documentation](https://cisofy.com/documentation/lynis/)
- [Lynis GitHub Repository](https://github.com/CISOfy/lynis)
- [Ubuntu Lynis Package](https://packages.ubuntu.com/search?keywords=lynis)
