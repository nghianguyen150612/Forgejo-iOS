# Forgejo iOS installation and lifecycle

The qualified target is `iPad4,4` / Apple A7 / iOS 12.5.7 / rootful Amethyst. The frozen release contains Forgejo 15.0.9 and go1.26.7-a7. This installer adds a POSIX lifecycle layer; it does not change Forgejo source, runtime patches, or the existing Bash launcher used by earlier manual deployments.

## Entry points and architecture

```sh
curl -fsSL https://raw.githubusercontent.com/nghianguyen150612/forgejo-ios/ios/install.sh | sudo sh
```

`install.sh` downloads `scripts/ios/install-forgejo.sh` over HTTPS to a private temporary directory, verifies the engine's SHA-256 embedded in the bootstrap, and invokes `/bin/sh` with a file argument. Both scripts use POSIX shell only. All interactive reads use `/dev/tty`; nothing consumes menu input from the download pipe. An explicit command works without a terminal except `uninstall --purge`.

The menu provides Install, Update, Verify, Diagnostics, Repair, Uninstall, and Exit. Installation persists the verified engine as `bin/manager.sh`, generates `bin/forgejo-ios`, and links the default deployment at `/usr/local/bin/forgejo-ios`. Local lifecycle commands work offline. Updating also copies the manager used for that transaction; an already-installed manager does not silently fetch new installer code. Re-run the latest bootstrap to adopt a newly published installer.

```text
device / account / path checks
  -> installation lock and same-filesystem temporary directory
  -> download and checksum verification
  -> device signing and non-root version probe
  -> snapshot binary, launcher, state, permissions and running state
  -> stop -> atomic binary rename -> launch -> HTTP health
  -> atomically write install-state
```

Errors before the snapshot do not replace installed files. Errors after the transaction begins trigger rollback. A directory lock serializes mutating commands; verify/diagnostics are read-only and can observe a transaction in progress.

## Prerequisites and service account

Install `curl`, `sha256sum`, `ldid`, `git`, `sqlite3`, `sudo`, `nohup`, `ps`, `stat`, and standard filesystem tools through the device's package manager. Use a working HTTPS trust store. The default installation requires root. A non-root custom deployment is supported only in a dedicated root owned by that user; it reports that root access was not verified.

The service account defaults to `SUDO_USER`, or `mobile` for a direct root invocation. It must already exist and have a nonzero UID. To select an existing dedicated account, download the bootstrap and run:

```sh
sudo env FORGEJO_IOS_USER=forgejo sh install.sh install
```

The installer never enables Forgejo's unsafe root mode. It runs Forgejo through `sudo -u` with a clean environment, a fixed PATH, `HOME` inside the data directory, and `GOMAXPROCS=1`. This retains the conservative A7 launcher policy. Boot persistence is opt-in: `forgejo-ios service install` creates the managed rootful LaunchDaemon described below; ordinary installation remains manual until that command is run.

## Directory layout and ownership

```text
/var/lib/forgejo-ios/
├── bin/
│   ├── forgejo
│   ├── manager.sh
│   └── forgejo-ios
├── custom/conf/app.ini
├── data/
├── repositories/
├── logs/
├── backup/transaction.XXXXXX/
├── run/forgejo.pid
└── install-state
```

| Path | Owner / mode for a root-managed installation |
| --- | --- |
| Installation root | root / 711, traversable by service account |
| `bin/`, executable and launchers | root / 755 |
| `backup/`, transaction snapshots | root / 700; copied files retain metadata |
| `install-state` | root / 600 |
| `custom/`, `custom/conf/`, `data/`, `repositories/`, `logs/`, `run/` | service account / 700 |
| `custom/conf/app.ini` | service account / 600 |
| `logs/service.log` | service account / 600; opened after dropping privileges |
| `logs/forgejo.log`, `logs/launcher.log` | service account / 600 |

For a user-owned deployment, the manager owns all entries. Repair adjusts only managed entries, not arbitrary contents recursively. Symlinks at managed paths or inside the installation-root ancestry are rejected, except the standard system `/var` alias. Spaces and shell metacharacters are not allowed in custom roots. The final directory name must be `forgejo-ios`, `forgejo-ios-<name>`, or `runtime`.

