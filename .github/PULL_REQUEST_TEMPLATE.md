# Pull Request

## Description

**What does this PR do?**

Provide a clear and concise description of your changes.

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New hardening measure or component (non-breaking)
- [ ] Changed default or tightened rule (see *Effect on a running server* below)
- [ ] Breaking change (removes or redefines an existing setting)
- [ ] Documentation update
- [ ] Tooling / CI

## Related Issues

Closes #(issue number)

## Changes Made

**Summary of changes:**
- Change 1
- Change 2

## Effect on a Running Server

**Does this change anything for an operator who already applies this repository?**

Answer explicitly, even if the answer is "nothing". Name any change to:

- `sshd_config` (`PermitRootLogin`, `PasswordAuthentication`, `AllowUsers`, `Port`)
- a firewall default policy or rule order (nftables, ufw)
- fail2ban `bantime` / `findtime` / `maxretry` / `ignoreip`
- a `sysctl` value, a GRUB password, or a USBGuard policy
- an installation path or the order of steps in `install.sh`

Anything in that list can lock an operator out of their own server and needs an
`### Upgrade notes` block in the changelog, including a rollback command.

## Testing

**How has this been tested?**

- [ ] Applied on a test system (not production)
- [ ] `shellcheck --severity=error` passes
- [ ] `bash -n` passes on all changed scripts
- [ ] Config syntax validated (`nft --check`, `sshd -t`, `visudo -c`, as applicable)
- [ ] Rollback path verified

**Test environment:**
- OS:
- Kernel:

## Checklist

- [ ] Every changed measure is documented in the component's README/docs
- [ ] `CHANGELOG.md` updated under `## [Unreleased]`
- [ ] `### Security` entry added if a hardening measure changed
- [ ] `### Upgrade notes` added if anything above restricts access
- [ ] No real hostnames, public IP addresses, or account names in code or docs
      (use RFC 2606 `example.com` and RFC 5737 `192.0.2.x`)
- [ ] All added text is in English

## Additional Notes

Any additional context or notes for reviewers.
