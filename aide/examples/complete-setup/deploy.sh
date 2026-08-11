#!/bin/bash
# Copyright (c) 2025-2026 Marc Allgeier (fidpa)
# SPDX-License-Identifier: MIT
# https://github.com/fidpa/ubuntu-server-security
#
# Complete AIDE Deployment Script
#
# Interactive deployment of AIDE with all components.
#
# Usage:
#   sudo ./deploy.sh
#
# Exit Codes:
#   0 - Success
#   1 - Error
#
# Version: 1.0.0
# Created: 2026-01-04

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Configuration
NUM_WORKERS=4
ENABLE_DOCKER=false
ENABLE_POSTGRESQL=false
ENABLE_NEXTCLOUD=false
ENABLE_SYSTEMD=true
ENABLE_METRICS=false
SCHEDULE="04:00"

log() {
    echo -e "${GREEN}✓${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

die() {
    error "$@"
    exit 1
}

check_requirements() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root"
    fi

    # Check if AIDE is installed
    if ! command -v aide >/dev/null 2>&1; then
        die "AIDE is not installed. Run: sudo apt install aide aide-common"
    fi

    # Check AIDE version
    local version
    version=$(aide --version 2>&1 | head -n1 | awk '{print $3}')
    log "AIDE version: $version"
}

detect_services() {
    echo ""
    echo "Detecting services..."

    # Detect Docker
    if command -v docker >/dev/null 2>&1; then
        warn "Docker detected"
        read -r -p "Enable Docker excludes? (y/n) " response
        [[ "$response" =~ ^[Yy]$ ]] && ENABLE_DOCKER=true
    fi

    # Detect PostgreSQL
    if command -v psql >/dev/null 2>&1 || [[ -d /var/lib/postgresql ]]; then
        warn "PostgreSQL detected"
        read -r -p "Enable PostgreSQL excludes? (y/n) " response
        [[ "$response" =~ ^[Yy]$ ]] && ENABLE_POSTGRESQL=true
    fi

    # Detect Nextcloud
    if [[ -d /var/www/nextcloud ]] || [[ -d /var/www/html/nextcloud ]]; then
        warn "Nextcloud detected"
        read -r -p "Enable Nextcloud excludes? (y/n) " response
        [[ "$response" =~ ^[Yy]$ ]] && ENABLE_NEXTCLOUD=true
    fi

    # systemd is always recommended
    ENABLE_SYSTEMD=true
}

configure_workers() {
    local cores
    cores=$(nproc)

    echo ""
    echo "CPU cores detected: $cores"
    echo "Recommended workers: $((cores / 2))"
    read -r -p "How many workers to use? (default: 4) " response
    NUM_WORKERS="${response:-4}"

    log "Using $NUM_WORKERS workers"
}

configure_metrics() {
    echo ""
    read -r -p "Enable Prometheus metrics export? (y/n) " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        ENABLE_METRICS=true
        log "Metrics export enabled"
    fi
}

deploy_configuration() {
    log "Deploying configuration..."

    # Backup existing config
    if [[ -f /etc/aide/aide.conf ]]; then
        cp /etc/aide/aide.conf "/etc/aide/aide.conf.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    # Copy main config
    cp "$REPO_ROOT/aide/aide.conf.template" /etc/aide/aide.conf
    cp "$REPO_ROOT/aide/aide.default.template" /etc/default/aide

    # Replace placeholders
    sed -i "s/{{HOSTNAME}}/$(hostname)/g" /etc/aide/aide.conf
    sed -i "s/{{NUM_WORKERS}}/$NUM_WORKERS/g" /etc/aide/aide.conf
    sed -i "s|{{DROPIN_DIR}}|/etc/aide/aide.conf.d|g" /etc/aide/aide.conf

    log "Configuration deployed"
}

deploy_dropins() {
    log "Deploying drop-in configs..."

    mkdir -p /etc/aide/aide.conf.d

    # Deploy selected drop-ins
    [[ "$ENABLE_DOCKER" == "true" ]] && cp "$REPO_ROOT/aide/drop-ins/10-docker-excludes.conf" /etc/aide/aide.conf.d/
    [[ "$ENABLE_POSTGRESQL" == "true" ]] && cp "$REPO_ROOT/aide/drop-ins/20-postgresql-excludes.conf" /etc/aide/aide.conf.d/
    [[ "$ENABLE_NEXTCLOUD" == "true" ]] && cp "$REPO_ROOT/aide/drop-ins/30-nextcloud-excludes.conf" /etc/aide/aide.conf.d/
    [[ "$ENABLE_SYSTEMD" == "true" ]] && cp "$REPO_ROOT/aide/drop-ins/40-systemd-excludes.conf" /etc/aide/aide.conf.d/

    log "Drop-ins deployed"
}

