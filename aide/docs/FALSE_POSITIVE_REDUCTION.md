# AIDE False-Positive Reduction

Strategies and patterns for reducing false-positive alerts in AIDE file integrity monitoring.

## The Problem

AIDE monitors **all** file changes by default, including legitimate system operations:
- Log rotation
- Package installations
- Database operations (PostgreSQL WAL, MySQL binary logs)
- Docker container layers
- Cache updates

**Result**: 100+ daily alerts from legitimate changes → Alert fatigue → Ignored real incidents

**Goal**: Reduce false-positives to <1% while maintaining security coverage

---

## Common False-Positive Sources

### 1. Log Files

**Problem**: Log rotation, syslog writes, application logs change constantly

**Exclude Pattern**:
```bash
# Exclude all logs
!/var/log

# More granular (exclude specific logs only)
!/var/log/syslog.*
!/var/log/auth.log.*
!/var/log/kern.log.*
```

**Impact**: Reduces alerts by ~40%

---

### 2. Cache Directories

**Problem**: APT cache, browser caches, application caches

**Exclude Pattern**:
```bash
# System caches
!/var/cache

# User caches
!/home/.*/.cache

# Application-specific
!/opt/monitoring/cache
!/usr/share/man/man.*/.*
```

**Impact**: Reduces alerts by ~15%

---

### 3. Docker Overlay Filesystems

**Problem**: Docker creates/destroys overlay2 directories on every container start/stop

**Exclude Pattern**:
```bash
# Docker storage
!/var/lib/docker/overlay2
!/var/lib/docker/image
!/var/lib/docker/containers

# Docker volumes (exclude if ephemeral)
!/var/lib/docker/volumes/.*/._data
```

**Impact**: Reduces alerts by ~25% (on systems running Docker)

---

### 4. PostgreSQL WAL Files

**Problem**: Write-Ahead Log files rotate frequently during normal operation

**Exclude Pattern**:
```bash
# PostgreSQL 12+
!/var/lib/postgresql/.*/main/pg_wal
!/var/lib/postgresql/.*/main/pg_xlog  # Pre-10

# Stats temp files
!/var/lib/postgresql/.*/main/pg_stat_tmp
```

**Impact**: Reduces alerts by ~10% (on database servers)

---

### 5. Systemd Runtime Files

**Problem**: systemd creates/removes runtime files in `/run`

**Exclude Pattern**:
```bash
# systemd runtime
!/run
!/var/run

# Keep monitoring critical areas
=/etc/systemd/system  # DO monitor systemd configs
```

**Impact**: Reduces alerts by ~5%

---

### 6. Monitoring Data (Prometheus, Grafana)

**Problem**: Prometheus TSDB, Grafana sessions, metrics

**Exclude Pattern**:
```bash
# Prometheus
!/opt/monitoring/prometheus/data
!/var/lib/prometheus

# Grafana
!/var/lib/grafana/sessions
!/var/lib/grafana/png
```

**Impact**: Reduces alerts by ~8% (on monitoring servers)

---

## Granular Exclude Strategies

### Strategy 1: Monitor Content, Ignore Metadata

**Use Case**: Monitor `/etc` for content changes, but ignore timestamp updates

```bash
# Monitor /etc but only content changes
/etc R+sha256

# Ignore permission/timestamp changes
!/etc/resolv.conf  # Changes from DHCP
!/etc/mtab         # Mount table updates
```

---

### Strategy 2: Monitor Directory Structure, Not Contents

**Use Case**: Alert on new files in `/usr/bin`, but don't track every binary update

```bash
# Monitor for new binaries, ignore updates
/usr/bin n+sha256  # n = number of entries only
```

---

### Strategy 3: Exclude by Extension

**Use Case**: Ignore temporary files, lock files

```bash
# Exclude temp files
!/.*\.tmp$
!/.*\.lock$
!/.*\.pid$
!/.*~$
```

---

## Drop-in Configuration Pattern

### Recommended Structure

```
/etc/aide/aide.conf.d/
├── 10-docker-excludes.conf          # Docker-specific
├── 15-monitoring-excludes.conf      # Prometheus/Grafana
├── 16-backups-excludes.conf         # Backup directories
├── 20-postgresql-excludes.conf      # PostgreSQL WAL
├── 30-nextcloud-excludes.conf       # Nextcloud data
├── 40-systemd-excludes.conf         # systemd runtime
├── 50-network-shares-excludes.conf  # NFS/SAMBA mounts
└── 99-custom-excludes.conf          # Site-specific
```

### Example: Docker Excludes (10-docker-excludes.conf)

```bash
# ============================================================================
# Docker Excludes - High-churn overlay filesystems
# ============================================================================
# Reason: Docker overlay2 changes on every container start/stop
# Impact: Reduces false-positives by ~25%
# Last Updated: 2025-12-15

# Overlay filesystems (ephemeral)
!/var/lib/docker/overlay2

# Container metadata
!/var/lib/docker/containers

# Image layers
!/var/lib/docker/image

# Network state
!/var/lib/docker/network

# Volumes (OPTIONAL - comment out to monitor volumes)
!/var/lib/docker/volumes/.*/._data

# ============================================================================
# MONITOR: Docker configuration (keep these!)
# ============================================================================
=/etc/docker/daemon.json
=/usr/lib/systemd/system/docker.service
```

