# GRUB Password Configuration

Detailed guide for GRUB boot password protection using PBKDF2-SHA512.

## Overview

GRUB password protection prevents unauthorized modification of boot parameters and recovery mode access. This implementation uses industry-standard PBKDF2-SHA512 hashing with the `--unrestricted` flag for headless server compatibility.

## How It Works

### Password Hash Generation

```bash
grub-mkpasswd-pbkdf2
```

This generates a PBKDF2-SHA512 hash with 10,000 iterations:

```
grub.pbkdf2.sha512.10000.HASH_PART_1.HASH_PART_2
```

**Format breakdown:**
- `grub.pbkdf2.sha512` - Algorithm identifier
- `10000` - PBKDF2 iteration count
- Two long hexadecimal hash segments

### Configuration Location

GRUB password is configured in `/etc/grub.d/40_custom`:

```bash
#!/bin/sh
exec tail -n +3 $0

# GRUB Boot Password Protection
set superusers="root"
password_pbkdf2 root grub.pbkdf2.sha512.10000.YOUR_HASH
```

**Key directives:**
- `set superusers="root"` - Defines admin user for GRUB
- `password_pbkdf2 root HASH` - Associates hash with user

### Unrestricted Boot

The setup script adds `--unrestricted` to normal boot entries automatically via `update-grub`. This ensures:

```
menuentry 'Ubuntu' --unrestricted {
    # Normal boot - no password required
}

menuentry 'Advanced options' --users '' {
    # Recovery/advanced - password required
}
```

## Manual Configuration Steps

### 1. Generate Hash

```bash
grub-mkpasswd-pbkdf2
```

Enter password twice, copy the resulting hash.

### 2. Edit 40_custom

```bash
sudo nano /etc/grub.d/40_custom
```

Add at the end:

```bash
# GRUB Boot Password Protection
set superusers="root"
password_pbkdf2 root grub.pbkdf2.sha512.10000.PASTE_HASH_HERE
```

**Critical:** Ensure the hash is on a single line with no line breaks.

### 3. Update GRUB

```bash
sudo update-grub
```

This regenerates `/boot/grub/grub.cfg` with the password configuration.

### 4. Validate Configuration

```bash
# Check 40_custom has the config
grep -E "superusers|password_pbkdf2" /etc/grub.d/40_custom

# Check grub.cfg includes it
grep -E "superusers|password_pbkdf2" /boot/grub/grub.cfg

# Verify unrestricted flag
grep "menuentry.*--unrestricted" /boot/grub/grub.cfg
```

## What Gets Protected

### Password Required For:

1. **Boot Menu Editing** (press 'e' at GRUB)
2. **GRUB Console** (press 'c' at GRUB)
3. **Recovery Mode** (Advanced Options)
4. **Single User Mode**

### Password NOT Required For:

1. **Normal boot** (default entry)
2. **Automatic boot** (after timeout)
3. **Remote reboots** (headless-compatible)

## Security Considerations

### Hash Strength

- **Algorithm:** PBKDF2-SHA512
- **Iterations:** 10,000 (reasonable balance)
- **Attack surface:** Requires physical access + unlimited attempts
- **Recommendation:** Use strong password (14+ characters)

### Common Mistakes

**Typo in Hash:**
```bash
# ❌ WRONG - Typo in "pbkdf2"
password_pokdr2 root grub.pbkdf2...
```

**Result:** `error: invalid PBKDF2 password` at boot

**Hash with Line Breaks:**
```bash
# ❌ WRONG - Hash split across lines
password_pbkdf2 root grub.pbkdf2.sha512.10000.PART1.
PART2
```

**Result:** Hash not recognized

**Correct Format:**
```bash
# ✅ CORRECT - Single line, no breaks
password_pbkdf2 root grub.pbkdf2.sha512.10000.LONG_HASH_HERE
```

### Testing After Setup

