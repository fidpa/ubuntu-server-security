# Boot Security

GRUB and UEFI password protection with triple-validation and multi-vendor guides.

## Features

- ✅ **PBKDF2-SHA512 Hashing** - Industry-standard password protection
- ✅ **Headless-Server Compatible** - `--unrestricted` flag allows normal boot without password
- ✅ **Triple-Validation** - Automated backup and rollback to prevent boot failures
- ✅ **Multi-Vendor UEFI Guides** - ASRock, Dell, HP, Lenovo documented
- ✅ **CIS Benchmark Aligned** - Implements control 1.4.x (boot loader security)
- ✅ **Automated Setup** - Script handles GRUB password configuration

## Quick Start

```bash
# 1. Run automated GRUB password setup
sudo ./scripts/setup-grub-password.sh

# 2. Follow prompts to set password

# 3. Reboot and verify (press 'e' in GRUB menu - should prompt for password)
```

**Full guide**: See [docs/GRUB_PASSWORD.md](docs/GRUB_PASSWORD.md)

## Documentation

| Document | Description |
|----------|-------------|
| [GRUB_PASSWORD.md](docs/GRUB_PASSWORD.md) | GRUB password setup (automated + manual) |
| [UEFI_PASSWORD.md](docs/UEFI_PASSWORD.md) | UEFI/BIOS password guides (ASRock, Dell, HP, Lenovo) |
| [TRIPLE_VALIDATION.md](docs/TRIPLE_VALIDATION.md) | Validation process and rollback procedures |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Boot failures and recovery |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- GRUB bootloader
- Root/sudo access
- Optional: UEFI/BIOS access (for firmware password)

## Two-Layer Protection

| Layer | Component | Protection Against |
|-------|-----------|---------------------|
| **Layer 1** | UEFI/BIOS Password | Unauthorized BIOS settings, boot device changes, USB boot |
| **Layer 2** | GRUB Password | GRUB menu modification ('e'), GRUB console ('c'), recovery mode |

**Recommendation**: Use both layers for defense-in-depth.

## Use Cases

- ✅ **Physical Security** - Protect servers in co-location or untrusted locations
- ✅ **Recovery Mode Protection** - Prevent unauthorized single-user mode access
- ✅ **Compliance** - Meet CIS Benchmark boot security requirements
- ✅ **Headless Servers** - Normal boot works without password (menu modification requires auth)
- ✅ **Multi-Boot Systems** - Protect boot configuration from unauthorized changes

## Resources

- [GRUB Manual - Security](https://www.gnu.org/software/grub/manual/grub/html_node/Security.html)
- [CIS Ubuntu Linux Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [Ubuntu GRUB2 Documentation](https://help.ubuntu.com/community/Grub2)
