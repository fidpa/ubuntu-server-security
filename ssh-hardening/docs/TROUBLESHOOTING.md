<!--
Copyright (c) 2025-2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# SSH Hardening - Troubleshooting Guide

Common issues, solutions, and SSH lockout recovery procedures.

## Quick Emergency Recovery

**⚠️ LOCKED OUT OF SSH?**

1. **If you still have one working SSH session**:
   ```bash
   # Revert hardening config
   sudo rm /etc/ssh/sshd_config.d/99-ssh-hardening.conf
   sudo systemctl restart ssh

   # Test from another terminal
   ssh your-server
   ```

2. **If completely locked out**:
   - Use console access (physical, VPS console, or rescue mode)
   - Boot into single-user mode or rescue mode
   - Remove: `/etc/ssh/sshd_config.d/99-ssh-hardening.conf`
   - Restart SSH: `systemctl restart ssh`

---

## Common Issues

### 1. Permission Denied (publickey)

**Symptom**:
```
Permission denied (publickey).
```

**Causes**:
1. SSH keys not configured
2. Wrong file permissions
3. Wrong username
4. Key type not accepted

**Debug**:
```bash
# Verbose SSH connection
ssh -vvv your-server

# Check auth log on server
sudo journalctl -u ssh -n 50 | grep "Failed\|Accepted"

# Verify authorized_keys exists
ls -la ~/.ssh/authorized_keys
```

**Solutions**:

**Solution 1**: Configure SSH keys
```bash
# On client:
ssh-copy-id your-server

# Or manually:
cat ~/.ssh/id_ed25519.pub | ssh your-server "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

**Solution 2**: Fix permissions
```bash
# On server:
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown -R $USER:$USER ~/.ssh
```

**Solution 3**: Check accepted key types
```bash
# On server:
sudo sshd -T | grep pubkeyacceptedkeytypes

# If your key type not listed, add to override:
echo "PubkeyAcceptedKeyTypes +rsa-sha2-512" | sudo tee /etc/ssh/sshd_config.d/50-custom.conf
sudo systemctl restart ssh
```

---

### 2. SSH Service Fails to Start

**Symptom**:
```
sudo systemctl status ssh
● ssh.service - OpenBSD Secure Shell server
   Loaded: loaded
   Active: failed
```

**Causes**:
1. Syntax error in config
2. Conflicting directives
3. Invalid value

**Debug**:
```bash
# Check syntax
sudo sshd -t
# Shows specific error

# Check systemd logs
sudo journalctl -u ssh -n 50 --no-pager

# Test config manually
sudo /usr/sbin/sshd -ddd
# Runs SSH in debug mode (foreground)
```

**Solutions**:

**Solution 1**: Fix syntax error
```bash
# Find error line
sudo sshd -t -f /etc/ssh/sshd_config.d/99-ssh-hardening.conf

# Edit config
sudo nano /etc/ssh/sshd_config.d/99-ssh-hardening.conf

