# AIDE Best Practices

Production-ready guidelines for AIDE configuration and operation.

## Configuration Best Practices

### 1. Use Drop-in Configuration Pattern

**✅ DO**: Modular service-specific excludes
```bash
/etc/aide/aide.conf.d/
├── 10-docker-excludes.conf      # Docker overlay FS
├── 15-monitoring-excludes.conf  # Prometheus/Grafana
├── 20-postgresql-excludes.conf  # PostgreSQL WAL
└── 99-custom-excludes.conf      # Site-specific
```

**❌ DON'T**: Monolithic configuration in single file

**Benefits**:
- Service-specific excludes can be enabled/disabled independently
- Easier to maintain and version control
- Clear naming convention (10-docker, 20-postgresql, etc.)

---

### 2. Minimize False-Positives

**✅ DO**: Exclude legitimate changing directories
```bash
!/var/log
!/var/cache
!/tmp
!/var/lib/docker/overlay2
!/var/lib/postgresql/.*/pg_wal
```

**❌ DON'T**: Exclude entire `/var` or `/opt`

**Goal**: <1% false-positive rate in production

**See**: [FALSE_POSITIVE_REDUCTION.md](FALSE_POSITIVE_REDUCTION.md)

---

### 3. Use Appropriate Hash Algorithms

**✅ DO**: Modern algorithms (sha256, sha512)
```bash
# In aide.conf
NORMAL = sha256+sha512
```

**❌ DON'T**: Deprecated algorithms (md5, sha1)

**Trade-off**: sha256+sha512 balances security and performance
- Database size: ~20-50 MB (medium filesystem)
- Scan time: 1-3 minutes (NVMe SSD)

---

## Security Best Practices

### 4. Protect AIDE Components

**Critical files to protect**:

| File | Protection | Priority |
|------|-----------|----------|
| `/usr/bin/aide` | `chattr +i` | CRITICAL |
| `/etc/aide/aide.conf` | `chattr +i` | HIGH |
| `/var/lib/aide/aide.db` | `chattr +i` | MEDIUM |

**Implementation**:
```bash
sudo chattr +i /usr/bin/aide
sudo chattr +i /etc/aide/aide.conf

# Optional: Database (prevents updates!)
# sudo chattr +i /var/lib/aide/aide.db
```

**Validation**:
```bash
./scripts/validate-immutable-flags.sh
```

---

### 5. Permission Management

**✅ DO**: Use dedicated `_aide` group
```bash
# Directory: 750 root:_aide
drwxr-x--- root _aide /var/lib/aide

# Database: 640 root:_aide
-rw-r----- root _aide /var/lib/aide/aide.db
```

**❌ DON'T**: World-readable (644) or root-only (600)

**Benefits**:
- Non-root monitoring tools can read database
- Write access restricted to root
- Audit logging possible via group membership

**Validation**:
```bash
./scripts/validate-permissions.sh monitoring-user
```

---

### 5. Configure systemd-tmpfiles Override

**Problem**: Default tmpfiles.d config resets permissions at boot

**✅ DO**: Create override in `/etc/tmpfiles.d/`
```bash
# Create override (correct group and permissions)
sudo tee /etc/tmpfiles.d/aide-common.conf > /dev/null << 'EOF'
d /run/aide            0700    _aide    root
d /var/log/aide        2755    _aide    adm
d /var/lib/aide        0750    _aide    _aide
EOF

# Apply immediately
sudo systemd-tmpfiles --create /etc/tmpfiles.d/aide-common.conf
```

**❌ DON'T**: Rely on manual `chmod`/`chown` after each boot

**Why Critical**:
- Default config: `_aide:root 0700` (blocks monitoring access)
- Override ensures: `_aide:_aide 0750` (persistent across reboots)
- Prevents "Permission denied" for monitoring users

**Verification**:
```bash
# Check override exists
ls -l /etc/tmpfiles.d/aide-common.conf

# Verify permissions survive reboot
sudo ls -ld /var/lib/aide/  # drwxr-x--- _aide _aide
```

---

## Operational Best Practices

### 6. Automate Database Updates

**✅ DO**: Use systemd timer for daily updates
```ini
# aide-update.timer
[Timer]
OnCalendar=daily
OnCalendar=03:00
Persistent=true
```

**❌ DON'T**: Manual updates only

**Why**: Database must stay current with system changes

---

### 7. Set Appropriate Timeouts

**✅ DO**: Increase timeout for large filesystems
```ini
# For 2TB+ filesystems
[Service]
TimeoutStartSec=30min
```

**❌ DON'T**: Use default 90s timeout

**Rule of thumb**: 1 minute per 100GB filesystem

---

### 8. Monitor AIDE Execution

**✅ DO**: Export metrics to Prometheus
```bash
# aide.prom
aide_check_exit_code 0
aide_database_size_bytes 22000000
aide_check_duration_seconds 83
```

**❌ DON'T**: Rely on logs only

**Alert on**:
- Check failures (exit code != 0)
- Missing executions (timer not running)
- Long duration (performance degradation)

---

## Performance Best Practices

### 9. Exclude High-Churn Directories

