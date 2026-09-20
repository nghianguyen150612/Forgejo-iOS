# Forgejo iOS Maintenance Guide

Operational guide for maintaining, updating, troubleshooting, and recovering Forgejo iOS installations.

## Daily Operations

### Monitoring

Check Forgejo status:

```bash
# View current process
ps aux | grep forgejo | grep -v grep

# Check port listening
netstat -tlnp | grep 3000

# Tail logs in real-time
tail -f /var/lib/forgejo-ios/logs/forgejo.log
```

### Regular Backups

Create manual backups before major changes:

```bash
BACKUP_DATE=$(date +%Y-%m-%d_%H-%M-%S)
sudo tar czf /tmp/forgejo-backup-${BACKUP_DATE}.tar.gz \
    /var/lib/forgejo-ios/data/ \
    /var/lib/forgejo-ios/repositories/ \
    /var/lib/forgejo-ios/custom/conf/
```

Store backups on external storage or in a safe location.

### Log Rotation

Forgejo logs grow continuously. Set up log rotation:

```bash
sudo tee /etc/logrotate.d/forgejo > /dev/null << 'EOF'
/var/lib/forgejo-ios/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        # Optionally signal Forgejo to reopen log files
        # killall -HUP forgejo 2>/dev/null || true
    endscript
}
EOF
```

Test the configuration:

```bash
sudo logrotate -d /etc/logrotate.d/forgejo
```

## Troubleshooting

### Forgejo Won't Start

**Symptoms**: Port 3000 not listening, process crashes immediately

**Diagnosis**:

```bash
# Check binary integrity
/var/lib/forgejo-ios/bin/forgejo --version

# Try running in foreground to see errors
/var/lib/forgejo-ios/bin/forgejo web

# Check permissions
ls -la /var/lib/forgejo-ios/
```

**Solutions**:

1. **Corrupted binary**: Run repair
   ```bash
   sudo sh install.sh
   # Option 5: Repair installation
   ```

2. **Database locked**: Another instance is running
   ```bash
   pkill -f "forgejo web"
   # Wait 5 seconds
   /var/lib/forgejo-ios/bin/forgejo web
   ```

3. **Permission denied**: Fix permissions
   ```bash
   sudo chmod 755 /var/lib/forgejo-ios/bin/forgejo
   sudo chmod 750 /var/lib/forgejo-ios/data/
   ```

4. **Port already in use**: Change configuration
   ```bash
   sudo vi /var/lib/forgejo-ios/custom/conf/app.ini
   # Change: HTTP_PORT = 3001 (or different port)
   ```

### High Memory Usage

**Diagnosis**:

```bash
# Check memory
free -h

# Monitor Forgejo process
ps aux | grep forgejo
top -p $(pgrep forgejo)
```

**Solutions**:

1. **Garbage collection**: Restart Forgejo
   ```bash
   pkill forgejo
   sleep 5
   /var/lib/forgejo-ios/bin/forgejo web &
   ```

2. **Large repository**: Optimize git
   ```bash
   cd /var/lib/forgejo-ios/repositories/user/repo.git
   git gc --aggressive
   ```

3. **Database growth**: Vacuum database
   ```bash
   sqlite3 /var/lib/forgejo-ios/data/gitea.db "VACUUM;"
   ```

### Disk Space Issues

**Diagnosis**:

```bash
# Check overall usage
df -h /var/lib/forgejo-ios

# Check per-directory usage
du -sh /var/lib/forgejo-ios/*
du -sh /var/lib/forgejo-ios/repositories/*
```

**Solutions**:

1. **Old backups**: Clean old backups
   ```bash
   ls -lat /var/lib/forgejo-ios/backup/ | tail -n +10 | awk '{print $NF}' | xargs rm
   ```

2. **Large repositories**: Archive or delete old repos
   ```bash
   # Check repo sizes
   du -sh /var/lib/forgejo-ios/repositories/*/
   ```

3. **Temporary files**: Clean temp directories
   ```bash
   sudo rm -rf /tmp/forgejo-*
   find /var/lib/forgejo-ios/data/ -name "*.tmp" -delete
   ```

