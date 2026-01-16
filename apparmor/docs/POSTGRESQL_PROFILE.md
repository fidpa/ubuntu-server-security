# PostgreSQL 16 AppArmor Profile Reference

Detailed documentation for the PostgreSQL 16 AppArmor profile.

## Profile Overview

| Attribute | Value |
|-----------|-------|
| **Target Binary** | `/usr/lib/postgresql/16/bin/postgres` |
| **Profile Name** | `postgresql` |
| **Flags** | `attach_disconnected` |
| **Ubuntu Version** | 22.04 LTS, 24.04 LTS |
| **PostgreSQL Version** | 16.x |

## Abstractions Included

The profile includes these standard AppArmor abstractions:

| Abstraction | Purpose |
|-------------|---------|
| `base` | Common system access patterns |
| `nameservice` | DNS, NSS, user/group lookups |
| `ssl_certs` | SSL certificate access |

## Capabilities

| Capability | Purpose | CIS Relevant |
|------------|---------|--------------|
| `chown` | Change file ownership | Yes |
| `dac_override` | Bypass DAC for admin operations | Yes |
| `dac_read_search` | Directory traversal | Yes |
| `fowner` | File owner operations | Yes |
| `fsetid` | Preserve set-id bits | No |
| `kill` | Send signals to worker processes | No |
| `setgid` | Change GID for pg_ctl | Yes |
| `setuid` | Change UID for pg_ctl | Yes |
| `sys_resource` | Set resource limits | No |

## File Access Rules

### Binaries and Libraries

| Path | Permission | Notes |
|------|------------|-------|
| `/usr/lib/postgresql/16/bin/*` | rix | All PG binaries |
| `/usr/lib/postgresql/16/lib/**` | mr | Shared libraries |
| `/usr/share/postgresql/16/**` | r | Shared data |
| `/usr/share/postgresql-common/**` | r | Common scripts |

### Configuration

| Path | Permission | Notes |
|------|------------|-------|
| `/etc/postgresql/16/main/` | r | Config directory |
| `/etc/postgresql/16/main/**` | r | All config files |
| `/etc/ssl/certs/**` | r | SSL certificates |
| `/etc/ssl/private/**` | r | SSL private keys |

### Data and Logs

| Path | Permission | Notes |
|------|------------|-------|
| `/var/lib/postgresql/16/main/**` | rwk | Data directory |
| `/var/log/postgresql/**` | rw | Log files |
| `/var/run/postgresql/**` | rwk | PID and sockets |
| `/run/postgresql/**` | rwk | Runtime files |

### Temporary Files

| Path | Permission | Notes |
|------|------------|-------|
| `/tmp/**` | rwk | Temp operations |
| `/var/tmp/**` | rwk | Persistent temp |

### System Access

| Path | Permission | Notes |
|------|------------|-------|
| `/lib/x86_64-linux-gnu/**` | mr | System libraries |
| `/usr/lib/x86_64-linux-gnu/**` | mr | User libraries |
| `/usr/share/locale/**` | r | Localization |
| `/usr/share/zoneinfo/**` | r | Timezone data |

### Proc/Sys Filesystem

| Path | Permission | Purpose |
|------|------------|---------|
| `@{PROC}/@{pid}/stat` | r | Process stats |
| `@{PROC}/meminfo` | r | Memory info |
| `@{PROC}/cpuinfo` | r | CPU info |
| `/sys/devices/system/cpu/**` | r | CPU topology |

## Network Rules

| Protocol | Type | Purpose |
|----------|------|---------|
| `inet stream` | TCP/IPv4 | Client connections (5432) |
| `inet6 stream` | TCP/IPv6 | IPv6 clients |
| `unix stream` | Unix socket | Local connections |

## Deny Rules (Security)

These paths are explicitly denied to prevent exploitation:

| Denied Path | Reason |
|-------------|--------|
| `/bin/**` | Prevent shell execution |
| `/sbin/**` | Prevent system binaries |
| `/usr/bin/**` | Prevent user binaries |
| `/usr/sbin/**` | Prevent admin binaries |
| `/home/**` | Prevent user data access |
| `/root/**` | Prevent root home access |

**Security Impact**: Even if PostgreSQL is compromised via SQL injection, attackers cannot:
- Execute shell commands (`/bin/bash`)
- Access user home directories
- Run system administration tools

## Customization Examples

### Custom Data Directory

```
# Add to profile
/data/postgresql/16/main/** rwk,
```

### Tablespace Support

```
# Add tablespace paths
/mnt/ssd/postgresql/** rwk,
/mnt/hdd/postgresql/** rwk,
```

### pgBackRest Integration

```
# Backup tool access
/var/lib/pgbackrest/** rw,
/var/log/pgbackrest/** rw,
/usr/bin/pgbackrest rix,
```

### pg_stat_statements Extension

```
# Shared preload library
/usr/lib/postgresql/16/lib/pg_stat_statements.so mr,
```

### PostGIS Extension

```
# Geospatial library
/usr/lib/postgresql/16/lib/postgis*.so mr,
/usr/share/postgresql/16/contrib/postgis*/** r,
```

## Troubleshooting

### Profile Won't Load

```bash
# Check syntax
sudo apparmor_parser -p /etc/apparmor.d/usr.lib.postgresql.16.bin.postgres

# Common issues:
# - Missing abstractions
# - Syntax errors in paths
# - Invalid capabilities
```

### Permission Denied in Logs

```bash
# Check what's being denied
sudo dmesg | grep -i apparmor | tail -20

# Example output:
# apparmor="DENIED" operation="open" profile="postgresql" name="/some/path"

# Add the path to profile:
/some/path r,
```

### Extensions Don't Load

```bash
# Check which .so file is needed
sudo dmesg | grep -i "apparmor.*\.so"

# Add to profile:
/usr/lib/postgresql/16/lib/extension_name.so mr,
```

## CIS Benchmark Alignment

| Control | Requirement | Profile Implementation |
|---------|-------------|------------------------|
| 1.6.1.3 | All profiles in enforce/complain | Profile provided |
| 1.6.1.4 | Profiles should be enforcing | ENFORCE mode supported |
| 5.2.x | Restrict service access | Deny rules implemented |
| 5.4.x | Limit capability usage | Minimal capabilities |

## Version Compatibility

| PostgreSQL | Profile Status | Notes |
|------------|----------------|-------|
| 16.x | ✅ Tested | Primary target |
| 15.x | ⚠️ Untested | Adjust paths |
| 14.x | ⚠️ Untested | Adjust paths |

For other versions, change the version number in paths:
```
/usr/lib/postgresql/16/  →  /usr/lib/postgresql/15/
```
