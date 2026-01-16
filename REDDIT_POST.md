# Reddit Post: Ubuntu Server Security

---

## Subreddits

**Tier 1** (Post hier zuerst):
- **r/selfhosted** (553k members) - Perfekte Zielgruppe (NAS, Nextcloud, self-hosted apps)
- **r/homelab** (903k members) - Größte Community, Security-interessiert
- **r/Ubuntu** (209k members) - Direktes OS-Match, sehr receptive

**Tier 2** (Falls Tier 1 gut ankommt):
- **r/linuxadmin** (200k members) - Professionelle Linux-Admins
- **r/netsec** (540k members) - Security-fokussiert (strenge Regeln, keine self-promotion)

**Nicht empfohlen**:
- r/linux (1M+ members) - Zu groß, zu generisch, könnte als spam wahrgenommen werden
- r/sysadmin - Windows-lastig, nicht ideal für Ubuntu-spezifisches
- r/devops - CI/CD-Fokus, nicht primär Security

**Posting-Strategie**:
1. **Start mit r/selfhosted** - Beste Zielgruppen-Passung, liebt OC (Original Content)
2. **r/Ubuntu** als zweites - Kleinere, fokussierte Community, sehr receptive
3. **r/homelab** nach 1-2 Tagen - Größte Reichweite, aber warte Feedback ab
4. **r/linuxadmin** nur wenn Tier 1 positiv - Professionellere Zielgruppe
5. **r/netsec** vermeiden - Sehr streng gegen self-promotion, hohes Downvote-Risiko

**Timing**: Dienstag-Donnerstag, 8-10 Uhr ET (13-15 Uhr CET) für maximale US + EU Reichweite

---

## Title Options

**Option 1** (Comprehensive):
> Production-ready Ubuntu Security - 14 components (Boot Security, Kernel Hardening, USB Defense, SSH, rkhunter, auditd, AppArmor, Vaultwarden, UFW, nftables, fail2ban, Security Monitoring, Lynis) with CIS Benchmark compliance

**Option 2** (Problem/Solution) ⭐ **Recommended**:
> I spent weeks achieving 100% CIS Benchmark compliance on Ubuntu. Here are 14 production-ready security components so you don't have to.

**Option 3** (Technical Focus):
> [Guide] Ubuntu Server Security - 3-layer USB defense, 99.7% AIDE false-positive reduction, GeoIP filtering, WireGuard VPN integration, and 100% CIS Benchmark compliance

---

## Post Content

**TL;DR**: After weeks hardening production servers (60% → 100% CIS Benchmark compliance), I've open-sourced 14 security components with production-tested configs and false-positive reduction guides. 3-layer USB defense system, 99.7% AIDE noise reduction, unified security event monitoring, GeoIP filtering for fail2ban, WireGuard VPN integration, and comprehensive documentation.

## What's Included

### 🔐 Boot Security
- GRUB password (PBKDF2-SHA512) with automated setup script
- Multi-vendor UEFI password guide (ASRock, Dell, HP, Lenovo)
- Triple-validation prevents boot failures
- Headless-server compatible (`--unrestricted` flag)
- Defense-in-depth: UEFI blocks firmware tampering, GRUB blocks recovery mode

### 🔍 AIDE (Intrusion Detection)
- 99.7% false-positive reduction (3,799 → 12 changes/day)
- Drop-in configuration (Docker, PostgreSQL, Nextcloud, systemd excludes)
- Prometheus metrics + real-time Telegram alerts
- Production scripts (update, backup, metrics exporter)
- Permission management for non-root monitoring

### 🔑 SSH Hardening
- 15+ CIS Benchmark controls (5.2.1 to 5.2.16)
- Key-only authentication (no passwords)
- Drop-in overrides (Gateway, Development, Minimal scenarios)
- Validation script prevents SSH lockout

### ⚙️ Kernel Hardening
- sysctl security parameters (CIS Level 1 & 2)
- /tmp partition hardening (nodev, nosuid, noexec)
- Docker-compatible configuration
- 12+ CIS controls (1.5.x, 3.2.x)

### 🔌 USB Defense System
- 3-layer defense-in-depth (kernel blacklist + real-time detection + auditd bypass monitoring)
- Layer 1: usb-storage module blacklisted (blocks USB mass storage at kernel level)
- Layer 2: Polling-based USB device watcher (2-4 second detection latency)
- Layer 3: auditd-based bypass detection (detects sophisticated circumvention attempts)
- HID filtering (keyboards/mice excluded automatically via USB class detection)
- Rate limiting (1-hour cooldown per device prevents alert floods)
- HTML-formatted email alerts with security status
- Zero external dependencies (standalone scripts)
- Production-proven (running on multiple servers since Jan 2026)
- Use case: Servers in office environments (no camera surveillance, multiple personnel access)
- Blocks: USB flash drives, external HDDs, USB card readers
- Still works: Keyboards/mice (usbhid), Live USB recovery, SSH access

### 🛡️ rkhunter (Rootkit Detection)
- Automated daily scans (cron.daily @ 06:25)
- Weekly signature updates
- False-positive whitelisting guide
- Email alerts on detection
- Complements AIDE (signature-based vs. integrity-based)

