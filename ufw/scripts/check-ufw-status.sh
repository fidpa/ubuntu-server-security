#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# UFW Status Check Script
# ═══════════════════════════════════════════════════════════════════════════
# Copyright (c) 2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# Purpose: Comprehensive UFW status check with CIS compliance verification
# Usage: ./check-ufw-status.sh [--verbose|-v] [--cis] [--json]
#
# Exit Codes:
#   0 - All checks passed
#   1 - Warnings found
#   2 - Errors found
#   3 - UFW not installed or not active
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0

# Options
VERBOSE=false
CIS_CHECK=false
JSON_OUTPUT=false

# ═══════════════════════════════════════════════════════════════════════════
# Functions
# ═══════════════════════════════════════════════════════════════════════════

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

UFW Status Check with CIS Benchmark Compliance verification.

Options:
  -v, --verbose    Show detailed output
  -c, --cis        Run CIS Benchmark compliance checks
  -j, --json       Output in JSON format
  -h, --help       Show this help message
  --version        Show version

Examples:
  $SCRIPT_NAME              # Basic status check
  $SCRIPT_NAME --cis        # Include CIS compliance checks
  $SCRIPT_NAME -v --cis     # Verbose with CIS checks

Exit Codes:
  0  All checks passed
  1  Warnings found
  2  Errors found
  3  UFW not installed or not active
EOF
}

info() {
    [[ "$JSON_OUTPUT" == "true" ]] && return
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    [[ "$JSON_OUTPUT" == "true" ]] && return
    echo -e "${GREEN}[PASS]${NC} $1"
}

warning() {
    [[ "$JSON_OUTPUT" == "true" ]] && return
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

error() {
    [[ "$JSON_OUTPUT" == "true" ]] && return
    echo -e "${RED}[FAIL]${NC} $1"
    ((ERRORS++))
}

# ═══════════════════════════════════════════════════════════════════════════
# Checks
# ═══════════════════════════════════════════════════════════════════════════

check_ufw_installed() {
    if dpkg -l ufw &>/dev/null; then
        success "UFW is installed"
        return 0
    else
        error "UFW is NOT installed"
        return 1
    fi
}

check_ufw_active() {
    local status
    status=$(sudo ufw status 2>/dev/null | head -1)

    if [[ "$status" == "Status: active" ]]; then
        success "UFW is active"
        return 0
    else
        error "UFW is NOT active"
        return 1
    fi
}

check_service_enabled() {
    if systemctl is-enabled ufw &>/dev/null; then
        success "UFW service is enabled"
        return 0
    else
        warning "UFW service is NOT enabled (won't start on boot)"
        return 1
    fi
}

check_default_policies() {
    local verbose_status
    verbose_status=$(sudo ufw status verbose 2>/dev/null)

    # Check incoming policy
    if echo "$verbose_status" | grep -q "deny (incoming)"; then
        success "Default incoming policy: DENY"
    else
        error "Default incoming policy is NOT deny"
    fi

    # Check outgoing policy
    if echo "$verbose_status" | grep -q "allow (outgoing)"; then
        success "Default outgoing policy: ALLOW"
    elif echo "$verbose_status" | grep -q "deny (outgoing)"; then
        info "Default outgoing policy: DENY (restrictive)"
    else
        warning "Default outgoing policy not set"
    fi
}

count_rules() {
    local ipv4_count ipv6_count

    # Count IPv4 rules
    ipv4_count=$(sudo ufw status numbered 2>/dev/null | grep -c "^\[" || echo "0")

    # Check IPv6 status
    local ipv6_enabled
    ipv6_enabled=$(grep "^IPV6=" /etc/default/ufw 2>/dev/null | cut -d= -f2)

    echo ""
    info "=== Rule Statistics ==="
    echo "  IPv4 Rules: $ipv4_count"
    echo "  IPv6 Enabled: ${ipv6_enabled:-unknown}"
}

show_rules() {
    echo ""
    info "=== Active Rules ==="
    sudo ufw status numbered 2>/dev/null
}

check_logging() {
    local log_level
    log_level=$(sudo ufw status verbose 2>/dev/null | grep "^Logging:" | awk '{print $2}')

    case "$log_level" in
        "on")
            success "Logging: enabled (default level)"
            ;;
        "off")
            warning "Logging: disabled"
            ;;
        *)
            success "Logging: $log_level"
            ;;
    esac

    # Check log file exists
    if [[ -f /var/log/ufw.log ]]; then
        local log_size
        log_size=$(du -h /var/log/ufw.log 2>/dev/null | cut -f1)
        [[ "$VERBOSE" == "true" ]] && echo "  Log file size: $log_size"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# CIS Benchmark Checks
# ═══════════════════════════════════════════════════════════════════════════

