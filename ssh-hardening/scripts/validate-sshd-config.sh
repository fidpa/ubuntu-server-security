#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# SSH Configuration Validator
#
# Validates SSH server configuration before deployment to prevent lockout.
# Checks syntax, baseline security compliance, permissions, and user accounts.
#
# Features:
# - Syntax validation (sshd -t)
# - Baseline compliance (ed25519, no weak ciphers)
# - File permission checks (0600 configs, 0644 drop-ins)
# - User account validation
# - JSON output for CI/CD integration
# - Lockout risk detection
#
# Usage:
#   ./validate-sshd-config.sh --config /etc/ssh/sshd_config
#   ./validate-sshd-config.sh --config /etc/ssh/sshd_config --json
#
# Exit Codes:
#   0 - OK (validation passed)
#   1 - Warning (non-critical issues)
#   2 - Error (critical configuration error)
#   3 - Lockout risk (would break SSH access)
#
# Documentation: https://github.com/fidpa/ubuntu-server-security/ssh-hardening/docs/TROUBLESHOOTING.md
# Version: 1.0.0
# Created: 2026-01-04

set -uo pipefail

# ============================================
# Configuration
# ============================================

CONFIG_FILE="${CONFIG_FILE:-/etc/ssh/sshd_config}"
JSON_OUTPUT=false
VERBOSE=false

# Exit codes
EXIT_OK=0
EXIT_WARNING=1
EXIT_ERROR=2
EXIT_LOCKOUT_RISK=3

# Colors (disabled in JSON mode)
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Validation results
WARNINGS=()
ERRORS=()
CHECKS_PASSED=0
CHECKS_TOTAL=0

# ============================================
# Functions
# ============================================

log() {
    local level="$1"
    shift
    local message="$*"

    if [[ "$JSON_OUTPUT" == "false" ]]; then
        case "$level" in
            ERROR)   echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
            WARNING) echo -e "${YELLOW}[WARNING]${NC} $message" >&2 ;;
            OK)      echo -e "${GREEN}[OK]${NC} $message" ;;
            INFO)    echo "[INFO] $message" ;;
        esac
    fi
}

add_warning() {
    WARNINGS+=("$1")
    log WARNING "$1"
}

add_error() {
    ERRORS+=("$1")
    log ERROR "$1"
}

check_syntax() {
    log INFO "Checking SSH configuration syntax..."
    ((CHECKS_TOTAL++))

    if ! sudo sshd -t -f "$CONFIG_FILE" 2>&1; then
        add_error "Syntax check failed: Invalid sshd_config"
        return 1
    fi

    ((CHECKS_PASSED++))
    log OK "Syntax check passed"
    return 0
}

check_baseline_compliance() {
    log INFO "Checking baseline security compliance..."
    local config_content
    config_content=$(cat "$CONFIG_FILE")

    # Check 1: PasswordAuthentication disabled
    ((CHECKS_TOTAL++))
    if echo "$config_content" | grep -qE "^PasswordAuthentication\s+no"; then
        ((CHECKS_PASSED++))
        log OK "PasswordAuthentication disabled"
    else
        add_error "PasswordAuthentication must be 'no' (lockout risk if SSH keys not configured)"
        return 1
    fi

    # Check 2: PubkeyAuthentication enabled
    ((CHECKS_TOTAL++))
    if echo "$config_content" | grep -qE "^PubkeyAuthentication\s+yes"; then
        ((CHECKS_PASSED++))
        log OK "PubkeyAuthentication enabled"
    else
        add_error "PubkeyAuthentication must be 'yes'"
    fi

    # Check 3: Ed25519 in accepted key types
    ((CHECKS_TOTAL++))
    if echo "$config_content" | grep -qE "^PubkeyAcceptedKeyTypes.*ssh-ed25519"; then
        ((CHECKS_PASSED++))
        log OK "Ed25519 keys accepted"
    else
        add_warning "Ed25519 not in PubkeyAcceptedKeyTypes (consider adding for modern crypto)"
    fi

    # Check 4: No weak ciphers (CBC)
    ((CHECKS_TOTAL++))
    if echo "$config_content" | grep -qE "^Ciphers.*-cbc"; then
        add_error "Weak CBC ciphers detected (security risk)"
    else
        ((CHECKS_PASSED++))
        log OK "No weak CBC ciphers"
    fi

    # Check 5: PermitRootLogin disabled
    ((CHECKS_TOTAL++))
    if echo "$config_content" | grep -qE "^PermitRootLogin\s+no"; then
        ((CHECKS_PASSED++))
        log OK "Root login disabled"
    else
        add_warning "PermitRootLogin should be 'no' (CIS Benchmark 5.2.12)"
    fi

    return 0
}

