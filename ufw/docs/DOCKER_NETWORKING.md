<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# Docker und UFW Networking

Docker und UFW haben eine komplizierte Beziehung. Dieses Dokument erklärt die Probleme und Lösungen.

## Das Problem

**Docker umgeht UFW!**

Docker manipuliert iptables direkt und fügt eigene Chains (`DOCKER`, `DOCKER-USER`) ein, die VOR UFW-Regeln verarbeitet werden.

### Beispiel

```bash
# UFW: Alles blockieren
sudo ufw default deny incoming

# Docker: Container auf Port 8080
docker run -p 8080:80 nginx

# Ergebnis: Port 8080 ist trotz UFW von außen erreichbar!
```

### Warum passiert das?

Docker verwendet die FORWARD-Chain und NAT-Regeln:

```
Packet → PREROUTING (NAT) → FORWARD (Docker) → Container
                                ↑
                        UFW INPUT wird umgangen!
```

```bash
# Docker-Chains anzeigen
sudo iptables -L -n | grep -A5 "Chain DOCKER"
```

## Lösungen

### Lösung 1: Service-Binding auf localhost (empfohlen)

**Beste Lösung für die meisten Use Cases.**

```yaml
# docker-compose.yml
services:
  app:
    ports:
      - "127.0.0.1:8080:8080"  # Nur localhost
```

**Dann Reverse Proxy nutzen**:
```
Client → UFW (443) → Nginx → localhost:8080 → Container
```

### Lösung 2: Host Network Mode

Container nutzt Host-Network direkt, UFW greift normal.

```yaml
services:
  app:
    network_mode: "host"
```

**Nachteile**:
- Keine Network-Isolation
- Port-Konflikte möglich
- Nicht für alle Container geeignet

### Lösung 3: DOCKER-USER Chain

Docker lässt die `DOCKER-USER` Chain für Custom-Regeln.

```bash
# Management-Netzwerk erlauben, Rest blockieren
sudo iptables -I DOCKER-USER -i eth0 -s 10.0.0.0/24 -j ACCEPT
sudo iptables -I DOCKER-USER -i eth0 -j DROP

# Regeln persistieren (NICHT via iptables-persistent!)
```

**Persistierung** (in `/etc/rc.local` oder systemd-Service):
```bash
#!/bin/bash
iptables -I DOCKER-USER -i eth0 -s 10.0.0.0/24 -j ACCEPT
iptables -I DOCKER-USER -i eth0 -j DROP
```

### Lösung 4: Docker Daemon konfigurieren

**iptables deaktivieren** (nicht empfohlen):

```json
// /etc/docker/daemon.json
{
  "iptables": false
}
```

**Nachteile**:
- Container-zu-Container Networking bricht
- NAT für Internetzugang funktioniert nicht
- Nur für sehr spezielle Setups

## Reverse Proxy Pattern (Best Practice)

### Architektur

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
            X     │ UFW blockt direkten Docker-Zugriff  │
                  └─────────────────────────────────────┘
```

### Nginx Konfiguration

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

### UFW Regeln

```bash
# Nur Nginx-Ports öffnen
sudo ufw allow 80/tcp comment 'HTTP (redirect)'
sudo ufw allow 443/tcp comment 'HTTPS (Nginx)'

# Docker-Ports NICHT öffnen (localhost-only)
```

## Defense-in-Depth

### Layer 1: UFW (Host-Level)

```bash
sudo ufw default deny incoming
sudo ufw allow 443/tcp
```

### Layer 2: Service-Binding

```yaml
ports:
  - "127.0.0.1:8080:8080"
```

### Layer 3: Network Segmentation

```yaml
# Separate Docker Networks
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # Kein Internet-Zugang
```

### Layer 4: Container Security

```yaml
services:
  db:
    networks:
      - backend  # Nur Backend-Network
    # KEINE ports: Definition (nicht exposed)
```

## Produktions-Beispiel: NAS mit Docker

### Architektur

- **Management Network** (10.0.0.0/24): Admin-Zugriff
- **Client LAN** (192.168.100.0/24): User-Zugriff
- **Docker Bridge**: Container-Isolation

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
      - "127.0.0.1:8080:80"  # Nur localhost!
    networks:
      - backend
    depends_on:
      - db

  portainer:
    image: portainer/portainer-ce
    ports:
      - "127.0.0.1:9000:9000"   # HTTP - nur localhost
      - "10.0.0.2:9443:9443"    # HTTPS - nur Management IP
    networks:
      - management

  db:
    image: postgres:15
    networks:
      - backend  # Kein Port-Expose!
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}

networks:
  frontend:
  backend:
    internal: true
  management:
```

### UFW Regeln

```bash
# Web (über Nginx Reverse Proxy)
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Portainer HTTPS (nur Management)
sudo ufw allow from 10.0.0.0/24 to any port 9443 proto tcp comment 'Portainer HTTPS'

# PostgreSQL: Kein UFW nötig (nicht exposed, nur Docker-internal)
```

## Troubleshooting

### Container von außen erreichbar obwohl UFW blockiert?

1. **Check Port-Binding**:
   ```bash
   docker port CONTAINER_NAME
   ```

2. **Auf 0.0.0.0 gebunden?** → Problem!
   ```
   0.0.0.0:8080 -> 80/tcp
   ```

3. **Fix**: localhost-only binden
   ```yaml
   ports:
     - "127.0.0.1:8080:80"
   ```

### DOCKER-USER Chain testen

```bash
# Aktuelle Regeln
sudo iptables -L DOCKER-USER -n -v

# Test-Regel (temporär)
sudo iptables -I DOCKER-USER -s 192.168.1.100 -j LOG --log-prefix "DOCKER-USER: "

# Log prüfen
sudo tail -f /var/log/kern.log | grep DOCKER-USER
```

### Docker-Chains Reset

Falls DOCKER-USER beschädigt:

```bash
# Docker-Service neustarten (erstellt Chains neu)
sudo systemctl restart docker
```

## Zusammenfassung

| Methode | Komplexität | Sicherheit | Empfohlen |
|---------|-------------|------------|-----------|
| localhost-Binding + Reverse Proxy | Niedrig | Hoch | ✅ Ja |
| DOCKER-USER Chain | Mittel | Mittel | Für Experten |
| Host Network Mode | Niedrig | Niedrig | Spezielle Fälle |
| iptables: false | Hoch | - | ❌ Nein |

**Best Practice**: Alle Container auf localhost binden und Nginx/Traefik als Reverse Proxy nutzen.
