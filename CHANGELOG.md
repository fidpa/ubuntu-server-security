# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Additional security component integrations
- Ansible playbook support
- Docker security hardening module

## [1.2.0] - 2026-08-30: install.sh runs the installers it could not find, and the README says what is not there

`install.sh` derived each installer's file name from the component name. Three
components ship a script the derivation never produced, a fourth was called
without the argument it requires, and the exit status of every installer was
discarded, so a run that did nothing still ended in `[SUCCESS]`. All four are
fixed, and the README was measured against the tree in the same pass.

### Fixed

- **`install.sh` finds the installers of `boot-security`, `kernel-hardening`
  and `lynis` again.** The script derived the file name from the component
  name (`setup-${component//-/_}.sh`), but the scripts are named after what
  they configure: `setup-grub-password.sh`, `setup-kernel-hardening.sh` with
  hyphens, `install-lynis.sh`. No name matched, and the three components fell
  through to the manual path. A lookup table now maps component to installer,
  so a renamed script fails loudly instead of disappearing. Automated
  components go from four to seven.
- **`install.sh auditd` deploys rules instead of printing its usage.**
  `deploy-auditd.sh` requires a mode (`base`, `aggressive`, `docker`) and
  exited 1 without one. The table carries the argument, and `base` is the
  documented recommendation.
- **A failing installer is reported as a failure.** The exit status of the
  component script was discarded: every run ended in `[SUCCESS] Installation
  complete!`, including the `auditd` run that had just refused to do anything.
  `install_component` now propagates the status and `main` aborts on it.
- **`--dry-run` uses the installer's own dry run where one exists.** Both
  `deploy-fail2ban.sh` and `install-lynis.sh` implement `--dry-run` and list
  the files they would write; `install.sh` printed "Would execute" and never
  called them. It now passes the flag through when running as root, and says
  so where it cannot, since both scripts check for root before doing anything.
- **`--list` marks each component `script` or `manual`,** derived from the same
  table the installation uses, so the list cannot drift from the behaviour.
- **`check_prerequisites` no longer prints `/etc/os-release: line 4: VERSION:
  readonly variable`.** It sourced `/etc/os-release`, whose `VERSION` collides
  with the script's own readonly `VERSION`; it now reads `ID` and
  `PRETTY_NAME` out of the file without sourcing it.

### Changed

- **The README states what the repository does and what it does not.** Every
  claim was measured against the tree. Corrected: `apparmor/` ships one profile
  (PostgreSQL 16); Docker keeps its own `docker-default`, which this repository
  does not provide. `install.sh` automates seven of the fourteen components and
  points the other seven at their `docs/SETUP.md`; that is now stated instead
  of a Quick Start that implied full automation. The SSH tally reads 15 of 18
  applicable CIS 5.2.x controls with the benchmark version, per
  `ssh-hardening/docs/CIS_CONTROLS.md`, in place of "15+". The AIDE figure
  carries its measurement (3,799 to 12 changes per day). The drop-in example
  names `99-custom.conf.example`, the file that exists.
- **Removed: the unsourced numbers.** The "CIS Benchmark 100%" badge, "40+
  controls" and "running on multiple servers with 100% CIS compliance" were
  claims about servers outside this repository and could not be checked from
  it. Compatibility now separates tested (Ubuntu 22.04, 24.04) from untested
  (Debian, Raspberry Pi OS), and a Known Limitations section names the lockout
  risk, the missing idempotency and the limits of a CIS mapping.
- **Fixed: two dead links under "See Also".** `ubuntu-server-security-ansible`
  does not exist, and the monitoring templates live at
  `fidpa/linux-monitoring-templates`.

### Upgrade notes

`sudo ./install.sh auditd` now deploys the CIS Level 1 audit rules
(`deploy-auditd.sh base`), where it previously printed the usage of that script
and changed nothing. A host that ran the command before and assumed it was a
no-op will gain `/etc/audit/rules.d/` entries and a restarted `auditd` on the
next run. The rules log, they do not deny; `deploy-auditd.sh` backs up the
existing rules before writing, and `./install.sh --dry-run auditd` names the
command it would run. To keep the old behaviour, do not call the component
through `install.sh`.

