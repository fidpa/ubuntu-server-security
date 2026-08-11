#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# SSH Host Key Generator
#
# Generates SSH host keys with modern cryptography (Ed25519 preferred).
# Backs up existing keys before generation and sets secure permissions.
#
# Features:
# - Ed25519 key generation (modern, fast, secure)
# - Automatic backup of existing keys
# - Secure permissions (0600)
# - Optional immutable flag (chattr +i) for rootkit protection
# - Idempotent (safe to run multiple times)
#
# Usage:
#   ./generate-hostkeys.sh
#   ./generate-hostkeys.sh --key-type ed25519 --immutable
#   ./generate-hostkeys.sh --backup-dir /backup/ssh-keys
#
# Exit Codes:
#   0 - Success
#   1 - Error
#
# Documentation: https://github.com/fidpa/ubuntu-server-security/ssh-hardening/docs/SETUP.md
# Version: 1.0.0
# Created: 2026-01-04

set -uo pipefail

# ============================================
# Configuration
# ============================================

KEY_TYPE="${KEY_TYPE:-ed25519}"
KEY_FILE="/etc/ssh/ssh_host_${KEY_TYPE}_key"
BACKUP_DIR="${BACKUP_DIR:-/root/ssh-key-backups}"
IMMUTABLE="${IMMUTABLE:-false}"
FORCE="${FORCE:-false}"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# ============================================
# Functions
# ============================================

log() {
    local level="$1"
    shift
    local message="$*"

    case "$level" in
        ERROR)   echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        WARNING) echo -e "${YELLOW}[WARNING]${NC} $message" >&2 ;;
        OK)      echo -e "${GREEN}[OK]${NC} $message" ;;
        INFO)    echo "[INFO] $message" ;;
    esac
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log ERROR "This script must be run as root"
        exit 1
    fi
}

backup_existing_keys() {
    if [[ ! -f "$KEY_FILE" ]]; then
        log INFO "No existing key found at $KEY_FILE"
        return 0
    fi

    log INFO "Backing up existing keys to $BACKUP_DIR"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"

    # Backup with timestamp
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/ssh_host_${KEY_TYPE}_key.${timestamp}"

    # Remove immutable flag if set (for backup)
    if lsattr "$KEY_FILE" 2>/dev/null | grep -q '^....i'; then
        log INFO "Removing immutable flag for backup"
        sudo chattr -i "$KEY_FILE" "$KEY_FILE.pub" 2>/dev/null || true
    fi

    # Backup both private and public keys
    cp -a "$KEY_FILE" "$backup_file"
    cp -a "$KEY_FILE.pub" "$backup_file.pub"

    log OK "Backup created: $backup_file"
}

generate_key() {
    log INFO "Generating $KEY_TYPE host key..."

    # Remove old key if --force specified
    if [[ "$FORCE" == "true" ]] && [[ -f "$KEY_FILE" ]]; then
        log WARNING "Removing existing key (--force specified)"
        rm -f "$KEY_FILE" "$KEY_FILE.pub"
    fi

    # Generate key
    case "$KEY_TYPE" in
        ed25519)
            ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "$(hostname)@$(date +%Y%m%d)" || {
                log ERROR "Failed to generate Ed25519 key"
                return 1
            }
            ;;
        ecdsa)
            ssh-keygen -t ecdsa -b 521 -f "$KEY_FILE" -N "" -C "$(hostname)@$(date +%Y%m%d)" || {
                log ERROR "Failed to generate ECDSA key"
                return 1
            }
            ;;
        rsa)
            ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N "" -C "$(hostname)@$(date +%Y%m%d)" || {
                log ERROR "Failed to generate RSA key"
                return 1
            }
            ;;
        *)
            log ERROR "Unsupported key type: $KEY_TYPE (use ed25519, ecdsa, or rsa)"
            return 1
            ;;
    esac

    log OK "Key generated successfully: $KEY_FILE"
}

set_permissions() {
    log INFO "Setting secure permissions..."

    # Private key: 0600 (root only)
    chmod 600 "$KEY_FILE"
    chown root:root "$KEY_FILE"

    # Public key: 0644 (world-readable)
    chmod 644 "$KEY_FILE.pub"
    chown root:root "$KEY_FILE.pub"

    log OK "Permissions set: $KEY_FILE (0600), $KEY_FILE.pub (0644)"
}

set_immutable() {
    if [[ "$IMMUTABLE" != "true" ]]; then
        return 0
    fi

    log INFO "Setting immutable flag (rootkit protection)..."

    # Check if chattr is available
    if ! command -v chattr >/dev/null 2>&1; then
        log WARNING "chattr not available - skipping immutable flag"
        return 0
    fi

    # Set immutable flag
    sudo chattr +i "$KEY_FILE" "$KEY_FILE.pub"

    log OK "Immutable flag set on host keys"
    log WARNING "To modify keys in the future, run: sudo chattr -i $KEY_FILE $KEY_FILE.pub"
}

verify_key() {
    log INFO "Verifying generated key..."

    # Check if files exist
    if [[ ! -f "$KEY_FILE" ]] || [[ ! -f "$KEY_FILE.pub" ]]; then
        log ERROR "Key files not found after generation"
        return 1
    fi

    # Verify key fingerprint
    local fingerprint
    fingerprint=$(ssh-keygen -lf "$KEY_FILE.pub")
    log OK "Key fingerprint: $fingerprint"

    return 0
}

# ============================================
# Main
# ============================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --key-type)
                KEY_TYPE="$2"
                KEY_FILE="/etc/ssh/ssh_host_${KEY_TYPE}_key"
                shift 2
                ;;
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --immutable)
                IMMUTABLE=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --key-type TYPE       Key type (ed25519, ecdsa, rsa) [default: ed25519]"
                echo "  --backup-dir DIR      Backup directory [default: /root/ssh-key-backups]"
                echo "  --immutable           Set immutable flag (chattr +i) for rootkit protection"
                echo "  --force               Overwrite existing key without prompting"
                echo "  --help                Show this help"
                echo ""
                echo "Examples:"
                echo "  $0"
                echo "  $0 --key-type ed25519 --immutable"
                echo "  $0 --key-type rsa --backup-dir /backup"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    check_root

    log INFO "SSH Host Key Generator"
    log INFO "Key type: $KEY_TYPE"
    log INFO "Key file: $KEY_FILE"
    log INFO "Backup directory: $BACKUP_DIR"

    # Check if key already exists
    if [[ -f "$KEY_FILE" ]] && [[ "$FORCE" != "true" ]]; then
        log WARNING "Key already exists: $KEY_FILE"
        log INFO "Use --force to overwrite, or remove manually"
        exit 0
    fi

    # Backup existing keys
    backup_existing_keys

    # Generate new key
    generate_key || exit 1

    # Set permissions
    set_permissions

    # Verify key
    verify_key || exit 1

    # Set immutable flag (optional)
    set_immutable

    echo ""
    log OK "Host key generation complete"
    log INFO "Next steps:"
    log INFO "  1. Restart SSH: sudo systemctl restart ssh"
    log INFO "  2. Test SSH connection: ssh localhost"
    log INFO "  3. Update known_hosts on clients if needed"

    exit 0
}

main "$@"
