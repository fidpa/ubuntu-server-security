# auditd Setup Guide

Complete installation and configuration guide for the Linux Audit Daemon.

## Prerequisites

- Ubuntu 22.04 LTS or 24.04 LTS
- Root/sudo access
- Sufficient disk space (500MB+ recommended for logs)

## Installation

### Step 1: Install auditd

```bash
sudo apt update
sudo apt install auditd audispd-plugins
```

**Packages installed:**
- `auditd` - The audit daemon and core utilities
- `audispd-plugins` - Dispatcher plugins (syslog, remote)

### Step 2: Verify Installation

```bash
# Check version
auditctl --version

# Check service status
sudo systemctl status auditd

# Verify initial rules (should be minimal)
sudo auditctl -l
```

## Configuration

### Step 3: Configure auditd.conf

Edit the main configuration file:

```bash
sudo nano /etc/audit/auditd.conf
```

**Recommended settings:**

```ini
# Log file settings
log_file = /var/log/audit/audit.log
log_format = ENRICHED
log_group = adm

# Log rotation
max_log_file = 50
num_logs = 5
max_log_file_action = rotate

# Buffer and backlog
priority_boost = 4
name_format = hostname

# Failure handling
disk_full_action = rotate
disk_error_action = syslog
admin_space_left_action = rotate
space_left_action = rotate

# Flush frequency (SYNC for compliance, INCREMENTAL_ASYNC for performance)
flush = INCREMENTAL_ASYNC
freq = 50
```

### Step 4: Deploy Audit Rules

Choose the appropriate rule set for your security requirements:

#### Option A: Base Rules (CIS Level 1) - Recommended

```bash
# Copy base rules
sudo cp audit-base.rules.template /etc/audit/rules.d/99-cis-base.rules

# For Docker hosts, add container rules
sudo cp audit-docker.rules.template /etc/audit/rules.d/50-docker.rules

# Load rules
sudo augenrules --load
```

#### Option B: Aggressive Rules (CIS Level 2 / STIG)

```bash
# Copy aggressive rules (includes immutable mode!)
sudo cp audit-aggressive.rules.template /etc/audit/rules.d/99-cis-l2.rules

# For Docker hosts
sudo cp audit-docker.rules.template /etc/audit/rules.d/50-docker.rules

# Load rules
sudo augenrules --load
```

**Warning:** Aggressive rules include `-e 2` (immutable mode). After loading, rule changes require a reboot!

### Step 5: Verify Rules

```bash
# List all loaded rules
sudo auditctl -l

# Count rules
sudo auditctl -l | wc -l

# Check for errors
sudo auditctl -s
```

**Expected output for base rules:** ~50-60 rules loaded

### Step 6: Generate Privileged Command Rules

The CIS benchmark requires auditing all SUID/SGID binaries. Generate rules specific to your system:

```bash
# Find all privileged binaries and generate rules
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | \
  awk '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged"}' | \
  sudo tee /etc/audit/rules.d/30-privileged.rules

# Reload rules
sudo augenrules --load
```

### Step 7: Enable and Start Service

```bash
# Enable on boot
sudo systemctl enable auditd

# Restart to apply configuration
sudo systemctl restart auditd

# Verify
sudo systemctl status auditd
```

## Validation

### Test Audit Logging

```bash
# Trigger a test event (sudo usage)
sudo ls /root

# Search for the event
sudo ausearch -k actions -ts recent

# Should show your sudo command
```

### Check for Lost Events

```bash
sudo auditctl -s | grep -E "lost|backlog"
```

**Healthy output:**
```
lost 0
backlog 0
backlog_limit 8192
```

If `lost > 0`, increase backlog limit in rules:
```
-b 16384
```

### Validate Rule Syntax

```bash
./scripts/validate-audit-rules.sh
```

## Log Rotation

auditd handles its own log rotation. Verify settings:

```bash
# Check current log size
ls -lh /var/log/audit/

# Check rotation configuration
grep -E "max_log_file|num_logs" /etc/audit/auditd.conf
```

**Default rotation:**
- 50 MB per file
- 5 rotated files kept
- Automatic rotation on size limit

## Remote Logging (Optional)

### Configure audisp-remote

For SIEM integration or centralized logging:

```bash
# Edit audisp-remote configuration
sudo nano /etc/audisp/plugins.d/au-remote.conf
```

```ini
active = yes
direction = out
path = /sbin/audisp-remote
type = always
```

```bash
# Configure remote server
sudo nano /etc/audisp/audisp-remote.conf
```

```ini
remote_server = 192.168.1.100
port = 60
transport = tcp
```

### Configure syslog Forwarding

Alternative to audisp-remote:

```bash
# Edit syslog plugin
sudo nano /etc/audisp/plugins.d/syslog.conf
```

```ini
active = yes
direction = out
path = /sbin/audisp-syslog
type = always
args = LOG_LOCAL6
format = string
```

Then configure rsyslog to forward LOG_LOCAL6 to your SIEM.

## Immutable Rules

For production servers, enable immutable mode:

1. Add `-e 2` at the END of your rules file
2. Reload rules: `sudo augenrules --load`
3. **From this point, rule changes require a reboot!**

**To modify rules after enabling immutable mode:**

```bash
# Edit rules file
sudo nano /etc/audit/rules.d/99-cis-base.rules

# Reboot to apply changes
sudo reboot
```

## Performance Tuning

### High-Volume Servers

For servers with high activity:

```bash
# Increase backlog
-b 32768

# Use asynchronous flushing
# In /etc/audit/auditd.conf:
flush = INCREMENTAL_ASYNC
freq = 50
```

### Reducing Noise

Exclude high-frequency, low-value events:

```bash
# Exclude read access to /proc (very noisy)
-a always,exclude -F msgtype=PATH -F path=/proc

# Exclude specific service accounts
-a always,exclude -F auid=systemd-network
-a always,exclude -F auid=systemd-resolve

# Exclude cron credential events
-a always,exclude -F msgtype=CRED_ACQ -F exe=/usr/sbin/cron
```

## Next Steps

1. **Set up Prometheus metrics:** See [../README.md](../README.md#prometheus-integration)
2. **Review CIS controls:** See [CIS_CONTROLS.md](CIS_CONTROLS.md)
3. **Troubleshooting:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## Quick Reference

| Command | Purpose |
|---------|---------|
| `sudo auditctl -l` | List loaded rules |
| `sudo auditctl -s` | Show audit status |
| `sudo ausearch -k <key>` | Search by key |
| `sudo aureport --summary` | Generate summary report |
| `sudo augenrules --load` | Reload rules from files |
| `sudo systemctl restart auditd` | Restart service |
