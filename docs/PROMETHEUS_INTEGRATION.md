# Prometheus Integration for AIDE

Monitor AIDE database health and check status with Prometheus and Grafana.

## Metrics Overview

The `aide-metrics-exporter.sh` script exports four metrics:

| Metric | Type | Description | Use Case |
|--------|------|-------------|----------|
| `aide_db_size_bytes` | gauge | Database size in bytes | Track DB growth over time |
| `aide_db_age_seconds` | gauge | Seconds since last DB update | Alert if DB becomes stale |
| `aide_last_update_timestamp` | gauge | UNIX timestamp of last update | Correlate with system events |
| `aide_last_check_status` | gauge | 0=OK, 1=WARNING, 2=CRITICAL | Monitor AIDE health status |

## Setup

### Step 1: Install node_exporter

```bash
# Install node_exporter
sudo apt install prometheus-node-exporter

# Or download latest release
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-1.7.0.linux-amd64.tar.gz
sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
```

### Step 2: Configure Textfile Collector

```bash
# Create metrics directory
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chmod 755 /var/lib/node_exporter/textfile_collector

# Configure node_exporter to use textfile collector
sudo systemctl edit node_exporter.service
```

Add:
```ini
[Service]
ExecStart=
ExecStart=/usr/bin/node_exporter --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
```

Restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart node_exporter
```

### Step 3: Export Metrics

Metrics are automatically exported by the systemd service (`ExecStartPost` hook):

```bash
# Manual export (for testing)
sudo /usr/local/bin/aide-metrics-exporter.sh

# Verify metrics file
cat /var/lib/node_exporter/textfile_collector/aide.prom
```

Expected output:
```prometheus
# HELP aide_db_size_bytes AIDE database size in bytes
# TYPE aide_db_size_bytes gauge
aide_db_size_bytes 38654208

# HELP aide_db_age_seconds Age of AIDE database in seconds
# TYPE aide_db_age_seconds gauge
aide_db_age_seconds 3600

# HELP aide_last_update_timestamp UNIX timestamp of last AIDE database update
# TYPE aide_last_update_timestamp gauge
aide_last_update_timestamp 1704297600

# HELP aide_last_check_status Last AIDE check status (0=OK, 1=WARNING, 2=CRITICAL)
# TYPE aide_last_check_status gauge
aide_last_check_status 0
```

### Step 4: Configure Prometheus

Add to `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']  # node_exporter default port
```

Reload Prometheus:
```bash
sudo systemctl reload prometheus
```

Verify metrics in Prometheus UI:
- Go to `http://your-prometheus:9090/graph`
- Query: `aide_db_age_seconds`

## Alert Rules

### Basic Alerts

Create `/etc/prometheus/rules/aide.yml`:

```yaml
groups:
  - name: aide
    interval: 60s
    rules:
      # Database is stale (>25 hours old)
      - alert: AIDEDatabaseStale
        expr: aide_db_age_seconds > 90000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "AIDE database is stale on {{ $labels.instance }}"
          description: "AIDE database is {{ $value | humanizeDuration }} old. Check aide-update.timer."

      # Database is missing
      - alert: AIDEDatabaseMissing
        expr: aide_db_age_seconds == -1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "AIDE database is missing on {{ $labels.instance }}"
          description: "AIDE database not found. Run: sudo aideinit"

      # AIDE check status is critical
      - alert: AIDECheckCritical
        expr: aide_last_check_status == 2
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "AIDE check failed on {{ $labels.instance }}"
          description: "AIDE check returned critical status. Check /var/log/aide/aide.log"

      # Database size growing unexpectedly
      - alert: AIDEDatabaseGrowth
        expr: rate(aide_db_size_bytes[7d]) > 1048576  # >1MB per day
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "AIDE database growing rapidly on {{ $labels.instance }}"
          description: "Database growing at {{ $value | humanize }}B/day. Review monitored paths."
```

Add to `prometheus.yml`:
```yaml
rule_files:
  - /etc/prometheus/rules/aide.yml
```

Reload:
```bash
sudo systemctl reload prometheus
```

### Advanced Alerts

