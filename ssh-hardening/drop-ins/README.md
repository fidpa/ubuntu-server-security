<!--
Copyright (c) 2025-2026 Marc Allgeier (fidpa)
SPDX-License-Identifier: MIT
https://github.com/fidpa/ubuntu-server-security
-->

# SSH Drop-in Overrides

Override configurations for role-specific SSH features.

## Why Drop-ins?

**Modularity**: Base config stays secure-by-default, overrides enable features only where needed

**Flexibility**: Mix and match overrides for your specific server role

**Maintainability**: Update base config without touching role-specific settings

## Available Overrides

| Override | Use Case | Features Enabled |
|----------|----------|-----------------|
| **[10-gateway.conf](10-gateway.conf)** | Network gateway, router, VPN endpoint | TCP forwarding, stream forwarding, gateway ports |
| **[20-development.conf](20-development.conf)** | Development server, workstation, Docker host | X11 forwarding, agent forwarding, TCP forwarding |
| **[30-minimal.conf](30-minimal.conf)** | Headless server, IoT device | None (base config only) |

## When to Use Each Override

### Gateway (10-gateway.conf)
✅ **Use if your server**:
- Acts as network gateway or router
- Runs VPN services (WireGuard, OpenVPN)
- Needs SSH tunneling for port forwarding
- Provides access to internal services

❌ **Don't use if**:
- Server is not internet-facing
- No VPN or tunneling requirements
- Pure application server

### Development (20-development.conf)
✅ **Use if your server**:
- Runs Docker containers with web UIs
- Needs remote GUI application access
- Hosts development tools (VS Code Remote, IDEs)
- Requires git SSH operations with forwarded keys

❌ **Don't use if**:
- Production server with no development tools
- No need for X11 or GUI applications
- Pure backend/API server

### Minimal (30-minimal.conf)
✅ **Use if your server**:
- Is headless with no GUI
- Has minimal SSH usage (admin only)
- Runs IoT/embedded workloads
- Needs maximum security (no extra features)

❌ **Don't use if**:
- You need any forwarding features
- Server hosts web services via SSH tunnels

## How to Deploy

### Option 1: Single Override
```bash
# Copy base + one override
sudo cp sshd_config.template /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo cp drop-ins/10-gateway.conf /etc/ssh/sshd_config.d/
sudo chmod 644 /etc/ssh/sshd_config.d/*.conf
```

### Option 2: Multiple Overrides (Advanced)
```bash
# Copy base + multiple overrides (settings are merged)
sudo cp sshd_config.template /etc/ssh/sshd_config.d/99-ssh-hardening.conf
sudo cp drop-ins/10-gateway.conf /etc/ssh/sshd_config.d/
sudo cp drop-ins/20-development.conf /etc/ssh/sshd_config.d/
sudo chmod 644 /etc/ssh/sshd_config.d/*.conf
```

**Note**: If multiple overrides set the same directive, the last one wins (numeric prefix determines order).

### Validate Before Restart
```bash
# CRITICAL: Always validate before restarting SSH
sudo sshd -t -f /etc/ssh/sshd_config

# If validation passes:
sudo systemctl restart ssh
```

## Custom Overrides

Create your own override for specific needs:

```bash
# Example: 40-custom.conf
sudo nano /etc/ssh/sshd_config.d/40-custom.conf
```

**Template**:
```bash
# Custom SSH Override
# Purpose: [Your specific use case]
# Features: [What this enables]

# Your settings here
AllowTcpForwarding yes
GatewayPorts clientspecified
```

**Naming Convention**:
- `10-*` - Infrastructure (gateway, router)
- `20-*` - Development (workstation, Docker)
- `30-*` - Minimal (headless, IoT)
- `40-*` - Custom (user-defined)
- `99-*` - Base config (lowest priority)

## CIS Benchmark Impact

| Override | Affected CIS Controls | Status |
|----------|----------------------|--------|
| Gateway | 5.2.3 (X11Forwarding), 5.2.23 (AllowTcpForwarding) | ⚠️ Relaxed for functionality |
| Development | 5.2.3 (X11Forwarding), 5.2.23 (AllowTcpForwarding) | ⚠️ Relaxed for functionality |
| Minimal | None | ✅ Full CIS compliance |

**Note**: Overrides intentionally relax specific controls for required functionality. All other controls remain enforced.

## Security Considerations

### Gateway Override
- **Risk**: TCP forwarding enables tunneling (could bypass firewall)
- **Mitigation**: GatewayPorts limited to `clientspecified` (not `yes`)
- **Best Practice**: Restrict to specific users with `Match User` blocks

### Development Override
- **Risk**: X11 forwarding has known security vulnerabilities
- **Mitigation**: X11UseLocalhost=yes prevents remote connections
- **Best Practice**: Use only on internal development networks

### Minimal Override
- **Risk**: None (base config is maximally secure)
- **Best Practice**: Default choice for production servers

## Troubleshooting

### "Permission denied" after adding override
```bash
# Check file permissions (must be 644 or 600)
ls -l /etc/ssh/sshd_config.d/

# Fix if needed
sudo chmod 644 /etc/ssh/sshd_config.d/*.conf
```

### SSH restart fails after adding override
```bash
# Check syntax
sudo sshd -t

# View errors
sudo systemctl status ssh
sudo journalctl -u ssh -n 50
```

### Override not taking effect
```bash
# Check if sshd_config includes drop-ins
grep "Include" /etc/ssh/sshd_config
# Should contain: Include /etc/ssh/sshd_config.d/*.conf

# If missing, add it (Ubuntu 22.04+ has this by default)
echo "Include /etc/ssh/sshd_config.d/*.conf" | sudo tee -a /etc/ssh/sshd_config
```

## See Also
- [../docs/SETUP.md](../docs/SETUP.md) - Full deployment guide
- [../docs/CIS_CONTROLS.md](../docs/CIS_CONTROLS.md) - CIS Benchmark mapping
- [../docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) - Common issues
