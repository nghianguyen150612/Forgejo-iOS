# Project status

Last reviewed: 2026-09-22

This page is the concise status view for Forgejo-iOS. It separates repository evidence from assumptions and device work that has not yet been completed. The detailed evidence log remains in [`PORTING_IOS.md`](../PORTING_IOS.md).

## Implemented

- Forgejo 15.0.9 is packaged for physical iOS arm64 with SQLite support.
- The A7-compatible `go1.26.7-a7` runtime and reproducible iPhoneOS build/probe workflow are present.
- The POSIX installer/lifecycle engine supports installation, verification, diagnostics, update, rollback, repair, and uninstall.
- The manual launcher runs Forgejo as a configured non-root account with owner-only runtime paths and loopback HTTP defaults.
- Backup and restore tooling includes SQLite/Git integrity checks, checksums, and permission checks.
- A rootful LaunchDaemon implementation exists for `com.forgejo.ios.plist`, including `RunAtLoad`, `KeepAlive`, controlled environment, status, stop, restart, and uninstall paths.
- Documentation covers the frozen release, security boundary, backups, maintenance, development, compatibility, and SSH tunneling.

## Tested / verified

The following claims have repository evidence:

- The current `iOS` baseline is commit `5b064e32f9ec09842d874b6fd0e1144e84c2924f`.
- The target device identity has been observed as iPad mini 2 / `iPad4,4` / Apple A7 / arm64 / iOS 12.5.7 / Darwin 18.7.0.
- Apple physical-iOS arm64 Mach-O probes build in GitHub Actions with the documented Xcode/iPhoneOS toolchain.
- Native C and Go 1.26.7 pure-Go/CGO probes execute on the target after the empirically required device-side signing treatment.
- The Forgejo production artifact, installer lifecycle, security audit, backup workflow, and host-side LaunchDaemon fixtures have CI or recorded validation evidence as described in [`PORTING_IOS.md`](../PORTING_IOS.md), [`RELEASE.md`](../RELEASE.md), and the workflow files.
- Loopback-only HTTP, disabled SSH defaults, owner-only paths, checksum verification, and manual start/stop behavior are the qualified operating posture.

## Implemented, awaiting physical-device verification

These features exist in the repository but must not be treated as device-qualified until a controlled device test records the result:

- LaunchDaemon installation against `/Library/LaunchDaemons` using non-interactive root access.
- Boot persistence after a real reboot.
- Crash recovery after killing the managed service.
- LaunchDaemon start/stop/restart behavior while preserving SQLite and HTTP health.
- Any claim of automatic startup or indefinite service availability on the iPad.

The earlier physical acceptance run was blocked because non-interactive `sudo` on the iPad required a password. Host fixtures do not substitute for those device checks.

## Planned

- Complete the disposable physical-device LaunchDaemon gate without touching real user data.
- Re-run the manual Forgejo lifecycle and SQLite/HTTP checks from a clean, documented device runtime.
- Expand the device matrix only after each combination has its own build, signing, runtime, and cleanup evidence.
- Measure bounded A7 resource behavior and document workload limits; do not promise indefinite uptime, thermal, battery, or capacity behavior.
- Reassess the frozen Forgejo/runtime pair through a separate upgrade cycle rather than changing the v1.0.0 qualification in place.

## Status vocabulary

- **Implemented** means code or documentation exists in this repository.
- **Tested / verified** means the repository contains reproducible CI, host, or device evidence for the stated scope.
- **Awaiting physical-device verification** means implementation exists, but the required iPad test has not passed or has not been run.
- **Planned** means no current implementation or qualification claim is made.

See [`COMPATIBILITY.md`](COMPATIBILITY.md) for the supported and unverified combinations, and [`ROADMAP.md`](../ROADMAP.md) for sequencing.
