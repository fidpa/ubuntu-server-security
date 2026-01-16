# rkhunter Setup Guide

Complete installation and configuration guide for rkhunter on Ubuntu Server.

## Installation

### Step 1: Install Package

```bash
sudo apt update
sudo apt install rkhunter
```

**Package Info:**
- Version: 1.4.6-12 (Ubuntu 24.04 LTS)
- Dependencies: ~17 packages including Ruby, Perl libraries
- Size: ~262 MB total

### Step 2: Initial Database Update

```bash
# Update rootkit signatures
sudo rkhunter --update

# Initialize file properties database
sudo rkhunter --propupd
```

**Expected Output:**
```
File updated: searched for 181 files, found 144
```

### Step 3: First Scan

```bash
# Run initial scan
sudo rkhunter --check --skip-keypress
```

**Expected:** 0-3 warnings (see FALSE_POSITIVES.md)

## Configuration

### Main Config File

Location: `/etc/rkhunter.conf`

### Essential Settings

```bash
# Edit configuration
sudo nano /etc/rkhunter.conf
```

**Key Parameters:**

```bash
# Email on warnings
MAIL-ON-WARNING=root
# Or external: MAIL-ON-WARNING=admin@example.com

# Database update method
UPDATE_MIRRORS=0
MIRRORS_MODE=1
WEB_CMD=/usr/bin/false  # Disable network updates (use apt)

# Monitoring options
ENABLE_TESTS=ALL
DISABLE_TESTS=suspscan hidden_ports deleted_files packet_cap_apps apps

# Log verbosity
LOGFILE=/var/log/rkhunter.log
APPEND_LOG=1
```

### Network Configuration

By default, `WEB_CMD=/usr/bin/false` prevents network updates:

```bash
# ✅ CORRECT - Updates via apt packages
WEB_CMD=/usr/bin/false

# ❌ WRONG - Network updates (security risk)
WEB_CMD=/usr/bin/wget
```

**Rationale:** Database updates should come from trusted apt repositories, not arbitrary network sources.

## Built-in Automation

rkhunter installs automatic cron jobs:

### Daily Scan

**File:** `/etc/cron.daily/rkhunter`

**Content:**
```bash
#!/bin/sh
test -x /usr/bin/rkhunter || exit 0
/usr/bin/rkhunter --cronjob --report-warnings-only
```

**Schedule:** Runs at 06:25 (via systemd timer)

**Actions:**
1. Full system scan
2. Email on warnings (if MAIL-ON-WARNING set)
3. Log to `/var/log/rkhunter.log`

### Weekly Update

**File:** `/etc/cron.weekly/rkhunter`

**Content:**
```bash
#!/bin/sh
test -x /usr/bin/rkhunter || exit 0
/usr/bin/rkhunter --update --cronjob
```

**Actions:**
1. Update rootkit signatures (from apt)
2. Update file properties
3. Log updates

### Verification

```bash
# Check daily timer
systemctl list-timers | grep rkhunter

# Or view cron status
ls -la /etc/cron.daily/rkhunter
ls -la /etc/cron.weekly/rkhunter
```

## Email Alerts

### Configure Mail Recipient

```bash
sudo nano /etc/rkhunter.conf
```

Set:
```bash
MAIL-ON-WARNING=your@email.com
```

### Test Email Functionality

```bash
# Test mail command
echo "rkhunter test" | mail -s "Test Alert" root

# Trigger test warning (safe)
sudo rkhunter --check --report-warnings-only
```

### Mail Transfer Agent Required

If using external email, install MTA:

```bash
# Option 1: Postfix (full MTA)
sudo apt install postfix

# Option 2: sSMTP (simple relay)
sudo apt install ssmtp
sudo nano /etc/ssmtp/ssmtp.conf
```

## Manual Scans

### Full Scan

```bash
sudo rkhunter --check
```

**Interactive:** Prompts to press key after each check.

### Automated Scan

```bash
sudo rkhunter --check --skip-keypress
```

**Non-interactive:** Suitable for scripts.

### Show Only Warnings

```bash
sudo rkhunter --check --report-warnings-only --skip-keypress
```

**Output:** Only items needing attention.

### Quick Check

```bash
sudo rkhunter --check --enable known_rkits --disable none
```

**Fast:** Only checks for known rootkits.

## Database Maintenance

### When to Update Properties

Run after:
- System updates: `sudo apt upgrade`
- Kernel updates
- Manual package installations
- Configuration changes

```bash
sudo rkhunter --propupd
```

### Signature Updates

```bash
# Update rootkit signatures (via apt)
sudo apt update
sudo apt upgrade rkhunter
```

**Note:** With `WEB_CMD=/usr/bin/false`, updates come from apt repositories only.

## Whitelisting False Positives

### Method 1: Config File

Edit `/etc/rkhunter.conf`:

```bash
# Allow specific warnings
ALLOWHIDDENDIR=/etc/.git
ALLOWDEVFILE=/dev/.udev
SCRIPTWHITELIST=/usr/bin/lwp-request
```

### Method 2: Property Update

After legitimate system changes:

```bash
sudo rkhunter --propupd
```

This updates the baseline for file integrity checks.

### Method 3: Disable Specific Tests

```bash
DISABLE_TESTS=suspscan hidden_procs deleted_files
```

