# GeoIP Filtering for fail2ban

Country-based IP whitelisting for SSH protection.

## Concept

GeoIP filtering allows you to restrict SSH access (or other services) to specific countries. This is particularly useful when:
- Your legitimate users are in specific geographic regions
- You want to block brute-force attacks from known high-risk countries
- Compliance requires geo-restrictions

**Default whitelist**: DE, AT, CH, NL, FR, BE, LU (DACH region + neighbors)

## How It Works

1. SSH login attempt from IP `1.2.3.4`
2. fail2ban calls `geoip-whitelist.sh 1.2.3.4`
3. Script performs GeoIP lookup
4. If country is whitelisted → `exit 0` (allow)
5. If country is NOT whitelisted → `exit 1` (ban immediately)

**Aggressive policy**: 1 attempt from non-whitelisted country → 24 hour ban

## Prerequisites

### Install GeoIP Packages

```bash
# Install GeoIP lookup tool and database
sudo apt install geoip-bin geoip-database

# Verify installation
geoiplookup 8.8.8.8
# Expected output: GeoIP Country Edition: US, United States
```

### Test GeoIP Lookup

```bash
# Test various countries
geoiplookup 8.8.8.8       # US (Google DNS)
geoiplookup 9.9.9.9       # US (Quad9 DNS)
geoiplookup 1.1.1.1       # AU (Cloudflare)
geoiplookup 193.99.144.80 # DE (Germany - should match whitelist)
```

## Installation

### 1. Deploy GeoIP Whitelist Script

```bash
# Copy script to system location
sudo cp scripts/geoip-whitelist.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/geoip-whitelist.sh

# Verify script is executable
ls -la /usr/local/bin/geoip-whitelist.sh
```

### 2. Test Script

```bash
# Test with US IP (should DENY - exit 1)
/usr/local/bin/geoip-whitelist.sh 8.8.8.8
echo $?  # Expected: 1

# Test with German IP (should ALLOW - exit 0)
/usr/local/bin/geoip-whitelist.sh 193.99.144.80
echo $?  # Expected: 0

# Test with private IP (should ALLOW - exit 0)
/usr/local/bin/geoip-whitelist.sh 10.0.0.1
echo $?  # Expected: 0
```

### 3. Deploy GeoIP Jail

```bash
# Copy GeoIP jail configuration
sudo cp drop-ins/40-geoip.conf /etc/fail2ban/jail.d/

# Restart fail2ban
sudo systemctl restart fail2ban

# Verify jail is active
sudo fail2ban-client status
# Expected: "sshd-geoip" in jail list
```

### 4. Check Jail Status

```bash
# View GeoIP jail details
sudo fail2ban-client status sshd-geoip

# Expected output:
# Status for the jail: sshd-geoip
# |- Filter
# |  |- Currently failed: 0
# |  |- Total failed:     0
# |  `- File list:        /var/log/auth.log
# `- Actions
#    |- Currently banned: 0
#    |- Total banned:     0
#    `- Banned IP list:
```

## Configuration

### Customize Whitelist Countries

Edit `/usr/local/bin/geoip-whitelist.sh`:

```bash
# Change this line (default):
readonly WHITELIST_COUNTRIES="${GEOIP_WHITELIST:-DE|AT|CH|NL|FR|BE|LU}"

# To customize (e.g., only Germany and Austria):
readonly WHITELIST_COUNTRIES="${GEOIP_WHITELIST:-DE|AT}"
```

**Or** set environment variable before running script:
```bash
export GEOIP_WHITELIST="DE|AT|CH|NL"
```

### Adjust Ban Policy

Edit `/etc/fail2ban/jail.d/40-geoip.conf`:

```ini
[sshd-geoip]
enabled = true

# Change ban duration (default: 24 hours = 86400 seconds)
bantime = 86400    # 24 hours
# bantime = 604800 # 1 week
# bantime = -1     # Permanent ban

# Change maxretry (default: 1 attempt)
maxretry = 1       # Aggressive: 1 strike
# maxretry = 3     # Moderate: 3 strikes

# Change findtime (default: 24 hours)
findtime = 86400   # 24 hours
```

## Monitoring

### View GeoIP Logs

```bash
# Follow GeoIP decision logs
sudo tail -f /var/log/$(hostname -s)/fail2ban-geoip.log

