---
name: Bug Report
about: Report a bug to help us improve
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description

**Clear and concise description of the bug**

## Affected Component

Which hardening component is involved? (e.g. `fail2ban`, `ssh-hardening`,
`nftables`, `ufw`, `aide`, `auditd`, `apparmor`, `kernel-hardening`,
`boot-security`, `usb-defense`, `lynis`, `rkhunter`, `security-monitoring`,
`vaultwarden`, or `install.sh` itself)

## Steps to Reproduce

1. Deploy the component: `sudo ./install.sh <component>`
2. Apply the configuration or run the script
3. Observe the error

## Expected Behavior

What you expected to happen.

## Actual Behavior

What actually happened.

## Environment

- **Repository version**: (run `./install.sh --version`)
- **OS**: (e.g. Ubuntu 24.04 LTS)
- **Kernel**: (run `uname -r`)
- **Component version**: (if the affected script prints one)
- **ShellCheck version**: (run `shellcheck --version`, if relevant)

## Logs and Error Messages

```bash
# Paste relevant logs or error messages here.
# Please redact hostnames, public IP addresses, and account names first.
```

## Impact on a Running Server

Did this lock anyone out, block legitimate traffic, or leave a service
unprotected? If so, say so here -- it changes how urgently we look at it.

## Additional Context

Any other context about the problem (e.g. related issues, workarounds tried).
