# AIDE Best Practices

Production recommendations based on servers with 100% CIS Benchmark compliance.

## Database Management

### 1. Never Auto-Update Database

**Rule**: Always review changes before accepting them.

```bash
# /etc/default/aide
COPYNEWDB=no  # SECURITY CRITICAL!
```

**Why**: A compromised system should not auto-accept its own backdoors.

**Workflow**:
```bash
# 1. AIDE detects changes
sudo aide --check

# 2. Review changes
sudo cat /var/log/aide/aide.log

# 3. Decide: Legitimate update or intrusion?

# 4. If legitimate, update database
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# If intrusion, investigate before updating!
```

---

### 2. Offsite Backups

**Rule**: Keep database backups separate from monitored system.

**Why**: Compromised system can delete local AIDE database to hide tracks.

**Implementation**:
```bash
# Daily offsite backup
sudo cp /var/lib/aide/aide.db /mnt/backup-server/aide/aide.db.$(date +%Y%m%d)

# Or use backup-aide-db.sh script
sudo /usr/local/bin/backup-aide-db.sh
```

**Retention**: 30 days minimum (allows forensics of long-term compromise).

---

### 3. Baseline After Major Changes

**Rule**: Update AIDE database after planned system changes.

**When to update**:
- ✅ After package upgrades (`apt upgrade`)
- ✅ After configuration changes in `/etc`
- ✅ After installing new services
- ✅ After security hardening

**How**:
```bash
# Run update
sudo aide --update

# Review changes
sudo aide --compare

# Accept if expected
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

---

## Configuration Best Practices

### 4. Use Drop-in Pattern

**Rule**: Separate service-specific excludes into drop-in files.

**Benefits**:
- ✅ Easier to add/remove services
- ✅ DRY (base config stays unchanged)
- ✅ Testable (validate drop-ins individually)

**Structure**:
```
/etc/aide/aide.conf              # 120 lines (base)
/etc/aide/aide.conf.d/
├── 10-docker-excludes.conf      # Docker
├── 20-postgresql-excludes.conf  # PostgreSQL
├── 30-nextcloud-excludes.conf   # Nextcloud
└── 99-custom.conf               # Your overrides
```

---

### 5. Document All Excludes

**Rule**: Every exclude must have a rationale comment.

**Why**: Future admins need to understand why something is excluded.

**Example**:
```aide
# Exclude Docker overlay2 filesystems (container filesystems change continuously)
# Intrusion detection: We still monitor /var/lib/docker/volumes structure
!/var/lib/docker/overlay2
/var/lib/docker/volumes VarDir
```

---

### 6. Tune for Your Environment

**Rule**: Default config is too noisy. Invest time in tuning.

**Metrics**:
- **Target**: <50 changes/day on stable server
- **Typical**: <20 changes/day after tuning
- **Baseline**: ~3,000+ changes/day without tuning

**Method**: See [FALSE_POSITIVE_REDUCTION.md](FALSE_POSITIVE_REDUCTION.md)

---

## Monitoring Best Practices

### 7. Monitor Database Age

**Rule**: Alert if database is stale (>25 hours old).

**Why**: Indicates timer failure or disk space issues.

**Prometheus alert**:
```yaml
- alert: AIDEDatabaseStale
  expr: aide_db_age_seconds > 90000  # 25 hours
  for: 10m
  labels:
    severity: warning
```

---

### 8. Track Database Growth

**Rule**: Monitor database size trends.

**Why**: Unexpected growth indicates:
- New files added to monitored paths
- Misconfigured excludes
- Potential intrusion (many new files)

**Typical growth**:
- Small server: <1 MB/day
- Medium server: 1-5 MB/day
- Large server: 5-20 MB/day

**Alert on**: >10 MB/day on small/medium servers.

---

### 9. Daily "All OK" Emails

**Rule**: Receive daily confirmation that AIDE is running.

```bash
# /etc/default/aide
QUIETREPORTS=no
```

**Why**: False-positive fatigue is real, but silence is worse. Daily "No changes" proves AIDE works.

---

## Security Hardening

### 10. Immutable Binary Protection

**Rule**: Protect AIDE binary and config with immutable flag.

```bash
sudo chattr +i /usr/bin/aide
sudo chattr +i /etc/aide/aide.conf
```

**Why**: Prevents rootkit from replacing AIDE.

**Trade-off**: Requires APT hook for upgrades (see [IMMUTABLE_BINARY_PROTECTION.md](IMMUTABLE_BINARY_PROTECTION.md)).

---

### 11. Non-Root Monitoring

**Rule**: Allow monitoring tools to read AIDE database without root.

```bash
# Create _aide group
sudo groupadd --system _aide

