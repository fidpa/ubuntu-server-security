# nftables - Advanced Firewall

Advanced firewall for gateways with NAT, WireGuard VPN integration, and Docker compatibility.

## Features

- ✅ **Production-Ready Templates** - Gateway, server, and Docker configurations
- ✅ **WireGuard VPN Integration** - Full DNS takeover and routing
- ✅ **NAT Support** - SNAT, DNAT, port forwarding
- ✅ **Docker Chain Preservation** - Never breaks container networking
- ✅ **Rate Limiting** - Protection against DoS and port scanning
- ✅ **Modular Drop-ins** - Service-specific rules in separate files

## Quick Start

```bash
# 1. Install nftables
sudo apt install nftables

# 2. Choose template (server or gateway)
sudo cp drop-ins/20-server.nft.template /etc/nftables.conf

# 3. Validate syntax
sudo ./scripts/validate-nftables.sh /etc/nftables.conf

# 4. Deploy (atomic replace)
sudo ./scripts/deploy-nftables.sh /etc/nftables.conf
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation, template selection, and deployment |
| [WIREGUARD_INTEGRATION.md](docs/WIREGUARD_INTEGRATION.md) | VPN setup with full DNS takeover |
| [DOCKER_COMPATIBILITY.md](docs/DOCKER_COMPATIBILITY.md) | Chain preservation and custom rules |
| [NAT_CONFIGURATION.md](docs/NAT_CONFIGURATION.md) | SNAT, DNAT, and port forwarding |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues (Docker networking, VPN routing) |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- nftables v1.0+
- Root/sudo access
- Optional: WireGuard (for VPN features)
- Optional: Docker (for container compatibility)

## Available Templates

| Template | Use Case | Features |
|----------|----------|----------|
| **10-gateway.nft** | Network gateway/router | NAT, Multi-WAN, port forwarding |
| **20-server.nft** | Simple server | Input filtering, rate limiting |
| **40-docker.nft** | Docker host | Chain preservation, custom rules |

## Use Cases

- ✅ **Network Gateways** - NAT, routing, Multi-WAN failover
- ✅ **WireGuard VPN Servers** - Full DNS takeover for VPN clients
- ✅ **Docker Hosts** - Firewall that doesn't break container networking
- ✅ **Production Servers** - Advanced filtering with rate limiting
- ✅ **Complex Routing** - Policy-based routing, custom chains

## Resources

- [nftables Official Documentation](https://wiki.nftables.org/)
- [nftables Wiki](https://wiki.nftables.org/wiki-nftables/index.php/Main_Page)
- [Debian nftables Guide](https://wiki.debian.org/nftables)
