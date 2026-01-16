# AIDE Binary Validation

## Overview

AIDE binary and configuration files should be protected with immutable flags (`chattr +i`) to prevent tampering. This guide covers validation, monitoring, and alerting for immutable flag status.

## Immutable Flag Basics

### What is the Immutable Flag?

The immutable flag (`i`) prevents ANY modification to a file, even by root:

```bash
# Set immutable flag
sudo chattr +i /usr/bin/aide

# Try to modify (will fail)
sudo rm /usr/bin/aide
# rm: cannot remove '/usr/bin/aide': Operation not permitted

# Remove immutable flag
sudo chattr -i /usr/bin/aide
```

### Why Use Immutable Flags for AIDE?

**Without immutable flag**:
- Malware can replace `/usr/bin/aide` with compromised version
- Modified AIDE reports "no changes" while system is compromised

**With immutable flag**:
- Binary cannot be replaced without explicitly removing flag
- Attack requires TWO steps: `chattr -i` + replace binary
- Additional detection opportunity (monitoring can alert on flag removal)

---

## Manual Validation

### Check Current Status

```bash
# Check all AIDE components
sudo lsattr /usr/bin/aide /etc/aide/aide.conf /var/lib/aide/aide.db

# Expected output:
# ----i---------e------- /usr/bin/aide           ← Has 'i' flag ✅
# ----i---------e------- /etc/aide/aide.conf     ← Has 'i' flag ✅
# --------------e------- /var/lib/aide/aide.db   ← NO 'i' flag ⚠️
```

### Interpret Output

**Flag meanings**:
- `i` = immutable (file cannot be modified)
- `a` = append-only (can add, not modify)
- `e` = extent format (default for ext4)
- `-` = flag not set

**Expected status**:
- `/usr/bin/aide`: MUST have `i` flag
- `/etc/aide/aide.conf`: MUST have `i` flag
- `/var/lib/aide/aide.db`: Optional (may be updated by AIDE)

---

## Automated Validation Script

**File**: `/usr/local/bin/validate-aide-immutable.sh`

```bash
#!/bin/bash
# Validates immutable flags on AIDE components

set -euo pipefail

# Files to check
AIDE_BINARY="/usr/bin/aide"
AIDE_CONFIG="/etc/aide/aide.conf"
AIDE_DB="/var/lib/aide/aide.db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== AIDE Immutable Flag Validation ==="

check_immutable() {
    local file="$1"
    local required="${2:-true}"

    if [[ ! -f "$file" ]]; then
        echo -e "${YELLOW}⚠️  File does not exist: ${file}${NC}"
        return 0
    fi

    if lsattr "$file" 2>/dev/null | grep -qE '^[^[:space:]]*i'; then
        echo -e "${GREEN}✅ ${file}: immutable flag SET${NC}"
        return 0
    else
        if [[ "$required" == "true" ]]; then
            echo -e "${RED}❌ ${file}: immutable flag NOT set (REQUIRED)${NC}"
            return 1
        else
            echo -e "${YELLOW}⚠️  ${file}: immutable flag NOT set (optional)${NC}"
            return 0
        fi
    fi
}

# Validation
EXIT_CODE=0

check_immutable "$AIDE_BINARY" true || EXIT_CODE=1
check_immutable "$AIDE_CONFIG" true || EXIT_CODE=1
check_immutable "$AIDE_DB" false || true  # Optional

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}=== Validation PASSED ===${NC}"
else
    echo -e "${RED}=== Validation FAILED ===${NC}"
fi

exit $EXIT_CODE
```

**Usage**:
```bash
# Run validation
./validate-aide-immutable.sh

# Use in automation
if ./validate-aide-immutable.sh; then
    echo "AIDE binaries are protected"
else
    echo "WARNING: AIDE binaries are NOT protected!"
    # Send alert
fi
```

---

## Prometheus Metrics

### Metrics Exporter Script

**File**: `/usr/local/bin/aide-immutable-metrics.sh`

