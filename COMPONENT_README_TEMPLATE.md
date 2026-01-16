# Component Name

One-line description (what it does + key differentiator).

## Features

- ✅ **Key Feature 1** - Brief explanation
- ✅ **Key Feature 2** - Brief explanation
- ✅ **Key Feature 3** - Brief explanation
- ✅ **Key Feature 4** - Brief explanation
- ✅ **Key Feature 5** - Brief explanation

## Quick Start

```bash
# 1. Install
sudo apt install package-name

# 2. Basic configuration
sudo cp component/config.template /etc/component/config

# 3. Enable
sudo systemctl enable --now component.service
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation and configuration guide |
| [KEY_DOC_1.md](docs/KEY_DOC_1.md) | Specific topic documentation |
| [KEY_DOC_2.md](docs/KEY_DOC_2.md) | Another important topic |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and solutions |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- systemd (for service management)
- Optional: Additional dependencies if needed

## Use Cases

- ✅ **Use Case 1** - When to use this component
- ✅ **Use Case 2** - Another scenario
- ✅ **Use Case 3** - Additional use case

---

## Template Usage Guidelines

**Keep**:
- One-line description (scannable)
- Features with ✅ checkmarks (5-7 max)
- Quick Start minimal (3-5 commands + link)
- Documentation table (4-6 key docs)

**Avoid**:
- Long "Overview" or "What It Does" sections (move to docs/OVERVIEW.md)
- Inline bash code >10 lines (move to docs/SETUP.md)
- Copyright headers (MIT license covers it)
- Redundant info already in main README.md

**Structure Priority**:
1. Features (what you get)
2. Quick Start (how to start)
3. Documentation (where to learn more)
4. Requirements (what you need)
5. Use Cases (when to use)
