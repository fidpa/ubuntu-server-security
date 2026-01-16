# rkhunter False Positives

Known false positives and whitelisting strategies for Ubuntu Server.

## Overview

rkhunter performs paranoid security checks that often flag legitimate system files as suspicious. This guide documents common false positives and how to handle them.

## Common False Positives

### 1. `/usr/bin/lwp-request`

**Warning:**
```
Warning: Suspicious file types found in /usr/bin:
    /usr/bin/lwp-request: Perl script text executable
```

**Cause:** rkhunter flags Perl scripts as suspicious in `/usr/bin`.

**Legitimacy:** Part of `libwww-perl` package, commonly installed.

**Verification:**
```bash
dpkg -S /usr/bin/lwp-request
# Output: libwww-perl: /usr/bin/lwp-request

file /usr/bin/lwp-request
# Output: Perl script text executable
```

**Whitelist:**
```bash
sudo nano /etc/rkhunter.conf
```

Add:
```bash
SCRIPTWHITELIST=/usr/bin/lwp-request
```

### 2. `/etc/.updated`

**Warning:**
```
Warning: Hidden file found: /etc/.updated
```

**Cause:** systemd package management marker file.

**Legitimacy:** Created by dpkg/apt after package updates.

**Verification:**
```bash
ls -la /etc/.updated
cat /etc/.updated  # Shows timestamp
```

**Whitelist:**
```bash
ALLOWHIDDENFILE=/etc/.updated
```

### 3. systemd Backup Files (`.bak`)

**Warning:**
```
Warning: Suspicious file found: /etc/.resolv.conf.systemd-resolved.bak
Warning: Hidden file found: /etc/.*.bak
```

**Cause:** systemd creates backup files for configuration.

**Legitimacy:** Normal systemd behavior for config backups.

**Verification:**
```bash
ls -la /etc/.*.bak
# Lists systemd backup files
```

**Whitelist:**
```bash
ALLOWHIDDENFILE=/etc/.resolv.conf.systemd-resolved.bak
ALLOWHIDDENFILE=/etc/.*.bak
```

### 4. Hidden Directories in `/dev`

**Warning:**
```
Warning: Hidden directory found: /dev/.udev
Warning: Hidden directory found: /dev/.lxd-mounts
```

**Cause:** systemd udev and LXD use hidden directories.

**Legitimacy:** Normal for modern Ubuntu systems.

**Verification:**
```bash
ls -la /dev/ | grep "^\."
systemctl status systemd-udevd
```

**Whitelist:**
```bash
ALLOWHIDDENDIR=/dev/.udev
ALLOWHIDDENDIR=/dev/.lxd-mounts
```

### 5. Network Interface Promiscuous Mode

**Warning:**
```
Warning: Interface 'docker0' is in promiscuous mode
Warning: Interface 'virbr0' is in promiscuous mode
```

**Cause:** Docker/libvirt network bridges operate in promiscuous mode.

**Legitimacy:** Required for container networking.

**Verification:**
```bash
ip link show docker0
# Flags include PROMISC

docker network ls
```

**Whitelist:**
```bash
ALLOWPROMISCIF=docker0
ALLOWPROMISCIF=virbr0
ALLOWPROMISCIF=br-*  # Docker custom bridges
```

### 6. Deleted Open Files

**Warning:**
```
Warning: Process '/usr/bin/some-daemon' has deleted files open
```

**Cause:** Long-running processes with outdated libraries after updates.

**Legitimacy:** Normal until service restart.

**Solution:** Restart affected services after system updates:
```bash
sudo systemctl restart servicename
```

**Or disable test:**
```bash
DISABLE_TESTS=deleted_files
```

### 7. Suspicious Strings in Binaries

**Warning:**
```
Warning: Possible rootkit string found in /usr/bin/program: 'bindshell'
```

**Cause:** Legitimate programs may contain rootkit-related strings for detection/testing.

**Verification:**
```bash
strings /usr/bin/program | grep bindshell
dpkg -S /usr/bin/program
```

**Whitelist (if verified safe):**
```bash
DISABLE_TESTS=suspscan
```

**Warning:** Only disable after manual verification!

## Whitelisting Strategies

### Strategy 1: Specific Whitelists (Recommended)

**Pros:** Maintains security, precise control
**Cons:** Requires manual configuration

```bash
# Whitelist specific files/directories
ALLOWHIDDENDIR=/etc/.git
ALLOWHIDDENFILE=/etc/.updated
SCRIPTWHITELIST=/usr/bin/lwp-request
ALLOWPROMISCIF=docker0
```

### Strategy 2: Disable Problem Tests

**Pros:** Quick solution
**Cons:** Reduces detection capability

```bash
# Disable tests with many false positives
DISABLE_TESTS=suspscan hidden_procs deleted_files apps
```

**Use sparingly!** Each disabled test reduces security.

### Strategy 3: Property Update

**Pros:** Handles legitimate changes automatically
**Cons:** Won't prevent recurring warnings

```bash
# After system updates
sudo rkhunter --propupd
```

**Best for:** File hash mismatches after package updates.

## Handling New False Positives

### Step 1: Investigate

```bash
# Identify warning
sudo rkhunter --check --report-warnings-only

# Verify legitimacy
file /path/to/suspicious/file
dpkg -S /path/to/suspicious/file
ls -la /path/to/suspicious/file
```

### Step 2: Determine Legitimacy

**Legitimate if:**
- Part of installed package (`dpkg -S` shows package name)
- Created by system service (systemd, Docker, etc.)
- Expected behavior (backups, temporary files)

