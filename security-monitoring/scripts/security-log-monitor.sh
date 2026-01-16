#!/bin/bash
#
# Security Log Monitor - Unified security event monitoring with smart deduplication
#
# Version: 1.3.0 (Refactored for ubuntu-server-security)
# Date: 15. Januar 2026
#
# Changelog:
#   v1.3.0 - Refactored for ubuntu-server-security repository
#   v1.2.2 - KISS improvements (AIDE Epoch timestamp, auditd normalization)
#   v1.2.1 - Bug fixes from external AI review
#   v1.2.0 - Added AIDE file integrity monitoring and rkhunter rootkit detection
#
# Purpose:
#   Monitor security logs for suspicious activity:
#   - fail2ban: Ban/Unban events
#   - SSH: Failed login attempts (auth.log via journalctl)
#   - UFW: Blocked connections from external IPs
#   - auditd: Security policy violations
#   - AIDE: File integrity monitoring (daily scans)
#   - rkhunter: Rootkit detection (scan warnings)
#
# Dependencies:
#   - bash-production-toolkit (logging.sh, secure-file-utils.sh, alerts.sh)
#   - journalctl (systemd)
#   - ausearch (auditd, optional)
#   - aide (optional)
#   - rkhunter (optional)
#
# Usage:
#   ./security-log-monitor.sh [--dry-run]
#
# Exit Codes:
#   0 - Script ran successfully (sends alerts/metrics regardless)
#   1 - Reserved for future use
#   2 - Script error (library load failures, etc.)
#

set -uo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Bash Production Toolkit path (override via environment variable)
BASH_TOOLKIT_PATH="${BASH_TOOLKIT_PATH:-/usr/local/lib/bash-production-toolkit}"

# State directory for deduplication (override via environment variable)
STATE_DIR="${STATE_DIR:-/var/lib/security-monitoring}"

# Check interval (minutes) - matches timer schedule
readonly CHECK_INTERVAL_MIN="${CHECK_INTERVAL_MIN:-15}"

# Thresholds (override via environment variable)
readonly SSH_FAILURE_THRESHOLD="${SSH_FAILURE_THRESHOLD:-5}"
readonly UFW_BLOCK_THRESHOLD="${UFW_BLOCK_THRESHOLD:-10}"

# Alerting configuration
export TELEGRAM_PREFIX="${TELEGRAM_PREFIX:-[Security]}"
export RATE_LIMIT_SECONDS="${RATE_LIMIT_SECONDS:-1800}"  # 30 minutes
export ENABLE_RECOVERY_ALERTS="${ENABLE_RECOVERY_ALERTS:-false}"

# ============================================================================
# DEPENDENCY LOADING
# ============================================================================

# Import libraries from bash-production-toolkit
# shellcheck source=/usr/local/lib/bash-production-toolkit/src/foundation/logging.sh
source "${BASH_TOOLKIT_PATH}/src/foundation/logging.sh" || {
    echo "FATAL: Failed to load logging.sh from bash-production-toolkit" >&2
    exit 2
}

# shellcheck source=/usr/local/lib/bash-production-toolkit/src/foundation/secure-file-utils.sh
source "${BASH_TOOLKIT_PATH}/src/foundation/secure-file-utils.sh" || {
    log_error "Failed to load secure-file-utils.sh from bash-production-toolkit"
    exit 2
}

# shellcheck source=/usr/local/lib/bash-production-toolkit/src/monitoring/alerts.sh
source "${BASH_TOOLKIT_PATH}/src/monitoring/alerts.sh" || {
    log_error "Failed to load alerts.sh from bash-production-toolkit"
    exit 2
}

# ============================================================================
# INLINE STATE MANAGEMENT
# ============================================================================

