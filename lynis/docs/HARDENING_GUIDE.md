# Lynis Hardening Guide - Top 20 Recommendations

This guide provides prioritized, high-impact hardening recommendations based on production Ubuntu server hardening to 100% CIS Benchmark compliance.

**Source**: Real-world hardening session (NAS Server: 70% → 80% Hardening Index in 57 minutes, zero downtime).

## Quick Reference

| Priority | Test ID | Category | Impact | Effort | CIS Ref |
|----------|---------|----------|--------|--------|---------|
| 1 | BANN-7126 | Legal Banners | HIGH | LOW | 1.7.1.x |
| 2 | AUTH-9286 | Password Aging | HIGH | LOW | 5.4.1.1 |
| 3 | SSH-7408 | SSH Hardening | HIGH | LOW | 5.2.x |
| 4 | KRNL-6000 | Kernel Hardening | HIGH | LOW | 3.2.x |
| 5 | ACCT-9622 | Process Accounting | MEDIUM | LOW | 4.1.x |
| 6 | PKGS-7381 | Security Packages | MEDIUM | LOW | Various |
| 7 | NETW-3200 | Protocol Blacklist | MEDIUM | LOW | 3.4.x |
| 8 | AUTH-9282 | Password Hash | MEDIUM | LOW | 5.3.4 |
| 9 | AUTH-9328 | Umask Settings | MEDIUM | LOW | 5.4.4 |
| 10 | KRNL-5830 | Core Dumps | MEDIUM | LOW | 1.5.1 |

**Strategy**: Start with Priority 1-5 (fastest ROI), then 6-10 (defense-in-depth).

---

## Priority 1: Legal Banners (BANN-7126)

### Problem
No authorization warnings displayed on login (legal liability).

### Risk Level
**HIGH** - Non-compliance with many security frameworks (PCI-DSS, HIPAA, ISO 27001).

### One-Liner Fix

```bash
# /etc/issue (console login)
sudo tee /etc/issue > /dev/null << 'EOF'
************************************
*   AUTHORIZED ACCESS ONLY         *
*   All activity is monitored      *
************************************
EOF

# /etc/issue.net (SSH login)
sudo tee /etc/issue.net > /dev/null << 'EOF'
************************************
*   AUTHORIZED ACCESS ONLY         *
*   All activity is monitored      *
************************************
EOF
```

### Verification

```bash
cat /etc/issue /etc/issue.net
```

### CIS Benchmark
- 1.7.1.1 - Ensure message of the day is configured properly
- 1.7.1.2 - Ensure local login warning banner is configured properly
- 1.7.1.3 - Ensure remote login warning banner is configured properly

---

## Priority 2: Password Aging (AUTH-9286)

### Problem
Passwords never expire (`PASS_MAX_DAYS 99999`).

### Risk Level
**HIGH** - Compromised credentials remain valid indefinitely.

### One-Liner Fix

```bash
# Set password aging to 180 days
sudo sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t180/' /etc/login.defs
```

### Verification

```bash
grep "^PASS_MAX_DAYS" /etc/login.defs
# Expected: PASS_MAX_DAYS	180
```

### CIS Benchmark
- 5.4.1.1 - Ensure password expiration is 365 days or less

**Note**: 180 days balances security with usability (SSH key-based auth reduces password exposure).

---

## Priority 3: SSH Hardening (SSH-7408)

### Problem
`TCPKeepAlive yes` enables session hijacking vulnerability.

### Risk Level
**HIGH** - Active sessions can be hijacked via TCP-level attacks.

### One-Liner Fix

