# UFW - Uncomplicated Firewall

Simple firewall for servers with CIS compliance and Docker-aware networking.

## Features

- ✅ **CIS Benchmark Compliant** - Implements control 3.5.1.x
- ✅ **Docker-Aware** - Handles container networking correctly
- ✅ **Drop-in Rules** - Modular service-specific configurations
- ✅ **Easy Syntax** - Human-readable firewall rules
- ✅ **IPv4/IPv6 Support** - Dual-stack protection
- ✅ **Default Deny** - Secure-by-default configuration

## Quick Start

```bash
# 1. Install UFW (usually pre-installed)
sudo apt install ufw

# 2. Basic hardening
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp

# 3. Enable firewall
sudo ufw enable

# 4. Verify
sudo ufw status verbose
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation, basic rules, and drop-in patterns |
| [DOCKER_NETWORKING.md](docs/DOCKER_NETWORKING.md) | Docker compatibility and best practices |
| [DROP_INS.md](docs/DROP_INS.md) | Service-specific rule examples |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues (Docker conflicts, port blocking) |

## Requirements

- Ubuntu 22.04+ / Debian 11+ (UFW included by default)
- Root/sudo access
- Optional: Docker (for container-aware rules)

## Available Drop-ins

| Drop-in | Service | Ports |
|---------|---------|-------|
| **10-webserver.rules** | nginx/Apache | 80/tcp, 443/tcp |
| **20-database.rules** | PostgreSQL/MySQL | 5432/tcp, 3306/tcp |
| **30-monitoring.rules** | Prometheus/Grafana | 9090/tcp, 3000/tcp |

## Use Cases

- ✅ **Simple Servers** - Web, database, NAS with straightforward firewall needs
- ✅ **Docker Hosts** - Container networking with proper rule ordering
- ✅ **Development Servers** - Easy to modify and test firewall rules
- ✅ **Compliance** - Meet CIS Benchmark firewall requirements
- ✅ **Quick Deployments** - Firewall setup in under 5 minutes

## Resources

- [UFW Official Documentation](https://help.ubuntu.com/community/UFW)
- [UFW Manual Page](https://manpages.ubuntu.com/manpages/jammy/man8/ufw.8.html)
- [CIS Ubuntu Linux Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
