#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# Vaultwarden Credentials Library
# ================================
# Source this library in your scripts to retrieve credentials from Vaultwarden
# instead of plaintext .env files.
#
# Features:
# - Vaultwarden-first credential retrieval via Bitwarden CLI
# - Graceful fallback to .env files (migration-friendly)
# - Session management helpers
# - Configurable via environment variables
#
# Usage:
#   source /path/to/vaultwarden-credentials.sh
#   init_vaultwarden_session  # Optional: Initialize session
#   PASSWORD=$(get_credential "Item Name" "ENV_VAR_FALLBACK")
#
# Requirements:
# - Bitwarden CLI (bw) installed
# - Vaultwarden server accessible
# - Valid Vaultwarden account
#
# Environment Variables:
#   BW_SESSION          - Vaultwarden session token (set by init_vaultwarden_session)
#   BW_MASTER_PASSWORD  - Master password (optional, for auto-unlock)
#   VAULTWARDEN_EMAIL   - Login email (optional, for auto-login)
#   VAULTWARDEN_SERVER  - Server URL (optional, default: https://vault.bitwarden.com)
#   CREDENTIALS_FALLBACK_FILE - Fallback .env file (default: ~/.env.secrets)
#   VAULTWARDEN_DISABLED - Set to "true" to skip Vaultwarden entirely
#
# Version: 1.0.0
# Created: 2026-01-04

# ============================================================================
# Configuration
# ============================================================================

# Fallback file for credentials (when Vaultwarden unavailable)
CREDENTIALS_FALLBACK_FILE="${CREDENTIALS_FALLBACK_FILE:-${HOME}/.env.secrets}"

# Custom CA certificate (for self-hosted Vaultwarden with custom CA)
VAULTWARDEN_CA_CERT="${VAULTWARDEN_CA_CERT:-}"

# ============================================================================
# Internal State
# ============================================================================

# Track if Vaultwarden is available (cached for performance)
_VAULTWARDEN_CHECKED=false
_VAULTWARDEN_AVAILABLE=false

# ============================================================================
# Public Functions
# ============================================================================

# Check if Vaultwarden/Bitwarden CLI is available and configured
# Returns: 0 if available, 1 if not
vaultwarden_available() {
    # Return cached result if already checked
    if [[ "$_VAULTWARDEN_CHECKED" == "true" ]]; then
        [[ "$_VAULTWARDEN_AVAILABLE" == "true" ]] && return 0 || return 1
    fi

    _VAULTWARDEN_CHECKED=true

    # Check if disabled via environment
    if [[ "${VAULTWARDEN_DISABLED:-}" == "true" ]]; then
        _VAULTWARDEN_AVAILABLE=false
        return 1
    fi

    # Check if bw CLI is installed
    if ! command -v bw >/dev/null 2>&1; then
        _VAULTWARDEN_AVAILABLE=false
        return 1
    fi

    # Check if session is active
    if [[ -n "${BW_SESSION:-}" ]]; then
        _VAULTWARDEN_AVAILABLE=true
        return 0
    fi

    _VAULTWARDEN_AVAILABLE=false
    return 1
}

# Initialize Vaultwarden session
# This unlocks the vault and exports BW_SESSION for subsequent calls.
#
# Options:
#   --quiet    Suppress status messages
#
# Returns: 0 on success, 1 on failure
init_vaultwarden_session() {
    local quiet=false
    [[ "${1:-}" == "--quiet" ]] && quiet=true

    # Check if disabled
    if [[ "${VAULTWARDEN_DISABLED:-}" == "true" ]]; then
        [[ "$quiet" == "false" ]] && echo "[INFO] Vaultwarden disabled via VAULTWARDEN_DISABLED=true" >&2
        return 1
    fi

    # Check if bw CLI is installed
    if ! command -v bw >/dev/null 2>&1; then
        [[ "$quiet" == "false" ]] && echo "[WARN] Bitwarden CLI (bw) not installed" >&2
        return 1
    fi

    # Set custom CA certificate if configured
    if [[ -n "$VAULTWARDEN_CA_CERT" && -f "$VAULTWARDEN_CA_CERT" ]]; then
        export NODE_EXTRA_CA_CERTS="$VAULTWARDEN_CA_CERT"
    fi

    # Configure server if specified
    if [[ -n "${VAULTWARDEN_SERVER:-}" ]]; then
        bw config server "$VAULTWARDEN_SERVER" >/dev/null 2>&1
    fi

    # Check current status
    local status
    status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

    case "$status" in
        "unlocked")
            # Already unlocked, get session token
            if [[ -z "${BW_SESSION:-}" ]]; then
                [[ "$quiet" == "false" ]] && echo "[WARN] Vault unlocked but BW_SESSION not set" >&2
            fi
            _VAULTWARDEN_AVAILABLE=true
            _VAULTWARDEN_CHECKED=true
            return 0
            ;;
        "locked")
            # Need to unlock
            if [[ -z "${BW_MASTER_PASSWORD:-}" ]]; then
                [[ "$quiet" == "false" ]] && echo "[ERROR] Vault locked and BW_MASTER_PASSWORD not set" >&2
                return 1
            fi
            BW_SESSION=$(bw unlock --passwordenv BW_MASTER_PASSWORD --raw 2>/dev/null)
            if [[ -z "$BW_SESSION" ]]; then
                [[ "$quiet" == "false" ]] && echo "[ERROR] Failed to unlock vault" >&2
                return 1
            fi
            export BW_SESSION
            _VAULTWARDEN_AVAILABLE=true
            _VAULTWARDEN_CHECKED=true
            [[ "$quiet" == "false" ]] && echo "[OK] Vaultwarden session initialized" >&2
            return 0
            ;;
        "unauthenticated")
            # Need to login first
            if [[ -z "${VAULTWARDEN_EMAIL:-}" || -z "${BW_MASTER_PASSWORD:-}" ]]; then
                [[ "$quiet" == "false" ]] && echo "[ERROR] Not logged in and credentials not set" >&2
                return 1
            fi
            bw login "$VAULTWARDEN_EMAIL" --passwordenv BW_MASTER_PASSWORD --raw >/dev/null 2>&1
            BW_SESSION=$(bw unlock --passwordenv BW_MASTER_PASSWORD --raw 2>/dev/null)
            if [[ -z "$BW_SESSION" ]]; then
                [[ "$quiet" == "false" ]] && echo "[ERROR] Failed to login and unlock" >&2
                return 1
            fi
            export BW_SESSION
            _VAULTWARDEN_AVAILABLE=true
            _VAULTWARDEN_CHECKED=true
            [[ "$quiet" == "false" ]] && echo "[OK] Vaultwarden session initialized (logged in)" >&2
            return 0
            ;;
        *)
            [[ "$quiet" == "false" ]] && echo "[ERROR] Unknown vault status: $status" >&2
            return 1
            ;;
    esac
}