## [1.1.5] - 2026-08-28: GitHub identifies the project as MIT-licensed

### Changed

- **The repository page shows the MIT licence, and licence-filtered searches
  find the project.** `LICENSE` carried the repository URL on its own line
  under the copyright notice. GitHub reads a licence text with an extra line as
  modified and reports `NOASSERTION`, which leaves the licence field on the
  repository page empty. The line is gone; the MIT text and the copyright
  notice are byte-for-byte unchanged, and the URL is still in `README.md`.

## [1.1.4] - 2026-08-28: Release notes match the tags they describe, and the remaining scripts are executable

Editorial pass over every section of this file, plus two changes to the repository
itself. Each section now leads with what a release changed for an operator, and each
statement it makes about the code was checked against the tag it describes, using
`git show <tag>:<path>`. The release notes on GitHub are built from these sections, so
the two now say the same thing.

Nothing was invented and nothing was softened: every measured value, path, and function
name that held up stayed as it was. The corrections are listed below, each with the
place in the tree that settles it.

### Fixed
- **`install-lynis.sh` and `validate-lynis-profile.sh` run directly again, as their own
  documentation describes.** `v1.1.3` restored the executable bit on 14 scripts but left
  21 others at `100644`, including these two, which `lynis/docs/SETUP.md` and
  `lynis/docs/CUSTOM_PROFILES.md` invoke as `sudo ../scripts/<script>.sh`. All 21 now
  carry mode `100755` across `aide/`, `auditd/`, `fail2ban/`, `lynis/`, `nftables/`,
  `security-monitoring/`, `ufw/`, and `vaultwarden/`. Content is unchanged, only the
  file mode. `vaultwarden/vaultwarden-credentials.sh` deliberately keeps `100644`: it is
  a library that `vaultwarden/README.md` tells you to `source`, not to run.
- **The initial release section no longer credits `v1.0.0` with a component set and an
  installer that tag does not carry.** `security-monitoring/`, `usb-defense/`, and
  `install.sh` are absent from `git ls-tree -r v1.0.0`; they arrive with `v1.0.1` and
  `v1.1.0`. The `[1.0.0]` section now says which parts of it the tag actually contains.
- **The fail2ban entry in `[1.0.0]` states the number of jails the tag ships.**
  `jail.local.template` and the four numbered files in `fail2ban/drop-ins/` define six
  jails between them; the section had claimed "15+", which is the count of SSH CIS
  controls used elsewhere in this repository.
- **The defense-in-depth entry in `[1.0.0]` counts layers, not components.** Fourteen is
  the number of components; the layer table in that tag's `README.md` has nine rows, and
  the table reached eleven with `v1.0.1`.
- **The `[1.1.2]` entry on release notes no longer generalises over the commit history.**
  Two of the twelve commit messages in this repository are not bare version lines
  (`Remove marketing files (should not be public)` and a merge commit), which is why the
  entry now names the condition instead of asserting it holds for every commit.
- **The `[1.1.2]` security entry names what was removed without describing what it
  contained.** The previous wording identified, file by file, the kind of value each
  removal had carried. Those files remain reachable through the history, so the wording
  was a route to exactly the data the release had set out to remove.

### Changed
- **A tagged release now arrives on GitHub with a headline instead of a bare version
  number.** `.github/workflows/release.yml` reads the headline from the matching
  `CHANGELOG.md` heading (`## [X.Y.Z] - YYYY-MM-DD: <headline>`) and passes it to
  `softprops/action-gh-release` as `name:`. Without it the action falls back to the tag
  name, which is what `v1.1.2` and `v1.1.3` shipped with. The job logs a warning and
  falls back to the plain tag when a heading carries no headline, rather than failing the
  release.