# Example output:
# [2026-01-10 12:00:00] IP=1.2.3.4 COUNTRY=US
# [2026-01-10 12:00:00] DENY: 1.2.3.4 (Not in whitelist)
# [2026-01-10 12:01:00] IP=10.0.0.5 PRIVATE_IP=true
# [2026-01-10 12:01:00] ALLOW: 10.0.0.5 (Private IP)
```

### View Banned IPs

```bash
# Check currently banned IPs in GeoIP jail
sudo fail2ban-client status sshd-geoip

# View ban details
sudo fail2ban-client get sshd-geoip banip
```

### Manual Unban

```bash
# Unban specific IP
sudo fail2ban-client set sshd-geoip unbanip 1.2.3.4

# Verify
sudo fail2ban-client status sshd-geoip
```

## Integration with Telegram Alerts

To receive Telegram notifications when IPs are banned by GeoIP filtering:

1. **Configure Telegram** (see [TELEGRAM_INTEGRATION.md](TELEGRAM_INTEGRATION.md))

2. **Edit GeoIP jail** (`/etc/fail2ban/jail.d/40-geoip.conf`):
   ```ini
   [sshd-geoip]
   enabled = true
   # ... other settings ...

   # Add Telegram action
   action = %(action_)s
            telegram[name=SSH-GeoIP]
   ```

3. **Restart fail2ban**:
   ```bash
   sudo systemctl restart fail2ban
   ```

**Telegram alert includes**:
- Banned IP
- Country code (from GeoIP lookup)
- ISP (via whois)
- Jail name (SSH-GeoIP)
- Ban duration

## Troubleshooting

### Problem: geoiplookup not found

**Solution**:
```bash
sudo apt install geoip-bin geoip-database
```

### Problem: Script returns exit 1 for whitelisted country

**Possible causes**:
1. GeoIP database outdated
2. IP range not in database
3. Typo in whitelist regex

**Debug**:
```bash
# Manual lookup
geoiplookup <ip_address>

# Check whitelist regex
grep WHITELIST_COUNTRIES /usr/local/bin/geoip-whitelist.sh
```

### Problem: Private IPs are banned

**Check**:
```bash
# Script should automatically whitelist RFC1918 ranges
# Test with your management IP
/usr/local/bin/geoip-whitelist.sh 10.0.0.1
echo $?  # Should be 0 (allowed)
```

If private IPs are still banned, check fail2ban's `ignoreip` setting.

### Problem: Too many legitimate users banned

**Solutions**:
1. **Expand whitelist**: Add more countries to `WHITELIST_COUNTRIES`
2. **Use standard SSH jail**: Disable GeoIP jail, use `10-sshd.conf` instead
3. **Increase maxretry**: Change from 1 to 3 in `40-geoip.conf`

### Problem: GeoIP database outdated

**Update database**:
```bash
# Install geoipupdate (for automatic updates)
sudo apt install geoipupdate

# Manual update (downloads latest database)
sudo geoipupdate

# Or reinstall database package
sudo apt install --reinstall geoip-database
```

## Best Practices

1. **Whitelist Management Network**: Add to `ignoreip` in `/etc/fail2ban/fail2ban.local`
   ```ini
   ignoreip = 127.0.0.1/8 ::1 10.0.0.0/24
   ```

2. **Test Before Production**: Use `--dry-run` mode or test on non-critical server first

3. **Monitor Logs**: Check GeoIP logs weekly for false positives

4. **Combine with Standard SSH Jail**: Run both `10-sshd.conf` and `40-geoip.conf` for defense-in-depth

5. **Document Exceptions**: If you whitelist additional countries, document why

6. **Regular Reviews**: Review whitelist quarterly based on user locations

## Country Codes Reference

Common country codes for `WHITELIST_COUNTRIES`:

| Code | Country |
|------|---------|
| DE | Germany |
| AT | Austria |
| CH | Switzerland |
| NL | Netherlands |
| FR | France |
| BE | Belgium |
| LU | Luxembourg |
| US | United States |
| GB | United Kingdom |
| CA | Canada |
| AU | Australia |
| JP | Japan |
| SG | Singapore |

Full list: [ISO 3166-1 alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2)

## See Also

- [SETUP.md](SETUP.md) - Initial installation
- [TELEGRAM_INTEGRATION.md](TELEGRAM_INTEGRATION.md) - Alert setup
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