```bash
# Disable TCP keepalive (use SSH-level instead)
echo "TCPKeepAlive no" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Verification

```bash
sshd -T | grep tcpkeepalive
# Expected: tcpkeepalive no
```

### CIS Benchmark
- 5.2.15 - Ensure SSH Keep Alive settings are configured

**Related**: See `ssh-hardening/` component for comprehensive SSH hardening.

---

## Priority 4: Kernel Hardening (KRNL-6000)

### Problem
Missing kernel security parameters (filesystem protection, pointer obfuscation, network security).

### Risk Level
**HIGH** - Exposes system to privilege escalation and network attacks.

### One-Liner Fix

```bash
sudo tee /etc/sysctl.d/99-lynis-hardening.conf > /dev/null << 'EOF'
# Filesystem Protection
fs.protected_fifos = 2
fs.protected_regular = 2

# Kernel Pointer Obfuscation
kernel.kptr_restrict = 2

# Network Security
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
EOF

sudo sysctl --system
```

### Verification

```bash
sysctl fs.protected_fifos fs.protected_regular kernel.kptr_restrict net.ipv4.conf.all.log_martians
```

### CIS Benchmark
- 3.2.x - Network parameters

**Related**: See `kernel-hardening/` component for comprehensive kernel hardening.

---

## Priority 5: Process Accounting (ACCT-9622)

### Problem
No audit trail for process execution (forensics gap).

### Risk Level
**MEDIUM** - Cannot trace attacker actions post-breach.

### One-Liner Fix

```bash
# Install process accounting
sudo apt install -y acct sysstat

# Enable services
sudo systemctl enable acct.service sysstat.service
sudo systemctl start acct.service sysstat.service
```

### Verification

```bash
systemctl is-active acct sysstat
# Expected: active (both)

