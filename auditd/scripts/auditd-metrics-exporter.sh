#!/bin/bash
# =============================================================================
# Ubuntu Server Security - auditd Prometheus Metrics Exporter
# =============================================================================
#
# Exports auditd statistics as Prometheus metrics for monitoring
#
# Usage:
#   ./auditd-metrics-exporter.sh > /var/lib/node_exporter/textfile_collector/auditd.prom
#
# Recommended: Run via cron every 5 minutes
#   */5 * * * * /opt/infrastructure/scripts/auditd-metrics-exporter.sh > /var/lib/node_exporter/textfile_collector/auditd.prom
#
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
METRICS_FILE="${1:-/dev/stdout}"

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

get_audit_status() {
    # Get audit system status
    sudo auditctl -s 2>/dev/null
}

get_event_counts() {
    # Get event counts by type from the last hour
    sudo aureport --summary --ts "$(date -d '1 hour ago' '+%m/%d/%Y %H:%M:%S')" 2>/dev/null
}

generate_metrics() {
    local timestamp
    timestamp=$(date +%s)

    echo "# HELP auditd_up Whether auditd is running (1=yes, 0=no)"
    echo "# TYPE auditd_up gauge"
    if systemctl is-active auditd &>/dev/null; then
        echo "auditd_up 1"
    else
        echo "auditd_up 0"
    fi

    # Parse auditctl -s output
    local status
    status=$(get_audit_status)

    echo ""
    echo "# HELP auditd_enabled Audit system enabled status (0=disabled, 1=enabled, 2=immutable)"
    echo "# TYPE auditd_enabled gauge"
    local enabled
    enabled=$(echo "$status" | grep -oP 'enabled \K\d+' || echo "0")
    echo "auditd_enabled $enabled"

    echo ""
    echo "# HELP auditd_rules_loaded Number of audit rules loaded"
    echo "# TYPE auditd_rules_loaded gauge"
    local rules
    rules=$(sudo auditctl -l 2>/dev/null | wc -l || echo "0")
    echo "auditd_rules_loaded $rules"

    echo ""
    echo "# HELP auditd_backlog_current Current audit event backlog"
    echo "# TYPE auditd_backlog_current gauge"
    local backlog
    backlog=$(echo "$status" | grep -oP 'backlog \K\d+' || echo "0")
    echo "auditd_backlog_current $backlog"

    echo ""
    echo "# HELP auditd_backlog_limit Maximum audit event backlog limit"
    echo "# TYPE auditd_backlog_limit gauge"
    local backlog_limit
    backlog_limit=$(echo "$status" | grep -oP 'backlog_limit \K\d+' || echo "8192")
    echo "auditd_backlog_limit $backlog_limit"

    echo ""
    echo "# HELP auditd_lost_events_total Total events lost due to backlog overflow"
    echo "# TYPE auditd_lost_events_total counter"
    local lost
    lost=$(echo "$status" | grep -oP 'lost \K\d+' || echo "0")
    echo "auditd_lost_events_total $lost"

    echo ""
    echo "# HELP auditd_failure_mode Audit failure mode (0=silent, 1=printk, 2=panic)"
    echo "# TYPE auditd_failure_mode gauge"
    local failure
    failure=$(echo "$status" | grep -oP 'failure \K\d+' || echo "1")
    echo "auditd_failure_mode $failure"

    # Log file size
    echo ""
    echo "# HELP auditd_log_size_bytes Current audit log file size in bytes"
    echo "# TYPE auditd_log_size_bytes gauge"
    local log_size
    log_size=$(stat -c %s /var/log/audit/audit.log 2>/dev/null || echo "0")
    echo "auditd_log_size_bytes $log_size"

    # Event counts by type (from aureport)
    echo ""
    echo "# HELP auditd_events_last_hour Events in the last hour by type"
    echo "# TYPE auditd_events_last_hour gauge"

    # Get summary and parse
    local summary
    summary=$(get_event_counts)

    # Parse common event types
    local syscall_events
    syscall_events=$(echo "$summary" | grep -i "syscall" | awk '{print $1}' || echo "0")
    echo "auditd_events_last_hour{type=\"syscall\"} ${syscall_events:-0}"

    local user_auth
    user_auth=$(echo "$summary" | grep -i "auth" | awk '{print $1}' || echo "0")
    echo "auditd_events_last_hour{type=\"user_auth\"} ${user_auth:-0}"

    local user_login
    user_login=$(echo "$summary" | grep -i "login" | awk '{print $1}' || echo "0")
    echo "auditd_events_last_hour{type=\"user_login\"} ${user_login:-0}"

    # Count events by key (last hour)
    echo ""
    echo "# HELP auditd_key_events_last_hour Events by audit key in the last hour"
    echo "# TYPE auditd_key_events_last_hour gauge"

    for key in time-change identity system-locale MAC-policy logins session perm_mod access privileged mounts scope actions modules; do
        local count
        count=$(sudo ausearch -k "$key" -ts "$(date -d '1 hour ago' '+%m/%d/%Y %H:%M:%S')" 2>/dev/null | grep -c "^type=" || echo "0")
        echo "auditd_key_events_last_hour{key=\"$key\"} $count"
    done

    # Failed events
    echo ""
    echo "# HELP auditd_failed_events_last_hour Failed authentication events in the last hour"
    echo "# TYPE auditd_failed_events_last_hour gauge"
    local failed
    failed=$(sudo aureport --failed --ts "$(date -d '1 hour ago' '+%m/%d/%Y %H:%M:%S')" 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
    echo "auditd_failed_events_last_hour ${failed:-0}"

    # Scrape metadata
    echo ""
    echo "# HELP auditd_exporter_scrape_timestamp_seconds Timestamp of last scrape"
    echo "# TYPE auditd_exporter_scrape_timestamp_seconds gauge"
    echo "auditd_exporter_scrape_timestamp_seconds $timestamp"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    # Check if running as root (needed for ausearch)
    if [[ $EUID -ne 0 ]]; then
        echo "# ERROR: Must run as root for full metrics" >&2
        echo "auditd_up 0"
        exit 1
    fi

    generate_metrics
}

main "$@"
