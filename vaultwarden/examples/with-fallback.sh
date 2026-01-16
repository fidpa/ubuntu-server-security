#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
#
# Migration-Friendly Example with Fallback
# =========================================
# Demonstrates the recommended pattern for migrating from .env files
# to Vaultwarden while maintaining backward compatibility.
#
# This pattern allows:
# - Scripts to work with Vaultwarden when available
# - Graceful fallback to .env files when Vaultwarden is not configured
# - Smooth migration without breaking existing deployments

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/../vaultwarden-credentials.sh"

# ============================================================================
# Example: Backup Script with Multiple Credentials
# ============================================================================

echo "Migration-Friendly Backup Script Example"
echo "========================================="
echo ""

# Try to initialize Vaultwarden (don't fail if unavailable)
# The --quiet flag suppresses status messages
if init_vaultwarden_session --quiet; then
    echo "✅ Using Vaultwarden for credentials"
else
    echo "ℹ️  Vaultwarden not available, using .env fallback"
fi
echo ""

# ============================================================================
# Get credentials (Vaultwarden-first, .env-fallback)
# ============================================================================

echo "Retrieving credentials..."

# Each get_credential call tries Vaultwarden first, then falls back to .env
SSH_PASSWORD=$(get_credential "Backup SSH" "BACKUP_SSH_PASSWORD")
ENCRYPTION_KEY=$(get_credential "Backup Encryption" "BACKUP_ENCRYPTION_KEY")
REMOTE_HOST=$(get_credential "Backup Host" "BACKUP_REMOTE_HOST")

# Validate we got the required credentials
missing=()
[[ -z "$SSH_PASSWORD" ]] && missing+=("SSH_PASSWORD")
[[ -z "$ENCRYPTION_KEY" ]] && missing+=("ENCRYPTION_KEY")
[[ -z "$REMOTE_HOST" ]] && missing+=("REMOTE_HOST")

if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Missing credentials: ${missing[*]}"
    echo ""
    echo "Please ensure these are set in either:"
    echo "  - Vaultwarden vault (recommended)"
    echo "  - ~/.env.secrets file (fallback)"
    exit 1
fi

echo "  ✅ SSH_PASSWORD: retrieved (${#SSH_PASSWORD} chars)"
echo "  ✅ ENCRYPTION_KEY: retrieved (${#ENCRYPTION_KEY} chars)"
echo "  ✅ REMOTE_HOST: $REMOTE_HOST"
echo ""

# ============================================================================
# Simulated backup operation
# ============================================================================

echo "Simulating backup operation..."
echo "  Would connect to: $REMOTE_HOST"
echo "  Would use SSH password for authentication"
echo "  Would encrypt backup with provided key"
echo ""

# In a real script, you would do something like:
# rsync -avz -e "sshpass -p '$SSH_PASSWORD' ssh" \
#     /data/ user@${REMOTE_HOST}:/backups/

echo "✅ Example complete!"
echo ""
echo "This pattern allows you to:"
echo "  1. Start with .env files (current state)"
echo "  2. Gradually migrate credentials to Vaultwarden"
echo "  3. Eventually remove .env files entirely"
