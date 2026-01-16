<!--
Copyright (c) 2025-2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# CIS Benchmark Controls - SSH Hardening

Complete mapping of CIS Ubuntu Benchmark SSH controls to configuration settings.

**Benchmark**: CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0
**Section**: 5.2 - Configure SSH Server

## Control Summary

This SSH hardening component implements **15+ CIS Benchmark controls** from section 5.2.

**Coverage**:
- ✅ Fully Implemented: 15 controls
- ⚠️ Partially Implemented (overrides): 3 controls
- ❌ Not Applicable: 2 controls

**Compliance Score**: **83% (15/18)**

---

## Implemented Controls

### 5.2.2 - Ensure SSH LogLevel is appropriate
**Status**: ✅ Fully Implemented

**Setting**:
```bash
LogLevel INFO
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 111)

**Rationale**: INFO level logs authentication attempts and failures without verbose debugging output. Balances security visibility with log volume.

**Verification**:
```bash
sudo sshd -T | grep loglevel
# Expected: loglevel INFO
```

---

### 5.2.3 - Ensure SSH X11Forwarding is disabled
**Status**: ⚠️ Partially Implemented (override available)

**Base Setting**:
```bash
X11Forwarding no
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 92)

**Override**: [../drop-ins/20-development.conf](../drop-ins/20-development.conf) enables X11 for development servers

**Rationale**: Disabled by default (security). Development servers can enable via drop-in for remote GUI applications.

**Verification**:
```bash
sudo sshd -T | grep x11forwarding
# Expected: x11forwarding no (base) or yes (with override)
```

---

### 5.2.4 - Ensure SSH X11UseLocalhost is enabled
**Status**: ✅ Fully Implemented (when X11 enabled)

**Setting**:
```bash
X11UseLocalhost yes
```

**Location**: [../drop-ins/20-development.conf](../drop-ins/20-development.conf) (line 23)

**Rationale**: If X11 forwarding is enabled, limit to localhost only (prevents remote connections to X11 display).

**Verification**:
```bash
sudo sshd -T | grep x11uselocalhost
# Expected: x11uselocalhost yes
```

---

### 5.2.5 - Ensure SSH MaxAuthTries is set to 3 or less
**Status**: ✅ Fully Implemented

**Setting**:
```bash
MaxAuthTries 3
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 79)

**Rationale**: Limits password guessing attempts. After 3 failures, connection is dropped. Prevents brute-force attacks.

**Verification**:
```bash
sudo sshd -T | grep maxauthtries
# Expected: maxauthtries 3
```

---

### 5.2.6 - Ensure SSH MaxSessions is set to 10 or less
**Status**: ✅ Fully Implemented

**Setting**:
```bash
MaxSessions 10
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 76)

**Rationale**: Limits concurrent sessions per connection. Prevents resource exhaustion.

**Verification**:
```bash
sudo sshd -T | grep maxsessions
# Expected: maxsessions 10
```

---

### 5.2.7 - Ensure SSH MaxStartups is configured
**Status**: ✅ Fully Implemented

**Setting**:
```bash
MaxStartups 3:50:10
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 82)

**Rationale**: Rate limits unauthenticated connections:
- Start dropping 50% of connections after 3 concurrent
- Drop 100% after 10 concurrent
- Prevents connection flooding attacks

**Verification**:
```bash
sudo sshd -T | grep maxstartups
# Expected: maxstartups 3:50:10
```

---

### 5.2.9 - Ensure SSH PermitEmptyPasswords is disabled
**Status**: ✅ Fully Implemented

**Setting**:
```bash
PermitEmptyPasswords no
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 35)

**Rationale**: Prevents authentication with empty passwords (critical security requirement).

**Verification**:
```bash
sudo sshd -T | grep permitemptypasswords
# Expected: permitemptypasswords no
```

---

### 5.2.10 - Ensure SSH PermitUserEnvironment is disabled
**Status**: ✅ Fully Implemented

**Setting**:
```bash
PermitUserEnvironment no
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 104)

**Rationale**: Prevents users from setting environment variables that could bypass security controls.

**Verification**:
```bash
sudo sshd -T | grep permituserenvironment
# Expected: permituserenvironment no
```

---

### 5.2.11 - Ensure SSH IgnoreRhosts is enabled
**Status**: ✅ Fully Implemented (implicit)

**Setting**: Default in OpenSSH 8.2+ (not explicitly configured)

**Rationale**: rhosts-based authentication is insecure and disabled by default in modern OpenSSH.

**Verification**:
```bash
sudo sshd -T | grep ignorerhosts
# Expected: ignorerhosts yes
```

---

### 5.2.12 - Ensure SSH PermitRootLogin is disabled
**Status**: ✅ Fully Implemented

**Setting**:
```bash
PermitRootLogin no
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 42)

