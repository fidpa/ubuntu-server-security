#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# nftables Configuration Validator
# ═══════════════════════════════════════════════════════════════════════════
# Copyright (c) 2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# Purpose: Validate nftables configuration before deployment
# Usage: ./validate-nftables.sh <config-file>
#
# Exit Codes:
# 0 - Valid configuration
# 1 - Warnings (non-critical issues)
# 2 - Errors (critical issues)
# 3 - Lockout risk (SSH or connectivity issues)
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

readonly SCRIPT_NAME="$(basename "$0")"
readonly CONFIG_FILE="${1:-}"

# Colors for output
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No Color

# Counters
declare -i ERRORS=0
declare -i WARNINGS=0

# ═══════════════════════════════════════════════════════════════════════════
# Functions
# ═══════════════════════════════════════════════════════════════════════════

error() {
    echo -e "${RED}❌ ERROR: $*${NC}" >&2
    ((ERRORS++))
}

warning() {
    echo -e "${YELLOW}⚠️  WARNING: $*${NC}" >&2
    ((WARNINGS++))
}

success() {
    echo -e "${GREEN}✅ $*${NC}"
}

info() {
    echo "ℹ️  $*"
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME <config-file>

Validates nftables configuration before deployment.

Checks:
  - Syntax validation
  - Rule order (accept before drop)
  - Docker chain preservation
  - Interface existence
  - Negation bug detection
  - Security best practices
  - NAT configuration

Examples:
  $SCRIPT_NAME /etc/nftables.conf
  $SCRIPT_NAME drop-ins/10-gateway.nft.template

Exit Codes:
  0 - Valid configuration
  1 - Warnings (non-critical)
  2 - Errors (critical issues)
  3 - Lockout risk (SSH/connectivity)
EOF
    exit 1
}

# ═══════════════════════════════════════════════════════════════════════════
# Validation Checks
# ═══════════════════════════════════════════════════════════════════════════

check_syntax() {
    info "Checking syntax..."
    if ! sudo nft -c -f "$CONFIG_FILE" 2>&1; then
        error "Syntax check failed"
        return 1
    fi
    success "Syntax: Valid"
}

check_docker_chain_preservation() {
    info "Checking Docker chain preservation..."

    # Check if Docker is running
    if systemctl is-active --quiet docker 2>/dev/null; then
        if grep -q "flush ruleset" "$CONFIG_FILE"; then
            error "Docker is running but config uses 'flush ruleset'"
            error "This will destroy Docker's DOCKER chain!"
            error "Use 'flush table inet filter' and 'flush table ip nat' instead"
            return 1
        fi
        success "Docker chain preservation: OK"
    else
        if grep -q "flush ruleset" "$CONFIG_FILE"; then
            warning "Config uses 'flush ruleset' (breaks Docker if installed)"
        fi
    fi
}

check_interface_existence() {
    info "Checking interface existence..."

    # Extract interface definitions
    local interfaces
    interfaces=$(grep -oP 'define \w+_INTERFACE = "\K[^"]+' "$CONFIG_FILE" 2>/dev/null || true)

    if [[ -z "$interfaces" ]]; then
        info "No interface variables found (skipping check)"
        return 0
    fi

    local missing=0
    while IFS= read -r iface; do
        if ! ip link show "$iface" &>/dev/null; then
            warning "Interface '$iface' not found (update variable or create interface)"
            ((missing++))
        fi
    done <<< "$interfaces"

    if [[ $missing -eq 0 ]]; then
        success "Interface existence: All found"
    fi
}

check_negation_bug() {
    info "Checking for negation bug (interval sets)..."

    # Detect != with @set patterns (doesn't work with interval sets)
    if grep -qE '!=\s+@\w+' "$CONFIG_FILE"; then
        error "Negation bug detected: '!= @set' doesn't work with interval sets"
        error "Use positive matching instead:"
        error "  ✅ ip saddr @whitelist accept"
        error "  ✅ counter reject (after whitelist)"
        error "  ❌ ip saddr != @whitelist reject (BROKEN)"
        return 1
    fi
    success "Negation bug: None detected"
}

