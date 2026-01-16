# False-Positive Reduction for AIDE

The hard-learned lessons from weeks of debugging AIDE on production servers with 100% CIS Benchmark compliance.

## The Problem

**Default AIDE configuration generates hundreds to thousands of false-positives per day.**

Real-world example from my production NAS:
- **Before optimization**: 3,799 changes per day (99.7% noise)
- **After optimization**: 12 changes per day (96% signal)
- **Improvement**: Factor 316 reduction (99.7% false-positive reduction)

**Why this matters**: False-positive fatigue leads to ignoring AIDE reports entirely, defeating the purpose of intrusion detection.

## Top 12 False-Positive Sources

### 1. /var/log Changes

**Symptom**: Logs grow and rotate constantly.

**Root Cause**: Using `Full` integrity check on logs means every write triggers an alert.

**Solution**: Use `ActLog` group for active logs:
```aide
# Don't do this (monitors content changes)
/var/log Full

# Do this instead (allows growing, monitors inode/permissions)
/var/log ActLog
```

**AIDE Groups Explained**:
- `Full` = Monitor everything (hash, size, mtime, owner, permissions)
- `ActLog` = Allow file to grow, monitor metadata only

---

### 2. Docker Volumes

**Symptom**: Every container start/stop generates alerts.

**Root Cause**: Docker overlay2 filesystems change continuously.

**Solution**: Exclude Docker runtime state, monitor structure only:
```aide
# Exclude container filesystems (change constantly)
!/var/lib/docker/overlay2
!/var/lib/docker/containers/.*/.*\.log$

# Monitor volume structure (not content)
/var/lib/docker/volumes VarDir
```

**Rationale**: You care if someone adds a new volume (potential data exfiltration), not if file content changes (normal Docker operation).

---

### 3. PostgreSQL WAL (Write-Ahead Log)

**Symptom**: Alerts every few seconds during normal DB operations.

**Root Cause**: PostgreSQL writes to WAL continuously for transaction durability.

**Solution**: Exclude WAL directories:
```aide
!/var/lib/postgresql/.*/main/pg_wal
!/var/lib/postgresql/.*/main/pg_stat_tmp
```

**What you still detect**: Changes to PostgreSQL binaries (`/usr/lib/postgresql`), config (`/etc/postgresql`), and data directory structure.

---

### 4. APT Package Cache

**Symptom**: `apt update` generates hundreds of alerts.

**Root Cause**: APT downloads package metadata to `/var/lib/apt/lists` and `/var/cache/apt`.

**Solution**: Use `FILTERUPDATES=yes` in `/etc/default/aide`:
```bash
# Filter package manager updates from reports
FILTERUPDATES=yes
```

**How it works**: AIDE cross-references changes with `/var/lib/dpkg/info` to identify legitimate package updates.

**What you still detect**: Manually edited files in `/etc`, new binaries in `/usr/bin` that aren't from packages.

---

### 5. systemd Journal

**Symptom**: Alerts every minute.

**Root Cause**: systemd journal files grow continuously.

**Solution**: Exclude journal directories:
```aide
!/var/log/journal
!/run/log/journal
```

**Alternative**: Use `ActLog` if you want to monitor journal structure.

---

### 6. Temporary Directories

**Symptom**: `/tmp` and `/var/tmp` generate constant alerts.

**Root Cause**: Applications create/delete temp files continuously.

**Solution**: Exclude temp directories entirely:
```aide
!/tmp
!/var/tmp
!/run
```

**Rationale**: Temp files are transient by definition. Focus AIDE on persistent files.

---

### 7. User Home Directories

**Symptom**: Every user action (download, config change) generates an alert.

**Root Cause**: User files change legitimately.

**Solution**: Exclude user home directories, monitor system areas only:
```aide
!/home
!/root/.cache
!/root/.local
```

