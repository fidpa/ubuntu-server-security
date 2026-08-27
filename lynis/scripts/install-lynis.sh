#!/bin/bash
# Lynis Installation Script
# SPDX-License-Identifier: MIT
# Version: 1.0.0
#
# Purpose: Install Lynis from CISOfy official repository (recommended)
# Usage: sudo ./install-lynis.sh [--dry-run]

set -uo pipefail

# ============================================
# Configuration - DYNAMIC PATHS
# ============================================

readonly SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
readonly COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"

# ============================================
# Variables
# ============================================

DRY_RUN=false

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
}

log_warning() {
    printf '[WARNING] %s\n' "$1" >&2
}

# ============================================
# Prerequisite Checks
# ============================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS (missing /etc/os-release)"
        exit 1
    fi

    if ! grep -q "ID=ubuntu\|ID=debian" /etc/os-release; then
        log_warning "This script is optimized for Ubuntu/Debian"
        log_warning "Other distros may work but are untested"
    fi
}

# ============================================
# Installation Functions
# ============================================

install_prerequisites() {
    log_info "Installing prerequisites..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would install: apt-transport-https ca-certificates"
        return 0
    fi

    apt-get update -qq
    apt-get install -y apt-transport-https ca-certificates wget gnupg2

    log_success "Prerequisites installed"
}

add_cisofy_repo() {
    log_info "Adding CISOfy official repository..."

    local key_url="https://packages.cisofy.com/keys/cisofy-software-public.key"
    local repo_file="/etc/apt/sources.list.d/cisofy-lynis.list"
    local repo_line="deb https://packages.cisofy.com/community/lynis/deb/ stable main"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would download GPG key from: $key_url"
        log_info "[DRY-RUN] Would create: $repo_file"
        log_info "[DRY-RUN] Repository line: $repo_line"
        return 0
    fi

    # Download and add GPG key
    wget -O - "$key_url" | apt-key add - || {
        log_error "Failed to add CISOfy GPG key"
        return 1
    }

    # Add repository
    echo "$repo_line" > "$repo_file"

    log_success "CISOfy repository added"
}

install_lynis() {
    log_info "Installing Lynis..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would run: apt-get update && apt-get install lynis"
        return 0
    fi

    apt-get update -qq
    apt-get install -y lynis || {
        log_error "Failed to install Lynis"
        return 1
    }

    log_success "Lynis installed"
}

verify_installation() {
    log_info "Verifying installation..."

    if ! command -v lynis >/dev/null 2>&1; then
        log_error "Lynis binary not found after installation"
        return 1
    fi

    local lynis_version
    lynis_version=$(lynis show version 2>/dev/null | grep "Lynis version" | awk '{print $3}')

    if [[ -z "$lynis_version" ]]; then
        log_error "Cannot determine Lynis version"
        return 1
    fi

    log_success "Lynis $lynis_version installed successfully"
}

run_first_audit() {
    log_info "Running first audit (this may take 1-2 minutes)..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would run: lynis audit system --quick"
        return 0
    fi

    lynis audit system --quick --quiet || {
        log_warning "Audit completed with findings (normal)"
    }

    log_success "First audit complete"
    log_info "Report location: /var/log/lynis-report.dat"
}

# ============================================
# Main Function
# ============================================

main() {
    log_info "Starting Lynis installation..."

    check_root
    check_ubuntu

    install_prerequisites || exit 1
    add_cisofy_repo || exit 1
    install_lynis || exit 1
    verify_installation || exit 1
    run_first_audit || log_warning "Skipping first audit (run manually with 'sudo lynis audit system')"

    log_success "Installation complete!"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Review report: /var/log/lynis-report.dat"
    log_info "  2. Deploy custom profile: sudo cp $COMPONENT_DIR/lynis-custom.prf.template /etc/lynis/custom.prf"
    log_info "  3. Run audit with profile: sudo lynis audit system --profile /etc/lynis/custom.prf"
}

# ============================================
# Command Parsing
# ============================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            log_info "DRY-RUN mode enabled (no changes will be made)"
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [--dry-run]"
            exit 1
            ;;
    esac
    shift
done

main