Existing `app.ini`, data, and repositories are never replaced by the installer. Existing config must use the selected root's absolute paths, SQLite, loopback HTTP, disabled SSH, and a valid non-root `RUN_USER` matching the config owner. There is no automatic migration from an earlier manual layout.

## First startup

Installation creates `app.ini` only when absent. Defaults are SQLite at `data/forgejo.db`, repositories at `repositories/`, disabled SSH, HTTP on `127.0.0.1:3000`, and file logs. Complete setup in the iPad browser. Before setup, `/api/healthz` checks the setup server and no database may exist. After setup, verify checks SQLite integrity read-only and the health route also checks the application database/cache.

```sh
sudo forgejo-ios verify
sudo forgejo-ios diagnostics
sudo forgejo-ios stop
sudo forgejo-ios start
sudo forgejo-ios restart
```

The PID file is checked against the expected executable, arguments, and UID before signaling. An exited PID is cleared; a PID belonging to another process is refused. An untracked process using this executable blocks startup. Shutdown sends SIGTERM and waits up to 30 seconds; it does not send SIGKILL. Startup allows 60 polling attempts, with bounded curl timeouts, and requires HTTP 200 from `/api/healthz` twice with the owned process alive. This can take several minutes on a slow/unhealthy device.

## Persistent LaunchDaemon mode

Persistent mode is implemented only for the rootful qualified deployment and
remains device-gated until the P18 reboot/crash checks pass. It does
not change Forgejo source, the Go runtime, the release binary, authentication,
or the SQLite format. The installer manages exactly:

```text
/Library/LaunchDaemons/com.forgejo.ios.plist
```

The plist is written to a same-directory temporary file, validated as XML/plist,
set to mode `644`, and loaded through `launchctl`. Its program arguments invoke
the installed manager's foreground `service-run` launcher, which then executes
the Forgejo binary as the configured non-root account. `RunAtLoad` starts it
after launchd becomes available and `KeepAlive` lets launchd recover a crashed
process. The launch environment contains only fixed path, home, and
`GOMAXPROCS=1` values; it does not carry passwords, tokens, or private keys.

Use:

```sh
sudo -n id
sudo forgejo-ios service install
sudo forgejo-ios service status
sudo forgejo-ios service stop
sudo forgejo-ios service start
sudo forgejo-ios service restart
sudo forgejo-ios service uninstall
```

`service install` requires the non-interactive root check before it touches
`/Library/LaunchDaemons`. It also checks the binary checksum, config and state
permissions, owner-only runtime directories, and loopback configuration.
`service stop` unloads the job before waiting for Forgejo and removes stale PID
state without sending SIGKILL. `service uninstall` stops/unloads the job and
removes only the plist; it never removes application data or configuration.

Managed logs are below `logs/`: `forgejo.log` captures launchd standard output,
`launcher.log` captures launcher/error output and startup/PID records, and
`service.log` records install/start/stop/restart/shutdown control events. Log
and state files are mode `600`; the service status surface prints only fixed
health/version/runtime facts and never config contents or credentials.

## Release verification and signing

The default release URL is:

```text
https://github.com/nghianguyen150612/forgejo-ios/releases/download/v1.0.0-ios/
```

The engine downloads `forgejo-ios` and `SHA256SUMS`. It accepts exactly one well-formed, path-free checksum entry for the executable, writes a selected checksum file in staging, and runs:

```sh
sha256sum -c SHA256SUMS
```

Other manifest assets are not downloaded or traversed. Duplicate, missing, malformed, or mismatched entries fail closed. The frozen A7 binary must additionally match:

```text
19dd23e3a78d13e1beb18a1e475d7b1a2c75959a0718d958905a0a540400218a
```

This prevents accidentally installing the separate generic iOS build. A new qualified binary requires a reviewed installer pin change. The trusted bootstrap/engine and GitHub HTTPS delivery are the trust boundary; SHA256SUMS is not a detached publisher signature.

Only after verification does `ldid` sign the staged copy with `com.apple.private.security.no-container`. The installed checksum consequently differs from the release checksum. `install-state` contains exactly four non-secret fields:

```text
VERSION=15.0.9
RELEASE=v1.0.0-ios
INSTALL_TIME=<UTC timestamp>
BINARY_SHA256=<device-signed executable checksum>
```

