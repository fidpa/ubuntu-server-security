# Lynis Custom Profiles

Custom profiles reduce false-positives and tailor audits to specific server environments.

## Why Custom Profiles?

**Problem**: Default Lynis tests include checks for desktop systems, unused services, and features intentionally disabled for security or workflow reasons.

**Example False-Positives**:
- SSH X11Forwarding disabled → Warning (but required for VS Code Remote)
- Mail server not running → Warning (but not needed on web server)
- Package updates available → Warning (but manual update schedule)

**Solution**: Custom profiles skip irrelevant tests and customize thresholds.

---

## Profile Location

**Default**: `/etc/lynis/custom.prf`

**Alternative**: Specify with `--profile` flag:
```bash
sudo lynis audit system --profile /path/to/custom.prf
```

---

## Profile Syntax

### Skip Tests

```bash
# Skip single test
skip-test=TEST-ID

# Skip test with detail (sub-check)
skip-test=TEST-ID:detail
```

**Example**:
```bash
skip-test=FILE-6310    # Skip X11 file checks
skip-test=SSH-7408:X11Forwarding  # Skip SSH X11Forwarding check only
```

### Customize Thresholds

```bash
config:key:value
```

**Example**:
```bash
config:password_max_days:180  # Password aging (default: 365)
```

### Comments

```bash
# This is a comment
```

---

## Server-Type Profiles

### Web Server Profile

Reduces false-positives for nginx/Apache web servers.

```bash
# Web Server Custom Profile
# Purpose: nginx/Apache server without mail/database

# Skip desktop checks
skip-test=FILE-6310    # X11 files

# Skip unused services
skip-test=MAIL-8818    # Mail server
skip-test=DBS-1804     # Database server
skip-test=PRNT-2307    # CUPS printing

# Skip irrelevant package checks
skip-test=PKGS-7392    # Package updates (manual schedule)

# Customize thresholds
config:password_max_days:180
```

### Database Server Profile

Reduces false-positives for PostgreSQL/MySQL/MariaDB servers.

```bash
# Database Server Custom Profile
# Purpose: PostgreSQL/MySQL server

# Skip desktop checks
skip-test=FILE-6310    # X11 files

# Skip unused services
skip-test=MAIL-8818    # Mail server
skip-test=HTTP-6622    # Web server
skip-test=PRNT-2307    # CUPS printing

# Skip package checks
skip-test=PKGS-7392    # Package updates (manual schedule)
skip-test=PKGS-7398    # debsums (DB packages modified for tuning)

# Customize thresholds
config:password_max_days:90  # Stricter for production DB
```

### Docker Host Profile

Reduces false-positives for Docker container hosts.

```bash
# Docker Host Custom Profile
# Purpose: Docker container host

# Skip desktop checks
skip-test=FILE-6310    # X11 files

# Skip container filesystem checks (overlayfs expected)
skip-test=FILE-6344    # Sticky bit on /tmp (containers handle this)

# Skip package checks (container images, not host)
skip-test=PKGS-7398    # debsums (containers modify files)

# Skip mail checks
skip-test=MAIL-8818    # Mail server

# Customize thresholds
config:password_max_days:180
```

### Development Server Profile

Reduces false-positives for development/testing servers.

```bash
# Development Server Custom Profile
# Purpose: Dev/test environment with VS Code Remote, Docker, Git

# Skip desktop checks
skip-test=FILE-6310    # X11 files

# Development-required SSH features
skip-test=SSH-7408:X11Forwarding      # VS Code Remote needs this
skip-test=SSH-7408:AllowAgentForwarding # Git SSH keys
skip-test=SSH-7408:AllowTcpForwarding   # Docker port forwarding

# Skip package checks
skip-test=PKGS-7392    # Updates (manual)
skip-test=PKGS-7398    # debsums (dev packages modified)

# Skip mail checks
skip-test=MAIL-8818    # Mail server

# Customize thresholds
config:password_max_days:180
```

---

## Common False-Positives

### X11 Files (FILE-6310)

**Why triggered**: Desktop files present (even on headless servers).

**Should skip if**: Headless server without GUI.

```bash
skip-test=FILE-6310
```

### Package Updates Available (PKGS-7392)

**Why triggered**: Newer packages available in repos.

**Should skip if**: Manual update schedule (to avoid breaking changes).

```bash
skip-test=PKGS-7392
```

### debsums Integrity Check (PKGS-7398)

**Why triggered**: Modified package files.

**Should skip if**: Development server with customized configs.

```bash
skip-test=PKGS-7398
```

### Mail Server Not Running (MAIL-8818)

**Why triggered**: Postfix/Exim not installed.

**Should skip if**: Server doesn't send/receive email.

```bash
skip-test=MAIL-8818
```

### SSH Forwarding (SSH-7408)

**Why triggered**: SSH forwarding features enabled.

**Should skip if**:
- X11Forwarding → VS Code Remote requires it
- AllowAgentForwarding → Git SSH keys require it
- AllowTcpForwarding → Docker port forwarding requires it

```bash
skip-test=SSH-7408:X11Forwarding
skip-test=SSH-7408:AllowAgentForwarding
skip-test=SSH-7408:AllowTcpForwarding
```

---

## Testing Profiles

### Validate Profile Syntax

```bash
# Automated validation
sudo ../scripts/validate-lynis-profile.sh /etc/lynis/custom.prf

# Manual validation (Lynis checks on run)
sudo lynis audit system --profile /etc/lynis/custom.prf
```

### Compare Results

```bash
# Baseline audit (no profile)
sudo lynis audit system
grep "hardening_index=" /var/log/lynis-report.dat

# Audit with profile
sudo lynis audit system --profile /etc/lynis/custom.prf
grep "hardening_index=" /var/log/lynis-report.dat

# Compare warnings/suggestions count
grep -c "warning\[\]=" /var/log/lynis-report.dat
grep -c "suggestion\[\]=" /var/log/lynis-report.dat
```

---

## Deployment

### Step 1: Copy Template

```bash
sudo cp ../lynis-custom.prf.template /etc/lynis/custom.prf
```

### Step 2: Customize for Your Environment

```bash
sudo nano /etc/lynis/custom.prf
```

**Add server-type skips** (web, database, Docker, dev).

### Step 3: Validate

```bash
sudo ../scripts/validate-lynis-profile.sh /etc/lynis/custom.prf
```

### Step 4: Test

```bash
sudo lynis audit system --profile /etc/lynis/custom.prf
```

### Step 5: Make Default (Optional)

```bash
# Systemd service using profile
sudo systemctl edit lynis-audit.service

# Add:
[Service]
ExecStart=
ExecStart=/usr/sbin/lynis audit system --profile /etc/lynis/custom.prf --quick --quiet
```

---

## Advanced Configuration

### Environment-Specific Profiles

**Multi-server fleet**: Different profiles per role.

```bash
# Web servers
/etc/lynis/profiles/web-server.prf

# Database servers
/etc/lynis/profiles/database-server.prf

# Docker hosts
/etc/lynis/profiles/docker-host.prf

# Deployment script selects profile based on hostname/role
```

### Version Control

**Best Practice**: Store profiles in version control.

```bash
# Repository
/ubuntu-server-security/lynis/profiles/
├── web-server.prf
├── database-server.prf
├── docker-host.prf
└── development.prf

# Deploy to servers
scp profiles/web-server.prf user@web01:/etc/lynis/custom.prf
```

---

## See Also

- [SETUP.md](SETUP.md) - Installation & first audit
- [HARDENING_GUIDE.md](HARDENING_GUIDE.md) - Top 20 recommendations
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