- **The release body no longer starts with a blank line.** Extraction moved from a `sed`
  range to `awk` anchored at the start of the line (`index($0, head) == 1`), followed by
  `sed -e '/./,$!d'`. The `sed` range matched any heading containing the version string,
  including one that merely mentions another version in its headline.

### Upgrade notes

None required. No firewall rule, sshd option, sysctl value, fail2ban threshold, or
installation path changed. Scripts that were readable and runnable via `bash <script>`
are now also runnable via `./<script>`; nothing that worked before stopped working.

Readers building against the `v1.0.0` tag should note that it sits on the first of three
commits carrying that version message. `compare/v1.0.0...v1.0.1` therefore shows two
whole components arriving in what its section describes as a documentation patch. The tag
is not being moved; `v1.0.1` and later are unaffected.

## [1.1.3] - 2026-08-11: Component scripts run directly again

### Fixed
- **Fourteen component scripts could not be started with `./script.sh`.** They were
  checked in as `100644`, so only `bash script.sh` worked, while the component READMEs
  describe the direct call. The executable bit is restored across `aide/`, `apparmor/`,
  `auditd/`, `boot-security/`, `kernel-hardening/`, `nftables/`, `ssh-hardening/`, and
  `ufw/`. Content is unchanged, only the file mode.

## [1.1.2] - 2026-08-09: install.sh reports the repository version, and the docs carry no private identifiers

Housekeeping release. No hardening rule, default, or access path changes -- every
change below is documentation, tooling, or repository hygiene. It is safe to
apply on a running server, and it changes nothing on one.

Two release commits (`1.1.0` and `1.1.1`) were never tagged, so the last
published release was `v1.0.1` from January 2026. This release supersedes both;
`v1.1.0` and `v1.1.1` will not receive tags of their own.

### Added
- **`install.sh --version` answers "which hardening level is running on this server?"
  correctly again.** A `VERSION` file in the repository root is now the single source of
  the project version, and `install.sh` reads it at runtime, falling back to `unknown`
  instead of failing. Until now the constant in `install.sh` reported `1.0.0` while the
  changelog stood at `1.1.1`, two releases of drift in the one number an operator quotes.
- **Bug reports and pull requests arrive in a usable shape.**
  `.github/ISSUE_TEMPLATE/` (bug report, feature request, config) and
  `.github/PULL_REQUEST_TEMPLATE.md`.

### Changed
- **A tagged release now carries the changelog section instead of the commit subjects.**
  `.github/workflows/release.yml` builds the release notes from the matching
  `CHANGELOG.md` section instead of `generate_release_notes: true`. Release commits in
  this repository carry a bare `vX.Y.Z` line as their subject, so generated notes said
  nothing the tag did not already say. The job fails loudly when a tag has no usable
  changelog section rather than publishing an empty release.
  `softprops/action-gh-release` moved from `v1` to `v2`.
- **The ShellCheck threshold now lives where it takes effect.** The `severity=warning`
  line was removed from `.shellcheckrc`. ShellCheck has no `severity` key for that file
  and discards unknown keys without a diagnostic, so the line looked like a setting and
  did nothing. Measured across all 40 scripts: 49 messages with the line present, 49 with
  a nonsense key in its place, 37 with `--severity=warning` on the command line. The
  binding threshold lives in `lint.yml` (`--severity=error`) and is now documented as such.
- **fail2ban alerts identify the host they came from, on any host.**
  `fail2ban/actions/telegram-send.sh` (2.0.0 -> 2.0.1) no longer hardcodes two specific
  hostnames in the alert prefix. It defaults to the short hostname, documents how to add
  per-host cases, and now honours an `ALERT_PREFIX` set in the secrets file; the previous
  assignment was unconditional and would have discarded one.

