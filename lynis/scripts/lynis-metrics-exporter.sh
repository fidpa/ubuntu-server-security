#!/bin/bash
# Lynis Prometheus Metrics Exporter
# SPDX-License-Identifier: MIT
# Version: 1.0.0
#
# Purpose: Export Lynis audit metrics to Prometheus textfile collector
# Usage: sudo ./lynis-metrics-exporter.sh [--run-audit]

set -uo pipefail

# ============================================
# Configuration
# ============================================

readonly REPORT_FILE="/var/log/lynis-report.dat"
readonly OUTPUT_FILE="/var/lib/node_exporter/textfile_collector/lynis.prom"

# ============================================
# Variables
# ============================================

RUN_AUDIT=false

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

# ============================================
# Prerequisite Checks
# ============================================

check_report_exists() {
    if [[ ! -f "$REPORT_FILE" ]]; then
        log_error "Report file not found: $REPORT_FILE"
        log_error "Run audit first: sudo lynis audit system"
        return 1
    fi
}

check_output_dir() {
    local output_dir
    output_dir="$(dirname "$OUTPUT_FILE")"

    if [[ ! -d "$output_dir" ]]; then
        log_error "Output directory not found: $output_dir"
        log_error "Install node_exporter with textfile collector enabled"
        return 1
    fi
}

# ============================================
# Audit Function
# ============================================

run_audit_if_requested() {
    if [[ "$RUN_AUDIT" == true ]]; then
        log_info "Running Lynis audit (--quick mode)..."

        if ! command -v lynis >/dev/null 2>&1; then
            log_error "Lynis is not installed"
            return 1
        fi

        lynis audit system --quick --quiet || {
            log_error "Audit failed"
            return 1
        }

        log_success "Audit complete"
    fi
}

# ============================================
# Metrics Extraction Functions
# ============================================

extract_hardening_index() {
    grep "^hardening_index=" "$REPORT_FILE" 2>/dev/null | cut -d= -f2 || echo "0"
}

extract_tests_done() {
    grep "^lynis_tests_done=" "$REPORT_FILE" 2>/dev/null | cut -d= -f2 || echo "0"
}

extract_warnings_count() {
    grep -c "^warning\[\]=" "$REPORT_FILE" 2>/dev/null || echo "0"
}

extract_suggestions_count() {
    grep -c "^suggestion\[\]=" "$REPORT_FILE" 2>/dev/null || echo "0"
}

# ============================================
# Metrics Export Function
# ============================================

export_metrics() {
    log_info "Extracting metrics from report..."

    local hardening_index
    hardening_index=$(extract_hardening_index)

    local tests_done
    tests_done=$(extract_tests_done)

    local warnings_count
    warnings_count=$(extract_warnings_count)

    local suggestions_count
    suggestions_count=$(extract_suggestions_count)

    log_info "Hardening Index: $hardening_index"
    log_info "Tests Done: $tests_done"
    log_info "Warnings: $warnings_count"
    log_info "Suggestions: $suggestions_count"

    # Write Prometheus metrics
    log_info "Writing metrics to: $OUTPUT_FILE"

    cat > "$OUTPUT_FILE" << EOF
# HELP lynis_hardening_index Lynis Hardening Index (0-100)
# TYPE lynis_hardening_index gauge
lynis_hardening_index $hardening_index

# HELP lynis_tests_done Total number of tests performed
# TYPE lynis_tests_done counter
lynis_tests_done $tests_done

# HELP lynis_warnings Number of warnings found
# TYPE lynis_warnings gauge
lynis_warnings $warnings_count

# HELP lynis_suggestions Number of suggestions made
# TYPE lynis_suggestions gauge
lynis_suggestions $suggestions_count
EOF

    log_success "Metrics exported successfully"
}

# ============================================
# Main Function
# ============================================

main() {
    log_info "Starting Lynis metrics export..."

    run_audit_if_requested || exit 1
    check_report_exists || exit 1
    check_output_dir || exit 1
    export_metrics || exit 1

    log_success "Metrics export complete!"
}

# ============================================
# Command Parsing
# ============================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run-audit)
            RUN_AUDIT=true
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [--run-audit]"
            exit 1
            ;;
    esac
    shift
done

main