### 📝 auditd (Kernel Audit Logging)
- CIS Benchmark 4.1.x alignment (20+ rules)
- Three rule profiles (Base, Aggressive, Docker)
- Immutable rules for production security
- Prometheus metrics exporter
- SIEM-ready log format (rsyslog, Filebeat)
- Real-time "who did what when" forensics

### 🔒 AppArmor (Mandatory Access Control)
- PostgreSQL 16 profile with defense-in-depth deny rules
- Two-phase deployment (COMPLAIN → ENFORCE)
- Violation monitoring scripts
- CIS Benchmark alignment (1.6.1.3, 1.6.1.4)

### 🔑 Vaultwarden Integration
- Sourced Bash library for credential management
- No more plaintext passwords in .env files
- Graceful fallback for gradual migration
- Works with any Bash script

### 🧱 UFW (Simple Firewall)
- CIS Benchmark 3.5.1.x compliant
- Docker-aware documentation (bypass patterns)
- Network segmentation patterns (Management vs. Client LAN)
- SSH rate-limiting built-in
- Prometheus metrics exporter
- Drop-in templates (Webserver, Database, Monitoring, Docker)

### 🔥 nftables (Advanced Firewall)
- Production-ready templates (Gateway, Server, Minimal, Docker)
- Docker chain preservation (never breaks container networking)
- WireGuard VPN integration (Full DNS takeover)
- NAT masquerading, MSS clamping, rate-limiting
- CIS Benchmark Level 1 & 2 compliant
- Based on Pi 5 Router production config (189 lines, battle-tested)

### 🚫 fail2ban (Brute-Force Protection)
- GeoIP country-based whitelisting (7 countries: DE, AT, CH, NL, FR, BE, LU)
- Telegram ban/unban alerts with IP context (Country, ISP via whois)
- Drop-in jail configuration (SSH, nginx, VNC, GeoIP filtering)
- Prometheus metrics exporter (jails, bans, ban events)
- Custom actions & filters (Telegram, VNC)
- Device-agnostic scripts (works on any Ubuntu server)
- Production-proven (Pi 5 Router with 6 active jails)

### 📡 Security Monitoring (Unified Event Monitoring)
- Multi-tool monitoring (fail2ban, SSH, UFW, auditd, AIDE, rkhunter)
- Smart deduplication (alert only on new events, not recurring)
- Aggregated alerts (single Telegram message per run)
- Configurable thresholds (SSH failures, UFW blocks)
- 15-minute interval via systemd timer
- Built on bash-production-toolkit (production-ready logging, alerting)
- Rate-limited notifications (prevents alert fatigue)

### 📊 Lynis (Security Auditing)
- Comprehensive security auditing (~275 system checks)
- Hardening Index tracking (0-100 score for quantified security posture)
- Custom profiles for server environments (reduces false-positives)
- Top 20 high-impact hardening recommendations (production-proven guide)
- Prometheus metrics exporter (track hardening over time)
- systemd automation (weekly audits with minimal overhead)
- Real-world validation: NAS Server 70% → 80% Hardening Index in 57 minutes

## Real-World Results

**Before**:
- Boot Security: 0% (no GRUB/UEFI protection)
- AIDE: 3,799 changes/day (99.7% noise)
- Kernel: 6 critical security gaps
- SSH: Password auth enabled
- Rootkit Detection: None
- CIS Compliance: ~60%

**After**:
- Boot Security: 100% (UEFI + GRUB defense-in-depth)
- AIDE: 12 changes/day (99.7% reduction)
- Kernel: 0 gaps (33 sysctl parameters)
- SSH: Key-only, 15+ CIS controls
- Rootkit Detection: Daily automated scans
- CIS Compliance: 100%

**Production-tested**: Running on multiple Ubuntu servers (NAS + work server + gateway), all with 100% CIS compliance.

## Quick Start