### Fixed
- **Four relative documentation links resolve again.** `aide/README.md` and
  `aide/docs/SETUP.md` pointed at `PROMETHEUS_INTEGRATION.md` and `FAILURE_ALERTING.md`
  inside the component directory, while both live in the repository-level `docs/`;
  `fail2ban/README.md` linked `TELEGRAM_ALERTS.md`, which is named
  `TELEGRAM_INTEGRATION.md`.
- **The `1.1.1` release is reachable from this file.** It had no link definition and no
  row in the version history table; both were added. The `1.1.0` and `1.1.1` link
  definitions now point at their commits rather than at compare ranges between tags that
  were never created, which returned 404.

### Removed
- **Two marketing drafts are no longer part of the published tree.**
  `aide/LINKEDIN_POST.md` and `aide/REDDIT_POST.md` were tracked and therefore public.
  `.gitignore` carries matching entries, but ignore rules only apply to untracked files,
  so `git check-ignore` reports them as *not* ignored, which reads like a different
  problem. The root-level copies were removed in January 2026; these two were missed.

### Security
- **The published documentation no longer carries identifiers from the author's own
  infrastructure.** None of it affected the hardening rules, and all of it was public.
  Corrected in `.shellcheckrc`, `fail2ban/actions/telegram-send.sh` and its
  documentation, `fail2ban/docs/GEOIP_FILTERING.md`,
  `nftables/docs/WIREGUARD_INTEGRATION.md`, `ufw/docs/SETUP.md`,
  `usb-defense/docs/THREE_LAYER_DEFENSE.md`, and five files under `nftables/`. Examples
  now use RFC 2606 names, the generic account `admin`, and a target derived at runtime;
  attributions read "a production gateway config". Generic references to Raspberry Pi OS
  as a supported platform are deliberately kept.
- **The remaining German documentation is readable to the audience this repository has.**
  Translated into English: the whole of `ufw/docs/` and `ufw/examples/`,
  `ufw/drop-ins/README.md`, and one code comment in
  `security-monitoring/scripts/security-log-monitor.sh`. This is not cosmetic for a
  security repository: a reader who cannot read a rule's rationale applies the rule
  without understanding it.

### Upgrade notes

None required. No firewall rule, sshd option, sysctl value, fail2ban threshold,
or installation path changed. `install.sh --version` now reports the repository
version instead of `1.0.0`; if any tooling parsed that constant, it will now see
`1.1.2`.

## [1.1.1] - 2026-07-26: Release and last-commit badges in the README

### Added
- **The repository front page shows its current release and last activity.**
  `README.md` carries release and last-commit badges.

  *(This entry was written in German in the original 1.1.1 release and has been
  translated here. Its content is unchanged.)*

## [1.1.0] - 2026-01-21: Every push to main is linted and syntax-checked

### Added
- **A broken script no longer reaches main unnoticed.** A GitHub Actions pipeline runs
  ShellCheck (`--severity=error`) and `bash -n` over every `.sh` file on each push to
  `main` and on pull requests, defined in `.github/workflows/lint.yml`.
- **A tagged release is published without manual steps.**
  `.github/workflows/release.yml` fires on `v*` tags.
- **ShellCheck runs against the same configuration everywhere.** `.shellcheckrc` sets
  `shell=bash`, `source-path=SCRIPTDIR`, `external-sources=true`, and disables SC1090
  and SC1091, which cannot resolve this repository's dynamic library paths. It also set
  `severity=warning`, which had no effect; `v1.1.2` removed that line.
- **The README states the build status.** CI status badge.

## [1.0.1] - 2026-01-20: Contribution and vulnerability reporting paths

### Changed
- **Abuse reports reach a channel that is actually monitored.**
  `CODE_OF_CONDUCT.md` moved the contact method from email to GitHub Issues.

### Added
- **A contributor knows the expected shape of a change before opening one.**
  `CONTRIBUTING.md` with development guidelines.
- **The project states which behaviour it expects.** `CODE_OF_CONDUCT.md`
  (Contributor Covenant v2.1).
- **A security finding has a documented, non-public route in.** `SECURITY.md` with the
  vulnerability reporting process.

