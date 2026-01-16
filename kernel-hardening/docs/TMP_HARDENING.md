# /tmp Partition Hardening

Secure `/tmp` filesystem configuration with `nodev`, `nosuid`, and `noexec` mount options.

## Overview

The `/tmp` directory is writable by all users and commonly exploited for privilege escalation attacks. Hardening `/tmp` with restrictive mount options prevents common attack vectors while maintaining system functionality.

## Security Benefits

### `nodev` - Block Device Files

Prevents creation of device files in `/tmp`:

```bash
# ❌ Without nodev - Attacker can create device files
mknod /tmp/evil_device b 1 1

# ✅ With nodev - Blocked
mknod /tmp/evil_device b 1 1
# Error: Operation not permitted
```

**Attack prevented:** Direct hardware access via crafted device files

### `nosuid` - Block SUID Escalation

Prevents SUID/SGID bit execution in `/tmp`:

```bash
# ❌ Without nosuid - SUID binaries execute with elevated privileges
cp /bin/bash /tmp/malicious_bash
chmod u+s /tmp/malicious_bash
/tmp/malicious_bash -p  # Runs as root!

# ✅ With nosuid - SUID bit ignored
/tmp/malicious_bash -p  # Runs as user (no escalation)
```

**Attack prevented:** Privilege escalation via malicious SUID binaries

### `noexec` - Block Binary Execution

Prevents direct binary execution in `/tmp`:

```bash
# ❌ Without noexec - Attacker can run arbitrary binaries
./tmp/malware

# ✅ With noexec - Execution blocked
./tmp/malware
# Error: Permission denied
```

**Attack prevented:** Malware execution, shellcode injection

## Implementation

### Method 1: tmpfs (Recommended)

Mount `/tmp` as tmpfs with security options:

```bash
# Edit /etc/fstab
sudo nano /etc/fstab
```

Add:
```bash
tmpfs /tmp tmpfs defaults,nodev,nosuid,noexec,mode=1777 0 0
```

**Advantages:**
- RAM-based (fast performance)
- Automatic cleanup on reboot
- Size-limited (prevents DoS)

### Method 2: Dedicated Partition

Create dedicated partition for `/tmp`:

```bash
# In /etc/fstab
/dev/sda5 /tmp ext4 defaults,nodev,nosuid,noexec 0 2
```

**Advantages:**
- Persistent across reboots
- Larger capacity than RAM
- Better for large temporary files

## Configuration

### Complete fstab Entry

```bash
tmpfs /tmp tmpfs defaults,nodev,nosuid,noexec,mode=1777 0 0
```

**Options explained:**
- `tmpfs` - Filesystem type (RAM-based)
- `/tmp` - Mount point
- `defaults` - Base mount options
- `nodev` - No device files
- `nosuid` - Ignore SUID/SGID bits
- `noexec` - No binary execution
- `mode=1777` - Sticky bit (users can only delete their own files)
- `0 0` - No dump, no fsck

### Apply Changes

```bash
# Remount /tmp with new options
sudo mount -o remount /tmp

# Or reboot for clean state
sudo reboot
```

### Verify Configuration

```bash
# Check mount options
mount | grep /tmp
# Expected: tmpfs on /tmp type tmpfs (rw,nosuid,nodev,noexec,relatime,inode64)

# Verify via findmnt
findmnt /tmp
# Shows: nodev,nosuid,noexec
```

## Testing Security

### Test 1: Device File Creation

```bash
# Should fail with "Operation not permitted"
mknod /tmp/test_device b 1 1
```

**Expected:** Operation blocked by `nodev`

### Test 2: SUID Escalation

```bash
# Copy SUID binary to /tmp
cp /bin/ping /tmp/test_suid
sudo chmod u+s /tmp/test_suid

# Execute - SUID should be ignored
/tmp/test_suid
# Should run as user, not root

# Cleanup
rm /tmp/test_suid
```

**Expected:** SUID bit ignored by `nosuid`

### Test 3: Binary Execution

```bash
# Create test binary
echo -e '#!/bin/bash\necho "Executed"' > /tmp/test_exec.sh
chmod +x /tmp/test_exec.sh

# Should fail
/tmp/test_exec.sh
# Error: Permission denied
```

**Expected:** Execution blocked by `noexec`

## Troubleshooting

### Scripts Won't Execute

**Symptom:**
```bash
./script.sh
# Error: Permission denied
```

**Cause:** `noexec` prevents direct execution

**Solutions:**

1. **Invoke interpreter explicitly:**
   ```bash
   bash /tmp/script.sh  # ✅ Works
   python3 /tmp/script.py  # ✅ Works
   ```

2. **Move to executable location:**
   ```bash
   cp /tmp/script.sh /home/user/
   chmod +x /home/user/script.sh
   ./home/user/script.sh  # ✅ Works
   ```

3. **Use different directory:**
   ```bash
   # Use ~/tmp or /var/tmp instead
   mkdir ~/tmp
   mv /tmp/script.sh ~/tmp/
   ~/tmp/script.sh  # ✅ Works
   ```

### Package Installations Fail