# View process accounting
sudo lastcomm | head -n 10
```

### CIS Benchmark
- 4.1.1.2 - Ensure system accounting is enabled

---

## Priority 6: Security Packages (PKGS-7381)

### Problem
Missing defense-in-depth packages.

### Risk Level
**MEDIUM** - Lack of additional security layers.

### One-Liner Fix

```bash
sudo apt install -y libpam-tmpdir libpam-pwquality debsums apt-show-versions apt-listchanges
```

**Package Purposes**:
- `libpam-tmpdir` - Per-user /tmp directories (isolation)
- `libpam-pwquality` - Password complexity enforcement
- `debsums` - Package integrity verification
- `apt-show-versions` - Upgrade tracking
- `apt-listchanges` - Upgrade notifications

### Verification

```bash
dpkg -l | grep -E "libpam-tmpdir|libpam-pwquality|debsums"
```

---

## Priority 7: Protocol Blacklist (NETW-3200)

### Problem
Unused network protocols loaded (attack surface expansion).

### Risk Level
**MEDIUM** - Exploitable protocols even if not actively used.

### One-Liner Fix

```bash
sudo tee /etc/modprobe.d/disable-unused-protocols.conf > /dev/null << 'EOF'
# Disable unused network protocols
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
EOF
```

### Verification

```bash
lsmod | grep -E "dccp|sctp|rds|tipc"
# Expected: no output (modules not loaded)
```

### CIS Benchmark
- 3.4.1 - Ensure DCCP is disabled
- 3.4.2 - Ensure SCTP is disabled
- 3.4.3 - Ensure RDS is disabled
- 3.4.4 - Ensure TIPC is disabled

---

## Priority 8: Password Hash Rounds (AUTH-9282)

### Problem
Default SHA512 rounds (5000) too low for brute-force resistance.

### Risk Level
**MEDIUM** - Offline password cracking easier.

### One-Liner Fix

```bash
# Increase SHA512 rounds to 10000 (doubles computational cost)
sudo sed -i 's/^# SHA_CRYPT_MIN_ROUNDS.*/SHA_CRYPT_MIN_ROUNDS\t10000/' /etc/login.defs
sudo sed -i 's/^# SHA_CRYPT_MAX_ROUNDS.*/SHA_CRYPT_MAX_ROUNDS\t10000/' /etc/login.defs
```

### Verification

```bash
grep "SHA_CRYPT" /etc/login.defs
```

### CIS Benchmark
- 5.3.4 - Ensure password hashing algorithm is SHA-512

---

## Priority 9: Umask Settings (AUTH-9328)

### Problem
Default umask 022 creates world-readable files.

### Risk Level
**MEDIUM** - Information disclosure risk.

### One-Liner Fix

```bash
# Set umask to 027 (remove world-readable)
sudo sed -i 's/^UMASK.*/UMASK\t\t027/' /etc/login.defs
```

### Verification

```bash
grep "^UMASK" /etc/login.defs
# Expected: UMASK		027
```

### CIS Benchmark
- 5.4.4 - Ensure default user umask is configured

---

## Priority 10: Core Dumps (KRNL-5830)

### Problem
Core dumps enabled (memory disclosure risk).

### Risk Level
**MEDIUM** - Sensitive data (passwords, keys) leak to disk.

### One-Liner Fix

```bash
# Disable core dumps globally
echo "* hard core 0" | sudo tee -a /etc/security/limits.conf
```

### Verification

```bash
grep "core" /etc/security/limits.conf
# Expected: * hard core 0
```

### CIS Benchmark
- 1.5.1 - Ensure core dumps are restricted

---

## Priorities 11-20 (Quick Reference)

| Priority | Test ID | Fix Summary | Impact |
|----------|---------|-------------|--------|
| 11 | FILE-6310 | Disable X11 forwarding | MEDIUM |
| 12 | PKGS-7392 | Enable auto-update notifications | LOW |
| 13 | MAIL-8818 | Disable mail server (if unused) | LOW |
| 14 | KRNL-5788 | Enable kernel address space randomization | MEDIUM |
| 15 | NETW-3001 | Disable IPv6 (if unused) | LOW |
| 16 | AUTH-9308 | Configure account lockout | MEDIUM |
| 17 | FILE-6344 | Set sticky bit on /tmp | MEDIUM |
| 18 | FIRE-4512 | Enable firewall (ufw/nftables) | HIGH |
| 19 | STRG-1846 | Enable filesystem quotas | LOW |
| 20 | BOOT-5122 | Set bootloader password | HIGH |

See Lynis report for detailed recommendations on tests 11-20.

---

## Production Results

**Real-world validation** (Ubuntu 24.04 LTS NAS Server):

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Hardening Index | 70% | 80% | +14.3% |
| Security Score | 98/100 | 101/100 | +3.1% |
| Warnings | 2 | 1 | -50% |
| Suggestions | 48 | 38 | -21% |

**Time Investment**: 57 minutes (10 changes)
**Downtime**: 0 minutes (SSH restart only)

---

## Implementation Strategy

### Phase 1: Quick Wins (15 minutes)
1. Legal Banners (BANN-7126)
2. Password Aging (AUTH-9286)
3. SSH Hardening (SSH-7408)

**Expected**: +5-8 Hardening Index points

### Phase 2: Defense-in-Depth (30 minutes)
4. Kernel Hardening (KRNL-6000)
5. Process Accounting (ACCT-9622)
6. Security Packages (PKGS-7381)
7. Protocol Blacklist (NETW-3200)

**Expected**: +3-5 Hardening Index points

### Phase 3: Comprehensive (15 minutes)
8-10. Password Hash, Umask, Core Dumps

**Expected**: +2-3 Hardening Index points

---

## Next Steps

1. **Baseline Audit**: `sudo lynis audit system` (capture current score)
2. **Implement Phase 1**: Legal Banners + Password + SSH (15 min)
3. **Re-audit**: Verify improvements
4. **Implement Phase 2**: Kernel + Accounting + Packages (30 min)
5. **Final Audit**: Confirm 70%+ Hardening Index

**Target**: 70-80% Hardening Index achievable in <1 hour

---

## See Also

- [SETUP.md](SETUP.md) - Installation & first audit
- [CUSTOM_PROFILES.md](CUSTOM_PROFILES.md) - Reduce false-positives
- [PROMETHEUS_INTEGRATION.md](PROMETHEUS_INTEGRATION.md) - Track hardening over time
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
