# Changelog

## Forgejo iOS v1.0.0 - 2026-09-20

Final release for the Forgejo iOS A7 validation target.

### Added

- iOS arm64 build support for the Forgejo 15.0.9 release artifact.
- A7 runtime compatibility through the frozen `go1.26.7-a7` runtime.
- Manual service launcher workflow for rootful jailbreak deployments.
- Backup and restore workflow with integrity checks and owner-only handling.
- Security boundary documentation covering loopback defaults, secrets, runtime data, signatures, backups, and unsupported exposure paths.

### Validated

- Forgejo 15.0.9.
- iPad4,4.
- iOS 12.5.7.
- `go1.26.7-a7`.

### Version Freeze

- Forgejo: 15.0.9.
- Runtime: `go1.26.7-a7`.
- Deployment: iPad4,4.

### Limitations

- Manual launcher only; no automatic boot or launchd guarantee is part of this release.
- Rootful jailbreak target only.
- Loopback HTTP is the default and only qualified listener posture.
- No automatic boot guarantee.

### Maintenance Policy

- Treat this release as frozen for Forgejo 15.0.9, `go1.26.7-a7`, and iPad4,4 deployment evidence.
- Do not update Forgejo, the Go runtime patch, build behavior, or deployment assumptions in the v1.0.0 release line without a new maintenance or upgrade cycle.
- Any Forgejo update requires a fresh upstream review, Linux build, iOS build, A7 runtime validation, device test, artifact checksum, and provenance record.
- Any Go runtime update requires source review, runtime probe evidence, A7 validation, device test, artifact checksum, and provenance record.
