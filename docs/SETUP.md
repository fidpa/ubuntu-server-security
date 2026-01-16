# AIDE Setup Guide

Complete installation and deployment guide for AIDE with production-ready configuration.

## Prerequisites

**Supported Platforms**:
- Ubuntu 22.04 LTS (Jammy)
- Ubuntu 24.04 LTS (Noble)

**Minimum Requirements**:
- AIDE v0.18.6+ (for `num_workers` and modern hash algorithms)
- systemd (for timer automation)
- 100 MB free disk space (for database and backups)

**Optional**:
- Prometheus + node_exporter (for metrics integration)
- `_aide` system group (for non-root monitoring)

## Step 1: Install AIDE

```bash
# Update package cache
sudo apt update

# Install AIDE
sudo apt install aide aide-common

# Verify version (must be >= 0.18.6)
aide --version
```

## Step 2: Deploy Configuration

### Main Configuration

```bash
# Backup existing config (if any)
sudo cp /etc/aide/aide.conf /etc/aide/aide.conf.bak

# Copy template
sudo cp aide/aide.conf.template /etc/aide/aide.conf

# Replace placeholders
sudo sed -i 's/{{HOSTNAME}}/'"$(hostname)"'/g' /etc/aide/aide.conf
sudo sed -i 's/{{NUM_WORKERS}}/4/g' /etc/aide/aide.conf  # Adjust for your CPU
sudo sed -i 's|{{DROPIN_DIR}}|/etc/aide/aide.conf.d|g' /etc/aide/aide.conf
```

### Default Configuration

```bash
# Copy default config
sudo cp aide/aide.default.template /etc/default/aide

# No placeholders to replace - this file is ready to use
```

### Drop-in Excludes

```bash
# Create drop-in directory
sudo mkdir -p /etc/aide/aide.conf.d

# Copy drop-ins (only for services you actually use)
sudo cp aide/drop-ins/10-docker-excludes.conf /etc/aide/aide.conf.d/
sudo cp aide/drop-ins/20-postgresql-excludes.conf /etc/aide/aide.conf.d/
# ... etc for other services

# If you don't use a service, don't copy its drop-in
# Example: If no Nextcloud, skip 30-nextcloud-excludes.conf
```

### Verify Configuration

```bash
# Check syntax
sudo aide --config-check

# Expected output: No errors
```

## Step 3: Initialize Database

This step scans your entire filesystem (can take 5-30 minutes depending on size):

```bash
# Initialize database
sudo aideinit

# This creates /var/lib/aide/aide.db.new

# Activate database
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

**Expected output**:
```
AIDE initialized successfully
Database written to /var/lib/aide/aide.db.new
```

## Step 4: Deploy Scripts

```bash
# Copy scripts to /usr/local/bin
sudo cp aide/scripts/update-aide-db.sh /usr/local/bin/
sudo cp aide/scripts/backup-aide-db.sh /usr/local/bin/
sudo cp aide/scripts/aide-metrics-exporter.sh /usr/local/bin/

# Make executable
sudo chmod 755 /usr/local/bin/update-aide-db.sh
sudo chmod 755 /usr/local/bin/backup-aide-db.sh
sudo chmod 755 /usr/local/bin/aide-metrics-exporter.sh

# Create log directory
sudo mkdir -p /var/log/aide
sudo chmod 750 /var/log/aide

# Create backup directory
sudo mkdir -p /var/backups/aide
sudo chmod 750 /var/backups/aide
```

## Step 5: Setup systemd Automation

```bash
# Copy service templates
sudo cp aide/systemd/aide-update.service.template /etc/systemd/system/aide-update.service
sudo cp aide/systemd/aide-update.timer.template /etc/systemd/system/aide-update.timer

