#!/usr/bin/env bash
#
# Ubuntu Server Security - Installation Script
# Installs and configures security components
#
# Usage: ./install.sh [component] [--dry-run] [--help]
#
set -uo pipefail

# =============================================================================
# Configuration
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "unknown")"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Available components
readonly COMPONENTS=(
    "fail2ban"
    "ssh-hardening"
    "nftables"
    "ufw"
    "aide"
    "lynis"
    "rkhunter"
    "auditd"
    "apparmor"
    "kernel-hardening"
    "boot-security"
    "usb-defense"
    "vaultwarden"
    "security-monitoring"
)

# =============================================================================
# Logging Functions
# =============================================================================

log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# =============================================================================
# Helper Functions
# =============================================================================

show_usage() {
    cat << EOF
Ubuntu Server Security Installation Script v${VERSION}

Usage: ${SCRIPT_NAME} [OPTIONS] [COMPONENT]

Options:
    -h, --help      Show this help message
    -l, --list      List available components
    -d, --dry-run   Show what would be done without making changes
    -a, --all       Install all components (interactive)
    -v, --version   Show version

Components:
$(printf '    %s\n' "${COMPONENTS[@]}")

Examples:
    ${SCRIPT_NAME} --list              # List all components
    ${SCRIPT_NAME} fail2ban            # Install fail2ban component
    ${SCRIPT_NAME} --dry-run aide      # Preview AIDE installation
    ${SCRIPT_NAME} --all               # Interactive installation of all components

Documentation:
    https://github.com/fidpa/ubuntu-server-security

EOF
}

show_version() {
    echo "${SCRIPT_NAME} version ${VERSION}"
}

