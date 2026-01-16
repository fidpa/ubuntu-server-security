#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# USB Defense System Deployment Script
#
# Purpose: One-click deployment of 3-layer USB defense system
# Features:
# - Layer 1: Kernel module blacklist (usb-storage, uas)
# - Layer 2: USB device watcher (polling-based daemon)
# - Layer 3: auditd bypass detection (periodic log analysis)
#
# Usage:
#   sudo ./deploy-usb-defense.sh
#   sudo ./deploy-usb-defense.sh --rollback
#
# Exit Codes:
#   0 - Success
#   1 - Warning
#   2 - Error
#   3 - Critical
#
# Documentation: https://github.com/fidpa/ubuntu-server-security/tree/main/usb-defense
# Version: 1.0.0
# Created: 2026-01-16

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
readonly SCRIPT_DIR

readonly VERSION="1.0.0"
readonly COMPONENT_DIR="$(dirname "$SCRIPT_DIR")"

# Inline logging
log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2; }
log_success() { echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }
log_warning() { echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $*"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run with sudo!"
        exit 3
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_tools=()
    for tool in lsusb lsmod auditd auditctl systemctl; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Install with: sudo apt install usbutils audit systemd"
        exit 3
    fi

    if ! systemctl is-active --quiet auditd; then
        log_warning "auditd service not running - Layer 3 won't work"
        log_info "Start with: sudo systemctl start auditd"
    fi

    log_success "Prerequisites OK"
}

deploy_layer1() {
    log_info "Deploying Layer 1: Kernel module blacklist..."

    if [[ ! -f "${COMPONENT_DIR}/configs/blacklist-usb-storage.conf" ]]; then
        log_error "Config file not found: ${COMPONENT_DIR}/configs/blacklist-usb-storage.conf"
        exit 2
    fi

    cp "${COMPONENT_DIR}/configs/blacklist-usb-storage.conf" /etc/modprobe.d/
    chmod 644 /etc/modprobe.d/blacklist-usb-storage.conf

    log_info "Updating initramfs (this may take 30-60 seconds)..."
    if update-initramfs -u >/dev/null 2>&1; then
        log_success "Layer 1 deployed: Kernel blacklist active"
    else
        log_warning "initramfs update failed - blacklist may not be boot-persistent"
    fi

    if lsmod | grep -q usb_storage; then
        log_warning "usb-storage module currently loaded - unloading..."
        rmmod usb_storage 2>/dev/null || log_warning "Could not unload usb-storage (devices in use?)"
    fi
}

deploy_layer2() {
    log_info "Deploying Layer 2: USB device watcher..."

    mkdir -p /var/lib/usb-defense
    chmod 755 /var/lib/usb-defense

    cp "${COMPONENT_DIR}/scripts/usb-device-watcher.sh" /usr/local/bin/
    chmod 755 /usr/local/bin/usb-device-watcher.sh

    cat > /etc/systemd/system/usb-device-watcher.service <<'EOF'
[Unit]
Description=USB Device Watcher
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=600
StartLimitBurst=3

[Service]
Type=simple
ExecStart=/usr/local/bin/usb-device-watcher.sh
Restart=on-failure
RestartSec=30
StandardOutput=journal
StandardError=journal

ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
NoNewPrivileges=yes
ReadWritePaths=/var/lib/usb-defense

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable usb-device-watcher.service
    systemctl start usb-device-watcher.service

    sleep 2
    if systemctl is-active --quiet usb-device-watcher.service; then
        log_success "Layer 2 deployed: USB device watcher active"
    else
        log_error "Layer 2 failed to start"
        exit 2
    fi
}

deploy_layer3() {
    log_info "Deploying Layer 3: auditd bypass detection..."

    if [[ ! -f "${COMPONENT_DIR}/configs/99-usb-defense.rules" ]]; then
        log_error "Config file not found: ${COMPONENT_DIR}/configs/99-usb-defense.rules"
        exit 2
    fi

    cp "${COMPONENT_DIR}/configs/99-usb-defense.rules" /etc/audit/rules.d/
    chmod 644 /etc/audit/rules.d/99-usb-defense.rules

    if systemctl is-active --quiet auditd; then
        augenrules --load >/dev/null 2>&1 || log_warning "Could not reload audit rules"
    fi

    cp "${COMPONENT_DIR}/scripts/check-usb-activity.sh" /usr/local/bin/
    chmod 755 /usr/local/bin/check-usb-activity.sh

    cat > /etc/systemd/system/check-usb-activity.service <<'EOF'
[Unit]
Description=USB Activity Monitor (auditd log analysis)
After=auditd.service
Requires=auditd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/check-usb-activity.sh
StandardOutput=journal
StandardError=journal
EOF

    cat > /etc/systemd/system/check-usb-activity.timer <<'EOF'
[Unit]
Description=USB Activity Monitor Timer
Documentation=https://github.com/fidpa/ubuntu-server-security

[Timer]
OnCalendar=*:0/10
RandomizedDelaySec=30
Persistent=true
AccuracySec=1min

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable check-usb-activity.timer
    systemctl start check-usb-activity.timer

    if systemctl is-active --quiet check-usb-activity.timer; then
        log_success "Layer 3 deployed: auditd bypass detection active"
    else
        log_error "Layer 3 failed to start"
        exit 2
    fi
}

