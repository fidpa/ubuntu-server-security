# AIDE Boot Resiliency

## Overview

AIDE (Advanced Intrusion Detection Environment) must start correctly after system boot to maintain file integrity monitoring. This document covers boot-time behavior, systemd dependencies, and recovery strategies.

## systemd Service Dependencies

### Required Dependencies

AIDE services require proper ordering to ensure:
1. Filesystems are mounted (`local-fs.target`)
2. Network is available (`network.target`)
3. Temporary directories exist (`tmp.mount`)

**Minimal Unit Configuration**:

```ini
[Unit]
Description=AIDE Database Update
After=local-fs.target network.target
Requires=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-aide-db.sh
TimeoutStartSec=30m

[Install]
WantedBy=multi-user.target
```

### Dependency Chain

```
Boot Sequence:
├── local-fs.target (mount /var, /tmp, etc.)
├── network.target (network interfaces up)
├── multi-user.target
    └── aide-update.service (starts here)
```

**Why `local-fs.target` is Critical**:
- AIDE database lives in `/var/lib/aide/`
- If `/var` is not mounted → service fails
- systemd auto-adds `var.mount` when `ReadWritePaths=/var/lib/aide` is set

**Best Practice**: Explicitly specify `After=local-fs.target` for clarity.

---

## Boot-Time Timeouts

### Problem: Slow AIDE Scans

AIDE can take 5-15 minutes on large filesystems. If boot-time timeout is too short, systemd kills the service.

**Symptoms**:
```
systemctl status aide-update.service
# Main process exited, code=killed, status=15/TERM
# Timed out
```

**Solution**: Increase `TimeoutStartSec`

```ini
[Service]
TimeoutStartSec=30min  # Default: 90s (too short!)
```

**Verification**:
```bash
# Check current timeout
systemctl show aide-update.service -p TimeoutStartUSec
# Expected: 30min0s

# Monitor boot-time execution
journalctl -u aide-update.service -b
```

---

## systemd-tmpfiles Permission Management

### Problem: Permissions Reset at Boot

systemd-tmpfiles.service runs early in boot and can reset directory permissions to default values, overriding manually configured permissions.

**Symptom After Reboot**:
```bash
$ sudo ls -ld /var/lib/aide/
drwx------ _aide root  # Permissions reset to 0700!
# Expected: drwxr-x--- _aide _aide
```

**Root Cause**: Default configuration in `/usr/lib/tmpfiles.d/aide-common.conf`:

```
d /var/lib/aide    0700    _aide    root
```

**Impact**:
- Group is `root` (monitoring users in `_aide` group lose access)
- Permissions are `0700` (no group read permission)
- Manually set correct permissions are overwritten at each boot

### Solution: tmpfiles.d Override

Create local override in `/etc/tmpfiles.d/` (higher priority than `/usr/lib/tmpfiles.d/`):

```bash
# Create override
sudo tee /etc/tmpfiles.d/aide-common.conf > /dev/null << 'EOF'
# Override: Group _aide (not root), Permissions 0750 (not 0700)
# Fix for systemd-tmpfiles permission reset on reboot
d /run/aide            0700    _aide    root
d /var/log/aide        2755    _aide    adm
d /var/lib/aide        0750    _aide    _aide
EOF

# Apply immediately (no reboot needed)
sudo systemd-tmpfiles --create /etc/tmpfiles.d/aide-common.conf
```

### Verification

**Before Reboot**:
```bash
# Check override exists
ls -l /etc/tmpfiles.d/aide-common.conf

# Verify correct permissions
sudo ls -ld /var/lib/aide/
# Expected: drwxr-x--- _aide _aide

# Test monitoring access
sudo -u monitoring-user test -r /var/lib/aide/aide.db && echo "✅ OK"
```

**After Reboot**:
```bash
# Permissions should persist
sudo ls -ld /var/lib/aide/
# Should still show: drwxr-x--- _aide _aide
```

