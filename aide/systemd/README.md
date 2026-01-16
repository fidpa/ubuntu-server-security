# AIDE systemd Integration

Automated AIDE database updates using systemd timers.

## Files

| File | Purpose |
|------|---------|
| [aide-update.service.template](aide-update.service.template) | Service unit for AIDE updates |
| [aide-update.timer.template](aide-update.timer.template) | Timer unit for daily execution |

## Installation

1. **Copy templates** to systemd directory:
   ```bash
   sudo cp aide-update.service.template /etc/systemd/system/aide-update.service
   sudo cp aide-update.timer.template /etc/systemd/system/aide-update.timer
   ```

2. **Edit service unit** - Replace placeholders:
   ```bash
   sudo nano /etc/systemd/system/aide-update.service
   ```

   Replace:
   - `{{SCRIPT_PATH}}` → Path to `update-aide-db.sh` (e.g., `/usr/local/bin/update-aide-db.sh`)
   - `{{METRICS_SCRIPT}}` → Path to `aide-metrics-exporter.sh`
   - `{{LOG_DIR}}` → Log directory (e.g., `/var/log/aide`)
   - `{{TIMEOUT}}` → Timeout in minutes (default: 90)

3. **Reload systemd**:
   ```bash
   sudo systemctl daemon-reload
   ```

4. **Enable and start timer**:
   ```bash
   sudo systemctl enable aide-update.timer
   sudo systemctl start aide-update.timer
   ```

5. **Verify timer is active**:
   ```bash
   sudo systemctl status aide-update.timer
   sudo systemctl list-timers aide-update.timer
   ```

## Customization

### Change Schedule

Edit `/etc/systemd/system/aide-update.timer`:

```ini
[Timer]
# Daily at 4:00 AM
OnCalendar=daily

# Change to weekly (Sunday at 2:00 AM)
OnCalendar=Sun *-*-* 02:00:00

# Change to specific time (3:30 AM)
OnCalendar=*-*-* 03:30:00
```

See `man systemd.time` for OnCalendar syntax.

### Adjust Timeout

For large databases, increase timeout in service unit:

```ini
[Service]
# NAS with 2TB database needs 240 minutes
TimeoutStartSec=240min
```

### Add Randomized Delay

Prevent load spikes when multiple servers run AIDE simultaneously:

```ini
[Timer]
OnCalendar=daily
RandomizedDelaySec=1800  # Random delay up to 30 minutes
```

## Monitoring

### Check Timer Status

```bash
# When will it run next?
sudo systemctl list-timers aide-update.timer

# Timer configuration
sudo systemctl cat aide-update.timer

# Timer logs
sudo journalctl -u aide-update.timer
```

### Check Service Status

```bash
# Last run status
sudo systemctl status aide-update.service

# Service logs (last 50 lines)
sudo journalctl -u aide-update.service -n 50

# Follow logs in real-time
sudo journalctl -u aide-update.service -f
```

### Manual Execution

Test the service manually:

```bash
sudo systemctl start aide-update.service
```

## Troubleshooting

**Problem**: Timer doesn't run

```bash
# Check if timer is enabled
sudo systemctl is-enabled aide-update.timer

# Check if timer is active
sudo systemctl is-active aide-update.timer

# Enable and start
sudo systemctl enable --now aide-update.timer
```

**Problem**: Service fails

```bash
# Check service logs
sudo journalctl -u aide-update.service -n 100

# Check script permissions
ls -la /usr/local/bin/update-aide-db.sh

# Test script manually
sudo /usr/local/bin/update-aide-db.sh --check
```

**Problem**: Timeout

Increase `TimeoutStartSec` in service unit. Large databases (2TB+) can take 4+ hours.

## Security Hardening

The service template includes security hardening:

- `PrivateTmp=yes` - Isolated /tmp directory
- `NoNewPrivileges=yes` - Prevents privilege escalation
- `ReadWritePaths=` - Explicit write permissions
- `ProtectSystem=strict` - Read-only /usr, /boot, /efi

Additional hardening options (add to `[Service]`):