# Edit service unit - replace placeholders
sudo sed -i 's|{{SCRIPT_PATH}}|/usr/local/bin|g' /etc/systemd/system/aide-update.service
sudo sed -i 's|{{METRICS_SCRIPT}}|/usr/local/bin|g' /etc/systemd/system/aide-update.service
sudo sed -i 's|{{LOG_DIR}}|/var/log/aide|g' /etc/systemd/system/aide-update.service
sudo sed -i 's|{{TIMEOUT}}|90|g' /etc/systemd/system/aide-update.service
sudo sed -i 's|{{TIMEOUT_SECONDS}}|5400|g' /etc/systemd/system/aide-update.service

# Reload systemd
sudo systemctl daemon-reload

# Enable and start timer
sudo systemctl enable aide-update.timer
sudo systemctl start aide-update.timer
```

## Step 6: Verify Installation

```bash
# Check timer status
sudo systemctl status aide-update.timer

# When will it run next?
sudo systemctl list-timers aide-update.timer

# Test manual run (dry-run, won't update DB)
sudo /usr/local/bin/update-aide-db.sh --check

# Check database
ls -lh /var/lib/aide/aide.db

# Check permissions
stat /var/lib/aide/aide.db
# Should be: root:_aide 640
```

## Step 7: Optional - Prometheus Integration

If you have Prometheus + node_exporter:

```bash
# Create metrics directory
sudo mkdir -p /var/lib/node_exporter/textfile_collector
sudo chmod 755 /var/lib/node_exporter/textfile_collector

# Export metrics manually (to test)
sudo /usr/local/bin/aide-metrics-exporter.sh

# Verify metrics file
cat /var/lib/node_exporter/textfile_collector/aide.prom
```

Configure node_exporter:
```bash
# Add --collector.textfile.directory flag
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

See [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) for Grafana dashboards.

## Step 8: Optional - Non-Root Monitoring

Allow monitoring tools (Prometheus, health-checks) to read AIDE database:

```bash
# Create _aide group
sudo groupadd --system _aide

# Add monitoring users to group
sudo usermod -aG _aide prometheus
sudo usermod -aG _aide nagios  # or your monitoring user

# Fix permissions (done automatically by update-aide-db.sh)
sudo chown root:_aide /var/lib/aide/aide.db
sudo chmod 640 /var/lib/aide/aide.db
```

## Step 9: Optional - Vaultwarden Integration

Use Bitwarden CLI for credential management instead of plaintext `.env` files:

```bash
# Install Bitwarden CLI
sudo npm install -g @bitwarden/cli

# Configure server (if self-hosted)
bw config server https://vaultwarden.example.com

# Login
bw login your-email@example.com

# Test credential retrieval
bw get password "Test Item" --raw
```

**Usage in scripts**:
```bash
# Initialize session (one-time)
export BW_SESSION=$(bw unlock --raw)

# Retrieve credentials
PASSWORD=$(bw get password "Item Name" --raw)
```

See [VAULTWARDEN_INTEGRATION.md](VAULTWARDEN_INTEGRATION.md) for complete setup guide and migration from `.env.secrets`.

## Quick Commands Reference

| Command | Purpose |
|---------|---------|
| `sudo aide --check` | Run manual check |
| `sudo aideinit` | Initialize new database |
| `sudo systemctl status aide-update.timer` | Check timer status |
| `sudo systemctl list-timers aide-update.timer` | When will timer run? |
| `sudo journalctl -u aide-update.service -n 50` | View service logs |
| `sudo /usr/local/bin/update-aide-db.sh --check` | Test update script |
| `sudo cat /var/log/aide/aide.log` | View AIDE report |

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues.

## Next Steps

- Review [FALSE_POSITIVE_REDUCTION.md](FALSE_POSITIVE_REDUCTION.md) to fine-tune excludes
- Setup [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) for monitoring
- Configure [VAULTWARDEN_INTEGRATION.md](VAULTWARDEN_INTEGRATION.md) for secure credential management
- Read [BEST_PRACTICES.md](BEST_PRACTICES.md) for production recommendations

## See Also

- [Ansible Automation](https://github.com/fidpa/ubuntu-server-security-ansible) (Coming soon)
- [AIDE Official Documentation](https://aide.github.io/)
