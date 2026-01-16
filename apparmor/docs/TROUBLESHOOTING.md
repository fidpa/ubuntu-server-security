# AppArmor Troubleshooting Guide

Common issues and solutions when deploying AppArmor profiles.

## Diagnostic Commands

```bash
# Overall status
sudo aa-status

# Recent violations
sudo dmesg | grep -i apparmor | tail -30

# Syslog violations
grep -i apparmor /var/log/syslog | tail -30

# Profile-specific issues
sudo aa-status | grep postgresql
```

## Common Issues

### 1. Service Won't Start After ENFORCE Mode

**Symptom**: Service fails to start, logs show "Permission denied"

**Diagnosis**:
```bash
sudo dmesg | grep -i "apparmor.*DENIED" | tail -20
```

**Solution**:
```bash
# Step 1: Switch to COMPLAIN mode
sudo aa-complain /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres

# Step 2: Restart service
sudo systemctl restart postgresql@16-main

# Step 3: Identify missing paths from logs
sudo dmesg | grep -i apparmor | grep postgresql

# Step 4: Add missing paths to profile
sudo nano /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres

# Step 5: Reload and test
sudo apparmor_parser -r /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
```

---

### 2. Extensions Won't Load

**Symptom**: `CREATE EXTENSION` fails with "could not load library"

**Diagnosis**:
```bash
sudo dmesg | grep -i "apparmor.*\.so"
```

**Solution**: Add extension library path to profile:
```
/usr/lib/postgresql/16/lib/*.so mr,
/usr/share/postgresql/16/extension/** r,
```

---

### 3. SSL Certificates Not Accessible

**Symptom**: "SSL error: certificate file not found"

**Solution**: Add SSL paths to profile:
```
/etc/ssl/certs/** r,
/etc/ssl/private/** r,
/etc/letsencrypt/live/** r,
/etc/letsencrypt/archive/** r,
```

---

### 4. Custom Data Directory Not Accessible

**Symptom**: PostgreSQL can't access tablespace or custom data path

**Solution**: Add custom path to profile:
```
/custom/path/to/data/** rwk,
```

---

### 5. Profile Syntax Error

**Symptom**: `apparmor_parser` fails with syntax error

**Diagnosis**:
```bash
sudo apparmor_parser -p /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
```

**Common Causes**:
- Missing comma at end of rule
- Missing `r`, `w`, `x` permissions
- Invalid path pattern
- Missing closing brace

**Example Fix**:
```
# Wrong
/var/log/postgresql/**

# Correct
/var/log/postgresql/** rw,
```

---

### 6. Profile Not Loading After Reboot

**Symptom**: Profile disappears after reboot

**Diagnosis**:
```bash
ls -la /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
```

**Solutions**:
1. Ensure profile is in `/etc/apparmor.d/`
2. Check permissions: `chmod 644 <profile>`
3. Verify AppArmor service: `systemctl status apparmor`

---

### 7. Docker Containers Blocked

**Symptom**: AppArmor blocking Docker container operations

**Note**: Docker has its own `docker-default` profile. Host profiles shouldn't interfere.

**Diagnosis**:
```bash
docker inspect --format='{{.AppArmorProfile}}' <container>
sudo aa-status | grep docker
```

**Solution**: Docker manages its own AppArmor profiles. Don't apply host profiles to containerized services.

---

### 8. Too Many Violations in COMPLAIN Mode

**Symptom**: Hundreds of `ALLOWED` messages in logs

**Solution**: This is normal during testing. Focus on unique paths:
```bash
sudo dmesg | grep -i "apparmor.*ALLOWED" | \
  grep -oP 'name="[^"]*"' | sort | uniq -c | sort -rn | head -20
```

---

## Using aa-logprof

`aa-logprof` can automatically suggest profile updates based on logged violations:

```bash
# Run after COMPLAIN mode testing
sudo aa-logprof

# Follow prompts to:
# - Allow (A) - Add rule to profile
# - Deny (D) - Explicitly deny
# - Glob (G) - Use wildcard pattern
# - Inherit (I) - Inherit from parent
```

**Best Practice**: Review suggestions before accepting. Don't blindly allow everything.

---

## Emergency Recovery

### Complete Profile Removal

If a profile completely breaks a service:

```bash
# 1. Boot with AppArmor disabled (if needed)
# Add apparmor=0 to kernel parameters in GRUB

# 2. Or from running system
sudo aa-disable /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
sudo systemctl restart postgresql@16-main

# 3. Remove profile
sudo rm /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
```

### Disable AppArmor Entirely (Last Resort)

```bash
sudo systemctl stop apparmor
sudo systemctl disable apparmor
```

**Warning**: This removes all AppArmor protection. Only use for debugging.

---

## Logging Configuration

### Increase Log Verbosity

Edit `/etc/apparmor/logprof.conf`:
```ini
[settings]
logfiles = /var/log/syslog /var/log/messages /var/log/audit/audit.log
```

### Audit Mode (Maximum Logging)

```bash
# Enable audit mode for profile
sudo aa-audit /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres
```

---

## Getting Help

1. **Check logs first**: Most issues are visible in `dmesg` or syslog
2. **Use COMPLAIN mode**: Test before ENFORCE
3. **Start minimal**: Add permissions incrementally
4. **Document changes**: Track what you add to profiles

### Useful Resources

- [Ubuntu AppArmor Wiki](https://wiki.ubuntu.com/AppArmor)
- [AppArmor Documentation](https://gitlab.com/apparmor/apparmor/-/wikis/home)
- `man apparmor.d` - Profile syntax reference
- `man aa-status` - Status command reference
