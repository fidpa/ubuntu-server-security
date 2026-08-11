#!/bin/bash
# deploy-profile.sh - Deploy AppArmor profile with validation
# Part of: ubuntu-server-security
#
# Usage: sudo ./deploy-profile.sh <profile-file> [--enforce]
#
# Options:
#   --enforce    Deploy directly in ENFORCE mode (default: COMPLAIN)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <profile-file> [--enforce]"
    echo "Example: $0 profiles/usr.lib.postgresql.16.bin.postgres"
    exit 1
fi

PROFILE_FILE="$1"
ENFORCE_MODE=false

if [[ "${2:-}" == "--enforce" ]]; then
    ENFORCE_MODE=true
fi

# Validate profile file exists
if [[ ! -f "$PROFILE_FILE" ]]; then
    log_error "Profile file not found: $PROFILE_FILE"
    exit 1
fi

PROFILE_NAME=$(basename "$PROFILE_FILE")
DEST_PATH="/etc/apparmor.d/$PROFILE_NAME"

log_info "Deploying AppArmor profile: $PROFILE_NAME"

# Step 1: Syntax validation
log_info "[1/4] Validating profile syntax..."
if ! apparmor_parser -p "$PROFILE_FILE" > /dev/null 2>&1; then
    log_error "Profile syntax validation failed"
    apparmor_parser -p "$PROFILE_FILE"
    exit 1
fi
log_info "Syntax OK"

# Step 2: Copy profile
log_info "[2/4] Copying profile to /etc/apparmor.d/..."
cp "$PROFILE_FILE" "$DEST_PATH"
chmod 644 "$DEST_PATH"

# Step 3: Load profile
if [[ "$ENFORCE_MODE" == true ]]; then
    log_info "[3/4] Loading profile in ENFORCE mode..."
    apparmor_parser -r "$DEST_PATH"
else
    log_info "[3/4] Loading profile in COMPLAIN mode..."
    apparmor_parser -r -C "$DEST_PATH"
fi

# Step 4: Verify
log_info "[4/4] Verifying profile..."
if aa-status | grep -q "postgresql"; then
    log_info "Profile loaded successfully"
else
    log_warn "Profile may not be loaded correctly"
fi

# Summary
echo ""
log_info "=== Deployment Complete ==="
if [[ "$ENFORCE_MODE" == true ]]; then
    log_info "Mode: ENFORCE (blocking violations)"
else
    log_info "Mode: COMPLAIN (logging only)"
    log_info ""
    log_info "Next steps:"
    log_info "1. Monitor for violations: tail -f /var/log/syslog | grep apparmor"
    log_info "2. After 24-48h without issues: sudo aa-enforce $DEST_PATH"
fi
