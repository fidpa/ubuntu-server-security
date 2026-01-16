# fail2ban Drop-in Jail Configurations

Service-specific jail configurations, organized as modular drop-in files.

## Drop-in Pattern

Instead of a monolithic `jail.local` file with 500+ lines, this approach uses:
- **Base configuration** (~30 lines): Core settings in `jail.local.template`
- **Service drop-ins** (15-35 lines each): Service-specific jails in this directory

**Benefits**:
- ✅ Easy to add/remove services (just add/delete drop-in file)
- ✅ DRY principle (base config stays unchanged)
- ✅ Testable (validate jails individually)
- ✅ Maintainable (clear separation of concerns)

## Naming Convention

Drop-in files are processed in alphanumeric order:

- `10-*.conf` - Core services (SSH)
- `20-*.conf` - Web servers (nginx, Apache)
- `30-*.conf` - Remote access (VNC, RDP)
- `40-*.conf` - Advanced features (GeoIP filtering)
- `99-*.conf` - User customizations

## Included Drop-ins

| File | Service | Purpose |
|------|---------|---------|
| [10-sshd.conf](10-sshd.conf) | SSH | Standard SSH brute-force protection |
| [20-nginx.conf](20-nginx.conf) | nginx | HTTP auth + rate limiting (Nextcloud, WordPress) |
| [30-vnc.conf](30-vnc.conf) | VNC | x11vnc, TigerVNC protection |
| [40-geoip.conf](40-geoip.conf) | SSH + GeoIP | Country-based IP whitelisting (requires geoip-bin) |
| [99-custom.conf.example](99-custom.conf.example) | Custom | Template for your own jails |

## How to Use

1. **Copy to fail2ban jail directory**:
   ```bash
   sudo cp *.conf /etc/fail2ban/jail.d/
   ```

2. **Enable only the services you use**:
   ```bash
   # If you don't use VNC:
   sudo rm /etc/fail2ban/jail.d/30-vnc.conf

   # If you don't want GeoIP filtering:
   sudo rm /etc/fail2ban/jail.d/40-geoip.conf
   ```

3. **Add your own jails**:
   ```bash
   sudo cp 99-custom.conf.example /etc/fail2ban/jail.d/99-custom.conf
   sudo nano /etc/fail2ban/jail.d/99-custom.conf
   ```

4. **Test your configuration**:
   ```bash
   sudo fail2ban-client --test
   ```

5. **Restart fail2ban** after changes:
   ```bash
   sudo systemctl restart fail2ban
   sudo fail2ban-client status
   ```

## Creating Your Own Drop-ins

Example: Postfix mail server jail

```bash
# File: /etc/fail2ban/jail.d/25-postfix.conf

[postfix-auth]
enabled = true
backend = systemd
port = smtp,submission,smtps
filter = postfix[mode=auth]
logpath = /var/log/mail.log
maxretry = 3
findtime = 600
bantime = 3600
```

**fail2ban Filter Reference**:
- Standard filters: `/etc/fail2ban/filter.d/`
- Custom filters: Create in `filters/` directory
- Test regex: `fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf`

## Common Jail Patterns

### Web Application Protection

If you host web applications (Nextcloud, WordPress, Joomla):
- ✅ Include `20-nginx.conf` or equivalent Apache jail
- Protects against password brute-force on login pages
- Rate limiting prevents DoS attacks

### Remote Access Protection

If you use remote desktop (VNC, RDP, x2go):
- ✅ Include `30-vnc.conf` or create custom RDP jail
- Critical for publicly accessible remote access
- Prevents credential stuffing attacks

### GeoIP Filtering

If you want country-based access control:
- ✅ Include `40-geoip.conf`
- **Requires**: `geoip-bin` + `geoip-database` packages
- **Requires**: `scripts/geoip-whitelist.sh` installed
- Whitelist specific countries (e.g., DE, AT, CH for DACH region)

## Validation

After adding drop-ins, verify no syntax errors:

```bash
sudo fail2ban-client --test
```

Check active jails:

```bash
sudo fail2ban-client status
```

View jail details:

```bash
sudo fail2ban-client status sshd
```

## Troubleshooting

**Problem**: Drop-in not loaded

**Solution**: Check file naming (must be `*.conf`) and location (`/etc/fail2ban/jail.d/`)

**Problem**: Jail enabled but not working

**Solution**: Check filter exists:
```bash
ls /etc/fail2ban/filter.d/sshd.conf
```

**Problem**: Too many false positives

**Solution**: Review and adjust:
- `maxretry` - Increase failed attempts threshold
- `findtime` - Increase time window
- `ignoreip` - Add trusted IPs to whitelist

See [../docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) for detailed solutions.

## Integration with Telegram Alerts

To receive ban notifications via Telegram:

1. Configure Telegram action (see `../actions/telegram.conf`)
2. Add to jail configuration:
   ```ini
   [sshd]
   enabled = true
   action = %(action_)s
            telegram[name=SSH]
   ```

See [../docs/TELEGRAM_INTEGRATION.md](../docs/TELEGRAM_INTEGRATION.md) for setup guide.

## Integration with Prometheus

To export ban metrics:

1. Deploy `../scripts/fail2ban-metrics-exporter.sh`
2. Configure systemd timer or cron
3. Metrics available at `/var/lib/node_exporter/textfile_collector/fail2ban.prom`

See [../docs/PROMETHEUS_INTEGRATION.md](../docs/PROMETHEUS_INTEGRATION.md) for details.