list_components() {
    echo "Available security components:"
    echo ""
    printf "%-20s %s\n" "COMPONENT" "DESCRIPTION"
    printf "%-20s %s\n" "---------" "-----------"
    printf "%-20s %s\n" "fail2ban" "Brute-force protection with GeoIP and Telegram alerts"
    printf "%-20s %s\n" "ssh-hardening" "SSH hardening with 15+ CIS controls"
    printf "%-20s %s\n" "nftables" "Advanced firewall with NAT and Docker support"
    printf "%-20s %s\n" "ufw" "Simple firewall (CIS-compliant)"
    printf "%-20s %s\n" "aide" "File integrity monitoring (99.7% false-positive reduction)"
    printf "%-20s %s\n" "lynis" "Security auditing with Hardening Index"
    printf "%-20s %s\n" "rkhunter" "Rootkit detection"
    printf "%-20s %s\n" "auditd" "Kernel-level audit logging (CIS 4.1.x)"
    printf "%-20s %s\n" "apparmor" "Mandatory Access Control profiles"
    printf "%-20s %s\n" "kernel-hardening" "sysctl security parameters"
    printf "%-20s %s\n" "boot-security" "GRUB and UEFI password protection"
    printf "%-20s %s\n" "usb-defense" "USB device access control"
    printf "%-20s %s\n" "vaultwarden" "Credential management via Bitwarden CLI"
    printf "%-20s %s\n" "security-monitoring" "Unified security event monitoring"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_prerequisites() {
    log "Checking prerequisites..."

    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine OS version"
        return 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release

    if [[ "${ID}" != "ubuntu" && "${ID}" != "debian" ]]; then
        error "This script is designed for Ubuntu/Debian (found: ${ID})"
        return 1
    fi

    log "OS: ${PRETTY_NAME}"

    # Check systemd
    if ! command -v systemctl &> /dev/null; then
        error "systemd is required but not found"
        return 1
    fi

    log "Prerequisites check passed"
    return 0
}

# =============================================================================
# Component Installation Functions
# =============================================================================

install_component() {
    local component="$1"
    local dry_run="${2:-false}"

    local component_dir="${SCRIPT_DIR}/${component}"

    if [[ ! -d "${component_dir}" ]]; then
        error "Component directory not found: ${component_dir}"
        return 1
    fi

    log "Installing component: ${component}"

    # Check for component-specific install script
    local install_script="${component_dir}/scripts/install.sh"
    local deploy_script="${component_dir}/scripts/deploy-${component}.sh"
    local setup_script="${component_dir}/scripts/setup-${component//-/_}.sh"

    if [[ -f "${install_script}" ]]; then
        if [[ "${dry_run}" == "true" ]]; then
            log "[DRY-RUN] Would execute: ${install_script}"
        else
            log "Running component installer: ${install_script}"
            bash "${install_script}"
        fi
    elif [[ -f "${deploy_script}" ]]; then
        if [[ "${dry_run}" == "true" ]]; then
            log "[DRY-RUN] Would execute: ${deploy_script}"
        else
            log "Running component deploy script: ${deploy_script}"
            bash "${deploy_script}"
        fi
    elif [[ -f "${setup_script}" ]]; then
        if [[ "${dry_run}" == "true" ]]; then
            log "[DRY-RUN] Would execute: ${setup_script}"
        else
            log "Running component setup script: ${setup_script}"
            bash "${setup_script}"
        fi
    else
        warn "No automated installer found for ${component}"
        log "Please follow manual installation in: ${component_dir}/docs/SETUP.md"
        return 0
    fi

    success "Component ${component} installation complete"
    return 0
}

interactive_install() {
    local dry_run="${1:-false}"

    echo ""
    echo "========================================"
    echo "Ubuntu Server Security - Interactive Setup"
    echo "========================================"
    echo ""

    for component in "${COMPONENTS[@]}"; do
        echo -n "Install ${component}? [y/N] "
        read -r response
        if [[ "${response}" =~ ^[Yy]$ ]]; then
            install_component "${component}" "${dry_run}"
        else
            log "Skipping ${component}"
        fi
        echo ""
    done

    show_next_steps
}

show_next_steps() {
    echo ""
    echo "========================================"
    echo "Next Steps"
    echo "========================================"
    echo ""
    echo "1. Review installed configurations:"
    echo "   - SSH: /etc/ssh/sshd_config.d/"
    echo "   - Firewall: /etc/nftables.conf or 'ufw status'"
    echo "   - AIDE: /etc/aide/aide.conf"
    echo ""
    echo "2. Run a security audit:"
    echo "   sudo lynis audit system"
    echo ""
    echo "3. Check documentation:"
    echo "   ${SCRIPT_DIR}/docs/README.md"
    echo ""
    echo "4. For monitoring integration:"
    echo "   ${SCRIPT_DIR}/docs/PROMETHEUS_INTEGRATION.md"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    local dry_run=false
    local component=""
    local action=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -l|--list)
                list_components
                exit 0
                ;;
            -d|--dry-run)
                dry_run=true
                shift
                ;;
            -a|--all)
                action="all"
                shift
                ;;
            -*)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                component="$1"
                shift
                ;;
        esac
    done

    # Show usage if no arguments
    if [[ -z "${action}" && -z "${component}" ]]; then
        show_usage
        exit 0
    fi

    # Check if running as root (unless dry-run)
    if [[ "${dry_run}" == "false" ]]; then
        check_root
    fi

    # Check prerequisites
    check_prerequisites || exit 1

    # Execute action
    if [[ "${action}" == "all" ]]; then
        interactive_install "${dry_run}"
    elif [[ -n "${component}" ]]; then
        # Validate component
        local valid=false
        for c in "${COMPONENTS[@]}"; do
            if [[ "${c}" == "${component}" ]]; then
                valid=true
                break
            fi
        done

        if [[ "${valid}" == "false" ]]; then
            error "Unknown component: ${component}"
            echo ""
            list_components
            exit 1
        fi

        install_component "${component}" "${dry_run}"
        show_next_steps
    fi

    success "Installation complete!"
    return 0
}

main "$@"