**Exception**: If you want to monitor specific users (e.g., service accounts that shouldn't change), use:
```aide
/home/serviceaccount Full
```

---

### 8. Package Manager Database

**Symptom**: `/var/lib/dpkg` changes during package operations.

**Root Cause**: APT updates package database.

**Solution**: Already handled by `FILTERUPDATES=yes`, but you can also exclude:
```aide
!/var/lib/dpkg/info
!/var/lib/apt/lists
```

---

### 9. Container Runtime State

**Symptom**: containerd/runc state changes constantly.

**Root Cause**: Container lifecycle management.

**Solution**: Exclude runtime state:
```aide
!/var/lib/containerd/io.containerd.runtime.v2.task
!/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs
```

---

### 10. Application Caches

**Symptom**: Nextcloud, WordPress, etc. cache changes.

**Root Cause**: Applications cache data for performance.

**Solution**: Exclude cache directories, monitor app structure:
```aide
!/var/www/nextcloud/apps/.*/cache
/var/www/nextcloud/config Full  # Still monitor config
```

**Pattern**: Cache = exclude, Config = monitor.

---

## AIDE Group Patterns (Decision Matrix)

| Use Case | AIDE Group | Monitors | Ignores |
|----------|-----------|----------|---------|
| **Immutable files** (binaries, libs) | `Full` | Hash, size, mtime, owner, perms, ACL | Nothing |
| **Config files** (may be edited) | `Full` or `VarTime` | Everything, or ignore mtime only | - |
| **Logs** (active, growing) | `ActLog` | Owner, perms, growing allowed | Hash, size changes |
| **Logs** (rotated) | `RotLog` | Owner, perms, size can change | Hash |
| **Data directories** (structure matters) | `VarDir` | Owner, perms, inode, structure | Content |
| **Metadata only** | `VarFile` | Owner, perms, links | Hash, size, mtime |

**Decision Tree**:
1. Should file NEVER change? → Use `Full`
2. Is it a log file? → Use `ActLog` or `RotLog`
3. Is it a directory with changing content? → Use `VarDir`
4. Do you only care about metadata? → Use `VarFile`
5. Should it be ignored entirely? → Use `!` prefix

---


### 11. Monitoring Stack (Prometheus/Grafana)

**Symptom**: AIDE scan takes hours or times out. Database scan CPU time exceeds wall time by 10x.

**Root Cause**: Prometheus Write-Ahead Log (WAL) changes every 2 hours. AIDE attempts to hash multi-GB time-series databases that are actively being written.

**Real-World Impact**:
- Prometheus WAL: 2-5GB, rewrites every 2h
- AIDE scan time: Can increase from 2 minutes to 4+ hours
- Memory usage: Peaks at 7-12GB (vs normal 200MB)

**Solution**: Exclude all monitoring stack operational data:
```aide
# Prometheus time-series database (WAL changes every 2h)
!/var/lib/prometheus/wal
!/opt/monitoring/prometheus/wal

# Prometheus chunks (active time-series data)
!/var/lib/prometheus/chunks_head

# Grafana dashboard database (changes on every view/edit)
!/var/lib/grafana/grafana.db
!/opt/monitoring/grafana/grafana.db

# Node Exporter metrics (updated every 15s-5min)
!/var/lib/node_exporter/textfile_collector/.*\.prom$
```

**Still Monitor**: Configuration files
```aide
/etc/prometheus Full
/etc/grafana Full
```

**When to use**: If you run Prometheus, Grafana, Uptime Kuma, or similar monitoring tools.

**See**: `drop-ins/15-monitoring-excludes.conf` for complete patterns.

---

### 12. Backup Storage

**Symptom**: AIDE scans backup snapshots (50-100GB+) causing extreme slowdowns. Database grows to 50+ MB.

**Root Cause**: Backup directories contain full snapshots of your entire system, which AIDE attempts to hash on every scan.

**Real-World Impact**:
- Nextcloud snapshots: 46GB
- Database dumps: 10-20GB
- AIDE scan time: +30 minutes per 50GB of backups

**Solution**: Exclude backup storage, monitor backup scripts:
```aide
# Backup snapshots (can be 50+ GB)
!/opt/backups
!/var/backups/application-backups

# BorgBackup/Restic repositories
!/opt/borg-backup
!/var/lib/restic

# Database dumps (change daily)
!/opt/backups/postgresql
!/opt/backups/mysql
```

**Still Monitor**: Backup scripts and configuration
```aide
# Monitor backup automation (scripts, timers)
/opt/scripts/backup Full
/etc/systemd/system/*backup* Full
```

**Rationale**:
- Backup data changes daily (that is the point!)
- Backup scripts should be immutable (monitor these!)
- Scanning backup data wastes resources without security benefit

**When to use**: If you store backups on the same server being monitored.

**See**: `drop-ins/16-backups-excludes.conf` for complete patterns.

---