**Common excludes**:
```bash
!/var/log                        # Logs change constantly
!/var/cache                      # Cache can be recreated
!/tmp                            # Temporary files
!/var/lib/docker/overlay2        # Docker layers
!/var/lib/postgresql/.*/pg_wal   # PostgreSQL WAL
!/opt/monitoring/data            # Prometheus time-series
!/home/.*/.cache                 # User caches
```

**Validation**: After adding excludes, check scan time reduction

---

### 10. Use Multi-Threading (If Supported)

**✅ DO** (AIDE 0.18+):
```bash
# In aide.conf
num_workers=4  # Use 4 CPU cores
```

**⚠️ NOTE**: May not improve performance on NVMe SSDs (I/O saturated)

**Test before/after**:
```bash
time sudo aide --check
```

---

## Backup and Recovery Best Practices

### 11. Backup AIDE Database

**✅ DO**: Regular offsite backups
```bash
# Weekly backup
rsync -av /var/lib/aide/aide.db \
    backup-server:/backups/aide/aide.db.$(date +%Y%m%d)
```

**❌ DON'T**: Only local backups

**Why**: Database is reference baseline - must survive host failure

---

### 12. Test Recovery Procedures

**✅ DO**: Quarterly recovery tests
```bash
# 1. Restore database from backup
# 2. Run aide --check
# 3. Verify results match expectations
```

**❌ DON'T**: Assume backups work without testing

---

## Documentation Best Practices

### 13. Document Custom Excludes

**✅ DO**: Comment why each exclude exists
```bash
# Custom excludes - Site-specific
# Added 2025-12-15: Exclude Nextcloud data directory (high churn)
!/opt/nextcloud/data

# Added 2025-12-20: Exclude local backups (scanned separately)
!/opt/backups/local
```

**❌ DON'T**: Uncommented excludes (future you won't remember why)

---

### 14. Maintain Change Log

**✅ DO**: Track configuration changes
```bash
# aide.conf header
# Version: 2.0
# Last Updated: 2025-12-15
# Changelog:
#   2025-12-15: Added PostgreSQL WAL excludes
#   2025-12-10: Enabled sha512 hashing
```

---

## Integration Best Practices

### 15. Integrate with Monitoring Stack

**Recommended integrations**:
- **Prometheus**: Metrics export (check status, duration, database size)
- **Grafana**: Dashboards and visualization
- **Alertmanager**: Alert routing
- **Telegram**: Real-time failure notifications

**Minimal setup**:
```bash
# Prometheus metrics
/var/lib/node_exporter/textfile_collector/aide.prom

# Telegram on failure
OnFailure=aide-failure-alert.service
```

---

### 16. Boot-Time Behavior

**✅ DO**: Use timer, not boot-time service
```ini
[Install]
WantedBy=timers.target  # NOT multi-user.target
```

**❌ DON'T**: Block boot sequence with AIDE check

**Why**: AIDE can take 5-15 minutes - don't delay boot

**See**: [docs/BOOT_RESILIENCY.md](docs/BOOT_RESILIENCY.md)

---

## Testing Best Practices

### 17. Test Before Production

**✅ DO**: Test on staging environment first
```bash
# 1. Deploy configuration
# 2. Run manual check
sudo aide --check

# 3. Trigger false changes
sudo touch /etc/test-file

# 4. Verify detection
sudo aide --check  # Should report new file

# 5. Update database
sudo /usr/local/bin/update-aide-db.sh

# 6. Cleanup
sudo rm /etc/test-file
```

**❌ DON'T**: Deploy directly to production

---

### 18. Validate Configuration Regularly

**✅ DO**: Monthly validation
```bash
# Run validation scripts
./scripts/validate-permissions.sh
./scripts/validate-immutable-flags.sh

# Check timer status
systemctl list-timers aide-update.timer

# Verify last successful run
journalctl -u aide-update.service -n 10
```

---

## Security Hardening Checklist

- [ ] AIDE binary protected with immutable flag
- [ ] Configuration protected with immutable flag
- [ ] Database permissions set to 640 root:_aide
- [ ] Non-root monitoring user in _aide group
- [ ] systemd service runs with PrivateTmp=yes
- [ ] Update script validated (shellcheck)
- [ ] Excludes follow principle of least exclusion
- [ ] Modern hash algorithms (sha256/sha512)
- [ ] Regular database backups configured
- [ ] Recovery procedure tested
- [ ] Validation scripts pass

---

## Performance Optimization Checklist

- [ ] High-churn directories excluded
- [ ] Appropriate timeout configured (30min+)
- [ ] Multi-threading enabled (if supported)
- [ ] Service runs with low priority (Nice=19)
- [ ] Scan time <5 minutes (or acceptable)
- [ ] Database size <50MB (or acceptable)
- [ ] False-positive rate <1%

---

## Summary

**Top 5 Critical Practices**:
1. ✅ Protect AIDE binary with immutable flag
2. ✅ Use modular drop-in configuration
3. ✅ Automate updates with systemd timer
4. ✅ Monitor execution with Prometheus
5. ✅ Regular validation with scripts

**Avoid These Mistakes**:
1. ❌ No immutable flag protection
2. ❌ World-readable database (644)
3. ❌ Blocking boot with AIDE service
4. ❌ No monitoring/alerting
5. ❌ Manual updates only
