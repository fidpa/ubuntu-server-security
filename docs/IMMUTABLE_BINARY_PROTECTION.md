# Immutable Binary Protection for AIDE

Prevent rootkits from replacing AIDE binaries using Linux immutable file attributes.

## Overview

**The Problem**: A sophisticated rootkit can replace `/usr/bin/aide` to hide its presence.

**The Solution**: Use `chattr +i` to make AIDE binary immutable - even root cannot modify it without first removing the immutable flag.

## How It Works

### Immutable Flag (`chattr +i`)

```bash
# Make file immutable
sudo chattr +i /usr/bin/aide

# Verify
lsattr /usr/bin/aide
# Output: ----i--------e----- /usr/bin/aide
```

**What immutable means**:
- ❌ Cannot be modified (even by root)
- ❌ Cannot be deleted
- ❌ Cannot be renamed
- ❌ Cannot create hard links to it

**Security benefit**: Rootkit must first remove immutable flag (requires CAP_LINUX_IMMUTABLE capability), which is more likely to be detected.

## Protection Scope

Protect these critical AIDE files:

```bash
# AIDE binary
sudo chattr +i /usr/bin/aide

# AIDE configuration
sudo chattr +i /etc/aide/aide.conf

# Optional: Drop-in configs
sudo chattr +i /etc/aide/aide.conf.d/*.conf
```

## Automated Protection

The `update-aide-db.sh` script handles immutable flags automatically:

```bash
# Before AIDE update: remove immutable flag
remove_immutable() {
    if lsattr "$file" | grep -q '\-i\-'; then
        chattr -i "$file"
    fi
}

# After AIDE update: restore immutable flag
restore_immutable() {
    chattr +i "$file"
}

# Trap ensures restoration even on error
trap 'restore_immutable "$AIDE_BINARY"' EXIT
```

**Workflow**:
1. Script removes immutable flag
2. AIDE runs (can write to database)
3. Script restores immutable flag (even on error via trap)

## APT Hook (Package Upgrades)

When upgrading AIDE package, APT needs to replace the binary.

### Option 1: Manual Unlock

```bash
# Before apt upgrade
sudo chattr -i /usr/bin/aide

# Upgrade
sudo apt upgrade aide

# After upgrade
sudo chattr +i /usr/bin/aide
```

### Option 2: APT Hook (Automated)

Create `/etc/apt/apt.conf.d/99-aide-unlock`:

```bash
# Unlock AIDE binary before package operations
DPkg::Pre-Install-Pkgs {
    "if [ -x /usr/bin/aide ]; then chattr -i /usr/bin/aide 2>/dev/null || true; fi";
};

# Re-lock after package operations
DPkg::Post-Invoke {
    "if [ -x /usr/bin/aide ]; then chattr +i /usr/bin/aide 2>/dev/null || true; fi";
};
```

**Test**:
```bash
# Dry-run upgrade
sudo apt install --simulate aide

# Verify unlock works
lsattr /usr/bin/aide
```

## Verification

### Check Immutable Status

```bash
# List all immutable files in /usr/bin
lsattr /usr/bin | grep '\-i\-'

# Check specific file
lsattr /usr/bin/aide
# Should show: ----i--------e----- /usr/bin/aide
```

### Test Protection

```bash
# Try to modify (should fail)
sudo echo "malicious" >> /usr/bin/aide
# Error: Operation not permitted

# Try to delete (should fail)
sudo rm /usr/bin/aide
# Error: Operation not permitted

# Try to rename (should fail)
sudo mv /usr/bin/aide /usr/bin/aide.bak
# Error: Operation not permitted
```

## Trade-offs

### Advantages

✅ **Defense in Depth**: Extra layer beyond file permissions
✅ **Rootkit Prevention**: Harder for rootkit to replace AIDE
✅ **Audit Trail**: Removing immutable flag is auditable (if auditd configured)
✅ **No Performance Impact**: Attribute check is fast

### Disadvantages

❌ **Package Upgrades**: Need APT hook or manual unlock
❌ **Recovery Complexity**: Harder to fix broken AIDE installation
❌ **Not Silver Bullet**: Skilled attacker can still remove flag

## Auditd Integration

Log when immutable flags are changed:

```bash
# /etc/audit/rules.d/99-aide.rules
-a always,exit -F arch=b64 -S ioctl -F a1=0x40086602 -F exe=/usr/bin/chattr -k aide_immutable_change
```

**Explanation**:
- `ioctl` syscall with `0x40086602` (FS_IOC_SETFLAGS) = chattr operation
- `-k aide_immutable_change` = Audit key for filtering

**Query audit logs**:
```bash
sudo ausearch -k aide_immutable_change
```

## Recovery

If AIDE is broken and you need to replace binary:

```bash
# Remove immutable flag
sudo chattr -i /usr/bin/aide

# Reinstall package
sudo apt install --reinstall aide

# Restore immutable flag
sudo chattr +i /usr/bin/aide
```

## Best Practices

### 1. Document Protected Files

Maintain list of immutable files:
```bash
# /etc/aide/immutable-files.txt
/usr/bin/aide
/etc/aide/aide.conf
/etc/aide/aide.conf.d/10-docker-excludes.conf
```

### 2. Verify After Updates

After any AIDE-related operation:
```bash
# Check immutable flags are restored
lsattr /usr/bin/aide /etc/aide/aide.conf
```

### 3. Monitor Flag Changes

Use auditd to alert on immutable flag changes (see above).

### 4. Combine with Other Protections

- ✅ AIDE monitoring (detects file changes)
- ✅ Immutable flags (prevents modification)
- ✅ AppArmor/SELinux (restricts process capabilities)
- ✅ Secure Boot (prevents boot-level tampering)

## Limitations

**What immutable DOES protect against**:
- Accidental deletion
- Simple file replacement attacks
- Unsophisticated rootkits

**What immutable DOES NOT protect against**:
- Kernel-level rootkits (can bypass immutable check)
- Attacks that first remove immutable flag
- Boot-level tampering (before OS loads)

**Recommendation**: Use immutable flags as **defense in depth**, not sole protection.

## See Also

- [SETUP.md](SETUP.md) - Initial AIDE configuration
- [BEST_PRACTICES.md](BEST_PRACTICES.md) - Production security recommendations
- [chattr man page](https://man7.org/linux/man-pages/man1/chattr.1.html)