deploy_scripts() {
    log "Deploying scripts..."

    cp "$REPO_ROOT/aide/scripts/update-aide-db.sh" /usr/local/bin/
    cp "$REPO_ROOT/aide/scripts/backup-aide-db.sh" /usr/local/bin/
    cp "$REPO_ROOT/aide/scripts/aide-metrics-exporter.sh" /usr/local/bin/

    chmod 755 /usr/local/bin/update-aide-db.sh
    chmod 755 /usr/local/bin/backup-aide-db.sh
    chmod 755 /usr/local/bin/aide-metrics-exporter.sh

    # Create directories
    mkdir -p /var/log/aide
    mkdir -p /var/backups/aide

    chmod 750 /var/log/aide
    chmod 750 /var/backups/aide

    log "Scripts deployed"
}

deploy_systemd() {
    log "Deploying systemd units..."

    cp "$REPO_ROOT/aide/systemd/aide-update.service.template" /etc/systemd/system/aide-update.service
    cp "$REPO_ROOT/aide/systemd/aide-update.timer.template" /etc/systemd/system/aide-update.timer

    # Replace placeholders
    sed -i 's|{{SCRIPT_PATH}}|/usr/local/bin|g' /etc/systemd/system/aide-update.service
    sed -i 's|{{METRICS_SCRIPT}}|/usr/local/bin|g' /etc/systemd/system/aide-update.service
    sed -i 's|{{LOG_DIR}}|/var/log/aide|g' /etc/systemd/system/aide-update.service
    sed -i 's|{{TIMEOUT}}|90|g' /etc/systemd/system/aide-update.service
    sed -i 's|{{TIMEOUT_SECONDS}}|5400|g' /etc/systemd/system/aide-update.service

    # Update schedule
    sed -i "s|OnCalendar=daily|OnCalendar=*-*-* $SCHEDULE:00|g" /etc/systemd/system/aide-update.timer

    systemctl daemon-reload
    systemctl enable aide-update.timer
    systemctl start aide-update.timer

    log "systemd units deployed and enabled"
}

initialize_database() {
    log "Initializing AIDE database (this may take several minutes)..."

    if ! aideinit; then
        die "Failed to initialize AIDE database"
    fi

    if [[ ! -f /var/lib/aide/aide.db.new ]]; then
        die "AIDE database not created"
    fi

    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

    # Fix permissions for non-root monitoring
    groupadd --system _aide 2>/dev/null || true
    chown root:_aide /var/lib/aide/aide.db
    chmod 640 /var/lib/aide/aide.db
    chown root:_aide /var/lib/aide
    chmod 750 /var/lib/aide

    local entry_count
    entry_count=$(aide --check 2>&1 | grep "^Total number of entries:" | awk '{print $5}')
    log "Database initialized ($entry_count entries)"
}

setup_metrics() {
    if [[ "$ENABLE_METRICS" == "true" ]]; then
        log "Setting up Prometheus metrics..."

        mkdir -p /var/lib/node_exporter/textfile_collector
        chmod 755 /var/lib/node_exporter/textfile_collector

        /usr/local/bin/aide-metrics-exporter.sh

        log "Metrics exported to /var/lib/node_exporter/textfile_collector/aide.prom"
    fi
}

print_summary() {
    echo ""
    echo "================================"
    echo "AIDE Deployment Complete"
    echo "================================"
    echo ""
    log "Configuration: /etc/aide/aide.conf"
    log "Scripts: /usr/local/bin/update-aide-db.sh"
    log "Timer: aide-update.timer"
    log "Database: /var/lib/aide/aide.db"
    echo ""
    echo "Next steps:"
    echo "  1. Verify: sudo aide --check"
    echo "  2. Timer status: sudo systemctl status aide-update.timer"
    echo "  3. Next run: sudo systemctl list-timers aide-update.timer"
    echo ""
    echo "Documentation: https://github.com/fidpa/ubuntu-server-security/docs/"
    echo ""
}

main() {
    echo "AIDE Complete Deployment Script"
    echo "==============================="
    echo ""

    check_requirements
    detect_services
    configure_workers
    configure_metrics

    echo ""
    read -r -p "Proceed with deployment? (y/n) " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi

    deploy_configuration
    deploy_dropins
    deploy_scripts
    deploy_systemd
    initialize_database
    setup_metrics

    print_summary
}

main "$@"
