# UEFI/BIOS Password Configuration

Multi-vendor guide for setting UEFI/BIOS administrator passwords.

## Overview

UEFI/BIOS password provides the first layer of boot security by protecting firmware settings and preventing unauthorized boot device changes. This complements GRUB password protection for defense-in-depth.

## What It Protects

### With UEFI Password:

- ✅ Blocks BIOS/UEFI settings access
- ✅ Prevents boot device order changes
- ✅ Blocks USB boot attacks
- ✅ Prevents firmware downgrades
- ✅ Protects Secure Boot settings

### Does NOT Protect:

- ❌ Normal boot process (unless explicitly configured)
- ❌ Disk encryption (use LUKS for that)
- ❌ Operating system access (use user passwords for that)

## Password Types

### Supervisor/Administrator Password

**Protects:** All BIOS/UEFI settings
**Recommendation:** Set this first
**Use case:** Full administrative control

### User/Power-On Password

**Protects:** System boot (blocks POST)
**Recommendation:** Only for high-security scenarios
**Warning:** Can prevent remote reboots and server recovery

### HDD/SSD Password

**Protects:** Drive access at firmware level
**Recommendation:** Only if no LUKS encryption
**Warning:** Lost password = lost data (no recovery)

## Vendor-Specific Instructions

### ASRock (DeskMini, Mini-PC Series)

**Example Hardware:** ASRock DeskMini X600

1. **Enter UEFI:**
   - Press `F2` or `DEL` during boot
   - Look for "Press F2 to enter Setup" message

2. **Navigate to Security:**
   - Use arrow keys to navigate to "Security" tab
   - Or search for "Administrator Password"

3. **Set Password:**
   - Select "Administrator Password"
   - Press Enter
   - Enter password twice
   - Password requirements: Usually 8-20 characters

4. **Save and Exit:**
   - Press `F10` to save
   - Confirm: "Save configuration changes and exit?"
   - System will reboot

5. **Verify:**
   - On next boot, enter UEFI again (F2/DEL)
   - Should prompt for Administrator password

### Dell (OptiPlex, PowerEdge, Latitude)

**Example Hardware:** Dell Latitude, OptiPlex Micro

1. **Enter BIOS:**
   - Press `F2` during Dell logo
   - Or `F12` → "BIOS Setup"

2. **Navigate to Security:**
   - Click "Security" in left menu
   - Or navigate with arrow keys

3. **Set Admin Password:**
   - Select "Admin Password"
   - Enter new password
   - Re-enter to confirm
   - Password requirements: 4-32 characters

4. **Optional - System Password:**
   - "System Password" blocks boot (not recommended for servers)

5. **Save:**
   - Click "Apply" then "Exit"
   - Or press `F10`

6. **Verify:**
   - Re-enter BIOS
   - Should prompt for Admin password

### HP (ProLiant, EliteDesk, ProBook)

**Example Hardware:** HP EliteDesk 800 G6

1. **Enter BIOS:**
   - Press `F10` during boot
   - Or `ESC` then `F10`

2. **Navigate to Security:**
   - Use arrow keys to "Security" menu
   - Or "Advanced" → "Security"

3. **Set Administrator Password:**
   - Select "Setup Password" or "Administrator Password"
   - Enter password
   - Confirm password
   - Password requirements: 8-32 characters

4. **Save:**
   - Press `F10` to save and exit
   - Confirm with `Yes`

5. **Verify:**
   - Enter BIOS again
   - Should prompt for password

### Lenovo (ThinkPad, ThinkCentre, ThinkStation)

**Example Hardware:** Lenovo ThinkCentre M720q

1. **Enter BIOS:**
   - Press `F1` during Lenovo logo
   - Or `Enter` then `F1`

2. **Navigate to Security:**
   - Use arrow keys to "Security" tab
   - Or "Config" → "Security"

3. **Set Supervisor Password:**
   - Select "Password" → "Supervisor Password"
   - Press Enter
   - Enter password twice
   - Password requirements: 5-128 characters

4. **Optional Settings:**
   - "Power-On Password" - Blocks boot
   - "Hard Disk Password" - Locks drive

5. **Save:**
   - Press `F10`
   - Confirm: "Setup Confirmation - Save configuration?"

6. **Verify:**
   - Re-enter BIOS
   - Should prompt for Supervisor password

## General Setup Steps (Any Vendor)

### Step 1: Prepare

- Ensure system has AC power (not just battery)
- Have password ready (write it down temporarily)
- Close all applications before reboot

### Step 2: Enter UEFI/BIOS