# Get credential from Vaultwarden with fallback to .env file
#
# Arguments:
#   $1 - Vaultwarden item name (e.g., "Database Production")
#   $2 - Environment variable name for fallback (e.g., "DB_PASSWORD")
#
# Options:
#   --required    Exit with error if credential not found anywhere
#   --no-fallback Skip .env fallback (Vaultwarden only)
#
# Returns: Credential value via stdout, or empty string if not found
#
# Example:
#   PASSWORD=$(get_credential "Database Production" "DB_PASSWORD")
#   API_KEY=$(get_credential "API Key" "API_KEY" --required)
get_credential() {
    local item_name=""
    local env_var=""
    local required=false
    local no_fallback=false
    local value=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --required)
                required=true
                shift
                ;;
            --no-fallback)
                no_fallback=true
                shift
                ;;
            *)
                if [[ -z "$item_name" ]]; then
                    item_name="$1"
                elif [[ -z "$env_var" ]]; then
                    env_var="$1"
                fi
                shift
                ;;
        esac
    done

    # Try Vaultwarden first
    if vaultwarden_available; then
        value=$(bw get password "$item_name" --raw 2>/dev/null)
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    # Fallback to .env file
    if [[ "$no_fallback" == "false" && -n "$env_var" && -f "$CREDENTIALS_FALLBACK_FILE" ]]; then
        value=$(grep "^${env_var}=" "$CREDENTIALS_FALLBACK_FILE" 2>/dev/null | head -1 | cut -d= -f2- | awk '{print $1}')
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    # Credential not found
    if [[ "$required" == "true" ]]; then
        echo "[ERROR] Required credential not found: $item_name / $env_var" >&2
        exit 1
    fi

    return 1
}

# Get username from Vaultwarden item
#
# Arguments:
#   $1 - Vaultwarden item name
#
# Returns: Username via stdout
get_username() {
    local item_name="$1"

    if ! vaultwarden_available; then
        return 1
    fi

    bw get username "$item_name" --raw 2>/dev/null
}

# Get custom field from Vaultwarden item
#
# Arguments:
#   $1 - Vaultwarden item name
#   $2 - Field name
#
# Returns: Field value via stdout
get_field() {
    local item_name="$1"
    local field_name="$2"

    if ! vaultwarden_available; then
        return 1
    fi

    bw get item "$item_name" 2>/dev/null | \
        jq -r ".fields[]? | select(.name==\"$field_name\") | .value" 2>/dev/null
}

# Sync Vaultwarden vault (fetch latest from server)
#
# Returns: 0 on success, 1 on failure
sync_vault() {
    if ! vaultwarden_available; then
        return 1
    fi

    bw sync >/dev/null 2>&1
}

# Lock Vaultwarden vault (security: clear session)
#
# Returns: 0 on success
lock_vault() {
    if command -v bw >/dev/null 2>&1; then
        bw lock >/dev/null 2>&1
    fi
    unset BW_SESSION
    _VAULTWARDEN_AVAILABLE=false
    _VAULTWARDEN_CHECKED=false
    return 0
}

# ============================================================================
# Convenience Aliases
# ============================================================================

# Alias for backward compatibility
get_secret() {
    get_credential "$@"
}

# ============================================================================
# Self-Test (when executed directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Vaultwarden Credentials Library - Self Test"
    echo "============================================"
    echo ""
    echo "Checking Bitwarden CLI..."
    if command -v bw >/dev/null 2>&1; then
        echo "  ✅ bw CLI installed: $(bw --version 2>/dev/null || echo 'unknown version')"
    else
        echo "  ❌ bw CLI not installed"
        echo ""
        echo "Install with: npm install -g @bitwarden/cli"
        exit 1
    fi
    echo ""
    echo "Checking vault status..."
    local status
    status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    echo "  Status: $status"
    echo ""
    echo "Environment variables:"
    echo "  BW_SESSION: ${BW_SESSION:+[SET]}${BW_SESSION:-[NOT SET]}"
    echo "  BW_MASTER_PASSWORD: ${BW_MASTER_PASSWORD:+[SET]}${BW_MASTER_PASSWORD:-[NOT SET]}"
    echo "  VAULTWARDEN_SERVER: ${VAULTWARDEN_SERVER:-[NOT SET]}"
    echo "  CREDENTIALS_FALLBACK_FILE: $CREDENTIALS_FALLBACK_FILE"
    echo ""
    echo "To use this library, source it in your script:"
    echo "  source /path/to/vaultwarden-credentials.sh"
    echo "  PASSWORD=\$(get_credential \"Item Name\" \"ENV_VAR_FALLBACK\")"
fi
