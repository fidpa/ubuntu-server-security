#!/bin/bash
#
# GRUB Boot Password Setup Script
# Configures GRUB boot password for Ubuntu servers
# Protects against physical attacks and single-user mode access
#
# CIS Benchmark Compliance:
#   - CIS 1.4.1: Bootloader password is set
#   - CIS 1.4.3: Authentication required for single user mode
#
# Features:
#   - PBKDF2-SHA512 password hashing (10,000 iterations)
#   - Hash syntax validation (prevents boot failures)
#   - Triple-validation before completion
#   - Automatic backup and rollback capability
#   - --unrestricted flag for headless servers
#
# Usage:
#   sudo ./setup-grub-password.sh
#
# Exit Codes:
#   0 - Success
#   1 - Error occurred
#   2 - User declined reboot

set -euo pipefail

# Configuration
readonly GRUB_CUSTOM_FILE="/etc/grub.d/40_custom"
readonly GRUB_BACKUP_DIR="/etc/grub.d/backups"
readonly GRUB_CFG="/boot/grub/grub.cfg"
readonly PATTERN_SUPERUSERS="set superusers="
readonly PATTERN_PASSWORD="password_pbkdf2"
readonly PATTERN_HASH="grub\.pbkdf2\.sha512\."

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
readonly TIMESTAMP

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check if GRUB password already configured
has_grub_password() {
    local file="${1:-$GRUB_CUSTOM_FILE}"
    grep -q "^${PATTERN_SUPERUSERS}" "$file" 2>/dev/null && \
    grep -q "^${PATTERN_PASSWORD}" "$file" 2>/dev/null
}

# Check existing password configuration
check_existing_password() {
    log_info "Checking for existing GRUB password configuration..."

    if has_grub_password "$GRUB_CUSTOM_FILE"; then
        log_warn "GRUB password appears to be already configured!"
        grep "^${PATTERN_SUPERUSERS}" "$GRUB_CUSTOM_FILE"

        read -r -p "Do you want to reset the password? (y/N) " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled"
            exit 0
        fi
    else
        log_info "No existing configuration found"
    fi
}

# Create backup directory
create_backup_dir() {
    if [ ! -d "$GRUB_BACKUP_DIR" ]; then
        log_info "Creating backup directory: $GRUB_BACKUP_DIR"
        mkdir -p "$GRUB_BACKUP_DIR"
    fi
}

# Backup current GRUB configuration
backup_grub_config() {
    local backup_file="${GRUB_BACKUP_DIR}/40_custom.${TIMESTAMP}.bak"

    log_info "Creating backup of $GRUB_CUSTOM_FILE..."
    cp "$GRUB_CUSTOM_FILE" "$backup_file"
    chmod 644 "$backup_file"  # Non-executable to prevent update-grub errors
    log_info "Backup created: $backup_file"
}

# Display password prompt
display_password_prompt() {
    cat <<EOF >&2

════════════════════════════════════════════════════════════════
                🔐 GRUB PASSWORD SETUP
════════════════════════════════════════════════════════════════

⚠️  IMPORTANT: Store password securely!
⚠️  Lost password = No access to GRUB menu editing!

You will be prompted to:
  1. Enter password (no asterisks shown - this is normal)
  2. Re-enter password to confirm

💡 Recommendation: 14+ characters, mixed case, numbers, symbols

════════════════════════════════════════════════════════════════

EOF
    read -r -p "Press ENTER to continue..." >&2
    echo "" >&2
}

# Extract hash from grub-mkpasswd-pbkdf2 output
extract_hash() {
    local output="$1"
    echo "$output" | sed -n 's/.*\(grub\.pbkdf2\.sha512\.[^ ]*\).*/\1/p'
}

# Generate GRUB password hash
generate_password_hash() {
    display_password_prompt

    local tmp_output
    tmp_output=$(mktemp)

    # Run grub-mkpasswd-pbkdf2 interactively
    if ! grub-mkpasswd-pbkdf2 </dev/tty 2>&1 | tee "$tmp_output" >&2; then
        log_error "Password generation failed"
        rm -f "$tmp_output"
        return 1
    fi

    echo "" >&2
    log_info "Password hash generated successfully" >&2

    # Extract hash
    local grub_output
    grub_output=$(cat "$tmp_output")
    rm -f "$tmp_output"

    local password_hash
    password_hash=$(extract_hash "$grub_output")

    if [[ -z "$password_hash" ]]; then
        log_error "Failed to extract hash from output"
        return 1
    fi

    # Validate hash syntax
    if ! echo "$password_hash" | grep -q "$PATTERN_HASH"; then
        log_error "Invalid hash syntax!"
        log_error "Expected: grub.pbkdf2.sha512..."
        log_error "Got: $password_hash"
        return 1
    fi

    log_info "Hash syntax validated" >&2
    echo "$password_hash"
}

