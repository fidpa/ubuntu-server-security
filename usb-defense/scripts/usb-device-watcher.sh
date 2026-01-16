#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# USB Device Watcher
#
# Purpose: Continuously monitor for new USB devices (polling-based)
# Features:
# - Polling-based detection (2-second intervals)
# - State tracking to identify NEW devices only
# - HID filtering (keyboards/mice excluded)
# - Rate limiting (1-hour cooldown per device)
# - E-mail alerts for non-HID devices
#
# Usage:
#   ./usb-device-watcher.sh
#
# Exit Codes:
#   0 - Success
#   1 - Fatal error
#
# Documentation: https://github.com/fidpa/ubuntu-server-security/tree/main/usb-defense
# Version: 3.0.0
# Created: 2026-01-16

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
readonly SCRIPT_DIR

SCRIPT_NAME="$(basename "$0" .sh)"
readonly SCRIPT_NAME

readonly VERSION="3.0.0"
readonly STATE_DIR="${USB_DEFENSE_STATE_DIR:-/var/lib/usb-defense}"
readonly STATE_FILE="${STATE_DIR}/usb-devices.state"
readonly LOCK_FILE="${STATE_DIR}/usb-device-watcher.lock"
readonly ALERT_COOLDOWN_FILE="${STATE_DIR}/usb-alert-cooldown"
readonly POLL_INTERVAL="${USB_DEFENSE_POLL_INTERVAL:-2}"
readonly WARMUP_CYCLES="${USB_DEFENSE_WARMUP_CYCLES:-5}"
readonly ALERT_COOLDOWN="${USB_DEFENSE_COOLDOWN:-3600}"
readonly ALERT_EMAIL="${USB_DEFENSE_ALERT_EMAIL:-root}"

readonly STATE_LINE_PATTERN='^[0-9]{3}:[0-9]{3}:[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4}$'

WARMUP_COUNTER=0
WARMUP_LOGGED=false

# Inline logging functions (no external dependencies)
log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_warning() { echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }

ensure_state_dir() {
    local state_dir
    state_dir=$(dirname "$STATE_FILE")

    if [[ ! -d "$state_dir" ]]; then
        if ! mkdir -p "$state_dir" 2>/dev/null; then
            log_error "FATAL: Cannot create state directory: $state_dir"
            exit 1
        fi
        chmod 755 "$state_dir"
    fi

    if ! touch "${state_dir}/.write-test" 2>/dev/null; then
        log_error "FATAL: No write permission for state directory: $state_dir"
        exit 1
    fi
    rm -f "${state_dir}/.write-test"

    log_info "State directory OK: $state_dir"
}

get_usb_devices() {
    local output
    if ! output=$(lsusb 2>&1); then
        log_warning "lsusb command failed - skipping this cycle"
        return 1
    fi

    if [[ -z "$output" ]]; then
        echo ""
        return 0
    fi

    echo "$output" | awk '{gsub(/:$/, "", $4); print $2":"$4":"$6}' | sort
}

write_state_file() {
    local content="$1"
    local temp_file="${STATE_FILE}.tmp.$$"

    if ! echo "$content" > "$temp_file" 2>/dev/null; then
        log_error "FATAL: Cannot write temp state file: $temp_file"
        log_error "This would cause alert flood - stopping service!"
        rm -f "$temp_file" 2>/dev/null
        exit 1
    fi

    if ! mv "$temp_file" "$STATE_FILE" 2>/dev/null; then
        log_error "FATAL: Cannot rename state file: $temp_file -> $STATE_FILE"
        log_error "This would cause alert flood - stopping service!"
        rm -f "$temp_file" 2>/dev/null
        exit 1
    fi
}

read_state_file() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo ""
        return 0
    fi

    local content invalid_count=0
    content=$(cat "$STATE_FILE" 2>/dev/null) || { echo ""; return 0; }

    local valid_lines=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ $STATE_LINE_PATTERN ]]; then
            valid_lines+="$line"$'\n'
        else
            ((invalid_count++)) || true
        fi
    done <<< "$content"

    if [[ $invalid_count -gt 0 ]]; then
        log_warning "State file had $invalid_count invalid lines (ignored)"
    fi

    echo "${valid_lines%$'\n'}"
}

