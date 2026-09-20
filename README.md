# Forgejo iOS

Production-quality Forgejo server for jailbroken iOS devices with complete lifecycle management: install, update, verify, diagnostics, repair, and uninstall.

## Features

- **One-command installation**: `curl -fsSL https://raw.githubusercontent.com/forgejo/forgejo/ios/install.sh | sudo sh`
- **Automatic updates** with rollback support
- **Data preservation**: Your repositories and configuration survive updates
- **Diagnostics**: Comprehensive system health checks
- **Safe uninstall**: Remove Forgejo while keeping your data
- **State management**: Track installation version and integrity
- **POSIX-compatible**: No bash or zsh dependencies
- **Safe from pipe**: Handles `stdin` safely when run from curl pipe

## Quick Start

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/forgejo/forgejo/ios/install.sh | sudo sh
```

The installer will:
1. Check device prerequisites (architecture, jailbreak, required tools)
2. Download the latest Forgejo iOS release
3. Verify the SHA256 checksum
4. Preserve any existing data
5. Move the binary to `/var/lib/forgejo-ios/bin/forgejo`
6. Create installation state file

### Launching the installer menu

If you want to re-run the installer without piping:

```bash
sudo sh install.sh
```

This shows an interactive menu:

```
1. Install Forgejo
2. Update Forgejo
3. Verify installation
4. Show diagnostics
5. Repair installation
6. Uninstall Forgejo
7. Exit
```

## Prerequisites

- **iOS version**: Any version with jailbreak access
- **Architecture**: ARM64 (A9+) or ARMv7 (32-bit devices)
- **Root access**: Jailbreak with SSH/shell access
- **Tools**: `curl`, `sha256sum`, `tar`, `gzip`
- **Optional**: `ldid` for binary signing on iOS

## Compatibility

### Supported Architectures

| Architecture | Devices | Status |
|---|---|---|
| ARM64 | iPhone 6s+, iPad Air 2+, iPad Pro | Fully supported |
| ARMv7 | iPhone 5s, earlier iPad Air, iPad mini 2-3 | Fully supported |

### iOS Versions

Forgejo iOS runs on any jailbroken iOS version with sufficient free storage (minimum 200 MB for binary, data directory).

### Device Requirements

- Minimum 512 MB available RAM
- 200 MB free storage (binary)
- 1 GB+ recommended for data and repositories

## Installation

### Standard installation (interactive)

```bash
sudo sh install.sh
```

Choose option `1` from the menu.

### Automatic installation (from curl pipe)

```bash
curl -fsSL https://raw.githubusercontent.com/forgejo/forgejo/ios/install.sh | sudo sh
```

This defaults to install mode when `stdin` is not a terminal.

### Custom installation directory

The default installation directory is `/var/lib/forgejo-ios`. To use a different location:

```bash
FORGEJO_BASE_DIR=/custom/path sudo sh install.sh
```

### Directory structure after install

```
/var/lib/forgejo-ios/
├── bin/
│   └── forgejo              # Forgejo binary
├── data/                    # User data (preserved on update)
├── repositories/            # Git repositories (preserved on update)
├── custom/
│   └── conf/
│       └── app.ini         # Forgejo configuration (preserved)
├── logs/                    # Application logs
├── backup/                  # Automatic backups during update
└── install-state            # Version and checksum tracking
```

## First Startup

After installation, start Forgejo:

```bash
/var/lib/forgejo-ios/bin/forgejo web
```

Or use your jailbreak's service manager (e.g., `launchd` on iOS):

```bash
# Create a LaunchDaemon plist for autostart
sudo tee /Library/LaunchDaemons/com.forgejo.plist > /dev/null << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.forgejo</string>
    <key>ProgramArguments</key>
    <array>
        <string>/var/lib/forgejo-ios/bin/forgejo</string>
        <string>web</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/lib/forgejo-ios/logs/forgejo.log</string>
    <key>StandardErrorPath</key>
    <string>/var/lib/forgejo-ios/logs/forgejo-error.log</string>
