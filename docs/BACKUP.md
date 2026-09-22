# Forgejo-iOS backup, restore, and migration

This document defines the P12 data-safety procedure for the native Forgejo
runtime on the primary device:

```text
Forgejo 15.0.9
Go runtime go1.26.7-a7
iPad4,4 / Apple A7 / iOS 12.5.7 / Darwin 18.7.0
SQLite with WAL
```

The procedure is deliberately filesystem-based. It does not change Forgejo
core, the Go runtime, SQLite, or the launcher. It is intended for an isolated
runtime root such as `/var/nghianguyen/forgejo-ios-p10/<sha>/runtime`, and it
never overwrites an existing backup or restore destination.

The P13 security contract in [`docs/SECURITY.md`](SECURITY.md) is a
prerequisite for this workflow. A backup is refused when the dedicated source
tree is not owner-only; backup confidentiality is not provided by a checksum
alone.

## What must be backed up

The backup command takes the three runtime directories below and packages them
under the same relative names. A missing mandatory directory is an error.

| Path | Classification | Contents and handling |
| --- | --- | --- |
| `custom/conf/` | Mandatory | `app.ini` and custom configuration. This is required to start the restored instance and to retain the configured paths, URL, authentication settings, and secrets. |
| `data/` | Mandatory | Forgejo application data, including the database, attachments, avatars, LFS/packages when configured, queues, sessions, and indexes. The whole directory is retained so that optional storage is not silently lost. |
| `data/forgejo.db` | Mandatory database | SQLite database. The backup records `PRAGMA integrity_check` and the observed `-wal`/`-shm` state. |
| `data/forgejo.db-wal` and `data/forgejo.db-shm` | Conditional database files | Included when a stopped runtime has them. If the service is explicitly backed up while live, SQLite `.backup` folds the committed WAL state into a new `forgejo.db`; the live sidecars are intentionally not copied. |
| `data/attachments/` | Optional user content | It is absent on a new instance, but every existing attachment is included because it is inside `data/`. `ATTACHMENTS_STATE` in the metadata records whether this directory was present. |
| `repositories/` | Mandatory | Forgejo bare Git repositories, including refs, objects, hooks, and repository configuration. Every `*.git` repository is checked with `git fsck --full` before and after staging. |

The following are not part of the backup payload because they are generated
or operational state and can be recreated:

- `log/`, launcher logs, PID files, `forgejo.binary`, and `forgejo.args`;
- the Forgejo executable, Go toolchain, code-signing files, and build output;
- temporary files and caches;
- indexer, queue, session, and temporary data when an operator deliberately
  removes those generated directories before a backup.

When generated directories exist below `data/`, the script includes them and
records their paths in `metadata.txt`. They may be rebuilt by Forgejo after a
restore, but retaining them makes a normal restore faster. The database,
attachments, and repositories are not considered disposable generated data.

## Backup format

`scripts/ios/backup-forgejo.sh` creates a new directory atomically:

```text
BACKUP_DIR/
├── metadata.txt       # mode 600; version, provenance, database state, counts
├── manifest.sha256    # mode 600; checksum for every regular payload file
└── payload.tar        # mode 600; custom/conf, data, repositories
```

The backup directory is mode `700`. The payload layout is deterministic and
does not depend on the absolute source path. `metadata.txt` records a UTC
timestamp, so two backups of the same bytes are intentionally distinguishable;
`BACKUP_CHECKSUM_SHA256` is the SHA-256 checksum of `payload.tar`. The manifest
and the checksum are verified before restore. The source runtime and extracted
payload must also have mode `700` directories and owner-only regular files;
`app.ini`, database files, key material, logs, and backup metadata are required
to be mode `600`. The script fails instead of silently broadening access.

The script refuses an existing final backup. It stages data below a hidden
`.BACKUP_NAME.partial.*` directory and renames that directory into place only
after database, repository, manifest, and tar validation succeeds. An
interrupted process can leave its staging directory if it is killed with
`SIGKILL`; a later run refuses a stale partial directory and does not delete it
automatically. Inspect and remove only that clearly identified staging path
after confirming that it is not a runtime or a completed backup.

## Normal backup procedure

Use the same unmodified runtime and stop it cleanly first. A clean stop lets
SQLite checkpoint and removes transient WAL/SHM files when Forgejo chooses to
do so.