### Update Failures

**Symptoms**: Update process hangs or rolls back automatically

**Diagnosis**:

```bash
# Check update status
cat /var/lib/forgejo-ios/install-state

# View recent logs
tail -100 /var/lib/forgejo-ios/logs/update.log

# Try update manually
sudo sh install.sh
# Option 2: Update Forgejo
```

**Solutions**:

1. **Network issue**: Check GitHub access
   ```bash
   curl -I https://api.github.com/repos/forgejo/forgejo/releases/latest
   ```

2. **Signature verification failed**: Retry
   ```bash
   sudo sh install.sh  # Option 2
   ```

3. **Disk space**: Free up space before retrying
   ```bash
   df -h /var/lib/forgejo-ios
   ```

### Database Corruption

**Symptoms**: Forgejo crashes on startup, SQLite errors in logs

**Diagnosis**:

```bash
# Check database integrity
sqlite3 /var/lib/forgejo-ios/data/gitea.db "PRAGMA integrity_check;"

# Backup current database
cp /var/lib/forgejo-ios/data/gitea.db /tmp/gitea.db.bak
```

**Solutions**:

1. **Recover from backup**:
   ```bash
   # If you have a recent backup
   sudo pkill forgejo
   sudo cp /tmp/forgejo-backup-*.tar.gz /tmp/
   sudo tar xzf /tmp/forgejo-backup-LATEST.tar.gz -C /
   ```

2. **Rebuild from export**: Not recommended unless backup unavailable

## Recovery Procedures

### Rollback to Previous Version

If update caused problems:

```bash
# Check available backups
ls -la /var/lib/forgejo-ios/backup/

# Manually restore previous binary
LATEST_BACKUP=$(ls -t /var/lib/forgejo-ios/backup/forgejo-*.bak | head -1)
sudo cp "${LATEST_BACKUP}" /var/lib/forgejo-ios/bin/forgejo
sudo chmod 755 /var/lib/forgejo-ios/bin/forgejo

# Verify restored binary
/var/lib/forgejo-ios/bin/forgejo --version

# Restart Forgejo
pkill forgejo
/var/lib/forgejo-ios/bin/forgejo web &
```

### Restore from Full Backup

If something goes seriously wrong:

```bash
# Stop Forgejo
sudo pkill forgejo

# Restore from backup
sudo tar xzf /tmp/forgejo-backup-YYYY-MM-DD_HH-MM-SS.tar.gz -C /

# Verify restored installation
sudo sh install.sh
# Option 3: Verify installation

# Restart
/var/lib/forgejo-ios/bin/forgejo web &
```

### Recover Deleted Repositories

Git repositories are immutable once created. If deleted:

1. **From local clone**: Re-push
   ```bash
   cd /path/to/local/repo
   git push origin main
   ```

2. **From backup**: Restore entire backup
   ```bash
   sudo tar xzf /tmp/forgejo-backup-YYYY-MM-DD.tar.gz -C /
   ```

3. **Using git reflog** (if still in local working directory)
   ```bash
   cd /var/lib/forgejo-ios/repositories/user/repo.git
   git reflog
   git reset --hard <sha>
   ```

## Performance Tuning

### Configuration Optimization

Edit `/var/lib/forgejo-ios/custom/conf/app.ini`:

```ini
# Increase performance for larger deployments
[database]
MAX_OPEN_CONNS = 50
CONN_MAX_LIFETIME = 3h

[service]
# Cache settings
DISABLE_GRAVATAR = true
ENABLE_USER_HEATMAP = false

[session]
PROVIDER = memory  # or file
PROVIDER_CONFIG = /var/lib/forgejo-ios/data/sessions

[cron]
# Disable background tasks if not needed
ENABLE_UPDATE_CHECKER = false
```

Then restart Forgejo.

### Git Optimization

For repositories with large history:

```bash
# Optimize all repositories
for repo in /var/lib/forgejo-ios/repositories/*/*.git; do
    echo "Optimizing: $repo"
    git -C "$repo" gc --aggressive
done

# Prune old objects
git -C "$repo" prune --expire=now
```

## Monitoring and Alerts