detect_new_devices() {
    local current_devices="$1"
    local previous_devices="$2"

    comm -13 <(printf '%s\n' "$previous_devices" | sort) \
             <(printf '%s\n' "$current_devices" | sort) 2>/dev/null || echo ""
}

is_in_cooldown() {
    local device_hash="$1"
    local cooldown_file="${ALERT_COOLDOWN_FILE}.${device_hash}"

    if [[ -f "$cooldown_file" ]]; then
        local last_alert
        last_alert=$(cat "$cooldown_file" 2>/dev/null || echo "0")
        local now
        now=$(date +%s)
        local diff=$((now - last_alert))

        if [[ $diff -lt $ALERT_COOLDOWN ]]; then
            log_info "Device in cooldown (${diff}s < ${ALERT_COOLDOWN}s), skipping alert"
            return 0
        fi
    fi

    return 1
}

set_cooldown() {
    local device_hash="$1"
    local cooldown_file="${ALERT_COOLDOWN_FILE}.${device_hash}"

    if ! date +%s > "$cooldown_file" 2>/dev/null; then
        log_error "Cannot write cooldown file: $cooldown_file - fail-closed (no alert)"
        return 1
    fi
    return 0
}

html_escape() {
    local text="$1"
    text="${text//&/&amp;}"
    text="${text//</&lt;}"
    text="${text//>/&gt;}"
    text="${text//\"/&quot;}"
    text="${text//\'/&#39;}"
    echo "$text"
}

is_hid_device() {
    local bus="$1"
    local dev="$2"

    local sysfs_path
    for sysfs_path in /sys/bus/usb/devices/*; do
        [[ -d "$sysfs_path" ]] || continue

        local busnum devnum
        busnum=$(cat "$sysfs_path/busnum" 2>/dev/null) || continue
        devnum=$(cat "$sysfs_path/devnum" 2>/dev/null) || continue

        if [[ "$((10#$bus))" == "$busnum" ]] && [[ "$((10#$dev))" == "$devnum" ]]; then
            local iface_class
            for iface in "$sysfs_path"/*:*/bInterfaceClass; do
                [[ -f "$iface" ]] || continue
                iface_class=$(cat "$iface" 2>/dev/null) || continue
                if [[ "$iface_class" == "03" ]] || [[ "$iface_class" == "09" ]]; then
                    return 0
                fi
            done
            break
        fi
    done

    return 1
}

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

send_alert_for_device() {
    local device_info="$1"

    local bus dev vidpid
    bus=$(echo "$device_info" | cut -d: -f1)
    dev=$(echo "$device_info" | cut -d: -f2)
    vidpid=$(echo "$device_info" | cut -d: -f3-)

    local device_hash
    device_hash=$(echo "$vidpid" | md5sum | cut -d' ' -f1)

    if is_in_cooldown "$device_hash"; then
        return 0
    fi

    log_info "New USB device detected: $device_info"

    local full_info
    full_info=$(lsusb -s "$bus:$dev" 2>/dev/null || echo "Unknown device: $device_info")

    if is_hid_device "$bus" "$dev"; then
        log_info "Filtered: HID device or Hub (USB class 03/09)"
        return 0
    fi

    if echo "$full_info" | grep -qiE "root hub"; then
        log_info "Filtered: Root hub"
        return 0
    fi

    if ! set_cooldown "$device_hash"; then
        log_warning "Skipping alert due to cooldown write failure (fail-closed)"
        return 0
    fi

    local full_info_escaped
    full_info_escaped=$(html_escape "$full_info")

    local message="<div style='font-family: monospace;'>"
    message+="<div style='margin-bottom: 20px;'>"
    message+="<h3 style='color: #F44336; margin: 0 0 10px 0;'>⚠️ USB DEVICE DETECTED</h3>"
    message+="<table class='diagnostic-table'>"
    message+="<tr><td>Device:</td><td><strong>$full_info_escaped</strong></td></tr>"
    message+="<tr><td>VID:PID:</td><td><code>$vidpid</code></td></tr>"
    message+="<tr><td>Detection Time:</td><td>$(date '+%Y-%m-%d %H:%M:%S')</td></tr>"
    message+="<tr><td>Server:</td><td>$(hostname)</td></tr>"
    message+="</table>"
    message+="</div>"

    message+="<div style='margin-bottom: 20px;'>"
    message+="<h3 style='color: #555; margin: 0 0 10px 0;'>🔒 SECURITY STATUS</h3>"
    message+="<table class='diagnostic-table'>"

    if lsmod | grep -q usb_storage; then
        message+="<tr><td>USB-Storage Module:</td><td><span class='badge badge-error'>⚠️ WARNING</span> Module loaded (bypass detected!)</td></tr>"
    else
        message+="<tr><td>USB-Storage Module:</td><td><span class='badge badge-success'>✅ OK</span> Not loaded (blocked)</td></tr>"
    fi

    if lsblk | grep -qE "sd[b-z]"; then
        local mounted_devices
        mounted_devices=$(html_escape "$(lsblk | grep -E 'NAME|sd[b-z]')")
        message+="<tr><td>Block Devices:</td><td><span class='badge badge-error'>⚠️ WARNING</span> USB storage mounted</td></tr>"
        message+="</table>"
        message+="<div style='margin-top: 10px;'><strong>Mounted Devices:</strong></div>"
        message+="<pre style='background: #263238; color: #AED581; padding: 12px; border-radius: 4px; font-size: 13px;'>$mounted_devices</pre>"
    else
        message+="<tr><td>Block Devices:</td><td><span class='badge badge-success'>✅ OK</span> No USB storage mounted</td></tr>"
        message+="</table>"
    fi
    message+="</div>"

    message+="<div style='margin-bottom: 20px;'>"
    message+="<h3 style='color: #555; margin: 0 0 10px 0;'>🔍 INVESTIGATION COMMANDS</h3>"
    message+="<div class='command-block'>"
    message+="<code>lsusb</code><br>"
    message+="<code>lsblk</code><br>"
    message+="<code>lsmod | grep usb_storage</code><br>"
    message+="<code>journalctl -u usb-device-watcher.service -n 50</code>"
    message+="</div>"
    message+="</div>"

    message+="</div>"

    log_info "Sending alert for device: $full_info"
    if send_usb_alert "⚠️ USB Device Connected - $(hostname)" "$message"; then
        log_success "Alert sent successfully"
    else
        log_warning "Alert sending may have failed"
    fi
}

