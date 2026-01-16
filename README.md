# Ubuntu Server Security

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-orange?logo=ubuntu)
![CIS Benchmark](https://img.shields.io/badge/CIS%20Benchmark-100%25-blue)

Production-ready security configurations for Ubuntu servers.

**The Problem**: Security tools are powerful but complex to configure. Default settings generate noise, integrations are missing, and credentials are stored in plaintext. After weeks of hardening production servers to 100% CIS Benchmark compliance, I've extracted 14 battle-tested security components.

## Components

| Component | Description |
|-----------|-------------|
| **[boot-security/](boot-security/)** | GRUB + UEFI password protection (defense-in-depth) |
| **[kernel-hardening/](kernel-hardening/)** | Kernel security via sysctl parameters + /tmp hardening |
| **[usb-defense/](usb-defense/)** | 3-layer USB defense system (kernel blacklist + real-time detection + auditd) |
| **[ssh-hardening/](ssh-hardening/)** | SSH hardening with 15+ CIS Benchmark controls |
| **[ufw/](ufw/)** | UFW Firewall baseline (CIS-compliant, Docker-aware) |
| **[nftables/](nftables/)** | Advanced firewall (NAT, Docker, WireGuard VPN, rate-limiting) |
| **[aide/](aide/)** | Intrusion Detection with 99.7% false-positive reduction |
| **[rkhunter/](rkhunter/)** | Rootkit detection with automated scanning |
| **[auditd/](auditd/)** | Kernel-level audit logging (CIS 4.1.x, SIEM-ready) |
| **[apparmor/](apparmor/)** | Mandatory Access Control profiles (PostgreSQL, Docker) |
| **[vaultwarden/](vaultwarden/)** | Credential management via Bitwarden CLI (no plaintext secrets) |
| **[fail2ban/](fail2ban/)** | Brute-force protection (GeoIP filtering, Telegram alerts) |
| **[security-monitoring/](security-monitoring/)** | Unified security event monitoring with smart deduplication |
| **[lynis/](lynis/)** | Security auditing & hardening recommendations (CIS compliance) |

## Features

- ✅ **Defense-in-Depth** - 14 complementary security layers (boot → kernel → hardware → network → detection → logging → audit → monitoring)
- ✅ **CIS Benchmark Compliance** - 40+ controls across all components
- ✅ **Drop-in Configuration Pattern** - Modular configs for all components
- ✅ **Docker-Compatible** - All hardening tested with containerized workloads
- ✅ **Prometheus Integration** - Metrics exporters for monitoring
- ✅ **systemd Automation** - Daily checks with configurable schedules
- ✅ **Production-Proven** - Running on multiple Ubuntu servers with 100% CIS compliance

## Quick Start

Each component has its own README with detailed setup instructions. Here's a quick overview:

```bash
# Clone the repository
git clone https://github.com/fidpa/ubuntu-server-security.git
cd ubuntu-server-security

# Choose components based on your needs:

# 1. Boot Security (prevents unauthorized boot modifications)
sudo ./boot-security/scripts/setup-grub-password.sh

# 2. Kernel Hardening (sysctl + /tmp hardening)
sudo ./kernel-hardening/scripts/setup-kernel-hardening.sh

# 3. USB Defense (3-layer protection against USB attacks)
sudo ./usb-defense/scripts/deploy-usb-defense.sh

# 4. SSH Hardening (key-only auth, modern crypto)
sudo cp ssh-hardening/sshd_config.template /etc/ssh/sshd_config
./ssh-hardening/scripts/validate-sshd-config.sh
sudo systemctl restart sshd

# 4. UFW Firewall (simple servers)
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp
sudo ufw enable

# 6. nftables Firewall (gateways, advanced setups)
sudo cp nftables/drop-ins/20-server.nft.template /etc/nftables.conf
sudo nftables/scripts/validate-nftables.sh /etc/nftables.conf
sudo nftables/scripts/deploy-nftables.sh /etc/nftables.conf

# 7. AIDE (intrusion detection)
sudo apt install aide aide-common
sudo cp aide/aide.conf.template /etc/aide/aide.conf
sudo cp aide/drop-ins/*.conf /etc/aide/aide.conf.d/
sudo aideinit

# 8. rkhunter (rootkit detection)
sudo apt install rkhunter
sudo rkhunter --propupd
```

**Full guides**: See each component's `README.md` and `docs/SETUP.md`.

## Component Overview

### Security Layers

| Layer | Component | Purpose |
|-------|-----------|---------|
| **Boot** | boot-security | Prevent unauthorized boot modifications |
| **Kernel** | kernel-hardening | Harden kernel parameters, /tmp isolation |
| **Hardware** | usb-defense | Block USB-based attacks (3-layer defense) |
| **Network** | ssh-hardening | Secure remote access |
| **Firewall** | ufw / nftables | Control network traffic |
| **Detection** | aide, rkhunter, fail2ban | Detect intrusions and rootkits |
| **Logging** | auditd | Kernel-level event logging |
| **Access Control** | apparmor | Mandatory Access Control |
| **Credentials** | vaultwarden | Eliminate plaintext secrets |
| **Monitoring** | security-monitoring | Unified security event monitoring |
| **Audit** | lynis | Comprehensive security auditing |

### Firewall Selection Guide

| Use Case | Component | Why |
|----------|-----------|-----|
| Simple server (web, database, NAS) | **UFW** | Easy syntax, CIS-compliant |
| Gateway / Router | **nftables** | NAT, routing, Multi-WAN |
| WireGuard VPN server | **nftables** | Native VPN integration |
| Docker host (simple) | **UFW** | With Docker-aware patterns |
| Docker host (advanced) | **nftables** | Chain preservation, custom rules |

### Detection & Monitoring Components

| Component | Method | Best For |
|-----------|--------|----------|
| **AIDE** | Integrity-based | Detecting file changes |
| **rkhunter** | Signature-based | Detecting known rootkits |
| **auditd** | Event-based | Real-time "who did what when" |
| **fail2ban** | Pattern-based | Blocking brute-force attacks |
| **security-monitoring** | Aggregation-based | Unified event monitoring with smart deduplication |
| **Lynis** | Audit-based | Comprehensive security posture assessment |

**Recommendation**: Use all six for defense-in-depth.

## Key Concepts

### Drop-in Configuration Pattern

All components use modular drop-in configurations instead of monolithic files:

```
# AIDE drop-ins
/etc/aide/aide.conf.d/
├── 10-docker-excludes.conf
├── 20-postgresql-excludes.conf
└── 99-custom.conf

# nftables drop-ins
nftables/drop-ins/
├── 10-gateway.nft.template
├── 20-server.nft.template
└── 40-docker.nft.template

# UFW drop-ins
ufw/drop-ins/
├── 10-webserver.rules
├── 20-database.rules
└── 30-monitoring.rules
```

**Benefits**: Easier maintenance, service-specific configs, no merge conflicts.

### CIS Benchmark Alignment

| Component | CIS Controls |
|-----------|--------------|
| boot-security | 1.4.x (Boot settings) |
| kernel-hardening | 1.5.x, 3.2.x (Kernel params) |
| usb-defense | Physical security (not in CIS, but defense-in-depth) |
| ssh-hardening | 5.2.x (SSH configuration) |
| ufw | 3.5.1.x (UFW firewall) |
| nftables | 3.5.3.x (nftables firewall) |
| aide | 1.3.x (File integrity) |
| auditd | 4.1.x (System accounting) |
| apparmor | 1.6.x (MAC) |
| lynis | Various (audit all controls) |

## Requirements

**Minimum**:
- Ubuntu 22.04 LTS or 24.04 LTS (or compatible distro)
- systemd (for timer automation)
- Root/sudo access

**Component-specific**:
- nftables 1.0+ (for advanced firewall features)
- AIDE v0.18.6+ (for modern hash algorithms)
- UFW (included in Ubuntu/Debian by default)

**Optional**:
- Prometheus + node_exporter (for metrics)
- Vaultwarden/Bitwarden server (for credential management)

## Compatibility

**Fully supported**:
- Ubuntu 22.04 LTS, 24.04 LTS
- Debian 11 (Bullseye), 12 (Bookworm)
- Raspberry Pi OS (Debian-based)

**Partial support** (no AppArmor/UFW components):
- RHEL / Fedora / Rocky Linux (use SELinux + firewalld instead)
- Other systemd-based distros (boot-security, kernel-hardening, ssh-hardening, nftables, aide, rkhunter work)

## Use Cases

- ✅ **Enterprise Infrastructure** - Servers, container hosts, network gateways
- ✅ **Production Servers** - CIS Benchmark compliance with 40+ controls
- ✅ **Container Hosts** - Docker-compatible hardening (kernel, firewall, AIDE)
- ✅ **Network Gateways** - nftables with NAT, WireGuard VPN, Multi-WAN
- ✅ **Compliance** - Generate audit trails and change reports

## Documentation

Each component has its own documentation:

| Component | Key Docs |
|-----------|----------|
| boot-security | [GRUB_PASSWORD.md](boot-security/docs/GRUB_PASSWORD.md), [UEFI_PASSWORD.md](boot-security/docs/UEFI_PASSWORD.md) |
| usb-defense | [THREE_LAYER_DEFENSE.md](usb-defense/docs/THREE_LAYER_DEFENSE.md), [SETUP.md](usb-defense/docs/SETUP.md) |
| ssh-hardening | [CIS_CONTROLS.md](ssh-hardening/docs/CIS_CONTROLS.md), [SETUP.md](ssh-hardening/docs/SETUP.md) |
| ufw | [SETUP.md](ufw/docs/SETUP.md), [DOCKER_NETWORKING.md](ufw/docs/DOCKER_NETWORKING.md) |
| nftables | [SETUP.md](nftables/docs/SETUP.md), [WIREGUARD_INTEGRATION.md](nftables/docs/WIREGUARD_INTEGRATION.md) |
| aide | [FALSE_POSITIVE_REDUCTION.md](aide/docs/FALSE_POSITIVE_REDUCTION.md) |
| rkhunter | [FALSE_POSITIVES.md](rkhunter/docs/FALSE_POSITIVES.md) |
| auditd | [CIS_CONTROLS.md](auditd/docs/CIS_CONTROLS.md), [SETUP.md](auditd/docs/SETUP.md) |
| lynis | [HARDENING_GUIDE.md](lynis/docs/HARDENING_GUIDE.md), [SETUP.md](lynis/docs/SETUP.md) |

**Repository-level docs**:

| Document | Description |
|----------|-------------|
| [docs/SETUP.md](docs/SETUP.md) | General installation guide |
| [docs/BEST_PRACTICES.md](docs/BEST_PRACTICES.md) | Production lessons |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues |
| [docs/PROMETHEUS_INTEGRATION.md](docs/PROMETHEUS_INTEGRATION.md) | Metrics setup |

## See Also

- [ubuntu-server-security-ansible](https://github.com/fidpa/ubuntu-server-security-ansible) - Ansible automation
- [monitoring-templates](https://github.com/fidpa/monitoring-templates) - Bash/Python monitoring templates
- [bash-production-toolkit](https://github.com/fidpa/bash-production-toolkit) - Production-ready Bash libraries

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

Marc Allgeier ([@fidpa](https://github.com/fidpa))

**Why I Built This**: After spending weeks hardening production servers to 100% CIS Benchmark compliance, I wished I could find everything in one place. This repo consolidates 14 production-tested security components so you don't have to piece together scattered documentation.

## Contributing

Contributions welcome! Please open an issue or pull request.

**Areas where help is appreciated**:
- Additional drop-in configs for services (MySQL, Redis, Nginx, etc.)
- Firewall templates for specific use cases
- Grafana dashboard examples
- Testing on other Ubuntu/Debian versions