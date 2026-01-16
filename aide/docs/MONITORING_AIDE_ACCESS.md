# Monitoring AIDE Access

## Overview

AIDE database security requires proper access control and monitoring. This guide covers permission setup, access validation, and audit logging for AIDE components.

## _aide Group Setup

### Why Use a Dedicated Group?

**Problem**: AIDE runs as root, but monitoring tools need read access to `/var/lib/aide/aide.db`.

**Solution**: Use `_aide` group with proper permissions (640/750).

### Create _aide Group

```bash
# 1. Create system group
sudo groupadd --system _aide

# 2. Add monitoring user
sudo usermod -aG _aide monitoring-user

# 3. Verify
getent group _aide
# Expected: _aide:x:999:monitoring-user
```

### Apply Permissions

```bash
# 1. AIDE database directory
sudo chown root:_aide /var/lib/aide
sudo chmod 750 /var/lib/aide

# 2. AIDE database file
sudo chown root:_aide /var/lib/aide/aide.db
sudo chmod 640 /var/lib/aide/aide.db

# 3. Verify
ls -ld /var/lib/aide
# Expected: drwxr-x--- root _aide

ls -l /var/lib/aide/aide.db
# Expected: -rw-r----- root _aide
```

---

## Permission Validation

### Manual Check

```bash
# 1. Check directory permissions
stat -c '%a %U:%G' /var/lib/aide
# Expected: 750 root:_aide

# 2. Check database permissions
stat -c '%a %U:%G' /var/lib/aide/aide.db
# Expected: 640 root:_aide

# 3. Test read access
sudo -u monitoring-user test -r /var/lib/aide/aide.db && echo "✅ Readable" || echo "❌ NOT readable"
```

### Automated Validation Script

**File**: `/usr/local/bin/validate-aide-permissions.sh`

```bash
#!/bin/bash
# Validates AIDE permissions for monitoring access

set -euo pipefail

AIDE_DIR="/var/lib/aide"
AIDE_DB="${AIDE_DIR}/aide.db"
AIDE_GROUP="_aide"
MONITORING_USER="${1:-monitoring-user}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== AIDE Permission Validation ==="
echo "Monitoring User: ${MONITORING_USER}"
echo ""

# Check 1: _aide group exists
if getent group "${AIDE_GROUP}" >/dev/null; then
    echo -e "${GREEN}✅ Group ${AIDE_GROUP} exists${NC}"
else
    echo -e "${RED}❌ Group ${AIDE_GROUP} does NOT exist${NC}"
    exit 1
fi

# Check 2: User is in _aide group
if groups "${MONITORING_USER}" | grep -q "${AIDE_GROUP}"; then
    echo -e "${GREEN}✅ User ${MONITORING_USER} is in ${AIDE_GROUP} group${NC}"
else
    echo -e "${RED}❌ User ${MONITORING_USER} is NOT in ${AIDE_GROUP} group${NC}"
    echo "   Fix: sudo usermod -aG ${AIDE_GROUP} ${MONITORING_USER}"
    exit 1
fi

# Check 3: Directory permissions (750)
DIR_PERMS=$(stat -c '%a' "${AIDE_DIR}")
DIR_OWNER=$(stat -c '%U:%G' "${AIDE_DIR}")
if [[ "${DIR_PERMS}" == "750" && "${DIR_OWNER}" == "root:${AIDE_GROUP}" ]]; then
    echo -e "${GREEN}✅ Directory permissions: ${DIR_PERMS} ${DIR_OWNER}${NC}"
else
    echo -e "${RED}❌ Directory permissions: ${DIR_PERMS} ${DIR_OWNER} (expected: 750 root:${AIDE_GROUP})${NC}"
    exit 1
fi

# Check 4: Database permissions (640)
if [[ -f "${AIDE_DB}" ]]; then
    DB_PERMS=$(stat -c '%a' "${AIDE_DB}")
    DB_OWNER=$(stat -c '%U:%G' "${AIDE_DB}")
    if [[ "${DB_PERMS}" == "640" && "${DB_OWNER}" == "root:${AIDE_GROUP}" ]]; then
        echo -e "${GREEN}✅ Database permissions: ${DB_PERMS} ${DB_OWNER}${NC}"
    else
        echo -e "${RED}❌ Database permissions: ${DB_PERMS} ${DB_OWNER} (expected: 640 root:${AIDE_GROUP})${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Database does not exist: ${AIDE_DB}${NC}"
fi

# Check 5: Read access test
if sudo -u "${MONITORING_USER}" test -r "${AIDE_DB}" 2>/dev/null; then
    echo -e "${GREEN}✅ Read access test PASSED${NC}"
else
    echo -e "${RED}❌ Read access test FAILED${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== All validation checks PASSED ===${NC}"
exit 0
```

**Usage**:
```bash
# Test with specific user
./validate-aide-permissions.sh monitoring-user

# Test with current user
./validate-aide-permissions.sh $USER
```

---

## Access Control Best Practices

### 1. Principle of Least Privilege

**✅ DO**:
- Use `_aide` group for read-only monitoring
- Keep database owner as `root`
- Restrict write access to AIDE update script only

**❌ DON'T**:
- Give monitoring users write access to database
- Use world-readable permissions (644)
- Run monitoring tools as root

### 2. Group Membership Management

