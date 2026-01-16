#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# fail2ban Telegram Alert Sender
# Sends ban/unban notifications to Telegram with IP context
#
# Features:
# - Real-time ban/unban notifications
# - IP context (Country, ISP via whois)
# - Rate limiting (5min cooldown per IP)
# - HTML-formatted messages
# - Device-agnostic (works on any server)
#
# Usage:
#   telegram-send.sh ban <ip> <failures> <jail> <bantime>
#   telegram-send.sh unban <ip> <jail>
#
# Requirements:
#   - curl (for Telegram API)
#   - whois (optional, for IP context)
#   - .env.secrets with TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID
#
# Version: 2.0.0 (Device-agnostic)
# Original: Pi 5 Router fail2ban integration

set -uo pipefail

# ============================================
# Configuration
# ============================================

# Device-agnostic paths (auto-detect from hostname)
readonly DEVICE_NAME="${DEVICE_NAME:-$(hostname -s)}"
readonly SECRETS_FILE="${SECRETS_FILE:-/etc/${DEVICE_NAME}/.env.secrets}"
readonly ALERT_STATE_DIR="${ALERT_STATE_DIR:-/var/lib/fail2ban/telegram-alerts}"
readonly LOG_FILE="${LOG_FILE:-/var/log/${DEVICE_NAME}/fail2ban-telegram.log}"

# Alert settings
readonly ALERT_COOLDOWN=300  # 5 minutes between alerts for same IP

# Create required directories
mkdir -p "$ALERT_STATE_DIR" 2>/dev/null || true
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# ============================================
# Load Credentials
# ============================================

if [[ -f "$SECRETS_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SECRETS_FILE"
else
    printf '[%s] ERROR: Secrets file not found: %s\n' "$(date)" "$SECRETS_FILE" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
fi

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] || [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    printf '[%s] ERROR: Missing Telegram credentials in %s\n' "$(date)" "$SECRETS_FILE" >> "$LOG_FILE" 2>/dev/null || true
    exit 1
fi

# ============================================
# Functions
# ============================================

# Device/Host detection for alert prefix
get_alert_prefix() {
    case "$(hostname -s)" in
        pi-router) echo "Pi5-Router" ;;
        nas)       echo "NAS-Server" ;;
        *)         echo "$(hostname -s)" ;;
    esac
}

readonly ALERT_PREFIX="$(get_alert_prefix)"
readonly HOST_IP=$(hostname -I | awk '{print $1}' || echo "unknown")
readonly HOST_NAME=$(hostname || echo "unknown")

# Rate limiting check
should_send_alert() {
    local alert_type="$1"
    local alert_file="${ALERT_STATE_DIR}/${alert_type}.last_alert"

    if [[ ! -f "$alert_file" ]]; then
        printf '%s\n' "$(date +%s)" > "$alert_file"
        return 0
    fi

    local last_alert
    last_alert=$(cat "$alert_file" 2>/dev/null || echo "0")
    local current_time
    current_time=$(date +%s)
    local time_diff=$((current_time - last_alert))

    if [[ $time_diff -ge $ALERT_COOLDOWN ]]; then
        printf '%s\n' "$current_time" > "$alert_file"
        return 0
    fi

    printf '[%s] INFO: Rate-limited: %s (cooldown: %ss remaining)\n' \
        "$(date)" "$alert_type" "$((ALERT_COOLDOWN - time_diff))" >> "$LOG_FILE" 2>/dev/null || true
    return 1
}

# Get IP context (country, ISP)
get_ip_context() {
    local ip="$1"
    local country="Unknown"
    local isp="Unknown"

    if command -v whois &>/dev/null; then
        local whois_output
        whois_output=$(whois "$ip" 2>/dev/null || echo "")
        country=$(printf '%s\n' "$whois_output" | grep -iE "^(Country|country):" | head -1 | awk '{print $2}' || echo "Unknown")
        isp=$(printf '%s\n' "$whois_output" | grep -iE "^(OrgName|org-name|descr):" | head -1 | cut -d: -f2- | xargs || echo "Unknown")
    fi

    printf '%s|%s\n' "$country" "$isp"
    return 0
}

# Send telegram message
send_telegram() {
    local message="$1"

    if curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${message}" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true" \
        --max-time 10 --retry 3 --retry-delay 2 \
        >/dev/null 2>&1; then
        printf '[%s] INFO: Alert sent successfully\n' "$(date)" >> "$LOG_FILE" 2>/dev/null || true
        return 0
    else
        printf '[%s] ERROR: Alert failed to send\n' "$(date)" >> "$LOG_FILE" 2>/dev/null || true
        return 1
    fi
}

# ============================================
# Main
# ============================================

main() {
    local action="$1"
    local ip="$2"

    case "$action" in
        ban)
            local failures="$3"
            local jail_name="$4"
            local ban_time="$5"

            if ! should_send_alert "ban_${ip}"; then
                exit 0
            fi

            local ip_context
            ip_context=$(get_ip_context "$ip")
            local country
            country=$(printf '%s\n' "$ip_context" | cut -d'|' -f1)
            local isp
            isp=$(printf '%s\n' "$ip_context" | cut -d'|' -f2)

            local message="🚨 <b>[$ALERT_PREFIX] fail2ban Ban</b>

<b>IP:</b> $ip
<b>Country:</b> $country 🌍
<b>ISP:</b> $isp
<b>Failures:</b> $failures attempts
<b>Jail:</b> $jail_name
<b>Ban-Time:</b> ${ban_time}s

<i>Time: $(date '+%Y-%m-%d %H:%M:%S')</i>
<i>Host: $HOST_IP ($HOST_NAME)</i>"

            if send_telegram "$message"; then
                printf '[%s] INFO: Ban alert sent for %s (jail: %s)\n' "$(date)" "$ip" "$jail_name" >> "$LOG_FILE" 2>/dev/null || true
            fi
            ;;

        unban)
            local jail_name="$3"

            if ! should_send_alert "unban_${ip}"; then
                exit 0
            fi

            local message="✅ <b>[$ALERT_PREFIX] fail2ban Unban</b>

<b>IP:</b> $ip
<b>Jail:</b> $jail_name
<b>Status:</b> Ban lifted

<i>Time: $(date '+%Y-%m-%d %H:%M:%S')</i>
<i>Host: $HOST_IP ($HOST_NAME)</i>"

            if send_telegram "$message"; then
                printf '[%s] INFO: Unban alert sent for %s (jail: %s)\n' "$(date)" "$ip" "$jail_name" >> "$LOG_FILE" 2>/dev/null || true
            fi
            ;;

        *)
            printf '[%s] ERROR: Unknown action: %s\n' "$(date)" "$action" >> "$LOG_FILE" 2>/dev/null || true
            exit 1
            ;;
    esac

    return 0
}

# Execute main function
main "$@"