**Critical:** Test immediately after setup!

1. **Test 1 - Edit Protection:**
   - Reboot
   - At GRUB menu, press 'e'
   - Should prompt: "Enter username:"
   - Enter: `root`
   - Should prompt: "Enter password:"
   - Enter GRUB password
   - Should allow editing

2. **Test 2 - Console Protection:**
   - At GRUB menu, press 'c'
   - Should prompt for authentication

3. **Test 3 - Normal Boot:**
   - Let GRUB menu timeout
   - Should boot normally without password

## Backup Strategy

### Automatic Backups

The setup script creates timestamped backups:

```
/etc/grub.d/backups/
├── 40_custom.20260106_150000.bak
├── 40_custom.20260106_160000.bak
└── 40_custom.20260106_170000.bak
```

### Manual Backup

```bash
sudo cp /etc/grub.d/40_custom /etc/grub.d/40_custom.bak
```

### Restore from Backup

```bash
sudo cp /etc/grub.d/backups/40_custom.TIMESTAMP.bak /etc/grub.d/40_custom
sudo update-grub
```

## Recovery Scenarios

### Scenario 1: Forgot GRUB Password

**Cannot access boot menu editing, but can boot normally.**

**Solution:**
1. Boot normally (unrestricted)
2. Login to system
3. Reset GRUB password:
   ```bash
   sudo grub-mkpasswd-pbkdf2  # Generate new hash
   sudo nano /etc/grub.d/40_custom  # Update hash
   sudo update-grub
   ```

### Scenario 2: Invalid Password Error

**Boot fails with "error: invalid PBKDF2 password".**

**Solution:**
1. Boot from USB/recovery media
2. Mount root filesystem:
   ```bash
   mount /dev/sda2 /mnt  # Adjust device
   ```
3. Restore backup:
   ```bash
   cp /mnt/etc/grub.d/backups/40_custom.*.bak /mnt/etc/grub.d/40_custom
   ```
4. Regenerate GRUB:
   ```bash
   chroot /mnt
   update-grub
   exit
   ```
5. Reboot

### Scenario 3: Locked Out Completely

**Cannot boot, forgot root password, GRUB password blocks recovery.**

**Solution:**
1. Boot from USB/recovery media
2. Mount root filesystem
3. Remove GRUB password:
   ```bash
   mount /dev/sda2 /mnt
   nano /mnt/etc/grub.d/40_custom
   # Delete password lines
   chroot /mnt
   update-grub
   exit
   ```
4. Reboot and login
5. Reset root password: `sudo passwd root`
6. Re-setup GRUB password correctly

## Advanced Topics

### Custom Username

Instead of `root`, use a custom username:

```bash
set superusers="admin"
password_pbkdf2 admin grub.pbkdf2.sha512.10000.HASH
```

### Multiple Users

```bash
set superusers="admin,backup"
password_pbkdf2 admin HASH1
password_pbkdf2 backup HASH2
```

### Menu-Specific Protection

Protect only specific menu entries:

```bash
menuentry 'Ubuntu' --unrestricted {
    # Anyone can boot this
}

menuentry 'Rescue Mode' --users admin {
    # Only admin can boot this
}
```

## CIS Benchmark Compliance

This configuration satisfies:

- **CIS 1.4.1:** Ensure bootloader password is set
  - ✅ PBKDF2 hash configured

- **CIS 1.4.2:** Ensure permissions on bootloader config are configured
  - ✅ `/boot/grub/grub.cfg` is 444 (read-only)

- **CIS 1.4.3:** Ensure authentication required for single user mode
  - ✅ Recovery mode requires GRUB password

## References

- [GNU GRUB Manual - Security](https://www.gnu.org/software/grub/manual/grub/html_node/Security.html)
- [Ubuntu GRUB2 Password Protection](https://help.ubuntu.com/community/Grub2/Passwords)
- [CIS Ubuntu Linux 24.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
