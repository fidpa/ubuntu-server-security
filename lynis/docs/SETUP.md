# Lynis Setup Guide

This guide walks through installing Lynis and running your first security audit.

## Prerequisites

**Minimum Requirements**:
- Ubuntu 22.04 LTS or 24.04 LTS (or compatible Debian-based distro)
- systemd
- Root/sudo access
- ~50 MB disk space

**Optional**:
- Prometheus + node_exporter (for metrics integration)

## Installation

### Option 1: CISOfy Official Repository (Recommended)

The CISOfy repository provides the latest Lynis version (updated monthly).

```bash
# Automated installation
sudo ../scripts/install-lynis.sh

# Or manual installation:
sudo apt install apt-transport-https ca-certificates wget gnupg2
wget -O - https://packages.cisofy.com/keys/cisofy-software-public.key | sudo apt-key add -
echo "deb https://packages.cisofy.com/community/lynis/deb/ stable main" | sudo tee /etc/apt/sources.list.d/cisofy-lynis.list
sudo apt update
sudo apt install lynis
```

**Why CISOfy repo?**
- Latest version (Ubuntu repo is often 6-12 months behind)
- Monthly updates with new tests
- Security fixes prioritized

### Option 2: Ubuntu Repository (Not Recommended)

```bash
sudo apt install lynis
```

**Drawbacks**:
- Outdated (Ubuntu 22.04: v3.0.8, CISOfy: v3.1.2+)
- Missing newer CIS controls
- No timely security updates

### Verify Installation

```bash
lynis show version
# Expected output: Lynis 3.1.x

which lynis
# Expected output: /usr/sbin/lynis
```

## First Audit

### Run Basic Audit

```bash
sudo lynis audit system
```

**What happens**:
- ~275 security tests run (~2-3 minutes)
- Report saved to `/var/log/lynis-report.dat` (machine-readable)
- Log saved to `/var/log/lynis.log` (human-readable)
- Hardening Index displayed (0-100 score)

### Run Quick Audit (Skips Slow Tests)

```bash
sudo lynis audit system --quick
```

**Faster** (~1 minute), **fewer tests** (~200 tests).

## Understanding the Report

### Hardening Index

The **Hardening Index** (0-100) quantifies your system's security posture.

| Score | Rating | Typical For |
|-------|--------|-------------|
| 80-100 | Excellent | Production-hardened servers |
| 60-79 | Good | Default Ubuntu + basic hardening |
| 40-59 | Fair | Fresh Ubuntu install |
| 0-39 | Poor | Unpatched or misconfigured |

**Example**:
```
Hardening index : 72 [############        ]
```

### Warnings vs. Suggestions

- **Warnings** (red): Critical security issues requiring immediate action
- **Suggestions** (yellow): Recommended hardening improvements

**Priority**: Fix warnings first, then high-impact suggestions.

### Reading the Report

```bash
# View hardening index
grep "hardening_index=" /var/log/lynis-report.dat

# Count warnings
grep -c "warning\[\]=" /var/log/lynis-report.dat

# Count suggestions
grep -c "suggestion\[\]=" /var/log/lynis-report.dat

# List all warnings
grep "warning\[\]=" /var/log/lynis-report.dat | cut -d= -f2
```

## Deploy Custom Profile

Custom profiles reduce false-positives for server environments.

```bash
# Copy template
sudo cp ../lynis-custom.prf.template /etc/lynis/custom.prf

# Edit for your environment
sudo nano /etc/lynis/custom.prf

# Run audit with profile
sudo lynis audit system --profile /etc/lynis/custom.prf
```

See [CUSTOM_PROFILES.md](CUSTOM_PROFILES.md) for customization options.

## Automated Audits (systemd Timer)

### Create systemd Service

```bash
sudo tee /etc/systemd/system/lynis-audit.service > /dev/null << 'EOF'
[Unit]
Description=Lynis Security Audit
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/lynis audit system --quick --quiet
StandardOutput=journal
StandardError=journal
EOF
```

### Create systemd Timer (Weekly)

```bash
sudo tee /etc/systemd/system/lynis-audit.timer > /dev/null << 'EOF'
[Unit]
Description=Weekly Lynis Security Audit

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF
```

### Enable and Start Timer

```bash
sudo systemctl daemon-reload
sudo systemctl enable lynis-audit.timer
sudo systemctl start lynis-audit.timer

# Verify timer
sudo systemctl status lynis-audit.timer
```

## Verification Commands

```bash
# Check Lynis version
sudo lynis show version

# Show license status
sudo lynis show license

# List available tests
sudo lynis show tests

# Test specific category
sudo lynis audit system --tests AUTH  # Authentication tests only
```

## Next Steps

1. **Review Report**: Analyze warnings and suggestions
2. **Prioritize Fixes**: See [HARDENING_GUIDE.md](HARDENING_GUIDE.md) for top 20 recommendations
3. **Custom Profile**: Deploy custom profile to reduce noise
4. **Automation**: Enable systemd timer for weekly audits
5. **Monitoring**: Integrate with Prometheus (see [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md))

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues.

**Common problems**:
- `lynis: command not found` → Verify installation path
- `Permission denied` → Must run with sudo
- Low hardening index → Expected on default Ubuntu (see HARDENING_GUIDE.md)
