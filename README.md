# Forgejo iOS

[![iOS Forgejo production build](https://github.com/nghianguyen150612/forgejo-ios/actions/workflows/ios-forgejo-production.yml/badge.svg?branch=ios)](https://github.com/nghianguyen150612/forgejo-ios/actions/workflows/ios-forgejo-production.yml)
[![iOS A7 runtime build](https://github.com/nghianguyen150612/forgejo-ios/actions/workflows/ios-forgejo-a7-runtime.yml/badge.svg?branch=ios)](https://github.com/nghianguyen150612/forgejo-ios/actions/workflows/ios-forgejo-a7-runtime.yml)
[![Release](https://img.shields.io/github/v/tag/nghianguyen150612/forgejo-ios?filter=v1.0.0-ios&label=release)](https://github.com/nghianguyen150612/forgejo-ios/releases/tag/v1.0.0-ios)
[![License](https://img.shields.io/github/license/nghianguyen150612/forgejo-ios)](LICENSE)

Forgejo iOS is a narrowly qualified port of [Forgejo](https://forgejo.org/) that runs natively on a jailbroken iPad.

[Tiếng Việt](README.vi.md)

## Overview

Forgejo iOS packages Forgejo `15.0.9` as a physical iOS `arm64` binary with an Apple A7-compatible Go runtime, a manual service launcher, and documented backup and security procedures.

The project is intended for operators and developers who want a small self-hosted Git server on the validated iOS target. It keeps Forgejo's web interface, Git repository workflow, and SQLite-backed deployment model while documenting the extra runtime, signing, and jailbreak boundaries needed on iOS.

This is not an upstream Forgejo support statement and it does not expand Forgejo's general platform support matrix.

## Features

- ✓ Native iOS `arm64` build for physical devices.
- ✓ Forgejo web interface served from the iPad.
- ✓ Git repository hosting through Forgejo's HTTP workflow.
- ✓ SQLite backend for the qualified single-device deployment.
- ✓ Backup and restore workflow with integrity checks.
- ✓ Manual service launcher for start, status, restart, and stop.
- ✓ Apple A7 runtime compatibility through `go1.26.7-a7`.
- ✓ Release metadata, checksum, provenance, and security boundary documentation.

## Supported Device

The v1.0.0 release is qualified only for this platform:

```text
Device:    iPad4,4
CPU:       Apple A7
OS:        iOS 12.5.7
Jailbreak: Rootful Amethyst
Forgejo:   15.0.9
Runtime:   go1.26.7-a7
```

Other iOS devices, iOS versions, jailbreak layouts, CPUs, and background-service models require their own validation before use.

## Quick Start

1. Obtain the `v1.0.0-ios` release artifact and metadata.
2. Verify `SHA256SUMS`, then transfer the executable to the jailbroken iPad.
3. Configure an owner-only runtime tree with loopback HTTP and SQLite paths.
4. Start Forgejo with `scripts/ios/run-forgejo.sh` and access it at the configured loopback URL.

## Installation

Start with the release bundle described in [`RELEASE.md`](RELEASE.md). The bundle contains the iOS executable, `build-info.txt`, and `SHA256SUMS`.

1. Obtain the `v1.0.0-ios` release artifact.
2. Verify the artifact before transfer:

   ```sh
   sha256sum -c SHA256SUMS
   ```

3. Copy the executable and support scripts to an owner-only directory on the jailbroken iPad.
4. Sign the device-side working copy with `ldid` and the documented no-container entitlement.
5. Create `custom/conf/app.ini`, `data/`, `repositories/`, and `logs/` inside a dedicated runtime root.
6. Keep configuration, database files, launcher state, and logs owner-only.

See [`docs/INSTALL.md`](docs/INSTALL.md) for the complete operator-focused installation guide.

## Usage

Start Forgejo with the launcher and an explicit configuration path:

```sh
export FORGEJO_IOS_BINARY=/var/nghianguyen/forgejo-ios/<release>/bin/forgejo-ios
export FORGEJO_IOS_SERVICE_DIR=/var/nghianguyen/forgejo-ios/<release>/runtime
export FORGEJO_IOS_DEVICE_MODEL=iPad4,4
export FORGEJO_IOS_DARWIN_RELEASE=18.7.0

scripts/ios/run-forgejo.sh start "$FORGEJO_IOS_BINARY" \
  --config "$FORGEJO_IOS_SERVICE_DIR/custom/conf/app.ini"
```

Then verify the service locally on the iPad:

```sh
scripts/ios/run-forgejo.sh status "$FORGEJO_IOS_BINARY"
curl --fail http://127.0.0.1:<port>/
sqlite3 "$FORGEJO_IOS_SERVICE_DIR/data/forgejo.db" 'PRAGMA integrity_check;'
```

Stop the service before backup, restore, upgrade testing, or filesystem maintenance:

```sh
scripts/ios/run-forgejo.sh stop "$FORGEJO_IOS_BINARY"
```

## Architecture

Forgejo iOS keeps the upstream Forgejo application model and adds a small iOS deployment layer around the build, runtime, launcher, and validation process.

```text
Forgejo
   |
Go runtime
   |
A7 compatibility layer
   |
iOS launcher
   |
Jailbroken iPad
```

The qualified runtime is built from Go `1.26.7` with a narrow iOS `arm64` A7 compatibility patch for `runtime.procyieldAsm`. The release uses `GOOS=ios`, `GOARCH=arm64`, `CGO_ENABLED=1`, physical iOS Mach-O output, SQLite build tags, and explicit device-side signing.

Detailed porting evidence is recorded in [`PORTING_IOS.md`](PORTING_IOS.md). Maintenance policy is documented in [`docs/MAINTENANCE.md`](docs/MAINTENANCE.md).

## Backup

Use the documented stopped-files backup flow before moving data, restoring an instance, or testing a new release. The backup process verifies SQLite integrity and repository object health, but it is not an encryption tool.

Read [`docs/BACKUP.md`](docs/BACKUP.md) before operating on persistent data.

## Security

The validated deployment defaults to loopback HTTP and owner-only runtime files. Do not publish private keys, credentials, runtime directories, databases, logs, cookies, or backup archives.

Read [`docs/SECURITY.md`](docs/SECURITY.md) for the security boundary, supported network posture, signing notes, permission expectations, and unsupported exposure paths.

## Limitations

- Manual launcher only; automatic boot is not guaranteed.
- Rootful jailbreak target only.
- Loopback HTTP is the default and only qualified listener posture.
- Other devices, iOS versions, jailbreaks, and CPUs require new testing.
- The A7 runtime evidence is bounded validation, not thermal, battery, capacity, or indefinite-soak qualification.
- Optional Forgejo services and external renderers remain deployment-specific.

## Development

Development work should preserve the release boundary unless a new maintenance or upgrade cycle is explicitly opened.

- Public documentation starts in [`docs/README.md`](docs/README.md).
- Installation details are in [`docs/INSTALL.md`](docs/INSTALL.md).
- Build and validation notes are in [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).
- The frozen v1.0.0 release metadata is in [`CHANGELOG.md`](CHANGELOG.md) and [`RELEASE.md`](RELEASE.md).

Contributions must not include runtime data, logs, backups, secrets, private keys, or device-local databases.

## License

Forgejo is distributed under the terms of the [GNU General Public License version 3.0](LICENSE) or any later version. Forgejo versions before v9.0 were distributed under the MIT license.

For upstream contribution guidance, see [`CONTRIBUTING.md`](CONTRIBUTING.md).