**Rationale**: Root login disabled. Use sudo instead for privilege escalation (principle of least privilege).

**Verification**:
```bash
sudo sshd -T | grep permitrootlogin
# Expected: permitrootlogin no
```

---

### 5.2.13 - Ensure SSH HostbasedAuthentication is disabled
**Status**: ✅ Fully Implemented (implicit)

**Setting**: Default in OpenSSH 8.2+ (not explicitly configured)

**Rationale**: Host-based authentication is insecure and disabled by default.

**Verification**:
```bash
sudo sshd -T | grep hostbasedauthentication
# Expected: hostbasedauthentication no
```

---

### 5.2.14 - Ensure only strong Ciphers are used
**Status**: ✅ Fully Implemented

**Setting**:
```bash
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 59)

**Rationale**:
- Only modern AEAD ciphers (ChaCha20-Poly1305, AES-GCM) and CTR mode
- **NO CBC mode** (vulnerable to attacks)
- **NO 3DES, Blowfish, CAST** (weak ciphers)

**Verification**:
```bash
sudo sshd -T | grep ciphers
# Expected: No CBC, 3DES, Blowfish, or CAST ciphers
```

---

### 5.2.15 - Ensure only strong MAC algorithms are used
**Status**: ✅ Fully Implemented

**Setting**:
```bash
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 62)

**Rationale**:
- Only SHA-2 family (512-bit and 256-bit)
- Encrypt-then-MAC (ETM) variants preferred
- **NO MD5** (broken)
- **NO SHA-1** (deprecated)

**Verification**:
```bash
sudo sshd -T | grep macs
# Expected: Only SHA-2 MACs, no MD5 or SHA-1
```

---

### 5.2.16 - Ensure only strong Key Exchange algorithms are used
**Status**: ✅ Fully Implemented

**Setting**:
```bash
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 56)

**Rationale**:
- Curve25519 preferred (modern, fast, secure)
- ECDH with NIST curves (521, 384, 256)
- Diffie-Hellman group exchange with SHA-256
- **NO SHA-1 variants**

**Verification**:
```bash
sudo sshd -T | grep kexalgorithms
# Expected: Only modern kex algorithms, no SHA-1
```

---

### 5.2.17 - Ensure SSH LoginGraceTime is configured
**Status**: ✅ Fully Implemented

**Setting**:
```bash
LoginGraceTime 60
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 73)

**Rationale**: 60 seconds to authenticate before connection is dropped. Prevents resource exhaustion from hanging connections.

**Verification**:
```bash
sudo sshd -T | grep logingracetime
# Expected: logingracetime 60
```

---

### 5.2.18 - Ensure SSH ClientAliveInterval and ClientAliveCountMax are configured
**Status**: ✅ Fully Implemented

**Settings**:
```bash
ClientAliveInterval 300
ClientAliveCountMax 2
```

**Location**: [../sshd_config.template](../sshd_config.template) (lines 69-70)

**Rationale**:
- Idle timeout: 15 minutes (300 seconds)
- 2 keepalive probes before disconnect
- Total timeout: 10 minutes (300s × 2)
- Prevents orphaned connections

**Verification**:
```bash
sudo sshd -T | grep clientalive
# Expected:
# clientaliveinterval 300
# clientalivecountmax 2
```

---

## Additional Hardening (Beyond CIS)

These settings are not part of CIS Benchmark but enhance security:

### Modern Key Types (Ed25519 Preferred)

**Setting**:
```bash
PubkeyAcceptedKeyTypes ssh-ed25519,sk-ssh-ed25519@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,rsa-sha2-512,rsa-sha2-256
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 50)

**Rationale**: Ed25519 > ECDSA > RSA (in order of preference). Modern, fast, and secure.

---

### Password Authentication Disabled

**Setting**:
```bash
PasswordAuthentication no
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 23)

**Rationale**: Key-only authentication. Prevents brute-force password attacks completely.

---

### Strict Modes Enabled