**Suspicious if:**
- Unknown origin
- Not in package database
- Unexpected location
- Recent appearance without system changes

### Step 3: Whitelist or Investigate

**If legitimate:**
```bash
sudo nano /etc/rkhunter.conf
# Add appropriate whitelist
sudo rkhunter --propupd
```

**If suspicious:**
```bash
# Quarantine file
sudo mv /path/to/file /root/quarantine/

# Investigate further
sudo rkhunter --check --enable suspscan
```

## Test-Specific False Positives

### `apps` Test

**Symptoms:** Many warnings about binary changes

**Solution:**
```bash
# Update properties after system updates
sudo rkhunter --propupd

# Or disable if too noisy
DISABLE_TESTS=apps
```

### `hidden_procs` Test

**Symptoms:** False positives about hidden processes (systemd)

**Solution:**
```bash
DISABLE_TESTS=hidden_procs
```

**Why:** Modern systemd creates many process structures that trigger false positives.

### `suspscan` Test

**Symptoms:** Strings like "backdoor", "rootkit" in legitimate binaries

**Solution:**
```bash
DISABLE_TESTS=suspscan
```

**Warning:** This test has high false-positive rate but also catches real threats. Disable only if overwhelming legitimate matches.

## Package Update Workflow

After `apt upgrade`, run:

```bash
# Update rkhunter properties
sudo rkhunter --propupd

# Verify no new warnings
sudo rkhunter --check --skip-keypress
```

This prevents false positives from:
- Binary hash changes (legitimate updates)
- Library replacements
- Configuration file updates

## Docker-Specific Configuration

### Docker Network Interfaces

```bash
# Whitelist Docker interfaces
ALLOWPROMISCIF=docker0
ALLOWPROMISCIF=br-*
ALLOWPROMISCIF=veth*
```

### Docker Hidden Directories

```bash
ALLOWHIDDENDIR=/dev/.lxd-mounts
ALLOWHIDDENDIR=/var/lib/docker/.docker-*
```

### Docker Process Detection

```bash
# Disable if Docker causes process warnings
DISABLE_TESTS=hidden_procs
```

## systemd-Specific Configuration

### systemd Backup Files

```bash
ALLOWHIDDENFILE=/etc/.*.bak
ALLOWHIDDENFILE=/etc/.resolv.conf.systemd-resolved.bak
```

### systemd Device Directories

```bash
ALLOWHIDDENDIR=/dev/.udev
ALLOWHIDDENDIR=/run/systemd
```

## Example Production Configuration

Complete `/etc/rkhunter.conf` whitelist section:

```bash
# ===== FALSE POSITIVE WHITELISTS =====

# Perl Scripts (Ubuntu packages)
SCRIPTWHITELIST=/usr/bin/lwp-request
SCRIPTWHITELIST=/usr/bin/GET
SCRIPTWHITELIST=/usr/bin/POST

# systemd Files
ALLOWHIDDENFILE=/etc/.updated
ALLOWHIDDENFILE=/etc/.*.bak
ALLOWHIDDENFILE=/etc/.resolv.conf.systemd-resolved.bak
ALLOWHIDDENDIR=/dev/.udev
ALLOWHIDDENDIR=/dev/.lxd-mounts

# Docker Network
ALLOWPROMISCIF=docker0
ALLOWPROMISCIF=br-*
ALLOWPROMISCIF=veth*

# Disable Noisy Tests
DISABLE_TESTS=suspscan hidden_procs deleted_files apps

# Enable Critical Tests Only
ENABLE_TESTS=known_rkits hidden_files passwd_changes group_changes system_commands

# ===== END WHITELISTS =====
```

## Monitoring False Positives

### Track Warning Trends

```bash
# Count warnings over time
sudo grep Warning /var/log/rkhunter.log | wc -l

# Group by warning type
sudo grep Warning /var/log/rkhunter.log | cut -d: -f2 | sort | uniq -c
```

### Alert on New Warning Types

```bash
#!/bin/bash
# /opt/scripts/rkhunter-new-warnings.sh

LAST_WARNINGS="/var/lib/rkhunter/last_warnings.txt"
CURRENT_WARNINGS=$(sudo rkhunter --check --report-warnings-only 2>&1 | grep Warning)

if [ -f "$LAST_WARNINGS" ]; then
    DIFF=$(comm -13 <(sort "$LAST_WARNINGS") <(echo "$CURRENT_WARNINGS" | sort))
    if [ -n "$DIFF" ]; then
        echo "New rkhunter warnings detected:"
        echo "$DIFF" | mail -s "rkhunter: New Warnings" root
    fi
fi

echo "$CURRENT_WARNINGS" > "$LAST_WARNINGS"
```

## When to Investigate vs. Whitelist

### Investigate Further If:

- File not in package database
- Appears in critical system directories (`/bin`, `/sbin`, `/usr/bin`)
- Recent appearance without system updates
- Unknown origin or purpose
- Located in `/tmp`, `/dev/shm`, or user directories

### Safe to Whitelist If:

- Part of installed package (`dpkg -S` confirms)
- Created by known system service
- Documented Ubuntu/systemd behavior
- Matches known false positive patterns
- Verified hash against clean system

## Resources

- [rkhunter FAQ](http://rkhunter.sourceforge.net/faq.html)
- [Ubuntu rkhunter Wiki](https://help.ubuntu.com/community/RKhunter)
- [rkhunter Mailing List Archives](https://sourceforge.net/p/rkhunter/mailman/rkhunter-users/)
