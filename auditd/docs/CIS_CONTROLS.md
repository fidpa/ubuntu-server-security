# auditd CIS Benchmark Controls

Mapping of CIS Ubuntu Linux Benchmark Section 4.1.x to audit rules.

## Overview

The CIS Benchmark Section 4.1 covers "Configure System Accounting (auditd)". This document maps each control to the corresponding rule in our templates.

## Control Summary

| CIS ID | Description | Level | Rule Template | Status |
|--------|-------------|-------|---------------|--------|
| 4.1.1.1 | Ensure auditd is installed | L1 | N/A (package) | Manual |
| 4.1.1.2 | Ensure auditd service is enabled | L1 | N/A (systemd) | Manual |
| 4.1.1.3 | Ensure auditing for processes that start prior to auditd | L1 | GRUB config | Manual |
| 4.1.1.4 | Ensure audit_backlog_limit is sufficient | L1 | `-b 8192` | Base |
| 4.1.2.1 | Ensure audit log storage size is configured | L1 | auditd.conf | Manual |
| 4.1.2.2 | Ensure audit logs are not automatically deleted | L1 | auditd.conf | Manual |
| 4.1.2.3 | Ensure system is disabled when audit logs are full | L2 | auditd.conf | Manual |
| 4.1.3 | Ensure events that modify date and time are collected | L1 | time-change | Base |
| 4.1.4 | Ensure events that modify user/group info are collected | L1 | identity | Base |
| 4.1.5 | Ensure events that modify network environment are collected | L1 | system-locale | Base |
| 4.1.6 | Ensure events that modify MAC are collected | L1 | MAC-policy | Base |
| 4.1.7 | Ensure login and logout events are collected | L1 | logins | Base |
| 4.1.8 | Ensure session initiation info is collected | L1 | session | Base |
| 4.1.9 | Ensure DAC permission modification events are collected | L1 | perm_mod | Base |
| 4.1.10 | Ensure unsuccessful unauthorized file access attempts | L1 | access | Base |
| 4.1.11 | Ensure use of privileged commands is collected | L1 | privileged | Base |
| 4.1.12 | Ensure successful file system mounts are collected | L1 | mounts | Base |
| 4.1.13 | Ensure file deletion events by users are collected | L2 | delete | Aggressive |
| 4.1.14 | Ensure changes to sudoers is collected | L1 | scope | Base |
| 4.1.15 | Ensure sudo command executions are collected | L1 | actions | Base |
| 4.1.16 | Ensure kernel module loading/unloading is collected | L1 | modules | Base |
| 4.1.17 | Ensure the audit configuration is immutable | L2 | `-e 2` | Aggressive |

## Detailed Control Mapping

### 4.1.1.1 - Ensure auditd is installed

**Level:** 1

**Manual Step:**
```bash
sudo apt install auditd audispd-plugins
```

**Verification:**
```bash
dpkg -s auditd | grep Status
# Expected: Status: install ok installed
```

---

### 4.1.1.2 - Ensure auditd service is enabled

**Level:** 1

**Manual Step:**
```bash
sudo systemctl enable auditd
sudo systemctl start auditd
```

**Verification:**
```bash
sudo systemctl is-enabled auditd
# Expected: enabled
```

---

### 4.1.1.3 - Ensure auditing for processes that start prior to auditd

**Level:** 1

**Manual Step:** Add `audit=1` to GRUB kernel parameters.

```bash
# Edit GRUB configuration
sudo nano /etc/default/grub

# Add audit=1 to GRUB_CMDLINE_LINUX
GRUB_CMDLINE_LINUX="audit=1"

# Update GRUB
sudo update-grub
sudo reboot
```

**Verification:**
```bash
grep "audit=1" /proc/cmdline
# Expected: audit=1 appears in output
```

---

### 4.1.1.4 - Ensure audit_backlog_limit is sufficient

**Level:** 1

**Rule:** `audit-base.rules.template`
```
-b 8192
```

**Verification:**
```bash
sudo auditctl -s | grep backlog_limit
# Expected: backlog_limit 8192 (or higher)
```

---

### 4.1.3 - Ensure events that modify date and time are collected

**Level:** 1

**Key:** `time-change`

**Rules:** `audit-base.rules.template`
```
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change
```

**Verification:**
```bash
sudo auditctl -l | grep time-change
# Expected: 5 rules with key=time-change
```

