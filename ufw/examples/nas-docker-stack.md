<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# File Server Docker Stack UFW Configuration

Production-tested UFW configuration for a file server running a Docker stack.

## Use case

- NAS (network attached storage)
- Docker-based services (Nextcloud, Grafana, Portainer, etc.)
- Multi-network setup (management + client LAN)
- Defense-in-depth architecture

## Architecture

```
                    ┌────────────────────────────────────────────┐
                    │           File Server                       │
                    │                                             │
Management ────────►│  mgmt0 (10.0.0.2)                          │
(10.0.0.0/24)       │    ├── SSH (22) LIMIT                      │
                    │    ├── Samba (139,445)                     │
                    │    ├── Prometheus (9090)                   │
                    │    └── Portainer (9443)                    │
                    │                                             │
Client LAN ────────►│  lan0 (192.168.100.2)                      │
(192.168.100.0/24)  │    ├── HTTP/HTTPS (80,443)                 │
                    │    ├── Samba (139,445)                     │
                    │    └── Grafana (3000)                      │
                    │                                             │
                    │  Docker Stack (localhost-bound):           │
                    │    ├── Nextcloud (127.0.0.1:8080)          │
                    │    ├── Grafana (127.0.0.1:3000)            │
                    │    └── Uptime Kuma (127.0.0.1:3001)        │
                    └────────────────────────────────────────────┘
```

## Features

- ✅ Network segmentation (management vs. client LAN)
- ✅ SSH rate limiting
- ✅ Samba file sharing
- ✅ Docker services (localhost-bound, behind a reverse proxy)
- ✅ Monitoring stack (Prometheus, Grafana)
- ✅ IPv6 disabled
- ✅ CIS Benchmark 100% compliant

## Network design

| Network | CIDR | Purpose | Interface |
|---------|------|---------|-----------|
| Management | 10.0.0.0/24 | Admin, SSH, monitoring | mgmt0 |
| Client LAN | 192.168.100.0/24 | User services, web | lan0 |

## Rules

**Total: 13 rules**

| # | Port | Protocol | Source | Comment |
|---|------|----------|--------|---------|
| 1 | 22 | TCP | LIMIT | SSH Rate-Limited |
| 2 | 80 | TCP | Anywhere | HTTP |
| 3 | 443 | TCP | Anywhere | HTTPS |
| 4 | 139,445 | TCP | 10.0.0.0/24 | Samba Management |
| 5 | 139,445 | TCP | 192.168.100.0/24 | Samba LAN |
| 6 | 8080 | TCP | 192.168.100.1 | Nextcloud (from Router) |
| 7 | 9000 | TCP | 10.0.0.0/24 | Portainer HTTP |
| 8 | 9443 | TCP | 10.0.0.0/24 | Portainer HTTPS |
| 9 | 9443 | TCP | 192.168.100.0/24 | Portainer HTTPS LAN |
| 10 | 61208 | TCP | 10.0.0.0/24 | Glances Management |
| 11 | 61208 | TCP | 192.168.100.0/24 | Glances LAN |
| 12 | 9090 | TCP | 10.0.0.0/24 | Prometheus |
| 13 | 3000 | TCP | 10.0.0.0/24 | Grafana |

## Deployment

### 1. Basis-Setup

```bash
# Installation
sudo apt update && sudo apt install ufw

# Default Policies
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny routed

# IPv6 deaktivieren
sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
```

### 2. SSH

```bash
sudo ufw limit 22/tcp comment 'SSH Rate-Limited'
```

### 3. Web Services

```bash
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```

### 4. Samba (File-Sharing)

```bash
# Management network
sudo ufw allow from 10.0.0.0/24 to any port 139,445 proto tcp comment 'Samba Management'

# Client LAN
sudo ufw allow from 192.168.100.0/24 to any port 139,445 proto tcp comment 'Samba LAN'
```

### 5. Nextcloud (from the router only)

```bash
# Nextcloud listens on 0.0.0.0:8080, but only the router (reverse proxy) may reach it
sudo ufw allow from 192.168.100.1 to any port 8080 proto tcp comment 'Nextcloud from Router'
```

### 6. Portainer

```bash
# Management
sudo ufw allow from 10.0.0.0/24 to any port 9000 proto tcp comment 'Portainer HTTP'
sudo ufw allow from 10.0.0.0/24 to any port 9443 proto tcp comment 'Portainer HTTPS'

# Optional: HTTPS from the LAN as well
sudo ufw allow from 192.168.100.0/24 to any port 9443 proto tcp comment 'Portainer HTTPS LAN'
```

### 7. Monitoring (Glances, Prometheus, Grafana)

```bash
# Glances
sudo ufw allow from 10.0.0.0/24 to any port 61208 proto tcp comment 'Glances Management'
sudo ufw allow from 192.168.100.0/24 to any port 61208 proto tcp comment 'Glances LAN'

# Prometheus (nur Management)
sudo ufw allow from 10.0.0.0/24 to any port 9090 proto tcp comment 'Prometheus'

# Grafana (nur Management)
sudo ufw allow from 10.0.0.0/24 to any port 3000 proto tcp comment 'Grafana'
```

### 8. Logging

```bash
sudo ufw logging medium
```

### 9. Aktivieren

```bash
sudo ufw enable
```

## Docker integration

### Service binding pattern

Bind the Docker services to localhost:

```yaml
# docker-compose.yml
services:
  nextcloud:
    ports:
      - "127.0.0.1:8080:80"  # localhost only

  grafana:
    ports:
      - "127.0.0.1:3000:3000"

  uptime-kuma:
    ports:
      - "127.0.0.1:3001:3001"
```

### Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/nextcloud
server {
    listen 443 ssl;
    server_name nextcloud.example.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Verification

```bash
# Check the status
sudo ufw status numbered

# CIS Compliance
./scripts/check-ufw-status.sh --cis

# Connectivity test (from a client)
nc -zv 10.0.0.2 22    # SSH
nc -zv 10.0.0.2 445   # Samba
nc -zv 10.0.0.2 9443  # Portainer
```

## Defense-in-depth layers

| Layer | Implementation | Status |
|-------|---------------|--------|
| Network Segmentation | Management vs. LAN | ✅ |
| Firewall Rules | UFW (13 rules) | ✅ |
| Service Binding | localhost + Reverse Proxy | ✅ |
| SSH Hardening | Key-only + Rate Limit | ✅ |
| Logging | medium level | ✅ |

## Troubleshooting

### Samba unreachable?

```bash
# Are the ports open?
sudo ufw status | grep 445

# Is Samba running?
systemctl status smbd

# Test from a client
smbclient -L //10.0.0.2 -N
```

### Docker service reachable from outside (although it should not be)?

Docker bypasses UFW. See [DOCKER_NETWORKING.md](../docs/DOCKER_NETWORKING.md)

```bash
# Check: which address is the container listening on?
docker port CONTAINER_NAME
# If it says 0.0.0.0:PORT, that is the problem.
# Fix: 127.0.0.1:PORT in docker-compose.yml
```

## References

- [DOCKER_NETWORKING.md](../docs/DOCKER_NETWORKING.md) - Docker/UFW interaction
- [CIS_CONTROLS.md](../docs/CIS_CONTROLS.md) - Compliance checks
- [../drop-ins/](../drop-ins/) - Modular templates