# Load state from file
# Usage: state_load "check_name"
# Returns: Newline-separated list of items (empty if file doesn't exist)
state_load() {
    local state_name="$1"
    local state_file="${STATE_DIR}/.${state_name}_state"

    if [[ ! -f "$state_file" ]]; then
        log_debug "No previous state found for $state_name"
        return 0
    fi

    cat "$state_file" 2>/dev/null || true
    log_debug "Loaded state for $state_name"
}

# Save state to file
# Usage: state_save "check_name" "item1\nitem2\nitem3"
state_save() {
    local state_name="$1"
    local state_data="$2"
    local state_file="${STATE_DIR}/.${state_name}_state"

    # Handle empty state
    if [[ -z "$state_data" ]]; then
        : > "$state_file"
        log_debug "Saved empty state for $state_name"
        return 0
    fi

    # Write to file
    echo "$state_data" > "$state_file"
    log_debug "Saved state for $state_name"
}

# Compare current vs known state
# Usage: state_compare "current_items" "known_items"
# Returns: "new_items|recovered_items|unchanged_items" (pipe-separated)
state_compare() {
    local current="$1"
    local known="$2"

    # Handle empty cases
    if [[ -z "$current" ]] && [[ -z "$known" ]]; then
        echo "||"
        return 0
    fi

    if [[ -z "$current" ]]; then
        echo "|${known}|"
        return 0
    fi

    if [[ -z "$known" ]]; then
        echo "${current}||"
        return 0
    fi

    # Both have content - do proper comparison
    local new_items="" recovered_items="" unchanged_items=""

    # Find NEW items
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        if ! echo "$known" | grep -Fxq "$item"; then
            [[ -n "$new_items" ]] && new_items+=$'\n'
            new_items+="$item"
        fi
    done <<< "$current"

    # Find RECOVERED items
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        if ! echo "$current" | grep -Fxq "$item"; then
            [[ -n "$recovered_items" ]] && recovered_items+=$'\n'
            recovered_items+="$item"
        fi
    done <<< "$known"

    # Find UNCHANGED items
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        if echo "$current" | grep -Fxq "$item"; then
            [[ -n "$unchanged_items" ]] && unchanged_items+=$'\n'
            unchanged_items+="$item"
        fi
    done <<< "$known"

    echo "${new_items}|${recovered_items}|${unchanged_items}"
}

# Count non-empty lines in a string
# Usage: count_lines "$string"
count_lines() {
    local data="$1"
    [[ -z "$data" ]] && { echo "0"; return 0; }
    [[ "$data" =~ ^[[:space:]]*$ ]] && { echo "0"; return 0; }
    echo "$data" | grep -c '.'
}

# ============================================================================
# RUNTIME SETUP
# ============================================================================

# Script version
readonly MONITOR_VERSION="1.3.0"

# Dry-run mode
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    log_info "DRY-RUN mode enabled (no alerts sent)"
fi

# Ensure state directory exists
mkdir -p "$STATE_DIR" || {
    log_error "Failed to create state directory: $STATE_DIR"
    exit 2
}

# ============================================================================
# ALERT AGGREGATION STORAGE
# ============================================================================

declare -a FAIL2BAN_NEW=()
declare -a SSH_NEW=()
declare -a UFW_NEW=()
declare -a AUDIT_NEW=()
declare -a AIDE_NEW=()
declare -a RKHUNTER_NEW=()

# ============================================================================
# CHECK FUNCTIONS
# ============================================================================

