# Documentation Index

This directory contains the public operator and maintenance documentation for Forgejo iOS. The v1.0.0 release is frozen to Forgejo `15.0.9`, `go1.26.7-a7`, and the qualified `iPad4,4` Apple A7 target.

```text
docs/
├ BACKUP.md
├ DEVELOPMENT.md
├ INSTALL.md
├ MAINTENANCE.md
├ SECURITY.md
└ README.md
```

## Core Documents

- [`INSTALL.md`](INSTALL.md) explains requirements, jailbreak assumptions, installation steps, verification, and first startup.
- [`DEVELOPMENT.md`](DEVELOPMENT.md) summarizes repository structure, build flow, the iOS toolchain, the A7 runtime patch, and validation expectations.
- [`BACKUP.md`](BACKUP.md) documents stopped-files backup and restore operations, integrity checks, and backup limitations.
- [`SECURITY.md`](SECURITY.md) defines the deployment security boundary, permissions, signing model, network posture, and unsupported exposure paths.
- [`MAINTENANCE.md`](MAINTENANCE.md) defines the frozen release matrix and the required process for Forgejo or Go runtime updates.

## Evidence Documents

- [`PERFORMANCE.md`](PERFORMANCE.md) records resource and performance evidence for the qualified target.
- [`P9-WORKLOAD.md`](P9-WORKLOAD.md) records workload validation evidence from the iPad test cycle.
- [`../PORTING_IOS.md`](../PORTING_IOS.md) is the full chronological porting, build, runtime, and device validation log.
- [`../RELEASE.md`](../RELEASE.md) is the v1.0.0 release metadata, checksum, provenance, and limitation summary.

## Reading Order

1. Read [`../README.md`](../README.md) for the project overview.
2. Read [`INSTALL.md`](INSTALL.md) before installing or moving artifacts to a device.
3. Read [`SECURITY.md`](SECURITY.md) before exposing any network endpoint.
4. Read [`BACKUP.md`](BACKUP.md) before operating on persistent data.
5. Read [`MAINTENANCE.md`](MAINTENANCE.md) and [`DEVELOPMENT.md`](DEVELOPMENT.md) before changing versions, tooling, or validation scope.

Do not commit runtime directories, databases, repositories, logs, private keys, credentials, cookies, or backup archives as documentation evidence.
