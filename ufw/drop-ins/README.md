<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# UFW Drop-in Templates

Modular UFW rule templates for different use cases.

## Template overview

| Template | Use case | Ports | Description |
|----------|----------|-------|-------------|
| [10-webserver.rules](10-webserver.rules) | Web server | 80, 443 | HTTP/HTTPS for Nginx/Apache |
| [20-database.rules](20-database.rules) | Databases | 5432, 3306 | PostgreSQL/MySQL (network-restricted) |
| [30-monitoring.rules](30-monitoring.rules) | Monitoring | 9090, 3000, 9100 | Prometheus/Grafana/Exporters |
| [40-docker-host.rules](40-docker-host.rules) | Docker host | 9000, 9443 | Portainer and Docker management |

## Usage

### Option 1: run the commands directly (recommended)

```bash
# Read the template
cat drop-ins/10-webserver.rules

# Copy the commands, adjust them, then run them
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```

### Option 2: with the deployment script

```bash
# Validate
./scripts/deploy-ufw-rules.sh --dry-run drop-ins/10-webserver.rules

# Deploy (with a backup)
./scripts/deploy-ufw-rules.sh drop-ins/10-webserver.rules
```

### Option 3: source it directly

```bash
# Only if the variables are set
source drop-ins/10-webserver.rules
```

## Template details

### 10-webserver.rules

**Use case**: Nginx, Apache, or any other web server

**Ports**:
- 80/tcp - HTTP
- 443/tcp - HTTPS

**Options**:
- Publicly reachable (default)
- Network-restricted (commented-out alternative)

### 20-database.rules

**Use case**: PostgreSQL, MySQL/MariaDB, Redis

**Ports**:
- 5432/tcp - PostgreSQL
- 3306/tcp - MySQL/MariaDB
- 6379/tcp - Redis (optional)

**Important**: databases must NEVER be publicly reachable.

**Pattern**: network-restricted (management network only)

### 30-monitoring.rules

**Use case**: Prometheus, Grafana, Node Exporter, Alertmanager

**Ports**:
- 9090/tcp - Prometheus
- 3000/tcp - Grafana
- 9100/tcp - Node Exporter
- 9093/tcp - Alertmanager

**Pattern**: management network only (10.0.0.0/24)

### 40-docker-host.rules

**Use case**: Portainer, Docker registry, Traefik dashboard

**Ports**:
- 9000/tcp - Portainer HTTP
- 9443/tcp - Portainer HTTPS
- 8000/tcp - Portainer Edge Tunnel
- 5000/tcp - Docker Registry (optional)

**Pattern**: management network only

## Combining templates

Several templates can be combined:

```bash
# Web server + monitoring
./scripts/deploy-ufw-rules.sh drop-ins/10-webserver.rules
./scripts/deploy-ufw-rules.sh drop-ins/30-monitoring.rules

# Or in a single step
cat drop-ins/10-webserver.rules drop-ins/30-monitoring.rules | \
  grep -v '^#' | grep -v '^$' | while read cmd; do sudo $cmd; done
```

## Customization

### Changing the network ranges

The templates use these default networks:
- **10.0.0.0/24** - management network
- **192.168.100.0/24** - client LAN

To change them:
```bash
# Edit before deployment, or use sed
sed -i 's/10.0.0.0\/24/172.16.0.0\/16/g' drop-ins/30-monitoring.rules
```

### Adjusting the comments

UFW comments help document the rule set:

```bash
# With a meaningful comment
sudo ufw allow 443/tcp comment 'HTTPS - Nextcloud'
```

## Best Practices

### 1. Mind the order

UFW evaluates rules in insertion order (first match wins):

```bash
# 1. Specific DENY rules first
sudo ufw insert 1 deny from 10.0.0.50 to any port 22

# 2. Then the ALLOW rules
sudo ufw allow from 10.0.0.0/24 to any port 22
```

### 2. Use network restriction

Public servers: HTTP/HTTPS open, everything else restricted

```bash
# Public
sudo ufw allow 443/tcp

# Management-only
sudo ufw allow from 10.0.0.0/24 to any port 22 proto tcp
```

### 3. Rate limiting for SSH

```bash
# ALWAYS rate-limit SSH
sudo ufw limit 22/tcp
```

### 4. Back up before making changes

```bash
# Manually
sudo cp /etc/ufw/user.rules /etc/ufw/user.rules.backup

# Or via the script (automatic)
./scripts/deploy-ufw-rules.sh drop-ins/...
```

## Complete examples

See [../examples/](../examples/) for full production configurations:

- [minimal-webserver.md](../examples/minimal-webserver.md) - Simple web server
- [nas-docker-stack.md](../examples/nas-docker-stack.md) - File server with Docker
- [development-server.md](../examples/development-server.md) - Development server
