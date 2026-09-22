# Forgejo-iOS Maintenance

This document defines the maintenance process for the frozen Forgejo-iOS v1.0.0 release line.

## Frozen Release Matrix

```text
Forgejo: 15.0.9
Runtime: go1.26.7-a7
Deployment: iPad4,4
Device OS: iOS 12.5.7
CPU: Apple A7
```

The v1.0.0 release line is frozen to this matrix. Maintenance work must preserve the release boundary unless it is explicitly opened as a new maintenance or upgrade cycle.

## Maintenance Policy

- Keep Forgejo source, Go runtime patches, and build behavior unchanged for v1.0.0 rebuilds.
- Do not include secrets, runtime directories, databases, repositories, logs, private keys, or backup payloads in source control or release metadata.
- Record every rebuilt artifact with `build-info.txt`, `SHA256SUMS`, signature status, source SHA, runtime provenance, and target device evidence.
- Treat device-side signatures as deployment-local artifacts; do not replace host artifact checksums with post-transfer `ldid` checksums.
- Require a new validation record for every Forgejo, Go runtime, SDK, signing, or device matrix change.

## Updating Forgejo

Forgejo updates are outside the frozen v1.0.0 line and require a new release cycle.

```text
upstream update
       |
       v
Linux build
       |
       v
iOS build
       |
       v
A7 runtime validation
       |
       v
device test
```

Required evidence for a Forgejo update:

- Upstream source version and commit are identified before any iOS build work starts.
- Linux build passes with the intended release tags.
- iOS arm64 production artifact is produced without unreviewed Forgejo source changes.
- A7 runtime validation is repeated on the frozen target class or the new target class is documented.
- Device test records HTTP readiness, SQLite integrity, listener posture, launcher behavior, shutdown behavior, artifact checksum, and signature status.

## Updating Go Runtime

Go runtime updates are outside the frozen v1.0.0 line and require source-level review before device validation.

Required evidence for a runtime update:

- Source review of the runtime delta and the iOS arm64 patch scope.
- Runtime probe confirming the expected low-level behavior before Forgejo qualification.
- A7 validation on iPad4,4 or an explicitly documented replacement device matrix.
- Production Forgejo-iOS rebuild with fresh `build-info.txt`, `SHA256SUMS`, signature information, and runtime provenance.

## Release Rebuild Checklist

- Confirm `git status` and `git diff` are clean before building.
- Confirm no runtime files, databases, logs, private keys, secrets, or backup archives are staged.
- Build the Linux control artifact with `make build TAGS='bindata timetzdata sqlite sqlite_unlock_notify'`.
- Build the iOS production artifact through the documented iOS release workflow.
- Verify `sha256sum -c SHA256SUMS` for the release bundle.
- Preserve `build-info.txt`, runtime patch SHA-256, signature status, and device validation notes with the artifact.
