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

# Installer per component, relative to the component directory. Components
# without an entry are installed by hand, see their docs/SETUP.md.
# Installers that implement a dry run of their own. install.sh passes the flag
# as the first argument, because deploy-fail2ban.sh only looks at $1.
declare -rA DRY_RUN_FLAGS=(
    ["fail2ban"]="--dry-run"
    ["lynis"]="--dry-run"
)

declare -rA INSTALLERS=(
    ["fail2ban"]="scripts/deploy-fail2ban.sh"
    ["nftables"]="scripts/deploy-nftables.sh"
    ["lynis"]="scripts/install-lynis.sh"
    ["auditd"]="scripts/deploy-auditd.sh base"
    ["kernel-hardening"]="scripts/setup-kernel-hardening.sh"
    ["boot-security"]="scripts/setup-grub-password.sh"
    ["usb-defense"]="scripts/deploy-usb-defense.sh"
)

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
                    (fail2ban and lynis dry-run themselves when run as root)
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

component_install_mode() {
    [[ -n "${INSTALLERS[$1]:-}" ]] && echo "script" || echo "manual"
}

list_components() {
    echo "Available security components:"
    echo ""
    printf "%-20s %-9s %s\n" "COMPONENT" "INSTALL" "DESCRIPTION"
    printf "%-20s %-9s %s\n" "---------" "-------" "-----------"
    printf "%-20s %-9s %s\n" "fail2ban" "$(component_install_mode "fail2ban")" "Brute-force protection with GeoIP and Telegram alerts"
    printf "%-20s %-9s %s\n" "ssh-hardening" "$(component_install_mode "ssh-hardening")" "SSH hardening, 15 of 18 applicable CIS 5.2.x controls"
    printf "%-20s %-9s %s\n" "nftables" "$(component_install_mode "nftables")" "Advanced firewall with NAT and Docker support"
    printf "%-20s %-9s %s\n" "ufw" "$(component_install_mode "ufw")" "Simple firewall (CIS-compliant)"
    printf "%-20s %-9s %s\n" "aide" "$(component_install_mode "aide")" "File integrity monitoring (99.7% false-positive reduction)"
    printf "%-20s %-9s %s\n" "lynis" "$(component_install_mode "lynis")" "Security auditing with Hardening Index"
    printf "%-20s %-9s %s\n" "rkhunter" "$(component_install_mode "rkhunter")" "Rootkit detection"
    printf "%-20s %-9s %s\n" "auditd" "$(component_install_mode "auditd")" "Kernel-level audit logging (CIS 4.1.x)"
    printf "%-20s %-9s %s\n" "apparmor" "$(component_install_mode "apparmor")" "Mandatory Access Control profiles"
    printf "%-20s %-9s %s\n" "kernel-hardening" "$(component_install_mode "kernel-hardening")" "sysctl security parameters"
    printf "%-20s %-9s %s\n" "boot-security" "$(component_install_mode "boot-security")" "GRUB and UEFI password protection"
    printf "%-20s %-9s %s\n" "usb-defense" "$(component_install_mode "usb-defense")" "USB device access control"
    printf "%-20s %-9s %s\n" "vaultwarden" "$(component_install_mode "vaultwarden")" "Credential management via Bitwarden CLI"
    printf "%-20s %-9s %s\n" "security-monitoring" "$(component_install_mode "security-monitoring")" "Unified security event monitoring"
    echo ""
    echo "script = installed by ${SCRIPT_NAME}, manual = follow <component>/docs/SETUP.md"
}

is_root() {
    [[ $EUID -eq 0 ]]
}

check_root() {
    if ! is_root; then
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

    # Read, not sourced: /etc/os-release sets VERSION, which is readonly here,
    # and sourcing would pull a dozen more names into this shell
    local os_id os_name
    os_id="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')"
    os_name="$(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | tr -d '"')"

    if [[ "${os_id}" != "ubuntu" && "${os_id}" != "debian" ]]; then
        error "This script is designed for Ubuntu/Debian (found: ${os_id})"
        return 1
    fi

    log "OS: ${os_name}"

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

    # Installer per component, looked up rather than derived from the name:
    # the scripts are named after what they configure (setup-grub-password.sh),
    # not after their directory. Components missing here need an argument that
    # only the operator can supply (ufw: rules file, apparmor: profile) or ship
    # no installer at all; both cases fall through to the manual path below.
    local installer="${INSTALLERS[${component}]:-}"

    if [[ -z "${installer}" ]]; then
        warn "No automated installer found for ${component}"
        log "Please follow manual installation in: ${component_dir}/docs/SETUP.md"
        return 0
    fi

    # Word splitting is intended: the entry may carry arguments
    # shellcheck disable=SC2206
    local cmd=(${installer})
    local script="${component_dir}/${cmd[0]}"
    cmd[0]="${script}"

    if [[ ! -f "${script}" ]]; then
        error "Installer listed for ${component} is missing: ${script}"
        return 1
    fi

    local dry_flag="${DRY_RUN_FLAGS[${component}]:-}"

    if [[ "${dry_run}" == "true" ]]; then
        # A component that dry-runs itself reports what it would touch; that
        # needs root, because it reads the configuration it would replace
        if [[ -n "${dry_flag}" ]] && is_root; then
            local dry_cmd=("${cmd[0]}" "${dry_flag}" "${cmd[@]:1}")
            log "Running installer in its own dry-run mode: ${dry_cmd[*]}"
            if ! bash "${dry_cmd[@]}"; then
                error "Dry run of ${component} failed"
                return 1
            fi
            return 0
        fi

        log "[DRY-RUN] Would execute: ${cmd[*]}"
        if [[ -n "${dry_flag}" ]]; then
            log "${component} dry-runs itself: run this with sudo to see the detail"
        fi
        return 0
    fi

    log "Running component installer: ${cmd[*]}"
    if ! bash "${cmd[@]}"; then
        error "Component ${component} installation failed"
        return 1
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

        if ! install_component "${component}" "${dry_run}"; then
            error "Installation aborted"
            return 1
        fi
        show_next_steps
    fi

    success "Installation complete!"
    return 0
}

main "$@"
