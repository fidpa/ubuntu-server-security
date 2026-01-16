#!/bin/bash
# =============================================================================
# Ubuntu Server Security - Audit Rules Validation Script
# =============================================================================
#
# Validates audit rules syntax and CIS compliance before deployment
#
# Usage:
#   ./validate-audit-rules.sh [rules-file]
#   ./validate-audit-rules.sh                    # Validate all in rules.d/
#   ./validate-audit-rules.sh /path/to/rules     # Validate specific file
#
# =============================================================================

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

validate_file_syntax() {
    local file="$1"
    local errors=0

    log_info "Validating syntax: $file"

    # Use auditctl to check syntax (dry-run)
    if ! sudo auditctl -R "$file" 2>&1 | grep -qi "error\|invalid\|unknown"; then
        log_pass "Syntax valid"
    else
        log_fail "Syntax errors found:"
        sudo auditctl -R "$file" 2>&1 | grep -i "error\|invalid\|unknown"
        errors=1
    fi

    return $errors
}

check_required_keys() {
    local file="$1"
    local errors=0

    log_info "Checking CIS required keys..."

    # CIS Level 1 required keys
    local required_keys=(
        "time-change"
        "identity"
        "system-locale"
        "MAC-policy"
        "logins"
        "session"
        "perm_mod"
        "access"
        "privileged"
        "mounts"
        "scope"
        "actions"
        "modules"
    )

    for key in "${required_keys[@]}"; do
        if grep -q "key=$key" "$file"; then
            log_pass "Key present: $key"
        else
            log_warn "Key missing: $key"
            ((errors++))
        fi
    done

    return $errors
}

check_backlog_limit() {
    local file="$1"

    log_info "Checking backlog limit..."

    if grep -q "^-b [0-9]" "$file"; then
        local limit
        limit=$(grep "^-b [0-9]" "$file" | head -1 | awk '{print $2}')

        if [[ $limit -ge 8192 ]]; then
            log_pass "Backlog limit: $limit (CIS minimum: 8192)"
        else
            log_warn "Backlog limit: $limit (CIS recommends >= 8192)"
        fi
    else
        log_warn "No backlog limit set (-b)"
    fi
}

check_immutable() {
    local file="$1"

    log_info "Checking immutable mode..."

    if grep -q "^-e 2" "$file"; then
        log_warn "Immutable mode enabled (-e 2)"
        log_warn "Rule changes will require system reboot!"
    else
        log_info "Immutable mode not set (rules can be changed at runtime)"
    fi
}

check_arch_consistency() {
    local file="$1"
    local errors=0

    log_info "Checking architecture consistency..."

    local b64_count
    local b32_count

    b64_count=$(grep -c "arch=b64" "$file" || echo 0)
    b32_count=$(grep -c "arch=b32" "$file" || echo 0)

    if [[ $b64_count -gt 0 ]] && [[ $b32_count -eq 0 ]]; then
        log_warn "Only 64-bit rules found. Add 32-bit rules for complete coverage."
        ((errors++))
    elif [[ $b32_count -gt 0 ]] && [[ $b64_count -eq 0 ]]; then
        log_warn "Only 32-bit rules found. Add 64-bit rules for 64-bit systems."
        ((errors++))
    else
        log_pass "Both 64-bit and 32-bit architectures covered"
    fi

    return $errors
}

check_auid_filters() {
    local file="$1"

    log_info "Checking auid filters..."

    # Check for proper auid filtering (ignore system accounts)
    local auid_rules
    auid_rules=$(grep -c "auid>=1000" "$file" || echo 0)

    if [[ $auid_rules -gt 0 ]]; then
        log_pass "Found $auid_rules rules with auid>=1000 filter"
    else
        log_warn "No auid>=1000 filters found. System account activity will be logged."
    fi

    # Check for unset auid exclusion
    local unset_rules
    unset_rules=$(grep -c "auid!=4294967295" "$file" || echo 0)

    if [[ $unset_rules -gt 0 ]]; then
        log_pass "Found $unset_rules rules excluding unset auid"
    else
        log_warn "No auid!=4294967295 exclusions. Unattributed events will be logged."
    fi
}

validate_single_file() {
    local file="$1"
    local total_errors=0

    echo ""
    echo "=============================================="
    echo "Validating: $file"
    echo "=============================================="

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    validate_file_syntax "$file" || ((total_errors++))
    check_backlog_limit "$file"
    check_required_keys "$file" || ((total_errors++))
    check_arch_consistency "$file" || ((total_errors++))
    check_auid_filters "$file"
    check_immutable "$file"

    echo ""
    if [[ $total_errors -eq 0 ]]; then
        log_pass "Validation passed with no errors"
    else
        log_warn "Validation completed with $total_errors warning(s)"
    fi

    return $total_errors
}

validate_rules_directory() {
    local rules_dir="${1:-/etc/audit/rules.d}"
    local total_errors=0

    log_info "Validating all rules in: $rules_dir"

    if [[ ! -d "$rules_dir" ]]; then
        log_error "Directory not found: $rules_dir"
        return 1
    fi

    for rules_file in "$rules_dir"/*.rules; do
        if [[ -f "$rules_file" ]]; then
            validate_single_file "$rules_file" || ((total_errors++))
        fi
    done

    echo ""
    echo "=============================================="
    echo "Summary"
    echo "=============================================="

    if [[ $total_errors -eq 0 ]]; then
        log_pass "All validations passed"
    else
        log_warn "$total_errors file(s) had warnings"
    fi

    return $total_errors
}

show_usage() {
    echo "Usage: $0 [rules-file]"
    echo ""
    echo "Options:"
    echo "  (none)        Validate all files in /etc/audit/rules.d/"
    echo "  <file>        Validate specific rules file"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Validate installed rules"
    echo "  $0 /etc/audit/rules.d/99-cis.rules   # Validate specific file"
    echo "  $0 ../audit-base.rules.template      # Validate template before deploy"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    local target="${1:-}"

    # Check for help flag
    if [[ "$target" == "-h" ]] || [[ "$target" == "--help" ]]; then
        show_usage
        exit 0
    fi

    # Check if running as root (needed for auditctl)
    if [[ $EUID -ne 0 ]]; then
        log_warn "Not running as root. Some checks may fail."
        log_info "For full validation, run: sudo $0 $*"
    fi

    if [[ -n "$target" ]]; then
        validate_single_file "$target"
    else
        validate_rules_directory
    fi
}

main "$@"
