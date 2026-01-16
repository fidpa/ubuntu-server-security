# AIDE Drop-in Configurations

Service-specific exclude patterns for AIDE, organized as modular drop-in files.

## Drop-in Pattern

Instead of a monolithic 500+ line `aide.conf`, this approach uses:
- **Base configuration** (120 lines): Core rules in `aide.conf.template`
- **Service drop-ins** (10-30 lines each): Service-specific excludes in this directory

**Benefits**:
- ✅ Easy to add/remove services (just add/delete drop-in file)
- ✅ DRY principle (base config stays unchanged)
- ✅ Testable (validate drop-ins individually)
- ✅ Maintainable (clear separation of concerns)

## Naming Convention

Drop-in files are processed in alphanumeric order:

- `10-*.conf` - Infrastructure services (Docker, Monitoring)
- `20-*.conf` - Database services (PostgreSQL, MySQL)
- `30-*.conf` - Application services (Nextcloud, WordPress)
- `40-*.conf` - System services (systemd, logging)
- `50-*.conf` - External resources (Network shares, backups)
- `99-*.conf` - User customizations

## Included Drop-ins

| File | Service | Purpose |
|------|---------|---------|
| [10-docker-excludes.conf](10-docker-excludes.conf) | Docker | Exclude volumes, containers, overlay2, runtime |
| [15-monitoring-excludes.conf](15-monitoring-excludes.conf) | Monitoring | Exclude Prometheus WAL, Grafana DB, metrics |
| [16-backups-excludes.conf](16-backups-excludes.conf) | Backups | Exclude backup snapshots, archives |
| [20-postgresql-excludes.conf](20-postgresql-excludes.conf) | PostgreSQL | Exclude WAL, stat_tmp, logs |
| [30-nextcloud-excludes.conf](30-nextcloud-excludes.conf) | Nextcloud | Exclude data directory, caches |
| [40-systemd-excludes.conf](40-systemd-excludes.conf) | systemd | Exclude journal, timers, runtime |
| [50-network-shares-excludes.conf](50-network-shares-excludes.conf) | Network Shares | Exclude SSHFS/NFS/CIFS mounts (prevents I/O errors) |
| [99-custom.conf.example](99-custom.conf.example) | Custom | Template for your own excludes |

## How to Use

1. **Copy to AIDE config directory**:
   ```bash
   sudo cp *.conf /etc/aide/aide.conf.d/
   ```

2. **Enable only the services you use**:
   ```bash
   # If you don't use Nextcloud:
   sudo rm /etc/aide/aide.conf.d/30-nextcloud-excludes.conf
   
   # If you don't have network shares:
   sudo rm /etc/aide/aide.conf.d/50-network-shares-excludes.conf
   ```

3. **Add your own excludes**:
   ```bash
   sudo cp 99-custom.conf.example /etc/aide/aide.conf.d/99-custom.conf
   sudo nano /etc/aide/aide.conf.d/99-custom.conf
   ```

4. **Test your configuration**:
   ```bash
   sudo aide --config-check
   ```

5. **Regenerate database** after changes:
   ```bash
   sudo aideinit
   sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
   ```

## Creating Your Own Drop-ins

Example: Redis excludes

```bash
# File: /etc/aide/aide.conf.d/25-redis-excludes.conf

# Redis data directory (RDB snapshots change frequently)
\!/var/lib/redis

# Redis logs
\!/var/log/redis

# Redis AOF (append-only file)
\!/var/lib/redis/appendonly.aof

# Monitor Redis config (but not data)
/etc/redis Full
```

**AIDE Group Reference**:
- `Full` - Complete integrity check (immutable files)
- `VarFile` - Metadata only (content changes OK)
- `VarDir` - Directory structure monitoring
- `ActLog` - Active logs (growing files)

See [../docs/FALSE_POSITIVE_REDUCTION.md](../docs/FALSE_POSITIVE_REDUCTION.md) for detailed explanation of AIDE groups.

## Common Patterns

### Monitoring Stack Excludes

If you use Prometheus, Grafana, or similar monitoring tools:
- ✅ Include `15-monitoring-excludes.conf`
- Prevents timeouts from scanning large time-series databases
- Prometheus WAL can grow to several GB and changes every 2 hours

### Backup Storage Excludes

If you store backups on the same server:
- ✅ Include `16-backups-excludes.conf`
- Prevents scanning large backup snapshots (can be 50+ GB)
- Still monitors backup scripts and configuration

### Network Shares Excludes

If you mount remote filesystems (NFS/SSHFS/CIFS):
- ✅ Include `50-network-shares-excludes.conf`
- **Critical**: Prevents I/O errors and scan timeouts on stale mounts
- Unmounted network shares can cause AIDE to hang for hours

## Validation

After adding drop-ins, verify no syntax errors:

```bash
sudo aide --config-check
```

Then test with a dry-run:

```bash
sudo aide --check --config=/etc/aide/aide.conf
```

## Troubleshooting

**Problem**: Drop-in not loaded

Check `/etc/aide/aide.conf` contains:
```
@@x_include /etc/aide/aide.conf.d ^[a-zA-Z0-9_-]+$
```

**Problem**: Still getting false-positives

Review [../docs/FALSE_POSITIVE_REDUCTION.md](../docs/FALSE_POSITIVE_REDUCTION.md) for methodology.

**Problem**: AIDE scan takes hours

Check if you're scanning large operational directories:
- Monitoring data (Prometheus WAL, Grafana DB)
- Backup snapshots
- Network shares (especially unmounted ones\!)

Use the appropriate drop-ins to exclude these.