rollback() {
    log_info "Rolling back USB Defense System..."

    systemctl stop usb-device-watcher.service 2>/dev/null || true
    systemctl disable usb-device-watcher.service 2>/dev/null || true
    rm -f /etc/systemd/system/usb-device-watcher.service

    systemctl stop check-usb-activity.timer 2>/dev/null || true
    systemctl disable check-usb-activity.timer 2>/dev/null || true
    rm -f /etc/systemd/system/check-usb-activity.service
    rm -f /etc/systemd/system/check-usb-activity.timer

    rm -f /usr/local/bin/usb-device-watcher.sh
    rm -f /usr/local/bin/check-usb-activity.sh

    rm -f /etc/modprobe.d/blacklist-usb-storage.conf
    rm -f /etc/audit/rules.d/99-usb-defense.rules

    systemctl daemon-reload

    log_info "Updating initramfs..."
    update-initramfs -u >/dev/null 2>&1 || log_warning "initramfs update failed"

    log_success "Rollback complete - reboot required to re-enable usb-storage"
}

verify_deployment() {
    log_info "Verifying deployment..."

    local errors=0

    if [[ ! -f /etc/modprobe.d/blacklist-usb-storage.conf ]]; then
        log_error "Layer 1: Blacklist file missing"
        ((errors++))
    else
        log_success "Layer 1: Blacklist file OK"
    fi

    if systemctl is-active --quiet usb-device-watcher.service; then
        log_success "Layer 2: Watcher service running"
    else
        log_error "Layer 2: Watcher service not running"
        ((errors++))
    fi

    if systemctl is-active --quiet check-usb-activity.timer; then
        log_success "Layer 3: Monitor timer active"
    else
        log_error "Layer 3: Monitor timer not active"
        ((errors++))
    fi

    local rule_count
    rule_count=$(auditctl -l 2>/dev/null | grep -c "usb_" || echo 0)
    if [[ $rule_count -ge 4 ]]; then
        log_success "Layer 3: auditd rules loaded ($rule_count rules)"
    else
        log_warning "Layer 3: Expected 7+ auditd rules, found $rule_count"
    fi

    if [[ $errors -eq 0 ]]; then
        log_success "All layers verified successfully!"
        return 0
    else
        log_error "$errors layer(s) failed verification"
        return 1
    fi
}

print_summary() {
    cat <<'EOF'

╔═══════════════════════════════════════════════════════════════╗
║          USB DEFENSE SYSTEM DEPLOYMENT COMPLETE               ║
╚═══════════════════════════════════════════════════════════════╝

3-Layer Defense Active:
  ✓ Layer 1: usb-storage kernel module blacklisted
  ✓ Layer 2: Real-time USB device watcher (2s polling)
  ✓ Layer 3: auditd bypass detection (10min checks)

Next Steps:
  1. Test with real USB device (recommended):
     - Plug in USB stick
     - Wait 2-4 seconds
     - Check email for alert
     - Verify: lsblk (should NOT show USB device)

  2. Monitor service health:
     systemctl status usb-device-watcher.service
     systemctl status check-usb-activity.timer
     journalctl -u usb-device-watcher.service -f

  3. Review audit logs (weekly):
     sudo ausearch -k usb_device_activity -i | tail -50

Configuration:
  State directory: /var/lib/usb-defense
  Alert email: root (customize via USB_DEFENSE_ALERT_EMAIL)
  Cooldown: 3600s (customize via USB_DEFENSE_COOLDOWN)

Documentation:
  https://github.com/fidpa/ubuntu-server-security/tree/main/usb-defense

EOF
}

main() {
    if [[ "${1:-}" == "--rollback" ]]; then
        check_root
        rollback
        exit 0
    fi

    log_info "USB Defense System Deployment v${VERSION}"
    log_info "Deploying 3-layer defense system..."

    check_root
    check_prerequisites

    deploy_layer1
    deploy_layer2
    deploy_layer3

    if verify_deployment; then
        print_summary
        exit 0
    else
        log_error "Deployment completed with warnings"
        exit 1
    fi
}

main "$@"
