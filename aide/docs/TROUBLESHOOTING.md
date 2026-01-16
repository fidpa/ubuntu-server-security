# AIDE Troubleshooting

Common issues and solutions for AIDE configuration and operation.

## Database Issues

### Issue 1: Database Missing or Not Initialized

**Symptoms**:
```bash
$ sudo aide --check
AIDE database does not exist or is not accessible
```

**Causes**:
- Database was never initialized
- Database file was deleted
- Wrong file path in configuration

**Solution**:
```bash
# 1. Initialize new database
sudo aideinit

# 2. Move to active location
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# 3. Set correct permissions
sudo chown root:_aide /var/lib/aide/aide.db
sudo chmod 640 /var/lib/aide/aide.db

# 4. Verify
ls -l /var/lib/aide/aide.db
```

---

### Issue 2: Permission Denied Reading Database

**Symptoms**:
```bash
$ aide --check
aide: Can't open file /var/lib/aide/aide.db for reading
```

**Causes**:
- User not in `_aide` group
- Directory permissions too restrictive (700)
- SELinux/AppArmor blocking access

**Solution**:
```bash
# 1. Check current permissions
ls -ld /var/lib/aide
ls -l /var/lib/aide/aide.db

# 2. Fix directory permissions
sudo chmod 750 /var/lib/aide
sudo chown root:_aide /var/lib/aide

# 3. Fix database permissions
sudo chmod 640 /var/lib/aide/aide.db
sudo chown root:_aide /var/lib/aide/aide.db

# 4. Add user to _aide group
sudo usermod -aG _aide your-user

# 5. Re-login or use newgrp
newgrp _aide
```

**Validation**:
```bash
./scripts/validate-permissions.sh your-user
```

---

## Service and Timer Issues

### Issue 3: Timer Not Running

**Symptoms**:
```bash
$ systemctl status aide-update.timer
● aide-update.timer - loaded inactive dead
```

**Solution**:
```bash
# 1. Enable timer
sudo systemctl enable aide-update.timer

# 2. Start timer
sudo systemctl start aide-update.timer

# 3. Verify
systemctl list-timers aide-update.timer
```

---

### Issue 4: Service Timeout

**Symptoms**:
```bash
$ journalctl -u aide-update.service
Main process exited, code=killed, status=15/TERM
Timed out
```

**Cause**: AIDE scan takes longer than configured timeout

**Solution**:
```bash
# 1. Increase timeout in service unit
sudo nano /etc/systemd/system/aide-update.service

# Add or modify:
[Service]
TimeoutStartSec=30min  # Increase from 90s

# 2. Reload systemd
sudo systemctl daemon-reload

# 3. Test
sudo systemctl start aide-update.service
```

---

### Issue 5: Immutable Flag Prevents APT Upgrade

**Symptoms**:
```bash
$ sudo apt upgrade aide
dpkg: error processing aide (--configure):
unable to install new version: Operation not permitted
```

**Cause**: `/usr/bin/aide` has immutable flag (`chattr +i`)

**Solution**:
```bash
# 1. Check immutable flag
sudo lsattr /usr/bin/aide
# Shows: ----i---------e-------

# 2. Remove immutable flag
sudo chattr -i /usr/bin/aide

# 3. Perform upgrade
sudo apt upgrade aide

# 4. Restore immutable flag
sudo chattr +i /usr/bin/aide

# 5. Verify
sudo lsattr /usr/bin/aide
```

---

## Configuration Issues

### Issue 6: Syntax Error in Configuration

**Symptoms**:
```bash
$ sudo aide --check
aide: Error in configuration file /etc/aide/aide.conf
```

**Solution**:
```bash
# 1. Check configuration syntax
sudo aide --check-config

# 2. Check specific line
sudo aide --config=/etc/aide/aide.conf --check-config

# 3. Common errors:
#    - Missing '=' in assignments
#    - Typo in rule names (H vs HASH)
#    - Missing '@@' for includes
```

---

### Issue 7: False-Positive Alerts

**Symptoms**: AIDE reports changes in legitimate system files (logs, caches, databases)

**Solution**: Add excludes to drop-in configuration

```bash
# 1. Create custom excludes file
sudo nano /etc/aide/aide.conf.d/99-custom-excludes.conf

# 2. Add excludes (examples):
!/var/log
!/var/cache
!/tmp
!/var/lib/docker
!/var/lib/postgresql/.*/pg_wal

# 3. Update database
sudo /usr/local/bin/update-aide-db.sh
```

**See Also**: [FALSE_POSITIVE_REDUCTION.md](FALSE_POSITIVE_REDUCTION.md)

---

## Performance Issues

### Issue 8: AIDE Scan Too Slow

**Symptoms**: AIDE check takes 30+ minutes

**Causes**:
- Large filesystem (2TB+)
- Many small files
- Slow disk I/O

**Solutions**:

**1. Reduce scope** (exclude unnecessary directories):
```bash
# Add to aide.conf.d/99-custom-excludes.conf
!/var/lib/docker  # Docker overlay filesystems
!/home/.*/.cache  # User caches
!/opt/backups     # Backup directories
```

