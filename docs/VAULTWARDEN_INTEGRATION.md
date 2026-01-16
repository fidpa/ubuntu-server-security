# Vaultwarden Integration for Credential Management

**Optional feature**: Use Bitwarden CLI to manage credentials instead of plaintext `.env` files.

## Why Vaultwarden Instead of .env Files?

**Traditional approach** (plaintext secrets):
```bash
# .env.secrets
DB_PASSWORD=my_secret_password
OFFSITE_SSH_PASSWORD=another_secret
```

**Problems**:
- ❌ Plaintext secrets on disk
- ❌ No audit trail (who accessed what when?)
- ❌ Manual rotation (edit file, restart services)
- ❌ Git-unfriendly (must be .gitignored)
- ❌ No multi-device sync

**Vaultwarden approach** (encrypted vault):
```bash
# Retrieve credential on-demand
PASSWORD=$(bw get password "Database Production" --raw)
```

**Benefits**:
- ✅ **Encrypted at rest** (Vaultwarden vault encrypted)
- ✅ **Audit trail** (Vaultwarden logs access)
- ✅ **Easy rotation** (update in vault, no file edits)
- ✅ **Multi-device sync** (same secrets everywhere)
- ✅ **No plaintext on disk** (credentials only in memory)

---

## Prerequisites

1. **Vaultwarden server** running and accessible
2. **Bitwarden CLI** (`bw`) installed on the system
3. **Credentials stored** in Vaultwarden vault
4. **Master password** available (can be in `.env.secrets` or environment)

---

## Installation

### Step 1: Install Bitwarden CLI

```bash
# Download latest release
curl -fsSL https://vault.bitwarden.com/download/?app=cli&platform=linux -o bw.zip
unzip bw.zip
sudo mv bw /usr/local/bin/
sudo chmod +x /usr/local/bin/bw

# Verify installation
bw --version
```

**Alternative** (via npm):
```bash
sudo npm install -g @bitwarden/cli
```

### Step 2: Configure Vaultwarden Server

```bash
# Set custom server URL (if using self-hosted Vaultwarden)
bw config server https://vaultwarden.example.com

# Login (one-time)
bw login your-email@example.com
```

### Step 3: Store Credentials in Vault

Create items in Vaultwarden web UI or via CLI:

```bash
# Example: Add SSH password
bw create item \
  --name "Production SSH Password" \
  --login \
  --username root \
  --password "your-secure-password"
```

---

## Usage Patterns

### Pattern 1: Session Initialization (Recommended)

Initialize Vaultwarden session once per script execution:

```bash
#!/bin/bash

# Initialize Vaultwarden session
init_vaultwarden_session() {
    local master_password

    # Option A: Master password from environment
    if [[ -n "${BW_MASTER_PASSWORD:-}" ]]; then
        master_password="$BW_MASTER_PASSWORD"
    # Option B: Master password from .env.secrets (less secure)
    elif [[ -f "$HOME/.env.secrets" ]]; then
        master_password=$(grep "^VAULTWARDEN_MASTER_PASSWORD=" "$HOME/.env.secrets" | cut -d= -f2 | tr -d ' \n\r')
    else
        echo "ERROR: Master password not found" >&2
        return 1
    fi

    # Check login status
    if ! bw status 2>/dev/null | grep -q '"status":"unlocked"'; then
        bw login "your-email@example.com" --passwordenv BW_MASTER_PASSWORD --raw >/dev/null 2>&1 || true
    fi

    # Get session token
    export BW_MASTER_PASSWORD="$master_password"
    BW_SESSION=$(bw unlock --passwordenv BW_MASTER_PASSWORD --raw 2>/dev/null)
    export BW_SESSION

    if [[ -z "$BW_SESSION" ]]; then
        echo "ERROR: Failed to unlock Vaultwarden vault" >&2
        return 1
    fi

    echo "✅ Vaultwarden session initialized"
}

# Usage
init_vaultwarden_session || exit 1
```

### Pattern 2: Retrieve Credentials

```bash
# Get password by item name
PASSWORD=$(bw get password "Item Name" --raw)

# Get password by item ID (faster)
PASSWORD=$(bw get password "a1b2c3d4-..." --raw)

# Get username
USERNAME=$(bw get username "Item Name" --raw)

# Get custom field
API_KEY=$(bw get item "Item Name" | jq -r '.fields[] | select(.name=="api_key") | .value')
```

### Pattern 3: Graceful Fallback

Support both Vaultwarden and `.env` files:

```bash
#!/bin/bash

get_credential() {
    local item_name="$1"
    local env_var="$2"
    local value

    # Try Vaultwarden first (if available)
    if command -v bw >/dev/null 2>&1 && [[ -n "${BW_SESSION:-}" ]]; then
        value=$(bw get password "$item_name" --raw 2>/dev/null)
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    # Fallback: .env.secrets
    if [[ -f "$HOME/.env.secrets" ]]; then
        value=$(grep "^${env_var}=" "$HOME/.env.secrets" | cut -d= -f2 | awk '{print $1}')
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    echo "ERROR: Credential not found: $item_name / $env_var" >&2
    return 1
}

# Usage
DB_PASSWORD=$(get_credential "Database Production" "DB_PASSWORD")
```

---

## Integration with AIDE Scripts

### Example: update-aide-db.sh with Vaultwarden