### Setup Basic Monitoring

Create a health check script:

```bash
#!/bin/sh
# /usr/local/bin/forgejo-health-check.sh

FORGEJO_BIN="/var/lib/forgejo-ios/bin/forgejo"
FORGEJO_PORT="3000"

# Check if binary exists
if [ ! -f "$FORGEJO_BIN" ]; then
    echo "CRITICAL: Forgejo binary not found"
    exit 2
fi

# Check if process is running
if ! pgrep -f "forgejo web" > /dev/null; then
    echo "CRITICAL: Forgejo process not running"
    exit 2
fi

# Check if port is listening
if ! netstat -tlnp 2>/dev/null | grep -q ":$FORGEJO_PORT"; then
    echo "CRITICAL: Forgejo not listening on port $FORGEJO_PORT"
    exit 2
fi

# Check HTTP response
if ! curl -sf http://localhost:$FORGEJO_PORT/api/v1/version > /dev/null 2>&1; then
    echo "CRITICAL: Forgejo HTTP check failed"
    exit 2
fi

echo "OK: Forgejo is running"
exit 0
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/forgejo-health-check.sh
```

Add to cron for monitoring:

```bash
sudo crontab -e
# Add: */5 * * * * /usr/local/bin/forgejo-health-check.sh >> /var/log/forgejo-health.log 2>&1
```

## Maintenance Schedule

### Daily
- Monitor logs for errors
- Check disk space
- Verify process is running

### Weekly
- Review security advisories
- Check backup integrity
- Optimize repositories (optional)

### Monthly
- Test backup restoration
- Review and clean old backups
- Update configuration if needed

### Quarterly
- Review Forgejo release notes
- Plan update timeline
- Test updates on staging device first

## Service Management

### LaunchDaemon Configuration (iOS)

Already covered in README, but for reference:

```bash
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
    <key>StartInterval</key>
    <integer>300</integer>
</dict>
</plist>
EOF
```

Load it:

```bash
sudo launchctl load /Library/LaunchDaemons/com.forgejo.plist
```

Check status:

```bash
sudo launchctl list | grep forgejo
```

## Advanced Debugging

### Enable Debug Logging

Edit `app.ini`:

```ini
[log]
MODE = file
LEVEL = DEBUG
```

Restart and check logs:

```bash
tail -f /var/lib/forgejo-ios/logs/forgejo.log
```

### Database Inspection

Query the database directly:

```bash
sqlite3 /var/lib/forgejo-ios/data/gitea.db

# List tables
.tables

# Check user count
SELECT COUNT(*) FROM user;

# Check repository count
SELECT COUNT(*) FROM repository;

# Exit
.quit
```

### Git Inspection

Check repository status:

```bash
cd /var/lib/forgejo-ios/repositories/user/repo.git

# Show git config
git config --list

# Check for corrupted objects
git fsck --full

# Count objects
git count-objects -v
```

## Support and Resources

- **Forgejo Documentation**: https://forgejo.org/docs/
- **Issue Tracker**: https://github.com/forgejo/forgejo/issues
- **Git Documentation**: https://git-scm.com/doc

## Common Questions

### Q: How often should I backup?

**A**: At minimum weekly, or before major changes. More frequently if repositories change rapidly.

### Q: Can I move Forgejo to a different device?

**A**: Yes, using backups. Restore to new device with same or higher iOS version.

### Q: What's the maximum repository size?

**A**: Limited only by available storage. Typical repositories under 1GB work smoothly.

### Q: How do I migrate from another Git service?

**A**: Use `git push --mirror` to import repositories. See Forgejo documentation for details.

### Q: Can I run Forgejo on multiple devices?

**A**: Each device should have its own independent installation. Consider using Git push/pull to sync between them manually.

## Glossary

- **SQLite**: Embedded database used by Forgejo for user/repository metadata
- **VACUUM**: SQLite operation to reclaim disk space
- **gc (garbage collection)**: Git operation to optimize repository storage
- **LaunchDaemon**: iOS service manager (autostart)
- **State file**: `/var/lib/forgejo-ios/install-state` tracking version and integrity
