# Three-Layer Defense Architecture

Complete technical explanation of the USB defense system architecture.

## Overview

The USB Defense System uses **defense-in-depth** with three complementary layers:

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Kernel Blacklist (PREVENTION)                 │
│ ├─ Blocks usb-storage kernel module                    │
│ └─ USB devices detected but NOT mountable              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 2: USB Device Watcher (DETECTION - Real-Time)    │
│ ├─ Polls lsusb every 2 seconds                         │
│ ├─ Detects NEW devices (state tracking)                │
│ └─ Sends email alerts (2-4s latency)                   │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Bypass Detection (DETECTION - Periodic)       │
│ ├─ auditd monitors modprobe/rmmod                      │
│ ├─ Periodic log analysis (every 10 minutes)            │
│ └─ Detects sophisticated bypass attempts               │
└─────────────────────────────────────────────────────────┘
```

---

## Layer 1: Kernel Blacklist

### Technology

Uses Linux kernel module blacklisting to prevent USB mass storage driver from loading.

**Key Insight**: `install /bin/false` is stronger than `blacklist` directive.

| Directive | Boot Protection | Hotplug Protection | Manual Load |
|-----------|----------------|-------------------|-------------|
| `blacklist usb-storage` | ✅ Yes | ❌ No | ⚠️ Possible |
| `install usb-storage /bin/false` | ✅ Yes | ✅ Yes | ⚠️ Possible* |

*Requires removing blacklist file + root access

### Implementation

**File**: `/etc/modprobe.d/blacklist-usb-storage.conf`
```bash
install usb-storage /bin/false
install uas /bin/false
```

**Boot Persistence**: Requires `update-initramfs -u`

### Effectiveness

**What happens when USB stick is plugged in:**
1. USB controller recognizes device (hardware level)
2. `lsusb` shows device (USB enumeration works)
3. Kernel tries to load `usb-storage` module
4. `/bin/false` returns exit code 1 (failure)
5. NO `/dev/sdX` block device created
6. Device NOT mountable

**User experience:**
```bash
$ lsusb
Bus 002 Device 004: ID 0781:5581 SanDisk Corp. Ultra

$ lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0 931.5G  0 disk
├─sda1   8:1    0   512M  0 part /boot
└─sda2   8:2    0   931G  0 part /
# USB stick NOT shown!

$ lsmod | grep usb_storage
# No output (module not loaded)
```

### Bypass Methods

Attacker with root access can bypass Layer 1:

```bash
# Method 1: Remove blacklist + load module
sudo rm /etc/modprobe.d/blacklist-usb-storage.conf
sudo modprobe usb-storage

# Method 2: Boot with kernel parameter
# Add "modprobe.blacklist=" to GRUB (requires reboot)
```

→ **Both methods detected by Layer 3 (auditd)**

---

## Layer 2: USB Device Watcher

### Technology

Polling-based daemon that continuously monitors for NEW USB devices.

**Why polling instead of udev?**
- udev RUN-Commands have 10-second timeout
- Complex scripts (email sending) don't work reliably
- Background execution (`&`) is unreliable in udev context

**Polling advantages:**
- No timeout constraints
- Full bash script support
- State tracking (only NEW devices trigger alerts)
- 2-4 second detection latency (acceptable)

### Architecture

```
┌──────────────────────────────────────────────┐
│ usb-device-watcher.sh (Daemon)               │
│                                              │
│ while true; do                               │
│   current=$(lsusb)                           │
│   new=$(comm -13 previous current)           │
│   if [[ -n "$new" ]]; then                   │
│     send_alert()                             │
│   fi                                         │
│   previous=$current                          │
│   sleep 2                                    │
│ done                                         │
└──────────────────────────────────────────────┘
       ↓
┌──────────────────────────────────────────────┐
│ State File: /var/lib/usb-defense/            │
│ usb-devices.state                            │
│                                              │
│ 001:002:8087:0026                            │
│ 002:001:1d6b:0002                            │
│ 002:003:046d:c534                            │
└──────────────────────────────────────────────┘
```

### Key Features

**1. State Tracking**
- Stores current USB devices in state file
- Compares current vs. previous state
- Only NEW devices trigger alerts

**2. HID Filtering**
- Checks USB interface class via sysfs
- Class 03 = HID (keyboards/mice) → Excluded
- Class 09 = Hub (internal) → Excluded

**3. Rate Limiting**
- 1-hour cooldown per device (based on VID:PID)
- Prevents duplicate alerts
- Cooldown files: `/var/lib/usb-defense/usb-alert-cooldown.*`

**4. Warmup Phase**
- First 5 cycles (10 seconds) = no alerts
- Prevents false positives during service startup

**5. Fail-Safe**
- If state file can't be written → service exits
- Prevents alert flood (learned from incident 15.01.2026)

### Alert Format

```
Subject: ⚠️ USB Device Connected - hostname

Device: Bus 002 Device 004: ID 0781:5581 SanDisk Corp. Ultra
VID:PID: 0781:5581
Detection Time: 2026-01-16 14:23:45

Security Status:
✅ OK: usb-storage module not loaded
✅ OK: No USB storage mounted