# Test again
sudo sshd -t
```

**Solution 2**: Remove conflicting override
```bash
# List all configs
ls /etc/ssh/sshd_config.d/*.conf

# Remove problematic override
sudo rm /etc/ssh/sshd_config.d/[problematic-file].conf

# Restart
sudo systemctl restart ssh
```

---

### 3. "Host key verification failed"

**Symptom**:
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
```

**Cause**: Server host keys changed (after running `generate-hostkeys.sh` or re-install)

**Solution**:
```bash
# Remove old entry
ssh-keygen -R your-server

# Or remove specific IP
ssh-keygen -R 192.168.1.100

# Accept new fingerprint on next connection
ssh your-server
```

**Verify fingerprint** (on server):
```bash
# Show current fingerprint
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

---

### 4. X11 Forwarding Not Working

**Symptom**:
```bash
ssh -X your-server
# X11 forwarding request failed
```

**Causes**:
1. X11Forwarding disabled in config
2. X11UseLocalhost misconfigured
3. xauth not installed
4. DISPLAY variable not set

**Debug**:
```bash
# Check if X11 enabled
sudo sshd -T | grep x11forwarding

# Check xauth installed
which xauth

# Check DISPLAY variable
echo $DISPLAY
```

**Solutions**:

**Solution 1**: Enable X11 in override
```bash
# Deploy development override
sudo cp drop-ins/20-development.conf /etc/ssh/sshd_config.d/
sudo systemctl restart ssh
```

**Solution 2**: Install xauth
```bash
sudo apt update
sudo apt install xauth
```

**Solution 3**: Test X11
```bash
# Connect with X11
ssh -X your-server

# Test GUI app
xclock
# Should show clock window
```

---

### 5. TCP Port Forwarding Blocked

**Symptom**:
```bash
ssh -L 8080:localhost:80 your-server
# Warning: remote port forwarding failed
```

**Cause**: AllowTcpForwarding disabled (base config default)

**Solution**: Deploy gateway or development override
```bash
# For gateway (TCP forwarding)
sudo cp drop-ins/10-gateway.conf /etc/ssh/sshd_config.d/
sudo systemctl restart ssh

# Test
ssh -L 8080:localhost:80 your-server
curl http://localhost:8080
```

---

### 6. "Too many authentication failures"

**Symptom**:
```
Received disconnect from server: 2: Too many authentication failures
```

**Cause**: MaxAuthTries exceeded (set to 3)

**Solutions**:

**Solution 1**: Specify key explicitly
```bash
# Use specific key
ssh -i ~/.ssh/id_ed25519 your-server

# Or configure in ~/.ssh/config:
Host your-server
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

**Solution 2**: Temporarily increase MaxAuthTries (not recommended)
```bash
# On server (emergency only)
echo "MaxAuthTries 6" | sudo tee /etc/ssh/sshd_config.d/50-temp-maxauth.conf
sudo systemctl restart ssh

# Remove after fixing client config
sudo rm /etc/ssh/sshd_config.d/50-temp-maxauth.conf
sudo systemctl restart ssh
```

---

### 7. Connection Times Out

**Symptom**:
```bash
ssh your-server
# Connection timed out
```

**Causes**:
1. Firewall blocking SSH (port 22)
2. SSH not running
3. Wrong IP/hostname
4. Network issue

**Debug**:
```bash
# Check if port 22 open
nc -zv your-server 22

# Check SSH running (on server)
sudo systemctl status ssh

# Check firewall (on server)
sudo ufw status
sudo iptables -L -n | grep 22
```

**Solutions**:

**Solution 1**: Open firewall (on server)
```bash
sudo ufw allow 22/tcp
sudo ufw reload
```

**Solution 2**: Start SSH
```bash
sudo systemctl start ssh
sudo systemctl enable ssh
```

---

### 8. "sshd_config: line X: Bad configuration option"

**Symptom**:
```
/etc/ssh/sshd_config.d/99-ssh-hardening.conf: line 42: Bad configuration option: [option]
```

**Causes**:
1. Typo in directive name
2. Unsupported option (older OpenSSH version)
3. Wrong value format

**Solutions**:

**Solution 1**: Check OpenSSH version
```bash
ssh -V
# OpenSSH_8.2p1 Ubuntu-4ubuntu0.5, OpenSSL 1.1.1f  31 Mar 2020
```

**Solution 2**: Comment out unsupported option
```bash
sudo nano /etc/ssh/sshd_config.d/99-ssh-hardening.conf

# Find problematic line and comment:
# UnsupportedOption value

sudo systemctl restart ssh
```

**Solution 3**: Check syntax
```bash
sudo sshd -t -f /etc/ssh/sshd_config.d/99-ssh-hardening.conf
# Shows exact line number
```

---

## SSH Lockout Recovery

### Scenario 1: One Working Session

**Recovery**:
1. **Keep working session open** (don't close!)
2. Revert config:
   ```bash
   sudo rm /etc/ssh/sshd_config.d/99-ssh-hardening.conf
   sudo systemctl restart ssh
   ```
3. Test from new terminal:
   ```bash
   ssh your-server
   ```
4. If works, investigate issue and re-deploy correctly

---

### Scenario 2: Complete Lockout (Console Access Available)

**Recovery**:
1. Access console (physical, VPS console, or rescue mode)
2. Login as root or sudo user
3. Remove hardening config:
   ```bash
   rm /etc/ssh/sshd_config.d/99-ssh-hardening.conf
   systemctl restart ssh
   ```
4. Test SSH from remote:
   ```bash
   ssh your-server
   ```
5. If works, fix issue and re-deploy

---

### Scenario 3: Complete Lockout (No Console Access)

**Recovery**:
1. **Contact hosting provider** for console access
2. Or use **rescue mode** (VPS/cloud providers)
3. Mount system disk
4. Edit config:
   ```bash
   mount /dev/sda1 /mnt
   rm /mnt/etc/ssh/sshd_config.d/99-ssh-hardening.conf
   ```
5. Reboot into normal mode
6. SSH should work with default config

---

## Validation & Testing

### Pre-Deployment Validation

**Critical checks before deploying**:
```bash
# 1. Syntax check
sudo sshd -t
echo "Exit code: $?"  # Must be 0

# 2. Baseline compliance
./scripts/validate-sshd-config.sh --config /etc/ssh/sshd_config

# 3. Permission check
stat -c "%a %n" /etc/ssh/sshd_config.d/*.conf
# Should be 644

# 4. SSH keys configured
ls -la ~/.ssh/authorized_keys
# Should exist and not be empty

# 5. Test connection with key
ssh -o PreferredAuthentications=publickey localhost
# Should succeed
```

---

### Post-Deployment Testing

**Safe testing workflow**:
1. **Keep existing SSH session open**
2. **Deploy config** in that session
3. **Test new connection** from different terminal:
   ```bash
   ssh your-server
   ```
4. **If test fails**: Revert in existing session
   ```bash
   sudo rm /etc/ssh/sshd_config.d/99-ssh-hardening.conf
   sudo systemctl restart ssh
   ```

---

## Debugging Commands

### Check Active Configuration
```bash
# Show all active settings
sudo sshd -T

# Filter specific settings
sudo sshd -T | grep -E "(password|pubkey|permit|forwarding)"

# Check specific directive
sudo sshd -T | grep allowtcpforwarding
```

### Check Authentication Logs
```bash
# Recent auth attempts
sudo journalctl -u ssh -n 50

# Failed logins
sudo journalctl -u ssh | grep "Failed"

# Successful logins
sudo journalctl -u ssh | grep "Accepted"

# Real-time monitoring
sudo journalctl -u ssh -f
```

### Check File Permissions
```bash
# SSH config files
ls -la /etc/ssh/sshd_config*
ls -la /etc/ssh/sshd_config.d/

# User SSH directory
ls -la ~/.ssh/

# Authorized keys
ls -la ~/.ssh/authorized_keys
```

### Check SSH Service
```bash
# Status
sudo systemctl status ssh

# Is it running?
sudo systemctl is-active ssh

# Is it enabled?
sudo systemctl is-enabled ssh

# Restart
sudo systemctl restart ssh
```

---

## Common Error Messages

### "Permission denied, please try again."
- **Cause**: Password auth disabled, no SSH keys
- **Fix**: Configure SSH keys (`ssh-copy-id`)

### "Connection closed by remote host"
- **Cause**: MaxAuthTries exceeded, IP banned (fail2ban)
- **Fix**: Use correct key, check fail2ban (`sudo fail2ban-client status sshd`)

### "Port 22: Connection refused"
- **Cause**: SSH not running, firewall blocking
- **Fix**: Start SSH (`sudo systemctl start ssh`), open firewall

### "No supported authentication methods available"
- **Cause**: Client doesn't have accepted key type
- **Fix**: Generate Ed25519 key (`ssh-keygen -t ed25519`)

---

## Best Practices to Avoid Issues

1. **Always validate before restarting**: `sudo sshd -t`
2. **Always keep one session open** during testing
3. **Always backup config** before changes
4. **Test from multiple clients** (different OSes)
5. **Use console access** for initial deployment (if possible)
6. **Document custom changes** (comments in configs)
7. **Monitor auth logs** after deployment
8. **Have recovery plan** (console access, rescue mode)

---

## Getting Help

### Gather Diagnostic Info
```bash
# SSH version
ssh -V

# OpenSSH version
sudo sshd -V

# OS version
cat /etc/os-release

# Active config
sudo sshd -T

# Auth logs
sudo journalctl -u ssh -n 100 --no-pager

# File permissions
ls -la /etc/ssh/sshd_config*
ls -la ~/.ssh/
```

### Report Issue
Include in bug report:
- SSH version
- OS version
- Active config (`sshd -T`)
- Auth logs (last 50 lines)
- Exact error message
- Steps to reproduce

---

## See Also

- [SETUP.md](SETUP.md) - Deployment guide
- [CIS_CONTROLS.md](CIS_CONTROLS.md) - CIS Benchmark mapping
- [OVERRIDE_PATTERNS.md](OVERRIDE_PATTERNS.md) - Drop-in architecture
- [../drop-ins/README.md](../drop-ins/README.md) - Override use cases

---

**Version**: 1.0
**Last Updated**: 2026-01-04
