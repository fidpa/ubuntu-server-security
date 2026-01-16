#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# USB Activity Monitor
#
# Purpose: Checks auditd logs for USB events and sends alerts
# Features:
# - Analyzes auditd logs for USB-related events
# - Detects module loading/unloading attempts
# - Detects blacklist file tampering
# - E-mail alerts on bypass attempts
#
# Usage:
#   ./check-usb-activity.sh
#
# Exit Codes:
#   0 - No activity detected
#   1 - USB activity detected
#
# Documentation: https://github.com/fidpa/ubuntu-server-security/tree/main/usb-defense
# Version: 2.0.0
# Created: 2026-01-16

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
readonly SCRIPT_DIR

SCRIPT_NAME="$(basename "$0" .sh)"
readonly SCRIPT_NAME

readonly VERSION="2.0.0"
readonly ALERT_EMAIL="${USB_DEFENSE_ALERT_EMAIL:-root}"
readonly LOOKBACK_MINUTES="${USB_DEFENSE_LOOKBACK_MINUTES:-6}"

# Inline logging functions (no external dependencies)
log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_warning() { echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }

send_usb_alert() {
    local subject="$1"
    local body="$2"

    if command -v mail >/dev/null 2>&1; then
        echo "$body" | mail -s "$subject" "${ALERT_EMAIL}"
        return
    fi

    if command -v msmtp >/dev/null 2>&1; then
        echo -e "Subject: $subject\n\n$body" | msmtp "${ALERT_EMAIL}"
        return
    fi

    log_warning "No mail command available - alert logged only"
    log_info "ALERT: $subject"
}

check_usb_events() {
    local since_time
    since_time=$(date -d "$LOOKBACK_MINUTES minutes ago" "+%Y-%m-%d %H:%M:%S")

    local usb_events
    usb_events=$(sudo ausearch -ts "$since_time" -k usb_device_activity,usb_module_loading,usb_blacklist_tampering,usb_modprobe 2>/dev/null | grep -v "^<no matches>" || true)

    if [[ -n "$usb_events" ]]; then
        log_warning "USB activity detected in last $LOOKBACK_MINUTES minutes"

        local event_summary
        event_summary=$(echo "$usb_events" | grep -E "type=|msg=audit|exe=|key=" | head -20)

        local email_body
        email_body="USB Activity Detected on $(hostname)

Time Window: Last $LOOKBACK_MINUTES minutes
Detection Time: $(date)

=== Event Summary ===
$event_summary

=== Full Audit Log ===
$usb_events

=== Current USB Devices ===
$(lsusb 2>/dev/null || echo "lsusb not available")

=== Loaded USB Modules ===
$(lsmod | grep usb || echo "No USB modules loaded")

=== Investigation Commands ===
sudo ausearch -k usb_device_activity -i
sudo ausearch -k usb_module_loading -i
sudo ausearch -k usb_blacklist_tampering -i
"

        send_usb_alert "USB Activity Detected - $(hostname)" "$email_body"
        log_success "Alert email sent to $ALERT_EMAIL"

        return 1
    else
        log_info "No USB activity detected (last $LOOKBACK_MINUTES minutes)"
        return 0
    fi
}

main() {
    log_info "USB Activity Monitor v${VERSION} started"

    check_usb_events
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "Check completed - no activity detected"
    else
        log_warning "Check completed - USB activity found and reported"
    fi

    return $exit_code
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