# Check fail2ban events
check_fail2ban_events() {
    log_info "Checking fail2ban events..."

    local since_time="${CHECK_INTERVAL_MIN} minutes ago"
    local logs
    logs="$(journalctl -u fail2ban --since "${since_time}" --no-pager 2>/dev/null || true)"

    # Extract IPs from ban events
    local current_bans=""
    if grep -qE "Ban " <<<"$logs"; then
        current_bans=$(grep -E "Ban " <<<"$logs" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | sort -u)
    fi

    # Load known state
    local known_bans
    known_bans=$(state_load "security-log-monitor_fail2ban" 2>/dev/null || echo "")

    # Compare states
    local comparison
    comparison=$(state_compare "$current_bans" "$known_bans")

    local new_bans recovered_bans unchanged_bans
    IFS='|' read -r new_bans recovered_bans unchanged_bans <<< "$comparison"

    local new_count
    new_count=$(count_lines "$new_bans")

    if [[ $new_count -gt 0 ]]; then
        log_warn "fail2ban: ${new_count} new ban(s) detected"
        while IFS= read -r ban; do
            [[ -n "$ban" ]] && FAIL2BAN_NEW+=("$ban")
        done <<< "$new_bans"
    else
        log_info "fail2ban: No new bans detected"
    fi

    # Save new state
    state_save "security-log-monitor_fail2ban" "$current_bans"
    return 0
}

# Check SSH failed login attempts
check_ssh_failures() {
    log_info "Checking SSH failed login attempts..."

    local since_time="${CHECK_INTERVAL_MIN} minutes ago"
    local logs=""
    logs="$(journalctl -u ssh -u sshd --since "${since_time}" --no-pager 2>/dev/null || true)"

    # Extract failed attempts
    local current_failures_with_counts=""
    if grep -qiE "Failed password|Invalid user|authentication failure" <<<"$logs"; then
        current_failures_with_counts=$(grep -iE "Failed password|Invalid user|authentication failure" <<<"$logs" | \
            grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | \
            sort | uniq -c | sort -rn)
    fi

    # Calculate total failures
    local total_failures=0
    if [[ -n "$current_failures_with_counts" ]]; then
        total_failures=$(awk '{s+=$1} END{print s+0}' <<<"$current_failures_with_counts")
    fi

    # State only stores IPs (without counts)
    local current_ips=""
    if [[ -n "$current_failures_with_counts" ]]; then
        current_ips=$(awk '{print $2}' <<<"$current_failures_with_counts" | sort -u)
    fi

    # Load known state
    local known_ips
    known_ips=$(state_load "security-log-monitor_ssh" 2>/dev/null || echo "")

    # Compare states
    local comparison
    comparison=$(state_compare "$current_ips" "$known_ips")

    local new_ips recovered_ips unchanged_ips
    IFS='|' read -r new_ips recovered_ips unchanged_ips <<< "$comparison"

    local new_ip_count
    new_ip_count=$(count_lines "$new_ips")

    # Alert if total failures above threshold AND new IPs detected
    if [[ $total_failures -gt $SSH_FAILURE_THRESHOLD ]]; then
        if [[ $new_ip_count -gt 0 ]]; then
            log_warn "SSH: ${new_ip_count} new IP(s), ${total_failures} total failures"
            while IFS= read -r ip; do
                if [[ -n "$ip" ]]; then
                    local count
                    count=$(awk -v ip="$ip" '$2==ip {print $1; exit}' <<<"$current_failures_with_counts")
                    SSH_NEW+=("${count:-?}x ${ip}")
                fi
            done <<< "$new_ips"
        else
            log_info "SSH: ${total_failures} failures (no new IPs)"
        fi
    else
        log_info "SSH: ${total_failures} failures (below threshold of ${SSH_FAILURE_THRESHOLD})"
    fi

    # Save state
    state_save "security-log-monitor_ssh" "$current_ips"
    return 0
}

