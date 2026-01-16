#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# fail2ban GeoIP Whitelist Script
# Country-based IP whitelisting for fail2ban ignorecommand
#
# Whitelist Countries: DE (Germany), AT (Austria), CH (Switzerland),
#                      NL (Netherlands), FR (France), BE (Belgium), LU (Luxembourg)
#                      + Private IP ranges (RFC1918)
#
# Returns:
#   Exit 0: IP in whitelist (allowed)
#   Exit 1: IP NOT in whitelist (banned)
#
# Usage:
#   geoip-whitelist.sh <ip>
#
# Requirements:
#   - geoip-bin package (provides geoiplookup)
#   - geoip-database package (country database)
#
# Installation:
#   sudo apt install geoip-bin geoip-database
#
# Configuration:
#   Set GEOIP_WHITELIST environment variable to customize countries:
#   export GEOIP_WHITELIST="DE|AT|CH|NL|FR"
#
# Version: 2.0.0 (Device-agnostic)

set -uo pipefail

# ============================================
# Configuration
# ============================================

readonly IP="${1:-}"
readonly DEVICE_NAME="${DEVICE_NAME:-$(hostname -s)}"
readonly LOG_FILE="${LOG_FILE:-/var/log/${DEVICE_NAME}/fail2ban-geoip.log}"

# Whitelist countries (configurable via environment)
readonly WHITELIST_COUNTRIES="${GEOIP_WHITELIST:-DE|AT|CH|NL|FR|BE|LU}"

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# ============================================
# Validation
# ============================================

if [[ -z "$IP" ]]; then
    printf '[%s] ERROR: No IP provided\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
fi

# ============================================
# Check if IP is Private (RFC1918 + Loopback)
# ============================================

if [[ "$IP" =~ ^10\. ]] || \
   [[ "$IP" =~ ^192\.168\. ]] || \
   [[ "$IP" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]] || \
   [[ "$IP" =~ ^127\. ]]; then
    printf '[%s] IP=%s PRIVATE_IP=true\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$IP" >> "$LOG_FILE" 2>/dev/null || true
    printf '[%s] ALLOW: %s (Private IP)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$IP" >> "$LOG_FILE" 2>/dev/null || true
    exit 0
fi

# ============================================
# GeoIP Lookup for Public IPs
# ============================================

COUNTRY=$(geoiplookup "$IP" 2>/dev/null | grep -E "$WHITELIST_COUNTRIES" || echo "")

# Log the lookup
printf '[%s] IP=%s COUNTRY=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" \
    "$IP" \
    "${COUNTRY:-NOT_IN_WHITELIST}" >> "$LOG_FILE" 2>/dev/null || true

# ============================================
# Return Exit Code
# ============================================

if [[ -n "$COUNTRY" ]]; then
    printf '[%s] ALLOW: %s (Whitelist match)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$IP" >> "$LOG_FILE" 2>/dev/null || true
    exit 0
else
    printf '[%s] DENY: %s (Not in whitelist)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$IP" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
fi