---

## False-Positive Analysis Workflow

### 1. Collect Alerts (1 week baseline)

```bash
# Run AIDE check daily for 1 week
# Log all changes to file
sudo aide --check | tee -a aide-baseline.log
```

### 2. Analyze Top Offenders

```bash
# Count changes by directory
grep "^changed:" aide-baseline.log | \
    cut -d: -f2 | \
    xargs -n1 dirname | \
    sort | uniq -c | sort -rn | head -20
```

**Example output**:
```
 145 /var/log
  87 /var/lib/docker/overlay2
  56 /var/cache
  34 /var/lib/postgresql/14/main/pg_wal
```

### 3. Evaluate Each Directory

For each top offender, ask:
- **Is this directory security-relevant?** (e.g., `/etc` = YES, `/var/log` = NO)
- **Can I exclude safely?** (e.g., logs = YES, `/usr/bin` = NO)
- **Is there a more granular exclude?** (e.g., exclude WAL, monitor config)

### 4. Implement Excludes

Create drop-in config with reasoning:

```bash
# 99-custom-excludes.conf
# Analysis date: 2025-12-15
# Baseline period: 2025-12-08 to 2025-12-15

# Top offender: /var/log (145 changes/week)
!/var/log

# Top offender: /var/lib/docker (87 changes/week)
!/var/lib/docker/overlay2
```

### 5. Re-baseline and Measure

```bash
# After excludes, measure improvement
sudo aide --check | tee aide-post-excludes.log

# Count remaining alerts
grep "^changed:" aide-post-excludes.log | wc -l
```

**Goal**: <10 alerts per week

---

## Production Metrics

### Target False-Positive Rate

| Metric | Target | Acceptable | Poor |
|--------|--------|------------|------|
| Daily alerts | <2 | 2-10 | >10 |
| Weekly alerts | <10 | 10-50 | >50 |
| FP rate | <1% | 1-5% | >5% |

### Measured Results (Example)

**Before optimization**:
- Daily alerts: 150+ (mostly logs, Docker, PostgreSQL)
- FP rate: ~95%
- Alert fatigue: High

**After optimization** (with drop-ins):
- Daily alerts: 3-5 (legitimate changes only)
- FP rate: <1%
- Alert actionability: High

**Optimization steps**:
1. Excluded `/var/log` → -40% alerts
2. Excluded Docker overlay2 → -25% alerts
3. Excluded PostgreSQL WAL → -10% alerts
4. Excluded caches → -15% alerts
5. Granular `/etc` monitoring → -5% alerts

**Result**: 99.7% false-positive reduction

---

## Best Practices

### ✅ DO

1. **Start conservative**: Monitor everything, then exclude based on data
2. **Document reasoning**: Every exclude should have a comment
3. **Review quarterly**: Excludes may become outdated
4. **Test after changes**: Run `aide --check` after adding excludes
5. **Keep security-relevant**: Never exclude `/etc`, `/usr/bin`, `/boot`

### ❌ DON'T

1. **Exclude entire `/var`**: Too broad, misses important changes
2. **Exclude without analysis**: Understand impact first
3. **Copy blindly**: Server A's excludes may not fit Server B
4. **Ignore patterns**: If seeing repeating changes, investigate
5. **Over-exclude**: Balance false-positives vs. security coverage

---

## Security Considerations

### Critical Directories (NEVER Exclude)

```bash
# ALWAYS monitor these
=/etc                 # System configuration
=/boot                # Kernel, initramfs
=/usr/bin             # System binaries
=/usr/sbin            # Admin binaries
=/lib/systemd/system  # systemd units
=/root                # Root home directory
```

### High-Risk Excludes (Use with Caution)

```bash
# RISKY: Exclude Docker volumes
!/var/lib/docker/volumes

# Why risky: May contain persistent application data
# Alternative: Monitor specific volume paths
=/var/lib/docker/volumes/critical-app-data/_data
```

### Validation After Excludes

```bash
# Ensure critical paths are still monitored
aide --check-config | grep "Checking rule"

# Verify /etc is not excluded
aide --dry-run /etc/passwd  # Should be monitored
```

---

## Maintenance

### Quarterly Review

```bash
# 1. Check if excludes are still relevant
grep "^!" /etc/aide/aide.conf.d/*.conf

# 2. Analyze current alert patterns
sudo aide --check | grep "^changed:"

# 3. Update drop-in configs
sudo nano /etc/aide/aide.conf.d/99-custom-excludes.conf

# 4. Rebuild database
sudo /usr/local/bin/update-aide-db.sh
```

### Metrics Tracking

Track false-positive rate over time:

```bash
# Log all checks
sudo aide --check | tee -a /var/log/aide-checks.log

# Monthly analysis
# - Count total alerts
# - Classify as TP (true positive) or FP (false positive)
# - Calculate FP rate: FP / (TP + FP)
```

---

## See Also

- **[SETUP.md](SETUP.md)** - Drop-in configuration setup
- **[BEST_PRACTICES.md](BEST_PRACTICES.md)** - Operational guidelines
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues
