#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# nftables Safe Deployment Script
# ═══════════════════════════════════════════════════════════════════════════
# Copyright (c) 2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# Purpose: Safely deploy nftables configuration with automatic rollback
# Usage: ./deploy-nftables.sh <config-file>
#
# Features:
# - Pre-deployment validation
# - Automatic backup
# - Confirmation prompt (30s timeout)
# - Automatic rollback on failure
# - SSH safety checks
#
# Exit Codes:
# 0 - Deployment successful
# 1 - Validation failed
# 2 - Deployment failed
# 3 - Rollback performed
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

readonly SCRIPT_NAME="$(basename "$0")"
readonly CONFIG_FILE="${1:-/etc/nftables.conf}"
readonly BACKUP_DIR="/etc/nftables/backups"
readonly BACKUP_FILE="$BACKUP_DIR/nftables.conf.backup.$(date +%Y%m%d_%H%M%S)"
readonly CONFIRMATION_TIMEOUT=30

# Colors
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════
# Functions
# ═══════════════════════════════════════════════════════════════════════════

error() {
    echo -e "${RED}❌ ERROR: $*${NC}" >&2
}

warning() {
    echo -e "${YELLOW}⚠️  WARNING: $*${NC}" >&2
}

success() {
    echo -e "${GREEN}✅ $*${NC}"
}

info() {
    echo "ℹ️  $*"
}

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [config-file]

Safely deploys nftables configuration with automatic rollback.

Options:
  config-file    Path to nftables config (default: /etc/nftables.conf)

Example:
  $SCRIPT_NAME /etc/nftables.conf
  $SCRIPT_NAME drop-ins/10-gateway.nft.template

Features:
  - Pre-deployment validation
  - Automatic backup to $BACKUP_DIR
  - SSH connectivity check
  - Automatic rollback on failure
  - systemd service restart

Exit Codes:
  0 - Deployment successful
  1 - Validation failed
  2 - Deployment failed
  3 - Rollback performed
EOF
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 2
    fi
}

create_backup() {
    info "Creating backup..."

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Backup current config if it exists
    if [[ -f /etc/nftables.conf ]]; then
        cp /etc/nftables.conf "$BACKUP_FILE"
        success "Backup created: $BACKUP_FILE"
    else
        warning "No existing config to backup"
    fi
}

validate_config() {
    info "Validating configuration..."

    # Run validator script if available
    local validator_script
    validator_script="$(dirname "$0")/validate-nftables.sh"

    if [[ -f "$validator_script" ]]; then
        if ! bash "$validator_script" "$CONFIG_FILE"; then
            error "Validation failed - aborting deployment"
            return 1
        fi
    else
        # Fallback: basic syntax check
        if ! nft -c -f "$CONFIG_FILE" 2>&1; then
            error "Syntax check failed - aborting deployment"
            return 1
        fi
        success "Syntax: Valid"
    fi
}

deploy_config() {
    info "Deploying configuration..."

    # Copy config to /etc/nftables.conf if different file
    if [[ "$CONFIG_FILE" != "/etc/nftables.conf" ]]; then
        cp "$CONFIG_FILE" /etc/nftables.conf
    fi

    # Apply configuration
    if nft -f /etc/nftables.conf; then
        success "Configuration applied"
        return 0
    else
        error "Failed to apply configuration"
        return 1
    fi
}

verify_connectivity() {
    info "Verifying connectivity..."

    # Check if SSH port is accessible (basic check)
    if ss -tlnp | grep -q ":22 "; then
        success "SSH port is listening"
    else
        warning "SSH port (22) is not listening"
    fi

    # Prompt user for confirmation
    echo
    echo "════════════════════════════════════════════════════════════════════════════"
    echo "⚠️  CONFIRMATION REQUIRED"
    echo "════════════════════════════════════════════════════════════════════════════"
    echo "The new firewall rules have been applied."
    echo "Please verify that you can still access the system (e.g., via SSH)."
    echo
    echo "If you can access the system, type 'yes' to confirm."
    echo "If you don't respond within ${CONFIRMATION_TIMEOUT}s, the changes will be ROLLED BACK."
    echo "════════════════════════════════════════════════════════════════════════════"
    echo

    # Read with timeout
    local response
    if read -t "$CONFIRMATION_TIMEOUT" -p "Confirm deployment (yes/no): " response; then
        if [[ "$response" == "yes" ]]; then
            success "Deployment confirmed by user"
            return 0
        else
            warning "Deployment NOT confirmed - rolling back"
            return 1
        fi
    else
        warning "Timeout - no confirmation received - rolling back"
        return 1
    fi
}

rollback() {
    error "Rolling back to previous configuration..."

    if [[ -f "$BACKUP_FILE" ]]; then
        cp "$BACKUP_FILE" /etc/nftables.conf
        nft -f /etc/nftables.conf
        success "Rollback complete"
        exit 3
    else
        error "No backup file found - cannot rollback"
        error "Manual intervention required!"
        exit 2
    fi
}

restart_service() {
    info "Restarting nftables service..."

    if systemctl restart nftables.service; then
        success "Service restarted"
    else
        warning "Service restart failed (check: systemctl status nftables.service)"
    fi

    if systemctl enable nftables.service 2>/dev/null; then
        success "Service enabled"
    fi
}

cleanup_old_backups() {
    info "Cleaning up old backups (keeping last 10)..."

    # Keep only last 10 backups
    local backup_count
    backup_count=$(ls -1 "$BACKUP_DIR"/nftables.conf.backup.* 2>/dev/null | wc -l)

    if [[ $backup_count -gt 10 ]]; then
        ls -1t "$BACKUP_DIR"/nftables.conf.backup.* | tail -n +11 | xargs rm -f
        success "Old backups cleaned up"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

main() {
    # Check arguments
    if [[ "$#" -gt 1 ]] || [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        usage
    fi

    # Check root
    check_root

    # Check file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Config file not found: $CONFIG_FILE"
        exit 2
    fi

    echo "════════════════════════════════════════════════════════════════════════════"
    echo "nftables Safe Deployment"
    echo "Config: $CONFIG_FILE"
    echo "════════════════════════════════════════════════════════════════════════════"
    echo

    # Pre-deployment steps
    validate_config || exit 1
    create_backup

    echo
    info "Starting deployment..."
    echo

    # Deploy
    if ! deploy_config; then
        rollback
    fi

    # Verify
    if ! verify_connectivity; then
        rollback
    fi

    # Post-deployment
    restart_service
    cleanup_old_backups

    # Success
    echo
    echo "════════════════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}✅ DEPLOYMENT SUCCESSFUL${NC}"
    echo "════════════════════════════════════════════════════════════════════════════"
    echo "Backup: $BACKUP_FILE"
    echo "Config: /etc/nftables.conf"
    echo
    echo "Check status: systemctl status nftables.service"
    echo "View rules: sudo nft list ruleset"
    echo "════════════════════════════════════════════════════════════════════════════"
}

main "$@"
