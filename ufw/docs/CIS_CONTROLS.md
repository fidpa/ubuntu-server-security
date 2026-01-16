<!--
Copyright (c) 2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# CIS Benchmark Controls - UFW

CIS Ubuntu 24.04 LTS Benchmark v1.0.0 - Section 3.5 (Host Based Firewall)

## Übersicht

| Control | Description | Level | Status |
|---------|-------------|-------|--------|
| 3.5.1.1 | Ensure ufw is installed | L1 | ✅ |
| 3.5.1.2 | Ensure iptables-persistent is not installed | L1 | ✅ |
| 3.5.1.3 | Ensure ufw service is enabled | L1 | ✅ |
| 3.5.1.4 | Ensure loopback traffic is configured | L1 | ✅ |
| 3.5.1.5 | Ensure outbound connections are configured | L1 | ✅ |
| 3.5.1.6 | Ensure firewall rules for open ports | L1 | ✅ |
| 3.5.1.7 | Ensure default deny policy | L1 | ✅ |

**Zusätzlich empfohlen**:

| Control | Description | Level | Status |
|---------|-------------|-------|--------|
| 3.1.1 | Ensure IPv6 is disabled | L2 | ✅ (optional) |

## Control Details

### 3.5.1.1 - UFW installiert

**Beschreibung**: UFW (Uncomplicated Firewall) muss installiert sein.

**Audit**:
```bash
dpkg -l | grep ufw
# Erwartet: ii  ufw  ...
```

**Remediation**:
```bash
sudo apt update
sudo apt install ufw
```

### 3.5.1.2 - iptables-persistent NICHT installiert

**Beschreibung**: `iptables-persistent` konfligiert mit UFW und darf nicht installiert sein.

**Audit**:
```bash
dpkg -l | grep iptables-persistent
# Erwartet: Keine Ausgabe
```

**Remediation**:
```bash
sudo apt purge iptables-persistent
```

**Rationale**: Beide Tools versuchen iptables-Regeln zu verwalten, was zu Konflikten führt.

### 3.5.1.3 - UFW Service enabled

**Beschreibung**: Der UFW-Service muss aktiviert und laufend sein.

**Audit**:
```bash
systemctl is-enabled ufw
# Erwartet: enabled

systemctl is-active ufw
# Erwartet: active

sudo ufw status
# Erwartet: Status: active
```

**Remediation**:
```bash
sudo systemctl enable ufw
sudo ufw enable
```

### 3.5.1.4 - Loopback Traffic konfiguriert

**Beschreibung**: Loopback-Interface (localhost) Traffic muss erlaubt sein.

**Audit**:
```bash
sudo ufw status verbose
# Prüfen: Loopback in/out erlaubt
```

**Hinweis**: UFW konfiguriert Loopback automatisch korrekt bei Aktivierung.

**Manuelle Verifikation** (falls nötig):
```bash
sudo iptables -L INPUT -v -n | grep lo
sudo iptables -L OUTPUT -v -n | grep lo
```

### 3.5.1.5 - Outbound Connections konfiguriert

**Beschreibung**: Ausgehende Verbindungen müssen explizit erlaubt oder blockiert sein.

**Audit**:
```bash
sudo ufw status verbose | grep "Default:"
# Erwartet: Default: deny (incoming), allow (outgoing), ...
```

**Remediation**:
```bash
sudo ufw default allow outgoing
```

**Alternative** (restriktiver, Level 2):
```bash
sudo ufw default deny outgoing
sudo ufw allow out 53/udp  # DNS
sudo ufw allow out 80/tcp  # HTTP
sudo ufw allow out 443/tcp # HTTPS
sudo ufw allow out 123/udp # NTP
```

### 3.5.1.6 - Firewall Rules für Open Ports

**Beschreibung**: Jeder offene Port muss eine entsprechende Firewall-Regel haben.

**Audit**:
```bash
# 1. Offene Ports identifizieren
ss -tuln | grep LISTEN

# 2. UFW-Regeln prüfen
sudo ufw status numbered

# 3. Vergleichen: Jeder LISTEN-Port sollte in UFW erlaubt sein
```

**Remediation**: Für jeden benötigten Port eine Regel erstellen:
```bash
sudo ufw allow <PORT>/tcp comment 'Service Name'
```

**Best Practice**: Nur notwendige Ports öffnen (Principle of Least Privilege).

### 3.5.1.7 - Default Deny Policy

**Beschreibung**: Die Standard-Policy muss eingehende Verbindungen blockieren.

**Audit**:
```bash
sudo ufw status verbose | grep "Default:"
# Erwartet: Default: deny (incoming), ...
```

**Remediation**:
```bash
sudo ufw default deny incoming
```

## Zusätzliche Empfehlungen

### 3.1.1 - IPv6 deaktivieren (optional)

**Beschreibung**: Wenn IPv6 nicht verwendet wird, sollte es deaktiviert werden.

**Audit**:
```bash
grep "^IPV6" /etc/default/ufw
# Prüfen: IPV6=no
```

**Remediation**:
```bash
# /etc/default/ufw editieren
sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
sudo ufw reload
```

**Vorteil**: Reduziert die Angriffsfläche und die Anzahl der UFW-Regeln.

## Automatisierte Compliance-Prüfung

### Quick Check Script

```bash
#!/bin/bash
# CIS UFW Compliance Check

echo "=== CIS UFW Compliance Check ==="

# 3.5.1.1
echo -n "3.5.1.1 UFW installed: "
dpkg -l ufw &>/dev/null && echo "PASS" || echo "FAIL"

# 3.5.1.2
echo -n "3.5.1.2 iptables-persistent absent: "
! dpkg -l iptables-persistent &>/dev/null && echo "PASS" || echo "FAIL"

# 3.5.1.3
echo -n "3.5.1.3 UFW enabled: "
systemctl is-enabled ufw &>/dev/null && echo "PASS" || echo "FAIL"

# 3.5.1.7
echo -n "3.5.1.7 Default deny: "
sudo ufw status verbose | grep -q "deny (incoming)" && echo "PASS" || echo "FAIL"
```

### Vollständiger Check

Nutze das mitgelieferte Script: [../scripts/check-ufw-status.sh](../scripts/check-ufw-status.sh)

## Compliance-Matrix

| Control | Audit Command | Expected Result |
|---------|--------------|-----------------|
| 3.5.1.1 | `dpkg -l ufw` | Package installed |
| 3.5.1.2 | `dpkg -l iptables-persistent` | Not found |
| 3.5.1.3 | `systemctl is-enabled ufw` | enabled |
| 3.5.1.4 | Automatic | Loopback configured |
| 3.5.1.5 | `ufw status verbose` | allow (outgoing) |
| 3.5.1.7 | `ufw status verbose` | deny (incoming) |

## Häufige Compliance-Fehler

### Problem: iptables-persistent installiert

```bash
# Symptom
dpkg -l | grep iptables-persistent
ii  iptables-persistent  ...

# Fix
sudo apt purge iptables-persistent
sudo ufw reload
```

### Problem: Default Policy nicht deny

```bash
# Symptom
sudo ufw status verbose
Default: allow (incoming), ...

# Fix
sudo ufw default deny incoming
```

### Problem: Service nicht aktiv

```bash
# Symptom
systemctl is-active ufw
inactive

# Fix
sudo ufw enable
```

## Referenzen

- [CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [UFW Official Documentation](https://help.ubuntu.com/community/UFW)
- [Ubuntu Server Guide - Firewall](https://ubuntu.com/server/docs/security-firewall)