# Check UFW blocked connections
check_ufw_blocks() {
    log_info "Checking UFW blocked connections..."

    local since_time="${CHECK_INTERVAL_MIN} minutes ago"
    local logs
    logs="$(journalctl -k --since "${since_time}" --no-pager 2>/dev/null || true)"

    # Extract external IPs with counts
    local current_blocks_with_counts=""
    if grep -q "UFW BLOCK" <<<"$logs"; then
        current_blocks_with_counts=$(grep "UFW BLOCK" <<<"$logs" | \
            grep -oE "SRC=([0-9]{1,3}\.){3}[0-9]{1,3}" | \
            cut -d= -f2 | \
            grep -vE "^192\.168\." | \
            grep -vE "^10\." | \
            grep -vE "^172\.(1[6-9]|2[0-9]|3[01])\." | \
            sort | uniq -c | sort -rn)
    fi

    # State only stores IPs
    local current_ips=""
    if [[ -n "$current_blocks_with_counts" ]]; then
        current_ips=$(awk '{print $2}' <<<"$current_blocks_with_counts" | sort -u)
    fi

    # Load known state
    local known_ips
    known_ips=$(state_load "security-log-monitor_ufw" 2>/dev/null || echo "")

    # Compare states
    local comparison
    comparison=$(state_compare "$current_ips" "$known_ips")

    local new_ips recovered_ips unchanged_ips
    IFS='|' read -r new_ips recovered_ips unchanged_ips <<< "$comparison"

    local new_ip_count
    new_ip_count=$(count_lines "$new_ips")

    # Only alert if significant blocks from same IP
    if [[ -n "$current_blocks_with_counts" ]]; then
        local top_blocker_count
        top_blocker_count=$(head -1 <<<"$current_blocks_with_counts" | awk '{print $1}')

        if [[ $top_blocker_count -gt $UFW_BLOCK_THRESHOLD ]]; then
            if [[ $new_ip_count -gt 0 ]]; then
                log_warn "UFW: ${new_ip_count} new blocked IP(s) (top: ${top_blocker_count} blocks)"
                local ip_count=0
                while IFS= read -r ip && [[ $ip_count -lt 5 ]]; do
                    if [[ -n "$ip" ]]; then
                        local block_count
                        block_count=$(awk -v ip="$ip" '$2==ip {print $1; exit}' <<<"$current_blocks_with_counts")
                        UFW_NEW+=("${block_count:-?}x ${ip}")
                        ((ip_count++))
                    fi
                done <<< "$new_ips"
            else
                log_info "UFW: ${top_blocker_count} blocks (no new IPs)"
            fi
        else
            log_info "UFW: Blocks detected but below threshold (top: ${top_blocker_count})"
        fi
    else
        log_info "UFW: No blocks from external IPs"
    fi

    # Save state
    state_save "security-log-monitor_ufw" "$current_ips"
    return 0
}

# Check auditd security events
check_audit_events() {
    log_info "Checking auditd security events..."

    # Check if ausearch is available
    if ! command -v ausearch &>/dev/null; then
        log_warn "ausearch not available, skipping audit check"
        return 0
    fi

    # Check if we have permission
    if [[ $EUID -ne 0 ]]; then
        log_warn "auditd check requires root, skipping"
        return 0
    fi

    # ISO-Format for ausearch -ts (universeller als MM/DD/YYYY)
    local since_ts
    since_ts="$(date -d "${CHECK_INTERVAL_MIN} minutes ago" '+%Y-%m-%d %H:%M:%S')"

    local audit_output
    audit_output="$(ausearch -m avc,user_avc -ts "$since_ts" 2>/dev/null || true)"

    local current_events=""
    if grep -qi "denied" <<<"$audit_output"; then
        # Normalisiere Whitespace statt awk $5 $6 (robuster, keine Spalten-Annahmen)
        current_events=$(grep -i "denied" <<<"$audit_output" | \
            sed 's/[[:space:]]\+/ /g' | \
            sort -u)
    fi

    # Load known state
    local known_events
    known_events=$(state_load "security-log-monitor_audit" 2>/dev/null || echo "")

    # Compare states
    local comparison
    comparison=$(state_compare "$current_events" "$known_events")

    local new_events recovered_events unchanged_events
    IFS='|' read -r new_events recovered_events unchanged_events <<< "$comparison"

    local new_count
    new_count=$(count_lines "$new_events")

    if [[ $new_count -gt 0 ]]; then
        log_warn "auditd: ${new_count} new security event(s)"
        while IFS= read -r event; do
            [[ -n "$event" ]] && AUDIT_NEW+=("$event")
        done <<< "$new_events"
    else
        log_info "auditd: No new security events"
    fi

    # Save new state
    state_save "security-log-monitor_audit" "$current_events"
    return 0
}

