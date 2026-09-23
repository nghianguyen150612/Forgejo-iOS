# Forgejo-iOS

[![Installer lifecycle](https://github.com/nghianguyen150612/Forgejo-iOS/actions/workflows/ios-installer.yml/badge.svg?branch=iOS)](https://github.com/nghianguyen150612/Forgejo-iOS/actions/workflows/ios-installer.yml)
[![A7 runtime build](https://github.com/nghianguyen150612/Forgejo-iOS/actions/workflows/ios-forgejo-a7-runtime.yml/badge.svg?branch=iOS)](https://github.com/nghianguyen150612/Forgejo-iOS/actions/workflows/ios-forgejo-a7-runtime.yml)

Run [Forgejo](https://forgejo.org/), a self-hosted Git service, natively on a qualified jailbroken iPad. This community port packages Forgejo **15.0.9**, SQLite, and the **go1.26.7-a7** runtime with an installer that manages the application lifecycle and preserves user data by default. It is not an upstream Forgejo support statement.

[Tiếng Việt](README.vi.md) · [Installation guide](docs/INSTALL.md) · [Maintenance](docs/MAINTENANCE.md)

## Features

- Physical iOS arm64 executable with the qualified Apple A7 runtime patch.
- Forgejo web UI, HTTP Git hosting, and SQLite storage.
- One entry point for install, update, verify, diagnostics, repair, and uninstall.
- SHA-256 verification before device signing or replacement; same-filesystem atomic binary replacement.
- Binary/launcher snapshots and automatic rollback when an update cannot start or pass HTTP health checks.
- Non-root service execution, owner-only configuration and data, and loopback HTTP.
- Optional rootful iOS LaunchDaemon mode with crash restart and boot persistence; physical enablement remains a target-device gate.
- Ordinary uninstall preserves configuration, databases, repositories, and recovery backups.

## Quick Start

Run on the supported jailbroken iPad from a terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/nghianguyen150612/Forgejo-iOS/iOS/install.sh | sudo sh
```

Choose **1. Install Forgejo**. The installer reads choices from `/dev/tty`, so piped stdin is safe. The default service account is the user invoking sudo; when invoked directly as root it defaults to `mobile`. Forgejo itself never runs as root.

After installation, open **http://127.0.0.1:3000/** on the iPad and finish Forgejo's first-run setup, including creating the administrator account. Keep SQLite and the displayed installer-managed paths. This is a loopback deployment.

```sh
sudo forgejo-ios verify
sudo forgejo-ios diagnostics
```

Before first-run setup creates the database, verification explicitly reports SQLite as not initialized. HTTP readiness at this stage verifies the setup server.

## Prerequisites

- Rootful Amethyst jailbreak with root/sudo access; stock iOS and rootless layouts are unsupported.
- POSIX `/bin/sh`; the installer and installed command require neither Bash nor Zsh.
- `curl` with HTTPS support, `sha256sum`, `ldid`, `git`, `sqlite3`, `sudo`, `nohup`, `ps`, `stat`, and ordinary Unix filesystem tools.
- An existing non-root service account and enough free space for staging, the installed binary, and retained binary snapshots. Each executable is about 100 MB; updates retain additional copies.
- Network access to GitHub and its release-download hosts, or an explicitly supplied offline release bundle.

## Compatibility

| Component | Qualified target |
| --- | --- |
| Device | iPad mini 2, `iPad4,4` |
| CPU / OS | Apple A7 / iOS 12.5.7 |
| Jailbreak | Rootful Amethyst |
| Forgejo / runtime | 15.0.9 / go1.26.7-a7 |
| Storage / access | SQLite / loopback HTTP |
| Startup | Manual lifecycle command; managed rootful LaunchDaemon is P18 device-gated |

The installer checks CPU type, device model, iOS version, root access, and tools. It cannot prove a jailbreak's distribution name from tools alone. Other platforms require their own qualification.

## Installation

The default root is `/var/lib/forgejo-ios/`, with `bin/`, `custom/conf/`, `data/`, `repositories/`, `logs/`, `backup/`, and `install-state`. Internal `run/` files track the service PID. The command is linked at `/usr/local/bin/forgejo-ios`.

The bootstrap verifies a pinned SHA-256 of its POSIX lifecycle engine. The engine downloads the pinned `v1.0.0-ios` release, verifies its binary against `SHA256SUMS` and the qualified A7 artifact hash, signs a staged working copy with `ldid`, and starts it as the service account. It writes a new `app.ini` only if one does not exist.

For review before execution, download the bootstrap to a file and inspect it. For offline installation, custom paths, account selection, permissions, and recovery, see [docs/INSTALL.md](docs/INSTALL.md). Existing manually managed installations need an explicit path/ownership review; the installer does not silently migrate them.

## Updating

```sh
sudo forgejo-ios update
sudo forgejo-ios verify
```

Or select **2. Update Forgejo** in the menu. A failed startup or HTTP check restores the previous binary, launcher, installer state, permissions, and running/stopped state. The PID changes when a running service is restarted.

The current release line is frozen: update safely reinstalls the qualified `15.0.9` artifact. It does **not** select arbitrary upstream versions. A future release requires a new artifact qualification and installer pin. Binary rollback cannot reverse database migrations; cross-version updates are refused. Take a stopped-files data backup before maintenance.

## Service and Uninstall

```sh
sudo forgejo-ios start
sudo forgejo-ios stop
sudo forgejo-ios restart
sudo forgejo-ios service install
sudo forgejo-ios service status
sudo forgejo-ios service stop
sudo forgejo-ios service start
sudo forgejo-ios service restart
sudo forgejo-ios service uninstall
sudo forgejo-ios repair
sudo forgejo-ios uninstall
```

`service install` atomically writes and validates
`/Library/LaunchDaemons/com.forgejo.ios.plist`, loads it through `launchctl`,
and runs the daemon as the configured non-root service account. The plist uses
`RunAtLoad`, `KeepAlive`, a fixed `GOMAXPROCS=1` A7 environment, and only
non-secret paths. `service stop` unloads the daemon and removes stale PID state;
`service uninstall` removes only the managed plist and preserves the Forgejo
configuration, database, repositories, logs, and backups. Plain `start`, `stop`,
and `restart` refuse to run while the managed LaunchDaemon plist exists, so a
manual launcher cannot race launchd's `KeepAlive`. Update and repair operations
quiesce a loaded LaunchDaemon before touching the binary and restore launchd
supervision after validation. Before any service command can touch
`/Library/LaunchDaemons`, `sudo -n id` must succeed.
The host fixtures validate this path; enabling it on the qualified iPad still
requires the disposable P18 reboot and crash-recovery gate.

Repair can recreate directories, restore managed permissions, restart the service, and recover a missing binary from a matching snapshot. It never resets configuration, repairs database contents, or deletes data.

Ordinary uninstall stops Forgejo, unloads and removes the managed LaunchDaemon if present, and removes its executable, lifecycle launcher, logs, and installer state. It keeps `data/`, `repositories/`, `custom/conf/`, and recovery backups. Reinstall can reuse this data.

To also delete persistent data and recovery backups:

```sh
sudo forgejo-ios uninstall --purge
```

Deletion requires typing **`DELETE FORGEJO DATA`** on `/dev/tty`. There is no unattended confirmation flag. Deleted data requires an external backup to recover.

## Backup

Installer rollback snapshots protect executables and launcher state, **not user data**. Follow [docs/BACKUP.md](docs/BACKUP.md) for a stopped-files backup of SQLite, repositories, and configuration; use the lifecycle command above to stop/start an installer-managed deployment. Review the backup tool's older launcher interface before combining it with this layout. Encrypt backups separately and keep a copy off the device.

## Troubleshooting

Run `sudo forgejo-ios diagnostics` for device, checksum, runtime, configuration status, SQLite integrity, owned PID, port, HTTP status, storage sizes, and free space. It does not dump configuration, log contents, database rows, passwords, tokens, or keys.

- **Download/checksum failure:** no binary replacement occurs. Confirm release availability and retry; never bypass verification.
- **Signing/startup failure:** review owner-only `logs/service.log` locally. Do not publish unredacted logs.
- **Port occupied:** stop the conflicting service or choose a different unprivileged loopback port in `app.ini`, then restart.
- **Missing binary:** run repair. A backup must match the installed checksum; otherwise manual recovery is required.
- **Interrupted operation:** preserve its snapshot and inspect `.installer-lock` before removing a stale lock. See [maintenance recovery](docs/MAINTENANCE.md).

## Known limitations

- Qualification is limited to the compatibility matrix above; no App Store, stock iOS, simulator, or rootless LaunchDaemon deployment is supported.
- The P18 LaunchDaemon implementation is host-validated, but boot persistence,
  crash recovery, and SQLite/HTTP health after reboot remain unproven until the
  target device accepts the required non-interactive root check.
- Loopback HTTP and disabled SSH are enforced by managed config checks. Public exposure requires a separate security design.
- Updates briefly stop the service and use two successful `/api/healthz` responses plus process ownership checks; they are not zero-downtime deployments.
- `SIGKILL`, power loss, full-storage failures during recovery, or an unresponsive process can require manual recovery. The installer does not force-kill Forgejo.
- Repair changes managed directories and executable/config file permissions, not every file inside repositories or databases.
- Release checksums provide integrity relative to the trusted installer/release source; they are not independently authenticated publisher signatures.
- Runtime qualification does not establish indefinite uptime, battery, thermal, or capacity guarantees.

Build evidence: [PORTING_IOS.md](PORTING_IOS.md). Frozen artifacts: [RELEASE.md](RELEASE.md). Security: [docs/SECURITY.md](docs/SECURITY.md). Documentation index: [docs/README.md](docs/README.md).

## License

Forgejo is licensed under [GNU GPL v3.0 or later](LICENSE). Versions before v9.0 used the MIT license. See [CONTRIBUTING.md](CONTRIBUTING.md) for upstream contribution guidance.
