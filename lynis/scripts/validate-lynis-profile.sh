#!/bin/bash
# Lynis Profile Validation Script
# SPDX-License-Identifier: MIT
# Version: 1.0.0
#
# Purpose: Validate custom Lynis profile syntax before deployment
# Usage: ./validate-lynis-profile.sh /path/to/profile.prf

set -uo pipefail

# ============================================
# Variables
# ============================================

ERRORS=0

# ============================================
# Logging Functions
# ============================================

log_info() {
    printf '[INFO] %s\n' "$1"
}

log_success() {
    printf '[SUCCESS] %s\n' "$1"
}

log_error() {
    printf '[ERROR] %s\n' "$1" >&2
    ((ERRORS++)) || true
}

log_warning() {
    printf '[WARNING] %s\n' "$1" >&2
}

# ============================================
# Validation Functions
# ============================================

validate_file_exists() {
    local profile_file="$1"

    if [[ ! -f "$profile_file" ]]; then
        log_error "Profile file not found: $profile_file"
        return 1
    fi

    log_info "Profile file found: $profile_file"
}

validate_syntax() {
    local profile_file="$1"

    log_info "Validating profile syntax..."

    # Check for invalid lines (not comments, not config, not skip-test)
    local line_num=0
    while IFS= read -r line; do
        ((line_num++)) || true

        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
            continue
        fi

        # Valid patterns:
        # - config:key:value
        # - skip-test=TEST-ID
        # - skip-test=TEST-ID:detail

        if [[ ! "$line" =~ ^config: ]] && [[ ! "$line" =~ ^skip-test= ]]; then
            log_error "Invalid syntax at line $line_num: $line"
        fi
    done < "$profile_file"

    if [[ $ERRORS -eq 0 ]]; then
        log_success "Syntax validation passed"
    fi
}

validate_config_values() {
    local profile_file="$1"

    log_info "Validating config values..."

    # Extract config lines
    while IFS= read -r line; do
        if [[ "$line" =~ ^config: ]]; then
            local config_key
            config_key=$(echo "$line" | cut -d: -f2)
            local config_value
            config_value=$(echo "$line" | cut -d: -f3)

            # Validate password_max_days (should be numeric)
            if [[ "$config_key" == "password_max_days" ]]; then
                if ! [[ "$config_value" =~ ^[0-9]+$ ]]; then
                    log_error "Invalid password_max_days value: $config_value (must be numeric)"
                fi
            fi
        fi
    done < "$profile_file"

    if [[ $ERRORS -eq 0 ]]; then
        log_success "Config validation passed"
    fi
}

validate_skip_tests() {
    local profile_file="$1"

    log_info "Validating skip-test IDs..."

    # Extract skip-test lines
    local skip_count=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^skip-test= ]]; then
            ((skip_count++)) || true

            # Extract test ID (e.g., FILE-6310 or SSH-7408:X11Forwarding)
            local test_id
            test_id=$(echo "$line" | cut -d= -f2 | cut -d: -f1)

            # Validate test ID format (should be CATEGORY-NNNN)
            if ! [[ "$test_id" =~ ^[A-Z]+-[0-9]{4}$ ]]; then
                log_warning "Non-standard test ID format: $test_id"
            fi
        fi
    done < "$profile_file"

    log_info "Found $skip_count skip-test entries"
}

# ============================================
# Main Function
# ============================================

main() {
    local profile_file="${1:-}"

    if [[ -z "$profile_file" ]]; then
        log_error "Usage: $0 /path/to/profile.prf"
        exit 1
    fi

    log_info "Validating Lynis profile: $profile_file"
    echo ""

    validate_file_exists "$profile_file" || exit 1
    validate_syntax "$profile_file"
    validate_config_values "$profile_file"
    validate_skip_tests "$profile_file"

    echo ""
    if [[ $ERRORS -gt 0 ]]; then
        log_error "Validation failed with $ERRORS error(s)"
        exit 1
    else
        log_success "Profile validation passed!"
    fi
}

main "$@"
