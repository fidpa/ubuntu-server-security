#!/bin/bash
# Lynis Audit Wrapper Script
# SPDX-License-Identifier: MIT
# Version: 1.0.0
#
# Purpose: Run Lynis audit with report parsing and metrics
# Usage: sudo ./lynis-audit.sh [--quick] [--profile /path/to/profile.prf]

set -uo pipefail

# ============================================
# Configuration
# ============================================

readonly REPORT_FILE="/var/log/lynis-report.dat"
readonly LOG_FILE="/var/log/lynis.log"

# ============================================
# Variables
# ============================================

QUICK_MODE=false
CUSTOM_PROFILE=""

# ============================================
# Logging Functions
# ============================================

log_info() {
    printf '[INFO] %s\n' "$1"
}

log_success() {
    printf '[SUCCESS] %s\n' "$1"
}

log_error() {
    printf '[ERROR] %s\n' "$1" >&2
}

log_warning() {
    printf '[WARNING] %s\n' "$1" >&2
}

# ============================================
# Prerequisite Checks
# ============================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_lynis_installed() {
    if ! command -v lynis >/dev/null 2>&1; then
        log_error "Lynis is not installed"
        log_error "Install with: sudo apt install lynis"
        exit 1
    fi
}

# ============================================
# Audit Functions
# ============================================

run_audit() {
    log_info "Running Lynis audit..."

    local lynis_cmd="lynis audit system"

    if [[ "$QUICK_MODE" == true ]]; then
        lynis_cmd+=" --quick"
        log_info "Quick mode enabled (skips slow tests)"
    fi

    if [[ -n "$CUSTOM_PROFILE" ]]; then
        if [[ ! -f "$CUSTOM_PROFILE" ]]; then
            log_error "Custom profile not found: $CUSTOM_PROFILE"
            return 1
        fi
        lynis_cmd+=" --profile $CUSTOM_PROFILE"
        log_info "Using custom profile: $CUSTOM_PROFILE"
    fi

    # Run audit (suppress output to console)
    $lynis_cmd --quiet || {
        log_warning "Audit completed with findings (normal)"
    }

    log_success "Audit complete"
}

# ============================================
# Report Parsing Functions
# ============================================

parse_report() {
    log_info "Parsing audit report..."

    if [[ ! -f "$REPORT_FILE" ]]; then
        log_error "Report file not found: $REPORT_FILE"
        return 1
    fi

    # Extract hardening index
    local hardening_index
    hardening_index=$(grep "^hardening_index=" "$REPORT_FILE" | cut -d= -f2 || echo "0")

    # Count warnings
    local warnings_count
    warnings_count=$(grep -c "^warning\[\]=" "$REPORT_FILE" 2>/dev/null || echo "0")

    # Count suggestions
    local suggestions_count
    suggestions_count=$(grep -c "^suggestion\[\]=" "$REPORT_FILE" 2>/dev/null || echo "0")

    # Count tests done
    local tests_done
    tests_done=$(grep "^lynis_tests_done=" "$REPORT_FILE" | cut -d= -f2 || echo "0")

    # Display results
    echo ""
    echo "========================================="
    echo "  Lynis Audit Results"
    echo "========================================="
    echo "  Hardening Index:  $hardening_index / 100"
    echo "  Tests Performed:  $tests_done"
    echo "  Warnings:         $warnings_count"
    echo "  Suggestions:      $suggestions_count"
    echo "========================================="
    echo ""

    # Score interpretation
    if [[ $hardening_index -ge 80 ]]; then
        log_success "Hardening Index: EXCELLENT (≥80)"
    elif [[ $hardening_index -ge 60 ]]; then
        log_warning "Hardening Index: GOOD (60-79)"
    else
        log_warning "Hardening Index: NEEDS IMPROVEMENT (<60)"
    fi

    echo ""
    log_info "Full report: $REPORT_FILE"
    log_info "Human-readable log: $LOG_FILE"
}

# ============================================
# Top Findings Functions
# ============================================

show_top_suggestions() {
    log_info "Top 10 Security Suggestions:"
    echo ""

    if [[ ! -f "$REPORT_FILE" ]]; then
        log_error "Report file not found"
        return 1
    fi

    # Extract suggestions (first 10)
    grep "^suggestion\[\]=" "$REPORT_FILE" | head -n 10 | cut -d= -f2 | while IFS= read -r suggestion; do
        echo "  • $suggestion"
    done

    echo ""
    log_info "See HARDENING_GUIDE.md for prioritized recommendations"
}

# ============================================
# Main Function
# ============================================

main() {
    log_info "Starting Lynis security audit..."

    check_root
    check_lynis_installed

    run_audit || exit 1
    parse_report || exit 1
    show_top_suggestions || log_warning "Could not extract suggestions"

    log_success "Audit workflow complete!"
}

# ============================================
# Command Parsing
# ============================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --quick)
            QUICK_MODE=true
            ;;
        --profile)
            if [[ -z "${2:-}" ]]; then
                log_error "--profile requires a path argument"
                exit 1
            fi
            CUSTOM_PROFILE="$2"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [--quick] [--profile /path/to/profile.prf]"
            exit 1
            ;;
    esac
    shift
done

main
