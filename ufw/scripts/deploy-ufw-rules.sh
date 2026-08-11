#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# UFW Rules Deployment Script
# ═══════════════════════════════════════════════════════════════════════════
# Copyright (c) 2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# Purpose: Safe deployment of UFW rules with backup and rollback
# Usage: ./deploy-ufw-rules.sh [OPTIONS] <rules-file>
#
# Exit Codes:
#   0 - Deployment successful
#   1 - Validation errors
#   2 - Deployment failed
#   3 - User aborted
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════

readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"
readonly BACKUP_DIR="/var/lib/ufw/backup"
readonly LOG_FILE="/var/log/ufw-deploy.log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Options
DRY_RUN=false
FORCE=false
VERBOSE=false

# ═══════════════════════════════════════════════════════════════════════════
# Functions
# ═══════════════════════════════════════════════════════════════════════════

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <rules-file>

Deploy UFW rules from a drop-in file with backup and validation.

Options:
  -n, --dry-run    Show what would be done without making changes
  -f, --force      Skip confirmation prompts
  -v, --verbose    Show detailed output
  -h, --help       Show this help message
  --version        Show version
  --rollback       Restore from latest backup

Arguments:
  rules-file       Path to rules file (drop-in format)

Examples:
  $SCRIPT_NAME drop-ins/10-webserver.rules
  $SCRIPT_NAME --dry-run drop-ins/30-monitoring.rules
  $SCRIPT_NAME --rollback

Exit Codes:
  0  Deployment successful
  1  Validation errors
  2  Deployment failed
  3  User aborted
EOF
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true

    case "$level" in
        INFO)  [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[INFO]${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
        OK)    echo -e "${GREEN}[OK]${NC} $message" ;;
    esac
}

info() { log INFO "$@"; }
warn() { log WARN "$@"; }
error() { log ERROR "$@"; }
success() { log OK "$@"; }

# ═══════════════════════════════════════════════════════════════════════════
# Backup Functions
# ═══════════════════════════════════════════════════════════════════════════

create_backup() {
    local backup_name
    backup_name="ufw-backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"

    info "Creating backup: $backup_path"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] Would create backup at $backup_path"
        return 0
    fi

    sudo mkdir -p "$backup_path"

    # Backup UFW configuration
    sudo cp /etc/ufw/user.rules "$backup_path/" 2>/dev/null || true
    sudo cp /etc/ufw/user6.rules "$backup_path/" 2>/dev/null || true
    sudo cp /etc/default/ufw "$backup_path/" 2>/dev/null || true

    # Save current status
    sudo ufw status verbose > "$backup_path/status.txt" 2>/dev/null || true
    sudo ufw status numbered > "$backup_path/numbered.txt" 2>/dev/null || true

    # Create metadata
    cat > "$backup_path/metadata.txt" <<EOF
Backup created: $(date -Iseconds)
Hostname: $(hostname)
UFW Version: $(dpkg -l ufw | tail -1 | awk '{print $3}')
User: ${SUDO_USER:-$USER}
EOF

    echo "$backup_path"
}

rollback_backup() {
    local latest_backup
    latest_backup=$(ls -td "$BACKUP_DIR"/ufw-backup-* 2>/dev/null | head -1)

    if [[ -z "$latest_backup" ]]; then
        error "No backup found in $BACKUP_DIR"
        exit 2
    fi

    echo "Latest backup: $latest_backup"
    echo ""
    cat "$latest_backup/metadata.txt" 2>/dev/null || true
    echo ""

    if [[ "$FORCE" != "true" ]]; then
        read -rp "Restore this backup? [y/N] " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Aborted."
            exit 3
        fi
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] Would restore from $latest_backup"
        return 0
    fi

    info "Restoring from backup..."

    sudo cp "$latest_backup/user.rules" /etc/ufw/ 2>/dev/null || true
    sudo cp "$latest_backup/user6.rules" /etc/ufw/ 2>/dev/null || true
    sudo cp "$latest_backup/ufw" /etc/default/ufw 2>/dev/null || true

    sudo ufw reload

    success "Backup restored successfully"
    sudo ufw status verbose
}

# ═══════════════════════════════════════════════════════════════════════════
# Validation Functions
# ═══════════════════════════════════════════════════════════════════════════

validate_rules_file() {
    local rules_file="$1"
    local errors=0

    info "Validating rules file: $rules_file"

    # Check file exists
    if [[ ! -f "$rules_file" ]]; then
        error "File not found: $rules_file"
        return 1
    fi

    # Check file is readable
    if [[ ! -r "$rules_file" ]]; then
        error "File not readable: $rules_file"
        return 1
    fi

    # Parse and validate each line
    local line_num=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))

        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Check for valid ufw command structure
        if ! echo "$line" | grep -qE "^sudo ufw (allow|deny|limit|reject|delete|insert)"; then
            warn "Line $line_num: Potentially invalid command: $line"
            ((errors++))
        fi

        # Check for dangerous patterns
        if echo "$line" | grep -qE "ufw (disable|reset)"; then
            error "Line $line_num: Dangerous command detected: $line"
            ((errors++))
        fi

    done < "$rules_file"

    if [[ $errors -gt 0 ]]; then
        error "Validation found $errors issue(s)"
        return 1
    fi

    success "Validation passed"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════
# Deployment Functions
# ═══════════════════════════════════════════════════════════════════════════

deploy_rules() {
    local rules_file="$1"
    local applied=0
    local failed=0

    info "Deploying rules from: $rules_file"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Remove 'sudo' prefix if present (we add it ourselves)
        line="${line#sudo }"

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY-RUN] Would execute: sudo $line"
            ((applied++))
            continue
        fi

        [[ "$VERBOSE" == "true" ]] && echo "  Executing: sudo $line"

        if sudo $line 2>&1; then
            ((applied++))
        else
            warn "Failed: $line"
            ((failed++))
        fi

    done < "$rules_file"

    echo ""
    info "Applied: $applied rules, Failed: $failed rules"

    if [[ $failed -gt 0 ]]; then
        return 1
    fi
    return 0
}

show_changes() {
    echo ""
    info "Current UFW status after deployment:"
    echo ""
    sudo ufw status numbered
}

# ═══════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════

main() {
    local rules_file=""
    local do_rollback=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --rollback)
                do_rollback=true
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
            -*)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                rules_file="$1"
                shift
                ;;
        esac
    done

    # Check root/sudo
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        error "This script requires sudo privileges"
        exit 2
    fi

    echo "═══════════════════════════════════════════════════════════════"
    echo " UFW Rules Deployment v$VERSION"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Handle rollback
    if [[ "$do_rollback" == "true" ]]; then
        rollback_backup
        exit 0
    fi

    # Validate arguments
    if [[ -z "$rules_file" ]]; then
        error "No rules file specified"
        usage
        exit 1
    fi

    # Validate rules file
    if ! validate_rules_file "$rules_file"; then
        exit 1
    fi

    # Confirmation
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        echo ""
        echo "Rules to be deployed from: $rules_file"
        echo ""
        grep -v '^#' "$rules_file" | grep -v '^$' | head -10
        echo "..."
        echo ""
        read -rp "Continue with deployment? [y/N] " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Aborted."
            exit 3
        fi
    fi

    # Create backup
    local backup_path
    backup_path=$(create_backup)

    # Deploy rules
    if deploy_rules "$rules_file"; then
        success "Deployment completed successfully"
        [[ "$DRY_RUN" != "true" ]] && show_changes
        exit 0
    else
        error "Deployment had failures"
        echo ""
        echo "To rollback: $SCRIPT_NAME --rollback"
        exit 2
    fi
}

main "$@"