check_permissions() {
    log INFO "Checking file permissions..."

    # Check 1: Main config file (0600 or 0644)
    ((CHECKS_TOTAL++))
    local perms
    perms=$(stat -c "%a" "$CONFIG_FILE")
    if [[ "$perms" == "600" || "$perms" == "644" ]]; then
        ((CHECKS_PASSED++))
        log OK "Config file permissions: $perms"
    else
        add_error "Config file has insecure permissions: $perms (should be 600 or 644)"
    fi

    # Check 2: Drop-in directory (if exists)
    if [[ -d "/etc/ssh/sshd_config.d" ]]; then
        ((CHECKS_TOTAL++))
        local dropin_perms
        dropin_perms=$(stat -c "%a" "/etc/ssh/sshd_config.d")
        if [[ "$dropin_perms" == "755" ]]; then
            ((CHECKS_PASSED++))
            log OK "Drop-in directory permissions: $dropin_perms"
        else
            add_warning "Drop-in directory permissions: $dropin_perms (recommended: 755)"
        fi
    fi

    return 0
}

check_lockout_risk() {
    log INFO "Checking for SSH lockout risks..."
    local config_content
    config_content=$(cat "$CONFIG_FILE")

    # Check 1: If PasswordAuthentication is disabled, ensure at least one user has SSH keys
    ((CHECKS_TOTAL++))
    if echo "$config_content" | grep -qE "^PasswordAuthentication\s+no"; then
        # Check if current user has authorized_keys
        if [[ -f "$HOME/.ssh/authorized_keys" ]] && [[ -s "$HOME/.ssh/authorized_keys" ]]; then
            ((CHECKS_PASSED++))
            log OK "Current user has SSH keys configured"
        else
            add_error "LOCKOUT RISK: PasswordAuthentication disabled but no SSH keys found for current user"
            return 1
        fi
    fi

    return 0
}

output_json() {
    local exit_code="$1"
    cat <<EOF
{
  "validation_status": "$exit_code",
  "config_file": "$CONFIG_FILE",
  "checks_total": $CHECKS_TOTAL,
  "checks_passed": $CHECKS_PASSED,
  "warnings_count": ${#WARNINGS[@]},
  "errors_count": ${#ERRORS[@]},
  "warnings": [$(printf '"%s",' "${WARNINGS[@]}" | sed 's/,$//')]
  "errors": [$(printf '"%s",' "${ERRORS[@]}" | sed 's/,$//')]
}
EOF
}

# ============================================
# Main
# ============================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--config FILE] [--json] [--verbose]"
                echo ""
                echo "Options:"
                echo "  --config FILE   Path to sshd_config (default: /etc/ssh/sshd_config)"
                echo "  --json          Output results as JSON"
                echo "  --verbose       Verbose logging"
                echo "  --help          Show this help"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Disable colors in JSON mode
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        RED=""
        YELLOW=""
        GREEN=""
        NC=""
    fi

    log INFO "Validating SSH configuration: $CONFIG_FILE"

    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        add_error "Config file not found: $CONFIG_FILE"
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json "$EXIT_ERROR"
        fi
        exit "$EXIT_ERROR"
    fi

    # Run validation checks
    check_syntax
    check_baseline_compliance
    check_permissions
    check_lockout_risk

    # Determine exit code
    local exit_code=$EXIT_OK

    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        # Check for lockout risk
        if printf '%s\n' "${ERRORS[@]}" | grep -q "LOCKOUT RISK"; then
            exit_code=$EXIT_LOCKOUT_RISK
        else
            exit_code=$EXIT_ERROR
        fi
    elif [[ ${#WARNINGS[@]} -gt 0 ]]; then
        exit_code=$EXIT_WARNING
    fi

    # Output results
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        output_json "$exit_code"
    else
        echo ""
        echo "==================================="
        echo "Validation Summary"
        echo "==================================="
        echo "Checks passed: $CHECKS_PASSED/$CHECKS_TOTAL"
        echo "Warnings: ${#WARNINGS[@]}"
        echo "Errors: ${#ERRORS[@]}"
        echo ""

        case "$exit_code" in
            "$EXIT_OK")
                log OK "Validation PASSED - Safe to deploy"
                ;;
            "$EXIT_WARNING")
                log WARNING "Validation passed with WARNINGS"
                ;;
            "$EXIT_ERROR")
                log ERROR "Validation FAILED - Do not deploy"
                ;;
            "$EXIT_LOCKOUT_RISK")
                log ERROR "LOCKOUT RISK DETECTED - Deployment would break SSH access"
                ;;
        esac
    fi

    exit "$exit_code"
}

main "$@"