check_default_policy() {
    info "Checking default policy..."

    local input_policy
    local forward_policy

    input_policy=$(grep -oP 'chain input.*policy \K\w+' "$CONFIG_FILE" || true)
    forward_policy=$(grep -oP 'chain forward.*policy \K\w+' "$CONFIG_FILE" || true)

    if [[ "$input_policy" != "drop" ]]; then
        error "INPUT chain policy is not 'drop' (current: $input_policy)"
    else
        success "Default policy: DROP (secure)"
    fi

    if grep -q "chain forward" "$CONFIG_FILE"; then
        if [[ "$forward_policy" != "drop" ]]; then
            warning "FORWARD chain policy is not 'drop' (current: $forward_policy)"
        fi
    fi
}

check_ssh_security() {
    info "Checking SSH security..."

    # Check for unrestricted SSH (0.0.0.0/0 or no source restriction)
    if grep -E 'tcp dport 22 accept' "$CONFIG_FILE" | grep -qvE '(iifname|ip saddr)'; then
        warning "SSH allows connections from 0.0.0.0/0 (consider restricting)"
        warning "Recommended: iifname \$MGMT_INTERFACE tcp dport 22 accept"
    else
        success "SSH security: Restricted to specific interfaces/IPs"
    fi

    # Check for telnet (port 23)
    if grep -qE 'tcp dport 23 accept' "$CONFIG_FILE"; then
        error "Telnet (port 23) is allowed - use SSH instead!"
    fi
}

check_nat_configuration() {
    info "Checking NAT configuration..."

    if grep -q "table ip nat" "$CONFIG_FILE"; then
        if ! grep -q "masquerade" "$CONFIG_FILE"; then
            warning "NAT table exists but no masquerade rules found"
            warning "LAN clients may not be able to access Internet"
        else
            success "NAT masquerading: Configured"
        fi
    else
        info "No NAT table (OK for server role)"
    fi
}

check_rule_order() {
    info "Checking rule order..."

    # This is a simplified check - real validation would need full parsing
    local drop_line
    local last_accept_line

    drop_line=$(grep -n "counter drop" "$CONFIG_FILE" | head -1 | cut -d: -f1 || true)
    last_accept_line=$(grep -n "accept" "$CONFIG_FILE" | tail -1 | cut -d: -f1 || true)

    if [[ -n "$drop_line" ]] && [[ -n "$last_accept_line" ]]; then
        if [[ $drop_line -lt $last_accept_line ]]; then
            warning "Potential rule order issue: drop rule before accept rule"
            warning "Check lines $drop_line and $last_accept_line"
        else
            success "Rule order: OK (accept before drop)"
        fi
    fi
}

check_mss_clamping() {
    info "Checking MSS clamping..."

    if grep -q "chain forward" "$CONFIG_FILE"; then
        if ! grep -q "tcp option maxseg size set rt mtu" "$CONFIG_FILE"; then
            warning "Forward chain exists but no MSS clamping configured"
            warning "NAT clients may experience MTU/fragmentation issues"
            warning "Add: tcp flags syn tcp option maxseg size set rt mtu"
        else
            success "MSS clamping: Configured"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

main() {
    # Check arguments
    if [[ -z "$CONFIG_FILE" ]]; then
        usage
    fi

    # Check file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Config file not found: $CONFIG_FILE"
        exit 2
    fi

    echo "════════════════════════════════════════════════════════════════════════════"
    echo "nftables Configuration Validator"
    echo "Config: $CONFIG_FILE"
    echo "════════════════════════════════════════════════════════════════════════════"
    echo

    # Run all checks
    check_syntax || true
    check_docker_chain_preservation || true
    check_interface_existence || true
    check_negation_bug || true
    check_default_policy || true
    check_ssh_security || true
    check_nat_configuration || true
    check_rule_order || true
    check_mss_clamping || true

    # Summary
    echo
    echo "════════════════════════════════════════════════════════════════════════════"
    echo "Validation Summary"
    echo "════════════════════════════════════════════════════════════════════════════"

    if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}✅ VALIDATION PASSED: No issues found${NC}"
        exit 0
    elif [[ $ERRORS -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  VALIDATION PASSED WITH WARNINGS: $WARNINGS warning(s)${NC}"
        exit 1
    else
        echo -e "${RED}❌ VALIDATION FAILED: $ERRORS error(s), $WARNINGS warning(s)${NC}"

        # Check for lockout risk
        if grep -qE 'tcp dport 22' "$CONFIG_FILE"; then
            exit 2
        else
            echo -e "${RED}🚨 LOCKOUT RISK: No SSH rule found!${NC}"
            exit 3
        fi
    fi
}

main "$@"
