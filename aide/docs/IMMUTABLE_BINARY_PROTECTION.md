# AIDE Immutable Binary Protection

Protection of AIDE binaries and configuration using immutable flags (`chattr +i`).

## Overview

AIDE monitors file integrity, but the AIDE binary itself can be replaced by malware. Immutable flags prevent modification of critical AIDE components.

## The Attack Scenario

**Without immutable protection**:
1. Attacker gains root access
2. Attacker replaces `/usr/bin/aide` with trojanized version
3. Trojanized AIDE reports "no changes" while system is compromised
4. Intrusion goes undetected

**With immutable protection**:
1. Attacker gains root access
2. Attacker tries to replace `/usr/bin/aide`
3. Operation fails: `rm: cannot remove '/usr/bin/aide': Operation not permitted`
4. Attacker must explicitly remove immutable flag (`chattr -i`)
5. **Detection opportunity**: Monitor for immutable flag removal

---

## Implementation

### Step 1: Identify Files to Protect

**Critical (MUST protect)**:
- `/usr/bin/aide` - AIDE binary
- `/etc/aide/aide.conf` - Main configuration

**Optional (MAY protect)**:
- `/etc/aide/aide.conf.d/*.conf` - Drop-in configs
- `/var/lib/aide/aide.db` - Database (prevents updates!)

---

### Step 2: Set Immutable Flags

```bash
# Protect AIDE binary
sudo chattr +i /usr/bin/aide

# Protect main configuration
sudo chattr +i /etc/aide/aide.conf

# Optional: Protect drop-in configs
sudo chattr +i /etc/aide/aide.conf.d/10-docker-excludes.conf
sudo chattr +i /etc/aide/aide.conf.d/20-postgresql-excludes.conf
```

---

### Step 3: Verify Protection

```bash
# Check flags
sudo lsattr /usr/bin/aide /etc/aide/aide.conf

# Expected output:
# ----i---------e------- /usr/bin/aide
# ----i---------e------- /etc/aide/aide.conf
```

**Flag meanings**:
- `i` = immutable (file cannot be modified, even by root)
- `e` = extent format (default for ext4 filesystem)

---

### Step 4: Test Protection

```bash
# Try to modify protected file (should fail)
sudo rm /usr/bin/aide
# rm: cannot remove '/usr/bin/aide': Operation not permitted

sudo vim /etc/aide/aide.conf
# Cannot save: Operation not permitted

# Success - protection is working!
```

---

## APT Upgrade Workflow

**Problem**: Package updates fail when binary is immutable

**Solution**: Remove flag, upgrade, restore flag

```bash
# 1. Check current flag
sudo lsattr /usr/bin/aide

# 2. Remove immutable flag
sudo chattr -i /usr/bin/aide

# 3. Perform upgrade
sudo apt update
sudo apt upgrade aide

# 4. Restore immutable flag
sudo chattr +i /usr/bin/aide

# 5. Verify
sudo lsattr /usr/bin/aide | grep -q 'i' && echo "✅ Protected"
```

---

## Automation for APT Hooks

### APT Pre-Invoke Hook

**File**: `/etc/apt/apt.conf.d/50aide-immutable`

```bash
# Pre-invoke: Remove immutable flag before upgrade
DPkg::Pre-Invoke {
    "if [ -f /usr/bin/aide ]; then chattr -i /usr/bin/aide 2>/dev/null || true; fi";
};

# Post-invoke: Restore immutable flag after upgrade
DPkg::Post-Invoke {
    "if [ -f /usr/bin/aide ]; then chattr +i /usr/bin/aide 2>/dev/null || true; fi";
};
```

**Install hook**:
```bash
sudo cp 50aide-immutable /etc/apt/apt.conf.d/
sudo chmod 644 /etc/apt/apt.conf.d/50aide-immutable
```

**Test hook**:
```bash
sudo apt upgrade aide --dry-run
# Should not show errors about Operation not permitted
```

---

## Monitoring Immutable Flag Status

### Manual Check

```bash
# Check all AIDE components
sudo lsattr /usr/bin/aide \
             /etc/aide/aide.conf \
             /var/lib/aide/aide.db

# Filter for immutable flag
sudo lsattr /usr/bin/aide | grep -q 'i' && \
    echo "✅ Protected" || echo "❌ NOT Protected"
```

---

### Automated Validation Script

Use the provided validation script:

```bash
./scripts/validate-immutable-flags.sh
```

**Output**:
```
==========================================
AIDE Immutable Flag Validation
==========================================

Checking AIDE binary... ✅ Protected
Checking AIDE config... ✅ Protected
Checking AIDE database... ⚠️  NOT Protected (optional)

✅ Validation PASSED - All required files are protected
```

