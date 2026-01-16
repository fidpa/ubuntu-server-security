# Kernel Hardening

Kernel security via sysctl parameters and /tmp hardening with Docker compatibility.

## Features

- ✅ **sysctl Security Parameters** - 20+ kernel hardening settings
- ✅ **/tmp noexec Hardening** - Prevent script execution from /tmp
- ✅ **Docker-Compatible** - All settings tested with containerized workloads
- ✅ **CIS Benchmark Aligned** - Implements controls 1.5.x and 3.2.x
- ✅ **Persistent Configuration** - Survives reboots via /etc/sysctl.d/
- ✅ **Production-Safe** - No breaking changes to standard applications

## Quick Start

```bash
# 1. Deploy sysctl parameters
sudo cp 99-kernel-hardening.conf.template /etc/sysctl.d/99-kernel-hardening.conf

# 2. Apply immediately
sudo sysctl -p /etc/sysctl.d/99-kernel-hardening.conf

# 3. Harden /tmp (optional)
sudo ./scripts/harden-tmp.sh
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation and parameter explanations |
| [SYSCTL_PARAMETERS.md](docs/SYSCTL_PARAMETERS.md) | Complete list of hardening parameters |
| [TMP_HARDENING.md](docs/TMP_HARDENING.md) | /tmp noexec setup and Docker compatibility |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues (Docker networking, IPv6 disabled) |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- Kernel 5.0+
- Root/sudo access
- Optional: systemd (for /tmp hardening)

## Hardening Categories

| Category | Parameters | Purpose |
|----------|------------|---------|
| **Network Security** | 8 parameters | Prevent IP spoofing, ICMP redirects, source routing |
| **Memory Protection** | 5 parameters | ASLR, restrict kernel pointers, core dumps |
| **Filesystem** | 4 parameters | Symlink/hardlink protections, /tmp noexec |
| **Kernel Security** | 3 parameters | Restrict dmesg, BPF, kernel modules |

## Use Cases

- ✅ **Production Servers** - Reduce kernel attack surface
- ✅ **Container Hosts** - Docker-compatible kernel hardening
- ✅ **Compliance** - Meet CIS Benchmark kernel requirements
- ✅ **Network Security** - Prevent IP spoofing and routing attacks
- ✅ **Defense-in-Depth** - Complement firewall and application security

## Resources

- [Linux Kernel sysctl Documentation](https://www.kernel.org/doc/Documentation/sysctl/)
- [CIS Ubuntu Linux Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [Red Hat Security Guide - Kernel](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/security_guide/sec-securing_the_kernel)