```bash
#!/bin/bash
# Exports AIDE immutable flag status to Prometheus

METRICS_FILE="/var/lib/node_exporter/textfile_collector/aide_immutable.prom"

check_flag() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "0"  # File not found
    elif lsattr "$file" 2>/dev/null | grep -qE '^[^[:space:]]*i'; then
        echo "1"  # Immutable flag set
    else
        echo "0"  # Immutable flag NOT set
    fi
}

# Generate metrics
{
    echo "# HELP aide_immutable_flag_status AIDE immutable flag status (1=protected, 0=unprotected)"
    echo "# TYPE aide_immutable_flag_status gauge"
    echo "aide_immutable_flag_status{file=\"/usr/bin/aide\"} $(check_flag /usr/bin/aide)"
    echo "aide_immutable_flag_status{file=\"/etc/aide/aide.conf\"} $(check_flag /etc/aide/aide.conf)"
    echo "aide_immutable_flag_status{file=\"/var/lib/aide/aide.db\"} $(check_flag /var/lib/aide/aide.db)"
} > "${METRICS_FILE}.tmp"

mv "${METRICS_FILE}.tmp" "${METRICS_FILE}"
```

**systemd Timer** (`/etc/systemd/system/aide-immutable-check.timer`):

```ini
[Unit]
Description=AIDE Immutable Flag Check Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
```

---

## Alerting

### Prometheus Alert Rules

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
          description: "/usr/bin/aide can be modified by malware"

      - alert: AideConfigNotProtected
        expr: aide_immutable_flag_status{file="/etc/aide/aide.conf"} == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "AIDE config is NOT protected with immutable flag"
```

### Telegram Alert Integration

```bash
# In aide-immutable-metrics.sh, add alerting:

if [[ $(check_flag /usr/bin/aide) -eq 0 ]]; then
    # Send Telegram alert
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="⚠️ AIDE binary is NOT protected with immutable flag!"
fi
```

---

## Troubleshooting

### Issue: Cannot modify AIDE files

**Symptom**:
```bash
$ sudo vim /etc/aide/aide.conf
# Cannot save: Operation not permitted
```

**Cause**: Immutable flag is set

**Fix**:
```bash
# 1. Remove immutable flag
sudo chattr -i /etc/aide/aide.conf

# 2. Edit file
sudo vim /etc/aide/aide.conf

# 3. Restore immutable flag
sudo chattr +i /etc/aide/aide.conf
```

### Issue: APT upgrade fails

**Symptom**:
```bash
$ sudo apt upgrade aide
# dpkg: error: unable to install new version
```

**Cause**: Immutable flag prevents package update

**Fix**: See TROUBLESHOOTING.md Issue #6

---

## Best Practices

1. **✅ Protect binaries**: Always set immutable flag on `/usr/bin/aide`
2. **✅ Protect config**: Set immutable flag on `/etc/aide/aide.conf`
3. **✅ Monitor status**: Use Prometheus metrics (check every 1h)
4. **✅ Alert on changes**: Set up Telegram/email alerts
5. **⚠️ Database protection**: Optional (AIDE needs to write updates)
6. **⚠️ Before APT upgrades**: Remove flag, upgrade, restore flag
7. **❌ Never leave unprotected**: After editing, always restore flag

---

## Integration Examples

### Ansible Playbook

```yaml
- name: Validate AIDE immutable flags
  hosts: all
  tasks:
    - name: Check AIDE binary immutable flag
      command: lsattr /usr/bin/aide
      register: aide_binary_attrs
      changed_when: false

    - name: Fail if not protected
      fail:
        msg: "AIDE binary is NOT protected!"
      when: "'i' not in aide_binary_attrs.stdout"
```

### Cron Job (Hourly Check)

```cron
# /etc/cron.d/aide-immutable-check
0 * * * * root /usr/local/bin/aide-immutable-metrics.sh
```

---

## See Also

- **IMMUTABLE_BINARY_PROTECTION.md** - Initial setup guide
- **TROUBLESHOOTING.md** - Common issues with immutable flags
- **MONITORING_AIDE_ACCESS.md** - Permission monitoring
- **BEST_PRACTICES.md** - Security guidelines
