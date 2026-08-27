#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# fail2ban Prometheus Metrics Exporter
# Exports fail2ban statistics in Prometheus format
#
# Metrics exported:
#   - fail2ban_jails_total: Number of configured jails
#   - fail2ban_bans_total: Currently banned IPs per jail
#   - fail2ban_ban_events_total: Cumulative ban events per jail
#
# Usage:
#   fail2ban-metrics-exporter.sh
#
# Output:
#   /var/lib/node_exporter/textfile_collector/fail2ban.prom
#
# Requirements:
#   - fail2ban running
#   - node_exporter with textfile collector enabled
#
# Installation:
#   1. Copy script to /usr/local/bin/
#   2. Create systemd timer for periodic export
#   3. Configure node_exporter: --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
#
# Version: 1.0.0

set -uo pipefail

# ============================================
# Configuration
# ============================================

readonly METRICS_FILE="${METRICS_FILE:-/var/lib/node_exporter/textfile_collector/fail2ban.prom}"
readonly HOSTNAME=$(hostname)

# Create metrics directory
mkdir -p "$(dirname "$METRICS_FILE")" 2>/dev/null || true

# ============================================
# Functions
# ============================================

# Get list of active jails
get_jails() {
    fail2ban-client status 2>/dev/null | grep "Jail list:" | sed 's/.*Jail list://' | tr -d '\t' | tr ',' '\n' | sed 's/^[[:space:]]*//' | grep -v '^$'
}

# Get currently banned IPs count for a jail
get_banned_count() {
    local jail="$1"
    fail2ban-client status "$jail" 2>/dev/null | grep "Currently banned:" | awk '{print $NF}'
}

# Get total banned IPs count for a jail
get_total_banned() {
    local jail="$1"
    fail2ban-client status "$jail" 2>/dev/null | grep "Total banned:" | awk '{print $NF}'
}

# ============================================
# Main
# ============================================

main() {
    local temp_file
    temp_file=$(mktemp)

    # Header
    {
        printf '# HELP fail2ban_jails_total Number of configured fail2ban jails\n'
        printf '# TYPE fail2ban_jails_total gauge\n'
        printf '# HELP fail2ban_bans_total Currently banned IPs per jail\n'
        printf '# TYPE fail2ban_bans_total gauge\n'
        printf '# HELP fail2ban_ban_events_total Cumulative ban events per jail\n'
        printf '# TYPE fail2ban_ban_events_total counter\n'
    } > "$temp_file"

    # Get all jails
    local jails
    jails=$(get_jails)

    if [[ -z "$jails" ]]; then
        # No jails active - export zero
        printf 'fail2ban_jails_total{hostname="%s"} 0\n' "$HOSTNAME" >> "$temp_file"
    else
        # Count jails
        local jail_count
        jail_count=$(echo "$jails" | wc -l)
        printf 'fail2ban_jails_total{hostname="%s"} %s\n' "$HOSTNAME" "$jail_count" >> "$temp_file"

        # Export metrics for each jail
        while IFS= read -r jail; do
            [[ -z "$jail" ]] && continue

            # Currently banned IPs
            local banned_count
            banned_count=$(get_banned_count "$jail")
            printf 'fail2ban_bans_total{hostname="%s",jail="%s"} %s\n' \
                "$HOSTNAME" "$jail" "${banned_count:-0}" >> "$temp_file"

            # Total ban events
            local total_banned
            total_banned=$(get_total_banned "$jail")
            printf 'fail2ban_ban_events_total{hostname="%s",jail="%s"} %s\n' \
                "$HOSTNAME" "$jail" "${total_banned:-0}" >> "$temp_file"

        done <<< "$jails"
    fi

    # Atomic update (rename temp file to final location)
    mv "$temp_file" "$METRICS_FILE"

    # Set readable permissions for node_exporter
    chmod 644 "$METRICS_FILE"

    return 0
}

main "$@"
