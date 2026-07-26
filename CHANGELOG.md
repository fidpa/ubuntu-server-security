# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Additional security component integrations
- Ansible playbook support
- Docker security hardening module

## [1.1.1] - 2026-07-26

### Added
- `README.md`: Release- und Last-Commit-Badge ergänzt.

## [1.1.0] - 2026-01-21

### Added
- CI/CD pipeline with GitHub Actions
- ShellCheck linting workflow (severity: error)
- Bash syntax validation workflow
- Automated release workflow
- `.shellcheckrc` configuration (Best Practices 2025)
- CI status badge in README.md

### Changed
- All bash scripts now validated on every push to main branch

## [1.0.1] - 2026-01-20

### Changed
- **CODE_OF_CONDUCT.md**: Updated contact method from email to GitHub Issues for abuse reporting

### Added
- CONTRIBUTING.md with development guidelines
- CODE_OF_CONDUCT.md (Contributor Covenant v2.1)
- SECURITY.md with vulnerability reporting process

## [1.0.0] - 2026-01-20

### Added

#### Core Components
- **fail2ban/**: Intrusion prevention with 15+ jail configurations
- **ssh-hardening/**: SSH hardening with secure sshd_config templates
- **nftables/**: Modern firewall with modular rule sets
- **ufw/**: Simplified firewall alternative
- **aide/**: File integrity monitoring with systemd integration
- **lynis/**: Security auditing with automation scripts
- **rkhunter/**: Rootkit detection and prevention
- **auditd/**: Kernel-level audit logging
- **apparmor/**: Mandatory access control profiles

#### Advanced Security
- **kernel-hardening/**: sysctl security configurations
- **boot-security/**: GRUB password protection
- **usb-defense/**: USB device access control
- **vaultwarden/**: Credential management integration
- **security-monitoring/**: Prometheus exporters and Grafana dashboards

#### Documentation
- Comprehensive README with Quick Start guide
- CIS Benchmark alignment documentation
- Troubleshooting guide
- Best practices documentation
- Prometheus/Grafana integration guide

### Security
- All configurations aligned with CIS Ubuntu Benchmark
- Defense-in-depth approach with 14 security layers
- Secure defaults for all components

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.1.0 | 2026-01-21 | CI/CD pipeline with GitHub Actions (ShellCheck, automated releases) |
| 1.0.1 | 2026-01-20 | Documentation patch (CODE_OF_CONDUCT.md contact update) |
| 1.0.0 | 2026-01-20 | Initial release with 14 security components |

[Unreleased]: https://github.com/fidpa/ubuntu-server-security/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/fidpa/ubuntu-server-security/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/fidpa/ubuntu-server-security/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/fidpa/ubuntu-server-security/releases/tag/v1.0.0
