#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# fail2ban Deployment Script
# Automated deployment of fail2ban configuration
#
# Features:
# - Template placeholder replacement
# - Drop-in jail deployment
# - Script installation
# - Validation
# - Service restart
#
# Usage:
#   sudo ./deploy-fail2ban.sh [--dry-run]
#
# Exit Codes:
#   0: Deployment successful
#   1: Deployment failed
#
# Version: 1.0.0

set -uo pipefail

# ============================================
# Configuration
# ============================================

readonly SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
readonly COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"

DRY_RUN=false

# ============================================
# Functions
# ============================================

log_info() {
    printf '[INFO] %s\n' "$1"
}

log_error() {
    printf '[ERROR] %s\n' "$1" >&2
}

log_success() {
    printf '[OK] %s\n' "$1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_fail2ban_installed() {
    if ! command -v fail2ban-client &>/dev/null; then
        log_error "fail2ban not installed. Install with: apt install fail2ban"
        exit 1
    fi
}

# Deploy base configuration
deploy_base_config() {
    log_info "Deploying base fail2ban configuration..."

    local src_file="${COMPONENT_DIR}/fail2ban.local.template"
    local dst_file="/etc/fail2ban/fail2ban.local"

    if [[ ! -f "$src_file" ]]; then
        log_error "Source template not found: $src_file"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would copy: $src_file → $dst_file"
    else
        cp "$src_file" "$dst_file"
        log_success "Deployed: $dst_file"
    fi
}

# Deploy jail configuration
deploy_jail_config() {
    log_info "Deploying jail configuration..."

    local src_file="${COMPONENT_DIR}/jail.local.template"
    local dst_file="/etc/fail2ban/jail.local"

    if [[ ! -f "$src_file" ]]; then
        log_error "Source template not found: $src_file"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would copy: $src_file → $dst_file"
    else
        cp "$src_file" "$dst_file"
        log_success "Deployed: $dst_file"
    fi
}

# Deploy drop-in jails
deploy_drop_ins() {
    log_info "Deploying drop-in jail configurations..."

    local src_dir="${COMPONENT_DIR}/drop-ins"
    local dst_dir="/etc/fail2ban/jail.d"

    if [[ ! -d "$src_dir" ]]; then
        log_error "Drop-in directory not found: $src_dir"
        return 1
    fi

    mkdir -p "$dst_dir"

    local deployed=0
    for jail_file in "$src_dir"/*.conf; do
        [[ -f "$jail_file" ]] || continue
        [[ "$(basename "$jail_file")" == "99-custom.conf.example" ]] && continue

        local jail_name
        jail_name=$(basename "$jail_file")

        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] Would copy: $jail_file → $dst_dir/$jail_name"
        else
            cp "$jail_file" "$dst_dir/$jail_name"
            log_success "Deployed jail: $jail_name"
        fi
        ((deployed++))
    done

    log_info "Deployed $deployed jail drop-ins"
}

# Deploy custom filters
deploy_filters() {
    log_info "Deploying custom filters..."

    local src_dir="${COMPONENT_DIR}/filters"
    local dst_dir="/etc/fail2ban/filter.d"

    if [[ ! -d "$src_dir" ]]; then
        log_info "No custom filters directory found (optional)"
        return 0
    fi

    local deployed=0
    for filter_file in "$src_dir"/*.conf; do
        [[ -f "$filter_file" ]] || continue

        local filter_name
        filter_name=$(basename "$filter_file")

        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] Would copy: $filter_file → $dst_dir/$filter_name"
        else
            cp "$filter_file" "$dst_dir/$filter_name"
            log_success "Deployed filter: $filter_name"
        fi
        ((deployed++))
    done

    log_info "Deployed $deployed custom filters"
}

# Deploy custom actions
deploy_actions() {
    log_info "Deploying custom actions..."

    local src_dir="${COMPONENT_DIR}/actions"
    local dst_dir="/etc/fail2ban/action.d"

    if [[ ! -d "$src_dir" ]]; then
        log_info "No custom actions directory found (optional)"
        return 0
    fi

    local deployed=0
    for action_file in "$src_dir"/*; do
        [[ -f "$action_file" ]] || continue
        [[ "$(basename "$action_file")" == "README.md" ]] && continue

        local action_name
        action_name=$(basename "$action_file")

        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] Would copy: $action_file → $dst_dir/$action_name"
        else
            cp "$action_file" "$dst_dir/$action_name"
            if [[ "$action_name" == *.sh ]]; then
                chmod 755 "$dst_dir/$action_name"
            fi
            log_success "Deployed action: $action_name"
        fi
        ((deployed++))
    done

    log_info "Deployed $deployed custom actions"
}

# Deploy scripts
deploy_scripts() {
    log_info "Deploying fail2ban scripts..."

    local src_dir="${COMPONENT_DIR}/scripts"
    local dst_dir="/usr/local/bin"

    if [[ ! -d "$src_dir" ]]; then
        log_info "No scripts directory found (optional)"
        return 0
    fi

    local deployed=0
    for script_file in "$src_dir"/*.sh; do
        [[ -f "$script_file" ]] || continue
        [[ "$(basename "$script_file")" == "deploy-fail2ban.sh" ]] && continue

        local script_name
        script_name=$(basename "$script_file")

        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY-RUN] Would copy: $script_file → $dst_dir/$script_name"
        else
            cp "$script_file" "$dst_dir/$script_name"
            chmod 755 "$dst_dir/$script_name"
            log_success "Deployed script: $script_name"
        fi
        ((deployed++))
    done

    log_info "Deployed $deployed scripts to $dst_dir"
}

# Validate configuration
validate_config() {
    log_info "Validating fail2ban configuration..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would validate configuration"
        return 0
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

# Restart fail2ban service
restart_service() {
    log_info "Restarting fail2ban service..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would restart fail2ban.service"
        return 0
    fi

    if systemctl restart fail2ban.service; then
        log_success "fail2ban service restarted"
    else
        log_error "Failed to restart fail2ban service"
        return 1
    fi

    sleep 2

    if systemctl is-active --quiet fail2ban.service; then
        log_success "fail2ban service is active"
    else
        log_error "fail2ban service is not active"
        return 1
    fi
}

# Show jail status
show_jail_status() {
    log_info "Checking active jails..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would show jail status"
        return 0
    fi

    fail2ban-client status
}

# ============================================
# Main
# ============================================

main() {
    # Parse arguments
    if [[ "${1:-}" == "--dry-run" ]]; then
        DRY_RUN=true
        log_info "Running in DRY-RUN mode (no changes will be made)"
    fi

    printf '\n=== fail2ban Deployment Script ===\n\n'

    check_root
    check_fail2ban_installed

    deploy_base_config || exit 1
    deploy_jail_config || exit 1
    deploy_drop_ins || exit 1
    deploy_filters
    deploy_actions
    deploy_scripts

    validate_config || exit 1

    if [[ "$DRY_RUN" == false ]]; then
        restart_service || exit 1
        show_jail_status
    fi

    printf '\n=== Deployment Complete ===\n'

    if [[ "$DRY_RUN" == false ]]; then
        printf '\nNext steps:\n'
        printf '  1. Review active jails: sudo fail2ban-client status\n'
        printf '  2. Check logs: sudo journalctl -u fail2ban -f\n'
        printf '  3. Test ban: sudo fail2ban-client set sshd banip 1.2.3.4\n'
        printf '  4. Optional: Configure GeoIP (see docs/GEOIP_FILTERING.md)\n'
        printf '  5. Optional: Configure Telegram (see docs/TELEGRAM_INTEGRATION.md)\n'
    fi

    return 0
}

main "$@"