# Fix permissions
sudo chown root:_aide /var/lib/aide/aide.db
sudo chmod 640 /var/lib/aide/aide.db

# Add monitoring users
sudo usermod -aG _aide prometheus
```

**Why**: Principle of least privilege - monitoring doesn't need full root.

---

### 12. Filter Package Updates

**Rule**: Enable `FILTERUPDATES` to reduce noise from APT.

```bash
# /etc/default/aide
FILTERUPDATES=yes
```

**Why**: Reduces false-positives by 99%+ while still detecting:
- Unauthorized file modifications
- New files in monitored directories
- Manual edits to `/etc`

---

## Operational Best Practices

### 13. Test Before Production

**Rule**: Test AIDE config on staging/dev before deploying to production.

**Testing checklist**:
- [ ] Config check passes (`aide --config-check`)
- [ ] Database initializes (<30 min)
- [ ] Daily check completes (<30 min for small servers)
- [ ] False-positives <50/day
- [ ] No disk space issues

---

### 14. Integrate with Change Management

**Rule**: Update AIDE database as part of change management process.

**Workflow**:
1. Plan change (e.g., install new package)
2. Execute change
3. Run AIDE update
4. Review changes match what was planned
5. Accept database update
6. Document in change log

---

### 15. CIS Benchmark Alignment

**Rule**: Use AIDE to satisfy CIS Benchmark control 1.3.1 (Ensure AIDE is installed).

**CIS Requirements**:
- ✅ AIDE installed
- ✅ Database initialized
- ✅ Regular checks scheduled (daily)
- ✅ Changes reviewed before database update

**Validation**:
```bash
# Check AIDE is installed
dpkg -l | grep aide

# Check timer is active
systemctl is-active aide-update.timer

# Check last run
sudo journalctl -u aide-update.service -n 1
```

---

## Performance Optimization

### 16. Tune Worker Threads

**Rule**: Set `num_workers` to match CPU cores.

```aide
# aide.conf
num_workers=8  # For 8-core CPU
```

**Typical values**:
- Small server (2 cores): `num_workers=2`
- Medium server (4-8 cores): `num_workers=4`
- Large server (16+ cores): `num_workers=8`

**Don't over-tune**: More workers = more memory usage.

---

### 17. Compress Database

**Rule**: Enable database compression.

```aide
# aide.conf
gzip_dbout=yes
```

**Impact**: 50-70% size reduction with minimal CPU overhead.

---

### 18. Schedule During Low-Load

**Rule**: Run AIDE checks during maintenance windows (2-5 AM).

```ini
# aide-update.timer
OnCalendar=*-*-* 04:00:00
```

**Why**: AIDE is I/O intensive. Minimize impact on production workloads.

---

## Disaster Recovery

### 19. Document Recovery Procedure

**Rule**: Maintain runbook for AIDE reinstallation.

**Minimum documentation**:
1. How to restore from backup
2. How to reinitialize if backup is lost
3. Contact for AIDE expertise

---

### 20. Test Restore Procedure

**Rule**: Quarterly test that you can restore AIDE database from backup.

**Test steps**:
```bash
# 1. Delete database (test environment!)
sudo rm /var/lib/aide/aide.db

# 2. Restore from backup
sudo cp /mnt/backup/aide.db.latest /var/lib/aide/aide.db

# 3. Verify
sudo aide --check
```

---

## Summary Checklist

**Configuration**:
- [ ] `COPYNEWDB=no` (never auto-update)
- [ ] `FILTERUPDATES=yes` (reduce noise)
- [ ] `QUIETREPORTS=no` (daily confirmation)
- [ ] Drop-in pattern used
- [ ] All excludes documented

**Monitoring**:
- [ ] Prometheus metrics exported
- [ ] Alerts configured (database age, size)
- [ ] Daily email reports working

**Security**:
- [ ] Immutable flags on binary/config
- [ ] Non-root monitoring enabled
- [ ] Offsite backups configured

**Operations**:
- [ ] Timer running (`systemctl list-timers`)
- [ ] Logs reviewed weekly
- [ ] Recovery procedure documented

---

## See Also

- [SETUP.md](SETUP.md) - Initial configuration
- [FALSE_POSITIVE_REDUCTION.md](FALSE_POSITIVE_REDUCTION.md) - Tuning guide
- [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) - Monitoring setup
- [CIS Ubuntu Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
