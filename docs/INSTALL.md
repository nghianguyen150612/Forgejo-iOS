# Forgejo iOS Installer — Technical Documentation

## Overview

The Forgejo iOS installer is a production-quality lifecycle manager that supports installation, updates, verification, diagnostics, repair, and uninstall operations. It's designed to be safe, resilient, and preserve user data across all operations.

## Architecture

### Design Principles

1. **Data preservation first**: Never overwrite user data without explicit backup
2. **Atomic operations**: Use temporary staging and atomic moves to prevent corruption
3. **Safe defaults**: Operations default to preserving data, even on uninstall
4. **POSIX compatibility**: No bash or zsh dependencies; pure `/bin/sh`
5. **Pipe-safe**: Safe to run from `curl | sudo sh` without interactive input blocking

### Installer State Machine

```
IDLE
 ├─ Install → DOWNLOAD → VERIFY → STAGE → PRESERVE → REPLACE → SAVE_STATE → SUCCESS
 ├─ Update → CHECK → DOWNLOAD → VERIFY → BACKUP → REPLACE → HEALTH_CHECK → (SUCCESS | ROLLBACK)
 ├─ Verify → CHECK_BINARY → CHECK_DIRS → CHECK_STATE → REPORT
 ├─ Diagnostics → COLLECT → REPORT
 ├─ Repair → SCAN → FIX → REPORT
 └─ Uninstall → PROMPT → REMOVE → REPORT
```

## Directory Layout

### Canonical Installation Path

```
/var/lib/forgejo-ios/
├── bin/
│   └── forgejo                          # Forgejo executable (755)
├── data/                                # Database and user data (750)
│   ├── gitea.db
│   ├── sessions
│   └── attachments/
├── repositories/                        # Git repositories (750)
│   ├── user/
│   ├── org/
│   └── ...
├── custom/
│   ├── conf/
│   │   ├── app.ini                      # Configuration (preserved)
│   │   └── ...
│   └── templates/
├── logs/                                # Application logs (755)
│   ├── forgejo.log
│   └── forgejo-error.log
├── backup/                              # Automatic backups (750)
│   ├── forgejo-v1.20.1.bak
│   ├── forgejo-v1.20.2.bak
│   └── ...
└── install-state                        # State tracking (600)
    VERSION=v1.20.2
    RELEASE=1694745600
    INSTALL_TIME=2023-09-15T10:10:00Z
    BINARY_SHA256=abc123...
```

### Permissions Model

| Path | Owner | Mode | Purpose |
|------|-------|------|---------|
| `/var/lib/forgejo-ios` | root | 755 | Directory listing |
| `bin/forgejo` | root | 755 | Executable |
| `data/` | root | 750 | Database (restricted read) |
| `repositories/` | root | 750 | Repositories (restricted read) |
| `logs/` | root | 755 | Log directory |
| `backup/` | root | 750 | Backup storage |
| `install-state` | root | 600 | Sensitive state data |

## Installation Flow

### 1. Prerequisite Checking

```sh
├─ Root access verification (UID 0)
├─ Architecture detection (arm64, armv7)
├─ Required tools check (curl, sha256sum, tar, gzip)
├─ Optional tool check (ldid for iOS signing)
└─ iOS environment validation
```

**Failure handling**: Exit with diagnostic message, no partial state created.

### 2. Release Discovery

Downloads GitHub API metadata to find latest release:

```json
{
  "tag_name": "v1.20.2",
  "assets": [
    {
      "name": "forgejo-v1.20.2-linux-arm64",
      "browser_download_url": "..."
    }
  ]
}
```

**Failure handling**: Retry with exponential backoff; timeout after 30s.

### 3. Download & Verify

```sh
# Download sequence
1. Fetch SHA256SUMS from release
2. Fetch forgejo binary
3. Verify: sha256sum -c SHA256SUMS

# Verification failure: Delete temp files, exit with error
# Network failure: Retry up to 3 times
```

**Atomic semantics**: All or nothing; if any step fails, no installation happens.

### 4. Data Preservation

Before replacing the binary:

```sh
# If binary exists
├─ Backup current binary → backup/forgejo-$(date +%s).bak
└─ Preserve permissions (755)

# Create required directories
├─ data/          → 750 permissions
├─ repositories/  → 750 permissions
├─ custom/conf/   → 750 permissions
└─ logs/          → 755 permissions

# Never touch or modify
├─ data/* (existing database)
├─ repositories/* (existing repos)
└─ custom/conf/app.ini (existing config)
```

### 5. Atomic Replacement

