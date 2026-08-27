#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
#
# Basic Vaultwarden Usage Example
# ================================
# Demonstrates simple credential retrieval from Vaultwarden.
#
# Prerequisites:
# - Bitwarden CLI installed (bw)
# - Vaultwarden session initialized (BW_SESSION set)
# - Credentials stored in vault

set -uo pipefail

# Determine script directory (resolve symlinks)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Source the Vaultwarden credentials library
source "${SCRIPT_DIR}/../vaultwarden-credentials.sh"

# ============================================================================
# Example: Get Database Password
# ============================================================================

echo "Example: Retrieving database password from Vaultwarden"
echo "======================================================="
echo ""

# Check if Vaultwarden is available
if vaultwarden_available; then
    echo "✅ Vaultwarden is available"
else
    echo "⚠️  Vaultwarden not available (using fallback)"
fi
echo ""

# Get credential (with fallback to .env file)
DB_PASSWORD=$(get_credential "Database Production" "DB_PASSWORD")

if [[ -n "$DB_PASSWORD" ]]; then
    echo "✅ Got database password (length: ${#DB_PASSWORD} characters)"
else
    echo "❌ Could not retrieve database password"
    echo ""
    echo "Make sure you have either:"
    echo "  1. A Vaultwarden item named 'Database Production' with a password"
    echo "  2. A DB_PASSWORD variable in ~/.env.secrets"
    exit 1
fi

echo ""
echo "Example complete!"
