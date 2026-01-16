<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# Minimal Web Server UFW Configuration

Minimale UFW-Konfiguration für einen einfachen Web-Server (Nginx/Apache).

## Use Case

- Statische Website
- Simple Reverse Proxy
- Single-Application Server
- Low-Attack-Surface Setup

## Architektur

```
                    ┌──────────────────────────┐
                    │     Ubuntu Server        │
                    │                          │
Internet ──────────►│  UFW (22, 80, 443)      │
                    │         │                │
                    │         ▼                │
                    │     Nginx/Apache         │
                    │         │                │
                    │         ▼                │
                    │    Application          │
                    └──────────────────────────┘
```

## Features

- ✅ SSH mit Rate-Limiting (Brute-Force-Schutz)
- ✅ HTTP (Redirect zu HTTPS)
- ✅ HTTPS
- ✅ IPv6 deaktiviert (optional)
- ✅ Default Deny Policy
- ✅ CIS Benchmark 3.5.1.x compliant

## Regeln

**Total: 6 Regeln (3 Services)**

| Port | Protocol | Action | Comment |
|------|----------|--------|---------|
| 22 | TCP | LIMIT | SSH Rate-Limited |
| 80 | TCP | ALLOW | HTTP |
| 443 | TCP | ALLOW | HTTPS |

## Deployment

### 1. UFW Installation & Basis-Setup

```bash
# Installation
sudo apt update && sudo apt install ufw

# Default Policies
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

### 2. Regeln hinzufügen

```bash
# SSH mit Rate-Limiting (WICHTIG: VOR ufw enable!)
sudo ufw limit 22/tcp comment 'SSH Rate-Limited'

# HTTP/HTTPS
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```

### 3. IPv6 deaktivieren (optional)

```bash
# IPv6 deaktivieren (reduziert Angriffsfläche)
sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
```

### 4. UFW aktivieren

```bash
sudo ufw enable
```

### 5. Verifikation

```bash
# Status prüfen
sudo ufw status verbose

# Erwartete Ausgabe:
# Status: active
# Logging: on (low)
# Default: deny (incoming), allow (outgoing), deny (routed)
#
# To                         Action      From
# --                         ------      ----
# 22/tcp                     LIMIT       Anywhere
# 80/tcp                     ALLOW       Anywhere
# 443/tcp                    ALLOW       Anywhere
```

## Varianten

### A) Network-Restricted SSH

Für Server im privaten Netzwerk:

```bash
# SSH nur aus Management-Netzwerk
sudo ufw delete limit 22/tcp
sudo ufw allow from 10.0.0.0/24 to any port 22 proto tcp comment 'SSH Management'
```

### B) Mit HTTP/3 (QUIC)

Für moderne Browser-Unterstützung:

```bash
# HTTP/3 über UDP
sudo ufw allow 443/udp comment 'HTTPS QUIC'
```

### C) Ohne HTTP (HTTPS-only)

Falls kein HTTP-Redirect benötigt:

```bash
# Nur HTTPS
sudo ufw delete allow 80/tcp
```

## CIS Compliance

| Control | Status | Verifikation |
|---------|--------|--------------|
| 3.5.1.1 | ✅ | `dpkg -l ufw` |
| 3.5.1.3 | ✅ | `systemctl is-enabled ufw` |
| 3.5.1.7 | ✅ | `ufw status verbose \| grep "deny (incoming)"` |

## Logging

```bash
# Logging aktivieren (empfohlen: low oder medium)
sudo ufw logging low

# Log prüfen
sudo tail -f /var/log/ufw.log
```

## Troubleshooting

### SSH-Verbindung verweigert?

```bash
# Von anderem Terminal/Konsole:
sudo ufw status numbered
# SSH-Regel vorhanden?

# Falls nicht:
sudo ufw allow 22/tcp
```

### Website nicht erreichbar?

```bash
# Port 80/443 blockiert?
sudo grep "UFW BLOCK" /var/log/ufw.log | grep "DPT=80\|DPT=443"

# Nginx läuft?
systemctl status nginx
ss -tuln | grep -E ":80|:443"
```

## Nächste Schritte

- [SETUP.md](../docs/SETUP.md) - Detaillierte Anleitung
- [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) - Problemlösungen
- [../drop-ins/](../drop-ins/) - Zusätzliche Regeln
