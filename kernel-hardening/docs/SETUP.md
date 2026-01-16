# Setup Guide

## Installation

1. Download the repository
2. Navigate to the kernel-hardening module:
   ```
   cd ubuntu-server-security/kernel-hardening
   ```
3. Run the setup script:
   ```
   sudo ./scripts/setup-kernel-hardening.sh
   ```

## What Happens During Setup

The script performs the following actions:

1. **Displays Current State** - Shows current kernel parameters before changes
2. **Creates Configuration** - Writes `/etc/sysctl.d/60-hardening.conf`
3. **Applies Changes** - Activates parameters immediately (no reboot required)
4. **Validates** - Checks that all critical parameters are set correctly
5. **Docker Check** - Verifies Docker compatibility if Docker is installed

## Post-Installation Validation

Verify the installation was successful:

```
# Quick check
sysctl fs.suid_dumpable
sysctl net.ipv4.conf.all.log_martians

# Comprehensive check
sudo sysctl -p /etc/sysctl.d/60-hardening.conf

# View all hardening parameters
cat /etc/sysctl.d/60-hardening.conf
```

## Reboot Test

To ensure persistence across reboots:

```
sudo reboot
# After reboot:
sysctl fs.suid_dumpable  # Should still be 0
sysctl net.ipv4.conf.all.log_martians  # Should still be 1
```

## Customization

Edit `/etc/sysctl.d/60-hardening.conf` to customize parameters:

```
sudo nano /etc/sysctl.d/60-hardening.conf
# After editing:
sudo sysctl -p /etc/sysctl.d/60-hardening.conf
```

## Rollback

To remove hardening:

```
sudo rm /etc/sysctl.d/60-hardening.conf
sudo sysctl --system
sudo reboot
```

## Troubleshooting

### Parameters Not Applied

If parameters don't match expected values:

1. Check for conflicting configurations:
   ```
   ls -la /etc/sysctl.d/
   ls -la /etc/sysctl.conf
   ```

2. Reapply configuration:
   ```
   sudo sysctl -p /etc/sysctl.d/60-hardening.conf
   ```

3. Check for errors:
   ```
   sudo sysctl -p /etc/sysctl.d/60-hardening.conf 2>&1 | grep -i error
   ```

### Docker Networking Issues

If Docker containers lose network connectivity after hardening:

1. Verify IP forwarding:
   ```
   sysctl net.ipv4.ip_forward  # Should be 1 for Docker
   ```

2. If disabled, edit the config:
   ```
   sudo nano /etc/sysctl.d/60-hardening.conf
   # Comment out: # net.ipv4.ip_forward = 0
   sudo sysctl -p /etc/sysctl.d/60-hardening.conf
   ```

3. Restart Docker:
   ```
   sudo systemctl restart docker
   ```
