# Lynis Troubleshooting

Common issues and solutions for Lynis security auditing.

---

## Installation Issues

### Issue 1: `lynis: command not found`

**Symptom**:
```bash
$ lynis audit system
lynis: command not found
```

**Cause**: Lynis not installed or not in PATH.

**Solution**:
```bash
# Check if installed
dpkg -l | grep lynis

# If missing, install
sudo apt install lynis

# Verify path
which lynis  # Should show /usr/sbin/lynis
```

**Alternative**: Use full path:
```bash
/usr/sbin/lynis audit system
```

---

### Issue 2: Old Lynis Version

**Symptom**:
```bash
$ lynis show version
Lynis 3.0.8  # Ubuntu repo version (outdated)
```

**Cause**: Ubuntu repository lags behind CISOfy by 6-12 months.

**Solution**: Install from CISOfy repository.
```bash
# Remove old version
sudo apt remove lynis

# Add CISOfy repo
wget -O - https://packages.cisofy.com/keys/cisofy-software-public.key | sudo apt-key add -
echo "deb https://packages.cisofy.com/community/lynis/deb/ stable main" | sudo tee /etc/apt/sources.list.d/cisofy-lynis.list

# Install latest
sudo apt update
sudo apt install lynis

# Verify
lynis show version  # Should show 3.1.x+
```

---

## Permission Issues

### Issue 3: `Permission denied`

**Symptom**:
```bash
$ lynis audit system
ERROR: Insufficient permissions to perform audit
```

**Cause**: Lynis requires root privileges to read system files.

**Solution**:
```bash
# Use sudo
sudo lynis audit system
```

---

### Issue 4: Report File Not Readable

**Symptom**:
```bash
$ grep "hardening_index=" /var/log/lynis-report.dat
Permission denied
```

**Cause**: Report is root-owned (mode 640).

**Solution**:
```bash
# Read with sudo
sudo grep "hardening_index=" /var/log/lynis-report.dat

# Or change permissions (not recommended for production)
sudo chmod 644 /var/log/lynis-report.dat
```

---

## Audit Issues

### Issue 5: Low Hardening Index (<60)

**Symptom**:
```
Hardening index : 45 [#########           ]
```

**Cause**: Fresh Ubuntu install without hardening.

**Solution**: See [HARDENING_GUIDE.md](HARDENING_GUIDE.md) for top 20 recommendations.

**Quick wins**:
1. Legal banners (BANN-7126) → +2 points
2. Password aging (AUTH-9286) → +3 points
3. SSH hardening (SSH-7408) → +2 points

**Expected**: 60-70% achievable in <30 minutes.

---

### Issue 6: Too Many False-Positives

**Symptom**:
```
Warnings: 25
Suggestions: 120
```

**Cause**: Default tests include desktop/unused service checks.

**Solution**: Deploy custom profile.
```bash
# Copy template
sudo cp ../lynis-custom.prf.template /etc/lynis/custom.prf

# Edit for server type (web, database, Docker, dev)
sudo nano /etc/lynis/custom.prf

# Run audit with profile
sudo lynis audit system --profile /etc/lynis/custom.prf
```

See [CUSTOM_PROFILES.md](CUSTOM_PROFILES.md) for server-type profiles.

---

### Issue 7: Audit Takes Too Long (>5 minutes)

**Symptom**:
```bash
# Audit runs for 10+ minutes
sudo lynis audit system
```

**Cause**: All tests enabled (including slow network/filesystem checks).

**Solution**: Use `--quick` mode.
```bash
sudo lynis audit system --quick
```

**Trade-off**: Skips ~75 slow tests, completes in ~1 minute.

---

## Profile Issues

### Issue 8: Profile Not Found

**Symptom**:
```bash
$ sudo lynis audit system --profile /etc/lynis/custom.prf
ERROR: Profile not found: /etc/lynis/custom.prf
```

**Cause**: Profile file missing or path incorrect.

**Solution**:
```bash
# Check file exists
ls -la /etc/lynis/custom.prf

# If missing, copy template
sudo cp ../lynis-custom.prf.template /etc/lynis/custom.prf

# Verify permissions
sudo chmod 644 /etc/lynis/custom.prf
```

---

### Issue 9: Profile Syntax Errors

**Symptom**:
```bash
$ sudo lynis audit system --profile /etc/lynis/custom.prf
WARNING: Invalid profile syntax at line 15
```

**Cause**: Malformed profile (typo, incorrect format).

**Solution**: Validate profile.
```bash
# Automated validation
sudo ../scripts/validate-lynis-profile.sh /etc/lynis/custom.prf

# Manual check
sudo cat /etc/lynis/custom.prf | grep -n "^[^#]"  # Show non-comment lines
```

**Common mistakes**:
- Missing `=` in `skip-test` (use `skip-test=TEST-ID`, not `skip-test TEST-ID`)
- Missing `:` in `config` (use `config:key:value`, not `config key value`)
- Typo in test ID (e.g., `FILE-6130` instead of `FILE-6310`)