```yaml
# Database hasn't been updated during maintenance window
- alert: AIDENoUpdateAfterMaintenance
  expr: aide_db_age_seconds > 172800 and day_of_week() == 1  # >2 days on Monday
  labels:
    severity: warning
  annotations:
    summary: "AIDE database not updated after weekend maintenance"
    description: "Run manual update: sudo /usr/local/bin/update-aide-db.sh"

# Database size decreased (possible corruption or deletion)
- alert: AIDEDatabaseShrunk
  expr: delta(aide_db_size_bytes[1d]) < -1048576  # Decreased >1MB
  labels:
    severity: critical
  annotations:
    summary: "AIDE database size decreased unexpectedly"
    description: "Database shrunk by {{ $value | humanize }}B. Check for corruption."
```

## Grafana Dashboards

### Quick Start: Simple Panel

1. Create new dashboard in Grafana
2. Add panel → Prometheus query:

**Query 1: Database Age**
```promql
aide_db_age_seconds / 3600
```
Unit: Hours
Thresholds: >24 (yellow), >48 (red)

**Query 2: Database Size**
```promql
aide_db_size_bytes
```
Unit: Bytes (IEC)

**Query 3: Check Status**
```promql
aide_last_check_status
```
Value mappings: 0=OK, 1=WARNING, 2=CRITICAL

**Query 4: Last Update**
```promql
aide_last_update_timestamp * 1000
```
Unit: From Now

### Example PromQL Queries

**Database age in hours**:
```promql
aide_db_age_seconds / 3600
```

**Database size growth over 7 days**:
```promql
delta(aide_db_size_bytes[7d])
```

**Time since last update (human-readable)**:
```promql
time() - aide_last_update_timestamp
```

**Alert threshold check** (returns 1 if stale):
```promql
aide_db_age_seconds > 90000
```

## Monitoring Best Practices

### 1. Set Realistic Thresholds

Don't alert on every small delay:
- **Warning**: DB >25 hours old (daily timer + buffer)
- **Critical**: DB >48 hours old (timer completely broken)

### 2. Correlate with System Events

Use `aide_last_update_timestamp` to correlate with:
- Server reboots (check if AIDE ran after reboot)
- Package updates (DB should update after major upgrades)
- Maintenance windows (expect updates)

### 3. Track DB Growth

Unexpected database growth can indicate:
- New files added to monitored paths
- Misconfigured excludes (monitoring too much)
- Potential intrusion (many new files)

**Normal growth**: <1 MB/day on stable server
**Investigate**: >10 MB/day

### 4. Monitor Check Status

`aide_last_check_status`:
- `0` (OK): No changes detected
- `1` (WARNING): Changes detected, review required
- `2` (CRITICAL): AIDE check failed (database missing, etc.)

**Don't alert on WARNING** - changes are often legitimate (package updates). Alert on CRITICAL only.

## Troubleshooting

### Metrics Not Appearing

```bash
# Check if metrics file exists
ls -la /var/lib/node_exporter/textfile_collector/aide.prom

# Check file contents
cat /var/lib/node_exporter/textfile_collector/aide.prom

# Check node_exporter can read it
sudo -u prometheus cat /var/lib/node_exporter/textfile_collector/aide.prom

# Check node_exporter logs
sudo journalctl -u node_exporter -n 50
```

### Metrics Show -1

This means AIDE database is missing:
```bash
# Check if database exists
ls -la /var/lib/aide/aide.db

# Initialize if missing
sudo aideinit
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Re-export metrics
sudo /usr/local/bin/aide-metrics-exporter.sh
```

### Metrics Not Updating

Check systemd service runs metrics exporter:
```bash
# Verify ExecStartPost is configured
sudo systemctl cat aide-update.service | grep ExecStartPost

# Run manual update to test
sudo systemctl start aide-update.service

# Check metrics file timestamp
stat /var/lib/node_exporter/textfile_collector/aide.prom
```

## See Also

- [SETUP.md](SETUP.md) - Initial AIDE setup
- [FALSE_POSITIVE_REDUCTION.md](FALSE_POSITIVE_REDUCTION.md) - Reduce noise
- [Prometheus Textfile Collector](https://github.com/prometheus/node_exporter#textfile-collector)
