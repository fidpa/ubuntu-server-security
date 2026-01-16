# AIDE Troubleshooting Guide

Common issues and solutions for AIDE on Ubuntu servers.

## Database Issues

### Problem: Database Not Found

**Symptom**:
```
AIDE database not found: /var/lib/aide/aide.db
```

**Causes**:
1. AIDE never initialized
2. Database was deleted
3. Wrong path in configuration

**Solutions**:

```bash
# Check if database exists
ls -la /var/lib/aide/aide.db

# If missing, initialize
sudo aideinit

# Activate new database
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Verify
sudo aide --check
```

---

### Problem: Database Corruption

**Symptom**:
```
Error reading database: /var/lib/aide/aide.db
```

**Causes**:
1. Disk full during DB write
2. Power loss during update
3. File system corruption

**Solutions**:

```bash
# Check disk space
df -h /var/lib/aide

# Try to read database
sudo aide --check

# If corrupted, restore from backup
ls -la /var/backups/aide/
sudo cp /var/backups/aide/aide.db.YYYYMMDD_HHMMSS /var/lib/aide/aide.db

# If no backup, reinitialize (loses baseline!)
sudo aideinit
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

**Prevention**:
- Enable `backup-aide-db.sh` script (offsite backups)
- Monitor disk space (`aide_db_size_bytes` metric)

---

### Problem: Database Too Large

**Symptom**:
- Database is several GB
- AIDE check takes hours
- Out of disk space

**Causes**:
- Monitoring too many files
- Large number of small files
- Inefficient excludes

**Solutions**:

```bash
# Check database size
ls -lh /var/lib/aide/aide.db

# Analyze what's being monitored
sudo aide --config-check | grep "^/" | wc -l

# Add more excludes (see FALSE_POSITIVE_REDUCTION.md)
# Examples:
sudo nano /etc/aide/aide.conf.d/99-custom.conf
```

Add excludes:
```aide
# Exclude large directories with many files
!/usr/share/doc
!/usr/share/man
!/var/lib/docker
```

```bash
# Reinitialize with new config
sudo aideinit
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

**Typical sizes**:
- Small server (<10k files): <10 MB
- Medium server (100k files): 10-100 MB
- Large server (1M+ files): 100-500 MB

---

## Permission Issues

### Problem: Permission Denied (Non-Root User)

**Symptom**:
```bash
$ aide --check
Permission denied: /var/lib/aide/aide.db
```

**Cause**: Database is `root:root 600` by default.

**Solution**: Use group-based read access:

```bash
# Create _aide group
sudo groupadd --system _aide

# Fix database permissions
sudo chown root:_aide /var/lib/aide/aide.db
sudo chmod 640 /var/lib/aide/aide.db
sudo chown root:_aide /var/lib/aide
sudo chmod 750 /var/lib/aide

# Add your user to _aide group
sudo usermod -aG _aide $USER

# Re-login to apply group membership
exit  # then ssh back in

# Test
aide --check
```

**Automatic fix**: The `update-aide-db.sh` script does this automatically.

---

### Problem: Monitoring Tools Can't Read Database

**Symptom**: Prometheus metrics show `-1` (database missing) but database exists.

**Cause**: `prometheus` user cannot read database.

**Solution**:

```bash
# Add prometheus to _aide group
sudo usermod -aG _aide prometheus

# Restart node_exporter
sudo systemctl restart node_exporter

# Verify
sudo -u prometheus cat /var/lib/aide/aide.db >/dev/null
echo $?  # Should be 0
```

---

## Timer/Service Issues

### Problem: Timer Not Running

**Symptom**:
```bash
sudo systemctl status aide-update.timer
# Output: inactive (dead)
```

**Solutions**:

```bash
# Check if enabled
sudo systemctl is-enabled aide-update.timer

# Enable and start
sudo systemctl enable aide-update.timer
sudo systemctl start aide-update.timer

# Verify
sudo systemctl list-timers aide-update.timer
```

---

### Problem: Service Fails

**Symptom**:
```bash
sudo systemctl status aide-update.service
# Output: failed
```

**Diagnosis**:

```bash
# Check logs
sudo journalctl -u aide-update.service -n 100

# Common errors:
# 1. Script not found
ls -la /usr/local/bin/update-aide-db.sh

# 2. Permission denied
sudo -u root /usr/local/bin/update-aide-db.sh --check

# 3. Timeout
# See timeout issues below
```

---

### Problem: Timeout

**Symptom**:
```
aide-update.service: Start operation timed out
```

**Causes**:
1. Large database (millions of files)
2. Slow disk I/O
3. Insufficient timeout setting

**Solutions**:

```bash
# Check current timeout
sudo systemctl cat aide-update.service | grep TimeoutStartSec

# Increase timeout
sudo systemctl edit aide-update.service
```

Add:
```ini
[Service]
TimeoutStartSec=240min  # 4 hours for very large servers
```

