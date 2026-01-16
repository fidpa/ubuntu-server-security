#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# nftables Prometheus Metrics Exporter
# ═══════════════════════════════════════════════════════════════════════════
# Copyright (c) 2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# Purpose: Export nftables metrics for Prometheus Node Exporter
# Usage: ./nftables-metrics.sh
#
# Deployment:
# 1. Copy to /opt/nftables/nftables-metrics.sh
# 2. Create systemd timer (run every 1 minute)
# 3. Ensure node_exporter textfile collector is enabled
#
# Metrics Exported:
# - nftables_input_dropped_total
# - nftables_forward_dropped_total
# - nftables_rules_total
# - nftables_nat_packets_total
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

readonly METRICS_FILE="/var/lib/node_exporter/textfile_collector/nftables.prom"
readonly TEMP_FILE="${METRICS_FILE}.$$"

# ═══════════════════════════════════════════════════════════════════════════
# Functions
# ═══════════════════════════════════════════════════════════════════════════

error() {
    echo "ERROR: $*" >&2
    exit 1
}

check_nft_command() {
    if ! command -v nft &>/dev/null; then
        error "nft command not found - is nftables installed?"
    fi
}

check_permissions() {
    if [[ ! -w "$(dirname "$METRICS_FILE")" ]]; then
        error "Cannot write to $(dirname "$METRICS_FILE") - run as root or check permissions"
    fi
}

get_input_dropped() {
    # Count packets dropped in input chain
    nft list chain inet filter input 2>/dev/null | \
        grep -oP 'counter packets \K\d+(?=.*drop)' | \
        awk '{sum+=$1} END {print sum+0}'
}

get_forward_dropped() {
    # Count packets dropped in forward chain
    nft list chain inet filter forward 2>/dev/null | \
        grep -oP 'counter packets \K\d+(?=.*drop)' | \
        awk '{sum+=$1} END {print sum+0}'
}

get_rules_total() {
    # Count total number of rules
    nft list ruleset 2>/dev/null | grep -c "^[[:space:]]*\(tcp\|udp\|ip\|ct\|iif\|oif\)" || echo 0
}

get_nat_packets() {
    # Count NAT masquerade packets
    nft list table ip nat 2>/dev/null | \
        grep -oP 'counter packets \K\d+(?=.*masquerade)' | \
        awk '{sum+=$1} END {print sum+0}'
}

get_nat_bytes() {
    # Count NAT masquerade bytes
    nft list table ip nat 2>/dev/null | \
        grep -oP 'counter packets \d+ bytes \K\d+(?=.*masquerade)' | \
        awk '{sum+=$1} END {print sum+0}'
}

write_metrics() {
    local input_dropped
    local forward_dropped
    local rules_total
    local nat_packets
    local nat_bytes

    # Gather metrics
    input_dropped=$(get_input_dropped)
    forward_dropped=$(get_forward_dropped)
    rules_total=$(get_rules_total)
    nat_packets=$(get_nat_packets)
    nat_bytes=$(get_nat_bytes)

    # Write to temp file
    cat > "$TEMP_FILE" <<EOF
# HELP nftables_input_dropped_total Total packets dropped in input chain
# TYPE nftables_input_dropped_total counter
nftables_input_dropped_total $input_dropped

# HELP nftables_forward_dropped_total Total packets dropped in forward chain
# TYPE nftables_forward_dropped_total counter
nftables_forward_dropped_total $forward_dropped

# HELP nftables_rules_total Total number of nftables rules
# TYPE nftables_rules_total gauge
nftables_rules_total $rules_total

# HELP nftables_nat_packets_total Total packets processed by NAT masquerade
# TYPE nftables_nat_packets_total counter
nftables_nat_packets_total $nat_packets

# HELP nftables_nat_bytes_total Total bytes processed by NAT masquerade
# TYPE nftables_nat_bytes_total counter
nftables_nat_bytes_total $nat_bytes
EOF

    # Atomic move
    mv "$TEMP_FILE" "$METRICS_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

main() {
    check_nft_command
    check_permissions
    write_metrics
}

main "$@"