</dict>
</plist>
EOF
```

Then load the service:

```bash
sudo launchctl load /Library/LaunchDaemons/com.forgejo.plist
```

## Updating

### Check for updates

```bash
sudo sh install.sh
```

Choose option `2` from the menu. The installer automatically:

1. Downloads the latest version
2. Verifies the checksum
3. Backs up the current binary
4. Replaces the binary atomically
5. Updates the state file

If something goes wrong during startup, the installer automatically rolls back to the previous version.

### Automatic updates

To keep Forgejo up to date automatically, add a cron job:

```bash
sudo crontab -e
# Add: 0 2 * * * sh /var/lib/forgejo-ios/install.sh 2 >> /var/lib/forgejo-ios/logs/update.log
```

Or use a LaunchDaemon for periodic updates (recommended on iOS).

## Verification

### Verify installation integrity

```bash
sudo sh install.sh
```

Choose option `3`. This checks:

- Binary exists and is executable
- State file present
- Required directories created
- File permissions correct

### Show diagnostics

```bash
sudo sh install.sh
```

Choose option `4`. Output includes:

- Device architecture and OS version
- Binary location, size, version, and checksum
- Installation state (version, install time)
- Storage usage (data, repositories, backups, free space)

## Repair

If something is broken, run the repair command:

```bash
sudo sh install.sh
```

Choose option `5`. This safely:

- Recreates missing directories
- Fixes file permissions
- Does NOT modify data or configuration
- Does NOT reset the database

## Backup and Restore

### Manual backup

```bash
sudo tar czf /tmp/forgejo-backup-$(date +%s).tar.gz \
    /var/lib/forgejo-ios/data/ \
    /var/lib/forgejo-ios/repositories/ \
    /var/lib/forgejo-ios/custom/conf/
```

### Manual restore

```bash
sudo tar xzf /tmp/forgejo-backup-1234567890.tar.gz -C /
```

Backups are also created automatically when updating.

## Uninstall

### Remove Forgejo (keep data)

```bash
sudo sh install.sh
```

Choose option `6`. When prompted, press `Enter` (do NOT type the confirmation phrase).

This removes:
- Forgejo binary
- Launcher and service files
- Installation state
- Log files

Your data and repositories are preserved at `/var/lib/forgejo-ios/data/` and `/var/lib/forgejo-ios/repositories/`.

### Complete uninstall (remove everything)

When prompted during uninstall, type exactly:

```
DELETE FORGEJO DATA
```

This removes:
- All Forgejo files
- Binary, state, logs
- **Also removes**: Data, repositories, and configuration

## Troubleshooting

### "Checksum verification failed"

The downloaded binary does not match the published SHA256SUMS file. This usually means:

- Network corruption (try again)
- Cached old file (clear cache and retry)
- GitHub API rate limit (wait and retry)

**Solution**: Run the installer again.

### "Forgejo binary is not executable"

The binary lost execute permissions, possibly due to mount options or file system issues.

**Solution**: Run `repair installation` (option 5).

### "Required tool not found"

The installer depends on standard Unix tools. This error means one is missing or not in `$PATH`.

**Solution**: Install the missing tool:
- Debian/Ubuntu: `sudo apt-get install curl gzip tar`
- Alpine: `sudo apk add curl gzip tar`
- macOS: `brew install curl gzip tar`

### "This script must be run as root"

The installer requires root/sudo access to create directories and install files in `/var/lib/`.

**Solution**: Run with `sudo`:

```bash
sudo sh install.sh
```

### Forgejo fails to start

Check logs:

```bash
tail -f /var/lib/forgejo-ios/logs/forgejo*.log
```

Common issues:

- Port already in use (configure different port in `app.ini`)
- Database locked (check for other instances)
- Permission issues (run repair)

### Update rolled back automatically

The update process detected that Forgejo failed to start with the new binary and restored the previous version.

**Solution**: Check logs to diagnose the issue, then try updating again after fixing the problem.

## Limitations

- **No automatic service management**: Forgejo does not self-restart on reboot. Use a LaunchDaemon or other jailbreak service manager.
- **Limited sandbox**: Running as root means Forgejo has full system access. Be careful with Git hooks and plugins.
- **iOS filesystem constraints**: Some common Linux tools may behave differently or be unavailable on iOS.
- **No automatic security updates**: Check the Forgejo project for security announcements.
- **jailbreak-dependent**: Forgejo requires a working jailbreak with SSH/shell access.

## Advanced

### Configuration

Edit `/var/lib/forgejo-ios/custom/conf/app.ini` to customize:

```ini
[server]
HTTP_PORT = 3000
```

Then restart Forgejo.

### Custom installation path

```bash
FORGEJO_BASE_DIR=/custom/path sudo sh install.sh
```

### Manual binary download

If the automatic download fails:

1. Download from [Forgejo releases](https://github.com/forgejo/forgejo/releases)
2. Place in `/var/lib/forgejo-ios/bin/forgejo`
3. Make executable: `chmod 755 /var/lib/forgejo-ios/bin/forgejo`
4. Run verify: `sudo sh install.sh` → option 3

## Support

For issues or feature requests:

- [Forgejo GitHub Issues](https://github.com/forgejo/forgejo/issues)
- [Forgejo Documentation](https://forgejo.org/docs/)

## License

Forgejo iOS follows the Forgejo project license (MIT).