```sh
export FORGEJO_IOS_BINARY=/var/nghianguyen/forgejo-ios-p10/<sha>/forgejo-ios-a7
export FORGEJO_IOS_SERVICE_DIR=/var/nghianguyen/forgejo-ios-p10/<sha>/runtime

scripts/ios/run-forgejo.sh stop "$FORGEJO_IOS_BINARY"

FORGEJO_IOS_VERSION=15.0.9 \
FORGEJO_IOS_GIT_COMMIT=<source-commit> \
FORGEJO_IOS_RUNTIME_VERSION=go1.26.7-a7 \
scripts/ios/backup-forgejo.sh backup \
  --source-root "$FORGEJO_IOS_SERVICE_DIR" \
  --output /var/nghianguyen/forgejo-backups/<utc-name> \
  --binary "$FORGEJO_IOS_BINARY"

scripts/ios/backup-forgejo.sh verify \
  /var/nghianguyen/forgejo-backups/<utc-name>
```

The command checks `PRAGMA integrity_check;`, validates every `*.git` tree,
compares repository refs and reachable object history before and after staging,
and records the database sidecar state. It does not print `app.ini`, database
rows, Git commit messages, repository contents, or command-line secrets.

The P10 historical runtime examples placed `app.ini` beside the executable.
That layout is not eligible for this backup command because the command's
confidentiality boundary requires `custom/conf/app.ini` inside the source
runtime. Move or recreate the configuration under `custom/conf/`, review every
absolute path, and pass it explicitly with `--config` before adopting the P13
backup procedure. Do not back up a mixed or partially migrated tree.

If the launcher still has a live PID, the default is a refusal. The explicit
live mode is available for a controlled maintenance window:

```sh
scripts/ios/backup-forgejo.sh backup \
  --source-root "$FORGEJO_IOS_SERVICE_DIR" \
  --output /var/nghianguyen/forgejo-backups/<utc-name> \
  --allow-running
```

In live mode the SQLite database is copied with SQLite's online `.backup`
operation and then checked again. Repository integrity and ref/history checks
still run, but concurrent application writes outside the SQLite snapshot can
make the complete filesystem set change during staging; the script fails if
repository identity changes. Therefore live mode is a safe database method,
not a promise of a crash-consistent full-instance snapshot. Stop Forgejo for
the production backup procedure.

## Restore procedure

Restore into a new, empty runtime location. The script refuses to overwrite an
existing path, so a failed restore cannot silently destroy the old runtime.

```sh
scripts/ios/backup-forgejo.sh verify \
  /var/nghianguyen/forgejo-backups/<utc-name>

scripts/ios/backup-forgejo.sh restore \
  /var/nghianguyen/forgejo-backups/<utc-name> \
  --destination /var/nghianguyen/forgejo-ios-restored/<new-sha>/runtime
```

After extraction:

1. Install or select the separately built Forgejo binary for the target. The
   backup contains data, not an executable or a Go runtime.
2. Review `custom/conf/app.ini`. Update absolute paths, the instance URL, and
   any device-specific paths to the new runtime location. Do not replace a
   restored database with a newly initialized one.
3. Check owner-only permissions on the restored configuration and the backup
   directory. Do not put the backup under a web-served directory.
4. Start the restored runtime through the existing launcher with the tested
   A7 policy:

   ```sh
   export FORGEJO_IOS_BINARY=/var/nghianguyen/forgejo-ios/<new-sha>/forgejo-ios-a7
   export FORGEJO_IOS_SERVICE_DIR=/var/nghianguyen/forgejo-ios-restored/<new-sha>/runtime
   export FORGEJO_IOS_DEVICE_MODEL=iPad4,4
   export FORGEJO_IOS_DARWIN_RELEASE=18.7.0
   scripts/ios/run-forgejo.sh start "$FORGEJO_IOS_BINARY" \
     --config "$FORGEJO_IOS_SERVICE_DIR/custom/conf/app.ini"
   ```

5. Verify HTTP readiness, the expected users and repositories, a clone, an
   authenticated push using a disposable test branch, and
   `PRAGMA integrity_check;`. Stop the isolated runtime after validation.

The script does not run Forgejo migrations or rewrite configuration. A
restore into an already populated location, an accidental path collision, or
a failed checksum is an operator error and is intentionally refused.

## Migration: runtime A to runtime B

Migration is the same restore operation with a different filesystem root:

```text
runtime A --backup--> backup set --restore--> runtime B
```

Use a new sibling or separate filesystem location for runtime B. Keep runtime A
stopped and untouched until runtime B passes the checks above. This validates
that identity is in the Forgejo data rather than in the old absolute path.
The app configuration must still be reviewed for absolute `WORK_PATH`,
repository, attachment, and log paths. Do not run two Forgejo instances against
the same SQLite database or repository directory.