# Check AIDE file integrity monitoring
check_aide_events() {
    log_info "Checking AIDE file integrity..."

    # Epoch-basiert (KISS: kein Locale-Problem bei journalctl --since)
    local last_aide_epoch
    last_aide_epoch=$(state_load "security-log-monitor_aide_timestamp" 2>/dev/null || date -d "${CHECK_INTERVAL_MIN} minutes ago" +%s)

    local aide_logs
    aide_logs=$(journalctl -u aide-update --since "@${last_aide_epoch}" --no-pager 2>/dev/null || true)

    if [[ -z "$aide_logs" ]] || ! grep -q "AIDE update completed" <<<"$aide_logs"; then
        log_info "AIDE: No new runs since last check"
        # Timestamp IMMER fortschreiben
        state_save "security-log-monitor_aide_timestamp" "$(date +%s)"
        return 0
    fi

    # Neuer AIDE-Lauf erkannt - prüfe Ergebnis
    local exit_info
    exit_info=$(grep -Eo 'exit code [0-9]+' <<<"$aide_logs" | tail -1 || true)
    local exit_code="${exit_info##* }"

    if [[ -n "$exit_code" ]] && [[ "$exit_code" =~ ^[0-9]+$ ]]; then
        if [[ "$exit_code" -ge 8 ]]; then
            log_error "AIDE: Error detected (exit code ${exit_code})"
            AIDE_NEW+=("🔴 AIDE Error (Exit ${exit_code})")
        elif [[ "$exit_code" -ge 1 ]]; then
            log_warn "AIDE: Changes detected (exit code ${exit_code})"
            AIDE_NEW+=("🟠 AIDE Changes detected (Exit ${exit_code})")
        else
            log_info "AIDE: Database synchronized (no changes)"
        fi
    else
        log_warn "AIDE: Run detected but exit code unknown"
        AIDE_NEW+=("🟡 AIDE Run detected (exit unknown)")
    fi

    # Speichere aktuellen Timestamp (Epoch)
    state_save "security-log-monitor_aide_timestamp" "$(date +%s)"
    return 0
}

# Check rkhunter rootkit detection
check_rkhunter_events() {
    log_info "Checking rkhunter rootkit detection..."

    local rkhunter_log="/var/log/rkhunter.log"
    [[ ! -f "$rkhunter_log" ]] && { log_info "rkhunter: Log not found, skipping"; return 0; }

    # Prüfe Log-Modification-Timestamp
    local current_mtime
    current_mtime=$(stat --format=%Y "$rkhunter_log" 2>/dev/null || echo "0")

    local last_mtime
    last_mtime=$(state_load "security-log-monitor_rkhunter_mtime" 2>/dev/null || echo "0")

    if [[ "$current_mtime" == "$last_mtime" ]]; then
        log_info "rkhunter: No new scan since last check"
        return 0
    fi

    # Parse Warnings
    local warnings
    warnings=$(grep -iE "\[WARNING\]|Warning:" "$rkhunter_log" 2>/dev/null | tail -5 || true)

    if [[ -n "$warnings" ]]; then
        local warning_count
        warning_count=$(wc -l <<<"$warnings")
        log_warn "rkhunter: ${warning_count} warning(s) in latest scan"
        RKHUNTER_NEW+=("🔍 ${warning_count} warnings:")
        while IFS= read -r line; do
            [[ -n "$line" ]] && RKHUNTER_NEW+=("  ${line:0:60}")
        done <<< "$warnings"
    else
        log_info "rkhunter: No warnings in latest scan"
    fi

    # Speichere Timestamp
    state_save "security-log-monitor_rkhunter_mtime" "$current_mtime"
    return 0
}

