# auditd Troubleshooting Guide

Common issues and solutions for the Linux Audit Daemon.

## Quick Diagnostics

```bash
# Service status
sudo systemctl status auditd

# Audit system status
sudo auditctl -s

# Recent errors in journal
sudo journalctl -u auditd -n 50 --no-pager

# Check for lost events
sudo auditctl -s | grep lost
```

## Common Issues

### 1. auditd Service Won't Start

**Symptom:**
```
systemctl status auditd
● auditd.service - Security Auditing Service
   Active: failed (Result: exit-code)
```

**Possible Causes:**

#### A. Syntax Error in Rules

**Diagnosis:**
```bash
# Check rules syntax
sudo augenrules --check
```

**Solution:**
```bash
# Find the problematic rule file
for f in /etc/audit/rules.d/*.rules; do
    echo "Checking $f..."
    sudo auditctl -R "$f" 2>&1 | grep -i error && echo "ERROR in $f"
done

# Fix the syntax error, then:
sudo augenrules --load
sudo systemctl restart auditd
```

#### B. Missing Log Directory

**Diagnosis:**
```bash
ls -la /var/log/audit/
```

**Solution:**
```bash
sudo mkdir -p /var/log/audit
sudo chmod 750 /var/log/audit
sudo chown root:adm /var/log/audit
sudo systemctl restart auditd
```

---

### 2. Rules Not Loading

**Symptom:**
```bash
sudo auditctl -l
# Shows: No rules
```

**Possible Causes:**

#### A. Rules Not in Correct Directory

**Diagnosis:**
```bash
ls -la /etc/audit/rules.d/
```

**Solution:**
```bash
# Ensure rules have .rules extension
sudo mv /etc/audit/rules.d/my-rules /etc/audit/rules.d/my-rules.rules

# Reload
sudo augenrules --load
```

#### B. Immutable Mode Active

If you previously enabled `-e 2`, rules won't load until reboot.

**Diagnosis:**
```bash
sudo auditctl -s | grep enabled
# If shows "enabled 2", immutable mode is active
```

**Solution:**
```bash
# Must reboot to change rules
sudo reboot
```

---

### 3. Lost Events (Backlog Overflow)

**Symptom:**
```bash
sudo auditctl -s
# Shows: lost 12345
```

**Cause:** Event generation faster than processing.

**Solution:**

1. Increase backlog limit:
```bash
# Edit rules file, add at beginning:
-b 32768

# Or for very busy systems:
-b 65536

sudo augenrules --load
```

2. Reduce rule verbosity:
```bash
# Remove or comment out high-volume rules
# Especially: execve tracking, file access tracking
```

3. Check disk I/O:
```bash
# If disk is slow, consider:
# - Moving audit logs to faster storage
# - Using asynchronous flush mode
```

---

### 4. High Disk Usage

**Symptom:**
```bash
du -sh /var/log/audit/
# Shows: 5.0G or more
```

**Solution:**

1. Configure rotation in `/etc/audit/auditd.conf`:
```ini
max_log_file = 50        # MB per file
num_logs = 5             # Keep 5 files (250MB total)
max_log_file_action = rotate
```

2. Apply and restart:
```bash
sudo systemctl restart auditd
```

3. Manually clean old logs (if needed):
```bash
sudo rm /var/log/audit/audit.log.[0-9]*
sudo systemctl restart auditd
```

---

### 5. No Events Being Logged

**Symptom:**
```bash
sudo ausearch -ts today
# Shows: <no matches>
```

**Possible Causes:**

#### A. No Rules Loaded

```bash
sudo auditctl -l
# If empty, load rules:
sudo augenrules --load
```

#### B. Service Not Running

```bash
sudo systemctl status auditd
# If not running:
sudo systemctl start auditd
```

#### C. Wrong auid Filter

Events from users with `auid < 1000` or `auid = 4294967295` (unset) won't be logged.

**Test:**
```bash
# Check your auid
cat /proc/self/loginuid

# If 4294967295, you logged in without PAM audit session
# Fix: Re-login via SSH or console
```

---

### 6. Can't Change Rules (Immutable Mode)

**Symptom:**
```bash
sudo auditctl -R /etc/audit/rules.d/new.rules
# Error: The audit system is in immutable mode
```

