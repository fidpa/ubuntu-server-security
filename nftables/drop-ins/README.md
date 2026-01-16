<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# nftables Drop-in Templates

Modular firewall configurations for different device roles.

## Quick Reference

| Template | Device Role | Use Case | Lines |
|----------|-------------|----------|-------|
| [10-gateway.nft](10-gateway.nft.template) | Router/Gateway | NAT, routing, failover | 180 |
| [20-server.nft](20-server.nft.template) | NAS/Server | File sharing, databases, services | 150 |
| [30-minimal.nft](30-minimal.nft.template) | Minimal | Web server, headless | 120 |
| [40-docker.nft](40-docker.nft.template) | Docker Host | Container networking | 100 |
| [50-vpn-wireguard.nft](50-vpn-wireguard.nft.template) | VPN Server | WireGuard integration | 80 |
| [60-rate-limiting.nft](60-rate-limiting.nft.template) | All | DoS protection | 70 |

## Template Selection

### Gateway/Router (10-gateway.nft)

**Use when**:
- Home gateway
- Raspberry Pi router
- pfSense/OPNsense replacement
- Multi-WAN failover

**Includes**:
- NAT masquerading
- FORWARD chain for routing
- LAN → WAN internet access
- MSS clamping (critical for NAT)

---

### Server/NAS (20-server.nft)

**Use when**:
- NAS server (Samba, NFS)
- Database server (PostgreSQL, MariaDB)
- Application server (Nextcloud, Grafana)
- Compute platform

**Includes**:
- File sharing ports (Samba, NFS)
- Database ports (PostgreSQL, MariaDB)
- Monitoring ports (Prometheus, Grafana)
- No NAT/routing (server role)

---

### Minimal (30-minimal.nft)

**Use when**:
- Web server only (nginx, Apache)
- Minimal attack surface
- Headless server
- Entry-level hardening

**Includes**:
- SSH (restricted to management network)
- HTTP/HTTPS (public)
- Nothing else (least privilege)

---

### Docker Host (40-docker.nft)

**Use when**:
- Running Docker containers
- Docker Compose stacks
- Any Docker installation

**Includes**:
- Docker DOCKER chain preservation
- Container → Internet access
- LAN → Container access
- Inter-container communication
- Docker NAT rules

**Critical**: Never use `flush ruleset` with this template!

---

### WireGuard VPN (50-vpn-wireguard.nft)

**Use when**:
- WireGuard VPN server
- Road warrior setup
- Site-to-site VPN

**Includes**:
- WireGuard handshake (UDP 51820)
- VPN → Internet routing
- VPN → LAN access
- VPN peer-to-peer
- Full DNS takeover support

---

### Rate-Limiting (60-rate-limiting.nft)

**Use when**:
- DoS protection needed
- Public-facing services
- Brute-force mitigation

**Includes**:
- WAN HTTP/HTTPS (100/min)
- Service-specific limits
- Whitelist + rate-limit patterns

---

## Combining Templates

Templates can be combined for complex setups:

**Gateway + Docker + VPN**:
```bash
cat drop-ins/10-gateway.nft.template \
    drop-ins/40-docker.nft.template \
    drop-ins/50-vpn-wireguard.nft.template > /etc/nftables.conf
```

**Server + Docker + Rate-Limiting**:
```bash
cat drop-ins/20-server.nft.template \
    drop-ins/40-docker.nft.template \
    drop-ins/60-rate-limiting.nft.template > /etc/nftables.conf
```

## Customization

All templates use variables for portability:

```nft
# Required variables (customize for your system)
define WAN_INTERFACE = "eth0"           # eth0, enp0s31f6, ens33, ppp0
define LAN_INTERFACE = "eth3"           # eth3, br0, enx5c857e3ff94d
define LAN_NETWORK = 192.168.1.0/24

# Optional variables
define MGMT_INTERFACE = "eth1"          # Management network (optional)
define MGMT_NETWORK = 10.0.0.0/24
```

## Deployment

1. **Copy template**: `sudo cp drop-ins/XX-*.nft.template /etc/nftables.conf`
2. **Customize variables**: Edit WAN_INTERFACE, LAN_NETWORK, etc.
3. **Validate**: `sudo ../scripts/validate-nftables.sh /etc/nftables.conf`
4. **Deploy**: `sudo ../scripts/deploy-nftables.sh /etc/nftables.conf`

## See Also

- [../examples/](../examples/) - Complete deployment scenarios
- [../docs/SETUP.md](../docs/SETUP.md) - Full deployment guide
- [../docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) - Common issues
