# Reddit Post - r/selfhosted / r/linuxadmin

**Posted**: (Draft - Created 2026-01-05)
**Flair**: Guide / Security
**Subreddits**: r/selfhosted, r/linuxadmin, r/homelab

---

## Title

AIDE Boot-Resilienz Audit found aide.db without immutable flag – created comprehensive docs

## Content

I ran a boot resiliency audit on my Ubuntu production server (AIDE file integrity monitoring) and discovered something interesting: The AIDE database (`aide.db`) had **no immutable flag**, while binary and config were protected with `chattr +i`.

**The Security Gap**:
Root processes (or malware with root access) could modify the database without AIDE detecting it. Classic bootstrapping problem in integrity monitoring.

**What I built**:
Added 8 comprehensive docs + 2 validation scripts (~3,000 lines) to the public ubuntu-server-security repo:

- **SETUP.md** – Complete installation guide (prerequisites → production)
- **TROUBLESHOOTING.md** – 9 common issues with quick fixes
- **BEST_PRACTICES.md** – Security checklists & production guidelines
- **FALSE_POSITIVE_REDUCTION.md** – Proven 99.7% reduction strategy (150 alerts → 3-5 per day)
- **BOOT_RESILIENCY.md** – systemd dependencies & emergency recovery
- **MONITORING_AIDE_ACCESS.md** – _aide group pattern for non-root monitoring
- **IMMUTABLE_BINARY_PROTECTION.md** – APT hooks & monitoring workflow
- **2 validation scripts** – Automated permission & immutable flag auditing

**Key Insights**:
- AIDE's own database needs immutable flag protection (not just binary)
- Drop-in configuration pattern reduces maintenance burden
- False-positive reduction is critical (logs, Docker, PostgreSQL WAL = 75% of noise)
- Boot-time behavior matters (systemd dependencies, timeouts)

**Tech Stack**: Pure Bash validation scripts, DIATAXIS documentation framework, production-tested patterns

GitHub: https://github.com/fidpa/ubuntu-server-security

MIT licensed. Feedback & contributions welcome!