Common keys:
- `F2` - Most systems (ASUS, ASRock, Acer)
- `F10` - HP systems
- `F1` - Lenovo ThinkPad/ThinkCentre
- `DEL` - Desktop motherboards
- `F12` → "BIOS Setup" - Dell systems
- `ESC` then `F10` - Some HP systems

**Tip:** Watch boot screen for "Press X to enter Setup" message.

### Step 3: Find Security Menu

Common locations:
- "Security" tab (top menu)
- "Advanced" → "Security"
- "Configuration" → "Security"
- Search for "Password" or "Administrator"

### Step 4: Set Password

1. Select "Administrator Password" or "Supervisor Password"
2. Press Enter
3. Enter password twice
4. Confirm with Enter or OK

### Step 5: Save and Exit

- Press `F10` (most systems)
- Or select "Save Changes and Exit"
- Confirm when prompted

### Step 6: Verify

- Reboot
- Enter UEFI/BIOS again
- Should prompt for password before entry

## Password Best Practices

### Length and Complexity

- **Minimum:** 12 characters
- **Recommended:** 14-16 characters
- **Include:** Uppercase, lowercase, numbers, symbols (if supported)

### Example Strong Password

```
Uefi!Secure#2026$Boot
```

**Why strong?**
- 21 characters
- Mixed case
- Numbers and symbols
- Not dictionary word

### Storage

**Do NOT:**
- Store in BIOS notes field
- Write on sticky note on case
- Save in plaintext file

**Do:**
- Use password manager (Vaultwarden, Bitwarden)
- Store in encrypted vault
- Document in secure disaster recovery plan
- Consider printed copy in safe

## Recovery Scenarios

### Forgot UEFI Password

**Consequences:**
- Cannot access BIOS/UEFI settings
- Cannot change boot device
- System still boots normally

**Solutions (Ordered by Difficulty):**

1. **Contact Manufacturer Support:**
   - Some vendors provide master passwords
   - Requires proof of ownership

2. **CMOS Reset (Desktop):**
   - Power off system
   - Disconnect AC power
   - Remove CMOS battery (usually CR2032)
   - Wait 5-10 minutes
   - Replace battery
   - Password cleared, but BIOS settings reset

3. **CMOS Jumper Reset:**
   - Some motherboards have CLR_CMOS jumper
   - Move jumper to clear position
   - Wait 10 seconds
   - Move back to original position

4. **Service Center (Laptops):**
   - Laptops often store passwords in security chip
   - Cannot be reset by CMOS battery removal
   - Requires service center intervention

## Security Considerations

### Physical Security First

UEFI password is meaningless without physical security:

- ✅ Lock server room
- ✅ Secure rack access
- ✅ Monitor physical access logs
- ✅ Use security cameras

### Threat Model

**UEFI Password Defends Against:**
- Casual unauthorized access
- Quick boot device changes
- Settings tampering

**Does NOT Defend Against:**
- Sophisticated attackers with tools
- Firmware exploits (SPI flash programmer)
- Evil maid attacks (need LUKS + Secure Boot)

### Integration with GRUB Password

**Defense-in-Depth Strategy:**

```
Layer 1: Physical Security (lock rack)
Layer 2: UEFI Password (blocks firmware)
Layer 3: GRUB Password (blocks boot modification)
Layer 4: LUKS Encryption (protects data)
Layer 5: User Authentication (OS access)
```

## Troubleshooting

### Cannot Enter BIOS

**Try:**
- Different function keys (F2, F10, F1, DEL)
- Press key repeatedly during boot
- Check if Fast Boot disabled in OS
- Disconnect USB devices (some block BIOS access)

### Password Not Accepted

**Possible Causes:**
- Caps Lock enabled
- Numlock state different from when set
- Keyboard layout changed (DE vs US)
- Typo when setting password

**Solution:**
- Reset CMOS (if accessible)
- Contact manufacturer

### System Won't Boot After Setting Password

**Rare Issue:** Power-On Password set instead of Admin Password

**Solution:**
- Enter password at boot prompt
- Re-enter BIOS and disable Power-On Password

## Vendor-Specific Resources

- **ASRock:** https://www.asrock.com/support/
- **Dell:** https://www.dell.com/support/kbdoc/en-us/000134308/bios-passwords
- **HP:** https://support.hp.com/us-en/document/c03493994
- **Lenovo:** https://support.lenovo.com/us/en/solutions/ht036206

## CIS Benchmark

UEFI password addresses:

- **CIS 1.4.1:** Bootloader protection (firmware level)
- **CIS 1.6.1:** Physical access controls
- **Custom control:** Firmware tampering prevention