```ini
# Restrict network access (AIDE doesn't need network)
PrivateNetwork=yes

# Restrict device access
PrivateDevices=yes

# Read-only /home
ProtectHome=yes
```

Test hardening changes:

```bash
sudo systemd-analyze security aide-update.service
```

## See Also

- [../docs/SETUP.md](../../docs/SETUP.md) - Complete setup guide
- [../docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md) - Common issues

---

## Boot-Time Behavior

### What Happens at Boot?

When system boots, AIDE timer starts but **does not run immediately**. First scheduled run is according to  setting.

**Boot Sequence**:
\`\`\`
1. local-fs.target (mount /var, /tmp)
2. network.target (network interfaces up)
3. multi-user.target
   └── aide-update.timer (enabled, waiting for schedule)
\`\`\`

**No immediate execution**: Timer waits for scheduled time (e.g., 04:00 AM).

### Running AIDE at Boot (Optional)

If you want AIDE to run once at boot:

\`\`\`ini
[Timer]
OnCalendar=daily
OnBootSec=5min  # Run 5 minutes after boot
\`\`\`

**Warning**: This increases boot time! AIDE can take 5-15 minutes.

### Boot Timeout Issues

**Problem**: Service times out during boot if database scan is slow.

**Solution**: Increase timeout in service unit:

\`\`\`ini
[Service]
TimeoutStartSec=30min  # Default: 90s is too short!
\`\`\`

### Emergency Mode Recovery

If AIDE service blocks boot:

1. **Boot to emergency mode** (add at GRUB):
   \`\`\`
   systemd.unit=emergency.target
   \`\`\`

2. **Disable AIDE temporarily**:
   \`\`\`bash
   systemctl mask aide-update.service
   systemctl mask aide-update.timer
   \`\`\`

3. **Reboot normally**, fix configuration, then unmask.

### Best Practices

1. **✅ Use Timer**: Daily timer, not boot-time service
2. **✅ Increase Timeout**: Set  minimum
3. **✅ Add Dependencies**: Explicit 
4. **❌ Don't block boot**: AIDE should not block 

**See Also**: [../docs/BOOT_RESILIENCY.md](../docs/BOOT_RESILIENCY.md) - Comprehensive boot behavior guide


---

## Boot-Time Behavior

### What Happens at Boot?

When system boots, AIDE timer starts but **does not run immediately**. First scheduled run is according to `OnCalendar=` setting.

**Boot Sequence**:
```
1. local-fs.target (mount /var, /tmp)
2. network.target (network interfaces up)
3. multi-user.target
   └── aide-update.timer (enabled, waiting for schedule)
```

**No immediate execution**: Timer waits for scheduled time (e.g., 04:00 AM).

### Running AIDE at Boot (Optional)

If you want AIDE to run once at boot:

```ini
[Timer]
OnCalendar=daily
OnBootSec=5min  # Run 5 minutes after boot
```

**Warning**: This increases boot time! AIDE can take 5-15 minutes.

### Boot Timeout Issues

**Problem**: Service times out during boot if database scan is slow.

**Solution**: Increase timeout in service unit:

```ini
[Service]
TimeoutStartSec=30min  # Default: 90s is too short!
```

### Emergency Mode Recovery

If AIDE service blocks boot:

1. **Boot to emergency mode** (add at GRUB):
   ```
   systemd.unit=emergency.target
   ```

2. **Disable AIDE temporarily**:
   ```bash
   systemctl mask aide-update.service
   systemctl mask aide-update.timer
   ```

3. **Reboot normally**, fix configuration, then unmask.

### Best Practices

1. **✅ Use Timer**: Daily timer, not boot-time service
2. **✅ Increase Timeout**: Set `TimeoutStartSec=30min` minimum
3. **✅ Add Dependencies**: Explicit `After=local-fs.target network.target`
4. **❌ Don't block boot**: AIDE should not block `multi-user.target`

**See Also**: [../docs/BOOT_RESILIENCY.md](../docs/BOOT_RESILIENCY.md) - Comprehensive boot behavior guide
