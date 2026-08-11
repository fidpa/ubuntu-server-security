# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Additional security component integrations
- Ansible playbook support
- Docker security hardening module

## [1.1.3] - 2026-08-11

### Fixed
- Restored the missing executable bit on 14 scripts across `aide/`,
  `apparmor/`, `auditd/`, `boot-security/`, `kernel-hardening/`, `nftables/`,
  `ssh-hardening/`, and `ufw/`. They were checked in as `100644` and could not
  be run directly (`./script.sh`); only `bash script.sh` worked. Content is
  unchanged, only the file mode.

## [1.1.2] - 2026-08-09

Housekeeping release. No hardening rule, default, or access path changes -- every
change below is documentation, tooling, or repository hygiene. It is safe to
apply on a running server, and it changes nothing on one.

Two release commits (`1.1.0` and `1.1.1`) were never tagged, so the last
published release was `v1.0.1` from January 2026. This release supersedes both;
`v1.1.0` and `v1.1.1` will not receive tags of their own.

### Added
- `VERSION` file in the repository root as the single source of the project
  version. `install.sh` reads it at runtime and falls back to `unknown` instead
  of failing. Until now `install.sh` reported `1.0.0` while the changelog was at
  `1.1.1` -- two minor releases of drift in the one number an operator uses to
  answer "which hardening level is running on this server?".
- `.github/ISSUE_TEMPLATE/` (bug report, feature request, config) and
  `.github/PULL_REQUEST_TEMPLATE.md`.

### Changed
- `.github/workflows/release.yml` now builds the release notes from the matching
  `CHANGELOG.md` section instead of `generate_release_notes: true`. Because
  every commit message in this repository is a bare `vX.Y.Z` line, the generated
  notes carried no information at all. The job fails loudly when a tag has no
  usable changelog section rather than publishing an empty release.
  `softprops/action-gh-release` moved from `v1` to `v2`.
- `.shellcheckrc`: the `severity=warning` line was removed. ShellCheck has no
  `severity` key for that file and discards unknown keys without a diagnostic,
  so the line looked like a setting and did nothing. Measured across all 40
  scripts: 49 messages with the line present, 49 with a nonsense key in its
  place, 37 with `--severity=warning` on the command line. The binding threshold
  lives in `lint.yml` (`--severity=error`) and is now documented as such.
- `fail2ban/actions/telegram-send.sh` (2.0.0 -> 2.0.1): the alert prefix no
  longer hardcodes two specific hostnames. It defaults to the short hostname,
  documents how to add per-host cases, and now honours an `ALERT_PREFIX` set in
  the secrets file -- previously the script documented no such override and
  would have discarded one, because the assignment was unconditional.

### Fixed
- Four broken relative documentation links: `aide/README.md` and
  `aide/docs/SETUP.md` pointed at `PROMETHEUS_INTEGRATION.md` and
  `FAILURE_ALERTING.md` inside the component directory, while both live in the
  repository-level `docs/`; `fail2ban/README.md` linked `TELEGRAM_ALERTS.md`,
  which is named `TELEGRAM_INTEGRATION.md`.
- `CHANGELOG.md`: the `1.1.1` release had no link definition and no row in the
  version history table. Both were added. The `1.1.0` and `1.1.1` link
  definitions now point at their commits rather than at compare ranges between
  tags that were never created, which returned 404.

### Removed
- `aide/LINKEDIN_POST.md` and `aide/REDDIT_POST.md`. Both were tracked and
  therefore public. `.gitignore` carries matching entries, but ignore rules only
  apply to untracked files -- `git check-ignore` reports them as *not* ignored,
  which reads like a different problem. The root-level copies were removed in
  January 2026; these two were missed.

### Security
- Removed private infrastructure details and real identifiers from the published
  documentation. None of these affected the hardening rules themselves, but all
  of them were public:
  - `.shellcheckrc` header described a private multi-device setup, including
    device roles and script counts.
  - `fail2ban/actions/telegram-send.sh` and its documentation mapped two real
    hostnames to display names.
  - `nftables/docs/WIREGUARD_INTEGRATION.md` used a real, resolvable hostname as
    a WireGuard endpoint; it now uses `vpn.example.com` (RFC 2606).
  - `ufw/docs/SETUP.md` and `usb-defense/docs/THREE_LAYER_DEFENSE.md` used a
    real account name in sudoers and audit-log examples; both now use `admin`.
  - `fail2ban/docs/GEOIP_FILTERING.md` used a real, publicly routed third-party
    address as a GeoIP test target. The examples now derive one at runtime.
  - Five nftables files credited a specific private device by name and twice
    cited an internal incident document by filename -- a document no reader can
    open. The technical substance is unchanged; the attribution is now generic
    ("a production gateway config"). Generic references to Raspberry Pi OS as a
    supported platform are deliberately kept.
- Translated the remaining German documentation into English: the whole of
  `ufw/docs/` and `ufw/examples/`, `ufw/drop-ins/README.md`, and one code
  comment in `security-monitoring/scripts/security-log-monitor.sh`. This is not
  cosmetic for a security repository: a reader who cannot read a rule's
  rationale applies the rule without understanding it.

### Upgrade notes

None required. No firewall rule, sshd option, sysctl value, fail2ban threshold,
or installation path changed. `install.sh --version` now reports the repository
version instead of `1.0.0`; if any tooling parsed that constant, it will now see
`1.1.2`.

## [1.1.1] - 2026-07-26

### Added
- `README.md`: release and last-commit badges.

  *(This entry was written in German in the original 1.1.1 release and has been
  translated here. Its content is unchanged.)*

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
| 1.1.3 | 2026-08-11 | Fix missing executable bit on 14 scripts |
| 1.1.2 | 2026-08-09 | Publishing hygiene, single-source version, changelog-driven release notes |
| 1.1.1 | 2026-07-26 | Release and last-commit badges |
| 1.1.0 | 2026-01-21 | CI/CD pipeline with GitHub Actions (ShellCheck, automated releases) |
| 1.0.1 | 2026-01-20 | Documentation patch (CODE_OF_CONDUCT.md contact update) |
| 1.0.0 | 2026-01-20 | Initial release with 14 security components |

[Unreleased]: https://github.com/fidpa/ubuntu-server-security/compare/v1.1.3...HEAD
[1.1.3]: https://github.com/fidpa/ubuntu-server-security/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/fidpa/ubuntu-server-security/compare/v1.0.1...v1.1.2
[1.1.1]: https://github.com/fidpa/ubuntu-server-security/commit/e13045f
[1.1.0]: https://github.com/fidpa/ubuntu-server-security/commit/d509c22
[1.0.1]: https://github.com/fidpa/ubuntu-server-security/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/fidpa/ubuntu-server-security/releases/tag/v1.0.0
