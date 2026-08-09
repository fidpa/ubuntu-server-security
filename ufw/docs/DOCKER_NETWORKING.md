<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# Docker and UFW networking

Docker and UFW have a complicated relationship. This document explains the problems and the solutions.

## The problem

**Docker bypasses UFW.**

Docker manipulates iptables directly and inserts its own chains (`DOCKER`, `DOCKER-USER`), which are evaluated BEFORE the UFW rules.

### Example

```bash
# UFW: block everything
sudo ufw default deny incoming

# Docker: container on port 8080
docker run -p 8080:80 nginx

# Result: port 8080 is reachable from outside despite UFW!
```

### Why does this happen?

Docker uses the FORWARD chain and NAT rules:

```
Packet → PREROUTING (NAT) → FORWARD (Docker) → Container
                                ↑
                        UFW INPUT is bypassed!
```

```bash
# Show the Docker chains
sudo iptables -L -n | grep -A5 "Chain DOCKER"
```

## Solutions

### Solution 1: bind services to localhost (recommended)

**The best solution for most use cases.**

```yaml
# docker-compose.yml
services:
  app:
    ports:
      - "127.0.0.1:8080:8080"  # localhost only
```

**Then put a reverse proxy in front**:
```
Client → UFW (443) → Nginx → localhost:8080 → Container
```

### Solution 2: host network mode

The container uses the host network directly, so UFW applies as usual.

```yaml
services:
  app:
    network_mode: "host"
```

**Drawbacks**:
- No network isolation
- Port conflicts are possible
- Not suitable for every container

### Solution 3: DOCKER-USER chain

Docker leaves the `DOCKER-USER` chain to you for custom rules.

```bash
# Allow the management network, block the rest
sudo iptables -I DOCKER-USER -i eth0 -s 10.0.0.0/24 -j ACCEPT
sudo iptables -I DOCKER-USER -i eth0 -j DROP

# Persist the rules (NOT via iptables-persistent!)
```

**Persistence** (in `/etc/rc.local` or a systemd service):
```bash
#!/bin/bash
iptables -I DOCKER-USER -i eth0 -s 10.0.0.0/24 -j ACCEPT
iptables -I DOCKER-USER -i eth0 -j DROP
```

### Solution 4: configure the Docker daemon

**Disable iptables** (not recommended):

```json
// /etc/docker/daemon.json
{
  "iptables": false
}
```

**Drawbacks**:
- Container-to-container networking breaks
- NAT for internet access stops working
- Only for very specific setups

## Reverse proxy pattern (best practice)

### Architecture

```
                  ┌─────────────────────────────────────┐
                  │           Host                       │
                  │                                      │
Internet ───┬────►│ UFW (443) ──► Nginx (reverse proxy) │
            │     │                       │              │
            │     │                       ▼              │
            │     │              ┌────────────────┐     │
            │     │              │ Docker Network  │     │
            │     │              │                 │     │
            │     │              │ App (127.0.0.1) │     │
            │     │              │ DB  (internal)  │     │
            │     │              └────────────────┘     │
            │     │                                      │
            X     │ UFW blocks direct Docker access      │
                  └─────────────────────────────────────┘
```

### Nginx configuration

```nginx
# /etc/nginx/sites-available/app
server {
    listen 443 ssl;
    server_name app.example.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### UFW rules

```bash
# Only open the Nginx ports
sudo ufw allow 80/tcp comment 'HTTP (redirect)'
sudo ufw allow 443/tcp comment 'HTTPS (Nginx)'

# Do NOT open the Docker ports (localhost only)
```

## Defense-in-Depth

### Layer 1: UFW (host level)

```bash
sudo ufw default deny incoming
sudo ufw allow 443/tcp
```

### Layer 2: service binding

```yaml
ports:
  - "127.0.0.1:8080:8080"
```

### Layer 3: Network Segmentation

```yaml
# Separate Docker networks
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # no internet access
```

### Layer 4: Container Security

```yaml
services:
  db:
    networks:
      - backend  # backend network only
    # NO ports: definition (not exposed)
```

## Production example: file server with Docker

### Architecture

- **Management network** (10.0.0.0/24): admin access
- **Client LAN** (192.168.100.0/24): user access
- **Docker bridge**: container isolation

### docker-compose.yml

```yaml
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    networks:
      - frontend
      - backend
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro

  nextcloud:
    image: nextcloud:apache
    ports:
      - "127.0.0.1:8080:80"  # localhost only!
    networks:
      - backend
    depends_on:
      - db

  portainer:
    image: portainer/portainer-ce
    ports:
      - "127.0.0.1:9000:9000"   # HTTP - localhost only
      - "10.0.0.2:9443:9443"    # HTTPS - management IP only
    networks:
      - management

  db:
    image: postgres:15
    networks:
      - backend  # no port exposed!
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}

networks:
  frontend:
  backend:
    internal: true
  management:
```

### UFW rules

```bash
# Web (via the Nginx reverse proxy)
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Portainer HTTPS (management only)
sudo ufw allow from 10.0.0.0/24 to any port 9443 proto tcp comment 'Portainer HTTPS'

# PostgreSQL: no UFW rule needed (not exposed, Docker-internal only)
```

## Troubleshooting

### Container reachable from outside although UFW blocks it?

1. **Check Port-Binding**:
   ```bash
   docker port CONTAINER_NAME
   ```

2. **Bound to 0.0.0.0?** → That is the problem.
   ```
   0.0.0.0:8080 -> 80/tcp
   ```

3. **Fix**: bind to localhost only
   ```yaml
   ports:
     - "127.0.0.1:8080:80"
   ```

### Testing the DOCKER-USER chain

```bash
# Current rules
sudo iptables -L DOCKER-USER -n -v

# Test rule (temporary)
sudo iptables -I DOCKER-USER -s 192.168.1.100 -j LOG --log-prefix "DOCKER-USER: "

# Inspect the log
sudo tail -f /var/log/kern.log | grep DOCKER-USER
```

### Resetting the Docker chains

If DOCKER-USER has been damaged:

```bash
# Restart the Docker service (recreates the chains)
sudo systemctl restart docker
```

## Summary

| Method | Complexity | Security | Recommended |
|---------|-------------|------------|-----------|
| localhost binding + reverse proxy | Low | High | ✅ Yes |
| DOCKER-USER chain | Medium | Medium | For experts |
| Host network mode | Low | Low | Special cases |
| iptables: false | High | - | ❌ No |

**Best practice**: bind every container to localhost and put Nginx/Traefik in front as a reverse proxy.
