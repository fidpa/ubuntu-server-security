# Boot Security Setup Guide

Complete setup guide for GRUB and UEFI boot password protection.

## Prerequisites

### 1. Root Password (MANDATORY)

Before setting GRUB password, ensure root has a password:

```bash
# Check if root password is set
sudo passwd -S root
# Output should show "P" (password set), not "L" (locked)

# If locked, set password
sudo passwd root
```

**Why this matters:** Emergency mode requires root password. Without it, you cannot recover if something goes wrong.

### 2. Required Packages

```bash
# Verify grub-mkpasswd-pbkdf2 is available
which grub-mkpasswd-pbkdf2

# If not found, install
sudo apt install grub-common
```

## Method 1: Automated Setup (Recommended)

### Using the Setup Script

```bash
# 1. Make script executable
chmod +x scripts/setup-grub-password.sh

# 2. Run with sudo
sudo ./scripts/setup-grub-password.sh

# 3. Follow interactive prompts:
#    - Enter GRUB password (twice)
#    - Confirm reboot
```

### What the Script Does

1. **Pre-flight check:** Verifies root password is set
2. **Backup:** Creates timestamped backup of `/etc/grub.d/40_custom`
3. **Hash generation:** Runs `grub-mkpasswd-pbkdf2` interactively
4. **Configuration:** Updates `/etc/grub.d/40_custom`
5. **GRUB update:** Runs `update-grub`
6. **Validation:** Triple-checks configuration is correct
7. **Reboot prompt:** Offers immediate reboot for testing

## Method 2: Manual Setup

### Step 1: Generate Password Hash

```bash
grub-mkpasswd-pbkdf2
```

Output:
```
Enter password:
Reenter password:
PBKDF2 hash of your password is grub.pbkdf2.sha512.10000.LONG_HASH_HERE
```

**Important:** Copy the ENTIRE hash starting with `grub.pbkdf2.sha512...`

### Step 2: Backup Current Config

```bash
sudo mkdir -p /etc/grub.d/backups
sudo cp /etc/grub.d/40_custom /etc/grub.d/backups/40_custom.$(date +%Y%m%d).bak
```

### Step 3: Add Password Configuration

```bash
sudo tee -a /etc/grub.d/40_custom > /dev/null << 'EOF'

# GRUB Boot Password Protection
set superusers="root"
password_pbkdf2 root YOUR_HASH_HERE
EOF
```

Replace `YOUR_HASH_HERE` with the hash from Step 1.

### Step 4: Update GRUB

```bash
sudo update-grub
```

### Step 5: Validate

```bash
# Check configuration exists
grep -E "superusers|password_pbkdf2" /etc/grub.d/40_custom

# Check it's in generated config
grep -E "superusers|password_pbkdf2" /boot/grub/grub.cfg
```

### Step 6: Reboot and Test

```bash
sudo reboot
```

At GRUB menu:
1. Press `e` to edit -> Should prompt for password
2. Press `c` for console -> Should prompt for password
3. Let boot proceed -> Should NOT prompt (unrestricted)

## UEFI Password Setup

UEFI password is set in BIOS/UEFI firmware. See [UEFI_PASSWORD.md](UEFI_PASSWORD.md) for vendor-specific instructions.

General steps:
1. Enter BIOS/UEFI (usually F2, F12, DEL during boot)
2. Navigate to Security section
3. Set Administrator/Supervisor password
4. Save and exit

## Troubleshooting

### "Invalid PBKDF2 Password" at Boot

**Cause:** Hash corruption or typo during copy-paste.

**Fix:**
```bash
# Boot from USB/recovery
mount /dev/sda2 /mnt  # Adjust device as needed

# Restore backup
cp /mnt/etc/grub.d/backups/40_custom.*.bak /mnt/etc/grub.d/40_custom

# Regenerate GRUB config
chroot /mnt update-grub
```

### Cannot Access Emergency Mode

**Cause:** Root password not set before GRUB password.

**Fix:**
```bash
# Boot from USB/recovery
mount /dev/sda2 /mnt

# Set root password
chroot /mnt passwd root
```

### Script Fails Pre-flight Check

**Cause:** Root password is locked.

**Fix:**
```bash
sudo passwd root
```

### GRUB Menu Not Showing

**Cause:** GRUB_TIMEOUT set to 0.

**Fix:**
```bash
# Edit /etc/default/grub
GRUB_TIMEOUT=5

# Update
sudo update-grub
```

## Security Considerations

### Password Storage

- Store GRUB password in a password manager (Vaultwarden, Bitwarden)
- Document for disaster recovery scenarios
- Do NOT store in plaintext files

### Hash Security

- PBKDF2-SHA512 with 10,000 iterations (default)
- Brute-force resistant but not unbreakable
- Use strong passwords (14+ characters, mixed case, numbers, symbols)

### Physical Security

GRUB password protects against:
- Casual unauthorized boot modification
- Recovery mode access without credentials
- Boot parameter tampering

Does NOT protect against:
- USB boot (use UEFI password)
- Disk removal (use LUKS encryption)
- Hardware keyloggers

## Rollback

To remove GRUB password protection:

```bash
# 1. Remove password lines from 40_custom
sudo nano /etc/grub.d/40_custom
# Delete: set superusers="root"
# Delete: password_pbkdf2 root ...

# 2. Update GRUB
sudo update-grub

# 3. Verify removal
grep password_pbkdf2 /boot/grub/grub.cfg  # Should return nothing
```
