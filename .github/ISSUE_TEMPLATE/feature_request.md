---
name: Feature Request
about: Suggest a new feature or improvement
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

## Problem Statement

**What problem does this feature solve?**

Describe the use case, the gap in coverage, or the limitation you're facing.

## Affected Component

An existing component (`fail2ban`, `ssh-hardening`, `nftables`, `ufw`, `aide`,
`auditd`, `apparmor`, `kernel-hardening`, `boot-security`, `usb-defense`,
`lynis`, `rkhunter`, `security-monitoring`, `vaultwarden`), or a new one?

## Proposed Solution

**How should this work?**

Describe your proposal in detail:
- The rule, template, or script involved
- The default value and why it is the right default
- Usage example

## CIS Benchmark Reference

If this maps to a CIS Ubuntu Benchmark control, name it (e.g. `3.5.1.7`).
Not every useful hardening measure has one -- say so if it doesn't.

## Effect on a Running Server

**Does this change anything for an operator who already applies this repository?**

Be specific about anything that restricts access: an sshd option, a default-deny
policy, a fail2ban threshold, a sysctl value, a GRUB password. Such a change
needs upgrade notes, and knowing that up front saves a round trip.

## Alternatives Considered

What other approaches did you consider, and why do they work less well?

## Additional Context

Any other context, references, or upstream documentation.