**Cause:** `-e 2` was set (immutable mode).

**Solution:**
```bash
# 1. Edit the rule files as needed
sudo nano /etc/audit/rules.d/99-cis-base.rules

# 2. Regenerate combined rules
sudo augenrules

# 3. Reboot to apply
sudo reboot
```

---

### 7. ausearch Returns Nothing

**Symptom:**
```bash
sudo ausearch -k privileged
# <no matches>
```

**Possible Causes:**

#### A. Wrong Key

```bash
# List all keys in use
sudo auditctl -l | grep -oP 'key=\K\w+' | sort -u
```

#### B. Time Range Issue

```bash
# Be explicit about time range
sudo ausearch -k privileged -ts today -te now

# Or last hour
sudo ausearch -k privileged -ts recent
```

#### C. No Matching Events Yet

```bash
# Trigger a test event
sudo ls /root

# Then search
sudo ausearch -k actions -ts recent
```

---

### 8. aureport Errors

**Symptom:**
```bash
sudo aureport --summary
# Error: ausearch-common getnode: Invalid or missing input data
```

**Cause:** Corrupted log file.

**Solution:**
```bash
# Rotate the corrupt log
sudo systemctl kill -s USR1 auditd

# Or restart service
sudo systemctl restart auditd
```

---

### 9. High CPU Usage

**Symptom:** auditd or kauditd using high CPU.

**Cause:** Too many events being generated.

**Solution:**

1. Identify noisy rules:
```bash
# Count events by key
sudo aureport -k --summary | head -20
```

2. Add exclusions for noisy events:
```bash
# Example: Exclude cron credential events
-a always,exclude -F msgtype=CRED_ACQ -F exe=/usr/sbin/cron
-a always,exclude -F msgtype=CRED_DISP -F exe=/usr/sbin/cron
```

3. Consider removing execve tracking:
```bash
# If exec tracking is too noisy, comment it out:
# -a always,exit -F arch=b64 -S execve -k exec
```

---

### 10. Docker Container Events Not Logged

**Symptom:** Container actions not appearing in audit log.

**Cause:** Container processes may not have audit session.

**Solution:**

1. Ensure Docker rules are loaded:
```bash
sudo auditctl -l | grep docker
```

2. Monitor Docker socket instead:
```bash
-w /var/run/docker.sock -p wa -k docker_socket
```

3. Track Docker CLI usage:
```bash
-a always,exit -F path=/usr/bin/docker -F perm=x -k docker_cmd
```

---

## Diagnostic Commands

### Full System Check

```bash
#!/bin/bash
echo "=== auditd Diagnostic Report ==="
echo ""
echo "Service Status:"
systemctl status auditd --no-pager
echo ""
echo "Audit Status:"
sudo auditctl -s
echo ""
echo "Rules Loaded:"
sudo auditctl -l | wc -l
echo ""
echo "Lost Events:"
sudo auditctl -s | grep lost
echo ""
echo "Log Size:"
du -sh /var/log/audit/
echo ""
echo "Recent Errors:"
sudo journalctl -u auditd -n 10 --no-pager -p err
```

### Test Audit Logging

```bash
#!/bin/bash
echo "Testing audit logging..."

# Trigger various events
echo "1. Testing sudo (key: actions)..."
sudo ls /root > /dev/null 2>&1

echo "2. Testing file permission change (key: perm_mod)..."
touch /tmp/test_audit_$$
chmod 600 /tmp/test_audit_$$
rm /tmp/test_audit_$$

echo "3. Waiting 2 seconds for logs..."
sleep 2

echo "4. Searching for test events..."
sudo ausearch -ts recent -k actions | head -5
sudo ausearch -ts recent -k perm_mod | head -5

echo "Test complete!"
```

## Getting Help

1. **Check logs:**
   ```bash
   sudo journalctl -u auditd -f
   ```

2. **Verbose mode:**
   ```bash
   sudo auditd -f -l  # Foreground with logging
   ```

3. **Man pages:**
   ```bash
   man auditd
   man auditctl
   man ausearch
   man aureport
   ```

4. **Red Hat documentation:** [Auditing the System](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/security_hardening/auditing-the-system_security-hardening)