---

## Metrics Issues

### Issue 10: Metrics Not Updating in Prometheus

**Symptom**: Prometheus shows stale hardening index (1 week old).

**Cause**: Metrics exporter timer not running or failed.

**Solution**:
```bash
# Check timer status
sudo systemctl status lynis-metrics-exporter.timer

# Check service logs
sudo journalctl -u lynis-metrics-exporter.service -n 50

# Manual export
sudo /usr/local/bin/lynis-metrics-exporter.sh --run-audit

# Restart node_exporter (re-reads textfile collector)
sudo systemctl restart node_exporter
```

---

### Issue 11: Metrics File Permissions

**Symptom**: node_exporter cannot read `/var/lib/node_exporter/textfile_collector/lynis.prom`.

**Cause**: Metrics file created with wrong permissions (e.g., 600 instead of 644).

**Solution**:
```bash
# Fix permissions
sudo chmod 644 /var/lib/node_exporter/textfile_collector/lynis.prom

# Verify
ls -la /var/lib/node_exporter/textfile_collector/lynis.prom
# Expected: -rw-r--r-- 1 root root ...
```

---

## Systemd Issues

### Issue 12: Timer Not Running

**Symptom**:
```bash
$ sudo systemctl status lynis-audit.timer
● lynis-audit.timer - Weekly Lynis Security Audit
   Loaded: loaded
   Active: inactive (dead)
```

**Cause**: Timer not enabled or started.

**Solution**:
```bash
# Enable and start
sudo systemctl enable lynis-audit.timer
sudo systemctl start lynis-audit.timer

# Verify
sudo systemctl status lynis-audit.timer
# Expected: Active: active (waiting)
```

---

### Issue 13: Service Fails to Start

**Symptom**:
```bash
$ sudo systemctl status lynis-audit.service
● lynis-audit.service - Lynis Security Audit
   Active: failed (Result: exit-code)
```

**Cause**: Script path incorrect or Lynis not installed.

**Solution**:
```bash
# Check logs
sudo journalctl -u lynis-audit.service -n 50

# Verify script path in service file
sudo cat /etc/systemd/system/lynis-audit.service | grep ExecStart

# Verify Lynis installed
which lynis
```

---

## Report Parsing Issues

### Issue 14: Cannot Extract Hardening Index

**Symptom**:
```bash
$ grep "hardening_index=" /var/log/lynis-report.dat
(no output)
```

**Cause**: Audit didn't complete or report file corrupted.

**Solution**:
```bash
# Check if audit completed
tail /var/log/lynis.log

# Re-run audit
sudo lynis audit system

# Verify report
ls -la /var/log/lynis-report.dat
# Expected: Recent timestamp
```

---

### Issue 15: Report Contains Garbled Data

**Symptom**: Report file has binary data or incorrect format.

**Cause**: Concurrent audits or interrupted audit.

**Solution**:
```bash
# Remove corrupted report
sudo rm /var/log/lynis-report.dat /var/log/lynis.log

# Run fresh audit
sudo lynis audit system

# Verify format
head -n 20 /var/log/lynis-report.dat
# Expected: Lines like "hardening_index=75"
```

---

## Common Warnings Explained

### Warning: SSH Root Login Enabled

**Test ID**: SSH-7408

**Meaning**: Root user can login via SSH (security risk).

**Fix**: Disable root login.
```bash
echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd
```

---

### Warning: Password Aging Not Configured

**Test ID**: AUTH-9286

**Meaning**: Passwords never expire.

**Fix**: Set password aging.
```bash
sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t180/' /etc/login.defs
```

---

### Warning: No Legal Banners

**Test ID**: BANN-7126

**Meaning**: No authorization warnings on login.

**Fix**: Create legal banners.
```bash
sudo tee /etc/issue > /dev/null << 'EOF'
************************************
*   AUTHORIZED ACCESS ONLY         *
************************************
EOF

sudo tee /etc/issue.net > /dev/null << 'EOF'
************************************
*   AUTHORIZED ACCESS ONLY         *
************************************
EOF
```

---

## Getting Help

### Check Lynis Documentation

```bash
# Show help
lynis show help

# Show tests
lynis show tests

# Show license
lynis show license
```

### Community Support

- **Lynis Forum**: https://github.com/CISOfy/lynis/discussions
- **GitHub Issues**: https://github.com/CISOfy/lynis/issues
- **Documentation**: https://cisofy.com/lynis/

---

## See Also

- [SETUP.md](SETUP.md) - Installation & first audit
- [HARDENING_GUIDE.md](HARDENING_GUIDE.md) - Top 20 recommendations
- [CUSTOM_PROFILES.md](CUSTOM_PROFILES.md) - Reduce false-positives
- [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) - Metrics setup