**Common Disables:**
- `suspscan` - Suspicious scan (many false positives)
- `hidden_procs` - Hidden process detection (systemd conflicts)
- `deleted_files` - Deleted file handles (normal for long-running processes)

## Log Management

### View Recent Warnings

```bash
sudo grep Warning /var/log/rkhunter.log | tail -20
```

### View Last Scan Results

```bash
tail -100 /var/log/rkhunter.log
```

### Log Rotation

rkhunter logs automatically rotate via logrotate:

```bash
/var/log/rkhunter.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
}
```

## Advanced Configuration

### Disable Network Tests

```bash
DISABLE_TESTS=packet_cap_apps
```

**Why:** Network interface checks can cause false positives on Docker hosts.

### Custom Scan Paths

```bash
# Add directories to scan
SCAN_MODE_DEV=THOROUGH

# Skip specific directories
ALLOWHIDDENDIR=/opt/.snapshots
```

### Performance Tuning

```bash
# Reduce check time
DISABLE_TESTS=apps suspscan hidden_ports

# Enable only critical checks
ENABLE_TESTS=known_rkits hidden_files
DISABLE_TESTS=ALL
```

## Validation

### Verify Installation

```bash
# Check version
rkhunter --version
# Expected: Rootkit Hunter 1.4.6

# Verify configuration
sudo rkhunter --config-check
# Expected: No errors found

# Check database
sudo rkhunter --list tests | wc -l
# Expected: ~30 tests available
```

### Test Automation

```bash
# Verify cron.daily
cat /etc/cron.daily/rkhunter

# Trigger manual run
sudo run-parts --test /etc/cron.daily

# Check last run
sudo journalctl -u cron | grep rkhunter | tail -5
```

### Test Email Alerts

```bash
# Set MAIL-ON-WARNING
sudo nano /etc/rkhunter.conf

# Force warning (create suspicious file)
sudo touch /tmp/.hidden_test_file

# Run scan
sudo rkhunter --check --skip-keypress

# Check mail
mail  # If using local mail
```

## Troubleshooting

### "Invalid WEB_CMD configuration"

**Error:**
```
Invalid WEB_CMD configuration option: Relative pathname: "/bin/false"
```

**Fix:**
```bash
sudo sed -i 's|^WEB_CMD=.*|WEB_CMD=/usr/bin/false|' /etc/rkhunter.conf
```

### Database Update Failures

**Symptom:** `rkhunter --update` shows "Update failed" for all files.

**Cause:** `WEB_CMD=/usr/bin/false` blocks network updates (by design).

**Solution:** This is correct behavior. Updates come from apt:
```bash
sudo apt update
sudo apt upgrade rkhunter
```

### Many Warnings After First Scan

**Normal:** Initial scan may show 3-5 false positives.

**Solution:** See [FALSE_POSITIVES.md](FALSE_POSITIVES.md) for common issues.

### Email Alerts Not Working

**Check:**
```bash
# Test local mail
echo "Test" | mail -s "rkhunter test" root

# Check mail logs
sudo tail /var/log/mail.log

# Verify MAIL-ON-WARNING
grep MAIL-ON-WARNING /etc/rkhunter.conf
```

### Scan Takes Too Long

**Reduce Scope:**
```bash
DISABLE_TESTS=apps suspscan hidden_ports
```

**Or limit paths:**
```bash
ENABLE_TESTS=known_rkits
DISABLE_TESTS=ALL
```

## Integration with Other Tools

### AIDE Integration

rkhunter and AIDE are complementary:

| Tool | Focus | Schedule |
|------|-------|----------|
| rkhunter | Rootkit detection | Daily (06:25) |
| AIDE | File integrity | Daily (06:00) |

**No conflicts:** Different detection methods, different schedules.

### Prometheus Integration

Export rkhunter metrics (optional):

```bash
#!/bin/bash
# /opt/scripts/rkhunter-metrics-exporter.sh

WARNINGS=$(sudo rkhunter --check --skip-keypress --report-warnings-only 2>/dev/null | wc -l)
echo "rkhunter_warnings_total $WARNINGS" > /var/lib/node_exporter/textfile_collector/rkhunter.prom
```

### Log Aggregation

Forward rkhunter logs to centralized logging:

```bash
# rsyslog rule
if $programname == 'rkhunter' then /var/log/centralized/rkhunter.log
```

## Security Hardening

### Restrict Config Access

```bash
sudo chmod 640 /etc/rkhunter.conf
sudo chown root:root /etc/rkhunter.conf
```

### Verify Binary Integrity

```bash
# Check rkhunter binary
dpkg -V rkhunter

# Verify package signature
apt-cache policy rkhunter
```

### Audit Log Access

```bash
# Restrict log access
sudo chmod 640 /var/log/rkhunter.log
sudo chown root:adm /var/log/rkhunter.log
```

## Uninstallation

To remove rkhunter:

```bash
# Remove package
sudo apt remove --purge rkhunter

# Remove logs
sudo rm -rf /var/log/rkhunter.log*

# Remove database
sudo rm -rf /var/lib/rkhunter/
```

## Resources

- [Official Documentation](http://rkhunter.sourceforge.net/docs/)
- [Ubuntu rkhunter Wiki](https://help.ubuntu.com/community/RKhunter)
- [Debian rkhunter Guide](https://wiki.debian.org/rkhunter)