**Symptom:**
```bash
sudo apt install package
# Error: /tmp: cannot execute binaries
```

**Cause:** Some package scripts need execution in `/tmp`

**Temporary workaround:**
```bash
# Remount /tmp with exec for installation
sudo mount -o remount,exec /tmp

# Install package
sudo apt install package

# Restore noexec
sudo mount -o remount,noexec /tmp
```

**Permanent solution:**
```bash
# Configure apt to use different temp directory
sudo nano /etc/apt/apt.conf.d/50remount-tmp
```

Add:
```
DPkg::Pre-Install-Pkgs {"/usr/bin/mount -o remount,exec /tmp";};
DPkg::Post-Invoke {"/usr/bin/mount -o remount,noexec /tmp";};
```

### Temporary File Space Issues

**Symptom:**
```bash
# /tmp fills up (tmpfs size limit)
df -h /tmp
# /tmp: 100% full
```

**Solutions:**

1. **Increase tmpfs size:**
   ```bash
   sudo nano /etc/fstab
   # Change to: tmpfs /tmp tmpfs defaults,nodev,nosuid,noexec,size=4G 0 0
   sudo mount -o remount /tmp
   ```

2. **Use alternative directory:**
   ```bash
   export TMPDIR=/var/tmp  # Larger, persistent
   ```

## Size Configuration

### Default Size

tmpfs defaults to 50% of RAM:

```bash
# 16GB RAM = 8GB /tmp
# 32GB RAM = 16GB /tmp
```

### Custom Size

```bash
# In /etc/fstab
tmpfs /tmp tmpfs defaults,nodev,nosuid,noexec,size=2G 0 0
```

**Recommendations:**
- **Minimal servers:** 512M-1G
- **Development:** 2G-4G
- **Heavy usage:** 4G-8G

### Check Current Usage

```bash
df -h /tmp
du -sh /tmp/*
```

## Alternative: /var/tmp

`/var/tmp` is typically NOT hardened (allows execution):

```bash
# Check /var/tmp mount options
mount | grep /var/tmp
```

**Security consideration:**
- `/var/tmp` persists across reboots
- Often not mounted with `noexec`
- Can be attack vector if not hardened

**Harden /var/tmp:**
```bash
# In /etc/fstab
/dev/sda6 /var/tmp ext4 defaults,nodev,nosuid,noexec 0 2
```

## CIS Benchmark Compliance

This configuration addresses:

- **CIS 1.1.2:** Ensure /tmp is a separate partition
- **CIS 1.1.3:** Ensure nodev option set on /tmp
- **CIS 1.1.4:** Ensure nosuid option set on /tmp
- **CIS 1.1.5:** Ensure noexec option set on /tmp

**Verification:**
```bash
# Check all options present
mount | grep /tmp | grep nodev | grep nosuid | grep noexec
```

**Expected:** All three options shown

## Performance Considerations

### tmpfs Performance

**Advantages:**
- RAM-speed access (10-100x faster than disk)
- No disk I/O overhead
- Automatic cleanup

**Disadvantages:**
- Limited by available RAM
- Lost on reboot (not suitable for persistent data)
- Increases memory pressure

### Disk-based /tmp

**Advantages:**
- Larger capacity
- Persistent across reboots
- No RAM pressure

**Disadvantages:**
- Slower than tmpfs
- Disk wear (SSDs)
- Manual cleanup required

## Security Best Practices

### 1. Regular Cleanup

```bash
# Automated cleanup (systemd)
systemctl status systemd-tmpfiles-clean.timer

# Manual cleanup
sudo find /tmp -type f -atime +7 -delete
```

### 2. Monitor Usage

```bash
# Watch for suspicious activity
sudo ls -la /tmp
sudo lsof +D /tmp
```

### 3. Audit Access

```bash
# Audit /tmp modifications (with auditd)
sudo auditctl -w /tmp -p wa -k tmp_access
```

### 4. Restrict Sticky Bit

```bash
# Verify sticky bit
ls -ld /tmp
# Expected: drwxrwxrwt (t = sticky bit)
```

Sticky bit ensures users can only delete their own files in `/tmp`.

## Integration with Other Security Layers

### Combined with:

- **AIDE:** Monitors `/tmp` for unauthorized files
- **rkhunter:** Scans `/tmp` for rootkits
- **auditd:** Logs `/tmp` access events
- **AppArmor/SELinux:** Restricts `/tmp` write access per process

**Defense-in-depth:**
```
Layer 1: Mount Options (nodev,nosuid,noexec)
Layer 2: File Integrity (AIDE)
Layer 3: Rootkit Detection (rkhunter)
Layer 4: Access Logging (auditd)
Layer 5: MAC Policies (AppArmor)
```

## References

- [CIS Ubuntu Linux 24.04 Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux) - Section 1.1
- [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs-3.0.html) - /tmp specification
- [systemd tmpfiles.d](https://www.freedesktop.org/software/systemd/man/tmpfiles.d.html) - Cleanup configuration
- [mount(8) man page](https://man7.org/linux/man-pages/man8/mount.8.html) - Mount options reference
