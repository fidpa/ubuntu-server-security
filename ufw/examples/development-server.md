<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# Development Server UFW Configuration

UFW configuration for a development server with wider port access.

## Use case

- Development server (not production!)
- VS Code Server / remote development
- Multiple dev ports (Node.js, Python, etc.)
- Team access from the local network

## Architecture

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
- ✅ Network-restricted (LAN only, not public!)

## Rules

**Total: ~12 rules**

| Port(s) | Protocol | Source | Comment |
|---------|----------|--------|---------|
| 22 | TCP | LIMIT | SSH |
| 80 | TCP | LAN | HTTP |
| 443 | TCP | LAN | HTTPS |
| 8443 | TCP | LAN | VS Code Server |
| 3000:3010 | TCP | LAN | Dev port range |
| 9229 | TCP | LAN | Node.js Debug |
| 5432 | TCP | LAN | PostgreSQL |
| 3306 | TCP | LAN | MySQL |
| 9000 | TCP | LAN | Portainer |

## Deployment

### 1. Base setup

```bash
# Installation
sudo apt update && sudo apt install ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

### 2. SSH

```bash
# Rate-limited SSH
sudo ufw limit 22/tcp comment 'SSH'

# Alternative: from the LAN only (safer)
# sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp comment 'SSH LAN'
```

### 3. Web services

```bash
# From the LAN only (a dev server should not be public!)
sudo ufw allow from 192.168.1.0/24 to any port 80 proto tcp comment 'HTTP LAN'
sudo ufw allow from 192.168.1.0/24 to any port 443 proto tcp comment 'HTTPS LAN'
```

### 4. VS Code Server

```bash
# VS Code remote development
sudo ufw allow from 192.168.1.0/24 to any port 8443 proto tcp comment 'VS Code Server'
```

### 5. Development port range

```bash
# Range for dev apps (React, Vue, Node.js, etc.)
# Port 3000 = React default
# Port 3001 = Create React App hot-reload
# Port 5173 = Vite default
sudo ufw allow from 192.168.1.0/24 to any port 3000:3010 proto tcp comment 'Dev Ports'
```

### 6. Node.js debugging

```bash
# Chrome DevTools debugging
sudo ufw allow from 192.168.1.0/24 to any port 9229 proto tcp comment 'Node Debug'
```

### 7. Databases (optional)

```bash
# PostgreSQL
sudo ufw allow from 192.168.1.0/24 to any port 5432 proto tcp comment 'PostgreSQL'

# MySQL/MariaDB
sudo ufw allow from 192.168.1.0/24 to any port 3306 proto tcp comment 'MySQL'

# Redis
sudo ufw allow from 192.168.1.0/24 to any port 6379 proto tcp comment 'Redis'
```

### 8. Docker management

```bash
# Portainer
sudo ufw allow from 192.168.1.0/24 to any port 9000 proto tcp comment 'Portainer'
```

### 9. Enable

```bash
sudo ufw enable
```

## Result

```bash
sudo ufw status numbered

# Expected output:
# [ 1] 22/tcp                     LIMIT IN    Anywhere
# [ 2] 80/tcp                     ALLOW IN    192.168.1.0/24
# [ 3] 443/tcp                    ALLOW IN    192.168.1.0/24
# [ 4] 8443/tcp                   ALLOW IN    192.168.1.0/24
# [ 5] 3000:3010/tcp              ALLOW IN    192.168.1.0/24
# [ 6] 9229/tcp                   ALLOW IN    192.168.1.0/24
# [ 7] 5432/tcp                   ALLOW IN    192.168.1.0/24
# [ 8] 9000/tcp                   ALLOW IN    192.168.1.0/24
```

## Variants

### A) Open a port temporarily

For short-lived testing:

```bash
# Open the port
sudo ufw allow from 192.168.1.0/24 to any port 8080 proto tcp comment 'Temp Test'

# Close it again after the test
sudo ufw delete allow from 192.168.1.0/24 to any port 8080 proto tcp
```

### B) A single developer workstation

Even more restrictive:

```bash
# From one specific IP only
sudo ufw allow from 192.168.1.50 to any port 3000:3010 proto tcp comment 'Dev from Workstation'
```

### C) VPN-only access

For remote developers on the VPN:

```bash
# WireGuard VPN subnet
sudo ufw allow from 10.29.93.0/24 to any port 3000:3010 proto tcp comment 'Dev via VPN'
```

## Security notes

### What this server must NOT be

- ❌ Reachable from the public internet
- ❌ Holding production data
- ❌ Running without backups

### Recommendations

- ✅ Reachable from the LAN/VPN only
- ✅ Regular backups
- ✅ No real credentials in the code
- ✅ A separate development database

## Troubleshooting

### Dev port unreachable?

```bash
# Does the UFW rule exist?
sudo ufw status | grep 3000

# Is the app running?
ss -tuln | grep 3000

# Which address is the app listening on?
# 127.0.0.1:3000 = localhost only (that's the problem!)
# 0.0.0.0:3000 = all addresses (OK)

# Node.js/React: start it with --host 0.0.0.0
npm run dev -- --host 0.0.0.0
```

### Vite/React only listening on localhost?

```javascript
// vite.config.js
export default defineConfig({
  server: {
    host: '0.0.0.0',  // reachable from outside
    port: 5173
  }
})
```

### VS Code Server connection refused?

```bash
# Is the port open?
sudo ufw status | grep 8443

# Is the service running?
systemctl status code-server

# On which address?
ss -tuln | grep 8443
```

## References

- [SETUP.md](../docs/SETUP.md) - Base setup
- [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) - Problem solving
- [../drop-ins/](../drop-ins/) - More templates