main() {
    log_info "USB Device Watcher v${VERSION} started (interval: ${POLL_INTERVAL}s)"
    log_info "Warmup phase: ${WARMUP_CYCLES} cycles (no alerts during warmup)"
    log_info "Alert cooldown: ${ALERT_COOLDOWN}s per device"

    ensure_state_dir

    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        log_error "FATAL: Another instance is already running (lock: $LOCK_FILE)"
        exit 1
    fi
    log_info "Lock acquired: $LOCK_FILE"

    local initial_devices
    if ! initial_devices=$(get_usb_devices); then
        log_error "FATAL: Cannot get initial USB devices"
        exit 1
    fi

    if ! write_state_file "$initial_devices"; then
        log_error "FATAL: Cannot initialize state file"
        exit 1
    fi

    local device_count
    if [[ -z "$initial_devices" ]]; then
        device_count=0
    else
        device_count=$(echo "$initial_devices" | grep -c .)
    fi
    log_info "Initial state: $device_count USB devices recorded"
    log_info "State file: $STATE_FILE"

    while true; do
        sleep "$POLL_INTERVAL"

        ((WARMUP_COUNTER++)) || true

        local current_devices
        if ! current_devices=$(get_usb_devices); then
            continue
        fi

        local previous_devices
        previous_devices=$(read_state_file)

        if [[ -z "$previous_devices" ]] && [[ -n "$current_devices" ]]; then
            log_warning "State file was empty - re-initializing (no alerts)"
            write_state_file "$current_devices"
            continue
        fi

        local new_devices
        new_devices=$(detect_new_devices "$current_devices" "$previous_devices")

        if [[ -n "$new_devices" ]]; then
            if [[ $WARMUP_COUNTER -le $WARMUP_CYCLES ]]; then
                if [[ "$WARMUP_LOGGED" == "false" ]]; then
                    local new_count
                    new_count=$(echo "$new_devices" | grep -c . || echo 0)
                    log_info "Warmup: $new_count new device(s) detected but skipped (${WARMUP_COUNTER}/${WARMUP_CYCLES})"
                    WARMUP_LOGGED=true
                fi
            else
                while IFS= read -r device; do
                    [[ -z "$device" ]] && continue
                    send_alert_for_device "$device"
                done <<< "$new_devices"
            fi
        fi

        write_state_file "$current_devices"
    done
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
