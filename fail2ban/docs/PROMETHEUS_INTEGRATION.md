# Prometheus Integration for fail2ban

Metrics export and monitoring for fail2ban.

## Overview

The fail2ban metrics exporter exports ban statistics in Prometheus format, enabling monitoring and alerting via Prometheus + Grafana.

**Metrics exported**:
- `fail2ban_jails_total` - Number of configured jails
- `fail2ban_bans_total` - Currently banned IPs per jail
- `fail2ban_ban_events_total` - Cumulative ban events per jail

## Prerequisites

- Prometheus installed
- node_exporter with textfile collector enabled
- fail2ban running

**node_exporter configuration**:
```bash
# Start node_exporter with textfile collector
node_exporter \
  --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
```

## Installation

### 1. Deploy Metrics Exporter Script

```bash
# Copy script to system location
sudo cp scripts/fail2ban-metrics-exporter.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/fail2ban-metrics-exporter.sh

# Create metrics directory
sudo mkdir -p /var/lib/node_exporter/textfile_collector
```

### 2. Test Manual Export

```bash
# Run exporter manually
sudo /usr/local/bin/fail2ban-metrics-exporter.sh

# Check metrics file
cat /var/lib/node_exporter/textfile_collector/fail2ban.prom
```

**Expected output**:
```prometheus
# HELP fail2ban_jails_total Number of configured fail2ban jails
# TYPE fail2ban_jails_total gauge
# HELP fail2ban_bans_total Currently banned IPs per jail
# TYPE fail2ban_bans_total gauge
# HELP fail2ban_ban_events_total Cumulative ban events per jail
# TYPE fail2ban_ban_events_total counter
fail2ban_jails_total{hostname="your-hostname"} 3
fail2ban_bans_total{hostname="your-hostname",jail="sshd"} 2
fail2ban_ban_events_total{hostname="your-hostname",jail="sshd"} 15
fail2ban_bans_total{hostname="your-hostname",jail="nginx-http-auth"} 0
fail2ban_ban_events_total{hostname="your-hostname",jail="nginx-http-auth"} 3
```

### 3. Setup Periodic Export (systemd timer)

Create systemd service:

```bash
sudo nano /etc/systemd/system/fail2ban-metrics.service
```

```ini
[Unit]
Description=fail2ban Prometheus Metrics Exporter
After=fail2ban.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fail2ban-metrics-exporter.sh
User=root
```

Create systemd timer:

```bash
sudo nano /etc/systemd/system/fail2ban-metrics.timer
```

```ini
[Unit]
Description=fail2ban Metrics Export Timer
Requires=fail2ban-metrics.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
```

**Enable and start timer**:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now fail2ban-metrics.timer

# Verify timer is active
systemctl status fail2ban-metrics.timer
systemctl list-timers fail2ban-metrics.timer
```

## Prometheus Configuration

### 1. Configure node_exporter Scrape

Edit Prometheus configuration (`/etc/prometheus/prometheus.yml`):

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets:
          - 'your-server:9100'
    metric_relabel_configs:
      # Ensure fail2ban metrics are scraped
      - source_labels: [__name__]
        regex: 'fail2ban_.*'
        action: keep
```

### 2. Reload Prometheus

```bash
sudo systemctl reload prometheus

# Or send SIGHUP
sudo killall -HUP prometheus
```

### 3. Verify Metrics in Prometheus

Open Prometheus UI (`http://your-prometheus:9090`) and query:

```promql
# Check if metrics are available
fail2ban_jails_total

# View all jail metrics
{__name__=~"fail2ban_.*"}

# Currently banned IPs per jail
fail2ban_bans_total
```

## Grafana Dashboard

### Example Dashboard Queries

#### Panel 1: Total Active Jails

```promql
# Gauge - Number of configured jails
fail2ban_jails_total
```

#### Panel 2: Currently Banned IPs

```promql
# Graph - Banned IPs over time per jail
fail2ban_bans_total
```

#### Panel 3: Ban Rate (Last Hour)

```promql
# Graph - New bans per hour
rate(fail2ban_ban_events_total[1h]) * 3600
```

#### Panel 4: Total Ban Events (All Time)

