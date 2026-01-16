#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# fail2ban Configuration Validation Script
# Validates fail2ban configuration syntax and jail setup
#
# Features:
# - Syntax validation
# - Jail configuration checks
# - Filter existence validation
# - Action configuration checks
#
# Usage:
#   validate-fail2ban-config.sh
#
# Exit Codes:
#   0: All validations passed
#   1: Validation errors found
#
# Version: 1.0.0

set -uo pipefail

# ============================================
# Configuration
# ============================================

readonly SCRIPT_NAME="$(basename "$0")"
ERRORS=0

# ============================================
# Functions
# ============================================

log_info() {
    printf '[INFO] %s\n' "$1"
}

log_error() {
    printf '[ERROR] %s\n' "$1" >&2
    ((ERRORS++))
}

log_success() {
    printf '[OK] %s\n' "$1"
}

# Validate fail2ban syntax
validate_syntax() {
    log_info "Validating fail2ban configuration syntax..."

    if ! command -v fail2ban-client &>/dev/null; then
        log_error "fail2ban-client not found. Is fail2ban installed?"
        return 1
    fi

    if fail2ban-client --test >/dev/null 2>&1; then
        log_success "Configuration syntax is valid"
        return 0
    else
        log_error "Configuration syntax is invalid"
        fail2ban-client --test 2>&1 | head -20
        return 1
    fi
}

# Validate jail configurations
validate_jails() {
    log_info "Validating jail configurations..."

    local jail_dir="/etc/fail2ban/jail.d"
    if [[ ! -d "$jail_dir" ]]; then
        log_error "Jail directory not found: $jail_dir"
        return 1
    fi

    local jail_count=0
    for jail_file in "$jail_dir"/*.conf; do
        [[ -f "$jail_file" ]] || continue

        local jail_name
        jail_name=$(basename "$jail_file" .conf)
        ((jail_count++))

        # Check if jail is parseable
        if fail2ban-client --test 2>&1 | grep -q "ERROR.*$jail_name"; then
            log_error "Jail has syntax errors: $jail_name ($jail_file)"
        else
            log_success "Jail is valid: $jail_name"
        fi
    done

    if [[ $jail_count -eq 0 ]]; then
        log_error "No jail configurations found in $jail_dir"
        return 1
    fi

    log_info "Validated $jail_count jail configurations"
    return 0
}

# Validate custom filters
validate_filters() {
    log_info "Validating custom filters..."

    local filter_dir="/etc/fail2ban/filter.d"
    local custom_filters=0

    # Check for custom filters (non-standard ones)
    for filter_file in "$filter_dir"/*.conf; do
        [[ -f "$filter_file" ]] || continue

        local filter_name
        filter_name=$(basename "$filter_file" .conf)

        # Check if filter is custom (not in default fail2ban)
        # Custom filters typically: vnc, custom-*, etc.
        if [[ "$filter_name" =~ ^(vnc|custom-.*|local-.*)$ ]]; then
            ((custom_filters++))
            if grep -q "failregex\s*=" "$filter_file"; then
                log_success "Custom filter is valid: $filter_name"
            else
                log_error "Custom filter missing failregex: $filter_name"
            fi
        fi
    done

    if [[ $custom_filters -gt 0 ]]; then
        log_info "Validated $custom_filters custom filters"
    else
        log_info "No custom filters found (using only standard filters)"
    fi

    return 0
}

# Validate custom actions
validate_actions() {
    log_info "Validating custom actions..."

    local action_dir="/etc/fail2ban/action.d"
    local custom_actions=0

    for action_file in "$action_dir"/*.conf; do
        [[ -f "$action_file" ]] || continue

        local action_name
        action_name=$(basename "$action_file" .conf)

        # Check if action is custom (telegram, webhook, etc.)
        if [[ "$action_name" =~ ^(telegram|webhook|custom-.*)$ ]]; then
            ((custom_actions++))
            if grep -q "\[Definition\]" "$action_file"; then
                log_success "Custom action is valid: $action_name"

                # Check if action script exists (for telegram)
                if [[ "$action_name" == "telegram" ]]; then
                    local script_path="/etc/fail2ban/action.d/telegram-send.sh"
                    if [[ -x "$script_path" ]]; then
                        log_success "Telegram script is executable: $script_path"
                    else
                        log_error "Telegram script not found or not executable: $script_path"
                    fi
                fi
            else
                log_error "Custom action missing [Definition] section: $action_name"
            fi
        fi
    done

    if [[ $custom_actions -gt 0 ]]; then
        log_info "Validated $custom_actions custom actions"
    else
        log_info "No custom actions found (using only standard actions)"
    fi

    return 0
}

# Check GeoIP dependencies
validate_geoip_dependencies() {
    log_info "Checking GeoIP dependencies (optional)..."

    local geoip_jail="/etc/fail2ban/jail.d/40-geoip.conf"
    if [[ ! -f "$geoip_jail" ]]; then
        log_info "GeoIP jail not deployed (optional feature)"
        return 0
    fi

    # Check if geoiplookup is available
    if ! command -v geoiplookup &>/dev/null; then
        log_error "GeoIP jail deployed but geoiplookup not found. Install: apt install geoip-bin"
        return 1
    fi

    # Check if geoip-whitelist.sh script exists
    local geoip_script="/usr/local/bin/geoip-whitelist.sh"
    if [[ -x "$geoip_script" ]]; then
        log_success "GeoIP whitelist script is installed: $geoip_script"
    else
        log_error "GeoIP whitelist script not found or not executable: $geoip_script"
    fi

    return 0
}

# Check Telegram dependencies
validate_telegram_dependencies() {
    log_info "Checking Telegram dependencies (optional)..."

    local telegram_action="/etc/fail2ban/action.d/telegram.conf"
    if [[ ! -f "$telegram_action" ]]; then
        log_info "Telegram action not deployed (optional feature)"
        return 0
    fi

    # Check if curl is available
    if ! command -v curl &>/dev/null; then
        log_error "Telegram action deployed but curl not found. Install: apt install curl"
        return 1
    fi

    # Check if .env.secrets exists
    local device_name
    device_name=$(hostname -s)
    local secrets_file="/etc/${device_name}/.env.secrets"

    if [[ -f "$secrets_file" ]]; then
        if grep -q "TELEGRAM_BOT_TOKEN" "$secrets_file" && \
           grep -q "TELEGRAM_CHAT_ID" "$secrets_file"; then
            log_success "Telegram credentials configured in $secrets_file"
        else
            log_error "Telegram credentials missing in $secrets_file"
        fi
    else
        log_error "Secrets file not found: $secrets_file"
    fi

    return 0
}

# ============================================
# Main
# ============================================

main() {
    printf '\n=== fail2ban Configuration Validation ===\n\n'

    validate_syntax
    validate_jails
    validate_filters
    validate_actions
    validate_geoip_dependencies
    validate_telegram_dependencies

    printf '\n=== Validation Summary ===\n'
    if [[ $ERRORS -eq 0 ]]; then
        log_success "All validations passed!"
        return 0
    else
        log_error "Found $ERRORS validation error(s)"
        return 1
    fi
}

main "$@"
