#!/bin/bash
# Kernel Hardening Setup Script
# Ubuntu Server 24.04 LTS - CIS Benchmark Level 1 & 2
# 
# Purpose: Configure sysctl kernel parameters for security hardening
# Sources: CIS Ubuntu 24.04 Benchmark, konstruktoid/hardening, nixCraft
#
# Usage: sudo ./setup-kernel-hardening.sh
#
# IMPORTANT: Requires root/sudo privileges

set -uo pipefail

# Simple logging functions (no external dependencies)
log_info() { echo "[INFO] $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_warning() { echo "[WARNING] $*"; }

readonly LOG_PREFIX="[Kernel Hardening]"
readonly SYSCTL_HARDENING_FILE="/etc/sysctl.d/60-hardening.conf"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
readonly TIMESTAMP

# Check root
if [ "$EUID" -ne 0 ]; then
    log_error "$LOG_PREFIX This script must be run with sudo!"
    exit 1
fi

log_info "$LOG_PREFIX =========================================="
log_info "$LOG_PREFIX Kernel Hardening Setup"
log_info "$LOG_PREFIX Ubuntu Server 24.04 LTS"
log_info "$LOG_PREFIX =========================================="
echo ""

# Display current values before hardening
log_info "$LOG_PREFIX Current kernel parameters (BEFORE hardening):"
echo ""

declare -a params=(
    "fs.suid_dumpable"
    "kernel.randomize_va_space"
    "kernel.dmesg_restrict"
    "kernel.kptr_restrict"
    "net.ipv4.conf.all.log_martians"
    "net.ipv4.conf.default.send_redirects"
    "net.ipv4.conf.all.send_redirects"
    "net.ipv4.conf.default.accept_source_route"
    "net.ipv4.conf.all.rp_filter"
    "net.ipv4.tcp_syncookies"
)

for param in "${params[@]}"; do
    value=$(sysctl -n "$param" 2>/dev/null || echo "N/A")
    log_info "$LOG_PREFIX   $param = $value"
done
echo ""

# Create sysctl hardening configuration
log_info "$LOG_PREFIX Creating kernel hardening configuration..."

cat > "$SYSCTL_HARDENING_FILE" << EOF
## Kernel Hardening Configuration
## Ubuntu Server 24.04 LTS
## CIS Benchmark Level 1 & 2 + Community Best Practices
##
## Purpose: Security hardening via sysctl parameters
## Sources: CIS Ubuntu 24.04 Benchmark, konstruktoid/hardening, nixCraft
##
## Note: This config is applied automatically after reboot
## Filename priority: 60-* overrides Ubuntu defaults (50-*)

## ==========================================
## Filesystem Security (CIS 1.5.x)
## ==========================================

## Disable core dumps for SUID/SGID programs (CIS 1.5.1)
## Prevents information disclosure through core dumps of privileged programs
fs.suid_dumpable = 0

## Hardlink/Symlink Protection (Defense-in-Depth)
## Prevents hardlink and symlink-based privilege escalation attacks
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

## FIFO Protection
## Protects against FIFO-based race condition attacks
fs.protected_fifos = 2

## ==========================================
## Kernel Security
## ==========================================

## ASLR (Address Space Layout Randomization)
## Randomizes memory addresses for exploit mitigation
kernel.randomize_va_space = 2

## Kernel Pointer Restriction (CIS 1.5.3)
## Hides kernel pointer addresses from non-privileged users
## 1 = root only, 2 = nobody (2 may break systemd services)
kernel.kptr_restrict = 1

## dmesg Restriction (CIS 1.5.2)
## Restricts access to kernel logs (root only)
kernel.dmesg_restrict = 1

## Core Dump Filename with PID
## Simplifies debugging without security impact
kernel.core_uses_pid = 1

## SysRq Key Configuration
## Limits dangerous kernel functions via physical access
## 176 = allow sync + reboot only
kernel.sysrq = 176

## Unprivileged BPF Disabled
## Prevents eBPF-based kernel exploits
kernel.unprivileged_bpf_disabled = 1

## Ptrace Scope Restriction
## Prevents process injection attacks
## 1 = restricted, 2 = admin-only (2 breaks ptrace-based debuggers)
kernel.yama.ptrace_scope = 1

## Performance Event Paranoia
## Restricts performance counter access
kernel.perf_event_paranoid = 3

## ==========================================
## Network Security - IPv4 (CIS 3.x)
## ==========================================

## IP Forwarding
## Note: Docker REQUIRES ip_forward=1 for container networking
## If you run Docker, DO NOT set this to 0!
## Uncomment only if you DO NOT run Docker:
# net.ipv4.ip_forward = 0

## ICMP Redirects Disabled (CIS 3.2.2)
## Prevents MITM attacks via ICMP redirect
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

## Secure ICMP Redirects Disabled (CIS 3.2.3)
## Additional protection against ICMP redirect-based attacks
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

## ICMP Redirect Sending Disabled (CIS 3.2.1)
## Servers should NOT send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

## Source Routing Disabled (CIS 3.2.4)
## Prevents IP spoofing attacks
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

## Reverse Path Filtering (CIS 3.2.7)
## Protects against IP spoofing via source validation
## 1 = strict mode, 2 = loose mode (use 1 for best security)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

## Log Martians (CIS 3.2.5)
## Logs suspicious packets (spoofed/martian addresses)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

## ICMP Echo Ignore Broadcasts (CIS 3.2.6)
## Prevents Smurf attacks
net.ipv4.icmp_echo_ignore_broadcasts = 1

## ICMP Bogus Error Responses
## Prevents log flooding by invalid ICMP
net.ipv4.icmp_ignore_bogus_error_responses = 1

## SYN Cookies (CIS 3.2.8)
## Protects against SYN flood attacks
net.ipv4.tcp_syncookies = 1

## IPv6 Router Advertisements Disabled (CIS 3.2.9)
## Prevents rogue router attacks (if IPv6 not used)
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

## ==========================================
## BPF JIT Hardening
## ==========================================

## BPF JIT Compiler Hardening
## Protects against eBPF JIT-based kernel exploits
net.core.bpf_jit_harden = 2
EOF

log_success "$LOG_PREFIX Configuration created: $SYSCTL_HARDENING_FILE"

# Apply sysctl configuration
log_info "$LOG_PREFIX Applying kernel parameters (live)..."
if sysctl -p "$SYSCTL_HARDENING_FILE" > /dev/null 2>&1; then
    log_success "$LOG_PREFIX Kernel parameters applied successfully"
else
    log_error "$LOG_PREFIX Failed to apply kernel parameters"
    exit 1
fi
echo ""

# Validate critical parameters
log_info "$LOG_PREFIX Validating configuration..."
echo ""

failed=0
total=0

# Critical parameters to validate
declare -A expected_values=(
    ["fs.suid_dumpable"]="0"
    ["kernel.randomize_va_space"]="2"
    ["kernel.dmesg_restrict"]="1"
    ["kernel.kptr_restrict"]="1"
    ["net.ipv4.conf.all.log_martians"]="1"
    ["net.ipv4.conf.default.send_redirects"]="0"
    ["net.ipv4.conf.all.send_redirects"]="0"
    ["net.ipv4.conf.default.accept_source_route"]="0"
    ["net.ipv4.conf.all.rp_filter"]="1"
    ["net.ipv4.tcp_syncookies"]="1"
)

for param in "${!expected_values[@]}"; do
    ((total++))
    expected="${expected_values[$param]}"
    actual=$(sysctl -n "$param" 2>/dev/null || echo "N/A")

    if [ "$actual" = "$expected" ]; then
        log_success "$LOG_PREFIX   ✅ $param = $actual"
    else
        log_error "$LOG_PREFIX   ❌ $param = $actual (expected: $expected)"
        ((failed++))
    fi
done

echo ""
log_info "$LOG_PREFIX Validation: $((total - failed))/$total parameters correct"

if [ $failed -eq 0 ]; then
    log_success "$LOG_PREFIX All critical parameters configured correctly!"
else
    log_warning "$LOG_PREFIX $failed/$total parameters failed validation"
fi
echo ""

# Docker compatibility check
if command -v docker >/dev/null 2>&1; then
    log_info "$LOG_PREFIX Docker detected - checking compatibility..."
    
    ip_forward=$(sysctl -n net.ipv4.ip_forward)
    if [ "$ip_forward" = "1" ]; then
        log_success "$LOG_PREFIX net.ipv4.ip_forward = 1 (Docker compatible)"
    else
        log_warning "$LOG_PREFIX net.ipv4.ip_forward = $ip_forward (Docker may not work!)"
        log_warning "$LOG_PREFIX Edit $SYSCTL_HARDENING_FILE if needed"
    fi
    echo ""
fi

# Summary
log_info "$LOG_PREFIX =========================================="
log_info "$LOG_PREFIX Kernel Hardening Setup Complete"
log_info "$LOG_PREFIX =========================================="
echo ""
log_info "$LOG_PREFIX Configuration file: $SYSCTL_HARDENING_FILE"
log_info "$LOG_PREFIX Parameters applied: Live (immediate effect)"
log_info "$LOG_PREFIX Reboot persistence: Automatic (via /etc/sysctl.d/)"
echo ""
log_info "$LOG_PREFIX Key changes:"
log_info "$LOG_PREFIX   - Core dumps disabled for SUID programs"
log_info "$LOG_PREFIX   - Martian packet logging enabled"
log_info "$LOG_PREFIX   - ICMP redirect prevention enabled"
log_info "$LOG_PREFIX   - Source routing disabled"
log_info "$LOG_PREFIX   - eBPF protections enabled"
echo ""
log_info "$LOG_PREFIX Validation commands:"
log_info "$LOG_PREFIX   sysctl -a | grep suid_dumpable"
log_info "$LOG_PREFIX   sysctl -a | grep log_martians"
log_info "$LOG_PREFIX   sysctl -a | grep send_redirects"
echo ""
log_success "$LOG_PREFIX Done! Hardening is active and will persist after reboot."
