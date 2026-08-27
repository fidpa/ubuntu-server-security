#!/bin/bash
# =============================================================================
# Ubuntu Server Security - auditd Deployment Script
# =============================================================================
#
# Deploys CIS-aligned audit rules with validation and backup
#
# Usage:
#   sudo ./deploy-auditd.sh [base|aggressive|docker]
#
# Examples:
#   sudo ./deploy-auditd.sh base        # Deploy CIS Level 1 rules
#   sudo ./deploy-auditd.sh aggressive  # Deploy CIS Level 2 / STIG rules
#   sudo ./deploy-auditd.sh docker      # Add Docker-aware rules
#
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"

RULES_DIR="/etc/audit/rules.d"
BACKUP_DIR="/etc/audit/backups"

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_auditd_installed() {
    if ! command -v auditctl &> /dev/null; then
        log_error "auditd is not installed"
        log_info "Install with: sudo apt install auditd audispd-plugins"
        exit 1
    fi
}

backup_existing_rules() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    mkdir -p "$BACKUP_DIR"

    if ls "$RULES_DIR"/*.rules 1> /dev/null 2>&1; then
        log_info "Backing up existing rules to $BACKUP_DIR/rules_$timestamp/"
        mkdir -p "$BACKUP_DIR/rules_$timestamp"
        cp "$RULES_DIR"/*.rules "$BACKUP_DIR/rules_$timestamp/" 2>/dev/null || true
    fi
}

deploy_base_rules() {
    log_info "Deploying CIS Level 1 (Base) rules..."

    if [[ ! -f "$COMPONENT_DIR/audit-base.rules.template" ]]; then
        log_error "Template not found: $COMPONENT_DIR/audit-base.rules.template"
        exit 1
    fi

    cp "$COMPONENT_DIR/audit-base.rules.template" "$RULES_DIR/99-cis-base.rules"
    chmod 640 "$RULES_DIR/99-cis-base.rules"

    log_info "Base rules deployed to $RULES_DIR/99-cis-base.rules"
}

deploy_aggressive_rules() {
    log_info "Deploying CIS Level 2 / STIG (Aggressive) rules..."

    if [[ ! -f "$COMPONENT_DIR/audit-aggressive.rules.template" ]]; then
        log_error "Template not found: $COMPONENT_DIR/audit-aggressive.rules.template"
        exit 1
    fi

    # Remove base rules if present (aggressive includes them)
    rm -f "$RULES_DIR/99-cis-base.rules" 2>/dev/null

    cp "$COMPONENT_DIR/audit-aggressive.rules.template" "$RULES_DIR/99-cis-l2.rules"
    chmod 640 "$RULES_DIR/99-cis-l2.rules"

    log_warn "Aggressive rules include immutable mode (-e 2)!"
    log_warn "After loading, rule changes will require a reboot!"

    log_info "Aggressive rules deployed to $RULES_DIR/99-cis-l2.rules"
}

deploy_docker_rules() {
    log_info "Deploying Docker-aware rules..."

    if [[ ! -f "$COMPONENT_DIR/audit-docker.rules.template" ]]; then
        log_error "Template not found: $COMPONENT_DIR/audit-docker.rules.template"
        exit 1
    fi

    cp "$COMPONENT_DIR/audit-docker.rules.template" "$RULES_DIR/50-docker.rules"
    chmod 640 "$RULES_DIR/50-docker.rules"

    log_info "Docker rules deployed to $RULES_DIR/50-docker.rules"
}

generate_privileged_rules() {
    log_info "Generating privileged command rules for this system..."

    # Find SUID/SGID binaries and generate rules
    local priv_file="$RULES_DIR/30-privileged.rules"

    echo "# Privileged commands (auto-generated)" > "$priv_file"
    echo "# Generated on $(date)" >> "$priv_file"

    find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | while read -r binary; do
        echo "-a always,exit -F path=$binary -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged" >> "$priv_file"
    done

    chmod 640 "$priv_file"

    local count
    count=$(wc -l < "$priv_file")
    log_info "Generated $((count - 2)) privileged command rules"
}

load_rules() {
    log_info "Loading audit rules..."

    if ! augenrules --load 2>&1; then
        log_error "Failed to load rules"
        log_info "Check syntax with: sudo augenrules --check"
        exit 1
    fi

    log_info "Rules loaded successfully"
}

verify_deployment() {
    log_info "Verifying deployment..."

    local rule_count
    rule_count=$(auditctl -l 2>/dev/null | wc -l)

    if [[ $rule_count -eq 0 ]]; then
        log_error "No rules loaded!"
        exit 1
    fi

    log_info "Total rules loaded: $rule_count"

    # Check for lost events
    local lost
    lost=$(auditctl -s 2>/dev/null | grep -oP 'lost \K\d+' || echo "0")

    if [[ $lost -gt 0 ]]; then
        log_warn "Lost events detected: $lost"
        log_warn "Consider increasing backlog limit"
    fi

    # Check key rules are present
    local missing=0
    for key in time-change identity system-locale MAC-policy logins session perm_mod privileged; do
        if ! auditctl -l | grep -q "key=$key"; then
            log_warn "Missing rule key: $key"
            ((missing++))
        fi
    done

    if [[ $missing -eq 0 ]]; then
        log_info "All expected rule keys present"
    fi
}

show_usage() {
    echo "Usage: $0 [base|aggressive|docker]"
    echo ""
    echo "Options:"
    echo "  base        Deploy CIS Level 1 rules (recommended)"
    echo "  aggressive  Deploy CIS Level 2 / STIG rules (includes immutable mode)"
    echo "  docker      Add Docker-aware rules (use with base or aggressive)"
    echo ""
    echo "Examples:"
    echo "  sudo $0 base                    # Deploy base rules only"
    echo "  sudo $0 base && sudo $0 docker  # Deploy base + docker rules"
    echo "  sudo $0 aggressive              # Deploy aggressive rules (Level 2)"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    local mode="${1:-}"

    if [[ -z "$mode" ]]; then
        show_usage
        exit 1
    fi

    check_root
    check_auditd_installed
    backup_existing_rules

    case "$mode" in
        base)
            deploy_base_rules
            generate_privileged_rules
            ;;
        aggressive)
            deploy_aggressive_rules
            generate_privileged_rules
            ;;
        docker)
            deploy_docker_rules
            ;;
        *)
            log_error "Unknown mode: $mode"
            show_usage
            exit 1
            ;;
    esac

    load_rules
    verify_deployment

    echo ""
    log_info "Deployment complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Verify rules: sudo auditctl -l"
    echo "  2. Test logging: sudo ls /root && sudo ausearch -k actions -ts recent"
    echo "  3. Monitor: sudo ausearch -ts today | tail"
}

main "$@"