```sh
# Staging
1. Download to TEMP_DIR
2. Verify checksum
3. Backup current binary (if exists)

# Atomic operation (no rollback point after this)
4. mv $TEMP_DIR/forgejo $BINARY_PATH
5. chmod 755 $BINARY_PATH
6. Save state file

# No interrupted state possible
# If `mv` fails, entire operation fails
# If state save fails, installation is complete but state not recorded
```

### 6. State File Creation

```ini
VERSION=v1.20.2
RELEASE=1694745600
INSTALL_TIME=2023-09-15T10:10:00Z
BINARY_SHA256=sha256hashvalue
```

**Security**: File permissions 600 (root-only read/write)

**Limitations**: Does not store:
- Database contents
- Configuration secrets
- API tokens
- SSH keys

## Update Lifecycle

### Update Detection

```sh
1. Load current version from install-state
2. Query GitHub API for latest version
3. Compare versions

# If current == latest
└─ Report "already up-to-date"

# If current < latest
└─ Proceed with update
```

### Update Process

```sh
DOWNLOAD → VERIFY → BACKUP → REPLACE → HEALTH_CHECK
    ↓         ↓         ↓        ↓          ↓
    │         │         │        │          └─ HTTP check on :3000
    │         │         │        └─ Atomic move to binary location
    │         │         └─ Save old binary to backup/
    │         └─ SHA256 verification required
    └─ GitHub API fetch
```

### Rollback on Startup Failure

If Forgejo fails to start with new binary:

```sh
1. Detect startup failure (timeout or HTTP not responding)
2. Restore previous binary from backup/
3. Restore previous state from backup/
4. Restart with previous version
5. Log rollback event
6. Report to user
```

**Automatic**: No user intervention required.

**Backup retention**: Keep all backed-up binaries in `backup/` indefinitely (user can manually clean).

## Verification Flow

### Binary Verification

```sh
✓ Binary exists at BINARY_PATH
✓ Binary is executable (mode & 0111)
✓ Binary checksum matches install-state
✓ Binary runs without segfault (--version)
```

### Directory Verification

```sh
✓ data/ exists and is readable
✓ repositories/ exists and is readable
✓ custom/conf/ exists
✓ logs/ exists and is writable
✓ backup/ exists
```

### State File Verification

```sh
✓ install-state file exists
✓ install-state is readable (not corrupted)
✓ install-state contains VERSION field
✓ install-state contains BINARY_SHA256 field
```

## Diagnostics Output

### Device Information

Sourced from `uname`:

```
Architecture:    arm64 (or armv7)
OS:              Darwin (iOS)
Kernel:          23.0.0 (example)
```

### Binary Information

```
Path:            /var/lib/forgejo-ios/bin/forgejo
Size:            45M (example)
Executable:      Yes
SHA256:          abc123...
Version:         v1.20.2
```

### Installation State

Parsed from `install-state`:

```
VERSION=v1.20.2
RELEASE=1694745600
INSTALL_TIME=2023-09-15T10:10:00Z
BINARY_SHA256=abc123...
```

### Storage Information

```
Data:            1.2G (du -sh output)
Repositories:    8.5G
Backups:         150M
Free space:      42G (df output)
```

## Repair Operations

Safe operations that do not modify data:

### 1. Recreate Missing Directories

```sh
for dir in data repositories custom/conf logs backup; do
    if [ ! -d "$FORGEJO_BASE_DIR/$dir" ]; then
        mkdir -p "$FORGEJO_BASE_DIR/$dir"
        log "Recreated: $dir"
    fi
done
```

### 2. Fix Permissions

```sh
chmod 755 $FORGEJO_BASE_DIR
chmod 755 $FORGEJO_BIN_DIR
chmod 750 $FORGEJO_DATA_DIR
chmod 750 $FORGEJO_REPO_DIR
chmod 755 $FORGEJO_LOG_DIR
chmod 600 $FORGEJO_STATE_FILE (if exists)
```

### 3. Validate Binary Executability

```sh
if [ -f "$FORGEJO_BINARY" ] && [ ! -x "$FORGEJO_BINARY" ]; then
    chmod 755 "$FORGEJO_BINARY"
    log "Fixed: Binary not executable"
fi
```

### Unsafe Operations (NOT performed)

- Deleting or modifying database files
- Resetting configuration (`app.ini`)
- Pruning repositories
- Clearing logs

## Uninstall Flow

### Safe Uninstall (default)

```sh
USER PROMPT: "Type 'DELETE FORGEJO DATA' to remove everything"

If NOT typed (or empty input):
├─ Remove binary
├─ Remove install-state
├─ Remove logs/
└─ KEEP: data/, repositories/, custom/conf/

If typed exactly "DELETE FORGEJO DATA":
└─ rm -rf entire FORGEJO_BASE_DIR
```