```bash
# Add user to group
sudo usermod -aG _aide monitoring-user

# Remove user from group
sudo deluser monitoring-user _aide

# List all group members
getent group _aide | cut -d: -f4
```

### 3. ACL Alternative (Advanced)

If `_aide` group is too restrictive, use ACLs:

```bash
# Grant specific user read access
sudo setfacl -m u:monitoring-user:r /var/lib/aide/aide.db

# Verify ACL
getfacl /var/lib/aide/aide.db

# List ACL-enabled files
getfacl -R /var/lib/aide
```

---

## Audit Logging

### auditd Integration

Track who accesses AIDE database:

```bash
# 1. Install auditd
sudo apt install auditd

# 2. Add audit rule
sudo auditctl -w /var/lib/aide/aide.db -p r -k aide_access

# 3. Verify rule
sudo auditctl -l | grep aide

# 4. Check access logs
sudo ausearch -k aide_access -ts recent
```

**Permanent Rule** (`/etc/audit/rules.d/aide.rules`):
```
# Audit AIDE database access
-w /var/lib/aide/aide.db -p r -k aide_access
-w /var/lib/aide/aide.db -p w -k aide_modification
```

### systemd Journal Integration

Monitor AIDE service execution:

```bash
# Show all AIDE service starts
journalctl -u aide-update.service | grep "Started"

# Show database access patterns
journalctl -u aide-update.service | grep "aide.db"

# Export to syslog
journalctl -u aide-update.service --since="1 hour ago" --output=syslog
```

---

## Monitoring Metrics

### Prometheus Exporter

Expose AIDE permissions as metrics:

```bash
# File: aide-permissions-metrics.sh
#!/bin/bash
METRICS_FILE="/var/lib/node_exporter/textfile_collector/aide_permissions.prom"

# Check if _aide group exists
if getent group _aide >/dev/null; then
    echo "aide_group_exists 1" > "${METRICS_FILE}"
else
    echo "aide_group_exists 0" > "${METRICS_FILE}"
fi

# Check database permissions
DB_PERMS=$(stat -c '%a' /var/lib/aide/aide.db 2>/dev/null || echo "0")
echo "aide_database_permissions ${DB_PERMS}" >> "${METRICS_FILE}"

# Check if monitoring user can read
if sudo -u monitoring-user test -r /var/lib/aide/aide.db 2>/dev/null; then
    echo "aide_monitoring_access 1" >> "${METRICS_FILE}"
else
    echo "aide_monitoring_access 0" >> "${METRICS_FILE}"
fi
```

**Prometheus Alerts**:
```yaml
# Alert if monitoring cannot access AIDE database
- alert: AideMonitoringAccessLost
  expr: aide_monitoring_access == 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Monitoring lost access to AIDE database"
```

---

## Troubleshooting Access Issues

### Issue 1: "Permission denied" when reading aide.db

**Symptoms**:
```bash
$ cat /var/lib/aide/aide.db
cat: /var/lib/aide/aide.db: Permission denied
```

**Diagnosis**:
```bash
# Check current user groups
groups

# Check if _aide is listed
getent group _aide | grep $USER
```

**Fix**:
```bash
# Add user to _aide group
sudo usermod -aG _aide $USER

# Log out and log back in (or use newgrp)
newgrp _aide

# Verify access
test -r /var/lib/aide/aide.db && echo "✅ Success"
```

### Issue 2: Group membership not effective

**Symptoms**: User is in `_aide` group but still cannot access database.

**Cause**: Need to re-login for group changes to take effect.

**Fix**:
```bash
# Option 1: Use newgrp (current shell only)
newgrp _aide

# Option 2: Use sg (single command)
sg _aide -c 'cat /var/lib/aide/aide.db'

# Option 3: Re-login (permanent)
exit
# SSH back in
```

### Issue 3: Directory permissions block access

**Symptoms**: File is readable but directory is not executable.

**Diagnosis**:
```bash
ls -ld /var/lib/aide
# Expected: drwxr-x--- (750)
# Wrong:    drwx------ (700) ← Blocks group access!
```

**Fix**:
```bash
sudo chmod 750 /var/lib/aide
```

---

## Security Considerations

### 1. AIDE Database Contains Sensitive Info

**What's in aide.db**:
- Complete file listing of system
- File hashes (can reveal installed software)
- Permissions and ownership data

**Risk**: Database exposure → reconnaissance for attackers

**Mitigation**:
- Keep 640 permissions (not 644)
- Limit `_aide` group membership
- Monitor access via auditd

### 2. Write Access Must Be Restricted

**Only** these processes should write to `/var/lib/aide/`:
- AIDE binary (`/usr/bin/aide`)
- Update scripts (`update-aide-db.sh`)

**Never** allow:
- Manual edits by users
- Automated tools (backups, monitoring) writing to directory
- Network-accessible services

### 3. Immutable Flag Protection

Combine with immutable flag for maximum security:

```bash
# After setting permissions
sudo chattr +i /var/lib/aide/aide.db

# Verify
lsattr /var/lib/aide/aide.db | grep '^----i'
```

---

## See Also

- **SETUP.md** - Initial AIDE installation
- **TROUBLESHOOTING.md** - Common permission issues
- **BEST_PRACTICES.md** - Security guidelines
- **AIDE_BINARY_VALIDATION.md** - Immutable flag monitoring