**Setting**:
```bash
StrictModes yes
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 89)

**Rationale**: Checks file permissions on user's home directory, .ssh/, and authorized_keys before accepting login.

---

### Use Privilege Separation (Sandbox)

**Setting**:
```bash
UsePrivilegeSeparation sandbox
```

**Location**: [../sshd_config.template](../sshd_config.template) (line 118)

**Rationale**: Uses kernel sandbox (seccomp-bpf) to limit SSH process capabilities.

---

## Controls with Overrides (Relaxed for Functionality)

### 5.2.23 - Ensure SSH AllowTcpForwarding is disabled
**Status**: ⚠️ Partially Implemented

**Base Setting**:
```bash
AllowTcpForwarding no
```

**Overrides**:
- [10-gateway.conf](../drop-ins/10-gateway.conf): Sets to `yes` (needed for VPN, tunnels)
- [20-development.conf](../drop-ins/20-development.conf): Sets to `yes` (needed for Docker port access)

**Rationale**: Disabled by default for security. Gateway and development servers enable for specific use cases.

---

### 5.2.24 - Ensure SSH AllowAgentForwarding is disabled
**Status**: ⚠️ Partially Implemented

**Base Setting**:
```bash
AllowAgentForwarding no
```

**Override**:
- [20-development.conf](../drop-ins/20-development.conf): Sets to `yes` (needed for git SSH operations)

**Rationale**: Disabled by default. Development servers enable for git workflows with SSH agent.

---

### 5.2.25 - Ensure SSH AllowStreamLocalForwarding is disabled
**Status**: ⚠️ Partially Implemented

**Base Setting**: Implicit `no` (not configured)

**Override**:
- [10-gateway.conf](../drop-ins/10-gateway.conf): Sets to `yes` (needed for VPN tunnel access)

**Rationale**: Disabled by default. Gateway servers enable for VPN functionality.

---

## Verification Commands

### Full Config Audit
```bash
# Show all active SSH settings
sudo sshd -T

# Filter CIS-relevant settings
sudo sshd -T | grep -E "(loglevel|x11forwarding|maxauthtries|maxsessions|maxstartups|permitemptypasswords|permituserenvironment|permitrootlogin|ciphers|macs|kexalgorithms|logingracetime|clientalive)"
```

### CIS Compliance Check
```bash
# Run validation script
../scripts/validate-sshd-config.sh --config /etc/ssh/sshd_config

# Expected output:
# Checks passed: 15+/15+
# Warnings: 0-3 (depending on overrides)
# Errors: 0
```

### Manual Verification Checklist
```bash
# Check each control manually
sudo sshd -T | grep loglevel              # INFO
sudo sshd -T | grep x11forwarding         # no (or yes with override)
sudo sshd -T | grep maxauthtries          # 3
sudo sshd -T | grep maxsessions           # 10
sudo sshd -T | grep maxstartups           # 3:50:10
sudo sshd -T | grep permitemptypasswords  # no
sudo sshd -T | grep permituserenvironment # no
sudo sshd -T | grep permitrootlogin       # no
sudo sshd -T | grep ciphers               # No CBC/3DES/Blowfish
sudo sshd -T | grep macs                  # SHA-2 only
sudo sshd -T | grep kexalgorithms         # Modern only
sudo sshd -T | grep logingracetime        # 60
sudo sshd -T | grep clientaliveinterval   # 300
sudo sshd -T | grep clientalivecountmax   # 2
```

---

## Compliance Summary

| CIS Control | Status | Base Config | Override |
|-------------|--------|-------------|----------|
| 5.2.2 LogLevel | ✅ | INFO | - |
| 5.2.3 X11Forwarding | ⚠️ | no | yes (dev only) |
| 5.2.4 X11UseLocalhost | ✅ | yes | - |
| 5.2.5 MaxAuthTries | ✅ | 3 | - |
| 5.2.6 MaxSessions | ✅ | 10 | - |
| 5.2.7 MaxStartups | ✅ | 3:50:10 | - |
| 5.2.9 PermitEmptyPasswords | ✅ | no | - |
| 5.2.10 PermitUserEnvironment | ✅ | no | - |
| 5.2.11 IgnoreRhosts | ✅ | yes (implicit) | - |
| 5.2.12 PermitRootLogin | ✅ | no | - |
| 5.2.13 HostbasedAuth | ✅ | no (implicit) | - |
| 5.2.14 Ciphers | ✅ | Modern only | - |
| 5.2.15 MACs | ✅ | SHA-2 only | - |
| 5.2.16 KexAlgorithms | ✅ | Modern only | - |
| 5.2.17 LoginGraceTime | ✅ | 60 | - |
| 5.2.18 ClientAlive | ✅ | 300/2 | - |
| 5.2.23 AllowTcpForwarding | ⚠️ | no | yes (gateway/dev) |
| 5.2.24 AllowAgentForwarding | ⚠️ | no | yes (dev only) |

**Overall Compliance**: **83% (15/18 fully implemented)**

**Note**: Overrides intentionally relax specific controls for required functionality. Servers using only base config achieve 100% compliance.

---

## See Also

- [SETUP.md](SETUP.md) - Deployment guide
- [OVERRIDE_PATTERNS.md](OVERRIDE_PATTERNS.md) - Drop-in architecture
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
- [CIS Ubuntu Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux) - Official benchmark

---

**Version**: 1.0
**Benchmark**: CIS Ubuntu Linux 24.04 LTS v1.0.0
**Last Updated**: 2026-01-04