## [1.0.0] - 2026-01-20: Initial release, aligned with the CIS Ubuntu Benchmark

First public release. A server operator can harden boot, kernel, network, access
control, and audit paths on Ubuntu Server from one repository, with each component
documented on its own and installable independently.

The `v1.0.0` tag sits on the first of three commits carrying this version message. Its
tree holds twelve of the components below: `security-monitoring/` and `usb-defense/`,
and the unified `install.sh`, are reachable from `v1.0.1` and `v1.1.0` respectively.
Until then each component installs from its own directory.

### Added

#### Core Components
- **fail2ban/**: Intrusion prevention. Six jails across `jail.local.template` and
  `fail2ban/drop-ins/`, with GeoIP filtering and Telegram alerts.
- **ssh-hardening/**: SSH hardening with secure sshd_config templates
- **nftables/**: Modern firewall with modular rule sets
- **ufw/**: Simplified firewall alternative
- **aide/**: File integrity monitoring with systemd integration
- **lynis/**: Security auditing with automation scripts
- **rkhunter/**: Rootkit detection and prevention
- **auditd/**: Kernel-level audit logging
- **apparmor/**: Mandatory access control profiles

#### Advanced Security
- **kernel-hardening/**: sysctl security configurations
- **boot-security/**: GRUB password protection
- **usb-defense/**: USB device access control
- **vaultwarden/**: Credential management integration
- **security-monitoring/**: Prometheus exporters and Grafana dashboards

#### Documentation
- **Each component can be set up without reading the others.** Component READMEs plus a
  repository README with a Quick Start guide.
- **An auditor can map the configuration to the benchmark it claims.** CIS Benchmark
  alignment documentation.
- **A failed hardening step has a documented first move.** Troubleshooting guide and
  best practices documentation.
- **The components report to Prometheus and Grafana.** Integration guide with exporters
  and dashboards.

### Security
- **The defaults are the hardened ones.** Configurations are aligned with the CIS Ubuntu
  Benchmark, and each component ships secure defaults rather than permissive ones that
  have to be tightened afterwards.
- **A single bypassed control does not open the server.** Defense-in-depth across the
  nine layers listed in this tag's README, from boot through kernel, network, and
  detection to audit.

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.2.0 | 2026-08-30 | install.sh finds every installer it lists, and the README is measured against the tree |
| 1.1.5 | 2026-08-28 | GitHub reads the licence as MIT again |
| 1.1.4 | 2026-08-28 | Editorial pass over every section, remaining scripts made executable, release titles carry a headline |
| 1.1.3 | 2026-08-11 | Fix missing executable bit on 14 scripts |
| 1.1.2 | 2026-08-09 | Publishing hygiene, single-source version, changelog-driven release notes |
| 1.1.1 | 2026-07-26 | Release and last-commit badges |
| 1.1.0 | 2026-01-21 | CI/CD pipeline with GitHub Actions (ShellCheck, automated releases) |
| 1.0.1 | 2026-01-20 | Documentation patch (CODE_OF_CONDUCT.md contact update) |
| 1.0.0 | 2026-01-20 | Initial release with 14 security components |

[Unreleased]: https://github.com/fidpa/ubuntu-server-security/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/fidpa/ubuntu-server-security/compare/v1.1.5...v1.2.0
[1.1.5]: https://github.com/fidpa/ubuntu-server-security/compare/v1.1.4...v1.1.5
[1.1.4]: https://github.com/fidpa/ubuntu-server-security/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/fidpa/ubuntu-server-security/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/fidpa/ubuntu-server-security/compare/v1.0.1...v1.1.2
[1.1.1]: https://github.com/fidpa/ubuntu-server-security/commit/e13045f
[1.1.0]: https://github.com/fidpa/ubuntu-server-security/commit/d509c22
[1.0.1]: https://github.com/fidpa/ubuntu-server-security/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/fidpa/ubuntu-server-security/releases/tag/v1.0.0