```promql
# Counter - Cumulative bans per jail
fail2ban_ban_events_total
```

#### Panel 5: Top Banned Jails

```promql
# Table - Jails sorted by ban count
topk(5, fail2ban_ban_events_total)
```

### Sample Grafana Dashboard JSON

```json
{
  "dashboard": {
    "title": "fail2ban Monitoring",
    "panels": [
      {
        "title": "Active Jails",
        "targets": [
          {
            "expr": "fail2ban_jails_total"
          }
        ],
        "type": "stat"
      },
      {
        "title": "Currently Banned IPs",
        "targets": [
          {
            "expr": "fail2ban_bans_total",
            "legendFormat": "{{jail}}"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Ban Rate (per hour)",
        "targets": [
          {
            "expr": "rate(fail2ban_ban_events_total[1h]) * 3600",
            "legendFormat": "{{jail}}"
          }
        ],
        "type": "graph"
      }
    ]
  }
}
```

## Alerting

### Example Prometheus Alerts

Create alerting rules (`/etc/prometheus/alerts/fail2ban.yml`):

```yaml
groups:
  - name: fail2ban
    interval: 5m
    rules:
      - alert: Fail2banHighBanRate
        expr: rate(fail2ban_ban_events_total[5m]) > 10
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High fail2ban ban rate on {{ $labels.hostname }}"
          description: "Jail {{ $labels.jail }} has banned >10 IPs/min for 10 minutes"

      - alert: Fail2banManyBannedIPs
        expr: fail2ban_bans_total > 50
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Many banned IPs on {{ $labels.hostname }}"
          description: "Jail {{ $labels.jail }} has {{ $value }} currently banned IPs"

      - alert: Fail2banJailsDown
        expr: fail2ban_jails_total == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "fail2ban has no active jails on {{ $labels.hostname }}"
          description: "fail2ban service may be down or misconfigured"
```

**Reload Prometheus alerts**:
```bash
sudo systemctl reload prometheus
```

## Monitoring Best Practices

1. **Regular Scrapes**: Set scrape interval to 1-5 minutes
2. **Long Retention**: Keep metrics for 30+ days to analyze trends
3. **Alerting Thresholds**: Adjust based on your typical ban rate
4. **Dashboard Access**: Share Grafana dashboard with security team
5. **Incident Response**: Link alerts to incident response procedures

## Troubleshooting

### Problem: Metrics file not found

**Check**:
```bash
ls -la /var/lib/node_exporter/textfile_collector/fail2ban.prom
```

**Solution**:
```bash
# Run exporter manually
sudo /usr/local/bin/fail2ban-metrics-exporter.sh

# Check permissions
sudo chmod 644 /var/lib/node_exporter/textfile_collector/fail2ban.prom
```

### Problem: Metrics not appearing in Prometheus

**Check**:
```bash
# Verify node_exporter is scraping textfile collector
curl http://localhost:9100/metrics | grep fail2ban
```

**Solution**:
1. Ensure node_exporter has `--collector.textfile.directory` flag
2. Restart node_exporter
3. Check Prometheus scrape config

### Problem: Timer not running

**Check**:
```bash
systemctl status fail2ban-metrics.timer
systemctl list-timers | grep fail2ban
```

**Solution**:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now fail2ban-metrics.timer
```

### Problem: Stale metrics

**Symptoms**: Metrics don't update

**Solution**:
```bash
# Check last run
sudo journalctl -u fail2ban-metrics.service -n 10

# Force manual run
sudo systemctl start fail2ban-metrics.service

# Check timer schedule
systemctl list-timers fail2ban-metrics.timer
```

## Advanced: Custom Metrics

To add custom metrics, edit `/usr/local/bin/fail2ban-metrics-exporter.sh`:

```bash
# Example: Add jail uptime metric
printf '# HELP fail2ban_jail_uptime_seconds Jail uptime in seconds\n'
printf '# TYPE fail2ban_jail_uptime_seconds gauge\n'

# Calculate uptime (time since jail started)
# Implementation depends on fail2ban version
```

## See Also

- [SETUP.md](SETUP.md) - Initial installation
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