**2. Enable multi-threading** (AIDE 0.18+):
```bash
# In /etc/aide/aide.conf
num_workers=4  # Use 4 CPU cores
```

**Note**: Multi-threading may not work on all filesystems (NVMe SSD).

**3. Lower priority** (reduce system impact):
```bash
# In service unit
[Service]
Nice=19
IOSchedulingClass=idle
```

---

## Immutable Flag Issues

### Issue 9: Cannot Modify Protected Files

**Symptoms**:
```bash
$ sudo vim /etc/aide/aide.conf
Cannot save: Operation not permitted
```

**Cause**: Immutable flag is set

**Solution**:
```bash
# 1. Remove immutable flag temporarily
sudo chattr -i /etc/aide/aide.conf

# 2. Edit file
sudo vim /etc/aide/aide.conf

# 3. Restore immutable flag
sudo chattr +i /etc/aide/aide.conf
```

**Validation**:
```bash
./scripts/validate-immutable-flags.sh
```

---

### Issue 10: Permissions Reset After Reboot

**Symptoms**: After reboot, monitoring users cannot read AIDE database

```bash
$ test -r /var/lib/aide/aide.db
# Exit Code 1 - Permission Denied

$ sudo ls -ld /var/lib/aide/
drwx------ _aide root  # Permissions reset to 0700!
```

**Cause**: systemd-tmpfiles resets permissions to default values from `/usr/lib/tmpfiles.d/aide-common.conf`

**Solution**: Create override in `/etc/tmpfiles.d/`

```bash
# Create override
sudo tee /etc/tmpfiles.d/aide-common.conf > /dev/null << 'EOF'
# Override: Group _aide (not root), Permissions 0750 (not 0700)
d /run/aide            0700    _aide    root
d /var/log/aide        2755    _aide    adm
d /var/lib/aide        0750    _aide    _aide
EOF

# Apply immediately
sudo systemd-tmpfiles --create /etc/tmpfiles.d/aide-common.conf

# Verify
sudo ls -ld /var/lib/aide/
# Expected: drwxr-x--- _aide _aide
```

**Prevention**: Always create tmpfiles.d override during initial setup

**See Also**: [SETUP.md § Fix systemd-tmpfiles](SETUP.md#10-fix-systemd-tmpfiles-permission-reset), [BOOT_RESILIENCY.md](BOOT_RESILIENCY.md)

---

## Diagnostic Commands

### Check Service Status
```bash
# Timer status
systemctl status aide-update.timer
systemctl list-timers aide-update.timer

# Service status
systemctl status aide-update.service

# Service logs
journalctl -u aide-update.service -n 50
journalctl -u aide-update.service -f  # Follow
```

### Check Database
```bash
# Database size
ls -lh /var/lib/aide/aide.db

# Database permissions
ls -l /var/lib/aide/aide.db
getfacl /var/lib/aide/aide.db

# Disk space
df -h /var/lib/aide
```

### Check Permissions
```bash
# Directory
stat -c '%a %U:%G' /var/lib/aide

# Database file
stat -c '%a %U:%G' /var/lib/aide/aide.db

# Immutable flags
sudo lsattr /usr/bin/aide /etc/aide/aide.conf /var/lib/aide/aide.db
```

### Check Configuration
```bash
# Syntax check
sudo aide --check-config

# Show effective configuration
sudo aide --config=/etc/aide/aide.conf --version

# Test manual check
sudo aide --check --config=/etc/aide/aide.conf
```

---

## Validation Scripts

Run validation scripts to check common issues:

```bash
# Validate permissions
./scripts/validate-permissions.sh monitoring-user

# Validate immutable flags
./scripts/validate-immutable-flags.sh
```

---

## Getting Help

If issues persist:

1. **Check logs**: `journalctl -u aide-update.service -n 100`
2. **Test manually**: `sudo aide --check --verbose=5`
3. **Verify configuration**: `sudo aide --check-config`
4. **Run validation scripts**: See above
5. **Review documentation**:
   - [SETUP.md](SETUP.md) - Installation steps
   - [BEST_PRACTICES.md](BEST_PRACTICES.md) - Production guidelines
   - [BOOT_RESILIENCY.md](docs/BOOT_RESILIENCY.md) - Boot issues
   - [MONITORING_AIDE_ACCESS.md](docs/MONITORING_AIDE_ACCESS.md) - Permission issues

---

## Emergency Recovery

### Disable AIDE Temporarily

If AIDE blocks system operation:

```bash
# Stop timer
sudo systemctl stop aide-update.timer
sudo systemctl disable aide-update.timer

# Mask service (prevent accidental start)
sudo systemctl mask aide-update.service

# Later, re-enable:
sudo systemctl unmask aide-update.service
sudo systemctl enable --now aide-update.timer
```

### Rebuild Database from Scratch

If database is corrupted:

```bash
# 1. Backup old database
sudo mv /var/lib/aide/aide.db /var/lib/aide/aide.db.corrupted

# 2. Initialize new database
sudo aideinit

# 3. Activate new database
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# 4. Set permissions
sudo chown root:_aide /var/lib/aide/aide.db
sudo chmod 640 /var/lib/aide/aide.db
```