---

### 4.1.4 - Ensure events that modify user/group information are collected

**Level:** 1

**Key:** `identity`

**Rules:** `audit-base.rules.template`
```
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
```

**Verification:**
```bash
sudo auditctl -l | grep identity
# Expected: 5 rules with key=identity
```

---

### 4.1.5 - Ensure events that modify network environment are collected

**Level:** 1

**Key:** `system-locale`

**Rules:** `audit-base.rules.template`
```
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/network -p wa -k system-locale
-w /etc/netplan -p wa -k system-locale
```

---

### 4.1.6 - Ensure events that modify MAC are collected

**Level:** 1

**Key:** `MAC-policy`

**Rules:** `audit-base.rules.template`
```
-w /etc/apparmor/ -p wa -k MAC-policy
-w /etc/apparmor.d/ -p wa -k MAC-policy
```

---

### 4.1.7 - Ensure login and logout events are collected

**Level:** 1

**Key:** `logins`

**Rules:** `audit-base.rules.template`
```
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins
```

---

### 4.1.8 - Ensure session initiation information is collected

**Level:** 1

**Key:** `session`

**Rules:** `audit-base.rules.template`
```
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
```

---

### 4.1.9 - Ensure DAC permission modification events are collected

**Level:** 1

**Key:** `perm_mod`

**Rules:** `audit-base.rules.template`
```
-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
-a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod
```

---

### 4.1.10 - Ensure unsuccessful unauthorized file access attempts are collected

**Level:** 1

**Key:** `access`

**Rules:** `audit-base.rules.template`
```
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access
```

---

### 4.1.11 - Ensure use of privileged commands is collected

**Level:** 1

**Key:** `privileged`

**Rules:** System-specific - generate with:
```bash
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | \
  awk '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged"}'
```

---

### 4.1.12 - Ensure successful file system mounts are collected

**Level:** 1

**Key:** `mounts`

**Rules:** `audit-base.rules.template`
```
-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts
```

---

### 4.1.13 - Ensure file deletion events by users are collected

**Level:** 2

**Key:** `delete`

**Rules:** `audit-aggressive.rules.template`
```
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k delete
```

---

### 4.1.14 - Ensure changes to sudoers is collected

**Level:** 1

**Key:** `scope`

**Rules:** `audit-base.rules.template`
```
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
```

---

### 4.1.15 - Ensure system administrator command executions are collected

**Level:** 1

**Key:** `actions`

**Rules:** `audit-base.rules.template`
```
-a always,exit -F arch=b64 -C euid!=uid -F euid=0 -F auid>=1000 -F auid!=4294967295 -S execve -k actions
-a always,exit -F arch=b32 -C euid!=uid -F euid=0 -F auid>=1000 -F auid!=4294967295 -S execve -k actions
```

---

### 4.1.16 - Ensure kernel module loading and unloading is collected

**Level:** 1

**Key:** `modules`

**Rules:** `audit-base.rules.template`
```
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
```

---

### 4.1.17 - Ensure the audit configuration is immutable

**Level:** 2

**Rule:** Last line in `audit-aggressive.rules.template`
```
-e 2
```

**Warning:** After enabling, rule changes require system reboot!

---

## Compliance Verification Script

```bash
#!/bin/bash
# Verify CIS 4.1.x compliance

echo "=== CIS 4.1.x Audit Compliance Check ==="

# Check installation
echo -n "4.1.1.1 auditd installed: "
dpkg -s auditd &>/dev/null && echo "PASS" || echo "FAIL"

# Check service
echo -n "4.1.1.2 auditd enabled: "
systemctl is-enabled auditd &>/dev/null && echo "PASS" || echo "FAIL"

# Check kernel parameter
echo -n "4.1.1.3 audit=1 in kernel: "
grep -q "audit=1" /proc/cmdline && echo "PASS" || echo "FAIL"

# Check backlog
echo -n "4.1.1.4 backlog_limit: "
auditctl -s | grep -q "backlog_limit [0-9]*" && echo "PASS" || echo "FAIL"

# Check key rules
for key in time-change identity system-locale MAC-policy logins session perm_mod access privileged mounts scope actions modules; do
    echo -n "Rule key $key: "
    auditctl -l | grep -q "key=$key" && echo "PASS" || echo "FAIL"
done

echo "=== Check Complete ==="
```
