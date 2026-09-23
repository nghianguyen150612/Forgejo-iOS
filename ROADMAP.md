# Roadmap

Forgejo-iOS is intentionally progressing in small, evidence-driven steps. The v1.0.0 line remains frozen to Forgejo 15.0.9, `go1.26.7-a7`, and the qualified A7 target. Items below do not expand support until their evidence is recorded.

## Current baseline

- Preserve the manual-launcher deployment as the qualified fallback.
- Keep HTTP on loopback by default and use an SSH tunnel or separately controlled private network path for remote administration.
- Do not claim reboot persistence or crash recovery from host fixtures alone.

## Next: close the device-service gate

1. Enter a controlled UID-0 context on the target device (through `sudo` or an existing root shell).
2. Install the managed rootful LaunchDaemon in a disposable runtime.
3. Verify `launchctl` status, process ownership, listener address, and SQLite integrity.
4. Reboot once and record whether `RunAtLoad` starts the service.
5. Kill the managed process and record whether `KeepAlive` recovers it.
6. Stop, uninstall, and prove that configuration, repositories, and backups remain intact.

A failed or unavailable step remains **not tested**; it is not converted into a support claim.

## Then: strengthen the qualified A7 profile

- Repeat clean-install, update, rollback, backup, restore, and uninstall checks on the target.
- Preserve and extend the bounded CPU, RSS, storage, startup, and workload observations already recorded in `docs/P9-WORKLOAD.md`.
- Test Git clone/fetch/push, hooks, SSH transport, and cancellation using disposable repositories.
- Document optional features separately instead of assuming that Linux-oriented PAM, systemd, sendmail, or external renderers work on iOS.

## Later: broaden compatibility carefully

- Test additional rootful jailbreak versions and layouts.
- Test additional A7 devices and iOS 12.x versions only with separate artifacts and evidence.
- Evaluate non-A7 arm64 devices and newer iOS versions only after the signing, filesystem, process, SQLite, and networking gates are defined for them.
- Consider rootless support only as a separate deployment design; it is not an incremental promise for the current installer.

## Release and maintenance policy

- Keep the v1.0.0 artifact and runtime pins reproducible.
- For a Forgejo or Go update, repeat upstream review, host build, physical-iOS build, signing, device runtime, checksum, and provenance validation.
- Prefer upstream-compatible changes and narrow iOS-specific additions; do not rewrite shared Forgejo behavior without confirmed device evidence.
- Do not commit device databases, credentials, runtime directories, private keys, or backup archives.

Out of scope for this roadmap are unrelated CI redesigns, a public hosting service, and a promise that jailbroken iOS provides server-grade isolation.
