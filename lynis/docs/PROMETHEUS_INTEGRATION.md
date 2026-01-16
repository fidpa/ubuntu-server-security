# Lynis Prometheus Integration

Export Lynis audit metrics to Prometheus for monitoring security posture over time.

## Overview

**Exported Metrics** (4):
- `lynis_hardening_index` - Security score (0-100)
- `lynis_tests_done` - Total tests performed
- `lynis_warnings` - Critical issues count
- `lynis_suggestions` - Recommendations count

**Update Frequency**: Weekly (default) or on-demand

---

## Prerequisites

**Required**:
- Prometheus installed
- node_exporter with textfile collector enabled

**Verify node_exporter**:
```bash
systemctl status node_exporter

# Check textfile collector directory
ls -la /var/lib/node_exporter/textfile_collector/
```

**If missing**: Install node_exporter with `--collector.textfile.directory=/var/lib/node_exporter/textfile_collector`.

---

## Setup

### Step 1: Deploy Metrics Exporter

```bash
# Make script executable
chmod +x ../scripts/lynis-metrics-exporter.sh

# Copy to system path (optional)
sudo cp ../scripts/lynis-metrics-exporter.sh /usr/local/bin/

# Or run from component directory
sudo ../scripts/lynis-metrics-exporter.sh --run-audit
```

### Step 2: Create systemd Service

```bash
sudo tee /etc/systemd/system/lynis-metrics-exporter.service > /dev/null << 'EOF'
[Unit]
Description=Lynis Prometheus Metrics Exporter
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/lynis-metrics-exporter.sh --run-audit
StandardOutput=journal
StandardError=journal
EOF
```

### Step 3: Create systemd Timer (Weekly)

```bash
sudo tee /etc/systemd/system/lynis-metrics-exporter.timer > /dev/null << 'EOF'
[Unit]
Description=Weekly Lynis Metrics Export

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF
```

### Step 4: Enable and Start

```bash
sudo systemctl daemon-reload
sudo systemctl enable lynis-metrics-exporter.timer
sudo systemctl start lynis-metrics-exporter.timer

# Verify timer
sudo systemctl status lynis-metrics-exporter.timer
```

---

## Metrics Format

**File**: `/var/lib/node_exporter/textfile_collector/lynis.prom`

**Example**:
```prometheus
# HELP lynis_hardening_index Lynis Hardening Index (0-100)
# TYPE lynis_hardening_index gauge
lynis_hardening_index 80

# HELP lynis_tests_done Total number of tests performed
# TYPE lynis_tests_done counter
lynis_tests_done 275

# HELP lynis_warnings Number of warnings found
# TYPE lynis_warnings gauge
lynis_warnings 1

# HELP lynis_suggestions Number of suggestions made
# TYPE lynis_suggestions gauge
lynis_suggestions 38
```

---

## Prometheus Configuration

### Add Scrape Target

**Edit**: `/etc/prometheus/prometheus.yml`

```yaml
scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']  # node_exporter with textfile collector
```

**Reload Prometheus**:
```bash
sudo systemctl reload prometheus
```

### Verify Metrics

**Prometheus Web UI**: http://localhost:9090

**Query**:
```promql
lynis_hardening_index
```

**Expected**: Graph showing hardening index over time.

---

## Grafana Dashboard

### Panel 1: Hardening Index (Gauge)

**Query**:
```promql
lynis_hardening_index
```

**Visualization**: Gauge
**Min**: 0
**Max**: 100
**Thresholds**:
- Red: 0-59
- Yellow: 60-79
- Green: 80-100

### Panel 2: Warnings/Suggestions (Time Series)

**Query**:
```promql
lynis_warnings
lynis_suggestions
```

**Visualization**: Graph
**Legend**: {{__name__}}

### Panel 3: Tests Performed (Stat)

**Query**:
```promql
lynis_tests_done
```

**Visualization**: Stat

### Panel 4: Hardening Trend (Time Series)

**Query**:
```promql
lynis_hardening_index
```

**Visualization**: Graph
**Time Range**: Last 90 days

### Example JSON Panel (Hardening Index Gauge)

```json
{
  "type": "gauge",
  "title": "Lynis Hardening Index",
  "targets": [
    {
      "expr": "lynis_hardening_index",
      "refId": "A"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "min": 0,
      "max": 100,
      "thresholds": {
        "steps": [
          { "color": "red", "value": 0 },
          { "color": "yellow", "value": 60 },
          { "color": "green", "value": 80 }
        ]
      }
    }
  }
}
```

---

## Alerting Rules

### Alert on Low Hardening Index

**File**: `/etc/prometheus/rules/lynis_alerts.yml`

```yaml
groups:
  - name: lynis_alerts
    interval: 1h
    rules:
      - alert: LynisHardeningIndexLow
        expr: lynis_hardening_index < 60
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Lynis Hardening Index below 60"
          description: "Current index: {{ $value }}. Review hardening guide."

      - alert: LynisWarningsIncreased
        expr: delta(lynis_warnings[7d]) > 5
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Lynis warnings increased by 5+ in 7 days"
          description: "New warnings detected. Review report."
```

**Reload Prometheus**:
```bash
sudo systemctl reload prometheus
```

---

## Manual Metrics Export

### Export Without Audit (Use Cached Report)

```bash
sudo ../scripts/lynis-metrics-exporter.sh
```

### Export With Fresh Audit

```bash
sudo ../scripts/lynis-metrics-exporter.sh --run-audit
```

### Verify Export

```bash
cat /var/lib/node_exporter/textfile_collector/lynis.prom
```

---

## Automation Options

### Option 1: Weekly Timer (Recommended)

Weekly audits balance freshness with performance overhead.

```bash
sudo systemctl enable lynis-metrics-exporter.timer
```

### Option 2: Daily Timer (High-Security Environments)

```bash
# Edit timer
sudo systemctl edit lynis-metrics-exporter.timer

# Change:
[Timer]
OnCalendar=daily
```

### Option 3: On-Demand (CI/CD Integration)

```bash
# Run after hardening changes
sudo /usr/local/bin/lynis-metrics-exporter.sh --run-audit
```

---

## Troubleshooting

### Metrics Not Updating

**Check**:
```bash
# Timer status
sudo systemctl status lynis-metrics-exporter.timer

# Service logs
sudo journalctl -u lynis-metrics-exporter.service -n 50

# Metrics file permissions
ls -la /var/lib/node_exporter/textfile_collector/lynis.prom
```

### Prometheus Not Scraping

**Check**:
```bash
# node_exporter running?
systemctl status node_exporter

# Textfile collector enabled?
ps aux | grep node_exporter | grep textfile
```

### Old Metrics Cached

**Fix**:
```bash
# Force fresh audit
sudo lynis audit system --quick
sudo ../scripts/lynis-metrics-exporter.sh

# Restart node_exporter (re-reads files)
sudo systemctl restart node_exporter
```

---

## See Also

- [SETUP.md](SETUP.md) - Installation & first audit
- [HARDENING_GUIDE.md](HARDENING_GUIDE.md) - Improve hardening index
- [CUSTOM_PROFILES.md](CUSTOM_PROFILES.md) - Reduce false-positives
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
