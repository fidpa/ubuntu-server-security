<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# UFW Troubleshooting

Häufige Probleme und deren Lösungen.

## Inhaltsverzeichnis

- [SSH-Lockout](#ssh-lockout)
- [Service nicht erreichbar](#service-nicht-erreichbar)
- [Docker umgeht UFW](#docker-umgeht-ufw)
- [Rate-Limiting zu streng](#rate-limiting-zu-streng)
- [Logging-Probleme](#logging-probleme)
- [Regel-Konflikte](#regel-konflikte)
- [IPv6 Probleme](#ipv6-probleme)

## SSH-Lockout

### Problem

Nach `ufw enable` kein SSH-Zugang mehr.

### Ursache

SSH-Regel wurde nicht VOR Aktivierung erstellt.

### Lösung

**Falls physischer/Konsolen-Zugang vorhanden**:
```bash
# UFW deaktivieren
sudo ufw disable

# SSH-Regel hinzufügen
sudo ufw allow 22/tcp

# UFW wieder aktivieren
sudo ufw enable
```

**Über Serial/IPMI Konsole**:
```bash
sudo ufw status
sudo ufw allow ssh
sudo ufw reload
```

### Prävention

**IMMER** SSH-Regel VOR Aktivierung erstellen:
```bash
sudo ufw allow 22/tcp
# DANN erst:
sudo ufw enable
```

## Service nicht erreichbar

### Problem

Ein Service ist trotz laufendem Prozess nicht von außen erreichbar.

### Diagnose

```bash
# 1. Service läuft?
systemctl status <service>
ss -tuln | grep <PORT>

# 2. UFW-Regel vorhanden?
sudo ufw status numbered | grep <PORT>

# 3. Log prüfen
sudo grep "UFW BLOCK" /var/log/ufw.log | tail -20
```

### Lösung

```bash
# Regel hinzufügen
sudo ufw allow <PORT>/tcp comment 'Service Name'

# Spezifischer (network-restricted)
sudo ufw allow from 10.0.0.0/24 to any port <PORT> proto tcp
```

### Debug-Methode

```bash
# Von Client:
nc -zv SERVER_IP PORT

# Auf Server: Live-Log
sudo tail -f /var/log/ufw.log | grep <PORT>
```

## Docker umgeht UFW

### Problem

Docker-Container sind trotz UFW-Regeln von außen erreichbar.

### Ursache

Docker manipuliert iptables direkt und fügt DOCKER/DOCKER-USER Chains VOR UFW ein.

### Diagnose

```bash
# Docker-Chains prüfen
sudo iptables -L DOCKER -n -v
sudo iptables -L DOCKER-USER -n -v
```

### Lösungen

**Option 1: Service auf localhost binden**

```yaml
# docker-compose.yml
ports:
  - "127.0.0.1:8080:8080"  # Nur localhost
  # NICHT: "8080:8080"     # Alle Interfaces!
```

**Option 2: DOCKER-USER Chain nutzen**

```bash
# Nur aus Management-Netzwerk erlauben
sudo iptables -I DOCKER-USER -i eth0 -s 10.0.0.0/24 -j ACCEPT
sudo iptables -I DOCKER-USER -i eth0 -j DROP
```

**Option 3: Reverse Proxy**

```
Client → UFW (Port 443) → Nginx → Container (localhost:8080)
```

Details: [DOCKER_NETWORKING.md](DOCKER_NETWORKING.md)

## Rate-Limiting zu streng

### Problem

Legitime SSH-Verbindungen werden geblockt (bei Automation, Deployment).

### Symptom

```bash
sudo grep "UFW LIMIT BLOCK" /var/log/ufw.log
# [UFW LIMIT BLOCK] ... DPT=22 ...
```

### Ursache

UFW LIMIT: max 6 Verbindungen pro 30 Sekunden.

### Lösungen

**Option 1: LIMIT durch ALLOW ersetzen**

```bash
sudo ufw delete limit 22/tcp
sudo ufw allow 22/tcp
```

**Option 2: Network-restricted ohne Limit**

```bash
sudo ufw delete limit 22/tcp
sudo ufw allow from 10.0.0.0/24 to any port 22 proto tcp comment 'SSH Management'
```

**Option 3: Whitelist + Limit**

```bash
# Automation-Server ohne Limit
sudo ufw insert 1 allow from 10.0.0.10 to any port 22 proto tcp
# Rest mit Limit
sudo ufw limit 22/tcp
```

## Logging-Probleme

### Problem: Log-Datei fehlt/leer

```bash
ls -la /var/log/ufw.log
# Datei nicht vorhanden
```

### Lösung

```bash
# Logging aktivieren
sudo ufw logging on
sudo ufw logging medium

# rsyslog konfiguriert?
grep -r "ufw" /etc/rsyslog.d/
```

### Problem: Zu viel Logging

```bash
# Log wächst zu schnell

# Logging reduzieren
sudo ufw logging low

# Oder temporär deaktivieren
sudo ufw logging off
```

### Log-Rotation

```bash
# /etc/logrotate.d/ufw (Standard bei Ubuntu)
/var/log/ufw.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

## Regel-Konflikte

### Problem: Regel hat keine Wirkung

**Ursache**: Reihenfolge der Regeln (first match wins).

### Diagnose

```bash
sudo ufw status numbered
```

```
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 22/tcp                     DENY IN     10.0.0.50
```

**Problem**: Regel 2 wird nie erreicht, da Regel 1 schon matcht.

### Lösung

```bash
# Spezifische Regel VOR allgemeine
sudo ufw delete 2
sudo ufw insert 1 deny from 10.0.0.50 to any port 22
```

### Best Practice

Regelreihenfolge:
1. DENY spezifische IPs/Hosts
2. ALLOW spezifische Netzwerke
3. LIMIT für Rate-Limited Services
4. ALLOW allgemein

## IPv6 Probleme

### Problem: Doppelte Regeln (IPv4 + IPv6)

```bash
sudo ufw status
To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
22/tcp (v6)                ALLOW       Anywhere (v6)
```

### Lösung (IPv6 deaktivieren)

```bash
# /etc/default/ufw
IPV6=no

sudo ufw reload
```

### Problem: IPv6 Service nicht erreichbar

Falls IPv6 benötigt wird:

```bash
# /etc/default/ufw
IPV6=yes

# Explizite IPv6-Regel
sudo ufw allow from 2001:db8::/32 to any port 22 proto tcp
```

## Recovery-Befehle

### UFW komplett zurücksetzen

```bash
sudo ufw reset
# Löscht ALLE Regeln!

# Basis-Setup wiederherstellen
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp
sudo ufw enable
```

### Backup vor Änderungen

```bash
# UFW-State sichern
sudo cp /etc/ufw/user.rules /etc/ufw/user.rules.backup
sudo cp /etc/ufw/user6.rules /etc/ufw/user6.rules.backup
```

### Aus Backup wiederherstellen

```bash
sudo cp /etc/ufw/user.rules.backup /etc/ufw/user.rules
sudo ufw reload
```

## Hilfreiche Befehle

| Befehl | Beschreibung |
|--------|--------------|
| `sudo ufw status verbose` | Vollständiger Status |
| `sudo ufw status numbered` | Mit Regel-Nummern |
| `sudo ufw show raw` | Raw iptables Output |
| `sudo ufw show added` | Hinzugefügte Regeln |
| `sudo tail -f /var/log/ufw.log` | Live-Log |
| `sudo ufw reload` | Regeln neu laden |
| `sudo ufw reset` | Alle Regeln löschen |