## Version compatibility and limitations

- Restore with the same Forgejo version and SQLite build first. The P12 target
  is Forgejo `15.0.9` with bundled SQLite and the `go1.26.7-a7` runtime.
- A newer Forgejo version may migrate the database on first start. Take a new
  backup before that migration and retain the old set. Do not assume that a
  database migrated forward can be opened by an older Forgejo binary.
- The backup does not contain the executable, code signature, Go runtime,
  device entitlements, logs, or external files outside the three runtime
  directories.
- External storage configured outside `custom/conf/`, `data/`, or
  `repositories/` is outside this format and must be backed up separately.
- Forgejo database rows and configuration can contain password hashes,
  session/access tokens, webhook secrets, OAuth material, and SSH private keys
  when those features are configured. A complete restore cannot preserve those
  features while stripping their data. Treat `payload.tar` as confidential and
  encrypt or otherwise protect it at rest and in transit. The script records
  no secret values in logs or metadata and sets the backup files to mode `600`;
  it is not an encryption tool.

## P12 validation record

All test data for this prompt is isolated and disposable. No database,
repository, archive, or secret is committed.

| Check | Result | Evidence |
| --- | --- | --- |
| Backup procedure and layout | PASS | This document and `metadata.txt`/`manifest.sha256` format |
| SQLite integrity and WAL/SHM handling | PASS | Stopped-file backup returned `ok`; live mode observed both `forgejo.db-wal` and `forgejo.db-shm`, used SQLite `.backup`, omitted live sidecars from the payload, and verified the resulting database. |
| Repository fsck, refs, and history | PASS | One disposable bare repository passed `git fsck --full`; pre/post refs, reachable object history, and commit count matched. |
| Restore with users/repositories/settings | PASS | Isolated Forgejo runtime B served HTTP 200, retained user `p12admin`, private repository `p12-repo`, and the `APP_NAME` setting. |
| Git clone and push after restore | PASS | A clone from runtime B succeeded and a second commit pushed back successfully. |
| Runtime A to runtime B migration | PASS | The full data set moved between two different temporary filesystem roots; only absolute configuration paths and the test port were updated. |
| Interrupted backup and stale partial | PASS | `SIGKILL` left a named partial directory; the next run refused it and did not delete it or overwrite the destination. |
| Missing optional attachments | PASS | Backup and verification succeeded with absent `data/attachments/`; metadata recorded `ATTACHMENTS_STATE=absent`. |
| Security and permissions | PASS with limitation | The disposable secret marker was absent from command output, backup metadata/manifest/payload were mode 600, and the backup root was mode 700. The payload remains confidential by design because complete Forgejo data can contain stored credential material. |
| Ten-minute resource window | PASS | Backup 0.439 s / 4,920 KB peak RSS; restore 0.318 s / 4,472 KB peak RSS; backup 2,523,136 bytes; restored runtime 2,600,960 bytes. |
| Linux regression | PASS | `GOTOOLCHAIN=local make build TAGS='bindata timetzdata sqlite sqlite_unlock_notify'`; produced Forgejo 15.0.9 with the requested tags using host Go `go1.27.1-X:nodwarf5`. |
| iOS/A7 CI | PENDING | A7 runtime, Forgejo build, launcher, and backup-script checks |

The short resource test is capped at ten minutes. It records the backup and
restore wall time, peak process RSS where available, and backup/runtime storage
with `du`. It is not a long soak, battery, thermal, or capacity qualification.

## Prompt 014 release-candidate compatibility check

The P14 check used the same backup contract with a fresh, empty device runtime
and the release-candidate A7 executable. It did not repeat the P12 account,
repository, clone, or push workload. The runtime was stopped before backup;
the backup used stopped-files SQLite mode, and restore targeted a different
filesystem root.

```text
device: iPad4,4 / Apple A7 / iOS 12.5.7 / Darwin 18.7.0
runtime: /var/nghianguyen/forgejo-ios-p14/276ef3b783c40348d35fc00ad249f3c9fd76742e
backup payload SHA-256: b7d7f1f7fa5c97e04c9deab4f06c170de98f1d035d9f83c25c5cda30336cc7bc
```

Result: **PASS**. The source, backup, and restored trees passed the strict
owner-only audit; the backup and manifest verified; SQLite integrity returned
`ok` before and after restore; and the restored disposable service returned
HTTP 200 and stopped cleanly. No repository objects or real user data were
included. The runtime, backup, and restored trees are disposable evidence and
are not release artifacts.