```bash
# Reload and test
sudo systemctl daemon-reload
sudo systemctl start aide-update.service
```

**Typical timeouts**:
- Small server (<100k files): 30 min
- Medium server (100k-1M files): 60-90 min
- Large server (1M+ files): 120-240 min

---

## False-Positive Issues

### Problem: Too Many Changes Detected

**Symptom**: AIDE reports thousands of changes daily.

**Cause**: Default configuration monitors too much.

**Solution**: See [FALSE_POSITIVE_REDUCTION.md](FALSE_POSITIVE_REDUCTION.md) for complete guide.

**Quick fixes**:

```bash
# Enable package update filtering
sudo nano /etc/default/aide
```
Set:
```bash
FILTERUPDATES=yes
```

```bash
# Add service-specific excludes
sudo cp aide/drop-ins/10-docker-excludes.conf /etc/aide/aide.conf.d/
sudo cp aide/drop-ins/40-systemd-excludes.conf /etc/aide/aide.conf.d/

# Reinitialize
sudo aideinit
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

---

## Configuration Issues

### Problem: Config Check Fails

**Symptom**:
```bash
sudo aide --config-check
# Error: Syntax error in aide.conf
```

**Diagnosis**:

```bash
# Check syntax in detail
sudo aide --config-check --verbose

# Common issues:
# 1. Typo in group name
# 2. Missing @@x_include directory
# 3. Invalid regex pattern
```

**Solution**: Review error message, fix syntax, retest.

---

### Problem: Drop-ins Not Loaded

**Symptom**: Drop-in rules not applied.

**Causes**:
1. `@@x_include` line missing in `aide.conf`
2. Drop-in directory doesn't exist
3. Wrong file permissions

**Solution**:

```bash
# Check if @@x_include is present
grep "@@x_include" /etc/aide/aide.conf

# Check drop-in directory
ls -la /etc/aide/aide.conf.d/

# Check file permissions (must be readable by root)
sudo chmod 644 /etc/aide/aide.conf.d/*.conf

# Test
sudo aide --config-check
```

---

## Email/Notification Issues

### Problem: No Email Reports

**Symptom**: AIDE runs but no emails received.

**Causes**:
1. No MTA (Mail Transfer Agent) installed
2. Email suppressed (`QUIETREPORTS=yes`)
3. Email delivery failed

**Solutions**:

```bash
# Install MTA
sudo apt install postfix  # or sendmail, exim4

# Check QUIETREPORTS
grep QUIETREPORTS /etc/default/aide
# Should be: QUIETREPORTS=no

# Test email delivery
echo "Test" | mail -s "AIDE Test" root

# Check mail logs
sudo tail -f /var/log/mail.log
```

---

### Problem: Email Too Large

**Symptom**: Email server rejects AIDE report (>10 MB).

**Cause**: Too many changes reported.

**Solution**:

```bash
# Enable truncation
sudo nano /etc/default/aide
```
Set:
```bash
TRUNCATEDETAILS=yes
LINES=1000  # Limit to first 1000 changes
```

**Alternative**: Use Prometheus metrics instead of email.

---

## Metrics/Monitoring Issues

### Problem: Metrics Not Updating

**Symptom**: `aide_db_age_seconds` stays constant.

**Causes**:
1. Metrics exporter not running
2. `ExecStartPost` hook missing in service unit
3. Metrics file not writable

**Solutions**:

```bash
# Check if metrics file exists
ls -la /var/lib/node_exporter/textfile_collector/aide.prom

# Check file timestamp (should update daily)
stat /var/lib/node_exporter/textfile_collector/aide.prom

# Run exporter manually
sudo /usr/local/bin/aide-metrics-exporter.sh

# Check service has ExecStartPost
sudo systemctl cat aide-update.service | grep ExecStartPost

# Check logs
sudo journalctl -u aide-update.service -n 50
```

---

## Recovery Procedures

### Complete AIDE Reinstall

If AIDE is completely broken:

```bash
# 1. Remove immutable flags (if set)
sudo chattr -i /usr/bin/aide /etc/aide/aide.conf

# 2. Purge AIDE
sudo apt purge aide aide-common

# 3. Remove data
sudo rm -rf /var/lib/aide /etc/aide

# 4. Reinstall
sudo apt install aide aide-common

# 5. Restore configuration from backup
sudo cp ~/backup/aide.conf /etc/aide/aide.conf
sudo cp -r ~/backup/aide.conf.d /etc/aide/

# 6. Initialize
sudo aideinit
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# 7. Restore immutable flags
sudo chattr +i /usr/bin/aide /etc/aide/aide.conf
```

---

## See Also

- [SETUP.md](SETUP.md) - Initial configuration
- [FALSE_POSITIVE_REDUCTION.md](FALSE_POSITIVE_REDUCTION.md) - Reduce noise
- [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) - Monitoring setup
- [AIDE Manual](https://aide.github.io/doc/)
