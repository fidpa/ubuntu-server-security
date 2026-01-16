<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# UFW Setup Guide

## TL;DR (30 Sekunden)

```bash
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp
sudo ufw enable
sudo ufw status verbose
```

## Voraussetzungen

- Ubuntu 22.04 LTS oder 24.04 LTS
- Root/sudo Zugriff
- SSH-Zugang (VOR Aktivierung SSH-Regel erstellen!)

**Wichtig**: `iptables-persistent` darf NICHT installiert sein (Konflikt mit UFW):

```bash
dpkg -l | grep iptables-persistent
# Falls installiert:
sudo apt purge iptables-persistent
```

## Installation

### 1. UFW installieren

```bash
sudo apt update
sudo apt install ufw
```

### 2. Default Policies setzen

```bash
# Eingehende Verbindungen: DENY (alles blockieren)
sudo ufw default deny incoming

# Ausgehende Verbindungen: ALLOW (alles erlauben)
sudo ufw default allow outgoing

# Routed Traffic (nur für Router/Gateways relevant)
sudo ufw default deny routed
```

### 3. SSH-Regel (KRITISCH!)

**Vor Aktivierung IMMER SSH-Zugang sichern!**

```bash
# Option A: Rate-Limited (empfohlen)
sudo ufw limit 22/tcp comment 'SSH Rate-Limited'

# Option B: Standard Allow
sudo ufw allow 22/tcp comment 'SSH'

# Option C: Network-restricted (sicherste)
sudo ufw allow from 10.0.0.0/24 to any port 22 proto tcp comment 'SSH Management'
```

### 4. UFW aktivieren

```bash
sudo ufw enable
# Bestätigung mit 'y'
```

### 5. Status prüfen

```bash
# Übersicht
sudo ufw status verbose

# Mit Regel-Nummern (für Bearbeitung)
sudo ufw status numbered
```

## Basis-Konfiguration

### Web Server (HTTP/HTTPS)

```bash
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```

### Samba (File-Sharing)

```bash
sudo ufw allow from 10.0.0.0/24 to any port 139,445 proto tcp comment 'Samba Management'
sudo ufw allow from 192.168.100.0/24 to any port 139,445 proto tcp comment 'Samba LAN'
```

### Monitoring Ports

```bash
# Nur aus Management-Netzwerk
sudo ufw allow from 10.0.0.0/24 to any port 9090 proto tcp comment 'Prometheus'
sudo ufw allow from 10.0.0.0/24 to any port 3000 proto tcp comment 'Grafana'
```

## Drop-in Integration

Drop-ins sind vorgefertigte Regel-Sets für spezifische Use Cases.

```bash
# 1. Drop-in auswählen
cat drop-ins/10-webserver.rules

# 2. Regeln anwenden
source drop-ins/10-webserver.rules
# Oder einzeln ausführen:
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```

Verfügbare Drop-ins: [drop-ins/README.md](../drop-ins/README.md)

## IPv6 Deaktivierung (optional)

Falls IPv6 nicht benötigt wird (CIS 3.1.1):

```bash
# /etc/default/ufw editieren
sudo nano /etc/default/ufw

# Ändern:
IPV6=no

# UFW neu laden
sudo ufw reload
```

**Vorteil**: Weniger Regeln, kleinere Angriffsfläche.

## Logging konfigurieren

```bash
# Logging Level setzen (empfohlen: medium)
sudo ufw logging medium

# Log-Datei prüfen
sudo tail -f /var/log/ufw.log
```

| Level | Description |
|-------|-------------|
| off | Kein Logging |
| low | Blocked Packets |
| medium | + Invalid + New Connections |
| high | + Rate-Limited Packets |
| full | Alles |

## Verifikation

### CIS Benchmark Checks

```bash
# 3.5.1.1 - UFW installiert
dpkg -l | grep ufw

# 3.5.1.3 - Service aktiv
systemctl is-enabled ufw
systemctl is-active ufw

# 3.5.1.7 - Default Deny
sudo ufw status verbose | grep -E "^Default:"
```

### Regel-Validierung

```bash
# Alle Regeln anzeigen
sudo ufw status numbered

# Regel testen (von anderem Host)
nc -zv SERVER_IP 22
nc -zv SERVER_IP 80
```

## Regeln verwalten

### Regel hinzufügen

```bash
# Mit Port
sudo ufw allow 8080/tcp comment 'Custom Service'

# Mit Service-Name
sudo ufw allow ssh
sudo ufw allow http

# Network-restricted
sudo ufw allow from 192.168.1.0/24 to any port 3306
```

### Regel löschen

```bash
# Nach Nummer
sudo ufw status numbered
sudo ufw delete 5

# Nach Regel
sudo ufw delete allow 8080/tcp
```

### Regel einfügen (an Position)

```bash
# An Position 1 einfügen
sudo ufw insert 1 deny from 10.0.0.50 to any
```

## Troubleshooting Quick Links

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Häufige Probleme
- [DOCKER_NETWORKING.md](DOCKER_NETWORKING.md) - Docker/UFW Issues
- [CIS_CONTROLS.md](CIS_CONTROLS.md) - Compliance-Checks

## Automatisierung

### systemd Service

UFW läuft als systemd Service:

```bash
# Status
sudo systemctl status ufw

# Service-File prüfen
systemctl cat ufw
```

### NOPASSWD für Status-Checks

Für automatisierte Monitoring-Scripts:

```bash
# /etc/sudoers.d/ufw-monitoring
marc ALL=(ALL) NOPASSWD: /usr/sbin/ufw status
marc ALL=(ALL) NOPASSWD: /usr/sbin/ufw status verbose
marc ALL=(ALL) NOPASSWD: /usr/sbin/ufw status numbered
```

Details: [../scripts/check-ufw-status.sh](../scripts/check-ufw-status.sh)

## Backup & Recovery

### Regeln exportieren

```bash
# UFW Konfiguration sichern
sudo cp -r /etc/ufw /etc/ufw.backup.$(date +%Y%m%d)
sudo cp /etc/default/ufw /etc/default/ufw.backup.$(date +%Y%m%d)
```

### Regeln importieren

```bash
# Aus Backup wiederherstellen
sudo cp -r /etc/ufw.backup.YYYYMMDD/* /etc/ufw/
sudo ufw reload
```

## Nächste Schritte

1. [CIS_CONTROLS.md](CIS_CONTROLS.md) - Compliance sicherstellen
2. [DOCKER_NETWORKING.md](DOCKER_NETWORKING.md) - Docker-Integration
3. [../drop-ins/](../drop-ins/) - Passende Templates wählen
4. [../examples/](../examples/) - Produktionsbeispiele
