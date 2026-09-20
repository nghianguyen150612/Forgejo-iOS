# Installation Guide

This guide describes the supported Forgejo iOS v1.0.0 installation flow for the qualified Apple A7 target. It does not add support for other devices, jailbreaks, or background-service models.

## Requirements

### Qualified Platform

```text
Device:    iPad4,4
CPU:       Apple A7
OS:        iOS 12.5.7
Jailbreak: Rootful Amethyst
Forgejo:   15.0.9
Runtime:   go1.26.7-a7
```

### Device Tools

- Shell access to the jailbroken iPad.
- `/usr/bin/ldid` for device-side signing.
- Git and SQLite command-line tools for validation and repository checks.
- A writable owner-only directory below the device user's home or another dedicated data location.

### Host Files

- `forgejo-ios` release executable.
- `build-info.txt` provenance file.
- `SHA256SUMS` checksum file.
- `scripts/ios/run-forgejo.sh` launcher.
- `scripts/ios/device-entitlements-no-container.plist` entitlement file.

## Jailbreak Requirement

Forgejo iOS v1.0.0 is qualified only on a rootful Amethyst jailbreak. The release expects explicit device-side signing and does not claim compatibility with rootless jailbreak layouts, stock iOS, App Store packaging, simulator builds, or automatic launchd integration.

Keep Forgejo under a dedicated owner-only tree. Do not mix the release bundle with unrelated jailbreak files, user repositories, logs, backups, or private keys.

## Installation Steps

### 1. Verify the Release Bundle

On the host, verify the release artifact before transfer:

```sh
sha256sum -c SHA256SUMS
```

The v1.0.0 release records these checksums in [`../RELEASE.md`](../RELEASE.md):

```text
forgejo-ios           19dd23e3a78d13e1beb18a1e475d7b1a2c75959a0718d958905a0a540400218a
forgejo-ios-pristine  e8a8d55f9cb3a942bad8cb0a00e3b88201244e8e73b469b1d45884ab6347389d
```

### 2. Create a Device Directory Layout

Create an isolated release directory on the iPad:

```sh
release_root=/var/nghianguyen/forgejo-ios/v1.0.0-ios
runtime_root="$release_root/runtime"

mkdir -p "$release_root/bin" \
  "$runtime_root/custom/conf" \
  "$runtime_root/data" \
  "$runtime_root/repositories" \
  "$runtime_root/logs"
chmod 700 "$release_root" "$release_root/bin" "$runtime_root" \
  "$runtime_root/custom" "$runtime_root/custom/conf" \
  "$runtime_root/data" "$runtime_root/repositories" "$runtime_root/logs"
```

The exact base path may differ by operator. Preserve the owner-only permission model.

### 3. Copy Files to the Device

Copy the executable, launcher, and entitlement plist into the release tree. Keep release metadata beside the executable for provenance:

```sh
cp forgejo-ios "$release_root/bin/forgejo-ios"
cp build-info.txt SHA256SUMS "$release_root/"
cp scripts/ios/run-forgejo.sh "$release_root/bin/run-forgejo.sh"
cp scripts/ios/device-entitlements-no-container.plist "$release_root/"
chmod 700 "$release_root/bin/forgejo-ios" "$release_root/bin/run-forgejo.sh"
chmod 600 "$release_root/build-info.txt" "$release_root/SHA256SUMS" \
  "$release_root/device-entitlements-no-container.plist"
```

### 4. Sign the Working Copy

Sign the device-side working copy with `ldid` and the no-container entitlement:

```sh
/usr/bin/ldid -S"$release_root/device-entitlements-no-container.plist" \
  "$release_root/bin/forgejo-ios"
/usr/bin/ldid -e "$release_root/bin/forgejo-ios"
```

The signed device copy has a different checksum from the host artifact. Preserve both values in operator notes.

### 5. Create `app.ini`

Create `custom/conf/app.ini` with explicit paths below the runtime root. Use a loopback listener for the qualified default:

```ini
APP_NAME = Forgejo iOS
RUN_USER = nghianguyen
WORK_PATH = /var/nghianguyen/forgejo-ios/v1.0.0-ios/runtime

[server]
APP_DATA_PATH = /var/nghianguyen/forgejo-ios/v1.0.0-ios/runtime/data
DOMAIN = 127.0.0.1
HTTP_ADDR = 127.0.0.1
HTTP_PORT = 39140
ROOT_URL = http://127.0.0.1:39140/
DISABLE_SSH = true
START_SSH_SERVER = false

[database]
DB_TYPE = sqlite3
PATH = /var/nghianguyen/forgejo-ios/v1.0.0-ios/runtime/data/forgejo.db

[repository]
ROOT = /var/nghianguyen/forgejo-ios/v1.0.0-ios/runtime/repositories

[log]
MODE = file
ROOT_PATH = /var/nghianguyen/forgejo-ios/v1.0.0-ios/runtime/logs
```

Then restrict the file:

```sh
chmod 600 "$runtime_root/custom/conf/app.ini"
```

## First Startup

Export the launcher environment and start Forgejo:

```sh
export FORGEJO_IOS_BINARY="$release_root/bin/forgejo-ios"
export FORGEJO_IOS_SERVICE_DIR="$runtime_root"
export FORGEJO_IOS_DEVICE_MODEL=iPad4,4
export FORGEJO_IOS_DARWIN_RELEASE=18.7.0

"$release_root/bin/run-forgejo.sh" start "$FORGEJO_IOS_BINARY" \
  --config "$runtime_root/custom/conf/app.ini"
```

Check service state:

```sh
"$release_root/bin/run-forgejo.sh" status "$FORGEJO_IOS_BINARY"
```

## Verification

Verify version, HTTP readiness, database integrity, and listener posture:

```sh
"$FORGEJO_IOS_BINARY" --version
curl --fail http://127.0.0.1:39140/
sqlite3 "$runtime_root/data/forgejo.db" 'PRAGMA integrity_check;'
netstat -an | grep 39140
```

Expected results:

- Forgejo reports version `15.0.9` with the release build tags.
- Launcher status reports the A7 runtime policy.
- HTTP readiness returns success on loopback.
- SQLite integrity returns `ok`.
- The listener is bound to `127.0.0.1`, not `0.0.0.0`, `::`, or `*`.

## Stop and Backup

Stop Forgejo before backup, restore, or maintenance:

```sh
"$release_root/bin/run-forgejo.sh" stop "$FORGEJO_IOS_BINARY"
```

Follow [`BACKUP.md`](BACKUP.md) for stopped-files backup and restore. Backups can contain sensitive repository data, configuration values, and credential-derived material; encrypt and store them separately.

## Troubleshooting Boundaries

- If signing changes the executable hash, treat that as expected and record both the host and device hashes.
- If the service binds to a non-loopback address, stop it and review `app.ini` before use.
- If SQLite integrity fails, do not continue startup testing; preserve the runtime tree and restore from a known-good backup.
- If the device is not `iPad4,4` on iOS `12.5.7`, treat the deployment as unqualified until a new validation cycle is completed.