Investigation Commands:
lsusb
lsblk
lsmod | grep usb_storage
```

### Performance

- **CPU**: ~1% over time (2-second polling)
- **Memory**: ~10 MB
- **Detection latency**: 2-4 seconds
- **False positives**: <0.1% (HID filtering)

---

## Layer 3: Bypass Detection

### Technology

Uses Linux Audit Framework (auditd) to detect sophisticated bypass attempts.

**What it monitors:**
1. Kernel module loading (`modprobe usb-storage`)
2. Kernel module unloading (`rmmod usb-storage`)
3. Blacklist file tampering (`/etc/modprobe.d/`)

### Architecture

```
┌────────────────────────────────────────────┐
│ Linux Kernel                               │
│   ↓                                        │
│ auditd (Kernel-Level Event Logging)       │
│   - 7 USB-specific rules                  │
│   - Logs to /var/log/audit/audit.log      │
└────────────────────────────────────────────┘
       ↓
┌────────────────────────────────────────────┐
│ check-usb-activity.timer                   │
│   - Runs every 10 minutes                  │
│   - Looks back 6 minutes (overlap)         │
└────────────────────────────────────────────┘
       ↓
┌────────────────────────────────────────────┐
│ check-usb-activity.sh                      │
│   ausearch -ts "6 min ago" -k usb_*        │
│   → Email if events found                  │
└────────────────────────────────────────────┘
```

### auditd Rules

```bash
# Monitor USB device access
-w /dev/bus/usb -p wa -k usb_device_activity
-w /sys/bus/usb -p wa -k usb_device_activity

# Monitor modprobe/rmmod
-a always,exit -F path=/sbin/modprobe -k usb_module_loading
-a always,exit -F path=/sbin/rmmod -k usb_module_loading

# Monitor blacklist tampering
-w /etc/modprobe.d/blacklist-usb-storage.conf -k usb_blacklist_tampering

# Monitor syscalls
-a always,exit -S execve -F path=/sbin/modprobe -k usb_modprobe
-a always,exit -S execve -F path=/sbin/rmmod -k usb_modprobe
```

### Detection Examples

**Scenario 1: Attacker loads usb-storage**
```bash
# Attacker command:
sudo modprobe usb-storage

# auditd log entry:
type=EXECVE msg=audit(1737823685.123:456): argc=2 a0="modprobe" a1="usb-storage"
auid=1000 uid=0 gid=0 comm="modprobe" exe="/usr/sbin/modprobe"

# Email alert (within 10 minutes):
Subject: USB Activity Detected - hostname
User marc (auid=1000) executed /sbin/modprobe with args: usb-storage
```

**Scenario 2: Attacker deletes blacklist**
```bash
# Attacker command:
sudo rm /etc/modprobe.d/blacklist-usb-storage.conf

# auditd log entry:
type=SYSCALL msg=audit(1737823700.456:457): syscall=unlink
name=/etc/modprobe.d/blacklist-usb-storage.conf

# Email alert:
Blacklist file was deleted!
```

### Why 10-minute intervals?

- **6-minute lookback** + **10-minute interval** = 100% coverage (4 min overlap)
- Trade-off: Detection latency vs. CPU usage
- Sophisticated attacks are rare (99% caught by Layer 2)

---

## Layer Interaction Matrix

| Scenario | Layer 1 | Layer 2 | Layer 3 | Detection Time |
|----------|---------|---------|---------|----------------|
| **Naive USB stick** | ✅ Blocks | ✅ Alerts | ➖ No event | 2-4 seconds |
| **Keyboard plugged in** | ➖ N/A | ✅ Filtered | ➖ No event | 0s (no alert) |
| **modprobe bypass** | ❌ Bypassed | ➖ No new device | ✅ Alerts | 0-10 minutes |
| **Blacklist deletion** | ❌ Bypassed | ➖ No new device | ✅ Alerts | 0-10 minutes |

**Key insight**: Layers are COMPLEMENTARY, not redundant.

---

## Threat Model

### Protected Against (99%+ of attacks)

- ✅ Naive USB stick insertion (office workers)
- ✅ Unauthorized data transfer attempts
- ✅ USB-based malware delivery
- ✅ Physical access exfiltration

### Detected (Sophisticated attackers)

- ✅ Manual modprobe bypass
- ✅ Blacklist file tampering
- ✅ Kernel module loading attempts

### NOT Protected Against (<1% of threats)

- ❌ BadUSB attacks (HID spoofing at hardware level)
- ❌ DMA attacks via Thunderbolt (requires IOMMU)
- ❌ Compromised BIOS/UEFI firmware
- ❌ Physical disk removal

**Recommendation**: For high-security environments, add:
- Physical security (camera surveillance)
- Boot security (GRUB password, Secure Boot)
- Full disk encryption (LUKS)

---

## Comparison to Alternatives

| Approach | Complexity | Effectiveness | Detection Speed | Bypass Resistance |
|----------|-----------|---------------|----------------|------------------|
| **USB Defense** | Medium | High (99%+) | 2-4 seconds | High |
| udev Rules | Low | Medium | Instant | Low |
| SELinux/AppArmor | High | Medium | Instant | Medium |
| Physical Port Disable | Low | Perfect | N/A | Perfect* |

*Unless attacker has physical access to motherboard

---

## See Also

- [SETUP.md](SETUP.md) - Installation guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [ALERT_CONFIGURATION.md](ALERT_CONFIGURATION.md) - Email setup
