# Ubuntu Server Security

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/fidpa/ubuntu-server-security)](https://github.com/fidpa/ubuntu-server-security/releases)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-orange?logo=ubuntu)](https://ubuntu.com/server)
[![CI](https://github.com/fidpa/ubuntu-server-security/actions/workflows/lint.yml/badge.svg)](https://github.com/fidpa/ubuntu-server-security/actions/workflows/lint.yml)
![Last Commit](https://img.shields.io/github/last-commit/fidpa/ubuntu-server-security)

Security configuration templates for Ubuntu servers, in 14 components.

Hardening a server means configuring a dozen tools that do not know about each
other. AIDE reports thousands of changes a day until its excludes match the
machine, fail2ban and nftables both want to own the firewall table, and every
script that needs a password ends up with it in plaintext. The configurations
here are the ones that came out of that work on production servers: drop-in
files, deploy scripts and per-component documentation, one directory per tool.

## Components

| Component | Description |
|-----------|-------------|
| **[boot-security/](boot-security/)** | GRUB and UEFI password protection |
| **[kernel-hardening/](kernel-hardening/)** | Kernel parameters via sysctl, plus /tmp isolation |
| **[usb-defense/](usb-defense/)** | Kernel blacklist, udev watcher, auditd bypass monitoring |
| **[ssh-hardening/](ssh-hardening/)** | sshd config template with documented CIS 5.2.x mapping |
| **[ufw/](ufw/)** | UFW baseline with Docker-aware rules |
| **[nftables/](nftables/)** | NAT, Docker chain preservation, WireGuard, rate limiting |
| **[aide/](aide/)** | File integrity monitoring with production-tuned excludes |
| **[rkhunter/](rkhunter/)** | Rootkit detection with a documented false-positive baseline |
| **[auditd/](auditd/)** | Kernel-level audit rules, mapped to CIS 4.1.x |
| **[apparmor/](apparmor/)** | PostgreSQL 16 profile and violation checker |
| **[vaultwarden/](vaultwarden/)** | Bash library that reads credentials from Bitwarden CLI |
| **[fail2ban/](fail2ban/)** | Jails for SSH, nginx, Apache, Postfix, Dovecot, with GeoIP and Telegram |
| **[security-monitoring/](security-monitoring/)** | Log aggregation with deduplication and Telegram alerts |
| **[lynis/](lynis/)** | Audit profile and Hardening Index export |

## Features

- **Drop-in configuration everywhere**: AIDE ships 7 exclude files, nftables 6
  rule templates, UFW 4 service rule sets. Nothing replaces a distribution file
  wholesale.
- **AIDE noise reduction, measured**: 3,799 changes per day down to 12 on the
  reference server, a factor of 316. How the excludes get there is in
  [docs/FALSE_POSITIVE_REDUCTION.md](docs/FALSE_POSITIVE_REDUCTION.md).
- **SSH: 15 of 18 applicable CIS 5.2.x controls fully implemented**, three
  relaxed by named override patterns, two not applicable. The tally, measured
  against CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0, is in
  [ssh-hardening/docs/CIS_CONTROLS.md](ssh-hardening/docs/CIS_CONTROLS.md).
- **CIS mapping per component**: each config states the control family it
  addresses, see [the table below](#cis-benchmark-mapping).
- **Prometheus text-format exporters** for aide, auditd, fail2ban and lynis,
  written for node_exporter's textfile collector.
- **systemd timer templates** for the three jobs that need a schedule: AIDE
  database update, USB activity check, security log monitor.
- **Docker-aware firewalling**: the nftables templates flush single tables
  rather than the ruleset, so the `DOCKER` and `DOCKER-USER` chains created at
  runtime survive a reload; the UFW rules use `DOCKER-USER` for the same reason.
- **Every script passes ShellCheck** at `--severity=error` and `bash -n` in CI
  on each push.

## Known Limitations

> **IMPORTANT**: This is a collection of configuration templates, not a
> turnkey hardening product.
>
> - `install.sh` automates 7 of the 14 components (boot-security,
>   kernel-hardening, usb-defense, nftables, auditd, fail2ban, lynis). For the
>   other seven it prints the path to that component's `docs/SETUP.md` and
>   stops; `./install.sh --list` marks each component `script` or `manual`.
> - `--dry-run` names the installer it would run. Two components dry-run
>   themselves and report what they would touch, fail2ban and lynis; both need
>   `sudo` for it, because the dry run reads the configuration it would
>   replace.
> - The scripts are not idempotent installers and carry no rollback. Templates
>   are meant to be read and adapted before they are copied.
> - CI checks shell syntax. It does not run the configurations against a live
>   system; that verification is manual, with `lynis audit system` as the
>   closest thing to an automated check.
> - The CIS tables document which controls a config addresses. That is a
>   mapping, not an audit, and no certification follows from it.
> - Boot and SSH hardening can lock you out. Both need a second, already open
>   session or console access while you test.

## Quick Start

```bash
git clone https://github.com/fidpa/ubuntu-server-security.git
cd ubuntu-server-security

# What is available, and which components have an installer
./install.sh --list

# Preview a component without touching the system
./install.sh --dry-run kernel-hardening

# fail2ban and lynis dry-run themselves, in detail, as root
sudo ./install.sh --dry-run fail2ban

# Install one of the seven automated components
sudo ./install.sh fail2ban
```

The other seven are copy-and-adapt. Read the component's `README.md` first;
the commands below are the shape of it, not a substitute:

```bash
# SSH: validate before restarting, and keep a second session open
sudo cp ssh-hardening/sshd_config.template /etc/ssh/sshd_config
./ssh-hardening/scripts/validate-sshd-config.sh
sudo systemctl restart sshd

# UFW baseline
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp
sudo ufw enable

# AIDE with the tuned excludes
sudo apt install aide aide-common
sudo cp aide/aide.conf.template /etc/aide/aide.conf
sudo cp aide/drop-ins/*.conf /etc/aide/aide.conf.d/
sudo aideinit

# rkhunter
sudo apt install rkhunter
sudo rkhunter --propupd
```

Full guides: each component's `README.md` and [docs/SETUP.md](docs/SETUP.md).

## Component Overview

### Security Layers

| Layer | Component | Purpose |
|-------|-----------|---------|
| **Boot** | boot-security | Prevent unauthorized boot modifications |
| **Kernel** | kernel-hardening | Harden kernel parameters, /tmp isolation |
| **Hardware** | usb-defense | Block USB-based attacks |
| **Network** | ssh-hardening | Secure remote access |
| **Firewall** | ufw / nftables | Control network traffic |
| **Detection** | aide, rkhunter, fail2ban | Detect intrusions and rootkits |
| **Logging** | auditd | Kernel-level event logging |
| **Access Control** | apparmor | Mandatory Access Control |
| **Credentials** | vaultwarden | Keep secrets out of scripts and .env files |
| **Monitoring** | security-monitoring | Aggregate events from the layers above |
| **Audit** | lynis | Score the result and list what is still open |

The layers are meant to be combined; each one also works alone.

### Firewall Selection Guide

| Use Case | Component | Why |
|----------|-----------|-----|
| Simple server (web, database, NAS) | **UFW** | Easy syntax, CIS 3.5.1.x mapping |
| Gateway / Router | **nftables** | NAT, routing, Multi-WAN |
| WireGuard VPN server | **nftables** | Native VPN integration |
| Docker host (simple) | **UFW** | With Docker-aware patterns |
| Docker host (advanced) | **nftables** | Chain preservation, custom rules |

Running both at once means two tools writing the same netfilter tables. Pick one.

### Detection and Monitoring

| Component | Method | Best For |
|-----------|--------|----------|
| **AIDE** | Integrity-based | Detecting file changes |
| **rkhunter** | Signature-based | Detecting known rootkits |
| **auditd** | Event-based | Real-time "who did what when" |
| **fail2ban** | Pattern-based | Blocking brute-force attacks |
| **security-monitoring** | Aggregation-based | One alert stream instead of six |
| **Lynis** | Audit-based | Periodic posture assessment |

## Key Concepts

### Drop-in Configuration Pattern

Components ship modular drop-in files instead of one monolithic config:

```
aide/drop-ins/                       nftables/drop-ins/
├── 10-docker-excludes.conf          ├── 10-gateway.nft.template
├── 15-monitoring-excludes.conf      ├── 20-server.nft.template
├── 20-postgresql-excludes.conf      ├── 40-docker.nft.template
├── 40-systemd-excludes.conf         ├── 50-vpn-wireguard.nft.template
└── 99-custom.conf.example           └── 60-rate-limiting.nft.template
```

A package update replaces the base file and leaves the drop-ins alone, and a
service that goes away takes exactly one file with it. `99-custom.conf.example`
is the copy-and-rename slot for host-specific rules.

### CIS Benchmark Mapping

| Component | CIS Controls |
|-----------|--------------|
| boot-security | 1.4.x (Boot settings) |
| kernel-hardening | 1.5.x, 3.2.x (Kernel params) |
| usb-defense | Not covered by CIS (physical access) |
| ssh-hardening | 5.2.x (SSH configuration) |
| ufw | 3.5.1.x (UFW firewall) |
| nftables | 3.5.3.x (nftables firewall) |
| aide | 1.3.x (File integrity) |
| auditd | 4.1.x (System accounting) |
| apparmor | 1.6.x (MAC) |
| lynis | Audits across all families |

## Requirements

**Minimum**:
- Ubuntu 22.04 LTS or 24.04 LTS
- systemd (for the timer templates)
- Root/sudo access

**Component-specific**:
- nftables 1.0+ (for the advanced firewall templates)
- AIDE 0.18.6+ (for `num_workers` and the modern hash algorithms)
- UFW (present on Ubuntu and Debian by default)
- Bitwarden CLI (`bw`) for the vaultwarden library

**Optional**:
- Prometheus and node_exporter with the textfile collector, for the four exporters
- A Vaultwarden or Bitwarden server behind the CLI
- A Telegram bot token, for the fail2ban and security-monitoring alerts

## Compatibility

**Tested**:
- Ubuntu 22.04 LTS, 24.04 LTS

**Should work, untested**:
- Debian 11 (Bullseye) and 12 (Bookworm), Raspberry Pi OS. Same package names
  and the same systemd, but no run of this repository has been recorded on them.

**Not supported**:
- RHEL, Fedora, Rocky Linux: SELinux instead of AppArmor, firewalld instead of
  UFW. The distribution-neutral parts (kernel-hardening, ssh-hardening, aide,
  rkhunter, auditd) are the transferable ones, and they still need adapting.
- Immutable or container-only systems: several components write to /etc and
  install systemd units.

## Where This Fits

**Suitable for**:
- Single servers and small fleets that are configured by hand
- Container hosts: the kernel, firewall and AIDE templates account for Docker
- Network gateways: nftables with NAT, WireGuard and Multi-WAN
- Reading material: each component documents why a setting is what it is

**Not recommended for**:
- Fleet rollout: there is no Ansible or Puppet integration here
- Hosts without out-of-band access, given the boot and SSH lockout risk
- Anyone who needs a compliance certificate rather than a control mapping
- Desktop systems: the USB and SSH defaults get in the way of normal use

## Documentation

| Component | Key Docs |
|-----------|----------|
| boot-security | [GRUB_PASSWORD.md](boot-security/docs/GRUB_PASSWORD.md), [UEFI_PASSWORD.md](boot-security/docs/UEFI_PASSWORD.md) |
| kernel-hardening | [TMP_HARDENING.md](kernel-hardening/docs/TMP_HARDENING.md), [SETUP.md](kernel-hardening/docs/SETUP.md) |
| usb-defense | [THREE_LAYER_DEFENSE.md](usb-defense/docs/THREE_LAYER_DEFENSE.md), [ALERT_CONFIGURATION.md](usb-defense/docs/ALERT_CONFIGURATION.md) |
| ssh-hardening | [CIS_CONTROLS.md](ssh-hardening/docs/CIS_CONTROLS.md), [OVERRIDE_PATTERNS.md](ssh-hardening/docs/OVERRIDE_PATTERNS.md) |
| ufw | [SETUP.md](ufw/docs/SETUP.md), [DOCKER_NETWORKING.md](ufw/docs/DOCKER_NETWORKING.md) |
| nftables | [NFTABLES_RULES.md](nftables/docs/NFTABLES_RULES.md), [WIREGUARD_INTEGRATION.md](nftables/docs/WIREGUARD_INTEGRATION.md) |
| aide | [FALSE_POSITIVE_REDUCTION.md](aide/docs/FALSE_POSITIVE_REDUCTION.md), [BOOT_RESILIENCY.md](aide/docs/BOOT_RESILIENCY.md) |
| rkhunter | [FALSE_POSITIVES.md](rkhunter/docs/FALSE_POSITIVES.md), [SETUP.md](rkhunter/docs/SETUP.md) |
| auditd | [CIS_CONTROLS.md](auditd/docs/CIS_CONTROLS.md), [SETUP.md](auditd/docs/SETUP.md) |
| apparmor | [POSTGRESQL_PROFILE.md](apparmor/docs/POSTGRESQL_PROFILE.md), [TROUBLESHOOTING.md](apparmor/docs/TROUBLESHOOTING.md) |
| fail2ban | [GEOIP_FILTERING.md](fail2ban/docs/GEOIP_FILTERING.md), [TELEGRAM_INTEGRATION.md](fail2ban/docs/TELEGRAM_INTEGRATION.md) |
| security-monitoring | [CONFIGURATION.md](security-monitoring/docs/CONFIGURATION.md), [SETUP.md](security-monitoring/docs/SETUP.md) |
| lynis | [HARDENING_GUIDE.md](lynis/docs/HARDENING_GUIDE.md), [CUSTOM_PROFILES.md](lynis/docs/CUSTOM_PROFILES.md) |

**Repository-level docs**:

| Document | Description |
|----------|-------------|
| [docs/SETUP.md](docs/SETUP.md) | General installation guide |
| [docs/BEST_PRACTICES.md](docs/BEST_PRACTICES.md) | Production lessons |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues |
| [docs/FALSE_POSITIVE_REDUCTION.md](docs/FALSE_POSITIVE_REDUCTION.md) | How the AIDE excludes were derived |
| [docs/IMMUTABLE_BINARY_PROTECTION.md](docs/IMMUTABLE_BINARY_PROTECTION.md) | Protecting the detection binaries themselves |
| [docs/FAILURE_ALERTING.md](docs/FAILURE_ALERTING.md) | Alerting when a check stops running |
| [docs/PROMETHEUS_INTEGRATION.md](docs/PROMETHEUS_INTEGRATION.md) | Metrics setup |
| [docs/VAULTWARDEN_INTEGRATION.md](docs/VAULTWARDEN_INTEGRATION.md) | Credentials in scripts and units |
| [docs/ROADMAP.md](docs/ROADMAP.md) | What is planned |
| [CHANGELOG.md](CHANGELOG.md) | Version history |
| [SECURITY.md](SECURITY.md) | Reporting a vulnerability |

## See Also

- [linux-monitoring-templates](https://github.com/fidpa/linux-monitoring-templates) - Prometheus and Grafana templates
- [bash-production-toolkit](https://github.com/fidpa/bash-production-toolkit) - Bash libraries for logging, retry and security

## License

MIT License, see [LICENSE](LICENSE).

## Author

Marc Allgeier ([@fidpa](https://github.com/fidpa))

## Contributing

Issues and pull requests are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md).
Drop-in configs for further services (MySQL, Redis, nginx), firewall templates
for setups not covered here, Grafana dashboards and reports from Debian or
Raspberry Pi OS are the gaps worth filling.
