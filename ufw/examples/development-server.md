<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# Development Server UFW Configuration

UFW-Konfiguration für einen Development-Server mit erweitertem Portzugang.

## Use Case

- Entwicklungs-Server (nicht Produktion!)
- VS Code Server / Remote Development
- Multiple Dev-Ports (Node.js, Python, etc.)
- Team-Zugriff aus lokalem Netzwerk

## Architektur

```
                    ┌────────────────────────────────────────────┐
                    │        Development Server                   │
                    │                                             │
LAN/VPN ───────────►│  eth0 (192.168.1.100)                      │
(192.168.1.0/24)    │    ├── SSH (22) LIMIT                      │
                    │    ├── HTTP/HTTPS (80, 443)                │
                    │    ├── VS Code Server (8443)               │
                    │    ├── Dev Ports (3000-3010)               │
                    │    ├── Node.js Debug (9229)                │
                    │    └── PostgreSQL (5432)                   │
                    │                                             │
                    │  Services:                                  │
                    │    ├── Docker Dev Stack                    │
                    │    ├── Local PostgreSQL                    │
                    │    └── Multiple Dev Apps                   │
                    └────────────────────────────────────────────┘
```

## Features

- ✅ SSH Rate-Limiting
- ✅ VS Code Server (Remote Development)
- ✅ Development Port Range
- ✅ Database Access (network-restricted)
- ✅ Node.js Debugging
- ✅ Docker Ports (Portainer)
- ✅ Network-Restricted (LAN-only, nicht öffentlich!)

## Regeln

**Total: ~12 Regeln**

| Port(s) | Protocol | Source | Comment |
|---------|----------|--------|---------|
| 22 | TCP | LIMIT | SSH |
| 80 | TCP | LAN | HTTP |
| 443 | TCP | LAN | HTTPS |
| 8443 | TCP | LAN | VS Code Server |
| 3000:3010 | TCP | LAN | Dev Ports Range |
| 9229 | TCP | LAN | Node.js Debug |
| 5432 | TCP | LAN | PostgreSQL |
| 3306 | TCP | LAN | MySQL |
| 9000 | TCP | LAN | Portainer |

## Deployment

### 1. Basis-Setup

```bash
# Installation
sudo apt update && sudo apt install ufw

# Default Policies
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

### 2. SSH

```bash
# Rate-Limited SSH
sudo ufw limit 22/tcp comment 'SSH'

# Alternative: Nur aus LAN (sicherer)
# sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp comment 'SSH LAN'
```

### 3. Web Services

```bash
# Nur aus LAN (Dev-Server sollte nicht öffentlich sein!)
sudo ufw allow from 192.168.1.0/24 to any port 80 proto tcp comment 'HTTP LAN'
sudo ufw allow from 192.168.1.0/24 to any port 443 proto tcp comment 'HTTPS LAN'
```

### 4. VS Code Server

```bash
# VS Code Remote Development
sudo ufw allow from 192.168.1.0/24 to any port 8443 proto tcp comment 'VS Code Server'
```

### 5. Development Port Range

```bash
# Range für Dev-Apps (React, Vue, Node.js, etc.)
# Port 3000 = React default
# Port 3001 = Create React App hot-reload
# Port 5173 = Vite default
sudo ufw allow from 192.168.1.0/24 to any port 3000:3010 proto tcp comment 'Dev Ports'
```

### 6. Node.js Debugging

```bash
# Chrome DevTools Debugging
sudo ufw allow from 192.168.1.0/24 to any port 9229 proto tcp comment 'Node Debug'
```

### 7. Datenbanken (optional)

```bash
# PostgreSQL
sudo ufw allow from 192.168.1.0/24 to any port 5432 proto tcp comment 'PostgreSQL'

# MySQL/MariaDB
sudo ufw allow from 192.168.1.0/24 to any port 3306 proto tcp comment 'MySQL'

# Redis
sudo ufw allow from 192.168.1.0/24 to any port 6379 proto tcp comment 'Redis'
```

### 8. Docker Management

```bash
# Portainer
sudo ufw allow from 192.168.1.0/24 to any port 9000 proto tcp comment 'Portainer'
```

### 9. Aktivieren

```bash
sudo ufw enable
```

## Ergebnis

```bash
sudo ufw status numbered

# Erwartete Ausgabe:
# [ 1] 22/tcp                     LIMIT IN    Anywhere
# [ 2] 80/tcp                     ALLOW IN    192.168.1.0/24
# [ 3] 443/tcp                    ALLOW IN    192.168.1.0/24
# [ 4] 8443/tcp                   ALLOW IN    192.168.1.0/24
# [ 5] 3000:3010/tcp              ALLOW IN    192.168.1.0/24
# [ 6] 9229/tcp                   ALLOW IN    192.168.1.0/24
# [ 7] 5432/tcp                   ALLOW IN    192.168.1.0/24
# [ 8] 9000/tcp                   ALLOW IN    192.168.1.0/24
```

## Varianten

### A) Temporärer Port öffnen

Für kurzfristiges Testing:

```bash
# Port öffnen
sudo ufw allow from 192.168.1.0/24 to any port 8080 proto tcp comment 'Temp Test'

# Nach dem Test wieder schließen
sudo ufw delete allow from 192.168.1.0/24 to any port 8080 proto tcp
```

### B) Einzelner Entwickler-PC

Noch restriktiver:

```bash
# Nur von bestimmter IP
sudo ufw allow from 192.168.1.50 to any port 3000:3010 proto tcp comment 'Dev from Workstation'
```

### C) VPN-only Access

Für Remote-Entwickler via VPN:

```bash
# WireGuard VPN Subnet
sudo ufw allow from 10.29.93.0/24 to any port 3000:3010 proto tcp comment 'Dev via VPN'
```

## Security Hinweise

### Was dieser Server NICHT sein sollte

- ❌ Öffentlich im Internet erreichbar
- ❌ Mit Produktionsdaten
- ❌ Ohne Backup

### Empfehlungen

- ✅ Nur im LAN/VPN zugänglich
- ✅ Regelmäßige Backups
- ✅ Keine echten Credentials in Code
- ✅ Separate Dev-Datenbank

## Troubleshooting

### Dev-Port nicht erreichbar?

```bash
# UFW-Regel vorhanden?
sudo ufw status | grep 3000

# App läuft?
ss -tuln | grep 3000

# Auf welcher IP lauscht die App?
# 127.0.0.1:3000 = nur localhost (Problem!)
# 0.0.0.0:3000 = alle IPs (OK)

# Node.js/React: Mit --host 0.0.0.0 starten
npm run dev -- --host 0.0.0.0
```

### Vite/React lauscht nur auf localhost?

```javascript
// vite.config.js
export default defineConfig({
  server: {
    host: '0.0.0.0',  // Von außen erreichbar
    port: 5173
  }
})
```

### VS Code Server Connection refused?

```bash
# Port offen?
sudo ufw status | grep 8443

# Service läuft?
systemctl status code-server

# Auf welcher IP?
ss -tuln | grep 8443
```

## Referenzen

- [SETUP.md](../docs/SETUP.md) - Basis-Setup
- [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) - Problemlösungen
- [../drop-ins/](../drop-ins/) - Weitere Templates
