# Ubuntu Server Security - Roadmap

This repository provides **12 production-ready security components** for Ubuntu servers, all released and battle-tested.

## Vision

Provide production-ready, battle-tested security configurations for Ubuntu servers, based on:
- ✅ Real-world production experience
- ✅ CIS Benchmark alignment
- ✅ False-positive reduction methodology
- ✅ Monitoring integration (Prometheus/Grafana)
- ✅ Automation (systemd, Ansible)

## Current Release: v1.0.0 (January 2026)

**Status**: ✅ All 12 components released

### Security Layers Overview

| Layer | Component | Status | Description |
|-------|-----------|--------|-------------|
| **Boot** | boot-security | ✅ v1.0 | GRUB + UEFI password protection |
| **Kernel** | kernel-hardening | ✅ v1.0 | sysctl parameters + /tmp hardening |
| **Network** | ssh-hardening | ✅ v1.0 | 15+ CIS Benchmark controls |
| **Firewall** | ufw | ✅ v1.0 | Simple firewall (CIS-compliant, Docker-aware) |
| **Firewall** | nftables | ✅ v1.0 | Advanced firewall (NAT, Docker, WireGuard) |
| **Detection** | aide | ✅ v1.0 | Intrusion detection (99.7% false-positive reduction) |
| **Detection** | rkhunter | ✅ v1.0 | Rootkit detection (automated scanning) |
| **Logging** | auditd | ✅ v1.0 | Kernel-level audit logging (CIS 4.1.x) |
| **Access Control** | apparmor | ✅ v1.0 | Mandatory Access Control profiles |
| **Credentials** | vaultwarden | ✅ v1.0 | Credential management (no plaintext secrets) |
| **Protection** | fail2ban | ✅ v1.0 | Brute-force protection (GeoIP, Telegram) |
| **Audit** | lynis | ✅ v1.0 | Security auditing (Hardening Index 0-100) |

---

## Component Details

### Boot Security
- GRUB password protection (PBKDF2-SHA512)
- UEFI/BIOS password guide (multi-vendor)
- Automated setup script with triple-validation
- Headless-server compatible (--unrestricted)

### Kernel Hardening
- sysctl security parameters (CIS-aligned)
- /tmp partition hardening (nodev, nosuid, noexec)
- Docker-compatible configuration
- 12+ CIS Benchmark controls

### SSH Hardening
- `sshd_config.template` (146 lines, CIS-aligned)
- 3 drop-in overrides (gateway, development, minimal)
- Validation scripts (prevent SSH lockout)
- 15+ CIS Benchmark controls (5.2.1 to 5.2.16)

### UFW Firewall
- CIS Benchmark 3.5.1.x compliant
- Docker-aware documentation
- Service-specific drop-in templates
- Prometheus metrics exporter

### nftables Firewall
- Production-ready templates (Gateway, Server, Docker)
- Docker chain preservation
- WireGuard VPN integration
- NAT masquerading, rate-limiting

### AIDE (Intrusion Detection)
- 99.7% false-positive reduction
- Drop-in configuration pattern
- Production scripts (update, backup, metrics)
- Prometheus integration

### rkhunter (Rootkit Detection)
- Automated daily rootkit scans
- Weekly signature updates
- False-positive whitelisting guide
- Email alert configuration

### auditd (Kernel Audit Logging)
- CIS Benchmark 4.1.x alignment (20+ rules)
- Three rule profiles (Base, Aggressive, Docker)
- Immutable rules for production
- Prometheus metrics exporter
- SIEM-ready log format

### AppArmor
- PostgreSQL 16 profile with defense-in-depth
- Two-phase deployment (COMPLAIN → ENFORCE)
- Violation monitoring scripts
- CIS Benchmark alignment (1.6.1.x)

### Vaultwarden
- Sourced Bash library (~300 lines)
- Graceful fallback to .env files
- Session management
- Example integrations

### fail2ban
- GeoIP country-based whitelisting
- Telegram ban/unban alerts with IP context
- Prometheus metrics exporter
- Custom filters and actions

### Lynis (Security Auditing)
- Comprehensive system checks (~275 tests)
- Hardening Index tracking (0-100 score)
- Custom profiles (reduces false-positives)
- Top 20 hardening recommendations

---

## Future Considerations

Additional security components under consideration:

- **ClamAV Integration** - Malware scanning with scheduled checks
- **OSSEC/Wazuh** - Host-based IDS integration
- **SELinux Profiles** - For RHEL/Fedora compatibility
- **PAM Hardening** - Password policies and account lockout

## Contributing

Interested in contributing?

**Areas where help is appreciated**:
- Additional AppArmor/SELinux profiles
- fail2ban filters for niche services
- Grafana dashboard examples
- Testing on other Ubuntu/Debian versions
- Documentation improvements

Open an issue or pull request to discuss!

## See Also

- **Ansible Automation**: [ubuntu-server-security-ansible](https://github.com/fidpa/ubuntu-server-security-ansible) (Coming soon)
- **Related Projects**: [monitoring-templates](https://github.com/fidpa/monitoring-templates), [bash-production-toolkit](https://github.com/fidpa/bash-production-toolkit)

---

**Last Updated**: January 2026