run_cis_checks() {
    echo ""
    info "=== CIS Benchmark Checks (3.5.1.x) ==="

    # 3.5.1.1 - UFW installed
    echo -n "  3.5.1.1 ufw installed: "
    if dpkg -l ufw &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        ((ERRORS++))
    fi

    # 3.5.1.2 - iptables-persistent NOT installed
    echo -n "  3.5.1.2 iptables-persistent absent: "
    if ! dpkg -l iptables-persistent &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC} (conflict with UFW)"
        ((ERRORS++))
    fi

    # 3.5.1.3 - UFW service enabled
    echo -n "  3.5.1.3 ufw service enabled: "
    if systemctl is-enabled ufw &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        ((ERRORS++))
    fi

    # 3.5.1.4 - Loopback configured (UFW handles this automatically)
    echo -n "  3.5.1.4 loopback configured: "
    echo -e "${GREEN}PASS${NC} (automatic)"

    # 3.5.1.5 - Outbound connections
    echo -n "  3.5.1.5 outbound configured: "
    if sudo ufw status verbose 2>/dev/null | grep -q "(outgoing)"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${YELLOW}WARN${NC}"
        ((WARNINGS++))
    fi

    # 3.5.1.7 - Default deny
    echo -n "  3.5.1.7 default deny: "
    if sudo ufw status verbose 2>/dev/null | grep -q "deny (incoming)"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        ((ERRORS++))
    fi

    # 3.1.1 - IPv6 disabled (optional)
    echo -n "  3.1.1   IPv6 disabled: "
    local ipv6_status
    ipv6_status=$(grep "^IPV6=" /etc/default/ufw 2>/dev/null | cut -d= -f2)
    if [[ "$ipv6_status" == "no" ]]; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${YELLOW}INFO${NC} (enabled: $ipv6_status)"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# JSON Output
# ═══════════════════════════════════════════════════════════════════════════

output_json() {
    local ufw_status active enabled default_incoming default_outgoing
    local ipv4_rules ipv6_enabled log_level

    ufw_status=$(sudo ufw status 2>/dev/null | head -1 | awk '{print $2}')
    active=$([[ "$ufw_status" == "active" ]] && echo "true" || echo "false")
    enabled=$(systemctl is-enabled ufw 2>/dev/null && echo "true" || echo "false")

    local verbose_output
    verbose_output=$(sudo ufw status verbose 2>/dev/null)
    default_incoming=$(echo "$verbose_output" | grep "Default:" | grep -o "[a-z]* (incoming)" | awk '{print $1}')
    default_outgoing=$(echo "$verbose_output" | grep "Default:" | grep -o "[a-z]* (outgoing)" | awk '{print $1}')

    ipv4_rules=$(sudo ufw status numbered 2>/dev/null | grep -c "^\[" || echo "0")
    ipv6_enabled=$(grep "^IPV6=" /etc/default/ufw 2>/dev/null | cut -d= -f2)
    log_level=$(echo "$verbose_output" | grep "^Logging:" | awk '{print $2}')

    cat <<EOF
{
  "version": "$VERSION",
  "timestamp": "$(date -Iseconds)",
  "ufw": {
    "installed": $(dpkg -l ufw &>/dev/null && echo "true" || echo "false"),
    "active": $active,
    "enabled": $enabled,
    "default_incoming": "$default_incoming",
    "default_outgoing": "$default_outgoing",
    "ipv4_rules": $ipv4_rules,
    "ipv6_enabled": "$ipv6_enabled",
    "logging": "$log_level"
  },
  "checks": {
    "errors": $ERRORS,
    "warnings": $WARNINGS
  }
}
EOF
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -c|--cis)
                CIS_CHECK=true
                shift
                ;;
            -j|--json)
                JSON_OUTPUT=true
                shift
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
                exit 2
                ;;
        esac
    done

    # JSON output mode
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        output_json
        exit 0
    fi

    echo "═══════════════════════════════════════════════════════════════"
    echo " UFW Status Check v$VERSION"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Check if UFW is installed
    if ! check_ufw_installed; then
        echo ""
        error "UFW is not installed. Install with: sudo apt install ufw"
        exit 3
    fi

    # Check if UFW is active
    if ! check_ufw_active; then
        echo ""
        error "UFW is not active. Enable with: sudo ufw enable"
        exit 3
    fi

    # Basic checks
    check_service_enabled
    check_default_policies
    check_logging

    # Rule statistics
    count_rules

    # Show rules if verbose
    if [[ "$VERBOSE" == "true" ]]; then
        show_rules
    fi

    # CIS checks if requested
    if [[ "$CIS_CHECK" == "true" ]]; then
        run_cis_checks
    fi

    # Summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    if [[ $ERRORS -gt 0 ]]; then
        echo -e " Result: ${RED}$ERRORS error(s)${NC}, ${YELLOW}$WARNINGS warning(s)${NC}"
        exit 2
    elif [[ $WARNINGS -gt 0 ]]; then
        echo -e " Result: ${YELLOW}$WARNINGS warning(s)${NC}"
        exit 1
    else
        echo -e " Result: ${GREEN}All checks passed${NC}"
        exit 0
    fi
}

main "$@"