# ============================================================================
# ALERT AGGREGATION
# ============================================================================

send_aggregated_alert() {
    local total_events=0
    total_events=$((${#FAIL2BAN_NEW[@]} + ${#SSH_NEW[@]} + ${#UFW_NEW[@]} + ${#AUDIT_NEW[@]} + ${#AIDE_NEW[@]} + ${#RKHUNTER_NEW[@]}))

    if [[ $total_events -eq 0 ]]; then
        log_info "No new security events to report"
        return 0
    fi

    log_info "Aggregating ${total_events} security events for alert..."

    # Build alert message
    local message="🔐 Security Alert\n\n"

    # fail2ban section
    if [[ ${#FAIL2BAN_NEW[@]} -gt 0 ]]; then
        message+="🚨 fail2ban: ${#FAIL2BAN_NEW[@]} new ban(s)\n"
        for ban in "${FAIL2BAN_NEW[@]}"; do
            message+="• ${ban}\n"
        done
        message+="\n"
    fi

    # SSH section
    if [[ ${#SSH_NEW[@]} -gt 0 ]]; then
        message+="⚠️ SSH: ${#SSH_NEW[@]} new failed login(s)\n"
        for failure in "${SSH_NEW[@]}"; do
            message+="• ${failure}\n"
        done
        message+="\n"
    fi

    # UFW section
    if [[ ${#UFW_NEW[@]} -gt 0 ]]; then
        message+="🛡️ UFW: ${#UFW_NEW[@]} blocked IP(s)\n"
        for block in "${UFW_NEW[@]}"; do
            message+="• ${block}\n"
        done
        message+="\n"
    fi

    # Audit section
    if [[ ${#AUDIT_NEW[@]} -gt 0 ]]; then
        message+="🔍 auditd: ${#AUDIT_NEW[@]} security event(s)\n"
        for event in "${AUDIT_NEW[@]}"; do
            message+="• ${event}\n"
        done
        message+="\n"
    fi

    # AIDE section
    if [[ ${#AIDE_NEW[@]} -gt 0 ]]; then
        message+="🔍 AIDE (File Integrity):\n"
        for event in "${AIDE_NEW[@]}"; do
            message+="• ${event}\n"
        done
        message+="\n"
    fi

    # rkhunter section
    if [[ ${#RKHUNTER_NEW[@]} -gt 0 ]]; then
        message+="🛡️ rkhunter (Rootkit Detection):\n"
        for event in "${RKHUNTER_NEW[@]}"; do
            message+="• ${event}\n"
        done
    fi

    # Send alert (unless dry-run)
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY-RUN: Would send alert:\n${message}"
    else
        log_info "Sending aggregated security alert..."
        send_telegram_alert "security_events" "$message" "🔐" "${TELEGRAM_PREFIX}"
    fi

    return 0
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log_info "===================================================="
    log_info "Security Log Monitor v${MONITOR_VERSION} starting..."
    log_info "Hostname: $(hostname -f 2>/dev/null || hostname)"
    log_info "Check interval: ${CHECK_INTERVAL_MIN} minutes"
    log_info "===================================================="

    # Run all checks
    check_fail2ban_events || log_warn "fail2ban check failed"
    check_ssh_failures || log_warn "SSH check failed"
    check_ufw_blocks || log_warn "UFW check failed"
    check_audit_events || log_warn "auditd check failed"
    check_aide_events || log_warn "AIDE check failed"
    check_rkhunter_events || log_warn "rkhunter check failed"

    # Send aggregated alert
    send_aggregated_alert

    log_info "===================================================="
    log_info "Security Log Monitor completed successfully"
    log_info "===================================================="

    return 0
}

# Run main function
main "$@"
exit $?
