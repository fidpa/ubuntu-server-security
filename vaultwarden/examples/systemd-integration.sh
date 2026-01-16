#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
#
# systemd Service Integration Example
# ====================================
# Demonstrates how to use Vaultwarden credentials in a systemd service.
#
# For systemd services, the session should be initialized before the
# service starts. This can be done via:
#   1. EnvironmentFile pointing to a session token file
#   2. ExecStartPre that initializes the session
#   3. A separate session-manager service
#
# This example assumes BW_SESSION is already set in the environment.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/../vaultwarden-credentials.sh"

# ============================================================================
# Service Configuration
# ============================================================================

SERVICE_NAME="example-monitor"
LOG_PREFIX="[$SERVICE_NAME]"

log_info() { echo "$LOG_PREFIX [INFO] $*"; }
log_error() { echo "$LOG_PREFIX [ERROR] $*" >&2; }
log_ok() { echo "$LOG_PREFIX [OK] $*"; }

# ============================================================================
# Main Service Logic
# ============================================================================

main() {
    log_info "Starting $SERVICE_NAME"

    # For systemd services, we expect the session to already be initialized
    # (via EnvironmentFile or ExecStartPre)
    if ! vaultwarden_available; then
        log_error "Vaultwarden session not available"
        log_error "Ensure BW_SESSION is set via EnvironmentFile"
        return 1
    fi

    log_ok "Vaultwarden session active"

    # Get required credentials
    local api_key
    local db_password

    api_key=$(get_credential "Monitoring API Key" "" --no-fallback)
    if [[ -z "$api_key" ]]; then
        log_error "Could not retrieve API key from Vaultwarden"
        return 1
    fi
    log_ok "Retrieved API key (${#api_key} chars)"

    db_password=$(get_credential "Monitoring Database" "" --no-fallback)
    if [[ -z "$db_password" ]]; then
        log_error "Could not retrieve database password from Vaultwarden"
        return 1
    fi
    log_ok "Retrieved database password (${#db_password} chars)"

    # Simulate service work
    log_info "Service initialized successfully"
    log_info "Would connect to monitoring API..."
    log_info "Would connect to database..."

    # In a real service, you would do your actual work here
    # For this example, we just exit successfully
    log_ok "Service completed"
    return 0
}

# ============================================================================
# Run
# ============================================================================

main "$@"
exit $?

# ============================================================================
# Example systemd unit file (save as /etc/systemd/system/example-monitor.service)
# ============================================================================
: <<'SYSTEMD_UNIT'
[Unit]
Description=Example Monitoring Service with Vaultwarden
After=network.target

[Service]
Type=oneshot
User=monitoring
Group=monitoring

# Option 1: Load session from environment file
# (Create this file with: echo "BW_SESSION=xxx" > /run/vaultwarden/session.env)
EnvironmentFile=/run/vaultwarden/session.env

# Option 2: Initialize session before starting (requires master password)
# EnvironmentFile=/etc/vaultwarden/master.env
# ExecStartPre=/usr/local/bin/init-vaultwarden-session.sh

ExecStart=/opt/example-monitor/run.sh

# Security hardening
PrivateTmp=yes
NoNewPrivileges=yes
ProtectSystem=strict
ReadOnlyPaths=/

[Install]
WantedBy=multi-user.target
SYSTEMD_UNIT