```bash
# Clone repo
git clone https://github.com/fidpa/ubuntu-server-security.git
cd ubuntu-server-security

# Boot Security (automated)
sudo ./boot-security/scripts/setup-grub-password.sh

# AIDE (see aide/docs/SETUP.md)
sudo apt install aide aide-common
sudo cp aide/aide.conf.template /etc/aide/aide.conf
sudo cp aide/drop-ins/*.conf /etc/aide/aide.conf.d/
sudo aideinit

# SSH Hardening
sudo cp ssh-hardening/sshd_config.template /etc/ssh/sshd_config
ssh-hardening/scripts/validate-sshd-config.sh  # Prevents lockout!
sudo systemctl restart sshd

# Kernel Hardening
sudo kernel-hardening/scripts/setup-kernel-hardening.sh

# USB Defense (3-layer protection)
sudo usb-defense/scripts/deploy-usb-defense.sh

# rkhunter
sudo apt install rkhunter
sudo rkhunter --propupd

# UFW (simple firewall for servers)
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp  # SSH rate-limiting
sudo ufw enable

# nftables (advanced firewall for gateways)
sudo apt install nftables
sudo cp nftables/drop-ins/10-gateway.nft.template /etc/nftables.conf
# Customize: WAN_INTERFACE, LAN_INTERFACE, networks
sudo nftables/scripts/validate-nftables.sh /etc/nftables.conf
sudo nftables/scripts/deploy-nftables.sh /etc/nftables.conf

# fail2ban (brute-force protection)
sudo apt install fail2ban
sudo cp fail2ban/fail2ban.local.template /etc/fail2ban/fail2ban.local
sudo cp fail2ban/jail.local.template /etc/fail2ban/jail.local
sudo cp fail2ban/drop-ins/*.conf /etc/fail2ban/jail.d/
sudo systemctl restart fail2ban
# Optional: GeoIP filtering (see fail2ban/docs/GEOIP_FILTERING.md)
# Optional: Telegram alerts (see fail2ban/docs/TELEGRAM_INTEGRATION.md)

# Security Monitoring (unified event monitoring)
# Prerequisites: bash-production-toolkit
sudo cp security-monitoring/scripts/security-log-monitor.sh /usr/local/bin/
sudo cp security-monitoring/systemd/security-log-monitor.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now security-log-monitor.timer
# Configure: /etc/default/security-log-monitor (Telegram credentials)
```

Full guides: See each component's `docs/SETUP.md`

## What Makes This Different

**Most security guides** ignore the hard parts: boot security, false-positive noise, credential management, monitoring integration.

**This repo includes**:
- 🔐 **Complete Defense-in-Depth** - Boot → Firewall → Detection → Logging → Audit
- 📖 **FALSE_POSITIVE_REDUCTION.md** - The "weeks of debugging" lessons nobody documents
- 🔑 **No Plaintext Secrets** - Vaultwarden integration with graceful fallback
- 📊 **Monitoring-Ready** - Prometheus exporters + Grafana dashboards
- 🧩 **Drop-in Configs** - Modular, maintainable (no monolithic 500-line files)
- ✅ **Production-Tested** - Running on real servers (NAS, gateway, work server), not just theory

## Use Cases

- ✅ Homelab security (NAS, media servers, Raspberry Pi)
- ✅ Production servers (CIS compliance)
- ✅ Self-hosted apps (Docker, PostgreSQL, Nextcloud)
- ✅ Container hosts (Docker-compatible hardening)

**Compatibility**: Ubuntu 22.04+, Debian 11+, Raspberry Pi OS (full support). RHEL/Fedora partial (no AppArmor/UFW).

---

**Repository**: https://github.com/fidpa/ubuntu-server-security
**License**: MIT

Questions? I've spent weeks debugging this so you don't have to.

---

## Expected Questions & Answers

**Q: Why both AIDE and rkhunter?**
A: Complementary detection methods. AIDE = integrity-based (detects file changes), rkhunter = signature-based (detects known rootkits). Defense-in-depth.

**Q: Will GRUB password break remote reboots?**
A: No! The `--unrestricted` flag allows normal boot without password. Password is only required for GRUB menu editing ('e' key) and recovery mode.

**Q: Can this work with Ansible?**
A: Yes! All components are template-based and can be deployed via Ansible. Check out the individual component READMEs for deployment patterns.

**Q: 99.7% false-positive reduction - how?**
A: See `aide/docs/FALSE_POSITIVE_REDUCTION.md`. Key: service-specific excludes + AIDE group patterns + FILTERUPDATES=yes. Took weeks to figure out.

**Q: Does this work on Debian?**
A: Should work (tested on Ubuntu 22.04/24.04 only). Boot security is universal, AIDE/rkhunter identical.

**Q: What if I lock myself out during boot security setup?**
A: The setup script has triple-validation to prevent boot failures. If something goes wrong, boot from USB, mount root, restore backup from `/etc/grub.d/backups/`. Full recovery guide in `boot-security/docs/SETUP.md`.

**Q: Will kernel hardening break Docker?**
A: No! Configuration is Docker-compatible (keeps `ip_forward=1`, uses strict `rp_filter`). Tested with 38+ containers.

**Q: Why Vaultwarden instead of just .env files?**
A: .env files store credentials in plaintext. Vaultwarden uses encrypted vault + Bitwarden CLI. The library provides graceful fallback so you can migrate gradually.

---

## Follow-Up Post Ideas (1-2 weeks later)

**Technical deep-dive**:
> [Tutorial] 99.7% AIDE false-positive reduction - The debugging lessons nobody documents

**Defense-in-depth**:
> [Guide] 100% CIS Benchmark compliance on Ubuntu - Complete defense-in-depth implementation

**nftables deep-dive**:
> [Tutorial] Production nftables config - Pi 5 Router with WireGuard VPN + Docker + Dual-WAN failover

**Use case**:
> [Guide] Securing a homelab NAS - From 60% to 100% CIS Benchmark compliance

**Comparison**:
> [Discussion] AIDE + rkhunter vs. OSSEC/Wazuh - Which intrusion detection for self-hosted?
> [Discussion] nftables vs. UFW - When to use which firewall? (Both included!)
