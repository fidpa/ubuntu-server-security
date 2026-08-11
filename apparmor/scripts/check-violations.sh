#!/bin/bash
# check-violations.sh - Check for AppArmor violations
# Part of: ubuntu-server-security
#
# Usage: ./check-violations.sh [profile-name] [--recent]
#
# Options:
#   profile-name   Filter by profile (e.g., "postgresql")
#   --recent       Show only last hour (default: last 24h)

set -euo pipefail

PROFILE_FILTER="${1:-}"
RECENT_ONLY=false

for arg in "$@"; do
    if [[ "$arg" == "--recent" ]]; then
        RECENT_ONLY=true
    fi
done

# Time filter
if [[ "$RECENT_ONLY" == true ]]; then
    TIME_FILTER="1 hour ago"
    TIME_DESC="last hour"
else
    TIME_FILTER="24 hours ago"
    TIME_DESC="last 24 hours"
fi

echo "=== AppArmor Violations ($TIME_DESC) ==="
echo ""

# Check dmesg for violations
echo "--- Kernel Messages (dmesg) ---"
if [[ -n "$PROFILE_FILTER" ]]; then
    sudo dmesg -T --since="$TIME_FILTER" 2>/dev/null | grep -i "apparmor.*$PROFILE_FILTER" || echo "No violations found for profile: $PROFILE_FILTER"
else
    sudo dmesg -T --since="$TIME_FILTER" 2>/dev/null | grep -i "apparmor.*DENIED" || echo "No violations found"
fi

echo ""

# Check syslog for violations
echo "--- Syslog ---"
if [[ -f /var/log/syslog ]]; then
    if [[ -n "$PROFILE_FILTER" ]]; then
        grep -i "apparmor.*$PROFILE_FILTER" /var/log/syslog 2>/dev/null | tail -20 || echo "No violations found for profile: $PROFILE_FILTER"
    else
        grep -i "apparmor.*DENIED" /var/log/syslog 2>/dev/null | tail -20 || echo "No violations found"
    fi
else
    echo "Syslog not found (using journald?)"
    if [[ -n "$PROFILE_FILTER" ]]; then
        journalctl --since="$TIME_FILTER" 2>/dev/null | grep -i "apparmor.*$PROFILE_FILTER" | tail -20 || echo "No violations found"
    else
        journalctl --since="$TIME_FILTER" 2>/dev/null | grep -i "apparmor.*DENIED" | tail -20 || echo "No violations found"
    fi
fi

echo ""

# Summary
echo "=== Current Profile Status ==="
sudo aa-status 2>/dev/null | head -20

echo ""
echo "Tip: Use 'sudo aa-logprof' to generate profile updates from violations"