---

### Prometheus Metrics

Export immutable flag status:

```bash
# File: /usr/local/bin/aide-immutable-metrics.sh

check_flag() {
    if lsattr "$1" 2>/dev/null | grep -qE '^[^[:space:]]*i'; then
        echo "1"  # Protected
    else
        echo "0"  # Not protected
    fi
}

cat > /var/lib/node_exporter/textfile_collector/aide_immutable.prom <<EOF
# HELP aide_immutable_flag_status AIDE immutable flag (1=protected, 0=unprotected)
# TYPE aide_immutable_flag_status gauge
aide_immutable_flag_status{file="/usr/bin/aide"} $(check_flag /usr/bin/aide)
aide_immutable_flag_status{file="/etc/aide/aide.conf"} $(check_flag /etc/aide/aide.conf)
EOF
```

**Run via cron**:
```cron
# /etc/cron.hourly/aide-immutable-metrics
0 * * * * /usr/local/bin/aide-immutable-metrics.sh
```

---

## Alerting

### Prometheus Alert

```yaml
groups:
  - name: aide_immutable
    rules:
      - alert: AideBinaryNotProtected
        expr: aide_immutable_flag_status{file="/usr/bin/aide"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "AIDE binary is NOT protected with immutable flag"
          description: "File /usr/bin/aide can be modified by malware"
```

---

## Troubleshooting

### Issue: Cannot Edit Configuration

**Symptom**:
```bash
$ sudo nano /etc/aide/aide.conf
# Cannot save: Operation not permitted
```

**Solution**:
```bash
# 1. Remove flag temporarily
sudo chattr -i /etc/aide/aide.conf

# 2. Edit file
sudo nano /etc/aide/aide.conf

# 3. Restore flag
sudo chattr +i /etc/aide/aide.conf
```

---

### Issue: APT Upgrade Fails

**Symptom**:
```bash
$ sudo apt upgrade aide
dpkg: error: unable to install new version: Operation not permitted
```

**Solution**: See "APT Upgrade Workflow" above

---

### Issue: Cannot Update AIDE Database

**Symptom**:
```bash
$ sudo aideinit
aide: error: cannot write to /var/lib/aide/aide.db
```

**Cause**: Database has immutable flag (NOT recommended)

**Solution**:
```bash
# Option 1: Remove flag (permanent)
sudo chattr -i /var/lib/aide/aide.db

# Option 2: Remove during update, restore after
sudo chattr -i /var/lib/aide/aide.db
sudo aideinit
sudo chattr +i /var/lib/aide/aide.db
```

**Recommendation**: DO NOT set immutable flag on database (prevents updates)

---

## Best Practices

### ✅ DO

1. **Protect binary**: Always set immutable flag on `/usr/bin/aide`
2. **Protect config**: Set immutable flag on `/etc/aide/aide.conf`
3. **Use APT hooks**: Automate flag removal/restoration
4. **Monitor status**: Check flags regularly (hourly/daily)
5. **Alert on changes**: Get notified if flag is removed
6. **Document process**: Team knows how to handle upgrades

### ❌ DON'T

1. **Protect database**: Makes updates impossible (optional only)
2. **Forget to restore**: After editing, always restore flag
3. **Ignore monitoring**: Flag removal = potential compromise
4. **Skip validation**: Use `validate-immutable-flags.sh` regularly

---

## Security Considerations

### Defense in Depth

Immutable flags are ONE layer of defense:

**Layer 1**: File permissions (`chmod`, `chown`)
**Layer 2**: Immutable flags (`chattr +i`)
**Layer 3**: AIDE monitoring (detects changes)
**Layer 4**: SELinux/AppArmor (MAC enforcement)

### Limitations

**What immutable flags protect against**:
- ✅ Accidental deletion
- ✅ Malware attempting direct file replacement
- ✅ Script errors that modify system files

**What immutable flags DON'T protect against**:
- ❌ Kernel-level rootkits (can bypass `chattr`)
- ❌ Physical access (can boot from USB, modify files)
- ❌ Attacker who knows to remove flag first

**Conclusion**: Immutable flags are useful, but not bulletproof

---

## See Also

- **[docs/AIDE_BINARY_VALIDATION.md](docs/AIDE_BINARY_VALIDATION.md)** - Monitoring and validation
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Issue #5: Immutable flag prevents APT upgrade
- **[BEST_PRACTICES.md](BEST_PRACTICES.md)** - Security best practices
- **[scripts/validate-immutable-flags.sh](scripts/validate-immutable-flags.sh)** - Validation script