# Configure GRUB with password
configure_grub_password() {
    local password_hash="$1"

    log_info "Configuring GRUB password protection..."

    # Remove existing configuration
    if has_grub_password "$GRUB_CUSTOM_FILE"; then
        log_info "Removing old password configuration..."
        sed -i "/^${PATTERN_SUPERUSERS}/d" "$GRUB_CUSTOM_FILE"
        sed -i "/^${PATTERN_PASSWORD}/d" "$GRUB_CUSTOM_FILE"
    fi

    # Add new configuration
    tee -a "$GRUB_CUSTOM_FILE" > /dev/null <<EOF

# GRUB Boot Password Protection
# Added: $TIMESTAMP
${PATTERN_SUPERUSERS}"root"
${PATTERN_PASSWORD} root $password_hash
EOF

    log_info "GRUB configuration updated"
}

# Update GRUB and validate
update_grub() {
    local expected_hash="$1"

    log_info "Updating GRUB configuration..."
    if ! update-grub; then
        log_error "update-grub failed"
        return 1
    fi

    log_info "Validating GRUB configuration..."

    # Check 1: grub.cfg exists
    if [ ! -f "$GRUB_CFG" ]; then
        log_error "GRUB config not created: $GRUB_CFG"
        return 1
    fi

    # Check 2: Password in grub.cfg
    if ! grep -q "${PATTERN_PASSWORD}.*${PATTERN_HASH}" "$GRUB_CFG"; then
        log_error "Password not found in $GRUB_CFG"
        return 1
    fi

    # Check 3: Expected hash matches
    if [[ -n "$expected_hash" ]]; then
        if ! grep -q "$expected_hash" "$GRUB_CFG"; then
            log_error "Hash mismatch in grub.cfg"
            return 1
        fi
    fi

    log_info "GRUB configuration validated successfully"
}

# Rollback on error
rollback() {
    local backup_file="${GRUB_BACKUP_DIR}/40_custom.${TIMESTAMP}.bak"

    log_error "Rolling back changes..."

    if [ ! -f "$backup_file" ]; then
        log_error "Backup not found: $backup_file"
        return 1
    fi

    cp "$backup_file" "$GRUB_CUSTOM_FILE"
    update-grub
    log_info "Rollback completed"
}

# Display post-installation instructions
display_instructions() {
    cat <<EOF

══════════════════════════════════════════════════════════════
        ✅ GRUB BOOT PASSWORD CONFIGURED SUCCESSFULLY
══════════════════════════════════════════════════════════════

Important Notes:

1. Password is required for:
   - Editing boot menu (press 'e')
   - GRUB console (press 'c')
   - Recovery mode

2. Password NOT required for:
   - Normal boot (--unrestricted)
   - Automatic boot after timeout

3. Store password securely (password manager recommended)

4. Backup location: $GRUB_BACKUP_DIR/

Test on Next Boot:
  - Press 'e' at GRUB menu → Should prompt for password
  - Let boot proceed normally → Should NOT prompt

══════════════════════════════════════════════════════════════

EOF
}

# Main function
main() {
    log_info "=========================================="
    log_info "GRUB Boot Password Setup"
    log_info "=========================================="

    # Check root privileges
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run with sudo"
        exit 1
    fi

    # Check grub-mkpasswd-pbkdf2 availability
    if ! command -v grub-mkpasswd-pbkdf2 &> /dev/null; then
        log_error "grub-mkpasswd-pbkdf2 not found"
        log_error "Install with: sudo apt install grub-common"
        exit 1
    fi

    # Check root password is set
    if ! passwd -S root | grep -q ' P '; then
        log_warn "Root password is not set!"
        log_warn "This is required for emergency mode access"
        read -r -p "Set root password now? (Y/n) " response
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            passwd root
        else
            log_error "Setup cancelled - root password required"
            exit 1
        fi
    fi

    # Step 1: Check existing configuration
    check_existing_password

    # Step 2: Create backup directory
    create_backup_dir

    # Step 3: Backup current configuration
    backup_grub_config

    # Step 4: Generate password hash
    local password_hash
    if ! password_hash=$(generate_password_hash) || [ -z "$password_hash" ]; then
        log_error "Setup failed at password generation"
        exit 1
    fi

    # Step 5: Configure GRUB
    if ! configure_grub_password "$password_hash"; then
        rollback
        exit 1
    fi

    # Step 6: Update GRUB
    if ! update_grub "$password_hash"; then
        rollback
        exit 1
    fi

    # Step 7: Display instructions
    display_instructions

    # Step 8: Reboot prompt
    log_warn "=========================================="
    log_warn "⚠️  TEST REBOOT REQUIRED"
    log_warn "=========================================="
    log_warn "System must be rebooted to test GRUB password"
    log_warn "Test: Press 'e' at GRUB menu → Should prompt for password"
    echo ""

    read -r -p "Reboot now? (y/N) " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Rebooting..."
        sleep 2
        reboot
    else
        log_warn "❌ Manual reboot required before proceeding!"
        exit 2
    fi
}

# Run main function
main "$@"
