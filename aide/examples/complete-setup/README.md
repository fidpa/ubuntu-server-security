# Complete AIDE Setup Example

End-to-end deployment script for AIDE with all components.

## What This Does

This example provides a **one-command deployment** of AIDE with:
- ✅ Configuration templates
- ✅ Service-specific drop-ins
- ✅ Production scripts
- ✅ systemd automation
- ✅ Prometheus metrics
- ✅ Validation checks

## Prerequisites

- Ubuntu 22.04 LTS or 24.04 LTS
- Root access
- AIDE package installed (`sudo apt install aide aide-common`)

## Quick Start

```bash
# 1. Clone repository
cd /tmp
git clone https://github.com/fidpa/ubuntu-server-security.git
cd ubuntu-server-security/aide/examples/complete-setup

# 2. Run deployment script
sudo ./deploy.sh

# 3. Follow interactive prompts
# - Select services to monitor (Docker, PostgreSQL, etc.)
# - Configure CPU workers
# - Enable Prometheus metrics (optional)

# 4. Verify installation
sudo systemctl status aide-update.timer
sudo aide --check
```

## What Gets Deployed

| Component | Destination | Purpose |
|-----------|-------------|---------|
| aide.conf.template | /etc/aide/aide.conf | Main configuration |
| aide.default.template | /etc/default/aide | Cron behavior |
| Drop-in configs | /etc/aide/aide.conf.d/ | Service excludes |
| update-aide-db.sh | /usr/local/bin/ | Update script |
| backup-aide-db.sh | /usr/local/bin/ | Backup script |
| aide-metrics-exporter.sh | /usr/local/bin/ | Metrics exporter |
| aide-update.service | /etc/systemd/system/ | Service unit |
| aide-update.timer | /etc/systemd/system/ | Timer unit |

## Interactive Options

The deployment script will ask:

### 1. Service Detection

```
Which services are running on this server?
[x] Docker
[ ] PostgreSQL
[ ] Nextcloud
[x] systemd (recommended)
```

Only selected services will have drop-in excludes deployed.

### 2. CPU Workers

```
How many CPU cores should AIDE use? (default: 4)
Detected: 8 cores
Recommended: 4-6 workers
> 4
```

### 3. Prometheus Metrics

```
Enable Prometheus metrics export? (y/n)
> y

node_exporter textfile collector directory?
(default: /var/lib/node_exporter/textfile_collector)
>
```

### 4. Schedule

```
When should AIDE run daily checks?
(default: 04:00)
> 04:00
```

## Manual Deployment

If you prefer manual control:

```bash
# Copy configuration
sudo cp ../../aide.conf.template /etc/aide/aide.conf
sudo cp ../../aide.default.template /etc/default/aide

# Replace placeholders
sudo sed -i "s/{{HOSTNAME}}/$(hostname)/g" /etc/aide/aide.conf
sudo sed -i "s/{{NUM_WORKERS}}/4/g" /etc/aide/aide.conf
sudo sed -i "s|{{DROPIN_DIR}}|/etc/aide/aide.conf.d|g" /etc/aide/aide.conf

# Copy drop-ins (only for services you use)
sudo mkdir -p /etc/aide/aide.conf.d
sudo cp ../../drop-ins/10-docker-excludes.conf /etc/aide/aide.conf.d/
# ... etc

# Copy scripts
sudo cp ../../scripts/*.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/update-aide-db.sh
sudo chmod 755 /usr/local/bin/backup-aide-db.sh
sudo chmod 755 /usr/local/bin/aide-metrics-exporter.sh

# Copy systemd units
sudo cp ../../systemd/aide-update.service.template /etc/systemd/system/aide-update.service
sudo cp ../../systemd/aide-update.timer.template /etc/systemd/system/aide-update.timer

# Replace placeholders in systemd units
sudo sed -i 's|{{SCRIPT_PATH}}|/usr/local/bin|g' /etc/systemd/system/aide-update.service
sudo sed -i 's|{{METRICS_SCRIPT}}|/usr/local/bin|g' /etc/systemd/system/aide-update.service
sudo sed -i 's|{{LOG_DIR}}|/var/log/aide|g' /etc/systemd/system/aide-update.service
sudo sed -i 's|{{TIMEOUT}}|90|g' /etc/systemd/system/aide-update.service
sudo sed -i 's|{{TIMEOUT_SECONDS}}|5400|g' /etc/systemd/system/aide-update.service

# Initialize database
sudo aideinit
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Enable timer
sudo systemctl daemon-reload
sudo systemctl enable --now aide-update.timer
```

## Verification

After deployment, verify:

```bash
# 1. Configuration is valid
sudo aide --config-check

# 2. Database exists
ls -lh /var/lib/aide/aide.db

# 3. Timer is active
sudo systemctl status aide-update.timer

# 4. Scripts are executable
ls -l /usr/local/bin/update-aide-db.sh
ls -l /usr/local/bin/backup-aide-db.sh
ls -l /usr/local/bin/aide-metrics-exporter.sh

# 5. Manual check works
sudo aide --check

# 6. Metrics exported (if enabled)
cat /var/lib/node_exporter/textfile_collector/aide.prom
```

## Expected Output

**Successful deployment**:
```
✓ Configuration deployed
✓ Scripts installed
✓ systemd timer enabled
✓ Database initialized (155,432 entries)
✓ Metrics exporter configured

AIDE is now active. Next run: 2026-01-05 04:00:00

To verify: sudo systemctl status aide-update.timer
```

## Troubleshooting

See [../../../docs/TROUBLESHOOTING.md](../../../docs/TROUBLESHOOTING.md) for common issues.

## Uninstall

```bash
# Stop and disable timer
sudo systemctl stop aide-update.timer
sudo systemctl disable aide-update.timer

# Remove files
sudo rm /etc/systemd/system/aide-update.{service,timer}
sudo rm /usr/local/bin/{update-aide-db.sh,backup-aide-db.sh,aide-metrics-exporter.sh}
sudo rm -rf /etc/aide/aide.conf.d
sudo rm /etc/aide/aide.conf
sudo rm /etc/default/aide

# Remove data
sudo rm -rf /var/lib/aide
sudo rm -rf /var/log/aide
sudo rm -rf /var/backups/aide

# Reload systemd
sudo systemctl daemon-reload
```

## See Also

- [../../../docs/SETUP.md](../../../docs/SETUP.md) - Detailed setup guide
- [../../../docs/BEST_PRACTICES.md](../../../docs/BEST_PRACTICES.md) - Production recommendations
