<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# UFW Drop-in Templates

Modulare UFW-Regel-Templates für verschiedene Use Cases.

## Template-Übersicht

| Template | Use Case | Ports | Beschreibung |
|----------|----------|-------|--------------|
| [10-webserver.rules](10-webserver.rules) | Web Server | 80, 443 | HTTP/HTTPS für Nginx/Apache |
| [20-database.rules](20-database.rules) | Datenbanken | 5432, 3306 | PostgreSQL/MySQL (network-restricted) |
| [30-monitoring.rules](30-monitoring.rules) | Monitoring | 9090, 3000, 9100 | Prometheus/Grafana/Exporters |
| [40-docker-host.rules](40-docker-host.rules) | Docker Host | 9000, 9443 | Portainer & Docker Management |

## Verwendung

### Option 1: Direkt ausführen (empfohlen)

```bash
# Template lesen
cat drop-ins/10-webserver.rules

# Befehle kopieren und anpassen, dann ausführen
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```

### Option 2: Mit Deployment-Script

```bash
# Validieren
./scripts/deploy-ufw-rules.sh --dry-run drop-ins/10-webserver.rules

# Deployen (mit Backup)
./scripts/deploy-ufw-rules.sh drop-ins/10-webserver.rules
```

### Option 3: Source direkt

```bash
# Nur wenn Variables gesetzt sind
source drop-ins/10-webserver.rules
```

## Template-Details

### 10-webserver.rules

**Use Case**: Nginx, Apache, oder andere Web-Server

**Ports**:
- 80/tcp - HTTP
- 443/tcp - HTTPS

**Optionen**:
- Öffentlich zugänglich (Standard)
- Network-restricted (kommentierte Alternative)

### 20-database.rules

**Use Case**: PostgreSQL, MySQL/MariaDB, Redis

**Ports**:
- 5432/tcp - PostgreSQL
- 3306/tcp - MySQL/MariaDB
- 6379/tcp - Redis (optional)

**Wichtig**: Datenbanken sollten NIEMALS öffentlich zugänglich sein!

**Pattern**: Network-restricted (Management-Network only)

### 30-monitoring.rules

**Use Case**: Prometheus, Grafana, Node Exporter, Alertmanager

**Ports**:
- 9090/tcp - Prometheus
- 3000/tcp - Grafana
- 9100/tcp - Node Exporter
- 9093/tcp - Alertmanager

**Pattern**: Management-Network only (10.0.0.0/24)

### 40-docker-host.rules

**Use Case**: Portainer, Docker Registry, Traefik Dashboard

**Ports**:
- 9000/tcp - Portainer HTTP
- 9443/tcp - Portainer HTTPS
- 8000/tcp - Portainer Edge Tunnel
- 5000/tcp - Docker Registry (optional)

**Pattern**: Management-Network only

## Template-Kombination

Mehrere Templates können kombiniert werden:

```bash
# Web Server + Monitoring
./scripts/deploy-ufw-rules.sh drop-ins/10-webserver.rules
./scripts/deploy-ufw-rules.sh drop-ins/30-monitoring.rules

# Oder in einem Schritt
cat drop-ins/10-webserver.rules drop-ins/30-monitoring.rules | \
  grep -v '^#' | grep -v '^$' | while read cmd; do sudo $cmd; done
```

## Anpassung

### Netzwerk-Bereiche ändern

Templates verwenden Standard-Netzwerke:
- **10.0.0.0/24** - Management Network
- **192.168.100.0/24** - Client LAN

Anpassen:
```bash
# Vor Deployment editieren oder sed verwenden
sed -i 's/10.0.0.0\/24/172.16.0.0\/16/g' drop-ins/30-monitoring.rules
```

### Kommentare anpassen

UFW-Kommentare helfen bei der Dokumentation:

```bash
# Mit aussagekräftigem Kommentar
sudo ufw allow 443/tcp comment 'HTTPS - Nextcloud'
```

## Best Practices

### 1. Reihenfolge beachten

UFW verarbeitet Regeln nach Einfügereihenfolge (first match wins):

```bash
# 1. Spezifische DENY-Regeln zuerst
sudo ufw insert 1 deny from 10.0.0.50 to any port 22

# 2. Dann ALLOW-Regeln
sudo ufw allow from 10.0.0.0/24 to any port 22
```

### 2. Network-Restriction verwenden

Öffentliche Server: HTTP/HTTPS offen, Rest restricted

```bash
# Öffentlich
sudo ufw allow 443/tcp

# Management-only
sudo ufw allow from 10.0.0.0/24 to any port 22 proto tcp
```

### 3. Rate-Limiting für SSH

```bash
# IMMER Rate-Limiting für SSH
sudo ufw limit 22/tcp
```

### 4. Backup vor Änderungen

```bash
# Manuell
sudo cp /etc/ufw/user.rules /etc/ufw/user.rules.backup

# Oder via Script (automatisch)
./scripts/deploy-ufw-rules.sh drop-ins/...
```

## Vollständige Beispiele

Siehe [../examples/](../examples/) für komplette Produktions-Konfigurationen:

- [minimal-webserver.md](../examples/minimal-webserver.md) - Einfacher Webserver
- [nas-docker-stack.md](../examples/nas-docker-stack.md) - NAS mit Docker
- [development-server.md](../examples/development-server.md) - Dev-Server
