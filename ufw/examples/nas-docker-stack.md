<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# NAS Docker Stack UFW Configuration

Produktions-erprobte UFW-Konfiguration für einen NAS-Server mit Docker-Stack.

## Use Case

- NAS (Network Attached Storage)
- Docker-basierte Services (Nextcloud, Grafana, Portainer, etc.)
- Multi-Network Setup (Management + Client LAN)
- Defense-in-Depth Architektur

## Architektur

```
                    ┌────────────────────────────────────────────┐
                    │            NAS Server                       │
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

- ✅ Network Segmentation (Management vs. Client LAN)
- ✅ SSH Rate-Limiting
- ✅ Samba File-Sharing
- ✅ Docker Services (localhost-bound, Reverse Proxy)
- ✅ Monitoring Stack (Prometheus, Grafana)
- ✅ IPv6 deaktiviert
- ✅ CIS Benchmark 100% compliant

## Netzwerk-Design

| Netzwerk | CIDR | Zweck | Interface |
|----------|------|-------|-----------|
| Management | 10.0.0.0/24 | Admin, SSH, Monitoring | mgmt0 |
| Client LAN | 192.168.100.0/24 | User-Services, Web | lan0 |

## Regeln

**Total: 13 Regeln**

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
# Management Network
sudo ufw allow from 10.0.0.0/24 to any port 139,445 proto tcp comment 'Samba Management'

# Client LAN
sudo ufw allow from 192.168.100.0/24 to any port 139,445 proto tcp comment 'Samba LAN'
```

### 5. Nextcloud (nur von Router)

```bash
# Nextcloud lauscht auf 0.0.0.0:8080, aber nur Router (Reverse Proxy) darf zugreifen
sudo ufw allow from 192.168.100.1 to any port 8080 proto tcp comment 'Nextcloud from Router'
```

### 6. Portainer

```bash
# Management
sudo ufw allow from 10.0.0.0/24 to any port 9000 proto tcp comment 'Portainer HTTP'
sudo ufw allow from 10.0.0.0/24 to any port 9443 proto tcp comment 'Portainer HTTPS'

# Optional: HTTPS auch aus LAN
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

## Docker-Integration

### Service-Binding Pattern

Docker-Services auf localhost binden:

```yaml
# docker-compose.yml
services:
  nextcloud:
    ports:
      - "127.0.0.1:8080:80"  # Nur localhost

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

## Verifikation

```bash
# Status prüfen
sudo ufw status numbered

# CIS Compliance
./scripts/check-ufw-status.sh --cis

# Connectivity Test (von Client)
nc -zv 10.0.0.2 22    # SSH
nc -zv 10.0.0.2 445   # Samba
nc -zv 10.0.0.2 9443  # Portainer
```

## Defense-in-Depth Layers

| Layer | Implementation | Status |
|-------|---------------|--------|
| Network Segmentation | Management vs. LAN | ✅ |
| Firewall Rules | UFW (13 rules) | ✅ |
| Service Binding | localhost + Reverse Proxy | ✅ |
| SSH Hardening | Key-only + Rate Limit | ✅ |
| Logging | medium level | ✅ |

## Troubleshooting

### Samba nicht erreichbar?

```bash
# Ports offen?
sudo ufw status | grep 445

# Samba läuft?
systemctl status smbd

# Von Client testen
smbclient -L //10.0.0.2 -N
```

### Docker-Service von außen erreichbar (obwohl nicht gewollt)?

Docker umgeht UFW! Siehe [DOCKER_NETWORKING.md](../docs/DOCKER_NETWORKING.md)

```bash
# Check: Auf welcher IP lauscht der Container?
docker port CONTAINER_NAME
# Falls 0.0.0.0:PORT → Problem!
# Fix: 127.0.0.1:PORT in docker-compose.yml
```

## Referenzen

- [DOCKER_NETWORKING.md](../docs/DOCKER_NETWORKING.md) - Docker/UFW Interaktion
- [CIS_CONTROLS.md](../docs/CIS_CONTROLS.md) - Compliance Checks
- [../drop-ins/](../drop-ins/) - Modulare Templates
