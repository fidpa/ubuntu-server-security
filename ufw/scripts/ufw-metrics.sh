#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# UFW Prometheus Metrics Exporter
# ═══════════════════════════════════════════════════════════════════════════
# Copyright (c) 2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# Purpose: Export UFW metrics for Prometheus node_exporter textfile collector
# Usage: ./ufw-metrics.sh [--output <file>]
#
# Output: /var/lib/node_exporter/textfile_collector/ufw.prom (default)
#
# Metrics exported:
#   ufw_active           - UFW status (1=active, 0=inactive)
#   ufw_enabled          - UFW service enabled (1=enabled, 0=disabled)
#   ufw_rules_total      - Total number of rules
#   ufw_blocked_today    - Blocked connections today (from log)
#   ufw_logging_level    - Logging level (0=off, 1=low, 2=medium, 3=high, 4=full)
#   ufw_ipv6_enabled     - IPv6 enabled (1=yes, 0=no)
#   ufw_last_check       - Timestamp of last metrics collection
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"
readonly DEFAULT_OUTPUT="/var/lib/node_exporter/textfile_collector/ufw.prom"
readonly UFW_LOG="/var/log/ufw.log"

OUTPUT_FILE="$DEFAULT_OUTPUT"

# ═══════════════════════════════════════════════════════════════════════════
# Functions
# ═══════════════════════════════════════════════════════════════════════════

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Export UFW metrics for Prometheus node_exporter textfile collector.

Options:
  -o, --output FILE    Output file (default: $DEFAULT_OUTPUT)
  -h, --help           Show this help message
  --version            Show version

Metrics:
  ufw_active           UFW status (1=active, 0=inactive)
  ufw_enabled          UFW service enabled (1=enabled, 0=disabled)
  ufw_rules_total      Total number of rules
  ufw_blocked_today    Blocked connections today
  ufw_logging_level    Logging level (0-4)
  ufw_ipv6_enabled     IPv6 enabled (1=yes, 0=no)
  ufw_last_check       Timestamp of last check

Example systemd timer:
  Run every 5 minutes to collect metrics

EOF
}

get_ufw_active() {
    local status
    status=$(sudo ufw status 2>/dev/null | head -1)

    if [[ "$status" == "Status: active" ]]; then
        echo 1
    else
        echo 0
    fi
}

get_ufw_enabled() {
    if systemctl is-enabled ufw &>/dev/null; then
        echo 1
    else
        echo 0
    fi
}

get_rules_count() {
    local count
    count=$(sudo ufw status numbered 2>/dev/null | grep -c "^\[" || echo "0")
    echo "$count"
}

get_blocked_today() {
    local today
    today=$(date +"%b %e")  # Format: "Jan  7"

    if [[ -f "$UFW_LOG" ]]; then
        # Count UFW BLOCK entries for today
        sudo grep "UFW BLOCK" "$UFW_LOG" 2>/dev/null | grep -c "^$today" || echo "0"
    else
        echo "0"
    fi
}

get_logging_level() {
    local verbose_status level_name level_num
    verbose_status=$(sudo ufw status verbose 2>/dev/null)
    level_name=$(echo "$verbose_status" | grep "^Logging:" | awk '{print $2}')

    case "$level_name" in
        "off")    level_num=0 ;;
        "on")     level_num=1 ;;  # Default is "low"
        "low")    level_num=1 ;;
        "medium") level_num=2 ;;
        "high")   level_num=3 ;;
        "full")   level_num=4 ;;
        *)        level_num=0 ;;
    esac

    echo "$level_num"
}

get_ipv6_enabled() {
    local ipv6_status
    ipv6_status=$(grep "^IPV6=" /etc/default/ufw 2>/dev/null | cut -d= -f2)

    if [[ "$ipv6_status" == "yes" ]]; then
        echo 1
    else
        echo 0
    fi
}

generate_metrics() {
    local active enabled rules blocked logging ipv6 timestamp

    # Collect metrics
    active=$(get_ufw_active)
    enabled=$(get_ufw_enabled)
    rules=$(get_rules_count)
    blocked=$(get_blocked_today)
    logging=$(get_logging_level)
    ipv6=$(get_ipv6_enabled)
    timestamp=$(date +%s)

    # Generate Prometheus format output
    cat <<EOF
# HELP ufw_active UFW firewall status (1=active, 0=inactive)
# TYPE ufw_active gauge
ufw_active $active

# HELP ufw_enabled UFW service enabled at boot (1=enabled, 0=disabled)
# TYPE ufw_enabled gauge
ufw_enabled $enabled

# HELP ufw_rules_total Total number of UFW rules configured
# TYPE ufw_rules_total gauge
ufw_rules_total $rules

# HELP ufw_blocked_today Number of blocked connections today
# TYPE ufw_blocked_today gauge
ufw_blocked_today $blocked

# HELP ufw_logging_level UFW logging level (0=off, 1=low, 2=medium, 3=high, 4=full)
# TYPE ufw_logging_level gauge
ufw_logging_level $logging

# HELP ufw_ipv6_enabled IPv6 support enabled (1=yes, 0=no)
# TYPE ufw_ipv6_enabled gauge
ufw_ipv6_enabled $ipv6

# HELP ufw_last_check_timestamp_seconds Unix timestamp of last metrics collection
# TYPE ufw_last_check_timestamp_seconds gauge
ufw_last_check_timestamp_seconds $timestamp
EOF
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --version)
                echo "$SCRIPT_NAME version $VERSION"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Check if UFW is installed
    if ! command -v ufw &>/dev/null; then
        echo "# UFW not installed" > "$OUTPUT_FILE.tmp"
        echo "ufw_active 0" >> "$OUTPUT_FILE.tmp"
        mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
        exit 0
    fi

    # Ensure output directory exists
    local output_dir
    output_dir=$(dirname "$OUTPUT_FILE")
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir" 2>/dev/null || {
            echo "Cannot create output directory: $output_dir" >&2
            exit 1
        }
    fi

    # Generate metrics to temp file (atomic write)
    local temp_file
    temp_file="$OUTPUT_FILE.tmp.$$"

    if generate_metrics > "$temp_file"; then
        mv "$temp_file" "$OUTPUT_FILE"
    else
        rm -f "$temp_file"
        echo "Failed to generate metrics" >&2
        exit 1
    fi
}

main "$@"
