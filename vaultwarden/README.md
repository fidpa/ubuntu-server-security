# Vaultwarden - Credential Management

Eliminate plaintext secrets via Bitwarden CLI with graceful fallback and sourced library pattern.

## Features

- ✅ **Sourced Bash Library** - ~300 lines, works in any script
- ✅ **No Plaintext Secrets** - Credentials encrypted in Bitwarden vault
- ✅ **Graceful Fallback** - Migration-friendly with .env compatibility
- ✅ **Examples Included** - Basic, fallback, and systemd integration
- ✅ **Production-Tested** - Running on multiple servers
- ✅ **Bitwarden CLI Integration** - Standard Bitwarden client (no custom server required)

## Quick Start

```bash
# 1. Install Bitwarden CLI
sudo snap install bw

# 2. Login and unlock
bw login
export BW_SESSION=$(bw unlock --raw)

# 3. Source library in your script
source vaultwarden-credentials.sh

# 4. Use credentials
DB_PASSWORD=$(get_credential "PostgreSQL Database Password")
```

**Full guide**: See [docs/SETUP.md](docs/SETUP.md)

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Installation, vault setup, and CLI configuration |
| [LIBRARY_USAGE.md](docs/LIBRARY_USAGE.md) | Sourced library API and examples |
| [MIGRATION.md](docs/MIGRATION.md) | Migrating from .env files to Vaultwarden |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues (session timeout, vault locked) |

## Requirements

- Ubuntu 22.04+ / Debian 11+
- Bitwarden CLI (`bw`) installed
- Vaultwarden or Bitwarden server (self-hosted or cloud)
- Bash 4.0+

## Library Functions

| Function | Purpose |
|----------|---------|
| `get_credential()` | Retrieve password from vault |
| `get_credential_with_fallback()` | Try vault, fall back to .env |
| `vault_login()` | Login and unlock vault |
| `vault_lock()` | Lock vault (security) |

## Use Cases

- ✅ **Production Scripts** - No hardcoded passwords in scripts
- ✅ **systemd Services** - Environment variables from vault
- ✅ **Backup Scripts** - Database credentials without .env files
- ✅ **Migration** - Gradual transition from plaintext to encrypted
- ✅ **Multi-Server** - Centralized credential management

## Resources

- [Bitwarden CLI Documentation](https://bitwarden.com/help/cli/)
- [Vaultwarden Project](https://github.com/dani-garcia/vaultwarden)
- [Bitwarden Official](https://bitwarden.com/)