State is parsed as data, never sourced as shell. No password, API token, private key, database content, or config dump is stored there.

## Overrides and offline installation

| Variable | Meaning |
| --- | --- |
| `FORGEJO_IOS_ROOT` | Dedicated root; default `/var/lib/forgejo-ios`, or the installed manager's own root |
| `FORGEJO_IOS_USER` | Existing non-root user for a new config; existing `RUN_USER` remains authoritative |
| `FORGEJO_IOS_PORT` | Initial loopback HTTP port, default 3000; existing config is preserved |
| `FORGEJO_IOS_RELEASE` | Explicit release tag, default `v1.0.0-ios`; qualified artifact hash still enforced |
| `FORGEJO_IOS_BUNDLE` | Local directory containing `forgejo-ios` and `SHA256SUMS`; identical verification/signing gates |

Example using the checked-out engine and a downloaded release bundle:

```sh
sudo env FORGEJO_IOS_ROOT=/var/lib/forgejo-ios-test \
  FORGEJO_IOS_USER=mobile FORGEJO_IOS_PORT=39160 \
  FORGEJO_IOS_BUNDLE=/path/to/verified-release \
  sh scripts/ios/install-forgejo.sh install
sudo /var/lib/forgejo-ios-test/bin/forgejo-ios verify
```

Custom roots do not install a global command link. Offline mode does not make a non-iOS executable or unqualified release acceptable.

## Updates and rollback

Run `sudo forgejo-ios update`. The snapshot holds the executable, manager, command wrapper, install-state, managed permissions/owners, and prior running state. The old binary remains under `backup/transaction.XXXXXX/`. Replacement uses `mv` from a staging directory on the same filesystem.

Only after health succeeds is the new state committed. A download, checksum, or signing failure leaves the existing service and executable in place. A later failure or catchable INT/TERM/HUP restores previous files atomically, restores permissions, and restarts the old service only if it was previously running. It never reinstates a stale PID number. Failed recovery returns failure and reports the preserved snapshot for manual intervention.

The installer accepts only the frozen 15.0.9 A7 artifact. It can reinstall that release but cannot perform arbitrary upstream upgrades. Binary rollback does not undo database migrations or application writes. Take a separate stopped-files data backup before any future qualified release transition.

Snapshots are not pruned automatically. Monitor storage and retain enough space for staging plus rollback. Power loss and SIGKILL cannot run shell traps; inspect the lock, snapshot, and state as described in [MAINTENANCE.md](MAINTENANCE.md).

## Diagnostics, repair, uninstall

Diagnostics prints device identity, architecture, OS, jailbreak/tool context, validated version, checksum status, Go version, config status, read-only SQLite integrity result, verified PID, port, numeric HTTP status, storage sizes, and free space. It suppresses raw config/database errors and never dumps logs or secret fields. Runtime probing is skipped if the binary fails its installed checksum.

Repair recreates managed directories, restores managed permissions, restarts Forgejo, and restores a missing binary only from a snapshot matching `BINARY_SHA256`. It does not replace a present corrupt binary, reset config, edit database contents, or delete data. Normal Forgejo startup can write application data; that is not database repair.

`uninstall` stops the owned process and removes the binary, manager, wrapper, default command link, logs, PID, and state. It retains configuration/data/repositories/backups. `uninstall --purge` additionally requires the exact phrase `DELETE FORGEJO DATA` on `/dev/tty` before deleting retained directories. Failed/missing confirmation leaves them intact; ordinary application removal has already occurred. There is no built-in undo.

## Validation

CI runs ShellCheck, `sh -n`, LaunchDaemon plist schema validation, the bootstrap engine-pin check, and `sh scripts/ios/install-forgejo.sh --self-test`. The isolated fixtures cover install, verify, update, failed-health rollback, prior running/stopped state, restored permissions/files, checksum refusal, missing-binary repair, uninstall, data preservation, managed-symlink refusal, and the service install/load/start/status/stop/restart/unload path. Signing/process/HTTP/launchd fixtures are mocks, not physical-device evidence. See [MAINTENANCE.md](MAINTENANCE.md) for device acceptance and release procedure.