**See Also**: [SETUP.md § Fix systemd-tmpfiles](SETUP.md#10-fix-systemd-tmpfiles-permission-reset)

---

## Emergency Mode Recovery

### Scenario: AIDE Blocks Boot

If AIDE service is misconfigured and blocks boot, system drops to emergency mode.

**Recovery Steps**:

1. **Boot to Emergency Mode**:
   ```bash
   # Kernel parameter at GRUB
   systemd.unit=emergency.target
   ```

2. **Disable AIDE Temporarily**:
   ```bash
   systemctl mask aide-update.service
   systemctl mask aide-update.timer
   ```

3. **Reboot Normally**:
   ```bash
   systemctl reboot
   ```

4. **Fix Configuration**:
   ```bash
   # Edit service file
   sudo nano /etc/systemd/system/aide-update.service

   # Fix dependencies (add local-fs.target)
   # Fix timeout (increase TimeoutStartSec)

   sudo systemctl daemon-reload
   ```

5. **Re-enable AIDE**:
   ```bash
   systemctl unmask aide-update.service
   systemctl unmask aide-update.timer
   systemctl enable aide-update.timer
   systemctl start aide-update.timer
   ```

### Skip AIDE at Boot (Temporary)

Use `systemd.mask=` kernel parameter:

```bash
# At GRUB, add to kernel command line:
systemd.mask=aide-update.service
```

---

## Fallback Strategies

### 1. Conditional Execution

Only run AIDE if database exists:

```ini
[Unit]
ConditionPathExists=/var/lib/aide/aide.db

[Service]
ExecStartPre=/usr/bin/test -r /var/lib/aide/aide.db
ExecStart=/usr/bin/aide --check
```

### 2. Transient Units

For one-time AIDE runs (not persistent):

```bash
systemd-run --unit=aide-oneshot --on-boot=300 /usr/bin/aide --check
```

Runs 5 minutes (300s) after boot, does not block boot sequence.

### 3. Separate Timer vs. Boot Service

**Pattern**: Timer for daily checks, boot service optional

```bash
# aide-update.timer (daily at 3am)
[Unit]
Description=Daily AIDE Check

[Timer]
OnCalendar=daily
OnCalendar=03:00
Persistent=true

[Install]
WantedBy=timers.target  # NOT multi-user.target!
```

**Benefits**:
- Daily checks run via timer
- Boot does not depend on AIDE
- Faster boot times

---

## Boot-Time Debugging

### Check Boot Duration

```bash
# Total boot time
systemd-analyze

# Per-service breakdown
systemd-analyze blame | grep aide

# Critical chain (dependency path)
systemd-analyze critical-chain aide-update.service
```

### Common Issues

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| Service timeout | `TimeoutStartSec=90s` too short | Increase to 30min |
| `/var/lib/aide: No such file` | Missing `local-fs.target` | Add `After=local-fs.target` |
| Emergency mode on boot | Failed service blocks boot | Disable via `systemd.mask=` |
| Service not starting | Timer misconfigured | Check `WantedBy=timers.target` |

### Logs

```bash
# Boot-specific logs
journalctl -u aide-update.service -b

# Last 50 lines
journalctl -u aide-update.service -n 50

# Follow live
journalctl -u aide-update.service -f

# Show only errors
journalctl -u aide-update.service -p err
```

---

## Performance Optimization

### Reduce Boot Impact

**1. Delay AIDE Execution**:

```ini
[Service]
# Wait 2 minutes after boot before starting
ExecStartPre=/bin/sleep 120
```

**2. Lower Priority**:

```ini
[Service]
Nice=19           # Lowest CPU priority
IOSchedulingClass=idle  # Lowest I/O priority
```

**3. Exclude Fast-Changing Directories**:

```bash
# In aide.conf
!/var/log
!/var/cache
!/tmp
```

---

## Best Practices

1. **✅ Use `local-fs.target`**: Always specify in `After=`
2. **✅ Increase Timeout**: Set `TimeoutStartSec=30min` minimum
3. **✅ Use Timers**: Prefer daily timer over boot-time service
4. **✅ Test Recovery**: Practice emergency mode recovery
5. **✅ Monitor Boot Time**: Use `systemd-analyze` regularly
6. **❌ Never `RequiresMountsFor=/`**: systemd handles this automatically
7. **❌ Never block `multi-user.target`**: Use `WantedBy=timers.target` instead

---

## Testing Boot Resiliency

### Simulate Boot Failure

```bash
# 1. Temporarily break AIDE service
sudo mv /var/lib/aide/aide.db /var/lib/aide/aide.db.bak

# 2. Reboot
sudo reboot

# 3. Check logs
journalctl -u aide-update.service -b

# 4. Restore
sudo mv /var/lib/aide/aide.db.bak /var/lib/aide/aide.db
```

### Automated Boot Test

Create a oneshot service that validates AIDE after boot:

```ini
[Unit]
Description=AIDE Boot Test
After=aide-update.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/validate-aide-boot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

---

## See Also

- **SETUP.md** - AIDE installation and configuration
- **TROUBLESHOOTING.md** - Common AIDE issues
- **BEST_PRACTICES.md** - Production guidelines
- **systemd/README.md** - Service and timer configuration
