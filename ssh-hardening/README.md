# SSH Hardening

Production-ready SSH hardening with 15+ CIS Benchmark controls and drop-in overrides.

## Features

- ✅ **Key-Only Authentication** - Password authentication disabled
- ✅ **Ed25519 Preferred** - Modern cryptography with RSA fallback
- ✅ **CIS Benchmark Compliance** - 15+ controls (5.2.x) documented
- ✅ **Drop-in Override Pattern** - Role-specific configs (gateway, development, minimal)
- ✅ **Validation Scripts** - Prevent SSH lockout with pre-restart checks
- ✅ **Brute-Force Protection** - Rate limiting and MaxAuthTries

## Quick Start

```bash
# 1. Validate existing config
./scripts/validate-sshd-config.sh --config /etc/ssh/sshd_config

# 2. Deploy base hardening
sudo cp sshd_config.template /etc/ssh/sshd_config.d/99-ssh-hardening.conf

# 3. Validate before restart (CRITICAL)
sudo sshd -t

# 4. Restart SSH
sudo systemctl restart ssh
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation, key generation, and deployment |
| [CIS_CONTROLS.md](docs/CIS_CONTROLS.md) | Complete mapping of 15+ CIS controls |
| [DROP_INS.md](docs/DROP_INS.md) | Role-specific override examples |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues (lockout prevention, key auth failures) |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- OpenSSH 8.0+
- Root/sudo access
- SSH key pair (Ed25519 or RSA 4096-bit)

## Available Drop-ins

| Drop-in | Use Case | Key Features |
|---------|----------|--------------|
| **10-gateway.conf** | Network gateways | AllowTcpForwarding, GatewayPorts |
| **20-development.conf** | Development servers | X11Forwarding, longer timeouts |
| **30-minimal.conf** | High-security | Minimal ciphers, strict auth |

## Use Cases

- ✅ **Production Servers** - Prevent password-based attacks
- ✅ **Compliance** - Meet CIS Benchmark SSH requirements
- ✅ **Network Gateways** - Allow port forwarding for VPN/tunnels
- ✅ **Development Servers** - Balance security with usability
- ✅ **High-Security Environments** - Minimal attack surface

## Resources

- [OpenSSH Manual](https://www.openssh.com/manual.html)
- [CIS Ubuntu Linux Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [Mozilla SSH Guidelines](https://infosec.mozilla.org/guidelines/openssh)