```bash
#!/bin/bash
# AIDE Database Update with Vaultwarden Integration

# Initialize Vaultwarden (optional)
if command -v bw >/dev/null 2>&1; then
    init_vaultwarden_session
fi

# Get offsite backup credentials
if [[ -n "${BW_SESSION:-}" ]]; then
    # Vaultwarden method
    OFFSITE_SSH_PASSWORD=$(bw get password "Offsite Backup SSH" --raw 2>/dev/null)
else
    # Fallback: .env.secrets
    OFFSITE_SSH_PASSWORD=$(grep "^OFFSITE_SSH_PASSWORD=" .env.secrets | cut -d= -f2 | awk '{print $1}')
fi

# Use credential for offsite backup
sshpass -p "$OFFSITE_SSH_PASSWORD" rsync -avz /var/lib/aide/aide.db \
    backup@backup-server:/backups/aide/
```

---

## Security Considerations

### 1. Session Token Security

**BW_SESSION token is sensitive** - treat it like a password:

```bash
# ✅ Good: Export in same shell
export BW_SESSION="..."

# ❌ Bad: Store in file
echo "$BW_SESSION" > /tmp/session  # Never do this!
```

**Session timeout**: Vaultwarden sessions expire (default: 1 hour). Re-initialize if needed.

### 2. Master Password Storage

**Options** (from most to least secure):

1. **Environment variable** (set externally, not in script)
   ```bash
   export BW_MASTER_PASSWORD="..."
   ./script.sh
   ```

2. **Prompt user** (interactive mode)
   ```bash
   read -s -p "Master password: " BW_MASTER_PASSWORD
   ```

3. **`.env.secrets` file** (encrypted filesystem recommended)
   ```bash
   # Still better than storing individual secrets in plaintext
   VAULTWARDEN_MASTER_PASSWORD=your_master_password
   ```

4. **TPM/Hardware security** (advanced)
   - Store master password in TPM
   - Use systemd credentials

### 3. Network Security

**If using self-hosted Vaultwarden**:
- ✅ Use HTTPS (valid certificate)
- ✅ Use VPN for remote access
- ✅ Enable 2FA on Vaultwarden account
- ✅ Regular security updates

### 4. Audit Trail

**Enable Vaultwarden event logging**:
```bash
# Check recent access
bw list events --organizationid <org-id>

# Export audit log
bw export --format json --output audit.json
```

---

## Migration Guide: .env.secrets → Vaultwarden

### Step 1: Inventory Current Secrets

```bash
# List all secrets in .env.secrets
grep "^[A-Z_]*=" .env.secrets | cut -d= -f1
```

### Step 2: Create Vaultwarden Items

For each secret:
```bash
bw create item \
  --name "Secret Name" \
  --login \
  --username "" \
  --password "value_from_env"
```

### Step 3: Update Scripts

Replace:
```bash
# Old
PASSWORD=$(grep "^DB_PASSWORD=" .env.secrets | cut -d= -f2)
```

With:
```bash
# New
PASSWORD=$(bw get password "Database Production" --raw)
```

### Step 4: Test

Run scripts in dry-run mode to verify Vaultwarden integration works.

### Step 5: Remove .env.secrets

**After successful migration**:
```bash
# Backup first (just in case)
cp .env.secrets .env.secrets.backup

# Securely delete
shred -vfz -n 3 .env.secrets
```

---

## Troubleshooting

### Problem: "Session key is invalid"

**Cause**: Session token expired or invalid.

**Solution**:
```bash
# Re-initialize session
unset BW_SESSION
init_vaultwarden_session
```

### Problem: "bw: command not found"

**Cause**: Bitwarden CLI not installed.

**Solution**:
```bash
# Install via npm
sudo npm install -g @bitwarden/cli

# Or download binary
curl -fsSL https://vault.bitwarden.com/download/?app=cli&platform=linux -o bw.zip
unzip bw.zip && sudo mv bw /usr/local/bin/
```

### Problem: "Failed to decrypt"

**Cause**: Wrong master password.

**Solution**:
- Verify `BW_MASTER_PASSWORD` is correct
- Check for trailing spaces/newlines
- Try manual unlock: `bw unlock`

### Problem: "SSL certificate error"

**Cause**: Self-signed certificate or custom CA.

**Solution**:
```bash
# Add custom CA certificate
export NODE_EXTRA_CA_CERTS="/path/to/ca-certificate.crt"
```

---

## Best Practices

1. **Use session initialization once per script**
   - Don't unlock vault for every credential
   - Cache `BW_SESSION` for the script duration

2. **Implement graceful fallback**
   - Support both Vaultwarden and `.env.secrets`
   - Makes migration easier

3. **Use item IDs for performance**
   - `bw get password <id>` is faster than searching by name
   - Get ID once: `bw list items | jq -r '.[] | select(.name=="Item") | .id'`

4. **Enable 2FA on Vaultwarden account**
   - Protects against master password compromise
   - Use TOTP or hardware key

5. **Rotate master password regularly**
   - Recommended: Every 6-12 months
   - Update in all scripts after rotation

6. **Monitor Vaultwarden access logs**
   - Set up alerts for suspicious activity
   - Review access patterns regularly

---

## See Also

- [Bitwarden CLI Documentation](https://bitwarden.com/help/cli/)
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [SETUP.md](SETUP.md) - AIDE installation guide
- [BEST_PRACTICES.md](BEST_PRACTICES.md) - Production recommendations

---

**Version**: 1.0.0
**Created**: 2026-01-04
**Author**: Marc Allgeier (fidpa)
