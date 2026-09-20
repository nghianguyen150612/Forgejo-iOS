# Development Guide

This guide summarizes how Forgejo iOS is organized, built, and validated. It is documentation for the frozen v1.0.0 release line and does not authorize product behavior changes.

## Repository Structure

- `cmd/`, `models/`, `modules/`, `routers/`, `services/`, `templates/`, and `web_src/` are upstream Forgejo application areas.
- `scripts/ios/` contains iOS build, launcher, audit, backup, signing, runtime provenance, and inspection helpers.
- `scripts/ios/go-runtime/` contains the A7 runtime build process and version-specific runtime patch inputs.
- `tools/ios-cgo-probe/` and `tools/ios-runtime-probes/` contain small validation probes for iOS runtime behavior.
- `.github/workflows/` contains the iOS runtime matrix, A7-compatible runtime, and production Forgejo build workflows.
- `docs/` contains public operator, security, backup, maintenance, performance, and development documentation.
- `PORTING_IOS.md` is the chronological engineering and evidence log for the port.
- `RELEASE.md`, `CHANGELOG.md`, and `docs/MAINTENANCE.md` define the frozen v1.0.0 release boundary.

## Build Flow

The qualified release flow is intentionally narrow:

```text
upstream Forgejo 15.0.9
        |
        v
Linux control build
        |
        v
Go 1.26.7 A7 runtime build
        |
        v
iOS arm64 Forgejo build
        |
        v
artifact inspection and checksums
        |
        v
device signing and validation
```

The Linux control build uses:

```sh
make build TAGS='bindata timetzdata sqlite sqlite_unlock_notify'
```

The iOS production build uses `GOOS=ios`, `GOARCH=arm64`, `CGO_ENABLED=1`, the iPhoneOS SDK, and physical-device Mach-O output. Release artifacts are accompanied by `build-info.txt` and `SHA256SUMS`.

## iOS Toolchain

The release evidence was produced with the macOS arm64 GitHub Actions environment documented in [`../RELEASE.md`](../RELEASE.md) and [`../PORTING_IOS.md`](../PORTING_IOS.md). The iOS build path requires:

- Xcode iPhoneOS SDK, not the simulator SDK.
- Apple clang from `xcrun --sdk iphoneos`.
- Minimum physical iOS target `12.0`.
- SQLite-enabled Forgejo build tags.
- Host-side artifact inspection before device transfer.
- Device-side signing with `ldid` for the working copy.

Do not replace the iOS SDK, signing treatment, or build tags in the v1.0.0 line without opening a new maintenance cycle.

## A7 Runtime Patch

The qualified runtime is `go1.26.7-a7`. It is built from Go `1.26.7` with a narrow patch scoped to iOS `arm64` `runtime.procyieldAsm` behavior on Apple A7 devices.

Maintenance requirements:

- Review the Go source delta before changing the runtime.
- Confirm the patch scope remains narrow and documented.
- Run runtime probes before qualifying Forgejo.
- Revalidate on `iPad4,4` or document a replacement device matrix.
- Regenerate artifact checksums, runtime provenance, and signature evidence.

The frozen runtime patch SHA-256 is recorded in [`../RELEASE.md`](../RELEASE.md) and [`MAINTENANCE.md`](MAINTENANCE.md).

## Validation Process

Validation is evidence-driven. A release or maintenance build must record:

- Clean `git status` and no unintended source changes.
- Linux control build result.
- iOS production build result.
- Runtime provenance and A7 instruction inspection.
- `SHA256SUMS` verification for the artifact bundle.
- Signature status for the host artifact and device working copy.
- Device startup, HTTP readiness, SQLite integrity, listener address, and clean stop.
- Backup and restore evidence when persistent data handling is in scope.

The v1.0.0 device target is:

```text
iPad4,4 / Apple A7 / iOS 12.5.7 / Darwin 18.7.0
```

## Documentation Workflow

Documentation-only changes may update `README.md`, `README.vi.md`, `docs/*.md`, `RELEASE.md`, `CHANGELOG.md`, and `PORTING_IOS.md` when appropriate. They must not alter source, workflows, runtime patches, binaries, release artifacts, or build behavior unless the prompt explicitly opens that scope.

Before committing documentation changes:

```sh
git status --short
git diff --check
```

Review local Markdown links and avoid unsupported claims. Do not add screenshots, logs, backups, runtime directories, databases, credentials, cookies, or private keys.

## Contribution Boundary

For v1.0.0 maintenance, accepted changes are limited to documentation corrections, release metadata clarifications, and rebuild evidence that preserves the frozen platform. Forgejo updates, Go runtime updates, new device support, automatic boot integration, non-loopback exposure, and new feature work require a new maintenance or upgrade plan.