### Confirmation Semantics

- Confirmation phrase is exact and case-sensitive
- Prevents accidental complete data loss
- User must explicitly type, not just press Enter
- Clear warning before prompt

## Security Considerations

### Secrets Not Stored

The `install-state` file stores only:
- Version (public)
- Release timestamp (public)
- Installation time (non-sensitive)
- Binary SHA256 (public)

Never stored:
- Database contents
- Configuration secrets
- API tokens
- SSH keys
- Passwords
- Private keys

### File Permissions

- `install-state` is 600 (root-only)
- Binary paths are 755 (world-readable, not writable)
- Data directories are 750 (root-only)
- Backup files preserve original permissions

### Root Access

- Installer requires root to:
  - Create directories in `/var/lib/`
  - Set file permissions
  - Replace binary atomically
- Non-root users cannot:
  - Install Forgejo
  - Update to new version
  - Modify state file

### Network Security

- Only downloads from GitHub (HTTPS)
- Verifies SHA256 before using binary
- Validates release metadata structure
- Timeouts on failed downloads (30s)

## State File Format

### Structure

Plain-text key=value format (POSIX shell-compatible):

```sh
#!/bin/sh
# Not executable, but compatible with sourcing
VERSION=v1.20.2
RELEASE=1694745600
INSTALL_TIME=2023-09-15T10:10:00Z
BINARY_SHA256=abc123def456...
```

### Parsing

```sh
if [ -f "$FORGEJO_STATE_FILE" ]; then
    . "$FORGEJO_STATE_FILE"  # Source to load variables
    echo "$VERSION"           # Access VERSION
fi
```

### Atomicity

- Written with `cat > file` (atomic on most filesystems)
- Permissions set immediately after (600)
- Old state file preserved in backup

## Error Handling

### Installation Errors

| Error | Cause | Recovery |
|-------|-------|----------|
| "Checksum verification failed" | Network corruption or wrong binary | Retry download |
| "Required tool not found" | Missing curl, tar, gzip, sha256sum | Install tools |
| "This script must be run as root" | Non-root execution | Re-run with sudo |
| "Failed to fetch releases" | GitHub API down or rate-limited | Retry later |
| "Failed to download Forgejo binary" | Network failure | Retry (up to 3x) |

### Update Errors

| Error | Cause | Recovery |
|-------|-------|----------|
| "Forgejo not installed" | No binary found | Run install first |
| "Update rolled back" | Startup health check failed | Check logs, retry |
| "Checksum verification failed" | Corrupted download | Retry update |

### Repair Outcomes

- **"Installation appears healthy"** → No repairs needed
- **"Repaired N issues"** → N problems fixed (permissions, missing dirs)
- **"Checksum mismatch"** → Binary corrupted, consider reinstall

## Logging

### Log Locations

```
/var/lib/forgejo-ios/logs/
├── forgejo.log         # Standard output from Forgejo
├── forgejo-error.log   # Errors from Forgejo
└── update.log          # Installer update history (if cron-based)
```

### Installer Diagnostics

The installer outputs colored diagnostics to stdout:

```
[INFO] Checking prerequisites...
[✓] Prerequisites check passed
[INFO] Downloading Forgejo...
[✓] Download and checksum verification passed
```

### No Audit Logging

The installer does not maintain a persistent audit log of all operations. It relies on shell history (`history` command) and stdout output at runtime.

## Caveats and Limitations

### iOS-Specific

- No automatic service restart on reboot (LaunchDaemon required)
- No sandbox isolation (runs as root)
- Filesystem may have different behavior than Linux
- Some standard tools may be unavailable or behave differently

### Backup Strategy

- Automatic backups only during updates
- Manual backups require user to run `tar czf`
- No automatic cleanup of old backups (manual deletion required)

### Scalability

- Designed for single-user or small-team deployments
- Not suitable for large-scale repository hosting
- No built-in high-availability or replication

## Testing Checklist

Before production deployment:

- [ ] Install on fresh device — all directories created
- [ ] Update to new version — binary replaced, health check passes
- [ ] Rollback scenario — startup failure triggers restore
- [ ] Verify after install — all checks pass
- [ ] Repair with missing dirs — recreation works
- [ ] Uninstall safe mode — data preserved
- [ ] Uninstall full mode — all data removed with confirmation
- [ ] Checksum failure — rejected with error
- [ ] Network failure — timeout and retry
- [ ] State file corruption — graceful handling
